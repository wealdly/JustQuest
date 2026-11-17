-- GearToast.lua — the Gear Advisor's on-screen notice. Two kinds, told apart by whether
-- actions were given:
--   * a prompt ("Equip / Skip / Never") — waits for your decision, never fades
--   * a passive notice — reports what already happened, fades on its own
--
-- Built from the game's own art rather than a lookalike, so it reads as part of the UI:
-- the DiamondMetal "Dialog" nine-slice every current Blizzard dialog uses, and the loot
-- toast's quality border around the icon (LOOT_BORDER_BY_QUALITY, the same table the loot
-- roll frame reads). Layout follows Blizzard's loot roll — which is this exact shape: an
-- item, and the buttons that decide it.
--
-- Hover the icon for the item's tooltip (shift to compare against what you're wearing):
-- the question is "wear this or not", and a name alone can't answer it.
--
-- One toast at a time — the newest replaces the last. Only the icon and the buttons take
-- the mouse, so the frame never swallows a click meant for the world behind it.

local ADDON_NAME, JustQuest = ...

local GearToast = {}

local WIDTH      = 380
local PAD        = 16   -- frame edge -> content; clears the DiamondMetal corners
local ICON       = 52   -- the loot toast's item size (LootItemExtended); its border and
                        -- drop shadow are atlases sized to match, so they're taken as-is
local GAP        = 8
local BTN_W      = 76
local BTN_H      = 22
local FADE_AFTER = 4.5  -- passive notices only
local TEXT_W     = WIDTH - (PAD + ICON + GAP + PAD)

local frame, hideTimer

local function EnsureFrame()
    if frame then return frame end
    frame = CreateFrame("Frame", "JustQuestGearToast", UIParent)
    frame:SetWidth(WIDTH)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -200)
    frame:SetFrameStrata("DIALOG")  -- same strata Blizzard gives the loot roll

    -- The game's own dialog art: the DiamondMetal nine-slice over "UI-DialogBox-Background-
    -- Dark" — the same pairing StaticPopup builds itself from, and the reason this reads as
    -- solid rather than a translucent overlay. (The plain DialogBorderTemplate is the older
    -- parchment background; the Dark one is what current dialogs actually use.)
    -- Nine-sliced, so it stretches to any height without distorting — which the loot-toast
    -- art can't do: that's baked at a fixed 276x96 and has no room for a button row.
    -- Fills the parent and draws on BACKGROUND/BORDER, so ARTWORK content sits above it.
    frame.Border = CreateFrame("Frame", nil, frame, "DialogBorderDarkTemplate")

    -- The icon is the hover target: a tooltip anchor, not a click target. Sized to the art
    -- so it can't shadow the rest of the frame and block clicks.
    local hover = CreateFrame("Frame", nil, frame)
    hover:SetSize(ICON, ICON)
    hover:SetPoint("TOPLEFT", PAD, -PAD)
    hover:EnableMouse(true)
    hover:SetScript("OnEnter", function(self)
        if not frame.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(frame.link)
        GameTooltip:Show()
    end)
    hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.hover = hover

    -- The loot toast's item, piece for piece: a drop shadow under an uncropped icon, with
    -- the quality border framing it. Both atlases carry their own size.
    frame.shadow = hover:CreateTexture(nil, "BACKGROUND")
    frame.shadow:SetAtlas("loottoast-itemborder-shadow", true)
    frame.shadow:SetPoint("CENTER")

    frame.icon = hover:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints()

    frame.quality = hover:CreateTexture(nil, "OVERLAY")
    frame.quality:SetPoint("CENTER")

    -- Explicit widths, not RIGHT anchors: wrapping has to be resolved before layout runs,
    -- because the frame's height is measured off these strings.
    frame.head = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.head:SetPoint("TOPLEFT", hover, "TOPRIGHT", GAP, -1)
    frame.head:SetWidth(TEXT_W)
    frame.head:SetJustifyH("LEFT")

    frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.text:SetPoint("TOPLEFT", frame.head, "BOTTOMLEFT", 0, -3)
    frame.text:SetWidth(TEXT_W)
    frame.text:SetJustifyH("LEFT")

    frame.sub = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    frame.sub:SetPoint("TOPLEFT", frame.text, "BOTTOMLEFT", 0, -3)
    frame.sub:SetWidth(TEXT_W)
    frame.sub:SetJustifyH("LEFT")

    -- What you actually gain and lose. A percentage says how much better; only the stat
    -- line says whether the trade is one you want, which is the question when a piece
    -- swaps one secondary for another. Pre-coloured by the caller.
    frame.stats = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.stats:SetPoint("TOPLEFT", frame.sub, "BOTTOMLEFT", 0, -3)
    frame.stats:SetWidth(TEXT_W)
    frame.stats:SetJustifyH("LEFT")

    frame.buttons = {}
    for i = 1, 4 do
        local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        b:SetSize(BTN_W, BTN_H)
        b:Hide()
        frame.buttons[i] = b
    end

    -- Don't strand a tooltip on screen when the toast goes away under the cursor.
    frame:SetScript("OnHide", function()
        if GameTooltip:IsOwned(hover) then GameTooltip:Hide() end
    end)

    frame:Hide()
    return frame
