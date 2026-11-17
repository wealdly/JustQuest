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

-- Option IDs already auto-selected for the CURRENT npc interaction (loop prevention).
-- Auto-selecting the exact same option twice is never legitimate automation — it means
-- the menu is looping — so each option is auto-selectable at most once per interaction,
-- no matter how slowly it re-shows. Not keyed by GUID: under addon taint UnitGUID
-- returns a "secret value" unusable as a table key. Only one gossip NPC is active at a
-- time, so a single set suffices; it is cleared on NPC change / gossip close.
local selectedOptions = {}
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

        -- Arm the cursor indicator on the way into BUSY. Nothing disarms it here: a chain
        -- blips through IDLE between steps far faster than the arming delay, so cancelling
        -- on every IDLE reset the clock before it could ever fire and the indicator never
        -- appeared at all. It retires itself instead — the armed callback re-checks
        -- IsBusy before showing, and its OnUpdate hides it the frame automation stops.
        if newState == "BUSY" then
            local indicator = JustQuest.Core.GetModule("AutomationIndicator")
            if indicator and indicator.Show then indicator.Show() end
        end

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
        -- 0.5s, not 1s. Both the fast-mode frame reveal and stall recovery only happen on
        -- this tick, so the tick interval is added to each of their thresholds as jitter:
        -- at 1Hz a frame that should reveal at 0.75s could stay invisible until 1.75s,
        -- which is the "it's stuck, walk away to clear it" window. Halving the tick
        -- halves that tail. The body is a handful of comparisons that early-out when
        -- IDLE with no frame open, so the extra wakeups cost nothing measurable.
        services.ScheduleRepeating("safety_stuck_state_recovery", 0.5, function()
            -- The currency-spend prompt is a deliberate, open-ended wait on the
            -- player; its popup is the interaction surface, so leave the frame
            -- hidden behind it and never time it out.
            if stateReason == "waiting_currency_prompt" then return end

            local timeSinceActivity = GetTime() - (JustQuest._lastProcessingTime or 0)
            local frameOpen = services.IsInteractionFrameOpen()

            -- Fast-mode visibility guarantee: fast mode hides the quest/gossip frame
            -- (alpha 0) while automating. If a frame is still open after automation
            -- has gone quiet for ~0.75s — stalled while BUSY, or settled into IDLE
            -- with the frame left for the player (manual pick, leftover gossip) — it
            -- must be revealed; otherwise it stays invisible and un-clickable (the
            -- "walk away to force-close it" trap). A live drain refreshes activity
            -- faster than this, so it stays hidden through continuing steps.
            if frameOpen and timeSinceActivity > 0.75 then
                services.RestoreAutomationFrames()
            end

            if state ~= "BUSY" then return end

            local config = GetConfig()
            local timeout = config and config.Get("advanced", "autoRecoveryTimeout") or JustQuest.Constants.TIMING.AUTO_RECOVERY_TIMEOUT

            -- Recover BUSY state when the frame is already closed (fast path), OR
            -- when automation has stalled past the full timeout even with a frame
            -- still open (the "stuck at turn-in" case: a missed QUEST_COMPLETE/
            -- QUEST_TURNED_IN). Repump so the still-open frame is re-processed.
            if (not frameOpen and timeSinceActivity > 1.0) or timeSinceActivity > timeout then
                if services.Debug then
                    services.Debug("Safety", string.format("Periodic recovery: BUSY %s (%.1fs idle, frame=%s)",
                        stateReason or "?", timeSinceActivity, frameOpen and "open" or "closed"))
                end
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

function SafetyEngine.ShouldSkipRepeat(optionID)
    if not optionID then return false end
    if selectedOptions[optionID] then
        DebugSafety("Repeat blocked: optionID=" .. tostring(optionID) .. " already auto-selected this interaction")
        return true
    end
    return false
end

function SafetyEngine.MarkSelection(optionID)
    if optionID then selectedOptions[optionID] = true end
end

-- Silent read of the repeat history (ShouldSkipRepeat logs; this is for callers that
-- only want to know, e.g. the traverse detecting a return to an already-walked menu).
function SafetyEngine.WasSelected(optionID)
    return optionID ~= nil and selectedOptions[optionID] == true
end

-- Clear selection history (NPC changed or gossip closed).
function SafetyEngine.ClearSelections()
    wipe(selectedOptions)
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

    if blacklistSet[cleanText] then return true end

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

-- Gate for TURNING IN / auto-completing an already-accepted quest (auto-quest
-- "click here to complete" popups and QUEST_AUTOCOMPLETE). Unlike ShouldAcceptQuest,
-- this must NOT apply accept-type policy (PvP/escort/repeatable prefs decide what to
-- ACCEPT, not what to hand in) — a quest already in the log should complete unless the
-- player explicitly blocklisted it. Gating turn-in on accept policy is why some push
-- quests sat stuck at "click here to complete".
function SafetyEngine.ShouldCompleteQuest(questID)
    if not questID then return true end
    local services = GetServices()
    if services and services.IsQuestBlocked and services.IsQuestBlocked(questID) then
        return false
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
        -- Measure the gap since the last automation STEP, not since the chain first went
        -- BUSY. stateStartTime only moves on an actual state change, so a BUSY->BUSY
        -- step (accepting -> completing -> reward) never refreshed it: any chain running
        -- longer than the timeout in total got force-IDLEd and became re-entrant, even
        -- while it was progressing normally. CanProcess and the periodic recovery both
        -- already use _lastProcessingTime; this was the odd one out.
        if (GetTime() - (JustQuest._lastProcessingTime or 0)) > timeout then
            SafetyEngine.SetState("IDLE", "auto_recovery")
        else
            DebugSafety("BeginProcessing blocked: already BUSY")
            return false
        end
    end

    SafetyEngine.SetState("BUSY", reason)
    return true
end

-- Reasons that mean "automation acted and CONTINUES to the next step" — in fast
-- mode the frame stays hidden through these so it doesn't flicker visible between
-- a turn-in and the next quest. Every other end reason (manual halt, nothing
-- auto-selectable, recovery, currency cancel) reveals the frame: the player needs
-- to see it because input is required or automation failed.
local CONTINUING_REASONS = {
    whitelisted_option_selected   = true,
    quest_option_selected         = true,
    service_step_selected         = true,
    gossip_option_selected        = true,
    quest_accept_action_complete  = true,
    quest_turned_in               = true,
}

function SafetyEngine.EndProcessing(reason, shouldRepump)
    -- Restore frame visibility unless this is a continuing step (fast mode hides
    -- frames mid-automation; outside fast mode this is a no-op, alpha already 1).
    local services = GetServices()
    if services and services.RestoreAutomationFrames and not CONTINUING_REASONS[reason or ""] then
        services.RestoreAutomationFrames()
    end

    SafetyEngine.SetState("IDLE", reason or "processing_complete")

    -- Container scans wait for combat to end (opening one is a bag action); the content
    -- re-check does not — quest and gossip steps work in combat, and gating it here meant a
    -- turn-in mid-fight never looked for the follow-up quest.
    if not InCombatLockdown() then
        local containerEngine = JustQuest.Core.GetModule("ContainerEngine")
        if containerEngine and services and services.ScheduleOnce then
            local scanDelay = services.GetTiming and services.GetTiming("CONTAINER_SCAN_AFTER_AUTOMATION", 0.25) or 0.25
            services.ScheduleOnce("container_scan_after_automation_safety", scanDelay, function()
                if containerEngine.OnBagUpdateDelayed then
                    containerEngine.OnBagUpdateDelayed()
                end
            end)
        end
    end

    -- Schedule content repump only when explicitly requested
    if shouldRepump and services and services.ScheduleContentCheck then
        local repumpDelay = services.GetTiming and services.GetTiming("REINTERACT_AFTER_TURNIN", 0.15) or 0.15
        services.ScheduleContentCheck(repumpDelay, "safety_end_processing")
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
