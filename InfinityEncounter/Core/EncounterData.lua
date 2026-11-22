-- Encounter Database
-- Boss data, abilities, timers, and phase information for all encounters

local InfinityEncounterDB = {}
_G.InfinityEncounterDB = InfinityEncounterDB

InfinityEncounterDB.encounters = {
    -- Example boss data structure
    -- [bossId] = {
    --     name = "Boss Name",
    --     zone = "Zone Name",
    --     encounterID = encounterID,
    --     difficulty = "Mythic" | "Heroic" | "Normal",
    --     phases = {
    --         { name = "Phase 1", healthPercent = 100 },
    --     },
    --     abilities = {
    --         [spellID] = {
    --             name = "Spell Name",
    --             type = "tank" | "group" | "raid" | "phase",
    --             timer = 30,
    --             cooldown = 45,
    --             alertTime = 10,
    --         },
    --     },
    --     mechanics = {
    --         "Mechanic 1",
    --         "Mechanic 2",
    --     },
    -- }
}

function InfinityEncounterDB:RegisterEncounter(bossId, data)
    if not bossId or not data or not data.name then
        return false
    end
    
    self.encounters[bossId] = data
    return true
end

function InfinityEncounterDB:GetEncounter(bossId)
    return self.encounters[bossId]
end

function InfinityEncounterDB:GetEncountersByZone(zone)
    local result = {}
    for bossId, encounter in pairs(self.encounters) do
        if encounter.zone == zone then
            table.insert(result, encounter)
        end
    end
    return result
end

function InfinityEncounterDB:GetAbility(bossId, spellID)
    local encounter = self:GetEncounter(bossId)
    if encounter and encounter.abilities then
        return encounter.abilities[spellID]
    end
    return nil
end

function InfinityEncounterDB:RegisterAbility(bossId, spellID, abilityData)
    local encounter = self:GetEncounter(bossId)
    if encounter then
        if not encounter.abilities then
            encounter.abilities = {}
        end
        encounter.abilities[spellID] = abilityData
        return true
    end
    return false
end

function InfinityEncounterDB:GetPhases(bossId)
    local encounter = self:GetEncounter(bossId)
    if encounter then
        return encounter.phases or {}
    end
    return {}
end

function InfinityEncounterDB:GetMechanics(bossId)
    local encounter = self:GetEncounter(bossId)
    if encounter then
        return encounter.mechanics or {}
    end
    return {}
end

local function Public(value)
    if _G.issecretvalue and _G.issecretvalue(value) then return nil end
    return value
end

local function PositiveID(value)
    value = Public(value)
    return type(value) == "number" and value > 0 and value < math.huge and value == math.floor(value)
end

local function Text(value)
    value = Public(value)
    return type(value) == "string" and value or nil
end

function InfinityEncounterDB:Initialize()
end

function InfinityEncounterDB:GetJournalInstance()
    if not (_G.C_Map and C_Map.GetBestMapForUnit and _G.EJ_GetInstanceForMap) then
        return nil, "Encounter Journal map lookup is unavailable."
    end
    local mapID = Public(C_Map.GetBestMapForUnit("player"))
    local visited = {}
    for _ = 1, 10 do
        if not PositiveID(mapID) or visited[mapID] then break end
        visited[mapID] = true
        local instanceID = Public(EJ_GetInstanceForMap(mapID))
        if PositiveID(instanceID) then return instanceID end
        local info = C_Map.GetMapInfo and Public(C_Map.GetMapInfo(mapID))
        mapID = type(info) == "table" and Public(info.parentMapID) or nil
    end
    return nil, "No Encounter Journal instance found for the current map."
end

