-- QuestTooltipEnhancerEngine.lua - Enhanced tooltip display for quests
-- Part of PluribusQuestie addon suite
-- Handles displaying quest information in item/NPC tooltips

local QuestTooltipEnhancerEngine = {}
QuestTooltipEnhancerEngine.enabled = false
QuestTooltipEnhancerEngine.db = nil
QuestTooltipEnhancerEngine.tooltip_config = {}
QuestTooltipEnhancerEngine.tooltip_cache = {}
QuestTooltipEnhancerEngine.hook_count = 0

-- Configuration
QuestTooltipEnhancerEngine.config = {
    enabled = true,
    show_quest_info = true,
    show_quest_rewards = true,
    show_quest_prerequisites = true,
    show_quest_difficulty = true,
    cache_tooltips = true,
    max_cache_size = 100,
}

function QuestTooltipEnhancerEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.tooltip_config then
        self.db.tooltip_config = {}
    end
    
    if not self.db.tooltip_cache then
        self.db.tooltip_cache = {}
    end
    
    self.tooltip_config = self.db.tooltip_config
    self.tooltip_cache = self.db.tooltip_cache
    self.enabled = true
    
    self:Log("Initialized quest tooltip enhancer engine")
end

function QuestTooltipEnhancerEngine:BuildQuestTooltip(questData)
    if not questData then
        return nil
    end
    
    local tooltip = {
        quest_id = questData.id,
        quest_name = questData.name or "Unknown Quest",
        content = {},
    }
    
    -- Quest name and level
    if questData.name then
        table.insert(tooltip.content, {type = "title", text = questData.name})
    end
    
    if questData.level then
        table.insert(tooltip.content, {type = "level", text = "Level: " .. questData.level})
    end
    
    -- Difficulty display
    if self.config.show_quest_difficulty and questData.difficulty then
        local difficultyName = self:GetDifficultyName(questData.difficulty)
        table.insert(tooltip.content, {type = "difficulty", text = "Difficulty: " .. difficultyName})
    end
    
    -- Quest description
    if questData.description then
        table.insert(tooltip.content, {type = "description", text = questData.description})
    end
    
    -- Objectives
    if questData.objectives and #questData.objectives > 0 then
        table.insert(tooltip.content, {type = "section", text = "Objectives:"})
        for _, objective in ipairs(questData.objectives) do
            table.insert(tooltip.content, {type = "objective", text = "• " .. (objective or "")})
        end
    end
    
    -- Rewards
    if self.config.show_quest_rewards and questData.rewards then
        table.insert(tooltip.content, {type = "section", text = "Rewards:"})
        
        if questData.rewards.xp then
            table.insert(tooltip.content, {type = "reward", text = "XP: " .. questData.rewards.xp})
        end
        
        if questData.rewards.gold then
            table.insert(tooltip.content, {type = "reward", text = "Gold: " .. questData.rewards.gold})
        end
        
        if questData.rewards.items and #questData.rewards.items > 0 then
            for _, item in ipairs(questData.rewards.items) do
                table.insert(tooltip.content, {type = "reward", text = "Item: " .. (item or "")})
            end
        end
    end
    
    -- Prerequisites
    if self.config.show_quest_prerequisites and questData.prerequisites and #questData.prerequisites > 0 then
        table.insert(tooltip.content, {type = "section", text = "Prerequisites:"})
        for _, prereq in ipairs(questData.prerequisites) do
            table.insert(tooltip.content, {type = "prerequisite", text = "→ Quest " .. prereq})
        end
    end
    
    return tooltip
end

function QuestTooltipEnhancerEngine:GetDifficultyName(difficulty)
    if not difficulty then
        return "Normal"
    end
    
    if difficulty <= 1 then return "Easy"
    elseif difficulty <= 2 then return "Normal"
    elseif difficulty <= 3 then return "Hard"
    elseif difficulty <= 4 then return "Very Hard"
    else return "Impossible"
    end
end

function QuestTooltipEnhancerEngine:FormatTooltipLine(contentItem)
    if not contentItem then
        return ""
    end
    
    if contentItem.type == "title" then
        return "|cFFFFD700" .. contentItem.text .. "|r"  -- Gold
    elseif contentItem.type == "level" then
        return "|cFFFFFFFF" .. contentItem.text .. "|r"  -- White
    elseif contentItem.type == "difficulty" then
        return "|cFFFF8000" .. contentItem.text .. "|r"  -- Orange
    elseif contentItem.type == "description" then
        return "|cFFC0C0C0" .. contentItem.text .. "|r"  -- Gray
    elseif contentItem.type == "objective" then
        return "|cFF00FF00" .. contentItem.text .. "|r"  -- Green
    elseif contentItem.type == "reward" then
        return "|cFF0070DD" .. contentItem.text .. "|r"  -- Blue
    elseif contentItem.type == "prerequisite" then
        return "|cFFFF0000" .. contentItem.text .. "|r"  -- Red
    elseif contentItem.type == "section" then
        return "|cFFFFFF00" .. contentItem.text .. "|r"  -- Yellow
    else
        return contentItem.text
    end