end

-- info = {
--   link    = item link — the icon, its quality border, and the tooltip you get on hover
--   head    = heading ("Gear upgrade")
--   text    = the subject, usually the item link itself
--   sub     = dimmed detail ("+12% upgrade · replaces <item>"); optional
--   stats   = pre-coloured stat delta line ("+120 Haste  -85 Mastery"); optional
--   actions = { {text=, func=}, ... } — omit for a passive notice that fades.
--             Up to 4; laid out right-to-left so actions[1] reads leftmost.
-- }
function GearToast.Show(info)
    local f = EnsureFrame()
    f.link = info.link

    f.icon:SetTexture(info.link and C_Item.GetItemIconByID(info.link))
    -- Quality border, from the same lookup the loot roll uses — via ColorManager, which is
    -- where Blizzard intends colour overrides to land. Poor has no entry (and no upgrade
    -- ever will), so a missing atlas just means no border.
    local quality = info.link and C_Item.GetItemQualityByID(info.link)
    local atlas = quality and (
        (ColorManager and ColorManager.GetAtlasDataForLootBorderItemQuality
            and ColorManager.GetAtlasDataForLootBorderItemQuality(quality))
        or (LOOT_BORDER_BY_QUALITY and LOOT_BORDER_BY_QUALITY[quality]))
    if atlas then f.quality:SetAtlas(atlas, true) end
    f.quality:SetShown(atlas ~= nil)

    f.head:SetText(info.head or "JustQuest")
    f.text:SetText(info.text or "")
    f.sub:SetText(info.sub or "")
    f.sub:SetShown(info.sub ~= nil and info.sub ~= "")

    f.stats:SetText(info.stats or "")
    f.stats:SetShown(info.stats ~= nil and info.stats ~= "")

    -- Laid out right-to-left so the group hugs the right edge, but indexed forward so the
    -- caller's order reads left-to-right on screen: the action you most likely want first.
    local actions = info.actions
    local n = actions and #actions or 0
    local prev
    for i = #f.buttons, 1, -1 do
        local b, a = f.buttons[i], actions and actions[i]
        if a then
            b:SetText(a.text)
            -- Fit the label rather than assuming it. With four actions the row is close to
            -- the frame width, and a fixed width clips the longest one.
            local textW = b:GetFontString() and b:GetFontString():GetStringWidth() or 0
            b:SetWidth(math.max(BTN_W, math.ceil(textW) + 20))
            b:SetScript("OnClick", function()
                if hideTimer then hideTimer:Cancel(); hideTimer = nil end
                f:Hide()
                if a.func then a.func() end
            end)
            b:ClearAllPoints()
            if prev then
                b:SetPoint("RIGHT", prev, "LEFT", -GAP, 0)
            else
                b:SetPoint("BOTTOMRIGHT", -PAD, PAD)
            end
            prev = b
            b:Show()
        else
            b:SetScript("OnClick", nil)
            b:Hide()
        end
    end

    -- Height follows the text. An item link plus "replaces <item link>" wraps to two lines
    -- as often as not, and a fixed height would clip those and leave a hole under the rest.
    local textH = f.head:GetStringHeight() + 3 + f.text:GetStringHeight()
    if f.sub:IsShown() then textH = textH + 3 + f.sub:GetStringHeight() end
    if f.stats:IsShown() then textH = textH + 3 + f.stats:GetStringHeight() end
    local h = PAD + math.max(ICON, textH) + PAD
    if n > 0 then h = h + BTN_H + GAP end
    f:SetHeight(h)

    f:SetAlpha(1)
    f:Show()

    if hideTimer then hideTimer:Cancel(); hideTimer = nil end
    if n == 0 then
        -- Passive notice: fade out. A prompt does NOT — it waits for a decision, so nothing
        -- is silently suppressed just for timing out.
        hideTimer = C_Timer.NewTimer(FADE_AFTER, function()
            if UIFrameFadeOut then UIFrameFadeOut(f, 0.7, f:GetAlpha(), 0) end
            C_Timer.After(0.8, function() if f then f:Hide() end end)
        end)
    end

    -- A prompt is asking you to decide, so it gets an attention ping — never the "equipped!"
    -- sound, which reads as if the swap already happened.
    local snd
    if n > 0 then
        snd = SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_OPEN
    else
        snd = SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST
    end
    if not info.quiet then pcall(PlaySound, snd or 856, "Master") end
end

-- Take the toast down without a decision. A prompt waits indefinitely by design, so when
-- the question stops making sense — you equipped the item yourself, sold it, or it is no
-- longer the best pick — the asker needs a way to withdraw it.
function GearToast.Hide()
    if frame then frame:Hide() end
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

function GearToast.Initialize() end

JustQuest.Core.RegisterModule("GearToast", GearToast, {})

return GearToast
