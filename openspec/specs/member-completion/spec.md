# member-completion Specification

## Purpose

Suggests the owning component's properties, methods and Livewire's magic actions while the user types a `wire:` attribute value or `$wire.`, so they don't have to switch to the PHP class to look names up.

## Requirements

### Requirement: Property completion in wire:model
When the cursor is inside the value of `wire:model` (with any modifiers), the completion sources SHALL offer the owning component's public, non-static properties. After `property.`, where the property is a Form object, they SHALL offer the Form object's public properties. Accepting an item SHALL replace only the partial name under the cursor.

#### Scenario: Properties offered
- **WHEN** the user types `wire:model="` in the view of `Greeter`, which declares `public string $name`, `public string $greeting` and `protected $secret`
- **THEN** items include `name` and `greeting` and exclude `secret`

#### Scenario: Form object
- **WHEN** the user types `wire:model.live="form.` and `form` is a `PostForm` declaring `public string $title`
- **THEN** items include `title`

### Requirement: Method completion in action directives
When the cursor is at the start of the value of `wire:click`, `wire:submit` or any other event directive, or of `wire:poll`, `wire:init`, `wire:intersect` or `wire:sort`, the sources SHALL offer:
- the owning component's public, non-static methods, except `render` and the lifecycle hooks Livewire refuses to call (`mount`, `boot`, `booted`, `exception`, `hydrate*`, `dehydrate*`, `updating*`, `updated*`, `rendering`, `rendered`)
- the magic actions available in the project's Livewire version, such as `$refresh`, `$set`, `$toggle`, `$parent`, `$dispatch`, `$dispatchTo`, `$dispatchSelf`, `$js` and `$commit`

Inside the first argument of `$set('…')` or `$toggle('…')`, the sources SHALL offer properties instead.

#### Scenario: Methods offered
- **WHEN** the user types `wire:click="` in the view of a component declaring `public function save()`, `public function mount()` and `protected function guard()`
- **THEN** items include `save` and `$refresh` and exclude `mount`, `guard` and `render`

#### Scenario: $toggle argument
- **WHEN** the user types `wire:click="$toggle('` in a view whose component declares `public bool $open`
- **THEN** items include `open`

### Requirement: Member completion in wire:target and after $wire
Inside a `wire:target` value, the sources SHALL offer public properties and callable methods. Each comma-separated entry SHALL be completed independently.

After `$wire.` anywhere in a Blade view of a component, they SHALL offer:
- public properties and callable methods
- the `$wire` magic properties of the project's Livewire version, such as `$refresh`, `$set`, `$get`, `$watch`, `$on`, `$dispatch`, `$el`, `$id`, `$parent` and `$upload`

#### Scenario: Second target
- **WHEN** the user types `wire:target="save, ` in a component with `public function delete()`
- **THEN** items include `delete`

#### Scenario: $wire in Alpine
- **WHEN** the user types `x-on:click="$wire.` in the view of `Greeter`
- **THEN** items include `changeGreeting`, `name` and `$refresh`

### Requirement: No owner, no items
When the view has no owning component, member completion SHALL offer only the magic actions (in action values) or `$wire` magic properties (after `$wire.`), and nothing for `wire:model` or `wire:target`. Values of directives whose value isn't a member reference SHALL get no member items. Those directives include `wire:key`, `wire:loading`, `wire:confirm`, `wire:navigate`, `wire:ref` and custom directives.

#### Scenario: Anonymous Blade component
- **WHEN** the user types `wire:model="` in `resources/views/components/app-logo.blade.php`
- **THEN** no items are offered

#### Scenario: Non-member value
- **WHEN** the user types `wire:key="`
- **THEN** no items are offered

### Requirement: Member item documentation
Each property and method item SHALL show its declaration (the type and name, or the method signature) and the file it is declared in. Magic action items SHALL show a short description.

#### Scenario: Property documentation
- **WHEN** the `name` item is selected in the view of `Greeter`
- **THEN** its documentation shows `public string $name` and `app/Livewire/Greeter.php`
