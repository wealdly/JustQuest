-- GameData.lua — Quest type detection and item analysis

local ADDON_NAME, JustQuest = ...

-- Namespaced APIs first. The bare GetSpecialization / GetSpecializationInfo globals are only
-- compatibility shims (Blizzard_DeprecatedSpecialization), and that addon does NOT load on WoW
-- Forever ("AllowLoadGameType: classic, standard") — calling the bare name there throws.
local GetSpecialization     = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
local GetSpecializationInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo

-- C_Item first: the bare item globals are compatibility shims, not guaranteed on every client.
local GetItemInfo  = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local IsUsableItem = (C_Item and C_Item.IsUsableItem) or IsUsableItem

local GameData = {}

-- ============================================================
-- Quest Type Detection
-- ============================================================

local QUEST_TYPE_CHECKERS = {
    world = function(questID) 
        return C_QuestLog and C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(questID) 
    end,
    
    daily = function(questID) 
        if not (C_QuestLog and C_QuestLog.GetLogIndexForQuestID) then
            return false
        end
        
        local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        if not logIndex then
            return false
        end
        
        local questInfo = C_QuestLog.GetInfo and C_QuestLog.GetInfo(logIndex)
        if not questInfo then
            return false
        end
        
        local services = JustQuest.Core.GetModule("Services")
        local dailyFreq = services and services.GetEnumValue("QuestFrequency", "Daily")
        return dailyFreq and questInfo.frequency == dailyFreq
    end,
    
    weekly = function(questID)
        if not (C_QuestLog and C_QuestLog.GetLogIndexForQuestID) then
            -- No log API — use IsRepeatableQuest as broad fallback
            return C_QuestLog and C_QuestLog.IsRepeatableQuest and C_QuestLog.IsRepeatableQuest(questID) or false
        end

        local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        if not logIndex then
            -- Quest not yet in log (pre-accept): IsRepeatableQuest covers daily/weekly/repeatable.
            -- Daily quests return false from the daily checker above, so weekly serves as the
            -- catch-all repeatable gate for quests not yet accepted.
            return C_QuestLog.IsRepeatableQuest and C_QuestLog.IsRepeatableQuest(questID) or false
        end

        local questInfo = C_QuestLog.GetInfo and C_QuestLog.GetInfo(logIndex)
        if not questInfo then return false end

        local services = JustQuest.Core.GetModule("Services")
        local weeklyFreq = services and services.GetEnumValue("QuestFrequency", "Weekly")
        return weeklyFreq and questInfo.frequency == weeklyFreq
    end,
    
    pvp = function(questID)
        local success, tagInfo = pcall(C_QuestLog.GetQuestTagInfo, questID)
        if success and tagInfo then
            if tagInfo.tagID == JustQuest.Constants.QUEST_TAGS.PVP then
                return true
            end
            -- World PVP quests use worldQuestType instead of tagID
            if tagInfo.worldQuestType == JustQuest.Constants.QUEST_TAGS.PVP_WORLD_TYPE then
                return true
            end
        end
        return false
    end,
    
    escort = function(questID)
        -- No reliable API to identify escort quests in modern WoW.
        -- QuestTag 85 = Heroic (not Escort) — matching it would block heroic dungeon quests.
        return false
    end,
    
    profession = function(questID)
        local success, tagInfo = pcall(C_QuestLog.GetQuestTagInfo, questID)
        if success and tagInfo then
            -- More reliable: check for tradeskillLineID presence
            return tagInfo.tradeskillLineID ~= nil and tagInfo.tradeskillLineID > 0
        end
        return false
    end,
}

-- Ordered priority: most-specific type first.
-- pvp before world so a PVP world quest gates on acceptPvP, not acceptRepeatable.
-- daily before weekly; weekly's pre-accept fallback (IsRepeatableQuest) catches both.
local QUEST_TYPE_CHECK_ORDER = { "pvp", "profession", "escort", "world", "daily", "weekly" }

function GameData.GetQuestType(questID)
    if not questID then return "normal" end

    for _, typeName in ipairs(QUEST_TYPE_CHECK_ORDER) do
        local checkFunc = QUEST_TYPE_CHECKERS[typeName]
        if checkFunc and checkFunc(questID) then
            return typeName
        end
    end

    return "normal"
end

function GameData.GetQuestName(questID)
    if not questID then return "Unknown" end
    local services = JustQuest.Core.GetModule("Services")
    local title = services and services.SafeCall(C_QuestLog.GetTitleForQuestID, questID)
    return title or "Unknown"
