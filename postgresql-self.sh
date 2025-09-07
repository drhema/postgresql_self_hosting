#!/bin/bash

#################################################
# PostgreSQL 16 + TimescaleDB + pgAdmin 4 Setup
# Optimized Self-Hosted Stack with IP Whitelisting
# Version: 2.0.0 - Fixed pgAdmin email validation
#################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Functions
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }

# Generate secure 12-character alphanumeric passwords
generate_password() {
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12
}

# Auto-detect server IP
detect_server_ip() {
    local ip=""
    
    # Try multiple services to get public IP
    for service in "ifconfig.me" "icanhazip.com" "ipinfo.io/ip" "api.ipify.org"; do
        ip=$(curl -s --max-time 3 $service 2>/dev/null)
        if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$ip"
            return
        fi
    done
    
    # Fallback to local IP
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$ip"
        return
    fi
    
    # Last resort
    echo "localhost"
}

# Default configuration
BASE_DIR="/srv/postgres16"
SERVER_IP=$(detect_server_ip)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dir)
            BASE_DIR="$2"
            shift 2
            ;;
        --ip)
            SERVER_IP="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --dir PATH    Custom installation directory (default: /srv/postgres16)"
            echo "  --ip ADDRESS  Specify server IP (default: auto-detect)"
            echo "  --help        Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

clear
echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║    PostgreSQL 16 + TimescaleDB + pgAdmin 4 Setup v2.0     ║
║         Optimized Stack with Security Features            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_info "Server IP detected: ${SERVER_IP}"
print_info "Installation directory: ${BASE_DIR}"
echo ""

# IP Whitelisting Configuration
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}                 SECURITY CONFIGURATION                      ${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Configure PostgreSQL access restrictions:"
echo "1) Docker network only (most secure, no external access)"
echo "2) Specific IP addresses (whitelist mode)"
echo "3) Any IP address (least secure, full access)"
echo ""
read -p "Select option [1-3] (default: 1): " SECURITY_OPTION

case "$SECURITY_OPTION" in
    2)
        echo ""
        read -p "Enter allowed IPs (comma-separated): " ALLOWED_IPS_INPUT
        if [ -z "$ALLOWED_IPS_INPUT" ]; then
            EXPOSE_POSTGRES="false"
            print_info "No IPs specified, using Docker network only"
        else
            ALLOWED_IPS="$ALLOWED_IPS_INPUT"
            EXPOSE_POSTGRES="true"
            print_success "PostgreSQL will accept connections from: ${ALLOWED_IPS}"
        fi
        ;;
    3)
        ALLOWED_IPS="0.0.0.0/0"
        EXPOSE_POSTGRES="true"
        print_warning "PostgreSQL will accept connections from ANY IP (not recommended)"
        ;;
    *)
        EXPOSE_POSTGRES="false"
        print_success "PostgreSQL restricted to Docker network only (recommended)"
        ;;
esac

# Generate credentials
print_info "Generating secure credentials..."
POSTGRES_PASSWORD=$(generate_password)
PGADMIN_PASSWORD=$(generate_password)
APP_USER_PASSWORD=$(generate_password)
READONLY_PASSWORD=$(generate_password)
BACKUP_PASSWORD=$(generate_password)
ANALYTICS_PASSWORD=$(generate_password)

# CRITICAL FIX: Use a valid email domain for pgAdmin
PGADMIN_EMAIL="admin@example.com"

# Create directory structure
print_info "Creating directory structure..."
sudo mkdir -p "$BASE_DIR"/{data,pgadmin,backups,scripts,logs,config,init}

# Set proper ownership
sudo chown -R 999:999 "$BASE_DIR/data"
sudo chown -R 5050:5050 "$BASE_DIR/pgadmin"
sudo chown -R 999:999 "$BASE_DIR/backups"
sudo chown -R 999:999 "$BASE_DIR/logs"

# Create .env file
print_info "Creating environment configuration..."
cat > "$BASE_DIR/.env" << EOF
# PostgreSQL 16 + TimescaleDB Configuration
# Generated: $(date)
# Server: ${SERVER_IP}

# ═══════════════════════════════════════════════════════════
# POSTGRESQL CONFIGURATION
# ═══════════════════════════════════════════════════════════
POSTGRES_USER=postgres
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=postgres

