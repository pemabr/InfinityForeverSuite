-- PartyFrameRenderer.lua - Render 5-player party frames
-- Part of PluribusHealer addon suite
-- Lightweight frame rendering for dungeon/5-player scenarios

local PartyFrameRenderer = {}
PartyFrameRenderer.enabled = false
PartyFrameRenderer.db = nil
PartyFrameRenderer.frames = {}
PartyFrameRenderer.party_size = 0
PartyFrameRenderer.frame_pool = {}

-- Configuration
PartyFrameRenderer.config = {
    enabled = true,
    frame_width = 150,
    frame_height = 60,
    frame_spacing = 5,
    max_frames = 5,
    show_numbers = true,
    show_class_colors = true,
    update_interval = 0.5,
    enable_clicks = true,
}

function PartyFrameRenderer:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.party_frames then
        self.db.party_frames = {}
    end
    
    self.enabled = true
    
    -- Create parent frame
    if not self.parent_frame then
        self.parent_frame = CreateFrame("Frame", "PluribusPartyFrames", UIParent)
        self.parent_frame:SetPoint("TOPLEFT", 10, -100)
        self.parent_frame:SetSize(800, 300)
        self.parent_frame:EnableMouse(false)
    end
    
    -- Register for events
    PluribusCore.Events:RegisterListener("party_joined", function(data)
        self:RefreshPartyFrames()
    end)
    
    PluribusCore.Events:RegisterListener("party_left", function(data)
        self:RefreshPartyFrames()
    end)
    
    self:Log("Initialized")
end

function PartyFrameRenderer:RefreshPartyFrames()
    if not self.enabled then
        return
    end
    
    -- Get current party size
    local partySize = GetNumPartyMembers()
    
    if partySize == 0 then
        -- No party, hide all frames
        self:HideAllFrames()
        self.party_size = 0
        return
    end
    
    -- Create or update frames
    for i = 1, math.min(partySize, self.config.max_frames) do
        local unitID = "party" .. i
        local name = UnitName(unitID)
        
        if name then
            self:CreateOrUpdateFrame(i, unitID, name)
        end
    end
    
    -- Hide extra frames
    for i = partySize + 1, self.config.max_frames do
        if self.frames[i] then
            self.frames[i].frame:Hide()
        end
    end
    
    self.party_size = partySize
    self:Log("Party frames refreshed: " .. partySize .. " players")
end

function PartyFrameRenderer:CreateOrUpdateFrame(index, unitID, playerName)
    if not self.frames[index] then
        self.frames[index] = self:CreateFrame(index, unitID)
    end
    
    local frameData = self.frames[index]
    frameData.unit = unitID
    frameData.player = playerName
    
    -- Update frame position
    local offsetX = (index - 1) * (self.config.frame_width + self.config.frame_spacing)
    frameData.frame:SetPoint("TOPLEFT", self.parent_frame, "TOPLEFT", offsetX, 0)
    
    -- Update content
    self:UpdateFrame(index)
    frameData.frame:Show()
end

function PartyFrameRenderer:CreateFrame(index, unitID)
    -- Create main frame
    local frame = CreateFrame("Button", "PluribusPartyFrame" .. index, self.parent_frame)
    frame:SetSize(self.config.frame_width, self.config.frame_height)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Player name
    local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
    nameText:SetSize(140, 15)
    nameText:SetJustifyH("LEFT")
    
    -- Health bar background
    local healthBg = frame:CreateTexture(nil, "BACKGROUND")
    healthBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -22)
    healthBg:SetSize(140, 15)
    healthBg:SetColorTexture(0, 0, 0, 0.5)
    
    -- Health bar
    local healthBar = CreateFrame("StatusBar", nil, frame)
    healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -22)
    healthBar:SetSize(140, 15)
    healthBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    healthBar:SetStatusBarColor(0, 0.8, 0)
    healthBar:SetValue(100)
    
    -- Health text
    local healthText = frame:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    healthText:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
    healthText:SetSize(135, 15)
    healthText:SetJustifyH("CENTER")
    healthText:SetTextColor(1, 1, 1, 1)
    
    -- Class indicator
    local classIndicator = frame:CreateTexture(nil, "OVERLAY")
    classIndicator:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -5)
    classIndicator:SetSize(12, 12)
    
    -- Store frame data
    local frameData = {
        frame = frame,
        nameText = nameText,
        healthBg = healthBg,
        healthBar = healthBar,
        healthText = healthText,
        classIndicator = classIndicator,
        unit = unitID,
        player = "",
        last_health = 0,
        last_max_health = 0,
    }
    
    -- Set up click handler
    if self.config.enable_clicks then
        frame:SetScript("OnClick", function(self, button)
            PartyFrameRenderer:OnFrameClicked(index, button)
        end)
    end
    
    return frameData
end

