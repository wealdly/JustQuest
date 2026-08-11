-- ConfigUI.lua
-- Configuration interface with AceConfig integration

local ADDON_NAME, JustQuest = ...

local ConfigUI = {}

-- ============================================================
-- AceConfig Integration
-- ============================================================

local ACR = LibStub and LibStub("AceConfigRegistry-3.0", true)
local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)

-- Shared palette (Core/Constants.lua) — one color per role across the whole panel.
local COLORS = JustQuest.Constants.COLORS
local EM, GOOD, WARN, DANGER, MUTED =
    COLORS.EMPHASIS, COLORS.GOOD, COLORS.WARNING, COLORS.DANGER, COLORS.MUTED

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

-- Grey out Gear Advisor widgets unless the advisor is enabled (shared by all of them).
local function advisorDisabled()
    local c = JustQuest.Core.GetModule("Config")
    return not (c and c.Get("gearSwap", "advisorEnabled"))
end

-- ============================================================
-- Option Builders
-- ============================================================

-- Root landing panel: what the addon does plus the master switches. Everything
-- else lives in the category panels, so nothing renders twice.
local function CreateLandingOptions()
    local version = C_AddOns and C_AddOns.GetAddOnMetadata
        and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
    return {
        type = "group",
        name = "JustQuest",
        args = {
            intro = {
                type = "description",
                order = 1,
                fontSize = "medium",
                name = "Automates quest interaction safely.\n\n" ..
                    "• Accepts and turns in quests\n" ..
                    "• Advances gossip to reach quests (Aggressive Gossip, on by default)\n" ..
                    "• Stops for real decisions: money or coded options, blacklisted keywords, forced menus\n\n" ..
                    "Each JustQuest category in the AddOns list covers one area of automation.",
            },
            coreSettings = {
                type = "group",
                name = "Main Controls",
                inline = true,
                order = 2,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "Enable JustQuest",
                        desc = "Master on/off switch.",
                        width = "full",
                        order = 1,
                        get = CreateAccessor(nil, "enabled").get,
                        set = CreateAccessor(nil, "enabled").set,
                    },
                    automationToggle = {
                        type = "toggle",
                        name = "Quest & NPC Automation",
                        desc = "Enable/disable quest and gossip automation.",
                        width = "full",
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
                        width = "full",
                        order = 3,
                        get = CreateAccessor(nil, "fastMode").get,
                        set = CreateAccessor(nil, "fastMode").set,
                    },
                    skipCinematics = {
                        type = "toggle",
                        name = "Skip Cinematics",
                        desc = "Skip quest cinematics and movies.",
                        width = "full",
                        order = 4,
                        get = CreateAccessor(nil, "skipCinematics").get,
                        set = CreateAccessor(nil, "skipCinematics").set,
                    },
                    automationSummary = {
                        type = "toggle",
                        name = "Summarize in Chat",
                        desc = "Print a concise chat line at the end of each automation chain (e.g. \"accepted 2, turned in 1, opened 1 container\").",
                        width = "full",
                        order = 5,
                        get = CreateAccessor(nil, "automationSummary").get,
                        set = CreateAccessor(nil, "automationSummary").set,
                    },
                }
            },
            versionText = version and {
                type = "description",
                order = 3,
                fontSize = "small",
                name = MUTED .. "JustQuest " .. version .. "|r",
            } or nil,
        }
    }
end

-- Grey out the delve widgets that hang off a toggle that's currently off.
local function delveNoPower()
    local c = JustQuest.Core.GetModule("Config")
    return not (c and c.Get("delve", "autoAcceptPower"))
end

local function torghastNoPower()
    local c = JustQuest.Core.GetModule("Config")
    return not (c and c.Get("torghast", "autoSelectPower"))
end

local function delveNoTier()
    local c = JustQuest.Core.GetModule("Config")
    return not (c and c.Get("delve", "autoTier"))
end

