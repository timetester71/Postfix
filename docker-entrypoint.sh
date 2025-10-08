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
# Use associative array to track unique aliases
declare -A UNIQUE_ALIASES

echo "# Auto-generated aliases" > /etc/aliases
echo "root: ${MAIL_USER}" >> /etc/aliases

IFS=',' read -ra ALIAS_ARRAY <<< "$ALL_ALIASES"
for alias in "${ALIAS_ARRAY[@]}"; do
    alias=$(echo "$alias" | xargs)  # trim whitespace
    if [ -n "$alias" ] && [ -z "${UNIQUE_ALIASES[$alias]}" ]; then
        echo "$alias: ${MAIL_USER}" >> /etc/aliases
        UNIQUE_ALIASES[$alias]=1
    fi
done

# Add the mail user itself as valid recipient only if not already added
if [ "$MAIL_USER" != "root" ] && [ -z "${UNIQUE_ALIASES[$MAIL_USER]}" ]; then
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

# Configure Dovecot
echo "Configuring Dovecot..."

# Configure mail location (mbox format in /var/mail)
cat > /etc/dovecot/conf.d/10-mail.conf <<EOF
mail_location = mbox:~/:INBOX=/var/mail/%u
mail_privileged_group = mail
mbox_write_locks = fcntl

namespace inbox {
  inbox = yes
  separator = .
}
EOF

# Configure authentication
cat > /etc/dovecot/conf.d/10-auth.conf <<EOF
disable_plaintext_auth = no
auth_mechanisms = plain login

passdb {
  driver = pam
}

userdb {
  driver = passwd
}
EOF

# Configure master settings
cat > /etc/dovecot/conf.d/10-master.conf <<EOF
service imap-login {
  inet_listener imap {
    port = 143
  }
}

service auth {
  unix_listener auth-userdb {
    mode = 0666
  }
}
EOF

# Configure logging
cat > /etc/dovecot/conf.d/10-logging.conf <<EOF
log_path = /dev/stderr
info_log_path = /dev/stdout
debug_log_path = /dev/stdout
EOF

# Configure SSL (disable for local testing)
cat > /etc/dovecot/conf.d/10-ssl.conf <<EOF
ssl = no
EOF

# Ensure mail group exists and mail user is in it
groupadd -f mail
if [ "$MAIL_USER" != "root" ]; then
    usermod -a -G mail "$MAIL_USER" 2>/dev/null || true
fi

# Set /var/mail permissions
chgrp mail /var/mail
chmod 1777 /var/mail

echo "Dovecot configuration complete"

# Start services via supervisor
exec "$@"