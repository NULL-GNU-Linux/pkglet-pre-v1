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
		"/usr/sbin",
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

	print("Initializing filesystem at " .. root .. "...")
	for _, dir in ipairs(dirs) do
		os.execute("mkdir -p " .. root .. dir)
	end

	print("Creating essential symlinks...")
	os.execute("ln -sf usr/bin " .. root .. "/bin 2>/dev/null")
	os.execute("ln -sf usr/sbin " .. root .. "/sbin 2>/dev/null")
	os.execute("ln -sf usr/lib " .. root .. "/lib 2>/dev/null")
	os.execute("ln -sf usr/lib64 " .. root .. "/lib64 2>/dev/null")

	print("✓ Filesystem initialized")
end

local function ensure_dirs()
	os.execute("mkdir -p " .. REPO_DIR)
	os.execute("mkdir -p " .. CACHE_DIR)
	os.execute("mkdir -p " .. os.getenv("HOME") .. "/.local/share/pkglet")
	os.execute("mkdir -p " .. os.getenv("HOME") .. "/.config/pkglet")
end

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

local function save_config(config)
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
	print("Updating repositories...")
	for _, repo in ipairs(config.repos) do
		print("\n→ " .. repo.name)
		local repo_path = REPO_DIR .. "/" .. repo.name
		if os.execute("test -d " .. repo_path) then
			print("  Pulling updates...")
			os.execute("cd " .. repo_path .. " && git pull -q")
		else
			print("  Cloning repository...")
			os.execute("git clone -q " .. repo.url .. " " .. repo_path)
		end
	end
	print("\n✓ Repositories updated")
end

local function add_and_update_repo(repo_source)
	print("Adding repository from " .. repo_source .. "...")
	local repo_content = ""

	if repo_source:match("^https?://") then
		local handle = io.popen("curl -sL " .. repo_source)
		repo_content = handle:read("*all")
		handle:close()
		if repo_content == "" then
			print("✗ Failed to fetch repo.lua from URL: " .. repo_source)
			return
		end
	else
		local f = io.open(repo_source, "r")
		if not f then
			print("✗ Failed to open repo.lua file: " .. repo_source)
			return
		end
		repo_content = f:read("*all")
		f:close()
	end

	local new_repo_func = load(repo_content)
	if not new_repo_func then
		print("✗ Failed to parse repo.lua content.")
		return
	end

	local new_repo = new_repo_func()
	if not new_repo or not new_repo.name or not new_repo.url or not new_repo.description then
		print("✗ Invalid repo.lua format. Missing name, url, or description.")
		return
	end

	local config = load_config()
	local repo_exists = false
	for _, repo in ipairs(config.repos) do
		if repo.name == new_repo.name then
			repo_exists = true
			print(
				"⚠ Repository with name '" .. new_repo.name .. "' already exists. Updating its URL and description."
			)
			repo.url = new_repo.url
			repo.description = new_repo.description
			break
		end
	end

	if not repo_exists then
		table.insert(config.repos, new_repo)
		print("✓ Added new repository: " .. new_repo.name)
	end

	save_config(config)
	update_repos()
	print("✓ Repository added and updated successfully.")
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
	return function(hook_name)
		return function(callback)
			hooks[hook_name] = callback
		end
	end, hooks
end

