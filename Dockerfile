FROM ghcr.io/pelican/panel:latest

USER root

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Patch upstream entrypoint: don't overwrite CADDY_APP_URL if already set by wrapper
# Line 99: export CADDY_APP_URL="${APP_URL}" → conditional
RUN sed -i 's|^export CADDY_APP_URL="${APP_URL}"|if [ -z "${CADDY_APP_URL}" ]; then export CADDY_APP_URL="${APP_URL}"; fi|' /entrypoint.sh
# Also patch the BEHIND_PROXY block to use $PORT instead of :80
RUN sed -i 's|export CADDY_APP_URL=":80"|export CADDY_APP_URL=":${PORT}"|g' /entrypoint.sh

EXPOSE 8080
ENV PORT=8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["supervisord", "-n", "-c", "/etc/supervisord.conf"]
