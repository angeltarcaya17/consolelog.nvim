local M = {}

function M.detect_value_type(value)
	if value:match("^%[.*%]$") then return "array" end
	if value:match("^{.*}$") then return "object" end
	if value:match("^['\"].*['\"]$") then return "string" end
	if value:match("^%-?%d+%.?%d*$") then return "number" end
	if value == "true" or value == "false" then return "boolean" end
	if value == "null" or value == "nil" or value == "undefined" then return "null" end
	return "unknown"
end

return M
