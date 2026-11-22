-- Main UI
-- DKP management interface

local InfinityDKPUI = _G.InfinityDKPUI or {}
_G.InfinityDKPUI = InfinityDKPUI

function InfinityDKPUI:Initialize()
    if self.initialized then return end
    self.frame = CreateFrame("Frame", "InfinityDKPMainFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.frame:SetSize(600, 400)
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    self.frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    self.frame:SetBackdropColor(0, 0, 0, 0.8)
    self.frame:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
    
    -- Title
    local title = self.frame:CreateFontString(nil, "ARTWORK", (GameFontBold and "GameFontBold" or "GameFontNormalLarge"))
    title:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -10)
    title:SetText("Infinity DKP Management")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() self.frame:Hide() end)
    local controls = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    controls:SetSize(110, 22)
    controls:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -40, -8)
    controls:SetText("DKP Actions")
    controls:SetScript("OnClick", function() self:ShowActions() end)
    
    -- Tabs
    local tabsFrame = CreateFrame("Frame", nil, self.frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    tabsFrame:SetSize(580, 30)
    tabsFrame:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    
    local tabs = {"Players", "Auctions", "History", "Reports"}
    for i, tabName in ipairs(tabs) do
        local selectedTab = tabName
        local tab = CreateFrame("Button", nil, tabsFrame)
        tab:SetSize(140, 25)
        tab:SetPoint("TOPLEFT", tabsFrame, "TOPLEFT", (i-1) * 145, 0)
        tab:SetNormalFontObject(GameFontNormal)
        tab:SetText(tabName)
        tab:SetNormalTexture("Interface/Buttons/UI-Panel-Button-Up")
        tab:SetPushedTexture("Interface/Buttons/UI-Panel-Button-Down")
        tab:SetScript("OnClick", function()
            self.selectedTab = selectedTab
            self:Update()
        end)
    end
    
    function InfinityDKPUI:ShowActions()
        if not _G.InfinityUIFramework then InfinityUtils:Warning("DKP controls unavailable.", "DKP"); return end
        if not self.actionsWindow then
            local frame = InfinityUIFramework:CreateListWindow("InfinityDKPActionsWindow", "DKP Actions", 800, 520)
            local fields = {
                { key = "player", label = "Player", x = 15, offset = 48, width = 105, max = 80 },
                { key = "value", label = "Value / ID", x = 180, offset = 72, width = 90, max = 30 },
                { key = "text", label = "Item / reason", x = 355, offset = 92, width = 190, max = 255 },
                { key = "seconds", label = "Time/bid", x = 650, offset = 63, width = 60, max = 10 },
            }
            self.actionFields = {}
            for _, field in ipairs(fields) do
                local label = InfinityUIFramework:CreateLabel(frame, field.label)
                label:SetPoint("TOPLEFT", field.x, -43)
                local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
                input:SetSize(field.width, 20)
                input:SetPoint("TOPLEFT", field.x + field.offset, -38)
                input:SetAutoFocus(false)
                input:SetMaxLetters(field.max)
                self.actionFields[field.key] = input
            end
            self.actionsWindow = frame
        end
        self.confirmAction, self.lastAction = nil, nil
        self:RefreshActions()
        self.actionsWindow:Show()
    end

    function InfinityDKPUI:RefreshActions()
        if not self.actionsWindow then return end
        local actions = {
            { "Add local player | Player", "add", { "player" } },
            { "Adjust local DKP | Player, Value; optional reason", "points", { "player", "value", "text?" }, true },
            { "Award local EP | Player, Value; optional reason", "ep", { "player", "value", "text?" }, true },
            { "Award local GP | Player, Value; optional reason", "gp", { "player", "value", "text?" }, true },
            { "Record DKP loot | Player, Value, Item", "spend", { "player", "value", "text" }, true },
            { "Record GP loot | Player, Value, Item", "award", { "player", "value", "text" }, true },
            { "Use DKP system", "system", { "=dkp" }, true },
            { "Use EPGP system", "system", { "=epgp" }, true },
            { "Send guild points snapshot", "sync send", {}, true },
            { "Apply guild snapshot | replaces local points", "sync apply", {}, true },
            { "Discard guild snapshot", "sync discard", {}, true },
            { "Undo last applied points snapshot", "sync undo", {}, true },
            { "Start guild auction | Value=start, Seconds, Item", "guildauction create", { "value", "seconds", "text" }, true },
            { "Bid in guild auction | Value=bid", "guildauction bid", { "value" }, true },
            { "Close guild auction", "guildauction close", {}, true },
            { "Cancel guild auction", "guildauction cancel", {}, true },
            { "Request guild auction", "guildauction sync", {} },
            { "Start local auction | Value=start, Seconds, Item", "auction create", { "value", "seconds", "text" }, true },
            { "Bid in local auction | Value=auction ID, Player, Seconds=bid", "auction bid", { "value", "player", "seconds" }, true },
            { "Close local auction | Value=auction ID", "auction close", { "value" }, true },
            { "Cancel local auction | Value=auction ID", "auction cancel", { "value" }, true },
            { "Offer guild DKP trade | Player, Value=amount", "trade offer", { "player", "value" }, true },
            { "Accept DKP trade | Player=sender, Value=trade ID", "trade accept", { "player", "value" }, true },
            { "Cancel DKP trade | Player=sender, Value=trade ID", "trade cancel", { "player", "value" }, true },
            { "Finalize DKP trade | Player=sender, Value=trade ID", "trade finalize", { "player", "value" }, true },
            { "Resend DKP trade | Value=trade ID", "trade resend", { "value" }, true },
            { "List session DKP trades in chat", "trade list", {} },
            { "Show full DKP report in chat", "report", {} },
            { "Show priority report in chat", "priority", {} },
            { "Show attendance report in chat", "attendance", {} },
            { "Show loot report in chat", "loot", {} },
            { "Show tax statistics in chat", "tax stats", {} },
            { "Enable tax whitelist", "tax whitelist mode", { "=on" }, true },
            { "Disable tax whitelist", "tax whitelist mode", { "=off" }, true },
            { "Add tax whitelist item | Value=item ID", "tax whitelist add", { "value" }, true },
            { "Remove tax whitelist item | Value=item ID", "tax whitelist remove", { "value" }, true },
            { "Clear tax whitelist", "tax whitelist clear", {}, true },
            { "Show tax whitelist in chat", "tax whitelist list", {} },
            { "Add tax blacklist item | Value=item ID", "tax blacklist add", { "value" }, true },
            { "Remove tax blacklist item | Value=item ID", "tax blacklist remove", { "value" }, true },
            { "Clear tax blacklist", "tax blacklist clear", {}, true },
            { "Show tax blacklist in chat", "tax blacklist list", {} },
            { "Show donation statistics in chat", "donations", {} },
            { "Enable donation whitelist", "donations whitelist mode", { "=on" }, true },
            { "Disable donation whitelist", "donations whitelist mode", { "=off" }, true },
            { "Add donation whitelist item | Value=item ID", "donations whitelist add", { "value" }, true },
            { "Remove donation whitelist item | Value=item ID", "donations whitelist remove", { "value" }, true },
            { "Clear donation whitelist", "donations whitelist clear", {}, true },
            { "Show donation whitelist in chat", "donations whitelist list", {} },
            { "Add donation blacklist item | Value=item ID", "donations blacklist add", { "value" }, true },
            { "Remove donation blacklist item | Value=item ID", "donations blacklist remove", { "value" }, true },
            { "Clear donation blacklist", "donations blacklist clear", {}, true },
            { "Show donation blacklist in chat", "donations blacklist list", {} },
        }
        local rows = {}
        local pending = _G.InfinityDKPGuildSync and InfinityDKPGuildSync.pending
        if _G.issecretvalue and _G.issecretvalue(pending) then pending = nil end
        self.displayedPending = pending
        if type(pending) == "table" and not (_G.issecretvalue and (issecretvalue(pending.sender)
            or issecretvalue(pending.count) or issecretvalue(pending.system)))
            and type(pending.sender) == "string" and type(pending.count) == "number" and type(pending.system) == "string" then
            rows[#rows + 1] = { text = "Pending snapshot: " .. pending.sender .. " | " .. pending.count .. " players | " .. pending.system }
        else
            rows[#rows + 1] = { text = "No guild points snapshot pending." }
        end
        rows[#rows + 1] = { text = "DKP tax/donation filters are local; no automatic bank processing." }
        rows[#rows + 1] = { text = "Open DKP tax and donation configuration", onClick = function() self:ShowTaxConfiguration() end }
        rows[#rows + 1] = { text = "Open live guild bank log", onClick = function() self:ShowGuildBankLog() end }
        rows[#rows + 1] = { text = "Open copyable DKP reports", onClick = function() self:ShowReport("full") end }
        rows[#rows + 1] = { text = "Configure local boss kill awards", onClick = function() self:ShowBossAwards() end }
        rows[#rows + 1] = { text = "Open local loot refunds", onClick = function() self:ShowRefunds() end }
        rows[#rows + 1] = { text = "Open local point transactions", onClick = function() self:ShowPointHistory() end }
        local trading = _G.InfinityDKPPlayerTrading
        if trading and trading.initialized and type(trading.Prune) == "function" and type(trading.offers) == "table" then
            trading:Prune()
            local offers = {}
            for _, offer in pairs(trading.offers) do
                if not (_G.issecretvalue and issecretvalue(offer)) and type(offer) == "table"
                    and not (_G.issecretvalue and (issecretvalue(offer.from)
                    or issecretvalue(offer.recipient) or issecretvalue(offer.token)
                    or issecretvalue(offer.amount) or issecretvalue(offer.status)))
                    and type(offer.from) == "string" and type(offer.recipient) == "string"
                    and type(offer.token) == "string" and type(offer.amount) == "number"
                    and type(offer.status) == "string" then
                    offers[#offers + 1] = offer
                end
            end
            table.sort(offers, function(a, b) return a.token < b.token end)
            for _, entry in ipairs(offers) do
                local offer = entry
                local status, amount, recipient = offer.status, offer.amount, offer.recipient
                rows[#rows + 1] = { text = "Trade: " .. offer.from .. " -> " .. offer.recipient
                    .. " | " .. offer.amount .. " DKP | " .. offer.status .. " | " .. offer.token
                    .. " | click to fill fields", onClick = function()
                    if trading:Find(offer.from, offer.token) ~= offer or offer.status ~= status
                        or offer.amount ~= amount or offer.recipient ~= recipient then
                        self.confirmAction = nil
                        self:RefreshActions()
                        InfinityUtils:Warning("Trade expired or changed. Review the list.", "DKP")
                        return
                    end
                    self.confirmAction = nil
                    self.actionFields.player:SetText(offer.from)
                    self.actionFields.value:SetText(offer.token)
                    self.actionsWindow.status:SetText("Trade fields filled. Choose accept, cancel, finalize or resend.")
                end }
            end
        end
        for _, action in ipairs(actions) do
            local item = action
            rows[#rows + 1] = { text = item[1] .. (item[4] and " | confirm twice" or ""), onClick = function()
                if self.lastAction ~= item[1] then self.confirmAction = nil end
                self.lastAction = item[1]
                local currentPending = _G.InfinityDKPGuildSync and InfinityDKPGuildSync.pending
                if _G.issecretvalue and _G.issecretvalue(currentPending) then currentPending = nil end
                if item[2] == "sync apply" and currentPending ~= self.displayedPending then
                    self.confirmAction = nil
                    self:RefreshActions()
                    InfinityUtils:Warning("Pending snapshot changed. Review it before applying.", "DKP")
                    return
                end
                local parts = {}
                for _, field in ipairs(item[3]) do
                    if field:sub(1, 1) == "=" then
                        parts[#parts + 1] = field:sub(2)
                    else
                        local optional = field:sub(-1) == "?"
                        local key = optional and field:sub(1, -2) or field
                        local value = self.actionFields[key]:GetText()
                        if _G.issecretvalue and _G.issecretvalue(value) then
                            InfinityUtils:Warning("Protected input cannot be used.", "DKP")
                            return
                        end
                        value = type(value) == "string" and value:match("^%s*(.-)%s*$") or ""
                        if value == "" and not optional then InfinityUtils:Warning("Fill the fields required by this action.", "DKP"); return end
                        if value ~= "" then parts[#parts + 1] = value end
                    end
                end
                local input = item[2] .. (#parts > 0 and (" " .. table.concat(parts, " ")) or "")
                if item[4] and self.confirmAction ~= input then
                    self.confirmAction = input
                    self.actionsWindow.status:SetText("Confirm: " .. item[1] .. " | " .. table.concat(parts, " | ") .. " | click again.")
                    return
                end
                self.confirmAction = nil
                local registry = _G.InfinityCommandRegistry
                local callback = registry and registry:GetCommand("dkp")
                if type(callback) ~= "function" then InfinityUtils:Warning("DKP action unavailable.", "DKP"); return end
                local ok, err = pcall(callback, InfinityUtils:Split(input, " "), input)
                if not ok then
                    if _G.issecretvalue and _G.issecretvalue(err) then err = nil end
                    InfinityUtils:Error("DKP action failed: " .. tostring(err or "protected error"), "DKP")
                    return
                end
                self:Update()
                self:RefreshActions()
                if self.taxConfigWindow and self.taxConfigWindow:IsShown() then
                    self.confirmTaxConfig = nil
                    self:RefreshTaxConfiguration()
                end
            end }
        end
        self.actionsWindow.status:SetText("Enter the values requested by an action, then click it.")
        self.actionsWindow:SetItems(rows)
    end

    function InfinityDKPUI:ShowBossAwards()
        local awards = _G.InfinityBossKillAwards
        if not _G.InfinityUIFramework or not awards or type(awards.localConfig) ~= "table"
            or type(awards.SetLocalConfig) ~= "function" then
            InfinityUtils:Warning("Local boss awards unavailable.", "DKP"); return
        end
        if not self.bossAwardWindow then
            local frame = InfinityUIFramework:CreateListWindow("InfinityDKPBossAwards", "Local Boss Kill Awards", 750, 430)
            local label = InfinityUIFramework:CreateLabel(frame, "Points per kill")
            label:SetPoint("TOPLEFT", 15, -43)
            local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
            input:SetSize(100, 20)
            input:SetPoint("TOPLEFT", 120, -38)
            input:SetAutoFocus(false)
            input:SetMaxLetters(10)
            input:SetText("")
            self.bossAwardWindow, self.bossAwardAmount = frame, input
        end
        self.confirmBossAward = nil
        self:RefreshBossAwards()
        self.bossAwardWindow:Show()
    end

    function InfinityDKPUI:RefreshBossAwards()
        local awards, frame = _G.InfinityBossKillAwards, self.bossAwardWindow
        local config = awards and awards.localConfig
        if not frame or not awards or (_G.issecretvalue and issecretvalue(config)) or type(config) ~= "table"
            or (_G.issecretvalue and (issecretvalue(config.enabled) or issecretvalue(config.kind) or issecretvalue(config.amount)))
            or type(config.enabled) ~= "boolean" or (config.kind ~= "dkp" and config.kind ~= "ep")
            or type(config.amount) ~= "number" or config.amount ~= config.amount
            or config.amount < 1 or config.amount > 1000000000 or config.amount ~= math.floor(config.amount) then
            InfinityUtils:Warning("Local boss award settings unavailable or invalid.", "DKP"); return
        end
        local rows = { { text = "Current: " .. (config.enabled and "enabled" or "disabled") .. " | "
            .. config.amount .. " " .. config.kind:upper() .. " per successful encounter" } }
        for _, spec in ipairs({ { "Enable", "enabled", true }, { "Disable", "enabled", false },
            { "Use DKP", "kind", "dkp" }, { "Use EP", "kind", "ep" }, { "Set points per kill", "amount" } }) do
            local label, key, fixed = spec[1], spec[2], spec[3]
            rows[#rows + 1] = { text = label .. (key == "amount" and " | Points per kill" or "") .. " | confirm twice",
                onClick = function()
                    if type(awards.HasValidLocalConfig) ~= "function" or not awards:HasValidLocalConfig()
                        or awards.localConfig ~= config then
                        self.confirmBossAward = nil
                        InfinityUtils:Warning("Boss award settings changed; reopen the window.", "DKP"); return
                    end
                    local enabled, kind, amount = config.enabled, config.kind, config.amount
                    if key == "amount" then
                        local raw = self.bossAwardAmount:GetText()
                        if _G.issecretvalue and issecretvalue(raw) then raw = nil end
                        amount = type(raw) == "string" and tonumber(raw) or nil
                        if type(amount) ~= "number" or amount ~= amount or amount < 1 or amount > 1000000000
                            or amount ~= math.floor(amount) then
                            self.confirmBossAward = nil
                            InfinityUtils:Warning("Enter a positive whole points amount.", "DKP"); return
                        end
                    elseif key == "enabled" then enabled = fixed else kind = fixed end
                    local pending = self.confirmBossAward
                    if not pending or pending.key ~= key or pending.enabled ~= enabled or pending.kind ~= kind
                        or pending.amount ~= amount or pending.oldEnabled ~= config.enabled
                        or pending.oldKind ~= config.kind or pending.oldAmount ~= config.amount then
                        self.confirmBossAward = { key = key, enabled = enabled, kind = kind, amount = amount,
                            oldEnabled = config.enabled, oldKind = config.kind, oldAmount = config.amount }
                        frame.status:SetText("Confirm " .. label .. ": " .. amount .. " " .. kind:upper() .. ". Click again.")
                        return
                    end
                    self.confirmBossAward = nil
                    local ok = awards:SetLocalConfig(enabled, kind, amount)
                    self:RefreshBossAwards()
                    frame.status:SetText(ok and "Local boss settings saved." or "Settings unchanged; see warning.")
                end }
        end
        frame:SetItems(rows)
        frame.status:SetText("Off by default; local registered attendees only. No guild sync or item transfer.")
    end

    function InfinityDKPUI:ShowTaxConfiguration()
        if not _G.InfinityUIFramework or not _G.InfinityDKPTaxSystem or not _G.InfinityDKPGuildBankDonations then
            InfinityUtils:Warning("DKP tax/donation configuration unavailable.", "DKP"); return
        end
        if not self.taxConfigWindow then
            local frame = InfinityUIFramework:CreateListWindow("InfinityDKPTaxConfiguration", "Local DKP Tax and Donation Configuration", 800, 500)
            local function Input(labelText, x, offset)
                local label = InfinityUIFramework:CreateLabel(frame, labelText)
                label:SetPoint("TOPLEFT", x, -43)
                local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
                input:SetSize(105, 20)
                input:SetPoint("TOPLEFT", x + offset, -38)
                input:SetAutoFocus(false)
                input:SetMaxLetters(20)
                input:SetText("")
                return input
            end
            self.taxConfigValue = Input("Value", 15, 50)
            self.taxConfigRarity = Input("Rarity 0-5", 210, 80)
            self.taxConfigWindow = frame
        end
        self.confirmTaxConfig = nil
        self:RefreshTaxConfiguration()
        self.taxConfigWindow:Show()
    end

    function InfinityDKPUI:RefreshTaxConfiguration()
        local frame, tax, donations = self.taxConfigWindow, _G.InfinityDKPTaxSystem, _G.InfinityDKPGuildBankDonations
        if not frame or not tax or not donations or type(tax.config) ~= "table" or type(donations.config) ~= "table" then
            InfinityUtils:Warning("DKP tax/donation configuration unavailable.", "DKP"); return
        end
        local specs = {
            { tax, "Tax percentage (0-100)", "SetTaxRate", "taxRatePercentage" },
            { tax, "Tax DKP per gold", "SetDKPPerGold", "dkpPerGold" },
            { tax, "Minimum taxable gold", "SetMinTaxAmount", "minTaxAmount" },
            { tax, "Maximum daily tax gold", "SetMaxTaxPerDay", "maxTaxPerDay" },
            { tax, "Enable tax", "SetEnabled", "enabled", true },
            { tax, "Disable tax", "SetEnabled", "enabled", false },
            { donations, "Donation DKP per gold", "SetGoldRewardRate", "goldRewardPerGoldDonated" },
            { donations, "Donation item mode: value", "SetItemRewardMode", "itemRewardMode", "value" },
            { donations, "Donation item mode: rarity", "SetItemRewardMode", "itemRewardMode", "rarity" },
            { donations, "Minimum gold donation (copper)", "SetMinGoldDonation", "minGoldDonation" },
            { donations, "Rarity multiplier", "SetItemRarityMultiplier", "itemRarityMultipliers", nil, true },
            { donations, "Enable donation rewards", "SetEnabled", "enabled", true },
            { donations, "Disable donation rewards", "SetEnabled", "enabled", false },
        }
        local rows = {}
        for _, entry in ipairs(specs) do
            local module, label, method, key, fixed, usesRarity = entry[1], entry[2], entry[3], entry[4], entry[5], entry[6]
            rows[#rows + 1] = { text = label .. (fixed == nil and " | Value" or "")
                .. (usesRarity and ", Rarity 0-5" or "") .. " | confirm twice", onClick = function()
                if type(module[method]) ~= "function" or type(module.config) ~= "table" then
                    self.confirmTaxConfig = nil
                    InfinityUtils:Warning("Configuration action unavailable.", "DKP"); return
                end
                local value, rarity = fixed, nil
                if fixed == nil then
                    local raw = self.taxConfigValue:GetText()
                    if _G.issecretvalue and issecretvalue(raw) then raw = nil end
                    value = type(raw) == "string" and tonumber(raw) or nil
                    if type(value) ~= "number" or value ~= value or value <= -math.huge or value >= math.huge then
                        self.confirmTaxConfig = nil
                        InfinityUtils:Warning("Enter a finite numeric value.", "DKP"); return
                    end
                end
                if usesRarity then
                    local raw = self.taxConfigRarity:GetText()
                    if _G.issecretvalue and issecretvalue(raw) then raw = nil end
                    rarity = type(raw) == "string" and tonumber(raw) or nil
                    if type(rarity) ~= "number" or rarity ~= rarity or rarity < 0 or rarity > 5 or rarity ~= math.floor(rarity) then
                        self.confirmTaxConfig = nil
                        InfinityUtils:Warning("Enter a whole rarity from 0 to 5.", "DKP"); return
                    end
                end
                local config, old = module.config, module.config[key]
                local mode = key == "taxRatePercentage" or key == "dkpPerGold"
                local oldMode
                if mode then oldMode = config.useDirectDKPAmount end
                if _G.issecretvalue and (issecretvalue(old) or issecretvalue(oldMode)) then
                    self.confirmTaxConfig = nil
                    InfinityUtils:Warning("Current configuration is protected.", "DKP"); return
                end
                if usesRarity then
                    if type(old) ~= "table" then
                        self.confirmTaxConfig = nil
                        InfinityUtils:Warning("Rarity multipliers unavailable.", "DKP"); return
                    end
                    old = old[rarity]
                end
                if _G.issecretvalue and issecretvalue(old) then
                    self.confirmTaxConfig = nil
                    InfinityUtils:Warning("Current configuration is protected.", "DKP"); return
                end
                local pending = self.confirmTaxConfig
                if not pending or pending.module ~= module or pending.method ~= method or pending.value ~= value
                    or pending.rarity ~= rarity or pending.config ~= config or pending.old ~= old or pending.oldMode ~= oldMode then
                    self.confirmTaxConfig = { module = module, method = method, value = value, rarity = rarity,
                        config = config, old = old, oldMode = oldMode }
                    frame.status:SetText("Confirm " .. label .. ": " .. tostring(old) .. " -> " .. tostring(value) .. ". Click again.")
                    return
                end
                self.confirmTaxConfig = nil
                local ok
                if usesRarity then ok = module[method](module, rarity, value) else ok = module[method](module, value) end
                self:RefreshTaxConfiguration()
                frame.status:SetText(ok and "Local setting saved; no automatic bank processing." or "Setting not changed; see warning.")
            end }
        end
        for _, group in ipairs({ { "Tax", tax }, { "Donation", donations } }) do
            local label, module = group[1], group[2]
            local mode = module.whitelistMode
            if _G.issecretvalue and issecretvalue(mode) then mode = nil end
            rows[#rows + 1] = { text = label .. " whitelist mode: "
                .. (mode == true and "on" or mode == false and "off" or "unavailable")
                .. " | change filters in DKP Actions" }
            for _, list in ipairs({ { "Whitelist", module.whitelistedItems }, { "Blacklist", module.blacklistedItems } }) do
                local listName, items = list[1], list[2]
                local keys, unreadable = {}, 0
                if not (_G.issecretvalue and issecretvalue(items)) and type(items) == "table" then
                    for item, enabled in pairs(items) do
                        if not (_G.issecretvalue and (issecretvalue(item) or issecretvalue(enabled)))
                            and enabled == true and (type(item) == "string" or type(item) == "number") then
                            keys[#keys + 1] = tostring(item)
                        elseif (_G.issecretvalue and (issecretvalue(item) or issecretvalue(enabled)))
                            or (enabled == true and type(item) ~= "string" and type(item) ~= "number") then
                            unreadable = unreadable + 1
                        end
                    end
                    table.sort(keys)
                    if #keys == 0 and unreadable == 0 then rows[#rows + 1] = { text = label .. " " .. listName .. ": empty" } end
                    for _, item in ipairs(keys) do
                        rows[#rows + 1] = { text = label .. " " .. listName .. ": " .. item }
                    end
                    if unreadable > 0 then
                        rows[#rows + 1] = { text = label .. " " .. listName .. ": " .. unreadable .. " unreadable entries" }
                    end
                else
                    rows[#rows + 1] = { text = label .. " " .. listName .. ": unavailable" }
                end
            end
        end
        frame:SetItems(rows)
        frame.status:SetText("Local DKP settings; separate from Loot settings. No automatic bank processing.")
    end

    function InfinityDKPUI:ShowReport(kind)
        local reports = _G.InfinityDKPReports
        local methods = {
            full = "GenerateFullReport",
            priority = "GeneratePriorityList",
            attendance = "GenerateAttendanceReport",
            loot = "GenerateLootReport",
        }
        local method = methods[kind]
        if not _G.InfinityUIFramework or not reports or not method or type(reports[method]) ~= "function" then
            InfinityUtils:Warning("DKP report unavailable.", "DKP"); return
        end
        local ok, text = pcall(reports[method], reports, 7)
        if _G.issecretvalue and issecretvalue(text) then text = nil end
        if not ok or type(text) ~= "string" then
            InfinityUtils:Warning("DKP report failed: " .. tostring(text or "protected data"), "DKP"); return
        end
        if not self.reportWindow then
            local frame = InfinityUIFramework:CreateFrame("InfinityDKPReportWindow", UIParent, 750, 500)
            frame:SetPoint("CENTER")
            local title = InfinityUIFramework:CreateLabel(frame, "Local DKP Reports - select and copy")
            title:SetPoint("TOPLEFT", 15, -12)
            local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
            close:SetPoint("TOPRIGHT", -5, -5)
            close:SetScript("OnClick", function() frame:Hide() end)
            self.reportButtons = {}
            for index, spec in ipairs({ { "Full", "full" }, { "Priority", "priority" },
                { "Attendance", "attendance" }, { "Loot", "loot" } }) do
                local label, selected = spec[1], spec[2]
                local button = InfinityUIFramework:CreateButton(frame, label, 105, 22, function()
                    self:ShowReport(selected)
                end)
                button:SetPoint("TOPLEFT", 15 + (index - 1) * 115, -37)
                self.reportButtons[selected] = button
            end
            local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
            scroll:SetPoint("TOPLEFT", 20, -70)
            scroll:SetSize(690, 375)
            local edit = CreateFrame("EditBox", nil, scroll)
            edit:SetMultiLine(true)
            edit:SetAutoFocus(false)
            edit:SetFontObject(_G.ChatFontNormal or _G.GameFontHighlight)
            edit:SetWidth(670)
            edit:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
            scroll:SetScrollChild(edit)
            local status = InfinityUIFramework:CreateLabel(frame, "Local data only; edited text does not change records.")
            status:SetPoint("BOTTOMLEFT", 15, 12)
            frame:Hide()
            self.reportWindow, self.reportText, self.reportScroll = frame, edit, scroll
        end
        self.reportText:SetText(text)
        local lines = select(2, text:gsub("\n", "\n")) + 1
        self.reportText:SetHeight(math.max(375, lines * 18))
        self.reportScroll:UpdateScrollChildRect()
        self.reportWindow:Show()
    end

    function InfinityDKPUI:ShowGuildBankLog()
        if not _G.InfinityUIFramework then InfinityUtils:Warning("Guild bank log window unavailable.", "DKP"); return end
        if not self.bankLogWindow then
            local frame = InfinityUIFramework:CreateListWindow("InfinityDKPGuildBankLog", "Live Guild Bank Log", 800, 500)
            local label = InfinityUIFramework:CreateLabel(frame, "Tab")
            label:SetPoint("TOPLEFT", 15, -43)
            local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
            input:SetSize(45, 20)
            input:SetPoint("TOPLEFT", 45, -38)
            input:SetAutoFocus(false)
            input:SetMaxLetters(3)
            input:SetText("1")
            local itemButton = InfinityUIFramework:CreateButton(frame, "Item tab", 100, 22, function()
                local value = input:GetText()
                if _G.issecretvalue and issecretvalue(value) then
                    InfinityUtils:Warning("Protected bank tab input.", "DKP"); return
                end
                local tab = type(value) == "string" and tonumber(value)
                self:RequestGuildBankLog(tab)
            end)
            itemButton:SetPoint("TOPLEFT", 110, -37)
            local moneyButton = InfinityUIFramework:CreateButton(frame, "Money log", 100, 22, function()
                self:RequestGuildBankLog("money")
            end)
            moneyButton:SetPoint("TOPLEFT", 220, -37)
            self.bankLogWindow, self.bankLogInput = frame, input
            self.bankLogItemButton, self.bankLogMoneyButton = itemButton, moneyButton
        end
        local bankFrame = _G.GuildBankFrame
        if not self.bankOpen and bankFrame and type(bankFrame.IsShown) == "function" then
            local shown = bankFrame:IsShown()
            if not (_G.issecretvalue and issecretvalue(shown)) and shown then self.bankOpen = true end
        end
        self.bankLogWindow:Show()
        self:RefreshGuildBankLog()
    end

    function InfinityDKPUI:RequestGuildBankLog(tab)
        if not self.bankOpen then
            InfinityUtils:Warning("Open the guild bank first.", "DKP"); return
        end
        if _G.issecretvalue and issecretvalue(tab) then
            InfinityUtils:Warning("Protected guild bank tab.", "DKP"); return
        end
        local apiTab
        if tab == "money" then
            local maxTabs = _G.MAX_GUILDBANK_TABS
            if _G.issecretvalue and issecretvalue(maxTabs) then maxTabs = nil end
            if maxTabs == nil then maxTabs = 6 end
            if type(maxTabs) ~= "number" or maxTabs < 1 or maxTabs > 100 or maxTabs ~= math.floor(maxTabs) then
                InfinityUtils:Warning("Guild bank money log index unavailable.", "DKP"); return
            end
            apiTab = maxTabs + 1
        else
            local ok, count = false, nil
            if type(_G.GetNumGuildBankTabs) == "function" then ok, count = pcall(_G.GetNumGuildBankTabs) end
            if not ok then
                if _G.issecretvalue and issecretvalue(count) then count = nil end
                InfinityUtils:Warning("Guild bank tabs unavailable: " .. tostring(count or "API unavailable"), "DKP"); return
            end
            if _G.issecretvalue and (issecretvalue(tab) or issecretvalue(count)) then
                InfinityUtils:Warning("Protected guild bank tab.", "DKP"); return
            end
            if type(tab) ~= "number" or tab ~= tab or tab < 1 or tab ~= math.floor(tab)
                or type(count) ~= "number" or count ~= count or count < 0 or count > 100
                or tab > count then
                InfinityUtils:Warning("Enter an available guild bank tab number.", "DKP"); return
            end
            apiTab = tab
        end
        if type(_G.QueryGuildBankLog) ~= "function" then
            InfinityUtils:Warning("Guild bank log API unavailable.", "DKP"); return
        end
        self.bankLogSelection = tab
        self.bankLogWindow:SetItems({ { text = "Waiting for guild bank log..." } })
        self.bankLogWindow.status:SetText("Requested from the server. No points or items change.")
        local ok, err = pcall(_G.QueryGuildBankLog, apiTab)
        if not ok then
            if _G.issecretvalue and issecretvalue(err) then err = nil end
            self.bankLogSelection = nil
            self:RefreshGuildBankLog()
            InfinityUtils:Warning("Guild bank log request failed: " .. tostring(err or "protected error"), "DKP")
        end
    end

    function InfinityDKPUI:RefreshGuildBankLog()
        local frame = self.bankLogWindow
        if not frame then return end
        if not self.bankOpen then
            frame:SetItems({ { text = "Open the guild bank to view its log." } })
            frame.status:SetText("Read-only; no points or items change.")
            return
        end
        local selection = self.bankLogSelection
        if not selection then
            frame:SetItems({ { text = "Choose an item tab or the money log." } })
            frame.status:SetText("Only server-provided recent records are shown.")
            return
        end
        local getCount = selection == "money" and _G.GetNumGuildBankMoneyTransactions or _G.GetNumGuildBankTransactions
        local getEntry = selection == "money" and _G.GetGuildBankMoneyTransaction or _G.GetGuildBankTransaction
        if type(getCount) ~= "function" or type(getEntry) ~= "function" then
            frame:SetItems({ { text = "Guild bank log API unavailable." } })
            frame.status:SetText("This client does not expose the selected log.")
            return
        end
        local ok, count
        if selection == "money" then ok, count = pcall(getCount) else ok, count = pcall(getCount, selection) end
        if not ok then
            if _G.issecretvalue and issecretvalue(count) then count = nil end
            frame:SetItems({ { text = "Guild bank log could not be read." } })
            frame.status:SetText("Try again while the guild bank is open.")
            InfinityUtils:Warning("Guild bank log read failed: " .. tostring(count or "protected error"), "DKP")
            return
        end
        if _G.issecretvalue and issecretvalue(count) then count = nil end
        if type(count) ~= "number" or count ~= count or count < 0 or count > 1000 or count ~= math.floor(count) then
            frame:SetItems({ { text = "Guild bank log count unavailable or protected." } })
            frame.status:SetText("Try again while the guild bank is open.")
            return
        end
        local rows, skipped = {}, 0
        for i = 1, count do
            local kind, name, asset, amount, years, months, days, hours, success
            if selection == "money" then
                success, kind, name, amount, years, months, days, hours = pcall(getEntry, i)
                asset = "copper"
            else
                local unused1, unused2
                success, kind, name, asset, amount, unused1, unused2, years, months, days, hours = pcall(getEntry, selection, i)
            end
            if not success then
                if _G.issecretvalue and issecretvalue(kind) then kind = nil end
                frame:SetItems({ { text = "Guild bank log could not be read." } })
                frame.status:SetText("Try again while the guild bank is open.")
                InfinityUtils:Warning("Guild bank log read failed: " .. tostring(kind or "protected error"), "DKP")
                return
            end
            local secret = _G.issecretvalue
            if not (secret and (secret(kind) or secret(name) or secret(asset) or secret(amount)
                or secret(years) or secret(months) or secret(days) or secret(hours)))
                and type(kind) == "string" and type(name) == "string" and type(asset) == "string"
                and type(amount) == "number" and amount == amount and amount >= 0 and amount < math.huge then
                local age = {}
                for _, part in ipairs({ { years, "y" }, { months, "mo" }, { days, "d" }, { hours, "h" } }) do
                    if type(part[1]) == "number" and part[1] >= 0 and part[1] < math.huge then
                        age[#age + 1] = part[1] .. part[2]
                    end
                end
                rows[#rows + 1] = {
                    text = kind .. " | " .. name .. " | " .. amount .. " " .. asset
                        .. (#age > 0 and (" | " .. table.concat(age, " ") .. " ago") or ""),
                    link = selection ~= "money" and asset:find("|Hitem:", 1, true) and asset or nil,
                }
            else
                skipped = skipped + 1
            end
        end
        if #rows == 0 then rows[1] = { text = "No readable records returned by the server." } end
        frame:SetItems(rows)
        frame.status:SetText("Live recent log; may be incomplete. No points or items change."
            .. (skipped > 0 and (" Unreadable: " .. skipped) or ""))
    end

    function InfinityDKPUI:OnGuildBankEvent(event)
        if event == "GUILDBANKFRAME_OPENED" then
            self.bankOpen, self.bankLogSelection = true, nil
        elseif event == "GUILDBANKFRAME_CLOSED" then
            self.bankOpen, self.bankLogSelection = false, nil
        end
        if self.bankLogWindow and self.bankLogWindow:IsShown() then self:RefreshGuildBankLog() end
    end

    function InfinityDKPUI:ShowPointHistory(player)
        local points = _G.InfinityDKPPoints
        if not _G.InfinityUIFramework or not points or type(points.point_history) ~= "table" then
            InfinityUtils:Warning("Local point transactions unavailable.", "DKP"); return
        end
        if not self.pointHistoryWindow then
            local frame = InfinityUIFramework:CreateListWindow("InfinityDKPPointHistoryWindow", "Local Point Transactions", 800, 500)
            local label = InfinityUIFramework:CreateLabel(frame, "Player filter")
            label:SetPoint("TOPLEFT", 15, -43)
            local filter = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
            filter:SetSize(180, 20)
            filter:SetPoint("TOPLEFT", 100, -38)
            filter:SetAutoFocus(false)
            filter:SetMaxLetters(80)
            filter:SetText("")
            filter:SetScript("OnEnterPressed", function(box)
                box:ClearFocus(); self.pointHistoryOffset = 0; self:RefreshPointHistory()
            end)
            local refresh = InfinityUIFramework:CreateButton(frame, "Refresh", 90, 22, function()
                self.pointHistoryOffset = 0
                self:RefreshPointHistory()
            end)
            refresh:SetPoint("TOPLEFT", 305, -37)
            local newer = InfinityUIFramework:CreateButton(frame, "Newer", 80, 22, function()
                self.pointHistoryOffset = math.max(0, self.pointHistoryOffset - 200)
                self:RefreshPointHistory()
            end)
            newer:SetPoint("TOPLEFT", 410, -37)
            local older = InfinityUIFramework:CreateButton(frame, "Older", 80, 22, function()
                if self.pointHistoryHasMore then
                    self.pointHistoryOffset = self.pointHistoryOffset + 200
                end
                self:RefreshPointHistory()
            end)
            older:SetPoint("TOPLEFT", 500, -37)
            self.pointHistoryNewer, self.pointHistoryOlder = newer, older
            self.pointHistoryWindow, self.pointHistoryFilter = frame, filter
        end
        self.pointHistoryOffset = 0
        if type(player) == "string" and not (_G.issecretvalue and issecretvalue(player)) then
            self.pointHistoryFilter:SetText(player)
        end
        self:RefreshPointHistory()
        self.pointHistoryWindow:Show()
    end

    function InfinityDKPUI:RefreshPointHistory()
        local frame, points = self.pointHistoryWindow, _G.InfinityDKPPoints
        if not frame or not points or type(points.point_history) ~= "table" then
            InfinityUtils:Warning("Local point transactions unavailable.", "DKP"); return
        end
        local filter = self.pointHistoryFilter:GetText()
        if _G.issecretvalue and issecretvalue(filter) then
            InfinityUtils:Warning("Protected input cannot be used.", "DKP"); return
        end
        if type(filter) ~= "string" then InfinityUtils:Warning("Invalid player filter.", "DKP"); return end
        filter = filter:match("^%s*(.-)%s*$"):lower()
        if self.pointHistoryLastFilter ~= filter then self.pointHistoryOffset = 0 end
        self.pointHistoryLastFilter = filter
        local rows, skipped, matching = {}, 0, 0
        self.pointHistoryHasMore = false
        for i = #points.point_history, 1, -1 do
            local entry = points.point_history[i]
            if not (_G.issecretvalue and issecretvalue(entry)) and type(entry) == "table" then
                local name, kind, amount, reason, timestamp = entry.player, entry.type, entry.amount, entry.reason, entry.timestamp
                if not (_G.issecretvalue and (issecretvalue(name) or issecretvalue(kind) or issecretvalue(amount)
                    or issecretvalue(reason) or issecretvalue(timestamp)))
                    and type(name) == "string" and type(kind) == "string" and type(amount) == "number"
                    and amount == amount and amount > -math.huge and amount < math.huge
                    and type(reason) == "string" and type(timestamp) == "string" then
                    if filter == "" or name:lower():find(filter, 1, true) then
                        matching = matching + 1
                        if matching > self.pointHistoryOffset then
                            if #rows == 200 then self.pointHistoryHasMore = true; break end
                            rows[#rows + 1] = { text = timestamp .. " | " .. name .. " | " .. kind .. " | "
                                .. (amount > 0 and "+" or "") .. amount .. " | " .. reason }
                        end
                    end
                else
                    skipped = skipped + 1
                end
            else
                skipped = skipped + 1
            end
        end
        local count = #rows
        if count == 0 then rows[1] = { text = "No readable matching transactions." } end
        frame:SetItems(rows)
        frame.status:SetText("Matching local records " .. (count > 0 and self.pointHistoryOffset + 1 or 0)
            .. "-" .. (self.pointHistoryOffset + count)
            .. "; not a complete audit."
            .. (skipped > 0 and (" Unreadable records: " .. skipped) or ""))
    end

    function InfinityDKPUI:ShowRefunds()
        local history, engine = _G.InfinityDKPHistory, _G.InfinityDKPEngine
        if not history or not engine or type(history.awards) ~= "table" then
            InfinityUtils:Warning("Loot history unavailable.", "DKP"); return
        end
        if not self.refundWindow then
            local frame = InfinityUIFramework:CreateListWindow("InfinityDKPRefundWindow", "Local Loot Refunds", 750, 500)
            local newer = InfinityUIFramework:CreateButton(frame, "Newer", 80, 22, function()
                self.refundOffset = math.max(0, self.refundOffset - 200)
                self.confirmRefund = nil
                self:RefreshRefunds()
            end)
            newer:SetPoint("TOPLEFT", 15, -37)
            local older = InfinityUIFramework:CreateButton(frame, "Older", 80, 22, function()
                if self.refundOffset + 200 < #history.awards then
                    self.refundOffset = self.refundOffset + 200
                    self.confirmRefund = nil
                    self:RefreshRefunds()
                end
            end)
            older:SetPoint("TOPLEFT", 105, -37)
            self.refundWindow, self.refundNewer, self.refundOlder = frame, newer, older
        end
        self.refundOffset = 0
        self.confirmRefund = nil
        self:RefreshRefunds()
        self.refundWindow:Show()
    end

    function InfinityDKPUI:RefreshRefunds()
        local history, engine, frame = _G.InfinityDKPHistory, _G.InfinityDKPEngine, self.refundWindow
        local rows = {}
        local start = math.max(1, #history.awards - self.refundOffset)
        for index = start, math.max(1, start - 199), -1 do
            local award = history.awards[index]
            if not (_G.issecretvalue and _G.issecretvalue(award)) and type(award) == "table" then
                local name, item, amount, kind = award.player, award.item, award.points, award.type
                if not (_G.issecretvalue and (issecretvalue(name) or issecretvalue(item)
                    or issecretvalue(amount) or issecretvalue(kind) or issecretvalue(award.refund)))
                    and type(name) == "string" and type(item) == "string"
                    and type(amount) == "number" and type(kind) == "string" then
                    local awardIndex = index
                    local refunded = award.refund ~= nil
                    local supported = (kind == "manual" or kind == "dkp") and amount > 0
                        and amount <= 1000000000 and amount == math.floor(amount)
                    rows[#rows + 1] = { text = name .. " | " .. item .. " | " .. amount .. " "
                        .. (kind == "manual" and "GP" or kind == "dkp" and "DKP" or kind)
                        .. (refunded and " | refunded" or (supported and " | click twice to refund" or " | manual adjustment only")),
                        link = item:find("|Hitem:", 1, true) and item or nil,
                        onClick = not refunded and supported and function()
                            local current = history.awards[awardIndex]
                            if (_G.issecretvalue and (issecretvalue(current) or issecretvalue(award.player)
                                or issecretvalue(award.item) or issecretvalue(award.points)
                                or issecretvalue(award.type) or issecretvalue(award.refund)))
                                or current ~= award or award.player ~= name or award.item ~= item
                                or award.points ~= amount or award.type ~= kind or award.refund then
                                self.confirmRefund = nil
                                self:RefreshRefunds()
                                InfinityUtils:Warning("Award changed; review the list.", "DKP")
                                return
                            end
                            local player = engine.players[name]
                            if _G.issecretvalue and _G.issecretvalue(player) then player = nil end
                            local balance
                            if type(player) == "table" then
                                if kind == "dkp" then balance = player.dkp else balance = player.gp end
                            end
                            if _G.issecretvalue and _G.issecretvalue(balance) then balance = nil end
                            if type(player) ~= "table" or type(balance) ~= "number" then
                                self.confirmRefund = nil
                                InfinityUtils:Warning("Player balance unavailable.", "DKP"); return
                            end
                            local pending = self.confirmRefund
                            if not pending or pending.award ~= award or pending.index ~= awardIndex
                                or pending.player ~= player or pending.balance ~= balance then
                                self.confirmRefund = { award = award, index = awardIndex, player = player, balance = balance }
                                frame.status:SetText("Refund " .. name .. " for " .. item .. "? Click again. No item is transferred.")
                                return
                            end
                            self.confirmRefund = nil
                            local ok = history:RefundAward(awardIndex)
                            self:RefreshRefunds()
                            self:Update()
                            frame.status:SetText(ok and "Refunded locally; synchronize separately." or "Refund failed; see warning.")
                        end }
                end
            end
        end
        if #rows == 0 then rows[1] = { text = "No readable local loot awards." } end
        frame:SetItems(rows)
        frame.status:SetText("Awards " .. (#history.awards > 0 and self.refundOffset + 1 or 0)
            .. "-" .. math.min(self.refundOffset + 200, #history.awards)
            .. ". Local points only; no items move. Click an award twice.")
    end

    -- Content area
    self.content = CreateFrame("Frame", nil, self.frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.content:SetSize(580, 320)
    self.content:SetPoint("TOPLEFT", tabsFrame, "BOTTOMLEFT", 0, -10)
    
    local scroll = CreateFrame("ScrollFrame", nil, self.content, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", self.content, "BOTTOMRIGHT", -25, 0)
    self.scrollChild = CreateFrame("Frame", nil, scroll)
    self.scrollChild:SetSize(555, 320)
    scroll:SetScrollChild(self.scrollChild)

    self.player_list = self.scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.player_list:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, 0)
    self.player_list:SetWidth(555)
    self.player_list:SetJustifyH("LEFT")
    self.player_list:SetText("Loading player data...")
    
    self.selectedTab = "Players"
    self.frame:Hide()
    self.initialized = true
end

function InfinityDKPUI:Toggle()
    if not self.initialized then
        self:Initialize()
    end
    if self.frame:IsShown() then self:Hide() else self:Show() end
end

function InfinityDKPUI:Show()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:Show()
    self:Update()
end

function InfinityDKPUI:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function InfinityDKPUI:Update()
    if not self.initialized or not self.frame:IsShown() then
        return
    end
    
    if self.selectedTab == "Players" and InfinityDKPEngine then
        local ranked = InfinityDKPEngine:GetRankedPlayers()
        local text = "Local points (" .. InfinityDKPEngine.system_type .. "; manual guild snapshots)\n"
            .. "/dkp system; /dkp add; /dkp points; /dkp spend; /dkp ep; /dkp gp; /dkp award\n\n"
            .. "Guild trade offers: /dkp trade\n\n"
            .. string.format("%-3s %-18s %-7s %-7s %-9s %-9s\n", "#", "Player", "EP", "GP", "DKP", "Priority")
        
        for i, player in ipairs(ranked) do
            text = text .. string.format("%-3d %-18s %-7.0f %-7.0f %-9.2f %-9.2f\n",
                i, player.name, player.ep, player.gp, player.dkp, player.priority)
        end
        
        if #ranked == 0 then
            text = text .. "No players registered"
        end
        
        self.player_list:SetText(text)
    elseif self.selectedTab == "Auctions" then
        local text = "Guild auction: /dkp guildauction for commands\n"
        local guildAuction = InfinityDKPGuildAuctions and InfinityDKPGuildAuctions.auction
        if guildAuction and (not InfinityDKPGuildSync or guildAuction.guild ~= InfinityDKPGuildSync:GetGuildKey()) then
            guildAuction = nil
        end
        if guildAuction then
            text = text .. guildAuction.status .. ": " .. guildAuction.itemLink .. " - "
                .. tostring(guildAuction.highBid or guildAuction.startingBid) .. " ("
                .. tostring(guildAuction.highestBidder or "no bids") .. ")\n"
        else
            text = text .. "No guild auction. /dkp guildauction sync to request one.\n"
        end
        text = text .. "Points and items are awarded manually.\n\n"
            .. "Local auctions: /dkp auction create | bid | close | cancel | list\n"
        local auctions = InfinityDKPUnifiedAuctions and InfinityDKPUnifiedAuctions:GetActiveAuctions() or {}
        local count = 0
        for _, auction in ipairs(auctions) do
            if auction.status == "active" then
                count = count + 1
                text = text .. string.format("[%d] %s: %s (%s)\n",
                    auction.id, tostring(auction.itemName or auction.itemLink), tostring(auction.currentHighBid or 0),
                    tostring(auction.highestBidder or "no bids"))
            end
        end
        self.player_list:SetText(text .. (count == 0 and "No active auctions" or ""))
    elseif self.selectedTab == "History" then
        local text = "Local loot history (not synchronized)\n\n"
        local history = InfinityDKPHistory and InfinityDKPHistory:GetRecentAwards(7) or {}
        for _, award in ipairs(history) do
            text = text .. string.format("%s | %s | %s%s\n", award.player, award.item, tostring(award.points),
                award.refund and " | refunded" or "")
        end
        self.player_list:SetText(text .. (#history == 0 and "No recorded awards" or ""))
    elseif self.selectedTab == "Reports" then
        local report = InfinityDKPReports and InfinityDKPReports:GenerateSummary() or "Reports unavailable"
        self.player_list:SetText("Local data (not synchronized)\n\n" .. report)
    end
    local height = self.player_list:GetStringHeight()
    self.scrollChild:SetHeight(math.max(320, type(height) == "number" and height + 10 or 0))
end

return InfinityDKPUI
