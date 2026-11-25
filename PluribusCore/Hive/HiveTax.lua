-- PluribusHive Guild Tax & Treasury System
-- Tracks guild gold tax (looted coins, quest gold, AH sales, optional weekly flat dues),
-- auto-detects tax payments mailed or traded to the Guild Banker, and syncs live compliance across the guild over PLBHIVE.

PluribusHiveTax = {
	initialized = false,
	lastMoney = nil,
	inLootWindow = false,
	lastLootClosedAt = 0,
	mailOpen = false,
	merchantOpen = false,
	_inboxSnapshot = {},
	_prevAhSaleTotal = 0,
	_recentTaxedMailCopper = 0,
	_recentTaxedMailAt = 0,
	_recentTaxedLootCopper = 0,
	_recentTaxedLootAt = 0,
	_recentTaxedQuestCopper = 0,
	_recentTaxedQuestAt = 0,
	_pendingQuestRewardCopper = 0,
	_questTurnedInAt = 0,
	lastTradeTarget = nil,
	lastTradeMoney = 0,
	guildBankOpen = false,
	guildBankBar = nil,
	_depositingViaButton = false,
}
_G.PluribusHiveTax = PluribusHiveTax

-- Module-local tracker so we NEVER write custom keys onto Blizzard's GuildBankFrame (zero taint)
local hookedGuildBankFrames = {}

local function EnsureTaxDB()
	local db = PluribusHive:GetDB()
	db.tax = db.tax or {}
	local t = db.tax
	t.policy = t.policy or {
		enabled = true,
		ratePct = 10,             -- Default 10% guild tax on loot, quest & AH gold
		taxLootGold = true,
		taxQuestGold = true,
		taxAuctionSales = true,
		taxVendorSales = false,
		weeklyFlatCopper = 0,     -- Optional flat weekly dues in copper
		bankerName = "",          -- Guild Banker character name for 1-click Mail Tax
		updatedAt = 0,
		updatedBy = "",
		_ahTaxMigrated = true,
	}
	-- Migrate older SavedVariables where AH tax defaulted to false with no UI checkbox
	if t.policy._ahTaxMigrated ~= true then
		t.policy.taxAuctionSales = true
		t.policy._ahTaxMigrated = true
	end
	if t.policy.taxVendorSales == nil then
		t.policy.taxVendorSales = false
	end
	t.members = t.members or {}
	t.history = t.history or {}
	return t
end

function PluribusHiveTax:PruneDuplicateTaxMembers()
	local t = EnsureTaxDB()
	local me = PluribusHive:GetPlayerShortName()
	local meKey = PluribusHive:CanonicalKey(me)
	local byCanon = {}
	local dirty = false

	for rawName, rec in pairs(t.members or {}) do
		if type(rec) == "table" then
			local cKey = PluribusHive:CanonicalKey(rawName)
			local norm = PluribusHive:NormalizeName(rawName)
			if cKey ~= "" then
				local targetName = (cKey == meKey) and me or norm
				if rawName ~= targetName then dirty = true end
				local existing = byCanon[cKey]
				if not existing then
					rec.name = targetName
					byCanon[cKey] = { name = targetName, rec = rec }
				else
					dirty = true
					local dst = existing.rec
					dst.grossEarned = math.max(tonumber(dst.grossEarned) or 0, tonumber(rec.grossEarned) or 0)
					dst.taxAccrued = math.max(tonumber(dst.taxAccrued) or 0, tonumber(rec.taxAccrued) or 0)
					dst.taxPaid = math.max(tonumber(dst.taxPaid) or 0, tonumber(rec.taxPaid) or 0)
					dst.lastPaymentAt = math.max(tonumber(dst.lastPaymentAt) or 0, tonumber(rec.lastPaymentAt) or 0)
					dst.updatedAt = math.max(tonumber(dst.updatedAt) or 0, tonumber(rec.updatedAt) or 0)
					if (not dst.class or dst.class == "") and rec.class then dst.class = rec.class end
					dst.name = targetName
					existing.name = targetName
				end
			else
				dirty = true
			end
		end
	end

	if dirty then
		local rebuilt = {}
		for _, entry in pairs(byCanon) do
			rebuilt[entry.name] = entry.rec
		end
		t.members = rebuilt
	end
end

function PluribusHiveTax:GetPolicy()
	return EnsureTaxDB().policy
end

