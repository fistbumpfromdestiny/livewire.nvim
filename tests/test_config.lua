local config = require("livewire.config")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T["definition options merge one level deep"] = function()
  local opts = config.set({ definition = { blade_components = false } })
  eq(opts.definition, { enabled = true, blade_components = false })
end

T["lists replace the default"] = function()
  local opts = config.set({ scan_paths = { "app.js" }, custom_directives = { "tooltip" } })
  eq(opts.scan_paths, { "app.js" })
  eq(opts.custom_directives, { "tooltip" })
  eq(config.set({}).definition, { enabled = true, blade_components = true })
end

return T
