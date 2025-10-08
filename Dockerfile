FROM debian:bookworm-slim

# Install Postfix and necessary tools
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    postfix \
    mailutils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure Postfix basic settings (will be overridden by entrypoint if env vars are set)
RUN postconf -e "myhostname=mail.example.local" \
    && postconf -e "inet_interfaces=all" \
    && postconf -e "inet_protocols=ipv4" \
    && postconf -e "relay_domains=" \
    && postconf -e "maillog_file=/dev/stdout" \
    && postconf -e "lmtp_host_lookup=native" \
    && postconf -e "smtp_host_lookup=native" \
    && postconf -e "default_transport=local" \
    && postconf -e "relay_transport=local" \
    && postconf -e "local_recipient_maps=hash:/etc/aliases"

# Create necessary directories
RUN mkdir -p /var/spool/postfix /var/mail

# Copy startup script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose SMTP port
EXPOSE 25

# Start Postfix
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["postfix", "start-fg"]