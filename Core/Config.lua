-- Config.lua — AceDB configuration with slash commands

local ADDON_NAME, JustQuest = ...

local Config = {}

-- ============================================================
-- State Management
-- ============================================================

local database = {}
local debugMode = false
local dbObj = nil

-- ============================================================
-- Utilities
-- ============================================================

local function GetDefaults()
    return JustQuest.Constants and JustQuest.Constants.DEFAULTS or { profile = {} }
end

local function Debug(msg)
    local services = JustQuest.Core.GetModule("Services")
    if services then
        services.Debug("Config", msg)
        return
    end
    
    -- Fallback before Services loads
    if debugMode then
        print("|cff00ccffJQ Config:|r " .. tostring(msg))
    end
end

local function GetValueWithFallback(profile, defaults, module, key)
    local value
    if module then
        value = profile[module] and profile[module][key]
        if value == nil and defaults.profile and defaults.profile[module] then
            value = defaults.profile[module][key]
        end
    else
        value = profile[key]
        if value == nil and defaults.profile then
            value = defaults.profile[key]
        end
    end
    return value
end

-- ============================================================
-- Configuration API
-- ============================================================

function Config.Get(module, key)
    if not database or not database.profile then 
        local defaults = GetDefaults()
        if module and defaults.profile and defaults.profile[module] then
            return defaults.profile[module][key]
        else
            return defaults.profile and defaults.profile[key]
        end
    end
    
    local profile = database.profile
    local defaults = GetDefaults()
    return GetValueWithFallback(profile, defaults, module, key)
end

function Config.Set(module, key, value)
    if not database or not database.profile then return end
    
    if module then
        database.profile[module] = database.profile[module] or {}
        database.profile[module][key] = value
    else
        database.profile[key] = value
        if key == "debugMode" then
            debugMode = value and true or false
        end
    end
    
    if not module and key == "enabled" then
        JustQuest.Core.SetupEvents()
    end
    
    if module == "gossip" and (key == "whitelist" or key == "blacklist") then
        local safetyEngine = JustQuest.Core.GetModule("SafetyEngine")
        if safetyEngine and safetyEngine.RebuildLists then
            safetyEngine.RebuildLists()
        end
    end
    
    if module == "containers" and (key == "whitelist" or key == "blacklist" or key == "enabled" or key == "mode" or key == "rogueAutoPick") then
        local containerEngine = JustQuest.Core.GetModule("ContainerEngine")
        if containerEngine and containerEngine.RefreshConfigCache then
            containerEngine.RefreshConfigCache()
        end
    end

    if module == "gearSwap" and (key == "advisorEnabled" or key == "minUpgradePct") and value then
        local advisor = JustQuest.Core.GetModule("GearAdvisor")
        if advisor and advisor.RescanNow then
            advisor.RescanNow()
        end
    end

    -- Rescan in BOTH directions, unlike the toggles above: turning this off has to bring
    -- back the recommendations it was suppressing, and the bags haven't moved either way.
    if module == "gearSwap" and (key == "respectEquipmentSets" or key == "protectProfessionGear") then
        local advisor = JustQuest.Core.GetModule("GearAdvisor")
        if advisor and advisor.RescanNow then
            advisor.RescanNow()
        end
    end

    if module == "gearSwap" and key == "weightItemLevel" then
        local inj = JustQuest.Core.GetModule("PawnStatInjection")
        if inj and inj.Refresh then
            inj.Refresh()
        end
        -- Every score just changed even though the bags didn't, so ask for a scan that
        -- doesn't take "bags look identical" for an answer.
        local advisor = JustQuest.Core.GetModule("GearAdvisor")
        if advisor and advisor.RescanNow then
            advisor.RescanNow()
        end
    end
    
    if not module and key == "debugMode" then
        JustQuest._debugMode = (value and true) or false
        -- Push to Services cache so Services.Debug() never needs GetModule
        local services = JustQuest.Core.GetModule("Services")
        if services and services.SetDebugMode then
            services.SetDebugMode(value)
        end
        Debug("Debug mode " .. (value and "enabled" or "disabled"))
    end

    if JustQuestDB then
        JustQuestDB.profile = database.profile
    end
end

function Config.Save()
    if JustQuestDB then
        JustQuestDB.profile = database.profile
    end
end

function Config.IsDebugMode()
	return debugMode
end

-- ============================================================
-- Gossip List Management
-- ============================================================

