# nbail

A Docker development environment for [NativeBlade](https://docs.nativeblade.dev) apps, in the spirit of Laravel Sail. Docker is the only thing you install: PHP, Composer, Node and Rust live in the container.

## What you get today

- PHP 8.3, 8.4 or 8.5 with the extensions Laravel and NativeBlade need
- Composer, Node 22 and Rust (stable)
- The NativeBlade browser preview with hot reload (`nativeblade:dev --platform=browser`)
- Optional Android toolchain to build APKs and AABs: JDK 17, Android SDK and NDK

The browser preview runs your UI, Livewire and the PHP WASM runtime. Native plugins (camera, push, and so on) are no-ops there. A host bridge for iOS and desktop is planned; see [Roadmap](#roadmap).

## Platform setup

Follow the section for your operating system first. The rest of this guide is the same everywhere.

### macOS

- Install Docker Desktop.
- Your LAN IP, used later for the Android dev client: `ipconfig getifaddr en0` (Wi-Fi) or `ipconfig getifaddr en1`.
- Docker Desktop publishes port 1420 on your network. If macOS asks whether Docker may accept incoming connections, allow it.
- Bind mounts are slower than native disk, so the first `composer install` and `npm install` take longer than on a local setup.
- On Apple Silicon, Google ships the Android SDK and NDK for x86_64 Linux only, so the Android image has to run as `linux/amd64` under emulation, and builds are much slower. This has not been tested yet.

### Linux

- Install Docker Engine with the Compose plugin, and add your user to the `docker` group.
- Your LAN IP, used later for the Android dev client: `hostname -I | awk '{print $1}'`
- Docker publishes port 1420 on your network. If a firewall is active, allow it, for example `sudo ufw allow 1420/tcp`.

### Windows

nbail runs from a WSL2 terminal, as Laravel Sail does. Keep your projects inside the WSL filesystem (for example `~/projects`), not under `/mnt/c`: file access through `/mnt/c` is much slower.

- Your LAN IP, used later for the Android dev client: run `ipconfig` in PowerShell and take the IPv4 address of your Wi-Fi or Ethernet adapter.

#### WSL2

These steps are for Docker Engine installed inside your WSL distribution (tested on Ubuntu).

**Port 1420 from your network.** Windows does not forward ports from your network into WSL, so a phone cannot reach the dev server until you forward the port. Run once from an administrator PowerShell:

```powershell
# IP of the WSL VM (changes after WSL restarts; run this again when it does)
$wslIp = (wsl hostname -I).Trim().Split(' ')[0]

netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=1420 connectaddress=$wslIp connectport=1420
New-NetFirewallRule -DisplayName "nbail dev server 1420" -Direction Inbound -LocalPort 1420 -Protocol TCP -Action Allow
```

To undo:

```powershell
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=1420
Remove-NetFirewallRule -DisplayName "nbail dev server 1420"
```

**VPNs.** Behind a VPN such as Cloudflare WARP, the tunnel's smaller MTU can make HTTPS hang inside the container while DNS and ping still work. Set `NBAIL_MTU=1280` and run `./vendor/bin/nbail down && ./vendor/bin/nbail up -d`. Image builds already use the host network for this reason.

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

## Android

Publish the compose file with the Android toolchain, then build:

```bash
./vendor/bin/nbail artisan nbail:install --android --force
./vendor/bin/nbail down && ./vendor/bin/nbail build && ./vendor/bin/nbail up -d
./vendor/bin/nbail artisan nativeblade:add android
./vendor/bin/nbail artisan nativeblade:build android
```

Artifacts land in `build/android/`. By default every architecture is built; `--targets=aarch64` builds one, which is faster while testing.

The image adds JDK 17, the Android SDK (platforms 35 and 36, build-tools 35.0.0) and NDK 29.0.14206865, plus the Rust Android targets. The NDK is r28 or newer on purpose: it links native libraries with the 16 KB page size Google Play requires, which rustflags cannot change because the Tauri CLI sets `RUSTFLAGS` itself.

The image is about 2 GB to download (7.5 GB on disk). The first build compiles every Rust crate and takes several minutes; the Cargo registry and Gradle cache persist in named volumes.

### Connecting a phone

The container reaches the phone over Wi-Fi with Android's Wireless debugging (Android 11+), so no USB drivers or adb are needed on your computer. The phone and the computer must be on the same network.

1. On the phone: Developer options, Wireless debugging, "Pair device with pairing code".
2. Pair, then connect with the port shown on the Wireless debugging screen (it differs from the pairing port):

   ```bash
   ./vendor/bin/nbail adb pair 192.168.1.34:42663      # asks for the 6-digit code
   ./vendor/bin/nbail adb connect 192.168.1.34:46777
   ./vendor/bin/nbail adb devices
   ```

Pairing keys live in a named volume, so a phone stays paired across container restarts. The connect port changes whenever Wireless debugging is turned off and on again.

### Live reload on a phone (dev client)

A dev client is a debug build that loads the app from your dev server instead of bundling it, so Blade, PHP and CSS changes show up on the phone as you save. Install it once; it reconnects on its own, with no cable or adb session needed.

The phone must reach port 1420 on your computer. Use your LAN IP and open the port as described in [Platform setup](#platform-setup), or use a tunnel URL (`https://...`).

With a phone connected (see [Connecting a phone](#connecting-a-phone)):

```bash
./vendor/bin/nbail android:devclient 192.168.1.20
```

The command builds the dev client for that address, installs it on the connected phone and starts the dev server. A dev client only depends on the address, so the next time you run it with the same IP it skips the build and install and just starts the dev server. Pass `--rebuild` after changing native code, plugins or the NativeBlade version, and `--targets=aarch64` to build a single architecture.

- No phone connected: it builds, prints how to pair and install, and starts the dev server anyway.
- Several devices connected: set `ANDROID_SERIAL=<serial>` to pick one.
- Tunnel URLs (`https://...`) are not supported by this command.

What it runs, if you prefer the steps:

```bash
./vendor/bin/nbail artisan nativeblade:build android --host=192.168.1.20
./vendor/bin/nbail adb install -r build/android/1.0.0-preview.apk   # <version>-preview.apk
NATIVEBLADE_HOST=192.168.1.20 ./vendor/bin/nbail dev
```

`NATIVEBLADE_HOST` must be the same address as `--host`, so the app polls the right server for PHP and Blade changes.

Requires NativeBlade 37.6.6 or newer. On older versions, a release build made earlier can end up copied as `<version>-preview.apk`; install `src-tauri/gen/android/app/build/outputs/apk/universal/debug/app-universal-debug.apk` instead.

`nativeblade:dev --platform=android` does not work from the container: the Tauri CLI replaces a loopback dev URL with the container's internal IP, which the phone cannot reach. Use the dev client instead.

### Installing a release build

`nativeblade:build android` produces an unsigned release APK, which Android refuses to install. For a quick test on your own phone, sign it with a debug key inside the container, then install it:

```bash
./vendor/bin/nbail shell -c '
  ks=~/.android/debug.keystore; bt=$ANDROID_HOME/build-tools/35.0.0
  [ -f "$ks" ] || keytool -genkeypair -keystore "$ks" -storepass android -alias androiddebugkey \
      -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
  "$bt/zipalign" -f -P 16 4 build/android/1.0.0.apk /tmp/aligned.apk
  "$bt/apksigner" sign --ks "$ks" --ks-pass pass:android --out build/android/1.0.0-debug.apk /tmp/aligned.apk'

./vendor/bin/nbail adb install -r build/android/1.0.0-debug.apk
```

Build for every architecture your phone runs natively. A 64-bit phone that still accepts 32-bit apps will run an armv7-only APK, but recent Android versions warn that the app "isn't compatible with the latest version of Android".

### Host adb server

To use an adb server running on your computer instead (for example a phone on USB), set `NBAIL_ADB_SERVER=tcp:<host-ip>:5037`. The host adb server must listen on that address (`adb -a nodaemon server start`). This has not been tested yet.

## Commands

| Command | What it does |
|---|---|
| `nbail up -d` | Start the container in the background |
| `nbail stop` / `nbail down` | Stop / remove the container |
| `nbail dev` | Browser preview with hot reload |
| `nbail artisan <command>` | Run an Artisan command |
| `nbail composer`, `npm`, `npx`, `node`, `php`, `cargo`, `rustup`, `adb` | Run the tool inside the container |
| `nbail android:devclient <lan-ip>` | Build and install the Android dev client when needed, then start the dev server |
| `nbail shell` / `nbail root-shell` | Open a shell as the app user / as root |
| `nbail build --no-cache` | Rebuild the image |

Anything else is passed to `docker compose`.

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `NB_PORT` | `1420` | Dev server port, used on both the host and the container |
| `NATIVEBLADE_HOST` | `127.0.0.1` | Address the app polls for PHP and Blade hot reload. Set your LAN IP for a phone |
| `WWWUSER` / `WWWGROUP` | your uid / gid | Owner of files the container writes into the project |
| `NBAIL_MTU` | `1500` | MTU of the container network. Set `1280` behind a VPN |
| `NBAIL_ADB_SERVER` | unset | Use an adb server on your computer, e.g. `tcp:192.168.1.20:5037` |

Change the PHP version with `./vendor/bin/nbail artisan nbail:install --php=8.4 --force`, then `./vendor/bin/nbail build`.

## Notes

- Files created in the container belong to your user: the container user takes your uid and gid at startup.
- The Cargo registry is kept in a named volume, so Rust dependencies are downloaded once.

## Roadmap

1. PHP, Composer, Node and Rust with the browser preview
2. Android: SDK, NDK and JDK as an optional image, builds and installs over Wireless debugging
3. Host bridge: a small helper on the host that runs iOS and desktop builds, where Xcode and the platform toolchains live
