-- DKP Trading System
-- Allows players to trade DKP with guildmates

local PluribusDKPTrade = {}
_G.PluribusDKPTrade = PluribusDKPTrade

PluribusDKPTrade.tradeRequests = {} -- {player -> {from, amount, timestamp}}
PluribusDKPTrade.tradeHistory = {}
PluribusDKPTrade.maxHistorySize = 1000

function PluribusDKPTrade:Initialize()
	PluribusUtils:Info("DKP Trading system initialized", "DKPTrade")
end

function PluribusDKPTrade:RequestTrade(targetPlayer, amount)
	if not UnitInGuild("player") then
		PluribusUtils:Warning("You must be in a guild to trade DKP", "DKPTrade")
		return false
	end
	
	local playerName = UnitName("player")
	local playerDKP = PluribusLootEPGP:GetPlayerDKP(playerName)
	
	if playerDKP < amount then
		PluribusUtils:Warning("Insufficient DKP. You have " .. playerDKP .. " DKP.", "DKPTrade")
		return false
	end
	
	local msg = "dkp_trade_request:" .. playerName .. ":" .. targetPlayer .. ":" .. amount
	PluribusMessaging:Publish("dkp_trade_request", playerName, targetPlayer, amount)
	
	PluribusUtils:Info("Trade request sent to " .. targetPlayer .. " for " .. amount .. " DKP", "DKPTrade")
	return true
end

function PluribusDKPTrade:ApproveTrade(fromPlayer, amount)
	local playerName = UnitName("player")
	local playerDKP = PluribusLootEPGP:GetPlayerDKP(playerName)
	
	if playerDKP < amount then
		PluribusUtils:Warning("Insufficient DKP to accept this trade", "DKPTrade")
		return false
	end
	
	-- Execute the trade
	PluribusLootEPGP:AwardGP(playerName, amount, "dkp_trade_to:" .. fromPlayer)
	PluribusLootEPGP:AwardGP(fromPlayer, -amount, "dkp_trade_from:" .. playerName)
	
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
	
	PluribusUtils:Info("DKP trade completed: " .. amount .. " DKP from " .. fromPlayer, "DKPTrade")
	PluribusMessaging:Publish("dkp_trade_completed", fromPlayer, playerName, amount)
	return true
end

function PluribusDKPTrade:DenyTrade(fromPlayer, amount)
	PluribusMessaging:Publish("dkp_trade_denied", fromPlayer, UnitName("player"), amount)
	PluribusUtils:Info("DKP trade request denied", "DKPTrade")
end

function PluribusDKPTrade:GetTradeHistory()
	return self.tradeHistory
end

function PluribusDKPTrade:GetTradesByPlayer(playerName)
	local trades = {}
	for _, trade in ipairs(self.tradeHistory) do
		if trade.from == playerName or trade.to == playerName then
			table.insert(trades, trade)
		end
	end
	return trades
end

return PluribusDKPTrade
