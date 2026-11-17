-- Run in Lua 5.1: loadfile(thisFile)(justQuestRoot).
local root = ...
assert(root, "Pass the JustQuest addon root")

local function Context(forever)
    local c = { items = {}, selected = {}, halted = {}, choices = 2, now = 100, timers = {} }
    local e = setmetatable({}, { __index = _G })
    local modules, ns = {}, { Core = {}, _stats = {} }
    c.env = e
    e._G = e
    e.WOW_PROJECT_CAMELOT = 99
    e.WOW_PROJECT_ID = forever == false and 1 or 99
    e.GetTime = function() return c.now end
    e.UnitLevel = function() return 30 end
    e.GetNumQuestChoices = function() return c.choices end
    e.GetQuestItemInfoLootType = function(_, i) return c.items[i].lootType or 0 end
    e.GetQuestItemLink = function(_, i)
        if c.items[i].noLink then return nil end
        return "item:" .. (c.items[i].itemID or i)
    end
    e.GetQuestItemInfo = function() return "Test" end
    e.GetQuestMoneyToGet = function() return c.payment or 0 end
    e.GetQuestReward = function(index) table.insert(c.selected, index or 0) end
    e.QuestFrameRewardPanel = { IsShown = function() return true end }
    e.Enum = { TooltipDataLineType = {
        ItemSpellTriggerOnUse = 44, ItemSpellTriggerOnEquip = 45, ItemSpellTriggerOnProc = 46,
    } }
    local function Item(link)
        local id = tonumber(link:match("item:(%d+)"))
        for index, item in pairs(c.items) do
            if (item.itemID or index) == id then return item end
        end
    end
    e.C_Item = {
        GetItemInfo = function(link)
            local i = Item(link)
            if not i or i.uncached then return nil end
            return i.name or "Test", link, i.quality, 1, i.reqLevel or 0, "", "", 1,
                i.slot, 0, i.price, i.class, i.subclass or 0, 1
        end,
        GetItemSpell = function(link)
            local item = Item(link)
            return item.spell, item.spellID
        end,
    }
    e.C_TooltipInfo = { GetHyperlink = function(link)
        local i = Item(link)
        if i.noTooltip then return nil end
        return { lines = { { type = i.effect or 22, leftText = "Test" } } }
    end }
    ns.Core.GetModule = function(name) return modules[name] end
    ns.Core.ModuleGetter = function(name) return function() return modules[name] end end
    ns.Core.RegisterModule = function(name, mod) modules[name] = mod end
    local function Load(path)
        local chunk = assert(loadfile(root .. "\\" .. path))
        setfenv(chunk, e)
        return chunk("JustQuest", ns)
    end
    Load("Core\\Constants.lua")
    c.config = ns.Constants.DEFAULTS.profile
    c.config.quest.autoReward = true
    modules.Config = { Get = function(group, key) return c.config[group][key] end }
    modules.Services = {
        ValidateAutomationPreconditions = function() return true end,
        Debug = function() end,
        OutputHalt = function(reason) table.insert(c.halted, reason) end,
        SafeCall = function(fn, ...) return fn(...) end,
        GetItemIDFromLink = function(link) return tonumber(link:match("item:(%d+)")) end,
        CancelScheduled = function(key) c.timers[key] = nil end,
        ScheduleOnce = function(key, _, fn) c.timers[key] = fn end,
    }
    modules.SafetyEngine = { EndProcessing = function(reason) c.reason = reason end }
    c.data = Load("Services\\GameData.lua")
    c.data.CanPlayerUseItem = function(link) return Item(link).usable ~= false end
    c.data.FormatMoney = tostring
    c.reward = Load("Engines\\RewardEngine.lua")
    function c:Add(index, options)
        local i = { class = 0, quality = 1, slot = "", price = index * 100 }
        for key, value in pairs(options or {}) do i[key] = value end
        self.items[index] = i
    end
    c:Add(1)
    c:Add(2)
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

