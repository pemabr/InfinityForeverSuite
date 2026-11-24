-- PluribusRaidAssignments Module
-- Manages raid roles, assignments, and member positioning

PluribusRaidAssignments = {}
PluribusRaidAssignments.assignments = {}
PluribusRaidAssignments.positioning = {}

function PluribusRaidAssignments:Initialize()
	local storageData = PluribusStorageManager:GetFeatureSetting("PluribusRaid", "assignments", {})
	self.assignments = storageData.assignments or {}
	self.positioning = storageData.positioning or {}
	
	PluribusUtils:Info("RaidAssignments module initialized", "PluribusRaid")
end

function PluribusRaidAssignments:AssignRole(memberName, role, group)
	local assignment = {
		member = memberName,
		role = role or "DPS",
		group = group or 1,
		assigned = PluribusUtils:GetTimeStamp(),
	}
	
	self.assignments[memberName] = assignment
	self:SaveAssignments()
	PluribusMessaging:Publish("role_assigned", { member = memberName, role = role, group = group })
	
	return assignment
end

function PluribusRaidAssignments:SetPosition(memberName, x, y, z)
	local position = {
		member = memberName,
		x = x or 0,
		y = y or 0,
		z = z or 0,
		recorded = PluribusUtils:GetTimeStamp(),
	}
	
	self.positioning[memberName] = position
	self:SaveAssignments()
	
	return position
end

function PluribusRaidAssignments:GetRaidComposition()
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

function PluribusRaidAssignments:SaveAssignments()
	PluribusStorageManager:SetFeatureSetting("PluribusRaid", "assignments", {
		assignments = self.assignments,
		positioning = self.positioning,
	})
	PluribusDataManager:UpdateSourceData("PluribusRaid", "assignments", {
		assignments = self.assignments,
		positioning = self.positioning,
	})
end

return PluribusRaidAssignments
