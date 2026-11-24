-- QuestGuidanceEngine.lua - Automated guidance to quest objectives
-- Part of PluribusQuestie addon suite
-- Provides real-time guidance to current quest objective

local QuestGuidanceEngine = {}
QuestGuidanceEngine.enabled = false
QuestGuidanceEngine.db = nil
QuestGuidanceEngine.guidance_sessions = {}
QuestGuidanceEngine.current_guidance = nil

-- Configuration
QuestGuidanceEngine.config = {
    enabled = true,
    auto_update = true,
    update_interval = 1,  -- Update guidance every second
    guidance_text_length = 120,
    enable_waypoint_markers = true,
    enable_progress_tracking = true,
}

function QuestGuidanceEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.guidance_sessions then
        self.db.guidance_sessions = {}
    end
    
    self.guidance_sessions = self.db.guidance_sessions
    self.enabled = true
    
    self:Log("Initialized quest guidance engine")
end

function QuestGuidanceEngine:StartGuidance(questId, questName, objective)
    if not questId or not questName or not objective then
        return false
    end
    
    self.current_guidance = {
        quest_id = questId,
        quest_name = questName,
        objective = objective,
        started_at = GetTime(),
        completed_at = nil,
        guidance_text = self:GenerateGuidanceText(objective),
        progress_percent = 0,
        active = true,
    }
    
    self:Log("Started guidance for quest: " .. questName)
    
    return true
end

function QuestGuidanceEngine:GenerateGuidanceText(objective)
    if not objective then
        return "Complete objective"
    end
    
    local objectiveType = objective.type or "unknown"
    local text = "Objective: "
    
    if objectiveType == "kill" then
        text = text .. "Kill " .. (objective.required or 1) .. " " .. (objective.name or "enemies")
    elseif objectiveType == "collect" then
        text = text .. "Collect " .. (objective.required or 1) .. " " .. (objective.name or "items")
    elseif objectiveType == "explore" then
        text = text .. "Explore " .. (objective.name or "location")
    elseif objectiveType == "talk" then
        text = text .. "Talk to " .. (objective.name or "NPC")
    elseif objectiveType == "deliver" then
        text = text .. "Deliver " .. (objective.name or "item") .. " to " .. (objective.recipient or "NPC")
    elseif objectiveType == "complete" then
        text = text .. "Complete " .. (objective.name or "task")
    else
        text = text .. objective.name or "Complete objective"
    end
    
    if #text > self.config.guidance_text_length then
        text = text:sub(1, self.config.guidance_text_length - 3) .. "..."
    end
    
    return text
end

function QuestGuidanceEngine:GetCurrentGuidance()
    return self.current_guidance
end

function QuestGuidanceEngine:UpdateGuidanceProgress(progress_percent)
    if not self.current_guidance then
        return false
    end
    
    self.current_guidance.progress_percent = math.min(100, math.max(0, progress_percent or 0))
    
    return true
end

function QuestGuidanceEngine:GetDirections(currentMapId, currentX, currentY, targetMapId, targetX, targetY)
    if currentMapId ~= targetMapId then
        return {
            direction = "navigate_to_map",
            target_map = targetMapId,
            message = "Head to map " .. targetMapId,
        }
    end
    
    local dx = targetX - currentX
    local dy = targetY - currentY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance < 5 then
        return {
            direction = "arrived",
            distance = distance,
            message = "You have arrived at the objective",
        }
    end
    
    local angle = math.atan2(dy, dx)
    local compass
    
    if angle > math.pi * 0.875 or angle < -math.pi * 0.875 then
        compass = "West"
    elseif angle > math.pi * 0.625 then
        compass = "Northwest"
    elseif angle > math.pi * 0.375 then
        compass = "North"
    elseif angle > math.pi * 0.125 then
        compass = "Northeast"
    elseif angle > -math.pi * 0.125 then
        compass = "East"
    elseif angle > -math.pi * 0.375 then
        compass = "Southeast"
    elseif angle > -math.pi * 0.625 then
        compass = "South"
    else
        compass = "Southwest"
    end
    
    return {
        direction = compass,
        distance = math.floor(distance),
        message = "Head " .. compass .. " (" .. math.floor(distance) .. "y)",
    }
end

function QuestGuidanceEngine:GetDistanceToObjective(currentX, currentY, targetX, targetY)
    local dx = targetX - currentX
    local dy = targetY - currentY
    return math.sqrt(dx * dx + dy * dy)