end

-- ============================================================
-- Item Analysis for Rewards
-- ============================================================

function GameData.ExtractItemInfo(itemLink)
    if not itemLink then
        return nil
    end
    
    local itemInfo = {GetItemInfo(itemLink)}
    if not itemInfo[1] then
        return nil -- Not cached yet
    end
    
    local services = JustQuest.Core.GetModule("Services")
    local name, _, quality, itemLevel, reqLevel, _, _, _, equipSlot, _, vendorPrice, classID, subclassID =
        itemInfo[1], itemInfo[2], itemInfo[3], itemInfo[4], itemInfo[5],
        itemInfo[6], itemInfo[7], itemInfo[8], itemInfo[9], itemInfo[10], itemInfo[11],
        itemInfo[12], itemInfo[13]

    local itemID = services and services.GetItemIDFromLink(itemLink)

    -- Fallback if vendorPrice not available from GetItemInfo
    if not vendorPrice and itemID then
        vendorPrice = GameData.GetVendorPrice(itemID)
    end

    -- Use effective item level from the link (accounts for bonus IDs on scaled quest rewards)
    local effectiveItemLevel = (C_Item and C_Item.GetDetailedItemLevelInfo and
        C_Item.GetDetailedItemLevelInfo(itemLink)) or itemLevel

    -- Detect collectible types using stable enum IDs (locale-independent)
    local IC  = JustQuest.Constants.ITEM_CLASS
    local IMS = JustQuest.Constants.ITEM_MISC_SUBCLASS
    local isMount = classID == IC.MISCELLANEOUS and subclassID == IMS.MOUNT
    local isPet   = classID == IC.BATTLEPET or
                    (classID == IC.MISCELLANEOUS and subclassID == IMS.COMPANION_PET)
    local isToy   = false

    if itemID and C_ToyBox and C_ToyBox.GetToyInfo then
        isToy = C_ToyBox.GetToyInfo(itemID) ~= nil
    end

    return {
        itemLink = itemLink,
        itemID = itemID,
        name = name,
        quality = quality,
        itemLevel = effectiveItemLevel,
        requiredLevel = reqLevel,
        equipSlot = equipSlot,
        isEquippable = equipSlot and equipSlot ~= "",
        vendorPrice = vendorPrice or 0,
        isMount = isMount,
        isPet = isPet,
        isToy = isToy,
        isCollectible = isMount or isPet or isToy,
        -- Body-armor type (cloth/leather/mail/plate = 1/2/3/4); nil for non-armor
        -- and for generic armor (rings/cloaks/necks/trinkets, subclass 0).
        armorSubclass = (classID == IC.ARMOR and subclassID and subclassID >= 1 and subclassID <= 4)
                        and subclassID or nil,
        isWeapon = classID == IC.WEAPON,
    }
end

function GameData.GetEquippedItemLevel(slotID)
    local itemLink = GetInventoryItemLink("player", slotID)
    if not itemLink then
        return 0
    end
    return (C_Item and C_Item.GetDetailedItemLevelInfo and
        C_Item.GetDetailedItemLevelInfo(itemLink)) or 0
end

function GameData.GetCurrentEquippedLevel(equipSlot)
    if not equipSlot or equipSlot == "" then 
        return 0 
    end
    
    local slots = JustQuest.Constants.EQUIPMENT_SLOTS[equipSlot]
    if not slots then 
        return 0 
    end
    
    -- Handle single slot
    if type(slots) == "number" then
        return GameData.GetEquippedItemLevel(slots)
    end
    
    -- A one-hander only competes with the main hand unless the off-hand can take it.
    if equipSlot == "INVTYPE_WEAPON" and not GameData.OneHanderFitsOffHand() then
        return GameData.GetEquippedItemLevel(16)
    end

    -- Handle multiple slots (rings, trinkets) - get lowest
    if type(slots) == "table" then
        local lowest = nil
        for _, slotID in ipairs(slots) do
            local level = GameData.GetEquippedItemLevel(slotID)
            if level > 0 and (not lowest or level < lowest) then
                lowest = level
            end
        end
        return lowest or 0
    end
    
    return 0
end

