-- Live Bid Bars
-- Visual representation of current bids during auctions

local MODULE_NAME = "LiveBidBars"
local InfinityLoot = InfinityLoot or {}
local InfinityCore = InfinityCore or {}

InfinityLoot.LiveBidBars = {
    enabled = false,
    visible = false,
    frames = {},
    active_auctions = {},
    
    config = {
        x = 100,
        y = 400,
        width = 400,
        height = 25,
        bar_height = 20,
        show_names = true,
        show_amounts = true,
        update_rate = 0.5,
        color_winning = { r = 0.1, g = 1, b = 0.1 },   -- Green
        color_losing = { r = 1, g = 0.1, b = 0.1 },    -- Red
        color_neutral = { r = 1, g = 1, b = 0.1 }      -- Yellow
    }
}

local BidBars = InfinityLoot.LiveBidBars

function BidBars:Initialize()
    if InfinityCore.Events then
        InfinityCore.Events:Subscribe("AUCTION_STARTED", function(item_id, item_name)
            BidBars:AddAuction(item_id, item_name)
        end)
        
        InfinityCore.Events:Subscribe("AUCTION_BID_PLACED", function(item_id, bidder, amount)
            BidBars:UpdateAuctionBid(item_id, bidder, amount)
        end)
        
        InfinityCore.Events:Subscribe("AUCTION_ENDED", function(item_id)
            BidBars:RemoveAuction(item_id)
        end)
    end
end

