-- QuestUIMainWindowEngine.lua - Main quest UI window frame
-- Part of InfinityQuestie addon suite
-- Handles the primary UI window for displaying quests and quest information

local QuestUIMainWindowEngine = {}
QuestUIMainWindowEngine.enabled = false
QuestUIMainWindowEngine.db = nil
QuestUIMainWindowEngine.main_frame = nil
QuestUIMainWindowEngine.window_config = {}
QuestUIMainWindowEngine.displayed_quests = {}

-- Configuration
QuestUIMainWindowEngine.config = {
    enabled = true,
    width = 400,
    height = 600,
    x_offset = 100,
    y_offset = 100,
    show_on_startup = false,
    max_quest_display = 25,
}

function QuestUIMainWindowEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.window_config then
        self.db.window_config = {}
    end
    
    if not self.db.displayed_quests then
        self.db.displayed_quests = {}
    end
    
    self.window_config = self.db.window_config
    self.displayed_quests = self.db.displayed_quests
    self.enabled = true
    
    self:Log("Initialized quest UI main window engine")
end

function QuestUIMainWindowEngine:CreateMainFrame()
    if self.main_frame then
        self:Log("Main frame already exists")
        return self.main_frame
    end
    
    -- Create main frame (placeholder - would be actual WoW frame in production)
    self.main_frame = {
        frame_type = "main_window",
        width = self.config.width,
        height = self.config.height,
        x = self.config.x_offset,
        y = self.config.y_offset,
        visible = false,
        title = "Infinity Questie",
        created_at = GetTime(),
    }
    
    self:Log("Created main UI frame: " .. self.config.width .. "x" .. self.config.height)
    
    return self.main_frame
end

function QuestUIMainWindowEngine:ShowFrame()
    if not self.main_frame then
        self:CreateMainFrame()
    end
    
    self.main_frame.visible = true
    self:Log("Showed main UI frame")
    
    return true
end

function QuestUIMainWindowEngine:HideFrame()
    if not self.main_frame then
        return false
    end
    
    self.main_frame.visible = false
    self:Log("Hid main UI frame")
    
    return true
end

function QuestUIMainWindowEngine:IsFrameVisible()
    if not self.main_frame then
        return false
    end
    
    return self.main_frame.visible
end

function QuestUIMainWindowEngine:ToggleFrame()
    if not self.main_frame then
        self:CreateMainFrame()
    end
    
    if self.main_frame.visible then
        self:HideFrame()
    else
        self:ShowFrame()
    end
    
    return self.main_frame.visible
end

function QuestUIMainWindowEngine:SetFramePosition(x, y)
    if not self.main_frame then
        self:CreateMainFrame()
    end
    
    self.main_frame.x = x
    self.main_frame.y = y
    
    self:Log("Set frame position to (" .. x .. ", " .. y .. ")")
    
    return true
end

function QuestUIMainWindowEngine:SetFrameSize(width, height)
    if not self.main_frame then
        self:CreateMainFrame()
    end
    
    if width < 200 or height < 300 then
        self:Log("Invalid frame size")
        return false
    end
    
    self.main_frame.width = width
    self.main_frame.height = height
    
    self:Log("Set frame size to " .. width .. "x" .. height)
    
    return true
end

function QuestUIMainWindowEngine:DisplayQuests(questList)
    if not questList then
        return false
    end
    
    -- Clear previous display
    self.displayed_quests = {}
    
    -- Display up to max_quest_display quests
    local displayCount = 0
    
    for _, quest in ipairs(questList) do
        if displayCount >= self.config.max_quest_display then
            break
        end
        
        table.insert(self.displayed_quests, {
            id = quest.id,
            name = quest.name,
            level = quest.level,
            type = quest.type,
            display_index = displayCount + 1,
        })
        
        displayCount = displayCount + 1
    end
    
    self:Log("Displayed " .. displayCount .. " quests")
    
    return true
end

function QuestUIMainWindowEngine:ClearDisplay()
    self.displayed_quests = {}
    self:Log("Cleared quest display")
    return true
end

function QuestUIMainWindowEngine:GetDisplayedQuests()
    return self.displayed_quests
end

function QuestUIMainWindowEngine:GetDisplayedQuestCount()
    return #self.displayed_quests
end

function QuestUIMainWindowEngine:SelectQuest(questId)
    if not questId then
        return false
    end
    
    for _, quest in ipairs(self.displayed_quests) do
        if quest.id == questId then
            quest.selected = true
            self:Log("Selected quest: " .. questId)
            return true
        else
            quest.selected = false
        end
    end
    
    return false
end

function QuestUIMainWindowEngine:GetSelectedQuest()
    for _, quest in ipairs(self.displayed_quests) do
        if quest.selected then
            return quest
        end
    end
    
    return nil
end

function QuestUIMainWindowEngine:ResizeToContent()
    if not self.main_frame then
        self:CreateMainFrame()
    end
    
    local questCount = #self.displayed_quests
    local minHeight = 300
    local heightPerQuest = 30
    
    local newHeight = math.max(minHeight, questCount * heightPerQuest + 100)
    
    self.main_frame.height = newHeight
    
    self:Log("Resized frame to fit content: " .. newHeight)
    
    return true
end

