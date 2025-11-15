local M = {}

local utils = require("consolelog.core.utils")

-- Check if a buffer should be processed by consolelog
local function should_process_buffer(bufnr)
	return utils.is_javascript_buffer(bufnr)
end

-- Export the function for use by other modules
M.should_process_buffer = should_process_buffer

function M.setup()
	local group = vim.api.nvim_create_augroup("ConsoleLog", { clear = true })

	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		callback = function()
			local bufnr = vim.api.nvim_get_current_buf()

			if not should_process_buffer(bufnr) then
				return
			end

			local consolelog = require("consolelog")
			consolelog.active_buf = bufnr

			-- Show outputs for the newly active buffer if they exist
			if consolelog.config.enabled and consolelog.outputs[bufnr] and not vim.tbl_isempty(consolelog.outputs[bufnr]) then
				require("consolelog.display.display").show_outputs(bufnr)
			end
		end,
	})



	-- Clear outputs only when buffer is reloaded from disk
	vim.api.nvim_create_autocmd("BufReadPost", {
		group = group,
		callback = function()
			local bufnr = vim.api.nvim_get_current_buf()

			if not should_process_buffer(bufnr) then
				return
			end

			local consolelog = require("consolelog")
			local line_matching = require("consolelog.processing.line_matching")

		-- Mark buffer as ready for processing (if using new method)
		if line_matching.set_buffer_ready then
			line_matching.set_buffer_ready(bufnr, true)
		end

			-- Clear outputs for this buffer on reload
			if consolelog.outputs[bufnr] then
				local debug_logger = require("consolelog.core.debug_logger")
				debug_logger.log("BUFREADPOST", string.format("Clearing outputs for buffer %d", bufnr))
				consolelog.outputs[bufnr] = {}
				require("consolelog.display.display").clear_buffer(bufnr)
			end
		end,
	})

	-- Mark buffer as ready when it's written
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		callback = function()
			local bufnr = vim.api.nvim_get_current_buf()

			if not should_process_buffer(bufnr) then
				return
			end

			local line_matching = require("consolelog.processing.line_matching")
			if line_matching.set_buffer_ready then
				line_matching.set_buffer_ready(bufnr, true)
			end
		end,
	})
end

return M

