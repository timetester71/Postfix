# Postfix Docker Container

A lightweight Postfix SMTP server for local application testing. Built on Debian, configured for local delivery with no DNS lookups.

## Features

- **Local testing optimized** - No DNS lookups, accepts mail from local networks
- **Configurable via environment variables** - Easy customization without rebuilding
- **Custom user support** - Create a specific mail user instead of using root
- **IMAP access** - Check received mail using any IMAP client
- **Real-time logging** - All Postfix and Dovecot logs output to Docker logs
- **Persistent mail storage** - Mail data stored in mounted volume
- **Alias management** - Configure email aliases via environment variables
- **Strict recipient validation** - Only accepts mail for configured aliases

## Quick Start

### Using Docker Compose

Create a `docker-compose.yml`:

```yaml
version: '3.8'

services:
  postfix:
    build: https://github.com/timetester71/Postfix.git
    image: mlovick/postfix
    container_name: postfix-test
    hostname: mail.example.local
    ports:
      - "25:25"
      - "143:143"
    volumes:
      - ./mail-data:/var/mail
    environment:
      MAIL_USER: "mark"
      MAIL_PASSWORD: "testpassword"
      ROOT_ALIASES: "admin,info"
    restart: unless-stopped
```

Start the container:
```bash
docker-compose up -d
```

### Using Docker Run

```bash
docker run -d \
  --name postfix-test \
  --hostname mail.example.local \
  -p 25:25 \
  -p 143:143 \
  -v ./mail-data:/var/mail \
  -e MAIL_USER="mark" \
  -e MAIL_PASSWORD="testpassword" \
  -e ROOT_ALIASES="admin,info" \
  mlovick/postfix
```

## Environment Variables

All variables are optional and have sensible defaults for local testing.

| Variable | Default | Description |
|----------|---------|-------------|
| `MAIL_USER` | `root` | Username for mail delivery. If not root, creates a new system user |
| `MAIL_PASSWORD` | *(empty)* | Password for the mail user (optional, used when creating new user) |
| `ROOT_ALIASES` | *(empty)* | Additional aliases that deliver to mail user (comma-separated) |
| `MYDESTINATION` | `mail.example.local, localhost.localdomain, localhost` | Comma-separated list of domains to accept mail for |
| `SMTPD_BANNER` | `$myhostname ESMTP Test Server` | SMTP banner text shown to clients |
| `MYNETWORKS` | `127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16` | Trusted networks allowed to relay mail |
| `DISABLE_DNS_LOOKUPS` | `yes` | Disable DNS lookups (recommended for local testing) |
| `LOCAL_RECIPIENT_MAPS` | `hash:/etc/aliases` | Map for valid recipients (use empty string to accept all) |

### Default Aliases

The following aliases always route to the configured mail user (default: root):
- `postmaster`
- `abuse`
- `noc`
- `support`
- `hostmaster`
- `webmaster`
- `root` (always forwards to MAIL_USER)

**Custom aliases** specified in `ROOT_ALIASES` are added to this list.

## Usage Examples

### Basic Setup (Using Root)
```bash
docker run -d \
  --name postfix \
  -p 25:25 \
  -p 143:143 \
  -v ./mail-data:/var/mail \
  mlovick/postfix
```

### Custom User with Password
```yaml
environment:
  MAIL_USER: "john"
  MAIL_PASSWORD: "secure123"
  ROOT_ALIASES: "john.doe,j.doe,contact"
```

All mail to `postmaster@`, `john@`, `john.doe@`, `j.doe@`, and `contact@` will be delivered to `/var/mail/john`

### Custom Domains and Aliases
```yaml
environment:
  MAIL_USER: "testuser"
  MYDESTINATION: "mycompany.com, test.local, localhost"
  ROOT_ALIASES: "info,sales,contact,hello"
```

### Accept Mail from Specific Network Only
```yaml
environment:
  MAIL_USER: "mailbox"
  MYNETWORKS: "192.168.1.0/24"
```

### Allow Any Recipient (Testing Mode)
```yaml
environment:
  MAIL_USER: "catchall"
  LOCAL_RECIPIENT_MAPS: ""
```

## Testing

### Send Test Email
```bash
# From host machine (replace 'mark' with your MAIL_USER)
echo "Test message body" | mail -s "Test Subject" mark@mail.example.local

# From inside container
docker exec -i postfix-test mail -s "Test" admin@mail.example.local
```

### Check Delivered Mail
```bash
# On host machine (replace 'mark' with your MAIL_USER)
cat mail-data/mark

# Inside container
docker exec postfix-test cat /var/mail/mark
```

### View Real-time Logs
```bash
docker logs -f postfix-test
```

### Check Mail Queue
```bash
docker exec postfix-test postqueue -p
```

### Access Mail User Shell
```bash
# If you created a custom user
docker exec -it postfix-test su - mark
```

