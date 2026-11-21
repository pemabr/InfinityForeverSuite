local addonName = ...
local GTC = GuildTradeCenter
local L = GTC.T

local SCANNER_VERSION = 1
local bankOpen = false
local scanPending = false
local scanRunning = false
-- Aenderungen waehrend eines laufenden Scans gingen vorher verloren (Ereignis ignoriert).
local rescanQueued = false
local rescanBank = false
local RequestScan

local function GetContainerSlots(bagID)
    if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
        local ok, slots = pcall(C_Container.GetContainerNumSlots, bagID)
        if ok and type(slots) == "number" then
            return slots
        end
        return 0
    end

    if type(GetContainerNumSlots) == "function" then
        local ok, slots = pcall(GetContainerNumSlots, bagID)
        if ok and type(slots) == "number" then
            return slots
        end
    end

    return 0
end

local function GetContainerLink(bagID, slotID)
    if C_Container and type(C_Container.GetContainerItemLink) == "function" then
        local ok, link = pcall(C_Container.GetContainerItemLink, bagID, slotID)
        if ok then
            return link
        end
        return nil
    end

    if type(GetContainerItemLink) == "function" then
        local ok, link = pcall(GetContainerItemLink, bagID, slotID)
        if ok then
            return link
        end
    end

    return nil
end

local function BuildBagList(includeBank)
    local bags = { 0, 1, 2, 3, 4 }

    if includeBank then
        -- Persoenliche Bank und die Banktaschen.
        -- Nicht verfuegbare Container liefern normalerweise keine Slots.
        table.insert(bags, -1)

        for bagID = 5, 11 do
            table.insert(bags, bagID)
        end
    end

    return bags
end

function GTC:ScanInventory(includeBank)
    local db = self.db

    if type(db) ~= "table" or type(db.items) ~= "table" then
        return false, L("Der aktive Datenbereich ist noch nicht initialisiert.")
    end

    local newItems = 0
    local visitedSlots = 0
    local now = time()

    for _, bagID in ipairs(BuildBagList(includeBank == true)) do
        local slotCount = GetContainerSlots(bagID)

        for slotID = 1, slotCount do
            visitedSlots = visitedSlots + 1

            local itemLink = GetContainerLink(bagID, slotID)
            if type(itemLink) == "string" then
                local itemID = itemLink:match("item:(%d+)")

                if itemID then
                    local existing = db.items[tostring(itemID)]

                    if not existing then
                        local remembered = self:RememberItem(itemLink)

                        if remembered then
                            newItems = newItems + 1

                            -- Itemdaten koennen noch nicht im Client-Cache liegen.
                            -- RememberItem speichert schon den gefundenen Item-Link.
                            self:UpdateItemMetadata(tonumber(itemID))
                        end
                    elseif not existing.name or not existing.itemLink then
                        -- Fehlende Grunddaten und Bindungsmetadaten ergaenzen.
                        self:RememberItem(itemLink)
                        self:UpdateItemMetadata(tonumber(itemID))
                    elseif type(existing.bindType) ~= "number" then
                        -- Auch vollstaendig benannte/iconisierte Alt-Eintraege pruefen.
                        self:UpdateItemMetadata(tonumber(itemID))
                    end
                end
            end
        end
    end

    db.scan = db.scan or {}
    db.scan.scannerVersion = SCANNER_VERSION
    db.scan.inventoryLastScan = now

    if includeBank then
        db.scan.bankLastScan = now
    end

    db.scan.lastVisitedSlots = visitedSlots

    return true, newItems, visitedSlots
end

