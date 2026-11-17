-- Core.lua — Module registry, event bus, and dependency injection

local ADDON_NAME, JustQuest = ...
_G.JustQuest = JustQuest

JustQuest.Core = {}

-- ============================================================
-- Module Registry
-- ============================================================

local modules = {}
local moduleOrder = {}
local initialized = false

-- Cached hot module refs — avoids GetModule() on every WoW event.
local _coreConfig = nil
local _coreServices = nil

-- ============================================================
-- Module Management
-- ============================================================

function JustQuest.Core.RegisterModule(name, module, dependencies)
    if modules[name] then
        error("Module already registered: " .. name)
    end
    
    modules[name] = {
        instance = module,
        dependencies = dependencies or {},
        initialized = false,
        enabled = true
    }
    
    table.insert(moduleOrder, name)
end

function JustQuest.Core.GetModule(name)
    return modules[name] and modules[name].instance or nil
end

-- Returns a memoized accessor for a module, replacing the per-engine
-- lazy GetX()/moduleCache boilerplate. Resolves on first successful lookup.
function JustQuest.Core.ModuleGetter(name)
    local cached
    return function()
        cached = cached or JustQuest.Core.GetModule(name)
        return cached
    end
end

-- Topological sort for dependency resolution
local function ResolveDependencies()
    local sorted = {}
    local visited = {}
    local visiting = {}
    
    local function visit(name)
        if visiting[name] then
            error("Circular dependency detected involving: " .. name)
        end
        if visited[name] then
            return
        end
        
        visiting[name] = true
        
        local module = modules[name]
        if module then
            for _, dep in ipairs(module.dependencies) do
                if not modules[dep] then
                    error("Missing dependency: " .. dep .. " required by " .. name)
                end
                visit(dep)
            end
        end
        
        visiting[name] = false
        visited[name] = true
        table.insert(sorted, name)
    end
    
    for _, name in ipairs(moduleOrder) do
        visit(name)
    end
    
    moduleOrder = sorted
end

-- ============================================================
-- Event Bus
-- ============================================================

local eventFrame = CreateFrame("FRAME")
local registeredEvents = {}

-- Event dispatcher mapping
local EVENT_DISPATCH = {
    -- Quest events -> QuestEngine
    QUEST_DETAIL = {"QuestEngine", "OnQuestDetail"},
    QUEST_PROGRESS = {"QuestEngine", "OnQuestProgress"},
    QUEST_COMPLETE = {"QuestEngine", "OnQuestComplete"},
    QUEST_AUTOCOMPLETE = {"QuestEngine", "OnQuestAutoComplete"},
    QUEST_GREETING = {"QuestEngine", "OnQuestGreeting"},
    QUEST_LOG_UPDATE = {"QuestEngine", "OnQuestLogUpdate"},
    QUEST_ACCEPT_CONFIRM = {"QuestEngine", "OnQuestAcceptConfirm"},
    QUEST_ITEM_UPDATE = {"QuestEngine", "OnQuestItemUpdate"},
    QUEST_DATA_LOAD_RESULT = {"QuestEngine", "OnQuestDataLoadResult"},
    
    PLAYER_CHOICE_UPDATE = {"QuestEngine", "OnPlayerChoiceUpdate"},
    PLAYER_CHOICE_CLOSE = {"QuestEngine", "OnPlayerChoiceClose"},
    
    GOSSIP_SHOW = {"QuestEngine", "OnGossipShow"},
    GOSSIP_CONFIRM = {"GossipEngine", "OnGossipConfirm"},
    GOSSIP_CONFIRM_CANCEL = {"GossipEngine", "OnGossipConfirmCancel"},
    GOSSIP_CLOSED = {"GossipEngine", "OnGossipClosed"},
    GOSSIP_OPTIONS_REFRESHED = {"GossipEngine", "OnGossipOptionsRefreshed"},
    
    QUEST_TURNED_IN = {"Core", "OnQuestTurnedIn"},
    QUEST_ACCEPTED = {"Core", "OnQuestAccepted"},
    QUEST_FINISHED = {"Core", "PumpQuestCheck"},
    
    -- Target/modifier events for instant state management
    MODIFIER_STATE_CHANGED = {"Core", "OnModifierStateChanged"},
    PLAYER_TARGET_CHANGED = {"Core", "OnPlayerTargetChanged"},
    
    -- Zone change recovery for quest-related teleportation
    PLAYER_ENTERING_WORLD = {"Core", "OnTeleportation"},
    
    CINEMATIC_START = {"Core", "OnCinematicStart"},
    PLAY_MOVIE = {"Core", "OnPlayMovie"},

    -- Vehicle / possess / override-bar control states: stand automation down
    -- immediately so nothing interacts with the controlling NPC mid-transition.
    UNIT_ENTERED_VEHICLE = {"Core", "OnControlStateEnter"},
    UPDATE_OVERRIDE_ACTIONBAR = {"Core", "OnControlStateEnter"},
    UPDATE_POSSESS_BAR = {"Core", "OnControlStateEnter"},
}

