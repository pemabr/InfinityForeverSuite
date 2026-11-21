-- QuestPublicAPI.lua - Public API for addon-to-addon communication
-- Part of InfinityQuestie addon suite
-- Provides callbacks and query methods for external addons

local QuestPublicAPI = {}
QuestPublicAPI.enabled = false
QuestPublicAPI.db = nil
QuestPublicAPI.callbacks = {}
QuestPublicAPI.ready_callbacks = {}
QuestPublicAPI.update_callbacks = {}

-- Configuration
QuestPublicAPI.config = {
    enabled = true,
    max_callbacks = 50,
    callback_timeout = 5,  -- seconds
    queue_enabled = true,
}

function QuestPublicAPI:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.callbacks then
        self.db.callbacks = {}
    end
    
    self.callbacks = self.db.callbacks
    self.enabled = true
    
    self:Log("Initialized quest public API")
end

-- OnReady Callback Registration
function QuestPublicAPI:RegisterOnReady(addonName, callbackFunction)
    if not addonName or not callbackFunction then
        return false
    end
    
    if #self.ready_callbacks >= self.config.max_callbacks then
        self:Log("Max ready callbacks reached")
        return false
    end
    
    local callback = {
        addon_name = addonName,
        callback = callbackFunction,
        registered_at = GetTime(),
        active = true,
    }
    
    table.insert(self.ready_callbacks, callback)
    self:Log("Registered OnReady callback for: " .. addonName)
    
    return true
end

-- Quest Update Callback Registration
function QuestPublicAPI:RegisterQuestUpdate(addonName, callbackFunction, questId)
    if not addonName or not callbackFunction then
        return false
    end
    
    if #self.update_callbacks >= self.config.max_callbacks then
        self:Log("Max update callbacks reached")
        return false
    end
    
    local callback = {
        addon_name = addonName,
        callback = callbackFunction,
        quest_id = questId,  -- nil = all quests
        registered_at = GetTime(),
        last_called = 0,
        active = true,
    }
    
    table.insert(self.update_callbacks, callback)
    self:Log("Registered quest update callback for: " .. addonName)
    
    return true
end

-- Unregister callbacks
function QuestPublicAPI:UnregisterOnReady(addonName)
    for i, callback in ipairs(self.ready_callbacks) do
        if callback.addon_name == addonName then
            callback.active = false
            self:Log("Unregistered OnReady callback for: " .. addonName)
            return true
        end
    end
    
    return false
end

function QuestPublicAPI:UnregisterQuestUpdate(addonName)
    for i, callback in ipairs(self.update_callbacks) do
        if callback.addon_name == addonName then
            callback.active = false
            self:Log("Unregistered quest update callback for: " .. addonName)
            return true
        end
    end
    
    return false
end

-- Fire ready callbacks
function QuestPublicAPI:FireOnReady()
    local successCount = 0
    local failureCount = 0
    
    for _, callback in ipairs(self.ready_callbacks) do
        if callback.active then
            local success, errorMsg = pcall(callback.callback)
            
            if success then
                successCount = successCount + 1
            else
                failureCount = failureCount + 1
                self:Log("OnReady callback error for " .. callback.addon_name .. ": " .. tostring(errorMsg))
            end
        end
    end
    
    self:Log("Fired OnReady callbacks: " .. successCount .. " success, " .. failureCount .. " failures")
    
    return successCount, failureCount
end

-- Fire quest update callbacks
function QuestPublicAPI:FireQuestUpdate(questId, questName, updateType)
    updateType = updateType or "progress"  -- progress, complete, abandon, accept
    
    local successCount = 0
    local failureCount = 0
    
    for _, callback in ipairs(self.update_callbacks) do
        if callback.active then
            if not callback.quest_id or callback.quest_id == questId then
                local success, errorMsg = pcall(callback.callback, questId, questName, updateType)
                
                if success then
                    successCount = successCount + 1
                    callback.last_called = GetTime()
                else
                    failureCount = failureCount + 1
                    self:Log("Quest update callback error for " .. callback.addon_name .. ": " .. tostring(errorMsg))
                end
            end
        end
    end
    
    return successCount, failureCount