function GTC:StartInventoryScan(onProgress, onComplete, includeBankOverride)
    if scanRunning then
        return false, L("Ein Scan läuft bereits.")
    end

    if type(self.db) ~= "table" or type(self.db.items) ~= "table" then
        return false, L("Die lokale Datenbank ist noch nicht initialisiert.")
    end

    if not C_Timer or type(C_Timer.After) ~= "function" then
        return false, L("Die Timer-API ist nicht verfügbar.")
    end

    local includeBank = (includeBankOverride == true) or bankOpen
    local slots = {}

    for _, bagID in ipairs(BuildBagList(includeBank)) do
        local slotCount = GetContainerSlots(bagID)
        for slotID = 1, slotCount do
            table.insert(slots, {
                bagID = bagID,
                slotID = slotID,
            })
        end
    end

    local total = #slots
    local processed = 0
    local added = 0
    local cursor = 0
    local batchSize = 12

    scanRunning = true

    local function Finish(success, message)
        scanRunning = false

        if success and type(self.db) == "table" then
            self.db.scan = self.db.scan or {}
            self.db.scan.scannerVersion = 1
            self.db.scan.inventoryLastScan = time()
            if includeBank then
                self.db.scan.bankLastScan = time()
            end
            self.db.scan.lastVisitedSlots = processed
        end

        if type(onComplete) == "function" then
            pcall(onComplete, success, added, processed, message, includeBank)
        end

        if rescanQueued and RequestScan then
            local bank = rescanBank
            rescanQueued, rescanBank = false, false
            C_Timer.After(0.5, function()
                RequestScan(bank, L("Inventar geändert"))
            end)
        end
    end

    local function ScanBatch()
        if type(self.db) ~= "table" or type(self.db.items) ~= "table" then
            Finish(false, L("Die lokale Datenbank ist nicht mehr verfügbar."))
            return
        end

        local currentBatch = 0

        while cursor < total and currentBatch < batchSize do
            cursor = cursor + 1
            currentBatch = currentBatch + 1

            local slot = slots[cursor]
            local link = GetContainerLink(slot.bagID, slot.slotID)

            if type(link) == "string" then
                local itemID = link:match("item:(%d+)")
                if itemID then
                    local key = tostring(itemID)
                    local existing = self.db.items[key]

                    if not existing then
                        local remembered = self:RememberItem(link)
                        if remembered then
                            added = added + 1
                            self:UpdateItemMetadata(tonumber(itemID))
                        end
                    elseif not existing.name or not existing.itemLink then
                        self:RememberItem(link)
                        self:UpdateItemMetadata(tonumber(itemID))
                    elseif type(existing.bindType) ~= "number" then
                        self:UpdateItemMetadata(tonumber(itemID))
                    end
                end
            end

            processed = processed + 1
        end

        if type(onProgress) == "function" then
            pcall(onProgress, processed, total, added, includeBank)
        end

        if cursor >= total then
            Finish(true, nil)
        else
            C_Timer.After(0.05, ScanBatch)
        end
    end

    C_Timer.After(0, ScanBatch)
    return true
end

local function SetScanStatus(message)
    if type(GTC.SetWindowStatus) == "function" then
        GTC:SetWindowStatus(message)
    elseif GTC then
        GTC.windowStatusMessage = tostring(message or "")
    end
end

RequestScan = function(includeBank, triggerReason)
    if scanRunning then
        rescanQueued = true
        rescanBank = rescanBank or includeBank == true
        return
    end
    if scanPending then
        return
    end

    scanPending = true
    local reason = triggerReason or
        (includeBank == true and L("Bank geöffnet") or L("Inventar geändert"))
    SetScanStatus(reason .. L(" - Scan startet automatisch..."))
    C_Timer.After(1.5, function()
        scanPending = false

        if type(GTC.StartInventoryScan) ~= "function" then
            return
        end

        local started, reason = GTC:StartInventoryScan(
            function(processed, total, added, scannedBank)
                local percent = total > 0
                    and math.floor(processed / total * 100) or 100

                if type(GTC.SetWindowStatus) == "function" then
                    GTC:SetWindowStatus(
                        (scannedBank and L("Taschen + Bank: ") or L("Taschen: ")) ..
                        percent .. "%"
                    )
                end
            end,
            function(ok, added, visited, message, scannedBank)
                local status
                if ok then
                    status = L("Scan fertig: ") .. added .. L(" neue Items")
                else
                    status = L("Scan fehlgeschlagen: ") .. tostring(message)
                end

                if type(GTC.SetWindowStatus) == "function" then
                    GTC:SetWindowStatus(status)
                else
                    GTC:Print(status)
                end
            end,
            includeBank == true
        )

        if not started and type(GTC.SetWindowStatus) == "function" then
            GTC:SetWindowStatus(L("Scan nicht gestartet: ") .. tostring(reason))
        end
    end)
end
local scannerFrame = CreateFrame("Frame")
scannerFrame:RegisterEvent("PLAYER_LOGIN")
-- BAG_UPDATE_DELAYED feuert einmal pro Aenderungsserie statt einmal pro Slot.
if not pcall(scannerFrame.RegisterEvent, scannerFrame, "BAG_UPDATE_DELAYED") then
    scannerFrame:RegisterEvent("BAG_UPDATE")
end
scannerFrame:RegisterEvent("BANKFRAME_OPENED")
scannerFrame:RegisterEvent("BANKFRAME_CLOSED")
scannerFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
scannerFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
scannerFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")

scannerFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "PLAYER_LOGIN" then
        RequestScan(false, L("Erster Inventarscan"))

    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
        RequestScan(true, L("Bank geöffnet"))

    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false

    elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
        RequestScan(bankOpen, L("Inventar geändert"))

    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        if bankOpen then
            RequestScan(true, L("Bank geändert"))
        end

    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        -- Bindung pruefen, auch wenn Name und Icon bereits gespeichert sind.
        local itemID = tonumber(arg1)
        local succeeded = arg2

        if succeeded and itemID then
            local entry = GTC.db and GTC.db.items
                and GTC.db.items[tostring(itemID)] or nil

            if entry and (type(entry.bindType) ~= "number" or not entry.icon) then
                GTC:UpdateItemMetadata(itemID)
            end


        end
    end
end)

SLASH_GTC_SCAN1 = "/gtcscan"
SlashCmdList["GTC_SCAN"] = function()
    RequestScan(bankOpen, L("Manueller Scan"))
end