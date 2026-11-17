-- ClassWeights.lua — WoW Forever gear scoring: per-class, per-role stat weights.
--
-- Forever gives the scorers nothing to stand on: no Pawn, item levels that don't mean anything
-- (over a thousand equippable items sit at item level 1; most scale off curves), and every class
-- has one specialization whose primary stat is "none" and whose role is "damage". What every item
-- DOES carry is its stats, so an item is worth the sum of its stats weighted for what the player
-- is doing — the way Pawn works, but with built-in weights since nobody has scales for this game.
--
-- The role comes from the player, per character, because the game can't tell a Protection warrior
-- from an Arms one. Hybrids get two damage roles (melee / caster): an Enhancement and an Elemental
-- shaman want opposite gear. The weights are a starting point written for this addon — relative
-- values with the primary stat at 1.0 — not copied from anywhere; `/jq gear stats` shows exactly
-- what each equipped stat contributed, so they can be tuned against real items.
--
-- Retail never reaches this module: there the spec and Pawn answer the same question better.

local ADDON_NAME, JustQuest = ...

local ClassWeights = {}

local GetConfig = JustQuest.Core.ModuleGetter("Config")
local GetGameData = JustQuest.Core.ModuleGetter("GameData")

-- GetItemStats keys (the game's own ITEM_MOD_* global names). Short aliases keep the tables
-- below readable.
local KEY = {
    STR = "ITEM_MOD_STRENGTH_SHORT",   AGI = "ITEM_MOD_AGILITY_SHORT",
    STA = "ITEM_MOD_STAMINA_SHORT",    INT = "ITEM_MOD_INTELLECT_SHORT",
    SPI = "ITEM_MOD_SPIRIT_SHORT",
    AP  = "ITEM_MOD_ATTACK_POWER_SHORT", RAP = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
    CRIT = "ITEM_MOD_CRIT_RATING_SHORT", HIT = "ITEM_MOD_HIT_RATING_SHORT",
    HASTE = "ITEM_MOD_HASTE_RATING_SHORT", EXP = "ITEM_MOD_EXPERTISE_RATING_SHORT",
    SP   = "ITEM_MOD_SPELL_POWER_SHORT", SDMG = "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT",
    HEAL = "ITEM_MOD_SPELL_HEALING_DONE_SHORT", MP5 = "ITEM_MOD_MANA_REGENERATION_SHORT",
    DEF  = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", DODGE = "ITEM_MOD_DODGE_RATING_SHORT",
    PARRY = "ITEM_MOD_PARRY_RATING_SHORT", BLOCK = "ITEM_MOD_BLOCK_RATING_SHORT",
    BLOCKV = "ITEM_MOD_BLOCK_VALUE_SHORT", XARMOR = "ITEM_MOD_EXTRA_ARMOR_SHORT",
    ARMOR = "RESISTANCE0_NAME",
    DPS  = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT",
}
local KNOWN_STATS = {}
for _, key in pairs(KEY) do KNOWN_STATS[key] = true end

-- Per-role weights, primary stat = 1.0. Two entries aren't stat keys:
--   SCHOOL      school-specific spell damage (Forever's fire / frost / shadow / ... damage
--               stats), counted only for the class's own schools — see CLASS.schools
--   RANGED_DPS  weapon DPS of an item worn in the ranged slot: the hunter's bow, the caster's
--               wand, the warrior's pulling gun — very different values to each
-- Vanilla rule of thumb behind the melee DPS figure: 14 attack power = 1 weapon DPS, and a
-- warrior gets 2 AP per Strength, so one point of weapon DPS is worth about 7 Strength.
-- Armour per point: levelling in vanilla is mostly taking hits, so it matters to everyone — a
-- tank values ~10 armour like a point of Stamina, damage roles about a third of that. (At
-- 0.01 a whole bracer's worth of armour lost to a single point of Stamina.)
local ROLE_BASE = {
    melee  = { STR = 1.0, AGI = 0.6, AP = 0.5, CRIT = 0.9, HIT = 0.9, HASTE = 0.6, EXP = 0.6,
               STA = 0.3, ARMOR = 0.03, DPS = 7, RANGED_DPS = 0.3 },
    ranged = { AGI = 1.0, INT = 0.35, RAP = 0.5, AP = 0.15, CRIT = 0.9, HIT = 0.9, HASTE = 0.6,
               STA = 0.3, ARMOR = 0.03, DPS = 0.8, RANGED_DPS = 5 },
    caster = { INT = 1.0, SP = 1.0, SDMG = 1.0, SCHOOL = 0.85, CRIT = 0.8, HIT = 0.8, HASTE = 0.6,
               SPI = 0.4, MP5 = 0.6, STA = 0.3, ARMOR = 0.02, RANGED_DPS = 1.5 },
    healer = { HEAL = 1.0, SP = 1.0, INT = 1.0, SPI = 0.6, MP5 = 1.0, CRIT = 0.6, HASTE = 0.5,
               STA = 0.3, ARMOR = 0.02, RANGED_DPS = 0.5 },
    tank   = { STA = 1.0, DEF = 1.0, DODGE = 0.8, PARRY = 0.7, BLOCK = 0.6, BLOCKV = 0.3,
               XARMOR = 0.1, ARMOR = 0.1, STR = 0.6, AGI = 0.7, HIT = 0.4, EXP = 0.4, AP = 0.2,
               DPS = 2, RANGED_DPS = 0.2 },
}

-- What each class can do on Forever (its talent trees), first = default, plus per-class
-- adjustments on top of ROLE_BASE.
local CLASS = {
    WARRIOR = { roles = { "melee", "tank" } },
    ROGUE   = { roles = { "melee" }, tweak = { melee = { AGI = 1.0, STR = 0.5 } } },
    HUNTER  = { roles = { "ranged" } },
    MAGE    = { roles = { "caster" }, schools = { FIRE = true, FROST = true, ARCANE = true } },
    WARLOCK = { roles = { "caster" }, schools = { SHADOW = true, FIRE = true },
                tweak = { caster = { STA = 0.5 } } },  -- Life Tap turns Stamina into mana
    PRIEST  = { roles = { "caster", "healer" }, schools = { SHADOW = true, HOLY = true } },
    PALADIN = { roles = { "melee", "tank", "healer" }, schools = { HOLY = true },
                tweak = { melee = { INT = 0.25 }, tank = { SP = 0.4, SCHOOL = 0.4, INT = 0.3 } } },
    SHAMAN  = { roles = { "melee", "caster", "healer" }, schools = { NATURE = true, FIRE = true, FROST = true },
                tweak = { melee = { INT = 0.25 } } },
    -- Forms fight with the form, not the weapon: weapon DPS is worth nothing to cat or bear.
    DRUID   = { roles = { "melee", "tank", "caster", "healer" }, schools = { NATURE = true, ARCANE = true },
                tweak = { melee = { AGI = 1.0, STR = 0.8, DPS = 0 }, tank = { AGI = 1.0, DPS = 0, ARMOR = 0.15 } } },  -- bear form multiplies armour
}

local ROLE_LABEL = {
    melee = "Melee damage", ranged = "Ranged damage", caster = "Caster damage",
    healer = "Healer", tank = "Tank",
}

local SCHOOLS = { "HOLY", "FIRE", "NATURE", "FROST", "SHADOW", "ARCANE" }

local NO_BASELINE = 100  -- empty slot; the sentinel the advisor and reward picker read as such

-- ============================================================
-- Weapon-type bonuses (racials and talents)
-- ============================================================
-- A human's swords crit 2% more, an orc's axes and a dwarf's maces 1%; talents add more (Two-
-- Handed Weapon Specialization, Fist Weapon Specialization, Weapon Mastery, Wand Specialization).
-- Read from the game's own data rather than a race table: a bonus counts when the character KNOWS
-- the spell (IsPlayerSpell), so racials and the talents actually taken both apply, and nothing
-- here names a race. Applied only to weighted weapon DPS, not to the item's other stats.
-- Crit and damage percentages are an approximation, not a simulated damage increase.
-- Regenerate with tools/gen_weapon_specs.py after a Forever patch.
-- Generated from WoW Forever 1.60.1.70205 DB2 (SpellEquippedItems + SpellEffect + SkillLineAbility):
-- every racial (skill category 9) and class-talent (7) passive that raises crit (auras 52/290) or
-- damage (aura 79) with specific weapon types.
-- [spellID] = { item-subclass mask, crit %, damage %, optional alternate-rank family }
local WEAPON_SPECS = {
    [6057] = { 524288, 0, 13 },  -- Wand Specialization (Arcane)
    [12163] = { 136546, 0, 1 },  -- Two-Handed Weapon Specialization (Arms)
    [12320] = { 173555, 5, 0 },  -- Cruelty (Fury)
    [12700] = { 131139, 1, 0 },  -- Weaponmaster (Arms)
    [13706] = { 40960, 5, 0 },  -- Hack and Slash (Combat, Combat)
    [13707] = { 8192, 1, 0, 13707 },  -- Fist Weapon Specialization (Combat)
    [13966] = { 8192, 2, 0, 13707 },  -- Fist Weapon Specialization (Combat)
    [13967] = { 8192, 3, 0, 13707 },  -- Fist Weapon Specialization (Combat)
    [13968] = { 8192, 4, 0, 13707 },  -- Fist Weapon Specialization (Combat)
    [13969] = { 8192, 5, 0, 13707 },  -- Fist Weapon Specialization (Combat)
    [14524] = { 524288, 0, 25 },  -- Wand Specialization (Discipline)
    [16255] = { 173555, 1, 0 },  -- Thundering Strikes (Enhancement)
    [19381] = { 173555, 0, 1, 19381 },  -- Melee Specialization (Survival)
    [19382] = { 173555, 0, 2, 19381 },  -- Melee Specialization (Survival)
    [19383] = { 173555, 0, 3, 19381 },  -- Melee Specialization (Survival)
    [19384] = { 173555, 0, 4, 19381 },  -- Melee Specialization (Survival)
    [19385] = { 173555, 0, 5, 19381 },  -- Melee Specialization (Survival)
    [19507] = { 262156, 0, 5 },  -- Ranged Weapon Specialization (Marksmanship)
    [20111] = { 136546, 0, 2 },  -- Two-Handed Weapon Specialization (Retribution)
    [20117] = { 173555, 5, 0 },  -- Conviction (Retribution)
    [20196] = { 43153, 0, 2 },  -- One-Handed Weapon Specialization (Protection)
    [20574] = { 3, 1, 0 },  -- Axe Specialization (Orc Racial)
    [20597] = { 384, 2, 0 },  -- Sword Specialization (Racial - Human)
    [29082] = { 44083, 0, 2, 29082 },  -- Weapon Mastery (Enhancement)
    [29084] = { 44083, 0, 4, 29082 },  -- Weapon Mastery (Enhancement)
    [29086] = { 44083, 0, 6, 29082 },  -- Weapon Mastery (Enhancement)
    [29087] = { 44083, 0, 8, 29082 },  -- Weapon Mastery (Enhancement)
    [29088] = { 44083, 0, 10, 29082 },  -- Weapon Mastery (Enhancement)
    [415320] = { 173555, 0, 8 },  -- Flanking Strike (Survival)
    [1259719] = { 48, 1, 0 },  -- Mace Specialization (Dwarven Racial)
}

-- Total bonus %, for the current character, on weapons of this item subclass. Cached per scan
-- generation (Invalidate drops it when spells or talents change).
local weaponBonusCache = {}
local function WeaponBonusPct(subclassID)
    if not subclassID then return 0 end
    local cached = weaponBonusCache[subclassID]
    if cached then return cached end
    -- Masks identify affected weapons, not stacking families. Distinct passives can share one.
    local best, bitValue = {}, 2 ^ subclassID
    for spellID, spec in pairs(WEAPON_SPECS) do
        if math.floor(spec[1] / bitValue) % 2 == 1 and IsPlayerSpell and IsPlayerSpell(spellID) then
            local group = spec[4] or spellID
            best[group] = math.max(best[group] or 0, spec[2] + spec[3])
        end
    end
    local pct = 0
    for _, value in pairs(best) do pct = pct + value end
    weaponBonusCache[subclassID] = pct
    return pct
end
ClassWeights.WeaponBonusPct = WeaponBonusPct

function ClassWeights.IsActive()
    return JustQuest.Constants.IS_FOREVER and true or false
end

local function PlayerClass()
    return select(2, UnitClass("player"))
end

-- ============================================================
-- Role (per character)
-- ============================================================
-- Stored per character inside the shared profile: every character uses the same profile, and a
-- role is the one gear setting that is obviously personal.
local function CharKey()
    local name, realm = UnitFullName("player")
    realm = (realm and realm ~= "") and realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or "?"
    return (name or "?") .. "-" .. realm
end

function ClassWeights.GetRoles()
    local class = CLASS[PlayerClass()]
    return class and class.roles or { "melee" }
end

function ClassWeights.RoleLabel(role)
    return ROLE_LABEL[role] or tostring(role)
end

function ClassWeights.GetRole()
    local roles = ClassWeights.GetRoles()
    local config = GetConfig()
    local saved = config and (config.Get("gearSwap", "roles") or {})[CharKey()]
    for _, r in ipairs(roles) do
        if r == saved then return r end
    end
    return roles[1]  -- unset, or a role this class doesn't have
end

local weightCache, scoreCache = nil, {}

-- Drop everything derived from the character: role change, a spell learned, talents changed.
function ClassWeights.Invalidate(reason)
    weightCache, scoreCache, weaponBonusCache = nil, {}, {}
    if EventRegistry then EventRegistry:TriggerEvent("JustQuest.GearScoringChanged", reason) end
end

function ClassWeights.SetRole(role)
    local valid = false
    for _, r in ipairs(ClassWeights.GetRoles()) do valid = valid or r == role end
    if not valid then return false end
    local config = GetConfig()
    if not config then return false end
    -- A fresh table: Get may hand back the shared default, which must not be written into.
    local roles = {}
    for k, v in pairs(config.Get("gearSwap", "roles") or {}) do roles[k] = v end
    roles[CharKey()] = role
    config.Set("gearSwap", "roles", roles)
    ClassWeights.Invalidate("role")
    return true
end

-- ============================================================
-- Scoring
-- ============================================================

-- The resolved table for the current class + role: stat key -> weight, plus SCHOOL / RANGED_DPS.
local function Weights()
    if weightCache then return weightCache end
    local classInfo = CLASS[PlayerClass()] or {}
    local role = ClassWeights.GetRole()
    local merged = {}
    for k, v in pairs(ROLE_BASE[role] or ROLE_BASE.melee) do merged[k] = v end
    for k, v in pairs((classInfo.tweak or {})[role] or {}) do merged[k] = v end

    local w = { SCHOOL = merged.SCHOOL or 0, RANGED_DPS = merged.RANGED_DPS or 0,
                schools = classInfo.schools or {}, role = role }
    for alias, value in pairs(merged) do
        if KEY[alias] then w[KEY[alias]] = value end
    end
    weightCache = w
    return w
end

-- School damage arrives under keys this file can't know in advance (Forever's own stats for
-- fire / frost / shadow ... damage). Matched by name: a key naming a school that isn't a
-- resistance. Returns the school or nil.
-- ponytail: name match, not a confirmed key list — `/jq gear stats` prints the real keys; pin
-- them in KEY once seen in game.
local function SchoolOf(key)
    if key:find("RESIST", 1, true) then return nil end
    for _, school in ipairs(SCHOOLS) do
        if key:find(school, 1, true) then return school end
    end
    return nil
