-- NetworkSkinSyncEngine.lua - Share and sync skins across raid group
-- Part of InfinityHealer addon suite
-- Handles network communication for skin distribution

local NetworkSkinSyncEngine = {}
NetworkSkinSyncEngine.enabled = false
NetworkSkinSyncEngine.db = nil
NetworkSkinSyncEngine.sync_requests = {}

-- Configuration
NetworkSkinSyncEngine.config = {
    enabled = true,
    allow_downloads = true,
    allow_uploads = true,
    sync_channel = "RAID",  -- RAID, PARTY, GUILD
    request_timeout = 30,
    max_concurrent_syncs = 5,
    compression_enabled = false,
}

function NetworkSkinSyncEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.network_skins then
        self.db.network_skins = {}
    end
    
    if not self.db.sync_requests then
        self.db.sync_requests = {}
    end
    
    self.sync_requests = self.db.sync_requests
    self.enabled = true
    
    self:Log("Initialized with sync channel: " .. self.config.sync_channel)
end

function NetworkSkinSyncEngine:RequestSkin(skinName, fromPlayer)
    if not self.config.allow_downloads then
        return false
    end
    
    if not skinName or not fromPlayer then
        return false
    end
    
    -- Create request
    local request = {
        skin_name = skinName,
        requester = UnitName("player") or "Unknown",
        requested_from = fromPlayer,
        requested_at = GetTime(),
        expires_at = GetTime() + self.config.request_timeout,
        status = "PENDING",
    }
    
    table.insert(self.sync_requests, request)
    
    -- Send request via chat
    local message = string.format("SKINSYNC_REQ:%s:%s", skinName, request.requester)
    SendChatMessage(message, self.config.sync_channel)
    
    self:Log("Skin request sent: " .. skinName .. " from " .. fromPlayer)
    return true
end

function NetworkSkinSyncEngine:ReceiveSkinRequest(skinName, requester)
    if not self.config.allow_uploads then
        return false
    end
    
    if not skinName or not requester then
        return false
    end
    
    -- Get the skin from SkinImportExportEngine
    if not InfinityHealer or not InfinityHealer.SkinImportExportEngine then
        return false
    end
    
    local skinData = InfinityHealer.SkinImportExportEngine:GetCustomSkin(skinName)
    
    if not skinData then
        return false
    end
    
    -- Send skin data via chat (chunked if necessary)
    local message = string.format("SKINSYNC_RES:%s:%s", skinName, requester)
    SendChatMessage(message, self.config.sync_channel)
    
    self:Log("Skin sent: " .. skinName .. " to " .. requester)
    return true
end

function NetworkSkinSyncEngine:ProcessIncomingSkinData(skinData, fromPlayer)
    if not skinData or not fromPlayer then
        return false
    end
    
    if not InfinityHealer or not InfinityHealer.SkinImportExportEngine then
        return false
    end
    
    -- Create export package format
    local importData = {
        skin_data = skinData,
        export_time = GetTime(),
        source_player = fromPlayer,
        exporter_version = "1.0",
    }
    
    -- Import the skin
    local success = InfinityHealer.SkinImportExportEngine:ImportSkin(importData)
    
    if success then
        self:Log("Skin received from " .. fromPlayer .. ": " .. skinData.name)
    end
    
    return success
end

function NetworkSkinSyncEngine:AdvertiseSkin(skinName)
    if not self.config.allow_uploads then
        return false
    end
    
    if not skinName or skinName == "" then
        return false
    end
    
    -- Check if skin exists
    if not InfinityHealer or not InfinityHealer.SkinImportExportEngine then
        return false
    end
    
    local skinData = InfinityHealer.SkinImportExportEngine:GetCustomSkin(skinName)
    
    if not skinData then
        return false
    end
    
    -- Send advertisement to group
    local message = string.format("SKINSYNC_ADV:%s:%s", skinName, skinData.author or "Unknown")
    SendChatMessage(message, self.config.sync_channel)
    
    self:Log("Skin advertised: " .. skinName)
    return true
end

function NetworkSkinSyncEngine:AdvertiseAllSkins()
    if not InfinityHealer or not InfinityHealer.SkinImportExportEngine then
        return false
    end
    
    local skins = InfinityHealer.SkinImportExportEngine:ListCustomSkins()
    local advertised = 0
    
    for _, skinInfo in ipairs(skins) do
        if self:AdvertiseSkin(skinInfo.name) then
            advertised = advertised + 1
        end
    end
    
    self:Log("Advertised " .. advertised .. " skins")
    return true
end

function NetworkSkinSyncEngine:SetSyncChannel(channel)
    if channel == "RAID" or channel == "PARTY" or channel == "GUILD" then
        self.config.sync_channel = channel
        self:Log("Sync channel set to: " .. channel)
        return true
    end
    return false
