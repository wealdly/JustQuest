-- ContainerEngine.lua — Automated container opening for quest rewards and loot containers

local ADDON_NAME, JustQuest = ...

local DANGEROUS_CONTAINERS = JustQuest.Database.DANGEROUS_CONTAINERS
-- DB2-generated (ContainerData.lua): items with ITEM_FLAG_OPENABLE, split by LockID. Only a
-- FALLBACK — the live info.hasLoot read is primary (see ShouldOpen).
local OPENABLE_CONTAINERS = JustQuest.Database.OPENABLE_CONTAINERS  -- free-open (LockID == 0)
local LOCKED_CONTAINERS   = JustQuest.Database.LOCKED_CONTAINERS    -- lockboxes (LockID != 0)

local PICK_LOCK_SPELL = 1804  -- Rogue "Pick Lock"

local ContainerEngine = {}

-- Memoized module accessors
local GetSafetyEngine = JustQuest.Core.ModuleGetter("SafetyEngine")
local GetServices     = JustQuest.Core.ModuleGetter("Services")
local GetConfig       = JustQuest.Core.ModuleGetter("Config")

local lastOpenTime = 0
local isProcessing = false
local failedContainers = {}
local lastScanTime = 0
local pendingContainerUnlock = nil
local lastBagUpdateTime = 0
local bagUpdateCount = 0
local isBagSortActive = false
local expectedContainers = {}  -- Track containers we expect from quest rewards

-- Cache config to avoid repeated lookups during bag iteration
local configCache = {
    enabled = false,
    whitelist = {},
    blacklist = {},
    mode = "safe",
    rogueAutoPick = false,
    lastUpdate = 0,
}

local function UpdateConfigCache()
    local config = GetConfig()
    if not config then return end
    
    configCache.enabled = config.Get("containers", "enabled") or false
    configCache.whitelist = config.Get("containers", "whitelist") or {}
    configCache.blacklist = config.Get("containers", "blacklist") or {}
    configCache.mode = config.Get("containers", "mode") or "safe"
    configCache.rogueAutoPick = config.Get("containers", "rogueAutoPick") or false
    configCache.lastUpdate = GetTime()
end

local debugFunc
local function Debug(msg)
    if not debugFunc then
        local services = GetServices()
        if services then
            debugFunc = function(m) services.Debug("Container", m) end
        else
            debugFunc = function() end
        end
    end
    debugFunc(msg)
end

local function ForEachBagItem()
    return coroutine.wrap(function()
        local startBag = BACKPACK_CONTAINER or 0
        local endBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4
        
        for bagID = startBag, endBag do
            local success, numSlots = pcall(C_Container.GetContainerNumSlots, bagID)
            if success and numSlots and numSlots > 0 then
                for slotID = 1, numSlots do
                    local infoSuccess, info = pcall(C_Container.GetContainerItemInfo, bagID, slotID)
                    if infoSuccess and info and info.itemID then
                        coroutine.yield(bagID, slotID, info)
                    end
                end
            end
        end
    end)
end

-- Whether to auto-open this bag item. PRIMARY signal is the LIVE ContainerItemInfo:
-- info.hasLoot is the runtime ITEM_FLAG_OPENABLE ("right-click to open") and info.isLocked
-- separates free-open containers from lockboxes — so the normal path needs no item DB and is
-- always current. FALLBACK: if the live flag can't be read (unexpected nil / secret value),
-- use the generated ContainerData.lua list by itemID (regenerate via tools/gen_containers.py).
-- Either way, the isLocked branch in ProcessContainerItem still gates lockboxes at runtime.
local function ShouldOpen(info)
    local itemID = info.itemID
    -- User whitelist forces open — covers loot bags that open via an on-use spell (no flag).
    if configCache.whitelist[itemID] then
        return true
    end

    local mode = configCache.mode
    if mode == "list" then return false end  -- whitelist only

    if type(info.hasLoot) == "boolean" then
        if not info.hasLoot then return false end          -- not an openable container
        if mode == "safe" then return not info.isLocked end  -- free-open only; lockboxes wait
        return true                                          -- "all": free-open + lockboxes
    end

    -- Fallback: live flag unreadable — use the baked list.
    if OPENABLE_CONTAINERS and OPENABLE_CONTAINERS[itemID] then return true end
    if mode == "all" and LOCKED_CONTAINERS and LOCKED_CONTAINERS[itemID] then return true end
    return false
end

local function IsDangerousContainer(itemID)
    -- User blacklist overrides everything
    if configCache.blacklist[itemID] then
        return true
    end
    
    -- Built-in never-open defaults (belt-and-suspenders over the live hasLoot check).
    if DANGEROUS_CONTAINERS and DANGEROUS_CONTAINERS[itemID] then
        return true
    end

    return false
