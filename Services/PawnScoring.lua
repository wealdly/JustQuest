-- PawnScoring.lua — shared native-Pawn item scoring.
--
-- One source of truth for "is this item an upgrade for the player's effective spec,
-- and by how much?", so reward auto-selection and the Gear Advisor never disagree.
-- Uses Pawn's public API directly (no translation layer): PawnGetItemData +
-- PawnIsItemAnUpgrade, filtered to the scales that apply to the player's class/spec.
-- Pawn absent / item not cached / no applicable scale -> returns nil for the caller
-- to choose its appropriate fallback.

local ADDON_NAME, JustQuest = ...

-- Namespaced APIs first. The bare GetSpecialization / GetSpecializationInfo globals are only
-- compatibility shims (Blizzard_DeprecatedSpecialization), and that addon does NOT load on WoW
-- Forever ("AllowLoadGameType: classic, standard") — calling the bare name there throws.
local GetSpecialization     = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
local GetSpecializationInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo

local PawnScoring = {}

local GetConfig = JustQuest.Core.ModuleGetter("Config")

local JUSTQUEST_SCALE = "__justquest__"

local function CharacterKey()
    local name, realm = UnitFullName("player")
    realm = (realm and realm ~= "") and realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or "?"
    return (name or "?") .. "-" .. realm
end

function PawnScoring.GetConfiguredForeverScale()
    local config = GetConfig()
    local scales = config and config.Get("gearSwap", "foreverPawnScales")
    local name = scales and scales[CharacterKey()]
    return name and name ~= JUSTQUEST_SCALE and name or nil
end

function PawnScoring.SetForeverScale(name)
    if type(name) ~= "string" then return false end
    local config = GetConfig()
    if not config then return false end
    local scales = {}
    for key, value in pairs(config.Get("gearSwap", "foreverPawnScales") or {}) do
        scales[key] = value
    end
    if name == JUSTQUEST_SCALE then
        scales[CharacterKey()] = nil
    else
        scales[CharacterKey()] = name
    end
    config.Set("gearSwap", "foreverPawnScales", scales)
    return true
end

-- Only expose visible scales Pawn can actually score. Unlike normal auto-selection,
-- the user explicitly picks the desired Forever talent-tree scale.
function PawnScoring.GetForeverScaleOptions()
    local values = { [JUSTQUEST_SCALE] = "JustQuest class/role weights" }
    if not (PawnCommon and PawnCommon.Scales and PawnIsScaleVisible) then return values end
    local _, _, playerClassID = UnitClass("player")
    local scales = PawnGetAllScalesEx and PawnGetAllScalesEx()
    if scales then
        for _, info in ipairs(scales) do
            local scale = PawnCommon.Scales[info.Name]
            if info.IsVisible and scale and (scale.ClassID == nil or scale.ClassID == playerClassID) then
                values[info.Name] = (info.LocalizedName or info.Name) .. " (" .. info.Name .. ")"
            end
        end
    else
        for name, scale in pairs(PawnCommon.Scales) do
            if PawnIsScaleVisible(name) and (scale.ClassID == nil or scale.ClassID == playerClassID) then
                values[name] = (scale.LocalizedName or name) .. " (" .. name .. ")"
            end
        end
    end
    local selected = PawnScoring.GetConfiguredForeverScale()
    if selected and not values[selected] then
        values[selected] = "Unavailable Pawn scale (" .. selected .. ")"
    end
    return values
end

function PawnScoring.RelevantScale(scaleName)
    if not (scaleName and PawnCommon and PawnCommon.Scales and PawnIsScaleVisible) then return nil end
    local scale = PawnCommon.Scales[scaleName]
    if not scale or (scale.ClassID ~= nil and select(3, UnitClass("player")) ~= scale.ClassID)
       or not PawnIsScaleVisible(scaleName) then
        return nil
    end
    return { [scaleName] = true }
end

