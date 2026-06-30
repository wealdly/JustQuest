-- SafetyEngine.lua — State machine, loop prevention, gossip option validation

local ADDON_NAME, JustQuest = ...

local SafetyEngine = {}

-- Hot path locals
local GetTime = GetTime
local pcall = pcall
local wipe = wipe

-- ============================================================
-- State Management (IDLE / BUSY)
-- ============================================================

local state = "IDLE"
local stateReason = nil
local stateStartTime = GetTime()

-- Recent gossip-option selections for the CURRENT npc (loop prevention).
-- Not keyed by GUID: under addon taint UnitGUID returns a "secret value" that
-- cannot be used as a table key. Only one gossip NPC is active at a time, so a
-- single history suffices; it is cleared on NPC change / gossip close.
local selectionHistory = {}
local statusAvailable      = nil
local statusAlreadyComplete = nil

-- Memoized module accessors
local GetServices = JustQuest.Core.ModuleGetter("Services")
local GetConfig   = JustQuest.Core.ModuleGetter("Config")
local GetGameData = JustQuest.Core.ModuleGetter("GameData")

local function DebugSafety(msg)
    local services = GetServices()
    if services then
        services.Debug("Safety", msg)
    end
end

-- ============================================================
-- State API
-- ============================================================

function SafetyEngine.SetState(newState, reason)
    local oldState = state
    newState = newState or "IDLE"

    if oldState ~= newState then
        local services = GetServices()
        if services and services.Debug then
            services.Debug("State", string.format("%s -> %s (%s)", oldState, newState, reason or ""))
        end
        stateStartTime = GetTime()

        -- Trigger container processing when automation completes
        if newState == "IDLE" and oldState == "BUSY" then
            local containerEngine = JustQuest.Core.GetModule("ContainerEngine")
            if containerEngine and containerEngine.OnAutomationComplete then
                containerEngine.OnAutomationComplete()
            end
        end
    end

    state = newState
    stateReason = reason
end

function SafetyEngine.GetState()
    return state
end

function SafetyEngine.GetReason()
    return stateReason
end

function SafetyEngine.GetStateTime()
    return GetTime() - stateStartTime
end

function SafetyEngine.IsBusy()
    return state == "BUSY"
end

function SafetyEngine.IsState(checkState)
    return state == checkState
end

-- ============================================================
-- List Management
-- ============================================================

local whitelistSet = {}
local blacklistSet = {}

function SafetyEngine.RebuildLists()
    wipe(whitelistSet)
    wipe(blacklistSet)

    local config = GetConfig()
    local services = GetServices()
    if not config then return end

    local wl = config.Get("gossip", "whitelist") or {}
    local bl = config.Get("gossip", "blacklist") or {}

    for i = 1, #wl do
        local normalized = services and services.NormalizeListEntry(wl[i]) or wl[i]
        if normalized then
            whitelistSet[normalized] = true
        end
    end

    for i = 1, #bl do
        local normalized = services and services.NormalizeListEntry(bl[i]) or bl[i]
        if normalized then
            blacklistSet[normalized] = true
        end
    end


end

-- ============================================================
-- Initialization
-- ============================================================

