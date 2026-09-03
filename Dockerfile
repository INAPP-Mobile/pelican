FROM ghcr.io/pelican/panel:latest

USER root

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Railway injects PORT=8080 — override upstream's EXPOSE 80/443
EXPOSE 8080
ENV PORT=8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/ash", "/entrypoint.sh", "supervisord", "-n", "-c", "/etc/supervisord.conf"]
