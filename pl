#!/usr/bin/env lua
-- The MIT License (MIT)
-- Copyright (c) 2025-present NEOAPPS <neo@obsidianos.xyz>
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
-- the Software, and to permit persons to whom the Software is furnished to do so,
-- subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
-- FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
-- COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
-- IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
-- CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

local VERSION = "1.0.0"
local ROOT = ""
local REPO_DIR = os.getenv("HOME") .. "/.local/share/pkglet/repos"
local CACHE_DIR = os.getenv("HOME") .. "/.cache/pkglet"
local DB_FILE = os.getenv("HOME") .. "/.local/share/pkglet/installed.db"
local CONFIG_FILE = os.getenv("HOME") .. "/.config/pkglet/config.lua"
local CURRENT_SOURCE_BASE_DIR = nil
local COLOR_RESET = "\027[0m"
local COLOR_RED = "\027[31m"
local COLOR_GREEN = "\027[32m"
local COLOR_YELLOW = "\027[33m"
local COLOR_BLUE = "\027[34m"
local COLOR_MAGENTA = "\027[35m"
local COLOR_CYAN = "\027[36m"
local COLOR_WHITE = "\027[37m"
local COLOR_BRIGHT_BLACK = "\027[90m"
local COLOR_BRIGHT_RED = "\027[91m"
local COLOR_BRIGHT_GREEN = "\027[92m"
local COLOR_BRIGHT_YELLOW = "\027[93m"
local COLOR_BRIGHT_BLUE = "\027[94m"
local COLOR_BRIGHT_MAGENTA = "\027[95m"
local COLOR_BRIGHT_CYAN = "\027[96m"
local COLOR_BRIGHT_WHITE = "\027[97m"
local function truncate(str, max)
	if #str > max then
		return string.sub(str, 1, max - 3) .. "..."
	else
		return str
	end
end
local function shell_escape(s)
	return "'" .. s:gsub("'", "'" .. "\\" .. "'" .. "'") .. "'"
end

local function dirname(path)
	local dir = path:match("^(.*)/[^/]*$")
	return dir
end
local function get_db_file()
	if ROOT ~= "" then
		return ROOT .. "/.pkglet.db"
	end
	return DB_FILE
end
local function init_filesystem(root)
	local dirs = {
		"/usr",
		"/usr/bin",
		"/usr/lib",
		"/usr/lib64",
		"/usr/local",
		"/usr/local/bin",
		"/usr/local/sbin",
		"/usr/local/lib",
		"/usr/share",
		"/usr/share/man",
		"/usr/share/man/man1",
		"/usr/share/doc",
		"/etc",
		"/etc/default",
		"/var",
		"/var/log",
		"/var/cache",
		"/var/tmp",
		"/var/lib",
		"/tmp",
		"/opt",
		"/boot",
		"/home",
		"/root",
		"/dev",
		"/proc",
		"/sys",
		"/run",
		"/mnt",
		"/srv",
		"/media",
	}

	print(COLOR_BRIGHT_BLUE .. "Initializing filesystem at " .. root .. "..." .. COLOR_RESET)
	for _, dir in ipairs(dirs) do
		os.execute("mkdir -p " .. root .. dir)
	end

	print(COLOR_BRIGHT_BLUE .. "Creating essential symlinks..." .. COLOR_RESET)
	os.execute("ln -sf usr/bin " .. root .. "/bin 2>/dev/null")
	os.execute("ln -sf usr/bin " .. root .. "/sbin 2>/dev/null")
	os.execute("ln -sf usr/lib " .. root .. "/lib 2>/dev/null")
	os.execute("ln -sf usr/lib64 " .. root .. "/lib64 2>/dev/null")
	print(COLOR_BRIGHT_BLUE .. "Creating /etc/passwd and /etc/shadow and /etc/hostname..." .. COLOR_RESET)
	os.execute("echo 'root:x:0:0:root:/root:/bin/bash' > " .. root .. "/etc/passwd")
	os.execute("echo 'root:!:18800:0:99999:7:::' > " .. root .. "/etc/shadow")
	os.execute("echo 'null' > " .. root .. "/etc/hostname")
	print(COLOR_BRIGHT_BLUE .. "Creating /etc/os-release..." .. COLOR_RESET)
	os.execute("echo 'NAME=\"NULL GNU/Linux\"' > " .. root .. "/etc/os-release")
	os.execute("echo 'PRETTY_NAME=\"NULL GNU/Linux\"' >> " .. root .. "/etc/os-release")
	os.execute("echo 'ID=nullos' >> " .. root .. "/etc/os-release")
	os.execute("echo 'BUILD_ID=rolling' >> " .. root .. "/etc/os-release")
	os.execute("echo 'ANSI_COLOR=\"38;2;138;43;226\"' >> " .. root .. "/etc/os-release")
	os.execute("echo 'HOME_URL=\"https://github.com/NULL-GNU-Linux\"' >> " .. root .. "/etc/os-release")
	os.execute("echo 'DOCUMENTATION_URL=\"https://github.com/NULL-GNU-Linux\"' >> " .. root .. "/etc/os-release")
	os.execute(
		"echo 'SUPPORT_URL=\"https://github.com/orgs/NULL-GNU-Linux/discussions\"' >> " .. root .. "/etc/os-release"
	)
	os.execute(
		"echo 'BUG_REPORT_URL=\"https://github.com/orgs/NULL-GNU-Linux/discussions\"' >> " .. root .. "/etc/os-release"
	)
	os.execute("echo 'PRIVACY_POLICY_URL=\"no-data-collection\"' >> " .. root .. "/etc/os-release")
	os.execute("echo 'LOGO=nullos' >> " .. root .. "/etc/os-release")
	print(COLOR_GREEN .. "✓ Filesystem initialized" .. COLOR_RESET)
