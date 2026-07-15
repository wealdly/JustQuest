-- PawnStatInjection.lua — optionally expose Item Level as a weightable Pawn stat.
--
-- Pawn scores by stat weights and can under-value a big item-level jump when secondary
-- stats are flat (a lower-ilvl "perfect" piece out-scoring a higher-ilvl upgrade). Opt in
-- (gearSwap.weightItemLevel) and JustQuest injects each item's effective item level into
-- Pawn's stat table as "ItemLevel", so you can give it a weight in your scale (e.g.
-- ItemLevel=5) and item-level jumps always register.
--
-- This wraps Pawn's GLOBAL PawnGetItemData, so it affects ALL Pawn scoring (tooltips,
-- reward picks, the advisor) — hence opt-in, off by default. The wrapper checks the toggle
-- on every call, so turning it off (which also clears Pawn's cache) stops injecting; the
-- wrapper itself is installed once and left in place (a global can't be cleanly unwrapped).

local ADDON_NAME, JustQuest = ...

local PawnStatInjection = {}

local GetConfig  = JustQuest.Core.ModuleGetter("Config")
local hooked     = false
local uiInjected = false

local function Enabled()
    local config = GetConfig()
    return config and config.Get("gearSwap", "weightItemLevel")
end

-- Add an item's effective item level to its Pawn stat table(s) as "ItemLevel".
local function Inject(item)
    if not item or not item.Stats or item.__jqItemLevel then return item end
    if not Enabled() then return item end
    if item.Level and item.Level > 0 and PawnAddStatToTable then
        PawnAddStatToTable(item.Stats, "ItemLevel", item.Level)
        if item.UnenchantedStats then
            PawnAddStatToTable(item.UnenchantedStats, "ItemLevel", item.Level)
        end
        if item.Values then item.Values = nil end  -- force a re-score with the new stat
        item.__jqItemLevel = true
    end
    return item
end

-- Show "Item Level" in Pawn's stat-config UI (under a "JustQuest" heading) so it can be
-- weighted without hand-editing the scale string. Guarded — safe to call more than once.
local function InjectUI()
    if uiInjected or not PawnStats then return end
    table.insert(PawnStats, 1, {"Item Level", "ItemLevel",
        "The item's effective item level (includes upgrades and scaling)."})
    table.insert(PawnStats, 1, {"JustQuest"})
    uiInjected = true
end

-- Install the wrapper once (Pawn must be loaded). Clears Pawn's cache so already-scored
-- items pick up the injected stat. Called when the toggle turns on / on login if on.
function PawnStatInjection.EnsureHook()
    if hooked then
        if PawnClearCache then PawnClearCache() end
        return true
    end
    if not (PawnGetItemData and PawnAddStatToTable) then return false end
    local original = PawnGetItemData
    PawnGetItemData = function(itemLink) return Inject(original(itemLink)) end
    InjectUI()
    if PawnClearCache then PawnClearCache() end
    hooked = true
    return true
end

-- Called by the Config.Set hook when the toggle changes (either direction).
function PawnStatInjection.Refresh()
    if Enabled() then
        PawnStatInjection.EnsureHook()
    elseif hooked and PawnClearCache then
        PawnClearCache()  -- drop injected items promptly; wrapper stays but returns as-is
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")  -- Pawn is loaded by now, whatever the addon order
frame:SetScript("OnEvent", function()
    if Enabled() then PawnStatInjection.EnsureHook() end
end)

function PawnStatInjection.Initialize()
    -- Wrapper is installed lazily on login / toggle-on so it's never present unless opted in.
end

JustQuest.Core.RegisterModule("PawnStatInjection", PawnStatInjection, {})

return PawnStatInjection
