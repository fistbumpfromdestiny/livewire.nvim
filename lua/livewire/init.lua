local M = {}

---@param opts? livewire.Config
function M.setup(opts)
  local options = require("livewire.config").set(opts)
  local project = require("livewire.project")
  project.reset()
  require("livewire.components").reset()
  require("livewire.members").reset()
  require("livewire.cmp").register()

  local diagnostics = require("livewire.diagnostics")
  diagnostics.disable()
  local lsp = require("livewire.lsp")
  lsp.stop()

  local group = vim.api.nvim_create_augroup("livewire", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    desc = "Re-scan Livewire custom directives and component classes",
    callback = function(ev)
      project.on_write(vim.fs.normalize(vim.fn.fnamemodify(ev.match, ":p")))
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "LivewireProjectChanged",
    callback = function(ev)
      diagnostics.project_changed(ev.data.root)
    end,
  })

  ---@param buf integer
  local function attach(buf)
    if options.diagnostics then
      diagnostics.attach(buf)
    end
    if options.definition.enabled then
      lsp.attach(buf)
    end
  end
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "blade",
    desc = "Livewire diagnostics and go-to-definition",
    callback = function(ev)
      attach(ev.buf)
    end,
  })
  -- buffers opened before setup() ran (lazy-loading)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "blade" then
      attach(buf)
    end
  end
end

return M
