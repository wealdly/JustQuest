-- On-screen Exit button for quick instance exits via the LFG listing flow.

local ADDON_NAME, JustQuest = ...

local LFGQuickStart = {}
local QUESTING_CATEGORY = 1
local QUICK_EXIT_PLAYSTYLE = Enum.LFGEntryGeneralPlaystyle.Learning
local QUICK_EXIT_LEAVE_DELAY = 0.2
local QUICK_EXIT_SUCCESS_MESSAGE = "Exit successful."
local QUICK_EXIT_COUNTDOWN_MESSAGE = "Exit initiated. Blizzard will show the instance ejection countdown."
local QUICK_EXIT_RESET_POLL_INTERVAL = 1.0
local QUICK_EXIT_RESET_TIMEOUT = 90.0
local QUICK_EXIT_WARN_COLOR = "|cFFFFAA00"

local quickExitEventFrame
local quickExitButton
local quickExitVisibilityFrame
local quickExitMouseUpAction = nil
local quickExitResultShown = false
local PrintQuickExitDebug
local CloseQuickExitWindows
local SuppressQuickExitWindows
local SaveQuickExitButtonPosition
-- Forward-declared: defined below but referenced by earlier functions.
local GetConfigModule
local ShowQuickExitResult

local quickExitSavedPVEAlpha
local quickExitSavedPVEMouseEnabled
local quickExitPVESuppressed = false

local function IsQuickExitPositionInitialized()
    local config = GetConfigModule()
    if not config then
        return true
    end

    return config.Get("lfgQuickExit", "positionInitialized") and true or false
end

local function MarkQuickExitPositionInitialized()
    local config = GetConfigModule()
    if not config then
        return
    end

    config.Set("lfgQuickExit", "positionInitialized", true)
end

local function GetQuickExitInitialAnchor()
    if QueueStatusButton and QueueStatusButton:IsShown() then
        return "TOPRIGHT", QueueStatusButton, "TOPLEFT", -8, 0
    end

    if MinimapCluster and MinimapCluster:IsShown() then
        return "TOPRIGHT", MinimapCluster, "BOTTOMLEFT", -8, -8
    end

    return "CENTER", UIParent, "CENTER", 280, -120
end

local function ApplyInitialQuickExitPosition()
    if not quickExitButton or IsQuickExitPositionInitialized() then
        return
    end

    local point, relativeTo, relativePoint, offsetX, offsetY = GetQuickExitInitialAnchor()
    quickExitButton:ClearAllPoints()
    quickExitButton:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
    SaveQuickExitButtonPosition()
    MarkQuickExitPositionInitialized()
end

function GetConfigModule()
    return JustQuest.Core.GetModule("Config")
end

local function UnregisterQuickExitEvents()
    if quickExitEventFrame then
        quickExitEventFrame:UnregisterAllEvents()
    end
end

local function FailQuickExit(stage, debugMessage, userMessage, options)
    options = options or {}

    if stage and debugMessage then
        PrintQuickExitDebug(stage, debugMessage, true)
    end

    if options.unregisterEvents then
        UnregisterQuickExitEvents()
    end

    if options.closeWindows then
        CloseQuickExitWindows()
    end

    if userMessage then
        ShowQuickExitResult(userMessage, QUICK_EXIT_WARN_COLOR)
    end

    return false
end

local function IsResetOnExitEnabled()
    local config = GetConfigModule()
    if not config then
        return false
    end

    return config.Get("lfgQuickExit", "resetInstanceOnExit") and true or false
end

local function QueueResetInstanceAfterExit(services)
    if not services or not IsResetOnExitEnabled() then
        return
    end

    local startedAt = GetTime()
    services.CancelScheduled("lfg_quick_exit_reset_poll")
    services.ScheduleRepeating("lfg_quick_exit_reset_poll", QUICK_EXIT_RESET_POLL_INTERVAL, function()
        local elapsed = GetTime() - startedAt
        local inInstance = IsInInstance()

        if inInstance and elapsed < QUICK_EXIT_RESET_TIMEOUT then
            return
        end

        services.CancelScheduled("lfg_quick_exit_reset_poll")

        if inInstance then
            PrintQuickExitDebug("RESET", "Timed out waiting to leave instance before reset", true)
            return
        end

        local resetSuccess, resetErr = pcall(ResetInstances)
        if not resetSuccess then
            PrintQuickExitDebug("RESET", "ResetInstances failed: " .. tostring(resetErr), true)
            return
        end

        PrintQuickExitDebug("RESET", "ResetInstances executed after exit")
    end)
