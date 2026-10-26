## 1. Plugin skeleton and test harness

- [x] 1.1 Create `lua/livewire/{init,config,util}.lua` with `setup(opts)` merging the config defaults from design.md; verify `nvim --headless -c 'lua require("livewire").setup({})' -c q` exits cleanly
- [x] 1.2 Add `tests/minimal_init.lua` (clones mini.nvim into git-ignored `.tests/`, adds this repo and `stdpath("data")/site` to rtp), a `Makefile` `test` target, and `.tests/` in `.gitignore`; verify `make test` runs and reports 0 tests without error
- [x] 1.3 Add a test helper that skips a case with a message when the `blade` parser is missing; verify by temporarily hiding the parser path and seeing the skip message

## 2. Directive catalog data

- [x] 2.1 Write `scripts/bundle-directives.sh` that greps a `livewire.esm.js` for Livewire `directive("…")` registrations (excluding `Alpine*.directive`), `wire:` attribute literals, colon sub-names and `modifiers.includes(...)` by section; verify running it on `~/Lerd/livewire/vendor/livewire/livewire/dist/livewire.esm.js` lists confirm, dirty, loading, model, poll, sort:item …
- [x] 2.2 Write `lua/livewire/catalog/events.lua`: DOM event names, the curated common-event list, shared event modifiers (prevent, stop, self, once, window, document, outside, passive, capture, debounce, throttle, async, renderless, preserve-scroll, prepend, append), and the key-name list; verify a unit test that `mouseenter` is an event and `keydown` is a keyboard event
- [x] 2.3 Write the Livewire 4 entries in `lua/livewire/catalog/directives.lua` (descriptions, 4.x docs paths, modifiers with argument kinds, sub-names, `poll` bare duration), checked against the 2.1 script output and the 4.x docs; add a provenance header; verify every Livewire directive from the 2.1 output has an entry and none of the Alpine-only names (anchor, collapse, mask, trap, resize) do
- [x] 2.4 Add Livewire 3 entries and version ranges from the 3.x docs and the latest v3 tag's `dist/livewire.esm.js` (e.g. `model.defer`/`lazy` v3, `show`/`text`/`ref`/`island` v4-only); verify unit tests for the version scenarios in `specs/directive-catalog/spec.md`
- [x] 2.5 Implement `lua/livewire/catalog/init.lua` query API (directive list per version, lookup with "other version" result, modifier-chain check returning per-segment status, internal-attribute set); verify unit tests for the modifier-argument, event, key-modifier and internal-attribute scenarios
- [x] 2.6 Implement Damerau–Levenshtein suggestion in `util.lua` with the length-based threshold; verify unit tests: `modle`→`model`, `lve`→`live`, `itme`→`item`, `xyzzy`→none

## 3. Project detection

- [x] 3.1 Implement root and version detection in `lua/livewire/project.lua` (composer.lock `packages`/`packages-dev`, major parsing incl. `4.x-dev`, override, default 4, mtime-validated cache); verify tests with v3 and v4 lock fixtures, an override, a missing lock file, and a touched lock file being re-read
- [x] 3.2 Implement the custom directive scan (`scan_paths` globs, skip `node_modules`, 1 MB cap, single/double quotes) merged with `custom_directives`; verify with a fixture `resources/js/app.js` defining `tooltip` plus a config entry
- [x] 3.3 Add the `BufWritePost` JS/TS invalidation that re-scans and fires a `User LivewireProjectChanged` event when the set changes; verify a test that writes a new `Livewire.directive('flash'…)` and sees `flash` become known

## 4. Cursor context detection

- [x] 4.1 Implement token extraction and splitting in `lua/livewire/context.lua` (directive / sub-name / modifier / argument, partial segment and its start column); verify unit tests for `wire:`, `wire:mo`, `wire:sort:`, `wire:model.live.`, `wire:model.live.debounce.`, `wire:keydown.`
- [x] 4.2 Add the tree-sitter position check (incremental parse of the cursor row, `attribute_name` ancestor or start-tag in error state) and the no-parser line fallback; verify fixture tests: multi-line `<x-input`, `<livewire:counter`, and returns nil in text content, attribute values and `{{ }}`

## 5. blink.cmp source

- [x] 5.1 Implement `lua/livewire/blink.lua` (`new`, `enabled` for filetype `blade`, trigger chars `:`/`.`, `get_completions` building items with textEdit ranges, kinds and markdown docs for directives, sub-names, modifiers, argument examples and custom directives); verify integration tests covering every scenario in `specs/directive-completion/spec.md` by calling `get_completions` with a constructed context
- [x] 5.2 Manually verify in LazyVim with `dir = "~/Projects/livewire.nvim"` in `~/Lerd/livewire`: typing `wire:`, `wire:model.`, `wire:click.` shows items with docs, and accepting `model` after `wire:mo` gives `wire:model`

## 6. Diagnostics

- [x] 6.1 Implement the scan in `lua/livewire/diagnostics.lua` (`(attribute_name)` query on the root blade tree, `wire.` / unknown directive / other-version / unknown sub-name / unknown modifier messages with segment ranges, WARN, source `livewire`); verify fixture tests covering every scenario in `specs/directive-diagnostics/spec.md` except refresh
- [x] 6.2 Wire up the autocmds (BufReadPost, normal-mode TextChanged, InsertLeave, BufWritePost) with a 150 ms per-buffer debounce, re-scan on `LivewireProjectChanged`, honour `diagnostics = false`, and no-op without the parser; verify tests for fix-clears-warning, disabled-by-config and parser-missing, and that typing in insert mode triggers no scan
- [x] 6.3 Manually verify in `~/Lerd/livewire`: `wire.model.fill`, `wire:modle` and `wire:model.lve` show warnings with suggestions, and a valid view shows none

## 7. Health check and documentation

- [x] 7.1 Implement `lua/livewire/health.lua` (Neovim version, blade parser, blink.cmp, project version and source, custom directives); verify `:checkhealth livewire` output in `~/Lerd/livewire` and with the parser hidden
- [x] 7.2 Rewrite `README.md`: features, requirements, lazy.nvim spec, blink.cmp `sources.providers` + `per_filetype.blade` snippet with `score_offset`, config options (including custom event names in `custom_directives`), and a "not yet" list (member completion, go-to-definition); verify the snippets by pasting them into the LazyVim config and repeating 5.2
- [x] 7.3 Run `make test` and confirm the full suite passes
