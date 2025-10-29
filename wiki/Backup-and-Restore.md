# Backup and Restore

## Table of Contents

- [Overview](#overview)
- [Backup Strategy](#backup-strategy)
  - [What Gets Backed Up](#what-gets-backed-up)
  - [Backup Frequency](#backup-frequency)
  - [Backup Location](#backup-location)
- [Using manage-colima.sh backup](#using-manage-colimabackup)
  - [Basic Usage](#basic-usage)
  - [What Happens During Backup](#what-happens-during-backup)
  - [Backup Output](#backup-output)
- [Critical Files to Backup](#critical-files-to-backup)
  - [Vault Keys](#vault-keys)
  - [Configuration Files](#configuration-files)
  - [SSL Certificates](#ssl-certificates)
- [Database Backups](#database-backups)
  - [PostgreSQL Backup](#postgresql-backup)
  - [MySQL Backup](#mysql-backup)
  - [MongoDB Backup](#mongodb-backup)
- [Vault Backup](#vault-backup)
  - [Vault Data](#vault-data)
  - [Unseal Keys](#unseal-keys)
  - [Root Token](#root-token)
- [Backup Scheduling](#backup-scheduling)
  - [Automated Backups with Cron](#automated-backups-with-cron)
  - [Backup Retention Policy](#backup-retention-policy)
  - [Backup Verification](#backup-verification)
- [Restore Procedures](#restore-procedures)
  - [PostgreSQL Restore](#postgresql-restore)
  - [MySQL Restore](#mysql-restore)
  - [MongoDB Restore](#mongodb-restore)
  - [Vault Restore](#vault-restore)
  - [Full Environment Restore](#full-environment-restore)
- [Disaster Recovery](#disaster-recovery)
  - [Recovery Scenarios](#recovery-scenarios)
  - [Recovery Time Objectives](#recovery-time-objectives)
  - [Recovery Point Objectives](#recovery-point-objectives)
- [Testing Backups](#testing-backups)
  - [Test Restore Procedure](#test-restore-procedure)
  - [Validation Checklist](#validation-checklist)
- [Offsite Backup Storage](#offsite-backup-storage)
  - [Cloud Storage Options](#cloud-storage-options)
  - [Automated Upload](#automated-upload)
  - [Encryption](#encryption)
- [Troubleshooting](#troubleshooting)
- [Related Pages](#related-pages)

## Overview

Regular backups are essential for protecting your development environment data. The colima-services environment provides automated backup capabilities for all stateful services.

**Backup Philosophy:**
- Automated daily backups
- Multiple restore points
- Offsite storage for disaster recovery
- Regular backup testing
- Encrypted backups for sensitive data

**Key Components:**
- Database dumps (PostgreSQL, MySQL, MongoDB)
- Vault keys and data
- Configuration files
- SSL certificates
- Docker volumes

## Backup Strategy

### What Gets Backed Up

The backup system covers all stateful data:

**Databases:**
- PostgreSQL - All databases including Forgejo
- MySQL - All databases and tables
- MongoDB - All databases and collections

**Vault:**
- Unseal keys (critical!)
- Root token
- All secrets stored in Vault
- PKI certificates and keys

**Configuration:**
- .env file
- Service configuration files
- docker-compose.yml
- Custom scripts

**Certificates:**
- CA certificates
- Service certificates
- Private keys

### Backup Frequency

**Recommended Schedule:**

```bash
# Daily backups at 2 AM
0 2 * * * /path/to/colima-services/manage-colima.sh backup

# Weekly full backups (Sunday 3 AM)
0 3 * * 0 /path/to/colima-services/scripts/full-backup.sh

# Pre-upgrade backups (manual)
./manage-colima.sh backup
```

**Retention Policy:**
- Daily backups: Keep 7 days
- Weekly backups: Keep 4 weeks
- Monthly backups: Keep 12 months
- Pre-upgrade backups: Keep until verified

### Backup Location

Default backup location:

```bash
~/colima-services/backups/
├── 2024-01-15_02-00-00/
│   ├── postgres_devdb.sql
│   ├── mysql_devdb.sql
│   ├── mongodb_devdb.archive
│   └── vault_snapshot.json
├── 2024-01-16_02-00-00/
└── latest -> 2024-01-16_02-00-00/
```

**Configure backup location in .env:**

```bash
BACKUP_DIR=/path/to/backups
```

## Using manage-colima.sh backup

### Basic Usage

```bash
# Create backup of all services
./manage-colima.sh backup

# Create backup with custom name
./manage-colima.sh backup pre-upgrade

# Create backup and compress
COMPRESS=true ./manage-colima.sh backup
```

### What Happens During Backup

The backup process performs these steps:

1. **Create backup directory** with timestamp
2. **Dump PostgreSQL databases**
   - Forgejo database
   - Development databases
   - Schema and data
3. **Dump MySQL databases**
   - All user databases
   - Grants and users
4. **Dump MongoDB databases**
   - All databases
   - Binary format for fast restore
5. **Export Vault data**
   - Vault snapshot
   - Copy unseal keys
   - Copy root token
6. **Copy certificates**
   - CA certificates
   - Service certificates
7. **Copy configuration**
   - .env file
   - docker-compose.yml
8. **Create manifest**
   - Backup metadata
   - File checksums
   - Service versions

### Backup Output

```bash
$ ./manage-colima.sh backup

=== Colima Services Backup ===
Backup directory: /Users/user/colima-services/backups/2024-01-15_14-30-00

[1/8] Backing up PostgreSQL...
  ✓ Database: devdb (1.2 MB)
  ✓ Database: forgejo (4.5 MB)

[2/8] Backing up MySQL...
  ✓ Database: devdb (890 KB)

[3/8] Backing up MongoDB...
  ✓ Database: devdb (2.3 MB)

[4/8] Backing up Vault...
  ✓ Vault snapshot (156 KB)
  ✓ Unseal keys copied
  ✓ Root token copied

[5/8] Backing up certificates...
  ✓ CA certificates
  ✓ Service certificates (7 services)

[6/8] Backing up configuration...
  ✓ .env file
  ✓ docker-compose.yml
  ✓ Service configs

[7/8] Creating manifest...
  ✓ Checksums calculated
  ✓ Metadata saved

[8/8] Compressing backup...
  ✓ Archive: backup-2024-01-15_14-30-00.tar.gz (9.2 MB)

Backup completed successfully!
Location: /Users/user/colima-services/backups/2024-01-15_14-30-00
Archive: /Users/user/colima-services/backups/backup-2024-01-15_14-30-00.tar.gz
```

## Critical Files to Backup

### Vault Keys

**CRITICAL - Without these, Vault data cannot be recovered!**

```bash
# Backup Vault keys (do this manually!)
mkdir -p ~/vault-backups
cp -r ~/.config/vault/ ~/vault-backups/vault-$(date +%Y%m%d)

# Copy to external drive
cp -r ~/.config/vault/ /Volumes/External/vault-backup/

# Upload to cloud (encrypted)
tar czf - ~/.config/vault/ | \
  openssl enc -aes-256-cbc -salt -pbkdf2 -out vault-backup.tar.gz.enc
```

**Files to backup:**
- `~/.config/vault/keys.json` - Unseal keys (5 keys, threshold 3)
- `~/.config/vault/root-token` - Root token for full access
- `~/.config/vault/ca/` - CA certificates
- `~/.config/vault/certs/` - Service certificates

### Configuration Files

```bash
# Essential configuration files
~/colima-services/.env
~/colima-services/docker-compose.yml
~/colima-services/configs/
```

### SSL Certificates

```bash
# CA certificates
~/.config/vault/ca/ca.pem
~/.config/vault/ca/ca-chain.pem

# Service certificates (regenerate from Vault if lost)
~/.config/vault/certs/postgres/
~/.config/vault/certs/mysql/
~/.config/vault/certs/redis-1/
# ... etc
```

## Database Backups

### PostgreSQL Backup

**Automated via backup script:**

```bash
# Backup all databases
docker exec dev-postgres pg_dumpall -U postgres > backups/postgres_all.sql

# Backup specific database
docker exec dev-postgres pg_dump -U postgres devdb > backups/postgres_devdb.sql

# Backup with custom format (faster restore)
docker exec dev-postgres pg_dump -U postgres -Fc devdb > backups/postgres_devdb.dump

# Backup schema only
docker exec dev-postgres pg_dump -U postgres --schema-only devdb > backups/postgres_schema.sql

# Backup data only
docker exec dev-postgres pg_dump -U postgres --data-only devdb > backups/postgres_data.sql
```

**Backup specific tables:**

```bash
# Backup single table
docker exec dev-postgres pg_dump -U postgres -t users devdb > backups/users_table.sql

# Backup multiple tables
docker exec dev-postgres pg_dump -U postgres -t users -t orders devdb > backups/tables.sql
```

### MySQL Backup

```bash
# Backup all databases
docker exec dev-mysql mysqldump -u root -p --all-databases > backups/mysql_all.sql

# Backup specific database
docker exec dev-mysql mysqldump -u root -p devdb > backups/mysql_devdb.sql

# Backup with single transaction (for InnoDB)
docker exec dev-mysql mysqldump -u root -p --single-transaction devdb > backups/mysql_devdb.sql

# Backup schema only
docker exec dev-mysql mysqldump -u root -p --no-data devdb > backups/mysql_schema.sql

# Backup with compression
docker exec dev-mysql mysqldump -u root -p devdb | gzip > backups/mysql_devdb.sql.gz
```

### MongoDB Backup

```bash
# Backup all databases
docker exec dev-mongodb mongodump --out=/backup/
docker cp dev-mongodb:/backup/ ./backups/mongodb/

# Backup specific database
docker exec dev-mongodb mongodump --db=devdb --out=/backup/
docker cp dev-mongodb:/backup/devdb/ ./backups/mongodb/devdb/

# Backup with authentication
docker exec dev-mongodb mongodump \
  -u devuser -p password --authenticationDatabase admin \
  --db=devdb --out=/backup/

# Backup to archive (compressed)
docker exec dev-mongodb mongodump \
  --db=devdb --archive=/backup/devdb.archive --gzip
docker cp dev-mongodb:/backup/devdb.archive ./backups/
```

## Vault Backup

### Vault Data

```bash
# Take Vault snapshot (requires Vault Enterprise for automated snapshots)
docker exec dev-vault vault operator raft snapshot save /tmp/vault-snapshot.snap
docker cp dev-vault:/tmp/vault-snapshot.snap ./backups/

# For file backend, backup data directory
docker cp dev-vault:/vault/data ./backups/vault-data/

# Export all secrets (alternative method)
./scripts/export-vault-secrets.sh > backups/vault-secrets.json
```

**Export script example:**

```bash
#!/bin/bash
# scripts/export-vault-secrets.sh

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# List all secrets
SECRET_PATHS=$(vault kv list -format=json secret/ | jq -r '.[]')

# Export each secret
echo "{"
first=true
for path in $SECRET_PATHS; do
  if [ "$first" = false ]; then echo ","; fi
  first=false

  echo "  \"$path\": $(vault kv get -format=json secret/$path | jq '.data.data')"
done
echo "}"
```

### Unseal Keys

```bash
# Backup unseal keys (CRITICAL!)
cp ~/.config/vault/keys.json ~/vault-backups/keys-$(date +%Y%m%d).json

# Verify backup
cat ~/vault-backups/keys-$(date +%Y%m%d).json | jq '.unseal_keys_b64 | length'
# Should output: 5
```

### Root Token

```bash
# Backup root token
cp ~/.config/vault/root-token ~/vault-backups/root-token-$(date +%Y%m%d)

# Verify token works
export VAULT_TOKEN=$(cat ~/vault-backups/root-token-$(date +%Y%m%d))
vault token lookup
```

## Backup Scheduling

### Automated Backups with Cron

**Create backup script:** `scripts/automated-backup.sh`

```bash
#!/bin/bash
set -e

BACKUP_DIR="/Users/user/colima-services/backups"
RETENTION_DAYS=7

# Change to project directory
cd /Users/user/colima-services

# Create backup
./manage-colima.sh backup

# Remove old backups
find $BACKUP_DIR -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;

# Compress and upload to cloud (optional)
LATEST=$(readlink $BACKUP_DIR/latest)
tar czf $BACKUP_DIR/$(basename $LATEST).tar.gz $BACKUP_DIR/$LATEST

# Upload to S3 (requires awscli)
aws s3 cp $BACKUP_DIR/$(basename $LATEST).tar.gz s3://my-backups/colima-services/

# Clean up compressed file
rm $BACKUP_DIR/$(basename $LATEST).tar.gz

# Log completion
echo "$(date): Backup completed successfully" >> /var/log/colima-backup.log
```

**Schedule with cron:**

```bash
crontab -e

# Add these lines:

# Daily backup at 2 AM
0 2 * * * /Users/user/colima-services/scripts/automated-backup.sh >> /var/log/colima-backup.log 2>&1

# Weekly full backup at 3 AM on Sunday
0 3 * * 0 /Users/user/colima-services/scripts/full-backup.sh >> /var/log/colima-backup.log 2>&1

# Monthly backup on 1st of month
0 4 1 * * /Users/user/colima-services/scripts/monthly-backup.sh >> /var/log/colima-backup.log 2>&1
```

### Backup Retention Policy

**Implement retention policy:**

```bash
#!/bin/bash
# scripts/cleanup-old-backups.sh

BACKUP_DIR="/Users/user/colima-services/backups"

# Keep daily backups for 7 days
find $BACKUP_DIR -type d -name "20*" -mtime +7 -exec rm -rf {} \;

# Keep weekly backups for 4 weeks
find $BACKUP_DIR/weekly -type d -mtime +28 -exec rm -rf {} \;

# Keep monthly backups for 12 months
find $BACKUP_DIR/monthly -type d -mtime +365 -exec rm -rf {} \;

# Log retention cleanup
echo "$(date): Cleaned up old backups" >> /var/log/backup-retention.log
```

### Backup Verification

**Verify backups are valid:**

```bash
#!/bin/bash
# scripts/verify-backup.sh

BACKUP_DIR=$1

# Check PostgreSQL dump
echo "Verifying PostgreSQL backup..."
pg_restore --list $BACKUP_DIR/postgres_devdb.dump > /dev/null
if [ $? -eq 0 ]; then
  echo "✓ PostgreSQL backup valid"
else
  echo "✗ PostgreSQL backup INVALID"
  exit 1
fi

# Check MySQL dump
echo "Verifying MySQL backup..."
if grep -q "Dump completed" $BACKUP_DIR/mysql_devdb.sql; then
  echo "✓ MySQL backup valid"
else
  echo "✗ MySQL backup INVALID"
  exit 1
fi

# Check MongoDB dump
echo "Verifying MongoDB backup..."
if [ -f $BACKUP_DIR/mongodb_devdb.archive ]; then
  echo "✓ MongoDB backup exists"
else
  echo "✗ MongoDB backup MISSING"
  exit 1
fi

# Check Vault keys
echo "Verifying Vault keys..."
if [ -f $BACKUP_DIR/vault/keys.json ]; then
  KEYS=$(jq '.unseal_keys_b64 | length' < $BACKUP_DIR/vault/keys.json)
  if [ "$KEYS" -eq 5 ]; then
    echo "✓ Vault keys valid (5 keys)"
  else
    echo "✗ Vault keys INVALID (expected 5, found $KEYS)"
    exit 1
  fi
fi

echo "All backups verified successfully!"
```

## Restore Procedures

### PostgreSQL Restore

```bash
# Stop services
docker compose stop

# Restore all databases
cat backups/postgres_all.sql | docker exec -i dev-postgres psql -U postgres

# Restore specific database
docker exec -i dev-postgres psql -U postgres -d devdb < backups/postgres_devdb.sql

# Restore from custom format
docker exec -i dev-postgres pg_restore -U postgres -d devdb < backups/postgres_devdb.dump

# Restore and drop existing database first
docker exec dev-postgres psql -U postgres -c "DROP DATABASE IF EXISTS devdb;"
docker exec dev-postgres psql -U postgres -c "CREATE DATABASE devdb;"
docker exec -i dev-postgres psql -U postgres -d devdb < backups/postgres_devdb.sql

# Verify restore
docker exec dev-postgres psql -U postgres -d devdb -c "\dt"
```

### MySQL Restore

```bash
# Restore all databases
cat backups/mysql_all.sql | docker exec -i dev-mysql mysql -u root -p

# Restore specific database
docker exec -i dev-mysql mysql -u root -p devdb < backups/mysql_devdb.sql

# Restore from compressed backup
gunzip < backups/mysql_devdb.sql.gz | docker exec -i dev-mysql mysql -u root -p devdb

# Drop and recreate database
docker exec dev-mysql mysql -u root -p -e "DROP DATABASE IF EXISTS devdb;"
docker exec dev-mysql mysql -u root -p -e "CREATE DATABASE devdb;"
docker exec -i dev-mysql mysql -u root -p devdb < backups/mysql_devdb.sql

# Verify restore
docker exec dev-mysql mysql -u root -p -e "SHOW TABLES;" devdb
```

### MongoDB Restore

```bash
# Copy backup into container
docker cp backups/mongodb/ dev-mongodb:/backup/

# Restore all databases
docker exec dev-mongodb mongorestore /backup/

# Restore specific database
docker exec dev-mongodb mongorestore --db=devdb /backup/devdb/

# Restore with drop (replace existing)
docker exec dev-mongodb mongorestore --drop --db=devdb /backup/devdb/

# Restore from archive
docker cp backups/devdb.archive dev-mongodb:/backup/
docker exec dev-mongodb mongorestore --archive=/backup/devdb.archive --gzip

# Verify restore
docker exec dev-mongodb mongosh --eval "show dbs"
docker exec dev-mongodb mongosh devdb --eval "db.getCollectionNames()"
```

### Vault Restore

```bash
# Stop Vault
docker compose stop vault

# Restore Vault data directory
docker cp backups/vault-data/ dev-vault:/vault/data/

# Restore unseal keys
cp backups/vault/keys.json ~/.config/vault/

# Restore root token
cp backups/vault/root-token ~/.config/vault/

# Start Vault
docker compose up -d vault

# Wait for Vault to start
sleep 5

# Unseal Vault
export VAULT_ADDR=http://localhost:8200
for i in 0 1 2; do
  UNSEAL_KEY=$(jq -r ".unseal_keys_b64[$i]" < ~/.config/vault/keys.json)
  vault operator unseal $UNSEAL_KEY
done

# Verify restore
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)
vault kv list secret/
```

### Full Environment Restore

```bash
#!/bin/bash
# scripts/full-restore.sh

BACKUP_DIR=$1

if [ -z "$BACKUP_DIR" ]; then
  echo "Usage: $0 <backup-directory>"
  exit 1
fi

echo "=== Full Environment Restore ==="
echo "Backup: $BACKUP_DIR"
echo "WARNING: This will replace all data!"
read -p "Continue? (yes/no) " confirm

if [ "$confirm" != "yes" ]; then
  echo "Restore cancelled"
  exit 0
fi

# Stop all services
echo "Stopping services..."
docker compose down

# Restore Vault (must be first)
echo "Restoring Vault..."
cp -r $BACKUP_DIR/vault/* ~/.config/vault/

# Start Vault
docker compose up -d vault
sleep 10

# Restore databases
echo "Restoring PostgreSQL..."
docker compose up -d postgres
sleep 5
cat $BACKUP_DIR/postgres_*.sql | docker exec -i dev-postgres psql -U postgres

echo "Restoring MySQL..."
docker compose up -d mysql
sleep 5
cat $BACKUP_DIR/mysql_*.sql | docker exec -i dev-mysql mysql -u root -p

echo "Restoring MongoDB..."
docker compose up -d mongodb
sleep 5
docker cp $BACKUP_DIR/mongodb/ dev-mongodb:/backup/
docker exec dev-mongodb mongorestore /backup/

# Start remaining services
echo "Starting all services..."
docker compose up -d

echo "Restore completed! Verifying..."
./manage-colima.sh health
```

## Disaster Recovery

### Recovery Scenarios

**Scenario 1: Lost Vault Keys**

If Vault keys are lost, Vault data CANNOT be recovered. Prevention is critical:

```bash
# Immediate backup after initialization
./manage-colima.sh vault-init
cp -r ~/.config/vault/ ~/vault-backup-CRITICAL-$(date +%Y%m%d)/

# Store in multiple locations
cp -r ~/.config/vault/ /Volumes/External/vault-backup/
# Upload to encrypted cloud storage
```

**Scenario 2: Corrupted Database**

```bash
# Stop affected service
docker compose stop postgres

# Restore from last backup
./scripts/full-restore.sh backups/latest/

# If recent backup unavailable, try transaction log recovery
# (PostgreSQL example)
docker exec dev-postgres pg_waldump /var/lib/postgresql/data/pg_wal/
```

**Scenario 3: Complete System Loss**

```bash
# Prerequisites: Offsite backups available

# 1. Reinstall Colima
./manage-colima.sh reset
./manage-colima.sh start

# 2. Restore from offsite backup
aws s3 cp s3://my-backups/colima-services/latest.tar.gz ./
tar xzf latest.tar.gz

# 3. Run full restore
./scripts/full-restore.sh backups/latest/

# 4. Verify all services
./manage-colima.sh health
./tests/run-all-tests.sh
```

### Recovery Time Objectives

**RTO (Recovery Time Objective) - Target restore time:**

- Vault: 5 minutes
- PostgreSQL: 10 minutes (per GB)
- MySQL: 15 minutes (per GB)
- MongoDB: 20 minutes (per GB)
- Full environment: 1 hour

**Factors affecting RTO:**
- Backup size
- Network speed (for offsite restore)
- Disk I/O performance
- Database complexity

### Recovery Point Objectives

**RPO (Recovery Point Objective) - Maximum acceptable data loss:**

- Development environment: 24 hours (daily backups)
- Production (if deployed): 1 hour (continuous replication)

**Minimize RPO:**
```bash
# Increase backup frequency
# Cron: Every 4 hours
0 */4 * * * /path/to/backup-script.sh

# Enable WAL archiving (PostgreSQL)
# In postgresql.conf:
wal_level = replica
archive_mode = on
archive_command = 'cp %p /backup/wal/%f'
```

## Testing Backups

### Test Restore Procedure

**Monthly backup test routine:**

```bash
#!/bin/bash
# scripts/test-restore.sh

# Create test environment
export COMPOSE_PROJECT_NAME=test-restore
docker compose -f docker-compose.test.yml up -d

# Wait for services
sleep 30

# Restore latest backup
./scripts/full-restore.sh backups/latest/

# Run validation tests
./tests/run-all-tests.sh

# Compare data checksums
docker exec test-postgres psql -U postgres -d devdb -c "SELECT COUNT(*) FROM users;"
# Compare with production count

# Cleanup test environment
docker compose -f docker-compose.test.yml down -v

echo "Backup test completed successfully!"
```

### Validation Checklist

After restore, verify:

- [ ] All services start successfully
- [ ] Health checks pass
- [ ] Database connections work
- [ ] Data integrity (record counts match)
- [ ] Vault unsealed and accessible
- [ ] Certificates valid
- [ ] Applications function correctly
- [ ] Test suites pass

```bash
# Automated validation
./manage-colima.sh health
./tests/run-all-tests.sh
docker exec dev-postgres psql -U postgres -c "SELECT COUNT(*) FROM pg_database;"
vault status
curl -f http://localhost:8000/health
```

## Offsite Backup Storage

### Cloud Storage Options

**AWS S3:**

```bash
# Install AWS CLI
brew install awscli

# Configure credentials
aws configure

# Upload backup
aws s3 cp backups/latest.tar.gz s3://my-backups/colima-services/backup-$(date +%Y%m%d).tar.gz

# Download backup
aws s3 cp s3://my-backups/colima-services/backup-20240115.tar.gz ./
```

**Google Cloud Storage:**

```bash
# Install gsutil
brew install google-cloud-sdk

# Authenticate
gcloud auth login

# Upload backup
gsutil cp backups/latest.tar.gz gs://my-backups/colima-services/
```

**Backblaze B2:**

```bash
# Install B2 CLI
brew install b2-tools

# Authenticate
b2 authorize-account <key-id> <app-key>

# Upload backup
b2 upload-file my-bucket backups/latest.tar.gz backup-$(date +%Y%m%d).tar.gz
```

### Automated Upload

```bash
#!/bin/bash
# scripts/upload-backup.sh

BACKUP_FILE=$1
CLOUD_PROVIDER=${CLOUD_PROVIDER:-s3}

case $CLOUD_PROVIDER in
  s3)
    aws s3 cp $BACKUP_FILE s3://my-backups/colima-services/
    ;;
  gcs)
    gsutil cp $BACKUP_FILE gs://my-backups/colima-services/
    ;;
  b2)
    b2 upload-file my-bucket $BACKUP_FILE $(basename $BACKUP_FILE)
    ;;
  *)
    echo "Unknown cloud provider: $CLOUD_PROVIDER"
    exit 1
    ;;
esac

echo "Backup uploaded successfully to $CLOUD_PROVIDER"
```

### Encryption

**Encrypt backups before upload:**

```bash
# Encrypt with OpenSSL
tar czf - backups/latest/ | \
  openssl enc -aes-256-cbc -salt -pbkdf2 \
  -out backup-$(date +%Y%m%d).tar.gz.enc

# Upload encrypted backup
aws s3 cp backup-$(date +%Y%m%d).tar.gz.enc s3://my-backups/

# Decrypt and restore
openssl enc -aes-256-cbc -d -pbkdf2 \
  -in backup-20240115.tar.gz.enc | tar xzf -
```

**Encrypt with GPG:**

```bash
# Generate GPG key (one-time)
gpg --gen-key

# Encrypt backup
tar czf - backups/latest/ | gpg -e -r your@email.com > backup.tar.gz.gpg

# Decrypt backup
gpg -d backup.tar.gz.gpg | tar xzf -
```

## Troubleshooting

**Backup fails with "No space left on device":**

```bash
# Check disk space
df -h

# Clean up old backups
find backups/ -type d -mtime +7 -exec rm -rf {} \;

# Change backup location
export BACKUP_DIR=/Volumes/External/backups
```

**Restore fails with "Permission denied":**

```bash
# Fix permissions on backup files
chmod -R 644 backups/latest/*
chmod 755 backups/latest/

# Run restore as correct user
sudo -u postgres ./scripts/restore-postgres.sh
```

**Vault restore fails "already initialized":**

```bash
# Vault is already initialized, need to reset
docker compose down vault
docker volume rm colima-services_vault-data
docker compose up -d vault

# Then restore
./scripts/restore-vault.sh backups/latest/
```

## Related Pages

- [CLI-Reference](CLI-Reference) - Management script commands
- [Vault-Troubleshooting](Vault-Troubleshooting) - Vault-specific issues
- [Service-Configuration](Service-Configuration) - Service configuration
- [Health-Monitoring](Health-Monitoring) - Monitoring and health checks
- [Disaster Recovery](Migration-Guide) - Migration and recovery procedures