function GameData.IsCollectibleKnown(itemInfo)
    if not itemInfo or not itemInfo.isCollectible then
        return true
    end
    
    local itemID = itemInfo.itemID
    if not itemID then
        return false
    end
    
    if itemInfo.isMount and C_MountJournal then
        local mountID = C_MountJournal.GetMountFromItem and C_MountJournal.GetMountFromItem(itemID)
        if mountID then
            local _, _, _, _, isUsable, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
            return isCollected == true
        end
    end
    
    if itemInfo.isPet and C_PetJournal then
        local speciesID = C_PetJournal.GetPetInfoByItemID and C_PetJournal.GetPetInfoByItemID(itemID)
        if speciesID then
            local numOwned = C_PetJournal.GetNumCollectedInfo(speciesID)
            return numOwned and numOwned > 0
        end
    end
    
    if itemInfo.isToy and C_ToyBox then
        return C_ToyBox.HasToy(itemID) == true
    end
    
    return false
end

-- Verified Item/ItemXItemEffect/ItemEffect joins in Forever 1.60.1.70790.
-- Item ID -> { consumable subclass, use spell }. Never generalize to a whole subclass.
local FOREVER_ORDINARY_REWARDS = {
    [858] = { 1, 440 },   -- Lesser Healing Potion
    [1251] = { 7, 746 },  -- Linen Bandage
    [4540] = { 5, 433 },  -- Tough Hunk of Bread
}

-- Multi-choice rewards with unpriced utility must not lose to a vendor-value heuristic.
function GameData.RewardReviewReason(itemLink)
    if not itemLink then return "reward data unavailable" end
    local name, _, quality, _, _, _, _, _, equipSlot, _, _, classID, subclassID = GetItemInfo(itemLink)
    if not name or not classID or not quality then return "reward data unavailable" end
    local IC = JustQuest.Constants.ITEM_CLASS
    if classID == IC.RECIPE then return "recipe or learning book" end
    if quality >= 5 then return "special-quality reward" end
    if classID == IC.PROFESSION then return "profession equipment" end
    if equipSlot and equipSlot ~= "" then return nil end
    -- Only ordinary consumables and trade goods are candidates for automatic vendor ranking.
    -- Other classes include containers, quest items, collectibles, and miscellaneous tokens.
    if classID ~= IC.CONSUMABLE and classID ~= IC.TRADEGOODS then return "special reward category" end
    if not C_Item.GetItemSpell then return "reward effect detection unavailable" end
    local spellName, spellID = C_Item.GetItemSpell(itemLink)
    local services = JustQuest.Core.GetModule("Services")
    local itemID = services and services.GetItemIDFromLink(itemLink)
    local ordinary = JustQuest.Constants.IS_FOREVER and FOREVER_ORDINARY_REWARDS[itemID]
    local verifiedUse = ordinary and classID == IC.CONSUMABLE and quality == 1
        and subclassID == ordinary[1] and spellName ~= nil and spellID == ordinary[2]
    if (spellName or spellID) and not verifiedUse then return "usable reward effect" end
    local lines = GameData.TooltipLines(itemLink)
    if not lines or #lines == 0 then return "reward tooltip unavailable" end
    local types = Enum and Enum.TooltipDataLineType
    if not (types and types.ItemSpellTriggerOnUse and types.ItemSpellTriggerOnEquip
            and types.ItemSpellTriggerOnProc) then return "reward effect detection unavailable" end
    for _, line in ipairs(lines) do
        if (line.type == types.ItemSpellTriggerOnUse and not verifiedUse)
           or line.type == types.ItemSpellTriggerOnEquip
           or line.type == types.ItemSpellTriggerOnProc then
            return "reward effect not evaluated"
        end
    end
end

