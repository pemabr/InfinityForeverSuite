local addonName = ...
GuildTradeCenter = GuildTradeCenter or {}

local GTC = GuildTradeCenter
local L = GTC.T

local function ReadAddonVersion()
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        local ok, version = pcall(
            C_AddOns.GetAddOnMetadata,
            "GuildTradeCenter",
            "Version"
        )

        if ok and type(version) == "string" and version ~= "" then
            return version
        end
    end

    if type(GetAddOnMetadata) == "function" then
        local ok, version = pcall(
            GetAddOnMetadata,
            "GuildTradeCenter",
            "Version"
        )

        if ok and type(version) == "string" and version ~= "" then
            return version
        end
    end

    return "unbekannt"
end

GTC.version = ReadAddonVersion()

-- Gemeinsame Grenzwerte (Core, Comm, UI). Das Netzwerkformat bleibt unveraendert.
GTC.TOMBSTONE_RETENTION = 7 * 24 * 60 * 60     -- Loeschmarker so lange behalten (Inserate leben max. 72 h)
GTC.MAX_FUTURE_SKEW = 60 * 60                  -- Zeitstempel weiter in der Zukunft gelten als ungueltig
GTC.MAX_LISTING_LIFETIME = 73 * 60 * 60        -- max. Restlaufzeit eines Inserats (72 h + 1 h Toleranz)
GTC.MAX_ACTIVE_PER_CHARACTER = 50              -- aktive Inserate pro Charakter

-- Einheitliche Zeitbasis: Serverzeit statt PC-Uhr (beides Unix-Sekunden, daher
-- kompatibel mit Clients, die noch time() verwenden).
function GTC:Now()
    if type(GetServerTime) == "function" then
        local ok, serverTime = pcall(GetServerTime)
        if ok and type(serverTime) == "number" and serverTime > 0 then
            return serverTime
        end
    end
    return time()
end

-- Diagnose-Protokoll (Ringpuffer in den SavedVariables, ueberlebt /reload).
-- Befehle: /gtc log [show|clear|on|off]
local LOG_MAX = 600

