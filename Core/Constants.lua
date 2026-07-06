-- Constants.lua

local ADDON_NAME, JustQuest = ...
JustQuest.Constants = {}

-- ============================================================
-- Game Constants
-- ============================================================

JustQuest.Constants.QUEST_TAGS = {
    PVP = 41,           -- Enum.QuestTag.PvP: static PVP quests (battleground, honor, etc.)
    PVP_WORLD_TYPE = 3, -- Enum.QuestTagType.PvP: PVP world quest type (worldQuestType field)
    HEROIC = 85,        -- Enum.QuestTag.Heroic: formerly misnamed ESCORT; 85 is Heroic, not Escort
}

JustQuest.Constants.EQUIPMENT_SLOTS = {
    INVTYPE_HEAD = 1, 
    INVTYPE_NECK = 2, 
    INVTYPE_SHOULDER = 3, 
    INVTYPE_CHEST = 5, 
    INVTYPE_ROBE = 5,
    INVTYPE_WAIST = 6, 
    INVTYPE_LEGS = 7, 
    INVTYPE_FEET = 8, 
    INVTYPE_WRIST = 9, 
    INVTYPE_HAND = 10,
    INVTYPE_FINGER = {11, 12}, 
    INVTYPE_TRINKET = {13, 14}, 
    INVTYPE_CLOAK = 15,
    INVTYPE_WEAPON = {16, 17},  -- 1H weapon fits mainhand OR offhand; compare against weaker
    INVTYPE_2HWEAPON = 16, 
    INVTYPE_WEAPONMAINHAND = 16,
    INVTYPE_WEAPONOFFHAND = 17, 
    INVTYPE_SHIELD = 17, 
    INVTYPE_HOLDABLE = 17, 
    INVTYPE_RANGED = 18,
}

-- GetItemInfo return value 14
JustQuest.Constants.BIND_TYPES = {
    NONE = 0,
    PICKUP = 1,
    EQUIP = 2,   -- BoE — has auction house value
    USE = 3,
    QUEST = 4,
}

-- Enum.ItemClass values (locale-independent, from ItemConstantsDocumentation)
JustQuest.Constants.ITEM_CLASS = {
    CONSUMABLE    = 0,
    CONTAINER     = 1,
    WEAPON        = 2,
    ARMOR         = 4,
    QUESTITEM     = 12,
    MISCELLANEOUS = 15,
    BATTLEPET     = 17,
}

-- Enum.ItemMiscellaneousSubclass values
JustQuest.Constants.ITEM_MISC_SUBCLASS = {
    JUNK            = 0,
    COMPANION_PET   = 2,
    MOUNT           = 5,
    MOUNT_EQUIPMENT = 6,
}

-- ============================================================
-- Timing Constants
-- ============================================================

JustQuest.Constants.TIMING = {
    -- Step delays (scaled by timing multiplier)
    SERVER_SYNC_DELAY = 0.15,
    QUEST_PUMP_STANDARD = 0.15,
    GOSSIP_REENTER_COOLDOWN = 0.15,
    REINTERACT_CHECK_DELAY = 0.15,
    REINTERACT_AFTER_TURNIN = 0.15,
    CONTAINER_SCAN_AFTER_AUTOMATION = 0.25,
    
    QUEST_ACCEPT_POLL_INTERVAL = 0.05,
    
    -- Safety thresholds (not scaled). These bound the gap between consecutive
    -- automation steps (one server round-trip), NOT the whole loop — _lastProcessingTime
    -- updates every step, so a stall only grows the gap when a step's reply never comes.
    -- A normal step is well under a second, so ~1.5s already clears worst-case latency.
    QUEST_PROCESSING_TIMEOUT = 1.5,
    AUTO_RECOVERY_TIMEOUT = 1.5,
    REINTERACT_QUEST_WINDOW = 0.5,
    GOSSIP_REPEAT_WINDOW = 1.50,
    
    -- Container housekeeping (not scaled)
    CONTAINER_THROTTLE = 0.5,
    CONTAINER_CLEANUP_INTERVAL = 60,
    CONTAINER_STALE_TIMEOUT = 120,
    CONTAINER_PERIODIC_SCAN = 30,
    
    -- Repump backoff (not scaled). TOTAL_TIME bounds how long a re-check keeps
    -- polling for server data that lags behind an accept/turn-in/gossip step
    -- (and how long legacy greeting polling waits) before giving up.
    RE_PUMP_MAX_DELAY = 0.3,
    RE_PUMP_TOTAL_TIME = 1.5,
    RE_PUMP_GROWTH_FACTOR = 1.4,
}

