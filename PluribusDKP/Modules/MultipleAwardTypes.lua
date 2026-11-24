-- Multiple Award Types System
-- Assign different DKP point values to different award types

local MODULE_NAME = "MultipleAwardTypes"
local PluribusDKP = PluribusDKP or {}
local PluribusCore = PluribusCore or {}

PluribusDKP.AwardTypes = {
    enabled = false,
    
    config = {
        -- Award type definitions with their point values
        award_types = {
            MS = {
                name = "Main Spec",
                gp_value = 100,
                ep_value = 50,
                color = {r = 0, g = 1, b = 0},
                description = "Main spec item - full value"
            },
            OS = {
                name = "Off Spec",
                gp_value = 75,
                ep_value = 35,
                color = {r = 1, g = 1, b = 0},
                description = "Off spec item - 75% value"
            },
            Offspec = {
                name = "Generic Offspec",
                gp_value = 50,
                ep_value = 25,
                color = {r = 1, g = 0.65, b = 0},
                description = "Generic offspec - 50% value"
            },
            Bank = {
                name = "Guild Bank",
                gp_value = 25,
                ep_value = 10,
                color = {r = 1, g = 0, b = 0},
                description = "Guild bank/storage - 25% value"
            }
        },
        
        -- Configuration
        custom_types_enabled = true,
        gp_calculation_method = "fixed",  -- "fixed" or "percentage"
        ep_calculation_method = "fixed",  -- "fixed" or "percentage"
        base_item_value = 100  -- Base value for percentage calculations
    },
    
    custom_award_types = {},
    award_history = {}
}

local AwardTypes = PluribusDKP.AwardTypes

function AwardTypes:Initialize()
    if self.enabled then return end
    
    self.enabled = true
    
    if not PluribusDKP.db then
        PluribusDKP.db = {}
    end
    if not PluribusDKP.db.award_types then
        PluribusDKP.db.award_types = {}
    end
    if not PluribusDKP.db.award_history then
        PluribusDKP.db.award_history = {}
    end
    
    -- Load saved award types
    self.award_types = PluribusDKP.db.award_types
    self.award_history = PluribusDKP.db.award_history
    
    if PluribusCore.Events then
        PluribusCore.Events:Register("loot_awarded", function(player, item, award_type, gp)
            AwardTypes:RecordAward(player, item, award_type, gp)
        end)
    end
end

function AwardTypes:GetAwardType(award_type_name)
    -- Check standard types first
    if self.config.award_types[award_type_name] then
        return self.config.award_types[award_type_name]
    end
    
    -- Check custom types
    if self.custom_award_types[award_type_name] then
        return self.custom_award_types[award_type_name]
    end
    
    return nil
end

function AwardTypes:GetGPValue(award_type_name, base_value)
    base_value = base_value or self.config.base_item_value
    
    local award_type = self:GetAwardType(award_type_name)
    if not award_type then
        return 0
    end
    
    if self.config.gp_calculation_method == "percentage" then
        return math.floor(base_value * (award_type.gp_value / 100))
    else
        return award_type.gp_value
    end
end

function AwardTypes:GetEPValue(award_type_name, base_value)
    base_value = base_value or self.config.base_item_value
    
    local award_type = self:GetAwardType(award_type_name)
    if not award_type then
        return 0
    end
    
    if self.config.ep_calculation_method == "percentage" then
        return math.floor(base_value * (award_type.ep_value / 100))
    else
        return award_type.ep_value
    end
end

function AwardTypes:SetAwardTypeGPValue(award_type_name, gp_value)
    local award_type = self:GetAwardType(award_type_name)
    if not award_type then
        print("|cffff0000Award type not found: " .. award_type_name .. "|r")
        return false
    end
    
    if gp_value < 1 or gp_value > 1000 then
        print("|cffff0000GP value must be 1-1000|r")
        return false
    end
    
    award_type.gp_value = gp_value
    
    print(string.format("|cff00ccff%s GP value set to %d|r", award_type_name, gp_value))
    return true
end

function AwardTypes:SetAwardTypeEPValue(award_type_name, ep_value)
    local award_type = self:GetAwardType(award_type_name)
    if not award_type then
        print("|cffff0000Award type not found: " .. award_type_name .. "|r")
        return false
    end
    
    if ep_value < 1 or ep_value > 1000 then
        print("|cffff0000EP value must be 1-1000|r")
        return false
    end
    
    award_type.ep_value = ep_value
    
    print(string.format("|cff00ccff%s EP value set to %d|r", award_type_name, ep_value))
    return true
end

function AwardTypes:CreateCustomAwardType(type_name, name, gp_value, ep_value, color_str)
    if self.custom_award_types[type_name] then
        print("|cffff0000Award type already exists|r")
        return false
    end
    
    if gp_value < 1 or gp_value > 1000 or ep_value < 1 or ep_value > 1000 then
        print("|cffff0000Values must be 1-1000|r")
        return false
    end
    
    self.custom_award_types[type_name] = {
        name = name or type_name,
        gp_value = gp_value,
        ep_value = ep_value,
        color_str = color_str or "ffffff",
        description = "Custom award type"
    }
    
    print(string.format("|cff00ccffCreated custom award type: %s|r", type_name))
    return true
