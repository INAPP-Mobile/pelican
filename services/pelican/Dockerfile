FROM ghcr.io/pelican/panel:latest

USER root

# Force cache invalidation: change this value to bust the build cache
ARG CACHE_BUST=20260904t0020

COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080
ENV PORT=8080
