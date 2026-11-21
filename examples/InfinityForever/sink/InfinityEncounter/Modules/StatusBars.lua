-- Status Bars Module
-- Render encounter status bars for timers and boss health

local InfinityEncounterStatusBars = {}
_G.InfinityEncounterStatusBars = InfinityEncounterStatusBars

InfinityEncounterStatusBars.bars = {}
InfinityEncounterStatusBars.bar_height = 20
InfinityEncounterStatusBars.bar_width = 200

-- Create a status bar
function InfinityEncounterStatusBars:CreateBar(name, initialValue, maxValue, options)
    options = options or {}
    
    local bar = {
        name = name,
        value = initialValue or 0,
        maxValue = maxValue or 100,
        label = options.label or name,
        color = options.color or {r = 0.2, g = 0.8, b = 0.2},
        x = options.x or 10,
        y = options.y or 100,
        width = options.width or self.bar_width,
        height = options.height or self.bar_height,
        visible = options.visible or true,
    }
    
    self.bars[name] = bar
    return bar
end

function InfinityEncounterStatusBars:UpdateBar(name, value, maxValue)
    local bar = self.bars[name]
    if not bar then return false end
    
    bar.value = value
    if maxValue then
        bar.maxValue = maxValue
    end
    
    return true
end

function InfinityEncounterStatusBars:GetBar(name)
    return self.bars[name]
end

function InfinityEncounterStatusBars:RemoveBar(name)
    self.bars[name] = nil
end

function InfinityEncounterStatusBars:GetBars()
    return self.bars
end

function InfinityEncounterStatusBars:ClearBars()
    self.bars = {}
end

-- Get bar progress (0-1)
function InfinityEncounterStatusBars:GetProgress(name)
    local bar = self.bars[name]
    if not bar or bar.maxValue == 0 then return 0 end
    return math.min(1, math.max(0, bar.value / bar.maxValue))
end

-- Get bar display text
function InfinityEncounterStatusBars:GetDisplayText(name)
    local bar = self.bars[name]
    if not bar then return "" end
    
    local percent = (bar.value / bar.maxValue) * 100
    return string.format("%s: %.1f%% (%d/%d)", bar.label, percent, bar.value, bar.maxValue)
end

-- Render bars to screen (would be called from UI)
function InfinityEncounterStatusBars:RenderBars(frame)
    if not frame then return end
    
    local yOffset = 0
    for name, bar in pairs(self.bars) do
        if bar.visible then
            -- Create frame if needed
            local barFrame = frame:CreateTexture(name .. "_bar", "BACKGROUND")
            barFrame:SetSize(bar.width, bar.height)
            barFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", bar.x, -bar.y - yOffset)
            
            -- Set color based on progress
            local progress = self:GetProgress(name)
            local color = bar.color
            barFrame:SetColorTexture(color.r * progress, color.g * progress, color.b * progress, 0.8)
            
            -- Update text
            local textString = frame:CreateFontString(name .. "_text", "ARTWORK", "GameFontNormal")
            textString:SetPoint("CENTER", barFrame)
            textString:SetText(self:GetDisplayText(name))
            
            yOffset = yOffset + bar.height + 5
        end
    end
end

return InfinityEncounterStatusBars
