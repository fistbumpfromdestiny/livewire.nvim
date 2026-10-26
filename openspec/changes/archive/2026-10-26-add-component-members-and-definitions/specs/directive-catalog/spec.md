## ADDED Requirements

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