-- ============================================================
-- Core Event Handlers
-- ============================================================

local function PumpQuestCheck()
    local services = JustQuest.Core.GetModule("Services")
    if services and services.PumpQuestCheck then
        local pumpDelay = services.GetTiming("QUEST_PUMP_STANDARD", 0.15)
        services.PumpQuestCheck("lifecycle", pumpDelay)
    end
end

local function OnQuestAccepted(questID)
    local services = JustQuest.Core.GetModule("Services")
    local safety = JustQuest.Core.GetModule("SafetyEngine")
    
    local questEngine = JustQuest.Core.GetModule("QuestEngine")
    if questEngine and questEngine.OnQuestAcceptedSuccess then
        questEngine.OnQuestAcceptedSuccess(questID)
    end
    
    if safety then
        safety.SetState("IDLE", "quest_accepted")
    end
    
    -- Reset gossip chain depth so the next gossip pass starts fresh
    local gossipEngine = JustQuest.Core.GetModule("GossipEngine")
    if gossipEngine and gossipEngine.ResetChainState then
        gossipEngine.ResetChainState()
    end

    -- Chain summary: a quest was accepted (no-op unless the option is on).
    if services and services.NoteAutomation then
        services.NoteAutomation("accepted")
    end

    -- Close the quest frame only if it is showing THIS quest, and only when automating.
    -- QUEST_ACCEPTED also fires for quests picked up elsewhere (area/bonus objectives,
    -- world quests on entering their zone); closing on any of those shut whatever quest
    -- window happened to be open — including one the player was reading.
    if QuestFrame and QuestFrame:IsShown() and GetQuestID and GetQuestID() == questID
       and services and services.ShouldAutomate() then
        services.SafeCall(CloseQuest)
    end

    JustQuest._lastProcessingTime = GetTime()
    JustQuest._lastProgressTime = GetTime()  -- the next quest may still be on its way
    if services and services.Debug then
        services.Debug("Core", string.format("OnQuestAccepted: updated _lastProcessingTime=%.3f", JustQuest._lastProcessingTime))
    end

    -- Schedule content re-check for remaining NPC quests.
    -- GOSSIP_SHOW does not always re-fire after quest accept (e.g. CloseQuest
    -- ends the interaction), so an explicit repump is needed.
    if services and services.PumpQuestCheck then
        local delay = services.GetTiming and services.GetTiming("REINTERACT_CHECK_DELAY", 0.15) or 0.15
        services.PumpQuestCheck("post_quest_accept", delay)
    end
end

