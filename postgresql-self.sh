#!/bin/bash

# PostgreSQL 16 Server Preparation Script
# Works on any server - auto-detects IP address
# Generates simple 12-character passwords for easy app integration

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Auto-detect server IP (tries multiple methods)
detect_server_ip() {
    # Try to get public IP
    SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || \
                curl -s -4 icanhazip.com 2>/dev/null || \
                curl -s -4 api.ipify.org 2>/dev/null || \
                echo "")
    
    # If no public IP, get local IP
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(hostname -I | awk '{print $1}')
    fi
    
    # If still empty, use localhost
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="localhost"
    fi
    
    echo "$SERVER_IP"
}

# Configuration
BASE_DIR="/srv/postgres16"
SERVER_IP=$(detect_server_ip)

# Function to print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Function to generate simple 12-character alphanumeric passwords
# Only uses letters and numbers for easy .env file usage
generate_password() {
    # Generate 12-character password with only alphanumeric characters
    # Mix of uppercase, lowercase, and numbers
    local password=""
    local chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    for i in {1..12}; do
        password="${password}${chars:RANDOM % ${#chars}:1}"
    done
    echo "$password"
}

# Function to generate simple username
generate_username() {
    # Generate simple username with 4-char hex suffix
    local suffix=$(openssl rand -hex 2)
    echo "admin${suffix}"
}

# ASCII Art Header
clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     PostgreSQL 16 + pgAdmin Server Preparation Tool      ║
║           Simple Passwords for App Integration           ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_info "Starting server preparation for PostgreSQL stack..."
print_info "Auto-detected Server IP: ${SERVER_IP}"
print_info "Target directory: ${BASE_DIR}"
echo ""

# Allow custom directory
read -p "Use default directory ${BASE_DIR}? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter custom directory path: " CUSTOM_DIR
    BASE_DIR="${CUSTOM_DIR}"
    print_info "Using directory: ${BASE_DIR}"
fi

# Generate simple credentials (12 chars, alphanumeric only)
print_step "Generating simple app-friendly credentials..."
POSTGRES_USER=$(generate_username)
POSTGRES_PASSWORD=$(generate_password)
POSTGRES_DB="maindb"
PGADMIN_EMAIL="admin@${SERVER_IP}"
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
echo -e "${GREEN}           🔐 GENERATED CREDENTIALS (App-Friendly)                ${NC}"
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
echo -e "  ${CYAN}Read-Only:${NC}  ${READONLY_USER} / ${READONLY_PASSWORD}"
echo -e "  ${CYAN}App User:${NC}   ${APP_USER} / ${APP_PASSWORD}"
echo -e "  ${CYAN}Monitor:${NC}    ${MONITOR_USER} / ${MONITOR_PASSWORD}"
echo ""
echo -e "${YELLOW}📝 Note: All passwords are 12 characters, alphanumeric only${NC}"
echo -e "${YELLOW}   Perfect for .env files - no special characters to escape!${NC}"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Ask for confirmation
echo -e "${YELLOW}This script will create directories and files at ${BASE_DIR}${NC}"
read -p "Do you want to continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Setup cancelled by user"
    exit 1
fi

# Create directory structure
print_step "Creating directory structure..."
sudo mkdir -p ${BASE_DIR}/{init-scripts,backups,data,pgadmin,scripts,config,logs}
print_success "Directories created"

# Create .env file for Portainer and apps
print_step "Creating .env file for Portainer stack and apps..."
cat > /tmp/.env << EOF
# PostgreSQL 16 Environment Variables
# Generated: $(date)
# Server: ${SERVER_IP}
# Simple 12-character alphanumeric passwords for easy app integration

# PostgreSQL Configuration
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}

# pgAdmin Configuration  
PGADMIN_EMAIL=${PGADMIN_EMAIL}
PGADMIN_PASSWORD=${PGADMIN_PASSWORD}

# Database Users (for your apps)
DB_READONLY_USER=${READONLY_USER}
DB_READONLY_PASSWORD=${READONLY_PASSWORD}
DB_APP_USER=${APP_USER}
DB_APP_PASSWORD=${APP_PASSWORD}
DB_MONITOR_USER=${MONITOR_USER}
DB_MONITOR_PASSWORD=${MONITOR_PASSWORD}

# Connection URLs (ready to use in your apps)
DATABASE_URL=postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}
DATABASE_URL_READONLY=postgresql://${READONLY_USER}:${READONLY_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}