end

local function ensure_dirs()
	os.execute("mkdir -p " .. REPO_DIR)
	os.execute("mkdir -p " .. CACHE_DIR)
	os.execute("mkdir -p " .. os.getenv("HOME") .. "/.local/share/pkglet")
	os.execute("mkdir -p " .. os.getenv("HOME") .. "/.config/pkglet")
end

local function resolve_path(path)
	local f = io.popen("realpath " .. shell_escape(path))
	if f then
		local full_path = f:read("*a")
		f:close()
		return full_path:gsub("s+$", ""):match("^%s*(.-)%s*$")
	end
	return path
end

local save_config
local function load_config()
	local f = io.open(CONFIG_FILE, "r")
	if not f then
		local default_config_table = {
			repos = {
				{
					name = "main",
					url = "https://github.com/NULL-GNU-Linux/pl-main.git",
					description = "The official Pkglet repo for NULL GNU/Linux",
				},
			},
		}
		save_config(default_config_table)
	else
		f:close()
	end
	return dofile(CONFIG_FILE)
end

save_config = function(config)
	local f = io.open(CONFIG_FILE, "w")
	f:write("config = {\n")
	f:write("        repos = {\n")
	for _, repo in ipairs(config.repos) do
		f:write(
			string.format(
				'                {\n                        name = "%s",\n                        url = "%s",\n                        description = "%s"\n                },\n',
				repo.name,
				repo.url,
				repo.description
			)
		)
	end
	f:write("        }\n")
	f:write("}\n")
	f:write("return config\n")
	f:close()
end

local function load_db()
	local db_file = get_db_file()
	local f = io.open(db_file, "r")
	if not f then
		local f_write = io.open(db_file, "w")
		if f_write then
			f_write:write("{\n}\n")
			f_write:close()
		end
		return {}
	end
	local content = f:read("*all")
	f:close()
	if content == "" then
		return {}
	end
	return load("return " .. content)()
end

local function save_db(db)
	local db_file = get_db_file()
	local f = io.open(db_file, "w")
	f:write("{\n")
	for name, info in pairs(db) do
		f:write(string.format('        ["%s"] = {version = "%s", files = {', name, info.version))
		for i, file in ipairs(info.files) do
			f:write(string.format('"%s"', file))
			if i < #info.files then
				f:write(", ")
			end
		end
		f:write("}},\n")
	end
	f:write("}\n")
	f:close()
end
local function update_repos()
	local config = load_config()
	print(COLOR_BRIGHT_BLUE .. "Updating repositories..." .. COLOR_RESET)
	for _, repo in ipairs(config.repos) do
		print(COLOR_BRIGHT_CYAN .. "\n→ " .. repo.name .. COLOR_RESET)
		local repo_path = REPO_DIR .. "/" .. repo.name
		if os.execute("test -d " .. repo_path) then
			print(COLOR_BLUE .. "  Pulling updates..." .. COLOR_RESET)
			os.execute("cd " .. repo_path .. " && git pull -q")
		else
			print(COLOR_BLUE .. "  Cloning repository..." .. COLOR_RESET)
			os.execute("git clone -q " .. repo.url .. " " .. repo_path)
		end
	end
	print(COLOR_GREEN .. "\n✓ Repositories updated" .. COLOR_RESET)
end

local function add_and_update_repo(repo_source)
	print(COLOR_BRIGHT_BLUE .. "Adding repository from " .. repo_source .. "..." .. COLOR_RESET)
	local repo_content = ""
	if repo_source:match("^https?://") then
		local handle = io.popen("curl -sL " .. repo_source)
		repo_content = handle:read("*all")
		handle:close()
		if repo_content == "" then
			print(COLOR_RED .. "✗ Failed to fetch repo.lua from URL: " .. repo_source .. COLOR_RESET)
			return
		end
	else
		local f = io.open(repo_source, "r")
		if not f then
			print(COLOR_RED .. "✗ Failed to open repo.lua file: " .. repo_source .. COLOR_RESET)
			return
		end
		repo_content = f:read("*all")
		f:close()
	end
	local new_repo_func = load(repo_content)
	if not new_repo_func then
		print(COLOR_RED .. "✗ Failed to parse repo.lua content." .. COLOR_RESET)
		return
	end

	local new_repo = new_repo_func()
	if not new_repo or not new_repo.name or not new_repo.url or not new_repo.description then
		print(COLOR_RED .. "✗ Invalid repo.lua format. Missing name, url, or description." .. COLOR_RESET)
		return
	end

	local config = load_config()
	local repo_exists = false
	for _, repo in ipairs(config.repos) do
		if repo.name == new_repo.name then
			repo_exists = true
			print(
				COLOR_YELLOW
					.. "⚠ Repository with name '"
					.. new_repo.name
					.. "' already exists. Updating its URL and description."
					.. COLOR_RESET
			)
			repo.url = new_repo.url
			repo.description = new_repo.description
			break
		end
	end

	if not repo_exists then
		table.insert(config.repos, new_repo)
		print(COLOR_GREEN .. "✓ Added new repository: " .. new_repo.name .. COLOR_RESET)
	end

	save_config(config)
	update_repos()
	print(COLOR_GREEN .. "✓ Repository added and updated successfully." .. COLOR_RESET)
end

