-- GossipEngine.lua — Priority-based dialog automation with whitelist preference and safety validation

local ADDON_NAME, JustQuest = ...

local GossipEngine = {}

-- Memoized module accessors
local GetSafetyEngine = JustQuest.Core.ModuleGetter("SafetyEngine")
local GetServices     = JustQuest.Core.ModuleGetter("Services")
local GetConfig       = JustQuest.Core.ModuleGetter("Config")

-- UnitGUID("npc") returns a "secret value" under addon taint (11.x+), and
-- comparing it with ==/~= raises an error that aborts the whole pass. Compare
-- through pcall and treat an uncomparable (secret) pair as the SAME npc, so
-- automation continues instead of crashing. Per-NPC loop protection still has
-- chain-depth + time-decay as a backstop. Truthiness checks (if not guid) are
-- unaffected and stay inline.
local function rawEq(a, b) return a == b end
local function SameNPC(a, b)
    local ok, equal = pcall(rawEq, a, b)
    return (not ok) or equal
end

-- Anti-loop cooldown: after a menu is left for manual selection, ignore identical
-- re-shows (same NPC + same option count) for this long.
local FAILED_GOSSIP_TTL = 5.0

-- ============================================================
-- State Management
-- ============================================================

local state = {
    chainDepth = 0,
    confirmationPending = false,
    automationHalted = false,
    lastShowTime = 0,
    expectedGUID = nil,
    failedGossipNPC = nil,
    failedGossipTime = 0,
    failedGossipOptions = 0,
    autoSelected = false,
}

-- The loop guards, as one unit: chain depth, the per-option repeat history, and the
-- failed-menu fingerprint. They only bound a walk if they outlive a single menu, so
-- clear them ONLY where a conversation genuinely ends (target change) or real progress
-- happened (quest accept/turn-in resets depth via ResetChainState). See OnGossipClosed
-- for why a gossip close is not, on its own, either of those.
local function ResetLoopGuards(safetyEngine)
    state.chainDepth = 0
    state.failedGossipNPC = nil
    state.failedGossipTime = 0
    state.failedGossipOptions = 0
    state.autoSelected = false

    safetyEngine = safetyEngine or GetSafetyEngine()
    if safetyEngine and safetyEngine.ClearSelections then
        safetyEngine.ClearSelections()
    end
end

-- Check if we're in failed gossip cooldown for current NPC
function GossipEngine.IsInFailedCooldown()
    if not state.failedGossipNPC then return false end

    local currentNPC = UnitGUID and UnitGUID("npc")
    if not currentNPC or not SameNPC(currentNPC, state.failedGossipNPC) then return false end

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

-- Returns true for gossip options flagged as quest-type (Blizzard prepends a blue
-- "(Quest)" label). Delegates to the shared detector: QuestLabelPrepend is the
-- authoritative server-set flag, with the localized "(Quest)" option text as a
-- fallback for odd/old content. The 12.0 GossipOptionUIInfo struct carries no
-- type / typeLabelText / questStartItemID fields (same shape on retail and Classic
-- content), so those older signals never populate and are not checked.
local function IsQuestOption(option)
    local services = GetServices()
    return (services and services.IsQuestRelatedGossip(option)) and true or false
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

    if safetyEngine then
        safetyEngine.MarkSelection(option.gossipOptionID or option.orderIndex)
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

