# livewire.nvim

Livewire support for Blade files in Neovim:

- **Completion** of `wire:` directives, their sub-names (`wire:sort:item`) and modifiers (`wire:model.live.debounce.500ms`), with descriptions and links to the Livewire docs, via [blink.cmp](https://github.com/saghen/blink.cmp).
- **Warnings** for directive mistakes that the browser, Blade and Livewire all ignore silently:

  ```blade
  <input wire.model="name">     {{-- Livewire ignores `wire.model`. Did you mean `wire:model`? --}}
  <input wire:modle="name">     {{-- Unknown Livewire directive `wire:modle`. Did you mean `wire:model`? --}}
  <input wire:model.lve="name"> {{-- Unknown modifier `.lve` for `wire:model`. Did you mean `.live`? --}}
  <div wire:ref="modal">        {{-- `wire:ref` requires Livewire 4 (this project uses Livewire 3) --}}
  ```

Livewire 3 and 4 are both supported. The version is read from your project's `composer.lock`.

## Requirements

- Neovim 0.11+
- The tree-sitter `blade` parser (`:TSInstall blade`). Diagnostics need it, and without it completion only works when the tag is on a single line.
- [blink.cmp](https://github.com/saghen/blink.cmp) v1, for completion. Diagnostics work without it.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim) (including LazyVim):

```lua
{
  "fistbumpfromdestiny/livewire.nvim",
  ft = "blade",
  opts = {},
},
{
  "saghen/blink.cmp",
  opts = {
    sources = {
      per_filetype = {
        blade = { inherit_defaults = true, "livewire" },
      },
      providers = {
        livewire = {
          name = "Livewire",
          module = "livewire.blink",
          -- rank Livewire items above buffer words and snippets
          score_offset = 100,
        },
      },
    },
  },
},
```

`opts = {}` makes lazy.nvim call `require("livewire").setup()`, which turns on the diagnostics. The completion source works without `setup()`.

## Configuration

These are the defaults:

```lua
require("livewire").setup({
  -- 3 or 4. nil reads the version of livewire/livewire from composer.lock (falling back to 4).
  livewire_version = nil,
  -- Extra `wire:` names to treat as known. Add your custom directives here when they aren't
  -- found automatically (see below), and custom event names you listen to, such as
  -- `wire:trix-change`.
  custom_directives = {},
  -- Files, relative to the project root, searched for `Livewire.directive("name", ...)`.
  scan_paths = { "resources/js/**/*.js", "resources/js/**/*.ts" },
  -- Report directive mistakes as warnings.
  diagnostics = true,
})
```

### Custom directives

Directives your project registers with `Livewire.directive("tooltip", ...)` in a file matched by `scan_paths` are found automatically. They're offered in completion and never reported as unknown. Their modifiers aren't checked, since the plugin can't know them. The scan reruns when you save one of those files from Neovim.

### Custom events

Livewire treats any `wire:<name>` it doesn't recognise as an event listener. So `wire:trix-change="..."` listens for a `trix-change` event, and `wire:modle` would quietly listen for a `modle` event. livewire.nvim knows the standard DOM events, but it reports names it doesn't recognise. If you listen to a custom event, add its name to `custom_directives`.

## Health check

`:checkhealth livewire` shows whether the `blade` parser and blink.cmp are found, and for the current buffer's project which Livewire version is used (and why) and which custom directives were found.

## Not yet

- Completion of component properties and methods inside `wire:model="…"` and `wire:click="…"`
- Warnings for properties and methods that don't exist on the component
- Go to definition for components, `wire:click`, `wire:model` and `$wire`
- An nvim-cmp source

## Development

```sh
make test
```

This runs the [mini.test](https://github.com/echasnovski/mini.nvim) suite headlessly (it clones mini.nvim into `.tests/` on first run). Tests that need the `blade` parser are skipped when it isn't installed.

`scripts/bundle-directives.sh path/to/livewire.esm.js` lists the directives and modifiers a Livewire JS bundle handles. Use it to check `lua/livewire/catalog/directives.lua` against a new Livewire release. Point `LIVEWIRE_V4_BUNDLE` / `LIVEWIRE_V3_BUNDLE` at bundles to have `make test` do that check too.

## License

MIT
