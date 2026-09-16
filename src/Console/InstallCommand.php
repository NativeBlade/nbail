<?php

namespace NativeBlade\Nbail\Console;

use Illuminate\Console\Command;

class InstallCommand extends Command
{
    /** PHP versions the runtime image can install (ondrej PPA on Ubuntu 24.04). */
    public const PHP_VERSIONS = ['8.3', '8.4', '8.5'];

    protected $signature = 'nbail:install
        {--php=8.5 : PHP version inside the container (8.3, 8.4 or 8.5)}
        {--force : Overwrite an existing compose.yaml}';

    protected $description = 'Publish the nbail compose.yaml to run this NativeBlade app in Docker';

    public function handle(): int
    {
        $php = (string) $this->option('php');

        if (!in_array($php, self::PHP_VERSIONS, true)) {
            $this->error("Unsupported PHP version '{$php}'. Use one of: " . implode(', ', self::PHP_VERSIONS));

            return self::FAILURE;
        }

        $target = base_path('compose.yaml');

        if (file_exists($target) && !$this->option('force')) {
            $this->error('compose.yaml already exists. Use --force to overwrite it.');

            return self::FAILURE;
        }

        $stub = file_get_contents(__DIR__ . '/../../stubs/compose.stub');
        file_put_contents($target, str_replace('{{PHP_VERSION}}', $php, $stub));

        $this->components->info("compose.yaml published (PHP {$php}).");
        $this->line('  Start the container:  ./vendor/bin/nbail up -d');
        $this->line('  Run the app:          ./vendor/bin/nbail dev');

        return self::SUCCESS;
    }
}