end

function ShowQuickExitResult(message, color)
    if quickExitResultShown then
        return
    end

    quickExitResultShown = true
    print((color or "|cFF00FF00") .. "JustQuest LFG:|r " .. tostring(message))
end

local function IsQuickExitDebugEnabled()
    local config = GetConfigModule()
    if not config then
        return false
    end

    if config.IsDebugMode then
        return config.IsDebugMode() and true or false
    end

    return config.Get(nil, "debugMode") and true or false
end

-- ============================================================
-- Core Functionality
-- ============================================================

local function BeginQuickExitLeaveAfterList(services)
    local debugMsg = services and services.Debug or function() end

    if not quickExitEventFrame then
        quickExitEventFrame = CreateFrame("Frame")
    end

    quickExitEventFrame:UnregisterAllEvents()
    quickExitEventFrame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
    quickExitEventFrame:RegisterEvent("LFG_LIST_ENTRY_CREATION_FAILED")
    quickExitEventFrame:SetScript("OnEvent", function(self, event)
        if event == "LFG_LIST_ENTRY_CREATION_FAILED" then
            self:UnregisterAllEvents()
            FailQuickExit("EVENT_LIST", "LFG_LIST_ENTRY_CREATION_FAILED", "Exit failed. Blizzard rejected the quick-exit listing.", { closeWindows = true })
            return
        end

        if not C_LFGList or not C_LFGList.HasActiveEntryInfo or not C_LFGList.HasActiveEntryInfo() then
            return
        end

        self:UnregisterAllEvents()
        PrintQuickExitDebug("EVENT_LIST", "Active entry detected, scheduling leave")
        services.ScheduleOnce("lfg_quick_exit_leave_party", QUICK_EXIT_LEAVE_DELAY, function()
            local leaveSuccess, leaveErr = pcall(C_PartyInfo.LeaveParty)
            if not leaveSuccess then
                debugMsg("LFGQuickStart", "LeaveParty after listing failed: " .. tostring(leaveErr))
                FailQuickExit("EVENT_LEAVE", "LeaveParty after listing failed: " .. tostring(leaveErr), "Exit failed. Could not start the instance-exit countdown.")
                return
            end

            ShowQuickExitResult(QUICK_EXIT_COUNTDOWN_MESSAGE)
            PrintQuickExitDebug("EVENT_LEAVE", "LeaveParty after listing succeeded")
            QueueResetInstanceAfterExit(services)
            CloseQuickExitWindows()
        end)
    end)
end

PrintQuickExitDebug = function(stage, message, isFailure)
    if not IsQuickExitDebugEnabled() then
        return
    end

    local color = isFailure and "|cFFFF6666" or "|cFF66CCFF"
    print(color .. "JustQuest LFG Debug [" .. stage .. "]|r " .. tostring(message))
end

SuppressQuickExitWindows = function()
    if not PVEFrame or quickExitPVESuppressed then
        return
    end

    quickExitSavedPVEAlpha = PVEFrame:GetAlpha()
    quickExitSavedPVEMouseEnabled = PVEFrame:IsMouseEnabled()

    local alphaSuccess = pcall(PVEFrame.SetAlpha, PVEFrame, 0)
    if not alphaSuccess then
        PrintQuickExitDebug("UI_HIDE", "Failed to set PVEFrame alpha", true)
    end

    local mouseSuccess = pcall(PVEFrame.EnableMouse, PVEFrame, false)
    if not mouseSuccess then
        PrintQuickExitDebug("UI_HIDE", "Failed to disable PVEFrame mouse", true)
    end

    quickExitPVESuppressed = true
end

