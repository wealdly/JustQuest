-- Verifies the gear rules that differ between retail and WoW Forever, by loading the REAL
-- Core/Constants.lua and Services/GameData.lua twice — once as each client — against stubs:
--
--   * where ranged weapons go (main hand on retail; Forever's ranged slot also takes thrown
--     weapons and relics)
--   * armour type follows TRAINING on Forever (leather / mail until Mail / Plate Mail is learned
--     at 40), and is fixed on retail
--   * the Forever class stat rule (no spec there names a primary stat)
--   * a one-hander only competes for the off-hand when you can dual wield and it holds a weapon
--
-- Run from the addon root (matching the syntax checker's interpreter):
--     python -c "import lupa.lua54 as l; l.LuaRuntime().execute(open('tools/gear_forever_check.lua', encoding='utf-8').read())"

local failures = 0
local function check(name, got, want)
    if got ~= want then
        print(string.format("FAIL %s: got %s, want %s", name, tostring(got), tostring(want)))
        failures = failures + 1
    end
end

-- ---------------------------------------------------------------- stubs
local class, known, dualWield = "HUNTER", {}, false
local equipped = {}            -- slot -> fake link
local ITEMS = {                -- fake link -> { invType, classID, subclassID, ilvl, stats }
    leatherChest = { "INVTYPE_CHEST", 4, 2, 20 },
    mailChest    = { "INVTYPE_CHEST", 4, 3, 22 },
    plateChest   = { "INVTYPE_CHEST", 4, 4, 22 },
    sword        = { "INVTYPE_WEAPON", 2, 7, 20 },
    shield       = { "INVTYPE_SHIELD", 4, 6, 5 },
    frill        = { "INVTYPE_HOLDABLE", 4, 0, 5 },
    intRing      = { "INVTYPE_FINGER", 4, 0, 20, { ITEM_MOD_INTELLECT_SHORT = 5 } },
    strIntRing   = { "INVTYPE_FINGER", 4, 0, 20, { ITEM_MOD_STRENGTH_SHORT = 3, ITEM_MOD_INTELLECT_SHORT = 3 } },
    staminaCloak = { "INVTYPE_CLOAK", 4, 1, 20, { ITEM_MOD_STAMINA_SHORT = 5 } },
    strMace      = { "INVTYPE_WEAPON", 2, 4, 20, { ITEM_MOD_STRENGTH_SHORT = 5 } },
    intStaff     = { "INVTYPE_2HWEAPON", 2, 10, 20, { ITEM_MOD_INTELLECT_SHORT = 5 } },
}
UnitClass = function() return "x", class end
IsPlayerSpell = function(id) return known[id] or false end
CanDualWield = function() return dualWield end
GetInventoryItemLink = function(_, slot) return equipped[slot] end
GetSpecialization = function() return nil end   -- Forever-like: no spec primary stat
-- ClassWeights registers its invalidation events on Forever at load; nothing fires them here.
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function() end }
end
C_Item = {
    GetItemInfoInstant = function(link)
        local i = ITEMS[link]; if not i then return nil end
        return tonumber(link:match("item:(%d+)")) or 1, "t", "s", i[1], 0, i[2], i[3]
    end,
    -- Like the real thing: NOTHING for an item with no stats, and base armour is never a stat.
    GetItemStats = function(link) return ITEMS[link] and ITEMS[link][5] or nil end,
    GetDetailedItemLevelInfo = function(link) return ITEMS[link] and ITEMS[link][4] end,
}

-- The Forever scorer only scores gear it can prove has no use/equip/proc effect; without these
-- it keeps the item ("effect detection unavailable"). Test items carry no effects.
Enum = Enum or {}
Enum.TooltipDataLineType = { ItemSpellTriggerOnUse = 30, ItemSpellTriggerOnEquip = 31,
                             ItemSpellTriggerOnProc = 32 }
C_Item.GetItemSpell = function() return nil end

