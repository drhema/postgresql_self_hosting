#!/bin/bash

#################################################
# PostgreSQL 16 + TimescaleDB + pgAdmin 4 Setup
# Self-Hosted Stack for Portainer Deployment
# Author: Database Stack Automation
# Version: 1.0.0
#################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Function to generate secure 12-character alphanumeric passwords
generate_password() {
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12
}

# Function to detect server IP
detect_server_ip() {
    local ip=""
    
    # Try to get public IP
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

# Default base directory
BASE_DIR="/srv/postgres16"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dir)
            BASE_DIR="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [--dir BASE_DIRECTORY]"
            echo "  --dir: Specify custom base directory (default: /srv/postgres16)"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_info "========================================="
print_info "PostgreSQL 16 + TimescaleDB + pgAdmin 4"
print_info "Self-Hosted Stack Setup"
print_info "========================================="

# Detect server IP
SERVER_IP=$(detect_server_ip)
print_info "Detected Server IP: $SERVER_IP"
print_info "Base Directory: $BASE_DIR"

# Create directory structure
print_info "Creating directory structure..."
sudo mkdir -p "$BASE_DIR"/{data,pgadmin,backups,scripts,logs,config}

# Set proper ownership (UID 999 for postgres, 5050 for pgadmin)
sudo chown -R 999:999 "$BASE_DIR/data"
sudo chown -R 5050:5050 "$BASE_DIR/pgadmin"
sudo chown -R 999:999 "$BASE_DIR/backups"
sudo chown -R 999:999 "$BASE_DIR/logs"

# Generate secure passwords
print_info "Generating secure passwords..."
POSTGRES_PASSWORD=$(generate_password)
PGADMIN_PASSWORD=$(generate_password)
APP_USER_PASSWORD=$(generate_password)
READONLY_PASSWORD=$(generate_password)
BACKUP_PASSWORD=$(generate_password)
ANALYTICS_PASSWORD=$(generate_password)

# Create .env file
print_info "Creating .env file..."
cat > "$BASE_DIR/.env" << EOF
# PostgreSQL Configuration
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=postgres

