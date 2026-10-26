-- What a position in a Blade view refers to: a component file for component tags, or a
-- member declaration for `wire:model`, `wire:click` and friends, `wire:target` entries,
-- `$set('…')` / `$toggle('…')` arguments and `$wire.member`.
local catalog = require("livewire.catalog")
local components = require("livewire.components")
local members = require("livewire.members")
local project = require("livewire.project")
local value_context = require("livewire.value_context")

local M = {}

---@class livewire.Location
---@field file string
---@field row integer 0-based
---@field col integer 0-based byte column

---@param m livewire.Member
---@return livewire.Location
local function location(m)
  return { file = m.file, row = m.row, col = m.col }
end

--- `$wire.member` whose `$wire.member` text contains the cursor.
local function wire_member(line, col)
  local init = 1
  while true do
    local s, e, name = line:find("%$wire%.([%a_][%w_]*)", init)
    if not s then
      return nil
    elseif col + 1 >= s and col + 1 <= e then
      return name
    end
    init = e + 1
  end
end

--- The member a `wire:` value refers to at the cursor: its name, and the Form object
--- property it belongs to for `form.field`.
---@param ctx livewire.ValueContext
---@param kind livewire.ValueKind
---@return string? name
---@return string? form
local function value_member(ctx, kind)
  local before, after = ctx.value:sub(1, ctx.offset), ctx.value:sub(ctx.offset + 1)
  local left, right = before:match("[%w_]*$"), after:match("^[%w_]*")
  local word = left .. right
  local prefix = before:sub(1, #before - #left)
  if word == "" or word:match("^%d") then
    return nil
  end
  if kind == "property" then
    if prefix:match("^%s*$") then
      return word
    end
    local form = prefix:match("^%s*([%a_][%w_]*)%.$")
    return form and word, form
  elseif kind == "action" then
    if prefix:match("^%s*%$set%(%s*['\"]$") or prefix:match("^%s*%$toggle%(%s*['\"]$") then
      return word
    end
    return prefix:match("^%s*$") and word or nil
  elseif kind == "targets" then
    return (prefix:match("^%s*$") or prefix:match(",%s*$")) and word or nil
  elseif kind == "expression" then
    local prev = prefix:sub(-1)
    return prev ~= "." and prev ~= "$" and word or nil
  end
end

--- Definition locations for a buffer position; empty when it isn't a reference the plugin
--- knows, or the target can't be found.
---@param buf integer
---@param row integer 0-based
---@param col integer 0-based byte column
---@return livewire.Location[]
function M.at(buf, row, col)
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""

  local kind, name = components.tag_at(line, col)
  if kind and name then
    local root = project.root(buf)
    local file = root and components.resolve(kind, name, root)
    return file and { { file = file, row = 0, col = 0 } } or {}
  end

  local member, form = wire_member(line, col), nil
  if not member then
    local ctx = value_context.at(buf, row, col)
    if not ctx or ctx.kind ~= "value" then
      return {}
    end
    local resolved = catalog.resolve(ctx.directive, project.version(buf), project.custom_directives(buf))
    member, form = value_member(ctx, catalog.value_kind(resolved, ctx.sub))
  end
  if not member then
    return {}
  end

  local index = members.for_buffer(buf)
  if index and form then
    index = members.form_index(index, form)
  end
  local m = index and index.members[member]
  return m and { location(m) } or {}
end

return M
