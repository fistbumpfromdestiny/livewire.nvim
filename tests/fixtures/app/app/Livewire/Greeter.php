<?php

namespace App\Livewire;

use App\Concerns\HasSearch;
use App\Livewire\Forms\PostForm;
use Livewire\Attributes\Validate;

class Greeter extends BaseTable
{
    use HasSearch;

    #[Validate('required|min:2')]
    public string $name = '';

    public string $greeting = '', $greetingMessage = '';

    public PostForm $form;

    public bool $open = false;

    protected string $secret = '';

    public static int $instances = 0;

    public function mount(): void {}

    public function changeGreeting(
        string $prefix = 'Hello',
    ): void {
        $this->greetingMessage = "{$prefix}, {$this->name}!";
    }

    // public function oldGreeting() {}

    /* public function commented() {} */

    public function updatedName(): void {}

    protected function guard(): void {}

    public static function make(): static
    {
        return new static;
    }

    public function render()
    {
        return view('livewire.greeter');
    }
}
