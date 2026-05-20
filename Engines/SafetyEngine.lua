-- SafetyEngine.lua — State machine, loop prevention, gossip option validation

local ADDON_NAME, JustQuest = ...

local SafetyEngine = {}

-- Hot path locals
local GetTime = GetTime
local pcall = pcall
local wipe = wipe

-- Module cache (lazy initialization)
local moduleCache = {}

-- ============================================================
-- State Management (IDLE / BUSY)
-- ============================================================

local state = "IDLE"
local stateReason = nil
local stateStartTime = GetTime()

local recentSelections = {}
local statusAvailable      = nil
local statusAlreadyComplete = nil
local statusUnavailable    = nil  -- shown in UI but not clickable (requirement not met)
local statusLocked         = nil  -- hidden/locked by server logic

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

local function GetGameData()
    if not moduleCache.GameData then
        moduleCache.GameData = JustQuest.Core.GetModule("GameData")
    end
    return moduleCache.GameData
end

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
    statusUnavailable    = getEnum("GossipOptionStatus", "Unavailable")
    statusLocked         = getEnum("GossipOptionStatus", "Locked")

    SafetyEngine.RebuildLists()

    -- Periodic stuck-state recovery
    if services and services.ScheduleRepeating then
        services.ScheduleRepeating("safety_stuck_state_recovery", 3.0, function()
            if state == "BUSY" then
                local config = GetConfig()
                local timeout = config and config.Get("advanced", "autoRecoveryTimeout") or JustQuest.Constants.TIMING.AUTO_RECOVERY_TIMEOUT
                local timeSinceActivity = GetTime() - (JustQuest._lastProcessingTime or 0)

                local frameOpen = services.IsInteractionFrameOpen()

                if (timeSinceActivity > timeout and not frameOpen) or
                   (not frameOpen and timeSinceActivity > 1.0) then
                    if services.Debug then
                        services.Debug("Safety", string.format("Periodic recovery: BUSY (%.1fs idle, frame=%s)",
                            timeSinceActivity, frameOpen and "open" or "closed"))
                    end
                    SafetyEngine.EndProcessing("periodic_stuck_recovery")
                end
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

-- Returns true for options that are present on the NPC but not yet clickable.
-- Useful for anticipating what options will appear after automation acts
-- (e.g. vendor unlocks after accepting a prerequisite quest in the same frame).
function SafetyEngine.OptionIsPending(option)
    if not option then return false end
    local status = option.status
    if status == nil then return false end
    if statusUnavailable ~= nil and statusLocked ~= nil then
        return status == statusUnavailable or status == statusLocked
    end
    -- Enum not resolved: anything that isn't available/alreadyComplete counts as pending
    return status ~= statusAvailable and status ~= statusAlreadyComplete
end



-- ============================================================
-- Repeat/Selection Tracking (loop prevention)
-- ============================================================

function SafetyEngine.ShouldSkipRepeat(npcGUID, optionID, totalOptions)
    if not npcGUID or not optionID then return false end

    local recent = recentSelections[npcGUID]
    if not recent or not recent.history then return false end

    local config = GetConfig()
    local ttl = config and config.Get("advanced", "gossipRepeatWindow") or JustQuest.Constants.TIMING.GOSSIP_REPEAT_WINDOW

    -- Reduce TTL for single options (likely "back" navigation)
    if totalOptions and totalOptions == 1 then
        ttl = ttl * 0.25
    end

    local now = GetTime()
    for _, entry in ipairs(recent.history) do
        if entry.optionID == optionID and (now - entry.time) < ttl then
            DebugSafety(string.format("Repeat blocked: optionID=%s, %.2fs ago, ttl=%.2fs",
                tostring(optionID), now - entry.time, ttl))
            return true
        end
    end

    return false
end

function SafetyEngine.MarkSelection(npcGUID, optionID)
    if not (npcGUID and optionID) then return end

    local now = GetTime()
    local config = GetConfig()
    local ttl = config and config.Get("advanced", "gossipRepeatWindow") or JustQuest.Constants.TIMING.GOSSIP_REPEAT_WINDOW

    if not recentSelections[npcGUID] then
        recentSelections[npcGUID] = { history = {}, lastTime = now }
    end

    local recent = recentSelections[npcGUID]
    recent.lastTime = now

    -- Filter expired entries in-place to avoid allocating a new table each call.
    local h = recent.history
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

function SafetyEngine.ClearNPCSelection(npcGUID)
    if not npcGUID then return end
    recentSelections[npcGUID] = nil
end

function SafetyEngine.CleanupRecentSelections()
    local now = GetTime()
    local maxAge = 300
    local maxEntries = 10
    local kept = 0

    for guid, data in pairs(recentSelections) do
        if now - data.lastTime > maxAge then
            recentSelections[guid] = nil
        else
            kept = kept + 1
        end
    end

    if kept > maxEntries then
        local entries = {}
        for guid, data in pairs(recentSelections) do
            table.insert(entries, {guid = guid, time = data.lastTime})
        end
        table.sort(entries, function(a, b) return a.time < b.time end)
        for i = 1, kept - maxEntries do
            recentSelections[entries[i].guid] = nil
        end
    end
end

-- ============================================================
-- Warning Color Detection (kept for gossip option text)
-- ============================================================

local WARNING_COLORS = {
    ["ff0000"] = true, ["ff3300"] = true, ["ff6600"] = true,
    ["ff4500"] = true, ["cc0000"] = true, ["ff8000"] = true, ["ffaa00"] = true,
    ["RED_FONT_COLOR"] = true, ["ORANGE_FONT_COLOR"] = true, ["DIM_RED_FONT_COLOR"] = true,
}

local SAFE_COLORS = {
    ["0078ff"] = true, ["00aaff"] = true, ["00ccff"] = true, ["0099ff"] = true, ["00d1ff"] = true,
    ["1eff00"] = true, ["00ff00"] = true, ["00ff96"] = true,
    ["ffff00"] = true, ["ffd100"] = true, ["ffffff"] = true,
    ["NORMAL_FONT_COLOR"] = true, ["HIGHLIGHT_FONT_COLOR"] = true,
    ["GREEN_FONT_COLOR"] = true, ["YELLOW_FONT_COLOR"] = true, ["BATTLENET_FONT_COLOR"] = true,
}

local function HasWarningColorCode(text)
    if not text or type(text) ~= "string" then return false end

    for namedColor in text:gmatch("|cn([%w_]+):") do
        if WARNING_COLORS[namedColor] then return true end
    end

    for hexColor in text:gmatch("|c%x%x(%x%x%x%x%x%x)") do
        local lower = hexColor:lower()
        if WARNING_COLORS[lower] then return true end
        if not SAFE_COLORS[lower] then
            local r = tonumber(lower:sub(1,2), 16) or 0
            local g = tonumber(lower:sub(3,4), 16) or 0
            local b = tonumber(lower:sub(5,6), 16) or 0
            if r > 180 and g < 150 and b < 100 then return true end
        end
    end

    return false
end

-- Returns true if the server embedded ANY color code in option.name.
-- All gossip buttons share one default gold font (QuestFontLeft/SystemFont_Med2).
-- Any |c or |cn in option.name means the server deliberately colored this option
-- to signal importance — it is not just template styling.
-- |c matches both |cffRRGGBB hex codes and |cnNAME: named codes (|cn is a prefix of |c)
local function HasAnyColorCode(text)
    if not text or type(text) ~= "string" then return false end
    return text:find("|c", 1, true) ~= nil
end

-- Expose color detection for cross-module use
SafetyEngine.HasWarningColorCode = HasWarningColorCode
SafetyEngine.HasAnyColorCode = HasAnyColorCode

-- ============================================================
-- UI Frame Color Extraction
-- ============================================================

-- GOSSIP_BUTTON_TYPE_OPTION = 3 (Blizzard constant)
local GOSSIP_BUTTON_TYPE_OPTION = 3

--- Reads the actual rendered text (with color codes) from GossipFrame UI buttons.
--- C_GossipInfo.GetOptions() returns plain text, but the UI frames preserve
--- server-applied colors. This function bridges that gap.
--- @return table  Map of optionKey -> { uiText=string, hasColor=bool, hasWarning=bool }
function SafetyEngine.GetGossipOptionUIColors()
    local colorMap = {}

    -- Guard: GossipFrame may not exist (e.g. Classic without shared templates)
    if not (GossipFrame and GossipFrame.GreetingPanel and GossipFrame.GreetingPanel.ScrollBox) then
        return colorMap
    end

    local scrollBox = GossipFrame.GreetingPanel.ScrollBox
    local enumerator = scrollBox.EnumerateFrames or scrollBox.GetFrames
    if not enumerator then return colorMap end

    for _, frame in scrollBox:EnumerateFrames() do
        local elementData = frame.GetElementData and frame:GetElementData()
        if elementData and elementData.buttonType == GOSSIP_BUTTON_TYPE_OPTION and elementData.info then
            local info = elementData.info
            local optionKey = info.gossipOptionID or info.orderIndex
            if optionKey then
                local fontString = frame.GetFontString and frame:GetFontString()
                local uiText = fontString and fontString:GetText() or ""
                colorMap[optionKey] = {
                    uiText = uiText,
                    hasColor = HasAnyColorCode(uiText),
                    hasWarning = HasWarningColorCode(uiText),
                }
            end
        end
    end

    return colorMap
end

-- ============================================================
-- Comprehensive Validation
-- ============================================================

function SafetyEngine.ValidateInteraction(options, uiColors)
    if not options or #options == 0 then
        return true, "no options available"
    end

    -- uiColors: map of optionKey -> { uiText, hasColor, hasWarning }
    -- When provided, use real UI text for color checks instead of API text
    -- (API text from C_GossipInfo.GetOptions() is always plain, no color codes).
    uiColors = uiColors or {}

    -- Single pass: whitelist/warning/color checks merged with blacklist/safe-count
    -- to halve the number of iterations over the options table.
    local coloredCount = 0
    local safeCount = 0
    local availableCount = 0

    for _, option in ipairs(options) do
        -- Whitelisted options are always safe — skip all other checks.
        if SafetyEngine.IsWhitelisted(option) then
            return false, "whitelisted option found"
        end

        if SafetyEngine.OptionIsAvailable(option) then
            availableCount = availableCount + 1

            if option.name then
                local optionKey = option.gossipOptionID or option.orderIndex
                local uiInfo = optionKey and uiColors[optionKey]

                -- Red/orange warning text: halt immediately.
                -- Check UI frame text first (authoritative), fall back to API text.
                if uiInfo and uiInfo.hasWarning then
                    DebugSafety("HALT: warning color in UI text: " .. (uiInfo.uiText or option.name))
                    return true, "warning_color_text"
                elseif HasWarningColorCode(option.name) then
                    DebugSafety("HALT: warning color in API text: " .. option.name)
                    return true, "warning_color_text"
                end

                -- Track any server-colored option (blue, highlight, etc.)
                if (uiInfo and uiInfo.hasColor) or HasAnyColorCode(option.name) then
                    coloredCount = coloredCount + 1
                end
            end

            if not SafetyEngine.IsBlacklisted(option) then
                safeCount = safeCount + 1
            end
        end
    end

    -- Two+ colored options: ambiguous, player must pick
    if coloredCount >= 2 then
        DebugSafety("HALT: " .. coloredCount .. " server-colored options require manual selection")
        return true, "multiple_important_options"
    end

    if availableCount > 0 and safeCount == 0 then
        return true, "all options unsafe"
    end

    return false, "passed"
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
