# JustQuest Style Guide - AI Reference

**Version:** 1.0.0  
**Format:** AI-optimized for quick parsing and rule extraction  
**Human Version:** See STYLE_GUIDE.md

---

## Priority Levels

- **MUST** - Critical rules, violations break functionality or cause conflicts
- **SHOULD** - Important conventions, follow unless there's good reason
- **MAY** - Optional guidelines, use for consistency

---

## Quick Rules Summary

### Critical (MUST)
```
✓ All variables MUST be local unless explicitly global
✓ MUST use single global namespace: JustQuest
✓ MUST use addon namespace pattern: local ADDON_NAME, JustQuest = ...
✓ MUST use 4 spaces for indentation (no tabs)
✓ MUST wrap WoW API calls that can fail in pcall()
✓ MUST use _G table for dynamic global access (not getglobal/setglobal)
✓ MUST document public API functions
```

### Important (SHOULD)
```
✓ Functions SHOULD be lowercase-started to avoid WoW API conflicts
✓ Constants SHOULD use UPPER_SNAKE_CASE
✓ Variables SHOULD use camelCase or snake_case (consistent per file)
✓ Modules SHOULD use PascalCase
✓ SHOULD return early to reduce nesting
✓ SHOULD use trailing commas in multi-line tables
✓ SHOULD cache repeated table lookups in locals
✓ SHOULD use ipairs() for arrays, pairs() for dictionaries
```

### Optional (MAY)
```
✓ MAY prefix private variables with underscore
✓ MAY use boolean prefixes (is/has/should/can)
✓ MAY use ternary-style and/or expressions for simple cases
```

---

## Namespace Rules

### Global Namespace
```lua
-- MUST: Single global table only
JustQuest = {}
_G.JustQuest = JustQuest

-- MUST NOT: Multiple globals
❌ JustQuestConfig = {}
❌ JustQuestUtils = {}
```

### Addon Namespace Pattern
```lua
-- MUST: Use at top of every .lua file
local ADDON_NAME, JustQuest = ...

-- SHOULD: Store module data in namespace
JustQuest.MyModule = {}
JustQuest.MyModule.data = value
```

### Variable Scope Priority
```
1. Block-local (inside do/if/for)
2. Function-local (inside functions)
3. File-local (top of file)
4. Module-local (in namespace table)
5. Global (avoid except root table)
```

---

## Naming Conventions

### Variables
```lua
-- SHOULD: camelCase or snake_case (consistent per file)
local questData = {}
local player_name = "Bob"

-- MUST: Constants in UPPER_SNAKE_CASE
local MAX_RETRIES = 3
local DEFAULT_TIMEOUT = 5.0

-- MAY: Prefix booleans
local isEnabled = true
local hasReward = false
local canProcess = true
```

### Functions
```lua
-- SHOULD: Lowercase start (avoid WoW API conflicts)
local function processQuest(questID)
local function validateData(data)

-- SHOULD: Module public API - PascalCase
function QuestEngine.ProcessQuest(questID)
function Services.SafeCall(func, ...)

-- SHOULD: Verb-based descriptive names
✓ processQuest()
✓ validateReward()
✓ isQuestComplete()

❌ quest()
❌ reward()
❌ complete()
```

### Modules/Tables
```lua
-- SHOULD: PascalCase for modules
local QuestEngine = {}
local RewardEngine = {}
local SafetyEngine = {}
```

---

## Formatting Rules

### Indentation
```lua
-- MUST: 4 spaces per level, no tabs
function myFunction()
    if condition then
        doSomething()
    end
end
```

### Spacing
```lua
-- MUST: Space after operators
local x = y + 5
local result = (a * b) / c

-- MUST: Space after commas
local t = {1, 2, 3}
myFunction(arg1, arg2, arg3)

-- MUST: Space around table braces
local config = { enabled = true }
local empty = {}

-- MUST NOT: Space between function name and parens
✓ myFunction(arg)
❌ myFunction (arg)
```

