# PostgreSQL 16 + TimescaleDB + pgAdmin Deployment Guide
## With IP Whitelisting & Security Features

## 🚀 Quick Installation

### One-Command Installation from GitHub
```bash
# Download and run the stable setup script
curl -fsSL https://raw.githubusercontent.com/drhema/postgresql_self_hosting/refs/heads/main/postgresql-self.sh \
  -o setup.sh && chmod +x setup.sh && sudo ./setup.sh
```

## 🔒 Security Features

### IP Whitelisting
The setup script will prompt you to enter allowed IP addresses that can connect to PostgreSQL:
- Enter multiple IPs separated by commas (e.g., `192.168.1.100,10.0.0.5,203.0.113.45`)
- Leave empty to allow all connections (not recommended for production)
- IPs are stored in `.env` file and can be modified later

### Example IP Configuration
```
Allowed IPs (comma-separated): 192.168.1.100,10.0.0.5,203.0.113.45
```

This will restrict PostgreSQL connections to only these three IP addresses.

## 📋 Post-Installation Commands

### View Configuration & Credentials
After installation, use these commands to view your settings:

```bash
# View all configuration and credentials
/srv/postgres16/scripts/show-config.sh

# View credentials file
cat /srv/postgres16/CREDENTIALS.txt

# View environment variables
cat /srv/postgres16/.env

# Monitor database status
/srv/postgres16/scripts/monitor.sh
```

## 🐳 Docker Compose with IP Restrictions

### docker-compose.yml (Enhanced with Security)
```yaml
version: '3'

services:
  postgres:
    image: timescale/timescaledb:latest-pg16
    container_name: postgres16
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      # IP restriction configuration
      POSTGRES_HOST_AUTH_METHOD: md5
      POSTGRES_INITDB_ARGS: "--auth-host=md5 --auth-local=trust"
    volumes:
      - /srv/postgres16/data:/var/lib/postgresql/data
      - /srv/postgres16/init-scripts:/docker-entrypoint-initdb.d:ro
      - /srv/postgres16/config/pg_hba_custom.conf:/etc/postgresql/pg_hba.conf:ro
      - /srv/postgres16/backups:/backups
    networks:
      - postgres_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
    command: >
      postgres
      -c listen_addresses='*'
      -c max_connections=200
      -c shared_buffers=256MB
      -c log_connections=on
      -c log_disconnections=on

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: pgadmin4
    restart: unless-stopped
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@example.com
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_PASSWORD}
      PGADMIN_CONFIG_SERVER_MODE: 'True'
      PGADMIN_LISTEN_PORT: 80
      PGADMIN_DISABLE_POSTFIX: 'True'
    volumes:
      - /srv/postgres16/pgadmin:/var/lib/pgadmin
      - /srv/postgres16/pgadmin-servers.json:/pgadmin4/servers.json:ro
    ports:
      - "5050:80"
    networks:
      - postgres_network
    depends_on:
      - postgres

networks:
  postgres_network:
    driver: bridge
```

