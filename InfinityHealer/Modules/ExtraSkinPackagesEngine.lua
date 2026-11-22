-- ExtraSkinPackagesEngine.lua - Load and manage extra skin packages
-- Part of InfinityHealer addon suite
-- Supports loading HealBot_ExtraSkins and other external skin packages

local ExtraSkinPackagesEngine = {}
ExtraSkinPackagesEngine.enabled = false
ExtraSkinPackagesEngine.db = nil
ExtraSkinPackagesEngine.external_packages = {}

-- Configuration
ExtraSkinPackagesEngine.config = {
    enabled = true,
    auto_discover = true,
    lazy_load = true,
    allow_third_party = true,
    max_packages = 10,
}

-- Known external package names and paths
ExtraSkinPackagesEngine.known_packages = {
    HealBot_ExtraSkins = {
        name = "HealBot Extra Skins",
        addon_name = "HealBot_ExtraSkins",
        load_function = "HealBot_ExtraSkins_LoadPackage",
    },
    TukuiSkins = {
        name = "Tukui Skins",
        addon_name = "Tukui",
        load_function = "Tukui_GetSkinData",
    },
    ElvUISkins = {
        name = "ElvUI Skins",
        addon_name = "ElvUI",
        load_function = "ElvUI_GetSkinData",
    },
}

function ExtraSkinPackagesEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.external_packages then
        self.db.external_packages = {}
    end
    
    if not self.db.package_skins then
        self.db.package_skins = {}
    end
    
    self.external_packages = self.db.external_packages
    self.enabled = true
    
    if self.config.auto_discover then
        self:AutoDiscoverPackages()
    end
    
    self:Log("Initialized with " .. self:CountLoadedPackages() .. " packages")
end

function ExtraSkinPackagesEngine:AutoDiscoverPackages()
    local discovered = 0
    
    for packageID, packageInfo in pairs(self.known_packages) do
        if self:IsPackageAvailable(packageInfo.addon_name) then
            if self:RegisterPackage(packageID, packageInfo) then
                discovered = discovered + 1
            end
        end
    end
    
    self:Log("Auto-discovered " .. discovered .. " external packages")
    return discovered
end

function ExtraSkinPackagesEngine:IsPackageAvailable(addonName)
    -- Check if addon is loaded
    local name, title, notes, enabled, loadable, reason, security = C_AddOns.GetAddOnInfo(addonName)
    
    if not name then
        return false
    end
    
    -- Check if addon is enabled
    return C_AddOns.IsAddOnLoaded(addonName)
end

function ExtraSkinPackagesEngine:RegisterPackage(packageID, packageInfo)
    if not packageID or not packageInfo then
        return false
    end
    
    if self:CountLoadedPackages() >= self.config.max_packages then
        self:Log("Warning: Max packages reached (" .. self.config.max_packages .. ")")
        return false
    end
    
    if not self.external_packages[packageID] then
        self.external_packages[packageID] = {
            id = packageID,
            name = packageInfo.name,
            addon_name = packageInfo.addon_name,
            load_function = packageInfo.load_function,
            loaded = false,
            skins = {},
            registered_at = GetTime(),
        }
        
        self:Log("Package registered: " .. packageInfo.name)
        return true
    end
    
    return false
end

