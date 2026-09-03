FROM ghcr.io/pelican/panel:latest

USER root

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Patch Caddyfile to listen on Railway's injected PORT
# The upstream entrypoint hardcodes CADDY_APP_URL=:80 when BEHIND_PROXY=true
# Railway forwards PORT=8080 to the container, so Caddy must listen on PORT
RUN sed -i 's/{CADDY_APP_URL}/{$PORT}/g' /etc/caddy/Caddyfile

EXPOSE 8080
ENV PORT=8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["supervisord", "-n", "-c", "/etc/supervisord.conf"]
