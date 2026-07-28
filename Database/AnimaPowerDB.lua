-- AnimaPowerDB.lua — curated scoring data for Torghast-style anima power choices.
--
-- Ported from the archived JustTorghast addon (same author). This is JUDGMENT data: which
-- powers are traps, and how much each is worth under two different goals. None of it is
-- derivable from game data today — there is no "is this power good" column anywhere — so
-- it stays hand-curated and hand-edited.
--
-- The danger list is NOT derivable from game data, and that was tested rather than assumed:
-- a blanket negative-basepoint rule over SpellEffect gets 38% recall with 9% false positives;
-- the best zero-false-positive rule set gets 48% with only ONE generalising rule; expanding
-- through EffectTriggerSpell made it worse, not better. Every genuinely run-ending trap is in
-- the half no rule catches, and for a structural reason: the harm is a property of the
-- CONTENT, not the spell. "Prevents jumping" is neutral game data that is only dangerous on
-- Torghast's terrain. None of that context exists in any data file. So unlike the container
-- list, this one can never be generated — it is play experience, and it is the real asset here.
--
-- Because of that, the description patterns below are the PRIMARY defence and not a fallback:
-- the description is the only place harm is stated, and it always arrives in the choice
-- payload. ScoreOption runs the penalty patterns BEFORE any curated lookup, so a wrong entry
-- in this file can cost a bad pick but never a taken trap.
--
-- IDs were verified against published power lists and cross-checked against SpellName; 15 were
-- pointing at unrelated spells and are marked "id corrected from". Entries labelled "-- was:"
-- had a description in the name field and now carry the canonical spell name. Around 55
-- duplicate keys were also collapsed — Lua silently keeps the last of a repeated key, so those
-- scores had been dead.
--
-- Scores are 0-100. Anything at or below IGNORE_BELOW is treated as "not worth taking" and
-- the choice is handed back to the player rather than guessed at.

local ADDON_NAME, JustQuest = ...

JustQuest.Database = JustQuest.Database or {}

local AnimaPowerDB = {}

-- ============================================================
-- Blocked powers — traps, not weak picks
-- ============================================================
-- These do not merely score badly, they actively cost you the run: movement restrictions
-- that strand you on terrain, health drains that spiral when low, self-damage on miss.
-- Never auto-selected, in either mode, at any score.

AnimaPowerDB.BLOCKED = {
    -- Elethium Weights - Prevents jumping
    [319041] = { name = "Elethium Weights", reason = "Prevents jumping - can get stuck" },
    [347968] = { name = "Elethium Weights", reason = "Prevents jumping - can get stuck" }, -- PTR version
    
    -- Elethium Diffuser - Prevents moving backward
    [319206] = { name = "Elethium Diffuser", reason = "Prevents moving backward - can get stuck" },
    [319209] = { name = "Elethium Diffuser", reason = "Prevents moving backward - can get stuck" }, -- Alternative ID
    [347969] = { name = "Elethium Diffuser", reason = "Prevents moving backward - can get stuck" }, -- Updated version
    
    -- Movement Speed Death Spiral
    [329960] = { name = "Lycara's Bargain", reason = "Movement speed reduced 1% per cast - death spiral" },
    
    -- Movement Speed Cap
    [320926] = { name = "Art of the Blinkmage", reason = "Movement speed capped at 3 yards/sec - too restrictive" },
    
    -- Health Cost Death Spirals
    [332207] = { name = "Tainted Blood Vial", reason = "Costs 10% current health per cast - death spiral when low" },
    [322841] = { name = "Furywing", reason = "Damages you for 15% health if doesn't hit enemy" },
    [320955] = { name = "Art of the Blood Passage", reason = "Deals 5% health damage every 3 seconds" },
    
    -- Dangerous Penalties
    [320936] = { name = "Soul Platter", reason = "50% chance to consume Soul Remnants - too risky" },  -- was: Demonic Tyrant Extension
    [322249] = { name = "Soul Platter", reason = "50% chance to consume Soul Remnants - too risky" },
    [337750] = { name = "Fractured Phantasma Lure", reason = "Decreases damage done by 10%" },
    
    -- Elethium Penalty Powers (Damage Reduction)
    [319276] = { name = "Elethium Muzzle", reason = "Reduces Physical damage and healing by 25%" },
    [319279] = { name = "Elethium Alembic", reason = "Reduces Arcane damage and healing by 25%" },
    [319280] = { name = "Elethium Beacon", reason = "Reduces Fire damage and healing by 25%" },
    [319285] = { name = "Elethium Teardrop", reason = "Reduces Frost damage and healing by 25%" },
    [319287] = { name = "Elethium Lantern", reason = "Reduces Shadow damage and healing by 25%" },
    [319288] = { name = "Elethium Censer", reason = "Reduces Holy damage and healing by 25%" },
    
    -- Dangerous Mechanics
    [320920] = { name = "Timebreaker's Paradox", reason = "Causes all affected players to die at the end" },
    [312897] = { name = "Volatile Augury", reason = "Pet explodes when it reaches critical health" },

    -- Loses you the map, which in Torghast is how you get lost rather than how you get killed —
    -- but it ends the run just as surely. Found by scanning the full labelled roster; it was
    -- never in the hand list because it does not read as dangerous until you play it.
    [319056] = { name = "Elethium Veil", reason = "No longer able to view your map" },
    [356954] = { name = "Elethium Veil", reason = "No longer able to view your map" },

    -- SIBLING IDS of the traps above. The game may offer any id that carries a power, and the
    -- hand-written list only ever caught the one that happened to be seen. Every entry here was
    -- found by matching names across the SpellLabel 630 roster — same failure as the scores,
    -- except that missing one of these costs the run rather than one weaker pick.
    [356851] = { name = "Elethium Diffuser", reason = "Prevents moving backward - can get stuck" },
    [322168] = { name = "Art of the Blood Passage", reason = "Deals 5% health damage every 3 seconds" },
    [322247] = { name = "Soul Platter", reason = "50% chance to consume Soul Remnants - too risky" },
    [332206] = { name = "Tainted Blood Vial", reason = "Costs 10% current health per cast - death spiral when low" },
    [324919] = { name = "Furywing", reason = "Damages you for 15% health if doesn't hit enemy" },
    [329961] = { name = "Lycara's Bargain", reason = "Movement speed reduced 1% per cast - death spiral" },
    [356346] = { name = "Timebreaker's Paradox", reason = "Causes all affected players to die at the end" },
    [312901] = { name = "Volatile Augury", reason = "Pet explodes when it reaches critical health" },
    [312902] = { name = "Volatile Augury", reason = "Pet explodes when it reaches critical health" },
}

-- ============================================================
-- Curated scores, per mode
-- ============================================================
-- Two genuinely different value systems, not one list with a multiplier. NORMAL optimises
-- for clearing (damage and survivability carry the run); FARMING optimises for throughput
-- (movement and Phantasma compound, survivability matters less when nothing lives long).

