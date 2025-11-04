# Service Configuration

## Table of Contents

- [Overview](#overview)
- [PostgreSQL Configuration](#postgresql-configuration)
  - [Environment Variables](#postgresql-environment-variables)
  - [Configuration Files](#postgresql-configuration-files)
  - [TLS Configuration](#postgresql-tls-configuration)
  - [Performance Tuning](#postgresql-performance-tuning)
  - [Init Scripts](#postgresql-init-scripts)
- [MySQL Configuration](#mysql-configuration)
  - [Environment Variables](#mysql-environment-variables)
  - [Configuration Files](#mysql-configuration-files)
  - [TLS Configuration](#mysql-tls-configuration)
  - [Performance Tuning](#mysql-performance-tuning)
- [MongoDB Configuration](#mongodb-configuration)
  - [Environment Variables](#mongodb-environment-variables)
  - [Configuration Files](#mongodb-configuration-files)
  - [TLS Configuration](#mongodb-tls-configuration)
  - [Performance Tuning](#mongodb-performance-tuning)
- [Redis Configuration](#redis-configuration)
  - [Environment Variables](#redis-environment-variables)
  - [Configuration Files](#redis-configuration-files)
  - [TLS Configuration](#redis-tls-configuration)
  - [Cluster Configuration](#redis-cluster-configuration)
- [RabbitMQ Configuration](#rabbitmq-configuration)
  - [Environment Variables](#rabbitmq-environment-variables)
  - [Configuration Files](#rabbitmq-configuration-files)
  - [TLS Configuration](#rabbitmq-tls-configuration)
  - [Performance Tuning](#rabbitmq-performance-tuning)
- [Vault Configuration](#vault-configuration)
  - [Environment Variables](#vault-environment-variables)
  - [Configuration Files](#vault-configuration-files)
  - [Auto-Unseal Configuration](#vault-auto-unseal-configuration)
  - [Storage Backend](#vault-storage-backend)
- [Forgejo Configuration](#forgejo-configuration)
  - [Environment Variables](#forgejo-environment-variables)
  - [Configuration Files](#forgejo-configuration-files)
  - [Database Backend](#forgejo-database-backend)
  - [SSH Configuration](#forgejo-ssh-configuration)
- [Custom Configuration Examples](#custom-configuration-examples)
- [Troubleshooting](#troubleshooting)
- [Related Pages](#related-pages)

## Overview

This page documents the configuration for all services in the colima-services environment. Each service follows the Vault-first architecture pattern where credentials are stored in Vault and fetched at runtime via wrapper scripts.

**Configuration Principles:**
- No hardcoded secrets in configuration files
- Credentials fetched from Vault at startup
- Optional TLS support per service (dual-mode)
- Performance tuning via environment variables
- Custom initialization scripts in `configs/<service>/scripts/`

## PostgreSQL Configuration

### PostgreSQL Environment Variables

PostgreSQL configuration is controlled via environment variables in the `.env` file:

```bash
# Network Configuration
POSTGRES_IP=172.20.0.10
POSTGRES_PORT=5432

# TLS Configuration
POSTGRES_ENABLE_TLS=true
POSTGRES_TLS_PORT=5432  # Same port, dual-mode

# Performance Tuning
POSTGRES_MAX_CONNECTIONS=200
POSTGRES_SHARED_BUFFERS=256MB
POSTGRES_EFFECTIVE_CACHE_SIZE=1GB
POSTGRES_WORK_MEM=4MB
POSTGRES_MAINTENANCE_WORK_MEM=64MB

# Logging
POSTGRES_LOG_STATEMENT=all
POSTGRES_LOG_CONNECTIONS=on

# Database and User (created at startup)
POSTGRES_DB=devdb
POSTGRES_USER=devuser
# POSTGRES_PASSWORD loaded from Vault at runtime
```

### PostgreSQL Configuration Files

**Location:** `configs/postgres/postgresql.conf`

```conf
# Connection Settings
listen_addresses = '*'
port = 5432
max_connections = 200

# Memory Settings
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB

# WAL Settings
wal_level = replica
max_wal_size = 1GB
min_wal_size = 80MB

# Logging
log_statement = 'all'
log_connections = on
log_disconnections = on
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '

# Performance
random_page_cost = 1.1  # SSD optimized
effective_io_concurrency = 200

# TLS Settings (when enabled)
ssl = on
ssl_cert_file = '/certs/cert.pem'
ssl_key_file = '/certs/key.pem'
ssl_ca_file = '/certs/ca.pem'
```

**Location:** `configs/postgres/pg_hba.conf`

```conf
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     trust
host    all             all             172.20.0.0/16           scram-sha-256
hostssl all             all             172.20.0.0/16           scram-sha-256
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
```

### PostgreSQL TLS Configuration

Enable TLS in `.env`:

```bash
POSTGRES_ENABLE_TLS=true
```

The init script will:
1. Check for certificates in `~/.config/vault/certs/postgres/`
2. Copy certificates to `/certs/` inside container
3. Set proper permissions (600 for key.pem)
4. Configure PostgreSQL to use TLS

**Verify TLS is enabled:**

```bash
# Check SSL status
docker exec dev-postgres psql -U devuser -d devdb -c "SHOW ssl;"

# Connect with TLS
docker exec dev-postgres psql "postgresql://devuser@localhost/devdb?sslmode=require"
```

### PostgreSQL Performance Tuning

Adjust based on available resources:

```bash
# For 8GB RAM system
POSTGRES_SHARED_BUFFERS=2GB
POSTGRES_EFFECTIVE_CACHE_SIZE=6GB
POSTGRES_WORK_MEM=10MB
POSTGRES_MAINTENANCE_WORK_MEM=512MB

# For 16GB RAM system
POSTGRES_SHARED_BUFFERS=4GB
POSTGRES_EFFECTIVE_CACHE_SIZE=12GB
POSTGRES_WORK_MEM=16MB
POSTGRES_MAINTENANCE_WORK_MEM=1GB
```

See [Performance-Tuning](Performance-Tuning) for detailed optimization guide.

### PostgreSQL Init Scripts

**Location:** `configs/postgres/scripts/init.sh`

This wrapper script runs before PostgreSQL starts:

```bash
#!/bin/bash
set -e

echo "Fetching PostgreSQL credentials from Vault..."

# Wait for Vault
until curl -s http://vault:8200/v1/sys/health > /dev/null 2>&1; do
  echo "Waiting for Vault..."
  sleep 2
done

# Fetch password from Vault
VAULT_ADDR=${VAULT_ADDR:-http://vault:8200}
VAULT_TOKEN=${VAULT_TOKEN}

if [ -z "$VAULT_TOKEN" ]; then
  echo "ERROR: VAULT_TOKEN not set"
  exit 1
fi

# Get credentials
RESPONSE=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/secret/data/postgres")

export POSTGRES_PASSWORD=$(echo $RESPONSE | jq -r '.data.data.password')

# Handle TLS certificates
if [ "$POSTGRES_ENABLE_TLS" = "true" ]; then
  echo "Configuring TLS certificates..."
  mkdir -p /certs
  cp /vault-certs/postgres/* /certs/
  chmod 600 /certs/key.pem
  chown postgres:postgres /certs/*
fi

# Start PostgreSQL
exec docker-entrypoint.sh postgres
```

## MySQL Configuration

### MySQL Environment Variables

```bash
# Network Configuration
MYSQL_IP=172.20.0.12
MYSQL_PORT=3306

# TLS Configuration
MYSQL_ENABLE_TLS=true
MYSQL_TLS_PORT=3306  # Dual-mode

# Performance Tuning
MYSQL_MAX_CONNECTIONS=200
MYSQL_INNODB_BUFFER_POOL_SIZE=256M
MYSQL_INNODB_LOG_FILE_SIZE=64M

# Database and User
MYSQL_DATABASE=devdb
MYSQL_USER=devuser
# MYSQL_PASSWORD loaded from Vault
# MYSQL_ROOT_PASSWORD loaded from Vault
```

### MySQL Configuration Files

**Location:** `configs/mysql/my.cnf`

```ini
[mysqld]
# Network
bind-address = 0.0.0.0
port = 3306
max_connections = 200

# InnoDB Settings
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT

# Character Set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

# Logging
general_log = 1
general_log_file = /var/log/mysql/general.log
log_error = /var/log/mysql/error.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2

# TLS Configuration
ssl-ca = /certs/ca.pem
ssl-cert = /certs/cert.pem
ssl-key = /certs/key.pem
require_secure_transport = OFF  # Dual-mode: allow both TLS and non-TLS
```

### MySQL TLS Configuration

Enable TLS in `.env`:

```bash
MYSQL_ENABLE_TLS=true
```

**Verify TLS:**

```bash
# Check SSL status
docker exec dev-mysql mysql -u root -p -e "SHOW VARIABLES LIKE '%ssl%';"

# Connect with TLS
docker exec dev-mysql mysql -u devuser -p --ssl-mode=REQUIRED
```

### MySQL Performance Tuning

```bash
# For high-traffic applications
MYSQL_MAX_CONNECTIONS=500
MYSQL_INNODB_BUFFER_POOL_SIZE=1G
MYSQL_INNODB_LOG_FILE_SIZE=256M
MYSQL_INNODB_LOG_BUFFER_SIZE=16M
```

## MongoDB Configuration

### MongoDB Environment Variables

```bash
# Network Configuration
MONGODB_IP=172.20.0.15
MONGODB_PORT=27017

# TLS Configuration
MONGODB_ENABLE_TLS=true
MONGODB_TLS_PORT=27017

# Database and User
MONGODB_DATABASE=devdb
MONGODB_USER=devuser
# MONGODB_PASSWORD loaded from Vault
# MONGODB_ROOT_PASSWORD loaded from Vault
```

### MongoDB Configuration Files

**Location:** `configs/mongodb/mongod.conf`

```yaml
# Network Configuration
net:
  port: 27017
  bindIp: 0.0.0.0
  tls:
    mode: preferTLS  # Dual-mode
    certificateKeyFile: /certs/combined.pem
    CAFile: /certs/ca.pem

# Storage
storage:
  dbPath: /data/db
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 0.5

# Security
security:
  authorization: enabled

# System Log
systemLog:
  destination: file
  path: /var/log/mongodb/mongod.log
  logAppend: true
  verbosity: 1

# Operation Profiling
operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 100
```

### MongoDB TLS Configuration

Enable TLS in `.env`:

```bash
MONGODB_ENABLE_TLS=true
```

**Verify TLS:**

```bash
# Connect with TLS
docker exec dev-mongodb mongosh --tls \
  --tlsCAFile /certs/ca.pem \
  --tlsCertificateKeyFile /certs/combined.pem \
  -u devuser -p
```

### MongoDB Performance Tuning

```bash
# Adjust WiredTiger cache size (50-80% of available RAM)
# In mongod.conf:
storage:
  wiredTiger:
    engineConfig:
      cacheSizeGB: 2  # For 4GB RAM allocated to MongoDB
```

## Redis Configuration

### Redis Environment Variables

```bash
# Redis Node 1
REDIS_1_IP=172.20.0.13
REDIS_1_PORT=6379
REDIS_1_TLS_PORT=6380
REDIS_1_CLUSTER_BUS_PORT=16379

# Redis Node 2
REDIS_2_IP=172.20.0.16
REDIS_2_PORT=6379
REDIS_2_TLS_PORT=6380
REDIS_2_CLUSTER_BUS_PORT=16379

# Redis Node 3
REDIS_3_IP=172.20.0.17
REDIS_3_PORT=6379
REDIS_3_TLS_PORT=6380
REDIS_3_CLUSTER_BUS_PORT=16379

# TLS Configuration
REDIS_ENABLE_TLS=true

# Performance
REDIS_MAXMEMORY=256mb
REDIS_MAXMEMORY_POLICY=allkeys-lru
```

### Redis Configuration Files

**Location:** `configs/redis/redis.conf`

```conf
# Network
bind 0.0.0.0
port 6379
protected-mode no

# TLS Port (when enabled)
tls-port 6380
tls-cert-file /certs/cert.pem
tls-key-file /certs/key.pem
tls-ca-cert-file /certs/ca.pem
tls-auth-clients no  # Allow non-TLS clients (dual-mode)

# Cluster Configuration
cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 5000
cluster-require-full-coverage no

# Memory Management
maxmemory 256mb
maxmemory-policy allkeys-lru

# Persistence
save 900 1
save 300 10
save 60 10000
appendonly yes
appendfsync everysec

# Logging
loglevel notice
logfile /var/log/redis/redis.log

# Password (loaded from Vault)
requirepass PLACEHOLDER  # Replaced at runtime

# Performance
tcp-backlog 511
timeout 0
tcp-keepalive 300
```

### Redis TLS Configuration

Enable TLS in `.env`:

```bash
REDIS_ENABLE_TLS=true
```

**Connect with TLS:**

```bash
# Via TLS port
docker exec dev-redis-1 redis-cli -p 6380 --tls \
  --cert /certs/cert.pem \
  --key /certs/key.pem \
  --cacert /certs/ca.pem \
  -a $(./manage-colima.sh vault-show-password redis-1)
```

### Redis Cluster Configuration

See [Redis-Cluster](Redis-Cluster) for complete cluster setup documentation.

**Cluster Initialization Script:** `configs/redis/scripts/redis-cluster-init.sh`

```bash
#!/bin/bash
set -e

echo "Initializing Redis Cluster..."

# Wait for all nodes to be ready
for port in 6379 6379 6379; do
  until redis-cli -h redis-1 -p $port ping 2>/dev/null; do
    echo "Waiting for Redis nodes..."
    sleep 2
  done
done

# Create cluster
redis-cli --cluster create \
  172.20.0.13:6379 \
  172.20.0.16:6379 \
  172.20.0.17:6379 \
  --cluster-replicas 0 \
  --cluster-yes

echo "Redis Cluster initialized successfully"
```

## RabbitMQ Configuration

### RabbitMQ Environment Variables

```bash
# Network Configuration
RABBITMQ_IP=172.20.0.14
RABBITMQ_PORT=5672
RABBITMQ_TLS_PORT=5671
RABBITMQ_MANAGEMENT_PORT=15672

# TLS Configuration
RABBITMQ_ENABLE_TLS=true

# User Configuration
RABBITMQ_DEFAULT_USER=devuser
# RABBITMQ_DEFAULT_PASS loaded from Vault

# Virtual Host
RABBITMQ_DEFAULT_VHOST=/
```

### RabbitMQ Configuration Files

**Location:** `configs/rabbitmq/rabbitmq.conf`

```conf
# Network
listeners.tcp.default = 5672
management.tcp.port = 15672

# TLS Listeners
listeners.ssl.default = 5671
ssl_options.cacertfile = /certs/ca.pem
ssl_options.certfile = /certs/cert.pem
ssl_options.keyfile = /certs/key.pem
ssl_options.verify = verify_none
ssl_options.fail_if_no_peer_cert = false

# Management Plugin TLS
management.ssl.port = 15671
management.ssl.cacertfile = /certs/ca.pem
management.ssl.certfile = /certs/cert.pem
management.ssl.keyfile = /certs/key.pem

# Logging
log.file.level = info
log.console.level = info

# Memory and Disk
vm_memory_high_watermark.relative = 0.6
disk_free_limit.relative = 1.0

# Default User
default_user = devuser
default_vhost = /
```

**Location:** `configs/rabbitmq/enabled_plugins`

```erlang
[rabbitmq_management,rabbitmq_prometheus].
```

### RabbitMQ TLS Configuration

Enable TLS in `.env`:

```bash
RABBITMQ_ENABLE_TLS=true
```

**Access Management UI:**

```bash
# HTTP
open http://localhost:15672

# HTTPS (if TLS enabled)
open https://localhost:15671
```

### RabbitMQ Performance Tuning

```bash
# Adjust memory watermark in rabbitmq.conf
vm_memory_high_watermark.relative = 0.8  # Use 80% of available RAM

# Increase connection limits
num_acceptors.tcp = 20
num_acceptors.ssl = 10
```

## Vault Configuration

### Vault Environment Variables

```bash
# Network Configuration
VAULT_IP=172.20.0.21
VAULT_PORT=8200

# Storage
VAULT_STORAGE_PATH=/vault/data

# TLS (Vault uses HTTP in dev mode)
VAULT_TLS_DISABLE=1

# Auto-unseal
VAULT_KEYS_FILE=/vault-keys/keys.json
```

### Vault Configuration Files

**Location:** `configs/vault/config.hcl`

```hcl
storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1  # Development mode
}

ui = true

api_addr = "http://172.20.0.21:8200"
cluster_addr = "http://172.20.0.21:8201"

disable_mlock = true  # Required for containers

log_level = "info"
```

### Vault Auto-Unseal Configuration

**Location:** `configs/vault/scripts/vault-auto-unseal.sh`

This script runs at Vault startup to automatically initialize and unseal:

```bash
#!/bin/bash
set -e

export VAULT_ADDR=http://127.0.0.1:8200
KEYS_FILE=/vault-keys/keys.json

# Start Vault server in background
vault server -config=/vault/config/config.hcl &
VAULT_PID=$!

# Wait for Vault to start
sleep 5

# Check if Vault is initialized
if ! vault status 2>/dev/null | grep -q "Initialized.*true"; then
  echo "Initializing Vault..."
  vault operator init -key-shares=5 -key-threshold=3 -format=json > $KEYS_FILE
  chmod 600 $KEYS_FILE
fi

# Unseal Vault
if vault status 2>/dev/null | grep -q "Sealed.*true"; then
  echo "Unsealing Vault..."
  for i in 0 1 2; do
    UNSEAL_KEY=$(jq -r ".unseal_keys_b64[$i]" < $KEYS_FILE)
    vault operator unseal $UNSEAL_KEY
  done
fi

# Keep Vault running
wait $VAULT_PID
```

### Vault Storage Backend

Vault uses file-based storage in development. For production, consider:

```hcl
# Consul backend (recommended for HA)
storage "consul" {
  address = "consul:8500"
  path    = "vault/"
}

# PostgreSQL backend
storage "postgresql" {
  connection_url = "postgres://vault:password@postgres:5432/vault?sslmode=disable"
}

# Raft integrated storage (recommended for Vault 1.4+)
storage "raft" {
  path    = "/vault/data"
  node_id = "vault-1"
}
```

## Forgejo Configuration

### Forgejo Environment Variables

```bash
# Network Configuration
FORGEJO_IP=172.20.0.20
FORGEJO_HTTP_PORT=3000
FORGEJO_SSH_PORT=2222

# Database Configuration
FORGEJO_DB_TYPE=postgres
FORGEJO_DB_HOST=postgres:5432
FORGEJO_DB_NAME=forgejo
FORGEJO_DB_USER=forgejo
# FORGEJO_DB_PASSWD loaded from Vault

# Application Settings
FORGEJO_APP_NAME="Colima Dev Git"
FORGEJO_RUN_MODE=prod
FORGEJO_DOMAIN=localhost
FORGEJO_ROOT_URL=http://localhost:3000
```

### Forgejo Configuration Files

**Location:** `configs/forgejo/app.ini` (generated on first run)

```ini
[server]
APP_DATA_PATH = /data/forgejo
DOMAIN = localhost
HTTP_PORT = 3000
ROOT_URL = http://localhost:3000/
SSH_DOMAIN = localhost
SSH_PORT = 2222
START_SSH_SERVER = true
LFS_START_SERVER = true

[database]
DB_TYPE = postgres
HOST = postgres:5432
NAME = forgejo
USER = forgejo
SCHEMA = public
SSL_MODE = disable

[security]
INSTALL_LOCK = true
SECRET_KEY = <generated-at-first-run>
INTERNAL_TOKEN = <generated-at-first-run>

[service]
DISABLE_REGISTRATION = false
REQUIRE_SIGNIN_VIEW = false
ENABLE_CAPTCHA = false

[log]
MODE = console
LEVEL = Info

[repository]
ROOT = /data/git/repositories
DEFAULT_BRANCH = main

[mailer]
ENABLED = false
```

### Forgejo Database Backend

Forgejo uses PostgreSQL from the colima-services stack:

```bash
# Create Forgejo database (automated via init script)
docker exec dev-postgres psql -U postgres -c "CREATE DATABASE forgejo;"
docker exec dev-postgres psql -U postgres -c "CREATE USER forgejo WITH PASSWORD 'vault-fetched-password';"
docker exec dev-postgres psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE forgejo TO forgejo;"
```

### Forgejo SSH Configuration

SSH access is on port 2222:

```bash
# Clone via SSH
git clone ssh://git@localhost:2222/username/repo.git

# Add remote
git remote add origin ssh://git@localhost:2222/username/repo.git

# Configure SSH
# Add to ~/.ssh/config:
Host localhost
  Port 2222
  User git
  IdentityFile ~/.ssh/id_ed25519
```

## Custom Configuration Examples

### Example: Custom PostgreSQL Extensions

Create custom initialization SQL:

**Location:** `configs/postgres/scripts/init.sql`

```sql
-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "hstore";

-- Create custom schema
CREATE SCHEMA IF NOT EXISTS app;

-- Create custom tables
CREATE TABLE IF NOT EXISTS app.users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  username VARCHAR(255) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Grant permissions
GRANT ALL PRIVILEGES ON SCHEMA app TO devuser;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA app TO devuser;
```

Mount in docker-compose.yml:

```yaml
services:
  postgres:
    volumes:
      - ./configs/postgres/scripts/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
```

### Example: Custom Redis Eviction Policy

Modify `configs/redis/redis.conf`:

```conf
# Use LFU (Least Frequently Used) instead of LRU
maxmemory-policy allkeys-lfu

# Tune LFU parameters
lfu-log-factor 10
lfu-decay-time 1
```

### Example: Custom RabbitMQ Policies

Create policy configuration file:

**Location:** `configs/rabbitmq/definitions.json`

```json
{
  "policies": [
    {
      "vhost": "/",
      "name": "ha-all",
      "pattern": ".*",
      "definition": {
        "ha-mode": "all",
        "ha-sync-mode": "automatic"
      }
    }
  ],
  "queues": [
    {
      "name": "tasks",
      "vhost": "/",
      "durable": true,
      "auto_delete": false,
      "arguments": {
        "x-message-ttl": 86400000,
        "x-max-length": 10000
      }
    }
  ]
}
```

Load via management API:

```bash
curl -u devuser:password -X POST \
  -H "Content-Type: application/json" \
  -d @configs/rabbitmq/definitions.json \
  http://localhost:15672/api/definitions
```

### Example: Custom Vault Secret Paths

Organize secrets by environment:

```bash
# Development secrets
vault kv put secret/dev/postgres password=dev123
vault kv put secret/dev/mysql password=dev456

# Staging secrets
vault kv put secret/staging/postgres password=staging123

# Production secrets
vault kv put secret/prod/postgres password=prod123

# Update init scripts to read from environment-specific path
SECRET_PATH="secret/${ENV:-dev}/postgres"
```

## Troubleshooting

### Service Won't Start

```bash
# Check Vault connectivity
docker exec <service> curl -v http://vault:8200/v1/sys/health

# Check if credentials exist in Vault
./manage-colima.sh vault-show-password <service>

# Check init script logs
docker logs <service> 2>&1 | grep -i vault
```

### Configuration Not Applied

```bash
# Restart service to reload config
docker compose restart <service>

# Force recreation
docker compose up -d --force-recreate <service>

# Check mounted config files
docker exec <service> cat /path/to/config
```

### TLS Not Working

```bash
# Verify certificates exist
ls -la ~/.config/vault/certs/<service>/

# Check certificate validity
openssl x509 -in ~/.config/vault/certs/<service>/cert.pem -text -noout

# Regenerate certificates
./scripts/generate-certificates.sh
docker compose restart <service>
```

### Password Mismatch

```bash
# Verify Vault has correct password
vault kv get secret/<service>

# Update password in Vault
vault kv put secret/<service> password=newpassword

# Restart service to fetch new password
docker compose restart <service>
```

## Related Pages

- [Environment-Variables](Environment-Variables) - Complete .env reference
- [TLS-Configuration](TLS-Configuration) - TLS setup guide
- [Performance-Tuning](Performance-Tuning) - Optimization guide
- [Vault-Troubleshooting](Vault-Troubleshooting) - Vault-specific issues
- [Docker-Compose-Reference](Docker-Compose-Reference) - Service definitions
- [Health-Monitoring](Health-Monitoring) - Health check configuration
- [Redis-Cluster](Redis-Cluster) - Redis cluster setup
- [CLI-Reference](CLI-Reference) - Management script commands
