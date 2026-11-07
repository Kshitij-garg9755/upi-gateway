FROM node:22-alpine AS assets
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY resources ./resources
COPY vite.config.js .
COPY public ./public
RUN npm run build

FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --no-progress --prefer-dist --no-scripts

FROM php:8.3-apache
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
WORKDIR /var/www/html

RUN apt-get update && apt-get install -y --no-install-recommends \
        libfreetype6-dev libicu-dev libjpeg62-turbo-dev libonig-dev libpng-dev libpq-dev libzip-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" bcmath gd intl mbstring opcache pdo_mysql pdo_pgsql zip \
    && a2enmod rewrite headers \
    && rm -rf /var/lib/apt/lists/*

COPY --from=vendor /app/vendor ./vendor
COPY . .
COPY --from=assets /app/public/build ./public/build
COPY docker/apache-site.conf.template /etc/apache2/sites-available/000-default.conf.template
COPY docker/entrypoint.sh /usr/local/bin/cloudnova-gateway-entrypoint
RUN chmod +x /usr/local/bin/cloudnova-gateway-entrypoint \
    && mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && php artisan package:discover --ansi

EXPOSE 10000
ENTRYPOINT ["cloudnova-gateway-entrypoint"]
