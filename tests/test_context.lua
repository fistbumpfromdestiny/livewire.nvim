local H = require("helpers")
local context = require("livewire.context")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

--- Context at the `|` marker of a one-line string.
local function token(text)
  local col = text:find("|", 1, true) - 1
  return context.parse_token(text:gsub("|", "", 1), col)
end

T["parse_token"] = MiniTest.new_set()

T["parse_token"]["directive name"] = function()
  eq(token("<input wire:|"), { kind = "directive", partial = "", modifiers = {}, start_col = 12, token_col = 7 })
  eq(token("<input wire:mo|").partial, "mo")
  eq(token("<input wire:mo|").start_col, 12)
end

T["parse_token"]["sub-name"] = function()
  local ctx = token("<li wire:sort:|")
  eq({ ctx.kind, ctx.name, ctx.partial }, { "subname", "sort", "" })
  eq(token("<li wire:sort:gr|").partial, "gr")
end

T["parse_token"]["modifiers"] = function()
  local ctx = token("<input wire:model.live.|")
  eq({ ctx.kind, ctx.name, ctx.modifiers, ctx.partial }, { "modifier", "model", { "live" }, "" })
  ctx = token("<input wire:model.live.debounce.|")
  eq(ctx.modifiers, { "live", "debounce" })
  ctx = token("<input wire:keydown.|")
  eq({ ctx.name, ctx.modifiers, ctx.partial, ctx.start_col }, { "keydown", {}, "", 20 })
  ctx = token("<div wire:intersect:leave.ha|")
  eq({ ctx.name, ctx.sub, ctx.partial }, { "intersect", "leave", "ha" })
end

T["parse_token"]["not a wire attribute"] = function()
  eq(token("<input x-wire:|"), nil)
  eq(token("$wire:|"), nil)
  eq(token("<livewire:|"), nil)
  eq(token('<input value="wire:|'), nil)
  eq(token("<input wire|"), nil)
  eq(token("<input wire:.|"), nil)
end

T["parse_token"]["only text before the cursor counts"] = function()
  eq(token("<input wire:mo|del").partial, "mo")
end

T["at"] = MiniTest.new_set()

--- Buffer from lines with one `|` marking the cursor; returns context.at for it.
local function at(lines, opts)
  local buf = vim.api.nvim_create_buf(false, true)
  local row, col
  for i, l in ipairs(lines) do
    local c = l:find("|", 1, true)
    if c then
      row, col = i - 1, c - 1
      lines[i] = l:sub(1, c - 1) .. l:sub(c + 1)
    end
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if not (opts and opts.no_parser) then
    vim.bo[buf].filetype = "blade"
  end
  return context.at(buf, row, col)
end

T["at"]["attribute names, including component and multi-line tags"] = function()
  H.skip_without_blade()
  eq(at({ "<div>", "  <input type=\"text\" wire:|", "</div>" }).kind, "directive")
  eq(at({ "<x-input", "    wire:|", "/>" }).kind, "directive")
  eq(at({ "<livewire:counter wire:model.| />" }).kind, "modifier")
  eq(at({ "@if($a) <span wire:loa| @endif" }).partial, "loa")
end

T["at"]["not in text, values, echoes or comments"] = function()
  H.skip_without_blade()
  eq(at({ "<p>Use wire:| to bind</p>" }), nil)
  eq(at({ '<input value="a wire:|">' }), nil)
  eq(at({ '<div x-on:click="foo; wire:|">' }), nil)
  eq(at({ "{{ 'a' . wire:| }}" }), nil)
  eq(at({ "{{-- a wire:| --}}" }), nil)
end

T["at"]["line fallback without a parser"] = function()
  local saved = vim.treesitter.get_parser
  vim.treesitter.get_parser = function()
    error("no parser")
  end
  local ok, err = pcall(function()
    eq(at({ "<input type=\"text\" wire:mo|" }, { no_parser = true }).partial, "mo")
    eq(at({ "<p>text</p> wire:|" }, { no_parser = true }), nil)
    eq(at({ '<input value="x wire:|' }, { no_parser = true }), nil)
    -- multi-line tags are not detected without a parser
    eq(at({ "<x-input", "    wire:|" }, { no_parser = true }), nil)
  end)
  vim.treesitter.get_parser = saved
  assert(ok, err)
end

return T
