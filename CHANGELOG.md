# Changelog

## [Unreleased]

## [3.3.0] - 2026-07-20

### Added
- New **Gear Advisor** (off by default). With the Pawn addon installed, JustQuest scores the gear in your bags for the spec you're playing and offers you the best upgrade for each slot — as you loot, and when you change specs (a nudge to swap to your intellect staff on a caster, for instance). Each upgrade waits for your decision: **Equip** it, **Skip** it for now, or **Never** suggest that item again — and you can hover the icon to compare it against what you're wearing. Turn on *Auto-Equip* to skip the asking and just equip them, out of combat; bind-on-equip items are always left for you to equip by hand. Trinkets aren't scored, and an item you couldn't wear because of a unique-equipped limit is never suggested. Find it under the new Gear tab.
- Gear suggestions show what you'd actually gain and lose — the biggest stat changes, gains in green and losses in red, next to the percentage. A percentage tells you how much better something is; it can't tell you it's trading your mastery for haste, which is the part you might want to decide differently. When several upgrades are waiting, the suggestion says how many and offers **Equip All**, so a full re-gear after a dungeon is one click instead of answering the same question for every slot.
- Two-handed weapon suggestions account for the off-hand they'd remove. The suggestion says which item comes off, and auto-equip won't take a two-hander that would silently unequip your shield or off-hand — that one always asks first.
- New **Protect Profession Gear** option (Gear tab, on by default). An equipped fishing pole or profession tool is never suggested away. They sit in ordinary equipment slots, so a stat-based score just sees weak gear — and would offer to replace them right before you want them.
- New **Respect Equipment Sets** option (Gear tab, on by default). Gear that belongs to one of your saved equipment sets is left alone, so a speed or utility set you're wearing on purpose doesn't get a "this is higher item level" suggestion every time something drops. It works slot by slot: only the pieces your set actually fills are held back, and every other slot is still offered as normal. Turn it off if you keep your everyday gear saved as a set.
- New **Delves** section (off by default). *Auto-Take Powers* takes your delve power for you instead of stopping you for it every few minutes. It's the one pop-up choice JustQuest will ever answer for you, and only inside a delve — because it isn't really a choice: you're offered a single power, and it's always worth taking. There's also an optional *Auto-Select Tier* for the difficulty picker, which can take you straight in if you want it to. Everywhere else, a choice window is still always yours.
- Container auto-open now has an **Auto-Open** mode: *My list only*, *Safe containers* (new default), or *Everything openable* (also lockboxes). In the Safe and Everything modes JustQuest recognizes openable containers automatically (clams, chests, coin sacks, and the like), so common ones open without you whitelisting each. Your blacklist still overrides everything.
- Rogues get an optional **Auto-Pick Lockboxes** toggle (in *Everything openable* mode) to pick and open lockboxes automatically.
- A small spinner now follows your cursor while JustQuest is working on something. Most of what it does is invisible — fast mode hides the quest window entirely, and a step waiting on the server looked exactly like a frozen addon. Quick steps stay silent: the spinner only appears if something takes longer than a moment, and it disappears the instant automation finishes.
- New **Summarize In Chat** option (General settings, off by default). When on, JustQuest prints one concise line at the end of each automation run — for example "accepted 2, turned in 1, opened 1 container" — so you can see what it did at a glance.

### Improved
- Dialogs are picked up faster. When the game announces an NPC menu it has already sent everything JustQuest needs, so it no longer pauses before reading it — the pause only remains where it's actually doing something, after an action. Noticeable most on quest hubs with several turn-ins.
- A hidden quest window in fast mode comes back on screen roughly twice as fast when automation stops early.