end

-- Weight of one stat for this item, and why (for the probe).
local function WeightFor(w, key, inRangedSlot)
    if key == KEY.DPS then
        if inRangedSlot then return w.RANGED_DPS, "ranged-slot DPS" end
        return w[key] or 0, "weapon DPS"
    end
    if w[key] then return w[key], nil end
    local school = SchoolOf(key)
    if school then
        if w.schools[school] then return w.SCHOOL, school:lower() .. " damage" end
        return 0, school:lower() .. " damage (not your school)"
    end
    return 0, "unweighted"
end

-- Score for the current class/role and destination slot. nil for missing or unmodeled stats.
function ClassWeights.Score(link, slot)
    if not link or not CLASS[PlayerClass()] then return nil end
    local w = Weights()
    local cacheKey = link .. "|" .. tostring(slot) .. "|" .. w.role
    if scoreCache[cacheKey] then return scoreCache[cacheKey] end

    local stats = GetGameData().ItemStats(link)
    if not stats then return nil end
    local inRangedSlot = slot == JustQuest.Constants.RANGED_SLOT and JustQuest.Constants.IS_FOREVER
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(link)
    if classID == JustQuest.Constants.ITEM_CLASS.WEAPON
       and (WeightFor(w, KEY.DPS, inRangedSlot)) > 0 and not stats[KEY.DPS] then
        return nil
    end
    local total, weaponValue = 0, 0
    for key, value in pairs(stats) do
        if value ~= 0 and not KNOWN_STATS[key] and not SchoolOf(key) then return nil end
        local contribution = value * (WeightFor(w, key, inRangedSlot))
        total = total + contribution
        if key == KEY.DPS then weaponValue = contribution end
    end
    -- Racial / talent weapon-type bonus (see WEAPON_SPECS).
    if classID == JustQuest.Constants.ITEM_CLASS.WEAPON then
        total = total + weaponValue * WeaponBonusPct(subclassID) / 100
    end
    scoreCache[cacheKey] = total
    return total
