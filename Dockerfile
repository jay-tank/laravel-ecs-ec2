# syntax=docker/dockerfile:1
# PHP-FPM application image for the Laravel app container.
FROM php:8.1-fpm-alpine

WORKDIR /var/www

# System libraries + PHP extensions required by Laravel.
# Build-only packages are installed in a virtual group and removed afterwards
# to keep the final image small.
RUN apk add --no-cache \
        freetype-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        libzip-dev \
        zip unzip git curl \
        jpegoptim optipng pngquant gifsicle \
    && apk add --no-cache --virtual .build-deps autoconf build-base \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_mysql zip exif pcntl gd \
    && pecl channel-update pecl.php.net \
    && pecl install -o -f redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps \
    && rm -rf /tmp/pear

# Composer (from the official image).
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# PHP runtime configuration.
COPY ./config/php/local.ini /usr/local/etc/php/conf.d/local.ini

# Non-root application user.
RUN addgroup -g 1000 -S www && adduser -u 1000 -S www -G www

# Copy the application source and install dependencies.
COPY . /var/www
RUN composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist --no-scripts \
    && chown -R www:www /var/www \
    && chmod -R 775 storage bootstrap/cache

USER www

# PHP-FPM listens on 9000 for FastCGI requests from the Nginx container.
EXPOSE 9000
CMD ["php-fpm"]
