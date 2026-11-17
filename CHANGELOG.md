# Changelog

## [Unreleased]

## [3.6.0] - 2026-11-17

### Changed
- Holding Shift, Ctrl or Alt when you click an NPC now keeps that whole conversation manual,
  including any quest you open from it, even after you let go of the key. Talk to the NPC again
  without the key to hand it back to JustQuest. Before, letting go could let automation take
  over a quest or reward you had opened to read.
- Quests JustQuest won't take (low-level, a quest type you've turned off, blocked, not yet
  complete, or a full quest log) no longer stop it from handling the rest of that NPC.
  A vendor, flight master or trainer that also offers such a quest is now handled like any
  other.

- Quest chains at one NPC move faster and more steadily: the next quest is picked up as soon
  as the NPC offers it, instead of sometimes waiting an extra moment.

- Quest items in your bags that say "This Item Begins a Quest" now start their quest for you
  (outside combat, when no NPC window is open). Only items bound to you are used — tradeable
  ones such as Darkmoon Faire decks are left alone — and your quest settings and blocked list
  apply. Option: "Start Quests from Items in Bags".
- Story windows with a single option that gives you a quest are now answered for you, like any
  other quest accept. Windows with more than one option, ones that ask "are you sure?", and any
  in a group instance are always left for you. Option: "Accept Story Choices That Give a Quest".
- New hint: when a follow-up quest appears right after the quest giver's window has closed,
  JustQuest tells you it's ready and which key talks to them again. The game decides whether
  to reopen that window at the moment you turn in, and addons can't reopen it, so one key press
  is the fastest way back in. Option: "Next-Quest Hint".
- New option: "Accept Shared Group Quests" (Quests → Quest Types). Escort and group quests a
  party member shares with you are accepted for you, and your other quest settings and blocked
  list now apply to them too. Off by default.
- JustQuest now recognises vendors, trainers, flight masters, banks and similar windows from
  the game's own interaction signal, so it reliably stays out of the way of any of them,
  including ones it didn't know by name before.

- Gear advisor on WoW Forever now judges upgrades by the stats that matter to your class and
  role, instead of item level. Choose this character's role (melee, ranged or caster damage,
  tank, healer — whichever your class can do) in the Gear tab or with `/jq gear role`.
  Quest rewards are chosen the same way. `/jq gear stats` shows how your equipped gear
  scores. Weapon bonuses from your race and talents count too: a human's swords, an orc's
  axes, a dwarf's maces, and talents like Two-Handed Weapon Specialization tip the choice
  toward those weapon types when the alternatives are close.
- Gear advisor on WoW Forever: pick which Pawn scale JustQuest uses for this character
  ("Pawn Scale (WoW Forever)" in the Gear tab), or leave it on JustQuest's class and role
  weights. Gear with effects JustQuest can't score (on-use, on-equip, procs, set bonuses),
  unknown stats or data that hasn't loaded is kept instead of being guessed at, and lighter
  armour counts as an upgrade when it scores higher.
- New option: "Required Quest-Loot Containers" (Containers, on by default). Opens a container
  in your bags when it supplies an unfinished objective of a quest you've accepted, including
  one you were already carrying when you took the quest.
- NPC windows with a single option that isn't conversation (a trainer's "show me your skills",
  a lone service) are now taken in conservative mode too, and on menus the game forces open.
  Never while the NPC has quest work for you, never a conversation option, and never inside an
  instance with a group.
- Menus the game forces open (it asks you to choose) no longer have their quest options picked
  for you.
- Quest windows, gossip and the next quest in a chain now move at an even pace in normal mode
  (about a quarter of a second between steps) instead of some answering instantly and others
  after a pause. Fast mode is unchanged.
- Turn-ins that need items bound to the quest are completed for you even when those items
  aren't in the "quest item" category. Ordinary materials and gear still ask first.
- Multi-choice rewards that include a recipe, book, profession item, collectible, currency or
  anything JustQuest can't assess are left for you to pick, checked again at the moment of
  choosing.
