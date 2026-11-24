-- PluribusCore Constants
-- Global constants used throughout the suite

PLURIBUS_SUITE_VERSION = "1.0.0"
PLURIBUS_SUITE_NAME = "Pluribus Suite"
PLURIBUS_CORE_NAME = "PluribusCore"

-- Feature module names
PLURIBUS_FEATURES = {
	LOOT = "PluribusLoot",
	GUILD = "PluribusGuild",
	RAID = "PluribusRaid",
	GATHER = "PluribusGather",
	GUIDE = "PluribusGuide",
	GEAR = "PluribusGear",
	QOL = "PluribusQoL",
	DATA = "PluribusData",
}

-- Event namespaces to prevent conflicts
PLURIBUS_EVENTS = {
	-- Data events
	DATA_CHANGED = "PLURIBUS_DATA_CHANGED",
	DATA_LOADED = "PLURIBUS_DATA_LOADED",
	
	-- Feature events
	FEATURE_ENABLED = "PLURIBUS_FEATURE_ENABLED",
	FEATURE_DISABLED = "PLURIBUS_FEATURE_DISABLED",
	
	-- Configuration events
	CONFIG_CHANGED = "PLURIBUS_CONFIG_CHANGED",
	KEYBIND_CHANGED = "PLURIBUS_KEYBIND_CHANGED",
	
	-- UI events
	UI_THEME_CHANGED = "PLURIBUS_UI_THEME_CHANGED",
	WINDOW_SHOWN = "PLURIBUS_WINDOW_SHOWN",
	WINDOW_HIDDEN = "PLURIBUS_WINDOW_HIDDEN",
}

-- UI Colors
PLURIBUS_COLORS = {
	PRIMARY = "|cff00ccff",		-- Cyan
	SECONDARY = "|cff33ff33",	-- Green
	WARNING = "|cffff9900",		-- Orange
	ERROR = "|cffff0000",		-- Red
	INFO = "|cff9999ff",		-- Light blue
	RESET = "|r",				-- Reset color
}

-- Data cache TTLs (in seconds)
PLURIBUS_CACHE_TTL = {
	SHORT = 60,			-- 1 minute
	MEDIUM = 300,		-- 5 minutes
	LONG = 3600,		-- 1 hour
	VERY_LONG = 86400,	-- 24 hours
}

-- Logging levels
PLURIBUS_LOG_LEVEL = {
	DEBUG = 1,
	INFO = 2,
	WARNING = 3,
	ERROR = 4,
}

-- Current log level
PLURIBUS_CURRENT_LOG_LEVEL = PLURIBUS_LOG_LEVEL.WARNING
