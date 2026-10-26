<?php

namespace App\Concerns;

trait HasSearch
{
    public string $search = '';

    public function bootHasSearch(): void {}

    public function clearSearch(): void
    {
        $this->search = '';
    }
}
