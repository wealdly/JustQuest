-- Verifies the anima power scorer against the REAL curated data in
-- Database/AnimaPowerDB.lua — 324 hand-scored entries and ~90 ordered patterns, where a
-- transcription slip or a reordered pattern group fails silently: you don't get an error,
-- you get a worse pick, or a trap power taken.
--
-- The three invariants that actually matter:
--   1. BLOCKED returns nil, never 0. They are different answers — 0 means "unrecognised"
--      (recoverable: reroll or hand back), nil means "known to be harmful" (never take).
--   2. Penalties win pattern precedence. "cooldown reduced, but you take more damage" must
--      resolve to blocked, not to the damage score its first clause earns.
--   3. The two modes are genuinely different value systems, not one list times a constant.
--
-- Pure Lua, no WoW APIs, no framework. Run with any Lua 5.1+:
--     lua tools/anima_logic_check.lua
-- or, matching the syntax checker's interpreter:
--     python -c "import lupa.lua54 as l; l.LuaRuntime().execute(open('tools/anima_logic_check.lua').read())"

local failures = 0
local function check(name, got, want)
    if got ~= want then
        print(string.format("FAIL %s: got %s, want %s", name, tostring(got), tostring(want)))
        failures = failures + 1
    end
end

-- Load the real data file. It takes (ADDON_NAME, JustQuest) as varargs and hangs itself off
-- JustQuest.Database, exactly as the .toc loads it.
local JustQuest = {}
local path = "Database/AnimaPowerDB.lua"
local chunk = assert(loadfile(path), "cannot load " .. path .. " (run from the addon root)")
chunk("JustQuest", JustQuest)
local db = assert(JustQuest.Database and JustQuest.Database.AnimaPowerDB, "DB did not register")

-- Exactly the scan order and semantics used by ScoreOption in Engines/DelveEngine.lua.
local PATTERN_ORDER = {
    "penalties", "high_value", "movement", "phantasma", "aoe",
    "damage", "utility", "survivability", "crowdcontrol", "low_value",
}

local DRAWBACK_WORDS = {
    "reduc", "decreas", "lower", "less", "lose", "lost", "cannot", "no longer",
    "unable", "prevent", "suffer", "slow", "die", "kill you",
}
local function HasDrawbackClause(text)
    for _, lead in ipairs({ "but", "however" }) do
        local at = 1
        while true do
            local s, e = text:find(lead, at, true)
            if not s then break end
            local before = (s > 1) and text:sub(s - 1, s - 1) or " "
            if before:find("%A") and (text:sub(e + 1, e + 1)):find("%A") then
                local clause = text:sub(e + 1, e + 160)
                for _, w in ipairs(DRAWBACK_WORDS) do
                    if clause:find(w, 1, true) then return true end
                end
            end
            at = e + 1
        end
    end
    return false
end

-- Read from the DB, never copied. A local copy of these drifted out of sync with the engine
-- once and the whole rarity section went on passing against numbers nothing used any more.
local RARITY_SCORE = assert(db.RARITY_SCORE, "RARITY_SCORE missing from AnimaPowerDB")
local POWER_TYPE   = assert(db.POWER_TYPE,   "POWER_TYPE missing from AnimaPowerDB")
local TYPE_BONUS   = assert(db.TYPE_BONUS,   "TYPE_BONUS missing from AnimaPowerDB")

