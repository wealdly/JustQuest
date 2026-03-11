-- ConfigUI.lua
-- Configuration interface with AceConfig integration

local ADDON_NAME, JustQuest = ...

local ConfigUI = {}

-- ============================================================
-- AceConfig Integration
-- ============================================================

local ACR = LibStub and LibStub("AceConfigRegistry-3.0", true)
local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)

-- Cache for UI state
local uiCache = {
    registered = false,
    addedToBlizz = false,
    blizzFrames = {}
}

-- ============================================================
-- Helper Functions
-- ============================================================

local function CreateAccessor(module, key)
    local config = JustQuest.Core.GetModule("Config")
    if config and config.CreateAccessor then
        return config.CreateAccessor(module, key)
    end
    
    -- Fallback accessor
    return {
        get = function() 
            return config and config.Get(module, key) 
        end,
        set = function(info, value) 
            if config then
                config.Set(module, key, value) 
            end
        end
    }
end

-- ============================================================
-- Option Builders
-- ============================================================

local function CreateGeneralOptions()
    return {
        type = "group",
        name = "General",
        order = 1,
        args = {
            header = {
                type = "header",
                name = "JustQuest - Intelligent Quest & NPC Automation",
                order = 1,
            },
            summary = {
                type = "group",
                name = "What JustQuest Does",
                inline = true,
                order = 2,
                args = {
                    description = {
                        type = "description",
                        name = "|cffffcc00What JustQuest Does:|r Automates quest interactions with safety rules.\n\n" ..
                             "• Quest handling: accept, turn-in, and reward selection.\n" ..
                             "• Quest dialog: auto-selects quest-flagged and blue-text dialog options.\n" ..
                             "• Services: opens single vendor/trainer/banker dialogs for convenience.\n" ..
                             "• Multiple quests: handles NPCs with multiple quests automatically.\n" ..
                             "• Non-quest gossip is skipped (no quest flag, no colored text = no automation).\n\n" ..
                             "Use the sections below to customize behavior.",
                        order = 1,
                        fontSize = "medium",
                    },
                }
            },
            coreSettings = {
                type = "group",
                name = "Main Controls",
                inline = true,
                order = 3,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "Enable JustQuest",
                        desc = "Enable or disable the entire addon", 
                        order = 1,
                        get = CreateAccessor(nil, "enabled").get,
                        set = CreateAccessor(nil, "enabled").set,
                    },
                    automationToggle = {
                        type = "toggle",
                        name = "Quest & NPC Automation",
                        desc = "Enable/disable quest and gossip automation (both work together for best results)", 
                        order = 2,
                        get = function() 
                            local config = JustQuest.Core.GetModule("Config")
                            return config and config.Get("quest", "enabled") and config.Get("gossip", "enabled")
                        end,
                        set = function(info, value) 
                            local config = JustQuest.Core.GetModule("Config")
                            if config then
                                config.Set("quest", "enabled", value)
                                config.Set("gossip", "enabled", value)
                            end
                        end,
                    },
                    fastMode = {
                        type = "toggle",
                        name = "Fast Mode",
                        desc = "Tighter timing and hide quest/gossip frames during automation.\n\nFrames only appear when automation halts for manual interaction.",
                        order = 2.5,
                        get = CreateAccessor(nil, "fastMode").get,
                        set = CreateAccessor(nil, "fastMode").set,
                    },
                    skipCinematics = {
                        type = "toggle",
                        name = "Skip Cinematics",
                        desc = "Automatically skip quest cinematics, cutscenes, and movies",
                        order = 3,
                        get = CreateAccessor(nil, "skipCinematics").get,
                        set = CreateAccessor(nil, "skipCinematics").set,
                    },
                }
            },
        }
    }
end

