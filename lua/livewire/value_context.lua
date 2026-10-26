-- Where the cursor is when it isn't on a `wire:` attribute name: inside the value of a
-- `wire:` attribute, or after `$wire.`.
local catalog = require("livewire.catalog")

local M = {}

---@class livewire.ValueContext
---@field kind "value"
---@field directive string Directive name, e.g. "model"
---@field sub? string Colon sub-name
---@field value string The whole value, without quotes (lines joined with "\n")
---@field offset integer Bytes of `value` before the cursor

---@class livewire.WireContext
---@field kind "wire"
---@field partial string Text typed after `$wire.`
---@field start_col integer 0-based column where `partial` starts

---@param buf integer
---@param srow integer
---@param scol integer
---@param erow integer
---@param ecol integer
local function text_between(buf, srow, scol, erow, ecol)
  return table.concat(vim.api.nvim_buf_get_text(buf, srow, scol, erow, ecol, {}), "\n")
end

---@return livewire.ValueContext|false|nil false when tree-sitter says it is not a wire: value
local function from_tree(buf, row, col)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "blade", { error = false })
  if not ok or not parser then
    return nil
  end
  local tree = parser:parse({ row, row + 1 })[1]
  local node = tree and tree:root():named_descendant_for_range(row, col, row, col)
  while node and node:type() ~= "attribute" do
    if node:type() == "start_tag" or node:type() == "element" or node:type() == "document" then
      return nil
    end
    node = node:parent()
  end
  if not node then
    return nil
  end
  local name_node, quoted
  for child in node:iter_children() do
    if child:type() == "attribute_name" then
      name_node = child
    elseif child:type() == "quoted_attribute_value" then
      quoted = child
    end
  end
  if not name_node or not quoted then
    return nil
  end
  local parsed = catalog.parse(vim.treesitter.get_node_text(name_node, buf))
  if not parsed or parsed.prefix ~= "wire:" then
    return false
  end
  local srow, scol, erow, ecol = quoted:range()
  -- inside the quotes: after the opening one, up to and including the closing one
  local after_open = row > srow or (row == srow and col >= scol + 1)
  local before_close = row < erow or (row == erow and col <= ecol - 1)
  if not (after_open and before_close) then
    return false
  end
  local value = text_between(buf, srow, scol + 1, erow, math.max(ecol - 1, 0))
  return {
    kind = "value",
    directive = parsed.name.text,
    sub = parsed.sub and parsed.sub.text,
    value = erow == srow and ecol - 1 < scol + 1 and "" or value,
    offset = #text_between(buf, srow, scol + 1, row, col),
  }
end

--- Without a parser (or with an unclosed quote): `wire:x="…` before the cursor on this line.
---@param line string
---@param col integer 0-based cursor column
---@return livewire.ValueContext?
function M.from_line(line, col)
  local before = line:sub(1, col)
  for _, q in ipairs({ '"', "'" }) do
    local attr, partial = before:match("%s(wire:[%w_%-:%.]+)%s*=%s*" .. q .. "([^" .. q .. "]*)$")
    if attr then
      local parsed = catalog.parse(attr)
      local rest = line:sub(col + 1):match("^[^" .. q .. "]*")
      return {
        kind = "value",
        directive = parsed.name.text,
        sub = parsed.sub and parsed.sub.text,
        value = partial .. rest,
        offset = #partial,
      }
    end
  end
end

--- Value or `$wire.` context at a buffer position.
---@param buf integer
---@param row integer 0-based
---@param col integer 0-based cursor byte column
---@return livewire.ValueContext|livewire.WireContext|nil
function M.at(buf, row, col)
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
  local partial = line:sub(1, col):match("%$wire%.([%w_%$]*)$")
  if partial then
    return { kind = "wire", partial = partial, start_col = col - #partial }
  end
  local ctx = from_tree(buf, row, col)
  if ctx == false then
    return nil
  end
  return ctx or M.from_line(line, col)
end

---@class livewire.Typing
---@field want "property"|"form_property"|"action"|"member"|"argument_property"
---@field partial string
---@field form? string Form object property, for "form_property"

--- What is being typed at the cursor inside a value of the given kind, or nil when it
--- isn't a member reference.
---@param ctx livewire.ValueContext
---@param kind livewire.ValueKind
---@return livewire.Typing?
function M.typing(ctx, kind)
  local before = ctx.value:sub(1, ctx.offset)
  if kind == "property" then
    local path = before:match("^%s*([%w_%.]*)$")
    if not path then
      return nil
    end
    local segments = vim.split(path, ".", { plain = true })
    if #segments == 1 then
      return { want = "property", partial = path }
    elseif #segments == 2 then
      return { want = "form_property", partial = segments[2], form = segments[1] }
    end
  elseif kind == "action" then
    local arg = before:match("^%s*%$set%(%s*['\"]([%w_]*)$") or before:match("^%s*%$toggle%(%s*['\"]([%w_]*)$")
    if arg then
      return { want = "argument_property", partial = arg }
    end
    local name = before:match("^%s*(%$?[%w_]*)$")
    return name and { want = "action", partial = name }
  elseif kind == "targets" then
    local entry = before:match("^%s*([%w_]*)$") or before:match(",%s*([%w_]*)$")
    return entry and { want = "member", partial = entry }
  elseif kind == "expression" then
    local name = before:match("[%w_]*$")
    local prev = before:sub(-#name - 1, -#name - 1)
    if prev ~= "." and prev ~= "$" and not name:match("^%d") then
      return { want = "member", partial = name }
    end
  end
end

return M
