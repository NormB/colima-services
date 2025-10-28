FROM edoburu/pgbouncer:latest

# Install dependencies for Vault integration
USER root
RUN apk add --no-cache wget jq postgresql-client

# Copy init script
COPY scripts/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

# Create .pgpass directory for pgbouncer user
RUN mkdir -p /var/lib/postgresql && \
    chown -R 70:70 /var/lib/postgresql

# Switch back to pgbouncer user (uid 70)
USER 70

# Use init script as entrypoint
ENTRYPOINT ["/usr/local/bin/init.sh"]

# Pass original CMD arguments to entrypoint
CMD ["/usr/bin/pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
