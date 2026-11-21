-- Finanzamt – englische Texte (Income)
-- Schlüssel = deutscher Originaltext, Wert = Übersetzung
local E = select(2, ...).GS.LOCALES.en

-- Kaufquellen / Fundorte (bleiben deutsch gespeichert, Anzeige mit L[...])
E["Kauf"] = "purchase"
E["Händler"] = "Vendor"
E["Auktionshaus"] = "Auction House"
E["Briefkasten"] = "Mailbox"

-- Chat-Ausgaben
E["Einkommen"] = "Income"
E["Sonstiger Goldeingang (steuerfrei): %s"] = "Other gold received (tax-free): %s"
E["Wareneinsatz erfasst: %s x%d für %s (%s) – mindert den AH-Gewinn"] = "Cost of materials recorded: %s x%d for %s (%s) – reduces the AH profit"
E["Alkohol-Einkauf erfasst: %s für %s – fällt unter die Alkoholsteuer"] = "Alcohol purchase recorded: %s for %s – subject to alcohol tax"
E[", %s/Stück"] = ", %s each"
E["Werbungskosten erfasst: %s x%d für %s (%s%s)"] = "Deductible expenses recorded: %s x%d for %s (%s%s)"
E["Weitere Lieferung desselben AH-Kaufs: %s x%d (Preis schon erfasst)"] = "Further delivery of the same AH purchase: %s x%d (price already recorded)"
E["Rückkauf verrechnet: %s – Händler-Einnahmen gemindert."] = "Buyback offset: %s – vendor income reduced."
E["AH-Anzahlung erfasst: %s"] = "AH deposit recorded: %s"
E["Reparatur als Werbungskosten erfasst: %s"] = "Repair recorded as deductible expenses: %s"
E["Nach einem Absturz fehlten Daten: Der Goldzuwachs von %s seit %s wird als normales Einkommen nachgeschätzt."] = "Data was missing after a crash: the gold gain of %s since %s is estimated as normal income."
E["|cffff4040Steuerhinterziehung erfasst:|r Dein Gold ist seit %s um %s gestiegen, während das Addon nicht aktiv war. Der Betrag wird nachversteuert."] = "|cffff4040Tax evasion recorded:|r Your gold has grown since %s by %s while the addon was not running. The amount will be taxed retroactively."
E["AH-Lieferung %s x%d nicht angekommen (Taschen voll?) – nichts gebucht."] = "AH delivery %s x%d did not arrive (bags full?) – nothing booked."
E["AH-Lieferung %s x%d – schon beim Kauf erfasst."] = "AH delivery %s x%d – already recorded at purchase."

-- Steuer-Zusatz in Geld-Meldungen
E["(unter %s Steuer)"] = "(under %s tax)"
E["(%s Steuer)"] = "(%s tax)"
E["(steuerfrei, noch %s frei)"] = "(tax-free, %s allowance left)"
E["(steuerfrei)"] = "(tax-free)"
E["steuerfrei"] = "tax-free"
E["Steuer)"] = "tax)"
E["Questbelohnung %s %s"] = "Quest reward %s %s"

-- Debug-Ausgaben
E["keine Spielmeldung (anderes Addon?)"] = "not a game message (another addon?)"
E["kein Händler/Quest/Briefkasten-Zusammenhang"] = "no vendor/quest/mailbox context"
E["Betrag %s erkannt, aber keine Steuerberechnung (z. B. Spielerpost)"] = "Amount %s detected, but no tax calculation (e.g. player mail)"
E["kein Geldbetrag erkannt"] = "no amount detected"
E["Debug Geld-Meldung: %s – Text: %s"] = "Debug money message: %s – text: %s"