AnimaPowerDB.SCORES_NORMAL = {
    -- === MOVEMENT POWERS (ABSOLUTE TOP PRIORITY) ===
    [329580] = { name = "Bottle of Swirling Maelstrom", priority = 95 }, -- Ghost Wolf speed
    [322835] = { name = "Mark of the Ogre", priority = 95 }, -- Metamorphosis size/speed/range
    [342789] = { name = "Smuggled Wildseed", priority = 90 }, -- Soulshape +50% speed
    [342779] = { name = "Crystallized Dreams", priority = 90 }, -- Soulshape immunity
    [325867] = { name = "Parliament Stone", priority = 88 }, -- Steward 50% speed + dodge  -- id corrected from 321077
    
    -- === GAME-CHANGING HIGH VALUE POWERS ===
    [330274] = { name = "Lycara's Sash", priority = 88 }, -- Auto-cast on shapeshift
    [291442] = { name = "Jack of All Trades", priority = 88 }, -- Cross-spec cooldowns
    [331641] = { name = "Constellation Star-Chart", priority = 88 }, -- Extra celestial invoke
    -- REMOVED: Tainted Blood Vial - health cost death spiral
    [320945] = { name = "Pact of Infernal Intimacy", priority = 87 }, -- 100% demon health/damage per floor
    
    -- === COMPOUND DAMAGE POWERS (EXCELLENT) ===
    [332366] = { name = "Ancient Drake Breath", priority = 85 }, -- Icebound + freeze all
    [332578] = { name = "Bone Growing Juice", priority = 85 }, -- +50% size/stats during CDs
    [322846] = { name = "Resonant Mawfang", priority = 85 }, -- Interrupt = 2% max health damage
    [331931] = { name = "Superstrain", priority = 84 }, -- All diseases apply others
    [329799] = { name = "Circlet of Weeds", priority = 84 }, -- 33% faster DOTs/HOTs
    [334314] = { name = "Draught of Midday Calm", priority = 83 }, -- 60% increased single target
    
    -- === SOUL REMNANT STACKERS (PERMANENT SCALING) ===
    [342027] = { name = "Offer of Souls", priority = 82 }, -- 10% permanent primary stat
    [320930] = { name = "Darkwhisper Signet", priority = 81 }, -- Extra summon
    [320932] = { name = "Mark of Borrowed Power", priority = 80 }, -- Refund chance
    
    -- === AOE MULTIPLICATION POWERS ===
    [320907] = { name = "Highly-Polished Handmirror", priority = 80 }, -- Smart mirror images
    [326553] = { name = "Heart-Piercing Spine", priority = 80 }, -- Throw glaive 70% health
    [343449] = { name = "Flowing Potential Wraps", priority = 80 }, -- 50% chance extra combo
    [332924] = { name = "Blood-tinged Poker", priority = 79 }, -- No sacrificial pact CD
    
    -- === CRITICAL MULTIPLIER POWERS ===
    [305052] = { name = "Lens of Elchaver", priority = 78 }, -- Crit deals 35% more  -- id corrected from 321064
    [337645] = { name = "Brittle Bone Dust", priority = 78 }, -- +25% crit chance taken
    
    -- === HIGH DAMAGE POWERS ===
    [299048] = { name = "Flame Jet", priority = 77 },  -- id corrected from 321044
    [331519] = { name = "The Horsemen's Call", priority = 77 },
    [329530] = { name = "Storm Conduit", priority = 77 },
    [320868] = { name = "Horrific Dictionary", priority = 77 }, -- Intellect per "Word" spell
    [329416] = { name = "Death Harvester", priority = 76 }, -- SW:Death stacking damage
    
    -- === MULTIPLICATIVE AOE POWERS ===
    [322421] = { name = "Pact of Infernal Intimacy", priority = 76 },
    [320944] = { name = "Hellfire Pact", priority = 76 },
    [304996] = { name = "Frostchipper", priority = 75 },  -- id corrected from 320948
    [329572] = { name = "Flames of the Cauldron", priority = 75 }, -- Flame Shock 40% faster
    
    -- === COMPOUND UTILITY POWERS ===
    [329970] = { name = "Orbit Breaker", priority = 74 }, -- Every 20th Moonfire = Full Moon
    [332685] = { name = "Plaguebringer", priority = 74 }, -- Disease 150% faster
    -- REMOVED: Soul Platter - Soul Remnant consumption risk
    -- REMOVED: Victory Rush Phantasma - takes resources from target
    
    -- === STACKING STAT POWERS (OBLERON SYSTEM) ===
    [294609] = { name = "Obleron Venom", priority = 70 }, -- 6% crit damage (stacks)
    [294578] = { name = "Obleron Spikes", priority = 70 }, -- 3% crit chance (stacks)
    [294592] = { name = "Obleron Winds", priority = 70 }, -- 3% haste (stacks)
    [294593] = { name = "Obleron Winds", priority = 73 }, -- 3% haste (stacks)
    [294594] = { name = "Obleron Winds", priority = 76 }, -- 9% haste
    [294611] = { name = "Obleron Venom", priority = 76 }, -- 18% crit damage
    [294587] = { name = "Obleron Spikes", priority = 73 }, -- 6% crit chance
    [294603] = { name = "Obleron Ephemera", priority = 66 }, -- 6% versatility
    [294604] = { name = "Obleron Ephemera", priority = 69 }, -- 9% versatility
    [294602] = { name = "Obleron Ephemera", priority = 63 }, -- 3% versatility (stacks)
    [293025] = { name = "Obleron Endurance", priority = 60 }, -- 15% max health
    [293026] = { name = "Obleron Endurance", priority = 63 }, -- 30% max health
    [293027] = { name = "Obleron Endurance", priority = 66 }, -- 45% max health
    
    -- === FEEDBACK LOOP POWERS ===
    [320898] = { name = "Seeker's Scroll", priority = 65 }, -- Phylactery = 2% spell damage (stacks 100)
    [305274] = { name = "Dark Armaments", priority = 64 }, -- Kill = 5% haste stacking
    [337881] = { name = "Fallen Armaments", priority = 64 }, -- Combat = 5% haste stacking
    [296141] = { name = "Knowledge of Mortality", priority = 63 }, -- 15% primary + regen  -- id corrected from 296140
    
    -- === GAME-CHANGING DEFENSIVE ===
    [338596] = { name = "Defiance of Death", priority = 85 }, -- 25% max health limit  -- id corrected from 321028
    [306609] = { name = "Disemboweler's Hook", priority = 82 }, -- Execute <10% health  -- id corrected from 321029
    [295963] = { name = "Crumbling Aegis", priority = 75 }, -- 1.5min immunity  -- id corrected from 321024
    
    -- === HIGH-VALUE GENERICS ===
    [336387] = { name = "Sealed Essence Sphere", priority = 71 },
    [335095] = { name = "Shard of Milkglass", priority = 70 },
    [331430] = { name = "Soulsteel Pinion", priority = 70 },
    [332806] = { name = "Badge of the Mad Paragon", priority = 69 },
    [320924] = { name = "Spaceweaver's Thread", priority = 68 },
    [320921] = { name = "Runecloth Wrappings", priority = 67 }, -- 2000% damage while invisible
    [314240] = { name = "Sacrificial Soul-Ash", priority = 67 },
    [322847] = { name = "Grim Tinder", priority = 67 },
    [329962] = { name = "Furious Spirits", priority = 67 },
    [322039] = { name = "Scratched Knife", priority = 65 },
    [332545] = { name = "Ring of Unburdening", priority = 68 },
    [329883] = { name = "Blackened Boulder", priority = 67 },
    
    -- === EXCELLENT KILL POWERS ===
    [333620] = { name = "Distillation of Sin", priority = 65 }, -- 5% kill chance  -- was: Execute Chance
    [331365] = { name = "Deadeye Satchel", priority = 64 }, -- Kill Shot 25% insta-kill <20%
    [329814] = { name = "Spike of the Ice Guardian", priority = 63 }, -- Frost Shock kills <10%
    
    -- === PET/SUMMON MULTIPLIERS ===
    [364517] = { name = "Zovaal's Versatile Vittles x 3", priority = 72 }, -- 45% pet damage  -- was: Pet Enhancement
    [364518] = { name = "Zovaal's Versatile Vittles x 4", priority = 75 }, -- Pet health/damage/size  -- was: Pet Enhancement
    [364474] = { name = "Zovaal's Versatile Vittles", priority = 66 }, -- 15% pet damage  -- was: Pet Enhancement
    [339126] = { name = "Imperial Warrant", priority = 65 }, -- 50% pet damage
    [332775] = { name = "Bottled Shadow", priority = 64 }, -- 200% pet damage  -- was: Soul Remnant Pet Boost
    
    -- === UTILITY EXCELLENT ===
    [300771] = { name = "Blade of the Lifetaker", priority = 72 },  -- id corrected from 321008
    [332316] = { name = "Bone Harvester", priority = 64 },
    [299391] = { name = "Call of Fire", priority = 70 },
    [299392] = { name = "Call of Lightning", priority = 70 },
    [299393] = { name = "Call of Earth", priority = 70 },
    [298806] = { name = "Consumed by Flame", priority = 58 },
    [329534] = { name = "Deadened Earth", priority = 56 },
    [329963] = { name = "Deathseer's Reins", priority = 64 },
    [329789] = { name = "Deathseer's Whip", priority = 64 },
    [329798] = { name = "Deeptremor Stone", priority = 66 },
    [335643] = { name = "Dried Blood of the Beast", priority = 60 },
    [299454] = { name = "Earthquake Upgrades", priority = 56 },
    [337613] = { name = "Erratic Howler", priority = 60 },  -- id corrected from 321033
    [332803] = { name = "Gavel of True Judgment", priority = 66 },
    [329335] = { name = "Gibbering Skull", priority = 58 },
    [335441] = { name = "Golden Plume", priority = 68 },
    [335607] = { name = "Mote of Blood Thirst", priority = 66 },
    [320905] = { name = "Sapphire Prism", priority = 64 },
    [320869] = { name = "Light-Tinged Scraps", priority = 52 },
    [298803] = { name = "Secret of Living Flame", priority = 58 },
    [332401] = { name = "Vestige of Hope", priority = 58 },
    [332592] = { name = "Theory of Justice", priority = 56 },
    [331667] = { name = "Tiger and Crane Figurines", priority = 66 },
    [298907] = { name = "Unquenchable Flame", priority = 74 },
    [335088] = { name = "Small Smooth Spike", priority = 58 },
    
    -- === SURVIVABILITY POWERS (REDUCED IN NORMAL) ===
    [338733] = { name = "Ever-Beating Heart", priority = 54 },  -- id corrected from 321035
    [343381] = { name = "Organized Vial Satchel", priority = 50 },
    [342796] = { name = "Murmuring Shawl", priority = 48 }, -- Door of Shadows dodge
    [342793] = { name = "Murmuring Shawl", priority = 48 }, -- Alternative spell ID
    [294588] = { name = "Obleron Spikes", priority = 76 }, -- rank x3 was MISSING - fell to the rarity fallback
    [294610] = { name = "Obleron Venom", priority = 73 }, -- rank x2 was MISSING - fell to the rarity fallback

    -- === BUILD-DEFINING POWERS (found by scanning the full SpellLabel 630 roster) ===
    [348541] = { name = "Refilling Elixir of Life", priority = 92 }, -- heal to full below a health threshold, once per floor - a free death save
    [343788] = { name = "Ever-Tumbling Stone", priority = 90 }, -- Roll grants immunity per yd travelled, refreshed each floor - mobility AND immunity
    [295086] = { name = "Ultimate Detainment", priority = 88 }, -- permanently root and silence everything nearby, once per floor
    [341098] = { name = "Death's Deliverance", priority = 86 }, -- Door of Shadows loses its cooldown and explodes on arrival - mobility engine
    [320908] = { name = "Sorcerer's Frozen Soul", priority = 85 }, -- Ice Block has no cooldown - unlimited defensive resets
    [322833] = { name = "Shield of Unending Fury", priority = 84 }, -- immune to all damage while channelling - large uptime on a core ability
    [322031] = { name = "Spattered Soles", priority = 78 }, -- Charge/Heroic Leap kills a Mawrat and RESETS - chains across a floor
    [332609] = { name = "Exterminator", priority = 76 }, -- Death Grip explodes a Mawrat and resets - same chaining
    [343251] = { name = "Poisoned Rush", priority = 80 }, -- Sepsis resets Vendetta/Adrenaline Rush/Shadow Blades
    [342377] = { name = "Malevolence", priority = 80 }, -- Mirrors instant, cooldown reset on a kill
    [343203] = { name = "Ringing Doom", priority = 76 }, -- Echoing Reprimand reset on Animacharged spend
    [333352] = { name = "Seeds of Rampant Growth", priority = 76 }, -- Fae Transfusion resets Feral Spirit / Elemental
    [334412] = { name = "Preserved Ironwood Seed", priority = 68 }, -- Rebirth has no cooldown - a battle rez, worth little solo
    [322859] = { name = "Moccasins of Ascent", priority = 82 }, -- a free 1-min major cooldown on EVERY floor
    [332409] = { name = "Winged Medallion", priority = 80 }, -- Avenging Wrath at the start of every floor
    [333917] = { name = "Shadowy Essence", priority = 74 }, -- free Cloak of Shadows when low, once per floor
    [320922] = { name = "Mad Wizard's Scrawlings", priority = 66 }, -- cast-in-order puzzle for a bonus - strong but demands attention
    [321433] = { name = "Mad Wizard's Intuition", priority = 66 }, -- same cast-in-order puzzle
    [321445] = { name = "Mad Wizard's Intellect", priority = 66 }, -- same cast-in-order puzzle
    [314225] = { name = "Lightfire Soles", priority = 70 }, -- kill Mawrats by running through them - pure trash clear
    [322868] = { name = "Cadaverous Cleats", priority = 74 }, -- Disengage kills a Mawrat, stacking into a damage bonus
    [331514] = { name = "Tumbling Rollstone", priority = 72 }, -- extra Roll charges - mobility
    [343468] = { name = "Staggered Stomps", priority = 76 }, -- extra Faeline Stomp charges, and gains one on reset
    [333344] = { name = "Hourglass of Soul Dust", priority = 74 }, -- extra Primordial Wave charges
    [314294] = { name = "Soulcarved Vow", priority = 78 }, -- Spear of Bastion's damage lasts forever
    [322879] = { name = "Necrotic Touch", priority = 64 }, -- a permanent slow - utility, not throughput
    [306610] = { name = "Disemboweler's Hook", priority = 82 }, -- alt id of 306609, score mirrored
    [308204] = { name = "Crumbling Aegis", priority = 75 }, -- alt id of 295963, score mirrored
    [331366] = { name = "Deadeye Satchel", priority = 64 }, -- alt id of 331365, score mirrored
    [333621] = { name = "Distillation of Sin", priority = 65 }, -- alt id of 333620, score mirrored
}

