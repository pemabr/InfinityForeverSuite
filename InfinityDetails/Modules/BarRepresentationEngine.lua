-- BarRepresentationEngine.lua - Create visual bar representations of rankings
-- Part of InfinityDetails addon suite
-- Shows player rankings, damage distribution, etc. as bar graphs

local BarRepresentationEngine = {}
BarRepresentationEngine.enabled = false
BarRepresentationEngine.db = nil
BarRepresentationEngine.bar_data = {}

-- Configuration
BarRepresentationEngine.config = {
    enabled = true,
    max_bars = 50,  -- Max bars to display
    sort_interval = 1,  -- Resort every 1 second
}

function BarRepresentationEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.bar_data then
        self.db.bar_data = {}
    end
    
    self.bar_data = self.db.bar_data
    self.enabled = true
    
    self:Log("Initialized bar representation engine")
end

function BarRepresentationEngine:CreateBarSet(setName, barType)
    if not setName or not barType then
        return nil
    end
    
    local barSet = {
        id = "bars_" .. GetTime(),
        name = setName,
        type = barType,  -- dps, hps, threat, healing_taken, etc.
        created_at = GetTime(),
        bars = {},
        sorted_at = 0,
        max_value = 0,
    }
    
    table.insert(self.bar_data, barSet)
    self:Log("Created bar set: " .. setName .. " (" .. barType .. ")")
    
    return barSet
end

function BarRepresentationEngine:AddBar(barSetId, barName, barValue, barColor)
    local barSet = self:GetBarSet(barSetId)
    if not barSet then
        return false
    end
    
    if #barSet.bars >= self.config.max_bars then
        self:Log("Max bars reached for set: " .. barSet.name)
        return false
    end
    
    barColor = barColor or "ffffff"  -- Default white
    
    local bar = {
        name = barName,
        value = barValue or 0,
        color = barColor,
        percent = 0,
    }
    
    table.insert(barSet.bars, bar)
    
    if barValue > barSet.max_value then
        barSet.max_value = barValue
    end
    
    return true
end

function BarRepresentationEngine:UpdateBar(barSetId, barName, newValue)
    local barSet = self:GetBarSet(barSetId)
    if not barSet then
        return false
    end
    
    for _, bar in ipairs(barSet.bars) do
        if bar.name == barName then
            bar.value = newValue or 0
            
            if newValue > barSet.max_value then
                barSet.max_value = newValue
            end
            
            return true
        end
    end
    
    return false
end

function BarRepresentationEngine:GetBarSet(barSetId)
    for _, barSet in ipairs(self.bar_data) do
        if barSet.id == barSetId then
            return barSet
        end
    end
    
    return nil
end

function BarRepresentationEngine:SortBars(barSetId, ascending)
    local barSet = self:GetBarSet(barSetId)
    if not barSet then
        return false
    end
    
    table.sort(barSet.bars, function(a, b)
        if ascending then
            return a.value < b.value
        else
            return a.value > b.value
        end
    end)
    
    barSet.sorted_at = GetTime()
    
    return true
end

function BarRepresentationEngine:CalculateBarPercents(barSetId)
    local barSet = self:GetBarSet(barSetId)
    if not barSet or barSet.max_value == 0 then
        return false
    end
    
    for _, bar in ipairs(barSet.bars) do
        bar.percent = (bar.value / barSet.max_value) * 100
    end
    
    return true
end