### Check Mail via IMAP

You can connect to the IMAP server using any mail client:

**Connection Settings:**
- **Server**: localhost (or container IP)
- **Port**: 143
- **Security**: None (plain text)
- **Username**: Your MAIL_USER value (e.g., "mark")
- **Password**: Your MAIL_PASSWORD value

**Example using command line (Alpine Linux mail client):**
```bash
# Install alpine if needed
apt-get install alpine

# Connect to IMAP
alpine -inbox={localhost:143/notls}INBOX -user=mark
```

**Example using telnet for testing:**
```bash
telnet localhost 143
# Then authenticate:
# a1 LOGIN mark testpassword
# a2 SELECT INBOX
# a3 FETCH 1 BODY[]
# a4 LOGOUT
```

**Example using Thunderbird or similar:**
1. Add new mail account
2. Configure incoming server as IMAP
3. Server: localhost, Port: 143
4. Connection security: None
5. Authentication: Normal password
6. Username: mark (or your MAIL_USER)
7. Password: testpassword (or your MAIL_PASSWORD)

## Building from Source

```bash
git clone https://github.com/timetester71/Postfix.git
cd Postfix
docker build -t mlovick/postfix .
```

## Volume Mounts

| Container Path | Purpose | Recommended Mount |
|---------------|---------|-------------------|
| `/var/mail` | Delivered mail storage | `./mail-data:/var/mail` |
| `/var/spool/postfix` | Mail queue (internal only) | **Do not mount on macOS** |

**Note**: On macOS, do not mount `/var/spool/postfix` as it causes permission errors. Only mount `/var/mail`.

### Accessing Mail Files

When using a custom mail user, mail is stored at:
- Container: `/var/mail/{MAIL_USER}`
- Host: `./mail-data/{MAIL_USER}`

Example:
```bash
# If MAIL_USER=mark
cat mail-data/mark
```

## Connecting Your Application

### SMTP (Sending Mail)
Configure your application to use:
- **Host**: `localhost` (or container name if on same Docker network)
- **Port**: `25`
- **Authentication**: None required
- **TLS/SSL**: Not configured (local testing only)

### IMAP (Reading Mail)
Configure your mail client to use:
- **Host**: `localhost` (or container name if on same Docker network)
- **Port**: `143`
- **Username**: Value of MAIL_USER environment variable
- **Password**: Value of MAIL_PASSWORD environment variable
- **TLS/SSL**: Not configured (local testing only)

### Example: PHP
```php
ini_set('SMTP', 'localhost');
ini_set('smtp_port', '25');
```

### Example: Python
```python
import smtplib
server = smtplib.SMTP('localhost', 25)
server.sendmail(from_addr, to_addrs, msg)
```

### Example: Node.js
```javascript
const nodemailer = require('nodemailer');
const transporter = nodemailer.createTransport({
  host: 'localhost',
  port: 25,
  secure: false
});
```

## Troubleshooting

### Container keeps restarting
Check logs: `docker logs postfix-test`

### Permission errors on macOS
Remove the postfix-spool volume mount - only mount `/var/mail`

### Mail not being delivered
1. Check if aliases are configured: `docker exec postfix-test cat /etc/aliases`
2. Check mail queue: `docker exec postfix-test postqueue -p`
3. View logs: `docker logs postfix-test`
4. Verify mail user exists: `docker exec postfix-test id {MAIL_USER}`

### Mail rejected with "User unknown"
Add the recipient to `ROOT_ALIASES` or set `LOCAL_RECIPIENT_MAPS=""` to accept all recipients

### Can't find mail file
Mail is stored at `/var/mail/{MAIL_USER}` where `{MAIL_USER}` is the value of the `MAIL_USER` environment variable (default: `root`)

### User already exists error
This happens when the container is recreated but the mail-data volume persists. Either:
- Use the same MAIL_USER value
- Clear the mail-data directory
- The container will skip user creation if user already exists

### IMAP connection refused or authentication failed
1. Verify port 143 is exposed: `docker ps` should show `0.0.0.0:143->143/tcp`
2. Check Dovecot is running: `docker exec postfix-test supervisorctl status`
3. Verify credentials match MAIL_USER and MAIL_PASSWORD environment variables
4. Check Dovecot logs: `docker logs postfix-test | grep dovecot`
5. Test with telnet: `telnet localhost 143` (should show Dovecot banner)

## Security Warning

**This container is designed for LOCAL TESTING ONLY.**

- No authentication required for SMTP
- IMAP uses plain text authentication (no encryption)
- Accepts mail from all local networks by default
- No TLS/encryption configured for SMTP or IMAP
- Passwords stored in plain text environment variables
- Should never be exposed to the public internet

## License

MIT License - Feel free to use and modify as needed.

## Contributing

Issues and pull requests welcome at https://github.com/timetester71/Postfix