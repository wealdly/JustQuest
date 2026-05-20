# JustQuest Style Guide

Human-readable coding conventions for JustQuest.

For AI-optimized parsing rules, see `Documentation/STYLE_GUIDE_AI.md`.

## 1. Core Principles

- Keep automation safe by default.
- Optimize for readability and maintainability.
- Prefer explicit, minimal, testable changes.

Operational guardrails:
- Do not guess WoW API behavior; verify with in-game checks.
- Do not auto-bump versions or auto-release.
- Do not add AI attribution text to repository content.

## 2. Lua and Namespace Rules

- Use one global namespace only: `JustQuest`.
- Use addon namespace pattern at top of files:

```lua
local ADDON_NAME, JustQuest = ...
```

- Default all variables to `local`.
- Avoid creating global helper variables/functions.

## 3. Naming Conventions

- Module/table names: PascalCase (`SafetyEngine`, `QuestEngine`).
- Public module functions: PascalCase (`SafetyEngine.SetState`).
- Local/private functions: lower camel style (`processQuest`, `hasColorCode`).
- Constants: UPPER_SNAKE_CASE.
- Booleans should read naturally (`isEnabled`, `shouldHalt`, `hasReward`).

## 4. Formatting

- Indent with 4 spaces (no tabs).
- Use spaces around operators and after commas.
- Keep lines reasonably short; hard cap 120 chars.
- Use trailing commas in multi-line tables.

## 5. Control Flow

- Prefer early returns over nested condition pyramids.
- Keep function responsibilities narrow.
- Split complex selection logic into helper functions.

## 6. Error Handling and API Safety

- Protect risky WoW API calls with `pcall()`.
- Prefer `Services.SafeCall(...)` when available.
- Fail safely: on uncertainty, do not auto-select risky options.

## 7. State Machine Discipline

Use the SafetyEngine state model consistently:
- Enter processing state before action.
- Exit with `EndProcessing(...)` on all completion paths.
- Avoid paths that can leave module in a busy state.

## 8. Timers and Scheduling

- Namespace timer keys by module (`QuestEngine_retry`, `GossipEngine_recheck`).
- Cancel timers when exiting or invalidating state.
- Keep timing constants centralized in `Core/Constants.lua`.

## 9. Data and Table Usage

- Dot notation for known keys.
- Bracket notation for dynamic keys only.
- Keep table schemas consistent across modules.

## 10. Documentation and Comments

- Add concise comments for non-obvious logic only.
- Document public APIs and module entry points.
- Update docs when behavior or safety rules change.

## 11. Testing Expectations

At minimum, verify in game:
- Quest accept/turn-in flow.
- Gossip automation safe-path behavior.
- Colored-text halt behavior.
- Blacklist skip behavior.
- Repeat protection against loops.

## 12. Source of Truth

If this file and `STYLE_GUIDE_AI.md` diverge:
- Human readability and repo maintainability take priority for coding style.
- AI-specific operational rules remain in `STYLE_GUIDE_AI.md`.
