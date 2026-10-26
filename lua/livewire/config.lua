local M = {}

---@class livewire.Config
---@field livewire_version? 3|4 Livewire major version; nil detects it from composer.lock
---@field custom_directives string[] Extra `wire:` names treated as known (custom directives or event names)
---@field scan_paths string[] Globs, relative to the project root, scanned for `Livewire.directive(...)`
---@field diagnostics boolean Report directive typos and unknown component members as warnings
---@field definition livewire.DefinitionConfig

---@class livewire.DefinitionConfig
---@field enabled boolean Start the in-process `livewire` language server for go-to-definition
---@field blade_components boolean Also resolve `<x-…>` Blade components
M.defaults = {
  livewire_version = nil,
  custom_directives = {},
  scan_paths = { "resources/js/**/*.js", "resources/js/**/*.ts" },
  diagnostics = true,
  definition = { enabled = true, blade_components = true },
}

-- option tables merged one level deep; lists and everything else replace the default
local nested = { "definition" }

---@type livewire.Config
M.options = vim.deepcopy(M.defaults)

---@param opts? table
function M.set(opts)
  opts = opts or {}
  M.options = vim.tbl_extend("force", vim.deepcopy(M.defaults), opts)
  for _, key in ipairs(nested) do
    M.options[key] = vim.tbl_extend("force", vim.deepcopy(M.defaults[key]), opts[key] or {})
  end
  return M.options
end

return M
