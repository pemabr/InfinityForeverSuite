-- Award Display System
-- Show award codes and color-coded loot awards

local MODULE_NAME = "AwardDisplay"
local InfinityLoot = InfinityLoot or {}
local InfinityCore = InfinityCore or {}

InfinityLoot.AwardDisplay = {
    enabled = false,
    
    -- Award type color codes
    colors = {
        MS = {r = 0, g = 1, b = 0},         -- Green
        OS = {r = 1, g = 1, b = 0},         -- Yellow
        Offspec = {r = 1, g = 0.65, b = 0}, -- Orange
        Bank = {r = 1, g = 0, b = 0}        -- Red
    },
    
    -- Award type names
    award_types = {
        "MS",      -- Main Spec
        "OS",      -- Off Spec
        "Offspec", -- Offspec (generic)
        "Bank"     -- Bank/Guild store
    }
}

local AwardDisplay = InfinityLoot.AwardDisplay

function AwardDisplay:Initialize()
    if self.enabled then return end
    
    self.enabled = true
    
    if InfinityCore.Events then
        InfinityCore.Events:Register("loot_awarded", function(player, item, award_type)
            AwardDisplay:DisplayAwardMessage(player, item, award_type)
        end)
    end
end

function AwardDisplay:GetAwardColor(award_type)
    return self.colors[award_type] or self.colors.Bank
end

function AwardDisplay:GetAwardColorString(award_type)
    local color = self:GetAwardColor(award_type)
    return string.format("|cff%02x%02x%02x",
        color.r * 255,
        color.g * 255,
        color.b * 255
    )
end

function AwardDisplay:DisplayAwardMessage(player, item, award_type)
    if not player or not item then return end
    
    local award_type_str = award_type or "Bank"
    local color_str = self:GetAwardColorString(award_type_str)
    
    local message = string.format(
        "%s awarded %s%s|r to %s",
        player,
        color_str,
        item,
        award_type_str
    )
    
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    end
    
    -- Also fire event for other systems to hear
    if InfinityCore.Events then
        InfinityCore.Events:Fire("award_displayed", player, item, award_type_str, color_str)
    end
end

function AwardDisplay:IsValidAwardType(award_type)
    for _, award in ipairs(self.award_types) do
        if award == award_type then
            return true
        end
    end
    return false
end

function AwardDisplay:GetAwardList()
    return self.award_types
end

function AwardDisplay:PrintAwardInfo()
    print("|cff00ccffAward Types:|r")
    print("")
    
    for _, award_type in ipairs(self.award_types) do
        local color_str = self:GetAwardColorString(award_type)
        print(string.format("  %s%s|r - %s", color_str, award_type, 
            award_type == "MS" and "Main Spec" or
            award_type == "OS" and "Off Spec" or
            award_type == "Offspec" and "Generic Offspec" or
            award_type == "Bank" and "Guild Bank/Storage" or "Unknown"
        ))
    end
    
    print("")
end

-- Create award display window (optional UI)
function AwardDisplay:CreateAwardWindow()
    local frame = CreateFrame("Frame", "InfinityAwardDisplayFrame", UIParent, "BackdropTemplate")
    frame:SetSize(350, 250)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    
    frame:SetBackdropColor(0.1, 0.1, 0.15, 0.9)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    title:SetText("|cff00ccffRecent Awards|r")
    
    -- Scroll frame for award history
    local scroll_frame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll_frame:SetSize(330, 220)
    scroll_frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
    
    -- Edit box for scrolling content
    local edit_box = CreateFrame("EditBox", nil, scroll_frame)
    edit_box:SetSize(310, 2000)
    edit_box:SetMultiLine(true)
    edit_box:SetAutoFocus(false)
    edit_box:SetEnabled(false)
    edit_box:SetFontObject(ChatFontNormal)
    
    scroll_frame:SetScrollChild(edit_box)
    
    frame.edit_box = edit_box
    frame:Hide()
    
    return frame
end

function AwardDisplay:LogAward(player, item, award_type)
    local timestamp = date("%H:%M:%S")
    local color_str = self:GetAwardColorString(award_type)
    
    local log_entry = string.format("[%s] %s - %s%s|r (%s)\n",
        timestamp,
        player or "Unknown",
        color_str,
        item or "Unknown",
        award_type or "Unknown"
    )
    
    return log_entry
end

return InfinityLoot.AwardDisplay
