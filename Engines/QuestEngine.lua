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
-- Turn-ins need the same memory as accepts. The server can silently refuse one (missing
-- gold, phasing, a group requirement) with no event back, so without this the same
-- always-first-in-sort quest was re-selected every recovery tick and the other
-- completable quests at that NPC were never reached.
local recentTurnInAttempts = {}

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

-- These handlers are entered BUSY — the gossip pass owns the state transition, not them —
-- so an early return has to release it, or an interfering frame opening mid-chain strands
-- BUSY until the recovery timer notices. Deliberately a small helper and NOT a wrapper
-- around each handler: the reason string is load-bearing (SafetyEngine keys frame-restore
-- and repump decisions off it), and a wrapper could only supply a generic one.
local function BailedOnAutomate(services, reason)
    if services and services.CanAutomate() then return false end
    local safetyEngine = GetSafetyEngine()
    if safetyEngine then safetyEngine.EndProcessing(reason) end
    return true
end

-- A deliberate "leave this one for the player" from a quest-frame handler. Same release
-- as above: drop any BUSY inherited from the gossip pass and un-hide the fast-mode frame
-- now, instead of leaving it invisible until periodic recovery notices.
local function LeaveForPlayer(reason)
    local safetyEngine = GetSafetyEngine()
    if safetyEngine then safetyEngine.EndProcessing(reason) end
end

-- One filter for "is there quest work here", run once and early by everything that asks:
-- this engine's own pass, dispatch routing, fast-mode hiding, and the gossip gates. A quest
-- the addon will never act on is dropped here and treated as ABSENT downstream, so it can't
-- hold up the vendor / dialog at the same NPC (it used to: any listed quest, even one we'd
-- filtered, stopped gossip handling cold). Returns why a quest is skipped, nil if actionable.
-- "pending" is the one exception that still counts: our own accept/turn-in of it is in
-- flight, so the server is still answering — see OnGossipShow.
local function ActiveSkipReason(quest)
    if not quest.isComplete then return "not complete" end
    local services = GetServices()
    if services and services.IsQuestBlocked(quest.questID) then return "blacklisted" end
    -- Recently attempted and it didn't take: move on to the next completable quest instead of
    -- re-selecting this one forever.
    local lastAttempt = recentTurnInAttempts[quest.questID]
    if lastAttempt and (GetTime() - lastAttempt) < ACCEPT_ATTEMPT_TTL then return "pending" end
end

local function AvailableSkipReason(quest)
    local questID = quest.questID
    -- Log full: accepts pause until a slot frees (turn-ins still run and free one).
    if questLogFull then return "quest log full" end
    local services = GetServices()
    if services and services.IsQuestBlocked(questID) then return "blacklisted" end
    if C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(questID) then return "already in log" end
    local lastAttempt = recentAcceptAttempts[questID]
    if lastAttempt and (GetTime() - lastAttempt) < ACCEPT_ATTEMPT_TTL then return "pending" end

    if quest.isTrivial then
        local config = GetConfig()
        if not (config and config.Get("quest", "acceptTrivial")) then return "trivial" end
    end

    if quest.isIgnored then return "ignored in quest log" end
    if C_QuestLog.IsQuestIgnored then
        local ok, ignored = pcall(C_QuestLog.IsQuestIgnored, questID)
        if ok and ignored then return "ignored in quest log" end
    end

    -- Already completed, unless repeatable. frequency is set on EVERY quest (Default = 0, which
    -- Lua treats as true), so it has to be compared, not truth-tested.
    if C_QuestLog.IsQuestFlaggedCompleted then
        local ok, completed = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
        local defaultFreq = Enum and Enum.QuestFrequency and Enum.QuestFrequency.Default or 0
        local repeatable = quest.repeatable or (quest.frequency and quest.frequency ~= defaultFreq)
        if ok and completed and not repeatable then return "already completed" end
    end

    local safetyEngine = GetSafetyEngine()
    if safetyEngine and not safetyEngine.ShouldAcceptQuest(questID, quest.frequency) then
        return "quest type turned off"
    end
end

