# Changelog

## [Unreleased]

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
