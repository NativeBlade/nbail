# nbail

A Docker development environment for [NativeBlade](https://docs.nativeblade.dev) apps, in the spirit of Laravel Sail. Docker is the only thing you install: PHP, Composer, Node and Rust live in the container.

## What you get today

- PHP 8.3, 8.4 or 8.5 with the extensions Laravel and NativeBlade need
- Composer, Node 22 and Rust (stable)
- The NativeBlade browser preview with hot reload (`nativeblade:dev --platform=browser`)

The browser preview runs your UI, Livewire and the PHP WASM runtime. Native plugins (camera, push, and so on) are no-ops there. Android builds and a host bridge for iOS and desktop are planned; see [Roadmap](#roadmap).

## Requirements

- Docker Desktop (macOS, Windows) or Docker Engine with the Compose plugin (Linux)
- On Windows, run the commands from a WSL2 terminal, as with Laravel Sail

## New app

```bash
bash installer/new.sh my-app com.example.myapp
cd my-app
./vendor/bin/nbail up -d
./vendor/bin/nbail dev
```

Open http://localhost:1420.

The first run builds the image, which takes a few minutes. Set `NBAIL_PHP_VERSION=8.4` to pick another PHP version (8.5 is the default).

## Existing app

Install nbail as a regular dependency, not with `--dev`. `nativeblade:dev` bundles Laravel with `composer install --no-dev`, which removes dev dependencies (and the `vendor/bin/nbail` wrapper) from the project.

```bash
composer require nativeblade/nbail
php artisan nbail:install
./vendor/bin/nbail up -d
./vendor/bin/nbail dev
```

Without PHP on the machine, run the first two commands through the image:

```bash
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -v "$(pwd)":/var/www/html --entrypoint bash nbail/php-8.5 \
    -c "composer require nativeblade/nbail && php artisan nbail:install"
```

## Commands

| Command | What it does |
|---|---|
| `nbail up -d` | Start the container in the background |
| `nbail stop` / `nbail down` | Stop / remove the container |
| `nbail dev` | Browser preview with hot reload |
| `nbail artisan <command>` | Run an Artisan command |
| `nbail composer`, `npm`, `npx`, `node`, `php`, `cargo`, `rustup` | Run the tool inside the container |
| `nbail shell` / `nbail root-shell` | Open a shell as the app user / as root |
| `nbail build --no-cache` | Rebuild the image |

Anything else is passed to `docker compose`.

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `NB_PORT` | `1420` | Dev server port, used on both the host and the container |
| `WWWUSER` / `WWWGROUP` | your uid / gid | Owner of files the container writes into the project |
| `NBAIL_MTU` | `1500` | MTU of the container network. Set `1280` behind a VPN |

Change the PHP version with `php artisan nbail:install --php=8.4 --force`, then `nbail build`.

## Notes

- Files created in the container belong to your user: the container user takes your uid and gid at startup.
- On macOS and Windows, bind mounts are slower than native disk. The first `composer install` and `npm install` take longer than on a local setup.
- The Cargo registry is kept in a named volume, so Rust dependencies are downloaded once.
- Behind a VPN such as Cloudflare WARP, the tunnel's smaller MTU can make HTTPS hang inside the container while DNS and ping still work. Set `NBAIL_MTU=1280` and run `nbail down && nbail up -d`. Image builds already use the host network for this reason.

## Roadmap

1. PHP, Composer, Node and Rust with the browser preview (this release)
2. Android: SDK, NDK and JDK as an optional image layer, with the device or emulator reached through the host's adb server
3. Host bridge: a small helper on the host that runs iOS and desktop builds, where Xcode and the platform toolchains live
