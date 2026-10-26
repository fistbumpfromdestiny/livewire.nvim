local M = {}

---@param opts? livewire.Config
function M.setup(opts)
  require("livewire.config").set(opts)
  local project = require("livewire.project")
  project.reset()

  local diagnostics = require("livewire.diagnostics")
  diagnostics.disable()

  local group = vim.api.nvim_create_augroup("livewire", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    desc = "Re-scan Livewire custom directives",
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

  if not require("livewire.config").options.diagnostics then
    return
  end
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "blade",
    desc = "Check Livewire directives",
    callback = function(ev)
      diagnostics.attach(ev.buf)
    end,
  })
  -- buffers opened before setup() ran (lazy-loading)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "blade" then
      diagnostics.attach(buf)
    end
  end
end

return M
