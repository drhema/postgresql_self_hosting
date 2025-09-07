# PostgreSQL IP Whitelisting Security Configuration

## 🔒 Method 1: Firewall Rules (Recommended - Most Secure)

### UFW Firewall Configuration

```bash
# 1. First, enable UFW if not already enabled
sudo ufw enable

# 2. Allow PostgreSQL only from specific IPs
# Replace with your actual IP addresses

# Allow from your office/home IP
sudo ufw allow from 192.168.1.100 to any port 5432

# Allow from another trusted server
sudo ufw allow from 203.0.113.45 to any port 5432

# Allow from localhost (the server itself)
sudo ufw allow from 127.0.0.1 to any port 5432

# Allow from Docker network (for pgAdmin to connect)
sudo ufw allow from 172.28.0.0/16 to any port 5432

# 3. Deny all other connections to PostgreSQL
sudo ufw deny 5432

# 4. Verify rules
sudo ufw status numbered
```

### Remove an IP from whitelist:
```bash
# List rules with numbers
sudo ufw status numbered

# Delete rule by number
sudo ufw delete [RULE_NUMBER]
```

---

## 🔒 Method 2: PostgreSQL pg_hba.conf Configuration

### Create Custom pg_hba.conf

1. **Create the configuration file:**

```bash
# Create config directory if it doesn't exist
sudo mkdir -p /srv/postgres16/config

# Create pg_hba.conf
sudo nano /srv/postgres16/config/pg_hba.conf
```

2. **Add this content (replace with your IPs):**

```conf
# PostgreSQL Client Authentication Configuration
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections (from the server itself)
local   all             all                                     scram-sha-256
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256

# Docker network (for pgAdmin)
host    all             all             172.28.0.0/16           scram-sha-256

# Specific IP whitelist (add your IPs here)
host    all             all             192.168.1.100/32        scram-sha-256   # Office IP
host    all             all             203.0.113.45/32         scram-sha-256   # Trusted server
host    all             all             10.0.0.5/32             scram-sha-256   # VPN IP

# Reject all others
host    all             all             0.0.0.0/0               reject
host    all             all             ::/0                    reject
```

3. **Update Docker Compose to use custom pg_hba.conf:**

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
      - /srv/postgres16/config/pg_hba.conf:/var/lib/postgresql/data/pg_hba.conf:ro  # Add this line
    ports:
      - "5432:5432"
    command: 
      - postgres
      - -c
      - hba_file=/var/lib/postgresql/data/pg_hba.conf  # Add this
    networks:
      - postgres_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  # pgadmin configuration remains the same...
```

---

## 🔒 Method 3: Docker Network + IPTables (Advanced)

### Configure IPTables rules:

```bash
# Create IP whitelist script
sudo nano /srv/postgres16/scripts/configure-iptables.sh
```

```bash
#!/bin/bash

# PostgreSQL IP Whitelist Configuration
# Add your allowed IPs here
ALLOWED_IPS=(
    "192.168.1.100"   # Office
    "203.0.113.45"    # Trusted server
    "10.0.0.5"        # VPN
)

# Allow localhost
iptables -A INPUT -p tcp --dport 5432 -s 127.0.0.1 -j ACCEPT

# Allow Docker network
iptables -A INPUT -p tcp --dport 5432 -s 172.28.0.0/16 -j ACCEPT

# Allow specific IPs
for ip in "${ALLOWED_IPS[@]}"; do
    echo "Allowing PostgreSQL access from: $ip"
    iptables -A INPUT -p tcp --dport 5432 -s "$ip" -j ACCEPT
done

# Drop all other connections to PostgreSQL
iptables -A INPUT -p tcp --dport 5432 -j DROP

echo "IPTables rules configured. PostgreSQL restricted to whitelisted IPs only."
```

```bash
# Make executable and run
sudo chmod +x /srv/postgres16/scripts/configure-iptables.sh
sudo /srv/postgres16/scripts/configure-iptables.sh
```

---

## 🔒 Method 4: Environment Variable Configuration (Simplest)

### Update .env file with allowed IPs:

```env
# Add to your .env file
POSTGRES_USER=postgres
POSTGRES_PASSWORD=njjXmoi7i5HX
POSTGRES_DB=postgres

