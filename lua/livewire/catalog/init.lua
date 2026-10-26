-- Queries over the directive data. Completion and diagnostics both go through here so
-- they agree on what is valid.
local directives = require("livewire.catalog.directives")
local events = require("livewire.catalog.events")
local util = require("livewire.util")

local M = {}

M.DOCS_BASE = "https://livewire.laravel.com/docs/%d.x/%s"

--- Attributes Livewire writes into rendered markup; never typed by hand.
M.internal = { id = true, name = true, snapshot = true, effects = true }

---@type table<string, livewire.Directive>
local by_name = {}
for _, d in ipairs(directives) do
  by_name[d.name] = d
end

local function has_version(entry, version)
  return vim.tbl_contains(entry.versions, version)
end

---@param d livewire.Directive
---@param version integer
---@return string?
function M.docs_url(d, version)
  local path = type(d.docs) == "table" and d.docs[version] or d.docs
  return path and M.DOCS_BASE:format(version, path)
end

---@param event string
---@param version integer
function M.event_docs_url(event, version)
  local path = (event == "click" or event == "submit") and "wire-" .. event or "actions#event-listeners"
  return M.DOCS_BASE:format(version, path)
end

---@class livewire.Resolved
---@field kind "directive"|"event"|"custom"|"internal"|"other_version"|"unknown"
---@field name string
---@field directive? livewire.Directive Set for "directive" and "other_version"
---@field suggestion? string Set for "unknown" when a known name is close