### Fixed
- Auto-skip cutscenes is now safer and smoother. It no longer touches vehicle or control cutscenes — the ones that put you into a quest vehicle or take control of your character (like the "interrogate/torture the suspect" quests that swap your abilities for a small set) — which could previously eject you mid-transition and disconnect you from the server. Regular cinematics and pre-rendered movies still skip instantly and now close cleanly. As an added safeguard, automation fully stands down whenever you're in a vehicle, possess, or special-ability-bar state.
- The delve difficulty picker is no longer treated as an ordinary dialog to click through. Its options are the difficulty tiers, and picking one takes you straight in — so auto-gossip could walk you into a delve at a tier you didn't choose, just for opening the picker. The picker is now left alone entirely unless you turn on the new Auto-Select Tier option.
- Going back to an NPC you'd already talked to now works properly, and automation no longer winds down the longer you quest. JustQuest only picks each dialog option once per conversation, but the end of a conversation wasn't always registering — so every NPC inherited the last one's history and JustQuest gradually ran out of things it was willing to click. If you opened a flight master's map and closed it without flying, or stepped away and came back, that option stayed used up. The same gap could leave a dialog open but invisible in fast mode, with no way to interact until you walked out of range. Conversations are now closed out properly, returning to an NPC is treated as a fresh one, and state recovery after a quest teleport works again — which is the main reason vendors, trainers, and flight masters "stopped working" on the second visit.
- Fixed a loop where JustQuest would click through the same NPC dialog over and over, several times a second, until you walked away. Ending a conversation can raise the "dialog closed" signal more than once, and only the first was recognised — so the second looked like you'd walked off, wiping its memory of which options it had already picked along with every safeguard against looping. Each option is now auto-selected at most once per conversation, so a menu that keeps re-showing (including on a laggy server) is left for you instead of looping.
- Auto-gossip no longer runs out of clicks partway through a dialog. Its per-conversation click budget was being charged twice for each step, so longer menus stalled before reaching the end.
- When a conversation offers something on your gossip blacklist — a portal, a teleport, or a campaign skip like "I have heard this tale before" — JustQuest now stops and shows you that menu instead of quietly clicking past it to a different option. That choice was previously made for you by omission, and in fast mode you never saw the option had been offered. Quest options and anything on your whitelist are still taken automatically.
- Turning JustQuest off and back on no longer leaves it half-dead for the rest of your session. Disabling it shut down the background check that recovers from a stuck step and reveals a hidden quest window, and re-enabling never started it again — so afterwards any hiccup became permanent, including an invisible dialog you could only clear by walking away. It now restarts properly.
- Follow-up quests are picked up without needing a second click. After finishing with an NPC, JustQuest re-checks for anything new they have to offer — but it treated "I looked and there was nothing yet" as "I'm done", so it stopped looking a fraction of a second before the quest actually arrived. It now keeps checking until the quest shows up or it's clear nothing is coming, which is why this was intermittent rather than constant.
- A quest turn-in the server won't accept — you're short on gold, the quest needs a group, or you're in the wrong phase — no longer jams everything behind it. JustQuest now moves on to the other quests the NPC has ready instead of retrying the same one indefinitely.
- Fixed a rare case where a turn-in that costs currency could leave automation stopped until you reloaded. If the confirmation prompt couldn't be shown (too many other pop-ups on screen, or you'd just died), JustQuest waited for an answer to a question that was never asked.
- Automation no longer gives up part-way through a quest hub when your target changes. Tab-targeting, a pet pulling aggro, or simply killing the mob you were fighting mid-conversation would cancel the rest of the run.
- Quests you've chosen not to auto-accept — PvP, escort, or repeatable ones — now keep their "click here to accept" pop-up so you can still take them by hand. Those pop-ups were being cleared away even when JustQuest deliberately left the quest alone.
- Auto-complete "click here to complete" quests (the ones that start or finish when you enter an area or use an object) now hand in reliably. Turn-ins are no longer skipped just because the quest is a PvP, escort, or repeatable type — those preferences only affect what gets auto-accepted, not what gets turned in.
- Auto-open now leaves quest items alone. Some quest containers are flagged the same way ordinary loot bags are, so "Safe containers" mode could open one out of order and consume it. Opening one is still possible by adding it to your own list.
- Containers now stop being retried once they've genuinely failed, instead of quietly getting their attempts back every minute.
- Auto-open no longer triggers while you're at the mailbox, auction house, vendor, or in a trade — moving items around in those windows looked like looting.
- Lootable containers (lockboxes, clams, and similar) now auto-open more reliably while actively looting, instead of being mistaken for a bag sort.
- Quest rewards you can't actually use are no longer offered. Reward picking checked that an item was equippable in general, not that *you* could equip it — so it could recommend plate to a mage, or a piece that needs a higher level than you've reached. It now respects level, class, armor type, and any other requirement the game itself would show you in red.
- Pawn-scored gear no longer calls a far lower item-level piece an upgrade. A stat score is measured against what you're already wearing, so if the piece in that slot has none of the stats your spec wants, nearly anything scored as an enormous improvement — occasionally by absurd margins like "+1178%". Item level is now the sanity check: something below the piece it would replace isn't an upgrade, however well its stats score.
- When a reward's item data hasn't finished loading, JustQuest now leaves the choice to you rather than risking an auto-pick of the wrong reward.
- Quests that require handing in trade goods or crafted items are now checked before any currency-spend prompt, so those items can't be consumed without warning.

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
