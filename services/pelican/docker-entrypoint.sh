#!/bin/ash -e
# shellcheck shell=dash
# Railway-compatible entrypoint for Pelican Panel
#
# Differences from the upstream /entrypoint.sh:
#   - Infra settings (APP_URL, DB_*, REDIS_*) are maintained from the Railway
#     environment instead of the web installer.
#   - First install runs automatically (migrate --force --seed + create-admin.php).
#   - Caddy listens on $PORT (Railway) instead of CADDY_APP_URL.

ENV_FILE=/pelican-data/.env

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

touch "$ENV_FILE"

# --- .env helpers -----------------------------------------------------------
# The panel writes runtime settings into this same file (EnvironmentWriterTrait),
# so we only touch the keys we own and never rewrite the file wholesale.

# set_env KEY VALUE — create or update exactly one key, preserving all other lines.
# Values containing whitespace or quotes are double-quoted (with " escaped) so
# the line is always valid dotenv — an invalid line bricks the panel at boot.
set_env() {
  case "$2" in
    *[[:space:]]*|*"\""*|*"'"*)
      _v="\"$(printf '%s' "$2" | sed 's/"/\\"/g')\""
      ;;
    *)
      _v="$2"
      ;;
  esac
  if grep -q "^$1=" "$ENV_FILE"; then
    # ENVIRON instead of -v: -v processes backslash escapes and would corrupt
    # values like "My \"Weird\" Panel"; ENVIRON passes them through raw.
    _KEY="$1" _VAL="$_v" awk 'BEGIN{FS=OFS="="}
      {if ($1==ENVIRON["_KEY"]) print ENVIRON["_KEY"] "=" ENVIRON["_VAL"]; else print}' \
      "$ENV_FILE" > "$ENV_FILE.tmp" \
      && mv "$ENV_FILE.tmp" "$ENV_FILE"
  else
    printf '%s=%s\n' "$1" "$_v" >> "$ENV_FILE"
  fi
}

# get_env KEY — current value in the file (empty if missing), outer quotes stripped
get_env() {
  _v="$(grep -m1 "^$1=" "$ENV_FILE" 2>/dev/null | head -n1 | cut -d= -f2-)"
  case "$_v" in
    \"*\") _v="${_v#\"}"; _v="${_v%\"}" ;;
    \'*\') _v="${_v#\'}"; _v="${_v%\'}" ;;
  esac
  printf '%s' "$_v"
  true
}

# apply_env KEY DEFAULT — env var wins; else keep existing file value; else DEFAULT
apply_env() {
  eval "value=\${$1:-}"
  if [ -n "$value" ]; then
    set_env "$1" "$value"
  elif [ -z "$(get_env "$1")" ]; then
    set_env "$1" "$2"
  fi
}

# --- Persistent APP_KEY -----------------------------------------------------
# Reuse the key already on the volume; a fresh key on every boot would
# invalidate all sessions and encrypted data.
if [ -z "${APP_KEY:-}" ]; then
  APP_KEY="$(get_env APP_KEY)"
  if [ -z "$APP_KEY" ]; then
    APP_KEY="base64:$(head -c 32 /dev/urandom | base64)"
    echo "No APP_KEY found, generated a new one"
  fi
fi
set_env APP_KEY "$APP_KEY"
echo "APP_KEY fingerprint: $(printf '%s' "$APP_KEY" | sha256sum | cut -c1-12)"

# Install state: environment wins, else the persisted marker in .env
if [ -z "${APP_INSTALLED:-}" ]; then
  APP_INSTALLED="$(get_env APP_INSTALLED)"
fi

# --- Infra keys owned by Railway (refreshed every boot) ----------------------
APP_URL="${APP_URL:-$(get_env APP_URL)}"
APP_URL="${APP_URL:-http://localhost:8080}"
case "$APP_URL" in
  http://*|https://*) : ;;
  *) APP_URL="https://$APP_URL" ;;
esac
set_env APP_URL "$APP_URL"

set_env DB_CONNECTION "${DB_CONNECTION:-pgsql}"
set_env DB_HOST "${DB_HOST:-localhost}"
set_env DB_PORT "${DB_PORT:-5432}"
set_env DB_DATABASE "${DB_DATABASE:-pelican}"
set_env DB_USERNAME "${DB_USERNAME:-pelican}"
set_env DB_PASSWORD "${DB_PASSWORD:-}"
set_env REDIS_HOST "${REDIS_HOST:-localhost}"
set_env REDIS_PORT "${REDIS_PORT:-6379}"
set_env REDIS_USERNAME "${REDIS_USERNAME:-}"
set_env REDIS_PASSWORD "${REDIS_PASSWORD:-}"

# --- Panel-managed / optional keys (never clobber settings changed in the UI)
apply_env APP_NAME "Pelican"
apply_env APP_ENV "production"
apply_env APP_DEBUG "false"
apply_env BEHIND_PROXY "true"
apply_env TRUSTED_PROXIES "*"
apply_env CACHE_DRIVER "redis"
apply_env SESSION_DRIVER "redis"
apply_env QUEUE_CONNECTION "${QUEUE_DRIVER:-redis}"
apply_env MAIL_MAILER "${MAIL_DRIVER:-log}"

# Create required directories
mkdir -p /pelican-data/database /pelican-data/storage/avatars /pelican-data/storage/fonts \
  /pelican-data/storage/icons /pelican-data/storage/app/public /pelican-data/storage/logs \
  /pelican-data/plugins /var/run/supervisord /var/www/html/storage/logs/supervisord
chown -R www-data:www-data /pelican-data /var/www/html/storage 2>/dev/null || true

cd /var/www/html

# --- Database ---------------------------------------------------------------
if [ "${DB_CONNECTION}" != "sqlite" ]; then
  echo "Waiting for database ${DB_HOST}:${DB_PORT}..."
  n=0
  until nc -z -w 10 "${DB_HOST}" "${DB_PORT}" 2>/dev/null; do
    n=$((n+1))
    [ $((n % 15)) -eq 0 ] && echo "Still waiting for database after ${n} attempts..."
    sleep 2
  done
  echo "Database is up."
else
  echo "Using sqlite database."
fi

if [ "${APP_INSTALLED}" != "true" ]; then
  echo "First install: running migrations..."
  php artisan migrate --force --seed
  set_env APP_INSTALLED "true"
  echo "Creating admin user..."
  php /create-admin.php || echo "WARNING: admin creation failed"
  echo "Admin credentials: ${ADMIN_USERNAME:-admin} / ${ADMIN_PASSWORD:-password}"
  php artisan p:plugin:composer
else
  echo "Panel already installed (APP_INSTALLED=true)"
  if [ "${SKIP_MIGRATIONS:-false}" = "true" ]; then
    echo "Skipping migrations (SKIP_MIGRATIONS=true)"
  else
    php artisan migrate --force
  fi
  php artisan p:plugin:composer
fi

echo "Optimizing Filament"
php artisan filament:optimize
# Note: config/route/event caches are intentionally NOT built here. Settings
# live in .env and are edited at runtime, and plugins register providers (and
# routes) at runtime - those caches would freeze them until the next restart.
echo "Caching Blade views"
php artisan view:cache

# --- Caddy ------------------------------------------------------------------
if [ "${SKIP_CADDY:-false}" = "true" ]; then
  echo "SKIP_CADDY=true — starting PHP-FPM only"
  export SUPERVISORD_CADDY=false
else
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
  export SUPERVISORD_CADDY=true
fi

echo "Starting supervisord..."
exec supervisord -c /etc/supervisord.conf