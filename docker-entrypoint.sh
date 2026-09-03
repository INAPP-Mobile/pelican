#!/bin/ash -e
# shellcheck shell=dash
# Modified for Railway — listens on $PORT instead of :80
# Version: 2026-09-03T23:50:00Z-force-env-sync

# Wait for Railway volume to be mounted on /pelican-data
for i in $(seq 1 30); do
  if mount | grep -q "/pelican-data"; then
    break
  fi
  sleep 1
done

# Force-rebuild .env from Railway-injected env vars
{
  echo "APP_NAME=Pelican"
  echo "APP_ENV=${APP_ENV:-production}"
  echo "APP_URL=${APP_URL:-http://localhost}"
  echo "APP_DEBUG=${APP_DEBUG:-false}"
  echo "APP_KEY=${APP_KEY:-base64:$(head -c 32 /dev/urandom | base64)}"
  echo "BEHIND_PROXY=${BEHIND_PROXY:-true}"
  echo "TRUSTED_PROXIES=${TRUSTED_PROXIES:-*}"
  echo "DB_CONNECTION=${DB_CONNECTION:-pgsql}"
  echo "DB_HOST=${DB_HOST:-localhost}"
  echo "DB_PORT=${DB_PORT:-5432}"
  echo "DB_DATABASE=${DB_DATABASE:-pelican}"
  echo "DB_USERNAME=${DB_USERNAME:-pelican}"
  echo "DB_PASSWORD=${DB_PASSWORD:-}"
  echo "REDIS_HOST=${REDIS_HOST:-localhost}"
  echo "REDIS_PORT=${REDIS_PORT:-6379}"
  echo "REDIS_USERNAME=${REDIS_USERNAME:-}"
  echo "REDIS_PASSWORD=${REDIS_PASSWORD:-}"
  echo "CACHE_DRIVER=${CACHE_DRIVER:-redis}"
  echo "SESSION_DRIVER=${SESSION_DRIVER:-redis}"
  echo "QUEUE_CONNECTION=${QUEUE_CONNECTION:-redis}"
  echo "MAIL_DRIVER=${MAIL_DRIVER:-log}"
  echo "SKIP_CADDY=${SKIP_CADDY:-false}"
  echo "APP_INSTALLED=false"
} > /pelican-data/.env

mkdir -p /pelican-data/storage/logs /pelican-data/database /pelican-data/storage/app/public /var/run/supervisord /var/www/html/storage/logs/supervisord
chown -R www-data:www-data /pelican-data /var/www/html/storage 2>/dev/null || true

if [ "${APP_INSTALLED}" != "true" ]; then
  if [ "${DB_CONNECTION}" != "sqlite" ]; then
    until nc -z -v -w30 "${DB_HOST}" "${DB_PORT}"
    do
      sleep 2
    done
  fi
  cd /var/www/html
  php artisan migrate --force --seed
  php artisan p:user:make --admin --no-interaction || true
  echo "APP_INSTALLED=true" >> /pelican-data/.env
fi

exec supervisord -c /etc/supervisord.conf