end

function AwardTypes:RemoveCustomAwardType(type_name)
    if not self.custom_award_types[type_name] then
        print("|cffff0000Custom award type not found|r")
        return false
    end
    
    self.custom_award_types[type_name] = nil
    
    print(string.format("|cff00ccffRemoved custom award type: %s|r", type_name))
    return true
end

function AwardTypes:RecordAward(player, item, award_type, gp_cost)
    if not player or not item or not award_type then
        return
    end
    
    table.insert(self.award_history, {
        timestamp = time(),
        player = player,
        item = item,
        award_type = award_type,
        gp_cost = gp_cost,
        ep_earned = self:GetEPValue(award_type)
    })
    
    if PluribusDKP.db then
        PluribusDKP.db.award_history = self.award_history
    end
end

function AwardTypes:SetCalculationMethod(method_type, method)
    if method_type ~= "gp" and method_type ~= "ep" then
        print("|cffff0000Method type must be 'gp' or 'ep'|r")
        return false
    end
    
    if method ~= "fixed" and method ~= "percentage" then
        print("|cffff0000Method must be 'fixed' or 'percentage'|r")
        return false
    end
    
    if method_type == "gp" then
        self.config.gp_calculation_method = method
    else
        self.config.ep_calculation_method = method
    end
    
    print(string.format("|cff00ccff%s calculation method set to %s|r", method_type:upper(), method))
    return true
end

function AwardTypes:SetBaseItemValue(value)
    if value < 1 or value > 10000 then
        print("|cffff0000Base value must be 1-10000|r")
        return false
    end
    
    self.config.base_item_value = value
    print(string.format("|cff00ccffBase item value set to %d|r", value))
    return true
end

function AwardTypes:PrintAwardTypes()
    print("|cff00ccffAvailable Award Types:|r")
    print("")
    
    print("Standard Types:")
    for type_name, award_type in pairs(self.config.award_types) do
        print(string.format("  %s: %s (GP: %d, EP: %d)",
            type_name,
            award_type.name,
            award_type.gp_value,
            award_type.ep_value
        ))
    end
    
    if next(self.custom_award_types) then
        print("")
        print("Custom Types:")
        for type_name, award_type in pairs(self.custom_award_types) do
            print(string.format("  %s: %s (GP: %d, EP: %d)",
                type_name,
                award_type.name,
                award_type.gp_value,
                award_type.ep_value
            ))
        end
    end
    
    print("")
end

function AwardTypes:PrintAwardComparison()
    print("|cff00ccffAward Type Comparison (Base Item = 100 GP):|r")
    print("")
    print("Type        | GP Value | EP Value | % of MS")
    print("------------ | -------- | -------- | -------")
    
    for type_name, award_type in pairs(self.config.award_types) do
        local gp_pct = (award_type.gp_value / self.config.award_types.MS.gp_value) * 100
        print(string.format("%-11s | %8d | %8d | %6.0f%%",
            type_name,
            award_type.gp_value,
            award_type.ep_value,
            gp_pct
        ))
    end
    
    print("")
end

function AwardTypes:PrintStatus()
    print("|cff00ccffAward Types System Status:|r")
    print(string.format("  Enabled: %s", self.enabled and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print(string.format("  GP Method: %s", self.config.gp_calculation_method))
    print(string.format("  EP Method: %s", self.config.ep_calculation_method))
    print(string.format("  Base Value: %d", self.config.base_item_value))
    print(string.format("  Standard Types: %d", self:CountStandardTypes()))
    print(string.format("  Custom Types: %d", self:CountCustomTypes()))
    print(string.format("  Awards Recorded: %d", #self.award_history))
    print("")
end

function AwardTypes:CountStandardTypes()
    local count = 0
    for _ in pairs(self.config.award_types) do
        count = count + 1
    end
    return count
end

function AwardTypes:CountCustomTypes()
    local count = 0
    for _ in pairs(self.custom_award_types) do
        count = count + 1
    end
    return count
end

function AwardTypes:GetAwardHistory(limit)
    limit = limit or 20
    
    local history = {}
    for i = #self.award_history, math.max(1, #self.award_history - limit + 1), -1 do
        table.insert(history, self.award_history[i])
    end
    
    return history
end

function AwardTypes:PrintAwardHistory()
    local history = self:GetAwardHistory(10)
    
    print("|cff00ccffRecent Awards by Type:|r")
    print("")
    
    for _, award in ipairs(history) do
        local date_str = date("%H:%M:%S", award.timestamp)
        print(string.format("[%s] %s - %s (%s) [GP: %d, EP: %d]",
            date_str,
            award.player or "Unknown",
            award.item or "Unknown",
            award.award_type or "Unknown",
            award.gp_cost or 0,
            award.ep_earned or 0
        ))
    end
    
    print("")
end

return PluribusDKP.AwardTypes
