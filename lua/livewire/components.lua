-- Component files behind tags, and the Livewire component that owns a Blade view:
--   <livewire:name/>, @livewire('name')  class in the class path first, then single-file
--                                        (⚡name.blade.php) and multi-file (name/name.php)
--   <x-name>, <x-ns::name>               class in app/View/Components first, then anonymous views
--   <flux:name>                          published override in resources/views/flux, then vendor
-- Paths come from config/livewire.php when it's published; classes are found through PSR-4.
local config = require("livewire.config")

local M = {}

M.defaults = {
  class_path = "app/Livewire",
  locations = { "resources/views/components", "resources/views/livewire" },
  namespaces = { layouts = "resources/views/layouts", pages = "resources/views/pages" },
}

---@class livewire.ComponentConfig
---@field class_path string
---@field locations string[]
---@field namespaces table<string, string>

---@class livewire.RootCache
---@field config? { key: string, value: livewire.ComponentConfig }
---@field psr4? { key: string, value: table<string, string[]> }
---@field owners table<string, string|false> view path -> owning file, false when none

---@type table<string, livewire.RootCache>
local cache = {}

local function root_cache(root)
  cache[root] = cache[root] or { owners = {} }
  return cache[root]
end

---@param path string
---@return string mtime, or "-" when the file is missing
local function mtime(path)
  local stat = vim.uv.fs_stat(path)
  return stat and ("%d.%d"):format(stat.mtime.sec, stat.mtime.nsec) or "-"
end