function GTC:Log(tag, message)
    local root = GuildTradeCenterDB
    if type(root) ~= "table" or root.logEnabled == false then
        return
    end

    local log = root.debugLog
    if type(log) ~= "table" then
        log = {}
        root.debugLog = log
    end

    local stamp = (type(date) == "function" and date("%H:%M:%S")) or tostring(time())
    log[#log + 1] = string.format("%s %-5s %s", stamp, tostring(tag), tostring(message))
    -- In Bloecken kuerzen: table.remove(log, 1) verschob bei jedem Eintrag alle 600 Zeilen.
    local count = #log
    if count > LOG_MAX + 100 then
        local drop = count - LOG_MAX
        for index = 1, LOG_MAX do
            log[index] = log[index + drop]
        end
        for index = LOG_MAX + 1, count do
            log[index] = nil
        end
    end
end

-- Voller Charaktername: Vorname plus Nachname/Zusatz, so wie ihn das Spiel in Gildenliste und
-- Chat anzeigt (GetUnitName mit showServerName). UnitName() liefert dort nur den Vornamen.
-- Das ist dasselbe Format wie die Namen aus der Gildenliste und der Addon-Kommunikation,
-- damit Fluestern und Zuordnung eindeutig sind.
function GTC:GetFullPlayerName()
    local full
    if type(GetUnitName) == "function" then
        full = GetUnitName("player", true)
    end
    if type(full) ~= "string" or full == "" then
        full = UnitName("player") or L("Unbekannt")
    end
    if type(Ambiguate) == "function" then
        full = Ambiguate(full, "none")
    end
    return full
end

-- Zerlegt einen Namen in Vorname und Rest (Nachname bzw. Realm, getrennt durch Leerzeichen
-- oder Bindestrich).
local function SplitCharacterName(name)
    local first, rest = tostring(name):match("^([^%s%-]+)[%s%-]*(.*)$")
    return first, rest or ""
end

-- Vergleicht zwei Charakternamen. Fehlt bei einem der beiden der Nachname (Altdaten mit nur
-- dem Vornamen), genuegt die Uebereinstimmung des Vornamens.
function GTC:SameCharacter(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then
        return false
    end
    if a == b then
        return true
    end
    local firstA, restA = SplitCharacterName(a)
    local firstB, restB = SplitCharacterName(b)
    if firstA ~= firstB then
        return false
    end
    if restA ~= "" and restB ~= "" then
        return restA == restB
    end
    return true
end
-- Eigene Inserate aus aelteren Versionen (nur Vorname) auf den vollen Namen anheben.
function GTC:UpgradeOwnListingNames()
    local db = self.db
    if type(db) ~= "table" or type(db.listings) ~= "table" then
        return
    end
    local short = UnitName("player")
    local full = self:GetFullPlayerName()
    if not short or full == short then
        return
    end
    local upgraded = 0
    for _, entry in ipairs(db.listings) do
        if type(entry) == "table" and entry.character == short then
            entry.character = full
            entry.updatedAt = GTC:Now()
            entry.revision = (tonumber(entry.revision) or 0) + 1
            upgraded = upgraded + 1
        end
    end
    if upgraded > 0 then
        self:Log("INFO", upgraded .. " eigene Inserate auf vollen Namen " .. full .. " angehoben")
        if type(self.ScheduleGuildSync) == "function" then
            self:ScheduleGuildSync()
        end
    end
end

function GTC:HandleLogCommand(arg)
    local root = GuildTradeCenterDB
    if type(root) ~= "table" then
        return
    end

    if arg == "clear" then
        root.debugLog = {}
        self:Print(L("Protokoll geleert."))
    elseif arg == "on" then
        root.logEnabled = true
        self:Print(L("Protokoll aktiviert."))
    elseif arg == "off" then
        root.logEnabled = false
        self:Print(L("Protokoll deaktiviert."))
    else
        local log = root.debugLog or {}
        self:Print(L("Protokoll: ") .. #log .. L(" Einträge (zeige die letzten 25). Alles: nach /reload in der Datei SavedVariables\\GuildTradeCenter.lua unter debugLog."))
        for index = math.max(1, #log - 24), #log do
            print("|cff8a8a8a" .. log[index] .. "|r")
        end
    end
end
GTC.testMode = false

-- Hilfsfunktionen fuer eine verlustbewusste Schema-Migration.
local function GTCMigrationDeepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}

    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy

    for key, child in pairs(value) do
        copy[GTCMigrationDeepCopy(key, seen)] =
            GTCMigrationDeepCopy(child, seen)
    end

    return copy
end

local function GTCMigrationEqual(a, b, seen)
    if a == b then
        return true
    end

    if type(a) ~= type(b) then
        return false
    end

    if type(a) ~= "table" then
        return false
    end

    seen = seen or {}

    if seen[a] ~= nil then
        return seen[a] == b
    end

    seen[a] = b

    for key, value in pairs(a) do
        if not GTCMigrationEqual(value, b[key], seen) then
            return false
        end
    end

    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end

    return true
end

local function GTCMigrationOrderedKeys(tbl)
    local numericKeys = {}
    local otherKeys = {}

    for key in pairs(tbl) do
        if type(key) == "number"
            and key >= 1
            and key % 1 == 0 then
            table.insert(numericKeys, key)
        else
            table.insert(otherKeys, key)
        end
    end

    table.sort(numericKeys)

    table.sort(otherKeys, function(a, b)
        local typeA = type(a)
        local typeB = type(b)

        if typeA == typeB then
            return tostring(a) < tostring(b)
        end

        return typeA < typeB
    end)

    local keys = {}

    for _, key in ipairs(numericKeys) do
        table.insert(keys, key)
    end

    for _, key in ipairs(otherKeys) do
        table.insert(keys, key)
    end

    return keys
end

local function GTCMigrationStoreRecovery(root, bucketName, record)
    if type(root.migrationRecovery) ~= "table" then
        local oldRecovery = root.migrationRecovery

        root.migrationRecovery = {}

        if oldRecovery ~= nil then
            root.migrationRecovery.invalidRecoveryContainer = oldRecovery
        end
    end

    local recovery = root.migrationRecovery
    local bucket = recovery[bucketName]

    if type(bucket) ~= "table" then
        local oldBucket = bucket

        bucket = {}
        recovery[bucketName] = bucket

        if oldBucket ~= nil then
            bucket[1] = {
                reason = "invalid-existing-recovery-bucket",
                value = oldBucket,
            }
        end
    end

    local highestIndex = 0

    for key in pairs(bucket) do
        if type(key) == "number"
            and key >= 1
            and key % 1 == 0
            and key > highestIndex then
            highestIndex = key
        end
    end

    bucket[highestIndex + 1] = record
end

local function GTCMigrationNormalizeListings(root, source, scopeKey, sourceName)
    if type(source) ~= "table" then
        if source ~= nil then
            GTCMigrationStoreRecovery(root, "invalidTableFields", {
                reason = "expected-listing-table",
                scopeKey = scopeKey,
                field = sourceName,
                value = GTCMigrationDeepCopy(source),
            })
        end

        return {}
    end

    local normalized = {}

    for _, key in ipairs(GTCMigrationOrderedKeys(source)) do
        local value = source[key]

        if type(value) == "table" then
            table.insert(normalized, GTCMigrationDeepCopy(value))
        else
            GTCMigrationStoreRecovery(root, "invalidListingEntries", {
                reason = "non-table-listing",
                scopeKey = scopeKey,
                sourceKey = key,
                value = GTCMigrationDeepCopy(value),
            })
        end
    end

    return normalized
end

local function GTCMigrationIsDenseListings(source)
    if type(source) ~= "table" then
        return false
    end

    local count = 0
    local highest = 0

    for key, value in pairs(source) do
        if type(key) ~= "number"
            or key < 1
            or key % 1 ~= 0
            or type(value) ~= "table" then
            return false
        end

        count = count + 1

        if key > highest then
            highest = key
        end
    end

    return highest == count
end

-- v1.1.5: Realm-unabhaengiger Vergleich von Gilden-Datenbereichen.
-- WoW Forever kennt keine festen Realms mehr; GetRealmName() kann fuer Mitglieder derselben
-- Gilde unterschiedliche Texte liefern. Der Schluessel "guild:<Gilde>@<Realm>:<Fraktion>"
-- bleibt im Netzwerkformat unveraendert (Kompatibilitaet zu v1.0.0), beim Vergleich zaehlen
-- aber nur Gildenname und Fraktion. Sicherheit kostet das nicht: Der Sync laeuft
-- ausschliesslich ueber den GUILD-Kanal und Absender werden gegen die Gildenliste geprueft.
local function ParseGuildScopeKey(key)
    if type(key) ~= "string" then
        return nil
    end
    -- Gildennamen enthalten kein "@"; die Fraktion ist das letzte ":"-Segment.
    local guild, faction = key:match("^guild:(.-)@.*:([^:]*)$")
    if not guild or guild == "" then
        return nil
    end
    return string.lower(guild), string.lower(faction or "")
end

GTC.ParseGuildScopeKey = ParseGuildScopeKey

function GTC:SameGuildScope(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then
        return false
    end
    if a == b then
        return true
    end
    local guildA, factionA = ParseGuildScopeKey(a)
    local guildB, factionB = ParseGuildScopeKey(b)
    return guildA ~= nil and guildB ~= nil
        and guildA == guildB and factionA == factionB
end

-- Wechselt der gemeldete Realm (z. B. anderer Layer/Login), entstuende sonst ein neuer, leerer
-- Datenbereich. Stattdessen wird ein vorhandener Bereich derselben Gilde/Fraktion
-- uebernommen und auf den aktuellen Schluessel umgestellt.
local function AdoptGuildScope(root, scopeKey)
    if type(root.scopes) ~= "table" or root.scopes[scopeKey] ~= nil then
        return
    end
    if not ParseGuildScopeKey(scopeKey) then
        return
    end

    local bestKey, best, bestRev = nil, nil, -1
    for key, value in pairs(root.scopes) do
        if key ~= scopeKey and type(value) == "table" and GTC:SameGuildScope(key, scopeKey) then
            local rev = type(value.sync) == "table" and tonumber(value.sync.revision) or 0
            if rev > bestRev then
                bestKey, best, bestRev = key, value, rev
            end
        end
    end
    if not best then
        return
    end

    root.scopes[scopeKey] = best
    root.scopes[bestKey] = nil
    best.scopeKey = scopeKey
    if type(best.sync) == "table" then
        for _, bucketName in ipairs({ "tombstones", "pendingListings" }) do
            local bucket = best.sync[bucketName]
            if type(bucket) == "table" then
                for _, record in pairs(bucket) do
                    if type(record) == "table" then
                        record.scopeKey = scopeKey
                    end
                end
            end
        end
    end
    GTC:Log("SCOPE", "Datenbereich uebernommen: " .. tostring(bestKey) .. " -> " .. tostring(scopeKey))
end

local function InitializeDatabase(force)
    local rawRoot = GuildTradeCenterDB

    -- Auch ein unerwarteter Root-Datentyp wird nicht kommentarlos
    -- verworfen: Der urspruengliche Wert bleibt erhalten.
    if type(rawRoot) ~= "table" then
        local replacement = {}

        if rawRoot ~= nil then
            replacement.migrationRecovery = {
                invalidRootDatabase = rawRoot,
            }
        end

        GuildTradeCenterDB = replacement
    end

    local root = GuildTradeCenterDB

    local guildName
    if type(GetGuildInfo) == "function" then
        guildName = GetGuildInfo("player")
    end

    local realmName
    if type(GetNormalizedRealmName) == "function" then
        realmName = GetNormalizedRealmName()
    end

    if not realmName or realmName == "" then
        if type(GetRealmName) == "function" then
            realmName = GetRealmName()
        end
    end

    realmName = realmName or "UnknownRealm"

    local faction
    if type(UnitFactionGroup) == "function" then
        faction = UnitFactionGroup("player")
    end
    faction = faction or "UnknownFaction"

    local playerName
    if type(UnitName) == "function" then
        playerName = UnitName("player")
    end
    playerName = playerName or "UnknownPlayer"

    -- GetGuildInfo liefert kurzzeitig nil (Ladebildschirm, Instanzwechsel), obwohl der
    -- Spieler in der Gilde ist. Ohne diese Absicherung wechselte die 60-s-Pruefung dann in
    -- den persoenlichen Bereich: Liste leer, Sync-Warteschlange verworfen.
    if (not guildName or guildName == "")
        and type(IsInGuild) == "function" and IsInGuild()
        and type(GTC.db) == "table" and GTC.db.scopeType == "guild"
        and type(GTC.db.guildName) == "string" and GTC.db.guildName ~= ""
        and GTC.db.faction == faction then
        guildName = GTC.db.guildName
    end

    local scopeType
    local scopeKey

    if guildName and guildName ~= "" then
        scopeType = "guild"
        scopeKey = "guild:" .. guildName .. "@" .. realmName .. ":" .. faction
    else
        scopeType = "personal"
        scopeKey = "personal:" .. playerName .. "@" .. realmName .. ":" .. faction
    end

    -- Schnellpfad: Der Datenbereich wurde bereits geprueft und der Bereich
    -- (Gilde/Realm/Fraktion) hat sich nicht geaendert. Die vollstaendige
    -- Validierung laeuft nur beim Login und alle 60 Sekunden (force).
    if not force and GTC.db and GTC.activeScopeKey == scopeKey
        and type(root.scopes) == "table" and root.scopes[scopeKey] == GTC.db then
        return GTC.db
    end

    -- Fehlerhafte Scopes werden vor dem Ersetzen gesichert.
    if type(root.scopes) ~= "table" then
        local invalidScopes = root.scopes

        if invalidScopes ~= nil then
            GTCMigrationStoreRecovery(root, "invalidRootScopes", {
                reason = "root-scopes-was-not-a-table",
                value = GTCMigrationDeepCopy(invalidScopes),
            })
        end

        root.scopes = {}
    end

    local rawSchemaVersion = root.schemaVersion
    local schemaVersion = tonumber(rawSchemaVersion) or 0

    if rawSchemaVersion ~= nil and tonumber(rawSchemaVersion) == nil then
        GTCMigrationStoreRecovery(root, "invalidSchemaVersions", {
            reason = "schema-version-not-numeric",
            value = GTCMigrationDeepCopy(rawSchemaVersion),
        })
    end

    -- Auch vorhandene Legacy-Felder muessen migriert werden, selbst wenn
    -- ein inkonsistenter Root bereits schemaVersion 2 behauptet.
    local hasLegacy = root.listings ~= nil
        or root.items ~= nil
        or root.nextListingId ~= nil

    local migrationWarnings = 0

    if schemaVersion < 2 or hasLegacy then
        -- Nur die Arbeitskopie der Scopes wird waehrend der Migration
        -- bearbeitet. Die aktiven Scopes werden erst danach ersetzt.
        local stagedScopes = GTCMigrationDeepCopy(root.scopes)
        local migrated = stagedScopes[scopeKey]

        if type(migrated) ~= "table" then
            if migrated ~= nil then
                GTCMigrationStoreRecovery(root, "invalidScopeValues", {
                    reason = "active-scope-was-not-a-table",
                    scopeKey = scopeKey,
                    value = GTCMigrationDeepCopy(migrated),
                })

                migrationWarnings = migrationWarnings + 1
            end

            migrated = {}
        end

        migrated.listings = GTCMigrationNormalizeListings(
            root,
            migrated.listings,
            scopeKey,
            "existing-scope-listings"
        )

        if type(migrated.items) ~= "table" then
            if migrated.items ~= nil then
                GTCMigrationStoreRecovery(root, "invalidTableFields", {
                    reason = "expected-items-table",
                    scopeKey = scopeKey,
                    field = "existing-scope-items",
                    value = GTCMigrationDeepCopy(migrated.items),
                })

                migrationWarnings = migrationWarnings + 1
            end

            migrated.items = {}
        end

        -- Nicht verwendbare Werte im Ziel-Item-Katalog sichern.
        for itemKey, itemValue in pairs(migrated.items) do
            if type(itemValue) ~= "table" then
                GTCMigrationStoreRecovery(root, "invalidItemEntries", {
                    reason = "non-table-existing-item",
                    scopeKey = scopeKey,
                    itemKey = itemKey,
                    value = GTCMigrationDeepCopy(itemValue),
                })

                migrated.items[itemKey] = nil
                migrationWarnings = migrationWarnings + 1
            end
        end

        local knownById = {}

        for _, existing in pairs(migrated.listings) do
            if type(existing) == "table" and existing.id ~= nil then
                local id = tostring(existing.id)

                if knownById[id] == nil then
                    knownById[id] = existing
                end
            end
        end

        -- Wichtig: pairs/OrderedKeys statt ipairs. Luecken in alten
        -- Angebotslisten duerfen keine spaeteren Eintraege verschlucken.
        if type(root.listings) == "table" then
            for _, legacyKey in ipairs(GTCMigrationOrderedKeys(root.listings)) do
                local legacy = root.listings[legacyKey]

                if type(legacy) ~= "table" then
                    GTCMigrationStoreRecovery(root, "invalidLegacyListings", {
                        reason = "legacy-listing-was-not-a-table",
                        sourceKey = legacyKey,
                        value = GTCMigrationDeepCopy(legacy),
                    })

                    migrationWarnings = migrationWarnings + 1
                else
                    local id = legacy.id ~= nil and tostring(legacy.id) or nil
                    local existing = id and knownById[id] or nil

                    if not existing then
                        local copied = GTCMigrationDeepCopy(legacy)

                        table.insert(migrated.listings, copied)

                        if id then
                            knownById[id] = copied
                        end
                    else
                        -- Nie stillschweigend verwerfen: selbst bei einer
                        -- ID-Kollision bleibt die alte Version gesichert.
                        local identical = GTCMigrationEqual(existing, legacy)

                        GTCMigrationStoreRecovery(
                            root,
                            identical
                                and "duplicateLegacyListings"
                                or "conflictingLegacyListings",
                            {
                                reason = identical
                                    and "identical-duplicate-preserved"
                                    or "duplicate-id-conflicting-content",
                                scopeKey = scopeKey,
                                sourceKey = legacyKey,
                                originalId = id,
                                entry = GTCMigrationDeepCopy(legacy),
                                existingEntry = GTCMigrationDeepCopy(existing),
                            }
                        )

                        if not identical then
                            migrationWarnings = migrationWarnings + 1
                        end
                    end
                end
            end
        elseif root.listings ~= nil then
            GTCMigrationStoreRecovery(root, "invalidLegacyListings", {
                reason = "legacy-listings-was-not-a-table",
                value = GTCMigrationDeepCopy(root.listings),
            })

            migrationWarnings = migrationWarnings + 1
        end

        if type(root.items) == "table" then
            for _, itemKey in ipairs(GTCMigrationOrderedKeys(root.items)) do
                local legacyItem = root.items[itemKey]
                local existingItem = migrated.items[itemKey]

                if type(legacyItem) ~= "table" then
                    GTCMigrationStoreRecovery(root, "invalidLegacyItems", {
                        reason = "legacy-item-was-not-a-table",
                        itemKey = itemKey,
                        value = GTCMigrationDeepCopy(legacyItem),
                    })

                    migrationWarnings = migrationWarnings + 1
                elseif existingItem == nil then
                    migrated.items[itemKey] = GTCMigrationDeepCopy(legacyItem)
                else
                    local identical = GTCMigrationEqual(existingItem, legacyItem)

                    GTCMigrationStoreRecovery(
                        root,
                        identical
                            and "duplicateLegacyItems"
                            or "conflictingLegacyItems",
                        {
                            reason = identical
                                and "identical-duplicate-preserved"
                                or "duplicate-item-key-conflicting-content",
                            scopeKey = scopeKey,
                            itemKey = itemKey,
                            value = GTCMigrationDeepCopy(legacyItem),
                            existingValue = GTCMigrationDeepCopy(existingItem),
                        }
                    )

                    if not identical then
                        migrationWarnings = migrationWarnings + 1
                    end
                end
            end
        elseif root.items ~= nil then
            GTCMigrationStoreRecovery(root, "invalidLegacyItems", {
                reason = "legacy-items-was-not-a-table",
                value = GTCMigrationDeepCopy(root.items),
            })

            migrationWarnings = migrationWarnings + 1
        end

        local oldNextId = tonumber(root.nextListingId) or 0
        local scopedNextId = tonumber(migrated.nextListingId) or 0

        if root.nextListingId ~= nil and tonumber(root.nextListingId) == nil then
            GTCMigrationStoreRecovery(root, "invalidScalarFields", {
                reason = "legacy-nextListingId-was-not-numeric",
                value = GTCMigrationDeepCopy(root.nextListingId),
            })

            migrationWarnings = migrationWarnings + 1
        end

        if migrated.nextListingId ~= nil
            and tonumber(migrated.nextListingId) == nil then
            GTCMigrationStoreRecovery(root, "invalidScalarFields", {
                reason = "scoped-nextListingId-was-not-numeric",
                scopeKey = scopeKey,
                value = GTCMigrationDeepCopy(migrated.nextListingId),
            })

            migrationWarnings = migrationWarnings + 1
        end

        migrated.nextListingId = math.max(scopedNextId, oldNextId)
        stagedScopes[scopeKey] = migrated

        -- Commit: Die neue Struktur wird erst nach dem Kopieren und
        -- Sichern der Konflikte aktiv. Alte Felder werden zuletzt entfernt.
        root.scopes = stagedScopes
        root.listings = nil
        root.items = nil
        root.nextListingId = nil
        root.schemaVersion = 2
    else
        root.schemaVersion = 2
    end

    if scopeType == "guild" then
        AdoptGuildScope(root, scopeKey)
    end

    local db = root.scopes[scopeKey]

    if type(db) ~= "table" then
        if db ~= nil then
            GTCMigrationStoreRecovery(root, "invalidScopeValues", {
                reason = "active-scope-was-not-a-table",
                scopeKey = scopeKey,
                value = GTCMigrationDeepCopy(db),
            })

            migrationWarnings = migrationWarnings + 1
        end

        db = {}
        root.scopes[scopeKey] = db
    end

    if type(db.listings) ~= "table" then
        if db.listings ~= nil then
            GTCMigrationStoreRecovery(root, "invalidTableFields", {
                reason = "active-listings-was-not-a-table",
                scopeKey = scopeKey,
                value = GTCMigrationDeepCopy(db.listings),
            })

            migrationWarnings = migrationWarnings + 1
        end

        db.listings = {}
    elseif not GTCMigrationIsDenseListings(db.listings) then
        db.listings = GTCMigrationNormalizeListings(
            root,
            db.listings,
            scopeKey,
            "active-scope-listings"
        )

        migrationWarnings = migrationWarnings + 1
    end

    if type(db.items) ~= "table" then
        if db.items ~= nil then
            GTCMigrationStoreRecovery(root, "invalidTableFields", {
                reason = "active-items-was-not-a-table",
                scopeKey = scopeKey,
                value = GTCMigrationDeepCopy(db.items),
            })

            migrationWarnings = migrationWarnings + 1
        end

        db.items = {}
    end

    for itemKey, itemValue in pairs(db.items) do
        if type(itemValue) ~= "table" then
            GTCMigrationStoreRecovery(root, "invalidItemEntries", {
                reason = "active-item-was-not-a-table",
                scopeKey = scopeKey,
                itemKey = itemKey,
                value = GTCMigrationDeepCopy(itemValue),
            })

            db.items[itemKey] = nil
            migrationWarnings = migrationWarnings + 1
        end
    end

    local parsedNextId = tonumber(db.nextListingId)

    if db.nextListingId ~= nil and parsedNextId == nil then
        GTCMigrationStoreRecovery(root, "invalidScalarFields", {
            reason = "active-nextListingId-was-not-numeric",
            scopeKey = scopeKey,
            value = GTCMigrationDeepCopy(db.nextListingId),
        })

        migrationWarnings = migrationWarnings + 1
    end

    db.nextListingId = parsedNextId or 0
    db.schemaVersion = 2
    db.scopeKey = scopeKey
    db.scopeType = scopeType
    db.guildName = (scopeType == "guild") and guildName or nil
    db.realm = realmName
    db.faction = faction

    if type(db.sync) ~= "table" then
        if db.sync ~= nil then
            GTCMigrationStoreRecovery(root, "invalidSyncFields", {
                reason = "sync-was-not-a-table",
                scopeKey = scopeKey,
                value = GTCMigrationDeepCopy(db.sync),
            })

            migrationWarnings = migrationWarnings + 1
        end

        db.sync = {}
    end

    if type(db.sync.peers) ~= "table" then
        if db.sync.peers ~= nil then
            GTCMigrationStoreRecovery(root, "invalidSyncFields", {
                reason = "peers-was-not-a-table",
                scopeKey = scopeKey,
                value = GTCMigrationDeepCopy(db.sync.peers),
            })

            migrationWarnings = migrationWarnings + 1
        end

        db.sync.peers = {}
    end

    if type(db.sync.tombstones) ~= "table" then
        if db.sync.tombstones ~= nil then
            GTCMigrationStoreRecovery(root, "invalidSyncFields", {
                reason = "tombstones-was-not-a-table",
                scopeKey = scopeKey,
                value = GTCMigrationDeepCopy(db.sync.tombstones),
            })

            migrationWarnings = migrationWarnings + 1
        end

        db.sync.tombstones = {}
    end

    local parsedRevision = tonumber(db.sync.revision)

    if db.sync.revision ~= nil and parsedRevision == nil then
        GTCMigrationStoreRecovery(root, "invalidSyncFields", {
            reason = "revision-was-not-numeric",
            scopeKey = scopeKey,
            value = GTCMigrationDeepCopy(db.sync.revision),
        })

        migrationWarnings = migrationWarnings + 1
    end

    db.sync.revision = parsedRevision or 0

    local parsedLastSync = tonumber(db.sync.lastSync)

    if db.sync.lastSync ~= nil and parsedLastSync == nil then
        GTCMigrationStoreRecovery(root, "invalidSyncFields", {
            reason = "lastSync-was-not-numeric",
            scopeKey = scopeKey,
            value = GTCMigrationDeepCopy(db.sync.lastSync),
        })

        migrationWarnings = migrationWarnings + 1
    end

    db.sync.lastSync = parsedLastSync or 0

    root.testMode = false
    GTC.testMode = false
    root.schemaVersion = 2
    root.version = GTC.version
    root.activeScopeKey = scopeKey

    local now = GTC:Now()
    local expiredRemoved = false

    for i = #db.listings, 1, -1 do
        local entry = db.listings[i]

        if entry then
            if not entry.id then
                db.nextListingId = db.nextListingId + 1
                entry.id = "gtc-" .. realmName .. "-" .. playerName .. "-"
                    .. tostring(now) .. "-" .. tostring(db.nextListingId)
            end

            local parsedCreatedAt = tonumber(entry.createdAt)

            if parsedCreatedAt == nil then
                if entry.createdAt ~= nil then
                    GTCMigrationStoreRecovery(root, "invalidListingFields", {
                        reason = "createdAt-was-not-numeric",
                        scopeKey = scopeKey,
                        id = tostring(entry.id),
                        value = GTCMigrationDeepCopy(entry.createdAt),
                    })

                    migrationWarnings = migrationWarnings + 1
                end

                parsedCreatedAt = now
            end

            entry.createdAt = parsedCreatedAt

            local parsedExpiresAt = tonumber(entry.expiresAt)

            if parsedExpiresAt == nil then
                if entry.expiresAt ~= nil then
                    GTCMigrationStoreRecovery(root, "invalidListingFields", {
                        reason = "expiresAt-was-not-numeric",
                        scopeKey = scopeKey,
                        id = tostring(entry.id),
                        value = GTCMigrationDeepCopy(entry.expiresAt),
                    })

                    migrationWarnings = migrationWarnings + 1
                end

                parsedExpiresAt = entry.createdAt + (72 * 60 * 60)
            end

            entry.expiresAt = parsedExpiresAt
            entry.scopeKey = scopeKey

            local parsedUpdatedAt = tonumber(entry.updatedAt)
            if entry.updatedAt ~= nil and parsedUpdatedAt == nil then
                GTCMigrationStoreRecovery(root, "invalidListingFields", {
                    reason = "updatedAt-was-not-numeric",
                    scopeKey = scopeKey,
                    id = tostring(entry.id),
                    value = GTCMigrationDeepCopy(entry.updatedAt),
                })

                migrationWarnings = migrationWarnings + 1
            end

            entry.updatedAt = parsedUpdatedAt or entry.createdAt
            entry.revision = tonumber(entry.revision) or 1
            entry.syncRevision = tonumber(entry.syncRevision) or 0

            if entry.expiresAt <= now then
                db.sync.revision = db.sync.revision + 1

                db.sync.tombstones[tostring(entry.id)] = {
                    id = entry.id,
                    scopeKey = scopeKey,
                    deletedAt = now,
                    deletedBy = "expiry",
                    revision = db.sync.revision,
                }

                table.remove(db.listings, i)
                expiredRemoved = true
            end
        end
    end

    -- Loeschmarker muessen nur so lange leben wie ein Inserat leben kann. Aeltere sowie
    -- unsinnig in die Zukunft datierte Marker werden entfernt (Wachstum, Sync-Limit,
    -- gefaelschte Marker).
    if type(db.sync.tombstones) == "table" then
        local oldest = now - GTC.TOMBSTONE_RETENTION
        local newest = now + GTC.MAX_FUTURE_SKEW
        for tombstoneID, tombstone in pairs(db.sync.tombstones) do
            local deletedAt = type(tombstone) == "table" and tonumber(tombstone.deletedAt) or nil
            if not deletedAt or deletedAt < oldest or deletedAt > newest then
                db.sync.tombstones[tombstoneID] = nil
            end
        end
    end

    GTC.db = db
    GTC.activeScopeKey = scopeKey

    if migrationWarnings > 0 then
        GTC:Print(
            L("WARNUNG: Bei der Datenprüfung wurden ") ..
            tostring(migrationWarnings) ..
            L(" auffällige Werte gesichert. Details: migrationRecovery. ") ..
            L("Bitte vor weiteren Migrationen prüfen.")
        )
    end

    if expiredRemoved then
        if type(GTC.ScheduleGuildSync) == "function" then
            GTC:ScheduleGuildSync()
        end

        if type(GTC.RefreshListingView) == "function" then
            GTC:RefreshListingView()
        end
    end

    return db
end

-- Oeffentlicher, schneller Zugriff auf den aktiven Datenbereich.
function GTC:EnsureDB()
    return InitializeDatabase()
end

function GTC:RememberItem(itemLink)
    local db = InitializeDatabase()

    if type(itemLink) ~= "string" then
        return false, L("Kein Item-Link")
    end

    local itemID = itemLink:match("item:(%d+)")
    if not itemID then
        return false, L("Keine Item-ID gefunden")
    end

    local items = db.items
    local entry = items[itemID] or {
        itemID = tonumber(itemID),
        firstSeen = time()
    }

    local name = itemLink:match("|h%[(.-)%]|h")
    if name and name ~= "" then
        entry.name = name
    end

    entry.itemLink = itemLink
    entry.lastSeen = time()
    db.sync.revision = db.sync.revision + 1
    entry.updatedAt = entry.lastSeen
    entry.revision = (tonumber(entry.revision) or 0) + 1
    entry.syncRevision = db.sync.revision
    entry.scopeKey = db.scopeKey
    items[itemID] = entry

    -- Katalogaenderungen werden nicht mehr automatisch synchronisiert (nur auf Knopfdruck).
    return true, itemID
end
local itemBindingLoadRequests = {}

local function RequestItemBindingData(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return
    end

    local key = tostring(itemID)
    local now = (type(GetTime) == "function") and GetTime() or time()
    local previous = itemBindingLoadRequests[key]
    if previous and (now - previous) < 3 then
        return
    end
    itemBindingLoadRequests[key] = now

    -- Explizite asynchrone Anfrage; Forever meldet die Antwort via
    -- ITEM_DATA_LOAD_RESULT. GetItemInfo kann zusaetzlich GET_ITEM_INFO_RECEIVED ausloesen.
    if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end

    if C_Item and type(C_Item.GetItemInfo) == "function" then
        pcall(C_Item.GetItemInfo, itemID)
    end
end

-- quiet = true: nur lokale Metadaten ergaenzen (z. B. beim Verarbeiten eines Syncs), ohne
-- den Datensatz als "geaendert" zu markieren. Sonst wuerden empfangene Items sofort wieder
-- an alle zurueckgesendet (Echo).
function GTC:UpdateItemMetadata(itemID, quiet)
    itemID = tonumber(itemID)
    if not itemID or itemID < 1 then
        return false, L("Ungültige Item-ID")
    end

    local db = self.db
    if type(db) ~= "table" or type(db.items) ~= "table" or type(db.sync) ~= "table" then
        db = InitializeDatabase()
    end

    if not C_Item or type(C_Item.GetItemInfo) ~= "function" then
        return false, L("C_Item.GetItemInfo ist nicht verfügbar")
    end

    -- bindType ist der 14. Rueckgabewert. Die Variablen fuer 11-13 muessen
    -- mit aufgenommen werden, sonst wuerde der falsche Wert gespeichert.
    local callOK, name, link, quality, itemLevel, reqLevel, itemType, itemSubType,
        stackCount, equipLoc, icon, sellPrice, classID, subclassID, bindType =
        pcall(C_Item.GetItemInfo, itemID)

    if not callOK or type(name) ~= "string" or type(bindType) ~= "number" then
        RequestItemBindingData(itemID)
        return false, L("Item-Daten noch nicht vollständig verfügbar")
    end

    local key = tostring(itemID)
    local entry = db.items[key]
    local changed = type(entry) ~= "table"

    -- Vorlaeufig aus einem Sync uebernommener Eintrag (Bindung noch nicht lokal geprueft).
    local wasUnverified = type(entry) == "table" and entry.bindUnverified == true

    if type(entry) ~= "table" then
        entry = {
            itemID = itemID,
            firstSeen = time(),
        }
    end

    if entry.name ~= name then changed = true end
    if type(link) == "string" and entry.itemLink ~= link then changed = true end
    if quality ~= nil and entry.quality ~= quality then changed = true end
    if itemType ~= nil and entry.itemType ~= itemType then changed = true end
    if itemSubType ~= nil and entry.itemSubType ~= itemSubType then changed = true end
    if icon ~= nil and entry.icon ~= icon then changed = true end
    if entry.bindType ~= bindType then changed = true end
    if entry.scopeKey ~= db.scopeKey then changed = true end

    entry.name = name
    if type(link) == "string" then entry.itemLink = link end
    if quality ~= nil then entry.quality = quality end
    if itemType ~= nil then entry.itemType = itemType end
    if itemSubType ~= nil then entry.itemSubType = itemSubType end
    if icon ~= nil then entry.icon = icon end
    entry.bindType = bindType
    entry.lastSeen = time()
    entry.scopeKey = db.scopeKey
    entry.bindUnverified = nil
    db.items[key] = entry
    itemBindingLoadRequests[key] = nil

    -- Lokale Pruefung eines vorlaeufig akzeptierten Eintrags: Ist der Gegenstand doch
    -- gebunden (BoP), werden Katalogeintrag und zugehoerige Inserate wieder entfernt.
    if wasUnverified then
        if bindType == 1 then
            db.items[key] = nil
            for index = #db.listings, 1, -1 do
                local listing = db.listings[index]
                if type(listing) == "table" and tonumber(listing.itemID) == itemID then
                    table.remove(db.listings, index)
                end
            end
            if type(self.Log) == "function" then
                self:Log("SYNC<", "Vorläufig akzeptiertes Item " .. key .. " ist BoP: entfernt")
            end
            return true, key
        end
        -- Bestaetigt: lokale Metadaten ergaenzen, aber nicht als eigene Aenderung weitersenden.
        changed = false
    end

    -- Wiederholte Cache-Ereignisse sollen nicht allein die Revision erhoehen
    -- oder eine endlose Folge neuer Snapshots verursachen.
    if changed and not quiet then
        db.sync.revision = (tonumber(db.sync.revision) or 0) + 1
        entry.updatedAt = entry.lastSeen
        entry.revision = (tonumber(entry.revision) or 0) + 1
        entry.syncRevision = db.sync.revision
    end

    return true, key
end

function GTC:GetItemBindingType(itemID, quiet)
    itemID = tonumber(itemID)
    if not itemID or itemID < 1 then
        return nil
    end

    local db = self.db
    if type(db) ~= "table" or type(db.items) ~= "table" then
        db = InitializeDatabase()
    end

    local key = tostring(itemID)
    local entry = db.items[key]
    if type(entry) == "table" and type(entry.bindType) == "number" then
        return entry.bindType
    end

    -- Erst synchron pruefen; wenn der Client die Daten noch nicht im Cache hat,
    -- UpdateItemMetadata fordert sie asynchron an und liefert nil als unbekannt.
    self:UpdateItemMetadata(itemID, quiet)
    entry = db.items[key]
    if type(entry) == "table" and type(entry.bindType) == "number" then
        return entry.bindType
    end

    RequestItemBindingData(itemID)
    return nil
end
-- v1.1.7: Gegenstand oder Beruf eines Inserats aus dem Text des Item-Feldes bestimmen.
-- Berufs-Inserate (GTC-Berufslink oder nativer Berufs-Link) bekommen ein ungebundenes
-- Platzhalter-Item, damit das Sync-Format (und damit aeltere Versionen) unveraendert bleibt.
-- Rueckgabe: true, subject  bzw.  false, Fehlermeldung
local function ResolveListingSubject(self, db, itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return false, L("Bitte einen gültigen WoW-Item-Link oder einen Beruf einfügen.")
    end

    local Prof = self.Prof
    local pid, nativeLink
    if Prof then
        pid, nativeLink = Prof:Parse(itemLink)
    end

    if pid then
        local tokenID = Prof:RequestTokenItem(pid)
        if not tokenID then
            return false, L("Für diesen Beruf ist kein Platzhalter-Item hinterlegt.")
        end
        local bindingType = self:GetItemBindingType(tokenID)
        if type(bindingType) ~= "number" then
            return false, L("Berufsdaten werden noch geladen. Bitte gleich noch einmal speichern.")
        end
        if bindingType == 1 then
            return false, L("Das Platzhalter-Item dieses Berufs ist gebunden. Bitte melde das als Fehler.")
        end
        -- Katalogeintrag des Platzhalters hat GetItemBindingType bereits angelegt.
        local item = db.items[tostring(tokenID)]
        return true, {
            itemID = tokenID,
            name = Prof:Name(pid),
            savedLink = Prof:BuildLink(pid),
            icon = item and item.icon,
            profession = pid,
            professionLink = nativeLink,
        }
    end

    local itemID = tonumber(itemLink:match("|[Hh]item:(%d+)"))
    if not itemID or itemID < 1 then
        return false, L("Bitte einen gültigen WoW-Item-Link einfügen (Shift-Klick auf den Gegenstand).")
    end

    local bindingType = self:GetItemBindingType(itemID)
    if bindingType == 1 then
        return false, L("BoP-Items (Bind on Pickup) können nicht als GTC-Inserat gespeichert werden.")
    end
    if type(bindingType) ~= "number" then
        return false, L("Item-Daten werden noch geladen. Bitte nach dem Laden erneut speichern.")
    end

    self:RememberItem(itemLink:match("item:(%d+)") and itemLink or ("item:" .. itemID))
    self:UpdateItemMetadata(itemID)

    local item = db.items[tostring(itemID)]
    local name = item and item.name
    if not name then
        name = itemLink:match("|h%[(.-)%]|h") or ("Item #" .. itemID)
    end

    local savedLink = itemLink
    if not savedLink:find("|Hitem:", 1, true) and not savedLink:find("|hitem:", 1, true) then
        savedLink = (item and item.itemLink) or itemLink
    end

    return true, {
        itemID = itemID,
        name = name,
        savedLink = savedLink,
        icon = item and item.icon,
    }
end

-- Standardbeschreibung fuer Berufs-Inserate (auch fuer aeltere Versionen lesbar, die nur
-- das Platzhalter-Item sehen). Gespeicherte Texte bleiben deutsch wie die Handelsart.
local function DefaultProfessionDescription(self, subject, kind, description)
    if not subject.profession or (description and description:match("%S")) then
        return description or ""
    end
    local name = self.Prof and self.Prof.INFO[subject.profession]
        and self.Prof.INFO[subject.profession][2] or subject.name
    if kind == "wanted" then
        return "Suche " .. name .. " (Beruf). GTC ab v1.1.7 zeigt das als Berufs-Gesuch."
    end
    return "Biete " .. name .. " an. Alle Rezepte per Klick im GTC (ab v1.1.7)."
end

function GTC:CreateLocalListing(itemLink, quantity, tradeType, description, kind, durationHours)
    local db = InitializeDatabase()

    local subjectOK, subject = ResolveListingSubject(self, db, itemLink)
    if not subjectOK then
        return false, subject
    end
    local itemID = subject.itemID

    quantity = subject.profession and 1 or (tonumber(quantity) or 1)
    if quantity < 1 or quantity ~= math.floor(quantity) then
        return false, L("Die Menge muss eine ganze Zahl größer als 0 sein.")
    end

    durationHours = tonumber(durationHours) or 24
    if durationHours < 1 or durationHours > 72 or durationHours ~= math.floor(durationHours) then
        return false, L("Die Laufzeit muss zwischen 1 und 72 Stunden liegen.")
    end

    kind = (kind == "wanted") and "wanted" or "offer"
    description = DefaultProfessionDescription(self, subject, kind, description)

    local name = subject.name
    local savedLink = subject.savedLink

    local activeCount = 0
    local ownName = self:GetFullPlayerName()
    local checkNow = self:Now()
    for _, existing in ipairs(db.listings) do
        if type(existing) == "table" and existing.completed ~= true
            and (tonumber(existing.expiresAt) or 0) > checkNow
            and self:SameCharacter(existing.character, ownName) then
            activeCount = activeCount + 1
        end
    end
    if activeCount >= self.MAX_ACTIVE_PER_CHARACTER then
        return false, L("Du hast bereits die maximale Zahl aktiver Inserate erreicht.")
            .. " (" .. tostring(self.MAX_ACTIVE_PER_CHARACTER) .. ")"
    end

    db.nextListingId = db.nextListingId + 1
    local now = self:Now()
    db.sync.revision = db.sync.revision + 1

    local entry = {
        id = "gtc-" .. tostring(db.realm) .. "-" .. tostring(UnitName("player") or "UnknownPlayer")
            .. "-" .. tostring(now) .. "-" .. tostring(db.nextListingId),
        itemID = itemID,
        item = name,
        itemLink = savedLink,
        icon = subject.icon,
        profession = subject.profession,
        professionLink = subject.professionLink,
        quantity = quantity,
        tradeType = (tradeType and tradeType ~= "") and tradeType or
            (kind == "wanted" and "Kauf" or "Tausch"),
        description = description or "",
        character = self:GetFullPlayerName(),
        kind = kind,
        isTest = false,
        completed = false,
        createdAt = now,
        expiresAt = now + (durationHours * 60 * 60),
        durationHours = durationHours,
        updatedAt = now,
        revision = 1,
        syncRevision = db.sync.revision,
        scopeKey = db.scopeKey,
    }

    table.insert(db.listings, entry)

    if type(self.ScheduleGuildSync) == "function" then
        self:ScheduleGuildSync()
    end

    return true, entry.id
end

function GTC:UpdateLocalListing(listingId, itemLink, quantity, tradeType, description, kind, actorName, durationHours)
    local db = InitializeDatabase()

    if not listingId then
        return false, L("Keine Eintrags-ID angegeben.")
    end

    actorName = actorName or self:GetFullPlayerName()

    local target
    for _, entry in ipairs(db.listings) do
        if entry and entry.id == listingId then
            target = entry
            break
        end
    end

    if not target then
        return false, L("Eintrag nicht gefunden.")
    end

    if not self:SameCharacter(target.character, actorName) then
        return false, L("Nur der Ersteller kann diesen Eintrag bearbeiten.")
    end

    if target.completed == true then
        return false, L("Ein abgeschlossener Eintrag kann nicht mehr bearbeitet werden.")
    end

    local subjectOK, subject = ResolveListingSubject(self, db, itemLink)
    if not subjectOK then
        return false, subject
    end
    local itemID = subject.itemID

    quantity = subject.profession and 1 or (tonumber(quantity) or 1)
    if quantity < 1 or quantity ~= math.floor(quantity) then
        return false, L("Die Menge muss eine ganze Zahl größer als 0 sein.")
    end

    kind = (kind == "wanted") and "wanted" or "offer"
    description = DefaultProfessionDescription(self, subject, kind, description)

    durationHours = tonumber(durationHours) or tonumber(target.durationHours) or 24
    if durationHours < 1 or durationHours > 72 or durationHours ~= math.floor(durationHours) then
        return false, L("Die Laufzeit muss zwischen 1 und 72 Stunden liegen.")
    end

    target.itemID = itemID
    target.item = subject.name
    target.itemLink = subject.savedLink
    target.icon = subject.icon or target.icon
    target.profession = subject.profession
    target.professionLink = subject.professionLink
    target.quantity = quantity
    target.tradeType = (tradeType and tradeType ~= "") and tradeType or
        (kind == "wanted" and "Kauf" or "Tausch")
    target.description = description or ""
    target.kind = kind
    target.updatedAt = self:Now()
    target.durationHours = durationHours
    target.expiresAt = target.updatedAt + (durationHours * 60 * 60)
    target.revision = (tonumber(target.revision) or 0) + 1
    target.scopeKey = db.scopeKey
    db.sync.revision = db.sync.revision + 1
    target.syncRevision = db.sync.revision

    if type(self.ScheduleGuildSync) == "function" then
        self:ScheduleGuildSync()
    end

    return true, target.id
end

function GTC:CompleteLocalListing(listingId, actorName)
    local db = InitializeDatabase()

    if not listingId then
        return false, L("Keine Eintrags-ID angegeben.")
    end

    actorName = actorName or self:GetFullPlayerName()

    local target
    for _, entry in ipairs(db.listings) do
        if entry and entry.id == listingId then
            target = entry
            break
        end
    end

    if not target then
        return false, L("Eintrag nicht gefunden.")
    end

    if not self:SameCharacter(target.character, actorName) or target.isTest ~= false then
        return false, L("Nur der Ersteller kann diesen echten Eintrag abschließen.")
    end

    if target.completed == true then
        return false, L("Dieser Eintrag ist bereits abgeschlossen.")
    end

    local now = self:Now()
    db.sync.revision = db.sync.revision + 1

    target.completed = true
    target.completedAt = now
    target.completedBy = actorName
    target.updatedAt = now
    target.revision = (tonumber(target.revision) or 0) + 1
    target.syncRevision = db.sync.revision
    target.scopeKey = db.scopeKey

    if type(self.ScheduleGuildSync) == "function" then
        self:ScheduleGuildSync()
    end

    if type(self.RefreshListingView) == "function" then
        self:RefreshListingView()
    end

    return true, target.id
end
function GTC:DeleteLocalListing(listingId, actorName)
    local db = InitializeDatabase()

    if not listingId then
        return false, L("Keine Eintrags-ID angegeben.")
    end

    actorName = actorName or self:GetFullPlayerName()

    for i = #db.listings, 1, -1 do
        local entry = db.listings[i]

        if entry and entry.id == listingId then
            if not self:SameCharacter(entry.character, actorName) then
                return false, L("Nur der Ersteller kann diesen Eintrag löschen.")
            end

            db.sync.revision = db.sync.revision + 1
            db.sync.tombstones[tostring(listingId)] = {
                id = listingId,
                scopeKey = db.scopeKey,
                deletedAt = self:Now(),
                deletedBy = actorName,
                revision = db.sync.revision,
            }
            table.remove(db.listings, i)

            if type(self.ScheduleGuildSync) == "function" then
                self:ScheduleGuildSync()
            end

            return true
        end
    end

    return false, L("Eintrag nicht gefunden.")
end

local quietPrefixes = nil

function GTC:Print(message)
    message = tostring(message)

    -- Normale Start- und Erfolgsmeldungen nicht in den Chat schreiben.
    -- Einmal aufbauen statt bei jeder Meldung neu (Sprache wechselt nur per /reload).
    local prefixes = quietPrefixes
    if not prefixes then
        prefixes = {
            "Version ",
            L("Live-Beta aktiv. Eigene echte Inserate werden lokal gespeichert."),
            L("Gilden-Snapshot eingereiht:"),
            L("Gilden-Sync gestartet. Es wird ausschließlich GUILD-Addon-Kommunikation verwendet."),
            L("Sync übernommen:"),
            L("Fenster wird vorbereitet."),
        }
        -- Erst nach dem Laden der Einstellungen merken (Sprachwahl steht dort).
        if type(GuildTradeCenterDB) == "table" then
            quietPrefixes = prefixes
        end
    end

    for _, prefix in ipairs(prefixes) do
        if message:sub(1, #prefix) == prefix then
            return
        end
    end

    -- Alle anderen Meldungen, insbesondere Fehler, bleiben sichtbar.
    print("|cff35d0d0GuildTradeCenter:|r " .. message)
end

function GTC:OnLogin()
    InitializeDatabase(true)
    self:UpgradeOwnListingNames()
    self:Log("INFO", "Login v" .. tostring(self.version) .. " Spieler=" .. tostring(UnitName("player"))
        .. " Gilde=" .. tostring(GetGuildInfo("player")) .. " Scope=" .. tostring(self.activeScopeKey))
    self:Print("Version " .. self.version .. L(" geladen."))
    self:Print(L("Eigene Inserate werden lokal gespeichert. Automatische Scans bei Login, Taschen- und Bankereignissen bleiben aktiv."))

    if self.CreateMainWindow then
        self:CreateMainWindow()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        GTC:OnLogin()
    end
end)

-- Ablauf von Inseraten: alle 60 Sekunden per Timer statt in jedem Frame.
C_Timer.NewTicker(60, function()
    if GTC.db ~= nil then
        InitializeDatabase(true)
    end
end)

-- Datenbereich (Gilde/personal) sofort neu bestimmen. Die Gildeninfo ist direkt nach dem
-- Login oft noch nicht verfuegbar; Comm.lua ruft das auf, sobald sie da sein koennte.
function GTC:RefreshDatabaseScope()
    return InitializeDatabase(true)
end

SLASH_GUILDTRADECENTER1 = "/gtc"
SLASH_GUILDTRADECENTER2 = "/guildtradecenter"

SlashCmdList["GUILDTRADECENTER"] = function(message)
    local rawMessage = message or ""
    message = (message or ""):lower():match("^%s*(.-)%s*$")

    local firstWord = message:match("^(%S+)")
    if firstWord == "watch" or firstWord == "wunschliste" then
        if GTC.HandleWatchCommand then
            GTC:HandleWatchCommand(rawMessage)
        end
        return
    end

    local langArg = message:match("^lang%s*(%S*)$")
    if langArg then
        if langArg == "de" or langArg == "en" or langArg == "auto" or langArg == "" then
            if langArg ~= "" then
                GTC.SetLanguage(langArg ~= "auto" and langArg or nil)
            end
            local active = GuildTradeCenterDB and GuildTradeCenterDB.language or "auto"
            print("|cff35d0d0GuildTradeCenter:|r Language / Sprache: " .. tostring(active)
                .. " (de, en, auto) - /reload")
        else
            print("|cff35d0d0GuildTradeCenter:|r /gtc lang de | en | auto")
        end
        return
    end

    local logArg = message:match("^log%s*(%S*)$")
    if logArg then
        GTC:HandleLogCommand(logArg)
        return
    end

    if message == "rezepte" or message == "recipes" then
        if GTC.ShowRecipes then GTC:ShowRecipes() end
        return
    end

    if message == "test" or message == "resettest" then
        GTC:Print(L("Testmodus und Beispieldaten sind in der Live-Beta deaktiviert."))
        return
    end

    if GTC.ToggleMainWindow then
        GTC:ToggleMainWindow()
    else
        GTC:Print(L("Fenster wird vorbereitet."))
    end
end
