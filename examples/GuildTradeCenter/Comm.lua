local GTC = GuildTradeCenter
local L = GTC.T

local PREFIX = "GTC_SYNC"
local PROTOCOL = 2
local CHUNK_SIZE = 190
local MAX_CHUNKS = 1600
local MAX_ENCODED_BYTES = 300000
local MAX_ITEMS = 10000
local MAX_PENDING_ITEMS = MAX_ITEMS * 2
local MAX_LISTINGS = 3000
local MAX_PENDING_LISTINGS = MAX_LISTINGS * 2
local MAX_TOMBSTONES = 5000

local function Now()
    return GTC:Now()
end

local outgoingQueue = {}
local queueRunning = false
local snapshotScheduled = false
local lastSnapshotTime = 0

-- Nachverfolgung, wann ein eingereihter Snapshot WIRKLICH vollstaendig gesendet wurde.
-- Erst dann darf lastBroadcastAt fortgeschrieben werden; sonst gilt ein Snapshot als
-- verteilt, obwohl er beim Ausloggen/Reload noch in der Warteschlange lag.
local sentTotal = 0           -- bisher aus der Warteschlange entfernte Pakete
local dropTotal = 0           -- davon wegen Sendefehlern verworfene
local queueCompletions = {}   -- { target = <sentTotal-Ziel>, drops = <dropTotal bei Start>, fn = f }
local sessionQueuedAt = nil   -- bis hierhin wurde in dieser Sitzung bereits eingereiht
local lastOwnAnnounceAt = 0
local lastManualSyncAt = 0
local ownAnnounceTicker = nil

-- Sendegrenze von Blizzard (Stand Doku): je Addon-Praefix 10 Nachrichten Burst, danach
-- 1 Nachricht pro Sekunde. Wir fuehren einen eigenen Token-Eimer, damit wir die Grenze
-- nicht reissen, und passen die Rate an, falls der Server sie aendert.
local BUCKET_BURST = 8        -- bewusst unter 10 (Sicherheitsabstand)
local bucketRate = 1.0        -- Nachrichten pro Sekunde (passt sich bei Drosselung an)
local bucketTokens = BUCKET_BURST
local bucketAt = nil
local unknownErrors = 0       -- aufeinanderfolgende unbekannte Sendefehler
local lockdownSince = nil     -- Beginn einer Sperre fuer Addon-Nachrichten
local sendStats = {
    sent = 0, throttled = 0, lockdown = 0, errors = 0, dropped = 0,
    lastResult = nil, rxAccepted = 0, rxRejected = 0, lastRxAt = nil,
    rxSnapshots = 0, lastSnapshotAt = nil,
}

-- HELLO-Verwaltung: Das HELLO beim Login darf nicht nur ein einziges Mal und nur bei
-- rechtzeitig bekannter Gilde gesendet werden (sonst startet der Sync u. U. nie).
local helloSentAt = nil         -- GetTime() des letzten HELLO
local helloAttempts = 0         -- gesendete HELLO seit dem Login
local catchupAtHello = 0        -- lastCatchup beim ersten HELLO (Fortschritt erkennen)
local syncStartPending = false
local supervisorTicker = nil
local pendingCursor = 0         -- Rotationszeiger fuer die Wiederholung wartender Item-Daten
local lastPendingRetryAt = 0

local function TrackCompletions()
    local index = 1
    while index <= #queueCompletions do
        local entry = queueCompletions[index]
        if sentTotal >= entry.target then
            table.remove(queueCompletions, index)
            pcall(entry.fn, dropTotal == entry.drops)
        else
            index = index + 1
        end
    end
end

local function TrackSent(dropped)
    sentTotal = sentTotal + 1
    if dropped then
        dropTotal = dropTotal + 1
    end
    if #queueCompletions > 0 then
        TrackCompletions()
    end
end

local function TrackClear()
    queueCompletions = {}
    sessionQueuedAt = nil
end

-- Wird nach dem Einfuegen von `count` Paketen aufgerufen. front = am Anfang eingefuegt
-- (Prioritaet): dann verschieben sich die Ziele aller bereits wartenden Snapshots.
local function TrackEnqueue(count, front, callback)
    local target
    if front then
        for _, entry in ipairs(queueCompletions) do
            entry.target = entry.target + count
        end
        target = sentTotal + count
    else
        target = sentTotal + #outgoingQueue
    end
    if callback then
        table.insert(queueCompletions, { target = target, drops = dropTotal, fn = callback })
    end
end
local transferCounter = 0
local incomingTransfers = {}
local prefixRegistered = false

-- Antwort auf fremde HELLO-Pakete: Frueher sendete JEDER online Spieler bei jedem
-- HELLO sofort seinen kompletten Snapshot (N Spieler = N volle Snapshots pro Login).
-- Jetzt antwortet nur, wer nach einer Zufallsverzoegerung noch keinen Snapshot
-- eines anderen Mitglieds gesehen hat.
local lastSnapshotSeenAt = -1000
local lastSnapshotSeenSince = 0
local helloReplyToken = 0
-- Der Item-Katalog wird nicht mehr automatisch synchronisiert (zu gross, siehe
-- GTC_Review.md). Stattdessen: Anfrage auf Knopfdruck ("Von Gilde laden"), Antwort als
-- kompakte ID-Liste. Inserate bringen ihre Item-ID und Bindung selbst mit.
local SYNC_ITEMS = false
local CATALOG_MAX_IDS = 20000
local catalogRequestUntil = 0
local catalogReplyToken = 0
local catalogLastDataAt = -1000
local catalogIncoming = {}
local catalogCounter = 0
local helloSender = nil
local rejectLogged = {}
local helloSinceBy = {}        -- [Absender] = Zeitpunkt, seit dem der Absender Daten braucht
local pendingFull = false      -- naechster Snapshot muss vollstaendig sein
local pendingSince = nil       -- fruehester Zeitpunkt, ab dem Daten gesendet werden muessen
local sendDelay = 0.12         -- adaptive Pause zwischen Paketen
local queueStartedAt = nil

local Encoding = C_EncodingUtil
local compressionMethod =
    (Enum and Enum.CompressionMethod and Enum.CompressionMethod.Deflate) or 0

local function After(delay, callback)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(delay, callback)
    end
end

local function SafeString(value, limit)
    if type(value) ~= "string" or #value > limit then
        return nil
    end
    if value:find("%z") then
        return nil
    end
    return value
end

local function SafeNumber(value, minimum, maximum)
    local number = tonumber(value)
    if not number or number ~= number or number < minimum or number > maximum then
        return nil
    end
    return number
end

-- v1.1.7: Berufs-Inserate. Zusaetzliche Felder `profession` (skillLineID) und
-- `professionLink` (nativer Berufs-Link). Aeltere Versionen ignorieren sie; das
-- Protokoll bleibt unveraendert.
local function CopyProfessionFields(target, remote)
    local prof = SafeNumber(remote.profession, 1, 100000)
    if prof and GTC.Prof and GTC.Prof:IsKnown(prof) then
        target.profession = prof
        local link = GTC.Prof:SanitizeNativeLink(remote.professionLink)
        target.professionLink = link or nil
    else
        target.profession = nil
        target.professionLink = nil
    end
    return target
end

local function CurrentDatabase()
    local db = GTC and GTC.db
    if type(db) ~= "table" or type(db.sync) ~= "table" then
        return nil
    end
    return db
end

local function IsGuildScope()
    local db = CurrentDatabase()

    return db ~= nil
        and db.scopeType == "guild"
        and type(db.scopeKey) == "string"
        and db.scopeKey ~= ""
        and type(IsInGuild) == "function"
        and IsInGuild()
end

local function CurrentPlayerName()
    if type(UnitName) == "function" then
        return UnitName("player")
    end
    return nil
end

local function NormalizePlayerName(name)
    if type(name) ~= "string" then
        return nil
    end

    if type(Ambiguate) == "function" then
        local ok, result = pcall(Ambiguate, name, "none")
        if ok and type(result) == "string" then
            return result
        end
    end

    return name:match("^([^-]+)") or name
end

-- Eigene Nachrichten: Das Spiel liefert GUILD-Addon-Nachrichten auch an den Absender
-- zurueck. Ohne Filter beantwortete man das eigene HELLO (voller Snapshot an alle) und
-- die eigene Katalog-Anfrage (die dann sofort als "beantwortet" galt).
local selfNames = nil

local function IsSelf(sender)
    if type(sender) ~= "string" or sender == "" then
        return false
    end
    if not selfNames then
        local names = {}
        local short = type(UnitName) == "function" and UnitName("player") or nil
        if type(short) == "string" and short ~= "" then
            names[short] = true
            local realm = type(GetNormalizedRealmName) == "function" and GetNormalizedRealmName() or nil
            if type(realm) == "string" and realm ~= "" then
                names[short .. "-" .. realm] = true
            end
        end
        local full = type(GTC.GetFullPlayerName) == "function" and GTC:GetFullPlayerName() or nil
        if type(full) == "string" and full ~= "" then
            names[full] = true
        end
        if next(names) == nil then
            return false
        end
        selfNames = names
    end
    if selfNames[sender] then
        return true
    end
    local normalized = NormalizePlayerName(sender)
    return normalized ~= nil and selfNames[normalized] == true
end

-- Gildenliste als Menge zwischenspeichern. Vorher wurde bei JEDEM Paket die
-- komplette Liste (bis 1000 Eintraege, mit pcall) durchlaufen - bei bis zu 1600
-- Paketen pro Snapshot sehr teuer.
local rosterSet = {}
local rosterBuiltAt = -1000
local rosterDirty = true

-- v1.1.5: Name ohne angehaengten Realm-Teil ("Vorname Nachname-Realm" -> "Vorname Nachname").
-- Gildenliste und Absender koennen bei WoW Forever unterschiedlich mit Realm-Zusatz kommen.
local function StripRealmSuffix(name)
    if type(name) ~= "string" then
        return nil
    end
    local base = name:match("^(.-)%-[^%-%s]+$")
    if base and base ~= "" then
        return base
    end
    return name
end

local function RebuildRosterSet()
    local set = {}
    local ok, memberCount = pcall(GetNumGuildMembers)
    if ok and type(memberCount) == "number" then
        for index = 1, math.min(memberCount, 1000) do
            local success, rosterName = pcall(GetGuildRosterInfo, index)
            if success and type(rosterName) == "string" then
                set[rosterName] = true
                local normalized = NormalizePlayerName(rosterName)
                if normalized then
                    set[normalized] = true
                end
                local base = StripRealmSuffix(rosterName)
                if base then
                    set[base] = true
                end
            end
        end
    end
    rosterSet = set
    rosterBuiltAt = (type(GetTime) == "function") and GetTime() or 0
    rosterDirty = false
end

local function IsCurrentGuildMember(sender)
    if not IsGuildScope() or type(sender) ~= "string" or sender == "" then
        return false
    end

    if type(GetNumGuildMembers) ~= "function"
        or type(GetGuildRosterInfo) ~= "function" then
        return false
    end

    local now = (type(GetTime) == "function") and GetTime() or 0
    local age = now - rosterBuiltAt
    if age > 120 or (rosterDirty and age > 5) or (next(rosterSet) == nil and age > 5) then
        RebuildRosterSet()
    end

    local senderNormalized = NormalizePlayerName(sender)
    -- Fail closed: Nicht in der geladenen Gildenliste = nicht akzeptieren.
    local senderBase = StripRealmSuffix(sender)
    return rosterSet[sender] == true
        or (senderNormalized ~= nil and rosterSet[senderNormalized] == true)
        or (senderBase ~= nil and rosterSet[senderBase] == true)
end
local function GetEncodingFunction(name)
    if type(Encoding) == "table" and type(Encoding[name]) == "function" then
        return Encoding[name]
    end
    return nil
end

local function EncodeBase64(value)
    local fn = GetEncodingFunction("EncodeBase64")
    if not fn then
        return nil
    end

    local ok, result = pcall(fn, value)
    if ok and type(result) == "string" then
        return result
    end
    return nil
end

local function DecodeSnapshot(encoded)
    local decode = GetEncodingFunction("DecodeBase64")
    local decompress = GetEncodingFunction("DecompressString")
    local deserialize = GetEncodingFunction("DeserializeCBOR")

    if not decode or not decompress or not deserialize then
        return nil, L("C_EncodingUtil ist nicht vollständig verfügbar.")
    end

    local ok, raw = pcall(decode, encoded)
    if not ok or type(raw) ~= "string" then
        return nil, L("Base64-Dekodierung fehlgeschlagen.")
    end

    local success, decompressed = pcall(decompress, raw, compressionMethod)
    if not success or type(decompressed) ~= "string" then
        return nil, L("Dekomprimierung fehlgeschlagen.")
    end

    local valid, snapshot = pcall(deserialize, decompressed)
    if not valid or type(snapshot) ~= "table" then
        return nil, L("Snapshot konnte nicht gelesen werden.")
    end

    return snapshot
end

