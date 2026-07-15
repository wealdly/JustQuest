-- DelveEngine.lua — delve-specific automation: take a delve power, pick a delve tier.
--
-- Everything here is OFF by default, and every path is gated on actually being in a delve
-- (or standing at the delve picker). That gate is the whole point: player choices are
-- deliberately NOT automated anywhere else in JustQuest — a world quest reward or a
-- covenant pick is a real decision and stays yours. A delve power is the one exception you
-- can opt into, because it isn't a decision: you're offered a single power, it's always
-- worth taking, and the window is just asking for a click you were always going to make.
--
-- Runs on its own frame, independent of the quest-automation dispatcher, so delve handling
-- can't be cancelled by a modifier-key takeover of quest automation (it still honours the
-- modifier itself — see ShouldAutomate).
--
-- Safety, in keeping with the rest of the addon:
--   * a choice the server marks requiresSelection is never auto-taken — it's a real decision
--   * a power whose button carries a confirmation is never auto-taken — same reason we never
--     auto-accept GOSSIP_CONFIRM: the server is asking, so the player should answer
--   * more than one option on offer means it isn't the usual power hand-out, so it's handed
--     back rather than guessed at
--   * the difficulty picker is otherwise off-limits (Constants.INTERFERING_FRAMES), so the
--     only thing that ever selects a tier is this file, with the player's say-so

local ADDON_NAME, JustQuest = ...

local DelveEngine = {}

local GetConfig   = JustQuest.Core.ModuleGetter("Config")
local GetServices = JustQuest.Core.ModuleGetter("Services")

local frame = CreateFrame("Frame")

local delveCache, delveCacheTime = false, 0
local lastChoiceID, answeredChoice
local powerFrameHidden = false
local lastTier, lastTierTime = nil, 0

local function Debug(msg)
    local services = GetServices()
    if services and services.Debug then services.Debug("Delve", msg) end
end

local function Notify(msg)
    local services = GetServices()
    if services and services.Info then services.Info(msg) else print("|cff00ccffJustQuest:|r " .. msg) end
end

local function Get(key)
    local config = GetConfig()
    return config and config.Get("delve", key)
end

-- Master switch AND the delve toggle in question.
local function On(key)
    local config = GetConfig()
    return config and config.Get(nil, "enabled") and config.Get("delve", key) and true or false
end

-- Modifier held / dead / vehicle: hands off, same as everywhere else.
local function MayAutomate()
    local services = GetServices()
    if services and services.ShouldAutomate and not services.ShouldAutomate() then return false end
    return true
end

-- ============================================================
-- Am I in a delve?
-- ============================================================

-- Three sources, cheapest first — none is reliable alone across load and transition, so
-- each falls through to the next. Cached for a second: this is asked on every choice event.
local function IsInDelve()
    local now = GetTime()
    if (now - delveCacheTime) < 1 then return delveCache end
    delveCacheTime = now

    if C_DelvesUI and C_DelvesUI.HasActiveDelve then
        local ok, _, _, _, mapID = pcall(UnitPosition, "player")
        if ok and mapID then
            local ok2, active = pcall(C_DelvesUI.HasActiveDelve, mapID)
            if ok2 then
                delveCache = active and true or false
                return delveCache
            end
        end
    end

    if C_PartyInfo and C_PartyInfo.IsDelveInProgress then
        local ok, active = pcall(C_PartyInfo.IsDelveInProgress)
        if ok then
            delveCache = active and true or false
            return delveCache
        end
    end

    -- Last resort: a scenario we can ask delve questions about is a delve.
    local inInstance, instanceType = IsInInstance()
    delveCache = (inInstance and instanceType == "scenario"
                  and C_PartyInfo and C_PartyInfo.IsDelveComplete ~= nil) and true or false
    return delveCache
end

DelveEngine.IsInDelve = IsInDelve

-- ============================================================
-- Power auto-accept (PlayerChoice)
-- ============================================================

-- Hidden by alpha, not :Hide() — the frame stays live so the server-side choice still
-- works. Services.RestoreAutomationFrames un-hides it on periodic recovery, so a failure
-- partway through can't strand you with an invisible dialog you can't answer.
local function HidePowerFrame()
    if not Get("hidePowerFrame") then return end
    if PlayerChoiceFrame and PlayerChoiceFrame.SetAlpha then
        PlayerChoiceFrame:SetAlpha(0)
        powerFrameHidden = true
    end
end

local function RestorePowerFrame()
    if not powerFrameHidden then return end
    if PlayerChoiceFrame and PlayerChoiceFrame.SetAlpha then PlayerChoiceFrame:SetAlpha(1) end
    powerFrameHidden = false