function PartyFrameRenderer:UpdateFrame(index)
    if not self.frames[index] then
        return
    end
    
    local frameData = self.frames[index]
    local unit = frameData.unit
    
    if not UnitExists(unit) then
        frameData.frame:Hide()
        return
    end
    
    -- Update name
    local name = UnitName(unit)
    frameData.nameText:SetText(name or "Unknown")
    frameData.player = name
    
    -- Update health
    local health = UnitHealth(unit)
    local maxHealth = UnitHealthMax(unit)
    
    if maxHealth > 0 then
        frameData.healthBar:SetValue(health / maxHealth * 100)
        frameData.healthText:SetText(math.floor(health) .. "/" .. math.floor(maxHealth))
    else
        frameData.healthBar:SetValue(0)
        frameData.healthText:SetText("0/0")
    end
    
    -- Update class color
    local classColor = self:GetClassColor(unit)
    if classColor then
        frameData.classIndicator:SetColorTexture(classColor.r, classColor.g, classColor.b, 1)
    end
    
    -- Update frame transparency based on status
    if UnitIsAFK(unit) then
        frameData.frame:SetAlpha(0.5)
    elseif UnitIsDead(unit) then
        frameData.frame:SetAlpha(0.3)
    else
        frameData.frame:SetAlpha(1)
    end
end

function PartyFrameRenderer:GetClassColor(unit)
    local class = select(2, UnitClass(unit))
    
    if class == "WARRIOR" then
        return { r = 0.78, g = 0.61, b = 0.43 }
    elseif class == "PALADIN" then
        return { r = 0.96, g = 0.55, b = 0.73 }
    elseif class == "HUNTER" then
        return { r = 0.67, g = 0.83, b = 0.45 }
    elseif class == "ROGUE" then
        return { r = 1, g = 0.96, b = 0.41 }
    elseif class == "PRIEST" then
        return { r = 1, g = 1, b = 1 }
    elseif class == "SHAMAN" then
        return { r = 0, g = 0.44, b = 0.87 }
    elseif class == "DRUID" then
        return { r = 1, g = 0.49, b = 0.04 }
    elseif class == "WARLOCK" then
        return { r = 0.58, g = 0.51, b = 0.79 }
    elseif class == "MAGE" then
        return { r = 0.41, g = 0.80, b = 0.94 }
    end
    
    return { r = 0.5, g = 0.5, b = 0.5 }
end

function PartyFrameRenderer:OnFrameClicked(index, button)
    if not self.frames[index] then
        return
    end
    
    local frameData = self.frames[index]
    local player = frameData.player
    
    if button == "LeftButton" then
        if IsShiftKeyDown() then
            -- Shift-click: open character info
            if CanInspect(frameData.unit) then
                InspectUnit(frameData.unit)
            end
        else
            -- Normal click: target player
            TargetByName(player)
        end
    elseif button == "RightButton" then
        -- Right-click: open context menu
        self:ShowContextMenu(index)
    end
    
    -- Fire event
    PluribusCore.Events:Fire("party_frame_clicked", {
        index = index,
        player = player,
        button = button,
    })
end

function PartyFrameRenderer:ShowContextMenu(index)
    if not self.frames[index] then
        return
    end
    
    local frameData = self.frames[index]
    local player = frameData.player
    
    -- Create menu
    local menu = {
        { text = "Target " .. player, func = function() TargetByName(player) end },
        { text = "Inspect", func = function() InspectUnit(frameData.unit) end },
        { text = "Invite to Group", func = function() GroupInvite(player) end },
    }
    
    self:Log("Context menu for " .. player .. " (placeholder)")
end

function PartyFrameRenderer:HideAllFrames()
    for i = 1, self.config.max_frames do
        if self.frames[i] then
            self.frames[i].frame:Hide()
        end
    end
end

function PartyFrameRenderer:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function PartyFrameRenderer:GetStatus()
    return {
        enabled = self.enabled,
        party_size = self.party_size,
        frames_rendered = math.min(self.party_size, self.config.max_frames),
        frame_width = self.config.frame_width,
        frame_height = self.config.frame_height,
    }
end

function PartyFrameRenderer:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[PartyFrameRenderer] " .. message)
    else
        print("[PartyFrameRenderer] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_PARTYUI1 = "/partyui"
    SlashCmdList["PARTYUI"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "refresh" then
            PartyFrameRenderer:RefreshPartyFrames()
            print("Party frames refreshed")
        elseif cmd == "status" then
            local status = PartyFrameRenderer:GetStatus()
            print("Party Frame Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        elseif cmd == "hide" then
            PartyFrameRenderer:HideAllFrames()
            print("Party frames hidden")
        elseif cmd == "config" then
            if args and args ~= "" then
                local key, value = args:match("^(%S+)%s+(%S+)$")
                if key and value then
                    PartyFrameRenderer:SetConfig(key, value)
                    print("Config set: " .. key .. " = " .. value)
                else
                    print("Usage: /partyui config <key> <value>")
                end
            else
                print("Party Frame Config:")
                for k, v in pairs(PartyFrameRenderer.config) do
                    print("  " .. k .. ": " .. tostring(v))
                end
            end
        else
            print("Party Frame Commands:")
            print("  /partyui refresh - Refresh party frames")
            print("  /partyui status - Show system status")
            print("  /partyui hide - Hide party frames")
            print("  /partyui config <key> <value> - Set config value")
        end
    end
end

return PartyFrameRenderer
