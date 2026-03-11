# JustQuest Output System

**Last Updated:** 2025-11-05

## Centralized Output Functions

All user-facing output should go through the centralized output system in `Services/Services.lua`:

### Services.Debug(module, msg)
**Purpose:** Debug logging that respects debug mode setting  
**Visibility:** Only shown when `/jq debug on` is enabled  
**Format:** `|cff00ccffJQ <module>:|r <message>`  
**Usage:**
```lua
local services = JustQuest.Core.GetModule("Services")
if services then
    services.Debug("Quest", "Processing quest batch...")
end
```

### Services.Info(msg)
**Purpose:** User-facing informational messages  
**Visibility:** Always shown  
**Format:** `|cff00ccffJustQuest:|r <message>`  
**Usage:**
```lua
services.Info("Leaving instance...")
services.Info("Quest automation enabled")
```

### Services.Warn(msg)
**Purpose:** Non-critical warnings  
**Visibility:** Always shown  
**Format:** `|cffffaa00JustQuest:|r <message>` (yellow)  
**Usage:**
```lua
services.Warn("Cannot leave - not in instance")
services.Warn("Safety check failed for quest " .. questID)
```

### Services.Error(msg)
**Purpose:** Critical errors  
**Visibility:** Always shown  
**Format:** `|cffff0000JustQuest:|r <message>` (red)  
**Usage:**
```lua
services.Error("Quest automation unavailable - Services module failed to load")
services.Error("Failed to accept quest - protected API")
```

## Bootstrap Debug Functions

Some modules initialize before Services loads and need bootstrap debug functions:

### Core.Debug(module, msg)
**Location:** `Core/Core.lua`  
**Purpose:** Bootstrap debug that forwards to Services.Debug when available  
**Fallback:** Direct print with same format if Services not loaded

### Config Debug(msg)
**Location:** `Core/Config.lua` (local function)  
**Purpose:** Config module bootstrap debug  
**Behavior:** Forwards to Services.Debug("Config", msg) when available

## Direct Print() Usage

Direct `print()` calls are **only allowed** for:

### 1. User-Facing Commands
Commands like `/jq status`, `/jq inspect` that generate formatted reports:
- **File:** `Core/Config.lua` (InspectFrame, ShowStatus functions)
- **Reason:** These are intentional user-requested reports with custom formatting
- **Pattern:** Color-coded sections with headers/dividers

### 2. Diagnostic Tools
Development/debugging tools that generate validation reports:
- **File:** `Debug/ContainerValidator.lua`
- **Reason:** Detailed diagnostic output for database validation
- **Pattern:** Formatted reports with statistics and issue lists

### 3. Critical Fallbacks
When Services module is unavailable (initialization failure):
- **File:** `Engines/QuestEngine.lua`, `Core/Core.lua`
- **Reason:** Services.Error() not available, need direct print
- **Pattern:** Red error message explaining module failure

### 4. Third-Party Libraries
AceConfig and other libraries have their own print() calls:
- **Files:** `Libs/AceConfig-3.0/**/*.lua`
- **Reason:** External library code, not modified
- **Action:** Leave as-is

## Anti-Patterns to Avoid

❌ **Direct print() for regular debugging**
```lua
-- BAD
print("Processing quest...")

-- GOOD
if services then
    services.Debug("Quest", "Processing quest...")
end
```

❌ **Inconsistent color codes**
```lua
-- BAD - custom colors
print("|cff33ff99My Message|r")

-- GOOD - use standardized functions
services.Info("My Message")
```

❌ **Mixed formatting styles**
```lua
-- BAD - inconsistent prefixes
print("|cff00ccffJQ Quest:|r Message")  -- Wrong module format
print("|cff00ccffJustQuest Quest:|r Message")  -- Wrong prefix

-- GOOD
services.Debug("Quest", "Message")  -- Automatically formats as "JQ Quest:"
```

## Color Code Reference

- `|cff00ccff` - Cyan (info, debug headers)
- `|cffffaa00` - Yellow (warnings)
- `|cffff0000` - Red (errors, critical)
- `|cffffcc00` - Light yellow (section headers in reports)
- `|cff00ff00` - Green (success states)
- `|cffff6666` - Light red (off states, issues)
- `|cff888888` - Gray (secondary info)

## Migration Checklist

When adding new output:
1. ✅ Use Services.Debug() for debug logging
2. ✅ Use Services.Info/Warn/Error() for user messages
3. ✅ Check `if services then` before calling
4. ✅ Provide descriptive module name to Debug()
5. ✅ Use appropriate severity level (debug vs info vs warn vs error)

## Testing

Enable debug mode and verify output:
```lua
/jq debug on
-- Trigger automation
-- Verify messages show consistent formatting:
--   |cff00ccffJQ <Module>:|r for debug
--   |cff00ccffJustQuest:|r for info
--   |cffffaa00JustQuest:|r for warnings
--   |cffff0000JustQuest:|r for errors
```