local function load_package(pkg_path)
	local pkg = {}
	pkg.files = {}

	local function install(source_path, destination_path, permissions)
		local full_dest_path = (ROOT or "") .. destination_path
		local base_source_dir = CURRENT_SOURCE_BASE_DIR or pkg_path:match("(.*)/[^/]+$")
		print(pkg.name)
		local full_source_path = base_source_dir .. "/" .. source_path
		print("  Installing '" .. source_path .. "' to '" .. full_dest_path .. "'")
		local parent_dir = dirname(full_dest_path)
		if parent_dir ~= nil and parent_dir ~= "" then
			os.execute("mkdir -p " .. shell_escape(parent_dir))
		end
		local success = os.execute("cp -r " .. shell_escape(full_source_path) .. " " .. shell_escape(full_dest_path))
		if not success then
			error("Failed to install '" .. source_path .. "'")
		end
		if permissions then
			local chmod_success = os.execute("chmod " .. permissions .. " " .. shell_escape(full_dest_path))
			if not chmod_success then
				error("Failed to set permissions for '" .. full_dest_path .. "'")
			end
		end
		table.insert(pkg.files, full_dest_path)
	end

	local function uninstall(destination_path)
		local full_dest_path = (ROOT or "") .. destination_path
		print("  Uninstalling '" .. full_dest_path .. "'")
		local success = os.execute("rm -rf " .. shell_escape(full_dest_path))
		if not success then
			error("Failed to uninstall '" .. full_dest_path .. "'")
		end
	end

	local function symlink(source_path, destination_path)
		local full_source_path = (ROOT or "") .. source_path
		local full_dest_path = (ROOT or "") .. destination_path
		print("  Symlinking '" .. full_source_path .. "' to '" .. full_dest_path .. "'")
		local parent_dir = dirname(full_dest_path)
		if parent_dir ~= nil and parent_dir ~= "" then
			os.execute("mkdir -p " .. shell_escape(parent_dir))
		end
		local success = os.execute("ln -sf " .. shell_escape(full_source_path) .. " " .. shell_escape(full_dest_path))
		if not success then
			error("Failed to create symlink from '" .. full_source_path .. "' to '" .. full_dest_path .. "'")
		end
		table.insert(pkg.files, full_dest_path)
	end

	local function sh(command)
		print("  Executing shell command: " .. command)
		local cd_prefix = ""
		if CURRENT_SOURCE_BASE_DIR ~= nil then
			cd_prefix = "cd " .. shell_escape(CURRENT_SOURCE_BASE_DIR) .. " && "
		end
		local full_command = cd_prefix .. command
		local success = os.execute(full_command)
		if not success then
			error("Shell command failed: " .. command)
		end
	end

	local function gitclone(repo_url, destination_path)
		local full_dest_path = (ROOT or "") .. destination_path
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
			error("Failed to clone git repository: " .. repo_url)
		end
		table.insert(pkg.files, full_dest_path)
	end

	local function wget(url, destination_path)
		local full_dest_path = destination_path
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
			error("Failed to download file from '" .. url .. "'")
		end
		table.insert(pkg.files, full_dest_path)
	end

	local function curl(url, destination_path)
		local full_dest_path = destination_path
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
			error("Failed to download file from '" .. url .. "' using curl")
		end
		table.insert(pkg.files, full_dest_path)
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
	}
	setmetatable(env, { __index = _G })

	local chunk = loadfile(pkg_path, "t", env)
	if not chunk then
		error("Failed to load package file: " .. pkg_path)
	end
	chunk()
	return env.pkg
end

local function is_installed(pkg_name)
	local db = load_db()
	return db[pkg_name] ~= nil
end

local function resolve_dependencies(pkg, visited)
	visited = visited or {}
	local to_install = {}

	if not pkg.depends then
		return to_install
	end

	for _, dep in ipairs(pkg.depends) do
		if not visited[dep] and not is_installed(dep) then
			visited[dep] = true
			local dep_path = find_package(dep)
			if dep_path then
				local dep_pkg = load_package(dep_path)
				local sub_deps = resolve_dependencies(dep_pkg, visited)
				for _, sub_dep in ipairs(sub_deps) do
					table.insert(to_install, sub_dep)
				end
				table.insert(to_install, dep)
			else
				print("⚠ Warning: Dependency not found: " .. dep)
			end
		end
	end

	return to_install
end

local function install_binary(pkg_name, skip_deps)
	local pkg_path, repo_name = find_package(pkg_name)
	if not pkg_path then
		print("✗ Package not found: " .. pkg_name)
		return false
	end

	local pkg = load_package(pkg_path)

	if not skip_deps then
		local deps = resolve_dependencies(pkg)
		if #deps > 0 then
			print("\nResolving dependencies for " .. pkg_name .. ":")
			for _, dep in ipairs(deps) do
				print("  → " .. dep)
			end
			print("")

			for _, dep in ipairs(deps) do
				if not install_binary(dep, true) then
					print("✗ Failed to install dependency: " .. dep)
					return false
				end
			end
		end
	end

	local mode_str = ROOT ~= "" and " (binary, root=" .. ROOT .. ")" or " (binary)"
	print("Installing " .. pkg_name .. mode_str .. "...")

	if not pkg.binary then
		print("✗ Package does not support binary installation")
		return false
	end

	local hook, hooks = create_hook_system()
	pkg.binary()(hook)

	if hooks.pre_install then
		hooks.pre_install()
	end
	if hooks.install then
		hooks.install()
	end
	if hooks.post_install then
		hooks.post_install()
	end

	local db = load_db()
	db[pkg.name] = {
		version = pkg.version,
		files = pkg.files or {},
	}
	save_db(db)

	print("\n✓ " .. pkg_name .. " installed successfully")
	return true
end

