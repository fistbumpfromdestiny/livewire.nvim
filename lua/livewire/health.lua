local M = {}

function M.check()
  local health = vim.health
  local config = require("livewire.config")
  local project = require("livewire.project")

  health.start("livewire.nvim")
  if vim.fn.has("nvim-0.11") == 1 then
    health.ok("Neovim " .. tostring(vim.version()))
  else
    health.error("Neovim 0.11+ is required, found " .. tostring(vim.version()))
  end

  local ok, added = pcall(vim.treesitter.language.add, "blade")
  if ok and added then
    health.ok("tree-sitter `blade` parser found")
  else
    health.error("tree-sitter `blade` parser not found: diagnostics are disabled and completion only works on single-line tags", {
      "Install it with nvim-treesitter: `:TSInstall blade`",
    })
  end

  if pcall(require, "blink.cmp") then
    health.ok("blink.cmp found (add the `livewire` provider to enable completion)")
  else
    health.warn("blink.cmp not found: completion is unavailable", { "Diagnostics still work without it" })
  end

  health.ok(("diagnostics: %s"):format(config.options.diagnostics and "enabled" or "disabled by config"))

  health.start("livewire.nvim: current project")
  -- :checkhealth opens its own buffer; describe the window we came from
  local buf = vim.fn.bufnr("#") > 0 and vim.fn.bufnr("#") or 0
  local root = project.root(buf)
  health.info("project root: " .. (root or "none found (no composer.lock, composer.json or artisan above this buffer)"))
  local version, source = project.version(buf)
  local sources = {
    override = "from the `livewire_version` option",
    ["composer.lock"] = "from composer.lock",
    default = "default; no livewire/livewire found in composer.lock",
  }
  health.ok(("Livewire %d (%s)"):format(version, sources[source]))
  local custom = vim.tbl_keys(project.custom_directives(buf))
  table.sort(custom)
  health.info("custom directives: " .. (#custom > 0 and table.concat(custom, ", ") or "none"))
end

return M
