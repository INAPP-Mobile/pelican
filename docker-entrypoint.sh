#!/bin/ash -e
# Railway wrapper for Pelican Panel
# Handles Railway's PORT injection and volume setup

# Create volume dirs
mkdir -p /pelican-data /var/www/html/storage/logs

# Ensure upstream entrypoint is executable (permission safeguard)
chmod +x /entrypoint.sh 2>/dev/null || true

# Run original entrypoint (preserves .env loading, APP_KEY generation, etc.)
exec /entrypoint.sh "$@"
