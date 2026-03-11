-- LFGQuickStart.lua — Quick group creation interface module
-- Opens the group creation panel for manual entry; handles exit for different instance types.
--
-- EXIT BEHAVIOR:
--   • LFG/LFR/Delves: Instant teleport exit
--   • Mythic instances: Opens panel while inside (manual exit required)
--   • Other instances: Attempts auto-exit, falls back to opening panel
--   • Groups with others: Aborts (safety feature)
--
-- USAGE:  /lfgqs  |  JustQuest_LFGQuickStart()  |  LFG_QuickStart()
-- NOTE: WoW UI security requires manual title entry after the panel opens.

local ADDON_NAME, JustQuest = ...

local LFGQuickStart = {}

-- ============================================================
-- CONFIGURATION
-- ============================================================
local CONFIG = {
    CATEGORY = 6,                          -- 1=Questing, 2=Dungeons, 3=Raids, 4=Arena, 6=Custom
}

-- ============================================================
-- Core Functionality
-- ============================================================

-- Function to navigate to dungeon group creation panel
local function OpenDungeonGroupCreation()
    local services = JustQuest.Core.GetModule("Services")
    local debugMsg = services and services.Debug or function() end

    debugMsg("LFGQuickStart", "Checking group/instance status...")

    -- Check for combat lockdown
    if InCombatLockdown() then
        print("|cFFFF0000JustQuest LFG:|r Cannot create group while in combat")
        return
    end

    -- Check current group/instance status
    local inInstance, instanceType = IsInInstance()
    local inGroup = IsInGroup() or IsInRaid()
    local groupSize = GetNumGroupMembers()
    local instanceName, _, difficultyID = GetInstanceInfo()
    local isMythicDungeon = (difficultyID == 8 or difficultyID == 23 or difficultyID == 24)

    -- SAFETY: If in a group with other people, abort
    if inGroup and groupSize > 1 then
        print("|cFFFF0000JustQuest LFG:|r You are in a group with other players. Please leave manually if you want to create a new group.")
        return
    end

    -- Handle solo instance scenarios
    if inInstance then
        -- Check if this is an instantly-exitable instance (LFG/LFR/Delve)
        local canInstantExit = false

        -- Check for LFG content
        if IsInLFGDungeon and IsInLFGDungeon() then
            -- LFG dungeon/raid/delve - can teleport out
            print("|cFF00FF00JustQuest LFG:|r Teleporting out of LFG instance...")
            local success, err = pcall(LFGTeleport, true)
            if success then
                -- Wait for teleport, then open panel
                services.ScheduleOnce("lfg_teleport_wait", 2.0, function()
                    OpenDungeonGroupCreation()
                end)
                return
            else
                debugMsg("LFGQuickStart", "LFGTeleport failed: " .. tostring(err))
            end
        end

        -- Check for Mythic/Mythic+ (difficulties 8, 23, 24)
        if isMythicDungeon then
            -- Can't instant exit Mythic - just open the panel while inside
            print("|cFFFFAA00JustQuest LFG:|r In Mythic instance - opening group panel...")
            print("|cFF888888Note: You'll need to exit the instance manually|r")
            -- Continue to open panel below
        else
            -- Unknown instance type - try to exit if solo
            if groupSize <= 1 then
                print("|cFFFFAA00JustQuest LFG:|r Attempting to leave instance...")
                local leaveSuccess, leaveMessage = services.LeaveInstance()
                if leaveSuccess then
                    print("|cFF00FF00JustQuest LFG:|r " .. leaveMessage)
                    services.ScheduleOnce("lfg_leave_wait", 2.0, function()
                        OpenDungeonGroupCreation()
                    end)
                    return
                else
                    -- Can't auto-exit, continue to open panel
                    print("|cFFFFAA00JustQuest LFG:|r Cannot auto-exit - opening panel anyway")
                end
            end
        end
    end

    -- If we're solo in a group (shouldn't happen, but just in case)
    if inGroup and groupSize <= 1 then
        print("|cFFFFAA00JustQuest LFG:|r Leaving empty group...")
        local success = pcall(C_PartyInfo.LeaveParty)
        if success then
            services.ScheduleOnce("lfg_leave_group_wait", 0.5, function()
                OpenDungeonGroupCreation()
            end)
            return
        end
    end

    -- Open the LFG panel (in Mythic or non-instance case)
    debugMsg("LFGQuickStart", "Opening LFG panel...")

    -- Step 1: Open Group Finder
    if not GroupFinderFrame or not GroupFinderFrame:IsVisible() then
        PVEFrame_ToggleFrame()
    end

    -- Step 2: Navigate to Custom groups
    services.ScheduleOnce("lfg_show_frame", 0.2, function()
        if GroupFinderFrameGroupButton4 then
            GroupFinderFrameGroupButton4:Click()

            -- Step 3: Select Custom category (6)
            services.ScheduleOnce("lfg_select_custom", 0.2, function()
                if LFGListFrame and LFGListFrame.CategorySelection then
                    LFGListCategorySelection_SelectCategory(LFGListFrame.CategorySelection, 6, 0)
                    debugMsg("LFGQuickStart", "Selected Custom category")

                    -- Step 4: Click Start Group
                    services.ScheduleOnce("lfg_start_group", 0.2, function()
                        if LFGListFrame.CategorySelection.StartGroupButton then
                            LFGListFrame.CategorySelection.StartGroupButton:Click()
                            debugMsg("LFGQuickStart", "Opened group creation panel")

                            -- Show status based on instance
                            if inInstance and isMythicDungeon then
                                print("|cFF00FF00JustQuest LFG:|r Group panel ready (still in Mythic instance)")
                                print("|cFFFFFF00Fill in details, list group, then exit instance manually|r")
                            else
                                print("|cFF00FF00JustQuest LFG:|r Group creation panel ready - fill in details")
                            end
                        end
                    end)
                end
            end)
        end
    end)
end

-- ============================================================
-- Public API
-- ============================================================

-- Global function for macro use
function JustQuest_LFGQuickStart()
    local services = JustQuest.Core.GetModule("Services")
    if not services then
        print("|cffff0000JustQuest:|r Services module not loaded")
        return
    end

    if not services.IsAutomationEnabled() then
        print("|cffffaa00JustQuest:|r LFG Quick Start requires automation to be enabled")
        return
    end

    if InCombatLockdown() then
        print("|cFFFF0000JustQuest LFG:|r Cannot create group while in combat")
        return
    end

    OpenDungeonGroupCreation()
end

-- Alternative global function name for convenience
function LFG_QuickStart()
    JustQuest_LFGQuickStart()
end

-- ============================================================
-- Slash Commands
-- ============================================================

SLASH_LFGQUICKSTART1 = "/lfgqs"
SLASH_LFGQUICKSTART2 = "/lfgdungeon"
SlashCmdList["LFGQUICKSTART"] = function(msg)
    if InCombatLockdown() then
        print("|cFFFF0000JustQuest LFG:|r Cannot create group while in combat")
        return
    end

    JustQuest_LFGQuickStart()
end

-- ============================================================
-- Module Interface
-- ============================================================

function LFGQuickStart.Initialize()
end

function LFGQuickStart.StartDungeonGroup()
    JustQuest_LFGQuickStart()
end

-- ============================================================
-- Module Registration
-- ============================================================

JustQuest.Core.RegisterModule("LFGQuickStart", LFGQuickStart, {"Services"})

return LFGQuickStart