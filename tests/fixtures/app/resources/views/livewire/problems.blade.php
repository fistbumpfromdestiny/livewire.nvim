<div>
    <input wire:model="nmae">
    <input wire:model="secret">
    <input wire:model="instances">
    <input wire:model.live="form.titel">
    <input wire:model="items.0.name">
    <button wire:submit="changeGreting()">Greet</button>
    <button wire:click="mount">Mount</button>
    <button wire:click="render">Render</button>
    <button wire:click="guard">Guard</button>
    <button wire:click="make">Make</button>
    <button wire:click="bootHasSearch">Boot</button>
    <button wire:click="updatedName">Updated</button>
    <button wire:click="$refresh">Refresh</button>
    <button wire:click="$set('open', true)">Set</button>
    <button wire:click="count++">Count</button>
    <button wire:click="sortBy('name')">Sort</button>
    <button wire:keydown.enter="clearSearch">Clear</button>
    <div wire:poll.5s="refreshStats">Poll</div>
    <div wire:key="item-1" wire:loading.class="opacity-50">Not members</div>
</div>