function ExtraSkinPackagesEngine:LoadPackage(packageID)
    if not packageID or not self.external_packages[packageID] then
        return false
    end
    
    local package = self.external_packages[packageID]
    
    if package.loaded then
        return true  -- Already loaded
    end
    
    -- Verify package addon is still available
    if not self:IsPackageAvailable(package.addon_name) then
        self:Log("Warning: Package addon not loaded: " .. package.addon_name)
        return false
    end
    
    -- Try to load skins from package
    local skins = self:FetchSkinsFromPackage(package)
    
    if skins and #skins > 0 then
        package.skins = skins
        package.loaded = true
        package.loaded_at = GetTime()
        
        self:Log("Package loaded: " .. package.name .. " (" .. #skins .. " skins)")
        return true
    end
    
    self:Log("Warning: No skins found in package: " .. packageID)
    return false
end

function ExtraSkinPackagesEngine:FetchSkinsFromPackage(package)
    if not package.load_function then
        return {}
    end
    
    local skins = {}
    
    -- Try to call the package's export function
    local exportFunc = _G[package.load_function]
    
    if type(exportFunc) == "function" then
        local result = exportFunc()
        
        if type(result) == "table" then
            -- Result should be an array of skin tables
            for _, skinData in ipairs(result) do
                if self:ValidateExternalSkin(skinData) then
                    table.insert(skins, skinData)
                end
            end
        end
    end
    
    return skins
end

function ExtraSkinPackagesEngine:ValidateExternalSkin(skinData)
    if not skinData or type(skinData) ~= "table" then
        return false
    end
    
    -- Check required fields
    if not skinData.name or not skinData.colors then
        return false
    end
    
    -- Check colors structure
    if not skinData.colors.frame_bg or not skinData.colors.low_health then
        return false
    end
    
    return true
end

function ExtraSkinPackagesEngine:GetPackageSkins(packageID)
    if not packageID or not self.external_packages[packageID] then
        return {}
    end
    
    local package = self.external_packages[packageID]
    
    if not package.loaded then
        self:LoadPackage(packageID)
    end
    
    return package.skins or {}
end

function ExtraSkinPackagesEngine:GetAllExternalSkins()
    local allSkins = {}
    
    for packageID, package in pairs(self.external_packages) do
        if package.loaded or self:LoadPackage(packageID) then
            for _, skin in ipairs(package.skins) do
                table.insert(allSkins, {
                    skin = skin,
                    package = package.name,
                    package_id = packageID,
                })
            end
        end
    end
    
    return allSkins
end

function ExtraSkinPackagesEngine:UnloadPackage(packageID)
    if not packageID or not self.external_packages[packageID] then
        return false
    end
    
    local package = self.external_packages[packageID]
    
    package.loaded = false
    package.skins = {}
    package.loaded_at = nil
    
    self:Log("Package unloaded: " .. package.name)
    return true
end

function ExtraSkinPackagesEngine:CountLoadedPackages()
    local count = 0
    
    for _, package in pairs(self.external_packages) do
        if package.loaded then
            count = count + 1
        end
    end
    
    return count
end

function ExtraSkinPackagesEngine:ListPackages()
    local packages = {}
    
    for packageID, package in pairs(self.external_packages) do
        table.insert(packages, {
            id = packageID,
            name = package.name,
            loaded = package.loaded,
            skin_count = package.loaded and #package.skins or 0,
        })
    end
    
    table.sort(packages, function(a, b) return a.name < b.name end)
    return packages
end

function ExtraSkinPackagesEngine:GetStatus()
    local loadedCount = 0
    local totalSkins = 0
    
    for _, package in pairs(self.external_packages) do
        if package.loaded then
            loadedCount = loadedCount + 1
            totalSkins = totalSkins + #package.skins
        end
    end
    
    return {
        enabled = self.enabled,
        total_packages = #self:ListPackages(),
        loaded_packages = loadedCount,
        total_external_skins = totalSkins,
        auto_discover = self.config.auto_discover,
        lazy_load = self.config.lazy_load,
    }
end

function ExtraSkinPackagesEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[ExtraSkinPackagesEngine] " .. message)
    else
        print("[ExtraSkinPackagesEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_SKINPACKAGE1 = "/skinpackage"
    SlashCmdList["SKINPACKAGE"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "list" then
            local packages = ExtraSkinPackagesEngine:ListPackages()
            print("External Skin Packages (" .. #packages .. "):")
            for _, pkg in ipairs(packages) do
                local status = pkg.loaded and "✓" or "○"
                print("  [" .. status .. "] " .. pkg.name .. " (" .. pkg.skin_count .. " skins)")
            end
        elseif cmd == "load" then
            if args and args ~= "" then
                if ExtraSkinPackagesEngine:LoadPackage(args) then
                    print("Package loaded: " .. args)
                else
                    print("Failed to load package: " .. args)
                end
            else
                print("Usage: /skinpackage load <package>")
            end
        elseif cmd == "unload" then
            if args and args ~= "" then
                if ExtraSkinPackagesEngine:UnloadPackage(args) then
                    print("Package unloaded: " .. args)
                else
                    print("Package not found: " .. args)
                end
            else
                print("Usage: /skinpackage unload <package>")
            end
        elseif cmd == "discover" then
            local count = ExtraSkinPackagesEngine:AutoDiscoverPackages()
            print("Discovered " .. count .. " packages")
        elseif cmd == "skins" then
            local skins = ExtraSkinPackagesEngine:GetAllExternalSkins()
            print("External Skins (" .. #skins .. "):")
            for i, entry in ipairs(skins) do
                if i <= 20 then
                    print("  " .. entry.skin.name .. " (" .. entry.package .. ")")
                end
            end
            if #skins > 20 then
                print("  ... and " .. (#skins - 20) .. " more")
            end
        elseif cmd == "status" then
            local status = ExtraSkinPackagesEngine:GetStatus()
            print("External Skin Packages Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("External Skin Package Commands:")
            print("  /skinpackage list - Show all packages")
            print("  /skinpackage load <package> - Load package")
            print("  /skinpackage unload <package> - Unload package")
            print("  /skinpackage discover - Auto-discover packages")
            print("  /skinpackage skins - List all external skins")
            print("  /skinpackage status - Show system status")
        end
    end
end

return ExtraSkinPackagesEngine
