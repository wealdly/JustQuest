-- Run in Lua 5.1: loadfile(thisFile)(justQuestRoot).
local root = ...
assert(root, "Pass the JustQuest addon root")

local function Context()
    local c = {
        now = 100, id = 100, blocked = {}, active = {}, available = {}, options = {},
        timers = {}, logs = {}, calls = { complete = 0, reward = 0, accept = 0, confirm = 0, select = {} },
        panel = true, completable = true, enabled = true, automate = true,
        whitelist = {}, modules = {}, full = false, force = false,
    }
    local e = setmetatable({}, { __index = _G })
    e._G, c.env = e, e
    e.wipe = function(t) for key in pairs(t) do t[key] = nil end return t end
    e.GetTime = function() return c.now end
    e.StaticPopupDialogs = {}
    e.StaticPopup_Show = function(_, _, _, data) c.popup = data return {} end
    e.GetQuestID = function() return c.id end
    e.GetTitleText = function() return "Test quest" end
    e.IsQuestCompletable = function() return c.completable end
    e.QuestFrameProgressPanel = { IsShown = function() return c.panel end }
    e.GossipFrame = { IsShown = function() return true end }
    e.QuestFrame = { IsShown = function() return false end }
    e.UnitIsDeadOrGhost = function() return c.dead == true end
    e.UnitGUID = function() return "npc-1" end
    e.IsInInstance = function() return false end
    e.IsInGroup = function() return false end
    e.InCombatLockdown = function() return false end
    e.GetNumQuestItems = function() return 0 end
    e.GetNumQuestCurrencies = function() return c.currencies or 0 end
    e.GetNumQuestChoices = function() return 0 end
    e.GetNumQuestRewards = function() return 0 end
    e.CompleteQuest = function() c.calls.complete = c.calls.complete + 1 end
    e.AcceptQuest = function() c.calls.accept = c.calls.accept + 1 end
    e.ConfirmAcceptQuest = function() c.calls.confirm = c.calls.confirm + 1 end
    e.StaticPopup_Hide = function() end
    e.GetQuestReward = function() c.calls.reward = c.calls.reward + 1 end
    e.GetNumActiveQuests = function() return #c.active end
    e.GetNumAvailableQuests = function() return #c.available end
    e.GetActiveTitle = function(i) return c.active[i].title, c.active[i].isComplete end
    e.GetActiveQuestID = function(i) return c.active[i].questID end
    e.GetAvailableTitle = function(i) return c.available[i].title end
    e.GetAvailableQuestInfo = function(i)
        local q = c.available[i]
        return q.isTrivial, q.frequency or 0, q.repeatable, false, q.questID
    end
    e.SelectActiveQuest = function(i) table.insert(c.calls.select, c.active[i].questID) end
    e.SelectAvailableQuest = function(i) table.insert(c.calls.select, c.available[i].questID) end
    e.ERR_QUEST_LOG_FULL = "Quest log full"
    e.CreateFrame = function()
        local frame = {}
        function frame:RegisterEvent() end
        function frame:SetScript(_, handler) c.errorHandler = handler end
        return frame
    end
    e.C_QuestLog = {
        IsOnQuest = function() return false end,
        IsQuestFlaggedCompleted = function() return false end,
        IsRepeatableQuest = function() return true end,
    }
    e.C_GossipInfo = {
        GetActiveQuests = function() return c.active end,
        GetAvailableQuests = function() return c.available end,
        GetOptions = function() return c.options end,
        ForceGossip = function() return c.force end,
        SelectOption = function(id) table.insert(c.calls.select, id) end,
    }
    e.Enum = {
        QuestFrequency = { Default = 0, Daily = 1 },
        GossipOptionStatus = { Available = 0, Unavailable = 1, AlreadyComplete = 2 },
    }
    e.LibStub = function()
        return {
            ScheduleTimer = function(_, fn, delay)
                local timer = { fn = fn, due = c.now + delay }
                c.timers[#c.timers + 1] = timer
                return timer
            end,
            CancelTimer = function(_, timer) timer.cancelled = true end,
            ScheduleRepeatingTimer = function() return {} end,
        }
    end
    local ns = { Core = {}, _stats = {} }
    ns.Core.GetModule = function(name) return c.modules[name] end
    ns.Core.ModuleGetter = function(name) return function() return c.modules[name] end end
    ns.Core.RegisterModule = function(name, mod) c.modules[name] = mod end
    local function Load(path)
        local chunk = assert(loadfile(root .. "\\" .. path))
        setfenv(chunk, e)
        return chunk("JustQuest", ns)
    end
    Load("Core\\Constants.lua")
    c.config = ns.Constants.DEFAULTS.profile
    c.modules.Config = {
        Get = function(group, key)
            if group then return c.config[group][key] end
            return c.config[key]
        end,
        GetCurrencyQuestWhitelist = function() return c.whitelist end,
        AddCurrencyQuestWhitelist = function(id) c.whitelist[id] = true end,
    }
    c.modules.GameData = { GetQuestType = function() return "normal" end }
    c.services = Load("Services\\Services.lua")
    c.services.Debug = function(_, text) table.insert(c.logs, text) end
    c.services.OutputHalt = function() end
    c.services.IsQuestBlocked = function(id) return c.blocked[id] == true end
    c.services.ShouldAutomate = function() return c.automate end
    c.services.IsAutomationEnabled = function() return c.enabled end
    c.services.InSpecialControlState = function() return c.control == true end
    c.services.HasInterferingFrame = function() return c.interference end
    c.services.CanAutomateBase = function() return c.enabled and c.automate and not c.dead end
    c.services.CanAutomate = c.services.CanAutomateBase
    c.services.IsAutomationContextAllowed = function() return true end
    c.services.IsInteractionFrameOpen = function() return true end
    c.services.RestoreAutomationFrames = function() c.restored = true end
    c.safety = Load("Engines\\SafetyEngine.lua")
    c.safety.Initialize()
    c.modules.RewardEngine = {
        ProcessQuestReward = function() c.calls.reward = c.calls.reward + 1 end,
    }
    c.quest = Load("Engines\\QuestEngine.lua")
    c.gossip = Load("Engines\\GossipEngine.lua")
    function c:Advance(seconds)
        self.now = self.now + seconds
        local pending = self.timers
        self.timers = {}
        for _, timer in ipairs(pending) do
            if not timer.cancelled then
                if timer.due <= self.now then timer.fn()
                else self.timers[#self.timers + 1] = timer end
            end
        end
    end
    function c:Prompt()
        self.currencies = 1
        self.quest.OnQuestProgress()
        assert(self.popup, "currency prompt must be shown")
    end
    return c
end

local count = 0
local function Test(name, fn)
    local ok, err = pcall(fn)
    assert(ok, name .. ": " .. tostring(err))
    count = count + 1
    print("PASS " .. name)
end
local function Equal(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end
local function Offer(id, trivial)
    return { questID = id, title = "Quest " .. id, isComplete = true, isTrivial = trivial }
end

Test("blocked direct progress and reward panels do not complete", function()
    local c = Context()
    c.blocked[c.id] = true
    c.quest.OnQuestProgress()
    c.quest.OnQuestComplete()
    Equal(c.calls.complete, 0)
    Equal(c.calls.reward, 0)
    Equal(c.safety.IsBusy(), false)
    Equal(c.restored, true)
end)
Test("allowed direct progress and reward panels still automate", function()
    local c = Context()
    c.quest.OnQuestProgress()
    c.quest.OnQuestComplete()
    Equal(c.calls.complete, 1)
    Equal(c.calls.reward, 1)
end)
Test("turn-in policy remains independent of accept-repeatable policy", function()
    local c = Context()
    c.config.quest.acceptRepeatable = false
    c.modules.GameData.GetQuestType = function() return "daily" end
    Equal(c.safety.ShouldAcceptQuest(c.id), false)
    c.quest.OnQuestProgress()
    Equal(c.calls.complete, 1)
end)
local function RequiredItem(c, classID, bindType)
    c.env.GetNumQuestItems = function() return 1 end
    c.env.GetQuestItemLink = function() return "item:123" end
    c.env.C_Item = {
        GetItemInfoInstant = function() return 123, "", "", "", 0, classID end,
        GetItemInfo = function()
            return "Required item", "item:123", 1, 1, 0, "", "", 1, "", 0, 0, classID, 0, bindType
        end,
    }
end
Test("quest-class turn-in needs no cached item metadata", function()
    local c = Context()
    RequiredItem(c, 12)
    c.env.C_Item.GetItemInfo = function() error("quest class is sufficient") end
    c.quest.OnQuestProgress()
    Equal(c.calls.complete, 1)
end)
for _, classID in ipairs({ 7, 15 }) do
    Test("quest-bound turn-in is accepted outside the quest item class " .. classID, function()
        local c = Context()
        RequiredItem(c, classID, 4)
        c.quest.OnQuestProgress()
        Equal(c.calls.complete, 1)
    end)
end
for _, item in ipairs({ { 7, 0 }, { 7, 1 }, { 4, 1 }, { 4, 2 } }) do
    Test("ordinary turn-in item still needs approval " .. item[1] .. ":" .. item[2], function()
        local c = Context()
        RequiredItem(c, item[1], item[2])
        c.currencies = 1
        c.quest.OnQuestProgress()
        Equal(c.calls.complete, 0)
        Equal(c.popup, nil)
        Equal(c.safety.GetReason(), "quest_requires_trade_items")
    end)
end
Test("missing turn-in metadata is retried when quest item data arrives", function()
    local c = Context()
    RequiredItem(c, 15, 4)
    local getItemInfo = c.env.C_Item.GetItemInfo
    c.env.C_Item.GetItemInfo = function() return nil end
    c.quest.OnQuestProgress()
    Equal(c.calls.complete, 0)
    Equal(c.safety.GetReason(), "quest_requires_uncached_items")
    c.env.C_Item.GetItemInfo = getItemInfo
    c.quest.OnQuestItemUpdate()
    Equal(c.calls.complete, 1)
end)
Test("quest-bound turn-in can resolve the required item ID without a link", function()
    local c = Context()
    RequiredItem(c, 15, 4)
    c.env.GetQuestItemLink = function() return nil end
    c.env.GetQuestItemInfo = function() return "Required item", 0, 1, 1, true, 123 end
    c.env.C_Item.GetItemInfoInstant = function(item)
        Equal(item, 123)
        return 123, "", "", "", 0, 15
    end
    c.quest.OnQuestProgress()
    Equal(c.calls.complete, 1)
end)
Test("quest-bound required items do not bypass currency approval", function()
    local c = Context()
    RequiredItem(c, 15, 4)
    c:Prompt()
    Equal(c.calls.complete, 0)
    c.env.StaticPopupDialogs.JUSTQUEST_CONFIRM_CURRENCY.OnAccept(nil, c.popup)
    Equal(c.calls.complete, 1)
end)
Test("valid currency spend once completes without whitelisting", function()
    local c = Context()
    c:Prompt()
    c.env.StaticPopupDialogs.JUSTQUEST_CONFIRM_CURRENCY.OnAccept(nil, c.popup)
    Equal(c.calls.complete, 1)
    Equal(c.whitelist[c.id], nil)
    Equal(c.safety.GetReason(), "completing_quest")
end)
Test("valid currency always-allow whitelists only the approved quest", function()
    local c = Context()
    c:Prompt()
    c.env.StaticPopupDialogs.JUSTQUEST_CONFIRM_CURRENCY.OnAlt(nil, c.popup)
    Equal(c.calls.complete, 1)
    Equal(c.whitelist[c.id], true)
end)
for _, action in ipairs({ "OnAccept", "OnAlt" }) do
    Test("stale currency quest is rejected for " .. action, function()
        local c = Context()
        c:Prompt()
        c.id = 200
        c.env.StaticPopupDialogs.JUSTQUEST_CONFIRM_CURRENCY[action](nil, c.popup)
        Equal(c.calls.complete, 0)
        Equal(next(c.whitelist), nil)
        Equal(c.safety.IsBusy(), false)
    end)
end
for _, gate in ipairs({ "panel", "completable", "enabled", "automate", "dead", "control", "interference", "blocked" }) do
    Test("currency approval rechecks " .. gate, function()
        local c = Context()
        c:Prompt()
        if gate == "blocked" then c.blocked[c.id] = true
        elseif gate == "dead" or gate == "control" or gate == "interference" then c[gate] = true
        else c[gate] = false end
        c.env.StaticPopupDialogs.JUSTQUEST_CONFIRM_CURRENCY.OnAlt(nil, c.popup)
        Equal(c.calls.complete, 0)
        Equal(next(c.whitelist), nil)
        Equal(c.safety.IsBusy(), false)
    end)
end
Test("duplicate currency approval is not applied twice", function()
    local c = Context()
    c:Prompt()
    local accept = c.env.StaticPopupDialogs.JUSTQUEST_CONFIRM_CURRENCY.OnAccept
    accept(nil, c.popup)
    accept(nil, c.popup)
    Equal(c.calls.complete, 1)
end)
Test("currency cancel and hide still release waiting state", function()
    for _, action in ipairs({ "OnCancel", "OnHide" }) do
        local c = Context()
        c:Prompt()
        c.env.StaticPopupDialogs.JUSTQUEST_CONFIRM_CURRENCY[action](nil, c.popup)
        Equal(c.safety.IsBusy(), false)
        Equal(c.calls.complete, 0)
    end
end)
Test("two-button currency approval uses the same quest validation", function()
    local c = Context()
    c:Prompt()
    local accept = c.env.StaticPopupDialogs.JUSTQUEST_CONFIRM_CURRENCY_ONCE.OnAccept
    c.panel = false
    accept(nil, c.popup)
    Equal(c.calls.complete, 0)
    c.panel = true
    c:Prompt()
    accept(nil, c.popup)
    Equal(c.calls.complete, 1)
    Equal(next(c.whitelist), nil)
end)
Test("cancelled currency approval cannot be reused", function()
    local c = Context()
    c:Prompt()
    local dialog = c.env.StaticPopupDialogs.JUSTQUEST_CONFIRM_CURRENCY
    dialog.OnCancel(nil, c.popup)
    dialog.OnAccept(nil, c.popup)
    Equal(c.calls.complete, 0)
end)
Test("legacy blocked turn-in does not prevent an allowed sibling", function()
    local c = Context()
    c.active = { Offer(1), Offer(2) }
    c.blocked[1] = true
    c.quest.ProcessLegacyQuestGreeting()
    Equal(c.calls.select[1], 2)
end)
Test("legacy trivial preference matches modern filtering", function()
    local c = Context()
    c.config.quest.acceptTrivial = false
    c.available = { Offer(1, true), Offer(2, false) }
    c.quest.ProcessLegacyQuestGreeting()
    Equal(c.calls.select[1], 2)
end)
Test("legacy full log blocks accepts but permits turn-ins", function()
    local c = Context()
    c.quest.Initialize()
    c.errorHandler(nil, "UI_ERROR_MESSAGE", 0, c.env.ERR_QUEST_LOG_FULL)
    c.available = { Offer(1) }
    c.quest.ProcessLegacyQuestGreeting()
    Equal(#c.calls.select, 0)
    c.now = c.now + 1
    c.active = { Offer(2) }
    c.quest.ProcessLegacyQuestGreeting()
    Equal(c.calls.select[1], 2)
end)
Test("legacy pending turn-in yields to another quest", function()
    local c = Context()
    c.active = { Offer(1), Offer(2) }
    c.quest.ProcessLegacyQuestGreeting()
    c.safety.EndProcessing("test")
    c.quest.ProcessLegacyQuestGreeting()
    Equal(c.calls.select[1], 1)
    Equal(c.calls.select[2], 2)
end)
Test("legacy pending accept is not selected again", function()
    local c = Context()
    c.available = { Offer(c.id) }
    c.quest.OnQuestDetail()
    c.now = c.now + 1
    c.quest.ProcessLegacyQuestGreeting()
    Equal(c.calls.accept, 1)
    Equal(#c.calls.select, 0)
end)
Test("legacy unknown quest ID is left for the player", function()
    local c = Context()
    c.active = { { title = "Unknown", isComplete = true } }
    c.quest.ProcessLegacyQuestGreeting()
    Equal(#c.calls.select, 0)
end)
Test("quest detail with missing ID is left for the player", function()
    local c = Context()
    c.id = 0
    c.quest.OnQuestDetail()
    Equal(c.calls.accept, 0)
    Equal(c.safety.IsBusy(), false)
end)
Test("shared quest confirmation with missing ID is left for the player", function()
    local c = Context()
    c.config.quest.acceptEscort = true
    c.quest.OnQuestAcceptConfirm("Party member", "Unknown quest", 0)
    Equal(c.calls.confirm, 0)
end)
Test("shared quest confirmation still applies quest filters", function()
    local c = Context()
    c.config.quest.acceptEscort = true
    c.blocked[c.id] = true
    c.quest.OnQuestAcceptConfirm("Party member", "Blocked quest", c.id)
    Equal(c.calls.confirm, 0)
end)
Test("eligible shared quest confirmation still accepts", function()
    local c = Context()
    c.config.quest.acceptEscort = true
    c.quest.OnQuestAcceptConfirm("Party member", "Eligible quest", c.id)
    Equal(c.calls.confirm, 1)
end)
Test("same-count gossip identities and statuses change the content fingerprint", function()
    local c = Context()
    c.options = { { gossipOptionID = 10, status = 0, name = "Test" } }
    local first = c.services.ContentFingerprint()
    c.options[1].gossipOptionID = 20
    local second = c.services.ContentFingerprint()
    assert(first ~= second)
    c.options[1].status = 1
    assert(second ~= c.services.ContentFingerprint())
end)
Test("gossip fingerprint tracks policy-relevant changes and forced menus", function()
    local c = Context()
    local fields = { name = "Changed", flags = 1, spellID = 123, icon = 132060,
        selectOptionWhenOnlyOption = true, rewards = { {} } }
    for field, value in pairs(fields) do
        c.options = { { gossipOptionID = 10, name = "Test" } }
        local before = c.services.ContentFingerprint()
        c.options[1][field] = value
        assert(before ~= c.services.ContentFingerprint(), field)
    end
    local before = c.services.ContentFingerprint()
    c.force = true
    assert(before ~= c.services.ContentFingerprint())
end)
Test("unchanged gossip fingerprint remains stable", function()
    local c = Context()
    c.options = { { gossipOptionID = 10, name = "Test", status = 0 } }
    Equal(c.services.ContentFingerprint(), c.services.ContentFingerprint())
end)
Test("failed-menu cooldown releases on same-count replacement", function()
    local c = Context()
    c.config.gossip.aggressive = false
    c.options = {
        { gossipOptionID = 10, name = "Read this", status = 0 },
        { gossipOptionID = 11, name = "Or this", status = 0 },
    }
    Equal(c.gossip.OnGossipShow(), false)
    Equal(c.gossip.IsInFailedCooldown(), true)
    c.options = { { gossipOptionID = 20, name = "Vendor", status = 0, selectOptionWhenOnlyOption = true } }
    Equal(c.gossip.IsInFailedCooldown(), false)
    c.now = c.now + 0.2
    Equal(c.gossip.OnGossipShow(), true)
    Equal(c.calls.select[1], 20)
end)
Test("failed-menu cooldown releases when an option becomes available", function()
    local c = Context()
    c.config.gossip.aggressive = false
    c.options = {
        { gossipOptionID = 10, name = "Read this", status = 0 },
        { gossipOptionID = 20, name = "Vendor", status = 1, selectOptionWhenOnlyOption = true },
    }
    Equal(c.gossip.OnGossipShow(), false)
    Equal(c.gossip.IsInFailedCooldown(), true)
    c.options[1].status, c.options[2].status = 1, 0
    Equal(c.gossip.IsInFailedCooldown(), false)
    c.now = c.now + 0.2
    Equal(c.gossip.OnGossipShow(), true)
    Equal(c.calls.select[1], 20)
end)
Test("changed fingerprint does not bypass repeat protection", function()
    local c = Context()
    c.options = { { gossipOptionID = 20, name = "Vendor", status = 0, selectOptionWhenOnlyOption = true } }
    Equal(c.gossip.OnGossipShow(), true)
    c.options[1].name = "Vendor updated"
    c.now = c.now + 0.2
    Equal(c.gossip.OnGossipShow(), false)
    Equal(#c.calls.select, 1)
end)
Test("gossip blacklist still wins over whitelist and service classification", function()
    local c = Context()
    c.config.gossip.whitelist = { "teleport me" }
    c.safety.RebuildLists()
    c.options = { { gossipOptionID = 20, name = "teleport me", status = 0, selectOptionWhenOnlyOption = true } }
    Equal(c.gossip.OnGossipShow(), false)
    Equal(#c.calls.select, 0)
end)
Test("forced gossip menu leaves quest options for the player", function()
    local c = Context()
    c.force = true
    c.options = { { gossipOptionID = 21, name = "(Quest) Start", status = 0 } }
    Equal(c.gossip.OnGossipShow(), false)
    Equal(#c.calls.select, 0)
end)
Test("conservative mode takes an unflagged single-option menu (trainer doorway)", function()
    local c = Context()
    c.config.gossip.aggressive = false
    c.options = { { gossipOptionID = 30, name = "Show me my skills", status = 0, icon = 4620670 } }
    Equal(c.gossip.OnGossipShow(), true)
    Equal(c.calls.select[1], 30)
end)
Test("forced single-option menu is taken in both modes", function()
    for _, aggressive in ipairs({ false, true }) do
        local c = Context()
        c.config.gossip.aggressive = aggressive
        c.force = true
        c.options = { { gossipOptionID = 31, name = "Let me train", status = 0, icon = 4620670 } }
        Equal(c.gossip.OnGossipShow(), true)
        Equal(c.calls.select[1], 31)
    end
end)
Test("single flavor-conversation option stays open for the player", function()
    for _, aggressive in ipairs({ false, true }) do
        for _, icon in ipairs({ 132053, false }) do
            local c = Context()
            c.config.gossip.aggressive = aggressive
            c.force = true
            c.options = { { gossipOptionID = 36, name = "Tell me about this place", status = 0,
                icon = icon or nil } }
            Equal(c.gossip.OnGossipShow(), false)
            Equal(#c.calls.select, 0)
        end
    end
    local c = Context()
    c.config.gossip.aggressive = false
    c.options = { { gossipOptionID = 37, name = "Tell me more", status = 0, icon = 132053 } }
    Equal(c.gossip.OnGossipShow(), false)
    Equal(#c.calls.select, 0)
end)
Test("single-option step stands down when grouped in an instance", function()
    local c = Context()
    c.config.gossip.aggressive = false
    c.env.IsInInstance = function() return true end
    c.env.IsInGroup = function() return true end
    c.options = { { gossipOptionID = 32, name = "We are ready", status = 0, icon = 4620670 } }
    Equal(c.gossip.OnGossipShow(), false)
    Equal(#c.calls.select, 0)
end)
Test("single-option step ignores menus with locked siblings or pending quests", function()
    local c = Context()
    c.config.gossip.aggressive = false
    c.options = {
        { gossipOptionID = 33, name = "Talk", status = 0, icon = 4620670 },
        { gossipOptionID = 34, name = "Locked", status = 1 },
    }
    Equal(c.gossip.OnGossipShow(), false)
    Equal(#c.calls.select, 0)

    local q = Context()
    q.config.gossip.aggressive = false
    q.services.HasActionableQuestContent = function() return true end
    q.options = { { gossipOptionID = 35, name = "Talk", status = 0, icon = 4620670 } }
    Equal(q.gossip.OnGossipShow(), false)
    Equal(#q.calls.select, 0)
end)
Test("conservative service step leaves action options for the player", function()
    local c = Context()
    c.config.gossip.aggressive = false
    c.options = { {
        gossipOptionID = 22, name = "Service", status = 0,
        selectOptionWhenOnlyOption = true, rewards = { {} },
    } }
    Equal(c.gossip.OnGossipShow(), false)
    Equal(#c.calls.select, 0)
end)
Test("dispatch poll notices same-count content change without a new event", function()
    local c = Context()
    c.options = { { gossipOptionID = 10, name = "Old" } }
    local examined = 0
    c.modules.QuestEngine.OnGossipShow = function()
        examined = examined + 1
        return false
    end
    c.services.ScheduleContentCheck(0.01, "test")
    c:Advance(0.02)
    Equal(examined, 1)
    c:Advance(0.02)
    Equal(examined, 1)
    c.options[1].gossipOptionID = 20
    c:Advance(0.05)
    Equal(examined, 2)
end)
Test("step pace: normal mode holds to the pace since the last step, fast mode does not", function()
    local c = Context()
    Equal(c.services.PaceWait(), 0)
    c.services.NoteStep()
    assert(math.abs(c.services.PaceWait() - 0.25) < 1e-9)
    c.now = c.now + 0.1
    assert(math.abs(c.services.PaceWait() - 0.15) < 1e-9)
    c.config.advanced.timingMultiplier = 5
    assert(math.abs(c.services.PaceWait() - 0.4) < 1e-9, "multiplier clamps to 2x")
    c.config.advanced.timingMultiplier = 1.0
    c.now = c.now + 0.2
    Equal(c.services.PaceWait(), 0)
    c.services.NoteStep()
    c.config.fastMode = true
    Equal(c.services.PaceWait(), 0)
end)
Test("dispatch holds a ready pass to the step pace, then acts", function()
    local c = Context()
    local examined = 0
    c.modules.QuestEngine.OnGossipShow = function()
        examined = examined + 1
        return true
    end
    c.options = { { gossipOptionID = 10, name = "Next" } }
    c.services.NoteStep()
    c.services.ScheduleContentCheck(0.05, "test")
    c:Advance(0.06)
    Equal(examined, 0)
    c:Advance(0.1)
    Equal(examined, 0)
    c:Advance(0.1)
    Equal(examined, 1)
end)
Test("gossip and quest selections mark a step", function()
    local c = Context()
    c.options = { { gossipOptionID = 40, name = "Vendor", status = 0, selectOptionWhenOnlyOption = true } }
    Equal(c.gossip.OnGossipShow(), true)
    assert(c.services.PaceWait() > 0, "a gossip selection must start the pace")
end)
Test("dispatch shares one content read and quest filter with conservative gossip", function()
    local c = Context()
    c.config.gossip.aggressive = false
    c.available = { Offer(200) }
    c.blocked[200] = true
    c.options = { {
        gossipOptionID = 20, name = "Service reward", status = 0,
        selectOptionWhenOnlyOption = true, rewards = { {} },
    } }
    local reads = { active = 0, available = 0, options = 0, filters = 0 }
    c.env.C_GossipInfo.GetActiveQuests = function()
        reads.active = reads.active + 1
        return c.active
    end
    c.env.C_GossipInfo.GetAvailableQuests = function()
        reads.available = reads.available + 1
        return c.available
    end
    c.env.C_GossipInfo.GetOptions = function()
        reads.options = reads.options + 1
        return c.options
    end
    local filter = c.quest.GetActionableQuests
    c.quest.GetActionableQuests = function(...)
        reads.filters = reads.filters + 1
        return filter(...)
    end

    c.services.ScheduleContentCheck(0.01, "test")
    c:Advance(0.02)
    Equal(reads.active, 1)
    Equal(reads.available, 1)
    Equal(reads.options, 1)
    Equal(reads.filters, 1)
    Equal(#c.calls.select, 0)

    c.options = { { gossipOptionID = 30, name = "Vendor", status = 0, selectOptionWhenOnlyOption = true } }
    c:Advance(0.05)
    Equal(c.calls.select[1], 30)
end)
Test("dispatch snapshot does not bypass a newly held automation modifier", function()
    local c = Context()
    c.options = { { gossipOptionID = 30, name = "Vendor", status = 0, selectOptionWhenOnlyOption = true } }
    local filter = c.quest.GetActionableQuests
    c.quest.GetActionableQuests = function(...)
        local active, available, pending = filter(...)
        c.automate = false
        return active, available, pending
    end
    c.services.ScheduleContentCheck(0.01, "test")
    c:Advance(0.02)
    Equal(#c.calls.select, 0)
    Equal(c.restored, true)
end)
Test("dispatch snapshot preserves turn-in priority over accepts and gossip", function()
    local c = Context()
    c.active = { Offer(100) }
    c.available = { Offer(200) }
    c.options = { { gossipOptionID = 30, name = "Vendor", status = 0, selectOptionWhenOnlyOption = true } }
    c.env.C_GossipInfo.SelectActiveQuest = function(id)
        table.insert(c.calls.select, id)
    end
    c.env.C_GossipInfo.SelectAvailableQuest = function(id)
        table.insert(c.calls.select, id)
    end
    c.services.ScheduleContentCheck(0.01, "test")
    c:Advance(0.02)
    Equal(#c.calls.select, 1)
    Equal(c.calls.select[1], 100)
end)
Test("performance diagnostics are opt-in and only report slow phases", function()
    local c = Context()
    local clock, calls = 0, 0
    c.env.debugprofilestop = function()
        calls = calls + 1
        return clock
    end
    Equal(c.services.ProfileStart(), nil)
    c.services.ProfileEnd("Disabled", 0)
    Equal(calls, 0)

    c.services.SetDebugMode(true)
    local started = c.services.ProfileStart()
    local logs = #c.logs
    clock = 1.99
    c.services.ProfileEnd("Fast", started)
    Equal(#c.logs, logs)
    clock = 2
    c.services.ProfileEnd("Slow", started)
    Equal(#c.logs, logs + 1)
    Equal(c.logs[#c.logs], "Slow: 2.00 ms")

    c.env.debugprofilestop = nil
    Equal(c.services.ProfileStart(), nil)
    c.services.ProfileEnd("Unavailable", started)
    Equal(#c.logs, logs + 1)
end)
Test("follow-up proximity scan matches the quest-line refresh cadence", function()
    local c = Context()
    local lineScans = 0
    c.services.DialogClosedFor = function() return 2 end
    c.services.IsDialogContinuing = function() return false end
    local position = { GetXY = function() return 0.1, 0.1 end }
    c.env.C_Map = {
        GetBestMapForUnit = function() return 1 end,
        GetPlayerMapPosition = function() return position end,
        GetMapWorldSize = function() return 1000, 1000 end,
    }
    c.env.C_QuestLine = {
        RequestQuestLinesForMap = function() end,
        GetAvailableQuestLines = function()
            lineScans = lineScans + 1
            return {}
        end,
    }

    c.quest.WatchForFollowUp()
    c:Advance(0.5)
    Equal(lineScans, 1)
    c:Advance(1)
    Equal(lineScans, 1, "must not rescan quest lines on the old 0.5s cadence")
    c:Advance(0.5)
    Equal(lineScans, 2)
end)

print(string.format("%d quest/gossip regression tests passed", count))
return count
