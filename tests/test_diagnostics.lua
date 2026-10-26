local H = require("helpers")
local config = require("livewire.config")
local diagnostics = require("livewire.diagnostics")
local project = require("livewire.project")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      H.skip_without_blade()
      config.set({})
      project.reset()
      vim.cmd("silent! %bwipeout!")
    end,
  },
})

local function open(path)
  vim.cmd.edit(vim.fn.fnameescape(H.fixtures .. "/" .. path))
  vim.bo.filetype = "blade"
  return vim.api.nvim_get_current_buf()
end

--- Diagnostics as { "row:col-end_col text", message } sorted by position.
local function scan(buf)
  diagnostics.refresh(buf)
  local out = {}
  for _, d in ipairs(vim.diagnostic.get(buf, { namespace = diagnostics.ns })) do
    eq({ d.severity, d.source }, { vim.diagnostic.severity.WARN, "livewire" })
    local line = vim.api.nvim_buf_get_lines(buf, d.lnum, d.lnum + 1, false)[1]
    out[#out + 1] = { line:sub(d.col + 1, d.end_col), d.message, d.lnum }
  end
  table.sort(out, function(a, b)
    return a[3] < b[3] or (a[3] == b[3] and a[1] < b[1])
  end)
  return vim.tbl_map(function(o)
    return { o[1], o[2] }
  end, out)
end

T["v4 fixture"] = function()
  eq(scan(open("v4/resources/views/diagnostics.blade.php")), {
    { "wire.model.fill", "Livewire ignores `wire.model.fill`. Did you mean `wire:model.fill`?" },
    { "modle", "Unknown Livewire directive `wire:modle`. Did you mean `wire:model`?" },
    { "lve", "Unknown modifier `.lve` for `wire:model`. Did you mean `.live`?" },
    { "defer", "`.defer` on `wire:model` is not supported in Livewire 4" },
    { "lodaing", "Unknown Livewire directive `wire:lodaing`. Did you mean `wire:loading`?" },
    { "itme", "Unknown `wire:sort` sub-name `:itme`. Did you mean `wire:sort:item`?" },
    {
      "frobnicate",
      "Unknown Livewire directive `wire:frobnicate`. If it is a custom directive or event, add it to `custom_directives`.",
    },
  })
end

T["v3 fixture"] = function()
  eq(scan(open("v3/resources/views/diagnostics.blade.php")), {
    { "ref", "`wire:ref` requires Livewire 4 (this project uses Livewire 3)" },
  })
end

T["custom_directives silences custom events"] = function()
  config.set({ custom_directives = { "frobnicate" } })
  local found = scan(open("v4/resources/views/diagnostics.blade.php"))
  eq(
    vim.tbl_filter(function(d)
      return d[1] == "frobnicate"
    end, found),
    {}
  )
end

T["members"] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      H.skip_without_php()
      require("livewire.components").reset()
      require("livewire.members").reset()
    end,
  },
})

T["members"]["problems fixture"] = function()
  eq(scan(open("app/resources/views/livewire/problems.blade.php")), {
    { "nmae", "Property `nmae` not found on `Problems`. Did you mean `name`?" },
    { "secret", "Property `secret` is protected on `Problems`, so `wire:model` can't set it; Livewire only binds public properties." },
    { "instances", "Property `instances` is static on `Problems`, so `wire:model` can't set it." },
    { "items", "Property `items` not found on `Problems`." },
    { "changeGreting", "Method `changeGreting` not found on `Problems`. Did you mean `changeGreeting`?" },
    { "mount", "`mount` is a lifecycle hook; Livewire won't call it from the browser." },
    { "render", "`render` can't be called from the browser; use `$refresh` to re-render." },
    { "guard", "Method `guard` is protected on `Problems`; Livewire can only call public methods." },
    { "make", "Method `make` is static on `Problems`; Livewire can only call public, non-static methods." },
    { "bootHasSearch", "`bootHasSearch` is a lifecycle hook; Livewire won't call it from the browser." },
    { "updatedName", "`updatedName` is a lifecycle hook; Livewire won't call it from the browser." },
    { "refreshStats", "Method `refreshStats` not found on `Problems`." },
  })
end