-- Returns the spec index (1–4) that should drive Pawn scale selection.
-- Honours the loot specialization override (right-click portrait → Loot Specialization):
-- if the player pinned a different spec for loot, respect it so tank/healer loot scales
-- are used even while playing a DPS spec. GetLootSpecialization() returns a global spec
-- ID; Pawn keys on the 1-4 index GetSpecialization() returns, so convert by probing.
--
-- For scoring things you KEEP (quest rewards). The Gear Advisor deliberately does not use
-- this — it recommends gear to wear right now, and loot spec says nothing about what you
-- should be wearing. A Guardian druid set to Feral for drops must still be advised on
-- Guardian gear, and if no Feral scale exists the advisor would score nothing whatsoever.
function PawnScoring.EffectiveSpecIndex()
    local config = GetConfig()
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

-- Returns { isUpgrade=bool, pawnPercentUpgrade=number, existingItemLink=string? } when
-- Pawn can give a definitive result for the player's effective spec, or nil to signal
-- "no Pawn verdict — fall back to item level".
--
-- Automatic scale selection priority:
--   1. Scales tagged to the player's current class+spec (Scale.ClassID + Scale.SpecID)
--   2. Scales tagged to the player's class only (Scale.ClassID, no SpecID)
--   3. Untagged/generic user scales (no ClassID)
-- Scales for other classes/specs are ignored so a Holy scale never sways a Ret pick.
-- The tightest set of visible Pawn scales that apply to the player (class+spec > class >
-- generic), as a { [scaleName]=true } set, or nil if none apply. HOT PATH: compute this
-- ONCE and pass it to ScoreItem when scoring many items — the classification depends only
-- on class/spec, so re-walking the scale table (and allocating three tables) per item is
-- pure waste in a bulk bag scan.
function PawnScoring.RelevantScales(specIndex)
    if not (PawnIsScaleVisible and PawnCommon and PawnCommon.Scales) then return nil end
    local _, _, playerClassID = UnitClass("player")
    local playerSpecIndex = specIndex or PawnScoring.EffectiveSpecIndex()
    local specScales, classScales, genericScales = {}, {}, {}
    for scaleName, scale in pairs(PawnCommon.Scales) do
        if PawnIsScaleVisible(scaleName) then
            if scale.ClassID ~= nil then
                if scale.ClassID == playerClassID then
                    if scale.SpecID ~= nil then
                        if scale.SpecID == playerSpecIndex then specScales[scaleName] = true end
                    else
                        classScales[scaleName] = true
                    end
                end
            else
                genericScales[scaleName] = true
            end
        end
    end
    if next(specScales) then return specScales end
    if next(classScales) then return classScales end
    if next(genericScales) then return genericScales end
    return nil
end

