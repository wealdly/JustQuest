-- RewardEngine.lua — Quest reward selection with item value analysis

local ADDON_NAME, JustQuest = ...

local RewardEngine = {}

-- Module cache (lazy initialization)
local moduleCache = {}

local function GetServices()
    if not moduleCache.Services then
        moduleCache.Services = JustQuest.Core.GetModule("Services")
    end
    return moduleCache.Services
end

local function GetConfig()
    if not moduleCache.Config then
        moduleCache.Config = JustQuest.Core.GetModule("Config")
    end
    return moduleCache.Config
end

local function GetSafetyEngine()
    if not moduleCache.SafetyEngine then
        moduleCache.SafetyEngine = JustQuest.Core.GetModule("SafetyEngine")
    end
    return moduleCache.SafetyEngine
end

local function GetGameData()
    if not moduleCache.GameData then
        moduleCache.GameData = JustQuest.Core.GetModule("GameData")
    end
    return moduleCache.GameData
end

-- ============================================================
-- Reward Processing State
-- ============================================================

local processingReward = false
local rewardRetryCount = 0
local MAX_REWARD_RETRIES = 4
local REWARD_RETRY_DELAY = 0.25

-- ============================================================
-- Item Data Readiness
-- ============================================================

--- Check if item data is available for all reward choices.
--- GetItemInfo returns nil on first call for uncached items; GetQuestItemLink
--- can also return nil if the quest frame hasn't finished loading.
--- @return boolean allReady  true if data is available for every choice
--- @return number  loadedCount  how many items have cached data
local function AreRewardItemsCached(numChoices)
    local loadedCount = 0
    local itemChoiceCount = 0
    for i = 1, numChoices do
        -- Currency choice slots have no item link; skip them for cache counting
        local lootType = GetQuestItemInfoLootType and GetQuestItemInfoLootType("choice", i) or 0
        if lootType == 0 then  -- LOOT_LIST_ITEM
            itemChoiceCount = itemChoiceCount + 1
            local itemLink = GetQuestItemLink and GetQuestItemLink("choice", i)
            if itemLink then
                local name = GetItemInfo(itemLink)
                if name then
                    loadedCount = loadedCount + 1
                end
            end
        end
    end
    if itemChoiceCount == 0 then return true, 0 end
    return loadedCount == itemChoiceCount, loadedCount
end

--- Request item data for all reward choices so the client caches them.
local function RequestRewardItemData(numChoices)
    for i = 1, numChoices do
        local itemLink = GetQuestItemLink and GetQuestItemLink("choice", i)
        if itemLink then
            -- GetItemInfo triggers a background load request on cache miss
            GetItemInfo(itemLink)
            -- Also use C_Item API if available for reliability
            local itemID = itemLink:match("item:(%d+)")
            if itemID and C_Item and C_Item.RequestLoadItemDataByID then
                pcall(C_Item.RequestLoadItemDataByID, tonumber(itemID))
            end
        end
    end
end

-- ============================================================
-- Core Reward Selection
-- ============================================================

