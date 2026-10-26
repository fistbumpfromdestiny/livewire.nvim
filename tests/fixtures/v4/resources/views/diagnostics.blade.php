<div>
    <p>Prose about wire.model="x" is not checked.</p>
    <input wire.model.fill="greeting">
    <input wire:modle="name">
    <input wire:model.lve="name">
    <input wire:model.defer="name">
    <input wire:model.blur.live.debounce.500ms="q">
    @if($open)<span wire:lodaing>Saving…</span>@endif
    <div wire:mouseenter="hover" wire:tooltip="Hi" wire:chart>
    <li wire:sort:itme="1">
    <input wire:keydown.shift.arrow-up.prevent="next">
    <div wire:snapshot="{}" wire:id="abc" wire:effects="{}"></div>
    <div wire:frobnicate="x"></div>
    {{-- <input wire:modle="commented"> --}}
    <input value="wire:modle" x-on:click="$wire.modle()">
</div>