end

local function IsContainerOpeningEnabled()
    return configCache.enabled
end

local function GetThrottleDelay()
    local config = GetConfig()
    if not config then
        return JustQuest.Constants.TIMING.CONTAINER_THROTTLE
    end
    
    local delay = config.Get("containers", "throttleDelay") or JustQuest.Constants.TIMING.CONTAINER_THROTTLE
    local multiplier
    if config.Get(nil, "fastMode") then
        multiplier = 0.5
    else
        multiplier = config.Get("advanced", "timingMultiplier") or 1.0
    end
    return delay * multiplier
end

-- Detect bag sorting by tracking rapid BAG_UPDATE events (addon sorters or manual moves).
-- Recording the count and querying the result are split: RecordBagUpdate() must run
-- EXACTLY ONCE per BAG_UPDATE_DELAYED, IsBagSortingActive() is a side-effect-free read.
-- Folding both into one call double-counted every event (the counter was bumped once by
-- OnBagUpdateDelayed and again by OpenBagContainers in the same frame), tripping the
-- "sorting" state at half its intended 3-event threshold and wrongly suppressing
-- container opening during normal looting.
local function DecayBagSort(currentTime)
    if isBagSortActive and currentTime - lastBagUpdateTime > 2.0 then
        isBagSortActive = false
        bagUpdateCount = 0
    end
end

local function RecordBagUpdate()
    local currentTime = GetTime()
    DecayBagSort(currentTime)

    -- BAG_UPDATE from our own container opening, or while expecting quest reward
    -- containers — not sorting. Refresh the activity time but don't count it.
    if (pendingContainerUnlock and (currentTime - pendingContainerUnlock.timestamp < 2.0))
       or next(expectedContainers) then
        lastBagUpdateTime = currentTime
        return
    end

    if currentTime - lastBagUpdateTime < 0.5 then
        bagUpdateCount = bagUpdateCount + 1
        if bagUpdateCount >= 3 then
            isBagSortActive = true
        end
    else
        bagUpdateCount = 1
    end

    lastBagUpdateTime = currentTime
end

local function IsBagSortingActive()
    DecayBagSort(GetTime())
    return isBagSortActive
end

local function GetContainerKey(bagID, slotID, itemID)
    return string.format("%d_%d_%d", bagID, slotID, itemID)
end

local function ShouldRetryContainer(containerKey)
    local failInfo = failedContainers[containerKey]
    if not failInfo then return true end
    
    local maxRetries = JustQuest.Constants.LIMITS.CONTAINER_MAX_RETRIES
    if failInfo.retryCount >= maxRetries then
        return false
    end
    
    local timeSinceFailure = GetTime() - failInfo.lastAttempt
    local minWaitTime = 1.0 * (2 ^ (failInfo.retryCount - 1))
    return timeSinceFailure >= minWaitTime
end

local function MarkContainerFailed(containerKey, reason)
    local maxRetries = JustQuest.Constants.LIMITS.CONTAINER_MAX_RETRIES
    local info = failedContainers[containerKey]
    if not info then
        failedContainers[containerKey] = {retryCount = 1, lastAttempt = GetTime(), firstFailureTime = GetTime(), lastReason = reason}
    else
        info.retryCount = info.retryCount + 1
        info.lastAttempt = GetTime()
        info.lastReason = reason
    end
end

local function ClearContainerFailure(containerKey)
    failedContainers[containerKey] = nil
end

local function ReduceAllFailurePenalties()
    local reduced = 0
    local cleared = 0
    for key, info in pairs(failedContainers) do
        if info.retryCount > 0 then
            info.retryCount = info.retryCount - 1
            
            -- If retry count reaches 0, clear the failure entirely
            if info.retryCount == 0 then
                failedContainers[key] = nil
                cleared = cleared + 1
            else
                -- Reset timer to allow immediate retry with new backoff
                info.lastAttempt = GetTime() - 1.0
                reduced = reduced + 1
            end
        end
    end
end

local function CleanupFailedContainers()
    local currentTime = GetTime()
    local cleaned = 0
    local maxRetries = JustQuest.Constants.LIMITS.CONTAINER_MAX_RETRIES
    local cleanupInterval = JustQuest.Constants.TIMING.CONTAINER_CLEANUP_INTERVAL
    local staleTimeout = JustQuest.Constants.TIMING.CONTAINER_STALE_TIMEOUT
    
    for key, info in pairs(failedContainers) do
        local stale = (info.retryCount >= maxRetries) or 
                     (currentTime - info.lastAttempt > cleanupInterval) or 
                     (currentTime - info.firstFailureTime > staleTimeout)
        
        if stale then
            failedContainers[key] = nil
            cleaned = cleaned + 1
        end
    end
    
    return cleaned
