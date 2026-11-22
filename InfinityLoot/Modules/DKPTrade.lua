-- DKP Trading System
-- Allows players to trade DKP with guildmates

local InfinityDKPTrade = {}
_G.InfinityDKPTrade = InfinityDKPTrade

InfinityDKPTrade.tradeRequests = {} -- {player -> {from, amount, timestamp}}
InfinityDKPTrade.tradeHistory = {}
InfinityDKPTrade.maxHistorySize = 1000

function InfinityDKPTrade:Initialize()
	InfinityUtils:Info("DKP Trading system initialized", "DKPTrade")
end

function InfinityDKPTrade:RequestTrade(targetPlayer, amount)
	local trading = _G.InfinityDKPPlayerTrading
	if not trading or type(trading.Offer) ~= "function" then
		InfinityUtils:Warning("InfinityDKP guild trading is unavailable.", "DKPTrade")
		return false
	end
	return trading:Offer(targetPlayer, amount)
end

function InfinityDKPTrade:ApproveTrade(fromPlayer, amount)
	InfinityUtils:Warning("Use the InfinityDKP trade controls with the trade ID to accept an offer.", "DKPTrade")
	return false
end

function InfinityDKPTrade:DenyTrade(fromPlayer, amount)
	InfinityUtils:Warning("Use the InfinityDKP trade controls with the trade ID to cancel an offer.", "DKPTrade")
	return false
end

function InfinityDKPTrade:GetTradeHistory()
	return self.tradeHistory
end

function InfinityDKPTrade:GetTradesByPlayer(playerName)
	local trades = {}
	for _, trade in ipairs(self.tradeHistory) do
		if trade.from == playerName or trade.to == playerName then
			table.insert(trades, trade)
		end
	end
	return trades
end

return InfinityDKPTrade
