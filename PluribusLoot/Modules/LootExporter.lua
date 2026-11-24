-- Loot Export System
-- Export loot history and DKP data to various formats

local MODULE_NAME = "LootExporter"
local PluribusLoot = PluribusLoot or {}
local PluribusDKP = PluribusDKP or {}
local PluribusCore = PluribusCore or {}

PluribusLoot.LootExporter = {
    enabled = false,
    
    config = {
        default_format = "text",
        date_format = "%Y-%m-%d %H:%M:%S",
        include_prices = true,
        include_descriptions = true
    }
}

local Exporter = PluribusLoot.LootExporter

function Exporter:ExportLootHistoryCSV(limit)
    limit = limit or 1000
    
    if not PluribusLoot or not PluribusLoot.db or not PluribusLoot.db.loot_history then
        return "No loot history available."
    end
    
    local csv = "Date,Winner,Item,Rarity,GP Cost,Source,Notes\n"
    
    local count = 0
    for i = #PluribusLoot.db.loot_history, 1, -1 do
        local entry = PluribusLoot.db.loot_history[i]
        
        if entry then
            local date_str = date(self.config.date_format, entry.timestamp or 0)
            local rarity = entry.rarity or "Unknown"
            local gp_cost = entry.gp_cost or 0
            local source = entry.source or "Unknown"
            local notes = (entry.notes or ""):gsub(",", ";") -- Escape commas
            
            csv = csv .. string.format(
                "%s,%s,%s,%s,%d,%s,%s\n",
                date_str,
                entry.winner or "Unknown",
                entry.item_name or "Unknown",
                rarity,
                gp_cost,
                source,
                notes
            )
            
            count = count + 1
            if count >= limit then
                break
            end
        end
    end
    
    return csv
end

function Exporter:ExportDKPLedgerCSV(limit)
    limit = limit or 1000
    
    if not PluribusDKP or not PluribusDKP.db or not PluribusDKP.db.transactions then
        return "No DKP history available."
    end
    
    local csv = "Date,Player,Type,Amount,Reason,Balance After,Reference\n"
    
    local count = 0
    for i = #PluribusDKP.db.transactions, 1, -1 do
        local tx = PluribusDKP.db.transactions[i]
        
        if tx then
            local date_str = date(self.config.date_format, tx.timestamp or 0)
            local type_str = tx.amount > 0 and "Award" or "Spend"
            local reason = (tx.reason or ""):gsub(",", ";")
            
            csv = csv .. string.format(
                "%s,%s,%s,%d,%s,%d,%s\n",
                date_str,
                tx.player or "Unknown",
                type_str,
                math.abs(tx.amount),
                reason,
                tx.balance_after or 0,
                tx.source or ""
            )
            
            count = count + 1
            if count >= limit then
                break
            end
        end
    end
    
    return csv
end

function Exporter:ExportRaidCompositionCSV()
    if not IsInRaid() then
        return "Not in raid."
    end
    
    local csv = "Rank,Name,Class,Level,Role,Zone\n"
    
    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        if UnitExists(unit) then
            local name = UnitName(unit)
            local class = select(2, UnitClass(unit))
            local level = UnitLevel(unit)
            local role = UnitGroupRolesAssigned(unit) or "Unknown"
            local zone = GetRealZoneText()
            
            csv = csv .. string.format(
                "%d,%s,%s,%d,%s,%s\n",
                i,
                name or "Unknown",
                class or "Unknown",
                level,
                role,
                zone
            )
        end
    end
    
    return csv
end

function Exporter:ExportPlayerStatsCSV()
    if not PluribusDKP or not PluribusDKP.db or not PluribusDKP.db.players then
        return "No player data available."
    end
    
    local csv = "Player,Balance,Earned,Spent,Ratio,Last Updated\n"
    
    for player_name, player_data in pairs(PluribusDKP.db.players) do
        local balance = player_data.balance or 0
        local earned = player_data.earned or 0
        local spent = player_data.spent or 0
        local ratio = earned > 0 and (spent / earned) or 0
        local last_updated = date(self.config.date_format, player_data.last_updated or 0)
        
        csv = csv .. string.format(
            "%s,%d,%d,%d,%.2f,%s\n",
            player_name,
            balance,
            earned,
            spent,
            ratio,
            last_updated
        )
    end
    
    return csv
end

