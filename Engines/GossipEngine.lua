-- GossipEngine.lua — Priority-based dialog automation with whitelist preference and safety validation

local ADDON_NAME, JustQuest = ...

local GossipEngine = {}

-- Module cache (lazy initialization)
local moduleCache = {}

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

-- ============================================================
-- State Management
-- ============================================================

local state = {
    chainDepth = 0,
    confirmationPending = false,
    lastNPC = nil,
    automationHalted = false,
    lastShowTime = 0,
    expectedGUID = nil,
    failedGossipNPC = nil,
    failedGossipTime = 0,
    failedGossipOptions = 0,
    lastChainIncrement = 0,
}

-- Check if we're in failed gossip cooldown for current NPC
function GossipEngine.IsInFailedCooldown()
    if not state.failedGossipNPC then return false end

    local currentNPC = UnitGUID and UnitGUID("npc")
    if not currentNPC or currentNPC ~= state.failedGossipNPC then return false end

    local FAILED_GOSSIP_TTL = 5.0
    if (GetTime() - state.failedGossipTime) >= FAILED_GOSSIP_TTL then
        return false
    end

    local currentOptions = C_GossipInfo and C_GossipInfo.GetOptions and C_GossipInfo.GetOptions() or {}
    if #currentOptions ~= state.failedGossipOptions then
        return false
    end

    if JustQuest._lastProcessingTime and JustQuest._lastProcessingTime > state.failedGossipTime then
        state.failedGossipNPC = nil
        return false
    end

    return true
end

-- ============================================================
-- Option Classification
-- ============================================================

-- Gossip icons associated with NPC services (empirically verified fileIDs).
-- Used as a fallback when selectOptionWhenOnlyOption is ambiguous.
local SERVICE_ICONS = {
    [132046] = true,  -- BankerGossipIcon
    [132047] = true,  -- BattlemasterGossipIcon
    [132049] = true,  -- BinderGossipIcon (innkeeper set-home)
    [132050] = true,  -- Banker variant (deposit box)
    [132051] = true,  -- Binder variant
    [132056] = true,  -- PetitionGossipIcon
    [132057] = true,  -- TaxiGossipIcon
    [132058] = true,  -- TrainerGossipIcon
    [132059] = true,  -- TabardGossipIcon
    [132060] = true,  -- VendorGossipIcon
    [132061] = true,  -- Taxi variant
    [132147] = true,  -- Binder variant (innkeeper)
    [133784] = true,  -- Trainer variant
}

-- Returns true for service/utility options (vendor, banker, binder, trainer, etc.)
-- Primary signal: selectOptionWhenOnlyOption == true means Blizzard considers
-- this option safe to auto-select (service NPC pattern, replaces old type-based check).
-- Fallback: known service icon fileIDs for edge cases.
local function IsServiceOption(option)
    if not option then return false end
    -- selectOptionWhenOnlyOption is the modern (10.0+) service signal.
    -- Blizzard sets this to true on service options so the UI auto-selects them
    -- when no quest or other gossip content is present.
    if option.selectOptionWhenOnlyOption then return true end
    -- Icon-based fallback
    if option.icon and SERVICE_ICONS[option.icon] then return true end
    return false
end

-- Returns true for gossip options flagged as quest-type (blue quest label in UI)
local function IsQuestOption(option)
    if not option then return false end
    -- flags-based check: QuestLabelPrepend flag means Blizzard prepends "(Quest)"
    -- in blue text on the UI button. This is the most reliable signal.
    if option.flags and Enum and Enum.GossipOptionRecFlags
       and Enum.GossipOptionRecFlags.QuestLabelPrepend then
        if bit and bit.band and bit.band(option.flags, Enum.GossipOptionRecFlags.QuestLabelPrepend) ~= 0 then
            return true
        end
    end
    -- typeLabelText is set to e.g. "Quest" for quest-opening gossip entries
    if option.typeLabelText then
        if option.typeLabelText:lower():find("quest", 1, true) then return true end
    end
    -- Enum-based check (ActiveQuest / AvailableQuest / Quest, depending on client version)
    if option.type and Enum and Enum.GossipOptionType then
        local E = Enum.GossipOptionType
        if (E.ActiveQuest   and option.type == E.ActiveQuest)   or
           (E.AvailableQuest and option.type == E.AvailableQuest) or
           (E.Quest          and option.type == E.Quest) then
            return true
        end
    end
    -- Non-zero questStartItemID also signals a quest-linked option
    if option.questStartItemID and option.questStartItemID ~= 0 then return true end
    return false
end

-- ============================================================
-- Option Selection
-- ============================================================