local function OnQuestTurnedIn(questID)
    JustQuest._lastProgressTime = GetTime()  -- the follow-up may still be on its way
    local questEngine = JustQuest.Core.GetModule("QuestEngine")
    if questEngine and questEngine.OnQuestTurnedInSuccess then
        questEngine.OnQuestTurnedInSuccess(questID)
    end

    -- Reset reward flag in case a prior crash left it stuck
    local rewardEngine = JustQuest.Core.GetModule("RewardEngine")
    if rewardEngine and rewardEngine.ResetProcessingFlag then
        rewardEngine.ResetProcessingFlag()
    end

    -- Turn-in is real progress: refresh the gossip auto-select budget so a hub that
    -- routes each turn-in through gossip navigation doesn't exhaust the chain-depth
    -- cap and stop mid-hub (accept does the same via OnQuestAccepted).
    local gossipEngine = JustQuest.Core.GetModule("GossipEngine")
    if gossipEngine and gossipEngine.ResetChainState then
        gossipEngine.ResetChainState()
    end

    -- Chain summary: a quest was turned in (no-op unless the option is on).
    local services = JustQuest.Core.GetModule("Services")
    if services and services.NoteAutomation then
        services.NoteAutomation("turnedIn")
    end

    local safety = JustQuest.Core.GetModule("SafetyEngine")
    if safety then
        safety.EndProcessing("quest_turned_in", true)
    end
end

-- CINEMATIC_START passes canBeCancelled as its first arg; Blizzard stores it as
-- CinematicFrame.isRealCinematic ("if it isn't real, it's a vehicle cinematic").
-- CinematicFrame_CancelCinematic() branches on it: real -> StopCinematic, a
-- cancellable scene -> CancelScene, otherwise -> VehicleExit(). That last branch is
-- the trap: a vehicle cinematic (quest possess/vehicle boarding like "torture the
-- suspect") would be force-skipped by ejecting the player mid-board, desyncing them
-- into a disconnect. So only skip a real cinematic or a cancellable in-game scene;
-- calling the same function Blizzard's own skip-confirm calls makes it instant and
-- seamless (no popup dance needed).
local function OnCinematicStart(canBeCancelled)
    local config = JustQuest.Core.GetModule("Config")
    if not (config and config.Get(nil, "skipCinematics")) then return end

    local skippable = canBeCancelled
        or (IsInCinematicScene and IsInCinematicScene() and CanCancelScene and CanCancelScene())
    if skippable and CinematicFrame_CancelCinematic then
        CinematicFrame_CancelCinematic()
    end
end

local function OnPlayMovie()
    local config = JustQuest.Core.GetModule("Config")
    if not (config and config.Get(nil, "skipCinematics")) then return end

    -- FinishMovie() is exactly what the movie's skip-confirm button calls (stop +
    -- hide + report finished). Pre-rendered movies are never vehicle transitions.
    if MovieFrame and MovieFrame.FinishMovie then
        MovieFrame:FinishMovie()
    end
end

-- State recovery for teleportation and UI state changes
local lastZone = GetRealZoneText()

local function OnStateRecoveryNeeded(reason)
    
    local services = JustQuest.Core.GetModule("Services")
    local gossipEngine = JustQuest.Core.GetModule("GossipEngine")
    
    if not services then return end
    
    if services.Debug then
        services.Debug("Core", "State recovery triggered: " .. reason)
    end
    
    -- 1. Reset if stuck in non-IDLE state
    local safety = JustQuest.Core.GetModule("SafetyEngine")
    local processingState = safety and safety.GetState() or "IDLE"
    if processingState and processingState ~= "IDLE" then
        if safety then
            safety.SetState("IDLE", "state_recovery_" .. reason)
        end
        if services.Debug then
            services.Debug("Core", "Reset stuck processing state: " .. processingState .. " -> IDLE")
        end
    end
    
    -- 2. Close desynchronized frames
    if QuestFrame and QuestFrame:IsShown() then
        QuestFrame:Hide()
    end
    if GossipFrame and GossipFrame:IsShown() then
        GossipFrame:Hide()
    end
    
    if gossipEngine and gossipEngine.OnGossipClosed then
        services.SafeCall(gossipEngine.OnGossipClosed)
    end
    
    if services.CancelAutomationTimers then
        services.CancelAutomationTimers()
    end
    
    if services.Debug then
        services.Debug("Core", "State recovery complete: " .. reason)
    end
    
    if services.ScheduleOnce then
        local resumeDelay = services.GetTiming("REINTERACT_CHECK_DELAY", 0.15)
        services.ScheduleOnce("state_recovery_resume", resumeDelay, function()
            if services.PumpQuestCheck then
                local pumpDelay = services.GetTiming("QUEST_PUMP_STANDARD", 0.15)
                services.PumpQuestCheck("after_state_recovery", pumpDelay)
            end
        end)
    end
