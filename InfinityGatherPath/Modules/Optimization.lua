-- Optimization Module
-- Optimize routes using simple pathfinding

local InfinityOptimization = {}
_G.InfinityOptimization = InfinityOptimization

function InfinityOptimization:CalculateDistance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function InfinityOptimization:OptimizeRoute(nodes)
    if not nodes or #nodes < 2 then return nodes or {} end
    
    -- Simple nearest-neighbor approach
    local optimized = {}
    local remaining = {}
    
    -- Copy nodes
    for i, node in ipairs(nodes) do
        table.insert(remaining, node)
    end
    
    -- Start with first node
    table.insert(optimized, table.remove(remaining, 1))
    
    -- Build route by always adding nearest unvisited node
    while #remaining > 0 do
        local current = optimized[#optimized]
        local nearest_idx = 1
        local nearest_dist = math.huge
        
        for i, node in ipairs(remaining) do
            local dist = self:CalculateDistance(current.x, current.y, node.x, node.y)
            if dist < nearest_dist then
                nearest_dist = dist
                nearest_idx = i
            end
        end
        
        table.insert(optimized, table.remove(remaining, nearest_idx))
    end
    
    return optimized
end

function InfinityOptimization:CalculateTotalDistance(nodes)
    local totalDistance = 0
    
    for i = 1, #nodes - 1 do
        local dist = self:CalculateDistance(nodes[i].x, nodes[i].y, 
                                            nodes[i + 1].x, nodes[i + 1].y)
        totalDistance = totalDistance + dist
    end
    
    return totalDistance
end

function InfinityOptimization:EstimateTime(nodes, speed)
    speed = speed or 7 -- yards per second
    local distance = self:CalculateTotalDistance(nodes)
    return distance / speed
end

function InfinityOptimization:EstimateProfit(nodes, pricePerNode)
    pricePerNode = pricePerNode or 100
    return #nodes * pricePerNode
end

return InfinityOptimization