end

function NetworkSkinSyncEngine:SetAllowDownloads(allowed)
    self.config.allow_downloads = allowed
    self:Log("Downloads: " .. (allowed and "enabled" or "disabled"))
    return true
end

function NetworkSkinSyncEngine:SetAllowUploads(allowed)
    self.config.allow_uploads = allowed
    self:Log("Uploads: " .. (allowed and "enabled" or "disabled"))
    return true
end

function NetworkSkinSyncEngine:GetPendingRequests()
    local pending = {}
    local currentTime = GetTime()
    
    for _, request in ipairs(self.sync_requests) do
        if request.status == "PENDING" and currentTime < request.expires_at then
            table.insert(pending, request)
        end
    end
    
    return pending
end

function NetworkSkinSyncEngine:CleanupExpiredRequests()
    local currentTime = GetTime()
    local remaining = {}
    
    for _, request in ipairs(self.sync_requests) do
        if currentTime < request.expires_at then
            table.insert(remaining, request)
        end
    end
    
    self.sync_requests = remaining
    return #self.sync_requests
end

function NetworkSkinSyncEngine:GetStatus()
    local pendingCount = #self:GetPendingRequests()
    
    return {
        enabled = self.enabled,
        allow_downloads = self.config.allow_downloads,
        allow_uploads = self.config.allow_uploads,
        sync_channel = self.config.sync_channel,
        pending_requests = pendingCount,
        compression = self.config.compression_enabled,
    }
end

function NetworkSkinSyncEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[NetworkSkinSyncEngine] " .. message)
    else
        print("[NetworkSkinSyncEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_SKINSYNC1 = "/skinsync"
    SlashCmdList["SKINSYNC"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "request" then
            local skin, player = args:match("^(%S+)%s+(%S+)$")
            if skin and player then
                if NetworkSkinSyncEngine:RequestSkin(skin, player) then
                    print("Skin request sent: " .. skin .. " from " .. player)
                else
                    print("Failed to send request")
                end
            else
                print("Usage: /skinsync request <skin> <player>")
            end
        elseif cmd == "advertise" then
            if args and args ~= "" then
                if NetworkSkinSyncEngine:AdvertiseSkin(args) then
                    print("Skin advertised: " .. args)
                else
                    print("Skin not found: " .. args)
                end
            else
                NetworkSkinSyncEngine:AdvertiseAllSkins()
                print("All skins advertised")
            end
        elseif cmd == "channel" then
            if args and (args == "RAID" or args == "PARTY" or args == "GUILD") then
                NetworkSkinSyncEngine:SetSyncChannel(args)
                print("Sync channel: " .. args)
            else
                print("Usage: /skinsync channel <RAID|PARTY|GUILD>")
            end
        elseif cmd == "downloads" then
            if args == "on" then
                NetworkSkinSyncEngine:SetAllowDownloads(true)
                print("Downloads enabled")
            elseif args == "off" then
                NetworkSkinSyncEngine:SetAllowDownloads(false)
                print("Downloads disabled")
            else
                print("Usage: /skinsync downloads <on|off>")
            end
        elseif cmd == "uploads" then
            if args == "on" then
                NetworkSkinSyncEngine:SetAllowUploads(true)
                print("Uploads enabled")
            elseif args == "off" then
                NetworkSkinSyncEngine:SetAllowUploads(false)
                print("Uploads disabled")
            else
                print("Usage: /skinsync uploads <on|off>")
            end
        elseif cmd == "pending" then
            local requests = NetworkSkinSyncEngine:GetPendingRequests()
            print("Pending requests (" .. #requests .. "):")
            for _, req in ipairs(requests) do
                print("  " .. req.skin_name .. " from " .. req.requested_from)
            end
        elseif cmd == "cleanup" then
            local remaining = NetworkSkinSyncEngine:CleanupExpiredRequests()
            print("Cleaned up expired requests. Remaining: " .. remaining)
        elseif cmd == "status" then
            local status = NetworkSkinSyncEngine:GetStatus()
            print("Network Skin Sync Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Network Skin Sync Commands:")
            print("  /skinsync request <skin> <player> - Request skin from player")
            print("  /skinsync advertise [skin] - Advertise skin(s) to group")
            print("  /skinsync channel <RAID|PARTY|GUILD> - Set sync channel")
            print("  /skinsync downloads <on|off> - Allow receiving skins")
            print("  /skinsync uploads <on|off> - Allow sending skins")
            print("  /skinsync pending - Show pending requests")
            print("  /skinsync cleanup - Clean up expired requests")
            print("  /skinsync status - Show system status")
        end
    end
end

return NetworkSkinSyncEngine
