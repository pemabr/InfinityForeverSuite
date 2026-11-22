-- Router Module
-- Optimize quest routes

local InfinityQuestRouter = {}
_G.InfinityQuestRouter = InfinityQuestRouter

function InfinityQuestRouter:CalculateRoute(questIDs, startZone)
    if not questIDs or #questIDs == 0 then return {} end
    
    local route = {
        questIDs = questIDs,
        waypoints = {},
        total_distance = 0,
        estimated_time = 0,
    }
    
    for _, questID in ipairs(questIDs) do
        local quest = InfinityQuestDB:GetQuest(questID)
        if quest then
            table.insert(route.waypoints, {
                questID = questID,
                name = quest.name,
                zone = quest.zone,
                giver = quest.giver,
            })
        end
    end
    
    return route
end

function InfinityQuestRouter:OptimizeRoute(questIDs, currentZone)
    local quest_by_zone = {}
    
    for _, questID in ipairs(questIDs) do
        local quest = InfinityQuestDB:GetQuest(questID)
        if quest then
            if not quest_by_zone[quest.zone] then
                quest_by_zone[quest.zone] = {}
            end
            table.insert(quest_by_zone[quest.zone], questID)
        end
    end
    
    local route = {}
    for zone, questsInZone in pairs(quest_by_zone) do
        for _, questID in ipairs(questsInZone) do
            table.insert(route, questID)
        end
    end
    
    return route
end

local function Public(value)
    if _G.issecretvalue and _G.issecretvalue(value) then return nil end
    return value
end

local function ValidCoordinate(value)
    return type(value) == "number" and value == value and value >= 0 and value <= 1
end

function InfinityQuestRouter:GetPlayerPosition()
    local map = _G.C_Map
    if not map or not map.GetBestMapForUnit or not map.GetPlayerMapPosition then return nil end
    local mapID = Public(map.GetBestMapForUnit("player"))
    if type(mapID) ~= "number" or mapID <= 0 or mapID >= math.huge or mapID ~= math.floor(mapID) then return nil end
    local position = Public(map.GetPlayerMapPosition(mapID, "player"))
    if type(position) ~= "table" and type(position) ~= "userdata" then return nil end
    local x, y = Public(position.x), Public(position.y)
    if (x == nil or y == nil) and type(position.GetXY) == "function" then
        x, y = position:GetXY()
        x, y = Public(x), Public(y)
    end
    if not ValidCoordinate(x) or not ValidCoordinate(y) or (x == 0 and y == 0) then return nil end
    return { mapID = mapID, x = x, y = y }
end

function InfinityQuestRouter:GetWaypoint(questID)
    questID = Public(questID)
    if type(questID) ~= "number" or questID <= 0 or questID >= math.huge or questID ~= math.floor(questID)
        or not _G.C_QuestLog or not _G.C_QuestLog.GetNextWaypoint then return nil end
    local mapID, x, y = _G.C_QuestLog.GetNextWaypoint(questID)
    mapID, x, y = Public(mapID), Public(x), Public(y)
    if type(mapID) ~= "number" or mapID ~= mapID or mapID <= 0 or mapID >= math.huge or mapID ~= math.floor(mapID)
        or not ValidCoordinate(x) or not ValidCoordinate(y)
        or (x == 0 and y == 0) then return nil end
    return { mapID = mapID, x = x, y = y }
end

function InfinityQuestRouter:BuildRoute(quests)
    local position = self:GetPlayerPosition()
    local nearby, other, missing, route = {}, {}, {}, {}
    for _, quest in ipairs(quests) do
        local point = self:GetWaypoint(quest.id)
        local entry = { quest = quest, point = point }
        if not point then
            missing[#missing + 1] = entry
        elseif position and point.mapID == position.mapID then
            nearby[#nearby + 1] = entry
        else
            other[#other + 1] = entry
        end
    end
    if position then
        local x, y = position.x, position.y
        while #nearby > 0 do
            local best, distance = 1, math.huge
            for index, entry in ipairs(nearby) do
                local dx, dy = entry.point.x - x, entry.point.y - y
                local candidate = dx * dx + dy * dy
                if candidate < distance then best, distance = index, candidate end
            end
            local nextEntry = table.remove(nearby, best)
            route[#route + 1] = nextEntry
            x, y = nextEntry.point.x, nextEntry.point.y
        end
    end
    for _, entry in ipairs(other) do route[#route + 1] = entry end
    for _, entry in ipairs(missing) do route[#route + 1] = entry end
    return route, position ~= nil
end

function InfinityQuestRouter:ShowWaypoint(questID)
    local point = self:GetWaypoint(questID)
    if not point then
        if _G.InfinityQuestieUI and _G.InfinityQuestLocations then
            return _G.InfinityQuestieUI:ShowLocations(questID)
        end
        InfinityUtils:Warning("No public waypoint is available for this quest.", "Questie")
        return false
    end
    return self:SetWaypoint(point)
end

function InfinityQuestRouter:SetWaypoint(point)
    point = Public(point)
    if type(point) ~= "table" then
        InfinityUtils:Warning("Invalid quest waypoint.", "Questie")
        return false
    end
    return InfinityUtils:SetUserWaypoint(point.mapID, point.x, point.y, "Questie")
end

return InfinityQuestRouter
