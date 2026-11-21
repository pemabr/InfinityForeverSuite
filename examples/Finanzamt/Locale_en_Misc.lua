-- Finanzamt – englische Texte (Misc)
-- Schlüssel = deutscher Originaltext, Wert = Übersetzung
local E = select(2, ...).GS.LOCALES.en

-- Tooltip.lua
E["Finanzamt: absetzbar (Werbungskosten)"] = "Finanzamt: deductible (deductible expenses)"
E["Finanzamt: Marktwert (Gildenbank)"] = "Finanzamt: market value (guild bank)"
E["AH-Scan"] = "AH scan"
E["Händlerpreis"] = "vendor price"
E["festgesetzt"] = "set manually"

-- Minimap.lua
E["Saldo:"] = "Balance:"
E["Status:"] = "Status:"
E["Laufende Woche (gesch.):"] = "Current week (est.):"
E["Online ohne Addon:"] = "Online without addon:"
E["Keine Gildendaten."] = "No guild data."
E["|cffffffffLinksklick:|r Fenster öffnen"] = "|cffffffffLeft-click:|r open window"
E["|cffffffffRechtsklick:|r Offiziersliste"] = "|cffffffffRight-click:|r officer list"
E["|cffffffffZiehen:|r verschieben"] = "|cffffffffDrag:|r move"
E["Minimap-Button ausgeblendet (/gst minimap zum Einblenden)"] = "Minimap button hidden (/gst minimap to show it again)"
E["Minimap-Button eingeblendet"] = "Minimap button shown"

-- Pricing.lua (GS.SOURCE_LABEL: deutsch, Anzeige mit L[...])
E["Auctionator"] = "Auctionator"
E["Händler (ungeprüft)"] = "vendor (unverified)"
E["kein Preis (ungeprüft)"] = "no price (unverified)"
E["Gold"] = "Gold"
E["Keine Gilde"] = "No guild"
E["Keine Berechtigung"] = "No permission"
E["Das Auktionshaus ist nicht geöffnet."] = "The Auction House is not open."
E["Dieser Client bietet keine Scan-Funktion an – Preise kommen dann aus Auctionator."] = "This client has no scan function – prices will come from Auctionator instead."
E["Komplettscan gerade nicht möglich (nur alle 15 Minuten)."] = "Full scan not possible right now (only every 15 minutes)."
E["Komplettscan erst in %d Min. wieder möglich (Server-Sperre 15 Minuten)."] = "Full scan possible again in %d min. (15-minute server cooldown)."
E["AH-Scan lieferte keine Auktionen – evtl. sperrt der Server den Scan noch. Später erneut versuchen."] = "AH scan returned no auctions – the server may still be blocking the scan. Try again later."
E["AH-Scan fertig: %d Auktionen, %d Preise gespeichert."] = "AH scan done: %d auctions, %d prices saved."
E["Keine passenden Scan-Preise vorhanden – zuerst das AH scannen."] = "No matching scan prices – scan the AH first."
E["Preise verteilt ohne Recht"] = "Sent prices without permission"

-- Ledger.lua (GS.BANK_TYPE_LABEL: deutsch, Anzeige mit L[...])
E["Item-Einlage"] = "Item deposit"
E["Item-Entnahme"] = "Item withdrawal"
E["Gold-Einzahlung"] = "Gold deposit"
E["Gold-Abhebung"] = "Gold withdrawal"
E["Gildenreparatur"] = "Guild repair"
E["Gildenbank"] = "Guild bank"
E["Log „%s“ war voll: Einträge zwischen %s und %s fehlen womöglich. Gildenbank öfter mit Addon öffnen."] = "Log '%s' was full: entries between %s and %s may be missing. Open the guild bank with the addon more often."
E["|cffff8040Gildenbank:|r "] = "|cffff8040Guild bank:|r "
E["Gildenbank-Gold gelesen: %s"] = "Guild bank gold read: %s"
E["|cffff8040Gildenbank:|r Das Log wurde seit %s von niemandem mit Addon gelesen. Bitte die Gildenbank öffnen, sonst gehen ältere Einträge verloren."] = "|cffff8040Guild bank:|r Nobody with the addon has read the log for %s. Please open the guild bank, or older entries will be lost."