function InfinityEncounterDB:GetJournalList()
    if not _G.EJ_GetEncounterInfoByIndex then
        return nil, "Encounter Journal is unavailable on this client."
    end
    local instanceID, err = self:GetJournalInstance()
    if not instanceID then return nil, err end
    local lines = { "Current instance: Journal encounters",
        "Use /encounter journal <journal ID> for details.", "" }
    for index = 1, 100 do
        local name, _, journalID = EJ_GetEncounterInfoByIndex(index, instanceID)
        if _G.issecretvalue and _G.issecretvalue(name) then
            return nil, "Encounter Journal entries are protected."
        end
        name, journalID = Text(name), Public(journalID)
        if index == 1 and not name and _G.EJ_SelectInstance then
            local selectedName = EJ_GetEncounterInfoByIndex(1)
            if _G.issecretvalue and _G.issecretvalue(selectedName) then
                return nil, "Encounter Journal entries are protected."
            end
            if not Text(selectedName) then
                local combat = _G.InCombatLockdown and Public(InCombatLockdown())
                if _G.InCombatLockdown and combat ~= false then
                    return nil, "Open the Encounter Journal outside combat before listing this instance."
                end
                EJ_SelectInstance(instanceID)
                name, _, journalID = EJ_GetEncounterInfoByIndex(index, instanceID)
                if _G.issecretvalue and _G.issecretvalue(name) then
                    return nil, "Encounter Journal entries are protected."
                end
                name, journalID = Text(name), Public(journalID)
            end
        end
        if not name or not PositiveID(journalID) then break end
        lines[#lines + 1] = journalID .. " - " .. name
    end
    if #lines == 3 then
        return nil, "No encounters available for this map. Open the in-game Encounter Journal and try again."
    end
    if #lines == 103 then lines[#lines + 1] = "Additional encounters omitted." end
    return table.concat(lines, "\n")
end

function InfinityEncounterDB:GetJournalEncounter(journalID)
    if not PositiveID(journalID) then return nil, "Enter a positive journal encounter ID." end
    if not (_G.EJ_GetEncounterInfo and _G.C_EncounterJournal and C_EncounterJournal.GetSectionInfo) then
        return nil, "Encounter Journal details are unavailable on this client."
    end
    local name, description, _, root = EJ_GetEncounterInfo(journalID)
    name, description, root = Text(name), Text(description), Public(root)
    if not name or name == "" then return nil, "Journal encounter not found: " .. journalID end
    local lines = { name .. " (Journal ID " .. journalID .. ")",
        "Journal descriptions; not automatic timers.", "" }
    if description and description ~= "" then lines[#lines + 1] = description .. "\n" end
    local stack, visited, count, displayed, omitted = {}, {}, 0, 0, false
    if PositiveID(root) then stack[1] = { root, 0 } end
    while #stack > 0 and count < 120 do
        local entry = table.remove(stack)
        local sectionID, depth = entry[1], entry[2]
        if not visited[sectionID] then
            visited[sectionID] = true
            count = count + 1
            local info = Public(C_EncounterJournal.GetSectionInfo(sectionID))
            if type(info) == "table" then
                local title, detail = Text(info.title), Text(info.description)
                local filtered = Public(info.filteredByDifficulty)
                local spellID = Public(info.spellID)
                if title and title ~= "" then
                    lines[#lines + 1] = string.rep("  ", depth) .. title
                        .. (PositiveID(spellID) and (" [Spell ID " .. spellID .. "]") or "")
                        .. (filtered == true and " (other difficulty)" or "")
                    displayed = displayed + 1
                    if detail and detail ~= "" then
                        if #detail > 2000 then detail = detail:sub(1, 2000) .. " [truncated]" end
                        lines[#lines + 1] = detail
                    end
                end
                local child, sibling = Public(info.firstChildSectionID), Public(info.siblingSectionID)
                if PositiveID(sibling) then stack[#stack + 1] = { sibling, depth } end
                if PositiveID(child) then
                    if depth < 10 then stack[#stack + 1] = { child, depth + 1 }
                    else omitted = true end
                end
            end
        end
    end
    if #stack > 0 or omitted then lines[#lines + 1] = "[Additional journal sections omitted.]" end
    if displayed == 0 then lines[#lines + 1] = "No journal mechanics available." end
    return table.concat(lines, "\n")
end

return InfinityEncounterDB
