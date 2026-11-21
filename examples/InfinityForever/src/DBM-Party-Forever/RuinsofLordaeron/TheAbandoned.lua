local mod	= DBM:NewMod("TheAbandoned", "DBM-Party-Forever", 2)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261107034458")
mod:EnableGenericTrash()
--mod:SetCreatureID(11517)
mod:SetEncounterID(3357)
mod:SetModelID(138667)
mod:SetZone(2999)

mod:RegisterCombat("combat")

--mod:AddAuraSoundOption(123456, true, 123456, 1, 1, "targetyou", 2, 0)
