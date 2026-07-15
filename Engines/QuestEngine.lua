-- QuestEngine.lua — Event-driven quest automation with sequential processing and retry logic

local ADDON_NAME, JustQuest = ...

local QuestEngine = {}
JustQuest._stats = JustQuest._stats or {}

-- Hot path locals
local GetTime = GetTime
local pcall = pcall

-- TTL guard prevents race-condition re-entry after failed accepts
local lastResetTime = 0
local recentAcceptAttempts = {}
local ACCEPT_ATTEMPT_TTL = 5.0

-- Authoritative quest-log-full signal. Set by ERR_QUEST_LOG_FULL (WoW fires it when
-- an accept actually fails for fullness — the reliable signal, since the quest COUNT
-- is unreliable), cleared by QUEST_REMOVED when a slot frees. While set, accepts are
-- paused so we don't spam doomed AcceptQuest calls (and re-trigger WoW's error).
local questLogFull = false
local QUEST_LOG_FULL_ERR = LE_GAME_ERR_QUEST_LOG_FULL  -- numeric error type (may be nil on old clients)
local errorEventFrame  -- holds UI_ERROR_MESSAGE / QUEST_REMOVED listener (created in Initialize)

-- Memoized module accessors
local GetSafetyEngine = JustQuest.Core.ModuleGetter("SafetyEngine")
local GetServices     = JustQuest.Core.ModuleGetter("Services")
local GetConfig       = JustQuest.Core.ModuleGetter("Config")
local GetGameData     = JustQuest.Core.ModuleGetter("GameData")

-- ============================================================
-- Currency Confirmation Popup
-- ============================================================
-- Registered at load time (StaticPopup requires top-level registration).
-- Shows when a quest requires currency consumption and the quest is not whitelisted.
-- Repeatable quests: 3-button (Spend Once / Cancel / Always Allow)
-- Non-repeatable quests: 2-button (Spend / Cancel) — whitelisting never makes sense

local function CurrencyPopup_Spend(data)
    local safetyEngine = JustQuest.Core.GetModule("SafetyEngine")
    local services = JustQuest.Core.GetModule("Services")
    if safetyEngine then safetyEngine.SetState("BUSY", "completing_quest") end
    if services then services.SafeCall(CompleteQuest) end
end

local function CurrencyPopup_Cancel()
    local safetyEngine = JustQuest.Core.GetModule("SafetyEngine")
    if safetyEngine then safetyEngine.EndProcessing("user_cancelled_currency_spend") end
end

local function CurrencyPopup_Hide()
    -- Safety net: if closed via Escape without choosing, release BUSY state
    local safetyEngine = JustQuest.Core.GetModule("SafetyEngine")
    if safetyEngine and safetyEngine.GetState() == "BUSY"
                   and safetyEngine.GetReason() == "waiting_currency_prompt" then
        safetyEngine.EndProcessing("currency_prompt_dismissed")
    end
end

