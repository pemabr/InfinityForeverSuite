-- DataBrokerEngine.lua - Minimap and data broker integration
-- Part of PluribusDetails addon suite
-- Provides quick access to metrics via DataBroker plugin

local DataBrokerEngine = {}
DataBrokerEngine.enabled = false
DataBrokerEngine.db = nil
DataBrokerEngine.broker_obj = nil
DataBrokerEngine.update_interval = 1  -- Update every second

-- Configuration
DataBrokerEngine.config = {
    enabled = true,
    show_dps = true,
    show_hps = true,
    show_threat = false,
}

function DataBrokerEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusDetails")
    if not self.db then
        self.db = {}
    end
    
    self.enabled = true
    
    self:Log("Initialized data broker engine")
end

function DataBrokerEngine:CreateBrokerObject(brokerName)
    if not brokerName then
        return nil
    end
    
    self.broker_obj = {
        type = "data source",
        icon = "Interface\\Icons\\Inv_Misc_Wrench_01",
        text = "Pluribus Details",
        value = "0 DPS",
        suffix = "",
        OnClick = function(self, button)
            DataBrokerEngine:OnBrokerClick(button)
        end,
        OnEnter = function(self)
            DataBrokerEngine:OnBrokerEnter(self)
        end,
        OnLeave = function(self)
            DataBrokerEngine:OnBrokerLeave(self)
        end,
    }
    
    self:Log("Created broker object: " .. brokerName)
    
    return self.broker_obj
end

function DataBrokerEngine:UpdateBrokerText(dps, hps, threat)
    if not self.broker_obj then
        return false
    end
    
    local text = ""
    
    if self.config.show_dps and dps and dps > 0 then
        text = string.format("%.0f DPS", dps)
    end
    
    if self.config.show_hps and hps and hps > 0 then
        if text ~= "" then
            text = text .. " / "
        end
        text = text .. string.format("%.0f HPS", hps)
    end
    
    if self.config.show_threat and threat and threat > 0 then
        if text ~= "" then
            text = text .. " / "
        end
        text = text .. string.format("%.0f Threat", threat)
    end
    
    if text == "" then
        text = "Idle"
    end
    
    self.broker_obj.text = "Details"
    self.broker_obj.value = text
    
    return true
end

function DataBrokerEngine:OnBrokerClick(button)
    if button == "LeftButton" then
        -- Toggle main window
        if PluribusCore and PluribusCore.Events then
            PluribusCore.Events:Fire("ToggleDetailsWindow")
        end
    elseif button == "RightButton" then
        -- Show menu
        if PluribusCore and PluribusCore.Events then
            PluribusCore.Events:Fire("ShowDetailsMenu")
        end
    end
end

function DataBrokerEngine:OnBrokerEnter(frame)
    if not frame then
        return
    end
    
    -- Create tooltip if available
    if GameTooltip then
        GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
        GameTooltip:AddLine("Pluribus Details")
        GameTooltip:AddLine("Combat metrics addon", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-Click: Toggle window", 0.5, 0.8, 1)
        GameTooltip:AddLine("Right-Click: Show menu", 0.5, 0.8, 1)
        GameTooltip:Show()
    end
end

function DataBrokerEngine:OnBrokerLeave(frame)
    if GameTooltip then
        GameTooltip:Hide()
    end
end

function DataBrokerEngine:RegisterBrokerData(brokerName, addon)
    if not brokerName or not addon then
        return nil
    end
    
    -- Create LibDataBroker-compatible object
    local ldb = {
        type = "data source",
        icon = "Interface\\Icons\\Inv_Misc_Wrench_01",
        text = "Pluribus Details",
        value = "0 DPS",
        label = "Pluribus Details",
    }
    
    return ldb
end

function DataBrokerEngine:GetBrokerStatus()
    if not self.broker_obj then
        return "No broker object created"
    end
    
    return {
        text = self.broker_obj.text,
        value = self.broker_obj.value,
        icon = self.broker_obj.icon,
    }
end

function DataBrokerEngine:SetBrokerConfig(configKey, configValue)
    if configKey and self.config[configKey] ~= nil then
        self.config[configKey] = configValue
        return true
    end
    
    return false
end

function DataBrokerEngine:GetBrokerConfig(configKey)
    if configKey then
        return self.config[configKey]
    end
    
    return self.config
end

function DataBrokerEngine:GetStatus()
    return {
        enabled = self.enabled,
        broker_active = self.broker_obj ~= nil,
        show_dps = self.config.show_dps,
        show_hps = self.config.show_hps,
        show_threat = self.config.show_threat,
    }
end

function DataBrokerEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[DataBrokerEngine] " .. message)
    else
        print("[DataBrokerEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_BROKER1 = "/broker"
    SlashCmdList["BROKER"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "create" then
            DataBrokerEngine:CreateBrokerObject("PluribusDetails")
            print("Broker object created")
        elseif cmd == "update" then
            local dps, hps = tonumber(args) or 0, 0
            DataBrokerEngine:UpdateBrokerText(dps, hps, 0)
            print("Broker updated")
        elseif cmd == "dps" then
            local enabled = string.find(args or "toggle", "on") ~= nil or 
                           (string.find(args or "toggle", "off") == nil and 
                            not DataBrokerEngine.config.show_dps)
            DataBrokerEngine:SetBrokerConfig("show_dps", enabled)
            print("Show DPS: " .. (enabled and "ON" or "OFF"))
        elseif cmd == "hps" then
            local enabled = string.find(args or "toggle", "on") ~= nil or 
                           (string.find(args or "toggle", "off") == nil and 
                            not DataBrokerEngine.config.show_hps)
            DataBrokerEngine:SetBrokerConfig("show_hps", enabled)
            print("Show HPS: " .. (enabled and "ON" or "OFF"))
        elseif cmd == "threat" then
            local enabled = string.find(args or "toggle", "on") ~= nil or 
                           (string.find(args or "toggle", "off") == nil and 
                            not DataBrokerEngine.config.show_threat)
            DataBrokerEngine:SetBrokerConfig("show_threat", enabled)
            print("Show Threat: " .. (enabled and "ON" or "OFF"))
        elseif cmd == "status" then
            local status = DataBrokerEngine:GetStatus()
            print("Data Broker:")
            print("  Enabled: " .. (status.enabled and "YES" or "NO"))
            print("  Broker Active: " .. (status.broker_active and "YES" or "NO"))
            print("  Show DPS: " .. (status.show_dps and "YES" or "NO"))
            print("  Show HPS: " .. (status.show_hps and "YES" or "NO"))
            print("  Show Threat: " .. (status.show_threat and "YES" or "NO"))
        else
            print("Data Broker Commands:")
            print("  /broker create - Create broker object")
            print("  /broker update <dps> - Update broker text")
            print("  /broker dps [on|off] - Toggle DPS display")
            print("  /broker hps [on|off] - Toggle HPS display")
            print("  /broker threat [on|off] - Toggle threat display")
            print("  /broker status - Show system status")
        end
    end
end

return DataBrokerEngine
