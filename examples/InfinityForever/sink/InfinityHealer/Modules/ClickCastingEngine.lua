-- ClickCastingEngine.lua - Core click-casting spell execution system
-- Part of InfinityHealer addon suite
-- Manages spell binding, modifier key support, and spell execution

local ClickCastingEngine = {}
ClickCastingEngine.enabled = false
ClickCastingEngine.db = nil
ClickCastingEngine.bindings = {}  -- spell -> { button: LEFT/RIGHT/MIDDLE, modifiers: {shift, ctrl, alt} }
ClickCastingEngine.current_target = nil
ClickCastingEngine.cast_queue = {}

-- Configuration
ClickCastingEngine.config = {
    enabled = true,
    allow_healing_in_combat = true,
    queue_spells = true,
    max_queue_size = 10,
    cast_delay = 0.1,  -- Minimum delay between casts
    notify_on_cast = true,
    block_hostile_casts = true,
    gcd_throttle = true,
    allow_self_cast = true,
}

function ClickCastingEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    -- Initialize binding storage
    if not self.db.click_bindings then
        self.db.click_bindings = {}
    end
    
    self.bindings = self.db.click_bindings
    self.enabled = true
    
    -- Register for events
    InfinityCore.Events:RegisterListener("frame_clicked", function(data)
        self:OnFrameClicked(data)
    end)
    
    self:Log("Initialized with " .. self:CountBindings() .. " spell bindings")
end

function ClickCastingEngine:BindSpell(spellName, button, modifiers)
    -- button: LEFT, RIGHT, MIDDLE
    -- modifiers: { shift = true, ctrl = true, alt = true }
    
    if not spellName or not button then
        self:Log("Invalid bind parameters")
        return false
    end
    
    -- Validate spell exists
    if not self:ValidateSpell(spellName) then
        self:Log("Spell not found: " .. spellName)
        return false
    end
    
    -- Create binding
    self.bindings[spellName] = {
        spell = spellName,
        button = button,
        modifiers = modifiers or {},
    }
    
    self:Log("Spell bound: " .. spellName .. " to " .. button .. " button")
    
    return true
end

function ClickCastingEngine:UnbindSpell(spellName)
    if not self.bindings[spellName] then
        self:Log("No binding found for: " .. spellName)
        return false
    end
    
    self.bindings[spellName] = nil
    self:Log("Spell unbound: " .. spellName)
    
    return true
end

function ClickCastingEngine:OnFrameClicked(data)
    if not self.enabled or not data.player then
        return
    end
    
    -- Get the spell binding for this click
    local button = data.button or "LeftButton"
    local modifiers = self:GetCurrentModifiers()
    
    -- Find matching spell
    local spell = self:FindSpellForClick(button, modifiers)
    
    if not spell then
        self:Log("No spell bound for click: " .. button)
        return
    end
    
    -- Cast spell on target
    self:CastSpell(spell, data.player)
end

function ClickCastingEngine:FindSpellForClick(button, modifiers)
    for spellName, binding in pairs(self.bindings) do
        if binding.button == button then
            -- Check if modifiers match
            if self:ModifiersMatch(binding.modifiers, modifiers) then
                return spellName
            end
        end
    end
    
    return nil
end

function ClickCastingEngine:ModifiersMatch(bindingMods, currentMods)
    -- Check if current modifiers match binding requirements
    local shiftMatch = (not bindingMods.shift) or currentMods.shift
    local ctrlMatch = (not bindingMods.ctrl) or currentMods.ctrl
    local altMatch = (not bindingMods.alt) or currentMods.alt
    
    return shiftMatch and ctrlMatch and altMatch
end

function ClickCastingEngine:GetCurrentModifiers()
    return {
        shift = IsShiftKeyDown(),
        ctrl = IsControlKeyDown(),
        alt = IsAltKeyDown(),
    }
end

function ClickCastingEngine:CastSpell(spellName, targetName)
    if not self.enabled then
        return false
    end
    
    -- Check if spell is known
    if not self:ValidateSpell(spellName) then
        self:Log("Spell not known: " .. spellName)
        return false
    end
    
    -- Check if in combat restrictions
    if UnitAffectingCombat("player") and not self.config.allow_healing_in_combat then
        self:Log("Combat spell restriction active")
        return false
    end
    
    -- Validate target
    if not targetName then
        targetName = UnitName("player")  -- Default to self
    end
    
    if not self:ValidateTarget(targetName) then
        self:Log("Invalid target: " .. tostring(targetName))
        return false
    end
    
    -- Queue cast or execute immediately
    if self.config.queue_spells then
        self:QueueCast(spellName, targetName)
    else
        self:ExecuteCast(spellName, targetName)
    end
    
    return true