-- rawActive / rawAvailable are optional (fetched when nil). log = print why each was skipped.
-- Returns active, available (actionable only), pending.
function QuestEngine.GetActionableQuests(rawActive, rawAvailable, log)
    local services = GetServices()
    local active, available, pending = {}, {}, false

    local function sift(list, skipReason, out)
        if type(list) ~= "table" then return end
        for _, quest in ipairs(list) do
            local why = quest.questID and skipReason(quest) or (not quest.questID and "no questID") or nil
            if not why then
                out[#out + 1] = quest
            else
                if why == "pending" then pending = true end
                if log and services and services.Debug then
                    services.Debug("Quest", "Skip " .. (quest.title or tostring(quest.questID)) .. ": " .. why)
                end
            end
        end
    end

    sift(rawActive or (services and services.SafeCall(C_GossipInfo.GetActiveQuests)), ActiveSkipReason, active)
    sift(rawAvailable or (services and services.SafeCall(C_GossipInfo.GetAvailableQuests)), AvailableSkipReason, available)
    return active, available, pending
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

-- Both take the already-filtered lists from GetActionableQuests.
local function ProcessActiveQuests(visible)
    if #visible == 0 then return false end
    local services = GetServices()

    -- Sort by priority (skip sort for single quest)
    if #visible > 1 then
        -- Precompute account-completion status to avoid O(n log n) pcalls
        -- inside the sort comparator.
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

        recentTurnInAttempts[quest.questID] = GetTime()
        if SelectQuest(C_GossipInfo.SelectActiveQuest, quest.questID) then
            return true
        end
    end

    return false
end

local function ProcessAvailableQuests(visible)
    if #visible == 0 then return false end
    local services = GetServices()

    -- Sort by priority (skip sort for single quest)
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
            -- The step we took never landed (the poll stopped on it as "handled"), so
            -- nothing else is looking: look again rather than leave the next quest sitting.
            services.ScheduleContentCheck(0.05, "processing_timeout")
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
            services.Debug("Quest", "Legacy greeting cooldown active - looking again after it")
        end
        -- Defer, don't drop: a greeting re-sent right after a turn-in lands inside this
        -- window, and nothing else would come back for it.
        services.ScheduleContentCheck(cooldown - (GetTime() - lastResetTime) + 0.01, "legacy_greeting_cooldown")
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

-- rawActive / rawAvailable: optional, the lists the dispatch poll already read this tick.
-- Returns handled, waiting. waiting = deliberately holding for content still on its way, so
-- the poll should keep looking every tick rather than file this menu as judged.
function QuestEngine.OnGossipShow(rawActive, rawAvailable)
    local services = GetServices()
    local safetyEngine = GetSafetyEngine()
    
    if not services then return false end
    
    -- Safety: CanAutomate covers modifier keys, dead/vehicle, interfering frames
    -- DispatchContent already pre-screens but direct calls need this gate too
    if not (safetyEngine and services.CanAutomate() and services.IsAutomationContextAllowed()) then
        return false
    end
    
    -- Filter once, up front: everything below sees only quests we will actually act on.
    local active, available, pending = QuestEngine.GetActionableQuests(rawActive, rawAvailable, JustQuest._debugMode)

    if #active == 0 and #available == 0 then
        -- Our own accept/turn-in here is still in flight (or the server quietly refused it):
        -- wait for its answer rather than wandering into gossip mid-step.
        -- Or: a turn-in/accept JUST happened and this menu has no quest yet. The follow-up
        -- usually lands within a few seconds of the menu re-showing; delegating to gossip now
        -- walks off to the vendor or a chatter branch and leaves the menu it was coming to.
        -- Quests we merely won't act on (blocked, trivial, type off, log full, not complete)
        -- were dropped above and hold nothing.
        local sinceProgress = GetTime() - (JustQuest._lastProgressTime or 0)
        local followUpWindow = sinceProgress < (JustQuest.Constants.TIMING.RE_PUMP_TOTAL_TIME or 3.5)
        if pending or followUpWindow then
            if services.Debug then
                services.Debug("Quest", pending and "Quest step still in flight - holding gossip"
                    or string.format("No quest yet %.1fs after a turn-in/accept - holding gossip for the follow-up", sinceProgress))
            end
            JustQuest._lastProcessingTime = GetTime()  -- still working: keep a hidden frame hidden
            return false, true
        end
    end

    -- Start processing (BeginProcessing sets BUSY, prevents re-entry)
    if not StartProcessing() then
        return false
    end

    -- Priority 1: Turn-ins
    if ProcessActiveQuests(active) then
        return true
    end

    -- Priority 2: Accepts
    if ProcessAvailableQuests(available) then
        return true
    end

    -- Priority 3: Delegate to gossip
    local gossipEngine = JustQuest.Core.GetModule("GossipEngine")
    if gossipEngine and gossipEngine.OnGossipShow then
        local gossipHandled = gossipEngine.OnGossipShow(true)
        
        -- Handled means an option was selected, and SelectOption already queued the
        -- (seeded) re-check for whatever it unlocks. A second, unseeded one here would
        -- merge into it and re-judge the stale menu.
        if not gossipHandled then
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

    -- Don't open popup frames if already processing — one deferred re-check. Popups are the
    -- only thing this handler acts on, so with none there's nothing to defer; and with one
    -- already pending, a burst of QUEST_LOG_UPDATEs (a turn-in fires several) no longer
    -- tears down and rebuilds the timer on every event. The re-check re-defers itself while
    -- still BUSY, so a popup is never dropped (BUSY is bounded by periodic recovery).
    if safetyEngine and safetyEngine.IsBusy() then
        if services and GetNumAutoQuestPopUps and GetNumAutoQuestPopUps() > 0
           and not services.IsScheduled("deferred_onquestlog_update") then
            services.Debug("Quest", "OnQuestLogUpdate deferred: BUSY")
            local delay = services.GetTiming and services.GetTiming("SERVER_SYNC_DELAY", 0.15) or 0.15
            services.ScheduleOnce("deferred_onquestlog_update", delay, QuestEngine.OnQuestLogUpdate)
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

            -- Removal belongs INSIDE the branch. Clearing a popup we deliberately
            -- declined destroyed the player's own "click here to accept" button along
            -- with it — a filter that should only mean "don't automate this" was
            -- silently losing the quest instead. A popup we don't act on stays for them.
            if shouldProcess then
                if popupType == "COMPLETE" then
                    services.SafeCall(ShowQuestComplete, questID)
                elseif popupType == "OFFER" then
                    services.SafeCall(ShowQuestOffer, questID)
                end
                services.SafeCall(RemoveAutoQuestPopUp, questID)
                -- One per pass: the quest frame holds a single quest, so opening a second
                -- here replaced the first while both popups were removed — losing it. The
                -- turn-in/accept fires QUEST_LOG_UPDATE again for the next one.
                return
            end
        end
    end
end

function QuestEngine.OnQuestDetail()
    local services = GetServices()
    local safetyEngine = GetSafetyEngine()
    
    if not services then return end
    
    if BailedOnAutomate(services, "quest_detail_cannot_automate") then return end

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
            LeaveForPlayer("quest_detail_declined")
            return
        end
    end

    -- Block if 3+ player choices shown — manual selection required
    if PlayerChoiceFrame and PlayerChoiceFrame:IsShown() then
        if C_PlayerChoice and C_PlayerChoice.GetCurrentPlayerChoiceInfo then
            local choiceInfo = C_PlayerChoice.GetCurrentPlayerChoiceInfo()
            if choiceInfo and choiceInfo.options and #choiceInfo.options >= 3 then
                LeaveForPlayer("quest_detail_player_choice")
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
                LeaveForPlayer("quest_detail_item_quest_off")
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

    if BailedOnAutomate(services, "quest_progress_cannot_automate") then return end

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
                    -- GetItemInfoInstant answers the class from static client data, with no
                    -- server lookup: GetItemInfo returned nothing for an item the client hadn't
                    -- loaded yet, which halted the first turn-in that ever asked for it.
                    local item = (GetQuestItemLink and GetQuestItemLink("required", i))
                              or (GetQuestItemInfo and select(6, GetQuestItemInfo("required", i)))
                    if item then
                        local classID = select(6, C_Item.GetItemInfoInstant(item))
                        if classID == nil or classID ~= IC.QUESTITEM then
                            if services.Debug then
                                services.Debug("Quest", "Quest requires non-quest item (classID=" .. tostring(classID) .. ") — halting for manual confirmation")
                            end
                            if services.OutputHalt then services.OutputHalt("quest_requires_trade_items") end
                            if safetyEngine then safetyEngine.EndProcessing("quest_requires_trade_items") end
                            return
                        end
                    else
                        -- No link and no item ID at all: cannot verify — halt to be safe.
                        if services.Debug then
                            services.Debug("Quest", "Required item unidentifiable — halting for manual confirmation")
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
                -- This state is exempt from stuck-state recovery (the wait on the player
                -- is open-ended), so it is only safe while the popup is actually up.
                -- StaticPopup_Show returns nil when all four slots are taken or the
                -- player is dead — with the return ignored, that was a BUSY nothing
                -- could ever clear short of /reload.
                local shown = StaticPopup_Show(dialogKey, questTitle, currencyText, {
                    questID = questID,
                    questTitle = questTitle,
                    currencyText = currencyText,
                })
                if not shown then
                    if services.OutputHalt then services.OutputHalt("quest_requires_currency") end
                    safetyEngine.EndProcessing("currency_prompt_unavailable")
                end
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
        LeaveForPlayer("quest_not_completable")
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
    
    if BailedOnAutomate(services, "quest_complete_cannot_automate") then return end

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
        rewardEngine.ProcessQuestReward(true)  -- a fresh reward panel: fresh data wait
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

-- QUEST_ACCEPT_CONFIRM: a party member started a shared (escort/group) quest. Since 12.0.5 the
-- event carries the questID, so it goes through the SAME accept filter as every other quest
-- (blocklist, quest-type settings, account-completed, already in log) instead of trusting the
-- escort toggle alone. Anything we pass on stays on the game's own popup for the player.
function QuestEngine.OnQuestAcceptConfirm(questGiver, questTitle, questID)
    local services = GetServices()
    local config = GetConfig()
    local safetyEngine = GetSafetyEngine()

    -- Not CanAutomate: that refuses whenever a StaticPopup is up, and the game shows its
    -- own QUEST_ACCEPT popup for this very event, so the gate could never pass.
    if not services or UnitIsDeadOrGhost("player") or services.InSpecialControlState()
       or not services.ShouldAutomate() or not services.IsAutomationEnabled() then
        return
    end

    local function pass(why)
        if services.Debug then
            services.Debug("Quest", string.format("Shared quest '%s' from %s left for you: %s",
                tostring(questTitle), tostring(questGiver), why))
        end
    end

    if not (config and config.Get("quest", "acceptEscort")) then return pass("shared quests turned off") end
    -- The game swaps in a "log full" popup instead; confirming would fail anyway.
    if questLogFull or (StaticPopup_Visible and StaticPopup_Visible("QUEST_ACCEPT_LOG_FULL")) then
        return pass("quest log full")
    end
    if type(questID) == "number" and questID > 0 then
        if C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(questID) then return pass("already in log") end
        if safetyEngine and not safetyEngine.ShouldAcceptQuest(questID) then
            return pass("blocked or quest type turned off")
        end
    end

    services.SafeCall(ConfirmAcceptQuest)
    StaticPopup_Hide("QUEST_ACCEPT")
    if services.Debug then
        services.Debug("Quest", "Accepted shared quest: " .. tostring(questTitle) .. " (ID: " .. tostring(questID) .. ")")
    end
end

function QuestEngine.OnQuestItemUpdate()
    -- QUEST_ITEM_UPDATE fires when quest item data loads asynchronously —
    -- re-evaluate the current quest frame in case rewards weren't cached yet.
    local services = GetServices()
    
    if not services or not services.CanAutomate() then
        return
    end

    -- Only re-trigger if a quest frame is visible. Not the detail panel: accepting reads no
    -- item data, so a re-run there could only fire a second AcceptQuest.
    if QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown() then
        local rewardEngine = JustQuest.Core.GetModule("RewardEngine")
        if rewardEngine and rewardEngine.IsWaitingForItemData and rewardEngine.IsWaitingForItemData() then
            -- The data the reward pick is waiting on just arrived: look now instead of waiting
            -- out the poll. (OnQuestComplete's duplicate guard would swallow this.)
            if services.Debug then
                services.Debug("Quest", "QUEST_ITEM_UPDATE: reward data arrived - re-checking now")
            end
            rewardEngine.ProcessQuestReward()
            return
        end
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
    
    -- No dedupe needed: requests merge into the one pending pass. (A 0.5s dedupe here used to
    -- drop the load that actually completed the list.)
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

-- Clear turn-in tracking once the turn-in actually lands.
function QuestEngine.OnQuestTurnedInSuccess(questID)
    if questID then
        recentTurnInAttempts[questID] = nil
    end

    local now = GetTime()
    for id, timestamp in pairs(recentTurnInAttempts) do
        if (now - timestamp) > 60 then
            recentTurnInAttempts[id] = nil
        end
    end

    QuestEngine.WatchForFollowUp()
end

-- ============================================================
-- Follow-up cue
-- ============================================================
-- After a turn-in it is the CLIENT that decides whether to reopen the NPC, from three bits the
-- server sends with the completion (LaunchGossip / UseQuestReward / LaunchQuest). LaunchQuest
-- reflects the NPC's quest status AT THAT INSTANT — so a follow-up that becomes available a
-- moment after the turn-in arrives on an NPC nobody is talking to any more. Addons can't
-- reopen it (InteractUnit / ReopenInteraction need a real key press), so the next best thing:
-- say it's there. One press of the Interact key and automation takes over again.
local FOLLOWUP_WATCH  = 8     -- seconds after the turn-in
local FOLLOWUP_RADIUS = 20    -- yards between you and the quest's start point
-- Only once the dialog has stayed closed this long: a re-show between windows is the client
-- reopening on its own, and automation is already on it.
local FOLLOWUP_SETTLE = 1.0
local followUp = nil          -- { deadline, mapID, nextRequest }

-- Available quest-line offers whose start point is within reach of where you stand. Map
-- positions are 0..1 across the map, so scale by the map's size in yards. Positions are
-- restricted in instances; pcall'd by the caller, and an instance simply yields nothing.
local function NearbyOffers(mapID)
    local offers = {}
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return offers end
    local px, py = pos:GetXY()
    local width, height = C_Map.GetMapWorldSize(mapID)
    if not (width and width > 0 and height and height > 0) then return offers end
    for _, line in ipairs(C_QuestLine.GetAvailableQuestLines(mapID) or {}) do
        if line.questID and line.x and line.y then
            local dx, dy = (line.x - px) * width, (line.y - py) * height
            if dx * dx + dy * dy <= FOLLOWUP_RADIUS * FOLLOWUP_RADIUS then
                offers[#offers + 1] = { questID = line.questID, title = line.questName }
            end
        end
    end
    return offers
end

local function ShowFollowUpCue(title)
    local key = GetBindingKey and GetBindingKey("INTERACTTARGET")
    local how = key and ("press " .. ((GetBindingText and GetBindingText(key)) or key))
                or "talk to them again"
    local msg = string.format("Next quest ready: %s — %s", title or "?", how)
    if UIErrorsFrame then UIErrorsFrame:AddMessage(msg, 1, 0.82, 0) end  -- the game's own yellow info line
    local services = GetServices()
    if services and services.Debug then services.Debug("Quest", "Follow-up cue: " .. msg) end
end

local function FollowUpTick()
    local st = followUp
    local services = GetServices()
    if not (st and services) then return end
    if GetTime() > st.deadline then followUp = nil return end

    -- The map's offers update as the server catches up; keep asking while we watch.
    if GetTime() >= st.nextRequest then
        pcall(C_QuestLine.RequestQuestLinesForMap, st.mapID)
        st.nextRequest = GetTime() + 1.5
    end

    if services.DialogClosedFor() >= FOLLOWUP_SETTLE and not services.IsDialogContinuing() then
        local ok, offers = pcall(NearbyOffers, st.mapID)
        if ok and #offers > 0 then
            -- Only a quest automation would actually take — same filter as everywhere else.
            local _, actionable = QuestEngine.GetActionableQuests({}, offers)
            if actionable[1] then
                ShowFollowUpCue(actionable[1].title)
                followUp = nil
                return
            end
        end
    end
    services.ScheduleOnce("quest_followup_watch", 0.5, FollowUpTick)
end

function QuestEngine.WatchForFollowUp()
    local services, config = GetServices(), GetConfig()
    if not (services and config and services.IsAutomationEnabled()) then return end
    if config.Get("quest", "followUpCue") == false then return end
    if not (C_QuestLine and C_QuestLine.GetAvailableQuestLines and C_Map and C_Map.GetBestMapForUnit) then return end
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not (ok and mapID) then return end
    followUp = { deadline = GetTime() + FOLLOWUP_WATCH, mapID = mapID, nextRequest = 0 }
    services.ScheduleOnce("quest_followup_watch", 0.5, FollowUpTick)
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
