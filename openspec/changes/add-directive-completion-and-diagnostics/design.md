## Context

The repo has no code yet. See proposal.md for the motivation and specs/ for the required behavior. The design rests on these findings from the local environment:

- **Tree-sitter `blade`** (installed) parses every attribute into `attribute` → `attribute_name` (+ `quoted_attribute_value`). This covers multi-line start tags, `<x-…>` and `<livewire:…>` tags, and tags inside `@if` blocks. It also produces `attribute_name` nodes for incomplete input such as `wire:` or `wire:model.` with no value. Attribute values and `{{ }}` echoes are separate injected trees (`javascript`, `php_only`), and prose is a `text` node. So querying `(attribute_name)` on the root `blade` tree alone already excludes everything the spec says not to check.
- **Livewire 4.4.8 runtime (`dist/livewire.esm.js`)** splits `wire:<value>.<mod>.<mod>` on `.` (`extractDirective`). Any `value` that isn't handled elsewhere and isn't a registered custom directive is forwarded to Alpine as `x-on:<value>` (`js/directives/wire-wildcard.js`). That is why "unknown directive" has to mean "not a directive, not a DOM event, not custom". Duration arguments arrive as their own modifier segments (`debounce`, `500ms`).
- **Livewire-registered directives in 4.4.8:** confirm, dirty, ignore, init, loading, model, offline, poll, replace, plus navigate, intersect, sort, show, text, bind, current, transition, cloak, ref, stream, island, key, and the event wildcard. Some `directive("…")` hits in the bundle are Alpine plugins (anchor, collapse, mask, trap, resize) and are **not** `wire:` directives. Colon sub-names exist for `sort` (`item`, `group`, `group-id`, `ignore`, `config`). `PRD-wire-model-modifiers.md` in the package confirms the v4 `wire:model` layering (`blur`/`change`/`enter` before `.live`, network modifiers after).
- **blink.cmp v1.10.2** source interface: `new`, `enabled`, `get_trigger_characters`, `get_completions(ctx, callback)`, optional `resolve`. Its default keyword pattern stops at `:` and `.`, so the fuzzy-match keyword is just the partial directive or modifier name.
- **`components.lua`** finds the project with `vim.fs.root(0, "artisan")`. This change doesn't touch component resolution.

## Goals / Non-Goals

**Goals:**
- One catalog module that both completion and diagnostics query, so they can never disagree.
- Diagnostics that cost nothing in insert mode and stay quiet on anything that isn't a `wire` attribute name.
- Code layout that the later member-completion and go-to-definition slices extend without restructuring. `project.lua` becomes their home for root and config lookup.

**Non-Goals:**
- Validating modifier *order* (for example `.live` placement for `wire:model`). Membership only.
- Validating attribute values. Anything inside `="…"` is out of scope.
- An nvim-cmp source, CI setup, and installing the `blade` parser for the user.

## Decisions

### Module layout
```
lua/livewire/
  init.lua          setup(opts): merge config, create autocmds
  config.lua        defaults + merged options
  catalog/
    init.lua        query API: directives(version, root), lookup(name, version, root), check_modifiers(...)
    directives.lua  pure data: directives, modifiers, versions, docs paths
    events.lua      DOM event names, event modifiers, key names, curated "common" events
  project.lua       root, Livewire version, custom directives (cached per root)
  context.lua       cursor → { kind = "directive"|"subname"|"modifier"|"argument", ... } or nil
  blink.lua         blink.cmp source (require path "livewire.blink")
  diagnostics.lua   namespace, buffer scan, debounce
  health.lua        :checkhealth livewire
  util.lua          edit distance, tree-sitter helpers
```
Users register blink with `module = "livewire.blink"`. *Alternative:* a separate `blink-cmp-livewire` repo. Rejected because it's more to install, and later slices will share the project/catalog code anyway.

### Catalog data model
Each directive is a table: `{ name, desc, docs = { [3] = "wire-model", [4] = "wire-model" }, versions = {3,4}, modifiers = { {name="live", versions={3,4}, desc=…}, {name="debounce", arg="duration", optional_arg=true}, … }, subnames = {...}, bare_arg = "duration" | nil, event_modifiers = true | nil }`. Modifier sets that several directives share (event modifiers, `class`/`attr`/`remove` for loading/dirty/offline) are defined once and referenced. Argument kinds are a small fixed set checked by Lua patterns: `duration` (`^%d+m?s$`), `number`, `length` (`^%d+px$`, `%`), and an `enum` list (for example `loading.delay` → `shortest … longest`). Docs URLs are built as `https://livewire.laravel.com/docs/<v>.x/<path>`.

The data is hand-written Lua, with a provenance header saying which bundle version and doc pages it was checked against. *Alternative:* parse the installed bundle at runtime. Rejected: the bundle gives names but no descriptions or argument shapes, mixes in Alpine directives, and wouldn't work for users whose `vendor/` is missing.

Livewire 3 data is sourced from the 3.x docs and the v3 `dist/livewire.esm.js` at the latest v3 tag, since no v3 project is available locally.

### Context detection: line text for the token, tree-sitter for position
`context.lua` reads backwards from the cursor on the current line over `[%w_%-:%.]` to get the token (for example `wire:model.live.deb`). If it starts with `wire:`, the token is split into directive, sub-name, modifiers, and the partial segment under the cursor. Tree-sitter then confirms the position: after `parser:parse({row, row+1})`, the node at the token start must be, or be inside, an `attribute_name`. If the parse is in an error state, a `start_tag`/`self_closing_tag` ancestor is accepted instead. Without a parser, the fallback accepts the token only if the text before it on the line has an unclosed `<tag` and the token isn't preceded by `="`. That means attributes on later lines of a multi-line tag aren't completed without a parser, which is acceptable.