function BarRepresentationEngine:GetTopBars(barSetId, limit)
    local barSet = self:GetBarSet(barSetId)
    if not barSet then
        return {}
    end
    
    limit = limit or 10
    
    self:SortBars(barSetId, false)  -- Sort descending
    self:CalculateBarPercents(barSetId)
    
    local results = {}
    for i = 1, math.min(limit, #barSet.bars) do
        table.insert(results, barSet.bars[i])
    end
    
    return results
end

function BarRepresentationEngine:GetBottomBars(barSetId, limit)
    local barSet = self:GetBarSet(barSetId)
    if not barSet then
        return {}
    end
    
    limit = limit or 10
    
    self:SortBars(barSetId, true)  -- Sort ascending
    self:CalculateBarPercents(barSetId)
    
    local results = {}
    for i = 1, math.min(limit, #barSet.bars) do
        table.insert(results, barSet.bars[i])
    end
    
    return results
end

function BarRepresentationEngine:GetBarAsciiRepresentation(barSetId, width, limit)
    local barSet = self:GetBarSet(barSetId)
    if not barSet then
        return ""
    end
    
    width = width or 40
    limit = limit or 10
    
    self:SortBars(barSetId, false)
    self:CalculateBarPercents(barSetId)
    
    local ascii = ""
    
    for i = 1, math.min(limit, #barSet.bars) do
        local bar = barSet.bars[i]
        local barLength = math.ceil((bar.percent / 100) * width)
        
        ascii = ascii .. string.format("%-15s", bar.name:sub(1, 15))
        ascii = ascii .. " ["
        
        for j = 1, width do
            if j <= barLength then
                ascii = ascii .. "="
            else
                ascii = ascii .. " "
            end
        end
        
        ascii = ascii .. "] " .. string.format("%.0f (%.1f%%)\n", bar.value, bar.percent)
    end
    
    return ascii
end

function BarRepresentationEngine:GetBarTableRepresentation(barSetId, limit)
    local barSet = self:GetBarSet(barSetId)
    if not barSet then
        return {}
    end
    
    limit = limit or 10
    
    self:SortBars(barSetId, false)
    self:CalculateBarPercents(barSetId)
    
    local results = {}
    
    for i = 1, math.min(limit, #barSet.bars) do
        local bar = barSet.bars[i]
        table.insert(results, {
            rank = i,
            name = bar.name,
            value = bar.value,
            percent = bar.percent,
            color = bar.color,
        })
    end
    
    return results
end

function BarRepresentationEngine:DeleteBarSet(barSetId)
    for i, barSet in ipairs(self.bar_data) do
        if barSet.id == barSetId then
            table.remove(self.bar_data, i)
            self:Log("Deleted bar set: " .. barSet.name)
            return true
        end
    end
    
    return false
end

function BarRepresentationEngine:ClearOldBarSets(minutesOld)
    minutesOld = minutesOld or 10
    local cutoffTime = GetTime() - (minutesOld * 60)
    local newData = {}
    
    for _, barSet in ipairs(self.bar_data) do
        if barSet.created_at > cutoffTime then
            table.insert(newData, barSet)
        end
    end
    
    self.bar_data = newData
    self.db.bar_data = newData
    
    self:Log("Cleared bar sets older than " .. minutesOld .. " minutes")
end

function BarRepresentationEngine:GetStatus()
    return {
        enabled = self.enabled,
        total_bar_sets = #self.bar_data,
        max_bars_per_set = self.config.max_bars,
    }
end

function BarRepresentationEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[BarRepresentationEngine] " .. message)
    else
        print("[BarRepresentationEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_BAR1 = "/bar"
    SlashCmdList["BAR"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "list" then
            local sets = BarRepresentationEngine.bar_data
            print("Bar Sets (" .. #sets .. "):")
            for i, barSet in ipairs(sets) do
                print("  [" .. i .. "] " .. barSet.name .. " (" .. barSet.type .. ")")
                print("       Bars: " .. #barSet.bars .. " | Max: " .. string.format("%.0f", barSet.max_value))
            end
        elseif cmd == "view" then
            local index = tonumber(args) or #BarRepresentationEngine.bar_data
            local barSet = BarRepresentationEngine.bar_data[index]
            
            if barSet then
                local ascii = BarRepresentationEngine:GetBarAsciiRepresentation(barSet.id, 40, 10)
                print(barSet.name .. " (" .. barSet.type .. "):")
                print(ascii)
            else
                print("Bar set not found")
            end
        elseif cmd == "table" then
            local index = tonumber(args) or #BarRepresentationEngine.bar_data
            local barSet = BarRepresentationEngine.bar_data[index]
            
            if barSet then
                local table = BarRepresentationEngine:GetBarTableRepresentation(barSet.id, 10)
                print(barSet.name .. ":")
                for _, row in ipairs(table) do
                    print(string.format("  [%2d] %-20s: %10.0f (%.1f%%)", 
                                      row.rank, row.name, row.value, row.percent))
                end
            else
                print("Bar set not found")
            end
        elseif cmd == "delete" then
            local index = tonumber(args)
            if index and BarRepresentationEngine.bar_data[index] then
                local barSet = BarRepresentationEngine.bar_data[index]
                BarRepresentationEngine:DeleteBarSet(barSet.id)
                print("Deleted bar set: " .. barSet.name)
            else
                print("Invalid bar set index")
            end
        elseif cmd == "status" then
            local status = BarRepresentationEngine:GetStatus()
            print("Bar Representation:")
            print("  Total Sets: " .. status.total_bar_sets)
            print("  Max Bars per Set: " .. status.max_bars_per_set)
        else
            print("Bar Commands:")
            print("  /bar list - List all bar sets")
            print("  /bar view [index] - View bars as ASCII")
            print("  /bar table [index] - View bars as table")
            print("  /bar delete [index] - Delete bar set")
            print("  /bar status - Show system status")
        end
    end
end

return BarRepresentationEngine
