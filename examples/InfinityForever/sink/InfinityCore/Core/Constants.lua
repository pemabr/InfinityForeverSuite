-- InfinityCore Constants
-- Global constants used throughout the suite

INFINITY_SUITE_VERSION = "1.0.0"
INFINITY_SUITE_NAME = "Infinity Suite"
INFINITY_CORE_NAME = "InfinityCore"

-- Feature module names
INFINITY_FEATURES = {
	LOOT = "InfinityLoot",
	GUILD = "InfinityGuild",
	RAID = "InfinityRaid",
	GATHER = "InfinityGather",
	GUIDE = "InfinityGuide",
	GEAR = "InfinityGear",
	QOL = "InfinityQoL",
	DATA = "InfinityData",
}

-- Event namespaces to prevent conflicts
INFINITY_EVENTS = {
	-- Data events
	DATA_CHANGED = "INFINITY_DATA_CHANGED",
	DATA_LOADED = "INFINITY_DATA_LOADED",
	
	-- Feature events
	FEATURE_ENABLED = "INFINITY_FEATURE_ENABLED",
	FEATURE_DISABLED = "INFINITY_FEATURE_DISABLED",
	
	-- Configuration events
	CONFIG_CHANGED = "INFINITY_CONFIG_CHANGED",
	KEYBIND_CHANGED = "INFINITY_KEYBIND_CHANGED",
	
	-- UI events
	UI_THEME_CHANGED = "INFINITY_UI_THEME_CHANGED",
	WINDOW_SHOWN = "INFINITY_WINDOW_SHOWN",
	WINDOW_HIDDEN = "INFINITY_WINDOW_HIDDEN",
}

-- UI Colors
INFINITY_COLORS = {
	PRIMARY = "|cff00ccff",		-- Cyan
	SECONDARY = "|cff33ff33",	-- Green
	WARNING = "|cffff9900",		-- Orange
	ERROR = "|cffff0000",		-- Red
	INFO = "|cff9999ff",		-- Light blue
	RESET = "|r",				-- Reset color
}

-- Data cache TTLs (in seconds)
INFINITY_CACHE_TTL = {
	SHORT = 60,			-- 1 minute
	MEDIUM = 300,		-- 5 minutes
	LONG = 3600,		-- 1 hour
	VERY_LONG = 86400,	-- 24 hours
}

-- Logging levels
INFINITY_LOG_LEVEL = {
	DEBUG = 1,
	INFO = 2,
	WARNING = 3,
	ERROR = 4,
}

-- Current log level
INFINITY_CURRENT_LOG_LEVEL = INFINITY_LOG_LEVEL.WARNING
