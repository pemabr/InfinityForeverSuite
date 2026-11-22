InfinityGearUI = {}

local slots = {
	"Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet",
	"Wrist", "Hands", "Finger 1", "Finger 2", "Trinket 1", "Trinket 2",
	"Back", "Main hand", "Off hand", "Ranged", "Tabard",
}

function InfinityGearUI:Initialize()
	if self.eventFrame then return end
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	events:RegisterEvent("EQUIPMENT_SETS_CHANGED")
	events:SetScript("OnEvent", function()
		if InfinityGearUI.frame and InfinityGearUI.frame:IsShown() then
			InfinityGearUI:Refresh()
		end
	end)
	self.eventFrame = events
end

function InfinityGearUI:Refresh()
	if not self.frame then return end
	local items = {}
	if not GetInventoryItemLink then
		self.frame.status:SetText("Equipment API unavailable.")
		self.frame:SetItems(items)
		return
	end
	for slot, name in ipairs(slots) do
		local link = GetInventoryItemLink("player", slot)
		local hidden = _G.issecretvalue and _G.issecretvalue(link)
		if hidden then link = nil end
		items[#items + 1] = {
			text = name .. ": " .. (hidden and "(unavailable)" or (link or "(empty)")),
			link = link,
		}
	end
	local sets = _G.C_EquipmentSet
	if sets and sets.GetEquipmentSetIDs and sets.GetEquipmentSetInfo and sets.UseEquipmentSet then
		local ids = sets.GetEquipmentSetIDs()
		if _G.issecretvalue and _G.issecretvalue(ids) then ids = nil end
		local incomplete = false
		for _, id in ipairs(type(ids) == "table" and ids or {}) do
			local setID = id
			if _G.issecretvalue and _G.issecretvalue(setID) then setID = nil end
			local valid = type(setID) == "number" and setID == setID and setID >= 0
				and setID < math.huge and setID == math.floor(setID)
			local setName = valid and sets.GetEquipmentSetInfo(setID)
			if _G.issecretvalue and _G.issecretvalue(setName) then setName = nil end
			if type(setName) == "string" then
				items[#items + 1] = {
					text = "Equip set: " .. setName,
					onClick = function()
						if InCombatLockdown and InCombatLockdown() then
							InfinityUtils:Warning("Cannot equip a set during combat.", "Gear")
							return
						end
						sets.UseEquipmentSet(setID)
					end,
				}
			else incomplete = true end
		end
		self.frame.status:SetText(type(ids) == "table" and ("Hover an item; click a saved equipment set to equip."
			.. (incomplete and " Some sets are unavailable." or ""))
			or "Equipment sets unavailable on this client.")
	else
		self.frame.status:SetText("Equipment sets unavailable on this client.")
	end
	self.frame:SetItems(items)
end

function InfinityGearUI:Toggle()
	if not self.frame then
		self.frame = InfinityUIFramework:CreateListWindow("InfinityGearWindow", "Equipment", 600, 500)
	end
	if self.frame:IsShown() then
		self.frame:Hide()
	else
		self:Refresh()
		self.frame:Show()
	end
end
