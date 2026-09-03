FROM ghcr.io/pelican/panel:latest

USER root

# Railway env-sync entrypoint - forces fresh .env from injected vars
# Timestamp: 2026-09-03T23:50:00Z
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080
ENV PORT=8080
