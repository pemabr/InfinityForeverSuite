local _, host = ...
host.ForeverCoreCopy:Define(function(_, ns)
ns.TrackerLine.template = "CommissionsForever_ForeverCore_ForeverTrackerInteractiveLineTemplate"
end)
local sealed, reason = host.ForeverCoreCopy:Seal()
assert(sealed or reason == "late", reason)
