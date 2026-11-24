-- PluribusCore Messaging System
-- Inter-addon communication framework

PluribusMessaging = {
	subscribers = {},
	messageHistory = {},
	maxHistory = 100,
}

-- Register a listener for a specific event
function PluribusMessaging:Subscribe(eventName, callback, priority)
	if not self.subscribers[eventName] then
		self.subscribers[eventName] = {}
	end
	
	priority = priority or 0
	
	local subscription = {
		callback = callback,
		priority = priority,
		active = true,
	}
	
	table.insert(self.subscribers[eventName], subscription)
	
	-- Sort by priority
	table.sort(self.subscribers[eventName], function(a, b)
		return a.priority > b.priority
	end)
	
	PluribusUtils:Debug("Subscriber registered for: " .. eventName, "Messaging")
	
	-- Return unsubscribe function
	return function()
		subscription.active = false
	end
end

-- Publish a message/event to all subscribers
function PluribusMessaging:Publish(eventName, ...)
	local args = {...}
	local timestamp = PluribusUtils:GetTimeStamp()
	
	-- Store in history
	table.insert(self.messageHistory, {
		event = eventName,
		timestamp = timestamp,
		args = args,
	})
	
	-- Clean up old history
	if #self.messageHistory > self.maxHistory then
		table.remove(self.messageHistory, 1)
	end
	
	-- Call subscribers
	if self.subscribers[eventName] then
		for _, subscription in ipairs(self.subscribers[eventName]) do
			if subscription.active then
				pcall(subscription.callback, unpack(args))
			end
		end
	end
	
	PluribusUtils:Debug("Event published: " .. eventName, "Messaging")
end

-- Get message history (for debugging)
function PluribusMessaging:GetHistory(eventName, limit)
	limit = limit or 10
	local result = {}
	
	for i = #self.messageHistory, 1, -1 do
		if not eventName or self.messageHistory[i].event == eventName then
			table.insert(result, self.messageHistory[i])
			if #result >= limit then
				break
			end
		end
	end
	
	return result
end

-- Query message statistics
function PluribusMessaging:GetStatistics()
	local stats = {
		subscriberCount = 0,
		eventTypes = 0,
		historySize = #self.messageHistory,
	}
	
	for _, subscribers in pairs(self.subscribers) do
		stats.eventTypes = stats.eventTypes + 1
		for _, sub in ipairs(subscribers) do
			if sub.active then
				stats.subscriberCount = stats.subscriberCount + 1
			end
		end
	end
	
	return stats
end

-- Clear inactive subscriptions
function PluribusMessaging:Cleanup()
	for eventName, subscribers in pairs(self.subscribers) do
		local active = {}
		for _, sub in ipairs(subscribers) do
			if sub.active then
				table.insert(active, sub)
			end
		end
		self.subscribers[eventName] = active
		if #active == 0 then
			self.subscribers[eventName] = nil
		end
	end
	
	PluribusUtils:Info("Messaging cleanup completed", "Messaging")
end

-- Wait for a specific event (for coroutines or async operations)
function PluribusMessaging:WaitFor(eventName, timeout)
	local result = nil
	local done = false
	
	local unsub = self:Subscribe(eventName, function(...)
		result = {...}
		done = true
	end)
	
	-- Wait with optional timeout
	local startTime = PluribusUtils:GetTimeStamp()
	while not done and (not timeout or (PluribusUtils:GetTimeStamp() - startTime) < timeout) do
		coroutine.yield()
	end
	
	unsub()
	return result
end

return PluribusMessaging
