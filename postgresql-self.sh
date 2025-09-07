#!/bin/bash

# PostgreSQL 16 + TimescaleDB + pgAdmin Setup Script with IP Whitelisting
# Works on any server with auto-detection
# Supports multiple IP whitelist for PostgreSQL connections

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Auto-detect server IP
detect_server_ip() {
    SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || \
                curl -s -4 icanhazip.com 2>/dev/null || \
                curl -s -4 api.ipify.org 2>/dev/null || \
                hostname -I | awk '{print $1}')
    
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="localhost"
    fi
    echo "$SERVER_IP"
}

# Configuration
BASE_DIR="/srv/postgres16"
SERVER_IP=$(detect_server_ip)

# Functions
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

# Generate simple 12-character alphanumeric passwords
generate_password() {
    local chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local password=""
    for i in {1..12}; do
        password="${password}${chars:RANDOM % ${#chars}:1}"
    done
    echo "$password"
}

# Header
clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║     PostgreSQL 16 + TimescaleDB + pgAdmin Setup          ║
║         With IP Whitelisting & Security Features         ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_info "Starting PostgreSQL stack setup..."
print_info "Server IP: ${SERVER_IP}"
print_info "Install directory: ${BASE_DIR}"
echo ""

# Ask for custom directory
read -p "Use default directory ${BASE_DIR}? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter custom directory path: " CUSTOM_DIR
    BASE_DIR="${CUSTOM_DIR}"
    print_info "Using directory: ${BASE_DIR}"
fi

# IP Whitelisting Configuration
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}                    IP WHITELISTING CONFIGURATION                 ${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Enter IP addresses that should have access to PostgreSQL."
echo "Separate multiple IPs with commas (e.g., 192.168.1.100,10.0.0.5)"
echo "Leave empty to allow connections from anywhere (less secure)"
echo ""
read -p "Allowed IPs (comma-separated): " ALLOWED_IPS_INPUT

# Process allowed IPs
if [ -z "$ALLOWED_IPS_INPUT" ]; then
    ALLOWED_IPS="0.0.0.0/0"
    POSTGRES_LISTEN="*"
    print_warning "No IP restrictions - PostgreSQL will accept connections from anywhere"
else
    ALLOWED_IPS="$ALLOWED_IPS_INPUT"
    POSTGRES_LISTEN="localhost,${ALLOWED_IPS_INPUT}"
    print_success "PostgreSQL will only accept connections from: ${ALLOWED_IPS}"
fi

# Generate credentials
print_info "Generating secure credentials..."
POSTGRES_USER="admin$(openssl rand -hex 2)"
POSTGRES_PASSWORD=$(generate_password)
POSTGRES_DB="maindb"
PGADMIN_EMAIL="admin@example.com"
PGADMIN_PASSWORD=$(generate_password)
READONLY_USER="readonly"
READONLY_PASSWORD=$(generate_password)
APP_USER="appuser"
APP_PASSWORD=$(generate_password)
MONITOR_USER="monitor"
MONITOR_PASSWORD=$(generate_password)

# Display credentials
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}                    🔐 GENERATED CREDENTIALS                      ${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${MAGENTA}PostgreSQL Super Admin:${NC}"
echo -e "  ${CYAN}Username:${NC} ${POSTGRES_USER}"
echo -e "  ${CYAN}Password:${NC} ${POSTGRES_PASSWORD}"
echo -e "  ${CYAN}Database:${NC} ${POSTGRES_DB}"
echo ""
echo -e "${MAGENTA}pgAdmin Web Interface:${NC}"
echo -e "  ${CYAN}URL:${NC}      http://${SERVER_IP}:5050"
echo -e "  ${CYAN}Email:${NC}    ${PGADMIN_EMAIL}"
echo -e "  ${CYAN}Password:${NC} ${PGADMIN_PASSWORD}"
echo ""
echo -e "${MAGENTA}Database Users:${NC}"
echo -e "  ${CYAN}App User:${NC}    ${APP_USER} / ${APP_PASSWORD}"
echo -e "  ${CYAN}Read-Only:${NC}   ${READONLY_USER} / ${READONLY_PASSWORD}"
echo -e "  ${CYAN}Monitor:${NC}     ${MONITOR_USER} / ${MONITOR_PASSWORD}"
echo ""
echo -e "${MAGENTA}Security Settings:${NC}"
echo -e "  ${CYAN}Allowed IPs:${NC} ${ALLOWED_IPS}"
echo ""
echo -e "${YELLOW}📝 All passwords are 12 characters, alphanumeric only${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Confirmation
read -p "Continue with setup? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Setup cancelled"
    exit 1
fi

# Create directory structure
print_info "Creating directory structure..."
sudo mkdir -p ${BASE_DIR}/{init-scripts,backups,data,pgadmin,scripts,config,logs}
print_success "Directories created"

# Create .env file with IP whitelist
print_info "Creating environment file with security settings..."
cat > /tmp/.env << EOF
# PostgreSQL 16 Environment Variables
# Generated: $(date)
# Server: ${SERVER_IP}

# ═══════════════════════════════════════════════════════════════════
# POSTGRESQL CONFIGURATION
# ═══════════════════════════════════════════════════════════════════
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}