AnimaPowerDB.SCORES_FARMING = {
    -- === MOVEMENT POWERS (STILL HIGHEST) ===
    [329580] = { name = "Bottle of Swirling Maelstrom", priority = 95 },
    [322835] = { name = "Mark of the Ogre", priority = 95 },
    [342789] = { name = "Smuggled Wildseed", priority = 92 },
    [342779] = { name = "Crystallized Dreams", priority = 92 },
    [325867] = { name = "Parliament Stone", priority = 90 },  -- id corrected from 321077
    
    -- === PHANTASMA POWERS (MASSIVE BOOST) ===
    [320898] = { name = "Seeker's Scroll", priority = 90 }, -- Phylactery stacking
    [295067] = { name = "Massive Phantasma", priority = 94 }, -- 50% more phantasma
    [305308] = { name = "Broker's Purse", priority = 88 }, -- 400 phantasma
    [295068] = { name = "Abundance of Phantasma", priority = 88 }, -- 300 phantasma  -- id corrected from 295968
    [295073] = { name = "Satchel of Phantasma", priority = 87 }, -- 150 phantasma
    [295092] = { name = "Clouded Thoughts", priority = 88 }, -- Phantasma clouds
    [295071] = { name = "Significant Phantasma", priority = 92 }, -- 25% more
    [295072] = { name = "Pouch of Phantasma", priority = 84 }, -- 75 phantasma
    [295070] = { name = "Increased Phantasma", priority = 90 }, -- 10% more
    [340691] = { name = "Weight of Darkness", priority = 88 }, -- 100% phantasma in darkness
    
    -- === HIGH VALUE POWERS (REDUCED) ===
    [330274] = { name = "Lycara's Sash", priority = 82 },
    [291442] = { name = "Jack of All Trades", priority = 82 },
    [331641] = { name = "Constellation Star-Chart", priority = 82 },
    -- REMOVED: Tainted Blood Vial - health cost death spiral
    [320945] = { name = "Pact of Infernal Intimacy", priority = 80 },
    
    -- === EFFICIENT KILL POWERS (FARMING FRIENDLY) ===
    [333620] = { name = "Distillation of Sin", priority = 78 }, -- 5% kill chance  -- was: Execute Chance
    [331365] = { name = "Deadeye Satchel", priority = 76 }, -- Kill Shot insta-kill
    [329814] = { name = "Spike of the Ice Guardian", priority = 75 }, -- Frost Shock kills
    [306609] = { name = "Disemboweler's Hook", priority = 78 }, -- Execute <10%  -- id corrected from 321029
    
    -- === AOE POWERS (GOOD FOR FARMING) ===
    [320907] = { name = "Highly-Polished Handmirror", priority = 74 },
    [326553] = { name = "Heart-Piercing Spine", priority = 74 },
    [343449] = { name = "Flowing Potential Wraps", priority = 74 },
    [332924] = { name = "Blood-tinged Poker", priority = 73 },
    [322421] = { name = "Pact of Infernal Intimacy", priority = 72 },
    [320944] = { name = "Hellfire Pact", priority = 72 },
    [304996] = { name = "Frostchipper", priority = 71 },  -- id corrected from 320948
    
    -- === SPEED + EFFICIENCY POWERS ===
    [329799] = { name = "Circlet of Weeds", priority = 76 }, -- Faster DOTs/HOTs
    [334314] = { name = "Draught of Midday Calm", priority = 74 }, -- Single target boost
    [329572] = { name = "Flames of the Cauldron", priority = 73 }, -- Faster Flame Shock
    
    -- === DAMAGE POWERS (REDUCED PRIORITY) ===
    [332366] = { name = "Ancient Drake Breath", priority = 72 },
    [332578] = { name = "Bone Growing Juice", priority = 72 },
    [322846] = { name = "Resonant Mawfang", priority = 72 },
    [331931] = { name = "Superstrain", priority = 71 },
    [299048] = { name = "Flame Jet", priority = 68 },  -- id corrected from 321044
    [331519] = { name = "The Horsemen's Call", priority = 68 },
    [329530] = { name = "Storm Conduit", priority = 68 },
    [320868] = { name = "Horrific Dictionary", priority = 68 },
    [342027] = { name = "Offer of Souls", priority = 68 },
    [329416] = { name = "Death Harvester", priority = 66 },
    
    -- === STACKING POWERS (STILL GOOD) ===
    [294609] = { name = "Obleron Venom", priority = 65 },
    [294578] = { name = "Obleron Spikes", priority = 65 },
    [294592] = { name = "Obleron Winds", priority = 65 },
    [294593] = { name = "Obleron Winds", priority = 68 },
    [305274] = { name = "Dark Armaments", priority = 62 },
    [337881] = { name = "Fallen Armaments", priority = 62 },
    
    -- === UTILITY POWERS (REDUCED) ===
    [336387] = { name = "Sealed Essence Sphere", priority = 64 },
    [320930] = { name = "Darkwhisper Signet", priority = 64 },
    [320932] = { name = "Mark of Borrowed Power", priority = 64 },
    [335095] = { name = "Shard of Milkglass", priority = 63 },
    [331430] = { name = "Soulsteel Pinion", priority = 63 },
    [329970] = { name = "Orbit Breaker", priority = 62 },
    [332685] = { name = "Plaguebringer", priority = 62 },
    [329883] = { name = "Blackened Boulder", priority = 60 },
    [314240] = { name = "Sacrificial Soul-Ash", priority = 60 },
    [322847] = { name = "Grim Tinder", priority = 60 },
    [329962] = { name = "Furious Spirits", priority = 60 },
    [322039] = { name = "Scratched Knife", priority = 58 },
    [332545] = { name = "Ring of Unburdening", priority = 56 },
    
    -- === CLASS-SPECIFIC COMPOUND POWERS ===
    
    -- DEATH KNIGHT SYNERGIES
    [350575] = { name = "Bone Borrower", priority = 75 }, -- Death Grip animates add  -- was: Death Grip Animator
    [332163] = { name = "Hungerstone", priority = 68 }, -- Death Strike +heal  -- was: Death Strike Enhancement
    -- REMOVED: Demon Scaling - Soul Remnant consumption risk  
    [332216] = { name = "Chains of Anguish", priority = 60 }, -- Health link 50% damage  -- was: Chains of Ice Health Link
    
    -- DEMON HUNTER SYNERGIES  
    [322822] = { name = "Seeker's Rage", priority = 58 }, -- 2% damage per phylactery  -- was: Ashen Phylactery Bonus
    [322837] = { name = "Cadaverous Eye", priority = 60 }, -- 60% CDR during Meta  -- was: Metamorphosis CDR
    
    -- DRUID SYNERGIES
    [330653] = { name = "Cloak of Thorns", priority = 68 }, -- Barkskin reflects damage  -- was: Barkskin Damage Reflect
    
    -- HUNTER SYNERGIES
    [364157] = { name = "Death's Rest", priority = 55 }, -- FD resets aspects  -- was: Feign Death Aspect Reset
    [331463] = { name = "Fogged Crystal", priority = 50 }, -- Target -90% damage  -- was: Misdirection Damage Reduction
    
    -- MAGE SYNERGIES
    
    -- MONK SYNERGIES
    [327761] = { name = "Negation Well", priority = 60 }, -- Enhanced mobility  -- was: Super Jump
    
    -- PALADIN SYNERGIES
    [364048] = { name = "Terraform Bolt", priority = 85 }, -- Chance for terrain bolt
    
    -- PRIEST SYNERGIES
    [350129] = { name = "Dark Technique", priority = 78 }, -- Fear enhances damage  -- was: Mass Fear Damage
    [329428] = { name = "Scales of Trauma", priority = 65 }, -- Shadow Mend empowers Mind Blast  -- was: Shadow Mend Empowerment
    [365200] = { name = "Inversion Prism", priority = 72 }, -- Heals deal 30% damage  -- was: Healing Damage Aura
    [331671] = { name = "Broker's Purse", priority = 87 }, -- BOOSTED for farming  -- was: Phantasma Bonus
    [364692] = { name = "Rapid Onset Shadows", priority = 60 }, -- SW:Death -5sec CD  -- was: Shadow Word Death CDR
    [364675] = { name = "Looming Death", priority = 62 }, -- SW:Death threshold +30%, damage +100%  -- was: Shadow Word Death Enhancement
    [363888] = { name = "Analyze Offenses", priority = 58 }, -- Damage reduces enemy damage 30%  -- was: Damage Examination
    [350140] = { name = "Voidwraith Signet", priority = 88 }, -- SW:Death kill = Voidwraith  -- was: Voidwraith Summon
    [349859] = { name = "Cowl of Influence", priority = 55 }, -- Control yourself during MC  -- was: Mind Control Enhancement
    [364663] = { name = "Prolonged Infusion", priority = 58 }, -- PI +10sec duration  -- was: Power Infusion Extension
    
    -- ROGUE SYNERGIES
    [364088] = { name = "Spirit of the Elusive Mark", priority = 54 }, -- Feint +20sec  -- was: Feint Duration
    [363994] = { name = "Cosmic Tremor", priority = 68 }, -- Enemies 45% slower  -- was: Movement/Attack Slow Aura
    [343451] = { name = "Vein Rippers", priority = 20 }, -- Vanish spreads poisons  -- was: Vanish Poison Explosion
    [364097] = { name = "Evasive Footwraps", priority = 55 }, -- Sprint casts Evasion  -- was: Sprint Evasion
    [343452] = { name = "Muffled Metronome", priority = 58 }, -- 10% damage per disabled enemy  -- was: CC Damage Bonus
    
    -- SHAMAN SYNERGIES
    [350252] = { name = "Pure Elemental Core", priority = 54 }, -- Storm Ele +50% duration  -- was: Storm Elemental Extension
    [329576] = { name = "Tsunami Relic", priority = 54 }, -- <50% health = 50% heal boost  -- was: Low Health Healing Boost
    [329811] = { name = "Spike of the Ice Guardian", priority = 70 }, -- GREAT for farming  -- was: Frost Shock Execute
    [350248] = { name = "Depleted Tesla Coil", priority = 72 }, -- Stormkeeper every 15sec  -- was: Auto Stormkeeper
    
    -- WARLOCK SYNERGIES
    [320939] = { name = "Dissolving Vial", priority = 55 }, -- Corruption instant cast  -- was: Instant Corruption
    [348545] = { name = "Orb of Replenishment", priority = 55 }, -- Orb mechanics  -- was: Healing Orbs
    [332185] = { name = "Blood-Stained Dagger", priority = 58 }, -- Pet damage reduction during heal  -- was: Pet Damage During Heal
    [320928] = { name = "Chaotic Effigy", priority = 58 }, -- Urns enhance shadowbolt  -- was: Urn Shadowbolt Damage
    -- REMOVED: Demonic Tyrant Extension - Soul Remnant consumption risk
    
    -- WARRIOR SYNERGIES
    [322030] = { name = "Hurricane Heart", priority = 58 }, -- Whirlwind heals  -- was: Whirlwind Healing
    [350007] = { name = "Gargolmar's Shattered Hand", priority = 54 }, -- Heal reduces leap CD  -- was: Heal Reduces Leap CD
    [350005] = { name = "Glory of Skyhold", priority = 55 }, -- Leap +2 charges  -- was: Heroic Leap Charges
    [350060] = { name = "Ancient Rubble", priority = 60 }, -- Leap more damage  -- was: Heroic Leap Damage
    [349916] = { name = "Weathered Runestone", priority = 58 }, -- Berserker Rage enhances damage  -- was: Berserker Rage Damage
    -- REMOVED: Victory Rush Phantasma - takes resources from target
    [349944] = { name = "Thorium Hairpin", priority = 54 }, -- Whirlwind generates rage  -- was: Whirlwind Rage Generation
    [350065] = { name = "Blade of the Tideskorn", priority = 55 }, -- Leap casts Piercing Howl  -- was: Heroic Leap Piercing Howl
    
    [300771] = { name = "Blade of the Lifetaker", priority = 62 },  -- id corrected from 321008
    [332316] = { name = "Bone Harvester", priority = 54 },
    [299391] = { name = "Call of Fire", priority = 60 },
    [299392] = { name = "Call of Lightning", priority = 60 },
    [299393] = { name = "Call of Earth", priority = 60 },
    [298806] = { name = "Consumed by Flame", priority = 48 },
    [329534] = { name = "Deadened Earth", priority = 46 },
    [329963] = { name = "Deathseer's Reins", priority = 58 },
    [329789] = { name = "Deathseer's Whip", priority = 54 },
    [329798] = { name = "Deeptremor Stone", priority = 56 },
    [335643] = { name = "Dried Blood of the Beast", priority = 50 },
    [299454] = { name = "Earthquake Upgrades", priority = 46 },
    [337613] = { name = "Erratic Howler", priority = 52 },  -- id corrected from 321033
    [332803] = { name = "Gavel of True Judgment", priority = 56 },
    [329335] = { name = "Gibbering Skull", priority = 44 },
    [335441] = { name = "Golden Plume", priority = 58 },
    [335607] = { name = "Mote of Blood Thirst", priority = 56 },
    [320905] = { name = "Sapphire Prism", priority = 54 },
    [320869] = { name = "Light-Tinged Scraps", priority = 44 },
    [298803] = { name = "Secret of Living Flame", priority = 48 },
    [332401] = { name = "Vestige of Hope", priority = 48 },
    [332592] = { name = "Theory of Justice", priority = 46 },
    [331667] = { name = "Tiger and Crane Figurines", priority = 56 },
    [298907] = { name = "Unquenchable Flame", priority = 64 },
    [335088] = { name = "Small Smooth Spike", priority = 48 },
    [320921] = { name = "Runecloth Wrappings", priority = 50 },
    
    -- === SURVIVABILITY (VERY LOW IN FARMING) ===
    [338733] = { name = "Ever-Beating Heart", priority = 41 },  -- id corrected from 321035
    [343381] = { name = "Organized Vial Satchel", priority = 35 },
    [342796] = { name = "Murmuring Shawl", priority = 35 },
    [342793] = { name = "Murmuring Shawl", priority = 35 },
    [338596] = { name = "Defiance of Death", priority = 45 }, -- Still valuable but lower  -- id corrected from 321028
    [295963] = { name = "Crumbling Aegis", priority = 42 },  -- id corrected from 321024
    
    -- === OBLERON STATS (LOWER IN FARMING) ===
    [294594] = { name = "Obleron Winds", priority = 71 },
    [294611] = { name = "Obleron Venom", priority = 71 },
    [294587] = { name = "Obleron Spikes", priority = 68 },
    [294603] = { name = "Obleron Ephemera", priority = 51 },
    [294604] = { name = "Obleron Ephemera", priority = 54 },
    [294602] = { name = "Obleron Ephemera", priority = 48 },
    [293025] = { name = "Obleron Endurance", priority = 45 },
    [293026] = { name = "Obleron Endurance", priority = 48 },
    [293027] = { name = "Obleron Endurance", priority = 51 },
    [294588] = { name = "Obleron Spikes", priority = 71 }, -- rank x3 was MISSING - fell to the rarity fallback
    [294610] = { name = "Obleron Venom", priority = 68 }, -- rank x2 was MISSING - fell to the rarity fallback

    -- === BUILD-DEFINING POWERS (found by scanning the full SpellLabel 630 roster) ===
    [348541] = { name = "Refilling Elixir of Life", priority = 88 }, -- heal to full below a health threshold, once per floor - a free death save
    [343788] = { name = "Ever-Tumbling Stone", priority = 92 }, -- Roll grants immunity per yd travelled, refreshed each floor - mobility AND immunity
    [295086] = { name = "Ultimate Detainment", priority = 84 }, -- permanently root and silence everything nearby, once per floor
    [341098] = { name = "Death's Deliverance", priority = 88 }, -- Door of Shadows loses its cooldown and explodes on arrival - mobility engine
    [320908] = { name = "Sorcerer's Frozen Soul", priority = 74 }, -- Ice Block has no cooldown - unlimited defensive resets
    [322833] = { name = "Shield of Unending Fury", priority = 76 }, -- immune to all damage while channelling - large uptime on a core ability
    [322031] = { name = "Spattered Soles", priority = 88 }, -- Charge/Heroic Leap kills a Mawrat and RESETS - chains across a floor
    [332609] = { name = "Exterminator", priority = 86 }, -- Death Grip explodes a Mawrat and resets - same chaining
    [343251] = { name = "Poisoned Rush", priority = 72 }, -- Sepsis resets Vendetta/Adrenaline Rush/Shadow Blades
    [342377] = { name = "Malevolence", priority = 72 }, -- Mirrors instant, cooldown reset on a kill
    [343203] = { name = "Ringing Doom", priority = 68 }, -- Echoing Reprimand reset on Animacharged spend
    [333352] = { name = "Seeds of Rampant Growth", priority = 68 }, -- Fae Transfusion resets Feral Spirit / Elemental
    [334412] = { name = "Preserved Ironwood Seed", priority = 58 }, -- Rebirth has no cooldown - a battle rez, worth little solo
    [322859] = { name = "Moccasins of Ascent", priority = 78 }, -- a free 1-min major cooldown on EVERY floor
    [332409] = { name = "Winged Medallion", priority = 74 }, -- Avenging Wrath at the start of every floor
    [333917] = { name = "Shadowy Essence", priority = 64 }, -- free Cloak of Shadows when low, once per floor
    [320922] = { name = "Mad Wizard's Scrawlings", priority = 58 }, -- cast-in-order puzzle for a bonus - strong but demands attention
    [321433] = { name = "Mad Wizard's Intuition", priority = 58 }, -- same cast-in-order puzzle
    [321445] = { name = "Mad Wizard's Intellect", priority = 58 }, -- same cast-in-order puzzle
    [314225] = { name = "Lightfire Soles", priority = 82 }, -- kill Mawrats by running through them - pure trash clear
    [322868] = { name = "Cadaverous Cleats", priority = 80 }, -- Disengage kills a Mawrat, stacking into a damage bonus
    [331514] = { name = "Tumbling Rollstone", priority = 82 }, -- extra Roll charges - mobility
    [343468] = { name = "Staggered Stomps", priority = 68 }, -- extra Faeline Stomp charges, and gains one on reset
    [333344] = { name = "Hourglass of Soul Dust", priority = 66 }, -- extra Primordial Wave charges
    [314294] = { name = "Soulcarved Vow", priority = 70 }, -- Spear of Bastion's damage lasts forever
    [322879] = { name = "Necrotic Touch", priority = 58 }, -- a permanent slow - utility, not throughput
    [306610] = { name = "Disemboweler's Hook", priority = 78 }, -- alt id of 306609, score mirrored
    [308204] = { name = "Crumbling Aegis", priority = 42 }, -- alt id of 295963, score mirrored
    [331366] = { name = "Deadeye Satchel", priority = 76 }, -- alt id of 331365, score mirrored
    [333621] = { name = "Distillation of Sin", priority = 78 }, -- alt id of 333620, score mirrored
    [316850] = { name = "Unstable Phantasma Lure", priority = 92 }, -- Phantasma: the point of a farming run
    [340692] = { name = "Weight of Darkness", priority = 88 }, -- Phantasma: the point of a farming run
    [337750] = { name = "Fractured Phantasma Lure", priority = 93 }, -- Phantasma: the point of a farming run
}

