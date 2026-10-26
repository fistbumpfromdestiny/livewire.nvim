-- blink.cmp (v1) source: `wire:` directive names, sub-names and modifiers in Blade files.
--
--   sources.providers.livewire = { name = "Livewire", module = "livewire.blink" }
local catalog = require("livewire.catalog")
local context = require("livewire.context")
local events = require("livewire.catalog.events")
local project = require("livewire.project")

local Kind = vim.lsp.protocol.CompletionItemKind

---@class livewire.BlinkSource
local source = {}

function source.new(opts)
  return setmetatable({ opts = opts or {} }, { __index = source })
end

function source:enabled()
  return vim.bo.filetype == "blade"
end

function source:get_trigger_characters()
  return { ":", "." }
end

---@param ctx livewire.Context
---@param row integer 0-based
---@param col integer 0-based cursor column
local function item(ctx, row, col, label, kind, doc, sort)
  return {
    label = label,
    kind = kind,
    sortText = sort and ("%03d"):format(sort) or nil,
    textEdit = {
      newText = label,
      range = {
        start = { line = row, character = ctx.start_col },
        ["end"] = { line = row, character = col },
      },
    },
    documentation = doc and { kind = "markdown", value = doc } or nil,
  }
end

local function doc(desc, url)
  return url and desc .. "\n\n" .. url or desc
end

local function directive_items(ctx, row, col, version, custom)
  local items = {}
  for _, c in ipairs(catalog.candidates(version, custom)) do
    local desc = c.kind == "custom" and "*Custom directive* defined by this project" or c.desc
    items[#items + 1] = item(ctx, row, col, c.name, Kind.Keyword, doc(desc, c.docs_url))
  end
  return items
end

local function subname_items(ctx, row, col, resolved, version)
  local subs = catalog.subnames(resolved, version)
  if type(subs) ~= "table" then
    return {}
  end
  return vim.tbl_map(function(s)
    return item(ctx, row, col, s.name, Kind.EnumMember, s.desc)
  end, subs)
end

local function modifier_items(ctx, row, col, resolved, version)
  if resolved.kind == "custom" then
    return {}
  end
  local items = {}
  local is_keyboard = resolved.kind == "event" and events.keyboard[resolved.name]
  local statuses = catalog.check_modifiers(resolved, version, ctx.modifiers)
  local last = statuses[#statuses]
  local last_mod = last and last.status == "modifier" and last.modifier
  if last and last.status == "modifier" and is_keyboard then
    -- keyboard events accept anything, so the check doesn't say which modifier it was
    last_mod = vim.iter(events.modifiers):find(function(m)
      return m.name == ctx.modifiers[#ctx.modifiers]
    end)
  end
  -- right after an argument-taking modifier only its values make sense
  if last_mod and last_mod.arg then
    local arg = last_mod.arg
    local values = type(arg) == "table" and arg or catalog.arg_examples[arg]
    for i, value in ipairs(values) do
      items[#items + 1] = item(ctx, row, col, value, Kind.Value, ("Argument of `.%s`"):format(last_mod.name), i)
    end
    return items
  end

  local used = {}
  for _, seg in ipairs(ctx.modifiers) do
    used[seg] = true
  end
  local mods = is_keyboard
      and vim.tbl_filter(function(m)
        return vim.tbl_contains(m.versions, version)
      end, events.modifiers)
    or catalog.modifiers(resolved, version)
    or {}
  for _, m in ipairs(mods) do
    if not used[m.name] then
      items[#items + 1] = item(ctx, row, col, m.name, Kind.EnumMember, m.desc)
    end
  end
  if is_keyboard then
    for _, key in ipairs(events.keys) do
      if not used[key] then
        items[#items + 1] = item(ctx, row, col, key, Kind.EnumMember, ("Only when the `%s` key is involved"):format(key))
      end
    end
  end
  local bare = resolved.directive and resolved.directive.bare_arg
  if bare then
    for i, value in ipairs(catalog.arg_examples[bare]) do
      items[#items + 1] = item(ctx, row, col, value, Kind.Value, "Interval", i)
    end
  end
  return items
end

--- Items for the cursor position; exposed for tests.
---@param buf integer
---@param row integer 0-based
---@param col integer 0-based
function source.items(buf, row, col)
  if vim.bo[buf].filetype ~= "blade" then
    return {}
  end
  local ctx = context.at(buf, row, col)
  if not ctx then
    return {}
  end
  local version = project.version(buf)
  local custom = project.custom_directives(buf)
  if ctx.kind == "directive" then
    return directive_items(ctx, row, col, version, custom)
  end
  local resolved = catalog.resolve(ctx.name, version, custom)
  if ctx.kind == "subname" then
    return subname_items(ctx, row, col, resolved, version)
  end
  return modifier_items(ctx, row, col, resolved, version)
end

function source:get_completions(ctx, callback)
  local ok, items = pcall(source.items, ctx.bufnr, ctx.cursor[1] - 1, ctx.cursor[2])
  callback({
    items = ok and items or {},
    is_incomplete_forward = false,
    is_incomplete_backward = false,
  })
end

return source
