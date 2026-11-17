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

-- One-shot automation-flow timers, cancelled together at terminal points
-- (manual takeover, state recovery, gossip close, target change) so every
-- teardown path stops the same complete set instead of a remembered subset.
-- Deliberately EXCLUDES the persistent recovery nets (safety_stuck_state_recovery,
-- container_periodic_scan), the post-automation container scans, and the LFG
-- subsystem — those must keep running across a teardown.
local AUTOMATION_TIMERS = {
    "content_repump",
    "quest_processing_timeout", "deferred_onquestlog_update",
    "reward_data_retry", "reward_select_fallback",
    "state_recovery_resume",
    "legacy_api_poll",
    "automation_indicator_show",
}

function Services.CancelAutomationTimers()
    for _, key in ipairs(AUTOMATION_TIMERS) do
        Services.CancelScheduled(key)
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

    -- Timestamped (seconds, mod 1000) so step-to-step gaps can be read straight off the log.
    print(string.format("|cff00ccffJQ %.2f %s:|r %s", GetTime() % 1000, module or "Core", out))
end

-- Direct answers to something the player did — a slash command, a button. Automation itself
-- says nothing in chat any more; it uses Debug above, so a quiet game stays quiet and the
-- detail is one /jq debug away.
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

-- Friendly text for the reasons actually passed to OutputHalt(). Any reason not
-- listed falls through to its raw slug, so keep this in sync with the OutputHalt
-- call sites rather than accumulating unused entries.
local HALT_REASONS = {
    ["interfering_frame"]              = "Non-quest frame detected",
    ["legacy_greeting"]               = "Legacy greeting panel detected",
    ["max_depth"]                     = "Chain depth limit reached",
    ["quest_log_full"]                = "Quest log is full",
    ["quest_requires_currency"]       = "Quest requires spending currency",
    ["quest_requires_trade_items"]    = "Quest requires trade goods or crafted items",
    ["quest_requires_uncached_items"] = "Quest requires an item that hasn't loaded yet",
    ["expensive_quest_requires_payment"] = "Quest turn-in costs gold",
    ["multiple_significant_rewards"]  = "Multiple significant rewards — manual selection required",
    ["reward_items_not_loaded"]       = "Reward items haven't finished loading",
    ["no_comparable_reward_value"]    = "Rewards can't be compared by value — pick one",
}

function Services.OutputHalt(reason, extraInfo)
    reason = reason or "paused"  -- guard: reason is the throttle table key, never nil
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
    
    -- Fast mode: restore frame visibility so player can interact manually. This is the part
    -- that actually matters — the panel comes back and you deal with it. The announcement was
    -- only ever narration on top of a frame you can already see.
    Services.RestoreAutomationFrames()

    Services.Debug("Halt", msg .. " - manual interaction required")
    return true  -- handled (the throttle consumed this reason)
end

-- ============================================================
-- Automation Summary (opt-in)
-- ============================================================
-- Counts what automation DID across one chain and prints a single concise line once the
-- chain settles. Every recorded action reschedules the same debounce flush, so a
-- multi-quest hub collapses into one summary instead of a line per step. NoteAutomation
-- is a no-op unless the option is on, so there is zero cost when disabled.
local SUMMARY_DEBOUNCE = 1.5
local summary = { accepted = 0, turnedIn = 0, containers = 0 }
local summaryPending = false