local function find_package(pkg_name)
	local config = load_config()
	for _, repo in ipairs(config.repos) do
		local repo_path = REPO_DIR .. "/" .. repo.name
		local pkg_file = pkg_name:gsub("%.", "/") .. ".lua"
		local pkg_path = repo_path .. "/" .. pkg_file
		local f = io.open(pkg_path, "r")
		if f then
			f:close()
			return pkg_path, repo.name
		end
	end
	return nil
end

local function create_hook_system()
	local hooks = {}
	return function(hook_name, options)
		return function(callback)
			if not hooks[hook_name] then
				hooks[hook_name] = {}
			end
			table.insert(hooks[hook_name], { callback = callback, options = options or {} })
		end
	end,
		hooks
end

local function print_error(message)
	io.stderr:write(COLOR_RED .. "✗ Error: " .. message .. COLOR_RESET .. "\n")
end

local function evaluate_condition(condition, current_options)
	if not condition then
		return true
	end
	for key, value in pairs(condition) do
		if current_options[key] ~= value then
			return false
		end
	end
	return true
end

local function validate_options(defined_options, provided_options)
	local validated = {}
	for name, def in pairs(defined_options) do
		local value = provided_options[name]
		if value == nil then
			if def.default ~= nil then
				validated[name] = def.default
			else
				print_error("Missing required option: " .. name)
				os.exit(1)
			end
		else
			local typeof_value = type(value)
			if def.type == "boolean" then
				if typeof_value ~= "boolean" then
					print_error("Option '" .. name .. "' must be a boolean, got " .. typeof_value)
					os.exit(1)
				end
			elseif def.type == "string" then
				if typeof_value ~= "string" then
					print_error("Option '" .. name .. "' must be a string, got " .. typeof_value)
					os.exit(1)
				end
			elseif def.type == "number" then
				if typeof_value ~= "number" then
					print_error("Option '" .. name .. "' must be a number, got " .. typeof_value)
					os.exit(1)
				end
				if def.min ~= nil and value < def.min then
					print_error("Option '" .. name .. "' must be at least " .. def.min .. ", got " .. value)
					os.exit(1)
				end
				if def.max ~= nil and value > def.max then
					print_error("Option '" .. name .. "' must be at most " .. def.max .. ", got " .. value)
					os.exit(1)
				end
			elseif def.type == "string" then
				if typeof_value ~= "string" then
					print_error("Option '" .. name .. "' must be a string, got " .. typeof_value)
					os.exit(1)
				end
				if def.from ~= nil then
					local found = false
					for _, allowed_value in ipairs(def.from) do
						if value == allowed_value then
							found = true
							break
						end
					end
					if not found then
						local allowed_values_str = table.concat(def.from, ", ")
						print_error(
							"Option '"
								.. name
								.. "' must be one of {"
								.. allowed_values_str
								.. "}, got '"
								.. value
								.. "'"
						)
						os.exit(1)
					end
				end
			else
				print_error("Unknown option type for '" .. name .. "': " .. def.type)
				os.exit(1)
			end
			validated[name] = value
		end
	end
	return validated
