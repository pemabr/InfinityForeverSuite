-- GTC_WATCHLIST
-- Wunschliste: Items vormerken und im Chat benachrichtigt werden, sobald ein
-- Gildenmitglied ein passendes Angebot oder Gesuch neu einstellt.
--
-- Rein lokal (kontoweit in GuildTradeCenterDB.watchlist). Es wird nichts ueber das
-- Netz gesendet, das Sync-Protokoll bleibt unveraendert.

local GTC = _G.GuildTradeCenter
if type(GTC) ~= "table" then
    return
end
local L = GTC.T

local MAX_WATCH = 100         -- maximale Eintraege auf der Wunschliste
local MAX_MESSAGES = 5        -- Chatmeldungen pro Zeitfenster
local WINDOW_SECONDS = 10

local notified = {}           -- [Inserat-ID] = true (pro Sitzung, keine Doppelmeldung)
local windowStart, windowCount, suppressed = 0, 0, 0

local function Root()
    local root = _G.GuildTradeCenterDB
    if type(root) == "table" then
        return root
    end
    return nil
end

local function Store(create)
    local root = Root()
    if not root then return nil end
    if type(root.watchlist) ~= "table" then
        if not create then return nil end
        root.watchlist = {}
    end
    return root.watchlist
end

local function ParseItemID(text)
    if type(text) ~= "string" then return nil end
    local id = text:match("|[Hh]item:(%d+)")
        or text:match("^%s*item:(%d+)")
        or text:match("^%s*(%d+)%s*$")
    id = tonumber(id)
    if id and id >= 1 and id <= 1000000000 then
        return id
    end
    return nil
end

local function ItemLabel(itemID, storedName)
    local name, link
    if type(GetItemInfo) == "function" then
        name, link = GetItemInfo(itemID)
    end
    if type(link) == "string" and link ~= "" then
        return link
    end
    return "[" .. tostring(name or storedName or ("Item #" .. tostring(itemID))) .. "]"
end

function GTC:WatchHas(itemID)
    local store = Store(false)
    return store ~= nil and type(store[tostring(tonumber(itemID) or 0)]) == "table"
end