# ═══════════════════════════════════════════════════════════
# PGADMIN CONFIGURATION (Fixed email validation)
# ═══════════════════════════════════════════════════════════
PGADMIN_DEFAULT_EMAIL=${PGADMIN_EMAIL}
PGADMIN_DEFAULT_PASSWORD=${PGADMIN_PASSWORD}
PGADMIN_CONFIG_SERVER_MODE=True
PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED=True

# ═══════════════════════════════════════════════════════════
# DATABASE USERS
# ═══════════════════════════════════════════════════════════
APP_USER_PASSWORD=${APP_USER_PASSWORD}
READONLY_PASSWORD=${READONLY_PASSWORD}
BACKUP_PASSWORD=${BACKUP_PASSWORD}
ANALYTICS_PASSWORD=${ANALYTICS_PASSWORD}

# ═══════════════════════════════════════════════════════════
# SERVER CONFIGURATION
# ═══════════════════════════════════════════════════════════
SERVER_IP=${SERVER_IP}
SERVER_PORT=5432
PGADMIN_PORT=5050
EXPOSE_POSTGRES=${EXPOSE_POSTGRES}

# ═══════════════════════════════════════════════════════════
# SECURITY SETTINGS
# ═══════════════════════════════════════════════════════════
POSTGRES_HOST_AUTH_METHOD=scram-sha-256
POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256 --auth-local=scram-sha-256
TIMESCALEDB_TELEMETRY=off

# ═══════════════════════════════════════════════════════════
# CONNECTION STRINGS
# ═══════════════════════════════════════════════════════════
DATABASE_URL=postgresql://app_user:${APP_USER_PASSWORD}@${SERVER_IP}:5432/app_db
DATABASE_URL_READONLY=postgresql://readonly_user:${READONLY_PASSWORD}@${SERVER_IP}:5432/app_db
EOF

# Secure the .env file
sudo chmod 600 "$BASE_DIR/.env"

# Create PostgreSQL configuration
print_info "Creating PostgreSQL configuration..."
cat > "$BASE_DIR/config/postgresql.conf" << 'EOF'
# PostgreSQL 16 Optimized Configuration
listen_addresses = '*'
max_connections = 200
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
work_mem = 4MB
random_page_cost = 1.1
effective_io_concurrency = 200

# Logging
logging_collector = on
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_line_prefix = '%t [%p]: user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_statement = 'ddl'

# Security
password_encryption = scram-sha-256

# TimescaleDB
shared_preload_libraries = 'timescaledb'
timescaledb.telemetry_level = off
EOF

# Create initialization SQL
print_info "Creating database initialization script..."
cat > "$BASE_DIR/init/01-init-database.sql" << EOF
-- PostgreSQL 16 + TimescaleDB Initialization
-- Generated: $(date)

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create application database
CREATE DATABASE app_db;

-- Switch to app_db for setup
\c app_db

-- Enable TimescaleDB in app_db
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- Create users with secure passwords
CREATE USER app_user WITH PASSWORD '${APP_USER_PASSWORD}';
CREATE USER readonly_user WITH PASSWORD '${READONLY_PASSWORD}';
CREATE USER backup_user WITH PASSWORD '${BACKUP_PASSWORD}';
CREATE USER analytics_user WITH PASSWORD '${ANALYTICS_PASSWORD}';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE app_db TO app_user;
GRANT CONNECT ON DATABASE app_db TO readonly_user;
GRANT CONNECT ON DATABASE app_db TO backup_user;
GRANT CONNECT ON DATABASE app_db TO analytics_user;

-- Set default privileges for app_user
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO app_user;

-- Set read-only privileges
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO readonly_user;

-- Set analytics privileges
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO analytics_user;

-- Create audit table
CREATE TABLE IF NOT EXISTS audit_log (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    user_name TEXT,
    database_name TEXT,
    command_tag TEXT,
    query TEXT
);

-- Create sample hypertable for TimescaleDB
CREATE TABLE IF NOT EXISTS metrics (
    time TIMESTAMPTZ NOT NULL,
    device_id TEXT,
    temperature DOUBLE PRECISION,
    humidity DOUBLE PRECISION,
    location TEXT
);

-- Convert to hypertable
SELECT create_hypertable('metrics', 'time', if_not_exists => TRUE);

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_metrics_device_time ON metrics (device_id, time DESC);

\echo 'Database initialization complete!'
EOF

