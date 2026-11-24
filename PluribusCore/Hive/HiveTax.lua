-- PluribusHive Guild Tax & Treasury System
-- Tracks guild gold tax (looted coins, quest gold, AH sales, optional weekly flat dues),
-- auto-detects tax payments mailed or traded to the Guild Banker, and syncs live compliance across the guild over PLBHIVE.

PluribusHiveTax = {
	initialized = false,
	lastMoney = nil,
	inLootWindow = false,
	lastTradeTarget = nil,
	lastTradeMoney = 0,
}
_G.PluribusHiveTax = PluribusHiveTax

local function EnsureTaxDB()
	local db = PluribusHive:GetDB()
	db.tax = db.tax or {}
	local t = db.tax
	t.policy = t.policy or {
		enabled = true,
		ratePct = 10,             -- Default 10% guild tax on looted gold
		taxLootGold = true,
		taxQuestGold = true,
		taxAuctionSales = false,
		weeklyFlatCopper = 0,     -- Optional flat weekly dues in copper
		bankerName = "",          -- Guild Banker character name for 1-click Mail Tax
		updatedAt = 0,
		updatedBy = "",
	}
	t.members = t.members or {}
	t.history = t.history or {}
	return t
end

function PluribusHiveTax:GetPolicy()
	return EnsureTaxDB().policy
end

function PluribusHiveTax:GetMyRecord()
	local t = EnsureTaxDB()
	local me = PluribusHive:GetPlayerShortName()
	if not t.members[me] then
		t.members[me] = {
			name = me,
			class = PluribusHive:GetPlayerClass(),
			grossEarned = 0,
			taxAccrued = 0,
			taxPaid = 0,
			lastPaymentAt = 0,
			updatedAt = time(),
		}
	end
	t.members[me].class = PluribusHive:GetPlayerClass()
	return t.members[me]
end

function PluribusHiveTax:GetBalanceDue(rec)
	rec = rec or self:GetMyRecord()
	return math.max(0, math.floor((rec.taxAccrued or 0) - (rec.taxPaid or 0)))
end

function PluribusHiveTax:ComputeTaxCopper(copperEarned, ratePct)
	local earned = tonumber(copperEarned) or 0
	local rate = tonumber(ratePct)
	if rate == nil then rate = self:GetPolicy().ratePct or 0 end
	if earned <= 0 or rate <= 0 then return 0 end
	return math.floor((earned * rate) / 100 + 0.5)
end

function PluribusHiveTax:AddHistory(kind, copper, note)
	local t = EnsureTaxDB()
	table.insert(t.history, 1, {
		time = time(),
		kind = kind or "TAX",
		copper = math.floor(copper or 0),
		note = tostring(note or ""),
	})
	while #t.history > 60 do table.remove(t.history) end
end

function PluribusHiveTax:RecordTaxableIncome(copperEarned, sourceLabel)
	local pol = self:GetPolicy()
	if not pol.enabled or (pol.ratePct or 0) <= 0 then return 0 end
	copperEarned = math.floor(tonumber(copperEarned) or 0)
	if copperEarned <= 0 then return 0 end

	local taxDue = self:ComputeTaxCopper(copperEarned, pol.ratePct)
	local rec = self:GetMyRecord()
	rec.grossEarned = (rec.grossEarned or 0) + copperEarned
	rec.taxAccrued = (rec.taxAccrued or 0) + taxDue
	rec.updatedAt = time()

	if taxDue > 0 then
		self:AddHistory("ACCRUED", taxDue, string.format("%d%% of %s (%s)", pol.ratePct, PluribusUtils:FormatGold(copperEarned), sourceLabel or "Loot"))
		self:BroadcastMyLedger()
	end
	return taxDue
end

function PluribusHiveTax:RecordPayment(copperPaid, methodLabel)
	copperPaid = math.floor(tonumber(copperPaid) or 0)
	if copperPaid <= 0 then return false end
	local rec = self:GetMyRecord()
	rec.taxPaid = (rec.taxPaid or 0) + copperPaid
	rec.lastPaymentAt = time()
	rec.updatedAt = time()
	self:AddHistory("PAID", copperPaid, methodLabel or "Guild Vault Deposit")
	self:BroadcastMyLedger()
	PluribusHive:AddFeedEvent("TAX", string.format("Paid %s guild tax (%s)", PluribusUtils:FormatGold(copperPaid), methodLabel or "Deposit"))
	if _G.PluribusUIFramework then
		_G.PluribusUIFramework:ShowNotification("|cff4ade80Logged Guild Tax payment: " .. PluribusUtils:FormatGold(copperPaid) .. "|r", 3.5)
	end
	return true
end

function PluribusHiveTax:UpdatePolicy(updates, broadcast)
	local pol = self:GetPolicy()
	for k, v in pairs(updates or {}) do
		pol[k] = v
	end
	pol.ratePct = math.max(0, math.min(50, tonumber(pol.ratePct) or 0))
	pol.weeklyFlatCopper = math.max(0, math.floor(tonumber(pol.weeklyFlatCopper) or 0))
	pol.bankerName = PluribusHive:NormalizeName(pol.bankerName or "")
	pol.updatedAt = time()
	pol.updatedBy = PluribusHive:GetPlayerShortName()
	if broadcast ~= false then
		self:BroadcastPolicy()
	end
	return pol