### Line Length
```
SHOULD: Soft limit 80-100 characters
MUST: Hard limit 120 characters
```

---

## File Structure

### Required Structure
```lua
-- ModuleName.lua
-- Brief description
-- Author: name | Version: X.Y.Z

local ADDON_NAME, JustQuest = ...

-- ============================================================
-- Module Definition
-- ============================================================

local ModuleName = {}

-- ============================================================
-- File-Local Variables
-- ============================================================

-- ============================================================
-- Private Helper Functions
-- ============================================================

-- ============================================================
-- Public API Functions
-- ============================================================

-- ============================================================
-- Initialization
-- ============================================================

function ModuleName.Initialize()
end

-- ============================================================
-- Module Registration
-- ============================================================

JustQuest.Core.RegisterModule("ModuleName", ModuleName, {"Deps"})

return ModuleName
```

---

## Function Patterns

### Early Returns
```lua
-- SHOULD: Return early to reduce nesting
function processQuest(questID)
    if not questID then return false end
    if not isValid(questID) then return false end
    if not canProcess() then return false end
    
    -- actual work
    return true
end

-- AVOID: Deep nesting
❌ function processQuest(questID)
    if questID then
        if isValid(questID) then
            if canProcess() then
                return true
            end
        end
    end
    return false
end
```

### Error Handling
```lua
-- SHOULD: Return nil + error for recoverable errors
function getQuestData(questID)
    if not questID then
        return nil, "Invalid quest ID"
    end
    return data
end

-- Usage
local data, err = getQuestData(questID)
if not data then
    handleError(err)
    return
end
```

### Parameter Count
```
SHOULD: 3 or fewer parameters
SHOULD: Use config table for complex parameters

✓ function create(config)
❌ function create(id, name, level, xp, gold, faction, zone, obj)
```

---

## Table Patterns

### Multi-line Tables
```lua
-- MUST: Trailing commas in multi-line tables
local config = {
    option1 = true,
    option2 = false,
    option3 = 42,  -- trailing comma required
}

-- SHOULD: Consistent formatting
local data = {
    id = 123,
    name = "Quest",
    rewards = {
        gold = 100,
        xp = 5000,
    },
}
```

### Table Access
```lua
-- SHOULD: Dot notation for known keys
local name = player.name

-- SHOULD: Bracket notation for dynamic keys
local key = "name"
local value = player[key]

-- AVOID: Bracket for known keys
❌ local name = player["name"]
```

---

## Control Structures

### Truthy Checks
```lua
-- SHOULD: Use truthy checks
if value then           -- value is not nil/false
if not value then       -- value is nil/false

-- ACCEPTABLE: Explicit when needed
if value == nil then    -- specifically nil
if value == false then  -- specifically false

-- AVOID: Redundant
❌ if value ~= nil then
```

### Complex Conditions
```lua
-- MUST: Parentheses for clarity
if (cond1 and cond2) or (cond3 and cond4) then
    doSomething()
end
```

### Loops
```lua
-- SHOULD: ipairs() for arrays (faster)
for i, value in ipairs(array) do
    process(value)
end

-- SHOULD: pairs() for dictionaries
for key, value in pairs(dict) do
    process(key, value)
end

-- SHOULD: Numeric for when appropriate
for i = 1, 10 do
    print(i)
end
```

---

## Comment Rules

### Style
```lua
-- MUST: Space after --
-- Good comment
--Bad comment (no space)
```

### Purpose
```
SHOULD: Comment WHY, not WHAT
SHOULD: Comment complex logic
SHOULD: Comment WoW API workarounds
MUST: Document public API functions
MUST NOT: Comment obvious code
MUST NOT: Comment Lua syntax
```

