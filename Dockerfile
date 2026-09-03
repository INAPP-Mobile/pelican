FROM ghcr.io/pelican/panel:latest

USER root

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Patch the upstream entrypoint to listen on Railway's PORT instead of :80
# The upstream sets CADDY_APP_URL=:80 when BEHIND_PROXY=true — override with $PORT
RUN sed -i 's|export CADDY_APP_URL=":80"|export CADDY_APP_URL=":${PORT}"|g' /entrypoint.sh

EXPOSE 8080
ENV PORT=8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["supervisord", "-n", "-c", "/etc/supervisord.conf"]
