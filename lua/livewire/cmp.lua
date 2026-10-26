-- nvim-cmp source with the same items as the blink.cmp source. `setup()` registers it as
-- "livewire" when nvim-cmp is loaded; add `{ name = "livewire" }` to nvim-cmp's sources.
local blink = require("livewire.blink")

local source = {}

function source.new()
  return setmetatable({}, { __index = source })
end

function source:get_debug_name()
  return "livewire"
end

function source:is_available()
  return vim.bo.filetype == "blade"
end

function source:get_trigger_characters()
  return blink.get_trigger_characters()
end

---@param params { context: { bufnr: integer, cursor: { row: integer, col: integer } } }
---@param callback fun(response: { items: table[], isIncomplete: boolean })
function source:complete(params, callback)
  local cursor = params.context.cursor
  local ok, items = pcall(blink.items, params.context.bufnr, cursor.row - 1, cursor.col - 1)
  callback({ items = ok and items or {}, isIncomplete = false })
end

local registered ---@type integer?

--- Register with nvim-cmp when it is installed; safe to call again.
function source.register()
  local ok, cmp = pcall(require, "cmp")
  if not ok then
    return
  end
  if registered then
    pcall(cmp.unregister_source, registered)
  end
  registered = cmp.register_source("livewire", source.new())
end

return source