function Config.AddGossipWhitelist(text)
    local services = JustQuest.Core.GetModule("Services")
    if not services then return end
    
    local isValid, cleanText, reason = services.ValidateTextForLists(text)
    if not isValid then
        Debug("Cannot add to whitelist: " .. tostring(reason))
        return false
    end
    
    -- Add to whitelist (deduplicate)
    local whitelist = Config.Get("gossip", "whitelist") or {}
    for i=1,#whitelist do 
        if whitelist[i] == cleanText then 
            Debug("Already in whitelist: " .. cleanText)
            return false 
        end 
    end
    table.insert(whitelist, cleanText)
    Config.Set("gossip", "whitelist", whitelist)
    
    Debug("Added to whitelist: " .. cleanText)
    return true
end

function Config.RemoveGossipWhitelist(text)
    local services = JustQuest.Core.GetModule("Services")
    if not services then return end
    
    local isValid, cleanText, reason = services.ValidateTextForLists(text)
    if not isValid then
        Debug("Cannot remove from whitelist: " .. tostring(reason))
        return false
    end
    
    local whitelist = Config.Get("gossip", "whitelist") or {}
    for i = #whitelist, 1, -1 do
        if whitelist[i] == cleanText then
            table.remove(whitelist, i)
            Config.Set("gossip", "whitelist", whitelist)
            Debug("Removed from whitelist: " .. cleanText)
            return true
        end
    end
    
    Debug("Not found in whitelist: " .. cleanText)
    return false
end

function Config.AddGossipBlacklist(text)
    local services = JustQuest.Core.GetModule("Services")
    if not services then return end
    
    local isValid, cleanText, reason = services.ValidateTextForLists(text)
    if not isValid then
        Debug("Cannot add to blacklist: " .. tostring(reason))
        return false
    end
    
    local blacklist = Config.Get("gossip", "blacklist") or {}
    for i=1,#blacklist do 
        if blacklist[i] == cleanText then 
            Debug("Already in blacklist: " .. cleanText)
            return false 
        end 
    end
    table.insert(blacklist, cleanText)
    Config.Set("gossip", "blacklist", blacklist)
    
    Debug("Added to blacklist: " .. cleanText)
    return true
end

function Config.RemoveGossipBlacklist(text)
    local services = JustQuest.Core.GetModule("Services")
    if not services then return end
    
    local isValid, cleanText, reason = services.ValidateTextForLists(text)
    if not isValid then
        Debug("Cannot remove from blacklist: " .. tostring(reason))
        return false
    end
    
    local blacklist = Config.Get("gossip", "blacklist") or {}
    for i = #blacklist, 1, -1 do
        if blacklist[i] == cleanText then
            table.remove(blacklist, i)
            Config.Set("gossip", "blacklist", blacklist)
            Debug("Removed from blacklist: " .. cleanText)
            return true
        end
    end
    
    Debug("Not found in blacklist: " .. cleanText)
    return false
end

-- ============================================================
-- Quest Blacklist Management
-- ============================================================

function Config.AddQuestBlacklist(questID)
    if not questID or type(questID) ~= "number" then return end
    
    local blockedQuests = Config.Get("quest", "blockedQuests") or {}
    if blockedQuests[questID] then return end
    
    blockedQuests[questID] = true
    Config.Set("quest", "blockedQuests", blockedQuests)
    
    Debug("Added quest to blacklist: " .. questID)
end

function Config.RemoveQuestBlacklist(questID)
    if not questID or type(questID) ~= "number" then return end
    
    local blockedQuests = Config.Get("quest", "blockedQuests") or {}
    if not blockedQuests[questID] then return end
    
    blockedQuests[questID] = nil
    Config.Set("quest", "blockedQuests", blockedQuests)
    
    Debug("Removed quest from blacklist: " .. questID)
end

function Config.ClearQuestBlacklist()
    Config.Set("quest", "blockedQuests", {})
    Debug("Cleared quest blacklist")
end

function Config.GetQuestBlacklist()
    return Config.Get("quest", "blockedQuests") or {}
end

-- ============================================================
-- Currency Quest Whitelist Management
-- ============================================================

function Config.AddCurrencyQuestWhitelist(questID, questTitle, currencyText)
    if not questID or type(questID) ~= "number" then return end

    local whitelist = Config.Get("quest", "currencyQuestWhitelist") or {}
    if whitelist[questID] then return end

    whitelist[questID] = {
        title = questTitle or "Unknown Quest",
        currencies = currencyText or "",
    }
    Config.Set("quest", "currencyQuestWhitelist", whitelist)

    Debug("Added quest to currency whitelist: " .. questID)
end

