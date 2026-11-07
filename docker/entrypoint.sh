#!/bin/sh
set -eu

if [ -z "${APP_KEY:-}" ]; then
    echo "APP_KEY is required. Generate one with: php artisan key:generate --show" >&2
    exit 1
fi
if [ "${DB_CONNECTION:-}" != "pgsql" ] || [ -z "${DB_URL:-}" ]; then
    echo "Set DB_CONNECTION=pgsql and DB_URL to the Render PostgreSQL internal URL." >&2
    exit 1
fi

port="${PORT:-10000}"
case "$port" in
    *[!0-9]*|'') echo "PORT must be a numeric port." >&2; exit 1 ;;
esac

sed "s/__PORT__/${port}/g" /etc/apache2/sites-available/000-default.conf.template \
    > /etc/apache2/sites-available/000-default.conf
printf 'Listen %s\n' "$port" > /etc/apache2/ports.conf

php artisan migrate --force
php artisan config:clear
php artisan view:cache

exec apache2-foreground
