FROM php:8.4-fpm-alpine@sha256:c16cd1d4efc6a275fe0f039c7bbfcb57dc2577782fb94e3fe387ce0d7e62b7ac AS base

RUN apk add --no-cache \
    nginx \
    supervisor \
    nodejs \
    npm \
    libpng-dev \
    libzip-dev \
    oniguruma-dev \
    && docker-php-ext-install \
        pdo_mysql \
        mbstring \
        zip \
        gd \
        opcache

COPY --from=composer:2@sha256:dc292c5c0f95f526b051d4c341bf08e7e2b18504c74625e3203d7f123050e318 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html


FROM base AS build

COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist

COPY package.json package-lock.json* ./
RUN npm ci

COPY . .
RUN composer dump-autoload --optimize \
    && npm run build


FROM base AS production

COPY --from=build /var/www/html /var/www/html

RUN chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/php-fpm.conf /usr/local/etc/php-fpm.d/www.conf
COPY docker/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
