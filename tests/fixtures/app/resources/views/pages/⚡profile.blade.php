<?php

use Livewire\Component;

new class extends Component {
    public string $email = '';

    public function save(): void {}
}; ?>

<section>
    <input wire:model="email">
    <button wire:click="save" x-on:click="$wire.save()">Save</button>
    <button wire:click="sav">Typo</button>
</section>
