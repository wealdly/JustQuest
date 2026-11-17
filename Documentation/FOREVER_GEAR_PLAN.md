# Forever gear scoring and disposition

## Goal

Use one gear verdict for recommendations and automatic junk classification.
Keep an upgrade, gear worth auctioning/trading, gear reserved for an alt, and
explicitly protected items. Vendor a confirmed non-upgrade only after those
protections pass. Unknown is never equivalent to non-upgrade.

## Implementation

1. Correct the existing class/role model:
   - Apply weapon-type bonuses only to weighted weapon DPS.
   - Group alternate talent ranks explicitly; let distinct passives stack.
   - Compare complete replacement packages, including the off-hand displaced by
     a two-hander even when the main hand is empty.
   - Return the destination slot and both scores, avoiding item-level inference
     when choosing which of two rings or weapons to replace.
   - Label heuristic changes as score changes, not actual performance gains.
   - Do not promote required level to a stat upgrade; missing weapon DPS and
     unrecognized nonzero stat keys leave the result unknown.
2. Expose a versioned, read-only Forever scoring API:
   - Use class/role scoring by default; when selected, use one visible,
     class-compatible Pawn scale consistently for recommendations, rewards, and
     the selling safeguard.
   - Return upgrade, not_upgrade, or unknown with a reason.
   - Work independently of advisor enablement, Skip/Never, and display thresholds.
   - Keep all positive gains safe, including gains below the prompt threshold.
   - Treat missing data, unsupported slots, trinkets, effects that the stat model
     cannot value, and incomplete weapon transitions as unknown.
3. Align the selling pipeline:
   - On Forever replace item-level/Pawn selling gates with the shared verdict.
   - Do not reject lighter armor using retail armor-specialization rules.
   - Retain manual and equipment-set protections, account/warband items, refund
     and group-trade windows, category controls, and auction-value safeguards.
   - Missing provider or uncertain verdict means keep non-grey gear.
   - Preserve retail selling behavior and existing grey-junk policy.
   - Reevaluate before selling and refresh bag markers when scoring inputs change.
4. Verify with mocked Lua regressions and syntax checks, then deploy the touched
   selling-addon files to its Forever installation without overwriting unrelated
   changes.

The initial integration uses the scoring provider when installed; it does not
duplicate scoring or add a hard dependency. Junk classification means eligible
for vendor sale, never automatic destruction.

## Acceptance cases

- Lower raw item level with better Forever stats is kept as an upgrade.
- Positive gains below the advisor's minimum are still kept.
- Known non-upgrade soulbound gear becomes a vendor candidate.
- Valuable/unpriced transferable gear, account-bound gear, active group-trade
  loot, saved sets, and manual keeps remain protected.
- Missing provider/data or unsupported effects keep gear.
- Two-hand comparisons include displaced off-hands; rings use the actual weaker
  destination, including two copies with the same item ID.
- Separate weapon passives stack, alternate ranks do not, and non-DPS stats are
  not multiplied by weapon bonuses.
- Retail and non-gear category behavior remains unchanged.

## Later enhancements requiring verified Forever data

- Optional playstyle and alternate-role keep profiles.
- Hit/defense/weapon-skill caps and breakpoints.
- Weapon-speed, main/off-hand penalties, and class-specific attack models.
- Curated proc, on-use, relic, and set-bonus valuation.
- Explicit alt reservations rather than inferring every transferable item is
  valuable to an alt.

Do not invent formulas or advertise weighted-score ratios as DPS, healing, or
survival percentages. Unmodeled mechanics stay uncertain until supported.

## Shared API

`JustQuest.GearScoring.version == 1`

`JustQuest.GearScoring.EvaluateItem(itemLink)` returns a table:

- `status`: `upgrade`, `not_upgrade`, or `unknown`.
- `reason`: a diagnostic explanation.
- Unknown results include `retryable`: whether the advisor should use its bounded
  settle retries. Consumers must not infer retry behavior from diagnostic wording;
  either value still means keep the item, never a disposal verdict.
- A known result also includes `isUpgrade`, `candidateScore`, `baselineScore`,
  `destinationSlot`, `existingItemLink`, `byClassStats`, and
  `pawnPercentUpgrade` (the legacy internal field for a score ratio).
- `displacedOffHand`: the off-hand link included in the replacement package.

Consumers must keep unknown results and API failures. They must not treat a
missing recommendation, Skip/Never, advisor disablement, or a score percentage
below the prompt threshold as proof an item should be sold.

The advisor, smart quest-reward comparisons, and selling safeguard use the same
Forever verdict by default. In the Gear settings, a character may instead select
one of their visible, class-compatible Pawn scales; the chosen scale is used
consistently across those features. Pawn's Forever scales may represent individual
talent trees.
Multiple-choice smart rewards with unknown gear scores require manual selection.

## Shared internals

- GameData supplies item stats (including tooltip armor) and comparable-slot
  rules to both class scoring and advisor presentation. The advisor retains its
  own explicit trinket/cosmetic exclusions.
- ClassWeights owns cache invalidation for Forever level, learned-spell, and
  talent events, independently of advisor enablement or presence.
- `JustQuest.GearScoringChanged` notifies consumers after invalidation. The
  optional reason is `"role"` for a role selection, or the triggering game event.
  The advisor subscribes to refresh recommendations; JustJunk refreshes markers.
- Legacy score-result field names remain compatible with API version 1.

## Validation

The implementation has 78 mocked Lua 5.1 regression cases in
[ForeverGearScoring.lua](../Tests/ForeverGearScoring.lua), covering the API,
advisor, smart rewards, markers, and selling pipeline. Load that test file with
the addon roots as its two arguments. Non-library Lua files also pass syntax
compilation. Live client behavior still needs an in-game reload and smoke test.

Before enabling automated gear sales, select the intended character role in the
Gear tab. Keep alternate-role, resistance, and utility sets explicitly. The
current model is deliberately not a full character simulator.