-- A config stub that honours module/key (roles are stored through it).
local store = {}
local configStub = {
    Get = function(module, key) return store[(module or "") .. "." .. key] end,
    Set = function(module, key, value) store[(module or "") .. "." .. key] = value end,
}
local charName = "Tester"
UnitFullName = function() return charName, "Realm" end
C_Item.GetItemInfo = function(link)
    local i = ITEMS[link]; if not i then return nil end   -- unknown = not cached
    return "n", link, 2, 1, i.req or 0
end
-- Armour comes off the tooltip ("29 Armor"); tooltipPending simulates data not loaded yet.
local tooltipPending = false
C_TooltipInfo = { GetHyperlink = function(link)
    if tooltipPending then return nil end
    local i = ITEMS[link]; if not i then return nil end
    local lines = { { leftText = "Bracers of Testing" } }
    if i.armor then lines[#lines + 1] = { leftText = i.armor .. " Armor" } end
    return { lines = lines }
end }

-- Each load makes its own modules; capture them through RegisterModule.
local function Load(forever, extraFiles, extraModules)
    local modules = { Config = configStub }
    for k, v in pairs(extraModules or {}) do modules[k] = v end
    WOW_PROJECT_CAMELOT = forever and 18 or nil
    WOW_PROJECT_ID = forever and 18 or 1
    local ns = { Core = {
        GetModule = function(name) return modules[name] end,
        ModuleGetter = function(name) return function() return modules[name] end end,
        RegisterModule = function(name, m) modules[name] = m end,
    } }
    local files = { "Core/Constants.lua", "Services/GameData.lua", "Services/ClassWeights.lua" }
    for _, extra in ipairs(extraFiles or {}) do files[#files + 1] = extra end
    for _, path in ipairs(files) do
        local f = assert(io.open(path, "r")); local src = f:read("a"); f:close()
        assert(load(src, "@" .. path))("JustQuest", ns)
    end
    return ns, modules.GameData, modules.ClassWeights, modules
end

-- ---------------------------------------------------------------- retail
do
    local ns, GD = Load(false)
    local C = ns.Constants
    check("retail: not Forever", C.IS_FOREVER, false)
    check("retail: ranged weapons are main-hand", C.RANGED_SLOT, 16)
    check("retail: guns/wands map to main hand", C.EQUIPMENT_SLOTS.INVTYPE_RANGEDRIGHT, 16)
    check("retail: no thrown slot", C.EQUIPMENT_SLOTS.INVTYPE_THROWN, nil)
    class, known = "HUNTER", {}
    check("retail: hunter in leather is the wrong type", GD.ItemIsWrongArmorType("leatherChest"), true)
    check("retail: hunter in mail is right", GD.ItemIsWrongArmorType("mailChest"), false)
    check("retail: no spec primary stat -> no stat opinion", GD.ItemIsWrongPrimaryStat("intRing"), false)
end

-- ---------------------------------------------------------------- Forever
local ns, GD, CW = Load(true)
local C = ns.Constants
check("Forever: detected", C.IS_FOREVER, true)
check("Forever: ranged slot", C.RANGED_SLOT, 18)
check("Forever: guns/wands -> ranged slot", C.EQUIPMENT_SLOTS.INVTYPE_RANGEDRIGHT, 18)
check("Forever: thrown -> ranged slot", C.EQUIPMENT_SLOTS.INVTYPE_THROWN, 18)
check("Forever: relics -> ranged slot", C.EQUIPMENT_SLOTS.INVTYPE_RELIC, 18)

-- No armour-type rule on Forever: vanilla has no armour-specialization bonus, and the score
-- already counts armour.
class = "WARRIOR"
check("Forever warrior: leather isn't 'wrong'", GD.ItemIsWrongArmorType("leatherChest"), false)
class = "HUNTER"
check("Forever hunter: mail isn't 'wrong'", GD.ItemIsWrongArmorType("mailChest"), false)

-- Armour value off the tooltip.
ITEMS.thousand = { "INVTYPE_CHEST", 4, 4, 1, nil, armor = "1,234" }
check("tooltip armour, thousands separator", GD.ItemArmor("thousand"), 1234)
ITEMS.noArmorLine = { "INVTYPE_NECK", 4, 0, 1 }
check("no armour line -> 0", GD.ItemArmor("noArmorLine"), 0)
tooltipPending = true
check("tooltip not ready -> nil", GD.ItemArmor("thousand"), nil)
tooltipPending = false

-- Class stat rule: Forever has none. Off-role primary stats are scored by the class/role weights
-- (or the selected Pawn scale) instead of being rejected outright; see Tests/ForeverGearScoring.lua.
class = "WARRIOR"
check("warrior: Intellect-only ring isn't rejected on Forever", GD.ItemIsWrongPrimaryStat("intRing"), false)
check("warrior: Strength+Intellect ring is fine", GD.ItemIsWrongPrimaryStat("strIntRing"), false)
check("warrior: no-primary cloak is fine", GD.ItemIsWrongPrimaryStat("staminaCloak"), false)
class = "MAGE"
check("mage: Strength mace isn't rejected on Forever", GD.ItemIsWrongPrimaryStat("strMace"), false)
check("mage: Intellect staff is fine", GD.ItemIsWrongPrimaryStat("intStaff"), false)
class = "PALADIN"
check("paladin (hybrid): Intellect is fine", GD.ItemIsWrongPrimaryStat("intRing"), false)
check("paladin (hybrid): Strength is fine", GD.ItemIsWrongPrimaryStat("strMace"), false)

-- One-handers and the off-hand.
dualWield, equipped = false, { [16] = "sword", [17] = "frill" }
check("can't dual wield: one-hander is main-hand only", GD.OneHanderFitsOffHand(), false)
check("...so it's compared with the main hand, not the frill", GD.GetCurrentEquippedLevel("INVTYPE_WEAPON"), 20)
dualWield, equipped = false, { [16] = "sword" }
check("can't dual wield, empty off-hand: still main-hand only", GD.OneHanderFitsOffHand(), false)
dualWield, equipped = true, { [16] = "sword", [17] = "shield" }
check("dual wielder with a shield: shield isn't a weaker weapon", GD.OneHanderFitsOffHand(), false)
dualWield, equipped = true, { [16] = "sword" }
check("dual wielder, empty off-hand: competes", GD.OneHanderFitsOffHand(), true)
dualWield, equipped = true, { [16] = "sword", [17] = "sword" }
check("dual wielder, weapon off-hand: competes", GD.OneHanderFitsOffHand(), true)

-- ---------------------------------------------------------------- class weights (ClassWeights.lua)
check("Forever: class weights active", CW.IsActive(), true)
local function Item(name, invType, stats, req)
    ITEMS[name] = { invType, 4, 0, 1, stats, req = req }
end
Item("strBelt",   "INVTYPE_WAIST", { ITEM_MOD_STRENGTH_SHORT = 10 })
Item("intBelt",   "INVTYPE_WAIST", { ITEM_MOD_INTELLECT_SHORT = 10 })
Item("tankBelt",  "INVTYPE_WAIST", { ITEM_MOD_STAMINA_SHORT = 10, RESISTANCE0_NAME = 120 })
Item("fireBelt",  "INVTYPE_WAIST", { ITEM_MOD_SPELL_DAMAGE_FIRE_SHORT = 10 })    -- school damage, name-matched
Item("shadowBelt","INVTYPE_WAIST", { ITEM_MOD_SPELL_DAMAGE_SHADOW_SHORT = 10 })
Item("fireResBelt","INVTYPE_WAIST", { RESISTANCE2_NAME = 10, FIRE_RESISTANCE_SHORT = 10 })
Item("bow",       "INVTYPE_RANGED", { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 })
Item("dagger",    "INVTYPE_WEAPON", { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 })
Item("greyLow",   "INVTYPE_WAIST", {}, 5)
Item("greyHigh",  "INVTYPE_WAIST", {}, 20)
Item("bigTwoHander", "INVTYPE_2HWEAPON", { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 12 })
Item("mainHand",  "INVTYPE_WEAPON", { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 8 })
Item("offHand",   "INVTYPE_WEAPON", { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 7 })

-- Roles: per class, per character, default first.
class, charName, store = "WARRIOR", "Tester", {}
check("warrior roles", table.concat(CW.GetRoles(), ","), "melee,tank")
check("warrior default role", CW.GetRole(), "melee")
check("healer isn't a warrior role", CW.SetRole("healer"), false)
check("set tank", CW.SetRole("tank"), true)
check("role sticks", CW.GetRole(), "tank")
charName = "Alt"
check("another character keeps its own role", CW.GetRole(), "melee")
charName = "Tester"

-- Warrior: melee wants Strength; tank wants Stamina and armour.
CW.SetRole("melee")
check("melee warrior: Strength beats Intellect", CW.Score("strBelt", 6) > CW.Score("intBelt", 6), true)
CW.SetRole("tank")
check("tank warrior: Stamina+armour beats Strength", CW.Score("tankBelt", 6) > CW.Score("strBelt", 6), true)

-- Schools: a mage counts fire, not shadow, and never a fire RESISTANCE.
class, store = "MAGE", {}
CW.SetRole("caster")
check("mage: fire damage counts", CW.Score("fireBelt", 6) > 1, true)
check("mage: shadow damage doesn't", CW.Score("shadowBelt", 6) < 0.1, true)
-- An unrecognized stat (a resistance) makes the score unknown, so the item is kept, never scored.
check("mage: fire resistance isn't fire damage", CW.Score("fireResBelt", 6), nil)
class, store = "WARLOCK", {}
CW.SetRole("caster")
check("warlock: shadow damage counts", CW.Score("shadowBelt", 6) > 1, true)

-- Weapon DPS: the hunter's bow in the ranged slot is worth far more than a melee stat stick.
class, store = "HUNTER", {}
CW.SetRole("ranged")
check("hunter: bow DPS (ranged slot) >> dagger DPS", CW.Score("bow", 18) > 4 * CW.Score("dagger", 16), true)
class, store = "DRUID", {}
CW.SetRole("melee")
check("cat druid: weapon DPS is worth nothing", CW.Score("dagger", 16) < 0.1, true)

-- Required level is not a stat: statless gear scores alike whatever its level.
check("grey items: required level doesn't change the score", CW.Score("greyHigh", 6) == CW.Score("greyLow", 6), true)

-- Comparisons.
class, store = "WARRIOR", {}
CW.SetRole("melee")
equipped = {}
local r = CW.CompareToEquipped("strBelt", { 6 })
check("empty slot: big upgrade sentinel", r.isUpgrade and r.pawnPercentUpgrade, 100)
equipped = { [6] = "intBelt" }
r = CW.CompareToEquipped("strBelt", { 6 })
check("Strength belt over Intellect belt: upgrade", r.isUpgrade, true)
check("...naming what it replaces", r.existingItemLink, "intBelt")
equipped = { [6] = "strBelt" }
check("Intellect belt over Strength belt: not an upgrade", CW.CompareToEquipped("intBelt", { 6 }).isUpgrade, false)
-- A two-hander must beat the main hand AND the off-hand it takes with it.
equipped = { [16] = "mainHand", [17] = "offHand" }
check("2H beats the main hand alone", CW.CompareToEquipped("bigTwoHander", { 16 }).isUpgrade, true)
check("...but not main + off-hand together", CW.CompareToEquipped("bigTwoHander", { 16 }, "offHand").isUpgrade, false)

-- The reported case: stat-less bracers, 29 armour in the bag against 4 armour worn. A clear
-- upgrade for every class and role.
ITEMS.bracers4  = { "INVTYPE_WRIST", 4, 1, 1, nil, armor = 4 }   -- cloth, no stats
ITEMS.bracers29 = { "INVTYPE_WRIST", 4, 2, 1, nil, armor = 29 }  -- leather, no stats
for _, case in ipairs({ { "WARRIOR", "melee" }, { "WARRIOR", "tank" }, { "MAGE", "caster" },
                        { "PRIEST", "healer" }, { "HUNTER", "ranged" }, { "ROGUE", "melee" } }) do
    class, store = case[1], {}
    CW.SetRole(case[2])
    equipped = { [9] = "bracers4" }
    local verdict = CW.CompareToEquipped("bracers29", { 9 })
    check(case[1] .. " " .. case[2] .. ": 29-armour bracers over 4-armour ones",
          verdict and verdict.isUpgrade and verdict.pawnPercentUpgrade >= 0.05, true)
end
class, store = "WARRIOR", {}
CW.SetRole("melee")
tooltipPending = true
CW.SetRole("tank"); CW.SetRole("melee")    -- drops the score cache
equipped = { [9] = "bracers4" }
local pending = CW.CompareToEquipped("bracers29", { 9 })
check("tooltip not ready: no verdict (not a wrong one)", pending == nil or pending.isUpgrade == nil, true)
tooltipPending = false

-- Weapon-type bonuses: known racial / talent spells favour their weapon types.
ITEMS.swordA = { "INVTYPE_WEAPON", 2, 7, 1, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 } }   -- 1H sword
ITEMS.maceA  = { "INVTYPE_WEAPON", 2, 4, 1, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 } }   -- 1H mace
ITEMS.axeA   = { "INVTYPE_WEAPON", 2, 0, 1, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 } }   -- 1H axe
ITEMS.maceB  = { "INVTYPE_WEAPON", 2, 4, 1, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10.5 } } -- 5% more DPS
class, store, known = "WARRIOR", {}, {}
CW.SetRole("melee")
check("no racial: same-DPS sword and mace score alike", CW.Score("swordA", 16) == CW.Score("maceA", 16), true)
known = { [20597] = true }                    -- Human: Sword Specialization (+2% crit)
CW.Invalidate()
check("human: bonus on swords", CW.WeaponBonusPct(7), 2)
check("human: no bonus on maces", CW.WeaponBonusPct(4), 0)
check("human: sword beats a same-DPS mace", CW.Score("swordA", 16) > CW.Score("maceA", 16), true)
check("human: a clearly better mace still wins (+5% DPS vs +2%)", CW.Score("maceB", 16) > CW.Score("swordA", 16), true)
known = { [20574] = true }                    -- Orc: Axe Specialization
CW.Invalidate()
check("orc: axe beats a same-DPS sword", CW.Score("axeA", 16) > CW.Score("swordA", 16), true)
known = { [1259719] = true }                  -- Dwarf: Mace Specialization (Forever)
CW.Invalidate()
check("dwarf: mace beats a same-DPS sword", CW.Score("maceA", 16) > CW.Score("swordA", 16), true)
known = { [20597] = true, [13969] = true }    -- talents stack with racials, per type
CW.Invalidate()
check("fist talent doesn't touch swords", CW.WeaponBonusPct(7), 2)
check("...but counts on fist weapons", CW.WeaponBonusPct(13), 5)
known = { [13707] = true, [13966] = true, [13967] = true, [13968] = true, [13969] = true }
CW.Invalidate()
check("all five ranks reading as known: 5%, not 1+2+3+4+5", CW.WeaponBonusPct(13), 5)
known = {}
CW.Invalidate()