function RewardEngine.ProcessQuestReward()
    if processingReward then return end
    processingReward = true
    JustQuest._lastProcessingTime = GetTime()
    
    local services = GetServices()
    local config = GetConfig()
    local safetyEngine = GetSafetyEngine()
    local gameData = GetGameData()
    
    if not (services and services.ValidateAutomationPreconditions()) then
        processingReward = false
        if services and services.Debug then
            services.Debug("Rewards", "ProcessQuestReward blocked - preconditions failed")
        end
        if safetyEngine then
            safetyEngine.EndProcessing("reward_preconditions_failed")
        end
        return
    end
    
    local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
    
    if numChoices <= 1 then
        RewardEngine.SelectReward(numChoices == 1 and 1 or nil)
        return
    end
    
    -- Multi-choice: check if item data is cached before making decisions.
    -- GetItemInfo returns nil on first call for uncached items, which causes
    -- wrong quality/value reads and incorrect reward selection.
    local allCached, loadedCount = AreRewardItemsCached(numChoices)
    if not allCached then
        RequestRewardItemData(numChoices)
        rewardRetryCount = rewardRetryCount + 1
        
        if rewardRetryCount <= MAX_REWARD_RETRIES then
            if services.Debug then
                services.Debug("Rewards", string.format(
                    "Item data not ready (%d/%d cached, attempt %d/%d) - retrying in %.2fs",
                    loadedCount, numChoices, rewardRetryCount, MAX_REWARD_RETRIES, REWARD_RETRY_DELAY))
            end
            processingReward = false  -- Allow re-entry on retry/QUEST_ITEM_UPDATE
            if services.ScheduleOnce then
                services.CancelScheduled("reward_data_retry")
                services.ScheduleOnce("reward_data_retry", REWARD_RETRY_DELAY, function()
                    RewardEngine.ProcessQuestReward()
                end)
            end
            return
        end
        
        -- Max retries exhausted: proceed with whatever data we have
        if services.Debug then
            services.Debug("Rewards", string.format(
                "Item data retry exhausted (%d/%d cached) - proceeding with partial data",
                loadedCount, numChoices))
        end
    end
    rewardRetryCount = 0  -- Reset for next quest
    
    if config and config.Get("quest", "autoReward") then
        if config.Get("quest", "simpleRewardMode") then
            if services.Debug then
                services.Debug("Rewards", "Simple mode: selecting highest vendor value")
            end
            local bestIdx = RewardEngine.GetHighestVendorValue(numChoices)
            RewardEngine.SelectReward(bestIdx)
            return
        end
        
        if RewardEngine.AllRewardsTrivial(numChoices) then
            if services.Debug then
                services.Debug("Rewards", "All trivial rewards: fast vendor value selection")
            end
            local bestIdx = RewardEngine.GetHighestVendorValue(numChoices)
            RewardEngine.SelectReward(bestIdx)
            return
        end
        
        -- Smart analysis for significant rewards
        local rewardChoice = RewardEngine.GetRecommendedChoice(numChoices)
        if rewardChoice then
            RewardEngine.SelectReward(rewardChoice)
        else
            services.Debug("Rewards", "Significant rewards detected - manual selection required")
            RewardEngine.HaltForManualSelection("multiple_significant_rewards")
        end
    else
        services.Debug("Rewards", "Auto-reward disabled")
        RewardEngine.HaltForManualSelection("auto_reward_disabled")
    end
    processingReward = false
end

function RewardEngine.SelectReward(choiceIndex)
    local services = GetServices()
    local safetyEngine = GetSafetyEngine()

    -- Mirror Blizzard's own reward button: if the quest costs money, do not auto-confirm.
    -- GetQuestReward would silently spend gold without the normal confirmation popup.
    local moneyRequired = GetQuestMoneyToGet and GetQuestMoneyToGet() or 0
    if moneyRequired > 0 then
        if services and services.Debug then
            services.Debug("Rewards", "Quest requires payment (" .. moneyRequired .. " copper) — halting for manual confirmation")
        end
        RewardEngine.HaltForManualSelection("expensive_quest_requires_payment")
        return
    end

    services.Debug("Rewards", "Selecting reward: " .. tostring(choiceIndex or "default"))
    
    services.SafeCallWithRetry(GetQuestReward, 3, choiceIndex)
    JustQuest._stats.getRewardCalls = (JustQuest._stats.getRewardCalls or 0) + 1
    JustQuest._lastProcessingTime = GetTime()

    if services.Debug then
        services.Debug("Rewards", "Issued GetQuestReward(" .. tostring(choiceIndex or "nil") .. ")")
    end
    
    processingReward = false
    
    -- Trust WoW event system: QUEST_TURNED_IN will fire and reset state to IDLE
    -- Schedule a safety fallback in case the event doesn't fire (e.g., GetQuestReward failed)
    if services and services.ScheduleOnce then
        local fallbackTimeout = JustQuest.Constants.TIMING.AUTO_RECOVERY_TIMEOUT or 5.0
        services.CancelScheduled("reward_select_fallback")
        services.ScheduleOnce("reward_select_fallback", fallbackTimeout, function()
            local s = GetSafetyEngine()
            if s and s.IsBusy() then
                -- Still BUSY after timeout - GetQuestReward may have failed
                local frameOpen = (QuestFrame and QuestFrame:IsShown()) or
                                 (QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown())
                if not frameOpen then
                    services.Debug("Rewards", "Fallback recovery: QUEST_TURNED_IN did not fire, resetting state")
                    s.EndProcessing("reward_fallback_recovery")
                end
            end
        end)
    end
