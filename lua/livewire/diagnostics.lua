-- Warnings for `wire.` typos, unknown directives, sub-names and modifiers in Blade buffers.
local catalog = require("livewire.catalog")
local config = require("livewire.config")
local project = require("livewire.project")
local util = require("livewire.util")

local M = {}

M.ns = vim.api.nvim_create_namespace("livewire")
M.DEBOUNCE_MS = 150

local query ---@type vim.treesitter.Query?

local function attribute_names()
  query = query or vim.treesitter.query.parse("blade", "(attribute_name) @name")
  return query
end

--- "requires Livewire 4" for newer features, "is not supported in Livewire 4" for removed ones.
---@param subject string
---@param versions integer[] versions the feature exists in
---@param version integer the project's version
local function version_message(subject, versions, version)
  if math.max(unpack(versions)) < version then
    return ("%s is not supported in Livewire %d"):format(subject, version)
  end
  return ("%s requires Livewire %s (this project uses Livewire %d)"):format(subject, table.concat(versions, " or "), version)
end

--- Problems in one attribute name. Offsets are 0-based byte ranges within `attr`.
---@param attr string
---@param version integer
---@param custom table<string, true>
---@return { start: integer, finish: integer, message: string }[]
function M.check_attribute(attr, version, custom)
  local parsed = catalog.parse(attr)
  if not parsed or parsed.name.text == "" then
    return {}
  end
  if parsed.prefix == "wire." then
    local fixed = "wire:" .. attr:sub(6)
    return {
      { start = 0, finish = #attr, message = ("Livewire ignores `%s`. Did you mean `%s`?"):format(attr, fixed) },
    }
  end

  local problems = {}
  local function add(seg, message)
    problems[#problems + 1] = { start = seg.start, finish = seg.start + #seg.text, message = message }
  end

  local name = parsed.name.text
  local resolved = catalog.resolve(name, version, custom)
  if resolved.kind == "internal" or resolved.kind == "custom" then
    return {}
  elseif resolved.kind == "other_version" then
    add(parsed.name, version_message(("`wire:%s`"):format(name), resolved.directive.versions, version))
    return problems
  elseif resolved.kind == "unknown" then
    local message = ("Unknown Livewire directive `wire:%s`."):format(name)
    if resolved.suggestion then
      message = message .. (" Did you mean `wire:%s`?"):format(resolved.suggestion)
    else
      message = message .. " If it is a custom directive or event, add it to `custom_directives`."
    end
    add(parsed.name, message)
    return problems
  end

  if parsed.sub then
    local sub = parsed.sub.text
    local subs = catalog.subnames(resolved, version)
    if subs == nil then
      add(parsed.sub, ("`wire:%s` does not take a `:%s` part."):format(name, sub))
    elseif subs ~= "any" then
      local names = vim.tbl_map(function(s)
        return s.name
      end, subs)
      if not vim.tbl_contains(names, sub) then
        local any = vim.iter(resolved.directive.subnames):find(function(s)
          return s.name == sub
        end)
        if any then
          add(parsed.sub, version_message(("`wire:%s:%s`"):format(name, sub), any.versions, version))
        else
          local suggestion = util.suggest(sub, names)
          add(
            parsed.sub,
            ("Unknown `wire:%s` sub-name `:%s`."):format(name, sub)
              .. (suggestion and (" Did you mean `wire:%s:%s`?"):format(name, suggestion) or "")
          )
        end
      end
    end
  end

  local segments = vim.tbl_map(function(s)
    return s.text
  end, parsed.modifiers)
  for i, status in ipairs(catalog.check_modifiers(resolved, version, segments)) do
    local seg = parsed.modifiers[i]
    if seg.text ~= "" then
      if status.status == "other_version" then
        add(seg, version_message(("`.%s` on `wire:%s`"):format(seg.text, name), status.modifier.versions, version))
      elseif status.status == "unknown" then
        add(
          seg,
          ("Unknown modifier `.%s` for `wire:%s`."):format(seg.text, name)
            .. (status.suggestion and (" Did you mean `.%s`?"):format(status.suggestion) or "")
        )
      end
    end
  end
  return problems
end

--- Compute and set diagnostics for a buffer. Never raises.
---@param buf integer
function M.refresh(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  M.scans = (M.scans or 0) + 1
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "blade", { error = false })
  if not ok or not parser then
    vim.diagnostic.reset(M.ns, buf)
    return
  end
  local version = project.version(buf)
  local custom = project.custom_directives(buf)
  local tree = parser:parse()[1]
  local diagnostics = {}
  for _, node in attribute_names():iter_captures(tree:root(), buf) do
    local text = vim.treesitter.get_node_text(node, buf)
    if text:sub(1, 5) == "wire:" or text:sub(1, 5) == "wire." then
      local row, col = node:start()
      for _, problem in ipairs(M.check_attribute(text, version, custom)) do
        diagnostics[#diagnostics + 1] = {
          lnum = row,
          col = col + problem.start,
          end_lnum = row,
          end_col = col + problem.finish,
          severity = vim.diagnostic.severity.WARN,
          source = "livewire",
          message = problem.message,
        }
      end
    end
  end
  vim.diagnostic.set(M.ns, buf, diagnostics)
end

---@type table<integer, uv.uv_timer_t>
local timers = {}

--- Refresh after a short pause, so bursts of edits cost one scan.
---@param buf integer
function M.schedule(buf)
  local timer = timers[buf]
  if not timer then
    timer = assert(vim.uv.new_timer())
    timers[buf] = timer
  end
  timer:stop()
  timer:start(M.DEBOUNCE_MS, 0, vim.schedule_wrap(function()
    M.refresh(buf)
  end))
end

local function detach(buf)
  if timers[buf] then
    timers[buf]:stop()
    timers[buf]:close()
    timers[buf] = nil
  end
end

--- Start checking a Blade buffer: now, and again after edits and writes.
---@param buf integer
function M.attach(buf)
  if not config.options.diagnostics or vim.b[buf].livewire_diagnostics then
    return
  end
  vim.b[buf].livewire_diagnostics = true
  local group = vim.api.nvim_create_augroup("livewire_diagnostics_" .. buf, { clear = true })
  -- TextChanged only fires outside insert mode, so typing never triggers a scan
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave", "TextChanged" }, {
    group = group,
    buffer = buf,
    callback = function()
      M.schedule(buf)
    end,
  })
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
    group = group,
    buffer = buf,
    callback = function()
      detach(buf)
      vim.b[buf].livewire_diagnostics = nil
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })
  M.schedule(buf)
end

--- Re-check open Blade buffers of a project whose version or custom directives changed.
---@param root string
function M.project_changed(root)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.b[buf].livewire_diagnostics and project.root(buf) == root then
      M.schedule(buf)
    end
  end
end

--- Stop checking every buffer and clear what was reported.
function M.disable()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.b[buf].livewire_diagnostics then
      detach(buf)
      vim.b[buf].livewire_diagnostics = nil
      pcall(vim.api.nvim_del_augroup_by_name, "livewire_diagnostics_" .. buf)
    end
  end
  vim.diagnostic.reset(M.ns)
end

return M
