-- SkinImportExportEngine.lua - Import and export custom skins
-- Part of PluribusHealer addon suite
-- Handles skin creation, modification, sharing via import/export

local SkinImportExportEngine = {}
SkinImportExportEngine.enabled = false
SkinImportExportEngine.db = nil
SkinImportExportEngine.skins = {}

-- Configuration
SkinImportExportEngine.config = {
    enabled = true,
    max_custom_skins = 20,
    allow_sharing = true,
    version_check = true,
}

-- Skin template structure
SkinImportExportEngine.skin_template = {
    name = "",
    version = "1.0",
    author = "",
    description = "",
    created_at = 0,
    updated_at = 0,
    colors = {
        -- Frame colors
        frame_bg = {0.1, 0.1, 0.1},
        frame_border = {0.5, 0.5, 0.5},
        -- Text colors
        health_text = {1.0, 1.0, 1.0},
        mana_text = {0.0, 1.0, 1.0},
        -- Status colors
        low_health = {1.0, 0.0, 0.0},
        half_health = {1.0, 1.0, 0.0},
        high_health = {0.0, 1.0, 0.0},
    },
    fonts = {
        health = "GameFontNormal",
        status = "GameFontSmall",
    },
    sizes = {
        frame_width = 100,
        frame_height = 50,
        health_bar_height = 20,
    },
}

function SkinImportExportEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.custom_skins then
        self.db.custom_skins = {}
    end
    
    if not self.db.skin_imports then
        self.db.skin_imports = {}
    end
    
    self.skins = self.db.custom_skins
    self.enabled = true
    
    self:Log("Initialized with " .. self:CountCustomSkins() .. " custom skins")
end

function SkinImportExportEngine:CountCustomSkins()
    local count = 0
    
    for _ in pairs(self.skins) do
        count = count + 1
    end
    
    return count
end

function SkinImportExportEngine:CreateCustomSkin(skinName, baseColors, baseFonts, baseSizes)
    if not skinName or skinName == "" then
        return false
    end
    
    if self:CountCustomSkins() >= self.config.max_custom_skins then
        self:Log("Warning: Max custom skins reached (" .. self.config.max_custom_skins .. ")")
        return false
    end
    
    local newSkin = {
        name = skinName,
        version = "1.0",
        author = GetPlayerName and GetPlayerName() or "Unknown",
        description = "Custom skin",
        created_at = GetTime(),
        updated_at = GetTime(),
        colors = baseColors or self:CopyTable(self.skin_template.colors),
        fonts = baseFonts or self:CopyTable(self.skin_template.fonts),
        sizes = baseSizes or self:CopyTable(self.skin_template.sizes),
    }
    
    self.skins[skinName] = newSkin
    
    self:Log("Custom skin created: " .. skinName)
    return true
end

function SkinImportExportEngine:UpdateCustomSkin(skinName, updates)
    if not skinName or not self.skins[skinName] then
        return false
    end
    
    if updates.colors then
        self.skins[skinName].colors = self:MergeTable(self.skins[skinName].colors, updates.colors)
    end
    
    if updates.fonts then
        self.skins[skinName].fonts = self:MergeTable(self.skins[skinName].fonts, updates.fonts)
    end
    
    if updates.sizes then
        self.skins[skinName].sizes = self:MergeTable(self.skins[skinName].sizes, updates.sizes)
    end
    
    if updates.description then
        self.skins[skinName].description = updates.description
    end
    
    self.skins[skinName].updated_at = GetTime()
    
    self:Log("Custom skin updated: " .. skinName)
    return true
end

function SkinImportExportEngine:DeleteCustomSkin(skinName)
    if not skinName or not self.skins[skinName] then
        return false
    end
    
    self.skins[skinName] = nil
    
    self:Log("Custom skin deleted: " .. skinName)
    return true
end

function SkinImportExportEngine:GetCustomSkin(skinName)
    if not skinName or not self.skins[skinName] then
        return nil
    end
    
    return self.skins[skinName]
end

function SkinImportExportEngine:ListCustomSkins()
    local list = {}
    
    for skinName, skinData in pairs(self.skins) do
        table.insert(list, {
            name = skinName,
            author = skinData.author,
            version = skinData.version,
            created = skinData.created_at,
            updated = skinData.updated_at,
        })
    end
    
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function SkinImportExportEngine:ExportSkin(skinName)
    if not skinName or not self.skins[skinName] then
        return nil
    end
    
    local skinData = self.skins[skinName]
    
    -- Create export package
    local export = {
        skin_data = skinData,
        export_time = GetTime(),
        exporter_version = "1.0",
    }
    
    return export
end

function SkinImportExportEngine:ImportSkin(importData)
    if not importData or not importData.skin_data then
        return false
    end
    
    local skinData = importData.skin_data
    
    -- Validation
    if not skinData.name or skinData.name == "" then
        return false
    end
    
    -- Check if already exists
    if self.skins[skinData.name] then
        self:Log("Warning: Skin already exists - will overwrite: " .. skinData.name)
    end
    
    -- Version compatibility check
    if self.config.version_check then
        if not skinData.version or skinData.version ~= "1.0" then
            self:Log("Warning: Skin version mismatch - compatibility not guaranteed")
        end
    end
    
    -- Validate structure
    if not self:ValidateSkinStructure(skinData) then
        return false
    end
    
    -- Import
    self.skins[skinData.name] = skinData
    self.skins[skinData.name].updated_at = GetTime()
    
    self:Log("Skin imported: " .. skinData.name .. " by " .. (skinData.author or "Unknown"))
    return true