function GameData.IsSignificantReward(choiceIndex)
    local itemLink = GetQuestItemLink and GetQuestItemLink("choice", choiceIndex)
    if not itemLink then 
        return false 
    end
    
    local itemInfo = {GetItemInfo(itemLink)}
    if not itemInfo[1] then 
        return false
    end
    
    local name, _, quality, itemLevel, reqLevel, _, _, _, equipSlot, _, _, _, _, bindType = 
        itemInfo[1], itemInfo[2], itemInfo[3], itemInfo[4], itemInfo[5], 
        itemInfo[6], itemInfo[7], itemInfo[8], itemInfo[9], itemInfo[10], itemInfo[11], itemInfo[12], itemInfo[13], itemInfo[14]
    
    local isEquippable = equipSlot and equipSlot ~= ""
    if not isEquippable then 
        return false 
    end
    
    local playerLevel = UnitLevel("player")
    if reqLevel and reqLevel > playerLevel then 
        return false 
    end
    
    -- BoE items at or above the player's current equipped ilvl may have auction value.
    -- Use a player-relative threshold so it does not over-halt on low-level BoEs.
    if bindType == JustQuest.Constants.BIND_TYPES.EQUIP then
        local playerEquippedIlvl = 0
        if GetAverageItemLevel then
            local _, equipped = GetAverageItemLevel()
            playerEquippedIlvl = equipped or 0
        end
        if itemLevel and playerEquippedIlvl > 0 and itemLevel >= playerEquippedIlvl then
            local services = JustQuest.Core.GetModule("Services")
            if services then
                services.Debug("Rewards", string.format(
                    "Significant reward: %s (BoE ilvl %d >= equipped avg %d)",
                    name, itemLevel, playerEquippedIlvl))
            end
            return true, string.format("BoE item with auction value: %s", name)
        end
    end
    
    -- Legendary/Artifact quality — always manual review
    if quality >= 5 then
        local services = JustQuest.Core.GetModule("Services")
        if services then
            services.Debug("Rewards", string.format("Significant reward: %s (Legendary/Artifact quality %d)", name, quality))
        end
        return true, string.format("legendary/artifact item: %s", name)
    end
    
    -- Epic (q4) NOT significant — common in modern WoW, ilvl comparison handles upgrades
    
    return false
end

-- ============================================================
-- Class and Profession Helpers
-- ============================================================

-- Surfaced tooltip lines for an item link, or nil when the data isn't available yet.
-- The nil is meaningful: a caller that caches a verdict must not record one built from
-- missing data. Every tooltip read goes through here so the surfacing rules — which have
-- moved more than once — live in exactly one place.
local function SurfacedLines(ok, data)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end

    -- Older shapes need the args surfaced before the fields are readable.
    if TooltipUtil and TooltipUtil.SurfaceArgs then
        pcall(TooltipUtil.SurfaceArgs, data)
        for _, line in ipairs(data.lines) do pcall(TooltipUtil.SurfaceArgs, line) end
    end

    return data.lines
end

function GameData.TooltipLines(itemLink)
    if not (itemLink and C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return nil end
    return SurfacedLines(pcall(C_TooltipInfo.GetHyperlink, itemLink))
end

-- Loaded statless gear can have no stat table. Base armor comes from the tooltip.
function GameData.ItemStats(itemLink)
    if not itemLink or not C_Item.GetItemInfo(itemLink) then return nil end
    local ok, stats = pcall(C_Item.GetItemStats, itemLink)
    if not ok or (stats ~= nil and type(stats) ~= "table") then
        local services = JustQuest.Core.GetModule("Services")
        if services then services.Debug("GameData", "GetItemStats failed: " .. tostring(stats)) end
        return nil
    end
    local out = {}
    for key, value in pairs(stats or {}) do
        if type(key) ~= "string" or type(value) ~= "number"
           or value ~= value or math.abs(value) == math.huge then
            local services = JustQuest.Core.GetModule("Services")
            if services then services.Debug("GameData", "Invalid item stat: " .. tostring(key)) end
            return nil
        end
        out[key] = value
    end
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemLink)
    -- Pawn reads weapon DPS from the tooltip. Some Forever weapons omit it from GetItemStats.
    if classID == JustQuest.Constants.ITEM_CLASS.WEAPON and not out.ITEM_MOD_DAMAGE_PER_SECOND_SHORT then
        local dps = GameData.ItemDPS(itemLink)
        if dps == nil then return nil end
        if dps > 0 then out.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = dps end
    end
    if not out.RESISTANCE0_NAME then
        if classID == JustQuest.Constants.ITEM_CLASS.ARMOR then
            local armor = GameData.ItemArmor(itemLink)
            if armor == nil then return nil end
            if armor > 0 then out.RESISTANCE0_NAME = armor end
        end
    end
    return out
end

-- Same, for the item actually sitting in a bag slot. Not interchangeable with the hyperlink
-- call: only this one reflects per-instance state, so a lockbox whose lock has already been
-- picked stops reading as locked.
function GameData.BagTooltipLines(bagID, slotID)
    if not (bagID and slotID and C_TooltipInfo and C_TooltipInfo.GetBagItem) then return nil end
    return SurfacedLines(pcall(C_TooltipInfo.GetBagItem, bagID, slotID))
end

