-- Main UI
-- Encounter window and status display

local InfinityEncounterUI = {}
_G.InfinityEncounterUI = InfinityEncounterUI

function InfinityEncounterUI:Initialize()
    if self.initialized then return end
    self.frame = CreateFrame("Frame", "InfinityEncounterMainFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.frame:SetSize(400, 300)
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    self.frame:SetBackdropColor(0, 0, 0, 0.8)
    self.frame:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
    
    -- Title
    local title = self.frame:CreateFontString(nil, "ARTWORK", (GameFontBold and "GameFontBold" or "GameFontNormalLarge"))
    title:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -10)
    title:SetText("Infinity Encounter")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() self.frame:Hide() end)
    
    -- Status text
    self.status_text = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.status_text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    self.status_text:SetWidth(380)
    self.status_text:SetJustifyH("LEFT")
    self.status_text:SetText("No encounter active")
    
    -- Abilities section
    self.abilities_frame = CreateFrame("Frame", nil, self.frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.abilities_frame:SetSize(380, 100)
    self.abilities_frame:SetPoint("TOPLEFT", self.status_text, "BOTTOMLEFT", 0, -20)
    
    -- Timer section
    self.timer_frame = CreateFrame("Frame", nil, self.frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.timer_frame:SetSize(380, 50)
    self.timer_frame:SetPoint("TOPLEFT", self.abilities_frame, "BOTTOMLEFT", 0, -10)

    local journalButton = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    journalButton:SetSize(130, 22)
    journalButton:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 10, 10)
    journalButton:SetText("Journal")
    journalButton:SetScript("OnClick", function() self:ShowJournal() end)
    local controls = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    controls:SetSize(130, 22)
    controls:SetPoint("LEFT", journalButton, "RIGHT", 8, 0)
    controls:SetText("Controls")
    controls:SetScript("OnClick", function() self:ShowControls() end)
    
    self.frame:Hide()
    self.initialized = true
end

local function EncounterInput(box)
    local value = box:GetText()
    if _G.issecretvalue and _G.issecretvalue(value) then
        InfinityUtils:Warning("Protected input cannot be used.", "Encounter")
        return nil
    end
    if type(value) ~= "string" then
        InfinityUtils:Warning("Encounter input is unavailable.", "Encounter")
        return nil
    end
    return value:match("^%s*(.-)%s*$")
end

function InfinityEncounterUI:RunAction(action, input)
    local callback = self.actions and self.actions[action]
    if not callback then InfinityUtils:Warning("Encounter action is unavailable.", "Encounter"); return end
    callback(input or "")
end

function InfinityEncounterUI:ShowControls()
    if not _G.InfinityUIFramework then InfinityUtils:Warning("Encounter controls unavailable.", "Encounter"); return end
    if not self.controls then
        local frame = InfinityUIFramework:CreateListWindow("InfinityEncounterControlsWindow", "Encounter Controls", 680, 500)
        local textLabel = InfinityUIFramework:CreateLabel(frame, "Name / label")
        textLabel:SetPoint("TOPLEFT", 15, -43)
        local text = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        text:SetSize(220, 20)
        text:SetPoint("TOPLEFT", 105, -38)
        text:SetAutoFocus(false)
        text:SetMaxLetters(80)
        local idLabel = InfinityUIFramework:CreateLabel(frame, "ID / seconds")
        idLabel:SetPoint("TOPLEFT", 345, -43)
        local id = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        id:SetSize(100, 20)
        id:SetPoint("TOPLEFT", 440, -38)
        id:SetAutoFocus(false)
        id:SetMaxLetters(10)
        self.controls, self.controlText, self.controlID = frame, text, id
    end
    self.confirmControl = nil
    self:RefreshControls()
    self.controls:Show()
end

function InfinityEncounterUI:RefreshControls()
    if not self.controls then return end
    local function Inputs()
        local text, id = EncounterInput(self.controlText), EncounterInput(self.controlID)
        if text == nil or id == nil then return nil end
        return text, id
    end
    local actions = {
        { "Start manual timer | seconds and name", function()
            local text, id = Inputs()
            if text then self:RunAction("timer", id .. " " .. text) end
        end },
        { "Stop manual timer | name", function()
            local text = Inputs()
            if text then self:RunAction("timer stop", text) end
        end },
        { "Open journal encounter | ID (optional)", function()
            local text, id = Inputs()
            if text then self:RunAction("journal", id) end
        end },
        { "Watch boss spell | spell ID and optional label", function()
            local text, id = Inputs()
            if text then self:RunAction("watch add", id .. " " .. text) end
        end },
        { "Manage watched boss spells", function() self:ShowWatches() end },
        { "Save current watches as preset | name", function()
            local text = Inputs()
            if text then self:RunAction("preset", "create " .. text) end
        end },
        { "Manage boss presets", function() self:ShowPresets() end },
        { "Enable DBM live timers", function() self:RunAction("dbm", "on") end },
        { "Disable DBM live timers", function() self:RunAction("dbm", "off") end },
        { "Allow DBM preset imports", function() self:RunAction("dbm import", "on") end },
        { "Disable DBM preset imports", function() self:RunAction("dbm import", "off") end },
        { "Browse loaded DBM modules | optional name filter", function()
            local text = Inputs()
            if text then self:ShowDBMModules(text) end
        end },
        { "Test encounter alerts", function() self:RunAction("test") end },
        { "Reset encounter data | click twice to confirm", function()
            if self.confirmControl ~= "reset" then
                self.confirmControl = "reset"
                self.controls.status:SetText("Reset encounter data? Click the same action again to confirm.")
            else self.confirmControl = nil; self:RunAction("reset") end
        end },
    }
    local rows = {}
    for _, action in ipairs(actions) do
        local item = action
        rows[#rows + 1] = { text = item[1], onClick = function()
            if self.lastControl ~= item[1] then self.confirmControl = nil end
            self.lastControl = item[1]
            item[2]()
        end }
    end
    self.controls.status:SetText("Enter the requested values above and click an action.")
    self.controls:SetItems(rows)
end

function InfinityEncounterUI:ShowWatches()
    local abilities = _G.InfinityEncounterAbilities
    if not abilities or type(abilities.watchedSpells) ~= "table" then
        InfinityUtils:Warning("Encounter watches unavailable.", "Encounter")
        return
    end
    if not self.watches then self.watches = InfinityUIFramework:CreateListWindow("InfinityEncounterWatchesWindow", "Boss Spell Watches", 600, 450) end
    local ids, rows = {}, {}
    for id in pairs(abilities.watchedSpells) do if type(id) == "number" then ids[#ids + 1] = id end end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local spellID = id
        rows[#rows + 1] = { text = spellID .. " - " .. tostring(abilities.watchedSpells[spellID]) .. " | click twice to remove",
            onClick = function()
                if self.confirmWatch ~= spellID then
                    self.confirmWatch = spellID
                    self.watches.status:SetText("Remove watch " .. spellID .. "? Click again to confirm.")
                else
                    self.confirmWatch = nil
                    self:RunAction("watch remove", tostring(spellID))
                    self:ShowWatches()
                end
            end }
    end
    if #rows == 0 then rows[1] = { text = "No watched boss spells." } end
    if not self.watches:IsShown() then self.confirmWatch = nil end
    self.watches.status:SetText("Add a watch in Encounter Controls.")
    self.watches:SetItems(rows)
    self.watches:Show()
end

function InfinityEncounterUI:ShowPresets()
    local presets = _G.InfinityEncounterPresets
    if not presets then InfinityUtils:Warning("Boss presets unavailable.", "Encounter"); return end
    local entries = presets:GetAll()
    if not entries then return end
    if not self.presetsWindow then self.presetsWindow = InfinityUIFramework:CreateListWindow("InfinityEncounterPresetsWindow", "Boss Presets", 650, 450) end
    local rows = {}
    local function Add(text, key, fn)
        rows[#rows + 1] = { text = text, onClick = function()
            if self.confirmPreset ~= key then
                self.confirmPreset = key
                self.presetsWindow.status:SetText("Click the same action again to confirm: " .. text)
            else
                self.confirmPreset = nil
                fn()
                self:ShowPresets()
            end
        end }
    end
    Add("Disable all boss watches", "none", function() presets:Use("none") end)
    for _, entry in ipairs(entries) do
        local id, name = entry.id, entry.preset.name
        Add("Apply " .. name .. " (" .. id .. ") | replaces current watches", "use:" .. id, function() presets:Use(id) end)
        rows[#rows + 1] = { text = "Share " .. name .. " with guild", onClick = function()
            self.confirmPreset = nil
            presets:Send(id)
        end }
        Add("Delete " .. name .. " (" .. id .. ")", "delete:" .. id, function() presets:Delete(id) end)
    end
    if not self.presetsWindow:IsShown() then self.confirmPreset = nil end
    self.presetsWindow.status:SetText("Applying or deleting requires two clicks.")
    self.presetsWindow:SetItems(rows)
    self.presetsWindow:Show()
end

function InfinityEncounterUI:ShowDBMModules(filter)
    local bridge = _G.InfinityEncounterDBMBridge
    if not bridge then InfinityUtils:Warning("DBM imports unavailable.", "Encounter"); return end
    local ids = bridge:GetModules(filter)
    if not ids then return end
    if not self.dbmWindow then self.dbmWindow = InfinityUIFramework:CreateListWindow("InfinityEncounterDBMModulesWindow", "DBM Modules", 600, 450) end
    local rows = {}
    for index = 1, math.min(#ids, 100) do
        local id = ids[index]
        rows[#rows + 1] = { text = id .. " | click to import as preset", onClick = function() bridge:ImportModule(id) end }
    end
    if #rows == 0 then rows[1] = { text = "No matching DBM modules loaded." } end
    self.dbmWindow.status:SetText(#ids > 100 and "First 100 shown; use a name filter." or "Enable DBM imports in Encounter Controls first.")
    self.dbmWindow:SetItems(rows)
    self.dbmWindow:Show()
end

function InfinityEncounterUI:Toggle()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:SetShown(not self.frame:IsShown())
end

function InfinityEncounterUI:Show()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:Show()
end

function InfinityEncounterUI:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function InfinityEncounterUI:ShowJournal(journalID)
    local database = _G.InfinityEncounterDB
    if not database then
        InfinityUtils:Warning("Encounter Journal database is unavailable.", "Encounter")
        return false
    end
    local ok, text, err = pcall(function()
        if journalID then return database:GetJournalEncounter(journalID) end
        return database:GetJournalList()
    end)
    if not ok then
        if _G.issecretvalue and _G.issecretvalue(text) then text = nil end
        InfinityUtils:Warning("Encounter Journal lookup failed: " .. tostring(text or "protected error"), "Encounter")
        return false
    end
    if not text then
        InfinityUtils:Warning(err, "Encounter")
        return false
    end
    if not self.journalFrame then
        local frame = CreateFrame("Frame", "InfinityEncounterJournalFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        frame:SetSize(600, 480)
        frame:SetPoint("CENTER")
        frame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0, 0, 0, 0.9)
        frame:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -12)
        title:SetText("Encounter Journal")
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
        close:SetScript("OnClick", function() frame:Hide() end)
        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -40)
        scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 15)
        local child = CreateFrame("Frame", nil, scroll)
        child:SetSize(550, 425)
        scroll:SetScrollChild(child)
        local content = child:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        content:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
        content:SetWidth(550)
        content:SetJustifyH("LEFT")
        self.journalFrame, self.journalScroll, self.journalChild, self.journalText = frame, scroll, child, content
    end
    self.journalText:SetText(text)
    local height = self.journalText:GetStringHeight()
    if _G.issecretvalue and _G.issecretvalue(height) then height = nil end
    self.journalChild:SetHeight(math.max(425, type(height) == "number" and height + 10 or 0))
    self.journalScroll:SetVerticalScroll(0)
    self.journalFrame:Show()
    return true
end

function InfinityEncounterUI:Update()
    if not self.initialized or not self.frame:IsShown() then
        return
    end
    
    -- Update status
    local boss = InfinityEncounterMgr:GetCurrentBoss()
    if boss then
        local text = "Boss: " .. tostring(boss.name or "Boss")
        if boss.healthPercent then
            text = text .. string.format("\nHealth: %.1f%% (%d/%d)", boss.healthPercent, boss.health, boss.maxHealth)
        else
            text = text .. "\nHealth: unavailable"
        end
        self.status_text:SetText(text)
    else
        local active = InfinityEncounterMgr.active_encounters
        local encounter = active and active[#active]
        self.status_text:SetText(encounter and ("Encounter: " .. encounter.name) or "No encounter active")
    end

    -- Update abilities
    if InfinityEncounterAbilities then
        local history = InfinityEncounterAbilities.ability_history or {}
        local abilityText = ""
        local startIdx = math.max(1, #history - 4)
        for i = #history, startIdx, -1 do
            local ab = history[i]
            abilityText = abilityText .. string.format("• %s (ID %s)\n", tostring(ab.name or "Unknown"), tostring(ab.spellID or "?"))
        end
        if abilityText == "" then
            abilityText = "No boss abilities recorded yet"
        end
        if not self.abilities_text then
            self.abilities_text = self.abilities_frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            self.abilities_text:SetPoint("TOPLEFT", self.abilities_frame, "TOPLEFT", 0, 0)
            self.abilities_text:SetWidth(380)
            self.abilities_text:SetJustifyH("LEFT")
        end
        self.abilities_text:SetText(abilityText)
    end
    
    -- Update timers
    if InfinityEncounterTimer then
        local timers = {}
        for _, timer in ipairs(InfinityEncounterTimer:GetActiveTimers()) do
            timers[#timers + 1] = { timer = timer, remaining = timer:GetRemaining() }
        end
        table.sort(timers, function(a, b) return a.remaining < b.remaining end)
        local timerText = ""
        for i = 1, math.min(3, #timers) do
            local timer, remaining = timers[i].timer, timers[i].remaining
            timerText = timerText .. string.format("%s: %.1fs%s\n", timer.name, remaining,
                timer.pausedRemaining ~= nil and " (paused)" or "")
        end
        
        if timerText == "" then
            timerText = "No active timers"
        end
        
        if not self.timer_text then
            self.timer_text = self.timer_frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            self.timer_text:SetPoint("TOPLEFT", self.timer_frame, "TOPLEFT", 0, 0)
            self.timer_text:SetWidth(380)
            self.timer_text:SetJustifyH("LEFT")
        end
        self.timer_text:SetText(timerText)
    end
end

return InfinityEncounterUI
