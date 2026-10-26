## Context

The plugin already has:
- a directive catalog
- a cursor context parser for attribute *names* (`context.lua`), using tree-sitter with a single-line fallback
- a blink.cmp source
- debounced diagnostics using the `livewire` namespace
- a per-root project cache (`project.lua`: version, custom directives, re-scan on write)

What this change needs to absorb lives in `~/.config/nvim/lua/config/components.lua` (358 lines, working in the author's setup):
- tag-to-file resolution for Livewire, Blade and Flux
- reading `config/livewire.php`
- finding the owner of a view
- PSR-4 resolution, from `autoload_psr4.php` with a `composer.json` fallback
- following parent classes and traits
- finding a member with Lua patterns

Facts verified in Livewire 4.4.8 (`vendor/livewire/livewire/src`):
- **Callable methods:** `HandleComponents::callMethods` only allows `Utils::getPublicMethodsDefinedBySubClass`, meaning public, non-static methods whose declaring class isn't `Livewire\Component` or `Livewire\Volt\Component`, minus `render`. Methods from traits that `Livewire\Component` itself uses count as declared by `Livewire\Component`, so they're excluded too.
- **Settable properties:** `updateProperty` only allows `getPublicPropertiesDefinedOnSubclass`, with the same rule for public, non-static properties.
- **Lifecycle hooks:** `SupportLifecycleHooks::call` blocks `mount`, `boot`, `booted`, `exception`, `hydrate*`, `dehydrate*`, `updating*`, `updated*`, `rendering`, `rendered`, `scriptSrc`, plus `mount<Trait>`, `boot<Trait>` and `booted<Trait>`.
- **Magic actions:**
  - server side (`SupportMagicActions`): `$refresh`, `$set`, `$sync`, `$commit`
  - client side (`livewire.esm.js`): `$parent`, `$dispatch*`, `$toggle`, `$js`, `$get`, `$watch`, `$on`, `$el`, `$id`, `$upload*`, `$refs`, `$errors`, `$dirty`, `$island`, `$intercept`
- **Blade tree:**
  - `wire:model.live="form.title"` parses as `attribute` → `attribute_name` + `quoted_attribute_value` → `attribute_value`, with exact byte ranges
  - Alpine attribute values are injected `javascript`
  - a single-file component's PHP block is a `php_statement` with injected `php_only`
- **In-process LSP:** `vim.lsp.start({ cmd = function(dispatchers) … end })` with a Lua table client answers `textDocument/definition` on Neovim 0.12.6. `cmd` as a function is supported since 0.10.

## Goals / Non-Goals

**Goals:**
- One resolution and indexing layer that definition, completion and diagnostics share, so the three can never disagree about what a member is.
- Warnings with no false positives: when anything in the chain is unknown, stay silent.
- Behave as `components.lua` does today for every case it handles, so the author can delete it.

**Non-Goals:**
- Completing component *names* after `<livewire:` / `<x-` (laravel/lsp does this).
- Volt's functional API (`state([...])`, `$save = fn …`). Such views have no owner, so they get no member features.
- Checking `$wire.member`, `wire:show`/`wire:text` expressions, magic action names, or nested property paths beyond the first segment.
- `#[Computed]` properties as `wire:model` targets. They're methods, and Livewire can't bind them.
- Hover, references or rename through the LSP server.
- Resolving a view's owner when it's rendered from a non-Livewire controller or included as a partial.

## Decisions

### 1. Go-to-definition through an in-process LSP server
`lua/livewire/lsp.lua` builds a `cmd` function returning a table client (`request`, `notify`, `is_closing`, `terminate`) that answers:
- `initialize`, advertising only `definitionProvider`
- `textDocument/definition`
- `shutdown`

`init.lua` calls `vim.lsp.start({ name = "livewire", cmd = …, root_dir = project.root(buf) }, { bufnr = buf })` on `FileType blade`. `vim.lsp.start` reuses a client per name and root.

The handler reads the buffer through `vim.uri_to_bufnr`, so unsaved text is used. It returns `Location[]`, which is empty when nothing applies.

- *Why:* every existing `gd` (LazyVim → Snacks `lsp_definitions`, Telescope, `vim.lsp.buf.definition`) merges all servers' answers with no keymap setup. This was the user's choice.
- *Alternative:* a Lua `definition()` returning false for a fallback keymap. Rejected as the primary path, though the same resolver functions stay internal and could be exposed later.
- *Note:* the server never sends diagnostics or completion. Those keep their existing paths, which avoids duplicate items when an LSP completion source is also active.

### 2. Port `components.lua` as `lua/livewire/components.lua`, cached per root
The port keeps the same candidate order and the same functions:
- `read_config`, mtime-cached per root
- `livewire_candidates`, `blade_candidates`, `flux_candidates`
- `owner_file`
- `psr4_map`, cached per root, invalidated when `composer.json` or `vendor/composer/autoload_psr4.php` changes mtime
- `class_to_file`

Owners found by searching the class path for the view name are cached per view path. That cache is cleared when a PHP file under the class path is written, via the existing `project.on_write`.

- *Why:* proven against the author's real projects. Keeping the order means `gd` behaves exactly as before.
- *Change from the original:* the root marker uses `project.root` (`composer.lock`/`composer.json`/`artisan`) instead of only `artisan`, to stay consistent with the rest of the plugin.

### 3. Member index with the tree-sitter `php` parser instead of Lua patterns
`lua/livewire/members.lua` parses source text with `vim.treesitter.get_string_parser(text, "php")`.
- **Class files:** the whole file.
- **Single-file components:** the text from the start through the first `?>`, which is valid PHP.

It walks:
- `namespace_definition`
- `namespace_use_declaration` (imports and aliases)
- the first `class_declaration`, or `object_creation_expression` → anonymous class, along with its `base_clause`
- `use_declaration` (traits)
- `property_declaration` (each `property_element`, with visibility, `static` and type)
- `method_declaration` (visibility, `static`, the parameter text for the signature)

Each file's result is cached by `(path, mtime)`, or by `(bufnr, changedtick)` when the file is loaded in a modified buffer.

`index(owner)` merges the file's members with its traits (first) and parent (after), following PHP's resolution order. It recurses through PSR-4 with a `seen` set, and stops at the FQCNs `Livewire\Component`, `Livewire\Volt\Component` and `Livewire\Form` without opening them. Any type that can't be resolved sets `complete = false`.

- *Why tree-sitter over the patterns in `components.lua`:* commented-out methods, multi-property declarations (`public $a, $b;`), attributes and multi-line signatures matter now. A *missing* member becomes a warning, so the index has to be right. The `php` parser comes with LazyVim's `lang.php` extra, and blade injection already needs `php_only`.
- *Fallback:* without the `php` parser, member features are off and `:checkhealth` says so. Patterns are not kept as a second implementation.
- *Form objects:* a property whose type name resolves (through imports and PSR-4) to a class whose chain reaches `Livewire\Form` gets `form_class`. Completing and resolving `form.x` uses that class's index.

### 4. Value context: tree-sitter first, line fallback
`lua/livewire/value_context.lua` returns one of:
- `{ kind = "value", directive, sub, value, value_start, cursor_offset }` when the cursor is inside the `attribute_value` of a `wire:` attribute
- `{ kind = "wire", partial, start_col }` after `$wire.`

The `wire:` attribute is found by walking up to the `attribute`, reading its `attribute_name` with the existing `catalog.parse`, and taking the `attribute_value` range. When there's no parser, it falls back to a line pattern `wire:[%w%-:%.]+%s*=%s*["']` before the cursor with no closing quote. `$wire.` uses a line pattern anywhere, since it lives in injected JavaScript, `<script>` blocks and `@script`.

Within a value, the value kind decides what's being typed:
- `property`: the path segment under the cursor
- `action`:
  - the name at the value start, or right after `$` for magic actions
  - inside `$set('` / `$toggle('`, a property
- `targets`: the comma-separated entry under the cursor
- `expression`: an identifier under the cursor, offering properties and methods (no diagnostics)

### 5. Value kinds in the catalog
`directives.lua` gains a `value` field per directive, with an optional per-sub-name override (`sort` = action, `sort:item`/`sort:handle`/`sort:group`/`sort:group-id` = none, `sort:config` = expression). `catalog.value_kind(resolved, sub)` returns:
- `"action"` for kind `event` and kind `unknown` (Livewire forwards unknown names as events)
- `"none"` for custom directives

### 6. Member diagnostics inside the existing refresh
`diagnostics.refresh` already visits every `attribute_name`. For `wire:` names whose value kind is `property` or `action`, it reads the sibling `attribute_value` and checks it. Before checking any attribute it resolves the owner and index once per refresh, and skips member checks unless `owner and index.complete`.

- **Action values** are checked only when they match `^%s*([%a_][%w_]*)%s*(%b())?%s*$`, a single call.
- **Property values** are checked only when they match `^%s*([%a_][%w_]*)[%w_%.]*%s*$`.

Suggestions reuse `util.suggest` against the public properties, or the callable methods.

To re-check when a component changes, `project.on_write` also fires `LivewireProjectChanged` when the written path is a `.php` file inside the root that the member cache has seen. That event already re-schedules every attached Blade buffer of the root. A single-file component re-checks on its own `TextChanged`/`InsertLeave`.

### 7. Completion: one item builder, two adapters
`blink.lua`'s item building moves into the shared `source.items(buf, row, col)`, which now also covers value and `$wire` contexts.
- **Ranking:** member items use `Kind.Field` (properties), `Kind.Method` (methods) and `Kind.Function` (magic actions), with `sortText` putting members before magic actions.
- **nvim-cmp:** `lua/livewire/cmp.lua` adapts `source.items` to nvim-cmp's interface (`is_available`, `get_trigger_characters`, `complete(params, callback)` with `params.context.cursor`, `get_debug_name`). nvim-cmp understands LSP `textEdit` items directly.
- **Registration:** `setup()` runs `pcall(require, "cmp")` and calls `cmp.register_source("livewire", …)` when it's available. A `plugin/` guard isn't needed, because lazy-loading on `ft = "blade"` runs `setup()` before any Blade completion.
- **Trigger characters** become `: . " ' (`. When the cursor isn't in a value context, a `"` or `(` trigger yields nothing, so it costs little.

### 8. Config additions
```lua
definition = { enabled = true, blade_components = true }
```
Users override it with a nested table, so `config.set` gets a one-level merge for the `definition` table only. Lists still replace rather than merge, which was the reason for the shallow `tbl_extend`.

### 9. Tests
New fixtures under `tests/fixtures/app/` (a Livewire 4 project):
- `app/Livewire/Greeter.php`, with a trait and a base class
- `app/Livewire/Forms/PostForm.php`
- `app/Concerns/HasSearch.php`
- `resources/views/livewire/greeter.blade.php`
- a single-file component `resources/views/pages/⚡profile.blade.php`
- a multi-file component `resources/views/components/⚡counter/counter.{php,blade.php}`
- `resources/views/flux/navlist/group.blade.php`
- `resources/views/components/app-logo.blade.php`
- `config/livewire.php`
- `vendor/composer/autoload_psr4.php`
- `composer.json`

Tests that need the `php` parser skip without it, like the existing `blade` skips. nvim-cmp is cloned into `.tests/` alongside mini.nvim for a real adapter test. The LSP server is tested through `vim.lsp.buf_request_sync`.

## Risks / Trade-offs

- **[Two servers answer `gd` for the same tag]** laravel_ls or laravel/lsp may also resolve `<x-…>` or `<livewire:…>`, so Snacks shows a picker with duplicate entries. → `definition.blade_components = false` covers `<x-…>`. The README documents the duplicate case. Checked during apply: in the author's setup, laravel_ls and intelephense returned nothing for any of the probed tags, members or `$wire` positions, so `gd` jumps directly. Snacks `lsp_definitions` doesn't set `unique_lines`, so it would show a two-entry picker if another server ever answered the same spot.
- **[False "not found" warnings]** A member added by a mechanism the index doesn't see would be flagged. Examples: `__call` magic, a trait applied to a parent outside PSR-4, `#[Js]` or another attribute-based method. → Warnings require a complete chain. `__call` anywhere in the chain marks the index incomplete. Only simple values are checked.
- **[Owner search cost]** Finding a class by its `view('…')` string reads every PHP file under the class path. → Convention is tried first, results are cached per view, and the search runs at most once per view until a class-path PHP file is written.
- **[`php` parser missing]** Member features silently do nothing. → `:checkhealth livewire` reports it, and the README lists it under requirements.
- **[In-process server lifecycle]** The client must stop cleanly when Neovim quits, and when `setup()` runs again. → `terminate` marks the client closed. `setup()` stops existing `livewire` clients before attaching again.
- **[Version drift in magic names]** The magic action and `$wire` property lists are hand-maintained. → They live in the catalog with versions and provenance comments, like directives. `scripts/bundle-directives.sh` gets a section listing `$`-names from the bundle.

## Migration Plan

1. Ship the release. The plugin's go-to-definition answers alongside other servers.
2. The author removes `~/.config/nvim/lua/config/components.lua` and the custom `gd` key in `lua/plugins/laravel.lua`, so LazyVim's default `gd` handles it (outside this repo).
3. Rollback: `definition = { enabled = false }`, or pin the previous commit.
