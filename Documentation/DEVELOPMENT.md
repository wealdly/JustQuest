# JustQuest Development Guide

This guide covers practical day-to-day development for JustQuest.

## 1. Live Development Layout

Recommended layout for fast iteration:
- Repo path: `.../Interface/AddOns/JustQuest`
- Run WoW with this folder directly loaded.
- Edit code, `/reload`, and verify behavior in game.

If developing outside the addon folder, use a directory symlink so WoW still loads the live working tree.

## 2. Build and Packaging

For local package output:

```powershell
./build.ps1
```

Output zip is created under `dist/`.

Packaging should mirror `JustQuest.toc` load order and include required libraries.

## 3. Module Loading and Dependencies

Load order is defined in `JustQuest.toc`.

Critical initialization chain:
1. `Core/Constants.lua`
2. `Core/Core.lua`
3. `Core/Config.lua`
4. `Services/Services.lua`
5. `Services/GameData.lua`
6. `Engines/*`

At file end, register modules through `JustQuest.Core.RegisterModule(...)`.

Always nil-check module lookups:

```lua
local config = JustQuest.Core.GetModule("Config")
if not config then return end
```

## 4. Safety-First Behavior

Never weaken safeguards without explicit approval.

Core protections:
- Colored gossip text detection.
- Whitelist and blacklist checks.
- Repeat protection against loops.
- ForceGossip handling.
- State-machine transitions (`IDLE`, `BUSY`) with recovery guards.

When changing any of these, test normal and edge cases in game.

## 5. Critical Workflow Guardrails

Apply these rules for every non-trivial change:
- NEVER guess WoW API behavior; verify with in-game checks.
- Propose before implementing when changing safety behavior.
- Do not auto-increment versions.
- Do not auto-build/push/tag/release unless explicitly requested.
- Do not add AI attribution strings to repo files.

## 6. Debug and Verification

### In-game checks

```lua
/script local s=JustQuest.Core.GetModule("SafetyEngine"); print(s.GetState(), s.GetReason())
/script print(C_GossipInfo.GetNumOptions())
/script print(QuestFrame and QuestFrame:IsShown())
```

### Behavioral smoke test

- Accept quest from NPC.
- Turn in completed quest.
- Process gossip menu with safe options.
- Validate colored option halt behavior.
- Validate blacklist skip behavior.
- Validate repeat protection under forced repeated menus.

## 7. Editing Conventions

- Prefer small targeted changes.
- Keep functions shallow; early-return on invalid state.
- Keep timing values in constants where possible.
- Namespace scheduled timers to avoid collisions (example: `QuestEngine_retry`).
- Use `Services.SafeCall(...)` around unstable APIs.

## 8. Documentation Updates

When behavior changes:
- Add user-facing notes to `UNRELEASED.md`.
- Update `README.md` for user-visible feature changes.
- Update `Documentation/STYLE_GUIDE.md` or `Documentation/STYLE_GUIDE_AI.md` when conventions change.

## 9. Release Flow (Maintainer-Driven)

Typical flow:
1. Implement and validate changes.
2. Keep `UNRELEASED.md` accurate.
3. Bump version only when instructed.
4. Build/test package.
5. Tag/release only when explicitly requested by maintainer.
