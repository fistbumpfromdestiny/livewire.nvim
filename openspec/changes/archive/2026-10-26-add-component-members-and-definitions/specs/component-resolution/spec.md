## Purpose

Works out which file a component tag refers to, which Livewire component owns a Blade view, and which properties and methods that component exposes. Go-to-definition, member completion and member diagnostics all build on this.

## ADDED Requirements

### Requirement: Livewire component tag resolution
The plugin SHALL resolve the component name in `<livewire:name>` and `@livewire('name')` to a file in the project.
- **Names:** dots map to directories, and `ns::name` uses the namespace's directory.
- **Order:** for a name without a namespace, the class file under the class path comes first. After that, each component location is tried, looking for a single-file component (`name.blade.php` or `⚡name.blade.php`), then a multi-file component (`name/name.php` or `⚡name/name.php`, falling back to its `.blade.php`).
- **Paths:** the class path, component locations and namespaces SHALL be read from the project's `config/livewire.php` when it exists. Otherwise they SHALL default to `app/Livewire`, `resources/views/components` plus `resources/views/livewire`, and the namespaces `layouts` and `pages`.

#### Scenario: Class component
- **WHEN** `<livewire:greeter />` is resolved in a project with `app/Livewire/Greeter.php`
- **THEN** the result is `app/Livewire/Greeter.php`

#### Scenario: Nested name to class
- **WHEN** `<livewire:admin.user-table />` is resolved and `app/Livewire/Admin/UserTable.php` exists
- **THEN** the result is that file

#### Scenario: Single-file component in a namespace
- **WHEN** `<livewire:pages::settings.profile />` is resolved and `resources/views/pages/settings/⚡profile.blade.php` exists
- **THEN** the result is that file

#### Scenario: Multi-file component
- **WHEN** `<livewire:counter />` is resolved, no class exists, and `resources/views/components/⚡counter/counter.php` exists
- **THEN** the result is that PHP file

#### Scenario: Published config
- **WHEN** `config/livewire.php` sets `'class_path' => app_path('Http/Livewire')` and `<livewire:greeter />` is resolved
- **THEN** `app/Http/Livewire/Greeter.php` is tried first

### Requirement: Blade and Flux component tag resolution
The plugin SHALL resolve `<flux:name>` to a published override under `resources/views/flux` first, then to the Flux package views under `vendor/livewire/flux-pro` and `vendor/livewire/flux`.

The plugin SHALL resolve `<x-name>` and `<x-ns::name>`:
- **Without a namespace:** the class under `app/View/Components` comes first, then the anonymous view under `resources/views/components`.
- **With a namespace:** the namespace's directory.

For each view directory, the paths `name.blade.php`, `name/index.blade.php` and `name/name.blade.php` SHALL be tried in that order.

- `<x-slot>`, `<x-slot:name>` and `<x-dynamic-component>` SHALL NOT be resolved.
- `<x-…>` resolution SHALL be skipped entirely when the `definition.blade_components` option is `false`.

#### Scenario: Flux override wins
- **WHEN** `<flux:navlist.group>` is resolved and `resources/views/flux/navlist/group.blade.php` exists
- **THEN** the result is that file, not the vendor copy

#### Scenario: Anonymous Blade component
- **WHEN** `<x-app-logo />` is resolved and only `resources/views/components/app-logo.blade.php` exists
- **THEN** the result is that file

#### Scenario: Blade components switched off
- **WHEN** `definition.blade_components` is `false` and `<x-app-logo />` is resolved
- **THEN** there is no result

#### Scenario: Slot is not a component
- **WHEN** `<x-slot:title>` is resolved
- **THEN** there is no result

### Requirement: Owning component of a view
For a Blade buffer, the plugin SHALL determine the Livewire component whose members the view's `wire:` attributes and `$wire` refer to. It SHALL check these in order and use the first that applies:
- **Single-file component:** the buffer itself contains a PHP block declaring a class that extends `Component`.
- **Multi-file component:** a PHP file with the view's base name (without `⚡`) sits next to the view.
- **Class component by convention:** a view under `resources/views/livewire/` maps to the class under the class path with the same path in StudlyCase.
- **Class component by reference:** a class under the class path mentions the view's dotted name, as in `view('livewire.greeter')`.

When none applies, the view has no owner.

#### Scenario: Class component view
- **WHEN** the owner of `resources/views/livewire/greeter.blade.php` is requested and `app/Livewire/Greeter.php` exists
- **THEN** the owner is `app/Livewire/Greeter.php`

#### Scenario: Single-file component
- **WHEN** the owner of `resources/views/pages/settings/⚡profile.blade.php` is requested and the file begins with `<?php … new class extends Component { … } ?>`
- **THEN** the owner is that same file

#### Scenario: Plain Blade view
- **WHEN** the owner of `resources/views/components/app-logo.blade.php` is requested
- **THEN** there is no owner

### Requirement: Component member index
For an owning component, the plugin SHALL list the properties and methods a view can refer to.
- **Per member:** its name, its kind (property or method), its visibility, whether it is static, its declared type or signature, and the file and position it is declared at.
- **Where members come from:** the class body, the traits it uses, and its parent classes, all followed recursively. Traits and parents SHALL be found through the project's PSR-4 autoload map: the generated `vendor/composer/autoload_psr4.php` when it exists, otherwise `composer.json`.
- **Where the search stops:** at `Livewire\Component`, `Livewire\Volt\Component` and `Livewire\Form`, whose own members SHALL NOT be listed.
- **Single-file components:** members SHALL be read from the view's PHP block.
- **Freshness:** for a file open in a modified buffer, the buffer's contents SHALL be used instead of the file on disk.
- **Completeness:** the index SHALL be marked *complete* only when every trait and parent class up to the stopping point was found.

#### Scenario: Trait and parent members
- **WHEN** the index is built for a component that uses trait `App\Concerns\HasSearch` (declaring `public string $search`) and extends `App\Livewire\BaseTable` (declaring `public function sortBy()`), both found through PSR-4
- **THEN** the index contains `search` and `sortBy` and is complete

#### Scenario: Livewire base class excluded
- **WHEN** the index is built for a component extending `Livewire\Component`
- **THEN** it contains none of `Livewire\Component`'s own methods such as `validate`, `redirect` or `dispatch`, and it is complete

#### Scenario: Unresolvable parent
- **WHEN** the index is built for a component extending a class that PSR-4 can't map to an existing file
- **THEN** the index contains the component's own members and is marked incomplete

#### Scenario: Unsaved edit to the component
- **WHEN** a new `public function archive()` has been typed into the open, unsaved component class and the index is requested
- **THEN** the index contains `archive`

### Requirement: Form object properties
When a component property's declared type is a class extending `Livewire\Form`, the plugin SHALL resolve that class through the file's imports and PSR-4. It SHALL list the class's public properties as the members available after `property.`.

#### Scenario: Form object
- **WHEN** a component declares `public PostForm $form` and `App\Livewire\Forms\PostForm` declares `public string $title`
- **THEN** the members available after `form.` include `title`
