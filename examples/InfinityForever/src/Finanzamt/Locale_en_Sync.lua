-- Finanzamt – englische Texte (Sync)
-- Schlüssel = deutscher Originaltext, Wert = Übersetzung
local E = select(2, ...).GS.LOCALES.en

-- Auffälligkeiten: Art (bleibt deutsch gespeichert, Anzeige mit L[fl.kind]) und Text
E["Werte gesunken"] = "Values decreased"
E["Rücksprung"] = "Rollback"
E["Unberechtigt"] = "Unauthorized"
E["Eigener Bericht enthielt niedrigere Werte als bereits bekannt"] = "Own report contained lower values than already known"
E["Sequenz %d statt bekannter %d – Daten gelöscht oder zurückgesetzt?"] = "Sequence %d instead of known %d – data deleted or reset?"
E["Verwaltungsbuchung (%s) ohne Recht verworfen"] = "Admin entry (%s) without permission discarded"
E["Einstellungsänderung (%s) ohne Recht verworfen"] = "Settings change (%s) without permission discarded"
E["Rechte-Matrix von Nicht-Gildenmeister verworfen"] = "Permission matrix from non-guild-master discarded"

-- Sync / Versionscheck
E["Keine Gilde"] = "No guild"
E["Bitte noch %d Sekunden warten."] = "Please wait %d more seconds."
E["|cffff8040Deine Version %s ist veraltet|r – %s nutzt schon %s. Bitte das Addon aktualisieren (z. B. über CurseForge), damit Steuern und Sync richtig laufen."] = "|cffff8040Your version %s is outdated|r – %s already uses %s. Please update the addon (e.g. via CurseForge) so taxes and sync work properly."
E["jemand"] = "someone"
E["eine neuere"] = "a newer one"
E["Finanzamt\n\nDeine Version %s ist veraltet.\n%s nutzt schon %s.\n\nBitte das Addon aktualisieren, damit Steuern und Sync richtig laufen."] = "Finanzamt\n\nYour version %s is outdated.\n%s already uses %s.\n\nPlease update the addon so taxes and sync work properly."
E["Ein Gildenmitglied"] = "A guild member"
E["eine neuere Version"] = "a newer version"

-- Addon-Status (MemberStatus/AccountAddonStatus liefern deutsche Werte, Anzeige mit L[st])
E["aktiv"] = "active"
E["aktiv (alte Version)"] = "active (old version)"
E["online ohne Addon"] = "online without addon"
E["offline"] = "offline"
E["veraltet"] = "stale"
E["veraltet (Version)"] = "outdated (version)"
E["nie gesehen"] = "never seen"
E["aktiv (Twink)"] = "active (alt)"
E["aktiv (alte Version) (Twink)"] = "active (old version) (alt)"
E["online ohne Addon (Twink)"] = "online without addon (alt)"
E["offline (Twink)"] = "offline (alt)"
E["veraltet (Twink)"] = "stale (alt)"
E["veraltet (Version) (Twink)"] = "outdated (version) (alt)"

E["Sync: Nachricht verworfen (%s)."] = "Sync: message dropped (%s)."
