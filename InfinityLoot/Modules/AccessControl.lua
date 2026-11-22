-- InfinityLoot Access Control System
-- Manage loot master, assistant, and member roles with permission levels

InfinityLootAccessControl = {
	db = {},
	roles = {}, -- playerName -> role
	permissions = {}, -- role -> {permission -> true/false}
	version = "1.0.0",
}

-- Define role hierarchy and permissions
local ROLE_DEFINITIONS = {
	["admin"] = {
		level = 3,
		permissions = {
			["manage_auctions"] = true,
			["close_auctions"] = true,
			["record_loot"] = true,
			["adjust_points"] = true,
			["manage_roles"] = true,
			["decay_points"] = true,
			["configure_settings"] = true,
			["export_data"] = true,
			["delete_records"] = true,
			["undo_actions"] = true,
		},
	},
	["manager"] = {
		level = 2,
		permissions = {
			["manage_auctions"] = true,
			["close_auctions"] = true,
			["record_loot"] = true,
			["adjust_points"] = false, -- Managers can't adjust, only admins
			["manage_roles"] = false,
			["decay_points"] = false,
			["configure_settings"] = false,
			["export_data"] = true,
			["delete_records"] = false,
			["undo_actions"] = false,
		},
	},
	["assistant"] = {
		level = 1,
		permissions = {
			["manage_auctions"] = false,
			["close_auctions"] = false,
			["record_loot"] = true, -- Can record loot
			["adjust_points"] = false,
			["manage_roles"] = false,
			["decay_points"] = false,
			["configure_settings"] = false,
			["export_data"] = false,
			["delete_records"] = false,
			["undo_actions"] = false,
		},
	},
	["member"] = {
		level = 0,
		permissions = {
			["manage_auctions"] = false,
			["close_auctions"] = false,
			["record_loot"] = false,
			["adjust_points"] = false,
			["manage_roles"] = false,
			["decay_points"] = false,
			["configure_settings"] = false,
			["export_data"] = false,
			["delete_records"] = false,
			["undo_actions"] = false,
		},
	},
}

-- Initialize access control system
function InfinityLootAccessControl:Initialize()
	InfinityUtils:Info("Access Control system initializing...", "InfinityLoot")
	
	self.db = InfinityStorageManager:GetFeatureSettings(INFINITY_FEATURES.LOOT) or {}
	
	if not self.db.roles then
		self.db.roles = {}
	end
	
	-- Make current player an admin by default if no admins exist
	if self:CountAdmins() == 0 then
		self:SetPlayerRole(UnitName("player"), "admin")
		InfinityUtils:Info("Current player set as admin (first admin)", "AccessControl")
	end
	
	InfinityUtils:Info("Access Control system initialized", "InfinityLoot")
end

-- ============================================================================
-- ROLE MANAGEMENT
-- ============================================================================

-- Set a player's role
function InfinityLootAccessControl:SetPlayerRole(playerName, role)
	-- Only admins can change roles
	local currentPlayer = UnitName("player")
	local currentRole = self:GetPlayerRole(currentPlayer)
	
	if currentRole ~= "admin" then
		InfinityUtils:Warning("Only admins can assign roles", "AccessControl")
		return false
	end
	
	-- Validate role
	if not ROLE_DEFINITIONS[role] then
		InfinityUtils:Warning("Invalid role: " .. tostring(role), "AccessControl")
		return false
	end
	
	self.db.roles[playerName] = {
		role = role,
		setBy = currentPlayer,
		setTime = GetTime(),
	}
	
	InfinityMessaging:Publish("role_changed", {
		player = playerName,
		role = role,
		setBy = currentPlayer,
	})
	
	InfinityUtils:Info(playerName .. " assigned role: " .. role, "AccessControl")
	return true
end

-- Get a player's role
function InfinityLootAccessControl:GetPlayerRole(playerName)
	if self.db.roles[playerName] then
		return self.db.roles[playerName].role
	end
	
	-- Default role for unassigned players
	return "member"
end

-- Get role details
function InfinityLootAccessControl:GetRoleDetails(role)
	return ROLE_DEFINITIONS[role] or ROLE_DEFINITIONS["member"]
end

-- ============================================================================
-- PERMISSION CHECKING
-- ============================================================================

-- Check if player has permission for an action
function InfinityLootAccessControl:HasPermission(playerName, permission)
	local role = self:GetPlayerRole(playerName)
	local roleDetails = ROLE_DEFINITIONS[role]
	
	if not roleDetails then
		return false
	end
	
	return roleDetails.permissions[permission] or false
end

-- Check current player's permission
function InfinityLootAccessControl:CanDoAction(permission)
	local currentPlayer = UnitName("player")
	local hasPermission = self:HasPermission(currentPlayer, permission)
	
	if not hasPermission then
		InfinityUtils:Warning("Permission denied: " .. permission, "AccessControl")
	end
	
	return hasPermission
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Count number of admins
function InfinityLootAccessControl:CountAdmins()
	local count = 0
	for _, roleData in pairs(self.db.roles) do
		if roleData.role == "admin" then
			count = count + 1
		end
	end
	return count
end

-- Get all players with a specific role
function InfinityLootAccessControl:GetPlayersWithRole(role)
	local players = {}
	for playerName, roleData in pairs(self.db.roles) do
		if roleData.role == role then
			table.insert(players, playerName)
		end
	end
	return players
end

-- Get all roles
function InfinityLootAccessControl:GetAllRoles()
	return self.db.roles or {}
end

-- Remove a player's role (back to member)
function InfinityLootAccessControl:RemovePlayerRole(playerName)
	if not self:CanDoAction("manage_roles") then
		return false
	end
	
	self.db.roles[playerName] = nil
	
	InfinityUtils:Info(playerName .. " role removed (reverted to member)", "AccessControl")
	return true
end

-- ============================================================================
-- AUDIT LOGGING
-- ============================================================================

-- Log an action for audit purposes
function InfinityLootAccessControl:LogAction(playerName, action, details)
	if not self.db.auditLog then
		self.db.auditLog = {}
	end
	
	local logEntry = {
		player = playerName,
		action = action,
		details = details or "",
		timestamp = GetTime(),
		ip = "local", -- Would be IP in real system
	}
	
	table.insert(self.db.auditLog, logEntry)
	
	-- Keep only last 1000 entries
	if #self.db.auditLog > 1000 then
		table.remove(self.db.auditLog, 1)
	end
	
	return true
end

-- Get audit log
function InfinityLootAccessControl:GetAuditLog(limit)
	if not self.db.auditLog then
		return {}
	end
	
	limit = limit or 100
	local result = {}
	
	for i = #self.db.auditLog, math.max(1, #self.db.auditLog - limit + 1), -1 do
		table.insert(result, self.db.auditLog[i])
	end
	
	return result
end

-- ============================================================================
-- STATISTICS
-- ============================================================================

function InfinityLootAccessControl:GetStats()
	local stats = {
		totalAdmins = 0,
		totalManagers = 0,
		totalAssistants = 0,
		totalMembers = 0,
		auditLogSize = self.db.auditLog and #self.db.auditLog or 0,
	}
	
	for _, roleData in pairs(self.db.roles) do
		if roleData.role == "admin" then
			stats.totalAdmins = stats.totalAdmins + 1
		elseif roleData.role == "manager" then
			stats.totalManagers = stats.totalManagers + 1
		elseif roleData.role == "assistant" then
			stats.totalAssistants = stats.totalAssistants + 1
		else
			stats.totalMembers = stats.totalMembers + 1
		end
	end
	
	return stats
end

return InfinityLootAccessControl
