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

  if require("livewire.members").available() then
    health.ok("tree-sitter `php` parser found")
  else
    health.warn("tree-sitter `php` parser not found: component member completion, warnings and go-to-definition are off", {
      "Install it with nvim-treesitter: `:TSInstall php`",
    })
  end

  local blink, cmp = pcall(require, "blink.cmp"), pcall(require, "cmp")
  if blink then
    health.ok("blink.cmp found (add the `livewire` provider to enable completion)")
  end
  if cmp then
    health.ok("nvim-cmp found (add `{ name = \"livewire\" }` to its sources to enable completion)")
  end
  if not blink and not cmp then
    health.warn("neither blink.cmp nor nvim-cmp found: completion is unavailable", {
      "Diagnostics and go-to-definition still work without them",
    })
  end

  health.ok(("diagnostics: %s"):format(config.options.diagnostics and "enabled" or "disabled by config"))
  if config.options.definition.enabled then
    local clients = vim.lsp.get_clients({ name = require("livewire.lsp").NAME })
    health.ok(("go-to-definition: enabled (%d `livewire` language server client%s running)"):format(#clients, #clients == 1 and "" or "s"))
  else
    health.ok("go-to-definition: disabled by config")
  end
  health.info(("Blade components (`<x-…>`): %s"):format(config.options.definition.blade_components and "resolved" or "not resolved"))

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

  if root and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf):match("%.blade%.php$") then
    local owner = require("livewire.components").owner(buf)
    if not owner then
      health.info("owning Livewire component: none (member completion and warnings are off in this view)")
    else
      local rel = owner:sub(#root + 2)
      local index = require("livewire.members").for_buffer(buf)
      if not index then
        health.warn(("owning Livewire component: %s, but its members can't be read"):format(rel), {
          "Check that the tree-sitter `php` parser is installed",
        })
      elseif index.complete then
        health.ok(("owning Livewire component: %s (%d members; every trait and parent class found)"):format(rel, #index.list))
      else
        health.warn(("owning Livewire component: %s (%d members; some traits or parent classes weren't found, so member warnings are off)"):format(rel, #index.list), {
          "Run `composer install` so vendor/composer/autoload_psr4.php exists, or check the class's `use` statements",
        })
      end
    end
  end
end

return M
