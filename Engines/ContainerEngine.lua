-- ContainerEngine.lua — Automated container opening for quest rewards and loot containers

local ADDON_NAME, JustQuest = ...

local SAFE_CONTAINERS = JustQuest.Database.SAFE_CONTAINERS
local DANGEROUS_CONTAINERS = JustQuest.Database.DANGEROUS_CONTAINERS

local ContainerEngine = {}

-- Module cache (lazy initialization)
local moduleCache = {}

-- ============================================================
-- Helper Functions
-- ============================================================

local function GetSafetyEngine()
    if not moduleCache.SafetyEngine then
        moduleCache.SafetyEngine = JustQuest.Core.GetModule("SafetyEngine")
    end
    return moduleCache.SafetyEngine
end

local function GetServices()
    if not moduleCache.Services then
        moduleCache.Services = JustQuest.Core.GetModule("Services")
    end
    return moduleCache.Services
end

local function GetConfig()
    if not moduleCache.Config then
        moduleCache.Config = JustQuest.Core.GetModule("Config")
    end
    return moduleCache.Config
end

-- (tooltip hook removed)

local lastOpenTime = 0
local isProcessing = false
local failedContainers = {}
local lastScanTime = 0
local lastCleanupTime = 0
local containerLockState = {}
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
    useDatabaseFallback = false,
    lastUpdate = 0,
}

local function UpdateConfigCache()
    local config = GetConfig()
    if not config then return end
    
    configCache.enabled = config.Get("containers", "enabled") or false
    configCache.whitelist = config.Get("containers", "whitelist") or {}
    configCache.blacklist = config.Get("containers", "blacklist") or {}
    configCache.useDatabaseFallback = config.Get("containers", "useDatabaseFallback") or false
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
                        coroutine.yield(bagID, slotID, info.itemID)
                    end
                end
            end
        end
    end)
end

-- User-driven whitelist system - simplified from monolithic database
-- Users add containers they want automated, remove ones that cause issues
local function IsSafeContainer(itemID)
    -- Check user whitelist (primary system)
    if configCache.whitelist[itemID] then
        return true
    end
    
    -- Optional: Fallback to database if user hasn't customized
    if configCache.useDatabaseFallback and SAFE_CONTAINERS then
        return SAFE_CONTAINERS[itemID] ~= nil
    end
    
    return false
end

local function IsDangerousContainer(itemID)
    -- User blacklist overrides everything
    if configCache.blacklist[itemID] then
        return true
    end
    
    -- Optional: Check known dangerous containers if database enabled
    if configCache.useDatabaseFallback and DANGEROUS_CONTAINERS then
        return DANGEROUS_CONTAINERS[itemID] ~= nil
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

-- Detect bag sorting by tracking rapid BAG_UPDATE events (addon sorters or manual moves)
local function IsBagSortingActive()
    local currentTime = GetTime()
    
    if isBagSortActive and currentTime - lastBagUpdateTime > 2.0 then
        isBagSortActive = false
        bagUpdateCount = 0
        return false
    end
    
    -- BAG_UPDATE from our own container opening — don't count toward sort detection
    if pendingContainerUnlock and (currentTime - pendingContainerUnlock.timestamp < 2.0) then
        lastBagUpdateTime = currentTime
        return isBagSortActive
    end
    
    -- BAG_UPDATE while expecting quest reward containers — not sorting
    if next(expectedContainers) then
        lastBagUpdateTime = currentTime
        return isBagSortActive
    end
    
    if currentTime - lastBagUpdateTime < 0.5 then
        bagUpdateCount = bagUpdateCount + 1
        
        if bagUpdateCount >= 3 then
            if not isBagSortActive then
                isBagSortActive = true
            end
            lastBagUpdateTime = currentTime
            return true
        end
    else
        bagUpdateCount = 1
    end
    
    lastBagUpdateTime = currentTime
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

local function MarkContainerLocked(containerKey)
    containerLockState[containerKey] = GetTime()
end

local function ClearContainerLock(containerKey)
    containerLockState[containerKey] = nil
end

