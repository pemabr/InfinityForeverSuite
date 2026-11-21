-- InfinityCore Event Router
-- Centralized WoW event handling to prevent duplicate listeners

InfinityEventRouter = {
	listeners = {},
	eventFrame = CreateFrame("Frame", "InfinityEventFrame"),
	registeredEvents = {},
}

-- Register to listen for a WoW event
function InfinityEventRouter:RegisterEvent(eventName, callback, priority)
	if not self.listeners[eventName] then
		self.listeners[eventName] = {}
		self.eventFrame:RegisterEvent(eventName)
		self.registeredEvents[eventName] = true
	end
	
	priority = priority or 0
	
	local listener = {
		callback = callback,
		priority = priority,
		active = true,
	}
	
	table.insert(self.listeners[eventName], listener)
	
	-- Sort by priority
	table.sort(self.listeners[eventName], function(a, b)
		return a.priority > b.priority
	end)
	
	InfinityUtils:Debug("WoW event registered: " .. eventName, "EventRouter")
	
	-- Return unregister function
	return function()
		listener.active = false
	end
end

-- Unregister from a WoW event entirely
function InfinityEventRouter:UnregisterEvent(eventName)
	if self.registeredEvents[eventName] then
		self.eventFrame:UnregisterEvent(eventName)
		self.registeredEvents[eventName] = nil
		self.listeners[eventName] = nil
		InfinityUtils:Debug("WoW event unregistered: " .. eventName, "EventRouter")
		return true
	end
	return false
end

-- Main event handler
function InfinityEventRouter:HandleEvent(eventName, ...)
	if not self.listeners[eventName] then
		return
	end
	
	-- Call all active listeners
	for _, listener in ipairs(self.listeners[eventName]) do
		if listener.active then
			pcall(listener.callback, eventName, ...)
		end
	end
end

-- Set up the frame to receive events
function InfinityEventRouter:Initialize()
	self.eventFrame:SetScript("OnEvent", function(frame, eventName, ...)
		InfinityEventRouter:HandleEvent(eventName, ...)
	end)
	
	InfinityUtils:Info("Event Router initialized", "EventRouter")
end

-- Get listener statistics
function InfinityEventRouter:GetStatistics()
	local stats = {
		registeredEvents = 0,
		totalListeners = 0,
		activeListeners = 0,
	}
	
	for eventName, listeners in pairs(self.listeners) do
		stats.registeredEvents = stats.registeredEvents + 1
		for _, listener in ipairs(listeners) do
			stats.totalListeners = stats.totalListeners + 1
			if listener.active then
				stats.activeListeners = stats.activeListeners + 1
			end
		end
	end
	
	return stats
end

-- Cleanup inactive listeners
function InfinityEventRouter:Cleanup()
	for eventName, listeners in pairs(self.listeners) do
		local active = {}
		for _, listener in ipairs(listeners) do
			if listener.active then
				table.insert(active, listener)
			end
		end
		self.listeners[eventName] = active
		if #active == 0 then
			self:UnregisterEvent(eventName)
		end
	end
	
	InfinityUtils:Info("Event Router cleanup completed", "EventRouter")
end

return InfinityEventRouter