function Services.FlushAutomationSummary()
    if not summaryPending then return end

    -- Still mid-chain (a step lagged past the debounce)? Wait and retry so the summary
    -- prints only after the whole chain has actually settled.
    local safety = JustQuest.Core.GetModule("SafetyEngine")
    if safety and safety.IsBusy() then
        Services.ScheduleOnce("automation_summary_flush", SUMMARY_DEBOUNCE, Services.FlushAutomationSummary)
        return
    end

    local parts = {}
    if summary.accepted > 0   then parts[#parts + 1] = "accepted " .. summary.accepted end
    if summary.turnedIn > 0   then parts[#parts + 1] = "turned in " .. summary.turnedIn end
    if summary.containers > 0 then
        parts[#parts + 1] = "opened " .. summary.containers ..
            (summary.containers == 1 and " container" or " containers")
    end

    summary.accepted, summary.turnedIn, summary.containers = 0, 0, 0
    summaryPending = false

    if #parts > 0 then
        Services.Info(table.concat(parts, ", "))
    end
end

-- Record one automated action. kind = "accepted" | "turnedIn" | "containers".
function Services.NoteAutomation(kind, count)
    local config = JustQuest.Core.GetModule("Config")
    if not (config and config.Get(nil, "automationSummary")) then return end
    if summary[kind] == nil then return end
    summary[kind] = summary[kind] + (count or 1)
    summaryPending = true
    Services.ScheduleOnce("automation_summary_flush", SUMMARY_DEBOUNCE, Services.FlushAutomationSummary)
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

-- True when the current gossip interaction is an actual quest giver: a quest to
-- accept, a quest to turn in, or a quest-flagged ("(Quest)") gossip option. An
-- in-progress quest with no turn-in here does NOT count. Fast mode uses this so it
-- only hides the interface for quest mobs — vendor/trainer/flavor gossip stays visible.
function Services.HasQuestGiverContent()
    if Services.HasActionableQuestContent() then return true end
    local options = Services.SafeCall(C_GossipInfo and C_GossipInfo.GetOptions)
    if type(options) == "table" then
        for _, option in ipairs(options) do
            if Services.IsQuestRelatedGossip(option) then return true end
        end
    end
    return false
end

local function FastModeSuppressFrame(frame)
    local config = JustQuest.Core.GetModule("Config")
    if not (config and config.Get(nil, "fastMode")) then return end
    -- These OnShow hooks are installed once and live forever, so they must honour the
    -- same enable gate as everything else. With the addon disabled, no event handler
    -- runs — nothing could un-hide what this hid, leaving a shown-but-invisible frame
    -- clearable only by walking out of range.
    if not Services.IsAutomationEnabled() then return end
    if not Services.ShouldAutomate() then return end  -- modifier held, or a manual conversation
    if Services.HasInterferingFrame() then return end

    -- Hide for quest mobs (offer / turn-in / quest-flagged gossip) and for pure
    -- flavor gossip (no options) — flavor is auto-closed once open, so hiding it
    -- first avoids a flash. QuestFrame is always a quest interaction. While BUSY
    -- the frame is the next step of an active chain (e.g. a blue-quest gossip
    -- chain), so hide it regardless of content even if its data hasn't populated
    -- yet. Only a real vendor / service gossip opened on its own stays visible.
    local safety = JustQuest.Core.GetModule("SafetyEngine")
    if frame == GossipFrame and not (safety and safety.IsBusy()) and not Services.HasQuestGiverContent() then
        local options = Services.SafeCall(C_GossipInfo.GetOptions)
        if type(options) == "table" and #options > 0 then
            return  -- service/vendor gossip with options but no quests: leave visible
        end
    end

    frame:SetAlpha(0)
end

-- ============================================================
-- Manual conversation (modifier held when the NPC dialog opened)
-- ============================================================
-- A modifier held as a conversation OPENS hands the whole conversation to the player — gossip,
-- the quest it leads to, the reward — not just the events that happen to arrive while the key
-- is still down. Releasing the key mid-conversation no longer lets a late event (item data
-- loading, a repump) take over a window the player opened to read. Re-talking to the NPC
-- without the modifier starts automation again.
--
-- The boundary is the quest/gossip frames: a conversation hops between them (gossip -> quest
-- detail -> gossip) with at most one server round-trip where neither is shown, so a new one
-- starts only when they reopen after a longer gap than that. The gossip -> quest hop doesn't
-- need the guess: the server flags it (GOSSIP_CLOSED interactionIsContinuing, the same signal
-- GossipFrame keys its own teardown on), and a flagged close bridges any gap.
-- ponytail: the quest -> gossip hop (after a turn-in) still rides the time gap; a >1s lag
-- spike there reads as a new conversation. The interaction-event log below exists to find a
-- server signal for that leg too.
local REINTERACT_GAP = 1.0
-- How long a server-flagged "continuing" close keeps bridging. Bounded so a flag whose next
-- dialog never comes (the NPC handed off to a vendor) can't latch onto a later conversation.
local CONTINUING_BRIDGE = 5.0
local dialogContinuingUntil = 0
-- The click lands a server round-trip before the frame shows, so a modifier released inside
-- that window was still held at the click.
-- ponytail: fixed window; a modifier tapped for something else just before a plain click
-- also reads as manual. Ceiling accepted — the cost is one conversation done by hand.
local MODIFIER_GRACE = 0.5
local manualConversation = false
local dialogClosedAt = 0
local modifierUpAt = 0

local function ModifierHeld()
    return IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
end

function Services.NoteModifierReleased()
    modifierUpAt = GetTime()
end

-- GossipEngine.OnGossipClosed reports the server's "this conversation continues" flag here.
function Services.NoteDialogContinuing()
    dialogContinuingUntil = GetTime() + CONTINUING_BRIDGE
end

-- True while a flagged close is waiting for its next dialog (the dispatch poll rides it out).
function Services.IsDialogContinuing()
    return GetTime() < dialogContinuingUntil
end

local function DialogFrameShown()
    return (QuestFrame and QuestFrame:IsShown()) or (GossipFrame and GossipFrame:IsShown()) or false
end

local function OnDialogFrameShow(frame)
    local other = (frame == QuestFrame) and GossipFrame or QuestFrame
    local continuing = (other and other:IsShown()) or (GetTime() - dialogClosedAt) < REINTERACT_GAP
                       or Services.IsDialogContinuing()
    dialogContinuingUntil = 0  -- consumed by the dialog it was bridging to
    if ModifierHeld() or (GetTime() - modifierUpAt) < MODIFIER_GRACE then
        if not manualConversation then Services.Debug("Services", "Modifier at open - conversation is manual") end
        manualConversation = true
    elseif not continuing then
        manualConversation = false
    end
    FastModeSuppressFrame(frame)
end

local function OnDialogFrameHide()
    if not DialogFrameShown() then dialogClosedAt = GetTime() end
end

-- Seconds since the last quest/gossip window closed; 0 while one is open.
function Services.DialogClosedFor()
    if DialogFrameShown() then return 0 end
    return GetTime() - dialogClosedAt
end

function Services.IsManualConversation()
    return manualConversation and DialogFrameShown()
end

function Services.SetupFastModeHooks()
    for _, frame in ipairs({ QuestFrame, GossipFrame }) do
        if frame and not frame._jqFastHooked then
            frame:HookScript("OnShow", OnDialogFrameShow)
            frame:HookScript("OnHide", OnDialogFrameHide)
            frame._jqFastHooked = true
        end
    end
end

function Services.RestoreAutomationFrames()
    if QuestFrame then QuestFrame:SetAlpha(1) end
    if GossipFrame then GossipFrame:SetAlpha(1) end
    -- DelveEngine hides this while auto-taking a power. If that ever fails partway, the
    -- frame would be left shown-but-invisible and the player couldn't answer it — so it
    -- rides the same periodic recovery as the rest.
    if PlayerChoiceFrame then PlayerChoiceFrame:SetAlpha(1) end
end

-- ============================================================
-- Typed NPC interactions (PLAYER_INTERACTION_MANAGER_FRAME_SHOW / _HIDE)
-- ============================================================
-- The server names every NPC interaction it opens (Merchant, Trainer, TaxiNode, Banker, ...).
-- Blizzard's own PlayerInteractionFrameManager opens and closes those service frames off
-- exactly these two events, so the set below is as reliable as the frames themselves — and it
-- also covers service UIs the hand-kept INTERFERING_FRAMES list doesn't name (custom frames,
-- new interaction types). Gossip and quest-giver interactions are the ones we drive; the
-- choice and Torghast-powers windows belong to DelveEngine. Everything else stands us down.
local activeInteractions = {}  -- [Enum.PlayerInteractionType] = true while shown
local interactionNames = nil   -- value -> name, built lazily for messages

local function InteractionName(t)
    if not interactionNames then
        interactionNames = {}
        for name, value in pairs(Enum and Enum.PlayerInteractionType or {}) do
            interactionNames[value] = name
        end
    end
    return interactionNames[t] or tostring(t)
end

local function IsDrivenInteraction(t)
    local T = Enum and Enum.PlayerInteractionType
    if not T then return true end
    return t == T.None or t == T.Item or t == T.Gossip or t == T.QuestGiver
        or t == T.PlayerChoice or t == T.JailersTowerBuffs
end

-- Name of an open service interaction that should stand automation down, or nil.
function Services.ActiveServiceInteraction()
    for t in pairs(activeInteractions) do
        if not IsDrivenInteraction(t) then return "interaction:" .. InteractionName(t) end
    end
    return nil
end

function Services.GetActiveInteractions()
    local names = {}
    for t in pairs(activeInteractions) do names[#names + 1] = InteractionName(t) end
    table.sort(names)
    return names
end

local function OnInteractionEvent(_, event, arg1)
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local T = Enum and Enum.PlayerInteractionType
        -- A new NPC dialog means any earlier service interaction has ended (the server runs
        -- one at a time). Clearing here bounds a missed HIDE to one conversation instead of
        -- the rest of the session.
        if T and (arg1 == T.Gossip or arg1 == T.QuestGiver) then wipe(activeInteractions) end
        activeInteractions[arg1] = true
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        activeInteractions[arg1] = nil
    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(activeInteractions)
        return
    end
    -- Ordering log (debug only): one line per dialog / interaction event, timestamped, so a
    -- real turn-in shows exactly what the server sends between one window and the next.
    if JustQuest._debugMode then
        local detail = ""
        if event:find("^PLAYER_INTERACTION") then
            detail = " " .. InteractionName(arg1)
        elseif event == "GOSSIP_CLOSED" then
            detail = " continuing=" .. tostring(arg1)
        end
        Services.Debug("Interact", (event:gsub("PLAYER_INTERACTION_MANAGER_", "")) .. detail)
    end
end
Services._OnInteractionEvent = OnInteractionEvent  -- for tools/dialog_gate_check.lua

local INTERACTION_EVENTS = {
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    "PLAYER_ENTERING_WORLD",
    -- Logged only, for the ordering record:
    "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS",
    "QUEST_COMPLETE", "QUEST_FINISHED", "QUEST_TURNED_IN", "QUEST_ACCEPTED",
}

local interactionFrame
function Services.SetupInteractionListener()
    interactionFrame = interactionFrame or CreateFrame("Frame")
    for _, event in ipairs(INTERACTION_EVENTS) do
        pcall(interactionFrame.RegisterEvent, interactionFrame, event)
    end
    interactionFrame:SetScript("OnEvent", OnInteractionEvent)
end

-- Check for non-quest/gossip NPC frames (vendor, trainer, flight map, etc.)
-- Caches _G frame references to avoid repeated string→table lookups
local interferingFrameRefs = nil

function Services.HasInterferingFrame()
    if not interferingFrameRefs then
        interferingFrameRefs = {}
        for _, name in ipairs(JustQuest.Constants.INTERFERING_FRAMES or {}) do
            interferingFrameRefs[#interferingFrameRefs + 1] = { name = name, ref = _G[name] or false }
        end
    end

    local service = Services.ActiveServiceInteraction()
    if service then return service end

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
        -- QuestLabelPrepend (== 1 in GossipOptionRecFlags); use the enum, fall back
        -- to the literal only if the enum table is somehow unavailable.
        local QUEST_FLAG = (Enum and Enum.GossipOptionRecFlags and Enum.GossipOptionRecFlags.QuestLabelPrepend) or 1
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

-- Is there quest work here the addon will actually do (a turn-in, an accept, or one of ours
-- still in flight)? Delegates to QuestEngine.GetActionableQuests so routing, fast-mode hiding
-- and the gossip gates all apply the SAME filter as the engine that acts on it. A quest that
-- filter drops (blocked, trivial, type off, log full, not complete) does not count.
-- Callers may pass pre-fetched lists to avoid re-querying.
function Services.HasActionableQuestContent(active, available)
    local questEngine = JustQuest.Core.GetModule("QuestEngine")
    if not (C_GossipInfo and questEngine and questEngine.GetActionableQuests) then return false end
    local actionableActive, actionableAvailable, pending = questEngine.GetActionableQuests(active, available)
    return #actionableActive > 0 or #actionableAvailable > 0 or pending
end

-- Scoped to the open dialog: a manual conversation pauses quest/gossip handling only while it
-- is on screen, so containers, delve powers and the gear advisor carry on once it closes.
function Services.ShouldAutomate()
    return not (ModifierHeld() or Services.IsManualConversation())
end

function Services.IsAutomationEnabled()
    local config = JustQuest.Core.GetModule("Config")
    return config and
           config.Get(nil, "enabled") and
           config.Get("quest", "enabled") and
           config.Get("gossip", "enabled")
end

-- True while the player is in a vehicle, possessing/controlling an NPC, or using
-- an override/vehicle action bar (e.g. "torture the suspect" quest control states,
-- where your bar is replaced with a few special abilities). Automation must fully
-- stand down here: interacting with the controlling NPC or its gossip during the
-- board/transition desyncs the client and the server force-disconnects.
-- UnitHasVehicleUI alone misses possess and override-bar states.
function Services.InSpecialControlState()
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then return true end
    if UnitInVehicle and UnitInVehicle("player") then return true end
    if HasOverrideActionBar and HasOverrideActionBar() then return true end
    if HasVehicleActionBar and HasVehicleActionBar() then return true end
    if IsPossessBarVisible and IsPossessBarVisible() then return true end
    return false
end

-- Base validation gate — shared by all automation paths.
-- Does NOT check interfering frames (NPC-interaction specific).
function Services.CanAutomateBase()
    if UnitIsDeadOrGhost("player") then return false end
    if Services.InSpecialControlState() then return false end
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

-- Container/reward gate. Auto-open is driven by BAG_UPDATE_DELAYED, which also fires for
-- a mail attachment, a vendor purchase and a completed trade — item movement, not looting,
-- and opening a container mid-transaction is never what the player meant.
--
-- Deliberately the SAME list the rest of automation uses rather than a hand-kept subset:
-- with two lists, adding a frame to INTERFERING_FRAMES (the obvious place, and where the
-- gossip path points readers) would silently do nothing here.
function Services.CanAutomateContainers()
    if not Services.CanAutomateBase() then return false end
    return not Services.HasInterferingFrame()
end

Services.ValidateAutomationPreconditions = Services.CanAutomateContainers

-- ============================================================
-- Quest Processing Support
-- ============================================================

function Services.PollForLegacyQuestData(maxAttempts, onSuccess, onTimeout)
    maxAttempts = maxAttempts or 10  -- guard the pollAttempts >= maxAttempts compare below
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
            -- Stable key (not per-attempt) so CancelAutomationTimers() can stop a pending
            -- poll at teardown; only one is ever outstanding since each poll schedules the
            -- next after the current has fired.
            Services.ScheduleOnce("legacy_api_poll", backoff + jitter, poll)
        end
    end
    
    poll()
end

-- ============================================================
-- Unified Quest/Gossip Processing
-- ============================================================

-- Check for actionable content via ANY API (modern or legacy). The quest lists may be passed
-- in by a caller that already fetched them this tick.
-- Routed by the window that is ACTUALLY open. Both data sources can be stale: the gossip lists
-- after the gossip window has given way to a quest greeting, the greeting counts after a gossip
-- NPC. Routing on stale data sent a pass down the wrong path, where it "succeeded" at nothing
-- and ended the poll — and the real next quest was never looked at.
function Services.HasAnyActionableContent(rawActive, rawAvailable)
    if GossipFrame and GossipFrame:IsShown() then
        rawActive = rawActive or Services.SafeCall(C_GossipInfo and C_GossipInfo.GetActiveQuests)
        rawAvailable = rawAvailable or Services.SafeCall(C_GossipInfo and C_GossipInfo.GetAvailableQuests)

        if Services.HasActionableQuestContent(rawActive, rawAvailable) then return true, "modern" end

        -- Unfiltered quest check — HasActionableQuestContent may filter all quests out
        -- (recently accepted, log full, etc.) or data may still be loading.
        -- Route through QuestEngine anyway for correct priority (quests before gossip).
        if (type(rawActive) == "table" and #rawActive > 0) or
           (type(rawAvailable) == "table" and #rawAvailable > 0) then
            return true, "modern"
        end

        local opts = Services.SafeCall(C_GossipInfo and C_GossipInfo.GetOptions)
        if type(opts) == "table" and #opts > 0 then return true, "gossip" end
        return false, "none"
    end

    -- Legacy quest greeting (QuestFrame greeting panel, no gossip window).
    if QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsVisible() then
        local numActive = GetNumActiveQuests and GetNumActiveQuests() or 0
        local numAvailable = GetNumAvailableQuests and GetNumAvailableQuests() or 0
        if numActive > 0 or numAvailable > 0 then return true, "legacy" end
        return true, "greeting_visible"  -- data may still be on its way
    end

    return false, "none"
end

-- Shared routing callback — routes to correct engine based on content type
-- Deliberately NOT in Constants.TIMING: everything there is scaled by GetTiming, which
-- halves in fast mode — exactly the mode this brake exists to protect.
local FLAVOR_CLOSE_THROTTLE = 1.0

-- Returns handled, examined. "examined" is false when we bailed before looking at the
-- content at all (busy mid-step, interfering frame, automation gated off) — the poll
-- below uses it to know its content fingerprint is not a verdict on that content.
-- rawActive / rawAvailable: this tick's lists, fetched once by the poll and passed down.
local function DispatchContent(reason, rawActive, rawAvailable)
    -- Use CanAutomateBase (not CanAutomate) to avoid noisy "interfering frame" messages
    -- during background repumps (e.g. MerchantFrame opening after quest turn-in)
    if not Services.CanAutomateBase() then
        Services.Debug("Services", "DispatchContent skipped: CanAutomateBase() failed, reason=" .. (reason or ""))
        return false, false
    end
    -- Silently bail if interfering frame is open
    if Services.HasInterferingFrame() then
        Services.Debug("Services", "DispatchContent skipped: interfering frame open, reason=" .. (reason or ""))
        return false, false
    end

    local safetyEngine = JustQuest.Core.GetModule("SafetyEngine")
    if safetyEngine and safetyEngine.IsBusy() then
        Services.Debug("Services", "DispatchContent skipped: already busy ("
            .. (safetyEngine.GetState() or "?") .. "), reason=" .. (reason or ""))
        return false, false
    end

    local hasContent, contentType = Services.HasAnyActionableContent(rawActive, rawAvailable)
    if not hasContent then
        -- Fast mode: a gossip window that's still open with no options and no quests
        -- is pure flavor text. It was hidden on show, so close it instead of leaving
        -- an invisible window lingering. A held modifier bails above at
        -- CanAutomateBase, leaving the flavor visible to read.
        -- Rate-limited: closing a menu the server immediately re-sends is a close/re-open
        -- cycle that nothing else brakes — the repeat guard only covers option
        -- SELECTION, so a flavor page with no options at all has no other stopping
        -- condition. One close per second per interaction is plenty for tidying up, and
        -- caps the thrash if the server disagrees with us about the menu being over.
        local config = JustQuest.Core.GetModule("Config")

        -- Right after a turn-in / accept, an empty page is the NPC's next dialog arriving
        -- before its next quest does — the follow-up typically lands within a few seconds.
        -- Closing it as flavor (fast mode) or concluding the NPC here threw away the very
        -- window that quest was about to appear in. Hold: report "not examined" so the poll
        -- keeps looking every tick, and keep the hidden frame from being revealed meanwhile.
        local sinceProgress = GetTime() - (JustQuest._lastProgressTime or 0)
        if GossipFrame and GossipFrame:IsShown()
           and sinceProgress < (JustQuest.Constants.TIMING.RE_PUMP_TOTAL_TIME or 3.5) then
            Services.Debug("Services", string.format("Empty dialog %.1fs after a turn-in/accept - waiting for the next quest", sinceProgress))
            JustQuest._lastProcessingTime = GetTime()
            return false, false
        end

        if GossipFrame and GossipFrame:IsShown() then
            -- Either way this page is a dead end — tell GossipEngine so a re-click at
            -- this NPC shows the menu immediately instead of re-running the walk.
            local gossipEngine = JustQuest.Core.GetModule("GossipEngine")
            if gossipEngine and gossipEngine.MarkConversationConcluded then
                gossipEngine.MarkConversationConcluded()
            end
            if config and config.Get(nil, "fastMode") then
                if C_GossipInfo and C_GossipInfo.CloseGossip
                   and (GetTime() - (Services._lastFlavorClose or 0)) > FLAVOR_CLOSE_THROTTLE then
                    Services.Debug("Services", "Fast mode: auto-closing flavor gossip (no options)")
                    Services._lastFlavorClose = GetTime()
                    Services.SafeCall(C_GossipInfo.CloseGossip)
                end
            else
                -- Page stays open for reading — say why nothing is happening.
                local footer = JustQuest.Core.GetModule("GossipFooter")
                if footer then
                    footer.SetNote("Nothing to automate")
                end
            end
        end
        return false, true
    end

    local questEngine = JustQuest.Core.GetModule("QuestEngine")
    local gossipEngine = JustQuest.Core.GetModule("GossipEngine")

    -- Check gossip failed cooldown for pure gossip content (anti-loop)
    if contentType == "gossip" and gossipEngine and gossipEngine.IsInFailedCooldown then
        if gossipEngine.IsInFailedCooldown() then
            Services.Debug("Services", "Skipping gossip - in failed cooldown")
            return false, false
        end
    end

    if contentType == "legacy" or contentType == "greeting_visible" then
        if questEngine and questEngine.ProcessLegacyQuestGreeting then
            questEngine.ProcessLegacyQuestGreeting()
        end
        -- The legacy path runs its own data poll (PollForLegacyQuestData) and re-schedules
        -- itself past its re-entry cooldown, so report handled either way rather than
        -- stacking a second poll on top of it.
        return true, true
    end

    if contentType == "modern" or contentType == "gossip" then
        -- Report what the handler ACTUALLY did, not merely that we routed to it.
        -- Returning true unconditionally here was the reason a follow-up quest often
        -- needed a second click: the caller treats true as "handled, stop polling", so
        -- the first re-check after a turn-in ended the poll even when it found nothing
        -- to do — and the quest the server was still about to deliver arrived with
        -- nobody listening. Every false below is a genuine "nothing done yet, look
        -- again": still BUSY, quests filtered, or the list not yet updated.
        --
        -- Always route through QuestEngine — correct priority: complete quests >
        -- available quests > gossip delegation.
        if questEngine and questEngine.OnGossipShow then
            -- waiting: QuestEngine is holding for a quest still on its way; don't file this
            -- content as judged, or the poll would never look at it again.
            local handled, waiting = questEngine.OnGossipShow(rawActive, rawAvailable)
            return handled and true or false, not waiting
        elseif gossipEngine and gossipEngine.OnGossipShow then
            return gossipEngine.OnGossipShow(true) and true or false, true
        end
    end

    return true, true
end

-- Post-action re-checks fire on a fixed short delay, but the follow-up quest/gossip
-- they look for arrives on a server round-trip that can lag past it. DispatchContent
-- returns true as soon as it finds and routes actionable content; while it keeps
-- returning false AND an NPC interaction frame is still open, the data simply hasn't
-- landed yet — so re-check with backoff until it does or a short deadline passes.
-- This turns each single-shot re-check into a bounded poll, so a lagging accept /
-- turn-in / gossip step that unlocks a new stage isn't dropped. "Handled" means the
-- handler actually did something — a pass that looked and found nothing keeps polling,
-- because that is exactly the case where the server is still on its way.
--
-- A menu left for the player is re-checked too, and that is the case that actually runs
-- to the deadline — so it early-outs on a content fingerprint. New server data always
-- moves one of these three counts; that is the entire reason the poll exists. Without it
-- every pass re-ran the full quest-list walk and cycled BUSY->IDLE, which is both wasted
-- allocation and enough state churn to keep re-arming the automation indicator so it
-- never survived long enough to appear.
-- Quest IDENTITY and completion, not just counts: a quest whose data fills in after the menu
-- opened, or one that turns complete while it's open, keeps the count the same — and a
-- count-only print read that as "nothing new" and never looked again.
local function QuestListPrint(list)
    if type(list) ~= "table" then return "-" end
    local parts = {}
    for i, quest in ipairs(list) do
        parts[i] = tostring(quest.questID) .. (quest.isComplete and "c" or "")
    end
    return table.concat(parts, ",")
end

-- Returns the print plus the lists it read, so the tick's dispatch reuses them.
local function ContentFingerprint()
    local active    = Services.SafeCall(C_GossipInfo and C_GossipInfo.GetActiveQuests)
    local available = Services.SafeCall(C_GossipInfo and C_GossipInfo.GetAvailableQuests)
    local options   = Services.SafeCall(C_GossipInfo and C_GossipInfo.GetOptions)
    return string.format("%s|%s|%d|%d:%d|%s%s",
        QuestListPrint(active), QuestListPrint(available),
        type(options) == "table" and #options or -1,
        GetNumActiveQuests and GetNumActiveQuests() or -1,
        GetNumAvailableQuests and GetNumAvailableQuests() or -1,
        (GossipFrame and GossipFrame:IsShown()) and "G" or "",
        (QuestFrame and QuestFrame:IsShown()) and "Q" or ""), active, available
end
Services.ContentFingerprint = ContentFingerprint

-- ONE pending content pass, shared by every request (events, post-action re-checks, data
-- loads). Requests merge: the EARLIEST due time wins and the latest deadline wins. Before,
-- the last request replaced the pending one, so a lifecycle event landing just after the
-- server's GOSSIP_SHOW pushed that ready-now pass out to its own longer delay.
local DISPATCH_KEY = "content_repump"
-- A conversation hops between frames with up to a server round-trip where none is open
-- (quest frame closes, the NPC's next menu is still on its way). A poll that quits the
-- instant nothing is open misses that next menu, so it rides out a gap this long.
local FRAME_GAP = 0.5
-- After REAL progress (a turn-in or accept) the next quest is the whole point, and it can be
-- slow: an NPC that speaks before offering the follow-up, a laggy re-show. So those checks
-- watch for as long as the dialog stays open (capped), and ride out a longer frame gap. The
-- cost is one fingerprint per tick (three list reads), and an unchanged print skips the
-- dispatch, so a long watch over an idle menu does no real work.
local WATCH_REASONS = {
    safety_end_processing = true,  -- QUEST_TURNED_IN (and stall recovery)
    post_quest_accept     = true,  -- QUEST_ACCEPTED
    lifecycle             = true,  -- QUEST_FINISHED
}
local pass = nil  -- { due, deadline, gap, delay, reason, lastPrint, closedSince }

local function DispatchTick()
    local st = pass
    if not st then return end

    -- Unchanged content means the server has sent nothing new since the last look,
    -- so the handler cannot reach a different decision than it just did.
    local print_, active, available = ContentFingerprint()
    local examined = false
    if print_ ~= st.lastPrint then
        local handled
        handled, examined = DispatchContent(st.reason, active, available)
        if JustQuest._debugMode then
            Services.Debug("Dispatch", string.format("%s [%s] -> %s", st.reason, print_,
                handled and "acted" or (examined and "nothing to do" or "gated")))
        end
        -- The handler may have queued a NEW pass (e.g. after a selection); that one owns
        -- the poll now.
        if pass ~= st then return end
        if handled then pass = nil return end
    end

    local now = GetTime()
    if now >= st.deadline then pass = nil return end
    if Services.IsInteractionFrameOpen() or Services.IsDialogContinuing() then
        st.closedSince = nil
    else
        st.closedSince = st.closedSince or now
        if now - st.closedSince > st.gap then pass = nil return end
    end

    -- Only remember this fingerprint if the content was actually examined. A pass
    -- that bailed on a transient gate (still BUSY finishing the previous step, an
    -- interfering frame) never judged this content — recording it anyway made every
    -- later tick skip the dispatch as "already seen", so a quest the server delivered
    -- mid-step was never looked at again and needed a manual re-click.
    if examined then st.lastPrint = print_ end

    local maxDelay = JustQuest.Constants.TIMING.RE_PUMP_MAX_DELAY or 0.3
    local growth   = JustQuest.Constants.TIMING.RE_PUMP_GROWTH_FACTOR or 1.4
    st.delay = math.min(st.delay * growth, maxDelay)
    st.due = now + st.delay
    Services.ScheduleOnce(DISPATCH_KEY, st.delay, DispatchTick)
end

-- seedPrint: the content as it stands right now, for a check that should only act once the
-- server has sent something NEW. After a gossip selection the client still holds the old
-- menu until the reply lands; an unseeded check at 0.15s re-judged that stale menu, found
-- nothing, and concluded the NPC (and flashed the frame) before the real menu arrived.
local function RequestDispatch(delay, reason, seedPrint)
    local now = GetTime()
    local due = now + (delay or 0.1)
    local TIMING = JustQuest.Constants.TIMING
    local watch = WATCH_REASONS[reason]
    local deadline = now + (watch and (TIMING.RE_PUMP_WATCH_TIME or 15) or (TIMING.RE_PUMP_TOTAL_TIME or 1.0))
    local gap = watch and (TIMING.RE_PUMP_WATCH_GAP or 2.0) or FRAME_GAP
    local st = pass

    if st and activeTimers[DISPATCH_KEY] and st.due <= due then
        -- A pass is already coming sooner: fold this request into it.
        st.deadline = math.max(st.deadline, deadline)
        st.gap = math.max(st.gap, gap)
        st.delay = math.min(st.delay, delay or 0.1)  -- fresh activity: restart quick ticks
        st.reason = reason
        st.closedSince = nil
        -- A new event is content nobody has judged yet — unless it's a seeded post-action
        -- check, which by definition wants the current content ignored.
        if not seedPrint then st.lastPrint = nil end
        return
    end

    -- Replacing a later-due pass still inherits its window; a cancelled one (teardown) doesn't.
    local live = st and activeTimers[DISPATCH_KEY] and st or nil
    pass = { due = due, deadline = math.max(deadline, live and live.deadline or 0),
             gap = math.max(gap, live and live.gap or 0),
             delay = delay or 0.1, reason = reason, lastPrint = seedPrint }
    Services.ScheduleOnce(DISPATCH_KEY, delay or 0.1, DispatchTick)
end

-- Unified content check scheduler — every repump / trigger goes through RequestDispatch.
function Services.ScheduleContentCheck(delay, reason, seedPrint)
    RequestDispatch(delay, reason or "unspecified", seedPrint)
end

-- Legacy compatibility wrapper
function Services.PumpQuestCheck(reason, delay)
    Services.ScheduleContentCheck(delay or 0.1, reason or "pump_quest_check")
end

function Services.CoalescedGossipPass(tag, delay)
    RequestDispatch(delay or 0.1, "coalesced_" .. tostring(tag))
end

function Services.IsScheduled(key)
    return activeTimers[SanitizeKey(key)] ~= nil
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

    -- A battleground or arena is an instance, but leaving one is not "exiting an instance".
    -- You are in a raid group in a battleground, so the grouped path below would fire
    -- LeaveParty and hand you a deserter debuff; in an arena it forfeits the match for your
    -- team. Refused here rather than at the button, because every caller — the Exit button,
    -- /jq, anything later — routes through this one function.
    if instanceType == "pvp" or instanceType == "arena" then
        Services.Debug("Instance", "Refusing to leave " .. tostring(instanceType) .. " content")
        return false, "Leaving a battleground or arena is yours to do (deserter / forfeit)"
    end

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
    Services.SetupInteractionListener()
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
