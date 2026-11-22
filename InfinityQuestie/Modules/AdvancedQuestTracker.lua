-- InfinityQuestie - Advanced Quest Tracking System  
-- Complete quest database, tracking, and navigation integration

local QuestTracker = {}
_G.InfinityQuestTracker = QuestTracker

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

QuestTracker.questDB = {} -- {questId = questData}
QuestTracker.activeQuests = {} -- Player's active quests
QuestTracker.completedQuests = {} -- Player's completed quests
QuestTracker.questLog = {} -- Full quest log tracking

QuestTracker.config = {
	updateInterval = 1.0, -- Update quest tracking every 1 second
	enableTracking = true,
	enableObjectives = true,
	enableRewards = true,
	maxQuestsTracked = 25,
}

-- ============================================================================
-- QUEST DATABASE
-- ============================================================================

--- Register quest
function QuestTracker:RegisterQuest(questId, questData)
	self.questDB[questId] = {
		id = questId,
		name = questData.name or "Unknown Quest",
		giver = questData.giver or "Unknown NPC",
		level = questData.level or 1,
		levelRange = questData.levelRange or {min = 1, max = 60},
		zone = questData.zone or "Unknown Zone",
		type = questData.type or "normal", -- normal, elite, dungeon, raid, pvp
		objectives = questData.objectives or {},
		rewards = questData.rewards or {},
		requiresPrerequisite = questData.prerequisite or nil,
		leadToQuest = questData.followUp or nil,
		description = questData.description or "",
		inLog = false,
		isComplete = false,
		isReturned = false,
		objectives_progress = {},
		startDate = nil,
		completeDate = nil,
		rewardChoices = questData.rewardChoices or {}
	}
	
	return self.questDB[questId]
end

--- Get quest
function QuestTracker:GetQuest(questId)
	return self.questDB[questId]
end

--- Find quest by name
function QuestTracker:FindQuestByName(questName)
	for id, quest in pairs(self.questDB) do
		if quest.name == questName then
			return quest
		end
	end
	return nil
end

--- Get quests by zone
function QuestTracker:GetQuestsByZone(zoneName)
	local quests = {}
	for id, quest in pairs(self.questDB) do
		if quest.zone == zoneName then
			table.insert(quests, quest)
		end
	end
	return quests
end

--- Get quests by level
function QuestTracker:GetQuestsByLevel(playerLevel, range)
	range = range or 5
	local quests = {}
	
	for id, quest in pairs(self.questDB) do
		if math.abs(quest.level - playerLevel) <= range then
			table.insert(quests, quest)
		end
	end
	
	return quests
end

-- ============================================================================
-- QUEST TRACKING
-- ============================================================================

--- Track quest (add to active)
function QuestTracker:TrackQuest(questId)
	if #self.activeQuests >= self.config.maxQuestsTracked then
		InfinityUtils:Warning("Too many quests tracked", "Quest")
		return false
	end
	
	local quest = self:GetQuest(questId)
	if not quest then
		return false
	end
	
	quest.inLog = true
	quest.startDate = quest.startDate or date("%Y-%m-%d %H:%M:%S")
	table.insert(self.activeQuests, quest)
	
	InfinityUtils:Info(string.format("Tracking quest: %s", quest.name), "Quest")
	return true
end

--- Stop tracking quest
function QuestTracker:UntrackQuest(questId)
	for i, quest in ipairs(self.activeQuests) do
		if quest.id == questId then
			quest.inLog = false
			table.remove(self.activeQuests, i)
			return true
		end
	end
	return false
end

--- Get active quests
function QuestTracker:GetActiveQuests()
	return self.activeQuests
end

--- Mark quest complete
function QuestTracker:CompleteQuest(questId)
	local quest = self:GetQuest(questId)
	if not quest then
		return false
	end
	
	quest.isComplete = true
	quest.completeDate = date("%Y-%m-%d %H:%M:%S")
	
	-- Move to completed list
	table.insert(self.completedQuests, quest)
	self:UntrackQuest(questId)
	
	InfinityUtils:Info(string.format("Completed quest: %s", quest.name), "Quest")
	return true
end

--- Get completed quests
function QuestTracker:GetCompletedQuests()
	return self.completedQuests
end

-- ============================================================================
-- OBJECTIVE TRACKING
-- ============================================================================