local function CleanupStaleLocks()
    local currentTime = GetTime()
    local LOCK_TIMEOUT = 2.0
    
    if not next(containerLockState) then return end
    
    -- Quick pass every call, full bag validation every ~5s
    if currentTime - lastCleanupTime < 5.0 then
        for key, lockTime in pairs(containerLockState) do
            if currentTime - lockTime > LOCK_TIMEOUT then
                containerLockState[key] = nil
            end
        end
        return
    end
    
    lastCleanupTime = currentTime
    
    local validItems = {}
    for bagID, slotID, itemID in ForEachBagItem() do
        validItems[GetContainerKey(bagID, slotID, itemID)] = true
    end
    
    local cleaned = 0
    for key, lockTime in pairs(containerLockState) do
        local isStale = not validItems[key] or (currentTime - lockTime > LOCK_TIMEOUT)
        if isStale then
            containerLockState[key] = nil
            cleaned = cleaned + 1
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

local function ProcessContainerItem(bagID, slotID, itemID, currentTime, skippedLocked, skippedRetry)
    -- Check state FIRST — quest/gossip automation may start between scan and here
    local safety = GetSafetyEngine()
    if not (safety and safety.IsState("IDLE")) then
        return nil, skippedLocked, skippedRetry
    end
    
    if IsDangerousContainer(itemID) then
        return false, skippedLocked, skippedRetry
    end
    
    if not IsSafeContainer(itemID) then
        return false, skippedLocked, skippedRetry
    end
    
    local containerKey = GetContainerKey(bagID, slotID, itemID)
    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    
    if not info then
        ClearContainerFailure(containerKey)
        ClearContainerLock(containerKey)
        return false, skippedLocked, skippedRetry
    end
    
    local itemStart, itemDuration, itemEnable = C_Container.GetContainerItemCooldown(bagID, slotID)
    if itemStart and itemStart > 0 and itemDuration and itemDuration > 0 then
        return false, skippedLocked, skippedRetry + 1
    end
    
    if info.isLocked then
        MarkContainerLocked(containerKey)
        return false, skippedLocked + 1, skippedRetry
    end
    
    -- Stale lock (>2s old, item not actually locked) — clear and proceed
    if containerLockState[containerKey] then
        local lockAge = GetTime() - containerLockState[containerKey]
        if lockAge > 2.0 then
            ClearContainerLock(containerKey)
        else
            return false, skippedLocked + 1, skippedRetry
        end
    end
    ClearContainerLock(containerKey)
    
    if not ShouldRetryContainer(containerKey) then
        return false, skippedLocked, skippedRetry + 1
    end
    
    if InCombatLockdown() then
        return nil, skippedLocked, skippedRetry
    end
    
    local success, err = pcall(C_Container.UseContainerItem, bagID, slotID)
    
    if success then
        -- UseContainerItem() succeeds even if item can't be opened,
        -- so we use pending state + ITEM_LOCK_CHANGED to confirm.
        ClearContainerFailure(containerKey)
        ReduceAllFailurePenalties()
        
        -- Clear expected container if this was one we were waiting for
        if expectedContainers[itemID] then
            expectedContainers[itemID] = nil
        end
        
        -- Optimistic: set pending before lock is confirmed
        pendingContainerUnlock = {
            bagID = bagID,
            slotID = slotID,
            itemID = itemID,
            timestamp = GetTime(),
        }
        
        return true, skippedLocked, skippedRetry
    else
        local errStr = tostring(err)
        local maxRetries = JustQuest.Constants.LIMITS.CONTAINER_MAX_RETRIES
        
        if errStr:find("Action only available") or errStr:find("protected") or errStr:find("taint") then
            failedContainers[containerKey] = {
                retryCount = maxRetries, 
                lastAttempt = currentTime, 
                firstFailureTime = GetTime(), 
                lastReason = "Protected"
            }
        else
            MarkContainerFailed(containerKey, errStr)
        end
        
        return nil, skippedLocked, skippedRetry
    end
end

