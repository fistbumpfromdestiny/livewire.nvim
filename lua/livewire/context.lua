-- What is being typed at the cursor: a `wire:` directive name, sub-name or modifier.
local M = {}

---@class livewire.Context
---@field kind "directive"|"subname"|"modifier"
---@field name? string Directive name (not set for kind "directive")
---@field sub? string Colon sub-name, when present
---@field modifiers string[] Completed modifier segments before the partial one
---@field partial string Text typed so far of the segment under the cursor
---@field start_col integer 0-based byte column where `partial` starts
---@field token_col integer 0-based byte column where `wire:` starts

--- Parse the `wire:` token that ends at byte `col` of `line`.
---@param line string
---@param col integer 0-based cursor column (bytes before the cursor)
---@return livewire.Context?
function M.parse_token(line, col)
  local before = line:sub(1, col)
  local token_start = before:find("[%w_%-:%.]*$")
  local token = before:sub(token_start)
  -- attribute names follow whitespace; this also rejects `$wire:`, `x-wire:`, `<livewire:`
  if token:sub(1, 5) ~= "wire:" or (token_start > 1 and not before:sub(token_start - 1, token_start - 1):match("%s")) then
    return nil
  end
  local token_col = token_start - 1
  local rest = token:sub(6)
  local dot = rest:find(".", 1, true)
  local head = dot and rest:sub(1, dot - 1) or rest
  local colon = head:find(":", 1, true)
  local name = colon and head:sub(1, colon - 1) or head
  local sub = colon and head:sub(colon + 1) or nil

  if not dot then
    if colon then
      if sub:find(":", 1, true) then
        return nil
      end
      return { kind = "subname", name = name, partial = sub, modifiers = {}, start_col = col - #sub, token_col = token_col }
    end
    return { kind = "directive", partial = name, modifiers = {}, start_col = col - #name, token_col = token_col }
  end

  local segments = vim.split(rest:sub(dot + 1), ".", { plain = true })
  local partial = table.remove(segments)
  if name == "" then
    return nil
  end
  return {
    kind = "modifier",
    name = name,
    sub = sub,
    modifiers = segments,
    partial = partial,
    start_col = col - #partial,
    token_col = token_col,
  }
end

local reject = {
  text = true,
  attribute_value = true,
  quoted_attribute_value = true,
  comment = true,
  php_only = true,
  php_statement = true,
}

--- Whether (row, col) sits in an attribute name, according to the blade tree.
---@return boolean? nil when tree-sitter can't tell
local function ts_in_attribute_name(buf, row, col)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "blade", { error = false })
  if not ok or not parser then
    return nil
  end
  local tree = parser:parse({ row, row + 1 })[1]
  if not tree then
    return nil
  end
  local node = tree:root():named_descendant_for_range(row, col, row, col)
  while node do
    local type = node:type()
    if type == "attribute_name" then
      return true
    elseif reject[type] then
      return false
    end
    node = node:parent()
  end
  return nil
end

--- Without a parser: inside an unclosed `<tag` on this line, and not inside quotes.
---@param before string line text before the token
local function line_in_tag(before)
  local open = before:match(".*()<[%w_:%-]")
  if not open or before:find(">", open, true) then
    return false
  end
  local _, quotes = before:sub(open):gsub('"', "")
  local _, squotes = before:sub(open):gsub("'", "")
  return quotes % 2 == 0 and squotes % 2 == 0
end

--- Completion context at a buffer position, or nil when not typing a `wire:` attribute name.
---@param buf integer
---@param row integer 0-based
---@param col integer 0-based cursor byte column
---@return livewire.Context?
function M.at(buf, row, col)
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
  local ctx = M.parse_token(line, col)
  if not ctx then
    return nil
  end
  local in_name = ts_in_attribute_name(buf, row, ctx.token_col)
  if in_name == nil then
    in_name = line_in_tag(line:sub(1, ctx.token_col))
  end
  return in_name and ctx or nil
end

return M
