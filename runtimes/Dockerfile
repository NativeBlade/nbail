# Stages:
#   toolchain          PHP, Composer, Node, Rust and the app user
#   base               toolchain + entrypoint (browser preview)
#   android-toolchain  toolchain + JDK, Android SDK/NDK, Rust Android targets
#   android            android-toolchain + entrypoint
#
# The entrypoint is copied last in each final stage, so editing
# start-container never invalidates the heavy toolchain layers.

FROM ubuntu:24.04 AS toolchain

LABEL org.opencontainers.image.title="nbail" \
      org.opencontainers.image.description="Development environment for NativeBlade apps: PHP, Composer, Node and Rust"

ARG PHP_VERSION=8.5
ARG NODE_VERSION=22
ARG WWWGROUP=1000

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

WORKDIR /var/www/html

# PHP from the ondrej PPA (8.3, 8.4 and 8.5 on Ubuntu 24.04). Extensions:
# Laravel's baseline plus gd (NativeBlade icon generator) and sqlite3.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl git unzip zip gnupg gosu \
        software-properties-common build-essential pkg-config \
    && add-apt-repository -y ppa:ondrej/php \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        php${PHP_VERSION}-cli php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml \
        php${PHP_VERSION}-curl php${PHP_VERSION}-zip php${PHP_VERSION}-sqlite3 \
        php${PHP_VERSION}-gd php${PHP_VERSION}-intl php${PHP_VERSION}-bcmath \
    && curl -fsSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Rust lives outside any home directory and is writable by every user, because
# the container user's uid is remapped to the host user's at startup.
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable --no-modify-path \
    && chmod -R a+rwX "$RUSTUP_HOME" "$CARGO_HOME"

# Ubuntu 24.04 ships a default "ubuntu" user on uid 1000, which would collide
# with the host uid most Linux users have.
RUN userdel -r ubuntu 2>/dev/null || true \
    && groupadd --force -g "$WWWGROUP" nbail \
    && useradd -ms /bin/bash --no-user-group -g "$WWWGROUP" -u 1337 nbail

EXPOSE 1420

# ---------------------------------------------------------------------------
FROM toolchain AS base

COPY --chmod=0755 start-container /usr/local/bin/start-container

ENTRYPOINT ["start-container"]
CMD ["sleep", "infinity"]

# ---------------------------------------------------------------------------
# Android: JDK, Android SDK and NDK, and the Rust Android targets.
# Versions follow the NativeBlade build farm. NDK r28+ is required: it links
# native libraries with the 16 KB page alignment Google Play demands, and
# rustflags cannot change that because the Tauri CLI sets RUSTFLAGS itself.
# Google only ships the SDK and NDK for x86_64 Linux hosts.
# ---------------------------------------------------------------------------
FROM toolchain AS android-toolchain

ARG ANDROID_CMDLINE_TOOLS=11076708
ARG ANDROID_PLATFORMS="35 36"
ARG ANDROID_BUILD_TOOLS=35.0.0
ARG ANDROID_NDK=29.0.14206865

ENV ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    JAVA_HOME=/usr/lib/jvm/java-17 \
    GRADLE_USER_HOME=/var/cache/nbail/gradle

ENV NDK_HOME=$ANDROID_HOME/ndk/$ANDROID_NDK \
    ANDROID_NDK_HOME=$ANDROID_HOME/ndk/$ANDROID_NDK \
    PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH

RUN apt-get update \
    && apt-get install -y --no-install-recommends openjdk-17-jdk-headless \
    && ln -s "/usr/lib/jvm/java-17-openjdk-$(dpkg --print-architecture)" "$JAVA_HOME" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# The SDK is writable by every user so Gradle can add a missing platform on
# demand, since the container user's uid is remapped at startup.
RUN mkdir -p "$ANDROID_HOME/cmdline-tools" "$GRADLE_USER_HOME" \
    && curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip" -o /tmp/cmdline-tools.zip \
    && unzip -q /tmp/cmdline-tools.zip -d "$ANDROID_HOME/cmdline-tools" \
    && mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest" \
    && rm /tmp/cmdline-tools.zip \
    && yes | sdkmanager --licenses >/dev/null \
    && sdkmanager \
        "platform-tools" \
        "build-tools;${ANDROID_BUILD_TOOLS}" \
        "ndk;${ANDROID_NDK}" \
        $(for api in $ANDROID_PLATFORMS; do printf 'platforms;android-%s ' "$api"; done) \
    && chmod -R a+rwX "$ANDROID_HOME" "$GRADLE_USER_HOME"

RUN rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android \
    && chmod -R a+rwX "$RUSTUP_HOME" "$CARGO_HOME"

# ---------------------------------------------------------------------------
FROM android-toolchain AS android

COPY --chmod=0755 start-container /usr/local/bin/start-container

ENTRYPOINT ["start-container"]
CMD ["sleep", "infinity"]
