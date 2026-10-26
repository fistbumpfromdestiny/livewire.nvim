local H = require("helpers")
local components = require("livewire.components")
local config = require("livewire.config")
local definition = require("livewire.definition")
local members = require("livewire.members")
local project = require("livewire.project")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      config.set({})
      project.reset()
      components.reset()
      members.reset()
      vim.cmd("silent! %bwipeout!")
    end,
  },
})

--- Definitions at the first `needle` (offset into it by `shift`) in a fixture view, as
--- "relative/path:line:text-at-col" strings.
local function defs(path, needle, shift, lines)
  vim.cmd.edit({ vim.fn.fnameescape(H.app .. "/" .. path), bang = true })
  vim.bo.filetype = "blade"
  if lines then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  end
  local buf = vim.api.nvim_get_current_buf()
  for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local s = line:find(needle, 1, true)
    if s then
      return vim.tbl_map(function(loc)
        local target = vim.fn.readfile(loc.file)[loc.row + 1] or ""
        return ("%s:%d:%s"):format(loc.file:sub(#H.app + 2), loc.row + 1, target:sub(loc.col + 1):match("^[%w_]*"))
      end, definition.at(buf, row - 1, s - 1 + (shift or 0)))
    end
  end
  error("needle not found: " .. needle)
end

local greeter = "resources/views/livewire/greeter.blade.php"

T["components"] = MiniTest.new_set()

T["components"]["livewire tag"] = function()
  local view = { "<livewire:greeter />", "@livewire('pages::profile')", "<livewire:missing />", "<x-app-logo />" }
  eq(defs(greeter, "greeter", 2, view), { "app/Livewire/Greeter.php:1:" })
  eq(defs(greeter, "<livewire:greeter", 0, view), { "app/Livewire/Greeter.php:1:" })
  eq(defs(greeter, "profile", 0, view), { "resources/views/pages/⚡profile.blade.php:1:" })
  eq(defs(greeter, "missing", 0, view), {})
  eq(defs(greeter, "app-logo", 0, view), { "resources/views/components/app-logo.blade.php:1:" })
end

T["members"] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      H.skip_without_blade()
      H.skip_without_php()
    end,
  },
})

T["members"]["wire:model"] = function()
  eq(defs(greeter, 'wire:model.live="name"', 18), { "app/Livewire/Greeter.php:14:name" })
end

T["members"]["action with arguments"] = function()
  eq(defs(greeter, 'wire:submit="changeGreeting()"', 15), { "app/Livewire/Greeter.php:28:changeGreeting" })
end

T["members"]["Form object field and the property before it"] = function()
  eq(defs(greeter, 'wire:model="form.title"', 19), { "app/Livewire/Forms/PostForm.php:9:title" })
  eq(defs(greeter, 'wire:model="form.title"', 13), { "app/Livewire/Greeter.php:18:form" })
end

T["members"]["$toggle argument"] = function()
  eq(defs(greeter, "$toggle('open')", 10), { "app/Livewire/Greeter.php:20:open" })
end

T["members"]["wire:target entries"] = function()
  eq(defs(greeter, "changeGreeting, name", 17), { "app/Livewire/Greeter.php:14:name" })
  eq(defs(greeter, "changeGreeting, name", 2), { "app/Livewire/Greeter.php:28:changeGreeting" })
end

T["members"]["$wire member from a parent class"] = function()
  eq(defs(greeter, "$wire.sortBy", 8), { "app/Livewire/BaseTable.php:11:sortBy" })
end

T["members"]["member from a trait"] = function()
  local view = { '<input wire:model="search">' }
  eq(defs(greeter, "search", 1, view), { "app/Concerns/HasSearch.php:7:search" })
end

T["members"]["$wire in a single-file component"] = function()
  eq(defs("resources/views/pages/⚡profile.blade.php", "$wire.save", 7), { "resources/views/pages/⚡profile.blade.php:8:save" })
end

T["members"]["multi-file component"] = function()
  eq(defs("resources/views/components/⚡counter/counter.blade.php", "increment", 0), {
    "resources/views/components/⚡counter/counter.php:8:increment",
  })
end

T["members"]["not member references"] = function()
  local view = { '<div wire:key="item-1" wire:loading.class="opacity-50" wire:click="$refresh">', '<p wire:model="ghost"></p>' }
  eq(defs(greeter, "item-1", 1, view), {})
  eq(defs(greeter, "opacity", 1, view), {})
  eq(defs(greeter, "refresh", 1, view), {})
  eq(defs(greeter, "ghost", 1, view), {})
  eq(defs("resources/views/components/app-logo.blade.php", "x", 0, { '<div wire:click="x">' }), {})
end

return T
