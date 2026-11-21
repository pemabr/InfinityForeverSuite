-- InfinityRaidAssignments Module
-- Manages raid roles, assignments, and member positioning

InfinityRaidAssignments = {}
InfinityRaidAssignments.assignments = {}
InfinityRaidAssignments.positioning = {}

function InfinityRaidAssignments:Initialize()
	local storageData = InfinityStorageManager:GetFeatureSetting("InfinityRaid", "assignments", {})
	self.assignments = storageData.assignments or {}
	self.positioning = storageData.positioning or {}
	
	InfinityUtils:Info("RaidAssignments module initialized", "InfinityRaid")
end

function InfinityRaidAssignments:AssignRole(memberName, role, group)
	local assignment = {
		member = memberName,
		role = role or "DPS",
		group = group or 1,
		assigned = InfinityUtils:GetTimeStamp(),
	}
	
	self.assignments[memberName] = assignment
	self:SaveAssignments()
	InfinityMessaging:Publish("role_assigned", { member = memberName, role = role, group = group })
	
	return assignment
end

function InfinityRaidAssignments:SetPosition(memberName, x, y, z)
	local position = {
		member = memberName,
		x = x or 0,
		y = y or 0,
		z = z or 0,
		recorded = InfinityUtils:GetTimeStamp(),
	}
	
	self.positioning[memberName] = position
	self:SaveAssignments()
	
	return position
end

function InfinityRaidAssignments:GetRaidComposition()
	local composition = {}
	
	for memberName, assignment in pairs(self.assignments) do
		local role = assignment.role
		if not composition[role] then
			composition[role] = {}
		end
		table.insert(composition[role], {
			name = memberName,
			group = assignment.group,
		})
	end
	
	return composition
end

function InfinityRaidAssignments:SaveAssignments()
	InfinityStorageManager:SetFeatureSetting("InfinityRaid", "assignments", {
		assignments = self.assignments,
		positioning = self.positioning,
	})
	InfinityDataManager:UpdateSourceData("InfinityRaid", "assignments", {
		assignments = self.assignments,
		positioning = self.positioning,
	})
end

return InfinityRaidAssignments