### Examples
```lua
-- GOOD: Explains WHY
-- Cache to avoid repeated API calls during combat
local playerName = UnitName("player")

-- GOOD: Documents workaround
-- WORKAROUND: API returns nil in 10.2.5, wrap in pcall
local success, result = pcall(C_QuestLog.GetQuestTagInfo, questID)

-- BAD: Obvious
❌ local playerName = UnitName("player")  -- Get player name
```

### Function Documentation
```lua
-- SHOULD: Document public API
-- Processes quest reward selection
-- @param questID number - Quest ID to process
-- @param rewardIndex number|nil - Optional reward index
-- @return boolean - True if successful
function RewardEngine.ProcessQuestReward(questID, rewardIndex)
```

---

## WoW-Specific Rules

### Frame Creation
```lua
-- SHOULD: Local frames (avoid globals)
local frame = CreateFrame("Frame")
frame:RegisterEvent("EVENT_NAME")

-- ACCEPTABLE: Named when needed by XML
local frame = CreateFrame("Frame", "MyAddonFrame")

-- MUST NOT: Implicit globals
❌ frame = CreateFrame("Frame")
```

### Event Handling
```lua
-- SHOULD: Use dispatcher pattern
local eventFrame = CreateFrame("Frame")
local handlers = {
    EVENT_ONE = function(...) end,
    EVENT_TWO = function(...) end,
}

eventFrame:SetScript("OnEvent", function(self, event, ...)
    local handler = handlers[event]
    if handler then handler(...) end
end)

for event in pairs(handlers) do
    eventFrame:RegisterEvent(event)
end
```

### API Safety
```lua
-- MUST: Wrap APIs that can fail
local success, result = pcall(C_QuestLog.GetQuestTagInfo, questID)
if success and result then
    -- use result
end

-- SHOULD: Provide fallbacks
local function safeGetQuestName(questID)
    local name = C_QuestLog.GetTitleForQuestID(questID)
    return name or "Unknown Quest"
end
```

### Dynamic Global Access
```lua
-- MUST: Use _G table (not deprecated functions)
✓ local frame = _G["PartyMemberFrame" .. i]

-- MUST NOT: Deprecated
❌ local frame = getglobal("PartyMemberFrame" .. i)
❌ setglobal("MyVar", value)
```

---

## Performance Rules

### Cache Lookups
```lua
-- SHOULD: Cache repeated table access
-- BAD
for i = 1, 1000 do
    JustQuest.Constants.TIMING.DELAY
end

-- GOOD
local timing = JustQuest.Constants.TIMING
for i = 1, 1000 do
    timing.DELAY
end
```

### Function Creation
```lua
-- AVOID: Creating functions in loops
❌ for i = 1, 100 do
    C_Timer.After(i, function() print(i) end)
end

-- BETTER: Reuse function
local function callback(n) print(n) end
for i = 1, 100 do
    C_Timer.After(i, function() callback(i) end)
end
```

### String Concatenation
```lua
-- AVOID: Repeated concatenation for many strings
❌ local result = ""
   for i = 1, 1000 do
       result = result .. tostring(i)
   end

-- SHOULD: Use table.concat
✓ local parts = {}
  for i = 1, 1000 do
      parts[i] = tostring(i)
  end
  local result = table.concat(parts, ", ")
```

---

## Common Anti-Patterns

### Avoid
```lua
❌ Global variables (except root table)
❌ Tabs for indentation
❌ Bracket notation for known keys: player["name"]
❌ Redundant nil checks: if x ~= nil then
❌ getglobal() / setglobal() (deprecated)
❌ Deep nesting (use early returns)
❌ Creating functions in hot loops
❌ Commenting obvious code
❌ Multiple statements per line
❌ Mixed tabs and spaces
❌ Function names starting with uppercase (conflicts with WoW API)
```

---

## Template Patterns

