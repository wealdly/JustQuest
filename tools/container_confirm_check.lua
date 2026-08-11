-- Verifies the container engine's open-confirmation, which is the one thing standing between
-- "we opened it" and "we said so". C_Container.UseContainerItem() returns success even when the
-- server refused, so the ONLY evidence of an open is the item being consumed. Get this wrong in
-- the permissive direction and a lockbox reports an open on every scan, forever, while re-arming
-- its own retry budget each time — which is exactly the bug this replaced.
--
-- Pure Lua, no WoW APIs, no framework. Run with any Lua 5.1+:
--     lua tools/container_confirm_check.lua
-- or, matching the syntax checker's interpreter:
--     python -c "import lupa.lua54 as l; l.LuaRuntime().execute(open('tools/container_confirm_check.lua').read())"

local failures = 0
local function check(name, got, want)
    if got ~= want then
        print(string.format("FAIL %s: got %s, want %s", name, tostring(got), tostring(want)))
        failures = failures + 1
    end
end

local CONTAINER_MAX_RETRIES = 3  -- mirrors Constants.LIMITS.CONTAINER_MAX_RETRIES

-- Exactly the predicate from ContainerEngine.IsOpenConfirmed.
local function IsOpenConfirmed(pending, info)
    if not pending then return false end
    return (not info)
        or info.itemID ~= pending.itemID
        or info.stackCount < pending.stackCount
end

-- A box we used, recorded as one Battered Chest sitting in bag 0 slot 1.
local function pendingOne() return { itemID = 4632, stackCount = 1 } end

check("slot emptied is an open",        IsOpenConfirmed(pendingOne(), nil), true)
check("different item is an open",      IsOpenConfirmed(pendingOne(), { itemID = 999, stackCount = 1 }), true)

-- THE lockbox case: the call "succeeded", the box is untouched. Must not count.
check("untouched item is NOT an open",  IsOpenConfirmed(pendingOne(), { itemID = 4632, stackCount = 1 }), false)

-- Our own UseContainerItem fires ITEM_LOCK_CHANGED with the item still present and merely
-- locked. Resolving on that would count every refused open.
check("transient lock is NOT an open",  IsOpenConfirmed(pendingOne(), { itemID = 4632, stackCount = 1, isLocked = true }), false)

-- One taken from a stack: the item is still in the slot, so consumption only shows in the count.
local stackOfThree = { itemID = 4632, stackCount = 3 }
check("stack 3->2 is an open",          IsOpenConfirmed(stackOfThree, { itemID = 4632, stackCount = 2 }), true)
check("stack 3->3 is NOT an open",      IsOpenConfirmed(stackOfThree, { itemID = 4632, stackCount = 3 }), false)
-- Looting more of the same item while an open is in flight must not read as consumption.
check("stack 3->5 is NOT an open",      IsOpenConfirmed(stackOfThree, { itemID = 4632, stackCount = 5 }), false)

check("no pending is never an open",    IsOpenConfirmed(nil, nil), false)

-- ResolvePending's split: only a confirmed open credits the summary; anything else charges a
-- retry. This is what eventually leaves an unopenable box alone instead of retrying it forever.
local function Resolve(state, opened)
    if opened then
        state.retryCount = 0
        state.reported = state.reported + 1
    else
        state.retryCount = state.retryCount + 1
    end
end
local function MayRetry(state) return state.retryCount < CONTAINER_MAX_RETRIES end

-- A lockbox: every attempt "succeeds" at the API and changes nothing.
local box = { retryCount = 0, reported = 0 }
local attempts = 0
while MayRetry(box) and attempts < 50 do
    attempts = attempts + 1
    Resolve(box, IsOpenConfirmed(pendingOne(), { itemID = 4632, stackCount = 1 }))
end
check("lockbox is never reported open", box.reported, 0)
check("lockbox stops after max retries", attempts, CONTAINER_MAX_RETRIES)

-- A real container: opens first try, reported once, retry budget stays clean.
local chest = { retryCount = 0, reported = 0 }
Resolve(chest, IsOpenConfirmed(pendingOne(), nil))
check("real container reported once",   chest.reported, 1)
check("real container keeps budget",    MayRetry(chest), true)

if failures == 0 then
    print("container confirm checks: all passed")
else
    print(string.format("container confirm checks: %d FAILED", failures))
    os.exit(1)
end