end

function PluribusHiveTax:BroadcastPolicy()
	local pol = self:GetPolicy()
	local payload = string.format("%d|%d|%d|%d|%d|%d|%s|%d",
		pol.enabled and 1 or 0,
		math.floor(pol.ratePct or 0),
		pol.taxLootGold and 1 or 0,
		pol.taxQuestGold and 1 or 0,
		pol.taxAuctionSales and 1 or 0,
		math.floor(pol.weeklyFlatCopper or 0),
		(pol.bankerName or ""):gsub("|", ""),
		pol.updatedAt or time()
	)
	PluribusHive:Send("TAXCFG", payload, "GUILD")
end

function PluribusHiveTax:BroadcastMyLedger()
	local rec = self:GetMyRecord()
	local payload = string.format("%s|%d|%d|%d|%d",
		rec.class or "WARRIOR",
		math.floor(rec.grossEarned or 0),
		math.floor(rec.taxAccrued or 0),
		math.floor(rec.taxPaid or 0),
		rec.lastPaymentAt or 0
	)
	PluribusHive:Send("TAXLOG", payload, "GUILD")
end

-- Returns sorted guild ledger + aggregate treasury totals
function PluribusHiveTax:GetGuildLedger()
	local t = EnsureTaxDB()
	self:GetMyRecord() -- ensure self is always present
	local rows = {}
	local totalAccrued, totalPaid, totalDue = 0, 0, 0
	local me = PluribusHive:GetPlayerShortName()

	for memberName, rec in pairs(t.members or {}) do
		local accrued = math.floor(rec.taxAccrued or 0)
		local paid = math.floor(rec.taxPaid or 0)
		local due = math.max(0, accrued - paid)
		local pct = accrued > 0 and math.min(100, math.floor((paid / accrued) * 100 + 0.5)) or 100
		totalAccrued = totalAccrued + accrued
		totalPaid = totalPaid + paid
		totalDue = totalDue + due
		table.insert(rows, {
			name = memberName,
			class = rec.class or "WARRIOR",
			grossEarned = math.floor(rec.grossEarned or 0),
			taxAccrued = accrued,
			taxPaid = paid,
			balanceDue = due,
			compliancePct = pct,
			lastPaymentAt = rec.lastPaymentAt or 0,
			isSelf = PluribusHive:SamePlayer(memberName, me),
		})
	end

	table.sort(rows, function(a, b)
		if a.balanceDue ~= b.balanceDue then return a.balanceDue > b.balanceDue end
		if a.taxPaid ~= b.taxPaid then return a.taxPaid > b.taxPaid end
		return a.name < b.name
	end)

	return rows, {
		totalAccrued = totalAccrued,
		totalPaid = totalPaid,
		totalDue = totalDue,
		memberCount = #rows,
	}
end

-- 1-click Pay Tax via WoW Mailbox (or save draft if not standing at a mailbox yet)
function PluribusHiveTax:MailTaxToBanker()
	local pol = self:GetPolicy()
	local due = self:GetBalanceDue()
	if due <= 0 then
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("|cff4ade80You have 0g guild tax owed — all caught up!|r", 3)
		end
		return false
	end
	local banker = PluribusHive:NormalizeName(pol.bankerName)
	if banker == "" then
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("|cfffbbf24Set a Guild Banker name in Guild Tax settings first.|r", 3.5)
		end
		return false
	end
	if _G.PluribusHiveMail then
		local subj = "Guild Tax Payment (" .. PluribusUtils:FormatGold(due) .. ")"
		local body = string.format("Guild tax deposit from %s via Pluribus Suite (%d%% rate).", PluribusHive:GetPlayerShortName(), pol.ratePct or 10)
		_G.PluribusHiveMail:PrefillWoWLetter(banker, subj, body, due)
		return true
	end
	return false
end

-- Parse localized/English loot coin strings (fallback alongside PLAYER_MONEY delta)
local function ParseLootCopper(msg)
	if type(msg) ~= "string" then return 0 end
	local g = tonumber(msg:match("(%d+)%s*[Gg]old")) or 0
	local s = tonumber(msg:match("(%d+)%s*[Ss]ilver")) or tonumber(msg:match("(%d+)%s*[Ss]ilber")) or 0
	local c = tonumber(msg:match("(%d+)%s*[Cc]opper")) or tonumber(msg:match("(%d+)%s*[Kk]upfer")) or 0
	return (g * 10000) + (s * 100) + c
end