--- What `wire:<name>` refers to for a Livewire major version.
---@param name string
---@param version integer
---@param custom? table<string, true>
---@return livewire.Resolved
function M.resolve(name, version, custom)
  local d = by_name[name]
  if M.internal[name] then
    return { kind = "internal", name = name }
  elseif custom and custom[name] then
    return { kind = "custom", name = name }
  elseif d and has_version(d, version) then
    return { kind = "directive", name = name, directive = d }
  elseif events.names[name] then
    return { kind = "event", name = name }
  elseif d then
    return { kind = "other_version", name = name, directive = d }
  end
  local candidates = {}
  for _, entry in ipairs(directives) do
    if has_version(entry, version) then
      candidates[#candidates + 1] = entry.name
    end
  end
  vim.list_extend(candidates, vim.tbl_keys(events.names))
  vim.list_extend(candidates, vim.tbl_keys(custom or {}))
  table.sort(candidates) -- deterministic tie-breaking
  return { kind = "unknown", name = name, suggestion = util.suggest(name, candidates) }
end

---@class livewire.Candidate
---@field name string
---@field kind "directive"|"event"|"custom"
---@field desc string
---@field docs_url? string

--- Directive names to offer after `wire:`.
---@param version integer
---@param custom? table<string, true>
---@return livewire.Candidate[]
function M.candidates(version, custom)
  local out = {}
  for _, d in ipairs(directives) do
    if has_version(d, version) then
      out[#out + 1] = { name = d.name, kind = "directive", desc = d.desc, docs_url = M.docs_url(d, version) }
    end
  end
  for name, desc in pairs(events.common) do
    if not by_name[name] then
      out[#out + 1] = { name = name, kind = "event", desc = desc, docs_url = M.event_docs_url(name, version) }
    end
  end
  for name in pairs(custom or {}) do
    if not by_name[name] then
      out[#out + 1] = { name = name, kind = "custom", desc = "Custom directive defined by this project" }
    end
  end
  table.sort(out, function(a, b)
    return a.name < b.name
  end)
  return out
end

--- Sub-names (`wire:<name>:<sub>`) for a resolved name: a list, "any", or nil when it takes none.
---@param resolved livewire.Resolved
---@param version integer
---@return livewire.Subname[]|"any"|nil
function M.subnames(resolved, version)
  if resolved.kind == "custom" then
    return "any"
  elseif resolved.kind ~= "directive" or not resolved.directive.subnames then
    return nil
  elseif resolved.directive.subnames == "any" then
    return "any"
  end
  return vim.tbl_filter(function(s)
    return has_version(s, version)
  end, resolved.directive.subnames --[[@as livewire.Subname[] ]])
end

--- Every modifier spec for a resolved name, regardless of version; nil when any modifier
--- is accepted (custom directives, keyboard events).
---@param resolved livewire.Resolved
---@return livewire.Modifier[]?
local function all_modifiers(resolved)
  if resolved.kind == "custom" or (resolved.kind == "event" and events.keyboard[resolved.name]) then
    return nil
  elseif resolved.kind == "event" then
    return events.modifiers
  end
  return resolved.directive and resolved.directive.modifiers or {}
end

--- Modifiers valid for a resolved name in a version; nil when anything goes.
---@param resolved livewire.Resolved
---@param version integer
---@return livewire.Modifier[]?
function M.modifiers(resolved, version)
  local mods = all_modifiers(resolved)
  return mods
    and vim.tbl_filter(function(m)
      return has_version(m, version)
    end, mods)
end

--- What the value of `wire:<name>[:<sub>]` refers to. Unknown names are forwarded to Alpine
--- as event listeners, so like events their value is an action.
---@param resolved livewire.Resolved
---@param sub? string
---@return livewire.ValueKind
function M.value_kind(resolved, sub)
  if resolved.kind == "event" or resolved.kind == "unknown" then
    return "action"
  elseif not resolved.directive or resolved.kind ~= "directive" then
    return "none"
  end
  local d = resolved.directive
  if sub and type(d.subnames) == "table" then
    for _, s in ipairs(d.subnames --[[@as livewire.Subname[] ]]) do
      if s.name == sub then
        return s.value or d.value
      end
    end
  end
  return d.value
end

local arg_patterns = {
  ms = { "^%d+$", "^%d+ms$" },
  duration = { "^%d+ms$", "^%d+s$", "^%d+m$" },
  number = { "^%d+$" },
  length = { "^%-?%d+$", "^%-?%d+px$", "^%-?%d+%%$" },
}

--- Example values offered in completion after an argument-taking modifier.
M.arg_examples = {
  ms = { "250ms", "500ms", "1000ms" },
  duration = { "500ms", "5s", "15s", "1m" },
  number = { "25", "50", "75" },
  length = { "100px", "200px", "10%" },
}

---@param kind livewire.ArgKind
---@param segment string
---@return boolean
function M.match_arg(kind, segment)
  if type(kind) == "table" then
    return vim.tbl_contains(kind, segment)
  end
  for _, pattern in ipairs(arg_patterns[kind]) do
    if segment:match(pattern) then
      return true
    end
  end
  return false
end

---@class livewire.SegmentStatus
---@field status "modifier"|"arg"|"unknown"|"other_version"
---@field modifier? livewire.Modifier The modifier itself, or the one this segment is an argument of
---@field suggestion? string

--- Classify each modifier segment of `wire:<name>.<seg>.<seg>`.
---@param resolved livewire.Resolved
---@param version integer
---@param segments string[]
---@return livewire.SegmentStatus[]
function M.check_modifiers(resolved, version, segments)
  local out = {}
  local all = all_modifiers(resolved)
  if not all then
    for i in ipairs(segments) do
      out[i] = { status = "modifier" }
    end
    return out
  end
  local valid = M.modifiers(resolved, version) or {}
  local valid_by_name, any_by_name = {}, {}
  for _, m in ipairs(valid) do
    valid_by_name[m.name] = m
  end
  for _, m in ipairs(all) do
    any_by_name[m.name] = m
  end
  local bare_arg = resolved.directive and resolved.directive.bare_arg

  -- the modifier whose argument(s) may follow, and how many more it accepts
  local pending, remaining = nil, 0
  for i, seg in ipairs(segments) do
    if pending and remaining > 0 and M.match_arg(pending.arg, seg) then
      out[i] = { status = "arg", modifier = pending }
      remaining = remaining - 1
    elseif valid_by_name[seg] then
      local m = valid_by_name[seg]
      out[i] = { status = "modifier", modifier = m }
      pending, remaining = m.arg and m or nil, m.arg and (m.arg_max or 1) or 0
    elseif bare_arg and M.match_arg(bare_arg, seg) then
      out[i] = { status = "arg" }
      pending, remaining = nil, 0
    elseif any_by_name[seg] then
      out[i] = { status = "other_version", modifier = any_by_name[seg] }
      pending, remaining = nil, 0
    else
      local names = vim.tbl_keys(valid_by_name)
      table.sort(names)
      out[i] = { status = "unknown", suggestion = util.suggest(seg, names) }
      pending, remaining = nil, 0
    end
  end
  return out
end

---@class livewire.Segment
---@field text string
---@field start integer 0-based byte offset within the attribute name

---@class livewire.ParsedAttribute
---@field prefix "wire:"|"wire."
---@field name livewire.Segment
---@field sub? livewire.Segment
---@field modifiers livewire.Segment[]

--- Split a `wire:` attribute name into name, colon sub-name and modifier segments.
---@param attr string e.g. "wire:model.live.debounce.500ms"
---@return livewire.ParsedAttribute?
function M.parse(attr)
  local prefix = attr:sub(1, 5)
  if prefix ~= "wire:" and prefix ~= "wire." then
    return nil
  end
  local rest = attr:sub(6)
  local head_end = rest:find(".", 1, true)
  local head = head_end and rest:sub(1, head_end - 1) or rest
  local colon = head:find(":", 1, true)
  local parsed = {
    prefix = prefix,
    name = { text = colon and head:sub(1, colon - 1) or head, start = 5 },
    sub = colon and { text = head:sub(colon + 1), start = 5 + colon } or nil,
    modifiers = {},
  }
  if head_end then
    local pos = 5 + head_end -- 0-based offset of the first modifier
    for seg in vim.gsplit(rest:sub(head_end + 1), ".", { plain = true }) do
      parsed.modifiers[#parsed.modifiers + 1] = { text = seg, start = pos }
      pos = pos + #seg + 1
    end
  end
  return parsed
end

return M
