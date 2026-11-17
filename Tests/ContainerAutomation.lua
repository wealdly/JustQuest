-- Run in Lua 5.1: loadfile(thisFile)(justQuestRoot).
local root = ...
assert(root, "Pass the JustQuest addon root")

local function Equal(actual, expected, label)
    assert(actual == expected, (label or "value")..": expected "..tostring(expected)..", got "..tostring(actual))
end

local function Context()
    local c = {
        now = 100, bags = { [0] = {} }, items = {}, sources = {},
        modules = {}, timers = {}, logs = {}, attempts = {}, confirmed = 0,
        state = "IDLE", allowed = true, combat = false, contract = true,
        quests = {
            [2459] = {
                quest = { ObjectiveData = { { Type = "item", Id = 8050 } } },
                native = { { text = "Tallonkai's Jewel: 0/1", type = "item", done = false } },
            },
        },
    }
    local e = setmetatable({}, { __index = _G })
    e._G, c.env = e, e
    e.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4
    e.BACKPACK_CONTAINER = 0
    e.LOCKED = "Locked"
    e.SlashCmdList = {}
    e.wipe = function(t) for key in pairs(t) do t[key] = nil end return t end
    e.GetTime = function() return c.now end
    e.InCombatLockdown = function() return c.combat end
    e.CreateFrame = function()
        local f = {}
        function f:RegisterEvent() end
        function f:UnregisterEvent() end
        function f:SetScript(_, handler) self.handler = handler end
        function f:UnregisterAllEvents() end
        return f
    end
    e.C_Container = {
        GetContainerNumSlots = function(bag) return #(c.bags[bag] or {}) end,
        GetContainerItemInfo = function(bag, slot) return (c.bags[bag] or {})[slot] end,
        GetContainerItemCooldown = function(bag, slot)
            local item = c.bags[bag][slot]
            return item.cooldown and 100 or 0, item.cooldown and 30 or 0
        end,
        UseContainerItem = function(bag, slot)
            c.attempts[#c.attempts + 1] = c.bags[bag][slot].itemID
            c.bags[bag][slot] = nil
        end,
    }
    e.C_Item = {
        GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, c.items[id].classID end,
    }
    e.C_QuestLog = {
        GetLogIndexForQuestID = function(id)
            return c.quests[id] and c.quests[id].logged ~= false and id or nil
        end,
        IsComplete = function(id) return c.quests[id].complete == true end,
    }
    e.GetQuestLogLeaderBoard = function(index, id)
        local row = c.quests[id].native[index]
        if row then return row.text, row.type, row.done end
    end
    e.Questie = { API = { isReady = true } }
    e.QuestieLoader = {
        ImportModule = function()
            return { Iterate = function() return pairs(c.quests) end }
        end,
    }
    e.LibQuestieDB = {
        RequireContract = function() return c.contract, "unsupported contract" end,
        Item = { Get = function(id, key)
            Equal(key, "itemDrops")
            return c.sources[id]
        end },
    }
    local ns = { Core = {}, Database = { DANGEROUS_CONTAINERS = {} } }
    c.ns = ns
    ns.Core.RegisterModule = function(name, module) c.modules[name] = module end
    ns.Core.GetModule = function(name) return c.modules[name] end
    ns.Core.ModuleGetter = function(name) return function() return c.modules[name] end end
    ns.Core.SetupEvents = function() end
    local function Load(path)
        local chunk = assert(loadfile(root.."\\"..path))
        setfenv(chunk, e)
        return chunk("JustQuest", ns)
    end
    c.Load = Load
    Load("Core\\Constants.lua")
    c.profile = ns.Constants.DEFAULTS.profile
    e.JustQuestDB = { profile = c.profile }
    c.modules.Services = {
        Debug = function(_, message) c.logs[#c.logs + 1] = message end,
        ValidateAutomationPreconditions = function() return c.allowed end,
        ScheduleOnce = function(key, _, callback) c.timers[key] = callback end,
        ScheduleRepeating = function() end,
        GetTiming = function(_, fallback) return fallback end,
        NoteAutomation = function(kind)
            Equal(kind, "containers")
            c.confirmed = c.confirmed + 1
        end,
    }
    c.modules.SafetyEngine = {
        IsState = function(state) return c.state == state end,
        IsBusy = function() return c.state ~= "IDLE" end,
        GetStateTime = function() return 10 end,
    }
    c.modules.GameData = {
        BagTooltipLines = function(bag, slot)
            return c.bags[bag][slot].tooltipLocked and { { leftText = "Locked" } } or {}
        end,
    }
    c.config = Load("Core\\Config.lua")
    c.config.Initialize()
    c.engine = Load("Engines\\ContainerEngine.lua")
    c.engine.Initialize()
    c.sources[8050] = { 8049 }
    function c:BagItem(id, overrides)
        local item = { itemID = id, stackCount = 1, hasLoot = true, classID = 12 }
        for key, value in pairs(overrides or {}) do item[key] = value end
        self.items[id] = item
        self.bags[0] = { item }
        return item
    end
    return c
end

do
    local c = Context()
    c:BagItem(8049)
    c.engine.OpenBagContainers()
    Equal(c.attempts[1], 8049, "unfinished jewel objective admits its necklace without a whitelist")
    Equal(c.confirmed, 0, "use is not yet confirmed")
    c.engine.OnItemLockChanged(0, 1)
    Equal(c.confirmed, 1, "consumption confirms the open")
    c:BagItem(8049)
    c.quests[2459].native[1].done = true
    c.now = 110
    c.engine.OpenBagContainers()
    Equal(#c.attempts, 1, "finishing an objective removes its previously eligible containers")
end

do
    local c = Context()
    c.sources[8049], c.sources[9001] = { 9001 }, { 8049 }
    c:BagItem(9001)
    c.engine.OpenBagContainers()
    Equal(c.attempts[1], 9001, "nested container sources and cycles are handled generically")
end

for _, condition in ipairs({ "complete", "objectiveDone", "notLogged", "delivery", "notOpenable",
    "blacklist", "locked", "tooltipLocked", "cooldown", "combat", "busy", "paused", "toggleOff", "listOnly" }) do
    local c = Context()
    local item = c:BagItem(8049)
    if condition == "complete" then c.quests[2459].complete = true
    elseif condition == "objectiveDone" then c.quests[2459].native[1].done = true
    elseif condition == "notLogged" then c.quests[2459].logged = false
    elseif condition == "delivery" then c.sources[8050] = nil
    elseif condition == "notOpenable" then item.hasLoot = false
    elseif condition == "blacklist" then c.config.Set("containers", "blacklist", { [8049] = true })
    elseif condition == "locked" then item.isLocked = true
    elseif condition == "tooltipLocked" then item.tooltipLocked = true
    elseif condition == "cooldown" then item.cooldown = true
    elseif condition == "combat" then c.combat = true
    elseif condition == "busy" then c.state = "BUSY"
    elseif condition == "paused" then c.allowed = false
    elseif condition == "toggleOff" then c.config.Set("containers", "openQuestLoot", false)
    elseif condition == "listOnly" then c.config.Set("containers", "mode", "list")
    end
    c.engine.OpenBagContainers()
    Equal(#c.attempts, 0, condition.." must prevent automatic quest-container opening")
end

do
    local c = Context()
    c:BagItem(8049)
    c.config.Set("containers", "openQuestLoot", false)
    c.engine.OpenBagContainers()
    c.config.Set("containers", "openQuestLoot", true)
    c.engine.OpenBagContainers()
    Equal(#c.attempts, 1, "category changes refresh the real configuration cache")
end

do
    local c = Context()
    c:BagItem(8049)
    c.config.Set("containers", "mode", "list")
    c.config.Set("containers", "whitelist", { [8049] = true })
    c.engine.OpenBagContainers()
    Equal(#c.attempts, 1, "explicit whitelist remains available in list-only mode")
end

do
    local c = Context()
    c:BagItem(8049)
    c.env.Questie = nil
    c.engine.OpenBagContainers()
    Equal(#c.attempts, 0, "missing optional quest data never broadens quest-item opening")
    assert(#c.logs > 0, "unavailable quest support is reported through standard diagnostics")
    c:BagItem(55, { classID = 15 })
    c.engine.OpenBagContainers()
    Equal(c.attempts[1], 55, "ordinary containers still open without Questie")
end

for _, condition in ipairs({ "notReady", "missingDB", "missingContractAPI", "incompatible", "noQuests",
    "notItemObjective", "nativeMismatch" }) do
    local c = Context()
    c:BagItem(8049)
    if condition == "notReady" then c.env.Questie.API.isReady = false
    elseif condition == "missingDB" then c.env.LibQuestieDB = nil
    elseif condition == "missingContractAPI" then c.env.LibQuestieDB.RequireContract = nil
    elseif condition == "incompatible" then c.contract = false
    elseif condition == "noQuests" then c.quests = {}
    elseif condition == "notItemObjective" then c.quests[2459].quest.ObjectiveData[1].Type = "monster"
    elseif condition == "nativeMismatch" then c.quests[2459].native[1].type = "monster"
    end
    c.engine.OpenBagContainers()
    Equal(#c.attempts, 0, condition.." must not admit quest containers")
end

do
    local c = Context()
    local options
    c.env.LibStub = function(name)
        if name == "AceConfigRegistry-3.0" then
            return { RegisterOptionsTable = function(_, addon, value)
                if addon == "JustQuest" then options = value end
            end }
        end
    end
    c.Load("Interface\\ConfigUI.lua").Initialize()
    local toggle = options.args.containers.args.settings.args.openQuestLoot
    Equal(toggle.disabled(), false, "new UI toggle is usable in openable mode")
    toggle.set({}, false)
    Equal(toggle.get(), false, "UI setter uses the real configuration")
    c.config.Set("containers", "mode", "list")
    Equal(toggle.disabled(), true, "UI disables the category in list-only mode")
end

do
    local c = Context()
    c:BagItem(8049)
    c.engine.OnAutomationComplete()
    assert(c.timers.container_scan_after_automation_container, "acceptance reschedules carried quest containers")
    c.timers.container_scan_after_automation_container()
    Equal(c.attempts[1], 8049)
end

print("PASS: required quest-loot containers, source chains, safety gates, config, confirmation, baseline containers")
