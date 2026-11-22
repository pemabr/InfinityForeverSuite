-- RefundSystem.lua - Handle DKP refunds for disputed loot awards
-- Part of InfinityDKP addon suite
-- Allow guild leadership to refund incorrectly awarded loot and restore DKP

local RefundSystem = {}
RefundSystem.enabled = false
RefundSystem.db = nil
RefundSystem.refund_queue = {}

-- Configuration
RefundSystem.config = {
    enabled = true,
    allow_player_refund_requests = true,
    require_manager_approval = true,
    refund_tax_percent = 0,  -- Tax on refunds (0% by default for fairness)
    max_refund_age_days = 30, -- Can only refund within 30 days
    track_refund_reason = true,
    notify_players = true,
}

function RefundSystem:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityDKP")
    if not self.db then
        self:Log("No DKP database found")
        return
    end
    
    -- Initialize refund structures
    if not self.db.refunds then
        self.db.refunds = {
            history = {},      -- Full refund history
            pending = {},      -- Pending refund requests
        }
    end
    
    self.enabled = true
    
    -- Register for events
    InfinityCore.Events:RegisterListener("refund_request", function(data)
        self:OnRefundRequested(data)
    end)
    
    self:Log("Initialized")
end

function RefundSystem:RequestRefund(playerName, lootID, reason)
    if not self.enabled or not self.db then
        return false
    end
    
    -- Verify loot entry exists
    if not self.db.loot_history then
        self:Log("No loot history found")
        return false
    end
    
    -- Find the loot entry
    local lootEntry = nil
    for _, entry in ipairs(self.db.loot_history) do
        if entry.id == lootID and entry.player == playerName then
            lootEntry = entry
            break
        end
    end
    
    if not lootEntry then
        self:Log("Loot entry not found: " .. tostring(lootID))
        return false
    end
    
    -- Check age limit
    local ageSeconds = time() - lootEntry.timestamp
    local ageLimit = self.config.max_refund_age_days * 24 * 60 * 60
    
    if ageSeconds > ageLimit then
        self:Log("Refund request too old: " .. tostring(ageSeconds) .. " seconds")
        return false
    end
    
    -- Create refund request
    local refundRequest = {
        id = "refund_" .. time() .. "_" .. math.random(10000),
        loot_id = lootID,
        player = playerName,
        gp_to_refund = lootEntry.gp_cost or 0,
        ep_to_refund = lootEntry.ep_value or 0,
        item_name = lootEntry.item_name or "Unknown",
        reason = reason or "No reason provided",
        requester = UnitName("player") or "Unknown",
        status = "pending",
        timestamp = time(),
        approved_by = nil,
        approved_at = nil,
    }
    
    -- Queue request
    if self.config.require_manager_approval then
        table.insert(self.db.refunds.pending, refundRequest)
        self:Log("Refund request queued for approval: " .. refundRequest.id)
        
        -- Fire event
        InfinityCore.Events:Fire("refund_request_pending", refundRequest)
    else
        -- Auto-approve
        self:ApproveRefund(refundRequest.id, UnitName("player") or "System")
    end
    
    return true
end

function RefundSystem:ApproveRefund(refundRequestID, approverName)
    if not self.enabled or not self.db then
        return false
    end
    
    -- Find the pending request
    local refundRequest = nil
    local requestIndex = nil
    
    for idx, req in ipairs(self.db.refunds.pending or {}) do
        if req.id == refundRequestID then
            refundRequest = req
            requestIndex = idx
            break
        end
    end
    
    if not refundRequest then
        self:Log("Refund request not found: " .. tostring(refundRequestID))
        return false
    end
    
    -- Process the refund
    local playerName = refundRequest.player
    
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
    
    -- Calculate refund amounts (minus tax if configured)
    local gpRefund = refundRequest.gp_to_refund * (1 - self.config.refund_tax_percent / 100)
    local epRefund = refundRequest.ep_to_refund * (1 - self.config.refund_tax_percent / 100)
    
    -- Apply refund
    self.db.players[playerName].gp = (self.db.players[playerName].gp or 0) - gpRefund
    self.db.players[playerName].dkp = (self.db.players[playerName].dkp or 0) + epRefund
    self.db.players[playerName].ep = (self.db.players[playerName].ep or 0) + epRefund
    
    -- Update request status
    refundRequest.status = "approved"
    refundRequest.approved_by = approverName
    refundRequest.approved_at = time()
    
    -- Move to history
    table.remove(self.db.refunds.pending, requestIndex)
    table.insert(self.db.refunds.history, refundRequest)
    
    -- Log to audit
    self:LogAudit(playerName, "refund_approved", {
        gp_refunded = gpRefund,
        ep_refunded = epRefund,
        item = refundRequest.item_name,
        approved_by = approverName,
        reason = refundRequest.reason,
    })
    
    -- Notify player if configured
    if self.config.notify_players then
        self:NotifyPlayer(playerName, "Your refund for " .. refundRequest.item_name .. " has been approved. " ..
                         "Refunded: " .. math.floor(epRefund) .. " DKP, " .. math.floor(gpRefund) .. " GP")
    end
    
    -- Fire event
    InfinityCore.Events:Fire("refund_approved", refundRequest)
    
    self:Log("Refund approved: " .. refundRequestID .. " for player " .. playerName)
    
    return true
