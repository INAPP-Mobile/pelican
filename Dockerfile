FROM ghcr.io/pelican/panel:latest

USER root

# Overwrite upstream entrypoint (called by Railway startCommand)
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 8080
ENV PORT=8080
