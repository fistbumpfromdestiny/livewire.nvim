local catalog = require("livewire.catalog")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

local function statuses(name, version, chain, custom)
  local resolved = catalog.resolve(name, version, custom)
  local segs = chain == "" and {} or vim.split(chain, ".", { plain = true })
  return vim.tbl_map(function(s)
    return s.status
  end, catalog.check_modifiers(resolved, version, segs))
end

T["versions"] = MiniTest.new_set()

T["versions"]["model exists in both, with per-version docs"] = function()
  for _, v in ipairs({ 3, 4 }) do
    local r = catalog.resolve("model", v)
    eq(r.kind, "directive")
    eq(catalog.docs_url(r.directive, v), ("https://livewire.laravel.com/docs/%d.x/wire-model"):format(v))
  end
end

T["versions"]["ref is v4-only and says so under v3"] = function()
  local r = catalog.resolve("ref", 3)
  eq(r.kind, "other_version")
  eq(r.directive.versions, { 4 })
end

T["versions"]["show and text exist in v3.8"] = function()
  eq(catalog.resolve("show", 3).kind, "directive")
  eq(catalog.resolve("text", 3).kind, "directive")
end

T["versions"]["model.defer is v3-only"] = function()
  eq(statuses("model", 3, "defer"), { "modifier" })
  eq(statuses("model", 4, "defer"), { "other_version" })
end

T["versions"]["v3 directives absent from v4 candidates"] = function()
  local names = vim.tbl_map(function(c)
    return c.name
  end, catalog.candidates(4))
  eq(vim.tbl_contains(names, "scroll"), false)
  eq(vim.tbl_contains(names, "ref"), true)
  names = vim.tbl_map(function(c)
    return c.name
  end, catalog.candidates(3))
  eq(vim.tbl_contains(names, "ref"), false)
  eq(vim.tbl_contains(names, "island"), false)
end

T["modifier arguments"] = MiniTest.new_set()

T["modifier arguments"]["debounce takes a millisecond argument"] = function()
  eq(statuses("model", 4, "live.debounce.500ms"), { "modifier", "modifier", "arg" })
  eq(statuses("model", 4, "live.debounce.500"), { "modifier", "modifier", "arg" })
  eq(statuses("click", 4, "throttle.250ms"), { "modifier", "arg" })
end

T["modifier arguments"]["debounce does not take seconds"] = function()
  eq(statuses("model", 4, "live.debounce.1s"), { "modifier", "modifier", "unknown" })
end

T["modifier arguments"]["poll takes a bare duration anywhere"] = function()
  eq(statuses("poll", 4, "5s"), { "arg" })
  eq(statuses("poll", 4, "keep-alive.15000ms"), { "modifier", "arg" })
  eq(statuses("poll", 3, "1m"), { "arg" })
end

T["modifier arguments"]["loading delay levels"] = function()
  eq(statuses("loading", 4, "delay.long"), { "modifier", "arg" })
  eq(statuses("loading", 4, "delay"), { "modifier" })
  eq(statuses("loading", 4, "class.remove"), { "modifier", "modifier" })
end

T["modifier arguments"]["intersect threshold and multi-value margin"] = function()
  eq(statuses("intersect", 4, "threshold.50"), { "modifier", "arg" })
  eq(statuses("intersect", 4, "once.half.margin.100px.10%"), { "modifier", "modifier", "modifier", "arg", "arg" })
end

T["modifier arguments"]["wire:model layering chain"] = function()
  eq(statuses("model", 4, "blur.live.debounce.500ms"), { "modifier", "modifier", "modifier", "arg" })
end

T["events"] = MiniTest.new_set()

T["events"]["mouseenter is a known event with event modifiers"] = function()
  local r = catalog.resolve("mouseenter", 4)
  eq(r.kind, "event")
  local names = vim.tbl_map(function(m)
    return m.name
  end, catalog.modifiers(r, 4))
  eq(vim.tbl_contains(names, "prevent"), true)
end

T["events"]["keyboard events accept any modifier"] = function()
  eq(statuses("keydown", 4, "shift.arrow-up.prevent"), { "modifier", "modifier", "modifier" })
  eq(catalog.modifiers(catalog.resolve("keydown", 4), 4), nil)
end

T["events"]["v4-only event modifiers"] = function()
  eq(statuses("click", 4, "async.renderless.preserve-scroll"), { "modifier", "modifier", "modifier" })
  eq(statuses("click", 3, "renderless"), { "other_version" })
end

T["events"]["submit is an event, not a directive"] = function()
  local r = catalog.resolve("submit", 4)
  eq(r.kind, "event")
  eq(catalog.event_docs_url("submit", 4), "https://livewire.laravel.com/docs/4.x/wire-submit")
end

T["internal and custom"] = MiniTest.new_set()

T["internal and custom"]["internal attributes"] = function()
  for _, name in ipairs({ "id", "name", "snapshot", "effects" }) do
    eq(catalog.resolve(name, 4).kind, "internal")
  end
  local names = vim.tbl_map(function(c)
    return c.name
  end, catalog.candidates(4))
  for _, name in ipairs({ "id", "name", "snapshot", "effects" }) do
    eq(vim.tbl_contains(names, name), false)
  end
end

T["internal and custom"]["custom directives accept anything"] = function()
  local custom = { tooltip = true }
  local r = catalog.resolve("tooltip", 4, custom)
  eq(r.kind, "custom")
  eq(catalog.subnames(r, 4), "any")
  eq(statuses("tooltip", 4, "top.whatever", custom), { "modifier", "modifier" })
  local c = vim.tbl_filter(function(x)
    return x.name == "tooltip"
  end, catalog.candidates(4, custom))
  eq(#c, 1)
  eq(c[1].kind, "custom")
end

T["unknown"] = MiniTest.new_set()

T["unknown"]["misspelled directive suggests the real one"] = function()
  local r = catalog.resolve("modle", 4)
  eq(r.kind, "unknown")
  eq(r.suggestion, "model")
end

T["unknown"]["misspelled modifier suggests the real one"] = function()
  local r = catalog.resolve("model", 4)
  local s = catalog.check_modifiers(r, 4, { "lve" })
  eq(s[1].status, "unknown")
  eq(s[1].suggestion, "live")
end

T["subnames"] = function()
  local subs = vim.tbl_map(function(s)
    return s.name
  end, catalog.subnames(catalog.resolve("sort", 4), 4))
  eq(vim.tbl_contains(subs, "item"), true)
  eq(vim.tbl_contains(subs, "handle"), true)
  eq(catalog.subnames(catalog.resolve("bind", 4), 4), "any")
  eq(catalog.subnames(catalog.resolve("model", 4), 4), nil)
  eq(#catalog.subnames(catalog.resolve("navigate", 3), 3), 0)
end

T["parse"] = function()
  eq(catalog.parse("wire:model.live.debounce.500ms"), {
    prefix = "wire:",
    name = { text = "model", start = 5 },
    modifiers = {
      { text = "live", start = 11 },
      { text = "debounce", start = 16 },
      { text = "500ms", start = 25 },
    },
  })
  eq(catalog.parse("wire:sort:group-id"), {
    prefix = "wire:",
    name = { text = "sort", start = 5 },
    sub = { text = "group-id", start = 10 },
    modifiers = {},
  })
  eq(catalog.parse("wire.model").prefix, "wire.")
  eq(catalog.parse("x-model"), nil)
  eq(catalog.parse("wire:model.").modifiers, { { text = "", start = 11 } })
end

return T
