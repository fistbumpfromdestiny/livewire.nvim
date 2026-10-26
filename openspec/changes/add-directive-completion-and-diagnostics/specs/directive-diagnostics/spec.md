## Purpose

Reports Livewire directive mistakes that the browser, Blade and Livewire all ignore silently, such as `wire.model=`, `wire:modle` and `wire:model.lve`, as Neovim diagnostics while the user edits Blade files.

## ADDED Requirements

### Requirement: Diagnostic scope and presentation
The plugin SHALL check attribute names inside HTML and Blade component start tags in buffers whose filetype is `blade`, including tags nested inside Blade control structures such as `@if`. It SHALL NOT check element text, attribute values, comments, or PHP and echo regions. Every diagnostic from this capability SHALL have severity WARN and source `livewire`, and SHALL span the offending attribute name or segment.

#### Scenario: Text content is ignored
- **WHEN** a paragraph's text contains `wire.model="x"`
- **THEN** no diagnostic is produced

#### Scenario: Nested in a Blade directive
- **WHEN** `@if($x)<span wire:lodaing>…</span>@endif` is in the buffer
- **THEN** `wire:lodaing` gets a diagnostic

### Requirement: Dot-instead-of-colon detection
An attribute name that starts with `wire.` SHALL produce a warning suggesting the same name with the first `.` replaced by `:`.

#### Scenario: wire.model typo
- **WHEN** the buffer contains `<input wire.model.fill="greeting">`
- **THEN** a warning on `wire.model.fill` reads that Livewire ignores it, and suggests `wire:model.fill`

### Requirement: Unknown directive detection
An attribute name `wire:<name>` SHALL produce a warning when `<name>` is not a directive available for the buffer's Livewire version, not a DOM event name, not an internal attribute, and not a custom directive. When a known directive or event name is close in spelling, the message SHALL suggest it. When `<name>` is a directive that exists only in another major version, the message SHALL say which version it needs.

#### Scenario: Misspelled directive
- **WHEN** the buffer contains `<input wire:modle="name">`
- **THEN** a warning on `modle` suggests `wire:model`

#### Scenario: Directive from a newer version
- **WHEN** a Livewire 3 project's buffer contains `<div wire:ref="modal">`
- **THEN** a warning says `wire:ref` requires Livewire 4

#### Scenario: DOM event and custom directive are not flagged
- **WHEN** the buffer contains `wire:mouseenter="hover"` and `wire:tooltip="Hi"` with `tooltip` a custom directive
- **THEN** no diagnostic is produced

### Requirement: Unknown modifier detection
For a known, non-custom directive, each modifier segment SHALL produce a warning when it is neither a modifier allowed for that directive and version nor a valid argument of the modifier before it. The warning SHALL span only that segment and SHALL suggest a close match when one exists. Modifiers of custom directives and of keyboard events SHALL NOT be checked.

#### Scenario: Misspelled modifier
- **WHEN** the buffer contains `wire:model.lve="name"`
- **THEN** a warning on `lve` suggests `live`

#### Scenario: Removed modifier
- **WHEN** a Livewire 4 project's buffer contains `wire:model.defer="name"`
- **THEN** a warning on `defer` says it is not supported in Livewire 4

#### Scenario: Valid chain with argument
- **WHEN** the buffer contains `wire:model.blur.live.debounce.500ms="q"`
- **THEN** no diagnostic is produced

#### Scenario: Unknown sub-name
- **WHEN** a Livewire 4 project's buffer contains `wire:sort:itme`
- **THEN** a warning on `itme` suggests `item`

### Requirement: Diagnostic refresh
Diagnostics SHALL be computed when a Blade buffer is read, after text changes in normal mode, on leaving insert mode, and after writing. They SHALL be recomputed for open Blade buffers when the buffer's Livewire version or custom directive set changes. Editing in insert mode SHALL NOT recompute them on every keystroke.

#### Scenario: Fix clears the warning
- **WHEN** the user corrects `wire:modle` to `wire:model` and leaves insert mode
- **THEN** the warning disappears

### Requirement: Diagnostics can be disabled and degrade safely
Setting `diagnostics = false` in the plugin config SHALL disable all diagnostics from this capability. When the `blade` tree-sitter parser is unavailable, the plugin SHALL produce no diagnostics and SHALL NOT raise errors.

#### Scenario: Disabled by config
- **WHEN** `diagnostics = false` is configured and a buffer contains `wire:modle`
- **THEN** no livewire diagnostic is shown

#### Scenario: Parser missing
- **WHEN** the `blade` parser is not installed and a Blade file is opened
- **THEN** no error message appears and no livewire diagnostics are set
