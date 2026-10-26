-- Per-project facts: root, Livewire major version and custom directives, cached by root.
local config = require("livewire.config")

local M = {}

M.DEFAULT_VERSION = 4
M.MAX_SCAN_BYTES = 1024 * 1024

---@class livewire.Project
---@field root string
---@field version? integer Major version from composer.lock
---@field lock_mtime? string
---@field custom? table<string, true> Directives found by the JS scan; nil until scanned

---@type table<string, livewire.Project>
local cache = {}

local markers = { "composer.lock", "composer.json", "artisan" }

---@param buf? integer
---@return string?
function M.root(buf)
  -- unnamed buffers search from the cwd
  return vim.fs.root(buf or 0, markers)
end

---@param root string
---@return livewire.Project
local function project(root)
  cache[root] = cache[root] or { root = root }
  return cache[root]
end

---@param version string e.g. "v4.4.8", "3.6.4", "4.x-dev"
---@return integer?
function M.parse_major(version)
  return tonumber(version:match("^v?(%d+)%.") or version:match("^v?(%d+)$") or version:match("^(%d+)%.x"))
end

---@param path string
---@return integer?
local function read_lock(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  local decoded_ok, lock = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not decoded_ok or type(lock) ~= "table" then
    return nil
  end
  for _, section in ipairs({ "packages", "packages-dev" }) do
    for _, pkg in ipairs(type(lock[section]) == "table" and lock[section] or {}) do
      if pkg.name == "livewire/livewire" and type(pkg.version) == "string" then
        return M.parse_major(pkg.version)
      end
    end
  end
end

---@param path string
---@return string?
local function mtime(path)
  local stat = vim.uv.fs_stat(path)
  return stat and ("%d.%d"):format(stat.mtime.sec, stat.mtime.nsec)
end

--- Livewire major version for a buffer, and where it came from.
---@param buf? integer
---@return integer version
---@return "override"|"composer.lock"|"default" source
function M.version(buf)
  if config.options.livewire_version then
    return config.options.livewire_version, "override"
  end
  local root = M.root(buf)
  if not root then
    return M.DEFAULT_VERSION, "default"
  end
  local p = project(root)
  local lock = root .. "/composer.lock"
  local current = mtime(lock)
  if current ~= p.lock_mtime then
    p.lock_mtime = current
    p.version = current and read_lock(lock) or nil
  end
  if p.version then
    return p.version, "composer.lock"
  end
  return M.DEFAULT_VERSION, "default"
end

local directive_pattern = "Livewire%.directive%(%s*[\"']([%w_%-]+)[\"']"

--- The directory part of a glob before its first wildcard: "resources/js/**/*.js" -> "resources/js".
---@param glob string
local function glob_base(glob)
  local static = glob:match("^[^*?{%[]*") or ""
  return static:match("^(.*)/") or "."
end

---@param root string
---@return table<string, true>
local function scan(root)
  local found = {}
  for _, glob in ipairs(config.options.scan_paths) do
    local matcher = vim.glob.to_lpeg(glob)
    local base = glob_base(glob)
    local dir = base == "." and root or root .. "/" .. base
    if vim.uv.fs_stat(dir) then
      local walk = vim.fs.dir(dir, {
        depth = 20,
        skip = function(name)
          return vim.fs.basename(name) ~= "node_modules"
        end,
      })
      for rel, type in walk do
        local path = base == "." and rel or base .. "/" .. rel
        local full = root .. "/" .. path
        local stat = type == "file" and matcher:match(path) and vim.uv.fs_stat(full)
        if stat and stat.size <= M.MAX_SCAN_BYTES then
          local fd = io.open(full, "r")
          if fd then
            for name in fd:read("*a"):gmatch(directive_pattern) do
              found[name] = true
            end
            fd:close()
          end
        end
      end
    end
  end
  return found
end

--- Custom directives for a buffer's project: the JS scan plus `custom_directives`.
---@param buf? integer
---@return table<string, true>
function M.custom_directives(buf)
  local set = {}
  local root = M.root(buf)
  if root then
    local p = project(root)
    p.custom = p.custom or scan(root)
    set = vim.deepcopy(p.custom)
  end
  for _, name in ipairs(config.options.custom_directives) do
    set[name] = true
  end
  return set
end

local function changed(root)
  vim.api.nvim_exec_autocmds("User", { pattern = "LivewireProjectChanged", data = { root = root } })
end

--- Called after a file is written: re-scan custom directives when it is one of a known
--- project's scanned files, forget component owners when a class changes, and announce
--- version, directive and component changes (including writes to any PHP file a member
--- index has read).
---@param path string absolute path
function M.on_write(path)
  local php_root = path:match("%.php$") and vim.fs.root(path, markers)
  if php_root then
    local owners_changed = require("livewire.components").on_write(php_root, path:sub(#php_root + 2))
    if owners_changed or require("livewire.members").seen[path] then
      changed(php_root)
    end
  end
  for root, p in pairs(cache) do
    local rel = vim.startswith(path, root .. "/") and path:sub(#root + 2)
    if rel == "composer.lock" then
      changed(root)
    elseif rel and p.custom then
      for _, glob in ipairs(config.options.scan_paths) do
        if vim.glob.to_lpeg(glob):match(rel) then
          local fresh = scan(root)
          if not vim.deep_equal(fresh, p.custom) then
            p.custom = fresh
            changed(root)
          end
          break
        end
      end
    end
  end
end

--- Forget everything cached (tests, `setup()` with new options).
function M.reset()
  cache = {}
end

return M
