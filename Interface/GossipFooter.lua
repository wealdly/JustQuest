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

-- The ScrollBox is NOT flush with the parchment: it runs past the bottom of the paper art
-- and over the dark backdrop underneath. From GossipFrame.xml, both measured down from the
-- GreetingPanel top: the Material textures stop at 444 (MaterialTopLeft at y=-75, height
-- 241, then MaterialBotLeft height 128), while the ScrollBox stops at 468 (y=-65, height
-- 403). Sitting the note on the ScrollBox bottom therefore lands it 22px onto the dark
-- backdrop, where dark quest ink is unreadable. Both are fixed sizes anchored to the panel,
-- so this gap is constant - no runtime measuring needed.
local PARCHMENT_GAP = 24  -- ScrollBox bottom -> bottom edge of the paper
local NOTE_MARGIN   = 4   -- breathing room above the paper's edge; raise if it still crowds

local function EnsureText()
    if text then return text end
    if not GossipFrame then return nil end
    -- The note belongs INSIDE the parchment reading area, with the rest of the text.
    -- The frame's own bottom edge is the button bar (GoodbyeButton lives there, dark
    -- wood — dark ink is invisible on it), so anchor to the ScrollBox, which is the
    -- scrolling content region — then lift clear of the paper's bottom edge, since the
    -- ScrollBox overhangs it (see PARCHMENT_GAP).
    local region = GossipFrame.GreetingPanel and GossipFrame.GreetingPanel.ScrollBox
                   or GossipFrame
    -- The FontString must live on a RAISED child frame, not on the panel itself: a
    -- region on a frame renders at that frame's base level, underneath the parchment
    -- art on higher-level children — the first version was painted over. Children
    -- keep their level offset when the UIPanel manager rebases the parent, so +20
    -- stays on top. No EnableMouse: the holder is a level host, never a click target.
    local holder = CreateFrame("Frame", nil, GossipFrame)
    local bottom = (region == GossipFrame) and NOTE_MARGIN or (PARCHMENT_GAP + NOTE_MARGIN)
    holder:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 4, bottom)
    holder:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -4, bottom)
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
