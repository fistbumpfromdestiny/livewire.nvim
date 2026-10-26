local H = require("helpers")
local config = require("livewire.config")
local project = require("livewire.project")
local source = require("livewire.blink")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      H.skip_without_blade()
      config.set({})
      project.reset()
    end,
  },
})

--- Scratch buffer named inside a fixture project, cursor at `|`.
---@return integer buf, integer row, integer col
local function buffer(lines, opts)
  opts = opts or {}
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(buf, ("%s/%s/resources/views/test-%d.blade.php"):format(H.fixtures, opts.project or "v4", buf))
  local row, col
  for i, l in ipairs(lines) do
    local c = l:find("|", 1, true)
    if c then
      row, col = i - 1, c - 1
      lines[i] = l:sub(1, c - 1) .. l:sub(c + 1)
    end
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = opts.filetype or "blade"
  return buf, row, col
end

local function labels(lines, opts)
  local items = source.items(buffer(lines, opts))
  local out = vim.tbl_map(function(i)
    return i.label
  end, items)
  table.sort(out)
  return out
end

local function has(list, wanted, expected)
  for _, w in ipairs(wanted) do
    eq({ w, vim.tbl_contains(list, w) }, { w, expected })
  end
end

T["non-blade buffers get nothing"] = function()
  eq(labels({ "<input wire:|" }, { filetype = "html" }), {})
  eq(labels({ "<input wire:|" }, { filetype = "php" }), {})
end

T["directive names"] = function()
  local l = labels({ "<input wire:|" })
  has(l, { "model", "click", "loading", "show", "navigate", "submit", "keydown", "tooltip", "chart" }, true)
  has(l, { "id", "snapshot", "effects", "name", "scroll" }, false)
end

T["directive names follow the version"] = function()
  local l = labels({ "<div wire:|" }, { project = "v3" })
  has(l, { "model", "show", "text", "scroll" }, true)
  has(l, { "ref", "island", "bind", "sort", "intersect" }, false)
end

T["accepting replaces only the partial name"] = function()
  local buf, row, col = buffer({ "<input wire:mo|" })
  local model = vim.iter(source.items(buf, row, col)):find(function(i)
    return i.label == "model"
  end)
  vim.lsp.util.apply_text_edits({ model.textEdit }, buf, "utf-16")
  eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "<input wire:model" })
end

T["component and multi-line tags"] = function()
  has(labels({ "<x-input", "    wire:|", "/>" }), { "model" }, true)
  has(labels({ "<livewire:counter", "    wire:|" }), { "model" }, true)
end

T["nothing outside attribute names"] = function()
  eq(labels({ "<p>Use wire:| here</p>" }), {})
  eq(labels({ '<input value="wire:|">' }), {})
  eq(labels({ "{{ 'x' . wire:| }}" }), {})
end

T["sort sub-names"] = function()
  has(labels({ "<li wire:sort:|" }), { "item", "group", "ignore" }, true)
end

T["wire:model modifiers"] = function()
  local l = labels({ "<input wire:model.|" })
  has(l, { "live", "blur", "change", "enter", "fill", "number", "boolean", "debounce" }, true)
  has(l, { "defer" }, false)
  has(labels({ "<input wire:model.|" }, { project = "v3" }), { "defer" }, true)
end

T["already-used modifiers are left out"] = function()
  local l = labels({ "<input wire:model.live.|" })
  has(l, { "live" }, false)
  has(l, { "blur" }, true)
end

T["event modifiers"] = function()
  local l = labels({ "<button wire:click.|" })
  has(l, {
    "prevent", "stop", "self", "once", "outside", "window", "document",
    "debounce", "throttle", "async", "renderless", "preserve-scroll",
  }, true)
end

T["argument values"] = function()
  eq(labels({ "<input wire:model.live.debounce.|" }), { "1000ms", "250ms", "500ms" })
  has(labels({ "<div wire:loading.delay.|" }), { "short", "longest" }, true)
  has(labels({ "<div wire:poll.|" }), { "keep-alive", "5s" }, true)
  eq(labels({ "<input wire:keydown.debounce.|" }), { "1000ms", "250ms", "500ms" })
end

T["keyboard events offer keys"] = function()
  has(labels({ "<input wire:keydown.|" }), { "enter", "escape", "space", "tab", "up", "arrow-down", "prevent", "shift" }, true)
end

T["custom directives get no modifiers"] = function()
  eq(labels({ "<div wire:tooltip.|" }), {})
end

T["documentation"] = function()
  local buf, row, col = buffer({ "<input wire:|" })
  local items = source.items(buf, row, col)
  local function find(label)
    return vim.iter(items):find(function(i)
      return i.label == label
    end)
  end
  local model = find("model")
  eq(model.documentation.kind, "markdown")
  eq(model.documentation.value:find("Bind an input", 1, true) ~= nil, true)
  eq(model.documentation.value:find("https://livewire.laravel.com/docs/4.x/wire-model", 1, true) ~= nil, true)
  eq(find("tooltip").documentation.value:find("Custom directive", 1, true) ~= nil, true)
end

T["get_completions calls back with the blink response shape"] = function()
  local buf, row, col = buffer({ "<input wire:|" })
  local s = source.new({})
  eq(s:get_trigger_characters(), { ":", "." })
  local response
  s:get_completions({ bufnr = buf, cursor = { row + 1, col } }, function(r)
    response = r
  end)
  eq(response.is_incomplete_forward, false)
  eq(#response.items > 10, true)
end

return T