local function SelectOption(option, safetyEngine, services)
    if not (option and C_GossipInfo) then return false end

    if not safetyEngine then
        safetyEngine = GetSafetyEngine()
    end
    if not services then
        services = GetServices()
    end

    if safetyEngine and not safetyEngine.OptionIsAvailable(option) then
        return false
    end

    local success
    if option.gossipOptionID then
        local ok = pcall(C_GossipInfo.SelectOption, option.gossipOptionID)
        success = ok
    elseif option.orderIndex and C_GossipInfo.SelectOptionByIndex then
        local ok = pcall(C_GossipInfo.SelectOptionByIndex, option.orderIndex)
        success = ok
    else
        return false
    end

    if not success then return false end

    local guid = services and services.SafeCall(UnitGUID, "npc")
    if guid and safetyEngine then
        safetyEngine.MarkSelection(guid, option.gossipOptionID or option.orderIndex)
    end

    if services and services.ScheduleContentCheck then
        local pumpDelay = services.GetTiming and services.GetTiming("QUEST_PUMP_STANDARD", 0.15) or 0.15
        services.ScheduleContentCheck(pumpDelay, "after_gossip_selection")
    end

    return true
end

-- ============================================================
-- Option Safety Helper
-- ============================================================

local function TrySelectSafeOption(option, safetyEngine, services, numAvailable)
    local guid = services.SafeCall(UnitGUID, "npc")
    local optionID = option.gossipOptionID or option.orderIndex
    if safetyEngine.ShouldSkipRepeat(guid, optionID, numAvailable) then return false end
    if safetyEngine.IsBlacklisted(option) then return false end
    if not SelectOption(option, safetyEngine, services) then return false end
    state.failedGossipNPC = nil
    state.failedGossipTime = 0
    state.failedGossipOptions = 0
    return true
end

-- ============================================================
-- Core Gossip Handler
-- ============================================================