# ═══════════════════════════════════════════════════════════════════
# SECURITY - IP WHITELIST
# ═══════════════════════════════════════════════════════════════════
# IPs allowed to connect to PostgreSQL (comma-separated)
# Use 0.0.0.0/0 to allow all (not recommended for production)
ALLOWED_IPS=${ALLOWED_IPS}
POSTGRES_LISTEN_ADDRESSES=${POSTGRES_LISTEN}

# ═══════════════════════════════════════════════════════════════════
# PGADMIN CONFIGURATION
# ═══════════════════════════════════════════════════════════════════
PGADMIN_EMAIL=${PGADMIN_EMAIL}
PGADMIN_PASSWORD=${PGADMIN_PASSWORD}

# ═══════════════════════════════════════════════════════════════════
# DATABASE USERS
# ═══════════════════════════════════════════════════════════════════
DB_READONLY_USER=${READONLY_USER}
DB_READONLY_PASSWORD=${READONLY_PASSWORD}
DB_APP_USER=${APP_USER}
DB_APP_PASSWORD=${APP_PASSWORD}
DB_MONITOR_USER=${MONITOR_USER}
DB_MONITOR_PASSWORD=${MONITOR_PASSWORD}

# ═══════════════════════════════════════════════════════════════════
# CONNECTION URLS FOR APPLICATIONS
# ═══════════════════════════════════════════════════════════════════
DATABASE_URL=postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}
DATABASE_URL_READONLY=postgresql://${READONLY_USER}:${READONLY_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}
DATABASE_URL_ADMIN=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}

# ═══════════════════════════════════════════════════════════════════
# SERVER INFORMATION
# ═══════════════════════════════════════════════════════════════════
SERVER_IP=${SERVER_IP}
TZ=UTC
POSTGRES_MAX_CONNECTIONS=200
POSTGRES_SHARED_BUFFERS=256MB
EOF

sudo mv /tmp/.env ${BASE_DIR}/.env
sudo chmod 644 ${BASE_DIR}/.env
print_success "Environment file created with security settings"

# Create PostgreSQL configuration for IP restrictions
print_info "Creating PostgreSQL security configuration..."
cat > /tmp/pg_hba_custom.conf << EOF
# PostgreSQL Client Authentication Configuration
# Generated: $(date)
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections
local   all             all                                     trust

# IPv4 local connections from Docker network
host    all             all             172.0.0.0/8             md5

# Allowed external IPs
EOF

# Add each allowed IP to pg_hba configuration
if [ "$ALLOWED_IPS" != "0.0.0.0/0" ]; then
    IFS=',' read -ra IPS <<< "$ALLOWED_IPS"
    for ip in "${IPS[@]}"; do
        ip=$(echo "$ip" | xargs)  # Trim whitespace
        echo "host    all             all             ${ip}/32                md5" >> /tmp/pg_hba_custom.conf
    done
else
    echo "host    all             all             0.0.0.0/0               md5" >> /tmp/pg_hba_custom.conf
fi

sudo mv /tmp/pg_hba_custom.conf ${BASE_DIR}/config/pg_hba_custom.conf
print_success "PostgreSQL security configuration created"

# Create pgAdmin servers configuration
print_info "Creating pgAdmin configuration..."
cat > /tmp/pgadmin-servers.json << EOF
{
  "Servers": {
    "1": {
      "Name": "PostgreSQL 16 - Main",
      "Group": "Production",
      "Host": "postgres",
      "Port": 5432,
      "MaintenanceDB": "postgres",
      "Username": "${POSTGRES_USER}",
      "SSLMode": "prefer",
      "Comment": "PostgreSQL 16 with TimescaleDB (IP Restricted)",
      "BGColor": "#00BCD4",
      "FGColor": "#ffffff"
    }
  }
}
EOF

sudo mv /tmp/pgadmin-servers.json ${BASE_DIR}/pgadmin-servers.json
print_success "pgAdmin configuration created"

# Create SQL initialization script
print_info "Creating database initialization script..."
cat > /tmp/01-init.sql << EOF
-- PostgreSQL 16 Initialization with Security
-- Generated: $(date)

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create users with limited permissions
CREATE USER ${READONLY_USER} WITH PASSWORD '${READONLY_PASSWORD}';
CREATE USER ${APP_USER} WITH PASSWORD '${APP_PASSWORD}';
CREATE USER ${MONITOR_USER} WITH PASSWORD '${MONITOR_PASSWORD}';

