-- ClickCastBindingConfigEngine.lua - Configure click-cast spell bindings
-- Part of PluribusHealer addon suite
-- Manages and stores spell bindings for frame clicks and modifiers

local ClickCastBindingConfigEngine = {}
ClickCastBindingConfigEngine.enabled = false
ClickCastBindingConfigEngine.db = nil
ClickCastBindingConfigEngine.bindings = {}

-- Configuration
ClickCastBindingConfigEngine.config = {
    enabled = true,
    max_bindings_per_button = 5,
    allow_modifiers = true,
    modifier_keys = {"ALT", "CTRL", "SHIFT"},
    button_bindings = {},  -- Button -> Modifier -> Spell mapping
}

-- Default spell bindings
ClickCastBindingConfigEngine.default_bindings = {
    LEFT_CLICK = {
        [0] = "Holy Light",  -- No modifier
        ["CTRL"] = "Flash Heal",
        ["SHIFT"] = "Renew",
    },
    RIGHT_CLICK = {
        [0] = "Dispel Magic",
    },
    MIDDLE_CLICK = {
        [0] = "Heal",
    },
}

function ClickCastBindingConfigEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.click_bindings then
        self.db.click_bindings = {}
        
        -- Initialize with defaults
        for button, modifierBindings in pairs(self.default_bindings) do
            self.db.click_bindings[button] = modifierBindings
        end
    end
    
    self.bindings = self.db.click_bindings
    self.config.button_bindings = self.bindings
    self.enabled = true
    
    self:Log("Initialized with " .. self:CountBindings() .. " default bindings")
end

function ClickCastBindingConfigEngine:CountBindings()
    local count = 0
    
    for _, modifierBindings in pairs(self.bindings) do
        for _ in pairs(modifierBindings) do
            count = count + 1
        end
    end
    
    return count
end

function ClickCastBindingConfigEngine:SetBinding(button, spellName, modifier)
    if not button or not spellName then
        return false
    end
    
    if not self.bindings[button] then
        self.bindings[button] = {}
    end
    
    -- Use 0 for no modifier, or the modifier key name
    local modifierKey = modifier or 0
    
    if modifier and not self:IsValidModifier(modifier) then
        return false
    end
    
    -- Check if spell exists (via spell lookup)
    if not self:ValidateSpellName(spellName) then
        self:Log("Warning: Spell '" .. spellName .. "' not validated")
    end
    
    self.bindings[button][modifierKey] = spellName
    
    self:Log("Binding set: " .. button .. " +" .. tostring(modifierKey) .. " -> " .. spellName)
    return true
end

function ClickCastBindingConfigEngine:RemoveBinding(button, modifier)
    if not button or not self.bindings[button] then
        return false
    end
    
    local modifierKey = modifier or 0
    
    if self.bindings[button][modifierKey] then
        self.bindings[button][modifierKey] = nil
        self:Log("Binding removed: " .. button .. " +" .. tostring(modifierKey))
        return true
    end
    
    return false
end

function ClickCastBindingConfigEngine:GetBinding(button, modifier)
    if not button or not self.bindings[button] then
        return nil
    end
    
    local modifierKey = modifier or 0
    return self.bindings[button][modifierKey]
end

function ClickCastBindingConfigEngine:GetAllBindingsForButton(button)
    if not button or not self.bindings[button] then
        return {}
    end
    
    local result = {}
    
    for modifierKey, spellName in pairs(self.bindings[button]) do
        table.insert(result, {
            button = button,
            modifier = modifierKey == 0 and "NONE" or modifierKey,
            spell = spellName,
        })
    end
    
    return result
end

function ClickCastBindingConfigEngine:IsValidModifier(modifier)
    for _, key in ipairs(self.config.modifier_keys) do
        if key == modifier then
            return true
        end
    end
    return false
end

function ClickCastBindingConfigEngine:ValidateSpellName(spellName)
    -- Basic validation - in a real implementation, would check against spell database
    if not spellName or spellName == "" then
        return false
    end
    
    if string.len(spellName) > 50 then
        return false
    end
    
    return true
end