function QuestUIMainWindowEngine:SaveWindowState()
    if not self.main_frame then
        return false
    end
    
    self.window_config.position = {
        x = self.main_frame.x,
        y = self.main_frame.y,
    }
    
    self.window_config.size = {
        width = self.main_frame.width,
        height = self.main_frame.height,
    }
    
    self.window_config.visible = self.main_frame.visible
    self.window_config.saved_at = GetTime()
    
    self:Log("Saved window state")
    
    return true
end

function QuestUIMainWindowEngine:LoadWindowState()
    if not self.window_config.position then
        return false
    end
    
    if not self.main_frame then
        self:CreateMainFrame()
    end
    
    self.main_frame.x = self.window_config.position.x
    self.main_frame.y = self.window_config.position.y
    self.main_frame.width = self.window_config.size.width or self.config.width
    self.main_frame.height = self.window_config.size.height or self.config.height
    self.main_frame.visible = self.window_config.visible or false
    
    self:Log("Loaded window state")
    
    return true
end

function QuestUIMainWindowEngine:ResetWindowState()
    self.main_frame.x = self.config.x_offset
    self.main_frame.y = self.config.y_offset
    self.main_frame.width = self.config.width
    self.main_frame.height = self.config.height
    self.main_frame.visible = false
    
    self.window_config = {}
    
    self:Log("Reset window state to defaults")
    
    return true
end

function QuestUIMainWindowEngine:GetFrameInfo()
    if not self.main_frame then
        return nil
    end
    
    return {
        x = self.main_frame.x,
        y = self.main_frame.y,
        width = self.main_frame.width,
        height = self.main_frame.height,
        visible = self.main_frame.visible,
        title = self.main_frame.title,
    }
end

function QuestUIMainWindowEngine:GetStatus()
    local questCount = #self.displayed_quests
    
    return {
        enabled = self.enabled,
        frame_created = self.main_frame ~= nil,
        frame_visible = self.main_frame and self.main_frame.visible or false,
        quests_displayed = questCount,
        max_display = self.config.max_quest_display,
    }
end

function QuestUIMainWindowEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestUIMainWindowEngine] " .. message)
    else
        print("[QuestUIMainWindowEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTUI1 = "/questui"
    SlashCmdList["QUESTUI"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "show" then
            QuestUIMainWindowEngine:ShowFrame()
            print("Quest UI window shown")
        elseif cmd == "hide" then
            QuestUIMainWindowEngine:HideFrame()
            print("Quest UI window hidden")
        elseif cmd == "toggle" then
            local visible = QuestUIMainWindowEngine:ToggleFrame()
            print("Quest UI window toggled: " .. (visible and "visible" or "hidden"))
        elseif cmd == "move" then
            local x, y = args:match("^([%d.]+)%s+([%d.]+)$")
            if x and y then
                x = tonumber(x)
                y = tonumber(y)
                QuestUIMainWindowEngine:SetFramePosition(x, y)
                print("Window moved to (" .. x .. ", " .. y .. ")")
            else
                print("Usage: /questui move <x> <y>")
            end
        elseif cmd == "resize" then
            local w, h = args:match("^([%d.]+)%s+([%d.]+)$")
            if w and h then
                w = tonumber(w)
                h = tonumber(h)
                QuestUIMainWindowEngine:SetFrameSize(w, h)
                print("Window resized to " .. w .. "x" .. h)
            else
                print("Usage: /questui resize <width> <height>")
            end
        elseif cmd == "clear" then
            QuestUIMainWindowEngine:ClearDisplay()
            print("Quest display cleared")
        elseif cmd == "reset" then
            QuestUIMainWindowEngine:ResetWindowState()
            print("Window state reset to defaults")
        elseif cmd == "save" then
            QuestUIMainWindowEngine:SaveWindowState()
            print("Window state saved")
        elseif cmd == "load" then
            QuestUIMainWindowEngine:LoadWindowState()
            print("Window state loaded")
        elseif cmd == "info" then
            local info = QuestUIMainWindowEngine:GetFrameInfo()
            if info then
                print("Quest UI Frame Info:")
                print("  Position: (" .. info.x .. ", " .. info.y .. ")")
                print("  Size: " .. info.width .. "x" .. info.height)
                print("  Visible: " .. (info.visible and "Yes" or "No"))
            else
                print("No frame created")
            end
        elseif cmd == "status" then
            local status = QuestUIMainWindowEngine:GetStatus()
            print("Quest UI Engine Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Frame Created: " .. (status.frame_created and "Yes" or "No"))
            print("  Frame Visible: " .. (status.frame_visible and "Yes" or "No"))
            print("  Quests Displayed: " .. status.quests_displayed .. "/" .. status.max_display)
        else
            print("Quest UI Commands:")
            print("  /questui show - Show window")
            print("  /questui hide - Hide window")
            print("  /questui toggle - Toggle visibility")
            print("  /questui move <x> <y> - Move window")
            print("  /questui resize <width> <height> - Resize window")
            print("  /questui clear - Clear quest display")
            print("  /questui reset - Reset to defaults")
            print("  /questui save - Save window state")
            print("  /questui load - Load window state")
            print("  /questui info - Show frame info")
            print("  /questui status - Show engine status")
        end
    end
end

return QuestUIMainWindowEngine