local function ScoreOption(option, mode, floorNum)
    floorNum = floorNum or 1
    local bands = (mode == "farming") and db.BANDS.FARMING or db.BANDS.NORMAL
    local text = string.lower((option.header or "") .. " " .. (option.description or ""))

    -- A drawback priced in for THIS mode waives both vetoes; needs an explicit listing and a
    -- curated score for the mode.
    local accepted = false
    if option.spellID and db.DRAWBACK_ACCEPTED and db.DRAWBACK_ACCEPTED[option.spellID] == mode then
        local ms = (mode == "farming") and db.SCORES_FARMING or db.SCORES_NORMAL
        if ms and ms[option.spellID] and ms[option.spellID].priority then accepted = true end
    end

    -- Penalties before any score, curated or not.
    if not accepted and HasDrawbackClause(text) then return nil end
    if not accepted then
        for i = 1, #db.PATTERNS.penalties do
            if string.find(text, db.PATTERNS.penalties[i][1]) then return nil end
        end
    end

    local spellID = option.spellID  -- spellID only; option.id is 0 on every real option
    if spellID then
        if (not accepted) and db.BLOCKED[spellID] then return nil end
        local scores = (mode == "farming") and db.SCORES_FARMING or db.SCORES_NORMAL
        local curated = scores and scores[spellID]
        if curated and curated.priority then
            if db.PER_FLOOR and db.PER_FLOOR[spellID] and floorNum > 1 then
                local decay = math.min((floorNum - 1) * (db.PER_FLOOR_DECAY or 3),
                                       db.PER_FLOOR_DECAY_MAX or 18)
                return math.max(1, curated.priority - decay)
            end
            return curated.priority
        end
        -- Curated for the other mode only: floor, not the other mode's number.
        local other = (mode == "farming") and db.SCORES_NORMAL or db.SCORES_FARMING
        local elsewhere = other and other[spellID]
        if elsewhere and elsewhere.priority then return bands.IGNORE_BELOW end
    end

    if spellID and db.MOVEMENT and db.MOVEMENT[spellID] then
        return bands.MOVEMENT_GOOD or 70
    end

    for _, group in ipairs(PATTERN_ORDER) do
        if group ~= "penalties" then
            local list = db.PATTERNS[group]
            if list then
                for i = 1, #list do
                    if string.find(text, list[i][1]) then
                        if list[i][2] == "BLACKLISTED" then return nil end
                        return bands[list[i][2]] or 0
                    end
                end
            end
        end
    end
    if option.rarity and RARITY_SCORE[option.rarity] then
        local kind = option.typeArtID and POWER_TYPE[option.typeArtID]
        local bonus = kind and (TYPE_BONUS[mode] or TYPE_BONUS.normal)[kind] or 0
        return RARITY_SCORE[option.rarity] + bonus
    end
    return 0
end

-- === 1. Blocked powers are nil, not zero ==========================================
-- Elethium Weights prevents jumping, which strands you on Torghast terrain.
check("blocked returns nil (normal)",  ScoreOption({ spellID = 319041 }, "normal"),  nil)
check("blocked returns nil (farming)", ScoreOption({ spellID = 319041 }, "farming"), nil)
check("blocked beats a curated score", ScoreOption({ spellID = 329960 }, "normal"),  nil)

-- An unrecognised power scores 0 — distinct from nil, and below every floor.
check("unknown scores zero", ScoreOption({ spellID = 999999, header = "Mystery" }, "normal"), 0)

-- === 2. Pattern precedence: penalties are scanned first ============================
-- Reads as a buff first and a drawback second. The drawback has to win.
local mixed = { header = "Test", description = "Cooldown reduced 50 sec, but you take 10% more damage" }
check("penalty clause beats the buff clause", ScoreOption(mixed, "normal"), nil)

-- A clean penalty with no redeeming clause.
check("plain penalty blocked", ScoreOption({ description = "Movement speed reduced by 10%" }, "normal"), nil)

-- A clean positive still scores through the fallback.
local speedy = { description = "Your movement speed is increased" }
check("positive pattern scores", ScoreOption(speedy, "normal"), db.BANDS.NORMAL.MOVEMENT_GOOD)

-- THE ORDERING INVARIANT: a stated penalty outranks a curated score. This is what contains a
-- mis-keyed curated entry — 329580 is scored 95, the highest band there is, and it must still
-- be refused when the description on screen says the power is harmful. If this ever regresses,
-- a wrong table entry silently becomes a taken trap.
local poisoned = { spellID = 329580, description = "Your movement speed is reduced by 10%" }
check("curated 95 does not survive a penalty description", ScoreOption(poisoned, "normal"), nil)
check("...and not in farming either",                      ScoreOption(poisoned, "farming"), nil)
-- Same power, clean description: the curated score still applies.
check("curated score intact without a penalty", ScoreOption({ spellID = 329580 }, "normal"), 95)