end

function ClickCastingEngine:QueueCast(spellName, targetName)
    if #self.cast_queue >= self.config.max_queue_size then
        self:Log("Cast queue full")
        return false
    end
    
    table.insert(self.cast_queue, {
        spell = spellName,
        target = targetName,
        timestamp = GetTime(),
    })
    
    self:Log("Cast queued: " .. spellName .. " on " .. targetName)
end

function ClickCastingEngine:ExecuteCast(spellName, targetName)
    -- Target the player
    if targetName and targetName ~= UnitName("player") then
        TargetByName(targetName)
    end
    
    -- Cast the spell
    CastSpellByName(spellName)
    
    -- Notify if configured
    if self.config.notify_on_cast then
        self:NotifyPlayer("Casting " .. spellName .. " on " .. targetName)
    end
    
    -- Fire event
    InfinityCore.Events:Fire("spell_cast", {
        spell = spellName,
        target = targetName,
        timestamp = time(),
    })
    
    self:Log("Cast executed: " .. spellName .. " on " .. targetName)
end

function ClickCastingEngine:ValidateSpell(spellName)
    if not spellName then
        return false
    end
    
    -- Check if spell is in spellbook
    local found = false
    for i = 1, GetNumSpellTabs() do
        local name, texture, offset, numSpells = GetSpellTabInfo(i)
        for j = 1, numSpells do
            local spellIndex = offset + j
            local name, rank = GetSpellName(spellIndex, BOOKTYPE_SPELL)
            if name == spellName then
                found = true
                break
            end
        end
        if found then break end
    end
    
    return found
end

function ClickCastingEngine:ValidateTarget(targetName)
    if not targetName then
        return false
    end
    
    -- Check if target is valid
    -- For now, accept any name (actual validation would check raid roster, etc)
    return true
end

function ClickCastingEngine:NotifyPlayer(message)
    if InfinityCore and InfinityCore.SendMessage then
        InfinityCore.SendMessage(UnitName("player"), "[ClickCast] " .. message)
    else
        print("[ClickCast] " .. message)
    end
end

function ClickCastingEngine:GetSpellList()
    local spells = {}
    
    for i = 1, GetNumSpellTabs() do
        local name, texture, offset, numSpells = GetSpellTabInfo(i)
        for j = 1, numSpells do
            local spellIndex = offset + j
            local spellName, rank = GetSpellName(spellIndex, BOOKTYPE_SPELL)
            if spellName then
                table.insert(spells, spellName)
            end
        end
    end
    
    return spells
end

function ClickCastingEngine:CountBindings()
    local count = 0
    for _ in pairs(self.bindings) do
        count = count + 1
    end
    return count
end

function ClickCastingEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function ClickCastingEngine:GetStatus()
    return {
        enabled = self.enabled,
        spell_bindings = self:CountBindings(),
        queue_size = #self.cast_queue,
        queue_enabled = self.config.queue_spells,
    }
end

function ClickCastingEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[ClickCastingEngine] " .. message)
    else
        print("[ClickCastingEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_CLICKCAST1 = "/clickcast"
    SlashCmdList["CLICKCAST"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "bind" then
            local spell, button = args:match("^(%S+)%s+(%S+)$")
            if spell and button then
                ClickCastingEngine:BindSpell(spell, button, {})
                print("Spell bound: " .. spell .. " to " .. button)
            else
                print("Usage: /clickcast bind <spell> <button>")
            end
        elseif cmd == "unbind" then
            if args and args ~= "" then
                ClickCastingEngine:UnbindSpell(args)
                print("Spell unbound: " .. args)
            else
                print("Usage: /clickcast unbind <spell>")
            end
        elseif cmd == "list" then
            local spells = ClickCastingEngine:GetSpellList()
            print("Available spells to bind (" .. #spells .. " total):")
            for i, spell in ipairs(spells) do
                if i <= 20 then  -- Show first 20
                    print("  " .. spell)
                end
            end
        elseif cmd == "status" then
            local status = ClickCastingEngine:GetStatus()
            print("Click-Casting Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Click-Casting Commands:")
            print("  /clickcast bind <spell> <button> - Bind spell to button click")
            print("  /clickcast unbind <spell> - Remove spell binding")
            print("  /clickcast list - List available spells")
            print("  /clickcast status - Show system status")
        end
    end
end

return ClickCastingEngine
