--[[
	GLUt // GoodLuaUtilities // Lua5.1 utilities module
	
	© Sprixitite, 2025
]]

local GLUt = {}

local GLUtCfg = {
	print = print,
	warn  = function(...) print("WARNING", ...) end,
	error = error,
	type  = type
}

local patternSpecChars = { '(', ')', '.', '%', '+', '-', '*', '?', '[', ']', '^', '$' }

function GLUt.configure(tbl)
	for k, v in pairs(tbl) do
		if GLUtCfg[k] ~= nil then
			GLUtCfg[k] = v
		else
			GLUtCfg.warn("Attempt to set invalid GLUtCfg Key \"" .. tostring(k) .. "\"")
		end
	end
end

function GLUt.default(arg, default)
	return (arg == nil) and default or arg
end

function GLUt.typecheck(arg, expected, argName, fName)
	local argType = GLUtCfg.type(arg)
	
	expected = string.gsub(expected, '?', "|nil")
	for _, validType in pairs(GLUt.str_split(expected, '|')) do
		if validType == argType then return true end
	end
	
	if argName ~= nil then
		local w = (GLUtCfg.type(fName)~="string") and "Expected arg \"" or fName .. ": expected arg \""
		GLUtCfg.warn(w .. argName .. "\" of type \"" .. expected .. "\" got type \"" .. argType .. "\"!")
	end
	
	return false
end

function GLUt.vararg_capture(...)
	local n = select('#', ...)
	return n, { ... }
end

function GLUt.vararg_iter(...)
	local n, t = GLUt.vararg_capture(...)
	local i = 0
	return function()
		i = i + 1
		if i <= n then return i, t[i], n end
	end, t
end

function GLUt.str_split(str, separator)
	str = str .. separator
	separator = GLUt.str_escape_pattern(separator)
	
	local substrs = {}
	for substr in string.gmatch(str, "(.-)" .. separator) do
		substrs[#substrs+1] = substr
	end
	return substrs
end

function GLUt.str_escape_pattern(str)
	local escaped = str
	for _, specChar in ipairs(patternSpecChars) do
		local escapedSpec = '%' .. specChar
		escaped = string.gsub(escaped, escapedSpec, (specChar == '%') and "%%" or '%' .. escapedSpec)
	end
	return escaped
end

function GLUt.str_double_substr(str, substr)
	local safe = GLUt.str_escape_pattern(substr)
	return string.gsub(str, safe, safe .. safe)
end

function GLUt.str_isempty(str)
	return string.match(str, "^%s$") ~= nil
end

function GLUt.str_chariter(str)
	local n = #str
	local i = 0
	return function()
		i = i + 1
		if i <= n then return GLUt.str_getchar(str, i) end
	end
end

function GLUt.str_getchar(str, i)
	return string.sub(str, i, i)
end

function GLUt.kvp_tostring(k, v)
	return tostring(k) .. " = " .. tostring(v)
end

function GLUt.tbl_tryindex(tbl, ...)
	local indexing = tbl
	for _, k in GLUt.vararg_iter(...) do
		if GLUtCfg.type(indexing) ~= "table" then
			return false, indexing
		end
		indexing = indexing[tostring(k)]
	end

	return true, indexing
end

function GLUt.tbl_clone(tbl, shallow)
	shallow = GLUt.default(shallow, false)
	
	local cloned = {}
	for k, v in pairs(tbl) do
		if GLUtCfg.type(v) == "table" and not shallow then
			cloned[k] = GLUt.tbl_clone(v, shallow)
		else
			cloned[k] = v
		end
	end
	return cloned
end

function GLUt.tbl_findsize(tbl)
	local i = 0
	for _, _ in pairs(tbl) do i = i + 1 end
	return i
end

local function tbl_tostring(tblName, tbl, levels, level)
	local str = tblName .. " = {"
	local indent = string.rep("  ", level)
	local n = GLUt.tbl_findsize(tbl)
	local i = 0
	for k, v in pairs(tbl) do
		i = i + 1
		str = str .. '\n' .. indent
		if GLUtCfg.type(v) == "table" and levels > level then
			str = str .. tbl_tostring(k, v, levels, level+1)
		else
			str = str .. GLUt.kvp_tostring(k, v)
		end
		if i < n then str = str .. ',' end
	end
	return str
end

function GLUt.tbl_tostring(tbl, levels, tblName)
	GLUt.default(tblName, tostring(tbl))
	return tbl_tostring(tblName, tbl, levels, 1)
end

return GLUt