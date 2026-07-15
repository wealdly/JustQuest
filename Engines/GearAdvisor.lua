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
local pendingEquip    = false
local pendingManual   = false  -- carry the manual (player-clicked) intent across a combat defer
local promptActive    = false  -- a prompt is on screen, waiting for your decision
local lastFingerprint          -- equippable bag contents at the last scored scan
local forceNext       = false  -- score the next scan even if the bags look unchanged

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

local function Enabled()
    local config = GetConfig()
    return config and config.Get(nil, "enabled") and config.Get("gearSwap", "advisorEnabled")
end

local function Notify(msg)
    local services = GetServices()
    if services and services.Info then services.Info(msg) else print("|cff00ccffJustQuest:|r " .. msg) end
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
local function Announce(head, text, sub, link, actions)
    Notify(sub and (text .. "  " .. sub) or text)
    local config = GetConfig()
    if config and config.Get("gearSwap", "announce") == false then return end
    local toast = GetToast()
    if toast and toast.Show then
        toast.Show({ link = link, head = head, text = text, sub = sub, actions = actions })
    end
end

local function RemoveRec(id)
    for k, r in pairs(recommendations) do
        if r.id == id then recommendations[k] = nil end
    end
end

-- Offer the best current suggestion and WAIT for a decision — the prompt stays until you
-- pick one (Dugi's model). Nothing is auto-suppressed just for having been shown: Skip
-- silences an item for this session, Never for good; otherwise it keeps being offered.
-- Chains: deciding shows the next suggestion, so a batch is handled one at a time.
local function ShowNextPrompt()
    promptActive = false
    local config = GetConfig()
    local autoEquip = config and config.Get("gearSwap", "autoEquip")

    local best
    for _, rec in pairs(recommendations) do
        -- In auto-equip mode, bound items are equipped silently — don't prompt for those.
        local willAutoEquip = autoEquip and rec.bound
        if not willAutoEquip and not tempIgnore[rec.id]
           and (not best or rec.pct > best.pct) then
            best = rec
        end
    end
    if not best then Debug("no suggestion to prompt") return end

    promptActive = true
    Debug("prompting: " .. tostring(best.link))
    local ps = GetPawnScoring()
    local detail   = (ps and ps.FormatUpgrade(best.pct)) or "upgrade"
    local replaced = ReplacedLink(best)
    if replaced then detail = detail .. "  ·  replaces " .. replaced end
    Announce("Gear upgrade", best.link, detail, best.link, {
        { text = "Equip", func = function()
            GearAdvisor.EquipRec(best, true)
            RemoveRec(best.id)          -- gone from the list; don't re-offer it
            ShowNextPrompt()
        end },
        { text = "Skip", func = function()
            tempIgnore[best.id] = true  -- not now; ask again next session
            ShowNextPrompt()
        end },
        { text = "Never", func = function()
            GearAdvisor.Ignore(best.id, best.link)  -- persistent; also drops it from the list
            ShowNextPrompt()
        end },
    })
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
    local data = C_TooltipInfo and C_TooltipInfo.GetHyperlink(link)
    if not data then return false end  -- not cached yet; don't record a wrong negative
    local unique, key, max = false, nil, 1
    if data.lines then
        for _, line in ipairs(data.lines) do
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
                    if not tempIgnore[id] and not ignoreList[id] then
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
    local spec = GetSpecialization()
    local relevant = ps.RelevantScales(spec)

    -- Pass 2 — score.
    local scored = 0
    local recs = {}
    for _, c in ipairs(candidates) do
        -- Active-spec scales precomputed above; nil relevant -> nothing to score.
        local result = relevant and ps.ScoreItem(c.link, spec, relevant)
        if result then scored = scored + 1 end
        if result and result.isUpgrade and result.pawnPercentUpgrade >= minPct then
            local rec = {
                link         = c.link,
                pct          = result.pawnPercentUpgrade,
                existingLink = result.existingItemLink,
                invType      = c.invType,
                bound        = c.bound,
                id           = c.id,
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
               and not UniqueConflict(c.link, dest) then  -- unique-equipped limit
                recs[dest] = rec
            end
        end
    end
    recommendations = recs

    local nRecs = 0
    for _ in pairs(recs) do nRecs = nRecs + 1 end
    Debug(string.format("scan: %d equippable in bags, %d in scorable slots, %d got a Pawn verdict, %d recommendation(s)",
        seen, #candidates, scored, nRecs))

    -- Offer the best suggestion, unless a prompt is already up waiting on you. Nothing is
    -- suppressed for merely having been shown — only your Skip / Never does that — so an
    -- item you equip and later take off is offered again.
    if not promptActive then ShowNextPrompt() end

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
    if InCombatLockdown() or UnitIsDeadOrGhost("player") then return false end
    local services = GetServices()
    if services and services.InSpecialControlState and services.InSpecialControlState() then return false end
    if services and services.ShouldAutomate and not services.ShouldAutomate() then return false end
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
    DoEquip(rec.link, slot)
    return true
end

function GearAdvisor.EquipAll(manual)
    if not CanEquipNow() then
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
    local equipped = {}
    for _, rec in pairs(recommendations) do
        if GearAdvisor.EquipRec(rec, manual) then
            equipped[#equipped + 1] = rec
        end
    end

    -- Confirm what changed so an auto-equip can't slip by unnoticed — but not while a
    -- prompt is on screen (a passive toast would clobber it and stall the prompt chain).
    if not promptActive then
        if #equipped == 1 then
            local rec = equipped[1]
            local ps = GetPawnScoring()
            Announce("Equipped upgrade", rec.link,
                (ps and ps.FormatUpgrade(rec.pct)) or "upgrade", rec.link)
        elseif #equipped > 1 then
            local links = {}
            for _, rec in ipairs(equipped) do links[#links + 1] = rec.link end
            Announce("Equipped " .. #equipped .. " upgrades", table.concat(links, ", "),
                nil, equipped[1].link)
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
    promptActive = false
    ScheduleScan(true)  -- the bags haven't changed; the filters have
end

function GearAdvisor.DismissAll()
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
        if not anyVisible then p("  |cffff0000no visible Pawn scale — enable/create one for this spec in Pawn|r") end
    else
        p("  |cffff0000PawnCommon.Scales unavailable (Pawn not loaded?)|r")
    end

    local mh = GetInventoryItemLink("player", 16)
    if mh and ps then
        local r = ps.ScoreItem(mh, activeIdx)
        p("equipped weapon: " .. mh .. " -> " .. (r and ("upgrade=" .. tostring(r.isUpgrade)) or "nil (no verdict)"))
    end

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
                    local r = ps and ps.ScoreItem(link, activeIdx)
                    -- Report the item levels the verdict turns on: a Pawn percentage is a
                    -- ratio, so it reads the same whether the baseline is comparable or
                    -- scores near zero. Only the levels show which one you're looking at.
                    local verdict = "nil"
                    if r then
                        verdict = ("upgrade=%s pct=%.2f ilvl=%s vs %s"):format(
                            tostring(r.isUpgrade), r.pawnPercentUpgrade or 0,
                            tostring(C_Item.GetDetailedItemLevelInfo(link) or "?"),
                            r.existingItemLink
                                and tostring(C_Item.GetDetailedItemLevelInfo(r.existingItemLink) or "?")
                                or "empty slot")
                    end
                    p(("  bag: %s [%s] cached=%s -> %s"):format(link, invType, tostring(cached), verdict))
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
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        if Enabled() then ScheduleScan(true) end

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- Prompt (and, in auto-equip mode, equip) the best gear for the new spec. Forced:
        -- your bags are identical, but every score in them just changed.
        if arg1 == "player" and Enabled() then
            ScanThenMaybeEquip(true)
        end

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
