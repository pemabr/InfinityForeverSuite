-- MultiSkinOptionsEngine.lua - Display and manage multiple skin options
-- Part of InfinityHealer addon suite
-- Provides UI for browsing and switching between available skins

local MultiSkinOptionsEngine = {}
MultiSkinOptionsEngine.enabled = false
MultiSkinOptionsEngine.db = nil
MultiSkinOptionsEngine.skin_options = {}

-- Configuration
MultiSkinOptionsEngine.config = {
    enabled = true,
    show_built_in = true,
    show_custom = true,
    show_external = true,
    sort_by = "NAME",  -- NAME, CATEGORY, AUTHOR
    items_per_page = 10,
    current_page = 1,
}

function MultiSkinOptionsEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.skin_history then
        self.db.skin_history = {}
    end
    
    if not self.db.favorite_skins then
        self.db.favorite_skins = {}
    end
    
    self.enabled = true
    
    self:Log("Initialized with skin browsing system")
end

function MultiSkinOptionsEngine:GetAvailableSkins()
    local skins = {}
    
    -- Get built-in skins
    if self.config.show_built_in and InfinityHealer and InfinityHealer.SkinEngine then
        local builtIn = InfinityHealer.SkinEngine.config.builtin_skins or {}
        
        for skinName, skinData in pairs(builtIn) do
            table.insert(skins, {
                name = skinName,
                type = "BUILT_IN",
                author = "Infinity Suite",
                category = "Built-in",
            })
        end
    end
    
    -- Get custom skins
    if self.config.show_custom and InfinityHealer and InfinityHealer.SkinImportExportEngine then
        local customSkins = InfinityHealer.SkinImportExportEngine:ListCustomSkins()
        
        for _, skinInfo in ipairs(customSkins) do
            table.insert(skins, {
                name = skinInfo.name,
                type = "CUSTOM",
                author = skinInfo.author or "Unknown",
                category = "Custom",
            })
        end
    end
    
    -- Get external skins from packages
    if self.config.show_external and InfinityHealer and InfinityHealer.ExtraSkinPackagesEngine then
        local externalSkins = InfinityHealer.ExtraSkinPackagesEngine:GetAllExternalSkins()
        
        for _, entry in ipairs(externalSkins) do
            table.insert(skins, {
                name = entry.skin.name,
                type = "EXTERNAL",
                author = entry.skin.author or entry.package,
                category = entry.package,
            })
        end
    end
    
    return skins
end

function MultiSkinOptionsEngine:GetSortedSkins(skins)
    if not skins or #skins == 0 then
        return {}
    end
    
    local sorted = {}
    for _, skin in ipairs(skins) do
        table.insert(sorted, skin)
    end
    
    if self.config.sort_by == "NAME" then
        table.sort(sorted, function(a, b) return a.name < b.name end)
    elseif self.config.sort_by == "CATEGORY" then
        table.sort(sorted, function(a, b)
            if a.category ~= b.category then
                return a.category < b.category
            end
            return a.name < b.name
        end)
    elseif self.config.sort_by == "AUTHOR" then
        table.sort(sorted, function(a, b)
            if a.author ~= b.author then
                return a.author < b.author
            end
            return a.name < b.name
        end)
    end
    
    return sorted
end