end

local function OnTeleportation()
    local currentZone = GetRealZoneText()
    local zoneChanged = (currentZone ~= lastZone)
    
    if zoneChanged then
        lastZone = currentZone
        OnStateRecoveryNeeded("teleportation")
    end
end

local function OnModifierStateChanged(_, down)
    if down == 0 then
        -- Feeds the "held at the click" grace for a dialog still on its way from the server.
        local services = JustQuest.Core.GetModule("Services")
        if services and services.NoteModifierReleased then services.NoteModifierReleased() end
    elseif down == 1 then
        local safety = JustQuest.Core.GetModule("SafetyEngine")
        local services = JustQuest.Core.GetModule("Services")
        
        -- Always restore frames when modifier is pressed.
        -- Fast mode may have hidden them; player needs to see the UI to interact.
        if services and services.RestoreAutomationFrames then
            services.RestoreAutomationFrames()
        end
        
        -- Manual takeover: cancel all pending automation timers, including ones
        -- that fire BEFORE StartProcessing (IsBusy() would miss those).
        if services and services.CancelAutomationTimers then
            services.CancelAutomationTimers()
        end
        
        if safety and safety.IsBusy and safety.IsBusy() then
            if services and services.Debug then
                services.Debug("Core", "Modifier key pressed - cancelling automation immediately")
            end
            if safety.EndProcessing then
                safety.EndProcessing("modifier_cancel")
            end
        end
    end
end

local function OnPlayerTargetChanged()
    local gossipEngine = JustQuest.Core.GetModule("GossipEngine")

    if gossipEngine and gossipEngine.OnTargetChanged then
        gossipEngine.OnTargetChanged()
    end
end