local function CreateQuestOptions()
    return {
        type = "group", 
        name = "Quests",
        order = 2,
        args = {
            header = {
                type = "header",
                name = "Quest Automation",
                order = 1,
            },
            questTypes = {
                type = "group",
                name = "Quest Types",
                inline = true,
                order = 2,
                args = {
                    acceptEscort = {
                        type = "toggle",
                        name = "Accept Escort Quests",
                        desc = "Automatically accept escort/follow quests.\n\n|cffff9999Warning:|r These may take you through dangerous areas.",
                        order = 1,
                        get = CreateAccessor("quest", "acceptEscort").get,
                        set = CreateAccessor("quest", "acceptEscort").set,
                    },
                    acceptPvP = {
                        type = "toggle", 
                        name = "Accept PvP Quests",
                        desc = "Automatically accept PvP and War Mode related quests.\n\n|cffff9999Warning:|r May flag you for PvP.",
                        order = 2,
                        get = CreateAccessor("quest", "acceptPvP").get,
                        set = CreateAccessor("quest", "acceptPvP").set,
                    },
                    acceptRepeatable = {
                        type = "toggle",
                        name = "Accept Repeatable Quests",
                        desc = "Automatically accept repeatable/daily quests",
                        order = 3,
                        get = CreateAccessor("quest", "acceptRepeatable").get,
                        set = CreateAccessor("quest", "acceptRepeatable").set,
                    },
                    acceptTrade = {
                        type = "toggle",
                        name = "Accept Trade Skill Quests", 
                        desc = "Automatically accept tradeskill quests",
                        order = 4,
                        get = CreateAccessor("quest", "acceptTrade").get,
                        set = CreateAccessor("quest", "acceptTrade").set,
                    },
                    acceptTrivial = {
                        type = "toggle",
                        name = "Accept Trivial Quests",
                        desc = "Accept trivial (grey/low-level) quests.\n\nUseful for Chromie Time, Party Sync, or completing old content.",
                        order = 5,
                        get = CreateAccessor("quest", "acceptTrivial").get,
                        set = CreateAccessor("quest", "acceptTrivial").set,
                    },
                    acceptAccountCompleted = {
                        type = "toggle",
                        name = "Accept Account-Wide Completed",
                        desc = "Accept quests already completed account-wide (Warband feature).\n\nDisable to skip quests done on other characters.",
                        order = 6,
                        get = CreateAccessor("quest", "acceptAccountCompleted").get,
                        set = CreateAccessor("quest", "acceptAccountCompleted").set,
                    },
                    acceptQuestItems = {
                        type = "toggle",
                        name = "Accept Item/Proximity Quests",
                        desc = "Automatically accept quests triggered by item use or area proximity (QuestIsFromAreaTrigger).\n\nDisable if you want to review item-started quests manually.",
                        order = 7,
                        get = CreateAccessor("quest", "acceptQuestItems").get,
                        set = CreateAccessor("quest", "acceptQuestItems").set,
                    },
                }
            },
            rewards = {
                type = "group", 
                name = "Reward Selection",
                inline = true,
                order = 3,
                args = {
                    autoReward = {
                        type = "toggle",
                        name = "Auto-Select Rewards",
                        desc = "Pick the most valuable reward automatically for simple cases; halts for potentially valuable choices.",
                        order = 1,
                        get = CreateAccessor("quest", "autoReward").get,
                        set = CreateAccessor("quest", "autoReward").set,
                    },
                    simpleRewardMode = {
                        type = "toggle",
                        name = "Simple Reward Mode",
                        desc = "Use fast vendor-value selection instead of smart analysis (faster but ignores collectibles/upgrades).",
                        order = 2,
                        get = CreateAccessor("quest", "simpleRewardMode").get,
                        set = CreateAccessor("quest", "simpleRewardMode").set,
                        disabled = function()
                            local config = JustQuest.Core.GetModule("Config")
                            return not (config and config.Get("quest", "autoReward"))
                        end,
                    },
                }
            },
            blockedQuests = {
                type = "group",
                name = "Blocked Quests",
                inline = true,
                order = 4,
                args = {
                    info = {
                        type = "description",
                        name = "|cffffcc00Blocked Quests:|r Prevent specific quests from being auto-accepted.\n" ..
                               "Enter the Quest ID (found in quest URLs or with /questid command).",
                        order = 1,
                        fontSize = "medium",
                    },
                    addQuest = {
                        type = "input",
                        name = "Add Quest ID",
                        desc = "Enter a Quest ID to block from auto-acceptance",
                        width = "full",
                        order = 2,
                        get = function() return "" end,
                        set = function(info, value)
                            local questID = tonumber(value)
                            if questID then
                                local config = JustQuest.Core.GetModule("Config")
                                if config and config.AddQuestBlacklist then
                                    config.AddQuestBlacklist(questID)
                                    if ACR then ACR:NotifyChange("JustQuest") end
                                end
                            end
                        end,
                    },
                    removeQuest = {
                        type = "select",
                        name = "Remove Quest",
                        desc = "Select a quest to remove from blocked list",
                        values = function()
                            local values = {}
                            local config = JustQuest.Core.GetModule("Config")
                            local blocked = config and config.GetQuestBlacklist() or {}
                            for questID, _ in pairs(blocked) do
                                local questTitle = C_QuestLog and C_QuestLog.GetTitleForQuestID(questID) or "Unknown"
                                values[questID] = string.format("%s (ID: %d)", questTitle, questID)
                            end
                            return values
                        end,
                        order = 3,
                        get = function() return nil end,
                        set = function(info, value)
                            if value then
                                local config = JustQuest.Core.GetModule("Config")
                                if config and config.RemoveQuestBlacklist then
                                    config.RemoveQuestBlacklist(value)
                                    if ACR then ACR:NotifyChange("JustQuest") end
                                end
                            end
                        end,
                    },
                    questList = {
                        type = "description",
                        order = 4,
                        name = function()
                            local config = JustQuest.Core.GetModule("Config")
                            local blocked = config and config.GetQuestBlacklist() or {}
                            local count = 0
                            for _ in pairs(blocked) do count = count + 1 end
                            
                            if count == 0 then
                                return "|cffaaaaaaNone.|r"
                            end
                            
                            local s = string.format("|cffffcc00Blocked quests (%d):|r\n", count)
                            for questID, _ in pairs(blocked) do
                                local questTitle = C_QuestLog and C_QuestLog.GetTitleForQuestID(questID) or "Unknown"
                                s = s .. string.format("• %s (ID: %d)\n", questTitle, questID)
                            end
                            return s
                        end,
                    },
                },
            },
        }
    }