function Exporter:ExportLootHistoryHTML()
    if not PluribusLoot or not PluribusLoot.db or not PluribusLoot.db.loot_history then
        return "<p>No loot history available.</p>"
    end
    
    local html = [[
<html>
<head>
    <title>Loot History Report</title>
    <style>
        body { font-family: Arial, sans-serif; background: #f0f0f0; }
        table { border-collapse: collapse; width: 100%; background: white; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        tr:hover { background-color: #f5f5f5; }
        .common { background-color: #fff; }
        .uncommon { background-color: #1eff00; }
        .rare { background-color: #0070dd; color: white; }
        .epic { background-color: #a335ee; color: white; }
        .legendary { background-color: #ff8000; color: white; }
    </style>
</head>
<body>
    <h1>Loot History Report</h1>
    <p>Generated: ]] .. date("%Y-%m-%d %H:%M:%S") .. [[</p>
    <table>
        <tr>
            <th>Date</th>
            <th>Winner</th>
            <th>Item</th>
            <th>Rarity</th>
            <th>GP Cost</th>
            <th>Source</th>
        </tr>
]]
    
    for i = #PluribusLoot.db.loot_history, math.max(1, #PluribusLoot.db.loot_history - 500), -1 do
        local entry = PluribusLoot.db.loot_history[i]
        
        if entry then
            local date_str = date("%Y-%m-%d %H:%M", entry.timestamp or 0)
            local rarity = entry.rarity or "Unknown"
            local rarity_class = rarity:lower():gsub(" ", "_")
            
            html = html .. string.format(
                "        <tr><td>%s</td><td>%s</td><td>%s</td><td class='%s'>%s</td><td>%d</td><td>%s</td></tr>\n",
                date_str,
                entry.winner or "Unknown",
                entry.item_name or "Unknown",
                rarity_class,
                rarity,
                entry.gp_cost or 0,
                entry.source or "Unknown"
            )
        end
    end
    
    html = html .. [[
    </table>
</body>
</html>
]]
    
    return html
end

function Exporter:ExportDKPLedgerHTML()
    if not PluribusDKP or not PluribusDKP.db or not PluribusDKP.db.transactions then
        return "<p>No DKP data available.</p>"
    end
    
    local html = [[
<html>
<head>
    <title>DKP Ledger Report</title>
    <style>
        body { font-family: Arial, sans-serif; background: #f0f0f0; }
        table { border-collapse: collapse; width: 100%; background: white; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #2196F3; color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        tr:hover { background-color: #f5f5f5; }
        .award { color: green; }
        .spend { color: red; }
    </style>
</head>
<body>
    <h1>DKP Ledger Report</h1>
    <p>Generated: ]] .. date("%Y-%m-%d %H:%M:%S") .. [[</p>
    <table>
        <tr>
            <th>Date</th>
            <th>Player</th>
            <th>Type</th>
            <th>Amount</th>
            <th>Reason</th>
            <th>Balance</th>
        </tr>
]]
    
    for i = #PluribusDKP.db.transactions, math.max(1, #PluribusDKP.db.transactions - 1000), -1 do
        local tx = PluribusDKP.db.transactions[i]
        
        if tx then
            local date_str = date("%Y-%m-%d %H:%M", tx.timestamp or 0)
            local type_str = tx.amount > 0 and "Award" or "Spend"
            local type_class = tx.amount > 0 and "award" or "spend"
            
            html = html .. string.format(
                "        <tr><td>%s</td><td>%s</td><td class='%s'>%s</td><td>%d</td><td>%s</td><td>%d</td></tr>\n",
                date_str,
                tx.player or "Unknown",
                type_class,
                type_str,
                math.abs(tx.amount),
                tx.reason or "Unknown",
                tx.balance_after or 0
            )
        end
    end
    
    html = html .. [[
    </table>
</body>
</html>
]]
    
    return html
end

function Exporter:PrintExportOptions()
    print("|cff00ccffLoot Exporter|r")
    print("Usage: /export <format> [type]")
    print("")
    print("Formats:")
    print("  |cffff9900text|r - Display in chat (truncated)")
    print("  |cffff9900csv|r - Comma-separated values")
    print("  |cffff9900html|r - HTML web page")
    print("")
    print("Types:")
    print("  |cffff9900loot|r - Loot history (default)")
    print("  |cffff9900dkp|r - DKP ledger")
    print("  |cffff9900composition|r - Current raid composition")
    print("  |cffff9900stats|r - Player statistics")
    print("")
    print("Examples:")
    print("  |cffff9900/export csv loot|r - Export loot history as CSV")
    print("  |cffff9900/export html dkp|r - Export DKP ledger as HTML")
    print("  |cffff9900/export csv stats|r - Export player stats as CSV")
end

-- Register slash commands
if PluribusCore.SlashCommand then
    PluribusCore.SlashCommand:Register("export", function(args)
        local format, data_type = string.match(args, "(%w+)%s*(%w*)")
        format = format or "text"
        data_type = data_type or "loot"
        
        if format == "help" or args == "" then
            Exporter:PrintExportOptions()
            return
        end
        
        local data = ""
        
        if data_type == "loot" then
            if format == "csv" then
                data = Exporter:ExportLootHistoryCSV()
            elseif format == "html" then
                data = Exporter:ExportLootHistoryHTML()
            end
        elseif data_type == "dkp" then
            if format == "csv" then
                data = Exporter:ExportDKPLedgerCSV()
            elseif format == "html" then
                data = Exporter:ExportDKPLedgerHTML()
            end
        elseif data_type == "composition" then
            if format == "csv" then
                data = Exporter:ExportRaidCompositionCSV()
            end
        elseif data_type == "stats" then
            if format == "csv" then
                data = Exporter:ExportPlayerStatsCSV()
            end
        end
        
        if data == "" then
            print("|cffff0000Invalid format or type.|r")
            Exporter:PrintExportOptions()
            return
        end
        
        if format == "text" then
            print("|cff00ccffExport Preview (truncated):|r")
            print(string.sub(data, 1, 500))
        else
            print(string.format("|cff00ff00✓ Export generated (%d bytes)|r", string.len(data)))
            print("|cffff9900Note: Copy from /script output or use an addon manager to save|r")
            -- In a real implementation, would trigger WoW's output export dialog
            if format == "csv" or format == "html" then
                print("|cffff9900Data:|r")
                print(data)
            end
        end
    end, "Export loot/DKP data")
end

return PluribusLoot.LootExporter