- Debug mode reports any automation step that takes 2 ms or longer.
- Gear advisor and quest rewards only offer weapons and armour you've learned to use. On WoW
  Forever a warrior isn't offered a bow before training Bows, and a hunter isn't offered mail
  before 40. Once you train the skill, the gear is offered straight away.
- Gear advisor and quest rewards never pick profession tools as weapons. A Mining Pick,
  Skinning Knife, Blacksmith Hammer or fishing pole stays in your bags even if it hits harder
  than your sword.

### Fixed
- Gear advisor on WoW Forever:
  - Armour upgrades work for every class. Pieces that are only armour (no other stats) now
    count their armour, so 29-armour bracers replace 4-armour ones. Gear is no longer hidden
    for being lighter than your class's usual armour type; on Forever a warrior in leather
    bracers is just a warrior with better bracers.
  - Bows, guns, crossbows, wands, thrown weapons and relics are compared against and equipped
    into the ranged slot, not the main hand.
  - Gear with another role's main stat (Intellect on a warrior, Strength on a mage) is scored
    by your class and role weights rather than offered or rejected on that stat alone.
  - Pawn-only settings are hidden there.
- Gear advisor on WoW Forever: recommendations work. The advisor's background check stopped
  with an error on every scan there, so nothing was ever suggested or equipped even though
  `/jq gear check` found the upgrades.
- Gear advisor: upgrades already in your bags are found after logging in. Before, an item
  whose details hadn't loaded yet at login was skipped and never looked at again until
  something else in your bags changed. With Auto-Equip on, upgrades you log in carrying are
  now equipped too, not just ones you loot afterwards.
- Gear advisor: a one-handed weapon is no longer offered for your off-hand unless you can
  dual wield, and never in place of a shield or off-hand item.
- Gear advisor: after you learn a new armour or weapon skill at a trainer, gear you can now
  wear is offered straight away instead of on the next level-up.
- The Gear tab now lists upgrades when Pawn isn't installed. It used to say the advisor
  needed Pawn and show nothing, even though upgrades were being found by item level.
- Quest rewards: guns, crossbows and wands (and, on retail, bows) are no longer treated as
  automatic upgrades. They're compared against the weapon you actually have.
- After a turn-in or accept, JustQuest now reliably picks up the NPC's next quest, even when
  it takes a few seconds to appear. Fast mode no longer closes the NPC's dialog as "nothing
  here" in the moment before the follow-up quest shows up, and JustQuest no longer walks off
  to the NPC's vendor or other dialog options while a follow-up is on its way. It also keeps
  looking during combat, through a slow-to-reopen dialog, and past a popup that was briefly
  on screen. Older-style quest givers that re-open their quest list right after a turn-in
  are no longer skipped.
- Turn-ins that need a quest item you haven't seen before no longer stop with "Quest requires
  an item that hasn't loaded yet".
- Quest rewards with several choices are picked as soon as their details load, and slow-loading
  rewards are less likely to be handed back to you.
- Picking up a quest elsewhere (a bonus objective or world quest) no longer closes a quest
  window you have open.
- Gear advisor: "Equip All" now handles bind-on-equip gear properly. Everything that needs no
  confirmation is equipped straight away, and the bind-on-equip pieces are asked about one at a
  time. Previously each new "this will bind to you" prompt replaced the last one, so only the
  final item could actually be equipped while the addon reported all of them as equipped.
  Declining one skips that piece for the session and carries on with the rest, and nothing is
  equipped while a bind prompt is on screen.
- When several quests show a "click here to complete" or "click here to accept" popup at
  once, they are now handled one after another. Before, only the last one opened and the
  others' popups disappeared.