end
local function load_package(pkg_path, options_str, is_graph_mode)
	local pkg = {}
	pkg.files = {}
	local function install(source_path, destination_path, permissions)
		local full_dest_path = (ROOT or "") .. destination_path
		local base_source_dir = CURRENT_SOURCE_BASE_DIR or pkg_path:match("(.*)/[^/]+$")
		local full_source_path
		if source_path:sub(1, 1) == "/" then
			full_source_path = source_path
		else
			full_source_path = base_source_dir .. "/" .. source_path
		end
		if not is_graph_mode then
			print("  Installing '" .. source_path .. "' to '" .. full_dest_path .. "'")
			local parent_dir = dirname(full_dest_path)
			if parent_dir ~= nil and parent_dir ~= "" then
				os.execute("mkdir -p " .. shell_escape(parent_dir))
			end
			local success =
				os.execute("cp -r " .. shell_escape(full_source_path) .. " " .. shell_escape(full_dest_path))
			if not success then
				print_error("Failed to install '" .. source_path .. "'")
				os.exit(1)
			end
			if permissions then
				local chmod_success = os.execute("chmod " .. permissions .. " " .. shell_escape(full_dest_path))
				if not chmod_success then
					print_error("Failed to set permissions for '" .. full_dest_path .. "'")
					os.exit(1)
				end
			end
			table.insert(pkg.files, full_dest_path)
		end
	end

	local function uninstall(destination_path)
		local full_dest_path = (ROOT or "") .. destination_path
		if not is_graph_mode then
			print("  Uninstalling '" .. full_dest_path .. "'")
			local success = os.execute("rm -rf " .. shell_escape(full_dest_path))
			if not success then
				print_error("Failed to uninstall '" .. full_dest_path .. "'")
				os.exit(1)
			end
		end
	end

	local function symlink(source_path, destination_path)
		local full_source_path
		if source_path:sub(1, 1) == "/" then
			full_source_path = source_path
		else
			full_source_path = (ROOT or "") .. source_path
		end
		local full_dest_path = (ROOT or "") .. destination_path
		if not is_graph_mode then
			print("  Symlinking '" .. full_source_path .. "' to '" .. full_dest_path .. "'")
			local parent_dir = dirname(full_dest_path)
			if parent_dir ~= nil and parent_dir ~= "" then
				os.execute("mkdir -p " .. shell_escape(parent_dir))
			end
			local success =
				os.execute("ln -sf " .. shell_escape(full_source_path) .. " " .. shell_escape(full_dest_path))
			if not success then
				print_error("Failed to create symlink from '" .. full_source_path .. "' to '" .. full_dest_path .. "'")
				os.exit(1)
			end
			table.insert(pkg.files, full_dest_path)
		end
	end

	local function dump(t, name, indent)
		indent = indent or 0
		local padding = string.rep("  ", indent)
		if name then
			print(padding .. COLOR_BRIGHT_YELLOW .. name .. " = {" .. COLOR_RESET)
		else
			print(padding .. "{")
		end

		for k, v in pairs(t) do
			local new_padding = string.rep("  ", indent + 1)
			if type(v) == "table" then
				dump(v, tostring(k), indent + 1)
			else
				print(new_padding .. tostring(k) .. " = " .. tostring(v))
			end
		end
		print(padding .. "}")
	end
	local function sh(command)
		if not is_graph_mode then
			print("  Executing shell command: " .. command)
			local cd_prefix = ""
			if CURRENT_SOURCE_BASE_DIR ~= nil then
				cd_prefix = "cd " .. shell_escape(CURRENT_SOURCE_BASE_DIR) .. " && "
			end
			local full_command = cd_prefix .. command
			local success = os.execute(full_command)
			if not success then
				print_error("Shell command failed: " .. command)
				os.exit(1)
			end
		end
	end

	local function gitclone(repo_url, destination_path)
		local full_dest_path
		if destination_path:sub(1, 1) == "/" then
			full_dest_path = destination_path
		else
			full_dest_path = (ROOT or "") .. destination_path
		end
		if not is_graph_mode then
			print("  Cloning git repository '" .. repo_url .. "' to '" .. full_dest_path .. "'")
			local parent_dir = dirname(full_dest_path)
			if parent_dir ~= nil and parent_dir ~= "" then
				os.execute("mkdir -p " .. shell_escape(parent_dir))
			end
			local cd_prefix = ""
			if CURRENT_SOURCE_BASE_DIR ~= nil then
				cd_prefix = "cd " .. shell_escape(CURRENT_SOURCE_BASE_DIR) .. " && "
			end
			local full_command = cd_prefix
				.. "git clone --progress "
				.. shell_escape(repo_url)
				.. " "
				.. shell_escape(full_dest_path)
			local success = os.execute(full_command)
			if not success then
				print_error("Failed to clone git repository: " .. repo_url)
				os.exit(1)
			end
			table.insert(pkg.files, full_dest_path)
		end
	end

	local function wget(url, destination_path)
		local full_dest_path
		if destination_path:sub(1, 1) == "/" then
			full_dest_path = destination_path
		else
			full_dest_path = (ROOT or "") .. destination_path
		end
		if not is_graph_mode then
			print("  Downloading '" .. url .. "' to '" .. full_dest_path .. "'")
			local parent_dir = dirname(full_dest_path)
			if parent_dir ~= nil and parent_dir ~= "" then
				os.execute("mkdir -p " .. shell_escape(parent_dir))
			end
			local cd_prefix = ""
			if CURRENT_SOURCE_BASE_DIR ~= nil then
				cd_prefix = "cd " .. shell_escape(CURRENT_SOURCE_BASE_DIR) .. " && "
			end
			local full_command = cd_prefix
				.. "wget --show-progress -O "
				.. shell_escape(full_dest_path)
				.. " "
				.. shell_escape(url)
			local success = os.execute(full_command)
			if not success then
				print_error("Failed to download file from '" .. url .. "'")
				os.exit(1)
			end
			table.insert(pkg.files, full_dest_path)
			return full_dest_path
		end
		return ""
	end

	local function curl(url, destination_path)
		local full_dest_path
		if destination_path:sub(1, 1) == "/" then
			full_dest_path = destination_path
		else
			full_dest_path = (ROOT or "") .. destination_path
		end
		if not is_graph_mode then
			print("  Downloading '" .. url .. "' to '" .. full_dest_path .. "' using curl")
			local parent_dir = dirname(full_dest_path)
			if parent_dir ~= nil and parent_dir ~= "" then
				os.execute("mkdir -p " .. shell_escape(parent_dir))
			end
			local cd_prefix = ""
			if CURRENT_SOURCE_BASE_DIR ~= nil then
				cd_prefix = "cd " .. shell_escape(CURRENT_SOURCE_BASE_DIR) .. " && "
			end
			local full_command = cd_prefix
				.. "curl -fSL --progress-bar -o "
				.. shell_escape(full_dest_path)
				.. " "
				.. shell_escape(url)
			local success = os.execute(full_command)
			if not success then
				print_error("Failed to download file from '" .. url .. "' using curl")
				os.exit(1)
			end
			table.insert(pkg.files, full_dest_path)
			return full_dest_path
		end
		return ""
	end

	local options = {}
	if options_str and options_str ~= "{}" then
		local success, parsed_options = pcall(load, "return " .. options_str)
		if success then
			options = parsed_options()
		else
			print("Warning: Failed to parse options string: " .. options_str)
			options = {}
		end
	end
	local temp_pkg_options = {}
	setmetatable(temp_pkg_options, { __index = _G })
	local temp_chunk = loadfile(pkg_path, "t", temp_pkg_options)
	if temp_chunk then
		temp_chunk()
	end

	if is_graph_mode and temp_pkg_options.pkg and temp_pkg_options.pkg.options then
		for name, def in pairs(temp_pkg_options.pkg.options) do
			if options[name] == nil then
				if def.default ~= nil then
					options[name] = def.default
				else
					if def.type == "string" then
						options[name] = "NULL"
					elseif def.type == "number" then
						options[name] = 0
					elseif def.type == "boolean" then
						options[name] = true
					elseif def.type == "table" then
						options[name] = {}
					end
				end
			end
		end
	end

	local env = {
		os = os,
		io = io,
		print = print,
		table = table,
		string = string,
		error = error,
		tonumber = tonumber,
		tostring = tostring,
		ipairs = ipairs,
		pairs = pairs,
		ROOT = ROOT,
		pkg = pkg,
		install = install,
		uninstall = uninstall,
		symlink = symlink,
		sh = sh,
		gitclone = gitclone,
		wget = wget,
		curl = curl,
		dump = dump,
		ARCH = io.popen("uname -m"):read("*all"):gsub("%s+", ""),
		OPTIONS = options,
	}
	setmetatable(env, { __index = _G })
	local chunk = loadfile(pkg_path, "t", env)
	if not chunk then
		print_error("Failed to load package file: " .. pkg_path)
		os.exit(1)
	end
	chunk()
	for k, v in pairs(env.pkg) do
		pkg[k] = v
	end

	if pkg.options then
		options = validate_options(pkg.options, options)
		env.OPTIONS = options
	end
	return pkg
