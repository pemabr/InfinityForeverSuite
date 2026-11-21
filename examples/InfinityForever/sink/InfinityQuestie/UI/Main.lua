-- Main UI
-- Quest tracker window

local InfinityQuestieUI = {}

function InfinityQuestieUI:Initialize()
    self.frame = CreateFrame("Frame", "InfinityQuestieMainFrame", UIParent)
    self.frame:SetSize(400, 500)
    self.frame:SetPoint("CENTER", UIParent, "CENTER", -300, 0)
    self.frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    self.frame:SetBackdropColor(0, 0, 0, 0.8)
    self.frame:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
    
    -- Title
    local title = self.frame:CreateFontString(nil, "ARTWORK", "GameFontBold")
    title:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -10)
    title:SetText("Infinity Questie")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() self.frame:Hide() end)
    
    -- Quest list
    self.quest_list = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.quest_list:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    self.quest_list:SetWidth(380)
    self.quest_list:SetJustifyH("LEFT")
    self.quest_list:SetText("No active quests")
    
    self.frame:Hide()
    self.initialized = true
end

function InfinityQuestieUI:Toggle()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:SetShown(not self.frame:IsShown())
end

function InfinityQuestieUI:Show()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:Show()
    self:Update()
end

function InfinityQuestieUI:Update()
    if not self.initialized or not self.frame:IsShown() then
        return
    end
    
    if InfinityQuestTracker then
        local activeQuests = InfinityQuestTracker:GetActiveQuests()
        local text = "Active Quests:\n\n"
        
        local count = 0
        for questID, quest in pairs(activeQuests) do
            text = text .. string.format("• %s\n", quest.name)
            count = count + 1
        end
        
        if count == 0 then
            text = "No active quests"
        end
        
        self.quest_list:SetText(text)
    end
end

return InfinityQuestieUI
