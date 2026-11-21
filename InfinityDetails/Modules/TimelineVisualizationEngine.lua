-- TimelineVisualizationEngine.lua - Render damage/healing graphs
-- Part of InfinityDetails addon suite
-- Creates visual representations of combat data over time

local TimelineVisualizationEngine = {}
TimelineVisualizationEngine.enabled = false
TimelineVisualizationEngine.db = nil
TimelineVisualizationEngine.graphs = {}

-- Configuration
TimelineVisualizationEngine.config = {
    enabled = true,
    max_graphs = 5,
    render_quality = "high",  -- low, medium, high
}

function TimelineVisualizationEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.graphs then
        self.db.graphs = {}
    end
    
    self.graphs = self.db.graphs
    self.enabled = true
    
    self:Log("Initialized timeline visualization engine")
end

function TimelineVisualizationEngine:CreateGraph(graphName, graphType, timelineData)
    if not graphName or not graphType or not timelineData then
        return nil
    end
    
    if #self.graphs >= self.config.max_graphs then
        self:Log("Max graphs reached (" .. self.config.max_graphs .. ")")
        return nil
    end
    
    local graph = {
        id = "graph_" .. GetTime(),
        name = graphName,
        type = graphType,  -- dps, hps, threat, etc.
        created_at = GetTime(),
        data_points = {},
        min_value = 0,
        max_value = 0,
        average_value = 0,
        peak_value = 0,
        peak_time = 0,
    }
    
    -- Process timeline data
    if type(timelineData) == "table" then
        graph.data_points = timelineData
        graph = self:CalculateGraphStats(graph)
    end
    
    table.insert(self.graphs, graph)
    self:Log("Created graph: " .. graphName .. " (" .. graphType .. ")")
    
    return graph
end

function TimelineVisualizationEngine:CalculateGraphStats(graph)
    if not graph.data_points or #graph.data_points == 0 then
        return graph
    end
    
    local sum = 0
    local min = math.huge
    local max = 0
    
    for _, point in ipairs(graph.data_points) do
        local value = point.value or point.total or 0
        
        sum = sum + value
        
        if value < min then
            min = value
        end
        
        if value > max then
            max = value
            graph.peak_value = value
            graph.peak_time = point.time or 0
        end
    end
    
    graph.min_value = min == math.huge and 0 or min
    graph.max_value = max
    graph.average_value = sum / #graph.data_points
    
    return graph
end

function TimelineVisualizationEngine:GetGraph(graphId)
    for _, graph in ipairs(self.graphs) do
        if graph.id == graphId then
            return graph
        end
    end
    
    return nil
end

function TimelineVisualizationEngine:GetGraphsByType(graphType)
    local results = {}
    
    for _, graph in ipairs(self.graphs) do
        if graph.type == graphType then
            table.insert(results, graph)
        end
    end
    
    return results
end

function TimelineVisualizationEngine:GenerateGraphPoints(dataTimeline, bucketSize)
    if not dataTimeline or #dataTimeline == 0 then
        return {}
    end
    
    bucketSize = bucketSize or 1
    local points = {}
    
    for i, timelineData in ipairs(dataTimeline) do
        table.insert(points, {
            time = i * bucketSize,
            value = timelineData.total or 0,
            count = timelineData.count or 0,
            max = timelineData.max or 0,
        })
    end
    
    return points
end

function TimelineVisualizationEngine:GetGraphPointsForTimeRange(graphId, startTime, endTime)
    local graph = self:GetGraph(graphId)
    if not graph then
        return {}
    end
    
    local results = {}
    
    for _, point in ipairs(graph.data_points) do
        if point.time >= startTime and point.time <= endTime then
            table.insert(results, point)
        end
    end
    
    return results
end

