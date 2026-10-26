local H = require("helpers")
local components = require("livewire.components")
local config = require("livewire.config")
local members = require("livewire.members")
local project = require("livewire.project")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      H.skip_without_php()
      config.set({})
      project.reset()
      components.reset()
      members.reset()
      vim.cmd("silent! %bwipeout!")
    end,
  },
})

local function names(list)
  local out = vim.tbl_map(function(m)
    return m.name
  end, list)
  table.sort(out)
  return out
end

local function greeter()
  return members.index(H.app .. "/app/Livewire/Greeter.php", H.app)
end

T["parse"] = MiniTest.new_set()

T["parse"]["class members with visibility, static and positions"] = function()
  local class = members.file(H.app .. "/app/Livewire/Greeter.php")
  eq(class.name, "Greeter")
  eq(class.parent, "App\\Livewire\\BaseTable")
  eq(class.traits, { "App\\Concerns\\HasSearch" })
  local by = {}
  for _, m in ipairs(class.members) do
    by[m.name] = m
  end
  eq(names(class.members), {
    "changeGreeting", "form", "greeting", "greetingMessage", "guard", "instances", "make", "mount",
    "name", "open", "render", "secret", "updatedName",
  })
  eq(by.oldGreeting, nil)
  eq(by.commented, nil)
  eq({ by.name.kind, by.name.visibility, by.name.static, by.name.detail }, { "property", "public", false, "public string $name" })
  eq(by.greetingMessage.detail, "public string $greetingMessage")
  eq({ by.secret.visibility, by.instances.static, by.make.static }, { "protected", true, true })
  eq(by.form.type, "App\\Livewire\\Forms\\PostForm")
  eq(by.open.type, "bool")
  eq(by.changeGreeting.detail, "public function changeGreeting(string $prefix = 'Hello'): void")
  -- `public string $name` is on line 15 (0-based 14), name after the `$`
  local line = vim.fn.readfile(H.app .. "/app/Livewire/Greeter.php")[by.name.row + 1]
  eq(line:sub(by.name.col + 1, by.name.col + 4), "name")
  line = vim.fn.readfile(H.app .. "/app/Livewire/Greeter.php")[by.changeGreeting.row + 1]
  eq(line:sub(by.changeGreeting.col + 1, by.changeGreeting.col + 14), "changeGreeting")
end

T["parse"]["anonymous class, aliases and promoted properties"] = function()
  local class = members.parse(
    [[<?php
use Livewire\Component as Base;
new #[Title('x')] class extends Base {
    public function __construct(public int $promoted, private $hidden) {}
    function implicit() {}
}; ?>]],
    "x.php"
  )
  eq(class.name, nil)
  eq(class.parent, "Livewire\\Component")
  local by = {}
  for _, m in ipairs(class.members) do
    by[m.name] = m
  end
  eq({ by.promoted.kind, by.promoted.visibility }, { "property", "public" })
  eq(by.hidden.visibility, "private")
  eq(by.implicit.visibility, "public")
end

T["index"] = MiniTest.new_set()

T["index"]["trait and parent members, complete"] = function()
  local index = greeter()
  eq(index.complete, true)
  eq(index.members.search.file, H.app .. "/app/Concerns/HasSearch.php")
  eq(index.members.sortBy.file, H.app .. "/app/Livewire/BaseTable.php")
  eq(index.members.sortField.kind, "property")
  eq(index.traits, { "HasSearch" })
  -- own members come first, then the trait, then the parent
  eq(index.list[1].name, "name")
  eq(index.list[#index.list].name, "sortBy")
end

T["index"]["Livewire's base class is not read"] = function()
  local index = members.index(H.app .. "/app/Livewire/Reports/Summary.php", H.app)
  eq(index.complete, true)
  eq(names(index.list), { "month", "render" })
end

T["index"]["unresolvable parent is incomplete"] = function()
  local index = members.index(H.app .. "/app/Livewire/Broken.php", H.app)
  eq(index.complete, false)
  eq(names(index.list), { "own" })
end

T["index"]["__call makes it incomplete"] = function()
  eq(members.index(H.app .. "/app/Livewire/Magical.php", H.app).complete, false)
end

T["index"]["single-file component reads its PHP block"] = function()
  local index = members.index(H.app .. "/resources/views/pages/⚡profile.blade.php", H.app)
  eq(index.complete, true)
  eq(names(index.list), { "email", "save" })
end

T["index"]["unsaved edit to the class"] = function()
  local path = H.app .. "/app/Livewire/Reports/Summary.php"
  vim.cmd.edit(vim.fn.fnameescape(path))
  eq(members.index(path, H.app).members.archive, nil)
  local last = vim.api.nvim_buf_line_count(0) - 1
  vim.api.nvim_buf_set_lines(0, last, last, false, { "    public function archive() {}" })
  eq(members.index(path, H.app).members.archive.kind, "method")
  vim.cmd("silent! bwipeout!")
end

T["filters"] = MiniTest.new_set()

T["filters"]["callable methods and settable properties"] = function()
  local index = greeter()
  eq(names(members.methods(index)), { "changeGreeting", "clearSearch", "sortBy" })
  eq(names(members.properties(index)), { "form", "greeting", "greetingMessage", "name", "open", "search", "sortField" })
end

T["filters"]["why a method can't be called"] = function()
  local index = greeter()
  eq(members.call_problem(index, "changeGreeting"), nil)
  eq(members.call_problem(index, "mount"), "hook")
  eq(members.call_problem(index, "updatedName"), "hook")
  eq(members.call_problem(index, "bootHasSearch"), "hook")
  eq(members.call_problem(index, "render"), "render")
  eq(members.call_problem(index, "guard"), "not_public")
  eq(members.call_problem(index, "make"), "static")
  eq(members.call_problem(index, "name"), "missing")
  eq(members.call_problem(index, "nope"), "missing")
end

T["filters"]["why a property can't be set"] = function()
  local index = greeter()
  eq(members.set_problem(index, "name"), nil)
  eq(members.set_problem(index, "secret"), "not_public")
  eq(members.set_problem(index, "instances"), "static")
  eq(members.set_problem(index, "changeGreeting"), "missing")
end

T["filters"]["Form object properties"] = function()
  local index = greeter()
  local form = members.form_index(index, "form")
  eq(form.complete, true)
  eq(names(members.properties(form)), { "body", "title" })
  eq(members.form_index(index, "name"), nil)
end

T["for_buffer"] = function()
  H.skip_without_blade()
  vim.cmd.edit(vim.fn.fnameescape(H.app .. "/resources/views/livewire/greeter.blade.php"))
  eq(members.for_buffer(0).name, "Greeter")
  vim.cmd.edit(vim.fn.fnameescape(H.app .. "/resources/views/components/app-logo.blade.php"))
  eq(members.for_buffer(0), nil)
end

return T
