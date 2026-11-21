-- Bid Popup Notifications
-- Notify players when they are outbid

local MODULE_NAME = "BidPopup"
local InfinityLoot = InfinityLoot or {}
local InfinityCore = InfinityCore or {}

InfinityLoot.BidPopup = {
    enabled = false,
    
    popup_queue = {},
    showing_popup = false,
    popup_frame = nil
}

local BidPopup = InfinityLoot.BidPopup

function BidPopup:Initialize()
    if self.enabled then return end
    
    self:CreatePopupFrame()
    self.enabled = true
    
    -- Register for outbid events
    if InfinityCore.Events then
        InfinityCore.Events:Register("player_outbid", function(player, item, old_bid, new_bid)
            BidPopup:OnPlayerOutbid(player, item, old_bid, new_bid)
        end)
    end
end

function BidPopup:CreatePopupFrame()
    if self.popup_frame then return end
    
    local frame = CreateFrame("Frame", "InfinityBidPopupFrame", UIParent, "BackdropTemplate")
    frame:SetSize(300, 100)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
    
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    frame:SetBackdropBorderColor(1, 0, 0, 1)
    
    -- Title text
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    title:SetText("|cffff0000You have been outbid!|r")
    frame.title = title
    
    -- Message text
    local message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    message:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    message:SetJustifyH("LEFT")
    message:SetWidth(280)
    message:SetWordWrap(true)
    frame.message = message
    
    -- Dismiss button
    local button = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    button:SetSize(80, 25)
    button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    button:SetText("Dismiss")
    
    button:SetScript("OnClick", function()
        BidPopup:DismissPopup()
    end)
    
    frame:Hide()
    
    self.popup_frame = frame
end

function BidPopup:OnPlayerOutbid(player, item, old_bid, new_bid)
    if not player or not item then return end
    
    local message = string.format(
        "%s outbid you on %s\nYour bid: %d | Their bid: %d",
        player or "Someone",
        item or "Unknown",
        old_bid or 0,
        new_bid or 0
    )
    
    table.insert(self.popup_queue, {
        message = message,
        time = GetTime()
    })
    
    if not self.showing_popup then
        self:ShowNextPopup()
    end
end

function BidPopup:ShowNextPopup()
    if #self.popup_queue == 0 then
        self.showing_popup = false
        return
    end
    
    self.showing_popup = true
    local popup_data = table.remove(self.popup_queue, 1)
    
    if self.popup_frame then
        self.popup_frame.message:SetText(popup_data.message)
        self.popup_frame:Show()
        
        -- Auto-dismiss after 5 seconds
        self:ScheduleDismiss(5)
    end
end

function BidPopup:ScheduleDismiss(delay)
    if self.dismiss_timer then
        self:CancelTimer(self.dismiss_timer)
    end
    
    self.dismiss_timer = C_Timer.After(delay or 5, function()
        BidPopup:DismissPopup()
    end)
end

function BidPopup:DismissPopup()
    if self.popup_frame then
        self.popup_frame:Hide()
    end
    
    if self.dismiss_timer then
        self:CancelTimer(self.dismiss_timer)
        self.dismiss_timer = nil
    end
    
    if #self.popup_queue > 0 then
        self:ShowNextPopup()
    else
        self.showing_popup = false
    end
end

function BidPopup:CancelTimer(timer)
    if timer then
        C_Timer.After(0, function() end)  -- Cancel timer
    end
end

return InfinityLoot.BidPopup
