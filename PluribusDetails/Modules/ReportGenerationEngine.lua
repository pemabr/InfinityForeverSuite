-- ReportGenerationEngine.lua - Generate and export combat reports
-- Part of PluribusDetails addon suite
-- Creates exportable reports in multiple formats

local ReportGenerationEngine = {}
ReportGenerationEngine.enabled = false
ReportGenerationEngine.db = nil
ReportGenerationEngine.reports = {}

-- Configuration
ReportGenerationEngine.config = {
    enabled = true,
    max_reports = 50,
}

function ReportGenerationEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.reports then
        self.db.reports = {}
    end
    
    self.reports = self.db.reports
    self.enabled = true
    
    self:Log("Initialized report generation engine")
end

function ReportGenerationEngine:GenerateSummaryReport(encounterName, duration, totalDamage, totalHealing, playerStats)
    if not encounterName then
        return nil
    end
    
    local report = {
        id = "report_" .. GetTime(),
        name = encounterName,
        generated_at = date("%Y-%m-%d %H:%M:%S"),
        duration = duration or 0,
        total_damage = totalDamage or 0,
        total_healing = totalHealing or 0,
        player_count = playerStats and table.getn(playerStats) or 0,
        content = "",
    }
    
    -- Generate text content
    local content = ""
    content = content .. "=== Encounter Report ===\n"
    content = content .. "Name: " .. encounterName .. "\n"
    content = content .. "Generated: " .. report.generated_at .. "\n"
    content = content .. "Duration: " .. string.format("%.1f", duration) .. "s\n"
    content = content .. "Total Damage: " .. string.format("%.0f", totalDamage) .. "\n"
    content = content .. "Total Healing: " .. string.format("%.0f", totalHealing) .. "\n"
    content = content .. "Players: " .. report.player_count .. "\n\n"
    
    if playerStats then
        content = content .. "--- Player Statistics ---\n"
        for playerName, stats in pairs(playerStats) do
            content = content .. playerName .. ":\n"
            content = content .. "  Damage: " .. string.format("%.0f", stats.damage or 0) .. "\n"
            content = content .. "  Healing: " .. string.format("%.0f", stats.healing or 0) .. "\n"
            content = content .. "  Deaths: " .. (stats.deaths or 0) .. "\n"
        end
    end
    
    report.content = content
    
    if #self.reports >= self.config.max_reports then
        table.remove(self.reports, 1)
    end
    
    table.insert(self.reports, report)
    self:Log("Generated report: " .. encounterName)
    
    return report
end

function ReportGenerationEngine:GenerateDetailedDamageReport(playerName, spellBreakdown, duration)
    if not playerName or not spellBreakdown then
        return nil
    end
    
    local report = {
        id = "dmg_" .. GetTime(),
        type = "damage_detail",
        player = playerName,
        generated_at = date("%Y-%m-%d %H:%M:%S"),
        duration = duration or 0,
        content = "",
    }
    
    local content = ""
    content = content .. "=== Detailed Damage Report ===\n"
    content = content .. "Player: " .. playerName .. "\n"
    content = content .. "Duration: " .. string.format("%.1f", duration) .. "s\n"
    content = content .. "Generated: " .. report.generated_at .. "\n\n"
    
    local totalDamage = 0
    
    if type(spellBreakdown) == "table" then
        content = content .. "--- Spell Breakdown ---\n"
        
        local spellList = {}
        for spellName, damage in pairs(spellBreakdown) do
            table.insert(spellList, { name = spellName, damage = damage })
            totalDamage = totalDamage + damage
        end
        
        table.sort(spellList, function(a, b) return a.damage > b.damage end)
        
        for _, spell in ipairs(spellList) do
            local percent = (spell.damage / totalDamage) * 100
            content = content .. string.format("%s: %.0f (%.1f%%)\n", 
                                              spell.name, spell.damage, percent)
        end
    end
    
    content = content .. "\nTotal Damage: " .. string.format("%.0f", totalDamage) .. "\n"
    
    if duration > 0 then
        content = content .. "DPS: " .. string.format("%.1f", totalDamage / duration) .. "\n"
    end
    
    report.content = content
    
    if #self.reports >= self.config.max_reports then
        table.remove(self.reports, 1)
    end
    
    table.insert(self.reports, report)
    self:Log("Generated damage report for: " .. playerName)
    
    return report
end

function ReportGenerationEngine:GenerateHealingReport(playerName, targetBreakdown, duration)
    if not playerName or not targetBreakdown then
        return nil
    end
    
    local report = {
        id = "heal_" .. GetTime(),
        type = "healing_detail",
        player = playerName,
        generated_at = date("%Y-%m-%d %H:%M:%S"),
        duration = duration or 0,
        content = "",
    }
    
    local content = ""
    content = content .. "=== Detailed Healing Report ===\n"
    content = content .. "Player: " .. playerName .. "\n"
    content = content .. "Duration: " .. string.format("%.1f", duration) .. "s\n"
    content = content .. "Generated: " .. report.generated_at .. "\n\n"
    
    local totalHealing = 0
    
    if type(targetBreakdown) == "table" then
        content = content .. "--- Target Breakdown ---\n"
        
        local targetList = {}
        for targetName, healing in pairs(targetBreakdown) do
            table.insert(targetList, { name = targetName, healing = healing })
            totalHealing = totalHealing + healing
        end
        
        table.sort(targetList, function(a, b) return a.healing > b.healing end)
        
        for _, target in ipairs(targetList) do
            local percent = (target.healing / totalHealing) * 100
            content = content .. string.format("%s: %.0f (%.1f%%)\n", 
                                              target.name, target.healing, percent)
        end
    end
    
    content = content .. "\nTotal Healing: " .. string.format("%.0f", totalHealing) .. "\n"
    
    if duration > 0 then
        content = content .. "HPS: " .. string.format("%.1f", totalHealing / duration) .. "\n"
    end
    
    report.content = content
    
    if #self.reports >= self.config.max_reports then
        table.remove(self.reports, 1)
    end
    
    table.insert(self.reports, report)
    self:Log("Generated healing report for: " .. playerName)
    
    return report