end

local function AcceptPower()
    -- Guarded, not pcall'd: indexing a missing C_PlayerChoice would throw while building
    -- the pcall's own arguments, before pcall could catch anything.
    if not (C_PlayerChoice and C_PlayerChoice.GetCurrentPlayerChoiceInfo
            and C_PlayerChoice.SendPlayerChoiceResponse) then return end
    if not On("autoAcceptPower") then return RestorePowerFrame() end
    if not IsInDelve() then return RestorePowerFrame() end
    if not MayAutomate() then
        Debug("modifier held / not automating — the choice is yours")
        return RestorePowerFrame()
    end

    local ok, info = pcall(C_PlayerChoice.GetCurrentPlayerChoiceInfo)
    if not ok or not info then Debug("no choice info yet") return end

    -- The server saying "you must choose" is a genuine decision. Never take it.
    if info.requiresSelection then
        Debug("choice requires manual selection — handing it back")
        return RestorePowerFrame()
    end
    if not (info.options and info.options[1]) then return RestorePowerFrame() end

    if lastChoiceID == info.choiceID and answeredChoice then
        Debug("already answered choice " .. tostring(info.choiceID))
        return
    end

    -- A delve power is offered one at a time: one option, one button, click it. So there's
    -- nothing to choose between and nothing to filter. More than one option means it ISN'T
    -- the usual power hand-out — it's a real choice — so hand it back rather than guess.
    if #info.options > 1 then
        Debug(("%d options — a real choice, handing it back"):format(#info.options))
        lastChoiceID, answeredChoice = info.choiceID, true
        return RestorePowerFrame()
    end

    local power  = info.options[1]
    local button = power.buttons and power.buttons[1]
    if not (button and button.id) or button.disabled then
        Debug("power can't be taken (no usable button)")
        return RestorePowerFrame()
    end
    -- The server wanting a second yes is the server asking. That's the player's to give.
    if button.confirmation then
        Debug("power asks for confirmation — handing it back")
        lastChoiceID, answeredChoice = info.choiceID, true
        return RestorePowerFrame()
    end

    lastChoiceID, answeredChoice = info.choiceID, true
    local sent = pcall(C_PlayerChoice.SendPlayerChoiceResponse, button.id)
    if not sent then
        Debug("send failed — handing the choice back")
        return RestorePowerFrame()
    end

    Notify("Delve power: " .. (power.header or "taken"))

    -- Blizzard normally closes this itself (PLAYER_CHOICE_CLOSE restores the alpha). If it
    -- doesn't, an alpha-0 frame would sit on screen eating clicks, so close it — unless the
    -- server wants it kept open, in which case make it visible again instead.
    C_Timer.After(0.3, function()
        if not (PlayerChoiceFrame and PlayerChoiceFrame:IsShown()) then return end
        if not (C_PlayerChoice and C_PlayerChoice.GetCurrentPlayerChoiceInfo) then return end
        local ok2, cur = pcall(C_PlayerChoice.GetCurrentPlayerChoiceInfo)
        if ok2 and cur and (cur.requiresSelection or cur.keepOpenAfterChoice) then
            RestorePowerFrame()
            return
        end
        if InCombatLockdown() then
            PlayerChoiceFrame:Hide()  -- HideUIPanel taints the secure panel system in combat
        else
            pcall(HideUIPanel, PlayerChoiceFrame)
        end
    end)
end

function DelveEngine.OnPlayerChoiceUpdate()
    if not On("autoAcceptPower") or not IsInDelve() or not MayAutomate() then return end
    answeredChoice = false
    HidePowerFrame()  -- after the gates, so a choice we won't touch never flickers

    -- Immediately, then once more: the choice data isn't always populated on the first tick.
    local services = GetServices()
    if services and services.ScheduleOnce then
        services.ScheduleOnce("delve_power", 0.05, AcceptPower)
        services.ScheduleOnce("delve_power_retry", 0.3, function()
            if not answeredChoice then AcceptPower() end
        end)
    else
        AcceptPower()
    end
end

function DelveEngine.OnPlayerChoiceClose()
    RestorePowerFrame()
    answeredChoice = false
    local services = GetServices()
    if services and services.CancelScheduled then
        services.CancelScheduled("delve_power")
        services.CancelScheduled("delve_power_retry")
    end
end

-- ============================================================
-- Tier selection
-- ============================================================

-- The picker's gossip options ARE the tiers, and selecting one enters the delve. So this
-- runs in two halves: preselect the tier in the UI (cosmetic, pokes Blizzard's frame the
-- way its own dropdown does), then — only if you asked for it — actually go in.
local function SelectTier(picker)
    if not On("autoTier") or not MayAutomate() then return end

    local desired = Get("preferredTier") or 1
    local services = GetServices()

    local ok, options = pcall(C_GossipInfo.GetOptions)
    if not ok or type(options) ~= "table" or #options == 0 then
        Debug("no options on the picker yet")
        return
    end
    table.sort(options, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)

    -- Match on orderIndex, not list position: a tier you can't queue for isn't listed, so
    -- options[3] is not necessarily tier 3.
    local target
    for _, option in ipairs(options) do
        if option.orderIndex == (desired - 1) then target = option break end
    end
    if not target then
        Debug(("tier %d isn't offered (%d options)"):format(desired, #options))
        return
    end

    if target.status and Enum and Enum.GossipOptionStatus then
        local available = target.status == Enum.GossipOptionStatus.Available
                       or target.status == Enum.GossipOptionStatus.AlreadyComplete
        if not available then
            Debug(("tier %d isn't available right now"):format(desired))
            return
        end
    end

    -- Don't re-pick the same tier on every picker refresh.
    local now = GetTime()
    local repeated = (lastTier == desired) and (now - lastTierTime) < 5
    lastTier, lastTierTime = desired, now

    if not repeated then
        -- Mirrors what the picker's own dropdown does on selection. All of it is Blizzard
        -- internals, so it's wrapped whole: if a patch moves any of it, the preselect
        -- quietly does nothing rather than erroring.
        local call = (services and services.SafeCall) or function(f, ...) return pcall(f, ...) end
        call(function()
            if picker.DelveRewardsContainerFrame then picker.DelveRewardsContainerFrame:Hide() end
            if picker.SetSelectedLevel then picker:SetSelectedLevel(target.orderIndex) end
            if picker.SetSelectedOption then picker:SetSelectedOption(target) end
            if picker.Dropdown and picker.Dropdown.Update then picker.Dropdown:Update() end
            if picker.UpdateWidgets and target.gossipOptionID then picker:UpdateWidgets(target.gossipOptionID) end
            if picker.DelveRewardsContainerFrame and picker.DelveRewardsContainerFrame.SetRewards then
                picker.DelveRewardsContainerFrame:SetRewards()
            end
            if picker.UpdatePortalButtonState then picker:UpdatePortalButtonState() end
            pcall(SetCVar, "lastSelectedDelvesTier", target.orderIndex + 1)
        end)
        Notify(("Delve: selected %s"):format(target.name or ("tier " .. desired)))
    end

    if not On("autoEnter") then return end
    if services and services.ScheduleOnce then
        services.ScheduleOnce("delve_enter", 0.2, function()
            Debug("entering delve at tier " .. desired)
            local enterOK = pcall(C_GossipInfo.SelectOptionByIndex, target.orderIndex)
            if not enterOK then Debug("enter failed — the picker is still yours") end
        end)
    end
end

-- ============================================================
-- Events (own frame — independent of the quest-automation gate)
-- ============================================================

frame:RegisterEvent("PLAYER_CHOICE_UPDATE")
frame:RegisterEvent("PLAYER_CHOICE_CLOSE")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("GOSSIP_CLOSED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_CHOICE_UPDATE" then
        DelveEngine.OnPlayerChoiceUpdate()

    elseif event == "PLAYER_CHOICE_CLOSE" then
        DelveEngine.OnPlayerChoiceClose()

    elseif event == "GOSSIP_SHOW" then
        -- arg1 is the texture kit: this is the only reliable way to tell the difficulty
        -- picker from an ordinary NPC, and everything else leaves the picker alone.
        if arg1 ~= "delves-difficulty-picker" then return end
        if not On("autoTier") then return end
        local picker = _G["DelvesDifficultyPickerFrame"]
        if not picker then return end
        local services = GetServices()
        if services and services.ScheduleOnce then
            services.ScheduleOnce("delve_tier", 0.2, function()
                if picker:IsVisible() then SelectTier(picker) end
            end)
        end

    elseif event == "GOSSIP_CLOSED" then
        local services = GetServices()
        if services and services.CancelScheduled then
            services.CancelScheduled("delve_tier")
            services.CancelScheduled("delve_enter")
        end
    end
end)

function DelveEngine.Initialize()
    -- Frame + events wired at load; every handler re-checks its own toggle.
end

JustQuest.Core.RegisterModule("DelveEngine", DelveEngine, {"Config", "Services"})

return DelveEngine
