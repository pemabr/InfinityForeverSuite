InfinityQoLUI = {}

local options = {
	{ name = "autoLootDefault", label = "Auto loot" },
	{ name = "autoSelfCast", label = "Auto self cast" },
	{ name = "autoQuestWatch", label = "Auto track quests" },
	{ name = "rotateMinimap", label = "Rotate minimap" },
}

local function CVarFunctions()
	local api = _G.C_CVar
	return (api and api.GetCVar) or _G.GetCVar, (api and api.SetCVar) or _G.SetCVar
end

function InfinityQoLUI:Initialize()
	if self.eventFrame then return end
	local events = CreateFrame("Frame")
	events:RegisterEvent("CVAR_UPDATE")
	events:SetScript("OnEvent", function()
		if InfinityQoLUI.frame and InfinityQoLUI.frame:IsShown() then
			InfinityQoLUI:Refresh()
		end
	end)
	self.eventFrame = events
end

function InfinityQoLUI:Refresh()
	if not self.frame then return end
	local get, set = CVarFunctions()
	if not get or not set then
		self.frame.status:SetText("Game settings API unavailable.")
		self.frame:SetItems({})
		return
	end
	local items = {}
	for _, option in ipairs(options) do
		local name, label = option.name, option.label
		local value = get(name)
		if _G.issecretvalue and _G.issecretvalue(value) then value = nil end
		if value == "0" or value == "1" then
			items[#items + 1] = {
				text = label .. ": " .. (value == "1" and "On" or "Off"),
				onClick = function()
					local current = get(name)
					if _G.issecretvalue and _G.issecretvalue(current) then current = nil end
					if current ~= "0" and current ~= "1" then
						InfinityUtils:Warning("Setting unavailable: " .. label, "QoL")
						return
					end
					set(name, current == "1" and "0" or "1")
					InfinityQoLUI:Refresh()
				end,
			}
		else
			items[#items + 1] = { text = label .. ": unavailable" }
		end
	end
	self.frame.status:SetText("Click an option to change the game setting.")
	self.frame:SetItems(items)
end

function InfinityQoLUI:Toggle()
	if not self.frame then
		self.frame = InfinityUIFramework:CreateListWindow("InfinityQoLWindow", "Quality of Life", 500, 300)
	end
	if self.frame:IsShown() then
		self.frame:Hide()
	else
		self:Refresh()
		self.frame:Show()
	end
end