end

function QuestTooltipEnhancerEngine:CacheTooltip(questId, tooltip)
    if not questId or not tooltip then
        return false
    end
    
    -- Check cache size
    if table.getn(self.tooltip_cache) >= self.config.max_cache_size then
        -- Remove oldest entry
        local firstKey = next(self.tooltip_cache)
        self.tooltip_cache[firstKey] = nil
    end
    
    self.tooltip_cache[questId] = {
        tooltip = tooltip,
        cached_at = GetTime(),
    }
    
    return true
end

function QuestTooltipEnhancerEngine:GetCachedTooltip(questId)
    if not questId then
        return nil
    end
    
    if self.tooltip_cache[questId] then
        return self.tooltip_cache[questId].tooltip
    end
    
    return nil
end

function QuestTooltipEnhancerEngine:ClearCache()
    self.tooltip_cache = {}
    self:Log("Tooltip cache cleared")
    return true
end

function QuestTooltipEnhancerEngine:EnableTooltipHooks()
    self.hook_count = (self.hook_count or 0) + 1
    self:Log("Tooltip hooks enabled (" .. self.hook_count .. " active)")
    return true
end

function QuestTooltipEnhancerEngine:DisableTooltipHooks()
    self.hook_count = math.max(0, (self.hook_count or 1) - 1)
    self:Log("Tooltip hooks disabled (" .. self.hook_count .. " remaining)")
    return true
end

function QuestTooltipEnhancerEngine:IsHookActive()
    return self.hook_count > 0
end

function QuestTooltipEnhancerEngine:SetConfig(key, value)
    if not key then
        return false
    end
    
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    
    return false
end

function QuestTooltipEnhancerEngine:GetConfig(key)
    if not key then
        return self.config
    end
    
    return self.config[key]
end

function QuestTooltipEnhancerEngine:ExportTooltip(questId)
    local tooltip = self:GetCachedTooltip(questId)
    if not tooltip then
        return nil
    end
    
    local exported = "Quest #" .. tooltip.quest_id .. ": " .. tooltip.quest_name .. "\n"
    
    for _, line in ipairs(tooltip.content) do
        exported = exported .. self:FormatTooltipLine(line) .. "\n"
    end
    
    return exported
end

function QuestTooltipEnhancerEngine:GetStatus()
    local cacheCount = table.getn(self.tooltip_cache)
    
    return {
        enabled = self.enabled,
        show_quest_info = self.config.show_quest_info,
        show_quest_rewards = self.config.show_quest_rewards,
        show_prerequisites = self.config.show_quest_prerequisites,
        hooks_active = self.hook_count,
        cached_tooltips = cacheCount,
        max_cache = self.config.max_cache_size,
    }
end

function QuestTooltipEnhancerEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[QuestTooltipEnhancerEngine] " .. message)
    else
        print("[QuestTooltipEnhancerEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTTOOLTIP1 = "/questtooltip"
    SlashCmdList["QUESTTOOLTIP"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "toggle" then
            local setting = args
            if setting ~= "" then
                local current = QuestTooltipEnhancerEngine:GetConfig(setting)
                if current ~= nil then
                    QuestTooltipEnhancerEngine:SetConfig(setting, not current)
                    print("Toggled " .. setting)
                else
                    print("Unknown config: " .. setting)
                end
            else
                print("Usage: /questtooltip toggle <config>")
            end
        elseif cmd == "enable" then
            QuestTooltipEnhancerEngine:EnableTooltipHooks()
            print("Tooltip hooks enabled")
        elseif cmd == "disable" then
            QuestTooltipEnhancerEngine:DisableTooltipHooks()
            print("Tooltip hooks disabled")
        elseif cmd == "cache" then
            QuestTooltipEnhancerEngine:ClearCache()
            print("Tooltip cache cleared")
        elseif cmd == "config" then
            local config = QuestTooltipEnhancerEngine:GetConfig()
            print("Tooltip Configuration:")
            for key, value in pairs(config) do
                print("  " .. key .. ": " .. tostring(value))
            end
        elseif cmd == "status" then
            local status = QuestTooltipEnhancerEngine:GetStatus()
            print("Quest Tooltip Engine Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Hooks Active: " .. status.hooks_active)
            print("  Cached Tooltips: " .. status.cached_tooltips .. "/" .. status.max_cache)
            print("  Show Info: " .. (status.show_quest_info and "Yes" or "No"))
            print("  Show Rewards: " .. (status.show_quest_rewards and "Yes" or "No"))
        else
            print("Quest Tooltip Commands:")
            print("  /questtooltip toggle <config> - Toggle configuration")
            print("  /questtooltip enable - Enable hooks")
            print("  /questtooltip disable - Disable hooks")
            print("  /questtooltip cache - Clear cache")
            print("  /questtooltip config - Show configuration")
            print("  /questtooltip status - Show engine status")
        end
    end
end

return QuestTooltipEnhancerEngine