-- ============================================================
-- Limits and Thresholds
-- ============================================================

JustQuest.Constants.LIMITS = {
    CHAIN_DEPTH = 10,
    MAX_RETRIES = 2,
    ITEM_LEVEL_BUFFER = 0,  -- reward must meet or exceed equipped ilvl to count as upgrade
    CONTAINER_MAX_RETRIES = 3,
}

-- ============================================================
-- Default Configuration
-- ============================================================

JustQuest.Constants.DEFAULTS = {
    profile = {
        enabled = true,
        skipCinematics = false,
        debugMode = false,
        fastMode = false,
        
        quest = {
            enabled = true,
            acceptEscort = false,
            acceptPvP = false,
            acceptRepeatable = true,
            acceptTrade = true,
            acceptTrivial = true,
            autoReward = false,
            simpleRewardMode = false,
            usePawnScoring = true,   -- use Pawn stat-weight scoring when Pawn is installed
            pawnUseLootSpec = true,  -- follow Loot Specialization setting for Pawn scale selection
            currencyQuestWhitelist = {},  -- quests allowed to auto-spend currencies
            acceptAccountCompleted = true,
            acceptQuestItems = true,
            blockedQuests = {},
        },
        
        gossip = {
            enabled = true,
            aggressive = true,  -- auto-advance any gossip option to reach quests; false = conservative (quest-flagged / single Blizzard-service step only)
            whitelist = {},
            blacklist = {
                -- Teleportation / portals (instant travel without confirmation)
                "teleport me",
                "teleport to",
                "teleport us",
                "send me to",
                "take me to",
                "transport me",
                "transport to",
                "portal to",
                "open a portal",
                "open portal",
                "wormhole",
                -- Timeline / phase changes
                "travel back in time",
                "travel to the past",
                "travel to another",
                -- Story / campaign skips (permanent choices)
                "i have heard this tale before",
                "i have heard this story before",
                "skip the campaign",
                "skip the first three chapters",
                "skip chapter",
            },
        },
        
        containers = {
            enabled = true,
            throttleDelay = 0.5,
            useDatabaseFallback = false,
            whitelist = {},
            blacklist = {},
        },

        lfgQuickExit = {
            buttonX = 280,
            buttonY = -120,
            positionInitialized = false,
            resetInstanceOnExit = false,
            exitGlowSeen = false,  -- glow the Exit button until first use, then stop
        },
        
        -- Auto-generated from TIMING table
        advanced = {},
	}
}

local function GenerateAdvancedDefaults()
    local advanced = JustQuest.Constants.DEFAULTS.profile.advanced
    
    for key, value in pairs(JustQuest.Constants.TIMING) do
        local camelKey = key:sub(1,1):lower() .. key:sub(2):gsub("_(.)", function(c) return c:upper() end)
        advanced[camelKey] = value
    end
    
    advanced.timingMultiplier = 1.0
    advanced.chainDepth = JustQuest.Constants.LIMITS.CHAIN_DEPTH
end

GenerateAdvancedDefaults()