--- Register objective for quest
function QuestTracker:AddObjective(questId, objective)
	local quest = self:GetQuest(questId)
	if not quest then
		return
	end
	
	table.insert(quest.objectives, {
		description = objective.description or "Unknown Objective",
		type = objective.type or "kill", -- kill, collect, talk, explore, cast
		target = objective.target or "",
		required = objective.required or 1,
		current = 0,
		complete = false
	})
end

--- Get objectives for quest
function QuestTracker:GetObjectives(questId)
	local quest = self:GetQuest(questId)
	if not quest then
		return {}
	end
	
	return quest.objectives
end

--- Update objective progress
function QuestTracker:UpdateObjective(questId, objectiveIndex, currentProgress)
	local quest = self:GetQuest(questId)
	if not quest or not quest.objectives[objectiveIndex] then
		return
	end
	
	local objective = quest.objectives[objectiveIndex]
	objective.current = currentProgress
	
	-- Check if objective complete
	if currentProgress >= objective.required then
		objective.complete = true
	end
end

--- Get objective progress
function QuestTracker:GetObjectiveProgress(questId, objectiveIndex)
	local quest = self:GetQuest(questId)
	if not quest or not quest.objectives[objectiveIndex] then
		return nil
	end
	
	local obj = quest.objectives[objectiveIndex]
	return {
		description = obj.description,
		current = obj.current,
		required = obj.required,
		complete = obj.complete,
		progress = (obj.current / obj.required) * 100
	}
end

--- Check if quest ready to turn in
function QuestTracker:IsQuestComplete(questId)
	local quest = self:GetQuest(questId)
	if not quest then
		return false
	end
	
	-- All objectives must be complete
	for _, objective in ipairs(quest.objectives) do
		if not objective.complete then
			return false
		end
	end
	
	return true
end

-- ============================================================================
-- REWARD INFORMATION
-- ============================================================================

--- Get quest rewards
function QuestTracker:GetRewards(questId)
	local quest = self:GetQuest(questId)
	if not quest then
		return {}
	end
	
	return quest.rewards
end

--- Add reward option
function QuestTracker:AddRewardOption(questId, reward)
	local quest = self:GetQuest(questId)
	if not quest then
		return
	end
	
	table.insert(quest.rewardChoices, {
		itemId = reward.itemId,
		name = reward.name,
		quality = reward.quality or "common",
		value = reward.value or 0,
		description = reward.description or ""
	})
end

--- Get reward options
function QuestTracker:GetRewardOptions(questId)
	local quest = self:GetQuest(questId)
	if not quest then
		return {}
	end
	
	return quest.rewardChoices
end

--- Estimate reward value
function QuestTracker:GetRewardValue(questId)
	local quest = self:GetQuest(questId)
	if not quest then
		return 0
	end
	
	local totalValue = 0
	
	-- Gold rewards
	for _, reward in ipairs(quest.rewards) do
		if reward.type == "gold" then
			totalValue = totalValue + reward.amount
		elseif reward.type == "item" then
			totalValue = totalValue + (reward.value or 0)
		end
	end
	
	-- Experience (approximate as gold value)
	for _, reward in ipairs(quest.rewards) do
		if reward.type == "experience" then
			totalValue = totalValue + (reward.amount / 10) -- Rough conversion
		end
	end
	
	return totalValue
end

-- ============================================================================
-- QUEST CHAINS & PREREQUISITES
-- ============================================================================

--- Get quest prerequisites
function QuestTracker:GetPrerequisites(questId)
	local quest = self:GetQuest(questId)
	if not quest or not quest.requiresPrerequisite then
		return {}
	end
	
	local prereqs = {}
	if type(quest.requiresPrerequisite) == "table" then
		return quest.requiresPrerequisite
	else
		return {quest.requiresPrerequisite}
	end
end

--- Get follow-up quests
function QuestTracker:GetFollowUpQuests(questId)
	local quest = self:GetQuest(questId)
	if not quest then
		return {}
	end
	
	local followUps = {}
	
	-- Find quests that have this quest as prerequisite
	for id, q in pairs(self.questDB) do
		if q.requiresPrerequisite == questId or 
		   (type(q.requiresPrerequisite) == "table" and 
		    self:TableContains(q.requiresPrerequisite, questId)) then
			table.insert(followUps, q)
		end
	end
	
	return followUps
