local H = require("helpers")
local T = MiniTest.new_set()

T["blade parser"] = function()
  H.skip_without_blade()
  MiniTest.expect.equality(H.has_blade(), true)
end

T["php parser"] = function()
  H.skip_without_php()
  MiniTest.expect.equality(H.has_php(), true)
end

T["app fixture project"] = function()
  for _, rel in ipairs({
    "composer.json",
    "config/livewire.php",
    "vendor/composer/autoload_psr4.php",
    "app/Livewire/Greeter.php",
    "resources/views/livewire/greeter.blade.php",
    "resources/views/pages/⚡profile.blade.php",
    "resources/views/components/⚡counter/counter.php",
  }) do
    MiniTest.expect.equality(vim.uv.fs_stat(H.app .. "/" .. rel) ~= nil, true)
  end
end

return T
