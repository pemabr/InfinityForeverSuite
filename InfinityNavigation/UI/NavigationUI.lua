-- Navigation UI
local InfinityNavigationUI = {}
_G.InfinityNavigationUI = InfinityNavigationUI

function InfinityNavigationUI:Initialize()
	InfinityUtils:Info("Navigation UI initialized", "Navigation")
end

function InfinityNavigationUI:Toggle()
	InfinityWayPointUI:Toggle()
end

return InfinityNavigationUI
