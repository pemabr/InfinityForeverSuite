-- Finanzamt – englische Texte (Tax)
-- Schlüssel = deutscher Originaltext, Wert = Übersetzung
local E = select(2, ...).GS.LOCALES.en


-- Buchungsnotizen
E["nicht belastet"] = "not charged"
E["freier Tab"] = "free tab"
E["Steuer %s"] = "Tax %s"
E["Steuer %s (gestundet)"] = "Tax %s (deferred)"
E["Verzugszinsen %s (%s auf %s)"] = "Late interest %s (%s on %s)"

-- Verzugszinsen
E["%s Tagen"] = "%s days"
E["%s Min. Spielzeit"] = "%s min. playtime"
E[" (ab %s in der Woche)"] = " (from %s per week)"
E["|cffffd100Verzugszinsen:|r noch %s aktive Wochen zinsfrei, danach %s pro aktiver Spielwoche"] = "|cffffd100Late interest:|r interest-free for %s more active weeks, then %s per active play week"
E["|cffffd100Verzugszinsen:|r diese Woche noch zinsfrei, danach %s pro aktiver Spielwoche"] = "|cffffd100Late interest:|r interest-free this week, then %s per active play week"
E["|cffff8040Verzugszinsen:|r Höchstbetrag erreicht – es kommen keine weiteren dazu"] = "|cffff8040Late interest:|r maximum reached – no more will be added"
E["|cffff8040Verzugszinsen:|r %s auf %s, wenn du diese Woche spielst%s und nicht zahlst"] = "|cffff8040Late interest:|r %s on %s if you play this week%s and don't pay"
E["|cffaaaaaaBisher angefallene Verzugszinsen: %s|r"] = "|cffaaaaaaLate interest so far: %s|r"

-- Zahlungszeile
E["Steuer letzte Woche"] = "Tax last week"
E["Steuer im Zahlungsziel"] = "Tax currently due"
E[" |cff40ff40– aus dem Guthaben gedeckt|r"] = " |cff40ff40– covered by your credit|r"
E["|cffff4040Zu zahlen: %s|r |cffff4040(davon überfällig %s)|r"] = "|cffff4040To pay: %s|r |cffff4040(of which overdue %s)|r"
E["|cffffd100Zu zahlen bis %s:|r %s"] = "|cffffd100To pay by %s:|r %s"
E[" |cffaaaaaa(%s aus dem Guthaben gedeckt)|r"] = " |cffaaaaaa(%s covered by your credit)|r"

-- Status (Werte bleiben deutsch, nur Anzeige)
E["quitt"] = "settled"
E["offen"] = "outstanding"
E["überfällig"] = "overdue"

-- Statistik / Steuerposten
E["Reparaturen"] = "Repairs"
E["Loot"] = "Loot"
E["Quests"] = "Quests"
E["Händler"] = "Vendor"
E["AH-Erlöse"] = "AH proceeds"
E["AH-Anzahlungen"] = "AH deposits"
E["Zurückgezahlte Anzahlungen"] = "Refunded deposits"
E["Werbungskosten"] = "Deductible expenses"
E["Wareneinsatz"] = "Cost of materials"
E["Werbungskosten: %s"] = "Deductible expenses: %s"
E["Wareneinsatz: %s"] = "Cost of materials: %s"
E["Werbungskosten: Reparaturen/Sonstiges"] = "Deductible expenses: repairs/other"
E["Wareneinsatz: ohne Item"] = "Cost of materials: no item"

-- Sparziele
E["Bitte einen Namen für das Ziel angeben."] = "Please enter a name for the goal."
E["Bitte einen Zielbetrag angeben (z. B. 50g)."] = "Please enter a target amount (e.g. 50g)."

-- Deine Woche im Überblick
E[" |cff40ff40(+%d %% zur Vorwoche)|r"] = " |cff40ff40(+%d %% vs. last week)|r"
E[" |cffff8040(%d %% zur Vorwoche)|r"] = " |cffff8040(%d %% vs. last week)|r"
E[" |cffaaaaaa(wie in der Vorwoche)|r"] = " |cffaaaaaa(same as last week)|r"
E["Eingenommen: %s"] = "Income: %s"
E["Steuer: %s"] = "Tax: %s"
E[" |cffaaaaaa(%s deines Einkommens)|r"] = " |cffaaaaaa(%s of your income)|r"
E["Platz %d von %d Steuerzahlern der Gilde"] = "Rank %d of %d taxpayers in the guild"
E["Steuer: |cff40ff40keine|r"] = "Tax: |cff40ff40none|r"
E["Sparziel „%s“: %d %%"] = "Savings goal '%s': %d %%"
E[" |cffaaaaaa– dein Beitrag diese Woche: %s|r"] = " |cffaaaaaa– your contribution this week: %s|r"

-- Datenstand
E["|cff888888keine Daten|r"] = "|cff888888no data|r"