function MultiSkinOptionsEngine:GetSkinsForPage(pageNumber)
    if not pageNumber or pageNumber < 1 then
        pageNumber = 1
    end
    
    local allSkins = self:GetAvailableSkins()
    local sorted = self:GetSortedSkins(allSkins)
    
    local startIdx = ((pageNumber - 1) * self.config.items_per_page) + 1
    local endIdx = math.min(pageNumber * self.config.items_per_page, #sorted)
    
    local pageSkins = {}
    for i = startIdx, endIdx do
        table.insert(pageSkins, sorted[i])
    end
    
    return {
        skins = pageSkins,
        current_page = pageNumber,
        total_pages = math.ceil(#sorted / self.config.items_per_page),
        total_skins = #sorted,
    }
end

function MultiSkinOptionsEngine:GetPageCount()
    local allSkins = self:GetAvailableSkins()
    return math.ceil(#allSkins / self.config.items_per_page)
end

function MultiSkinOptionsEngine:SelectSkin(skinName)
    if not skinName then
        return false
    end
    
    if InfinityHealer and InfinityHealer.SkinEngine then
        local success = InfinityHealer.SkinEngine:SetSkin(skinName)
        
        if success then
            self:RecordSkinHistory(skinName)
            self:Log("Skin selected: " .. skinName)
        end
        
        return success
    end
    
    return false
end

function MultiSkinOptionsEngine:AddFavoriteSkin(skinName)
    if not skinName then
        return false
    end
    
    if not self.db.favorite_skins then
        self.db.favorite_skins = {}
    end
    
    self.db.favorite_skins[skinName] = true
    self:Log("Skin added to favorites: " .. skinName)
    return true
end

function MultiSkinOptionsEngine:RemoveFavoriteSkin(skinName)
    if not skinName or not self.db.favorite_skins then
        return false
    end
    
    self.db.favorite_skins[skinName] = nil
    self:Log("Skin removed from favorites: " .. skinName)
    return true
end

function MultiSkinOptionsEngine:IsFavoriteSkin(skinName)
    if not skinName or not self.db.favorite_skins then
        return false
    end
    
    return self.db.favorite_skins[skinName] == true
end

function MultiSkinOptionsEngine:GetFavoriteSkins()
    local favorites = {}
    
    if not self.db.favorite_skins then
        return favorites
    end
    
    local allSkins = self:GetAvailableSkins()
    
    for _, skin in ipairs(allSkins) do
        if self:IsFavoriteSkin(skin.name) then
            table.insert(favorites, skin)
        end
    end
    
    return self:GetSortedSkins(favorites)
end

function MultiSkinOptionsEngine:RecordSkinHistory(skinName)
    if not skinName then
        return false
    end
    
    if not self.db.skin_history then
        self.db.skin_history = {}
    end
    
    table.insert(self.db.skin_history, {
        name = skinName,
        time = GetTime(),
    })
    
    -- Keep only last 50 entries
    if #self.db.skin_history > 50 then
        table.remove(self.db.skin_history, 1)
    end
    
    return true
end

function MultiSkinOptionsEngine:GetSkinHistory()
    if not self.db.skin_history then
        return {}
    end
    
    local history = {}
    
    for i = #self.db.skin_history, math.max(1, #self.db.skin_history - 9), -1 do
        table.insert(history, self.db.skin_history[i])
    end
    
    return history
end

function MultiSkinOptionsEngine:SetSortBy(sortType)
    if sortType == "NAME" or sortType == "CATEGORY" or sortType == "AUTHOR" then
        self.config.sort_by = sortType
        self.config.current_page = 1  -- Reset to first page
        self:Log("Sort order: " .. sortType)
        return true
    end
    return false
end

function MultiSkinOptionsEngine:SetItemsPerPage(count)
    if count and count > 0 and count <= 50 then
        self.config.items_per_page = count
        self.config.current_page = 1  -- Reset to first page
        self:Log("Items per page: " .. count)
        return true
    end
    return false
end

function MultiSkinOptionsEngine:GetStatus()
    local allSkins = self:GetAvailableSkins()
    
    return {
        enabled = self.enabled,
        total_skins = #allSkins,
        show_built_in = self.config.show_built_in,
        show_custom = self.config.show_custom,
        show_external = self.config.show_external,
        sort_by = self.config.sort_by,
        items_per_page = self.config.items_per_page,
    }
end

function MultiSkinOptionsEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[MultiSkinOptionsEngine] " .. message)
    else
        print("[MultiSkinOptionsEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_SKINSELECTOR1 = "/skinselector"
    SlashCmdList["SKINSELECTOR"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "browse" then
            local page = tonumber(args) or 1
            local result = MultiSkinOptionsEngine:GetSkinsForPage(page)
            print("Skins (Page " .. result.current_page .. "/" .. result.total_pages .. "):")
            for i, skin in ipairs(result.skins) do
                local fav = MultiSkinOptionsEngine:IsFavoriteSkin(skin.name) and "★" or " "
                print("  [" .. fav .. "] " .. skin.name .. " (" .. skin.type .. ") - " .. skin.author)
            end
        elseif cmd == "select" then
            if args and args ~= "" then
                if MultiSkinOptionsEngine:SelectSkin(args) then
                    print("Skin applied: " .. args)
                else
                    print("Skin not found or error: " .. args)
                end
            else
                print("Usage: /skinselector select <skinname>")
            end
        elseif cmd == "favorite" then
            if args and args ~= "" then
                if MultiSkinOptionsEngine:IsFavoriteSkin(args) then
                    MultiSkinOptionsEngine:RemoveFavoriteSkin(args)
                    print("Removed from favorites: " .. args)
                else
                    MultiSkinOptionsEngine:AddFavoriteSkin(args)
                    print("Added to favorites: " .. args)
                end
            else
                print("Usage: /skinselector favorite <skinname>")
            end
        elseif cmd == "favorites" then
            local favorites = MultiSkinOptionsEngine:GetFavoriteSkins()
            print("Favorite Skins (" .. #favorites .. "):")
            for _, skin in ipairs(favorites) do
                print("  ★ " .. skin.name .. " - " .. skin.author)
            end
        elseif cmd == "history" then
            local history = MultiSkinOptionsEngine:GetSkinHistory()
            print("Skin History (" .. #history .. " recent):")
            for _, entry in ipairs(history) do
                print("  " .. entry.name)
            end
        elseif cmd == "sort" then
            if args and (args == "NAME" or args == "CATEGORY" or args == "AUTHOR") then
                MultiSkinOptionsEngine:SetSortBy(args)
                print("Sort: " .. args)
            else
                print("Usage: /skinselector sort <NAME|CATEGORY|AUTHOR>")
            end
        elseif cmd == "status" then
            local status = MultiSkinOptionsEngine:GetStatus()
            print("Multi-Skin Options Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Skin Selector Commands:")
            print("  /skinselector browse [page] - Browse skins by page")
            print("  /skinselector select <name> - Apply skin")
            print("  /skinselector favorite <name> - Toggle favorite")
            print("  /skinselector favorites - Show favorites")
            print("  /skinselector history - Show recent skins")
            print("  /skinselector sort <NAME|CATEGORY|AUTHOR> - Change sort")
            print("  /skinselector status - Show system status")
        end
    end
end

return MultiSkinOptionsEngine