end

local function CreateGossipOptions()
    return {
        type = "group",
        name = "NPCs",
        order = 3,
        args = {
            header = { type = "header", name = "NPC Interactions", order = 1 },
            

            
            rules = {
                type = "group",
                name = "NPC Rules (Whitelist & Blacklist)",
                inline = true,
                order = 2,
                args = {
                    rulesInfo = {
                        type = "description",
                        name = "|cffffcc00Whitelist vs Blacklist:|r\n" ..
                               "• |cff00ff00Whitelist:|r Trusted options that bypass ALL safety checks and are selected immediately (except repeat protection).\n" ..
                               "• |cffff0000Blacklist:|r Dangerous keywords — matching options are skipped and the next safe option is selected instead. Automation only halts if ALL options are unsafe.\n\n" ..
                               "|cffffcc00Note:|r Only quest-indicated dialog (quest-flagged or blue/colored text) is automated. Plain gossip with no quest indicators is always skipped.\n",
                        order = 1, 
                        fontSize = "medium",
                    },

                    wlGroup = {
                        type = "group", 
                        name = "Trusted Options (Whitelist)", 
                        inline = true, 
                        order = 2,
                        args = {
                            wlAdd = {
                                type = "input", 
                                name = "Add Trusted Text",
                                desc = "Enter exact gossip text to whitelist. Will be auto-selected immediately, bypassing all safety checks.\nTip: enable Debug Mode to see exact text.",
                                width = "full", 
                                order = 1,
                                get = function() return "" end,
                                set = function(info, value)
                                    if value and value:trim() ~= "" then
                                        local config = JustQuest.Core.GetModule("Config")
                                        if config and config.AddGossipWhitelist then
                                            config.AddGossipWhitelist(value:trim())
                                            if ACR then ACR:NotifyChange("JustQuest") end
                                        end
                                    end
                                end,
                            },
                            
                            wlRemove = {
                                type = "select", 
                                name = "Remove Trusted Text",
                                desc = "Select an item to remove from whitelist",
                                values = function()
                                    local values = {}
                                    local config = JustQuest.Core.GetModule("Config")
                                    local wl = config and config.Get("gossip", "whitelist") or {}
                                    for i = 1, #wl do
                                        values[wl[i]] = wl[i]
                                    end
                                    return values
                                end,
                                order = 2,
                                get = function() return nil end,
                                set = function(info, value)
                                    if value then
                                        local config = JustQuest.Core.GetModule("Config")
                                        if config and config.RemoveGossipWhitelist then
                                            config.RemoveGossipWhitelist(value)
                                            if ACR then ACR:NotifyChange("JustQuest") end
                                        end
                                    end
                                end,
                            },
                            
                            wlList = {
                                type = "description", 
                                order = 3,
                                name = function()
                                    local config = JustQuest.Core.GetModule("Config")
                                    local wl = config and config.Get("gossip", "whitelist") or {}
                                    if #wl == 0 then
                                        return "|cffaaaaaaNone.|r"
                                    end
                                    local s = "|cffffcc00Current whitelist:|r\n"
                                    for i = 1, #wl do 
                                        s = s .. "• " .. wl[i] .. "\n" 
                                    end
                                    return s
                                end,
                            },
                        },
                    },

                    blGroup = {
                        type = "group", 
                        name = "Dangerous Keywords (Blacklist)", 
                        inline = true, 
                        order = 3,
                        args = {
                            blAdd = {
                                type = "input", 
                                name = "Add Dangerous Keyword",
                                desc = "Enter keyword/phrase to blacklist (substring match). Matching options are skipped; automation halts only if ALL options are unsafe.\nExamples: 'teleport', 'skip campaign', 'Stay awhile'.",
                                width = "full", 
                                order = 1,
                                get = function() return "" end,
                                set = function(info, value)
                                    if value and value:trim() ~= "" then
                                        local config = JustQuest.Core.GetModule("Config")
                                        if config and config.AddGossipBlacklist then
                                            config.AddGossipBlacklist(value:trim())
                                            if ACR then ACR:NotifyChange("JustQuest") end
                                        end
                                    end
                                end,
                            },
                            
                            blRemove = {
                                type = "select", 
                                name = "Remove Keyword",
                                desc = "Select an item to remove from blacklist",
                                values = function()
                                    local values = {}
                                    local config = JustQuest.Core.GetModule("Config")
                                    local bl = config and config.Get("gossip", "blacklist") or {}
                                    for i = 1, #bl do
                                        values[bl[i]] = bl[i]
                                    end
                                    return values
                                end,
                                order = 2,
                                get = function() return nil end,
                                set = function(info, value)
                                    if value then
                                        local config = JustQuest.Core.GetModule("Config")
                                        if config and config.RemoveGossipBlacklist then
                                            config.RemoveGossipBlacklist(value)
                                            if ACR then ACR:NotifyChange("JustQuest") end
                                        end
                                    end
                                end,
                            },
                            
                            blList = {
                                type = "description", 
                                order = 3,
                                name = function()
                                    local config = JustQuest.Core.GetModule("Config")
                                    local bl = config and config.Get("gossip", "blacklist") or {}
                                    if #bl == 0 then
                                        return "|cffaaaaaaNone.|r"
                                    end
                                    local s = "|cffffcc00Current blacklist:|r\n"
                                    for i = 1, #bl do 
                                        s = s .. "• " .. bl[i] .. "\n" 
                                    end
                                    return s
                                end,
                            },
                            
                            blDefaults = {
                                type = "execute", 
                                name = "Reset Blacklist to Safe Defaults",
                                desc = "Restore the shipped blacklist (teleports, story skips, etc.).",
                                order = 4,
                                func = function()
                                    local defaults = JustQuest.Constants and JustQuest.Constants.DEFAULTS
                                    local defaultBL = defaults and defaults.profile and defaults.profile.gossip and defaults.profile.gossip.blacklist or {}
                                    local config = JustQuest.Core.GetModule("Config")
                                    if config then
                                        config.Set("gossip", "blacklist", defaultBL)
                                        if ACR then ACR:NotifyChange("JustQuest") end
                                    end
                                end,
                            },
                        },
                    },
                },
            },
        },
    }
