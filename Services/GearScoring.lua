local ADDON_NAME, JustQuest = ...

local GearScoring = { version = 1 }
local GetGameData = JustQuest.Core.ModuleGetter("GameData")
local GetClassWeights = JustQuest.Core.ModuleGetter("ClassWeights")
local GetPawnScoring = JustQuest.Core.ModuleGetter("PawnScoring")

local UNSUPPORTED = {
    INVTYPE_TRINKET = true, INVTYPE_RELIC = true,
    INVTYPE_BODY = true, INVTYPE_TABARD = true,
}

local function Unknown(reason, retryable)
    return { status = "unknown", reason = reason, retryable = retryable == true }
end

local function UnmodeledItem(link, gameData, context)
    if not link then return nil end
    local cache = context and context.itemChecks
    local cached = cache and cache[link]
    if cached then return cached.reason, cached.retryable, cached.lines end
    local function Finish(reason, retryable, lines)
        if cache then cache[link] = { reason = reason, retryable = retryable, lines = lines } end
        return reason, retryable, lines
    end
    local name, _, quality, _, _, _, _, _, _, _, _, _, _, _, _, setID = C_Item.GetItemInfo(link)
    if not name then return Finish("item data unavailable", true) end
    if quality >= 5 or (setID and setID > 0) then
        return Finish("special or set effects not evaluated")
    end
    local lines = gameData.TooltipLines(link)
    if not lines or #lines == 0 then return Finish("tooltip data unavailable", true) end
    local types = Enum and Enum.TooltipDataLineType
    if not (types and types.ItemSpellTriggerOnUse and types.ItemSpellTriggerOnEquip
            and types.ItemSpellTriggerOnProc) then
        return Finish("effect detection unavailable", true)
    end
    for _, line in ipairs(lines) do
        if line.type == types.ItemSpellTriggerOnUse or line.type == types.ItemSpellTriggerOnEquip
           or line.type == types.ItemSpellTriggerOnProc then
            return Finish("item effects not evaluated")
        end
    end
    if C_Item.GetItemSpell(link) then return Finish("item effects not evaluated") end
    return Finish(nil, nil, lines)
end

local function ValidateItem(link, context)
    local cache = context and context.validations
    local cached = type(link) == "string" and cache and cache[link]
    if cached then return cached end
    local function Finish(result)
        if type(link) == "string" and cache then cache[link] = result end
        return result
    end
    if not JustQuest.Constants.IS_FOREVER then return Finish(Unknown("Forever scoring only")) end
    if type(link) ~= "string" or not link:find("item:", 1, true) then
        return Finish(Unknown("invalid item link"))
    end
    if InCombatLockdown() then return Finish(Unknown("scoring deferred during combat")) end
    local gameData, cw = GetGameData(), GetClassWeights()
    if not (gameData and cw) then return Finish(Unknown("scoring modules unavailable", true)) end
    if not C_Item.GetItemInfo(link) then return Finish(Unknown("item data unavailable", true)) end
    local _, _, _, invType = C_Item.GetItemInfoInstant(link)
    if not invType or UNSUPPORTED[invType] then return Finish(Unknown("item slot not evaluated")) end
    if gameData.IsProfessionTool(link) then return Finish(Unknown("profession tool protected")) end
    local slots = gameData.ComparableSlots(invType)
    if not slots then return Finish(Unknown("item slot not evaluated")) end
    local reason, retryable, lines = UnmodeledItem(link, gameData, context)
    if reason then return Finish(Unknown(reason, retryable)) end
    -- Required levels and untrained proficiencies can change. They are not disposal verdicts.
    if gameData.ItemFailsARequirement(link, lines) then
        return Finish(Unknown("item requirements not met"))
    end
    if gameData.ItemIsWrongPrimaryStat(link) then
        return Finish(Unknown("off-role primary stats not evaluated"))
    end

    for _, slot in ipairs(slots) do
        local equipped = GetInventoryItemLink("player", slot)
        reason, retryable = UnmodeledItem(equipped, gameData, context)
        if reason then return Finish(Unknown(reason, retryable)) end
    end
    local displaced = gameData.DisplacedOffHand(invType, slots[1])
    reason, retryable = UnmodeledItem(displaced, gameData, context)
    if reason then return Finish(Unknown(reason, retryable)) end
    local main = GetInventoryItemLink("player", 16)
    if slots[1] == 17 and main
       and select(4, C_Item.GetItemInfoInstant(main)) == "INVTYPE_2HWEAPON"
       and not GetInventoryItemLink("player", 17) then
        return Finish(Unknown("off-hand requires a different main hand"))
    end
    return Finish({ status = "ready", slots = slots, displacedOffHand = displaced })
