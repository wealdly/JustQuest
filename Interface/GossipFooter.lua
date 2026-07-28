-- GossipFooter.lua — one line at the bottom of the gossip panel saying why automation
-- left this menu for the player.
--
-- When automation surfaces a menu it just stops, and a surfaced menu looks identical to
-- automation being broken. This is the smallest thing that says "on purpose, and here's
-- why". A bare FontString parented to GossipFrame: it shows and hides with the panel,
-- nothing to click, nothing to taint. GossipEngine owns the wording and the lifecycle
-- (cleared on each new menu and on every successful auto-selection).

local ADDON_NAME, JustQuest = ...

local GossipFooter = {}

local text  -- FontString, created on first use (GossipFrame exists at login on retail,
            -- but lazy creation keeps load order irrelevant)

local function EnsureText()
    if text then return text end
    if not GossipFrame then return nil end
    -- The note belongs INSIDE the parchment reading area, with the rest of the text.
    -- The frame's own bottom edge is the button bar (GoodbyeButton lives there, dark
    -- wood — dark ink is invisible on it), so anchor to the ScrollBox, which is the
    -- parchment content region (GossipFrame.xml: it ends ~28px above the frame
    -- bottom, right where the button bar starts).
    local region = GossipFrame.GreetingPanel and GossipFrame.GreetingPanel.ScrollBox
                   or GossipFrame
    -- The FontString must live on a RAISED child frame, not on the panel itself: a
    -- region on a frame renders at that frame's base level, underneath the parchment
    -- art on higher-level children — the first version was painted over. Children
    -- keep their level offset when the UIPanel manager rebases the parent, so +20
    -- stays on top. No EnableMouse: the holder is a level host, never a click target.
    local holder = CreateFrame("Frame", nil, GossipFrame)
    holder:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 4, 2)
    holder:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -4, 2)
    holder:SetHeight(1)  -- the FontString hangs off the anchors; the holder only hosts a frame level
    holder:SetFrameLevel(GossipFrame:GetFrameLevel() + 20)
    -- QuestFontNormalSmall is what Blizzard puts on this parchment (the body text is
    -- QuestFont); it inherits the dark ink color, so the note reads as part of the
    -- panel rather than an addon overlay. No SetTextColor — the font object's own
    -- color is the native one.
    text = holder:CreateFontString(nil, "OVERLAY", "QuestFontNormalSmall")
    text:SetPoint("BOTTOMLEFT")
    text:SetPoint("BOTTOMRIGHT")
    text:SetJustifyH("CENTER")
    return text
end

function GossipFooter.SetNote(note)
    local fs = EnsureText()
    if not fs then return end
    fs:SetText(note or "")
    fs:SetShown(note ~= nil and note ~= "")
end

function GossipFooter.Clear()
    if text then
        text:SetText("")
        text:Hide()
    end
end

function GossipFooter.Initialize() end

function GossipFooter.OnDisable()
    GossipFooter.Clear()
end

JustQuest.Core.RegisterModule("GossipFooter", GossipFooter)

return GossipFooter