end

-- ============================================================
-- Fast Path: Trivial Rewards
-- ============================================================

function RewardEngine.AllRewardsTrivial(numChoices)
    -- Trivial = all choices are low-quality non-equippable items with no special value.
    -- Currency choices and any equippable gear (even uncommon/green) always go through
    -- smart analysis: green gear can be a real upgrade in current-content leveling.
    local checkedCount = 0
    for i = 1, numChoices do
        local lootType = GetQuestItemInfoLootType and GetQuestItemInfoLootType("choice", i) or 0
        if lootType == 1 then return false end  -- currency choice is never trivial

        local itemLink = GetQuestItemLink and GetQuestItemLink("choice", i)
        if itemLink then
            local _, _, quality, _, _, _, _, _, equipSlot = GetItemInfo(itemLink)
            if quality then
                checkedCount = checkedCount + 1
                if equipSlot and equipSlot ~= "" then
                    return false  -- any equippable gear warrants smart analysis
                end
                if quality >= 3 then
                    return false  -- rare+ non-equippable also warrants analysis
                end
            end
        end
    end
    return checkedCount > 0
end

function RewardEngine.GetHighestVendorValue(numChoices)
    local bestIdx = 1
    local bestValue = 0
    
    for i = 1, numChoices do
        local itemLink = GetQuestItemLink and GetQuestItemLink("choice", i)
        if itemLink then
            local _, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(itemLink)
            if vendorPrice and vendorPrice > bestValue then
                bestValue = vendorPrice
                bestIdx = i
            end
        end
    end
    
    return bestIdx
end

function RewardEngine.HaltForManualSelection(reason)
    local services = GetServices()
    local safetyEngine = GetSafetyEngine()
    
    if services then
        services.Debug("Rewards", "HALT: " .. tostring(reason))
        -- Notify player for non-obvious halts (skip for deliberately disabled auto-reward)
        if reason ~= "auto_reward_disabled" and services.OutputHalt then
            services.OutputHalt(reason)
        end
    end
    
    if safetyEngine then
        safetyEngine.EndProcessing(reason or "manual_reward_selection")
    end
end

-- ============================================================
-- Reward Analysis
-- ============================================================

function RewardEngine.AnalyzeRewardChoices(numChoices)
    local choices = {}
    local gameData = GetGameData()
    if not gameData then return choices end
    
    for i = 1, numChoices do
        local lootType = GetQuestItemInfoLootType and GetQuestItemInfoLootType("choice", i) or 0
        if lootType == 1 then  -- LOOT_LIST_CURRENCY: no item link, handle as currency
            local name = select(1, GetQuestItemInfo("choice", i)) or "Currency Reward"
            choices[i] = {
                index = i,
                itemLink = nil,
                name = name,
                quality = 1,
                itemLevel = 0,
                vendorPrice = 0,
                equipSlot = "",
                isEquippable = false,
                isCurrency = true,
                canUse = true
            }
        else
            local itemLink = GetQuestItemLink and GetQuestItemLink("choice", i)
            if not itemLink then
                choices[i] = {
                    index = i,
                    itemLink = nil,
                    name = "Unknown",
                    quality = 0,
                    itemLevel = 0,
                    vendorPrice = 0,
                    equipSlot = "",
                    isEquippable = false,
                    canUse = true
                }
            else
                local choice = gameData.ExtractItemInfo(itemLink)
                if not choice then
                    choice = {
                        index = i,
                        itemLink = itemLink,
                        name = "Unknown",
                        quality = 0,
                        itemLevel = 0,
                        vendorPrice = 0,
                        equipSlot = "",
                        isEquippable = false,
                        canUse = true
                    }
                end

                if choice.isCollectible then
                    choice.isCollectibleKnown = gameData.IsCollectibleKnown and gameData.IsCollectibleKnown(choice)
                end

                -- Lazy equipment comparison: only for Uncommon+ items
                if choice.isEquippable and choice.quality and choice.quality >= 2 then
                    choice.upgradeInfo = RewardEngine.CompareWithEquipped(choice)
                end

                choice.canUse = gameData.CanPlayerUseItem(itemLink)
                choice.isSignificant = gameData.IsSignificantReward and gameData.IsSignificantReward(i) or false
                choice.index = i
                choices[i] = choice
            end
        end
    end
    
    return choices
