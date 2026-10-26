# Research: Livewire directive support for Neovim

Date: 2026-10-26

## The problem

Livewire directives are plain HTML attributes, so a typo fails silently:

```blade
<input wire.model.fill="greeting">   {{-- should be wire:model.fill --}}
```

- **HTML:** dots are valid in attribute names, and browsers ignore attributes they don't know.
- **Blade:** passes unknown attributes through unchanged.
- **Livewire:** only reads attributes that start with `wire:`. It never warns about anything else.

The result is an input that silently isn't bound. Nothing in the current editor setup (LazyVim) catches it either.

## What already exists

| Tool | Livewire support | Completes `wire:` directives? | Usable with LazyVim / blink.cmp? |
|---|---|---|---|
| [laravel/lsp](https://github.com/laravel/lsp), the official Laravel language server (Laracon US 2026) | Completes, explains and links component names | No. It has no Livewire diagnostics. | Yes (Neovim 0.11+) |
| `laravel_ls`, already installed | Go-to-definition for Laravel strings | No | Yes |
| `intelephense`, already installed | PHP only | No | Yes |
| `friendly-snippets`, already installed | 3 snippets: `@livewireStyles`, `@livewireScripts`, `@livewire(...)` | No | Yes |
| [lali-components.nvim](https://github.com/RicardoRamirezR/lali-components.nvim) | Completes component names after `<x-`, `<live`, `@livewire` | No | nvim-cmp only |
| [coc-laravel](https://socket.dev/npm/package/@yaegassy/coc-laravel) | Has `wire:model` completion | Yes | No. It needs coc.nvim, a separate completion system. |

**Conclusion:** no tool for LazyVim completes `wire:` directives, their modifiers, or the component members they refer to, and none warns about mistakes in them.

### Related code already in the local config

`~/.config/nvim/lua/config/components.lua` (358 lines) already solves the hardest shared problem for go-to-definition:

- reads `config/livewire.php` for the class path, component locations and namespaces
- finds the Livewire component that owns a view, for class-based, single-file (`⚡name.blade.php`) and multi-file components
- finds a member (property or method) in that component, including traits and parent classes, using PSR-4 from `composer.json`

The plugin should take over this logic rather than duplicate it. The local config then becomes a consumer of the plugin.

## What the plugin would need

Working name: **livewire.nvim**.

### Features

1. **Directive completion.** Typing `wire:` in a Blade file suggests Livewire 4 directives, each with a short description and a link to its docs.
2. **Modifier completion.** Typing `wire:model.` suggests that directive's modifiers (`live`, `blur`, `fill`, `debounce.500ms`, ...). Typing `wire:click.` suggests event modifiers (`prevent`, `stop`, `self`, ...).
3. **Member completion.** Inside `wire:model="…"` it suggests the owning component's public properties. Inside `wire:click="…"`, `wire:submit="…"` and similar, it suggests the component's public methods. This must work for class, single-file and multi-file components.
4. **Diagnostics.**
   - `wire.something=` used as an attribute name: did you mean `wire:something`?
   - unknown directive: `wire:modle`
   - unknown modifier for a directive: `wire:model.lve`
   - (later) a `wire:model` property or `wire:click` method that doesn't exist on the component
5. **Go-to-definition.** Moved here from `components.lua`: `<livewire:…>`, `@livewire(…)`, `wire:click`, `wire:model` and `$wire.…`.

Suggested order: 1 + 2 + 4 (first three bullets) first, then 3, then 5 and the member-existence diagnostic.

### Technical pieces

- **blink.cmp source.** A Lua module implementing blink.cmp's source interface (`get_trigger_characters` returning `:`, `.` and `"`, plus `get_completions`, and optionally `resolve` for docs). It is registered via `sources.providers` and enabled for the `blade` filetype. Installed blink.cmp is v1.10.2, and blink.cmp v2 is in development with breaking changes, so target v1.
- **Context detection.** Work out from the cursor whether you're typing a directive name, a modifier, or an attribute value. Two options:
  - Tree-sitter `blade` parser (installed) to find the attribute node, with the text on the current line as a fallback.
  - Lua patterns on the current line only. This is simpler, but fails on attributes split across lines.
- **Directive data.** One table of directives → description, docs URL, allowed modifiers and value kind (property, method, expression, none). This is the core of features 1, 2 and 4, and must be checked against the installed Livewire version (see below).
- **Component member extraction.** Public properties and methods from the PHP class, or from the `<?php … ?>` block of a single-file component. Lua patterns are enough for a first version (`public … $name`, `public function name(`); the tree-sitter `php` parser is the more robust upgrade. Exclude Livewire lifecycle hooks (`mount`, `render`, `boot`, `updated*`, ...).
- **Diagnostics.** A namespace and `vim.diagnostic.set`, run on `BufReadPost`, `TextChanged`, `InsertLeave` and `BufWritePost` for `*.blade.php`.
- **Requirements.** Neovim 0.11+ (local: 0.12.6) and blink.cmp v1. An nvim-cmp source is optional.
- **Tests.** Headless Neovim with `mini.test` or busted/plenary. Use fixture Blade and PHP files for context detection, member extraction and diagnostics.
- **Installation.** A lazy.nvim spec in the README, plus the blink.cmp `sources.providers` snippet.

## Livewire 4 directive list

The directive names and modifiers below are **only a starting point**. The final table must be built and checked against the Livewire 4 docs and the installed bundle (`vendor/livewire/livewire/dist/livewire.esm.js`, v4.4.8 locally).

**Directives found in the v4.4.8 JS bundle or the docs:**
`wire:model`, `wire:click` and any other `wire:<event>`, `wire:submit`, `wire:loading`, `wire:target`, `wire:dirty`, `wire:poll`, `wire:init`, `wire:intersect`, `wire:navigate`, `wire:current`, `wire:confirm`, `wire:offline`, `wire:ignore`, `wire:replace`, `wire:cloak`, `wire:transition`, `wire:show`, `wire:text`, `wire:bind`, `wire:ref`, `wire:stream`, `wire:sort`, `wire:key`, `wire:island`.

**Internal attributes that are never typed by hand, and must not be suggested or flagged:**
`wire:id`, `wire:name`, `wire:snapshot`, `wire:effects`.

**`wire:model` modifiers (from the v4 docs):**
`live`, `blur`, `change`, `enter`, `lazy` (v3 compatibility), `debounce.Xms`, `throttle.Xms`, `number`, `boolean`, `fill`, `deep`, `renderless`, `preserve-scroll`.

**Event modifiers (`wire:click` and similar):**
These are not yet mapped to directives. Names found in the bundle include `prevent`, `stop`, `self`, `once`, `window`, `document`, `outside`, `passive`, `debounce`, `throttle`, `async`, `renderless` and `preserve-scroll`.

## Decisions (2026-10-26)

- **Scope:** a standalone plugin in this repo, loaded via lazy.nvim `dir = "~/Projects/livewire.nvim"` while developing, and published on GitHub later. Write the README and config for other users from the start.
- **Versions:** support both Livewire 3 and 4.
  - Detect the version from the project's `composer.lock`, with a config override.
  - Directive and modifier data needs version info. For example, v3's `wire:model.defer` and `.lazy` differ from v4, and some directives are v4-only, such as `wire:show`, `wire:text`, `wire:ref` and `wire:island`.
- **Go-to-definition:** move it into the plugin as part of the work, rather than leaving it in `components.lua`.
- **Severity:** unknown directives and modifiers are reported as **warnings**.
- **Custom directives:** a project can define its own `wire:` directives in JavaScript with `Livewire.directive('name', …)`. The plugin handles them two ways, and treats both as known:
  - **Detection:** scan the project's JS (e.g. `resources/js/**`) for `Livewire.directive('…'`.
  - **Config:** a `custom_directives = { "tooltip" }` option, added to whatever detection finds. This covers what the scan misses, such as directives defined by a package.

  Custom directives are offered in completion too, and are never flagged as unknown. Their modifiers aren't checked, since the plugin can't know them.

## Sources

- [laravel/lsp on GitHub](https://github.com/laravel/lsp)
- [Laravel News: Laravel LSP announced at Laracon US 2026](https://laravel-news.com/laravel-lsp-a-first-party-language-server-announced-at-laracon-us-2026)
- [Laravel LSP in Neovim: Setup and What It Skips](https://www.nihardaily.com/posts/laravel-lsp-in-neovim-setup-and-what-it-skips)
- [lali-components.nvim](https://github.com/RicardoRamirezR/lali-components.nvim)
- [Laravel News: Neovim Laravel Livewire plugin](https://laravel-news.com/neovim-laravel-livewire-plugin)
- [coc-laravel](https://socket.dev/npm/package/@yaegassy/coc-laravel)
- [blink.cmp](https://github.com/saghen/blink.cmp)
- [Livewire 4 docs: wire:model](https://livewire.laravel.com/docs/4.x/wire-model)
