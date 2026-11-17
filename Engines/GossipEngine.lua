-- GossipEngine.lua — Priority-based dialog automation with whitelist preference and safety validation

local ADDON_NAME, JustQuest = ...

local GossipEngine = {}

-- Memoized module accessors
local GetSafetyEngine = JustQuest.Core.ModuleGetter("SafetyEngine")
local GetServices     = JustQuest.Core.ModuleGetter("Services")
local GetConfig       = JustQuest.Core.ModuleGetter("Config")
local GetFooter       = JustQuest.Core.ModuleGetter("GossipFooter")

local function SetFooterNote(note)
    local footer = GetFooter()
    if footer then footer.SetNote(note) end
end

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
-- re-shows (same NPC + same option fingerprint) for this long.
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
    failedGossipFingerprint = nil,
    -- When we last auto-selected an option. Doubles as the "is this still the same
    -- conversation" signal for both the re-show and the close paths.
    lastSelectTime = 0,
    -- NPC whose conversation the walk already explored to a dead end (terminal flavor
    -- page, or a hub menu with nothing left to take). While set, the traverse stands
    -- down at this NPC — re-clicks show the menu immediately instead of re-exploring.
    -- Deliberately survives ResetLoopGuards (whose aging reset exists so services can
    -- re-fire) and clears only on target change or real quest progress. May hold a
    -- secret GUID: compare via SameNPC only, never key or concatenate.
    concludedNPC = nil,
}

-- A server-driven menu re-show or close lands within a few tenths of a second of our own
-- selection. Anything slower is a human coming back to the NPC, i.e. a NEW conversation.
--
-- Deliberately NOT in Constants.TIMING: everything there is scaled by GetTiming, which
-- halves in fast mode — and this is not a delay we choose, it classifies observed server
-- behaviour. Halving it would start misreading re-shows as new conversations.
local RESHOW_WINDOW = 2.0

-- The arithmetic behind "is this event still part of the conversation we were driving".
-- Written once because the two callers guard it DIFFERENTLY, and when both spelled the
-- subtraction inline the difference read as a copy-paste slip rather than a decision.
local function IsServerContinuation()
    return (GetTime() - (state.lastSelectTime or 0)) <= RESHOW_WINDOW
end

-- The loop guards, as one unit: chain depth, the per-option repeat history, and the
-- failed-menu fingerprint. They only bound a walk if they outlive a single menu, so
-- clear them ONLY where a conversation genuinely ends (target change) or real progress
-- happened (quest accept/turn-in resets depth via ResetChainState). See OnGossipClosed
-- for why a gossip close is not, on its own, either of those.
local function ResetLoopGuards(safetyEngine)
    state.chainDepth = 0
    state.failedGossipNPC = nil
    state.failedGossipTime = 0
    state.failedGossipFingerprint = nil
    state.lastSelectTime = 0
    -- Conversation over — a "left for manual" note must not leak onto the next menu.
    -- Cleared here rather than on every show: a repump of a still-surfaced menu
    -- early-outs on the fingerprint and would never re-set a note wiped at show time.
    SetFooterNote(nil)

    safetyEngine = safetyEngine or GetSafetyEngine()
    if safetyEngine and safetyEngine.ClearSelections then
        safetyEngine.ClearSelections()
    end
end

-- Check if we're in failed gossip cooldown for current NPC
function GossipEngine.IsInFailedCooldown(snapshot)
    if not state.failedGossipNPC then return false end

    local currentNPC = UnitGUID and UnitGUID("npc")
    if not currentNPC or not SameNPC(currentNPC, state.failedGossipNPC) then return false end

    if (GetTime() - state.failedGossipTime) >= FAILED_GOSSIP_TTL then
        return false
    end

    local fingerprint = snapshot and snapshot.optionsFingerprint
    if not fingerprint then
        local currentOptions = C_GossipInfo and C_GossipInfo.GetOptions and C_GossipInfo.GetOptions() or {}
        fingerprint = GetServices().GossipOptionsFingerprint(currentOptions)
    end
    if fingerprint ~= state.failedGossipFingerprint then
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

