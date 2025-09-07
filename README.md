# PostgreSQL 16 + TimescaleDB + pgAdmin - Deployment Files

## 🚀 Quick Setup Option

Run this command on your server to auto-generate configuration:

```bash
# Download and run the stable setup script
curl -fsSL https://raw.githubusercontent.com/drhema/postgresql_self_hosting/refs/heads/main/postgresql-self.sh \
  -o setup.sh && chmod +x setup.sh && sudo ./setup.sh
```

---

## 📦 Manual Deployment Files for Portainer

### 1. Docker Compose Stack (`docker-compose.yml`)

Copy this into Portainer's stack editor:

```yaml
version: '3.8'

services:
  postgres:
    image: timescale/timescaledb:latest-pg16
    container_name: postgres16
    restart: always
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_HOST_AUTH_METHOD=scram-sha-256
      - POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256 --auth-local=scram-sha-256
      - TIMESCALEDB_TELEMETRY=off
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - postgres_backups:/backups
    ports:
      - "5432:5432"    # PostgreSQL exposed for external connections
    networks:
      - postgres_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: pgadmin4
    restart: always
    environment:
      # CRITICAL: Use a valid email domain, not .local or IP addresses!
      - PGADMIN_DEFAULT_EMAIL=${PGADMIN_DEFAULT_EMAIL}
      - PGADMIN_DEFAULT_PASSWORD=${PGADMIN_DEFAULT_PASSWORD}
      - PGADMIN_CONFIG_SERVER_MODE=True
      - PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED=True
      - PGADMIN_CONFIG_ENHANCED_COOKIE_PROTECTION=True
      - PGADMIN_CONFIG_LOGIN_BANNER="Authorized access only!"
      - PGADMIN_CONFIG_CONSOLE_LOG_LEVEL=10
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    ports:
      - "${PGADMIN_PORT}:80"
    networks:
      - postgres_network
    depends_on:
      postgres:
        condition: service_healthy

volumes:
  postgres_data:
    driver: local
  postgres_backups:
    driver: local
  pgadmin_data:
    driver: local

networks:
  postgres_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
```

### 2. Environment Variables (`.env`)

Add these to Portainer's environment variables section:

```env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=njjXmoi7i5HX
POSTGRES_DB=postgres
PGADMIN_DEFAULT_EMAIL=admin@example.com
PGADMIN_DEFAULT_PASSWORD=EtJmEKbjLb0a
PGADMIN_CONFIG_SERVER_MODE=True
PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED=True
PGADMIN_PORT=5050
TIMESCALEDB_TELEMETRY=off
POSTGRES_HOST_AUTH_METHOD=scram-sha-256
POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256 --auth-local=scram-sha-256
```

---

## 📋 Deployment Steps

1. **In Portainer:**
   - Go to **Stacks** → **Add Stack**
   - Name: `postgres16`
   - **Web editor**: Paste the docker-compose.yml content
   - **Environment variables**: Paste the .env content
   - Click **Deploy the stack**

2. **Wait 30 seconds for initialization**

3. **Access Services:**
   - **pgAdmin**: http://YOUR_SERVER_IP:5050
     - Email: `admin@example.com`
     - Password: `EtJmEKbjLb0a`
   
   - **PostgreSQL**: YOUR_SERVER_IP:5432
     - User: `postgres`
     - Password: `njjXmoi7i5HX`
     - Database: `postgres`

4. **Connect pgAdmin to PostgreSQL:**
   - In pgAdmin, register new server
   - Host: `postgres` (container name, not IP)
   - Port: `5432`
   - Username: `postgres`
   - Password: `njjXmoi7i5HX`

5. **External Connections (TablePlus, DBeaver, etc):**
   - Host: `YOUR_SERVER_IP`
   - Port: `5432`
   - User: `postgres`
   - Password: `njjXmoi7i5HX`

---

## ⚠️ Important Notes

- **pgAdmin Email**: Must use a valid domain (`.com`, `.org`, etc). Never use `.local` or IP addresses
- **PostgreSQL Port 5432**: Currently exposed for external connections. Remove the `ports` section under postgres service if you only need internal access
- **Passwords**: All passwords are 12 characters, alphanumeric only
- **Security**: Consider adding firewall rules to restrict PostgreSQL access to specific IPs

---
