local UI = {}
_G.InfinityHealerUI = UI

local function InputValue(input)
	local text = input and input:GetText()
	if _G.issecretvalue and _G.issecretvalue(text) then
		InfinityUtils:Warning("Protected input cannot be used.", "Healer")
		return nil
	end
	if type(text) ~= "string" then return nil end
	return text:match("^%s*(.-)%s*$")
end

function UI:Initialize()
	InfinityUtils:Info("Healer UI initialized", "Healer")
end

function UI:Refresh()
	if not self.mainWindow then return end
	local bindings = InfinityClickCast:GetAllBindings()
	local rows = {
		{
			text = "Group frames: " .. (InfinityHealer.settings.visible and "On" or "Off") .. " (click to toggle)",
			onClick = function() InfinityHealer:ToggleFrames(); self:Refresh() end,
		},
		{ text = "Left click targets the unit." },
	}
	for _, key in ipairs({ "right", "shift-right", "ctrl-right", "alt-right" }) do
		local binding = key
		rows[#rows + 1] = {
			text = binding .. ": " .. (bindings[binding] and ("spell ID " .. bindings[binding]) or "no explicit binding"),
			onClick = function()
				local value = InputValue(self.input)
				if not value or value == "" then
					InfinityUtils:Warning("Enter a spell ID or clear, then select a binding.", "Healer")
				elseif value:lower() == "clear" then
					InfinityClickCast:SetBinding(binding, nil)
				else
					local id = tonumber(value)
					if id then InfinityClickCast:SetBinding(binding, id)
					else InfinityUtils:Warning("Enter a valid spell ID or clear.", "Healer") end
				end
				self:Refresh()
			end,
		}
	end
	rows[#rows + 1] = { text = "Enter a spell ID above, then click a binding. Enter clear to remove it." }
	rows[#rows + 1] = { text = "Enter a scale from 0.5 to 2 above, then click Set Scale." }
	rows[#rows + 1] = {
		text = "Group reports: " .. (InfinityGroupStatus.settings.groupSharing and "On" or "Off") .. " (click to toggle)",
		onClick = function() InfinityGroupStatus:SetEnabled(not InfinityGroupStatus.settings.groupSharing); self:Refresh() end,
	}
	rows[#rows + 1] = { text = "Shares your readable cooldowns and effects with the current group/raid." }
	rows[#rows + 1] = { text = "Open group reports and manage watched spells (click)",
		onClick = function() InfinityGroupStatus:Toggle() end }
	self.mainWindow:SetItems(rows)
	local status = "Bindings are character-specific; group changes during combat are deferred."
	if InfinityHealer.rosterPending then
		status = InCombatLockdown and InCombatLockdown() and "Roster changed; avoid frame clicks until combat ends."
			or "Group roster unavailable; frames hidden."
	elseif InfinityHealer.pending then
		status = "Secure frame updates apply after combat."
	end
	self.mainWindow.status:SetText(status)
end

function UI:Toggle()
	if not self.mainWindow then
		self.mainWindow = InfinityUIFramework:CreateListWindow("InfinityHealerMainWindow", "Healer group frames", 650, 400)
		self.input = CreateFrame("EditBox", nil, self.mainWindow, "InputBoxTemplate")
		self.input:SetSize(110, 20)
		self.input:SetPoint("TOPLEFT", self.mainWindow, "TOPLEFT", 20, -40)
		self.input:SetAutoFocus(false)
		self.input:SetMaxLetters(16)
		local scale = InfinityUIFramework:CreateButton(self.mainWindow, "Set Scale", 90, 22, function()
			local value = InputValue(self.input)
			if not value then return end
			InfinityHealer:SetFrameScale(tonumber(value))
			self:Refresh()
		end)
		scale:SetPoint("LEFT", self.input, "RIGHT", 12, 0)
		self.scaleButton = scale
	end
	if self.mainWindow:IsShown() then
		self.mainWindow:Hide()
	else
		self:Refresh()
		self.mainWindow:Show()
	end
end

return UI