-- === 3b. Regressions the pattern audit caught, verbatim ============================
-- Real text of Smuggled Wildseed (curated 90). The COOLDOWN is reduced, not the speed — an
-- unbounded "movement speed.*reduced" pattern matched across the clause and vetoed it.
local wildseed = { spellID = 342789,
    description = "Soulshape increases your movement speed by an additional 50%, and its cooldown is reduced by 30 sec." }
check("a reduced COOLDOWN is not a speed penalty", ScoreOption(wildseed, "normal"), 90)

-- Real text that a bare "cannot" match vetoed. These are caveats and clarifications, not drawbacks.
check("'damage cannot exceed' is not a drawback",
      ScoreOption({ description = "Healing empowers your next spell. Stored damage cannot exceed 20% of your maximum health." }, "normal") ~= nil, true)
check("'cannot break' is not a drawback",
      ScoreOption({ description = "Enemies suffer damage every 2 sec. This damage cannot break Psychic Scream." }, "normal") ~= nil, true)

-- ...but a real trailing drawback clause still blocks, which is what those patterns were for.
check("'but ... reduced' blocks",
      ScoreOption({ description = "Your abilities cool down 15% faster, but your Physical damage is reduced by 25%." }, "normal"), nil)
check("'but ... causes players to die' blocks",
      ScoreOption({ description = "Time Warp lasts 100% longer, but causes all affected players to die at the end." }, "normal"), nil)
check("'but also decreases' blocks",
      ScoreOption({ description = "Increases Phantasma earned by 50%, but also decreases damage done by 10%." }, "normal"), nil)
-- Word-boundary guard: "but" inside another word must not trigger the clause scan.
check("'attribute' does not read as a drawback clause",
      ScoreOption({ description = "Redistribute 10% of your attributes. You lose nothing." }, "normal") ~= nil, true)

-- === 3c. Rarity fallback ==========================================================
-- Uncurated, unmatched powers used to score 0 and be handed back — measurement said that was
-- ~74% of all powers. Rarity is the server's own tier and must sit below every curated score.
local blank = "Grants an unremarkable effect of no describable kind."
-- MEASURED: rarity does NOT track power quality (correlation +0.18 clearing, -0.14 farming;
-- Common powers average ~70 curated). So the ladder is deliberately flat and must NOT decide
-- on its own — every non-Epic tier sits within a few points of the floor, leaving the call to
-- type. Asserting the flatness directly, because the old numbers encoded the wrong assumption
-- and nothing caught it.
local floorN = db.BANDS.NORMAL.IGNORE_BELOW
for _, r in ipairs({ 0, 1, 2 }) do
    local s = ScoreOption({ spellID = 999000 + r, description = blank, rarity = r }, "normal")
    check("rarity " .. r .. " lands near the floor, deciding nothing alone",
          math.abs(s - floorN) <= 4, true)
end
check("Epic clears the floor on its own",
      ScoreOption({ spellID = 999004, description = blank, rarity = 3 }, "normal") > floorN, true)
check("the ladder is monotonic but compressed",
      (RARITY_SCORE[3] - RARITY_SCORE[0]) <= 20 and RARITY_SCORE[3] > RARITY_SCORE[0], true)
check("no rarity, nothing matched -> 0", ScoreOption({ spellID = 999005, description = blank }, "normal"), 0)
-- Rarity must never outrank curation, and must never rescue a blocked power.
check("curated beats rarity",  ScoreOption({ spellID = 329580, rarity = 3 }, "normal"), 95)
check("blocked beats rarity",  ScoreOption({ spellID = 319041, rarity = 3 }, "normal"), nil)

-- === 3c2. Curated in one mode only =================================================
-- 59 entries exist in one score table and not the other. Dropping those to the rarity fallback
-- threw away real judgment for a guess — that guess is what scored a known-good buff 46 and
-- handed it back. They must be TAKEN, but must not outrank anything judged for the active mode.
local phantasma = 295067  -- farming 88, no normal entry
check("one-mode power is taken in the other mode",
      ScoreOption({ spellID = phantasma }, "normal") >= db.BANDS.NORMAL.IGNORE_BELOW, true)
check("...at the floor, not at the other mode's number",
      ScoreOption({ spellID = phantasma }, "normal"), db.BANDS.NORMAL.IGNORE_BELOW)
