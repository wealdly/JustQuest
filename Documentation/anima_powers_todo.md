# Anima power reference

Every spell carrying `SpellLabel.LabelID == 630` (the roguelike-run power marker) that has both a name and a description. `$@spelldesc` pointers are resolved; rank variants and alternate IDs are collapsed onto one row.

1831 labelled spells -> 1111 distinct powers (uncurated only).

`ids` lists every spell id sharing this description — **all of them need a score**, since the game may offer any one. Bold ids are already in AnimaPowerDB.

| ids | name | description |
|---|---|---|
| 293956, 294113, 294114 | Mawstone | Increase your current Vitality by $s1. |
| 294130 | Visor of the Firstborn | Sense treasure chests and elite enemies through walls. |
| 294138 | Obleron Armaments | Obleron Armor is indelibly tied to the Armory. |
| 294296 | Secret Spices | Killing a Mawrat grants you $s1 Vitality. |
| 294331 | Essence of Vim | Your damage is increased by ${$s1/100}.2% for every Vitality you have remaining. |
| 294340 | Essence of Vigor | Your damage is increased by ${$s1/100}.2% for every Vitality you are missing. |
| 294410 | Terminus Orb | Regain $s1 Vitality when you ascend to a new floor of the Armory. |
| 294422 | Bloating Fodder | You cause Mawrats to explode on death, dealing $<damage> Plague damage to all other nearby enemies. |
| 294423 | Bloating Fodder Burst | You cause Mawrats to explode on death, dealing $<damage> Plague damage to all other nearby enemies. |
| 294562 | Dowsing Rod | Exanima Cells will always offer you a Mawstone as an additional choice. |
| 294597 | Obleron Talisman | Increase mastery by $s1%. |
| 294600, 294601 | Obleron Talisman | Increase mastery by ${$s1*$294597s1}%. |
| 294706 | Vital Aegis | Reduce any Vitality damage taken by $s1. |
| 294719, 294720, 356916, 356917 | Bottled Enigma | A cloud of obscuring mist surrounds you, preventing enemies from targeting into or out of the mist. |
| 294887, 294888, 294889, 294891 | Glutton's Kerchief | Gain $s3% Critical Strike, Haste, Mastery, and Versatility.

\|cFFff2020$294889d after ascending to a new floor of the Tower, you will begin to suffer increasing Shadow damage every $t1 sec.\|r |
| 295080, 295081, 295083, 295095 | Phantasma Cloud | The Holy energy of Azeroth invigorates you, healing the caster for $s1% health, and increasing damage dealt by $s2% and maximum health by $s3% for $d. |
| 295085 | Phantasma Cloud | The Holy energy of Azeroth invigorates you, healing the caster for $s1% health, and increasing damage dealt by $s3% and maximum health by $s5% for $d. |
| 295086, 295100 | Ultimate Detainment | Learn the ability Ultimate Detainment, allowing you to permanently root and silence all enemies within $295089A1 yds.

\|cFFFFFF97Ultimate Detainment may only be cast once per floor.\|r |
| 295089 | Ultimate Detainment | Permanently silence all enemies within $A1 yds. Enemies struck also have their movement speeds reduced by $s1%.

$?a295100[\|cFFFFFFFFCastable once per floor.\|r][\|cFFFF2020Ascend to a new floor of the Tower to recharge.\|r] |
| 295139 | Obsidian Effigy | Increase your current and maximum Vitality by $s1%.

