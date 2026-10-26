## Why

Livewire directives are plain HTML attributes. A typo such as `wire.model="name"`, `wire:modle` or `wire:model.lve` produces no error anywhere: not from the browser, not from Blade, not from Livewire. The input just quietly stops working. No tool usable from LazyVim/blink.cmp completes `wire:` directives or warns about them (see `docs/research.md`). This change is the first slice of livewire.nvim, the research's suggested features 1, 2 and the first three diagnostics. It gives the plugin a usable core and the directive data that later slices (member completion, go-to-definition) build on.

## What Changes

- New Neovim plugin skeleton: `lua/livewire/` with `setup(opts)`, a user-facing config, a `:checkhealth livewire` health check, a README with lazy.nvim and blink.cmp setup, and a headless test suite.
- **Directive catalog:** a data table of Livewire 3 and Livewire 4 directives. Each entry has a description, docs URL, version range, allowed modifiers (including argument forms such as `debounce.500ms`), and colon sub-names (`wire:sort:item`). It is built from and checked against the Livewire docs and the installed v4.4.8 bundle. A list of DOM event names covers `wire:<event>`, and internal attributes (`wire:id`, `wire:snapshot`, ...) are excluded.
- **Version detection:** reads the Livewire version from the project's `composer.lock`, with a config override. Defaults to v4 when it can't be found.
- **Custom directives:** found by scanning the project's JS for `Livewire.directive('name'` and from a `custom_directives` config option. Both are treated as known.
- **Completion (blink.cmp v1 source):** directive names after `wire:`, and modifiers after `wire:<directive>.`, in Blade files. Each item has a description and docs link.
- **Diagnostics (warnings):** `wire.<name>` used as an attribute name (did you mean `wire:<name>`?), unknown directive names, and unknown modifiers for a known directive. Each comes with a "did you mean" suggestion when one is close.

Out of scope (later changes): component member completion inside attribute values, a member-existence diagnostic, go-to-definition and absorbing `~/.config/nvim/lua/config/components.lua`, and an nvim-cmp source.

## Capabilities

### New Capabilities
- `directive-catalog`: The versioned Livewire directive/modifier data, Livewire version detection, and custom directive discovery that completion and diagnostics both read from.
- `directive-completion`: blink.cmp source that completes `wire:` directive names and their modifiers in Blade buffers.
- `directive-diagnostics`: Warnings for `wire.` attribute typos, unknown directives and unknown modifiers in Blade buffers.

### Modified Capabilities
<!-- none: no existing specs -->

## Impact

- **New code:** `lua/livewire/**`, `plugin/` or setup entry point, `tests/**`, and fixture Blade/JS/composer.lock files. The repo currently contains only `README.md` and `docs/research.md`.
- **Runtime dependencies:** Neovim 0.11+ and the tree-sitter `blade` parser (needed for diagnostics and context detection; completion falls back to line text without it). blink.cmp v1 is optional, only for completion.
- **Dev dependencies:** `mini.test` (fetched into a git-ignored folder by the test bootstrap) for headless tests.
- **User config:** users add a `sources.providers.livewire` entry to blink.cmp and enable it for the `blade` filetype. The README documents this.
- **No change** to the user's `components.lua` in this change.
