-- ContainerValidator.lua — Debug module to validate ContainerDB entries against in-game data
-- Checks for deprecated items, wrong IDs, and non-instant-open containers

local ADDON_NAME, JustQuest = ...

-- Initialize debug namespace
JustQuest.Debug = JustQuest.Debug or {}

local ContainerValidator = {}
JustQuest.Debug.ContainerValidator = ContainerValidator

local logBuffer = {}
local LOG_FLUSH_SIZE = 50

local validationResults = {
    safe = {
        valid = {},              -- Items that exist and match
        minorMismatch = {},      -- Items with minor name differences (>75% similar)
        majorMismatch = {},      -- Items with major name differences (<75% similar)
        deprecated = {},         -- Items that don't exist in game
        nonUsable = {},          -- Items that exist but can't be used
        total = 0
    },
    dangerous = {
        valid = {},
        minorMismatch = {},
        majorMismatch = {},
        deprecated = {},
        total = 0
    },
    scanStartTime = nil,
    scanEndTime = nil,
    itemsProcessed = 0,
    itemsPending = 0,
    isScanning = false
}

local itemQueryCache = {}
local queryQueue = {}
local retryQueue = {}
local QUERY_DELAY = 0.15
local BATCH_SIZE = 5
local MAX_RETRIES = 3
local queryTimer = nil

-- Debug output function
local function DebugLog(msg)
    if JustQuest.Core and JustQuest.Core.GetModule then
        local services = JustQuest.Core.GetModule("Services")
        if services then
            services.Debug("ContainerValidator", msg)
        end
    end
    -- Fallback to print
    print("|cFF00FF00[JustQuest-Validator]|r " .. tostring(msg))
end

local function FlushLog()
    if not JustQuestDB then
        JustQuestDB = {}
    end
    if not JustQuestDB.ContainerValidatorLog then
        JustQuestDB.ContainerValidatorLog = {}
    end
    
    -- Append buffer to saved log
    for _, line in ipairs(logBuffer) do
        table.insert(JustQuestDB.ContainerValidatorLog, line)
    end
    
    -- Clear buffer
    logBuffer = {}
end

local function ClearLog()
    if JustQuestDB then
        JustQuestDB.ContainerValidatorLog = {}
        -- Clean up old validation logs from previous versions
        JustQuestDB.validationLogs = nil
        JustQuestDB.ValidatorLog = nil  -- Old log location
    end
    logBuffer = {}
    DebugLog("Log cleared")
end

-- File logging function
local function LogToFile(msg)
    table.insert(logBuffer, string.format("[%s] %s", date("%H:%M:%S"), msg))
    
    -- Flush to SavedVariables periodically
    if #logBuffer >= LOG_FLUSH_SIZE then
        FlushLog()
    end
end

-- Check if an item is a safe container using proper WoW APIs
local function IsInstantUse(itemID)
    -- First check if item data is cached
    if not C_Item.IsItemDataCachedByID(itemID) then
        return false, "Item data not cached"
    end
    
    -- Get item class info using GetItemInfoInstant (always cached)
    -- This is the reliable way to get class/subclass
    local itemID_ret, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    
    if not itemID_ret then
        return false, "No instant item info available"
    end
    
    -- Item class constants from Enum.ItemClass:
    -- 0 = Consumable (some openable items like food/drink that open)
    -- 1 = Container (actual bags and openable containers)
    -- 12 = Quest Item (some quest containers)
    -- 15 = Miscellaneous (junk, some lockboxes)
    
    -- Most openable containers are classID 1 (Container) or 15 (Miscellaneous)
    -- We DON'T check if usable because many containers show as "not usable" 
    -- but can still be right-clicked to open
    local isLikelyContainer = (classID == 1 or classID == 15 or classID == 0 or classID == 12)
    
    if not isLikelyContainer then
        return false, string.format("Wrong item class (class:%d=%s, subclass:%d)", 
            classID or 0, itemType or "unknown", subclassID or 0)
    end
    
    -- If it's in our safe list and has a container-like class, assume it's OK
    -- The real test is whether it's in the database - we're just double-checking
    return true, "OK"
end

