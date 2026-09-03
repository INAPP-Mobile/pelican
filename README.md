# Deploy and Host

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.com/deploy/pelican)

Pelican Panel — open-source game server management panel with a clean UI, egg-based server templates, and multi-server support. Self-host your game servers with automated deployment, monitoring, and user management.

## System Requirements

- **Disk:** 10GB+ for panel data (configs, plugins, logs)
- **Memory:** 512 MB RAM minimum (1 GB+ recommended)
- **Network:** HTTP/HTTPS access for panel UI
- **Database:** SQLite (default) or external MySQL/PostgreSQL

## About Hosting

This template runs Pelican Panel on Railway with Caddy as the built-in web server. Panel data persists on a Railway volume mounted at `/pelican-data` — configs, plugins, and logs survive deploys and restarts.

The entrypoint configures Caddy to listen on Railway's injected `PORT` (8080) and disables auto-https since Railway handles SSL termination at the proxy layer.

**First-run setup:**
1. After deploy, open the panel URL
2. Complete the installation wizard (database, admin account, site settings)
3. Add game servers (nodes) and eggs to start hosting

Key environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_URL` | `http://localhost` | Public URL for the panel |
| `LE_EMAIL` | *(empty)* | Let's Encrypt email (required for HTTPS) |
| `APP_ENV` | `production` | Application environment |
| `APP_DEBUG` | `false` | Debug mode |
| `DB_CONNECTION` | `sqlite` | Database driver (sqlite/mysql/pgsql) |
| `CACHE_DRIVER` | `file` | Cache driver (file/redis/memcached) |
| `SESSION_DRIVER` | `file` | Session driver (file/redis/cookie/database) |
| `QUEUE_DRIVER` | `database` | Queue driver (database/redis/sync) |
| `MAIL_DRIVER` | `log` | Mail driver (log/smtp) |
| `TRUSTED_PROXIES` | *(empty)* | Comma-separated trusted proxy IPs |
| `BEHIND_PROXY` | `false` | Set true if behind Cloudflare/reverse proxy |

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 8080 | TCP | Panel web UI (Caddy) |

## Why Deploy

- **One-click deploy**: no manual server setup or Docker knowledge required
- **Persistent data**: configs, plugins, and logs survive restarts
- **Built-in web server**: Caddy auto-configures with Railway's proxy
- **Open source**: free, community-driven alternative to commercial panels

## Common Use Cases

- Host game servers (Minecraft, CS2, Valheim, etc.) for friends
- Manage multiple game servers across different nodes
- Provide game server hosting as a service
- Self-host a Pterodactyl alternative

## Dependencies for

This template has no external service dependencies — everything runs in a single container with a persistent volume. SQLite is used by default; for production with high traffic, consider an external MySQL/PostgreSQL database.

### Deployment Dependencies

- A Railway account
- A domain (optional — Railway provides a default domain)