CloseQuickExitWindows = function()
    if quickExitPVESuppressed and PVEFrame then
        pcall(PVEFrame.SetAlpha, PVEFrame, quickExitSavedPVEAlpha or 1)
        pcall(PVEFrame.EnableMouse, PVEFrame, quickExitSavedPVEMouseEnabled and true or false)
        quickExitSavedPVEAlpha = nil
        quickExitSavedPVEMouseEnabled = nil
        quickExitPVESuppressed = false
    end

    if InCombatLockdown() then
        PrintQuickExitDebug("UI_CLOSE", "Skipped Group Finder close (in combat)")
        return
    end

    local closed = false
    if PVEFrame and PVEFrame:IsShown() then
        local hideSuccess, hideErr = pcall(HideUIPanel, PVEFrame)
        if hideSuccess then
            closed = true
        elseif PVEFrame.Hide then
            local hideFrameSuccess, hideFrameErr = pcall(PVEFrame.Hide, PVEFrame)
            if hideFrameSuccess then
                closed = true
            else
                PrintQuickExitDebug("UI_CLOSE", "PVEFrame hide failed: " .. tostring(hideFrameErr), true)
            end
        else
            PrintQuickExitDebug("UI_CLOSE", "HideUIPanel failed: " .. tostring(hideErr), true)
        end
    end

    if closed then
        PrintQuickExitDebug("UI_CLOSE", "Closed Group Finder window")
    end
end

local function ApplyQuickExitDefaultsNow(services, entryCreation)
    local debugMsg = services and services.Debug or function() end

    if entryCreation.PrivateGroup and entryCreation.PrivateGroup.CheckButton then
        local privateSuccess, privateErr = pcall(entryCreation.PrivateGroup.CheckButton.SetChecked, entryCreation.PrivateGroup.CheckButton, true)
        if not privateSuccess then
            debugMsg("LFGQuickStart", "PrivateGroup:SetChecked failed: " .. tostring(privateErr))
            PrintQuickExitDebug("DOWN_DEFAULTS", "Private toggle failed: " .. tostring(privateErr), true)
        end
    end

    local playstyleSuccess, playstyleErr = pcall(LFGListEntryCreation_OnPlayStyleSelectedInternal, entryCreation, QUICK_EXIT_PLAYSTYLE)
    if not playstyleSuccess then
        debugMsg("LFGQuickStart", "Playstyle selection failed: " .. tostring(playstyleErr))
        PrintQuickExitDebug("DOWN_DEFAULTS", "Playstyle selection failed: " .. tostring(playstyleErr), true)
    elseif entryCreation.PlayStyleDropdown then
        local dropdownUpdateSuccess, dropdownUpdateErr = pcall(entryCreation.PlayStyleDropdown.Update, entryCreation.PlayStyleDropdown)
        if not dropdownUpdateSuccess then
            debugMsg("LFGQuickStart", "PlayStyleDropdown:Update failed: " .. tostring(dropdownUpdateErr))
            PrintQuickExitDebug("DOWN_DEFAULTS", "Playstyle dropdown update failed: " .. tostring(dropdownUpdateErr), true)
        end
    end

    if C_LFGList and C_LFGList.SetEntryTitle and entryCreation.selectedActivity and entryCreation.selectedGroup then
        local titleSuccess, titleErr = pcall(
            C_LFGList.SetEntryTitle,
            entryCreation.selectedActivity,
            entryCreation.selectedGroup,
            entryCreation.selectedPlaystyle,
            entryCreation.generalPlaystyle
        )
        if not titleSuccess then
            debugMsg("LFGQuickStart", "SetEntryTitle failed: " .. tostring(titleErr))
            PrintQuickExitDebug("DOWN_DEFAULTS", "SetEntryTitle failed: " .. tostring(titleErr), true)
        end
    else
        PrintQuickExitDebug("DOWN_DEFAULTS", "SetEntryTitle skipped (activity/group not ready)")
    end

    local validStateSuccess, validStateErr = pcall(LFGListEntryCreation_UpdateValidState, entryCreation)
    if not validStateSuccess then
        debugMsg("LFGQuickStart", "UpdateValidState after quick-exit defaults failed: " .. tostring(validStateErr))
        PrintQuickExitDebug("DOWN_DEFAULTS", "UpdateValidState failed: " .. tostring(validStateErr), true)
    end
end

