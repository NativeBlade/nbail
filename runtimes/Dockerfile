FROM ubuntu:24.04

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

COPY start-container /usr/local/bin/start-container
RUN chmod +x /usr/local/bin/start-container

EXPOSE 1420

ENTRYPOINT ["start-container"]
CMD ["sleep", "infinity"]
