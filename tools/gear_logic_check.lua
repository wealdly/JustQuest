-- Verifies the two bits of the gear advisor that are easy to get silently wrong:
-- pcall + multi-return index arithmetic against GetItemInfoInstant's return shape, and
-- the stat-delta ordering / sign / zero-filtering. Both fail quietly rather than loudly —
-- an off-by-one in the return positions yields a plausible-looking wrong number.
--
-- Pure Lua, no WoW APIs, no framework. Run with any Lua 5.1+:
--     lua tools/gear_logic_check.lua
-- or, matching the syntax checker's interpreter:
--     python -c "import lupa.lua54 as l; l.LuaRuntime().execute(open('tools/gear_logic_check.lua').read())"

local failures = 0
local function check(name, got, want)
    if got ~= want then
        print(string.format("FAIL %s: got %s, want %s", name, tostring(got), tostring(want)))
        failures = failures + 1
    end
end

-- GetItemInfoInstant returns, in order:
-- itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID
local function GetItemInfoInstant(id)
    if id == "fishingpole" then
        return 6256, "Weapon", "Fishing Poles", "INVTYPE_2HWEAPON", 132932, 2, 20
    elseif id == "professiontool" then
        return 111111, "Profession", "Blacksmithing", "INVTYPE_PROFESSION_TOOL", 1, 19, 3
    end
    return 222222, "Armor", "Plate", "INVTYPE_CHEST", 2, 4, 4
end

-- Exactly the destructuring used in SlotIsProfessionProtected.
local ok, _, _, _, _, _, classID, subclassID = pcall(GetItemInfoInstant, "fishingpole")
check("pcall ok", ok, true)
check("fishing pole classID", classID, 2)
check("fishing pole subclassID", subclassID, 20)

local ok2, _, _, _, _, _, classID2 = pcall(GetItemInfoInstant, "professiontool")
check("profession classID", classID2, 19)
check("pcall ok2", ok2, true)

-- Exactly the destructuring used in DisplacedOffHand.
local okMain, _, _, _, mainEquipLoc = pcall(GetItemInfoInstant, "fishingpole")
check("equipLoc position", mainEquipLoc, "INVTYPE_2HWEAPON")
check("pcall okMain", okMain, true)

-- A failing call must not produce a bogus classID.
local okBad, _, _, _, _, _, classIDBad = pcall(function() error("boom") end)
check("failed pcall reports false", okBad, false)
check("failed pcall yields nil classID", classIDBad, nil)

