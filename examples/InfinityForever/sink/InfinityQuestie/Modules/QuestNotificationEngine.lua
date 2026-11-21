-- QuestNotificationEngine.lua - Quest notification and alert system
-- Part of InfinityQuestie addon suite
-- Manages quest notifications, deadlines, and important alerts

local QuestNotificationEngine = {}
QuestNotificationEngine.enabled = false
QuestNotificationEngine.db = nil
QuestNotificationEngine.notifications = {}
QuestNotificationEngine.notification_config = {}
QuestNotificationEngine.notification_history = {}

-- Configuration
QuestNotificationEngine.config = {
    enabled = true,
    notify_on_complete = true,
    notify_on_expire = true,
    notify_on_new = true,
    sound_enabled = true,
    max_notifications = 10,
}

-- Notification types
QuestNotificationEngine.notification_types = {
    COMPLETE = "quest_complete",
    EXPIRE = "quest_expire",
    NEW = "quest_new",
    REMINDER = "quest_reminder",
    WARNING = "quest_warning",
    DEADLINE = "quest_deadline",
}

-- Priority levels
QuestNotificationEngine.priority_levels = {
    LOW = 1,
    MEDIUM = 2,
    HIGH = 3,
    CRITICAL = 4,
}

function QuestNotificationEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.notifications then
        self.db.notifications = {}
    end
    
    if not self.db.notification_config then
        self.db.notification_config = {}
    end
    
    if not self.db.notification_history then
        self.db.notification_history = {}
    end
    
    self.notifications = self.db.notifications
    self.notification_config = self.db.notification_config
    self.notification_history = self.db.notification_history
    self.enabled = true
    
    self:Log("Initialized notification engine")
end

function QuestNotificationEngine:CreateNotification(questId, notificationType, message)
    if not questId or not notificationType or not message then
        return nil
    end
    
    local notification = {
        id = "notif_" .. questId .. "_" .. GetTime(),
        quest_id = tonumber(questId),
        type = notificationType,
        message = message,
        created_at = GetTime(),
        read = false,
        priority = self:DeterminePriority(notificationType),
        expires_at = GetTime() + 3600,  -- 1 hour default
    }
    
    table.insert(self.notifications, notification)
    
    -- Keep only last N notifications
    while #self.notifications > self.config.max_notifications do
        table.remove(self.notifications, 1)
    end
    
    self:Log("Created notification: " .. notificationType .. " for quest " .. questId)
    
    return notification
end

function QuestNotificationEngine:DeterminePriority(notificationType)
    if notificationType == self.notification_types.DEADLINE then
        return self.priority_levels.CRITICAL
    elseif notificationType == self.notification_types.EXPIRE then
        return self.priority_levels.HIGH
    elseif notificationType == self.notification_types.WARNING then
        return self.priority_levels.HIGH
    elseif notificationType == self.notification_types.REMINDER then
        return self.priority_levels.MEDIUM
    elseif notificationType == self.notification_types.COMPLETE then
        return self.priority_levels.MEDIUM
    else
        return self.priority_levels.LOW
    end
end

function QuestNotificationEngine:NotifyQuestComplete(questId, reward)
    local message = "Quest completed!"
    
    if reward and reward.gold then
        message = message .. " Reward: " .. reward.gold .. "g"
    end
    
    return self:CreateNotification(questId, self.notification_types.COMPLETE, message)
end

function QuestNotificationEngine:NotifyQuestExpiring(questId, timeRemaining)
    local message = "Quest expires in " .. timeRemaining .. " minutes!"
    
    return self:CreateNotification(questId, self.notification_types.EXPIRE, message)
end

function QuestNotificationEngine:NotifyNewQuest(questId, questName)
    local message = "New quest accepted: " .. (questName or "Unknown")
    
    return self:CreateNotification(questId, self.notification_types.NEW, message)
end

function QuestNotificationEngine:NotifyDeadline(questId, deadline)
    local message = "Quest deadline approaching!"
    
    return self:CreateNotification(questId, self.notification_types.DEADLINE, message)
end

function QuestNotificationEngine:NotifyWarning(questId, warning)
    return self:CreateNotification(questId, self.notification_types.WARNING, warning)
end

function QuestNotificationEngine:NotifyReminder(questId, reminder)
    return self:CreateNotification(questId, self.notification_types.REMINDER, reminder)
end

function QuestNotificationEngine:MarkAsRead(notificationId)
    if not notificationId then
        return false
    end
    
    for _, notif in ipairs(self.notifications) do
        if notif.id == notificationId then
            notif.read = true
            self:Log("Marked notification as read: " .. notificationId)
            return true
        end
    end
    
    return false
end

function QuestNotificationEngine:GetUnreadNotifications()
    local unread = {}
    
    for _, notif in ipairs(self.notifications) do
        if not notif.read then
            table.insert(unread, notif)
        end
    end
    
    -- Sort by priority descending, then by creation time descending
    table.sort(unread, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        return a.created_at > b.created_at
    end)
    
    return unread
end

function QuestNotificationEngine:GetNotificationsByType(notificationType)
    local result = {}
    
    for _, notif in ipairs(self.notifications) do
        if notif.type == notificationType then
            table.insert(result, notif)
        end
    end
    
    return result
end