-- Non-quest/gossip NPC frames — automation halts if any are visible
JustQuest.Constants.INTERFERING_FRAMES = {
    "MerchantFrame",
    "TrainerFrame",
    "ClassTrainerFrame",
    "FlightMapFrame",
    "TaxiFrame",
    "BankFrame",
    "GuildBankFrame",
    "VoidStorageFrame",
    "AuctionHouseFrame",
    "MailFrame",
    "PetStableFrame",
    "TabardFrame",
    "GuildRegistrarFrame",
    "TransmogrifyFrame",
    "ItemUpgradeFrame",
    "ObliterumForgeFrame",
    "ScrappingMachineFrame",
    "CharacterCustomizeFrame",
    "PVPMatchScoreboard",
    "CommunitiesFrame",
    "WarboardQuestChoiceFrame",
}

-- ============================================================
-- Event Mapping
-- ============================================================

JustQuest.Constants.EVENTS = {
	QUEST_DETAIL = "QUEST_DETAIL",
	QUEST_PROGRESS = "QUEST_PROGRESS", 
    QUEST_COMPLETE = "QUEST_COMPLETE",
    QUEST_AUTOCOMPLETE = "QUEST_AUTOCOMPLETE",
    QUEST_GREETING = "QUEST_GREETING",
    QUEST_LOG_UPDATE = "QUEST_LOG_UPDATE",
    QUEST_TURNED_IN = "QUEST_TURNED_IN",
    QUEST_ACCEPTED = "QUEST_ACCEPTED",
    QUEST_FINISHED = "QUEST_FINISHED",
    QUEST_ACCEPT_CONFIRM = "QUEST_ACCEPT_CONFIRM",
    QUEST_ITEM_UPDATE = "QUEST_ITEM_UPDATE",
    QUEST_DATA_LOAD_RESULT = "QUEST_DATA_LOAD_RESULT",
    
    PLAYER_CHOICE_UPDATE = "PLAYER_CHOICE_UPDATE",
    PLAYER_CHOICE_CLOSE = "PLAYER_CHOICE_CLOSE",
    
    GOSSIP_SHOW = "GOSSIP_SHOW",
    GOSSIP_CONFIRM = "GOSSIP_CONFIRM",
    GOSSIP_CONFIRM_CANCEL = "GOSSIP_CONFIRM_CANCEL",
    GOSSIP_CLOSED = "GOSSIP_CLOSED",
    GOSSIP_OPTIONS_REFRESHED = "GOSSIP_OPTIONS_REFRESHED",
    
    MODIFIER_STATE_CHANGED = "MODIFIER_STATE_CHANGED",
    PLAYER_TARGET_CHANGED = "PLAYER_TARGET_CHANGED",
    
	CINEMATIC_START = "CINEMATIC_START",
    PLAY_MOVIE = "PLAY_MOVIE"
}

JustQuest.Constants.BYPASS_SAFETY_EVENTS = {
	-- Quest lifecycle events — these fire while frames may already be closing
	-- or without any NPC interaction frame at all (popup quests, proximity triggers).
	-- Each handler performs its own CanAutomate() / safety gate internally.
	[JustQuest.Constants.EVENTS.QUEST_DETAIL] = true,
	[JustQuest.Constants.EVENTS.QUEST_PROGRESS] = true,
	[JustQuest.Constants.EVENTS.QUEST_COMPLETE] = true,
	[JustQuest.Constants.EVENTS.QUEST_AUTOCOMPLETE] = true,
	[JustQuest.Constants.EVENTS.QUEST_FINISHED] = true,
	[JustQuest.Constants.EVENTS.QUEST_ACCEPTED] = true,
	[JustQuest.Constants.EVENTS.QUEST_TURNED_IN] = true,
	[JustQuest.Constants.EVENTS.QUEST_LOG_UPDATE] = true,
	-- Instant state management — must always fire
	[JustQuest.Constants.EVENTS.MODIFIER_STATE_CHANGED] = true,
	[JustQuest.Constants.EVENTS.PLAYER_TARGET_CHANGED] = true,
}