### Sample .env File with IP Whitelisting
```env
# ═══════════════════════════════════════════════════════════════════
# POSTGRESQL CONFIGURATION
# ═══════════════════════════════════════════════════════════════════
POSTGRES_USER=admin7c3f
POSTGRES_PASSWORD=Kj9mP2xQ7nL4
POSTGRES_DB=maindb

# ═══════════════════════════════════════════════════════════════════
# SECURITY - IP WHITELIST
# ═══════════════════════════════════════════════════════════════════
# IPs allowed to connect to PostgreSQL (comma-separated)
# Examples:
#   Single IP: 192.168.1.100
#   Multiple IPs: 192.168.1.100,10.0.0.5,203.0.113.45
#   All IPs (not secure): 0.0.0.0/0
ALLOWED_IPS=192.168.1.100,10.0.0.5,203.0.113.45
POSTGRES_LISTEN_ADDRESSES=*

# ═══════════════════════════════════════════════════════════════════
# PGADMIN CONFIGURATION
# ═══════════════════════════════════════════════════════════════════
PGADMIN_EMAIL=admin@example.com
PGADMIN_PASSWORD=Yx5hN8qR2wK9

# ═══════════════════════════════════════════════════════════════════
# DATABASE USERS
# ═══════════════════════════════════════════════════════════════════
DB_APP_USER=appuser
DB_APP_PASSWORD=Bm4kT9sW2nP6
DB_READONLY_USER=readonly
DB_READONLY_PASSWORD=Qz8vL3mK7xR5
DB_MONITOR_USER=monitor
DB_MONITOR_PASSWORD=Nt7pL3mK9xW2

# ═══════════════════════════════════════════════════════════════════
# CONNECTION URLS
# ═══════════════════════════════════════════════════════════════════
DATABASE_URL=postgresql://appuser:Bm4kT9sW2nP6@your-server:5432/maindb
DATABASE_URL_READONLY=postgresql://readonly:Qz8vL3mK7xR5@your-server:5432/maindb
DATABASE_URL_ADMIN=postgresql://admin7c3f:Kj9mP2xQ7nL4@your-server:5432/maindb

# ═══════════════════════════════════════════════════════════════════
# SERVER INFORMATION
# ═══════════════════════════════════════════════════════════════════
SERVER_IP=your-server-ip
TZ=UTC
```

## 📝 Step-by-Step Deployment Process

### Step 1: Run the Setup Script
```bash
# Download from GitHub
curl -fsSL https://raw.githubusercontent.com/drhema/postgresql_self_hosting/refs/heads/main/postgresql-self.sh -o setup.sh

# Make executable
chmod +x setup.sh

# Run with sudo
sudo ./setup.sh
```

### Step 2: Configure IP Whitelist
When prompted, enter the IP addresses that should have access:
```
Enter IP addresses that should have access to PostgreSQL.
Separate multiple IPs with commas (e.g., 192.168.1.100,10.0.0.5)
Leave empty to allow connections from anywhere (less secure)

Allowed IPs (comma-separated): 192.168.1.100,10.0.0.5,your-app-server-ip
```

### Step 3: Deploy in Portainer
1. Login to Portainer
2. Go to **Stacks** → **Add Stack**
3. Name: `postgres16`
4. Paste the docker-compose.yml
5. Load environment variables from `/srv/postgres16/.env`
6. Deploy the stack

### Step 4: Verify Deployment
```bash
# Check containers
docker ps

# View configuration
/srv/postgres16/scripts/show-config.sh

# Monitor connections
/srv/postgres16/scripts/monitor.sh

# Test PostgreSQL access
docker exec -it postgres16 psql -U admin7c3f -d maindb -c "SELECT version();"
```

## 🔧 Managing IP Whitelist

### Add New IP Address
1. Edit the .env file:
```bash
nano /srv/postgres16/.env
```

2. Update the `ALLOWED_IPS` line:
```env
ALLOWED_IPS=192.168.1.100,10.0.0.5,203.0.113.45,NEW_IP_HERE
```

3. Update pg_hba configuration:
```bash
nano /srv/postgres16/config/pg_hba_custom.conf
```

4. Restart the PostgreSQL container:
```bash
docker restart postgres16
```

### View Current Allowed IPs
```bash
# Quick view
grep ALLOWED_IPS /srv/postgres16/.env

# Detailed view with all settings
/srv/postgres16/scripts/show-config.sh
```

### Check Active Connections
```bash
# See who's connected
docker exec postgres16 psql -U admin7c3f -d maindb -c \
  "SELECT client_addr, usename, application_name, state 
   FROM pg_stat_activity 
   WHERE client_addr IS NOT NULL;"
```

## 🛡️ Security Best Practices

### 1. IP Whitelisting
- Always specify allowed IPs in production
- Never use `0.0.0.0/0` unless absolutely necessary
- Regularly review and update the whitelist

### 2. Firewall Configuration
```bash
# Allow PostgreSQL only from specific IPs
sudo ufw allow from 192.168.1.100 to any port 5432
sudo ufw allow from 10.0.0.5 to any port 5432

# Allow pgAdmin from anywhere (or restrict as needed)
sudo ufw allow 5050/tcp
```

