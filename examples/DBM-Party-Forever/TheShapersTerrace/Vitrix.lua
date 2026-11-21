local mod	= DBM:NewMod("Vitrix", "DBM-Party-Forever", 9)

mod:SetRevision("20261109015934")
mod:EnableGenericTrash()
mod:SetEncounterID(3600)
mod:SetModelID(147098)
mod:SetZone(3001)

mod:RegisterCombat("combat")
