FROM nginx:alpine

# bash is required by startup.sh; openssl for the self-signed fallback cert;
# logrotate + curl for log housekeeping and health checks.
# startup.sh also needs envsubst, which the official nginx image ships; fail the build
# loudly if a future base image stops providing it.
RUN apk add --no-cache logrotate openssl bash curl \
    && command -v envsubst

# www-data (GID/UID 82) matches the php-fpm image so shared volumes have consistent ownership.
# Only create what is missing, so a genuine addgroup/adduser failure still fails the build.
RUN getent group www-data >/dev/null || addgroup -g 82 -S www-data \
    && getent passwd www-data >/dev/null || adduser -u 82 -D -S -G www-data www-data

# Upstream php-fpm address; defaults match the `php-fpm` service in docker-compose.yml.
ARG PHP_UPSTREAM_CONTAINER=php-fpm
ARG PHP_UPSTREAM_PORT=9000

# Alpine's stock /etc/logrotate.conf may reference /var/log/messages; make sure it exists
# so the daily logrotate run doesn't error on a missing file.
RUN touch /var/log/messages

COPY logrotate/nginx /etc/logrotate.d/nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Upstream definition referenced by `fastcgi_pass php-upstream;` in sites/laravel.conf.
# Remove the stock default site so only the project's conf is served.
RUN echo "upstream php-upstream { server ${PHP_UPSTREAM_CONTAINER}:${PHP_UPSTREAM_PORT}; }" > /etc/nginx/conf.d/upstream.conf \
    && rm -f /etc/nginx/conf.d/default.conf

# sites-available/ and ssl/ are bind-mounted by docker-compose.yml. startup.sh renders
# sites-available/*.conf into the container-local sites-enabled/ (nginx.conf includes that).
RUN mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/ssl /var/log/nginx

COPY startup.sh /opt/startup.sh
# Strip CRs in case the repo was checked out with Windows line endings
RUN sed -i 's/\r//g' /opt/startup.sh
CMD ["/bin/bash", "/opt/startup.sh"]

EXPOSE 80 443
