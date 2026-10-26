-- Properties and methods of a Livewire component, read with the tree-sitter `php` parser
-- from the class, its traits and its parent classes. The walk stops at Livewire's own base
-- classes: Livewire only lets the browser call or set members declared below them
-- (Utils::getPublicMethodsDefinedBySubClass / getPublicPropertiesDefinedOnSubclass).
local components = require("livewire.components")

local M = {}

--- Base classes whose own members aren't reachable from the browser.
M.stop = {
  ["Livewire\\Component"] = true,
  ["Livewire\\Volt\\Component"] = true,
  ["Livewire\\Form"] = true,
}

---@class livewire.Member
---@field name string
---@field kind "property"|"method"
---@field visibility "public"|"protected"|"private"
---@field static boolean
---@field detail string Declaration as written, e.g. "public string $name"
---@field type? string Declared property type, fully qualified when it names a class
---@field file string
---@field row integer 0-based
---@field col integer 0-based column of the name

---@class livewire.ParsedClass
---@field name? string Short class name; nil for anonymous classes
---@field parent? string Parent class, fully qualified
---@field traits string[] Used traits, fully qualified
---@field members livewire.Member[]
---@field magic boolean Declares `__call`, so any method name may work

function M.available()
  local ok, added = pcall(vim.treesitter.language.add, "php")
  return ok and added == true
end

local function text(node, src)
  return vim.treesitter.get_node_text(node, src)
end

local function squash(s)
  return (s:gsub("%s+", " "):gsub("%( ", "("):gsub(",? ?%)", ")"))
end