end

local function CreateContainerOptions()
    return {
        type = "group",
        name = "Containers",
        order = 4,
        args = {
            header = {
                type = "header",
                name = "Container Auto-Opening",
                order = 1,
            },
            
            settings = {
                type = "group",
                name = "Settings",
                inline = true,
                order = 2,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "Enable",
                        desc = "Automatically open whitelisted containers",
                        order = 1,
                        get = CreateAccessor("containers", "enabled").get,
                        set = CreateAccessor("containers", "enabled").set,
                    },
                    throttleDelay = {
                        type = "range",
                        name = "Opening Delay",
                        desc = "Minimum delay between opening containers (seconds)",
                        min = 0.1,
                        max = 2.0,
                        step = 0.1,
                        order = 2,
                        get = CreateAccessor("containers", "throttleDelay").get,
                        set = CreateAccessor("containers", "throttleDelay").set,
                    },
                    useDatabaseFallback = {
                        type = "toggle",
                        name = "Use Built-In Database (Optional)",
                        desc = "Enable a pre-populated database of ~1000 safe containers as a fallback.\n\n" ..
                               "Disabled by default. When enabled, unlisted containers check the database.\n" ..
                               "You can still customize your whitelist/blacklist with this enabled.",
                        order = 3,
                        get = CreateAccessor("containers", "useDatabaseFallback").get,
                        set = CreateAccessor("containers", "useDatabaseFallback").set,
                    },
                }
            },
            
            lists = {
                type = "group",
                name = "Your Container Lists",
                inline = true,
                order = 3,
                args = {
                    listsInfo = {
                        type = "description",
                        name = "|cffffcc00How to add containers:|r\n" ..
                               "• Click 'Add Item ID' box below, then |cff00ff00Shift-Click|r a container in your bags.\n" ..
                               "• Or manually enter an Item ID.\n",
                        order = 1,
                        fontSize = "medium",
                    },
                    
                    wlGroup = {
                        type = "group",
                        name = "Whitelist (Auto-Opens)",
                        inline = true,
                        order = 2,
                        args = {
                            wlAdd = {
                                type = "input",
                                name = "Add Item ID (or Shift-Click item)",
                                desc = "Enter Item ID to whitelist, or Shift-Click a container in your bags to insert its link",
                                width = "full",
                                order = 1,
                                get = function() return "" end,
                                set = function(info, value)
                    -- Try to extract item ID from item link first (format: |cffffffff|Hitem:12345:...|h[Name]|h|r)
                    local itemID = tonumber(value:match("item:(%d+)"))
                    
                    -- If not a link, try to parse as direct number
                    if not itemID then
                        itemID = tonumber(value)
                    end
                    
                    if itemID then
                        local config = JustQuest.Core.GetModule("Config")
                        if config and config.AddContainerWhitelist then
                            local itemName = C_Item and C_Item.GetItemNameByID(itemID) or nil
                            config.AddContainerWhitelist(itemID, itemName)
                            if ACR then ACR:NotifyChange("JustQuest") end
                        end
                    else
                        print("|cff00ccffJustQuest:|r |cffff0000Invalid input - enter Item ID or Shift-Click a container|r")
                    end
                end,
                            },
                            
                            wlRemove = {
                                type = "select",
                                name = "Remove Item",
                                desc = "Select an item to remove from whitelist",
                                order = 2,
                                values = function()
                                    local values = {}
                                    local config = JustQuest.Core.GetModule("Config")
                                    local wl = config and config.Get("containers", "whitelist") or {}
                                    for itemID, itemName in pairs(wl) do
                                        local displayName = type(itemName) == "string" and itemName or tostring(itemID)
                                        values[itemID] = string.format("%s (ID: %d)", displayName, itemID)
                                    end
                                    return values
                                end,
                                get = function() return nil end,
                                set = function(info, value)
                                    if value then
                                        local config = JustQuest.Core.GetModule("Config")
                                        if config and config.RemoveContainerWhitelist then
                                            config.RemoveContainerWhitelist(value)
                                            if ACR then ACR:NotifyChange("JustQuest") end
                                        end
                                    end
                                end,
                            },
                            
                            wlList = {
                                type = "description",
                                order = 3,
                                name = function()
                                    local config = JustQuest.Core.GetModule("Config")
                                    local wl = config and config.Get("containers", "whitelist") or {}
                                    local count = 0
                                    for _ in pairs(wl) do count = count + 1 end
                                    
                                    if count == 0 then
                                        return "|cffaaaaaaNone.|r"
                                    end
                                    
                                    local s = string.format("|cffffcc00Current whitelist (%d):|r\n", count)
                                    for itemID, itemName in pairs(wl) do
                                        local displayName = type(itemName) == "string" and itemName or "Unknown"
                                        s = s .. string.format("• %s (ID: %d)\n", displayName, itemID)
                                    end
                                    return s
                                end,
                            },
                        },
                    },
                    
                    blGroup = {
                        type = "group",
                        name = "Blacklist (Never Opens)",
                        inline = true,
                        order = 3,
                        args = {
                            blAdd = {
                                type = "input",
                                name = "Add Item ID (or Shift-Click item)",
                                desc = "Enter Item ID to blacklist, or Shift-Click a container in your bags to insert its link",
                                width = "full",
                                order = 1,
                                get = function() return "" end,
                                set = function(info, value)
                                    -- Try to extract item ID from item link first (format: |cffffffff|Hitem:12345:...|h[Name]|h|r)
                                    local itemID = tonumber(value:match("item:(%d+)"))
                                    
                                    -- If not a link, try to parse as direct number
                                    if not itemID then
                                        itemID = tonumber(value)
                                    end
                                    
                                    if itemID then
                                        local config = JustQuest.Core.GetModule("Config")
                                        if config and config.AddContainerBlacklist then
                                            local itemName = C_Item and C_Item.GetItemNameByID(itemID) or nil
                                            config.AddContainerBlacklist(itemID, itemName)
                                            if ACR then ACR:NotifyChange("JustQuest") end
                                        end
                                    else
                                        print("|cff00ccffJustQuest:|r |cffff0000Invalid input - enter Item ID or Shift-Click a container|r")
                                    end
                                end,
                            },
                            
                            blRemove = {
                                type = "select",
                                name = "Remove Item",
                                desc = "Select an item to remove from blacklist",
                                order = 2,
                                values = function()
                                    local values = {}
                                    local config = JustQuest.Core.GetModule("Config")
                                    local bl = config and config.Get("containers", "blacklist") or {}
                                    for itemID, itemName in pairs(bl) do
                                        local displayName = type(itemName) == "string" and itemName or tostring(itemID)
                                        values[itemID] = string.format("%s (ID: %d)", displayName, itemID)
                                    end
                                    return values
                                end,
                                get = function() return nil end,
                                set = function(info, value)
                                    if value then
                                        local config = JustQuest.Core.GetModule("Config")
                                        if config and config.RemoveContainerBlacklist then
                                            config.RemoveContainerBlacklist(value)
                                            if ACR then ACR:NotifyChange("JustQuest") end
                                        end
                                    end
                                end,
                            },
                            
                            blList = {
                                type = "description",
                                order = 3,
                                name = function()
                                    local config = JustQuest.Core.GetModule("Config")
                                    local bl = config and config.Get("containers", "blacklist") or {}
                                    local count = 0
                                    for _ in pairs(bl) do count = count + 1 end
                                    
                                    if count == 0 then
                                        return "|cffaaaaaaNone.|r"
                                    end
                                    
                                    local s = string.format("|cffffcc00Current blacklist (%d):|r\n", count)
                                    for itemID, itemName in pairs(bl) do
                                        local displayName = type(itemName) == "string" and itemName or "Unknown"
                                        s = s .. string.format("• %s (ID: %d)\n", displayName, itemID)
                                    end
                                    return s
                                end,
                            },
                        },
                    },
                },
            },
        }
    }
