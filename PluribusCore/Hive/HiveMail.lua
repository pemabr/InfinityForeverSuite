-- PluribusHive In-Addon Guild Mail & Letter System
-- Lets players write in-addon messages (delivered live or queued until recipient comes online via PLBHIVE)
-- AND pre-fill real WoW Mailbox letters directly from anywhere (Crafters Directory, Surplus Mats, Tax, Guild Hub)

PluribusHiveMail = {
	initialized = false,
	composerFrame = nil,
}
_G.PluribusHiveMail = PluribusHiveMail

local function EnsureMailDB()
	local db = PluribusHive:GetDB()
	db.mail = db.mail or {}
	db.mail.inbox = db.mail.inbox or {}
	db.mail.sent = db.mail.sent or {}
	db.mail.outbox = db.mail.outbox or {} -- queued for offline peers; delivered when they come online
	return db.mail
end

local function SanitizeField(str, maxLen)
	local s = tostring(str or ""):gsub("[\t\r\n|]", " "):match("^%s*(.-)%s*$") or ""
	if maxLen and #s > maxLen then
		s = s:sub(1, maxLen)
	end
	return s
end

function PluribusHiveMail:GetInbox()
	local m = EnsureMailDB()
	table.sort(m.inbox, function(a, b) return (a.sentAt or 0) > (b.sentAt or 0) end)
	return m.inbox
end

function PluribusHiveMail:GetSent()
	local m = EnsureMailDB()
	table.sort(m.sent, function(a, b) return (a.sentAt or 0) > (b.sentAt or 0) end)
	return m.sent
end

function PluribusHiveMail:GetUnreadCount()
	local m = EnsureMailDB()
	local count = 0
	for _, msg in ipairs(m.inbox) do
		if not msg.read then count = count + 1 end
	end
	return count
end

function PluribusHiveMail:MarkRead(msgID)
	local m = EnsureMailDB()
	for _, msg in ipairs(m.inbox) do
		if msg.id == msgID then
			msg.read = true
			return true
		end
	end
	return false
end

function PluribusHiveMail:DeleteMessage(msgID, fromSent)
	local m = EnsureMailDB()
	local list = fromSent and m.sent or m.inbox
	for i = #list, 1, -1 do
		if list[i].id == msgID then
			table.remove(list, i)
			return true
		end
	end
	return false
end

-- Send an in-addon Guild Message (delivered instantly if recipient is online, or queued & auto-delivered on next sync)
function PluribusHiveMail:SendAddonMessage(recipient, subject, body, opts)
	recipient = PluribusHive:NormalizeName(recipient)
	if recipient == "" then return false, "Recipient name is required." end
	subject = SanitizeField(subject ~= "" and subject or "Guild Note", 64)
	body = SanitizeField(body, 320)
	if body == "" then return false, "Message body cannot be empty." end
	opts = opts or {}

	local me = PluribusHive:GetPlayerShortName()
	local now = time()
	local id = string.format("%s-%d-%d", me:sub(1, 6), now, math.random(100, 999))
	local itemID = tonumber(opts.itemID) or 0
	local recipeName = SanitizeField(opts.recipeName or "", 48)

	local record = {
		id = id,
		from = me,
		to = recipient,
		subject = subject,
		body = body,
		itemID = itemID,
		recipeName = recipeName,
		sentAt = now,
		delivered = false,
		read = true,
	}

	local m = EnsureMailDB()
	table.insert(m.sent, 1, record)
	while #m.sent > 80 do table.remove(m.sent) end

	-- Self-note shortcut for personal notes / testing
	if PluribusHive:SamePlayer(recipient, me) then
		table.insert(m.inbox, 1, {
			id = id,
			from = me,
			to = me,
			subject = subject,
			body = body,
			itemID = itemID,
			recipeName = recipeName,
			sentAt = now,
			read = false,
		})
		record.delivered = true
		return true, "Saved note to your Inbox."
	end

	local payload = string.format("%s|%s|%s|%s|%d|%s|%d",
		id, recipient, subject, body, itemID, recipeName, now
	)

	-- Queue for guaranteed delivery even if recipient is currently offline
	m.outbox[id] = {
		id = id,
		to = recipient,
		payload = payload,
		sentAt = now,
		attempts = 1,
	}

	-- Broadcast over PLBHIVE GUILD channel (and WHISPER channel if supported) so online recipient receives immediately
	local sent = PluribusHive:Send("MAIL", payload, "GUILD", nil, true)
	if sent then
		PluribusHive:AddFeedEvent("MAIL", string.format("Sent message to %s: %s", recipient, subject))
	end
	return true, "Message sent via Pluribus Guild Mail (auto-delivers if offline)."
