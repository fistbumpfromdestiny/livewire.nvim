local M = {}

---@class livewire.Config
---@field livewire_version? 3|4 Livewire major version; nil detects it from composer.lock
---@field custom_directives string[] Extra `wire:` names treated as known (custom directives or event names)
---@field scan_paths string[] Globs, relative to the project root, scanned for `Livewire.directive(...)`
---@field diagnostics boolean Report directive typos as warnings
M.defaults = {
  livewire_version = nil,
  custom_directives = {},
  scan_paths = { "resources/js/**/*.js", "resources/js/**/*.ts" },
  diagnostics = true,
}

---@type livewire.Config
M.options = vim.deepcopy(M.defaults)

---@param opts? table
function M.set(opts)
  M.options = vim.tbl_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

return M