# Create docker-compose.yml based on security settings
print_info "Creating Docker Compose configuration..."

if [ "$EXPOSE_POSTGRES" = "true" ]; then
    POSTGRES_PORTS="    ports:
      - \"5432:5432\""
else
    POSTGRES_PORTS="    # PostgreSQL not exposed externally for security"
fi

cat > "$BASE_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  postgres:
    image: timescale/timescaledb:latest-pg16
    container_name: postgres16
    restart: always
    environment:
      - POSTGRES_USER=\${POSTGRES_USER}
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
      - POSTGRES_DB=\${POSTGRES_DB}
      - POSTGRES_HOST_AUTH_METHOD=\${POSTGRES_HOST_AUTH_METHOD}
      - POSTGRES_INITDB_ARGS=\${POSTGRES_INITDB_ARGS}
      - TIMESCALEDB_TELEMETRY=\${TIMESCALEDB_TELEMETRY}
    volumes:
      - ${BASE_DIR}/data:/var/lib/postgresql/data
      - ${BASE_DIR}/init:/docker-entrypoint-initdb.d:ro
      - ${BASE_DIR}/backups:/backups
      - ${BASE_DIR}/logs:/var/log/postgresql
      - ${BASE_DIR}/config/postgresql.conf:/etc/postgresql/postgresql.conf:ro
    command: 
      - postgres
      - -c
      - config_file=/etc/postgresql/postgresql.conf
${POSTGRES_PORTS}
    networks:
      - postgres_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER} -d \${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: pgadmin4
    restart: always
    environment:
      - PGADMIN_DEFAULT_EMAIL=\${PGADMIN_DEFAULT_EMAIL}
      - PGADMIN_DEFAULT_PASSWORD=\${PGADMIN_DEFAULT_PASSWORD}
      - PGADMIN_CONFIG_SERVER_MODE=\${PGADMIN_CONFIG_SERVER_MODE}
      - PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED=\${PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED}
      - PGADMIN_CONFIG_ENHANCED_COOKIE_PROTECTION=True
      - PGADMIN_CONFIG_LOGIN_BANNER="Authorized access only!"
    volumes:
      - ${BASE_DIR}/pgadmin:/var/lib/pgadmin
    ports:
      - "\${PGADMIN_PORT}:80"
    networks:
      - postgres_network
    depends_on:
      postgres:
        condition: service_healthy

networks:
  postgres_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
EOF

# Create backup script
print_info "Creating backup script..."
cat > "$BASE_DIR/scripts/backup.sh" << 'EOF'
#!/bin/bash
# PostgreSQL Backup Script

source /srv/postgres16/.env

BACKUP_DIR="/srv/postgres16/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.sql"

echo "Starting backup..."
docker exec postgres16 pg_dumpall -U postgres > $BACKUP_FILE

if [ $? -eq 0 ]; then
    gzip $BACKUP_FILE
    echo "✓ Backup completed: ${BACKUP_FILE}.gz"
    
    # Remove backups older than 30 days
    find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +30 -delete
    echo "✓ Old backups cleaned"
else
    echo "✗ Backup failed!"
    rm -f $BACKUP_FILE
    exit 1
fi
EOF
chmod +x "$BASE_DIR/scripts/backup.sh"

# Create monitoring script
print_info "Creating monitoring script..."
cat > "$BASE_DIR/scripts/monitor.sh" << 'EOF'
#!/bin/bash

source /srv/postgres16/.env

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}           PostgreSQL 16 + TimescaleDB Monitoring              ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Container Status
echo "📦 Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "NAME|postgres|pgadmin" || echo "No containers running"
echo ""

# Database Connections
echo "🔗 Active Connections:"
docker exec postgres16 psql -U postgres -c "SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;" 2>/dev/null || echo "Cannot retrieve connections"
echo ""

# Database Sizes
echo "💾 Database Sizes:"
docker exec postgres16 psql -U postgres -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) as size FROM pg_database WHERE datname NOT IN ('template0', 'template1');" 2>/dev/null || echo "Cannot retrieve sizes"
echo ""

# System Resources
echo "⚙️  Resource Usage:"
docker stats --no-stream postgres16 pgadmin4 2>/dev/null || echo "Cannot retrieve stats"
echo ""

