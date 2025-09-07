#!/bin/bash

# Quick non-interactive PostgreSQL setup script
# Can be run with: curl -fsSL [URL] | bash

set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}Starting PostgreSQL 16 Quick Setup...${NC}"

# Auto-detect server IP
SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')
BASE_DIR="/srv/postgres16"

echo "Server IP: ${SERVER_IP}"
echo "Install directory: ${BASE_DIR}"

# Generate simple passwords
generate_password() {
    local chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local password=""
    for i in {1..12}; do
        password="${password}${chars:RANDOM % ${#chars}:1}"
    done
    echo "$password"
}

# Generate credentials
POSTGRES_USER="admin$(openssl rand -hex 2)"
POSTGRES_PASSWORD=$(generate_password)
POSTGRES_DB="maindb"
PGADMIN_EMAIL="admin@${SERVER_IP}"
PGADMIN_PASSWORD=$(generate_password)
APP_USER="appuser"
APP_PASSWORD=$(generate_password)
READONLY_USER="readonly"
READONLY_PASSWORD=$(generate_password)

# Create directories
sudo mkdir -p ${BASE_DIR}/{init-scripts,backups,data,pgadmin,scripts,config,logs}

# Create .env file
cat > /tmp/postgres.env << EOF
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}
PGADMIN_EMAIL=${PGADMIN_EMAIL}
PGADMIN_PASSWORD=${PGADMIN_PASSWORD}
DATABASE_URL=postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}
DATABASE_URL_READONLY=postgresql://${READONLY_USER}:${READONLY_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}
SERVER_IP=${SERVER_IP}
EOF

sudo mv /tmp/postgres.env ${BASE_DIR}/.env

# Download additional setup files from GitHub
echo "Downloading setup files..."
curl -fsSL https://raw.githubusercontent.com/drhema/postgresql_self_hosting/refs/heads/main/postgresql-self.sh -o ${BASE_DIR}/full-setup.sh
chmod +x ${BASE_DIR}/full-setup.sh

# Save credentials
cat > ${BASE_DIR}/CREDENTIALS.txt << EOF
════════════════════════════════════════════════════════════
PostgreSQL 16 Quick Setup Credentials
Generated: $(date)
Server: ${SERVER_IP}
════════════════════════════════════════════════════════════

POSTGRESQL:
Username: ${POSTGRES_USER}
Password: ${POSTGRES_PASSWORD}
Database: ${POSTGRES_DB}

PGADMIN:
URL: http://${SERVER_IP}:5050
Email: ${PGADMIN_EMAIL}
Password: ${PGADMIN_PASSWORD}

APP USER:
Username: ${APP_USER}
Password: ${APP_PASSWORD}

READ-ONLY:
Username: ${READONLY_USER}
Password: ${READONLY_PASSWORD}

CONNECTION STRINGS:
Main: postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}
ReadOnly: postgresql://${READONLY_USER}:${READONLY_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}

════════════════════════════════════════════════════════════
EOF

echo ""
echo -e "${GREEN}✓ Quick setup complete!${NC}"
echo ""
echo -e "${YELLOW}📁 Files created at: ${BASE_DIR}${NC}"
echo -e "${YELLOW}📄 Credentials saved to: ${BASE_DIR}/CREDENTIALS.txt${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "1. Review credentials: cat ${BASE_DIR}/CREDENTIALS.txt"
echo "2. Copy docker-compose.yml to Portainer"
echo "3. Use environment variables from: ${BASE_DIR}/.env"
echo ""
echo -e "${GREEN}Database URL for your apps:${NC}"
echo "postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}"
echo ""
