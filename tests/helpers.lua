local H = {}

H.root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
H.fixtures = H.root .. "/tests/fixtures"

function H.has_blade()
  local ok, added = pcall(vim.treesitter.language.add, "blade")
  return ok and added == true
end

--- Skip the current case when the blade parser isn't installed.
function H.skip_without_blade()
  if not H.has_blade() then
    MiniTest.skip("tree-sitter `blade` parser not installed")
  end
end

function H.has_php()
  local ok, added = pcall(vim.treesitter.language.add, "php")
  return ok and added == true
end

--- Skip the current case when the php parser isn't installed.
function H.skip_without_php()
  if not H.has_php() then
    MiniTest.skip("tree-sitter `php` parser not installed")
  end
end

--- The fixture Livewire 4 project used by component and member tests.
H.app = H.fixtures .. "/app"

return H
