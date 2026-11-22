local InfinityWayPointUI = {}
_G.InfinityWayPointUI = InfinityWayPointUI

function InfinityWayPointUI:Initialize()
	if self.frame then return end
	self.frame = InfinityUIFramework:CreateListWindow("InfinityWayPointFrame", "Navigation", 600, 450)
	local save = InfinityUIFramework:CreateButton(self.frame, "Save position", 120, 22, function()
		local ok, result = InfinityNavigator:SavePlayerPosition("Saved position")
		if not ok then InfinityUtils:Warning(result, "Navigation") end
		self:Refresh()
	end)
	save:SetPoint("TOPRIGHT", -40, -34)
	local edit = InfinityUIFramework:CreateButton(self.frame, "Manage", 100, 22, function() self:ShowEditor() end)
	edit:SetPoint("RIGHT", save, "LEFT", -8, 0)
end

local function InputValue(box)
	local value = box:GetText()
	if _G.issecretvalue and _G.issecretvalue(value) then
		InfinityUtils:Warning("Protected input cannot be used.", "Navigation")
		return nil
	end
	if type(value) ~= "string" then InfinityUtils:Warning("Input unavailable.", "Navigation"); return nil end
	return value:match("^%s*(.-)%s*$")
end

function InfinityWayPointUI:ShowEditor()
	if not self.editor then
		local frame = InfinityUIFramework:CreateListWindow("InfinityWaypointEditorWindow", "Manage Waypoints", 720, 470)
		local function Input(labelText, x, offset, width, max)
			local label = InfinityUIFramework:CreateLabel(frame, labelText)
			label:SetPoint("TOPLEFT", x, -43)
			local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
			box:SetSize(width, 20)
			box:SetPoint("TOPLEFT", x + offset, -38)
			box:SetAutoFocus(false)
			box:SetMaxLetters(max)
			return box
		end
		self.editorID = Input("Map/quest/number", 15, 120, 80, 10)
		self.editorX = Input("X %", 230, 35, 55, 10)
		self.editorY = Input("Y %", 335, 35, 55, 10)
		self.editorName = Input("Name", 445, 45, 180, 100)
		self.editor = frame
	end
	self.confirmRemoval, self.confirmClear = nil, nil
	self:RefreshEditor()
	self.editor:Show()
end

function InfinityWayPointUI:RefreshEditor()
	if not self.editor then return end
	local navigator = InfinityNavigator
	local function Values()
		local id, x, y, name = InputValue(self.editorID), InputValue(self.editorX), InputValue(self.editorY), InputValue(self.editorName)
		if not id or not x or not y or not name then return nil end
		return tonumber(id), tonumber(x), tonumber(y), name
	end
	local rows = {
		{ text = "Save current position | optional Name", onClick = function()
			local _, _, _, name = Values()
			if not name then return end
			local ok, problem = navigator:SavePlayerPosition(name ~= "" and name or "Saved position")
			if not ok then InfinityUtils:Warning(problem, "Navigation") else self:Refresh() end
		end },
		{ text = "Add waypoint | Map ID, X %, Y %, Name", onClick = function()
			local id, x, y, name = Values()
			local ok, problem
			if x and y then ok, problem = navigator:AddWaypoint(x / 100, y / 100, id, name) end
			if not ok then InfinityUtils:Warning(problem or "Invalid map ID, coordinates or name.", "Navigation") else self:Refresh() end
		end },
		{ text = "Track quest waypoint | Quest ID", onClick = function()
			local id = Values()
			navigator:SetObjective(id)
		end },
		{ text = "Remove saved waypoint | Number; click twice to confirm", onClick = function()
			local id = Values()
			local point = id and navigator.waypoints[id]
			if not point then self.confirmRemoval = nil; InfinityUtils:Warning("Waypoint number not found.", "Navigation"); return end
			if not self.confirmRemoval or self.confirmRemoval.id ~= id or self.confirmRemoval.point ~= point then
				self.confirmRemoval, self.confirmClear = { id = id, point = point }, nil
				self.editor.status:SetText("Remove waypoint " .. id .. " (" .. point.description .. ")? Click again.")
			elseif navigator:RemoveWaypoint(id) then
				self.confirmRemoval = nil
				self:Refresh()
				self:RefreshEditor()
			end
		end },
		{ text = "Clear all saved waypoints | click twice to confirm", onClick = function()
			local matches = self.confirmClear and #self.confirmClear == #navigator.waypoints
			if matches then
				for index, waypoint in ipairs(navigator.waypoints) do
					if self.confirmClear[index] ~= waypoint then matches = false; break end
				end
			end
			if not matches then
				self.confirmClear, self.confirmRemoval = {}, nil
				for index, waypoint in ipairs(navigator.waypoints) do self.confirmClear[index] = waypoint end
				self.editor.status:SetText("Clear all saved waypoints? Active map marker remains. Click again.")
			else
				self.confirmClear = nil
				navigator:ClearWaypoints()
				self:Refresh()
				self:RefreshEditor()
			end
		end },
	}
	self.editor:SetItems(rows)
	self.editor.status:SetText("Enter the requested values above and click an action.")
end

function InfinityWayPointUI:Refresh()
	if not self.frame then return end
	local items = {}
	for index, entry in ipairs(InfinityNavigator.waypoints) do
		local waypoint = entry
		items[#items + 1] = {
			text = string.format("%d. %s - map %d (%.1f, %.1f)", index, waypoint.description,
				waypoint.mapID, waypoint.x * 100, waypoint.y * 100),
			onClick = function() InfinityNavigator:SetWaypoint(waypoint) end,
		}
	end
	if #items == 0 then items[1] = { text = "No saved waypoints." } end
	self.frame.status:SetText("Click a waypoint to track it. Use Manage to edit waypoints.")
	self.frame:SetItems(items)
end

function InfinityWayPointUI:Toggle()
	self:Initialize()
	if self.frame:IsShown() then
		self.frame:Hide()
	else
		self:Refresh()
		self.frame:Show()
	end
end

return InfinityWayPointUI