check("...so a power judged FOR this mode still wins",
      ScoreOption({ spellID = 329580 }, "normal") > ScoreOption({ spellID = phantasma }, "normal"), true)
-- Its own mode keeps the real figure.
check("its own mode is unaffected", ScoreOption({ spellID = phantasma }, "farming"),
      db.SCORES_FARMING[phantasma].priority)
-- A blocked power must never be rescued by the other table.
check("blocked still beats the cross-mode fallback",
      ScoreOption({ spellID = 319041 }, "farming"), nil)

-- === 3c3. The floor governs rerolling, not handing back ===========================
-- A Torghast power window must be answered to carry on, so refusing to pick does not spare the
-- player a decision — it makes them click through options we already ranked. Handing back is
-- reserved for the case where every option is BLOCKED, which is a genuine "which harm do I
-- accept" choice. Mirrors AcceptScoredPower.
local function WouldTake(opts)  -- the floor deliberately plays no part here
    -- Each entry is { score = n } or { blocked = true }; a sparse array of scores would make
    -- ipairs stop at the first nil, which is a property of Lua tables and not of the engine
    -- (BestOption walks option TABLES and scores each one).
    local best, blockedCount = nil, 0
    for _, o in ipairs(opts) do
        if o.blocked then blockedCount = blockedCount + 1
        elseif not best or o.score > best then best = o.score end
    end
    if not best then return nil, blockedCount end   -- everything blocked -> hand back
    return best, blockedCount                        -- a safe option exists -> take it, floor or not
end

local B = { blocked = true }
check("a safe option under the floor is still taken", (WouldTake({ {score=44}, {score=46} })), 46)
check("the best safe option wins even when all are low", (WouldTake({ {score=20}, {score=44}, {score=31} })), 44)
check("all-blocked hands back", (WouldTake({ B, B })), nil)
check("a safe option beats blocked siblings", (WouldTake({ B, {score=44}, B })), 44)
-- And the blocklist is what actually protects: a blocked power can never be "best".
check("blocked never becomes the pick",
      ScoreOption({ spellID = 319041, description = blank, rarity = 3, typeArtID = 3446882 }, "farming"), nil)

-- === 3c4. Per-floor powers decay as the run goes on ===============================
-- A power that pays out each floor is worth what REMAINS of the run. JAILERS_TOWER_LEVEL_UPDATE
-- gives the current floor; static scoring rated these identically on floor 1 and floor 8.
local perFloor = 348541  -- Refilling Elixir of Life: heal to full, once per floor
local base = ScoreOption({ spellID = perFloor }, "normal", 1)
check("floor 1 is the undiscounted score", base, db.SCORES_NORMAL[perFloor].priority)
check("a later floor is worth less", ScoreOption({ spellID = perFloor }, "normal", 5) < base, true)
check("the discount is capped", ScoreOption({ spellID = perFloor }, "normal", 99),
      base - db.PER_FLOOR_DECAY_MAX)
-- An ordinary power is unaffected by the floor.
local flat = 329580
check("a non-per-floor power ignores the floor",
      ScoreOption({ spellID = flat }, "normal", 9), ScoreOption({ spellID = flat }, "normal", 1))
-- Unknown floor must behave exactly as before the floor was tracked.
check("unknown floor defaults to no discount", ScoreOption({ spellID = perFloor }, "normal"), base)

-- === 3c5. Priced-in drawbacks, per mode ===========================================
-- Fractured Phantasma Lure trades 10% damage for a large Phantasma gain. That is a bad deal
-- while clearing and the best on the board while farming, because Phantasma is what a farming
-- run is FOR. It waives the blocklist and the description veto in FARMING ONLY.
local lure = 337750
local lureDesc = "Increases Phantasma earned by 50%, but also decreases damage done by 10%."
check("the lure is taken while farming",
      ScoreOption({ spellID = lure, description = lureDesc }, "farming") ~= nil, true)
check("...and is still refused while clearing",
      ScoreOption({ spellID = lure, description = lureDesc }, "normal"), nil)
-- The waiver is narrow: it must not generalise to other traps, in either mode.
check("a real trap is unaffected by the waiver (farming)",
      ScoreOption({ spellID = 319041, description = "you are no longer able to jump" }, "farming"), nil)