# pgAdmin Configuration
PGADMIN_DEFAULT_EMAIL=admin@${SERVER_IP//./-}.local
PGADMIN_DEFAULT_PASSWORD=$PGADMIN_PASSWORD
PGADMIN_CONFIG_SERVER_MODE=True
PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED=True

# Database Users Passwords
APP_USER_PASSWORD=$APP_USER_PASSWORD
READONLY_PASSWORD=$READONLY_PASSWORD
BACKUP_PASSWORD=$BACKUP_PASSWORD
ANALYTICS_PASSWORD=$ANALYTICS_PASSWORD

# Server Configuration
SERVER_IP=$SERVER_IP
SERVER_PORT=5432
PGADMIN_PORT=5050

# TimescaleDB Configuration
TIMESCALEDB_TELEMETRY=off

# Security Settings
POSTGRES_HOST_AUTH_METHOD=scram-sha-256
POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256 --auth-local=scram-sha-256
EOF

# Secure the .env file
sudo chmod 600 "$BASE_DIR/.env"

# Create PostgreSQL configuration
print_info "Creating PostgreSQL configuration..."
cat > "$BASE_DIR/config/postgresql.conf" << 'EOF'
# Connection settings
listen_addresses = '*'
max_connections = 200
superuser_reserved_connections = 3

# Memory settings
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
work_mem = 4MB

# Write ahead log
wal_level = replica
max_wal_size = 1GB
min_wal_size = 80MB

# Query tuning
random_page_cost = 1.1
effective_io_concurrency = 200

# Logging
logging_collector = on
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_connections = on
log_disconnections = on
log_duration = off
log_error_verbosity = default
log_hostname = on
log_lock_waits = on
log_statement = 'ddl'
log_temp_files = 0
log_timezone = 'UTC'

# Security
ssl = off  # Internal network only
password_encryption = scram-sha-256

# TimescaleDB
shared_preload_libraries = 'timescaledb'
timescaledb.telemetry_level = off
EOF

# Create pg_hba.conf for security
print_info "Creating pg_hba.conf..."
cat > "$BASE_DIR/config/pg_hba.conf" << 'EOF'
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections
local   all             all                                     scram-sha-256

# IPv4 local connections (Docker network)
host    all             all             172.16.0.0/12           scram-sha-256
host    all             all             10.0.0.0/8              scram-sha-256
host    all             all             192.168.0.0/16          scram-sha-256

# Reject all other connections
host    all             all             0.0.0.0/0               reject
EOF

# Create initialization SQL script
print_info "Creating database initialization script..."
cat > "$BASE_DIR/scripts/init.sql" << EOF
-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- Create application database
CREATE DATABASE app_db;

-- Create roles
CREATE ROLE app_user WITH LOGIN PASSWORD '${APP_USER_PASSWORD}';
CREATE ROLE readonly_user WITH LOGIN PASSWORD '${READONLY_PASSWORD}';
CREATE ROLE backup_user WITH LOGIN PASSWORD '${BACKUP_PASSWORD}';
CREATE ROLE analytics_user WITH LOGIN PASSWORD '${ANALYTICS_PASSWORD}';

-- Grant privileges to app_user
GRANT CONNECT ON DATABASE app_db TO app_user;
GRANT CREATE ON DATABASE app_db TO app_user;
ALTER DATABASE app_db OWNER TO app_user;

-- Grant read-only access
GRANT CONNECT ON DATABASE app_db TO readonly_user;
\c app_db
GRANT USAGE ON SCHEMA public TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly_user;

-- Grant backup privileges
GRANT CONNECT ON DATABASE app_db TO backup_user;
GRANT CONNECT ON DATABASE postgres TO backup_user;
\c postgres
GRANT pg_read_all_data TO backup_user;

-- Grant analytics privileges
GRANT CONNECT ON DATABASE app_db TO analytics_user;
\c app_db
GRANT USAGE ON SCHEMA public TO analytics_user;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO analytics_user;
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

-- Enable row level security on audit table
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- Create policy for audit table
CREATE POLICY audit_log_policy ON audit_log
    FOR ALL
    TO postgres
    USING (true);
EOF

# Create docker-compose.yml
print_info "Creating docker-compose.yml..."
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
      - $BASE_DIR/data:/var/lib/postgresql/data
      - $BASE_DIR/backups:/backups
      - $BASE_DIR/logs:/var/log/postgresql
      - $BASE_DIR/scripts/init.sql:/docker-entrypoint-initdb.d/10-init.sql:ro
      - $BASE_DIR/config/postgresql.conf:/etc/postgresql/postgresql.conf:ro
      - $BASE_DIR/config/pg_hba.conf:/etc/postgresql/pg_hba.conf:ro
    command: 
      - postgres
      - -c
      - config_file=/etc/postgresql/postgresql.conf
      - -c
      - hba_file=/etc/postgresql/pg_hba.conf
    networks:
      - postgres_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER} -d \${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
    # PostgreSQL is NOT exposed to the internet for security
    # Only accessible within Docker network

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
      - PGADMIN_CONFIG_CONSOLE_LOG_LEVEL=10
    volumes:
      - $BASE_DIR/pgadmin:/var/lib/pgadmin
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

# Create backup
docker exec postgres16 pg_dumpall -U $POSTGRES_USER > $BACKUP_FILE

# Compress backup
gzip $BACKUP_FILE

# Remove backups older than 30 days
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +30 -delete

echo "Backup completed: ${BACKUP_FILE}.gz"
EOF

chmod +x "$BASE_DIR/scripts/backup.sh"

# Create pgAdmin servers.json configuration
print_info "Creating pgAdmin server configuration..."
mkdir -p "$BASE_DIR/pgadmin"
cat > "$BASE_DIR/pgadmin/servers.json" << EOF
{
    "Servers": {
        "1": {
            "Name": "PostgreSQL 16 - TimescaleDB",
            "Group": "Servers",
            "Host": "postgres",
            "Port": 5432,
            "MaintenanceDB": "postgres",
            "Username": "postgres",
            "SSLMode": "prefer",
            "Comment": "Local PostgreSQL 16 with TimescaleDB"
        }
    }
}
EOF

# Set proper permissions
sudo chmod 600 "$BASE_DIR/pgadmin/servers.json"
sudo chown 5050:5050 "$BASE_DIR/pgadmin/servers.json"

# Create cron job for automated backups
print_info "Setting up automated backups..."
(crontab -l 2>/dev/null; echo "0 2 * * * $BASE_DIR/scripts/backup.sh") | crontab -

print_success "========================================="
print_success "Setup completed successfully!"
print_success "========================================="
echo ""
print_info "📁 Installation Directory: $BASE_DIR"
print_info "🌐 Server IP: $SERVER_IP"
echo ""
print_success "🔐 Access Credentials:"
echo "  PostgreSQL:"
echo "    Host: postgres (internal only)"
echo "    Port: 5432 (not exposed externally)"
echo "    Admin User: postgres"
echo "    Admin Password: $POSTGRES_PASSWORD"
echo ""
echo "  pgAdmin:"
echo "    URL: http://$SERVER_IP:5050"
echo "    Email: admin@${SERVER_IP//./-}.local"
echo "    Password: $PGADMIN_PASSWORD"
echo ""
echo "  Database Users:"
echo "    app_user: $APP_USER_PASSWORD (Full access to app_db)"
echo "    readonly_user: $READONLY_PASSWORD (Read-only access)"
echo "    backup_user: $BACKUP_PASSWORD (Backup privileges)"
echo "    analytics_user: $ANALYTICS_PASSWORD (Analytics access)"
echo ""
print_info "📝 Next Steps:"
echo "  1. Copy the docker-compose.yml to Portainer"
echo "  2. Copy the .env file content to Portainer environment"
echo "  3. Deploy the stack"
echo "  4. Access pgAdmin at http://$SERVER_IP:5050"
echo ""
print_warning "⚠️  Security Notes:"
echo "  - PostgreSQL is NOT exposed to the internet"
echo "  - All passwords are stored in $BASE_DIR/.env"
echo "  - Backup this file securely!"
echo "  - Automated backups run daily at 2 AM"
echo ""
print_success "Stack files created at: $BASE_DIR"
