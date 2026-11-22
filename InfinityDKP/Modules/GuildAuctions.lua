local GuildAuctions = { prefix = "InfinityDKPA1", sequence = 0 }
_G.InfinityDKPGuildAuctions = GuildAuctions

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Integer(value, maximum)
	value = Public(value)
	return type(value) == "number" and value == value and value > 0
		and value <= maximum and value == math.floor(value)
end

local function SafeName(name)
	return type(name) == "string" and name ~= "" and #name <= 80 and not name:find("[%z\1-\32~|]")
end

local function ValidToken(token)
	return type(token) == "string" and #token <= 32 and token:match("^%d+%-%d+$") ~= nil
end

local function Sync() return _G.InfinityDKPGuildSync end
local function Guild() return Sync() and Sync():GetGuildKey() end
local function FullName(name) return Sync() and Sync():GetFullName(name) end
local function Me() return _G.UnitName and FullName(Public(UnitName("player"))) end
local function Refresh()
	if _G.InfinityDKPUI then InfinityDKPUI:Update() end
end

function GuildAuctions:Initialize()
	if self.initialized then return end
	self.initialized = true
	local chat = _G.C_ChatInfo
	if not (Sync() and chat and chat.RegisterAddonMessagePrefix and chat.SendAddonMessage
		and _G.C_Timer and C_Timer.After) then
		InfinityUtils:Warning("Guild auction messaging is unavailable.", "GuildAuction")
		return
	end
	local ok, result = pcall(chat.RegisterAddonMessagePrefix, self.prefix)
	local protected = _G.issecretvalue and issecretvalue(result)
	local duplicate = _G.Enum and Enum.RegisterAddonMessagePrefixResult
		and Enum.RegisterAddonMessagePrefixResult.DuplicatePrefix or 1
	if not ok or protected or (result ~= nil and result ~= true and result ~= 0 and result ~= duplicate) then
		InfinityUtils:Warning("Could not register guild auction messages.", "GuildAuction")
		return
	end
	self.available = true
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("CHAT_MSG_ADDON")
	frame:SetScript("OnEvent", function(_, _, ...) self:OnMessage(...) end)
	self.frame = frame
end

function GuildAuctions:Send(message)
	if not self.available or not Guild() then
		InfinityUtils:Warning("Guild auction messaging is unavailable.", "GuildAuction")
		return false
	end
	local ok, result = pcall(C_ChatInfo.SendAddonMessage, self.prefix, message, "GUILD")
	local protected = _G.issecretvalue and issecretvalue(result)
	if not ok or protected or (result ~= nil and result ~= true and result ~= 0) then
		InfinityUtils:Warning("Guild auction message failed: " .. (protected and "protected result" or tostring(result)), "GuildAuction")
		return false
	end
	return true
end

function GuildAuctions:Create(itemLink, startingBid, duration)
	itemLink, startingBid, duration = Public(itemLink), Public(startingBid), Public(duration)
	local guild, owner = Guild(), Me()
	if not self.available or not guild or not owner or not Sync():IsLocalGuildMaster() then
		InfinityUtils:Warning("Only the guild master can start a guild auction.", "GuildAuction")
		return false
	end
	if self.auction and self.auction.status == "active" and self.auction.guild == guild
		and self.auction.owner == owner then
		InfinityUtils:Warning("A guild auction is already active.", "GuildAuction")
		return false
	end
	if type(itemLink) ~= "string" or not itemLink:match("|Hitem:%d+") or #itemLink > 150
		or itemLink:find("[%z\1-\31~]") or not Integer(startingBid, 1000000000)
		or not Integer(duration, 3600) then
		InfinityUtils:Warning("Invalid item link, starting bid or duration.", "GuildAuction")
		return false
	end
	self.sequence = self.sequence + 1
	local token = tostring(math.floor(GetTime() * 1000)) .. "-" .. self.sequence
	local message = table.concat({ "A", token, duration, startingBid, itemLink }, "~")
	if #message > 240 or not self:Send(message) then return false end
	local auction = { token = token, guild = guild, owner = owner, itemLink = itemLink,
		startingBid = startingBid, endTime = GetTime() + duration, status = "active", revision = 0 }
	self.auction = auction
	C_Timer.After(duration, function()
		if self.auction == auction and auction.status == "active" then self:Close() end
	end)
	print("Guild auction " .. token .. " started. Bids are synchronized; points and items remain manual.")
	Refresh()
	return true
