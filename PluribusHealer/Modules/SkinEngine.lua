-- SkinEngine.lua - Switch between visual themes for raid frames
-- Part of PluribusHealer addon suite
-- Manages frame skins, colors, borders, and textures

local SkinEngine = {}
SkinEngine.enabled = false
SkinEngine.db = nil
SkinEngine.current_skin = "default"
SkinEngine.skins = {}

-- Define built-in skins
SkinEngine.skin_definitions = {
    default = {
        name = "Default",
        description = "Classic WoW UI style",
        frame_bg = "Interface/Tooltips/UI-Tooltip-Background",
        frame_border = "Interface/Tooltips/UI-Tooltip-Border",
        health_bar_texture = "Interface/TargetingFrame/UI-StatusBar",
        health_bar_color = { 0, 0.8, 0 },
        mana_bar_color = { 0, 0, 1 },
        bg_color = { 0.1, 0.1, 0.1, 0.8 },
        border_color = { 0.5, 0.5, 0.5, 1 },
        text_color = { 1, 1, 1, 1 },
        border_size = 8,
        edge_size = 1,
    },
    dark = {
        name = "Dark",
        description = "Dark theme with minimal contrast",
        frame_bg = "Interface/Tooltips/UI-Tooltip-Background",
        frame_border = "Interface/Tooltips/UI-Tooltip-Border",
        health_bar_texture = "Interface/TargetingFrame/UI-StatusBar",
        health_bar_color = { 0, 0.6, 0 },
        mana_bar_color = { 0, 0, 0.8 },
        bg_color = { 0.05, 0.05, 0.05, 0.9 },
        border_color = { 0.3, 0.3, 0.3, 1 },
        text_color = { 0.8, 0.8, 0.8, 1 },
        border_size = 8,
        edge_size = 1,
    },
    bright = {
        name = "Bright",
        description = "Light theme with high contrast",
        frame_bg = "Interface/Tooltips/UI-Tooltip-Background",
        frame_border = "Interface/Tooltips/UI-Tooltip-Border",
        health_bar_texture = "Interface/TargetingFrame/UI-StatusBar",
        health_bar_color = { 0, 1, 0 },
        mana_bar_color = { 0, 0.5, 1 },
        bg_color = { 0.2, 0.2, 0.2, 0.7 },
        border_color = { 0.8, 0.8, 0.8, 1 },
        text_color = { 1, 1, 1, 1 },
        border_size = 8,
        edge_size = 1,
    },
    compact = {
        name = "Compact",
        description = "Minimal skin for high performance",
        frame_bg = "Interface/Tooltips/UI-Tooltip-Background",
        frame_border = "Interface/Tooltips/UI-Tooltip-Border",
        health_bar_texture = "Interface/TargetingFrame/UI-StatusBar",
        health_bar_color = { 0, 0.7, 0 },
        mana_bar_color = { 0, 0, 0.9 },
        bg_color = { 0.1, 0.1, 0.1, 0.6 },
        border_color = { 0.4, 0.4, 0.4, 0.8 },
        text_color = { 1, 1, 1, 0.9 },
        border_size = 6,
        edge_size = 1,
    },
    modern = {
        name = "Modern",
        description = "Contemporary flat design",
        frame_bg = "Interface/Tooltips/UI-Tooltip-Background",
        frame_border = "Interface/Tooltips/UI-Tooltip-Border",
        health_bar_texture = "Interface/TargetingFrame/UI-StatusBar",
        health_bar_color = { 0.2, 0.9, 0.2 },
        mana_bar_color = { 0.2, 0.6, 1 },
        bg_color = { 0.12, 0.12, 0.12, 0.85 },
        border_color = { 0.6, 0.6, 0.6, 1 },
        text_color = { 1, 1, 1, 1 },
        border_size = 4,
        edge_size = 0.5,
    },
}

function SkinEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.skins then
        self.db.skins = {}
    end
    
    if not self.db.current_skin then
        self.db.current_skin = "default"
    end
    
    self.skins = self.db.skins
    self.current_skin = self.db.current_skin or "default"
    self.enabled = true
    
    self:Log("Initialized with skin: " .. self.current_skin)
end

function SkinEngine:GetSkin(skinName)
    if not skinName then
        skinName = self.current_skin
    end
    
    -- Check custom skins first
    if self.skins[skinName] then
        return self.skins[skinName]
    end
    
    -- Fall back to built-in skins
    if self.skin_definitions[skinName] then
        return self.skin_definitions[skinName]
    end
    
    -- Default fallback
    return self.skin_definitions["default"]
end

function SkinEngine:SetSkin(skinName)
    if not skinName then
        return false
    end
    
    if not self:GetSkin(skinName) then
        self:Log("Skin not found: " .. skinName)
        return false
    end
    
    self.current_skin = skinName
    self.db.current_skin = skinName
    
    self:Log("Skin changed to: " .. skinName)
    return true
end