end

-- Rogue auto-pick: cast Pick Lock on a locked box and apply it to the slot; a pickable box
-- unlocks async (ITEM_LOCK_CHANGED) and the normal open path loots it on the next scan.
-- Gated: "all" mode only, opted in, Rogue who knows the spell, never in combat. It's
-- attempt-based (no lock-type data needed) — a key-required or too-high-skill box simply
-- doesn't unlock and burns its retry budget (see the caller), then is left alone. The cast
-- is pcall'd because a non-hardware-event cast can be blocked. (Needs in-game validation.)
local function TryPickLock(bagID, slotID)
    if not (configCache.rogueAutoPick and configCache.mode == "all") then return false end
    if InCombatLockdown() then return false end
    if not (IsSpellKnown and IsSpellKnown(PICK_LOCK_SPELL)) then return false end

    -- pcall result is intentionally ignored: whether the cast takes effect or is blocked, we
    -- return "attempted" so the caller charges a retry — that's what bounds attempts on a box
    -- that can't actually be picked (key-required, too-high skill, or a blocked cast).
    pcall(function()
        if C_Spell and C_Spell.CastSpellByID then
            C_Spell.CastSpellByID(PICK_LOCK_SPELL)
        elseif CastSpellByID then
            CastSpellByID(PICK_LOCK_SPELL)
        end
        C_Container.UseContainerItem(bagID, slotID)  -- applies the pending pick to this box
    end)
    return true
end

-- Returns true = opened this item (stop the scan), nil = stop the scan (busy/combat/failure),
-- false = not this one, continue to the next bag item.
local function ProcessContainerItem(bagID, slotID, info, currentTime)
    -- Check state FIRST — quest/gossip automation may start between scan and here.
    local safety = GetSafetyEngine()
    if not (safety and safety.IsState("IDLE")) then return nil end

    local itemID = info.itemID
    if IsDangerousContainer(itemID) then return false end  -- user blacklist
    if not ShouldOpen(info) then return false end

    local containerKey = GetContainerKey(bagID, slotID, itemID)

    -- On cooldown (e.g. just used) — try a later scan.
    local itemStart, itemDuration = C_Container.GetContainerItemCooldown(bagID, slotID)
    if itemStart and itemStart > 0 and itemDuration and itemDuration > 0 then
        return false
    end

    if info.isLocked then
        -- Rogue auto-pick (retry-bounded): a pickable box unlocks and opens on a later scan; a
        -- box that can't be picked charges its retry budget, then waits like any locked box.
        if ShouldRetryContainer(containerKey) and TryPickLock(bagID, slotID) then
            MarkContainerFailed(containerKey, "pick_attempt")
            -- Pick Lock unlocks async and (unlike a key) consumes nothing, so no BAG_UPDATE
            -- follows to re-scan. Schedule one (debounced) so the unlocked box gets opened.
            local services = GetServices()
            if services and services.ScheduleOnce then
                services.ScheduleOnce("container_pick_rescan", 1.0, ContainerEngine.OnBagUpdateDelayed)
            end
        end
        return false
    end

    if not ShouldRetryContainer(containerKey) then return false end
    if InCombatLockdown() then return nil end

    local success, err = pcall(C_Container.UseContainerItem, bagID, slotID)
    if success then
        -- UseContainerItem() reports success even if nothing opened, so we confirm the open via
        -- pendingContainerUnlock + ITEM_LOCK_CHANGED rather than trusting this call.
        ClearContainerFailure(containerKey)
        ReduceAllFailurePenalties()
        expectedContainers[itemID] = nil
        pendingContainerUnlock = { bagID = bagID, slotID = slotID, itemID = itemID, timestamp = GetTime() }
        return true
    end

    local errStr = tostring(err)
    if errStr:find("Action only available") or errStr:find("protected") or errStr:find("taint") then
        -- Protected/taint failure won't clear on retry — spend the whole budget at once.
        failedContainers[containerKey] = {
            retryCount = JustQuest.Constants.LIMITS.CONTAINER_MAX_RETRIES,
            lastAttempt = currentTime,
            firstFailureTime = GetTime(),
            lastReason = "Protected",
        }
    else
        MarkContainerFailed(containerKey, errStr)
    end
    return nil  -- stop this scan on a failure
end

