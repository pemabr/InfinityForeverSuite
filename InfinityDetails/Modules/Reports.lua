-- Reports Module
-- Generate combat analysis reports

local InfinityDetailsReports = {}
_G.InfinityDetailsReports = InfinityDetailsReports

function InfinityDetailsReports:GenerateDPSReport()
    local report = "=== DPS Report ===\n"
    
    if InfinityDetailsMeters then
        local dpsMeter = InfinityDetailsMeters:GetDPSMeter(20)
        report = report .. string.format("Duration: %.1f seconds\n\n", InfinityDetailsMeters.duration)
        report = report .. string.format("%-3s %-20s %-15s %-15s %-10s\n", 
            "#", "Name", "DPS", "Total Damage", "Crits")
        report = report .. string.rep("-", 65) .. "\n"
        
        for _, entry in ipairs(dpsMeter) do
            report = report .. string.format("%-3d %-20s %-15.1f %-15d %-10.1f%%\n",
                entry.rank, entry.name, entry.dps, entry.damage, entry.crits)
        end
    end
    
    return report
end

function InfinityDetailsReports:GenerateHPSReport()
    local report = "=== HPS Report ===\n"
    
    if InfinityDetailsMeters then
        local hpsMeter = InfinityDetailsMeters:GetHPSMeter(20)
        report = report .. string.format("Duration: %.1f seconds\n\n", InfinityDetailsMeters.duration)
        report = report .. string.format("%-3s %-20s %-15s %-15s %-15s\n",
            "#", "Name", "HPS", "Total Healing", "Overheal")
        report = report .. string.rep("-", 70) .. "\n"
        
        for _, entry in ipairs(hpsMeter) do
            report = report .. string.format("%-3d %-20s %-15.1f %-15d %-15d\n",
                entry.rank, entry.name, entry.hps, entry.healing, entry.overheal)
        end
    end
    
    return report
end

function InfinityDetailsReports:GenerateThreatReport()
    local report = "=== Threat Report ===\n"
    
    if InfinityDetailsMeters then
        local threatMeter = InfinityDetailsMeters:GetThreatMeter(20)
        report = report .. string.format("Duration: %.1f seconds\n\n", InfinityDetailsMeters.duration)
        report = report .. string.format("%-3s %-20s %-15s %-15s\n",
            "#", "Name", "TPS", "Total Threat")
        report = report .. string.rep("-", 55) .. "\n"
        
        for _, entry in ipairs(threatMeter) do
            report = report .. string.format("%-3d %-20s %-15.1f %-15d\n",
                entry.rank, entry.name, entry.tps, entry.threat)
        end
    end
    
    return report
end

function InfinityDetailsReports:GenerateDeathReport()
    local report = "=== Death Report ===\n"
    
    if InfinityDetailsDeaths then
        local deaths = InfinityDetailsDeaths:GetDeaths()
        report = report .. string.format("Total Deaths: %d\n\n", #deaths)
        
        if #deaths > 0 then
            for _, death in ipairs(deaths) do
                report = report .. string.format("%s - %s killed by %s\n",
                    death.timestamp, death.player, death.killedBy)
            end
        else
            report = report .. "No deaths recorded"
        end
    end
    
    return report
end

function InfinityDetailsReports:GenerateFullReport()
    local report = ""
    report = report .. self:GenerateDPSReport() .. "\n"
    report = report .. self:GenerateHPSReport() .. "\n"
    report = report .. self:GenerateThreatReport() .. "\n"
    report = report .. self:GenerateDeathReport()
    
    return report
end

return InfinityDetailsReports
