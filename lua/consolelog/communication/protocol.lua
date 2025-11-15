local M = {}

local display = require("consolelog.display.display")

M.pending_responses = {}

function M.handle_message(session, raw_message)
	local ok, message = pcall(vim.json.decode, raw_message)
	if not ok then
		return
	end



	if message.method then
		M.handle_event(session, message)
	elseif message.id then
		M.handle_response(session, message)
	end
end

function M.handle_event(session, message)
	if message.method == "Runtime.consoleAPICalled" then
		M.handle_console_event(session, message.params)
	elseif message.method == "Runtime.exceptionThrown" then
		M.handle_exception_event(session, message.params)
	elseif message.method == "Debugger.paused" then
		require("consolelog.communication.inspector").send_command(session, "Debugger.resume", {})
	elseif message.method == "Inspector.detached" then
		vim.schedule(function()
			vim.notify("Debugger detached: " .. (message.params.reason or "unknown"), vim.log.levels.WARN)
		end)
	end
end

function M.handle_console_event(session, params)
	local console_type = params.type
	local args = params.args or {}

	if #args == 0 then
		return
	end

	local values = {}
	local raw_values = {}
	for _, arg in ipairs(args) do
		local value = M.extract_value(arg)
		table.insert(values, value)
		-- Store raw JSON for objects/arrays
		if arg.type == "object" and arg.preview then
			table.insert(raw_values, vim.json.encode(arg))
		else
			table.insert(raw_values, value)
		end
	end

	local output_text = table.concat(values, " ")
	local raw_text = nil

	-- If we have a single object/array, store its raw value
	if #args == 1 and args[1].type == "object" then
		raw_text = vim.json.encode(args[1])
	elseif #raw_values > 0 then
		raw_text = table.concat(raw_values, " ")
	end

	if console_type == "error" then
		output_text = "❌ " .. output_text
	elseif console_type == "warn" then
		output_text = "⚠️  " .. output_text
	elseif console_type == "info" then
		output_text = "ℹ️  " .. output_text
	elseif console_type == "debug" then
		output_text = "🐛 " .. output_text
	end

	local line_number = M.extract_line_number(params.stackTrace, session.filepath)

	if line_number then
		display.update_output(session.bufnr, line_number, output_text, console_type, raw_text)
	end
end

function M.handle_exception_event(session, params)
	local exception = params.exceptionDetails
	if not exception then
		return
	end

	local text = exception.text or "Unknown exception"
	if exception.exception and exception.exception.description then
		text = exception.exception.description
	end

	local line_number = nil
	if exception.stackTrace then
		line_number = M.extract_line_number(exception.stackTrace, session.filepath)
	elseif exception.lineNumber then
		line_number = exception.lineNumber
	end

	if line_number then
		display.update_output(session.bufnr, line_number, "💥 " .. text, "error")
	end
end

function M.extract_value(arg)
	if arg.type == "string" then
		return arg.value
	elseif arg.type == "number" then
		return tostring(arg.value)
	elseif arg.type == "boolean" then
		return tostring(arg.value)
	elseif arg.type == "undefined" then
		return "undefined"
	elseif arg.type == "symbol" then
		return arg.description or "Symbol()"
	elseif arg.type == "bigint" then
		return tostring(arg.value) .. "n"
	elseif arg.type == "object" then
		if arg.subtype == "null" then
			return "null"
		elseif arg.subtype == "array" then
			return M.format_array_preview(arg)
		elseif arg.subtype == "regexp" then
			return arg.description or "/regex/"
		elseif arg.subtype == "date" then
			return arg.description or "Date"
		elseif arg.subtype == "map" then
			return M.format_map_preview(arg)
		elseif arg.subtype == "set" then
			return M.format_set_preview(arg)
		elseif arg.subtype == "error" then
			return arg.description or "Error"
		else
			return M.format_object_preview(arg)
		end
	elseif arg.type == "function" then
		return M.format_function_preview(arg)
	else
		return vim.inspect(arg.value or arg.description or arg.type)
	end