end

-- Pre-fill WoW's native SendMailFrame (or instruct player if not currently standing at a mailbox)
function PluribusHiveMail:PrefillWoWLetter(recipient, subject, body, copperAmount)
	recipient = PluribusHive:NormalizeName(recipient)
	if recipient == "" then return false, "Recipient name is required." end

	if _G.MailFrame and _G.MailFrame:IsShown() then
		if _G.MailFrameTab2 and _G.MailFrameTab2.Click then
			pcall(function() _G.MailFrameTab2:Click() end)
		end
		if _G.SendMailNameEditBox then pcall(_G.SendMailNameEditBox.SetText, _G.SendMailNameEditBox, recipient) end
		if _G.SendMailSubjectEditBox then pcall(_G.SendMailSubjectEditBox.SetText, _G.SendMailSubjectEditBox, tostring(subject or "")) end
		if _G.SendMailBodyEditBox then pcall(_G.SendMailBodyEditBox.SetText, _G.SendMailBodyEditBox, tostring(body or "")) end
		if copperAmount and copperAmount > 0 and _G.MoneyInputFrame_SetCopper and _G.SendMailMoney then
			pcall(_G.MoneyInputFrame_SetCopper, _G.SendMailMoney, math.floor(copperAmount))
		end
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("|cff4ade80Filled WoW Mailbox letter to " .. recipient .. "! Review & click Send.|r", 3.5)
		end
		return true, "Filled WoW Mailbox letter."
	end

	-- Save as pending mailbox draft so the moment the player opens any mailbox, it can be filled in 1 click!
	local m = EnsureMailDB()
	m.pendingWoWLetter = {
		to = recipient,
		subject = subject or "",
		body = body or "",
		copper = tonumber(copperAmount) or 0,
		createdAt = time(),
	}
	if _G.PluribusUIFramework then
		_G.PluribusUIFramework:ShowNotification("|cfffbbf24Draft saved for " .. recipient .. "! Open any Mailbox to auto-fill your WoW letter.|r", 4)
	end
	return false, "Saved WoW Letter draft — open a Mailbox to auto-fill."
end

-- Flush any queued outbox messages for a recipient who just came online
function PluribusHiveMail:FlushOutboxFor(peerName)
	local m = EnsureMailDB()
	local now = time()
	for id, q in pairs(m.outbox or {}) do
		if (now - (q.sentAt or 0)) > (7 * 86400) then
			m.outbox[id] = nil
		elseif not peerName or PluribusHive:SamePlayer(q.to, peerName) then
			PluribusHive:Send("MAIL", q.payload, "GUILD")
			q.attempts = (q.attempts or 0) + 1
		end
	end
end

