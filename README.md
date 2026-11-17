# JustQuest - Quest Automation

A World of Warcraft addon that automates quest acceptance, turn-in, gossip dialog selection, reward picking, and container opening — so you can focus on playing instead of clicking through NPC dialogs.

Tracks live retail; current on **12.1.0**.

## What It Does

JustQuest handles the repetitive parts of questing automatically:

- **Accepts quests** from NPCs, items, and proximity triggers
- **Starts quests from items in your bags** ("This Item Begins a Quest" — bound items only)
- **Answers story choices that only give a quest** (single option; real decisions stay yours)
- **Hints when a follow-up quest appears** after the quest giver's window has closed
- **Turns in completed quests** — prioritizes important/campaign quests
- **Selects gossip options** that lead to quests (blue "(Quest)" labeled options)
- **Opens services through small talk** — vendors, trainers, flight masters and the like fire immediately, even when parked behind a line of chatter
- **Picks quest rewards** intelligently (highest vendor value, or halts for significant upgrades)
- **Opens reward containers** from quest rewards automatically
- **Recommends gear upgrades** from your bags for the spec you're playing (optional, off by default)
- **Picks anima powers and starts the climb in Torghast** (optional, off by default)
- **Skips cinematics and movies** (optional)

When automation deliberately leaves a dialog open — a travel option, a forced choice, nothing safe to click — a short note at the bottom of the panel says why.

Hold any modifier key (Shift, Ctrl, Alt) at any time to instantly pause automation and interact manually. Hold one while you click an NPC and that whole conversation stays manual, even after you let go, until you talk to them again.

## Safety System

JustQuest is designed to be safe by default — it won't blindly click through everything.

### What It Avoids

- **Colored/warning text** — Halts on options with red/orange text (gold costs, teleports, consequences)
- **Blacklisted content** — Built-in database of known dangerous NPCs, quests, and gossip options
- **PvP quests** — Skipped unless explicitly enabled
- **Quests shared by other players** — Left for you to accept unless explicitly enabled
- **Story/branching choices** — Multiple colored options require manual selection
- **ForceGossip NPCs** — Menus the server marks "show the player" are never auto-advanced (whitelisted options are the deliberate exception)
- **Reward and event options** — Dialog options that grant items, cast a spell, or play a cinematic are left for you
- **Encounter starters** — Dialog exploration stands down in group instances, where the one conversation option is often "begin the fight"
- **Significant rewards** — Rare+ quality multi-choice rewards prompt manual selection

### Anti-Loop Protection

- Repeat protection prevents selecting the same gossip option twice in rapid succession
- Chain depth limits prevent infinite gossip loops
- Failed gossip cooldowns prevent retry spam
- Stuck-state recovery auto-resets automation after timeouts

## Features

### Fast Mode

Hides quest and gossip frames during automation for a seamless experience. Frames are instantly restored when you hold a modifier key or automation halts.

### Smart Reward Selection

- **Simple mode** — Always picks highest vendor value
- **Smart mode** — Analyzes item quality, equippability, and value; halts for meaningful choices
- Trivial rewards (green or below) are auto-selected for speed

### Container Auto-Opening

