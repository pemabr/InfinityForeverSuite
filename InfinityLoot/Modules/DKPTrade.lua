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
	if not UnitInGuild("player") then
		InfinityUtils:Warning("You must be in a guild to trade DKP", "DKPTrade")
		return false
	end
	
	local playerName = UnitName("player")
	local playerDKP = InfinityLootEPGP:GetPlayerDKP(playerName)
	
	if playerDKP < amount then
		InfinityUtils:Warning("Insufficient DKP. You have " .. playerDKP .. " DKP.", "DKPTrade")
		return false
	end
	
	local msg = "dkp_trade_request:" .. playerName .. ":" .. targetPlayer .. ":" .. amount
	InfinityMessaging:Publish("dkp_trade_request", playerName, targetPlayer, amount)
	
	InfinityUtils:Info("Trade request sent to " .. targetPlayer .. " for " .. amount .. " DKP", "DKPTrade")
	return true
end

function InfinityDKPTrade:ApproveTrade(fromPlayer, amount)
	local playerName = UnitName("player")
	local playerDKP = InfinityLootEPGP:GetPlayerDKP(playerName)
	
	if playerDKP < amount then
		InfinityUtils:Warning("Insufficient DKP to accept this trade", "DKPTrade")
		return false
	end
	
	-- Execute the trade
	InfinityLootEPGP:AwardGP(playerName, amount, "dkp_trade_to:" .. fromPlayer)
	InfinityLootEPGP:AwardGP(fromPlayer, -amount, "dkp_trade_from:" .. playerName)
	
	-- Log trade
	table.insert(self.tradeHistory, {
		from = fromPlayer,
		to = playerName,
		amount = amount,
		timestamp = GetTime(),
	})
	
	if #self.tradeHistory > self.maxHistorySize then
		table.remove(self.tradeHistory, 1)
	end
	
	InfinityUtils:Info("DKP trade completed: " .. amount .. " DKP from " .. fromPlayer, "DKPTrade")
	InfinityMessaging:Publish("dkp_trade_completed", fromPlayer, playerName, amount)
	return true
end

function InfinityDKPTrade:DenyTrade(fromPlayer, amount)
	InfinityMessaging:Publish("dkp_trade_denied", fromPlayer, UnitName("player"), amount)
	InfinityUtils:Info("DKP trade request denied", "DKPTrade")
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
