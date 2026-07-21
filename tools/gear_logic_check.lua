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

if failures == 0 then
    print("gear checks: all passed")
else
    print(string.format("gear checks: %d FAILED", failures))
    os.exit(1)
end