local function build_from_source(pkg_name, skip_deps)
	local pkg_path, repo_name = find_package(pkg_name)
	if not pkg_path then
		print("✗ Package not found: " .. pkg_name)
		return false
	end

	local pkg = load_package(pkg_path)

	if not skip_deps then
		local deps = resolve_dependencies(pkg)
		if #deps > 0 then
			print("\nResolving dependencies for " .. pkg_name .. ":")
			for _, dep in ipairs(deps) do
				print("  → " .. dep)
			end
			print("")

			for _, dep in ipairs(deps) do
				if not install_binary(dep, true) then
					print("✗ Failed to install dependency: " .. dep)
					return false
				end
			end
		end
	end

	local mode_str = ROOT ~= "" and " from source (root=" .. ROOT .. ")" or " from source"
	print("Building " .. pkg_name .. mode_str .. "...")

	if not pkg.source then
		print("✗ Package does not support source installation")
		return false
	end

	local build_dir = CACHE_DIR .. "/build/" .. pkg.name
	os.execute("rm -rf " .. build_dir)
	os.execute("mkdir -p " .. build_dir)

	local old_dir = os.getenv("PWD")
	os.execute("cd " .. shell_escape(build_dir))

	CURRENT_SOURCE_BASE_DIR = build_dir

	local hook, hooks = create_hook_system()
	pkg.source()(hook)

	os.execute("cd " .. shell_escape(old_dir))
	if hooks.prepare then
		hooks.prepare()
	end
	if hooks.build then
		hooks.build()
	end
	if hooks.pre_install then
		hooks.pre_install()
	end
	if hooks.install then
		hooks.install()
	end
	if hooks.post_install then
		hooks.post_install()
	end

	local db = load_db()
	db[pkg.name] = {
		version = pkg.version,
		files = pkg.files or {},
	}
	save_db(db)

	print("\n✓ " .. pkg_name .. " built and installed successfully")
	return true
end

local function list_installed()
	local db = load_db()
	local count = 0

	print("Installed packages:\n")
	for pkg_name, info in pairs(db) do
		print(string.format("  %s  %s", pkg_name, info.version))
		count = count + 1
	end

	if count == 0 then
		print("  (none)")
	else
		print("\nTotal: " .. count .. " package(s)")
	end
end

local function upgrade_packages()
	local db = load_db()
	local count = 0

	print("Checking for upgrades...")
	for pkg_name, info in pairs(db) do
		local pkg_path = find_package(pkg_name)
		if pkg_path then
			local pkg = load_package(pkg_path)
			if pkg.version ~= info.version and pkg.version ~= "git" then
				print("\n→ Upgrading " .. pkg_name .. ": " .. info.version .. " → " .. pkg.version)

				if pkg.upgrade then
					pkg.upgrade()(info.version)
				end

				install_binary(pkg_name)
				count = count + 1
			end
		end
	end

	if count == 0 then
		print("✓ All packages up to date")
	else
		print("\n✓ Upgraded " .. count .. " package(s)")
	end
end

local function show_help()
	print([[pkglet - The package manager for NULLOS
Version ]] .. VERSION .. [[


Usage:
  pl <package>                Install package (binary)
  pl b/<package> [...]        Build package(s) from source
  pl u                        Update repositories
  pl uu                       Upgrade installed packages
  pl l                        List installed packages
  pl -b=<path> <packages...>  Bootstrap mode (install to specified directory)
  pl -bn=<path> <packages...> Bootstrap mode without filesystem initialization
  pl -v, --version            Show version
  pl -h, --help               Show this help

Examples:
  pl com.example.hello
  pl b/xyz.obsidianos.obsidianctl
  pl b/com.example.pkg1 com.example.pkg2
  pl -b=/mnt com.example.base b/sys.core.kernel

Bootstrap mode installs packages to the specified directory instead of /
Useful for installing a fresh system to a new partition or chroot.

License: MIT
]])
end

local function main(args)
	ensure_dirs()

	if #args == 0 or args[1] == "-h" or args[1] == "--help" then
		show_help()
		return
	end

	if args[1] == "-v" or args[1] == "--version" then
		print("pkglet " .. VERSION)
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
			print("Bootstrap mode (no-init): " .. ROOT)
			os.execute("mkdir -p " .. ROOT)
		elseif arg:match("^%-b=") then
			ROOT = arg:match("^%-b=(.+)")
			if ROOT:sub(-1) == "/" then
				ROOT = ROOT:sub(1, -2)
			end
			print("Bootstrap mode: " .. ROOT)
			os.execute("mkdir -p " .. ROOT)
			init_filesystem(ROOT)
		elseif arg:match("^b/") then
			build_mode = true
			table.insert(packages, arg:sub(3))
		elseif not arg:match("^%-") then
			table.insert(packages, arg)
		end
	end

	if #packages == 0 then
		print("✗ No packages specified")
		return
	end

	for _, pkg_name in ipairs(packages) do
		if build_mode then
			build_from_source(pkg_name)
		else
			install_binary(pkg_name)
		end
	end
end

main(arg)
