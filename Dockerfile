FROM ghcr.io/pelican/panel:latest

USER root

# v2: sync Railway env vars into .env on volume
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080
ENV PORT=8080

ENTRYPOINT ["/entrypoint.sh"]
