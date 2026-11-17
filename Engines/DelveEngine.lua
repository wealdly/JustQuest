-- DelveEngine.lua — instance-content automation: take a delve power, pick a delve tier,
-- and score Torghast-style anima power choices.
--
-- Everything here is OFF by default, and every path is gated on the specific content it
-- serves — being in a delve, standing at the delve picker, or the server dressing a choice
-- in a power-choice texture kit. That gate is the whole point: player choices are
-- deliberately NOT automated anywhere else in JustQuest — a world quest reward or a
-- covenant pick is a real decision and stays yours.
--
-- Two exceptions you can opt into, for two different reasons:
--   * a DELVE POWER isn't a decision at all — one power is offered, it's always worth
--     taking, and the window is just asking for a click you were always going to make.
--   * an ANIMA POWER is a real decision, but a repetitive one with a knowable answer, so
--     it's answered from curated data (Database/AnimaPowerDB.lua) rather than guessed at.
--     When the data has nothing good to say, the choice goes back to you rather than
--     defaulting to whatever sorted first.
--   * a QUEST CHOICE (on by default, a quest setting): a story window whose only option has
--     one button that grants a quest (`rewardQuestID`) — answering it IS accepting that quest,
--     so it goes through the normal accept filter. Several buttons that each grant a quest
--     ("which path?") is a real decision and stays yours.
--
-- Runs on its own frame, independent of the quest-automation dispatcher, so delve handling
-- can't be cancelled by a modifier-key takeover of quest automation (it still honours the
-- modifier itself — see ShouldAutomate).
--
-- Safety, in keeping with the rest of the addon:
--   * a power whose button carries a confirmation is never auto-taken — same reason we never
--     auto-accept GOSSIP_CONFIRM: the server is asking, so the player should answer
--   * on the delve path, more than one option on offer means it isn't the usual power hand-out,
--     so it's handed back rather than guessed at
--   * the difficulty picker is otherwise off-limits (Constants.INTERFERING_FRAMES), so the
--     only thing that ever selects a tier is this file, with the player's say-so
--
-- Note on `requiresSelection`: it only means the window has no close button (Blizzard uses it
-- for exactly that), NOT "this is a weighty decision". Nothing branches on it — a modal window
-- is the one you most want answered for you. It is printed by the probe, and nowhere else.

local ADDON_NAME, JustQuest = ...

local DelveEngine = {}

local GetConfig   = JustQuest.Core.ModuleGetter("Config")
local GetServices = JustQuest.Core.ModuleGetter("Services")

local frame = CreateFrame("Frame")

local delveCache, delveCacheTime = false, 0
local lastChoiceID, answeredChoice
local powerFrameHidden = false
local lastTier, lastTierTime = nil, 0
local lastRerollTime = 0
-- The choice payload does not always exist when PLAYER_CHOICE_UPDATE fires. Bounded so a
-- window that never populates is abandoned rather than polled forever; reset per choice.
local infoPolls = 0
local MAX_INFO_POLLS = 6
-- Current Torghast floor, from JAILERS_TOWER_LEVEL_UPDATE (payload: level, JailersTowerType).
-- Used to discount powers that pay out per floor — see AnimaPowerDB.PER_FLOOR. 1 when unknown,
-- which makes every such power score exactly as it did before the floor was tracked.
local torghastFloor, torghastWing = 1, nil

local function Debug(msg)
    local services = GetServices()
    if services and services.Debug then services.Debug("Delve", msg) end
end

-- Automation runs quiet. What used to narrate itself in chat — every power taken, every reroll,
-- every tier picked — goes to the debug channel instead, so the detail is still there when you
-- turn debug on without a running commentary during play. Answers to a slash command still
-- print normally: you asked for those.
local function Notify(msg)
    local services = GetServices()
    if services and services.Debug then services.Debug("Delve", msg) end
end

local function Get(ns, key)
    local config = GetConfig()
    return config and config.Get(ns, key)
end

-- Master switch AND the specific toggle in question. Namespaced because this file now
-- serves two kinds of instance content ("delve" and "torghast") whose toggles are separate:
-- opting into one must never opt you into the other.
local function On(ns, key)
    local config = GetConfig()
    return config and config.Get(nil, "enabled") and config.Get(ns, key) and true or false
end

-- Modifier held / dead / vehicle: hands off, same as everywhere else.
local function MayAutomate()
    local services = GetServices()
    if services and services.ShouldAutomate and not services.ShouldAutomate() then return false end
    return true
end

-- ============================================================
-- Am I in a delve?
-- ============================================================

-- Three sources, cheapest first — none is reliable alone across load and transition, so
-- each falls through to the next. Cached for a second: this is asked on every choice event.
local function IsInDelve()
    local now = GetTime()
    if (now - delveCacheTime) < 1 then return delveCache end
    delveCacheTime = now

    if C_DelvesUI and C_DelvesUI.HasActiveDelve then
        local ok, _, _, _, mapID = pcall(UnitPosition, "player")
        if ok and mapID then
            -- Only a POSITIVE answer commits. UnitPosition's instanceID is not
            -- necessarily the uiMapID this API wants, so a mismatch returns a clean
            -- false rather than an error — letting the cheapest source veto the two
            -- more reliable ones below and silently disable the feature in a delve.
            local ok2, active = pcall(C_DelvesUI.HasActiveDelve, mapID)
            if ok2 and active then
                delveCache = true
                return true
            end
        end
    end

    if C_PartyInfo and C_PartyInfo.IsDelveInProgress then
        local ok, active = pcall(C_PartyInfo.IsDelveInProgress)
        if ok then
            delveCache = active and true or false
            return delveCache
        end
    end

    -- Last resort, reached only if BOTH delve APIs above are missing entirely.
    --
    -- It used to read "a scenario we can ask delve questions about" — but `IsDelveComplete ~= nil`
    -- tests whether the API EXISTS, which is true in Torghast, a Horrific Vision and every other
    -- scenario in the game. That made this branch mean "any scenario is a delve". Harmless in
    -- practice (the scored-kit branch claims Torghast powers before the delve path runs) but
    -- wrong, and the kind of thing that gets inherited as a real check.
    --
    -- A walk-in party is an actual state, and it is the signal Services.LeaveInstance already
    -- uses to recognise a delve — true solo as well as grouped.
    local inInstance, instanceType = IsInInstance()
    if not (inInstance and instanceType == "scenario" and C_PartyInfo and C_PartyInfo.IsPartyWalkIn) then
        delveCache = false
        return false
    end
    local okWalkIn, walkIn = pcall(C_PartyInfo.IsPartyWalkIn)
    delveCache = (okWalkIn and walkIn) and true or false
    return delveCache
end

DelveEngine.IsInDelve = IsInDelve

-- ============================================================
-- Power auto-accept (PlayerChoice)
-- ============================================================

-- Hidden by alpha, not :Hide() — the frame stays live so the server-side choice still
-- works. Services.RestoreAutomationFrames un-hides it on periodic recovery, so a failure
-- partway through can't strand you with an invisible dialog you can't answer.
local function HidePowerFrame(ns)
    -- Quest choices are hidden the way every other quest window is: in fast mode.
    local want = (ns == "quest") and Get(nil, "fastMode") or Get(ns, "hidePowerFrame")
    if not want then return end
    if PlayerChoiceFrame and PlayerChoiceFrame.SetAlpha then
        PlayerChoiceFrame:SetAlpha(0)
        powerFrameHidden = true
        -- Counts as activity, or periodic recovery (reveals after 0.75s quiet) undoes the hide.
        JustQuest._lastProcessingTime = GetTime()
    end
end

local function RestorePowerFrame()
    if not powerFrameHidden then return end
    if PlayerChoiceFrame and PlayerChoiceFrame.SetAlpha then PlayerChoiceFrame:SetAlpha(1) end
    powerFrameHidden = false
