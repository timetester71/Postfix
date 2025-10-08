FROM debian:bookworm-slim

# Install Postfix, Dovecot, and necessary tools
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    postfix \
    mailutils \
    sasl2-bin \
    libsasl2-modules \
    dovecot-imapd \
    dovecot-lmtpd \
    supervisor \
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

# Create supervisor config directory
RUN mkdir -p /etc/supervisor/conf.d

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Expose SMTP and IMAP ports
EXPOSE 25 143

# Start services via supervisor
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]