function PluribusHiveTax:GetMyRecord()
	self:PruneDuplicateTaxMembers()
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
	t.members[me].name = me
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

	local rec = self:GetMyRecord()
	-- Fractional carry accumulator ensures small looted copper adds up accurately instead of rounding to 0 forever
	local exactTax = (copperEarned * (tonumber(pol.ratePct) or 0)) / 100
	local totalWithCarry = exactTax + (tonumber(rec._taxCarry) or 0)
	local taxDue = math.floor(totalWithCarry + 0.000001)
	rec._taxCarry = totalWithCarry - taxDue

	rec.grossEarned = (rec.grossEarned or 0) + copperEarned
	rec.taxAccrued = (rec.taxAccrued or 0) + taxDue
	rec.updatedAt = time()

	if taxDue > 0 then
		self:AddHistory("ACCRUED", taxDue, string.format("%d%% von %s (%s)", pol.ratePct, PluribusUtils:FormatGold(copperEarned), sourceLabel or "Loot"))
		self:BroadcastMyLedger()
		self:RefreshGuildBankTaxBar()
		self:NotifyTaxChanged()
	end
	return taxDue
end

function PluribusHiveTax:NotifyTaxChanged()
	if _G.PluribusMessaging and _G.PluribusMessaging.Publish then
		pcall(function() _G.PluribusMessaging:Publish("HIVE_TAX_UPDATED") end)
	end
	if _G.PluribusMainFrame and _G.PluribusMainFrame.frame and _G.PluribusMainFrame.frame:IsShown() then
		if _G.PluribusMainFrame.RefreshSideBadges then
			_G.PluribusMainFrame:RefreshSideBadges(_G.PluribusMainFrame.frame)
		end
		if _G.PluribusMainFrame.currentTab == "Guild Tax" then
			_G.PluribusMainFrame:ShowTab(_G.PluribusMainFrame.frame, "Guild Tax")
		end
	end
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
	self:RefreshGuildBankTaxBar()
	self:NotifyTaxChanged()
	PluribusHive:AddFeedEvent("TAX", string.format("Paid %s guild tax (%s)", PluribusUtils:FormatGold(copperPaid), methodLabel or "Deposit"))
	if _G.PluribusUIFramework then
		_G.PluribusUIFramework:ShowNotification("|cff4ade80Gildensteuer verbucht: " .. PluribusUtils:FormatGold(copperPaid) .. "|r", 3.5)
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
	self:RefreshGuildBankTaxBar()
	self:NotifyTaxChanged()
	return pol
end

