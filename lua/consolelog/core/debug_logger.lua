local M = {}

function M.is_enabled()
  local consolelog = require("consolelog")
  return consolelog.config.debug_logger and consolelog.config.debug_logger.enabled
end

function M.get_log_file()
  local consolelog = require("consolelog")
  return consolelog.config.debug_logger and consolelog.config.debug_logger.log_file or "/tmp/consolelog_debug.log"
end

function M.log(category, message, data)
  if not M.is_enabled() then return end
  
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local lines = {
    string.format("[%s] [%s] %s", timestamp, category, tostring(message))
  }
  
  if data then
    if type(data) == "table" then
      table.insert(lines, vim.inspect(data))
    else
      table.insert(lines, tostring(data))
    end
  end
  
  table.insert(lines, "")
  
  local ok, err = pcall(function()
    vim.fn.writefile(lines, M.get_log_file(), "a")
  end)
  
  if not ok then
    vim.schedule(function()
      vim.fn.writefile(lines, M.get_log_file(), "a")
    end)
  end
end

function M.clear()
  vim.fn.writefile({}, M.get_log_file())
  M.log("SYSTEM", "Log cleared")
end

function M.toggle()
  local consolelog = require("consolelog")
  if consolelog.config.debug_logger then
    consolelog.config.debug_logger.enabled = not consolelog.config.debug_logger.enabled
    vim.notify("ConsoleLog debug logging: " .. (consolelog.config.debug_logger.enabled and "enabled" or "disabled"))
  end
end

function M.open()
  vim.cmd("edit " .. M.get_log_file())
end

function M.open_debug_window()
  vim.cmd("edit " .. M.get_log_file())
  vim.bo.filetype = "log"
  vim.bo.autoread = true
  vim.cmd("normal! G")
  
  vim.api.nvim_buf_set_keymap(0, "n", "r", ":checktime | normal! G<CR>", {
    noremap = true,
    silent = true,
    desc = "Refresh log"
  })
  
  vim.api.nvim_buf_set_keymap(0, "n", "c", "", {
    noremap = true,
    silent = true,
    callback = function()
      M.clear()
      vim.cmd("checktime")
    end,
    desc = "Clear log"
  })
  
  vim.api.nvim_echo({
    { "ConsoleLog Debug: ", "Title" },
    { "r", "Special" },
    { " refresh | ", "Normal" },
    { "c", "Special" },
    { " clear", "Normal" },
  }, false, {})
end

return M