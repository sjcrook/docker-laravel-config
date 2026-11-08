#!/bin/bash

# Start the cron service (runs the Laravel scheduler: artisan schedule:run).
# This cron is inside the php-fpm container and is entirely separate from the
# nginx reload cron in startup.sh (which runs inside the nginx container).
if [ "yes" == "${RUN_CRON}" ]; then
    echo "Starting cron"
    cron -f &
fi

rm -f /var/log/xdebug.log

# Add xdebug configuration at container start (not at build time).
# The xdebug .so is present in the image (installed by pecl in Dockerfile)
# but is not active until this block runs. A container with XDEBUG_MODE=''
# skips this block entirely - xdebug is never loaded and has zero overhead.
if [ ! -z "${XDEBUG_MODE}" ]; then
    echo "Enabling xdebug"
    docker-php-ext-enable xdebug && \
    echo "zend_extension=xdebug"                      >  /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
    echo "xdebug.mode=$XDEBUG_MODE"                   >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
    echo "xdebug.start_with_request=yes"              >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
    echo "xdebug.client_host=host.docker.internal"    >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
    echo "xdebug.log=/var/log/xdebug.log"             >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
fi

# Inject opcache.enable_cli at runtime so it can be toggled via docker-compose.yml
# without rebuilding the image. The last occurrence of a setting wins, so appending
# here overrides anything earlier. Any line left by a previous start of this same
# container (docker restart) is removed first so the file does not accumulate lines.
#
# OPCACHE_ENABLE_CLI=0 (default in docker-compose.yml):
#   CLI processes (artisan, Tinkerwell SSH) always see fresh files - no stale-cache issues.
#
# OPCACHE_ENABLE_CLI=1 (set in docker-compose.yml for queue worker performance testing):
#   CLI opcache enabled; do not use when interactively editing code during the same session.
perl -i -ne 'print unless /^opcache\.enable_cli=/' /usr/local/etc/php/conf.d/laravel.ini
echo "opcache.enable_cli=$OPCACHE_ENABLE_CLI" >> /usr/local/etc/php/conf.d/laravel.ini

# Start the SSH server so that Tinkerwell can connect.
/usr/sbin/sshd -D &

exec "$@"
