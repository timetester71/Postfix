#!/bin/bash
set -e

# Configure Postfix from environment variables with defaults
MYDESTINATION=${MYDESTINATION:-"mail.example.local, localhost.localdomain, localhost"}
SMTPD_BANNER=${SMTPD_BANNER:-"\$myhostname ESMTP Test Server"}
MYNETWORKS=${MYNETWORKS:-"127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16"}
DISABLE_DNS_LOOKUPS=${DISABLE_DNS_LOOKUPS:-"yes"}
LOCAL_RECIPIENT_MAPS=${LOCAL_RECIPIENT_MAPS:-"hash:/etc/aliases"}
ROOT_ALIASES=${ROOT_ALIASES:-""}

# User configuration
MAIL_USER=${MAIL_USER:-"root"}
MAIL_PASSWORD=${MAIL_PASSWORD:-""}

# Apply configuration
postconf -e "mydestination=${MYDESTINATION}"
postconf -e "smtpd_banner=${SMTPD_BANNER}"
postconf -e "mynetworks=${MYNETWORKS}"
postconf -e "disable_dns_lookups=${DISABLE_DNS_LOOKUPS}"
postconf -e "local_recipient_maps=${LOCAL_RECIPIENT_MAPS}"

# Create custom user if specified and not root
if [ "$MAIL_USER" != "root" ]; then
    # Check if user already exists
    if ! id "$MAIL_USER" &>/dev/null; then
        echo "Creating user: $MAIL_USER"
        useradd -m -s /bin/bash "$MAIL_USER"
        
        # Set password if provided
        if [ -n "$MAIL_PASSWORD" ]; then
            echo "$MAIL_USER:$MAIL_PASSWORD" | chpasswd
            echo "Password set for user: $MAIL_USER"
        fi
    fi
    
    # Ensure mail directory exists with correct permissions
    mkdir -p "/var/mail"
    touch "/var/mail/$MAIL_USER"
    chown "$MAIL_USER:$MAIL_USER" "/var/mail/$MAIL_USER"
    chmod 600 "/var/mail/$MAIL_USER"
fi

# Configure aliases - start with defaults
DEFAULT_ALIASES="postmaster,abuse,noc,support,hostmaster,webmaster"
ALL_ALIASES="${DEFAULT_ALIASES}"

# Append custom aliases if provided
if [ -n "$ROOT_ALIASES" ]; then
    ALL_ALIASES="${ALL_ALIASES},${ROOT_ALIASES}"
fi

# Generate aliases file pointing to configured user
echo "# Auto-generated aliases" > /etc/aliases
echo "root: ${MAIL_USER}" >> /etc/aliases

IFS=',' read -ra ALIAS_ARRAY <<< "$ALL_ALIASES"
for alias in "${ALIAS_ARRAY[@]}"; do
    alias=$(echo "$alias" | xargs)  # trim whitespace
    if [ -n "$alias" ]; then
        echo "$alias: ${MAIL_USER}" >> /etc/aliases
    fi
done

# Add the mail user itself as valid recipient
if [ "$MAIL_USER" != "root" ]; then
    echo "${MAIL_USER}: ${MAIL_USER}" >> /etc/aliases
fi

newaliases

echo "All mail aliases configured to deliver to: $MAIL_USER"

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