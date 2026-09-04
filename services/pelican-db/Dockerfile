FROM supabase/postgres:15.8.1.085
# Volume mount: /var/lib/postgresql/data
# PGDATA: /var/lib/postgresql/data/pgdata
#
# Custom entrypoint: grants schema ownership to 'postgres' user on startup
COPY entrypoint.sh /custom-entrypoint.sh
RUN chmod +x /custom-entrypoint.sh
EXPOSE 5432