end

function SkinImportExportEngine:ValidateSkinStructure(skinData)
    if not skinData.name or not skinData.colors or not skinData.fonts or not skinData.sizes then
        return false
    end
    
    -- Check required color fields
    local requiredColors = {"frame_bg", "frame_border", "health_text", "low_health", "high_health"}
    
    for _, colorField in ipairs(requiredColors) do
        if not skinData.colors[colorField] then
            return false
        end
    end
    
    -- Check color format (RGB table)
    for _, color in pairs(skinData.colors) do
        if type(color) ~= "table" or #color ~= 3 then
            return false
        end
    end
    
    return true
end

function SkinImportExportEngine:DuplicateSkin(sourceSkinName, newSkinName)
    if not sourceSkinName or not newSkinName then
        return false
    end
    
    if not self.skins[sourceSkinName] then
        return false
    end
    
    if self.skins[newSkinName] then
        self:Log("Warning: Destination skin already exists")
        return false
    end
    
    -- Deep copy
    local sourceData = self.skins[sourceSkinName]
    
    self.skins[newSkinName] = {
        name = newSkinName,
        version = sourceData.version,
        author = sourceData.author .. " (copied)",
        description = sourceData.description .. " (copy)",
        created_at = GetTime(),
        updated_at = GetTime(),
        colors = self:CopyTable(sourceData.colors),
        fonts = self:CopyTable(sourceData.fonts),
        sizes = self:CopyTable(sourceData.sizes),
    }
    
    self:Log("Skin duplicated: " .. sourceSkinName .. " -> " .. newSkinName)
    return true
end

function SkinImportExportEngine:CopyTable(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end
    
    local copy = {}
    
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            copy[k] = self:CopyTable(v)
        else
            copy[k] = v
        end
    end
    
    return copy
end

function SkinImportExportEngine:MergeTable(base, updates)
    if type(updates) ~= "table" then
        return base
    end
    
    local result = self:CopyTable(base)
    
    for k, v in pairs(updates) do
        if type(v) == "table" and type(result[k]) == "table" then
            result[k] = self:MergeTable(result[k], v)
        else
            result[k] = v
        end
    end
    
    return result
end

function SkinImportExportEngine:GetStatus()
    local customSkinCount = self:CountCustomSkins()
    
    return {
        enabled = self.enabled,
        custom_skins = customSkinCount,
        max_custom_skins = self.config.max_custom_skins,
        allow_sharing = self.config.allow_sharing,
        version_check = self.config.version_check,
    }
end

function SkinImportExportEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[SkinImportExportEngine] " .. message)
    else
        print("[SkinImportExportEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_SKINEXPORT1 = "/skinexport"
    SlashCmdList["SKINEXPORT"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "create" then
            if args and args ~= "" then
                SkinImportExportEngine:CreateCustomSkin(args)
                print("Skin created: " .. args)
            else
                print("Usage: /skinexport create <name>")
            end
        elseif cmd == "delete" then
            if args and args ~= "" then
                if SkinImportExportEngine:DeleteCustomSkin(args) then
                    print("Skin deleted: " .. args)
                else
                    print("Skin not found: " .. args)
                end
            else
                print("Usage: /skinexport delete <name>")
            end
        elseif cmd == "list" then
            local skins = SkinImportExportEngine:ListCustomSkins()
            print("Custom Skins (" .. #skins .. "):")
            for _, skin in ipairs(skins) do
                print("  " .. skin.name .. " by " .. skin.author)
            end
        elseif cmd == "duplicate" then
            local source, dest = args:match("^(%S+)%s+(%S+)$")
            if source and dest then
                if SkinImportExportEngine:DuplicateSkin(source, dest) then
                    print("Skin duplicated: " .. source .. " -> " .. dest)
                else
                    print("Duplication failed")
                end
            else
                print("Usage: /skinexport duplicate <source> <dest>")
            end
        elseif cmd == "export" then
            if args and args ~= "" then
                local export = SkinImportExportEngine:ExportSkin(args)
                if export then
                    print("Skin exported: " .. args .. " (copy the string to file)")
                else
                    print("Skin not found: " .. args)
                end
            else
                print("Usage: /skinexport export <name>")
            end
        elseif cmd == "status" then
            local status = SkinImportExportEngine:GetStatus()
            print("Skin Import/Export Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Skin Import/Export Commands:")
            print("  /skinexport create <name> - Create custom skin")
            print("  /skinexport delete <name> - Delete custom skin")
            print("  /skinexport list - List all custom skins")
            print("  /skinexport duplicate <source> <dest> - Duplicate skin")
            print("  /skinexport export <name> - Export skin to string")
            print("  /skinexport status - Show system status")
        end
    end
end

return SkinImportExportEngine
