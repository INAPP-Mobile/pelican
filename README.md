# Deploy and Host

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.com/deploy/pelican)

Pelican Panel — open-source game server management panel with a clean UI, egg-based server templates, and multi-server support. Self-host your game servers with automated deployment, monitoring, and user management.

## Source Repository

[https://github.com/INAPP-Mobile/pelican](https://github.com/INAPP-Mobile/pelican)

## System Requirements

- **Disk:** 10GB+ for panel data (configs, plugins, logs)
- **Memory:** 512 MB RAM minimum (1 GB+ recommended)
- **Network:** HTTP/HTTPS access for panel UI

## About Hosting

This template deploys three services: **pelican** (the panel), **pelican-db** (PostgreSQL 16), and **pelican-redis** (Redis 7). Database and Redis variables are pre-wired with companion references — no manual configuration needed.

Panel data persists on a Railway volume mounted at `/pelican-data` — configs, plugins, and logs survive deploys and restarts.

**First-run setup: none.** The entrypoint runs migrations and seeds automatically on boot, then creates an admin account:

- **Username:** `admin`
- **Password:** `password`

Log in and change the admin credentials from the settings page immediately after your first deploy.

The panel serves traffic through Caddy listening on Railway's injected `PORT`; Railway handles SSL termination at the proxy layer.

Key environment variables (pre-configured):

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_URL` | `${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL for the panel |
| `APP_ENV` | `production` | Application environment |
| `APP_DEBUG` | `false` | Debug mode |
| `DB_CONNECTION` | `pgsql` | Database driver |
| `DB_HOST` | `${{pelican-db.RAILWAY_PRIVATE_DOMAIN}}` | Postgres companion host |
| `CACHE_DRIVER` | `redis` | Cache driver |
| `SESSION_DRIVER` | `redis` | Session driver |
| `QUEUE_DRIVER` | `redis` | Queue driver |
| `MAIL_DRIVER` | `log` | Mail driver (log/smtp) |
| `TRUSTED_PROXIES` | `*` | Trusted proxy IPs |
| `BEHIND_PROXY` | `true` | Behind Railway's reverse proxy |

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 8080 | TCP | Panel web UI (Caddy) |

## Why Deploy

- **One-click deploy**: no manual server setup or Docker knowledge required
- **Zero-config install**: migrations, seeds, and admin account run automatically
- **Persistent data**: configs, plugins, and logs survive restarts
- **Companion database + cache**: Postgres and Redis included, pre-wired
- **Open source**: free, community-driven alternative to commercial panels

## Common Use Cases

- Host game servers (Minecraft, CS2, Valheim, etc.) for friends
- Manage multiple game servers across different nodes
- Provide game server hosting as a service
- Self-host a Pterodactyl alternative

## Dependencies for Pelican

This template includes two companion services that deploy alongside the panel.

### Deployment Dependencies

- **pelican-db** — PostgreSQL 16 database for panel data
- **pelican-redis** — Redis 7 for cache, sessions, and queues
- A Railway account