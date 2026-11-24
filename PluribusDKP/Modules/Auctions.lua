-- Auctions Module
-- Manage loot auctions and distributions

local PluribusDKPAuctions = {}
_G.PluribusDKPAuctions = PluribusDKPAuctions

PluribusDKPAuctions.active_auctions = {}
PluribusDKPAuctions.auction_history = {}
PluribusDKPAuctions.callbacks = {}

function PluribusDKPAuctions:CreateAuction(itemName, itemID, startingBid)
    local auction = {
        id = #self.active_auctions + 1,
        item = itemName,
        itemID = itemID,
        starting_bid = startingBid or 1,
        current_bid = startingBid or 1,
        highest_bidder = nil,
        bids = {},
        start_time = GetTime(),
        end_time = nil,
        duration = 60,
        winner = nil,
        final_price = 0,
    }
    
    table.insert(self.active_auctions, auction)
    self:TriggerCallback("auction_created", itemName, startingBid)
    
    return auction
end

function PluribusDKPAuctions:PlaceBid(auctionID, playerName, bidAmount)
    local auction = self.active_auctions[auctionID]
    if not auction then return false end
    
    bidAmount = tonumber(bidAmount) or 0
    if bidAmount <= auction.current_bid then
        return false
    end
    
    table.insert(auction.bids, {
        player = playerName,
        amount = bidAmount,
        time = GetTime(),
    })
    
    auction.current_bid = bidAmount
    auction.highest_bidder = playerName
    
    self:TriggerCallback("bid_placed", playerName, auction.item, bidAmount)
    return true
end

function PluribusDKPAuctions:CompleteAuction(auctionID)
    local auction = self.active_auctions[auctionID]
    if not auction then return false end
    
    auction.end_time = GetTime()
    auction.winner = auction.highest_bidder
    auction.final_price = auction.current_bid
    
    table.insert(self.auction_history, auction)
    table.remove(self.active_auctions, auctionID)
    
    if auction.winner then
        self:TriggerCallback("auction_won", auction.winner, auction.item, auction.final_price)
    end
    
    return true
end

function PluribusDKPAuctions:GetActiveAuctions()
    return self.active_auctions
end

function PluribusDKPAuctions:GetAuctionHistory()
    return self.auction_history
end

function PluribusDKPAuctions:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function PluribusDKPAuctions:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

return PluribusDKPAuctions
