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

function InfinityQuestRouter:GetWaypoint(questID)
    local quest = InfinityQuestDB:GetQuest(questID)
    if not quest then return nil end
    
    return {
        x = math.random(1, 100),
        y = math.random(1, 100),
        zone = quest.zone,
        name = quest.name,
    }
end

return InfinityQuestRouter
