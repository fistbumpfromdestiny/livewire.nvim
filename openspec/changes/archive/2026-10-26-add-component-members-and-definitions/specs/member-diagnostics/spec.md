## Purpose

Warns about `wire:model` properties and `wire:click` and other action methods that Livewire would reject at runtime: because they don't exist on the owning component, aren't public, or are lifecycle hooks. Only cases the plugin can prove are reported.

## ADDED Requirements

### Requirement: Unknown property in wire:model
When a `wire:model` value is a plain property path (`name`, `form.title`, `items.0.name`), the plugin SHALL report a warning on the first segment if any of these holds:
- it isn't a property in a complete member index of the owning component
- it is a property that isn't public
- it is a static property

The message SHALL name the component class and SHALL suggest the closest public property when one is within the same edit-distance threshold used for directive names. Only the first segment SHALL be checked.

#### Scenario: Misspelled property
- **WHEN** a view of `Greeter` (properties `name`, `greeting`, `greetingMessage`) contains `wire:model="nmae"`
- **THEN** a warning on `nmae` says the property is not found on `Greeter` and suggests `name`

#### Scenario: Protected property
- **WHEN** the component declares `protected string $secret` and the view contains `wire:model="secret"`
- **THEN** a warning says `secret` is not public, so `wire:model` cannot set it

#### Scenario: Nested path
- **WHEN** the view contains `wire:model="form.titel"` and `form` is a public property
- **THEN** no warning is reported

### Requirement: Unknown method in action directives
When the value of an action directive (an event directive such as `wire:click` or `wire:submit`, or `wire:poll`, `wire:init`, `wire:intersect`, `wire:sort`) consists of a single method name, optionally followed by a parenthesised argument list, the plugin SHALL report a warning on the name in these cases:
- **Not found:** the name isn't in a complete member index of the owning component. The message SHALL suggest the closest callable method.
- **Not public, or static:** the message SHALL say Livewire can only call public methods.
- **`render` or a lifecycle hook:** the message SHALL say Livewire refuses to call it from the browser.

Values starting with `$` (magic actions, `$wire`, `$dispatch` and similar) and any other JavaScript expression SHALL NOT be checked.

#### Scenario: Misspelled method
- **WHEN** a view of `Greeter` contains `wire:submit="changeGreting()"`
- **THEN** a warning on `changeGreting` says the method is not found on `Greeter` and suggests `changeGreeting`

#### Scenario: Lifecycle hook
- **WHEN** the view contains `wire:click="mount"`
- **THEN** a warning says `mount` is a lifecycle hook Livewire won't call from the browser

#### Scenario: Magic action and expression
- **WHEN** the view contains `wire:click="$refresh"`, `wire:click="$set('open', true)"` and `wire:click="count++"`
- **THEN** none of them are reported

### Requirement: Only provable problems
Member diagnostics SHALL be reported only when all of the following hold. Otherwise the view SHALL get no member diagnostics:
- the view has an owning component
- that component's member index is complete
- the tree-sitter `php` parser is available

Member diagnostics SHALL use the same warning severity, namespace and `diagnostics` option as directive diagnostics.

#### Scenario: Plain Blade component
- **WHEN** `resources/views/components/app-logo.blade.php` contains `wire:click="anything"`
- **THEN** no member warning is reported

#### Scenario: Unresolvable base class
- **WHEN** the owning component extends a class that can't be found through PSR-4 and the view contains `wire:click="inheritedMethod"`
- **THEN** no member warning is reported

### Requirement: Re-check when the component changes
When a PHP file that belongs to a project's member index is written, open Blade views of that project SHALL be re-checked. In a single-file component, editing the PHP block SHALL re-check the view on the usual diagnostic refresh events.

#### Scenario: Method added to the class
- **WHEN** a view shows a warning for `wire:click="archive"` and the user adds `public function archive()` to the class and saves it
- **THEN** the warning disappears from the open view