-- Graphical Composer Modal (Send In-Addon Message, Prefill WoW Mailbox Letter, or Whisper)
function PluribusHiveMail:OpenComposer(recipient, subject, body, opts)
	local UI = _G.PluribusUIFramework
	if not UI then return end
	opts = opts or {}

	if not self.composerFrame then
		local f = UI:CreateFrame("PluribusMailComposerFrame", UIParent, 460, 344, "Write Guild Message / Letter", "In-Addon Mail & WoW Mailbox")
		f:SetPoint("CENTER")

		local banner = UI:CreateBannerCard(f, 436, 46, "Interface\\Icons\\INV_Letter_15",
			"|cfffbbf24Guild Mail & Craft Request|r",
			"Send instantly in-addon (even if offline) or pre-fill a real WoW Mailbox letter.",
			0.92, 0.72, 0.22)
		banner:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -46)

		local toLbl = UI:CreateLabel(f, "Recipient:", 0.78, 0.86, 0.94)
		toLbl:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -104)
		local toBox = UI:CreateInputBox(f, 180, 24)
		toBox:SetPoint("LEFT", toLbl, "RIGHT", 8, 0)
		f.toBox = toBox

		local subjLbl = UI:CreateLabel(f, "Subject:", 0.78, 0.86, 0.94)
		subjLbl:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -136)
		local subjBox = UI:CreateInputBox(f, 344, 24)
		subjBox:SetPoint("LEFT", subjLbl, "RIGHT", 18, 0)
		f.subjBox = subjBox

		local bodyLbl = UI:CreateLabel(f, "Message:", 0.78, 0.86, 0.94)
		bodyLbl:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -168)

		local bodyHolder = UI:CreateCard(f, 434, 96)
		bodyHolder:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -186)

		local bodyBox = CreateFrame("EditBox", nil, bodyHolder)
		bodyBox:SetMultiLine(true)
		bodyBox:SetAutoFocus(false)
		bodyBox:SetFontObject("ChatFontNormal")
		bodyBox:SetPoint("TOPLEFT", bodyHolder, "TOPLEFT", 8, -8)
		bodyBox:SetPoint("BOTTOMRIGHT", bodyHolder, "BOTTOMRIGHT", -8, 8)
		bodyBox:SetMaxLetters(320)
		bodyBox:SetScript("OnEscapePressed", function(sb) sb:ClearFocus() end)
		bodyBox:SetScript("OnMouseDown", function(sb) UI:BringOwnerToFront(sb) end)
		f.bodyBox = bodyBox

		local statusLbl = UI:CreateLabel(f, "", 0.65, 0.82, 0.94, "GameFontHighlightSmall")
		statusLbl:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -288)
		f.statusLbl = statusLbl

		local sendAddonBtn = UI:CreateButton(f, "Send Addon Message", 148, 26, function()
			local ok, msg = PluribusHiveMail:SendAddonMessage(f.toBox:GetText(), f.subjBox:GetText(), f.bodyBox:GetText(), f._opts)
			if ok then
				UI:ShowNotification("|cff4ade80" .. msg .. "|r", 3)
				f:Hide()
				if _G.PluribusMainWindow and _G.PluribusMainWindow:IsVisible() and _G.PluribusMainFrame and _G.PluribusMainFrame.currentTab == "Guild Mail" then
					_G.PluribusMainFrame:ShowTab(_G.PluribusMainWindow, "Guild Mail")
				end
			else
				f.statusLbl:SetText("|cfff87171" .. tostring(msg) .. "|r")
			end
		end, true)
		sendAddonBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)

		local wowLetterBtn = UI:CreateButton(f, "Write WoW Letter", 136, 26, function()
			local _, msg = PluribusHiveMail:PrefillWoWLetter(f.toBox:GetText(), f.subjBox:GetText(), f.bodyBox:GetText(), f._opts and f._opts.copper)
			f.statusLbl:SetText("|cfffbbf24" .. tostring(msg) .. "|r")
		end)
		wowLetterBtn:SetPoint("LEFT", sendAddonBtn, "RIGHT", 8, 0)

		local whisperBtn = UI:CreateButton(f, "Whisper", 82, 26, function()
			local target = PluribusHive:NormalizeName(f.toBox:GetText())
			local txt = SanitizeField(f.bodyBox:GetText(), 220)
			if target ~= "" and txt ~= "" and SendChatMessage then
				pcall(SendChatMessage, txt, "WHISPER", nil, target)
				UI:ShowNotification("|cff38bdf8Whispered " .. target .. "|r", 2.5)
				f:Hide()
			elseif target ~= "" and ChatFrame_SendTell then
				pcall(ChatFrame_SendTell, target)
			end
		end)
		whisperBtn:SetPoint("LEFT", wowLetterBtn, "RIGHT", 8, 0)

		self.composerFrame = f
	end

	local f = self.composerFrame
	f._opts = opts
	f.toBox:SetText(PluribusHive:NormalizeName(recipient or ""))
	f.subjBox:SetText(tostring(subject or ""))
	f.bodyBox:SetText(tostring(body or ""))
	f.statusLbl:SetText(opts.copper and opts.copper > 0 and ("|cfffbbf24Includes " .. PluribusUtils:FormatGold(opts.copper) .. " when sent at Mailbox|r") or "")
	f:Show()
	UI:BringToFront(f)
end

