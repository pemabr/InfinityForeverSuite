-- InfinityCore Utilities
-- General utility functions used throughout the suite

InfinityUtils = {}

-- Logging function
function InfinityUtils:Log(level, message, source)
	if not level or level < INFINITY_CURRENT_LOG_LEVEL then
		return
	end
	
	source = source or "InfinityCore"
	local timestamp = date("%H:%M:%S")
	local levelName = ""
	
	if level == INFINITY_LOG_LEVEL.DEBUG then
		levelName = "DEBUG"
	elseif level == INFINITY_LOG_LEVEL.INFO then
		levelName = "INFO"
	elseif level == INFINITY_LOG_LEVEL.WARNING then
		levelName = "WARN"
	elseif level == INFINITY_LOG_LEVEL.ERROR then
		levelName = "ERROR"
	end
	
	print(string.format("|cff00ccff[%s]|r |cff9999ff%s|r |cffcccccc%s|r: %s", INFINITY_SUITE_NAME, timestamp, levelName, message))
end

-- Debug wrapper
function InfinityUtils:Debug(message, source)
	self:Log(INFINITY_LOG_LEVEL.DEBUG, message, source)
end

-- Info wrapper
function InfinityUtils:Info(message, source)
	self:Log(INFINITY_LOG_LEVEL.INFO, message, source)
end

-- Warning wrapper
function InfinityUtils:Warning(message, source)
	self:Log(INFINITY_LOG_LEVEL.WARNING, message, source)
end

-- Error wrapper
function InfinityUtils:Error(message, source)
	self:Log(INFINITY_LOG_LEVEL.ERROR, message, source)
end

-- Table operations
function InfinityUtils:DeepCopy(obj)
	if type(obj) ~= "table" then return obj end
	
	local result = {}
	for k, v in pairs(obj) do
		result[k] = self:DeepCopy(v)
	end
	return result
end

function InfinityUtils:TableMerge(base, override)
	local result = self:DeepCopy(base)
	for k, v in pairs(override) do
		if type(v) == "table" and type(result[k]) == "table" then
			result[k] = self:TableMerge(result[k], v)
		else
			result[k] = v
		end
	end
	return result
end

-- String operations
function InfinityUtils:Trim(str)
	return str:match("^%s*(.-)%s*$")
end

function InfinityUtils:Split(str, delimiter)
	local result = {}
	for part in str:gmatch("([^" .. delimiter .. "]+)") do
		table.insert(result, part)
	end
	return result
end

-- Validation
function InfinityUtils:IsValid(value)
	return value ~= nil and value ~= ""
end

function InfinityUtils:IsValidTable(tbl)
	return type(tbl) == "table" and #tbl > 0
end

-- Time operations
function InfinityUtils:GetTimeStamp()
	return time()
end

function InfinityUtils:FormatTime(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	
	if hours > 0 then
		return string.format("%dh %dm %ds", hours, minutes, secs)
	elseif minutes > 0 then
		return string.format("%dm %ds", minutes, secs)
	else
		return string.format("%ds", secs)
	end
end

-- Number formatting
function InfinityUtils:FormatNumber(num)
	if not num then return "0" end
	
	local formatted = tostring(num)
	local k = tonumber(num) or num
	
	if k >= 1000000 then
		return string.format("%.1fM", k / 1000000)
	elseif k >= 1000 then
		return string.format("%.1fK", k / 1000)
	else
		return formatted
	end
end

-- Gold formatting
function InfinityUtils:FormatGold(copper)
	if not copper or copper == 0 then return "0g" end
	
	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	local copper_remainder = copper % 100
	
	local result = ""
	if gold > 0 then
		result = gold .. "g"
	end
	if silver > 0 then
		result = result .. (result ~= "" and " " or "") .. silver .. "s"
	end
	if copper_remainder > 0 then
		result = result .. (result ~= "" and " " or "") .. copper_remainder .. "c"
	end
	
	return result ~= "" and result or "0c"
end

-- Color utilities
function InfinityUtils:GetQualityColor(quality)
	local colors = {
		[0] = "|cff9d9d9d",	-- Poor (grey)
		[1] = "|cffffffff",	-- Common (white)
		[2] = "|cff1eff00",	-- Uncommon (green)
		[3] = "|cff0070dd",	-- Rare (blue)
		[4] = "|cffa335ee",	-- Epic (purple)
		[5] = "|cffff8000",	-- Legendary (orange)
		[6] = "|cffe6cc80",	-- Artifact (tan)
	}
	return colors[quality] or "|cffffffff"
end

return InfinityUtils