check("a real trap is unaffected by the waiver (clearing)",
      ScoreOption({ spellID = 319041 }, "normal"), nil)
-- And it cannot fire for a power with no curated score in that mode.
check("waiver needs a curated score for the mode",
      ScoreOption({ spellID = 999777, description = lureDesc }, "farming"), nil)

-- === 3c6. SpellEffect-derived movement =============================================
-- The one category SpellEffect classifies cleanly (100% pure across 268 description-labelled
-- powers). Generated, so locale-proof — unlike the four English movement patterns. It must rank
-- an uncurated movement power well, but never outrank a curated judgment or rescue a trap.
local moveID = next(db.MOVEMENT)
check("MOVEMENT set is populated", moveID ~= nil, true)
if moveID then
    check("an uncurated movement power scores the movement band",
          ScoreOption({ spellID = moveID, description = blank }, "farming"), db.BANDS.FARMING.MOVEMENT_GOOD)
    check("...and clears the floor", ScoreOption({ spellID = moveID, description = blank }, "farming")
          >= db.BANDS.FARMING.IGNORE_BELOW, true)
    check("the generated set never contains a curated power", db.SCORES_FARMING[moveID], nil)
end
-- A curated score still wins, and a trap is still a trap.
check("curated beats the generated movement band", ScoreOption({ spellID = 329580 }, "farming"), 95)
check("a blocked power is not rescued by the movement set",
      ScoreOption({ spellID = 319041 }, "farming"), nil)

-- === 3d. Power type (option.typeArtID) ============================================
-- Blizzard's own three-way classification, shipped as the TypeIcon texture. The whole point is
-- that the SAME uncurated power is worth different amounts in the two modes.
local OFFENSE, DEFENSE, UTILITY = 3446882, 3446881, 3446883
local function uncurated(art, rarity)
    return { spellID = 999100 + (art % 10), description = blank, rarity = rarity, typeArtID = art }
end
check("offense scores higher when clearing than when farming",
      ScoreOption(uncurated(OFFENSE, 2), "normal") > ScoreOption(uncurated(OFFENSE, 2), "farming"), true)
check("utility scores higher when farming than when clearing",
      ScoreOption(uncurated(UTILITY, 2), "farming") > ScoreOption(uncurated(UTILITY, 2), "normal"), true)
-- A Rare utility power clears the farming floor but not the clearing floor: the mode decides.
check("rare utility taken when farming",
      ScoreOption(uncurated(UTILITY, 2), "farming") >= db.BANDS.FARMING.IGNORE_BELOW, true)
check("rare utility handed back when clearing",
      ScoreOption(uncurated(UTILITY, 2), "normal") < db.BANDS.NORMAL.IGNORE_BELOW, true)
check("defense is worth more when clearing than when farming",
      ScoreOption(uncurated(DEFENSE, 2), "normal") > ScoreOption(uncurated(DEFENSE, 2), "farming"), true)
-- Type is now the thing that decides. A Common OFFENSE power is taken while clearing — which
-- is intended, and was measured: Common powers average ~70 curated, so refusing them on rarity
-- alone (the old behaviour) was throwing away good powers.
check("common offense is taken when clearing",
      ScoreOption(uncurated(OFFENSE, 0), "normal") >= db.BANDS.NORMAL.IGNORE_BELOW, true)
check("...but the same power is refused when farming",
      ScoreOption(uncurated(OFFENSE, 0), "farming") < db.BANDS.FARMING.IGNORE_BELOW, true)
check("curated beats type+rarity",
      ScoreOption({ spellID = 329580, rarity = 3, typeArtID = UTILITY }, "farming"), 95)
check("blocked beats type+rarity",
      ScoreOption({ spellID = 319041, rarity = 3, typeArtID = OFFENSE }, "normal"), nil)
-- === 3e. option.id is never a key ==================================================
-- A live probe shows option.id is 0 on every option, so it identifies nothing. Feeding it into
-- the curated lookup could only ever produce a bogus [0] hit; a real option carries spellID.
check("option.id is ignored, not used as a lookup key",
      ScoreOption({ id = 0, description = blank, rarity = 2, typeArtID = UTILITY }, "farming"),
      RARITY_SCORE[2] + TYPE_BONUS.farming.utility)