-- Everything that stops the player using an item. Required level is checked directly
-- because it's certain and cheap; the rest — class, armour proficiency, faction,
-- profession — comes from red tooltip text, which is the game's own verdict and needs no
-- table maintained against it. Anything unexpected degrades to "no requirement failed",
-- so a false "usable" is never worse than the behaviour this replaced.
function GameData.ItemFailsARequirement(itemLink, tooltipLines)
    if not itemLink then return false end

    local minLevel = select(5, C_Item.GetItemInfo(itemLink))
    if minLevel and minLevel > (UnitLevel("player") or 0) then return true end

    if GameData.LacksProficiency(itemLink) then return true end

    local lines = tooltipLines or GameData.TooltipLines(itemLink)
    if not lines then return false end

    -- Both columns: the weapon / armour type a character can't use is the RIGHT-hand text of
    -- the slot line ("Ranged ... Bow"), and reading only the left let unusable bows through.
    local function IsRed(c)
        -- RED_FONT_COLOR is (1, 0.125, 0.125); compare loosely rather than exactly.
        return c and c.r and c.g and c.b and c.r > 0.9 and c.g < 0.2 and c.b < 0.2
    end
    for _, line in ipairs(lines) do
        if IsRed(line.leftColor) or IsRed(line.rightColor) then return true end
    end
    return false
end

-- WoW Forever trains weapon and armour skills, vanilla-style: a warrior can't fire a bow until a
-- weapon master teaches Bows, a hunter can't wear mail until 40. The proficiency spells are the
-- game's own record, so the answer is IsPlayerSpell on the one for the item's type.
-- [item subclass] = proficiency spell, verified in Forever's SpellName / SkillLineAbility
-- (build 1.60.1.70245). Not used on retail, which has no trained weapon skills.
local WEAPON_PROFICIENCY = {
    [0] = 196, [1] = 197, [2] = 264, [3] = 266, [4] = 198, [5] = 199, [6] = 200, [7] = 201,
    [8] = 202, [10] = 227, [13] = 15590, [15] = 1180, [16] = 2567, [18] = 5011, [19] = 5009,
}  -- axes, bows, guns, maces, polearms, swords, staves, fist, daggers, thrown, crossbows, wands
local ARMOR_PROFICIENCY = { [1] = 9078, [2] = 9077, [3] = 8737, [4] = 750, [6] = 9116 }
local CLOTH_PROFICIENCY = 9078  -- every Forever class knows it (class mask 1503)

function GameData.LacksProficiency(itemLink)
    if not (itemLink and JustQuest.Constants.IS_FOREVER and IsPlayerSpell) then return false end
    -- Every class knows Cloth. If it reads as unknown, this client isn't reporting passive
    -- proficiencies at all — and hiding every weapon on the strength of that would be far worse
    -- than the occasional unusable bow, so the check stands down.
    if not IsPlayerSpell(CLOTH_PROFICIENCY) then return false end

    local ok, _, _, _, _, _, classID, subclassID = pcall(C_Item.GetItemInfoInstant, itemLink)
    if not ok then return false end
    local IC = JustQuest.Constants.ITEM_CLASS
    local spell = (classID == IC.WEAPON and WEAPON_PROFICIENCY[subclassID])
               or (classID == IC.ARMOR and ARMOR_PROFICIENCY[subclassID])
    return spell and not IsPlayerSpell(spell) or false
end