function ContainerEngine.OpenBagContainers()
    if InCombatLockdown() then 
        return 
    end
    
    -- Don't open containers during quest/gossip automation —
    -- UseContainerItem() can taint protected frames via hardware event
    local safety = GetSafetyEngine()
    if safety and safety.IsBusy() then
        local state = safety.GetState()
        local stateTime = safety.GetStateTime()
        
        -- Only validate frames if stuck >5s to avoid expensive IsShown() calls on every scan
        if stateTime > 5.0 then
            local frameActuallyOpen = false
            
            if state == "QUEST" then
                frameActuallyOpen = (QuestFrame and QuestFrame:IsShown()) or 
                                   (QuestLogPopupDetailFrame and QuestLogPopupDetailFrame:IsShown())
            elseif state == "GOSSIP" then
                frameActuallyOpen = (GossipFrame and GossipFrame:IsShown())
            elseif state == "CONFIRM" then
                frameActuallyOpen = (StaticPopup1 and StaticPopup1:IsShown()) or
                                   (QuestFrame and QuestFrame:IsShown()) or
                                   (GossipFrame and GossipFrame:IsShown())
            end
            
            if not frameActuallyOpen then
                Debug(string.format("Stuck state recovery: %s for %.1fs with no frame", state, stateTime))
                local safetyEngine = GetSafetyEngine()
                if safetyEngine then
                    safetyEngine.EndProcessing("container_stuck_state_recovery")
                end
            end
        end
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
    
    local canAutomate, reason = services.ValidateAutomationPreconditions()
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
    
    -- If ITEM_LOCK_CHANGED is missed, pendingContainerUnlock can block all processing.
    -- Timeout at 1.0s (reduced from 2.0s) for faster recovery.
    if pendingContainerUnlock and pendingContainerUnlock.timestamp then
        local pendingAge = currentTime - pendingContainerUnlock.timestamp
        if pendingAge > 1.0 then
            local key = GetContainerKey(
                pendingContainerUnlock.bagID,
                pendingContainerUnlock.slotID,
                pendingContainerUnlock.itemID
            )
            ClearContainerLock(key)
            
            -- Don't mark as failed: may have succeeded but event was missed
            pendingContainerUnlock = nil
        else
            -- Still waiting for unlock event, but check if item still exists
            local info = C_Container.GetContainerItemInfo(pendingContainerUnlock.bagID, pendingContainerUnlock.slotID)
            if not info or info.itemID ~= pendingContainerUnlock.itemID then
                -- Container was consumed (success!) or moved - clear pending state
                pendingContainerUnlock = nil
            elseif not info.isLocked then
                -- Container unlocked but event didn't fire - clear and continue
                local key = GetContainerKey(
                    pendingContainerUnlock.bagID,
                    pendingContainerUnlock.slotID,
                    pendingContainerUnlock.itemID
                )
                ClearContainerLock(key)
                pendingContainerUnlock = nil
            else
                -- Still locked and waiting - skip this scan
                return
            end
        end
    end
    
    local cleanupInterval = JustQuest.Constants.TIMING.CONTAINER_CLEANUP_INTERVAL
    if currentTime - lastScanTime > cleanupInterval then
        CleanupFailedContainers()
        lastScanTime = currentTime
    end
    
    CleanupStaleLocks()
    
    local openedAny = false
    local itemsFound = 0
    local skippedRetry = 0
    local skippedLocked = 0
    
    for bagID, slotID, itemID in ForEachBagItem() do
        itemsFound = itemsFound + 1
        
        local result, newSkippedLocked, newSkippedRetry = ProcessContainerItem(bagID, slotID, itemID, currentTime, skippedLocked, skippedRetry)
        
        -- Update skip counters if returned
        if newSkippedLocked then skippedLocked = newSkippedLocked end
        if newSkippedRetry then skippedRetry = newSkippedRetry end
        
        if result == true then
            -- Successfully opened container
            lastOpenTime = currentTime
            openedAny = true
            break
        elseif result == nil then
            -- Stop processing (combat or failure)
            break
        end
        -- result == false means continue to next item
    end
    
    if openedAny or skippedLocked > 0 or skippedRetry > 0 then
        -- Scan completed with results
    end
end

-- ============================================================
-- Event Handlers
-- ============================================================