function SafetyEngine.Initialize()
    local services = GetServices()
    local getEnum = services and services.GetEnumValue or function(n,k) return Enum[n] and Enum[n][k] end

    statusAvailable      = getEnum("GossipOptionStatus", "Available")
    statusAlreadyComplete = getEnum("GossipOptionStatus", "AlreadyComplete")

    SafetyEngine.RebuildLists()

    -- Periodic stuck-state recovery
    if services and services.ScheduleRepeating then
        services.ScheduleRepeating("safety_stuck_state_recovery", 1.0, function()
            if state ~= "BUSY" then return end

            -- The currency-spend prompt is a deliberate, open-ended wait on the
            -- player; its own popup handlers release the state. Never time it out.
            if stateReason == "waiting_currency_prompt" then return end

            local config = GetConfig()
            local timeout = config and config.Get("advanced", "autoRecoveryTimeout") or JustQuest.Constants.TIMING.AUTO_RECOVERY_TIMEOUT
            local timeSinceActivity = GetTime() - (JustQuest._lastProcessingTime or 0)
            local frameOpen = services.IsInteractionFrameOpen()

            -- Fast mode hides the quest/gossip frame (alpha 0) while automating.
            -- The instant automation stalls, un-hide it so the player is never left
            -- staring at an invisible, un-clickable window (the "walk away to
            -- force-close it" trap) — well before the slower full reset below.
            -- Normal steps are sub-second apart, so a >0.75s gap means stalled.
            if timeSinceActivity > 0.75 then
                services.RestoreAutomationFrames()
            end

            -- Recover when the frame is already closed (fast path), OR when
            -- automation has stalled past the full timeout even with a frame
            -- still open. The frame-open stall is the "stuck at turn-in" case:
            -- a missed QUEST_COMPLETE/QUEST_TURNED_IN leaves us BUSY with the
            -- quest frame up. Recovery used to require the player to walk away
            -- (closing the frame) before it would fire.
            if (not frameOpen and timeSinceActivity > 1.0) or timeSinceActivity > timeout then
                if services.Debug then
                    services.Debug("Safety", string.format("Periodic recovery: BUSY %s (%.1fs idle, frame=%s)",
                        stateReason or "?", timeSinceActivity, frameOpen and "open" or "closed"))
                end
                -- Repump so a still-open quest/gossip frame is re-processed
                -- instead of sitting idle until the next event.
                SafetyEngine.EndProcessing("periodic_stuck_recovery", true)
            end
        end)
    end
end

-- ============================================================
-- Gossip Option Validation
-- ============================================================

function SafetyEngine.OptionIsAvailable(option)
    if not option then return false end
    if not option.gossipOptionID and not option.orderIndex then return false end

    local status = option.status
    if status then
        if not statusAvailable and not statusAlreadyComplete then
            return true
        end
        return status == statusAvailable or status == statusAlreadyComplete
    end

    return true
end


-- ============================================================
-- Repeat/Selection Tracking (loop prevention)
-- ============================================================

function SafetyEngine.ShouldSkipRepeat(optionID, totalOptions)
    if not optionID or #selectionHistory == 0 then return false end

    local config = GetConfig()
    local ttl = config and config.Get("advanced", "gossipRepeatWindow") or JustQuest.Constants.TIMING.GOSSIP_REPEAT_WINDOW

    -- Reduce TTL for single options (likely "back" navigation)
    if totalOptions and totalOptions == 1 then
        ttl = ttl * 0.25
    end

    local now = GetTime()
    for _, entry in ipairs(selectionHistory) do
        if entry.optionID == optionID and (now - entry.time) < ttl then
            DebugSafety(string.format("Repeat blocked: optionID=%s, %.2fs ago, ttl=%.2fs",
                tostring(optionID), now - entry.time, ttl))
            return true
        end
    end

    return false
end

function SafetyEngine.MarkSelection(optionID)
    if not optionID then return end

    local now = GetTime()
    local config = GetConfig()
    local ttl = config and config.Get("advanced", "gossipRepeatWindow") or JustQuest.Constants.TIMING.GOSSIP_REPEAT_WINDOW

    -- Prune expired entries in-place to avoid allocating a new table each call.
    local h = selectionHistory
    local write = 0
    for read = 1, #h do
        if (now - h[read].time) < ttl then
            write = write + 1
            h[write] = h[read]
        end
    end
    for i = write + 1, #h do h[i] = nil end

    -- Append new entry and cap history at 20.
    h[write + 1] = { optionID = optionID, time = now }
    while #h > 20 do table.remove(h, 1) end
end

-- Clear selection history (NPC changed or gossip closed).
function SafetyEngine.ClearSelections()
    wipe(selectionHistory)
end

-- ============================================================
-- Whitelist/Blacklist Checking
-- ============================================================

function SafetyEngine.IsWhitelisted(option)
    if not (option and option.name) then return false end

    local services = GetServices()
    if not services then return false end

    local cleanText = services.CleanText(option.name)

    if whitelistSet[cleanText] then return true end

    for entry in pairs(whitelistSet) do
        if cleanText:find(entry, 1, true) then return true end
    end

    return false
end

function SafetyEngine.IsBlacklisted(option)
    if not (option and option.name) then return false end

    local services = GetServices()
    if not services then return false end

    local cleanText = services.CleanText(option.name)

    for entry in pairs(blacklistSet) do
        if cleanText:find(entry, 1, true) then
            DebugSafety(string.format("Blacklist match: '%s' ~ '%s'", cleanText, entry))
            return true
        end
    end

    return false
end

-- ============================================================
-- Chain Depth Protection
-- ============================================================

function SafetyEngine.ValidateChainDepth(currentDepth)
    local config = GetConfig()
    local maxDepth = config and config.Get("advanced", "chainDepth") or JustQuest.Constants.LIMITS.CHAIN_DEPTH

    if currentDepth > maxDepth then
        DebugSafety("HALT: max depth (" .. currentDepth .. " > " .. maxDepth .. ")")
        return false, "max_depth"
    end

    return true
end

-- ============================================================
-- Quest Safety
-- ============================================================

function SafetyEngine.ShouldAcceptQuest(questID, frequency)
    local config = GetConfig()
    local services = GetServices()

    if not config or not services then return false end

    if not questID or services.IsQuestBlocked(questID) then
        return false
    end

    -- Warband account-wide completion check
    if not config.Get("quest", "acceptAccountCompleted") then
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompletedOnAccount then
            local success, isAccountCompleted = pcall(C_QuestLog.IsQuestFlaggedCompletedOnAccount, questID)
            if success and isAccountCompleted then
                return false
            end
        end
    end

    local gameData = GetGameData()
    local questType = gameData and gameData.GetQuestType(questID) or "normal"

    local configMap = {
        daily = "acceptRepeatable",
        weekly = "acceptRepeatable",
        world = "acceptRepeatable",
        pvp = "acceptPvP",
        escort = "acceptEscort",
        profession = "acceptTrade",
    }

    local configKey = configMap[questType]
    if configKey then
        return config.Get("quest", configKey)
    end

    -- Only block if frequency indicates an actual repeatable (daily/weekly).
    -- C_GossipInfo sets frequency on ALL quests — normal quests get
    -- Enum.QuestFrequency.Default (non-nil), so a bare truthy check blocks everything.
    if frequency and not config.Get("quest", "acceptRepeatable") then
        local defaultFreq = Enum and Enum.QuestFrequency and Enum.QuestFrequency.Default
        if defaultFreq == nil or frequency ~= defaultFreq then
            return false
        end
    end

    return true
end

-- ============================================================
-- Processing State Management
-- ============================================================

function SafetyEngine.BeginProcessing(reason)
    -- Defense-in-depth: block automation start if modifier key held
    local services = GetServices()
    if services and not services.ShouldAutomate() then
        if services.RestoreAutomationFrames then
            services.RestoreAutomationFrames()
        end
        DebugSafety("BeginProcessing blocked: modifier key held")
        return false
    end

    if state ~= "IDLE" then
        local config = GetConfig()
        local timeout = config and config.Get("advanced", "autoRecoveryTimeout") or JustQuest.Constants.TIMING.AUTO_RECOVERY_TIMEOUT
        if (GetTime() - stateStartTime) > timeout then
            SafetyEngine.SetState("IDLE", "auto_recovery")
        else
            DebugSafety("BeginProcessing blocked: already BUSY")
            return false
        end
    end

    SafetyEngine.SetState("BUSY", reason)
    return true
end

function SafetyEngine.EndProcessing(reason, shouldRepump)
    -- Restore frame visibility (fast mode may have hidden frames)
    local services = GetServices()
    if services and services.RestoreAutomationFrames then
        services.RestoreAutomationFrames()
    end

    SafetyEngine.SetState("IDLE", reason or "processing_complete")

    if not InCombatLockdown() then
        local containerEngine = JustQuest.Core.GetModule("ContainerEngine")

        -- Schedule container scan
        if containerEngine and services and services.ScheduleOnce then
            local scanDelay = services.GetTiming and services.GetTiming("CONTAINER_SCAN_AFTER_AUTOMATION", 0.25) or 0.25
            services.ScheduleOnce("container_scan_after_automation_safety", scanDelay, function()
                if containerEngine.OnBagUpdateDelayed then
                    containerEngine.OnBagUpdateDelayed()
                end
            end)
        end

        -- Schedule content repump only when explicitly requested
        if shouldRepump and services and services.ScheduleContentCheck then
            local repumpDelay = services.GetTiming and services.GetTiming("REINTERACT_AFTER_TURNIN", 0.15) or 0.15
            services.ScheduleContentCheck(repumpDelay, "safety_end_processing")
        end
    end
end

function SafetyEngine.CanProcess()
    if state == "IDLE" then
        return true
    end

    -- BUSY state: auto-recover if stuck or frame closed
    local config = GetConfig()
    local timeout = config and config.Get("advanced", "autoRecoveryTimeout") or JustQuest.Constants.TIMING.AUTO_RECOVERY_TIMEOUT
    local timeSinceActivity = GetTime() - (JustQuest._lastProcessingTime or 0)

    if timeSinceActivity > timeout then
        DebugSafety(string.format("Auto-recovery: BUSY stuck for %.1fs", timeSinceActivity))
        SafetyEngine.EndProcessing("auto_recovery")
        return true
    end

    -- Allow continuation if recent activity or frame still open
    if timeSinceActivity < 1.5 then return true end

    local frameOpen = GetServices() and GetServices().IsInteractionFrameOpen()

    if not frameOpen then
        DebugSafety(string.format("Frame closed recovery: BUSY %.1fs idle", timeSinceActivity))
        SafetyEngine.EndProcessing("frame_closed_recovery")
        return true
    end

    return true
end

-- ============================================================
-- Module Registration
-- ============================================================

JustQuest.Core.RegisterModule("SafetyEngine", SafetyEngine, {"Config", "GameData"})

return SafetyEngine