-- Guard the degenerate case directly: were a [0] entry ever added, it must not be reachable.
check("a spellID-less option never resolves to a curated score",
      ScoreOption({ id = 0, description = blank }, "normal"), 0)

-- An unrecognised typeArtID must contribute nothing rather than be guessed at.
check("unknown typeArtID falls back to plain rarity",
      ScoreOption({ spellID = 999200, description = blank, rarity = 2, typeArtID = 1 }, "normal"), 52)

-- === 3. The modes disagree, and that is the point ==================================
-- Same power, different worth: Farming values the speed compounding more than Clearing does.
check("curated normal",  ScoreOption({ spellID = 342789 }, "normal"),  90)
check("curated farming", ScoreOption({ spellID = 342789 }, "farming"), 92)
check("modes differ on the same power",
      ScoreOption({ spellID = 342789 }, "normal") ~= ScoreOption({ spellID = 342789 }, "farming"), true)

-- Phantasma is worth far more when farming than when clearing — the clearest mode signal.
local phant = db.BANDS.FARMING.PHANTASMA_EXCELLENT > db.BANDS.NORMAL.PHANTASMA_EXCELLENT
check("farming values phantasma higher", phant, true)
-- ...and survivability far less.
local surv = db.BANDS.FARMING.SURVIVABILITY_EXCELLENT < db.BANDS.NORMAL.SURVIVABILITY_EXCELLENT
check("farming values survivability lower", surv, true)

-- === 4. Floors exist and are sane ==================================================
for _, mode in ipairs({ "NORMAL", "FARMING" }) do
    local floor = db.BANDS[mode].IGNORE_BELOW
    check(mode .. " floor is set", type(floor) == "number" and floor > 0, true)
    -- A floor above every curated score would mean nothing is ever auto-taken.
    local best = 0
    local scores = (mode == "FARMING") and db.SCORES_FARMING or db.SCORES_NORMAL
    for _, e in pairs(scores) do
        if e.priority and e.priority > best then best = e.priority end
    end
    check(mode .. " floor is reachable", best >= floor, true)
end

-- === 5. Data integrity =============================================================
-- A power can't be both blocked and recommended; that would make the answer depend on
-- which table happened to be consulted first.
for id in pairs(db.BLOCKED) do
    -- A power listed in DRAWBACK_ACCEPTED is deliberately blocked AND scored: blocked so it is
    -- refused everywhere by default, scored so the waiver has a number to use in the one mode
    -- where the cost is priced in. Every OTHER blocked power must appear in neither table.
    local waived = db.DRAWBACK_ACCEPTED and db.DRAWBACK_ACCEPTED[id]
    if not waived then
        check("blocked " .. id .. " not also scored (normal)",  db.SCORES_NORMAL[id],  nil)
        check("blocked " .. id .. " not also scored (farming)", db.SCORES_FARMING[id], nil)
    else
        -- and the waiver must be scoped to exactly one mode
        local other = (waived == "farming") and db.SCORES_NORMAL or db.SCORES_FARMING
        check("waived " .. id .. " is scored only in its waived mode", other[id], nil)
    end
end

-- Every pattern must compile as a Lua pattern and every label must resolve to a band.
for group, list in pairs(db.PATTERNS) do
    for i = 1, #list do
        local pat, label = list[i][1], list[i][2]
        local ok = pcall(string.find, "probe text", pat)
        check(("pattern %s[%d] compiles"):format(group, i), ok, true)
        if label ~= "BLACKLISTED" then
            check(("label %s[%d]=%s resolves"):format(group, i, label),
                  db.BANDS.NORMAL[label] ~= nil, true)
        end
    end
end

local counts = 0
for _ in pairs(db.SCORES_NORMAL) do counts = counts + 1 end
print(string.format("checked %d normal / %d blocked entries",
      counts, (function() local n = 0 for _ in pairs(db.BLOCKED) do n = n + 1 end return n end)()))

if failures > 0 then
    print(failures .. " FAILURES")
    os.exit(1)
end
print("anima logic check: clean")