function Config.RemoveCurrencyQuestWhitelist(questID)
    if not questID or type(questID) ~= "number" then return end

    local whitelist = Config.Get("quest", "currencyQuestWhitelist") or {}
    if not whitelist[questID] then return end

    whitelist[questID] = nil
    Config.Set("quest", "currencyQuestWhitelist", whitelist)

    Debug("Removed quest from currency whitelist: " .. questID)
end

function Config.GetCurrencyQuestWhitelist()
    return Config.Get("quest", "currencyQuestWhitelist") or {}
end

-- ============================================================
-- Container Whitelist/Blacklist Management
-- ============================================================

function Config.AddContainerWhitelist(itemID, itemName)
    if not itemID or type(itemID) ~= "number" then return false end
    
    local whitelist = Config.Get("containers", "whitelist") or {}
    if whitelist[itemID] then return false end
    
    whitelist[itemID] = itemName or true
    Config.Set("containers", "whitelist", whitelist)
    
    Debug("Added container to whitelist: " .. itemID .. (itemName and (" (" .. itemName .. ")") or ""))
    return true
end

function Config.RemoveContainerWhitelist(itemID)
    if not itemID or type(itemID) ~= "number" then return false end
    
    local whitelist = Config.Get("containers", "whitelist") or {}
    if not whitelist[itemID] then return false end
    
    whitelist[itemID] = nil
    Config.Set("containers", "whitelist", whitelist)
    
    Debug("Removed container from whitelist: " .. itemID)
    return true
end

function Config.AddContainerBlacklist(itemID, itemName)
    if not itemID or type(itemID) ~= "number" then return false end
    
    local blacklist = Config.Get("containers", "blacklist") or {}
    if blacklist[itemID] then return false end
    
    blacklist[itemID] = itemName or true
    Config.Set("containers", "blacklist", blacklist)
    
    Debug("Added container to blacklist: " .. itemID .. (itemName and (" (" .. itemName .. ")") or ""))
    return true
end

function Config.RemoveContainerBlacklist(itemID)
    if not itemID or type(itemID) ~= "number" then return false end
    
    local blacklist = Config.Get("containers", "blacklist") or {}
    if not blacklist[itemID] then return false end
    
    blacklist[itemID] = nil
    Config.Set("containers", "blacklist", blacklist)
    
    Debug("Removed container from blacklist: " .. itemID)
    return true
end

-- ============================================================
-- Frame Inspection
-- ============================================================