-- Instance-content automation. Delves and Torghast sit together because they are the same
-- kind of exception: content where a repeated pop-up has a knowable answer, so you can opt
-- into having it answered. Everything here is off until you turn it on.
local function CreateInstanceOptions()
    return {
        type = "group",
        name = "Instances",
        order = 4,
        args = {
            intro = {
                type = "description",
                order = 1,
                fontSize = "medium",
                name = "Automation for instanced content, where a pop-up choice can be worth answering for you.\n\n" ..
                       "Everywhere else in JustQuest a choice is always left to you. These are the exceptions you can opt into — and they stay off until you do.\n\n" ..
                       WARN .. "Anything the game asks you to confirm, and any choice it marks as requiring a selection, is still always handed back.|r",
            },

            quickExit = {
                type = "group",
                name = "Quick Exit",
                inline = true,
                order = 1.5,
                args = {
                    resetInstanceOnExit = {
                        type = "toggle",
                        name = "Reset Instance on Exit",
                        desc = "When using Quick Exit, automatically reset instances after you leave.\n\nFor 60-second ejection exits, reset waits until you are actually out.",
                        width = "full",
                        order = 1,
                        get = CreateAccessor("lfgQuickExit", "resetInstanceOnExit").get,
                        set = CreateAccessor("lfgQuickExit", "resetInstanceOnExit").set,
                    },
                },
            },

            delves = {
                type = "group",
                name = "Delves",
                order = 2,
                args = {
                    intro = {
                        type = "description",
                        order = 1,
                        fontSize = "medium",
                        name = "A delve power is offered one at a time, it's always worth taking, and there's nothing to decide — so it can be answered without weighing anything.\n\n" ..
                               WARN .. "The difficulty picker is otherwise left alone entirely: JustQuest never touches a tier unless you turn on Auto-Select Tier below.|r",
                    },

                    powers = {
                        type = "group",
                        name = "Delve Powers",
                        inline = true,
                        order = 2,
                        args = {
                            autoAcceptPower = {
                                type = "toggle",
                                name = "Auto-Take Powers",
                                desc = "Take the delve power automatically instead of being asked for a click you were always going to make.",
                                width = "full",
                                order = 1,
                                get = CreateAccessor("delve", "autoAcceptPower").get,
                                set = CreateAccessor("delve", "autoAcceptPower").set,
                            },
                            hidePowerFrame = {
                                type = "toggle",
                                name = "Hide The Power Pop-Up",
                                desc = "Hide the power window while it's being taken for you. It comes back on its own whenever the choice returns to you.",
                                width = "full",
                                order = 2,
                                disabled = delveNoPower,
                                get = CreateAccessor("delve", "hidePowerFrame").get,
                                set = CreateAccessor("delve", "hidePowerFrame").set,
                            },
                        },
                    },

                    tier = {
                        type = "group",
                        name = "Difficulty",
                        inline = true,
                        order = 3,
                        args = {
                            autoTier = {
                                type = "toggle",
                                name = "Auto-Select Tier",
                                desc = "Pick your usual tier for you when the delve picker opens. Nothing is entered — you still press the button.",
                                width = "full",
                                order = 1,
                                get = CreateAccessor("delve", "autoTier").get,
                                set = CreateAccessor("delve", "autoTier").set,
                            },
                            preferredTier = {
                                type = "range",
                                name = "Tier",
                                desc = "Which tier to select. Skipped if you can't queue for it yet.",
                                min = 1, max = 11, step = 1,
                                order = 2,
                                disabled = delveNoTier,
                                get = CreateAccessor("delve", "preferredTier").get,
                                set = CreateAccessor("delve", "preferredTier").set,
                            },
                        },
                    },
                },
            },

            torghast = {
                type = "group",
                name = "Torghast",
                order = 3,
                args = {
                    intro = {
                        type = "description",
                        order = 1,
                        fontSize = "medium",
                        name = "Anima powers are a real choice, but a repetitive one with a knowable answer — so JustQuest can answer it from a curated list of which powers are worth taking and which are traps.\n\n" ..
                               WARN .. "When nothing on offer is worth taking, the choice goes back to you rather than defaulting to whatever came first.|r",
                    },

                    powers = {
                        type = "group",
                        name = "Anima Powers",
                        inline = true,
                        order = 2,
                        args = {
                            autoSelectPower = {
                                type = "toggle",
                                name = "Auto-Select Powers",
                                desc = "Score the powers on offer and take the best one.\n\n" ..
                                       "Powers known to strand or kill you — movement restrictions, health drains — are never taken, whatever else is on offer.",
                                width = "full",
                                order = 1,
                                get = CreateAccessor("torghast", "autoSelectPower").get,
                                set = CreateAccessor("torghast", "autoSelectPower").set,
                            },
                            hidePowerFrame = {
                                type = "toggle",
                                name = "Hide The Power Pop-Up",
                                desc = "Hide the power window while it's being answered for you. It comes back on its own whenever the choice returns to you.",
                                width = "full",
                                order = 2,
                                disabled = torghastNoPower,
                                get = CreateAccessor("torghast", "hidePowerFrame").get,
                                set = CreateAccessor("torghast", "hidePowerFrame").set,
                            },
                            mode = {
                                type = "select",
                                name = "Pick For",
                                desc = "Which powers count as good.\n\n" ..
                                       EM .. "Clearing|r favours damage and staying alive.\n" ..
                                       EM .. "Farming|r favours movement speed and Phantasma, for fast repeat runs.",
                                order = 3,
                                disabled = torghastNoPower,
                                values = { normal = "Clearing", farming = "Farming" },
                                sorting = { "normal", "farming" },
                                get = CreateAccessor("torghast", "mode").get,
                                set = CreateAccessor("torghast", "mode").set,
                            },
                            autoReroll = {
                                type = "toggle",
                                name = "Reroll A Bad Offering",
                                desc = "Spend one of your rerolls when nothing on offer is worth taking.\n\n" ..
                                       WARN .. "Rerolls are limited. Left off, a bad offering is handed back to you instead.|r",
                                width = "full",
                                order = 4,
                                disabled = torghastNoPower,
                                get = CreateAccessor("torghast", "autoReroll").get,
                                set = CreateAccessor("torghast", "autoReroll").set,
                            },
                        },
                    },

                    entrance = {
                        type = "group",
                        name = "Entering",
                        inline = true,
                        order = 3,
                        args = {
                            autoClimb = {
                                type = "toggle",
                                name = "Pick The Highest Layer",
                                desc = "At the wayfinder, select the highest layer you've unlocked and press Climb.\n\n" ..
                                       "If you're not the group leader, or the portal isn't ready yet, the button is left for you.",
                                width = "full",
                                order = 1,
                                get = CreateAccessor("torghast", "autoClimb").get,
                                set = CreateAccessor("torghast", "autoClimb").set,
                            },
                            -- NOTE: there is deliberately no "accept the prompt" toggle. The
                            -- ready prompt runs AcceptProposal(), a protected function — an
                            -- addon clicking it produces "Interface action failed because of an
                            -- AddOn" and nothing else. Blizzard protects it precisely so queue
                            -- pops cannot be auto-accepted. Selecting the layer is as far as
                            -- automation can go.
                        },
                    },
                },
            },
        },
    }
