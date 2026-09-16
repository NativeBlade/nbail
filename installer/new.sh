#!/usr/bin/env bash
# Create a new NativeBlade app when only Docker is installed.
#
#   bash new.sh <app-name> [app-id]
#   curl -fsSL <url-to-new.sh> | bash -s my-app com.example.myapp
#
# Everything (Composer, PHP, Node) runs inside the nbail image; nothing is
# installed on the host.
set -euo pipefail

NAME="${1:-}"
APP_ID="${2:-}"
PHP_VERSION="${NBAIL_PHP_VERSION:-8.5}"
IMAGE="nbail/php-${PHP_VERSION}"

# Where the runtime image is built from until it is published to a registry.
NBAIL_SOURCE="${NBAIL_SOURCE:-https://github.com/NativeBlade/nbail.git#main:runtimes}"
# Composer source for the nbail package until it is published on Packagist.
NBAIL_VCS="${NBAIL_VCS:-https://github.com/NativeBlade/nbail}"
NBAIL_CONSTRAINT="${NBAIL_CONSTRAINT:-@dev}"
# Local checkout of nbail to install instead (for working on nbail itself).
NBAIL_PATH="${NBAIL_PATH:-}"

if [ -z "$NAME" ]; then
    echo "Usage: new.sh <app-name> [app-id]" >&2
    exit 1
fi

if ! [[ "$NAME" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "The app name may only contain letters, numbers, '-' and '_'." >&2
    exit 1
fi

if [ -z "$APP_ID" ]; then
    APP_ID="com.example.$(printf '%s' "$NAME" | tr -cd 'A-Za-z0-9' | tr 'A-Z' 'a-z')"
fi

if ! [[ "$APP_ID" =~ ^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$ ]]; then
    echo "Invalid app id '$APP_ID' (expected something like com.example.myapp)." >&2
    exit 1
fi

if [ -e "$NAME" ]; then
    echo "'$NAME' already exists in $(pwd)." >&2
    exit 1
fi

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "Docker is not installed or not running." >&2
    exit 1
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "==> Building the nbail image (first time only, this takes a few minutes)"
    # Host network: behind a VPN the bridge MTU hangs apt (see stubs/compose.stub).
    docker build --network host -t "$IMAGE" --build-arg PHP_VERSION="$PHP_VERSION" "$NBAIL_SOURCE"
fi

LOCAL_MOUNT=()
if [ -n "$NBAIL_PATH" ]; then
    [ -f "$NBAIL_PATH/composer.json" ] || { echo "NBAIL_PATH has no composer.json: $NBAIL_PATH" >&2; exit 1; }
    LOCAL_MOUNT=(-v "$(cd "$NBAIL_PATH" && pwd)":/nbail:ro)
fi

echo "==> Creating $NAME ($APP_ID)"

# Values reach the container as environment variables, never interpolated into
# the script, so a name or id cannot inject shell code.
docker run --rm \
    --network host \
    --user "$(id -u):$(id -g)" \
    --entrypoint bash \
    -e HOME=/tmp \
    -e COMPOSER_HOME=/tmp/composer \
    -e npm_config_cache=/tmp/npm \
    -e NB_NAME="$NAME" \
    -e NB_APP_ID="$APP_ID" \
    -e NB_PHP_VERSION="$PHP_VERSION" \
    -e NBAIL_VCS="$NBAIL_VCS" \
    -e NBAIL_CONSTRAINT="$NBAIL_CONSTRAINT" \
    -e NBAIL_LOCAL="${NBAIL_PATH:+1}" \
    ${LOCAL_MOUNT[@]+"${LOCAL_MOUNT[@]}"} \
    -v "$(pwd)":/opt \
    -w /opt \
    "$IMAGE" -c '
        set -e
        composer create-project --no-interaction "laravel/laravel:^13.0" "$NB_NAME"
        cd "$NB_NAME"
        composer require --no-interaction nativeblade/nativeblade
        # A regular dependency, not --dev: nativeblade:dev bundles Laravel with
        # "composer install --no-dev", which would delete nbail (and its
        # vendor/bin/nbail wrapper) on the first dev run.
        if [ -n "$NBAIL_LOCAL" ]; then
            # Copy, not symlink: /nbail only exists while this container runs.
            composer config repositories.nbail "{\"type\":\"path\",\"url\":\"/nbail\",\"options\":{\"symlink\":false}}"
            composer require --no-interaction "nativeblade/nbail:@dev"
        else
            composer config repositories.nbail vcs "$NBAIL_VCS"
            composer require --no-interaction "nativeblade/nbail:$NBAIL_CONSTRAINT"
        fi
        php artisan nativeblade:install --name="$NB_NAME" --id="$NB_APP_ID" --template=blank
        php artisan nbail:install --php="$NB_PHP_VERSION"
        npm run build
    '

cat <<EOF

==> $NAME is ready

    cd $NAME
    ./vendor/bin/nbail up -d
    ./vendor/bin/nbail dev

Then open http://localhost:1420
EOF
