local M = {}

function M.setup(config)
	if not config.keymaps or not config.keymaps.enabled then
		return
	end

	local keymaps = config.keymaps

	local function set_keymap(key, command, desc)
		if key and key ~= "" then
			vim.keymap.set("n", key, command, { desc = desc, silent = true })
		end
	end

	set_keymap(keymaps.toggle, ":ConsoleLogToggle<CR>", "Toggle ConsoleLog")
	set_keymap(keymaps.run, ":ConsoleLogRun<CR>", "Run current file with ConsoleLog")
	set_keymap(keymaps.clear, ":ConsoleLogClear<CR>", "Clear console outputs")
	set_keymap(keymaps.inspect, ":ConsoleLogInspect<CR>", "Inspect console output at cursor line")
	set_keymap(keymaps.inspect_all, ":ConsoleLogInspectAll<CR>", "Inspect all console outputs (all buffers)")
	set_keymap(keymaps.inspect_buffer, ":ConsoleLogInspectBuffer<CR>", "Inspect all outputs for current buffer")
	set_keymap(keymaps.reload, ":ConsoleLogReload<CR>", "Reload ConsoleLog plugin")
	set_keymap(keymaps.debug_toggle, ":ConsoleLogDebugToggle<CR>", "Toggle debug logging on/off")
end

return M