end

-- ============================================================
-- Equipment Comparison
-- ============================================================

-- Returns the spec index (1–4) that should drive Pawn scale selection.
-- Honours the loot specialization override (right-click portrait → Loot Specialization):
-- if the player has pinned a different spec for loot, we respect that preference so
-- tank/healer loot scales are used even while playing a DPS spec.
-- GetLootSpecialization() returns a global spec ID; Pawn stores the 1-4 index that
-- GetSpecialization() returns, so we convert by probing GetSpecializationInfo(i).
local function GetEffectiveSpecIndex()
    local config = JustQuest.Core.GetModule("Config")
    local useLootSpec = not config or config.Get("quest", "pawnUseLootSpec") ~= false
    if useLootSpec then
        local lootSpecID = GetLootSpecialization and GetLootSpecialization() or 0
        if lootSpecID and lootSpecID > 0 then
            -- WoW has at most 4 specs per class; iterate until we find the matching index.
            for i = 1, 4 do
                local id = GetSpecializationInfo and GetSpecializationInfo(i)
                if not id then break end
                if id == lootSpecID then return i end
            end
        end
    end
    -- Loot spec disabled, = 0 ("Current Specialization"), or conversion failed: use active spec.
    return GetSpecialization and GetSpecialization() or nil
end

-- Returns { isUpgrade=bool, pawnPercentUpgrade=number } when Pawn can give a definitive
-- result for the player's CURRENT spec, or nil to signal "fall back to ilvl comparison".
--
-- Scale selection priority:
--   1. Scales tagged to the player's current class+spec (Scale.ClassID + Scale.SpecID match)
--   2. Scales tagged to the player's class only (Scale.ClassID matches, no SpecID)
--   3. Untagged/generic user scales (no ClassID)
--
-- Scales for other classes or other specs are ignored entirely so a Holy Paladin
-- scale does not influence a Retribution Paladin's reward pick.
local function GetPawnUpgradeForCurrentSpec(itemLink)
    if not (PawnGetItemData and PawnIsItemAnUpgrade and PawnIsScaleVisible
            and PawnCommon and PawnCommon.Scales) then
        return nil
    end

    -- Respect the user's option to disable Pawn scoring.
    local config = JustQuest.Core.GetModule("Config")
    if config and config.Get("quest", "usePawnScoring") == false then
        return nil
    end

    local pawnData = PawnGetItemData(itemLink)
    if not pawnData then return nil end  -- item not in WoW/Pawn cache yet

    local upgradeTable, _, bestItemTable, secondBestTable = PawnIsItemAnUpgrade(pawnData)

    -- Player identity for scale filtering (loot spec overrides active spec)
    local _, _, playerClassID = UnitClass("player")
    local playerSpecIndex    = GetEffectiveSpecIndex()

    -- Classify each visible scale into one of three buckets:
    --   specScales   — tagged to this class AND this spec (highest priority)
    --   classScales  — tagged to this class, no spec restriction
    --   genericScales — no class/spec tag (user-created)
    -- Scales for a different class or a different spec of this class are skipped.
    local specScales    = {}
    local classScales   = {}
    local genericScales = {}

    for scaleName, scale in pairs(PawnCommon.Scales) do
        if PawnIsScaleVisible(scaleName) then
            if scale.ClassID ~= nil then
                if scale.ClassID == playerClassID then
                    if scale.SpecID ~= nil then
                        if scale.SpecID == playerSpecIndex then
                            specScales[scaleName] = true
                        end
                        -- else: same class, different spec — skip
                    else
                        classScales[scaleName] = true
                    end
                end
                -- else: different class — skip
            else
                genericScales[scaleName] = true
            end
        end
    end

    -- Pick the tightest matching set that has at least one scale
    local relevant
    if next(specScales)  then relevant = specScales
    elseif next(classScales) then relevant = classScales
    else relevant = genericScales
    end
    if not next(relevant) then return nil end  -- no applicable scales at all

    -- Walk the three result tables Pawn returned and collect hits from relevant scales
    local isUpgrade        = false
    local pawnPercentUpgrade = 0
    local hadResult        = false

    if upgradeTable then
        for _, entry in ipairs(upgradeTable) do
            if relevant[entry.ScaleName] then
                hadResult  = true
                isUpgrade  = true
                local pct  = entry.PercentUpgrade or 0
                if pct > pawnPercentUpgrade then
                    pawnPercentUpgrade = pct
                end
            end
        end
    end

    -- bestItemTable / secondBestTable mean "this scale ran and the item is NOT an upgrade".
    -- Use separate blocks, not ipairs{}, to avoid ipairs stopping at the first nil entry.
    if bestItemTable then
        for scaleName in pairs(bestItemTable) do
            if relevant[scaleName] then
                hadResult = true
                -- isUpgrade intentionally stays false unless upgradeTable already set it
            end
        end
    end
    if secondBestTable then
        for scaleName in pairs(secondBestTable) do
            if relevant[scaleName] then
                hadResult = true
            end
        end
    end

    if not hadResult then return nil end  -- relevant scales didn't produce any result

    return { isUpgrade = isUpgrade, pawnPercentUpgrade = pawnPercentUpgrade }
