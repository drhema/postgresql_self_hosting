#!/bin/bash

# PostgreSQL 16 + TimescaleDB + pgAdmin Setup Script
# Works on any server with auto-detection
# Generates simple 12-character passwords for easy app integration

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
║           Simple Passwords for App Integration           ║
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

# Generate credentials
print_info "Generating secure credentials..."
POSTGRES_USER="admin$(openssl rand -hex 2)"
POSTGRES_PASSWORD=$(generate_password)
POSTGRES_DB="maindb"
# Use valid email domain (not IP)
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

# Create .env file
print_info "Creating environment file..."
cat > /tmp/.env << EOF
# PostgreSQL 16 Environment Variables
# Generated: $(date)
# Server: ${SERVER_IP}

# PostgreSQL Configuration
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}

# pgAdmin Configuration (using valid email domain)
PGADMIN_EMAIL=${PGADMIN_EMAIL}
PGADMIN_PASSWORD=${PGADMIN_PASSWORD}

# Database Users
DB_READONLY_USER=${READONLY_USER}
DB_READONLY_PASSWORD=${READONLY_PASSWORD}
DB_APP_USER=${APP_USER}
DB_APP_PASSWORD=${APP_PASSWORD}
DB_MONITOR_USER=${MONITOR_USER}
DB_MONITOR_PASSWORD=${MONITOR_PASSWORD}

# Connection URLs for Apps
DATABASE_URL=postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}
DATABASE_URL_READONLY=postgresql://${READONLY_USER}:${READONLY_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}

# Server Info
SERVER_IP=${SERVER_IP}
TZ=UTC
EOF

sudo mv /tmp/.env ${BASE_DIR}/.env
sudo chmod 644 ${BASE_DIR}/.env
print_success "Environment file created"

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
      "Comment": "PostgreSQL 16 with TimescaleDB",
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
-- PostgreSQL 16 Initialization
-- Generated: $(date)

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create users
CREATE USER ${READONLY_USER} WITH PASSWORD '${READONLY_PASSWORD}';
CREATE USER ${APP_USER} WITH PASSWORD '${APP_PASSWORD}';
CREATE USER ${MONITOR_USER} WITH PASSWORD '${MONITOR_PASSWORD}';

-- Grant permissions
GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${READONLY_USER};
GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${APP_USER};
GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${MONITOR_USER};

-- Set default privileges
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO ${READONLY_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${APP_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${APP_USER};

-- Create sample table
CREATE TABLE IF NOT EXISTS app_info (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) UNIQUE NOT NULL,
    value TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO app_info (key, value) VALUES 
    ('version', '1.0.0'),
    ('setup_date', '$(date)'),
    ('server_ip', '${SERVER_IP}');

\echo 'Database initialization complete!'
EOF

sudo mv /tmp/01-init.sql ${BASE_DIR}/init-scripts/01-init.sql
print_success "Initialization script created"

# Create monitoring script
print_info "Creating monitoring script..."
cat > /tmp/monitor.sh << 'EOF'
#!/bin/bash

SCRIPT_DIR="/srv/postgres16"
source ${SCRIPT_DIR}/.env

echo "═══════════════════════════════════════════════════════"
echo "        PostgreSQL 16 Monitoring Dashboard"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "postgres|pgadmin"
echo ""
echo "Database Info:"
echo "  Server: ${SERVER_IP}:5432"
echo "  Database: ${POSTGRES_DB}"
echo "  Admin User: ${POSTGRES_USER}"
echo ""
echo "Quick Commands:"
echo "  Connect: docker exec -it postgres16 psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
echo "  Logs: docker logs postgres16 --tail 20"
echo ""
echo "Access URLs:"
echo "  pgAdmin: http://${SERVER_IP}:5050"
echo "  PostgreSQL: ${SERVER_IP}:5432"
echo ""
echo "App Connection String:"
echo "  ${DATABASE_URL}"
EOF

sudo mv /tmp/monitor.sh ${BASE_DIR}/scripts/monitor.sh
sudo chmod +x ${BASE_DIR}/scripts/monitor.sh
print_success "Monitoring script created"

# Create credentials file
print_info "Saving credentials..."
cat > /tmp/CREDENTIALS.txt << EOF
═══════════════════════════════════════════════════════════════════
                 PostgreSQL 16 + TimescaleDB + pgAdmin
                        Installation Credentials
═══════════════════════════════════════════════════════════════════
Generated: $(date)
Server IP: ${SERVER_IP}
Directory: ${BASE_DIR}

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
CONNECTION STRINGS FOR YOUR APPS:
───────────────────────────────────────────────────────────────────
Main App (Read/Write):
postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}

Read-Only Access:
postgresql://${READONLY_USER}:${READONLY_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}

Admin Access:
postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}

───────────────────────────────────────────────────────────────────
FOR YOUR APPLICATION .ENV FILE:
───────────────────────────────────────────────────────────────────
DATABASE_URL=postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}
DB_HOST=${SERVER_IP}
DB_PORT=5432
DB_NAME=${POSTGRES_DB}
DB_USER=${APP_USER}
DB_PASSWORD=${APP_PASSWORD}

═══════════════════════════════════════════════════════════════════
IMPORTANT: Save this file securely! All passwords are 12 characters,
alphanumeric only - perfect for .env files without escaping issues.
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
echo -e "${CYAN}📄 Credentials file:${NC} ${BASE_DIR}/CREDENTIALS.txt"
echo -e "${CYAN}📋 Environment file:${NC} ${BASE_DIR}/.env"
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