local function HandleGossip(skipPreChecks)
    local services = GetServices()
    local safetyEngine = GetSafetyEngine()
    if not (services and safetyEngine) then return false end

    -- Always check modifier keys, even when skipPreChecks=true
    if not services.ShouldAutomate() then
        services.RestoreAutomationFrames()
        return false
    end

    local function halt(reason)
        state.automationHalted = true
        services.OutputHalt(reason)
        safetyEngine.EndProcessing(reason)
        return false
    end

    if not skipPreChecks then
        if not services.CanAutomate() then return false end
        if not services.IsAutomationContextAllowed() then return false end
        if safetyEngine.IsBusy() then return false end
    end

    if state.confirmationPending then return false end

    local currentNPC = services.SafeCall(UnitGUID, "npc")
    if not currentNPC then return false end
    if state.expectedGUID and state.expectedGUID ~= currentNPC then return false end

    if state.lastNPC ~= currentNPC then
        state.chainDepth = 0
        state.automationHalted = false
        state.lastNPC = currentNPC
        state.failedGossipNPC = nil
        state.failedGossipTime = 0
        state.failedGossipOptions = 0
        if safetyEngine.ClearNPCSelection then
            safetyEngine.ClearNPCSelection(currentNPC)
        end
    end

    -- Respect automation halt if no quest content exists
    if state.automationHalted then
        if not (services.HasGossipQuests and services.HasGossipQuests()) then
            return false
        end
        state.automationHalted = false
    end

    -- When skipPreChecks=true, caller (QuestEngine) already owns the BUSY state
    if not skipPreChecks then
        if not safetyEngine.BeginProcessing("handling_gossip") then return false end
    end

    -- Get all options (includes unavailable/locked — needed for fingerprinting)
    local allOptions = services.SafeCall(C_GossipInfo and C_GossipInfo.GetOptions) or {}

    if #allOptions == 0 then
        safetyEngine.EndProcessing("no_options")
        return false
    end

    -- Split options into two categories:
    --   available  = interactable right now (status Available or AlreadyComplete)
    --   pending    = present on NPC but not yet clickable (Unavailable / Locked)
    --                used to anticipate what will appear as automation progresses
    local available = {}
    local pending   = {}
    for _, option in ipairs(allOptions) do
        if safetyEngine.OptionIsAvailable(option) then
            available[#available + 1] = option
        elseif safetyEngine.OptionIsPending(option) then
            pending[#pending + 1] = option
        end
    end

    -- Anti-loop: fingerprint against the TOTAL option count so any server-side
    -- state change (a locked option unlocking, etc.) resets the cooldown
    local FAILED_GOSSIP_TTL = 5.0
    if state.failedGossipNPC == currentNPC and
       state.failedGossipOptions == #allOptions and
       (GetTime() - state.failedGossipTime) < FAILED_GOSSIP_TTL then
        safetyEngine.EndProcessing("failed_gossip_cooldown")
        return false
    end

    if #available == 0 then
        safetyEngine.EndProcessing("no_options")
        return false
    end

    -- Single service option: select directly, bypassing cost/keyword checks
    if #available == 1 and IsServiceOption(available[1]) then
        local option = available[1]
        local guid = services.SafeCall(UnitGUID, "npc")
        local optionID = option.gossipOptionID or option.orderIndex
        if not safetyEngine.ShouldSkipRepeat(guid, optionID, 1) then
            if SelectOption(option, safetyEngine, services) then
                safetyEngine.EndProcessing("option_selected")
                return true
            end
        end
        safetyEngine.EndProcessing("no_safe_options")
        return false
    end

    -- Filter out service options (vendor, trainer, binder, etc.) when mixed with
    -- regular gossip/quest options. Only halt if ALL options are services.
    if #available > 1 then
        local nonService = {}
        for _, option in ipairs(available) do
            if not IsServiceOption(option) then
                nonService[#nonService + 1] = option
            end
        end
        if #nonService > 0 then
            available = nonService
        else
            return halt("all_service_options")
        end
    end

    -- NOTE: selectOptionWhenOnlyOption == false is NOT a reliable signal for
    -- "player must choose between activities". Blizzard sets it to false on most
    -- regular gossip options by default. Genuine activity/branching choices are
    -- caught by downstream safety: colored text halt (2+ colored options in
    -- ValidateInteraction), blacklist, and repeat protection.

    -- Extract actual color codes from UI frame buttons.
    -- C_GossipInfo.GetOptions() returns plain text — colors only live in UI frames.
    local uiColors = safetyEngine.GetGossipOptionUIColors and safetyEngine.GetGossipOptionUIColors() or {}

    -- WHITELIST: Highest priority (bypasses all safety except repeat protection)
    for _, option in ipairs(available) do
        if safetyEngine.IsWhitelisted(option) then
            local guid = services.SafeCall(UnitGUID, "npc")
            local optionID = option.gossipOptionID or option.orderIndex
            if not safetyEngine.ShouldSkipRepeat(guid, optionID, #available) then
                if SelectOption(option, safetyEngine, services) then
                    safetyEngine.EndProcessing("whitelisted_option_selected")
                    return true
                end
            end
        end
    end

    -- SAFETY VALIDATION (uses UI-extracted colors for reliable color detection)
    local shouldHalt, reason = safetyEngine.ValidateInteraction(available, uiColors)
    if shouldHalt then
        return halt(reason)
    end

    -- Time-based chain depth decay: if no gossip activity for longer than
    -- the repeat window, reset depth. Handles cases where the gossip frame
    -- stays open across quest interactions without GOSSIP_CLOSED firing.
    local chainDecayTime = JustQuest.Constants.TIMING.GOSSIP_REPEAT_WINDOW or 1.5
    if state.lastChainIncrement > 0 and (GetTime() - state.lastChainIncrement) > chainDecayTime then
        state.chainDepth = 0
        state.automationHalted = false
    end
    state.lastChainIncrement = GetTime()

    state.chainDepth = state.chainDepth + 1
    local valid, chainReason = safetyEngine.ValidateChainDepth(state.chainDepth)
    if not valid then
        return halt(chainReason)
    end

    -- QUEST PRIORITY: prefer quest-flagged gossip options over plain gossip
    for _, option in ipairs(available) do
        if IsQuestOption(option) and TrySelectSafeOption(option, safetyEngine, services, #available) then
            safetyEngine.EndProcessing("quest_option_selected", true)
            return true
        end
    end

    -- COLORED TEXT PRIORITY: server-colored options (blue text in UI) signal
    -- quest-related content — select them regardless of option count.
    for _, option in ipairs(available) do
        local optionKey = option.gossipOptionID or option.orderIndex
        local uiInfo = optionKey and uiColors[optionKey]
        if uiInfo and uiInfo.hasColor and not uiInfo.hasWarning
           and TrySelectSafeOption(option, safetyEngine, services, #available) then
            safetyEngine.EndProcessing("colored_option_selected")
            return true
        end
    end

    -- No quest content to automate: remaining options are plain gossip with no
    -- quest flags or colored text indicators. Skip automation to avoid
    -- interacting with non-quest dialog that may have gameplay consequences.
    if services.Debug then
        services.Debug("Gossip", "No quest-indicated options found — skipping plain gossip")
    end

    -- Record failure to prevent infinite retry loops
    local guid = services.SafeCall(UnitGUID, "npc")
    state.failedGossipNPC     = guid
    state.failedGossipTime    = GetTime()
    state.failedGossipOptions = #allOptions  -- total fingerprint, not just interactable count

    safetyEngine.EndProcessing("no_safe_options")
    return false
end

-- ============================================================
-- Event Handlers
-- ============================================================

function GossipEngine.OnGossipShow(skipPreChecks)
    local services = GetServices()
    if not services then return false end
    if not services.ShouldAutomate() then
        services.RestoreAutomationFrames()
        return false
    end
    if not services.IsAutomationContextAllowed() then return false end

    if not skipPreChecks then
        if state.lastShowTime and (GetTime() - state.lastShowTime) < 0.1 then
            return false
        end
    end

    state.lastShowTime = GetTime()

    local currentGUID = services.SafeCall(UnitGUID, "npc")
    if not state.expectedGUID or state.expectedGUID ~= currentGUID then
        state.expectedGUID = currentGUID
    end

    local safety = GetSafetyEngine()
    local currentState = safety and safety.GetState() or "IDLE"
    if currentState ~= "IDLE" and not skipPreChecks then
        return false
    end

    return HandleGossip(skipPreChecks)
end

function GossipEngine.OnGossipOptionsRefreshed()
    local services = GetServices()
    if not services then return end
    if not services.ShouldAutomate() then
        services.RestoreAutomationFrames()
        return
    end
    if not services.IsAutomationContextAllowed() then return end
    HandleGossip()
end

function GossipEngine.OnGossipConfirm()
    state.confirmationPending = true
    state.chainDepth = 0
end

function GossipEngine.OnGossipConfirmCancel()
    state.confirmationPending = false
end

function GossipEngine.OnGossipClosed()
    JustQuest._legacyGreetingPolling = nil

    -- Restore frames when gossip closes (fast mode may have hidden them)
    local services = GetServices()
    if services and services.RestoreAutomationFrames then
        services.RestoreAutomationFrames()
    end

    -- Gossip-specific state cleanup (always safe — gossip IS closed)
    state.chainDepth = 0
    state.confirmationPending = false
    state.lastNPC = nil
    state.automationHalted = false
    state.expectedGUID = nil
    state.failedGossipNPC = nil
    state.failedGossipTime = 0
    state.failedGossipOptions = 0

    local safetyEngine = GetSafetyEngine()
    if safetyEngine and safetyEngine.CleanupRecentSelections then
        safetyEngine.CleanupRecentSelections()
    end

    -- DON'T reset state or workflow if BUSY — a quest was likely selected from
    -- gossip and quest events (QUEST_PROGRESS, QUEST_COMPLETE, QUEST_TURNED_IN)
    -- will handle state transitions. Premature reset causes race conditions:
    -- DispatchContent/repumps see IDLE and start new processing mid-turn-in.
    -- If truly stuck, SafetyEngine's periodic recovery handles it (1-4s).
    if not (safetyEngine and safetyEngine.IsBusy()) then
        local questEngine = JustQuest.Core.GetModule("QuestEngine")
        if questEngine and questEngine.ResetWorkflow then
            questEngine.ResetWorkflow()
        end
    elseif services and services.Debug then
        services.Debug("Gossip", "OnGossipClosed: skipping state reset (BUSY - quest transition in progress)")
    end
end

-- ============================================================
-- Target Change Handler (called by Core)
-- ============================================================

function GossipEngine.OnTargetChanged()
    -- Restore frames on target change (fast mode may have hidden them)
    local services = GetServices()
    if services and services.RestoreAutomationFrames then
        services.RestoreAutomationFrames()
    end

    state.chainDepth = 0
    state.confirmationPending = false
    state.automationHalted = false
    state.expectedGUID = nil
    state.failedGossipNPC = nil
    state.failedGossipTime = 0
    state.failedGossipOptions = 0
end

-- ============================================================
-- Module API
-- ============================================================

function GossipEngine.OnDisable()
    state.chainDepth = 0
    state.confirmationPending = false
    state.lastNPC = nil
    state.automationHalted = false
end

function GossipEngine.Initialize()
end

-- Reset gossip chain state (called after quest accept to prevent stale depth)
function GossipEngine.ResetChainState()
    state.chainDepth = 0
    state.automationHalted = false
    state.lastChainIncrement = 0
end

function GossipEngine.GetStateInfo()
    return {
        chainDepth = state.chainDepth,
        confirmationPending = state.confirmationPending,
        lastNPC = state.lastNPC,
        automationHalted = state.automationHalted,
        lastShowTime = state.lastShowTime,
        expectedGUID = state.expectedGUID,
    }
end

-- ============================================================
-- Module Registration
-- ============================================================

JustQuest.Core.RegisterModule("GossipEngine", GossipEngine, {"Services", "Config", "SafetyEngine"})

return GossipEngine
