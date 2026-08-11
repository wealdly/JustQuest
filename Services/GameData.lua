-- GameData.lua — Quest type detection and item analysis

local ADDON_NAME, JustQuest = ...

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
function GameData.TooltipLines(itemLink)
    if not (itemLink and C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return nil end

    local ok, data = pcall(C_TooltipInfo.GetHyperlink, itemLink)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end

    -- Older shapes need the args surfaced before the fields are readable.
    if TooltipUtil and TooltipUtil.SurfaceArgs then
        pcall(TooltipUtil.SurfaceArgs, data)
        for _, line in ipairs(data.lines) do pcall(TooltipUtil.SurfaceArgs, line) end
    end

    return data.lines
end

-- Everything that stops the player using an item. Required level is checked directly
-- because it's certain and cheap; the rest — class, armour proficiency, faction,
-- profession — comes from red tooltip text, which is the game's own verdict and needs no
-- table maintained against it. Anything unexpected degrades to "no requirement failed",
-- so a false "usable" is never worse than the behaviour this replaced.
function GameData.ItemFailsARequirement(itemLink)
    if not itemLink then return false end

    local minLevel = select(5, C_Item.GetItemInfo(itemLink))
    if minLevel and minLevel > (UnitLevel("player") or 0) then return true end

    local lines = GameData.TooltipLines(itemLink)
    if not lines then return false end

    for _, line in ipairs(lines) do
        local c = line.leftColor
        -- RED_FONT_COLOR is (1, 0.125, 0.125); compare loosely rather than exactly.
        if c and c.r and c.g and c.b and c.r > 0.9 and c.g < 0.2 and c.b < 0.2 then
            return true
        end
    end
    return false
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

    local ok, _, _, _, invType, _, classID, subclassID = pcall(C_Item.GetItemInfoInstant, itemLink)
    if not ok then return false end
    if classID ~= JustQuest.Constants.ITEM_CLASS.ARMOR then return false end
    if not ARMOR_TYPED_SLOTS[invType] then return false end

    local want = ClassArmorSubclass()[GameData.GetPlayerClass()]
    if not want then return false end

    return subclassID ~= want
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
function GameData.ItemIsWrongPrimaryStat(itemLink)
    if not itemLink then return false end

    -- No spec chosen yet (levelling, before the class picks one) means no opinion to have.
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex then return false end

    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo)
                    or GetSpecializationInfo
    if not getInfo then return false end
    -- primaryStat is Nilable, and 0 for a spec that has none.
    local ok, _, _, _, _, _, primaryStat = pcall(getInfo, specIndex)
    if not (ok and primaryStat and primaryStat ~= 0) then return false end

    local want = PrimaryStatKey()[primaryStat]
    if not want then return false end

    local okStats, stats = pcall(C_Item.GetItemStats, itemLink)
    if not (okStats and type(stats) == "table") then return false end  -- not cached yet

    if stats[want] then return false end  -- carries ours; nothing to say

    -- Only wrong if it actually carries one of the OTHER primary stats. An item with none
    -- reaches here too, and must pass.
    for _, key in pairs(PrimaryStatKey()) do
        if key ~= want and stats[key] then return true end
    end
    return false
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