function PluribusHiveTax:BroadcastPolicy()
	local pol = self:GetPolicy()
	local payload = string.format("%d|%d|%d|%d|%d|%d|%s|%d|%d",
		pol.enabled and 1 or 0,
		math.floor(pol.ratePct or 0),
		pol.taxLootGold and 1 or 0,
		pol.taxQuestGold and 1 or 0,
		pol.taxAuctionSales and 1 or 0,
		math.floor(pol.weeklyFlatCopper or 0),
		(pol.bankerName or ""):gsub("|", ""),
		pol.updatedAt or time(),
		pol.taxVendorSales and 1 or 0
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

-- Returns sorted guild ledger + aggregate treasury totals (strictly deduplicated by CanonicalKey)
function PluribusHiveTax:GetGuildLedger()
	self:PruneDuplicateTaxMembers()
	local t = EnsureTaxDB()
	self:GetMyRecord() -- ensure self is always present
	local rows = {}
	local seenCanon = {}
	local totalAccrued, totalPaid, totalDue = 0, 0, 0
	local me = PluribusHive:GetPlayerShortName()

	for memberName, rec in pairs(t.members or {}) do
		local cKey = PluribusHive:CanonicalKey(memberName)
		if cKey ~= "" and not seenCanon[cKey] and type(rec) == "table" then
			seenCanon[cKey] = true
			local displayName = PluribusHive:SamePlayer(memberName, me) and me or PluribusHive:NormalizeName(memberName)
			local accrued = math.floor(rec.taxAccrued or 0)
			local paid = math.floor(rec.taxPaid or 0)
			local due = math.max(0, accrued - paid)
			local pct = accrued > 0 and math.min(100, math.floor((paid / accrued) * 100 + 0.5)) or 100
			totalAccrued = totalAccrued + accrued
			totalPaid = totalPaid + paid
			totalDue = totalDue + due
			table.insert(rows, {
				name = displayName,
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

-- Check whether Blizzard's Guild Bank window is currently open
function PluribusHiveTax:IsGuildBankOpen()
	if self.guildBankOpen then return true end
	if _G.PluribusHiveInventory and _G.PluribusHiveInventory.guildBankOpen then
		return true
	end
	if _G.GuildBankFrame and _G.GuildBankFrame.IsShown and _G.GuildBankFrame:IsShown() then
		return true
	end
	return false
end

-- 1-Click Pay Tax directly into the open Guild Bank
function PluribusHiveTax:DepositTaxToGuildBank()
	local due = self:GetBalanceDue()
	if due <= 0 then
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("|cff4ade80Keine offenen Gildensteuern — alles bezahlt!|r", 3)
		end
		self:RefreshGuildBankTaxBar()
		return false
	end

	if not self:IsGuildBankOpen() then
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("|cfffbbf24Bitte öffne zuerst die Gildenbank, um Steuern einzuzahlen.|r", 3.5)
		end
		return false
	end

	if type(DepositGuildBankMoney) ~= "function" then
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("|cfff87171Gildenbank-Einzahlung wird von diesem Client nicht unterstützt.|r", 3.5)
		end
		return false
	end

	local cash = (GetMoney and GetMoney()) or 0
	local payable = math.min(due, cash)
	if payable <= 0 then
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("|cfff87171Nicht genug Gold im Inventar, um Steuern zu tilgen.|r", 3.5)
		end
		return false
	end

	self._depositingViaButton = true
	local ok = pcall(DepositGuildBankMoney, payable)
	self._depositingViaButton = false

	if not ok then
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("|cfff87171Einzahlung in die Gildenbank fehlgeschlagen.|r", 3.5)
		end
		return false
	end

	self:RecordPayment(payable, "Gildenbank-Einzahlung")
	local remaining = self:GetBalanceDue()
	if remaining > 0 and _G.PluribusUIFramework then
		_G.PluribusUIFramework:ShowNotification(
			"|cfffbbf24Teilzahlung eingezahlt (" .. PluribusUtils:FormatGold(payable) .. ") — Rest: " .. PluribusUtils:FormatGold(remaining) .. "|r",
			4
		)
	end
	self:RefreshGuildBankTaxBar()
	return true
end

-- Refresh text & button state on the attached Guild Bank tax strip (and Unified Guild Bank footer!)
function PluribusHiveTax:RefreshGuildBankTaxBar()
	if _G.PluribusHiveInventory and _G.PluribusHiveInventory.RefreshUnifiedGuildBankTaxStrip then
		_G.PluribusHiveInventory:RefreshUnifiedGuildBankTaxStrip()
	end
	local bar = self.guildBankBar
	if not bar then return end
	if _G.PluribusHiveInventory and _G.PluribusHiveInventory.IsUnifiedGuildBankActive and _G.PluribusHiveInventory:IsUnifiedGuildBankActive() then
		bar:Hide()
		return
	end

	local due = self:GetBalanceDue()
	local cash = (GetMoney and GetMoney()) or 0
	local pol = self:GetPolicy()

	if due > 0 then
		bar.statusText:SetText(string.format(
			"|cfffbbf24Gildensteuer (%d%%):|r |cfff87171%s offen|r",
			math.floor(pol.ratePct or 0),
			PluribusUtils:FormatGold(due)
		))
		if cash >= due then
			bar.payBtn:SetText("Steuern tilgen (" .. PluribusUtils:FormatGold(due) .. ")")
			bar.payBtn:SetEnabled(true)
			bar.payBtn:SetAlpha(1.0)
		elseif cash > 0 then
			bar.payBtn:SetText("Teilzahlung (" .. PluribusUtils:FormatGold(cash) .. ")")
			bar.payBtn:SetEnabled(true)
			bar.payBtn:SetAlpha(1.0)
		else
			bar.payBtn:SetText("Kein Gold dabei")
			bar.payBtn:SetEnabled(false)
			bar.payBtn:SetAlpha(0.55)
		end
	else
		bar.statusText:SetText(string.format(
			"|cfffbbf24Gildensteuer (%d%%):|r |cff4ade80Alles bezahlt (0c)|r",
			math.floor(pol.ratePct or 0)
		))
		bar.payBtn:SetText("Steuern bezahlt")
		bar.payBtn:SetEnabled(false)
		bar.payBtn:SetAlpha(0.55)
	end
end

-- Attach a sleek, taint-free 1-click "Steuern tilgen" bar directly above Blizzard's GuildBankFrame
function PluribusHiveTax:AttachToGuildBank()
	local gbFrame = _G.GuildBankFrame
	local UI = _G.PluribusUIFramework
	if not gbFrame or not UI then return end

	if not self.guildBankBar then
		local bar = CreateFrame("Frame", "PluribusGuildBankTaxBar", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		bar:SetHeight(34)
		bar:SetFrameStrata("HIGH")
		bar:SetClampedToScreen(true)
		bar:EnableMouse(true)
		UI:ApplyBackdrop(bar, 0.05, 0.08, 0.14, 0.96, 0.92, 0.72, 0.22, 0.92)

		local icon = bar:CreateTexture(nil, "ARTWORK")
		icon:SetSize(20, 20)
		icon:SetPoint("LEFT", bar, "LEFT", 10, 0)
		icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
		if icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end

		local statusText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		statusText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
		statusText:SetJustifyH("LEFT")
		bar.statusText = statusText

		local hubBtn = UI:CreateButton(bar, "Steuer-Tab", 86, 24, function()
			if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
				_G.PluribusMainFrame:OpenToTab("Guild Tax")
			end
		end)
		hubBtn:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
		bar.hubBtn = hubBtn

		local payBtn = UI:CreateButton(bar, "Steuern tilgen", 190, 24, function()
			PluribusHiveTax:DepositTaxToGuildBank()
		end, true)
		payBtn:SetPoint("RIGHT", hubBtn, "LEFT", -6, 0)
		bar.payBtn = payBtn

		statusText:SetPoint("RIGHT", payBtn, "LEFT", -8, 0)
		if statusText.SetWordWrap then statusText:SetWordWrap(false) end

		bar:Hide()
		self.guildBankBar = bar
	end

	self.guildBankBar:ClearAllPoints()
	self.guildBankBar:SetPoint("BOTTOMLEFT", gbFrame, "TOPLEFT", 6, 4)
	self.guildBankBar:SetPoint("BOTTOMRIGHT", gbFrame, "TOPRIGHT", -6, 4)

	if not hookedGuildBankFrames[gbFrame] then
		hookedGuildBankFrames[gbFrame] = true
		pcall(gbFrame.HookScript, gbFrame, "OnShow", function()
			PluribusHiveTax.guildBankOpen = true
			local unifiedOn = _G.PluribusHiveInventory and _G.PluribusHiveInventory.IsUnifiedUIEnabled and _G.PluribusHiveInventory:IsUnifiedUIEnabled()
			if PluribusHiveTax.guildBankBar then
				if unifiedOn then
					PluribusHiveTax.guildBankBar:Hide()
				else
					PluribusHiveTax.guildBankBar:Show()
				end
				PluribusHiveTax:RefreshGuildBankTaxBar()
			end
		end)
		pcall(gbFrame.HookScript, gbFrame, "OnHide", function()
			PluribusHiveTax.guildBankOpen = false
			if PluribusHiveTax.guildBankBar then
				PluribusHiveTax.guildBankBar:Hide()
			end
		end)
	end

	if gbFrame:IsShown() then
		self.guildBankOpen = true
		local unifiedOn = _G.PluribusHiveInventory and _G.PluribusHiveInventory.IsUnifiedUIEnabled and _G.PluribusHiveInventory:IsUnifiedUIEnabled()
		if unifiedOn then
			self.guildBankBar:Hide()
		else
			self.guildBankBar:Show()
		end
		self:RefreshGuildBankTaxBar()
	end
end

-- Parse EN/DE text AND coin-texture chat strings (|TInterface\MoneyFrame\UI-GoldIcon...|t, "12 Gold, 34 Silber", "12g 34s 56c")
local function ParseLootCopper(msg)
	if type(msg) ~= "string" or msg == "" then return 0 end
	-- Strip WoW color escapes and thousands separators between digits
	local clean = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	clean = clean:gsub("(%d)[%.,](%d%d%d)", "%1%2")

	-- 1. Coin texture icon format (e.g. 12|TInterface\MoneyFrame\UI-GoldIcon:0:0:2:0|t)
	local tg = tonumber(clean:match("(%d+)%s*|T[^|]*[Gg]old[Ii]con[^|]*|t")) or 0
	local ts = tonumber(clean:match("(%d+)%s*|T[^|]*[Ss]ilver[Ii]con[^|]*|t")) or 0
	local tc = tonumber(clean:match("(%d+)%s*|T[^|]*[Cc]opper[Ii]con[^|]*|t")) or 0
	if tg > 0 or ts > 0 or tc > 0 then
		return (tg * 10000) + (ts * 100) + tc
	end

	-- 2. Full EN + DE words (Gold / Silver / Silber / Copper / Kupfer)
	local g = tonumber(clean:match("(%d+)%s*[Gg]old")) or 0
	local s = tonumber(clean:match("(%d+)%s*[Ss]ilver")) or tonumber(clean:match("(%d+)%s*[Ss]ilber")) or 0
	local c = tonumber(clean:match("(%d+)%s*[Cc]opper")) or tonumber(clean:match("(%d+)%s*[Kk]upfer")) or 0
	if g > 0 or s > 0 or c > 0 then
		return (g * 10000) + (s * 100) + c
	end

	-- 3. Compact shorthand (e.g. "12g 34s 56c" or "12g 34s 56k")
	local cg = tonumber(clean:match("(%d+)%s*[gG]%f[%A]")) or 0
	local cs = tonumber(clean:match("(%d+)%s*[sS]%f[%A]")) or 0
	local cc = tonumber(clean:match("(%d+)%s*[cCkK]%f[%A]")) or 0
	return (cg * 10000) + (cs * 100) + cc
end

-- Identify whether an inbox mail is an Auction House SALE payout (never outbid/expired/cancelled refund!)
function PluribusHiveTax:ClassifyAuctionMail(sender, subject, money, invoiceType, itemName)
	money = tonumber(money) or 0
	if money <= 0 then return false, nil end

	-- 1. Authoritative WoW API check: GetInboxInvoiceInfo returns "seller" ONLY for completed AH sales
	if invoiceType == "seller" then
		return true, (itemName and itemName ~= "") and itemName or subject or "AH Verkauf"
	end
	if invoiceType == "buyer" or invoiceType == "seller_temp_invoice" then
		return false, nil
	end

	-- 2. Localized EN/DE fallback when GetInboxInvoiceInfo is unavailable on custom/Classic servers
	local sLow = tostring(sender or ""):lower()
	local subjLow = tostring(subject or ""):lower()
	local isAhSender = sLow:find("auction house", 1, true)
		or sLow:find("auktionshaus", 1, true)
		or sLow:find("blackwater", 1, true)
		or sLow:find("schwarzmeer", 1, true)
	if not isAhSender then return false, nil end

	-- Explicitly exclude outbid refunds, expired auctions, cancelled auctions
	if subjLow:find("outbid", 1, true)
		or subjLow:find("überboten", 1, true)
		or subjLow:find("ueberboten", 1, true)
		or subjLow:find("expired", 1, true)
		or subjLow:find("abgelaufen", 1, true)
		or subjLow:find("cancelled", 1, true)
		or subjLow:find("canceled", 1, true)
		or subjLow:find("abgebrochen", 1, true)
		or subjLow:find("storniert", 1, true)
	then
		return false, nil
	end

	local isSaleSubject = subjLow:find("auction successful", 1, true)
		or subjLow:find("auktion erfolgreich", 1, true)
		or subjLow:find("sold", 1, true)
		or subjLow:find("verkauft", 1, true)
	if isSaleSubject then
		local extracted = tostring(subject or ""):match(":%s*(.+)$") or itemName or subject or "AH Verkauf"
		return true, extracted
	end
	return false, nil
end

function PluribusHiveTax:InspectInboxMail(index)
	if not index or not GetInboxHeaderInfo then return nil end
	local ok, _, _, sender, subject, money, codAmount = pcall(GetInboxHeaderInfo, index)
	if not ok then return nil end
	money = tonumber(money) or 0
	if money <= 0 or (tonumber(codAmount) or 0) > 0 then
		return { index = index, isAhSale = false, money = money, sender = sender, subject = subject }
	end
	local invoiceType, itemName = nil, nil
	if GetInboxInvoiceInfo then
		local okInv, iType, iName = pcall(GetInboxInvoiceInfo, index)
		if okInv then
			invoiceType, itemName = iType, iName
		end
	end
	local isAhSale, label = self:ClassifyAuctionMail(sender, subject, money, invoiceType, itemName)
	return {
		index = index,
		isAhSale = isAhSale,
		money = money,
		itemName = label or itemName or subject or "AH Verkauf",
		sender = sender,
		subject = subject,
	}
end

function PluribusHiveTax:SnapshotInbox()
	local snap = {}
	local totalAhCopper = 0
	local numItems = (GetInboxNumItems and select(1, GetInboxNumItems())) or 0
	for i = 1, numItems do
		local info = self:InspectInboxMail(i)
		if info then
			snap[i] = info
			if info.isAhSale and info.money > 0 then
				totalAhCopper = totalAhCopper + info.money
			end
		end
	end
	self._inboxSnapshot = snap
	return totalAhCopper
end

function PluribusHiveTax:HandleInboxMoneyCollected(mailIndex)
	local pol = self:GetPolicy()
	if not pol.enabled or not pol.taxAuctionSales then return end
	local idx = tonumber(mailIndex)
	if not idx or idx <= 0 then return end

	-- Prefer pre-loot snapshot (in case TakeInboxMoney already mutated the slot) or inspect live
	local info = (self._inboxSnapshot and self._inboxSnapshot[idx]) or self:InspectInboxMail(idx)
	if not info or not info.isAhSale or (info.money or 0) <= 0 or info._taxed then
		-- Fallback: re-inspect live in case snapshot was stale
		local live = self:InspectInboxMail(idx)
		if live and live.isAhSale and live.money > 0 and (not info or not info._taxed) then
			info = live
		else
			return
		end
	end

	info._taxed = true
	local now = (GetTime and GetTime()) or 0
	if (now - (self._recentTaxedMailAt or 0)) > 2.0 then
		self._recentTaxedMailCopper = 0
	end
	self._recentTaxedMailCopper = (self._recentTaxedMailCopper or 0) + info.money
	self._recentTaxedMailAt = now
	self._prevAhSaleTotal = math.max(0, (self._prevAhSaleTotal or 0) - info.money)

	self:RecordTaxableIncome(info.money, "AH Verkauf: " .. tostring(info.itemName or "Auktion"))
end

function PluribusHiveTax:Initialize()
	if self.initialized then return end
	self.initialized = true
	EnsureTaxDB()
	self:GetMyRecord()

	-- Receive guild tax policy updates from officers / guild master
	PluribusHive:RegisterHandler("TAXCFG", function(sender, body)
		local en, rate, lootF, questF, ahF, flatC, banker, ts, vendorF =
			body:match("^(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|([^|]*)|?([^|]*)|?(.*)$")
		if not en then return end
		local pol = PluribusHiveTax:GetPolicy()
		local incomingTs = tonumber(ts) or time()
		if incomingTs >= (pol.updatedAt or 0) then
			pol.enabled = (en == "1")
			pol.ratePct = math.max(0, math.min(50, tonumber(rate) or 10))
			pol.taxLootGold = (lootF == "1")
			pol.taxQuestGold = (questF == "1")
			pol.taxAuctionSales = (ahF == "1")
			if vendorF and vendorF ~= "" then
				pol.taxVendorSales = (vendorF == "1")
			end
			pol.weeklyFlatCopper = tonumber(flatC) or 0
			pol.bankerName = PluribusHive:NormalizeName(banker or "")
			pol.updatedAt = incomingTs
			pol.updatedBy = sender
			PluribusHiveTax:RefreshGuildBankTaxBar()
			PluribusHiveTax:NotifyTaxChanged()
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

	-- Auto-detect AH sale gold collected via Blizzard Mailbox, Shift-Click, Open All Mail, or Mail Addons!
	if hooksecurefunc then
		if _G.TakeInboxMoney then
			pcall(hooksecurefunc, "TakeInboxMoney", function(mailIndex)
				PluribusHiveTax:HandleInboxMoneyCollected(mailIndex)
			end)
		end
		if _G.AutoLootMailItem then
			pcall(hooksecurefunc, "AutoLootMailItem", function(mailIndex)
				PluribusHiveTax:HandleInboxMoneyCollected(mailIndex)
			end)
		end
	end

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

	-- Auto-detect manual gold deposits into the Guild Bank via hooksecurefunc("DepositGuildBankMoney")
	if hooksecurefunc and _G.DepositGuildBankMoney then
		pcall(hooksecurefunc, "DepositGuildBankMoney", function(copper)
			if PluribusHiveTax._depositingViaButton then return end
			local deposited = math.floor(tonumber(copper) or 0)
			if deposited <= 0 then return end
			local due = PluribusHiveTax:GetBalanceDue()
			if due > 0 then
				local credited = math.min(deposited, due)
				PluribusHiveTax:RecordPayment(credited, "Gildenbank (Manuell)")
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

	-- Track AH mailbox income, looted gold, quest gold, vendor sales, banker trades, and Guild Bank UI automatically
	local f = CreateFrame("Frame")
	for _, ev in ipairs({
		"PLAYER_ENTERING_WORLD",
		"PLAYER_MONEY",
		"CHAT_MSG_MONEY",
		"CHAT_MSG_SYSTEM",
		"LOOT_OPENED",
		"LOOT_READY",
		"LOOT_CLOSED",
		"MAIL_SHOW",
		"MAIL_INBOX_UPDATE",
		"MAIL_CLOSED",
		"MERCHANT_SHOW",
		"MERCHANT_CLOSED",
		"QUEST_PROGRESS",
		"QUEST_COMPLETE",
		"QUEST_TURNED_IN",
		"TRADE_SHOW",
		"TRADE_MONEY_CHANGED",
		"TRADE_ACCEPT_UPDATE",
		"GUILDBANKFRAME_OPENED",
		"GUILDBANKFRAME_CLOSED",
		"ADDON_LOADED",
	}) do
		pcall(f.RegisterEvent, f, ev)
	end
	f:SetScript("OnEvent", function(_, ev, arg1, arg2, arg3)
		local now = (GetTime and GetTime()) or 0
		if ev == "PLAYER_ENTERING_WORLD" then
			PluribusHiveTax.lastMoney = GetMoney and GetMoney() or 0
			PluribusHiveTax:AttachToGuildBank()
			if C_Timer and C_Timer.After then
				C_Timer.After(8, function() PluribusHiveTax:BroadcastMyLedger() end)
			end
		elseif ev == "ADDON_LOADED" and arg1 == "Blizzard_GuildBankUI" then
			PluribusHiveTax:AttachToGuildBank()
		elseif ev == "GUILDBANKFRAME_OPENED" then
			PluribusHiveTax.guildBankOpen = true
			PluribusHiveTax:AttachToGuildBank()
			if PluribusHiveTax.guildBankBar then
				PluribusHiveTax.guildBankBar:Show()
				PluribusHiveTax:RefreshGuildBankTaxBar()
			end
		elseif ev == "GUILDBANKFRAME_CLOSED" then
			PluribusHiveTax.guildBankOpen = false
			if PluribusHiveTax.guildBankBar then
				PluribusHiveTax.guildBankBar:Hide()
			end
		elseif ev == "LOOT_OPENED" or ev == "LOOT_READY" then
			PluribusHiveTax.inLootWindow = true
		elseif ev == "LOOT_CLOSED" then
			PluribusHiveTax.inLootWindow = false
			PluribusHiveTax.lastLootClosedAt = now
		elseif ev == "MERCHANT_SHOW" then
			PluribusHiveTax.merchantOpen = true
		elseif ev == "MERCHANT_CLOSED" then
			PluribusHiveTax.merchantOpen = false
		elseif ev == "MAIL_SHOW" then
			PluribusHiveTax.mailOpen = true
			PluribusHiveTax._prevAhSaleTotal = PluribusHiveTax:SnapshotInbox()
		elseif ev == "MAIL_INBOX_UPDATE" then
			if PluribusHiveTax.mailOpen or (_G.MailFrame and _G.MailFrame.IsShown and _G.MailFrame:IsShown()) then
				PluribusHiveTax.mailOpen = true
				local prevTotal = PluribusHiveTax._prevAhSaleTotal or 0
				local newTotal = PluribusHiveTax:SnapshotInbox()
				-- Safety net: if AH sale mails disappeared via an addon/API that bypassed TakeInboxMoney hook
				local pol = PluribusHiveTax:GetPolicy()
				if pol.enabled and pol.taxAuctionSales and prevTotal > newTotal then
					local diff = prevTotal - newTotal
					local recentHooked = ((now - (PluribusHiveTax._recentTaxedMailAt or 0)) <= 2.0) and (PluribusHiveTax._recentTaxedMailCopper or 0) or 0
					if diff > recentHooked and PluribusHiveTax._lastMailMoneyGainAt and (now - PluribusHiveTax._lastMailMoneyGainAt) <= 2.0 then
						local untaxed = diff - recentHooked
						PluribusHiveTax._recentTaxedMailCopper = recentHooked + untaxed
						PluribusHiveTax._recentTaxedMailAt = now
						PluribusHiveTax:RecordTaxableIncome(untaxed, "AH Verkauf (Post)")
					end
				end
				PluribusHiveTax._prevAhSaleTotal = newTotal
			end
		elseif ev == "MAIL_CLOSED" then
			PluribusHiveTax.mailOpen = false
			PluribusHiveTax._inboxSnapshot = {}
			PluribusHiveTax._prevAhSaleTotal = 0
		elseif ev == "QUEST_PROGRESS" or ev == "QUEST_COMPLETE" then
			if GetRewardMoney then
				local ok, reward = pcall(GetRewardMoney)
				if ok and tonumber(reward) and tonumber(reward) > 0 then
					PluribusHiveTax._pendingQuestRewardCopper = tonumber(reward)
				end
			end
		elseif ev == "QUEST_TURNED_IN" then
			local pol = PluribusHiveTax:GetPolicy()
			local moneyReward = tonumber(arg3) or 0
			if moneyReward <= 0 and (PluribusHiveTax._pendingQuestRewardCopper or 0) > 0 then
				moneyReward = PluribusHiveTax._pendingQuestRewardCopper
			end
			PluribusHiveTax._pendingQuestRewardCopper = 0
			PluribusHiveTax._questTurnedInAt = now
			if pol.enabled and pol.taxQuestGold and moneyReward > 0 then
				PluribusHiveTax._recentTaxedQuestCopper = moneyReward
				PluribusHiveTax._recentTaxedQuestAt = now
				PluribusHiveTax:RecordTaxableIncome(moneyReward, "Quest-Belohnung")
			end
		elseif ev == "CHAT_MSG_MONEY" then
			local pol = PluribusHiveTax:GetPolicy()
			if pol.enabled and pol.taxLootGold then
				local copper = ParseLootCopper(arg1)
				if copper > 0 then
					PluribusHiveTax._recentTaxedLootCopper = copper
					PluribusHiveTax._recentTaxedLootAt = now
					PluribusHiveTax:RecordTaxableIncome(copper, "Loot Gold")
				end
			end
		elseif ev == "CHAT_MSG_SYSTEM" then
			-- Classic fallback: "Received 1 Gold, 25 Silver." / "Ihr erhaltet 1 Gold, 25 Silber." on quest turn-in
			local pol = PluribusHiveTax:GetPolicy()
			if pol.enabled and pol.taxQuestGold and type(arg1) == "string" then
				local low = arg1:lower()
				if (low:find("received ", 1, true) or low:find("ihr erhaltet ", 1, true))
					and (now - (PluribusHiveTax._questTurnedInAt or 0)) <= 2.0
					and (now - (PluribusHiveTax._recentTaxedQuestAt or 0)) > 1.5
				then
					local copper = ParseLootCopper(arg1)
					if copper > 0 then
						PluribusHiveTax._recentTaxedQuestCopper = copper
						PluribusHiveTax._recentTaxedQuestAt = now
						PluribusHiveTax:RecordTaxableIncome(copper, "Quest-Belohnung")
					end
				end
			end
		elseif ev == "PLAYER_MONEY" then
			local curMoney = (GetMoney and GetMoney()) or 0
			local prevMoney = PluribusHiveTax.lastMoney
			PluribusHiveTax.lastMoney = curMoney

			if prevMoney ~= nil and curMoney > prevMoney then
				local delta = curMoney - prevMoney
				local pol = PluribusHiveTax:GetPolicy()

				if PluribusHiveTax.mailOpen or (_G.MailFrame and _G.MailFrame.IsShown and _G.MailFrame:IsShown()) then
					PluribusHiveTax.mailOpen = true
					PluribusHiveTax._lastMailMoneyGainAt = now
					-- If our TakeInboxMoney/AutoLootMailItem hook didn't fire (e.g. C-level Open All), match against snapshotted AH sale mails!
					if pol.enabled and pol.taxAuctionSales then
						local recentlyCovered = ((now - (PluribusHiveTax._recentTaxedMailAt or 0)) <= 1.5) and (PluribusHiveTax._recentTaxedMailCopper or 0) or 0
						if recentlyCovered >= delta then
							PluribusHiveTax._recentTaxedMailCopper = recentlyCovered - delta
						else
							-- Check if an untaxed AH sale mail in our snapshot matches this exact payout
							local matched = nil
							for _, m in pairs(PluribusHiveTax._inboxSnapshot or {}) do
								if m.isAhSale and not m._taxed and m.money == delta then
									matched = m
									break
								end
							end
							if matched then
								matched._taxed = true
								PluribusHiveTax._recentTaxedMailAt = now
								PluribusHiveTax._recentTaxedMailCopper = 0
								PluribusHiveTax._prevAhSaleTotal = math.max(0, (PluribusHiveTax._prevAhSaleTotal or 0) - delta)
								PluribusHiveTax:RecordTaxableIncome(delta, "AH Verkauf: " .. tostring(matched.itemName or "Auktion"))
							end
						end
					end
				elseif pol.enabled and pol.taxQuestGold
					and (now - (PluribusHiveTax._questTurnedInAt or 0)) <= 1.2
					and (now - (PluribusHiveTax._recentTaxedQuestAt or 0)) > 1.2
				then
					PluribusHiveTax._recentTaxedQuestAt = now
					PluribusHiveTax._recentTaxedQuestCopper = delta
					PluribusHiveTax:RecordTaxableIncome(delta, "Quest-Belohnung")
				elseif pol.enabled and pol.taxLootGold
					and (PluribusHiveTax.inLootWindow or (now - (PluribusHiveTax.lastLootClosedAt or 0)) <= 1.0)
					and not PluribusHiveTax.merchantOpen and not PluribusHiveTax.guildBankOpen
				then
					-- Fallback when CHAT_MSG_MONEY didn't fire or used an unrecognized locale string
					local recentlyCovered = ((now - (PluribusHiveTax._recentTaxedLootAt or 0)) <= 1.2) and (PluribusHiveTax._recentTaxedLootCopper or 0) or 0
					if recentlyCovered >= delta then
						PluribusHiveTax._recentTaxedLootCopper = recentlyCovered - delta
					elseif delta > recentlyCovered then
						local untaxed = delta - recentlyCovered
						PluribusHiveTax._recentTaxedLootAt = now
						PluribusHiveTax._recentTaxedLootCopper = 0
						PluribusHiveTax:RecordTaxableIncome(untaxed, "Loot Gold")
					end
				elseif pol.enabled and pol.taxVendorSales and PluribusHiveTax.merchantOpen then
					PluribusHiveTax:RecordTaxableIncome(delta, "Händler-Verkauf")
				end
			end

			if PluribusHiveTax.guildBankBar and PluribusHiveTax.guildBankBar:IsShown() then
				PluribusHiveTax:RefreshGuildBankTaxBar()
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