### Module Template
```lua
local ADDON_NAME, JustQuest = ...
local MyModule = {}

-- Private
local privateVar = 0
local function privateHelper() end

-- Public
function MyModule.PublicFunction() end

-- Init
function MyModule.Initialize() end

JustQuest.Core.RegisterModule("MyModule", MyModule, {"Deps"})
return MyModule
```

### Event Handler Template
```lua
local eventFrame = CreateFrame("Frame")
local handlers = {
    EVENT_NAME = function(...) end,
}

eventFrame:SetScript("OnEvent", function(self, event, ...)
    local handler = handlers[event]
    if handler then handler(...) end
end)

for event in pairs(handlers) do
    eventFrame:RegisterEvent(event)
end
```

### Safe API Call Template
```lua
local function safeAPICall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        -- log error
        return nil
    end
    return result
end
```

### Error Return Template
```lua
function myFunction(arg)
    if not arg then
        return nil, "Invalid argument"
    end
    
    local result = process(arg)
    if not result then
        return nil, "Processing failed"
    end
    
    return result
end
```

---

## Code Review Checklist

When writing or reviewing code, verify:

```
□ All variables declared local
□ Single global namespace used
□ Addon namespace pattern at file top
□ 4-space indentation (no tabs)
□ Descriptive names (not abbreviated)
□ Constants in UPPER_SNAKE_CASE
□ Functions lowercase-started
□ Trailing commas in multi-line tables
□ Spaces around operators
□ Space after commas
□ Space after -- in comments
□ Comments explain WHY not WHAT
□ Public functions documented
□ WoW API calls wrapped in pcall
□ Early returns used (not deep nesting)
□ No function creation in loops
□ Table lookups cached in locals
□ ipairs for arrays, pairs for dicts
□ _G used (not getglobal/setglobal)
□ No global namespace pollution
```

---

## Priority Decision Tree

**When writing code:**

1. Does it need to be global?
   - NO → Make it local
   - YES → Add to JustQuest namespace

2. Is it a constant?
   - YES → UPPER_SNAKE_CASE
   - NO → Continue

3. Is it a module/class?
   - YES → PascalCase
   - NO → camelCase or snake_case

4. Does it call WoW API?
   - YES → Wrap in pcall if it can fail
   - NO → Continue

5. Is it complex or unusual?
   - YES → Add comment explaining WHY
   - NO → No comment needed

6. Will it be called frequently?
   - YES → Cache table lookups, avoid function creation in loops
   - NO → Keep it simple and readable

---

## Quick Don't/Do Reference

### Don't → Do

```lua
-- Global variables
❌ myVar = "hello"
✓ local myVar = "hello"

-- Multiple globals
❌ MyAddonConfig = {}
   MyAddonUtils = {}
✓ JustQuest.Config = {}
   JustQuest.Utils = {}

-- Tabs
❌ function()
	    code
✓ function()
    code

-- Spacing
❌ local x=y+5
✓ local x = y + 5

-- Function names
❌ function GetPlayerQuest()
✓ function getPlayerQuest()

-- Comments
❌ local x = 5  -- Set x to 5
✓ local x = 5  -- Max retry attempts per spec

-- Nesting
❌ if a then
       if b then
           if c then
               return true
✓ if not a then return false end
  if not b then return false end
  if not c then return false end
  return true

-- API calls
❌ local info = C_QuestLog.GetQuestTagInfo(id)
✓ local ok, info = pcall(C_QuestLog.GetQuestTagInfo, id)
  if ok and info then

-- Dynamic globals
❌ local f = getglobal("Frame" .. i)
✓ local f = _G["Frame" .. i]

-- Repeated lookups
❌ for i = 1, 100 do
       JustQuest.Constants.VALUE
✓ local constants = JustQuest.Constants
  for i = 1, 100 do
      constants.VALUE
```

---

## Version History

- **1.0.0** (2025): Initial AI-optimized reference guide

---

**Usage Note:** This document is optimized for AI parsing. For detailed explanations and human-readable content, refer to STYLE_GUIDE.md.
