local H = require("helpers")
local config = require("livewire.config")
local project = require("livewire.project")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      config.set({})
      project.reset()
    end,
  },
})

local function edit(path)
  vim.cmd("silent! %bwipeout!")
  vim.cmd.edit(vim.fn.fnameescape(path))
  return vim.api.nvim_get_current_buf()
end

T["parse_major"] = function()
  eq(project.parse_major("v4.4.8"), 4)
  eq(project.parse_major("3.6.4"), 3)
  eq(project.parse_major("4.x-dev"), 4)
  eq(project.parse_major("v4"), 4)
  eq(project.parse_major("dev-main"), nil)
end

T["version from composer.lock packages"] = function()
  local buf = edit(H.fixtures .. "/v4/resources/views/welcome.blade.php")
  eq({ project.version(buf) }, { 4, "composer.lock" })
end

T["version from composer.lock packages-dev"] = function()
  local buf = edit(H.fixtures .. "/v3/resources/views/welcome.blade.php")
  eq({ project.version(buf) }, { 3, "composer.lock" })
end

T["config override wins"] = function()
  config.set({ livewire_version = 3 })
  local buf = edit(H.fixtures .. "/v4/resources/views/welcome.blade.php")
  eq({ project.version(buf) }, { 3, "override" })
end

T["no lock file defaults to 4"] = function()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local buf = edit(dir .. "/page.blade.php")
  eq({ project.version(buf) }, { 4, "default" })
end

T["lock file is re-read when it changes"] = function()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local lock = dir .. "/composer.lock"
  local function write(version)
    vim.fn.writefile({ vim.json.encode({ packages = { { name = "livewire/livewire", version = version } } }) }, lock)
  end
  write("v3.5.0")
  local buf = edit(dir .. "/page.blade.php")
  eq(project.version(buf), 3)
  vim.uv.sleep(20) -- make sure the mtime moves
  write("v4.0.0")
  eq(project.version(buf), 4)
end

T["custom directives from project JS"] = function()
  local buf = edit(H.fixtures .. "/v4/resources/views/welcome.blade.php")
  eq(project.custom_directives(buf), { tooltip = true, chart = true })
end

T["custom directives from config are added"] = function()
  config.set({ custom_directives = { "sortable-list" } })
  local buf = edit(H.fixtures .. "/v4/resources/views/welcome.blade.php")
  eq(project.custom_directives(buf), { tooltip = true, chart = true, ["sortable-list"] = true })
end

T["custom directives without a project"] = function()
  config.set({ custom_directives = { "x" } })
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  eq(project.custom_directives(edit(dir .. "/a.blade.php")), { x = true })
end

T["scan_paths is configurable"] = function()
  config.set({ scan_paths = { "resources/js/*.js" } })
  local buf = edit(H.fixtures .. "/v4/resources/views/welcome.blade.php")
  eq(project.custom_directives(buf), { tooltip = true })
end

T["writing a scanned file re-scans and announces the change"] = function()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir .. "/resources/js", "p")
  vim.fn.writefile({ "{}" }, dir .. "/composer.lock")
  require("livewire").setup({})
  local blade = edit(dir .. "/page.blade.php")
  eq(project.custom_directives(blade), {})

  local events = {}
  vim.api.nvim_create_autocmd("User", {
    pattern = "LivewireProjectChanged",
    callback = function(ev)
      events[#events + 1] = ev.data.root
    end,
  })
  vim.cmd.edit(vim.fn.fnameescape(dir .. "/resources/js/app.js"))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Livewire.directive('flash', () => {})" })
  vim.cmd("silent write")
  eq(project.custom_directives(blade), { flash = true })
  eq(events, { vim.fs.normalize(dir) })

  -- writing again without changing the set announces nothing
  vim.cmd("silent write")
  eq(#events, 1)
end

return T