end

function GuildAuctions:Bid(amount)
	amount = Public(amount)
	local auction = self.auction
	if not auction or auction.status ~= "active" or auction.guild ~= Guild() or GetTime() >= auction.endTime then
		InfinityUtils:Warning("No active guild auction is available.", "GuildAuction")
		return false
	end
	if not Integer(amount, 1000000000) then
		InfinityUtils:Warning("Bid must be a positive integer.", "GuildAuction")
		return false
	end
	if auction.owner == Me() then
		return self:AcceptBid(Me(), amount)
	end
	if not self:Send("B~" .. auction.token .. "~" .. amount) then return false end
	print("Guild bid sent; awaiting the guild master's confirmation.")
	return true
end

function GuildAuctions:AcceptBid(sender, amount)
	local auction = self.auction
	if not auction or auction.status ~= "active" or auction.guild ~= Guild() or auction.owner ~= Me()
		or not Sync():IsLocalGuildMaster() or GetTime() >= auction.endTime
		or not Integer(amount, 1000000000) or not SafeName(sender) or not Sync():IsGuildMember(sender) then
		return false
	end
	local required = auction.highBid and auction.highBid + 1 or auction.startingBid
	if amount < required then
		InfinityUtils:Warning("Guild bid below the current minimum: " .. required, "GuildAuction")
		self:Send(table.concat({ "N", auction.token, sender, required }, "~"))
		return false
	end
	local revision = auction.revision + 1
	local remaining = math.max(0, math.floor(auction.endTime - GetTime()))
	local message = table.concat({ "U", auction.token, revision, amount, sender, remaining }, "~")
	if not self:Send(message) then return false end
	auction.revision, auction.highBid, auction.highestBidder = revision, amount, sender
	print("Guild bid accepted: " .. sender .. " for " .. amount .. ".")
	Refresh()
	return true
end

function GuildAuctions:Close(cancel)
	local auction = self.auction
	if not auction or auction.status ~= "active" or auction.guild ~= Guild() or auction.owner ~= Me()
		or not Sync():IsLocalGuildMaster() then
		InfinityUtils:Warning("Only the current guild master can close this guild auction.", "GuildAuction")
		return false
	end
	local bidder, amount = auction.highestBidder or "-", auction.highBid or 0
	local message = table.concat({ cancel and "X" or "C", auction.token, bidder, amount }, "~")
	if not self:Send(message) then return false end
	auction.status = cancel and "cancelled" or "closed"
	if cancel then print("Guild auction cancelled.")
	elseif auction.highestBidder then
		print("Guild auction winner: " .. bidder .. " for " .. amount .. ". Award item and points manually.")
	else print("Guild auction closed without bids.") end
	Refresh()
	return true
end

function GuildAuctions:Request()
	if not self:Send("R") then return false end
	print("Requested the current guild auction.")
	return true
end

function GuildAuctions:Broadcast()
	local auction = self.auction
	if not auction or auction.status ~= "active" or auction.guild ~= Guild() or auction.owner ~= Me()
		or not Sync():IsLocalGuildMaster() then return false end
	local remaining = math.max(0, math.ceil(auction.endTime - GetTime()))
	if remaining == 0 then return self:Close() end
	if not self:Send(table.concat({ "A", auction.token, remaining, auction.startingBid, auction.itemLink }, "~")) then return false end
	if auction.highBid then
		return self:Send(table.concat({ "U", auction.token, auction.revision, auction.highBid,
			auction.highestBidder, remaining }, "~"))
	end
	return true
end

