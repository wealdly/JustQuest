-- AutomationIndicator.lua — the "still working" notice shown while automation is running.
--
-- Automation is mostly invisible: fast mode hides the quest/gossip panel outright, and
-- even with the panel up, a step waiting on the server looks identical to a frozen addon.
-- This is the smallest thing that tells the player the difference.
--
-- It rides the cursor, the way an OS busy pointer does. That is where the player is
-- already looking after clicking an NPC, and it works for automation with no frame behind
-- it at all (container opening, reward selection) — which a notice anchored to a panel
-- cannot. It never takes the mouse, so a click meant for the world behind it always gets
-- through.
--
-- Deliberately plain: a spinner glyph and a label in the default font, no art and no UI
-- template, so there is nothing to break across a patch and nothing to taint.

local ADDON_NAME, JustQuest = ...

local AutomationIndicator = {}

-- Long enough that ordinary automation never shows it. Quick steps staying silent is the
-- entire point of fast mode; only a step that has actually stalled is worth announcing.
local SHOW_AFTER  = 0.6
local SPIN_PERIOD = 0.1
-- Give up eventually. Stuck-state recovery gets many attempts inside this window, so
-- anything still "busy" past it is wedged rather than working — and a spinner glued to
-- the cursor for the rest of the session is worse than no spinner at all.
local MAX_VISIBLE = 10
-- Plain ASCII: renders in the default font on every client and locale. A prettier glyph
-- set is a font gamble for no real gain at this size. Built complete at load rather than
-- concatenated per tick — the spinner advances 10x a second for as long as it is up.
local FRAMES      = { "| JustQuest", "/ JustQuest", "- JustQuest", "\\ JustQuest" }
-- Down-right of the cursor hotspot, clear of the pointer art itself.
local OFFSET_X, OFFSET_Y = 18, -22

-- Memoized accessors: StillWorking runs from OnUpdate, i.e. every frame while visible,
-- and an uncached GetModule there is a string-keyed lookup 60x a second for nothing.
local GetSafety   = JustQuest.Core.ModuleGetter("SafetyEngine")
local GetServices = JustQuest.Core.ModuleGetter("Services")

local frame, armedAt, expiresAt, uiScale, lastX, lastY

local function StillWorking()
    local safety = GetSafety()
    return safety and safety.IsBusy and safety.IsBusy()
end

local function EnsureFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "JustQuestAutomationIndicator", UIParent)
    frame:SetSize(120, 16)
    frame:SetFrameStrata("TOOLTIP")  -- above the panels it reports on
    frame:Hide()
    -- No EnableMouse: a readout, never a click target.

    frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.Text:SetPoint("LEFT")
    frame.Text:SetJustifyH("LEFT")

    frame:SetScript("OnUpdate", function(self, elapsed)
        -- This is the retirement path, not just a redraw: automation ending is noticed
        -- here rather than pushed in, so a missed notification can't strand the spinner.
        -- MAX_VISIBLE caps it regardless, in case BUSY itself is stuck.
        if not StillWorking() or GetTime() > expiresAt then
            AutomationIndicator.Hide()
            return
        end

        -- Follow the cursor. GetCursorPosition reports in screen pixels, so it has to be
        -- divided by the effective scale to land in UIParent's coordinate space. Re-anchor
        -- only on actual movement — a cursor resting still while a step waits on the
        -- server is the common case, and re-anchoring dirties layout every frame for it.
        local x, y = GetCursorPosition()
        if x ~= lastX or y ~= lastY then
            lastX, lastY = x, y
            self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
                          (x / uiScale) + OFFSET_X, (y / uiScale) + OFFSET_Y)
        end

        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < SPIN_PERIOD then return end
        self.elapsed = 0
        self.step = ((self.step or 0) % #FRAMES) + 1
        self.Text:SetText(FRAMES[self.step])
    end)

    return frame
end

-- Arm rather than show. If automation finishes inside SHOW_AFTER — the common case —
-- Hide() cancels it and nothing ever appears.
function AutomationIndicator.Show()
    if armedAt then return end  -- already armed or visible; don't restart the clock
    armedAt = GetTime()

    local services = GetServices()
    if not (services and services.ScheduleOnce) then return end

    services.ScheduleOnce("automation_indicator_show", SHOW_AFTER, function()
        -- Re-check rather than trust the arming: automation blips through IDLE between
        -- steps, so "was busy 0.6s ago" is not "is busy now". If it finished in the
        -- meantime, disarm here — nothing else is going to.
        if not armedAt then return end
        if not StillWorking() then armedAt = nil return end

        local f = EnsureFrame()
        f.step = 0
        f.elapsed = 0
        f.Text:SetText(FRAMES[1])
        -- Resolved once per appearance, not per frame: it walks the parent scale chain.
        uiScale = UIParent:GetEffectiveScale()
        if not uiScale or uiScale <= 0 then uiScale = 1 end
        expiresAt = armedAt + MAX_VISIBLE
        lastX, lastY = nil, nil
        f:ClearAllPoints()
        f:Show()
    end)
end

function AutomationIndicator.Hide()
    armedAt = nil
    local services = GetServices()
    if services and services.CancelScheduled then
        services.CancelScheduled("automation_indicator_show")
    end
    if frame then frame:Hide() end
end

function AutomationIndicator.Initialize() end

function AutomationIndicator.OnDisable()
    AutomationIndicator.Hide()
end

JustQuest.Core.RegisterModule("AutomationIndicator", AutomationIndicator, {"Services"})

return AutomationIndicator