local function TrySelectSafeOption(option, safetyEngine, services)
    local optionID = option.gossipOptionID or option.orderIndex
    if safetyEngine.ShouldSkipRepeat(optionID) then return false end
    if safetyEngine.IsBlacklisted(option) then return false end
    if not SelectOption(option, safetyEngine, services) then return false end
    state.failedGossipNPC = nil
    state.failedGossipTime = 0
    state.failedGossipOptions = 0
    -- Marks any gossip close that follows as server-driven, not player-driven.
    state.autoSelected = true
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
    if state.expectedGUID and not SameNPC(state.expectedGUID, currentNPC) then return false end

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

    -- Interactable options right now (status Available or AlreadyComplete).
    local available = {}
    for _, option in ipairs(allOptions) do
        if safetyEngine.OptionIsAvailable(option) then
            available[#available + 1] = option
        end
    end

    -- Anti-loop: fingerprint against the TOTAL option count so any server-side
    -- state change (a locked option unlocking, etc.) resets the cooldown
    if SameNPC(state.failedGossipNPC, currentNPC) and
       state.failedGossipOptions == #allOptions and
       (GetTime() - state.failedGossipTime) < FAILED_GOSSIP_TTL then
        safetyEngine.EndProcessing("failed_gossip_cooldown")
        return false
    end

    if #available == 0 then
        safetyEngine.EndProcessing("no_options")
        return false
    end

    -- Chain-depth accounting (anti-loop) — every auto-selection counts toward the
    -- cap. Reset only on real progress (NPC change, quest accept/turn-in), NOT on a
    -- time gap and NOT on a bare gossip close: a menu that re-shows after each
    -- successful select would otherwise reset the counter every cycle and walk without
    -- bound (the slow-loop the player sees "sometimes").
    state.chainDepth = state.chainDepth + 1
    local validDepth, chainReason = safetyEngine.ValidateChainDepth(state.chainDepth)
    if not validDepth then
        return halt(chainReason)
    end

    -- PRIORITY 1 — WHITELIST: user-explicit, the escape hatch for multi-option
    -- filler. Bypasses service/quest gating, but not blacklist/repeat protection.
    for _, option in ipairs(available) do
        if safetyEngine.IsWhitelisted(option)
           and TrySelectSafeOption(option, safetyEngine, services) then
            safetyEngine.EndProcessing("whitelisted_option_selected")
            return true
        end
    end

    -- PRIORITY 2 — QUEST OPTIONS: gossip entries flagged as quest-linked (server
    -- QuestLabelPrepend flag, with a localized "(Quest)" text fallback). Safe to take
    -- at any option count; the quest itself is gated by QUEST_DETAIL safety.
    for _, option in ipairs(available) do
        if IsQuestOption(option)
           and TrySelectSafeOption(option, safetyEngine, services) then
            safetyEngine.EndProcessing("quest_option_selected", true)
            return true
        end
    end

    -- The server forcing the menu (ForceGossip / ForceInteractionOnSingleChoice)
    -- is an explicit "show the player" — a true decision — so never auto-advance
    -- past it, in either mode.
    local forceGossip = C_GossipInfo.ForceGossip and C_GossipInfo.ForceGossip() or false
    local config = GetConfig()
    local aggressive = not config or config.Get("gossip", "aggressive") ~= false

    -- A menu holding a blacklisted option (teleport/portal/campaign-skip ship by
    -- default) is a real decision, not navigation filler. Traversing past it by taking
    -- some OTHER option answers it for the player by omission, and in fast mode the menu
    -- is hidden, so they never see the option was offered at all. Treat it like
    -- ForceGossip: stop and surface the menu. The whitelist and quest-flagged passes
    -- above already ran — those are explicit intent and quest content, not guesswork.
    local hasUnsafeOption = false
    for _, option in ipairs(available) do
        if safetyEngine.IsBlacklisted(option) then
            hasUnsafeOption = true
            break
        end
    end

    if aggressive and not forceGossip and not hasUnsafeOption then
        -- PRIORITY 3 (aggressive, default) — TRAVERSE: advance through gossip so
        -- quests buried behind dialog are reached without stopping the player on pure
        -- navigation. Two passes in ONE handling (no extra round-trip): first any
        -- NON-service option — services (vendor/trainer/banker) lead away from quests
        -- and open a blocking frame — then services, so a pure service NPC still
        -- fires in the same tick when that's all there is. Safety is layered and
        -- already enforced here:
        --   • a blacklisted keyword (teleport/portal/time/campaign-skip ship by
        --     default) anywhere in the menu stops the traverse before it starts — see
        --     hasUnsafeOption above — and TrySelectSafeOption blocks the option itself,
        --   • costed/coded/otherwise-irreversible options never execute from this
        --     call — the server intercepts them with GOSSIP_CONFIRM / GOSSIP_ENTER_CODE,
        --     which we never auto-accept (they surface for the player), and
        --   • once-per-conversation repeat + chain-depth guards bound the walk, so a
        --     looping or dead-end menu surfaces instead of spinning.
        for pass = 1, 2 do
            local wantService = (pass == 2)  -- pass 1: conversation options; pass 2: services
            for _, option in ipairs(available) do
                if IsServiceOption(option) == wantService
                   and TrySelectSafeOption(option, safetyEngine, services) then
                    safetyEngine.EndProcessing("gossip_option_selected")
                    return true
                end
            end
        end
    elseif not aggressive then
        -- PRIORITY 3 (conservative) — SINGLE SERVICE STEP (Blizzard-exact): exactly
        -- one option Blizzard marks auto-selectable (selectOptionWhenOnlyOption, with
        -- an icon fallback), no quests pending, not forced. Mirrors HandleShow().
        local npcHasQuests = (C_GossipInfo.GetNumAvailableQuests and C_GossipInfo.GetNumAvailableQuests() or 0) > 0
                          or (C_GossipInfo.GetNumActiveQuests and C_GossipInfo.GetNumActiveQuests() or 0) > 0
        if #available == 1 and IsServiceOption(available[1])
           and not npcHasQuests and not forceGossip then
            if TrySelectSafeOption(available[1], safetyEngine, services) then
                safetyEngine.EndProcessing("service_step_selected")
                return true
            end
        end
    end

    -- Nothing auto-selectable: a forced/true-decision menu, a menu holding an option we
    -- refuse to click, or (conservative mode) a multi-option / non-whitelisted menu.
    -- Leave it for the player — EndProcessing below un-hides the frame, since
    -- "no_safe_options" is not a continuing reason. Fingerprint the unchanged menu so
    -- repeated pumps don't loop on it.
    if services.Debug then
        services.Debug("Gossip", hasUnsafeOption
            and "Menu holds an unsafe option — surfacing for manual choice"
            or "No auto-selectable option — leaving for manual")
    end
    state.failedGossipNPC     = currentNPC
    state.failedGossipTime    = GetTime()
    state.failedGossipOptions = #allOptions

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
    if not state.expectedGUID or not SameNPC(state.expectedGUID, currentGUID) then
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
    state.confirmationPending = false
    state.automationHalted = false
    state.expectedGUID = nil

    local safetyEngine = GetSafetyEngine()

    -- A close that follows OUR OWN auto-selection is the server tearing down one step
    -- of a conversation it is about to re-show — not the player leaving. The loop
    -- guards have to survive it: clearing them here is what let a menu that re-shows
    -- after every selection wipe its own chain-depth and repeat history every cycle and
    -- walk without bound (the loop the player sees). The repeat guard then blocks the
    -- option on the re-show and the menu surfaces, as intended.
    -- A close with NO auto-selection behind it is a real end (player escaped, walked
    -- off, or we left the menu for manual) — reset, so the next conversation is fresh.
    if state.autoSelected then
        state.autoSelected = false
    else
        ResetLoopGuards(safetyEngine)
    end

    -- DON'T reset state or workflow if BUSY — a quest was likely selected from
    -- gossip and quest events (QUEST_PROGRESS, QUEST_COMPLETE, QUEST_TURNED_IN)
    -- will handle state transitions. Premature reset causes race conditions:
    -- DispatchContent/repumps see IDLE and start new processing mid-turn-in.
    -- If truly stuck, SafetyEngine's periodic recovery handles it (1-4s).
    if not (safetyEngine and safetyEngine.IsBusy()) then
        -- Terminal close: stop every pending automation timer (one set).
        if services and services.CancelAutomationTimers then
            services.CancelAutomationTimers()
        end
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

    state.confirmationPending = false
    state.automationHalted = false
    state.expectedGUID = nil

    -- A new target is the one unambiguous end of a conversation, so this is where the
    -- loop guards clear (a gossip close is not — see OnGossipClosed). This must clear
    -- the repeat history too, or the previous NPC's already-picked options stay
    -- off-limits on the next one.
    ResetLoopGuards()

    -- New target: drop any pending automation timers from the previous NPC.
    if services and services.CancelAutomationTimers then
        services.CancelAutomationTimers()
    end
end

-- ============================================================
-- Module API
-- ============================================================

function GossipEngine.OnDisable()
    state.chainDepth = 0
    state.confirmationPending = false
    state.automationHalted = false
end

function GossipEngine.Initialize()
end

-- Reset gossip chain state (called after quest accept to prevent stale depth)
function GossipEngine.ResetChainState()
    state.chainDepth = 0
    state.automationHalted = false
end

function GossipEngine.GetStateInfo()
    return {
        chainDepth = state.chainDepth,
        confirmationPending = state.confirmationPending,
        automationHalted = state.automationHalted,
        lastShowTime = state.lastShowTime,
        expectedGUID = state.expectedGUID,
        autoSelected = state.autoSelected,
    }
end

-- ============================================================
-- Module Registration
-- ============================================================

JustQuest.Core.RegisterModule("GossipEngine", GossipEngine, {"Services", "Config", "SafetyEngine"})

return GossipEngine