-- WICHTIG: Zuerst die normale SendAddonMessage verwenden. Die "Logged"-Variante wird vom
-- Spiel auf ca. 1 Nachricht pro Sekunde gedrosselt (Protokoll: 378 Pakete = ueber 6 Minuten).
-- Empfaenger verwerfen unvollstaendige Uebertragungen nach einiger Zeit, der Sync kam so
-- nie an. Die normale Variante hat dieselbe Grenze je Praefix (10 Burst, dann 1/s), wird
-- aber nicht zusaetzlich gedrosselt. Die Pumpe haelt diese Grenze selbst ein.
local function SendFunction()
    if C_ChatInfo and type(C_ChatInfo.SendAddonMessage) == "function" then
        return C_ChatInfo.SendAddonMessage
    end
    if C_ChatInfo and type(C_ChatInfo.SendAddonMessageLogged) == "function" then
        return C_ChatInfo.SendAddonMessageLogged
    end
    if type(SendAddonMessage) == "function" then
        return SendAddonMessage
    end
    return nil
end

local function QueueMessage(message)
    if type(message) ~= "string" or #message > 255 then
        GTC:Print(L("Sync-Paket überschreitet das WoW-Nachrichtenlimit."))
        return false
    end

    if #outgoingQueue >= 10000 then
        GTC:Print(L("Sync-Warteschlange voll; bitte später erneut synchronisieren."))
        return false
    end

    table.insert(outgoingQueue, message)
    return true
end