-- Grant appropriate permissions
GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${READONLY_USER};
GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${APP_USER};
GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${MONITOR_USER};

-- Set default privileges
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO ${READONLY_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${APP_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${APP_USER};

-- Create connection tracking table
CREATE TABLE IF NOT EXISTS connection_log (
    id SERIAL PRIMARY KEY,
    username TEXT,
    ip_address INET,
    connected_at TIMESTAMPTZ DEFAULT NOW(),
    application_name TEXT
);

-- Log current configuration
CREATE TABLE IF NOT EXISTS setup_info (
    key VARCHAR(255) PRIMARY KEY,
    value TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO setup_info (key, value) VALUES 
    ('version', '1.0.0'),
    ('setup_date', '$(date)'),
    ('server_ip', '${SERVER_IP}'),
    ('allowed_ips', '${ALLOWED_IPS}'),
    ('postgres_version', version());

\echo 'Database initialization complete with security settings!'
EOF

sudo mv /tmp/01-init.sql ${BASE_DIR}/init-scripts/01-init.sql
print_success "Initialization script created"

# Create view configuration script
print_info "Creating configuration viewer script..."
cat > /tmp/show-config.sh << 'EOF'
#!/bin/bash

# PostgreSQL Configuration Viewer
SCRIPT_DIR="/srv/postgres16"
source ${SCRIPT_DIR}/.env

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'

clear
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}              PostgreSQL Configuration & Credentials               ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${MAGENTA}▶ Server Information:${NC}"
echo "  Server IP: ${SERVER_IP}"
echo "  Installation Path: ${SCRIPT_DIR}"
echo "  Timezone: ${TZ}"
echo ""

echo -e "${MAGENTA}▶ Security Settings:${NC}"
echo "  Allowed IPs: ${ALLOWED_IPS}"
if [ "${ALLOWED_IPS}" == "0.0.0.0/0" ]; then
    echo -e "  ${YELLOW}⚠ Warning: PostgreSQL accepts connections from anywhere${NC}"
else
    echo -e "  ${GREEN}✓ PostgreSQL restricted to specific IPs only${NC}"
fi
echo ""

echo -e "${MAGENTA}▶ PostgreSQL Admin:${NC}"
echo "  Username: ${POSTGRES_USER}"
echo "  Password: ${POSTGRES_PASSWORD}"
echo "  Database: ${POSTGRES_DB}"
echo "  Port: 5432"
echo ""

echo -e "${MAGENTA}▶ pgAdmin Access:${NC}"
echo "  URL: http://${SERVER_IP}:5050"
echo "  Email: ${PGADMIN_EMAIL}"
echo "  Password: ${PGADMIN_PASSWORD}"
echo ""

echo -e "${MAGENTA}▶ Application Users:${NC}"
echo "  App User: ${DB_APP_USER} / ${DB_APP_PASSWORD}"
echo "  ReadOnly: ${DB_READONLY_USER} / ${DB_READONLY_PASSWORD}"
echo "  Monitor: ${DB_MONITOR_USER} / ${DB_MONITOR_PASSWORD}"
echo ""

echo -e "${MAGENTA}▶ Connection Strings:${NC}"
echo "  App URL: ${DATABASE_URL}"
echo "  ReadOnly URL: ${DATABASE_URL_READONLY}"
echo ""

echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}To modify settings, edit: ${SCRIPT_DIR}/.env${NC}"
echo -e "${YELLOW}Then restart: docker-compose down && docker-compose up -d${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
EOF

sudo mv /tmp/show-config.sh ${BASE_DIR}/scripts/show-config.sh
sudo chmod +x ${BASE_DIR}/scripts/show-config.sh
print_success "Configuration viewer created"

# Create monitoring script
print_info "Creating monitoring script..."
cat > /tmp/monitor.sh << 'EOF'
#!/bin/bash

SCRIPT_DIR="/srv/postgres16"
source ${SCRIPT_DIR}/.env

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo "              PostgreSQL 16 Monitoring Dashboard"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "NAME|postgres|pgadmin"
echo ""
echo "Security Status:"
echo "  Allowed IPs: ${ALLOWED_IPS}"
echo ""
echo "Database Connections:"
docker exec postgres16 psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT client_addr, usename, application_name, state FROM pg_stat_activity WHERE client_addr IS NOT NULL;" 2>/dev/null || echo "  No active connections"
echo ""
echo "Quick Commands:"
echo "  Show Config: ${SCRIPT_DIR}/scripts/show-config.sh"
echo "  Connect DB: docker exec -it postgres16 psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
echo "  View Logs: docker logs postgres16 --tail 20"
echo ""
echo "Access URLs:"
echo "  pgAdmin: http://${SERVER_IP}:5050"
echo "  PostgreSQL: ${SERVER_IP}:5432 (Restricted to: ${ALLOWED_IPS})"
echo ""
EOF

sudo mv /tmp/monitor.sh ${BASE_DIR}/scripts/monitor.sh
sudo chmod +x ${BASE_DIR}/scripts/monitor.sh
print_success "Monitoring script created"

# Create credentials file
print_info "Saving complete credentials..."
cat > /tmp/CREDENTIALS.txt << EOF
═══════════════════════════════════════════════════════════════════
                 PostgreSQL 16 + TimescaleDB + pgAdmin
                     Secure Installation Credentials
═══════════════════════════════════════════════════════════════════
Generated: $(date)
Server IP: ${SERVER_IP}
Directory: ${BASE_DIR}

───────────────────────────────────────────────────────────────────
SECURITY CONFIGURATION:
───────────────────────────────────────────────────────────────────
Allowed IPs: ${ALLOWED_IPS}
Listen Addresses: ${POSTGRES_LISTEN}

Note: Only the IPs listed above can connect to PostgreSQL port 5432.
To modify, edit ${BASE_DIR}/.env and restart the stack.

───────────────────────────────────────────────────────────────────
POSTGRESQL DATABASE:
───────────────────────────────────────────────────────────────────
Host: ${SERVER_IP}
Port: 5432
Admin Username: ${POSTGRES_USER}
Admin Password: ${POSTGRES_PASSWORD}
Database Name: ${POSTGRES_DB}

───────────────────────────────────────────────────────────────────
PGADMIN WEB INTERFACE:
───────────────────────────────────────────────────────────────────
URL: http://${SERVER_IP}:5050
Login Email: ${PGADMIN_EMAIL}
Login Password: ${PGADMIN_PASSWORD}

───────────────────────────────────────────────────────────────────
APPLICATION USERS:
───────────────────────────────────────────────────────────────────
App User (Read/Write):
  Username: ${APP_USER}
  Password: ${APP_PASSWORD}
  
Read-Only User:
  Username: ${READONLY_USER}
  Password: ${READONLY_PASSWORD}
  
Monitor User:
  Username: ${MONITOR_USER}
  Password: ${MONITOR_PASSWORD}

───────────────────────────────────────────────────────────────────
CONNECTION STRINGS:
───────────────────────────────────────────────────────────────────
Main App (Read/Write):
postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}