function GuildAuctions:OnMessage(prefix, message, channel, sender)
	prefix, message, channel, sender = Public(prefix), Public(message), Public(channel), Public(sender)
	if prefix ~= self.prefix or channel ~= "GUILD" or type(message) ~= "string" or #message > 240 then return end
	local guild, senderKey, myKey = Guild(), FullName(sender), Me()
	if not guild or not senderKey or not myKey or senderKey == myKey or not Sync():IsGuildMember(sender) then return end
	if message == "R" then
		if Sync():IsLocalGuildMaster() then
			local auction = self.auction
			if auction and auction.status == "active" and auction.guild == guild and auction.owner == myKey then
				if GetTime() < auction.endTime then
					self:Broadcast()
				elseif self:Close() then
					self:Send("Z~" .. senderKey)
				end
			else
				self:Send("Z~" .. senderKey)
			end
		end
		return
	end
	local token, amount = message:match("^B~([%d%-]+)~(%d+)$")
	if token then
		amount = tonumber(amount)
		if self.auction and token == self.auction.token then self:AcceptBid(senderKey, amount) end
		return
	end
	if not Sync():IsGuildMaster(sender) then return end
	local missing = message:match("^Z~([^~]+)$")
	if missing then
		if missing == myKey then
			local auction = self.auction
			if auction and auction.guild == guild and auction.status == "active" then auction.status = "unavailable" end
			InfinityUtils:Warning("The guild master has no active guild auction.", "GuildAuction")
			Refresh()
		end
		return
	end
	local duration, startingBid, itemLink
	token, duration, startingBid, itemLink = message:match("^A~([%d%-]+)~(%d+)~(%d+)~(.+)$")
	if token then
		duration, startingBid = tonumber(duration), tonumber(startingBid)
		if not ValidToken(token) or not Integer(duration, 3600) or not Integer(startingBid, 1000000000)
			or not itemLink:match("|Hitem:%d+") or #itemLink > 150 or itemLink:find("[%z\1-\31~]") then return end
		local auction = self.auction
		if auction and auction.status == "active" and auction.guild == guild
			and auction.token == token and auction.owner == senderKey then
			if auction.itemLink ~= itemLink or auction.startingBid ~= startingBid then return end
			auction.endTime = GetTime() + duration
		else
			self.auction = { token = token, owner = senderKey, guild = guild, itemLink = itemLink,
				startingBid = startingBid, endTime = GetTime() + duration, revision = 0, status = "active" }
			print("Guild auction " .. token .. ": " .. itemLink .. ". /dkp guildauction bid <amount>")
		end
		Refresh()
		return
	end
	local auction = self.auction
	if not auction or auction.status ~= "active" or auction.owner ~= senderKey or auction.guild ~= guild then return end
	local rejected, minimum
	token, rejected, minimum = message:match("^N~([%d%-]+)~([^~]+)~(%d+)$")
	if token then
		minimum = tonumber(minimum)
		if token == auction.token and rejected == myKey and Integer(minimum, 1000000001) then
			InfinityUtils:Warning("Guild bid rejected. Current minimum: " .. minimum, "GuildAuction")
		end
		return
	end
	local revision, bidder, remaining
	token, revision, amount, bidder, remaining = message:match("^U~([%d%-]+)~(%d+)~(%d+)~([^~]+)~(%d+)$")
	if token then
		revision, amount, remaining = tonumber(revision), tonumber(amount), tonumber(remaining)
		if token ~= auction.token or not Integer(revision, 1000000000) or revision <= auction.revision
			or not Integer(amount, 1000000000) or amount < auction.startingBid
			or not SafeName(bidder) or not Sync():IsGuildMember(bidder)
			or type(remaining) ~= "number" or remaining < 0 or remaining > 3600 then return end
		auction.revision, auction.highBid, auction.highestBidder = revision, amount, bidder
		auction.endTime = GetTime() + remaining
		print("Guild bid: " .. bidder .. " for " .. amount .. ".")
		Refresh()
		return
	end
	local kind
	kind, token, bidder, amount = message:match("^([CX])~([%d%-]+)~([^~]+)~(%d+)$")
	if kind and token == auction.token then
		amount = tonumber(amount)
		if not ((bidder == "-" and amount == 0) or (SafeName(bidder) and Integer(amount, 1000000000)
			and Sync():IsGuildMember(bidder))) then return end
		auction.status, auction.highestBidder = kind == "C" and "closed" or "cancelled", bidder ~= "-" and bidder or nil
		auction.highBid = amount > 0 and amount or nil
		if kind == "X" then print("Guild auction cancelled.")
		elseif auction.highestBidder then
			print("Guild auction winner: " .. bidder .. " for " .. amount .. ". Award item and points manually.")
		else print("Guild auction closed without bids.") end
		Refresh()
	end
end

return GuildAuctions
