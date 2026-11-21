-- Finanzamt – einfacher, addon-message-tauglicher Serializer
local GS = select(2, ...).GS
local floor = math.floor

local S = {}
GS.Ser = S

local ESC = { ["~"] = "~~", [";"] = "~s", ["|"] = "~p", ["\n"] = "~n", ["\r"] = "~r" }
local UNESC = { ["~"] = "~", s = ";", p = "|", n = "\n", r = "\r" }

local function esc(s) return (s:gsub("[~;|\n\r]", ESC)) end
local function unesc(s) return (s:gsub("~(.)", UNESC)) end

local function ser(v, out)
	local t = type(v)
	if t == "number" then
		if v == floor(v) and v > -1e15 and v < 1e15 then
			out[#out + 1] = "n" .. string.format("%.0f", v) .. ";"
		else
			out[#out + 1] = "f" .. string.format("%.8g", v) .. ";"
		end
	elseif t == "string" then
		out[#out + 1] = "s" .. esc(v) .. ";"
	elseif t == "boolean" then
		out[#out + 1] = v and "T" or "F"
	elseif t == "table" then
		out[#out + 1] = "{"
		for k, val in pairs(v) do
			ser(k, out)
			ser(val, out)
		end
		out[#out + 1] = "}"
	else
		out[#out + 1] = "N"
	end
end

function S.Serialize(v)
	local out = {}
	ser(v, out)
	return table.concat(out)
end

local function des(str, pos, depth)
	if depth > 30 then error("zu tief") end
	local c = str:sub(pos, pos)
	if c == "n" or c == "f" or c == "s" then
		local e = str:find(";", pos + 1, true)
		if not e then error("unvollständig") end
		local raw = str:sub(pos + 1, e - 1)
		if c == "s" then return unesc(raw), e + 1 end
		return tonumber(raw), e + 1
	elseif c == "T" then return true, pos + 1
	elseif c == "F" then return false, pos + 1
	elseif c == "N" then return nil, pos + 1
	elseif c == "{" then
		local t = {}
		pos = pos + 1
		while true do
			if pos > #str then error("unvollständig") end
			if str:sub(pos, pos) == "}" then break end
			local k, v
			k, pos = des(str, pos, depth + 1)
			v, pos = des(str, pos, depth + 1)
			if k ~= nil then t[k] = v end
		end
		return t, pos + 1
	end
	error("ungültiges Zeichen")
end

function S.Deserialize(str)
	if type(str) ~= "string" or str == "" then return nil end
	local ok, v = pcall(des, str, 1, 0)
	if ok then return v end
	return nil
end