end

local function NewScanContext()
    local context = { validations = {}, itemChecks = {} }
    if JustQuest.Constants.IS_FOREVER then
        context.pawn = GetPawnScoring()
        context.selectedScale = context.pawn and context.pawn.GetConfiguredForeverScale()
        context.relevant = context.selectedScale and context.pawn.RelevantScale(context.selectedScale)
    end
    return context
end

function GearScoring.CreateScanContext()
    return NewScanContext()
end

function GearScoring.ValidateItem(link, context)
    return ValidateItem(link, context)
end

local function ArmorOnlyComparison(link, validation)
    if validation.displacedOffHand then return false end
    local gameData = GetGameData()
    local function ArmorOnly(itemLink)
        if not itemLink then return true end
        local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemLink)
        if classID ~= JustQuest.Constants.ITEM_CLASS.ARMOR then return false end
        local stats = gameData.ItemStats(itemLink)
        if not stats or not stats.RESISTANCE0_NAME or stats.RESISTANCE0_NAME <= 0 then return false end
        for key, value in pairs(stats) do
            if key ~= "RESISTANCE0_NAME" and value ~= 0 then return false end
        end
        return true
    end
    if not ArmorOnly(link) then return false end
    for _, slot in ipairs(validation.slots) do
        if not ArmorOnly(GetInventoryItemLink("player", slot)) then return false end
    end
    return true
end

-- A score verdict, not an instruction to equip or sell. Display/ignore settings never enter it.
function GearScoring.EvaluateItem(link, context)
    context = context or NewScanContext()
    local validation = ValidateItem(link, context)
    if validation.status ~= "ready" then return validation end
    local pawn = context.pawn
    local relevant = context.relevant
    -- Scales may assign no value to armor. With no other stats on either piece there
    -- is no Pawn trade-off to preserve; use the existing armor-aware comparison.
    if relevant and not ArmorOnlyComparison(link, validation) then
        local result = pawn.ScoreItem(link, nil, relevant, context.selectedScale)
        if not result then return Unknown("selected Pawn scale score unavailable", true) end
        result.status = result.isUpgrade and "upgrade" or "not_upgrade"
        result.reason = result.isUpgrade and "selected Pawn scale upgrade"
            or "no selected Pawn scale score gain"
        result.byPawnScale = true
        return result
    end

    local cw = GetClassWeights()
    local slots, displaced = validation.slots, validation.displacedOffHand
    local result = cw.CompareToEquipped(link, slots, displaced)
    if not result then return Unknown("stat data unavailable", true) end
    result.status = result.isUpgrade and "upgrade" or "not_upgrade"
    result.reason = result.isUpgrade and "higher class-role score" or "no class-role score gain"
    result.displacedOffHand = displaced
    return result
end

function GearScoring.FormatUpgrade(pct, baselineScore)
    if baselineScore == 0 then return "fills an empty score baseline" end
    if not pct or pct <= 0 then return nil end
    return string.format("+%.0f%% estimated score", pct * 100)
end

JustQuest.GearScoring = GearScoring
JustQuest.Core.RegisterModule("GearScoring", GearScoring, {"GameData", "ClassWeights", "PawnScoring"})

return GearScoring