end

function M.format_array_preview(arg)
	if arg.preview and arg.preview.properties then
		local items = {}
		local count = 0
		for _, prop in ipairs(arg.preview.properties) do
			if prop.name and tonumber(prop.name) then
				count = count + 1
				if count <= 5 then
					table.insert(items, prop.value or "...")
				end
			end
		end
		if count > 5 then
			table.insert(items, "...")
		end
		return "[" .. table.concat(items, ", ") .. "]"
	end
	return arg.description or "[]"
end

function M.format_object_preview(arg)
	if arg.className then
		return "[" .. arg.className .. "]"
	elseif arg.preview and arg.preview.properties then
		local props = {}
		for i, prop in ipairs(arg.preview.properties) do
			if i <= 3 then
				local value = prop.value or "..."
				if prop.valuePreview then
					value = M.format_value_preview(prop.valuePreview)
				end
				table.insert(props, prop.name .. ": " .. value)
			end
		end
		if #arg.preview.properties > 3 then
			table.insert(props, "...")
		end
		return "{ " .. table.concat(props, ", ") .. " }"
	end
	return arg.description or "{}"
end

function M.format_value_preview(preview)
	if preview.type == "object" then
		if preview.subtype == "array" then
			return "[...]"
		else
			return "{...}"
		end
	else
		return preview.value or preview.description or "..."
	end
end

function M.format_map_preview(arg)
	if arg.preview and arg.preview.entries then
		local entries = {}
		for i, entry in ipairs(arg.preview.entries) do
			if i <= 3 then
				local key = entry.key and entry.key.value or "?"
				local value = entry.value and entry.value.value or "?"
				table.insert(entries, key .. " => " .. value)
			end
		end
		if #arg.preview.entries > 3 then
			table.insert(entries, "...")
		end
		return "Map { " .. table.concat(entries, ", ") .. " }"
	end
	return arg.description or "Map {}"
end

function M.format_set_preview(arg)
	if arg.preview and arg.preview.entries then
		local values = {}
		for i, entry in ipairs(arg.preview.entries) do
			if i <= 5 then
				table.insert(values, entry.value and entry.value.value or "?")
			end
		end
		if #arg.preview.entries > 5 then
			table.insert(values, "...")
		end
		return "Set { " .. table.concat(values, ", ") .. " }"
	end
	return arg.description or "Set {}"
end

function M.format_function_preview(arg)
	local name = arg.description or "anonymous"
	name = name:match("^function%s+(%w+)") or name:match("^(%w+)") or "anonymous"
	return "[Function: " .. name .. "]"
end

function M.extract_line_number(stackTrace, filepath)
	if not stackTrace or not stackTrace.callFrames then
		return nil
	end

	local filename = vim.fn.fnamemodify(filepath, ":t")
	local full_path = vim.fn.fnamemodify(filepath, ":p")

	for _, frame in ipairs(stackTrace.callFrames) do
		if frame.url then
			local frame_file = frame.url:match("([^/]+)$")
			local frame_path = frame.url:match("file://(.+)$")

			if frame_file == filename or frame_path == full_path then
				return frame.lineNumber + 1
			end
		end
	end

	if #stackTrace.callFrames > 0 then
		local first_frame = stackTrace.callFrames[1]
		if first_frame.lineNumber then
			return first_frame.lineNumber + 1
		end
	end

	return nil
end

function M.handle_response(session, message)
	if M.pending_responses[message.id] then
		local callback = M.pending_responses[message.id]
		M.pending_responses[message.id] = nil

		if message.error then
			vim.notify("Inspector error: " .. (message.error.message or "Unknown error"),
				vim.log.levels.ERROR)
		elseif callback then
			callback(message.result)
		end
	end
end

function M.register_response_callback(id, callback)
	M.pending_responses[id] = callback
end

return M

