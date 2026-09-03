#!/bin/ash -e
# Railway wrapper for Pelican Panel
# Handles Railway's PORT injection and volume setup

# Create volume dirs
mkdir -p /pelican-data /var/www/html/storage/logs

# Railway injects PORT=8080 — Caddy must listen on it
# The upstream entrypoint overrides CADDY_APP_URL only when BEHIND_PROXY=true
# So we set BEHIND_PROXY=false to prevent the override, then set our own Caddy vars
if [ -n "${PORT}" ]; then
  echo "Railway PORT=${PORT} — configuring Caddy to listen on ${PORT}"
  export BEHIND_PROXY="false"
  export CADDY_APP_URL=":${PORT}"
  export CADDY_AUTO_HTTPS="auto_https off"
  export CADDY_LE_EMAIL=""
fi

# Ensure upstream entrypoint is executable (permission safeguard)
chmod +x /entrypoint.sh 2>/dev/null || true

# Run original entrypoint (preserves .env loading, APP_KEY generation, etc.)
exec /entrypoint.sh "$@"
