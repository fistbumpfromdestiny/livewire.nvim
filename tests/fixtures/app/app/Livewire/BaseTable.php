<?php

namespace App\Livewire;

use Livewire\Component;

abstract class BaseTable extends Component
{
    public string $sortField = 'id';

    public function sortBy(string $column): void
    {
        $this->sortField = $column;
    }
}