-- Vehicle boarding, possess, or an override action bar (e.g. a "torture the
-- suspect" quest bar) means the player is now controlling something else.
-- Interacting with the source NPC or its gossip while the server is still
-- transitioning desyncs the client and force-disconnects, so cancel every
-- pending automation action and go idle. Automation resumes on the next real
-- quest/gossip event once the control state ends.
local function OnControlStateEnter(unit)
    -- UNIT_ENTERED_VEHICLE passes a unit; override/possess-bar events pass none.
    if unit ~= nil and unit ~= "player" then return end

    local services = JustQuest.Core.GetModule("Services")
    if services then
        if services.CancelAutomationTimers then services.CancelAutomationTimers() end
        if services.RestoreAutomationFrames then services.RestoreAutomationFrames() end
    end

    local safety = JustQuest.Core.GetModule("SafetyEngine")
    if safety then
        if safety.IsBusy and safety.IsBusy() and safety.EndProcessing then
            safety.EndProcessing("control_state_enter")
        elseif safety.SetState then
            safety.SetState("IDLE", "control_state_enter")
        end
    end
end

-- Core method dispatch table
local CORE_METHODS = {
    PumpQuestCheck = PumpQuestCheck,
    OnQuestAccepted = OnQuestAccepted,
    OnQuestTurnedIn = OnQuestTurnedIn,
    OnCinematicStart = OnCinematicStart,
    OnPlayMovie = OnPlayMovie,
    OnTeleportation = OnTeleportation,
    OnModifierStateChanged = OnModifierStateChanged,
    OnPlayerTargetChanged = OnPlayerTargetChanged,
    OnControlStateEnter = OnControlStateEnter,
}

-- ============================================================
-- Event Processing
-- ============================================================

local DIALOG_OPEN_EVENTS = { GOSSIP_SHOW = true, QUEST_GREETING = true, GOSSIP_OPTIONS_REFRESHED = true }

local function ShouldProcessEvent(event)
    if JustQuest.Constants.BYPASS_SAFETY_EVENTS[event] then
        return true
    end

    -- Use cached refs — avoids GetModule on every event
    local config = _coreConfig
    if not config or not config.Get(nil, "enabled") then return false end

    local services = _coreServices
    if not services then return false end

    if event == "CINEMATIC_START" or event == "PLAY_MOVIE" then
        return config.Get(nil, "skipCinematics") and
               services.ShouldAutomate()
    end

    -- Single-pass automation gate (modifier keys, dead, vehicle, config, frames)
    if not services.ShouldAutomate() then
        -- Modifier key held: restore frames so player sees the UI.
        -- Fast mode may have already hidden them via OnShow hook.
        services.RestoreAutomationFrames()
        return false
    end
    if UnitIsDeadOrGhost("player") then return false end
    if services.InSpecialControlState and services.InSpecialControlState() then return false end
    if not config.Get("quest", "enabled") or not config.Get("gossip", "enabled") then return false end

    -- The server (re-)opening a dialog is never dropped here for a TRANSIENT reason (a popup
    -- up, a vendor frame still closing, the frame not flagged shown yet). These only schedule
    -- a content pass, and that pass re-checks every gate on each tick until its deadline — so
    -- a blocker that clears a moment later no longer costs the next quest in a chain. Dropping
    -- the re-show that follows a turn-in was a silent "needs a second click".
    if DIALOG_OPEN_EVENTS[event] then return true end

    -- Single-pass frame check (not duplicated via CanAutomate)
    if not services.IsAutomationContextAllowed() then return false end

    return true
end

local function HandleSpecialEvent(event, ...)
    local services = _coreServices
    if not services then
        return true
    end
    
    if event == "GOSSIP_SHOW" then
        local showDelay = services.GetTiming("GOSSIP_EVENT_DISPATCH", 0.05)
        services.CoalescedGossipPass("gossip_show", showDelay)
        return true
    elseif event == "QUEST_GREETING" then
        local greetingDelay = services.GetTiming("GOSSIP_EVENT_DISPATCH", 0.05)
        services.CoalescedGossipPass("quest_greeting", greetingDelay)
        return true
    elseif event == "GOSSIP_OPTIONS_REFRESHED" then
        -- Route through DispatchContent (same as GOSSIP_SHOW) so QuestEngine
        -- processes available/active quests before GossipEngine selects options.
        -- Without this, GossipEngine.HandleGossip() runs directly, ignoring
        -- remaining quests and causing gossip loops.
        local refreshDelay = services.GetTiming("GOSSIP_EVENT_DISPATCH", 0.05)
        services.ScheduleContentCheck(refreshDelay, "gossip_options_refreshed")
        return true
    end
    
    return false
end

local function DispatchToModule(moduleName, methodName, ...)
    if moduleName == "Core" then
        local coreMethod = CORE_METHODS[methodName]
        if coreMethod then
            local success, result = pcall(coreMethod, ...)
            if not success then
                JustQuest.Core.Debug("Core", "Core method failed: " .. tostring(result))
            end
        end
        return
    end
    
    local module = JustQuest.Core.GetModule(moduleName)
    if module and module[methodName] then
        local services = JustQuest.Core.GetModule("Services")
        if services and services.SafeCall then
            services.SafeCall(module[methodName], ...)
        else
            local success, result = pcall(module[methodName], ...)
            if not success then
                JustQuest.Core.Debug("Core", moduleName .. "." .. methodName .. " failed: " .. tostring(result))
            end
        end
    end
end

-- ============================================================
-- Main Event Handler
-- ============================================================

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if not ShouldProcessEvent(event) then
        return
    end
    
    if HandleSpecialEvent(event, ...) then
        return
    end
    
    local dispatchInfo = EVENT_DISPATCH[event]
    if not dispatchInfo then
        return
    end
    
    if type(dispatchInfo) == "function" then
        local success, result = pcall(dispatchInfo, event, ...)
        if not success then
            JustQuest.Core.Debug("Core", "Inline handler failed: " .. tostring(result))
        end
        return
    end
    
    local moduleName, methodName = dispatchInfo[1], dispatchInfo[2]
    DispatchToModule(moduleName, methodName, ...)
end)

-- ============================================================
-- Event Registration
-- ============================================================

