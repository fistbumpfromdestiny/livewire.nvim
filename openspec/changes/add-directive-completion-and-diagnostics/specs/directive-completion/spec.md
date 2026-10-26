## Purpose

Lets users discover and type Livewire `wire:` directives and their modifiers from blink.cmp in Blade files, with descriptions and documentation links, so they don't have to look them up.

## ADDED Requirements

### Requirement: Completion source for blink.cmp
The plugin SHALL provide a blink.cmp v1 completion source that users register under `sources.providers`. The source SHALL only return items in buffers whose filetype is `blade`, and SHALL trigger on `:` and `.`.

#### Scenario: Non-Blade buffer
- **WHEN** the user types `wire:` in a buffer with filetype `html` or `php`
- **THEN** the source returns no items

### Requirement: Directive name completion
When the cursor is in an attribute name inside an HTML or Blade component start tag, directly after `wire:` or after `wire:` plus a partial name, the source SHALL offer every directive available for the buffer's Livewire version, every custom directive, and a curated set of common DOM events (at least `click`, `submit`, `keydown`, `keyup`, `change`, `input`, `blur`, `focus`). Accepting an item SHALL replace only the partial directive name.

#### Scenario: Typing wire colon
- **WHEN** the user types `<input wire:` in a Livewire 4 project
- **THEN** items include `model`, `click`, `loading`, `show` and `navigate`, and exclude `id`, `snapshot` and `effects`

#### Scenario: Version filtering
- **WHEN** the user types `<div wire:` in a Livewire 3 project
- **THEN** items exclude Livewire-4-only directives such as `ref`, `island`, `bind`, `sort` and `intersect`

#### Scenario: Partial name
- **WHEN** the line is `<input wire:mo` and the user accepts `model`
- **THEN** the line becomes `<input wire:model`

#### Scenario: Component tags and multi-line tags
- **WHEN** the user types `wire:` on its own line inside a multi-line `<x-input` or `<livewire:counter` start tag
- **THEN** directive items are offered

#### Scenario: Outside an attribute name
- **WHEN** the user types `wire:` in element text content, inside an attribute value, or inside a `{{ }}` echo
- **THEN** no directive items are offered

### Requirement: Colon sub-name completion
When the cursor follows `wire:<directive>:` for a directive that has colon sub-names, the source SHALL offer that directive's sub-names.

#### Scenario: Sort sub-names
- **WHEN** the user types `<li wire:sort:` in a Livewire 4 project
- **THEN** items include `item`, `group` and `ignore`

### Requirement: Modifier completion
When the cursor follows `wire:<directive>.` or a chain of modifiers ending in `.`, the source SHALL offer the modifiers allowed for that directive and version, leaving out modifiers already in the chain. When the preceding segment is a modifier that takes an argument, the source SHALL offer example argument values (for example `250ms`, `500ms`, `1000ms` after `debounce.`). Accepting an item SHALL replace only the partial modifier.

#### Scenario: wire:model modifiers
- **WHEN** the user types `wire:model.` in a Livewire 4 project
- **THEN** items include `live`, `blur`, `change`, `enter`, `fill`, `number`, `boolean` and `debounce`, and exclude `defer`

#### Scenario: Already-used modifier
- **WHEN** the user types `wire:model.live.`
- **THEN** `live` is not offered again

#### Scenario: Event modifiers
- **WHEN** the user types `wire:click.`
- **THEN** items include `prevent`, `stop`, `self`, `once`, `outside`, `window`, `document`, `debounce`, `throttle`, `async`, `renderless` and `preserve-scroll`

#### Scenario: Argument values
- **WHEN** the user types `wire:model.live.debounce.`
- **THEN** items offered are duration values such as `500ms`

#### Scenario: Keyboard event
- **WHEN** the user types `wire:keydown.`
- **THEN** items include common key names (`enter`, `escape`, `space`, `tab`, arrow keys) and the event modifiers

#### Scenario: Custom directive
- **WHEN** the user types `wire:tooltip.` where `tooltip` is a custom directive
- **THEN** the source returns no items

### Requirement: Item documentation
Each directive and modifier item SHALL include a short description and, for directives, a link to the documentation page for the buffer's Livewire version. Custom directive items SHALL be labelled as custom.

#### Scenario: Documentation shown
- **WHEN** the `model` item is selected in the completion menu in a Livewire 4 project
- **THEN** its documentation shows a description and `https://livewire.laravel.com/docs/4.x/wire-model`
