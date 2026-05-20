-- Services.lua — Timers, safe API wrappers, and text processing

local ADDON_NAME, JustQuest = ...

local Services = {}

local AceTimer = LibStub("AceTimer-3.0")
for k, v in pairs(AceTimer) do
    Services[k] = v
end

-- ============================================================
-- Timer System
-- ============================================================

local activeTimers = {}

local function SanitizeKey(key)
    if type(key) ~= "string" then 
        key = tostring(key or "") 
    end
    key = key:gsub("[^%w_]+","_")
    if #key > 64 then 
        key = key:sub(1,64) 
    end
    return key
end

function Services.ScheduleOnce(key, delay, fn, ...)
    if not key or not fn then 
        return 
    end
    
    local args = { ... }
    key = SanitizeKey(key)
    
    Services.CancelScheduled(key)
    
    local timer = Services:ScheduleTimer(function()
        activeTimers[key] = nil
        local ok, err = pcall(fn, unpack(args))
        if not ok then
            Services.Debug("Timer", "ScheduleOnce error: " .. tostring(err))
        end
    end, math.max(0, tonumber(delay) or 0))
    
    activeTimers[key] = timer
    return timer
end

function Services.CancelScheduled(key)
    local timer = activeTimers[key]
    if timer then
        Services:CancelTimer(timer)
        activeTimers[key] = nil
    end
end

function Services.ScheduleRepeating(key, interval, fn, ...)
    if not key or not fn then 
        return 
    end
    
    local args = { ... }
    key = SanitizeKey(key)
    
    Services.CancelScheduled(key)
    
    local timer = Services:ScheduleRepeatingTimer(function()
        local ok, err = pcall(fn, unpack(args))
        if not ok then
            Services.Debug("Timer", "ScheduleRepeating error: " .. tostring(err))
        end
    end, math.max(0.1, tonumber(interval) or 1))
    
    activeTimers[key] = timer
    return timer
end

-- ============================================================
-- Safe API Wrappers
-- ============================================================

function Services.SafeCall(func, ...)
    if not func then return nil end
    local success, result = pcall(func, ...)
    if not success then
        Services.Debug("SafeCall", "Function failed: " .. tostring(result))
        return nil
    end
    return result
end

function Services.SafeCallWithRetry(func, maxRetries, ...)
    if not func then return nil end
    maxRetries = maxRetries or 3
    
    for attempt = 1, maxRetries do
        local success, result = pcall(func, ...)
        if success then
            return result
        end
        
        if attempt < maxRetries then
            Services.Debug("Retry", string.format("Attempt %d/%d failed", attempt, maxRetries))
        end
        
        -- No artificial delay — WoW API is already server-throttled
    end
    
    Services.Debug("Retry", string.format("All %d attempts failed", maxRetries))
    return nil
end

function Services.GetEnumValue(enumName, key)
    if type(enumName) ~= "string" or not Enum then return nil end
    local e = Enum[enumName]
    if not e then return nil end
    return e[key]
end

-- ============================================================
-- Timing Utilities
-- ============================================================

function Services.GetTiming(timingKey, fallback)
    local baseValue = JustQuest.Constants.TIMING[timingKey]
    if not baseValue then return fallback or 0 end

    local config = JustQuest.Core.GetModule("Config")
    local multiplier
    if config and config.Get(nil, "fastMode") then
        multiplier = 0.5
    else
        multiplier = (config and config.Get("advanced", "timingMultiplier")) or 1.0
        multiplier = math.max(0.75, math.min(2.0, multiplier))
    end

    return baseValue * multiplier
end

-- ============================================================
-- Output System - Centralized messaging for consistency
-- ============================================================

-- Cached debug flag — avoids GetModule+config lookup on every Debug() call.
local _debugEnabled = false

function Services.SetDebugMode(enabled)
    _debugEnabled = enabled and true or false
    JustQuest._debugMode = _debugEnabled
end

function Services.Debug(module, msg)
    if not _debugEnabled then return end

    local out = tostring(msg)
    out = out:gsub("%s+", " ")
    local MAX_LEN = 200
    if #out > MAX_LEN then
        out = out:sub(1, MAX_LEN - 3) .. "..."
    end

    print("|cff00ccffJQ " .. (module or "Core") .. ":|r " .. out)
end

-- Info output (always shown)
function Services.Info(msg)
    print("|cff00ccffJustQuest:|r " .. tostring(msg))
end

function Services.Warn(msg)
    print("|cffffaa00JustQuest:|r " .. tostring(msg))
