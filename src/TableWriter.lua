local TableWriter = {}

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
		return "\"" .. tostring(v):gsub("\n", "\\n"):gsub("\t", "\\t") .. "\""
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
	Color3 = function(v)
		return `Color3.fromRGB({v.R},{v.G},{v.B})`
	end,
}

function TableWriter.write_key(k)
	local kType = typeof(k)
	local writer = keyWriters[kType]
	if writer then return writer(k) end
	error(`Attempt to write {kType} as key`)
end

function TableWriter.write_value(v)
	local vType = typeof(v)
	local writer = valueWriters[vType]
	if writer then return writer(v) end
	error(`Attempt to write {vType} as value`)
end

function TableWriter.write_kvp(k, v)
	local kStr = TableWriter.write_key(k)
	local vStr = TableWriter.write_value(v)
	return kStr .. '=' .. vStr
end

function TableWriter.is_array(tbl)
	local is_arr = true
	for k, v in pairs(tbl) do
		if type(k) ~= "number" then
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
	local str = '{'
	for i, v in ipairs(tbl) do
		str = str .. TableWriter.write_value(v)
		if i ~= #tbl then str = str .. ',' end
	end
	str = str .. '}'
	return str
end

function TableWriter.write_tbl(tbl)
	if TableWriter.is_array(tbl) then return TableWriter.write_arr(tbl) end
	
	local n = TableWriter.tbl_count(tbl)
	local i = 0
	local str = '{'
	for k, v in pairs(tbl) do
		i = i + 1
		str = str .. TableWriter.write_kvp(k, v)
		if i ~= n then str = str .. ',' end
	end
	str = str .. '}'
	
	return str
end

return TableWriter