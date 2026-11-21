-- InfinityEncounter Localization
-- English localization strings

InfinityEncounterL = {
    -- UI Labels
    ui_title = "Infinity Encounter",
    ui_encounters = "Encounters",
    ui_abilities = "Abilities",
    ui_alerts = "Alerts",
    ui_timers = "Timers",
    ui_settings = "Settings",
    
    -- Encounter States
    state_waiting = "Waiting for combat...",
    state_in_combat = "In Combat",
    state_between = "Between Pulls",
    state_victory = "Victory!",
    state_wipe = "Wipe",
    
    -- Timer Messages
    timer_ability_soon = "%s in %d seconds",
    timer_phase_change = "Phase change in %d seconds",
    timer_ability_cast = "%s casting",
    
    -- Alerts
    alert_boss_pull = "Boss pulled: %s",
    alert_phase_change = "Phase %d started",
    alert_ability_incoming = "%s incoming in %d seconds",
    alert_player_targeted = "%s targeted by %s",
    alert_boss_low = "%s at %.1f%% health",
    
    -- Commands
    cmd_toggle = "Toggle encounter window",
    cmd_reset = "Reset encounter data",
    cmd_test = "Test alerts system",
}

return InfinityEncounterL