end
local function is_installed(pkg_name)
	local db = load_db()
	return db[pkg_name] ~= nil
end

local function resolve_dependencies(pkg, visited, parent_options_str)
	visited = visited or {}
	local to_install = {}
	if not pkg.depends then
		return to_install
	end
	for _, dep_full_name in ipairs(pkg.depends) do
		local build = false
		local dep_name = dep_full_name
		local dep_options_str = parent_options_str or "{}"
		if dep_full_name:match("^b/") then
			build = true
			dep_name = dep_full_name:sub(3)
		end

		local name_match, options_match = dep_name:match("^(.-){(.*)}$")
		if name_match and options_match then
			dep_name = name_match
			dep_options_str = "{" .. options_match .. "}"
		end

		if not visited[dep_name] and not is_installed(dep_name) then
			visited[dep_name] = true
			local dep_path = find_package(dep_name)
			if dep_path then
				local dep_pkg = load_package(dep_path, dep_options_str)
				local sub_deps = resolve_dependencies(dep_pkg, visited, dep_options_str)
				for _, sub_dep in ipairs(sub_deps) do
					table.insert(to_install, sub_dep)
				end
				table.insert(to_install, { name = dep_name, build = build, options = dep_options_str })
			else
				print("⚠ Warning: Dependency not found: " .. dep_name)
			end
		end
	end

	return to_install
end

local build_from_source

local function install_binary(pkg_name, skip_deps, options_str)
	local pkg_path, repo_name = find_package(pkg_name)
	if not pkg_path then
		print(COLOR_RED .. "✗ Package not found: " .. pkg_name .. COLOR_RESET)
		return false
	end

	local pkg = load_package(pkg_path, options_str)
	if not skip_deps then
		local deps = resolve_dependencies(pkg)
		if #deps > 0 then
			print(COLOR_BRIGHT_BLUE .. "\nResolving dependencies for " .. pkg_name .. ":" .. COLOR_RESET)
			for _, dep in ipairs(deps) do
				print(COLOR_BLUE .. "  → " .. dep.name .. COLOR_RESET)
			end
			print("")
			for _, dep_info in ipairs(deps) do
				if dep_info.build then
					if not build_from_source(dep_info.name, true, dep_info.options) then
						print(COLOR_RED .. "✗ Failed to build dependency: " .. dep_info.name .. COLOR_RESET)
						return false
					end
				else
					if not install_binary(dep_info.name, true, dep_info.options) then
						print(COLOR_RED .. "✗ Failed to install dependency: " .. dep_info.name .. COLOR_RESET)
						return false
					end
				end
			end
		end

		local mode_str = ROOT ~= "" and " (binary, root=" .. ROOT .. ")" or " (binary)"
		print(COLOR_BRIGHT_BLUE .. "Installing " .. pkg_name .. mode_str .. "..." .. COLOR_RESET)
		local build_dir = CACHE_DIR .. "/build/" .. pkg.name
		os.execute("rm -rf " .. build_dir)
		os.execute("mkdir -p " .. build_dir)
		CURRENT_SOURCE_BASE_DIR = build_dir
		if not pkg.binary then
			print(COLOR_RED .. "✗ Package does not support binary installation" .. COLOR_RESET)
			CURRENT_SOURCE_BASE_DIR = nil
			return false
		end

		local hook_register, hooks = create_hook_system()
		pkg.binary()(hook_register)
		local function run_hooks(hook_name)
			if hooks[hook_name] then
				for _, hook_entry in ipairs(hooks[hook_name]) do
					if evaluate_condition(hook_entry.options["if"], pkg.OPTIONS) then
						hook_entry.callback()
					end
				end
			end
		end

		run_hooks("prepare")
		run_hooks("pre_install")
		run_hooks("install")
		run_hooks("post_install")

		local db = load_db()
		db[pkg.name] = {
			version = pkg.version,
			files = pkg.files or {},
		}
		save_db(db)

		print(COLOR_GREEN .. "\n✓ " .. pkg_name .. " installed successfully" .. COLOR_RESET)
		CURRENT_SOURCE_BASE_DIR = nil
		return true
	end