end

local function CreateAdvancedOptions()
    return {
        type = "group",
        name = "Advanced",
        order = 5,  -- After Containers, before Profiles
        args = {
            header = {
                type = "header", 
                name = "Advanced Configuration",
                order = 1,
            },
            warning = {
                type = "description",
                name = "|cffffcc00Internal settings for power users.|r\n\n" ..
                       "|cffff6666Warning:|r Change only if you know what you're doing.\n",
                order = 2,
                fontSize = "medium",
            },
            debugMode = {
                type = "toggle",
                name = "Debug Mode", 
                desc = "Show debug messages in chat (for troubleshooting)",
                order = 3,
                get = CreateAccessor(nil, "debugMode").get,
                set = CreateAccessor(nil, "debugMode").set,
            },
            safetyInfo = {
                type = "group",
                name = "Safety Features (Always Active)",
                inline = true,
                order = 3.5,
                args = {
                    safetyDesc = {
                        type = "description",
                        name = "|cff88ff88Built-in protections:|r\n\n" ..
                               "• Only automates quest-indicated dialog (quest flags, blue text)\n" ..
                               "• Plain gossip with no quest indicators is never automated\n" ..
                               "• Single service options (vendor, trainer) auto-selected for convenience\n" ..
                               "• Multiple service options halt for manual selection\n" ..
                               "• Blacklist catches teleports, portals, story skips by keyword\n" ..
                               "• Detects warning colors (red/orange) in NPC text\n" ..
                               "• Multiple server-colored options halt for manual choice\n" ..
                               "• Prevents infinite gossip loops (repeat protection)\n" ..
                               "• Blocks all StaticPopup dialogs (delves, dungeons, confirmations)\n" ..
                               "• Pauses when modifier key is held\n",
                        order = 1,
                        fontSize = "medium",
                    },
                }
            },
            timingGroup = {
                type = "group",
                name = "Timing Settings",
                inline = true,
                order = 4,
                args = {
                    timingMultiplier = {
                        type = "range",
                        name = "Timing Multiplier",
                        desc = "Global speed control for all delays\n0.75 = Fast (low latency)\n1.0 = Normal (recommended)\n2.0 = Conservative (high latency)",
                        min = 0.75,
                        max = 2.0,
                        step = 0.05,
                        order = 1,
                        get = CreateAccessor("advanced", "timingMultiplier").get,
                        set = CreateAccessor("advanced", "timingMultiplier").set,
                    },
                    chainDepth = {
                        type = "range",
                        name = "Maximum Chain Depth",
                        desc = "Maximum gossip chain depth to follow",
                        min = 1, 
                        max = 15, 
                        step = 1,
                        order = 2,
                        get = CreateAccessor("advanced", "chainDepth").get,
                        set = CreateAccessor("advanced", "chainDepth").set,
                    },
                }
            }
        }
    }