# Security - IP Whitelist (comma-separated)
ALLOWED_IPS=192.168.1.100,203.0.113.45,10.0.0.5
POSTGRES_LISTEN_ADDRESSES=localhost,192.168.1.100,203.0.113.45,10.0.0.5

# pgAdmin configuration...
```

### Create initialization script:

```bash
sudo nano /srv/postgres16/init/02-configure-access.sh
```

```bash
#!/bin/bash
# This script runs on container startup

# Parse allowed IPs from environment
IFS=',' read -ra IPS <<< "$ALLOWED_IPS"

# Update pg_hba.conf dynamically
PG_HBA="/var/lib/postgresql/data/pg_hba.conf"

# Keep default local access
echo "local   all   all                    scram-sha-256" > $PG_HBA
echo "host    all   all   127.0.0.1/32     scram-sha-256" >> $PG_HBA
echo "host    all   all   172.28.0.0/16    scram-sha-256" >> $PG_HBA

# Add each allowed IP
for ip in "${IPS[@]}"; do
    echo "host    all   all   ${ip}/32    scram-sha-256" >> $PG_HBA
done

# Reject all others
echo "host    all   all   0.0.0.0/0    reject" >> $PG_HBA

# Reload PostgreSQL configuration
pg_ctl reload
```

---

## 🎯 Quick Implementation Guide

### For immediate security, use Method 1 (UFW):

```bash
# Allow your IPs (replace with actual IPs)
sudo ufw allow from YOUR_IP_1 to any port 5432
sudo ufw allow from YOUR_IP_2 to any port 5432
sudo ufw allow from 172.28.0.0/16 to any port 5432  # Docker network
sudo ufw deny 5432  # Block all others

# Check status
sudo ufw status
```

### Test connection from allowed IP:
```bash
# From allowed IP
psql -h 20.64.251.75 -U postgres -d postgres

# From non-allowed IP (should fail)
psql -h 20.64.251.75 -U postgres -d postgres
# Error: connection refused
```

---

## 📋 Complete Secure Configuration Example

### If your allowed IPs are:
- Server itself: 127.0.0.1, 20.64.251.75
- Office: 192.168.1.100
- Home: 86.45.123.67
- Another server: 157.230.45.89

### Run these commands:

```bash
# 1. Configure firewall
sudo ufw allow from 127.0.0.1 to any port 5432
sudo ufw allow from 192.168.1.100 to any port 5432
sudo ufw allow from 86.45.123.67 to any port 5432
sudo ufw allow from 157.230.45.89 to any port 5432
sudo ufw allow from 172.28.0.0/16 to any port 5432  # Docker
sudo ufw deny 5432

# 2. Verify
sudo ufw status numbered

# 3. Test from each IP
# Should work from allowed IPs
# Should fail from any other IP
```

---

## 🔍 Monitoring & Logging

### Check who's connecting:

```bash
# View current connections
docker exec postgres16 psql -U postgres -c "SELECT client_addr, usename, application_name, state FROM pg_stat_activity WHERE client_addr IS NOT NULL;"

# Check PostgreSQL logs for connection attempts
docker logs postgres16 --tail 50 | grep connection

# Monitor failed connection attempts
sudo tail -f /var/log/ufw.log | grep DPT=5432
```

### Create connection audit table:

```sql
-- Run in PostgreSQL
CREATE TABLE connection_audit (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    client_ip INET,
    username TEXT,
    database TEXT,
    success BOOLEAN,
    error_message TEXT
);

-- Create function to log connections
CREATE OR REPLACE FUNCTION log_connection() RETURNS event_trigger AS $$
BEGIN
    INSERT INTO connection_audit (client_ip, username, database, success)
    VALUES (inet_client_addr(), current_user, current_database(), true);
END;
$$ LANGUAGE plpgsql;
```

---

## ⚠️ Important Notes

1. **Always include Docker network** (172.28.0.0/16) or pgAdmin won't connect
2. **Test thoroughly** after implementing - use wrong IPs to verify blocking works
3. **Keep a backup access method** (like SSH) in case you lock yourself out
4. **Document your whitelist** - maintain a list of allowed IPs and their purpose
5. **Regular audits** - Review access logs monthly

---

## 🚨 Emergency Access Recovery

If you accidentally lock yourself out:

```bash
# Via SSH to the server
# Temporarily disable firewall
sudo ufw disable

# Or remove PostgreSQL rule
sudo ufw delete deny 5432

# Fix configuration
# Then re-enable security
```