-- The armour type each class is meant to wear. Proficiency is NOT the same question:
-- a druid can physically equip cloth, so nothing about the item or the tooltip marks it
-- as wrong — a stat scorer sees only stats, and a high-stat cloth chest beats the leather
-- one on paper while costing the class its armour-specialization bonus. There is no API
-- for this (the client never exposes a class's armour type), so it is a table; it changes
-- only when a class is added.
--
-- Keyed by the locale-independent class token from UnitClass, not the numeric ID.
local CLASS_ARMOR_SUBCLASS  -- built on first use: Enum isn't guaranteed at file scope
local function ClassArmorSubclass()
    if CLASS_ARMOR_SUBCLASS then return CLASS_ARMOR_SUBCLASS end
    local sub = (Enum and Enum.ItemArmorSubclass) or {}
    local CLOTH, LEATHER = sub.Cloth or 1, sub.Leather or 2
    local MAIL,  PLATE   = sub.Mail  or 3, sub.Plate   or 4
    CLASS_ARMOR_SUBCLASS = {
        WARRIOR = PLATE,   PALADIN = PLATE,   DEATHKNIGHT = PLATE,
        HUNTER  = MAIL,    SHAMAN  = MAIL,    EVOKER      = MAIL,
        ROGUE   = LEATHER, DRUID   = LEATHER, MONK        = LEATHER,
        DEMONHUNTER = LEATHER,
        PRIEST  = CLOTH,   MAGE    = CLOTH,   WARLOCK     = CLOTH,
    }
    return CLASS_ARMOR_SUBCLASS
end

-- Only the slots that HAVE a class armour type. A cloak is Cloth-subclass for every
-- class alive, and necks/rings/trinkets/off-hand frills are Generic or Miscellaneous —
-- filtering any of those by armour type would hide gear everyone is supposed to wear.
local ARMOR_TYPED_SLOTS = {
    INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true,
    INVTYPE_ROBE = true, INVTYPE_WAIST = true,    INVTYPE_LEGS  = true,
    INVTYPE_FEET = true, INVTYPE_WRIST = true,    INVTYPE_HAND  = true,
}

-- True when this is body armour of an armour type the player's class is not meant to
-- wear. Anything unreadable or unrecognised (a new class token, a non-armour item)
-- answers false: the failure direction has to be "don't filter", or a client change
-- silently hides every upgrade the player owns.
function GameData.ItemIsWrongArmorType(itemLink)
    if not itemLink then return false end
    -- Not a rule on WoW Forever. Retail's reason for it — the armour-specialization bonus for
    -- wearing your own type — doesn't exist in vanilla, where a warrior in leather bracers is
    -- just a warrior with bracers. There the class-weight score decides, and it already counts
    -- armour, so heavier pieces win on their own when stats are equal. (Gating here hid a
    -- 29-armour pair of bracers from a warrior wearing 4-armour cloth ones.)
    if JustQuest.Constants.IS_FOREVER then return false end

    local ok, _, _, _, invType, _, classID, subclassID = pcall(C_Item.GetItemInfoInstant, itemLink)
    if not ok then return false end
    if classID ~= JustQuest.Constants.ITEM_CLASS.ARMOR then return false end
    if not ARMOR_TYPED_SLOTS[invType] then return false end

    local want = ClassArmorSubclass()[GameData.GetPlayerClass()]
    if not want then return false end

    return subclassID ~= want
end

-- An armour item's armour value, read off its tooltip ("29 Armor") — GetItemStats doesn't carry
-- base armour, and returns nothing at all for an item with no other stats. nil when the tooltip
-- isn't available yet; 0 when there's no armour line.
local ARMOR_PATTERN  -- built on first use from the localized "%s Armor" template
function GameData.ItemArmor(itemLink)
    local lines = GameData.TooltipLines(itemLink)
    if not lines then return nil end
    if not ARMOR_PATTERN then
        local template = ARMOR_TEMPLATE or "%s Armor"
        ARMOR_PATTERN = "^" .. template:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
                                       :gsub("%%[sd]", "([%%d,%%.]+)") .. "$"
    end
    for _, line in ipairs(lines) do
        local text = line and line.leftText
        local value = text and text:match(ARMOR_PATTERN)
        if value then return tonumber((value:gsub("[,%.]", ""))) or 0 end
    end
    return 0
end

-- A weapon's tooltip DPS ("(4.62 damage per second)"). nil when the tooltip isn't available
-- yet; 0 when there's no DPS line.
local DPS_PATTERN
function GameData.ItemDPS(itemLink)
    local lines = GameData.TooltipLines(itemLink)
    if not lines then return nil end
    if not DPS_PATTERN then
        local template = DPS_TEMPLATE or "(%s damage per second)"
        DPS_PATTERN = "^" .. template:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
                                     :gsub("%%[sd]", "([%%d,%%.]+)") .. "$"
    end
    for _, line in ipairs(lines) do
        for _, text in ipairs({ line and line.leftText, line and line.rightText }) do
            local value = type(text) == "string" and text:match(DPS_PATTERN)
            if value then
                -- One separator is the decimal mark; anything before it groups thousands.
                local whole, fraction = value:match("^(.-)[,%.](%d+)$")
                local number = whole and tonumber(whole:gsub("[,%.]", "") .. "." .. fraction)
                    or tonumber((value:gsub("[,%.]", "")))
                return number or 0
            end
        end
    end
    return 0
end

-- Whether a one-handed weapon competes for the off-hand slot at all. Only for a character who
-- can dual wield, and only against another weapon or an empty hand: a shield or held-in-off-hand
-- item is a different kind of gear, not a weaker weapon. Without this a caster was offered a
-- mace for their off-hand frill (an equip that fails), and a tank a sword for their shield.
-- Profession tools that happen to be weapons. They have weapon damage, so a damage scorer rates
-- the Mining Pick above a starting sword — but equipping one is never the point of carrying it.
-- Two signals: the "Miscellaneous" weapon subclass, which on WoW Forever holds exactly the four
-- basic tools (every other item in it is an NPC display model), and fishing poles; plus the
-- upgraded tools Blizzard filed under real weapon types, by ID (WoW Forever DB2: weapons with a
-- TotemCategoryID outside the Miscellaneous subclass, build 1.60.1.70205).
local TOOL_WEAPONS = {
    [6206]   = true,  -- Rock Chipper
    [269716] = true,  -- Keen Skinning Knife
    [285280] = true,  -- Mithril Blacksmith Hammer
    [285281] = true,  -- Arcanite Blacksmith Hammer
}

function GameData.IsProfessionTool(itemLink)
    if not itemLink then return false end
    local ok, itemID, _, _, _, _, classID, subclassID = pcall(C_Item.GetItemInfoInstant, itemLink)
    if not ok or classID ~= JustQuest.Constants.ITEM_CLASS.WEAPON then return false end
    local WS = JustQuest.Constants.WEAPON_SUBCLASS
    return subclassID == WS.GENERIC or subclassID == WS.FISHING_POLE or TOOL_WEAPONS[itemID] or false
end

-- The inventory slots an item of this equip location can replace, as a list (EQUIPMENT_SLOTS
-- mixes numbers and lists), with the one-hander rule below applied. nil for unknown locations.
function GameData.ComparableSlots(equipSlot)
    local slots = equipSlot and JustQuest.Constants.EQUIPMENT_SLOTS[equipSlot]
    if not slots then return nil end
    if type(slots) == "number" then return { slots } end
    if equipSlot == "INVTYPE_WEAPON" and not GameData.OneHanderFitsOffHand() then return { 16 } end
    return slots
end

function GameData.OneHanderFitsOffHand()
    if not (CanDualWield and CanDualWield()) then return false end
    local main = GetInventoryItemLink("player", 16)
    local off = GetInventoryItemLink("player", 17)
    if JustQuest.Constants.IS_FOREVER and main
       and select(4, C_Item.GetItemInfoInstant(main)) == "INVTYPE_2HWEAPON"
       and not off then return false end
    if not off then return true end
    local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, off)
    return ok and classID == JustQuest.Constants.ITEM_CLASS.WEAPON