*Alternative:* tree-sitter only. Rejected because mid-keystroke trees can lag behind the buffer, and the token text is all we need. *Alternative:* line patterns only. Rejected because it can't tell an attribute name from prose or a value, and fails on multi-line tags.

### Completion items
Each item has a `textEdit` whose range spans from the start of the partial segment to the cursor, so accepting `model` after `wire:mo` replaces only `mo`. Documentation (description, plus a docs link for directives, plus a "custom directive" label for custom ones) is markdown attached directly to the item, so no `resolve` is needed. Kinds: `Keyword` for directives and events, `EnumMember` for modifiers and sub-names, `Value` for argument examples. Modifiers already used in the chain are filtered out. After an argument-taking modifier, only its example values are offered (`250ms`, `500ms`, `1000ms` for `debounce`/`throttle`, which only parse milliseconds; the enum members for enums). For `keydown`/`keyup`/`keypress`, a curated key list (`enter`, `escape`, `space`, `tab`, `up`/`down`/`left`/`right`, `arrow-*`, `shift`, `ctrl`, `alt`, `meta`, `cmd`) is offered alongside the event modifiers.

### Diagnostics pipeline
On `FileType blade`, `diagnostics.lua` attaches buffer-local autocmds: `BufReadPost`, `BufWritePost`, `InsertLeave`, and `TextChanged` (normal mode only, so insert-mode typing never triggers a scan). Each one schedules a scan through a per-buffer 150 ms `vim.uv` timer. A scan parses the `blade` tree, runs the query `(attribute_name) @name`, skips names that don't start with `wire.` or `wire:`, and checks each with the catalog. Results go to `vim.diagnostic.set(ns, buf, …)` with `severity = WARN` and `source = "livewire"`. Segment ranges are computed from byte offsets within the node's text, which is always on a single line.

Suggestions use Damerau–Levenshtein distance, with a threshold of 1 for names up to 4 characters and 2 above that. Candidates are the version's directives and all event names, or the directive's allowed modifiers. When a name exists only in another version, the message says so (`wire:ref requires Livewire 4`) instead of suggesting a spelling.

### Project detection and caching
`project.lua` resolves the root with `vim.fs.root(buf, { "composer.lock", "composer.json", "artisan" })`. It caches `{ version, version_source, lock_mtime, custom = set, custom_scanned }` per root. Version is decoded from `composer.lock` (`packages` and `packages-dev`, `livewire/livewire`), taking the major from `^v?(%d+)` or `(%d+)%.x`. The cached version is re-validated against the lock file's `fs_stat` mtime on access, which is cheap. Precedence: `config.livewire_version` > lock file > default `4`.

Custom directives: on first use for a root, walk the `scan_paths` globs (matched with `vim.glob.to_lpeg`, skipping `node_modules`, and capping files at 1 MB) and collect matches of `Livewire%.directive%(%s*["']([%w_%-]+)["']`. Then add `config.custom_directives`. A `BufWritePost` autocmd on JS/TS files under a cached root marks it dirty and re-scans open Blade buffers of that root once the set changes.

### Configuration
```lua
require("livewire").setup({
  livewire_version = nil,          -- 3 | 4 | nil (detect)
  custom_directives = {},          -- extra names treated as known (also custom event names)
  scan_paths = { "resources/js/**/*.js", "resources/js/**/*.ts" },
  diagnostics = true,
})
```
The blink source reads the same config, and works with the defaults if `setup` was never called. Diagnostics need `setup()` (lazy.nvim's `opts = {}` calls it).

### Tests
Use `mini.test`, run by `make test` → `nvim --headless -u tests/minimal_init.lua`. The init clones `mini.nvim` into a git-ignored `.tests/` folder and adds the user's `stdpath("data")/site` to `runtimepath`, so the installed `blade` parser is found. Cases that need the parser skip with a message when it's missing. Fixtures live under `tests/fixtures/`: Blade views, `composer.lock` stubs for v3 and v4, and a `resources/js/app.js` with a custom directive. Unit tests cover the catalog, edit distance, version parsing and context parsing. Integration tests load fixture buffers and assert completion item labels and diagnostic messages/ranges.

## Risks / Trade-offs

- **Hand-written data drifts from Livewire releases** → Each entry records its source. The health check reports the detected version, and a task covers cross-checking against the 4.4.8 bundle with a grep script kept in `scripts/`.
- **Custom event listeners (`wire:item-saved`) dispatched from Alpine get flagged as unknown** → `custom_directives` accepts them, and the README documents this. Warning severity keeps it non-blocking.
- **Duplicate or conflicting items from other sources (emmet, html-lsp) in Blade files** → Out of our control. The README shows how to give `livewire` a higher `score_offset`.
- **Large `resources/js` trees slow the first scan** → It's a one-time scan per root, with a file-size cap and `node_modules` skipped. It runs only on the first Blade buffer of a project.
- **Blade grammar quirks** (for example attributes produced by `{{ $attributes }}` or `@class`) → Those aren't `attribute_name` nodes, so they're never checked. Missing a diagnostic is better than a false positive.
- **blink.cmp v2 breaking changes** → The source interface is isolated in `blink.lua`. The README pins blink v1.

## Migration Plan

New plugin, so there's nothing to migrate. Local adoption: add a lazy.nvim spec with `dir = "~/Projects/livewire.nvim"` and the blink provider snippet to the LazyVim config. Rollback is removing that spec.

## Open Questions

- The exact curated "common events" list offered in completion. All DOM events are valid either way, so it only affects the suggestion list.
- Whether `wire:model` modifier ordering hints (for example `.debounce` before `.live`) are worth adding as a later diagnostic.
