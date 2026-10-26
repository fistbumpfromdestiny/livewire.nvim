<?php

namespace App\Livewire\Forms;

use Livewire\Form;

class PostForm extends Form
{
    public string $title = '';

    public string $body = '';

    protected array $internal = [];
}