-- ============================================================
-- Score bands and thresholds, per mode
-- ============================================================

AnimaPowerDB.BANDS = {
    NORMAL = {
        MOVEMENT_EXCELLENT = 95, MOVEMENT_GREAT = 90, MOVEMENT_GOOD = 85,
        HIGH_VALUE = 88,
        DAMAGE_EXCELLENT = 82, DAMAGE_GREAT = 78, DAMAGE_GOOD = 74,
        AOE_EXCELLENT = 80, AOE_GREAT = 76, AOE_GOOD = 72,
        SURVIVABILITY_EXCELLENT = 70, SURVIVABILITY_GREAT = 68, SURVIVABILITY_GOOD = 64,
        PHANTASMA_EXCELLENT = 68, PHANTASMA_GREAT = 64, PHANTASMA_GOOD = 60,
        UTILITY_EXCELLENT = 64, UTILITY_GREAT = 62, UTILITY_GOOD = 60,
        CROWDCONTROL_GOOD = 62, CROWDCONTROL_BASIC = 58,
        SITUATIONAL_ONLY = 8, MINIMAL_EFFECT = 2, BLACKLISTED = -100,
        IGNORE_BELOW = 50,
    },
    FARMING = {
        MOVEMENT_EXCELLENT = 95, MOVEMENT_GREAT = 90, MOVEMENT_GOOD = 85,
        PHANTASMA_EXCELLENT = 88, PHANTASMA_GREAT = 83, PHANTASMA_GOOD = 78,
        HIGH_VALUE = 80,
        AOE_EXCELLENT = 76, AOE_GREAT = 72, AOE_GOOD = 68,
        DAMAGE_EXCELLENT = 64, DAMAGE_GREAT = 60, DAMAGE_GOOD = 56,
        UTILITY_EXCELLENT = 58, UTILITY_GREAT = 54, UTILITY_GOOD = 50,
        SURVIVABILITY_EXCELLENT = 40, SURVIVABILITY_GREAT = 36, SURVIVABILITY_GOOD = 32,
        CROWDCONTROL_GOOD = 30, CROWDCONTROL_BASIC = 26,
        SITUATIONAL_ONLY = 4, MINIMAL_EFFECT = 1, BLACKLISTED = -100,
        IGNORE_BELOW = 49,
    }
}