function ContainerEngine.OpenBagContainers()
    if InCombatLockdown() then 
        return 
    end
    
    -- Don't open containers during quest/gossip automation — UseContainerItem()
    -- can taint protected frames via hardware event. Stuck-BUSY cleanup is owned
    -- by SafetyEngine's periodic recovery (state-aware, honors the currency
    -- prompt); here we just wait it out.
    local safety = GetSafetyEngine()
    if safety and safety.IsBusy() then
        return
    end
    
    local config = GetConfig()
    if not (config and config.Get(nil, "enabled")) then 
        return 
    end
    if not IsContainerOpeningEnabled() then 
        return 
    end
    
    local services = GetServices()
    if not services then 
        return 
    end
    
    local canAutomate = services.ValidateAutomationPreconditions()
    if not canAutomate then 
        return 
    end
    
    -- Check if bag sorting is in progress (addon or manual)
    if IsBagSortingActive() then
        return
    end
    
    local currentTime = GetTime()
    
    -- Bypass throttle if expecting a container from quest rewards
    local hasExpectedContainer = false
    for itemID, info in pairs(expectedContainers) do
        if currentTime - info.timestamp > 10.0 then
            expectedContainers[itemID] = nil
        else
            hasExpectedContainer = true
        end
    end
    
    if not hasExpectedContainer and currentTime - lastOpenTime < GetThrottleDelay() then 
        return 
    end
    
    -- One open is in flight: wait for ITEM_LOCK_CHANGED to confirm it before scanning again.
    -- If that event is missed, resolve here — the item is gone/changed/unlocked, or a 1.0s
    -- timeout gives up (don't mark failed: it may have opened).
    if pendingContainerUnlock and pendingContainerUnlock.timestamp then
        if currentTime - pendingContainerUnlock.timestamp > 1.0 then
            pendingContainerUnlock = nil
        else
            local info = C_Container.GetContainerItemInfo(pendingContainerUnlock.bagID, pendingContainerUnlock.slotID)
            if not info or info.itemID ~= pendingContainerUnlock.itemID or not info.isLocked then
                pendingContainerUnlock = nil  -- consumed, moved, or unlocked
            else
                return  -- still locked and waiting — skip this scan
            end
        end
    end

    local cleanupInterval = JustQuest.Constants.TIMING.CONTAINER_CLEANUP_INTERVAL
    if currentTime - lastScanTime > cleanupInterval then
        CleanupFailedContainers()
        lastScanTime = currentTime
    end

    for bagID, slotID, info in ForEachBagItem() do
        local result = ProcessContainerItem(bagID, slotID, info, currentTime)
        if result == true then
            lastOpenTime = currentTime
            local svc = GetServices()
            if svc and svc.NoteAutomation then svc.NoteAutomation("containers") end
            break
        elseif result == nil then
            break  -- stop (busy/combat/failure)
        end
        -- false = continue to the next bag item
    end
end

-- ============================================================
-- Event Handlers
-- ============================================================

function ContainerEngine.OnBagUpdateDelayed()
    -- Track BAG_UPDATE_DELAYED for sort detection even when we skip opening.
    -- Recorded once here; OpenBagContainers only READS the state (IsBagSortingActive).
    RecordBagUpdate()

    if isProcessing then
        return
    end
    
    isProcessing = true
    pcall(ContainerEngine.OpenBagContainers)
    isProcessing = false
end

function ContainerEngine.ExpectContainer(itemID, itemName)
    -- Prepare for immediate opening when the item lands in bags (resets throttle)
    if not itemID then return end
    
    expectedContainers[itemID] = {
        itemID = itemID,
        name = itemName or "Unknown",
        timestamp = GetTime(),
    }
    
    lastOpenTime = 0
end

function ContainerEngine.OnQuestTurnedIn()
    -- Reset throttle so containers from quest rewards are opened immediately
    lastOpenTime = 0
end

function ContainerEngine.OnAutomationComplete()
    -- Called when state transitions to IDLE — wait for safe idle time before scanning
    -- to ensure all quest/gossip automation has fully finished.
    if not IsContainerOpeningEnabled() then return end
    
    local safety = GetSafetyEngine()
    if not (safety and safety.IsState("IDLE")) then
        return
    end
    
    local currentTime = GetTime()
    local hasExpected = false
    for itemID, info in pairs(expectedContainers) do
        if currentTime - info.timestamp > 10.0 then
            expectedContainers[itemID] = nil
        else
            hasExpected = true
        end
    end
    
    -- Only scan if we have expected containers
    if hasExpected then
        -- Wait for safe idle time to confirm automation has fully finished
        local services = GetServices()
        local scanDelay = services and services.GetTiming and services.GetTiming("CONTAINER_SCAN_AFTER_AUTOMATION", 0.25) or 0.25
        if services and services.ScheduleOnce then
            services.ScheduleOnce("container_scan_after_automation_container", scanDelay, function()
                -- Verify state is still IDLE with sufficient idle time
                local s = GetSafetyEngine()
                local stateTime = s and s.GetStateTime() or 0
                if not (s and s.IsState("IDLE")) then
                    return
                end

                if stateTime < scanDelay then
            -- Reschedule for remaining time
                    services.ScheduleOnce("container_scan_after_automation_container", scanDelay - stateTime + 0.01, function()
                        local s2 = GetSafetyEngine()
                        if s2 and s2.IsState("IDLE") then
                            ContainerEngine.OnBagUpdateDelayed()
                        end
                    end)
                else
                    ContainerEngine.OnBagUpdateDelayed()
                end
            end)
        else
            -- Fallback: immediate scan if no scheduler
            ContainerEngine.OnBagUpdateDelayed()
        end
    end
end

function ContainerEngine.OnItemLockChanged(bagID, slotID)
    if not (bagID and slotID) then return end

    -- Guard the read like every other GetContainerItemInfo call in this file:
    -- ITEM_LOCK_CHANGED reaches here straight from OnEvent with no outer pcall.
    local ok, info = pcall(C_Container.GetContainerItemInfo, bagID, slotID)
    if not ok then return end

    -- Handle case where item is consumed/moved (info is nil)
    if not info then
        -- Item no longer exists - check if this was our pending container
        if pendingContainerUnlock and 
           pendingContainerUnlock.bagID == bagID and 
           pendingContainerUnlock.slotID == slotID then
            
    -- Clear the pending state
            pendingContainerUnlock = nil
            
            lastOpenTime = 0
            
            if not isProcessing then
                ContainerEngine.OnBagUpdateDelayed()
            end
        end
        return
    end
    
    -- Our pending open resolves when that box unlocks — clear it and rescan.
    if not info.isLocked
       and pendingContainerUnlock
       and pendingContainerUnlock.bagID == bagID
       and pendingContainerUnlock.slotID == slotID
       and pendingContainerUnlock.itemID == info.itemID then
        pendingContainerUnlock = nil
        lastOpenTime = 0
        if not isProcessing then
            ContainerEngine.OnBagUpdateDelayed()
        end
    end
end

local eventFrame = CreateFrame("Frame")

function ContainerEngine.Initialize()
    UpdateConfigCache()
    
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
    eventFrame:RegisterEvent("QUEST_TURNED_IN")

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "BAG_UPDATE_DELAYED" then
            ContainerEngine.OnBagUpdateDelayed()
        elseif event == "ITEM_LOCK_CHANGED" then
            local bagID, slotID = ...
            ContainerEngine.OnItemLockChanged(bagID, slotID)
        elseif event == "QUEST_TURNED_IN" then
            ContainerEngine.OnQuestTurnedIn()
        end
    end)
    
    -- Start periodic scan to catch missed containers
    local services = GetServices()
    if services and services.ScheduleRepeating then
        local scanInterval = JustQuest.Constants.TIMING.CONTAINER_PERIODIC_SCAN or 30
        services.ScheduleRepeating("container_periodic_scan", scanInterval, function()
            -- Only scan if not in combat and not busy with automation
            local safety = GetSafetyEngine()
            if not InCombatLockdown() and not (safety and safety.IsBusy()) then
                ContainerEngine.OnBagUpdateDelayed()
            end
        end)
    end
end

function ContainerEngine.OnDisable()
    local services = GetServices()
    if services and services.CancelScheduled then
        services.CancelScheduled("container_initial_scan")
        services.CancelScheduled("container_periodic_scan")
        services.CancelScheduled("container_retry_after_automation")
        services.CancelScheduled("container_scan_after_automation_container")
    end
    
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
    end
    
    lastOpenTime = 0
    isProcessing = false
    failedContainers = {}
    lastScanTime = 0
    pendingContainerUnlock = nil
    lastBagUpdateTime = 0
    bagUpdateCount = 0
    isBagSortActive = false
end

-- ============================================================
-- Public API
-- ============================================================

-- Refresh config cache when settings change
function ContainerEngine.RefreshConfigCache()
    UpdateConfigCache()
end

-- ============================================================
-- Module Registration
-- ============================================================

JustQuest.Core.RegisterModule("ContainerEngine", ContainerEngine, {"Config", "Services", "SafetyEngine"})

return ContainerEngine