function ContainerEngine.OnBagUpdateDelayed()
    -- Track BAG_UPDATE_DELAYED for sort detection even when we skip opening
    IsBagSortingActive()
    
    if isProcessing then
        return
    end
    
    isProcessing = true
    pcall(ContainerEngine.OpenBagContainers)
    isProcessing = false
end

function ContainerEngine.OnPlayerEnteringWorld()
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
    
    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    
    -- ⚡ FIX: Handle case where item is consumed/moved (info is nil)
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
    
    local containerKey = GetContainerKey(bagID, slotID, info.itemID)
    
    if info.isLocked then
        MarkContainerLocked(containerKey)
    else
        ClearContainerLock(containerKey)
        
        if pendingContainerUnlock and 
           pendingContainerUnlock.bagID == bagID and 
           pendingContainerUnlock.slotID == slotID and
           pendingContainerUnlock.itemID == info.itemID then
            
            pendingContainerUnlock = nil
            lastOpenTime = 0
            
            if not isProcessing then
                ContainerEngine.OnBagUpdateDelayed()
            end
        end
    end
end

function ContainerEngine.ScanNow()
    ContainerEngine.OnBagUpdateDelayed()
end

-- ============================================================
-- Tooltip Enhancement
-- ============================================================

-- Show whitelist/blacklist status in tooltips
-- Tooltip UI enhancement removed: no runtime tooltip hooks

local eventFrame = CreateFrame("Frame")

function ContainerEngine.Initialize()
    UpdateConfigCache()
    
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
    eventFrame:RegisterEvent("QUEST_TURNED_IN")
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "BAG_UPDATE_DELAYED" then
            ContainerEngine.OnBagUpdateDelayed()
        elseif event == "PLAYER_ENTERING_WORLD" then
            ContainerEngine.OnPlayerEnteringWorld()
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
    containerLockState = {}
    lastScanTime = 0
    lastCleanupTime = 0
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

function ContainerEngine.AddSafeContainer(itemID, name)
    local config = GetConfig()
    if config and config.AddContainerWhitelist then
        config.AddContainerWhitelist(itemID, name)
    end
end

function ContainerEngine.RemoveSafeContainer(itemID)
    local config = GetConfig()
    if config and config.RemoveContainerWhitelist then
        config.RemoveContainerWhitelist(itemID)
    end
end

function ContainerEngine.IsSafeContainer(itemID)
    return IsSafeContainer(itemID)
end

function ContainerEngine.GetSafeContainers()
    local config = GetConfig()
    if config then
        return config.Get("containers", "whitelist") or {}
    end
    return {}
end

function ContainerEngine.GetDangerousContainers()
    local config = GetConfig()
    if config then
        return config.Get("containers", "blacklist") or {}
    end
    return {}
end

-- Reset notification throttle (useful for testing/debugging)
function ContainerEngine.ResetNotifications()
    -- Notification system removed - keeping function for compatibility
end

-- Debug function to inspect internal state
function ContainerEngine.GetDebugInfo()
    local config = GetConfig()
    local services = GetServices()
    
    local failedCount = 0
    for _ in pairs(failedContainers) do
        failedCount = failedCount + 1
    end
    
    local lockedCount = 0
    for _ in pairs(containerLockState) do
        lockedCount = lockedCount + 1
    end
    
    return {
        enabled = IsContainerOpeningEnabled(),
        addonEnabled = config and config.Get(nil, "enabled") or false,
        containerEnabled = config and config.Get("containers", "enabled") or false,
        canAutomate = services and services.CanAutomateContainers() or false,
        isProcessing = isProcessing,
        -- tooltipHookAvailable removed
        lastOpenTime = lastOpenTime,
        timeSinceLastOpen = GetTime() - lastOpenTime,
        throttleDelay = GetThrottleDelay(),
        failedCount = failedCount,
        lockedCount = lockedCount,
        inCombat = InCombatLockdown(),
    }
end

-- ============================================================
-- Module Registration
-- ============================================================

JustQuest.Core.RegisterModule("ContainerEngine", ContainerEngine, {"Config", "Services", "SafetyEngine"})

return ContainerEngine
