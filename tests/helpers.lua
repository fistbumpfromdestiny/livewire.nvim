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

return H
