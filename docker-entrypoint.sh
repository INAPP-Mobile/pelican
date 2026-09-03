#!/bin/ash -e
# shellcheck shell=dash
# Modified for Railway — listens on $PORT instead of :80

# Wait for Railway volume to be mounted on /pelican-data
# The entrypoint runs BEFORE the bind-mount completes, so we must wait
# otherwise our .env writes get hidden by the mount.
for i in $(seq 1 30); do
  if mount | grep -q "/pelican-data"; then
    break
  fi
  sleep 1
done

# Force-rebuild .env from Railway-injected env vars on every boot.
# Pelican's installer reads .env directly; stale values on volume cause
# the installer to prompt for connection info despite DB/REDIS being wired.
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

# create directories for volumes
mkdir -p /pelican-data/storage/logs /pelican-data/database /pelican-data/storage/app/public /var/run/supervisord /var/www/html/storage/logs/supervisord

# Fix ownership — Railway volume is root-mounted, panel runs as www-data
chown -R www-data:www-data /pelican-data /var/www/html/storage 2>/dev/null || true

# only run installer if app is not installed
if [ "${APP_INSTALLED}" != "true" ]; then
  if [ "${DB_CONNECTION}" != "sqlite" ]; then
    echo "Checking database status."
    until nc -z -v -w30 "${DB_HOST}" "${DB_PORT}"
    do
      echo "Waiting for database connection..."
      sleep 2
    done
    echo "Database is reachable."
  fi
  echo "Running migrations..."
  cd /var/www/html
  php artisan migrate --force --seed

  echo "Creating initial user..."
  php artisan p:user:make --admin --no-interaction || true

  echo "APP_INSTALLED=true" >> /pelican-data/.env
fi

# Patch Caddy app URL to Railway PORT if not already set
if [ -n "${PORT}" ]; then
  grep -q "^CADDY_APP_URL=" /pelican-data/.env && \
    sed -i "s|^CADDY_APP_URL=.*|CADDY_APP_URL=\"\${PORT}\"|" /pelican-data/.env || \
    echo "CADDY_APP_URL=\"\${PORT}\"" >> /pelican-data/.env
fi

# Start supervisord
exec supervisord -c /etc/supervisord.conf