end

-- ============================================================
-- Main UI Builder
-- ============================================================

local function BuildOptionsTable()
    local options = {
        type = "group",
        name = "JustQuest",
        args = {
            general = CreateGeneralOptions(),
            quests = CreateQuestOptions(), 
            gossip = CreateGossipOptions(),
            containers = CreateContainerOptions(),
            advanced = CreateAdvancedOptions(),
        },
    }
    
    -- Add profiles if AceDB is available
    local config = JustQuest.Core.GetModule("Config")
    local db = config and config.GetDatabase()
    if db and LibStub then
        local AceDBOptions = LibStub("AceDBOptions-3.0", true)
        if AceDBOptions then
            local profiles = AceDBOptions:GetOptionsTable(db)
            profiles.order = 99
            options.args.profiles = profiles
        end
    end
    
    return options
end

-- ============================================================
-- Public API
-- ============================================================

function ConfigUI.ShowConfig()
    -- Register if needed
    if not uiCache.registered and ACR then
        local options = BuildOptionsTable()
        ACR:RegisterOptionsTable("JustQuest", options)
        uiCache.registered = true
    end
    
    -- Add to Blizzard options if needed
    if not uiCache.addedToBlizz and ACD and uiCache.registered then
        uiCache.blizzFrames["JustQuest"] = ACD:AddToBlizOptions("JustQuest", "JustQuest")
        uiCache.blizzFrames["JustQuest-General"] = ACD:AddToBlizOptions("JustQuest", "General", "JustQuest", "general")
        uiCache.blizzFrames["JustQuest-Quests"] = ACD:AddToBlizOptions("JustQuest", "Quests", "JustQuest", "quests")
        uiCache.blizzFrames["JustQuest-Gossip"] = ACD:AddToBlizOptions("JustQuest", "NPCs", "JustQuest", "gossip")
        uiCache.blizzFrames["JustQuest-Containers"] = ACD:AddToBlizOptions("JustQuest", "Containers", "JustQuest", "containers")
        uiCache.blizzFrames["JustQuest-Advanced"] = ACD:AddToBlizOptions("JustQuest", "Advanced", "JustQuest", "advanced")
        
        -- Add profiles panel if available
        local config = JustQuest.Core.GetModule("Config")
        local db = config and config.GetDatabase()
        if db and LibStub and LibStub("AceDBOptions-3.0", true) then
            uiCache.blizzFrames["JustQuest-Profiles"] = ACD:AddToBlizOptions("JustQuest", "Profiles", "JustQuest", "profiles")
        end
        
        uiCache.addedToBlizz = true
    end
    
    -- Open the panel
    local rootFrame = uiCache.blizzFrames["JustQuest"]
    
    if Settings and Settings.OpenToCategory and rootFrame and rootFrame.categoryID then
        Settings.OpenToCategory(rootFrame.categoryID)
    elseif _G["InterfaceOptionsFrame_OpenToCategory"] and rootFrame then
        local openFunc = _G["InterfaceOptionsFrame_OpenToCategory"]
        openFunc(rootFrame)
        openFunc(rootFrame) -- Sometimes needs to be called twice
    elseif ACD then
        ACD:Open("JustQuest")
    else
        local services = JustQuest.Core.GetModule("Services")
        if services then
            services.Debug("ConfigUI", "Could not open options UI - use /jq help")
        end
    end
end

-- ============================================================
-- Module API
-- ============================================================

function ConfigUI.Initialize()
    -- Module initialization - no debug output needed (Core handles success/failure reporting)
end

-- ============================================================
-- Module Registration
-- ============================================================

JustQuest.Core.RegisterModule("ConfigUI", ConfigUI, {"Config"})

return ConfigUI