function ClickCastBindingConfigEngine:ResetBindings()
    self.bindings = {}
    
    for button, modifierBindings in pairs(self.default_bindings) do
        self.bindings[button] = {}
        for modifier, spell in pairs(modifierBindings) do
            self.bindings[button][modifier] = spell
        end
    end
    
    self:Log("Bindings reset to defaults")
    return true
end

function ClickCastBindingConfigEngine:ExportBindings()
    local export = {}
    
    for button, modifierBindings in pairs(self.bindings) do
        export[button] = {}
        for modifier, spell in pairs(modifierBindings) do
            export[button][modifier] = spell
        end
    end
    
    return export
end

function ClickCastBindingConfigEngine:ImportBindings(importData)
    if not importData or type(importData) ~= "table" then
        return false
    end
    
    self.bindings = {}
    
    for button, modifierBindings in pairs(importData) do
        self.bindings[button] = {}
        for modifier, spell in pairs(modifierBindings) do
            if self:ValidateSpellName(spell) then
                self.bindings[button][modifier] = spell
            end
        end
    end
    
    self:Log("Bindings imported successfully")
    return true
end

function ClickCastBindingConfigEngine:GetStatus()
    local buttonCount = 0
    
    for _ in pairs(self.bindings) do
        buttonCount = buttonCount + 1
    end
    
    return {
        enabled = self.enabled,
        total_bindings = self:CountBindings(),
        button_count = buttonCount,
        allow_modifiers = self.config.allow_modifiers,
        max_bindings_per_button = self.config.max_bindings_per_button,
    }
end

function ClickCastBindingConfigEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[ClickCastBindingConfigEngine] " .. message)
    else
        print("[ClickCastBindingConfigEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_CLICKCAST1 = "/clickcast"
    SlashCmdList["CLICKCAST"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "set" then
            local button, rest = args:match("^(%S+)%s+(.*)$")
            if button and rest then
                local spell, modifier = rest:match("^(.+)%s+(%S+)$")
                if not modifier then
                    spell = rest
                end
                
                if ClickCastBindingConfigEngine:SetBinding(button, spell, modifier) then
                    print("Binding set: " .. button .. " +" .. (modifier or "NONE") .. " -> " .. spell)
                else
                    print("Failed to set binding")
                end
            else
                print("Usage: /clickcast set <button> <spell> [modifier]")
            end
        elseif cmd == "remove" then
            local button, modifier = args:match("^(%S+)%s*(%S*)$")
            if button then
                if ClickCastBindingConfigEngine:RemoveBinding(button, modifier or nil) then
                    print("Binding removed: " .. button)
                else
                    print("Binding not found")
                end
            else
                print("Usage: /clickcast remove <button> [modifier]")
            end
        elseif cmd == "list" then
            local button = args
            if button and button ~= "" then
                local bindings = ClickCastBindingConfigEngine:GetAllBindingsForButton(button)
                if #bindings > 0 then
                    print("Bindings for " .. button .. ":")
                    for _, binding in ipairs(bindings) do
                        print("  +" .. binding.modifier .. " -> " .. binding.spell)
                    end
                else
                    print("No bindings for " .. button)
                end
            else
                print("Usage: /clickcast list <button>")
            end
        elseif cmd == "reset" then
            if args == "confirm" then
                ClickCastBindingConfigEngine:ResetBindings()
                print("Bindings reset to defaults")
            else
                print("Usage: /clickcast reset confirm")
            end
        elseif cmd == "export" then
            local export = ClickCastBindingConfigEngine:ExportBindings()
            local serialized = tostring(export)
            print("Exported bindings (copy to file): " .. serialized:sub(1, 100) .. "...")
        elseif cmd == "status" then
            local status = ClickCastBindingConfigEngine:GetStatus()
            print("Click-Cast Binding Configuration:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Click-Cast Binding Commands:")
            print("  /clickcast set <button> <spell> [modifier] - Set binding")
            print("  /clickcast remove <button> [modifier] - Remove binding")
            print("  /clickcast list <button> - List bindings for button")
            print("  /clickcast reset confirm - Reset to defaults")
            print("  /clickcast export - Export bindings")
            print("  /clickcast status - Show system status")
        end
    end
end

return ClickCastBindingConfigEngine