function SkinEngine:ApplySkinToFrame(frame, skinName)
    if not frame then
        return false
    end
    
    local skin = self:GetSkin(skinName)
    if not skin then
        return false
    end
    
    -- Apply backdrop
    frame:SetBackdrop({
        bgFile = skin.frame_bg,
        edgeFile = skin.frame_border,
        tile = false,
        tileSize = 16,
        edgeSize = skin.border_size or 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    
    -- Apply colors
    frame:SetBackdropColor(skin.bg_color[1], skin.bg_color[2], skin.bg_color[3], skin.bg_color[4])
    frame:SetBackdropBorderColor(skin.border_color[1], skin.border_color[2], skin.border_color[3], skin.border_color[4])
    
    return true
end

function SkinEngine:ApplySkinToHealthBar(statusBar, skinName)
    if not statusBar then
        return false
    end
    
    local skin = self:GetSkin(skinName)
    if not skin then
        return false
    end
    
    statusBar:SetStatusBarTexture(skin.health_bar_texture)
    statusBar:SetStatusBarColor(skin.health_bar_color[1], skin.health_bar_color[2], skin.health_bar_color[3])
    
    return true
end

function SkinEngine:ApplySkinToText(fontString, skinName)
    if not fontString then
        return false
    end
    
    local skin = self:GetSkin(skinName)
    if not skin then
        return false
    end
    
    fontString:SetTextColor(skin.text_color[1], skin.text_color[2], skin.text_color[3], skin.text_color[4])
    
    return true
end

function SkinEngine:CreateCustomSkin(skinName, definition)
    if not skinName or not definition then
        return false
    end
    
    if self.skins[skinName] then
        self:Log("Skin already exists: " .. skinName)
        return false
    end
    
    self.skins[skinName] = definition
    self:Log("Custom skin created: " .. skinName)
    return true
end

function SkinEngine:DeleteCustomSkin(skinName)
    if not skinName then
        return false
    end
    
    if self.skin_definitions[skinName] then
        self:Log("Cannot delete built-in skin: " .. skinName)
        return false
    end
    
    if self.skins[skinName] then
        self.skins[skinName] = nil
        self:Log("Custom skin deleted: " .. skinName)
        return true
    end
    
    return false
end

function SkinEngine:ListSkins()
    local skins = {}
    
    -- Add built-in skins
    for skinName, skin in pairs(self.skin_definitions) do
        table.insert(skins, {
            name = skinName,
            display = skin.name,
            type = "built-in",
            description = skin.description,
        })
    end
    
    -- Add custom skins
    for skinName, skin in pairs(self.skins) do
        table.insert(skins, {
            name = skinName,
            display = skin.name or skinName,
            type = "custom",
            description = skin.description or "Custom skin",
        })
    end
    
    return skins
end

function SkinEngine:GetSkinInfo(skinName)
    local skin = self:GetSkin(skinName)
    if not skin then
        return nil
    end
    
    return {
        name = skin.name or skinName,
        description = skin.description or "",
        bg_color = skin.bg_color,
        border_color = skin.border_color,
        text_color = skin.text_color,
        health_bar_color = skin.health_bar_color,
    }
end

function SkinEngine:GetStatus()
    local customCount = 0
    for _ in pairs(self.skins) do
        customCount = customCount + 1
    end
    
    return {
        enabled = self.enabled,
        current_skin = self.current_skin,
        built_in_skins = 5,
        custom_skins = customCount,
    }
end

function SkinEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[SkinEngine] " .. message)
    else
        print("[SkinEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_SKINENGINE1 = "/skin"
    SlashCmdList["SKINENGINE"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "set" then
            if args and args ~= "" then
                if SkinEngine:SetSkin(args) then
                    print("Skin set to: " .. args)
                else
                    print("Skin not found: " .. args)
                end
            else
                print("Usage: /skin set <skin_name>")
            end
        elseif cmd == "list" then
            local skins = SkinEngine:ListSkins()
            print("Available skins:")
            for _, skin in ipairs(skins) do
                local typeStr = skin.type == "built-in" and "[BUILTIN]" or "[CUSTOM]"
                print("  " .. skin.display .. " " .. typeStr)
                if skin.description and skin.description ~= "" then
                    print("    " .. skin.description)
                end
            end
        elseif cmd == "current" then
            print("Current skin: " .. SkinEngine.current_skin)
        elseif cmd == "info" then
            if args and args ~= "" then
                local info = SkinEngine:GetSkinInfo(args)
                if info then
                    print("Skin Info: " .. info.name)
                    print("  Description: " .. info.description)
                    print("  BG Color: " .. math.floor(info.bg_color[1]*255) .. ", " .. math.floor(info.bg_color[2]*255) .. ", " .. math.floor(info.bg_color[3]*255))
                    print("  Text Color: " .. math.floor(info.text_color[1]*255) .. ", " .. math.floor(info.text_color[2]*255) .. ", " .. math.floor(info.text_color[3]*255))
                else
                    print("Skin not found: " .. args)
                end
            else
                print("Usage: /skin info <skin_name>")
            end
        elseif cmd == "status" then
            local status = SkinEngine:GetStatus()
            print("Skin Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Skin Commands:")
            print("  /skin set <name> - Set active skin")
            print("  /skin list - List all available skins")
            print("  /skin current - Show current skin")
            print("  /skin info <name> - Show skin details")
            print("  /skin status - Show system status")
        end
    end
end

return SkinEngine