Increase your normal damage taken by $s2%. |
| 295187 | Mawrat Harness | Obtain a Mawrat Harness, an item that allows you to transform into a Maw Rat while in Torghast. |
| 295694, 313174 | Secret Spices | Killing a Mawrat increases your maximum health by $s1%, up to ${$u*$s1}%. |
| 295732 | Golden Idol | Become able to see which enemies are carrying Plundered Anima. |
| 295754, 295755, 300707 | Purifier's Flame | Deadsoul Death Pools no longer damage you, and instead you absorb them, healing yourself for $300707s1 every $294607t1 sec. |
| 295948 | Farseer's Lesson | Gain the Spirit Wolf talent.

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 295965, 295967 | Curious Miasma | When you attack a new creature, you are healed for $295967s1. |
| 295969, 295971 | Protective Phantasma | Looting Phantasma grants you an absorb shield for $s2 per Phantasma, up to a maximum of ${$s1*$MHP}. The absorption stacks, and lasts $295971d. |
| 295978, 295980 | Echo of Azeroth | Sustaining fatal damage instead heals you for $295980s1% of your health and restores $295980s2% of your primary resource. This effect is then consumed. |
| 295997, 308203 | Crown of Obstinance | Enemies within $s1 yds have their casting speed reduced by $295998s1%. |
| 295998 | Obstinance | Enemies within $s1 yds have their casting speed reduced by $295998s1%. |
| 296140, 347975 | Tremorbeast Heart | Primary stat increased by $s1%, and regenerate $s2 health every $t2 sec. |
| 296146 | Know Mortality | Your attacks have a high chance to inflict Know Mortality, dealing $<damage> Shadow damage over $296146d and reducing the target's movement speed by $296146s2%. |
| 296307 | Prismatic Chip | Combine 10 Prismatic Chips to generate a Prismatic Soul, granting you a Legendary Item. |
| 296309 | Prismatic Soul | Create a Legendary Item for your specialization. |
| 296485 | High Priest's Legacy | $?a137032[Gain the Castigation talent.]?a137031[Gain the Censure talent.]?a137033[Gain the Misery talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 296499 | Shadowblade's Legacy | Gain the Prey on the Weak talent.

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 296502 | Highlord's Legacy | $?a137029[Gain the Crusader's Might talent.]?a137028[Gain the Redoubt talent.]?a137027[Gain the Righteous Verdict talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 296503 | Battlelord's Legacy | $?a137049[Gain the War Machine talent.]?a137050[Gain the War Machine talent.]?a137048[Gain the Punish talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 296504 | Slayer's Legacy | $?a212612[Gain the Demonic Appetite talent.]?a212613[Gain the Fallout talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 296507 | Deathlord's Legacy | $?a137008[Gain the Heartbreaker talent.]?a137006[Gain the Runic Attenuation talent.]?a137007[Gain the Harbinger of Doom talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 296515 | Mind Breach | Aether Lance applies Schism to enemies it strikes. |
| 297413 | Shackle Keys | Shackle effects no longer damage or snare you. |
| 297576, 297577, 297579, 300318 | Tremorbeast Tusk | When an enemy damages you, they suffer $297577s1 Nature damage. If they deal at least $s1% of your health in damage, they are knocked back.

The knockback may only occur every $300318d per target. |
| 297721, 297722 | Subjugator's Manacles | When you attack a new creature, they suffer $297722s1 Shadow damage and are silenced for $297722d. |
| 297833 | Enchanted Thieves' Tools | Certain Anima Cells offer an additional choice. |
| 297849 | Crystallum Orbis | Caches at the end of a floor never contain Common choices. |
| 297876 | Mobius Graft | Receive a new set of choices from this chest. Cannot be undone. |
| 297877, 297878 | Mobius Graft | Caches at the end of a floor can be reset one time each, granting you a new set of choices. |
| 298561 | Lingering Reverberations | Earthquake lasts ${$s1/1000} sec longer. |
| 298562 | Cracking Fissure | Earthquake is $s1% larger. |
| 298563 | Violent Tremors | Earthquake's damage is increased by $s1%, or by $s2% if it damages only one enemy. |
| 298564, 298568 | Might of the Worldsplitter | Whenever Earthquake knocks an enemy down, you generate $298568s1 Maelstrom. |
| 298572 | Tectonic Storm | Chain Lightning always causes an Elemental Overload against enemies standing in your Earthquake. |
| 298576, 298578 | Earthen Resonance | Your Intellect is increased by $298578s1% for each Earthquake you have active. |
| 298581, 298582 | Shake the Foundations | Casting Earthquake automatically casts Chain Lightning at $m1 random $Lenemy:enemies; in the Earthquake. |
| 298590 | Totemic Slam | Whenever you summon a Totem, it causes an Earthquake at its location. |
| 298650 | Unstable Terrain | Earthquake reduces enemies' movement speed by $s1%. |
| 298685 | Thermal Harmony | Casting Flame Shock also casts Frost Shock. |
| 298690 | Improved Healing Surge | Healing Surge restores $s1% more health. |
| 298692 | Blessing of Ahune | Frost Shock reduces movement speed by an additional $s2%, and lasts ${$s1/1000} sec longer. |
| 298767 | Mountains Will Fall | Your Mastery now affects Earthquake, allowing it to cause an Elemental Overload. |
| 298789 | Astral Phantasma | Looting Phantasma reduces the remaining cooldown of Astral Shift by ${$s1/1000} sec per Phantasma. |
| 298810 | Consumed by Flame | Secrets of Living Flame prevents you from accessing Frost magic.

$@spellicon196840$@spellname196840
Chills the target with frost, causing $s1 Frost damage and reducing the target's movement speed by $s2% for $d.$?a343725&a210714[

\|cFFFFFFFFGenerates ${$343725s10+$343725s7} Maelstrom.\|r]?a3437 |
| 298811 | Consumed by Flame | Secrets of Living Flame prevents you from accessing Frost magic.

$@spellicon546$@spellname546
Allows the friendly target to walk across water for $d. Damage will cancel the effect. |
| 298813 | Consumed by Flame | Secrets of Living Flame prevents you from accessing Frost magic.

$@spellicon210714$@spellname210714
Hurls frigid ice at the target, dealing $s1 Frost damage and causing your next Frost Shock to deal $s2% increased damage, damage $s4 additional $Ltarget:targets;, and generate $343725s7 additional |
| 298883 | Farseer's Cypher | $?a137039[Gain the Torrent talent.]?a137041[Gain the Lashing Flames talent.]?a137040[Gain the Earthen Rage talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 298884 | Farseer's Gift | $?a137039[Gain the Echo of the Elements talent.]?a137041[Gain the Stormflurry talent.]?a137040[Gain the Aftershock talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 298885 | Farseer's Invocation | $?a137039[Gain the Ancestral Vigor talent.]?a137041[Gain the Elemental Assault talent.]?a137040[Gain the Master of the Elements talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 298886 | Farseer's Mythos | $?a137039[Gain the Flash Flood talent.]?a137041[Gain the Crashing Storm talent.]?a137040[Gain the Surge of Power talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 298887 | Farseer's Ultimatum | $?a137039[Gain the High Tide talent.]?a137041[Gain the Elemental Spirits talent.]?a137040[Gain the Unlimited Power talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 298891, 298905, 298963 | All-Consuming Blaze | Fire damage dealt by you and your summons increases the damage the target takes from your Lava Burst by $298905s1%, stacking up to $298905u times. |
| 298911 | Molten Shock | Earth Shock grants you Lava Surge. |
| 298952 | Ignan Oblation | Summoning your $?s192249[Storm Elemental][Fire Elemental] causes you to gain Ascendance for ${$s1/1000} sec. |
| 298969, 298971 | Magma Fist | Lava Burst knocks the target away from you. |
| 298991 | By Fire Be Purged | Successfully Purging an enemy casts Lava Burst at them. |
| 299046 | Flame Jet | Burn enemies in a cone in front of you for $s1 Fire damage, and reduce their Armor by $s2% for $d. |
| 299049, 299050 | Heart of the Forge | Heat radiates from you, inflicting $299050s1 Fire damage to nearby enemies every $t1 sec. |
| 299388, 299389 | Galvanizing Nimbus | Lightning Bolt, Chain Lightning, and their overloads cause your next Thunderstorm to deal $299389s1% increased damage, stacking up to $299389u times. |
| 299419 | Flaming Lance | Anima Lance applies Flame Shock to enemies it strikes. |
| 300730, 300731 | Vitality Guillotine | The first time you damage an Elite enemy, deal additional damage equal to half their maximum health. After this occurs $u times this effect is lost, and you gain $300733s1% maximum health. |
| 300733 | Sated Guillotine | The first time you damage an Elite enemy, deal additional damage equal to half their maximum health. After this occurs $u times this effect is lost, and you gain $300733s1% maximum health. |
| 300793 | Open Doors | Door of Shadows has an instant cast time. |
| 300796, 300803 | Touch of the Unseen | Door of Shadows heals you for $s1% of your maximum health. |
| 303842, 352102 | Obleron Spikes | Obleron Armor is indelibly tied to the Armory. |
| 303843 | Obleron Venom | Obleron Armor is indelibly tied to the Armory. |
| 303844 | Obleron Winds | Obleron Armor is indelibly tied to the Armory. |
| 303845 | Obleron Talisman | Obleron Armor is indelibly tied to the Armory. |
| 303846 | Obleron Endurance | Obleron Armor is indelibly tied to the Armory. |
| 303847 | Obleron Ephemera | Obleron Armor is indelibly tied to the Armory. |
| 304845 | Mawrat Stirrups | Entering combat no longer dismounts you from your Enormous Mawrat. |
| 304917 | Deadsoul Hound Harness | Obtain a Deadsoul Hound Harness, an item that allows you to transform into a Deadsoul Hound while in Torghast. |
| 304918 | Maw Seeker Harness | Obtain a Maw Seeker Harness, an item that allows you to transform into a Maw Seeker while in Torghast. |
| 304992 | Band of Deep Burns | Dealing Fire damage has a chance to reduce the target's movement speed by $304993s1% for $304993d. |
| 304993 | Deep Burns | Dealing Fire damage has a chance to reduce the target's movement speed by $304993s1% for $304993d. |
| 304998, 305000 | Stormcycle Peridot | Dealing Nature damage has a chance to inflict your target with Stormcycle, dealing $305000s1 damage every $305000t1 sec indefinitely. |
| 305002, 305003 | Shadowed Iris | Dealing Shadow damage has a chance to blind the target, reducing their chance to hit by $305003s1% for $305003d. |
| 305004 | Words of Incomprehensible Glory | Dealing Holy damage has a chance to overwhelm the target with gloriousness, stunning them for $305005d. |
| 305005 | Incomprehensible Glory | Dealing Holy damage has a chance to overwhelm the target with gloriousness, stunning them for $305005d. |
| 305006, 305007 | Scroll of Elchaver | Dealing Arcane damage has a chance to turn non-elite targets into an inanimate household object, killing them instantly. |
| 305008 | Hematoma Bat | Dealing Physical damage has a chance to confuse the target, compelling them to fight alongside you for $305009d. |
| 305009 | Hematoma | Dealing Physical damage has a chance to confuse the target, compelling them to fight alongside you for $305009d. |
| 305042, 305043, 308194 | Finger of Frozen Fury | Your attacks have a chance to fire a bolt of magic, dealing $305043s1 Frost damage to enemies within $305043A1 yards of your target. |
| 305044, 305045, 308195, 352069, 352070, 447396 | Lightning Dust | Your attacks have a chance to fire a bolt of lightning, dealing $305045s1 Nature damage to your target. |
| 305047, 305049, 308196 | Corruption Antenna | Your attacks have a chance to curse your target, dealing $305049o1 Shadow damage to your target over $305049d. |
| 305050, 305051 | Watchful Lightfly | A Watchful Lightfly defends you, dealing $305051s1 Holy damage to enemies that strike you in melee. |
| 305054, 305055, 305060 | Yel'Shir's Powerglove | Your damaging spells and abilities empower your weapon, increasing the damage of your next melee strike by $305060s1, stacking up to $305055u times. |
| 305266, 305309 | Warden's Authority | Automatically open all Soul Cages within $305309A1 yards. |
| 305269 | Pocketed Soulcage | Opening the cage will reward $m-$M Soul Remnants. |
| 305273 | Vial of Lost Potential | Clear all permanent debuffs left by the Eternal Subjugator. |
| 305277 | Flamestarved Cinders | Absorbs all nearby heat, reducing Fire damage taken by $s1%. |
| 305282, 305284, 356920 | Glasswing Charm | Become a cloud of insects when out of combat, increasing movement speed by $305284s1%. |
| 305287 | Marrow Scooper | Skeletons in the Jailer's Tower drop $s1 times as much Phantasma. |
| 305288 | Skeletal Ward | A skeleton will serve as your ward, assisting you in combat. |
| 305289 | Skeletal Ward | Summon a skeletal ward to assist you in combat. |
| 305293, 305295 | Prisoner's Concord | Freeing a Soul Remnant from Torghast grants you $305295s1% Critical Strike for $305295d. |
| 306563, 306565 | Kyrian Blessing | Your spells and attacks have a chance to grant you $306565s1% Mastery for $306565d. |
| 306571, 306572 | Maldraxxian Repayment | Your spells and attacks have a chance to grant you $306572s1% Versatility for $306572d. |
| 306573, 306574 | Gift of Ardenweald | Your spells and attacks have a chance to grant you $306574s1% Haste for $306574d. |
| 306575, 306577 | Venthyr's Gratitude | Your spells and attacks have a chance to grant you $306577s1% Critical Strike chance for $306577d. |
| 306590 | Sword Off My Back | Acquire a weapon that the kyrian prisoner was carrying. |
| 306591 | Blooded Satchel | Acquire a bag filled with various bones and meats. |
| 306592 | Satchel of Nature's Bounty | Acquire a satchel filled with various herbs and fish. |
| 306593 | Venthyr's Coin Purse | Acquire a bag filled with gold and various gems. |
| 306604 | Boots of Bellaton | Don the boots, increasing your movement speed by $s1%.

\|cFFFF2020Reduces your maximum health by $s2%.\|r |
| 306615 | Roots of the Dreamtree | Increases maximum health by $s1% and prevents knockback effects.

\|cFFFF2020Standing still temporarily reduces your movement speed due to growing roots.\|r |
| 306625 | Cilice of Denathrius | Gain an additional $s1% damage and healing when you ascend to a new floor of the Jailer's Tower.

\|cFFFF2020Lose $s2% max health when you ascend to a new floor of the Jailer's Tower.\|r |
| 307595 | Bounty of the Grove | Purity's Vale lasts ${$s1/1000} sec longer. |
| 307597 | Overgrown Garden | Purity's Vale is $s1% larger. |
| 307598, 307602 | Sun-Drenched Grove | Purity's Vale instantly casts Sunfire on all enemies in the area. |
| 307605, 307612 | Darkening Canopy | Purity's Vale blinds enemies instantly and every $306701t2 sec, disorienting them for $307612d. |
| 307647, 307652 | Wisdom and Fury | When Purity's Vale ends it causes a burst of fiery energy, dealing $307652s1 Fire damage to all enemies in the area. |
| 307660 | Wisdom's Embrace | Purity's Vale healing is increased by $s1%. |
| 307661, 307662 | Giving Tree | Purity's Vale grants you $?a137013[${$307662s1/10} Astral Power]?a137011[$307662s2 Energy]?a137010[${$307662s3/10} Rage][$307662s4% mana] every $306701s1 sec. |
| 307738 | Winds of Bastion | Purity's Vale instantly casts Ursol's Vortex at its location. |
| 307741 | Command the Grove | Purity's Vale's cooldown is reduced to 20 sec, but it costs $?a137013[60 Astral Power]?a137011[100 Energy]?a137010[60 Rage][10,000 mana] to cast. |
| 308197 | Lost Pyrestone | Obtain a Pyrestone. |
| 308198 | Skeletal Ward | The skeleton will serve as your ward, assisting you in combat. |
| 308199 | Updraft | Sunrise lets you fly for $s1% longer. |
| 308200 | Tailwind | Sunrise increases your flight speed by an additional $s1%. |
| 308201 | Curious Miasma | When you attack a new creature, you are healed for $<heal>. |
| 308202 | Shadiform Rags | Prevent the Eye of the Jailer points from increasing for $d. |
| 312334, 312335 | Chain of Command | \|cFFffffffBeasts of Prodigum\|r

Calls forth Horgul, a powerful Shade Hound that can stun individual enemies and draw their attention. |
| 312340, 312341 | Shade Essence-Lure | \|cFFffffffBeasts of Prodigum\|r

Calls forth Valioc, a powerful Soul Eater that can inflict area damage and silence enemies. |
| 312342, 312343 | Wailing Pendant | \|cFFffffffBeasts of Prodigum\|r

Calls forth Nal'tari, a powerful Soul Hunter that can howl to increase allies' combat abilities. |
| 312532 | Infused Flesh | \|cFFffffffBeasts of Prodigum\|r

The cooldown of your Maw Beast's special ability is reduced by $s1%. |
| 312533 | Runic Etchings | \|cFFffffffBeasts of Prodigum\|r

The maximum health of your Maw Beast is increased by $s1%. |
| 312535, 312539 | Hungering Anima | \|cFFffffffBeasts of Prodigum\|r

Your Maw Beast gains $s1% increased damage done, but also loses $s2% health every $312538t2 sec while in combat. |
| 312536 | Runic Etchings | The maximum health of your Maw Beast is increased by $s1%. |
| 312538 | Hungering Anima | Your Maw Beast gains $s1% increased damage done, but also loses $s2% health every $t2 sec while in combat. |
| 312547, 312610 | Symbiotic Essence | \|cFFffffffBeasts of Prodigum\|r

The healing of your Maw Beast is increased by $s1% and also heals you as well. |
| 312549, 312604, 312606 | Satchel of the Hunt | \|cFFffffffBeasts of Prodigum\|r

Your Maw Beast grants allies within $s1 yds an additional $312606s1% movement speed. |
| 312552 | Unnatural Claws | \|cFFffffffBeasts of Prodigum\|r

Your Maw Beast strikes all enemies within $s1 yds while attacking. |
| 312598 | Infused Flesh | The cooldown of your Maw Beast's special ability is reduced by $s1%. |
| 312600, 313008, 313009, 313011 | Melee | Your Maw Beast strikes all enemies within $s1 additional yds while attacking. |
| 312601 | Unnatural Claws | Your Maw Beast strikes all enemies within $s1 additional yds while attacking. |
| 312670 | Stygian Victuals | \|cFFffffffBeasts of Prodigum\|r

Your Maw Beast regenerates $s1% of its health every $s2 sec while not in combat. |
| 312671, 312672 | Stygian Victuals | Your Maw Beast regenerates $s1% of its health every $s2 sec while not in combat. |
| 312840, 312841 | Anamnestic Memories | \|cFFffffffBeasts of Prodigum\|r

Your Maw Beast's movement speed is increased by $s1% and it will attempt to retrieve loot for you after combat. |
| 312847 | Anamnestic Memories | . |
| 312851, 312852, 312853 | Anamnestic Memories | Retrieves the loot from a nearby corpse. |
| 312985 | Collar of Teeth | \|cFFffffffBeasts of Prodigum\|r

Your Maw Beast's damage done is increased by $s1%. |
| 312986 | Collar of Teeth | Your Maw Beast's damage done is increased by $s1%. |
| 313576 | Death-Triggered Anima Bomb | Sustaining fatal damage instead detonates an Anima bomb, dealing $313578s2 Frost damage to all enemies within $313578a2 yards and restoring $313578s1% of your health. This effect is then consumed. |
| 313766 | Farseer's Legacy | Gain the Nature's Guardian talent.

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313817 | Slayer's Cypher | $?a212612[Gain the Blind Fury talent.]?a212613[Gain the Abyssal Strike talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313818 | Slayer's Gift | $?a212612[Gain the Burning Hatred talent.]?a212613[Gain the Feast of Souls talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313819 | Slayer's Lesson | $?a212612[Gain the Trail of Ruin talent.]?a212613[Gain the Infernal Armor talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313820 | Slayer's Invocation | Gain the Soul Rending talent.

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313821 | Slayer's Legacy | $?a212612[Gain the Cycle of Hatred talent.]?a212613[Gain the Concentrated Sigils talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313822 | Slayer's Mythos | $?a212612[Gain the Unleashed Power talent.]?a212613[Gain the Void Reaver talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313823 | Slayer's Ultimatum | $?a212612[Gain the Demonic talent.]?a212613[Gain the Last Resort talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313824 | Archdruid's Cypher | $?a137012[Gain the Abundance talent.]?a137011[Gain the Predator talent.]?a137013[Gain the Nature's Balance talent.]?a137010[Gain the Brambles talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313825 | Archdruid's Gift | Gain the Tiger Dash talent.

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313826 | Archdruid's Lesson | $?a137012[Gain the Balance Affinity talent.]?a137011[Gain the Balance Affinity talent.]?a137013[Gain the Feral Affinity talent.]?a137010[Gain the Balance Affinity talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in  |
| 313827 | Archdruid's Invocation | Gain the Mighty Bash talent.

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313828 | Archdruid's Legacy | Gain the Soul of the Forest talent.

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313829 | Archdruid's Mythos | $?a137012[Gain the Inner Peace talent.]?a137011[Gain the Scent of Blood talent.]?a137013[Gain the Stellar Drift talent.]?a137010[Gain the Earthwarden talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row. |
| 313831 | Archdruid's Ultimatum | $?a137012[Gain the Photosynthesis talent.]?a137011[Gain the Moment of Clarity talent.]?a137013[Gain the Solstice talent.]?a137010[Gain the Rend and Tear talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same r |
| 313832 | Shadowblade's Cypher | $?a137037[Gain the Master Poisoner talent.]?a137036[Gain the Weaponmaster talent.]?a137035[Gain the Weaponmaster talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313833 | Shadowblade's Gift | $?a137037[Gain the Nightstalker talent.]?a137036[Gain the Acrobatic Strikes talent.]?a137035[Gain the Nightstalker talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313834 | Shadowblade's Lesson | Gain the Vigor talent.

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313835 | Shadowblade's Invocation | $?a137037[Gain the Leeching Poison talent.]?a137036[Gain the Iron Stomach talent.]?a137035[Gain the Soothing Darkness talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313836 | Shadowblade's Legacy | $?a137037[Gain the Internal Bleeding talent.]?a137036[Gain the Dirty Tricks talent.]?a137035[Gain the Shot in the Dark talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313837 | Shadowblade's Mythos | $?a137037[Gain the Venom Rush talent.]?a137036[Gain the Loaded Dice talent.]?a137035[Gain the Dark Shadow talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313838 | Shadowblade's Ultimatum | $?a137037[Gain the Poison Bomb talent.]?a137036[Gain the Dancing Steel talent.]?a137035[Gain the Master of Shadows talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313839 | Highlord's Cypher | $?a137029[Gain the Crusader's Might talent.]?a137028[Gain the Holy Shield talent.]?a137027[Gain the Zeal talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313840 | Highlord's Gift | $?a137029[Gain the Saved by the Light talent.]?a137028[Gain the First Avenger talent.]?a137027[Gain the Fires of Justice talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313841 | Highlord's Lesson | Gain the Fist of Justice talent.

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313842 | Highlord's Invocation | $?a137029[Gain the Unbreakable Spirit talent.]?a137028[Gain the Unbreakable Spirit talent.]?a137027[Gain the Unbreakable Spirit talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313843 | Highlord's Legacy | $?a137029[Gain the Divine Purpose talent.]?a137028[Gain the Divine Purpose talent.]?a137027[Gain the Divine Purpose talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313844 | Highlord's Mythos | $?a137029[Gain the Sanctified Wrath talent.]?a137028[Gain the Hand of the Protector talent.]?a137027[Gain the Selfless Healer talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313845 | Highlord's Ultimatum | $?a137029[Gain the Glimmer of Light talent.]?a137028[Gain the Sanctified Wrath talent.]?a137027[Gain the Sanctified Wrath talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313846 | Deathlord's Cypher | $?a137008[Gain the Heartbreaker talent.]?a137006[Gain the Inexorable Assault talent.]?a137007[Gain the Infected Claws talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313847 | Deathlord's Gift | $?a137008[Gain the Rapid Decomposition talent.]?a137006[Gain the Runic Attenuation talent.]?a137007[Gain the Bursting Sores talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313848 | Deathlord's Lesson | $?a137008[Gain the Foul Bulwark talent.]?a137006[Gain the Death's Reach talent.]?a137007[Gain the Grip of the Dead talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313849 | Deathlord's Invocation | $?a137008[Gain the Will of the Necropolis talent.]?a137006[Gain the Avalanche talent.]?a137007[Gain the Pestilent Pustules talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313850 | Deathlord's Legacy | $?a137008[Gain the Grip of the Dead talent.]?a137006[Gain the Permafrost talent.]?a137007[Gain the Spell Eater talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313851 | Deathlord's Mythos | $?a137008[Gain the Voracious talent.]?a137006[Gain the Gathering Storm talent.]?a137007[Gain the Pestilence talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313852 | Deathlord's Ultimatum | $?a137008[Gain the Purgatory talent.]?a137006[Gain the Icecap talent.]?a137007[Gain the Army of the Damned talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313853 | Battlelord's Cypher | $?a137047[Gain the War Machine talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313854 | Battlelord's Gift | $?a137047[Gain the Double Time talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313855 | Battlelord's Lesson | $?a137049[Gain the Massacre talent.]?a137050[Gain the Massacre talent.]?a137048[Gain the Best Served Cold talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313856 | Battlelord's Invocation | $?a137049[Gain the Second Wind talent.]?a137050[Gain the Furious Charge talent.]?a137048[Gain the Crackling Thunder talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313857 | Battlelord's Legacy | $?a137049[Gain the Warbreaker talent.]?a137050[Gain the Seethe talent.]?a137048[Gain the Never Surrender talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313858 | Battlelord's Mythos | $?a137049[Gain the In For The Kill talent.]?a137050[Gain the Meat Cleaver talent.]?a137048[Gain the Into the Fray talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313859 | Battlelord's Ultimatum | $?a137047[Gain the Anger Management talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313860 | Grandmaster's Cypher | $?a137023[Gain the Eye of the Tiger talent.]?a137024[Gain the Mist Wrap talent.]?a137025[Gain the Eye of the Tiger talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313861 | Grandmaster's Gift | Gain the Celerity talent.

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313862 | Grandmaster's Lesson | $?a137023[Gain the Light Brewing talent.]?a137024[Gain the Lifecycles talent.]?a137025[Gain the Ascension talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313863 | Grandmaster's Invocation | Gain the Tiger Tail Sweep talent.

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313864 | Grandmaster's Legacy | $?a137023[Gain the Bob and Weave talent.]?a137024[Gain the Healing Elixir talent.]?a137025[Gain the Inner Strength talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313865 | Grandmaster's Mythos | $?a137023[Gain the Special Delivery talent.]?a137024[Gain the Summon Jade Serpent Statue talent.]?a137025[Gain the Hit Combo talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313866 | Grandmaster's Ultimatum | $?a137023[Gain the High Tolerance talent.]?a137024[Gain the Focused Thunder talent.]?a137025[Gain the Spiritual Focus talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313867 | Archmage's Cypher | $?a137021[Gain the Amplification talent.]?a137019[Gain the Firestarter talent.]?a137020[Gain the Bone Chilling talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313868 | Archmage's Gift | $?a137021[Gain the Master of Time talent.]?a137019[Gain the Blazing Soul talent.]?a137020[Gain the Glacial Insulation talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313869 | Archmage's Lesson | Gain the Incanter's Flow talent.

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313870 | Archmage's Invocation | $?a137021[Gain the Resonance talent.]?a137019[Gain the Flame On talent.]?a137020[Gain the Frozen Touch talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313871 | Archmage's Legacy | $?a137021[Gain the Chrono Shift talent.]?a137019[Gain the Frenetic Speed talent.]?a137020[Gain the Frigid Winds talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313872 | Archmage's Mythos | $?a137021[Gain the Reverberate talent.]?a137019[Gain the Flame Patch talent.]?a137020[Gain the Freezing Rain talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313873 | Archmage's Ultimatum | $?a137021[Gain the Overpowered talent.]?a137019[Gain the Kindling talent.]?a137020[Gain the Thermal Void talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313874 | Netherlord's Cypher | $?a137043[Gain the Nightfall talent.]?a137044[Gain the Dreadlash talent.]?a137046[Gain the Flashover talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313875 | Netherlord's Gift | $?a137043[Gain the Writhe in Agony talent.]?a137044[Gain the Demonic Calling talent.]?a137046[Gain the Reverse Entropy talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313876 | Netherlord's Lesson | Gain the Demon Skin talent.

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313877 | Netherlord's Invocation | $?a137043[Gain the Sow the Seeds talent.]?a137044[Gain the From the Shadows talent.]?a137046[Gain the Inferno talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313878 | Netherlord's Legacy | Gain the Darkfury talent.

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313879 | Netherlord's Mythos | $?a137043[Gain the Shadow Embrace talent.]?a137044[Gain the Soul Conduit talent.]?a137046[Gain the Roaring Blaze talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313880 | Netherlord's Ultimatum | $?a137043[Gain the Soul Conduit talent.]?a137044[Gain the Sacrificed Souls talent.]?a137046[Gain the Soul Conduit talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313881 | Huntmaster's Cypher | $?a137015[Gain the Killer Instinct talent.]?a137016[Gain the Master Marksman talent.]?a137017[Gain the Viper's Venom talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313882 | Huntmaster's Gift | $?a137015[Gain the Scent of Blood talent.]?a137016[Gain the Careful Aim talent.]?a137017[Gain the Guerilla Tactics talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313883 | Huntmaster's Lesson | Gain the Trailblazer talent.

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313884 | Huntmaster's Invocation | $?a137015[Gain the Spitting Cobra talent.]?a137016[Gain the Steady Focus talent.]?a137017[Gain the Bloodseeker talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313885 | Huntmaster's Legacy | Gain the Born To Be Wild talent.

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313886 | Huntmaster's Mythos | $?a137015[Gain the Stomp talent.]?a137016[Gain the Lethal Shots talent.]?a137017[Gain the Tip of the Spear talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313887 | Huntmaster's Ultimatum | $?a137015[Gain the Aspect of the Beast talent.]?a137016[Gain the Calling the Shots talent.]?a137017[Gain the Birds of Prey talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313888 | High Priest's Cypher | $?a137032[Gain the Castigation talent.]?a137031[Gain the Enlightenment talent.]?a137033[Gain the Fortress of the Mind talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313889 | High Priest's Gift | $?a137032[Gain the Body and Soul talent.]?a137031[Gain the Angel's Mercy talent.]?a137033[Gain the Body and Soul talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313890 | High Priest's Lesson | $?a137032[Gain the Shield Discipline talent.]?a137031[Gain the Cosmic Ripple talent.]?a137033[Gain the Twist of Fate talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313891 | High Priest's Invocation | $?a137032[Gain the Psychic Voice talent.]?a137031[Gain the Psychic Voice talent.]?a137033[Gain the Last Word talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313892 | High Priest's Legacy | $?a137032[Gain the Sins of the Many talent.]?a137031[Gain the Surge of Light talent.]?a137033[Gain the Auspicious Spirits talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313893 | High Priest's Mythos | $?a137032[Gain the Purge the Wicked talent.]?a137031[Gain the Benediction talent.]?a137033[Gain the Damnation talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313894 | High Priest's Ultimatum | $?a137032[Gain the Lenience talent.]?a137031[Gain the Light of the Naaru talent.]?a137033[Gain the Ancient Madness talent.][This upgrade is not appropriate for your class.]

\|cFFFFFFFFIf you already have this talent, you may select another talent in the same row.\|r |
| 313900 | Thrice-Charred Eye | Track Blazing Pyrestones on your map. |
| 313902 | Executor's Call Sheet | Reveal the locations of rare enemies on your map. |
| 313965 | Soul Detector | Track Souls on your map. |
| 314222 | Zeal of the Aspirant | Killing an enemy reduces the cooldown of Unburden by $s1 seconds. |
| 314225 | Lightfire Soles | While under the effects of Unburden, you instantly kill Mawrats that you pass through. |
| 314226 | Elysian Endurance | Increase the duration of Unburden by $s1%. |
| 314227 | Ascendant's Accelerando | Increase the speed of Unburden by $s1 yards/sec. |
| 314228 | Ancient Meditator's Bell | Unburden no longer propels you forward. |
| 314229 | Ode to Humility | Unburden can be cast instantly. |
| 314230 | Eyes of the Unceasing | Reduce the cooldown of Shackle the Unworthy by ${$abs($s1/1000)} seconds. |
| 314231 | Reinforced Manacle | Shackle the Unworthy reduces enemy damage dealt to you by an additional ${$abs($s1)}%. |
| 314232, 314691 | Darkhelm of Nuren | Shackle the Unworthy causes enemies within $314691A1 yards of your target to tremble in fear, stunning them for $314691d. |
| 314233 | Hateforged Cilice | Shackle the Unworthy also increases your damage dealt to the target by $s1%. |
| 314234, 314702 | Twisted Hellchoker | Shackle the Unworthy charms the target, causing them to fight alongside you for $314702d. |
| 314235 | Oppressor's Chain | Shackle the Unworthy will automatically be cast on enemies that strike you in melee.  This effect cannot occur more than once every $proccooldown seconds, and does not incur the ability's cooldown. |
| 314236 | Flail of Merkur | Your Steward's Phial of Serenity refreshes the cooldown of Elysian Decree. |
| 314237, 314725 | Mask of the Winged Dominator | $s1% of the damage dealt by Elysian Decree is returned to you as healing. |
| 314238 | Searing Deathbrand | Elysian Decree deals $s1% more damage. |
| 314239 | Souleater's Claw | Elysian Decree refunds $s1 additional Lesser Soul $LFragment:Fragments;. |
| 314241 | Scouring Rags of Torghast | Elysian Decree does not incur its cooldown if it hits a Mawrat. |
| 314242 | Deathwire | Reduce the cooldown of Resonating Arrow by ${$abs($s1/1000)} seconds. |
| 314243 | Deadsoul Aspect | Using Resonance Arrow heals the hunter and their pet are healed for $314559s1% of their maximum HP. |
| 314244 | Hell-Hardened Quartzite | Increase the duration of Resonance Trap by $s1%. |
| 314245 | Super Soul Scope | Resonating Arrow increases the hunter’s chance to critically hit the target by an additional $s1%. |
| 314246 | Sling of the Unseen | Increase the hunter's damage dealt to targets within Resonance Trap's effect by $308498s5%. If the hunter does not have line of sight on the target, damage is instead increased by ${$s1*$308498s5}%. |
| 314247 | Pact of the Soulstalkers | The $308498s1% bonus critical strike chance from Resonance Trap now applies to the hunter's entire party. |
| 314248 | Anima-Flecked Topaz | Reduce the cooldown of Radiant Spark by ${$abs($s1/1000)} seconds. |
| 314249 | Scroll of the Arcane Meditator | Radiant Spark’s initial damage is increased by $s1%. |
| 314250 | Winged Curio | Extend the duration of Radiant Spark by ${$s1/1000} seconds. |
| 314251 | Long-Forbidden Words | Radiant Spark can be cast instantly and interrupts spellcasting. |
| 314252 | Urael's Finality | After hitting an enemy with Radiant Spark, the damage of your 4th subsequent direct damage spell against that target is increased by an additional $s1%. |
| 314253, 335752 | Wizard's Prayer | $s1% of the damage dealt by Radiant Spark is returned as healing to the mage's party. |
| 314254 | Haven's Breath | Your Steward's Phial of Serenity refreshes the cooldown of Weapons of Order. |
| 314255 | Anima-Tinged Weapon Oil | Increase the Mastery granted by Weapons of Order by an additional $s1%. |
| 314256 | Maw-Darkened Slippers | Rolling while under the effects of Weapons of Order will shoot a bolt of Radiant energy at a nearby enemy, dealing Arcane damage. |
| 314257 | Forgotten Armor of Order | Weapons of Order increases Armor by $s1%. |
| 314258 | Balancing Stave | The mastery effect of Weapons of Order also affects critical strike, haste, versatility, and leech ratings. |
| 314260 | Ember of the Carillon | Reduce the cooldown of Divine Toll by ${$abs($s2/1000)} seconds. |
| 314262 | Belt of the Mawsworn Avenger | You cast Divine Toll when Avenging Wrath begins and ends. |
| 314264 | Big Clapper | Casting Divine Toll stuns all enemies within $314590A1 yards for $314590d. |
| 314266 | Faithstone | Casting Unburden refreshes the cooldown of Blind Faith. |
| 314267 | Deeply-Held Vow | Reduces Blind Faith channel time by an additional $s1%. |
| 314268 | Second Chorus | The duration of the beneficial effect of Blind Faith is increased by 50%. |
| 314269 | Mark of Blinding Faith | Damaging an enemy while under the effects of Blind Faith has a very high chance to blind them, disorienting them for $314416d. |
| 314270 | Answered Prayer | Blind Faith no longer has any negative effects upon expiring.  Instead, you explode with Arcane energy, dealing $314418s1 damage to enemies and $314418s2 healing to allies within $314418A1 yards. |
| 314271 | Blackened Shroud | Blind Faith causes you to go Truly Blind, increasing your damage and healing by $314437s1% and reducing damage taken by $314437s3%.

While Truly Blind, you will be completely unable to see your surroundings. |
| 314272 | Elysian Trickster-Ring | Reduce the cooldown of Echoing Reprimand by ${$abs($s1/1000)} seconds. |
| 314273 | Lightblade Haft | Echoing Reprimand no longer costs energy. |
| 314274 | Screaming Signet | Increase the duration of Echoing Reprimand by $s1%. |
| 314275 | Razorfeather | Increase the damage of Echoing Reprimand by $s1%. |
| 314276 | Shadesinger's Bargain | Echoing Reprimand grants $s1 additional Animacharged combo points. |
| 314277 | Sharpened Harpstring | Echoing Reprimand also decreases the target's damage by $306119s3% and increases the target's damage taken by $306119s4%. |
| 314278 | Wildzeal Wraps | Reduce the cooldown of Vesper Totem by ${$abs($s1/1000)} seconds. |
| 314279 | Generosity of the Winged Seer | Vesper Totem no longer has a mana cost. |
| 314280 | Weightless Spirit | Vesper Totem’s effect allows Unburden to be cast instantly, even if it is on cooldown. |
| 314281 | Vesperwind Bit | Vesper Totem also grants $s1% Haste to its target. |
| 314282 | Brooch of the Vale-Spirit | The Mastery effect of Vesper Totem is increased by $s1%. |
| 314283 | Diamondine Vesper | Vesper Totem now lasts for 5 minutes. |
| 314284 | Tome of Taking | Reduce the cooldown of Scouring Tithe by ${$abs($s1/1000)} seconds. |
| 314285 | Tithing Dish | If an enemy dies while under the effects of Scouring Tithe, they instantly grant $s1 Phantasma to all players. |
| 314286 | Shard of Slath'gerrar | Scouring Tithe can be cast instantly. |
| 314287 | Indebting Word | Increase Scouring Tithe’s periodic damage by $s1%. |
| 314288 | Languishing Soul Detritus | Increase the duration of Scouring Tithe by $s1%. |
| 314289 | Ash and Anima | Scouring Tithe finishes its entire effect in $s1% less time. |
| 314290 | Kyrian Warhelm | Your Steward's Phial of Serenity refreshes the cooldown of Spear of Bastion. |
| 314291 | Elysian Shoulderwrap | Increase Spear of Bastion's periodic damage by $s1%. |
| 314292 | Stonepiercer Signet | Increase the duration of Spear of Bastion by $s1%. |
| 314293 | Ancient Prolegomenon | Casting Spear of Bastion also applies $314625u stacks of Sunder Armor to the target, reducing their armor by ${$314625u*$314625s1}% for $314625d. |
| 314294 | Soulcarved Vow | The damage effect of Spear of Bastion lasts forever. |
| 314295, 314654 | Spearheads of Eternity | Each time you throw the Spear of Bastion, hitting at least one enemy  increases the Spear's instant damage by $314654s1%, stacking up to $314654u times. |
| 314590 | Big Clapper | Stun enemies within $A1. |
| 314625 | Sunder Armor | Hacks at an enemy's armor, reducing it $s1% per Sunder Armor. Can be applied up to 5 times. Lasts $d. |
| 315266 | Fleetwing Torch | Your next Unburden has infinite duration. |
| 315288, 315289, 315293 | Frostbite Wand | Damaging an enemy will also apply Frostbite, dealing damage equal to $s1% of their current hit points. After $d, the enemy will start regenerating all of the lost health over a period of $315293d.

Creatures can only be Frostbitten once. |
| 315300, 315312, 315313 | Icy Heartcrust | Absorb $315312s1% of damage dealt to you when your health is below $s1%. |
| 315314 | Spectral Bridle | Obtain a Spectral Bridle, an item that allows you to transform into a rideable Spectral Horse while in the Jailer's Tower. |
| 315315 | Spectral Bridle | Transform into a rideable Spectral Horse while in the Jailer's Tower, increasing your movement speed by $s3%. |
| 315319 | Spectral Oats | Heal $s1% of your max health every $t sec while running. |
| 316693, 343087 | Irresistible Cheese | Mawrats within 15 yards are immune to fear and will no longer flee at low health. |
| 316850 | Unstable Phantasma Lure | Increases Phantasma earned by $s1%. |
| 319056 | Elethium Veil | Your ability costs are reduced by $s2%, but you are no longer able to view your map. |
| 319281 | Elethium Lifegourd | Your haste is increased by $s3%, but your Nature damage and Nature healing done is reduced by $s1%. |
| 319605 | Unlock Shortcut | Unlock a shortcut to the previous floor that can be used at the start of future Torghast runs.

\|cFFFFA000This is a permanent power that is unlocked for all future Torghast runs.\|r |
| 319607 | Shortcut - Floor 11 | Permanently unlock a shortcut to floor $s1 that can be used at the start of the tower. |
| 319649 | Unlock Shortcut | Unlock a shortcut to the floor 3 levels below your current floor that can be used at the start future Torghast runs.

\|cFFFFA000This is a permanent power that is unlocked for all future Torghast runs.\|r |
| 320870 | Flash-Echo Focus | $?c2[Flash Heal][Shadow Mend] repeats its effect after $321008d, healing for $s1% of the original amount. |
| 320871 | Vandal's Zeal | Destroying a breakable object within Torghast empowers your $?c2[Holy Fire][Mind Blast] by $s1%, stacking up to $321152u times. |
| 320872 | Flashbox | For every $s2 seconds that you do not cast Flash Heal, the healing of your next Flash Heal is increased by $321153s1%. This effect can stack up to $321153u times. |
| 320873 | Searing Lantern | Your Flash Heals apply Searing Luminosity to your targets, causing them to reflect $321155s2% of damage taken back to attackers as Holy damage for $321155d. |
| 320874, 350068 | Fallen Priest's Blessing | Casting $?c2[Holy Fire][Mind Blast] increases damage or healing of your next $?c3[Devouring Plague]?c2[Holy Word: Chastise][Penance] by $?c2[$350068s2%][$350068s1%]. This effect stacks, but duration is not refreshed. |
| 320875 | Consuming Refrain | The periodic damage of Holy Fire lasts an additional ${$s1/1000} seconds. |
| 320876 | Holyfire Draught | Holy Fire has a $s1% chance to not trigger its cooldown. |
| 320877, 321168 | Mark of Righteous Protection | You take $321168s1% less damage while an enemy within 10 yards is under the effects of your Holy Fire. |
| 320878, 321171 | Holy Hellstone | When Holy Fire expires, it jumps to another nearby target. |
| 320879 | Idea Eater | Mind Blast critical strikes grant $?a137033[${$s1/100} Insanity][${$s2/100} Mana]. |
| 320880 | Painwheel | Extend the duration of $?s204197[Purge the Wicked][Shadow Word: Pain] by ${$s1/1000} seconds, and its damage is increased by $s2%. |
| 320881, 321179 | Schaden Fluorite | When $?s204197[Purge the Wicked][Shadow Word: Pain] expires on a target, all party members within $321179a1 yards of the target are healed for $321179s1% of their maximum health. |
| 320882 | Red-Hot Mindpokers | The initial damage of $?s204197[Purge the Wicked][Shadow Word: Pain] is always a critical hit. |
| 320883 | Rat-Corpse Bag | Killing a Mawrat grants you a bonus charge of Shadow Word: Death.

The bag can hold up to $321189u dead Mawrats. |
| 320884 | Impulsor | Casting $?s14914[Holy Fire][Mind Blast] will daze the target, reducing the target's movement speed and chance to hit by $321192s1% for $321192d.$?a320885[][

Subsequent casts of Mind Blast or Holy Fire will remove this effect.] |
| 320885 | Modified Impulsor | Casting $?s14914[Holy Fire][Mind Blast] will no longer remove the Dazzled effect. |
| 320886, 321197 | Catharstick | $s2% of all damage that you take is stored in the Catharstick.  The initial damage of your next $?s204197[Purge the Wicked][Shadow Word: Pain] deals this stored damage to your target. |
| 320887 | Painbreaker Psalm | Shadow Word: Death consumes your $?s204197[Purge the Wicked][Shadow Word: Pain] effects on the target, dealing all remaining damage. |
| 320888 | Mind Exploder | Mind Blast damage is increased by $s1%, but its cooldown is increased by $s2% |
| 320889 | Diary of Necrotic Thoughts | Mind Control can be used on Undead beings. |
| 320890 | Psychic Wallet | Casting Mind Control on an enemy will empty their pockets, granting roughly $321199s1 Phantasma. |
| 320891 | Commandment of Contagion | Using Mind Control on a Mawrat will trigger Rapid Contagion, causing all Mawrats within $321228a1 yards to give birth to a litter of 2-5 additional Mawrats. |
| 320892 | Puppetmaster's Strings | Mind Control lasts $s3 seconds longer and increases the target's damage by $s1%. |
| 320893 | Cruelty Censer | You deal $s1% more damage to creatures that are feared, horrified, stunned, or dazed. |
| 320894 | Animagrips | Casting Thoughtsteal on a target has a chance to grant you a Maw Power.  This effect can only occur once per level.

NYI - Grants 3% all stats. |
| 320895 | Thick Burlap Sash | Power Word: Fortitude grants an additional $s1% Stamina. |
| 320896 | Enchanted Shroud | Power Word: Fortitude now also reduces magical damage taken by $s1%. |
| 320897, 321286 | Warm Blanket | Players affected by your Power Word: Fortitude now also grant $321289s1% Stamina to party members within 3 yards. |
| 320899 | Wand Grease | The cast time of $?a137021[Arcane Blast]?a137019[Fireball]?a137020[Frostbolt][] is reduced by ${$s1/-1000}.1 \|4second:seconds;. |
| 320900 | Pandemonium Lens | The damage of Arcane Explosion, Flamestrike, and Blizzard is increased by $s1%. |
| 320901, 321634 | Whizzard Hat | Killing a creature with $?a137021[Arcane Explosion]?a137019[Flamestrike]?a137020[Blizzard][] increases your Haste by $321634s1% for $321634d.  Stacks up to $321634u times. |
| 320902 | Bombardier's Etching | Damaging an enemy with $?a137021[Arcane Explosion]?a137019[Flamestrike]?a137020[Blizzard][] automatically applies $?a137021[Prismatic Barrier]?a137019[Blazing Barrier]?a137020[Ice Barrier][]. This effect can only occur once every $proccooldown sec. |
| 320903, 321661, 321665, 321667 | Chaos Invitation | Your first $?a137021[Arcane Explosion]?a137019[Flamestrike]?a137020[Blizzard][] on a floor deals an additional $321661s1% damage. |
| 320904 | Manascale | Your $?a137021[Fire and Frost]?a137019[Arcane and Frost]?a137020[Arcane and Fire][] damage is increased by $s1%. |
| 320906, 321594 | Scroll of Explosure | Damaging an enemy with Arcane Explosion increases the damage it takes from all sources by $321594s1% for $321594d. |
| 320908 | Sorcerer's Frozen Soul | Ice Block has no cooldown. |
| 320909 | Eldritch Teachings | Increases the damage of $?c1[Arcane Barrage by $s1%.]?c2[Pyroblast by $s1%.][Flurry by $s2%.] |
| 320910, 321417 | Constellation Shield | Interrupting an enemy's spell cast reduces your damage taken by $321417s1% for $321417d. |
| 320911 | Resolute Medallion | The absorb of your Barrier spells is increased by $s1%. |
| 320912 | Tundrid Phial | Frost Nova cooldown is reduced by ${$s1/-1000} seconds. |
| 320913 | Everwarm Socks | Ice Block heals you for ${$45438s7*$45438d}% of your maximum health over the duration and no longer covers your feet, allowing you to move... albeit very slowly. |
| 320914 | Chronomancer's Hourglass | During Alter Time, you and your Mirror Images gain a bonus Time Warp at $s1% value. This is unaffected by Temporal Displacement or similar effects. |
| 320915 | Grisly Icicle | Damage no longer breaks Frost Nova. |
| 320916 | Triune Ward | Casting any Barrier spell grants the effects of Blazing Barrier, Ice Barrier, and Prismatic Barrier. |
| 320917 | Bottled Tesseract | Alter Time's maximum duration is increased by $s3 seconds. |
| 320919 | Echoes of Elisande | Time Warp also increases the rate at which time passes by $s1%. |
| 320922 | Mad Wizard's Scrawlings | At the beginning of each floor, you will receive an intuition, telling you to cast a series of spells in a certain order.

If you successfully cast these spells in the correct order, your Intellect will be increased by $321445s1%. |
| 320923 | Arcanic Pulse Detector | You will automatically cast Invisibility when you die, hiding you from the Jailer and preventing your death from being noticed.

This effect is then consumed. |
| 320925, 321706, 330766 | Dimensional Blade | Blinking through an enemy refreshes your Blink cooldown. Blinking through Mawrats will kill them instantly. |
| 320927 | Clouded Diamond | Blinking leaves a Mirror Image behind. This Mirror Image lasts for $s1 sec. |
| 320929 | Doomstone | NYI - (Shadow Bolt/Incinerate) has an N% chance to instantly detonate your Curse of Doom. |
| 320931 | Glutton's Guise | Casting $?a137043[Malefic Rapture]?a137044[Call Dreadstalkers]?a137046[Chaos Bolt][] instantly grants you $s1 Phantasma. |
| 320933 | Spattershield | $?a137043[Unstable Affliction]?a137044[Call Dreadstalkers]?a137046[Chaos Bolt][] contributes $s1% more absorption to your Soul Leech shield. |
| 320934 | Realmlord's Insignia | Reduce the cooldown of $?a137043[Summon Darkglare]?a137044[Summon Demonic Tyrant]?a137046[Summon Infernal][Summon Infernal] by $s1%. |
| 320935, 322326, 322335 | Heart of Endereth | Your $?a137043[Darkglare]?a137044[Demonic Tyrant]?a137046[Infernal][] increases the Versatility of all nearby players by $322335s1%. |
| 320937 | Detonation Torch | The damage of your $?a137043&s198590[Drain Soul]?a137043&!s198590[Shadow Bolt]?a137044[Shadow Bolt and Demonbolt]?a137046[Incinerate][] is increased by $s1%. |
| 320938 | Inferno Skewers | $?a137043[Seed of Corruption]?a137044[Implosion]?a137046[Rain of Fire][] damage is increased by $s1%. |
| 320940 | Eye of Endereth | The damage of your Corruption is increased by $s1% for each Freed Soul you have in your possession, up to a maximum of ${$s1*$s2}%. |
| 320941, 322157 | Soulvoid Bag | Creatures that die while affected by Corruption have a $s1% chance to grant a Soul Remnant. |
| 320942 | Choking Chains | Your Summon Demon spells are now instant. |
| 320943, 322360 | Pact of Thickness | Your primary summoned demons have $s1% more health and deal $s2% more damage. |
| 320946 | Kiss of Recklessness | Curse of Recklessness no longer increases your enemies' attack power. |
| 320947 | Accursed Ashes | NYI - The duration of Curse of Doom is increased by (large number)%, and its damage is increased by (VERY large number)%. |
| 320948 | Thirsting Chain | Drain Life healing increased by $s1%. |
| 320949 | Whispers of the Jailer | Fear duration increased by ${$s1/1000} seconds. |
| 320950 | Sacrificial Vermin | Killing a Mawrat reduces the cooldown of Shadowfury by $s1 seconds. |
| 320951 | Claw of Endereth | Drain Life drains the same amount of health $s1% faster. |
| 320952, 350958 | Visage of Lethality | When you are struck by a melee auto-attack, fear all nearby enemies for $350958d.

This can only occur once every $proccooldown sec. |
| 320953 | Shadowed Shortblade | Shadowfury stun duration increased by $s1%. |
| 320954 | Zovaal's Resolution | Unending Resolve duration increased by $s1%. |
| 320956, 322454, 322455 | Disembodied Tongue | Every enemy within $322454A1 yards that is afflicted by Curse of Tongues grants you $322455s1% Haste. |
| 320957 | Warlock's Bargain | Increase your Haste by $s1%, but reduce your Stamina by $s2%. |
| 321152 | Vandal's Zeal | $?c2[Holy Fire][Mind Blast] damage increased by $s1%. |
| 321153 | Flashbox | Increase the healing of your next Flash Heal by $s1%. |
| 321155 | Searing Luminosity | Reflect $w2% of damage taken. |
| 321156 | Searing Luminosity | Reflect damage to your attacker. |
| 321189 | Dead Mawrat | Killing a Mawrat grants you a bonus charge of Shadow Word: Death.

The bag can hold up to $321189u dead Mawrats. |
| 321192 | Dazzled | Casting $?s14914[Holy Fire][Mind Blast] will daze the target, reducing the target's movement speed and chance to hit by $321192s1% for $321192d.$?a320885[][

Subsequent casts of Mind Blast or Holy Fire will remove this effect.] |
| 321199 | Looted | Phantasma has already been looted. |
| 321217, 321224, 321228 | Rapid Contagion | Using Mind Control on a Mawrat will trigger Rapid Contagion, causing all Mawrats within $321228a1 yards to give birth to a litter of 2-5 additional Mawrats. |
| 321289 | Power Word: Snuggle | Players affected by your Power Word: Fortitude now also grant $321289s1% Stamina to party members within 3 yards. |
| 321433 | Mad Wizard's Intuition | At the beginning of each floor, you will receive an intuition, telling you to cast a series of spells in a certain order.

If you successfully cast these spells in the correct order, your Intellect will be increased by $321445s1%. |
| 321445 | Mad Wizard's Intellect | At the beginning of each floor, you will receive an intuition, telling you to cast a series of spells in a certain order.

If you successfully cast these spells in the correct order, your Intellect will be increased by $321445s1%. |
| 321924 | Class Power | TEMP - Someday I will be a real power!

Increase all stats by $s1%. |
| 321934 | Dismiss Charmed Enemy | Release the enemy that you have struck with the Hematoma Bat. |
| 322023, 322054 | Champion's Decree | Breaking an Ashen Phylactery increases the damage of your next $?c3[Revenge][Slam] by $322054s1%. This effect stacks $322054u times. |
| 322024 | Shadehound Tooth | The cooldown of $?c1[Mortal Strike]?c2[Bloodthirst][Shield Slam] is reduced by $s1%. |
| 322025 | Edge of Hatred | The damage of $?c1[Mortal Strike]?c2[Rampage][Shield Slam] is increased by $s1%. |
| 322026 | Bladed Bulwark | Ignore Pain has a $s1% chance to cast $?c1[Die by the Sword]?c2[Enraged Regeneration][Shield Wall]. |
| 322027 | Zovaal's Warbanner | The duration$?c1[s of Bladestorm and Avatar are]?c2[s of Recklessness and Bladestorm are]?c3[ of Avatar is][] increased by $s1%. |
| 322028 | Propeller Blade | Whirlwind increases your movement speed by N% and reduces your fall speed. |
| 322029 | Fan of Longswords | $?c1[Mortal Strike]?c2[Rampage][Shield Slam] also casts Whirlwind. |
| 322031, 322081 | Spattered Soles | Striking a Mawrat with Charge or Heroic Leap instantly kills the Mawrat and resets the cooldown of the ability. |
| 322032, 329316 | Smoldering Inertia | Charge and Heroic Leap increase your damage done by $329316s1% for $329316d. |
| 322033 | Desiccated Grasshopper | Striking an enemy with Heroic Leap restores N% of your health. |
| 322034 | Stone of the Unmoving Citadel | After landing your Heroic Leap, your damage taken is reduced by N% and your damage dealt is increased by X%.  This effect goes away once you move. |
| 322035, 329165 | Pleonexian Command | $?s202168[Impending Victory][Victory Rush] takes $329165s1 Phantasma from the target. |
| 322036 | Bloodstained Whetstone | The damage of Whirlwind$?c3[ and Thunder Clap are][ is] increased by $s1%. |
| 322037 | Victor's Braggadocio | Victory Rush has an N% chance to be castable again. |
| 322038 | Succulent Carpaccio | Ignore Pain absorbs additional damage equal to $s1% of your maximum health$?c3[][, and its cooldown is reduced by ${$s3/-1000} sec]. |
| 322040 | Longstrider Chalice | The range of Charge and Intervene is extended by N yards. |
| 322041 | Sprinter's Braid | The damage of Charge is increased by N% for every X seconds that you do not cast Charge, up to a maximum of Y%. |
| 322042 | Windswept Visor | You can Charge without triggering its cooldown while under the effects of Victory Rush. |
| 322043, 322091 | Resonant Throatbands | Enemies affected by any of your Shouts take $322091s1% increased damage from all sources. |
| 322044 | Juggernaut's Warhorn | Your Shouts increase the damage of your next Charge by N%. |
| 322045 | Cowing Glare | Intimidating Shout now increases enemy damage taken by N%. |
| 322046 | Ragemote | Your abilities cost no Rage for $d after choosing this power. |
| 322047 | Brawler's Brass Knuckles | Rage generation increased by $s1%. |
| 322048 | Signet of Unending Fury | Casting Slam when at 100 or more Rage will expend 100 Rage, dealing (very large number)% additional damage, but stunning you for N seconds. |
| 322049 | Periapt of Furor | Berserker Rage lasts $s1% longer and also causes your party members to go berserk. |
| 322050 | Mark of Masochism | Hamstring steals the enemy’s speed, granting you N% movement speed for the duration of the effect. |
| 322051 | Warlord's Resolve | The cooldown of $?c1[Die by the Sword]?c2[Enraged Regeneration][Last Stand] is reduced by $s1%. |
| 322052 | Bladelord's Intimidator | Successfully interrupting a spell with Pummel causes the target to tremble in fear for N sec. |
| 322053 | Tendon Slicer | Hamstringing an enemy that you have already Hamstrung will root them for N sec. |
| 322093 | Thundering Roar | Your Shouts last $s1% longer. |
| 322154 | Catharstick Shock | $s2% of all damage that you take is stored in the Catharstick.  The initial damage of your next $?s204197[Purge the Wicked][Shadow Word: Pain] deals this stored damage to your target. |
| 322540 | Berserker Rage | Go berserk, removing and granting immunity to Fear, Sap, and Incapacitate effects for $d. |
| 322823, 323024, 323026 | Willbreaker | Damaging the same enemy with $?a212612[Demon's Bite]?s263642[Fracture][Shear] $s1 times in a row grants you $323026s1% additional damage to that enemy. |
| 322824, 326467 | Felborn Pendant | Your first $?a212612[Chaos Strike]?a212613[Soul Cleave][] on a floor deals an additional $326467s1% damage. |
| 322825 | Felborn Torch | Immolation Aura increases the damage of $?a212612[Chaos Strike]?a212613[Soul Cleave][] by $s1%$?a212613[, and changes the damage type to Fire][]. |
| 322826 | Felborn Shield | $?a212612[Chaos Strike]?a212613[Soul Cleave][] automatically applies $?a212612[Blur]?a212613[Demon Spikes][]. This effect can only occur once every $proccooldown sec. |
| 322827 | Finely-Honed Bone Blades | The damage of $?a212612[Blade Dance]?a212613[Sigil of Flame][] is increased by $s1%. |
| 322828 | Demonglass Curio | The cooldown of $?a212612[Blade Dance is]?a212613[your Sigils are][]  reduced by $s1%. |
| 322829, 323076 | Fury Wrappings | Using $?a212612[Blade Dance]?a212613[one of your Sigils][] increases your chance to dodge by $323076s1% for $323076d. |
| 322830, 323115 | Dark Stalker's Draught | Every $s1 uses of $?a212612[Blade Dance]?a212613[your Sigil abilities][] will heal you for $323115s1% of your maximum health and refill your Fury. |
| 322831, 323153 | Phantasmal Iris | Looting Phantasma increases the damage of your next $?a212612[Eye Beam]?a212613[Fel Devastation][] by $323153s1%. |
| 322832 | Darkglare Medallion | $?a212612[Eye Beam]?a212613[Fel Devastation][] has a $s1% chance to not incur its cooldown. |
| 322833, 323220, 352138, 352139 | Shield of Unending Fury | You are immune to all damage when channeling $?a212612[Eye Beam]?a212613[Fel Devastation][]. |
| 322834 | Ragehoof | Killing a Mawrat reduces the cooldown of Metamorphosis by $s1 sec. |
| 322836 | Shifting Signet | Metamorphosis cooldown reduced by $s1%. |
| 322838 | Frenzywing | $?a212612[Fel Rush]?a212613[Infernal Strike][] has a 1 sec recharge for the next $d. |
| 322839, 324917 | Fleetwing | You move $324917s1% faster for $324917d after casting $?a212612[Fel Rush]?a212613[Infernal Strike][]. |
| 322840 | Forcewing | $?a212612[Fel Rush]?a212613[Infernal Strike][] range increased by $s1%. |
| 322842 | Ghastly Chains | NYI

Obtain 3% all stats. |
| 322843 | Tormentor's Spiked Noose | Imprison now charms your target, forcing them to fight alongside you. |
| 322844 | Blindfold of Focus | Damaging an enemy with Throw Glaive from at least 20 yards away will grant you $326510s1 Fury. |
| 322845 | Heart-Piercing Spine | Your next $u uses of Throw Glaive will always reduce enemy health to at least $s2%. |
| 322848 | Immolation Flux | Immolation Aura damage increased by $s1%. |
| 322849, 326559 | Manafeeder's Bib | Successfully dispelling a Magic effect with Consume Magic heals you for $326559s1% of your maximum health and grants you a random Well Fed buff. |
| 322850 | Soarstone | You restore $s1% health per second while Gliding. |
| 322851, 326581 | Soulrender of Zovaal | Generate a Lesser Soul Fragment from a nearby enemy every $t1 sec. |
| 322852, 322997 | Ashen Hide | Your primary pet takes $322997s1% less damage from all sources. |
| 322853 | Huntsman's Pouch | The damage of $?a137015[Kill Command]?a137016[Aimed Shot]?a137017[Raptor Strike][] is increased by $s1%. |
| 322854 | Huntsman's Sash | The cooldown of $?a137015[Kill Command]?a137016[Aimed Shot]?a137017[Wildfire Bomb][] is reduced by $s1%. |
| 322855 | Phantasmal Fetish | Looting Phantasma increases the damage of your next (Multi-Shot/Carve) by N%, up to a maximum of X%. |
| 322856 | Art of the Endless Cavalcade | $?a137015[Multi-Shot]?a137016[Multi-Shot]?a137017[Carve][] no longer has a Focus cost. |
| 322857 | Beaststalker's Signet | The cooldown of $?a137015[Bestial Wrath]?a137016[Trueshot]?a137017[Coordinated Assault][] is reduced by $s1%. |
| 322858 | Beaststalker's Wrappings | (Bestial Wrath/Trueshot/Coordinated Assault) also increases your chance to dodge by N%. |
| 322859 | Moccasins of Ascent | A special 1-minute (Bestial Wrath/Trueshot/Coordinated Assault) is automatically applied to you every time you ascend to a new floor. |
| 322860 | Hateful Shard-Ring | Interrupting with (Counter Shot/Muzzle) reducdes the cooldown of (Bestial Wrath/Trueshot/Coordinated Assault) by N sec. |
| 322861 | Flute of Skoldus | A Mawrat fights by your side. |
| 322862 | Soul Eater Jerky | Increase your pet’s health by N%. |
| 322863 | Bone Collar | Increase your pet’s damage by $s1%. |
| 322864 | Pristine Flute of Skoldus | An Enormous Mawrat fights by your side. |
| 322865 | Deadeye Satchel | Your next N Kill Shots are guaranteed kills. |
| 322866 | Acrobat's Rations | Disengage gains N charges. |
| 322867 | Acrobat's Vision | Disengage grants N Focus. |
| 322868 | Cadaverous Cleats | Landing on a Mawrat with Disengage will instantly kill it.  Performing this feat N times will increase all damage done by X%. |
| 322869 | Acrobat's Razor | Your first damaging attack after Disengaging deals an additional (large number)% damage. |
| 322870 | Feline Femur | Aspect of the Cheetah's cooldown is decreased by $s1%. |
| 322871 | Scent of Blood | Killing an enemy adds N seconds to the duration of your next Aspect of the Cheetah. |
| 322872 | Graven Winds | Aspect of the Cheetah's movement speed bonus is increased by an additional $s1%. |
| 322873 | Sigil of Scutes | Aspect of the Turtle reduces damage taken by an additional $s1%. |
| 322874 | Chelonian Crest | You can now attack during Aspect of the Turtle, and its duration is tripled. |
| 322875 | Euphoria Emblem | Exhilaration heals you for $s1% additional health. |
| 322876 | Wildhide Bandages | Exhilaration automatically applies Aspect of the Cheetah (and Aspect of the Eagle/Aspect of the Wild), even if it is on cooldown. |
| 322877 | Permafrost Barbs | The first N attacks against targets affected by your Freezing Trap will not break the effect. |
| 322878 | Peltsman's Grit | You take N% less damage for X seconds after placing a trap. |
| 322879 | Necrotic Touch | Your $?a137015[Concussive Shot]?a137016[Concussive Shot]?a137017[Wing Clip][] lasts forever. |
| 322880 | Appetizing Gravy | Mawrats periodically attack the target of your Hunter’s Mark. |
| 322881 | Craven Strategem | Taking damage reduces the cooldown of Feign Death by $s1 \|4second:seconds;. |
| 324501, 342362 | Chilling Touch | Deathborne creates a frozen storm around you that slows enemy movement speed by $324501s1% and deals $324501s3 Frost damage every $s1 sec to enemies inside the area. |
| 325800 | Phial of Light | Your Steward's Phial of Serenity now restores an additional $s1% of your health. |
| 325801 | Phial of Pain | Your Steward's Phial of Serenity increases damage and healing by $s1% for $323436d. |
| 325830 | Bottomless Chalice | Your Steward also provides Phials of Serenity for your allies. |
| 325887 | Strigidium | You can now order your Steward to heal or buff you in combat. |
| 325890 | Darksight Orbs | Your Steward can now hunt for materials within Torghast. |
| 326510 | Blindfold of Focus | Gain $s1 Fury. |
| 326579 | Torghast Ambassador | Assisting a Covenant captive with what they need will result in them staying and assisting you after instead of leaving to hide. |
| 327363 | Torch of Humility | Your next Boon of the Ascended lasts for ${($s1/1000+$325013d)} sec. |
| 327370 | Faithstone | Your self-healing from Boon of the Ascended is increased by $s1%. |
| 327468 | Second Chorus | The cooldown of Boon of the Ascended is reduced by ${$s1/-1000} sec. |
| 327469 | Deeply-Held Vow | Ascended Nova applies Shadow Word: Pain to enemies and Renew to allies. |
| 327513 | Feathered Fetters | The damage and healing of Boon of the Ascended's effects are increased by $s1%, but you cannot move for its duration. |
| 327536, 327562, 327563 | Glorious Prayer | Boon of the Ascended heals you for $327562s1% of your health.

Ascended Eruption restores $s3275631% of your $?a137033[Insanity and ][]Mana. |
| 329146 | Soulwrought Studs | Your Armor and Block value are increased by $s1%. |
| 329207 | Unbound Fortitude | $@spellname324717 increases the duration of $?c1[Die by the Sword]?c2[Enraged Regeneration][Shield Wall] by $s1% per application. |
| 329213, 329214 | Voracious Culling Blade | $?a317320[Condemn's][Execute's] damage is increased by $s1%. Casting $?a317320[Condemn][Execute] $s3 times allows you to use it at any time, regardless of the target's health. |
| 329237 | Mask of Sheer Terror | Increases the amount of damage required to break your $?s205369[Mind Bomb][Psychic Scream] by $s1%. |
| 329241, 329281 | Volatile Phantasm | Fade creates an illusion of the Priest for $329242d, tricking enemies to attack it instead. The illusion explodes for Shadow damage when it dies, increased based on how long it remained alive. |
| 329242 | Volatile Phantasm | Fade creates an illusion of the Priest, causing nearby creatures to attack it. The illusion explodes for Shadow damage when it dies, increased based on how long it remained alive. |
| 329267 | Spell Reflection | Raise your $?c3[shield][weapon], reflecting spells cast on you and reducing magical damage you take by $s2%. $?a188672[Lasts $d.][Lasts $d or until a spell is reflected.] |
| 329268 | Misshapen Mirror | Spell Reflection lasts $s1% longer, and applies to your party. |
| 329274 | Phantasmic Detonation | Your Phantasm explodes, dealing $s1 Shadow damage. |
| 329275, 329277, 329278, 347335 | Shrieking Flagon | Whirlwind $?c3[and Thunder Clap pull][pulls] $329277i random enemies within $329277A1 yds to you. |
| 329283 | Umbral Ear Trumpet | Your Shouts cause you to yell another, random Shout. |
| 329300 | Pandemonium Loop | Casting $?s14914[Holy Fire][Mind Blast] on a target that is feared triggers Pandemonium, fearing all enemies near your target for $329398d. |
| 329323 | Shattered Anima | Your first Shattering Throw on a floor deals $322084s1% increased damage, and shatters an Anima Cell from the target. Does not work against bosses. |
| 329345 | Signet of Tormented Kings | Activating $?s152277[Ravager][Bladestorm], Recklessness, or Avatar randomly casts one of the other two abilities. |
| 329398 | Pandemonium | Lets out a psychic scream, causing $i enemies within $A1 yards to flee, disorienting them for $d. Damage may interrupt the effect. |
| 329452, 329454 | Ogundimu's Fist | Pummel knocks the target away and stuns them for $329454d. |
| 329457 | Scales of Trauma | Deals $s1 Shadow damage, increased by healing done. |
| 329482 | Singing Stones of Battle | Battle Shout lasts $s1% longer. |
| 329483 | Singing Stones of Courage | Rallying Cry lasts $s1% longer. |
| 329484 | Singing Stones of Intimidation | Intimidating Shout lasts $s1% longer. |
| 329485 | Singing Stones of Bravery | Challenging Shout lasts $s1% longer. |
| 329486 | Singing Stones of Terror | Piercing Howl lasts $s1% longer. |
| 329488 | Singing Stones of Unnerving | Demoralizing Shout lasts $s1% longer. |
| 329489 | Singing Stones | The duration of one of your Shouts is increased by $329482s1%. Which Shout these Singing Stones affect is revealed when this power is selected. |
| 329510 | Life Barrier | Power Word: Shield's absorption is increased by $s1% of your maximum health. |
| 329526 | Wailing Winds | Wind Shear cooldown reduced by ${$m1/-1000}.1 sec. |
| 329537 | Essence of the Ancestors | $?s32182[Heroism][Bloodlust] grants an additional $s1% Haste. |
| 329538 | Astral Bulwark | Astral Shift duration increased by ${$m1/1000}.1 sec. |
| 329573 | Vial of Soothing Waters | $?s157153[Cloudburst Totem][Healing Stream Totem] healing amount increased by $s1%. |
| 329588 | Fragments of Obscurity | Fade's cooldown is reduced by $/1000;s1 seconds and prevents your movement speed from being reduced below $s2%. |
| 329590, 329591, 329592 | Elemental Core | Each $?s51505[Lava Surge][Stormbringer] buff you consume increases the damage of $?s51505[Lava Burst][Stormstrike] by $329591s1%. After generating $329591u stacks, the cooldown of $?s51505[Lava Burst][Stormstrike] is reduced by $329592s2%. |
| 329595, 329596, 330512 | Leeching Lilypad | Hex now damages the target for $329596s1 Shadow damage every $329596t1 sec, healing you for the amount drained. This damage will not break Hex. |
| 329605, 329607 | Power Overwhelming | Power Infusion causes $?c2[Flash Heal][Shadow Mend], Mind Blast, and Holy Fire to become instant cast and have no cooldown. |
| 329632 | Light-Infused Egg | $?c3[Mind Flay damage has a $s1%][Smite has a $s2%] chance to grant Power Infusion. |
| 329645 | Soul Sapper | While an enemy is shackled by your Shackle Undead, your Power Infusion's cooldown recovers $s1% faster. |
| 329678 | Reflective Shield | $s1% of the damage you absorb with Power Word: Shield is reflected back at the attacker. |
| 329689 | Wailing Visage | Your $?s205369[Mind Bomb][Psychic Scream] lasts an additional $s2 seconds. |
| 329693 | Enduring Spirit | Your Vampiric Embrace, Pain Suppression, and Guardian Spirit last $s1% longer. |
| 329726, 329728 | Rimeblood | Frost Shock reduces all damage the target deals by $329728s1% for $329728d. |
| 329732, 329767 | Untaintable Waters | Targets healed by your $?s157153[Cloudburst Totem][Healing Stream Totem] take $329767s1% reduced damage for $329767d. |
| 329768, 329771, 329772 | Chains of Devastation | Casting Chain Heal makes your next Chain Lightning instant cast. Casting Chain Lightning makes your next Chain Heal instant cast. |
| 329793, 329794 | Mawrats on Ice | Frost Shock freezes Mawrats in a block of ice, killing them instantly. |
| 329796 | String of Fangs and Talons | Starsurge, Swiftmend, Ferocious Bite, and Thrash deal $s1% increased damage and healing. |
| 329800 | Steelwood Slab | Barkskin's duration is increased by $s1%. |
| 329801 | Earthquake | Causes the earth within $a1 yards of the target location to tremble and break, dealing ${$s4*$77478s1} Nature damage over $d and has a $77478s2% chance to knock the enemy down. Multiple uses of Earthquake may overlap.

\|cFFFFFFFFThis spell is cast at a selected location.\|r |
| 329802 | Moon-Spirit Essence | The cooldowns of Berserk, Celestial Alignment, Tranquility, and Incarnation are reduced by $s1%. |
| 329803 | Plague-Hardened Hide | Ironfur lasts ${$s1/1000} sec longer and persists outside of Bear Form. |
| 329805, 329806 | Shield of Spirits | While Astral Shift is active, you have a $329806s1% chance to resist spells. |
| 329815, 334586, 334596, 334597, 334598 | Affinity Stones | You have all of the Affinity passive bonuses, and their effects are increased by $s5%. |
| 329817 | Flowing Streams | When Healing Stream Totem heals a target, you have a $s1% chance to also cast a free, instant Chain Heal at the same target. |
| 329857 | Deathseer's Satchel | Placing a totem causes you to drop another, random totem. |
| 329886 | Blackened Boulder | Receive a power from Denathrius, Master of Revendreth. |
| 329937, 329941 | Deathseer Choker | Each active totem increases your damage and healing by $s1%. |
| 329949, 329950 | Blood of Heroes | Your first $?s32182[Heroism][Bloodlust] on a floor does not cause the $?s32182[Exhausted][Sated] effect, will not incur its cooldown, and will apply even if $?s32182[Exhausted][Sated]. |
| 329959 | Petrus Ring | Entangling Roots can withstand $s1% more damage before breaking. |
| 329968 | Oath of Druids | You permanently have the benefits of Heart of the Wild. |
| 329969 | Sylvatican Charm | Your periodic heals have a very high chance to apply Ironbark to the target. |
| 330179, 330374 | Heart of the Deathseer | $?a137041[Lava Lash damage is increased by $s1%][Chain Lightning now jumps to $s3 additional targets, and deals $s4% additional damage per jump]. |
| 330383, 346052 | Guardian's Cudgel | Capacitor Totem stun duration increased by $s1%, and when Capacitor Totem fades, another Capacitor Totem is automatically dropped in the same place. |
| 330551 | Spellweaver's Mojo | Your Fire, Frost, and Arcane spells cause the target to take $s1% increased damage from your other two elements for $330556d. |
| 330556 | Spellweaver's Mojo | Damage taken by Fire and Frost increased by $s1%. |
| 330558 | Spellweaver's Mojo | Damage taken by Arcane and Frost increased by $s1%. |
| 330560 | Spellweaver's Mojo | Damage taken by Arcane and Fire increased by $s1%. |
| 330579, 330584 | Fire Juggler | Your Fire Blast launches your enemy into the air. |
| 330630, 350234 | Gravity Dynamo | Knocking, rooting, or incapacitating enemies increases Fire, Frost, and Arcane damage done by $s1% for $350234d. |
| 330638 | Alluring Cheese | Knocking, rooting, or incapacitating enemies increases Fire, Frost, and Arcane damage done by $s1% for $350234d. |
| 330652 | Bottle of Moonshine | Enemies affected by Moonfire deal $s1% less damage. |
| 330657, 330658, 330661, 330662, 330663 | Writings of Lycara | You gain $s1 of a secondary stat while in each form:

No Form: Haste
Cat Form: Critical Strike
Bear Form: Versatility
Moonkin Form: Mastery |
| 330666, 330668 | Lycara's Twig | Shapeshifting increases the damage or healing of your next Shred, Mangle, Wrath, or Regrowth by $s1%. |
| 330670 | Curious Bramblepatch | Entangling Roots deals $339s2 Nature damage every $339t2 sec. |
| 330671, 330674 | Remote Sheep Detonator | Polymorphed enemies become a ticking bomb, accumulating $<bomb> Arcane damage every $330674t seconds, stacking up to $330674u times. When Polymorph ends, it explodes on all nearby enemies. |
| 330672, 330673 | Blood-Tinged Teeth | Growl increases the target's damage taken by $s1% for $330673d. |
| 330675 | Sheep Detonation | The sheep explodes, dealing $s1 Arcane damage. |
| 330743, 330745 | Timeweaver's Needle | Spells cast during Alter Time reduce your remaining cooldowns of all spells by $m1 $Lsecond:seconds;. |
| 330855 | Creeping Freeze | Ice Block spreads a freezing pulse, causing nearby enemies to take Frost damage and become trapped in ice for $330858d. |
| 330858 | Creeping Freeze | Stuns the target for $d. |
| 330860 | Creeping Freeze | Moving during Ice Block spreads a freezing pulse, causing nearby enemies to take Frost damage and become trapped in ice for $330858d. |
| 330873 | Entangling Roots | Roots the target in place for $d. Damage may cancel the effect.$?s33891[

\|C0033AA11Tree of Life: Instant cast.\|R][] |
| 330888 | Creeping Freeze | Deals $s1 damage. |
| 330897 | Grasping Tendrils | The first $s2 melee $lattack:attacks; into Barkskin or Ironbark cause Entangling Roots to appear on the attacker. |
| 330904, 330906 | Rootwood Scarab | When Entangling Roots breaks, it explodes for $330906s1 Nature damage to all nearby enemies. |
| 330915, 330916 | Draught of Midnight Blazes | While Moonfire or Rake are on at least $s1 targets, your damage and healing are increased by $330916s1%. |
| 331179 | Acrobat's Rations | Disengage cooldown reduced by ${$m1/-1000}.1 sec. |
| 331181 | Sticky Tar | Tar Trap snares the target by an additional $s1%. |
| 331183, 342707 | Piercing Scope | Hunter's Mark now increases damage the target takes from all sources by $s1%. |
| 331185 | Bone Barbs | Kill Shot damage increased by $s1%. |
| 331186 | Beaststalker's Signet | Duration of $?a137015[Bestial Wrath]?a137016[Trueshot][Coordinated Assault] increased by $s1%. |
| 331187, 331188, 348662 | Cadaverous Cleats | Disengage reduces all damage you take by $331188s1% for $331188d. |
| 331190 | Euphoria Emblem | Exhiliration cooldown reduced by ${$m1/-1000}.1 sec. |
| 331192, 358012 | Necrotic Venom | $?a137016[Aimed Shot][Kill Command] damage increased by $s1%. |
| 331193 | Feline Femur | Aspect of the Cheetah cooldown reduced by ${$m1/-1000}.1 sec. |
| 331194, 331195, 331196 | Scaredy Rat | If you use Scare Beast on a Mawrat, it will die after $331195d. |
| 331197, 331269 | Soulforge Embers | If you launch a Flare into your Tar Trap, all enemies inside of the Tar Trap will burn for $331269s1 Fire damage every $331269t1 sec for $331269d. |
| 331227 | Demonic Resolve | The cooldown of $?a212612[Blur]?a212613[Fiery Brand][] is reduced by $s1%. |
| 331283, 331284 | Peltsman's Grit | Enemies affected by any of your traps deal $331284s1% less damage for $331284d. |
| 331287 | Bursting Tar | Tar Trap radius Increased by $s1%. |
| 331296, 331297 | Forsworn Feather | Disengage increases your movement speed by $s1%, permanently, stacking up to $331297u times. |
| 331300 | Chelonian Crest | Aspect of the Turtle no longer prevents you from attacking, and its duration is increased by $s1%. |
| 331338, 331339 | Petrified Pet Food | Ashen Phylacteries have a $s1% chance to contain some Petrified Pet Food when destroyed. Consuming Petrified Pet Food will increase your pet's size by $s3% and damage by $331339s2% for $331339d. |
| 331345 | Bountiful Souls | You receive an additional $s1% healing from Soul Fragments. |
| 331355 | Craven Strategem | Feign Death cooldown reduced by ${$m1/-1000}.1 sec, and Feign Death now removes most negative status effects from yourself and your pet. |
| 331357, 331362 | Hateful Shard-Ring | Your first $?a137017[Wing Clip][Concussive Shot] against a target now roots them in place for ${$m1/1000}.1 sec. |
| 331367, 331368 | Sigil of Skoldus | Dropping any trap increases you and your pet's damage dealt by $s1% for $331368d. |
| 331369 | Acrobat's Razor | Disengage drops a random trap from where you leap from, and where you land. |
| 331375 | Revitalizing Spirit | Periodic healing from Regrowth reduces the cooldown of a major ability of the target by $s1 sec. |
| 331390 | Feathers of a Hundred Flocks | Spinning Crane Kick radius and damage increased by $s1%. |
| 331426 | Technique of the Rushing Tiger | Tiger Palm range increased by $s1 yds,  deals damage $s2 additional $ltime:times; and charges you towards the target. |
| 331431 | Rushing Tiger Strikes | Tiger Palm range increased by $s1 yds,  deals damage $s2 additional $ltime:times; and charges you towards the target. |
| 331439 | Fortified Leg Braces | Leg Sweep cooldown reduced by ${$s1/-1000} sec. |
| 331442, 331446 | Celestial Dynasty | The duration of $?s137023[$@spellname132578]?s137025[$@spellname123904]?s325197[$@spellname325197][$@spellname322118] is increased by $s1%, and is summoned the first time you enter combat on a floor. |
| 331447 | Demonic Bias | All enemy Souls Fragments are treated as Demon Souls and the duration of the effect is increased by $s1%. |
| 331455, 331461 | Amplifying Mirror | The target of your Misdirection has all of their damage increased by $s1% while your Misdirection is active. |
| 331476 | Bag of Mawrat Eyes | When choosing this power, and at the start of each new floor, gain the effects of $?a137016[Trueshot]?a137015[Aspect of the Wild][Coordinated Assault] for ${$m1/1000}.1 sec. |
| 331493 | Darkest Hour | You automatically trigger Darkness when you fall below $s1% health. This effect can only occur once every $331497d. |
| 331497 | Darkest Hour | You cannot benefit from Darkest Hour again for $d. |
| 331511 | 36 Pressure Point Technique | Touch of Death cooldown reduced by ${$s1/-1000} seconds. |
| 331512 | Shadowboxing Treads | Blackout Kick damage increased by $s2% and strikes an additional $s1 $ltarget;targets. |
| 331514 | Tumbling Rollstone | Roll has $s1 additional \|4charge:charges;. |
| 331524 | Death Gate | Calls forth a Horseman of the Ebon Blade to assist you in battle. |
| 331528, 331535, 331536 | Corrosive Dosage | Vivify leaves a corrosive mist around targets it heals, dealing $s1% of its healing as Nature damage to nearby enemies every $331535t1 sec for $331535d. |
| 331620, 331622 | Hit Scheme | Dealing damage with Blackout Kick increases the damage of your next Keg Smash, Rising Sun Kick, or Fists of Fury by $331620s1%, stacking up to $331620u times. |
| 331647, 331649 | Deathtouched Brew | Touch of Death damage increases Fortifying Brew by an additional $s1% maximum health while in Torghast. |
| 331650 | Flowing Chi Rolls | Chi Wave is cast on all enemies you roll through. |
| 331652, 347703 | Flowing Chi Rolls | The duration of $?s137023[$@spellname132578]?s137025[$@spellname123904]?s325197[$@spellname325197][$@spellname322118] is increased by $s1%, and is summoned the first time you enter combat on a floor. |
| 331653 | Mystic Touch | Your damage weakens the target, increasing Physical damage taken by $113746s1%. |
| 331654 | Amplified Samples | Tiger Palm damage applies $M1 additional $Lstack:stacks; of Mystic Touch for $331653d. |
| 331655 | Stroke of Elegance | Cooldowns are reduced by $s1 sec., to a minimum of $s2 sec. |
| 331660 | Bad Karma | Provoke has a $s1% chance to cast Touch of Karma. |
| 331663, 331665 | Rolling Tigers | Roll casts Tiger's Lust on all nearby targets. |
| 331672 | Tiger Style | Crane Style increases your Mastery and Versatility by the total of your Critical Strike and Haste.

Tiger Style increases your Critical Strike and Haste by the total of your Mastery and Versatility.

Roll switches between Crane Style and Tiger Style. |
| 331673 | Crane Style | Crane Style increases your Mastery and Versatility by the total of your Critical Strike and Haste.

Tiger Style increases your Critical Strike and Haste by the total of your Mastery and Versatility.

Roll switches between Crane Style and Tiger Style. |
| 331679 | Fatal Flying Guillotine | Touch of Death strikes up to $s1 additional nearby $Ltarget;targets. |
| 331763 | Warden Shackles | Your Imprison now lasts for 10,000 years. |
| 331823, 331825 | Whirling Stormgem | Breaking an Ashen Phylactery increases your movement speed by $331825s2% and Spinning Crane Kick damage by $331825s1% for $331825d, stacking up to $331825u times. |
| 331826, 331828, 331829 | Katamawri | Rolling over Maw Rat corpses and broken Ashen Phylacteries reduces damage taken by $331828w1%. for $331828d, stacking up to $331828u times. |
| 331830, 331831 | Caught by the Dropkicks | Interrupting spells and abilities by any means increases the damage you deal to the target by $331831s1%, and they deal $331831s2% less damage for $331831d. |
| 331834, 331835 | Balance of the Ox | While in combat, your spells and abilities increase damage and healing by $331835s1% for $331835d, but reduce your movement speed by $331835s2%,  stacking up to $331835u times. Your movement abilities allow you to move freely for $331835d. |
| 331865 | Skull Bloomer | Death Strike, Frost Strike, and Death Coil deal $s1% additional damage. Death Coil's healing is also increased by $s1%. |
| 331916, 350557 | Death Hook | Death Grip instead pulls you to your target and causes them to slam to the ground, knocking down nearby enemies for $331917d. |
| 331917 | Death Hook | Knocks down the target, stunning them for $d. |
| 331921 | Tome of Swordplay | Mind Freeze's cooldown is reduced by $s1 seconds when you successfully interrupt a cast. |
| 331959 | Superstrain | Blast the target with a frigid wind, dealing ${$s1*$<CAP>/$AP} $?s204088[Frost damage and applying Frost Fever to the target.][Frost damage to that foe, and reduced damage to all other enemies within $237680A1 yards, infecting all targets with Frost Fever.]

\|Tinterface\icons\spell_deathknight_fro |
| 331962 | Blood Boil | Deals $s1 Shadow damage$?s212744[ to all enemies within $A1 yds.][ and infects all enemies within $A1 yds with Blood Plague.

\|Tinterface\icons\spell_deathknight_bloodplague.blp:24\|t \|cFFFFFFFFBlood Plague\|r
A shadowy disease that drains $o1 health from the target over $d.] |
| 332001 | Monstrous Concoction | Death Coil infuses you and your minions with monstrous power, increasing damage and attack speed by $s1% for $332004d. |
| 332125 | Creeping Decay | $?s315442[Death's Due]?s152280[Defile][Death and Decay] gains $s3 additional $Lcharge:charges; and its radius is increased by $s1 yds. |
| 332199 | Phearomones | Enemies damaged by your $?s315442[Death's Due]?s152280[Defile][Death and Decay] have a chance to cower in place for $206961d. |
| 332200 | Crystal of Perpetual Displacement | Reduce the cooldown of Demonic Circle: Teleport by ${$m1/-1000}.1 sec. |
| 332201, 332205, 348403 | Smoking Shard of Teleportation | Using Demonic Circle: Teleport or your Demonic Gateway reduces all damage you take by $332205s1% for $332205d. |
| 332212 | Occult Emitter | Runic Power generation increased by 100% while affected by your Anti-Magic Shell and Anti-Magic Zone. |
| 332320, 332337, 332346 | Bone Harvest | Death Coil afflicts enemies with Bone Harvest, dealing $s1% of Death Coil's damage over $332320d. Targets killed during Bone Harvest are reanimated as a Risen Skulker or a Magus of the Dead for $332337d. |
| 332365 | Ancient Drake Breath | Summons a frostwyrm who breathes on all enemies within $s1 yd in front of you, stunning them for $d. |
| 332398 | Shattered Gauntlet | Hammer of Wrath deals $s1% increased damage. |
| 332407 | Defiled Prayer Beads | The cooldowns of Blessings are reduced by $s1%. |
| 332409 | Winged Medallion | For the first $s1 sec of each floor, you have Avenging Wrath. |
| 332517, 332523 | Death Turf | Within your $?s315442[Death's Due]?s152280[Defile][Death and Decay], you gain $s1% Haste, and enemies deal $s2% reduced damage to you. |
| 332531 | Ancient Drake Breath | Stuns the target for $d. |
| 332532 | Boundless Fortitude | Mind Freezing a spell cast activates Icebound Fortitude. |
| 332534, 332536 | Soulforged Censer | When an enemy dies within Consecration, you gain $s1% damage and healing for $332536d. |
| 332539 | Soul-Touched Reins | Grand Crusader, Art of War, and Infusion of Light reduce the remaining cooldown of Divine Steed by $s1 sec. |
| 332540 | Ancient Writ of Order | Holy Power spending abilities are $s1% more effective. |
| 332541 | Radiant Essence | Forbearance increases damage dealt by $s1%. |
| 332542 | Soulsteel Hasp | The cooldown of Divine Shield is reduced by $s1%. |
| 332543, 350242 | Entropic Pool | Dealing damage with Death and Decay increases damage you deal to the target by $s1%, stacking. |
| 332546, 332547 | Animate Armaments | Death Grip strips your enemy of their weapon if they have one, animating it to fight by your side for 6s. |
| 332548 | Necromantic Bile | Your Heart Strike, Obliterate, and Scourge Strike deal $s1% more damage. |
| 332573 | Lich Robes | Reduces the cooldown of Lichborne by $s1 sec per $s2 Runic Power spent. |
| 332584 | Unquenchable Blade | $?c3[Army of the Dead's cooldown is decreased by ${$abs($s3/1000)} seconds.]?c2[Empower Rune Weapon's cooldown is decreased by ${$abs($s1/1000)} seconds.][Dancing Rune Weapon's cooldown is decreased by ${$abs($s1/1000)} seconds.] |
| 332603 | Exterminator | Death Grip has $s1 additional $Lcharge:charges;, and killing a Mawrat refunds all charges. |
| 332609 | Exterminator | Death Gripping a Maw Rat causes it to explode and resets the cooldown of Death Grip. |
| 332627 | Deadly Toll | The duration of Demon Soul granted from Fodder to the Flame is increased by ${$abs($m1/1000)} sec. |
| 332628 | Stalker Sling | The Hunt cooldown reduced by ${$m1/-1000}.1 sec. |
| 332691 | Fallen Comrade's Blindfold | Casting $?a212612 [Eye Beam][Fel Devastation] summons an allied $?a212612 [Vengeance][Havoc] Demon Hunter who casts $?a212612 [Fel Devastation][Eye Beam]. |
| 332739 | Darkreaver's Lens | Anti-Magic Shell and Anti-Magic Zone reflect harmful magical effects back at the caster. |
| 332762, 332764 | Void Etched Talisman | Using a Healthstone increases all healing taken by $s1% for $332764d. |
| 332773 | Ancient Drake Breath | Deals $s1 damage. |
| 332799, 332802 | Blood Beacon | Every ${$s2*$t1/$s1} sec in combat, you gain 1 Holy Power. |
| 332800, 332801 | Pendrake's Visor | Once every $332801d, Word of Glory applies Blessing of Spellwarding. |
| 332804 | Judged: Unworthy | The first time you Judge a target, it has a $s1% chance to be deemed Unworthy, permanently reducing its damage and health by $332804s1% |
| 332805 | Judged: Worthy | The first time you Judge a target, it has a $s1% chance to be deemed Unworthy, permanently reducing its damage and health by $332804s1% |
| 332807, 333107 | Coldheart Plume | During Avenging Wrath, prevent $s2% of damage from enemies. That damage will be dealt to you when Avenging Wrath ends, if the enemy that dealt it is alive. |
| 332808 | Pendrake's Shattered Aegis | Divine Shield protects everyone in your party. |
| 332829 | Anti-Magic Zone | Places an Anti-Magic Zone for $d that reflects all spell casts and reduces spell damage taken by party or raid members by $145629m1%. |
| 332831 | Anti-Magic Zone | Places an Anti-Magic Zone for $d, reducing the magic damage taken by party or raid members by $145629m1%. |
| 332861 | Darkreaver's Ward | Anti-Magic Shell and Anti-Magic Zone duration increased by ${$s1/1000} sec. |
| 332873, 332876 | Languishing Soul Detritus | When Scouring Tithe generates Soul Shards, gain $332876s1% increased movement speed and $332876s2% critical strike chance for $332876d. |
| 332880 | Satchel of Soul Dust | Decimating Bolt's bonus damage to $?s137046[Incinerate]?s198590[Drain Soul]?a137044&?!s137046[Demonbolt]?!a137044[Shadow Bolt][] is increased by $s1%. |
| 332887, 332896 | Smoking Ash Pile | Casting Decimating Bolt increases your critical strike chance by $s1% and your critical damage dealt by $s2% for $332896d. |
| 332897 | Depleted Soul Vessel | Decimating Bolt's bonus to $?s137046[Incinerate]?s198590[Drain Soul][Demonbolt] now applies to an additional $s1 casts. |
| 332907 | Withered Root Cluster | Reduce the cooldown of Soul Rot by ${$m1/-1000}.1 sec. |
| 332939, 332940 | Mark of Conk-quest | Hammer of Wrath makes your next Holy Power spending ability $s1% more effective. |
| 332944 | Rune of Razorice | Engrave your weapon with a rune that causes ${$max(($<coeff>*$AP),1)}% extra weapon damage as Frost damage and increases enemies' vulnerability to your Frost attacks by $51714s1%, stacking up to $51714u times. $?a332944[][

Modifying your rune requires a Runeforge in Ebon Hold.] |
| 332947, 332948 | Pendrake's Brooch | When a party member is damaged below $s1% health, you cast Blessing of Sacrifice on them. Cannot happen more than once every $332948d. |
| 333024 | Idol of Lost Souls | Soul Rot applies to $s1 additional target. |
| 333029, 333037 | Accursed Hand Wraps | Casting Soul Rot increases the damage of your Drain Life spell by $333037s1% for $333037d. |
| 333038 | Glass Eye of Perfection | Impending Catastrophe range increased by $s1 yds. |
| 333041 | Unbreakable Cuffs | Chains of Ice strikes $s1 additional $Ltarget:targets; and increases your Physical and Frost damage dealt to affected enemies by $s2%. |
| 333042 | Contained Perpetual Explosion | Impending Catastrophe's final explosion damage is increased by $s1% for each enemy target hit on the way to its destination. |
| 333067 | Rune Hunter | Ashen Phylacteries have a $s1% chance to contain a rune that affixes to your rune weapon, to a maximum of 8 additional runes. |
| 333093 | Unstable Containment Crystal | Impending Catastrophe now also summons $?a137043[Darkglare]?a137044[Demonic Tyrant][Infernal]. |
| 333105 | Fel Devastation | Unleash the fel within you, damaging enemies directly in front of you for ${$333110s1*(2/$t1)} Fire damage over $d. Causing damage also heals you for up to ${$333120s1*(2/$t1)} health. |
| 333110, 333120 | Fel Devastation | Unleash the fel within you, damaging enemies directly in front of you for ${$212105s1*(2/$t1)} Fire damage over $d.$?s320639[ Causing damage also heals you for up to ${$212106s1*(2/$t1)} health.][] |
| 333113 | Rune of Hysteria | Increases maximum Runic Power by ${$s2/10}.

Your attacks have a chance to increase Runic Power generation by $326918s2% for $326918d. |
| 333114 | Rune of Sanguination | Your Death Strike deals increased damage based on the target's missing health. When you fall below $s1% Health, you heal for ${$326808s1*$326808d}% of your maximum health over $326808d. 

Can only occur once every $326808s1 minutes. |
| 333115 | Rune of Spellwarding | Passive: Deflects $s2% of all spell damage.

Taking magic damage has a chance to grant you a shield that absorbs ${$MHP*$326867s2/100} magic damage for $326867d. When an enemy damages the shield, their cast speed is reduced by $326868s1% for $326868d. |
| 333121 | Of Dusk and Dawn | When you reach $s1 Holy Power, you gain $@spellname333122. When you reach $s2 Holy Power, you gain $@spellname333123.

$@spellicon333122 $@spellname333122
Damage increased by $s1% for $d.

$@spellicon333123 $@spellname333123
Damage taken reduced by $s1% for $d. |
| 333122 | Blessing of Dawn | Damage increased by $s1% for $d. |
| 333123 | Blessing of Dusk | Damage taken reduced by $s1% for $d. |
| 333124 | Blightstone | The damage of your Blood Plague, Frost Fever, and Virulent Plague are increased by $s1%. |
| 333261 | Diamondine Vesper | Reduce the cooldown of Vesper Totem by ${$m1/-1000}.1 sec. |
| 333262 | Vesperwind Bit | Vesper Totem will work on $s1 additional damage and $s2 additional healing events. |
| 333264 | Generosity of the Winged Seer | Vesper Totem's damage or healing is increased by $s1% for each charge of the Vesper Totem that is consumed. |
| 333327 | Corrupted Sapwood | Death's Due stacks $m1 additional $Ltime:times; for each target struck by $?c2[Obliterate]?c1[Heart Strike][Scourge Strike]. Also increases the maximum stacks by $s2. |
| 333334, 333337 | Fossilized Bone Fragments | Casting Primordial Wave increases the $?a137039[healing][damage] of your next $?a137039[Healing Wave]?a137040[Lava Burst][Lightning Bolt] by $s1%. |
| 333339, 333340 | Splintered Elemental Rod | Each additional $?a137039[Healing Wave]?a137040[Lava Burst][Lightning Bolt] generated by Primordial Wave increases your Haste by $s1% for $333340d. |
| 333344 | Hourglass of Soul Dust | Primordial Wave has $s1 additional charges. |
| 333348 | Crystalline Leaf | Fae Transfusion cooldown reduced by ${$m1/-1000}.1 sec. |
| 333349 | Bloody Thorn Stalk | Fae Transfusion channel duration and periodic damage frequency reduced by $s1%. |
| 333352 | Seeds of Rampant Growth | Casting Fae Transfusion resets the cooldown of $?a137039[Healing Tide Totem]?a137040&!s192249[Fire Elemental]?a137040&s192249[Storm Elemental][Feral Spirit]. |
| 333355 | Blood Stained Gauntlet | Critical Strike chance of Chain Harvest increased by $s1%. |
| 333357 | Elemental Conduit | Each friendly target healed by Chain Harvest automatically has Riptide applied to them. Each enemy target damaged by Chain Harvest automatically has Flame Shock applied to them. |
| 333366, 333371, 333375 | Crystallized Elemental Heart | Chain Harvest increases the damage of your next $333371u Chain Lightning spells by $333371s1%, and the healing of your next $333375u Chain Heal spells by $333375s1%. |
| 333388 | Toxic Accumulator | Enemies damaged by Death's Due take $s1% increased damage from Death's Due, stacking up to $324164u times. |
| 333389 | Eye Beam | Blasts all enemies in front of you, dealing guaranteed critical strikes for up to ${$s1*10*2} Chaos damage over $d. Deals reduced damage to secondary targets. |
| 333470 | Death Coil | Fires a blast of unholy energy at the target, causing $47632s1 Shadow damage to an enemy or healing an Undead ally for $47633s1 health.$?s316941[

Reduces the cooldown of Dark Transformation by $s2 sec.][] |
| 333471 | Undertaker's Crown | Lichborne causes you to radiate Death Coils onto your target, or yourself while you are injured. |
| 333480 | Fel Scorched Contract | Fodder to the Flame summons a demon that drops a Sigil of Flame every $333483t1 sec for $333483d. |
| 333496, 333497 | Fel Ignitor | When the Condemned Demon from Fodder to the Flame dies, a fiery explosion knocks back nearby enemies and applies Fiery Brand to them. |
| 333501 | Pouch of Soul-Ash | Killing an enemy reduces the remaining cooldown of Vanish by $s1 sec. |
| 333502 | Slippery Wraithcoil | The cooldown of $?s195457[Grappling Hook][Shadowstep] is reduced by ${$s1/-1000} sec and it generates $s2 combo $lpoint:points;. |
| 333503, 333504 | First Steps | Targets within $333504a1 yd of your $?s195457[Grappling Hook][Shadowstep] destination suffer an additional $333504s1% damage from your next finishing move. |
| 333505 | Rupturing Spike | $?s185438[Shadowstrike][Ambush] applies a $s1 combo point Rupture. |
| 333506, 333507 | Unceasing Chain Link | Finishing Moves increase the damage of your next combo point generator by $s1%. |
| 333508 | The Last Blade | $?s32645[Envenom]?s2098[Dispatch][Eviscerate] deals an additional $s1% damage. |
| 333509 | Scroll of Forewarning | Duration of Evasion, Feint, Cloak of Shadows, and Vanish increased by ${$m1/1000} sec. |
| 333510 | Surefoot Grease | You are immune to movement impairing effects, and your movement speed is increased by $s1%. |
| 333511 | Invigorating Shadowdust | Vanish reduces the remaining cooldown of your other abilities by $s1 sec. |
| 333512 | Restless Onyx Geodes | $?s195457[Grappling Hook][Shadowstep] causes you to gain $s1 sec of Cloak of Shadows, Evasion, Feint, or Crimson Vial. |
| 333513, 333514 | Generator I | Your single-target Combo Point generators deal an additional $s1% Nature damage to all nearby targets for each Combo Point you have. |
| 333561, 333608 | Nightmare Tendrils | Death's Due roots targets inside its radius for $333561d when cast, dealing $333561s2 damage every $333561t2 sec. |
| 333585 | Writhing Noose | Condemn's damage done and damage prevented are increased by $s1%. |
| 333598, 333599 | Pridebreaker's Anvil | Condemn knocks down the target for $333599d. |
| 333759, 333760 | Leather Apron | Targets deal $s1% reduced damage for 5 seconds after recovering from your crowd control abilities. |
| 333761 | Hunting Bola | The Hunt stuns all enemies within $333762A1 yards for $333762d. |
| 333763, 333764, 345373 | Vial of Unseen Poison | Your instant-damage finishing moves deal an additional $s1% as Nature damage when behind targets. |
| 333765, 333766, 333767, 348267 | Distracting Charges | Distract attaches explosive charges to targets that detonates after $333766d, dealing $333767s1 Fire damage and stunning for $333767d. |
| 333786 | Sinew-Sewn Tassels | Conqueror's Banner grants $s1% critical strike chance to you and your allies. |
| 333846, 333847 | Red Ink | Your Lethal Poison now also applies Red Ink poison, causing the target to take $333846s2% additional damage from your poisons and bleeds, and suffer ${$333846m1*$333846d/$333846t1} Nature damage over $333846d. |
| 333851 | Thistler | Ashen Phylacteries have a chance to drop Thistle Tea, which can be consumed to restore 100 Energy. |
| 333853 | Thistler | Rolling over Maw Rat corpses and broken Ashen Phylacteries reduces damage taken by $331828w1%. for $331828d, stacking up to $331828u times. |
| 333858, 333860, 350605 | Repulsive Pennant | While Conqueror's Banner is active, deal $333860s1 Shadow damage to all enemies within $333860A1 yds of you every $350605t1 sec. |
| 333891, 333892 | Hateful Fetish | Conqueror's Banner makes you immune to crowd control effects and grants you $333892s1% Leech. |
| 333893 | Fae Empowered Elixir | The cooldown of The Hunt is reset if the marked enemy is killed within $333883d of its application. |
| 333910 | Jack of All Trades | You gain Adrenaline Rush, Vendetta, and Shadow Blades when any are activated. |
| 333911 | Branding Iron | Increase the damage of Sinful Brand by $s1%. |
| 333917, 333926 | Shadowy Essence | You gain Cloak of Shadows the first  magical damage you take while under $s1% health each floor.

Additionally, nearby allies gain Cloak of Shadows when you do. |
| 333920 | Cloak of Shadows | Cloaked in shadows, causing you to resist harmful spells for $d. |
| 333927 | Overgrowth Catalyst | Ancient Aftershock's damage and Rage generation are increased by $s2%. |
| 333937 | Livingwood Pommel | Your auto attacks have a chance to cause an Ancient Aftershock. |
| 333949, 333953 | Petrified Wildseed | Whenever Ancient Aftershock generates Rage, it also reduces the remaining cooldown of a random ability by ${$s1/1000} sec. |
| 333996 | Incriminating Ledger | Sinful Brand applies to $s1 additional target. |
| 334005 | Perpetual Sinstone | $?a212612[Eye Beam][Fel Devastation] refreshes the duration of Sinful Brand. |
| 334336 | Trample | Damage all nearby fragile objects. |
| 334337 | Oversized Boots | Don the very large boots, automatically crushing any Ashen Phylacteries you step on. Trampling increases your movement speed by $334336s2% for $334336d. |
| 334393, 334400 | Draught of Waning Twilight | When you have $s1 periodic effects on a target, your damage and healing on them are increased by $334400s1%. |
| 334412 | Preserved Ironwood Seed | Rebirth has no cooldown. |
| 334459, 334460 | Silent Spirit | You deal $s1% increased damage for $334460d after exiting Prowl. |
| 334592, 352140 | Soulborne Clasp | When a target dies, your damage over time effects on them jump to another target within $s1 yards. |
| 334604 | Leaf on the Water | Clearcasting and Gore trigger $s1% more often, and Eclipse's cooldown is reduced by ${$s2/1000} sec. |
| 334730, 334731 | Pendrake's Locket | Damage taken from Blessing of Sacrifice is reduced by $s1%, and increases your $?c1[Intellect][Strength] for $334731d, based on the amount of damage. |
| 334992 | Thread of Beads | Your next $s3 Lay on Hands have no cooldown. |
| 335054, 335057 | Faintly Glowing Ember | Avenging Wrath and Forbearance abilities fill your Holy Power. |
| 335069 | Negative Energy Token | Judgment has a $h% chance to allow Hammer of Wrath to be cast on any target for $345693d. |
| 335103 | Divine Shield | Divine Shield protects everyone in your party. |
| 335424 | Soul-Touched Spurs | Divine Steed duration increased by ${$s1/1000} sec. |
| 335537, 335541, 335546 | Sling of the Unseen | Targets affected by your Resonating Arrow suffer an additional $335546s1 Arcane damage when struck by a critical strike. |
| 335557 | Pendulum of Impending Doom | Death Chakram bounces $s1 additional $Ltime:times;. |
| 335562 | Chakram Throwers | Death Chakram cooldown reduced by ${$m1/-1000}.1 sec. |
| 335566 | Bag of Munitions | Death Chakram now also applies Explosive Shot to every target it hits.

$@spellicon212431 $@spellname212431
Fires an explosive shot at your target that lasts for $d. Every $t1 sec, the shot will explode, dealing $s1 Fire damage to all enemies within $212680A1 yds. $?a1301406[Any remaining damage  |
| 335600 | Glowing Pollen Satchel | Wild Spirits cooldown reduced by ${$m1/-1000}.1 sec. |
| 335601 | Shard of Silvered Glass | Ravenous Frenzy's duration is increased by ${$s1/1000} sec. |
| 335608 | Majestic Antler Fragment | Targets affected by your Wild Mark take $s1% increased damage from you and your pets. |
| 335611, 335614 | Capsule of Pure Moonlight | Targets that die while affected by your Wild Spirits will cause an eruption at their location, dealing $335614s1 Nature damage to nearby enemies. |
| 335620 | Serrated Arrowhead | Flayer's Mark increases the damage of Kill Shot by an additional $s1%. |
| 335630 | Blood-soaked Bow String | Flayed Shot lasts an additional ${$m1/1000}.1 sec. |
| 335632 | Deathdealer's Scope | Flayed Shot grants you the Flayer's Mark effect when cast and when Flayed Shot is removed from the target. |
| 335644 | White Pollen Mote | Adaptive Swarm increases periodic effects by an additional $s1%. |
| 335645 | Perfectly Preserved Insect | Adaptive Swarm has a $s1% chance to split into two Swarms each time it jumps. |
| 335689 | Dried Flower Petal | When Adaptive Swarm arrives at a target, it applies Moonfire or Rejuvenation. |
| 335741 | Twin Friendship Ring | Kindred Spirits is empowered for an additional ${$s1/1000} sec. |
| 335747 | Hardened Bark Sliver | Activating Kindred Spirits applies Barkskin to you and Ironbark to your partner. |
| 335754, 335757 | Coil of Wire | While Kindred Spirits is empowered, the less injured partner will transfer up to $s1% health to the more injured partner every $326967t2 sec. |
| 335766 | Coalesced Spirit Droplet | The cooldown of Convoke the Spirits is reduced by ${$s1/-1000} sec. |
| 335771 | Energy Focusing Crystal | While channeling Convoke the Spirits, your damage and healing are increased by $s1%. |
| 336485 | Undead Bone Ash | Hammer of Wrath reduces Ashen Hallow's cooldown by $s1 sec. |
| 336489 | Hallowed Candle | Ashen Hallow deals $s1% increased damage or healing when there are $s2 or fewer targets. |
| 336492 | Dried Fire Flower | Blessing of Summer damage is increased by $s1%. |
| 336493 | Pristine Fallen Leaf | Blessing of Autumn's duration is increased by $s1%. |
| 336549 | Hallowed Silverglass | Casting Hammer of Wrath, Judgment, or Holy Shock within Ashen Hallow triggers its damage and healing. |
| 336612 | Worn Leather Strap | Cooldown of Vanquisher's Hammer reduced by ${$s1/-1000} sec. |
| 336615, 336619 | Darkened Ember | Vanquisher's Hammer generates $336619s1 Holy Power. |
| 336625 | Tome of the Vanquished | Vanquisher's Hammer triggers an additional Divine Storm. |
| 336643 | Calibrated Sextant | Blessing of the Seasons additionally grants $s1 secondary stat.

Summer: Critical Strike
Autumn: Haste
Winter: Versatility
Spring: Mastery |
| 336750 | Silent Elysian Bell | Echoing Reprimand is free and now restores $s1 Energy and $s2 additional Combo Points. |
| 337585, 337590, 357524 | The Stone Ward | Shields you for $s1% of your maximum health. This absorb refreshes every $t1 sec. |
| 337614 | Erratic Howl | While in combat, release an uncontrolled howl at random intervals. This howl inflicts $337614s1 Shadow damage to enemies within $337614A1 yds and interrupts spells. |
| 337620, 337622 | Unstable Form | While in combat, become incorporeal at random intervals, reducing damage taken by $337622s1% for $337622d. |
| 337657, 352065 | The Fifth Skull | While in combat, if there are $s1 or more enemies within $337658A1 yds, the skull releases a storm of bones, inflicting $337659s1 Shadow damage every $t1 sec to ALL nearby players and enemies. |
| 337659 | Bonestorm! | While in combat, if there are $s1 or more enemies within $337658A1 yds, the skull releases a storm of bones, inflicting $337659s1 Shadow damage every $t1 sec to ALL nearby players and enemies. |
| 337719, 337721 | Heart-Seeking Fang | While in combat, leech $337721s1 health from a random enemy within $337720A1 yds every $t1 sec. This damage and healing is tripled if the target is suffering from a Bleed effect. |
| 337728 | Kerim's Amulet of Laceration | While in combat, cause all enemies within $337729A1 yds to bleed uncontrollably, suffering $337729s1 Shadow damage every $t1 sec. |
| 337729 | Kerim's Laceration | While in combat, cause all enemies within $337729A1 yds to bleed uncontrollably, suffering $337729s1 Shadow damage every $t1 sec. |
| 337765 | Reinforced Lure Casing | Removes the damage done penalty from any Fractured Phantasma Lures carried. |
| 337878, 337879 | Dark Fortress | While in combat, every $t1 sec gain $337879s1% reduced damage taken for $337879d. This effect stacks up to $337879U times. |
| 337880 | Fallen Armaments | Increases the caster's haste by $s1% for $d. This effect stacks. |
| 337927, 337928 | Potent Acid Gland | Your attacks have a chance to launch a glob of acid, inflicting $337927s1 Nature damage and allowing you to ignore $337927s2% of the target's armor for $337927d. |
| 337938 | Lumbering Form | While in combat, your size is increased by $337940s1% and you automatically knock back ALL players and enemies that come within $337942A1 yds of yourself. |
| 338023, 338027 | Irritating Moth Dust | Your attacks have a chance to create a cloud of irritant near your target for $338024d. Enemies caught within have their damage done reduced by $338027s1%. |
| 338029 | Shimmering Wingcape | Reduces the range at which enemies can detect you by $s1 yds. |
| 338062, 338065, 338066, 347982, 347983 | Stoneflesh Figurine | When below $s1% maximum health, you reduce all damage taken by $338065s1% and your own movement speed by $338065s2%. |
| 338072, 338076 | Gruul's Shattered Toenail | Every $t1 sec you are stunned or snared, earthen fragments shatter off of yourself and inflict $338076s1 Nature damage to enemies within $338076A1 yds. |
| 338446 | Coffer of Spectral Whispers | You become immune to Silence and Interrupt effects. |
| 338449 | Elongated Skeletal Arms | Increases the range of your Auto Attack and Auto Shot by $s1 yds. Auto Attack and Auto Shot damage increased by $s2%. |
| 338512, 338524 | Gaze of Death | Every $t1 sec the Gaze of Death focuses on a random enemy within $338515A1 yds for $338524d. This effect causes the target to take increased damage randomly between $338524m1% and $338524M1%. |
| 338616, 338620 | Pulsing Rot-hive | Your attacks have a chance to attach decayfly larvae in the target, inflicting $338620s1 Nature damage every $338620t1 sec for $338620d. When this effect expires, the larvae hatch from within the target to fight for you. |
| 338631 | Swarm Form | Your body becomes more like a swarm of insects, increasing enemy chance to miss you by $s1%. |
| 338705 | Overgrowth Seedling | Increases your armor by $s1%. |
| 338922 | Soulward Clasp | Your attacks have a chance to create a zone of soul empowerment nearby. Any player may collect this to gain $338928s1% damage and healing done and $338928s2% movement speed for $338928d. |
| 338928, 353745 | Soul Empowerment | Your attacks have a chance to create a zone of soul empowerment nearby. Any player may collect this to gain $338928s1% damage and healing done and $338928s2% movement speed for $338928d. |
| 338948, 338949 | V'lara's Cape of Subterfuge | Your attacks have a chance to cause you to fade away, reducing your threat for $338949d. While you are under this effect, your critical strike chance is increased by $338949s2%. |
| 339024 | Ephemeral Effigy | You take $s1% less Physical damage and suffer $s2% more Magic damage. |
| 339026 | Resonating Effigy | You take $s1% less Magic damage and suffer $s2% more Physical damage. |
| 339111 | Suffused Noble Writ | Magic, Curse, Disease, and Poison effects on you have their durations reduced by $s1%. |
| 340180 | Vial of Unbridled Darkness | \|cFFffffffUnbridled Darkness\|r

Release the darkness for $340182d, causing you to be completely unable to view your surroundings. While under this effect, your damage and healing done is increased by $340182s2% and your movement speed is increased by $340182s3%. 

90 sec cooldown. |
| 340182 | Vial of Unbridled Darkness | Release the darkness for $340182d, causing you to be completely unable to view your surroundings. While under this effect, your damage and healing done is increased by $340182s2% and your movement speed in increased by $340182s3%. |
| 340435 | Flask of Unbridled Darkness | \|cFFffffffUnbridled Darkness\|r

Release the darkness for $340438d, causing you to be completely unable to view your surroundings. While under this effect, your damage and healing done is increased by $340438s2% and your movement speed is increased by $340438s3%. 

60 sec cooldown. |
| 340438 | Flask of Unbridled Darkness | Release the darkness for $340438d, causing you to be completely unable to view your surroundings. While under this effect, your damage and healing done is increased by $340438s2% and your movement speed in increased by $340438s3%. |
| 340445 | Censer of Suffocating Shadows | \|cFFffffffUnbridled Darkness\|r

While under the effects of Unbridled Darkness, release a wave of magic every $340585t1 sec, inflicting $340571s1 Shadow damage to enemies within $340571A1 yds. |
| 340448 | Tollar's Dancing Garments | \|cFFffffffUnbridled Darkness\|r

While under the effects of Unbridled Darkness, you have $340597s1% increased dodge chance. |
| 340451 | Form of Darkness | \|cFFffffffUnbridled Darkness\|r

While under the effects of Unbridled Darkness, killing an enemy unit extends its duration by $s1 sec. Unbridled Darkness is automatically removed from you while out of combat. |
| 340571 | Suffocating Shadows | \|cFFffffffUnbridled Darkness\|r

While under the effects of Unbridled Darkness, release a wave of magic every $340585t1 sec, inflicting $340571s1 Shadow damage to enemies within $340571A1 yds. |
| 340597 | Dancing in the Shadows | \|cFFffffffUnbridled Darkness\|r

While under the effects of Unbridled Darkness, you have $340597s1% increased dodge chance. |
| 340643, 340653 | Wild Flail of Tollar | \|cFFffffffUnbridled Darkness\|r

While under the effects of Unbridled Darkness, you lash out at the nearest enemy OR player within $340651A1 yds every $340644t1 sec, inflicting $340653s1 Shadow damage. |
| 340672, 340673 | Globule of Cloying Darkness | \|cFFffffffUnbridled Darkness\|r

While under the effects of Unbridled Darkness, you have $340673s1% increased mastery and $340673s2% increased critical strike chance. |
| 340676, 340677 | Tollar's Hidden Flask of Fortification | \|cFFffffffUnbridled Darkness\|r

While under the effects of Unbridled Darkness, your maximum health is increased by $340677s1%. |
| 340725 | Engorged Limb | Each Rune spent extends Abomination Limb's duration by $s1 sec. |
| 340728 | Fatal Grasp | Abomination Limb casts Soul Reaper on any enemy it pulls. |
| 340735 | Abomination Limb | Sprout an additional limb for $d. Every $t1 sec, it deals $323798s1 Shadow damage to all nearby enemies and pulls an enemy to your location if they are further than $323710s3 yds from you. |
| 340742, 340744 | Sands of Desperation | \|cFFffffffUnbridled Darkness\|r

While under the effects of Unbridled Darkness, your time flows $340744s1% faster. |
| 340745, 340747 | Oddly Intangible Key | \|cFFffffffUnbridled Darkness\|r

While under the effects of Unbridled Darkness, you take $340747s1% less damage from area of effect attacks. |
| 340755 | Prosthetic Grabber | Grows an extra Abomination Limb, and allows your Abomination Limb to grab enemies from up to ${$323710a1+$s2} yards away. |
| 340774 | Tollar's Willful Blinder | \|cFFffffffUnbridled Darkness\|r

The duration of your Unbridled Darkness is increased by $s1 sec. |
| 340801 | Huddled Carvings | \|cFFffffffUnbridled Darkness\|r

Your damage done is increased by $340823s1% if you and an ally within $340830A2 yds are both under the effects of Unbridled Darkness. |
| 340823 | Huddled in the Darkness | \|cFFffffffUnbridled Darkness\|r

Your damage done is increased by $340823s1% if you and an ally within $340830A2 yds are both under the effects of Unbridled Darkness. |
| 340850, 340861 | Harvester of Shadows | \|cFFffffffUnbridled Darkness\|r

If you and an ally within $340856A2 yds are both under the effects of Unbridled Darkness, you heal for $340861s1% of your maximum health every $340855t1 sec. |
| 340928, 340969 | Formless Executioner | Swarming Mist increases Dodge by an additional $s1%, and each time you dodge an attack, Swarming Mists damage is increased by $s2%. Stacks 5 times. |
| 341095 | Swarm Host | Death Grip activates Swarming Mist for $s1 sec. If Swarming Mist is already active, its duration is increased instead. |
| 341098, 341100 | Death's Deliverance | During Swarming Mist, Door of Shadows has no cooldown and now causes you to explode upon reaching your destination, dealing $341100s1 Shadow damage. |
| 341137, 341138, 341140 | Writhing Shadow-Tendrils | \|cFFffffffUnbridled Darkness\|r

While under the effects of Unbridled Darkness, your attacks have a chance to cause a dark explosion and inflict $341140s1 Shadow damage as well as blind enemies within $341140A1 yds of your target for $341140d. |
| 341324 | Uncontrolled Darkness | \|cFFffffffUnbridled Darkness\|r

Darkness envelops you every $s1 kills, causing you to be completely unable to view your surroundings. While under this effect, your damage and healing done is increased by $341375s2% and your movement speed is increased by $341375s3%. This effect is only removed whe |
| 341370 | Darkness Rising | \|cFFffffffUnbridled Darkness\|r

Darkness envelops you every $s1 kills, causing you to be completely unable to view your surroundings. While under this effect, your damage and healing done is increased by $341375s2% and your movement speed is increased by $341375s3%. This effect is only removed whe |
| 341373 | Darkness Fading | \|cFFffffffUnbridled Darkness\|r

Darkness envelops you every $s1 kills, causing you to be completely unable to view your surroundings. While under this effect, your damage and healing done is increased by $341375s2% and your movement speed is increased by $341375s3%. This effect is only removed whe |
| 341375 | Uncontrolled Darkness | Darkness envelops you every $341324s1 kills, causing you to be completely unable to view your surroundings. While under this effect, your damage and healing done is increased by $s2% and your movement speed in increased by $s3%. This effect is only removed when you kill $341324s2 more enemies. |
| 341576 | Howling Soulcore | \|cFFffffffChorus of Dead Souls\|r

Assume the form of a Deadsoul Chorus, replacing your abilities with Maw based spells. While in this form, you have $341602s1% increased damage and healing as well as $341602s2% increased movement speed. 

Friendly players may merge with your form to add to the c |
| 341580 | Wailing Blast | Launches a blast of negative energy at an enemy, inflicting $s1 Shadow damage and interrupting spellcasting, preventing any spell in that school from being cast for $d. |
| 341596 | Scream of Pain | Release a wild scream, inflicting $s1 Shadow damage to enemies within $A1 yds. |
| 341602 | Chorus of Dead Souls | \|cFFffffffChorus of Dead Souls\|r

Assume the form of a Deadsoul Chorus, replacing your abilities with Maw based spells. While in this form, you have $341602s1% increased damage and healing as well as $341602s2% increased movement speed. 

Friendly players may merge with your form to add to the c |
| 341614 | Return to Existence | Release the wailing souls, returning to your original physical form. |
| 341622 | Phase Shift | Shifts out of reality, reducing all damage taken by $s1% for $d. This can be cast while casting. |
| 341629 | Twisting Shadows | Leap through the shadows, teleporting to a targeted location. |
| 341658, 341700 | One Piece of Many | \|cFFffffffChorus of Dead Souls\|r

While part of a Deadsoul Chorus, your damage and healing done is increased by $341700s1%. |
| 341710 | Echoing Amplifier | \|cFFffffffChorus of Dead Souls\|r

The cooldown of Wailing Blast is reduced by ${$s1/-1000} sec. |
| 341721 | Screaming Statuettes | \|cFFffffffChorus of Dead Souls\|r

The radius of Scream of Pain is increased by $s1 yds. |
| 341737, 341738 | Aural Fracture | \|cFFffffffChorus of Dead Souls\|r

Wailing Blast ruptures the target's ears, inflicting an additional $341738s1 Shadow damage every $341738t1 sec for $341738d. |
| 341745 | Improbably Shifting Orb | \|cFFffffffChorus of Dead Souls\|r

Increases the maximum number of charges of Phase Shift by $s1. |
| 341753, 341754 | Dangling Soulcatcher | \|cFFffffffChorus of Dead Souls\|r

Any time you assume the form of a Deadsoul Chorus or return to corporeal form, you are healed for $341754s1. This effect can only occur every $341756d. |
| 341762, 341763 | Shifting Sustenance | \|cFFffffffChorus of Dead Souls\|r

Phase Shift heals all nearby friendly targets within $341763A1 yds for $341763s1. |
| 341780, 341783 | Incorporeal Weave | \|cFFffffffChorus of Dead Souls\|r

Phase Shift additionally increases your movement speed by $341783s1% for $341783d. |
| 341798, 341799 | Brand of Instability | \|cFFffffffChorus of Dead Souls\|r

While assuming the form of a Deadsoul Chorus, your movement speed is increased by $341799s1%. |
| 341805 | Twisted Idol | \|cFFffffffChorus of Dead Souls\|r

Increases the maximum number of charges of Twisting Shadows by $s2 and reduces its cooldown by ${$s1/-1000} sec. |
| 341813, 341814 | Contorted Hourglass | \|cFFffffffChorus of Dead Souls\|r

While part of a Deadsoul Chorus, time passes $341814s1% faster for you. |
| 341817, 341818 | Aegis of Lost Souls | \|cFFffffffChorus of Dead Souls\|r

While part of a Deadsoul Chorus, all damage taken is reduced by $341818s1%. |
| 341951, 341953 | Essence Siphoner | \|cFFffffffChorus of Dead Souls\|r

While part of a Deadsoul Chorus, increases Phantasma earned by $341953s1%. |
| 341954, 341955 | The Spectral Hands of Arcadne | \|cFFffffffChorus of Dead Souls\|r

While part of a Deadsoul Chorus, your Auto Attack and Auto Shot damage is increased by $341955s2% and your Auto Attack and Auto Shot range is increased by $341955s1 yds. |
| 341973, 341976 | Soulburst Charm | \|cFFffffffChorus of Dead Souls\|r

Any time you return to corporeal form from existing within a Deadsoul Chorus, you inflict $341976s1 Shadow damage and blind enemies within $341976A1 yds for $341976d. This effect can only occur every $341978d. |
| 342008, 342024 | Arcadne's Feasting Mark | \|cFFffffffChorus of Dead Souls\|r

Any time a Deadsoul Chorus that you are a part of casts $@spellname341622, you are healed for $342024s1 Health every $342024t1 sec for $342024d. |
| 342023, 342025 | Arcadne's Ritual Mask | \|cFFffffffChorus of Dead Souls\|r

Any time a Deadsoul Chorus that you are a part of casts $@spellname341629, you gain $342025s1% critical strike chance for $342025d. |
| 342359 | Power Overwhelming | Deathborne grants an additional $s1% spell damage. |
| 342360 | One With Death | Reduces the cooldown of Deathborne by ${$s1*-1}%. |
| 342370 | Infinite Power | Increases Shifting Power damage by $s1%. |
| 342371 | Fae Concentration | Shifting Power can be cast while moving and you gain $314791s3% movement speed for the duration. |
| 342372, 342373 | Fae Tendrils | Shifting Power entangles enemies it hits, rooting them in place for $342373d. |
| 342374 | Lingering Torments | Increases Mirrors of Torment damage by $s1%. |
| 342375 | Tormenting Backlash | Conjure $n mirrors to torment the enemy for $d. Whenever the target attacks, casts a spell, or uses an ability, a mirror is consumed to inflict $320035s1 Shadow damage and their movement and cast speed are slowed by $320035s3%. This effect cannot be triggered more often than once per $345977d.

Th |
| 342376 | Maliced Rumination | Mirrors of Torment's final mirror will now damage, root, and silence all nearby enemies. |
| 342377 | Malevolence | Mirrors of Torment can be cast instantly and if an enemy dies while afflicted its cooldown is reset. |
| 342382, 342384 | Necromight Infusion | Allies that are healed by Unholy Transfusion gain $s1% critical strike chance for $342384d, stacking up to $342384u times. |
| 342387 | Baroness' Lost Plagueloop | Mind Blast, Holy Fire, and Shadow Word: Death extend the duration of Unholy Transfusion by $s1 sec. |
| 342390 | Maldo's Soul Exploder | Enemies that die within $a1 yds have a $s1% chance to trigger an Unholy Nova at its location. |
| 342397, 342398 | Pixie Dust | When your Fae Guardians follow your spell casts, you or your ally are healed for $342398s1 every $342398t1 sec for $342398d. |
| 342399 | Fae-bliss Lantern | Gain an additional Fae Guardian that increases damage and healing by $s1%. Follows your Power Infusion. |
| 342402 | Divine Faerie | Gain an additional Fae Guardian that increases damage and healing by $s1%. Follows your Power Infusion. |
| 342409 | Dreamspun Mushrooms | Your Fae Guardians last $s1% longer. |
| 342411 | Mindmancer Handgloves | Mindgames deals $s3% increased damage and reverses $s1% more damage and healing. |
| 342412 | Earworm | Mindgames has a $s1% chance to infect an enemy when they strike you. |
| 342413, 342414 | Cracked Mindscreecher | Mindgames debilitates enemies when it ends, interrupting and silencing them for $342414d. While silenced, the target takes $342414s3% more damage. |
| 342444 | Bulging Brew | Bonedust Brew's radius increased by $s1%. |
| 342445, 342446 | Corrosive Carbonation | Bonedust Brew deals $342445s1 damage every $342445t sec to enemies disabled by crowd control. |
| 342453 | Unfiltered Bone Broth | Bonedust Brew's chance is reduced to ${$325216h+$s1}%, but now provides $s2% additional Shadow damage and healing. |
| 342458, 342459, 348631 | Fae Aftershock | Faeline Stomp deals its damage along your Faelines every $s2 sec for $s1 sec after opening. |
| 342540, 342541 | Neural Pet Enhancer | While your pet is under the effects of Eyes of the Beast, its damage dealt is increased by $s1%. |
| 342546, 342547 | Mawrat Scent Gland | When your pet is within $s1 yds of a mawrat, your pet will immediately kill the mawrat and increase your pet's damage by $342547s1% for $342547d. |
| 342549, 342556 | Stuffed on Mawrats | When your pet is within $s1 yds of a mawrat, your pet will immediately kill the mawrat and increase your pet's damage by $342547s1% for $342547d. |
| 342632, 342662 | Malevolent Stitching | Fleshcraft increases your $pri by $s1% while the shield holds. |
| 342664 | Musophobic Femur | Fleshcraft treats Mawrats as powerful enemies. |
| 342710, 342717 | Volatile Flesh | Fleshcraft only lasts $s2 sec, but when it is consumed or expires it explodes for $s3% of the shield's initial value as Shadow damage to all nearby enemies. |
| 342757, 342758 | Clinging Fog | During Soulshape, Flicker reduces the movement speed of enemies near your departure location by $s1% for $342758d. |
| 342799, 342801 | Gnarled Key | Casting Door of Shadows reduces the cast time of Door of Shadows by $342801s1%, and its cooldown by ${$342801s2/-1000} sec. Stacks up to $342801u times. |
| 342818, 342819 | Mask of Withering | Door of Shadows weakens all enemies you pass through, increasing their damage taken by $342819s1% for $342819d. |
| 343203 | Ringing Doom | Echoing Reprimand's cooldown is reset when your Animacharged combo point is consumed. |
| 343209 | Reverberating Strike | Damaging finishing moves that consume your Animacharged combo point function as if you consumed $s1 combo points. |
| 343217 | Serrated Bone Spike | Serrated Bone Spike's bleed damage is increased by $s1%, and damages a nearby enemy. |
| 343220 | Fractured Bone Shards | Serrated Bone Spike's bleed damage is increased by $s1%, and damages a nearby enemy. |
| 343221 | Hollow Bones | Serrated Bone Spike's range is increased by $s2 yards, and damage increased by up to $s1% at maximum range. |
| 343231 | Spring-loaded Bone Pouch | Serrated Bone Spike gains $s2 charges and refunds ${$s2+3} charges when an enemy dies with an active bone spike. |
| 343237 | Boiling Poison Sores | Sepsis deals $s1% of the target's maximum health in Poison damage to up to $s2 nearby targets. |
| 343239 | Explosive Inflamation | Sepsis deals $s1% of the target's maximum health in Poison damage to up to $s2 nearby targets. |
| 343245 | Backup Poison Injectors | Sepsis spreads to up to $s1 nearby targets, with each jump increasing the duration by an additional $s2 sec. |
| 343251 | Poisoned Rush | Sepsis resets the cooldown of $?s79140[Vendetta]?s13750[Adrenaline Rush][Shadow Blades] if the target survives the poison. |
| 343255, 343256 | Slaughter Sling | $?s195457[Grappling Hook][Shadowstep] increases the damage of Slaughter by $s1% and allows its use without Stealth for 3 sec. |
| 343377 | Spiked Lashes | Flagellation now grants you $s2% Haste per stack, up to a maximum of $s3% Haste. |
| 343379 | Prolonged Pain | Increases the duration of Flagellation's Haste increase by $s1%. |
| 343380 | Thirsty Venom Vial | Increases the duration of Flagellation's Haste increase by $s1%. |
| 343382, 343383 | Shadowlaced Armaments | Combo Point generating abilities now also deal an additional $s1% damage to nearby targets for each Combo Point you currently have. |
| 343389, 343390, 343391 | Silent Footpads | Entering Stealth heals you for $s1% of your maximum health.  Leaving Stealth increases your damage by $s2% for $343391d. |
| 343392, 343439 | Shimmering Cloaktrails | Dodging attacks extends the duration of Evasion by $s1 sec, up to an additional $s2 sec. |
| 343442, 343444 | Draped Prism Shawl | Tricks of the Trade grants you and the target $s1% dodge for $s2 sec. |
| 343446 | Quicksilver Mixture | Crimson Vial grants Evasion, Cloak of Shadows, or Feint for $s1 sec. |
| 343450, 343779 | Terror-laden Slumbersand | Your Blinded and Sapped targets suffer $s1% of the damage you deal to other targets without being broken out of Sap or Blind. |
| 343454 | Celestial Weapon-Chains | Your spells and abilities have a chance to activate Weapons of Order for $s1 sec. |
| 343456 | Bladed Knuckle-Punchers | Each target struck by your Tiger Palm while Weapons of Order is active increases its Mastery bonus by $s1%. |
| 343458 | Fae Footwraps | Faeline Stomp no longer branches, but extends up to $s1 yards away if possible. |
| 343461, 343825 | Scales of Order | Weapons of Order also increases your critical strike chance, haste, versatility, Agility, Intellect, movement speed, maximum health, and size by $?c1[${$117906bc1*$310454s1}]?c2[${$117907bc1*$310454s1}][${$115636bc1*$310454s1}]%. |
| 343468 | Staggered Stomps | Faeline Stomp has $s1 additional maximum charges, and now gains a charge when its cooldown is reset. |
| 343474 | Tiny Toxic Blade | Shiv causes your Poisons and Bleeds on the target to spread to a nearby enemy. |
| 343788, 343789, 348722 | Ever-Tumbling Stone | For $343789d after you activate this power, and whenever you change floors in Torghast, $?s115008[Chi Torpedo][Roll] grants immunity to all damage for $s2 sec per yd traveled. |
| 343790, 343791 | Cloud of Feathers | Spinning Crane Kick also reduces damage you and your allies in its radius take by $s1%. |
| 343793, 343794 | Bottled Wind | $?s115008[Chi Torpedo][Roll] grants you an absorb shield equal to $s1% of your maximum health. |
| 343795, 343796 | Wrist Wraps of the Zen Master | Targets affected by your Mystic Touch explode when killed, dealing $s1% of their maximum health as damage to any enemy within $343796A1 yds. |
| 343822, 343823, 343824 | Celestial Lasso | Spinning Crane Kick now also pulls a random enemy within $343823A1 yds to your current location. |
| 344580 | Deep Reflection | Fallen Order summons $m1 additional $?$C1[Ox]?$C2[Crane][Tiger] $ladept:adepts; for $326860d. |
| 344581, 344582, 344583 | Fading Memory Shards | Fallen Order adepts detonate instead of fading back into the shadows, dealing $344582s1 Shadow damage to enemies within $344582a1 yds. |
| 344588 | Tattered Teachings | Fallen Order adepts protect the Monk $s1% longer before expiring, and are now summoned at the Monk's location. |
| 344590, 348708 | Dowsing Rod | Standing in your Faeline reduces damage you and your allies take by $s1%, but Faeline length is reduced. |
| 345632 | Remorse | Flagellation causes the tormented target to be lashed $s1 additional $ltime:times; every $s2 sec. |
| 345693 | Negative Energy Token | Hammer of Wrath makes your next Holy Power spending ability $s1% more effective. |
| 345871 | Half-Giant Empowerment | Metamorphosis increases your size, movement speed, and melee range by $326486s1%. |
| 347646 | Deathseer's Whip | Dropping a totem grants your party ${$m1/1000}.1 sec of $?s32182[Heroism][Bloodlust] |
| 347934 | Overgrowth Seedling | Increases your armor by $s1% and reduces the power cost of most abilities by $s2%. |
| 347943 | Obleron Endurance | Maximum health increased by $s1%. |
| 347944 | Obleron Spikes | Critical strike chance increased by $s1%. |
| 347945 | Obleron Winds | Haste increased by $s1%. |
| 347946 | Obleron Talisman | Mastery increased by $s1%. |
| 347947 | Obleron Ephemera | Versatility increased by $s1%. |
| 347948 | Obleron Venom | Critical damage and healing increased by ${$s1*2}%. |
| 347960 | Resonating Effigy | You take $s1% less Magic damage. Taking Magic damage has a chance to increase your movement speed and damage done by $353784s1% for $353784d. |
| 347962 | The Stone Ward | Shields you for $s1% of your maximum health. This absorb refreshes every $t1 sec. While this shield holds, you are immune to stuns and being knocked back. |
| 347966, 355663 | Ever-Beating Heart | You become immune to Fear and Stun effects. |
| 347967 | Oddly Intangible Key | You take $s1% less damage from area of effect attacks. |
| 347972 | Huddled Carvings | Your damage and healing done is increased by $347974s1% while within $347973A1 yds of at least $s1 other players. |
| 347978 | Spectral Oats | While running, you take $s2% less damage and inflict $s3% more damage, as well as heal for $s1% of your maximum health every $t1 sec. |
| 347980 | Unstable Form | While in combat, become incorporeal at random intervals, reducing damage taken by $337622s1% for $337622d. This instability removes a stack of a random debuff on you when it occurs. |
| 347985 | V'lara's Cape of Subterfuge | Your attacks have a chance to cause you to fade away, reducing your threat for $347986d. While you are under this effect, your critical strike chance is increased by $347986s2%. |
| 347988 | Ten of Towers | Increases all primary, secondary, and tertiary stats by $s1%. Upon death, detonate and stun ALL players and enemies within $347990A1 yds for $347990d. |
| 348025, 348026 | Potent Acid Gland | Your attacks have a chance to launch a glob of acid, inflicting $348026s1 Nature damage and increasing damage you inflict on that target by $348026s2% for $348026d. |
| 348027 | Erratic Howler | While in combat, release an uncontrolled howl at random intervals. This howl inflicts $348029s1 Shadow damage to enemies within $348029A1 yds and interrupts spells. |
| 348040, 361254 | Negation Well | Greatly increase the power of your jumps. While jumping in the air, area of effect attacks are beneath you and you take $361254s1% less damage from them.

Your movement speed is increased by $s3%. |
| 348041 | Satchel of the Hunt | You grant all allies within $s1 yds an additional $348042s1% movement speed. |
| 348043 | Lumbering Form | While in combat, your size is increased by $348044s1%, your damage and healing is increased by $348044s2%, and you automatically knock back ALL players that come within $348045A1 yds of yourself. |
| 348048 | Heart-Seeking Fang | While in combat, leech $348050s1 health from a random enemy within $348049A1 yds every $t1 sec. This damage and healing is doubled if the target is suffering from a Bleed effect. |
| 348059 | Twisted Samophlange | While in combat, the $s1 nearest other players to you within $348060A1 yds gain $348060s1% increased damage and healing done. |
| 348063 | Disembodied Mystic Hands | Your attacks have a high chance to steal a beneficial Magic or Enrage effect from your target, applying it to yourself. |
| 348482 | Notched Axe Head | Gain the Victorious effect every $t1 sec, allowing the use of $?s202168[Impending Victory][Victory Rush]. |
| 348483, 348484, 348485 | Tarnished Medallion | Berserker Rage restores $348484s1% health instantly, and every $348484t1 sec. |
| 348511, 348512 | Bloodgorged Leech | Your damaging spells and abilities have a very high chance to heal you$?a137014\|a137042[ and your summoned][]$?a137014[ pet]?a137042[ demon][] for $s1% of your maximum health. |
| 348541, 348542, 348543 | Refilling Elixir of Life | When you fall below $s1% health, immediately heal to full health. This can only occur once per floor. |
| 348761 | Death Turf | $?s315442[Death's Due]?s152280[Defile][Death and Decay] gains $s3 additional $Lcharge:charges; and its radius is increased by $s1 yds. |
| 348904 | Desolate Chitin | Fleshcraft absorbs $s1% more damage. |
| 348908, 348909 | Ethereal Wildseed | During Soulshape, Flicker heals you for $s1% of your maximum health. |
| 348910, 348911 | Frigid Wildseed | Activating Soulshape creates swirls of anima at your initial and destination locations, stunning enemies within $348911A1 yds for $348911d. |
| 350117 | Soul of an Archon | Power Infusion increases periodic damage and healing by $s1%. |
| 350119 | Soul of an Archon | Infuses the target with power for $d, increasing periodic damage and healing by $s1%. |
| 350267 | Incanter's Ward | When your barrier is consumed, gain up to $s1% Intellect, based on the amount absorbed. |
| 350269 | Incanter's Ward | Magical energy flows through you while in combat, building up to ${$116267m1*5}% increased damage and then diminishing down to $116267s1% increased damage, cycling every 10 sec. |
| 350350 | Deadeye Satchel | Every $t1 sec, your next Kill Shot will instantly kill a target below $s2% health. |
| 350577 | Bone Borrower | Death Coil afflicts enemies with Bone Harvest, dealing $s1% of Death Coil's damage over $332320d. Targets killed during Bone Harvest are reanimated as a Risen Skulker or a Magus of the Dead for $332337d. |
| 353743 | Soulward Clasp | Your abilities have a chance to create a zone of soul empowerment nearby. Any player may collect this to gain $353745s1% damage and healing done and $353745s2% movement speed for $353745d. |
| 353747, 353748 | Pulsing Rot-hive | Your attacks have a chance to attach decayfly larvae in the target, inflicting $353748s1 Nature damage every $353748t1 sec for $353748d. When this effect expires, the larvae hatch from within the target to fight for you. |
| 354569 | Potent Potion | Rejuvenating Siphoned Essence potions grant their effect twice, and grant an absorb shield for $354705d. |
| 354675, 354698 | Empowered Hops | When Empowered, jumping has a high chance to deal $<points>  Arcane damage to a random enemy within $357263A1 yds. |
| 354705 | Essence Shield | Rejuvenating Siphoned Essence potions grant their effect twice, and grant an absorb shield for $354705d. |
| 354707, 354722 | Empowered Bravery | You are immune to Fear when Empowered. |
| 354708, 354725 | Empowered Regeneration | When Empowered, heal $354725s1%
health every $354725t1 sec. |
| 354709, 354727 | Empowered Phantasma | When Empowered, increase the amount of Phantasma dropped from enemies by $354727s1%. |
| 354746 | Orb of Self Replenishment | When you attack a Boss for the first time, spawn $s1 nearby $Lorb:orbs; that will heal you for $s2% of your maximum health when collected. |
| 354757 | Empowered | The party becomes Empowered for up to $<duration> sec, increasing Haste by $<haste>%, Leech by $354757s5%, and movement speed by $<speed>%.

While Empowered, all actions grant $354757s8% bonus points. |
| 355602 | Potent Acid Gland | Your attacks have a chance to launch a glob of acid, inflicting $355603s1 Nature damage and increasing damage you inflict on that target by $355603s2% for $355603d. |
| 355665 | Immovable Iron Stompers | You become immune to Knockback and Forced Movement effects. |
| 355667 | Unfaltering Sandals | You become immune to Root and Snare effects. |
| 355696 | Fallen Armaments | While in combat, every $t1 sec gain $355695s1% Haste for $355695d. This effect stacks up to $355695U times. |
| 355698, 355699 | Lens of Elchaver | When you critically strike with a direct attack, an Arcane bolt will also strike your target, dealing $355699s1 Arcane damage. |
| 356250 | Elemental Conduit | Up to $s1 friendly targets healed by Chain Harvest will have Riptide cast on them. Up to $s2 enemy targets damaged by Chain Harvest will have Flame Shock cast on them. Flame Shock critical strikes reduce the cooldown of Chain Harvest by ${$m3/1000}.1 sec. |
| 356253, 356440, 356447, 356685 | Dreadbugs | You are covered in a swarm of aggressive insects that transfer to an enemy when you damage, dealing $<points> Nature damage every $356440t1 sec, then return to you when the enemy dies.

\|cFFff2020You suffer $356253s1% health as Nature damage every $356253t1 sec while swarmed.\|r |
| 356346 | Timebreaker's Paradox | Frozen in time for $d. |
| 356359 | Sanguine Defense | You have a chance to summon Coagulated Blood to assist you in battle when you receive damage. When they die or expire, you are healed for $s2% of your maximum health.

A maximum of $s3 Coagulated Blood may be active at once. |
| 356365 | Sanguine Defense | Heals the target for $s1% of their maximum health. |
| 356389 | Claws of Sath'zuul | Dealing damage has a chance to spawn a Sanguine Globule nearby. Collecting the globule grants you increased leech and primary stat for $356393d. |
| 356393 | Sanguine Fury | Increases primary stat by $s1% and leech by $s2%. |
| 356506 | Sweet Dreams | When you attack a new creature, teleport to their location: putting all enemies in a $r yard radius into a deep sleep for $s2 seconds. 

Damage breaks this effect. This effect can only occur once every $s3 seconds. |
| 356507 | Sweet Dreams | Teleport to the current target, sleeping nearby enemies for $s2 seconds. |
| 356516 | Imposter | Copy an enemy's appearance: fooling them and their allies. While disguised: your next attack inflicts $s2% increased damage. |
| 356524 | Imposter | Gain an Orb of Deception: allowing you to copy an enemy's appearance: fooling them and their allies. While disguised: your next attack inflicts $s1% increased damage. |
| 356530 | Dreadbound | Your soul is bound with Vil'thras. When you fall below $s2% health, he casts Dread Protection, reducing damage taken by $356533s1% for $356533d.

\|cFFff2020Occasionally, Vil'thras challenges you in an attempt to take over your body. Dread Protection will not trigger when fighting Vil'thras.\|r |
| 356533 | Dread Protection | $%spelldesc356530 |
| 356600 | Calculated Assault | Your attacks have a chance to summon a Focused Conduit: inflicting Arcane damage to all enemies in a straight line after a brief delay. |
| 356628 | Grant Power: Calculated Assault | On Pickup: Grants the Anima Power, "Calculated Assault". |
| 356662 | Refractive Shield | Being attacked causes you to emit a Refractive Burst, inflicting Arcane damage and stunning all nearby enemies. This effect can occur once every $356669d. |
| 356663 | Refractive Burst | Inflicts $s1 Arcane damage and stuns all enemies within $A1 yards. |
| 356672 | Grant Power: Refractive Shield | On Pickup: Grants the Anima Power, "Refractive Shield". |
| 356779 | Fool's Wager | Replace your gear with a fool's outfit, betting on yourself to complete the next floor without dying. If successful, earn a substantial boon.

Successful wager causes: Damage taken is reduced by $s3%. Maximum health increased by $s4%. Health regen increased by $s5%.

\|cFFff2020Fool's outfit caus |
| 356789 | Raging Vesper Vortex | When $s1 charges of Vesper Totem are consumed, Vesper Totem will radiate a $356790A1 yd burst of $356790s1 Arcane damage and $356791s2 healing. |
| 356825 | Dark Fortress | While in combat, every $t1 sec gain $356826s1% reduced damage taken for $356826d. This effect stacks up to $356826U times. |
| 356827 | Tiny Dancing Shoes | Upon entering combat, you dodge $357540U melee or ranged attacks against you. |
| 356828 | Dripping Fang | Gain $356828s1% Leech increasing up to $s2% based on your missing health. |
| 356851 | Elethium Diffuser | Inflicts Shadow damage equal to $s3% of all the damage you receive, split amongst enemies within $356852A1 yds, but you are no longer able to step backwards. |
| 356855 | Soul Empowerment | Your abilities have a chance to create a zone of soul empowerment nearby. Any player may collect this to gain $353745s1% damage and healing done and $353745s2% movement speed for $353745d. |
| 356914 | Erratic Howler | While in combat, release an uncontrolled howl at random intervals. This howl interrupts spells within $356915A1 yards. |
| 356921 | Glasswing Charm | Become a cloud of insects when out of combat, increasing movement speed by $356920s1%. |
| 356922 | Negation Well | Greatly increase the power of your jumps. Your movement speed is also increased by $s3%. |
| 356954 | Elethium Veil | Your ability costs are reduced by $s1%. |
| 357556 | Self-Embalming Kit | Increases all self-healing by $s1%. |
| 357575 | Champion's Brand | While above $s1% health, your Mastery or Critical Strike is increased by $357584s1. Your highest stat is always chosen. |
| 357604 | Siegebreaker's Stand | Standing still increases your damage dealt by $357607s1% every $t1 sec, stacking up to $357607U times. Upon reaching $357607U stacks gain an additional $359166s1% Armor. This bonus is lost when you move. |
| 357609 | Dagger of Necrotic Wounding | Damaging a target has a high chance to consume the target with creeping decay, dealing ${$<points>*$d/$t1} Physical damage over $d, and reducing healing and absorption received by $s3%, stacking up to $U times. |
| 357706 | Volcanic Plumage | Damaging a target has a chance to create a gout of flame beneath the target that erupts after 2.5 sec, dealing ${$<points>} Fire damage to all enemies within $357708a1 yards, and knocking them upward. |
| 357747 | Overflowing Chalice | Healing a target has a chance to chance to generate $@spellname357749, which can be collected to restore $357751s1% of your maximum mana. |
| 357778 | Broken Mirror | Magic damage taken is reduced by $s1%. |
| 357814 | Regenerative Fungus | Taking damage heals you for ${$359164s2/10}.1% of your maximum health. |
| 357815, 359122 | Satchel of the Hunt | While in combat, you grant all allies within $s1 yds an additional $357816s1% movement speed. |
| 357817 | Huntsman's Horn | Upon entering combat, gain $357818s1% movement speed for $357818d. |
| 357825 | Vial of Desperation | Whenever you take more than $s2% of your maximum health in damage from a single attack, you gain $357826s1% increased movement speed and suffer $357826s2% less damage for $357826d. |
| 357839 | The Fifth Skull | While in combat, if there are $357839s1 or more enemies within $357840A1 yds, the skull releases a wave of shadow, dealing ${$<points>} Shadow damage every $357839t1 sec to up to $357839s2 enemies. |
| 357863 | The Stygian King's Barbs | When enemies strike you in melee combat, shadow barbs lash out from you and deal $s2% of your current health in Shadow damage to them. |
| 357864 | Raging Battle-Axe | Damaging a target below $357864s1% health has a high chance to hurl a $@spellname357866 at the target dealing ${$<points>} Physical damage. |
| 357889 | Pedestal of Utter Hubris | Your Haste is increased by $357892s1% while in combat, but you burn for $359119s1% of your maximum health every $357892t2 sec. |
| 357897 | Crumbling Bulwark | Your versatility is increased by $s2%. 

Upon entering combat, your damage taken is reduced by $357898s1% for $357898d. |
| 357900 | Bottle of Sanguine Ichor | Healing a target has a chance to cause you to splash Sanguine Ichor, healing up to $357900s1 allies for ${$<points0>} and dealing ${$<points2>} Shadow damage to up to $357900s1 enemies within $357901a1 yds. |
| 359015 | Forbidden Knowledge | You have an anima power that is incompatible with your current specialization. |
| 362182 | Obleron Armaments | Grants a collection of Obleron Armaments. |
| 363724 | Torment | Inflicts $s1 Shadow damage to an enemy every $t1 sec. |
| 363726 | Looping Torment | Your attacks have a chance to form an Orb of Torment to orbit around you, inflicting Shadow damage to enemies in their path. |
| 363739, 363741 | Cosmic Alacrity | Killing an enemy grants $s1% increased movement speed for $d. Stacks $U times. |
| 363878 | Automa Excavator | An Automa Excavator joins you in combat. |
| 363996 | Cosmic Tremor | Reduces movement speed and melee attack speed by $s1%. |
| 364050 | Terraform Bolt | Inflicts Cosmic damage to all enemies within $A1 yards. |
| 364085 | Potent Thistle Tea Concentrate | Provides a large boost to your Energy regeneration rate. |
| 364538 | Sharpshooter's Insight | Increases the maximum damage bonus of Lone Wolf by $s1%. |
| 364542, 364543, 364545 | Sharpshooter's Insight | Increases the maximum damage bonus of Lone Wolf by ${$s1*$364538s1}% |
| 365266 | Inversion Prism | Your heals deal $s1% of their potential heal amount as Holy damage to nearby enemies. |
| 365267, 365340, 365372 | Virulent Spores | Regrowth forms a temporary poisonous patch on the ground around its target, dealing $s1% of its healing as Nature damage to nearby enemies every $s2 sec for $365340d. |
| 372904 | Ruby Affinity | Red spells deal $s1% more damage and healing. |
| 372909, 372910 | Ruby Affinity | Red spells deal ${$372904s1*$s1}% more damage and healing. |
| 372911 | Emerald Affinity | Green spells deal $s1% more healing and damage. |
| 372912, 372913 | Emerald Affinity | Green spells deal ${$372911s1*$s1}% more healing and damage. |
| 372914 | Azure Affinity | Blue spells deal $s1% more damage and healing. |
| 372915, 372916 | Azure Affinity | Blue spells deal ${$372914s1*$s1}% more damage and healing. |
| 372917 | Obsidian Affinity | Black spells deal $s1% more damage and healing. |
| 372918, 372919 | Obsidian Affinity | Black spells deal ${$372917s1*$s1}% more damage and healing. |
| 372920 | Bronze Affinity | Bronze spells deal $s1% more healing and damage. |
| 372921, 372922 | Bronze Affinity | Bronze spells deal ${$372920s1*$s1}% more healing and damage. |
| 372923 | Hearty Sustenance | Essence recharges $s1% faster. |
| 372929 | Legacy of Wisdom | The cooldowns of Red and Green spells are reduced by $s1%. |
| 372932 | Legacy of Knowledge | The cooldowns of Blue and Bronze spells are reduced by $s1%. |
| 372933 | Legacy of Power | The cooldowns of Black spells are reduced by $s1%. |
| 372935 | Worn Adamantine Scale | $@spellname324717 increases the duration of Obsidian Scales by $s1% per application. |
| 372936, 372937 | Enlivened Soot | Living Flame increases your haste by $s1% for $372937d, stacking up to $372937u times. |
| 372938 | Talon-Raked Aegis | Reduces the cooldown of Wing Buffet and Tail Swipe by ${$s1/-1000} sec. |
| 372939 | Pulsating Eggshell | Gain the Essence Burst effect every $t1 sec. |
| 372940, 373020 | Roar in a Bottle | Empower spells grant you $s1% versatility per empower level for $373020d. |
| 372946 | Energized Membrane | Hover lasts ${$s1/1000} sec longer. |
| 372948 | Colossal Fang | Fire Breath's damage over time effect also silences enemies. |
| 372950 | Searing Coals | Disintegrate casts $m1 $LPyre:Pyres; at your target over its duration. |
| 372954, 372956 | Igneous Crucible | $?s403631[Breath of Eons][Deep Breath] causes enemies to take $372956s1% increased damage from all sources for $372956d. |
| 372958 | Antique Oathstone | Your Essence spells deal $s1% more damage and healing. |
| 373005, 373008 | Spectral Sproutling | Emerald Blossom now grows a bulb at all of your allies' locations, or a second bulb on yourself if you are not in a party. |
| 373713, 373714, 373715, 373716, 373717 | Humming Geode | Essence abilities grant you $s1% increased damaging and healing for that color for $373714d. Stacks $373714u times. |
| 373726, 373728, 373730 | Lichdragon's Cursemark | Defeating an enemy grants $s1 Essence and $s2% mana. |
| 373748, 373751 | Vicious Whelpling | Gain a whelpling companion that deals $s1 damage each time you cast an Evoker spell. |
| 373761 | Poisonous Spores | Emerald Blossom damages enemies within its radius for $s1% of its healing amount. |
| 373766 | Emerald Blossom | Grow a bulb from the Emerald Dream at an ally's location. After $d, heal up to $355916s2 injured allies within $s1 yds for $355916s1. |
| 373770, 373771 | Sands of Time | Hover accelerates time by $s1% for $373771d. |