end

function QuestGuidanceEngine:GetEstimatedTimeToObjective(currentX, currentY, targetX, targetY, speed)
    speed = speed or 7  -- Average WoW player speed
    
    local distance = self:GetDistanceToObjective(currentX, currentY, targetX, targetY)
    
    return math.ceil(distance / speed)
end

function QuestGuidanceEngine:CreateGuidanceMarker(questId, markerType, mapId, x, y, name)
    if not questId or not markerType or not mapId then
        return false
    end
    
    if not self.guidance_sessions[questId] then
        self.guidance_sessions[questId] = {}
    end
    
    local marker = {
        id = questId .. "_" .. markerType,
        type = markerType,
        map_id = mapId,
        x = x,
        y = y,
        name = name or "",
        created_at = GetTime(),
        visible = true,
    }
    
    table.insert(self.guidance_sessions[questId], marker)
    self:Log("Created guidance marker: " .. marker.id)
    
    return true
end

function QuestGuidanceEngine:GetGuidanceMarkers(questId)
    if not questId or not self.guidance_sessions[questId] then
        return {}
    end
    
    return self.guidance_sessions[questId]
end

function QuestGuidanceEngine:CompleteGuidance()
    if not self.current_guidance then
        return false
    end
    
    self.current_guidance.active = false
    self.current_guidance.completed_at = GetTime()
    
    self:Log("Completed guidance for quest: " .. self.current_guidance.quest_name)
    
    return true
end

function QuestGuidanceEngine:StopGuidance()
    if not self.current_guidance then
        return false
    end
    
    self.current_guidance.active = false
    self.current_guidance = nil
    
    self:Log("Stopped guidance")
    
    return true
end

function QuestGuidanceEngine:GetGuidanceStats()
    local activeGuidance = self.current_guidance and self.current_guidance.active or false
    local questCount = table.getn(self.guidance_sessions)
    
    return {
        active_guidance = activeGuidance,
        guided_quests = questCount,
        current_quest_name = self.current_guidance and self.current_guidance.quest_name or "None",
        progress = self.current_guidance and self.current_guidance.progress_percent or 0,
    }
end

function QuestGuidanceEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[QuestGuidanceEngine] " .. message)
    else
        print("[QuestGuidanceEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTGUIDE1 = "/questguide"
    SlashCmdList["QUESTGUIDE"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "start" then
            local questId = tonumber(args)
            if questId then
                QuestGuidanceEngine:StartGuidance(questId, "Quest " .. questId, {
                    type = "unknown",
                    name = "Complete objective"
                })
                print("Started guidance for quest: " .. questId)
            else
                print("Usage: /questguide start <questId>")
            end
        elseif cmd == "progress" then
            local progress = tonumber(args)
            if progress then
                QuestGuidanceEngine:UpdateGuidanceProgress(progress)
                print("Updated guidance progress: " .. progress .. "%")
            else
                print("Usage: /questguide progress <0-100>")
            end
        elseif cmd == "stop" then
            QuestGuidanceEngine:StopGuidance()
            print("Stopped guidance")
        elseif cmd == "complete" then
            QuestGuidanceEngine:CompleteGuidance()
            print("Completed guidance")
        elseif cmd == "current" then
            local guidance = QuestGuidanceEngine:GetCurrentGuidance()
            if guidance then
                print("Current Guidance:")
                print("  Quest: " .. guidance.quest_name)
                print("  Objective: " .. guidance.guidance_text)
                print("  Progress: " .. guidance.progress_percent .. "%")
            else
                print("No active guidance")
            end
        elseif cmd == "stats" then
            local stats = QuestGuidanceEngine:GetGuidanceStats()
            print("Guidance Stats:")
            print("  Active Guidance: " .. (stats.active_guidance and "Yes" or "No"))
            print("  Current Quest: " .. stats.current_quest_name)
            print("  Progress: " .. stats.progress .. "%")
            print("  Guided Quests: " .. stats.guided_quests)
        else
            print("Quest Guidance Commands:")
            print("  /questguide start <questId> - Start guidance")
            print("  /questguide progress <0-100> - Update progress")
            print("  /questguide stop - Stop guidance")
            print("  /questguide complete - Complete guidance")
            print("  /questguide current - Show current guidance")
            print("  /questguide stats - Show guidance stats")
        end
    end
end

return QuestGuidanceEngine
