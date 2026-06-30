# AGENTS

Guidelines for AI coding agents working in this repository.

Primary reference files:
- `.github/copilot-instructions.md`
- `Documentation/STYLE_GUIDE_AI.md`
- `Documentation/STYLE_GUIDE.md`
- `Documentation/DEVELOPMENT.md`

## 1. Mission

Implement safe, minimal, and verifiable improvements to JustQuest without weakening safety protections.

## 2. Required Workflow

1. Search for existing logic before editing.
2. Read the specific target area before proposing changes.
3. Explain intended behavior change clearly and ask before safety-impacting changes.
4. Apply the smallest practical patch.
5. Validate behavior using in-game checks.
6. Update docs and `UNRELEASED.md` for user-visible changes.

## 3. Safety Constraints

Do not weaken these protections without explicit maintainer approval:
- Colored text halt behavior.
- Blacklist and whitelist safety checks.
- Repeat protection/anti-loop controls.
- ForceGossip protective handling.
- Busy-state gating in SafetyEngine.

If uncertain about risk level, halt and ask.

## 4. Coding Constraints

- Keep all non-namespace values local.
- Follow 4-space indentation.
- Prefer early returns.
- Use `pcall()` or `Services.SafeCall(...)` for unstable APIs.
- Avoid adding temporary debug code in committed files.

## 5. Module Access Pattern

```lua
local module = JustQuest.Core.GetModule("ModuleName")
if not module then return end
```

Use nil-checks for module dependencies before calling methods.

## 6. Verification Commands

Recommended in-game checks:

```lua
/script local s=JustQuest.Core.GetModule("SafetyEngine"); print(s.GetState(), s.GetReason())
/script print(C_GossipInfo.GetNumOptions())
/script print(QuestFrame and QuestFrame:IsShown())
```

Also verify modifier-key pause behavior and at least one full quest accept/turn-in path.

## 7. Release and Version Guardrails

Do not bump versions, build, commit, tag, push, or publish unless explicitly
requested. Keep `UNRELEASED.md` current during feature and fix work.

When a release is requested, the flow (same as JustAC) is:

1. `.\release.ps1 -Version X.Y.Z` — promotes `UNRELEASED.md` into `CHANGELOG.md`
   under a new `## [X.Y.Z] - date` heading, bumps `JustQuest.toc`, and resets
   `UNRELEASED.md`. It does not commit; it prints the git commands.
2. Review the diff.
3. `git commit -m "release: X.Y.Z"` → `git tag vX.Y.Z` → `git push --follow-tags`
   (the tag push triggers `.github/workflows/release.yml` → CurseForge).

Releases are cut from the working branch. `build.ps1` only makes a local test zip
and is not part of publishing.

## 8. Attribution Guardrail

- Never add AI attribution lines (for example, `Co-Authored-By`) to commits, docs, or source files.

## 9. Multi-Agent Consistency

If multiple AI tools are used, this file is the shared behavior contract.

When conflict exists between agent defaults and repo docs, follow repo docs.