T["members"]["valid views are clean"] = function()
  for _, path in ipairs({
    "app/resources/views/livewire/greeter.blade.php",
    "app/resources/views/livewire/reports/monthly.blade.php",
    "app/resources/views/components/⚡counter/counter.blade.php",
  }) do
    eq({ path, scan(open(path)) }, { path, {} })
  end
end

T["members"]["single-file component"] = function()
  eq(scan(open("app/resources/views/pages/⚡profile.blade.php")), {
    { "sav", "Method `sav` not found on this component. Did you mean `save`?" },
  })
end

T["members"]["unresolvable base class or no owner stays silent"] = function()
  eq(scan(open("app/resources/views/livewire/broken.blade.php")), {})
  local buf = open("app/resources/views/components/app-logo.blade.php")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '<button wire:click="anything" wire:model="nope">' })
  eq(scan(buf), {})
end

T["members"]["multi-line value"] = function()
  local buf = open("app/resources/views/livewire/greeter.blade.php")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "<button wire:click=\"", "    savee", '">' })
  eq(scan(buf), { { "savee", "Method `savee` not found on `Greeter`." } })
end

T["members"]["typo in the directive name skips the member check"] = function()
  local buf = open("app/resources/views/livewire/greeter.blade.php")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '<input wire:modle="nope">' })
  eq(#scan(buf), 1)
end

T["members"]["method added to the class clears the warning"] = function()
  H.skip_without_blade()
  local root = vim.fs.normalize(vim.fn.tempname())
  vim.fn.system({ "cp", "-r", H.app, root })
  require("livewire").setup({})
  vim.cmd.edit(root .. "/resources/views/livewire/greeter.blade.php")
  vim.bo.filetype = "blade"
  local view = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(view, 0, -1, false, { '<button wire:click="archive">' })
  eq(scan(view), { { "archive", "Method `archive` not found on `Greeter`." } })

  vim.cmd.split(root .. "/app/Livewire/Greeter.php")
  local at = vim.fn.search("use HasSearch;")
  vim.api.nvim_buf_set_lines(0, at, at, false, { "    public function archive(): void {}" })
  vim.cmd.write()
  vim.wait(2000, function()
    return #vim.diagnostic.get(view, { namespace = diagnostics.ns }) == 0
  end)
  eq(vim.diagnostic.get(view, { namespace = diagnostics.ns }), {})

  -- a trait outside the class path: re-checked because the index read it
  vim.api.nvim_buf_set_lines(view, 0, -1, false, { '<button wire:click="purge">' })
  eq(scan(view), { { "purge", "Method `purge` not found on `Greeter`." } })
  vim.cmd.edit(root .. "/app/Concerns/HasSearch.php")
  local at = vim.fn.search("string $search")
  vim.api.nvim_buf_set_lines(0, at, at, false, { "    public function purge(): void {}" })
  vim.cmd.write()
  vim.wait(2000, function()
    return #vim.diagnostic.get(view, { namespace = diagnostics.ns }) == 0
  end)
  eq(vim.diagnostic.get(view, { namespace = diagnostics.ns }), {})
  vim.fn.delete(root, "rf")
end

T["check_attribute"] = MiniTest.new_set()

T["check_attribute"]["sub-name on a directive without sub-names"] = function()
  eq(diagnostics.check_attribute("wire:model:x", 4, {}), {
    { start = 11, finish = 12, message = "`wire:model` does not take a `:x` part." },
  })
end

T["check_attribute"]["version-only sub-name"] = function()
  eq(diagnostics.check_attribute("wire:navigate:scroll", 3, {})[1].message,
    "`wire:navigate:scroll` requires Livewire 4 (this project uses Livewire 3)")
end

T["check_attribute"]["bind takes any attribute"] = function()
  eq(diagnostics.check_attribute("wire:bind:data-count", 4, {}), {})
end

T["check_attribute"]["trailing dot and bare wire: are left alone"] = function()
  eq(diagnostics.check_attribute("wire:model.", 4, {}), {})
  eq(diagnostics.check_attribute("wire:", 4, {}), {})
end

T["check_attribute"]["unknown directives skip modifier checks"] = function()
  eq(#diagnostics.check_attribute("wire:modle.lve", 4, {}), 1)
end

T["refresh"] = MiniTest.new_set({
  hooks = {
    post_case = function()
      require("livewire").setup({ diagnostics = false })
    end,
  },
})

local function livewire_diags(buf)
  return vim.diagnostic.get(buf, { namespace = diagnostics.ns })
end

local function wait_for(fn)
  vim.wait(1000, fn, 10)
  return fn()
end

T["refresh"]["fix clears the warning on leaving insert mode"] = function()
  require("livewire").setup({})
  local buf = open("v4/resources/views/diagnostics.blade.php")
  eq(wait_for(function()
    return #livewire_diags(buf) == 7
  end), true)
  local row = vim.fn.search("wire:modle") - 1
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  vim.api.nvim_buf_set_lines(buf, row, row + 1, false, { (line:gsub("wire:modle", "wire:model")) })
  vim.api.nvim_exec_autocmds("InsertLeave", { buffer = buf })
  eq(wait_for(function()
    return #livewire_diags(buf) == 6
  end), true)
end

T["refresh"]["typing in insert mode does not scan"] = function()
  require("livewire").setup({})
  local buf = open("v4/resources/views/diagnostics.blade.php")
  wait_for(function()
    return #livewire_diags(buf) > 0
  end)
  vim.wait(2 * diagnostics.DEBOUNCE_MS)
  local before = diagnostics.scans
  -- what Neovim fires while typing in insert mode (TextChanged only fires outside it)
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "<input wire:modle>" })
  vim.api.nvim_exec_autocmds({ "TextChangedI", "TextChangedP", "CursorMovedI" }, { buffer = buf })
  vim.wait(3 * diagnostics.DEBOUNCE_MS)
  eq(diagnostics.scans, before)
  vim.api.nvim_exec_autocmds("InsertLeave", { buffer = buf })
  eq(wait_for(function()
    return diagnostics.scans == before + 1
  end), true)