-- ---- stat delta ordering / sign / zero-filtering ----
local MAX_STATS = 4
local function deltas(newStats, oldStats)
    local out, seen = {}, {}
    local function consider(key)
        if seen[key] then return end
        seen[key] = true
        local diff = (newStats[key] or 0) - (oldStats[key] or 0)
        if diff ~= 0 then out[#out + 1] = { key = key, diff = diff } end
    end
    for k in pairs(newStats) do consider(k) end
    for k in pairs(oldStats) do consider(k) end
    table.sort(out, function(a, b) return math.abs(a.diff) > math.abs(b.diff) end)
    local parts = {}
    for i = 1, math.min(MAX_STATS, #out) do
        parts[#parts + 1] = (out[i].diff > 0 and "+" or "") .. out[i].diff .. " " .. out[i].key
    end
    return table.concat(parts, "   "), #out
end

-- A stat only on the OLD item must appear as a loss (the union matters).
local s = deltas({ HASTE = 100 }, { MASTERY = 80 })
check("union includes dropped stat", s, "+100 HASTE   -80 MASTERY")

-- Unchanged stats are omitted entirely.
local s2, n2 = deltas({ STAM = 50, HASTE = 10 }, { STAM = 50 })
check("zero delta filtered", s2, "+10 HASTE")
check("zero delta not counted", n2, 1)

-- Biggest absolute change leads, regardless of sign.
local s3 = deltas({ A = 1, B = 5 }, { A = 0, B = 0, C = 90 })
check("largest absolute first", s3, "-90 C   +5 B   +1 A")

-- Empty slot (no old item) is all gains.
local s4 = deltas({ A = 7 }, {})
check("empty baseline", s4, "+7 A")

-- Identical items produce nothing to say.
local _, n5 = deltas({ A = 7 }, { A = 7 })
check("identical yields no lines", n5, 0)

-- ---- armour-type gate ----
-- The trap this guards: a cloak is Cloth-subclass for EVERY class, so a gate that keys
-- only on subclass hides every cloak from everyone but clothies.
local ARMOR_CLASS = 4
local ARMOR_TYPED_SLOTS = {
    INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true,
    INVTYPE_ROBE = true, INVTYPE_WAIST = true,    INVTYPE_LEGS  = true,
    INVTYPE_FEET = true, INVTYPE_WRIST = true,    INVTYPE_HAND  = true,
}
local CLASS_ARMOR = {
    WARRIOR = 4, PALADIN = 4, DEATHKNIGHT = 4,
    HUNTER  = 3, SHAMAN  = 3, EVOKER      = 3,
    ROGUE   = 2, DRUID   = 2, MONK        = 2, DEMONHUNTER = 2,
    PRIEST  = 1, MAGE    = 1, WARLOCK     = 1,
}

-- Mirrors GameData.ItemIsWrongArmorType.
local function wrongArmor(class, itemClassID, invType, itemSubclassID)
    if itemClassID ~= ARMOR_CLASS then return false end
    if not ARMOR_TYPED_SLOTS[invType] then return false end
    local want = CLASS_ARMOR[class]
    if not want then return false end
    return itemSubclassID ~= want
end

check("druid rejects cloth chest",   wrongArmor("DRUID", 4, "INVTYPE_CHEST", 1), true)
check("druid accepts leather chest", wrongArmor("DRUID", 4, "INVTYPE_CHEST", 2), false)
check("druid rejects mail legs",     wrongArmor("DRUID", 4, "INVTYPE_LEGS", 3), true)
check("druid accepts leather robe",  wrongArmor("DRUID", 4, "INVTYPE_ROBE", 2), false)
check("warrior accepts plate",       wrongArmor("WARRIOR", 4, "INVTYPE_HEAD", 4), false)
check("evoker accepts mail",         wrongArmor("EVOKER", 4, "INVTYPE_HAND", 3), false)
-- Cloaks are Cloth for everyone: never filtered.
check("druid keeps cloth cloak",     wrongArmor("DRUID", 4, "INVTYPE_CLOAK", 1), false)
check("plate class keeps cloak",     wrongArmor("PALADIN", 4, "INVTYPE_CLOAK", 1), false)
-- Rings/necks (Miscellaneous subclass) and weapons are outside the gate entirely.
check("ring not filtered",           wrongArmor("DRUID", 4, "INVTYPE_FINGER", 0), false)
check("weapon not filtered",         wrongArmor("DRUID", 2, "INVTYPE_2HWEAPON", 6), false)
-- An unknown class token must not filter anything (fail open, never hide upgrades).
check("unknown class filters nothing", wrongArmor("TINKER", 4, "INVTYPE_CHEST", 1), false)

-- Travel-item hold. Mirrors GearAdvisor's TravelHold. A teleport cloak scores as a pure
-- downgrade (Pawn rates stats; a teleport has none), so without the hold the advisor offers to
-- take it straight back off — and in auto-equip mode actually does, which cancels the trip,
-- because those items only work from an equipped slot. Two ways to get it wrong: release too
-- early and you break the teleport, never release and the swap-back reminder is lost for good.
local TRAVEL_HOLD = 5

local function TravelHold(now, holdUntil, casting)
    if casting then return true end
    return now < holdUntil
end

local armed = 0 + TRAVEL_HOLD  -- cloak goes on at t=0
check("held right after equipping",  TravelHold(1, armed, false), true)
check("held while the cast runs",    TravelHold(5, armed, true), true)
-- A cast slower than the window must not fall through mid-teleport.
check("cast outlasts the window",    TravelHold(15, armed, true), true)
-- Put it on and never used it: the reminder has to come back, not be suppressed forever.
check("window expires unused",       TravelHold(15, armed, false), false)
-- PLAYER_ENTERING_WORLD zeroes the hold — arriving is exactly when the reminder is wanted.
check("arrival releases the hold",   TravelHold(1, 0, false), false)
-- Ordinary gear arms nothing, so normal prompting is untouched.
check("plain gear arms no hold",     TravelHold(0.1, 0, false), false)

-- Primary-stat gate. Mirrors GameData.ItemIsWrongPrimaryStat. This runs inside the usability
-- check, so the dangerous direction is filtering too much: a wrong "true" hides a real upgrade
-- and the advisor just goes quiet, which looks exactly like having no upgrades.
local STR, AGI, INT = 1, 2, 4
local PRIMARY_KEY = {
    [STR] = "ITEM_MOD_STRENGTH_SHORT",
    [AGI] = "ITEM_MOD_AGILITY_SHORT",
    [INT] = "ITEM_MOD_INTELLECT_SHORT",
}

local function WrongPrimaryStat(primaryStat, stats)
    if not primaryStat or primaryStat == 0 then return false end
    local want = PRIMARY_KEY[primaryStat]
    if not want then return false end
    if type(stats) ~= "table" then return false end
    if stats[want] then return false end
    for _, key in pairs(PRIMARY_KEY) do
        if key ~= want and stats[key] then return true end
    end
    return false
end

local agiSpear   = { ITEM_MOD_AGILITY_SHORT = 120,  ITEM_MOD_STAMINA_SHORT = 200 }
local intStaff   = { ITEM_MOD_INTELLECT_SHORT = 120, ITEM_MOD_STAMINA_SHORT = 200 }
local plainCloak = { ITEM_MOD_STAMINA_SHORT = 80,   ITEM_MOD_HASTE_RATING_SHORT = 40 }
local allStats   = { ITEM_MOD_AGILITY_SHORT = 50,   ITEM_MOD_INTELLECT_SHORT = 50 }

check("resto druid rejects agi spear",  WrongPrimaryStat(INT, agiSpear), true)
check("resto druid keeps int staff",    WrongPrimaryStat(INT, intStaff), false)
check("feral druid keeps agi spear",    WrongPrimaryStat(AGI, agiSpear), false)
-- No primary stat at all: cloaks, necks, most rings. Filtering these hides ordinary gear.
check("statless cloak kept",            WrongPrimaryStat(INT, plainCloak), false)
-- "All stats" gear carries ours alongside another — ours being present is enough.
check("all-stats item kept",            WrongPrimaryStat(INT, allStats), false)
-- Every unknown fails open.
check("no spec filters nothing",        WrongPrimaryStat(nil, agiSpear), false)
check("statless spec filters nothing",  WrongPrimaryStat(0, agiSpear), false)
check("uncached item filters nothing",  WrongPrimaryStat(INT, nil), false)

-- Item-level fallback, used when Pawn has no scale for the spec. Mirrors ScoreByItemLevel.
-- Two things have to hold: a dual slot is judged against its WEAKER side (or a new ring always
-- looks like a downgrade next to your good one and nothing is ever offered), and an uncached
-- item level yields no verdict rather than a wrong one.
local NO_BASELINE = 100

local function ScoreByItemLevel(candidate, equippedLevels)
    if not candidate then return nil end
    local worstLevel
    for _, level in ipairs(equippedLevels) do
        if level == false then return nil end        -- uncached side: no verdict
        if level == 0 then return { pct = NO_BASELINE, empty = true } end  -- empty slot
        if not worstLevel or level < worstLevel then worstLevel = level end
    end
    if candidate <= worstLevel then return nil end
    return { pct = (candidate - worstLevel) / math.max(worstLevel, 1), empty = false }
end

local function pct(r) return r and r.pct end

check("beats the equipped piece",     pct(ScoreByItemLevel(120, {100})), 0.2)
check("ties are not upgrades",        pct(ScoreByItemLevel(100, {100})), nil)
check("below is not an upgrade",      pct(ScoreByItemLevel(90,  {100})), nil)
-- Rings/one-handers: judged against the weaker side, so a mid ring still beats the bad one.
check("dual slot uses weaker side",   pct(ScoreByItemLevel(120, {200, 100})), 0.2)
check("worse than both is rejected",  pct(ScoreByItemLevel(90,  {200, 100})), nil)
-- An empty slot has nothing to be worse than: always offered, flagged as having no baseline.
check("empty slot always offered",    pct(ScoreByItemLevel(50,  {0})), NO_BASELINE)
check("empty second ring offered",    pct(ScoreByItemLevel(50,  {200, 0})), NO_BASELINE)
-- Uncached item level must produce no verdict at all, never a guess.
check("uncached candidate no verdict", pct(ScoreByItemLevel(nil, {100})), nil)
check("uncached equipped no verdict",  pct(ScoreByItemLevel(120, {false})), nil)

if failures == 0 then
    print("gear checks: all passed")
else
    print(string.format("gear checks: %d FAILED", failures))
    os.exit(1)
end
