local TableWriter = {}

local tableWriterCfg = {
	type = type,
	warn = function(...) print("WARNING ", ...) end,
	error = error,
	userdata_value_writers = {}
}

local keyWriters = {
	string = function(k)
		if k:match("^[_%a][_%w]+$") then
			return k
		else
			return "[\"" .. k .. "\"]"
		end
	end,
	boolean = function(k)
		return '[' .. tostring(k) .. ']'
	end,
	number = function(k)
		return '[' .. tostring(k) .. ']'
	end,
	["nil"] = function(k)
		return "[nil]"
	end,
}

local valueWriters = {
	string = function(v)
		return "\"" .. tostring(v):gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\t", "\\t"):gsub("\r", "\\r"):gsub("\v", "\\v"):gsub("\f", "\\f"):gsub("\"", "\\\""):gsub("\'", "\\\'") .. "\""
	end,
	table = function(v)
		return TableWriter.write_tbl(v)
	end,
	number = function(v)
		return tostring(v)
	end,
	boolean = function(v)
		return tostring(v)
	end,
	["nil"] = function(v)
		return "nil"
	end,
}

function TableWriter.write_key(k)
	local kType = tableWriterCfg.type(k)
	local writer = keyWriters[kType]
	if writer then return writer(k) end
	tableWriterCfg.error("Attempt to write " .. kType .. " as key")
end

function TableWriter.write_value(v)
	local vType = tableWriterCfg.type(v)
	local writer = valueWriters[vType]
	writer = writer or tableWriterCfg.userdata_value_writers[vType]
	if writer then return writer(v) end
	tableWriterCfg.error("Attempt to write " .. vType .. " as value")
end

function TableWriter.write_kvp(k, v)
	local kStr = TableWriter.write_key(k)
	local vStr = TableWriter.write_value(v)
	return kStr .. '=' .. vStr
end

function TableWriter.is_array(tbl)
	local is_arr = true
	for k, v in pairs(tbl) do
		if tableWriterCfg.type(k) ~= "number" then
			is_arr = false
			break
		end
	end
	return is_arr
end

function TableWriter.tbl_count(tbl)
	local i = 0
	for _, _ in pairs(tbl) do
		i = i + 1
	end
	return i
end

function TableWriter.write_arr(tbl)
	local str = '{\n'
	for i, v in ipairs(tbl) do
		str = str .. TableWriter.write_value(v)
		if i ~= #tbl then str = str .. ',\n' end
	end
	str = str .. '\n}'
	return str
end

function TableWriter.write_tbl(tbl)
	if TableWriter.is_array(tbl) then return TableWriter.write_arr(tbl) end

	local n = TableWriter.tbl_count(tbl)
	local i = 0
	local str = '{\n'
	for k, v in pairs(tbl) do
		i = i + 1
		str = str .. "\t" .. TableWriter.write_kvp(k, v):gsub("\n", "\n\t")
		if i ~= n then str = str .. ',\n' end
	end
	str = str .. '\n}'

	return str
end

function TableWriter.configure(tbl)
	for k, v in pairs(tbl) do
		local existingValue = tableWriterCfg[k]
		if existingValue ~= nil then
			tableWriterCfg[k] = v
		else 
			tableWriterCfg.warn("Attempt to set unsupported config key \"" .. k .. "\" = \"" .. tostring(v) .. "\"!")
		end
	end
end

return TableWriter