end

T["refresh"]["disabled by config"] = function()
  require("livewire").setup({ diagnostics = false })
  local buf = open("v4/resources/views/diagnostics.blade.php")
  vim.wait(3 * diagnostics.DEBOUNCE_MS)
  eq(livewire_diags(buf), {})
end

T["refresh"]["setup() attaches to Blade buffers that are already open"] = function()
  local buf = open("v4/resources/views/diagnostics.blade.php")
  require("livewire").setup({})
  eq(wait_for(function()
    return #livewire_diags(buf) == 7
  end), true)
end

T["refresh"]["a new custom directive clears its warning"] = function()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir .. "/resources/js", "p")
  vim.fn.writefile({ "{}" }, dir .. "/composer.lock")
  vim.fn.writefile({ "<div wire:flash></div>" }, dir .. "/page.blade.php")
  require("livewire").setup({})
  vim.cmd.edit(vim.fn.fnameescape(dir .. "/page.blade.php"))
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].filetype = "blade"
  eq(wait_for(function()
    return #livewire_diags(buf) == 1
  end), true)

  vim.cmd("split " .. vim.fn.fnameescape(dir .. "/resources/js/app.js"))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Livewire.directive('flash', () => {})" })
  vim.cmd("silent write")
  eq(wait_for(function()
    return #livewire_diags(buf) == 0
  end), true)
end

local P = MiniTest.new_set({
  hooks = {
    pre_case = function()
      config.set({})
      project.reset()
      vim.cmd("silent! %bwipeout!")
    end,
  },
})
T["parser missing"] = P

P["no error and no diagnostics"] = function()
  local saved = vim.treesitter.get_parser
  vim.treesitter.get_parser = function(_, _, opts)
    if opts and opts.error == false then
      return nil
    end
    error("no parser for blade")
  end
  local ok, err = pcall(function()
    require("livewire").setup({})
    local buf = open("v4/resources/views/diagnostics.blade.php")
    vim.wait(3 * diagnostics.DEBOUNCE_MS)
    eq(livewire_diags(buf), {})
    eq(vim.v.errmsg, "")
  end)
  vim.treesitter.get_parser = saved
  require("livewire").setup({ diagnostics = false })
  assert(ok, err)
end

return T