end

-- Compare an item with what's worn in the slots it can replace (the weaker of two). displaced =
-- an extra item that would also come off (the off-hand under a two-hander), whose score is
-- added to the baseline. Returns a Pawn-shaped verdict, or nil when something isn't cached yet.
function ClassWeights.CompareToEquipped(link, slots, displaced)
    if not (link and slots and slots[1]) then return nil end
    local new = ClassWeights.Score(link, slots[1])
    if not new then return nil end

    local worstLink, worst, worstSlot
    for _, slot in ipairs(slots) do
        local equipped = GetInventoryItemLink("player", slot)
        local score = 0
        if equipped then score = ClassWeights.Score(equipped, slot) end
        if not score then return nil end
        if not worst or score < worst then worstLink, worst, worstSlot = equipped, score, slot end
    end
    if displaced then
        local extra = ClassWeights.Score(displaced, 17)
        if not extra then return nil end
        worst = worst + extra
    end

    return {
        isUpgrade          = new > worst,
        pawnPercentUpgrade = new > worst and (worst > 0 and (new - worst) / worst or NO_BASELINE) or 0,
        existingItemLink   = worstLink,
        byClassStats       = true,
        destinationSlot    = worstSlot,
        candidateScore     = new,
        baselineScore      = worst,
    }
