# Management Commands

Complete reference for the `manage-colima.sh` script - the primary interface for managing all Colima Services operations.

## Table of Contents

- [Overview](#overview)
- [Core Commands](#core-commands)
- [Vault Commands](#vault-commands)
- [Service Management](#service-management)
- [Monitoring Commands](#monitoring-commands)
- [Backup and Restore](#backup-and-restore)
- [Advanced Commands](#advanced-commands)
- [Command Reference](#command-reference)

## Overview

The `manage-colima.sh` script provides a unified interface for:
- Starting/stopping the entire environment
- Managing Vault initialization and configuration
- Monitoring service health
- Viewing logs
- Backup and restore operations

### Getting Help

```bash
# Show all available commands
./manage-colima.sh help

# Show version
./manage-colima.sh version
```

## Core Commands

### start

Start the entire Colima Services environment.

```bash
./manage-colima.sh start
```

**What it does:**
1. Checks if Colima is installed
2. Starts Colima VM (4 CPUs, 8GB RAM, 60GB disk)
3. Sets Docker context to Colima
4. Starts all Docker Compose services
5. Waits for services to become healthy

**Options:**
- None (configured in script or .env)

**Expected time:** 2-3 minutes

**Example output:**
```
✓ Colima is running
✓ Docker context set to colima
✓ Starting all services...
✓ All services started successfully
```

### stop

Stop all services and Colima VM.

```bash
./manage-colima.sh stop
```

**What it does:**
1. Stops all Docker Compose services
2. Stops Colima VM
3. Preserves all data in Docker volumes

**Data preserved:**
- Database data
- Vault data
- Redis data
- All configuration

**Example output:**
```
✓ Stopping all services...
✓ Services stopped
✓ Stopping Colima VM...
✓ Colima stopped
```

### restart

Restart all Docker Compose services without restarting Colima VM.

```bash
./manage-colima.sh restart
```

**What it does:**
1. Stops all Docker Compose services
2. Starts all Docker Compose services
3. Keeps Colima VM running

**Use when:**
- Services are misbehaving
- After configuration changes
- To refresh connections

**Faster than:** stop + start (VM stays running)

### status

Display status of all services with resource usage.

```bash
./manage-colima.sh status
```

**What it shows:**
- Service name
- Container state (running/stopped/restarting)
- Health status (healthy/unhealthy/starting)
- CPU usage
- Memory usage
- Network ports

**Example output:**
```
NAME              STATE     STATUS    CPU %    MEM USAGE   PORTS
dev-vault         running   healthy   0.12%    45.5MB      0.0.0.0:8200->8200/tcp
dev-postgres      running   healthy   0.05%    32.1MB      0.0.0.0:5432->5432/tcp
dev-redis-1       running   healthy   0.08%    12.3MB      0.0.0.0:6379->6379/tcp
...
```

## Vault Commands

### vault-init

Initialize Vault for first time use.

```bash
./manage-colima.sh vault-init
```

**What it does:**
1. Checks if Vault is already initialized
2. Initializes Vault with Shamir secret sharing (5 keys, threshold 3)
3. Saves unseal keys to `~/.config/vault/keys.json`
4. Saves root token to `~/.config/vault/root-token`
5. Automatically unseals Vault

**⚠️ Run this ONCE** - First time only

**Output files:**
- `~/.config/vault/keys.json` - Unseal keys
- `~/.config/vault/root-token` - Root token

**⚠️ BACKUP THESE FILES!** Without them, Vault data is unrecoverable.

**Example output:**
```
✓ Vault initialized successfully
✓ Unseal keys saved to ~/.config/vault/keys.json
✓ Root token saved to ~/.config/vault/root-token
✓ Vault unsealed
⚠️  BACKUP ~/.config/vault/ DIRECTORY!
```

### vault-bootstrap

Bootstrap Vault with PKI and service credentials.

```bash
./manage-colima.sh vault-bootstrap
```

**What it does:**
1. Creates Root CA (10-year validity)
2. Creates Intermediate CA (5-year validity)
3. Generates TLS certificates for all services
4. Stores database passwords in Vault KV store
5. Exports CA certificates to `~/.config/vault/ca/`

**Run after:** `vault-init`

**Creates:**
- `secret/postgres` - PostgreSQL credentials
- `secret/mysql` - MySQL credentials
- `secret/mongodb` - MongoDB credentials
- `secret/redis-1` - Redis password (shared across cluster)
- `secret/rabbitmq` - RabbitMQ credentials
- TLS certificates for all services

**Example output:**
```
✓ Root CA created (10-year validity)
✓ Intermediate CA created (5-year validity)
✓ Service certificates generated
✓ Database credentials stored in Vault
✓ CA certificates exported to ~/.config/vault/ca/
```

### vault-status

Check Vault initialization and seal status.

```bash
./manage-colima.sh vault-status
```

**What it shows:**
- Initialization status
- Seal status
- Seal threshold
- Total shares
- Version

**Example output:**
```
Vault Status:
  Initialized: true
  Sealed: false
  Seal Type: shamir
  Threshold: 3
  Total Shares: 5
  Version: 1.18.0
```

### vault-unseal

Manually unseal Vault (rarely needed due to auto-unseal).

```bash
./manage-colima.sh vault-unseal
```

**What it does:**
1. Reads unseal keys from `~/.config/vault/keys.json`
2. Applies 3 unseal keys (threshold)
3. Unseals Vault

**When needed:**
- After manual Vault restart
- If auto-unseal fails
- After VM reboot

**Note:** Vault auto-unseals on startup via entrypoint script.

### vault-token

Display the Vault root token.

```bash
./manage-colima.sh vault-token
```

**What it shows:**
- Root token value
- Location of token file

**Use for:**
- Setting VAULT_TOKEN environment variable
- Manual Vault CLI operations

**Example output:**
```
Vault Root Token: hvs.1234567890abcdef
Token file: ~/.config/vault/root-token

Export with:
  export VAULT_TOKEN=$(cat ~/.config/vault/root-token)
```

### vault-show-password

Retrieve a service password from Vault.

```bash
./manage-colima.sh vault-show-password <service>
```

**Supported services:**
- `postgres`
- `mysql`
- `mongodb`
- `redis`
- `rabbitmq`

**Example:**
```bash
# Get PostgreSQL password
./manage-colima.sh vault-show-password postgres

# Output: <password-string>
```

**Use cases:**
- Manual database connections
- Debugging authentication issues
- Setting up external tools

## Service Management

### logs

View logs for a specific service or all services.

```bash
# View logs for one service
./manage-colima.sh logs <service-name>

# View all logs
./manage-colima.sh logs

# Follow logs (real-time)
./manage-colima.sh logs <service-name> -f
```

**Examples:**
```bash
# View Vault logs
./manage-colima.sh logs vault

# Follow PostgreSQL logs
./manage-colima.sh logs postgres -f

# View last 100 lines
./manage-colima.sh logs redis-1 --tail 100
```

**Service names:**
- `vault`
- `postgres`, `pgbouncer`
- `mysql`
- `mongodb`
- `redis-1`, `redis-2`, `redis-3`
- `rabbitmq`
- `forgejo`
- `reference-api`, `api-first`
- `prometheus`, `grafana`, `loki`

### shell

Open interactive shell in a container.

```bash
./manage-colima.sh shell <service-name>
```

**What it does:**
- Opens `/bin/sh` or `/bin/bash` in container
- Useful for debugging and exploration

**Examples:**
```bash
# Shell into PostgreSQL container
./manage-colima.sh shell postgres

# Now you can run:
# psql -U dev_admin -d dev_database

# Shell into Vault container
./manage-colima.sh shell vault

# Now you can run:
# vault status
```

## Monitoring Commands

### health

Run health checks on all services.

```bash
./manage-colima.sh health
```

**What it checks:**
- Container status (running/stopped)
- Health check status (healthy/unhealthy)
- Service responsiveness
- Basic connectivity

**Example output:**
```
✓ Vault: healthy
✓ PostgreSQL: healthy
✓ MySQL: healthy
✓ MongoDB: healthy
✓ Redis Cluster: healthy (3/3 nodes)
✓ RabbitMQ: healthy
✓ Forgejo: healthy
⚠ Reference API: starting (2/3 attempts)
```

### stats

Display real-time resource usage statistics.

```bash
./manage-colima.sh stats
```

**What it shows:**
- Container name
- CPU percentage
- Memory usage / limit
- Memory percentage
- Network I/O
- Block I/O

**Refreshes:** Every 2 seconds

**Exit:** Press Ctrl+C

## Backup and Restore

### backup

Create backups of all databases.

```bash
./manage-colima.sh backup
```

**What it backs up:**
- PostgreSQL: SQL dump
- MySQL: SQL dump
- MongoDB: BSON dump
- Redis: RDB snapshot

**Backup location:** `./backups/YYYY-MM-DD_HH-MM-SS/`

**Example output:**
```
✓ Created backup directory: ./backups/2025-10-28_14-30-00/
✓ PostgreSQL backup complete: postgres_backup.sql (2.3MB)
✓ MySQL backup complete: mysql_backup.sql (1.1MB)
✓ MongoDB backup complete: mongodb_backup/ (512KB)
✓ Redis backup complete: redis_backup.rdb (128KB)
✓ Backup complete: ./backups/2025-10-28_14-30-00/
```

**Manual Vault backup:**
```bash
# Vault backup (CRITICAL)
cp -r ~/.config/vault ~/vault-backup-$(date +%Y%m%d)
```

## Advanced Commands

### reset

**⚠️ DESTRUCTIVE:** Delete all data and reset environment.

```bash
./manage-colima.sh reset
```

**What it does:**
1. Stops all services
2. Removes all Docker volumes (DATA LOSS)
3. Removes all Docker containers
4. Stops Colima VM
5. Optionally deletes Colima VM

**Data destroyed:**
- All database data
- Vault keys and secrets
- Redis data
- Container state

**Use when:**
- Starting fresh
- Unrecoverable errors
- Testing clean installs

**⚠️ Requires confirmation**

**After reset:**
```bash
./manage-colima.sh start
./manage-colima.sh vault-init
./manage-colima.sh vault-bootstrap
```

## Command Reference

### Quick Reference Table

| Command | Description | When to Use |
|---------|-------------|-------------|
| `start` | Start everything | First time, after reboot |
| `stop` | Stop everything | End of day, maintenance |
| `restart` | Restart services | After config changes |
| `status` | Show service status | Check if running |
| `health` | Run health checks | Verify all working |
| `logs <service>` | View logs | Debugging issues |
| `shell <service>` | Open shell | Debug inside container |
| `vault-init` | Initialize Vault | First time only |
| `vault-bootstrap` | Setup PKI & secrets | After vault-init |
| `vault-status` | Check Vault status | Verify Vault ready |
| `vault-token` | Show root token | Manual Vault access |
| `vault-show-password` | Get service password | Database connections |
| `backup` | Backup databases | Before major changes |
| `reset` | Delete everything | Start fresh |

### Common Workflows

**First Time Setup:**
```bash
./manage-colima.sh start
./manage-colima.sh vault-init
./manage-colima.sh vault-bootstrap
./manage-colima.sh health
```

**Daily Startup:**
```bash
./manage-colima.sh start
./manage-colima.sh status
```

**Debugging Issues:**
```bash
./manage-colima.sh status
./manage-colima.sh health
./manage-colima.sh logs <problematic-service>
./manage-colima.sh shell <problematic-service>
```

**Before Updates:**
```bash
./manage-colima.sh backup
# Make changes
./manage-colima.sh restart
./manage-colima.sh health
```

**Clean Slate:**
```bash
./manage-colima.sh backup  # Save what you need
./manage-colima.sh reset
./manage-colima.sh start
./manage-colima.sh vault-init
./manage-colima.sh vault-bootstrap
```

## Makefile Commands

For API synchronization and validation:

```bash
# Show all Makefile targets
make help

# Validate API sync
make validate

# Run tests
make test

# Generate API-first code
make regenerate
```

See [Development Workflow](Development-Workflow) for details.

## See Also

- [Quick Start Guide](Quick-Start-Guide) - Get started quickly
- [Common Issues](Common-Issues) - Troubleshooting
- [Service Configuration](Service-Configuration) - Configure services
- [Backup and Restore](Backup-and-Restore) - Data management
