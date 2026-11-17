# Client compatibility: Retail and WoW Forever in one addon

One branch, one release, both clients (the JustAC model). Quest, gossip, reward and container
automation is shared; what differs is gear scoring and a short list of client behaviours.

## Rules

1. **One client predicate.** `JustQuest.Constants.IS_FOREVER` in `Core/Constants.lua`, from
   `WOW_PROJECT_CAMELOT` (only defined by the Forever client). Nothing else tests the client.
2. **Gate where everything routes through.** `Services/GearScoring.lua` refuses to score off
   Forever (`EvaluateItem` returns unknown), and `Services/ClassWeights.lua` only registers its
   events on Forever, so callers need no guard of their own.
3. **Retail behaviour stays as it is unless a change is meant for both.** Universal changes are
   deliberate and listed below.
4. **Client cases are tested as both clients.** `python tools/run_lua_tests.py` runs `Tests/*.lua`
   and `tools/*_check.*`; the files set `WOW_PROJECT_ID` / `IS_FOREVER` per case.
   `Tests/ForeverGearScoring.lua` loads JustJunk too, so a JustJunk checkout must sit next to this one.

## Deploying

Both clients load the same files: edit this checkout, then
`python D:\.src\WOW\WOW\00-SOURCE\tools\deploy_just_runtime.py --apply JustQuest JustQuest-forever`.
`tools/sync_forever.ps1` (a `/MIR` copy into the Forever AddOns folder with a rewritten TOC
interface) was retired: the TOC lists both interface versions, and the Forever AddOns folder is now
a junction into a runtime copy that a mirror would overwrite.

## Forever-only behaviour (gated)

- Gear scoring through `GearScoring.lua`: class and role weights or a selected Pawn scale
  (`gearSwap.foreverPawnScales`), armour from the tooltip, weapon DPS from the tooltip,
  rank-aware weapon bonuses, unknown verdicts for effects/unknown stats/missing data.
- Ranged slot, trained armour types, no class primary-stat rule (see `tools/gear_forever_check.lua`).
- Verified ordinary reward consumables (`GameData` `FOREVER_ORDINARY_REWARDS`) and reward ranking
  that does not discard better lighter armour.

## Retail/Forever merge (2026-11-17)

The Forever copy was mirrored from the Retail working tree by `tools/sync_forever.ps1` and developed
in place. On branch `merge/forever`: `pre-merge/retail-wip` (Retail WIP), `pre-merge/forever`
(Forever import), then the merge review. Every Forever change was accepted for both clients:

- Normal-mode step pace (`TIMING.STEP_PACE`, `Services.NoteStep` / `PaceWait`) for quest windows,
  gossip and dispatch; fast mode unchanged.
- One coalesced dispatch for `GOSSIP_SHOW`, `QUEST_GREETING`, `GOSSIP_OPTIONS_REFRESHED`; content
  snapshots per pass; gossip options fingerprinted for failed-menu cooldowns.
- Single-option doorway step in both modes; forced menus keep their quest options for the player.
- Currency approvals revalidated at the click; missing quest IDs and blocked completions left for
  the player; legacy greetings share the modern quest filter.
- Quest-bound required items accepted for turn-in; special or uncertain multi-choice rewards
  require a manual pick (`special_reward_choice`).
- Required quest-loot containers (`containers.openQuestLoot`, default on).
- Opt-in debug timing for phases of 2 ms or more.

`tools/gear_forever_check.lua` was updated to the Forever scoring rules (no primary-stat
rejection, unknown stats and required level not scored, effect-detection stubs, GearScoring loaded
as the TOC loads it).