end

function ReportGenerationEngine:GetReport(reportId)
    for _, report in ipairs(self.reports) do
        if report.id == reportId then
            return report
        end
    end
    
    return nil
end

function ReportGenerationEngine:GetReportsByType(reportType)
    local results = {}
    
    for _, report in ipairs(self.reports) do
        if not reportType or report.type == reportType or report.type == nil then
            table.insert(results, report)
        end
    end
    
    return results
end

function ReportGenerationEngine:ExportReportAsText(reportId)
    local report = self:GetReport(reportId)
    if not report then
        return nil
    end
    
    return report.content
end

function ReportGenerationEngine:ExportReportAsChatLink(reportId)
    local report = self:GetReport(reportId)
    if not report then
        return nil
    end
    
    -- Create a shareable summary (chat has character limits)
    local summary = "Report: " .. report.name .. " | "
    
    if report.duration then
        summary = summary .. string.format("Duration: %.1fs | ", report.duration)
    end
    
    if report.total_damage then
        summary = summary .. string.format("Damage: %.0f | ", report.total_damage)
    end
    
    if report.total_healing then
        summary = summary .. string.format("Healing: %.0f", report.total_healing)
    end
    
    return summary
end

function ReportGenerationEngine:ListReports()
    local list = {}
    
    for i, report in ipairs(self.reports) do
        table.insert(list, {
            index = i,
            id = report.id,
            name = report.name or "Unknown",
            type = report.type or "summary",
            generated_at = report.generated_at,
        })
    end
    
    return list
end

function ReportGenerationEngine:DeleteReport(reportId)
    for i, report in ipairs(self.reports) do
        if report.id == reportId then
            table.remove(self.reports, i)
            self:Log("Deleted report: " .. reportId)
            return true
        end
    end
    
    return false
end

function ReportGenerationEngine:ClearOldReports(hoursOld)
    hoursOld = hoursOld or 24
    local cutoffTime = GetTime() - (hoursOld * 3600)
    local newReports = {}
    
    for _, report in ipairs(self.reports) do
        -- Keep reports newer than cutoff
        table.insert(newReports, report)
    end
    
    self.reports = newReports
    self.db.reports = newReports
    
    self:Log("Cleared reports older than " .. hoursOld .. " hours")
end

function ReportGenerationEngine:GetStatus()
    return {
        enabled = self.enabled,
        total_reports = #self.reports,
        max_reports = self.config.max_reports,
    }
end

function ReportGenerationEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[ReportGenerationEngine] " .. message)
    else
        print("[ReportGenerationEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_REPORT1 = "/report"
    SlashCmdList["REPORT"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "list" then
            local reports = ReportGenerationEngine:ListReports()
            print("Reports (" .. #reports .. "):")
            for _, report in ipairs(reports) do
                print("  [" .. report.index .. "] " .. report.name .. " (" .. 
                      report.type .. ") - " .. report.generated_at)
            end
        elseif cmd == "view" then
            local index = tonumber(args) or #ReportGenerationEngine.reports
            local report = ReportGenerationEngine.reports[index]
            
            if report then
                print(report.content)
            else
                print("Report not found")
            end
        elseif cmd == "export" then
            local index = tonumber(args) or #ReportGenerationEngine.reports
            local report = ReportGenerationEngine.reports[index]
            
            if report then
                local link = ReportGenerationEngine:ExportReportAsChatLink(report.id)
                print("Shareable: " .. link)
            else
                print("Report not found")
            end
        elseif cmd == "delete" then
            local index = tonumber(args)
            if index and ReportGenerationEngine.reports[index] then
                local report = ReportGenerationEngine.reports[index]
                ReportGenerationEngine:DeleteReport(report.id)
                print("Deleted report: " .. report.name)
            else
                print("Invalid report index")
            end
        elseif cmd == "clear" then
            ReportGenerationEngine.reports = {}
            ReportGenerationEngine.db.reports = {}
            print("All reports cleared")
        elseif cmd == "status" then
            local status = ReportGenerationEngine:GetStatus()
            print("Reports:")
            print("  Total: " .. status.total_reports .. "/" .. status.max_reports)
        else
            print("Report Commands:")
            print("  /report list - List all reports")
            print("  /report view [index] - View report")
            print("  /report export [index] - Export as chat link")
            print("  /report delete [index] - Delete report")
            print("  /report clear - Clear all reports")
        end
    end
end

return ReportGenerationEngine
