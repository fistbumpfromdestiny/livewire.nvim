-- Headless test bootstrap: this repo + mini.nvim and nvim-cmp (cloned into .tests/) + the
-- user's site dir so installed `blade` and `php` tree-sitter parsers are found.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

local function clone(repo)
  local dir = root .. "/.tests/" .. repo:match("[^/]+$")
  if not vim.uv.fs_stat(dir) then
    vim.fn.system({ "git", "clone", "--filter=blob:none", "--depth=1", "https://github.com/" .. repo, dir })
    if vim.v.shell_error ~= 0 then
      error("failed to clone " .. repo .. " into " .. dir)
    end
  end
  return dir
end

local mini = clone("echasnovski/mini.nvim")
local cmp = clone("hrsh7th/nvim-cmp")

vim.opt.runtimepath:prepend(root)
package.path = root .. "/tests/?.lua;" .. package.path
vim.opt.runtimepath:append(mini)
vim.opt.runtimepath:append(cmp)
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
