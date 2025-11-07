# CLI Reference

## Table of Contents

- [Overview](#overview)
- [Start Command](#start-command)
- [Stop Command](#stop-command)
- [Restart Command](#restart-command)
- [Status Command](#status-command)
- [Health Command](#health-command)
- [Logs Command](#logs-command)
- [Shell Command](#shell-command)
- [Vault Commands](#vault-commands)
  - [vault-init](#vault-init)
  - [vault-bootstrap](#vault-bootstrap)
  - [vault-status](#vault-status)
  - [vault-unseal](#vault-unseal)
  - [vault-token](#vault-token)
  - [vault-show-password](#vault-show-password)
- [Backup Command](#backup-command)
- [Reset Command](#reset-command)
- [Related Pages](#related-pages)

## Overview

The `manage-devstack.sh` script is the primary interface for managing the devstack-core environment. This page documents all available commands and their usage.

**Script Location:** `/Users/gator/devstack-core/manage-devstack.sh`

**Basic Usage:**
```bash
./manage-devstack.sh <command> [arguments]
```

## Start Command

**Start the entire environment (Colima VM + all services)**

```bash
./manage-devstack.sh start
```

**What it does:**
1. Checks if Colima is running
2. Starts Colima VM if not running
3. Starts all Docker containers via docker-compose
4. Waits for Vault to become healthy
5. Allows dependent services to start

**Options:**
```bash
# Start with custom Colima configuration
COLIMA_CPU=8 COLIMA_MEM=16 COLIMA_DISK=100 ./manage-devstack.sh start

# Start specific services only
docker compose up -d vault postgres redis-1
```

**Output:**
```
Starting Colima VM...
✓ Colima started successfully

Starting services...
[+] Running 15/15
 ✔ Container dev-vault           Started
 ✔ Container dev-postgres        Started
 ✔ Container dev-mysql           Started
 ✔ Container dev-mongodb         Started
 ✔ Container dev-redis-1         Started
 ✔ Container dev-redis-2         Started
 ✔ Container dev-redis-3         Started
 ✔ Container dev-rabbitmq        Started
 ✔ Container dev-forgejo         Started
 ✔ Container dev-reference-api   Started

All services started successfully!
```

## Stop Command

**Stop all services and the Colima VM**

```bash
./manage-devstack.sh stop
```

**What it does:**
1. Stops all Docker containers
2. Stops Colima VM
3. Preserves data volumes

**Options:**
```bash
# Stop services but keep Colima running
docker compose down

# Stop specific services
docker compose stop postgres mysql
```

**Output:**
```
Stopping services...
[+] Running 15/15
 ✔ Container dev-reference-api   Stopped
 ✔ Container dev-forgejo         Stopped
 ✔ Container dev-rabbitmq        Stopped
 ✔ Container dev-redis-3         Stopped
 ✔ Container dev-redis-2         Stopped
 ✔ Container dev-redis-1         Stopped
 ✔ Container dev-mongodb         Stopped
 ✔ Container dev-mysql           Stopped
 ✔ Container dev-postgres        Stopped
 ✔ Container dev-vault           Stopped

Stopping Colima VM...
✓ Colima stopped successfully
```

## Restart Command

**Restart all services (Colima VM stays running)**

```bash
./manage-devstack.sh restart
```

**What it does:**
1. Stops all Docker containers
2. Starts all Docker containers
3. Colima VM remains running

**Use when:**
- Configuration changes require restart
- Services become unresponsive
- After updating docker-compose.yml

**Options:**
```bash
# Restart specific service
docker compose restart postgres

# Restart with recreate (rebuild containers)
docker compose up -d --force-recreate
```

## Status Command

**Display VM and service status with resource usage**

```bash
./manage-devstack.sh status
```

**Output:**
```
=== Colima VM Status ===
Profile: default
Runtime: docker
CPU: 8
Memory: 16GB
Disk: 100GB
Status: Running

=== Service Status ===
NAME                CPU %    MEM USAGE / LIMIT     MEM %    NET I/O           BLOCK I/O
dev-vault           0.50%    45.2MB / 256MB        17.66%   1.2MB / 850KB     0B / 4.1MB
dev-postgres        2.30%    156MB / 2GB           7.80%    5.4MB / 3.2MB     12MB / 45MB
dev-mysql           1.80%    245MB / 1GB           24.50%   3.1MB / 2.8MB     8MB / 32MB
dev-mongodb         1.20%    180MB / 1GB           18.00%   2.5MB / 1.9MB     6MB / 28MB
dev-redis-1         0.40%    12.3MB / 512MB        2.40%    850KB / 620KB     0B / 1.2MB
dev-redis-2         0.35%    11.8MB / 512MB        2.30%    780KB / 580KB     0B / 1.1MB
dev-redis-3         0.38%    12.1MB / 512MB        2.36%    820KB / 600KB     0B / 1.1MB
dev-rabbitmq        1.50%    95MB / 512MB          18.55%   1.8MB / 1.5MB     2MB / 8MB
dev-reference-api   0.80%    78MB / 1GB            7.80%    2.5MB / 1.8MB     0B / 512KB
```

**Useful for:**
- Checking resource usage
- Identifying performance issues
- Capacity planning

## Health Command

**Check health of all services**

```bash
./manage-devstack.sh health
```

**Output:**
```
=== DevStack Core Health Check ===

Core Services:
Vault:          ✓ healthy (unsealed)
PostgreSQL:     ✓ healthy
MySQL:          ✓ healthy
MongoDB:        ✓ healthy
Redis-1:        ✓ healthy
Redis-2:        ✓ healthy
Redis-3:        ✓ healthy
Redis Cluster:  ✓ healthy (3 masters, all slots assigned)
RabbitMQ:       ✓ healthy
Forgejo:        ✓ healthy

Observability:
Prometheus:     ✓ healthy
Grafana:        ✓ healthy
Loki:           ✓ healthy

Reference Apps:
FastAPI:        ✓ healthy
Go API:         ✓ healthy
Node.js API:    ✓ healthy
Rust API:       ✓ healthy

Overall Status: ALL SERVICES HEALTHY ✓
```

**Exit codes:**
- 0: All services healthy
- 1: One or more services unhealthy

## Logs Command

**View logs for all or specific services**

```bash
# All services
./manage-devstack.sh logs

# Specific service
./manage-devstack.sh logs postgres

# Follow logs (tail -f)
./manage-devstack.sh logs vault -f

# Last N lines
./manage-devstack.sh logs redis-1 --tail=100
```

**Examples:**
```bash
# View Vault logs
./manage-devstack.sh logs vault

# Follow PostgreSQL logs
./manage-devstack.sh logs postgres -f

# View last 50 lines from MySQL
./manage-devstack.sh logs mysql --tail=50

# Multiple services
docker compose logs postgres mysql redis-1
```

## Shell Command

**Open an interactive shell in a container**

```bash
./manage-devstack.sh shell <service>
```

**Examples:**
```bash
# Shell into PostgreSQL container
./manage-devstack.sh shell postgres

# Shell into Vault container
./manage-devstack.sh shell vault

# Shell into Redis node
./manage-devstack.sh shell redis-1
```

**Inside container:**
```bash
# PostgreSQL container
$ psql -U postgres
$ pg_isready
$ ps aux

# Vault container
$ vault status
$ env | grep VAULT

# Redis container
$ redis-cli
$ redis-cli CLUSTER INFO
```

## Vault Commands

### vault-init

**Initialize Vault (first-time setup only)**

```bash
./manage-devstack.sh vault-init
```

**What it does:**
1. Initializes Vault with 5 keys, threshold 3
2. Saves keys to `~/.config/vault/keys.json`
3. Saves root token to `~/.config/vault/root-token`
4. Unseals Vault automatically

**Output:**
```
Initializing Vault...
✓ Vault initialized successfully
✓ Unseal keys saved to ~/.config/vault/keys.json
✓ Root token saved to ~/.config/vault/root-token

IMPORTANT: Backup these files immediately!
  cp -r ~/.config/vault ~/vault-backup-$(date +%Y%m%d)
```

**WARNING:** Only run once! Running again will fail if Vault is already initialized.

### vault-bootstrap

**Set up PKI and store all service credentials**

```bash
./manage-devstack.sh vault-bootstrap
```

**What it does:**
1. Creates root CA (10 year TTL)
2. Creates intermediate CA (5 year TTL)
3. Creates service roles for certificates
4. Generates and stores passwords for all services
5. Stores database connection info

**Services configured:**
- PostgreSQL
- MySQL
- MongoDB
- Redis (all nodes)
- RabbitMQ
- Forgejo

**Output:**
```
Bootstrapping Vault...

Setting up PKI...
✓ Root CA created
✓ Intermediate CA created
✓ Service roles created

Storing service credentials...
✓ PostgreSQL credentials stored
✓ MySQL credentials stored
✓ MongoDB credentials stored
✓ Redis credentials stored
✓ RabbitMQ credentials stored
✓ Forgejo credentials stored

Bootstrap complete!
```

### vault-status

**Check Vault seal status**

```bash
./manage-devstack.sh vault-status
```

**Output (unsealed):**
```
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    5
Threshold       3
Version         1.15.0
Storage Type    file
Cluster Name    vault-cluster-dev
```

**Output (sealed):**
```
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          true
Total Shares    5
Threshold       3

Vault is sealed. Run './manage-devstack.sh vault-unseal' to unseal.
```

### vault-unseal

**Manually unseal Vault**

```bash
./manage-devstack.sh vault-unseal
```

**What it does:**
1. Reads unseal keys from `~/.config/vault/keys.json`
2. Applies 3 keys (threshold)
3. Unseals Vault

**Output:**
```
Unsealing Vault...
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             false
Unseal Progress    3/3

✓ Vault unsealed successfully
```

### vault-token

**Display root token**

```bash
./manage-devstack.sh vault-token
```

**Output:**
```
Vault Root Token: hvs.CAESIJxyz123abc456...

Set token in environment:
  export VAULT_TOKEN=hvs.CAESIJxyz123abc456...

Or source the token file:
  export VAULT_TOKEN=$(cat ~/.config/vault/root-token)
```

### vault-show-password

**Get service password from Vault**

```bash
./manage-devstack.sh vault-show-password <service>
```

**Examples:**
```bash
# PostgreSQL password
./manage-devstack.sh vault-show-password postgres
# Output: pg_s3cr3t_p4ssw0rd

# MySQL password
./manage-devstack.sh vault-show-password mysql

# Redis password
./manage-devstack.sh vault-show-password redis-1

# Use in scripts
POSTGRES_PASSWORD=$(./manage-devstack.sh vault-show-password postgres)
psql "postgresql://devuser:$POSTGRES_PASSWORD@localhost/devdb"
```

## Backup Command

**Backup all databases and Vault data**

```bash
./manage-devstack.sh backup [name]
```

**Examples:**
```bash
# Standard backup
./manage-devstack.sh backup

# Named backup (e.g., pre-upgrade)
./manage-devstack.sh backup pre-upgrade

# Compressed backup
COMPRESS=true ./manage-devstack.sh backup
```

**What gets backed up:**
- PostgreSQL databases
- MySQL databases
- MongoDB databases
- Vault snapshot
- Vault keys and token
- Configuration files
- SSL certificates

**Backup location:**
```
~/devstack-core/backups/
├── 2024-01-15_14-30-00/
│   ├── postgres_devdb.sql
│   ├── mysql_devdb.sql
│   ├── mongodb_devdb.archive
│   ├── vault/
│   │   ├── keys.json
│   │   ├── root-token
│   │   └── snapshot.json
│   └── config/
└── latest -> 2024-01-15_14-30-00/
```

## Reset Command

**Destroy and reset environment (DATA LOSS)**

```bash
./manage-devstack.sh reset
```

**WARNING:** This command:
- Stops all containers
- Deletes all Docker volumes (ALL DATA LOST)
- Deletes Vault keys
- Stops Colima VM

**Confirmation required:**
```
WARNING: This will DELETE ALL DATA!
Are you sure you want to reset the environment? (yes/no): yes

Stopping all services...
Removing all containers...
Removing all volumes...
Removing Vault keys...
Stopping Colima...

Reset complete. To start fresh:
  ./manage-devstack.sh start
  ./manage-devstack.sh vault-init
  ./manage-devstack.sh vault-bootstrap
```

**Use when:**
- Starting completely fresh
- Testing initialization
- Fixing irreparable corruption
- Switching configurations

**ALWAYS backup before reset!**
```bash
# Backup first
./manage-devstack.sh backup pre-reset

# Then reset
./manage-devstack.sh reset
```

## Related Pages

- [Health-Monitoring](Health-Monitoring) - Health check details
- [Backup-and-Restore](Backup-and-Restore) - Backup procedures
- [Vault-Troubleshooting](Vault-Troubleshooting) - Vault commands
- [Service-Configuration](Service-Configuration) - Service management