Read-Only Access:
postgresql://${READONLY_USER}:${READONLY_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}

Admin Access:
postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}

───────────────────────────────────────────────────────────────────
MANAGEMENT COMMANDS:
───────────────────────────────────────────────────────────────────
View Configuration: ${BASE_DIR}/scripts/show-config.sh
Monitor Status: ${BASE_DIR}/scripts/monitor.sh
View This File: cat ${BASE_DIR}/CREDENTIALS.txt
Edit Settings: nano ${BASE_DIR}/.env

═══════════════════════════════════════════════════════════════════
IMPORTANT: Keep this file secure! Passwords are 12 characters,
alphanumeric only - perfect for .env files without escaping.
═══════════════════════════════════════════════════════════════════
EOF

sudo mv /tmp/CREDENTIALS.txt ${BASE_DIR}/CREDENTIALS.txt
sudo chmod 644 ${BASE_DIR}/CREDENTIALS.txt
print_success "Credentials saved"

# Set permissions
print_info "Setting permissions..."
sudo chown -R 999:999 ${BASE_DIR}/data 2>/dev/null || true
sudo chown -R 5050:5050 ${BASE_DIR}/pgadmin 2>/dev/null || true
sudo chmod 755 ${BASE_DIR}
print_success "Permissions set"

# Final summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                  ✓ SETUP COMPLETED SUCCESSFULLY!                  ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}📁 Files created at:${NC} ${BASE_DIR}"
echo -e "${CYAN}🔒 Security:${NC} PostgreSQL restricted to: ${ALLOWED_IPS}"
echo ""
echo -e "${YELLOW}📋 View configuration anytime:${NC}"
echo "   ${BASE_DIR}/scripts/show-config.sh"
echo ""
echo -e "${YELLOW}🚀 Next Steps:${NC}"
echo "1. Copy docker-compose.yml to Portainer"
echo "2. Load environment variables from ${BASE_DIR}/.env"
echo "3. Deploy the stack"
echo "4. Access pgAdmin at http://${SERVER_IP}:5050"
echo ""
echo -e "${GREEN}App Connection String:${NC}"
echo "postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}"
echo ""
echo -e "${CYAN}To view all credentials and settings later:${NC}"
echo "cat ${BASE_DIR}/CREDENTIALS.txt"
echo "${BASE_DIR}/scripts/show-config.sh"
echo ""
