-- Main UI
-- Gathering route manager

local InfinityGatherPathUI = {}
_G.InfinityGatherPathUI = InfinityGatherPathUI

local function Public(value)
    if _G.issecretvalue and _G.issecretvalue(value) then return nil end
    return value
end

local function CurrentZone()
    local zone = _G.GetRealZoneText and Public(GetRealZoneText())
    if type(zone) ~= "string" or zone == "" then
        InfinityUtils:Warning("Current zone unavailable.", "GatherPath")
        return nil
    end
    return zone
end

function InfinityGatherPathUI:Initialize()
    if self.initialized then return end
    self.frame = CreateFrame("Frame", "InfinityGatherPathMainFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.frame:SetSize(500, 400)
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 300, -100)
    self.frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    self.frame:SetBackdropColor(0, 0, 0, 0.8)
    self.frame:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
    
    -- Title
    local title = self.frame:CreateFontString(nil, "ARTWORK", (GameFontBold and "GameFontBold" or "GameFontNormalLarge"))
    title:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -10)
    title:SetText("Infinity GatherPath")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() self.frame:Hide() end)

    local record = InfinityUIFramework:CreateButton(self.frame, "Record herb", 115, 22, function()
        self:RecordCurrentNode()
    end)
    record:SetPoint("TOPLEFT", 10, -38)
    local optimize = InfinityUIFramework:CreateButton(self.frame, "Optimize zone", 115, 22, function()
        self:OptimizeCurrentZone()
    end)
    optimize:SetPoint("LEFT", record, "RIGHT", 8, 0)
    local nodes = InfinityUIFramework:CreateButton(self.frame, "Node count", 105, 22, function()
        self.routes_text:SetText("Recorded nodes this session: " .. InfinityNodeDB:GetNodeCount())
    end)
    nodes:SetPoint("LEFT", optimize, "RIGHT", 8, 0)
    
    -- Routes display
    self.routes_text = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.routes_text:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -72)
    self.routes_text:SetWidth(480)
    self.routes_text:SetJustifyH("LEFT")
    self.routes_text:SetText("No routes recorded")
    
    self.frame:Hide()
    self.initialized = true
end

function InfinityGatherPathUI:RecordCurrentNode()
    local zone = CurrentZone()
    if not zone then return false end
    local map = _G.C_Map
    if not map or type(map.GetBestMapForUnit) ~= "function" or type(map.GetPlayerMapPosition) ~= "function" then
        InfinityUtils:Warning("Player map position API unavailable.", "GatherPath")
        return false
    end
    local mapID = Public(map.GetBestMapForUnit("player"))
    if not InfinityUtils:IsValidWaypoint(mapID, 0, 0) then
        InfinityUtils:Warning("Player map unavailable.", "GatherPath")
        return false
    end
    local position = Public(map.GetPlayerMapPosition(mapID, "player"))
    if type(position) ~= "table" and type(position) ~= "userdata" then
        InfinityUtils:Warning("Player position unavailable or protected.", "GatherPath")
        return false
    end
    local x, y = Public(position.x), Public(position.y)
    if (x == nil or y == nil) and type(position.GetXY) == "function" then
        x, y = position:GetXY()
        x, y = Public(x), Public(y)
    end
    if not InfinityUtils:IsValidWaypoint(mapID, x, y) or (x == 0 and y == 0) then
        InfinityUtils:Warning("Player position unavailable or protected.", "GatherPath")
        return false
    end
    local added = InfinityNodeDB:RecordNode("herb", x * 100, y * 100, zone, 300)
    self:Initialize()
    self.routes_text:SetText((added and "Herb position recorded" or "Herb position already recorded")
        .. " in " .. zone .. ". Session only.")
    return added
end

function InfinityGatherPathUI:OptimizeCurrentZone()
    local zone = CurrentZone()
    if not zone then return false end
    local nodes = InfinityNodeDB:GetNodesByZone(zone)
    if #nodes == 0 then InfinityUtils:Warning("No nodes recorded in this zone.", "GatherPath"); return false end
    table.sort(nodes, function(a, b)
        if a.x ~= b.x then return a.x < b.x end
        return a.y < b.y
    end)
    local optimized = InfinityOptimization:OptimizeRoute(nodes)
    local items = {}
    for i, node in ipairs(optimized) do
        items[#items + 1] = { text = string.format("%d. %s (%.1f, %.1f)", i, node.type, node.x, node.y) }
    end
    if not self.routeFrame then
        self.routeFrame = InfinityUIFramework:CreateListWindow("InfinityGatherPathOptimizedFrame", "Optimized Zone Nodes", 600, 450)
    end
    self.routeFrame:SetItems(items)
    self.routeFrame.status:SetText(zone .. ": nearest-neighbor order; map-coordinate distance "
        .. string.format("%.1f", InfinityOptimization:CalculateTotalDistance(optimized)) .. ". Session only.")
    self.routeFrame:Show()
    return true
end

function InfinityGatherPathUI:Toggle()
    if not self.initialized then
        self:Initialize()
    end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:Show()
    end
end

function InfinityGatherPathUI:Show()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:Show()
    self:Update()
end

function InfinityGatherPathUI:Update()
    if not self.initialized or not self.frame:IsShown() then
        return
    end
    
    if InfinityRoutes then
        local routes = InfinityRoutes:GetRoutes()
        local text = "Available Routes:\n\n"
        
        local count = 0
        for routeID, route in pairs(routes) do
            text = text .. string.format("• %s (%d nodes in %s)\n",
                route.name, #route.nodes, route.zone)
            count = count + 1
        end
        
        if count == 0 then
            text = "No routes recorded"
        end
        
        self.routes_text:SetText(text)
    end
end

return InfinityGatherPathUI