function TimelineVisualizationEngine:ScaleGraphToResolution(graphId, width, height)
    local graph = self:GetGraph(graphId)
    if not graph or #graph.data_points == 0 then
        return false
    end
    
    local scaledPoints = {}
    local dataRange = graph.max_value - graph.min_value
    
    if dataRange == 0 then
        dataRange = 1
    end
    
    for i, point in ipairs(graph.data_points) do
        local scaledX = (i / #graph.data_points) * width
        local scaledY = ((point.value - graph.min_value) / dataRange) * height
        
        table.insert(scaledPoints, {
            x = scaledX,
            y = scaledY,
            original = point,
        })
    end
    
    graph.scaled_points = scaledPoints
    
    return true
end

function TimelineVisualizationEngine:GetGraphSVGData(graphId)
    local graph = self:GetGraph(graphId)
    if not graph or not graph.scaled_points or #graph.scaled_points == 0 then
        return nil
    end
    
    local svgWidth = 400
    local svgHeight = 200
    local strokeWidth = 2
    
    -- Start SVG
    local svg = '<svg width="' .. svgWidth .. '" height="' .. svgHeight .. '">'
    
    -- Draw background
    svg = svg .. '<rect width="' .. svgWidth .. '" height="' .. svgHeight .. '" fill="#1a1a1a" />'
    
    -- Draw grid lines
    for i = 0, 10 do
        local y = (i / 10) * svgHeight
        svg = svg .. '<line x1="0" y1="' .. y .. '" x2="' .. svgWidth .. '" y2="' .. y .. '" stroke="#333" stroke-width="1" />'
    end
    
    -- Draw data line
    svg = svg .. '<polyline points="'
    
    for _, point in ipairs(graph.scaled_points) do
        svg = svg .. point.x .. ',' .. (svgHeight - point.y) .. ' '
    end
    
    svg = svg .. '" fill="none" stroke="#00ff00" stroke-width="' .. strokeWidth .. '" />'
    
    -- Draw peak marker
    if graph.peak_value > 0 then
        local peakScaled = self:ScaleGraphToResolution(graphId, svgWidth, svgHeight)
        svg = svg .. '<circle cx="' .. graph.peak_time .. '" cy="' .. (svgHeight - 
               ((graph.peak_value - graph.min_value) / (graph.max_value - graph.min_value)) * svgHeight) .. 
               '" r="3" fill="#ff0000" />'
    end
    
    -- Close SVG
    svg = svg .. '</svg>'
    
    return svg
end

function TimelineVisualizationEngine:DeleteGraph(graphId)
    for i, graph in ipairs(self.graphs) do
        if graph.id == graphId then
            table.remove(self.graphs, i)
            self:Log("Deleted graph: " .. graph.name)
            return true
        end
    end
    
    return false
end

function TimelineVisualizationEngine:ExportGraphAsImage(graphId, format)
    format = format or "svg"
    
    local graph = self:GetGraph(graphId)
    if not graph then
        return nil
    end
    
    if format == "svg" then
        return self:GetGraphSVGData(graphId)
    elseif format == "text" then
        return self:GetGraphAsText(graph)
    end
    
    return nil
end

function TimelineVisualizationEngine:GetGraphAsText(graph)
    local text = ""
    text = text .. "Graph: " .. graph.name .. "\n"
    text = text .. "Type: " .. graph.type .. "\n"
    text = text .. "Peak: " .. string.format("%.0f", graph.peak_value) .. " at " .. 
           string.format("%.1f", graph.peak_time) .. "s\n"
    text = text .. "Average: " .. string.format("%.0f", graph.average_value) .. "\n"
    text = text .. "Min: " .. string.format("%.0f", graph.min_value) .. "\n"
    text = text .. "Max: " .. string.format("%.0f", graph.max_value) .. "\n"
    
    return text
end

function TimelineVisualizationEngine:GetStatus()
    return {
        enabled = self.enabled,
        total_graphs = #self.graphs,
        max_graphs = self.config.max_graphs,
        render_quality = self.config.render_quality,
    }
end

function TimelineVisualizationEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[TimelineVisualizationEngine] " .. message)
    else
        print("[TimelineVisualizationEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_GRAPH1 = "/graph"
    SlashCmdList["GRAPH"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "list" then
            local graphs = TimelineVisualizationEngine.graphs
            print("Graphs (" .. #graphs .. "/" .. TimelineVisualizationEngine.config.max_graphs .. "):")
            for i, graph in ipairs(graphs) do
                print("  [" .. i .. "] " .. graph.name .. " (" .. graph.type .. ")")
                print("       Peak: " .. string.format("%.0f", graph.peak_value))
            end
        elseif cmd == "view" then
            local index = tonumber(args) or #TimelineVisualizationEngine.graphs
            local graph = TimelineVisualizationEngine.graphs[index]
            
            if graph then
                print(TimelineVisualizationEngine:GetGraphAsText(graph))
            else
                print("Graph not found")
            end
        elseif cmd == "export" then
            local index = tonumber(args) or #TimelineVisualizationEngine.graphs
            local graph = TimelineVisualizationEngine.graphs[index]
            
            if graph then
                local svg = TimelineVisualizationEngine:ExportGraphAsImage(graph.id, "svg")
                if svg then
                    print("SVG Generated (" .. string.len(svg) .. " chars)")
                else
                    print("Failed to generate SVG")
                end
            else
                print("Graph not found")
            end
        elseif cmd == "delete" then
            local index = tonumber(args)
            if index and TimelineVisualizationEngine.graphs[index] then
                local graph = TimelineVisualizationEngine.graphs[index]
                TimelineVisualizationEngine:DeleteGraph(graph.id)
                print("Deleted graph: " .. graph.name)
            else
                print("Invalid graph index")
            end
        elseif cmd == "status" then
            local status = TimelineVisualizationEngine:GetStatus()
            print("Graph System:")
            print("  Graphs: " .. status.total_graphs .. "/" .. status.max_graphs)
            print("  Quality: " .. status.render_quality)
        else
            print("Graph Commands:")
            print("  /graph list - List all graphs")
            print("  /graph view [index] - View graph stats")
            print("  /graph export [index] - Export as SVG")
            print("  /graph delete [index] - Delete graph")
            print("  /graph status - Show system status")
        end
    end
end

return TimelineVisualizationEngine