end

-- Query APIs

function QuestPublicAPI:GetQuestIcon(questId)
    if not questId then
        return nil
    end
    
    if not QuestDatabaseEngine then
        return "Interface\\Icons\\INV_Scroll_04"  -- Default quest icon
    end
    
    local quest = QuestDatabaseEngine:GetQuest(questId)
    if not quest then
        return "Interface\\Icons\\INV_Scroll_04"
    end
    
    -- Icon based on quest type or difficulty
    if quest.difficulty == "Elite" then
        return "Interface\\Icons\\INV_Jewelry_Ring_32"
    elseif quest.difficulty == "Hard" then
        return "Interface\\Icons\\INV_Scroll_06"
    else
        return "Interface\\Icons\\INV_Scroll_04"
    end
end

function QuestPublicAPI:GetQuestObjectiveUnits(questId)
    if not questId then
        return {}
    end
    
    if not ObjectiveTrackingEngine then
        return {}
    end
    
    local objectives = ObjectiveTrackingEngine:GetObjectives(questId)
    if not objectives or #objectives == 0 then
        return {}
    end
    
    local units = {}
    
    for _, objective in ipairs(objectives) do
        if objective.type == "kill" then
            table.insert(units, {
                type = "kill",
                target = objective.name or "",
                required = objective.required or 1,
                current = objective.progress or 0,
            })
        elseif objective.type == "collect" then
            table.insert(units, {
                type = "collect",
                item = objective.name or "",
                required = objective.required or 1,
                current = objective.progress or 0,
            })
        end
    end
    
    return units
end

function QuestPublicAPI:GetQuestData(questId)
    if not questId then
        return nil
    end
    
    if not QuestDatabaseEngine then
        return nil
    end
    
    local quest = QuestDatabaseEngine:GetQuest(questId)
    if not quest then
        return nil
    end
    
    local tracking = QuestTrackingEngine:GetQuestStatus(questId)
    local objectives = ObjectiveTrackingEngine:GetObjectives(questId)
    
    return {
        id = quest.id,
        name = quest.name,
        level = quest.level,
        zone = quest.zone,
        type = quest.type,
        difficulty = quest.difficulty,
        status = tracking and tracking.status or "unknown",
        progress = #objectives > 0 and ObjectiveTrackingEngine:GetQuestProgress(questId) or 0,
        objective_count = #objectives,
        reward_xp = quest.reward_xp or 0,
        reward_gold = quest.reward_gold or 0,
    }
end

function QuestPublicAPI:GetQuestList(filterCriteria)
    filterCriteria = filterCriteria or {}
    
    if not QuestDatabaseEngine then
        return {}
    end
    
    local quests = QuestDatabaseEngine:GetAllQuests()
    if not quests then
        return {}
    end
    
    local results = {}
    
    for _, quest in ipairs(quests) do
        local include = true
        
        -- Apply filters
        if filterCriteria.minLevel and quest.level and quest.level < filterCriteria.minLevel then
            include = false
        end
        if filterCriteria.maxLevel and quest.level and quest.level > filterCriteria.maxLevel then
            include = false
        end
        if filterCriteria.zone and quest.zone ~= filterCriteria.zone then
            include = false
        end
        if filterCriteria.type and quest.type ~= filterCriteria.type then
            include = false
        end
        
        if include then
            table.insert(results, {
                id = quest.id,
                name = quest.name,
                level = quest.level,
                zone = quest.zone,
                type = quest.type,
            })
        end
    end
    
    return results
end

function QuestPublicAPI:IsQuestAvailable(questId)
    if not questId then
        return false
    end
    
    if not QuestDatabaseEngine then
        return false
    end
    
    return QuestDatabaseEngine:CanStartQuest(questId)
end