- **Auto-Open modes:** *My list only*, or *Openable containers* (default — clams, chests, coin sacks, and the like)
- Recognizes openable containers automatically from live game data — no need to whitelist each one
- Lockboxes are left alone: opening one takes a key or a lockpick, which only you can use
- Customizable whitelist and blacklist via `/jq container` commands or the config UI
- Respects bank/void storage (won't open containers at the bank)

### Gear Advisor

- Scores the gear in your bags for the spec you're playing and offers the best upgrade per slot — as you loot, and when you change specs
- Each suggestion waits for you: **Equip**, **Skip**, or **Never** for that item. **Equip All** when several are queued. Auto-Equip skips the asking entirely (out of combat only)
- Pawn does the scoring when it's installed with a scale for your spec; without it, upgrades are judged on item level and the prompt says "(by item level)" so you know it's the rougher call
- On WoW Forever, gear is scored by stats weighted for your class and a role you choose per character (melee / ranged / caster damage, tank, healer) — `/jq gear role`, `/jq gear stats`
- Never suggests the wrong armor type, the wrong primary stat, bind-on-equip items, or on-use travel gear mid-teleport
- Trinkets aren't scored

### Instances (Delves & Torghast)

- Delve difficulty: pre-selects your preferred tier and optionally enters. Only when the game is offering a delve — the same window drives lairs, whose tiers can queue you for a group, and those are left for you
- Torghast anima power selection from a curated safety-first list — powers that stop jumping, drain health, or cap speed are never taken; pick for clearing or for farming, with optional reroll
- Torghast wayfinder: selects your highest unlocked layer and starts the climb (group leader only, everyone gathered)
- Quick Exit for leaving instances and parties, with optional instance reset on the way out

### LFG Quick Start

- Auto-enters "specific dungeon" LFG when entering a dungeon solo
- Configurable per-dungeon enable/disable
- Stays out of battlegrounds and arenas

## Installation

1. Extract to `Interface\AddOns\JustQuest`
2. `/jq` to open options (`/jq help` for command list)

## Commands

```text
/jq              - Open options panel
/jq help         - Show help
/jq toggle       - Enable/disable addon
/jq config       - Open settings panel
/jq status       - Show current status
/jq debug [on|off] - Toggle debug logging
/jq inspect      - Inspect current NPC/quest frame state
/jq fast         - Toggle fast mode
/jq gear         - Gear advisor options
/jq delve        - Delve automation options
/jq torghast     - Torghast options (anima powers, climb)
/jq container add|remove|block|unblock|list <itemID>
                 - Manage container whitelist/blacklist
/jql             - Leave instance/party
```

## Configuration

Options are available via `/jq config` or the WoW AddOns settings panel. The main
**JustQuest** page is a short overview with the master switches; each category below
opens from the AddOns list.

| Section | Purpose |
|---------|---------|
| **Quests** | Which quests are accepted, and how their rewards are chosen — quest types, blocked quests, reward mode, currency costs |
| **NPCs** | How gossip menus are handled — aggressive vs conservative, whitelist/blacklist keywords |
| **Gear** | Upgrade recommendations, auto-equip, per-slot rules, the never-suggest list |
| **Instances** | Delve tier, Torghast anima powers and climb, Quick Exit and instance reset |
| **Containers** | Auto-open mode, whitelist/blacklist management |
| **Advanced** | Debug, timing controls, and the always-on safety summary |
| **Profiles** | AceDB profiles |

## Development Documentation

For contributor and AI-agent workflows:

- `CONTRIBUTING.md` - Contribution process and safety checklist
- `Documentation/DEVELOPMENT.md` - Live development and validation workflow
- `Documentation/STYLE_GUIDE.md` - Human-readable coding standards
- `Documentation/STYLE_GUIDE_AI.md` - AI-optimized coding and formatting rules
- `AGENTS.md` - Cross-agent operating guardrails

## Acknowledgments & Credits

### Libraries

**[Ace3 Framework](https://www.wowace.com/projects/ace3)**
*Created by the WoWAce Community*
AceDB, AceConfig, AceTimer — the backbone of addon configuration and scheduling.

**[LibStub](https://www.wowace.com/projects/libstub)**
*Created by Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke*
Library versioning system. Public domain.

### Blizzard Entertainment

For the quest and gossip APIs that make this addon possible.

### The WoW Addon Community

To everyone who has contributed to wowace.com, curseforge, GitHub discussions, and the countless forum threads that help addon developers learn and grow.

---

## License

GNU General Public License v3 (GPL-3.0-or-later) — See [LICENSE](LICENSE) for details.

The embedded Ace3 libraries retain their original licenses and are clearly marked in `Libs/`.

---

*JustQuest is not affiliated with or endorsed by Blizzard Entertainment.*