-- specIndex: score for a specific spec (advisor passes the ACTIVE spec; reward omits it,
-- defaulting to the loot-spec-aware index). relevant: precomputed RelevantScales for a
-- bulk scan (optional — computed here when nil).
function PawnScoring.ScoreItem(itemLink, specIndex, relevant, configuredForeverScale)
    if not (PawnGetItemData and PawnIsItemAnUpgrade and PawnIsScaleVisible
            and PawnCommon and PawnCommon.Scales) then
        return nil
    end

    -- No applicable scale -> skip the expensive Pawn calls entirely.
    relevant = relevant or PawnScoring.RelevantScales(specIndex)
    if not relevant then return nil end

    -- Respect the user's option on clients where it is exposed. Forever's option is
    -- hidden because selecting a Pawn scale in the Gear panel is explicit consent.
    local config = GetConfig()
    local selectedForeverScale
    if JustQuest.Constants.IS_FOREVER then
        selectedForeverScale = configuredForeverScale or PawnScoring.GetConfiguredForeverScale()
    end
    if config and config.Get("quest", "usePawnScoring") == false
       and not (selectedForeverScale and relevant[selectedForeverScale]) then
        return nil
    end

    local pawnData = PawnGetItemData(itemLink)
    if not pawnData then return nil end  -- item not in WoW/Pawn cache yet

    local upgradeTable, _, bestItemTable, secondBestTable = PawnIsItemAnUpgrade(pawnData)

    -- Walk Pawn's result tables, keeping the best upgrade % among relevant scales.
    local isUpgrade, pawnPercentUpgrade, existingItemLink = false, 0, nil
    local hadResult = false

    if upgradeTable then
        for _, entry in ipairs(upgradeTable) do
            if relevant[entry.ScaleName] then
                hadResult = true
                isUpgrade = true
                local pct = entry.PercentUpgrade or 0
                if pct > pawnPercentUpgrade then
                    pawnPercentUpgrade = pct
                end
                -- Baseline capture is SEPARATE from the max. Tying it to a strict
                -- improvement meant a 0% (or nil) upgrade set isUpgrade but left
                -- existingItemLink nil, which silently skipped the item-level check
                -- below — exactly the case that check exists to catch.
                existingItemLink = existingItemLink or entry.ExistingItemLink
            end
        end
    end

    -- bestItemTable / secondBestTable mean "this scale ran and the item is NOT an upgrade".
    -- Separate blocks (not ipairs) so a nil entry doesn't stop the scan early.
    if bestItemTable then
        for scaleName in pairs(bestItemTable) do
            if relevant[scaleName] then hadResult = true end
        end
    end
    if secondBestTable then
        for scaleName in pairs(secondBestTable) do
            if relevant[scaleName] then hadResult = true end
        end
    end

    if not hadResult then return nil end  -- relevant scales produced no result

    -- Item-level sanity check. Pawn's percentage is a RATIO against what you're wearing
    -- — Difference / (BestValue + Epsilon), where the epsilon is there to keep no-stat
    -- items from dividing by zero. So a baseline that scores near nothing for the scale
    -- (a starter ring, an item with no stat the scale wants) divides down to almost
    -- nothing and ANY item carrying a relevant stat comes back as a colossal upgrade:
    -- a four-figure percentage on an item a fraction of your item level. The ratio has
    -- no way to notice that; item level does. Below what it would replace is not an
    -- upgrade however well the stats score — the same rule, and the same buffer, the
    -- reward picker applies when Pawn isn't available. An empty slot reports no
    -- baseline, so it has nothing to be worse than and always passes.
    if isUpgrade and existingItemLink then
        local candidateLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
        local existingLevel  = C_Item.GetDetailedItemLevelInfo(existingItemLink)
        local buffer = JustQuest.Constants.LIMITS.ITEM_LEVEL_BUFFER
        -- Uncached either side: no verdict rather than a wrong one.
        if candidateLevel and existingLevel and candidateLevel < (existingLevel - buffer) then
            isUpgrade = false
        end
    end

    return {
        isUpgrade          = isUpgrade,
        pawnPercentUpgrade = pawnPercentUpgrade,
        existingItemLink   = existingItemLink,
    }
end

-- Player-facing upgrade string, aligned to Pawn's own tooltip wording. Returns nil when
-- there's nothing meaningful to show. pct is Pawn's PercentUpgrade fraction (0.12 = 12%);
-- Pawn's PawnBigUpgradeThreshold (100) is the "no baseline / empty slot" sentinel.
function PawnScoring.FormatUpgrade(pct)
    if not pct or pct <= 0 then return nil end
    if pct >= 99 then return "big upgrade (no baseline)" end
    return string.format("+%.0f%% upgrade", pct * 100)
end

-- True if at least one visible Pawn scale applies to the player (class+spec, class-only,
-- or a generic user scale). When false, ScoreItem returns nil for everything — the usual
-- cause of "no recommendations": Pawn has no active scale for this spec.
function PawnScoring.HasScaleForSpec(specIndex)
    if not (PawnIsScaleVisible and PawnCommon and PawnCommon.Scales) then return false end
    local _, _, classID = UnitClass("player")
    specIndex = specIndex or PawnScoring.EffectiveSpecIndex()
    local hasGeneric = false
    for name, scale in pairs(PawnCommon.Scales) do
        if PawnIsScaleVisible(name) then
            if scale.ClassID == nil then
                hasGeneric = true
            elseif scale.ClassID == classID and (scale.SpecID == nil or scale.SpecID == specIndex) then
                return true
            end
        end
    end
    return hasGeneric
end

JustQuest.Core.RegisterModule("PawnScoring", PawnScoring, {})

return PawnScoring