-- ============================================================
-- Description patterns — fallback for powers not in the curated tables
-- ============================================================
-- Scanned in order, first match wins, matched against a lowercased "name description".
-- PENALTIES RUN FIRST and that ordering is load-bearing: a power that reads "cooldown
-- reduced 50%, but you deal 10% less damage" must resolve to blocked, not to the utility
-- score its first clause would earn.
--
-- Known ceiling, accepted for now: these are English patterns against localized text, so on
-- a non-English client the fallback silently stops firing and unmatched powers hand back to
-- the player (safe, just less useful). The SpellEffect-derived classifier planned for this
-- is locale-proof and replaces the whole table — see the header note.

AnimaPowerDB.PATTERNS = {
    penalties = {
        -- Measured against all 1,725 resolved descriptions. A bare "no longer" was vetoing 15
        -- GOOD powers ("Death Pools no longer damage you", "Echoing Reprimand no longer costs
        -- energy", "Damage no longer breaks Frost Nova") because the phrase overwhelmingly marks
        -- a drawback being REMOVED. The traps use one specific construction — "you are no longer
        -- able to jump/step backwards" — so match that instead. The old wordings below it
        -- ("unable to jump", "cannot jump", ...) never fired on a single real description; they
        -- were guesses at phrasing the game does not use, and the blunt "no longer" was silently
        -- covering for them.
        {"no longer able to", "BLACKLISTED"},
        {"movement speed.*capped", "BLACKLISTED"},
        {"speed reduced", "BLACKLISTED"},
        {"speed is reduced", "BLACKLISTED"},
        {"haste.*reduced", "BLACKLISTED"},
        {"cooldown.*increased", "BLACKLISTED"},
        {"damage done.*reduced", "BLACKLISTED"},
        {"take.*more damage", "BLACKLISTED"},
        {"chance to consume", "BLACKLISTED"},
        {"no longer able to view.*map", "BLACKLISTED"},
        {"increased.*but.*reduced", "BLACKLISTED"},
        {"but.*take.*more damage", "BLACKLISTED"},
        {"but.*reduced.*stamina", "BLACKLISTED"},
    },
    high_value = {
        {"no cooldown", "HIGH_VALUE"},
        {"automatically cast", "HIGH_VALUE"},
        {"permanently increases", "HIGH_VALUE"},
        {"lasts.*forever", "HIGH_VALUE"},
        {"no longer consumes", "HIGH_VALUE"},
        {"infinite", "HIGH_VALUE"},
        {"reset.*cooldown", "HIGH_VALUE"},
        {"instantly kill", "HIGH_VALUE"},
        {"permanent", "HIGH_VALUE"},
        {"unable to lose more than.*health", "HIGH_VALUE"},
        {"health.*below.*%.*instantly kill", "HIGH_VALUE"},
        {"disembowel.*instantly killing", "HIGH_VALUE"},
        {"immunity to all damage", "HIGH_VALUE"},
        {"learn the.*ability", "HIGH_VALUE"},
        {"sustaining fatal damage.*detonates", "HIGH_VALUE"},
    },
    movement = {
        {"movement speed.*increased.*%%", "MOVEMENT_GREAT"},
        {"movement speed.*increased", "MOVEMENT_GOOD"},
        {"move.*faster", "MOVEMENT_GOOD"},
        {"speed.*increased", "MOVEMENT_GOOD"},
    },
    damage = {
        {"damage.*increased.*%d+%%", "DAMAGE_GOOD"},
        {"deal.*%d+%%.*more damage", "DAMAGE_GOOD"},
        {"critical.*increased.*%d+%%", "DAMAGE_GOOD"},
        {"haste.*increased.*%d+%%", "DAMAGE_GOOD"},
        {"cooldown.*reduced.*%d+", "DAMAGE_GOOD"},
    },
    aoe = {
        {"radius.*increased.*%d+", "AOE_EXCELLENT"},
        {"additional targets", "AOE_GOOD"},
        {"nearby enemies", "AOE_GOOD"},
        {"cleave", "AOE_GOOD"},
        {"area.*increased", "AOE_GOOD"},
    },
    phantasma = {
        {"phantasma.*earned.*%d+%%", "PHANTASMA_EXCELLENT"},
        {"phantasma.*increased.*%d+%%", "PHANTASMA_EXCELLENT"},
        {"acquire.*%d+.*phantasma", "PHANTASMA_GREAT"},
        {"gain.*%d+.*phantasma", "PHANTASMA_GREAT"},
        {"grants.*%d+.*phantasma", "PHANTASMA_GREAT"},
        {"more phantasma", "PHANTASMA_GOOD"},
        {"additional.*phantasma", "PHANTASMA_GOOD"},
    },
    survivability = {
        {"take.*%d+%%.*less damage", "SURVIVABILITY_GREAT"},
        {"damage.*taken.*reduced.*%d+%%", "SURVIVABILITY_GREAT"},
        {"health.*increased.*%d+%%", "SURVIVABILITY_GOOD"},
        {"maximum health.*increased", "SURVIVABILITY_GOOD"},
        {"immunity.*damage", "SURVIVABILITY_EXCELLENT"},
    },
    utility = {
        {"cost.*reduced.*%d+%%", "UTILITY_GREAT"},
        {"cooldown.*reduced.*%d+", "UTILITY_GREAT"},
        {"charges.*increased", "UTILITY_GREAT"},
        {"duration.*increased.*%d+", "UTILITY_GOOD"},
        {"range.*increased", "UTILITY_GOOD"},
        {"instant.*cast", "UTILITY_GOOD"},
        {"no.*mana.*cost", "UTILITY_GOOD"},
    },
    crowdcontrol = {
        {"stun.*%d+.*sec", "CROWDCONTROL_GOOD"},
        {"interrupt.*spell", "CROWDCONTROL_GOOD"},
        {"root.*%d+.*sec", "CROWDCONTROL_GOOD"},
        {"silence.*%d+.*sec", "CROWDCONTROL_GOOD"},
        {"slow.*%d+%%", "CROWDCONTROL_BASIC"},
        {"fear.*%d+.*sec", "CROWDCONTROL_BASIC"},
    },
    low_value = {
        {"cosmetic", "MINIMAL_EFFECT"},
        {"appearance", "MINIMAL_EFFECT"},
        {"visual.*effect", "MINIMAL_EFFECT"},
        {"detect.*treasure", "MINIMAL_EFFECT"},
    }
}

-- ============================================================
-- Fallback scoring for powers no curated entry covers
-- ============================================================
-- Lives here rather than in the engine because it is tuning data, and because the logic check
-- loads this file directly — a copy in the engine and a copy in the check drifted apart once
-- already, and the check went on passing against the stale numbers.

-- Blizzard's power-type icons (option.typeArtID, a texture FileDataID drawn as the card's
-- TypeIcon). Exactly three exist; confirmed live via /jq torghast check.
--     interface/icons/ui_jailerstower_offense.blp / _defense.blp / _utility.blp
AnimaPowerDB.POWER_TYPE = {
    [3446882] = "offense",
    [3446881] = "defense",
    [3446883] = "utility",
}

