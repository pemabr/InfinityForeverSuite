local Trading = {
	prefix = "InfinityDKPT1",
	offers = {},
	noticeSeen = {},
	noticeOrder = {},
	sequence = 0,
	lifetime = 300,
	maxOffers = 100,
}
_G.InfinityDKPPlayerTrading = Trading

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Sync() return _G.InfinityDKPGuildSync end
local function FullName(name) return Sync():GetFullName(name) end
local function Guild() return Sync():GetGuildKey() end
local function Me()
	return _G.UnitName and FullName(Public(_G.UnitName("player")))
end
local function SafeName(name)
	return type(name) == "string" and name ~= "" and #name <= 80 and not name:find("[%z\1-\32~|]")
end
local function ValidToken(token)
	return type(token) == "string" and #token <= 32 and token:match("^%d+%-%d+$") ~= nil
end
local function ValidAmount(amount)
	if _G.issecretvalue and _G.issecretvalue(amount) then return false end
	return type(amount) == "number" and amount == amount and amount > 0
		and amount <= 1000000000 and amount == math.floor(amount)
end
local function OfferKey(guild, from, token) return guild .. "|" .. from .. "|" .. token end

function Trading:Initialize(db)
	if self.initialized then return end
	if type(db) ~= "table" then error("DKP trade database unavailable") end
	if db.dkpTrades == nil then db.dkpTrades = {} end
	if type(db.dkpTrades) ~= "table" then error("Invalid saved DKP trade history") end
	self.db, self.initialized = db, true
	local chat = _G.C_ChatInfo
	if not (chat and chat.RegisterAddonMessagePrefix and chat.SendAddonMessage) then
		InfinityUtils:Warning("DKP trade messages unavailable.", "DKP Trade")
		return
	end
	local ok, result = pcall(chat.RegisterAddonMessagePrefix, self.prefix)
	local protected = _G.issecretvalue and _G.issecretvalue(result)
	result = Public(result)
	local duplicate = _G.Enum and _G.Enum.RegisterAddonMessagePrefixResult
		and _G.Enum.RegisterAddonMessagePrefixResult.DuplicatePrefix or 1
	if not ok or protected or (result ~= nil and result ~= true and result ~= 0 and result ~= duplicate) then
		InfinityUtils:Warning("Could not register DKP trade messages: " .. (protected and "protected result" or tostring(result)), "DKP Trade")
		return
	end
	self.available = true
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("CHAT_MSG_ADDON")
	frame:SetScript("OnEvent", function(_, _, ...) self:OnMessage(...) end)
	self.frame = frame
end

function Trading:Send(message)
	if not self.available or not Guild() then
		InfinityUtils:Warning("DKP trade messaging or guild unavailable.", "DKP Trade")
		return false
	end
	local ok, result = pcall(_G.C_ChatInfo.SendAddonMessage, self.prefix, message, "GUILD")
	local protected = _G.issecretvalue and _G.issecretvalue(result)
	result = Public(result)
	if not ok or protected or (result ~= nil and result ~= true and result ~= 0) then
		InfinityUtils:Warning("DKP trade message failed: " .. (protected and "protected result" or tostring(result)), "DKP Trade")
		return false
	end
	return true
end

function Trading:Prune()
	local now = GetTime()
	for key, offer in pairs(self.offers) do
		if offer.guild ~= Guild() or now >= offer.expiresAt then self.offers[key] = nil end
	end
end

