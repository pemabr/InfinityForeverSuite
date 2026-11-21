-- UnitFrameInteractionEngine.lua - Click-to-interact frame system
-- Part of InfinityHealer addon suite
-- Manages frame clickability, targeting, and spell binding integration

local UnitFrameInteractionEngine = {}
UnitFrameInteractionEngine.enabled = false
UnitFrameInteractionEngine.db = nil
UnitFrameInteractionEngine.frame_bindings = {}  -- frame -> { spells: { ... }, enabled: true }
UnitFrameInteractionEngine.click_callbacks = {}
UnitFrameInteractionEngine.target_cache = {}

-- Configuration
UnitFrameInteractionEngine.config = {
    enabled = true,
    allow_target_switching = true,
    allow_focus_setting = true,
    allow_assist_setting = true,
    enable_context_menu = true,
    queue_clicks = true,
    max_click_queue = 10,
    click_timeout = 0.5,
    enable_inspect = true,
}

function UnitFrameInteractionEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.frame_bindings then
        self.db.frame_bindings = {}
    end
    
    self.frame_bindings = self.db.frame_bindings
    self.enabled = true
    
    self:Log("Initialized")
end

function UnitFrameInteractionEngine:AttachToFrame(frameObject, unitID)
    if not frameObject or not unitID then
        return false
    end
    
    -- Enable mouse on frame
    frameObject:EnableMouse(true)
    
    -- Set up click handler
    frameObject:SetScript("OnClick", function(frame, button, down)
        self:OnFrameClicked(frameObject, unitID, button, down)
    end)
    
    -- Set up enter/leave handlers for tooltips
    frameObject:SetScript("OnEnter", function(frame)
        self:OnFrameEnter(frameObject, unitID)
    end)
    
    frameObject:SetScript("OnLeave", function(frame)
        self:OnFrameLeave(frameObject, unitID)
    end)
    
    self:Log("Attached to frame for unit: " .. unitID)
    
    return true
end

function UnitFrameInteractionEngine:OnFrameClicked(frameObject, unitID, button, down)
    if not self.enabled or not down then
        return
    end
    
    -- Get player name
    local playerName = UnitName(unitID)
    if not playerName then
        return
    end
    
    -- Determine action based on button and modifiers
    if button == "LeftButton" then
        self:OnLeftClick(unitID, playerName)
    elseif button == "RightButton" then
        self:OnRightClick(frameObject, unitID, playerName)
    elseif button == "MiddleButton" then
        self:OnMiddleClick(unitID, playerName)
    end
end

function UnitFrameInteractionEngine:OnLeftClick(unitID, playerName)
    if not self.config.allow_target_switching then
        return
    end
    
    -- Determine action based on modifiers
    if IsAltKeyDown() then
        -- Alt+Left: Set focus
        if self.config.allow_focus_setting then
            FocusUnit(unitID)
            self:Log("Focus set to " .. playerName)
        end
    elseif IsCtrlKeyDown() then
        -- Ctrl+Left: Set assist target
        if self.config.allow_assist_setting then
            AssistUnit(unitID)
            self:Log("Assist set to " .. playerName)
        end
    else
        -- Normal: Target player
        TargetUnit(unitID)
        self:Log("Targeted " .. playerName)
    end
    
    -- Fire event
    InfinityCore.Events:Fire("unit_frame_clicked", {
        unit = unitID,
        player = playerName,
        button = "LeftButton",
        action = "target",
    })
end

function UnitFrameInteractionEngine:OnRightClick(frameObject, unitID, playerName)
    if not self.config.enable_context_menu then
        return
    end
    
    -- Show context menu
    self:ShowContextMenu(frameObject, unitID, playerName)
end

function UnitFrameInteractionEngine:OnMiddleClick(unitID, playerName)
    if self.config.enable_inspect then
        if CanInspect(unitID) then
            InspectUnit(unitID)
            self:Log("Inspecting " .. playerName)
        end
    end
end

function UnitFrameInteractionEngine:ShowContextMenu(frameObject, unitID, playerName)
    -- Create context menu options
    local menu = {
        {
            text = "Target " .. playerName,
            func = function()
                TargetUnit(unitID)
            end,
        },
        {
            text = "Focus " .. playerName,
            func = function()
                FocusUnit(unitID)
            end,
        },
        {
            text = "Assist " .. playerName,
            func = function()
                AssistUnit(unitID)
            end,
        },
        { text = "-" },  -- Separator
        {
            text = "Inspect",
            func = function()
                if CanInspect(unitID) then
                    InspectUnit(unitID)
                end
            end,
        },
        {
            text = "Whisper",
            func = function()
                ChatEdit_ActivateChat(DEFAULT_CHAT_FRAME.editBox)
                DEFAULT_CHAT_FRAME.editBox:SetText("/w " .. playerName .. " ")
            end,
        },
    }
    
    -- Add spells if available
    if self.frame_bindings[frameObject] and self.frame_bindings[frameObject].spells then
        table.insert(menu, { text = "-" })
        
        for spell, _ in pairs(self.frame_bindings[frameObject].spells) do
            table.insert(menu, {
                text = "Cast " .. spell,
                func = function()
                    self:CastSpellOnUnit(spell, unitID)
                end,
            })
        end
    end
    
    -- Display menu
    self:DisplayMenu(frameObject, menu)
