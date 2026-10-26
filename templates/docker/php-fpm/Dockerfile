FROM php:{{PHP_VERSION}}-fpm

ENV COMPOSER_MEMORY_LIMIT='-1'

# Work around "Hash Sum mismatch" errors behind caching proxies
RUN printf 'Acquire::http::Pipeline-Depth 0;\nAcquire::http::No-Cache true;\nAcquire::BrokenProxy true;\n' > /etc/apt/apt.conf.d/99fixbadproxy

# The PGDG suite is derived from the base image's Debian release (VERSION_CODENAME),
# so it stays correct when the php:*-fpm tag moves to a newer Debian.
RUN apt-get update && \
    apt-get install -y wget gnupg && \
    # Add PostgreSQL Repo
    wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg && \
    . /etc/os-release && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt ${VERSION_CODENAME}-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    # Add Ngrok Repo
    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && \
    echo "deb https://ngrok-agent.s3.amazonaws.com bookworm main" | tee /etc/apt/sources.list.d/ngrok.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        pkg-config \
        libssl-dev \
        openssh-server \
        git \
        cron \
        nano \
        vim \
        libreadline-dev \
        libicu-dev \
        libzip-dev \
        libgmp-dev \
        libpq-dev \
        postgresql-client-{{PG_CLIENT_VERSION}} \
        unzip \
        ngrok && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

{{NODE_APT_BLOCK}}

# Group 1: Stable extensions — no configure step needed
RUN docker-php-ext-install pdo_pgsql pgsql bcmath gmp sockets pcntl

# Group 2: Extensions that require explicit configure
RUN docker-php-ext-configure intl && docker-php-ext-install intl
RUN docker-php-ext-configure zip && docker-php-ext-install zip

RUN docker-php-source delete

#####################################
# xDebug:
#####################################

# Install the xdebug extension. `pecl config-set php_ini` is required because PECL cannot
# locate php.ini in the official image (it uses conf.d/). With it set, `pecl install`
# writes a zend_extension line into that file, which would activate xdebug at build time;
# remove it so xdebug stays inactive (zero overhead) until docker-entrypoint.sh enables it
# at container start when XDEBUG_MODE is set.
RUN pecl config-set php_ini /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    pecl install xdebug && \
    rm -f /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

#####################################
# Composer:
#####################################

# Install composer from the official image.
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

#####################################
# Laravel Schedule Cron Job:
#####################################
RUN echo "* * * * * www-data /usr/local/bin/php /var/www/laravel/current/artisan schedule:run >> /dev/null 2>&1" >> /etc/cron.d/laravel-scheduler
RUN chmod 0644 /etc/cron.d/laravel-scheduler

COPY laravel.ini /usr/local/etc/php/conf.d/laravel.ini
# php-fpm pool settings (pm.*) are not valid in conf.d ini files; zz- sorts after zz-docker.conf
COPY php-fpm-pool.conf /usr/local/etc/php-fpm.d/zz-laravel.conf

RUN usermod -u 1000 www-data

# Create ngrok config directory and give ownership to www-data so Pest tests can configure it
RUN mkdir -p /var/www/.config/ngrok && chown -R www-data:www-data /var/www/.config

# SSH server so that Tinkerwell can connect in (sshd settings belong in sshd_config.d)
RUN mkdir -p /var/run/sshd
RUN useradd -m -s /bin/bash devuser && echo 'devuser:password' | chpasswd
RUN printf 'PasswordAuthentication yes\nPermitRootLogin no\n' > /etc/ssh/sshd_config.d/10-laravel-dev.conf

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
# Strip CRs in case the repo was checked out with Windows line endings
RUN sed -i 's/\r//g' /usr/local/bin/docker-entrypoint.sh && chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["php-fpm"]
