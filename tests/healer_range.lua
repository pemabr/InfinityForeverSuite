local secret, output = {}, {}
issecretvalue = function(value) return value == secret end
GetTime = function() return 100 end
SlashCmdList = {}
local units = {
	player = { name = "Player", range = 0, checked = true },
	party1 = { name = "Near", range = 900, checked = true },
	party2 = { name = "Far", range = 2500, checked = true },
	party3 = { name = "Unknown", range = secret, checked = true },
	party4 = { name = "Restricted", range = 100, checked = secret },
}
UnitExists = function(unit) return units[unit] ~= nil end
UnitName = function(unit) return units[unit].name end
UnitDistanceSquared = function(unit) return units[unit].range, units[unit].checked end
GetNumGroupMembers = function() return 5 end
IsInRaid = function() return false end
local engine = dofile("InfinityHealer\\Modules\\LineOfSightEngine.lua")
assert(engine:IsInLineOfSight("party1") == nil and engine:CanCastSpellOn("Heal", "party1") == nil)
assert(engine:CheckLineOfSight("player", "party1") == nil and engine:GetBlockedMembers() == nil)
assert(engine:GetLosStatus("party1").in_range == true)
assert(engine:GetLosStatus("party2").in_range == false)
assert(engine:GetLosStatus("party3").in_range == nil)
assert(engine:GetLosStatus("party4").in_range == nil)
local report = engine:GetLosReport()
assert(report.total_members == 5 and report.in_range == 2 and report.out_of_range == 1 and report.unknown_range == 2)
IsInRaid = function() return nil end
assert(engine:GetLosReport().total_members == 5)
local originalPrint = print
print = function(message) output[#output + 1] = tostring(message) end
SlashCmdList.LOSCHECK("check party1")
assert(output[#output - 1]:find("unavailable", 1, true))
assert(output[#output]:find("yes", 1, true))
SlashCmdList.LOSCHECK("check party4")
assert(output[#output]:find("unknown", 1, true))
SlashCmdList.LOSCHECK("blocked")
assert(output[#output]:find("cannot be determined", 1, true))
SlashCmdList.LOSCHECK("report")
assert(output[#output - 1]:find("2", 1, true))
GetNumGroupMembers = function() return secret end
SlashCmdList.LOSCHECK("report")
assert(output[#output]:find("unavailable", 1, true))
print = originalPrint
print("healer_range: all tests passed")
