local M = {}
local debug_logger = require("consolelog.core.debug_logger")

function M.detect(project_root)
  local package_json = project_root .. "/package.json"
  if vim.fn.filereadable(package_json) == 1 then
    local content = table.concat(vim.fn.readfile(package_json), "\n")
    return content:match('"vue"') ~= nil and not content:match('"vite"')
  end
  return false
end

function M.patch(project_root, ws_port)
  debug_logger.log("VUE_PATCH", string.format("Patching Vue app for port %d", ws_port))
  
  local project_id = vim.fn.fnamemodify(project_root, ":t")
  
  local current_file = debug.getinfo(1, "S").source:sub(2)
  local plugin_dir = vim.fn.fnamemodify(current_file, ":p"):match("(.*[/\\]consolelog%.nvim[/\\])")
  if not plugin_dir then
    plugin_dir = vim.fn.fnamemodify(current_file, ":p:h:h:h:h:h")
  end
  
  local inject_script_path = plugin_dir .. "js/inject-client.js"
  local sourcemap_script_path = plugin_dir .. "js/sourcemap-resolver.js"
  if vim.fn.filereadable(inject_script_path) ~= 1 then
    debug_logger.log("VUE_PATCH", "ERROR: inject-client.js not found")
    return false
  end
  
  local inject_content = table.concat(vim.fn.readfile(inject_script_path), "\n")
  
  local sourcemap_content = ""
  if vim.fn.filereadable(sourcemap_script_path) == 1 then
    sourcemap_content = table.concat(vim.fn.readfile(sourcemap_script_path), "\n")
    debug_logger.log("vue_PATCH", "Including source map resolver")
  end
  
  local injection_script = string.format("window.__CONSOLELOG_WS_PORT = %d; window.__CONSOLELOG_PROJECT_ID = '%s'; %s %s", ws_port, project_id, sourcemap_content, inject_content)
  
  local index_html = project_root .. "/public/index.html"
  if vim.fn.filereadable(index_html) == 1 then
    local content = table.concat(vim.fn.readfile(index_html), "\n")
    
    if not content:match("ConsoleLog%.nvim auto%-injection") then
      local script_tag = string.format("  <!-- ConsoleLog.nvim auto-injection -->\n  <script>\n%s\n  </script>", injection_script)
      content = content:gsub("</head>", script_tag .. "\n</head>")
      vim.fn.writefile(vim.split(content, "\n"), index_html)
      debug_logger.log("VUE_PATCH", "Patched public/index.html")
      vim.notify("ConsoleLog: Vue app patched. Restart dev server.", vim.log.levels.INFO)
      return true
    else
      debug_logger.log("VUE_PATCH", "Already patched")
      return true
    end
  end
  
  debug_logger.log("VUE_PATCH", "No index.html found")
  return false
end

function M.unpatch(project_root)
  local index_html = project_root .. "/public/index.html"
  if vim.fn.filereadable(index_html) == 1 then
    local content = table.concat(vim.fn.readfile(index_html), "\n")
    local pattern = "  <!%-%- ConsoleLog%.nvim auto%-injection %-%->.-</script>"
    local new_content = content:gsub(pattern, "")
    
    if new_content ~= content then
      vim.fn.writefile(vim.split(new_content, "\n"), index_html)
      debug_logger.log("VUE_PATCH", "Unpatched index.html")
    end
  end
end

return M