- In fast mode, a quest window JustQuest leaves for you (a quest type you've turned off, or a
  quest that isn't ready to hand in) now appears right away. Before, it could stay invisible
  for a moment and automation paused for a second or two afterwards.
- Torghast: when powers are rerolled, or the same power is offered twice in a row, the addon
  no longer occasionally takes an unscored power from the old offering. The power window also
  stays hidden while it's being handled instead of briefly reappearing.
- Turning JustQuest off and back on no longer stops container auto-open until you reload.
- Container auto-open is less likely to hold off because it mistook quest automation for
  bag sorting.
- Auto-open no longer tries to open locked boxes, so the red "It's locked!" message
  no longer appears when logging in with a lockbox in your bags. A box whose lock has
  already been picked still opens normally.
- Approving a currency cost ("Spend" / "Always Allow") only goes ahead if the same quest is
  still open and automation is still allowed; a stale approval spends nothing.
- A quest window or shared-quest prompt without a readable quest ID is left for you instead
  of being accepted unchecked, and quests your filters block are no longer completed from a
  progress or reward window that opens directly.
- Older-style quest greeting windows use the same quest filters as the modern ones, so a
  blocked turn-in no longer stops an allowed one beside it.
- A gossip menu JustQuest left for you is looked at again as soon as its options change, even
  if the number of options stays the same.
- Picking up an area or bonus quest by walking into it no longer makes the next NPC you talk to
  wait for a follow-up quest that isn't coming.

## [3.5.0] - 2026-08-11

### Added
- The gear advisor now works without Pawn. Previously, if Pawn wasn't installed — or had no scale set up for the specialization you were playing — the advisor scored nothing and quietly recommended nothing, which looked exactly like having no upgrades. It now falls back to comparing item levels, and says so: the prompt reads "Gear upgrade (by item level)" so you know it's the rougher judgement. Everything else still applies, so it won't offer you the wrong armor type, the wrong primary stat, or anything you can't wear. Install Pawn and set up a scale and it goes back to using that, which is still the better answer.

### Changed
- Updated for game patch 12.1.0.
- The delve difficulty window is only automated when it's actually offering a delve. That window has been given a second job this patch — it now also sets the difficulty for lairs, and some of those difficulties queue you for a group rather than sending you straight in. Picking a delve tier isn't the same as agreeing to be put in a queue, so the automatic tier choice and auto-enter stay with delves; a lair difficulty window is left for you.
- JustQuest no longer narrates itself in chat. Accepting a quest, taking an anima power, rerolling, picking a delve tier, swapping a piece of gear, or stepping back so you can handle a dialogue yourself — all of it used to print a line, and none of it does now. What replaced it was already there: the gear toast still appears on screen, the dialogue panel still carries its own note, and the full detail is one debug toggle away. Replies to slash commands you type are untouched, and so is the optional end-of-run summary.
- The "Everything openable" auto-open mode and the rogue "Auto-Pick Lockboxes" toggle are gone. Neither could ever open a lockbox — that needs a key or a lockpick, and the game only lets you use those yourself, never an addon on your behalf. Auto-open is now simply "My list only" or "Openable containers". If you had "Everything openable" selected you'll be moved to "Openable containers", which is what it had been doing anyway.
- The options panel got a design cleanup. The main JustQuest page is now a short overview with the master switches; each category opens from the AddOns list and reads the same way — a short intro up top, details in tooltips. Colors now mean the same thing everywhere (gold for headings, soft red for caveats, grey for empty lists), and empty lists explain how to fill them instead of just saying "None". The safety summary under Advanced now describes current behavior, "Reset Instance On Exit" moved to the Instances category where it belongs, and the escort-quest toggle (which could never work — the game offers no way to detect escort quests) is gone.

### Fixed
- The run summary no longer reports opening containers it never opened. If you were carrying a lockbox, it was counted as opened every single time the addon looked in your bags — the game accepts the request to open one and then quietly declines, and that was being read as success. An open now only counts once the container is actually used up, and anything that refuses to open is left alone after a few tries instead of being poked forever.
- Follow-up quests that a quest giver hands out a second or two after the previous one are picked up reliably again. If the new quest arrived while the addon was still finishing the previous step, it was written off as "nothing new here" and never looked at again — you had to click the NPC a second time. The wait for a slow follow-up is also longer now, so a laggy quest giver still gets caught.
- The note explaining why automation left a dialogue for you to handle is readable again. It sat just past the bottom edge of the parchment, so its dark text landed on the dark border below the paper. It now sits on the paper, with the rest of the dialogue text.
- The gear advisor now leaves teleport cloaks and other on-use travel gear alone while you're travelling. Putting one on read as an instant downgrade, so you'd get an upgrade prompt while you were still reaching for the right-click — and with auto-equip on, the cloak came straight back off, which cancels the teleport, since those items only work while worn. The advisor now waits out the cast and reminds you to swap back once you've arrived, which is when you want to hear it.
- The gear advisor no longer suggests gear built around the wrong primary stat. A Restoration druid was offered an Agility spear: it's legal to hold, it isn't the wrong armor type, and nothing on the tooltip marks it as a mistake, so a high enough number on it read as an upgrade. Items carrying a primary stat your specialization doesn't use are now left out. Gear with no primary stat at all — cloaks, necklaces, most rings — is unaffected, and the check re-evaluates when you change specialization.
- The gear advisor no longer suggests armor your class isn't meant to wear. A druid with a high-stat cloth chest in their bags was offered it as an upgrade — it can be equipped, so nothing flagged it, but wearing it costs your armor specialization bonus. Only your own armor type is suggested now. Cloaks, rings, necklaces and weapons are unaffected.

## [3.4.0] - 2026-07-28

### Added
- **Anima power selection in Torghast.** JustQuest can now pick your anima powers for you, from a curated list of which are worth taking and which are traps — powers that stop you jumping, drain your health, or cap your speed are never taken, whatever else is on offer. A power whose own description states a drawback is refused too, even if the list rates it highly. For powers the list doesn't cover, JustQuest falls back to what the game itself says about them — their quality and whether they're offensive, defensive or utility — weighed against what you're playing for. A power window has to be answered before you can carry on, so the best safe option is always taken rather than handed back for an unremarkable choice; the window only comes back to you when every option on offer is one of the harmful ones. Choose whether it picks for clearing the run or for fast farming, and optionally let it spend a reroll when nothing on offer is worth having. When nothing is worth taking, the choice comes back to you rather than defaulting to whatever appeared first. Off until you turn it on, like everything else that answers a pop-up. `/jq torghast`
- **Getting into Torghast.** At the wayfinder, JustQuest can select the highest layer you've unlocked and start the climb, so you don't have to page across to it and pick it every run. Off until you turn it on, and left alone entirely if you're not the group leader or the group isn't gathered yet. The ready prompt that follows is still yours to accept — the game does not allow an addon to answer that one. `/jq torghast climb`
- **New "Instances" settings section** gathering the delve and Torghast options together, and reachable from the standard AddOns settings list — the delve options were previously only findable through `/jq config`.
- When automation leaves a dialog open on purpose, a short note at the bottom of the panel now says why (e.g. it contains a travel option, the game requires a manual choice, or there's simply nothing to automate).

### Fixed
- **Quick Exit no longer appears in battlegrounds and arenas.** It counted them as ordinary instances, and using it there would have left the match — a deserter penalty in a battleground, a forfeit in an arena. Leaving those is yours to do.
- A vendor, trainer, or flight master standing behind a couple of lines of small talk could stop opening for you. Once JustQuest had looked through that NPC's dialog and found nothing, it stopped offering the service too — so clicking the same NPC again just showed the menu. Services now always fire; only the dialog exploration retires.

### Changed
- **Dialog exploration now stands down inside dungeons, raids and other instances when you're in a group.** In instanced content, an NPC's one conversation option is often the one that starts the fight — "we're ready", "begin the assault", "send in the next wave" — and nothing marks those as different from small talk. Vendors, quest options and anything you've whitelisted still fire as normal; only the exploratory click stops. Playing solo is unchanged, so soloing old raids and scenarios still works exactly as before.
- Dialog options that take you into instanced content at a difficulty you didn't pick are now left for you, the same way the delve difficulty window already is.
- Choosing a Chromie Time timeline is now left alone by automation.
- Chatty NPCs feel much less clunky: dialog exploration now takes at most one conversation branch instead of clicking through every option, and once an NPC's dialog leads nowhere, re-opening that NPC shows the menu immediately instead of re-running the exploration.
- Service options (vendor, trainer, flight master, bank, etc.) are now taken right away instead of after conversation options — a chatty vendor opens their shop instead of talking first.
- Gossip automation no longer auto-clicks dialog options that grant items or currency, cast a spell, or play a cinematic. These now stay on screen for you to choose (whitelisted options still fire).
- Smarter conversation tracking: the game's own "conversation continuing" signal is now used when a dialog closes mid-chain, so multi-step conversations with slow transitions no longer risk re-selecting earlier options.

## [3.3.0] - 2026-07-20

### Added
- New **Gear Advisor** (off by default). With the Pawn addon installed, JustQuest scores the gear in your bags for the spec you're playing and offers you the best upgrade for each slot — as you loot, and when you change specs (a nudge to swap to your intellect staff on a caster, for instance). Each upgrade waits for your decision: **Equip** it, **Skip** it for now, or **Never** suggest that item again — and you can hover the icon to compare it against what you're wearing. Turn on *Auto-Equip* to skip the asking and just equip them, out of combat; bind-on-equip items are always left for you to equip by hand. Trinkets aren't scored, and an item you couldn't wear because of a unique-equipped limit is never suggested. Find it under the new Gear tab.
- Gear suggestions show what you'd actually gain and lose — the biggest stat changes, gains in green and losses in red, next to the percentage. A percentage tells you how much better something is; it can't tell you it's trading your mastery for haste, which is the part you might want to decide differently. When several upgrades are waiting, the suggestion says how many and offers **Equip All**, so a full re-gear after a dungeon is one click instead of answering the same question for every slot.
- Two-handed weapon suggestions account for the off-hand they'd remove. The suggestion says which item comes off, and auto-equip won't take a two-hander that would silently unequip your shield or off-hand — that one always asks first.
- New **Protect Profession Gear** option (Gear tab, on by default). An equipped fishing pole or profession tool is never suggested away. They sit in ordinary equipment slots, so a stat-based score just sees weak gear — and would offer to replace them right before you want them.
- New **Respect Equipment Sets** option (Gear tab, on by default). Gear that belongs to one of your saved equipment sets is left alone, so a speed or utility set you're wearing on purpose doesn't get a "this is higher item level" suggestion every time something drops. It works slot by slot: only the pieces your set actually fills are held back, and every other slot is still offered as normal. Turn it off if you keep your everyday gear saved as a set.
- New **Delves** section (off by default). *Auto-Take Powers* takes your delve power for you instead of stopping you for it every few minutes. It's the one pop-up choice JustQuest will ever answer for you, and only inside a delve — because it isn't really a choice: you're offered a single power, and it's always worth taking. There's also an optional *Auto-Select Tier* for the difficulty picker, which can take you straight in if you want it to. Everywhere else, a choice window is still always yours.
- Container auto-open now has an **Auto-Open** mode: *My list only*, *Safe containers* (new default), or *Everything openable* (also lockboxes). In the Safe and Everything modes JustQuest recognizes openable containers automatically (clams, chests, coin sacks, and the like), so common ones open without you whitelisting each. Your blacklist still overrides everything.
- Rogues get an optional **Auto-Pick Lockboxes** toggle (in *Everything openable* mode) to pick and open lockboxes automatically.
- A small spinner now follows your cursor while JustQuest is working on something. Most of what it does is invisible — fast mode hides the quest window entirely, and a step waiting on the server looked exactly like a frozen addon. Quick steps stay silent: the spinner only appears if something takes longer than a moment, and it disappears the instant automation finishes.
- New **Summarize In Chat** option (General settings, off by default). When on, JustQuest prints one concise line at the end of each automation run — for example "accepted 2, turned in 1, opened 1 container" — so you can see what it did at a glance.

### Improved
- Dialogs are picked up faster. When the game announces an NPC menu it has already sent everything JustQuest needs, so it no longer pauses before reading it — the pause only remains where it's actually doing something, after an action. Noticeable most on quest hubs with several turn-ins.
- A hidden quest window in fast mode comes back on screen roughly twice as fast when automation stops early.

### Fixed
- Auto-skip cutscenes is now safer and smoother. It no longer touches vehicle or control cutscenes — the ones that put you into a quest vehicle or take control of your character (like the "interrogate/torture the suspect" quests that swap your abilities for a small set) — which could previously eject you mid-transition and disconnect you from the server. Regular cinematics and pre-rendered movies still skip instantly and now close cleanly. As an added safeguard, automation fully stands down whenever you're in a vehicle, possess, or special-ability-bar state.
- The delve difficulty picker is no longer treated as an ordinary dialog to click through. Its options are the difficulty tiers, and picking one takes you straight in — so auto-gossip could walk you into a delve at a tier you didn't choose, just for opening the picker. The picker is now left alone entirely unless you turn on the new Auto-Select Tier option.
- Going back to an NPC you'd already talked to now works properly, and automation no longer winds down the longer you quest. JustQuest only picks each dialog option once per conversation, but the end of a conversation wasn't always registering — so every NPC inherited the last one's history and JustQuest gradually ran out of things it was willing to click. If you opened a flight master's map and closed it without flying, or stepped away and came back, that option stayed used up. The same gap could leave a dialog open but invisible in fast mode, with no way to interact until you walked out of range. Conversations are now closed out properly, returning to an NPC is treated as a fresh one, and state recovery after a quest teleport works again — which is the main reason vendors, trainers, and flight masters "stopped working" on the second visit.
- Fixed a loop where JustQuest would click through the same NPC dialog over and over, several times a second, until you walked away. Ending a conversation can raise the "dialog closed" signal more than once, and only the first was recognised — so the second looked like you'd walked off, wiping its memory of which options it had already picked along with every safeguard against looping. Each option is now auto-selected at most once per conversation, so a menu that keeps re-showing (including on a laggy server) is left for you instead of looping.
- Auto-gossip no longer runs out of clicks partway through a dialog. Its per-conversation click budget was being charged twice for each step, so longer menus stalled before reaching the end.
- When a conversation offers something on your gossip blacklist — a portal, a teleport, or a campaign skip like "I have heard this tale before" — JustQuest now stops and shows you that menu instead of quietly clicking past it to a different option. That choice was previously made for you by omission, and in fast mode you never saw the option had been offered. Quest options and anything on your whitelist are still taken automatically.
- Turning JustQuest off and back on no longer leaves it half-dead for the rest of your session. Disabling it shut down the background check that recovers from a stuck step and reveals a hidden quest window, and re-enabling never started it again — so afterwards any hiccup became permanent, including an invisible dialog you could only clear by walking away. It now restarts properly.
- Follow-up quests are picked up without needing a second click. After finishing with an NPC, JustQuest re-checks for anything new they have to offer — but it treated "I looked and there was nothing yet" as "I'm done", so it stopped looking a fraction of a second before the quest actually arrived. It now keeps checking until the quest shows up or it's clear nothing is coming, which is why this was intermittent rather than constant.
- A quest turn-in the server won't accept — you're short on gold, the quest needs a group, or you're in the wrong phase — no longer jams everything behind it. JustQuest now moves on to the other quests the NPC has ready instead of retrying the same one indefinitely.
- Fixed a rare case where a turn-in that costs currency could leave automation stopped until you reloaded. If the confirmation prompt couldn't be shown (too many other pop-ups on screen, or you'd just died), JustQuest waited for an answer to a question that was never asked.
- Automation no longer gives up part-way through a quest hub when your target changes. Tab-targeting, a pet pulling aggro, or simply killing the mob you were fighting mid-conversation would cancel the rest of the run.
- Quests you've chosen not to auto-accept — PvP, escort, or repeatable ones — now keep their "click here to accept" pop-up so you can still take them by hand. Those pop-ups were being cleared away even when JustQuest deliberately left the quest alone.
- Auto-complete "click here to complete" quests (the ones that start or finish when you enter an area or use an object) now hand in reliably. Turn-ins are no longer skipped just because the quest is a PvP, escort, or repeatable type — those preferences only affect what gets auto-accepted, not what gets turned in.
- Auto-open now leaves quest items alone. Some quest containers are flagged the same way ordinary loot bags are, so "Safe containers" mode could open one out of order and consume it. Opening one is still possible by adding it to your own list.
- Containers now stop being retried once they've genuinely failed, instead of quietly getting their attempts back every minute.
- Auto-open no longer triggers while you're at the mailbox, auction house, vendor, or in a trade — moving items around in those windows looked like looting.
- Lootable containers (lockboxes, clams, and similar) now auto-open more reliably while actively looting, instead of being mistaken for a bag sort.
- Quest rewards you can't actually use are no longer offered. Reward picking checked that an item was equippable in general, not that *you* could equip it — so it could recommend plate to a mage, or a piece that needs a higher level than you've reached. It now respects level, class, armor type, and any other requirement the game itself would show you in red.
- Pawn-scored gear no longer calls a far lower item-level piece an upgrade. A stat score is measured against what you're already wearing, so if the piece in that slot has none of the stats your spec wants, nearly anything scored as an enormous improvement — occasionally by absurd margins like "+1178%". Item level is now the sanity check: something below the piece it would replace isn't an upgrade, however well its stats score.
- When a reward's item data hasn't finished loading, JustQuest now leaves the choice to you rather than risking an auto-pick of the wrong reward.
- Quests that require handing in trade goods or crafted items are now checked before any currency-spend prompt, so those items can't be consumed without warning.

## [3.2.0] - 2026-07-06

### Bug Fixes

- **New quest steps that unlock mid-automation are no longer missed on a laggy server** — after an accept, turn-in, or gossip selection the follow-up check used to look only once; if the server hadn't sent the next step yet, automation stopped and you had to re-click the NPC. It now keeps checking briefly, while the quest/gossip window is still open, until the new step appears. Menus left for you to choose are unaffected.
- **Reward picking no longer undervalues green gear** — uncommon (green) equippable rewards are evaluated as possible upgrades instead of being treated as vendor trash.
- **Upgrade checks are accurate** — a reward counts as an upgrade only if its item level meets or beats what you have equipped, and both sides use effective item level so bonus-scaled quest rewards compare correctly.
- **Bind-on-equip gear halts sensibly** — automation pauses on BoE gear above your current average item level (instead of a fixed old threshold) so you decide whether to keep or sell it.
- **Mount/pet rewards detected on all clients** — collectible detection no longer relies on text matching, fixing missed mounts and pets on non-English clients.
- **Mixed item/currency reward quests fixed** — currency reward choices are recognized correctly, ending a retry loop on those quests.
- **Quests that charge gold pause for confirmation** — turn-ins that cost gold no longer pay automatically.
- **Currency and trade-item turn-ins pause for confirmation** — turn-ins that would spend currency (Flightstones, Honor, crafting materials, etc.) or hand over non-quest items now wait for you. Ordinary quest-item turn-ins still proceed automatically.
- **No more getting stuck at turn-in** — a dropped server message no longer strands automation with an invisible quest window; it restores and retries on its own within a second or two instead of making you walk away.
- **Fast mode hides quest-giver windows cleanly** — in fast mode the interface is hidden for quest mobs and for empty flavor dialog (which is auto-closed), while real vendor/trainer/service windows stay visible. A full multi-step quest-gossip chain stays hidden end to end without flickering, and is revealed only when you need to act — a manual reward pick, a menu with nothing to auto-select, a confirmation — or if automation stalls. Hold Shift/Ctrl/Alt to read a dialog yourself.
- **Fixed crashes from recent patches** — talking to NPCs could error out under a protected-value change in 11.x+; NPC identity checks and the debug inspector are now hardened.
- **Full quest log handled correctly** — removed the false "Accept FAILED" message. A full log is detected reliably: accepts pause while turn-ins keep freeing slots, until space opens — no spam, no false blocking.
- **Options panel listed under AddOns immediately** — settings register at login, so JustQuest appears in Game Menu → Options → AddOns right away instead of only after the first `/jq`.
- **Reward auto-selection no longer skips the next quest** — after a reward was left for you to pick, an internal guard could briefly block the following quest's reward; it's now always released.
- **Container opening leaves the currency prompt alone** — removed a stale path that could reset automation while the spend-currency confirmation was open.
- **Fixed a quick-exit startup crash.**

### New Features

- **Aggressive gossip — auto-advance to quests (on by default)** — a new NPCs-tab toggle. When on, JustQuest clicks through gossip dialog automatically to reach quests buried behind menus, advancing through multi-option menus rather than only quest-flagged or single-service ones. It prefers conversation options over vendor/trainer/banker ones so it heads toward quests instead of opening a shop, but still opens a service NPC when that's all a menu offers. It always stops and hands the menu back to you for real decisions: options that cost money or need a typed code, anything matching your dangerous-keyword blacklist (teleport, portal, campaign-skip and more ship by default), and menus the game forces open. Hold Shift/Ctrl/Alt to read any menu yourself. Turn the toggle off for the previous conservative behavior — only quest-indicated dialog and single service steps are automated.
- **Smarter reward upgrades with Pawn** — when Pawn is installed, reward picking uses your stat weights to rank upgrades, filtered to your spec, and falls back to item-level comparison when Pawn isn't present or has no matching scale. New Reward Selection options toggle Pawn scoring and choose whether it follows your Loot Specialization; a status line shows the active mode and spec. No setup or extra dependency required.
- **Class-appropriate armor rewards** — when a quest offers one item per armor type, auto-pick always chooses the highest armor type your class can wear. Weapons and accessories continue through stat/item-level scoring.
- **Currency turn-in confirmation** — when a turn-in would spend currency (Flightstones, Honor, Resonance Crystals, etc.) and the quest isn't whitelisted, a prompt lets you Spend Once, Always Allow (whitelists that quest for next time), or Cancel. A new panel in the Quests tab lists whitelisted quests and lets you remove them. Stored per character profile.
- **Quick-exit questing shortcut** — a movable on-screen `Exit` button (and `/lfgexit`) leaves LFG, delve, or grouped content immediately using Blizzard's direct-exit paths, or starts a listing-based exit when that's the only option. Delves use Blizzard's dedicated immediate-exit path. Each attempt reports a single status line: success, countdown started, or one concise failure. `/lfgqs` remains the manual shortcut.
- **Exit button is easier to spot** — the quick-exit button shows a soft pulsing glow until you click it the first time, then stops — easy for new players to find without staying flashy once you know where it is.
- **Reset instance on exit** — an optional General-tab toggle resets the instance after a successful quick-exit (deferred until you're actually outside, for delayed exits).

### Maintenance

- `/jq` now opens options by default; `/jq help` shows the command list; `/jq debug` toggles debug mode when run with no argument.
- Options UI text pass — shorter, clearer config descriptions, and a few pause messages now show plain language instead of an internal code.
- Gossip detection reworked internally — replaced fragile reading of the dialog window's colors with the game's own quest/service flags, plus a text fallback for older content.
- Smaller download and internal consolidation — removed a bundled database tool and dead code, and unified several internal paths. No behavior change.

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
