# Quest & Gossip Frame Interaction Model

**Version:** 1.1  
**Last Updated:** 2025-11-02  
**Purpose:** Comprehensive reference for automating WoW quest/gossip frame interactions  
**API Version:** Patch 10.0.0+ (Dragonflight)

---

## Table of Contents

1. [Frame Architecture](#frame-architecture)
2. [Event Flow & State Machines](#event-flow--state-machines)
3. [API Reference](#api-reference)
4. [Combat Lockdown & Protection](#combat-lockdown--protection)
5. [Automation Optimization Strategies](#automation-optimization-strategies)
6. [Common Pitfalls & Solutions](#common-pitfalls--solutions)
7. [API Breaking Changes](#api-breaking-changes)

---

## Frame Architecture

### Quest Frame System

**Primary Frame:** `QuestFrame`  
**Parent Panels (Mutually Exclusive):**
- `QuestFrameGreetingPanel` - Legacy multi-quest selection (QUEST_GREETING event)
- `QuestFrameDetailPanel` - Quest acceptance view (QUEST_DETAIL event)
- `QuestFrameProgressPanel` - Quest progress/turn-in check (QUEST_PROGRESS event)
- `QuestFrameRewardPanel` - Quest completion/reward selection (QUEST_COMPLETE event)

**Key Characteristics:**
- Only ONE panel visible at a time (mutual exclusivity enforced)
- Frame automatically hides all other panels when showing one
- Each panel triggers when specific event fires

### Gossip Frame System

**Primary Frame:** `GossipFrame`  
**Main Panel:** `GossipFrame.GreetingPanel`  
**Uses ScrollBox system** with dynamic button pools

**Button Types (GOSSIP_BUTTON_TYPE constants):**
1. `GOSSIP_BUTTON_TYPE_TITLE` (1) - Greeting text
2. `GOSSIP_BUTTON_TYPE_DIVIDER` (2) - Visual separator
3. `GOSSIP_BUTTON_TYPE_OPTION` (3) - Gossip option (vendor, teleport, etc.)
4. `GOSSIP_BUTTON_TYPE_ACTIVE_QUEST` (4) - Quest turn-in
5. `GOSSIP_BUTTON_TYPE_AVAILABLE_QUEST` (5) - New quest offer

---

## Event Flow & State Machines

### Modern Quest Flow (C_GossipInfo API)

```
GOSSIP_SHOW
├─> C_GossipInfo.GetAvailableQuests() - New quests
├─> C_GossipInfo.GetActiveQuests() - Turn-ins
└─> C_GossipInfo.GetOptions() - Other options

User Selection:
├─> C_GossipInfo.SelectAvailableQuest(questID)
│   └─> QUEST_DETAIL → QuestFrameDetailPanel
│       └─> AcceptQuest() → QUEST_ACCEPTED
│
├─> C_GossipInfo.SelectActiveQuest(questID)
│   └─> QUEST_PROGRESS → QuestFrameProgressPanel
│       ├─> CompleteQuest() [if ready]
│       │   └─> QUEST_COMPLETE → QuestFrameRewardPanel
│       │       └─> GetQuestReward(choiceIndex)
│       │           └─> QUEST_FINISHED
│       └─> [not ready] → Stay in QUEST_PROGRESS
│
└─> C_GossipInfo.SelectOption(optionID)
    └─> May trigger new GOSSIP_SHOW or close
```

### Legacy Quest Flow (QUEST_GREETING)

```
QUEST_GREETING
├─> GetNumActiveQuests() - Turn-ins count
├─> GetNumAvailableQuests() - New quests count
└─> QuestFrameGreetingPanel:Show()

User Selection (via button click):
├─> SelectActiveQuest(index) [1-based]
│   └─> QUEST_PROGRESS → [same as modern flow]
│
└─> SelectAvailableQuest(index) [1-based]
    └─> QUEST_DETAIL → [same as modern flow]
```

### Critical State Transitions

**Quest Detail → Accept:**
```
QUEST_DETAIL fires
└─> QuestFrameDetailPanel:Show()
    └─> AcceptQuest()
        ├─> Success: QUEST_ACCEPTED fires
        │   └─> May trigger QUEST_PROGRESS if auto-complete
        └─> Failure: No event (quest log full, prerequisites missing)
```

**Quest Progress → Complete:**
```
QUEST_PROGRESS fires
└─> QuestFrameProgressPanel:Show()
    └─> Check IsQuestCompletable()
        ├─> true: CompleteQuest() enabled
        │   └─> CompleteQuest()
        │       └─> QUEST_COMPLETE → QuestFrameRewardPanel
        └─> false: CompleteQuest() disabled (cannot proceed)
```

**Quest Reward → Finish:**
```
QUEST_COMPLETE fires
└─> QuestFrameRewardPanel:Show()
    └─> GetNumQuestChoices()
        ├─> 0: GetQuestReward(nil) [auto-complete]
        ├─> 1: GetQuestReward(1) [single reward]
        └─> >1: User must select
            └─> GetQuestReward(choiceIndex) [1-based]
                └─> QUEST_FINISHED fires
                    └─> QuestFrame automatically hides
```

---

## API Reference

### C_GossipInfo (Modern API)

#### Data Retrieval

```lua
-- Get gossip greeting text
local text = C_GossipInfo.GetText()

-- Get available quests (new quests)
local availableQuests = C_GossipInfo.GetAvailableQuests()
-- Returns: array of GossipQuestUIInfo
-- {
--   questID = number,
--   title = string,
--   isLegendary = bool,
--   frequency = Enum.QuestFrequency (nil, Daily, Weekly),
--   isRepeatable = bool,
--   isImportant = bool,
--   isMeta = bool,
--   isTrivial = bool,
--   isIgnored = bool,
--   questInfoID = number (optional)
-- }

-- Get active quests (turn-ins)
local activeQuests = C_GossipInfo.GetActiveQuests()
-- Returns: array of GossipQuestUIInfo (same structure)
-- Additional field: isComplete = bool

-- Get gossip options (non-quest interactions)
local options = C_GossipInfo.GetOptions()
-- Returns: array of GossipOptionUIInfo
-- {
--   gossipOptionID = number,
--   name = string,
--   icon = number (texture ID),
--   type = Enum.GossipOptionType,
--   status = Enum.GossipOptionStatus,
--   spellID = number (optional),
--   flags = number (bitmask),
--   overrideIconID = number (optional),
--   orderIndex = number,
--   selectOptionWhenOnlyOption = bool
-- }

-- Get counts
local numAvailable = C_GossipInfo.GetNumAvailableQuests()
local numActive = C_GossipInfo.GetNumActiveQuests()
```

#### Selection Actions

```lua
-- Select available quest (triggers QUEST_DETAIL)
-- ⚠️ CHANGED in Patch 10.0.0: Now uses questID, not index
C_GossipInfo.SelectAvailableQuest(questID)

-- Select active quest (triggers QUEST_PROGRESS)
-- ⚠️ CHANGED in Patch 10.0.0: Now uses questID, not index
C_GossipInfo.SelectActiveQuest(questID)

-- Select gossip option by ID
C_GossipInfo.SelectOption(gossipOptionID, text, confirmed)
-- text: optional input string for text-entry gossip
-- confirmed: optional bool for confirmation dialogs

-- Select gossip option by index (1-based, orderIndex)
C_GossipInfo.SelectOptionByIndex(orderIndex, text, confirmed)

-- Close gossip without selecting
C_GossipInfo.CloseGossip()

-- Check if forced gossip (cannot auto-select single option)
local forced = C_GossipInfo.ForceGossip()

-- Refresh option data (rarely needed)
C_GossipInfo.RefreshOptions()
```

### Legacy Quest API (QUEST_GREETING)

```lua
-- Get greeting text
local text = GetGreetingText()

-- Get quest counts
local numActive = GetNumActiveQuests()
local numAvailable = GetNumAvailableQuests()

-- Get quest info (index is 1-based)
local title, isComplete = GetActiveTitle(index)
local questID = GetActiveQuestID(index)
local isTrivial = IsActiveQuestTrivial(index)

local title = GetAvailableTitle(index)
local isTrivial, frequency, isRepeatable, isLegendary, questID, 
      isImportant, isMeta, questInfoID = GetAvailableQuestInfo(index)

-- Select quest (index-based, triggers QUEST_DETAIL or QUEST_PROGRESS)
SelectActiveQuest(index)
SelectAvailableQuest(index)
```

### Quest Frame API

```lua
-- Accept quest (call from QUEST_DETAIL)
AcceptQuest()  -- No return value, check QUEST_ACCEPTED event

-- Progress quest (call from QUEST_PROGRESS)
CompleteQuest()  -- Triggers QUEST_COMPLETE if ready

-- Check if quest can be completed
local canComplete = IsQuestCompletable()  -- bool

-- Get reward info (call from QUEST_COMPLETE)
local numChoices = GetNumQuestChoices()  -- 0, 1, or more
local money = GetQuestMoneyToGet()  -- 0 or copper amount

-- Complete quest with reward selection
GetQuestReward(choiceIndex)  -- nil for no choice, 1-based index
-- Triggers QUEST_FINISHED

-- Close quest frame without accepting/completing
CloseQuest()  -- Does NOT trigger QUEST_FINISHED

-- Get current quest ID (from active quest frame)
local questID = GetQuestID()  -- 0 if no quest active

-- Check quest properties
local isAutoAccept = QuestGetAutoAccept()
local isFromAreaTrigger = QuestIsFromAreaTrigger()
local isFromAdventureMap = QuestIsFromAdventureMap()

-- Quest item info
local questStartItemID = ...  -- From QUEST_DETAIL event payload
```

### Enum Values Reference

```lua
-- Enum.QuestFrequency
nil or 0  -- Normal (one-time)
1         -- Daily
2         -- Weekly

-- Enum.GossipOptionStatus
0  -- Available
1  -- Unavailable
2  -- Locked
3  -- AlreadyComplete

-- ⚠️ REMOVED in Patch 10.0.0: Enum.GossipOptionType field
-- The 'type' field no longer exists in GossipOptionUIInfo
-- Previously: banker, battlemaster, binder, gossip, healer, petition, 
-- tabard, taxi, trainer, unlearn, vendor, workorder, chatbubble
-- Workaround: Use icon texture IDs or option names for type detection
```

---

## Combat Lockdown & Protection

### Combat State Detection

```lua
-- Check if in combat
local inCombat = InCombatLockdown()  -- Returns true/false

-- Combat events (use for state tracking)
-- PLAYER_REGEN_DISABLED - Fires AFTER entering combat
-- PLAYER_REGEN_ENABLED - Fires BEFORE leaving combat

local combatState = false

frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        combatState = true
        -- Cancel all pending automation
        CancelAllQuestAutomation()
    elseif event == "PLAYER_REGEN_ENABLED" then
        combatState = false
        -- Resume automation after brief delay
        C_Timer.After(0.5, ResumeQuestAutomation)
    end
end)
```

### Protected Functions (Cannot Call During Combat if Tainted)

**Frame Management:**
- `ShowUIPanel(frame)` - **PROTECTED**
- `HideUIPanel(frame)` - **PROTECTED**

**Quest Functions (Strongly Implied Protected):**
- `AcceptQuest()` - Cannot call if tainted during combat
- `CompleteQuest()` - Cannot call if tainted during combat
- `GetQuestReward(choiceIndex)` - Cannot call if tainted during combat
- `CloseQuest()` - May fail if tainted during combat

**Selection Functions:**
- `C_GossipInfo.SelectOption()` - Protected during combat
- `C_GossipInfo.SelectActiveQuest()` - Protected during combat
- `C_GossipInfo.SelectAvailableQuest()` - Protected during combat

### Taint Management Strategy

```lua
-- GOOD: Queue actions during combat, process after
local queuedActions = {}

function AutomateQuest()
    if InCombatLockdown() then
        -- Queue for post-combat
        table.insert(queuedActions, {
            type = "ACCEPT_QUEST",
            questID = GetQuestID(),
            timestamp = GetTime()
        })
        return false, "combat"
    end
    
    AcceptQuest()
    return true, "accepted"
end

-- Process queue when combat ends
function OnPlayerRegenEnabled()
    C_Timer.After(0.5, function()
        for _, action in ipairs(queuedActions) do
            if action.type == "ACCEPT_QUEST" then
                -- Re-validate quest is still available
                ProcessQueuedQuest(action.questID)
            end
        end
        queuedActions = {}
    end)
end
```

### Real-World Taint Examples

**Known Issues from Quest Automation Addons:**
- **QuickQuest:** Taint issues cause quest frame errors during combat NPC interactions
- **AutoTurnIn:** Protected function calls fail when player enters combat mid-automation
- **Classic Quest Log:** Documented taint propagation to Blizzard frames

**Prevention Best Practices:**
1. Always check `InCombatLockdown()` before automation
2. Register combat events and halt processing immediately
3. Queue actions for post-combat processing
4. Use 0.5s delay after `PLAYER_REGEN_ENABLED` for UI stabilization
5. Avoid touching Blizzard frames directly - use protected APIs only

---

## Automation Optimization Strategies

### 1. Event Coalescing

**Problem:** GOSSIP_SHOW fires rapidly during NPC interactions  
**Solution:** Debounce/coalesce multiple fires within 0.15-0.3s window

```lua
local gossipShowTime = 0
local COALESCE_DELAY = 0.15

function OnGOSSIP_SHOW()
    local now = GetTime()
    if now - gossipShowTime < COALESCE_DELAY then
        -- Ignore rapid re-fire
        return
    end
    gossipShowTime = now
    
    -- Schedule actual processing after delay
    C_Timer.After(COALESCE_DELAY, function()
        ProcessGossipData()
    end)
end
```

### 2. API Call Batching

**Problem:** Multiple C_GossipInfo calls within same frame  
**Solution:** Call once, cache results for frame lifecycle

```lua
-- GOOD: Cache results
local activeQuests = C_GossipInfo.GetActiveQuests()
local availableQuests = C_GossipInfo.GetAvailableQuests()
local options = C_GossipInfo.GetOptions()

for _, quest in ipairs(activeQuests) do
    ProcessQuest(quest)  -- Use cached data
end

-- BAD: Repeated calls
for i = 1, C_GossipInfo.GetNumActiveQuests() do
    local quests = C_GossipInfo.GetActiveQuests()  -- Called every iteration!
    ProcessQuest(quests[i])
end
```

### 3. Frame State Validation

**Always validate frame state before automation:**

```lua
function CanAutomateQuestFrame()
    -- Check frame visibility
    if not QuestFrame or not QuestFrame:IsVisible() then
        return false
    end
    
    -- Check which panel is active
    if QuestFrameDetailPanel:IsVisible() then
        return "DETAIL"
    elseif QuestFrameProgressPanel:IsVisible() then
        return "PROGRESS"
    elseif QuestFrameRewardPanel:IsVisible() then
        return "REWARD"
    elseif QuestFrameGreetingPanel:IsVisible() then
        return "GREETING"
    end
    
    return false
end
```

### 4. Timing Constants (Critical Values)

```lua
-- Minimum server sync delay (WoW server tick rate)
GOSSIP_SHOW_DELAY = 0.15  -- Wait for UI stabilization after event

-- Quest processing delay (quest log sync)
QUEST_PROCESSING_DELAY = 0.15  -- Wait after AcceptQuest()

-- Gossip cache TTL
GOSSIP_PER_NPC_TTL = 0.30  -- Prevent repeat automation on same NPC

-- Reinteraction check delay
REINTERACT_CHECK_DELAY = 0.50  -- Check if NPC needs re-interaction

-- Timing multiplier for lag/latency
-- All delays should multiply by user-configured value (default 1.0)
delay = BASE_DELAY * timingMultiplier
```

### 5. Quest/Gossip Option Filtering

**Use single-pass filtering for performance:**

```lua
-- GOOD: Single iteration
local questRelated = {}
local nonQuest = {}

for _, option in ipairs(options) do
    if IsQuestRelatedGossip(option) then
        table.insert(questRelated, option)
    else
        table.insert(nonQuest, option)
    end
end

-- BAD: Multiple passes
local questRelated = FilterQuestOptions(options)  -- Full iteration
local nonQuest = FilterNonQuestOptions(options)   -- Full iteration again
```

### 6. Auto-Select Optimization

**Blizzard UI handles single non-gossip options automatically:**

```lua
-- From GossipFrameShared.lua:
if (C_GossipInfo.GetNumAvailableQuests() == 0) and 
   (C_GossipInfo.GetNumActiveQuests() == 0) and 
   (#self.gossipOptions == 1) and 
   not C_GossipInfo.ForceGossip() then
    if options[1].selectOptionWhenOnlyOption then
        C_GossipInfo.SelectOptionByIndex(options[1].orderIndex)
        return  -- Frame won't even show
    end
end
```

**Implication:** GOSSIP_SHOW may not fire for single auto-selected options!  
**Solution:** Also hook QUEST_DETAIL/QUEST_PROGRESS for complete coverage

### 7. Modern vs Legacy Detection

```lua
function DetectQuestSystem()
    -- Modern API always takes precedence
    if C_GossipInfo then
        local avail = C_GossipInfo.GetAvailableQuests()
        local active = C_GossipInfo.GetActiveQuests()
        local options = C_GossipInfo.GetOptions()
        
        if #avail > 0 or #active > 0 or #options > 0 then
            return "MODERN"
        end
    end
    
    -- Check legacy API
    if GetNumActiveQuests and GetNumAvailableQuests then
        local numActive = GetNumActiveQuests() or 0
        local numAvail = GetNumAvailableQuests() or 0
        
        if numActive > 0 or numAvail > 0 then
            return "LEGACY"
        end
    end
    
    return nil
end
```

---

## Common Pitfalls & Solutions

### Pitfall 1: Duplicate GOSSIP_SHOW Processing

**Symptom:** Automation triggers twice for same NPC  
**Cause:** GOSSIP_SHOW fires multiple times during single interaction  
**Solution:** Implement coalescing + NPC GUID tracking

```lua
local lastNPCGUID = nil
local lastProcessTime = 0

function OnGOSSIP_SHOW()
    local npcGUID = UnitGUID("npc")
    local now = GetTime()
    
    -- Skip if same NPC within cooldown
    if npcGUID == lastNPCGUID and (now - lastProcessTime) < 0.30 then
        return
    end
    
    lastNPCGUID = npcGUID
    lastProcessTime = now
    
    ProcessGossip()
end
```

### Pitfall 2: Race Condition Between QUEST_DETAIL and GOSSIP_SHOW

**Symptom:** Quest accepted before gossip processing completes  
**Cause:** QUEST_DETAIL may fire BEFORE GOSSIP_SHOW completes processing  
**Solution:** Use transition flag or processing state

```lua
local transitioningToQuestFrame = false

function OnGOSSIP_SHOW()
    if transitioningToQuestFrame then
        return  -- Let QUEST_DETAIL handler take over
    end
    
    -- ... gossip processing
    
    if shouldSelectQuest then
        transitioningToQuestFrame = true
        C_GossipInfo.SelectAvailableQuest(questID)
    end
end

function OnQUEST_DETAIL()
    transitioningToQuestFrame = false  -- Reset flag
    -- ... quest detail processing
end
```

### Pitfall 3: Reward Selection with GetNumQuestChoices() = 1

**Symptom:** Auto-completion doesn't work for single-choice rewards  
**Cause:** Blizzard UI expects GetQuestReward(1), not GetQuestReward(nil)  
**Solution:** Always pass choice index, even for single reward

```lua
local numChoices = GetNumQuestChoices()

if numChoices == 0 then
    GetQuestReward(nil)  -- No choice needed
elseif numChoices == 1 then
    GetQuestReward(1)  -- MUST pass 1, not nil
else
    local choice = DetermineOptimalReward()
    GetQuestReward(choice)  -- 1-based index
end
```

### Pitfall 4: Quest Frame Not Closing After QUEST_FINISHED

**Symptom:** QuestFrame remains visible after completion  
**Cause:** Blizzard auto-hides on QUEST_FINISHED, but may fail if event lost  
**Solution:** Manually close on timeout

```lua
function OnQUEST_FINISHED()
    -- Blizzard will auto-close, but set backup timeout
    C_Timer.After(0.5, function()
        if QuestFrame and QuestFrame:IsVisible() then
            HideUIPanel(QuestFrame)
        end
    end)
end
```

### Pitfall 5: Using pairs() on C_GossipInfo Arrays

**Symptom:** Options processed in undefined order  
**Cause:** C_GossipInfo returns indexed arrays, pairs() doesn't guarantee order  
**Solution:** Always use ipairs() for quest/option arrays

```lua
-- GOOD: Maintains order
for i, quest in ipairs(C_GossipInfo.GetAvailableQuests()) do
    ProcessQuest(quest)
end

-- BAD: Undefined order
for i, quest in pairs(C_GossipInfo.GetAvailableQuests()) do
    ProcessQuest(quest)
end
```

### Pitfall 6: Not Handling Combat Lockdown

**Symptom:** Addon errors during combat  
**Cause:** Many quest/gossip APIs protected during combat  
**Solution:** Always check InCombatLockdown()

```lua
function AutomateQuest()
    if InCombatLockdown() then
        -- Queue for post-combat processing
        queuedActions[#queuedActions + 1] = "AutomateQuest"
        return false
    end
    
    AcceptQuest()
    return true
end

-- Register PLAYER_REGEN_ENABLED to process queue
```

### Pitfall 7: Assuming QUEST_ACCEPTED Always Fires

**Symptom:** Automation hangs waiting for quest acceptance  
**Cause:** QUEST_ACCEPTED only fires if quest successfully accepted  
**Solution:** Implement timeout and validation

```lua
local acceptTimeout = nil

function AcceptQuestWithTimeout(questID)
    AcceptQuest()
    
    acceptTimeout = C_Timer.After(3.0, function()
        -- Timeout - check if quest actually accepted
        if C_QuestLog.IsOnQuest(questID) then
            -- Success (event was lost)
            OnQuestAcceptedFallback(questID)
        else
            -- Failed (quest log full, prerequisites, etc.)
            OnQuestAcceptFailed(questID)
        end
    end)
end

function OnQUEST_ACCEPTED()
    if acceptTimeout then
        acceptTimeout:Cancel()
        acceptTimeout = nil
    end
    -- Normal processing
end
```

---

## Event Timing Diagram

```
User Interacts with NPC
    ↓
GOSSIP_SHOW (t=0ms)
    ↓ [0-50ms] - Additional GOSSIP_SHOW fires (coalesce these)
GOSSIP_SHOW (t=20ms) ← Ignore
GOSSIP_SHOW (t=45ms) ← Ignore
    ↓ [150ms] - Wait for UI stabilization
Process Gossip Data (t=150ms)
    ↓
C_GossipInfo.SelectAvailableQuest(questID) (t=160ms)
    ↓ [~100-200ms] - Server round-trip
QUEST_DETAIL (t=300ms)
    ↓ [150ms] - Wait for quest log sync
AcceptQuest() (t=450ms)
    ↓ [~100-200ms] - Server processing
QUEST_ACCEPTED (t=600ms)
    ↓
[Quest added to log] (t=600ms)
```

**Total Modern Quest Accept Time:** ~600-800ms from GOSSIP_SHOW to QUEST_ACCEPTED

---

## Performance Benchmarks

### API Call Costs (Typical)

| API Call | Time (ms) | Notes |
|----------|-----------|-------|
| `C_GossipInfo.GetOptions()` | 0.1-0.3 | Cached by Blizzard |
| `C_GossipInfo.GetActiveQuests()` | 0.1-0.3 | Cached by Blizzard |
| `C_GossipInfo.GetAvailableQuests()` | 0.1-0.3 | Cached by Blizzard |
| `C_GossipInfo.SelectOption()` | 100-200 | Server round-trip |
| `AcceptQuest()` | 100-200 | Server round-trip |
| `GetQuestReward()` | 100-200 | Server round-trip |
| `C_QuestLog.IsOnQuest()` | 0.5-1.0 | Quest log lookup |

### Event Fire Frequencies

| Event | Frequency | Coalescing Needed? |
|-------|-----------|-------------------|
| `GOSSIP_SHOW` | 2-5 per interaction | ✅ Yes (0.15s window) |
| `QUEST_DETAIL` | 1 per quest | ❌ No |
| `QUEST_PROGRESS` | 1 per turn-in | ❌ No |
| `QUEST_COMPLETE` | 1 per completion | ❌ No |
| `QUEST_ACCEPTED` | 1 per accept | ❌ No |
| `QUEST_FINISHED` | 1 per finish | ❌ No |
| `QUEST_LOG_UPDATE` | High (variable) | ✅ Yes (debounce) |

---

## Reference Implementation Patterns

### Pattern 1: Safe Option Selection

```lua
function SelectSafeOption(option)
    -- Validate option availability
    if not option or option.status ~= Enum.GossipOptionStatus.Available then
        return false, "unavailable"
    end
    
    -- Check for dangerous types
    local dangerousTypes = {
        [Enum.GossipOptionType.Binder] = true,
        [Enum.GossipOptionType.SpiritHealer] = true,
        [Enum.GossipOptionType.PetitionVendor] = true,
    }
    
    if dangerousTypes[option.type] then
        return false, "dangerous_type"
    end
    
    -- Select option
    local success = pcall(C_GossipInfo.SelectOption, option.gossipOptionID)
    return success, success and "selected" or "error"
end
```

### Pattern 2: Quest Batch Processing

```lua
function ProcessQuestBatch(quests, maxDepth)
    maxDepth = maxDepth or 10
    if #quests == 0 or maxDepth <= 0 then
        return false
    end
    
    local quest = quests[1]
    table.remove(quests, 1)
    
    -- Process quest
    local success = ProcessQuest(quest)
    
    -- Schedule next quest
    if #quests > 0 then
        C_Timer.After(0.15, function()
            ProcessQuestBatch(quests, maxDepth - 1)
        end)
    end
    
    return success
end
```

### Pattern 3: State Recovery

```lua
function RecoverFromBrokenState()
    -- Cancel all pending timers
    CancelAllScheduledActions()
    
    -- Reset processing flags
    processingState = "IDLE"
    
    -- Close any open frames
    if QuestFrame and QuestFrame:IsVisible() then
        HideUIPanel(QuestFrame)
    end
    if GossipFrame and GossipFrame:IsVisible() then
        HideUIPanel(GossipFrame)
    end
    
    -- Clear caches
    lastNPCGUID = nil
    lastProcessTime = 0
    
    -- Re-engage automation after delay
    C_Timer.After(0.5, function()
        RecheckNPCInteraction()
    end)
end
```

---

## Debugging Checklist

When automation fails, check:

1. ✅ **Frame visibility:** Is expected panel actually showing?
2. ✅ **Event coalescing:** Are multiple GOSSIP_SHOW processed as one?
3. ✅ **Timing delays:** Are delays sufficient for server sync (≥150ms)?
4. ✅ **Processing state:** Is state machine stuck in non-IDLE?
5. ✅ **NPC GUID:** Did NPC change during interaction?
6. ✅ **Combat lockdown:** Are APIs protected?
7. ✅ **Quest log full:** Can more quests be accepted?
8. ✅ **API return values:** Are arrays empty when expected to have data?
9. ✅ **Modern vs Legacy:** Is correct API path being used?
10. ✅ **Event ordering:** Did events fire in unexpected sequence?

---

## API Breaking Changes

### Patch 10.0.0 (Dragonflight - October 25, 2022)

**Critical Breaking Changes:**

#### 1. Quest Selection Parameter Type Change ⚠️

**Changed Functions:**
- `C_GossipInfo.SelectAvailableQuest(questID)` - Was `SelectAvailableQuest(index)`
- `C_GossipInfo.SelectActiveQuest(questID)` - Was `SelectActiveQuest(index)`

**Impact:** Pre-10.0 code using index-based selection will fail  
**Migration:**

```lua
-- OLD (Pre-10.0.0) - BROKEN
local availableQuests = C_GossipInfo.GetAvailableQuests()
for i = 1, #availableQuests do
    C_GossipInfo.SelectAvailableQuest(i)  -- ❌ WRONG: uses index
end

-- NEW (10.0.0+) - CORRECT
local availableQuests = C_GossipInfo.GetAvailableQuests()
for _, quest in ipairs(availableQuests) do
    C_GossipInfo.SelectAvailableQuest(quest.questID)  -- ✅ CORRECT: uses questID
end
```

**Source:** [BreezeWiki Patch 10.0.0 Notes](https://breezewiki.com/wowpedia/wiki/Patch_10.0.0)

#### 2. GossipOptionType Field Removed ⚠️

**Removed Field:** `option.type` (Enum.GossipOptionType)

**Previous Values (No Longer Available):**
- `banker`, `battlemaster`, `binder`, `gossip`, `healer`, `petition`
- `tabard`, `taxi`, `trainer`, `unlearn`, `vendor`, `workorder`, `chatbubble`

**Impact:** Type-based filtering no longer works directly  
**Migration:**

```lua
-- OLD (Pre-10.0.0) - BROKEN
if option.type == Enum.GossipOptionType.Vendor then  -- ❌ type field removed
    return true, "dangerous_vendor"
end

-- NEW (10.0.0+) - CORRECT: Use icon or name matching
local DANGEROUS_ICONS = {
    [132060] = "Vendor",
    [132061] = "Taxi",
    [132147] = "Binder",
    -- ... add more icon IDs
}

if DANGEROUS_ICONS[option.icon] then  -- ✅ CORRECT: icon-based detection
    return true, "dangerous_service"
end

-- Alternative: Name-based detection
if option.name:find("vendor", 1, true) or 
   option.name:find("inn", 1, true) then
    return true, "dangerous_service"
end
```

**Workaround:** Build icon-to-type mapping table from observation  
**Source:** [Wowpedia Patch 10.0.0 API Changes](https://wowpedia.fandom.com/wiki/Patch_10.0.0/API_changes)

#### 3. gossipOptionID Nilability (Patch 10.0.7+)

**🔴 CRITICAL BREAKING CHANGE - Patch 10.0.7 (2023-03-21)**

The `gossipOptionID` field in `GossipOptionUIInfo` became **nilable** in Patch 10.0.7. Quest automation addons that assume `gossipOptionID` is always valid will crash when it is nil.

**Breaking Code:**
```lua
-- ❌ CRASHES when gossipOptionID is nil
local option = C_GossipInfo.GetOptions()[1]
C_GossipInfo.SelectOption(option.gossipOptionID)  -- ERROR if nil
```

**Fixed Code:**
```lua
-- ✅ SAFE: Fall back to orderIndex when gossipOptionID is nil
local option = C_GossipInfo.GetOptions()[1]
if option.gossipOptionID then
    C_GossipInfo.SelectOption(option.gossipOptionID)
elseif option.orderIndex and C_GossipInfo.SelectOptionByIndex then
    C_GossipInfo.SelectOptionByIndex(option.orderIndex)
else
    -- Legacy fallback (pre-10.0.0)
    SelectGossipOption(option.orderIndex or 1)
end
```

**Impact:** Multiple quest automation addons broke in 10.0.7 due to this change  
**Source:** [Wowpedia Patch 10.0.7](https://wowpedia.fandom.com/wiki/Patch_10.0.7), [WoWWiki](https://wowwiki-archive.fandom.com/wiki/API_C_GossipInfo.SelectOption)

#### 4. Legacy API Deprecation Status

**Still Functional (as of 10.0.0+):**
- `GetNumActiveQuests()` / `GetNumAvailableQuests()`
- `GetActiveTitle(index)` / `GetAvailableTitle(index)`
- `SelectActiveQuest(index)` / `SelectAvailableQuest(index)`
- `GetGreetingText()`

**Status:** Legacy API works but modern C_GossipInfo preferred  
**Recommendation:** Use C_GossipInfo for new code, maintain legacy for compatibility

### Version Compatibility Strategy

```lua
-- Detect API version and use appropriate calls
local function selectAvailableQuest(quest, index)
    -- Try modern API first (10.0.0+)
    if C_GossipInfo and C_GossipInfo.SelectAvailableQuest then
        local success = pcall(C_GossipInfo.SelectAvailableQuest, quest.questID)
        if success then return true end
    end
    
    -- Fallback to legacy API (pre-10.0.0)
    if SelectAvailableQuest and index then
        local success = pcall(SelectAvailableQuest, index)
        return success
    end
    
    return false
end

-- Detect GossipOptionType removal
local function hasGossipTypeField()
    local options = C_GossipInfo.GetOptions()
    if #options > 0 and options[1].type ~= nil then
        return true  -- Pre-10.0.0
    end
    return false  -- 10.0.0+
end
```

### Known Undocumented Behaviors

**⚠️ Not Explicitly Documented (but Observed):**

1. **GetQuestReward() with nil vs 1:**
   - `GetQuestReward(nil)` - Works for 0 choices (auto-complete)
   - `GetQuestReward(1)` - **Required** for 1 choice (not nil)
   - Documentation ambiguous, behavior confirmed through testing

2. **QUEST_ACCEPTED Event Reliability:**
   - Does NOT fire if quest log is full
   - Does NOT fire if prerequisites not met
   - Does NOT fire if quest already accepted
   - **Always implement timeout fallback**

3. **Quest Frame Combat Protection:**
   - `AcceptQuest()`, `CompleteQuest()`, `GetQuestReward()` appear protected during combat
   - Not explicitly documented, inferred from taint issues in multiple addons
   - Always check `InCombatLockdown()` before calling

4. **Single-Option Auto-Selection:**
   - Blizzard UI auto-selects if:
     - 0 available quests AND
     - 0 active quests AND
     - 1 gossip option AND
     - NOT `ForceGossip()` AND
     - `option.selectOptionWhenOnlyOption == true`
   - **GOSSIP_SHOW event may not fire** - frame never shows
   - **Hook QUEST_DETAIL/QUEST_PROGRESS** for complete coverage

---

## Version History

**1.1** (2025-11-02)
- Added API version compatibility notes (Patch 10.0.0+)
- Documented quest selection parameter type change
- Documented GossipOptionType field removal
- Added combat lockdown and protection section
- Added taint management strategies
- Added version compatibility detection code
- Documented undocumented behaviors

**1.0** (2025-11-02)
- Initial documentation based on WoW UI source analysis
- Complete API reference for C_GossipInfo and legacy quest APIs
- Event flow diagrams and state machines
- Performance optimization strategies
- Common pitfalls and solutions

---

## Additional Resources

- **WoW API Documentation:** https://wowpedia.fandom.com/wiki/World_of_Warcraft_API
- **Event Reference:** https://wowpedia.fandom.com/wiki/Events
- **Enum Values:** Check `Blizzard_APIDocumentationGenerated` addon files
- **Source Code:** `Interface/AddOns/Blizzard_UIPanels_Game/` (QuestFrame.lua, GossipFrame.lua)