end

-- ============================================================
-- Which automation, if any, owns the choice on screen
-- ============================================================

-- PlayerChoiceInfo.uiTextureKit is the server's own label for the UI it dressed this choice
-- in, and it is never nil — so it identifies the content exactly, with no locale-dependent
-- zone-name match and no instance-type guess (every scenario reports "scenario", which is
-- why that signal can't tell Torghast from an Island Expedition).
--
-- Blizzard's own comment on the kit table calls `genericplayerchoice` "the evergreen version"
-- of the Torghast power choice, so the same scorer will serve current content. Only
-- jailerstower is wired up today, deliberately: a kit whose powers aren't in the DB would
-- score every option 0 and "pick the best" would mean picking blind, which is worse than
-- handing the choice back.
-- ponytail: one kit. Add genericplayerchoice / cypherchoice here once their powers are in
-- AnimaPowerDB — the scoring path itself needs no change.
local SCORED_KITS = {
    jailerstower = true,  -- Torghast anima power
}

local function IsScoredChoice(info)
    local kit = info and info.uiTextureKit
    return (kit and SCORED_KITS[kit]) and true or false
end

-- A story choice that only hands out a quest: one option, one live button, no confirmation,
-- nothing cast, and the button's rewardQuestID set — the server's own record of "picking this
-- gives you quest N" (PlayerChoiceResponse.RewardQuestID). Returns button, option or nil.
local function QuestChoice(info)
    local options = info and info.options
    if not (options and #options == 1) then return nil end
    local option = options[1]
    if option.spellID or option.disabledOption then return nil end
    local buttons = option.buttons
    if not (buttons and #buttons == 1) then return nil end
    local button = buttons[1]
    if not button.id or button.disabled then return nil end
    -- The server wanting a second yes is the server asking. That's the player's to give.
    if button.confirmation and button.confirmation ~= "" then return nil end
    if type(button.rewardQuestID) ~= "number" or button.rewardQuestID <= 0 then return nil end
    return button, option
end

-- May we answer it? Same accept filter as every other quest, plus the gates every automated
-- step honours. Grouped inside an instance it's left alone, as gossip exploration is there:
-- a story beat can start content for the whole group.
local function QuestChoiceAllowed(questID)
    if not On("quest", "acceptQuestChoices") then return false, "quest choices turned off" end
    if IsInInstance() and IsInGroup() then return false, "grouped in an instance" end
    local services = GetServices()
    if services and services.CanAutomateBase and not services.CanAutomateBase() then
        return false, "automation paused"
    end
    local questEngine = JustQuest.Core.GetModule("QuestEngine")
    if not (questEngine and questEngine.GetActionableQuests) then return false, "no quest engine" end
    local _, actionable = questEngine.GetActionableQuests({}, { { questID = questID } })
    if not actionable[1] then return false, "quest filtered (blocked, type off, done, or log full)" end
    return true
end

-- ============================================================
-- Scoring (Torghast-style multi-option power choices)
-- ============================================================

-- Matches the scan order the curated pattern table was written against. PENALTIES FIRST is
-- load-bearing, not stylistic: a power reading "cooldown reduced, but you deal less damage"
-- must resolve to blocked rather than to the utility score its first clause would earn.
local PATTERN_ORDER = {
    "penalties", "high_value", "movement", "phantasma", "aoe",
    "damage", "utility", "survivability", "crowdcontrol", "low_value",
}

local function AnimaDB()
    return JustQuest.Database and JustQuest.Database.AnimaPowerDB
end

-- Blizzard writes an anima power's drawback as a trailing clause: "<good>, but <bad>".
-- Detecting that construction beats keyword matching, measured against real power descriptions:
-- identical recall to the whole 27-pattern penalty block (12 of 21 known traps) with a fifth of
-- the false positives (1 vs 5 across 153 curated-good powers). The keyword patterns those five
-- came from were unbounded — "movement speed.*reduced" matched "movement speed ... cooldown is
-- reduced" and vetoed a top-scored movement power; a bare "cannot" matched "damage cannot
-- exceed". Looking only INSIDE the drawback clause is what removes that whole failure mode.
-- Lua patterns have no alternation, hence the word list rather than one expression.
local DRAWBACK_WORDS = {
    "reduc", "decreas", "lower", "less", "lose", "lost", "cannot", "no longer",
    "unable", "prevent", "suffer", "slow", "die", "kill you",
}

local function HasDrawbackClause(text)
    for _, lead in ipairs({ "but", "however" }) do
        local at = 1
        while true do
            local s, e = text:find(lead, at, true)
            if not s then break end
            -- Whole word only: "but" must not be the tail of "attribute", "distribute"...
            local before = (s > 1) and text:sub(s - 1, s - 1) or " "
            if before:find("%A") and (text:sub(e + 1, e + 1)):find("%A") then
                local clause = text:sub(e + 1, e + 160)
                for _, w in ipairs(DRAWBACK_WORDS) do
                    if clause:find(w, 1, true) then return true end
                end
            end
            at = e + 1
        end
    end
    return false
end

-- Blizzard's own quality tier, delivered in the choice payload. Not a substitute for curation —
-- an Epic movement power and an Epic damage power still rank differently — but it is a real
-- signal for the powers no curated entry covers, which measurement says is most of them: only
-- ~26% of real anima powers match any description pattern, so the rest were scoring 0 and being
-- handed straight back. Common/Uncommon sit below both mode floors (50/49) and so still hand
-- back; Rare/Epic clear them. Deliberately below every curated score: data never outranks judgment.
-- The fallback scoring tables (RARITY_SCORE / POWER_TYPE / TYPE_BONUS) live in
-- Database/AnimaPowerDB.lua, not here. They are tuning data, and a copy in this file plus a
-- copy in tools/anima_logic_check.lua drifted apart once already — the check kept passing
-- against numbers the engine no longer used. One definition, read by both.

-- Returns nil for a BLOCKED power (a trap, never take it) plus a reason, otherwise a 0-100
-- score. nil and 0 are deliberately different answers: 0 means "we don't know what this is",
-- which is recoverable by rerolling or handing back; nil means "we know, and it's harmful".
local function ScoreOption(option, mode)
    local db = AnimaDB()
    if not (db and option) then return 0 end

    local bands = db.BANDS and ((mode == "farming") and db.BANDS.FARMING or db.BANDS.NORMAL)
    if not bands then return 0 end

    local text = string.lower((option.header or option.title or "") .. " "
                              .. (option.description or option.text or ""))

    -- PENALTIES ARE CHECKED BEFORE ANY SCORE, curated or not. Harm stated in the power's own
    -- description outranks a number in our table, because the description is the server's
    -- account of what the power does and the table is our opinion about it — and if the two
    -- disagree, the table is what's wrong. It also bounds the damage from a wrong entry in that
    -- table: a mis-keyed score can cost a bad pick, never a taken trap.
    -- The description is always present in the payload (Nilable = false), so this always runs.
    -- A drawback that is PRICED IN for this mode. Checked ahead of both vetoes because the
    -- whole point is that the stated cost is known and accepted here — see DRAWBACK_ACCEPTED.
    -- Requires an explicit listing AND a curated score for this mode, so a mis-keyed entry
    -- cannot switch a trap back on by itself.
    local accepted = false
    if option.spellID and db.DRAWBACK_ACCEPTED and db.DRAWBACK_ACCEPTED[option.spellID] == mode then
        local modeScores = (mode == "farming") and db.SCORES_FARMING or db.SCORES_NORMAL
        local entry = modeScores and modeScores[option.spellID]
        if entry and entry.priority then
            accepted = true
        end
    end

    if not accepted and HasDrawbackClause(text) then
        return nil, "description states a drawback"
    end

    local penalties = (not accepted) and db.PATTERNS and db.PATTERNS.penalties
    if penalties then
        for i = 1, #penalties do
            if string.find(text, penalties[i][1]) then
                return nil, "description reads as a penalty"
            end
        end
    end

    -- spellID ONLY. The inherited code fell back to `option.id`, but a live probe shows that
    -- field is 0 on every option — it identifies nothing, and mixing it into the same key space
    -- could only ever produce a bogus [0] lookup. `spellID` is nilable; when it is absent the
    -- power is simply uncurated and falls through to the description and payload signals below.
    local spellID = option.spellID
    if spellID then
        local blocked = (not accepted) and db.BLOCKED[spellID]
        if blocked then return nil, blocked.reason or "blocked" end

        local scores = (mode == "farming") and db.SCORES_FARMING or db.SCORES_NORMAL
        local curated = scores and scores[spellID]
        if curated and curated.priority then
            -- A power that pays out per floor is worth what remains of the run, not a fixed
            -- number. JAILERS_TOWER_LEVEL_UPDATE tells us how far up we are; discount
            -- accordingly. Static scoring rated these the same on floor 1 and floor 8.
            if db.PER_FLOOR and db.PER_FLOOR[spellID] and torghastFloor > 1 then
                local decay = math.min((torghastFloor - 1) * (db.PER_FLOOR_DECAY or 3),
                                       db.PER_FLOOR_DECAY_MAX or 18)
                return math.max(1, curated.priority - decay), curated.name
            end
            return curated.priority, curated.name
        end

        -- Curated for the OTHER mode only. 59 entries are in that state, and dropping them to
        -- the rarity fallback was throwing away real judgment for a guess — that guess is what
        -- scored a known-good buff 46 and handed it back.
        --
        -- Scored AT the floor rather than at the other mode's number: a Phantasma power worth 88
        -- while farming is not worth 88 while clearing, so importing the figure would invert
        -- priorities. The floor says the honest thing — worth taking, but behind anything
        -- actually judged for this mode.
        local other = (mode == "farming") and db.SCORES_NORMAL or db.SCORES_FARMING
        local elsewhere = other and other[spellID]
        if elsewhere and elsewhere.priority then
            return bands.IGNORE_BELOW or 50, elsewhere.name
        end
    end

    -- Uncurated but identified as MOVEMENT from SpellEffect. Sits above the pattern groups
    -- because it is generated and locale-proof, where the movement patterns are four English
    -- lines — and movement is the top of the farming scale, so getting it wrong is expensive.
    -- Still below any curated score: a real judgment always wins.
    if spellID and db.MOVEMENT and db.MOVEMENT[spellID] then
        local band = bands.MOVEMENT_GOOD or 70
        return band, "movement (from spell data)"
    end

    -- Uncurated: the remaining pattern groups decide.
    for _, group in ipairs(PATTERN_ORDER) do
        if group ~= "penalties" then  -- already run, above
            local list = db.PATTERNS and db.PATTERNS[group]
            if list then
                for i = 1, #list do
                    if string.find(text, list[i][1]) then
                        local label = list[i][2]
                        if label == "BLACKLISTED" then return nil, "description reads as a penalty" end
                        return bands[label] or 0, nil
                    end
                end
            end
        end
    end

    -- Nothing recognised it. Fall back to what the server itself says about the power — its
    -- quality tier, adjusted by its type — rather than 0, which would hand back roughly three
    -- quarters of all powers. Both signals come free in the payload.
    local byRarity = option.rarity and db.RARITY_SCORE and db.RARITY_SCORE[option.rarity]
    if byRarity then
        local kind = option.typeArtID and db.POWER_TYPE and db.POWER_TYPE[option.typeArtID]
        local bonusFor = db.TYPE_BONUS and (db.TYPE_BONUS[mode] or db.TYPE_BONUS.normal) or nil
        local bonus = (kind and bonusFor and bonusFor[kind]) or 0
        return byRarity + bonus, kind
    end

    return 0, nil
end

-- Pick the highest-scoring safe option. Returns the button id to send, the chosen power's
-- spellID (the only durable identity — see SendChoiceResponse), its label and score, or nil
-- plus a count of how many options were rejected as harmful.
local function BestOption(info, mode)
    local bestScore, bestID, bestName, bestSpell, blocked = nil, nil, nil, nil, 0

    for _, option in ipairs(info.options) do
        local button = option.buttons and option.buttons[1]
        -- Same per-button rules as the single-power path: a disabled button can't be used,
        -- and one carrying a confirmation is the server asking, which stays the player's.
        if button and button.id and not button.disabled and not button.confirmation then
            local score, why = ScoreOption(option, mode)
            if score == nil then
                blocked = blocked + 1
                Debug(("blocked: %s (%s)"):format(tostring(option.header), tostring(why)))
            elseif not bestScore or score > bestScore then
                bestScore, bestID, bestName, bestSpell = score, button.id, option.header, option.spellID
            end
        end
    end

    return bestID, bestName, bestScore, blocked, bestSpell
end

-- Spend a reroll when the whole offering is beneath the floor. Uses the dedicated API rather
-- than clicking Blizzard's reroll button: driving a secure button from a non-hardware event is
-- exactly what taint blocks, and there is a supported call for this.
local function TryReroll()
    if not On("torghast", "autoReroll") then return false end
    if not (C_PlayerChoice and C_PlayerChoice.GetNumRerolls
            and C_PlayerChoice.RequestRerollPlayerChoice) then return false end

    -- The server decrements the reroll count, so this terminates on its own. The throttle
    -- only stops a duplicate PLAYER_CHOICE_UPDATE for the SAME offering from spending two.
    if (GetTime() - lastRerollTime) < 2 then return false end

    local ok, remaining = pcall(C_PlayerChoice.GetNumRerolls)
    if not ok or not remaining or remaining <= 0 then return false end

    lastRerollTime = GetTime()
    if not pcall(C_PlayerChoice.RequestRerollPlayerChoice) then return false end

    Notify(("Rerolling powers (%d left)"):format(remaining - 1))
    return true
end

-- Nothing acknowledges a player-choice response: SendPlayerChoiceResponse returns nothing, and
-- pcall succeeding only means it didn't raise. So a dropped or too-early send looked exactly
-- like success — and because `answeredChoice` was set BEFORE sending, the 0.3s retry (gated on
-- `not answeredChoice`) never fired. One silent miss was permanent, and the addon still printed
-- "Anima power: X" for a power it had not taken.
--
-- Acknowledging a send is genuinely awkward and two obvious approaches are both wrong:
--
--   * choiceID identity — it REPEATS. A probe caught 611 twice with the same two options, and
--     `maxStacks` (5/3 on those powers) means a power really can be offered again.
--   * PLAYER_CHOICE_CLOSE — in a back-to-back power sequence the window never closes, it
--     transitions straight to the next choice. Seen live: a power was gained and the next frame
--     appeared with no close event, so this reported failure for a send that had worked.
--   * button identity — `buttons[1].id` is a per-choice ordinal (1, 2 …), so "our button is
--     still offered" is true of almost any later choice. Useless as a signal.
--
-- What does hold: the POWER we chose. If the spellID we aimed at is no longer among the offered
-- options, the server moved on — whether that is our send landing or the offer advancing, there
-- is nothing left to retry at. That plus "no choice on screen" covers every observed case.
local pendingSend = nil   -- { choiceID, buttonID, spellID, label, attempts }
local SEND_RETRY_DELAY, SEND_MAX_ATTEMPTS = 0.4, 3
-- Bumped on every PLAYER_CHOICE_UPDATE. A retry only re-sends against the offering it was
-- scored on: buttonID is a per-offering slot, so after an update it may name another power.
local choiceGen = 0

-- Blizzard tears the window down CLIENT-SIDE, inside the button's click path:
--     PlayerChoiceBaseOptionButtonTemplateMixin:OnConfirm
--       -> C_PlayerChoice.SendPlayerChoiceResponse(self.buttonID)
--       -> self.parentOption:OnSelected() -> PlayerChoiceFrameMixin:OnSelectionMade()
--          -> HideUIPanel(self), unless keepOpenAfterChoice
--
-- Calling the API directly performs the FIRST STEP ONLY. That is why the power was granted and
-- the window stayed open anyway — the teardown never ran, because nothing had clicked anything.
-- So drive the real widget: these option buttons are not protected, so this is an ordinary
-- click, and it runs precisely the path a player's click runs.
local function FindOptionButton(buttonID)
    local f = PlayerChoiceFrame
    if not (f and f:IsShown()) then return nil end
    local frames = rawget(f, "optionFrames")
    if type(frames) ~= "table" then return nil end

    local match
    local function scan(node, depth)
        if match or depth > 3 then return end
        local ok, kids = pcall(function() return { node:GetChildren() } end)
        for _, kid in ipairs(ok and kids or {}) do
            if type(kid) == "table" then
                if rawget(kid, "buttonID") == buttonID and kid.Click then match = kid return end
                scan(kid, depth + 1)
            end
        end
    end

    for _, of in ipairs(frames) do
        scan(rawget(of, "OptionButtonsContainer") or of, 0)
        if match then return match end
    end
    return nil
end

-- Mirror of OnSelectionMade, for the fallback path where no widget was found and only the API
-- ran. HideUIPanel taints the secure panel system in combat, so use the same split the delve
-- path already uses.
local function CloseChoiceWindow()
    local f = PlayerChoiceFrame
    if not (f and f:IsShown()) then return end
    local cached = rawget(f, "choiceInfo")
    if type(cached) == "table" and cached.keepOpenAfterChoice then return end
    if InCombatLockdown() then f:Hide() else pcall(HideUIPanel, f) end
end

local SendChoiceResponse
SendChoiceResponse = function(choiceID, buttonID, spellID, label, kind)
    -- choiceID is used only to keep the attempt count scoped to one send chain — never as the
    -- acknowledgement, since it repeats across offerings.
    local sameChain = pendingSend and pendingSend.choiceID == choiceID
    local attempts = (sameChain and pendingSend.attempts or 0) + 1
    pendingSend = { choiceID = choiceID, buttonID = buttonID, spellID = spellID,
                    label = label, kind = kind or "Anima power", attempts = attempts }

    lastChoiceID, answeredChoice = choiceID, true
    JustQuest._lastProcessingTime = GetTime()
    local mine, gen = pendingSend, choiceGen

    -- Prefer the widget. It sends AND closes; the bare API only sends.
    local widget = FindOptionButton(buttonID)
    if widget then
        Debug(("clicking option button: choiceID=%s button=%s (%s), attempt %d"):format(
            tostring(choiceID), tostring(buttonID), tostring(label), attempts))
        if not pcall(widget.Click, widget) then
            Debug("click raised — handing the choice back")
            pendingSend = nil
            return RestorePowerFrame()
        end
    else
        Debug(("sending response: choiceID=%s button=%s (%s), attempt %d — no widget found, API only"):format(
            tostring(choiceID), tostring(buttonID), tostring(label), attempts))
        if not pcall(C_PlayerChoice.SendPlayerChoiceResponse, buttonID) then
            Debug("send raised — handing the choice back")
            pendingSend = nil
            return RestorePowerFrame()
        end
        -- Teardown lives in the click path, so it has to be done by hand here.
        CloseChoiceWindow()
    end

    C_Timer.After(SEND_RETRY_DELAY, function()
        -- Cleared by OnPlayerChoiceClose (the window shut, so the answer was taken), or
        -- replaced by a newer send whose own timer owns it now.
        if pendingSend ~= mine then return end

        local ok, cur = pcall(C_PlayerChoice.GetCurrentPlayerChoiceInfo)
        local open = ok and cur and cur.options and #cur.options > 0

        -- Is the power we picked still on the table? That is the only durable identity here.
        local stillOffered = false
        if open and pendingSend.spellID then
            for _, opt in ipairs(cur.options) do
                if opt.spellID == pendingSend.spellID then stillOffered = true break end
            end
        end

        if not open then
            Notify(("%s: %s"):format(pendingSend.kind or "Anima power", pendingSend.label or "taken"))
            pendingSend = nil
            return RestorePowerFrame()
        end

        if pendingSend.spellID and not stillOffered then
            -- The offer moved on. Either our response landed, or the next power replaced it —
            -- both mean there is nothing left to retry at.
            Notify(("%s: %s"):format(pendingSend.kind or "Anima power", pendingSend.label or "taken"))
            pendingSend = nil
            return
        end

        if choiceGen ~= gen then
            -- A new offering arrived (our power is in it again). Its own AcceptPower scores
            -- and answers it; re-sending our old slot here would pick blind.
            pendingSend = nil
            return
        end

        if pendingSend.attempts < SEND_MAX_ATTEMPTS then
            Debug(("response did not land (attempt %d, choiceID=%s button=%s, %s still offered) — retrying"):format(
                pendingSend.attempts, tostring(cur.choiceID), tostring(pendingSend.buttonID),
                tostring(pendingSend.label)))
            answeredChoice = false
            SendChoiceResponse(choiceID, pendingSend.buttonID, pendingSend.spellID, pendingSend.label, pendingSend.kind)
        else
            Debug(("response did not land after %d attempts (choiceID=%s button=%s, %s still offered) — the choice is yours"):format(
                pendingSend.attempts, tostring(cur.choiceID), tostring(pendingSend.buttonID),
                tostring(pendingSend.label)))
            pendingSend = nil
            RestorePowerFrame()
        end
    end)

    return true
end

-- ============================================================
-- Torghast entrance: the wayfinder, then the ready prompt
-- ============================================================

-- The wayfinder is a custom gossip frame, routed by texture kit (CustomGossipFrameBase registers
-- one handler per wing). Its gossip options ARE the layers.
local TORGHAST_WAYFINDER_KITS = {
    skoldushall = true, mortregar = true, coldheartinterstitia = true,
    fracturechambers = true, soulforges = true, theupperreaches = true,
    twistingcorridors = true,
}

-- The wayfinder builds its layer buttons from a frame pool during layout, so the first pass can
-- arrive before there is anything to select. Bounded so a picker that never populates is left
-- alone rather than retried forever; reset once a layer is selected and when the frame closes.
local climbAttempts = 0
local MAX_CLIMB_ATTEMPTS = 5



-- Selecting the highest layer is ONE gossip call. Blizzard's own helper cannot be used, and the
-- widget path is unnecessary:
--
--   * TorghastLevelPickerFrameMixin:ScrollAndSelectHighestAvailableLayer compares each button's
--     `index` against `highestAvailableLayerIndex`. The former is filled by Setup from
--     `optionInfo.orderIndex` (0-based); the latter is a 1-based position in gossipOptions. For
--     the top layer they can never be equal, so it selects nothing. Observed live: 16 layers,
--     `activeButtons=6 [12,15,5,14,4,13]` — orderIndexes, where 15 IS layer 16, while the helper
--     hunted for 16 and gave up.
--   * Only six layer buttons exist, recycled across pages, so "find the button for layer N" is
--     unreliable by construction.
--   * The Climb button adds nothing but a sound. Its whole OnClick is
--     `C_GossipInfo.SelectOptionByIndex(selectedPortal.optionInfo.orderIndex)`.
--
-- So: pick the highest selectable option and send its orderIndex. That IS pressing Climb, with
-- no pool, paging or selection state in between. (Unlike the anima power choice, there is no
-- client-side teardown living in the click path here — hence no widget click needed.)
local function ClimbHighestLayer()
    if not On("torghast", "autoClimb") or not MayAutomate() then return end
    local picker = _G["TorghastLevelPickerFrame"]
    if not (picker and picker:IsShown()) then return end
    if not (C_GossipInfo and C_GossipInfo.GetOptions and C_GossipInfo.SelectOptionByIndex) then return end

    local ok, options = pcall(C_GossipInfo.GetOptions)
    if not (ok and type(options) == "table" and #options > 0) then
        -- Layers arrive with the gossip payload, which can lag the frame.
        climbAttempts = climbAttempts + 1
        if climbAttempts < MAX_CLIMB_ATTEMPTS then
            local svc = GetServices()
            if svc and svc.ScheduleOnce then svc.ScheduleOnce("torghast_climb_open", 0.4, ClimbHighestLayer) end
        else
            Debug("wayfinder: no layers offered — leaving it for you")
        end
        return
    end
    climbAttempts = 0

    -- Highest SELECTABLE layer, by the same rule Blizzard uses for availability.
    local available = Enum and Enum.GossipOptionStatus and Enum.GossipOptionStatus.Available
    local complete  = Enum and Enum.GossipOptionStatus and Enum.GossipOptionStatus.AlreadyComplete
    local best
    for _, o in ipairs(options) do
        local selectable = (o.status == nil) or (o.status == available) or (o.status == complete)
        if selectable and o.orderIndex and (not best or o.orderIndex > best.orderIndex) then
            best = o
        end
    end
    if not best then
        Debug("wayfinder: no layer is selectable — leaving it for you")
        return
    end

    -- The same two preconditions the Climb button enforces (UpdatePortalButtonState). Bypassing
    -- the button means enforcing them ourselves rather than inheriting its disabled state.
    if not rawget(picker, "isPartyLeader") then
        Debug("wayfinder: not the group leader — the climb is yours to start")
        return
    end
    local okTower, inTower = pcall(C_PartyInfo and C_PartyInfo.IsPartyInJailersTower)
    if not (okTower and inTower) then
        Debug("wayfinder: group isn't gathered at the tower yet — leaving it for you")
        return
    end

    if not pcall(C_GossipInfo.SelectOptionByIndex, best.orderIndex) then
        Debug("wayfinder: sending the layer failed — yours to press")
        return
    end

    -- Pressing Climb is the ONLY thing that permits the ready prompt to be answered.
    Notify(("Torghast: layer %s"):format(tostring(best.name or (best.orderIndex + 1))))
end

-- The ready prompt is LFGDungeonReadyPopup/Dialog, whose enter button is plain XML:
--     <OnClick> PlaySound(...); AcceptProposal(); </OnClick>
--
-- IMPORTANT: that dialog is shared by ALL LFG content, so accepting it on sight would also
-- accept a dungeon or battleground pop nobody asked us to touch. The gate is CAUSAL, not
-- locational: we answer a prompt only when it follows a Climb that WE pressed, seconds earlier.
-- Being in a Torghast party is a place — you can be stood in it with a dungeon queue popping —
-- whereas having just pressed Climb is the actual reason this prompt exists.
--
-- Armed by pressing Climb, disarmed on a timer if no prompt follows, and consumed the moment one
-- is answered. One Climb answers at most one prompt. If the player pressed Climb themselves, or
-- the window lapses, nothing is armed and the prompt stays theirs.

-- Reported by /jq probe so "why didn't it fire" is visible rather than inferred.
function DelveEngine.GetEntranceState()
    return {
        autoClimb = On("torghast", "autoClimb"),
    }
end

-- NOT AUTOMATABLE — do not re-attempt. The ready prompt's enter button runs `AcceptProposal()`,
-- which is a PROTECTED function: Blizzard deliberately prevents addons from accepting a queue
-- pop. Clicking the widget from addon code produced "Interface action failed because of an
-- AddOn" and did nothing, and pcall reported success because the call was refused rather than
-- raised — the same trap as the player-choice send.
--
-- There is no supported route to this. Selecting the layer (ClimbHighestLayer above) is the last
-- step automation can take; pressing Enter on the prompt is the player's, by design.

-- ============================================================
-- Probe (diagnostic)
-- ============================================================

-- Arms a one-shot RAW dump of the next choice payload. Exists because this file has now been
-- wrong three times about what a field means at runtime — requiresSelection read as "a weighty
-- decision" when it only removes the close button, IsWaitingForPlayerChoiceResponse read as
-- "our send is in flight" when it means "a choice is open", and a send that reported success
-- without landing. Every one of those was a guess about a shape nobody had printed.
--
-- Auto-select is suppressed for the probed choice on purpose: a probe that races our own
-- selection describes a window that is already closing, which is how you get confounded data.
-- Two pieces of state, not one: OnPlayerChoiceUpdate schedules TWO passes (0.05s, then a 0.3s
-- retry). Clearing the armed flag on the first pass left the retry to select normally, so the
-- first probe dumped the window and then took the power anyway. `probedChoiceID` suppresses
-- every later pass for the same choice.
local probeArmed, probedChoiceID = false, nil

function DelveEngine.ArmProbe()
    probeArmed = true
    -- Printed, not routed to debug: this is the reply to /jq probe, and a diagnostic you
    -- invoked that answers only in the debug channel is a diagnostic that looks broken.
    print("|cff00ccffJustQuest:|r Probe armed. Open a power choice — auto-select is suppressed "
          .. "for that one, and the window is left visible so you can compare it against the dump.")
end

local function tf(v)
    if v == nil then return "|cff888888nil|r" end
    if v == true then return "|cff00ff00true|r" end
    if v == false then return "|cffff6666false|r" end
    return tostring(v)
end

-- Walk the actual frame, not the API payload. This is the half that matters when
-- GetCurrentPlayerChoiceInfo returns nothing while a window is plainly on screen: the payload
-- says "no choice", the widgets say otherwise, and only one of them can be right. Everything is
-- guarded — frame internals are Blizzard's and change without notice.
local function DumpFrame()
    local f = PlayerChoiceFrame
    if not f then print("  |cffff6666PlayerChoiceFrame does not exist|r") return end

    -- Not `ok and v or nil`: that collapses a real `false` into nil, which made disabled
    -- buttons and hidden frames read as missing APIs.
    local function g(fn, ...)
        if not fn then return nil end
        local ok, v = pcall(fn, ...)
        if not ok then return nil end
        return v
    end
    print(("  |cffffcc00frame:|r shown=%s alpha=%s kit=%s"):format(
        tf(g(f.IsShown, f)), tf(g(f.GetAlpha, f)), tostring(rawget(f, "uiTextureKit"))))

    -- GetChildren returns MANY values. Capturing it as `local ok, v = pcall(...)` keeps only
    -- the first child, which is why the first version of this walk reported "nothing found"
    -- against a window that plainly had two options on it. Pack the whole vararg.
    local function childrenOf(node)
        local ok, kids = pcall(function() return { node:GetChildren() } end)
        return ok and kids or {}
    end

    local found = 0
    local function describe(kid, label)
        local bid, oid = rawget(kid, "buttonID"), rawget(kid, "optionID")
        if bid or oid then
            found = found + 1
            print(("     |cff33ccffbutton|r buttonID=%s optionID=%s shown=%s enabled=%s text=%q"):format(
                tf(bid), tf(oid), tf(g(kid.IsShown, kid)), tf(g(kid.IsEnabled, kid)),
                tostring(g(kid.GetText, kid))))
        end
        local oi = rawget(kid, "optionInfo")
        if type(oi) == "table" then
            found = found + 1
            print(("     |cff33ff33%s|r header=%q spellID=%s rarity=%s shown=%s"):format(
                label or "option frame", tostring(rawget(oi, "header")), tf(rawget(oi, "spellID")),
                tf(rawget(oi, "rarity")), tf(g(kid.IsShown, kid))))
        end
    end

    -- Authoritative source first: Blizzard keeps the live option frames in this array
    -- (PlayerChoiceFrameMixin populates self.optionFrames as it acquires them from the pool).
    local optionFrames = rawget(f, "optionFrames")
    if type(optionFrames) == "table" and #optionFrames > 0 then
        print(("  |cffffcc00optionFrames:|r %d"):format(#optionFrames))
        for i, of in ipairs(optionFrames) do
            describe(of, "option " .. i)
            -- Buttons live in the option's OptionButtonsContainer, itself pooled.
            local container = rawget(of, "OptionButtonsContainer")
            if container then
                for _, kid in ipairs(childrenOf(container)) do
                    if type(kid) == "table" then
                        describe(kid)
                        for _, sub in ipairs(childrenOf(kid)) do
                            if type(sub) == "table" then describe(sub) end
                        end
                    end
                end
            end
        end
    end

    -- Generic sweep as a backstop, in case the structure moves.
    local function walk(node, depth)  -- not `frame`: that is this file's event frame
        if depth > 5 or found > 60 then return end
        for _, kid in ipairs(childrenOf(node)) do
            if type(kid) == "table" then
                describe(kid)
                walk(kid, depth + 1)
            end
        end
    end
    walk(f, 0)
    if found == 0 then print("  |cff888888no option frames or buttons found under PlayerChoiceFrame|r") end

    -- The Torghast toggle/reroll widget lives outside PlayerChoiceFrame.
    for _, name in ipairs({ "TorghastPlayerChoiceToggleButton", "GenericPlayerChoiceToggleButton" }) do
        local tb = _G[name]
        if tb then
            local rb = rawget(tb, "RerollButton")
            print(("  |cffffcc00%s:|r shown=%s rerollButton=%s rerollShown=%s numRerolls=%s"):format(
                name, tf(g(tb.IsShown, tb)), rb and "present" or "|cff888888absent|r",
                rb and tf(g(rb.IsShown, rb)) or "-",
                tf(g(C_PlayerChoice and C_PlayerChoice.GetNumRerolls))))
        end
    end
end

-- Exposed so the frame can be inspected on demand, without waiting for the next choice. The
-- interesting failure is a window that is up while the API reports nothing, and you cannot arm
-- for that after the fact.
DelveEngine.DumpFrame = DumpFrame

local function DumpProbe(info)
    local function call(fn) if not fn then return nil end local ok, v = pcall(fn) return ok and v or nil end
    print("|cff00ccff===== JustQuest anima probe =====|r")
    print(("  choiceID=%s  kit=|cffffd100%s|r  options=%d"):format(
        tf(info.choiceID), tostring(info.uiTextureKit), #(info.options or {})))
    print(("  requiresSelection=%s |cff888888(modal only — hides the close button)|r"):format(tf(info.requiresSelection)))
    print(("  keepOpenAfterChoice=%s   waitingForPlayer=%s |cff888888(true whenever a choice is open)|r"):format(
        tf(info.keepOpenAfterChoice), tf(call(C_PlayerChoice.IsWaitingForPlayerChoiceResponse))))
    print(("  numRerolls=%s  remainingTime=%s"):format(
        tf(call(C_PlayerChoice.GetNumRerolls)), tf(call(C_PlayerChoice.GetRemainingTime))))

    local mode = Get("torghast", "mode") or "normal"
    local db = AnimaDB()
    local bands = db and db.BANDS and ((mode == "farming") and db.BANDS.FARMING or db.BANDS.NORMAL)
    print(("  scoring mode=|cffffd100%s|r  floor=%s"):format(mode, tf(bands and bands.IGNORE_BELOW)))

    for i, opt in ipairs(info.options or {}) do
        print(("  |cffffcc00option %d|r %s"):format(i, tostring(opt.header)))
        print(("     id=%s spellID=%s rarity=%s typeArtID=%s maxStacks=%s"):format(
            tf(opt.id), tf(opt.spellID), tf(opt.rarity), tf(opt.typeArtID), tf(opt.maxStacks)))
        local score, why = ScoreOption(opt, mode)
        print(("     |cff888888our score:|r %s %s"):format(
            score == nil and "|cffff6666BLOCKED|r" or tostring(score), why and ("(" .. tostring(why) .. ")") or ""))
        local buttons = opt.buttons or {}
        print(("     buttons=%d"):format(#buttons))
        for b, btn in ipairs(buttons) do
            -- buttons[1].id is the responseID SendPlayerChoiceResponse wants (Blizzard does
            -- exactly this in PlayerChoiceBaseOptionButtonTemplateMixin:OnConfirm).
            print(("       [%d] id=%s disabled=%s confirmation=%s selected=%s text=%q"):format(
                b, tf(btn.id), tf(btn.disabled), tf(btn.confirmation), tf(btn.selected), tostring(btn.text)))
        end
        if opt.description and opt.description ~= "" then
            print(("     |cff888888desc:|r %s"):format(opt.description:sub(1, 150)))
        end
    end
    print("|cff00ccff----- frame -----|r")
    DumpFrame()
    print("|cff00ccff=================================|r")
end

local function AcceptScoredPower(info)
    local mode = Get("torghast", "mode") or "normal"
    local bands = AnimaDB() and AnimaDB().BANDS
    local floor = (bands and ((mode == "farming") and bands.FARMING or bands.NORMAL)
                   or {}).IGNORE_BELOW or 50

    local buttonID, name, score, blocked, spellID = BestOption(info, mode)

    -- Every option is a trap, or none is usable. THIS is the real decision — which harm to
    -- accept — so it goes back to the player.
    -- A reroll answers this offering: mark it, or the 0.3s second pass takes a power from
    -- the offering the server is replacing. The reroll's own update clears the mark.
    if not buttonID then
        if TryReroll() then lastChoiceID, answeredChoice = info.choiceID, true return end
        Debug(("nothing safe to take (%d blocked) — handing it back"):format(blocked))
        lastChoiceID, answeredChoice = info.choiceID, true
        return RestorePowerFrame()
    end

    -- Below the floor, but SAFE. The floor governs rerolling, not handing back: a Torghast
    -- power window has to be answered to carry on, so handing it back does not spare the
    -- player a decision, it just makes them click through the same options we already
    -- ranked. Measured, this was 23.5% of farming choices and 4.7% of clearing ones — all of
    -- them cases where nothing on offer was harmful, only unremarkable.
    --
    -- The protection that matters is the blocklist, and it is independent of this: a blocked
    -- power is never the best option because it is never an option at all.
    if score < floor then
        if TryReroll() then lastChoiceID, answeredChoice = info.choiceID, true return end
        Debug(("best %s scored %s, under the floor of %d — taking it anyway, nothing here is harmful")
              :format(tostring(name), tostring(score), floor))
    end

    return SendChoiceResponse(info.choiceID, buttonID, spellID, name, "Anima power")
end

-- The API is not the only source of the payload. Blizzard stores the choice it built the window
-- from on the frame itself (`PlayerChoiceFrameMixin`: `self.choiceInfo = choiceInfo`), and a live
-- frame walk showed complete option data — header, spellID, rarity, buttons — at a moment when
-- GetCurrentPlayerChoiceInfo described no choice at all. That combination left a real, pending
-- choice sitting unanswered on screen, because we only ever asked the API.
--
-- The frame cache is only trusted while a choice is actually awaiting an answer. Without that
-- guard it would also match the window you just answered, and we would re-send at a dead choice.
-- Returns (info, "api"|"frame") on success, or (nil, reason) where reason is one of:
--   "no-window"  nothing on screen; nothing is arriving, so don't poll
--   "stale"      a window is up but nothing awaits an answer (the choice you just took)
--   "not-ready"  a window is up, a choice IS pending, the data hasn't landed yet — poll
-- One place decides; callers just report. The three cases were previously decided here and
-- re-decided by the caller, which is how they drift apart.
local function CurrentChoiceInfo()
    local ok, info = pcall(C_PlayerChoice.GetCurrentPlayerChoiceInfo)
    if ok and info and info.options and info.options[1] then return info, "api" end

    local f = PlayerChoiceFrame
    if not (f and f:IsShown()) then return nil, "no-window" end

    if C_PlayerChoice.IsWaitingForPlayerChoiceResponse then
        local okWait, pending = pcall(C_PlayerChoice.IsWaitingForPlayerChoiceResponse)
        if okWait and not pending then return nil, "stale" end
    end

    local cached = rawget(f, "choiceInfo")
    if type(cached) == "table" and cached.options and cached.options[1] then
        return cached, "frame"
    end
    return nil, "not-ready"
end

local function AcceptPower()
    -- Guarded, not pcall'd: indexing a missing C_PlayerChoice would throw while building
    -- the pcall's own arguments, before pcall could catch anything.
    if not (C_PlayerChoice and C_PlayerChoice.GetCurrentPlayerChoiceInfo
            and C_PlayerChoice.SendPlayerChoiceResponse) then return end
    if not probeArmed and not MayAutomate() then
        Debug("modifier held / not automating — the choice is yours")
        return RestorePowerFrame()
    end

    -- Reads the API, then falls back to the payload Blizzard cached on the frame. See
    -- CurrentChoiceInfo: a populated window whose data the API would not return was leaving a
    -- real choice sitting unanswered.
    local info, source = CurrentChoiceInfo()
    if not info then
        -- Only "not-ready" is worth waiting on. PLAYER_CHOICE_UPDATE also fires while a choice
        -- is torn down after being answered, and polling that is pure waste.
        if source == "no-window" then
            Debug("no choice info and no window on screen — nothing pending")
            infoPolls = 0
            return
        end
        if source == "stale" then
            Debug("window still up but nothing awaiting an answer — stale frame, leaving it")
            infoPolls = 0
            return RestorePowerFrame()
        end

        infoPolls = infoPolls + 1
        if infoPolls <= MAX_INFO_POLLS then
            Debug(("no choice info yet (poll %d/%d)"):format(infoPolls, MAX_INFO_POLLS))
            local services = GetServices()
            if services and services.ScheduleOnce then
                JustQuest._lastProcessingTime = GetTime()  -- still working: keep the frame hidden
                services.ScheduleOnce("delve_power_poll", 0.3, AcceptPower)
            end
        else
            -- A window is up but the API will not describe it. This is precisely the case the
            -- frame walk exists for, so dump it rather than just giving up silently.
            Debug("choice info never populated — dumping the frame and leaving it for you")
            DumpFrame()
            RestorePowerFrame()
        end
        return
    end

    if not (info.options and info.options[1]) then return RestorePowerFrame() end
    if source == "frame" then
        Debug("choice read from the frame cache (the API returned nothing for it)")
    end

    -- Probe consumes the choice: dump it, leave it on screen, select nothing — and keep
    -- selecting nothing for this choice, including on the retry pass.
    if probeArmed then
        probeArmed, probedChoiceID = false, info.choiceID
        DumpProbe(info)
        return RestorePowerFrame()
    end
    if probedChoiceID and probedChoiceID == info.choiceID then
        Debug("probed choice — leaving it for you")
        return RestorePowerFrame()
    end

    if lastChoiceID == info.choiceID and answeredChoice then
        Debug("already answered choice " .. tostring(info.choiceID))
        return
    end

    -- Torghast-style power choice: several options, all of them powers, one to pick. This is
    -- the one place a multi-option choice is auto-answered, and only because every option has
    -- been scored against curated data — see AnimaPowerDB.
    if IsScoredChoice(info) then
        if not On("torghast", "autoSelectPower") then return RestorePowerFrame() end
        return AcceptScoredPower(info)
    end

    -- A choice that only grants a quest. Not allowed -> fall through: inside a delve the power
    -- path may still own it; anywhere else the gates below hand it back.
    local questButton, questOption = QuestChoice(info)
    if questButton then
        local allowed, why = QuestChoiceAllowed(questButton.rewardQuestID)
        if allowed then
            return SendChoiceResponse(info.choiceID, questButton.id, questOption.spellID,
                questOption.header or ("quest " .. questButton.rewardQuestID), "Quest choice")
        end
        Debug("quest choice not taken: " .. tostring(why))
    end

    if not On("delve", "autoAcceptPower") then return RestorePowerFrame() end
    if not IsInDelve() then return RestorePowerFrame() end

    -- NOTE: no `requiresSelection` check. It only means the window has no close button — the
    -- two things Blizzard uses it for are hiding CloseButton and refusing
    -- OnCloseUIFromExitButton — not "this is a weighty decision", which is how it was
    -- originally read. That misreading silently disabled the scored path entirely; it was
    -- quarantined here rather than fixed, which left the same wrong bail on a path where it is
    -- wrong for the same reason. A modal window is the one you MOST want answered for you.
    --
    -- A delve power is offered one at a time: one option, one button, click it. So there's
    -- nothing to choose between and nothing to filter. More than one option means it ISN'T
    -- the usual power hand-out — it's a real choice — so hand it back rather than guess.
    if #info.options > 1 then
        Debug(("%d options — a real choice, handing it back"):format(#info.options))
        lastChoiceID, answeredChoice = info.choiceID, true
        return RestorePowerFrame()
    end

    local power  = info.options[1]
    local button = power.buttons and power.buttons[1]
    if not (button and button.id) or button.disabled then
        Debug("power can't be taken (no usable button)")
        return RestorePowerFrame()
    end
    -- The server wanting a second yes is the server asking. That's the player's to give.
    if button.confirmation then
        Debug("power asks for confirmation — handing it back")
        lastChoiceID, answeredChoice = info.choiceID, true
        return RestorePowerFrame()
    end

    -- Same send as the scored path: clicks the real widget, which sends AND closes in one go
    -- (Blizzard tears the window down in the button's click path, not on the server response).
    -- This used to call the API directly and then hand-close the frame on a 0.3s timer, which
    -- is why taking a delve power felt slower than a Torghast one. It also gains the send
    -- verification the scored path already had — the API alone reports success even when the
    -- response never lands.
    return SendChoiceResponse(info.choiceID, button.id, power.spellID, power.header, "Delve power")
end

-- Which namespace, if either, is going to act on the choice now on screen. Returns nil when
-- nothing will, so a choice we aren't touching is never hidden.
local function PendingOwner()
    if C_PlayerChoice and C_PlayerChoice.GetCurrentPlayerChoiceInfo then
        local ok, info = pcall(C_PlayerChoice.GetCurrentPlayerChoiceInfo)
        if ok and info and IsScoredChoice(info) then
            return On("torghast", "autoSelectPower") and "torghast" or nil
        end
        local questButton = ok and info and QuestChoice(info)
        if questButton and QuestChoiceAllowed(questButton.rewardQuestID) then return "quest" end
    end
    -- The choice data isn't always populated this early. The delve gate doesn't need it, so
    -- it still answers; a scored kit that arrives late just isn't pre-hidden (a brief flash,
    -- not a failure — AcceptPower still handles it on the 0.05s pass).
    if On("delve", "autoAcceptPower") and IsInDelve() then return "delve" end
    return nil
end

function DelveEngine.OnPlayerChoiceUpdate()
    choiceGen = choiceGen + 1  -- before the gates: a stale retry must stand down regardless
    -- The probe deliberately bypasses both gates: diagnosing why nothing fired is most useful
    -- precisely when a toggle is off or a modifier is held, which is when it fires nothing.
    if not probeArmed then
        if not MayAutomate() then return end
        if not (On("delve", "autoAcceptPower") or On("torghast", "autoSelectPower")
                or On("quest", "acceptQuestChoices")) then return end
    end
    answeredChoice = false
    infoPolls = 0

    -- Never hide a frame we're only going to describe.
    local owner = not probeArmed and PendingOwner() or nil
    if owner then HidePowerFrame(owner) end  -- after the gates, so a choice we won't touch never flickers

    -- Immediately, then once more: the choice data isn't always populated on the first tick.
    local services = GetServices()
    if services and services.ScheduleOnce then
        services.ScheduleOnce("delve_power", 0.05, AcceptPower)
        services.ScheduleOnce("delve_power_retry", 0.3, function()
            if not answeredChoice then AcceptPower() end
        end)
    else
        AcceptPower()
    end
end

function DelveEngine.OnPlayerChoiceClose()
    RestorePowerFrame()
    answeredChoice = false
    -- The probed choice is gone; the next one is fair game again.
    probedChoiceID = nil
    -- This event IS the acknowledgement for a response we sent: the window only closes because
    -- the server took the answer (keepOpenAfterChoice is false on these). Report success here
    -- rather than at send time, so the message can never describe a power we failed to take.
    if pendingSend then
        Notify(("%s: %s"):format(pendingSend.kind or "Anima power", pendingSend.label or "taken"))
        pendingSend = nil
    end
    infoPolls = 0
    local services = GetServices()
    if services and services.CancelScheduled then
        services.CancelScheduled("delve_power")
        services.CancelScheduled("delve_power_retry")
        services.CancelScheduled("delve_power_poll")
    end
end

-- ============================================================
-- Tier selection
-- ============================================================

-- The picker's gossip options ARE the tiers, and selecting one enters the delve. So this
-- runs in two halves: preselect the tier in the UI (cosmetic, pokes Blizzard's frame the
-- way its own dropdown does), then — only if you asked for it — actually go in.
local function SelectTier(picker)
    if not On("delve", "autoTier") or not MayAutomate() then return end

    -- 12.1.0 gave this same frame a second job: it now also runs Lairs, whose tiers can put you
    -- into an LFG queue (`queueAsLFG`). A delve-tier preference is not consent to be queued for
    -- group content, so anything the game does not call a delve is left alone. Fail open — if
    -- the type can't be read, behave as before rather than silently stopping on delves.
    if C_DelvesUI and C_DelvesUI.GetTieredEntranceType and Enum and Enum.TieredEntranceType then
        local okType, entranceType = pcall(C_DelvesUI.GetTieredEntranceType)
        if okType and entranceType and entranceType ~= Enum.TieredEntranceType.Delve then
            Debug(("entrance type %s isn't a delve — leaving the picker to you"):format(tostring(entranceType)))
            return
        end
    end

    local desired = Get("delve", "preferredTier") or 1
    local services = GetServices()

    local ok, options = pcall(C_GossipInfo.GetOptions)
    if not ok or type(options) ~= "table" or #options == 0 then
        Debug("no options on the picker yet")
        return
    end
    table.sort(options, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)

    -- Match on orderIndex, not list position: a tier you can't queue for isn't listed, so
    -- options[3] is not necessarily tier 3.
    local target
    for _, option in ipairs(options) do
        if option.orderIndex == (desired - 1) then target = option break end
    end
    if not target then
        Debug(("tier %d isn't offered (%d options)"):format(desired, #options))
        return
    end

    if target.status and Enum and Enum.GossipOptionStatus then
        local available = target.status == Enum.GossipOptionStatus.Available
                       or target.status == Enum.GossipOptionStatus.AlreadyComplete
        if not available then
            Debug(("tier %d isn't available right now"):format(desired))
            return
        end
    end

    -- Don't re-pick the same tier on every picker refresh.
    local now = GetTime()
    local repeated = (lastTier == desired) and (now - lastTierTime) < 5
    lastTier, lastTierTime = desired, now

    if not repeated then
        -- Mirrors what the picker's own dropdown does on selection. All of it is Blizzard
        -- internals, so it's wrapped whole: if a patch moves any of it, the preselect
        -- quietly does nothing rather than erroring.
        local call = (services and services.SafeCall) or function(f, ...) return pcall(f, ...) end
        call(function()
            if picker.DelveRewardsContainerFrame then picker.DelveRewardsContainerFrame:Hide() end
            if picker.SetSelectedLevel then picker:SetSelectedLevel(target.orderIndex) end
            if picker.SetSelectedOption then picker:SetSelectedOption(target) end
            if picker.Dropdown and picker.Dropdown.Update then picker.Dropdown:Update() end
            if picker.UpdateWidgets and target.gossipOptionID then picker:UpdateWidgets(target.gossipOptionID) end
            if picker.DelveRewardsContainerFrame and picker.DelveRewardsContainerFrame.SetRewards then
                picker.DelveRewardsContainerFrame:SetRewards()
            end
            if picker.UpdatePortalButtonState then picker:UpdatePortalButtonState() end
            pcall(SetCVar, "lastSelectedDelvesTier", target.orderIndex + 1)
        end)
        Notify(("Delve: selected %s"):format(target.name or ("tier " .. desired)))
    end

    if not On("delve", "autoEnter") then return end
    if services and services.ScheduleOnce then
        services.ScheduleOnce("delve_enter", 0.2, function()
            Debug("entering delve at tier " .. desired)
            local enterOK = pcall(C_GossipInfo.SelectOptionByIndex, target.orderIndex)
            if not enterOK then Debug("enter failed — the picker is still yours") end
        end)
    end
end

-- ============================================================
-- Events (own frame — independent of the quest-automation gate)
-- ============================================================

frame:RegisterEvent("PLAYER_CHOICE_UPDATE")
frame:RegisterEvent("PLAYER_CHOICE_CLOSE")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("GOSSIP_CLOSED")
frame:RegisterEvent("JAILERS_TOWER_LEVEL_UPDATE")
frame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "JAILERS_TOWER_LEVEL_UPDATE" then
        torghastFloor, torghastWing = arg1 or 1, arg2
        Debug(("Torghast floor %s (wing type %s)"):format(tostring(torghastFloor), tostring(torghastWing)))

    elseif event == "PLAYER_CHOICE_UPDATE" then
        DelveEngine.OnPlayerChoiceUpdate()

    elseif event == "PLAYER_CHOICE_CLOSE" then
        DelveEngine.OnPlayerChoiceClose()

    elseif event == "GOSSIP_SHOW" then
        -- arg1 is the texture kit: the only reliable way to tell a special picker from an
        -- ordinary NPC. The Torghast wayfinder is one kit per wing.
        if TORGHAST_WAYFINDER_KITS[arg1 or ""] then
            local services = GetServices()
            if services and services.ScheduleOnce then
                -- The picker is demand-loaded and populates its layers after the event.
                services.ScheduleOnce("torghast_climb_open", 0.3, ClimbHighestLayer)
            else
                ClimbHighestLayer()
            end
            return
        end

        if arg1 ~= "delves-difficulty-picker" then return end
        if not On("delve", "autoTier") then return end
        local picker = _G["DelvesDifficultyPickerFrame"]
        if not picker then return end
        local services = GetServices()
        if services and services.ScheduleOnce then
            services.ScheduleOnce("delve_tier", 0.2, function()
                if picker:IsVisible() then SelectTier(picker) end
            end)
        end

    elseif event == "GOSSIP_CLOSED" then
        local services = GetServices()
        climbAttempts = 0  -- a new wayfinder session starts fresh
        if services and services.CancelScheduled then
            services.CancelScheduled("delve_tier")
            services.CancelScheduled("delve_enter")
            services.CancelScheduled("torghast_climb_open")
            services.CancelScheduled("torghast_climb")
        end
    end
end)

function DelveEngine.Initialize()
    -- Frame + events wired at load; every handler re-checks its own toggle.
end

-- Disabling cancels every timer, including periodic recovery — so a choice hidden right now
-- would stay invisible. Hand it back.
function DelveEngine.OnDisable()
    pendingSend = nil
    RestorePowerFrame()
end

JustQuest.Core.RegisterModule("DelveEngine", DelveEngine, {"Config", "Services"})

return DelveEngine
