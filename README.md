# PostgreSQL 16 + TimescaleDB + pgAdmin Complete Deployment Guide

## 🚀 Quick Start

### One-Line Installation
```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/postgresql-setup/main/setup-postgresql.sh -o setup.sh && chmod +x setup.sh && sudo ./setup.sh
```

## 📋 Components

- **PostgreSQL 16** with TimescaleDB extension
- **pgAdmin 4** web interface for database management
- **Auto-generated** secure credentials (12-char alphanumeric)
- **Multiple users** with different permission levels
- **Local storage** at `/srv/postgres16/`

## 📁 File Structure

```
/srv/postgres16/
├── .env                    # Environment variables
├── CREDENTIALS.txt         # All passwords and connection info
├── docker-compose.yml      # Stack configuration (add manually)
├── pgadmin-servers.json    # pgAdmin auto-configuration
├── init-scripts/           # SQL initialization
│   └── 01-init.sql
├── scripts/
│   └── monitor.sh          # Monitoring dashboard
├── data/                   # PostgreSQL data (persistent)
├── pgadmin/               # pgAdmin configuration
├── backups/               # Database backups
└── logs/                  # Application logs
```

## 🐳 Docker Compose Configuration

### docker-compose.yml

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
    volumes:
      - /srv/postgres16/data:/var/lib/postgresql/data
      - /srv/postgres16/init-scripts:/docker-entrypoint-initdb.d:ro
      - /srv/postgres16/backups:/backups
    networks:
      - postgres_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

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

### Sample .env File

```env
# PostgreSQL Configuration
POSTGRES_USER=admin7c3f
POSTGRES_PASSWORD=Kj9mP2xQ7nL4
POSTGRES_DB=maindb

# pgAdmin Configuration (MUST use valid email domain)
PGADMIN_EMAIL=admin@example.com
PGADMIN_PASSWORD=Yx5hN8qR2wK9

# Database Users
DB_APP_USER=appuser
DB_APP_PASSWORD=Bm4kT9sW2nP6
DB_READONLY_USER=readonly
DB_READONLY_PASSWORD=Qz8vL3mK7xR5

# Connection URLs
DATABASE_URL=postgresql://appuser:Bm4kT9sW2nP6@20.64.251.75:5432/maindb
DATABASE_URL_READONLY=postgresql://readonly:Qz8vL3mK7xR5@20.64.251.75:5432/maindb

# Server Info
SERVER_IP=20.64.251.75
TZ=UTC
```

## 📝 Step-by-Step Deployment

### Step 1: Run Setup Script

```bash
# Download and run the setup script
curl -fsSL https://your-url/setup-postgresql.sh -o setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

The script will:
- Auto-detect your server IP
- Generate secure 12-character passwords
- Create all necessary directories
- Generate configuration files
- Save credentials to `/srv/postgres16/CREDENTIALS.txt`

### Step 2: Deploy in Portainer

1. **Login to Portainer** at `http://your-server:9000`

2. **Create New Stack**:
   - Go to **Stacks** → **Add Stack**
   - Name: `postgres16`

3. **Add Docker Compose**:
   - Copy the `docker-compose.yml` content above
   - Paste in the **Web editor**

4. **Add Environment Variables**:
   - Click **"Load variables from .env file"**
   - Copy contents from `/srv/postgres16/.env`:
   ```bash
   cat /srv/postgres16/.env
   ```
   - Paste into the environment variables section

5. **Deploy**:
   - Click **"Deploy the stack"**
   - Wait ~30 seconds for initialization

### Step 3: Verify Deployment

```bash
# Check containers
docker ps | grep -E "postgres16|pgadmin4"

# Test PostgreSQL
docker exec -it postgres16 psql -U admin7c3f -d maindb -c "SELECT version();"

# Check TimescaleDB
docker exec -it postgres16 psql -U admin7c3f -d maindb -c "SELECT extname FROM pg_extension WHERE extname = 'timescaledb';"

# Monitor status
/srv/postgres16/scripts/monitor.sh
```

### Step 4: Access Services

