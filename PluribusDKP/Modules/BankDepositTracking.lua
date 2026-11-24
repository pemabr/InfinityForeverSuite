-- BankDepositTracking.lua - Track guild bank deposits for taxation
-- Part of PluribusDKP addon suite
-- Records bank deposits and calculates tax DKP automatically

local BankDepositTracking = {}
BankDepositTracking.enabled = false
BankDepositTracking.db = nil
BankDepositTracking.last_scan = {}

-- Configuration
BankDepositTracking.config = {
    enabled = true,
    track_deposits = true,
    track_withdrawals = true,
    calculate_tax_dkp = true,
    tax_per_1000_gold = 5,  -- 5 DKP per 1000g deposited
    auction_tax_percent = 2, -- 2% tax on AH items
    enable_whitelist = true,
    enable_blacklist = true,
    min_deposit_value = 1,  -- Track deposits > 1g
    notify_depositor = true,
}

function BankDepositTracking:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusDKP")
    if not self.db then
        self:Log("No DKP database found")
        return
    end
    
    -- Initialize tracking structures
    if not self.db.bank_tracking then
        self.db.bank_tracking = {
            deposits = {},
            withdrawals = {},
            whitelist = {},  -- Items exempt from tax
            blacklist = {},  -- Items that require tax
            total_taxes_collected = 0,
        }
    end
    
    self.enabled = true
    
    -- Register for events
    PluribusCore.Events:RegisterListener("guild_bank_deposit", function(player, item, quantity, value)
        self:OnBankDeposit(player, item, quantity, value)
    end)
    
    PluribusCore.Events:RegisterListener("guild_bank_withdraw", function(player, item, quantity)
        self:OnBankWithdraw(player, item, quantity)
    end)
    
    self:Log("Initialized")
end

function BankDepositTracking:OnBankDeposit(playerName, itemName, quantity, value)
    if not self.enabled or not self.db then
        return
    end
    
    -- Create deposit record
    local deposit = {
        id = "deposit_" .. time() .. "_" .. math.random(10000),
        player = playerName,
        item = itemName,
        quantity = quantity,
        value = value or 0,
        timestamp = time(),
        tax_dkp = 0,
        tax_percentage = 0,
        processed = false,
    }
    
    -- Calculate tax if applicable
    local taxDKP = self:CalculateDepositTax(itemName, value)
    
    if taxDKP > 0 then
        -- Check whitelist/blacklist
        if self.config.enable_whitelist and self:IsWhitelisted(itemName) then
            taxDKP = 0
        elseif self.config.enable_blacklist and self:IsBlacklisted(itemName) then
            taxDKP = taxDKP * 1.5  -- 1.5x tax for blacklisted items
        end
    end
    
    deposit.tax_dkp = taxDKP
    
    -- Apply tax to player
    if taxDKP > 0 then
        self:ApplyBankTax(playerName, taxDKP, itemName)
        deposit.processed = true
    end
    
    -- Record deposit
    table.insert(self.db.bank_tracking.deposits, deposit)
    
    -- Log to audit
    self:LogAudit(playerName, "bank_deposit", {
        item = itemName,
        quantity = quantity,
        value = value,
        tax_dkp = taxDKP,
    })
    
    -- Notify depositor
    if self.config.notify_depositor and taxDKP > 0 then
        self:NotifyPlayer(playerName, "Bank deposit tax: " .. math.floor(taxDKP) .. " DKP for " .. itemName)
    end
    
    -- Fire event
    PluribusCore.Events:Fire("bank_deposit_recorded", deposit)
    
    self:Log("Deposit recorded: " .. playerName .. " deposited " .. itemName)
end

function BankDepositTracking:OnBankWithdraw(playerName, itemName, quantity)
    if not self.enabled or not self.db then
        return
    end
    
    -- Record withdrawal
    local withdrawal = {
        id = "withdrawal_" .. time() .. "_" .. math.random(10000),
        player = playerName,
        item = itemName,
        quantity = quantity,
        timestamp = time(),
    }
    
    table.insert(self.db.bank_tracking.withdrawals, withdrawal)
    
    -- Log to audit
    self:LogAudit(playerName, "bank_withdrawal", {
        item = itemName,
        quantity = quantity,
    })
    
    self:Log("Withdrawal recorded: " .. playerName .. " withdrew " .. itemName)
end

function BankDepositTracking:CalculateDepositTax(itemName, value)
    if not self.config.calculate_tax_dkp then
        return 0
    end
    
    -- Calculate based on gold value
    if value and value > self.config.min_deposit_value then
        local taxDKP = math.floor(value / 1000 * self.config.tax_per_1000_gold)
        return math.max(1, taxDKP)  -- Minimum 1 DKP
    end
    
    return 0
end

function BankDepositTracking:ApplyBankTax(playerName, taxDKP, reason)
    if not self.db.players then
        self.db.players = {}
    end
    
    if not self.db.players[playerName] then
        self.db.players[playerName] = {
            dkp = 0,
            gp = 0,
            ep = 0,
        }
    end
    
    -- Deduct DKP for tax (GP cost of donating)
    self.db.players[playerName].gp = (self.db.players[playerName].gp or 0) + taxDKP
    
    -- Update total taxes collected
    self.db.bank_tracking.total_taxes_collected = 
        (self.db.bank_tracking.total_taxes_collected or 0) + taxDKP
end

function BankDepositTracking:Whitelist(itemName)
    if not self.db.bank_tracking.whitelist then
        self.db.bank_tracking.whitelist = {}
    end
    
    -- Add to whitelist
    self.db.bank_tracking.whitelist[itemName] = true
    self:Log("Whitelisted: " .. itemName)
    return true
end

