-- Raid Composition Optimizer
-- Analyzes current raid and suggests optimal compositions

local MODULE_NAME = "RaidCompositionOptimizer"
local PluribusCore = PluribusCore or {}
local PluribusPerformanceAnalytics = PluribusPerformanceAnalytics or {}

PluribusPerformanceAnalytics.CompositionOptimizer = {
    enabled = false,
    
    -- Optimal raid compositions for different scenarios
    templates = {
        mc_40man = {
            name = "Molten Core (40-man)",
            tanks = 3,
            healers = 10,
            dps = 27,
            optimal_classes = {
                tank = {"Warrior", "Paladin"},
                healer = {"Priest", "Druid", "Paladin", "Shaman"},
                dps = {"Warrior", "Rogue", "Mage", "Warlock", "Druid", "Hunter"}
            }
        },
        bwl_40man = {
            name = "Blackwing Lair (40-man)",
            tanks = 3,
            healers = 10,
            dps = 27,
            optimal_classes = {
                tank = {"Warrior", "Paladin"},
                healer = {"Priest", "Druid", "Paladin", "Shaman"},
                dps = {"Warrior", "Rogue", "Mage", "Warlock", "Druid", "Hunter"}
            }
        },
        aq_40man = {
            name = "Temple of Ahn'Qiraj (40-man)",
            tanks = 4,
            healers = 11,
            dps = 25,
            optimal_classes = {
                tank = {"Warrior", "Paladin"},
                healer = {"Priest", "Druid", "Paladin", "Shaman"},
                dps = {"Warrior", "Rogue", "Mage", "Warlock", "Druid", "Hunter"}
            }
        },
        naxx_40man = {
            name = "Naxxramas (40-man)",
            tanks = 4,
            healers = 12,
            dps = 24,
            optimal_classes = {
                tank = {"Warrior", "Paladin", "Druid"},
                healer = {"Priest", "Druid", "Paladin", "Shaman"},
                dps = {"Warrior", "Rogue", "Mage", "Warlock", "Druid", "Hunter"}
            }
        },
        pvp_bgs = {
            name = "PvP Battlegrounds",
            tanks = 1,
            healers = 3,
            dps = 6,
            optimal_classes = {
                tank = {"Warrior", "Paladin"},
                healer = {"Priest", "Druid", "Paladin", "Shaman"},
                dps = {"Warrior", "Rogue", "Mage", "Warlock", "Hunter"}
            }
        }
    },
    
    class_roles = {
        Warrior = { tank = 100, dps = 90 },
        Paladin = { tank = 80, healer = 85, dps = 40 },
        Hunter = { dps = 100 },
        Rogue = { dps = 100 },
        Priest = { healer = 100, dps = 20 },
        Shaman = { healer = 90, dps = 70 },
        Mage = { dps = 100 },
        Warlock = { dps = 100 },
        Druid = { tank = 70, healer = 90, dps = 80 }
    }
}

local Optimizer = PluribusPerformanceAnalytics.CompositionOptimizer

function Optimizer:Initialize()
    -- Setup templates
end

function Optimizer:GetCurrentRaidComposition()
    if not IsInRaid() then
        return nil
    end
    
    local composition = {
        total = GetNumGroupMembers(),
        tanks = {},
        healers = {},
        dps = {},
        by_class = {}
    }
    
    for i = 1, composition.total do
        local unit = "raid" .. i
        if UnitExists(unit) then
            local name = UnitName(unit)
            local class = select(2, UnitClass(unit))
            local role = UnitGroupRolesAssigned(unit)
            
            if not composition.by_class[class] then
                composition.by_class[class] = {}
            end
            
            table.insert(composition.by_class[class], {
                name = name,
                class = class,
                role = role or "unknown"
            })
            
            if role == "TANK" then
                table.insert(composition.tanks, name)
            elseif role == "HEALER" then
                table.insert(composition.healers, name)
            elseif role == "DAMAGER" then
                table.insert(composition.dps, name)
            end
        end
    end
    
    return composition
end

