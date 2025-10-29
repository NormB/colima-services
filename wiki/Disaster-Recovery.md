# Disaster Recovery

Comprehensive guide to disaster recovery procedures, backup strategies, and restoration processes for the Colima Services environment.

## Table of Contents

- [Overview](#overview)
- [Recovery Objectives](#recovery-objectives)
  - [RTO - Recovery Time Objective](#rto---recovery-time-objective)
  - [RPO - Recovery Point Objective](#rpo---recovery-point-objective)
  - [Service Priority Matrix](#service-priority-matrix)
- [Disaster Scenarios](#disaster-scenarios)
  - [Complete Data Loss](#complete-data-loss)
  - [Database Corruption](#database-corruption)
  - [Accidental Deletion](#accidental-deletion)
  - [Hardware Failure](#hardware-failure)
  - [Vault Key Loss](#vault-key-loss)
- [Backup Strategy](#backup-strategy)
  - [Automated Backups](#automated-backups)
  - [Offsite Storage](#offsite-storage)
  - [Backup Verification](#backup-verification)
  - [Backup Retention](#backup-retention)
- [Recovery Procedures](#recovery-procedures)
  - [PostgreSQL Restore](#postgresql-restore)
  - [MySQL Restore](#mysql-restore)
  - [MongoDB Restore](#mongodb-restore)
  - [Redis Data Recovery](#redis-data-recovery)
  - [RabbitMQ Configuration Restore](#rabbitmq-configuration-restore)
- [Vault Recovery](#vault-recovery)
  - [Unsealing Vault After Restart](#unsealing-vault-after-restart)
  - [Recovering from Lost Keys](#recovering-from-lost-keys)
  - [Re-initializing Vault](#re-initializing-vault)
  - [Restoring Vault Secrets](#restoring-vault-secrets)
- [Service Restoration](#service-restoration)
  - [Service Startup Order](#service-startup-order)
  - [Dependency Management](#dependency-management)
  - [Health Verification](#health-verification)
- [Testing Disaster Recovery](#testing-disaster-recovery)
  - [Regular DR Drills](#regular-dr-drills)
  - [Restore Testing](#restore-testing)
  - [Documentation Validation](#documentation-validation)
- [Partial Recovery](#partial-recovery)
  - [Recovering Individual Databases](#recovering-individual-databases)
  - [Selective Data Restoration](#selective-data-restoration)
  - [Table-Level Recovery](#table-level-recovery)
- [Data Validation](#data-validation)
  - [Post-Recovery Validation](#post-recovery-validation)
  - [Integrity Checks](#integrity-checks)
  - [Application Testing](#application-testing)
- [Incident Response](#incident-response)
  - [Communication Plan](#communication-plan)
  - [Escalation Procedures](#escalation-procedures)
  - [Post-Incident Review](#post-incident-review)
- [Point-in-Time Recovery](#point-in-time-recovery)
  - [PostgreSQL PITR](#postgresql-pitr)
  - [Transaction Log Replay](#transaction-log-replay)
  - [MySQL Binary Log Recovery](#mysql-binary-log-recovery)
- [Preventive Measures](#preventive-measures)
  - [Backup Monitoring](#backup-monitoring)
  - [Backup Alerts](#backup-alerts)
  - [Redundancy Strategies](#redundancy-strategies)
- [Complete System Recovery](#complete-system-recovery)
- [Reference](#reference)

## Overview

Disaster recovery (DR) is the process of restoring services and data after a catastrophic failure. This guide provides step-by-step procedures for recovering from various disaster scenarios in the Colima Services environment.

**Key Principles:**
- **Backup everything:** Databases, Vault keys, configurations, volumes
- **Test regularly:** DR procedures must be tested quarterly
- **Document everything:** Detailed runbooks for each scenario
- **Automate backups:** Scheduled automated backups reduce human error
- **Secure backups:** Offsite storage, encrypted, access-controlled

**Related Pages:**
- [Backup and Restore](Backup-and-Restore) - Detailed backup procedures
- [Vault Troubleshooting](Vault-Troubleshooting) - Vault recovery
- [Health Monitoring](Health-Monitoring) - Monitoring and alerting
- [Secrets Rotation](Secrets-Rotation) - Credential management

## Recovery Objectives

### RTO - Recovery Time Objective

**RTO:** Maximum acceptable time to restore service after disaster.

**Colima Services RTO Targets:**

| Service | RTO Target | Justification |
|---------|-----------|---------------|
| Vault | 15 minutes | Critical: All services depend on Vault |
| PostgreSQL | 30 minutes | High priority: Primary database |
| MySQL | 1 hour | Medium priority: Secondary database |
| MongoDB | 1 hour | Medium priority: Document store |
| Redis Cluster | 30 minutes | High priority: Cache and session store |
| RabbitMQ | 1 hour | Medium priority: Message queue |
| Reference Apps | 2 hours | Low priority: Example applications |
| Observability | 2 hours | Low priority: Monitoring stack |

### RPO - Recovery Point Objective

**RPO:** Maximum acceptable data loss (time between backups).

**Colima Services RPO Targets:**

| Data Type | RPO Target | Backup Frequency |
|-----------|-----------|------------------|
| PostgreSQL Data | 24 hours | Daily automated backups |
| MySQL Data | 24 hours | Daily automated backups |
| MongoDB Data | 24 hours | Daily automated backups |
| Vault Secrets | 0 minutes | Real-time (no data loss) |
| Vault Keys | 0 minutes | Immediately backed up after init |
| Configurations | 0 minutes | Version controlled in Git |
| Redis Data | Acceptable loss | Cache can be rebuilt |

**For production environments, reduce RPO to 1 hour or less with continuous backups.**

### Service Priority Matrix

**Recovery order based on dependencies:**

```
Priority 1 (Critical - Restore First):
├── Vault (all services depend on it)
└── Vault Keys (required to unseal Vault)

Priority 2 (High - Restore Second):
├── PostgreSQL (primary database)
├── PgBouncer (connection pooling)
└── Redis Cluster (sessions, cache)

Priority 3 (Medium - Restore Third):
├── MySQL (secondary database)
├── MongoDB (document store)
└── RabbitMQ (message queue)

Priority 4 (Low - Restore Last):
├── Reference applications
├── Observability stack (Prometheus, Grafana, Loki)
└── Development tools (Forgejo)
```

## Disaster Scenarios

### Complete Data Loss

**Scenario:** Entire Colima VM destroyed, all containers and volumes lost.

**Impact:**
- All services down
- All data lost (unless backed up)
- Complete environment rebuild required

**Recovery procedure:** See [Complete System Recovery](#complete-system-recovery)

### Database Corruption

**Scenario:** Database files corrupted, service won't start.

**Symptoms:**
```bash
# PostgreSQL corruption
docker logs dev-postgres
# ERROR: invalid page in block 12345 of relation base/16384/16385
# PANIC: corrupted page detected

# MySQL corruption
docker logs dev-mysql
# ERROR: Table './myapp/users' is marked as crashed and should be repaired
```

**Recovery:** Restore from backup (see [Recovery Procedures](#recovery-procedures))

### Accidental Deletion

**Scenario:** Important data accidentally deleted (DROP TABLE, DELETE without WHERE).

**Symptoms:**
```sql
-- Oops!
DROP TABLE users;
-- Query OK, 0 rows affected

-- Or
DELETE FROM orders;
-- Query OK, 50000 rows affected
```

**Recovery:**
1. **Stop writes immediately** (prevent further data loss)
2. **Assess scope** (what was deleted?)
3. **Restore from backup** (latest backup before deletion)
4. **Point-in-time recovery** (if available, restore to moment before deletion)

### Hardware Failure

**Scenario:** Mac hardware failure, disk failure, system crash.

**Recovery:**
1. **Assess hardware:** Can system boot? Is disk accessible?
2. **If disk accessible:** Backup Vault keys and data volumes
3. **If disk failed:** Restore from offsite backups
4. **New hardware:** Rebuild environment from backups

### Vault Key Loss

**Scenario:** Vault unseal keys or root token lost.

**Impact:**
- **Cannot unseal Vault** (if keys lost)
- **Cannot access secrets** (if root token lost)
- **All services unable to fetch credentials**
- **CATASTROPHIC if no backup**

**Prevention:** Always backup `~/.config/vault/` immediately after Vault initialization.

**Recovery:** See [Vault Recovery](#vault-recovery)

## Backup Strategy

### Automated Backups

**Backup script (runs daily):**

```bash
#!/bin/bash
# Save as: /Users/gator/colima-services/scripts/automated-backup.sh

set -e

BACKUP_ROOT="/Users/gator/colima-services/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/$DATE"

echo "=== Automated Backup Started: $(date) ==="

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup PostgreSQL (all databases)
echo "Backing up PostgreSQL..."
docker exec dev-postgres pg_dumpall -U postgres | gzip > "$BACKUP_DIR/postgresql_all.sql.gz"

# Backup PostgreSQL (per-database custom format)
for DB in postgres forgejo; do
    docker exec dev-postgres pg_dump -U postgres -Fc "$DB" > "$BACKUP_DIR/postgresql_${DB}.dump"
done

# Backup MySQL (all databases)
echo "Backing up MySQL..."
docker exec dev-mysql mysqldump -u root --all-databases | gzip > "$BACKUP_DIR/mysql_all.sql.gz"

# Backup MongoDB (all databases)
echo "Backing up MongoDB..."
docker exec dev-mongodb mongodump --username root --authenticationDatabase admin --out=/tmp/mongodump
docker cp dev-mongodb:/tmp/mongodump "$BACKUP_DIR/mongodb"
docker exec dev-mongodb rm -rf /tmp/mongodump

# Backup Vault keys (CRITICAL)
echo "Backing up Vault keys..."
cp -r ~/.config/vault "$BACKUP_DIR/vault"

# Backup Vault secrets (export all)
echo "Backing up Vault secrets..."
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)
vault kv list secret/ | tail -n +3 | while read SECRET; do
    vault kv get -format=json "secret/$SECRET" > "$BACKUP_DIR/vault/secrets_${SECRET}.json"
done

# Backup Docker volumes
echo "Backing up Docker volumes..."
docker run --rm -v postgres_data:/data -v "$BACKUP_DIR:/backup" alpine tar czf /backup/postgres_data.tar.gz -C /data .
docker run --rm -v mysql_data:/data -v "$BACKUP_DIR:/backup" alpine tar czf /backup/mysql_data.tar.gz -C /data .
docker run --rm -v mongodb_data:/data -v "$BACKUP_DIR:/backup" alpine tar czf /backup/mongodb_data.tar.gz -C /data .

# Backup configuration files
echo "Backing up configurations..."
cp -r /Users/gator/colima-services/configs "$BACKUP_DIR/"
cp /Users/gator/colima-services/.env "$BACKUP_DIR/"
cp /Users/gator/colima-services/docker-compose.yml "$BACKUP_DIR/"

# Create backup manifest
cat > "$BACKUP_DIR/MANIFEST.txt" << EOF
Backup Date: $(date)
Backup Directory: $BACKUP_DIR

Files:
$(ls -lh "$BACKUP_DIR")

Docker Volumes:
$(docker volume ls)

Services Running:
$(docker ps --format "table {{.Names}}\t{{.Status}}")
EOF

# Compress entire backup
echo "Compressing backup..."
tar czf "$BACKUP_ROOT/backup_$DATE.tar.gz" -C "$BACKUP_ROOT" "$DATE"
rm -rf "$BACKUP_DIR"

# Remove old backups (keep last 7 days)
find "$BACKUP_ROOT" -name "backup_*.tar.gz" -mtime +7 -delete

echo "=== Backup Complete: $(date) ==="
echo "Backup location: $BACKUP_ROOT/backup_$DATE.tar.gz"
echo "Backup size: $(du -h $BACKUP_ROOT/backup_$DATE.tar.gz | cut -f1)"
```

**Make script executable and schedule:**

```bash
chmod +x /Users/gator/colima-services/scripts/automated-backup.sh

# Add to crontab (daily at 2 AM)
crontab -e
# Add: 0 2 * * * /Users/gator/colima-services/scripts/automated-backup.sh >> ~/backup.log 2>&1
```

### Offsite Storage

**Copy backups to offsite location:**

```bash
# Sync to external drive
EXTERNAL_DRIVE="/Volumes/BackupDrive"
rsync -av --delete /Users/gator/colima-services/backups/ "$EXTERNAL_DRIVE/colima-backups/"

# Or sync to cloud storage (AWS S3 example)
aws s3 sync /Users/gator/colima-services/backups/ s3://my-backup-bucket/colima-backups/

# Or sync to remote server
rsync -av -e ssh /Users/gator/colima-services/backups/ user@backup-server:/backups/colima/
```

### Backup Verification

**Test backups regularly:**

```bash
#!/bin/bash
# Save as: /Users/gator/colima-services/scripts/verify-backups.sh

BACKUP_FILE="/Users/gator/colima-services/backups/backup_$(date +%Y%m%d)_*.tar.gz"

echo "=== Backup Verification ==="

# 1. Check backup exists
if [ ! -f $BACKUP_FILE ]; then
    echo "✗ Backup file not found: $BACKUP_FILE"
    exit 1
fi
echo "✓ Backup file exists"

# 2. Verify backup is not corrupted
tar tzf $BACKUP_FILE > /dev/null
if [ $? -eq 0 ]; then
    echo "✓ Backup archive is valid"
else
    echo "✗ Backup archive is corrupted"
    exit 1
fi

# 3. Extract backup to temp location
TEMP_DIR=$(mktemp -d)
tar xzf $BACKUP_FILE -C "$TEMP_DIR"
echo "✓ Backup extracted successfully"

# 4. Verify PostgreSQL backup
if [ -f "$TEMP_DIR"/*/postgresql_all.sql.gz ]; then
    gunzip -t "$TEMP_DIR"/*/postgresql_all.sql.gz
    echo "✓ PostgreSQL backup is valid"
else
    echo "✗ PostgreSQL backup not found"
fi

# 5. Verify Vault keys exist
if [ -d "$TEMP_DIR"/*/vault ]; then
    if [ -f "$TEMP_DIR"/*/vault/keys.json ] && [ -f "$TEMP_DIR"/*/vault/root-token ]; then
        echo "✓ Vault keys present"
    else
        echo "✗ Vault keys missing"
    fi
else
    echo "✗ Vault backup not found"
fi

# 6. Verify backup size (should be > 10MB)
BACKUP_SIZE=$(stat -f%z "$BACKUP_FILE")
if [ $BACKUP_SIZE -gt 10485760 ]; then
    echo "✓ Backup size acceptable ($(numfmt --to=iec-i --suffix=B $BACKUP_SIZE))"
else
    echo "⚠ Backup size suspiciously small"
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo "=== Verification Complete ==="
```

### Backup Retention

**Retention policy:**

```
Daily backups: Keep for 7 days
Weekly backups: Keep for 4 weeks
Monthly backups: Keep for 12 months
Yearly backups: Keep indefinitely

Example:
├── Daily: 2024-10-28, 2024-10-27, ..., 2024-10-22 (7 days)
├── Weekly: 2024-10-21, 2024-10-14, 2024-10-07, 2024-09-30 (4 weeks)
├── Monthly: 2024-10-01, 2024-09-01, ..., 2023-11-01 (12 months)
└── Yearly: 2024-01-01, 2023-01-01, 2022-01-01 (indefinite)
```

**Retention script:**

```bash
#!/bin/bash
# Save as: /Users/gator/colima-services/scripts/backup-retention.sh

BACKUP_DIR="/Users/gator/colima-services/backups"

# Keep daily backups for 7 days
find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +7 -type f -delete

# Keep weekly backups (Sundays) for 4 weeks
# Keep monthly backups (1st of month) for 12 months
# Keep yearly backups (January 1st) forever

echo "Backup retention policy applied"
```

## Recovery Procedures

### PostgreSQL Restore

**Scenario:** Restore PostgreSQL from backup.

#### Full Database Restore

```bash
#!/bin/bash
# PostgreSQL full restore procedure

echo "=== PostgreSQL Restore Procedure ==="

# 1. Identify backup file
BACKUP_FILE="/Users/gator/colima-services/backups/backup_20241027_020000.tar.gz"
TEMP_DIR=$(mktemp -d)

# 2. Extract backup
echo "Extracting backup..."
tar xzf "$BACKUP_FILE" -C "$TEMP_DIR"
BACKUP_EXTRACTED=$(find "$TEMP_DIR" -name "postgresql_all.sql.gz" -exec dirname {} \;)

# 3. Stop dependent services
echo "Stopping dependent services..."
docker stop reference-api api-first dev-pgbouncer

# 4. Stop PostgreSQL
echo "Stopping PostgreSQL..."
docker stop dev-postgres

# 5. Remove PostgreSQL volume
echo "⚠️ WARNING: Removing PostgreSQL volume (data will be lost)"
read -p "Continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted"
    exit 1
fi

docker volume rm postgres_data

# 6. Restart PostgreSQL (creates new empty database)
echo "Starting PostgreSQL..."
docker start dev-postgres
sleep 15

# 7. Restore data
echo "Restoring data..."
gunzip -c "$BACKUP_EXTRACTED/postgresql_all.sql.gz" | docker exec -i dev-postgres psql -U postgres

# 8. Verify restore
echo "Verifying restore..."
docker exec dev-postgres psql -U postgres -c "\l"
docker exec dev-postgres psql -U postgres -c "SELECT count(*) FROM pg_database;"

# 9. Restart dependent services
echo "Starting dependent services..."
docker start dev-pgbouncer
sleep 5
docker start reference-api api-first
sleep 5

# 10. Verify connectivity
echo "Verifying connectivity..."
docker exec dev-postgres psql -U postgres -c "SELECT version();"
curl http://localhost:8000/health

echo "=== Restore Complete ==="

# Cleanup
rm -rf "$TEMP_DIR"
```

#### Single Database Restore

```bash
#!/bin/bash
# Restore single database (forgejo example)

BACKUP_FILE="/Users/gator/colima-services/backups/backup_20241027_020000.tar.gz"
DATABASE="forgejo"

# Extract backup
TEMP_DIR=$(mktemp -d)
tar xzf "$BACKUP_FILE" -C "$TEMP_DIR"
BACKUP_EXTRACTED=$(find "$TEMP_DIR" -name "postgresql_${DATABASE}.dump" -exec dirname {} \;)

# Drop and recreate database
docker exec dev-postgres psql -U postgres -c "DROP DATABASE IF EXISTS $DATABASE;"
docker exec dev-postgres psql -U postgres -c "CREATE DATABASE $DATABASE;"

# Restore database
docker exec -i dev-postgres pg_restore -U postgres -d "$DATABASE" < "$BACKUP_EXTRACTED/postgresql_${DATABASE}.dump"

# Verify
docker exec dev-postgres psql -U postgres -d "$DATABASE" -c "\dt"

echo "✓ Database $DATABASE restored"

# Cleanup
rm -rf "$TEMP_DIR"
```

### MySQL Restore

```bash
#!/bin/bash
# MySQL full restore procedure

echo "=== MySQL Restore Procedure ==="

BACKUP_FILE="/Users/gator/colima-services/backups/backup_20241027_020000.tar.gz"
TEMP_DIR=$(mktemp -d)

# Extract backup
tar xzf "$BACKUP_FILE" -C "$TEMP_DIR"
BACKUP_EXTRACTED=$(find "$TEMP_DIR" -name "mysql_all.sql.gz" -exec dirname {} \;)

# Stop MySQL
docker stop dev-mysql

# Remove MySQL volume
docker volume rm mysql_data

# Start MySQL
docker start dev-mysql
sleep 20

# Restore data
gunzip -c "$BACKUP_EXTRACTED/mysql_all.sql.gz" | docker exec -i dev-mysql mysql -u root

# Verify
docker exec dev-mysql mysql -u root -e "SHOW DATABASES;"

echo "=== MySQL Restore Complete ==="

# Cleanup
rm -rf "$TEMP_DIR"
```

### MongoDB Restore

```bash
#!/bin/bash
# MongoDB restore procedure

echo "=== MongoDB Restore Procedure ==="

BACKUP_FILE="/Users/gator/colima-services/backups/backup_20241027_020000.tar.gz"
TEMP_DIR=$(mktemp -d)

# Extract backup
tar xzf "$BACKUP_FILE" -C "$TEMP_DIR"
BACKUP_EXTRACTED=$(find "$TEMP_DIR" -type d -name "mongodb")

# Stop MongoDB
docker stop dev-mongodb

# Remove MongoDB volume
docker volume rm mongodb_data

# Start MongoDB
docker start dev-mongodb
sleep 15

# Copy backup into container
docker cp "$BACKUP_EXTRACTED" dev-mongodb:/tmp/mongodump

# Restore data
docker exec dev-mongodb mongorestore --username root --authenticationDatabase admin /tmp/mongodump

# Cleanup container
docker exec dev-mongodb rm -rf /tmp/mongodump

# Verify
docker exec dev-mongodb mongosh -u root --authenticationDatabase admin --eval "db.adminCommand('listDatabases')"

echo "=== MongoDB Restore Complete ==="

# Cleanup
rm -rf "$TEMP_DIR"
```

### Redis Data Recovery

**Note:** Redis is primarily a cache. Data loss is acceptable. Recovery rebuilds cache.

```bash
# If Redis persistence enabled (RDB/AOF)
# Stop Redis
docker stop dev-redis-1

# Restore RDB/AOF files (if backed up)
# Copy to volume: /data

# Start Redis
docker start dev-redis-1

# Verify
docker exec dev-redis-1 redis-cli PING

# For cache: Let application rebuild cache naturally
echo "Redis restarted. Cache will rebuild from application."
```

### RabbitMQ Configuration Restore

```bash
#!/bin/bash
# RabbitMQ configuration restore

# Export current definitions (backup)
curl -u admin:password http://localhost:15672/api/definitions > rabbitmq-definitions.json

# Restore definitions
curl -u admin:password -X POST -H "Content-Type: application/json" \
    -d @rabbitmq-definitions.json http://localhost:15672/api/definitions

echo "✓ RabbitMQ configuration restored"
```

## Vault Recovery

### Unsealing Vault After Restart

**If Vault restarted and sealed:**

```bash
# Check Vault status
docker exec dev-vault vault status

# If sealed, unseal using keys
UNSEAL_KEY_1=$(cat ~/.config/vault/keys.json | jq -r '.unseal_keys_b64[0]')
UNSEAL_KEY_2=$(cat ~/.config/vault/keys.json | jq -r '.unseal_keys_b64[1]')
UNSEAL_KEY_3=$(cat ~/.config/vault/keys.json | jq -r '.unseal_keys_b64[2]')

docker exec dev-vault vault operator unseal "$UNSEAL_KEY_1"
docker exec dev-vault vault operator unseal "$UNSEAL_KEY_2"
docker exec dev-vault vault operator unseal "$UNSEAL_KEY_3"

# Verify unsealed
docker exec dev-vault vault status

echo "✓ Vault unsealed"
```

### Recovering from Lost Keys

**⚠️ CRITICAL:** If Vault keys are lost and Vault is sealed, **data cannot be recovered**.

**Prevention:**
- Backup `~/.config/vault/keys.json` immediately after initialization
- Store backup in secure offsite location
- Never delete this file

**If keys are lost:**
```bash
# If Vault is sealed: DATA IS UNRECOVERABLE
# If Vault is unsealed: Export secrets immediately

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# Export all secrets
vault kv list secret/ | tail -n +3 | while read SECRET; do
    vault kv get -format=json "secret/$SECRET" > "vault-secrets-${SECRET}.json"
done

# Backup these files immediately
# Re-initialize Vault (see below)
```

### Re-initializing Vault

**If Vault data lost, re-initialize from scratch:**

```bash
#!/bin/bash
# Re-initialize Vault and restore secrets

echo "=== Vault Re-initialization ==="

# Stop all services
docker compose down

# Remove Vault volume
docker volume rm vault_data

# Start Vault
docker compose up -d vault
sleep 10

# Initialize Vault
./manage-colima.sh vault-init

# Bootstrap Vault (PKI, secrets)
./manage-colima.sh vault-bootstrap

# Restore secrets from backup (if available)
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# Restore each secret
vault kv put secret/postgres password="<from_backup>"
vault kv put secret/mysql password="<from_backup>"
vault kv put secret/mongodb password="<from_backup>"
vault kv put secret/redis-1 password="<from_backup>"
vault kv put secret/rabbitmq password="<from_backup>"

# Regenerate certificates
./scripts/generate-certificates.sh

# Start all services
docker compose up -d

echo "=== Vault Re-initialization Complete ==="
```

### Restoring Vault Secrets

**Restore secrets from backup:**

```bash
#!/bin/bash
# Restore Vault secrets from JSON backups

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

BACKUP_DIR="/Users/gator/colima-services/backups/20241027_020000/vault"

# Restore each secret
for SECRET_FILE in "$BACKUP_DIR"/secrets_*.json; do
    SECRET_NAME=$(basename "$SECRET_FILE" .json | sed 's/secrets_//')
    echo "Restoring secret: $SECRET_NAME"

    # Extract and restore secret data
    jq -r '.data.data' "$SECRET_FILE" | \
        vault kv put "secret/$SECRET_NAME" -

done

echo "✓ Vault secrets restored"
```

## Service Restoration

### Service Startup Order

**Correct order (respects dependencies):**

```bash
#!/bin/bash
# Start services in correct order

echo "=== Service Restoration ==="

# 1. Start Vault (critical)
echo "Starting Vault..."
docker start dev-vault
sleep 10

# Unseal Vault if needed
./manage-colima.sh vault-status
# If sealed: ./scripts/unseal-vault.sh

# 2. Start databases
echo "Starting databases..."
docker start dev-postgres
sleep 10

docker start dev-mysql
sleep 10

docker start dev-mongodb
sleep 10

# 3. Start PgBouncer
echo "Starting PgBouncer..."
docker start dev-pgbouncer
sleep 5

# 4. Start Redis cluster
echo "Starting Redis cluster..."
docker start dev-redis-1 dev-redis-2 dev-redis-3
sleep 10

# 5. Start RabbitMQ
echo "Starting RabbitMQ..."
docker start dev-rabbitmq
sleep 15

# 6. Start applications
echo "Starting applications..."
docker start reference-api api-first golang-api nodejs-api rust-api
sleep 10

# 7. Start observability
echo "Starting observability stack..."
docker start dev-prometheus dev-grafana dev-loki dev-vector
sleep 5

echo "=== Service Restoration Complete ==="
```

### Dependency Management

**Service dependency tree:**

```
Vault (no dependencies)
├── PostgreSQL (depends on Vault)
│   └── PgBouncer (depends on PostgreSQL)
│       └── Reference API (depends on PgBouncer)
├── MySQL (depends on Vault)
│   └── Reference API (depends on MySQL)
├── MongoDB (depends on Vault)
│   └── Reference API (depends on MongoDB)
├── Redis Cluster (depends on Vault)
│   └── Reference API (depends on Redis)
└── RabbitMQ (depends on Vault)
    └── Reference API (depends on RabbitMQ)
```

### Health Verification

**After restoration, verify all services:**

```bash
#!/bin/bash
# Comprehensive health check after restoration

echo "=== Post-Restoration Health Check ==="

# Vault
echo -n "Vault: "
curl -s http://localhost:8200/v1/sys/health > /dev/null && echo "✓ Healthy" || echo "✗ Unhealthy"

# PostgreSQL
echo -n "PostgreSQL: "
docker exec dev-postgres pg_isready -U postgres > /dev/null && echo "✓ Healthy" || echo "✗ Unhealthy"

# PgBouncer
echo -n "PgBouncer: "
docker exec dev-postgres psql -h pgbouncer -p 6432 -U postgres -c "SELECT 1;" > /dev/null 2>&1 && echo "✓ Healthy" || echo "✗ Unhealthy"

# MySQL
echo -n "MySQL: "
docker exec dev-mysql mysqladmin ping -u root > /dev/null 2>&1 && echo "✓ Healthy" || echo "✗ Unhealthy"

# MongoDB
echo -n "MongoDB: "
docker exec dev-mongodb mongosh -u root --authenticationDatabase admin --eval "db.adminCommand('ping')" > /dev/null 2>&1 && echo "✓ Healthy" || echo "✗ Unhealthy"

# Redis
echo -n "Redis: "
docker exec dev-redis-1 redis-cli PING > /dev/null 2>&1 && echo "✓ Healthy" || echo "✗ Unhealthy"

# RabbitMQ
echo -n "RabbitMQ: "
docker exec dev-rabbitmq rabbitmqctl status > /dev/null 2>&1 && echo "✓ Healthy" || echo "✗ Unhealthy"

# Reference API
echo -n "Reference API: "
curl -s http://localhost:8000/health > /dev/null && echo "✓ Healthy" || echo "✗ Unhealthy"

echo "=== Health Check Complete ==="
```

## Testing Disaster Recovery

### Regular DR Drills

**Quarterly DR drill procedure:**

```bash
#!/bin/bash
# Disaster Recovery Drill

echo "=== Disaster Recovery Drill ==="
echo "Date: $(date)"
echo "Scenario: Complete data loss"

# 1. Document current state
echo "1. Documenting current state..."
docker ps > /tmp/dr-drill-services-before.txt
./manage-colima.sh health > /tmp/dr-drill-health-before.txt

# 2. Create test data
echo "2. Creating test data..."
docker exec dev-postgres psql -U postgres -c "
CREATE TABLE IF NOT EXISTS dr_drill_test (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP DEFAULT NOW(),
    drill_id VARCHAR(50)
);
INSERT INTO dr_drill_test (drill_id) VALUES ('DRILL-$(date +%Y%m%d-%H%M%S)');
"

# 3. Backup
echo "3. Creating backup..."
./scripts/automated-backup.sh

# 4. Simulate disaster (destroy everything)
echo "4. Simulating disaster..."
docker compose down -v  # ⚠️ This deletes all data

# 5. Restore from backup
echo "5. Restoring from backup..."
./scripts/restore-from-backup.sh

# 6. Verify restoration
echo "6. Verifying restoration..."
docker exec dev-postgres psql -U postgres -c "SELECT * FROM dr_drill_test ORDER BY created_at DESC LIMIT 1;"

# 7. Document results
echo "7. Documenting results..."
docker ps > /tmp/dr-drill-services-after.txt
./manage-colima.sh health > /tmp/dr-drill-health-after.txt

echo "=== DR Drill Complete ==="
echo "Review: Compare /tmp/dr-drill-*.txt files"
```

### Restore Testing

**Test restore without destroying production:**

```bash
# Test restore on separate system or VM
# 1. Copy backup to test system
# 2. Run restore procedure
# 3. Verify data integrity
# 4. Document any issues
# 5. Update DR procedures if needed
```

### Documentation Validation

**Ensure DR documentation is current:**

- [ ] DR procedures tested within last 90 days
- [ ] All recovery scripts functional
- [ ] Contact information current
- [ ] Backup locations accessible
- [ ] Vault keys accessible and valid
- [ ] Recovery time objectives met in testing
- [ ] All team members trained on procedures

## Partial Recovery

### Recovering Individual Databases

**Restore single database without affecting others:**

```bash
# Example: Restore only "forgejo" database
BACKUP_FILE="/Users/gator/colima-services/backups/backup_20241027_020000.tar.gz"

# Extract backup
tar xzf "$BACKUP_FILE" -C /tmp
DUMP_FILE=$(find /tmp -name "postgresql_forgejo.dump")

# Drop and recreate database
docker exec dev-postgres psql -U postgres -c "DROP DATABASE IF EXISTS forgejo;"
docker exec dev-postgres psql -U postgres -c "CREATE DATABASE forgejo;"

# Restore
docker exec -i dev-postgres pg_restore -U postgres -d forgejo < "$DUMP_FILE"

# Verify
docker exec dev-postgres psql -U postgres -d forgejo -c "\dt"

echo "✓ Database forgejo restored"
```

### Selective Data Restoration

**Restore specific tables:**

```bash
# Extract single table from backup
pg_restore -t users -d myapp backup.dump

# Or using SQL dump
docker exec -i dev-postgres psql -U postgres myapp << EOF
-- Drop table if exists
DROP TABLE IF EXISTS users CASCADE;

-- Restore table definition and data
\i /path/to/users_table_backup.sql
EOF
```

### Table-Level Recovery

**Restore table from backup without dropping database:**

```bash
#!/bin/bash
# Restore single table (users example)

DATABASE="myapp"
TABLE="users"
BACKUP_FILE="postgresql_${DATABASE}.dump"

# Create temporary database
docker exec dev-postgres psql -U postgres -c "CREATE DATABASE temp_restore;"

# Restore full backup to temp database
docker exec -i dev-postgres pg_restore -U postgres -d temp_restore < "$BACKUP_FILE"

# Copy table from temp to production
docker exec dev-postgres psql -U postgres -c "
-- Backup current table
CREATE TABLE ${TABLE}_backup AS SELECT * FROM $DATABASE.$TABLE;

-- Drop current table
DROP TABLE $DATABASE.$TABLE;

-- Copy from temp database
CREATE TABLE $DATABASE.$TABLE AS SELECT * FROM temp_restore.$TABLE;

-- Restore constraints/indexes (manual, based on schema)
"

# Drop temp database
docker exec dev-postgres psql -U postgres -c "DROP DATABASE temp_restore;"

echo "✓ Table $TABLE restored"
```

## Data Validation

### Post-Recovery Validation

```bash
#!/bin/bash
# Validate data after recovery

echo "=== Post-Recovery Data Validation ==="

# 1. Check database sizes
echo "1. Database sizes:"
docker exec dev-postgres psql -U postgres -c "
SELECT datname, pg_size_pretty(pg_database_size(datname)) as size
FROM pg_database
WHERE datname NOT IN ('template0', 'template1')
ORDER BY pg_database_size(datname) DESC;
"

# 2. Check row counts
echo "2. Row counts (PostgreSQL):"
docker exec dev-postgres psql -U postgres -d myapp -c "
SELECT schemaname, tablename,
       n_live_tup as row_count
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;
"

# 3. Check data consistency
echo "3. Data consistency checks:"
docker exec dev-postgres psql -U postgres -d myapp -c "
-- Check for null values in non-nullable columns
-- Check referential integrity
-- Check data ranges
"

# 4. Application smoke tests
echo "4. Application smoke tests:"
curl http://localhost:8000/api/postgres/users | jq '.count'
curl http://localhost:8000/api/redis/get/test

echo "=== Validation Complete ==="
```

### Integrity Checks

```bash
# PostgreSQL integrity checks
docker exec dev-postgres psql -U postgres -d myapp -c "
-- Check for corrupted indexes
REINDEX DATABASE myapp;

-- Check table corruption
SELECT * FROM pg_class WHERE relname = 'users';

-- Analyze tables
ANALYZE;
"

# MySQL integrity checks
docker exec dev-mysql mysqlcheck -u root --all-databases --check --auto-repair
```

### Application Testing

```bash
# Run test suite after recovery
./tests/run-all-tests.sh

# Manual testing
curl http://localhost:8000/health
curl http://localhost:8000/api/postgres/users
curl http://localhost:8000/api/redis/set/test/value
curl http://localhost:8000/api/rabbitmq/publish
```

## Incident Response

### Communication Plan

**During disaster:**

1. **Assess situation** (within 5 minutes)
2. **Notify team** (within 10 minutes)
3. **Update status** (every 30 minutes)
4. **Document actions** (real-time)

**Communication channels:**
- Slack: #incidents
- Email: team@example.com
- Phone: Emergency contact list

**Status updates:**
```
Subject: [INCIDENT] Colima Services - PostgreSQL Data Loss

Status: RECOVERING
Time: 2024-10-28 14:30 UTC
Impact: All applications unable to access PostgreSQL
Action: Restoring from backup (ETA: 30 minutes)
Next Update: 2024-10-28 15:00 UTC
```

### Escalation Procedures

**Escalation levels:**

**Level 1:** Minor incident (< 1 hour downtime)
- Handle within team
- Document in incident log

**Level 2:** Major incident (1-4 hours downtime)
- Notify management
- Engage backup resources
- Post-incident review required

**Level 3:** Critical incident (> 4 hours downtime)
- Escalate to senior management
- Consider external assistance
- Detailed post-incident review
- Update DR procedures

### Post-Incident Review

**After recovery, conduct review:**

```
Incident Post-Mortem Template:

1. Incident Summary
   - Date/time of incident
   - Duration of downtime
   - Services affected
   - Root cause

2. Timeline
   - Detection: When was incident detected?
   - Response: When did recovery begin?
   - Resolution: When was service restored?

3. Impact
   - Data loss (if any)
   - Service unavailability
   - User impact

4. Root Cause Analysis
   - What went wrong?
   - Why did it happen?
   - What were contributing factors?

5. Recovery Actions
   - What steps were taken?
   - What worked well?
   - What didn't work?

6. Lessons Learned
   - What should be changed?
   - How can we prevent recurrence?
   - What worked well?

7. Action Items
   - [ ] Update DR procedures
   - [ ] Improve monitoring
   - [ ] Additional backups
   - [ ] Team training
```

## Point-in-Time Recovery

### PostgreSQL PITR

**Requires WAL archiving (setup first):**

```bash
# Enable WAL archiving in postgresql.conf
docker exec dev-postgres bash -c "cat >> /var/lib/postgresql/data/postgresql.conf << EOF
wal_level = replica
archive_mode = on
archive_command = 'test ! -f /var/lib/postgresql/wal_archive/%f && cp %p /var/lib/postgresql/wal_archive/%f'
EOF"

# Restart PostgreSQL
docker restart dev-postgres
```

**Create base backup:**

```bash
# Create base backup for PITR
docker exec dev-postgres pg_basebackup -U postgres -D /tmp/basebackup -Ft -z -P

# WAL files automatically archived to /var/lib/postgresql/wal_archive/
```

**Perform PITR:**

```bash
# Stop PostgreSQL
docker stop dev-postgres

# Remove data directory
docker exec dev-postgres rm -rf /var/lib/postgresql/data/*

# Restore base backup
docker cp backup.tar.gz dev-postgres:/tmp/
docker exec dev-postgres tar xzf /tmp/backup.tar.gz -C /var/lib/postgresql/data

# Create recovery.conf
docker exec dev-postgres bash -c "cat > /var/lib/postgresql/data/recovery.conf << EOF
restore_command = 'cp /var/lib/postgresql/wal_archive/%f %p'
recovery_target_time = '2024-10-28 14:00:00'
EOF"

# Start PostgreSQL (will replay WAL to target time)
docker start dev-postgres

# Monitor recovery
docker logs dev-postgres -f
# When recovery complete, recovery.conf renamed to recovery.done
```

### Transaction Log Replay

**Manual WAL replay:**

```bash
# Copy WAL files to pg_wal directory
docker cp wal_archive/* dev-postgres:/var/lib/postgresql/data/pg_wal/

# PostgreSQL will automatically replay on startup
docker restart dev-postgres
```

### MySQL Binary Log Recovery

**Requires binary logging (setup first):**

```bash
# Enable binary logging in my.cnf
docker exec dev-mysql bash -c "cat >> /etc/mysql/my.cnf << EOF
[mysqld]
log-bin=/var/lib/mysql/mysql-bin
binlog_format=ROW
EOF"

# Restart MySQL
docker restart dev-mysql
```

**Perform PITR:**

```bash
# Restore from full backup first
mysql -u root < full_backup.sql

# Then apply binary logs up to specific time
mysqlbinlog --stop-datetime="2024-10-28 14:00:00" mysql-bin.000001 | mysql -u root
```

## Preventive Measures

### Backup Monitoring

```bash
#!/bin/bash
# Monitor backup health

BACKUP_DIR="/Users/gator/colima-services/backups"
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/backup_*.tar.gz | head -1)

# Check if backup exists today
if [ -z "$LATEST_BACKUP" ]; then
    echo "✗ No backup found"
    # Send alert
    exit 1
fi

# Check backup age (should be < 24 hours)
BACKUP_AGE=$(( ($(date +%s) - $(stat -f%m "$LATEST_BACKUP")) / 3600 ))
if [ $BACKUP_AGE -gt 24 ]; then
    echo "⚠ Backup is $BACKUP_AGE hours old (> 24 hours)"
    # Send alert
fi

# Check backup size (should be > 10MB)
BACKUP_SIZE=$(stat -f%z "$LATEST_BACKUP")
if [ $BACKUP_SIZE -lt 10485760 ]; then
    echo "⚠ Backup size suspiciously small"
    # Send alert
fi

echo "✓ Backup health OK"
```

### Backup Alerts

**Configure alerts for backup failures:**

```bash
# Add to crontab (check every hour)
0 * * * * /Users/gator/colima-services/scripts/check-backup-health.sh || echo "Backup health check failed" | mail -s "ALERT: Backup Issue" admin@example.com
```

### Redundancy Strategies

**Multi-layered backup strategy:**

1. **Automated daily backups** (primary)
2. **Manual weekly backups** (secondary)
3. **Offsite backups** (disaster recovery)
4. **Version control** (configurations)
5. **Database replication** (production environments)

**Geographic redundancy (production):**
- Primary datacenter: Live system
- Secondary datacenter: Replicated backups
- Cloud storage: Long-term retention

## Complete System Recovery

**Full environment rebuild from scratch:**

```bash
#!/bin/bash
# Complete system recovery

echo "=== Complete System Recovery ==="
echo "This will rebuild the entire environment from backups"

BACKUP_FILE="/Users/gator/colima-services/backups/backup_20241027_020000.tar.gz"

# 1. Extract backup
echo "Step 1: Extracting backup..."
TEMP_DIR=$(mktemp -d)
tar xzf "$BACKUP_FILE" -C "$TEMP_DIR"
BACKUP_DIR=$(find "$TEMP_DIR" -type d -name "202*" | head -1)

# 2. Stop and remove all containers/volumes
echo "Step 2: Cleaning environment..."
cd /Users/gator/colima-services
docker compose down -v

# 3. Restore Vault keys
echo "Step 3: Restoring Vault keys..."
rm -rf ~/.config/vault
cp -r "$BACKUP_DIR/vault" ~/.config/

# 4. Restore configurations
echo "Step 4: Restoring configurations..."
cp -r "$BACKUP_DIR/configs/"* /Users/gator/colima-services/configs/
cp "$BACKUP_DIR/.env" /Users/gator/colima-services/
cp "$BACKUP_DIR/docker-compose.yml" /Users/gator/colima-services/

# 5. Start Vault
echo "Step 5: Starting Vault..."
docker compose up -d vault
sleep 15

# 6. Unseal Vault
echo "Step 6: Unsealing Vault..."
./manage-colima.sh vault-status
# Vault should auto-unseal using restored keys

# 7. Start databases
echo "Step 7: Starting databases..."
docker compose up -d postgres mysql mongodb
sleep 20

# 8. Restore PostgreSQL data
echo "Step 8: Restoring PostgreSQL..."
gunzip -c "$BACKUP_DIR/postgresql_all.sql.gz" | docker exec -i dev-postgres psql -U postgres

# 9. Restore MySQL data
echo "Step 9: Restoring MySQL..."
gunzip -c "$BACKUP_DIR/mysql_all.sql.gz" | docker exec -i dev-mysql mysql -u root

# 10. Restore MongoDB data
echo "Step 10: Restoring MongoDB..."
docker cp "$BACKUP_DIR/mongodb" dev-mongodb:/tmp/
docker exec dev-mongodb mongorestore --username root --authenticationDatabase admin /tmp/mongodb

# 11. Start remaining services
echo "Step 11: Starting remaining services..."
docker compose up -d

# 12. Wait for all services
echo "Step 12: Waiting for services to stabilize..."
sleep 30

# 13. Verify recovery
echo "Step 13: Verifying recovery..."
./manage-colima.sh health

# 14. Run tests
echo "Step 14: Running tests..."
./tests/test-vault.sh
./tests/test-postgres.sh

echo "=== Recovery Complete ==="
echo "Please review logs and verify all functionality"

# Cleanup
rm -rf "$TEMP_DIR"
```

## Reference

### Related Wiki Pages

- [Backup and Restore](Backup-and-Restore) - Detailed backup procedures
- [Vault Troubleshooting](Vault-Troubleshooting) - Vault issues
- [Health Monitoring](Health-Monitoring) - Service monitoring
- [Secrets Rotation](Secrets-Rotation) - Credential rotation
- [Service Configuration](Service-Configuration) - Service details

### DR Scripts Location

```
/Users/gator/colima-services/scripts/
├── automated-backup.sh              # Daily automated backup
├── verify-backups.sh                # Backup verification
├── backup-retention.sh              # Retention policy
├── restore-from-backup.sh           # Full restore
├── restore-postgres.sh              # PostgreSQL restore
├── restore-mysql.sh                 # MySQL restore
├── restore-mongodb.sh               # MongoDB restore
├── unseal-vault.sh                  # Vault unseal
├── dr-drill.sh                      # DR drill execution
└── check-backup-health.sh           # Backup monitoring
```

### Emergency Contacts

```
Primary Contact: Dev Team Lead
  Email: lead@example.com
  Phone: +1-555-0100

Secondary Contact: Infrastructure Team
  Email: infra@example.com
  Phone: +1-555-0101

Escalation: CTO
  Email: cto@example.com
  Phone: +1-555-0102
```

### Backup Locations

```
Primary: /Users/gator/colima-services/backups/
Secondary: /Volumes/BackupDrive/colima-backups/
Offsite: s3://my-backup-bucket/colima-backups/
Vault Keys: ~/.config/vault/ (CRITICAL - always backup)
```

### Recovery Checklists

**Quick Recovery Checklist:**
- [ ] Identify disaster scenario
- [ ] Locate latest backup
- [ ] Verify backup integrity
- [ ] Stop running services
- [ ] Restore Vault keys
- [ ] Restore databases
- [ ] Start services in order
- [ ] Verify connectivity
- [ ] Run tests
- [ ] Document incident

**Complete Rebuild Checklist:**
- [ ] Extract full backup
- [ ] Restore Vault keys
- [ ] Restore configurations
- [ ] Start Vault
- [ ] Unseal Vault
- [ ] Restore databases
- [ ] Start all services
- [ ] Verify all health checks
- [ ] Run full test suite
- [ ] Update documentation

### Additional Resources

- [PostgreSQL Backup Documentation](https://www.postgresql.org/docs/current/backup.html)
- [PostgreSQL PITR](https://www.postgresql.org/docs/current/continuous-archiving.html)
- [Vault Disaster Recovery](https://www.vaultproject.io/docs/concepts/recovery)
- [Docker Volume Backup](https://docs.docker.com/storage/volumes/#backup-restore-or-migrate-data-volumes)
