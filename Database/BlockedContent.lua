-- BlockedContent.lua — Static blocked quests and dangerous services lookup tables

local ADDON_NAME, JustQuest = ...

JustQuest.Database = JustQuest.Database or {}

-- ============================================================
-- BLOCKED QUESTS
-- ============================================================
-- All queries go through Services.IsQuestBlocked() which checks this combined
-- with user-configured blocked quests from Config. Do not call this table directly.

JustQuest.Database.BLOCKED_QUESTS = {
    -- ========================================
    -- Legion - Artifact/Class Hall
    -- ========================================
    [43923] = "Artifact Quest - Requires Manual Selection",
    [43924] = "Artifact Quest - Requires Manual Selection",
    [43925] = "Artifact Quest - Requires Manual Selection",

    -- ========================================
    -- Dragonflight - Profession Quests
    -- ========================================
    [71162] = "Profession Quest - Special Mechanics",
    [71165] = "Profession Quest - Special Mechanics",
    [71138] = "Profession Quest - Special Mechanics",
    [71178] = "Profession Quest - Special Mechanics",

    -- ========================================
    -- Classic - Problematic Quests
    -- ========================================
    [25] = "Classic Quest - Known Issues",
    [309] = "Classic Quest - Known Issues",
    [434] = "Classic Quest - Known Issues",
    [435] = "Classic Quest - Known Issues",
    [590] = "Classic Quest - Known Issues",
    [648] = "Classic Quest - Known Issues",
    [836] = "Classic Quest - Known Issues",
    [1246] = "Classic Quest - Known Issues",
    [1249] = "Classic Quest - Known Issues",
    [1324] = "Classic Quest - Known Issues",
}