-- The plain speech-bubble icon (GossipGossipIcon) marks conversation: "Tell me about…",
-- "What happened here?" — options that lead to flavor text. Anything else (trainer,
-- profession, vendor, or an icon we haven't catalogued) is an NPC function behind a door.
-- An option with no icon at all is treated as conversation: the safe reading.
local CHATTER_ICONS = {
    [132053] = true,  -- GossipGossipIcon
}
local function IsChatterOption(option)
    if not option then return true end
    if option.selectOptionWhenOnlyOption then return false end
    return (not option.icon) or CHATTER_ICONS[option.icon] == true
end

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

-- Returns true for options that DO something when clicked rather than navigating
-- conversation: they grant listed rewards (option.rewards), cast/teach a spell
-- (option.spellID), or play a movie (server-set PlayMovieLabelPrepend flag — the
-- "(Movie)" label). The traverse pass must not click these: claiming a reward or
-- starting a cinematic answers a decision the player never saw. They surface for
-- manual choice instead (whitelist still overrides — that pass runs first).
local MOVIE_FLAG = (Enum and Enum.GossipOptionRecFlags and Enum.GossipOptionRecFlags.PlayMovieLabelPrepend) or 4
local function IsActionOption(option)
    if not option then return false end
    if option.spellID then return true end
    if option.rewards and #option.rewards > 0 then return true end
    if option.flags and bit and bit.band and bit.band(option.flags, MOVIE_FLAG) ~= 0 then
        return true
    end
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

    local started = services and services.ProfileStart and services.ProfileStart()
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
    if services and services.ProfileEnd then services.ProfileEnd("Gossip selection", started) end

    if not success then return false end
    if services and services.NoteStep then services.NoteStep() end

    if safetyEngine then
        safetyEngine.MarkSelection(option.gossipOptionID or option.orderIndex)
    end

    -- Seeded with the menu as it stands: the client keeps showing it until the server's reply
    -- lands, and this check must act on the reply, not re-judge the menu we just answered.
    -- The reply's own events (GOSSIP_SHOW, QUEST_DETAIL) still trigger passes of their own.
    if services and services.ScheduleContentCheck then
        local pumpDelay = services.GetTiming and services.GetTiming("QUEST_PUMP_STANDARD", 0.15) or 0.15
        services.ScheduleContentCheck(pumpDelay, "after_gossip_selection",
            services.ContentFingerprint and (services.ContentFingerprint()))
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
    -- Depth counts real steps only. A single server menu can reach HandleGossip twice —
    -- the post-selection content check fires at ~0.15s, then the server's own GOSSIP_SHOW
    -- schedules another pass — so counting entries spent the budget at 2x and halted a
    -- short walk before it reached anything useful.
    state.chainDepth = state.chainDepth + 1
    state.failedGossipNPC = nil
    state.failedGossipTime = 0
    state.failedGossipFingerprint = nil
    -- Marks a close or re-show landing shortly after this as server-driven, not the
    -- player leaving. Re-readable, unlike the consumable flag this replaced.
    state.lastSelectTime = GetTime()
    -- Automation is moving again — any "left for manual" note no longer applies.
    SetFooterNote(nil)
    return true
end

-- ============================================================
-- Core Gossip Handler
-- ============================================================

-- Entered only from OnGossipShow, which the content dispatch reaches through QuestEngine
-- (quests first). The caller owns BUSY and has already run the automate / context gates.
local function HandleGossip(snapshot)
    local services = GetServices()
    local safetyEngine = GetSafetyEngine()
    if not (services and safetyEngine) then return false end

    local function halt(reason)
        state.automationHalted = true
        services.OutputHalt(reason)
        safetyEngine.EndProcessing(reason)
        return false
    end

    if state.confirmationPending then return false end

    local currentNPC = services.SafeCall(UnitGUID, "npc")
    if not currentNPC then return false end

    -- Respect automation halt unless there is quest work we'd actually do
    if state.automationHalted then
        if not services.HasQuestGiverContent() then
            return false
        end
        state.automationHalted = false
    end

    local config = GetConfig()
    local aggressive = not config or config.Get("gossip", "aggressive") ~= false

    -- Get all options (includes unavailable/locked — needed for fingerprinting)
    local allOptions = snapshot and snapshot.options
        or services.SafeCall(C_GossipInfo and C_GossipInfo.GetOptions) or {}

    if #allOptions == 0 then
        -- Optionless page: a dead end. The common flavor path never reaches here —
        -- DispatchContent bails on "no actionable content" first, marks the
        -- conversation concluded and sets the footer note (see there). Mirror the
        -- concluded mark for this rarer direct entry (e.g. a 0-option refresh).
        state.concludedNPC = currentNPC
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

    local fingerprint = snapshot and snapshot.optionsFingerprint
        or services.GossipOptionsFingerprint(allOptions)
    if SameNPC(state.failedGossipNPC, currentNPC) and
       state.failedGossipFingerprint == fingerprint and
       (GetTime() - state.failedGossipTime) < FAILED_GOSSIP_TTL then
        safetyEngine.EndProcessing("failed_gossip_cooldown")
        return false
    end

    if #available == 0 then
        safetyEngine.EndProcessing("no_options")
        return false
    end

    -- Chain-depth accounting (anti-loop) — every auto-selection counts toward the
    -- cap (incremented in TrySelectSafeOption, so only real steps count). Reset only on
    -- real progress (NPC change, quest accept/turn-in), NOT on a time gap and NOT on a
    -- bare gossip close: a menu that re-shows after each successful select would
    -- otherwise reset the counter every cycle and walk without bound.
    local validDepth, chainReason = safetyEngine.ValidateChainDepth(state.chainDepth + 1)
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

    -- A forced menu (ForceGossip / ForceInteractionOnSingleChoice) is the server saying
    -- "show the player". With several options that is a real decision: no quest pick, no
    -- traverse. A forced menu of one is still just a doorway (single-option step below).
    local forceGossip = C_GossipInfo.ForceGossip and C_GossipInfo.ForceGossip() or false

    -- PRIORITY 2 — QUEST OPTIONS: gossip entries flagged as quest-linked (server
    -- QuestLabelPrepend flag, with a localized "(Quest)" text fallback). Safe to take
    -- at any option count; the quest itself is gated by QUEST_DETAIL safety. ForceGossip
    -- is the exception: it explicitly asks the player to make the menu choice.
    if not forceGossip then
        for _, option in ipairs(available) do
            if IsQuestOption(option)
               and TrySelectSafeOption(option, safetyEngine, services) then
                -- No repump here: SelectOption already queued the (seeded) post-selection check.
                safetyEngine.EndProcessing("quest_option_selected")
                return true
            end
        end
    end

    -- A menu holding a blacklisted option (teleport/portal/campaign-skip ship by
    -- default) is a real decision, not navigation filler. Traversing past it by taking
    -- some OTHER option answers it for the player by omission, and in fast mode the menu
    -- is hidden, so they never see the option was offered at all. Like ForceGossip, it
    -- stops the traverse and surfaces the menu.
    local hasUnsafeOption = false
    for _, option in ipairs(available) do
        if safetyEngine.IsBlacklisted(option) then
            hasUnsafeOption = true
            break
        end
    end

    -- Inside an instance, with other people in the group, a lone non-service option is
    -- routinely "we are ready" / "begin the assault" — it starts an encounter, and nothing
    -- marks those (no quest/service flag, no rewards, no keyword that covers twenty years of
    -- phrasing). Non-service exploration stands down there. GROUPED, not merely instanced:
    -- soloing legacy content is where it earns its keep, and a mistaken pull there costs
    -- only the person who walked in.
    local groupedInstance = (IsInInstance() and IsInGroup()) and true or false

    if aggressive and not forceGossip and not hasUnsafeOption then
        -- PRIORITY 3 (aggressive) — TRAVERSE, services FIRST. A vendor / trainer / flight
        -- master is what the player walked up for; probing chatter ahead of it fought the
        -- player, and since the probe usually dead-ends, the service never fired at chatty
        -- NPCs. Pass 2 is ONE conversation branch, purely to reach gossip-buried quests.
        -- Known cost: a quest buried behind chatter at an NPC that also offers a service is
        -- not auto-found (the whitelist covers those).
        -- Pass 2 is skipped when:
        --   • concluded — the conversation already walked to a dead end at this NPC;
        --   • revisited — an option we already took is showing again: this is a hub and the
        --     branch led nowhere, and sibling chatter is alternatives, not a checklist;
        --   • groupedInstance — see above.
        -- Costed/coded options never execute from here: the server intercepts them with
        -- GOSSIP_CONFIRM / GOSSIP_ENTER_CODE, which we never auto-accept. Repeat and
        -- chain-depth guards bound the walk.
        local concluded = (state.concludedNPC and SameNPC(state.concludedNPC, currentNPC)) or false
        local revisited = false
        for _, option in ipairs(available) do
            if safetyEngine.WasSelected(option.gossipOptionID or option.orderIndex) then
                revisited = true
                break
            end
        end
        for pass = 1, ((revisited or concluded or groupedInstance) and 1 or 2) do
            local wantService = (pass == 1)
            for _, option in ipairs(available) do
                if IsServiceOption(option) == wantService
                   and not IsActionOption(option)
                   and TrySelectSafeOption(option, safetyEngine, services) then
                    safetyEngine.EndProcessing("gossip_option_selected")
                    return true
                end
            end
        end
    end

    -- PRIORITY 4 (both modes, and the stand-down path for forced menus) — SINGLE-OPTION
    -- STEP. One thing to click is not a decision, it is a doorway: a service, or a trainer's
    -- "see skills" page. Blizzard's GossipFrame already clicks flagged single services on
    -- unforced menus, so what reaches here is exactly what it declined — unflagged
    -- doorways and forced single-choice menus — and refusing those made conservative mode
    -- a no-op. Two shapes qualify:
    --   • a service (selectOptionWhenOnlyOption or a service icon), even beside locked
    --     siblings and inside a grouped instance — the player walked up for it;
    --   • any other non-conversation option, when it is the ONLY option and we aren't
    --     grouped in an instance.
    -- Never conversation (speech-bubble / no icon): that opens flavor text the player came
    -- to read. Never reward/spell/movie options, never quest-flagged options (the quest pass
    -- deliberately leaves them on forced menus), never while the NPC has quest work pending
    -- (counting only quests we'd act on, so an unfinished quest doesn't block a flight
    -- master). TrySelectSafeOption still applies blacklist and repeat protection.
    if #available == 1 then
        local only = available[1]
        local npcHasQuests
        if snapshot and snapshot.hasActionableQuests ~= nil then
            npcHasQuests = snapshot.hasActionableQuests
        else
            npcHasQuests = services.HasActionableQuestContent()
        end
        local doorway = IsServiceOption(only)
            or (#allOptions == 1 and not IsChatterOption(only) and not groupedInstance)
        if doorway and not npcHasQuests
           and not IsActionOption(only) and not IsQuestOption(only)
           and TrySelectSafeOption(only, safetyEngine, services) then
            safetyEngine.EndProcessing("single_option_selected")
            return true
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

    -- Say WHY in the panel itself. Unsafe/forced menus get a note in both modes (rare,
    -- and the reason is invisible otherwise — in fast mode the frame just materializes).
    -- The action/generic notes are aggressive-only: in conservative mode every
    -- multi-option menu surfaces, and a note on all of them is noise, not signal.
    -- nil clears any earlier note instead of letting it misdescribe this menu.
    local note
    if hasUnsafeOption then
        note = "Contains a travel or commitment option"
    elseif forceGossip then
        note = "Requires a manual choice"
    elseif aggressive then
        -- Only meaningful in aggressive mode: it names the pass that DIDN'T run. In
        -- conservative mode the menu would have surfaced regardless, so saying this would
        -- credit the group gate for a hand-back it had nothing to do with.
        if groupedInstance then
            note = "Grouped in an instance — dialog left for you"
        end
        for _, option in ipairs(available) do
            if IsActionOption(option) then
                note = note or "Contains a reward or event option"
                break
            end
        end
        note = note or "Nothing safe to auto-select"
    end
    SetFooterNote(note)

    state.failedGossipNPC     = currentNPC
    state.failedGossipTime    = GetTime()
    state.failedGossipFingerprint = fingerprint
    -- The fingerprint above expires (TTL) and is wiped by the aging reset on re-show;
    -- this survives both, so a re-click gets the menu instantly instead of a re-walk.
    state.concludedNPC        = currentNPC

    safetyEngine.EndProcessing("no_safe_options")
    return false
end

-- The other dead end: the walk stepped onto a terminal flavor page (text, no options,
-- no quests). That path never reaches HandleGossip — DispatchContent bails on "no
-- actionable content" and (fast mode) closes the page — so Services reports it here.
function GossipEngine.MarkConversationConcluded()
    local services = GetServices()
    local guid = services and services.SafeCall(UnitGUID, "npc")
    if guid then
        state.concludedNPC = guid
    end
end

-- ============================================================
-- Event Handlers
-- ============================================================

-- Called by QuestEngine once it has found no quest work (it already owns BUSY), or by the
-- dispatch fallback. snapshot: this pass's options + fingerprint, never retained.
function GossipEngine.OnGossipShow(snapshot)
    local services = GetServices()
    if not services then return false end
    if not services.ShouldAutomate() then
        services.RestoreAutomationFrames()
        return false
    end
    if not services.IsAutomationContextAllowed() then return false end

    state.lastShowTime = GetTime()

    -- A new menu means any confirm dialog resolved. Accepting a confirm produces a menu
    -- re-show, not a cancel event, so nothing cleared this flag on the accept path — and
    -- every later pass bailed on it, silently killing gossip automation at that NPC.
    state.confirmationPending = false

    -- A menu opening well after our last selection is a NEW conversation, even at the
    -- same NPC — the guards must not carry over. Target change was the only reset, so
    -- re-talking to an NPC you'd already auto-selected at (a flight master whose map you
    -- closed, say) found its option still repeat-blocked, forever. That is why services
    -- "were never reached": they had been reached once, and burned.
    -- Guarded on a selection having actually happened: ResetLoopGuards zeroes the
    -- timestamp, so an unguarded check re-fires on every pass and would wipe the
    -- failed-menu fingerprint that a repump poll had just set — turning each cheap
    -- re-check into a full re-walk of the menu.
    -- The extra clause IS the difference from the close path below: with no selection yet
    -- there is nothing to age out, and resetting anyway would wipe a fingerprint the
    -- repump poll had just set.
    if (state.lastSelectTime or 0) > 0 and not IsServerContinuation() then
        ResetLoopGuards()
    end

    state.expectedGUID = services.SafeCall(UnitGUID, "npc")

    return HandleGossip(snapshot)
end

function GossipEngine.OnGossipConfirm()
    state.confirmationPending = true
    state.chainDepth = 0
end

function GossipEngine.OnGossipConfirmCancel()
    state.confirmationPending = false
end

function GossipEngine.OnGossipClosed(interactionIsContinuing)
    JustQuest._legacyGreetingPolling = nil

    -- Restore frames when gossip closes (fast mode may have hidden them)
    local services = GetServices()
    if services and services.RestoreAutomationFrames then
        services.RestoreAutomationFrames()
    end

    -- The server says the conversation goes on (gossip -> quest detail, -> a service): the next
    -- dialog is the same conversation however long it takes, for the manual-conversation
    -- boundary and the follow-up quest watch alike.
    if interactionIsContinuing and services and services.NoteDialogContinuing then
        services.NoteDialogContinuing()
    end

    -- Gossip-specific state cleanup (always safe — gossip IS closed)
    state.confirmationPending = false
    state.automationHalted = false
    state.expectedGUID = nil

    local safetyEngine = GetSafetyEngine()

    -- A close that lands right after OUR OWN auto-selection is the server tearing down
    -- one step of a conversation it is about to re-show — not the player leaving. The
    -- loop guards must survive it, or a menu that re-shows after every selection wipes
    -- its own repeat history and chain depth each cycle and walks without bound.
    --
    -- This is a TIMESTAMP, not a consumable flag, and that is the whole point: one
    -- logical close can raise GOSSIP_CLOSED more than once (fast mode closing a flavor
    -- page itself, plus the server's own close). A flag got spent by the first event, so
    -- the second read as "player left" and reset every guard at once — repeat history,
    -- failed-menu fingerprint and chain depth together — which re-armed the option just
    -- taken and spun the whole thing. A timestamp gives the same answer however many
    -- times it is asked.
    -- No "did we ever select" guard here, unlike the show path: a close with no selection
    -- behind it IS the player leaving, which is exactly when the guards should clear.
    --
    -- The event payload (interactionIsContinuing) is the server's own answer to the same
    -- question — Blizzard's GossipFrame keys its OnHide teardown off it. It extends the
    -- timestamp: a slow teardown past the window with the payload set true still keeps
    -- the guards. The payload saying false does NOT force a reset on its own — our own
    -- CloseGossip calls raise this event with false mid-walk, so on that side the
    -- timestamp remains the authority.
    if not (interactionIsContinuing or IsServerContinuation()) then
        ResetLoopGuards(safetyEngine)
    end

    -- DON'T reset state or workflow if BUSY — a quest was likely selected from
    -- gossip and quest events (QUEST_PROGRESS, QUEST_COMPLETE, QUEST_TURNED_IN)
    -- will handle state transitions. Premature reset causes race conditions:
    -- DispatchContent/repumps see IDLE and start new processing mid-turn-in.
    -- If truly stuck, SafetyEngine's periodic recovery handles it (1-4s).
    -- Terminal means the conversation is really over: not mid-step (BUSY), not a close the
    -- server flags as continuing, and not right on the heels of an automation step. A close
    -- between a turn-in and the NPC's next menu is none of those — and tearing down there
    -- cancelled the very re-check that was waiting for the follow-up quest.
    local recentStep = (GetTime() - (JustQuest._lastProcessingTime or 0)) <= RESHOW_WINDOW
    if not (safetyEngine and safetyEngine.IsBusy()) and not interactionIsContinuing and not recentStep then
        -- Terminal close: stop every pending automation timer (one set).
        if services and services.CancelAutomationTimers then
            services.CancelAutomationTimers()
        end
        local questEngine = JustQuest.Core.GetModule("QuestEngine")
        if questEngine and questEngine.ResetWorkflow then
            questEngine.ResetWorkflow()
        end
    elseif services and services.Debug then
        services.Debug("Gossip", "OnGossipClosed: not terminal (busy / continuing / recent step) - keeping pending checks")
    end
end

-- ============================================================
-- Target Change Handler (called by Core)
-- ============================================================

function GossipEngine.OnTargetChanged()
    local services = GetServices()

    -- A target change while still talking to the SAME npc is not a conversation
    -- boundary — tab-targeting, a pet taunt, or the mob you were fighting dying all
    -- fire this mid-dialog. Tearing down here cancelled the repump that carries a hub
    -- NPC from one turn-in to the next (the "stopped halfway through" stall) and wiped
    -- the repeat history under an open menu, so the next refresh re-selected an option
    -- already taken (the loop the repeat guard exists to prevent).
    if services and services.IsInteractionFrameOpen()
       and SameNPC(services.SafeCall(UnitGUID, "npc"), state.expectedGUID) then
        return
    end

    -- Restore frames on target change (fast mode may have hidden them)
    if services and services.RestoreAutomationFrames then
        services.RestoreAutomationFrames()
    end

    state.confirmationPending = false
    state.automationHalted = false
    state.expectedGUID = nil
    -- Concluded-conversation memory is per-NPC; a new target ends its scope.
    state.concludedNPC = nil

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
    state.concludedNPC = nil
end

function GossipEngine.Initialize()
end

-- Reset gossip chain state (called after quest accept to prevent stale depth)
function GossipEngine.ResetChainState()
    state.chainDepth = 0
    state.automationHalted = false
    -- Real quest progress at this NPC: it earned another look, un-conclude it.
    state.concludedNPC = nil
end

-- Why the engine did or didn't take a given option, in one short string. Exists because the
-- classification is all heuristic — there is no per-option service type in GossipOptionUIInfo
-- (see IsServiceOption) — so when a menu behaves unexpectedly the useful question is "what did
-- you think this option WAS", and guessing at that from the outside is slow. Used by /jq inspect.
function GossipEngine.ExplainOption(option)
    if not option then return "?" end
    local safetyEngine = GetSafetyEngine()
    local bits = {}
    if IsQuestOption(option) then bits[#bits + 1] = "|cff33ff33quest|r" end
    if IsServiceOption(option) then
        bits[#bits + 1] = "|cff33ccffservice|r"
            .. (option.selectOptionWhenOnlyOption and "" or " (by icon)")
    else
        bits[#bits + 1] = IsChatterOption(option) and "|cff888888chatter (flavor)|r"
            or "|cff888888chatter (doorway icon " .. tostring(option.icon) .. ")|r"
    end
    if IsActionOption(option) then bits[#bits + 1] = "|cffff9999action-skip|r" end
    if safetyEngine then
        if safetyEngine.IsWhitelisted(option) then bits[#bits + 1] = "|cff33ff33whitelisted|r" end
        if safetyEngine.IsBlacklisted(option) then bits[#bits + 1] = "|cffff6666blacklisted|r" end
        if not safetyEngine.OptionIsAvailable(option) then bits[#bits + 1] = "|cff888888unavailable|r" end
        if safetyEngine.WasSelected
           and safetyEngine.WasSelected(option.gossipOptionID or option.orderIndex) then
            bits[#bits + 1] = "|cffffcc00already-taken|r"
        end
    end
    return table.concat(bits, ", ")
end

-- The menu-level state that decides which branch runs at all. A vendor that won't fire is
-- usually explained here rather than by any single option.
function GossipEngine.ExplainMenu()
    local services = GetServices()
    local currentNPC = services and services.SafeCall(UnitGUID, "npc")
    local forced = C_GossipInfo and C_GossipInfo.ForceGossip and C_GossipInfo.ForceGossip() or false
    return {
        concluded = (state.concludedNPC and currentNPC and SameNPC(state.concludedNPC, currentNPC)) or false,
        forceGossip = forced,
        chainDepth = state.chainDepth,
        groupedInstance = (IsInInstance() and IsInGroup()) and true or false,
    }
end

function GossipEngine.GetStateInfo()
    return {
        chainDepth = state.chainDepth,
        confirmationPending = state.confirmationPending,
        automationHalted = state.automationHalted,
        lastShowTime = state.lastShowTime,
        expectedGUID = state.expectedGUID,
        lastSelectTime = state.lastSelectTime,
        -- Boolean, not the GUID itself: safe to print (the GUID may be secret).
        conversationConcluded = state.concludedNPC ~= nil,
    }
end

-- ============================================================
-- Module Registration
-- ============================================================

JustQuest.Core.RegisterModule("GossipEngine", GossipEngine, {"Services", "Config", "SafetyEngine"})

return GossipEngine
