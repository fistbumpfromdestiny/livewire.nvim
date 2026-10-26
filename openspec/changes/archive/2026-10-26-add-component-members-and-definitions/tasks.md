## 1. Foundations

- [x] 1.1 Add `definition = { enabled = true, blade_components = true }` to `config.lua`, with a one-level merge for the `definition` table. Verify with a `test_config` case: `setup({ definition = { blade_components = false } })` keeps `enabled = true`, and `custom_directives` still replaces rather than merges.
- [x] 1.2 Add the `tests/fixtures/app/` Livewire 4 project described in design §9, plus a `has_php` / `skip_without_php` helper. Verify that `test_harness` lists the fixture files and that the php skip works with `LIVEWIRE_TEST_NO_SITE=1`.
- [x] 1.3 Clone nvim-cmp into `.tests/` from `tests/minimal_init.lua`, the same way as mini.nvim. Verify that `make test` on a clean `.tests/` fetches it and `require("cmp")` succeeds in a test.

## 2. Directive catalog value kinds

- [x] 2.1 Add a `value` field to every directive in `catalog/directives.lua`, with sub-name overrides for `sort`, and `catalog.value_kind(resolved, sub)` returning `action` for events and unknown names and `none` for custom directives. Verify with `test_catalog` cases for model, click, keydown, target, show, key, `sort` vs `sort:item`, and a custom directive.
- [x] 2.2 Add versioned `magic_actions` and `wire_magics` lists, with descriptions and a provenance comment, to the catalog. Add a `$`-name section to `scripts/bundle-directives.sh`. Verify with `test_directives_data` checking that every listed v4 magic name appears in the bundle when `LIVEWIRE_V4_BUNDLE` is set.

## 3. Component resolution

- [x] 3.1 Port `read_config`, the PSR-4 map and `class_to_file` into `lua/livewire/components.lua`, cached per root by mtime. Verify with `test_components`: config paths are read from the fixture's `config/livewire.php`, defaults are used without it, and a PSR-4 FQCN resolves through `autoload_psr4.php` and through `composer.json` when that file is missing.
- [x] 3.2 Port tag resolution for `<livewire:…>`, `@livewire(…)`, `<flux:…>` and `<x-…>`, honouring `definition.blade_components` and skipping slot and dynamic-component tags. Verify with a test for each scenario in the component-resolution spec's two tag-resolution requirements.
- [x] 3.3 Port owner resolution: single-file, multi-file, class by convention, then class by `view('…')` search, with a per-view cache cleared on class-path PHP writes. Verify with tests for the class view, the single-file component, the multi-file component, a plain Blade view (no owner), and the cache clearing after `project.on_write`.

## 4. Member index

- [x] 4.1 Implement `lua/livewire/members.lua` file parsing with the tree-sitter `php` parser. It covers the namespace, imports with aliases, the class or anonymous class, base class, traits, properties (multi-element, static, type) and methods (visibility, static, signature, position), cached by mtime or by changedtick for loaded buffers. Verify with `test_members` against fixture classes, including a commented-out method that must be absent.
- [x] 4.2 Implement `members.index(owner)`, merging traits and parents through PSR-4. It stops at `Livewire\Component`, `Livewire\Volt\Component` and `Livewire\Form`, and sets `complete = false` on an unresolved type or a `__call`. Verify with tests for the trait and parent scenario, the base-class exclusion, an unresolvable parent (incomplete) and an unsaved buffer edit.
- [x] 4.3 Add Form object detection (`form_class` on properties whose type chain reaches `Livewire\Form`) and a callable-method filter that excludes `render`, static methods and the lifecycle hooks, including `mount<Trait>`/`boot<Trait>`/`booted<Trait>`. Verify with tests for `form.title`, `mount`, `updatedName`, `bootHasSearch` and a public static method.

## 5. Value context

- [x] 5.1 Implement `lua/livewire/value_context.lua`: the tree-sitter path (`attribute_value` inside a `wire:` attribute, with directive, sub-name and cursor offset), the line fallback without a parser, and `$wire.` detection. Verify with `test_value_context` cases for `wire:model.live="form.|"`, `wire:click="sa|"`, `wire:click="$toggle('|"`, `wire:target="save, |"`, `x-on:click="$wire.|"`, a multi-line tag, and a non-wire attribute (nil).

## 6. Completion

- [x] 6.1 Extend `source.items` with value and `$wire` items (properties, Form properties, callable methods, magic actions, targets, `$wire` magics), with kinds, sort order and declaration documentation. Add `" ' (` as trigger characters. Verify with `test_blink` cases for every scenario in the member-completion spec, plus a check that the existing directive tests still pass.
- [x] 6.2 Implement `lua/livewire/cmp.lua` and auto-register it in `setup()` when nvim-cmp is loaded. Verify with a test that uses the cloned nvim-cmp: register, call the source's `complete` at `<input wire:mo` and in `wire:model="`, and compare labels with `source.items`.

## 7. Go-to-definition

- [x] 7.1 Implement `lua/livewire/definition.lua`, mapping a cursor position to a component file or a member location (tags, `wire:model`, actions, targets, `$set`/`$toggle` arguments, `$wire.member`, `form.field`). Verify with `test_definition` covering every scenario in the definition spec's component and member requirements, called directly.
- [x] 7.2 Implement the in-process server in `lua/livewire/lsp.lua` and start it from `init.lua` on `FileType blade` (respecting `definition.enabled`, one client per root, restart on re-`setup()`). Verify with a test that opens a fixture view, checks a `livewire` client with `definitionProvider` is attached, gets the `Greeter.php` location from `vim.lsp.buf_request_sync(…, "textDocument/definition", …)`, and finds no client when the option is disabled.

## 8. Member diagnostics

- [x] 8.1 Add property and action checks to `diagnostics.refresh` (owner and index resolved once per refresh, checks only when the index is complete, simple values only, messages with suggestions). Verify with `test_diagnostics` cases for every scenario in the member-diagnostics spec's first three requirements, using a fixture view with known problems and an exact expected list.
- [x] 8.2 Make `project.on_write` fire `LivewireProjectChanged` for PHP files the member cache has seen. Verify with the "method added to the class" scenario: write the fixture class through a buffer and confirm the warning clears in the open view.
- [x] 8.3 Run the diagnostics over every view in `~/Lerd/livewire` (read-only, unsaved buffers). Verify there are zero member warnings, or that each one is a confirmed real problem, and record the result in the apply summary.

## 9. Health, docs, finish

- [x] 9.1 Extend `:checkhealth livewire` with the `php` parser (a warning when it's missing), nvim-cmp detection, the definition server state, and the current buffer's owning component and index completeness. Verify by running it headlessly on the fixture view and on a plain Blade view.
- [x] 9.2 Update the README: drop "Not yet" and add go-to-definition, member completion and warnings, nvim-cmp setup, the `definition` options, the duplicate-`gd` note and migrating from a custom `gd` mapping. Update the requirements (`php` parser). Verify the nvim-cmp and lazy snippets by loading them in a headless minimal config.
- [x] 9.3 Probe the real setup headlessly with the author's LazyVim config on `~/Lerd/livewire` (`dir =` the checkout, unsaved buffers): `gd` targets on `greeter.blade.php` and `⚡profile.blade.php`, member completion, and how Snacks handles duplicate definitions. Verify the results are recorded in the apply summary, and that the full `make test` passes with and without the parsers.