function BidBars:CreateFrame()
    local frame = CreateFrame("Frame", "InfinityLiveBidBarsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(self.config.width, 300)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", self.config.x, -self.config.y)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Title bar
    local titlebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titlebar:SetSize(self.config.width, 25)
    titlebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    titlebar:SetBackdropColor(0.2, 0.2, 0.2, 1)
    
    local title = titlebar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titlebar, "LEFT", 8, 0)
    title:SetText("Live Bids")
    
    -- Close button
    local close_btn = CreateFrame("Button", nil, titlebar, "UIPanelCloseButton")
    close_btn:SetPoint("RIGHT", titlebar, "RIGHT", -2, 0)
    close_btn:SetScript("OnClick", function()
        BidBars:Hide()
    end)
    
    -- Make draggable
    titlebar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            frame:StartMoving()
        end
    end)
    titlebar:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        BidBars.config.x = frame:GetLeft()
        BidBars.config.y = -frame:GetTop()
    end)
    
    -- Scroll frame for auctions
    local scroll = CreateFrame("ScrollFrame", "InfinityBidBarsScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetSize(self.config.width - 25, 300 - 40)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -30)
    
    local content = CreateFrame("Frame", nil, scroll, BackdropTemplateMixin and "BackdropTemplate" or nil)
    content:SetSize(self.config.width - 40, 10)
    scroll:SetScrollChild(content)
    
    frame.scroll = scroll
    frame.content = content
    
    self.frames.main = frame
end

function BidBars:AddAuction(item_id, item_name)
    if not self.active_auctions[item_id] then
        self.active_auctions[item_id] = {
            item_id = item_id,
            item_name = item_name or "Unknown",
            current_bid = 0,
            current_bidder = "Nobody",
            opening_bid = 0,
            highest_bid = 0,
            bid_count = 0,
            start_time = GetTime(),
            frame = nil
        }
    end
    
    self:RefreshDisplay()
end

function BidBars:UpdateAuctionBid(item_id, bidder, amount)
    if not self.active_auctions[item_id] then
        return
    end
    
    local auction = self.active_auctions[item_id]
    auction.current_bidder = bidder
    auction.current_bid = amount
    auction.bid_count = auction.bid_count + 1
    
    if amount > auction.highest_bid then
        auction.highest_bid = amount
    end
    
    if auction.opening_bid == 0 then
        auction.opening_bid = amount
    end
    
    self:RefreshDisplay()
end

function BidBars:RemoveAuction(item_id)
    if self.active_auctions[item_id] then
        self.active_auctions[item_id] = nil
    end
    
    self:RefreshDisplay()
end

function BidBars:RefreshDisplay()
    if not self.frames.main or not self.visible then
        return
    end
    
    local content = self.frames.main.content
    local auction_count = 0
    
    -- Clear existing
    for i = #content, 1, -1 do
        if content[i] and content[i]:IsObjectType("Frame") then
            content[i]:Hide()
        end
    end
    
    local y_offset = 0
    
    for item_id, auction in pairs(self.active_auctions) do
        auction_count = auction_count + 1
        
        local auction_frame = content[auction_count]
        if not auction_frame then
            auction_frame = CreateFrame("Frame", nil, content, BackdropTemplateMixin and "BackdropTemplate" or nil)
            auction_frame:SetSize(content:GetWidth(), self.config.bar_height + 15)
            content[auction_count] = auction_frame
        end
        
        auction_frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y_offset)
        auction_frame:Show()
        
        -- Item name
        local item_name = auction_frame:CreateFontString(nil, "OVERLAY", "GameFontSmall")
        item_name:SetWidth(200)
        item_name:SetText(auction.item_name)
        item_name:SetPoint("TOPLEFT", auction_frame, "TOPLEFT", 2, 0)
        item_name:SetTextColor(1, 1, 1, 1)
        
        -- Current bid
        local bid_text = auction_frame:CreateFontString(nil, "OVERLAY", "GameFontSmall")
        bid_text:SetWidth(80)
        bid_text:SetText(tostring(auction.current_bid) .. " DKP")
        bid_text:SetPoint("TOPRIGHT", auction_frame, "TOPRIGHT", -2, 0)
        bid_text:SetTextColor(1, 1, 0, 1)
        
        -- Bid bar background
        local bar_bg = CreateFrame("Frame", nil, auction_frame, "BackdropTemplate")
        bar_bg:SetSize(auction_frame:GetWidth() - 4, self.config.bar_height)
        bar_bg:SetPoint("TOPLEFT", auction_frame, "TOPLEFT", 2, -15)
        bar_bg:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
        bar_bg:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
        
        -- Bid bar fill (scales with bid amount vs opening bid)
        local fill_percent = 0
        if auction.highest_bid > 0 then
            fill_percent = math.min(1, auction.current_bid / (auction.highest_bid * 1.1))
        end
        
        local bar_fill = CreateFrame("Frame", nil, bar_bg, "BackdropTemplate")
        bar_fill:SetSize((bar_bg:GetWidth() - 4) * fill_percent, self.config.bar_height - 2)
        bar_fill:SetPoint("TOPLEFT", bar_bg, "TOPLEFT", 2, -1)
        
        -- Determine bar color based on player's bid
        local my_name = UnitName("player")
        local bar_color = self.config.color_neutral
        
        if auction.current_bidder == my_name then
            bar_color = self.config.color_winning
        else
            bar_color = self.config.color_losing
        end
        
        bar_fill:SetBackdropColor(bar_color.r, bar_color.g, bar_color.b, 0.9)
        bar_fill:SetBackdropBorderColor(bar_color.r * 1.5, bar_color.g * 1.5, bar_color.b * 1.5, 1)
        
        -- Bidder name
        local bidder_text = bar_bg:CreateFontString(nil, "OVERLAY", "GameFontSmall")
        bidder_text:SetWidth(150)
        bidder_text:SetText(auction.current_bidder)
        bidder_text:SetPoint("LEFT", bar_bg, "LEFT", 4, 0)
        bidder_text:SetTextColor(1, 1, 1, 0.8)
        
        -- Bid count
        local bid_count = bar_bg:CreateFontString(nil, "OVERLAY", "GameFontSmall")
        bid_count:SetWidth(50)
        bid_count:SetText("(" .. tostring(auction.bid_count) .. ")")
        bid_count:SetPoint("RIGHT", bar_bg, "RIGHT", -4, 0)
        bid_count:SetTextColor(0.7, 0.7, 0.7, 1)
        
        y_offset = y_offset + self.config.bar_height + 20
    end
    
    -- Update scroll child height
    content:SetHeight(math.max(auction_count * (self.config.bar_height + 20), 10))
end

function BidBars:Toggle()
    if self.visible then
        self:Hide()
    else
        self:Show()
    end
end

function BidBars:Show()
    if not self.frames.main then
        self:CreateFrame()
    end
    
    self.visible = true
    self.frames.main:Show()
    self:RefreshDisplay()
end

function BidBars:Hide()
    if self.frames.main then
        self.frames.main:Hide()
    end
    self.visible = false
end

-- Register slash command
if InfinityCore.SlashCommand then
    InfinityCore.SlashCommand:Register("bidbars", function(args)
        if args == "toggle" then
            BidBars:Toggle()
        elseif args == "show" then
            BidBars:Show()
        elseif args == "hide" then
            BidBars:Hide()
        else
            BidBars:Toggle()
        end
    end, "Toggle live bid bars display")
end

return InfinityLoot.LiveBidBars
