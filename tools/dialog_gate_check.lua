-- Verifies the two gates every quest/dialog decision goes through, by loading the REAL
-- Services.lua and QuestEngine.lua against minimal WoW stubs:
--
--   1. The early quest filter (QuestEngine.GetActionableQuests / Services.HasActionableQuestContent).
--      A quest the addon will never act on must count as absent — when it didn't, one filtered
--      quest at an NPC stopped its vendor and dialog from ever being handled.
--   2. The manual conversation: a modifier held when a dialog opens keeps the whole
--      conversation manual until the NPC is talked to again, and only while it's on screen.
--   3. The content dispatcher that looks for the next quest after every accept / turn-in /
--      selection: the earliest pending pass wins, a post-click check ignores the stale menu
--      but not the reply, and the poll rides out the gap between one frame and the next.
--   4. The follow-up after a turn-in: an empty re-shown dialog is held open (not closed as
--      flavor, not walked off to a vendor) until the next quest lands, ~3s later.
--   5. Typed NPC interactions (PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE) stand automation
--      down for services, and a missed HIDE can't outlive the next NPC dialog.
--   6. A server-flagged continuing gossip close keeps a manual conversation manual past the gap.
--   7. Shared quests (QUEST_ACCEPT_CONFIRM + questID) go through the normal accept filter.
--   8. Story choices: only a single option with one button that grants a quest is answered.
--   9. Quest-starting bag items: bound only, filtered, once per session, never over a dialog.
--  10. Follow-up cue: only for a quest we'd take, within reach, with no dialog open.
--
-- Run from the addon root (matching the syntax checker's interpreter):
--     python -c "import lupa.lua54 as l; l.LuaRuntime().execute(open('tools/dialog_gate_check.lua', encoding='utf-8').read())"

local failures = 0
local function check(name, got, want)
    if got ~= want then
        print(string.format("FAIL %s: got %s, want %s", name, tostring(got), tostring(want)))
        failures = failures + 1
    end
end

-- ---------------------------------------------------------------- stubs
local now = 100
GetTime = function() return now end
local shift = false
IsShiftKeyDown = function() return shift end
IsControlKeyDown = function() return false end
IsAltKeyDown = function() return false end
LibStub = function() return {} end
StaticPopupDialogs = {}
Enum = { QuestFrequency = { Default = 0, Daily = 1 } }

local function MakeFrame()
    local f = { shown = false, hooks = {} }
    function f:IsShown() return self.shown end
    function f:SetAlpha() end
    function f:HookScript(script, fn) self.hooks[script] = fn end
    function f:Show() self.shown = true; if self.hooks.OnShow then self.hooks.OnShow(self) end end
    function f:Hide() self.shown = false; if self.hooks.OnHide then self.hooks.OnHide(self) end end
    return f
end
QuestFrame, GossipFrame = MakeFrame(), MakeFrame()

local settings = { acceptTrivial = false }
local modules = {
    Config = { Get = function(_, key) return settings[key] end },
    SafetyEngine = { ShouldAcceptQuest = function(questID) return questID ~= 6 end },  -- 6 = type off
}
local ns = { Database = { BLOCKED_QUESTS = {} }, Constants = { TIMING = {} } }
ns.Core = {
    RegisterModule = function(name, m) modules[name] = m end,
    GetModule = function(name) return modules[name] end,
    ModuleGetter = function(name) return function() return modules[name] end end,
}

local inLog, flaggedDone = { [3] = true }, { [5] = true, [7] = true }
C_QuestLog = {
    IsOnQuest = function(id) return inLog[id] or false end,
    IsQuestFlaggedCompleted = function(id) return flaggedDone[id] or false end,
    IsQuestIgnored = function() return false end,
}
local rawActive, rawAvailable = {}, {}
C_GossipInfo = {
    GetActiveQuests = function() return rawActive end,
    GetAvailableQuests = function() return rawAvailable end,
}

local function Load(path)
    local f = assert(io.open(path, "r"))
    local src = f:read("a"); f:close()
    assert(load(src, "@" .. path))("JustQuest", ns)
end
Load("Services/Services.lua")
Load("Engines/QuestEngine.lua")
local Services, QuestEngine = modules.Services, modules.QuestEngine
Services.SetupFastModeHooks()

-- ---------------------------------------------------------------- 1. early filter
ns.Database.BLOCKED_QUESTS[2] = true
rawActive = {
    { questID = 1, isComplete = false },  -- not complete: nothing to do
    { questID = 2, isComplete = true },   -- complete but blocked
}
rawAvailable = {
    { questID = 3 },                           -- already in log
    { questID = 4, isTrivial = true },         -- trivial, acceptTrivial off
    { questID = 5, frequency = 0 },            -- completed, not repeatable (Default freq)
    { questID = 6 },                           -- quest type turned off
}
local a, v, pending = QuestEngine.GetActionableQuests()
check("nothing actionable: active", #a, 0)
check("nothing actionable: available", #v, 0)
check("nothing actionable: not pending", pending, false)
check("filtered quests don't count as quest work", Services.HasActionableQuestContent(), false)

rawAvailable[#rawAvailable + 1] = { questID = 7, frequency = 1 }  -- completed before, but a daily
rawActive[#rawActive + 1] = { questID = 8, isComplete = true }
a, v = QuestEngine.GetActionableQuests()
check("completed daily is still offered", #v == 1 and v[1].questID, 7)
check("complete unblocked turn-in kept", #a == 1 and a[1].questID, 8)
check("actionable quest counts", Services.HasActionableQuestContent(), true)

settings.acceptTrivial = true
_, v = QuestEngine.GetActionableQuests()
check("trivial allowed when turned on", #v, 2)

-- ---------------------------------------------------------------- 2. manual conversation
check("no dialog, no modifier: automate", Services.ShouldAutomate(), true)

shift = true
GossipFrame:Show()                       -- shift-click an NPC
shift = false                            -- ...and let go
now = now + 0.3
check("manual survives the key release", Services.ShouldAutomate(), false)

GossipFrame:Hide(); now = now + 0.2; QuestFrame:Show()   -- picks a quest: gossip -> detail
check("manual carries into the quest frame", Services.ShouldAutomate(), false)

QuestFrame:Hide()
check("closed: other automation unaffected", Services.ShouldAutomate(), true)

now = now + 3; GossipFrame:Show()        -- talks to the NPC again, no modifier
check("re-interaction resumes automation", Services.ShouldAutomate(), true)
GossipFrame:Hide()

now = now + 3
Services.NoteModifierReleased()          -- shift released while the click's reply is in flight
now = now + 0.2; GossipFrame:Show()
check("modifier released just before the frame showed: manual", Services.ShouldAutomate(), false)
GossipFrame:Hide()

now = now + 0.5; GossipFrame:Show()      -- quick re-open (< gap): still the same conversation
check("re-open inside the gap stays manual", Services.ShouldAutomate(), false)
GossipFrame:Hide()

now = now + 3; shift = true
check("modifier held right now always pauses", Services.ShouldAutomate(), false)
shift = false

-- ---------------------------------------------------------------- 3. content dispatcher
-- Fake clock + timer queue standing in for AceTimer.
unpack = unpack or table.unpack
local timers = {}
Services.ScheduleTimer = function(_, fn, delay)
    local t = { at = now + delay, fn = fn }
    timers[#timers + 1] = t
    return t
end
Services.CancelTimer = function(_, t) t.cancelled = true end
local function advance(dt)
    local target = now + dt
    while true do
        local nextT
        for _, t in ipairs(timers) do
            if not (t.cancelled or t.done) and t.at <= target and (not nextT or t.at < nextT.at) then nextT = t end
        end
        if not nextT then break end
        now = math.max(now, nextT.at); nextT.done = true; nextT.fn()
    end
    now = target
end
Services.Debug = function(m, msg)  -- surface errors the timer wrapper would swallow
    if m == "Timer" then print("TIMER ERROR: " .. tostring(msg)); failures = failures + 1 end
end

UnitIsDeadOrGhost = function() return false end
settings.enabled, settings.fastMode = true, false
modules.SafetyEngine.IsBusy = function() return false end
local options = { {}, {} }
C_GossipInfo.GetOptions = function() return options end
rawActive, rawAvailable = {}, {}
local dispatches, handledResult = 0, false
QuestEngine.OnGossipShow = function() dispatches = dispatches + 1; return handledResult end

now = now + 5; GossipFrame:Show()

-- Earliest wins: the server's ready-now pass must not be pushed out by a later, slower request.
Services.CoalescedGossipPass("gossip_show", 0.05)
Services.PumpQuestCheck("lifecycle", 0.15)
advance(0.06)
check("earlier pending pass is not pushed back", dispatches, 1)
advance(20); dispatches = 0

-- Seeded post-click check: the stale menu we just answered is not re-judged...
Services.ScheduleContentCheck(0.15, "after_gossip_selection", Services.ContentFingerprint())
advance(0.5)
check("seeded check ignores unchanged content", dispatches, 0)
-- ...but the server's reply is.
options[#options + 1] = {}
advance(0.4)
check("seeded check acts on new content", dispatches, 1)
advance(20); dispatches = 0

-- An event merged into a seeded check is unjudged content: it must be looked at.
Services.ScheduleContentCheck(0.15, "after_gossip_selection", Services.ContentFingerprint())
Services.CoalescedGossipPass("gossip_show", 0.2)  -- GOSSIP_SHOW with the same counts
advance(0.3)
check("event merged into a seeded check still dispatches", dispatches, 1)
advance(20); dispatches = 0

-- Rides out the gap between the quest frame closing and the NPC's next menu.
Services.PumpQuestCheck("post_turn_in", 0.15)
advance(0.2); dispatches = 0
GossipFrame:Hide()
advance(0.3)                                     -- inside the gap, nothing open
options[#options + 1] = {}; GossipFrame:Show()   -- next menu lands, no event of ours
advance(0.4)
check("poll survives the frame transition gap", dispatches >= 1, true)
advance(20); dispatches = 0

-- ...but a conversation that really ended stops the poll.
Services.PumpQuestCheck("post_turn_in", 0.15)
advance(0.2); GossipFrame:Hide(); advance(1.0)
local before = dispatches
options[#options + 1] = {}; GossipFrame:Show(); advance(0.5)
check("poll stops once nothing has been open past the gap", dispatches, before)

-- ---------------------------------------------------------------- 4. follow-up after a turn-in
-- The reported failure: the NPC's next quest shows up within ~3s of the turn-in, after the
-- dialog has already re-opened (empty) or is still re-opening.
advance(20); dispatches = 0
local closes = 0
C_GossipInfo.CloseGossip = function() closes = closes + 1 end
settings.fastMode = true
options, rawActive, rawAvailable = {}, {}, {}

-- Turn-in: quest frame closes, NPC's dialog takes 1.5s to come back EMPTY, quest lands at ~3s.
ns._lastProgressTime = now                      -- what Core.OnQuestTurnedIn records
Services.ScheduleContentCheck(0.15, "safety_end_processing")  -- QUEST_TURNED_IN's re-check
GossipFrame:Hide(); advance(1.5)
GossipFrame:Show(); advance(1.2)                -- empty page, ~2.7s after the turn-in
check("empty dialog right after a turn-in is not closed as flavor", closes, 0)
rawAvailable = { { questID = 99 } }             -- the follow-up arrives
advance(0.4)
check("follow-up quest picked up ~3s after the turn-in", dispatches >= 1, true)
advance(20); dispatches = 0

-- Long after any progress, an empty page IS flavor and closes (fast mode).
rawAvailable = {}
Services.CoalescedGossipPass("gossip_show", 0.05)
advance(0.3)
check("empty page closes once no follow-up is expected", closes, 1)
advance(20)

-- The real QuestEngine.OnGossipShow holds gossip delegation (vendor / chatter) while the
-- follow-up may still be coming, and reports "waiting" so the poll keeps looking.
QuestEngine.OnGossipShow = nil
Load("Engines/QuestEngine.lua")   -- fresh copy of the real handler (re-registers the module)
modules.SafetyEngine.CanProcess = function() return false end
options = { {} }
ns._lastProgressTime = now - 1
local handled, waiting = modules.QuestEngine.OnGossipShow({}, {})
check("menu without a quest right after progress: held", waiting, true)
check("...and nothing taken", handled, false)
ns._lastProgressTime = now - 30
handled, waiting = modules.QuestEngine.OnGossipShow({}, {})
check("same menu long after progress: not held", waiting ~= true, true)

-- ---------------------------------------------------------------- 5. typed NPC interactions
wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end return t end
Enum.PlayerInteractionType = { None = 0, Item = 2, Gossip = 3, QuestGiver = 4, Merchant = 5,
                               TaxiNode = 6, PlayerChoice = 37, JailersTowerBuffs = 63 }
local T, fire = Enum.PlayerInteractionType, Services._OnInteractionEvent
GossipFrame:Hide(); QuestFrame:Hide()

fire(nil, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", T.Gossip)
check("gossip interaction doesn't stand us down", Services.HasInterferingFrame(), nil)
fire(nil, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", T.Merchant)
check("merchant interaction stands us down", Services.HasInterferingFrame(), "interaction:Merchant")
fire(nil, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", T.Merchant)
check("...until it hides", Services.HasInterferingFrame(), nil)
fire(nil, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", T.TaxiNode)   -- its HIDE never arrives
fire(nil, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", T.QuestGiver) -- next NPC dialog
check("a missed HIDE is bounded by the next NPC dialog", Services.HasInterferingFrame(), nil)
fire(nil, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", T.PlayerChoice)
check("choice windows belong to DelveEngine, not a blocker", Services.HasInterferingFrame(), nil)
fire(nil, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", T.Merchant)
fire(nil, "PLAYER_ENTERING_WORLD")
check("loading screen clears interactions", Services.HasInterferingFrame(), nil)

-- ---------------------------------------------------------------- 6. server-flagged continuation
now = now + 30
shift = true; GossipFrame:Show(); shift = false             -- manual conversation
now = now + 1; GossipFrame:Hide()
Services.NoteDialogContinuing()                              -- GOSSIP_CLOSED(continuing=true)
now = now + 2.5; QuestFrame:Show()                           -- quest detail, slow server (> 1s gap)
check("flagged gossip->quest hop stays manual past the gap", Services.ShouldAutomate(), false)
QuestFrame:Hide(); now = now + 3; GossipFrame:Show()         -- the flag was consumed: re-talk
check("flag is consumed by the dialog it bridged", Services.ShouldAutomate(), true)
GossipFrame:Hide()

-- ---------------------------------------------------------------- 7. shared quest accept (12.0.5 questID)
local confirmed, popupHidden = 0, 0
ConfirmAcceptQuest = function() confirmed = confirmed + 1 end
StaticPopup_Hide = function(which) if which == "QUEST_ACCEPT" then popupHidden = popupHidden + 1 end end
StaticPopup_Visible = function() return nil end
InCombatLockdown = function() return false end
now = now + 30
local QE = modules.QuestEngine
settings.acceptEscort = false
QE.OnQuestAcceptConfirm("Ally", "Escort", 42)
check("shared quests off: left for the player", confirmed, 0)
settings.acceptEscort = true
QE.OnQuestAcceptConfirm("Ally", "Blocked type", 6)
check("shared quest of a type turned off: left for the player", confirmed, 0)
QE.OnQuestAcceptConfirm("Ally", "Already have it", 3)
check("shared quest already in log: left for the player", confirmed, 0)
QE.OnQuestAcceptConfirm("Ally", "Escort", 42)
check("allowed shared quest is accepted", confirmed, 1)
check("...and the game's popup is closed", popupHidden, 1)
StaticPopup_Visible = function(which) return which == "QUEST_ACCEPT_LOG_FULL" and "StaticPopup1" or nil end
QE.OnQuestAcceptConfirm("Ally", "Escort", 43)
check("log full: not confirmed", confirmed, 1)

-- ---------------------------------------------------------------- shared stubs for 8-10
local function StubFrame()
    local f = {}
    for _, m in ipairs({ "RegisterEvent", "UnregisterEvent", "UnregisterAllEvents", "SetScript",
                         "SetAlpha", "Hide", "Show" }) do f[m] = function() end end
    f.IsShown = function() return false end
    return f
end
CreateFrame = function() return StubFrame() end
C_Timer = { After = function(d, fn) timers[#timers + 1] = { at = now + d, fn = fn } end }
IsInInstance = function() return false end
IsInGroup = function() return false end
modules.SafetyEngine.IsState = function(s) return s == "IDLE" end
modules.SafetyEngine.CanProcess = function() return true end
now = now + 30

-- ---------------------------------------------------------------- 8. story choice that grants a quest
Load("Engines/DelveEngine.lua")
local DE = modules.DelveEngine
settings.acceptQuestChoices = true
local sent, choiceInfo = {}, nil
C_PlayerChoice = {
    GetCurrentPlayerChoiceInfo = function() return choiceInfo end,
    SendPlayerChoiceResponse = function(id) sent[#sent + 1] = id end,
}
local function Offer(info) sent = {}; choiceInfo = info; DE.OnPlayerChoiceUpdate(); advance(1) end
local function OneButton(button) return { choiceID = 7, options = { { header = "Onward", buttons = { button } } } } end

Offer(OneButton({ id = 11, rewardQuestID = 42 }))
check("one option, one button that grants a quest: answered", sent[1], 11)
Offer(OneButton({ id = 11, rewardQuestID = 6 }))
check("...unless the quest is filtered (type turned off)", #sent, 0)
Offer(OneButton({ id = 11, rewardQuestID = 42, confirmation = "Are you sure?" }))
check("...or the server asks for confirmation", #sent, 0)
Offer(OneButton({ id = 11 }))
check("...or the button grants no quest", #sent, 0)
Offer({ choiceID = 7, options = { { buttons = { { id = 1, rewardQuestID = 42 }, { id = 2, rewardQuestID = 43 } } } } })
check("several quest buttons ('which path?'): left for you", #sent, 0)
IsInInstance, IsInGroup = function() return true end, function() return true end
Offer(OneButton({ id = 11, rewardQuestID = 42 }))
check("grouped in an instance: left for you", #sent, 0)
IsInInstance, IsInGroup = function() return false end, function() return false end
settings.acceptQuestChoices = false
Offer(OneButton({ id = 11, rewardQuestID = 42 }))
check("setting off: left for you", #sent, 0)
settings.acceptQuestChoices = true
choiceInfo = nil; advance(20)

-- ---------------------------------------------------------------- 9. quest-starting items in bags
ns.Constants.TIMING.CONTAINER_THROTTLE = 0.5
Load("Engines/ContainerEngine.lua")
local CE = modules.ContainerEngine
local bag, used = {}, {}
C_Container = {
    GetContainerNumSlots = function(b) return b == 0 and #bag or 0 end,
    GetContainerItemInfo = function(b, s) return b == 0 and bag[s] and bag[s].info or nil end,
    GetContainerItemQuestInfo = function(b, s) return bag[s] and bag[s].quest or { isQuestItem = false, isActive = false } end,
    UseContainerItem = function(b, s) used[#used + 1] = s end,
    GetContainerItemCooldown = function() return 0, 0 end,
}
local function Slot(itemID, questID, isBound, isActive)
    return { info = { itemID = itemID, isBound = isBound, stackCount = 1 },
             quest = { isQuestItem = true, questID = questID, isActive = isActive or false } }
end
local function Scan() used = {}; CE.OnBagUpdateDelayed(); advance(1.5) end

bag = { Slot(19228, 50, false) }                 -- tradeable (Darkmoon deck)
Scan(); check("tradeable quest starter: never used", #used, 0)
bag = { Slot(1, 51, true, true) }                -- already on that quest
Scan(); check("quest already active: not used", #used, 0)
bag = { Slot(2, 6, true) }                       -- quest type turned off
Scan(); check("filtered quest: not used", #used, 0)
bag = { Slot(3, 52, true) }
Scan(); check("bound starter for a quest we'd take: used", used[1], 1)
Scan(); check("tried once per session", #used, 0)
bag = { Slot(4, 53, true) }
GossipFrame:Show(); Scan()
check("never over an open dialog", #used, 0)
GossipFrame:Hide(); now = now + 5; Scan()
check("used once the dialog has closed", used[1], 1)
settings.startQuestItems = false
bag = { Slot(5, 54, true) }; Scan()
check("setting off: not used", #used, 0)
settings.startQuestItems = nil
advance(20)

-- ---------------------------------------------------------------- 10. follow-up cue
local cues, offers = {}, {}
UIErrorsFrame = { AddMessage = function(_, msg) cues[#cues + 1] = msg end }
GetBindingKey = function() return "F" end
GetBindingText = function(k) return k end
C_QuestLine = {
    GetAvailableQuestLines = function() return offers end,
    RequestQuestLinesForMap = function() end,
}
C_Map = {
    GetBestMapForUnit = function() return 2248 end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.5 end } end,
    GetMapWorldSize = function() return 1000, 1000 end,   -- yards
}
local QE10 = modules.QuestEngine
now = now + 10
QE10.OnQuestTurnedInSuccess(100)                 -- dialog closed after the turn-in
advance(1.5)
check("nothing offered yet: no cue", #cues, 0)
offers = { { questID = 101, questName = "The Next Step", x = 0.505, y = 0.5 } }  -- 5 yd away
advance(1)
check("follow-up appears beside you: cue", cues[1] and cues[1]:find("The Next Step") ~= nil, true)
check("...naming the Interact key", cues[1] and cues[1]:find("press F") ~= nil, true)

cues = {}; offers = { { questID = 102, questName = "Far Away", x = 0.6, y = 0.5 } }       -- 100 yd
QE10.OnQuestTurnedInSuccess(100); advance(9)
check("an offer across the zone: no cue", #cues, 0)

cues = {}; offers = { { questID = 6, questName = "Type Off", x = 0.5, y = 0.5 } }
QE10.OnQuestTurnedInSuccess(100); advance(9)
check("a quest we'd refuse: no cue", #cues, 0)

cues = {}; offers = { { questID = 103, questName = "Here", x = 0.5, y = 0.5 } }
GossipFrame:Show()
QE10.OnQuestTurnedInSuccess(100); advance(3)
check("dialog open (automation has it): no cue", #cues, 0)
GossipFrame:Hide(); advance(9)

settings.followUpCue = false; cues = {}
QE10.OnQuestTurnedInSuccess(100); advance(9)
check("setting off: no cue", #cues, 0)
settings.followUpCue = nil

if failures == 0 then
    print("dialog gate checks: all passed")
else
    print(string.format("dialog gate checks: %d FAILED", failures))
end
