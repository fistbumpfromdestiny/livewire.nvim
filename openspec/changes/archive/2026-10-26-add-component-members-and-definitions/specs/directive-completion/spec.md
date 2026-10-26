## MODIFIED Requirements

### Requirement: Completion source for blink.cmp
The plugin SHALL provide two completion sources that offer identical items:
- a blink.cmp v1 source, which users register under `sources.providers`
- an nvim-cmp source named `livewire`, which `setup()` registers automatically when nvim-cmp is loaded, and which users add to their nvim-cmp `sources`

Both sources SHALL only return items in buffers whose filetype is `blade`. Both SHALL trigger on `:` and `.` (directive names, sub-names, modifiers, `$wire.`) and on `"`, `'` and `(` (attribute values and `$set('…')` arguments).

#### Scenario: Non-Blade buffer
- **WHEN** the user types `wire:` in a buffer with filetype `html` or `php`
- **THEN** the source returns no items

#### Scenario: nvim-cmp offers the same items
- **WHEN** nvim-cmp is installed, `setup()` has been called, `livewire` is in nvim-cmp's sources, and the user types `<input wire:mo` in a Blade buffer
- **THEN** nvim-cmp offers `model` with the same documentation as the blink.cmp source

#### Scenario: Value opens without a letter
- **WHEN** the user types the opening `"` of `wire:model="` in a component view
- **THEN** completion is triggered and property items are offered