end

function RewardEngine.CompareWithEquipped(rewardInfo)
    if not rewardInfo or not rewardInfo.isEquippable then
        return { isUpgrade = false, reason = "not_equippable" }
    end

    local gameData = GetGameData()
    if not gameData then
        return { isUpgrade = false, reason = "no_gamedata" }
    end

    local rewardLevel = rewardInfo.itemLevel or 0

    -- Pawn: spec-aware stat-weight scoring (falls back to ilvl when Pawn is absent,
    -- item not yet cached, or no relevant scales are configured for the active spec).
    if rewardInfo.itemLink then
        local pawnResult = GetPawnUpgradeForCurrentSpec(rewardInfo.itemLink)
        if pawnResult then
            return {
                isUpgrade          = pawnResult.isUpgrade,
                reason             = pawnResult.isUpgrade and "pawn_upgrade" or "pawn_not_upgrade",
                pawnPercentUpgrade = pawnResult.pawnPercentUpgrade,
                rewardLevel        = rewardLevel,
            }
        end
    end

    -- ilvl fallback: slot-specific comparison using GetDetailedItemLevelInfo on both sides.
    local currentLevel = gameData.GetCurrentEquippedLevel(rewardInfo.equipSlot)

    if currentLevel == 0 then
        return {
            isUpgrade = true,
            reason = "empty_slot",
            currentLevel = 0,
            rewardLevel = rewardLevel
        }
    end

    local buffer = JustQuest.Constants.LIMITS.ITEM_LEVEL_BUFFER
    if rewardLevel >= (currentLevel - buffer) then
        return {
            isUpgrade = true,
            reason = "item_level_upgrade",
            currentLevel = currentLevel,
            rewardLevel = rewardLevel,
            difference = rewardLevel - currentLevel
        }
    end

    return {
        isUpgrade = false,
        reason = "downgrade",
        currentLevel = currentLevel,
        rewardLevel = rewardLevel,
        difference = rewardLevel - currentLevel
    }
end

-- ============================================================
-- Smart Selection Logic
-- ============================================================

