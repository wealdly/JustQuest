-- Verifies the gossip traverse decision table in Engines/GossipEngine.lua — which branch runs,
-- and how many passes.
--
-- This exists because a real bug lived here: `concluded` (the conversation already dead-ended)
-- diverted to the stand-down branch, whose own comment claimed "a pure vendor/trainer still
-- fires". It could not — that branch requires the WHOLE menu to be a single option, and a
-- vendor beside two lines of flavor never is. Worse, it was self-reinforcing: probing the
-- flavor dead-ends the conversation, which sets `concluded`, which then blocked the vendor on
-- every later click at that target. Nothing failed loudly; the vendor just never opened.
--
-- Pure Lua, no WoW APIs. Run with any Lua 5.1+:
--     lua tools/gossip_traverse_check.lua
-- or, matching the syntax checker's interpreter:
--     python -c "import lupa.lua54 as l; l.LuaRuntime().execute(open('tools/gossip_traverse_check.lua').read())"

local failures = 0
local function check(name, got, want)
    if got ~= want then
        print(string.format("FAIL %s: got %s, want %s", name, tostring(got), tostring(want)))
        failures = failures + 1
    end
end

-- Grouped inside an instance: the chatter probe stands down there, because the lone
-- non-service option on a dungeon or raid NPC is routinely the one that starts an encounter.
-- Both halves matter — solo legacy farming keeps the full traverse.
local function GroupedInstance(s)
    return (s.inInstance and s.inGroup) and true or false
end

-- Exactly the branch condition and pass count used by HandleGossip.
-- Returns "traverse", passes  |  "standdown", 0
local function Decide(s)
    if s.aggressive and not s.forceGossip and not s.hasUnsafeOption then
        return "traverse", ((s.revisited or s.concluded or GroupedInstance(s)) and 1 or 2)
    end
    return "standdown", 0
end

-- The stand-down branch's own guard, for the cases that reach it.
local function StandDownFires(s)
    return s.availableCount == 1 and s.firstIsService and not s.npcHasQuests and not s.forceGossip
end

local A = { aggressive = true }
local function with(t)
    local s = {}
    for k, v in pairs(A) do s[k] = v end
    for k, v in pairs(t) do s[k] = v end
    return s
end

-- === The reported bug: chatty vendor, conversation already dead-ended ==============
-- Two flavor lines plus a vendor. Services MUST still be reachable.
local chattyVendor = with({ concluded = true, availableCount = 3, firstIsService = false })
local branch, passes = Decide(chattyVendor)
check("concluded menu still traverses", branch, "traverse")
check("concluded runs the SERVICE pass", passes >= 1, true)
check("concluded retires the chatter probe", passes, 1)
-- And the proof the old routing was broken: the stand-down branch could never have helped.
check("stand-down cannot fire on a multi-option menu", StandDownFires(chattyVendor), false)

-- === The chatter probe is still bounded ===========================================
check("fresh menu probes chatter once", select(2, Decide(with({}))), 2)
check("revisited menu retires the probe", select(2, Decide(with({ revisited = true }))), 1)
check("revisited AND concluded still runs services",
      select(2, Decide(with({ revisited = true, concluded = true }))), 1)

-- === Grouped inside an instance: no chatter probe =================================
-- A dungeon/raid NPC's one non-service option is as likely to be "we are ready" as it is to
-- be flavor, and clicking it pulls a boss for four people who clicked nothing.
check("grouped in an instance retires the chatter probe",
      select(2, Decide(with({ inInstance = true, inGroup = true }))), 1)
-- ...but services (pass 1) must still fire: a vendor inside an instance is why you clicked.
check("grouped in an instance still runs the SERVICE pass",
      select(2, Decide(with({ inInstance = true, inGroup = true }))) >= 1, true)
-- Both halves are required. Soloing legacy raids is where the traverse earns its keep.
check("solo in an instance still probes chatter",
      select(2, Decide(with({ inInstance = true, inGroup = false }))), 2)
check("grouped in the open world still probes chatter",
      select(2, Decide(with({ inInstance = false, inGroup = true }))), 2)
-- Quest-flagged and whitelisted options never reach this decision at all (priorities 1-2 run
-- above it), so a gossip-buried quest inside a dungeon is still taken.

-- === Stand-down still owns the cases it should ====================================
-- ForceGossip is the server saying "show the player" — never auto-advance past it.
check("forced menu stands down", (Decide(with({ forceGossip = true }))), "standdown")
check("forced menu never auto-selects even a lone service",
      StandDownFires({ availableCount = 1, firstIsService = true, forceGossip = true }), false)
-- A menu holding a travel/commitment option is a real decision; taking some OTHER option
-- answers it by omission.
check("unsafe menu stands down", (Decide(with({ hasUnsafeOption = true }))), "standdown")
-- Conservative mode never traverses at all.
check("conservative mode stands down", (Decide({ aggressive = false })), "standdown")
-- Blizzard-exact single service step still works where it applies.
check("lone service fires on stand-down",
      StandDownFires({ availableCount = 1, firstIsService = true }), true)
check("lone service withheld when the NPC has quests",
      StandDownFires({ availableCount = 1, firstIsService = true, npcHasQuests = true }), false)

-- === Precedence: the dangerous combinations ======================================
-- Unsafe/forced must win over concluded, not the other way round.
check("concluded does not re-enable traverse on an unsafe menu",
      (Decide(with({ concluded = true, hasUnsafeOption = true }))), "standdown")
check("concluded does not re-enable traverse on a forced menu",
      (Decide(with({ concluded = true, forceGossip = true }))), "standdown")

if failures > 0 then
    print(failures .. " FAILURES")
    os.exit(1)
end
print("gossip traverse check: clean")
