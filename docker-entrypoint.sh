#!/bin/bash
set -e

# Configure Postfix from environment variables with defaults
MYDESTINATION=${MYDESTINATION:-"mail.example.local, localhost.localdomain, localhost"}
SMTPD_BANNER=${SMTPD_BANNER:-"\$myhostname ESMTP Test Server"}
MYNETWORKS=${MYNETWORKS:-"127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16"}
DISABLE_DNS_LOOKUPS=${DISABLE_DNS_LOOKUPS:-"yes"}
LOCAL_RECIPIENT_MAPS=${LOCAL_RECIPIENT_MAPS:-"hash:/etc/aliases"}
ROOT_ALIASES=${ROOT_ALIASES:-""}

# Apply configuration
postconf -e "mydestination=${MYDESTINATION}"
postconf -e "smtpd_banner=${SMTPD_BANNER}"
postconf -e "mynetworks=${MYNETWORKS}"
postconf -e "disable_dns_lookups=${DISABLE_DNS_LOOKUPS}"
postconf -e "local_recipient_maps=${LOCAL_RECIPIENT_MAPS}"

# Configure aliases for root - start with defaults
DEFAULT_ALIASES="postmaster,abuse,noc,support,hostmaster,webmaster,root"
ALL_ALIASES="${DEFAULT_ALIASES}"

# Append custom aliases if provided
if [ -n "$ROOT_ALIASES" ]; then
    ALL_ALIASES="${ALL_ALIASES},${ROOT_ALIASES}"
fi

# Generate aliases file
echo "# Auto-generated aliases" > /etc/aliases
IFS=',' read -ra ALIAS_ARRAY <<< "$ALL_ALIASES"
for alias in "${ALIAS_ARRAY[@]}"; do
    alias=$(echo "$alias" | xargs)  # trim whitespace
    if [ -n "$alias" ]; then
        echo "$alias: root" >> /etc/aliases
    fi
done
newaliases

# Fix Postfix spool directory permissions
chown root:root /var/spool/postfix
chown root:root /var/spool/postfix/pid
chown postfix:postdrop /var/spool/postfix/public
chown postfix:postdrop /var/spool/postfix/maildrop
chown root:root /var/spool/postfix/etc
chown root:root /var/spool/postfix/lib
chown root:root /var/spool/postfix/usr
chown -R root:root /var/spool/postfix/usr/lib 2>/dev/null || true

# Set proper permissions
chmod 755 /var/spool/postfix
chmod 730 /var/spool/postfix/public
chmod 730 /var/spool/postfix/maildrop

# Start Postfix in foreground
exec "$@"