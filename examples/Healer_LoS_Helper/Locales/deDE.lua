local L = Healer_LoS_Helper_Locale or {}

if GetLocale() == "deDE" then
    L["OPTIONS_TITLE"] = "Healer LoS Helper Optionen"
    L["OPTIONS_REQUIRED_CLICKS"] = "Benoetigte Fehlerversuche"
    L["OPTIONS_CLICK_THRESHOLD"] = "Klick-Zeitfenster (Sekunden)"
    L["OPTIONS_TIMER_DURATION"] = "Anzeigedauer (Sekunden)"
    L["OPTIONS_RESET"] = "Zuruecksetzen"
    L["OPTIONS_SHOW_RANGE_SYMBOL"] = "Symbol (O), wenn Ziel außer Reichweite"
    L["UI_NOT_IN_LOS"] = "Ziel nicht in Sichtlinie"
    L["NOTIFY_LOS"] = "Ziel benachrichtigen, wenn nicht in Sichtlinie"
    L["NOTIFY_RANGE"] = "Ziel benachrichtigen, wenn nicht in Reichweite"
    L["OPTIONS_MESSAGE_LANGUAGE"] = "Whisper-Sprache"
    L["SPAM_PROTECTION"] = "Spam-Schutz: Nachrichtensperre auf Ziel"
    L["OPTIONS_HP_THRESHOLD"] = "HP-Schwelle: bei xx%% oder weniger erfolgt Nachricht an Ziel"
    L["MSG_LOS"] = "Ich kann dich nicht heilen - keine Sichtlinie! (%d%% HP)"
    L["MSG_RANGE"] = "Ich kann dich nicht heilen - ausser Reichweite! (%d%% HP)"
    L["DB_NOT_READY"] = "Datenbank noch nicht geladen - bitte gleich noch einmal versuchen."
    L["OPTIONS_NOT_READY"] = "Optionen sind noch nicht geladen."
end

Healer_LoS_Helper_Locale = L