for _, simple in ipairs({ false, true }) do
    for _, quality in ipairs({ 1, 2, 3 }) do
        Test("recipe protected at quality " .. quality .. ", simple=" .. tostring(simple), function()
            local c = Context()
            c.config.quest.simpleRewardMode = simple
            c:Add(1, { class = 9, quality = quality, price = 0, usable = false })
            Equal(c.reward.AllRewardsTrivial(2), false)
            c.reward.ProcessQuestReward(true)
            Equal(#c.selected, 0)
            Equal(c.reason, "special_reward_choice")
        end)
    end
end
for _, options in ipairs({
    { class = 0, spell = "Learn a profession" },
    { class = 7, spell = "Increase skill" },
    { class = 0, effect = 44 },
    { class = 7, effect = 45 },
    { class = 0, effect = 46 },
    { class = 15 }, { class = 12 }, { class = 1 }, { class = 19, slot = "INVTYPE_HEAD" },
    { class = 0, quality = 5 }, { class = 0, noTooltip = true },
}) do
    Test("special category or utility effect is protected " .. (count + 1), function()
        local c = Context()
        c.config.quest.simpleRewardMode = true
        c:Add(1, options)
        c.reward.ProcessQuestReward(true)
        Equal(#c.selected, 0)
        Equal(c.reason, "special_reward_choice")
    end)
end
Test("missing effect enums require manual review", function()
    local c = Context()
    c.env.Enum.TooltipDataLineType = nil
    c.reward.ProcessQuestReward(true)
    Equal(c.reason, "special_reward_choice")
    Equal(#c.selected, 0)
end)
Test("missing effect API requires manual review", function()
    local c = Context()
    c.env.C_Item.GetItemSpell = nil
    c.reward.ProcessQuestReward(true)
    Equal(c.reason, "special_reward_choice")
end)
Test("currency mixed with an item is never compared by vendor value", function()
    local c = Context()
    c:Add(1, { lootType = 1 })
    c.config.quest.simpleRewardMode = true
    c.reward.ProcessQuestReward(true)
    Equal(#c.selected, 0)
    Equal(c.reason, "special_reward_choice")
end)
Test("final action boundary rejects special alternatives", function()
    local c = Context()
    c:Add(1, { class = 9 })
    c.reward.SelectReward(2)
    Equal(#c.selected, 0)
    Equal(c.reason, "special_reward_choice")
end)
Test("smart analysis does not filter out an unusable tome before review", function()
    local c = Context()
    c:Add(1, { class = 9, quality = 3, usable = false })
    local choices = c.reward.AnalyzeRewardChoices(2)
    assert(choices[1].manualReviewReason)
    Equal(choices[1].canUse, false)
    Equal(c.reward.SelectSmartChoice(choices), nil)
end)
Test("special choice takes precedence over unknown collectible auto-pick", function()
    local c = Context()
    Equal(c.reward.SelectSmartChoice({
        { index = 1, isCollectible = true, isCollectibleKnown = false },
        { index = 2, canUse = false, manualReviewReason = "recipe" },
    }), nil)
end)
for _, simple in ipairs({ false, true }) do
    Test("ordinary vendor ranking still works, simple=" .. tostring(simple), function()
        local c = Context()
        c.config.quest.simpleRewardMode = simple
        c:Add(1, { class = 7 })
        c.reward.ProcessQuestReward(true)
        Equal(c.selected[1], 2)
    end)
    Test("ordinary rare non-gear still supports smart ranking, simple=" .. tostring(simple), function()
        local c = Context()
        c.config.quest.simpleRewardMode = simple
        c:Add(1, { class = 7, quality = 3 })
        c.reward.ProcessQuestReward(true)
        Equal(c.selected[1], 2)
    end)
end
Test("unloaded reward waits and eventually halts without choosing", function()
    local c = Context()
    c:Add(1, { class = 9, uncached = true })
    c.reward.ProcessQuestReward(true)
    Equal(#c.selected, 0)
    assert(c.timers.reward_data_retry)
    c.now = c.now + 2
    c.timers.reward_data_retry()
    Equal(c.reason, "reward_items_not_loaded")
end)
Test("manual halt releases the guard for the next ordinary quest", function()
    local c = Context()
    c:Add(1, { class = 9 })
    c.reward.ProcessQuestReward(true)
    Equal(#c.selected, 0)
    c:Add(1)
    c.reward.ProcessQuestReward(true)
    Equal(c.selected[1], 2)
end)
Test("uncached link is not a vendor fallback", function()
    local c = Context()
    c:Add(1, { noLink = true })
    c.reward.SelectReward(2)
    Equal(#c.selected, 0)
    Equal(c.reason, "special_reward_choice")
end)
Test("ordinary gear preserves simple-mode vendor ranking", function()
    local c = Context()
    c.config.quest.simpleRewardMode = true
    c:Add(1, { class = 4, quality = 2, slot = "INVTYPE_WRIST", noTooltip = true })
    c:Add(2, { class = 2, quality = 3, slot = "INVTYPE_WEAPON", spell = "Weapon effect" })
    c.reward.ProcessQuestReward(true)
    Equal(c.selected[1], 2)
end)
Test("above-level profession recipe is still protected", function()
    local c = Context()
    c:Add(1, { class = 9, reqLevel = 60, usable = false })
    c.reward.ProcessQuestReward(true)
    Equal(#c.selected, 0)
    Equal(c.reason, "special_reward_choice")
end)
Test("final guard catches reward changes after analysis", function()
    local c = Context()
    Equal(c.reward.RequiresManualReview(2), false)
    c:Add(1, { class = 9 })
    c.reward.SelectReward(2)
    Equal(#c.selected, 0)
end)
Test("disabled multi-choice automation still leaves the choice untouched", function()
    local c = Context()
    c.config.quest.autoReward = false
    c:Add(1, { class = 9 })
    c.reward.ProcessQuestReward(true)
    Equal(#c.selected, 0)
    Equal(c.reason, "auto_reward_disabled")
end)
for _, forever in ipairs({ true, false }) do
    Test("single special reward preserves automatic claim, Forever=" .. tostring(forever), function()
        local c = Context(forever)
        c.choices = 1
        c.config.quest.autoReward = false
        c:Add(1, { class = 9 })
        c.reward.ProcessQuestReward(true)
        Equal(c.selected[1], 1)
    end)
    Test("multi-choice recipe protection applies, Forever=" .. tostring(forever), function()
        local c = Context(forever)
        c:Add(1, { class = 9 })
        c.reward.ProcessQuestReward(true)
        Equal(#c.selected, 0)
        Equal(c.reason, "special_reward_choice")
    end)
end
Test("guaranteed-only rewards are still claimed", function()
    local c = Context()
    c.choices = 0
    c.reward.ProcessQuestReward(true)
    Equal(c.selected[1], 0)
end)
Test("single-choice payment guard is unchanged", function()
    local c = Context()
    c.choices, c.payment = 1, 100
    c.reward.ProcessQuestReward(true)
    Equal(#c.selected, 0)
    Equal(c.reason, "expensive_quest_requires_payment")
end)

-- Item/ItemXItemEffect/ItemEffect joins, Forever 1.60.1.70790, wago.tools/db2.
-- These fixtures pin real classifications and use-spell IDs, not inferred spell knowledge.
local FOREVER_EXAMPLES = {
    { itemID = 16084, name = "Expert First Aid - Under Wraps", class = 9, subclass = 7,
      spellID = 19903, reason = "recipe or learning book" },
    { itemID = 16072, name = "Expert Cookbook", class = 9, subclass = 5,
      spellID = 19886, reason = "recipe or learning book" },
    { itemID = 17062, name = "Recipe: Mithril Head Trout", class = 9, subclass = 5,
      spellID = 402265, reason = "recipe or learning book" },
    { itemID = 858, name = "Lesser Healing Potion", class = 0, subclass = 1,
      spellID = 440 },
    { itemID = 1251, name = "Linen Bandage", class = 0, subclass = 7,
      spellID = 746 },
    { itemID = 4540, name = "Tough Hunk of Bread", class = 0, subclass = 5,
      spellID = 433 },
}
for _, example in ipairs(FOREVER_EXAMPLES) do
    Test("verified Forever reward classification: " .. example.itemID, function()
        local c = Context()
        c:Add(1, example)
        c.items[1].spell = "Localized use-spell name"
        c.items[1].effect = 44
        local link = c.env.GetQuestItemLink("choice", 1)
        Equal(c.data.RewardReviewReason(link), example.reason)
        c.config.quest.simpleRewardMode = true
        c.reward.ProcessQuestReward(true)
        if example.reason then
            Equal(#c.selected, 0)
            Equal(c.reason, "special_reward_choice")
        else
            Equal(c.selected[1], 2)
        end
    end)
end
Test("knowing a recipe's shared teaching spell does not authorize vendor ranking", function()
    local c = Context()
    c:Add(1, FOREVER_EXAMPLES[3])
    c.items[1].spell = "Shared teaching spell"
    -- Item 17062 uses spell 402265; its separate TriggerType 6 entry names recipe 20916.
    c.env.C_SpellBook = { IsSpellKnown = function(id) return id == 402265 end }
    c.reward.ProcessQuestReward(true)
    Equal(#c.selected, 0)
    Equal(c.reason, "special_reward_choice")
end)

for _, example in ipairs({ FOREVER_EXAMPLES[4], FOREVER_EXAMPLES[5], FOREVER_EXAMPLES[6] }) do
    Test("verified consumable works in smart mode: " .. example.itemID, function()
        local c = Context()
        c:Add(1, example)
        c.items[1].spell, c.items[1].effect = "Localized use", 44
        c.reward.ProcessQuestReward(true)
        Equal(c.selected[1], 2)
    end)
    Test("verified consumable remains manual on retail: " .. example.itemID, function()
        local c = Context(false)
        c:Add(1, example)
        c.items[1].spell, c.items[1].effect = "Localized use", 44
        c.reward.ProcessQuestReward(true)
        Equal(#c.selected, 0)
        Equal(c.reason, "special_reward_choice")
    end)
end
for _, change in ipairs({
    { key = "spellID", value = 19903 },
    { key = "spellID", value = false },
    { key = "subclass", value = 8 },
    { key = "quality", value = 2 },
    { key = "class", value = 7 },
    { key = "class", value = 9 },
    { key = "itemID", value = 999858 },
    { key = "noTooltip", value = true },
    { key = "effect", value = 45 },
    { key = "effect", value = 46 },
}) do
    Test("consumable exception rejects changed data: " .. change.key .. "=" .. tostring(change.value), function()
        local c = Context()
        c:Add(1, FOREVER_EXAMPLES[4])
        c.items[1].spell, c.items[1].effect = "Localized use", 44
        c.items[1][change.key] = change.value
        c.reward.ProcessQuestReward(true)
        Equal(#c.selected, 0)
        Equal(c.reason, "special_reward_choice")
    end)
end
Test("verified consumable still requires effect enums", function()
    local c = Context()
    c:Add(1, FOREVER_EXAMPLES[4])
    c.items[1].spell = "Localized use"
    c.env.Enum.TooltipDataLineType = nil
    c.reward.ProcessQuestReward(true)
    Equal(c.reason, "special_reward_choice")
end)
Test("verified consumable does not override a recipe alternative", function()
    local c = Context()
    c:Add(1, FOREVER_EXAMPLES[4])
    c.items[1].spell = "Localized use"
    c:Add(2, FOREVER_EXAMPLES[1])
    c.reward.ProcessQuestReward(true)
    Equal(#c.selected, 0)
    Equal(c.reason, "special_reward_choice")
end)

print(string.format("%d reward safety tests passed", count))
return count