end

-- ============================================================
-- Probe: /jq gear stats
-- ============================================================
-- Every equipped item's stats as the game reports them, with the weight each got and its
-- contribution — so a missing or odd key (Forever's school damage, ratings vs percentages)
-- shows up in one look, and the weights can be checked against real gear.
function ClassWeights.DumpEquipped()
    local function p(s) print("|cff00ccffJQ Stats:|r " .. s) end
    local w = Weights()
    p(("class %s, role %s%s"):format(tostring(PlayerClass()), ClassWeights.RoleLabel(w.role),
        ClassWeights.IsActive() and "" or "  (retail: Pawn / item level score gear, not these weights)"))
    for slot = (INVSLOT_FIRST_EQUIPPED or 1), (INVSLOT_LAST_EQUIPPED or 19) do
        local link = GetInventoryItemLink("player", slot)
        local stats = link and GetGameData().ItemStats(link)
        if stats then
            local inRanged = slot == JustQuest.Constants.RANGED_SLOT and JustQuest.Constants.IS_FOREVER
            local parts = {}
            for key, value in pairs(stats) do
                local weight, why = WeightFor(w, key, inRanged)
                parts[#parts + 1] = ("%s=%s x%s%s"):format(key, tostring(value), tostring(weight),
                    why and (" (" .. why .. ")") or "")
            end
            table.sort(parts)
            p(("[%d] %s  score %.1f"):format(slot, link, ClassWeights.Score(link, slot) or -1))
            for _, part in ipairs(parts) do p("      " .. part) end
            local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(link)
            local bonus = classID == JustQuest.Constants.ITEM_CLASS.WEAPON and WeaponBonusPct(subclassID) or 0
            if bonus > 0 then p(("      weapon-type bonus (racial / talents): +%g%%"):format(bonus)) end
        end
    end
end

if JustQuest.Constants.IS_FOREVER then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LEVEL_UP")
    frame:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
    for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE" }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    frame:SetScript("OnEvent", function(_, event) ClassWeights.Invalidate(event) end)
end

JustQuest.Core.RegisterModule("ClassWeights", ClassWeights, {"Config", "GameData"})

return ClassWeights