-- Profession tools with weapon damage are never "weapons".
ITEMS["item:2901:pick"]    = { "INVTYPE_WEAPONMAINHAND", 2, 14, 1, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 20 } }
ITEMS["item:7005:knife"]   = { "INVTYPE_WEAPON", 2, 14, 1, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 20 } }
ITEMS["item:6206:chipper"] = { "INVTYPE_2HWEAPON", 2, 1, 1, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 20 } }
ITEMS["item:6256:pole"]    = { "INVTYPE_2HWEAPON", 2, 20, 1, {} }
check("Mining Pick is a tool", GD.IsProfessionTool("item:2901:pick"), true)
check("Skinning Knife is a tool", GD.IsProfessionTool("item:7005:knife"), true)
check("Rock Chipper (a real 2H axe subclass) is a tool", GD.IsProfessionTool("item:6206:chipper"), true)
check("fishing pole is a tool", GD.IsProfessionTool("item:6256:pole"), true)
check("a sword isn't", GD.IsProfessionTool("swordA"), false)
check("armour isn't", GD.IsProfessionTool("bracers29"), false)

-- Proficiencies: trained weapon / armour skills, checked against the proficiency spells.
UnitLevel = function() return 20 end
ITEMS.bowP    = { "INVTYPE_RANGED", 2, 2, 1, nil }    -- bow: needs Bows (264)
ITEMS.swordP  = { "INVTYPE_WEAPON", 2, 7, 1, nil }    -- 1H sword: One-Handed Swords (201)
ITEMS.mailP   = { "INVTYPE_CHEST", 4, 3, 1, nil }     -- mail: Mail (8737)
ITEMS.cloakP  = { "INVTYPE_CLOAK", 4, 1, 1, nil }     -- cloth (Cloth, which everyone has)
known = {}
check("Cloth unreported -> check stands down (never hides everything)", GD.LacksProficiency("swordP"), false)
known = { [9078] = true, [201] = true }               -- warrior: Cloth, 1H Swords; no Bows, no Mail
check("untrained Bows: bow unusable", GD.LacksProficiency("bowP"), true)
check("...and the shared requirement check says so", GD.ItemFailsARequirement("bowP"), true)
check("known One-Handed Swords: sword usable", GD.LacksProficiency("swordP"), false)
check("no Mail proficiency: mail unusable", GD.LacksProficiency("mailP"), true)
check("cloak (cloth) usable", GD.LacksProficiency("cloakP"), false)
known = { [9078] = true, [201] = true, [264] = true }  -- trained Bows at a weapon master
check("after training Bows: bow usable", GD.LacksProficiency("bowP"), false)
known = {}