local function PrepareQuickExitOnMouseDown()
    local services = JustQuest.Core.GetModule("Services")
    if not services then
        return FailQuickExit("DOWN_INIT", "Services module unavailable", "Exit failed. Services are unavailable.")
    end

    quickExitResultShown = false
    quickExitMouseUpAction = nil

    if not services.IsAutomationEnabled or not services.IsAutomationEnabled() then
        return FailQuickExit("DOWN_INIT", "Automation disabled", "Exit unavailable while automation is disabled.")
    end

    if InCombatLockdown() then
        return FailQuickExit("DOWN_INIT", "Blocked by combat lockdown", "Exit blocked in combat.")
    end

    local inInstance = IsInInstance()
    PrintQuickExitDebug("DOWN_STATE", string.format("inInstance=%s inGroup=%s groupSize=%d",
        tostring(inInstance), tostring(IsInGroup() or IsInRaid()), GetNumGroupMembers() or 0))

    if not inInstance then
        return FailQuickExit("DOWN_STATE", "Not in an instance", "Exit unavailable outside an instance.")
    end

    -- 1. Direct exit: LFG teleport, grouped leave, solo party leave
    local exitSuccess, exitMsg = services.LeaveInstance()
    if exitSuccess then
        ShowQuickExitResult(QUICK_EXIT_SUCCESS_MESSAGE)
        PrintQuickExitDebug("DOWN_EXIT", "Direct exit: " .. tostring(exitMsg))
        QueueResetInstanceAfterExit(services)
        CloseQuickExitWindows()
        quickExitMouseUpAction = "handled"
        return true
    end
    PrintQuickExitDebug("DOWN_EXIT", "Direct exit unavailable, preparing LFG listing form")

    -- 2. LFG listing fallback (solo non-LFG instance): prepare form now, execute on mouse up

    if GroupFinderFrame and LFGListPVEStub then
        local showGroupSuccess, showGroupErr = pcall(GroupFinderFrame_ShowGroupFrame, LFGListPVEStub)
        if not showGroupSuccess then
            PrintQuickExitDebug("DOWN_OPEN", "ShowGroupFrame failed: " .. tostring(showGroupErr), true)
        end
    end

    local showSuccess, showErr = pcall(PVEFrame_ShowFrame, "GroupFinderFrame", "LFGListPVEStub")
    if not showSuccess then
        return FailQuickExit("DOWN_OPEN", "PVEFrame_ShowFrame failed: " .. tostring(showErr), "Exit failed. Could not open the quick-exit fallback.")
    end

    SuppressQuickExitWindows()

    local panel = LFGListFrame and LFGListFrame.CategorySelection
    local entryCreation = LFGListFrame and LFGListFrame.EntryCreation
    if not panel or not entryCreation then
        return FailQuickExit("DOWN_OPEN", "LFGList CategorySelection/EntryCreation not ready", "Exit failed. Quick-exit UI was not ready.", { closeWindows = true })
    end

    local categorySuccess, categoryErr = pcall(LFGListCategorySelection_SelectCategory, panel, QUESTING_CATEGORY, 0)
    if not categorySuccess then
        return FailQuickExit("DOWN_CATEGORY", "SelectCategory failed: " .. tostring(categoryErr), "Exit failed. Could not configure fallback category.", { closeWindows = true })
    end

    local showEntrySuccess, showEntryErr = pcall(LFGListEntryCreation_Show, entryCreation, LFGListFrame.baseFilters, QUESTING_CATEGORY, 0)
    if not showEntrySuccess then
        return FailQuickExit("DOWN_ENTRY", "EntryCreation_Show failed: " .. tostring(showEntryErr), "Exit failed. Could not configure fallback entry.", { closeWindows = true })
    end

    ApplyQuickExitDefaultsNow(services, entryCreation)

    local listButton = entryCreation.ListGroupButton
    if not listButton then
        return FailQuickExit("DOWN_ARM", "ListGroupButton missing", "Exit failed. Fallback action button was unavailable.", { closeWindows = true, unregisterEvents = true })
    end

    local isListEnabled = listButton:IsEnabled()
    PrintQuickExitDebug("DOWN_ARM", "ListGroupButton enabled=" .. tostring(isListEnabled))
    if not isListEnabled then
        return FailQuickExit("DOWN_ARM", "ListGroupButton disabled after defaults", "Exit failed. Fallback action is currently disabled.", { closeWindows = true, unregisterEvents = true })
    end

    BeginQuickExitLeaveAfterList(services)
    quickExitMouseUpAction = "list_then_leave"
    PrintQuickExitDebug("DOWN_READY", "Prepared listing form; mouse up will trigger ListGroup")
    return true
end

