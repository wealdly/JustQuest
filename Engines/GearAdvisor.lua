-- GearAdvisor.lua — Pawn-powered gear brain: best-in-slot recommendations + spec-change
-- reminders for the spec you're playing.
--
-- Scans your bags, scores each equippable item against your ACTIVE spec's Pawn scale
-- (shared PawnScoring module — native Pawn, no translation), keeps the best per-slot
-- upgrade you own, and:
--   * on loot: notes upgrades in chat (advise) or equips them (auto-equip)
--   * on spec change: reminds you of the best gear for the new spec ("switch to your
--     intellect staff") and, in auto-equip mode, equips it.
--
-- With no Pawn scale for the spec — or no Pawn at all — it falls back to item level, behind the
-- same usability / armour-type / primary-stat gates (see ScoreByItemLevel). Crude, and the
-- prompt says so, but the alternative is silence that reads as "you have no upgrades".
--
-- Trinkets are out of scope — Pawn can't score them, so the advisor never touches them.
-- Unique-equipped items are respected: a recommendation is dropped if wearing it would
-- exceed its unique constraint (you already wear it, or the max of a named set).
--
-- All scoring and equipping is OUT OF COMBAT ONLY: Pawn's stat math throws on combat
-- "secret values", and the server rejects weapon swaps in combat.

local ADDON_NAME, JustQuest = ...

local GearAdvisor = {}

local GetConfig      = JustQuest.Core.ModuleGetter("Config")
local GetServices    = JustQuest.Core.ModuleGetter("Services")
local GetPawnScoring = JustQuest.Core.ModuleGetter("PawnScoring")
local GetToast       = JustQuest.Core.ModuleGetter("GearToast")
local GetGameData    = JustQuest.Core.ModuleGetter("GameData")
local GetSafety      = JustQuest.Core.ModuleGetter("SafetyEngine")

-- Equip location -> inventory slot(s). Trinkets (13/14), shirt (4), tabard (19) are
-- excluded (Pawn won't score trinkets; the others are cosmetic). Rings and 1H weapons
-- are dual-slot; the destination is resolved from Pawn's ExistingItemLink.
local INVTYPE_SLOTS = {
    INVTYPE_HEAD = {1}, INVTYPE_NECK = {2}, INVTYPE_SHOULDER = {3},
    INVTYPE_CHEST = {5}, INVTYPE_ROBE = {5}, INVTYPE_WAIST = {6},
    INVTYPE_LEGS = {7}, INVTYPE_FEET = {8}, INVTYPE_WRIST = {9},
    INVTYPE_HAND = {10}, INVTYPE_FINGER = {11, 12}, INVTYPE_CLOAK = {15},
    INVTYPE_WEAPON = {16, 17}, INVTYPE_2HWEAPON = {16},
    INVTYPE_WEAPONMAINHAND = {16}, INVTYPE_WEAPONOFFHAND = {17},
    INVTYPE_HOLDABLE = {17}, INVTYPE_SHIELD = {17},
    INVTYPE_RANGED = {16}, INVTYPE_RANGEDRIGHT = {16},
}

local FIRST_SLOT = INVSLOT_FIRST_EQUIPPED or 1
local LAST_SLOT  = INVSLOT_LAST_EQUIPPED or 19

local recommendations = {}   -- [invType] = { link, pct, existingLink, invType, bound, id }
local tempIgnore      = {}   -- itemID -> true ("Skip": not now — wiped on reload / rescan)
local uniqueCache     = {}   -- itemID -> { unique=bool, key=string|nil, max=number }
local usableCache     = {}   -- itemID -> bool (can this character actually wear it)
local pendingEquip    = false
local pendingDeadline = 0
-- How long a blocked auto-equip keeps retrying before giving up on that batch.
local PENDING_EQUIP_WINDOW = 60
local pendingManual   = false  -- carry the manual (player-clicked) intent across a combat defer
-- The itemID the on-screen prompt is asking about, or nil when no prompt is up. One
-- variable, not a flag plus an id: a separate boolean is exactly "promptedID ~= nil" and
-- the two had already drifted apart in one path.
local promptedID
local lastFingerprint          -- equippable bag contents at the last scored scan
local forceNext       = false  -- score the next scan even if the bags look unchanged

-- A travel item — a teleport cloak, a port trinket — is a downgrade on paper: Pawn scores stats
-- and a teleport has none. So the instant one goes on, the scan wants the real piece back, which
-- means a prompt while you are still reaching for the right-click and, in auto-equip mode, the
-- cloak coming off before you can use it at all. That last one isn't just noise: these items
-- only function from an equipped slot, so pulling it off IS cancelling the trip.
--
-- Hence a hold, started by putting on anything with a Use: effect and extended for as long as a
-- cast is up (the teleport itself). Arriving ends it — which is the moment "you're still wearing
-- the travel cloak" turns into the useful thing to say, so the reminder lands on the far side.
local holdUntil = 0
local TRAVEL_HOLD = 5  -- only has to cover notice-and-right-click; the cast extends it from there

-- Deliberately not a list of travel items: C_Item.GetItemSpell answers "does this have a Use:
-- effect" from the item itself, which covers every teleport cloak, port trinket and on-use
-- oddity without naming any of them.
local function HasUseEffect(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then return false end  -- slot was emptied, not filled
    local ok, spellName = pcall(C_Item.GetItemSpell, link)
    return ok and spellName ~= nil
end

local function TravelHold()
    if UnitCastingInfo("player") or UnitChannelInfo("player") then return true end
    return GetTime() < holdUntil
end

-- Gear that belongs to a saved equipment set was put on deliberately. A speed-levelling
-- or utility set is chosen for what it does, not for its item level, so "this is 40 ilvl
-- higher" is not an argument the player wants re-made every time something drops. Pawn
-- can only see stats, so left alone it prompts forever.
--
-- Per equipped SLOT rather than per whole set: GetEquippedSetID only answers when every
-- slot matches exactly, so one swapped trinket would drop the protection for the entire
-- loadout. This asks the narrower question — "did the player place this specific piece as
-- part of a set they built?" — which also leaves slots outside the set free to be
-- upgraded normally.
local setItemIDs        -- itemID -> true, across every saved set; nil = needs rebuilding

local function SetItemIDs()
    if setItemIDs then return setItemIDs end

    setItemIDs = {}
    if not (C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs and C_EquipmentSet.GetItemIDs) then
        return setItemIDs
    end

    local ok, ids = pcall(C_EquipmentSet.GetEquipmentSetIDs)
    if not ok or type(ids) ~= "table" then return setItemIDs end

    for _, setID in ipairs(ids) do
        local okItems, items = pcall(C_EquipmentSet.GetItemIDs, setID)
        if okItems and type(items) == "table" then
            for _, itemID in pairs(items) do
                -- Ignored / empty slots come back as 0 or a sentinel, not a real item.
                if type(itemID) == "number" and itemID > 1 then
                    setItemIDs[itemID] = true
                end
            end
        end
    end
    return setItemIDs
end

-- A fishing pole occupies the main hand and a profession accessory occupies a real slot,
-- so to a stat scorer they look exactly like underpowered gear and get "upgraded" away —
-- usually right before you want them. Identified by item class rather than by tooltip
-- text, so it doesn't depend on the client's language.
local function SlotIsProfessionProtected(slot)
    if not slot then return false end

    local config = GetConfig()
    if config and config.Get("gearSwap", "protectProfessionGear") == false then return false end

    local equippedID = GetInventoryItemID and GetInventoryItemID("player", slot)
    if not equippedID then return false end

    local ok, _, _, _, _, _, classID, subclassID = pcall(C_Item.GetItemInfoInstant, equippedID)
    if not ok then return false end

    local CLASS = JustQuest.Constants.ITEM_CLASS
    if classID == CLASS.PROFESSION then return true end
    if classID == CLASS.WEAPON
       and subclassID == JustQuest.Constants.WEAPON_SUBCLASS.FISHING_POLE then
        return true
    end
    return false
end

-- A two-hander takes the off-hand slot with it, but Pawn scores it against the main hand
-- alone — so a 2H can read as an upgrade while being a net loss once the off-hand goes.
-- Returns the item that would come off, or nil if nothing would.
local function DisplacedOffHand(invType, dest)
    if dest ~= 16 or invType ~= "INVTYPE_2HWEAPON" then return nil end

    local offLink = GetInventoryItemLink("player", 17)
    if not offLink then return nil end

    -- Titan's Grip and anything like it: if a two-hander is ALREADY equipped in the main
    -- hand alongside an off-hand, then a two-hander demonstrably does not displace one.
    -- Reading the player's actual state beats maintaining a list of talents that allow it.
    local mainLink = GetInventoryItemLink("player", 16)
    if mainLink then
        local okMain, _, _, _, mainEquipLoc = pcall(C_Item.GetItemInfoInstant, mainLink)
        if okMain and mainEquipLoc == "INVTYPE_2HWEAPON" then return nil end
    end

    return offLink
end

local function SlotIsSetProtected(slot)
    if not slot then return false end

    local config = GetConfig()
    if config and config.Get("gearSwap", "respectEquipmentSets") == false then return false end

    local equippedID = GetInventoryItemID and GetInventoryItemID("player", slot)
    if not equippedID then return false end

    return SetItemIDs()[equippedID] or false
end

-- IsEquippableItem only says "this is an equippable KIND of item" — it does not ask
-- whether THIS character can wear it. Without this, a mage was offered plate and a level
-- 60 was offered gear that wants 70: Pawn scores stats, and stats are stats whoever is
-- carrying them.
--
-- Armour type is the case the requirement read CANNOT catch, because nothing about the
-- item is wrong: a druid may legally equip cloth, so no red text appears and every
-- filter passes it. Only the class's own armour type answers it, so that gate is a
-- separate call rather than more requirement-reading.
--
-- The requirement read lives in GameData so the reward picker uses the same one. This
-- deliberately does NOT go through GameData.CanPlayerUseItem: that ends in IsUsableItem,
-- which reports nil for plenty of ordinary gear, and treating nil as unusable here would
-- silently hide real upgrades. Uncached data degrades to "allow" and the next scan
-- revisits it — a missed pass is cheap, a permanently hidden upgrade is not.
--
-- Cached per itemID because the caller is the deliberately-cheap bag walk that runs on every
-- bag event. Dropped where the verdicts actually change: level-up (gear becomes wearable) and
-- specialization change (the primary-stat answer is per spec, but the key is only the itemID).
local function CanPlayerEquip(link, id)
    if not link then return false end
    -- No id (odd link) means no cache slot — still answer, just don't store under nil.
    if id and usableCache[id] ~= nil then return usableCache[id] end

    local gameData = GetGameData()
    local usable = not (gameData and gameData.ItemFailsARequirement
                        and gameData.ItemFailsARequirement(link))

    if usable and gameData and gameData.ItemIsWrongArmorType
       and gameData.ItemIsWrongArmorType(link) then
        usable = false
    end

    -- Primary stat, same reasoning one step further: an Agility spear is legal for a
    -- Restoration druid to hold and has no armour type to be wrong about, so only the stat
    -- itself says no. This is also the floor when Pawn is absent or its scale is generic.
    if usable and gameData and gameData.ItemIsWrongPrimaryStat
       and gameData.ItemIsWrongPrimaryStat(link) then
        usable = false
    end

    if id then usableCache[id] = usable end
    return usable
end

local frame = CreateFrame("Frame")

local function ItemID(link)
    return link and tonumber(link:match("item:(%d+)"))
end

-- The item an upgrade would displace, as a proper link — nil when there isn't one to name:
-- an empty slot (Pawn's no-baseline sentinel %) displaces nothing. Pawn sometimes hands
-- back a bare "item:..." string, so resolve that to a real link before showing it.
local function ReplacedLink(rec)
    if rec.pct and rec.pct >= 99 then return nil end  -- empty slot / no baseline
    local link = rec.existingLink
    if not link then return nil end
    if not link:find("|H", 1, true) then
        local _, full = C_Item.GetItemInfo(link)
        link = full or link
    end
    return link:find("item:", 1, true) and link or nil
end

local function ResolveSlot(rec)
    local slots = INVTYPE_SLOTS[rec.invType]
    if not slots then return nil end
    -- Target the slot holding the exact item Pawn says it replaces (handles ring
    -- 11-vs-12, weapon 16-vs-17). Pawn's ExistingItemLink is unenchanted, so match by
    -- itemID; when both slots share an itemID (two copies at different upgrade levels)
    -- disambiguate by item level so we replace the weaker one, not the stronger.
    local existingID = ItemID(rec.existingLink)
    if existingID then
        local existingILvl = rec.existingLink and C_Item.GetDetailedItemLevelInfo(rec.existingLink)
        local idFallback
        for _, s in ipairs(slots) do
            local link = GetInventoryItemLink("player", s)
            if ItemID(link) == existingID then
                if not existingILvl or C_Item.GetDetailedItemLevelInfo(link) == existingILvl then
                    return s
                end
                idFallback = idFallback or s
            end
        end
        if idFallback then return idFallback end
    end
    for _, s in ipairs(slots) do
        if not GetInventoryItemLink("player", s) then return s end  -- empty slot
    end
    return slots[1]
end

-- ============================================================
-- Item-level fallback (no Pawn)
-- ============================================================
-- With no Pawn scale nothing scores at all, and the advisor goes silent in a way that reads as
-- "you have no upgrades" rather than "nothing was measured" — the two are indistinguishable
-- from outside. Item level is the crude answer, and crude beats silent while levelling, which
-- is where this addon lives.
--
-- Reached ONLY when Pawn cannot answer, and deliberately blunt: no stat weighting, no role
-- awareness. What keeps it honest is the gate it sits behind — usability, armour type and
-- primary stat are all filtered out before anything is scored, so the worst it can do is prefer
-- a higher-item-level piece the player's spec can legitimately wear.
--
-- Results are shaped exactly like Pawn's, so the minimum-upgrade threshold, slot resolution,
-- the toast and auto-equip all work without knowing which scorer produced them.
local NO_BASELINE = 100  -- empty slot; matches the sentinel FormatUpgrade reads as "no baseline"

local function ItemLevel(link)
    if not link then return nil end
    local ok, ilvl = pcall(C_Item.GetDetailedItemLevelInfo, link)
    return ok and ilvl or nil
end

local function ScoreByItemLevel(link, invType)
    local slots = INVTYPE_SLOTS[invType]
    if not slots then return nil end

    local candidate = ItemLevel(link)
    if not candidate then return nil end  -- uncached: no verdict rather than a wrong one

    -- Against the WEAKEST of a dual slot — the ring or one-hander a new one should displace.
    -- Pawn names the loser itself; here it has to be worked out.
    local worstLink, worstLevel
    for _, s in ipairs(slots) do
        local equipped = GetInventoryItemLink("player", s)
        if not equipped then
            return { isUpgrade = true, pawnPercentUpgrade = NO_BASELINE, byItemLevel = true }
        end
        local level = ItemLevel(equipped)
        if not level then return nil end  -- uncached on this side too: still no verdict
        if not worstLevel or level < worstLevel then
            worstLink, worstLevel = equipped, level
        end
    end

    if candidate <= worstLevel then return nil end
    return {
        isUpgrade          = true,
        -- max(,1) only guards the divide; a real equipped item never reports zero.
        pawnPercentUpgrade = (candidate - worstLevel) / math.max(worstLevel, 1),
        existingItemLink   = worstLink,
        byItemLevel        = true,
    }
end

local function Enabled()
    local config = GetConfig()
    return config and config.Get(nil, "enabled") and config.Get("gearSwap", "advisorEnabled")
end

-- ============================================================
-- Stat delta
-- ============================================================

-- A percentage answers "how much better"; it cannot answer "better at what". A piece that
-- trades mastery for haste and a piece that is simply bigger read identically as "+12%",
-- and only one of those is a decision the player might want to make differently.
--
-- Stats are keyed by the game's own global names (ITEM_MOD_*), whose values are the
-- localized short labels — so the display text comes from the client, not from us.
local STAT_LABEL_FALLBACK = {
    RESISTANCE0_NAME = "Armor",
}

local function StatsFor(link)
    if not link then return nil end
    local getter = (C_Item and C_Item.GetItemStats) or GetItemStats
    if not getter then return nil end
    local ok, stats = pcall(getter, link)
    return ok and type(stats) == "table" and stats or nil
end

-- Up to MAX_STATS lines of "+N Label", biggest absolute change first, gains green and
-- losses red. Returns nil when there is nothing meaningful to say, so the caller can omit
-- the line entirely rather than showing an empty row.
local MAX_STATS = 4

local function StatDeltaText(candidateLink, equippedLink)
    local newStats = StatsFor(candidateLink)
    if not newStats then return nil end
    local oldStats = StatsFor(equippedLink) or {}

    local deltas = {}
    local seen = {}
    local function consider(key)
        if seen[key] then return end
        seen[key] = true
        local diff = (newStats[key] or 0) - (oldStats[key] or 0)
        if diff ~= 0 then
            deltas[#deltas + 1] = { key = key, diff = diff }
        end
    end
    for key in pairs(newStats) do consider(key) end
    for key in pairs(oldStats) do consider(key) end
    if #deltas == 0 then return nil end

    table.sort(deltas, function(a, b) return math.abs(a.diff) > math.abs(b.diff) end)

    local parts = {}
    for i = 1, math.min(MAX_STATS, #deltas) do
        local d = deltas[i]
        local label = _G[d.key] or STAT_LABEL_FALLBACK[d.key] or d.key
        local colour = d.diff > 0 and "|cff40ff40+" or "|cffff4040"
        parts[#parts + 1] = string.format("%s%d|r %s", colour, d.diff, label)
    end
    return table.concat(parts, "   ")
end

-- The toast carries the message; chat does not need to repeat it. Kept as debug so a
-- "why did it equip that" question can still be answered from the log.
local function Notify(msg)
    local services = GetServices()
    if services and services.Debug then services.Debug("GearAdvisor", msg) end
end

local function RefreshUI()
    local ACR = LibStub and LibStub("AceConfigRegistry-3.0", true)
    if ACR then ACR:NotifyChange("JustQuest") end
end

local function Debug(msg)
    local services = GetServices()
    if services and services.Debug then services.Debug("GearAdvisor", msg) end
end

-- Chat line + (unless disabled) a hard-to-miss on-screen toast, so an auto-equip or a fresh
-- upgrade doesn't slip by. Chat gets one flat line; the toast gets the same words as a
-- subject (text) and dimmed detail (sub). link is the item the icon and tooltip show.
-- Takes the toast's own table rather than positional args: the body was doing nothing but
-- unpacking six positionals straight back into it, and two of the three callers pass four.
local function Announce(info)
    Notify(info.sub and (info.text .. "  " .. info.sub) or info.text)
    local config = GetConfig()
    if config and config.Get("gearSwap", "announce") == false then return end
    local toast = GetToast()
    if toast and toast.Show then toast.Show(info) end
end

local function RemoveRec(id)
    for k, r in pairs(recommendations) do
        if r.id == id then recommendations[k] = nil end
    end
end

-- A prompt outlives the scan that raised it, so it can go stale: equip the item yourself
-- (or sell it, or find something better), and the rebuild drops it from the list while the
-- toast is still on screen asking you to equip what you are already wearing. If the item
-- being asked about is no longer recommended, the question is void — release it so the
-- caller withdraws the toast or moves to the next suggestion.
local function WithdrawPromptIfStale()
    if not promptedID then return end
    for _, rec in pairs(recommendations) do
        if rec.id == promptedID then return end
    end
    Debug("prompt withdrawn: " .. tostring(promptedID) .. " is no longer recommended")
    promptedID = nil
end

-- Offer the best current suggestion and WAIT for a decision — the prompt stays until you
-- pick one, rather than fading and leaving the choice unmade. Nothing is auto-suppressed
-- just for having been shown: Skip silences an item for this session, Never for good;
-- otherwise it keeps being offered.
-- Chains: deciding shows the next suggestion, so a batch is handled one at a time.
local function ShowNextPrompt()
    local config = GetConfig()
    local autoEquip = config and config.Get("gearSwap", "autoEquip")

    local best
    -- One pass: the best pick and the pending count read the same table under the same
    -- condition, so counting here costs a line instead of a second traversal.
    local pending = 0
    for _, rec in pairs(recommendations) do
        -- In auto-equip mode, bound items are equipped silently — don't prompt for those.
        -- Except one that would strip the off-hand: auto-equip refuses those, so without
        -- this they'd be equipped by nobody and prompted by nobody.
        local displaces = DisplacedOffHand(rec.invType, ResolveSlot(rec))
        local willAutoEquip = autoEquip and rec.bound and not displaces
        if not tempIgnore[rec.id] then
            pending = pending + 1
            if not willAutoEquip and (not best or rec.pct > best.pct) then
                best = rec
            end
        end
    end
    if not best then
        Debug("no suggestion to prompt")
        -- Nothing left to ask about. Withdraw whatever is still on screen, or a prompt
        -- for an item you already dealt with sits there until the next upgrade drops.
        promptedID = nil
        local toast = GetToast()
        if toast and toast.Hide then toast.Hide() end
        return
    end

    promptedID = best.id
    Debug("prompting: " .. tostring(best.link))
    local ps = GetPawnScoring()
    local detail   = (ps and ps.FormatUpgrade(best.pct)) or "upgrade"
    local replaced = ReplacedLink(best)
    if replaced then detail = detail .. "  ·  replaces " .. replaced end

    -- Resolved now, not at scan time: the player can equip, sell or move things between
    -- the scan and the answer, and EquipRec recomputes these for exactly that reason.
    local destSlot  = ResolveSlot(best)
    local displaces = DisplacedOffHand(best.invType, destSlot)
    -- Losing the off-hand is part of the offer, not a footnote — say so before the click.
    if displaces then detail = detail .. "  ·  also unequips " .. displaces end

    -- Compare against what is actually in the destination slot, not Pawn's baseline link:
    -- the baseline is unenchanted, and for an empty slot there is no baseline at all.
    local equippedLink = destSlot and GetInventoryItemLink("player", destSlot)
    local statLine = StatDeltaText(best.link, equippedLink or replaced)

    local actions = {
        { text = "Equip", func = function()
            GearAdvisor.EquipRec(best, true)
            RemoveRec(best.id)          -- gone from the list; don't re-offer it
            ShowNextPrompt()
        end },
    }

    -- Batch accept, only when there is genuinely a batch. A full re-gear after a dungeon
    -- shouldn't be a slot-by-slot interrogation.
    -- The count goes in the heading, not the button: four buttons already fill the row,
    -- and a two-digit count in the label would push the last one off the frame.
    -- Name the weaker basis. "+18% upgrade" from item level alone is a different claim from
    -- the same number out of a stat scale, and the player can only judge it if they're told.
    local heading = best.byItemLevel and "Gear upgrade (by item level)" or "Gear upgrade"
    if pending > 1 then
        heading = heading .. "  (" .. pending .. " waiting)"
        actions[#actions + 1] = { text = "Equip All", func = function()
            GearAdvisor.EquipAll(true)  -- manual intent: BoEs included, as on the Gear tab
            ShowNextPrompt()
        end }
    end

    actions[#actions + 1] = { text = "Skip", func = function()
        tempIgnore[best.id] = true  -- not now; ask again next session
        ShowNextPrompt()
    end }
    actions[#actions + 1] = { text = "Never", func = function()
        GearAdvisor.Ignore(best.id, best.link)  -- persistent; also drops it from the list
        ShowNextPrompt()
    end }

    Announce{
        head = heading, text = best.link, sub = detail,
        link = best.link, stats = statLine, actions = actions,
    }
end

-- Ask again once the hold clears. Without this the reminder is simply dropped: the hold ends on
-- a clock, and nothing is guaranteed to move afterwards to trigger another scan — arriving in a
-- new zone doesn't touch your bags.
local HoldRecheck
HoldRecheck = function()
    local services = GetServices()
    if not (services and services.ScheduleOnce) then return end
    services.ScheduleOnce("gear_advisor_hold", 1, function()
        if TravelHold() then
            HoldRecheck()
        elseif not promptedID then
            ShowNextPrompt()
        end
    end)
end

-- ============================================================
-- Unique-equipped handling
-- ============================================================

local UNIQUE_PREFIX = ITEM_UNIQUE_EQUIPPABLE or "Unique-Equipped"

-- Returns isUnique(bool), constraintKey(string|nil), maxAllowed(number). Named-set items
-- ("Unique-Equipped: Primordial Stones (3)") share a key and a max; a plain unique-equipped
-- item is keyed to itself with max 1. Result cached by itemID (unique status is static).
local function UniqueInfo(link)
    if not link then return false end  -- empty slot / no item
    local id = ItemID(link)
    if id and uniqueCache[id] then
        local c = uniqueCache[id]
        return c.unique, c.key, c.max
    end
    -- Shared reader: it pcalls the API and surfaces the line args, which this call site
    -- previously did not — two readers of the same tooltip disagreeing about surfacing is
    -- how a client change breaks exactly one of them, and this is the one nobody would
    -- notice, since it only misbehaves while carrying a second copy of a named-unique.
    local gameData = GetGameData()
    local lines = gameData and gameData.TooltipLines and gameData.TooltipLines(link)
    if not lines then return false end  -- not cached yet; don't record a wrong negative

    local unique, key, max = false, nil, 1
    for _, line in ipairs(lines) do
        local text = line and line.leftText
        if text and text:sub(1, #UNIQUE_PREFIX) == UNIQUE_PREFIX then
            unique = true
            -- Named-multiple form "<prefix>: <name> (<n>)".
            local name, n = text:match("^.-:%s*(.-)%s*%((%d+)%)%s*$")
            if name and n then
                key, max = "NAMED:" .. name, tonumber(n)
            else
                key, max = id and ("SELF:" .. id) or "SELF", 1
            end
            break
        end
    end
    if id then uniqueCache[id] = { unique = unique, key = key, max = max } end
    return unique, key, max
end

-- True if equipping `link` (freeing destSlot, if given) would exceed its unique constraint
-- — i.e. you already wear it, or already wear the max of its named set.
local function UniqueConflict(link, destSlot)
    local unique, key, max = UniqueInfo(link)
    if not unique then return false end
    local worn = 0
    for slot = FIRST_SLOT, LAST_SLOT do
        if slot ~= destSlot then
            local eqUnique, eqKey = UniqueInfo(GetInventoryItemLink("player", slot))
            if eqUnique and eqKey == key then worn = worn + 1 end
        end
    end
    return worn >= max
end

-- ============================================================
-- Slot resolution
-- ============================================================


-- ============================================================
-- Scan: score every equippable bag item, keep the best per slot
-- ============================================================

function GearAdvisor.Scan()
    if not Enabled() then Debug("scan skipped: advisor off (master + gearSwap.advisorEnabled)") return end
    -- Out of combat only: Pawn's stat arithmetic throws on secret values in combat.
    if InCombatLockdown() or UnitIsDeadOrGhost("player") then Debug("scan skipped: in combat / dead") return end
    local ps = GetPawnScoring()
    if not ps then Debug("scan skipped: PawnScoring module missing") return end

    local config = GetConfig()
    local minPct = ((config and config.Get("gearSwap", "minUpgradePct")) or 5) / 100
    local ignoreList = (config and config.Get("gearSwap", "ignoreItems")) or {}

    -- Pass 1 — walk the bags for equippable candidates. No Pawn calls: this is the cheap
    -- half, and on most bag events it's all we do.
    local candidates, fingerprint = {}, {}
    local seen = 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and info.hyperlink
            if link and C_Item.IsEquippableItem(link) then
                seen = seen + 1
                local id = ItemID(link)
                local invType = select(4, C_Item.GetItemInfoInstant(link))
                if id and invType and INVTYPE_SLOTS[invType] then
                    -- Fingerprint the full scorable set — links, not IDs, so an item level
                    -- change registers — before the ignore filters, so toggling those can't
                    -- alias two different bag states to the same print.
                    fingerprint[#fingerprint + 1] = link
                    if not tempIgnore[id] and not ignoreList[id]
                       and CanPlayerEquip(link, id) then
                        candidates[#candidates + 1] = {
                            link    = link,
                            id      = id,
                            invType = invType,
                            bound   = info.isBound and true or false,
                        }
                    end
                end
            end
        end
    end

    -- Every score is relative to what you're already wearing, so the worn set belongs in
    -- the print too: upgrading or enchanting equipped gear can retire a recommendation
    -- without a single bag slot moving. Always a fixed-length tail, so it can't be
    -- confused with the bag entries above it.
    for slot = FIRST_SLOT, LAST_SLOT do
        fingerprint[#fingerprint + 1] = GetInventoryItemLink("player", slot) or ""
    end

    -- Bag events fire for every herb looted and every potion sipped. Scoring is the
    -- expensive half — Pawn re-values your equipped gear against every scale, per item —
    -- so skip it entirely unless something that feeds a score actually changed. The two
    -- inputs a fingerprint can't see (your spec, your scales) force instead.
    -- Consumed here, not at the top: a scan that bailed above (combat, dead, Pawn missing)
    -- never scored anything, so the force has to survive for whichever scan does.
    local force = forceNext
    forceNext = false

    local fp = table.concat(fingerprint, "|")
    if not force and fp == lastFingerprint then
        Debug("scan: bags unchanged (" .. seen .. " equippable) — skipped scoring")
        return
    end
    lastFingerprint = fp

    -- Hot path: resolve the applicable Pawn scales ONCE for the whole scan, not per item.
    --
    -- ACTIVE spec, deliberately — NOT EffectiveSpecIndex, and this must not be "fixed" to
    -- match the reward picker. The two answer different questions. Loot specialization
    -- says which spec you want DROPS for; it does not change what you should be wearing
    -- right now. This advisor equips gear, so a Guardian druid farming Feral drops has to
    -- be told about Guardian gear — scoring their bags as Feral would recommend they tank
    -- in DPS gear, and with no Feral scale defined it scores nothing at all and the
    -- advisor silently goes dead. The reward picker follows loot spec because a quest
    -- reward is a thing you keep for later; this is a thing you put on now.
    local spec = GetSpecialization()
    local relevant = ps.RelevantScales(spec)
    if not relevant then
        -- No scale for the spec being played (or no Pawn at all). Item level takes over so the
        -- advisor still says something; see ScoreByItemLevel for why crude beats silent.
        Debug("scan: no Pawn scale applies to the spec you're playing — scoring by item level")
    end

    -- Pass 2 — score.
    local scored = 0
    local recs = {}

    -- Protection is a property of the SLOT, but the loop below runs per candidate: five
    -- rings in the bag asked the same question about slot 11 five times, each a config
    -- read plus an inventory lookup plus a tooltip-class read. The equipped item cannot
    -- change during a synchronous scan, so one answer per slot is the whole truth.
    local protectedSlot = {}
    local function SlotProtected(slot)
        local known = protectedSlot[slot]
        if known == nil then
            known = SlotIsSetProtected(slot) or SlotIsProfessionProtected(slot)
            protectedSlot[slot] = known
        end
        return known
    end
    for _, c in ipairs(candidates) do
        -- Pawn where it can answer, item level where it can't. Written out rather than as
        -- `relevant and ... or ...`: with Pawn present but this item not yet cached, ScoreItem
        -- returns nil and that has to STAY nil, not quietly drop through to the cruder scorer
        -- and mix two kinds of verdict inside one scan.
        local result
        if relevant then
            result = ps.ScoreItem(c.link, spec, relevant)
        else
            result = ScoreByItemLevel(c.link, c.invType)
        end
        if result then scored = scored + 1 end
        if result and result.isUpgrade and result.pawnPercentUpgrade >= minPct then
            local rec = {
                link         = c.link,
                pct          = result.pawnPercentUpgrade,
                existingLink = result.existingItemLink,
                invType      = c.invType,
                bound        = c.bound,
                id           = c.id,
                byItemLevel  = result.byItemLevel,  -- say so in the prompt; it's a weaker claim
            }
            -- Keyed by DESTINATION SLOT, not equip location: a shield, an off-hand weapon
            -- and a held-in-off-hand frill are three equip locations that all land in slot
            -- 17, and only one can be worn — so only the best may stand, or auto-equip
            -- would equip them in table order and let the worst win. Conversely two rings
            -- (11/12) or a main-hand and an off-hand weapon are distinct slots, so both
            -- are offered in the same pass.
            local dest = ResolveSlot(rec)
            local cur  = dest and recs[dest]
            if dest and (not cur or rec.pct > cur.pct)
               and not UniqueConflict(c.link, dest)   -- unique-equipped limit
               and not SlotProtected(dest) then       -- set piece / profession gear
                recs[dest] = rec
            end
        end
    end
    recommendations = recs

    local nRecs = 0
    for _ in pairs(recs) do nRecs = nRecs + 1 end
    Debug(string.format("scan: %d equippable in bags, %d in scorable slots, %d scored (%s), %d recommendation(s)",
        seen, #candidates, scored, relevant and "Pawn" or "item level", nRecs))

    -- A prompt outlives the scan that raised it, so it can go stale: equip the item
    -- yourself (or sell it, or find something better), and the rebuild above drops it from
    -- the list while the toast is still on screen asking you to equip what you are already
    -- wearing. If the item being asked about is no longer recommended, the question is
    -- void — release the prompt so the pass below withdraws it or moves to the next one.
    WithdrawPromptIfStale()

    -- Offer the best suggestion, unless a prompt is already up waiting on you. Nothing is
    -- suppressed for merely having been shown — only your Skip / Never does that — so an
    -- item you equip and later take off is offered again.
    if TravelHold() then
        HoldRecheck()  -- mid-trip: ask on the other side, where the answer is useful
    elseif not promptedID then
        ShowNextPrompt()
    end

    RefreshUI()
end

-- force=true: score even if the bags are unchanged (the scoring inputs moved instead —
-- spec, scale, or settings). It's a flag rather than an argument because scans debounce by
-- key: a plain bag event landing within the window would otherwise replace the forced scan
-- and silently drop the force.
local function ScheduleScan(force)
    if force then forceNext = true end
    local services = GetServices()
    if services and services.ScheduleOnce then
        -- Private timer key (NOT in AUTOMATION_TIMERS) so a modifier-key takeover of
        -- quest automation doesn't cancel gear scanning.
        services.ScheduleOnce("gear_advisor_scan", 0.5, GearAdvisor.Scan)
    else
        GearAdvisor.Scan()
    end
end

-- ============================================================
-- Equip
-- ============================================================

local function CanEquipNow()
    -- Re-check the toggles, not just the physical state. A deferred equip retries on a
    -- timer, so the player can turn the advisor (or auto-equip) off inside that window
    -- and still have gear swapped from a stale recommendation.
    if not Enabled() then return false end
    if InCombatLockdown() or UnitIsDeadOrGhost("player") then return false end
    -- Mid-trip: a travel item only works from an equipped slot, so swapping it out here doesn't
    -- just re-gear you, it cancels the teleport. The caller's retry picks this up on arrival.
    if TravelHold() then return false end
    local services = GetServices()
    if services and services.InSpecialControlState and services.InSpecialControlState() then return false end
    if services and services.ShouldAutomate and not services.ShouldAutomate() then return false end
    -- Equipping mid-turn-in is bag manipulation during a taint-sensitive chain; the
    -- container engine already stands down for exactly this and this path listens to the
    -- same BAG_UPDATE_DELAYED that fires as quest rewards land.
    local safety = GetSafety()
    if safety and safety.IsBusy and safety.IsBusy() then return false end
    return true
end

local function DoEquip(link, slot)
    local services = GetServices()
    if services and services.SafeCall then
        services.SafeCall(C_Item.EquipItemByName, link, slot)
    else
        pcall(C_Item.EquipItemByName, link, slot)
    end
end

-- Equip one recommendation. manual=true when the player clicked (they accept any
-- bind-on-equip popup); auto mode equips already-bound items only, so an unbound BoE
-- is never silently soulbound — it stays a recommendation until equipped by hand.
function GearAdvisor.EquipRec(rec, manual)
    if not rec then return false end
    if not CanEquipNow() then return false end
    if not rec.bound and not manual then return false end
    local slot = ResolveSlot(rec)
    if not slot then return false end
    if UniqueConflict(rec.link, slot) then return false end  -- can't wear a second copy
    -- Taking the off-hand off is a second, unscored change to the player's gear. Pawn
    -- rated the main hand alone, so we cannot claim this is an upgrade — and silently
    -- removing a shield is not something to do on the player's behalf. Recomputed here
    -- fresh here: the scan that produced this recommendation may be seconds old.
    if not manual and DisplacedOffHand(rec.invType, slot) then
        Debug("auto-equip declined: " .. tostring(rec.link) .. " would unequip the off-hand")
        return false
    end
    DoEquip(rec.link, slot)
    return true
end

function GearAdvisor.EquipAll(manual)
    if not CanEquipNow() then
        -- Bound the wait. This retries itself every 2s with no cap, so a blocker that
        -- never clears (advisor switched off, a long vehicle sequence) left a deferred
        -- equip armed indefinitely — and the recommendations it would apply go stale.
        local now = GetTime()
        if not pendingEquip then pendingDeadline = now + PENDING_EQUIP_WINDOW end
        if now > pendingDeadline then
            pendingEquip = false
            return
        end
        pendingEquip  = true
        pendingManual = manual and true or false  -- preserve player-clicked intent across the wait
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- retry after combat
        -- Combat may not be the only blocker (vehicle / dead / modifier held), and
        -- PLAYER_REGEN_ENABLED won't fire again once out of combat, so also poll.
        local services = GetServices()
        if services and services.ScheduleOnce then
            services.ScheduleOnce("gear_advisor_equip_retry", 2, function()
                if pendingEquip then GearAdvisor.EquipAll(pendingManual) end
            end)
        end
        return
    end
    pendingEquip = false
    pendingDeadline = 0
    local equipped = {}
    for _, rec in pairs(recommendations) do
        if GearAdvisor.EquipRec(rec, manual) then
            equipped[#equipped + 1] = rec
        end
    end

    -- Confirm what changed so an auto-equip can't slip by unnoticed — but not while a
    -- prompt is on screen (a passive toast would clobber it and stall the prompt chain).
    if not promptedID then
        if #equipped == 1 then
            local rec = equipped[1]
            local ps = GetPawnScoring()
            Announce{
                head = "Equipped upgrade", text = rec.link, link = rec.link,
                sub = (ps and ps.FormatUpgrade(rec.pct)) or "upgrade",
            }
        elseif #equipped > 1 then
            local links = {}
            for _, rec in ipairs(equipped) do links[#links + 1] = rec.link end
            Announce{
                head = "Equipped " .. #equipped .. " upgrades",
                text = table.concat(links, ", "), link = equipped[1].link,
            }
        end
    end
end

-- ============================================================
-- Public API (ConfigUI, Config.Set hook)
-- ============================================================

function GearAdvisor.GetRecommendations() return recommendations end

-- Manual rescan (the Rescan button / a settings change): clear this session's "Skip"s so
-- everything is offered again, and drop any stale prompt state. "Never" is persistent and
-- is NOT cleared here — use Clear Never List for that.
function GearAdvisor.RescanNow()
    wipe(tempIgnore)
    promptedID = nil
    ScheduleScan(true)  -- the bags haven't changed; the filters have
end

function GearAdvisor.DismissAll()
    -- Dismissing answers the open question too — leaving the toast up would keep asking
    -- about something the player just cleared.
    promptedID = nil
    local toast = GetToast()
    if toast and toast.Hide then toast.Hide() end

    for _, rec in pairs(recommendations) do tempIgnore[rec.id] = true end
    recommendations = {}
    RefreshUI()
end

-- Add an item to the persistent "never recommend" list (the prompt's Never button).
function GearAdvisor.Ignore(id, link)
    if not id then return end
    local config = GetConfig()
    if config then
        local list = config.Get("gearSwap", "ignoreItems") or {}
        list[id] = (link and C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(link)) or true
        config.Set("gearSwap", "ignoreItems", list)
    end
    tempIgnore[id] = true
    for k, r in pairs(recommendations) do if r.id == id then recommendations[k] = nil end end
    RefreshUI()
end

-- /jq gear check — dump where the pipeline stands (advisor state, Pawn scales, and a
-- Pawn verdict for the equipped weapon + each bag item), so "no recommendation" can be
-- pinned to Pawn config vs an uncached item vs the scoring itself.
function GearAdvisor.Diagnose()
    local function p(s) print("|cff00ccffJQ Gear:|r " .. s) end
    local config, ps = GetConfig(), GetPawnScoring()
    local _, className, classID = UnitClass("player")
    local activeIdx = GetSpecialization and GetSpecialization()
    local activeName = (activeIdx and GetSpecializationInfo) and select(2, GetSpecializationInfo(activeIdx)) or "?"
    local lootIdx = ps and ps.EffectiveSpecIndex()

    p(("advisor enabled: %s | Pawn present: %s | usePawnScoring: %s"):format(
        tostring(Enabled() and true or false),
        tostring(PawnGetItemData ~= nil),
        tostring(not (config and config.Get("quest", "usePawnScoring") == false))))
    p(("active spec: %s (index %s) | loot-spec index: %s | class: %s (id %s)"):format(
        tostring(activeName), tostring(activeIdx), tostring(lootIdx), tostring(className), tostring(classID)))

    if PawnCommon and PawnCommon.Scales then
        local anyVisible = false
        for name, scale in pairs(PawnCommon.Scales) do
            if PawnIsScaleVisible and PawnIsScaleVisible(name) then
                anyVisible = true
                local applies = scale.ClassID == nil
                    or (scale.ClassID == classID and (scale.SpecID == nil or scale.SpecID == activeIdx))
                p(("  scale: %s  ClassID=%s SpecID=%s%s"):format(name, tostring(scale.ClassID),
                    tostring(scale.SpecID), applies and "  |cff00ff00<= applies to you|r" or ""))
            end
        end
        if not anyVisible then p("  |cffffaa00no visible Pawn scale — scoring by item level; create one in Pawn for stat-aware picks|r") end
    else
        p("  |cffffaa00PawnCommon.Scales unavailable (Pawn not loaded?) — scoring by item level|r")
    end

    local mh = GetInventoryItemLink("player", 16)
    if mh and ps then
        local r = ps.ScoreItem(mh, activeIdx)
        p("equipped weapon: " .. mh .. " -> " .. (r and ("upgrade=" .. tostring(r.isUpgrade)) or "nil (no verdict)"))
    end

    -- Resolved once, exactly as the scan does it, so the verdicts below are the ones the
    -- engine would actually reach rather than a second opinion computed a different way.
    local relevant = ps and ps.RelevantScales(activeIdx)

    local found = false
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and info.hyperlink
            if link and C_Item.IsEquippableItem(link) then
                local invType = select(4, C_Item.GetItemInfoInstant(link))
                if invType and INVTYPE_SLOTS[invType] then
                    found = true
                    local cached = PawnGetItemData and (PawnGetItemData(link) ~= nil)
                    local r
                    if relevant then
                        r = ps.ScoreItem(link, activeIdx, relevant)
                    else
                        r = ScoreByItemLevel(link, invType)
                    end
                    -- Report the item levels the verdict turns on: a Pawn percentage is a
                    -- ratio, so it reads the same whether the baseline is comparable or
                    -- scores near zero. Only the levels show which one you're looking at.
                    local verdict = "nil"
                    if r then
                        verdict = ("%supgrade=%s pct=%.2f ilvl=%s vs %s"):format(
                            r.byItemLevel and "[item level] " or "",
                            tostring(r.isUpgrade), r.pawnPercentUpgrade or 0,
                            tostring(C_Item.GetDetailedItemLevelInfo(link) or "?"),
                            r.existingItemLink
                                and tostring(C_Item.GetDetailedItemLevelInfo(r.existingItemLink) or "?")
                                or "empty slot")
                    end
                    -- Show wearability too: a filtered item is otherwise indistinguishable
                    -- from a scoring failure when someone asks why it wasn't offered.
                    local wearable = CanPlayerEquip(link, ItemID(link))
                    p(("  bag: %s [%s] cached=%s wearable=%s -> %s"):format(
                        link, invType, tostring(cached), tostring(wearable), verdict))
                end
            end
        end
    end
    if not found then p("  (no equippable bag items in scorable slots)") end

    local n = 0
    for _ in pairs(recommendations) do n = n + 1 end
    p("current recommendations: " .. n)
end

-- ============================================================
-- Events (own frame — independent of the quest-automation gate)
-- ============================================================

local function ScanThenMaybeEquip(force)
    ScheduleScan(force)
    local config = GetConfig()
    if config and config.Get("gearSwap", "autoEquip") then
        -- Equip after the scan settles (scan is debounced 0.5s; give it a moment).
        local services = GetServices()
        if services and services.ScheduleOnce then
            services.ScheduleOnce("gear_advisor_autoequip", 0.75, function() GearAdvisor.EquipAll(false) end)
        end
    end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("EQUIPMENT_SETS_CHANGED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        if Enabled() then ScheduleScan(true) end

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Arrived. If a travel item brought us here it has done its job, so end the hold: now is
        -- when "you're still wearing the teleport cloak" is worth saying. Forced because the trip
        -- is what changed, not the bags. A blocked auto-equip is already retrying on its own.
        holdUntil = 0
        if Enabled() then ScheduleScan(true) end

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- Prompt (and, in auto-equip mode, equip) the best gear for the new spec. Forced:
        -- your bags are identical, but every score in them just changed.
        if arg1 == "player" then
            -- The usability verdicts have to go with them: they are cached per itemID, but
            -- the primary-stat gate answers per SPEC. A druid going Restoration -> Feral
            -- would otherwise keep judging Agility gear by the Intellect answer.
            wipe(usableCache)
            if Enabled() then ScanThenMaybeEquip(true) end
        end

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- Something with a Use: effect just went on — a teleport cloak, a port trinket. Give it
        -- a moment to be used before offering to take it back off again (see TravelHold).
        if arg1 and HasUseEffect(arg1) then holdUntil = GetTime() + TRAVEL_HOLD end

        -- What you're wearing is half of every score, and equipping the recommended item
        -- yourself is the case that has to retire its own prompt. Bag events cover most of
        -- this by side effect, but this is the signal that actually means it. Not forced:
        -- the scan is debounced and fingerprinted, so a swap that changes nothing scorable
        -- costs one bag walk.
        if Enabled() then ScanThenMaybeEquip() end

    elseif event == "EQUIPMENT_SETS_CHANGED" then
        -- Saving, editing or deleting a set changes which equipped pieces are protected,
        -- and the bags haven't moved — so drop the cache and force past the fingerprint.
        setItemIDs = nil
        if Enabled() then ScheduleScan(true) end

    elseif event == "PLAYER_LEVEL_UP" then
        -- Gear held back for being over-level can become wearable here, and the bags
        -- haven't changed — so the usability verdicts have to be dropped and the scan
        -- forced past its fingerprint check, or the newly-legal upgrade stays invisible
        -- until something unrelated moves in your bags.
        wipe(usableCache)
        if Enabled() then ScanThenMaybeEquip(true) end

    elseif event == "BAG_UPDATE_DELAYED" then
        -- The spammy one — fires for looted junk, sold greys, a sipped potion. Not forced,
        -- so it costs a bag walk and stops there unless equippable contents moved.
        if Enabled() then ScanThenMaybeEquip() end

    elseif event == "PLAYER_REGEN_ENABLED" then
        frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if pendingEquip then
            GearAdvisor.EquipAll(pendingManual)  -- clears pendingEquip on success, else re-defers
        end
    end
end)

function GearAdvisor.Initialize()
    -- Frame + events wired at load; scanning begins on PLAYER_LOGIN when enabled.
end

JustQuest.Core.RegisterModule("GearAdvisor", GearAdvisor, {})

return GearAdvisor