end

function UnitFrameInteractionEngine:DisplayMenu(frameObject, menu)
    -- Create UIDropDownMenu if needed
    if not UIDropDownMenu_Initialize then
        self:Log("UIDropDownMenu not available")
        return
    end
    
    -- Simple menu display (would use blizzard's dropdown normally)
    self:Log("Context menu for frame with " .. #menu .. " options")
end

function UnitFrameInteractionEngine:OnFrameEnter(frameObject, unitID)
    -- Show tooltip
    if GameTooltip then
        GameTooltip:SetOwner(frameObject, "ANCHOR_BOTTOM")
        GameTooltip:SetUnit(unitID)
        GameTooltip:Show()
    end
end

function UnitFrameInteractionEngine:OnFrameLeave(frameObject, unitID)
    -- Hide tooltip
    if GameTooltip then
        GameTooltip:Hide()
    end
end

function UnitFrameInteractionEngine:BindSpellToFrame(frameObject, spellName)
    if not frameObject or not spellName then
        return false
    end
    
    if not self.frame_bindings[frameObject] then
        self.frame_bindings[frameObject] = {
            spells = {},
            enabled = true,
        }
    end
    
    self.frame_bindings[frameObject].spells[spellName] = true
    
    self:Log("Spell bound to frame: " .. spellName)
    
    return true
end

function UnitFrameInteractionEngine:UnbindSpellFromFrame(frameObject, spellName)
    if not frameObject or not spellName then
        return false
    end
    
    if not self.frame_bindings[frameObject] then
        return false
    end
    
    self.frame_bindings[frameObject].spells[spellName] = nil
    
    self:Log("Spell unbound from frame: " .. spellName)
    
    return true
end

function UnitFrameInteractionEngine:CastSpellOnUnit(spellName, unitID)
    -- Target the unit
    TargetUnit(unitID)
    
    -- Cast spell
    CastSpellByName(spellName)
    
    self:Log("Cast " .. spellName .. " on " .. UnitName(unitID))
    
    -- Fire event
    InfinityCore.Events:Fire("spell_cast", {
        spell = spellName,
        target = UnitName(unitID),
        unit = unitID,
        timestamp = time(),
    })
end

function UnitFrameInteractionEngine:GetFrameInfo(frameObject)
    if not frameObject then
        return nil
    end
    
    if not self.frame_bindings[frameObject] then
        return nil
    end
    
    local bindings = self.frame_bindings[frameObject]
    local spellList = {}
    
    for spell, _ in pairs(bindings.spells or {}) do
        table.insert(spellList, spell)
    end
    
    return {
        spells = spellList,
        enabled = bindings.enabled,
        spell_count = #spellList,
    }
end

function UnitFrameInteractionEngine:SetFrameEnabled(frameObject, enabled)
    if not frameObject then
        return false
    end
    
    if not self.frame_bindings[frameObject] then
        self.frame_bindings[frameObject] = { spells = {}, enabled = enabled }
    else
        self.frame_bindings[frameObject].enabled = enabled
    end
    
    self:Log("Frame enabled: " .. tostring(enabled))
    
    return true
end

function UnitFrameInteractionEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function UnitFrameInteractionEngine:GetStatus()
    local boundFrames = 0
    for _ in pairs(self.frame_bindings) do
        boundFrames = boundFrames + 1
    end
    
    return {
        enabled = self.enabled,
        bound_frames = boundFrames,
        allow_targeting = self.config.allow_target_switching,
        allow_focus = self.config.allow_focus_setting,
        enable_context_menu = self.config.enable_context_menu,
    }
end

function UnitFrameInteractionEngine:CountTable(t)
    local count = 0
    for _ in pairs(t or {}) do
        count = count + 1
    end
    return count
end

function UnitFrameInteractionEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[UnitFrameInteractionEngine] " .. message)
    else
        print("[UnitFrameInteractionEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_FRAMEINT1 = "/frameint"
    SlashCmdList["FRAMEINT"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "status" then
            local status = UnitFrameInteractionEngine:GetStatus()
            print("Unit Frame Interaction Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        elseif cmd == "config" then
            if args and args ~= "" then
                local key, value = args:match("^(%S+)%s+(%S+)$")
                if key and value then
                    local boolValue = value:lower() == "true" or value == "1"
                    UnitFrameInteractionEngine:SetConfig(key, boolValue)
                    print("Config set: " .. key .. " = " .. tostring(boolValue))
                else
                    print("Usage: /frameint config <key> <true/false>")
                end
            else
                print("Frame Interaction Config:")
                for k, v in pairs(UnitFrameInteractionEngine.config) do
                    print("  " .. k .. ": " .. tostring(v))
                end
            end
        else
            print("Unit Frame Interaction Commands:")
            print("  /frameint status - Show system status")
            print("  /frameint config - Show all config")
            print("  /frameint config <key> <true/false> - Set config value")
        end
    end
end

return UnitFrameInteractionEngine