function BankDepositTracking:Blacklist(itemName)
    if not self.db.bank_tracking.blacklist then
        self.db.bank_tracking.blacklist = {}
    end
    
    -- Add to blacklist
    self.db.bank_tracking.blacklist[itemName] = true
    self:Log("Blacklisted: " .. itemName)
    return true
end

function BankDepositTracking:IsWhitelisted(itemName)
    if not self.config.enable_whitelist then
        return false
    end
    
    return self.db.bank_tracking.whitelist[itemName] or false
end

function BankDepositTracking:IsBlacklisted(itemName)
    if not self.config.enable_blacklist then
        return false
    end
    
    return self.db.bank_tracking.blacklist[itemName] or false
end

function BankDepositTracking:GetDepositHistory(playerName, maxResults)
    if not self.db or not self.db.bank_tracking then
        return {}
    end
    
    maxResults = maxResults or 100
    local results = {}
    
    for _, deposit in ipairs(self.db.bank_tracking.deposits or {}) do
        if playerName == nil or deposit.player == playerName then
            table.insert(results, deposit)
            if #results >= maxResults then
                break
            end
        end
    end
    
    return results
end

function BankDepositTracking:GetTaxStats(playerName)
    if not self.db or not self.db.bank_tracking then
        return {}
    end
    
    local stats = {
        player = playerName,
        total_deposits = 0,
        total_tax_dkp = 0,
        average_tax = 0,
        last_deposit = nil,
    }
    
    for _, deposit in ipairs(self.db.bank_tracking.deposits or {}) do
        if deposit.player == playerName then
            stats.total_deposits = stats.total_deposits + 1
            stats.total_tax_dkp = stats.total_tax_dkp + (deposit.tax_dkp or 0)
            
            if not stats.last_deposit or deposit.timestamp > stats.last_deposit then
                stats.last_deposit = deposit.timestamp
            end
        end
    end
    
    if stats.total_deposits > 0 then
        stats.average_tax = stats.total_tax_dkp / stats.total_deposits
    end
    
    return stats
end

function BankDepositTracking:LogAudit(playerName, action, details)
    if not self.db.audit_log then
        self.db.audit_log = {}
    end
    
    if #self.db.audit_log > 10000 then
        table.remove(self.db.audit_log, 1)
    end
    
    table.insert(self.db.audit_log, {
        player = playerName,
        action = action,
        details = details,
        timestamp = time(),
    })
end

function BankDepositTracking:NotifyPlayer(playerName, message)
    if PluribusCore and PluribusCore.SendMessage then
        PluribusCore.SendMessage(playerName, "[BankDeposit] " .. message)
    else
        print("[BankDeposit] " .. playerName .. ": " .. message)
    end
end

function BankDepositTracking:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function BankDepositTracking:GetStatus()
    if not self.db or not self.db.bank_tracking then
        return {}
    end
    
    return {
        enabled = self.enabled,
        total_deposits = #(self.db.bank_tracking.deposits or {}),
        total_withdrawals = #(self.db.bank_tracking.withdrawals or {}),
        total_taxes_collected = self.db.bank_tracking.total_taxes_collected or 0,
        whitelisted_items = self:CountTable(self.db.bank_tracking.whitelist or {}),
        blacklisted_items = self:CountTable(self.db.bank_tracking.blacklist or {}),
    }
end

function BankDepositTracking:CountTable(t)
    local count = 0
    for _ in pairs(t or {}) do
        count = count + 1
    end
    return count
end

function BankDepositTracking:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[BankDepositTracking] " .. message)
    else
        print("[BankDepositTracking] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_BANKDEPOSIT1 = "/bankdeposit"
    SlashCmdList["BANKDEPOSIT"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "whitelist" then
            if args and args ~= "" then
                BankDepositTracking:Whitelist(args)
                print("Whitelisted: " .. args)
            else
                print("Usage: /bankdeposit whitelist <item>")
            end
        elseif cmd == "blacklist" then
            if args and args ~= "" then
                BankDepositTracking:Blacklist(args)
                print("Blacklisted: " .. args)
            else
                print("Usage: /bankdeposit blacklist <item>")
            end
        elseif cmd == "history" then
            if args and args ~= "" then
                local history = BankDepositTracking:GetDepositHistory(args, 20)
                print("Deposit history for " .. args .. " (" .. #history .. " items):")
                for _, dep in ipairs(history) do
                    local dateStr = date("%Y-%m-%d", dep.timestamp)
                    print("  " .. dateStr .. " | " .. dep.item .. " | Tax: " .. math.floor(dep.tax_dkp) .. " DKP")
                end
            else
                print("Usage: /bankdeposit history <player>")
            end
        elseif cmd == "stats" then
            if args and args ~= "" then
                local stats = BankDepositTracking:GetTaxStats(args)
                print("Bank tax stats for " .. args .. ":")
                print("  Total deposits: " .. stats.total_deposits)
                print("  Total tax paid: " .. math.floor(stats.total_tax_dkp) .. " DKP")
                print("  Average tax: " .. math.floor(stats.average_tax) .. " DKP/deposit")
            else
                print("Usage: /bankdeposit stats <player>")
            end
        elseif cmd == "status" then
            local status = BankDepositTracking:GetStatus()
            print("Bank Deposit Tracking Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Bank Deposit Tracking Commands:")
            print("  /bankdeposit whitelist <item> - Exempt item from tax")
            print("  /bankdeposit blacklist <item> - Increase tax for item")
            print("  /bankdeposit history <player> - Show deposit history")
            print("  /bankdeposit stats <player> - Show tax statistics")
            print("  /bankdeposit status - Show system status")
        end
    end
end

return BankDepositTracking
