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
        local weeklyFreq = services and services.GetEnumValue("QuestFrequency", "Weekly")
        return weeklyFreq and questInfo.frequency == weeklyFreq
    end,
    
    pvp = function(questID)
        local success, tagInfo = pcall(C_QuestLog.GetQuestTagInfo, questID)
        if success and tagInfo then
            return tagInfo.tagID == JustQuest.Constants.QUEST_TAGS.PVP
        end
        return false
    end,
    
    escort = function(questID)
        local success, tagInfo = pcall(C_QuestLog.GetQuestTagInfo, questID)
        if success and tagInfo then
            -- Escort tag ID 85 is also used for escort quests
            return tagInfo.tagID == JustQuest.Constants.QUEST_TAGS.ESCORT or tagInfo.tagID == 85
        end
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

function GameData.GetQuestType(questID)
    if not questID then return "normal" end
    
    for typeName, checkFunc in pairs(QUEST_TYPE_CHECKERS) do
        if checkFunc(questID) then
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
    local name, _, quality, itemLevel, reqLevel, itemType, itemSubType, _, equipSlot, _, vendorPrice = 
        itemInfo[1], itemInfo[2], itemInfo[3], itemInfo[4], itemInfo[5], 
        itemInfo[6], itemInfo[7], itemInfo[8], itemInfo[9], itemInfo[10], itemInfo[11]
    
    local itemID = services and services.GetItemIDFromLink(itemLink)
    
    -- Fallback if vendorPrice not available from GetItemInfo
    if not vendorPrice and itemID then
        vendorPrice = GameData.GetVendorPrice(itemID)
    end
    
    -- Detect collectible types
    local isMount = itemType and itemType == "Mount" or (itemSubType and itemSubType == "Mount")
    local isPet = itemType and itemType == "Battle Pets" or (itemSubType and itemSubType:find("Pet"))
    local isToy = false
    
    -- Check if item is a toy
    if itemID and C_ToyBox and C_ToyBox.GetToyInfo then
        local toyInfo = C_ToyBox.GetToyInfo(itemID)
        isToy = toyInfo ~= nil
    end
    
    return {
        itemLink = itemLink,
        itemID = itemID,
        name = name,
        quality = quality,
        itemLevel = itemLevel,
        requiredLevel = reqLevel,
        itemType = itemType,
        itemSubType = itemSubType,
        equipSlot = equipSlot,
        isEquippable = equipSlot and equipSlot ~= "",
        vendorPrice = vendorPrice or 0,
        isMount = isMount,
        isPet = isPet,
        isToy = isToy,
        isCollectible = isMount or isPet or isToy,
    }
end

function GameData.GetEquippedItemLevel(slotID)
    local itemLink = GetInventoryItemLink("player", slotID)
    if not itemLink then 
        return 0 
    end
    
    local location = ItemLocation:CreateFromEquipmentSlot(slotID)
    if location and location:IsValid() then
        return C_Item.GetCurrentItemLevel(location) or 0
    end
    return 0
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
    
    -- BoE items with significant ilvl — may have auction value, needs manual decision
    if bindType == JustQuest.Constants.BIND_TYPES.EQUIP and itemLevel and itemLevel >= 60 then
        local services = JustQuest.Core.GetModule("Services")
        if services then
            services.Debug("Rewards", string.format("Significant reward: %s (BoE ilvl %d - auction value)", name, itemLevel))
        end
        return true, string.format("BoE item with auction value: %s", name)
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

function GameData.CanPlayerUseItem(itemLink)
    if not itemLink then return false end
    
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
-- Initialization
-- ============================================================

function GameData.Initialize()
end

-- ============================================================
-- Module Registration
-- ============================================================

JustQuest.Core.RegisterModule("GameData", GameData, {"Services"})

return GameData
