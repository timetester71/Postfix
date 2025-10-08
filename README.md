# Postfix Docker Container

A lightweight Postfix SMTP server for local application testing. Built on Debian, configured for local delivery with no DNS lookups.

## Features

- **Local testing optimized** - No DNS lookups, accepts mail from local networks
- **Configurable via environment variables** - Easy customization without rebuilding
- **Real-time logging** - All Postfix logs output to Docker logs
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
    volumes:
      - ./mail-data:/var/mail
    environment:
      ROOT_ALIASES: "mark,admin"
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
  -v ./mail-data:/var/mail \
  -e ROOT_ALIASES="mark" \
  mlovick/postfix
```

## Environment Variables

All variables are optional and have sensible defaults for local testing.

| Variable | Default | Description |
|----------|---------|-------------|
| `MYDESTINATION` | `mail.example.local, example.com, localhost.localdomain, localhost` | Comma-separated list of domains to accept mail for |
| `SMTPD_BANNER` | `$myhostname ESMTP Test Server` | SMTP banner text shown to clients |
| `MYNETWORKS` | `127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16` | Trusted networks allowed to relay mail |
| `DISABLE_DNS_LOOKUPS` | `yes` | Disable DNS lookups (recommended for local testing) |
| `LOCAL_RECIPIENT_MAPS` | `hash:/etc/aliases` | Map for valid recipients (use empty string to accept all) |
| `ROOT_ALIASES` | *(empty)* | Additional aliases that deliver to root mailbox (comma-separated) |

### Default Aliases

The following aliases always route to root's mailbox:
- `postmaster`
- `abuse`
- `noc`
- `support`
- `hostmaster`
- `webmaster`
- `root`

**Custom aliases** specified in `ROOT_ALIASES` are added to this list.

## Usage Examples

### Basic Setup
```bash
docker run -d \
  --name postfix \
  -p 25:25 \
  -v ./mail-data:/var/mail \
  mlovick/postfix
```

### Custom Domains and Aliases
```yaml
environment:
  MYDESTINATION: "mycompany.com, test.local, localhost"
  ROOT_ALIASES: "info,sales,contact,hello"
```

### Accept Mail from Specific Network Only
```yaml
environment:
  MYNETWORKS: "192.168.1.0/24"
```

### Allow Any Recipient (Testing Mode)
```yaml
environment:
  LOCAL_RECIPIENT_MAPS: ""
```

## Testing

### Send Test Email
```bash
# From host machine
echo "Test message body" | mail -s "Test Subject" mark@example.com

# From inside container
docker exec -i postfix-test mail -s "Test" mark@example.com
```

### Check Delivered Mail
```bash
# On host machine
cat mail-data/root

# Inside container
docker exec postfix-test cat /var/mail/root
```

### View Real-time Logs
```bash
docker logs -f postfix-test
```

### Check Mail Queue
```bash
docker exec postfix-test postqueue -p
```

## Building from Source

```bash
git clone https://github.com/timetester71/Postfix.git
cd postfix-docker
docker build -t mlovick/postfix .
```

## Volume Mounts

| Container Path | Purpose | Recommended Mount |
|---------------|---------|-------------------|
| `/var/mail` | Delivered mail storage | `./mail-data:/var/mail` |
| `/var/spool/postfix` | Mail queue (internal only) | **Do not mount on macOS** |

**Note**: On macOS, do not mount `/var/spool/postfix` as it causes permission errors. Only mount `/var/mail`.

## Connecting Your Application

Configure your application to use:
- **Host**: `localhost` (or container name if on same Docker network)
- **Port**: `25`
- **Authentication**: None required
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

### Mail rejected with "User unknown"
Add the recipient to `ROOT_ALIASES` or set `LOCAL_RECIPIENT_MAPS=""` to accept all recipients

## Security Warning

**This container is designed for LOCAL TESTING ONLY.**

- No authentication required
- Accepts mail from all local networks by default
- No TLS/encryption configured
- Should never be exposed to the public internet

## License

MIT License - Feel free to use and modify as needed.

## Contributing

Issues and pull requests welcome at https://github.com/timetester71/Postfix