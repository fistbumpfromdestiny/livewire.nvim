<?php

namespace App\Livewire\Reports;

use Livewire\Component;

class Summary extends Component
{
    public string $month = '';

    public function render()
    {
        return view('livewire.reports.monthly');
    }
}