end

local function CreateGearOptions()
    return {
        type = "group",
        name = "Gear",
        order = 3,
        args = {
            intro = {
                type = "description",
                order = 1,
                fontSize = "medium",
                name = "Scores the gear in your bags with Pawn and, when it finds an upgrade for your current spec, prompts you to equip it — one at a time, with " .. GOOD .. "Equip|r / " .. DANGER .. "Never|r. " ..
                       "Turn on Auto-Equip to skip the prompt and just equip.\n\n" ..
                       WARN .. "Needs a Pawn scale for the spec you're playing.|r  Trinkets aren't scored (a Pawn limitation).",
            },

            settings = {
                type = "group",
                name = "Advisor",
                inline = true,
                order = 2,
                args = {
                    advisorEnabled = {
                        type = "toggle",
                        name = "Recommend Upgrades",
                        desc = "Scan your bags and prompt you to equip gear upgrades for your current spec.",
                        width = "full",
                        order = 1,
                        get = CreateAccessor("gearSwap", "advisorEnabled").get,
                        set = CreateAccessor("gearSwap", "advisorEnabled").set,
                    },
                    autoEquip = {
                        type = "toggle",
                        name = "Auto-Equip",
                        desc = "Skip the prompt: equip recommended upgrades automatically — as you loot, and the best gear for a spec when you switch to it (out of combat). " ..
                               "Bind-on-equip items are never auto-equipped, so nothing binds by surprise.",
                        width = "full",
                        order = 2,
                        disabled = advisorDisabled,
                        get = CreateAccessor("gearSwap", "autoEquip").get,
                        set = CreateAccessor("gearSwap", "autoEquip").set,
                    },
                    announce = {
                        type = "toggle",
                        name = "On-Screen Prompts & Sound",
                        desc = "Show the pop-up prompt (with a sound). Off = chat only, and the config panel below.",
                        width = "full",
                        order = 3,
                        disabled = advisorDisabled,
                        get = CreateAccessor("gearSwap", "announce").get,
                        set = CreateAccessor("gearSwap", "announce").set,
                    },
                    minUpgradePct = {
                        type = "range",
                        name = "Minimum Upgrade",
                        desc = "Ignore upgrades smaller than this, to avoid noise from tiny gains.",
                        min = 1, max = 25, step = 1,
                        order = 4,
                        disabled = advisorDisabled,
                        get = CreateAccessor("gearSwap", "minUpgradePct").get,
                        set = CreateAccessor("gearSwap", "minUpgradePct").set,
                    },
                    respectEquipmentSets = {
                        type = "toggle",
                        name = "Respect Equipment Sets",
                        desc = "Leave gear alone if it belongs to one of your saved equipment sets.\n\n" ..
                               "A speed or utility set is worn for what it does, not its item level, so " ..
                               "suggesting a higher-item-level replacement every time one drops is just noise. " ..
                               "Only the slots filled by set gear are held back — everything else is still offered.\n\n" ..
                               WARN .. "Turn this off if you keep your everyday gear saved as a set.|r",
                        width = "full",
                        order = 5,
                        disabled = advisorDisabled,
                        get = CreateAccessor("gearSwap", "respectEquipmentSets").get,
                        set = CreateAccessor("gearSwap", "respectEquipmentSets").set,
                    },
                    protectProfessionGear = {
                        type = "toggle",
                        name = "Protect Profession Gear",
                        desc = "Never suggest replacing an equipped fishing pole or profession tool.\n\n" ..
                               "These sit in ordinary equipment slots, so to a stat-based score they just " ..
                               "look like weak gear — and get suggested away right before you want them.",
                        width = "full",
                        order = 6,
                        disabled = advisorDisabled,
                        get = CreateAccessor("gearSwap", "protectProfessionGear").get,
                        set = CreateAccessor("gearSwap", "protectProfessionGear").set,
                    },
                    weightItemLevel = {
                        type = "toggle",
                        name = "Weight Item Level (Pawn)",
                        desc = "Adds Item Level to Pawn as a weightable stat, so a big item-level jump counts even when secondary stats are flat. " ..
                               "After enabling, give it a weight in your Pawn scale (e.g. ItemLevel=5) or in Pawn's stat list under \"JustQuest\".\n\n" ..
                               WARN .. "Affects all Pawn scoring — tooltips, reward picks, and the advisor — and modifies Pawn globally.|r",
                        width = "full",
                        order = 7,
                        get = CreateAccessor("gearSwap", "weightItemLevel").get,
                        set = CreateAccessor("gearSwap", "weightItemLevel").set,
                    },
                },
            },

            recommendations = {
                type = "group",
                name = "Recommendations",
                inline = true,
                order = 3,
                hidden = advisorDisabled,
                args = {
                    recsList = {
                        type = "description",
                        order = 1,
                        fontSize = "medium",
                        name = function()
                            local advisor = JustQuest.Core.GetModule("GearAdvisor")
                            local ps = JustQuest.Core.GetModule("PawnScoring")
                            if PawnGetItemData == nil then
                                return MUTED .. "Pawn is not installed — the advisor needs Pawn to score gear.|r"
                            end
                            local recs = advisor and advisor.GetRecommendations() or {}
                            local count = 0
                            for _ in pairs(recs) do count = count + 1 end
                            if count == 0 then
                                -- Active spec, matching what the advisor actually scores
                                -- with — not the loot spec, or this reports "no scale" for
                                -- a spec the advisor never consulted.
                                if ps and ps.HasScaleForSpec and not ps.HasScaleForSpec(GetSpecialization()) then
                                    return WARN .. "No active Pawn scale for this spec — set one up in Pawn (usually automatic). Run |r" .. EM .. "/jq gear check|r" .. WARN .. " for details.|r"
                                end
                                return MUTED .. "No upgrades in your bags for this spec right now.|r"
                            end
                            local s = string.format(EM .. "%d upgrade%s available:|r\n", count, count == 1 and "" or "s")
                            for _, rec in pairs(recs) do
                                local pctStr = (ps and ps.FormatUpgrade(rec.pct)) or "upgrade"
                                -- No "replaces" for an empty slot (Pawn's no-baseline sentinel %).
                                local replaces = (rec.existingLink and rec.pct and rec.pct < 99)
                                    and ("  " .. MUTED .. "replaces " .. rec.existingLink .. "|r") or ""
                                local boe = rec.bound and "" or ("  " .. WARN .. "(BoE — equip by hand)|r")
                                s = s .. "• " .. (rec.link or "?") .. "  " .. GOOD .. pctStr .. "|r" .. replaces .. boe .. "\n"
                            end
                            return s
                        end,
                    },
                    equipUpgrades = {
                        type = "execute",
                        name = "Equip All",
                        desc = "Equip every recommended upgrade now (out of combat). Bind-on-equip items will prompt for confirmation.",
                        order = 2,
                        func = function()
                            local advisor = JustQuest.Core.GetModule("GearAdvisor")
                            if advisor and advisor.EquipAll then advisor.EquipAll(true) end
                        end,
                    },
                    rescan = {
                        type = "execute",
                        name = "Rescan Bags",
                        desc = "Scan your bags for upgrades again now.",
                        order = 3,
                        func = function()
                            local advisor = JustQuest.Core.GetModule("GearAdvisor")
                            if advisor and advisor.RescanNow then advisor.RescanNow() end
                        end,
                    },
                    dismissAll = {
                        type = "execute",
                        name = "Dismiss All",
                        desc = "Ignore the current suggestions until you reload.",
                        order = 4,
                        func = function()
                            local advisor = JustQuest.Core.GetModule("GearAdvisor")
                            if advisor and advisor.DismissAll then advisor.DismissAll() end
                        end,
                    },
                },
            },

            neverList = {
                type = "group",
                name = "Never-Recommend List",
                inline = true,
                order = 4,
                args = {
                    ignoredList = {
                        type = "description",
                        order = 1,
                        fontSize = "small",
                        name = function()
                            local config = JustQuest.Core.GetModule("Config")
                            local list = config and config.Get("gearSwap", "ignoreItems") or {}
                            local names, n = {}, 0
                            for _, v in pairs(list) do
                                n = n + 1
                                if type(v) == "string" then names[#names + 1] = v end
                            end
                            if n == 0 then
                                return MUTED .. "Items you choose \"Never\" on appear here.|r"
                            end
                            if #names > 0 then
                                return MUTED .. "Never recommending: " .. table.concat(names, ", ") .. "|r"
                            end
                            return MUTED .. "Never recommending " .. n .. " item(s).|r"
                        end,
                    },
                    clearIgnored = {
                        type = "execute",
                        name = "Clear Never List",
                        desc = "Start recommending items you marked \"Never\" again.",
                        order = 2,
                        disabled = function()
                            local config = JustQuest.Core.GetModule("Config")
                            local list = config and config.Get("gearSwap", "ignoreItems") or {}
                            return next(list) == nil
                        end,
                        func = function()
                            local config = JustQuest.Core.GetModule("Config")
                            if config then config.Set("gearSwap", "ignoreItems", {}) end
                            local advisor = JustQuest.Core.GetModule("GearAdvisor")
                            if advisor and advisor.RescanNow then advisor.RescanNow() end
                            if ACR then ACR:NotifyChange("JustQuest") end
                        end,
                    },
                },
            },
        },
    }
end

local function CreateQuestOptions()
    return {
        type = "group",
        name = "Quests",
        order = 1,
        args = {
            intro = {
                type = "description",
                order = 1,
                fontSize = "medium",
                name = "Which quests are accepted for you, and how their rewards are chosen.",
            },
            questTypes = {
                type = "group",
                name = "Quest Types",
                inline = true,
                order = 2,
                args = {
                    acceptPvP = {
                        type = "toggle",
                        name = "Accept PvP Quests",
                        desc = "Accept PvP and War Mode quests.\n\n" .. WARN .. "May flag you for PvP.|r",
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
                                return MUTED .. "Pawn is not installed. Upgrade comparison uses item level.|r"
                            end
                            local config = JustQuest.Core.GetModule("Config")
                            if config and config.Get("quest", "usePawnScoring") == false then
                                return WARN .. "Pawn installed but scoring disabled. Using item level.|r"
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
                            return GOOD .. "Pawn active" .. specNote .. ".|r"
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
                        name = "Quests in this list are never auto-accepted. Add by quest ID.",
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
                                return MUTED .. "Quests you block appear here.|r"
                            end

                            local s = string.format(EM .. "Blocked quests (%d):|r\n", count)
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
                        name = "Quests here are allowed to auto-spend currencies " ..
                               "without prompting. Use " .. GOOD .. "Always Allow|r in the confirmation popup to add entries.\n" ..
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
                                return MUTED .. "Quests you Always Allow appear here.|r"
                            end

                            local s = string.format(EM .. "Whitelisted quests (%d):|r\n", count)
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
        order = 2,
        args = {
            intro = {
                type = "description",
                order = 1,
                fontSize = "medium",
                name = "How gossip menus are handled when you talk to NPCs.",
            },

            aggressive = {
                type = "toggle",
                name = "Aggressive Gossip",
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
                        name = "• " .. GOOD .. "Whitelist:|r Selected immediately (still respects repeat protection).\n" ..
                               "• " .. DANGER .. "Blacklist:|r Matching options are skipped; addon picks next safe option.\n\n" ..
                               EM .. "Note:|r With Aggressive Gossip on (default), any gossip option is auto-advanced to reach quests, except forced menus and money/coded options. With it off, only quest-indicated dialog and single service steps are automated.\n",
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
                                        return MUTED .. "Trusted gossip text you add appears here.|r"
                                    end
                                    local s = EM .. "Current whitelist:|r\n"
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
                                        return MUTED .. "Blocked keywords you add appear here.|r"
                                    end
                                    local s = EM .. "Current blacklist:|r\n"
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
        order = 5,
        args = {
            intro = {
                type = "description",
                order = 1,
                fontSize = "medium",
                name = "Opens containers sitting in your bags for you, using the mode and lists below.",
            },

            settings = {
                type = "group",
                name = "Settings",
                inline = true,
                order = 2,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "Auto-Open Containers",
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
                    mode = {
                        type = "select",
                        name = "Auto-Open",
                        desc = "Which containers to auto-open. Your blacklist always overrides.",
                        order = 3,
                        values = {
                            list = "My list only",
                            safe = "Openable containers (clams, chests, coin sacks)",
                        },
                        sorting = { "list", "safe" },
                        get = CreateAccessor("containers", "mode").get,
                        set = CreateAccessor("containers", "mode").set,
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
                        name = EM .. "How to add containers:|r\n" ..
                               "• Click an Add box, then " .. GOOD .. "Shift-Click|r a container in your bags\n" ..
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
                                        print("|cff00ccffJustQuest:|r " .. DANGER .. "Invalid input - enter Item ID or Shift-Click a container|r")
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
                                        return MUTED .. "Containers you whitelist appear here.|r"
                                    end

                                    local s = string.format(EM .. "Current whitelist (%d):|r\n", count)
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
                                        print("|cff00ccffJustQuest:|r " .. DANGER .. "Invalid input - enter Item ID or Shift-Click a container|r")
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
                                        return MUTED .. "Containers you blacklist appear here.|r"
                                    end

                                    local s = string.format(EM .. "Current blacklist (%d):|r\n", count)
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
        order = 6,
        args = {
            intro = {
                type = "description",
                name = "Debugging and timing controls. The defaults are right for almost everyone.",
                order = 1,
                fontSize = "medium",
            },
            debugMode = {
                type = "toggle",
                name = "Debug Mode",
                desc = "Show debug messages in chat.",
                width = "full",
                order = 2,
                get = CreateAccessor(nil, "debugMode").get,
                set = CreateAccessor(nil, "debugMode").set,
            },
            safetyInfo = {
                type = "group",
                name = "Safety Features (Always Active)",
                inline = true,
                order = 3,
                args = {
                    safetyDesc = {
                        type = "description",
                        name = GOOD .. "Built-in protections:|r\n\n" ..
                               "• Options that cost money or need a typed code always stop for you (the server flags them)\n" ..
                               "• Menus the server forces open are shown, never answered for you\n" ..
                               "• Blacklisted keywords (teleports, story skips, etc.) are skipped in every mode\n" ..
                               "• Repeat and chain-depth guards prevent gossip loops\n" ..
                               "• Holding Shift, Ctrl, or Alt pauses automation so you can read a menu\n" ..
                               "• Confirmation pop-ups are handed back to you — only the Delve and Torghast power choices you opt into are answered\n" ..
                               "• With Aggressive Gossip off, only quest-indicated dialog and single service steps are automated\n",
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
            gear = CreateGearOptions(),
            instances = CreateInstanceOptions(),
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
        ACR:RegisterOptionsTable("JustQuest-Landing", CreateLandingOptions())
        uiCache.registered = true
    end

    if not uiCache.addedToBlizz and ACD and uiCache.registered then
        -- The root panel is a slim landing page (overview + master switches); each
        -- category is its own child panel, so nothing renders twice.
        uiCache.blizzFrames["JustQuest"] = ACD:AddToBlizOptions("JustQuest-Landing", "JustQuest")
        uiCache.blizzFrames["JustQuest-Quests"] = ACD:AddToBlizOptions("JustQuest", "Quests", "JustQuest", "quests")
        uiCache.blizzFrames["JustQuest-Gossip"] = ACD:AddToBlizOptions("JustQuest", "NPCs", "JustQuest", "gossip")
        uiCache.blizzFrames["JustQuest-Gear"] = ACD:AddToBlizOptions("JustQuest", "Gear", "JustQuest", "gear")
        uiCache.blizzFrames["JustQuest-Instances"] = ACD:AddToBlizOptions("JustQuest", "Instances", "JustQuest", "instances")
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