-- Attach a Guild Mail side tab onto WoW's native Mailbox frame so drafts & guild messages appear right at the mailbox
function PluribusHiveMail:AttachToMailFrame()
	local host = _G.MailFrame
	if not host or host._plbMailAttached or not _G.PluribusUIFramework then return end
	if _G.PluribusHive and _G.PluribusHive:GetConfig().attachSideTabs == false then return end
	host._plbMailAttached = true

	local UI = _G.PluribusUIFramework
	local tab = UI:CreateSideTab(host, 1, {
		icon = "Interface\\Icons\\INV_Letter_15",
		title = "Pluribus Guild Mail & Drafts",
		tooltip = "Open Guild Mail inbox or auto-fill your saved Pluribus WoW Letter / Tax Payment.",
		yOffset = -56,
		onClick = function()
			local m = EnsureMailDB()
			if m.pendingWoWLetter then
				local d = m.pendingWoWLetter
				PluribusHiveMail:PrefillWoWLetter(d.to, d.subject, d.body, d.copper)
				m.pendingWoWLetter = nil
			elseif _G.PluribusMainFrame then
				_G.PluribusMainFrame:OpenToTab("Guild Mail")
			end
		end,
	})
	host._plbMailTab = tab

	if host.HookScript then
		pcall(host.HookScript, host, "OnShow", function()
			local m = EnsureMailDB()
			if tab then
				local badge = PluribusHiveMail:GetUnreadCount() + (m.pendingWoWLetter and 1 or 0)
				tab:SetBadge(badge, 0.85, 0.62, 0.14)
			end
			if m.pendingWoWLetter then
				local d = m.pendingWoWLetter
				if C_Timer and C_Timer.After then
					C_Timer.After(0.25, function()
						if _G.MailFrame and _G.MailFrame:IsShown() and m.pendingWoWLetter then
							PluribusHiveMail:PrefillWoWLetter(d.to, d.subject, d.body, d.copper)
							m.pendingWoWLetter = nil
						end
					end)
				end
			end
		end)
	end
end

function PluribusHiveMail:Initialize()
	if self.initialized then return end
	self.initialized = true
	EnsureMailDB()

	-- Receive incoming in-addon Guild Mail
	PluribusHive:RegisterHandler("MAIL", function(sender, body)
		local id, toName, subject, msgBody, itemStr, recipeName, tsStr =
			body:match("^([^|]+)|([^|]+)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|?(.*)$")
		if not id or not toName then return end
		local me = PluribusHive:GetPlayerShortName()
		if not PluribusHive:SamePlayer(toName, me) then return end

		local m = EnsureMailDB()
		for _, existing in ipairs(m.inbox) do
			if existing.id == id then
				-- Duplicate delivery — still ACK so sender clears outbox
				PluribusHive:Send("MAILACK", id, "GUILD")
				return
			end
		end

		table.insert(m.inbox, 1, {
			id = id,
			from = sender,
			to = me,
			subject = subject ~= "" and subject or "Guild Note",
			body = msgBody or "",
			itemID = tonumber(itemStr) or 0,
			recipeName = recipeName or "",
			sentAt = tonumber(tsStr) or time(),
			read = false,
		})
		while #m.inbox > 100 do table.remove(m.inbox) end

		PluribusHive:Send("MAILACK", id, "GUILD")
		PluribusHive:AddFeedEvent("MAIL", string.format("New guild message from %s: %s", sender, subject))
		if _G.PluribusUIFramework and PluribusHive:GetConfig().enableNotifications ~= false then
			_G.PluribusUIFramework:ShowNotification(string.format("|cfffbbf24New Guild Message from %s:|r %s", sender, subject), 4.5)
		end
	end)

	-- Delivery ACK from recipient
	PluribusHive:RegisterHandler("MAILACK", function(_, id)
		if not id or id == "" then return end
		local m = EnsureMailDB()
		if m.outbox[id] then
			m.outbox[id] = nil
		end
		for _, rec in ipairs(m.sent) do
			if rec.id == id then
				rec.delivered = true
				break
			end
		end
	end)

	-- Auto-deliver queued offline mail whenever a peer pings or requests sync
	if _G.PluribusMessaging then
		_G.PluribusMessaging:Subscribe("HIVE_PEER_REQUESTED_SYNC", function(peer)
			if C_Timer and C_Timer.After then
				C_Timer.After(2, function() PluribusHiveMail:FlushOutboxFor(peer) end)
			end
		end)
	end

	local f = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "MAIL_SHOW" }) do
		pcall(f.RegisterEvent, f, ev)
	end
	f:SetScript("OnEvent", function(_, ev)
		if ev == "MAIL_SHOW" then
			PluribusHiveMail:AttachToMailFrame()
		elseif ev == "PLAYER_ENTERING_WORLD" then
			PluribusHiveMail:AttachToMailFrame()
			if C_Timer and C_Timer.After then
				C_Timer.After(9, function() PluribusHiveMail:FlushOutboxFor(nil) end)
			end
		end
	end)
end

return PluribusHiveMail
