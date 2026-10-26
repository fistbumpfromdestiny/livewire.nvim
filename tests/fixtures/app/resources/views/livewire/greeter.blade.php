<div>
    <form wire:submit="changeGreeting()">
        <input wire:model.live="name">
        <input wire:model="form.title">
        <button wire:click="$toggle('open')">Toggle</button>
        <span wire:loading wire:target="changeGreeting, name">Saving</span>
        <div x-on:click="$wire.sortBy('name')">{{ $search }}</div>
    </form>
</div>