end

--- Check if quest can be accepted
function QuestTracker:CanAcceptQuest(questId)
	local quest = self:GetQuest(questId)
	if not quest then
		return false
	end
	
	local playerLevel = UnitLevel("player")
	
	-- Check level requirement
	if playerLevel < quest.levelRange.min then
		return false, "Too low level"
	end
	
	-- Check prerequisites
	local prerequisites = self:GetPrerequisites(questId)
	for _, prereqId in ipairs(prerequisites) do
		local prereq = self:GetQuest(prereqId)
		if prereq and not self:IsQuestCompleted(prereqId) then
			return false, "Prerequisite quest not completed: " .. prereq.name
		end
	end
	
	return true, "Quest available"
end

--- Check if quest completed
function QuestTracker:IsQuestCompleted(questId)
	for _, quest in ipairs(self.completedQuests) do
		if quest.id == questId then
			return true
		end
	end
	return false
end

-- ============================================================================
-- QUEST STATISTICS
-- ============================================================================

--- Get quest completion stats
function QuestTracker:GetCompletionStats()
	local stats = {
		total = 0,
		completed = #self.completedQuests,
		active = #self.activeQuests,
		available = 0,
		completionPercent = 0
	}
	
	-- Count total registered quests
	for _ in pairs(self.questDB) do
		stats.total = stats.total + 1
	end
	
	-- Count available quests
	for id, quest in pairs(self.questDB) do
		local canAccept, _ = self:CanAcceptQuest(id)
		if canAccept then
			stats.available = stats.available + 1
		end
	end
	
	stats.completionPercent = stats.total > 0 and (stats.completed / stats.total * 100) or 0
	
	return stats
end

--- Print quest statistics
function QuestTracker:PrintStats()
	local stats = self:GetCompletionStats()
	
	print("|cff00ccffQuest Statistics:|r")
	print(string.format("  Total Quests: %d", stats.total))
	print(string.format("  Completed: %d (%.1f%%)", stats.completed, stats.completionPercent))
	print(string.format("  Active: %d", stats.active))
	print(string.format("  Available: %d", stats.available))
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

function QuestTracker:TableContains(table, value)
	for _, v in ipairs(table) do
		if v == value then
			return true
		end
	end
	return false
end

-- ============================================================================
-- INTEGRATION WITH NAVIGATION
-- ============================================================================

--- Get quest giver location
function QuestTracker:GetQuestGiverLocation(questId)
	local quest = self:GetQuest(questId)
	if not quest then
		return nil
	end
	
	-- This would integrate with navigation addon
	return {
		zone = quest.zone,
		npc = quest.giver
	}
end

--- Get objective location
function QuestTracker:GetObjectiveLocation(questId, objectiveIndex)
	local quest = self:GetQuest(questId)
	if not quest or not quest.objectives[objectiveIndex] then
		return nil
	end
	
	local objective = quest.objectives[objectiveIndex]
	
	-- This would integrate with navigation addon
	return {
		zone = quest.zone,
		target = objective.target,
		type = objective.type
	}
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function QuestTracker:Initialize()
	InfinityUtils:Info("QuestTracker initializing...", "Quest")
	
	-- Load saved quest database
	-- Register basic quests
	
	InfinityUtils:Info("QuestTracker initialized", "Quest")
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

if InfinityCommandRegistry then
	InfinityCommandRegistry:RegisterCommand("quest", function(args)
		if not args or #args == 0 then
			QuestTracker:PrintStats()
		elseif args[1] == "active" then
			local active = QuestTracker:GetActiveQuests()
			print("|cff00ccffActive Quests:|r (" .. #active .. ")")
			for _, quest in ipairs(active) do
				print("  - " .. quest.name .. " (" .. quest.zone .. ")")
			end
		elseif args[1] == "completed" then
			local completed = QuestTracker:GetCompletedQuests()
			print("|cff00ccffCompleted Quests:|r (" .. #completed .. ")")
			for i, quest in ipairs(completed) do
				if i <= 10 then
					print("  - " .. quest.name)
				end
			end
			if #completed > 10 then
				print("  ... and " .. (#completed - 10) .. " more")
			end
		end
	end, {"quests", "q"})
end

print("[INFO] Quest Tracker loaded successfully")