function RewardEngine.SelectSmartChoice(choices)
    local usableChoices = {}
    local significantChoices = {}
    local unknownCollectibles = {}
    local upgrades = {}
    
    for i, choice in ipairs(choices) do
        if choice and choice.canUse ~= false then
            table.insert(usableChoices, choice)
            
            if choice.isSignificant then
                table.insert(significantChoices, choice)
            end
            
            -- Track unknown collectibles (mounts/pets/toys not yet collected)
            if choice.isCollectible and choice.isCollectibleKnown == false then
                table.insert(unknownCollectibles, choice)
            end
            
            -- Track item level upgrades (empty slots or better ilvl)
            if choice.upgradeInfo and choice.upgradeInfo.isUpgrade then
                table.insert(upgrades, choice)
            end
        end
    end
    
    local services = GetServices()
    
    if #usableChoices == 1 then
        services.Debug("Rewards", "Single usable choice: " .. usableChoices[1].name)
        return usableChoices[1].index
    end
    
    -- PRIORITY 1: Unknown collectibles (mounts/pets/toys)
    -- Always prioritize collecting new cosmetics over everything else
    if #unknownCollectibles > 0 then
        local collectible = unknownCollectibles[1]
        local collectibleType = collectible.isMount and "Mount" or (collectible.isPet and "Pet" or "Toy")
        services.Debug("Rewards", string.format("PRIORITY: Unknown %s - %s", collectibleType, collectible.name))
        return collectible.index
    end
    
    -- PRIORITY 2: Halt for significant items (Epic+, BoE)
    if #significantChoices > 0 then
        services.Debug("Rewards", #significantChoices .. " significant choice(s) detected - halting for manual selection")
        return nil
    end
    
    -- PRIORITY 3: Item level upgrades (for leveling characters)
    if #upgrades > 0 then
        -- Rank by Pawn PercentUpgrade when available, otherwise by ilvl delta.
        -- All choices in a single reward set will have used the same path (Pawn or ilvl)
        -- so mixing the two scoring modes per-choice is not expected.
        local function upgradeScore(choice)
            local info = choice.upgradeInfo
            if info.pawnPercentUpgrade and info.pawnPercentUpgrade > 0 then
                return info.pawnPercentUpgrade
            end
            return (info.difference or 0) * 0.001  -- normalise ilvl delta to same scale as Pawn %
        end

        local bestUpgrade = upgrades[1]
        local bestScore = upgradeScore(bestUpgrade)
        for i = 2, #upgrades do
            local score = upgradeScore(upgrades[i])
            if score > bestScore then
                bestUpgrade = upgrades[i]
                bestScore = score
            end
        end

        local info = bestUpgrade.upgradeInfo
        if info.pawnPercentUpgrade and info.pawnPercentUpgrade > 0 then
            -- PawnBigUpgradeThreshold = 100 is a sentinel for "no baseline / empty slot" (= 10000%).
            -- Display it as a plain "big upgrade" rather than a nonsense percentage.
            local pctDisplay = info.pawnPercentUpgrade >= 99
                and "big upgrade (no baseline)"
                or string.format("%.0f%% better by stat weight", info.pawnPercentUpgrade * 100)
            services.Debug("Rewards", string.format("PRIORITY: Pawn upgrade - %s (%s)",
                bestUpgrade.name, pctDisplay))
        else
            services.Debug("Rewards", string.format("PRIORITY: Upgrade - %s (+%d ilvl)",
                bestUpgrade.name, info.difference or 0))
        end
        return bestUpgrade.index
    end
    
    -- PRIORITY 4: Vendor value fallback
    -- If all choices failed usability check (currency tokens, crests), compare all choices.
    local candidates = #usableChoices > 0 and usableChoices or choices
    if #usableChoices == 0 then
        services.Debug("Rewards", "No usable choices (currency tokens/crests?) - falling back to all choices by vendor value")
    end
    local bestChoice = candidates[1]
    if not bestChoice then
        return 1
    end
    local bestValue = bestChoice.vendorPrice or 0

    for i = 2, #candidates do
        local c = candidates[i]
        if c then
            local choiceValue = c.vendorPrice or 0
            if choiceValue > bestValue then
                bestChoice = c
                bestValue = choiceValue
            end
        end
    end

    local gameData = GetGameData()
    local priceStr = gameData and gameData.FormatMoney(bestValue) or (bestValue .. " copper")
    services.Debug("Rewards", "Best vendor value: " .. (bestChoice.name or "?") .. " (" .. priceStr .. ")")

    return bestChoice.index
end

-- ============================================================
-- Quality Assessment
-- ============================================================

function RewardEngine.GetQualityColor(quality)
    local colors = {
        [0] = "|cff9d9d9d", -- Poor (gray)
        [1] = "|cffffffff", -- Common (white) 
        [2] = "|cff1eff00", -- Uncommon (green)
        [3] = "|cff0070dd", -- Rare (blue)
        [4] = "|cffa335ee", -- Epic (purple)
        [5] = "|cffff8000", -- Legendary (orange)
        [6] = "|cffe6cc80", -- Artifact
        [7] = "|cff00ccff", -- Heirloom
    }
    return colors[quality] or "|cffffffff"
end

function RewardEngine.FormatRewardChoice(choice)
    if not choice then return "Unknown" end
    
    local qualityColor = RewardEngine.GetQualityColor(choice.quality)
    local result = qualityColor .. (choice.name or "Unknown") .. "|r"
    
    if choice.itemLevel and choice.itemLevel > 0 then
        result = result .. " (iLvl " .. choice.itemLevel .. ")"
    end
    
    if choice.vendorPrice and choice.vendorPrice > 0 then
        local gameData = GetGameData() 
        if gameData then
            result = result .. " [" .. gameData.FormatMoney(choice.vendorPrice) .. "]"
        end
    end
    
    return result
end

-- ============================================================
-- Debug and Logging
-- ============================================================

function RewardEngine.LogRewardAnalysis(choices)
    local services = GetServices()
    if not services then return end
    
    services.Debug("Rewards", "=== Reward Analysis ===")
    for i, choice in ipairs(choices) do
        if choice then
            local info = RewardEngine.FormatRewardChoice(choice)
            local flags = {}
            
            if choice.canUse == false then table.insert(flags, "UNUSABLE") end
            if choice.isSignificant then table.insert(flags, "SIGNIFICANT") end
            if choice.isEquippable then table.insert(flags, "EQUIPPABLE") end
            
            -- Collectible flags
            if choice.isMount then 
                table.insert(flags, choice.isCollectibleKnown == false and "MOUNT-NEW" or "MOUNT-KNOWN")
            end
            if choice.isPet then 
                table.insert(flags, choice.isCollectibleKnown == false and "PET-NEW" or "PET-KNOWN")
            end
            if choice.isToy then 
                table.insert(flags, choice.isCollectibleKnown == false and "TOY-NEW" or "TOY-KNOWN")
            end
            
            -- Upgrade flag
            if choice.upgradeInfo and choice.upgradeInfo.isUpgrade then
                local diff = choice.upgradeInfo.difference or 0
                table.insert(flags, string.format("UPGRADE+%d", diff))
            end
            
            local flagStr = #flags > 0 and " [" .. table.concat(flags, ",") .. "]" or ""
            services.Debug("Rewards", "  " .. i .. ": " .. info .. flagStr)
            
            if choice.upgradeInfo then
                local prefix = choice.upgradeInfo.isUpgrade and "    ✓ Upgrade" or "    ✗ Not upgrade"
                local reason = choice.upgradeInfo.reason or "unknown"
                if choice.upgradeInfo.currentLevel then
                    services.Debug("Rewards", string.format("%s: %s (current %d → reward %d)", 
                        prefix, reason, choice.upgradeInfo.currentLevel, choice.upgradeInfo.rewardLevel or 0))
                else
                    services.Debug("Rewards", prefix .. ": " .. reason)
                end
            end
        end
    end
    services.Debug("Rewards", "======================")
end

function RewardEngine.GetRecommendedChoice(numChoices)
    if numChoices <= 1 then
        return numChoices == 1 and 1 or nil
    end
    
    local choices = RewardEngine.AnalyzeRewardChoices(numChoices)
    RewardEngine.LogRewardAnalysis(choices)
    return RewardEngine.SelectSmartChoice(choices)
end

-- ============================================================
-- Initialization
-- ============================================================

function RewardEngine.ResetProcessingFlag()
    processingReward = false
    rewardRetryCount = 0
    local services = GetServices()
    if services and services.CancelScheduled then
        services.CancelScheduled("reward_data_retry")
    end
end

function RewardEngine.Initialize()
end

-- ============================================================
-- Module Registration
-- ============================================================

JustQuest.Core.RegisterModule("RewardEngine", RewardEngine, {"Services", "Config", "SafetyEngine", "GameData"})

return RewardEngine