function QuestPublicAPI:IsQuestCompleted(questId)
    if not questId then
        return false
    end
    
    if not QuestTrackingEngine then
        return false
    end
    
    local status = QuestTrackingEngine:GetQuestStatus(questId)
    
    return status and status.status == "completed" or false
end

function QuestPublicAPI:GetQuestProgress(questId)
    if not questId then
        return 0
    end
    
    if not ObjectiveTrackingEngine then
        return 0
    end
    
    return ObjectiveTrackingEngine:GetQuestProgress(questId)
end

-- Callback Management

function QuestPublicAPI:GetRegisteredCallbacks()
    local readyCount = 0
    local updateCount = 0
    
    for _, callback in ipairs(self.ready_callbacks) do
        if callback.active then
            readyCount = readyCount + 1
        end
    end
    
    for _, callback in ipairs(self.update_callbacks) do
        if callback.active then
            updateCount = updateCount + 1
        end
    end
    
    return {
        onReady = readyCount,
        onUpdate = updateCount,
        total = readyCount + updateCount,
    }
end

function QuestPublicAPI:GetStatus()
    return {
        enabled = self.enabled,
        ready_callbacks = #self.ready_callbacks,
        update_callbacks = #self.update_callbacks,
        total_callbacks = #self.ready_callbacks + #self.update_callbacks,
    }
end

function QuestPublicAPI:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestPublicAPI] " .. message)
    else
        print("[QuestPublicAPI] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTAPI1 = "/questapi"
    SlashCmdList["QUESTAPI"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "query" then
            local questId = tonumber(args)
            if questId then
                local data = QuestPublicAPI:GetQuestData(questId)
                if data then
                    print("Quest " .. questId .. " Data:")
                    print("  Name: " .. data.name)
                    print("  Level: " .. data.level)
                    print("  Zone: " .. data.zone)
                    print("  Type: " .. data.type)
                    print("  Status: " .. data.status)
                    print("  Progress: " .. data.progress .. "%")
                else
                    print("Quest not found: " .. questId)
                end
            else
                print("Usage: /questapi query <questId>")
            end
        elseif cmd == "available" then
            local questId = tonumber(args)
            if questId then
                local available = QuestPublicAPI:IsQuestAvailable(questId)
                print("Quest " .. questId .. " available: " .. (available and "Yes" or "No"))
            else
                print("Usage: /questapi available <questId>")
            end
        elseif cmd == "completed" then
            local questId = tonumber(args)
            if questId then
                local completed = QuestPublicAPI:IsQuestCompleted(questId)
                print("Quest " .. questId .. " completed: " .. (completed and "Yes" or "No"))
            else
                print("Usage: /questapi completed <questId>")
            end
        elseif cmd == "progress" then
            local questId = tonumber(args)
            if questId then
                local progress = QuestPublicAPI:GetQuestProgress(questId)
                print("Quest " .. questId .. " progress: " .. progress .. "%")
            else
                print("Usage: /questapi progress <questId>")
            end
        elseif cmd == "callbacks" then
            local counts = QuestPublicAPI:GetRegisteredCallbacks()
            print("Registered Callbacks:")
            print("  OnReady: " .. counts.onReady)
            print("  OnUpdate: " .. counts.onUpdate)
            print("  Total: " .. counts.total)
        elseif cmd == "status" then
            local status = QuestPublicAPI:GetStatus()
            print("Quest Public API:")
            print("  Total Callbacks: " .. status.total_callbacks)
            print("  Ready Callbacks: " .. status.ready_callbacks)
            print("  Update Callbacks: " .. status.update_callbacks)
        else
            print("Quest Public API Commands:")
            print("  /questapi query <questId> - Get quest data")
            print("  /questapi available <questId> - Check if available")
            print("  /questapi completed <questId> - Check if completed")
            print("  /questapi progress <questId> - Get progress %")
            print("  /questapi callbacks - Show registered callbacks")
            print("  /questapi status - Show API status")
        end
    end
end

return QuestPublicAPI