-- Compare two strings with normalization (case-insensitive, ignore special chars)
local function NormalizeString(str)
    if not str then return "" end
    -- Remove special characters, convert to lowercase
    return str:lower():gsub("[%p%s]", "")
end

local function StringsMatch(str1, str2)
    return NormalizeString(str1) == NormalizeString(str2)
end

-- Calculate Levenshtein distance between two strings
local function LevenshteinDistance(s1, s2)
    s1 = s1:lower()
    s2 = s2:lower()
    local len1 = #s1
    local len2 = #s2
    local matrix = {}
    
    -- Initialize matrix
    for i = 0, len1 do
        matrix[i] = {[0] = i}
    end
    for j = 0, len2 do
        matrix[0][j] = j
    end
    
    -- Fill matrix
    for i = 1, len1 do
        for j = 1, len2 do
            local cost = (s1:sub(i,i) == s2:sub(j,j)) and 0 or 1
            matrix[i][j] = math.min(
                matrix[i-1][j] + 1,      -- deletion
                matrix[i][j-1] + 1,      -- insertion
                matrix[i-1][j-1] + cost  -- substitution
            )
        end
    end
    
    return matrix[len1][len2]
end

-- Calculate similarity score (0-100, where 100 is identical)
local function CalculateSimilarity(str1, str2)
    if not str1 or not str2 then return 0 end
    if str1 == str2 then return 100 end
    
    local maxLen = math.max(#str1, #str2)
    if maxLen == 0 then return 100 end
    
    local distance = LevenshteinDistance(str1, str2)
    local similarity = ((maxLen - distance) / maxLen) * 100
    
    return math.floor(similarity)
end

-- Categorize name mismatch severity
-- Returns: "minor" (>75% similar), "major" (<75% similar)
local function CategorizeMismatch(expected, actual)
    local similarity = CalculateSimilarity(expected, actual)
    
    if similarity >= 75 then
        return "minor", similarity
    else
        return "major", similarity
    end
end

-- Process a single item validation
local function ValidateItem(itemID, expectedName, containerType, retryCount)
    retryCount = retryCount or 0
    
    local result = {
        itemID = itemID,
        expectedName = expectedName,
        actualName = nil,
        actualLink = nil,
        exists = false,
        nameMatches = false,
        mismatchSeverity = nil,   -- "minor" or "major"
        similarity = nil,          -- 0-100 similarity score
        isUsable = false,
        usabilityReason = nil,
        containerType = containerType,
        needsRetry = false,
        retryCount = retryCount
    }
    
    -- Check if item data is cached before attempting to retrieve
    local isCached = C_Item.IsItemDataCachedByID(itemID)
    
    if not isCached then
        -- Request load and mark for retry
        C_Item.RequestLoadItemDataByID(itemID)
        result.needsRetry = true
        result.exists = false
        result.usabilityReason = "Data not cached (pending)"
        if retryCount == 0 then
            LogToFile(string.format("[%d] %s - Data not cached, requesting (attempt %d/%d)", 
                itemID, expectedName, retryCount + 1, MAX_RETRIES))
        end
        return result
    end
    
    -- Get item info from game using safe API
    local itemName, itemLink = C_Item.GetItemInfo(itemID)
    
    if itemName then
        result.exists = true
        result.actualName = itemName
        result.actualLink = itemLink
        result.nameMatches = StringsMatch(itemName, expectedName)
        
        -- If names don't match, calculate similarity
        if not result.nameMatches then
            local severity, similarity = CategorizeMismatch(expectedName, itemName)
            result.mismatchSeverity = severity
            result.similarity = similarity
            LogToFile(string.format("[%d] Name mismatch (%s, %d%% similar): '%s' vs '%s'", 
                itemID, severity, similarity, expectedName, itemName))
        end
        
        -- Check if it's usable (only for safe containers)
        if containerType == "safe" then
            local canUse, reason = IsInstantUse(itemID)
            result.isUsable = canUse
            result.usabilityReason = reason
            
            if not canUse then
                LogToFile(string.format("[%d] %s - Not usable: %s", itemID, itemName, reason))
            end
        end
    else
        -- Data is cached but GetItemInfo returns nil
        -- This might mean item doesn't exist OR data not fully loaded yet
        if retryCount < MAX_RETRIES then
            result.needsRetry = true
            LogToFile(string.format("[%d] %s - No data returned, retrying (attempt %d/%d)", 
                itemID, expectedName, retryCount + 1, MAX_RETRIES))
        else
            result.exists = false
            LogToFile(string.format("[%d] %s - DEPRECATED (not found after %d retries)", 
                itemID, expectedName, MAX_RETRIES))
        end
    end
    
    return result
end

-- Add item to query queue
local function QueueItemValidation(itemID, expectedName, containerType)
    -- Check if already in cache
    if itemQueryCache[itemID] then
        return
    end
    
    table.insert(queryQueue, {
        itemID = itemID,
        expectedName = expectedName,
        containerType = containerType
    })
    
    validationResults.itemsPending = validationResults.itemsPending + 1
end

-- Process batch of items from queue
local function ProcessQueryBatch()
    -- Check if we should process retries first
    if #queryQueue == 0 and #retryQueue > 0 then
        -- Move retry items back to main queue
        for _, item in ipairs(retryQueue) do
            table.insert(queryQueue, item)
        end
        retryQueue = {}
        DebugLog(string.format("Processing %d retry items", #queryQueue))
    end
    
    if #queryQueue == 0 then
        -- Scan complete
        if queryTimer then
            queryTimer:Cancel()
            queryTimer = nil
        end
        validationResults.isScanning = false
        validationResults.scanEndTime = time()
        FlushLog() -- Final log flush
        ContainerValidator.PrintReport()
        LogToFile("=== SCAN COMPLETE ===")
        DebugLog("Scan complete! Use /jqvalidate report for summary")
        return
    end
    
    local batchEnd = math.min(#queryQueue, BATCH_SIZE)
    local batch = {}
    
    for i = 1, batchEnd do
        local item = table.remove(queryQueue, 1)
        table.insert(batch, item)
    end
    
    -- Request item info for batch
    for _, item in ipairs(batch) do
        if not C_Item.IsItemDataCachedByID(item.itemID) then
            C_Item.RequestLoadItemDataByID(item.itemID)
        end
    end
    
    -- Process batch after delay
    C_Timer.After(0.5, function()
        for _, item in ipairs(batch) do
            local retryCount = item.retryCount or 0
            local result = ValidateItem(item.itemID, item.expectedName, item.containerType, retryCount)
            
            -- Check if this item needs retry
            if result.needsRetry and retryCount < MAX_RETRIES then
                -- Add to retry queue with incremented count
                table.insert(retryQueue, {
                    itemID = item.itemID,
                    expectedName = item.expectedName,
                    containerType = item.containerType,
                    retryCount = retryCount + 1
                })
                -- Don't mark as processed yet
                validationResults.itemsPending = validationResults.itemsPending -- keep count same
            else
                -- Item is done (success or max retries reached)
                itemQueryCache[item.itemID] = result
                
                local resultSet = validationResults[item.containerType]
                
                if not result.exists then
                    table.insert(resultSet.deprecated, result)
                elseif not result.nameMatches then
                    if result.mismatchSeverity == "minor" then
                        table.insert(resultSet.minorMismatch, result)
                    else
                        table.insert(resultSet.majorMismatch, result)
                    end
                elseif item.containerType == "safe" and not result.isUsable then
                    table.insert(resultSet.nonUsable, result)
                else
                    table.insert(resultSet.valid, result)
                end
                
                validationResults.itemsProcessed = validationResults.itemsProcessed + 1
                validationResults.itemsPending = validationResults.itemsPending - 1
            end
        end
        
        -- Concise progress update
        local totalItems = validationResults.itemsProcessed + validationResults.itemsPending
        if validationResults.itemsProcessed % 100 == 0 or validationResults.itemsPending < 10 then
            local pct = (validationResults.itemsProcessed / totalItems) * 100
            local retryCount = #retryQueue
            if retryCount > 0 then
                DebugLog(string.format("%.0f%% (%d/%d) | %d pending retry", 
                    pct, validationResults.itemsProcessed, totalItems, retryCount))
            else
                DebugLog(string.format("%.0f%% (%d/%d)", 
                    pct, validationResults.itemsProcessed, totalItems))
            end
        end
    end)
end

-- Start validation scan
function ContainerValidator.StartValidation()
    if validationResults.isScanning then
        DebugLog("Validation already in progress!")
        return
    end
    
    DebugLog("Starting ContainerDB validation...")
    
    -- Clear and initialize log
    ClearLog()
    LogToFile("=== ContainerDB Validation Started ===")
    LogToFile(string.format("Timestamp: %s", date("%Y-%m-%d %H:%M:%S")))
    
    -- Reset results
    validationResults = {
        safe = {
            valid = {},
            minorMismatch = {},
            majorMismatch = {},
            deprecated = {},
            nonUsable = {},
            total = 0
        },
        dangerous = {
            valid = {},
            minorMismatch = {},
            majorMismatch = {},
            deprecated = {},
            total = 0
        },
        scanStartTime = time(),
        scanEndTime = nil,
        itemsProcessed = 0,
        itemsPending = 0,
        isScanning = true
    }
    
    itemQueryCache = {}
    queryQueue = {}
    retryQueue = {}
    
    -- Queue all safe containers
    if JustQuest.Database and JustQuest.Database.SAFE_CONTAINERS then
        for itemID, itemName in pairs(JustQuest.Database.SAFE_CONTAINERS) do
            QueueItemValidation(itemID, itemName, "safe")
            validationResults.safe.total = validationResults.safe.total + 1
        end
        LogToFile(string.format("Queued %d safe containers", validationResults.safe.total))
    end
    
    -- Queue all dangerous containers
    if JustQuest.Database and JustQuest.Database.DANGEROUS_CONTAINERS then
        for itemID, itemName in pairs(JustQuest.Database.DANGEROUS_CONTAINERS) do
            QueueItemValidation(itemID, itemName, "dangerous")
            validationResults.dangerous.total = validationResults.dangerous.total + 1
        end
        DebugLog(string.format("Queued %d dangerous containers for validation", validationResults.dangerous.total))
    end
    
    DebugLog(string.format("Total items to validate: %d", validationResults.itemsPending))
    
    -- Start processing queue
    if JustQuest.AceTimer then
        queryTimer = JustQuest.AceTimer.ScheduleRepeatingTimer(JustQuest, ProcessQueryBatch, QUERY_DELAY)
    else
        -- Fallback to C_Timer if AceTimer not available
        local function ScheduleNext()
            if #queryQueue > 0 and validationResults.isScanning then
                ProcessQueryBatch()
                C_Timer.After(QUERY_DELAY, ScheduleNext)
            end
        end
        ScheduleNext()
    end
end

-- Stop validation scan
function ContainerValidator.StopValidation()
    if queryTimer then
        queryTimer:Cancel()
        queryTimer = nil
    end
    validationResults.isScanning = false
    validationResults.scanEndTime = time()
    DebugLog("Validation scan stopped by user")
end

-- Print validation report (concise)
function ContainerValidator.PrintReport()
    local results = validationResults
    
    print("\n|cFFFFD700=== ContainerDB Validation Report ===|r")
    
    if results.scanStartTime then
        local duration = (results.scanEndTime or time()) - results.scanStartTime
        print(string.format("Duration: %ds | Processed: %d items", duration, results.itemsProcessed))
    end
    
    -- Safe containers summary
    local safeTotal = results.safe.total
    local safeValid = #results.safe.valid
    local safeMinor = #results.safe.minorMismatch
    local safeMajor = #results.safe.majorMismatch
    local safeDeprecated = #results.safe.deprecated
    local safeNonUsable = #results.safe.nonUsable
    local safeIssues = safeMinor + safeMajor + safeDeprecated + safeNonUsable
    
    print(string.format("\n|cFF00FF00SAFE:|r %d total | %d OK | %d issues", safeTotal, safeValid, safeIssues))
    if safeIssues > 0 then
        if safeMinor > 0 then print(string.format("  Minor diffs: %d (update names)", safeMinor)) end
        if safeMajor > 0 then print(string.format("  |cFFFFAA00Major diffs: %d (review!)|r", safeMajor)) end
        if safeDeprecated > 0 then print(string.format("  |cFFFF0000Deprecated: %d (remove!)|r", safeDeprecated)) end
        if safeNonUsable > 0 then print(string.format("  Non-usable: %d (review)", safeNonUsable)) end
    end
    
    -- Dangerous containers summary
    local dangerTotal = results.dangerous.total
    local dangerValid = #results.dangerous.valid
    local dangerMinor = #results.dangerous.minorMismatch
    local dangerMajor = #results.dangerous.majorMismatch
    local dangerDeprecated = #results.dangerous.deprecated
    local dangerIssues = dangerMinor + dangerMajor + dangerDeprecated
    
    print(string.format("\n|cFFFF0000DANGEROUS:|r %d total | %d OK | %d issues", dangerTotal, dangerValid, dangerIssues))
    if dangerIssues > 0 then
        if dangerMinor > 0 then print(string.format("  Minor diffs: %d", dangerMinor)) end
        if dangerMajor > 0 then print(string.format("  |cFFFFAA00Major diffs: %d|r", dangerMajor)) end
        if dangerDeprecated > 0 then print(string.format("  |cFFFF0000Deprecated: %d|r", dangerDeprecated)) end
    end
    
    print("\nCommands: /jqvalidate issues | minor | major | deprecated | nonusable | export")
    print("Full log: Check SavedVariables\\JustQuest.lua (JustQuestDB.ValidatorLog)")
    print(string.rep("=", 60))
end

-- Print detailed issues
function ContainerValidator.PrintIssues(issueType)
    local results = validationResults
    
    if issueType == "deprecated" or issueType == "all" then
        print("\n|cFFFF0000DEPRECATED ITEMS (Not Found in Game)|r")
        print(string.rep("-", 80))
        
        if #results.safe.deprecated > 0 then
            print("|cFF00FF00Safe Containers:|r")
            for _, item in ipairs(results.safe.deprecated) do
                print(string.format("  [%d] %s", item.itemID, item.expectedName))
            end
        end
        
        if #results.dangerous.deprecated > 0 then
            print("\n|cFFFF0000Dangerous Containers:|r")
            for _, item in ipairs(results.dangerous.deprecated) do
                print(string.format("  [%d] %s", item.itemID, item.expectedName))
            end
        end
    end
    
    if issueType == "mismatch" or issueType == "minor" or issueType == "all" then
        print("\n|cFF88FF88MINOR NAME DIFFERENCES (>75% Similar - Just Update)|r")
        print(string.rep("-", 80))
        
        local hasMinor = false
        if #results.safe.minorMismatch > 0 then
            hasMinor = true
            print("|cFF00FF00Safe Containers:|r")
            for _, item in ipairs(results.safe.minorMismatch) do
                print(string.format("  [%d] (%d%% similar)", item.itemID, item.similarity))
                print(string.format("      Expected: %s", item.expectedName))
                print(string.format("      Actual:   %s", item.actualName))
            end
        end
        
        if #results.dangerous.minorMismatch > 0 then
            hasMinor = true
            print("\n|cFFFF0000Dangerous Containers:|r")
            for _, item in ipairs(results.dangerous.minorMismatch) do
                print(string.format("  [%d] (%d%% similar)", item.itemID, item.similarity))
                print(string.format("      Expected: %s", item.expectedName))
                print(string.format("      Actual:   %s", item.actualName))
            end
        end
        
        if not hasMinor then
            print("  None found!")
        end
    end
    
    if issueType == "mismatch" or issueType == "major" or issueType == "all" then
        print("\n|cFFFFAA00MAJOR NAME MISMATCHES (<75% Similar - Review/Remove)|r")
        print(string.rep("-", 80))
        
        local hasMajor = false
        if #results.safe.majorMismatch > 0 then
            hasMajor = true
            print("|cFF00FF00Safe Containers:|r")
            for _, item in ipairs(results.safe.majorMismatch) do
                print(string.format("  [%d] (%d%% similar) |cFFFF0000⚠ REVIEW|r", item.itemID, item.similarity))
                print(string.format("      Expected: %s", item.expectedName))
                print(string.format("      Actual:   %s", item.actualName))
            end
        end
        
        if #results.dangerous.majorMismatch > 0 then
            hasMajor = true
            print("\n|cFFFF0000Dangerous Containers:|r")
            for _, item in ipairs(results.dangerous.majorMismatch) do
                print(string.format("  [%d] (%d%% similar) |cFFFF0000⚠ REVIEW|r", item.itemID, item.similarity))
                print(string.format("      Expected: %s", item.expectedName))
                print(string.format("      Actual:   %s", item.actualName))
            end
        end
        
        if not hasMajor then
            print("  None found!")
        end
    end
    
    if issueType == "nonusable" or issueType == "all" then
        print("\n|cFFFF6600NON-USABLE ITEMS (May require interaction)|r")
        print(string.rep("-", 80))
        
        if #results.safe.nonUsable > 0 then
            for _, item in ipairs(results.safe.nonUsable) do
                print(string.format("  [%d] %s (%s) - Reason: %s", 
                    item.itemID, item.actualName or item.expectedName, 
                    item.actualLink or "No Link", item.usabilityReason or "Unknown"))
            end
        else
            print("  None found!")
        end
    end
end

-- Export results to a formatted string for copying
function ContainerValidator.ExportResults()
    local output = {}
    local results = validationResults
    
    table.insert(output, "JustQuest ContainerDB Validation Export")
    table.insert(output, "Generated: " .. date("%Y-%m-%d %H:%M:%S"))
    table.insert(output, "")
    
    -- Deprecated items to remove
    table.insert(output, "=== DEPRECATED ITEMS (REMOVE FROM DB) ===")
    for _, item in ipairs(results.safe.deprecated) do
        table.insert(output, string.format("[%d] = %q, -- SAFE - DEPRECATED", item.itemID, item.expectedName))
    end
    for _, item in ipairs(results.dangerous.deprecated) do
        table.insert(output, string.format("[%d] = %q, -- DANGEROUS - DEPRECATED", item.itemID, item.expectedName))
    end
    
    -- Minor name differences (safe to update)
    table.insert(output, "")
    table.insert(output, "=== MINOR NAME DIFFERENCES (UPDATE DB - >75%% SIMILAR) ===")
    for _, item in ipairs(results.safe.minorMismatch) do
        table.insert(output, string.format("[%d] = %q, -- SAFE - Was: %q (%d%% similar)", 
            item.itemID, item.actualName, item.expectedName, item.similarity))
    end
    for _, item in ipairs(results.dangerous.minorMismatch) do
        table.insert(output, string.format("[%d] = %q, -- DANGEROUS - Was: %q (%d%% similar)", 
            item.itemID, item.actualName, item.expectedName, item.similarity))
    end
    
    -- Major name mismatches (review carefully)
    table.insert(output, "")
    table.insert(output, "=== MAJOR NAME MISMATCHES (REVIEW/REMOVE - <75%% SIMILAR) ===")
    for _, item in ipairs(results.safe.majorMismatch) do
        table.insert(output, string.format("[%d] = %q, -- SAFE - Was: %q (%d%% similar) ⚠ VERIFY", 
            item.itemID, item.actualName, item.expectedName, item.similarity))
    end
    for _, item in ipairs(results.dangerous.majorMismatch) do
        table.insert(output, string.format("[%d] = %q, -- DANGEROUS - Was: %q (%d%% similar) ⚠ VERIFY", 
            item.itemID, item.actualName, item.expectedName, item.similarity))
    end
    
    -- Non-usable items
    table.insert(output, "")
    table.insert(output, "=== NON-USABLE ITEMS (REVIEW) ===")
    for _, item in ipairs(results.safe.nonUsable) do
        table.insert(output, string.format("[%d] = %q, -- %s", 
            item.itemID, item.actualName or item.expectedName, item.usabilityReason))
    end
    
    local exportText = table.concat(output, "\n")
    
    -- Try to create a frame to show the export text
    ContainerValidator.ShowExportFrame(exportText)
    
    return exportText
end

-- Create export frame
function ContainerValidator.ShowExportFrame(text)
    if not ContainerValidatorExportFrame then
        local frame = CreateFrame("Frame", "ContainerValidatorExportFrame", UIParent, "BasicFrameTemplateWithInset")
        frame:SetSize(600, 400)
        frame:SetPoint("CENTER")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame.title = frame:CreateFontString(nil, "OVERLAY")
        frame.title:SetFontObject("GameFontHighlight")
        frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 5, 0)
        frame.title:SetText("ContainerDB Validation Export")
        
        local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
        scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)
        
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetWidth(550)
        editBox:SetAutoFocus(false)
        editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
        
        scrollFrame:SetScrollChild(editBox)
        frame.editBox = editBox
    end
    
    ContainerValidatorExportFrame.editBox:SetText(text)
    ContainerValidatorExportFrame.editBox:HighlightText()
    ContainerValidatorExportFrame:Show()
end

-- Slash command handler
SLASH_JQVALIDATE1 = "/jqvalidate"
SlashCmdList["JQVALIDATE"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "start" or msg == "" then
        ContainerValidator.StartValidation()
    elseif msg == "stop" then
        ContainerValidator.StopValidation()
    elseif msg == "report" then
        ContainerValidator.PrintReport()
    elseif msg == "issues" or msg == "all" then
        ContainerValidator.PrintIssues("all")
    elseif msg == "deprecated" then
        ContainerValidator.PrintIssues("deprecated")
    elseif msg == "mismatch" then
        ContainerValidator.PrintIssues("mismatch")
    elseif msg == "minor" then
        ContainerValidator.PrintIssues("minor")
    elseif msg == "major" then
        ContainerValidator.PrintIssues("major")
    elseif msg == "nonusable" then
        ContainerValidator.PrintIssues("nonusable")
    elseif msg == "export" then
        ContainerValidator.ExportResults()
    elseif msg == "log" then
        FlushLog()
        local logCount = JustQuestDB and JustQuestDB.ContainerValidatorLog and #JustQuestDB.ContainerValidatorLog or 0
        print(string.format("|cFF00FF00Log flushed!|r %d entries saved", logCount))
        print("|cFFFFAA00Location:|r WTF\\Account\\<YourAccount>\\SavedVariables\\JustQuest.lua")
        print("|cFFFFAA00Variable:|r JustQuestDB.ContainerValidatorLog")
        if logCount > 0 then
            print(string.format("|cFF88FF88Tip:|r Use /jqvalidate clearlog to reset (%d lines)", logCount))
        end
    elseif msg == "clearlog" then
        local oldCount = JustQuestDB and JustQuestDB.ContainerValidatorLog and #JustQuestDB.ContainerValidatorLog or 0
        local oldValidatorLog = JustQuestDB and JustQuestDB.ValidatorLog and #JustQuestDB.ValidatorLog or 0
        local hadOldLogs = JustQuestDB and JustQuestDB.validationLogs and #JustQuestDB.validationLogs or 0
        ClearLog()
        FlushLog() -- Ensure SavedVariables are updated
        print("|cFF00FF00Validation log cleared!|r")
        if oldCount > 0 then
            print(string.format("|cFF888888Removed %d current log entries|r", oldCount))
        end
        if oldValidatorLog > 0 then
            print(string.format("|cFF888888Removed %d old ValidatorLog entries|r", oldValidatorLog))
        end
        if hadOldLogs > 0 then
            print(string.format("|cFF888888Cleaned up %d old validation reports|r", hadOldLogs))
        end
        print("|cFFFFAA00SavedVariables size reduced|r - Changes saved on logout/reload")
    else
        print("|cFFFFD700JustQuest Container Validator|r")
        print("  /jqvalidate [start] - Begin validation scan")
        print("  /jqvalidate report - Summary (use after scan)")
        print("  /jqvalidate issues - Show all issues")
        print("  /jqvalidate minor - Minor name diffs (>75% similar)")
        print("  /jqvalidate major - Major mismatches (<75% similar)")
        print("  /jqvalidate deprecated - Items not found in game")
        print("  /jqvalidate nonusable - Items that can't auto-open")
        print("  /jqvalidate export - Export fixes")
        print("  /jqvalidate log - Flush & show log file location")
        print("  /jqvalidate stop - Cancel scan")
    end
end

-- Silently loaded - use /jqvalidate to start
-- DebugLog("ContainerValidator loaded. Use /jqvalidate to start.")