end

function GameData.DisplacedOffHand(invType, dest)
    if dest ~= 16 or invType ~= "INVTYPE_2HWEAPON" then return nil end
    local off = GetInventoryItemLink("player", 17)
    if not off then return nil end
    local main = GetInventoryItemLink("player", 16)
    if main and select(4, C_Item.GetItemInfoInstant(main)) == "INVTYPE_2HWEAPON" then return nil end
    return off
end

-- The item stat each primary stat is named by. Built on first use: the LE_UNIT_STAT globals
-- are not guaranteed to exist at file scope. Stats come back keyed by the game's own
-- ITEM_MOD_* global names, the same keys the advisor's stat-delta line reads.
local PRIMARY_STAT_KEY
local function PrimaryStatKey()
    if PRIMARY_STAT_KEY then return PRIMARY_STAT_KEY end
    PRIMARY_STAT_KEY = {
        [LE_UNIT_STAT_STRENGTH  or 1] = "ITEM_MOD_STRENGTH_SHORT",
        [LE_UNIT_STAT_AGILITY   or 2] = "ITEM_MOD_AGILITY_SHORT",
        [LE_UNIT_STAT_INTELLECT or 4] = "ITEM_MOD_INTELLECT_SHORT",
    }
    return PRIMARY_STAT_KEY
end

