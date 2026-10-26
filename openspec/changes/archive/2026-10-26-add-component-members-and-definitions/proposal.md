## Why

livewire.nvim checks the `wire:` attribute *names*, but not their *values*. In `wire:model="nmae"` or `wire:click="savee"` the attribute name is fine but the member doesn't exist. Livewire only reports that at runtime, as a `PublicPropertyNotFoundException` or `MethodNotFoundException` after a click. The plugin's README lists everything that's missing ("Not yet"): member completion, member warnings, go-to-definition and an nvim-cmp source. Go-to-definition already works in the author's own config (`~/.config/nvim/lua/config/components.lua`), so the hardest part, finding the component behind a view, is already proven. It just isn't available to anyone else.

## What Changes

- **Component resolution** (ported from `components.lua`):
  - finds the file behind `<livewire:…>` / `@livewire('…')` for class, single-file (`⚡name.blade.php`) and multi-file components
  - finds the file behind `<flux:…>`: a published override in `resources/views/flux` first, then vendor
  - finds the file behind `<x-…>`, unless the new `definition.blade_components` option turns that off
  - finds the Livewire component that owns the current Blade view
  - reads `config/livewire.php` for the class path, component locations and namespaces
- **Member index:**
  - finds a component's properties and methods, with their visibility, in the class, its traits and its parent classes
  - stops at `Livewire\Component`, matching what Livewire lets the browser call or set
  - follows traits and parents through PSR-4
  - uses the tree-sitter `php` parser
- **Go-to-definition through a built-in LSP server.** An in-process language server named `livewire` attaches to Blade buffers and answers `textDocument/definition` for:
  - component tags
  - `wire:model`, `wire:click` (and every other event or action directive), `wire:target`, `$set('…')` / `$toggle('…')`
  - `$wire.member`

  Any existing `gd` (LazyVim, Snacks, Telescope, `vim.lsp.buf.definition`) works without keymap configuration.
- **Member completion** inside attribute values:
  - properties in `wire:model`, including one level into Livewire Form objects (`form.email`)
  - public methods (excluding `render` and lifecycle hooks) and magic actions in `wire:click` and other action directives
  - properties and methods in `wire:target` and after `$wire.`
- **Member diagnostics.** Warnings for:
  - a `wire:model` property, or a plain `wire:click` / action method, that doesn't exist on the owning component (with a "did you mean")
  - one that exists but isn't public

  They are reported only when the owning component and its whole class chain were resolved, so an unknown base class or trait never produces false warnings.
- **nvim-cmp source** (`livewire.cmp`) offering the same items as the blink.cmp source.
- blink.cmp and nvim-cmp also trigger on `"`, `'` and `(`, so value completion opens without typing a letter.
- README: the "Not yet" list goes away. New sections cover go-to-definition, member completion and warnings, nvim-cmp setup, the `definition` options, and migrating a custom `gd` mapping.

## Capabilities

### New Capabilities
- `component-resolution`: maps component tags to files, finds the component that owns a Blade view, reads `config/livewire.php` and PSR-4, and indexes a component's members across traits and parent classes.
- `definition`: the in-process `livewire` LSP server and the go-to-definition targets it answers.
- `member-completion`: completion of component properties, methods and magic actions inside `wire:` attribute values and after `$wire.`.
- `member-diagnostics`: warnings for `wire:model` properties and action methods that don't exist on the owning component or aren't public.

### Modified Capabilities
- `directive-catalog`: each directive gains a value kind (property, action, targets, expression or none), which tells member features what a directive's value refers to.
- `directive-completion`: the completion source requirement now covers nvim-cmp as well as blink.cmp, and the trigger characters gain `"`, `'` and `(`.

## Impact

- **New modules:**
  - `lua/livewire/components.lua` (tag and owner resolution, config, PSR-4)
  - `lua/livewire/members.lua` (PHP member index)
  - `lua/livewire/lsp.lua` (in-process server)
  - `lua/livewire/cmp.lua` (nvim-cmp source)
  - `lua/livewire/value_context.lua` (cursor inside a `wire:` value or after `$wire.`)
- **Changed modules:**
  - `catalog/directives.lua` and `catalog/events.lua` (value kinds)
  - `blink.lua` (value items and trigger characters)
  - `diagnostics.lua` (member checks)
  - `init.lua` (starts the LSP server, re-checks on PHP writes)
  - `config.lua` (the `definition` options)
  - `health.lua` (php parser, owner of the current buffer)
- **Dependencies:** the tree-sitter `php` parser becomes required for member features. Directive features keep working without it, and `:checkhealth livewire` reports it. nvim-cmp is optional.
- **Tests:** new fixtures:
  - a class component with a trait and a user-land base class
  - a single-file and a multi-file component
  - a Form object
  - a Flux override
  - a `config/livewire.php`
  - `vendor/composer/autoload_psr4.php`

  Tests also need nvim-cmp, cloned into `.tests/` the same way mini.nvim is.
- **Author's config:** after this ships, `~/.config/nvim/lua/config/components.lua` and the custom `gd` in `lua/plugins/laravel.lua` can be removed. That's outside this repo and isn't part of this change's tasks.
