## [Unreleased]

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
  - It no longer suggests Intellect-only gear to warriors and rogues, or Strength and Agility
    gear to mages, priests and warlocks. Paladins, shamans, druids and hunters are unaffected.
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