function QuestNotificationEngine:GetNotificationsForQuest(questId)
    questId = tonumber(questId)
    local result = {}
    
    for _, notif in ipairs(self.notifications) do
        if notif.quest_id == questId then
            table.insert(result, notif)
        end
    end
    
    return result
end

function QuestNotificationEngine:ClearExpiredNotifications()
    local count = 0
    local currentTime = GetTime()
    
    for i = #self.notifications, 1, -1 do
        if self.notifications[i].expires_at < currentTime then
            table.remove(self.notifications, i)
            count = count + 1
        end
    end
    
    self:Log("Cleared " .. count .. " expired notifications")
    
    return count
end

function QuestNotificationEngine:ClearAllNotifications()
    local count = #self.notifications
    self.notifications = {}
    self.db.notifications = {}
    
    self:Log("Cleared all notifications")
    
    return count
end

function QuestNotificationEngine:GetNotificationCount()
    return #self.notifications
end

function QuestNotificationEngine:GetUnreadCount()
    local count = 0
    
    for _, notif in ipairs(self.notifications) do
        if not notif.read then
            count = count + 1
        end
    end
    
    return count
end

function QuestNotificationEngine:GetNotificationStatistics()
    local stats = {
        total = #self.notifications,
        unread = 0,
        by_type = {},
        by_priority = {},
        by_quest = {},
    }
    
    for _, notif in ipairs(self.notifications) do
        if not notif.read then
            stats.unread = stats.unread + 1
        end
        
        if not stats.by_type[notif.type] then
            stats.by_type[notif.type] = 0
        end
        stats.by_type[notif.type] = stats.by_type[notif.type] + 1
        
        if not stats.by_priority[notif.priority] then
            stats.by_priority[notif.priority] = 0
        end
        stats.by_priority[notif.priority] = stats.by_priority[notif.priority] + 1
    end
    
    return stats
end

function QuestNotificationEngine:SetNotificationExpiry(notificationId, seconds)
    if not notificationId then
        return false
    end
    
    seconds = tonumber(seconds) or 3600
    
    for _, notif in ipairs(self.notifications) do
        if notif.id == notificationId then
            notif.expires_at = GetTime() + seconds
            self:Log("Set notification expiry: " .. notificationId .. " in " .. seconds .. "s")
            return true
        end
    end
    
    return false
end

function QuestNotificationEngine:MarkAllAsRead()
    local count = 0
    
    for _, notif in ipairs(self.notifications) do
        if not notif.read then
            notif.read = true
            count = count + 1
        end
    end
    
    self:Log("Marked " .. count .. " notifications as read")
    
    return count
end

function QuestNotificationEngine:GetStatus()
    local stats = self:GetNotificationStatistics()
    
    return {
        enabled = self.enabled,
        total = stats.total,
        unread = stats.unread,
        sound_enabled = self.config.sound_enabled,
        notify_complete = self.config.notify_on_complete,
    }
end

function QuestNotificationEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestNotificationEngine] " .. message)
    else
        print("[QuestNotificationEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTNOTIFY1 = "/questnotify"
    SlashCmdList["QUESTNOTIFY"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "create" then
            local questId, msgText = args:match("^(%d+)%s+(.*)$")
            if questId and msgText then
                QuestNotificationEngine:CreateNotification(tonumber(questId), "custom", msgText)
                print("Created notification")
            else
                print("Usage: /questnotify create <questId> <message>")
            end
        elseif cmd == "complete" then
            local questId = tonumber(args)
            if questId then
                QuestNotificationEngine:NotifyQuestComplete(questId)
                print("Quest completion notification sent")
            else
                print("Usage: /questnotify complete <questId>")
            end
        elseif cmd == "unread" then
            local unread = QuestNotificationEngine:GetUnreadNotifications()
            print("Unread Notifications (" .. #unread .. "):")
            for i = 1, math.min(5, #unread) do
                print(i .. ". " .. unread[i].message)
            end
        elseif cmd == "mark" then
            if args ~= "" then
                local success = QuestNotificationEngine:MarkAsRead(args)
                print("Mark as read: " .. (success and "Success" or "Failed"))
            else
                print("Usage: /questnotify mark <notificationId>")
            end
        elseif cmd == "clear" then
            local count = QuestNotificationEngine:ClearExpiredNotifications()
            print("Cleared " .. count .. " expired notifications")
        elseif cmd == "stats" then
            local stats = QuestNotificationEngine:GetNotificationStatistics()
            print("Notification Statistics:")
            print("  Total: " .. stats.total)
            print("  Unread: " .. stats.unread)
            for notifType, count in pairs(stats.by_type) do
                print("  " .. notifType .. ": " .. count)
            end
        elseif cmd == "status" then
            local status = QuestNotificationEngine:GetStatus()
            print("Quest Notification Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Total: " .. status.total)
            print("  Unread: " .. status.unread)
            print("  Sound: " .. (status.sound_enabled and "On" or "Off"))
        else
            print("Quest Notification Commands:")
            print("  /questnotify create <questId> <message> - Create notification")
            print("  /questnotify complete <questId> - Notify quest complete")
            print("  /questnotify unread - Show unread notifications")
            print("  /questnotify mark <notifId> - Mark as read")
            print("  /questnotify clear - Clear expired notifications")
            print("  /questnotify stats - Show statistics")
            print("  /questnotify status - Show engine status")
        end
    end
end

return QuestNotificationEngine
