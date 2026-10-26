local H = require("helpers")
local blink = require("livewire.blink")
local config = require("livewire.config")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      config.set({})
      vim.cmd("silent! %bwipeout!")
    end,
  },
})

local function labels(items)
  local out = vim.tbl_map(function(i)
    return i.label
  end, items)
  table.sort(out)
  return out
end

--- Open a Blade buffer at `path` (inside the app fixture) with `line`, cursor at `|`.
local function open(path, line)
  vim.cmd.edit(vim.fn.fnameescape(H.app .. "/" .. path))
  local col = line:find("|", 1, true) - 1
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { line:sub(1, col) .. line:sub(col + 2) })
  vim.bo.filetype = "blade"
  vim.api.nvim_win_set_cursor(0, { 1, col })
  return vim.api.nvim_get_current_buf(), col
end

--- Ask the registered source through nvim-cmp's own context object.
local function complete(buf)
  local cmp_source = vim.iter(require("cmp").get_registered_sources()):find(function(s)
    return s.name == "livewire"
  end)
  local response
  local ctx = require("cmp.context").new()
  cmp_source.source:complete({ context = ctx, offset = ctx.cursor.col }, function(r)
    response = r
  end)
  eq(ctx.bufnr, buf)
  return response
end

T["setup registers the source once"] = function()
  require("livewire").setup({})
  require("livewire").setup({})
  local found = vim.tbl_filter(function(s)
    return s.name == "livewire"
  end, require("cmp").get_registered_sources())
  eq(#found, 1)
  eq(found[1].source:get_trigger_characters(), blink.get_trigger_characters())
end

T["same items as the blink source"] = function()
  H.skip_without_blade()
  require("livewire").setup({})
  local buf, col = open("resources/views/livewire/greeter.blade.php", "<input wire:mo|")
  local response = complete(buf)
  eq(response.isIncomplete, false)
  eq(labels(response.items), labels(blink.items(buf, 0, col)))
  eq(vim.tbl_contains(labels(response.items), "model"), true)
end

T["member items through nvim-cmp"] = function()
  H.skip_without_blade()
  H.skip_without_php()
  require("livewire").setup({})
  local buf, col = open("resources/views/livewire/greeter.blade.php", '<input wire:model="|">')
  local items = complete(buf).items
  eq(labels(items), labels(blink.items(buf, 0, col)))
  eq(vim.tbl_contains(labels(items), "name"), true)
end

T["unavailable outside Blade"] = function()
  local source = require("livewire.cmp").new()
  vim.bo.filetype = "php"
  eq(source:is_available(), false)
  vim.bo.filetype = "blade"
  eq(source:is_available(), true)
end

return T
