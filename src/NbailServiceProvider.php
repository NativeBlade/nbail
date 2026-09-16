<?php

namespace NativeBlade\Nbail;

use Illuminate\Support\ServiceProvider;
use NativeBlade\Nbail\Console\InstallCommand;

class NbailServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        if ($this->app->runningInConsole()) {
            $this->commands([
                InstallCommand::class,
            ]);
        }
    }
}
