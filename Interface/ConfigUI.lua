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
                        name = "|cffffcc00What JustQuest Does:|r Automates quest interaction safely.\n\n" ..
                            "• Accepts and turns in quests\n" ..
                            "• Auto-advances gossip to reach quests (Aggressive gossip, on by default)\n" ..
                            "• Stops for real decisions: money/coded options, blacklisted keywords, forced menus\n\n" ..
                            "Use the tabs below to tune behavior.",
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
                        desc = "Master on/off switch.", 
                        order = 1,
                        get = CreateAccessor(nil, "enabled").get,
                        set = CreateAccessor(nil, "enabled").set,
                    },
                    automationToggle = {
                        type = "toggle",
                        name = "Quest & NPC Automation",
                        desc = "Enable/disable quest and gossip automation.", 
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
                        desc = "Uses tighter timing and hides quest/gossip frames while automating.",
                        order = 2.5,
                        get = CreateAccessor(nil, "fastMode").get,
                        set = CreateAccessor(nil, "fastMode").set,
                    },
                    skipCinematics = {
                        type = "toggle",
                        name = "Skip Cinematics",
                        desc = "Skip quest cinematics and movies.",
                        order = 3,
                        get = CreateAccessor(nil, "skipCinematics").get,
                        set = CreateAccessor(nil, "skipCinematics").set,
                    },
                    resetInstanceOnExit = {
                        type = "toggle",
                        name = "Reset Instance On Exit",
                        desc = "When using Quick Exit, automatically reset instances after you leave.\n\nFor 60-second ejection exits, reset waits until you are actually out.",
                        order = 4,
                        get = CreateAccessor("lfgQuickExit", "resetInstanceOnExit").get,
                        set = CreateAccessor("lfgQuickExit", "resetInstanceOnExit").set,
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
                        desc = "Accept escort/follow quests.\n\n|cffff9999Detection unavailable:|r No escort-quest API exists in modern WoW. This toggle is reserved for future use.",
                        order = 1,
                        disabled = true,
                        get = CreateAccessor("quest", "acceptEscort").get,
                        set = CreateAccessor("quest", "acceptEscort").set,
                    },
                    acceptPvP = {
                        type = "toggle", 
                        name = "Accept PvP Quests",
                        desc = "Accept PvP and War Mode quests. |cffff9999Warning:|r May flag you for PvP.",
                        order = 2,
                        get = CreateAccessor("quest", "acceptPvP").get,
                        set = CreateAccessor("quest", "acceptPvP").set,
                    },
                    acceptRepeatable = {
                        type = "toggle",
                        name = "Accept Repeatable Quests",
                        desc = "Accept repeatable quests (daily/weekly/world).",
                        order = 3,
                        get = CreateAccessor("quest", "acceptRepeatable").get,
                        set = CreateAccessor("quest", "acceptRepeatable").set,
                    },
                    acceptTrade = {
                        type = "toggle",
                        name = "Accept Trade Skill Quests", 
                        desc = "Accept profession/trade skill quests.",
                        order = 4,
                        get = CreateAccessor("quest", "acceptTrade").get,
                        set = CreateAccessor("quest", "acceptTrade").set,
                    },
                    acceptTrivial = {
                        type = "toggle",
                        name = "Accept Trivial Quests",
                        desc = "Accept low-level (gray) quests.",
                        order = 5,
                        get = CreateAccessor("quest", "acceptTrivial").get,
                        set = CreateAccessor("quest", "acceptTrivial").set,
                    },
                    acceptAccountCompleted = {
                        type = "toggle",
                        name = "Accept Account-Wide Completed",
                        desc = "Accept quests already completed account-wide (Warband).",
                        order = 6,
                        get = CreateAccessor("quest", "acceptAccountCompleted").get,
                        set = CreateAccessor("quest", "acceptAccountCompleted").set,
                    },
                    acceptQuestItems = {
                        type = "toggle",
                        name = "Accept Item/Proximity Quests",
                        desc = "Accept quests triggered by item use or area proximity.",
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
                        desc = "Auto-pick simple rewards; halt for significant choices.",
                        order = 1,
                        get = CreateAccessor("quest", "autoReward").get,
                        set = CreateAccessor("quest", "autoReward").set,
                    },
                    simpleRewardMode = {
                        type = "toggle",
                        name = "Simple Reward Mode",
                        desc = "Always choose highest vendor value (no collectible/upgrade logic).",
                        order = 2,
                        get = CreateAccessor("quest", "simpleRewardMode").get,
                        set = CreateAccessor("quest", "simpleRewardMode").set,
                        disabled = function()
                            local config = JustQuest.Core.GetModule("Config")
                            return not (config and config.Get("quest", "autoReward"))
                        end,
                    },
                    usePawnScoring = {
                        type = "toggle",
                        name = "Use Pawn for Upgrade Scoring",
                        desc = "When Pawn is installed, use stat-weight scoring to pick the best upgrade.\n" ..
                               "Disable to always compare by item level instead.",
                        order = 3,
                        get = CreateAccessor("quest", "usePawnScoring").get,
                        set = CreateAccessor("quest", "usePawnScoring").set,
                        disabled = function()
                            local config = JustQuest.Core.GetModule("Config")
                            if not (config and config.Get("quest", "autoReward")) then return true end
                            if config.Get("quest", "simpleRewardMode") then return true end
                            return PawnGetItemData == nil  -- grey out if Pawn not installed
                        end,
                    },
                    pawnUseLootSpec = {
                        type = "toggle",
                        name = "Follow Loot Specialization",
                        desc = "Use your Loot Specialization setting (right-click portrait) to choose Pawn scales, " ..
                               "rather than your currently active spec.\n" ..
                               "Useful when queuing as DPS but gearing for tank/healer.",
                        order = 4,
                        get = CreateAccessor("quest", "pawnUseLootSpec").get,
                        set = CreateAccessor("quest", "pawnUseLootSpec").set,
                        disabled = function()
                            local config = JustQuest.Core.GetModule("Config")
                            if not (config and config.Get("quest", "autoReward")) then return true end
                            if config.Get("quest", "simpleRewardMode") then return true end
                            if config.Get("quest", "usePawnScoring") == false then return true end
                            return PawnGetItemData == nil
                        end,
                    },
                    pawnStatus = {
                        type = "description",
                        name = function()
                            if PawnGetItemData == nil then
                                return "|cff808080Pawn is not installed. Upgrade comparison uses item level.|r"
                            end
                            local config = JustQuest.Core.GetModule("Config")
                            if config and config.Get("quest", "usePawnScoring") == false then
                                return "|cffff8800Pawn installed but scoring disabled. Using item level.|r"
                            end
                            local lootSpecID = GetLootSpecialization and GetLootSpecialization() or 0
                            local useLootSpec = not config or config.Get("quest", "pawnUseLootSpec") ~= false
                            local specNote = ""
                            if useLootSpec and lootSpecID and lootSpecID > 0 then
                                local _, lootSpecName = GetSpecializationInfoByID and GetSpecializationInfoByID(lootSpecID)
                                specNote = " (loot spec: " .. (lootSpecName or "?") .. ")"
                            elseif not useLootSpec then
                                local _, specName = GetSpecializationInfo and GetSpecializationInfo(GetSpecialization())
                                specNote = " (active spec: " .. (specName or "?") .. ")"
                            end
                            return "|cff00ff00Pawn active" .. specNote .. ".|r"
                        end,
                        order = 5,
                        fontSize = "small",
                        hidden = function()
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
                        name = "|cffffcc00Blocked Quests:|r Quests in this list are never auto-accepted.\n" ..
                               "Add by quest ID.",
                        order = 1,
                        fontSize = "medium",
                    },
                    addQuest = {
                        type = "input",
                        name = "Add Quest ID",
                        desc = "Add a quest ID to the blocked list.",
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
                        desc = "Remove a quest from the blocked list.",
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
            currencyWhitelist = {
                type = "group",
                name = "Currency Spending Whitelist",
                inline = true,
                order = 5,
                args = {
                    info = {
                        type = "description",
                        name = "|cffffcc00Currency Whitelist:|r Quests here are allowed to auto-spend currencies " ..
                               "without prompting. Use |cff00ff00Always Allow|r in the confirmation popup to add entries.\n" ..
                               "Select a quest below to remove it.",
                        order = 1,
                        fontSize = "medium",
                    },
                    removeEntry = {
                        type = "select",
                        name = "Remove Entry",
                        desc = "Remove a quest from the currency spending whitelist.",
                        values = function()
                            local values = {}
                            local config = JustQuest.Core.GetModule("Config")
                            local whitelist = config and config.GetCurrencyQuestWhitelist and config.GetCurrencyQuestWhitelist() or {}
                            for questID, entry in pairs(whitelist) do
                                local title = (type(entry) == "table" and entry.title) or
                                              (C_QuestLog and C_QuestLog.GetTitleForQuestID(questID)) or
                                              "Quest " .. questID
                                values[questID] = string.format("%s (ID: %d)", title, questID)
                            end
                            return values
                        end,
                        order = 2,
                        get = function() return nil end,
                        set = function(info, value)
                            if value then
                                local config = JustQuest.Core.GetModule("Config")
                                if config and config.RemoveCurrencyQuestWhitelist then
                                    config.RemoveCurrencyQuestWhitelist(value)
                                    if ACR then ACR:NotifyChange("JustQuest") end
                                end
                            end
                        end,
                    },
                    entryList = {
                        type = "description",
                        order = 3,
                        name = function()
                            local config = JustQuest.Core.GetModule("Config")
                            local whitelist = config and config.GetCurrencyQuestWhitelist and config.GetCurrencyQuestWhitelist() or {}
                            local count = 0
                            for _ in pairs(whitelist) do count = count + 1 end

                            if count == 0 then
                                return "|cffaaaaaaNone.|r"
                            end

                            local s = string.format("|cffffcc00Whitelisted quests (%d):|r\n", count)
                            for questID, entry in pairs(whitelist) do
                                local title = (type(entry) == "table" and entry.title) or
                                              (C_QuestLog and C_QuestLog.GetTitleForQuestID(questID)) or
                                              "Quest " .. questID
                                local currencies = (type(entry) == "table" and entry.currencies) or ""
                                if currencies ~= "" then
                                    s = s .. string.format("• %s (ID: %d) — %s\n", title, questID, currencies)
                                else
                                    s = s .. string.format("• %s (ID: %d)\n", title, questID)
                                end
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

            aggressive = {
                type = "toggle",
                name = "Aggressive gossip (auto-advance to quests)",
                desc = "Automatically clicks through gossip to reach quests: takes the first available option in ANY menu, not only quest-flagged or single-service ones.\n\n" ..
                       "Still safe: options that cost money or need a typed code stop for you (the server intercepts them), blacklisted keywords are skipped, and holding Shift/Ctrl/Alt lets you read a menu manually.\n\n" ..
                       "Turn OFF for conservative behavior — only quest-indicated dialog and single Blizzard-service steps are automated; other menus are left for you.",
                width = "full",
                order = 2,
                get = function()
                    local config = JustQuest.Core.GetModule("Config")
                    local v = config and config.Get("gossip", "aggressive")
                    if v == nil then return true end
                    return v
                end,
                set = function(info, value)
                    local config = JustQuest.Core.GetModule("Config")
                    if config then config.Set("gossip", "aggressive", value) end
                end,
            },
            

            
            rules = {
                type = "group",
                name = "NPC Rules (Whitelist & Blacklist)",
                inline = true,
                order = 3,
                args = {
                    rulesInfo = {
                        type = "description",
                        name = "|cffffcc00Whitelist vs Blacklist:|r\n" ..
                               "• |cff00ff00Whitelist:|r Selected immediately (still respects repeat protection).\n" ..
                               "• |cffff0000Blacklist:|r Matching options are skipped; addon picks next safe option.\n\n" ..
                               "|cffffcc00Note:|r With Aggressive gossip on (default), any gossip option is auto-advanced to reach quests, except forced menus and money/coded options. With it off, only quest-indicated dialog and single service steps are automated.\n",
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
                                desc = "Add exact gossip text to whitelist. Tip: enable Debug Mode to capture exact text.",
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
                                desc = "Remove an entry from the whitelist.",
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
                                desc = "Add keyword/phrase blacklist match (substring). Examples: 'teleport', 'skip campaign'.",
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
                                desc = "Remove an entry from the blacklist.",
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
                                desc = "Restore the default blacklist.",
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
                        desc = "Auto-open whitelisted containers.",
                        order = 1,
                        get = CreateAccessor("containers", "enabled").get,
                        set = CreateAccessor("containers", "enabled").set,
                    },
                    throttleDelay = {
                        type = "range",
                        name = "Opening Delay",
                        desc = "Minimum delay between container opens (seconds).",
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
                        desc = "Use the built-in safe-container database as fallback for unlisted items.",
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
                               "• Click an Add box, then |cff00ff00Shift-Click|r a container in your bags\n" ..
                               "• Or enter the item ID manually\n",
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
                                desc = "Add an item ID to whitelist (or Shift-Click a bag item).",
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
                                desc = "Remove an item from whitelist.",
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
                                desc = "Add an item ID to blacklist (or Shift-Click a bag item).",
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
                                desc = "Remove an item from blacklist.",
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
                name = "|cffffcc00Advanced settings.|r Tune only if needed.\n",
                order = 2,
                fontSize = "medium",
            },
            debugMode = {
                type = "toggle",
                name = "Debug Mode", 
                desc = "Show debug messages in chat.",
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
                               "• Automates only quest-indicated dialog (quest flags or server-colored text)\n" ..
                               "• Plain gossip with no quest indicators is never automated\n" ..
                               "• Single service options (vendor, trainer) auto-selected for convenience\n" ..
                               "• Multiple service options halt for manual selection\n" ..
                               "• Blacklist skips dangerous keywords (teleports, story skips, etc.)\n" ..
                               "• Warning colors (red/orange) halt automation\n" ..
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
                        desc = "Global delay multiplier. 0.75 = faster, 1.0 = normal, 2.0 = slower.",
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
                        desc = "Max number of chained gossip selections before halt.",
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
-- Registration
-- ============================================================

-- Register the options table and add it to the Blizzard AddOns settings list.
-- Idempotent (guarded by uiCache); called at startup so JustQuest always shows
-- in the AddOns panel, and again from ShowConfig as a safety net.
local function EnsureRegistered()
    if not uiCache.registered and ACR then
        ACR:RegisterOptionsTable("JustQuest", BuildOptionsTable())
        uiCache.registered = true
    end

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
end

-- ============================================================
-- Public API
-- ============================================================

function ConfigUI.ShowConfig()
    EnsureRegistered()

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
    -- Register at load so JustQuest appears in the Blizzard AddOns settings list
    -- immediately, instead of only after the first /jq.
    EnsureRegistered()
end

-- ============================================================
-- Module Registration
-- ============================================================

JustQuest.Core.RegisterModule("ConfigUI", ConfigUI, {"Config"})

return ConfigUI