end

function Services.Error(msg)
    print("|cffff0000JustQuest:|r " .. tostring(msg))
end

-- Throttled per reason to avoid spam
local haltThrottles = {}
local HALT_THROTTLE_SECONDS = 10

local HALT_REASONS = {
    -- Safety halts
    ["dangerous_service"] = "Dangerous service detected",
    ["money_cost"] = "Cost required",
    ["multiple_options"] = "Multiple choices available",
    ["mixed_options"] = "Mixed quest/non-quest options",
    ["blacklisted"] = "Blacklisted option",
    ["blacklisted_quest"] = "Blacklisted quest",
    ["quest_danger"] = "Quest has warnings",
    ["max_depth"] = "Chain depth limit reached",
    ["no_safe_options"] = "No safe options available",
    ["vendor_option"] = "Vendor or service available",
    ["multiple_choices"] = "Multiple activity options — manual selection required",
    ["multiple_significant_rewards"] = "Multiple significant rewards — manual selection required",
    ["legacy_greeting"] = "Legacy greeting panel detected",
    ["colored_text"] = "Colored text requires confirmation",
    ["warning_color_text"] = "Red/warning text in option - manual selection required",
    ["multiple_important_options"] = "Multiple highlighted options - manual selection required",

    -- Resource limits
    ["quest_log_full"] = "Quest log is full",
    -- Misc
    ["modifier_held"] = "Modifier key held",
    ["combat"] = "In combat",
    ["interfering_frame"] = "Non-quest frame detected",
}

function Services.OutputHalt(reason, extraInfo)
    local now = GetTime()
    
    -- Throttle per reason
    if haltThrottles[reason] and (now - haltThrottles[reason]) < HALT_THROTTLE_SECONDS then
        return false  -- Throttled
    end
    haltThrottles[reason] = now
    
    local msg = HALT_REASONS[reason] or reason or "Automation paused"
    if extraInfo then
        msg = msg .. " (" .. tostring(extraInfo) .. ")"
    end
    
    -- Fast mode: restore frame visibility so player can interact manually
    Services.RestoreAutomationFrames()

    print("|cffff6b00JustQuest:|r " .. msg .. " - manual interaction required")
    return true  -- Message was shown
end

-- ============================================================
-- Text Processing
-- ============================================================

function Services.CleanText(text)
    if not text then return "" end
    return text:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

-- Normalize text for list membership
function Services.NormalizeListEntry(text)
    if not text or text == "" then return nil end
    local cleaned = Services.CleanText(text)
    if cleaned == "" then return nil end
    return cleaned
end

-- Validate text for list operations
-- Returns (isValid, normalizedText, reason)
function Services.ValidateTextForLists(text)
    if not text or text == "" then
        return false, nil, "text is empty"
    end
    
    local normalized = Services.NormalizeListEntry(text)
    if not normalized then
        return false, nil, "text is only whitespace or special characters"
    end
    
    if #normalized < 2 then
        return false, nil, "text too short after normalization (minimum 2 characters)"
    end
    
    if #normalized > 100 then
        return false, nil, "text too long after normalization (maximum 100 characters)"
    end
    
    return true, normalized, nil
end

-- ============================================================
-- Automation Context Validation
-- ============================================================

local function HasActiveStaticPopup()
    for i = 1, 4 do
        local popup = _G["StaticPopup" .. i]
        if popup and popup:IsVisible() then return true end
    end
    return false
end

-- Returns true if any quest/gossip interaction frame is currently visible.
-- Centralises the 4-frame check used by stuck-state recovery, automation
-- context validation, and processing guards.
function Services.IsInteractionFrameOpen()
    return (QuestFrame and QuestFrame:IsShown()) or
           (GossipFrame and GossipFrame:IsShown()) or
           (PlayerChoiceFrame and PlayerChoiceFrame:IsShown()) or
           (QuestLogPopupDetailFrame and QuestLogPopupDetailFrame:IsShown()) or false
end

function Services.IsAutomationContextAllowed()
    -- QuestFrame covers children (GreetingPanel, DetailPanel, ProgressPanel, RewardPanel)
    if not Services.IsInteractionFrameOpen() then return false end

    if HasActiveStaticPopup() then return false end

    if Services.HasInterferingFrame() then return false end

    return true
end

-- Fast mode: alpha=0 while automating, restored on halt or dialog close

local function FastModeSuppressFrame(frame)
    local config = JustQuest.Core.GetModule("Config")
    if not (config and config.Get(nil, "fastMode")) then return end
    if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then return end
    if Services.HasInterferingFrame() then return end
    frame:SetAlpha(0)
