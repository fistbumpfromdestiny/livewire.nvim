import { Livewire } from '../../vendor/livewire/livewire/dist/livewire.esm'

Livewire.directive('tooltip', ({ el, directive }) => {
    el.title = directive.expression
})

Livewire.start()
