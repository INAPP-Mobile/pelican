#!/bin/ash -e
# shellcheck shell=dash
# Modified for Railway — listens on $PORT instead of :80

# check for .env file or symlink and generate app keys if missing
if [ -f /pelican-data/.env ]; then
  echo ".env vars exist."
  for VAR in APP_KEY APP_INSTALLED DB_CONNECTION DB_HOST DB_PORT TRUSTED_PROXIES; do
    echo "checking for ${VAR}"
    eval "CURRENT=\${${VAR}:-}"
    if [ -n "${CURRENT}" ]; then
      echo "${VAR} already set in environment, skipping"
      continue
    fi
    if ! LINE=$(grep -m1 "^${VAR}=" .env); then
      echo "didn't find variable to set"
      continue
    fi
    case "$LINE" in
      *'$('*|*'`'*)
        echo "var in .env may be executable, skipping"
        continue
        ;;
    esac
    echo "loading ${VAR} from .env"
    export "$(echo "$LINE" | tr -d "\r\"'")"
  done
else
  echo ".env vars don't exist."
  touch /pelican-data/.env

  if [ -z "${APP_KEY}" ]; then
    echo "No key set, Generating key."
    APP_KEY="base64:$(head -c 32 /dev/urandom | base64)"
    echo "APP_KEY=$APP_KEY" > /pelican-data/.env
    echo "Generated app key written to .env file"
  else
    echo "APP_KEY exists in environment, using that."
    echo "APP_KEY=${APP_KEY}" > /pelican-data/.env
  fi

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
      sleep 1
    done
  else
    echo "using sqlite database"
  fi
  
  if [ "${SKIP_MIGRATIONS:-false}" = "true" ]; then
    echo "Skipping migrations (SKIP_MIGRATIONS=true)"
  else
    php artisan migrate --force
  fi

  php artisan p:plugin:composer
fi

echo "Optimizing Filament"
php artisan filament:optimize

echo "Caching Blade views"
php artisan view:cache

# --- Railway PORT handling ---
# Railway injects PORT=8080. Listen on PORT instead of :80.
# Override any previous CADDY_APP_URL setting (upstream sets :80 when BEHIND_PROXY=true)
echo "=== Railway PORT handling ==="
echo "PORT=${PORT:-8080}"
echo "BEHIND_PROXY=${BEHIND_PROXY:-not set}"
echo "Overriding CADDY_APP_URL to use Railway PORT"

export SUPERVISORD_CADDY=true
export CADDY_APP_URL=":${PORT:-8080}"
export CADDY_AUTO_HTTPS="auto_https off"
export CADDY_LE_EMAIL=""
export CADDY_TRUSTED_PROXIES=""
export CADDY_STRICT_PROXIES=""
export ASSET_URL="${APP_URL}"

echo "Final CADDY_APP_URL=${CADDY_APP_URL}"
echo "Final SUPERVISORD_CADDY=${SUPERVISORD_CADDY}"
echo "Starting PHP-FPM and Caddy"
echo "Starting Supervisord"

exec supervisord -n -c /etc/supervisord.conf