local function ExecuteQuickExitOnMouseUp()
    local services = JustQuest.Core.GetModule("Services")
    local debugMsg = services and services.Debug or function() end

    local action = quickExitMouseUpAction
    quickExitMouseUpAction = nil

    if not action then
        PrintQuickExitDebug("UP_INIT", "No prepared action from mouse down", true)
        return false
    end

    if action == "handled" then
        return true
    end

    PrintQuickExitDebug("UP_INIT", "Executing action=" .. tostring(action))

    if action ~= "list_then_leave" then
        return FailQuickExit("UP_INIT", "Unknown action: " .. tostring(action), "Exit failed. Unknown quick-exit action.")
    end

    local entryCreation = LFGListFrame and LFGListFrame.EntryCreation
    if not entryCreation then
        return FailQuickExit("UP_LIST", "EntryCreation unavailable on mouse up", "Exit failed. Fallback entry is unavailable.", { closeWindows = true, unregisterEvents = true })
    end

    local listButton = entryCreation.ListGroupButton
    if not listButton then
        return FailQuickExit("UP_LIST", "ListGroupButton missing on mouse up", "Exit failed. Could not trigger fallback action.", { closeWindows = true, unregisterEvents = true })
    end

    if not listButton:IsEnabled() then
        return FailQuickExit("UP_LIST", "ListGroupButton disabled on mouse up", "Exit failed. Fallback action is disabled.", { closeWindows = true, unregisterEvents = true })
    end

    local clickSuccess, clickErr = pcall(listButton.Click, listButton)
    if not clickSuccess then
        debugMsg("LFGQuickStart", "ListGroupButton:Click failed on mouse up: " .. tostring(clickErr))
        local listSuccess, listErr = pcall(LFGListEntryCreation_ListGroup, entryCreation)
        if not listSuccess then
            return FailQuickExit("UP_LIST", "Button click and ListGroup fallback both failed: " .. tostring(listErr), "Exit failed. Could not list fallback group.", { closeWindows = true, unregisterEvents = true })
        end

        PrintQuickExitDebug("UP_LIST", "ListGroup fallback succeeded")
    else
        PrintQuickExitDebug("UP_LIST", "ListGroupButton click sent")
    end

    PrintQuickExitDebug("UP_WAIT", "Waiting for LFG_LIST_ACTIVE_ENTRY_UPDATE")
    return true
end

SaveQuickExitButtonPosition = function()
    local config = GetConfigModule()
    if not config or not quickExitButton then
        return
    end

    local centerX, centerY = quickExitButton:GetCenter()
    if not centerX or not centerY then
        return
    end

    local uiCenterX = UIParent:GetWidth() / 2
    local uiCenterY = UIParent:GetHeight() / 2

    config.Set("lfgQuickExit", "buttonX", math.floor(centerX - uiCenterX + 0.5))
    config.Set("lfgQuickExit", "buttonY", math.floor(centerY - uiCenterY + 0.5))
    config.Set("lfgQuickExit", "positionInitialized", true)
end

local function ShouldShowQuickExitButton()
    local services = JustQuest.Core.GetModule("Services")
    if not services or not services.IsAutomationEnabled or not services.IsAutomationEnabled() then
        return false
    end

    if InCombatLockdown() then
        return false
    end

    local inInstance = IsInInstance()
    if not inInstance then
        return false
    end

    return true
end

local function UpdateQuickExitButtonVisibility()
    if not quickExitButton then
        return
    end

    if ShouldShowQuickExitButton() then
        ApplyInitialQuickExitPosition()
        quickExitButton:Show()
    else
        quickExitMouseUpAction = nil
        quickExitButton:Hide()
        if GameTooltip and GameTooltip:IsOwned(quickExitButton) then
            GameTooltip:Hide()
        end
    end
end

local function EnsureQuickExitVisibilityWatcher()
    if quickExitVisibilityFrame then
        return
    end

    quickExitVisibilityFrame = CreateFrame("Frame")
    quickExitVisibilityFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    quickExitVisibilityFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    quickExitVisibilityFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    quickExitVisibilityFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    quickExitVisibilityFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    quickExitVisibilityFrame:SetScript("OnEvent", function()
        UpdateQuickExitButtonVisibility()
    end)
end

