# JustQuest - Quest Automation

A World of Warcraft addon that automates quest acceptance, turn-in, gossip dialog selection, reward picking, and container opening — so you can focus on playing instead of clicking through NPC dialogs.

## What It Does

JustQuest handles the repetitive parts of questing automatically:

- **Accepts quests** from NPCs, items, and proximity triggers
- **Turns in completed quests** — prioritizes important/campaign quests
- **Selects gossip options** that lead to quests (blue "(Quest)" labeled options)
- **Picks quest rewards** intelligently (highest vendor value, or halts for significant upgrades)
- **Opens reward containers** from quest rewards automatically
- **Skips cinematics and movies** (optional)

Hold any modifier key (Shift, Ctrl, Alt) at any time to instantly pause automation and interact manually.

## Safety System

JustQuest is designed to be safe by default — it won't blindly click through everything.

### What It Avoids

- **Colored/warning text** — Halts on options with red/orange text (gold costs, teleports, consequences)
- **Blacklisted content** — Built-in database of known dangerous NPCs, quests, and gossip options
- **PvP and escort quests** — Skipped unless explicitly enabled
- **Story/branching choices** — Multiple colored options require manual selection
- **ForceGossip NPCs** — Lore/story NPCs can be configured to halt automation
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

- Opens whitelisted containers received as quest rewards
- Customizable whitelist and blacklist via `/jq container` commands or the config UI
- Built-in database of common quest reward containers
- Respects bank/void storage (won't open containers at the bank)

### LFG Quick Start

- Auto-enters "specific dungeon" LFG when entering a dungeon solo
- Configurable per-dungeon enable/disable

## Installation

1. Extract to `Interface\AddOns\JustQuest`
2. `/jq` to see available commands

## Commands

```text
/jq              - Show help
/jq toggle       - Enable/disable addon
/jq config       - Open settings panel
/jq status       - Show current status
/jq debug on|off - Toggle debug logging
/jq inspect      - Inspect current NPC/quest frame state
/jq container add|remove|block|unblock|list <itemID>
                 - Manage container whitelist/blacklist
/jql             - Leave instance/party
```

## Configuration

Options are available via `/jq config` or the WoW AddOns settings panel:

| Section | Purpose |
|---------|---------|
| **Quest** | Auto-accept, auto-turn-in, escort quests, trivial quests, quest items, PvP quests |
| **Gossip** | Gossip automation, ForceGossip handling |
| **Rewards** | Auto-reward, simple vs smart mode |
| **Containers** | Auto-open, whitelist/blacklist management |
| **Cinematics** | Skip cinematics and movies |
| **Advanced** | Timeouts, fast mode, debug, LFG quick start |
| **Profiles** | AceDB profiles |

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