---@param body TSNode declaration_list
---@param src string
---@param file string
---@param qualify fun(name: string): string
---@return livewire.ParsedClass
local function read_body(body, src, file, qualify)
  local class = { traits = {}, members = {}, magic = false }
  local function add(member)
    class.members[#class.members + 1] = member
  end
  for child in body:iter_children() do
    local type = child:type()
    if type == "use_declaration" then
      for name in child:iter_children() do
        if name:type() == "name" or name:type() == "qualified_name" then
          class.traits[#class.traits + 1] = qualify(text(name, src))
        end
      end
    elseif type == "property_declaration" or type == "method_declaration" then
      local visibility, static, ptype = "public", false, nil
      for c in child:iter_children() do
        local t = c:type()
        if t == "visibility_modifier" then
          visibility = text(c, src)
        elseif t == "static_modifier" then
          static = true
        end
      end
      if type == "property_declaration" then
        local type_node = child:field("type")[1]
        if not type_node then
          for c in child:iter_children() do
            if c:type():match("_type$") then
              type_node = c
            end
          end
        end
        ptype = type_node and text(type_node, src):gsub("^%?", "")
        local prefix = squash(text(child, src):match("^(.-)%$") or "")
          :gsub("#%b[]%s*", "")
          :gsub("^%s+", "")
        for element in child:iter_children() do
          if element:type() == "property_element" then
            local var = element:field("name")[1] or element:named_child(0)
            local row, col = var:start()
            local name = text(var, src):gsub("^%$", "")
            add({
              name = name,
              kind = "property",
              visibility = visibility,
              static = static,
              detail = prefix .. "$" .. name,
              type = ptype and ptype:match("^[%w_\\]+$") and not ptype:match("^%l") and qualify(ptype) or ptype,
              file = file,
              row = row,
              col = col + 1,
            })
          end
        end
      else
        local name_node = child:field("name")[1]
        local name = text(name_node, src)
        local row, col = name_node:start()
        local params = child:field("parameters")[1]
        local ret = child:field("return_type")[1]
        local detail = ("%s%s function %s%s%s"):format(
          visibility,
          static and " static" or "",
          name,
          params and squash(text(params, src)) or "()",
          ret and (": " .. text(ret, src)) or ""
        )
        add({ name = name, kind = "method", visibility = visibility, static = static, detail = detail, file = file, row = row, col = col })
        class.magic = class.magic or name == "__call"
        -- constructor property promotion declares properties too
        for param in (name == "__construct" and params and params:iter_children() or function() end) do
          if param:type() == "property_promotion_parameter" then
            local var = param:field("name")[1]
            local vis = param:field("visibility")[1]
            local prow, pcol = var:start()
            local pname = text(var, src):gsub("^%$", "")
            add({
              name = pname,
              kind = "property",
              visibility = vis and text(vis, src) or "public",
              static = false,
              detail = squash(text(param, src)),
              file = file,
              row = prow,
              col = pcol + 1,
            })
          end
        end
      end
    end
  end
  return class
end

--- The first class, trait or anonymous class in PHP source.
---@param src string
---@param file string
---@return livewire.ParsedClass?
function M.parse(src, file)
  local ok, parser = pcall(vim.treesitter.get_string_parser, src, "php")
  if not ok or not parser then
    return nil
  end
  local root = parser:parse()[1]:root()
  local namespace, imports = "", {}

  local function qualify(name)
    if name:sub(1, 1) == "\\" then
      return name:sub(2)
    end
    local first, rest = name:match("^([^\\]+)(.*)$")
    if imports[first] then
      return imports[first] .. rest
    end
    return (namespace ~= "" and (namespace .. "\\") or "") .. name
  end

  local found
  local function visit(node)
    for child in node:iter_children() do
      if found then
        return
      end
      local type = child:type()
      if type == "namespace_definition" then
        local name = child:field("name")[1]
        namespace = name and text(name, src) or namespace
        local body = child:field("body")[1]
        if body then
          visit(body)
        end
      elseif type == "namespace_use_declaration" then
        for clause in child:iter_children() do
          if clause:type() == "namespace_use_clause" then
            local alias = clause:field("alias")[1]
            local target = clause:named_child(0)
            local fqcn = text(target, src):gsub("^\\", "")
            imports[alias and text(alias, src) or fqcn:match("([^\\]+)$")] = fqcn
          end
        end
      elseif type == "class_declaration" or type == "trait_declaration" or type == "anonymous_class" then
        local body = child:field("body")[1]
        if body then
          found = read_body(body, src, file, qualify)
          local name = child:field("name")[1]
          found.name = name and text(name, src) or nil
          for c in child:iter_children() do
            if c:type() == "base_clause" then
              found.parent = qualify(text(c:named_child(0), src))
            end
          end
        end
      elseif child:named_child_count() > 0 then
        visit(child)
      end
    end
  end
  visit(root)
  return found
end

---@type table<string, { key: string, class: livewire.ParsedClass|false }>
local file_cache = {}

--- Files read while building an index, so writes to them can trigger re-checks.
---@type table<string, true>
M.seen = {}

--- Parsed class in a file: its buffer when loaded (so unsaved edits count), else the file.
--- For a Blade single-file component only its leading PHP block is read.
---@param path string
---@return livewire.ParsedClass?
function M.file(path)
  M.seen[path] = true
  local buf = vim.fn.bufnr(path)
  local key, read
  if buf > 0 and vim.api.nvim_buf_is_loaded(buf) then
    key = ("buf:%d:%d"):format(buf, vim.api.nvim_buf_get_changedtick(buf))
    read = function()
      return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    end
  else
    local stat = vim.uv.fs_stat(path)
    if not stat then
      return nil
    end
    key = ("%d.%d"):format(stat.mtime.sec, stat.mtime.nsec)
    read = function()
      local f = io.open(path, "r")
      local src = f and f:read("*a") or ""
      if f then
        f:close()
      end
      return src
    end
  end
  local cached = file_cache[path]
  if cached and cached.key == key then
    return cached.class or nil
  end
  local src = read()
  if path:match("%.blade%.php$") then
    src = src:match("^%s*<%?php.-%?>") or ""
  end
  local class = src ~= "" and M.parse(src, path) or nil
  file_cache[path] = { key = key, class = class or false }
  return class
end

---@class livewire.Index
---@field file string File of the component itself
---@field name? string Short class name; nil for anonymous classes
---@field members table<string, livewire.Member>
---@field list livewire.Member[] In declaration order: own members, traits, then parents
---@field traits string[] Short names of every trait in the chain (for `mount<Trait>` hooks)
---@field complete boolean Every trait and parent up to Livewire's base class was found
---@field root string

---@param path string
---@param root string
---@return livewire.Index?
function M.index(path, root)
  local class = M.file(path)
  if not class then
    return nil
  end
  local index = { file = path, name = class.name, members = {}, list = {}, traits = {}, complete = true, root = root }
  local seen = {}

  local function merge(c)
    for _, m in ipairs(c.members) do
      if not index.members[m.name] then
        index.members[m.name] = m
        index.list[#index.list + 1] = m
      end
    end
  end

  local function walk(c)
    index.complete = index.complete and not c.magic
    merge(c)
    -- traits before the parent, as PHP resolves them
    local supers = vim.list_extend({}, c.traits)
    for _, trait in ipairs(c.traits) do
      index.traits[#index.traits + 1] = trait:match("([^\\]+)$")
    end
    if c.parent then
      supers[#supers + 1] = c.parent
    end
    for _, fqcn in ipairs(supers) do
      if not M.stop[fqcn] and not seen[fqcn] then
        seen[fqcn] = true
        local file = components.class_to_file(fqcn, root)
        local super = file and M.file(file)
        if super then
          walk(super)
        else
          index.complete = false
        end
      end
    end
  end
  walk(class)
  return index
end

--- Whether a class (by FQCN) extends Livewire\Form somewhere up its chain.
---@param fqcn string
---@param root string
---@return string? file The class's file when it is a Form object
function M.form_file(fqcn, root)
  local file = components.class_to_file(fqcn, root)
  local current, seen = file, {}
  while current and not seen[current] do
    seen[current] = true
    local class = M.file(current)
    if not class or not class.parent then
      return nil
    elseif class.parent == "Livewire\\Form" then
      return file
    end
    current = components.class_to_file(class.parent, root)
  end
end

--- Index of the Form object behind a property, when its type is one.
---@param index livewire.Index
---@param name string property name
---@return livewire.Index?
function M.form_index(index, name)
  local m = index.members[name]
  local file = m and m.kind == "property" and m.type and M.form_file(m.type, index.root)
  return file and M.index(file, index.root) or nil
end

---@param name string
---@param traits string[]
local function is_hook(name, traits)
  if vim.tbl_contains({ "mount", "boot", "booted", "exception", "rendering", "rendered", "scriptSrc" }, name) then
    return true
  end
  for _, prefix in ipairs({ "hydrate", "dehydrate", "updating", "updated" }) do
    if vim.startswith(name, prefix) then
      return true
    end
  end
  for _, trait in ipairs(traits) do
    for _, hook in ipairs({ "mount", "boot", "booted" }) do
      if name == hook .. trait then
        return true
      end
    end
  end
  return false
end

---@alias livewire.CallProblem "missing"|"not_public"|"static"|"hook"|"render"|"magic_method"

--- Why the browser can't call a method, or nil when it can.
---@param index livewire.Index
---@param name string
---@return livewire.CallProblem?
function M.call_problem(index, name)
  local m = index.members[name]
  if not m or m.kind ~= "method" then
    return "missing"
  elseif name:sub(1, 2) == "__" then
    return "magic_method"
  elseif m.visibility ~= "public" then
    return "not_public"
  elseif m.static then
    return "static"
  elseif name == "render" then
    return "render"
  elseif is_hook(name, index.traits) then
    return "hook"
  end
end

--- Why the browser can't set a property, or nil when it can.
---@param index livewire.Index
---@param name string
---@return "missing"|"not_public"|"static"|nil
function M.set_problem(index, name)
  local m = index.members[name]
  if not m or m.kind ~= "property" then
    return "missing"
  elseif m.visibility ~= "public" then
    return "not_public"
  elseif m.static then
    return "static"
  end
end

---@param index livewire.Index
---@return livewire.Member[]
function M.properties(index)
  return vim.tbl_filter(function(m)
    return m.kind == "property" and not M.set_problem(index, m.name)
  end, index.list)
end

---@param index livewire.Index
---@return livewire.Member[]
function M.methods(index)
  return vim.tbl_filter(function(m)
    return m.kind == "method" and not M.call_problem(index, m.name)
  end, index.list)
end

--- Index of the component owning a Blade buffer.
---@param buf integer
---@return livewire.Index?
function M.for_buffer(buf)
  if not M.available() then
    return nil
  end
  local owner, root = components.owner(buf)
  return owner and root and M.index(owner, root) or nil
end

function M.reset()
  file_cache = {}
  M.seen = {}
end

return M