function Optimizer:AnalyzeComposition(composition, template)
    if not composition or not template then
        return nil
    end
    
    local analysis = {
        composition = composition,
        template = template,
        tanks_needed = template.tanks,
        healers_needed = template.healers,
        dps_needed = template.dps,
        tanks_actual = #composition.tanks,
        healers_actual = #composition.healers,
        dps_actual = #composition.dps,
        issues = {},
        suggestions = {}
    }
    
    -- Check tank count
    if analysis.tanks_actual < analysis.tanks_needed then
        table.insert(analysis.issues, string.format(
            "Tank shortage: %d present, %d recommended",
            analysis.tanks_actual,
            analysis.tanks_needed
        ))
    elseif analysis.tanks_actual > analysis.tanks_needed then
        table.insert(analysis.suggestions, string.format(
            "Extra tank available: consider using as off-tank DPS"
        ))
    end
    
    -- Check healer count
    if analysis.healers_actual < analysis.healers_needed then
        table.insert(analysis.issues, string.format(
            "Healer shortage: %d present, %d recommended",
            analysis.healers_actual,
            analysis.healers_needed
        ))
    elseif analysis.healers_actual > analysis.healers_needed then
        table.insert(analysis.suggestions, string.format(
            "Extra healer available: might be overhealed"
        ))
    end
    
    -- Check DPS count
    if analysis.dps_actual < analysis.dps_needed then
        table.insert(analysis.suggestions, string.format(
            "DPS below optimal: %d present, %d recommended",
            analysis.dps_actual,
            analysis.dps_needed
        ))
    end
    
    return analysis
end

function Optimizer:SuggestOptimalComposition()
    if not IsInRaid() then
        return nil
    end
    
    local raid_size = GetNumGroupMembers()
    
    local available_players = {}
    local current_composition = self:GetCurrentRaidComposition()
    
    -- Analyze what roles we have available
    for class, players in pairs(current_composition.by_class) do
        for _, player in ipairs(players) do
            if not available_players[player.role] then
                available_players[player.role] = {}
            end
            
            table.insert(available_players[player.role], {
                name = player.name,
                class = class,
                flexibility = self:GetClassFlexibility(class)
            })
        end
    end
    
    return available_players
end

function Optimizer:GetClassFlexibility(class_name)
    if not self.class_roles[class_name] then
        return 0
    end
    
    local roles = self.class_roles[class_name]
    local role_count = 0
    
    for role, value in pairs(roles) do
        if value > 0 then
            role_count = role_count + 1
        end
    end
    
    return role_count
end

function Optimizer:PrintCompositionAnalysis(template_name)
    if not IsInRaid() then
        print("|cffff0000You are not in a raid.|r")
        return
    end
    
    template_name = template_name or "mc_40man"
    local template = self.templates[template_name]
    
    if not template then
        print("|cffff0000Unknown template: " .. template_name .. "|r")
        return
    end
    
    local composition = self:GetCurrentRaidComposition()
    local analysis = self:AnalyzeComposition(composition, template)
    
    print("|cff00ccffRaid Composition Analysis|r - " .. template.name)
    print(string.rep("-", 60))
    print(string.format(
        "Current: %d Tanks, %d Healers, %d DPS (Total: %d)",
        analysis.tanks_actual,
        analysis.healers_actual,
        analysis.dps_actual,
        composition.total
    ))
    print(string.format(
        "Optimal: %d Tanks, %d Healers, %d DPS (Total: %d)",
        analysis.tanks_needed,
        analysis.healers_needed,
        analysis.dps_needed,
        analysis.tanks_needed + analysis.healers_needed + analysis.dps_needed
    ))
    print(string.rep("-", 60))
    
    if #analysis.issues > 0 then
        print("|cffff0000⚠ Issues:|r")
        for _, issue in ipairs(analysis.issues) do
            print("  - " .. issue)
        end
        print("")
    end
    
    if #analysis.suggestions > 0 then
        print("|cff00ff00✓ Suggestions:|r")
        for _, suggestion in ipairs(analysis.suggestions) do
            print("  - " .. suggestion)
        end
        print("")
    end
    
    -- Class breakdown
    print("|cff00ccffClass Breakdown:|r")
    for class, players in pairs(composition.by_class) do
        print(string.format("  %s: %d players", class, #players))
    end
    
    print(string.rep("-", 60))
end

function Optimizer:PrintClassFlexibility()
    print("|cff00ccffClass Role Flexibility|r")
    print(string.rep("-", 60))
    
    for class, roles in pairs(self.class_roles) do
        local role_list = {}
        
        for role, value in pairs(roles) do
            if value > 0 then
                table.insert(role_list, role)
            end
        end
        
        print(string.format("  %s: %s", class, table.concat(role_list, ", ")))
    end
    
    print(string.rep("-", 60))
end

-- Register slash commands
if PluribusCore.SlashCommand then
    PluribusCore.SlashCommand:Register("composition", function(args)
        if args == "analyze" then
            Optimizer:PrintCompositionAnalysis()
        elseif args == "flexible" then
            Optimizer:PrintClassFlexibility()
        elseif args ~= "" then
            Optimizer:PrintCompositionAnalysis(args)
        else
            Optimizer:PrintCompositionAnalysis()
        end
    end, "Analyze raid composition")
end

return PluribusPerformanceAnalytics.CompositionOptimizer