-- True when the item carries a primary stat that isn't the one the player's spec runs on —
-- the Agility spear in a Restoration druid's bag. Nothing else catches it: the item is legal
-- to equip, it has no armour type to be wrong about, and the tooltip shows no red text, so a
-- scorer reading raw stats sees a big number and calls it an upgrade.
--
-- Every unknown answers false, and so does an item with NO primary stat at all — cloaks,
-- necks and rings often have none, and filtering those would hide gear every spec wears. The
-- failure direction has to be "don't filter": a wrong verdict here hides real upgrades.
-- The spec's primary stat as an ITEM_MOD key, or nil when there's no answer: no spec chosen yet,
-- or a spec without one (every Forever spec: ChrSpecialization.PrimaryStatPriority = 0).
local function SpecPrimaryStatKey()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex then return nil end
    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo)
                    or GetSpecializationInfo
    if not getInfo then return nil end
    -- primaryStat is Nilable, and 0 for a spec that has none.
    local ok, _, _, _, _, _, primaryStat = pcall(getInfo, specIndex)
    if not (ok and primaryStat and primaryStat ~= 0) then return nil end
    return PrimaryStatKey()[primaryStat]
end

function GameData.ItemIsWrongPrimaryStat(itemLink)
    if not itemLink or JustQuest.Constants.IS_FOREVER then return false end
    local want = SpecPrimaryStatKey()
    if not want then return false end

    local okStats, stats = pcall(C_Item.GetItemStats, itemLink)
    if not (okStats and type(stats) == "table") then return false end  -- not cached yet

    -- Wrong only if it carries a primary stat that isn't ours AND none that is. An item with
    -- no primary stat at all (cloaks, necks, rings) must pass, and so must a mixed one.
    local carriesOurs, carriesOther = false, false
    for _, key in pairs(PrimaryStatKey()) do
        if stats[key] then
            local ours = key == want
            if ours then carriesOurs = true else carriesOther = true end
        end
    end
    return carriesOther and not carriesOurs
end

function GameData.CanPlayerUseItem(itemLink)
    if not itemLink then return false end
    if GameData.ItemFailsARequirement(itemLink) then return false end

    local services = JustQuest.Core.GetModule("Services")
    return services and services.SafeCall(IsUsableItem, itemLink) or false
end

function GameData.GetPlayerClass()
    return select(2, UnitClass("player"))
end

function GameData.GetPlayerLevel()
    return UnitLevel("player")
end

-- ============================================================
-- Profession Support
-- ============================================================

function GameData.HasProfession(tradeskillLineID)
    if not tradeskillLineID then return false end
    
    if not C_TradeSkillUI.IsTradeSkillLinked() then
        local professionInfo = C_TradeSkillUI.GetTradeSkillLineInfoByID and 
                              C_TradeSkillUI.GetTradeSkillLineInfoByID(tradeskillLineID)
        return professionInfo and professionInfo.skillLevel > 0
    end
    
    return false
end

function GameData.GetProfessionSkillLevel(tradeskillLineID)
    if not tradeskillLineID then return 0 end
    
    local professionInfo = C_TradeSkillUI.GetTradeSkillLineInfoByID and 
                          C_TradeSkillUI.GetTradeSkillLineInfoByID(tradeskillLineID)
    return professionInfo and professionInfo.skillLevel or 0
end

-- ============================================================
-- Currency and Economy
-- ============================================================

function GameData.GetVendorPrice(itemID)
    if not itemID then return 0 end
    return select(11, GetItemInfo(itemID)) or 0
end

function GameData.GetPlayerMoney()
    return GetMoney()
end

-- ============================================================
-- Quest Log Helpers
-- ============================================================

function GameData.IsQuestComplete(questID)
    if not questID then return false end
    
    local success, isComplete = pcall(C_QuestLog.IsComplete, questID)
    if success and isComplete then return true end
    
    local logIndex = C_QuestLog and C_QuestLog.GetLogIndexForQuestID(questID)
    if not logIndex then return false end
    
    local questInfo = C_QuestLog.GetInfo(logIndex)
    return questInfo and questInfo.isComplete
end

function GameData.IsQuestInLog(questID)
    if not questID then return false end
    
    local logIndex = C_QuestLog and C_QuestLog.GetLogIndexForQuestID(questID)
    return logIndex ~= nil
end

-- ============================================================
-- Utility Functions
-- ============================================================

function GameData.FormatMoney(copper)
    if not copper or copper == 0 then return "0" end
    
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    copper = copper % 100
    
    local result = ""
    if gold > 0 then
        result = result .. gold .. "|cffffd700g|r"
    end
    if silver > 0 then
        result = result .. silver .. "|cffc7c7cfs|r"
    end
    if copper > 0 or result == "" then
        result = result .. copper .. "|cffeda55fc|r"
    end
    
    return result
end

-- ============================================================
-- Module Registration
-- ============================================================

JustQuest.Core.RegisterModule("GameData", GameData, {"Services"})

return GameData