# Additional Settings
TZ=UTC
POSTGRES_MAX_CONNECTIONS=200
POSTGRES_SHARED_BUFFERS=256MB
SERVER_IP=${SERVER_IP}
EOF

sudo mv /tmp/.env ${BASE_DIR}/.env
sudo chmod 644 ${BASE_DIR}/.env  # Readable for easy copying
print_success "Environment file created (readable for easy copying)"

# Create app-example.env file
print_step "Creating example .env file for your applications..."
cat > /tmp/app-example.env << EOF
# Example .env for your application
# Copy these lines to your app's .env file

# PostgreSQL Connection (Read/Write)
DATABASE_URL=postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}

# PostgreSQL Connection (Read-Only)
DATABASE_URL_READONLY=postgresql://${READONLY_USER}:${READONLY_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}

# Individual Components (if needed)
DB_HOST=${SERVER_IP}
DB_PORT=5432
DB_NAME=${POSTGRES_DB}
DB_USER=${APP_USER}
DB_PASSWORD=${APP_PASSWORD}

# For Prisma/TypeORM/Sequelize
DATABASE_URL=postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}?schema=public

# For Django
# Add to settings.py:
# DATABASES = {
#     'default': {
#         'ENGINE': 'django.db.backends.postgresql',
#         'NAME': '${POSTGRES_DB}',
#         'USER': '${APP_USER}',
#         'PASSWORD': '${APP_PASSWORD}',
#         'HOST': '${SERVER_IP}',
#         'PORT': '5432',
#     }
# }
EOF

sudo mv /tmp/app-example.env ${BASE_DIR}/app-example.env
print_success "App example .env file created"

# Create pgAdmin servers configuration
print_step "Creating pgAdmin server configuration..."
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
      "Comment": "Supabase PostgreSQL 16 with TimescaleDB",
      "BGColor": "#00BCD4",
      "FGColor": "#ffffff",
      "Timeout": 10,
      "UseSSHTunnel": 0
    },
    "2": {
      "Name": "PostgreSQL 16 - App User",
      "Group": "Production",
      "Host": "postgres",
      "Port": 5432,
      "MaintenanceDB": "${POSTGRES_DB}",
      "Username": "${APP_USER}",
      "SSLMode": "prefer",
      "Comment": "Application User Access",
      "BGColor": "#4CAF50",
      "FGColor": "#ffffff",
      "Timeout": 10,
      "UseSSHTunnel": 0
    },
    "3": {
      "Name": "PostgreSQL 16 - ReadOnly",
      "Group": "Production",
      "Host": "postgres",
      "Port": 5432,
      "MaintenanceDB": "${POSTGRES_DB}",
      "Username": "${READONLY_USER}",
      "SSLMode": "prefer",
      "Comment": "Read-Only Access",
      "BGColor": "#FF9800",
      "FGColor": "#ffffff",
      "Timeout": 10,
      "UseSSHTunnel": 0
    }
  }
}
EOF

sudo mv /tmp/pgadmin-servers.json ${BASE_DIR}/pgadmin-servers.json
print_success "pgAdmin configuration created"

# Create comprehensive SQL initialization script
print_step "Creating database initialization scripts..."
cat > /tmp/01-init-database.sql << EOF
-- PostgreSQL 16 Initialization Script
-- Generated: $(date)
-- Server: ${SERVER_IP}
-- This script sets up extensions, users, and sample schemas

\echo '===================================='
\echo 'Starting Database Initialization...'
\echo '===================================='

-- Create extensions in postgres database first
\c postgres;

-- Core Extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- TimescaleDB (most important)
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- Supabase Extensions
CREATE EXTENSION IF NOT EXISTS pgjwt;
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_hashids;
CREATE EXTENSION IF NOT EXISTS pg_jsonschema;

\echo 'Extensions installed in postgres database'

-- Now setup main database
\c ${POSTGRES_DB};

-- Enable extensions in main database
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pgjwt;
CREATE EXTENSION IF NOT EXISTS vector;

\echo 'Extensions enabled in ${POSTGRES_DB}'

-- Create schemas
CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS api;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS monitoring;
COMMENT ON SCHEMA app IS 'Application data and tables';
COMMENT ON SCHEMA api IS 'API functions and views';
COMMENT ON SCHEMA audit IS 'Audit and logging tables';
COMMENT ON SCHEMA monitoring IS 'Monitoring and metrics data';

-- Create users with specific permissions
\echo 'Creating database users...'

