-- Headless test bootstrap: this repo + mini.nvim (cloned into .tests/) + the user's
-- site dir so an installed `blade` tree-sitter parser is found.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local mini = root .. "/.tests/mini.nvim"

if not vim.uv.fs_stat(mini) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--depth=1", "https://github.com/echasnovski/mini.nvim", mini })
  if vim.v.shell_error ~= 0 then
    error("failed to clone mini.nvim into " .. mini)
  end
end

vim.opt.runtimepath:prepend(root)
package.path = root .. "/tests/?.lua;" .. package.path
vim.opt.runtimepath:append(mini)
local site = vim.fn.stdpath("data") .. "/site"
if vim.env.LIVEWIRE_TEST_NO_SITE then
  -- simulate a machine without the blade parser
  vim.opt.runtimepath:remove(site)
  vim.opt.runtimepath:remove(site .. "/after")
else
  vim.opt.runtimepath:append(site)
end
vim.o.swapfile = false

require("mini.test").setup()
