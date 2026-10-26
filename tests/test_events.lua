local events = require("livewire.catalog.events")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T["mouseenter is an event"] = function()
  eq(events.names.mouseenter, true)
end

T["keydown is a keyboard event, click is not"] = function()
  eq(events.keyboard.keydown, true)
  eq(events.keyboard.click, nil)
end

T["common events are all valid events"] = function()
  for name in pairs(events.common) do
    eq({ name, events.names[name] }, { name, true })
  end
end

T["modifier names are unique"] = function()
  local seen = {}
  for _, mod in ipairs(events.modifiers) do
    eq(seen[mod.name], nil)
    seen[mod.name] = true
  end
end

return T