end

function RefundSystem:DenyRefund(refundRequestID, denyReasonReason)
    if not self.enabled or not self.db then
        return false
    end
    
    -- Find the pending request
    local refundRequest = nil
    local requestIndex = nil
    
    for idx, req in ipairs(self.db.refunds.pending or {}) do
        if req.id == refundRequestID then
            refundRequest = req
            requestIndex = idx
            break
        end
    end
    
    if not refundRequest then
        self:Log("Refund request not found: " .. tostring(refundRequestID))
        return false
    end
    
    -- Update status
    refundRequest.status = "denied"
    refundRequest.deny_reason = denyReason or "No reason provided"
    
    -- Move to history
    table.remove(self.db.refunds.pending, requestIndex)
    table.insert(self.db.refunds.history, refundRequest)
    
    -- Notify player
    if self.config.notify_players then
        self:NotifyPlayer(refundRequest.player, "Your refund request for " .. refundRequest.item_name ..
                         " has been denied. Reason: " .. refundRequest.deny_reason)
    end
    
    -- Fire event
    InfinityCore.Events:Fire("refund_denied", refundRequest)
    
    self:Log("Refund denied: " .. refundRequestID)
    
    return true
end

function RefundSystem:LogAudit(playerName, action, details)
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

function RefundSystem:NotifyPlayer(playerName, message)
    if InfinityCore and InfinityCore.SendMessage then
        InfinityCore.SendMessage(playerName, "[RefundSystem] " .. message)
    else
        print("[RefundSystem] " .. playerName .. ": " .. message)
    end
end

function RefundSystem:GetPendingRefunds()
    if not self.db or not self.db.refunds then
        return {}
    end
    
    return self.db.refunds.pending or {}
end

function RefundSystem:GetRefundHistory(playerName, maxResults)
    if not self.db or not self.db.refunds then
        return {}
    end
    
    maxResults = maxResults or 100
    local results = {}
    
    for _, entry in ipairs(self.db.refunds.history or {}) do
        if playerName == nil or entry.player == playerName then
            table.insert(results, entry)
            if #results >= maxResults then
                break
            end
        end
    end
    
    return results
end

function RefundSystem:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function RefundSystem:GetStatus()
    return {
        enabled = self.enabled,
        pending_refunds = #(self.db.refunds.pending or {}),
        total_refunds = #(self.db.refunds.history or {}),
    }
end

function RefundSystem:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[RefundSystem] " .. message)
    else
        print("[RefundSystem] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_REFUND1 = "/refund"
    SlashCmdList["REFUND"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "pending" then
            local pending = RefundSystem:GetPendingRefunds()
            print("Pending refund requests: " .. #pending)
            for _, req in ipairs(pending) do
                print("  " .. req.id .. " | " .. req.player .. " | " .. req.item_name .. " | " .. req.reason)
            end
        elseif cmd == "approve" then
            if args and args ~= "" then
                RefundSystem:ApproveRefund(args, UnitName("player") or "Admin")
                print("Refund approved: " .. args)
            else
                print("Usage: /refund approve <id>")
            end
        elseif cmd == "deny" then
            local id, reason = args:match("^(%S+)%s+(.+)$")
            if id then
                RefundSystem:DenyRefund(id, reason or "No reason provided")
                print("Refund denied: " .. id)
            else
                print("Usage: /refund deny <id> [reason]")
            end
        elseif cmd == "status" then
            local status = RefundSystem:GetStatus()
            print("Refund System Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Refund System Commands:")
            print("  /refund pending - Show pending refund requests")
            print("  /refund approve <id> - Approve a refund")
            print("  /refund deny <id> [reason] - Deny a refund")
            print("  /refund status - Show system status")
        end
    end
end

return RefundSystem
