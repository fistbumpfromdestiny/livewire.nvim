## Purpose

Lets users jump from a component tag, a `wire:` attribute value or `$wire.member` in a Blade view to the component file or member it refers to. It works with whatever go-to-definition mapping they already use, because the plugin answers as a language server.

## ADDED Requirements

### Requirement: In-process language server
After `setup()`, the plugin SHALL attach a language server named `livewire` to every Blade buffer, running inside Neovim with no external process. It SHALL advertise only the definition capability, so that it does not compete with other servers for completion, hover or formatting. The server SHALL NOT be started when the `definition.enabled` option is `false`. Each server instance SHALL be shared by the Blade buffers of one project root.

#### Scenario: Attached to Blade buffers
- **WHEN** a `.blade.php` file inside a Laravel project is opened after `setup()`
- **THEN** a client named `livewire` is attached to the buffer and advertises `definitionProvider`

#### Scenario: Disabled
- **WHEN** `setup({ definition = { enabled = false } })` was called and a Blade file is opened
- **THEN** no `livewire` client is attached

### Requirement: Component definitions
When definitions are requested with the cursor on the name in a component tag (`<livewire:…>`, `@livewire('…')`, `<flux:…>`, `<x-…>`), the server SHALL return the file that component resolves to, positioned at the start of the file. When the component can't be resolved, it SHALL return no locations.

#### Scenario: Livewire tag
- **WHEN** definitions are requested with the cursor on `greeter` in `<livewire:greeter />`
- **THEN** the result is a location in `app/Livewire/Greeter.php`

#### Scenario: Unresolved component
- **WHEN** definitions are requested on `<livewire:missing />`
- **THEN** the result is empty

### Requirement: Member definitions
When definitions are requested with the cursor on a member reference, the server SHALL return the member's declaration in the owning component, its traits or its parent classes. If the member is a Form object property followed by `.name`, it SHALL return the declaration in the Form class.

Member references are:
- the value of `wire:model`
- the method name in the value of `wire:click` or any other action directive
- an entry in a `wire:target` list
- the first argument of `$set('…')` or `$toggle('…')`
- `member` in `$wire.member`

When the view has no owner or the member isn't found, it SHALL return no locations.

#### Scenario: wire:model
- **WHEN** definitions are requested on `name` in `wire:model="name"` in a view owned by `Greeter`
- **THEN** the result is the line declaring `public string $name` in `app/Livewire/Greeter.php`

#### Scenario: Action with arguments
- **WHEN** definitions are requested on `changeGreeting` in `wire:submit="changeGreeting()"`
- **THEN** the result is the line declaring `function changeGreeting` in the owning class

#### Scenario: Member from a trait
- **WHEN** definitions are requested on `wire:model="search"` and `search` is declared in a trait the component uses
- **THEN** the result is in the trait's file

#### Scenario: $wire in a single-file component
- **WHEN** definitions are requested on `save` in `$wire.save()` inside a single-file component
- **THEN** the result is the line declaring `function save` in the same buffer

#### Scenario: Not a member reference
- **WHEN** definitions are requested on the value of `wire:key="item-1"` or `wire:loading.class="opacity-50"`
- **THEN** the result is empty