-- Entfernt die wartenden Pakete einer Uebertragung, die nicht mehr vollstaendig gesendet
-- werden kann (halbe Snapshots sind fuer den Empfaenger wertlos).
local function DropTransferOf(message)
    local transferID = type(message) == "string" and message:match("^P|2|([%w%-]+)|") or nil
    if not transferID then
        table.remove(outgoingQueue, 1)
        TrackSent(true)
        sendStats.dropped = sendStats.dropped + 1
        return 1
    end
    local prefix = "P|2|" .. transferID .. "|"
    local removed = 0
    local index = 1
    while index <= #outgoingQueue do
        local queued = outgoingQueue[index]
        if type(queued) == "string" and queued:sub(1, #prefix) == prefix then
            table.remove(outgoingQueue, index)
            TrackSent(true)
            removed = removed + 1
        else
            index = index + 1
        end
    end
    sendStats.dropped = sendStats.dropped + removed
    return removed
end

local function RefillBucket()
    local now = GetTime()
    if bucketAt then
        bucketTokens = math.min(BUCKET_BURST, bucketTokens + (now - bucketAt) * bucketRate)
    end
    bucketAt = now
end

local function SetSendStatus(text)
    if type(GTC.SetWindowStatus) == "function" then
        GTC:SetWindowStatus(text)
    end
end

local function PumpQueue()
    if queueRunning then
        return
    end
    queueRunning = true
    queueStartedAt = queueStartedAt or GetTime()

    local function Step()
        if #outgoingQueue == 0 then
            queueRunning = false
            if queueStartedAt then
                GTC:Log("SYNC>", "Warteschlange leer nach " .. string.format("%.1f", GetTime() - queueStartedAt) .. " s, Rate " .. string.format("%.2f", bucketRate) .. "/s")
                queueStartedAt = nil
            end
            return
        end

        if not IsGuildScope() then
            outgoingQueue = {}
            TrackClear()
            queueRunning = false
            return
        end

        local send = SendFunction()
        if not send then
            outgoingQueue = {}
            TrackClear()
            queueRunning = false
            GTC:Print(L("Keine Addon-Kommunikations-API verfügbar."))
            return
        end

        -- Erst senden, wenn nach der Blizzard-Grenze ein Platz frei ist. Das vermeidet
        -- Drosselung (und damit Wartezeit) schon im Voraus.
        RefillBucket()
        if bucketTokens < 1 then
            After(math.max(0.05, (1 - bucketTokens) / bucketRate + 0.02), Step)
            return
        end

        local message = outgoingQueue[1]
        local ok, firstResult, secondResult = pcall(send, PREFIX, message, "GUILD")

        -- Neuere Clients geben einen Enum-Wert zurueck; aeltere Wrapper
        -- koennen den Status an der zweiten Rueckgabeposition liefern.
        local result
        if ok then
            result = secondResult
            if result == nil then
                result = firstResult
            end
        end
        sendStats.lastResult = ok and tostring(result == nil and "ok" or result) or "Fehler"

        local enumResult = Enum and Enum.SendAddonMessageResult
        local throttleResult = enumResult and enumResult.AddonMessageThrottle or 3
        local channelThrottleResult = enumResult and enumResult.ChannelThrottle or 8
        local notInGuildResult = enumResult and enumResult.NotInGuild or 10
        local lockdownResult = enumResult and enumResult.AddOnMessageLockdown or 11

        -- Erfolg: Paket entfernen. (Erfolg heisst nur "vom Spiel angenommen".)
        if ok and (result == nil or result == true or result == 0) then
            table.remove(outgoingQueue, 1)
            TrackSent(false)
            sendStats.sent = sendStats.sent + 1
            unknownErrors = 0
            bucketTokens = bucketTokens - 1
            bucketRate = math.min(1.0, bucketRate + 0.01)
            if lockdownSince then
                lockdownSince = nil
                SetSendStatus(L("Sync läuft wieder"))
            end
            After(0.05, Step)
            return
        end

        -- Gedrosselt: Paket bleibt an Position 1, Eimer leeren und Rate vorsichtig senken.
        if ok and (result == throttleResult or result == channelThrottleResult) then
            sendStats.throttled = sendStats.throttled + 1
            bucketTokens = 0
            bucketAt = GetTime()
            bucketRate = math.max(0.4, bucketRate * 0.85)
            GTC:Log("SYNC>", "gedrosselt (Ergebnis " .. tostring(result) .. "), Queue=" .. #outgoingQueue .. ", Rate jetzt " .. string.format("%.2f", bucketRate) .. "/s")
            SetSendStatus(L("Sync wartet auf Gildenkanal (") .. tostring(#outgoingQueue) .. L(" Pakete)"))
            After(1 / bucketRate + 0.1, Step)
            return
        end

        -- Addon-Nachrichten sind zeitweise gesperrt (z. B. in Begegnungen): NICHT verwerfen,
        -- sondern warten. Sonst entstehen unvollstaendige Uebertragungen.
        if ok and result == lockdownResult then
            sendStats.lockdown = sendStats.lockdown + 1
            if not lockdownSince then
                lockdownSince = GetTime()
                GTC:Log("SYNC>", "Addon-Nachrichten gesperrt, warte (Queue=" .. #outgoingQueue .. ")")
            end
            SetSendStatus(L("Sync pausiert: Addon-Nachrichten gesperrt (") .. tostring(#outgoingQueue) .. L(" Pakete)"))
            After(5, Step)
            return
        end

        -- Nicht (mehr) in der Gilde: nichts zu senden.
        if ok and result == notInGuildResult then
            GTC:Log("ERR", "Sendeergebnis NotInGuild, Warteschlange verworfen")
            outgoingQueue = {}
            TrackClear()
            queueRunning = false
            return
        end

        -- Unbekannter Fehler: erst einige Male wiederholen (kann voruebergehend sein), dann
        -- die ganze betroffene Uebertragung verwerfen statt einzelne Pakete zu verlieren.
        unknownErrors = unknownErrors + 1
        GTC:Log("ERR", "Sendefehler Ergebnis=" .. tostring(ok and result or firstResult) .. " (Versuch " .. unknownErrors .. ")")
        if unknownErrors <= 3 then
            After(2, Step)
            return
        end

        unknownErrors = 0
        sendStats.errors = sendStats.errors + 1
        local removed = DropTransferOf(message)
        local errorText = L("Sync-Sendefehler: ") .. tostring(ok and result or firstResult)
            .. " (" .. tostring(removed) .. L(" Pakete verworfen)")
        SetSendStatus(errorText)
        GTC:Print(errorText)
        After(0.12, Step)
    end

    After(0, Step)
end

local function BuildSnapshot(since, ownOnly)
    local db = CurrentDatabase()
    if not db or db.scopeType ~= "guild" then
        return nil, L("Kein Gilden-Datenbereich aktiv.")
    end

    -- ownOnly: kleiner Snapshot nur mit den eigenen Inseraten (und eigenen Loeschmarkern).
    -- since = 4000000000 kennzeichnet einen Teil-Datensatz: Empfaenger ruecken dadurch
    -- ihren Stand (lastCatchup) nicht vor. Das Format bleibt unveraendert.
    local ownName = ownOnly and GTC:GetFullPlayerName() or nil
    if ownOnly and not ownName then
        return nil, L("Eigener Charaktername nicht verfügbar.")
    end

    local snapshot = {
        protocol = PROTOCOL,
        schemaVersion = 2,
        scopeKey = db.scopeKey,
        scopeType = db.scopeType,
        guildName = db.guildName,
        realm = db.realm,
        faction = db.faction,
        revision = tonumber(db.sync.revision) or 0,
        since = ownOnly and 4000000000 or (since or 0),
        -- GTC_UPDATE5_AH_SCAN_SYNC_OUT
        ahScan = (type(db.scan) == "table"
            and type(db.scan.ahLatestScan) == "table"
            and tonumber(db.scan.ahLatestScan.at)
            and tonumber(db.scan.ahLatestScan.at) > 0
            and type(db.scan.ahLatestScan.character) == "string"
            and db.scan.ahLatestScan.source == "ah") and {
            at = math.floor(tonumber(db.scan.ahLatestScan.at) or 0),
            character = string.sub(db.scan.ahLatestScan.character, 1, 100),
            source = "ah",
        } or nil,
        createdAt = time(),
        createdBy = CurrentPlayerName() or "UnknownPlayer",
        items = {},
        listings = {},
        tombstones = {},
    }

    -- Beim Delta-Snapshot muessen die Katalogeintraege der enthaltenen Inserate immer
    -- mitgesendet werden, auch wenn sie sich selbst nicht geaendert haben (sonst kann der
    -- Empfaenger die Bindung des Gegenstands nicht einschaetzen).
    -- Nur benoetigt, solange der Item-Katalog mitsynchronisiert wird (SYNC_ITEMS).
    local now = Now()
    local neededItems = {}
    if SYNC_ITEMS and since then
        for _, listingSource in ipairs(db.listings or {}) do
            if type(listingSource) == "table"
                and listingSource.isTest == false
                and (tonumber(listingSource.expiresAt) or 0) > now
                and (tonumber(listingSource.updatedAt or listingSource.createdAt) or 0) >= since then
                local neededID = tonumber(listingSource.itemID)
                if neededID then
                    neededItems[tostring(neededID)] = true
                end
            end
        end
    end

    if SYNC_ITEMS and ownOnly then
        for _, listingSource in ipairs(db.listings or {}) do
            if type(listingSource) == "table"
                and listingSource.isTest == false
                and (tonumber(listingSource.expiresAt) or 0) > now
                and GTC:SameCharacter(listingSource.character, ownName) then
                local neededID = tonumber(listingSource.itemID)
                if neededID then
                    neededItems[tostring(neededID)] = true
                end
            end
        end
    end

    local itemCount = 0
    for key, source in pairs(SYNC_ITEMS and db.items or {}) do
        if type(source) == "table" then
            itemCount = itemCount + 1
            if itemCount > MAX_ITEMS then
                return nil, L("Der Item-Katalog überschreitet das Snapshot-Limit.")
            end

            local itemID = SafeNumber(source.itemID or key, 1, 1000000000)
            local changedSince
            if ownOnly then
                changedSince = itemID ~= nil and neededItems[tostring(itemID)] == true
            else
                changedSince = (not since)
                    or (itemID ~= nil and neededItems[tostring(itemID)] == true)
                    or ((SafeNumber(source.updatedAt, 0, 4000000000) or 0) >= since)
            end
            local bindType = (itemID and changedSince) and GTC:GetItemBindingType(itemID) or nil
            if itemID and changedSince and type(bindType) == "number" and bindType ~= 1 then
                local item = {
                    itemID = itemID,
                    bindType = bindType,
                    firstSeen = SafeNumber(source.firstSeen, 0, 4000000000),
                    lastSeen = SafeNumber(source.lastSeen, 0, 4000000000),
                    -- Nur echte Aenderungen (updatedAt) weitergeben, nicht lastSeen: Lokal
                    -- ergaenzte Metadaten sollen keine Echo-Updates ausloesen.
                    updatedAt = SafeNumber(source.updatedAt, 0, 4000000000) or 0,
                    revision = SafeNumber(source.revision, 0, 1000000000) or 0,
                    syncRevision = SafeNumber(source.syncRevision, 0, 1000000000) or 0,
                }

                -- Schlank: Link, Typ und Icon liefert jeder Client lokal aus der Item-ID
                -- (UpdateItemMetadata), sie muessen nicht uebertragen werden.
                item.name = SafeString(source.name, 256)

                if type(source.quality) == "number" then
                    item.quality = source.quality
                end

                table.insert(snapshot.items, item)
            end
        end
    end

    -- Bei Ueberschreitung des Limits werden die aeltesten Inserate weggelassen, statt den
    -- ganzen Snapshot abzubrechen (sonst waere der Sync fuer alle blockiert).
    local listingSources = db.listings or {}
    if #listingSources > MAX_LISTINGS then
        local sorted = {}
        for _, entry in ipairs(listingSources) do
            table.insert(sorted, entry)
        end
        table.sort(sorted, function(a, b)
            return (tonumber(type(a) == "table" and a.updatedAt) or 0)
                > (tonumber(type(b) == "table" and b.updatedAt) or 0)
        end)
        listingSources = sorted
    end

    local listingCount = 0
    for _, source in ipairs(listingSources) do
        if type(source) == "table"
            and source.isTest == false
            and (tonumber(source.expiresAt) or 0) > now
            and ((not since) or ((tonumber(source.updatedAt or source.createdAt) or 0) >= since))
            and ((not ownOnly) or GTC:SameCharacter(source.character, ownName)) then

            listingCount = listingCount + 1
            if listingCount > MAX_LISTINGS then
                break
            end

            local id = SafeString(source.id, 180)
            local itemID = SafeNumber(source.itemID, 1, 1000000000)
            local quantity = SafeNumber(source.quantity, 1, 1000000000)
            local character = SafeString(source.character, 100)
            local kind = source.kind
            local bindType = itemID and GTC:GetItemBindingType(itemID) or nil

            if id and itemID and type(bindType) == "number" and bindType ~= 1
                and quantity and character
                and (kind == "offer" or kind == "wanted") then

                local listing = {
                    id = id,
                    itemID = itemID,
                    bindType = bindType,
                    quantity = quantity,
                    character = character,
                    kind = kind,
                    isTest = false,
                    createdAt = SafeNumber(source.createdAt, 0, 4000000000) or 0,
                    expiresAt = SafeNumber(source.expiresAt, 0, 4000000000) or 0,
                    updatedAt = SafeNumber(source.updatedAt or source.createdAt, 0, 4000000000) or 0,
                    revision = SafeNumber(source.revision, 0, 1000000000) or 0,
                    syncRevision = SafeNumber(source.syncRevision, 0, 1000000000) or 0,
                    scopeKey = db.scopeKey,
                }

                listing.item = SafeString(source.item, 256)
                listing.tradeType = SafeString(source.tradeType, 128)
                listing.description = SafeString(source.description or "", 2000)
                listing.durationHours = SafeNumber(source.durationHours, 1, 72)
                listing.completed = source.completed == true
                listing.completedAt = SafeNumber(source.completedAt, 0, 4000000000)
                listing.completedBy = SafeString(source.completedBy, 100)
                CopyProfessionFields(listing, source)

                table.insert(snapshot.listings, listing)
            end
        end
    end

    local tombstoneSources = {}
    for tombID, tombSource in pairs(db.sync.tombstones or {}) do
        if type(tombSource) == "table" and (
            (ownOnly and tombSource.deletedBy ~= "expiry"
                and GTC:SameCharacter(tombSource.deletedBy, ownName)
                and (tonumber(tombSource.deletedAt) or 0) >= now - 72 * 60 * 60)
            or ((not ownOnly) and ((not since) or ((tonumber(tombSource.deletedAt) or 0) >= since)))
        ) then
            table.insert(tombstoneSources, { id = tombID, source = tombSource })
        end
    end
    if #tombstoneSources > MAX_TOMBSTONES then
        table.sort(tombstoneSources, function(a, b)
            return (tonumber(a.source.deletedAt) or 0) > (tonumber(b.source.deletedAt) or 0)
        end)
    end

    local tombstoneCount = 0
    for _, wrapper in ipairs(tombstoneSources) do
        local id, source = wrapper.id, wrapper.source
        if type(source) == "table" then
            tombstoneCount = tombstoneCount + 1
            if tombstoneCount > MAX_TOMBSTONES then
                break
            end

            local safeID = SafeString(source.id or id, 180)
            local deletedAt = SafeNumber(source.deletedAt, 0, 4000000000)
            if safeID and deletedAt then
                table.insert(snapshot.tombstones, {
                    id = safeID,
                    deletedAt = deletedAt,
                    deletedBy = SafeString(source.deletedBy, 100) or "",
                    revision = SafeNumber(source.revision, 0, 1000000000) or 0,
                    scopeKey = db.scopeKey,
                })
            end
        end
    end

    return snapshot
end

local function SendSnapshot(since, options)
    local ownOnly = type(options) == "table" and options.ownOnly == true
    local quiet = type(options) == "table" and options.quiet == true
    local db = CurrentDatabase()
    if not IsGuildScope() or not db then
        return false
    end

    local serialize = GetEncodingFunction("SerializeCBOR")
    local compress = GetEncodingFunction("CompressString")
    local encode = GetEncodingFunction("EncodeBase64")

    if not serialize or not compress or not encode then
        GTC:Print(L("Sync benötigt die C_EncodingUtil-API dieses WoW-Clients."))
        return false
    end

    local snapshot, snapshotError = BuildSnapshot(since, ownOnly)
    if not snapshot then
        GTC:Print(L("Sync abgebrochen: ") .. tostring(snapshotError))
        return false
    end
    if ownOnly and #snapshot.listings == 0 and #snapshot.tombstones == 0 then
        return false
    end

    local ok, raw = pcall(serialize, snapshot)
    if not ok or type(raw) ~= "string" then
        GTC:Print(L("Snapshot konnte nicht serialisiert werden."))
        return false
    end

    local success, compressed = pcall(compress, raw, compressionMethod)
    if not success or type(compressed) ~= "string" then
        GTC:Print(L("Snapshot konnte nicht komprimiert werden."))
        return false
    end

    local encodedOK, encoded = pcall(encode, compressed)
    if not encodedOK or type(encoded) ~= "string" then
        GTC:Print(L("Snapshot konnte nicht Base64-kodiert werden."))
        return false
    end

    if #encoded > MAX_ENCODED_BYTES then
        GTC:Print(L("Sync-Snapshot ist zu groß; bitte Item-Katalog begrenzen."))
        return false
    end

    transferCounter = transferCounter + 1
    local transferID = tostring(time()) .. "-" .. tostring(transferCounter)
    local total = math.ceil(#encoded / CHUNK_SIZE)

    if total < 1 or total > MAX_CHUNKS then
        GTC:Print(L("Sync-Snapshot hat zu viele Pakete."))
        return false
    end

    local packets = {}
    for part = 1, total do
        local first = ((part - 1) * CHUNK_SIZE) + 1
        local piece = encoded:sub(first, first + CHUNK_SIZE - 1)
        local packet = "P|" .. PROTOCOL .. "|" .. transferID
            .. "|" .. part .. "|" .. total .. "|" .. piece

        if #packet > 255 then
            GTC:Print(L("Sync-Paket überschreitet 255 Zeichen."))
            return false
        end

        table.insert(packets, packet)
    end

    local startedAt = Now()
    GTC:Log("SYNC>", (ownOnly and "EIGENE" or (since and ("Delta seit " .. tostring(since)) or "VOLL")) .. " Snapshot: " .. #snapshot.items .. " Items, " .. #snapshot.listings .. " Inserate, "
        .. #snapshot.tombstones .. " Tombstones, " .. total .. " Pakete, " .. #encoded .. " Bytes")

    if #outgoingQueue + #packets > 10000 then
        GTC:Print(L("Sync-Warteschlange voll; Snapshot nicht eingereiht."))
        return false
    end

    if ownOnly then
        -- Eigene Inserate haben Vorrang vor grossen Snapshots, die gerade noch laufen.
        for index, packet in ipairs(packets) do
            table.insert(outgoingQueue, index, packet)
        end
        TrackEnqueue(#packets, true, nil)
    else
        for _, packet in ipairs(packets) do
            table.insert(outgoingQueue, packet)
        end
        sessionQueuedAt = startedAt
        TrackEnqueue(#packets, false, function(complete)
            if complete then
                -- Erst jetzt gilt der Stand als verteilt (kein Verlust bei Logout/Reload).
                if (tonumber(db.sync.lastBroadcastAt) or 0) < startedAt then
                    db.sync.lastBroadcastAt = startedAt
                end
            else
                sessionQueuedAt = nil
            end
        end)
    end

    if type(GTC.SetWindowStatus) == "function" then
        GTC:SetWindowStatus("Sync: " .. total .. L(" Pakete eingereiht"))
    end

    if ownOnly then
        if not quiet then
            GTC:Print(
                L("Eigene Inserate eingereiht (") .. #snapshot.listings
                .. L(" Inserate, ") .. total .. L(" Pakete).")
            )
        end
    else
        GTC:Print(
            L("Gilden-Snapshot eingereiht: ") .. #snapshot.items .. L(" Items, ")
            .. #snapshot.listings .. L(" Inserate, ") .. #snapshot.tombstones
            .. L(" Löschmarkierungen (") .. total .. L(" Pakete).")
        )
    end

    PumpQueue()
    return true
end

-- forceFull: vollstaendiger Snapshot. requestedSince: ein Mitglied braucht alles seit
-- diesem Zeitpunkt. Ohne beides werden nur Aenderungen seit dem letzten Versand gesendet.
local function ScheduleSnapshot(forceFull, requestedSince)
    if forceFull then
        pendingFull = true
    end
    if requestedSince then
        pendingSince = pendingSince and math.min(pendingSince, requestedSince) or requestedSince
    end

    if snapshotScheduled then
        return
    end

    snapshotScheduled = true
    After(2.5, function()
        snapshotScheduled = false

        local full, requested = pendingFull, pendingSince
        pendingFull, pendingSince = false, nil

        if not IsGuildScope() or not prefixRegistered then
            return
        end

        local since
        if not full then
            since = requested
            if not since then
                local db = CurrentDatabase()
                local last = math.max(db and tonumber(db.sync.lastBroadcastAt) or 0, sessionQueuedAt or 0)
                if last > 0 then
                    since = math.max(0, last - 60)
                end
            end
            if since and since <= 0 then
                since = nil
            end
        end

        if SendSnapshot(since) then
            lastSnapshotTime = (type(GetTime) == "function") and GetTime() or time()
        end
    end)
end
function GTC:ScheduleGuildSync()
    if not IsGuildScope() or not prefixRegistered then
        return false
    end

    ScheduleSnapshot()
    return true
end
-- Sendet die eigenen aktiven Inserate (und eigene Loeschmarker) als kleinen Snapshot erneut.
-- Heilt verlorene Pakete und Logout-vor-Versand, ohne das Protokoll zu aendern: Empfaenger
-- ignorieren bereits bekannte Inserate.
function GTC:AnnounceOwnListings(auto)
    if not IsGuildScope() or not prefixRegistered then
        return false
    end

    local now = (type(GetTime) == "function") and GetTime() or 0
    if auto then
        if #outgoingQueue > 300 then
            return false
        end
        if lastOwnAnnounceAt > 0 and now - lastOwnAnnounceAt < 300 then
            return false
        end
    end

    if SendSnapshot(nil, { ownOnly = true, quiet = auto == true }) then
        lastOwnAnnounceAt = now
        return true
    end
    return false
end

-- Manueller Sync (Button und /gtcsync): eigene Inserate erneut senden und Neuigkeiten abfragen.
function GTC:ManualSync()
    local now = (type(GetTime) == "function") and GetTime() or 0
    if lastManualSyncAt > 0 and now - lastManualSyncAt < 60 then
        self:Print(L("Bitte noch ") .. tostring(math.ceil(60 - (now - lastManualSyncAt)))
            .. L(" s warten, bevor du erneut synchronisierst."))
        return false
    end
    if not IsGuildScope() or not prefixRegistered then
        return self:StartGuildSync()
    end
    lastManualSyncAt = now
    self:AnnounceOwnListings(false)
    return self:StartGuildSync()
end

function GTC:StartGuildSync()
    if not IsGuildScope() then
        if type(self.SetWindowStatus) == "function" then
            self:SetWindowStatus(L("Sync inaktiv: keine Gilde"))
        end
        self:Print(L("Sync deaktiviert: kein aktiver Gilden-Datenbereich."))
        return false
    end

    if not prefixRegistered then
        self:Print(L("Sync deaktiviert: Addon-Präfix konnte nicht registriert werden."))
        return false
    end

    local encode = GetEncodingFunction("EncodeBase64")
    if not encode then
        self:Print(L("Sync deaktiviert: Base64-API nicht verfügbar."))
        return false
    end

    local scopeEncoded = EncodeBase64(self.db.scopeKey)
    if not scopeEncoded then
        self:Print(L("Gilden-Scope konnte nicht kodiert werden."))
        return false
    end

    GTC:Log("SYNC>", "HELLO gesendet")
    local hello = "H|" .. PROTOCOL .. "|" .. scopeEncoded
    if not QueueMessage(hello) then
        return false
    end
    if not helloSentAt then
        catchupAtHello = tonumber(self.db.sync.lastCatchup) or 0
    end
    helloSentAt = (type(GetTime) == "function") and GetTime() or 0
    helloAttempts = helloAttempts + 1

    -- Zeitpunkt, bis zu dem diese Datenbank vollstaendig ist: Antwortende senden nur
    -- Neueres (aeltere Versionen ignorieren diese Nachricht und senden alles).
    QueueMessage("T|2|" .. tostring(math.floor(tonumber(self.db.sync.lastCatchup) or 0)))

    -- Eigene Inserate sofort erneut ankuendigen (klein, vor dem grossen Snapshot) und
    -- danach regelmaessig, damit nichts dauerhaft verloren geht.
    self:AnnounceOwnListings(true)
    if not ownAnnounceTicker and C_Timer and type(C_Timer.NewTicker) == "function" then
        ownAnnounceTicker = C_Timer.NewTicker(900, function()
            GTC:AnnounceOwnListings(true)
        end)
    end

    PumpQueue()
    ScheduleSnapshot()
    if type(self.SetWindowStatus) == "function" then
        self:SetWindowStatus(L("Gilden-Sync gestartet"))
    end
    self:Print(L("Gilden-Sync gestartet. Es wird ausschließlich GUILD-Addon-Kommunikation verwendet."))
    return true
end

local function FindListing(db, listingID)
    for _, entry in ipairs(db.listings) do
        if entry and tostring(entry.id) == listingID then
            return entry
        end
    end
    return nil
end

local pendingLimitWarned = { items = false, listings = false }

local function CountMapEntries(map)
    local count = 0
    if type(map) == "table" then
        for _ in pairs(map) do
            count = count + 1
        end
    end
    return count
end

-- Laufzeit-Index: welche Item-IDs haben wartende Inserate? Vorher wurde bei JEDEM
-- Item-Cache-Ereignis des Spiels (Tooltips, Taschen, andere Addons) die komplette
-- Warteliste durchlaufen.
local pendingByItem = nil
local pendingByItemTable = nil

local function MarkPendingIndexDirty()
    pendingByItem = nil
end

local function HasPendingListingForItem(db, itemID)
    local pending = db and db.sync and db.sync.pendingListings
    if type(pending) ~= "table" then
        return false
    end
    if not pendingByItem or pendingByItemTable ~= pending then
        pendingByItem = {}
        pendingByItemTable = pending
        for _, record in pairs(pending) do
            local id = type(record) == "table" and tonumber(record.itemID) or nil
            if id then
                pendingByItem[id] = true
            end
        end
    end
    return pendingByItem[itemID] == true
end

local function EnsurePendingSyncTables(db)
    if type(db.sync.pendingItems) ~= "table" then
        db.sync.pendingItems = {}
        db.sync.pendingItemCount = 0
    elseif type(db.sync.pendingItemCount) ~= "number" then
        db.sync.pendingItemCount = CountMapEntries(db.sync.pendingItems)
    end

    if type(db.sync.pendingListings) ~= "table" then
        db.sync.pendingListings = {}
        db.sync.pendingListingCount = 0
    elseif type(db.sync.pendingListingCount) ~= "number" then
        db.sync.pendingListingCount = CountMapEntries(db.sync.pendingListings)
    end
end

local function RemovePendingItemRecord(db, key)
    if db.sync.pendingItems[key] ~= nil then
        db.sync.pendingItems[key] = nil
        db.sync.pendingItemCount = math.max(0, (tonumber(db.sync.pendingItemCount) or 1) - 1)
    end
end

local function RemovePendingListingRecord(db, id)
    if db.sync.pendingListings[id] ~= nil then
        db.sync.pendingListings[id] = nil
        db.sync.pendingListingCount = math.max(0, (tonumber(db.sync.pendingListingCount) or 1) - 1)
        MarkPendingIndexDirty()
    end
end

local function IsPendingRecordNewer(candidate, existing)
    if type(existing) ~= "table" then
        return true
    end

    local candidateUpdated = tonumber(candidate.updatedAt or candidate.lastSeen) or 0
    local existingUpdated = tonumber(existing.updatedAt or existing.lastSeen) or 0
    if candidateUpdated ~= existingUpdated then
        return candidateUpdated > existingUpdated
    end

    return (tonumber(candidate.revision) or 0) > (tonumber(existing.revision) or 0)
end

local function QueuePendingItemRecord(db, sender, remote, itemID, now)
    local key = tostring(itemID)
    local record = {
        sender = sender,
        itemID = itemID,
        firstSeen = SafeNumber(remote.firstSeen, 0, 4000000000) or now,
        lastSeen = SafeNumber(remote.lastSeen, 0, 4000000000) or now,
        updatedAt = SafeNumber(remote.updatedAt or remote.lastSeen, 0, 4000000000) or 0,
        revision = SafeNumber(remote.revision, 0, 1000000000) or 0,
        syncRevision = SafeNumber(remote.syncRevision, 0, 1000000000) or 0,
        name = SafeString(remote.name, 256),
        itemLink = SafeString(remote.itemLink, 1000),
        itemType = SafeString(remote.itemType, 128),
        itemSubType = SafeString(remote.itemSubType, 128),
        quality = SafeNumber(remote.quality, 0, 100),
        scopeKey = db.scopeKey,
    }

    if type(remote.icon) == "number"
        or (type(remote.icon) == "string" and #remote.icon <= 256) then
        record.icon = remote.icon
    end

    local existing = db.sync.pendingItems[key]
    if existing then
        if IsPendingRecordNewer(record, existing) then
            db.sync.pendingItems[key] = record
        end
        return true
    end

    if db.sync.pendingItemCount >= MAX_PENDING_ITEMS then
        if not pendingLimitWarned.items then
            pendingLimitWarned.items = true
            GTC:Print(L("SYNC-WARNUNG: Die Warteschlange für noch unbekannte Item-Daten ist voll. Neue Datensätze werden nicht stillschweigend übernommen."))
        end
        return false
    end

    db.sync.pendingItems[key] = record
    db.sync.pendingItemCount = db.sync.pendingItemCount + 1
    return true
end

local function QueuePendingListingRecord(db, sender, remote, itemID, id, now)
    local quantity = SafeNumber(remote.quantity, 1, 1000000000)
    local character = SafeString(remote.character, 100)
    local kind = remote.kind
    local expiresAt = SafeNumber(remote.expiresAt, 0, 4000000000)
    local updatedAt = SafeNumber(remote.updatedAt or remote.createdAt, 0, 4000000000) or 0

    if not quantity or not character or not expiresAt or expiresAt <= now
        or not GTC:SameGuildScope(remote.scopeKey, db.scopeKey) or remote.isTest ~= false
        or (kind ~= "offer" and kind ~= "wanted") then
        return false
    end

    local record = {
        sender = sender,
        id = id,
        itemID = itemID,
        item = SafeString(remote.item, 256),
        itemLink = SafeString(remote.itemLink, 1000),
        quantity = quantity,
        tradeType = SafeString(remote.tradeType, 128) or L("Tausch"),
        description = SafeString(remote.description or "", 2000) or "",
        character = character,
        kind = kind,
        isTest = false,
        createdAt = SafeNumber(remote.createdAt, 0, 4000000000) or now,
        expiresAt = expiresAt,
        durationHours = SafeNumber(remote.durationHours, 1, 72) or 24,
        completed = remote.completed == true,
        completedAt = SafeNumber(remote.completedAt, 0, 4000000000),
        completedBy = SafeString(remote.completedBy, 100),
        updatedAt = updatedAt,
        revision = SafeNumber(remote.revision, 0, 1000000000) or 0,
        syncRevision = SafeNumber(remote.syncRevision, 0, 1000000000) or 0,
        scopeKey = db.scopeKey,
    }
    CopyProfessionFields(record, remote)

    if type(remote.icon) == "number"
        or (type(remote.icon) == "string" and #remote.icon <= 256) then
        record.icon = remote.icon
    end

    local existing = db.sync.pendingListings[id]
    if existing then
        if IsPendingRecordNewer(record, existing) then
            db.sync.pendingListings[id] = record
            MarkPendingIndexDirty()
        end
        return true
    end

    if db.sync.pendingListingCount >= MAX_PENDING_LISTINGS then
        if not pendingLimitWarned.listings then
            pendingLimitWarned.listings = true
            GTC:Print(L("SYNC-WARNUNG: Die Warteschlange für Inserate mit unbekannten Item-Daten ist voll. Neue Inserate werden nicht stillschweigend übernommen."))
        end
        return false
    end

    db.sync.pendingListings[id] = record
    db.sync.pendingListingCount = db.sync.pendingListingCount + 1
    MarkPendingIndexDirty()
    return true
end
local ProcessPendingSyncForItem

-- Grundname eines Charakters ("Name-Realm" -> "name") als Zaehlschluessel.
local function CharKey(name)
    local text = tostring(name or "")
    return (text:match("^([^%-]+)") or text):lower()
end

-- Prueft, ob ein fremder Loeschmarker plausibel vom Besitzer (oder vom Ablauf) stammt.
-- Das Netzwerkformat bleibt gleich: deletedBy wird wie bisher vom Loescher gesetzt.
local function TombstoneIsAuthentic(existing, id, deletedAt, deletedBy, now)
    if deletedBy == "expiry" then
        if existing then
            return (tonumber(existing.expiresAt) or 0) <= math.min(deletedAt, now) + 600
        end
        return true
    end
    if deletedBy == "" then
        return false
    end
    if existing then
        return GTC:SameCharacter(existing.character, deletedBy)
    end
    -- Inserat unbekannt: Der Ersteller steckt in der ID ("gtc-<Realm>-<Vorname>-<Zeit>-<Nr>").
    -- deletedBy ist der volle Name ("Vorname Nachname" oder "Name-Realm"); in der ID steht
    -- nur der Vorname. Vorher wurde bei Namen mit Leerzeichen nie ein Treffer gefunden.
    local baseName = deletedBy:match("^([^%s%-]+)")
    return baseName ~= nil and id:find("-" .. baseName .. "-", 1, true) ~= nil
end

local function MergeSnapshot(sender, snapshot)
    local db = CurrentDatabase()
    if not db or db.scopeType ~= "guild" then
        return
    end

    if type(snapshot) ~= "table"
        or snapshot.protocol ~= PROTOCOL
        or snapshot.schemaVersion ~= 2
        or snapshot.scopeType ~= "guild" then
        return
    end

    if not GTC:SameGuildScope(snapshot.scopeKey, db.scopeKey) then
        sendStats.rxScopeMismatch = (sendStats.rxScopeMismatch or 0) + 1
        sendStats.lastScopeMismatch = SafeString(snapshot.scopeKey, 300)
        GTC:Log("SYNC<", "Snapshot verworfen: anderer Datenbereich "
            .. tostring(snapshot.scopeKey) .. " (eigener: " .. tostring(db.scopeKey) .. ")")
        return
    end

    if type(snapshot.items) ~= "table"
        or type(snapshot.listings) ~= "table"
        or type(snapshot.tombstones) ~= "table" then
        return
    end

    if #snapshot.items > MAX_ITEMS
        or #snapshot.listings > MAX_LISTINGS
        or #snapshot.tombstones > MAX_TOMBSTONES then
        return
    end

    -- Items aus Snapshots werden nicht mehr uebernommen (Katalog nur auf Knopfdruck).
    if not SYNC_ITEMS then
        snapshot.items = {}
    end

    -- Erst nach der Validierung: Der Snapshot ist gueltig.
    -- 1) Ein anderes Mitglied (nicht der Hello-Absender) hat geantwortet; merken, ab wann
    --    dessen Daten reichen (fuer die Unterdrueckung eigener Hello-Antworten).
    if sender ~= helloSender and type(GetTime) == "function"
        and (tonumber(snapshot.since) or 0) < 4000000000 then
        lastSnapshotSeenAt = GetTime()
        lastSnapshotSeenSince = tonumber(snapshot.since) or 0
    end

    -- 2) Die Datenbank gilt bis "createdAt" als vollstaendig, wenn der Snapshot alles seit
    --    einem Zeitpunkt enthaelt, der nicht spaeter liegt als unser bisheriger Stand.
    do
        local snapshotSince = tonumber(snapshot.since) or 0
        local caughtUp = tonumber(db.sync.lastCatchup) or 0
        local created = tonumber(snapshot.createdAt) or 0
        if snapshotSince <= caughtUp and created > caughtUp then
            db.sync.lastCatchup = created
        end
    end

    local now = Now()
    EnsurePendingSyncTables(db)

    -- Index der vorhandenen Inserate (ID -> Eintrag). Vorher wurde fuer jede
    -- Loeschmarkierung und jedes Inserat die ganze Liste mehrfach linear durchsucht
    -- (bis zu 5000 x 3000 Vergleiche pro Snapshot = spuerbarer Ruckler).
    local listingById = {}
    for _, entry in ipairs(db.listings) do
        if type(entry) == "table" and entry.id ~= nil then
            local entryKey = tostring(entry.id)
            if listingById[entryKey] == nil then
                listingById[entryKey] = entry
            end
        end
    end

    -- Abgelaufene wartende Inserate belegen keinen Queue-Platz mehr.
    for pendingID, pendingListing in pairs(db.sync.pendingListings) do
        if type(pendingListing) ~= "table"
            or (tonumber(pendingListing.expiresAt) or 0) <= now then
            RemovePendingListingRecord(db, pendingID)
        end
    end

    -- Bereits zurueckgestellte IDs merken. Wenn dieselben Items inzwischen
    -- geladen sind, werden ihre wartenden Datensaetze nach diesem Merge erneut verarbeitet.
    local pendingItemIDs = {}
    for key in pairs(db.sync.pendingItems) do
        pendingItemIDs[key] = true
    end
    for _, pending in pairs(db.sync.pendingListings) do
        if type(pending) == "table" and pending.itemID then
            pendingItemIDs[tostring(pending.itemID)] = true
        end
    end

    local acceptedItems = {}
    local acceptedListings = {}
    local bindingTypes = {}
    local provisional = {}
    local resolvedPendingItemIDs = {}
    local deferredItems = 0
    local deferredListings = 0

    -- Bindungsstatus immer lokal pruefen. bindType aus fremden Snapshots wird
    -- nicht als vertrauenswuerdiger Nachweis verwendet.
    for _, remote in ipairs(snapshot.items) do
        if type(remote) == "table" then
            local itemID = SafeNumber(remote.itemID, 1, 1000000000)
            if not itemID then
                table.insert(acceptedItems, remote)
            else
                local key = tostring(itemID)
                local bindType = GTC:GetItemBindingType(itemID, true)

                if type(bindType) ~= "number" then
                    -- Der Client kennt den Gegenstand noch nicht. Der Absender filtert BoP
                    -- bereits selbst und meldet die Bindung mit. Damit Katalog und Inserate
                    -- sofort sichtbar sind, wird vorlaeufig akzeptiert und die Bindung lokal
                    -- nachgeprueft, sobald die Item-Daten geladen sind (UpdateItemMetadata).
                    local claimed = SafeNumber(remote.bindType, 0, 20)
                    if claimed and claimed ~= 1 then
                        provisional[key] = true
                        bindingTypes[key] = claimed
                        table.insert(acceptedItems, remote)
                    elseif QueuePendingItemRecord(db, sender, remote, itemID, now) then
                        deferredItems = deferredItems + 1
                    end
                else
                    bindingTypes[key] = bindType
                    if pendingItemIDs[key] then
                        resolvedPendingItemIDs[key] = itemID
                    end
                    if bindType ~= 1 then
                        table.insert(acceptedItems, remote)
                    end
                end
            end
        end
    end

    for _, remote in ipairs(snapshot.listings) do
        if type(remote) == "table" then
            local id = SafeString(remote.id, 180)
            local itemID = SafeNumber(remote.itemID, 1, 1000000000)

            if not id or not itemID then
                table.insert(acceptedListings, remote)
            else
                local key = tostring(itemID)
                local bindType = GTC:GetItemBindingType(itemID, true)

                if type(bindType) ~= "number" then
                    -- Bindung des Gegenstands aus dem gleichen Snapshot oder dem Katalog
                    -- uebernehmen (vorlaeufig, wird lokal nachgeprueft).
                    local known = bindingTypes[key]
                    if not known then
                        local catalogEntry = db.items[key]
                        known = type(catalogEntry) == "table" and tonumber(catalogEntry.bindType) or nil
                    end
                    if not known then
                        known = SafeNumber(remote.bindType, 0, 20)
                    end
                    if known and known ~= 1 then
                        provisional[key] = true
                        table.insert(acceptedListings, remote)
                        -- Katalog-Platzhalter, damit die Bindung spaeter lokal geprueft
                        -- wird (UpdateItemMetadata entfernt das Inserat bei BoP).
                        if type(db.items[key]) ~= "table" then
                            db.items[key] = {
                                itemID = itemID,
                                name = SafeString(remote.item, 256),
                                bindType = known,
                                bindUnverified = true,
                                firstSeen = now,
                                lastSeen = now,
                                scopeKey = db.scopeKey,
                            }
                        end
                    elseif QueuePendingListingRecord(db, sender, remote, itemID, id, now) then
                        deferredListings = deferredListings + 1
                    end
                else
                    bindingTypes[key] = bindType
                    if pendingItemIDs[key] then
                        resolvedPendingItemIDs[key] = itemID
                    end
                    if bindType ~= 1 then
                        table.insert(acceptedListings, remote)
                    end
                end
            end
        end
    end

    snapshot.items = acceptedItems
    snapshot.listings = acceptedListings

    local changed = false
    local addedItems = 0
    local addedListings = 0
    local appliedDeletes = 0
    local removedListings = {}

    -- Loeschmarkierungen zuerst anwenden, damit alte Inserate aus demselben
    -- Snapshot nicht unmittelbar wieder eingesetzt werden.
    for _, remote in ipairs(snapshot.tombstones) do
        if type(remote) == "table" then
            local id = SafeString(remote.id, 180)
            local deletedAt = SafeNumber(remote.deletedAt, 0, 4000000000)
            local remoteDeletedBy = SafeString(remote.deletedBy, 100) or ""

            if id and deletedAt and GTC:SameGuildScope(remote.scopeKey, db.scopeKey)
                and deletedAt <= now + GTC.MAX_FUTURE_SKEW
                and deletedAt >= now - GTC.TOMBSTONE_RETENTION
                and TombstoneIsAuthentic(listingById[id], id, deletedAt, remoteDeletedBy, now) then
                local pendingListing = db.sync.pendingListings[id]
                if pendingListing
                    and (tonumber(pendingListing.updatedAt) or 0) <= deletedAt then
                    RemovePendingListingRecord(db, id)
                end

                local existingTombstone = db.sync.tombstones[id]
                local existingDeletedAt =
                    type(existingTombstone) == "table"
                    and (tonumber(existingTombstone.deletedAt) or 0) or 0

                if not existingTombstone or deletedAt > existingDeletedAt then
                    db.sync.tombstones[id] = {
                        id = id,
                        scopeKey = db.scopeKey,
                        deletedAt = deletedAt,
                        deletedBy = remoteDeletedBy,
                        revision = SafeNumber(remote.revision, 0, 1000000000) or 0,
                    }
                    changed = true
                end

                local currentListing = listingById[id]
                if currentListing
                    and (tonumber(currentListing.updatedAt) or 0) <= deletedAt then
                    removedListings[currentListing] = true
                    listingById[id] = nil
                    appliedDeletes = appliedDeletes + 1
                    changed = true
                end
            end
        end
    end

    -- Geloeschte Inserate in einem Durchgang entfernen (gleiche Tabelle bleibt erhalten).
    if appliedDeletes > 0 then
        local listings = db.listings
        local count = #listings
        local write = 0
        for read = 1, count do
            local entry = listings[read]
            if not removedListings[entry] then
                write = write + 1
                listings[write] = entry
            end
        end
        for index = write + 1, count do
            listings[index] = nil
        end
    end

    local positionOf = {}
    for index, entry in ipairs(db.listings) do
        positionOf[entry] = index
    end

    -- Item-Katalog ueber eindeutige Item-IDs zusammenfuehren.
    for _, remote in ipairs(snapshot.items) do
        if type(remote) == "table" then
            local itemID = SafeNumber(remote.itemID, 1, 1000000000)
            local key = itemID and tostring(itemID)

            if key then
                local existing = db.items[key]
                local remoteUpdated = SafeNumber(remote.updatedAt or remote.lastSeen, 0, 4000000000) or 0
                local localUpdated = type(existing) == "table"
                    and (tonumber(existing.updatedAt or existing.lastSeen) or 0) or -1

                if type(existing) ~= "table" or remoteUpdated > localUpdated then
                    local merged = {
                        itemID = itemID,
                        bindType = bindingTypes[key],
                        bindUnverified = provisional[key] or nil,
                        name = SafeString(remote.name, 256),
                        itemLink = SafeString(remote.itemLink, 1000) or ("item:" .. tostring(itemID)),
                        itemType = SafeString(remote.itemType, 128),
                        itemSubType = SafeString(remote.itemSubType, 128),
                        quality = SafeNumber(remote.quality, 0, 100),
                        firstSeen = SafeNumber(remote.firstSeen, 0, 4000000000) or now,
                        lastSeen = SafeNumber(remote.lastSeen, 0, 4000000000) or now,
                        updatedAt = remoteUpdated,
                        revision = SafeNumber(remote.revision, 0, 1000000000) or 0,
                        syncRevision = SafeNumber(remote.syncRevision, 0, 1000000000) or 0,
                        scopeKey = db.scopeKey,
                    }

                    if type(remote.icon) == "number" or
                        (type(remote.icon) == "string" and #remote.icon <= 256) then
                        merged.icon = remote.icon
                    end

                    db.items[key] = merged
                    changed = true
                    addedItems = addedItems + 1
                end
            end
        end
    end

    -- Aktive Inserate je Charakter zaehlen (Limit gegen Flooding).
    local activeByChar = {}
    for _, entry in ipairs(db.listings) do
        if type(entry) == "table" and entry.completed ~= true
            and (tonumber(entry.expiresAt) or 0) > now then
            local key = CharKey(entry.character)
            activeByChar[key] = (activeByChar[key] or 0) + 1
        end
    end

    -- Inserate zusammenfuehren; Testdaten, abgelaufene Inserate und
    -- Eintraege aus einem anderen Scope werden nicht uebernommen.
    for _, remote in ipairs(snapshot.listings) do
        if type(remote) == "table" then
            local id = SafeString(remote.id, 180)
            local itemID = SafeNumber(remote.itemID, 1, 1000000000)
            local quantity = SafeNumber(remote.quantity, 1, 1000000000)
            local character = SafeString(remote.character, 100)
            local kind = remote.kind
            local expiresAt = SafeNumber(remote.expiresAt, 0, 4000000000)
            local updatedAt = SafeNumber(remote.updatedAt or remote.createdAt, 0, 4000000000) or 0

            -- Gefaelschte Zeitstempel begrenzen: Ablauf hoechstens 72 h (+Toleranz) voraus.
            if expiresAt and expiresAt > now + GTC.MAX_LISTING_LIFETIME then
                expiresAt = now + GTC.MAX_LISTING_LIFETIME
            end

            local valid = id and itemID and quantity and character and expiresAt
                and expiresAt > now
                and updatedAt <= now + GTC.MAX_FUTURE_SKEW
                and GTC:SameGuildScope(remote.scopeKey, db.scopeKey)
                and remote.isTest == false
                and (kind == "offer" or kind == "wanted")

            if valid then
                local tombstone = db.sync.tombstones[id]
                local deletedAt = type(tombstone) == "table"
                    and (tonumber(tombstone.deletedAt) or 0) or 0

                if deletedAt < updatedAt then
                    local existing = listingById[id]
                    local existingUpdated = type(existing) == "table"
                        and (tonumber(existing.updatedAt or existing.createdAt) or 0) or -1
                    local remoteRevision = SafeNumber(remote.revision, 0, 1000000000) or 0
                    local localRevision = type(existing) == "table"
                        and (tonumber(existing.revision) or 0) or -1

                    -- Der Besitzer eines Inserats darf sich nicht aendern; neue Inserate eines
                    -- Charakters nur bis zum Limit.
                    local ownerOK = (not existing) or GTC:SameCharacter(existing.character, character)
                    local capOK = existing ~= nil
                        or (activeByChar[CharKey(character)] or 0) < GTC.MAX_ACTIVE_PER_CHARACTER

                    -- Gleicher Stand, aber mit Berufsangaben: Inserat wurde vorher ueber eine
                    -- aeltere Version (ohne die neuen Felder) weitergereicht, jetzt ergaenzen.
                    local enrich = existing ~= nil
                        and updatedAt == existingUpdated and remoteRevision == localRevision
                        and remote.profession ~= nil and existing.profession == nil

                    if ownerOK and capOK and (not existing or updatedAt > existingUpdated
                        or (updatedAt == existingUpdated and remoteRevision > localRevision)
                        or enrich) then

                        local merged = {
                            id = id,
                            itemID = itemID,
                            item = SafeString(remote.item, 256),
                            itemLink = SafeString(remote.itemLink, 1000) or ("item:" .. tostring(itemID)),
                            icon = remote.icon,
                            quantity = quantity,
                            tradeType = SafeString(remote.tradeType, 128) or L("Tausch"),
                            description = SafeString(remote.description or "", 2000) or "",
                            character = character,
                            kind = kind,
                            isTest = false,
                            createdAt = SafeNumber(remote.createdAt, 0, 4000000000) or now,
                            expiresAt = expiresAt,
                            durationHours = SafeNumber(remote.durationHours, 1, 72) or 24,
                            completed = remote.completed == true or (existing and existing.completed == true) or false,
                            completedAt = SafeNumber(remote.completedAt, 0, 4000000000)
                                or (existing and SafeNumber(existing.completedAt, 0, 4000000000)),
                            completedBy = SafeString(remote.completedBy, 100)
                                or (existing and SafeString(existing.completedBy, 100)),
                            updatedAt = updatedAt,
                            revision = remoteRevision,
                            syncRevision = SafeNumber(remote.syncRevision, 0, 1000000000) or 0,
                            scopeKey = db.scopeKey,
                        }
                        CopyProfessionFields(merged, remote)
                        if merged.profession then
                            merged.itemLink = GTC.Prof:BuildLink(merged.profession) or merged.itemLink
                        end

                        if type(merged.icon) ~= "number"
                            and type(merged.icon) ~= "string" then
                            merged.icon = nil
                        elseif type(merged.icon) == "string" and #merged.icon > 256 then
                            merged.icon = nil
                        end

                        if existing then
                            local position = positionOf[existing]
                            if position then
                                db.listings[position] = merged
                                positionOf[existing] = nil
                                positionOf[merged] = position
                            end
                            listingById[id] = merged
                        else
                            table.insert(db.listings, merged)
                            positionOf[merged] = #db.listings
                            listingById[id] = merged
                            addedListings = addedListings + 1
                            local countKey = CharKey(character)
                            activeByChar[countKey] = (activeByChar[countKey] or 0) + 1
                            if GTC.NotifyWatchlist then
                                pcall(GTC.NotifyWatchlist, GTC, merged)
                            end
                        end

                        changed = true
                    end
                end
            end
        end
    end

    db.sync.peers[sender] = {
        lastSeen = now,
        revision = SafeNumber(snapshot.revision, 0, 1000000000) or 0,
    }
    -- GTC_UPDATE5_AH_SCAN_SYNC_IN
    -- Only the minimal, non-market scan metadata is merged from a complete, validated peer snapshot.
    local remoteAHScan = type(snapshot) == "table" and type(snapshot.ahScan) == "table" and snapshot.ahScan or nil
    if remoteAHScan and remoteAHScan.source == "ah" then
        local remoteScanAt = SafeNumber(remoteAHScan.at, 1, 4000000000)
        local remoteCharacter = SafeString(remoteAHScan.character, 100)
        if remoteScanAt and remoteCharacter and remoteCharacter ~= "" then
            local currentScan = type(db.scan) == "table" and type(db.scan.ahLatestScan) == "table" and db.scan.ahLatestScan or nil
            local currentScanAt = currentScan and tonumber(currentScan.at) or 0
            if remoteScanAt > currentScanAt then
                if type(db.scan) ~= "table" then db.scan = {} end
                db.scan.ahLatestScan = {
                    at = math.floor(remoteScanAt),
                    character = remoteCharacter,
                    source = "ah",
                }
                -- Kein erneutes Senden: Der Snapshot ging bereits an die ganze Gilde. Frueher
                -- schickte JEDER Empfaenger daraufhin einen eigenen Delta-Snapshot (N-faches Echo).
                -- Spaeter eingeloggte Mitglieder erhalten den Stand ohnehin mit jedem Snapshot.
            end
        end
    end

    db.sync.lastSync = now

    GTC:Log("SYNC<", "Merge von " .. tostring(sender) .. ": +" .. addedItems .. " Items, +" .. addedListings
        .. " Inserate, -" .. appliedDeletes .. " gelöscht, zurückgestellt " .. deferredItems .. "/" .. deferredListings
        .. ", geändert=" .. tostring(changed))

    if changed then
        db.sync.revision = (tonumber(db.sync.revision) or 0) + 1
        if type(GTC.SetWindowStatus) == "function" then
            GTC:SetWindowStatus(
                L("Sync empfangen: +") .. addedItems .. L(" Items, +") ..
                addedListings .. L(" Inserate, -") .. appliedDeletes
            )
        end

        GTC:Print(
            L("Sync übernommen: ") .. addedItems .. L(" Item-Datensätze, ")
            .. addedListings .. L(" Inserate neu, ") .. appliedDeletes
            .. L(" Inserate gelöscht/entfernt.")
        )
        if GTC.RefreshListingView then
            GTC:RefreshListingView()
        end
    end
    if deferredItems > 0 or deferredListings > 0 then
        if type(GTC.SetWindowStatus) == "function" then
            GTC:SetWindowStatus(
                L("Sync wartet auf Item-Daten: ") .. deferredItems .. L(" Items, ") ..
                deferredListings .. L(" Inserate")
            )
        end
    end

    -- Wenn ein vormals unbekanntes Item jetzt aus einem anderen Snapshot
    -- aufgeloest wurde, wartende Datensaetze nach dem aktuellen Merge erneut versuchen.
    if ProcessPendingSyncForItem then
        for _, resolvedItemID in pairs(resolvedPendingItemIDs) do
            ProcessPendingSyncForItem(resolvedItemID)
        end
    end
end

ProcessPendingSyncForItem = function(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return
    end

    local db = CurrentDatabase()
    if not db or db.scopeType ~= "guild" then
        return
    end

    EnsurePendingSyncTables(db)
    local bindType = GTC:GetItemBindingType(itemID)
    if type(bindType) ~= "number" then
        return
    end

    local key = tostring(itemID)
    local groups = {}
    local function GetGroup(sender)
        if type(sender) ~= "string" or sender == "" then
            return nil
        end
        if not groups[sender] then
            groups[sender] = { items = {}, listings = {} }
        end
        return groups[sender]
    end

    local pendingItem = db.sync.pendingItems[key]
    if pendingItem then
        RemovePendingItemRecord(db, key)
        if bindType ~= 1 then
            local group = GetGroup(pendingItem.sender)
            if group then
                pendingItem.sender = nil
                table.insert(group.items, pendingItem)
            end
        end
    end

    -- Alle wartenden Inserate zu derselben Item-ID gemeinsam aufloesen.
    for listingID, pendingListing in pairs(db.sync.pendingListings) do
        if type(pendingListing) == "table"
            and tonumber(pendingListing.itemID) == itemID then
            RemovePendingListingRecord(db, listingID)
            if bindType ~= 1 then
                local group = GetGroup(pendingListing.sender)
                if group then
                    pendingListing.sender = nil
                    table.insert(group.listings, pendingListing)
                end
            end
        end
    end

    -- BindType 1 = BoP: wartende Remote-Datensaetze werden verworfen und
    -- gelangen weder in den lokalen Gilden-Katalog noch in die Inseratsliste.
    if bindType == 1 then
        return
    end

    for sender, batch in pairs(groups) do
        local listingCount = #batch.listings
        local offset = 1
        local firstBatch = true

        repeat
            local listingChunk = {}
            local stopAt = math.min(offset + MAX_LISTINGS - 1, listingCount)
            for index = offset, stopAt do
                table.insert(listingChunk, batch.listings[index])
            end

            local retrySnapshot = {
                protocol = PROTOCOL,
                schemaVersion = 2,
                scopeKey = db.scopeKey,
                scopeType = "guild",
                guildName = db.guildName,
                realm = db.realm,
                faction = db.faction,
                revision = tonumber(db.sync.revision) or 0,
                since = 4000000000, -- Teil-Datensatz: darf lastCatchup nicht vorruecken
                createdAt = time(),
                createdBy = CurrentPlayerName() or "UnknownPlayer",
                items = firstBatch and batch.items or {},
                listings = listingChunk,
                tombstones = {},
            }
            MergeSnapshot(sender, retrySnapshot)
            firstBatch = false
            offset = offset + MAX_LISTINGS
        until offset > listingCount
    end
end

function GTC:ProcessPendingSyncForItem(itemID)
    ProcessPendingSyncForItem(itemID)
end

-- limit: nur so viele Items je Aufruf verarbeiten (Rotation ueber alle wartenden Items),
-- damit der Client nicht mit Item-Anfragen ueberflutet wird. Ohne limit werden alle bearbeitet.
function GTC:ProcessAllPendingSync(limit)
    local db = CurrentDatabase()
    if not db or db.scopeType ~= "guild" then
        return
    end

    EnsurePendingSyncTables(db)
    local seen, list = {}, {}
    for key in pairs(db.sync.pendingItems) do
        local id = tonumber(key)
        if id and not seen[id] then
            seen[id] = true
            list[#list + 1] = id
        end
    end
    for _, pending in pairs(db.sync.pendingListings) do
        local id = type(pending) == "table" and tonumber(pending.itemID) or nil
        if id and not seen[id] then
            seen[id] = true
            list[#list + 1] = id
        end
    end
    table.sort(list)

    if limit and #list > limit then
        local startIndex = 1
        for index, id in ipairs(list) do
            if id > pendingCursor then
                startIndex = index
                break
            end
        end
        local picked = {}
        for step = 0, limit - 1 do
            picked[#picked + 1] = list[((startIndex - 1 + step) % #list) + 1]
        end
        pendingCursor = picked[#picked]
        list = picked
    end

    for _, itemID in ipairs(list) do
        ProcessPendingSyncForItem(itemID)
    end
end

local function ExpireIncompleteTransfers()
    local now = time()
    for key, transfer in pairs(incomingTransfers) do
        -- Bei ca. 1 Paket/s (Blizzard-Limit) dauern grosse Snapshots lange: Verwerfen erst
        -- nach 10 Minuten ohne neues Paket oder nach 60 Minuten insgesamt.
        if type(transfer) ~= "table"
            or now - (tonumber(transfer.lastPartAt) or tonumber(transfer.createdAt) or now) > 600
            or now - (tonumber(transfer.createdAt) or now) > 3600 then
            incomingTransfers[key] = nil
        end
    end
end

-- Obergrenzen fuer gleichzeitig offene Uebertragungen (Speicherschutz gegen Flooding).
local MAX_TRANSFERS_PER_SENDER = 3
local MAX_TRANSFERS_TOTAL = 40

local function EvictOldestTransfer(sender)
    local oldestKey, oldestAt
    for key, transfer in pairs(incomingTransfers) do
        if type(transfer) == "table" and (sender == nil or transfer.sender == sender) then
            local startedAt = tonumber(transfer.createdAt) or 0
            if not oldestAt or startedAt < oldestAt then
                oldestKey, oldestAt = key, startedAt
            end
        end
    end
    if oldestKey then
        incomingTransfers[oldestKey] = nil
        return true
    end
    return false
end

local function EnforceTransferLimits(sender)
    local senderCount, total = 0, 0
    for _, transfer in pairs(incomingTransfers) do
        total = total + 1
        if type(transfer) == "table" and transfer.sender == sender then
            senderCount = senderCount + 1
        end
    end
    while senderCount >= MAX_TRANSFERS_PER_SENDER and EvictOldestTransfer(sender) do
        senderCount = senderCount - 1
        total = total - 1
    end
    while total >= MAX_TRANSFERS_TOTAL and EvictOldestTransfer(nil) do
        total = total - 1
    end
end

local function ReceiveChunk(sender, message)
    local transferID, partText, totalText, piece =
        message:match("^P|2|([%w%-]+)|(%d+)|(%d+)|([A-Za-z0-9+/=]+)$")

    if not transferID then
        return
    end

    local part = tonumber(partText)
    local total = tonumber(totalText)

    if not part or not total or total < 1 or total > MAX_CHUNKS
        or part < 1 or part > total or #piece > CHUNK_SIZE then
        return
    end

    ExpireIncompleteTransfers()

    local key = sender .. ":" .. transferID
    local transfer = incomingTransfers[key]

    if not transfer then
        EnforceTransferLimits(sender)
        transfer = {
            parts = {},
            total = total,
            received = 0,
            byteCount = 0,
            createdAt = time(),
            lastPartAt = time(),
            sender = sender,
        }
        incomingTransfers[key] = transfer
    end

    if transfer.total ~= total then
        incomingTransfers[key] = nil
        return
    end

    if not transfer.parts[part] then
        transfer.parts[part] = piece
        transfer.lastPartAt = time()
        transfer.received = transfer.received + 1
        transfer.byteCount = transfer.byteCount + #piece
    end

    if transfer.byteCount > MAX_ENCODED_BYTES then
        incomingTransfers[key] = nil
        return
    end

    if transfer.received ~= transfer.total then
        return
    end

    local encoded = table.concat(transfer.parts, "")
    incomingTransfers[key] = nil

    if #encoded > MAX_ENCODED_BYTES then
        return
    end

    sendStats.rxSnapshots = sendStats.rxSnapshots + 1
    sendStats.lastSnapshotAt = GetTime()
    GTC:Log("SYNC<", "Snapshot von " .. tostring(sender) .. " vollständig: " .. total .. " Pakete, " .. #encoded .. " Bytes")
    local snapshot, decodeError = DecodeSnapshot(encoded)
    if not snapshot then
        GTC:Log("ERR", "Snapshot von " .. tostring(sender) .. " verworfen: " .. tostring(decodeError))
        GTC:Print(L("Sync-Snapshot von ") .. sender .. L(" verworfen: ") .. tostring(decodeError))
        return
    end

    MergeSnapshot(sender, snapshot)
end

-- ---------------------------------------------------------------- Katalog auf Knopfdruck
local B36DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

local function B36(number)
    if number == 0 then return "0" end
    local out = {}
    while number > 0 do
        local rest = number % 36
        out[#out + 1] = B36DIGITS:sub(rest + 1, rest + 1)
        number = (number - rest) / 36
    end
    return string.reverse(table.concat(out))
end

-- Fragt den Gilden-Katalog an. Rueckgabe: ok, Meldung
function GTC:RequestGuildCatalog()
    if not IsGuildScope() or not prefixRegistered then
        return false, L("Keine Gilde oder Sync nicht bereit.")
    end
    local now = GetTime()
    if catalogRequestUntil > now then
        return false, L("Eine Anfrage läuft bereits.")
    end
    catalogRequestUntil = now + 300
    catalogIncoming = {} -- Reste frueherer, unvollstaendiger Antworten verwerfen
    GTC:Log("CAT>", "Katalog angefordert")
    if not QueueMessage("KQ|2") then
        catalogRequestUntil = 0
        return false, L("Warteschlange voll.")
    end
    PumpQueue()
    return true, L("Katalog angefordert. Antworten kommen nach wenigen Sekunden.")
end

local function SendCatalogList()
    local db = CurrentDatabase()
    if not db or not IsGuildScope() then return end

    local ids = {}
    for key, entry in pairs(db.items or {}) do
        if type(entry) == "table" and type(entry.bindType) == "number" and entry.bindType ~= 1 then
            local id = SafeNumber(entry.itemID or key, 1, 1000000000)
            if id then ids[#ids + 1] = id end
            if #ids >= CATALOG_MAX_IDS then break end
        end
    end
    if #ids == 0 then return end
    table.sort(ids)

    -- Delta-kodiert (Basis 36), jedes Paket beginnt mit einer absoluten ID.
    catalogCounter = catalogCounter + 1
    local transfer = tostring(time()) .. "-" .. tostring(catalogCounter)
    local budget = 185
    local chunks, current, length, previous = {}, {}, 0, nil
    for _, id in ipairs(ids) do
        local token = (previous and #current > 0) and B36(id - previous) or B36(id)
        if #current > 0 and length + #token + 1 > budget then
            chunks[#chunks + 1] = table.concat(current, ",")
            current, length, token = {}, 0, B36(id)
        end
        current[#current + 1] = token
        length = length + #token + 1
        previous = id
    end
    if #current > 0 then chunks[#chunks + 1] = table.concat(current, ",") end

    for index, payload in ipairs(chunks) do
        QueueMessage("KD|2|" .. transfer .. "|" .. index .. "|" .. #chunks .. "|" .. payload)
    end
    GTC:Log("CAT>", "Katalog gesendet: " .. #ids .. " Items in " .. #chunks .. " Paketen")
    PumpQueue()
end

local function MergeCatalogIds(sender, ids)
    local db = CurrentDatabase()
    if not db or db.scopeType ~= "guild" then return end
    local now = time()
    local added = 0
    for _, id in ipairs(ids) do
        local key = tostring(id)
        if type(db.items[key]) ~= "table" then
            db.items[key] = {
                itemID = id,
                bindUnverified = true,
                firstSeen = now,
                lastSeen = now,
                scopeKey = db.scopeKey,
            }
            added = added + 1
        end
    end
    GTC:Log("CAT<", "Katalog von " .. tostring(sender) .. ": " .. #ids .. " IDs, " .. added .. " neu")
    if type(GTC.SetWindowStatus) == "function" then
        GTC:SetWindowStatus(L("Katalog erhalten: +") .. added .. L(" Items"))
    end
    GTC.catalogReceivedAt = time()
    GTC.catalogReceivedCount = added
    if type(GTC.OnCatalogReceived) == "function" then
        GTC:OnCatalogReceived(added, #ids)
    end
end

local function HandleCatalogMessage(sender, message)
    if message == "KQ|2" then
        local now = GetTime()
        local db = CurrentDatabase()
        if not db then return true end
        local count = 0
        for _, entry in pairs(db.items or {}) do
            if type(entry) == "table" and type(entry.bindType) == "number" and entry.bindType ~= 1 then
                count = count + 1
                break
            end
        end
        if count == 0 then return true end
        catalogReplyToken = catalogReplyToken + 1
        local token = catalogReplyToken
        GTC:Log("CAT<", "Katalog-Anfrage von " .. tostring(sender) .. ", Antwort geplant")
        After(1 + math.random() * 8, function()
            -- Hat inzwischen ein anderes Mitglied geantwortet? Dann schweigen.
            if token ~= catalogReplyToken or catalogLastDataAt >= now then
                GTC:Log("CAT", "Katalog-Antwort unterdrückt (anderer hat geantwortet)")
                return
            end
            SendCatalogList()
        end)
        return true
    end

    local transfer, partText, totalText, payload =
        message:match("^KD|2|([%w%-]+)|(%d+)|(%d+)|([%w,]+)$")
    if not transfer then return false end

    catalogLastDataAt = GetTime()
    if catalogRequestUntil <= GetTime() then
        return true -- nicht angefordert: ignorieren
    end

    local part, total = tonumber(partText), tonumber(totalText)
    if not part or not total or total < 1 or total > 600 or part < 1 or part > total then
        return true
    end

    local key = sender .. ":" .. transfer
    local incoming = catalogIncoming[key]
    if not incoming then
        incoming = { got = {}, total = total, count = 0 }
        catalogIncoming[key] = incoming
    end
    if incoming.total ~= total then
        catalogIncoming[key] = nil
        return true
    end
    if not incoming.got[part] then
        incoming.got[part] = payload
        incoming.count = incoming.count + 1
    end
    if incoming.count < incoming.total then
        return true
    end

    catalogIncoming[key] = nil
    local ids = {}
    for index = 1, total do
        local previous
        for tokenText in incoming.got[index]:gmatch("[^,]+") do
            local value = tonumber(tokenText, 36)
            if not value then return true end
            previous = previous and (previous + value) or value
            if previous >= 1 and previous <= 1000000000 then
                ids[#ids + 1] = previous
            end
        end
    end
    if #ids > CATALOG_MAX_IDS then return true end
    catalogRequestUntil = 0
    MergeCatalogIds(sender, ids)
    return true
end

-- Erneutes HELLO (leichtgewichtig): fragt nach Daten, die uns fehlen. Antwortende senden nur
-- das, was seit unserem letzten vollstaendigen Stand neu ist.
function GTC:Rehello(reason)
    if not IsGuildScope() or not prefixRegistered then
        return false
    end
    if #outgoingQueue > 200 then
        return false
    end
    local scopeEncoded = EncodeBase64(self.db.scopeKey)
    if not scopeEncoded then
        return false
    end
    if not QueueMessage("H|" .. PROTOCOL .. "|" .. scopeEncoded) then
        return false
    end
    QueueMessage("T|2|" .. tostring(math.floor(tonumber(self.db.sync.lastCatchup) or 0)))
    helloSentAt = (type(GetTime) == "function") and GetTime() or 0
    helloAttempts = helloAttempts + 1
    GTC:Log("SYNC>", "HELLO erneut gesendet (" .. tostring(reason) .. "), Versuch " .. helloAttempts)
    PumpQueue()
    return true
end

-- Ueberwacht den Sync: startet ihn, sobald die Gilde bekannt ist (die Gildeninfo ist direkt
-- nach dem Login oft noch nicht da), wiederholt das HELLO bei fehlender Antwort und fragt
-- spaeter gelegentlich erneut nach Neuigkeiten. Wartende Item-Daten werden erneut angefragt.
local function SupervisorTick()
    if not prefixRegistered then
        return
    end

    local now = (type(GetTime) == "function") and GetTime() or 0

    if not IsGuildScope() then
        -- Ohne Gilde nicht alle 10 s die komplette Datenpruefung laufen lassen.
        if type(IsInGuild) == "function" and IsInGuild()
            and type(GTC.RefreshDatabaseScope) == "function" then
            pcall(GTC.RefreshDatabaseScope, GTC)
        end
        if not IsGuildScope() then
            return
        end
    end

    if not helloSentAt then
        if syncStartPending then
            return
        end
        syncStartPending = true
        if C_GuildInfo and type(C_GuildInfo.GuildRoster) == "function" then
            pcall(C_GuildInfo.GuildRoster)
        elseif type(GuildRoster) == "function" then
            pcall(GuildRoster)
        end
        GTC:Log("SYNC>", "Gilde jetzt bekannt, Sync wird gestartet")
        After(3, function()
            syncStartPending = false
            if helloSentAt then
                return
            end
            if GTC.ProcessAllPendingSync then
                GTC:ProcessAllPendingSync(40)
            end
            if GTC.StartGuildSync then
                GTC:StartGuildSync()
            end
        end)
        return
    end

    -- Hat jemand geantwortet (Stand ist seit dem ersten HELLO vorgerueckt)?
    local db = CurrentDatabase()
    local progressed = db ~= nil and (tonumber(db.sync.lastCatchup) or 0) > catchupAtHello
    local interval
    if progressed then
        interval = 1800
    else
        interval = ({ 30, 60, 120, 240 })[helloAttempts] or 600
    end
    -- Laeuft gerade eine Uebertragung bei uns ein (bei 1 Paket/s dauert sie Minuten), darf kein
    -- neues HELLO folgen: Es wuerde nur weitere vollstaendige Snapshots ausloesen.
    local incomingActive = false
    local wallNow = time()
    for _, transfer in pairs(incomingTransfers) do
        if type(transfer) == "table"
            and wallNow - (tonumber(transfer.lastPartAt) or tonumber(transfer.createdAt) or 0) < 120 then
            incomingActive = true
            break
        end
    end
    if now - helloSentAt >= interval and not incomingActive then
        GTC:Rehello(progressed and "regelmaessig" or "keine Antwort")
    end

    -- Wartende Inserate/Items: Item-Daten erneut anfragen (die Anfrage ist sonst einmalig).
    if db and now - lastPendingRetryAt >= 30 then
        lastPendingRetryAt = now
        if (tonumber(db.sync.pendingItemCount) or 0) > 0
            or (tonumber(db.sync.pendingListingCount) or 0) > 0 then
            if GTC.ProcessAllPendingSync then
                GTC:ProcessAllPendingSync(40)
            end
        end
    end
end

local function RegisterPrefix()
    local ok, result

    if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    elseif type(RegisterAddonMessagePrefix) == "function" then
        ok, result = pcall(RegisterAddonMessagePrefix, PREFIX)
    else
        return false
    end

    if not ok then
        return false
    end

    -- 0 = Success in newer clients; true/nil may be returned by legacy wrappers.
    if result == nil or result == true or result == 0 then
        return true
    end

    -- Prefix already registered during this session is also usable.
    if Enum and Enum.RegisterAddonMessagePrefixResult
        and result == Enum.RegisterAddonMessagePrefixResult.DuplicatePrefix then
        return true
    end

    if result == 1 then
        return true
    end

    return false
end

local commFrame = CreateFrame("Frame")
commFrame:RegisterEvent("CHAT_MSG_ADDON")
commFrame:RegisterEvent("CHAT_MSG_ADDON_LOGGED")
commFrame:RegisterEvent("PLAYER_LOGIN")
commFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
commFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
commFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")

local function CommOnEvent(_, event, ...)
    if event == "GUILD_ROSTER_UPDATE" then
        rosterDirty = true
        return
    end

    if event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        local itemID, success = ...
        itemID = tonumber(itemID)
        if success and itemID then
            local db = CurrentDatabase()
            if not db then
                return
            end
            local key = tostring(itemID)
            local trackedEntry = type(db.items) == "table" and db.items[key] or nil
            local pendingItem = type(db.sync.pendingItems) == "table"
                and db.sync.pendingItems[key] ~= nil
            local pendingListing = HasPendingListingForItem(db, itemID)

            -- Globale Item-Cache-Events betreffen auch andere Addons und Tooltips.
            -- Nur bereits bekannte oder wartende GTC-Items duerfen in den Katalog.
            -- Vollstaendige Katalogeintraege nicht erneut verarbeiten (Scanner.lua
            -- ergaenzt fehlende Daten bereits beim selben Ereignis).
            local incomplete = type(trackedEntry) == "table" and (
                type(trackedEntry.bindType) ~= "number"
                or trackedEntry.bindUnverified == true
                or not trackedEntry.name
                or not trackedEntry.icon)
            if incomplete or pendingItem or pendingListing then
                GTC:UpdateItemMetadata(itemID)
            end

            if (pendingItem or pendingListing) and ProcessPendingSyncForItem then
                ProcessPendingSyncForItem(itemID)
            end
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        prefixRegistered = RegisterPrefix()

        if not prefixRegistered then
            GTC:Print(L("Sync-Präfix konnte nicht registriert werden."))
            return
        end

        if not supervisorTicker and C_Timer and type(C_Timer.NewTicker) == "function" then
            supervisorTicker = C_Timer.NewTicker(10, function()
                local ok, err = pcall(SupervisorTick)
                if not ok then
                    GTC:Log("ERR", "Supervisor: " .. tostring(err))
                end
            end)
        end

        After(2, function()
            if not IsGuildScope() then
                return
            end

            if C_GuildInfo and type(C_GuildInfo.GuildRoster) == "function" then
                pcall(C_GuildInfo.GuildRoster)
            elseif type(GuildRoster) == "function" then
                pcall(GuildRoster)
            end

            After(3, function()
                -- Begrenzt: Ohne Limit wurden beim Login fuer ALLE wartenden Items
                -- gleichzeitig Item-Daten beim Server angefragt. Der Rest folgt ueber
                -- den Supervisor (alle 30 s je 40 Items).
                if GTC.ProcessAllPendingSync then
                    GTC:ProcessAllPendingSync(100)
                end
                if GTC.StartGuildSync then
                    GTC:StartGuildSync()
                end
            end)
        end)

        return
    end

    if event ~= "CHAT_MSG_ADDON" and event ~= "CHAT_MSG_ADDON_LOGGED" then
        return
    end

    local prefix, message, channel, sender = ...

    -- Harte Kanalgrenze: kein WHISPER, PARTY, RAID, INSTANCE_CHAT oder
    -- anderer Kanal wird von GuildTradeCenter zur Synchronisierung genutzt.
    if prefix ~= PREFIX or channel ~= "GUILD" then
        return
    end

    if type(message) ~= "string" or #message > 255 then
        return
    end

    if IsSelf(sender) then
        return
    end

    if not IsCurrentGuildMember(sender) then
        sendStats.rxRejected = sendStats.rxRejected + 1
        local nowT = GetTime()
        if not rejectLogged[sender] or nowT - rejectLogged[sender] > 30 then
            rejectLogged[sender] = nowT
            GTC:Log("SYNC<", "ABGELEHNT (nicht in Gildenliste): " .. tostring(sender) .. " Roster=" .. tostring(next(rosterSet) and "geladen" or "leer"))
        end
        return
    end

    local db = CurrentDatabase()
    if not db or db.scopeType ~= "guild" then
        return
    end

    sendStats.rxAccepted = sendStats.rxAccepted + 1
    sendStats.lastRxAt = GetTime()

    local helloScope = message:match("^H|2|([A-Za-z0-9+/=]+)$")
    if helloScope then
        local ownScope = EncodeBase64(db.scopeKey)
        local sameScope = ownScope ~= nil and helloScope == ownScope
        if not sameScope then
            local decodeFn = GetEncodingFunction("DecodeBase64")
            if decodeFn then
                local okDecode, theirScope = pcall(decodeFn, helloScope)
                if okDecode and type(theirScope) == "string" then
                    sameScope = GTC:SameGuildScope(theirScope, db.scopeKey)
                    if not sameScope then
                        sendStats.rxScopeMismatch = (sendStats.rxScopeMismatch or 0) + 1
                        sendStats.lastScopeMismatch = SafeString(theirScope, 300)
                        GTC:Log("SYNC<", "HELLO von " .. tostring(sender)
                            .. " ignoriert: anderer Datenbereich " .. tostring(theirScope))
                    end
                end
            end
        end
        if sameScope then
            GTC:Log("SYNC<", "HELLO von " .. tostring(sender) .. ", Antwort geplant")
            helloReplyToken = helloReplyToken + 1
            local token = helloReplyToken
            local scheduledAt = GetTime()
            helloSender = sender
            After(2 + math.random() * 25, function()
                local theirSince = helloSinceBy[sender]
                local needFrom = (theirSince and theirSince > 0) and math.max(0, theirSince - 600) or 0
                if token ~= helloReplyToken
                    or (lastSnapshotSeenAt >= scheduledAt and lastSnapshotSeenSince <= needFrom) then
                    GTC:Log("SYNC", "HELLO-Antwort unterdrückt (anderer hat geantwortet)")
                    return
                end
                if theirSince and theirSince > 0 then
                    GTC:Log("SYNC>", "HELLO-Antwort: Delta seit " .. tostring(theirSince - 600))
                    ScheduleSnapshot(false, math.max(0, theirSince - 600))
                else
                    GTC:Log("SYNC>", "HELLO-Antwort: vollständiger Snapshot")
                    ScheduleSnapshot(true)
                end
            end)
        end
        return
    end

    if message:sub(1, 2) == "KQ" or message:sub(1, 2) == "KD" then
        HandleCatalogMessage(sender, message)
        return
    end

    local tSince = message:match("^T|2|(%d+)$")
    if tSince then
        helloSinceBy[sender] = tonumber(tSince)
        return
    end

    if message:match("^P|2|") then
        ReceiveChunk(sender, message)
    end
end

commFrame:SetScript("OnEvent", function(...)
    local ok, err = pcall(CommOnEvent, ...)
    if not ok then
        GTC:Log("ERR", "Comm: " .. tostring(err))
        geterrorhandler()(err)
    end
end)

function GTC:PrintSyncStatus()
    local db = CurrentDatabase()

    local function CountEntries(collection)
        local count = 0
        if type(collection) == "table" then
            for _ in pairs(collection) do
                count = count + 1
            end
        end
        return count
    end

    self:Print(L("===== GuildTradeCenter Sync-Status ====="))
    self:Print(L("Sync-Kanal: ausschließlich GUILD"))
    self:Print(L("Addon-Präfix registriert: ") .. tostring(prefixRegistered))
    self:Print(L("Gilden-Scope aktiv: ") .. tostring(IsGuildScope()))

    if not db then
        self:Print(L("Aktive Datenbank: NICHT VERFÜGBAR"))
        return
    end

    self:Print(L("Scope-Typ: ") .. tostring(db.scopeType))
    self:Print("Scope-Key: " .. tostring(db.scopeKey))
    self:Print(L("Abweichender Datenbereich verworfen: ") .. tostring(sendStats.rxScopeMismatch or 0)
        .. (sendStats.lastScopeMismatch and (L(" | zuletzt: ") .. sendStats.lastScopeMismatch) or ""))
    self:Print(L("Schema-Version: ") .. tostring(db.schemaVersion))
    self:Print(L("Item-Katalog: ") .. tostring(CountEntries(db.items)))
    self:Print(L("Inserate: ") .. tostring(CountEntries(db.listings)))
    self:Print(L("Löschmarkierungen: ") ..
        tostring(CountEntries(db.sync and db.sync.tombstones)))
    self:Print(L("Bekannte Sync-Peers: ") ..
        tostring(CountEntries(db.sync and db.sync.peers)))
    self:Print(L("Ausgehende Pakete: ") .. tostring(#outgoingQueue))
    self:Print(L("Zurückgestellte Item-Datensätze: ") .. tostring(CountEntries(db.sync and db.sync.pendingItems)))
    self:Print(L("Zurückgestellte Inserate: ") .. tostring(CountEntries(db.sync and db.sync.pendingListings)))
    self:Print(L("Letzter Merge: ") ..
        tostring(db.sync and db.sync.lastSync or 0))
    self:Print(L("Senden: ") .. tostring(sendStats.sent) .. L(" gesendet, ")
        .. tostring(sendStats.throttled) .. L(" gedrosselt, ")
        .. tostring(sendStats.lockdown) .. L(" gesperrt, ")
        .. tostring(sendStats.dropped) .. L(" verworfen | Rate ")
        .. string.format("%.2f", bucketRate) .. L("/s | letztes Ergebnis: ")
        .. tostring(sendStats.lastResult or "-"))
    local helloAge = helloSentAt and math.floor(GetTime() - helloSentAt) or nil
    self:Print(L("HELLO: ") .. tostring(helloAttempts) .. L("x gesendet, zuletzt ")
        .. (helloAge and (L("vor ") .. tostring(helloAge) .. " s") or "-")
        .. L(" | vollständige Snapshots empfangen: ") .. tostring(sendStats.rxSnapshots))
    local rxAge = sendStats.lastRxAt and math.floor(GetTime() - sendStats.lastRxAt) or nil
    self:Print(L("Empfangen: ") .. tostring(sendStats.rxAccepted) .. L(" Pakete von Mitgliedern, ")
        .. tostring(sendStats.rxRejected) .. L(" abgelehnt (nicht in Gildenliste) | letzter Empfang: ")
        .. (rxAge and (L("vor ") .. tostring(rxAge) .. " s") or "-"))
    local lastSent = tonumber(db.sync and db.sync.lastBroadcastAt) or 0
    self:Print(L("Letzter vollständig gesendeter Snapshot: ")
        .. (lastSent > 0 and date("%d.%m. %H:%M:%S", lastSent) or "-"))

    local encodingFunctions = {
        "SerializeCBOR",
        "DeserializeCBOR",
        "CompressString",
        "DecompressString",
        "EncodeBase64",
        "DecodeBase64",
    }

    local missing = {}
    for _, name in ipairs(encodingFunctions) do
        if not GetEncodingFunction(name) then
            table.insert(missing, name)
        end
    end

    if #missing == 0 then
        self:Print(L("Encoding-APIs: alle 6 vorhanden"))
    else
        self:Print(L("Fehlende Encoding-APIs: ") .. table.concat(missing, ", "))
    end

    local canSend = C_ChatInfo
        and (
            type(C_ChatInfo.SendAddonMessageLogged) == "function"
            or type(C_ChatInfo.SendAddonMessage) == "function"
        )

    self:Print("C_ChatInfo-Sendefunktion vorhanden: " .. tostring(not not canSend))

    local scopeState = (db and db.scopeType == "guild" and IsGuildScope())
        and L("Gilde aktiv") or "lokal"
    if type(self.SetWindowStatus) == "function" then
        self:SetWindowStatus(
            "Sync " .. scopeState ..
            " | Items " .. tostring(db and CountEntries(db.items) or 0) ..
            L(" | Inserate ") .. tostring(db and CountEntries(db.listings) or 0) ..
            " | Queue " .. tostring(#outgoingQueue)
        )
    end

    self:Print("========================================")
end

local function RunEncodingSelfTest()
    local serialize = GetEncodingFunction("SerializeCBOR")
    local compress = GetEncodingFunction("CompressString")
    local encode = GetEncodingFunction("EncodeBase64")

    if not serialize or not compress or not encode then
        GTC:Print(L("SELFTEST FEHLER: Encoding-API fehlt."))
        return false
    end

    local probe = {
        protocol = PROTOCOL,
        label = "GTC-selftest",
        count = 96,
        entries = {},
    }

    for i = 1, 96 do
        table.insert(probe.entries, {
            itemID = i * 173 + 123,
            quantity = (i % 7) + 1,
            name = "GTC-test-item-" .. tostring(i),
            description = "Payload-" .. tostring(i) .. "-" ..
                string.rep(string.char(65 + (i % 26)), (i % 13) + 2),
        })
    end
    local okRaw, rawData = pcall(serialize, probe)
    if not okRaw or type(rawData) ~= "string" then
        GTC:Print(L("SELFTEST FEHLER: CBOR-Serialisierung."))
        return false
    end

    local okCompressed, compressed = pcall(compress, rawData, compressionMethod)
    if not okCompressed or type(compressed) ~= "string" then
        GTC:Print(L("SELFTEST FEHLER: Kompression."))
        return false
    end

    local okEncoded, encoded = pcall(encode, compressed)
    if not okEncoded or type(encoded) ~= "string" then
        GTC:Print(L("SELFTEST FEHLER: Base64-Encoding."))
        return false
    end

    -- Den echten Decode-Pfad verwenden, aber nichts senden.
    local decoded, decodeError = DecodeSnapshot(encoded)
    if not decoded then
        GTC:Print(L("SELFTEST FEHLER: Rückweg: ") .. tostring(decodeError))
        return false
    end

    if decoded.protocol ~= PROTOCOL
        or decoded.label ~= probe.label
        or decoded.count ~= probe.count
        or type(decoded.entries) ~= "table"
        or #decoded.entries ~= 96
        or decoded.entries[52].itemID ~= (52 * 173 + 123)
        or decoded.entries[96].quantity ~= ((96 % 7) + 1) then
        GTC:Print(L("SELFTEST FEHLER: Datenvergleich nach Rückweg."))
        return false
    end

    -- Mehrpaket-Test: jedes Paket wie beim echten Guild-Sync aufbauen.
    local parts = {}
    local packetCount = math.ceil(#encoded / CHUNK_SIZE)

    if packetCount < 2 then
        GTC:Print(L("SELFTEST FEHLER: Testdaten erzeugten nicht mehrere Pakete."))
        return false
    end

    if packetCount > MAX_CHUNKS then
        GTC:Print(L("SELFTEST FEHLER: Zu viele Testpakete."))
        return false
    end

    local testID = "selftest-1234567890"
    local reassembledParts = {}

    for part = 1, packetCount do
        local first = ((part - 1) * CHUNK_SIZE) + 1
        local piece = encoded:sub(first, first + CHUNK_SIZE - 1)
        local packet = "P|2|" .. testID .. "|" .. part .. "|" ..
            packetCount .. "|" .. piece

        if #packet > 255 then
            GTC:Print(L("SELFTEST FEHLER: Paket größer als 255 Zeichen."))
            return false
        end

        local parsedID, parsedPart, parsedTotal, parsedPiece =
            packet:match("^P|2|([%w%-]+)|(%d+)|(%d+)|([A-Za-z0-9+/=]+)$")

        if parsedID ~= testID
            or tonumber(parsedPart) ~= part
            or tonumber(parsedTotal) ~= packetCount
            or parsedPiece ~= piece then
            GTC:Print(L("SELFTEST FEHLER: Paketformat oder Zerlegung."))
            return false
        end

        reassembledParts[part] = parsedPiece
        parts[part] = piece
    end

    local reassembled = table.concat(reassembledParts)
    if reassembled ~= encoded then
        GTC:Print(L("SELFTEST FEHLER: Segment-Reassembly."))
        return false
    end

    GTC:Print(L("SELFTEST OK: Paketformat und 255-Zeichen-Limit."))
    GTC:Print(L("SELFTEST OK: Segmentierung und Reassembly (") ..
        packetCount .. L(" Pakete)."))
    if type(GTC.SetWindowStatus) == "function" then
        GTC:SetWindowStatus(L("Sync-Selbsttest OK | ") .. packetCount .. L(" Paket(e)"))
    end

    GTC:Print(L("SELFTEST OK: CBOR, Kompression, Base64 und Rückweg."))
    GTC:Print(L("SELFTEST OK: Segmentierung und Reassembly (") .. packetCount .. L(" Paket(e))."))
    GTC:Print(L("SELFTEST: Es wurden keine Nachrichten gesendet."))
    return true
end
SLASH_GTC_SYNC1 = "/gtcsync"

SlashCmdList["GTC_SYNC"] = function(message)
    message = (message or ""):lower():match("^%s*(.-)%s*$")

    if message == "status" then
        GTC:PrintSyncStatus()
        return
    end

    if message == "selftest" then
        RunEncodingSelfTest()
        return
    end

    if message == "log" then
        GTC:HandleLogCommand("show")
        return
    end

    if message ~= "" and message ~= "start" then
        GTC:Print(L("Verwendung: /gtcsync | /gtcsync status | /gtcsync selftest"))
        return
    end

    if GTC.ManualSync then
        GTC:ManualSync()
    elseif GTC.StartGuildSync then
        GTC:StartGuildSync()
    end
end