end
build_from_source = function(pkg_name, skip_deps, options_str)
	local pkg_path, repo_name = find_package(pkg_name)
	if not pkg_path then
		print(COLOR_RED .. "✗ Package not found: " .. pkg_name .. COLOR_RESET)
		return false
	end

	local pkg = load_package(pkg_path, options_str)
	if not skip_deps then
		local deps = resolve_dependencies(pkg)
		if #deps > 0 then
			print(COLOR_BRIGHT_BLUE .. "\nResolving dependencies for " .. pkg_name .. ":" .. COLOR_RESET)
			for _, dep in ipairs(deps) do
				print(COLOR_BLUE .. "  → " .. dep.name .. COLOR_RESET)
			end
			print("")
			for _, dep_info in ipairs(deps) do
				if dep_info.build then
					if not build_from_source(dep_info.name, true, dep_info.options) then
						print(COLOR_RED .. "✗ Failed to build dependency: " .. dep_info.name .. COLOR_RESET)
						return false
					end
				else
					if not install_binary(dep_info.name, true, dep_info.options) then
						print(COLOR_RED .. "✗ Failed to install dependency: " .. dep_info.name .. COLOR_RESET)
						return false
					end
				end
			end
		end
	end

	local mode_str = ROOT ~= "" and " from source (root=" .. ROOT .. ")" or " from source"
	print(COLOR_BRIGHT_BLUE .. "Building " .. pkg_name .. mode_str .. "..." .. COLOR_RESET)
	if not pkg.source then
		print(COLOR_RED .. "✗ Package does not support source installation" .. COLOR_RESET)
		return false
	end

	local build_dir = CACHE_DIR .. "/build/" .. pkg.name
	os.execute("rm -rf " .. build_dir)
	os.execute("mkdir -p " .. build_dir)
	local old_dir = os.getenv("PWD")
	os.execute("cd " .. shell_escape(build_dir))
	CURRENT_SOURCE_BASE_DIR = build_dir
	local hook_register, hooks = create_hook_system()
	pkg.source()(hook_register)
	os.execute("cd " .. shell_escape(old_dir))

	local function run_hooks(hook_name)
		if hooks[hook_name] then
			for _, hook_entry in ipairs(hooks[hook_name]) do
				if evaluate_condition(hook_entry.options["if"], pkg.OPTIONS) then
					hook_entry.callback()
				end
			end
		end
	end
	run_hooks("prepare")
	run_hooks("build")
	run_hooks("pre_install")
	run_hooks("install")
	run_hooks("post_install")

	local db = load_db()
	db[pkg.name] = {
		version = pkg.version,
		files = pkg.files or {},
	}
	save_db(db)
	print(COLOR_GREEN .. "\n✓ " .. pkg_name .. " built and installed successfully" .. COLOR_RESET)
	CURRENT_SOURCE_BASE_DIR = nil
	return true
end

local function list_installed()
	local db = load_db()
	local count = 0
	print(COLOR_BRIGHT_BLUE .. "Installed packages:" .. COLOR_RESET .. "\n")
	for pkg_name, info in pairs(db) do
		print(string.format(COLOR_GREEN .. "  %s" .. COLOR_RESET .. "  %s", pkg_name, info.version))
		count = count + 1
	end

	if count == 0 then
		print(COLOR_YELLOW .. "  (none)" .. COLOR_RESET)
	else
		print(COLOR_BRIGHT_BLUE .. "\nTotal: " .. count .. " package(s)" .. COLOR_RESET)
	end
end

local function upgrade_packages()
	local db = load_db()
	local count = 0
	print(COLOR_BRIGHT_BLUE .. "Checking for upgrades..." .. COLOR_RESET)
	for pkg_name, info in pairs(db) do
		local pkg_path = find_package(pkg_name)
		if pkg_path then
			local pkg = load_package(pkg_path)
			if pkg.version ~= info.version and pkg.version ~= "git" then
				print(
					COLOR_BRIGHT_CYAN
						.. "\n→ Upgrading "
						.. pkg_name
						.. ": "
						.. info.version
						.. " → "
						.. pkg.version
						.. COLOR_RESET
				)

				if pkg.upgrade then
					pkg.upgrade()(info.version)
				end

				install_binary(pkg_name)
				count = count + 1
			end
		end
	end

	if count == 0 then
		print(COLOR_GREEN .. "✓ All packages up to date" .. COLOR_RESET)
	else
		print(COLOR_GREEN .. "\n✓ Upgraded " .. count .. " package(s)" .. COLOR_RESET)
	end
end

local function get_package_metadata(pkg_path)
	local f = io.open(pkg_path, "r")
	if not f then
		return nil
	end
	local content = f:read("*all")
	f:close()

	local pkg = {}
	local success, err = pcall(function()
		local env = {
			pkg = pkg,
			print = function() end,
			install = function() end,
			symlink = function() end,
			sh = function() end,
			gitclone = function() end,
			wget = function() end,
			curl = function() end,
			dump = function() end,
			ARCH = nil,
			OPTIONS = {},
		}
		setmetatable(env, { __index = _G })
		local chunk = load(content, "@" .. pkg_path, "t", env)
		if chunk then
			chunk()
		end
		pkg = env.pkg
	end)

	if not success then
		print_error("Error loading package for metadata: " .. pkg_path .. " - " .. err)
		return nil
	end

	if pkg.name then
		return pkg
	end
	return nil
end