#### pgAdmin Web Interface
- **URL**: `http://your-server:5050`
- **Email**: `admin@example.com`
- **Password**: Check `/srv/postgres16/CREDENTIALS.txt`

#### PostgreSQL Database
- **Host**: your-server-ip
- **Port**: 5432
- **Database**: maindb
- **Users**: admin, appuser, readonly

## 🔧 Important Configuration Notes

### pgAdmin Email Requirements
⚠️ **CRITICAL**: pgAdmin requires a **valid email format** with a proper domain:
- ✅ **CORRECT**: `admin@example.com`, `admin@localhost.com`
- ❌ **WRONG**: `admin@192.168.1.1`, `admin@20.64.251.75`

If using an IP address in the email causes deployment failure!

### Password Format
All passwords are:
- 12 characters long
- Alphanumeric only (a-z, A-Z, 0-9)
- No special characters
- Perfect for .env files without escaping

## 🔌 Application Connection Examples

### Node.js (pg)
```javascript
const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://appuser:Bm4kT9sW2nP6@your-server:5432/maindb'
});
```

### Python (psycopg2)
```python
import psycopg2
conn = psycopg2.connect(
    "postgresql://appuser:Bm4kT9sW2nP6@your-server:5432/maindb"
)
```

### Prisma
```prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
```

### Django
```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'maindb',
        'USER': 'appuser',
        'PASSWORD': 'Bm4kT9sW2nP6',
        'HOST': 'your-server',
        'PORT': '5432',
    }
}
```

## 🛠️ Management Commands

### View Credentials
```bash
cat /srv/postgres16/CREDENTIALS.txt
```

### Monitor Database
```bash
/srv/postgres16/scripts/monitor.sh
```

### Connect via psql
```bash
# As admin
docker exec -it postgres16 psql -U admin7c3f -d maindb

# As app user
docker exec -it postgres16 psql -U appuser -d maindb
```

### View Logs
```bash
# PostgreSQL logs
docker logs postgres16 --tail 50

# pgAdmin logs
docker logs pgadmin4 --tail 50
```

### Backup Database
```bash
docker exec postgres16 pg_dump -U admin7c3f maindb > backup.sql
```

### Restart Services
```bash
docker restart postgres16 pgadmin4
```

## 🔒 Security Notes

1. **Change default passwords** immediately after setup
2. **PostgreSQL port (5432)** is exposed - use firewall rules
3. **pgAdmin (5050)** is publicly accessible - consider VPN/proxy
4. **Backup regularly** - data is stored at `/srv/postgres16/data`

## 🎯 Troubleshooting

### pgAdmin Won't Start
- Check email format is valid (not IP address)
- Verify password in .env file
- Check logs: `docker logs pgadmin4`

### Can't Connect to PostgreSQL
- Verify port 5432 is open: `netstat -tlnp | grep 5432`
- Check firewall: `sudo ufw status`
- Test locally: `docker exec -it postgres16 psql -U admin7c3f`

### TimescaleDB Not Working
```sql
-- Enable extension manually
docker exec -it postgres16 psql -U admin7c3f -d maindb
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
```

## 📊 Installed Extensions

- **timescaledb** - Time-series data support
- **pg_stat_statements** - Query performance tracking
- **pgcrypto** - Cryptographic functions
- **uuid-ossp** - UUID generation

## 🎉 Success Checklist

- [ ] Setup script executed successfully
- [ ] Docker stack deployed in Portainer
- [ ] PostgreSQL accessible on port 5432
- [ ] pgAdmin accessible at http://server:5050
- [ ] TimescaleDB extension enabled
- [ ] Application connected successfully
- [ ] Credentials saved securely

## 📚 Additional Resources

- [TimescaleDB Documentation](https://docs.timescale.com/)
- [PostgreSQL 16 Documentation](https://www.postgresql.org/docs/16/)
- [pgAdmin Documentation](https://www.pgadmin.org/docs/)
- [Docker Compose Reference](https://docs.docker.com/compose/)

---

**Generated by PostgreSQL Setup Script**  
**Version**: 1.0.0  
**Support**: Create an issue on GitHub repository
