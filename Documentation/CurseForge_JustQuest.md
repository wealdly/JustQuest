**JustQuest automates quest accepting, turn-ins, gossip and rewards.**

It handles the repetitive clicking and stops when a decision is actually yours. Current on 12.1.0.

Hold Shift, Ctrl or Alt at any time to pause it and deal with an NPC yourself. Hold one as you click the NPC and the whole conversation stays yours until you talk to them again.

## What it does

- Accepts quests from NPCs, items and proximity triggers
- Turns in finished quests, campaign quests first
- Finds quest dialog buried in gossip menus
- Opens vendors, trainers and flight masters on the first click, even behind small talk
- Picks rewards by vendor value, or stops when the choice matters
- Opens containers sitting in your bags
- Skips cinematics

## What it won't do

- Click options with red or orange text — gold costs, teleports, consequences
- Answer anything the server gates behind a confirmation or a typed code
- Explore dialog inside group instances, where the one option is often "start the fight"
- Choose between rare-or-better rewards when there's more than one
- Accept PvP quests or quests other players share, unless you turn those on
- Open lockboxes, which need a key or a lockpick you have to use yourself

When it leaves a dialog alone, a note at the bottom of the panel says why.

## Features

**Quests** — Auto-accept and auto-turn-in. Block individual quests by ID. Choose whether trivial and repeatable quests count.

**NPCs** — Aggressive mode (default) works through menus to reach quests buried in conversation. Conservative mode only takes quest-flagged options and single service steps. Keyword whitelist and blacklist for both.

**Rewards** — Simple mode takes the highest vendor value. Smart mode weighs quality and whether you can use it, and stops for real choices. Reward containers open themselves.

**Gear Advisor** — Scores gear in your bags for your current spec and offers the best upgrade per slot. Equip, Skip, or Never for each one; Equip All when several are waiting; Auto-Equip if you'd rather not be asked. Pawn does the scoring if you have it with a scale for your spec, otherwise it compares item level and says so. Skips the wrong armor type, the wrong primary stat, BoE items, and your teleport cloak mid-cast. Trinkets aren't scored.

**Containers** — Opens clams, chests, coin sacks and similar from your bags, recognized from game data rather than a hand-maintained list. Whitelist and blacklist as you like. Nothing opens at the bank.

**Delves** — Pre-selects your preferred tier and optionally enters. Delves only: the same window sets lair difficulty now, and some lair tiers queue you for a group.

**Torghast** — Picks anima powers from a curated list. Powers that stop you jumping, drain health or cap speed are never taken, and a power that states its own drawback is refused. Pick for clearing or for farming, with an optional reroll. The wayfinder selects your highest unlocked layer and starts the climb.

**Quick Exit** — Leaves an instance or party from one button, with optional instance reset. Stays out of battlegrounds and arenas.

**LFG Quick Start** — Auto-enters the specific-dungeon queue when you walk into a dungeon solo. Configurable per dungeon.

**Fast Mode** — Hides quest and gossip frames while automation runs, so a turn-in loop doesn't flash the screen at you. They come back instantly when you hold a modifier.

## Options

Anything that answers a pop-up for you is off until you turn it on — gear advice, delve tiers, anima powers, the climb, cinematic skipping, LFG quick start.

`/jq` opens the panel, `/jq help` lists commands, `/jq inspect` shows what JustQuest is seeing if you want to know why it did or didn't act. Per-profile settings via Ace3.

---

*JustQuest is not affiliated with or endorsed by Blizzard Entertainment.*