-- Soft pulsing glow sized to the button. GlowEmitterFactory's templates use
-- fixed-size end-cap art tuned for large buttons (Enter World / Save Changes), which
-- pinches into an hourglass on a 56×22 button — so we roll a stretchable glow from
-- the classic proc-glow texture instead (still native, but geometry we control).
-- Shown until first use so new users can spot the button, then dismissed + remembered.
local function EnsureQuickExitGlow()
    if not quickExitButton then return nil end
    if quickExitButton.jqGlow then return quickExitButton.jqGlow end

    -- ButtonHilight-Square fills its own bounds (no invisible inset margin to guess),
    -- and SetAllPoints binds it to the button's exact rectangle, so the glow matches
    -- the button 1:1 at any size and can't mis-fit. ARTWORK sits above the backdrop
    -- but below the OVERLAY label, so "Exit" stays crisp.
    local glow = quickExitButton:CreateTexture(nil, "ARTWORK")
    glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1.0, 0.82, 0.25)  -- warm gold
    glow:SetAllPoints(quickExitButton)
    glow:Hide()

    local ag = glow:CreateAnimationGroup()
    ag:SetLooping("REPEAT")
    local up = ag:CreateAnimation("Alpha")
    up:SetFromAlpha(0.3); up:SetToAlpha(1.0); up:SetDuration(0.85); up:SetOrder(1); up:SetSmoothing("IN_OUT")
    local down = ag:CreateAnimation("Alpha")
    down:SetFromAlpha(1.0); down:SetToAlpha(0.3); down:SetDuration(0.85); down:SetOrder(2); down:SetSmoothing("IN_OUT")

    glow.anim = ag
    quickExitButton.jqGlow = glow
    return glow
end

local function ShowQuickExitGlow()
    local config = GetConfigModule()
    if config and config.Get("lfgQuickExit", "exitGlowSeen") then return end
    local glow = EnsureQuickExitGlow()
    if glow then
        glow:Show()
        glow.anim:Play()
    end
end

local function DismissQuickExitGlow()
    local glow = quickExitButton and quickExitButton.jqGlow
    if glow then
        glow.anim:Stop()
        glow:Hide()
    end
    local config = GetConfigModule()
    if config then config.Set("lfgQuickExit", "exitGlowSeen", true) end
end

local function CreateQuickExitButton()
    if quickExitButton then
        return
    end

    local config = GetConfigModule()
    local buttonX = (config and config.Get("lfgQuickExit", "buttonX")) or 280
    local buttonY = (config and config.Get("lfgQuickExit", "buttonY")) or -120

    local button = CreateFrame("Button", "JustQuestQuickExitButton", UIParent, "BackdropTemplate")
    if not button then
        return
    end

    quickExitButton = button
    button:SetSize(56, 22)
    if config and config.Get("lfgQuickExit", "positionInitialized") then
        button:SetPoint("CENTER", UIParent, "CENTER", buttonX, buttonY)
    else
        local point, relativeTo, relativePoint, offsetX, offsetY = GetQuickExitInitialAnchor()
        button:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
    end
    button:SetFrameStrata("MEDIUM")
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("RightButton")
    button:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 4,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    button:SetBackdropColor(0.18, 0.22, 0.26, 0.88)
    button:SetBackdropBorderColor(0.66, 0.72, 0.78, 0.95)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    label:SetText("Exit")
    button.label = label

    button:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveQuickExitButtonPosition()
    end)

    button:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton ~= "LeftButton" then
            return
        end

        DismissQuickExitGlow()
        PrepareQuickExitOnMouseDown()
    end)

    button:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton ~= "LeftButton" then
            return
        end

        ExecuteQuickExitOnMouseUp()
    end)

    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.24, 0.29, 0.33, 0.94)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("JustQuest Quick Exit", 1, 1, 1)
        GameTooltip:AddLine("LFG/delve/grouped: exits immediately", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Solo instance: starts 1-min exit countdown", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Right-drag: Move button", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.18, 0.22, 0.26, 0.88)
        GameTooltip:Hide()
    end)

    ShowQuickExitGlow()
    EnsureQuickExitVisibilityWatcher()
    UpdateQuickExitButtonVisibility()
end

-- ============================================================
-- Module Interface
-- ============================================================

function LFGQuickStart.Initialize()
    CreateQuickExitButton()
end

-- ============================================================
-- Module Registration
-- ============================================================

JustQuest.Core.RegisterModule("LFGQuickStart", LFGQuickStart, {"Services", "Config"})

return LFGQuickStart