local function search_packages(search_term)
	local config = load_config()
	local results = {}
	for _, repo in ipairs(config.repos) do
		local repo_path = REPO_DIR .. "/" .. repo.name
		for file in io.popen("find " .. shell_escape(repo_path) .. " -name '*.lua' 2>/dev/null"):lines() do
			local pkg_metadata = get_package_metadata(file)
			if pkg_metadata and pkg_metadata.name then
				local match = false
				if not search_term or search_term == "" then
					match = true
				else
					local lower_search_term = search_term:lower()
					if
						pkg_metadata.name:lower():find(lower_search_term)
						or (pkg_metadata.description and pkg_metadata.description:lower():find(lower_search_term))
						or (pkg_metadata.maintainers and pkg_metadata.maintainers:lower():find(lower_search_term))
					then
						match = true
					end
				end

				if match then
					table.insert(results, {
						repo = repo.name,
						name = pkg_metadata.name,
						version = pkg_metadata.version or "N/A",
						description = pkg_metadata.description or "N/A",
						maintainers = pkg_metadata.maintainer or "N/A",
					})
				end
			end
		end
	end

	if #results > 0 then
		local max_repo = 6
		local max_name = 10
		local max_version = 9
		local max_description = 20
		local max_maintainers = 15
		for _, pkg in ipairs(results) do
			max_repo = math.max(max_repo, #pkg.repo)
			max_name = math.max(max_name, math.min(30, #pkg.name))
			max_version = math.max(max_version, #pkg.version)
			max_description = math.max(max_description, math.min(50, #pkg.description))
			max_maintainers = math.max(max_maintainers, #pkg.maintainers)
		end
		local header_format = COLOR_BRIGHT_CYAN
			.. "%-"
			.. max_repo
			.. "s  %-"
			.. max_name
			.. "s  %-"
			.. max_version
			.. "s  %-"
			.. max_description
			.. "s  %-"
			.. max_maintainers
			.. "s"
			.. COLOR_RESET
		print(string.format(header_format, "Repo", "Name", "Version", "Description", "Maintainers"))
		print(
			COLOR_BRIGHT_BLACK
				.. string.rep("─", max_repo)
				.. "──"
				.. string.rep("─", max_name)
				.. "──"
				.. string.rep("─", max_version)
				.. "──"
				.. string.rep("─", max_description)
				.. "──"
				.. string.rep("─", max_maintainers)
				.. COLOR_RESET
		)
		for _, pkg in ipairs(results) do
			local row_format = "%-"
				.. max_repo
				.. "s  %-"
				.. max_name
				.. "s  %-"
				.. max_version
				.. "s  %-"
				.. max_description
				.. "s  %-"
				.. max_maintainers
				.. "s"
			print(
				string.format(
					row_format,
					pkg.repo,
					pkg.name,
					pkg.version,
					truncate(pkg.description, max_description),
					pkg.maintainers
				)
			)
		end
	else
		print("No packages found.")
	end
end

local function show_help()
	print([[pkglet - The hybrid package manager for NULL GNU/Linux
Version ]] .. VERSION .. [[


Usage:
  pl <package>[{...}]                Install package (binary)
  pl b/<package>[{...}] [...]        Build package(s) from source
  pl u                               Update repositories
  pl uu                              Upgrade installed packages
  pl l                               List installed packages
  pl s [term]                        Search for packages
  pl g <package>[{...}]              Show package graph
  pl -b=<path> <packages...>         Bootstrap mode (install to specified directory)
  pl -bn=<path> <packages...>        Bootstrap mode without filesystem initialization
  pl -v, --version                   Show version
  pl -h, --help                      Show this help

Examples:
  pl com.example.hello
  pl b/xyz.obsidianos.obsidianctl
  pl b/com.example.pkg1 com.example.pkg2
  pl -b=/mnt com.example.base b/org.kernel.linux b/org.lua.lua

Bootstrap mode installs packages to the specified directory instead of /
Useful for installing a fresh system to a new partition or chroot.

[{...}] represents package options. Package options are Lua tables which gets passed to the package. Example:
  pl com.example.hello{debug=true}

License: MIT
]])
end

local function show_graph(pkg_name, pkg_options)
	print(COLOR_BRIGHT_BLUE .. "Graph for package: " .. pkg_name .. COLOR_RESET)
	local visited = {}
	local traverse_package
	traverse_package = function(current_pkg_name, indent)
		indent = indent or ""
		if visited[current_pkg_name] then
			print(indent .. COLOR_BRIGHT_BLACK .. "(already visited) " .. current_pkg_name .. COLOR_RESET)
			return
		end
		visited[current_pkg_name] = true
		local pkg_path, repo_name = find_package(current_pkg_name)
		if not pkg_path then
			print(indent .. COLOR_RED .. "✗ Package not found: " .. current_pkg_name .. COLOR_RESET)
			return
		end

		local pkg = load_package(pkg_path, pkg_options, true)
		print(indent .. COLOR_CYAN .. "Package: " .. pkg.name .. " (" .. (pkg.version or "N/A") .. ")" .. COLOR_RESET)
		print(indent .. "  Description: " .. (pkg.description or "N/A"))
		print(indent .. "  Repo: " .. repo_name)
		print(indent .. "  Source build: " .. tostring(pkg.source ~= nil))
		print(indent .. "  Binary install: " .. tostring(pkg.binary ~= nil))
		if pkg.options then
			print(indent .. "  Supported Options:")
			for name, def in pairs(pkg.options) do
				local default_val_str = ""
				if def.default ~= nil then
					default_val_str = " (default: " .. tostring(def.default) .. ")"
				end
				local range_str = ""
				if def.type == "number" then
					if def.min ~= nil and def.max ~= nil then
						range_str = ", range: [" .. def.min .. ", " .. def.max .. "]"
					elseif def.min ~= nil then
						range_str = ", min: " .. def.min
					elseif def.max ~= nil then
						range_str = ", max: " .. def.max
					end
				elseif def.type == "string" and def.from ~= nil then
					local allowed_values_str = table.concat(def.from, ", ")
					range_str = ", from: {" .. allowed_values_str .. "}"
				end
				print(indent .. "    - " .. name .. " (type: " .. def.type .. default_val_str .. range_str .. ")")
				if def.description then
					print(indent .. "      Description: " .. def.description)
				end
			end
		end
		local _, hooks = create_hook_system()
		if pkg.source then
			pkg.source()(function(hook_name, options)
				return function(callback)
					if not hooks[hook_name] then
						hooks[hook_name] = {}
					end
					table.insert(hooks[hook_name], { type = "source", callback = callback, options = options or {} })
				end
			end)
		end
		if pkg.binary then
			pkg.binary()(function(hook_name, options)
				return function(callback)
					if not hooks[hook_name] then
						hooks[hook_name] = {}
					end
					table.insert(hooks[hook_name], { type = "binary", callback = callback, options = options or {} })
				end
			end)
		end

		local hook_count = 0
		for hook_name, hook_entries in pairs(hooks) do
			if #hook_entries > 0 then
				if hook_count == 0 then
					print(indent .. "  Hooks:")
				end
				hook_count = hook_count + 1
				for _, entry in ipairs(hook_entries) do
					local options_str = ""
					if next(entry.options) then
						options_str = " (options: "
						local opt_parts = {}
						for k, v in pairs(entry.options) do
							if type(v) == "table" then
								local inner_opt_parts = {}
								for ik, iv in pairs(v) do
									table.insert(inner_opt_parts, ik .. "=" .. tostring(iv))
								end
								table.insert(opt_parts, k .. "={" .. table.concat(inner_opt_parts, ", ") .. "}")
							else
								table.insert(opt_parts, k .. "=" .. tostring(v))
							end
						end
						options_str = options_str .. table.concat(opt_parts, ", ") .. ")"
					end
					print(indent .. "    - (" .. entry.type .. ") " .. hook_name .. options_str)
				end
			end
		end

		if pkg.depends and #pkg.depends > 0 then
			print(indent .. "  Dependencies:")
			for _, dep_full_name in ipairs(pkg.depends) do
				local dep_name = dep_full_name
				local dep_options_str = "{}"
				local build_dep = false

				if dep_full_name:match("^b/") then
					build_dep = true
					dep_name = dep_full_name:sub(3)
				end

				local name_match, options_match = dep_name:match("^(.-){(.*)}$")
				if name_match and options_match then
					dep_name = name_match
					dep_options_str = "{" .. options_match .. "}"
				end

				print(
					indent
						.. "    → "
						.. dep_name
						.. (build_dep and " (build)" or "")
						.. " (options: "
						.. dep_options_str
						.. ")"
				)
				traverse_package(dep_name, indent .. "      ")
			end
		end
	end
	traverse_package(pkg_name)
end

local function main(args)
	ensure_dirs()
	if #args == 0 or args[1] == "-h" or args[1] == "--help" then
		show_help()
		return
	end
	if args[1] == "-v" or args[1] == "--version" then
		print(COLOR_BRIGHT_GREEN .. "pkglet " .. VERSION .. COLOR_RESET)
		return
	end
	if args[1] == "u" then
		if args[2] then
			add_and_update_repo(args[2])
		else
			update_repos()
		end
		return
	end
	if args[1] == "uu" then
		upgrade_packages()
		return
	end
	if args[1] == "l" then
		list_installed()
		return
	end
	if args[1] == "s" then
		search_packages(args[2])
		return
	end
	if args[1] == "g" then
		if not args[2] then
			print(COLOR_RED .. "✗ Package name required for graph command." .. COLOR_RESET)
			return
		end
		local pkg_full_name = args[2]
		local pkg_name = pkg_full_name
		local pkg_options_str = "{}"
		local name_match, options_match = pkg_full_name:match("^(.-){(.*)}$")
		if name_match and options_match then
			pkg_name = name_match
			pkg_options_str = "{" .. options_match .. "}"
		end
		show_graph(pkg_name, pkg_options_str)
		return
	end
	local build_mode = false
	local packages = {}
	local skip_next = false
	for i, arg in ipairs(args) do
		if skip_next then
			skip_next = false
		elseif arg:match("^%-bn=") then
			ROOT = arg:match("^%-bn=(.+)")
			if ROOT:sub(-1) == "/" then
				ROOT = ROOT:sub(1, -2)
			end
			ROOT = resolve_path(ROOT)
			print(COLOR_BRIGHT_BLUE .. "Bootstrap mode (no-init): " .. ROOT .. COLOR_RESET)
			os.execute("mkdir -p " .. ROOT)
		elseif arg:match("^%-b=") then
			ROOT = arg:match("^%-b=(.+)")
			if ROOT:sub(-1) == "/" then
				ROOT = ROOT:sub(1, -2)
			end
			ROOT = resolve_path(ROOT)
			print(COLOR_BRIGHT_BLUE .. "Bootstrap mode: " .. ROOT .. COLOR_RESET)
			os.execute("mkdir -p " .. ROOT)
			init_filesystem(ROOT)
		else
			local pkg_full_name = arg
			local pkg_name = arg
			local pkg_options_str = "{}"
			local build = false
			if pkg_full_name:match("^b/") then
				build = true
				pkg_full_name = pkg_full_name:sub(3)
				pkg_name = pkg_full_name
			end
			local name_match, options_match = pkg_full_name:match("^(.-){(.*)}$")
			if name_match and options_match then
				pkg_name = name_match
				pkg_options_str = "{" .. options_match .. "}"
			end
			if not arg:match("^%-") then
				table.insert(packages, { name = pkg_name, build = build, options = pkg_options_str })
				if build then
					build_mode = true
				end
			end
		end
	end
	if #packages == 0 then
		print(COLOR_RED .. "✗ No packages specified" .. COLOR_RESET)
		return
	end
	for _, pkg_info in ipairs(packages) do
		if pkg_info.build then
			build_from_source(pkg_info.name, false, pkg_info.options)
		else
			install_binary(pkg_info.name, false, pkg_info.options)
		end
	end
end
main(arg)
