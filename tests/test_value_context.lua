local H = require("helpers")
local value_context = require("livewire.value_context")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      vim.cmd("silent! %bwipeout!")
    end,
  },
})

--- Context at `|` in a scratch Blade buffer.
local function at(lines)
  local buf = vim.api.nvim_create_buf(true, true)
  local row, col
  for i, l in ipairs(lines) do
    local c = l:find("|", 1, true)
    if c then
      row, col = i - 1, c - 1
      lines[i] = l:sub(1, c - 1) .. l:sub(c + 1)
    end
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "blade"
  return value_context.at(buf, row, col)
end

local function typing(lines, kind)
  local ctx = at(lines)
  return ctx and value_context.typing(ctx, kind)
end

-- runs on the tree when the blade parser is installed, on the line fallback otherwise
T["values"] = MiniTest.new_set()

T["values"]["wire:model with modifiers and a Form path"] = function()
  local ctx = at({ '<input wire:model.live="form.|">' })
  eq({ ctx.kind, ctx.directive, ctx.value, ctx.offset }, { "value", "model", "form.", 5 })
  eq(value_context.typing(ctx, "property"), { want = "form_property", partial = "", form = "form" })
end

T["values"]["action name, magic and $toggle argument"] = function()
  eq(typing({ '<button wire:click="sa|">' }, "action"), { want = "action", partial = "sa" })
  eq(typing({ '<button wire:click="$re|">' }, "action"), { want = "action", partial = "$re" })
  eq(typing({ '<button wire:click="save(|)">' }, "action"), nil)
end

T["values"]["second wire:target entry"] = function()
  eq(typing({ '<span wire:target="save, |">' }, "targets"), { want = "member", partial = "" })
  eq(typing({ '<span wire:target="sa|">' }, "targets"), { want = "member", partial = "sa" })
end

T["line fallback"] = function()
  local line = [[<input wire:model.live="form.ti" x-data>]]
  eq(
    value_context.from_line(line, #"<input wire:model.live=\"form.t"),
    { kind = "value", directive = "model", value = "form.ti", offset = 6 }
  )
  -- unclosed quote while typing
  eq(value_context.from_line([[<input wire:model="na]], 21).value, "na")
  eq(value_context.from_line([[<button wire:click='sa]], 22).value, "sa")
  eq(value_context.from_line([[<input class="a]], 15), nil)
  eq(value_context.from_line([[<input xwire:model="a]], 21), nil)
end

T["$toggle argument in the tree"] = function()
  H.skip_without_blade()
  eq(typing({ "<button wire:click=\"$toggle('op|')\">" }, "action"), { want = "argument_property", partial = "op" })
end

T["tree"] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      H.skip_without_blade()
    end,
  },
})

T["tree"]["multi-line tag, colon sub-name"] = function()
  local ctx = at({ "<ul", '  wire:sort:item="|"', ">" })
  eq({ ctx.directive, ctx.sub, ctx.value, ctx.offset }, { "sort", "item", "", 0 })
end

T["tree"]["empty value"] = function()
  local ctx = at({ '<input wire:model="|">' })
  eq({ ctx.value, ctx.offset }, { "", 0 })
  eq(value_context.typing(ctx, "property"), { want = "property", partial = "" })
end

T["tree"]["outside the quotes or in another attribute"] = function()
  eq(at({ '<input wire:model="x"| class="a">' }), nil)
  eq(at({ '<input wire:model="x" class="|a">' }), nil)
  eq(at({ '<input class="a" |>' }), nil)
end

T["$wire"] = function()
  eq(at({ '<div x-on:click="$wire.|">' }), { kind = "wire", partial = "", start_col = 23 })
  eq(at({ "<script>$wire.sa|</script>" }), { kind = "wire", partial = "sa", start_col = 14 })
  eq(at({ "<script>$wire.$re|</script>" }), { kind = "wire", partial = "$re", start_col = 14 })
end

T["expression identifiers"] = function()
  H.skip_without_blade()
  eq(typing({ '<div wire:show="op|">' }, "expression"), { want = "member", partial = "op" })
  eq(typing({ '<div wire:show="! |">' }, "expression"), { want = "member", partial = "" })
  eq(typing({ '<div wire:show="form.ti|">' }, "expression"), nil)
end

return T
