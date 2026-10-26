# livewire.nvim

Livewire support for Blade files in Neovim, plus the Blade and Flux components used in Livewire views:

- **Completion** via [blink.cmp](https://github.com/saghen/blink.cmp) or [nvim-cmp](https://github.com/hrsh7th/nvim-cmp):
  - `wire:` directives, their sub-names (`wire:sort:item`) and modifiers (`wire:model.live.debounce.500ms`), with descriptions and links to the Livewire docs.
  - Your component's properties inside `wire:model="…"`, its methods and Livewire's magic actions inside `wire:click="…"` and other actions, and both after `$wire.`.
- **Go to definition** from `<livewire:…>`, `@livewire(…)`, `<flux:…>`, `<x-…>`, `wire:model`, `wire:click`, `wire:target` and `$wire.…` to the component or member. It works with whatever `gd` you already use.
- **Warnings** for mistakes that the browser, Blade and Livewire all ignore silently, or only report after a click:

  ```blade
  <input wire.model="name">     {{-- Livewire ignores `wire.model`. Did you mean `wire:model`? --}}
  <input wire:modle="name">     {{-- Unknown Livewire directive `wire:modle`. Did you mean `wire:model`? --}}
  <input wire:model.lve="name"> {{-- Unknown modifier `.lve` for `wire:model`. Did you mean `.live`? --}}
  <div wire:ref="modal">        {{-- `wire:ref` requires Livewire 4 (this project uses Livewire 3) --}}
  <input wire:model="nmae">     {{-- Property `nmae` not found on `Greeter`. Did you mean `name`? --}}
  <button wire:click="savee">   {{-- Method `savee` not found on `Greeter`. Did you mean `save`? --}}
  <button wire:click="mount">   {{-- `mount` is a lifecycle hook; Livewire won't call it from the browser. --}}
  ```

Livewire 3 and 4 are both supported. The version is read from your project's `composer.lock`.

## Requirements

- Neovim 0.11+
- The tree-sitter `blade` parser (`:TSInstall blade`). Diagnostics need it, and without it completion only works when the tag is on a single line.
- The tree-sitter `php` parser (`:TSInstall php`, included in LazyVim's `lang.php` extra), for anything involving your component's properties and methods.
- [blink.cmp](https://github.com/saghen/blink.cmp) v1 or [nvim-cmp](https://github.com/hrsh7th/nvim-cmp), for completion. Diagnostics and go-to-definition work without them.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim) (including LazyVim) and blink.cmp:

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

With nvim-cmp, `setup()` registers a source named `livewire`. Add it to nvim-cmp's sources:

```lua
{
  "fistbumpfromdestiny/livewire.nvim",
  ft = "blade",
  opts = {},
},
{
  "hrsh7th/nvim-cmp",
  opts = function(_, opts)
    opts.sources = opts.sources or {}
    table.insert(opts.sources, 1, { name = "livewire" })
  end,
},
```

The source only offers items in Blade buffers.

`opts = {}` makes lazy.nvim call `require("livewire").setup()`. That turns on the diagnostics and go-to-definition, and registers the nvim-cmp source. The blink.cmp source works without `setup()`.

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
  -- Report directive and component member mistakes as warnings.
  diagnostics = true,
  definition = {
    -- Answer go-to-definition through the built-in `livewire` language server.
    enabled = true,
    -- Also resolve plain Blade components (`<x-…>`). Turn this off if another language
    -- server already does it.
    blade_components = true,
  },
})
```

### Custom directives

Directives your project registers with `Livewire.directive("tooltip", ...)` in a file matched by `scan_paths` are found automatically. They're offered in completion and never reported as unknown. Their modifiers aren't checked, since the plugin can't know them. The scan reruns when you save one of those files from Neovim.

### Custom events

Livewire treats any `wire:<name>` it doesn't recognise as an event listener. So `wire:trix-change="..."` listens for a `trix-change` event, and `wire:modle` would quietly listen for a `modle` event. livewire.nvim knows the standard DOM events, but it reports names it doesn't recognise. If you listen to a custom event, add its name to `custom_directives`.

## Component members

Member completion, warnings and go-to-definition need to know which Livewire component a view belongs to:

| View | Component |
|---|---|
| Single-file `⚡name.blade.php` | the class in the view's own `<?php … ?>` block |
| Multi-file `⚡name/name.blade.php` | `⚡name/name.php` next to it |
| `resources/views/livewire/a/b-c.blade.php` | `app/Livewire/A/BC.php`, or the class whose `render()` returns `view('livewire.a.b-c')` |

Paths follow your published `config/livewire.php` when there is one. Other views, such as anonymous Blade components and partials, have no component, so they get magic actions in completion but no member warnings.

A component's members include its traits and parent classes, which are found through Composer's PSR-4 autoload map. As in Livewire, members declared on `Livewire\Component` itself don't count. `wire:click` can only call public, non-static methods other than `render` and lifecycle hooks, and `wire:model` can only set public, non-static properties.

Member warnings are only reported when the whole class chain was found. If a parent class or trait can't be found (for example before `composer install`), or the class defines `__call`, the view gets no member warnings rather than wrong ones. Only plain values are checked: `wire:model="name"` and `wire:click="save"` or `save(1)`. Magic actions (`$refresh`, `$set(…)`), JavaScript expressions and `$wire.…` aren't.

When you save a component class, or any trait or parent class it uses, open views are checked again.

## Go to definition

`setup()` starts a small language server named `livewire` inside Neovim (no external process) for Blade buffers. It only answers go-to-definition, so `gd`, `vim.lsp.buf.definition()`, Snacks and Telescope all pick it up with no extra keymaps:

| Cursor on | Goes to |
|---|---|
| `<livewire:counter>`, `@livewire('counter')` | the component class, single-file view or multi-file class |
| `<flux:button>` | your published `resources/views/flux/…` override, else the Flux package view |
| `<x-alert>`, `<x-layouts::app>` | `app/View/Components/…` or the anonymous component view |
| `wire:model="name"`, `wire:model="form.title"` | the property, or the field on the Form object |
| `wire:click="save(1)"`, `wire:target="save"`, `$toggle('open')` | the method or property |
| `$wire.save()` | the method or property |

If another language server also resolves components (for example `<x-…>` in laravel/lsp), `gd` may list both answers. Set `definition.blade_components = false` to leave `<x-…>` to the other server.

If you used a custom `gd` mapping to jump to Livewire components and members, you can remove it and let your normal LSP `gd` handle it.

## Health check

`:checkhealth livewire` shows:
- whether the `blade` and `php` parsers and blink.cmp or nvim-cmp are found
- whether the language server is running
- for the current buffer's project, which Livewire version is used (and why) and which custom directives were found
- which component owns the current view, and whether its whole class chain was found

## Development

```sh
make test
```

This runs the [mini.test](https://github.com/echasnovski/mini.nvim) suite headlessly. On first run it clones mini.nvim and nvim-cmp into `.tests/`. Tests that need the `blade` or `php` parser are skipped when it isn't installed.

`scripts/bundle-directives.sh path/to/livewire.esm.js` lists the directives, modifiers and `$wire` magic properties a Livewire JS bundle handles. Use it to check `lua/livewire/catalog/` against a new Livewire release. Point `LIVEWIRE_V4_BUNDLE` / `LIVEWIRE_V3_BUNDLE` at bundles to have `make test` do that check too.

## License

MIT
