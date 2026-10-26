# directive-catalog Specification

## Purpose

Provides the single source of truth for which `wire:` directives, sub-names and modifiers exist for the project's Livewire version, including project-defined custom directives, so completion and diagnostics agree on what is valid.

## Requirements

### Requirement: Versioned directive catalog
The plugin SHALL ship a catalog of Livewire directives covering Livewire 3 and Livewire 4. For every directive the catalog SHALL record a short description, a documentation URL for each supported major version, the major versions it exists in, its allowed modifiers (each with the versions it exists in), and any colon sub-names (for example `sort:item`, `sort:group-id`). The Livewire 4 entries SHALL agree with the Livewire 4.4.8 bundle and the Livewire 4 docs. The Livewire 3 entries SHALL agree with the Livewire 3 docs.

#### Scenario: Directive present in both versions
- **WHEN** the catalog is queried for `model` under Livewire 3 and under Livewire 4
- **THEN** both queries return the directive, each with a docs URL for that version

#### Scenario: Version-only directive
- **WHEN** the catalog is queried for `ref` under Livewire 3
- **THEN** the directive is reported as unavailable for that version, with the version it was introduced in

#### Scenario: Version-only modifier
- **WHEN** the catalog is queried for the `defer` modifier of `model` under Livewire 4
- **THEN** the modifier is reported as unavailable in Livewire 4

### Requirement: Modifier arguments
The catalog SHALL describe modifiers that take an argument segment (for example `debounce.500ms`, `throttle.250ms`, `poll.5s`, `loading.delay.long`, `intersect.threshold.50`) so that the argument segment is recognised as valid and not as a separate modifier.

#### Scenario: Duration argument
- **WHEN** the modifier chain `live.debounce.500ms` of `model` is checked
- **THEN** `500ms` is accepted as the argument of `debounce` and no modifier is reported unknown

#### Scenario: Bare duration on poll
- **WHEN** the modifier chain `5s` of `poll` is checked
- **THEN** it is accepted as a valid poll interval

### Requirement: Event directives
Any standard DOM event name (for example `click`, `submit`, `keydown`, `input`, `change`, `blur`, `focus`) SHALL be treated as a known directive. These use Livewire's event modifiers. For keyboard events (`keydown`, `keyup`, `keypress`), any modifier SHALL be accepted, because key names are open-ended.

#### Scenario: Known event
- **WHEN** the catalog is queried for `mouseenter`
- **THEN** it is reported as a known event directive with the event modifiers allowed

#### Scenario: Key modifier
- **WHEN** the modifier chain `shift.arrow-up.prevent` of `keydown` is checked
- **THEN** no modifier is reported unknown

### Requirement: Internal attributes are invisible
Livewire's internal attributes `wire:id`, `wire:name`, `wire:snapshot` and `wire:effects` SHALL be neither offered as completions nor reported as unknown.

#### Scenario: Rendered markup pasted into a view
- **WHEN** a Blade buffer contains `wire:snapshot="{...}"` and `wire:id="abc"`
- **THEN** neither attribute produces a completion item or a diagnostic

### Requirement: Livewire version detection
The plugin SHALL find the Livewire major version for a buffer by reading the `livewire/livewire` package version from the `composer.lock` of the buffer's project, checking both `packages` and `packages-dev`. A `livewire_version` config value (3 or 4) SHALL override detection. When neither yields a version, the plugin SHALL assume Livewire 4. The detected version SHALL be cached per project root and re-read when that project's `composer.lock` changes on disk.

#### Scenario: Detected from composer.lock
- **WHEN** a Blade file is opened in a project whose `composer.lock` lists `livewire/livewire` at `v3.6.4`
- **THEN** completion and diagnostics for that buffer use the Livewire 3 catalog

#### Scenario: Config override
- **WHEN** `livewire_version = 3` is configured and the project's lock file lists `v4.4.8`
- **THEN** the Livewire 3 catalog is used

#### Scenario: No lock file
- **WHEN** a Blade file is opened outside any project with a `composer.lock`
- **THEN** the Livewire 4 catalog is used and no error is shown

### Requirement: Custom directive discovery
The plugin SHALL treat as known every directive name registered in the project's JavaScript or TypeScript with `Livewire.directive('<name>'` or `Livewire.directive("<name>"`, found by scanning configurable paths under the project root (default `resources/js/**/*.{js,ts}`). It SHALL also treat as known every name in the `custom_directives` config option. A custom directive SHALL accept any modifiers and any colon sub-name. The scan SHALL run at most once per project root until a scanned file is written from Neovim.

#### Scenario: Directive defined in project JS
- **WHEN** `resources/js/app.js` contains `Livewire.directive('tooltip', ...)`
- **THEN** `tooltip` is offered as a directive and `wire:tooltip.top` produces no diagnostic

#### Scenario: Directive from config
- **WHEN** `custom_directives = { "sortable-list" }` is configured
- **THEN** `wire:sortable-list` is treated as known even though no project file defines it

#### Scenario: New directive saved
- **WHEN** the user adds `Livewire.directive('flash', ...)` to a scanned JS file and writes it
- **THEN** `wire:flash` stops being reported as unknown in open Blade buffers

### Requirement: Health check
`:checkhealth livewire` SHALL report the Neovim version, whether the tree-sitter `blade` parser is available, whether blink.cmp is installed, and for the current buffer's project the Livewire version with its source (lock file, override, or default) and the custom directives found.

#### Scenario: Missing blade parser
- **WHEN** `:checkhealth livewire` runs without the `blade` parser installed
- **THEN** it reports an error explaining that diagnostics are disabled and how to install the parser

### Requirement: Directive value kinds
The catalog SHALL record what each directive's value refers to:
- `property`: a component property, as in `wire:model`
- `action`: a method call or magic action, as in event directives, `wire:poll`, `wire:init`, `wire:intersect` and `wire:sort`
- `targets`: a comma-separated list of methods and properties, as in `wire:target`
- `expression`: a JavaScript expression evaluated against the component, as in `wire:show`, `wire:text` and `wire:bind:*`
- `none`: anything else, such as CSS classes, keys, names, URLs or text

A value kind MAY depend on the colon sub-name: `wire:sort` is `action`, but `wire:sort:item` is `none`. Every DOM event and every unknown name treated as an event SHALL have the value kind `action`. Custom directives SHALL have the value kind `none`.

#### Scenario: Model is a property
- **WHEN** the catalog is asked for the value kind of `model`
- **THEN** it returns `property`

#### Scenario: Event is an action
- **WHEN** the catalog is asked for the value kind of `click` or `keydown`
- **THEN** it returns `action`

#### Scenario: Sub-name changes the kind
- **WHEN** the catalog is asked for the value kind of `sort` and of `sort:item`
- **THEN** it returns `action` and `none` respectively