local function read(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local src = f:read("*a")
  f:close()
  return src
end

-- resource_path('x') / app_path('x') / base_path('x') -> project-relative path
local function php_path(fn, arg)
  local prefix = ({ resource_path = "resources/", app_path = "app/", base_path = "" })[fn]
  return prefix and (prefix .. arg)
end

---@param src string
---@return livewire.ComponentConfig
local function parse_config(src)
  local cfg = vim.deepcopy(M.defaults)
  local class_fn, class_arg = src:match("'class_path'%s*=>%s*([%w_]+)%(%s*'([^']*)'")
  cfg.class_path = class_fn and php_path(class_fn, class_arg) or cfg.class_path

  local locations = src:match("'component_locations'%s*=>%s*(%b[])")
  if locations then
    cfg.locations = {}
    for fn, arg in locations:gmatch("([%w_]+)%(%s*'([^']*)'") do
      cfg.locations[#cfg.locations + 1] = php_path(fn, arg)
    end
  end

  local namespaces = src:match("'component_namespaces'%s*=>%s*(%b[])")
  if namespaces then
    cfg.namespaces = {}
    for ns, fn, arg in namespaces:gmatch("'([%w_-]+)'%s*=>%s*([%w_]+)%(%s*'([^']*)'") do
      cfg.namespaces[ns] = php_path(fn, arg)
    end
  end
  return cfg
end

--- Paths from config/livewire.php, falling back to Livewire's defaults.
---@param root string
---@return livewire.ComponentConfig
function M.config(root)
  local c = root_cache(root)
  local path = root .. "/config/livewire.php"
  local key = mtime(path)
  if not c.config or c.config.key ~= key then
    local src = read(path)
    c.config = { key = key, value = src and parse_config(src) or vim.deepcopy(M.defaults) }
  end
  return c.config.value
end

---@param root string
---@return table<string, string[]>
local function read_psr4(root)
  local map = {}
  local src = read(root .. "/vendor/composer/autoload_psr4.php")
  if src then
    for prefix, dirs in src:gmatch("'([^']+)'%s*=>%s*array%((.-)%),") do
      prefix = prefix:gsub("\\\\", "\\")
      map[prefix] = {}
      for var, dir in dirs:gmatch("%$(%w+)%s*%.%s*'([^']*)'") do
        local path = ((var == "vendorDir" and "vendor" or "") .. dir):gsub("^/", "")
        table.insert(map[prefix], path)
      end
    end
    return map
  end
  local ok, composer = pcall(vim.json.decode, read(root .. "/composer.json") or "")
  if not ok or type(composer) ~= "table" then
    return map
  end
  for _, section in ipairs({ composer.autoload or {}, composer["autoload-dev"] or {} }) do
    for prefix, dirs in pairs(type(section) == "table" and section["psr-4"] or {}) do
      map[prefix] = vim.tbl_map(function(d)
        return (d:gsub("/$", ""))
      end, type(dirs) == "table" and dirs or { dirs })
    end
  end
  return map
end

--- PSR-4 prefixes -> project-relative dirs, from composer's generated map (covers vendor
--- too), falling back to composer.json when dependencies aren't installed.
---@param root string
---@return table<string, string[]>
function M.psr4(root)
  local c = root_cache(root)
  local key = mtime(root .. "/vendor/composer/autoload_psr4.php") .. mtime(root .. "/composer.json")
  if not c.psr4 or c.psr4.key ~= key then
    c.psr4 = { key = key, value = read_psr4(root) }
  end
  return c.psr4.value
end

--- Fully qualified class name -> file, trying the longest matching PSR-4 prefix first.
---@param fqcn string without a leading backslash
---@param root string
---@return string?
function M.class_to_file(fqcn, root)
  local psr4 = M.psr4(root)
  local prefixes = vim.tbl_keys(psr4)
  table.sort(prefixes, function(a, b)
    return #a > #b
  end)
  for _, prefix in ipairs(prefixes) do
    if fqcn:sub(1, #prefix) == prefix then
      local rel = fqcn:sub(#prefix + 1):gsub("\\", "/") .. ".php"
      for _, dir in ipairs(psr4[prefix]) do
        local path = root .. "/" .. dir .. "/" .. rel
        if vim.uv.fs_stat(path) then
          return path
        end
      end
    end
  end
end

-- Blade tags that look like components but aren't
local not_components = { slot = true, ["dynamic-component"] = true }

local tag_patterns = {
  { kind = "livewire", pat = "<livewire:()([%w%._:%-]+)" },
  { kind = "livewire", pat = "@livewire%(%s*['\"]()([^'\"]+)['\"]" },
  { kind = "flux", pat = "<flux:()([%w%._%-]+)" },
  { kind = "blade", pat = "<x%-()([%w%._:%-]+)" },
}

---@alias livewire.ComponentKind "livewire"|"blade"|"flux"

--- Component tag whose name contains byte column `col` of `line`.
---@param line string
---@param col integer 0-based
---@return livewire.ComponentKind? kind
---@return string? name
function M.tag_at(line, col)
  for _, p in ipairs(tag_patterns) do
    local init = 1
    while true do
      local s, e, name_start, name = line:find(p.pat, init)
      if not s then
        break
      end
      -- anywhere from `<` to the end of the name
      if col + 1 >= s and col + 1 <= name_start + #name - 1 then
        return p.kind, name
      end
      init = e + 1
    end
  end
end

local function studly(segment)
  return (segment:gsub("[-_](%w)", string.upper):gsub("^%l", string.upper))
end

-- "ns::a.b-c" -> ns, { "a", "b-c" }
local function split_name(name)
  local ns, rest = name:match("^([%w_-]+)::(.+)$")
  return ns, vim.split(rest or name, ".", { plain = true })
end

local function class_file(dir, segments)
  return dir .. "/" .. table.concat(vim.tbl_map(studly, segments), "/") .. ".php"
end

-- Anonymous Blade views: dir/a/b.blade.php, dir/a/b/index.blade.php, dir/a/b/b.blade.php
local function view_files(dir, segments)
  local rel = dir .. "/" .. table.concat(segments, "/")
  local leaf = segments[#segments]
  return { rel .. ".blade.php", rel .. "/index.blade.php", rel .. "/" .. leaf .. ".blade.php" }
end

local function livewire_candidates(name, cfg)
  local ns, segments = split_name(name)
  local leaf = segments[#segments]
  local parent = table.concat(segments, "/", 1, #segments - 1)
  parent = parent ~= "" and (parent .. "/") or ""

  local candidates = ns and {} or { class_file(cfg.class_path, segments) }
  for _, dir in ipairs(ns and { cfg.namespaces[ns] } or cfg.locations) do
    local base = dir .. "/" .. parent
    vim.list_extend(candidates, {
      base .. "⚡" .. leaf .. ".blade.php",
      base .. leaf .. ".blade.php",
      base .. "⚡" .. leaf .. "/" .. leaf .. ".php",
      base .. leaf .. "/" .. leaf .. ".php",
      base .. "⚡" .. leaf .. "/" .. leaf .. ".blade.php",
      base .. leaf .. "/" .. leaf .. ".blade.php",
    })
  end
  return candidates
end

local function blade_candidates(name, cfg)
  if not_components[name] or name:match("^slot:") then
    return {}
  end
  local ns, segments = split_name(name)
  if ns then
    return cfg.namespaces[ns] and view_files(cfg.namespaces[ns], segments) or {}
  end
  local candidates = { class_file("app/View/Components", segments) }
  vim.list_extend(candidates, view_files("resources/views/components", segments))
  return candidates
end

local function flux_candidates(name)
  local segments = vim.split(name, ".", { plain = true })
  local candidates = view_files("resources/views/flux", segments)
  for _, pkg in ipairs({ "flux-pro", "flux" }) do
    vim.list_extend(candidates, view_files("vendor/livewire/" .. pkg .. "/stubs/resources/views/flux", segments))
  end
  return candidates
end

--- File a component tag refers to.
---@param kind livewire.ComponentKind
---@param name string
---@param root string
---@return string?
function M.resolve(kind, name, root)
  local candidates
  if kind == "livewire" then
    candidates = livewire_candidates(name, M.config(root))
  elseif kind == "blade" then
    candidates = config.options.definition.blade_components and blade_candidates(name, M.config(root)) or {}
  else
    candidates = flux_candidates(name)
  end
  for _, rel in ipairs(candidates) do
    if vim.uv.fs_stat(root .. "/" .. rel) then
      return root .. "/" .. rel
    end
  end
end

--- Whether Blade source starts with a single-file component's class.
---@param text string
function M.is_single_file(text)
  local head = text:match("^%s*<%?php(.-)%?>")
  return head ~= nil and head:find("%f[%w]class%s+extends%s") ~= nil
end

---@param buf integer
---@param root string
---@return string?
local function find_owner(buf, root)
  local file = vim.api.nvim_buf_get_name(buf)
  local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  if M.is_single_file(text) then
    return file
  end

  local dir, leaf = file:match("^(.*)/([^/]+)%.blade%.php$")
  if not dir then
    return nil
  end
  local sibling = dir .. "/" .. leaf:gsub("^⚡", "") .. ".php"
  if vim.uv.fs_stat(sibling) then
    return sibling
  end

  local rel = file:sub(#root + 2):match("^resources/views/(.+)%.blade%.php$")
  if not rel or file:sub(1, #root + 1) ~= root .. "/" then
    return nil
  end
  local cfg = M.config(root)
  -- convention first (resources/views/livewire/a/b-c -> app/Livewire/A/BC.php), then search render()
  local under_livewire = rel:match("^livewire/(.+)$")
  if under_livewire then
    local guess = root .. "/" .. class_file(cfg.class_path, vim.split(under_livewire, "/", { plain = true }))
    if vim.uv.fs_stat(guess) then
      return guess
    end
  end
  local view = vim.pesc(rel:gsub("/", "."))
  local base = root .. "/" .. cfg.class_path
  if not vim.uv.fs_stat(base) then
    return nil
  end
  for name, type in vim.fs.dir(base, { depth = 10 }) do
    if type == "file" and name:match("%.php$") then
      local src = read(base .. "/" .. name) or ""
      if src:find("['\"]" .. view .. "['\"]") then
        return base .. "/" .. name
      end
    end
  end
end

--- File holding the Livewire component that owns a Blade view: the view itself for
--- single-file components, name/name.php for multi-file ones, else the class rendering it.
---@param buf integer
---@return string? owner
---@return string? root
function M.owner(buf)
  local root = require("livewire.project").root(buf)
  if not root then
    return nil
  end
  local file = vim.api.nvim_buf_get_name(buf)
  local c = root_cache(root)
  -- single-file components can gain or lose their class while being edited; don't cache them
  if file:match("%.blade%.php$") and c.owners[file] ~= nil then
    return c.owners[file] or nil, root
  end
  local owner = find_owner(buf, root)
  if owner ~= file then
    c.owners[file] = owner or false
  end
  return owner, root
end

--- Forget owners found by searching the class path after one of its files is written.
---@param root string
---@param rel string path relative to the root
---@return boolean changed whether anything was forgotten
function M.on_write(root, rel)
  local c = cache[root]
  if not c or not rel:match("%.php$") or rel:match("%.blade%.php$") then
    return false
  end
  local class_path = M.config(root).class_path
  if rel:sub(1, #class_path + 1) ~= class_path .. "/" or vim.tbl_isempty(c.owners) then
    return false
  end
  c.owners = {}
  return true
end

--- Forget everything cached (tests, `setup()`).
function M.reset()
  cache = {}
end

return M
