#!/bin/ash -e
# shellcheck shell=dash
# Modified for Railway — listens on $PORT instead of :80

# Ensure .env exists on volume
if [ ! -f /pelican-data/.env ]; then
  touch /pelican-data/.env
fi

# Sync Railway-injected env vars into .env file
# (Installer reads .env directly; Railway injects at container level)
ENV_SYNC_VARS="APP_KEY APP_INSTALLED APP_URL APP_ENV DB_CONNECTION DB_HOST DB_PORT DB_DATABASE DB_USERNAME DB_PASSWORD REDIS_HOST REDIS_PORT REDIS_USERNAME REDIS_PASSWORD CACHE_DRIVER SESSION_DRIVER QUEUE_DRIVER TRUSTED_PROXIES"

for VAR in $ENV_SYNC_VARS; do
  eval "VAL=\${${VAR}:-}"
  if [ -n "$VAL" ]; then
    if grep -q "^${VAR}=" /pelican-data/.env; then
      sed -i "s|^${VAR}=.*|${VAR}=${VAL}|" /pelican-data/.env
    else
      echo "${VAR}=${VAL}" >> /pelican-data/.env
    fi
  fi
done

# Generate APP_KEY if missing (first run)
if [ -z "${APP_KEY}" ]; then
  echo "No key set, Generating key."
  APP_KEY="base64:$(head -c 32 /dev/urandom | base64)"
  if grep -q "^APP_KEY=" /pelican-data/.env; then
    sed -i "s|^APP_KEY=.*|APP_KEY=$APP_KEY|" /pelican-data/.env
  else
    echo "APP_KEY=$APP_KEY" >> /pelican-data/.env
  fi
  echo "Generated app key written to .env file"
fi

# Ensure APP_INSTALLED is in .env
if ! grep -q "^APP_INSTALLED=" /pelican-data/.env; then
  echo "APP_INSTALLED=false" >> /pelican-data/.env
fi

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
