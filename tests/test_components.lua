local H = require("helpers")
local components = require("livewire.components")
local config = require("livewire.config")
local project = require("livewire.project")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      config.set({})
      project.reset()
      components.reset()
      vim.cmd("silent! %bwipeout!")
    end,
  },
})

--- A throwaway project: { [relative path] = contents }.
local function tmp_project(files)
  local root = vim.fs.normalize(vim.fn.tempname())
  files["composer.json"] = files["composer.json"] or "{}"
  for rel, text in pairs(files) do
    vim.fn.mkdir(vim.fs.dirname(root .. "/" .. rel), "p")
    vim.fn.writefile(vim.split(text, "\n"), root .. "/" .. rel)
  end
  return root
end

local function rel(path)
  return path and path:sub(#H.app + 2)
end

T["config"] = MiniTest.new_set()

T["config"]["read from config/livewire.php"] = function()
  local cfg = components.config(H.app)
  eq(cfg.class_path, "app/Livewire")
  eq(cfg.locations, { "resources/views/components", "resources/views/livewire" })
  eq(cfg.namespaces, { layouts = "resources/views/layouts", pages = "resources/views/pages" })
end

T["config"]["defaults without a published config"] = function()
  eq(components.config(tmp_project({})), components.defaults)
end

T["config"]["published class path is tried first"] = function()
  local root = tmp_project({
    ["config/livewire.php"] = "<?php return [ 'class_path' => app_path('Http/Livewire') ];",
    ["app/Http/Livewire/Greeter.php"] = "<?php",
    ["resources/views/livewire/greeter.blade.php"] = "<div></div>",
  })
  eq(components.resolve("livewire", "greeter", root), root .. "/app/Http/Livewire/Greeter.php")
end

T["psr4"] = MiniTest.new_set()

T["psr4"]["from vendor/composer/autoload_psr4.php"] = function()
  eq(components.psr4(H.app)["App\\"], { "app" })
  eq(components.psr4(H.app)["Livewire\\"], { "vendor/livewire/livewire/src" })
  eq(rel(components.class_to_file("App\\Livewire\\Forms\\PostForm", H.app)), "app/Livewire/Forms/PostForm.php")
  eq(components.class_to_file("Acme\\Missing\\Base", H.app), nil)
end

T["psr4"]["falls back to composer.json"] = function()
  local root = tmp_project({
    ["composer.json"] = [[{ "autoload": { "psr-4": { "App\\": "app/" } }, "autoload-dev": { "psr-4": { "Tests\\": ["tests/"] } } }]],
    ["app/Concerns/HasSearch.php"] = "<?php",
  })
  eq(components.psr4(root), { ["App\\"] = { "app" }, ["Tests\\"] = { "tests" } })
  eq(components.class_to_file("App\\Concerns\\HasSearch", root), root .. "/app/Concerns/HasSearch.php")
end

T["tags"] = MiniTest.new_set()

T["tags"]["tag under the cursor"] = function()
  local line = [[<livewire:greeter /> @livewire('pages::profile') <flux:navlist.group> <x-card>]]
  eq({ components.tag_at(line, 0) }, { "livewire", "greeter" })
  eq({ components.tag_at(line, 12) }, { "livewire", "greeter" })
  eq({ components.tag_at(line, 18) }, {})
  eq({ components.tag_at(line, line:find("profile")) }, { "livewire", "pages::profile" })
  eq({ components.tag_at(line, line:find("group")) }, { "flux", "navlist.group" })
  eq({ components.tag_at(line, #line - 3) }, { "blade", "card" })
end

T["tags"]["livewire components"] = function()
  eq(rel(components.resolve("livewire", "greeter", H.app)), "app/Livewire/Greeter.php")
  eq(rel(components.resolve("livewire", "reports.summary", H.app)), "app/Livewire/Reports/Summary.php")
  eq(rel(components.resolve("livewire", "pages::profile", H.app)), "resources/views/pages/⚡profile.blade.php")
  eq(rel(components.resolve("livewire", "counter", H.app)), "resources/views/components/⚡counter/counter.php")
  eq(components.resolve("livewire", "missing", H.app), nil)
end

T["tags"]["nested name to class"] = function()
  local root = tmp_project({ ["app/Livewire/Admin/UserTable.php"] = "<?php" })
  eq(components.resolve("livewire", "admin.user-table", root), root .. "/app/Livewire/Admin/UserTable.php")
end

T["tags"]["flux override wins over vendor"] = function()
  eq(rel(components.resolve("flux", "navlist.group", H.app)), "resources/views/flux/navlist/group.blade.php")
  eq(
    rel(components.resolve("flux", "button", H.app)),
    "vendor/livewire/flux/stubs/resources/views/flux/button.blade.php"
  )
end

T["tags"]["blade components"] = function()
  eq(rel(components.resolve("blade", "app-logo", H.app)), "resources/views/components/app-logo.blade.php")
  eq(rel(components.resolve("blade", "card", H.app)), "resources/views/components/card/index.blade.php")
  eq(rel(components.resolve("blade", "alert", H.app)), "app/View/Components/Alert.php")
  eq(rel(components.resolve("blade", "layouts::app", H.app)), "resources/views/layouts/app.blade.php")
  eq(components.resolve("blade", "slot:title", H.app), nil)
  eq(components.resolve("blade", "slot", H.app), nil)
  eq(components.resolve("blade", "dynamic-component", H.app), nil)
end

T["tags"]["blade components switched off"] = function()
  config.set({ definition = { blade_components = false } })
  eq(components.resolve("blade", "app-logo", H.app), nil)
  eq(rel(components.resolve("livewire", "greeter", H.app)), "app/Livewire/Greeter.php")
end

T["owner"] = MiniTest.new_set()

local function owner_of(path)
  vim.cmd.edit(vim.fn.fnameescape(H.app .. "/" .. path))
  return rel((components.owner(vim.api.nvim_get_current_buf())))
end

T["owner"]["class component by convention"] = function()
  eq(owner_of("resources/views/livewire/greeter.blade.php"), "app/Livewire/Greeter.php")
end

T["owner"]["class component by view reference"] = function()
  eq(owner_of("resources/views/livewire/reports/monthly.blade.php"), "app/Livewire/Reports/Summary.php")
end

T["owner"]["single-file component owns itself"] = function()
  eq(owner_of("resources/views/pages/⚡profile.blade.php"), "resources/views/pages/⚡profile.blade.php")
end

T["owner"]["multi-file component"] = function()
  eq(owner_of("resources/views/components/⚡counter/counter.blade.php"), "resources/views/components/⚡counter/counter.php")
end

T["owner"]["plain Blade view has none"] = function()
  eq(owner_of("resources/views/components/app-logo.blade.php"), nil)
end

T["owner"]["search results are forgotten when a class is written"] = function()
  local root = tmp_project({
    ["app/Livewire/Stats.php"] = "<?php class Stats { function render() { return view('livewire.panel'); } }",
    ["resources/views/livewire/panel.blade.php"] = "<div></div>",
  })
  vim.cmd.edit(root .. "/resources/views/livewire/panel.blade.php")
  local buf = vim.api.nvim_get_current_buf()
  eq(components.owner(buf), root .. "/app/Livewire/Stats.php")
  vim.fn.writefile({ "<?php class Stats { function render() { return view('livewire.other'); } }" }, root .. "/app/Livewire/Stats.php")
  vim.fn.writefile({ "<?php class Panel { function render() { return view('livewire.panel'); } }" }, root .. "/app/Livewire/Panel2.php")
  -- still cached until a class-path write is reported
  eq(components.owner(buf), root .. "/app/Livewire/Stats.php")
  eq(components.on_write(root, "resources/views/livewire/panel.blade.php"), false)
  eq(components.on_write(root, "app/Models/User.php"), false)
  local fired = 0
  vim.api.nvim_create_autocmd("User", {
    pattern = "LivewireProjectChanged",
    once = true,
    callback = function(ev)
      fired = ev.data.root == root and 1 or -1
    end,
  })
  project.on_write(root .. "/app/Livewire/Stats.php")
  eq(fired, 1)
  eq(components.owner(buf), root .. "/app/Livewire/Panel2.php")
end

return T