# Access Information
echo -e "${GREEN}Access URLs:${NC}"
echo "  pgAdmin: http://${SERVER_IP}:5050"
if [ "${EXPOSE_POSTGRES}" = "true" ]; then
    echo "  PostgreSQL: ${SERVER_IP}:5432"
else
    echo "  PostgreSQL: Internal only (Docker network)"
fi
echo ""
EOF
chmod +x "$BASE_DIR/scripts/monitor.sh"

# Create credentials file
print_info "Saving credentials..."
cat > "$BASE_DIR/CREDENTIALS.txt" << EOF
═══════════════════════════════════════════════════════════════════
           PostgreSQL 16 + TimescaleDB + pgAdmin 4
                   Installation Credentials
═══════════════════════════════════════════════════════════════════
Generated: $(date)
Server IP: ${SERVER_IP}
Directory: ${BASE_DIR}

───────────────────────────────────────────────────────────────────
POSTGRESQL DATABASE:
───────────────────────────────────────────────────────────────────
Host: ${SERVER_IP}
Port: 5432 $([ "$EXPOSE_POSTGRES" = "false" ] && echo "(Docker network only)" || echo "(Exposed)")
Admin User: postgres
Admin Password: ${POSTGRES_PASSWORD}
Database: postgres / app_db

───────────────────────────────────────────────────────────────────
PGADMIN WEB INTERFACE:
───────────────────────────────────────────────────────────────────
URL: http://${SERVER_IP}:5050
Email: ${PGADMIN_EMAIL}
Password: ${PGADMIN_PASSWORD}

───────────────────────────────────────────────────────────────────
DATABASE USERS:
───────────────────────────────────────────────────────────────────
App User (Full Access):
  Username: app_user
  Password: ${APP_USER_PASSWORD}
  
Read-Only User:
  Username: readonly_user
  Password: ${READONLY_PASSWORD}
  
Backup User:
  Username: backup_user
  Password: ${BACKUP_PASSWORD}
  
Analytics User:
  Username: analytics_user
  Password: ${ANALYTICS_PASSWORD}

───────────────────────────────────────────────────────────────────
CONNECTION STRINGS:
───────────────────────────────────────────────────────────────────
Application (Full Access):
postgresql://app_user:${APP_USER_PASSWORD}@${SERVER_IP}:5432/app_db

Read-Only Access:
postgresql://readonly_user:${READONLY_PASSWORD}@${SERVER_IP}:5432/app_db

───────────────────────────────────────────────────────────────────
QUICK COMMANDS:
───────────────────────────────────────────────────────────────────
View this file: cat ${BASE_DIR}/CREDENTIALS.txt
Monitor status: ${BASE_DIR}/scripts/monitor.sh
Run backup: ${BASE_DIR}/scripts/backup.sh
Connect to DB: docker exec -it postgres16 psql -U postgres

═══════════════════════════════════════════════════════════════════
Keep this file secure! All passwords are 12 characters alphanumeric.
═══════════════════════════════════════════════════════════════════
EOF

sudo chmod 600 "$BASE_DIR/CREDENTIALS.txt"

# Setup cron for automated backups
print_info "Setting up automated backups..."
(crontab -l 2>/dev/null || true; echo "0 2 * * * $BASE_DIR/scripts/backup.sh") | crontab -

# Display summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}              ✓ SETUP COMPLETED SUCCESSFULLY!                      ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}📁 Installation:${NC} ${BASE_DIR}"
echo -e "${CYAN}🌐 Server IP:${NC} ${SERVER_IP}"
echo ""
echo -e "${MAGENTA}🔐 Access Credentials:${NC}"
echo ""
echo "  PostgreSQL:"
echo "    User: postgres"
echo "    Pass: ${POSTGRES_PASSWORD}"
echo ""
echo "  pgAdmin:"
echo "    URL: http://${SERVER_IP}:5050"
echo "    Email: ${PGADMIN_EMAIL}"
echo "    Pass: ${PGADMIN_PASSWORD}"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "1. Copy docker-compose.yml to Portainer Stack"
echo "2. Copy .env content to Environment variables"
echo "3. Deploy the stack"
echo "4. Access pgAdmin at http://${SERVER_IP}:5050"
echo ""
echo -e "${GREEN}All credentials saved to:${NC} ${BASE_DIR}/CREDENTIALS.txt"
echo -e "${GREEN}Monitor status:${NC} ${BASE_DIR}/scripts/monitor.sh"
echo ""