-- 3-button variant: shown for repeatable quests (daily/weekly/general repeatable)
StaticPopupDialogs["JUSTQUEST_CONFIRM_CURRENCY"] = {
    text = "Quest: |cffffd100%s|r\n\nRequires:\n%s\n\nAllow JustQuest to spend this?",
    button1 = "Spend Once",
    button2 = "Cancel",
    button3 = "Always Allow",
    OnAccept = function(self, data) CurrencyPopup_Spend(data) end,
    OnAlt = function(self, data)
        if data and data.questID then
            local config = JustQuest.Core.GetModule("Config")
            if config and config.AddCurrencyQuestWhitelist then
                config.AddCurrencyQuestWhitelist(data.questID, data.questTitle, data.currencyText)
            end
        end
        CurrencyPopup_Spend(data)
    end,
    OnCancel = function(self, data) CurrencyPopup_Cancel() end,
    OnHide = function(self) CurrencyPopup_Hide() end,
    timeout = 0,
    whileDead = false,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- 2-button variant: shown for non-repeatable quests (no whitelist option)
StaticPopupDialogs["JUSTQUEST_CONFIRM_CURRENCY_ONCE"] = {
    text = "Quest: |cffffd100%s|r\n\nRequires:\n%s\n\nAllow JustQuest to spend this?",
    button1 = "Spend",
    button2 = "Cancel",
    OnAccept = function(self, data) CurrencyPopup_Spend(data) end,
    OnCancel = function(self, data) CurrencyPopup_Cancel() end,
    OnHide = function(self) CurrencyPopup_Hide() end,
    timeout = 0,
    whileDead = false,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ============================================================
-- Quest Visibility Filters (with blacklist integration)
-- ============================================================

-- Check if active quest (turn-in) should be visible
local function IsActiveQuestVisible(quest)
    if not quest or not quest.questID then return false end
    
    local services = GetServices()
    
    -- BLACKLIST: Block if blacklisted
    if services and services.IsQuestBlocked(quest.questID) then
        return false
    end
    
    -- Must be complete to turn in
    if not quest.isComplete then
        return false
    end
    
    return true
end

-- Check if available quest (accept) should be visible
local function IsAvailableQuestVisible(quest)
    if not quest or not quest.questID then return false end
    
    local services = GetServices()
    local config = GetConfig()
    local safetyEngine = GetSafetyEngine()
    local questName = quest.title or ("QuestID:" .. quest.questID)
    
    -- BLACKLIST: Block if blacklisted
    if services and services.IsQuestBlocked(quest.questID) then
        if services.Debug then services.Debug("Quest", "Filtered " .. questName .. ": blacklisted") end
        return false
    end
    
    -- Already in quest log (prevents infinite accept loop)
    if C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(quest.questID) then
        if services and services.Debug then services.Debug("Quest", "Filtered " .. questName .. ": already in log") end
        return false
    end
    
    -- Recently attempted to accept (prevents race condition loops)
    local lastAttempt = recentAcceptAttempts[quest.questID]
    if lastAttempt and (GetTime() - lastAttempt) < ACCEPT_ATTEMPT_TTL then
        if services and services.Debug then services.Debug("Quest", "Filtered " .. questName .. ": recent accept attempt (" .. string.format("%.1fs ago", GetTime() - lastAttempt) .. ")") end
        return false
    end
    
    -- Already completed (don't reaccept unless repeatable)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local success, isCompleted = pcall(C_QuestLog.IsQuestFlaggedCompleted, quest.questID)
        if success and isCompleted then
            -- Allow if explicitly repeatable
            if not (quest.frequency or quest.isRepeatable) then
                if services and services.Debug then services.Debug("Quest", "Filtered " .. questName .. ": already completed") end
                return false
            end
        end
    end
    
    -- Trivial/low-level quests (greyed out)
    if quest.isTrivial then
        local showLowLevel = config and config.Get("quest", "acceptTrivial")
        if not showLowLevel then
            if services and services.Debug then services.Debug("Quest", "Filtered " .. questName .. ": trivial (acceptTrivial disabled)") end
            return false
        end
    end
    
    -- Quest is ignored in log
    if C_QuestLog and C_QuestLog.IsQuestIgnored then
        local success, isIgnored = pcall(C_QuestLog.IsQuestIgnored, quest.questID)
        if success and isIgnored then
            if services and services.Debug then services.Debug("Quest", "Filtered " .. questName .. ": ignored in quest log") end
            return false
        end
    end
    
    -- SafetyEngine validation (quest type, settings, etc.)
    if safetyEngine and not safetyEngine.ShouldAcceptQuest(quest.questID, quest.frequency) then
        if services and services.Debug then services.Debug("Quest", "Filtered " .. questName .. ": ShouldAcceptQuest refused (freq=" .. tostring(quest.frequency) .. ")") end
        return false
    end
    
    return true
end

-- ============================================================
-- Quest Selection with Retries
-- ============================================================

local function SelectQuest(selectFunc, param)
    if not pcall(selectFunc, param) then return false end
    JustQuest._lastProcessingTime = GetTime()
    return true
end

-- ============================================================
-- Simplified Quest Processing (event-driven, one quest at a time)
-- ============================================================

local function ProcessActiveQuests()
    local services = GetServices()
    
    local success, quests = pcall(C_GossipInfo.GetActiveQuests)
    if not (success and quests and #quests > 0) then
        if services and services.Debug then
            services.Debug("Quest", "No active quests from API (success=" .. tostring(success) .. ", count=" .. tostring(quests and #quests or 0) .. ")")
        end
        return false
    end
    
    if services and services.Debug then
        services.Debug("Quest", "Processing " .. #quests .. " active quest(s)")
    end
    
    -- Pre-filter: one visibility check per quest (avoids O(n log n) checks in sort)
    local visible = {}
    for _, quest in ipairs(quests) do
        if IsActiveQuestVisible(quest) then
            visible[#visible + 1] = quest
        elseif services and services.Debug then
            local reason = not quest.isComplete and "not complete"
                or (services.IsQuestBlocked(quest.questID) and "blacklisted")
                or "filtered"
            services.Debug("Quest", "Filtered: " .. (quest.title or "Unknown") .. " - " .. reason)
        end
    end
    
    if #visible == 0 then
        if services and services.Debug then
            services.Debug("Quest", "No visible active quests to process")
        end
        return false
    end
    
    -- Sort only visible quests by priority (skip sort for single quest)
    if #visible > 1 then
        -- Precompute account-completion status to avoid O(n log n) pcalls
        -- inside the sort comparator. Also fixes the original bug where only
        -- the pcall success bool was captured instead of the actual result.
        local familiarStatus = {}
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompletedOnAccount then
            for _, quest in ipairs(visible) do
                local ok, isFamiliar = pcall(C_QuestLog.IsQuestFlaggedCompletedOnAccount, quest.questID)
                familiarStatus[quest.questID] = ok and isFamiliar or false
            end
        end

        table.sort(visible, function(a, b)
            -- Important/legendary/campaign quests first
            local aImportant = a.isImportant or a.isLegendary or a.isMeta
            local bImportant = b.isImportant or b.isLegendary or b.isMeta
            if aImportant ~= bImportant then return aImportant end

            -- Account-familiar repeatables first for faster turn-ins
            local aFamiliar = familiarStatus[a.questID]
            local bFamiliar = familiarStatus[b.questID]
            if aFamiliar ~= bFamiliar then return aFamiliar end

            return false
        end)
    end
    
    -- Select the highest-priority visible quest
    for _, quest in ipairs(visible) do
        if services and services.Debug then
            services.Debug("Quest", "Turn-in: " .. (quest.title or "Unknown") .. " (ID: " .. tostring(quest.questID) .. ")")
        end
        
        if SelectQuest(C_GossipInfo.SelectActiveQuest, quest.questID) then
            return true
        end
    end
    
    return false
end

local function ProcessAvailableQuests()
    -- Log full: pause accepts (turn-ins still run and free slots → clears the flag).
    if questLogFull then return false end

    local services = GetServices()

    local success, quests = pcall(C_GossipInfo.GetAvailableQuests)
    if not (success and quests and #quests > 0) then
        return false
    end
    
    -- Pre-filter: one visibility check per quest (avoids O(n log n) checks in sort)
    local visible = {}
    for _, quest in ipairs(quests) do
        if IsAvailableQuestVisible(quest) then
            visible[#visible + 1] = quest
        end
    end
    
    if #visible == 0 then
        -- Nothing acceptable here (all filtered: already in log, blocked, trivial,
        -- recently attempted). We don't guess "log full" from the quest count — it's
        -- unreliable (counts non-cap quests). A genuinely full log surfaces via WoW's
        -- own error when an accept is attempted.
        return false
    end
    
    -- Sort only visible quests by priority (skip sort for single quest)
    if #visible > 1 then
        table.sort(visible, function(a, b)
            local aImportant = a.isImportant or a.isLegendary or a.isMeta
            local bImportant = b.isImportant or b.isLegendary or b.isMeta
            if aImportant ~= bImportant then return aImportant end
            return false
        end)
    end
    
    -- Select the highest-priority visible quest
    for _, quest in ipairs(visible) do
        if services and services.Debug then
            local questType = (quest.isImportant and "[Important]") or (quest.isLegendary and "[Legendary]") or (quest.isMeta and "[Campaign]") or ""
            services.Debug("Quest", "Accept: " .. questType .. " " .. (quest.title or "Unknown") .. " (ID: " .. tostring(quest.questID) .. ")")
        end
        
        if SelectQuest(C_GossipInfo.SelectAvailableQuest, quest.questID) then
            return true
        end
    end
    
    return false
end

local function ScheduleFinalRepump()
    local services = GetServices()
    if not services or not services.ScheduleContentCheck then return end

    -- Unified content check after gossip completes (for quests unlocked by gossip)
    -- DispatchContent handles IsBusy guard and routes to QuestEngine.OnGossipShow
    local delay = services.GetTiming("SERVER_SYNC_DELAY", 0.15)
    services.ScheduleContentCheck(delay, "final_quest_repump")
end
-- ============================================================
-- State Management
-- ============================================================

local function ResetProcessing()
    local safetyEngine = GetSafetyEngine()
    local services = GetServices()
    
    -- Guard: skip EndProcessing if already IDLE (HandleGossip may have called it)
    if safetyEngine and safetyEngine.GetState() ~= "IDLE" then
        safetyEngine.EndProcessing("quest_reset")
    end
    if services then
        services.CancelScheduled("quest_processing_timeout")
        -- Don't cancel content_repump here: GOSSIP_CLOSED fires during quest
        -- transitions and calls ResetWorkflow → ResetProcessing, which would
        -- kill the pending re-check scheduled by QUEST_FINISHED/PumpQuestCheck.
        -- DispatchContent already guards against stale or invalid calls.
    end
    
    JustQuest._stats.resetCount = (JustQuest._stats.resetCount or 0) + 1
    lastResetTime = GetTime()
    
    if services and services.Debug then
        services.Debug("Quest", "State reset - ready for next interaction")
    end
end

local function StartProcessing()
    local safetyEngine = GetSafetyEngine()
    local services = GetServices()
    local config = GetConfig()
    
    if not (safetyEngine and safetyEngine.CanProcess()) then return false end
    if not services then return false end
    
    local timeout = config and config.Get("advanced", "questProcessingTimeout") or 3.0
    if not safetyEngine.BeginProcessing("processing") then return false end
    
    JustQuest._lastProcessingTime = GetTime()
    JustQuest._questProcessingStart = GetTime()
    
    -- Simple timeout guard
    services.CancelScheduled("quest_processing_timeout")
    services.ScheduleOnce("quest_processing_timeout", timeout, function()
        local safety = GetSafetyEngine()
        if safety and safety.IsBusy() and GetTime() - (JustQuest._lastProcessingTime or 0) > timeout then
            ResetProcessing()
        end
    end)
    
    return true
end

-- ============================================================
-- Event Handlers
-- ============================================================

function QuestEngine.OnQuestGreeting()
    local services = GetServices()
    if not services then return end
    
    QuestEngine.ProcessLegacyQuestGreeting()
end

function QuestEngine.ProcessLegacyQuestGreeting()
    local services = GetServices()
    local safetyEngine = GetSafetyEngine()
    local gameData = GetGameData()
    
    if not services then return end
    
    -- Modifier held: bypass automation so player can interact manually
    if not services.ShouldAutomate() then
        services.RestoreAutomationFrames()
        return
    end
    
    -- Simple safety checks
    if not (services.IsAutomationContextAllowed and services.IsAutomationContextAllowed()) then
        return
    end
    
    -- Prevent rapid re-entry (same cooldown as OnGossipShow)
    local cooldown = services.GetTiming and services.GetTiming("GOSSIP_REENTER_COOLDOWN", 0.15) or 0.15
    if lastResetTime and (GetTime() - lastResetTime < cooldown) then
        if services.Debug then
            services.Debug("Quest", "Legacy greeting cooldown active")
        end
        return
    end
    
    if not (safetyEngine and safetyEngine.CanProcess()) then
        if services.OutputHalt then services.OutputHalt("legacy_greeting") end
        return
    end
    
    -- Poll for data if needed (greeting frame visible but no quest data)
    local numActive = GetNumActiveQuests and GetNumActiveQuests() or 0
    local numAvailable = GetNumAvailableQuests and GetNumAvailableQuests() or 0
    
    if (numActive == 0 and numAvailable == 0) and QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsVisible() then
        if not JustQuest._legacyGreetingPolling then
            JustQuest._legacyGreetingPolling = true
            if services.Debug then
                services.Debug("Quest", "Legacy greeting - polling for quest data")
            end
            
            services.PollForLegacyQuestData(
                10,
                function()
                    JustQuest._legacyGreetingPolling = nil
                    QuestEngine.ProcessLegacyQuestGreeting()
                end,
                function()
                    JustQuest._legacyGreetingPolling = nil
                    if services.Debug then
                        services.Debug("Quest", "Legacy greeting data timeout")
                    end
                end
            )
            return
        else
            return  -- Already polling
        end
    end
    
    -- Clear polling flag (data available or frame not visible)
    JustQuest._legacyGreetingPolling = nil
    
    if not StartProcessing() then
        return
    end
    
    -- Priority 1: Process active quests (turn-ins)
    if numActive > 0 then
        for i = 1, numActive do
            local title, isComplete = GetActiveTitle(i)
            if isComplete then
                if services.Debug then
                    services.Debug("Quest", "Legacy turn-in: " .. (title or "Unknown"))
                end
                
                if SelectQuest(SelectActiveQuest, i) then
                    return  -- Wait for next event
                end
            end
        end
    end
    
    -- Priority 2: Process available quests (accepts)
    if numAvailable > 0 then
        for i = 1, numAvailable do
            local isTrivial, frequency, isRepeatable, isLegendary, questID = GetAvailableQuestInfo(i)
            local title = GetAvailableTitle(i)
            
            if questID and safetyEngine.ShouldAcceptQuest(questID, frequency) then
                -- Check if blacklisted
                if services.IsQuestBlocked(questID) then
                    if services.Debug then
                        services.Debug("Quest", "Legacy quest blocked: " .. (title or "Unknown"))
                    end
                else
                    if services.Debug then
                        services.Debug("Quest", "Legacy accept: " .. (title or "Unknown"))
                    end
                    
                    if SelectQuest(SelectAvailableQuest, i) then
                        return  -- Wait for next event
                    end
                end
            end
        end
    end
    
    -- No quests to process - reset
    ResetProcessing()
end

function QuestEngine.OnGossipShow()
    local services = GetServices()
    local safetyEngine = GetSafetyEngine()
    
    if not services then return false end
    
    -- Safety: CanAutomate covers modifier keys, dead/vehicle, interfering frames
    -- DispatchContent already pre-screens but direct calls need this gate too
    if not (safetyEngine and services.CanAutomate() and services.IsAutomationContextAllowed()) then
        return false
    end
    
    -- Start processing (BeginProcessing sets BUSY, prevents re-entry)
    if not StartProcessing() then
        return false
    end
    
    -- Priority 1: Turn-ins
    if ProcessActiveQuests() then
        return true
    end
    
    -- Priority 2: Accepts
    if ProcessAvailableQuests() then
        return true
    end
    
    -- Guard: if available quests were filtered out by safety (blocked, trivial,
    -- already in log, etc.), don't delegate to gossip — selecting a gossip
    -- option could navigate away from the quest list and cause a gossip loop.
    -- Incomplete active quests are NOT a filter reason: the player is expected
    -- to interact with gossip options (e.g. "(Quest)" labeled) while carrying
    -- incomplete quests at that NPC.
    if C_GossipInfo then
        local rawAvailable = services.SafeCall(C_GossipInfo.GetAvailableQuests)
        local filteredAvailable = type(rawAvailable) == "table" and #rawAvailable > 0

        local filteredActive = false
        local rawActive = services.SafeCall(C_GossipInfo.GetActiveQuests)
        if type(rawActive) == "table" then
            for _, quest in ipairs(rawActive) do
                -- An incomplete active quest is normal — only count it as
                -- "filtered" if it IS complete but was blocked/skipped.
                if quest.isComplete then
                    filteredActive = true
                    break
                end
            end
        end

        if filteredAvailable or filteredActive then
            if services.Debug then
                services.Debug("Quest", "Quests present but all filtered - skipping gossip delegation")
            end
            ResetProcessing()
            return false
        end
    end
    
    -- Priority 3: Delegate to gossip
    local gossipEngine = JustQuest.Core.GetModule("GossipEngine")
    if gossipEngine and gossipEngine.OnGossipShow then
        local gossipHandled = gossipEngine.OnGossipShow(true)
        
        if gossipHandled then
            ScheduleFinalRepump()
        else
            ResetProcessing()
        end
        
        return gossipHandled
    end
    
    ResetProcessing()
    return false
end

function QuestEngine.OnQuestLogUpdate()
    local services = GetServices()
    local safetyEngine = GetSafetyEngine()

    -- Don't open popup frames if already processing — single deferred re-check
    if safetyEngine and safetyEngine.IsBusy() then
        if services then
            services.Debug("Quest", "OnQuestLogUpdate deferred: BUSY")
            local delay = services.GetTiming and services.GetTiming("SERVER_SYNC_DELAY", 0.15) or 0.15
            services.CancelScheduled("deferred_onquestlog_update")
            services.ScheduleOnce("deferred_onquestlog_update", delay, function()
                local s = GetSafetyEngine()
                if not (s and s.IsBusy()) then
                    QuestEngine.OnQuestLogUpdate()
                end
                -- SafetyEngine periodic recovery handles truly stuck states
            end)
        end
        return
    end

    if not (GetNumAutoQuestPopUps and services) then
        return
    end
    
    local numPopups = GetNumAutoQuestPopUps()
    if numPopups == 0 then return end
    
    -- Only run full CanAutomate check when there are actually popups to process
    if not services.CanAutomate() then return end
    
    if services.Debug then
        services.Debug("Quest", "Processing " .. numPopups .. " popup quest(s)")
    end
    
    for i = 1, numPopups do
        local questID, popupType = GetAutoQuestPopUp(i)
        if questID then
            -- COMPLETE popups turn in an already-accepted quest: gate on the blocklist
            -- only (ShouldCompleteQuest), NOT accept-type policy. OFFER popups are
            -- accepts, so they keep the full ShouldAcceptQuest gate.
            local shouldProcess
            if popupType == "COMPLETE" then
                shouldProcess = not safetyEngine or safetyEngine.ShouldCompleteQuest(questID)
            else
                shouldProcess = safetyEngine and safetyEngine.ShouldAcceptQuest(questID)
            end

            if services.Debug then
                local questName = "Quest " .. questID
                local gameData = GetGameData()
                if gameData then
                    questName = gameData.GetQuestName and gameData.GetQuestName(questID) or questName
                end
                services.Debug("Quest", string.format("Popup %s (%s): %s",
                    questName, popupType or "UNKNOWN", shouldProcess and "PROCESS" or "SKIP"))
            end

            if shouldProcess then
                if popupType == "COMPLETE" then
                    services.SafeCall(ShowQuestComplete, questID)
                elseif popupType == "OFFER" then
                    services.SafeCall(ShowQuestOffer, questID)
                end
            end

            -- Only clear a popup we actually had (questID nil = no popup at this index).
            services.SafeCall(RemoveAutoQuestPopUp, questID)
        end
    end
end

function QuestEngine.OnQuestDetail()
    local services = GetServices()
    local safetyEngine = GetSafetyEngine()
    
    if not services then return end
    
    -- Safety: Single validation gate
    if not services.CanAutomate() then return end

    local questTitle = GetTitleText and GetTitleText() or "Unknown Quest"
    local questID = GetQuestID and GetQuestID() or 0

    if services.Debug then
        services.Debug("Quest", string.format("QUEST_DETAIL: %s (ID: %d)", questTitle, questID))
    end

    -- Validate quest against safety filters (PvP, escort, blacklist, etc.)
    -- Without this, quests that open QUEST_DETAIL directly (e.g. via gossip
    -- quest-type options, items, or proximity triggers) bypass ShouldAcceptQuest.
    if questID and questID > 0 and safetyEngine then
        if not safetyEngine.ShouldAcceptQuest(questID) then
            if services.Debug then
                services.Debug("Quest", string.format("QUEST_DETAIL blocked by ShouldAcceptQuest: %s (ID: %d)", questTitle, questID))
            end
            return
        end
    end

    -- Block if 3+ player choices shown — manual selection required
    if PlayerChoiceFrame and PlayerChoiceFrame:IsShown() then
        if C_PlayerChoice and C_PlayerChoice.GetCurrentPlayerChoiceInfo then
            local choiceInfo = C_PlayerChoice.GetCurrentPlayerChoiceInfo()
            if choiceInfo and choiceInfo.options and #choiceInfo.options >= 3 then
                return
            end
        end
    end

    -- Quests from object/item interactions (QuestIsFromAreaTrigger):
    -- Allow if a PlayerChoice was just shown, or if quest.acceptQuestItems is enabled.
    if QuestIsFromAreaTrigger and QuestIsFromAreaTrigger() then
        local recentPlayerChoice = JustQuest._lastPlayerChoiceTime and
                                   (GetTime() - JustQuest._lastPlayerChoiceTime) < JustQuest.Constants.TIMING.REINTERACT_QUEST_WINDOW

        if recentPlayerChoice then
            JustQuest._lastPlayerChoiceTime = nil
        else
            local config = GetConfig()
            local allowQuestItems = config and config.Get("quest", "acceptQuestItems")
            if allowQuestItems == nil then allowQuestItems = true end  -- default on

            if not allowQuestItems then
                return
            end
        end
    end
    
    -- Auto-accept quests are already accepted server-side (we just close). For a real
    -- accept, honor the authoritative full-log signal and don't re-attempt a doomed
    -- accept — that just re-fires WoW's "quest log is full" error. The flag clears on
    -- QUEST_REMOVED. (We don't probe the quest count: it includes campaign/world/calling
    -- quests that don't count toward the cap, so it reads false-full, e.g. 40/35 at 32/35.)
    local autoAccept = QuestGetAutoAccept and QuestGetAutoAccept()
    if questLogFull and not autoAccept then
        if services.Debug then services.Debug("Quest", "Skipping accept — quest log full") end
        if safetyEngine then safetyEngine.EndProcessing("quest_log_full") end
        return
    end

    -- Ensure BUSY state for quest processing.
    -- May already be BUSY (from OnGossipShow) or IDLE (direct quest open via item/proximity).
    if safetyEngine then
        safetyEngine.SetState("BUSY", "accepting_quest")
    end

    -- Accept quest.
    if autoAccept then
        services.SafeCall(CloseQuest)
    else
        services.SafeCall(AcceptQuest)
    end

    -- The accept is async — QUEST_ACCEPTED is the real confirmation (it clears the
    -- attempt tracker on success). Don't poll IsOnQuest here: the round-trip hasn't
    -- completed, so it reports false failures even when the accept worked.
    if services.Debug then
        services.Debug("Quest", string.format("Issued %s for %s (ID: %d)",
            autoAccept and "CloseQuest (auto-accept)" or "AcceptQuest", questTitle, questID))
    end

    -- Track this attempt to prevent race-condition re-accept loops.
    if questID and questID > 0 then
        recentAcceptAttempts[questID] = GetTime()
    end

    JustQuest._lastProcessingTime = GetTime()

    -- Reset to IDLE so GOSSIP_SHOW fires for the next quest.
    if safetyEngine then
        safetyEngine.EndProcessing("quest_accept_action_complete")
    end
end

function QuestEngine.OnQuestProgress()
    local services = GetServices()
    local safetyEngine = GetSafetyEngine()

    if not (services and services.CanAutomate()) then return end

    -- IsQuestCompletable() checks UI state; C_QuestLog.IsComplete() validates objectives
    local questID = GetQuestID and GetQuestID()
    local isComplete = false
    
    if questID and C_QuestLog and C_QuestLog.IsComplete then
        local success, result = pcall(C_QuestLog.IsComplete, questID)
        isComplete = success and result
    end
    
    if not isComplete and IsQuestCompletable then
        -- Fallback if C_QuestLog.IsComplete fails
        isComplete = IsQuestCompletable()
    end
    
    if isComplete then
        -- Guard: required items — halt unless ALL are quest-class items (classID 12).
        -- Quest items (pelts, vials, stolen plans) are expected consumables. Trade
        -- materials, crafted items, or uncached items are not safe to auto-consume.
        -- MUST run before the currency prompt below: the popup's Spend path calls
        -- CompleteQuest directly, so an unsafe item has to halt here or it would be
        -- consumed silently after the player only approved the currency.
        local numItems = GetNumQuestItems and GetNumQuestItems() or 0
        if numItems > 0 then
            local IC = JustQuest.Constants.ITEM_CLASS
            for i = 1, numItems do
                local hidden = IsQuestItemHidden and IsQuestItemHidden(i) or 0
                if hidden == 0 then  -- only inspect visible required items
                    local itemLink = GetQuestItemLink and GetQuestItemLink("required", i)
                    if itemLink then
                        local classID = select(12, GetItemInfo(itemLink))
                        if classID == nil or classID ~= IC.QUESTITEM then
                            if services.Debug then
                                services.Debug("Quest", "Quest requires non-quest item (classID=" .. tostring(classID) .. ") — halting for manual confirmation")
                            end
                            if services.OutputHalt then services.OutputHalt("quest_requires_trade_items") end
                            if safetyEngine then safetyEngine.EndProcessing("quest_requires_trade_items") end
                            return
                        end
                    else
                        -- Item link not in client cache; cannot verify — halt to be safe.
                        if services.Debug then
                            services.Debug("Quest", "Required item link not cached — halting for manual confirmation")
                        end
                        if services.OutputHalt then services.OutputHalt("quest_requires_uncached_items") end
                        if safetyEngine then safetyEngine.EndProcessing("quest_requires_uncached_items") end
                        return
                    end
                end
            end
        end

        -- Guard: required currencies — check whitelist, then prompt if not already allowed.
        -- Currencies (Flightstones, Resonance Crystals, Honor, etc.) are consumed by CompleteQuest().
        local numCurrencies = GetNumQuestCurrencies and GetNumQuestCurrencies() or 0
        if numCurrencies > 0 then
            -- questID already resolved above; nil means we cannot whitelist — halt safely
            if not questID then
                if services.Debug then
                    services.Debug("Quest", "Quest requires currencies but questID is nil — halting for manual confirmation")
                end
                if services.OutputHalt then services.OutputHalt("quest_requires_currency") end
                if safetyEngine then safetyEngine.EndProcessing("quest_requires_currency") end
                return
            end

            local config = GetConfig()
            local whitelist = config and config.GetCurrencyQuestWhitelist and config.GetCurrencyQuestWhitelist() or {}

            if not whitelist[questID] then
                -- Build the currency list for the popup
                local currencyLines = {}
                for i = 1, numCurrencies do
                    local ok, info = pcall(function()
                        return C_QuestOffer and C_QuestOffer.GetQuestRequiredCurrencyInfo
                               and C_QuestOffer.GetQuestRequiredCurrencyInfo(i)
                    end)
                    if ok and info then
                        tinsert(currencyLines, string.format("  %dx %s", info.requiredAmount or 1, info.name or "?"))
                    end
                end
                local currencyText = #currencyLines > 0 and table.concat(currencyLines, "\n") or "Unknown currencies"
                local questTitle = GetTitleText and GetTitleText() or "Unknown Quest"

                if services.Debug then
                    services.Debug("Quest", "Quest requires currencies — showing confirmation prompt")
                end
                if not safetyEngine then
                    if services.OutputHalt then services.OutputHalt("quest_requires_currency") end
                    return
                end
                local isRepeatable = C_QuestLog and C_QuestLog.IsRepeatableQuest
                                     and C_QuestLog.IsRepeatableQuest(questID)
                local dialogKey = isRepeatable and "JUSTQUEST_CONFIRM_CURRENCY"
                                               or "JUSTQUEST_CONFIRM_CURRENCY_ONCE"
                safetyEngine.SetState("BUSY", "waiting_currency_prompt")
                StaticPopup_Show(dialogKey, questTitle, currencyText, {
                    questID = questID,
                    questTitle = questTitle,
                    currencyText = currencyText,
                })
                return
            end

            -- Whitelisted: fall through to CompleteQuest below
            if services.Debug then
                services.Debug("Quest", "Quest " .. tostring(questID) .. " is currency-whitelisted — proceeding")
            end
        end

        -- Ensure BUSY state before calling CompleteQuest.
        -- Prevents repumps/DispatchContent from starting new processing mid-turn-in.
        if safetyEngine then
            safetyEngine.SetState("BUSY", "completing_quest")
        end

        if services.Debug then
            services.Debug("Quest", "OnQuestProgress: quest is completable; attempting turn-in")
        end
        
        services.SafeCall(CompleteQuest)

        JustQuest._stats.completeActions = (JustQuest._stats.completeActions or 0) + 1
        JustQuest._lastProcessingTime = GetTime()

        if services.Debug then
            services.Debug("Quest", "Called CompleteQuest()")
        end
    else
        if services.Debug then
            services.Debug("Quest", "Quest not completable - skipping turn-in")
        end
    end
end

-- Flag any whitelisted-container rewards so ContainerEngine opens them as soon
-- as they land in bags. itemType is "choice" (selectable) or "reward" (guaranteed).
local function ExpectWhitelistedContainers(containerEngine, itemType, count)
    if count == 0 then return end
    local config = GetConfig()
    local whitelist = config and (config.Get("containers", "whitelist") or {}) or {}
    for i = 1, count do
        local ok, name, _, _, _, _, itemID = pcall(GetQuestItemInfo, itemType, i)
        if ok and itemID and whitelist[itemID] then
            if not name or name == "" then
                name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID))
                       or ("Item " .. tostring(itemID))
            end
            containerEngine.ExpectContainer(itemID, name)
        end
    end
end

function QuestEngine.OnQuestComplete()
    local services = GetServices()
    local rewardEngine = JustQuest.Core.GetModule("RewardEngine")
    local containerEngine = JustQuest.Core.GetModule("ContainerEngine")
    
    if not (services and services.CanAutomate()) then return end

    -- Per-quest debounce: prevent duplicate processing of the same quest.
    -- Global debounce would accidentally skip a DIFFERENT quest's QUEST_COMPLETE
    -- if two quests are turned in rapidly (e.g., multi-turnin NPC).
    local questID = GetQuestID and GetQuestID() or 0
    local now = GetTime()
    -- Only debounce on a real (nonzero) ID: two different turn-ins that both report
    -- questID 0 within the window must not be treated as the same quest.
    if questID ~= 0 and QuestEngine._lastQuestCompleteID == questID and
       QuestEngine._lastQuestCompleteTime and (now - QuestEngine._lastQuestCompleteTime) < 0.5 then
        if services and services.Debug then
            services.Debug("Quest", "OnQuestComplete: Skipped duplicate (debounced, questID=" .. tostring(questID) .. ")")
        end
        return
    end
    QuestEngine._lastQuestCompleteID = questID
    QuestEngine._lastQuestCompleteTime = now
    
    -- Ensure BUSY state before processing rewards.
    -- Prevents repumps/DispatchContent from starting new processing mid-reward-selection.
    local safetyEngine = GetSafetyEngine()
    if safetyEngine then
        safetyEngine.SetState("BUSY", "processing_reward")
    end

    if services and services.Debug then
        services.Debug("Quest", "OnQuestComplete event received (questID=" .. tostring(questID) .. ")")
    end
    
    -- Scan rewards for whitelisted containers
    if containerEngine and containerEngine.ExpectContainer then
        ExpectWhitelistedContainers(containerEngine, "choice", GetNumQuestChoices and GetNumQuestChoices() or 0)
        ExpectWhitelistedContainers(containerEngine, "reward", GetNumQuestRewards and GetNumQuestRewards() or 0)
    end
    
    if rewardEngine and rewardEngine.ProcessQuestReward then
        JustQuest._lastProcessingTime = GetTime()
        if services.Debug then
            services.Debug("Quest", "OnQuestComplete: calling ProcessQuestReward")
        end
        rewardEngine.ProcessQuestReward()
        -- RewardEngine manages state reset after processing
    else
        -- Fallback: no reward engine, just select reward. Release BUSY here since
        -- nothing else owns the reset on this path (QUEST_TURNED_IN normally does,
        -- but don't rely on it if GetQuestReward silently fails).
        local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
        services.SafeCall(GetQuestReward, numChoices == 1 and 1 or nil)
        if safetyEngine then safetyEngine.EndProcessing("quest_turned_in") end
    end
end

function QuestEngine.OnQuestAutoComplete(questID)
    local services = GetServices()
    local safetyEngine = GetSafetyEngine()
    
    -- QUEST_AUTOCOMPLETE is a turn-in of an already-accepted quest — gate it on the
    -- completion check (blocklist only), not accept-type policy.
    if services and services.CanAutomate() and
       type(questID) == "number" and
       (not safetyEngine or safetyEngine.ShouldCompleteQuest(questID)) then
        services.SafeCall(ShowQuestComplete, questID)
    end
end

-- ============================================================
-- Event-Driven Enhancement Handlers
-- ============================================================

function QuestEngine.OnQuestAcceptConfirm(questGiver, questTitle)
    -- QUEST_ACCEPT_CONFIRM fires when another player shares an escort/group quest
    local services = GetServices()
    local config = GetConfig()
    
    if not services or not services.CanAutomate() then
        return
    end

    local acceptEscort = config and config.Get("quest", "acceptEscort")
    
    if services.Debug then
        services.Debug("Quest", string.format("QUEST_ACCEPT_CONFIRM: '%s' from %s (acceptEscort=%s)", 
            tostring(questTitle), tostring(questGiver), tostring(acceptEscort)))
    end
    
    if acceptEscort then
        services.SafeCall(ConfirmAcceptQuest)
        
        if services.Debug then
            services.Debug("Quest", "Auto-accepted escort/shared quest: " .. tostring(questTitle))
        end
    else
        if services.Debug then
            services.Debug("Quest", "Escort quest declined (acceptEscort=false)")
        end
    end
end

function QuestEngine.OnQuestItemUpdate()
    -- QUEST_ITEM_UPDATE fires when quest item data loads asynchronously —
    -- re-evaluate the current quest frame in case rewards weren't cached yet.
    local services = GetServices()
    
    if not services or not services.CanAutomate() then
        return
    end

    -- Only re-trigger if a quest frame is visible
    if QuestFrameDetailPanel and QuestFrameDetailPanel:IsShown() then
        if services.Debug then
            services.Debug("Quest", "QUEST_ITEM_UPDATE: Re-evaluating quest detail panel")
        end
        QuestEngine.OnQuestDetail()
    elseif QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown() then
        if services.Debug then
            services.Debug("Quest", "QUEST_ITEM_UPDATE: Re-evaluating quest reward panel")
        end
        QuestEngine.OnQuestComplete()
    elseif QuestFrameProgressPanel and QuestFrameProgressPanel:IsShown() then
        if services.Debug then
            services.Debug("Quest", "QUEST_ITEM_UPDATE: Re-evaluating quest progress panel")
        end
        QuestEngine.OnQuestProgress()
    end
end

function QuestEngine.OnQuestDataLoadResult(questID, success)
    -- QUEST_DATA_LOAD_RESULT fires frequently for all quests in the log —
    -- only act if gossip is open and data may affect available quest visibility.
    local services = GetServices()
    if not services then return end

    -- This event fires for every quest in the log, but we only care while gossip is
    -- open — check that cheap condition before the fuller CanAutomate() gate.
    if not (GossipFrame and GossipFrame:IsShown()) then
        return
    end

    if not services.CanAutomate() then
        return
    end

    if not success then
        return
    end
    
    -- Deduplicate: skip if we've already pumped recently
    local now = GetTime()
    if QuestEngine._lastDataLoadPump and (now - QuestEngine._lastDataLoadPump) < 0.5 then
        return
    end
    QuestEngine._lastDataLoadPump = now
    
    -- Pump quest check to re-evaluate with new data
    if services.PumpQuestCheck then
        services.PumpQuestCheck("quest_data_loaded", 0.1)
    end
end

-- ============================================================
-- Player Choice Handlers (Quest Type Selection)
-- ============================================================

function QuestEngine.OnPlayerChoiceUpdate()
    -- Player choice window is intentionally NOT automated — user makes the manual
    -- selection, which then triggers QUEST_DETAIL that we can automate.
    JustQuest._lastPlayerChoiceTime = GetTime()
    
    local services = GetServices()
    if services then
        services.Debug("Quest", "PlayerChoiceFrame shown - tracking for subsequent quest automation")
    end
end

function QuestEngine.OnPlayerChoiceClose()
    -- Keep timestamp for a short window so the resulting QUEST_DETAIL can be automated
    local services = GetServices()
    if services then
        services.Debug("Quest", "PlayerChoiceFrame closed - quest acceptance will be automated")
    end
    ResetProcessing()
end

-- ============================================================
-- Module API
-- ============================================================

function QuestEngine.OnDisable()
    ResetProcessing()
    questLogFull = false
    if errorEventFrame then
        errorEventFrame:UnregisterAllEvents()
    end
end

function QuestEngine.ResetWorkflow()
    ResetProcessing()
end

-- Clear recent accept tracking for a successfully accepted quest
function QuestEngine.OnQuestAcceptedSuccess(questID)
    if questID then
        recentAcceptAttempts[questID] = nil
    end
    
    -- Also prune old entries (> 60s) to prevent memory growth
    local now = GetTime()
    for id, timestamp in pairs(recentAcceptAttempts) do
        if (now - timestamp) > 60 then
            recentAcceptAttempts[id] = nil
        end
    end
end

-- ============================================================
-- Initialization
-- ============================================================

function QuestEngine.Initialize()
    -- Listen for the authoritative full-log signal and the slot-freed signal.
    errorEventFrame = errorEventFrame or CreateFrame("Frame")
    errorEventFrame:RegisterEvent("UI_ERROR_MESSAGE")
    errorEventFrame:RegisterEvent("QUEST_REMOVED")
    errorEventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
        if event == "UI_ERROR_MESSAGE" then
            -- arg1 = numeric error type, arg2 = localized message. Match either so
            -- it works whether or not LE_GAME_ERR_QUEST_LOG_FULL is defined.
            local isFull = (QUEST_LOG_FULL_ERR and arg1 == QUEST_LOG_FULL_ERR)
                        or (arg2 ~= nil and arg2 == ERR_QUEST_LOG_FULL)
            if isFull and not questLogFull then
                questLogFull = true
                local services = GetServices()
                if services then
                    if services.OutputHalt then services.OutputHalt("quest_log_full") end
                    if services.Debug then services.Debug("Quest", "ERR_QUEST_LOG_FULL — pausing accepts until a quest is removed") end
                end
            end
        elseif event == "QUEST_REMOVED" then
            -- A quest left the log: a slot may have freed, so resume accepts.
            if questLogFull then
                questLogFull = false
                local services = GetServices()
                if services and services.Debug then services.Debug("Quest", "Quest removed — resuming accepts") end
            end
        end
    end)
end

-- ============================================================
-- Module Registration
-- ============================================================

JustQuest.Core.RegisterModule("QuestEngine", QuestEngine, {"Services", "Config", "SafetyEngine", "GameData", "RewardEngine"})

return QuestEngine