function Trading:ObserveFinalization(key)
	if self.noticeSeen[key] then return end
	self.noticeSeen[key] = true
	self.noticeOrder[#self.noticeOrder + 1] = key
	if #self.noticeOrder > 500 then self.noticeSeen[table.remove(self.noticeOrder, 1)] = nil end
	Sync():MarkSnapshotsStale()
end

function Trading:Find(from, token)
	self:Prune()
	local guild, name = Guild(), FullName(from)
	if not guild or not name or not ValidToken(token) then return nil end
	return self.offers[OfferKey(guild, name, token)]
end

function Trading:Offer(recipient, amount)
	local guild, me = Guild(), Me()
	recipient = FullName(recipient)
	if not guild or not SafeName(me) then
		InfinityUtils:Warning("Player or guild identity unavailable.", "DKP Trade")
		return false
	end
	if not SafeName(recipient) or not ValidAmount(amount) then
		print("Usage: /dkp trade offer <guild player> <positive integer DKP>")
		return false
	end
	if me == recipient or not Sync():IsGuildMember(me) or not Sync():IsGuildMember(recipient) then
		InfinityUtils:Warning("Both distinct players must be in the current guild roster.", "DKP Trade")
		return false
	end
	self:Prune()
	local count = 0
	for _ in pairs(self.offers) do count = count + 1 end
	if count >= self.maxOffers then
		InfinityUtils:Warning("Too many pending trades; wait for expiration.", "DKP Trade")
		return false
	end
	local token
	repeat
		self.sequence = self.sequence + 1
		token = tostring(time()) .. "-" .. self.sequence
	until not self.db.dkpTrades[OfferKey(guild, me, token)] and not self.offers[OfferKey(guild, me, token)]
	local message = string.format("O~%s~%s~%d", token, recipient, amount)
	if not self:Send(message) then return false end
	self:OnMessage(self.prefix, message, "GUILD", me)
	print("Offer sent; recipient and guild master must be online. ID: " .. token)
	return true, token
end

function Trading:Accept(from, token)
	local offer = self:Find(from, token)
	if not offer or offer.recipient ~= Me() or (offer.status ~= "pending" and offer.status ~= "accepted") then
		InfinityUtils:Warning("No matching active offer for this recipient.", "DKP Trade")
		return false
	end
	local message = string.format("A~%s~%s~%d", token, offer.from, offer.amount)
	if not self:Send(message) then return false end
	self:OnMessage(self.prefix, message, "GUILD", Me())
	print("Acceptance sent; the guild master must finalize the trade.")
	return true
end

function Trading:Cancel(from, token)
	local offer = self:Find(from, token)
	local me = Me()
	if not offer or (me ~= offer.from and me ~= offer.recipient)
		or (offer.status ~= "pending" and offer.status ~= "accepted") then
		InfinityUtils:Warning("No active trade available to cancel.", "DKP Trade")
		return false
	end
	local message = string.format("C~%s~%s~%d", token, offer.from, offer.amount)
	if not self:Send(message) then return false end
	self:OnMessage(self.prefix, message, "GUILD", me)
	return true
end

function Trading:Resend(token)
	local offer = self:Find(Me(), token)
	if not offer or (offer.status ~= "pending" and offer.status ~= "accepted") then
		InfinityUtils:Warning("No active offer available to resend.", "DKP Trade")
		return false
	end
	if not self:Send(string.format("O~%s~%s~%d", token, offer.recipient, offer.amount)) then return false end
	print("Offer resent. The recipient can resend acceptance with /dkp trade accept.")
	return true
end

local function PlayerKey(fullName)
	local found
	for name in pairs(InfinityDKPEngine.players) do
		if FullName(name) == fullName then
			if found then return nil end
			found = name
		end
	end
	return found
end

function Trading:Finalize(from, token)
	local offer = self:Find(from, token)
	if not Sync():IsLocalGuildMaster() then
		InfinityUtils:Warning("Only the guild master can finalize trades.", "DKP Trade")
		return false
	end
	if Sync().outgoing then
		InfinityUtils:Warning("Wait for the current DKP snapshot to finish before finalizing.", "DKP Trade")
		return false
	end
	if not offer or offer.status ~= "accepted" or offer.guild ~= Guild()
		or not Sync():IsGuildMember(offer.from) or not Sync():IsGuildMember(offer.recipient) then
		InfinityUtils:Warning("Trade missing, expired, unaccepted, or no longer in this guild.", "DKP Trade")
		return false
	end
	local engine, key = InfinityDKPEngine, OfferKey(offer.guild, offer.from, offer.token)
	if engine.system_type ~= engine.SYSTEM_DKP or self.db.dkpTrades[key] then
		InfinityUtils:Warning("Trade requires DKP mode and must not already be finalized.", "DKP Trade")
		return false
	end
	local fromKey, toKey = PlayerKey(offer.from), PlayerKey(offer.recipient)
	if not fromKey or not toKey or not engine:TransferDKP(fromKey, toKey, offer.amount) then
		InfinityUtils:Warning("Transfer failed: players, balance, or DKP limit invalid.", "DKP Trade")
		return false
	end
	self.db.dkpTrades[key] = {
		from = offer.from, recipient = offer.recipient, amount = offer.amount,
		token = offer.token, guild = offer.guild, time = time(), approvedBy = Me(),
	}
	offer.status = "completed"
	self:ObserveFinalization(key)
	InfinityDKPPoints:LogTransaction(fromKey, "dkp", -offer.amount, "Trade to " .. toKey .. " (" .. token .. ")")
	InfinityDKPPoints:LogTransaction(toKey, "dkp", offer.amount, "Trade from " .. fromKey .. " (" .. token .. ")")
	engine:TriggerCallback("dkp_transferred", fromKey, toKey, offer.amount)
	if _G.InfinityDKPUI then _G.InfinityDKPUI:Update() end
	print("Trade finalized locally. Send /dkp sync send; members must apply the snapshot.")
	if not self:Send(string.format("F~%s~%s~%d", token, offer.from, offer.amount)) then
		InfinityUtils:Warning("Transfer succeeded locally but the trade notification failed.", "DKP Trade")
	end
	return true
end

function Trading:OnMessage(prefix, message, channel, sender)
	prefix, message, channel, sender = Public(prefix), Public(message), Public(channel), Public(sender)
	if prefix ~= self.prefix or channel ~= "GUILD" or type(message) ~= "string" or #message > 240 then return end
	local guild, me, senderName = Guild(), Me(), FullName(sender)
	if not guild or not me or not SafeName(senderName) or not Sync():IsGuildMember(senderName) then return end
	self:Prune()
	local token, recipient, rawAmount = message:match("^O~([^~]+)~([^~]+)~(%d+)$")
	if token then
		recipient = FullName(recipient)
		local amount = tonumber(rawAmount)
		if not ValidToken(token) or not SafeName(recipient) or senderName == recipient
			or not ValidAmount(amount) or not Sync():IsGuildMember(recipient)
			or (me ~= recipient and me ~= senderName and not Sync():IsLocalGuildMaster()) then return end
		local key = OfferKey(guild, senderName, token)
		if self.db.dkpTrades[key] then return end
		local old = self.offers[key]
		if old then return end
		local count = 0
		for _ in pairs(self.offers) do count = count + 1 end
		if count >= self.maxOffers then
			InfinityUtils:Warning("Too many pending DKP trades.", "DKP Trade")
			return
		end
		self.offers[key] = { guild = guild, from = senderName, recipient = recipient, token = token,
			amount = amount, status = "pending", expiresAt = GetTime() + self.lifetime }
		if me == recipient then
			print(string.format("DKP offer: %s -> you, %d DKP. /dkp trade accept %s %s", senderName, amount, senderName, token))
		elseif me ~= senderName then
			print(string.format("DKP offer: %s -> %s, %d DKP; awaiting recipient acceptance.", senderName, recipient, amount))
		end
		return
	end
	local action, from, amount
	action, token, from, amount = message:match("^([ACF])~([^~]+)~([^~]+)~(%d+)$")
	if not action then return end
	if action == "F" and ValidToken(token) and SafeName(FullName(from)) and ValidAmount(tonumber(amount))
		and Sync():IsGuildMaster(senderName) then
		self:ObserveFinalization(OfferKey(guild, FullName(from), token))
	end
	local offer = self:Find(from, token)
	if not offer or tonumber(amount) ~= offer.amount then return end
	if action == "A" and senderName == offer.recipient and (offer.status == "pending" or offer.status == "accepted") then
		offer.status = "accepted"
		if Sync():IsLocalGuildMaster() then
			print(string.format("DKP trade accepted. /dkp trade finalize %s %s", offer.from, offer.token))
		elseif me == offer.from then
			print("Recipient accepted your DKP offer; guild master must finalize.")
		end
	elseif action == "C" and (senderName == offer.from or senderName == offer.recipient)
		and (offer.status == "pending" or offer.status == "accepted") then
		offer.status = "cancelled"
		print("DKP trade cancelled: " .. offer.from .. " " .. offer.token)
	elseif action == "F" and Sync():IsGuildMaster(senderName) and offer.status == "accepted" then
		offer.status = "completed"
		print("Guild master finalized the DKP trade. Apply a new guild snapshot to update local points.")
	end
end

function Trading:List()
	self:Prune()
	print("Session trades (expire after 5 minutes):")
	local count = 0
	for _, offer in pairs(self.offers) do
		count = count + 1
		print(string.format("%s %s -> %s: %d DKP [%s]", offer.token, offer.from, offer.recipient, offer.amount, offer.status))
	end
	if count == 0 then print("No session trades.") end
end

return Trading
