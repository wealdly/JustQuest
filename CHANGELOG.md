# Changelog

## [Unreleased]

## [3.2.0] - 2026-07-06

### Bug Fixes

- **New quest steps that unlock mid-automation are no longer missed on a laggy server** — after an accept, turn-in, or gossip selection the follow-up check used to look only once; if the server hadn't sent the next step yet, automation stopped and you had to re-click the NPC. It now keeps checking briefly, while the quest/gossip window is still open, until the new step appears. Menus left for you to choose are unaffected.
- **Reward picking no longer undervalues green gear** — uncommon (green) equippable rewards are evaluated as possible upgrades instead of being treated as vendor trash.
- **Upgrade checks are accurate** — a reward counts as an upgrade only if its item level meets or beats what you have equipped, and both sides use effective item level so bonus-scaled quest rewards compare correctly.
- **Bind-on-equip gear halts sensibly** — automation pauses on BoE gear above your current average item level (instead of a fixed old threshold) so you decide whether to keep or sell it.
- **Mount/pet rewards detected on all clients** — collectible detection no longer relies on text matching, fixing missed mounts and pets on non-English clients.
- **Mixed item/currency reward quests fixed** — currency reward choices are recognized correctly, ending a retry loop on those quests.
- **Quests that charge gold pause for confirmation** — turn-ins that cost gold no longer pay automatically.
- **Currency and trade-item turn-ins pause for confirmation** — turn-ins that would spend currency (Flightstones, Honor, crafting materials, etc.) or hand over non-quest items now wait for you. Ordinary quest-item turn-ins still proceed automatically.
- **No more getting stuck at turn-in** — a dropped server message no longer strands automation with an invisible quest window; it restores and retries on its own within a second or two instead of making you walk away.
- **Fast mode hides quest-giver windows cleanly** — in fast mode the interface is hidden for quest mobs and for empty flavor dialog (which is auto-closed), while real vendor/trainer/service windows stay visible. A full multi-step quest-gossip chain stays hidden end to end without flickering, and is revealed only when you need to act — a manual reward pick, a menu with nothing to auto-select, a confirmation — or if automation stalls. Hold Shift/Ctrl/Alt to read a dialog yourself.
- **Fixed crashes from recent patches** — talking to NPCs could error out under a protected-value change in 11.x+; NPC identity checks and the debug inspector are now hardened.
- **Full quest log handled correctly** — removed the false "Accept FAILED" message. A full log is detected reliably: accepts pause while turn-ins keep freeing slots, until space opens — no spam, no false blocking.
- **Options panel listed under AddOns immediately** — settings register at login, so JustQuest appears in Game Menu → Options → AddOns right away instead of only after the first `/jq`.
- **Reward auto-selection no longer skips the next quest** — after a reward was left for you to pick, an internal guard could briefly block the following quest's reward; it's now always released.
- **Container opening leaves the currency prompt alone** — removed a stale path that could reset automation while the spend-currency confirmation was open.
- **Fixed a quick-exit startup crash.**

### New Features

- **Aggressive gossip — auto-advance to quests (on by default)** — a new NPCs-tab toggle. When on, JustQuest clicks through gossip dialog automatically to reach quests buried behind menus, advancing through multi-option menus rather than only quest-flagged or single-service ones. It prefers conversation options over vendor/trainer/banker ones so it heads toward quests instead of opening a shop, but still opens a service NPC when that's all a menu offers. It always stops and hands the menu back to you for real decisions: options that cost money or need a typed code, anything matching your dangerous-keyword blacklist (teleport, portal, campaign-skip and more ship by default), and menus the game forces open. Hold Shift/Ctrl/Alt to read any menu yourself. Turn the toggle off for the previous conservative behavior — only quest-indicated dialog and single service steps are automated.
- **Smarter reward upgrades with Pawn** — when Pawn is installed, reward picking uses your stat weights to rank upgrades, filtered to your spec, and falls back to item-level comparison when Pawn isn't present or has no matching scale. New Reward Selection options toggle Pawn scoring and choose whether it follows your Loot Specialization; a status line shows the active mode and spec. No setup or extra dependency required.
- **Class-appropriate armor rewards** — when a quest offers one item per armor type, auto-pick always chooses the highest armor type your class can wear. Weapons and accessories continue through stat/item-level scoring.
- **Currency turn-in confirmation** — when a turn-in would spend currency (Flightstones, Honor, Resonance Crystals, etc.) and the quest isn't whitelisted, a prompt lets you Spend Once, Always Allow (whitelists that quest for next time), or Cancel. A new panel in the Quests tab lists whitelisted quests and lets you remove them. Stored per character profile.
- **Quick-exit questing shortcut** — a movable on-screen `Exit` button (and `/lfgexit`) leaves LFG, delve, or grouped content immediately using Blizzard's direct-exit paths, or starts a listing-based exit when that's the only option. Delves use Blizzard's dedicated immediate-exit path. Each attempt reports a single status line: success, countdown started, or one concise failure. `/lfgqs` remains the manual shortcut.
- **Exit button is easier to spot** — the quick-exit button shows a soft pulsing glow until you click it the first time, then stops — easy for new players to find without staying flashy once you know where it is.
- **Reset instance on exit** — an optional General-tab toggle resets the instance after a successful quick-exit (deferred until you're actually outside, for delayed exits).

### Maintenance

- `/jq` now opens options by default; `/jq help` shows the command list; `/jq debug` toggles debug mode when run with no argument.
- Options UI text pass — shorter, clearer config descriptions, and a few pause messages now show plain language instead of an internal code.
- Gossip detection reworked internally — replaced fragile reading of the dialog window's colors with the game's own quest/service flags, plus a text fallback for older content.
- Smaller download and internal consolidation — removed a bundled database tool and dead code, and unified several internal paths. No behavior change.

## [3.1.1] - 2026-03-11

### Fixed
- Gossip delegation no longer blocked when NPC has incomplete active quests — options with "(Quest)" blue label are now auto-selected correctly
- Added `QuestLabelPrepend` flag detection to `IsQuestOption()` for reliable quest-linked gossip option identification
- Modifier key (Shift/Ctrl/Alt) bypass now enforced at all automation entry points including gossip engine, legacy quest greeting, and safety engine state machine

### Improved
- Defense-in-depth modifier checks added to `HandleGossip()`, `GossipEngine.OnGossipShow()`, `GossipEngine.OnGossipOptionsRefreshed()`, `ProcessLegacyQuestGreeting()`, and `SafetyEngine.BeginProcessing()`

## [3.1.0] - 2026-03-10

### Added
- Initial public release
- Quest auto-accept and auto-turn-in with safety filtering
- Gossip option auto-selection with quest priority, colored text detection, and whitelist/blacklist
- Smart reward selection (vendor value analysis, significant reward halt)
- Container auto-opening with customizable whitelist/blacklist and built-in database
- Safety engine with repeat protection, chain depth limits, and stuck-state recovery
- Fast mode (hidden frames during automation)
- Cinematic and movie skipping
- LFG Quick Start for solo dungeon entry
- Frame inspector (`/jq inspect`) for debugging NPC interactions
- AceDB profile support