-- Tooltip: the unusable weapon type is the RIGHT-hand text of the slot line.
ITEMS.redRight = { "INVTYPE_RANGED", 2, 2, 1, nil }
local realHyperlink = C_TooltipInfo.GetHyperlink
C_TooltipInfo.GetHyperlink = function(link)
    if link == "redRight" then
        return { lines = { { leftText = "Ranged", leftColor = { r = 1, g = 1, b = 1 },
                             rightText = "Bow", rightColor = { r = 1, g = 0.125, b = 0.125 } } } }
    end
    return realHyperlink(link)
end
check("red right-hand tooltip text fails the requirement", GD.ItemFailsARequirement("redRight"), true)
C_TooltipInfo.GetHyperlink = realHyperlink

-- GameData.ComparableSlots (the reward picker's slot list).
dualWield, equipped = false, { [16] = "mainHand" }
check("slots: single slot as a list", GD.ComparableSlots("INVTYPE_WAIST")[1], 6)
check("slots: one-hander, no dual wield -> main hand only", #GD.ComparableSlots("INVTYPE_WEAPON"), 1)
check("slots: bow -> ranged slot", GD.ComparableSlots("INVTYPE_RANGED")[1], 18)

-- ---------------------------------------------------------------- the advisor's scan (GearAdvisor.lua)
-- The reported failure end to end: at login the bag bracers' data isn't loaded, the scan gets no
-- verdict — and must come back for it rather than file the unchanged bags as already scored.
do
    local timers, equippedCalls, uncached = {}, {}, {}
    local stubFrame = { RegisterEvent = function() end, UnregisterEvent = function() end,
                        SetScript = function() end }
    CreateFrame = function() return stubFrame end
    InCombatLockdown = function() return false end
    UnitIsDeadOrGhost = function() return false end
    UnitCastingInfo, UnitChannelInfo = function() end, function() end
    UnitLevel = function() return 10 end
    GetTime = function() return 1000 end
    date = date or os.date   -- WoW exposes os.date as the global date
    GetInventoryItemID = function(_, slot)
        local link = equipped[slot]; return link and tonumber(link:match("item:(%d+)"))
    end
    StaticPopup_Visible = function() return nil end
    NUM_BAG_SLOTS = 0
    local bagSlots = {}
    C_Container = {
        GetContainerNumSlots = function(bag) return bag == 0 and #bagSlots or 0 end,
        GetContainerItemInfo = function(_, slot) return bagSlots[slot] end,
    }
    C_Item.IsEquippableItem = function(link) return ITEMS[link] ~= nil end
    C_Item.EquipItemByName = function(link, slot) equippedCalls[#equippedCalls + 1] = { link, slot } end
    local realInfo = C_Item.GetItemInfo
    C_Item.GetItemInfo = function(link) if uncached[link] then return nil end return realInfo(link) end

    local stubs = {
        Services = {
            ScheduleOnce = function(key, _, fn) timers[key] = fn end,
            Debug = function() end,
            SafeCall = function(fn, ...) return fn(...) end,
            ShouldAutomate = function() return true end,
            InSpecialControlState = function() return false end,
        },
        PawnScoring = { RelevantScales = function() return nil end,
                        GetConfiguredForeverScale = function() return nil end,  -- no Pawn scale picked
                        RelevantScale = function() return nil end,
                        FormatUpgrade = function() return "+%" end },
        GearToast = { Show = function() end, Hide = function() end },
        SafetyEngine = { IsBusy = function() return false end },
    }
    -- Forever as it really is: the bare spec globals don't exist (their compatibility addon is
    -- excluded from camelot), only C_SpecializationInfo. Calling the bare name crashed the scan.
    GetSpecialization, GetSpecializationInfo = nil, nil
    C_SpecializationInfo = {
        GetSpecialization = function() return 1 end,
        GetSpecializationInfo = function() return 1491, "Warrior", "", 0, "DAMAGER", 0 end,  -- primary stat 0
    }
    store = { [".enabled"] = true, ["gearSwap.advisorEnabled"] = true, ["gearSwap.autoEquip"] = true,
              ["gearSwap.minUpgradePct"] = 3, ["gearSwap.announce"] = false }
    class = "WARRIOR"
    local _, _, cw, mods = Load(true, { "Services/GearScoring.lua", "Engines/GearAdvisor.lua" }, stubs)
    local GA = mods.GearAdvisor

    -- Real links carry an item ID (the advisor keys on it), so alias the test bracers.
    local OLD, NEW = "item:1004:bracers", "item:1029:bracers"
    ITEMS[OLD], ITEMS[NEW] = ITEMS.bracers4, ITEMS.bracers29
    equipped = { [9] = OLD }
    -- The Mining Pick out-damages the equipped sword; it must still never be offered.
    local PICK, SWORD = "item:2901:pick", "item:2131:sword"
    ITEMS[SWORD] = { "INVTYPE_WEAPON", 2, 7, 1, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 1.15 } }
    equipped[16] = SWORD
    bagSlots = { { hyperlink = NEW, isBound = true }, { hyperlink = PICK, isBound = true } }
    uncached = { [NEW] = true }              -- login: not loaded yet

    GA.Scan()
    local n = 0; for _ in pairs(GA.GetRecommendations()) do n = n + 1 end
    check("scan at login (bracers not loaded): no recommendation yet", n, 0)
    check("...and a retry is scheduled instead of giving up", timers.gear_advisor_settle ~= nil, true)

    uncached = {}                            -- the data arrives
    local retry = timers.gear_advisor_settle
    timers.gear_advisor_settle = nil
    retry()
    local rec = GA.GetRecommendations()[9]
    check("retry: the 29-armour bracers are recommended for the wrist", rec and rec.link, NEW)
    check("retry: auto-equip puts them on, in the wrist slot",
          equippedCalls[1] and (equippedCalls[1][1] .. "@" .. equippedCalls[1][2]), NEW .. "@9")
    check("settled: no further retries", timers.gear_advisor_settle, nil)
    check("the Mining Pick is never recommended over the sword", GA.GetRecommendations()[16], nil)
end

if failures == 0 then
    print("gear forever checks: all passed")
else
    print(string.format("gear forever checks: %d FAILED", failures))
end
