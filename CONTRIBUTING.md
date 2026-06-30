# Contributing to JustQuest

Thank you for contributing to JustQuest.

This document is the quick-start for safe, consistent changes to this addon.

## Project Scope

JustQuest is a World of Warcraft addon focused on quest and gossip automation with strict safety controls.

Primary goals:
- Reduce repetitive quest-clicking friction.
- Preserve player control for risky or branching interactions.
- Prevent unsafe auto-selection loops.

## Development Setup

1. Clone this repository.
2. Place it in your live addon path:
   - `World of Warcraft/_retail_/Interface/AddOns/JustQuest`
3. Launch WoW and enable JustQuest.
4. Use `/jq` in game to confirm the addon loaded.

Optional local package build:
- Run `./build.ps1` from the repo root.

## Architecture Basics

Load order starts in `JustQuest.toc` and flows through core modules, services, and engines.

Key modules:
- `Core/*`: constants, module registry, config wrappers.
- `Services/*`: shared helpers (timers, safe calls, data).
- `Engines/*`: behavior and automation logic.

State safety model:
- `IDLE`, `QUEST`, `GOSSIP`, `HALT`
- Start with `SafetyEngine.SetState(...)`
- End with `SafetyEngine.EndProcessing(...)`

## Critical Workflow

1. NEVER guess WoW API behavior. Verify with in-game `/script` checks.
2. Propose behavior changes before implementation when safety logic is affected.
3. Do not auto-increment versions. Track active work in `UNRELEASED.md`.
4. Do not auto-build, push, tag, or release unless explicitly requested.
5. Do not add AI attribution text to project files or commit metadata.

## Coding Rules

Follow these standards:
- Use 4-space indentation.
- Keep all variables local unless intentionally in the `JustQuest` namespace.
- Prefer early returns over deep nesting.
- Wrap risky WoW API calls in `pcall()` or `Services.SafeCall()`.
- Avoid temporary debug prints in committed code.

See:
- `Documentation/STYLE_GUIDE.md`
- `Documentation/STYLE_GUIDE_AI.md`
- `.github/copilot-instructions.md`

## Safe Change Workflow

1. Search before editing.
2. Read nearby logic in target files (do not patch blind).
3. Propose intended behavior change clearly.
4. Implement minimal, focused edits.
5. Validate in game with simple `/script` checks.
6. Update docs/changelog notes if behavior changed.

## In-Game Verification

Useful checks:

```lua
/script local s=JustQuest.Core.GetModule("SafetyEngine"); print(s.GetState(), s.GetReason())
/script print(C_GossipInfo.GetNumOptions())
/script print(QuestFrame and QuestFrame:IsShown())
```

Also test:
- Quest accept and turn-in paths.
- Gossip options with colored text.
- Whitelist/blacklist behavior.
- Repeat protection and loop prevention.

## Pull Request Checklist

Before submitting:
- [ ] Change is scoped and minimal.
- [ ] Safety behavior is preserved or explicitly updated.
- [ ] No new globals introduced.
- [ ] No temporary debug output left behind.
- [ ] In-game smoke test completed.
- [ ] `UNRELEASED.md` updated for user-visible changes.
- [ ] Related docs updated when behavior changed.

## Versioning and Releases

- Do not bump versions, tag, or release unless explicitly requested by the maintainer.
- Keep `UNRELEASED.md` current during active development.

When a release is requested, use `release.ps1` (same flow as JustAC):

1. `.\release.ps1 -Version X.Y.Z` promotes `UNRELEASED.md` into `CHANGELOG.md`, bumps
   `JustQuest.toc`, and resets `UNRELEASED.md`. It prints the git commands; it does not
   commit.
2. Review the diff, then `git commit -m "release: X.Y.Z"`, `git tag vX.Y.Z`, and
   `git push --follow-tags`. The tag push triggers the CurseForge release workflow.

`build.ps1` produces a local test zip only and is not part of publishing.

## Questions

If requirements are unclear (especially around safety behavior), pause and ask before changing logic.