function Config.InspectCurrentFrame()
    print("|cff00ccff========== JustQuest Frame Inspector ==========|r")
    
    local services = JustQuest.Core.GetModule("Services")
    local safeCall = services and services.SafeCall or function(f, ...) return f and f(...) end
    
    -- NPC Information. UnitGUID/UnitName can return "secret" values under taint
    -- (11.x+) that throw on concatenation; render them defensively.
    local function safeStr(v, fallback)
        local ok, s = pcall(function() return v and ("" .. v) or fallback end)
        return ok and s or "secret"
    end
    local npcGUID = safeCall(UnitGUID, "npc")
    local npcName = safeCall(UnitName, "npc")
    print("|cffffcc00NPC:|r " .. safeStr(npcName, "None") .. " |cff888888(" .. safeStr(npcGUID, "no GUID") .. ")|r")
    
    -- Processing State
    local safety = JustQuest.Core.GetModule("SafetyEngine")
    print("|cffffcc00Processing State:|r " .. (safety and safety.GetState() or "UNKNOWN"))
    if safety and safety.GetReason() then
        print("  Reason: " .. safety.GetReason())
    end
    
    -- Frame Visibility
    print("|cffffcc00Visible Frames:|r")
    local frameCount = 0
    if QuestFrame and QuestFrame:IsShown() then 
        print("  ✓ QuestFrame")
        frameCount = frameCount + 1
    end
    if QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown() then 
        print("  ✓ QuestFrameGreetingPanel")
        frameCount = frameCount + 1
    end
    if QuestFrameDetailPanel and QuestFrameDetailPanel:IsShown() then 
        print("  ✓ QuestFrameDetailPanel")
        frameCount = frameCount + 1
    end
    if QuestFrameProgressPanel and QuestFrameProgressPanel:IsShown() then 
        print("  ✓ QuestFrameProgressPanel")
        frameCount = frameCount + 1
    end
    if QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown() then 
        print("  ✓ QuestFrameRewardPanel")
        frameCount = frameCount + 1
    end
    if GossipFrame and GossipFrame:IsShown() then 
        print("  ✓ GossipFrame")
        frameCount = frameCount + 1
    end
    if frameCount == 0 then
        print("  |cffff6666None|r")
    end
    
    -- Gossip Information
    if C_GossipInfo then
        local forceGossip = safeCall(C_GossipInfo.ForceGossip)
        print("|cffffcc00ForceGossip:|r " .. (forceGossip and "|cffff0000YES|r (manual interaction required)" or "|cff00ff00NO|r"))
        
        local availQuests = safeCall(C_GossipInfo.GetAvailableQuests) or {}
        local activeQuests = safeCall(C_GossipInfo.GetActiveQuests) or {}
        print("|cffffcc00Quests:|r Available=" .. #availQuests .. ", Active=" .. #activeQuests)
        
        if #availQuests > 0 then
            print("  Available Quests:")
            for i, quest in ipairs(availQuests) do
                local trivial = quest.isTrivial and " |cff888888(trivial)|r" or ""
                local important = quest.isImportant and " |cffffaa00(!)|r" or ""
                print("    " .. i .. ". " .. (quest.title or "Unknown") .. trivial .. important)
            end
        end
        
        if #activeQuests > 0 then
            print("  Active Quests:")
            for i, quest in ipairs(activeQuests) do
                local complete = quest.isComplete and " |cff00ff00(complete)|r" or " |cffff6666(incomplete)|r"
                print("    " .. i .. ". " .. (quest.title or "Unknown") .. complete)
            end
        end
        
        local options = safeCall(C_GossipInfo.GetOptions) or {}
        print("|cffffcc00Gossip Options:|r " .. #options .. " total")
        
        if #options > 0 then
            local safetyEngine = JustQuest.Core.GetModule("SafetyEngine")
            for i, option in ipairs(options) do
                local available = safetyEngine and safetyEngine.OptionIsAvailable(option) or true
                local isBlacklisted = safetyEngine and safetyEngine.IsBlacklisted(option) or false
                
                local status = available and "|cff00ff00✓|r" or "|cffff6666✗|r"
                local flags = ""
                if isBlacklisted then flags = flags .. " |cffff0000[BLACKLISTED]|r" end
                
                local autoSelect = option.selectOptionWhenOnlyOption
                if autoSelect == false then flags = flags .. " |cffffaa00[NO-AUTOSELECT]|r" end

                local optionType = option.type and (" |cff888888(type:" .. option.type .. ")|r") or ""
                local icon = option.icon and (" icon:" .. option.icon) or ""
                
                print("    " .. status .. " " .. i .. ". " .. (option.name or "Unknown") .. optionType .. icon .. flags)
                if option.gossipOptionID then
                    print("       |cff888888ID: " .. option.gossipOptionID .. "|r")
                end
            end
        end
    else
        print("|cffff6666C_GossipInfo not available|r")
    end
    
    -- Quest Details (if quest frame is open)
    if QuestFrameDetailPanel and QuestFrameDetailPanel:IsShown() then
        print("|cffffcc00Quest Details:|r")
        local title = safeCall(GetTitleText)
        print("  Title: " .. (title or "Unknown"))
        
        local objectives = safeCall(GetObjectiveText)
        if objectives and objectives ~= "" then
            print("  Objectives: " .. objectives:sub(1, 60) .. (objectives:len() > 60 and "..." or ""))
        end
    end
    
    -- Quest Rewards (if reward frame is open)
    if QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown() then
        print("|cffffcc00Quest Rewards:|r")
        if C_QuestLog and C_QuestLog.GetNumRewardChoices then
            local numChoices = safeCall(C_QuestLog.GetNumRewardChoices) or 0
            print("  Reward Choices: " .. numChoices)
            
            if numChoices > 0 then
                for i = 1, numChoices do
                    local itemLink = safeCall(GetQuestItemLink, "choice", i)
                    if itemLink then
                        print("    " .. i .. ". " .. itemLink)
                    end
                end
            end
        end
        
        if GetNumQuestRewards then
            local numRewards = safeCall(GetNumQuestRewards) or 0
            if numRewards > 0 then
                print("  Fixed Rewards: " .. numRewards)
            end
        end
    end
    
    -- Automation Status
    print("|cffffcc00Automation Status:|r")
    local enabled = Config.Get(nil, "enabled")
    local questEnabled = Config.Get("quest", "enabled")
    local gossipEnabled = Config.Get("gossip", "enabled")
    print("  Master: " .. (enabled and "|cff00ff00ON|r" or "|cffff6666OFF|r"))
    print("  Quest: " .. (questEnabled and "|cff00ff00ON|r" or "|cffff6666OFF|r"))
    print("  Gossip: " .. (gossipEnabled and "|cff00ff00ON|r" or "|cffff6666OFF|r"))
    
    if services then
        local canAutomate = services.CanAutomate and services.CanAutomate() or false
        local contextAllowed = services.IsAutomationContextAllowed and services.IsAutomationContextAllowed() or false
        print("  Can Automate: " .. (canAutomate and "|cff00ff00✓|r" or "|cffff6666✗|r"))
        print("  Context: " .. (contextAllowed and "|cff00ff00✓|r" or "|cffff6666✗|r (invalid frame)"))
    end
    
    -- Recent Selections (if SafetyEngine available)
    local safetyEngine = JustQuest.Core.GetModule("SafetyEngine")
    if safetyEngine and npcGUID then
        local gossipEngine = JustQuest.Core.GetModule("GossipEngine")
        if gossipEngine and gossipEngine.GetStateInfo then
            local stateInfo = gossipEngine.GetStateInfo()
            if stateInfo then
                print("|cffffcc00Gossip Engine State:|r")
                print("  Chain Depth: " .. (stateInfo.chainDepth or 0))
                print("  Automation Halted: " .. (stateInfo.automationHalted and "|cffff0000YES|r" or "|cff00ff00NO|r"))
            end
        end
    end
    
    print("|cff00ccff" .. string.rep("=", 47) .. "|r")
end

-- ============================================================
-- Slash Commands
-- ============================================================

local function HandleSlashCommand(msg)
    local cmd, rest = strsplit(" ", msg, 2)
    cmd = cmd and cmd:lower() or ""

    -- Match JustAC behavior: no argument opens options panel
    if cmd == "" then
        Config.ShowConfig()
        return
    end

    if cmd == "help" then
        print("|cff00ccff========== JustQuest ==========|r")
        print("|cffffcc00Commands:|r")
        print("  |cff00ff00/jq|r - Open options panel")
        print("  |cff00ff00/jq help|r - Show this help")
        print("  |cff00ff00/jq toggle|r - Enable/disable addon")
        print("  |cff00ff00/jq config|r - Open settings panel")
        print("  |cff00ff00/jq status|r - Show current status")
        print("  |cff00ff00/jq debug [on|off]|r - Toggle debug logging")
        print("  |cff00ff00/jq gear [on|off]|r - Auto-swap gear on spec change")
        print("  |cff00ff00/jq gear smart|full|r - Swap weapons/trinkets/rings, or all gear")
        print("")
        print("|cffffcc00Container Management:|r")
        print("  |cff00ff00Shift-Click|r in config UI - Add container to whitelist (easiest!)")
        print("  |cff00ff00/jq container add <itemID>|r - Add to whitelist")
        print("  |cff00ff00/jq container remove <itemID>|r - Remove from whitelist")
        print("  |cff00ff00/jq container block <itemID>|r - Add to blacklist")
        print("  |cff00ff00/jq container unblock <itemID>|r - Remove from blacklist")
        print("  |cff00ff00/jq container list|r - Show your custom lists")
        print("")
        print("|cff888888Utility:|r")
        print("  |cff00ff00/jq inspect|r - Inspect current NPC/quest frame")
        print("  |cff00ff00/jql|r - Leave instance/party")
        print("")
        print("|cffffaa00Tip:|r Open config UI (|cff00ff00/jq config|r), click 'Add Item ID', then Shift-Click containers!")
        print("|cff888888Use /jq config for detailed settings|r")
        print("|cff00ccff" .. string.rep("=", 30) .. "|r")
        return
    end
    
    -- Toggle addon on/off
    if cmd == "toggle" then
        local current = Config.Get(nil, "enabled")
        Config.Set(nil, "enabled", not current)
        print("|cff00ccffJustQuest:|r " .. (not current and "|cff00ff00Enabled|r" or "|cffff6666Disabled|r"))
        return
    end
    
    -- Open config panel
    if cmd == "config" or cmd == "settings" or cmd == "options" then
        Config.ShowConfig()
        return
    end
    
    -- Show quick status
    if cmd == "status" then
        local enabled = Config.Get(nil, "enabled")
        local questEnabled = Config.Get("quest", "enabled")
        local gossipEnabled = Config.Get("gossip", "enabled")
        local debug = Config.Get(nil, "debugMode")
        
        print("|cff00ccff========== JustQuest Status ==========|r")
        print("  Addon: " .. (enabled and "|cff00ff00ON|r" or "|cffff6666OFF|r"))
        print("  Quest Automation: " .. (questEnabled and "|cff00ff00ON|r" or "|cffff6666OFF|r"))
        print("  Gossip Automation: " .. (gossipEnabled and "|cff00ff00ON|r" or "|cffff6666OFF|r"))
        print("  Debug Logging: " .. (debug and "|cff00ff00ON|r" or "|cffff6666OFF|r"))
        
        local services = JustQuest.Core.GetModule("Services")
        if services then
            local canAutomate = services.CanAutomate and services.CanAutomate() or false
            print("  Can Automate: " .. (canAutomate and "|cff00ff00✓|r" or "|cffff6666✗|r"))
        end
        
        print("|cff00ccff" .. string.rep("=", 38) .. "|r")
        print("|cff888888Use /jq config for detailed settings|r")
        return
    end
    
    -- Inspect current NPC/quest frame
    if cmd == "inspect" then
        Config.InspectCurrentFrame()
        return
    end
    
    -- Debug toggle
    if cmd == "debug" then
        if not rest or rest == "" then
            local current = Config.Get(nil, "debugMode")
            local newValue = not current
            Config.Set(nil, "debugMode", newValue)
            print("|cff00ccffJustQuest:|r Debug logging " .. (newValue and "|cff00ff00enabled|r" or "|cffff6666disabled|r"))
            return
        end

        if rest then
            local mode = rest:lower()
            if mode == "on" or mode == "1" or mode == "true" or mode == "enable" then
                Config.Set(nil, "debugMode", true)
                print("|cff00ccffJustQuest:|r Debug logging |cff00ff00enabled|r")
                print("|cff888888Debug messages will appear in chat|r")
            elseif mode == "off" or mode == "0" or mode == "false" or mode == "disable" then
                Config.Set(nil, "debugMode", false)
                print("|cff00ccffJustQuest:|r Debug logging |cffff6666disabled|r")
            else
                print("|cffff6666Usage:|r /jq debug <on|off>")
            end
        end
        return
    end

    -- Fast mode toggle
    if cmd == "fast" then
        local current = Config.Get(nil, "fastMode") or false
        Config.Set(nil, "fastMode", not current)
        print("|cff00ccffJustQuest:|r Fast mode " .. (not current and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        return
    end

    -- Gear Advisor (Pawn-powered upgrade recommendations)
    if cmd == "gear" or cmd == "g" then
        local sub = (rest and strsplit(" ", rest):lower()) or ""
        if sub == "check" or sub == "debug" then
            local advisor = JustQuest.Core.GetModule("GearAdvisor")
            if advisor and advisor.Diagnose then
                advisor.Diagnose()
            else
                print("|cff00ccffJustQuest:|r Gear Advisor not loaded.")
            end
        elseif sub == "clear" then
            Config.Set("gearSwap", "ignoreItems", {})
            print("|cff00ccffJustQuest:|r Gear Advisor never-recommend list cleared.")
            local advisor = JustQuest.Core.GetModule("GearAdvisor")
            if advisor and advisor.RescanNow then advisor.RescanNow() end
        elseif sub == "on" or sub == "off" then
            Config.Set("gearSwap", "advisorEnabled", sub == "on")
            print("|cff00ccffJustQuest:|r Gear Advisor " .. (sub == "on" and "|cff00ff00ON|r" or "|cffff6666OFF|r"))
        elseif sub == "" then
            local cur = Config.Get("gearSwap", "advisorEnabled")
            Config.Set("gearSwap", "advisorEnabled", not cur)
            print("|cff00ccffJustQuest:|r Gear Advisor " .. (not cur and "|cff00ff00ON|r" or "|cffff6666OFF|r"))
        else
            print("|cffff6666Usage:|r /jq gear [on|off|check|clear]")
        end
        return
    end

    -- Delve automation (powers / tier)
    if cmd == "delve" or cmd == "d" then
        local sub = (rest and strsplit(" ", rest):lower()) or ""
        if sub == "on" or sub == "off" or sub == "" then
            local value
            if sub == "" then
                value = not Config.Get("delve", "autoAcceptPower")
            else
                value = (sub == "on")
            end
            Config.Set("delve", "autoAcceptPower", value)
            print("|cff00ccffJustQuest:|r Delve power auto-take " .. (value and "|cff00ff00ON|r" or "|cffff6666OFF|r"))
        elseif sub == "check" or sub == "status" then
            local delve = JustQuest.Core.GetModule("DelveEngine")
            local inDelve = delve and delve.IsInDelve and delve.IsInDelve()
            print("|cff00ccffJustQuest:|r In a delve: " .. (inDelve and "|cff00ff00YES|r" or "|cff888888no|r"))
            print("  auto-take powers: " .. tostring(Config.Get("delve", "autoAcceptPower")))
            print("  auto-select tier: " .. tostring(Config.Get("delve", "autoTier"))
                  .. " (tier " .. tostring(Config.Get("delve", "preferredTier"))
                  .. ", go straight in: " .. tostring(Config.Get("delve", "autoEnter")) .. ")")
        else
            print("|cffff6666Usage:|r /jq delve [on|off|check]")
        end
        return
    end

    -- Container management
    if cmd == "container" or cmd == "c" then
        if not rest then
            print("|cffffaa00Tip:|r Open config (|cff00ff00/jq config|r), click 'Add Item ID', then Shift-Click containers!")
            print("|cff888888Or use:|r /jq c list")
            return
        end
        
        local subCmd, itemIDStr = strsplit(" ", rest, 2)
        subCmd = subCmd and subCmd:lower() or ""
        
        if subCmd == "list" or subCmd == "l" then
            local whitelist = Config.Get("containers", "whitelist") or {}
            local blacklist = Config.Get("containers", "blacklist") or {}
            
            print("|cff00ccff========== Container Lists ==========|r")
            
            local whiteCount = 0
            for itemID, value in pairs(whitelist) do
                whiteCount = whiteCount + 1
            end
            
            if whiteCount > 0 then
                print("|cff00ff00Whitelist:|r " .. whiteCount .. " containers")
                for itemID, value in pairs(whitelist) do
                    local itemName = type(value) == "string" and value or C_Item.GetItemNameByID(itemID) or "Unknown"
                    print("  " .. itemID .. " - " .. itemName)
                end
            else
                print("|cff00ff00Whitelist:|r Empty (openable containers are auto-detected by mode)")
            end
            
            print("")
            
            local blackCount = 0
            for itemID, value in pairs(blacklist) do
                blackCount = blackCount + 1
            end
            
            if blackCount > 0 then
                print("|cffff6666Blacklist:|r " .. blackCount .. " containers")
                for itemID, value in pairs(blacklist) do
                    local itemName = type(value) == "string" and value or C_Item.GetItemNameByID(itemID) or "Unknown"
                    print("  " .. itemID .. " - " .. itemName)
                end
            else
                print("|cffff6666Blacklist:|r Empty")
            end
            
            print("|cff00ccff" .. string.rep("=", 39) .. "|r")
            
            local modeLabels = {
                list = "My list only",
                safe = "Safe containers (clams, chests, coin sacks)",
                all  = "Everything openable (incl. lockboxes)",
            }
            local mode = Config.Get("containers", "mode") or "safe"
            print("|cff888888Auto-open mode: |cff00ff00" .. (modeLabels[mode] or mode) .. "|r|r")
            return
        end
        
        if not itemIDStr then
            print("|cffff6666Error:|r Missing item ID")
            print("|cffffaa00Tip:|r Open config (|cff00ff00/jq config|r), then Shift-Click containers!")
            return
        end
        
        local itemID = tonumber(itemIDStr)
        if not itemID then
            print("|cffff6666Error:|r Invalid item ID '" .. itemIDStr .. "' (must be a number)")
            return
        end
        
        -- Get item name for better feedback
        local itemName = C_Item.GetItemNameByID(itemID)
        local displayName = itemName and ("|cff00ccff[" .. itemName .. "]|r") or ("Item " .. itemID)
        
        if subCmd == "add" then
            if Config.AddContainerWhitelist(itemID, itemName) then
                print("|cff00ccffJustQuest:|r Added to whitelist: " .. displayName)
            else
                print("|cffffaa00JustQuest:|r Already in whitelist: " .. displayName)
            end
        elseif subCmd == "remove" or subCmd == "rm" then
            if Config.RemoveContainerWhitelist(itemID) then
                print("|cff00ccffJustQuest:|r Removed from whitelist: " .. displayName)
            else
                print("|cffffaa00JustQuest:|r Not in whitelist: " .. displayName)
            end
        elseif subCmd == "block" then
            if Config.AddContainerBlacklist(itemID, itemName) then
                print("|cff00ccffJustQuest:|r Added to blacklist: " .. displayName)
            else
                print("|cffffaa00JustQuest:|r Already in blacklist: " .. displayName)
            end
        elseif subCmd == "unblock" then
            if Config.RemoveContainerBlacklist(itemID) then
                print("|cff00ccffJustQuest:|r Removed from blacklist: " .. displayName)
            else
                print("|cffffaa00JustQuest:|r Not in blacklist: " .. displayName)
            end
        else
            print("|cffff6666Error:|r Unknown command '" .. subCmd .. "'")
            print("|cffffaa00Tip:|r Open config (|cff00ff00/jq config|r), then Shift-Click containers!")
        end
        return
    end
    
    -- Unknown command
    print("|cffff6666JustQuest:|r Unknown command '|cffffaa00" .. cmd .. "|r'")
    print("|cff888888Type|r |cff00ff00/jq help|r |cff888888for available commands|r")
end

SLASH_JUSTQUEST1 = "/justquest"
SLASH_JUSTQUEST2 = "/jq"
SlashCmdList["JUSTQUEST"] = HandleSlashCommand

-- ============================================================
-- UI Integration
-- ============================================================

function Config.ShowConfig()
    -- Try to show UI via ConfigUI module
    local configUI = JustQuest.Core.GetModule("ConfigUI")
    if configUI and configUI.ShowConfig then
        configUI.ShowConfig()
    else
        local services = JustQuest.Core.GetModule("Services")
        if services then
            services.Debug("Config", "Options panel not available - use slash commands: /jq help")
        else
            print("|cff00ccffJustQuest:|r Options panel not available - use slash commands: /jq help")
        end
    end
end

function Config.CreateAccessor(module, key)
    return {
        get = function() 
            return Config.Get(module, key) 
        end,
        set = function(info, value) 
            Config.Set(module, key, value) 
        end
    }
end

-- ============================================================
-- Initialization
-- ============================================================

function Config.Initialize()
    local defaultConfig = GetDefaults()

    -- Prefer AceDB for robust profile handling
    if LibStub then
        local AceDB = LibStub("AceDB-3.0", true)
        if AceDB then
            local ok, res = pcall(function()
                return AceDB:New("JustQuestDB", defaultConfig, true)
            end)
            if ok and res then
                dbObj = res
                database.profile = dbObj.profile or (defaultConfig.profile or {})
            end
        end
    end

    -- Fallback to direct SavedVariables if AceDB not available or creation failed
    if not database.profile then
        if JustQuestDB and JustQuestDB.profile then
            database.profile = JustQuestDB.profile
        else
            database.profile = defaultConfig.profile or {}
        end
    end

    -- Set debug mode
    debugMode = database.profile.debugMode or false
    -- Mirror into a lightweight global for early debug checks
    JustQuest._debugMode = debugMode and true or false

    -- Ensure global SavedVariables references the live profile
    if not JustQuestDB then 
        JustQuestDB = {} 
    end
    JustQuestDB.profile = database.profile

    if dbObj and dbObj.RegisterCallback then
        dbObj:RegisterCallback("OnProfileChanged", function()
            database.profile = dbObj.profile or database.profile
            debugMode = database.profile.debugMode or false
            JustQuest._debugMode = debugMode and true or false
            Debug("Profile changed via AceDB")
        end)
    end

    -- Register logout handler
    local logoutFrame = CreateFrame("FRAME")
    logoutFrame:RegisterEvent("PLAYER_LOGOUT")
    logoutFrame:SetScript("OnEvent", function()
        if JustQuestDB then
            JustQuestDB.profile = database.profile
        end
        Config.Save()
        logoutFrame:UnregisterEvent("PLAYER_LOGOUT")
    end)
    
    -- Initialize sub-sections if not present
    if not database.profile.gossip then
        database.profile.gossip = {
            enabled = true,
            whitelist = {},
            blacklist = defaultConfig.profile.gossip and defaultConfig.profile.gossip.blacklist or {}
        }
    end
    
    if not database.profile.quest then
        database.profile.quest = {
            enabled = true,
            acceptEscort = false,
            acceptPvP = false,
            acceptRepeatable = true,
            acceptTrade = true,
            acceptTrivial = true,
            autoReward = false,
            simpleRewardMode = false,
        }
    end
    
    if not database.profile.advanced then
        database.profile.advanced = defaultConfig.profile.advanced or {}
	end
end

-- Expose the database object for ConfigUI module
function Config.GetDatabase()
    return dbObj
end

-- ============================================================
-- Module Registration
-- ============================================================

JustQuest.Core.RegisterModule("Config", Config, {})

-- Expose Config globally for convenience
JustQuest.Config = Config

return Config