end

function Services.SetupFastModeHooks()
    if QuestFrame and not QuestFrame._jqFastHooked then
        QuestFrame:HookScript("OnShow", FastModeSuppressFrame)
        QuestFrame._jqFastHooked = true
    end
    if GossipFrame and not GossipFrame._jqFastHooked then
        GossipFrame:HookScript("OnShow", FastModeSuppressFrame)
        GossipFrame._jqFastHooked = true
    end
end

function Services.RestoreAutomationFrames()
    if QuestFrame then QuestFrame:SetAlpha(1) end
    if GossipFrame then GossipFrame:SetAlpha(1) end
end

-- Check for non-quest/gossip NPC frames (vendor, trainer, flight map, etc.)
-- Caches _G frame references to avoid repeated string→table lookups
local interferingFrameRefs = nil

function Services.HasInterferingFrame()
    if not interferingFrameRefs then
        local frameNames = JustQuest.Constants.INTERFERING_FRAMES
        if not frameNames then return nil end
        interferingFrameRefs = {}
        for _, name in ipairs(frameNames) do
            interferingFrameRefs[#interferingFrameRefs + 1] = { name = name, ref = _G[name] or false }
        end
    end

    for _, entry in ipairs(interferingFrameRefs) do
        local frame = entry.ref
        if frame == false then
            -- Lazy resolve: frame may have been created after cache build
            frame = _G[entry.name]
            if frame then entry.ref = frame end
        end
        if frame and frame:IsShown() then
            return entry.name
        end
    end
    return nil
end

-- ============================================================
-- Game State Functions
-- ============================================================

function Services.GetItemIDFromLink(itemLink)
    return itemLink and tonumber(itemLink:match("item:(%d+)"))
end



function Services.IsQuestRelatedGossip(option)
    if not option then return false end
    
    if option.flags and bit and bit.band then
        local QUEST_FLAG = 1
        if bit.band(option.flags, QUEST_FLAG) ~= 0 then
            return true
        end
    end
    
    if option.name and type(option.name) == "string" then
        local cleanName = Services.CleanText(option.name)
        return cleanName:find("%(%s*quest[!%s]*%s*%)") or 
               cleanName:find("%[%s*quest[!%s]*%s*%]")
    end
    
    return false
end

function Services.HasGossipQuests()
    if not C_GossipInfo then 
        return false 
    end
    
    local active = C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests()
    if type(active) == "table" and #active > 0 then 
        return true 
    end
    
    local available = C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests()
    if type(available) == "table" and #available > 0 then
        return true
    end
    
    local options = Services.SafeCall(C_GossipInfo.GetOptions)
    if type(options) == "table" then
        for _, option in ipairs(options) do
            if Services.IsQuestRelatedGossip(option) then
                Services.Debug("Services", "Quest-related gossip detected: " .. tostring(option.name))
                return true
            end
        end
    end
    
    return false
end

-- Check for ACTIONABLE quests (complete to turn in, or available to accept).
-- Aligned with QuestEngine visibility filters to prevent phantom routing.
function Services.HasActionableQuestContent()
    if not C_GossipInfo then
        return false, "no_api"
    end

    -- Check for complete quests (can turn in)
    local active = C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests()
    if type(active) == "table" then
        for _, quest in ipairs(active) do
            if quest.isComplete and quest.questID and not Services.IsQuestBlocked(quest.questID) then
                return true, "complete_quest"
            end
        end
    end

    -- Check for available quests (can accept)
    local available = C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests()
    if type(available) == "table" and #available > 0 then
        local safetyEngine = JustQuest.Core.GetModule("SafetyEngine")
        for _, quest in ipairs(available) do
            if quest.questID then
                local inLog = C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(quest.questID)
                local completed = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(quest.questID)
                local blocked = Services.IsQuestBlocked(quest.questID)
                local shouldAccept = not safetyEngine or not safetyEngine.ShouldAcceptQuest
                                     or safetyEngine.ShouldAcceptQuest(quest.questID, quest.frequency)
                if not inLog and not completed and not blocked and shouldAccept then
                    return true, "available_quest"
                end
            else
                -- No questID to check, assume available
                return true, "available_quest_unknown"
            end
        end
    end

    return false, "no_actionable"
end

function Services.ShouldAutomate()
    return not (IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown())
end

function Services.IsAutomationEnabled()
    local config = JustQuest.Core.GetModule("Config")
    return config and
           config.Get(nil, "enabled") and
           config.Get("quest", "enabled") and
           config.Get("gossip", "enabled")
end

-- Base validation gate — shared by all automation paths.
-- Does NOT check interfering frames (NPC-interaction specific).
function Services.CanAutomateBase()
    if UnitIsDeadOrGhost("player") then return false end
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then return false end
    if not Services.ShouldAutomate() then
        -- Modifier key held: restore frames so player can interact manually.
        -- Fast mode may have hidden them before the modifier was pressed.
        Services.RestoreAutomationFrames()
        return false
    end
    if not Services.IsAutomationEnabled() then return false end
    if HasActiveStaticPopup() then return false end
    return true
end

-- NPC interaction gate — adds interfering frame detection
function Services.CanAutomate()
    if not Services.CanAutomateBase() then return false end
    local interferingFrame = Services.HasInterferingFrame()
    if interferingFrame then
        Services.RestoreAutomationFrames()
        Services.OutputHalt("interfering_frame", interferingFrame)
        return false
    end
    return true
end

-- Container/reward gate — only blocks on bank/void storage (risky bag manipulation)
function Services.CanAutomateContainers()
    if not Services.CanAutomateBase() then return false end
    if BankFrame and BankFrame:IsShown() then return false end
    if GuildBankFrame and GuildBankFrame:IsShown() then return false end
    if VoidStorageFrame and VoidStorageFrame:IsShown() then return false end
    return true
end

Services.ValidateAutomationPreconditions = Services.CanAutomateContainers

-- ============================================================
-- Quest Processing Support
-- ============================================================

function Services.PollForLegacyQuestData(maxAttempts, onSuccess, onTimeout)
    local pollAttempts = 0
    local pollInterval = Services.GetTiming("QUEST_ACCEPT_POLL_INTERVAL", 0.05)
    
    local startTime = GetTime()
    local maxTotal = JustQuest.Constants.TIMING.RE_PUMP_TOTAL_TIME or 2.0
    local function poll()
        pollAttempts = pollAttempts + 1
        
        local numActive = GetNumActiveQuests and GetNumActiveQuests() or 0
        local numAvailable = GetNumAvailableQuests and GetNumAvailableQuests() or 0
        local totalQuests = numActive + numAvailable
        
        if totalQuests > 0 then
            Services.Debug("Services", string.format("Legacy API data loaded (attempt %d): %d active, %d available", 
                pollAttempts, numActive, numAvailable))
            if onSuccess then onSuccess() end
        elseif (GetTime() - startTime) >= maxTotal or pollAttempts >= maxAttempts then
            if (GetTime() - startTime) >= maxTotal then
                Services.Debug("Services", string.format("Legacy API timeout: total retry time exceeded (%.3fs)", GetTime() - startTime))
            else
                Services.Debug("Services", string.format("Legacy API timeout after %d attempts", pollAttempts))
            end
            if onTimeout then onTimeout() end
        else
            local maxDelay = JustQuest.Constants.TIMING.RE_PUMP_MAX_DELAY or 2.0
            local growth = JustQuest.Constants.TIMING.RE_PUMP_GROWTH_FACTOR or 1.5
            local backoff = math.min(pollInterval * (growth ^ (pollAttempts - 1)), maxDelay)
            local jitter = (math.random() * 0.2 - 0.1) * backoff
            Services.ScheduleOnce('legacy_api_poll_' .. pollAttempts, backoff + jitter, poll)
        end
    end
    
    poll()
end

-- ============================================================
-- Unified Quest/Gossip Processing
-- ============================================================

-- Check for actionable content via ANY API (modern or legacy)
function Services.HasAnyActionableContent()
    local hasModern = Services.HasActionableQuestContent()
    if hasModern then return true, "modern" end

    -- Unfiltered quest check — HasActionableQuestContent may filter all quests out
    -- (recently accepted, log full, etc.) or data may still be loading.
    -- Route through QuestEngine anyway for correct priority (quests before gossip).
    if C_GossipInfo then
        local rawActive = C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests()
        local rawAvailable = C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests()
        if (type(rawActive) == "table" and #rawActive > 0) or
           (type(rawAvailable) == "table" and #rawAvailable > 0) then
            return true, "modern"
        end
    end

    -- Legacy API (QUEST_GREETING frame)
    local numActive = GetNumActiveQuests and GetNumActiveQuests() or 0
    local numAvailable = GetNumAvailableQuests and GetNumAvailableQuests() or 0
    if numActive > 0 or numAvailable > 0 then
        return true, "legacy"
    end

    -- Greeting frame may have data pending
    if QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsVisible() then
        return true, "greeting_visible"
    end

    local hasGossip = C_GossipInfo and C_GossipInfo.GetOptions and #(C_GossipInfo.GetOptions() or {}) > 0
    if hasGossip then return true, "gossip" end

    return false, "none"
end

-- Shared routing callback — routes to correct engine based on content type
local function DispatchContent(reason)
    -- Use CanAutomateBase (not CanAutomate) to avoid noisy "interfering frame" messages
    -- during background repumps (e.g. MerchantFrame opening after quest turn-in)
    if not Services.CanAutomateBase() then
        Services.Debug("Services", "DispatchContent skipped: CanAutomateBase() failed, reason=" .. (reason or ""))
        return false
    end
    -- Silently bail if interfering frame is open
    if Services.HasInterferingFrame() then
        Services.Debug("Services", "DispatchContent skipped: interfering frame open, reason=" .. (reason or ""))
        return false
    end

    local safetyEngine = JustQuest.Core.GetModule("SafetyEngine")
    if safetyEngine and safetyEngine.IsBusy() then
        Services.Debug("Services", "DispatchContent skipped: already busy ("
            .. (safetyEngine.GetState() or "?") .. "), reason=" .. (reason or ""))
        return false
    end

    local hasContent, contentType = Services.HasAnyActionableContent()
    if not hasContent then return false end

    local questEngine = JustQuest.Core.GetModule("QuestEngine")
    local gossipEngine = JustQuest.Core.GetModule("GossipEngine")

    -- Check gossip failed cooldown for pure gossip content (anti-loop)
    if contentType == "gossip" and gossipEngine and gossipEngine.IsInFailedCooldown then
        if gossipEngine.IsInFailedCooldown() then
            Services.Debug("Services", "Skipping gossip - in failed cooldown")
            return false
        end
    end

    if contentType == "legacy" or contentType == "greeting_visible" then
        if questEngine and questEngine.ProcessLegacyQuestGreeting then
            questEngine.ProcessLegacyQuestGreeting()
        end
    elseif contentType == "modern" or contentType == "gossip" then
        -- Always route through QuestEngine — it makes fresh API calls and has
        -- correct priority: complete quests > available quests > gossip delegation.
        if questEngine and questEngine.OnGossipShow then
            questEngine.OnGossipShow()
        elseif gossipEngine and gossipEngine.OnGossipShow then
            gossipEngine.OnGossipShow(true)
        end
    end

    return true
end

-- Unified content check scheduler — replaces all repump/trigger timer variants
function Services.ScheduleContentCheck(delay, reason)
    delay = delay or 0.1
    reason = reason or "unspecified"

    -- Cancel competing content-check timers
    Services.CancelScheduled("content_repump")
    Services.CancelScheduled("gossip_show")
    Services.CancelScheduled("quest_greeting")

    Services.ScheduleOnce("content_repump", delay, function()
        DispatchContent(reason)
    end)
end

-- Legacy compatibility wrapper
function Services.PumpQuestCheck(reason, delay)
    Services.ScheduleContentCheck(delay or 0.1, reason or "pump_quest_check")
end

function Services.CoalescedGossipPass(tag, delay)
    Services.CancelScheduled(tag)

    Services.CancelScheduled("content_repump")
    if tag ~= "gossip_show" then
        Services.CancelScheduled("gossip_show")
    end
    if tag ~= "quest_greeting" then
        Services.CancelScheduled("quest_greeting")
    end

    Services.ScheduleOnce(tag, delay or 0.1, function()
        DispatchContent("coalesced_" .. tag)
    end)
end

-- ============================================================
-- Safety Validation
-- ============================================================

function Services.IsQuestBlocked(questID)
    if not questID then return false end
    
    if JustQuest.Database.BLOCKED_QUESTS[questID] then
        Services.Debug("Safety", "Quest " .. questID .. " is in blocked quests database")
        return true
    end
    
    local config = JustQuest.Core.GetModule("Config")
    if config then
        local userBlocked = config.Get("quest", "blockedQuests") or {}
        if userBlocked[questID] then
            Services.Debug("Safety", "Quest " .. questID .. " is in user blocked quests")
            return true
        end
    end
    
    return false
end



-- ============================================================
-- Instance Management
-- ============================================================

function Services.LeaveInstance()
    local inInstance = IsInInstance()
    if not inInstance then
        return false, "Not in an instance"
    end
    
    local inGroup = IsInGroup() or IsInRaid()
    local instanceName, instanceType, difficultyID, difficultyName = GetInstanceInfo()
    
    Services.Debug("Instance", string.format("Leave attempt - %s (%s), Difficulty: %s (%d), InGroup: %s", 
        tostring(instanceName), tostring(instanceType), tostring(difficultyName), tostring(difficultyID), tostring(inGroup)))

    -- Method 1: Walk-in party content (Delves) — use dedicated teleport out
    local isWalkInParty = false
    if C_PartyInfo and C_PartyInfo.IsPartyWalkIn then
        local walkInSuccess, walkInResult = pcall(C_PartyInfo.IsPartyWalkIn)
        if walkInSuccess then
            isWalkInParty = walkInResult and true or false
        else
            Services.Debug("Instance", "IsPartyWalkIn check failed: " .. tostring(walkInResult))
        end
    end

    if isWalkInParty and C_PartyInfo and C_PartyInfo.DelveTeleportOut then
        local delveSuccess, delveErr = pcall(C_PartyInfo.DelveTeleportOut)
        if delveSuccess then
            Services.Debug("Instance", "Left via DelveTeleportOut (walk-in party)")
            return true, "Teleporting out of delve..."
        end
        Services.Debug("Instance", "DelveTeleportOut failed: " .. tostring(delveErr))
    end
    
    -- Method 2: Grouped players — use instance category leave
    if inGroup then
        local LE_PARTY_CATEGORY_INSTANCE = 2
        local success, err = pcall(C_PartyInfo.LeaveParty, LE_PARTY_CATEGORY_INSTANCE)
        if success then
            Services.Debug("Instance", "Left via LeaveParty(LE_PARTY_CATEGORY_INSTANCE)")
            return true, "Leaving instance..."
        end
        Services.Debug("Instance", "LeaveParty(INSTANCE) failed: " .. tostring(err))
        
    -- Solo: fallback for grouped: Try without category
        local fallbackSuccess = pcall(C_PartyInfo.LeaveParty)
        if fallbackSuccess then
            Services.Debug("Instance", "Left via LeaveParty (no category)")
            return true, "Leaving party and instance..."
        end
        
        Services.Debug("Instance", "All grouped leave methods failed")
        return false, string.format("Cannot leave %s - try right-click portrait → Leave Instance", instanceName or "instance")
    end
    
    -- Solo players from here on (not inGroup)
    
    -- Method 3: Solo LFG content — try LFGTeleport
    if instanceType == "party" or instanceType == "raid" or instanceType == "scenario" then
        local inLFG = false
        if C_PartyInfo and C_PartyInfo.IsPartyLFG then
            local success, result = pcall(C_PartyInfo.IsPartyLFG)
            inLFG = success and result or false
        end
        
        if inLFG then
            local lfgSuccess, lfgErr = pcall(LFGTeleport, true)
            if lfgSuccess then
                Services.Debug("Instance", "Left via LFGTeleport (LFG content)")
                return true, "Teleporting out of instance..."
            end
            Services.Debug("Instance", "LFGTeleport failed: " .. tostring(lfgErr))
        end
    end
    
    -- Method 4: Solo non-LFG — ConvertToParty is PROTECTED
    Services.Debug("Instance", "Solo non-LFG instance - manual party conversion required")
    
    local helpMessage = "Solo Exit → Right-click portrait → Convert to Party → Wait 60s → Auto-exits"
    
    if instanceType == "scenario" then
        helpMessage = helpMessage .. " (or use exit portal if available)"
    elseif difficultyID == 23 or difficultyID == 8 then
        helpMessage = "Mythic Solo → Right-click portrait → Convert to Party → Wait 60s → Auto-exits"
    end
    
    return false, helpMessage
end

-- ============================================================
-- Initialization
-- ============================================================

function Services.Initialize()
    -- Sync debug flag from Config so Debug() never needs to call GetModule
    local config = JustQuest.Core.GetModule("Config")
    local enabled = config and (config.IsDebugMode and config.IsDebugMode() or config.Get(nil, "debugMode")) or false
    Services.SetDebugMode(enabled)
    Services.SetupFastModeHooks()
end

function Services.OnDisable()
    Services:CancelAllTimers()
    activeTimers = {}
    Services._coalescingActive = false
end

-- ============================================================
-- Module Registration
-- ============================================================

JustQuest.Core.RegisterModule("Services", Services, {"Config"})

return Services
