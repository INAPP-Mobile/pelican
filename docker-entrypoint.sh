#!/bin/ash -e
# shellcheck shell=dash
# Railway-compatible entrypoint for Pelican Panel
# Writes .env from Railway-injected vars, configures Caddy, runs upstream logic

# Wait for volume mount to accept writes
for i in $(seq 1 60); do
  if mount | grep -q "/pelican-data"; then
    echo "test" > /pelican-data/.write_test 2>/dev/null
    if [ -f /pelican-data/.write_test ]; then
      rm -f /pelican-data/.write_test
      echo "Volume mounted and writable after ${i}s"
      break
    fi
  fi
  sleep 1
done

# Write .env from Railway-injected env vars (Filament installer reads this file directly)
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
  echo "APP_INSTALLED=false"
} > /pelican-data/.env

# Configure Caddy for Railway (listen on Railway's PORT, bind to all interfaces)
export CADDY_APP_URL=":${PORT:-8080}"
export CADDY_AUTO_HTTPS="off"
export CADDY_LE_EMAIL=""
export CADDY_TRUSTED_PROXIES=""
export CADDY_STRICT_PROXIES=""
export SUPERVISORD_CADDY=true

# Create required directories
mkdir -p /pelican-data/storage/logs /pelican-data/database /pelican-data/storage/app/public /pelican-data/plugins /var/run/supervisord /var/www/html/storage/logs/supervisord
chown -R www-data:www-data /pelican-data /var/www/html/storage 2>/dev/null || true

# Run migrations if not installed
if [ "${APP_INSTALLED}" != "true" ]; then
  if [ "${DB_CONNECTION}" != "sqlite" ]; then
    echo "Waiting for database ${DB_HOST}:${DB_PORT}..."
    until nc -z -v -w30 "${DB_HOST}" "${DB_PORT}" 2>/dev/null; do
      sleep 2
    done
  fi
  cd /var/www/html
  echo "Running migrations..."
  php artisan migrate --force --seed
  echo "APP_INSTALLED=true" >> /pelican-data/.env
fi

# Optimize Laravel
cd /var/www/html
php artisan optimize 2>/dev/null || true

echo "Starting supervisord..."
exec supervisord -c /etc/supervisord.conf
