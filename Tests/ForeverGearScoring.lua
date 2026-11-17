-- Run in Lua 5.1: loadfile(thisFile)(justQuestRoot, justJunkRoot).
local questRoot, junkRoot = ...
assert(questRoot and junkRoot, "Pass both addon roots")

local function Load(root, path, env, name, namespace)
    local chunk = assert(loadfile(root .. "\\" .. path))
    setfenv(chunk, env)
    return chunk(name, namespace)
end

local function Context(forever, class, withoutAdvisor)
    local c = {
        items = {}, worn = {}, bags = { [0] = {} }, spells = {}, proficiencies = {},
        modules = {}, timers = {}, logs = {}, callbacks = {}, frames = {},
        sets = {}, prices = {}, combat = false, level = 30, markers = 0, equipped = {},
    }
    local e = setmetatable({}, { __index = _G })
    c.env = e
    e._G = e
    e.WOW_PROJECT_CAMELOT = 99
    e.WOW_PROJECT_ID = forever == false and 1 or 99
    e.NUM_BAG_SLOTS = 4
    e.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4
    e.ARMOR_TEMPLATE = "%s Armor"
    e.ITEM_UNIQUE_EQUIPPABLE = "Unique-Equipped"
    e.Enum = {
        ItemClass = {}, ItemArmorSubclass = {}, ItemTradegoodsSubclass = {},
        ItemMiscellaneousSubclass = {}, BagSlotFlags = {},
        TooltipDataLineType = {
            ItemSpellTriggerOnUse = 44, ItemSpellTriggerOnEquip = 45,
            ItemSpellTriggerOnProc = 46, TradeTimeRemaining = 36,
        },
    }
    e.C_Timer = {}
    e.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    e.GetTime = function() return 100 end
    e.date = function() return "12:00:00" end
    e.UnitLevel = function() return c.level end
    e.UnitIsDeadOrGhost = function() return false end
    e.UnitCastingInfo = function() return nil end
    e.UnitChannelInfo = function() return nil end
    e.InCombatLockdown = function() return c.combat end
    e.CanDualWield = function() return c.dualWield == true end
    e.GetAverageItemLevel = function() return 100, 100 end
    e.UnitFullName = function() return "Test", "Realm" end
    e.UnitClass = function() return class or "WARRIOR", class or "WARRIOR", 1 end
    local prof = {
        [9078] = true, [9077] = true, [8737] = true, [750] = true, [9116] = true,
        [196] = true, [197] = true, [264] = true, [266] = true, [198] = true,
        [199] = true, [200] = true, [201] = true, [202] = true, [227] = true,
        [15590] = true, [1180] = true, [2567] = true, [5011] = true, [5009] = true,
    }
    e.IsPlayerSpell = function(id)
        if prof[id] then return c.proficiencies[id] ~= false end
        return c.spells[id] == true
    end
    e.C_SpecializationInfo = {
        GetSpecialization = function() return 1 end,
        GetSpecializationInfo = function(i)
            if i == 1 then return 1, "Forever", "", 0, "DAMAGER", 0 end
        end,
    }
    e.GetInventoryItemLink = function(_, slot) return c.worn[slot] end
    local function Item(link)
        if type(link) == "number" then
            for _, item in pairs(c.items) do if item.id == link then return item end end
        end
        return c.items[link]
    end
    e.GetInventoryItemID = function(_, slot)
        local item = Item(c.worn[slot])
        return item and item.id
    end
    e.CreateFrame = function()
        local frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        function frame:SetScript(_, fn) self.handler = fn end
        c.frames[#c.frames + 1] = frame
        return frame
    end
    e.EventRegistry = {
        RegisterCallback = function(_, event, fn, owner)
            c.callbacks[event] = c.callbacks[event] or {}
            table.insert(c.callbacks[event], function(...) fn(owner, ...) end)
        end,
        TriggerEvent = function(_, event, ...)
            for _, fn in ipairs(c.callbacks[event] or {}) do fn(...) end
        end,
    }
    e.C_Item = {
        GetItemInfo = function(link)
            local i = Item(link)
            if not i or i.uncached then return nil end
            return "Test", link, i.quality, i.ilvl, i.reqLevel, "", "", 1,
                i.invType, 0, i.vendorPrice, i.classID, i.subClassID, i.bindType, 0, i.setID
        end,
        GetItemInfoInstant = function(link)
            local i = Item(link)
            if not i then return nil end
            return i.id, "", "", i.invType, 0, i.classID, i.subClassID
        end,
        GetItemStats = function(link)
            local i = Item(link)
            if i and i.statError then error("stats failed") end
            return i and i.stats
        end,
        GetItemSpell = function(link)
            local i = Item(link)
            return i and i.useSpell
        end,
        GetDetailedItemLevelInfo = function(link) local i = Item(link) return i and i.ilvl end,
        IsEquippableItem = function() return true end,
        GetCurrentItemLevel = function(location)
            local link = location.equipment and c.worn[location.equipment]
                or c.bags[location.bag][location.slot].hyperlink
            return Item(link).ilvl
        end,
        IsBound = function(location) return c.bags[location.bag][location.slot].isBound end,
        EquipItemByName = function(link, slot)
            c.equipped[#c.equipped + 1] = { link = link, slot = slot }
            c.worn[slot] = link
        end,
    }
    e.C_TooltipInfo = {
        GetHyperlink = function(link)
            local i = Item(link)
            if not i or i.tooltipMissing then return nil end
            local lines = { { type = 22, leftText = "Test" } }
            if i.armor then lines[#lines + 1] = { leftText = tostring(i.armor) .. " Armor" } end
            if i.dpsText then lines[#lines + 1] = { leftText = "(" .. i.dpsText .. " damage per second)" } end
            if i.effect then lines[#lines + 1] = { type = i.effect } end
            return { lines = lines }
        end,
    }
    e.TooltipUtil = {
        FindLinesFromGetter = function(_, _, bag, slot)
            local info = c.bags[bag][slot]
            return info.tradeTimer and { {} } or {}
        end,
    }
    e.C_EquipmentSet = {
        GetEquipmentSetIDs = function() return next(c.sets) and { 1 } or {} end,
        GetItemIDs = function() return c.sets end,
    }
    e.C_Container = {
        GetContainerNumSlots = function(bag) return #(c.bags[bag] or {}) end,
        GetContainerItemInfo = function(bag, slot) return (c.bags[bag] or {})[slot] end,
        GetContainerItemPurchaseInfo = function(bag, slot)
            local info = c.bags[bag][slot]
            return info.refund and { refundSeconds = 120, money = 1 } or nil
        end,
        UseContainerItem = function(bag, slot) c.bags[bag][slot] = nil end,
    }
    e.ItemLocation = {
        CreateFromEquipmentSlot = function(_, slot) return { equipment = slot, IsValid = function() return true end } end,
    }
    c.quest = { Core = {} }
    e.JustQuest = c.quest
    c.quest.Core.RegisterModule = function(name, module) c.modules[name] = module end
    c.quest.Core.GetModule = function(name) return c.modules[name] end
    c.quest.Core.ModuleGetter = function(name) return function() return c.modules[name] end end
    Load(questRoot, "Core\\Constants.lua", e, "JustQuest", c.quest)
    c.config = c.quest.Constants.DEFAULTS.profile
    c.modules.Config = {
        Get = function(module, key)
            if module then return c.config[module][key] end
            return c.config[key]
        end,
        Set = function(module, key, value) c.config[module][key] = value end,
    }
    c.modules.Services = {
        Debug = function(_, text) c.logs[#c.logs + 1] = text end,
        ScheduleOnce = function(key, _, fn) c.timers[key] = fn end,
        ShouldAutomate = function() return true end,
    }
    Load(questRoot, "Services\\GameData.lua", e, "JustQuest", c.quest)
    c.weights = Load(questRoot, "Services\\ClassWeights.lua", e, "JustQuest", c.quest)
    c.scoring = Load(questRoot, "Services\\GearScoring.lua", e, "JustQuest", c.quest)
    Load(questRoot, "Services\\PawnScoring.lua", e, "JustQuest", c.quest)
    if not withoutAdvisor then
        c.advisor = Load(questRoot, "Engines\\GearAdvisor.lua", e, "JustQuest", c.quest)
    end
    c.reward = Load(questRoot, "Engines\\RewardEngine.lua", e, "JustQuest", c.quest)

    c.junk = {}
    Load(junkRoot, "Config_Data.lua", e, "JustJunk", c.junk)
    Load(junkRoot, "Utils.lua", e, "JustJunk", c.junk)
    local utils = c.junk.Utils
    utils.Debug = function(_, text) c.logs[#c.logs + 1] = text end
    utils.ScheduleOnce = function(key, _, fn) c.timers[key] = fn end
    utils.CreateItemLocation = function(bag, slot) return { bag = bag, slot = slot } end
    utils.IsBagProtected = function() return false end
    utils.IterateBagSlots = function()
        local slot = 0
        return function()
            slot = slot + 1
            if c.bags[0][slot] then return 0, slot end
        end
    end
    c.junkConfig = c.junk.ConfigData.defaults.profile
    c.junk.ConfigModule = {
        Get = function(module, key)
            if module then return c.junkConfig[module][key] end
            return c.junkConfig[key]
        end,
    }
    c.junk.MarketEngine = { GetPrice = function(link) return c.prices[link] or 0, "test" end }
    c.junk.BagMarkers = { UpdateAll = function() c.markers = c.markers + 1 end }
    Load(junkRoot, "ItemEngine.lua", e, "JustJunk", c.junk)

    function c:Add(id, stats, invType, options)
        local i = {
            id = id, stats = stats, invType = invType or "INVTYPE_WRIST", classID = 4,
            subClassID = 1, ilvl = 1, quality = 2, reqLevel = 0, vendorPrice = 10, bindType = 1,
        }
        for k, v in pairs(options or {}) do i[k] = v end
        local link = "item:" .. id .. ":" .. tostring(i.variant or "")
        self.items[link] = i
        return link
    end
    function c:Bag(link, options)
        local i = self.items[link]
        local info = { hyperlink = link, itemID = i.id, quality = i.quality, stackCount = 1, isBound = true }
        for k, v in pairs(options or {}) do info[k] = v end
        table.insert(self.bags[0], info)
        return #self.bags[0]
    end
    function c:Verdict(link) return self.scoring.EvaluateItem(link) end
    function c:FireEvent(event, ...)
        for _, frame in ipairs(self.frames) do
            if frame.events[event] then frame.handler(frame, event, ...) end
        end
    end
    function c:Sell(link, bound)
        local i = self.items[link]
        return self.junk.ItemEngine.EvaluateItemForSelling({
            itemID = i.id, itemLink = link, classID = i.classID, subClassID = i.subClassID,
            equipSlot = i.invType, quality = i.quality, itemLevel = i.ilvl, vendorPrice = i.vendorPrice,
            bindType = i.bindType, isSoulbound = bound ~= false, stackCount = 1, maxStackSize = 1,
        })
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
local function Near(actual, expected) assert(math.abs(actual - expected) < 0.00001) end
local STR, INT, DPS = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"
local function Gear(forever, class)
    local c = Context(forever, class)
    c.worn[9] = c:Add(1, { [STR] = 100 })
    return c
end

Test("lower item-level positive stats are kept", function()
    local c = Gear()
    c.items[c.worn[9]].ilvl = 200
    local link = c:Add(2, { [STR] = 110 })
    Equal(c:Verdict(link).status, "upgrade")
    Equal(c:Sell(link), false)
end)
Test("sub-threshold upgrade independent of advisor settings", function()
    local c = Gear()
    c.config.enabled, c.config.gearSwap.advisorEnabled = false, false
    c.config.gearSwap.minUpgradePct = 25
    c.config.gearSwap.ignoreItems[2] = true
    local link = c:Add(2, { [STR] = 101 })
    Near(c:Verdict(link).pawnPercentUpgrade, 0.01)
    Equal(c:Sell(link), false)
end)
Test("known bound non-upgrade is sellable regardless of item level", function()
    local c = Gear()
    Equal(c:Sell(c:Add(2, { [STR] = 80 }, nil, { ilvl = 500 })), true)
end)
Test("equal score is non-upgrade; required level is not a stat", function()
    local c = Gear()
    local link = c:Add(2, { [STR] = 100 }, nil, { reqLevel = 20 })
    Equal(c:Verdict(link).status, "not_upgrade")
end)
Test("valuable transferable gear is kept", function()
    local c = Gear()
    local link = c:Add(2, { [STR] = 80 }, nil, { bindType = 2 })
    c.prices[link] = 100001
    Equal(c:Sell(link, false), false)
end)
Test("unpriced transferable gear is kept", function()
    local c = Gear()
    Equal(c:Sell(c:Add(2, { [STR] = 80 }, nil, { bindType = 2 }), false), false)
end)
Test("low-value transferable non-upgrade follows auction policy", function()
    local c = Gear()
    local link = c:Add(2, { [STR] = 80 }, nil, { bindType = 2 })
    c.prices[link] = 100
    Equal(c:Sell(link, false), true)
end)
for _, bind in ipairs({ 5, 6 }) do
    Test("alt-bound protection " .. bind, function()
        local c = Gear()
        Equal(c:Sell(c:Add(2, { [STR] = 80 }, nil, { bindType = bind })), false)
    end)
end
Test("manual keep and saved set remain protected", function()
    local c = Gear()
    local link = c:Add(2, { [STR] = 80 })
    c.junkConfig.merchant.forceKeepItems[2] = true
    Equal(c:Sell(link), false)
    c.junkConfig.merchant.forceKeepItems[2] = nil
    c.sets = { 2 }
    Equal(c:Sell(link), false)
end)
for _, flag in ipairs({ "tradeTimer", "refund", "isLocked" }) do
    Test("bag protection " .. flag, function()
        local c = Gear()
        local slot = c:Bag(c:Add(2, { [STR] = 80 }), { [flag] = true })
        Equal(c.junk.ItemEngine.ShouldSellBagSlot(0, slot), false)
    end)
end
Test("missing provider keeps non-grey gear", function()
    local c = Gear()
    c.env.JustQuest = nil
    Equal(c:Sell(c:Add(2, { [STR] = 80 })), false)
end)
Test("provider failure keeps gear and logs the error", function()
    local c = Gear()
    c.scoring.EvaluateItem = function() error("provider failed") end
    Equal(c:Sell(c:Add(2, { [STR] = 80 })), false)
    assert(c.logs[#c.logs]:find("provider failed", 1, true))
end)
Test("malformed provider keeps gear", function()
    local c = Gear()
    c.scoring.EvaluateItem = function() return false end
    Equal(c:Sell(c:Add(2, { [STR] = 80 })), false)
    assert(c.logs[#c.logs]:find("Invalid", 1, true))
end)
Test("unsupported provider version keeps gear", function()
    local c = Gear()
    c.scoring.version = 2
    Equal(c:Sell(c:Add(2, { [STR] = 80 })), false)
end)
Test("unknown or contradictory provider verdict never authorizes sale", function()
    local c = Gear()
    local link = c:Add(2, { [STR] = 80 })
    c.scoring.EvaluateItem = function() return { status = "not_upgrade", isUpgrade = true } end
    Equal(c:Sell(link), false)
    c.scoring.EvaluateItem = function() return { status = "unknown", isUpgrade = false } end
    Equal(c:Sell(link), false)
end)
for _, flag in ipairs({ "uncached", "tooltipMissing", "statError" }) do
    Test("missing candidate data " .. flag, function()
        local c = Gear()
        local link = c:Add(2, { [STR] = 80 }, nil, { [flag] = true })
        Equal(c:Verdict(link).status, "unknown")
        Equal(c:Sell(link), false)
    end)
end
Test("missing equipped stats is not an empty baseline", function()
    local c = Gear()
    c.items[c.worn[9]].statError = true
    Equal(c:Verdict(c:Add(2, { [STR] = 80 })).status, "unknown")
end)
Test("unrecognized stats keep gear", function()
    local c = Gear()
    local link = c:Add(2, { FOREVER_NEW_STAT = 5 })
    Equal(c:Verdict(link).status, "unknown")
    Equal(c:Sell(link), false)
end)
Test("invalid numeric stats keep gear", function()
    local c = Gear()
    for index, value in ipairs({ math.huge, -math.huge, "100" }) do
        Equal(c:Verdict(c:Add(index + 1, { [STR] = value })).status, "unknown")
    end
    Equal(c:Verdict(c:Add(5, { [STR] = 0 / 0 })).status, "unknown")
end)
Test("missing effect enums keep gear", function()
    local c = Gear()
    c.env.Enum.TooltipDataLineType.ItemSpellTriggerOnProc = nil
    Equal(c:Sell(c:Add(2, { [STR] = 80 })), false)
end)
Test("item-spell fallback protects utility effects", function()
    local c = Gear()
    Equal(c:Sell(c:Add(2, { [STR] = 80 }, nil, { useSpell = "Teleport" })), false)
end)
for _, effect in ipairs({ 44, 45, 46 }) do
    Test("unmodeled effect " .. effect, function()
        local c = Gear()
        local link = c:Add(2, { [STR] = 80 }, nil, { effect = effect })
        Equal(c:Verdict(link).status, "unknown")
        Equal(c:Sell(link), false)
    end)
end
Test("equipped effect and set effects prevent stat-only verdicts", function()
    local c = Gear()
    c.items[c.worn[9]].effect = 46
    Equal(c:Verdict(c:Add(2, { [STR] = 110 })).status, "unknown")
    c.items[c.worn[9]].effect = nil
    Equal(c:Verdict(c:Add(3, { [STR] = 80 }, nil, { setID = 10 })).status, "unknown")
end)
Test("unsupported trinket, relic, and utility tool are kept", function()
    local c = Gear()
    for _, invType in ipairs({ "INVTYPE_TRINKET", "INVTYPE_RELIC" }) do
        Equal(c:Sell(c:Add(2, {}, invType)), false)
    end
    Equal(c:Sell(c:Add(3, { [DPS] = 10 }, "INVTYPE_WEAPON", { classID = 2, subClassID = 14 })), false)
end)
Test("unmet level or proficiency is unknown, not junk", function()
    local c = Gear()
    Equal(c:Verdict(c:Add(2, { [STR] = 80 }, nil, { reqLevel = 50 })).status, "unknown")
    c.proficiencies[264] = false
    Equal(c:Verdict(c:Add(3, { [DPS] = 10 }, "INVTYPE_RANGED", { classID = 2, subClassID = 2 })).status, "unknown")
end)
Test("combat keeps gear without stat arithmetic", function()
    local c = Gear()
    c.combat = true
    Equal(c:Sell(c:Add(2, { [STR] = 80 })), false)
end)
Test("lighter armor is a valid Forever upgrade", function()
    local c = Gear()
    local link = c:Add(2, { [STR] = 110 }, nil, { subClassID = 2 })
    Equal(c:Verdict(link).status, "upgrade")
    Equal(c:Sell(link), false)
end)
Test("two-hander compares both hands", function()
    local c = Context()
    c.worn[16] = c:Add(1, { [DPS] = 10 }, "INVTYPE_WEAPON", { classID = 2, subClassID = 7 })
    c.worn[17] = c:Add(2, { [STR] = 50 }, "INVTYPE_SHIELD", { subClassID = 6 })
    local link = c:Add(3, { [DPS] = 15 }, "INVTYPE_2HWEAPON", { classID = 2, subClassID = 8 })
    local result = c:Verdict(link)
    Equal(result.status, "not_upgrade")
    Near(result.baselineScore, 120)
    Near(result.candidateScore, 105)
end)
Test("empty main hand still includes displaced off-hand", function()
    local c = Context()
    c.worn[17] = c:Add(2, { [STR] = 100 }, "INVTYPE_SHIELD", { subClassID = 6 })
    local result = c:Verdict(c:Add(3, { [DPS] = 10 }, "INVTYPE_2HWEAPON", { classID = 2, subClassID = 8 }))
    Equal(result.status, "not_upgrade")
    Near(result.baselineScore, 100)
end)
Test("empty baseline has an explicit destination", function()
    local c = Context()
    local result = c:Verdict(c:Add(2, { [STR] = 10 }))
    Equal(result.status, "upgrade")
    Equal(result.destinationSlot, 9)
    Equal(result.baselineScore, 0)
end)
Test("armor-only upgrades are scored with no stat table", function()
    local c = Context()
    c.worn[9] = c:Add(1, nil, nil, { armor = 4 })
    local link = c:Add(2, nil, nil, { armor = 29 })
    Equal(c:Verdict(link).status, "upgrade")
    Near(c:Verdict(link).candidateScore, 0.87)
end)
Test("missing off-hand stats prevent a two-hand verdict", function()
    local c = Context()
    c.worn[17] = c:Add(1, { [STR] = 100 }, "INVTYPE_SHIELD", { subClassID = 6, statError = true })
    Equal(c:Verdict(c:Add(2, { [DPS] = 10 }, "INVTYPE_2HWEAPON", { classID = 2, subClassID = 8 })).status, "unknown")
end)
Test("same-ID rings use the weaker exact slot, not item level", function()
    local c = Context()
    c.worn[11] = c:Add(1, { [STR] = 200 }, "INVTYPE_FINGER", { variant = "a" })
    c.worn[12] = c:Add(1, { [STR] = 100 }, "INVTYPE_FINGER", { variant = "b" })
    local result = c:Verdict(c:Add(2, { [STR] = 110 }, "INVTYPE_FINGER"))
    Equal(result.destinationSlot, 12)
    Near(result.baselineScore, 100)
end)
Test("weapon bonuses modify DPS only", function()
    local c = Context(true, "MAGE")
    c.spells[6057] = true
    local link = c:Add(2, { [DPS] = 10, [INT] = 100 }, "INVTYPE_RANGEDRIGHT", { classID = 2, subClassID = 19 })
    Near(c.weights.Score(link, 18), 100 + 15 * 1.13)
end)
Test("distinct weapon bonuses stack while alternate ranks do not", function()
    local c = Context(true, "HUNTER")
    c.spells[19381], c.spells[19385], c.spells[415320] = true, true, true
    Near(c.weights.WeaponBonusPct(7), 13)
    c.spells[19381], c.spells[19385], c.spells[415320] = nil, nil, nil
    c.spells[13707], c.spells[13969] = true, true
    c.weights.Invalidate()
    Near(c.weights.WeaponBonusPct(13), 5)
end)
Test("missing weapon DPS is unknown, not a required-level upgrade", function()
    local c = Context()
    Equal(c:Verdict(c:Add(2, {}, "INVTYPE_WEAPON", { classID = 2, subClassID = 7 })).status, "unknown")
end)
Test("weapon DPS missing from item stats is read from the tooltip", function()
    local c = Context(true, "HUNTER")
    c.config.gearSwap.advisorEnabled = true
    c.worn[18] = c:Add(1, {}, "INVTYPE_RANGED", { classID = 2, subClassID = 2, dpsText = "1.50" })
    local bow = c:Add(2, {}, "INVTYPE_RANGED", { classID = 2, subClassID = 2, dpsText = "4.62" })
    local result = c:Verdict(bow)
    Equal(result.status, "upgrade")
    Near(result.candidateScore, 4.62 * 5)
    Near(result.baselineScore, 1.5 * 5)
    c:Bag(bow)
    c.advisor.Scan()
    Equal(c.advisor.GetRecommendations()[18].link, bow)
    Near(c.env.JustQuest.Core.GetModule("GameData").ItemDPS(
        c:Add(3, {}, "INVTYPE_RANGED", { classID = 2, subClassID = 2, dpsText = "1.234,5" })), 1234.5)
end)
Test("one-hander replaces two-handed main hand, not empty off-hand", function()
    local c = Context()
    c.dualWield = true
    c.worn[16] = c:Add(1, { [DPS] = 20 }, "INVTYPE_2HWEAPON", { classID = 2, subClassID = 8 })
    local link = c:Add(2, { [DPS] = 10 }, "INVTYPE_WEAPON", { classID = 2, subClassID = 7 })
    Equal(c:Verdict(link).status, "not_upgrade")
    Equal(c:Verdict(link).destinationSlot, 16)
end)
Test("off-hand under a two-hander is an incomplete transition", function()
    local c = Context()
    c.worn[16] = c:Add(1, { [DPS] = 20 }, "INVTYPE_2HWEAPON", { classID = 2, subClassID = 8 })
    Equal(c:Verdict(c:Add(2, { [STR] = 10 }, "INVTYPE_SHIELD", { subClassID = 6 })).status, "unknown")
end)
Test("role change invalidates scores and refreshes junk markers", function()
    local c = Context(true, "PALADIN")
    c.junk.ItemEngine.Initialize()
    local link = c:Add(2, { [STR] = 100, [INT] = 10 })
    Near(c.weights.Score(link, 9), 102.5)
    Equal(c.weights.SetRole("healer"), true)
    Near(c.weights.Score(link, 9), 10)
    Equal(c.markers, 1)
end)
Test("level-up invalidates scaled-item scores", function()
    local c = Gear()
    local link = c:Add(2, { [STR] = 80 })
    Near(c.weights.Score(link, 9), 80)
    c.items[link].stats[STR] = 120
    for _, frame in ipairs(c.frames) do
        if frame.events.PLAYER_LEVEL_UP then frame.handler(frame, "PLAYER_LEVEL_UP", 31) end
    end
    Near(c.weights.Score(link, 9), 120)
end)
Test("advisor uses shared Forever scorer even when Pawn has a scale", function()
    local c = Gear()
    c.config.gearSwap.advisorEnabled = true
    c.env.PawnCommon = { Scales = { generic = {} } }
    c.env.PawnIsScaleVisible = function() return true end
    c.env.PawnGetItemData = function() error("Forever must not use Pawn") end
    c.env.PawnIsItemAnUpgrade = c.env.PawnGetItemData
    local link = c:Add(2, { [STR] = 110 })
    c:Bag(link)
    c.advisor.Scan()
    Equal(c.advisor.GetRecommendations()[9].link, link)
    Equal(c.advisor.GetRecommendations()[9].byClassStats, true)
end)
Test("advisor refreshes a single prompt as more gear arrives and defers it in combat", function()
    local c = Gear()
    c.config.gearSwap.advisorEnabled = true
    c.toastShows, c.toastHides = {}, 0
    c.modules.GearToast = {
        Show = function(info) table.insert(c.toastShows, info) end,
        Hide = function() c.toastHides = c.toastHides + 1 end,
    }

    c:Bag(c:Add(2, { [STR] = 110 }, "INVTYPE_WRIST"))
    c.advisor.Scan()
    Equal(#c.toastShows, 1)
    assert(not c.toastShows[1].head:find("waiting", 1, true))

    c:Bag(c:Add(3, { [STR] = 130 }, "INVTYPE_CHEST"))
    c.advisor.Scan()
    Equal(#c.toastShows, 2)
    assert(c.toastShows[2].head:find("(2 waiting)", 1, true))
    Equal(c.toastShows[2].actions[2].text, "Equip All")
    Equal(c.toastShows[2].quiet, true)

    c.combat = true
    c:FireEvent("PLAYER_REGEN_DISABLED")
    Equal(c.toastHides, 1)
    c.combat = false
    c:FireEvent("PLAYER_REGEN_ENABLED")
    assert(c.timers.gear_advisor_scan, "leaving combat should force a fresh recommendation scan")
    c.timers.gear_advisor_scan()
    Equal(#c.toastShows, 3)
    assert(c.toastShows[3].head:find("(2 waiting)", 1, true))
end)
Test("scan context reuses Forever item validation and selected Pawn scale", function()
    local c = Gear()
    c.worn[9] = c:Add(1, { [STR] = 100, RESISTANCE0_NAME = 1 })
    local tooltips, scaleReads = 0, 0
    local getTooltip = c.env.C_TooltipInfo.GetHyperlink
    c.env.C_TooltipInfo.GetHyperlink = function(link)
        tooltips = tooltips + 1
        return getTooltip(link)
    end
    local pawn = c.modules.PawnScoring
    local getScale = pawn.GetConfiguredForeverScale
    pawn.GetConfiguredForeverScale = function(...)
        scaleReads = scaleReads + 1
        return getScale(...)
    end

    local context = c.scoring.CreateScanContext()
    local stats = { [STR] = 100, RESISTANCE0_NAME = 1 }
    c.scoring.EvaluateItem(c:Add(2, stats), context)
    c.scoring.EvaluateItem(c:Add(3, stats), context)

    Equal(scaleReads, 1)
    Equal(tooltips, 3)
end)
Test("advisor suppresses sub-threshold gain without making it junk", function()
    local c = Gear()
    c.config.gearSwap.advisorEnabled = true
    local link = c:Add(2, { [STR] = 101 })
    c:Bag(link)
    c.advisor.Scan()
    Equal(next(c.advisor.GetRecommendations()), nil)
    Equal(c:Sell(link), false)
end)
Test("equip revalidates stale recommendations", function()
    local c = Gear()
    c.config.gearSwap.advisorEnabled = true
    c:Bag(c:Add(2, { [STR] = 110 }))
    c.advisor.Scan()
    local rec = c.advisor.GetRecommendations()[9]
    c.worn[9] = c:Add(3, { [STR] = 200 })
    Equal(c.advisor.EquipRec(rec, true), false)
    Equal(#c.equipped, 0)
end)
Test("same-ID ring upgrade equips into the actual weaker slot", function()
    local c = Context()
    c.config.gearSwap.advisorEnabled = true
    c.worn[11] = c:Add(1, { [STR] = 100 }, "INVTYPE_FINGER", { variant = "a" })
    c.worn[12] = c:Add(1, { [STR] = 50 }, "INVTYPE_FINGER", { variant = "b" })
    local link = c:Add(1, { [STR] = 75 }, "INVTYPE_FINGER", { variant = "c" })
    c:Bag(link)
    c.advisor.Scan()
    Equal(c.advisor.EquipRec(c.advisor.GetRecommendations()[12], true), true)
    Equal(c.equipped[1].slot, 12)
    Equal(c.worn[11], "item:1:a")
end)
Test("two-hand prompt stat deltas include the displaced off-hand", function()
    local c = Context()
    c.config.gearSwap.advisorEnabled = true
    c.modules.GearToast = { Show = function(info) c.toast = info end }
    c.worn[16] = c:Add(1, { [DPS] = 10 }, "INVTYPE_WEAPON", { classID = 2, subClassID = 7 })
    c.worn[17] = c:Add(2, { [STR] = 20 }, "INVTYPE_SHIELD", { subClassID = 6 })
    c:Bag(c:Add(3, { [DPS] = 20 }, "INVTYPE_2HWEAPON", { classID = 2, subClassID = 8 }))
    c.advisor.Scan()
    assert(c.toast.stats:find("-20", 1, true))
    assert(c.toast.sub:find("also unequips", 1, true))
    assert(c.toast.sub:find("estimated score", 1, true))
end)
Test("reward comparison uses the same package and never item-level fallback", function()
    local c = Gear()
    local link = c:Add(2, { [STR] = 80 }, nil, { ilvl = 500 })
    Equal(c.reward.CompareWithEquipped({ itemLink = link, isEquippable = true, itemLevel = 500 }).isUpgrade, false)
    c.items[link].effect = 46
    Equal(c.reward.CompareWithEquipped({ itemLink = link, isEquippable = true, itemLevel = 500 }).reason,
        "item effects not evaluated")
end)
Test("unknown multi-choice gear rewards require manual selection", function()
    local c = Gear()
    local unknown = c:Add(2, { [STR] = 80 }, nil, { effect = 46 })
    local known = c:Add(3, { [STR] = 120 })
    local choices = {}
    for index, link in ipairs({ unknown, known }) do
        choices[index] = {
            index = index, name = "Test", vendorPrice = 10,
            upgradeInfo = c.reward.CompareWithEquipped({ itemLink = link, isEquippable = true }),
        }
    end
    Equal(c.reward.SelectSmartChoice(choices), nil)
end)
Test("Forever reward ranking does not discard better lighter armor", function()
    local c = Gear()
    local choices = {}
    for index, strength in ipairs({ 120, 110 }) do
        local link = c:Add(index + 1, { [STR] = strength }, nil, { subClassID = index == 1 and 2 or 4 })
        choices[index] = {
            index = index, name = "Test", armorSubclass = index == 1 and 2 or 4,
            upgradeInfo = c.reward.CompareWithEquipped({ itemLink = link, isEquippable = true }),
        }
    end
    Equal(c.reward.SelectSmartChoice(choices), 1)
end)
Test("bag markers and merchant sale share the same verdict", function()
    local c = Gear()
    local slot = c:Bag(c:Add(2, { [STR] = 80 }))
    Equal(c.junk.ItemEngine.ShouldSellBagSlot(0, slot), true)
    c.junk.ItemEngine.ResetSellSession()
    Equal(c.junk.ItemEngine.SellNextItem(), true)
    Equal(c.bags[0][slot], nil)
end)
Test("merchant reevaluates after gear changes", function()
    local c = Gear()
    local link = c:Add(2, { [STR] = 80 })
    local slot = c:Bag(link)
    c.junk.ItemEngine.ResetSellSession()
    c.worn[9] = c:Add(3, { [STR] = 50 })
    Equal(c.junk.ItemEngine.SellNextItem(), false)
    assert(c.bags[0][slot])
end)
Test("manual vendor remains an explicit override", function()
    local c = Gear()
    local link = c:Add(2, { [STR] = 110 })
    c.junkConfig.merchant.forceSellItems[2] = true
    Equal(c:Sell(link), true)
end)
Test("retail armor restriction remains unchanged", function()
    local c = Gear(false)
    Equal(c:Sell(c:Add(2, { [STR] = 110 }, nil, { subClassID = 2, ilvl = 200 })), true)
end)
Test("retail item-level selling does not call Forever provider", function()
    local c = Gear(false)
    c.scoring.EvaluateItem = function() error("unexpected Forever scoring") end
    c.worn[9] = c:Add(1, {}, nil, { subClassID = 4, ilvl = 100 })
    Equal(c:Sell(c:Add(2, {}, nil, { subClassID = 4, ilvl = 80 })), true)
    Equal(c:Sell(c:Add(3, {}, nil, { subClassID = 4, ilvl = 95 })), false)
end)
Test("non-gear category and grey policy are unchanged", function()
    local c = Gear()
    c.scoring.EvaluateItem = function() error("gear scorer should not run") end
    Equal(c:Sell(c:Add(2, {}, "", { classID = 0, quality = 1 })), true)
    Equal(c:Sell(c:Add(3, {}, nil, { quality = 0 })), true)
    c.junkConfig.merchant.sellGreyJunk = false
    Equal(c:Sell(c:Add(4, {}, nil, { quality = 0 })), false)
end)
Test("score text never claims a performance percentage", function()
    local c = Context()
    Equal(c.scoring.FormatUpgrade(0.12, 100), "+12% estimated score")
    Equal(c.scoring.FormatUpgrade(100, 0), "fills an empty score baseline")
end)

Test("shared stat reader copies stats and adds armor without mutating API data", function()
    local c = Context()
    local link = c:Add(2, { [STR] = 10 }, nil, { armor = 25 })
    local stats = c.modules.GameData.ItemStats(link)
    Equal(stats[STR], 10)
    Equal(stats.RESISTANCE0_NAME, 25)
    Equal(c.items[link].stats.RESISTANCE0_NAME, nil)
    stats[STR] = 50
    Equal(c.items[link].stats[STR], 10)
end)
Test("shared stat reader rejects malformed and failed API data explicitly", function()
    local c = Context()
    for index, stats in ipairs({ "invalid", { [STR] = "invalid" }, { [STR] = math.huge } }) do
        Equal(c.modules.GameData.ItemStats(c:Add(index, stats)), nil)
    end
    Equal(c.modules.GameData.ItemStats(c:Add(4, {}, nil, { statError = true })), nil)
    Equal(#c.logs, 4)
end)
Test("shared stat reader keeps missing armor data unknown", function()
    local c = Context()
    local link = c:Add(2, nil, nil, { tooltipMissing = true })
    Equal(c.modules.GameData.ItemStats(link), nil)
    Equal(c:Verdict(link).status, "unknown")
end)
Test("armor-only prompt and scoring use the same shared stats", function()
    local c = Context()
    c.config.gearSwap.advisorEnabled = true
    c.modules.GearToast = { Show = function(info) c.toast = info end }
    c.worn[9] = c:Add(1, nil, nil, { armor = 4 })
    local link = c:Add(2, nil, nil, { armor = 29 })
    c:Bag(link)
    local calls = 0
    local reader = c.modules.GameData.ItemStats
    c.modules.GameData.ItemStats = function(itemLink)
        calls = calls + 1
        return reader(itemLink)
    end
    c.advisor.Scan()
    assert(calls >= 4, "scoring and prompt must both read shared stats")
    assert(c.toast.stats:find("+25", 1, true))
    assert(c.toast.stats:find("Armor", 1, true))
    Near(c:Verdict(link).candidateScore, 0.87)
end)
Test("Forever class weights can score an upgrade with off-role primary stats", function()
    local c = Context(true, "ROGUE")
    c.config.gearSwap.advisorEnabled = true
    c.env.C_SpecializationInfo.GetSpecializationInfo = function()
        return 1, "Rogue", "", 0, "DAMAGER", 4, 4
    end
    c.worn[5] = c:Add(1, { [INT] = 100 }, "INVTYPE_CHEST", { subClassID = 2, armor = 4 })
    local link = c:Add(2, { [INT] = 120 }, "INVTYPE_CHEST", { subClassID = 2, armor = 29 })
    c:Bag(link)

    Equal(c.modules.GameData.ItemIsWrongPrimaryStat(link), false)
    Equal(c:Verdict(link).status, "upgrade")
    c.advisor.Scan()
    Equal(c.advisor.GetRecommendations()[5].link, link)
end)
Test("selected Pawn scale drives Forever recommendations and rewards", function()
    local c = Context(true, "ROGUE")
    local scaleName = "Classic: Rogue: Combat"
    c.config.gearSwap.advisorEnabled = true
    c.env.UnitClass = function() return "Rogue", "ROGUE", 4 end
    c.env.PawnCommon = {
        Scales = {
            [scaleName] = { ClassID = 4, SpecID = 2, LocalizedName = "Rogue: Combat" },
            ["Other class"] = { ClassID = 1, LocalizedName = "Other class" },
        },
    }
    c.env.PawnIsScaleVisible = function(name) return name == scaleName end
    c.env.PawnGetAllScalesEx = function()
        return {
            { Name = scaleName, LocalizedName = "Rogue: Combat", IsVisible = true },
            { Name = "Other class", LocalizedName = "Other class", IsVisible = false },
        }
    end
    c.env.PawnGetItemData = function(link) return { Link = link } end
    c.env.PawnIsItemAnUpgrade = function()
        return { { ScaleName = scaleName, PercentUpgrade = 0.5, ExistingItemLink = c.worn[5] } }
    end

    assert(c.modules.PawnScoring.SetForeverScale(scaleName))
    Equal(c.config.gearSwap.foreverPawnScales["Test-Realm"], scaleName)
    c.env.UnitFullName = function() return "Alt", "Realm" end
    Equal(c.modules.PawnScoring.GetConfiguredForeverScale(), nil)
    c.env.UnitFullName = function() return "Test", "Realm" end
    local options = c.modules.PawnScoring.GetForeverScaleOptions()
    Equal(options[scaleName], "Rogue: Combat (Classic: Rogue: Combat)")
    Equal(options["Other class"], nil)
    c.worn[5] = c:Add(1, { [STR] = 10 }, "INVTYPE_CHEST", { subClassID = 2 })
    local link = c:Add(2, { [STR] = 120 }, "INVTYPE_CHEST", { subClassID = 2 })
    c:Bag(link)
    local specialLink = c:Add(3, { [STR] = 300 }, "INVTYPE_CHEST", { subClassID = 2, effect = 46 })
    c:Bag(specialLink)

    local scaleReads = 0
    local getSelectedScale = c.modules.PawnScoring.GetConfiguredForeverScale
    c.modules.PawnScoring.GetConfiguredForeverScale = function(...)
        scaleReads = scaleReads + 1
        return getSelectedScale(...)
    end
    c.advisor.Scan()
    Equal(scaleReads, 1)
    Equal(c.advisor.GetRecommendations()[5].link, link)
    Equal(c:Sell(link), false)
    Equal(c:Sell(specialLink), false)
    local reward = c.reward.CompareWithEquipped({
        itemLink = link, isEquippable = true, equipSlot = "INVTYPE_CHEST", itemLevel = 1,
    })
    Equal(reward.reason, "pawn_upgrade")
end)
local function ArmorPawnContext()
    local c = Context(true, "ROGUE")
    c.config.gearSwap.advisorEnabled = true
    c.env.PawnCommon = { Scales = { armorless = { ClassID = 1 } } }
    c.env.PawnIsScaleVisible = function() return true end
    c.env.PawnGetItemData = function(link) return { Link = link } end
    c.env.PawnIsItemAnUpgrade = function()
        return nil, nil, { armorless = {} }
    end
    assert(c.modules.PawnScoring.SetForeverScale("armorless"))
    return c
end
Test("selected Pawn scale still recommends armor-only upgrades", function()
    local c = ArmorPawnContext()
    c.worn[9] = c:Add(1, nil, nil, { armor = 4 })
    local link = c:Add(2, nil, nil, { armor = 29 })
    c:Bag(link)
    local result = c:Verdict(link)
    Equal(result.status, "upgrade")
    Equal(result.byClassStats, true)
    Near(result.pawnPercentUpgrade, 6.25)
    c.advisor.Scan()
    Equal(c.advisor.GetRecommendations()[9].link, link)
    Equal(c:Sell(link), false)
    Equal(c.reward.CompareWithEquipped({
        itemLink = link, isEquippable = true, equipSlot = "INVTYPE_WRIST", itemLevel = 1,
    }).isUpgrade, true)
end)
Test("armor-only Pawn fallback handles empty slots, ties, and downgrades", function()
    local c = ArmorPawnContext()
    local link = c:Add(2, {}, nil, { armor = 29 })
    Equal(c:Verdict(link).status, "upgrade")
    Equal(c:Verdict(link).destinationSlot, 9)
    for _, armor in ipairs({ 29, 40 }) do
        c.worn[9] = c:Add(armor, {}, nil, { armor = armor })
        Equal(c:Verdict(link).status, "not_upgrade")
    end
end)
Test("armor fallback never overrides Pawn for stat trade-offs", function()
    for _, candidateHasStats in ipairs({ false, true }) do
        local c = ArmorPawnContext()
        c.worn[9] = c:Add(1, not candidateHasStats and { [STR] = 1 } or {}, nil, { armor = 4 })
        local link = c:Add(2, candidateHasStats and { [STR] = 1 } or {}, nil, { armor = 29 })
        local result = c:Verdict(link)
        Equal(result.status, "not_upgrade")
        Equal(result.byPawnScale, true)
    end
end)
Test("armor fallback preserves effect and missing-data protections", function()
    local c = ArmorPawnContext()
    c.worn[9] = c:Add(1, {}, nil, { armor = 4 })
    for id, options in ipairs({
        { armor = 29, effect = 46 }, { armor = 29, tooltipMissing = true },
    }) do
        Equal(c:Verdict(c:Add(id + 1, {}, nil, options)).status, "unknown")
    end
    local link = c:Add(4, {}, nil, { armor = 29 })
    c.items[c.worn[9]].effect = 46
    Equal(c:Verdict(link).status, "unknown")
end)
Test("advisor and scorer resolve destinations through shared slot rules", function()
    local c = Context()
    c.config.gearSwap.advisorEnabled = true
    local slots = c.modules.GameData.ComparableSlots
    c.modules.GameData.ComparableSlots = function(invType)
        if invType == "INVTYPE_WRIST" then return { 10 } end
        return slots(invType)
    end
    local link = c:Add(2, { [STR] = 110 })
    c:Bag(link)
    Equal(c:Verdict(link).destinationSlot, 10)
    c.advisor.Scan()
    Equal(c.advisor.GetRecommendations()[10].link, link)
    Equal(c.advisor.GetRecommendations()[9], nil)
end)
Test("shared slot rules never replace a shield with a generic one-hander", function()
    for _, forever in ipairs({ true, false }) do
        local c = Context(forever)
        c.config.gearSwap.advisorEnabled = true
        c.dualWield = true
        c.worn[16] = c:Add(1, { [DPS] = 10 }, "INVTYPE_WEAPON", { classID = 2, subClassID = 7, ilvl = 10 })
        c.worn[17] = c:Add(2, { [STR] = 1 }, "INVTYPE_SHIELD", { subClassID = 6, ilvl = 1 })
        local link = c:Add(3, { [DPS] = 20 }, "INVTYPE_WEAPON", { classID = 2, subClassID = 7, ilvl = 20 })
        c:Bag(link)
        c.advisor.Scan()
        Equal(c.advisor.GetRecommendations()[16].link, link)
        Equal(c.advisor.GetRecommendations()[17], nil)
    end
end)
Test("advisor still excludes trinkets and cosmetics on both clients", function()
    for _, forever in ipairs({ true, false }) do
        local c = Context(forever)
        c.config.gearSwap.advisorEnabled = true
        for index, invType in ipairs({ "INVTYPE_TRINKET", "INVTYPE_BODY", "INVTYPE_TABARD" }) do
            c:Bag(c:Add(index, { [STR] = 100 }, invType))
        end
        c.advisor.Scan()
        Equal(next(c.advisor.GetRecommendations()), nil)
    end
end)
Test("scoring lifecycle invalidates and refreshes markers without an advisor", function()
    for _, event in ipairs({ "PLAYER_LEVEL_UP", "LEARNED_SPELL_IN_SKILL_LINE",
                              "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE" }) do
        local c = Context(true, "WARRIOR", true)
        c.junk.ItemEngine.Initialize()
        local link = c:Add(2, { [STR] = 80 })
        Near(c.weights.Score(link, 9), 80)
        c.items[link].stats[STR] = 120
        c:FireEvent(event)
        Near(c.weights.Score(link, 9), 120)
        Equal(c.markers, 1)
        Equal(c.modules.GearAdvisor, nil)
    end
end)
Test("role-change notification preserves advisor rescan behavior", function()
    local c = Context(true, "PALADIN")
    c.config.gearSwap.advisorEnabled = true
    local link = c:Add(2, { [INT] = 100 })
    c:Bag(link)
    c.advisor.Scan()
    c.advisor.DismissAll()
    Equal(next(c.advisor.GetRecommendations()), nil)
    c.weights.SetRole("healer")
    assert(c.timers.gear_advisor_scan, "role change must schedule a rescan")
    c.timers.gear_advisor_scan()
    Equal(c.advisor.GetRecommendations()[9].link, link)
end)
Test("talent events invalidate weapon bonuses without duplicate consumer refreshes", function()
    local c = Context(true, "MAGE")
    c.junk.ItemEngine.Initialize()
    local link = c:Add(2, { [DPS] = 10 }, "INVTYPE_RANGEDRIGHT", { classID = 2, subClassID = 19 })
    Near(c.weights.Score(link, 18), 15)
    c.spells[6057] = true
    c:FireEvent("PLAYER_TALENT_UPDATE")
    Near(c.weights.Score(link, 18), 15 * 1.13)
    Equal(c.markers, 1)
end)
Test("retail level-up still refreshes advisor usability without Forever events", function()
    local c = Context(false)
    c.config.gearSwap.advisorEnabled = true
    local link = c:Add(2, { [STR] = 100 }, nil, { reqLevel = 31, ilvl = 10, subClassID = 4 })
    c:Bag(link)
    c.advisor.Scan()
    Equal(next(c.advisor.GetRecommendations()), nil)
    c.level = 31
    c:FireEvent("PLAYER_LEVEL_UP", 31)
    c.timers.gear_advisor_scan()
    Equal(c.advisor.GetRecommendations()[9].link, link)
    Equal(c.markers, 0)
end)
Test("scoring notification clears advisor usability cache after training", function()
    local c = Context()
    c.config.gearSwap.advisorEnabled = true
    c.proficiencies[750] = false
    local link = c:Add(2, { [STR] = 100 }, nil, { subClassID = 4 })
    c:Bag(link)
    c.advisor.Scan()
    Equal(next(c.advisor.GetRecommendations()), nil)
    c.proficiencies[750] = true
    c:FireEvent("LEARNED_SPELL_IN_SKILL_LINE")
    c.timers.gear_advisor_scan()
    Equal(c.advisor.GetRecommendations()[9].link, link)
end)
Test("unknown verdicts explicitly distinguish retryable data from unsupported effects", function()
    local c = Context()
    Equal(c:Verdict(c:Add(1, {}, nil, { uncached = true })).retryable, true)
    Equal(c:Verdict(c:Add(2, {}, nil, { tooltipMissing = true })).retryable, true)
    Equal(c:Verdict(c:Add(3, {}, nil, { effect = 46 })).retryable, false)
    Equal(c:Verdict(c:Add(4, {}, "INVTYPE_TRINKET")).retryable, false)
end)
Test("advisor retry decisions do not depend on diagnostic wording", function()
    for _, retryable in ipairs({ true, false }) do
        local c = Context()
        c.config.gearSwap.advisorEnabled = true
        c:Bag(c:Add(2, { [STR] = 100 }))
        c.scoring.EvaluateItem = function()
            return { status = "unknown", reason = retryable and "waiting" or "unavailable", retryable = retryable }
        end
        c.advisor.Scan()
        Equal(c.timers.gear_advisor_settle ~= nil, retryable)
    end
end)

print(string.format("%d regression tests passed", count))
return count
