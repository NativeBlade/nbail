<?php

namespace NativeBlade\Nbail\Console;

use Illuminate\Console\Command;

class InstallCommand extends Command
{
    /** PHP versions the runtime image can install (ondrej PPA on Ubuntu 24.04). */
    public const PHP_VERSIONS = ['8.3', '8.4', '8.5'];

    protected $signature = 'nbail:install
        {--php=8.5 : PHP version inside the container (8.3, 8.4 or 8.5)}
        {--android : Include the Android SDK, NDK and JDK to build Android apps}
        {--force : Overwrite an existing compose.yaml}';

    protected $description = 'Publish the nbail compose.yaml to run this NativeBlade app in Docker';

    public function handle(): int
    {
        $php = (string) $this->option('php');
        $android = (bool) $this->option('android');

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
        file_put_contents($target, self::render($stub, $php, $android));

        $this->components->info('compose.yaml published (PHP ' . $php . ($android ? ', Android' : '') . ').');
        $this->line('  Start the container:  ./vendor/bin/nbail up -d');
        $this->line('  Run the app:          ./vendor/bin/nbail dev');

        if ($android) {
            $this->line('  Build for Android:    ./vendor/bin/nbail artisan nativeblade:build android');
        }

        return self::SUCCESS;
    }

    /**
     * Fill the compose stub. Android adds the image stage with the SDK and NDK
     * plus volumes that keep the Gradle cache and adb keys (paired devices)
     * across container restarts.
     */
    public static function render(string $stub, string $php, bool $android): string
    {
        $volumes = $android
            ? "            - 'nbail-gradle:/var/cache/nbail/gradle'\n"
                . "            - 'nbail-android:/home/nbail/.android'\n"
            : '';

        $definitions = $android
            ? "    nbail-gradle:\n        driver: local\n"
                . "    nbail-android:\n        driver: local\n"
            : '';

        return strtr($stub, [
            '{{PHP_VERSION}}' => $php,
            '{{TARGET}}' => $android ? 'android' : 'base',
            '{{IMAGE_SUFFIX}}' => $android ? '-android' : '',
            "{{ANDROID_VOLUMES}}\n" => $volumes,
            "{{ANDROID_VOLUME_DEFINITIONS}}\n" => $definitions,
        ]);
    }
}
