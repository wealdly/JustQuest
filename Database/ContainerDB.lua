-- ContainerDB.lua — built-in "never auto-open" blacklist for the container engine.
--
-- Openable containers are detected LIVE at runtime (C_Container.GetContainerItemInfo →
-- info.hasLoot / info.isLocked), with tools/gen_containers.py → Database/ContainerData.lua as
-- an offline fallback. There is no hand-maintained "safe list" here anymore — only the small
-- blacklist below: a belt-and-suspenders default over the live flag check for items that can
-- look openable but shouldn't be auto-opened. Players add their own via /jq container block.
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
