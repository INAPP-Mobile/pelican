#!/bin/ash -e
# shellcheck shell=dash
# Railway-compatible entrypoint for Pelican Panel

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
  # Ensure APP_URL has a scheme (Laravel doubles domain in redirects otherwise)
  case "$APP_URL" in
    http://*|https://*) : ;;
    *) APP_URL="https://$APP_URL" ;;
  esac
  echo "APP_URL=${APP_URL}"
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
} > /pelican-data/.env

# Write a Railway-compatible Caddyfile
cat > /etc/caddy/Caddyfile <<CADDYFILE
{
    admin off
}

:${PORT:-8080} {
    root * /var/www/html/public
    encode gzip

    file_server
    php_fastcgi 127.0.0.1:9000
}
CADDYFILE

# Set supervisor to run caddy
export SUPERVISORD_CADDY=true

# Create required directories
mkdir -p /pelican-data/storage/logs /pelican-data/database /pelican-data/storage/app/public /pelican-data/plugins /var/run/supervisord /var/www/html/storage/logs/supervisord
chown -R www-data:www-data /pelican-data /var/www/html/storage 2>/dev/null || true

# Run migrations if not installed
export APP_INSTALLED=false
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

  # Auto-create admin user
  echo "=== ADMIN CREATION DEBUG ==="
  cd /var/www/html
  php artisan tinker --execute="echo 'tinker works';" 2>&1 || echo "tinker failed"
  php artisan tinker --execute="echo \App\Models\User::count();" 2>&1 || echo "User model check failed"
  echo "=== END DEBUG ==="
  echo "Creating admin user..."
  php artisan p:user:make \
    --email="${ADMIN_EMAIL:-admin@example.com}" \
    --username="${ADMIN_USERNAME:-admin}" \
    --password="${ADMIN_PASSWORD:-password}" \
    --admin=true 2>&1 || echo "p:user:make failed"
  echo "Admin credentials: ${ADMIN_USERNAME:-admin} / ${ADMIN_PASSWORD:-password}"
fi

# Optimize Laravel
cd /var/www/html
php artisan optimize 2>/dev/null || true

echo "Starting supervisord..."
exec supervisord -c /etc/supervisord.conf