### 3. Regular Security Audits
```bash
# Check failed connection attempts
docker logs postgres16 | grep -i "failed\|error\|denied"

# Review active connections
/srv/postgres16/scripts/monitor.sh

# Check PostgreSQL logs
docker exec postgres16 tail -f /var/lib/postgresql/data/log/postgresql-*.log
```

## 📊 Useful Management Commands

### Configuration Management
```bash
# View all settings
/srv/postgres16/scripts/show-config.sh

# Edit configuration
nano /srv/postgres16/.env

# View credentials
cat /srv/postgres16/CREDENTIALS.txt
```

### Database Operations
```bash
# Connect as admin
docker exec -it postgres16 psql -U admin7c3f -d maindb

# Connect as app user
docker exec -it postgres16 psql -U appuser -d maindb

# Backup database
docker exec postgres16 pg_dump -U admin7c3f maindb > backup.sql

# Restore database
docker exec -i postgres16 psql -U admin7c3f maindb < backup.sql
```

### Monitoring
```bash
# Real-time monitoring
/srv/postgres16/scripts/monitor.sh

# Container logs
docker logs postgres16 --tail 50 -f

# pgAdmin logs
docker logs pgadmin4 --tail 50
```

## 🔍 Troubleshooting

### Connection Refused from Application
1. Check if IP is whitelisted:
```bash
grep ALLOWED_IPS /srv/postgres16/.env
```

2. Add the application's IP if missing:
```bash
# Edit .env file
nano /srv/postgres16/.env
# Add IP to ALLOWED_IPS
# Restart PostgreSQL
docker restart postgres16
```

### Can't Access pgAdmin
```bash
# Check if running
docker ps | grep pgadmin

# Check logs
docker logs pgadmin4

# Verify port is open
sudo netstat -tlnp | grep 5050
```

### PostgreSQL Not Starting
```bash
# Check logs
docker logs postgres16

# Verify permissions
ls -la /srv/postgres16/data

# Check disk space
df -h /srv/postgres16
```

## 📱 Application Connection Examples

### With IP Restrictions
Your application must be connecting from a whitelisted IP:

#### Node.js
```javascript
// Application must run from whitelisted IP
const { Pool } = require('pg');
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  // Connection will only work from whitelisted IPs
});
```

#### Python
```python
# Application must run from whitelisted IP
import psycopg2
import os

conn = psycopg2.connect(os.environ['DATABASE_URL'])
# Connection will fail if not from whitelisted IP
```

## 🎯 Quick Reference

### Files and Locations
| File/Directory | Purpose |
|---------------|---------|
| `/srv/postgres16/.env` | Environment variables & IP whitelist |
| `/srv/postgres16/CREDENTIALS.txt` | All passwords and users |
| `/srv/postgres16/scripts/show-config.sh` | View current configuration |
| `/srv/postgres16/scripts/monitor.sh` | Monitor database status |
| `/srv/postgres16/config/pg_hba_custom.conf` | PostgreSQL access control |

### Default Ports
| Service | Port | Access |
|---------|------|--------|
| PostgreSQL | 5432 | Restricted to whitelisted IPs |
| pgAdmin | 5050 | Open (configure firewall as needed) |

### GitHub Repository
- **Repository**: https://github.com/drhema/postgresql_self_hosting
- **Setup Script**: https://raw.githubusercontent.com/drhema/postgresql_self_hosting/refs/heads/main/postgresql-self.sh

## ✅ Success Checklist

- [ ] Setup script executed successfully
- [ ] IP whitelist configured
- [ ] Docker stack deployed in Portainer
- [ ] pgAdmin accessible at http://server:5050
- [ ] PostgreSQL accessible from whitelisted IPs only
- [ ] Configuration viewable via `show-config.sh`
- [ ] Credentials saved in `/srv/postgres16/CREDENTIALS.txt`
- [ ] Application connected successfully from whitelisted IP

---

**Version**: 1.1.0 (with IP Whitelisting)  
**Repository**: [drhema/postgresql_self_hosting](https://github.com/drhema/postgresql_self_hosting)  
**Support**: Create an issue on GitHub