function PluribusHiveTax:Initialize()
	if self.initialized then return end
	self.initialized = true
	EnsureTaxDB()
	self:GetMyRecord()

	-- Receive guild tax policy updates from officers / guild master
	PluribusHive:RegisterHandler("TAXCFG", function(sender, body)
		local en, rate, lootF, questF, ahF, flatC, banker, ts =
			body:match("^(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|([^|]*)|?(.*)$")
		if not en then return end
		local pol = PluribusHiveTax:GetPolicy()
		local incomingTs = tonumber(ts) or time()
		if incomingTs >= (pol.updatedAt or 0) then
			pol.enabled = (en == "1")
			pol.ratePct = math.max(0, math.min(50, tonumber(rate) or 10))
			pol.taxLootGold = (lootF == "1")
			pol.taxQuestGold = (questF == "1")
			pol.taxAuctionSales = (ahF == "1")
			pol.weeklyFlatCopper = tonumber(flatC) or 0
			pol.bankerName = PluribusHive:NormalizeName(banker or "")
			pol.updatedAt = incomingTs
			pol.updatedBy = sender
		end
	end)

	-- Receive guildmates' tax ledger summaries
	PluribusHive:RegisterHandler("TAXLOG", function(sender, body)
		local cls, gross, accrued, paid, lastPay =
			body:match("^([^|]*)|(%d+)|(%d+)|(%d+)|?(.*)$")
		if not gross then return end
		local t = EnsureTaxDB()
		local key = PluribusHive:NormalizeName(sender)
		if key == "" or PluribusHive:SamePlayer(key, PluribusHive:GetPlayerShortName()) then return end
		t.members[key] = {
			name = key,
			class = cls ~= "" and cls or "WARRIOR",
			grossEarned = tonumber(gross) or 0,
			taxAccrued = tonumber(accrued) or 0,
			taxPaid = tonumber(paid) or 0,
			lastPaymentAt = tonumber(lastPay) or 0,
			updatedAt = time(),
		}
	end)

	-- Auto-detect gold mailed to Guild Banker via hooksecurefunc("SendMail")
	if hooksecurefunc and _G.SendMail then
		pcall(hooksecurefunc, "SendMail", function(target)
			local pol = PluribusHiveTax:GetPolicy()
			local banker = PluribusHive:NormalizeName(pol.bankerName)
			if banker ~= "" and PluribusHive:SamePlayer(target, banker) then
				local copper = GetSendMailMoney and GetSendMailMoney() or 0
				if copper and copper > 0 then
					PluribusHiveTax:RecordPayment(copper, "Mailed to " .. banker)
				end
			end
		end)
	end

	-- Sync ledger on guild sync requests
	if _G.PluribusMessaging then
		_G.PluribusMessaging:Subscribe("HIVE_PEER_REQUESTED_SYNC", function()
			if C_Timer and C_Timer.After then
				C_Timer.After(math.random(3, 7), function()
					PluribusHiveTax:BroadcastMyLedger()
				end)
			end
		end)
	end

	-- Track looted gold, quest gold, and banker trades automatically
	local f = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "CHAT_MSG_MONEY", "QUEST_TURNED_IN", "TRADE_SHOW", "TRADE_MONEY_CHANGED", "TRADE_ACCEPT_UPDATE" }) do
		pcall(f.RegisterEvent, f, ev)
	end
	f:SetScript("OnEvent", function(_, ev, arg1, arg2, arg3)
		if ev == "PLAYER_ENTERING_WORLD" then
			PluribusHiveTax.lastMoney = GetMoney and GetMoney() or 0
			if C_Timer and C_Timer.After then
				C_Timer.After(8, function() PluribusHiveTax:BroadcastMyLedger() end)
			end
		elseif ev == "CHAT_MSG_MONEY" then
			local pol = PluribusHiveTax:GetPolicy()
			if pol.enabled and pol.taxLootGold then
				local copper = ParseLootCopper(arg1)
				if copper > 0 then
					PluribusHiveTax:RecordTaxableIncome(copper, "Loot Gold")
				end
			end
		elseif ev == "QUEST_TURNED_IN" then
			local pol = PluribusHiveTax:GetPolicy()
			local moneyReward = tonumber(arg3) or 0
			if pol.enabled and pol.taxQuestGold and moneyReward > 0 then
				PluribusHiveTax:RecordTaxableIncome(moneyReward, "Quest Reward")
			end
		elseif ev == "TRADE_SHOW" then
			PluribusHiveTax.lastTradeTarget = UnitName and UnitName("npc") or nil
			PluribusHiveTax.lastTradeMoney = 0
		elseif ev == "TRADE_MONEY_CHANGED" then
			if GetPlayerTradeMoney then
				PluribusHiveTax.lastTradeMoney = GetPlayerTradeMoney() or 0
			end
		elseif ev == "TRADE_ACCEPT_UPDATE" then
			if arg1 == 1 and arg2 == 1 and PluribusHiveTax.lastTradeMoney > 0 and PluribusHiveTax.lastTradeTarget then
				local pol = PluribusHiveTax:GetPolicy()
				if pol.bankerName ~= "" and PluribusHive:SamePlayer(PluribusHiveTax.lastTradeTarget, pol.bankerName) then
					PluribusHiveTax:RecordPayment(PluribusHiveTax.lastTradeMoney, "Traded to " .. pol.bankerName)
					PluribusHiveTax.lastTradeMoney = 0
				end
			end
		end
	end)
end

return PluribusHiveTax
