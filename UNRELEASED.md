## [Unreleased]

### Bug Fixes

- **Green gear no longer fast-pathed to vendor value** — any equippable choice is now treated as non-trivial regardless of quality; only non-equippable, non-currency, sub-rare items are skipped.
- **Upgrade comparison is now strict** — reward must meet or exceed equipped item level (`ITEM_LEVEL_BUFFER` 5 → 0).
- **Effective item level used for comparisons** — both reward and equipped item level now come from `C_Item.GetDetailedItemLevelInfo`, accounting for bonus IDs on scaled quest rewards.
- **Locale-independent collectible detection** — mount/pet detection replaced locale-dependent string comparisons with classID/subclassID enum checks; fixes false negatives on non-English clients.
- **BoE "significant" threshold is now player-relative** — halts on BoE gear above the player's current average equipped item level rather than the obsolete absolute floor of ilvl 60.
- **Currency choice rewards handled correctly** — currency slots detected via `GetQuestItemInfoLootType`; fixes retry-spin on mixed item/currency reward quests.
- **Expensive-quest payment guard** — `SelectReward` now checks `GetQuestMoneyToGet()` and halts for manual confirmation if the quest costs gold.
- **Currency and trade-item turn-in guard** — `OnQuestProgress` now checks for required currencies (`GetNumQuestCurrencies`) and required non-quest-class items (`GetNumQuestItems` + classID check) before calling `CompleteQuest`. Quests that cost Flightstones, Honor, crafting materials, or any non-quest-class item halt for manual confirmation. Pure quest-item turn-ins (classID 12) proceed automatically. Uncached item links also halt to be safe.

### New Features

- **Quick-exit questing shortcut** — `/lfgexit` now uses direct exit APIs when Blizzard provides them, then opens the same `Premade Groups > Questing > Start a Group` entry form the manual workaround uses. The quick-exit path preselects `Learning` and `Private` and leaves `/lfgqs` as the separate manual Custom-panel shortcut. The on-screen `Exit` button now runs a strict staged flow: **mouse down** prepares Questing listing (defaults + watcher arming), **mouse up** triggers List Group and leaves party to start the exit timer. Stage-tagged debug output (`DOWN_*`, `UP_*`, `EVENT_*`) is printed so failures are pinpointed immediately.
- **Quiet quick-exit UX** — quick-exit now suppresses Group Finder visibility during fallback setup and emits a single final chat status line per attempt (direct success, Blizzard countdown started, or one concise failure), instead of stage-by-stage chat spam.
- **Quick-exit reset option** — new `Reset Instance On Exit` toggle (General tab) optionally runs `ResetInstances()` after quick-exit succeeds. For delayed ejection exits, reset is deferred until the player is actually outside the instance.
- **Delve direct-exit integration** — instance exit now checks walk-in party state first and calls `C_PartyInfo.DelveTeleportOut()` before generic party/LFG fallback logic, ensuring Delves use Blizzard's dedicated immediate exit path when available.
- **Pawn stat-weight upgrade scoring** — `CompareWithEquipped` now calls Pawn when installed. Scales are filtered to the player's effective spec (class+spec match first, class-only second, generic last; other-class and other-spec scales ignored). Multiple upgrades are ranked by Pawn `PercentUpgrade`; falls back to ilvl delta when Pawn is absent or has no applicable scales. Soft dependency — no `.toc` change required.
- **Pawn options** — Reward Selection panel adds "Use Pawn for Upgrade Scoring" (default on) and "Follow Loot Specialization" (default on — uses the loot spec setting from the character portrait menu to pick Pawn scales, rather than the active playing spec). A live status line shows which mode and spec is active. Both toggles grey out when Pawn is not installed or Simple Reward Mode is enabled.
- **Currency turn-in confirmation popup** — when a quest requires currency (Flightstones, Honor, Resonance Crystals, etc.) and the quest is not whitelisted, a dialog prompts: "Spend Once" proceeds once; "Always Allow" whitelists the quest so future turn-ins proceed automatically; "Cancel" halts automation. The whitelist is stored per-profile.
- **Currency Spending Whitelist panel** — new group in the Quests options tab lists all whitelisted quests (with quest name, ID, and currency summary) and provides a dropdown to remove individual entries.

### Maintenance

- Removed orphaned constants and unused locals/no-op branches across core/services/engines/interface modules (no behavior change).
- `/jq` now opens options by default; `/jq help` shows the command list; `/jq debug` toggles debug mode when called with no argument.
- Options UI text pass: shortened and clarified config descriptions.
