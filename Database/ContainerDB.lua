-- ContainerDB.lua — built-in "never auto-open" blacklist for the container engine.
--
-- Openable containers are detected LIVE at runtime: C_Container.GetContainerItemInfo returns
-- info.hasLoot (the runtime ITEM_FLAG_OPENABLE — "right-click to open", set by the game on
-- every item that opens to give loot and on nothing else) and info.isLocked (lockbox). Both are
-- Nilable = false, so the read never fails and no offline item list is needed. One used to sit
-- here as a "fallback" and was unreachable: it was generated from ItemSparse.Flags_0 & 0x4,
-- i.e. a stale copy of the very flag it was backing up, so it could never know anything the
-- live read did not.
--
-- What remains is the small blacklist below — a belt-and-suspenders default over the live flag
-- for items that look openable but shouldn't be auto-opened, which is NOT derivable from the
-- flag. Players add their own via /jq container block.
--
-- Prior art that informed JustQuest's container automation (thanks to Gogo#0298 &
-- TechnoHunter#2706 and these addons): Open Sesame!, Auto Open Items, AutoClam, AutoOpen,
-- kAutoOpen / kAutoOpen Dragonflight, and the Openables WeakAura.

local ADDON_NAME, JustQuest = ...

JustQuest.Database = JustQuest.Database or {}

-- Built-in defaults that must never be auto-opened. The user blacklist adds to this.
JustQuest.Database.DANGEROUS_CONTAINERS = {
    -- Items requiring special handling
    [94295]  = "Primal Egg",                   -- Requires hatching
    [191784] = "Dragon Shard of Knowledge",    -- Profession specialization token
    [151568] = "Primal Sargerite",             -- Currency conversion

    -- Not actual containers (on-use items / currency / tokens)
    [33154]  = "Sinister Squashling",          -- Pet item, not container
    [44792]  = "Blossoming Branch",            -- Quest/toy item, not container
    [23083]  = "Captured Flame",               -- Midsummer currency, not container
    [23247]  = "Burning Blossom",              -- Midsummer currency, not container
    [103533] = "Vicious Saddle",               -- PvP mount token, not container
    [45624]  = "Emblem of Conquest",           -- Old currency token, not container
    [116415] = "Shiny Pet Charm",              -- Currency, not container
    [120302] = "Weapon Enhancement Token",     -- Token item, not container
}