-- MEASURED, not assumed: rarity does NOT track how good a power is. Correlating Blizzard's tier
-- against the curated scores gives +0.18 while clearing and -0.14 while farming — no relationship,
-- and slightly inverted in the mode that cares most. Common powers average ~70 curated (Draught
-- of Midday Calm is Common and scored 83). Rarity evidently describes how often a power turns up.
--
-- So this ladder is deliberately flat and decides almost nothing on its own: every tier sits
-- within a few points of the mode floors (50/49), handing the real decision to TYPE_BONUS. Epic
-- keeps a genuine bump because build-defining powers do cluster there.
AnimaPowerDB.RARITY_SCORE = {
    [0] = 48,  -- Common
    [1] = 50,  -- Uncommon
    [2] = 52,  -- Rare
    [3] = 62,  -- Epic
}

-- What each type is worth, per mode — the signal that actually discriminates. Clearing has to
-- kill things and survive them; farming has to move fast and collect. Same distinction the two
-- curated tables encode, applied to powers no curated entry covers.
AnimaPowerDB.TYPE_BONUS = {
    normal  = { offense =  8, defense =  4, utility = -4 },
    farming = { offense = -4, defense = -8, utility =  8 },
}

-- ============================================================
-- Powers that pay out per floor
-- ============================================================
-- These either accumulate every time you ascend ("...and every time you ascend a floor, up to a
-- maximum of...") or hand you something once per floor. Either way their worth is a function of
-- how many floors are LEFT, not of the power alone: taken on the first floor a per-floor power
-- pays several times, taken on the last it pays once.
--
-- JAILERS_TOWER_LEVEL_UPDATE gives us the current floor, so the engine discounts these as the
-- run goes on. Static scoring rated them identically on floor 1 and floor 8.
AnimaPowerDB.PER_FLOOR = {
    [320945] = true,  -- Pact of Infernal Intimacy: demons gain health/damage every ascent
    [322421] = true,  -- (alt id of the above)
    [322859] = true,  -- Moccasins of Ascent: a free major cooldown every floor
    [332409] = true,  -- Winged Medallion: Avenging Wrath at the start of each floor
    [333917] = true,  -- Shadowy Essence: free Cloak of Shadows once per floor
    [348541] = true,  -- Refilling Elixir of Life: heal to full, once per floor
    [295086] = true,  -- Ultimate Detainment: castable once per floor
    [320922] = true,  -- Mad Wizard's Scrawlings: a puzzle bonus per floor
    [321433] = true,  -- Mad Wizard's Intuition
    [321445] = true,  -- Mad Wizard's Intellect
    [343788] = true,  -- Ever-Tumbling Stone: refreshes whenever you change floors
    [295067] = true,  -- Phantasma multiplier: compounds over the floors that remain
    [295070] = true,  -- Phantasma multiplier: compounds over the floors that remain
    [295071] = true,  -- Phantasma multiplier: compounds over the floors that remain
    [316850] = true,  -- Phantasma multiplier: compounds over the floors that remain
    [340692] = true,  -- Phantasma multiplier: compounds over the floors that remain
    [340691] = true,  -- Phantasma multiplier: compounds over the floors that remain
}

-- How much a per-floor power loses per floor already climbed. Deliberately mild and capped —
-- the direction is certain (fewer floors left is worth less) but the exact slope is not, and a
-- wing's total floor count varies by JailersTowerType, which we do not track.
-- ponytail: flat slope. Use the wing's real floor count if JailersTowerType is ever wired in.
AnimaPowerDB.PER_FLOOR_DECAY = 3
AnimaPowerDB.PER_FLOOR_DECAY_MAX = 18

-- ============================================================
-- Drawbacks that are priced in, per mode
-- ============================================================
-- A stated drawback normally vetoes a power outright, and that is right for a trap. It is wrong
-- for a BARGAIN: Fractured Phantasma Lure trades 10% of your damage for a large Phantasma gain,
-- which is a bad deal while clearing and the best deal on the board while farming, since
-- Phantasma is what a farming run is FOR.
--
-- Listing a power here waives both the blocklist and the description veto, but ONLY in the named
-- mode and ONLY if it also carries a curated score for that mode. Needing both means a mis-keyed
-- entry cannot quietly switch a trap back on.
AnimaPowerDB.DRAWBACK_ACCEPTED = {
    [337750] = "farming",  -- Fractured Phantasma Lure: -10% damage for a large Phantasma gain
}

-- ============================================================
-- Movement powers, derived from SpellEffect
-- ============================================================
-- The one category SpellEffect classifies cleanly. Measured against 268 powers whose
-- descriptions state their category unambiguously, these auras were 100% movement:
--     Effect 6 (APPLY_AURA) with EffectAura 10, 31, 33, 56, 129, 171, 293
-- Damage and survivability are NOT separable this way — the highest-volume signature,
-- Effect 6 / Aura 4, covers 78 powers split 18/26/34 across all three categories. So this
-- list stops at movement rather than pretending to be a general classifier.
--
-- Why it earns its place: movement is the top of the farming scale (the two 95s are both
-- movement), and the English patterns that previously had to spot it were four fragile lines.
-- This is locale-proof and generated. Negative magnitudes are excluded — the same aura with a
-- negative value is a SLOW, which is a trap, not a movement power.
--
-- Generated by tools/gen_movement_powers.py. Uncurated entries only: a curated score always wins.
AnimaPowerDB.MOVEMENT = {
    [296146] = true,  -- Know Mortality
    [304993] = true,  -- Deep Burns
    [305007] = true,  -- Scroll of Elchaver
    [305284] = true,  -- Glasswing Charm
    [306604] = true,  -- Boots of Bellaton
    [312606] = true,  -- Satchel of the Hunt
    [312841] = true,  -- Anamnestic Memories
    [315315] = true,  -- Spectral Bridle
    [321928] = true,  -- Hematoma Bat
    [322136] = true,  -- Dissolving Vial
    [324917] = true,  -- Fleetwing
    [326486] = true,  -- Mark of the Ogre
    [331297] = true,  -- Forsworn Feather
    [331825] = true,  -- Whirling Stormgem
    [332876] = true,  -- Languishing Soul Detritus
    [333119] = true,  -- Unending Thirst
    [333510] = true,  -- Surefoot Grease
    [334336] = true,  -- Trample
    [338928] = true,  -- Soul Empowerment
    [340180] = true,  -- Vial of Unbridled Darkness
    [340182] = true,  -- Vial of Unbridled Darkness
    [340435] = true,  -- Flask of Unbridled Darkness
    [340438] = true,  -- Flask of Unbridled Darkness
    [341375] = true,  -- Uncontrolled Darkness
    [341576] = true,  -- Howling Soulcore
    [341602] = true,  -- Chorus of Dead Souls
    [341783] = true,  -- Incorporeal Weave
    [341799] = true,  -- Brand of Instability
    [343825] = true,  -- Scales of Order
    [345871] = true,  -- Half-Giant Empowerment
    [348040] = true,  -- Negation Well
    [353745] = true,  -- Soul Empowerment
    [354757] = true,  -- Empowered
    [356855] = true,  -- Soul Empowerment
    [356920] = true,  -- Glasswing Charm
    [356922] = true,  -- Negation Well
    [363739] = true,  -- Cosmic Alacrity
    [363996] = true,  -- Cosmic Tremor
}

JustQuest.Database.AnimaPowerDB = AnimaPowerDB

return AnimaPowerDB
