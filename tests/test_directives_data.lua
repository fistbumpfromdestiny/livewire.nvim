local H = require("helpers")
local directives = require("livewire.catalog.directives")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

local by_name = {}
for _, d in ipairs(directives) do
  by_name[d.name] = d
end

--- Directive names (with sub-names) the extraction script finds in a bundle.
local function bundle_names(bundle)
  local out = vim.fn.system({ H.root .. "/scripts/bundle-directives.sh", bundle })
  assert(vim.v.shell_error == 0, out)
  local names, section = {}, nil
  for line in vim.gsplit(out, "\n") do
    section = line:match("^== (.*)") or section
    if section and not line:match("^==") and line ~= "" then
      if section:match("^Livewire directive registrations") or section:match("^Directives handled by attribute prefix") then
        for name in line:gmatch("%S+") do
          names[name] = true
        end
      elseif section:match("^Every wire: attribute literal") then
        for name in line:gmatch("wire:([%w%-:]+)") do
          names[name] = true
        end
      end
    end
  end
  return names
end

local internal = { id = true, name = true, snapshot = true, effects = true }

for major, bundle in pairs({
  [4] = vim.env.LIVEWIRE_V4_BUNDLE or vim.fn.expand("~/Lerd/livewire/vendor/livewire/livewire/dist/livewire.esm.js"),
  [3] = vim.env.LIVEWIRE_V3_BUNDLE,
}) do
  T["every v" .. major .. " bundle directive has an entry"] = function()
    if not bundle or not vim.uv.fs_stat(bundle) then
      MiniTest.skip("no Livewire " .. major .. " bundle (set LIVEWIRE_V" .. major .. "_BUNDLE)")
    end
    for name in pairs(bundle_names(bundle)) do
      local base, sub = name:match("^([^:]+):?(.*)$")
      if not internal[base] then
        local d = by_name[base]
        eq({ name, d ~= nil and vim.tbl_contains(d.versions, major) }, { name, true })
        if sub ~= "" then
          local subs = vim.tbl_map(function(s)
            return s.name
          end, d.subnames == "any" and {} or d.subnames or {})
          eq({ name, d.subnames == "any" or vim.tbl_contains(subs, sub) }, { name, true })
        end
      end
    end
  end
end

T["every listed v4 $wire magic is in the bundle"] = function()
  local bundle = vim.env.LIVEWIRE_V4_BUNDLE or vim.fn.expand("~/Lerd/livewire/vendor/livewire/livewire/dist/livewire.esm.js")
  if not vim.uv.fs_stat(bundle) then
    MiniTest.skip("no Livewire 4 bundle (set LIVEWIRE_V4_BUNDLE)")
  end
  local out = vim.fn.system({ H.root .. "/scripts/bundle-directives.sh", bundle })
  local defined = {}
  for name in (out:match("== %$wire magic properties[^\n]*\n([^\n]*)") or ""):gmatch("%S+") do
    defined[name] = true
  end
  eq(defined["$refresh"], true)
  local magics = require("livewire.catalog.magics")
  for _, m in ipairs(magics.for_version(magics.wire, 4)) do
    eq({ m.name, defined[m.name] }, { m.name, true })
  end
  -- actions are $wire properties too, except $event (Alpine's)
  for _, m in ipairs(magics.for_version(magics.actions, 4)) do
    eq({ m.name, m.name == "$event" or defined[m.name] }, { m.name, true })
  end
end

T["Alpine plugin directives are not wire: directives"] = function()
  for _, name in ipairs({ "anchor", "collapse", "mask", "trap", "resize", "data", "for", "if" }) do
    eq({ name, by_name[name] }, { name, nil })
  end
end

T["entries are well formed"] = function()
  for _, d in ipairs(directives) do
    eq(type(d.desc), "string")
    eq(#d.versions > 0, true)
    for _, v in ipairs(d.versions) do
      local docs = type(d.docs) == "table" and d.docs[v] or d.docs
      eq({ d.name, v, type(docs) }, { d.name, v, "string" })
    end
    local seen = {}
    for _, m in ipairs(d.modifiers) do
      eq({ d.name, m.name, seen[m.name] }, { d.name, m.name, nil })
      seen[m.name] = true
      eq(type(m.desc), "string")
    end
  end
end

return T