function JustQuest.Core.RegisterEvents()
    if next(registeredEvents) then
        return
    end
    
    for event in pairs(EVENT_DISPATCH) do
        eventFrame:RegisterEvent(event)
        registeredEvents[event] = true
    end
end

function JustQuest.Core.UnregisterEvents()
    eventFrame:UnregisterAllEvents()
    registeredEvents = {}
    
    for name, moduleData in pairs(modules) do
        if moduleData.instance and moduleData.instance.OnDisable then
            pcall(moduleData.instance.OnDisable)
        end
    end
end

-- ============================================================
-- Public API
-- ============================================================

function JustQuest.Core.SetupEvents()
    local config = JustQuest.Core.GetModule("Config")
    if config and config.Get(nil, "enabled") then
        JustQuest.Core.RegisterEvents()
        -- Disabling tears down every timer, including the persistent recovery nets that
        -- are meant to survive a teardown. Core.Initialize is one-shot, so without this
        -- a disable/enable cycle left the session with no stuck-state recovery and no
        -- fast-mode un-hide for the rest of the session. ScheduleRepeating replaces on
        -- the same key, so re-initializing is idempotent. Quest (log-full listener) and
        -- Container (bag events + periodic scan) tear down their own listeners in OnDisable,
        -- so they need the same re-arm or auto-open stays dead after a toggle.
        for _, name in ipairs({ "SafetyEngine", "QuestEngine", "ContainerEngine" }) do
            local module = JustQuest.Core.GetModule(name)
            if module and module.Initialize then pcall(module.Initialize) end
        end
    else
        JustQuest.Core.UnregisterEvents()
    end
end

-- Pre-Services debug fallback
function JustQuest.Core.Debug(module, msg)
    local services = JustQuest.Core.GetModule("Services")
    if services and services.Debug then
        services.Debug(module, msg)
        return
    end
    
    -- Fallback before Services loads
    local config = JustQuest.Core.GetModule("Config")
    local debugEnabled = false
    
    if config then
        debugEnabled = config.Get(nil, "debugMode")
    else
        debugEnabled = JustQuest._debugMode
    end
    
    if debugEnabled then
        print("|cff00ccffJQ " .. (module or "Core") .. ":|r " .. tostring(msg))
    end
end

-- ============================================================
-- Initialization
-- ============================================================

function JustQuest.Core.Initialize()
    if initialized then
        return
    end
    
    ResolveDependencies()
    
    local loadedModules = {}
    for _, name in ipairs(moduleOrder) do
        local moduleData = modules[name]
        if moduleData and moduleData.enabled and moduleData.instance then
            if moduleData.instance.Initialize then
                local success, result = pcall(moduleData.instance.Initialize)
                if success then
                    moduleData.initialized = true
                    table.insert(loadedModules, name)
                else
                    JustQuest.Core.Debug("Core", "Failed to initialize " .. name .. ": " .. tostring(result))
                end
            else
                moduleData.initialized = true
                table.insert(loadedModules, name)
            end
        end
    end
    
    if #loadedModules > 0 then
        JustQuest.Core.SetupEvents()
    end

    -- Cache hot module refs now that all modules are initialized
    _coreConfig = modules["Config"] and modules["Config"].instance or nil
    _coreServices = modules["Services"] and modules["Services"].instance or nil

    initialized = true
end

-- ============================================================
-- Slash Commands
-- ============================================================

SLASH_JUSTQUESTLEAVE1 = "/jql"
SlashCmdList["JUSTQUESTLEAVE"] = function()
    local services = JustQuest.Core.GetModule("Services")
    if not services then
        print("|cffff0000JustQuest:|r Services module not loaded")
        return
    end
    
    local success, reason = services.LeaveInstance()
    if success then
        services.Info(reason or "Leaving instance...")
    else
        services.Warn("Cannot leave - " .. (reason or "unknown error"))
    end
end

-- ============================================================
-- Auto-initialize
-- ============================================================

local initFrame = CreateFrame("FRAME")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if loadedAddonName == ADDON_NAME then
        JustQuest.Core.Initialize()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
