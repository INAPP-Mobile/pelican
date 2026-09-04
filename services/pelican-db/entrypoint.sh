#!/bin/bash
set -e

# Prepare data directory
mkdir -p /var/lib/postgresql/data/pgdata
chown -R postgres:postgres /var/lib/postgresql /var/lib/postgresql/data 2>/dev/null
rm -f /var/lib/postgresql/data/pgdata/postmaster.pid 2>/dev/null

export PGDATA=/var/lib/postgresql/data/pgdata

# Ensure Postgres listens on all interfaces so Railway private networking can reach it.
cat >> /etc/postgresql/pg_hba.conf <<'HBA'
host  all  all  10.0.0.0/8  md5
host  all  all  127.0.0.1/32  trust
host  all  all  ::1/128  trust
HBA

# Start postgres in background, forcing listen on all interfaces.
docker-entrypoint.sh postgres \
  -c config_file=/etc/postgresql/postgresql.conf \
  -c data_directory=/var/lib/postgresql/data/pgdata \
  -c listen_addresses='*' &
PG_PID=$!

# Wait for postgres to be ready
wait_for_ready() {
  for i in $(seq 1 60); do
    if su postgres -c "pg_isready -h 127.0.0.1 -p 5432" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

echo "Waiting for postgres to start..."
if ! wait_for_ready; then
  echo "Postgres did not become ready in time." >&2
  kill $PG_PID 2>/dev/null || true
  wait $PG_PID 2>/dev/null || true
  exit 1
fi
echo "Postgres is ready."

# Create the pelican database and user if they don't exist
su postgres -c "psql -h 127.0.0.1 -U postgres" <<SQL || true
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${POSTGRES_USER:-pelican}') THEN
    CREATE ROLE ${POSTGRES_USER:-pelican} LOGIN PASSWORD '${POSTGRES_PASSWORD:-pelican}';
  END IF;
END
\$\$;
SQL

su postgres -c "psql -h 127.0.0.1 -U postgres -c \"CREATE DATABASE ${POSTGRES_DB:-pelican} OWNER ${POSTGRES_USER:-pelican};" || true

echo "Database setup complete."

# Bring postgres to foreground
wait $PG_PID
