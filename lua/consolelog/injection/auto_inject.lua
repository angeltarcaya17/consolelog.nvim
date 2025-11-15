local M = {}

local uv = vim.loop
local debug_logger = require("consolelog.core.debug_logger")

M.active_projects = {} -- { project_root = { ws_server, ports, patched, project_root } }


-- Setup injection for a project
function M.setup_project(project_root, force_repatch)
	local instance_key = project_root .. "_" .. vim.fn.getpid()
	debug_logger.log("SETUP", string.format("Setting up project: %s (instance: %s, force: %s)", project_root, instance_key, tostring(force_repatch)))

	-- If force_repatch, clear existing entry to ensure re-patching
	if force_repatch and M.active_projects[instance_key] then
		debug_logger.log("SETUP", "Force re-patch - clearing existing project entry")
		M.active_projects[instance_key] = nil
	end

	-- Check if already setup for this instance
	if M.active_projects[instance_key] and not force_repatch then
		debug_logger.log("SETUP", "Project already setup for this instance, returning existing ports")
		return M.active_projects[instance_key].ports
	end

	-- Only clear outputs when starting a NEW project session
	local consolelog = require("consolelog")
	local message_processor = require("consolelog.processing.message_processor_impl")
	consolelog.clear()
	message_processor.reset_matched_lines()

	-- Clean up any stale port files first
	local port_manager = require("consolelog.communication.port_manager")
	port_manager.cleanup_stale_ports(project_root)

	-- Allocate ports
	local port_manager = require("consolelog.communication.port_manager")
	local ports = port_manager.allocate_ports(project_root)
	if not ports then
		vim.notify("ConsoleLog: Failed to allocate ports for " .. project_root, vim.log.levels.ERROR)
		return nil
	end

	-- Use the injector manager to patch the appropriate framework
	local injector_manager = require("consolelog.injection.injectors.manager")
	local patched, framework = injector_manager.patch(project_root, ports.ws_port)

	if patched then
		debug_logger.log("SETUP", string.format("Successfully patched %s for port %d", framework, ports.ws_port))
	else
		debug_logger.log("SETUP", "Framework patching failed or not applicable - using direct WebSocket only")
	end

	-- Start WebSocket server directly to Neovim
	local ws_server = require("consolelog.communication.ws_server")
	local actual_port = ws_server.start(ports.ws_port)

	if not actual_port then
		debug_logger.log("SETUP", "Failed to start WebSocket server, cleaning up")
		-- Clean up port allocation if server fails
		port_manager.release_ports(project_root)
		return nil
	end

	M.active_projects[instance_key] = {
		ws_server = ws_server,
		ports = ports,
		patched = patched,
		project_root = project_root
	}

	if patched then
		local consolelog = require("consolelog")
		if framework == "nextjs" then
			consolelog.notify(
				string.format("ConsoleLog: Next.js patched (Port %d). Restart dev server to apply changes.",
					ports.ws_port), vim.log.levels.INFO)
		elseif not M.active_projects[instance_key .. "_notified"] then
			consolelog.notify(
				string.format("ConsoleLog: Browser console capture ready (Port %d). Restart dev server if needed.",
					ports.ws_port), vim.log.levels.INFO)
			M.active_projects[instance_key .. "_notified"] = true
		end
	end

	return ports
end

-- Stop injection for a project
function M.stop_project(project_root)
	local instance_key = project_root .. "_" .. vim.fn.getpid()
	local project = M.active_projects[instance_key]
	if not project then return end

	local debug_logger = require("consolelog.core.debug_logger")
	debug_logger.log("STOP_PROJECT", "Stopping project: " .. project_root)

	if project.ws_server then
		debug_logger.log("STOP_PROJECT", "Sending shutdown to clients")
		project.ws_server.shutdown_clients()
		
		vim.defer_fn(function()
			debug_logger.log("STOP_PROJECT", "Stopping WebSocket server")
			project.ws_server.stop()
		end, 200)
	end

	require("consolelog.communication.port_manager").release_ports(project_root)

	local injector_manager = require("consolelog.injection.injectors.manager")
	injector_manager.unpatch(project_root)

	M.active_projects[instance_key] = nil
	M.setup_complete[instance_key] = nil

	vim.notify("ConsoleLog: Stopped for " .. vim.fn.fnamemodify(project_root, ":t"), vim.log.levels.INFO)
end

-- Auto-detect and setup when opening a file
-- Track last setup time per project
M.last_setup_time = {}
-- Track if project is fully setup for this vim session
M.setup_complete = {}

function M.auto_setup()
	local port_manager = require("consolelog.communication.port_manager")
	local debug_logger = require("consolelog.core.debug_logger")

	local project_root = port_manager.find_project_root()
	if not project_root then
		debug_logger.log("AUTO_SETUP", "No project root found")
		return
	end

	-- If already completely setup for this vim session, skip entirely
	local session_key = project_root .. "_" .. vim.fn.getpid()
	if M.setup_complete[session_key] then
		debug_logger.log("AUTO_SETUP", "Project already fully setup for this session")
		return
	end

	debug_logger.log("AUTO_SETUP", "Starting auto_setup")

	-- Check cooldown per project (10 seconds)
	local now = vim.loop.now()
	if M.last_setup_time[project_root] and (now - M.last_setup_time[project_root]) < 10000 then
		debug_logger.log("AUTO_SETUP", "Skipping - project setup cooldown active")
		return
	end
	M.last_setup_time[project_root] = now

	debug_logger.log("AUTO_SETUP", string.format("Project root: %s", project_root))

	-- Use the improved detection from port_manager
	local is_nextjs = port_manager.is_nextjs_project(project_root)
	debug_logger.log("AUTO_SETUP", string.format("Is Next.js project: %s", tostring(is_nextjs)))

	if is_nextjs then
		-- Enable ConsoleLog if not already enabled
		local consolelog = require("consolelog")
		if not consolelog.config.enabled then
			consolelog.config.enabled = true
		end

		debug_logger.log("AUTO_SETUP", "Setting up project injection")
		M.setup_project(project_root)

		-- Mark as complete for this session
		M.setup_complete[session_key] = true
		debug_logger.log("AUTO_SETUP", "Project setup complete for session")
	else
		-- Check for other project types
		local package_json = project_root .. "/package.json"
		if vim.fn.filereadable(package_json) == 1 then
			local content = table.concat(vim.fn.readfile(package_json), "\n")

			-- Check if it's a browser project using the injector manager
			local injector_manager = require("consolelog.injection.injectors.manager")
			local is_browser_project = injector_manager.is_browser_project(project_root)

			debug_logger.log("AUTO_SETUP",
				string.format("Is browser project: %s", tostring(is_browser_project)))

			if is_browser_project then
				debug_logger.log("AUTO_SETUP", "Detected browser project")

				-- Enable ConsoleLog if not already enabled
				local consolelog = require("consolelog")
				if not consolelog.config.enabled then
					consolelog.config.enabled = true
				end

				-- Setup project for Vite/React/Vue
				M.setup_project(project_root)
				debug_logger.log("AUTO_SETUP", "Called setup_project for browser project")
			end
		end
	end
end

-- Stop all projects
function M.stop_all()
	for instance_key, project_info in pairs(M.active_projects) do
		if type(project_info) == "table" and project_info.project_root then
			M.stop_project(project_info.project_root)
		end
	end
end

return M