function GTC:WatchAdd(itemID, name)
    itemID = tonumber(itemID)
    if not itemID or itemID < 1 then
        return false, L("Ungültiges Item.")
    end
    local store = Store(true)
    if not store then
        return false, L("Wunschliste nicht verfügbar.")
    end
    local key = tostring(itemID)
    if type(store[key]) == "table" then
        return false, L("Dieses Item ist bereits auf der Wunschliste.")
    end
    local count = 0
    for _ in pairs(store) do count = count + 1 end
    if count >= MAX_WATCH then
        return false, L("Die Wunschliste ist voll (100 Einträge).")
    end
    store[key] = {
        itemID = itemID,
        name = (type(name) == "string" and name ~= "" and #name <= 256) and name or nil,
        addedAt = self:Now(),
    }
    return true
end

function GTC:WatchRemove(itemID)
    local store = Store(false)
    local key = tostring(tonumber(itemID) or 0)
    if store and type(store[key]) == "table" then
        store[key] = nil
        return true
    end
    return false
end

-- Schaltet ein Item um. Rueckgabe: ok, beobachtet-jetzt, Fehlertext
function GTC:WatchToggle(itemID, name)
    if self:WatchHas(itemID) then
        self:WatchRemove(itemID)
        return true, false
    end
    local ok, message = self:WatchAdd(itemID, name)
    if not ok then
        return false, false, message
    end
    return true, true
end

function GTC:WatchSoundEnabled()
    local root = Root()
    return not (root and root.watchSound == false)
end

local function PlayNotifySound()
    if not GTC:WatchSoundEnabled() or type(PlaySound) ~= "function" then return end
    local soundID = (type(SOUNDKIT) == "table" and SOUNDKIT.TELL_MESSAGE) or 3081
    pcall(PlaySound, soundID)
end

-- Wird von Comm.lua fuer jedes NEU uebernommene Inserat aufgerufen.
function GTC:NotifyWatchlist(listing)
    if type(listing) ~= "table" or listing.completed == true then return end
    -- Berufs-Inserate tragen nur ein Platzhalter-Item: keine Wunschlisten-Meldung.
    if listing.profession ~= nil then return end
    local itemID = tonumber(listing.itemID)
    if not itemID then return end

    local store = Store(false)
    local watch = store and store[tostring(itemID)]
    if type(watch) ~= "table" then return end

    local listingID = tostring(listing.id)
    if notified[listingID] then return end
    notified[listingID] = true

    local me = self:GetFullPlayerName()
    if me and self:SameCharacter(listing.character, me) then return end

    -- Beim Login koennen viele Treffer auf einmal eintreffen: begrenzen und zusammenfassen.
    local now = type(GetTime) == "function" and GetTime() or 0
    if now - windowStart > WINDOW_SECONDS then
        windowStart = now
        windowCount = 0
    end
    windowCount = windowCount + 1
    if windowCount > MAX_MESSAGES then
        suppressed = suppressed + 1
        if suppressed == 1 and C_Timer and C_Timer.After then
            C_Timer.After(WINDOW_SECONDS + 1, function()
                if suppressed > 0 then
                    GTC:Print(L("Wunschliste: ") .. tostring(suppressed) .. L(" weitere Treffer."))
                    suppressed = 0
                end
            end)
        end
        return
    end

    local verb = (listing.kind == "wanted") and L(" sucht ") or L(" bietet ")
    self:Print(L("Wunschliste: ") .. tostring(listing.character or "?") .. verb
        .. ItemLabel(itemID, watch.name or listing.item) .. " x" .. tostring(listing.quantity or 1))
    PlayNotifySound()
end

local function PrintHelp()
    GTC:Print(L("Befehle: /gtc watch add <Item-Link oder ID> | remove <Item-Link oder ID> | list | clear | sound on/off"))
end

-- /gtc watch ...   (raw = Originaltext mit Gross-/Kleinschreibung und Item-Links)
function GTC:HandleWatchCommand(raw)
    local rest = tostring(raw or ""):match("^%s*%S+%s*(.-)%s*$") or ""
    local sub, arg = rest:match("^(%S+)%s*(.-)$")
    sub = sub and sub:lower() or "list"
    arg = arg or ""

    if sub == "add" or sub == "+" or sub == "hinzufuegen" then
        local itemID = ParseItemID(arg)
        if not itemID then
            self:Print(L("Bitte einen Item-Link (Shift-Klick) oder eine Item-ID angeben."))
            return
        end
        local ok, message = self:WatchAdd(itemID, arg:match("|h%[(.-)%]|h"))
        if ok then
            self:Print(L("Zur Wunschliste hinzugefügt: ") .. ItemLabel(itemID))
        else
            self:Print(message)
        end
    elseif sub == "remove" or sub == "del" or sub == "-" or sub == "entfernen" then
        local itemID = ParseItemID(arg)
        if not itemID then
            self:Print(L("Bitte einen Item-Link (Shift-Klick) oder eine Item-ID angeben."))
            return
        end
        if self:WatchRemove(itemID) then
            self:Print(L("Von der Wunschliste entfernt: ") .. ItemLabel(itemID))
        else
            self:Print(L("Dieses Item war nicht auf der Wunschliste."))
        end
    elseif sub == "clear" or sub == "leeren" then
        local root = Root()
        if root then root.watchlist = {} end
        self:Print(L("Wunschliste geleert."))
    elseif sub == "sound" then
        local root = Root()
        local value = arg:lower()
        if root and (value == "on" or value == "an") then
            root.watchSound = true
            self:Print(L("Wunschliste: Ton an."))
        elseif root and (value == "off" or value == "aus") then
            root.watchSound = false
            self:Print(L("Wunschliste: Ton aus."))
        else
            PrintHelp()
        end
    elseif sub == "list" or sub == "liste" then
        local store = Store(false)
        local entries = {}
        for _, entry in pairs(store or {}) do
            if type(entry) == "table" and tonumber(entry.itemID) then
                table.insert(entries, entry)
            end
        end
        if #entries == 0 then
            self:Print(L("Die Wunschliste ist leer."))
            PrintHelp()
            return
        end
        table.sort(entries, function(a, b) return (tonumber(a.addedAt) or 0) < (tonumber(b.addedAt) or 0) end)
        self:Print(L("Wunschliste: ") .. tostring(#entries) .. L(" Einträge:"))
        for _, entry in ipairs(entries) do
            print("  " .. ItemLabel(tonumber(entry.itemID), entry.name))
        end
    else
        PrintHelp()
    end
end