-- Read-only user (for reporting, analytics)
CREATE USER ${READONLY_USER} WITH PASSWORD '${READONLY_PASSWORD}';
GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${READONLY_USER};
GRANT USAGE ON SCHEMA public, app, api TO ${READONLY_USER};
GRANT SELECT ON ALL TABLES IN SCHEMA public, app, api TO ${READONLY_USER};
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public, app, api TO ${READONLY_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public, app, api GRANT SELECT ON TABLES TO ${READONLY_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public, app, api GRANT SELECT ON SEQUENCES TO ${READONLY_USER};

-- Application user (main app user with read/write)
CREATE USER ${APP_USER} WITH PASSWORD '${APP_PASSWORD}';
GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${APP_USER};
GRANT USAGE, CREATE ON SCHEMA app, api TO ${APP_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA app, api TO ${APP_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA app, api TO ${APP_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA app, api TO ${APP_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA app, api GRANT ALL ON TABLES TO ${APP_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA app, api GRANT ALL ON SEQUENCES TO ${APP_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA app, api GRANT ALL ON FUNCTIONS TO ${APP_USER};

-- Monitoring user (for metrics collection)
CREATE USER ${MONITOR_USER} WITH PASSWORD '${MONITOR_PASSWORD}';
GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${MONITOR_USER};
GRANT USAGE ON SCHEMA monitoring, public TO ${MONITOR_USER};
GRANT pg_monitor TO ${MONITOR_USER};
GRANT SELECT ON ALL TABLES IN SCHEMA monitoring, public TO ${MONITOR_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA monitoring GRANT SELECT ON TABLES TO ${MONITOR_USER};

\echo 'Users created successfully'

-- Create audit table for tracking changes
CREATE TABLE audit.audit_log (
    id BIGSERIAL PRIMARY KEY,
    table_schema TEXT NOT NULL,
    table_name TEXT NOT NULL,
    user_name TEXT DEFAULT current_user,
    action_type TEXT NOT NULL CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),
    row_id TEXT,
    old_data JSONB,
    new_data JSONB,
    query TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_log_table ON audit.audit_log(table_schema, table_name);
CREATE INDEX idx_audit_log_created ON audit.audit_log(created_at DESC);
CREATE INDEX idx_audit_log_user ON audit.audit_log(user_name);

-- Grant readonly user access to audit log
GRANT SELECT ON audit.audit_log TO ${READONLY_USER};

-- Create monitoring tables with TimescaleDB
CREATE TABLE monitoring.metrics (
    time TIMESTAMPTZ NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value DOUBLE PRECISION,
    labels JSONB,
    host TEXT DEFAULT '${SERVER_IP}'
);

-- Convert to hypertable
SELECT create_hypertable('monitoring.metrics', 'time', if_not_exists => TRUE);

-- Create indexes
CREATE INDEX idx_metrics_name_time ON monitoring.metrics (metric_name, time DESC);
CREATE INDEX idx_metrics_labels ON monitoring.metrics USING GIN (labels);

-- Add compression policy (compress data older than 7 days)
SELECT add_compression_policy('monitoring.metrics', INTERVAL '7 days', if_not_exists => TRUE);

-- Add retention policy (keep data for 90 days)
SELECT add_retention_policy('monitoring.metrics', INTERVAL '90 days', if_not_exists => TRUE);

-- Create sample application tables
CREATE TABLE app.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_login TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_users_email ON app.users(email);
CREATE INDEX idx_users_username ON app.users(username);
CREATE INDEX idx_users_active ON app.users(is_active) WHERE is_active = true;
CREATE INDEX idx_users_created ON app.users(created_at DESC);

-- Create sessions table
CREATE TABLE app.sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES app.users(id) ON DELETE CASCADE,
    token TEXT UNIQUE NOT NULL,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sessions_token ON app.sessions(token);
CREATE INDEX idx_sessions_user ON app.sessions(user_id);
CREATE INDEX idx_sessions_expires ON app.sessions(expires_at);

-- Create API key table for app authentication
CREATE TABLE app.api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    key_hash TEXT UNIQUE NOT NULL,
    permissions JSONB DEFAULT '[]'::jsonb,
    rate_limit INTEGER DEFAULT 1000,
    is_active BOOLEAN DEFAULT true,
    last_used TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

CREATE INDEX idx_api_keys_hash ON app.api_keys(key_hash);
CREATE INDEX idx_api_keys_active ON app.api_keys(is_active) WHERE is_active = true;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION app.trigger_set_timestamp()
RETURNS TRIGGER AS \$\$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
\$\$ LANGUAGE plpgsql;

-- Add trigger to users table
CREATE TRIGGER set_timestamp_users
    BEFORE UPDATE ON app.users
    FOR EACH ROW
    EXECUTE FUNCTION app.trigger_set_timestamp();

-- Create view for active sessions
CREATE VIEW api.active_sessions AS
SELECT 
    s.id,
    s.user_id,
    u.username,
    u.email,
    s.ip_address,
    s.created_at,
    s.expires_at
FROM app.sessions s
JOIN app.users u ON u.id = s.user_id
WHERE s.expires_at > NOW()
    AND u.is_active = true;

-- Grant permissions on views
GRANT SELECT ON api.active_sessions TO ${APP_USER};
GRANT SELECT ON api.active_sessions TO ${READONLY_USER};

-- Create helper function for password hashing
CREATE OR REPLACE FUNCTION app.hash_password(password TEXT)
RETURNS TEXT AS \$\$
BEGIN
    RETURN crypt(password, gen_salt('bf', 8));
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create helper function for password verification
CREATE OR REPLACE FUNCTION app.verify_password(password TEXT, hash TEXT)
RETURNS BOOLEAN AS \$\$
BEGIN
    RETURN hash = crypt(password, hash);
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER;

-- Sample data for testing (optional)
INSERT INTO app.users (username, email, password_hash, full_name) VALUES
    ('testuser', 'test@example.com', app.hash_password('testpass123'), 'Test User'),
    ('demouser', 'demo@example.com', app.hash_password('demopass123'), 'Demo User')
ON CONFLICT DO NOTHING;

-- Create continuous aggregate for monitoring (TimescaleDB feature)
CREATE MATERIALIZED VIEW monitoring.metrics_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS hour,
    metric_name,
    avg(metric_value) as avg_value,
    max(metric_value) as max_value,
    min(metric_value) as min_value,
    count(*) as sample_count
FROM monitoring.metrics
GROUP BY hour, metric_name
WITH NO DATA;

-- Add refresh policy for continuous aggregate
SELECT add_continuous_aggregate_policy('monitoring.metrics_hourly',
    start_offset => INTERVAL '3 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE);

-- Create database statistics view
CREATE OR REPLACE VIEW monitoring.database_stats AS
SELECT
    current_timestamp as timestamp,
    datname as database_name,
    numbackends as active_connections,
    xact_commit as transactions_committed,
    xact_rollback as transactions_rolled_back,
    blks_read as blocks_read,
    blks_hit as blocks_hit,
    round(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2) as cache_hit_ratio,
    pg_database_size(datname) as database_size_bytes,
    pg_size_pretty(pg_database_size(datname)) as database_size
FROM pg_stat_database
WHERE datname NOT IN ('template0', 'template1');

-- Grant permissions
GRANT SELECT ON monitoring.database_stats TO ${MONITOR_USER}, ${READONLY_USER};

-- Display summary
\echo ''
\echo '===================================='
\echo 'Database Initialization Complete!'
\echo '===================================='
\echo ''
\echo 'Installed Extensions:'
SELECT extname, extversion FROM pg_extension WHERE extname NOT IN ('plpgsql') ORDER BY extname;

\echo ''
\echo 'Created Users:'
SELECT usename FROM pg_user WHERE usename IN ('${POSTGRES_USER}', '${READONLY_USER}', '${APP_USER}', '${MONITOR_USER}');

\echo ''
\echo 'Created Schemas:'
SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast') ORDER BY schema_name;

\echo ''
\echo 'Database ready for connections!'
\echo 'Connection string for apps: postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}'
EOF

sudo mv /tmp/01-init-database.sql ${BASE_DIR}/init-scripts/01-init-database.sql
print_success "Database initialization script created"

# Create backup script
print_step "Creating backup script..."
cat > /tmp/backup.sh << 'EOF'
#!/bin/bash

# PostgreSQL Backup Script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")/.."
source ${SCRIPT_DIR}/.env

BACKUP_DIR="${SCRIPT_DIR}/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${SCRIPT_DIR}/logs/backup_${TIMESTAMP}.log"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a ${LOG_FILE}
}

# Start backup
log "Starting PostgreSQL backup..."

# Check if container is running
if ! docker ps | grep -q postgres16; then
    log "ERROR: PostgreSQL container is not running!"
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p ${BACKUP_DIR}
mkdir -p ${SCRIPT_DIR}/logs

# Perform full cluster backup
log "Creating full cluster backup..."
if docker exec postgres16 pg_dumpall -U ${POSTGRES_USER} | gzip > ${BACKUP_DIR}/cluster_${TIMESTAMP}.sql.gz; then
    SIZE=$(du -h ${BACKUP_DIR}/cluster_${TIMESTAMP}.sql.gz | cut -f1)
    log "✓ Full cluster backup completed: cluster_${TIMESTAMP}.sql.gz (${SIZE})"
else
    log "✗ Full cluster backup failed!"
    exit 1
fi

# Backup individual database
log "Creating individual database backup..."
if docker exec postgres16 pg_dump -U ${POSTGRES_USER} -Fc -Z9 ${POSTGRES_DB} > ${BACKUP_DIR}/${POSTGRES_DB}_${TIMESTAMP}.dump; then
    SIZE=$(du -h ${BACKUP_DIR}/${POSTGRES_DB}_${TIMESTAMP}.dump | cut -f1)
    log "✓ Database backup completed: ${POSTGRES_DB}_${TIMESTAMP}.dump (${SIZE})"
else
    log "✗ Database backup failed!"
fi

# Clean old backups (keep last 7 days)
log "Cleaning old backups..."
find ${BACKUP_DIR} -name "*.sql.gz" -mtime +7 -delete
find ${BACKUP_DIR} -name "*.dump" -mtime +7 -delete
find ${SCRIPT_DIR}/logs -name "*.log" -mtime +30 -delete

# Summary
TOTAL_SIZE=$(du -sh ${BACKUP_DIR} | cut -f1)
BACKUP_COUNT=$(ls -1 ${BACKUP_DIR}/*.{sql.gz,dump} 2>/dev/null | wc -l)

log "======================================"
log "Backup completed successfully!"
log "Total backups: ${BACKUP_COUNT}"
log "Total size: ${TOTAL_SIZE}"
log "======================================"

echo -e "${GREEN}✓ Backup completed successfully!${NC}"
EOF

sudo mv /tmp/backup.sh ${BASE_DIR}/scripts/backup.sh
sudo chmod +x ${BASE_DIR}/scripts/backup.sh
print_success "Backup script created"

# Create restore script
print_step "Creating restore script..."
cat > /tmp/restore.sh << 'EOF'
#!/bin/bash

# PostgreSQL Restore Script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")/.."
source ${SCRIPT_DIR}/.env

BACKUP_DIR="${SCRIPT_DIR}/backups"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}PostgreSQL Restore Utility${NC}"
echo "======================================"

# List available backups
echo -e "${YELLOW}Available backups:${NC}"
echo ""

# Show cluster backups
echo "Full Cluster Backups (.sql.gz):"
ls -lah ${BACKUP_DIR}/*.sql.gz 2>/dev/null | awk '{print "  " NR ". " $9 " (" $5 ")"}'

echo ""
echo "Individual Database Backups (.dump):"
ls -lah ${BACKUP_DIR}/*.dump 2>/dev/null | awk '{print "  " NR ". " $9 " (" $5 ")"}'

echo ""
echo "======================================"
echo -e "${YELLOW}Enter the full filename to restore:${NC}"
read -p "> " BACKUP_FILE

# Check if file exists
if [ ! -f "${BACKUP_DIR}/${BACKUP_FILE}" ]; then
    echo -e "${RED}Error: File not found!${NC}"
    exit 1
fi

# Confirm restoration
echo ""
echo -e "${RED}⚠️  WARNING: This will restore the database from backup!${NC}"
echo -e "${RED}   Current data may be overwritten.${NC}"
echo ""
read -p "Type 'yes' to continue: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

echo ""
echo "Starting restore process..."

# Restore based on file type
if [[ $BACKUP_FILE == *.sql.gz ]]; then
    echo "Restoring from SQL backup..."
    gunzip -c ${BACKUP_DIR}/${BACKUP_FILE} | docker exec -i postgres16 psql -U ${POSTGRES_USER}
elif [[ $BACKUP_FILE == *.dump ]]; then
    echo "Restoring from custom format backup..."
    docker exec postgres16 psql -U ${POSTGRES_USER} -c "DROP DATABASE IF EXISTS ${POSTGRES_DB};"
    docker exec postgres16 psql -U ${POSTGRES_USER} -c "CREATE DATABASE ${POSTGRES_DB};"
    docker exec -i postgres16 pg_restore -U ${POSTGRES_USER} -d ${POSTGRES_DB} --no-owner --no-privileges < ${BACKUP_DIR}/${BACKUP_FILE}
else
    echo -e "${RED}Unknown backup format!${NC}"
    exit 1
fi

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Restore completed successfully!${NC}"
else
    echo -e "${RED}✗ Restore failed! Check logs for details.${NC}"
    exit 1
fi
EOF

sudo mv /tmp/restore.sh ${BASE_DIR}/scripts/restore.sh
sudo chmod +x ${BASE_DIR}/scripts/restore.sh
print_success "Restore script created"

# Create monitoring script
print_step "Creating monitoring script..."
cat > /tmp/monitor.sh << 'EOF'
#!/bin/bash

# PostgreSQL Monitoring Dashboard
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")/.."
source ${SCRIPT_DIR}/.env

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'

# Function to execute SQL
exec_sql() {
    docker exec postgres16 psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -t -c "$1"
}

clear
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           PostgreSQL 16 Monitoring Dashboard              ║"
echo "║                  $(date '+%Y-%m-%d %H:%M:%S')                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Container Status
echo -e "${MAGENTA}▶ Container Status${NC}"
docker ps --filter name=postgres16 --format "table {{.Names}}\t{{.Status}}\t{{.Size}}" | tail -n +2
echo ""

# Database Info
echo -e "${MAGENTA}▶ Database Information${NC}"
echo "  Server: ${SERVER_IP}:5432"
echo "  Database: ${POSTGRES_DB}"
echo "  Admin User: ${POSTGRES_USER}"
UPTIME=$(exec_sql "SELECT now() - pg_postmaster_start_time() as uptime;")
echo "  Uptime: ${UPTIME}"
echo ""

# Database Sizes
echo -e "${MAGENTA}▶ Database Sizes${NC}"
exec_sql "SELECT datname as database, 
          pg_size_pretty(pg_database_size(datname)) as size 
          FROM pg_database 
          WHERE datname NOT IN ('template0', 'template1') 
          ORDER BY pg_database_size(datname) DESC;"
echo ""

# Connection Statistics
echo -e "${MAGENTA}▶ Connection Statistics${NC}"
TOTAL=$(exec_sql "SELECT count(*) FROM pg_stat_activity;")
ACTIVE=$(exec_sql "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';")
IDLE=$(exec_sql "SELECT count(*) FROM pg_stat_activity WHERE state = 'idle';")
echo "  Total Connections: ${TOTAL}"
echo "  Active: ${ACTIVE}"
echo "  Idle: ${IDLE}"
echo ""

# User Connections
echo -e "${MAGENTA}▶ Connections by User${NC}"
exec_sql "SELECT usename, count(*) as connections 
          FROM pg_stat_activity 
          GROUP BY usename 
          ORDER BY connections DESC;"
echo ""

# TimescaleDB Status
echo -e "${MAGENTA}▶ TimescaleDB Status${NC}"
TIMESCALE=$(exec_sql "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';")
if [ -n "${TIMESCALE}" ]; then
    echo -e "  ${GREEN}✓ TimescaleDB ${TIMESCALE} is active${NC}"
    HYPERTABLES=$(exec_sql "SELECT count(*) FROM timescaledb_information.hypertables;")
    echo "  Hypertables: ${HYPERTABLES}"
else
    echo -e "  ${RED}✗ TimescaleDB not installed${NC}"
fi
echo ""

# Disk Usage
echo -e "${MAGENTA}▶ Disk Usage${NC}"
df -h ${SCRIPT_DIR} | tail -n 1 | awk '{print "  Total: " $2 "  Used: " $3 " (" $5 ")  Available: " $4}'
echo ""

# Quick Commands
echo -e "${YELLOW}Quick Commands:${NC}"
echo "  Connect: docker exec -it postgres16 psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
echo "  Logs:    docker logs postgres16 --tail 50 -f"
echo "  Backup:  ${SCRIPT_DIR}/scripts/backup.sh"
echo "  Restore: ${SCRIPT_DIR}/scripts/restore.sh"
echo ""

echo -e "${CYAN}Connection Strings for Apps:${NC}"
echo "  Main:     postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}"
echo "  ReadOnly: postgresql://${READONLY_USER}:${READONLY_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}"
echo ""
EOF

sudo mv /tmp/monitor.sh ${BASE_DIR}/scripts/monitor.sh
sudo chmod +x ${BASE_DIR}/scripts/monitor.sh
print_success "Monitoring script created"

# Create credentials file
print_step "Saving credentials to file..."
cat > /tmp/CREDENTIALS.txt << EOF
════════════════════════════════════════════════════════════════
           PostgreSQL 16 + pgAdmin Stack Credentials
                    Simple App-Friendly Passwords
                    Generated: $(date)
                    Server IP: ${SERVER_IP}
════════════════════════════════════════════════════════════════

POSTGRESQL SUPER ADMIN:
─────────────────────
Username: ${POSTGRES_USER}
Password: ${POSTGRES_PASSWORD}
Database: ${POSTGRES_DB}

PGADMIN WEB INTERFACE:
─────────────────────
URL: http://${SERVER_IP}:5050
Email: ${PGADMIN_EMAIL}
Password: ${PGADMIN_PASSWORD}

DATABASE USERS FOR APPS:
───────────────────────
Read-Only User:
  Username: ${READONLY_USER}
  Password: ${READONLY_PASSWORD}
  
Application User (Read/Write):
  Username: ${APP_USER}
  Password: ${APP_PASSWORD}
  
Monitoring User:
  Username: ${MONITOR_USER}
  Password: ${MONITOR_PASSWORD}

CONNECTION STRINGS FOR YOUR APPS:
─────────────────────────────────
Main App Connection:
postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}

Read-Only Connection:
postgresql://${READONLY_USER}:${READONLY_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}

Admin Connection:
postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}

FOR YOUR APP'S .ENV FILE:
─────────────────────────
DATABASE_URL=postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}
DB_HOST=${SERVER_IP}
DB_PORT=5432
DB_NAME=${POSTGRES_DB}
DB_USER=${APP_USER}
DB_PASSWORD=${APP_PASSWORD}

FILE LOCATIONS:
──────────────
Base Directory: ${BASE_DIR}
Environment File: ${BASE_DIR}/.env
App Example: ${BASE_DIR}/app-example.env
Scripts: ${BASE_DIR}/scripts/
Backups: ${BASE_DIR}/backups/

MANAGEMENT COMMANDS:
───────────────────
Monitor:  ${BASE_DIR}/scripts/monitor.sh
Backup:   ${BASE_DIR}/scripts/backup.sh
Restore:  ${BASE_DIR}/scripts/restore.sh

════════════════════════════════════════════════════════════════
Note: All passwords are 12 characters, alphanumeric only.
      No special characters - perfect for .env files!
════════════════════════════════════════════════════════════════
EOF

sudo mv /tmp/CREDENTIALS.txt ${BASE_DIR}/CREDENTIALS.txt
sudo chmod 644 ${BASE_DIR}/CREDENTIALS.txt  # Readable for easy copying
print_success "Credentials saved to ${BASE_DIR}/CREDENTIALS.txt"

# Create README
print_step "Creating README documentation..."
cat > /tmp/README.md << EOF
# PostgreSQL 16 + pgAdmin Stack

## Overview
Production-ready PostgreSQL 16 with Supabase image, TimescaleDB, and app-friendly configuration.

**Server IP:** ${SERVER_IP}  
**Directory:** ${BASE_DIR}

## Quick Start

### 1. Deploy in Portainer
- Go to **Stacks** → **Add Stack**
- Name: \`postgres-stack\`
- Paste docker-compose.yml
- Use environment variables from \`${BASE_DIR}/.env\`
- Deploy!

### 2. Access Services
- **pgAdmin:** http://${SERVER_IP}:5050
- **PostgreSQL:** ${SERVER_IP}:5432 (internal only by default)

### 3. Connect Your Apps

Add to your app's \`.env\` file:
\`\`\`env
DATABASE_URL=postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}
\`\`\`

Or use individual variables:
\`\`\`env
DB_HOST=${SERVER_IP}
DB_PORT=5432
DB_NAME=${POSTGRES_DB}
DB_USER=${APP_USER}
DB_PASSWORD=${APP_PASSWORD}
\`\`\`

## Database Users

| User | Password | Purpose | Permissions |
|------|----------|---------|-------------|
| ${POSTGRES_USER} | ${POSTGRES_PASSWORD} | Super Admin | Full access |
| ${APP_USER} | ${APP_PASSWORD} | Application | Read/Write to app schema |
| ${READONLY_USER} | ${READONLY_PASSWORD} | Reporting | Read-only access |
| ${MONITOR_USER} | ${MONITOR_PASSWORD} | Monitoring | pg_monitor role |

## Management Scripts

- **Monitor:** \`${BASE_DIR}/scripts/monitor.sh\`
- **Backup:** \`${BASE_DIR}/scripts/backup.sh\`
- **Restore:** \`${BASE_DIR}/scripts/restore.sh\`

## Features

### Extensions Enabled
- TimescaleDB (time-series data)
- pgcrypto (encryption)
- uuid-ossp (UUID generation)  
- pgjwt (JWT tokens)
- vector (AI embeddings)
- pg_cron (scheduled jobs)
- pg_stat_statements (performance)

### Schemas
- \`public\` - Default schema
- \`app\` - Application tables
- \`api\` - API views and functions
- \`audit\` - Audit logging
- \`monitoring\` - Metrics and monitoring

### Security
- Simple 12-character alphanumeric passwords (app-friendly)
- PostgreSQL not exposed publicly by default
- Separate users with role-based permissions
- Audit logging enabled

## Example App Connections

### Node.js with pg
\`\`\`javascript
const { Pool } = require('pg')
const pool = new Pool({
  connectionString: 'postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}'
})
\`\`\`

### Python with psycopg2
\`\`\`python
import psycopg2
conn = psycopg2.connect(
    "postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}"
)
\`\`\`

### Prisma
\`\`\`env
DATABASE_URL="postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}?schema=app"
\`\`\`

## Backup & Restore

Automated daily backups at 2 AM. Manual operations:
- Backup now: \`${BASE_DIR}/scripts/backup.sh\`
- Restore: \`${BASE_DIR}/scripts/restore.sh\`

## Troubleshooting

Check container:
\`\`\`bash
docker ps | grep postgres16
docker logs postgres16 --tail 50
\`\`\`

Test connection:
\`\`\`bash
docker exec -it postgres16 psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
\`\`\`

## Support

All credentials are in: \`${BASE_DIR}/CREDENTIALS.txt\`
EOF

sudo mv /tmp/README.md ${BASE_DIR}/README.md
print_success "README documentation created"

# Set proper permissions
print_step "Setting proper permissions..."
sudo chown -R 999:999 ${BASE_DIR}/data 2>/dev/null || true
sudo chown -R 5050:5050 ${BASE_DIR}/pgadmin 2>/dev/null || true
sudo chown -R $(whoami):$(whoami) ${BASE_DIR}/backups
sudo chown -R $(whoami):$(whoami) ${BASE_DIR}/scripts
sudo chown -R $(whoami):$(whoami) ${BASE_DIR}/logs
sudo chmod 755 ${BASE_DIR}
sudo chmod 755 ${BASE_DIR}/scripts/*.sh
print_success "Permissions set"

# Create cron job for automated backups
print_step "Setting up automated backups..."
(crontab -l 2>/dev/null || true; echo "0 2 * * * ${BASE_DIR}/scripts/backup.sh >> ${BASE_DIR}/logs/backup_cron.log 2>&1") | crontab -
print_success "Daily backup cron job created (2:00 AM)"

# Display summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}                    ✓ SERVER PREPARATION COMPLETE!                 ${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}📁 Files Created at ${BASE_DIR}:${NC}"
echo "   • .env (Portainer variables)"
echo "   • app-example.env (For your apps)"
echo "   • CREDENTIALS.txt (All passwords)"
echo "   • pgadmin-servers.json"
echo "   • init-scripts/*.sql"
echo "   • scripts/*.sh"
echo ""
echo -e "${CYAN}🚀 Next Steps:${NC}"
echo "   1. Copy docker-compose.yml to Portainer"
echo "   2. Use environment variables from: ${BASE_DIR}/.env"
echo "   3. Deploy the stack"
echo "   4. Access pgAdmin at: http://${SERVER_IP}:5050"
echo ""
echo -e "${CYAN}📱 For Your Apps - Add to .env:${NC}"
echo -e "${YELLOW}DATABASE_URL=postgresql://${APP_USER}:${APP_PASSWORD}@${SERVER_IP}:5432/${POSTGRES_DB}${NC}"
echo ""
echo -e "${CYAN}📝 View All Credentials:${NC}"
echo "   cat ${BASE_DIR}/CREDENTIALS.txt"
echo ""
echo -e "${GREEN}✨ Server ready! All passwords are 12 chars, alphanumeric only.${NC}"
echo -e "${GREEN}   Perfect for .env files - no escaping needed!${NC}"
echo ""
