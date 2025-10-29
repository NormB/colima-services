# Volume Management

Comprehensive guide to Docker volume management and data persistence in the Colima Services environment.

## Table of Contents

- [Overview](#overview)
- [Quick Reference](#quick-reference)
- [Volume Types](#volume-types)
  - [Named Volumes](#named-volumes)
  - [Bind Mounts](#bind-mounts)
  - [tmpfs Mounts](#tmpfs-mounts)
  - [Volume Comparison](#volume-comparison)
- [Volume Lifecycle](#volume-lifecycle)
  - [Creating Volumes](#creating-volumes)
  - [Listing Volumes](#listing-volumes)
  - [Inspecting Volumes](#inspecting-volumes)
  - [Removing Volumes](#removing-volumes)
- [Volume Backup](#volume-backup)
  - [Backup Strategies](#backup-strategies)
  - [Backing Up Volumes](#backing-up-volumes)
  - [Backup Verification](#backup-verification)
  - [Automated Backups](#automated-backups)
- [Volume Restore](#volume-restore)
  - [Restoring from Backup](#restoring-from-backup)
  - [Volume Migration](#volume-migration)
  - [Point-in-Time Recovery](#point-in-time-recovery)
- [Volume Inspection](#volume-inspection)
  - [Finding Volumes](#finding-volumes)
  - [Disk Usage](#disk-usage)
  - [Volume Contents](#volume-contents)
  - [Volume Dependencies](#volume-dependencies)
- [Volume Cleanup](#volume-cleanup)
  - [Removing Unused Volumes](#removing-unused-volumes)
  - [Pruning Volumes](#pruning-volumes)
  - [Space Reclamation](#space-reclamation)
- [Data Persistence](#data-persistence)
  - [Understanding Persistence](#understanding-persistence)
  - [Volume Locations](#volume-locations)
  - [Data Durability](#data-durability)
  - [Backup Importance](#backup-importance)
- [Volume Troubleshooting](#volume-troubleshooting)
  - [Permission Issues](#permission-issues)
  - [Disk Full](#disk-full)
  - [Corrupted Data](#corrupted-data)
  - [Mount Failures](#mount-failures)
- [Best Practices](#best-practices)
  - [Naming Conventions](#naming-conventions)
  - [Backup Schedules](#backup-schedules)
  - [Monitoring](#monitoring)
  - [Security](#security)
- [Service-Specific Volumes](#service-specific-volumes)
  - [PostgreSQL Volumes](#postgresql-volumes)
  - [MySQL Volumes](#mysql-volumes)
  - [MongoDB Volumes](#mongodb-volumes)
  - [Redis Volumes](#redis-volumes)
  - [Vault Volumes](#vault-volumes)
  - [Grafana Volumes](#grafana-volumes)
- [Related Documentation](#related-documentation)

## Overview

Docker volumes provide persistent data storage for containers. In Colima Services, volumes store all database data, configurations, and state.

**Volume Infrastructure:**
- **Type**: Named Docker volumes (managed by Docker)
- **Location**: Inside Colima VM at `/var/lib/docker/volumes/`
- **Persistence**: Survives container removal
- **Backup**: Manual via docker commands or scripts

**⚠️ WARNING:** Data in volumes is critical. Regular backups are essential to prevent data loss.

## Quick Reference

```bash
# List volumes
docker volume ls

# Create volume
docker volume create myvolume

# Inspect volume
docker volume inspect postgres-data

# Remove volume
docker volume rm myvolume

# Prune unused volumes
docker volume prune

# Backup volume
docker run --rm -v postgres-data:/data -v $(pwd):/backup alpine tar czf /backup/postgres-data.tar.gz -C /data .

# Restore volume
docker run --rm -v postgres-data:/data -v $(pwd):/backup alpine tar xzf /backup/postgres-data.tar.gz -C /data

# Check volume size
docker system df -v

# Find volume location
docker volume inspect postgres-data -f '{{.Mountpoint}}'
```

## Volume Types

### Named Volumes

Named volumes are managed by Docker and referenced by name:

```bash
# Create named volume
docker volume create postgres-data

# Use in docker run
docker run -d -v postgres-data:/var/lib/postgresql/data postgres:16

# Use in docker-compose.yml
services:
  postgres:
    volumes:
      - postgres-data:/var/lib/postgresql/data

volumes:
  postgres-data:
    driver: local
```

**Advantages:**
- Easy to reference by name
- Managed by Docker
- Portable across containers
- Easy to backup/restore

**Disadvantages:**
- Less direct access from host
- Harder to browse contents

### Bind Mounts

Bind mounts link host directories to containers:

```bash
# Use in docker run
docker run -d -v /path/on/host:/path/in/container postgres:16

# Use in docker-compose.yml
services:
  postgres:
    volumes:
      - ./configs/postgres:/etc/postgresql:ro
      - /Users/gator/data:/var/lib/postgresql/data
```

**Advantages:**
- Direct access from host
- Easy to browse and edit
- Good for configs and code

**Disadvantages:**
- Path must exist on host
- Not portable across systems
- Permission issues possible

### tmpfs Mounts

tmpfs mounts store data in memory:

```bash
# Use in docker run
docker run -d --tmpfs /tmp:rw,size=100m postgres:16

# Use in docker-compose.yml
services:
  postgres:
    tmpfs:
      - /tmp:rw,size=100m
```

**Advantages:**
- Very fast (in memory)
- Automatic cleanup on stop
- Good for temporary data

**Disadvantages:**
- Data lost on container stop
- Uses system memory
- Size limited by available RAM

### Volume Comparison

| Feature | Named Volumes | Bind Mounts | tmpfs |
|---------|---------------|-------------|-------|
| **Persistence** | Yes | Yes | No (lost on stop) |
| **Management** | Docker managed | User managed | Docker managed |
| **Performance** | Good | Good | Excellent |
| **Host Access** | Difficult | Easy | No |
| **Portability** | Excellent | Poor | Excellent |
| **Best For** | Databases, state | Configs, code | Temp files, cache |

## Volume Lifecycle

### Creating Volumes

```bash
# Create basic volume
docker volume create myvolume

# Create with driver options
docker volume create --driver local myvolume

# Create with labels
docker volume create --label env=dev --label app=postgres postgres-data

# Create multiple volumes
for vol in postgres-data mysql-data mongodb-data; do
  docker volume create $vol
done

# Docker Compose creates volumes automatically
docker compose up -d
# Creates volumes defined in docker-compose.yml
```

Volume creation in docker-compose.yml:

```yaml
volumes:
  postgres-data:
    driver: local
    driver_opts:
      type: none
      device: /path/to/data
      o: bind

  mysql-data:
    driver: local
    labels:
      env: development
      backup: daily

  redis-data:
    external: true  # Use existing volume
```

### Listing Volumes

```bash
# List all volumes
docker volume ls

# List with filter
docker volume ls --filter dangling=true
docker volume ls --filter label=env=dev
docker volume ls --filter driver=local

# List with format
docker volume ls --format "table {{.Name}}\t{{.Driver}}\t{{.Mountpoint}}"

# List volumes for specific service
docker compose config | grep -A 5 "volumes:"

# Show volume sizes
docker system df -v

# List volumes and their containers
for vol in $(docker volume ls -q); do
  echo "Volume: $vol"
  docker ps -a --filter volume=$vol --format "  {{.Names}}"
done
```

### Inspecting Volumes

```bash
# Inspect volume
docker volume inspect postgres-data

# Get specific field
docker volume inspect postgres-data -f '{{.Mountpoint}}'
docker volume inspect postgres-data -f '{{.Driver}}'
docker volume inspect postgres-data -f '{{.CreatedAt}}'

# Pretty print JSON
docker volume inspect postgres-data | jq

# Check volume size
docker system df -v | grep postgres-data

# List volume contents (requires accessing Colima VM)
docker run --rm -v postgres-data:/data alpine ls -lah /data

# Count files in volume
docker run --rm -v postgres-data:/data alpine find /data -type f | wc -l

# Get volume usage
docker run --rm -v postgres-data:/data alpine du -sh /data
```

### Removing Volumes

```bash
# Remove single volume
docker volume rm myvolume

# Remove multiple volumes
docker volume rm postgres-data mysql-data

# Remove all volumes (⚠️ dangerous!)
docker volume rm $(docker volume ls -q)

# Remove volume only if not in use
docker volume rm postgres-data
# Error if container is using it

# Force remove (stop container first)
docker compose down
docker volume rm postgres-data

# Remove volumes when removing containers
docker compose down -v

# Remove unused volumes
docker volume prune
```

**⚠️ WARNING:** Removing a volume permanently deletes all data. Always backup first!

## Volume Backup

### Backup Strategies

**1. Volume Tar Archive (Simple)**
```bash
# Pros: Simple, portable, cross-platform
# Cons: Requires downtime, slower for large volumes
docker run --rm -v myvolume:/data -v $(pwd):/backup alpine tar czf /backup/myvolume.tar.gz -C /data .
```

**2. Database Dump (Recommended)**
```bash
# Pros: Consistent, portable, cross-version
# Cons: Database-specific commands
docker exec postgres pg_dump -U postgres myapp > backup.sql
```

**3. Filesystem Snapshot (Advanced)**
```bash
# Pros: Fast, consistent, space-efficient
# Cons: Requires filesystem support (ZFS, BTRFS)
# Not available in default Colima setup
```

**4. Continuous Replication (Production)**
```bash
# Pros: Real-time, disaster recovery
# Cons: Complex setup, resource intensive
# Not configured in dev environment
```

### Backing Up Volumes

**PostgreSQL backup:**

```bash
# Method 1: Using pg_dump (recommended)
docker exec postgres pg_dump -U postgres myapp > myapp_$(date +%Y%m%d_%H%M%S).sql

# All databases
docker exec postgres pg_dumpall -U postgres > all_databases_$(date +%Y%m%d_%H%M%S).sql

# With compression
docker exec postgres pg_dump -U postgres myapp | gzip > myapp_$(date +%Y%m%d_%H%M%S).sql.gz

# Method 2: Volume tar backup
docker compose stop postgres
docker run --rm -v postgres-data:/data -v $(pwd)/backups:/backup alpine tar czf /backup/postgres-data-$(date +%Y%m%d_%H%M%S).tar.gz -C /data .
docker compose start postgres
```

**MySQL backup:**

```bash
# Method 1: Using mysqldump (recommended)
docker exec mysql mysqldump -u root -p myapp > myapp_$(date +%Y%m%d_%H%M%S).sql

# All databases
docker exec mysql mysqldump -u root -p --all-databases > all_databases_$(date +%Y%m%d_%H%M%S).sql

# Method 2: Volume tar backup
docker compose stop mysql
docker run --rm -v mysql-data:/data -v $(pwd)/backups:/backup alpine tar czf /backup/mysql-data-$(date +%Y%m%d_%H%M%S).tar.gz -C /data .
docker compose start mysql
```

**MongoDB backup:**

```bash
# Method 1: Using mongodump (recommended)
docker exec mongodb mongodump --db=myapp --out=/tmp/backup
docker cp mongodb:/tmp/backup ./backups/mongodb-$(date +%Y%m%d_%H%M%S)
docker exec mongodb rm -rf /tmp/backup

# Method 2: Volume tar backup
docker compose stop mongodb
docker run --rm -v mongodb-data:/data -v $(pwd)/backups:/backup alpine tar czf /backup/mongodb-data-$(date +%Y%m%d_%H%M%S).tar.gz -C /data .
docker compose start mongodb
```

**Redis backup:**

```bash
# Method 1: RDB snapshot (automatic)
docker exec redis-1 redis-cli SAVE
docker cp redis-1:/data/dump.rdb ./backups/redis-dump-$(date +%Y%m%d_%H%M%S).rdb

# Method 2: Volume tar backup
docker compose stop redis-1
docker run --rm -v redis-data:/data -v $(pwd)/backups:/backup alpine tar czf /backup/redis-data-$(date +%Y%m%d_%H%M%S).tar.gz -C /data .
docker compose start redis-1
```

**Vault backup:**

```bash
# Method 1: Vault snapshot (recommended)
docker exec vault vault operator raft snapshot save /tmp/vault-snapshot
docker cp vault:/tmp/vault-snapshot ./backups/vault-snapshot-$(date +%Y%m%d_%H%M%S)
docker exec vault rm /tmp/vault-snapshot

# Method 2: Volume tar backup
docker compose stop vault
docker run --rm -v vault-file:/data -v $(pwd)/backups:/backup alpine tar czf /backup/vault-data-$(date +%Y%m%d_%H%M%S).tar.gz -C /data .
docker compose start vault

# IMPORTANT: Also backup unseal keys and root token
cp -r ~/.config/vault ~/vault-keys-backup-$(date +%Y%m%d_%H%M%S)
```

**Generic volume backup:**

```bash
# Backup any volume
VOLUME_NAME=myvolume
BACKUP_DIR=$(pwd)/backups
mkdir -p $BACKUP_DIR

docker run --rm \
  -v ${VOLUME_NAME}:/data \
  -v ${BACKUP_DIR}:/backup \
  alpine tar czf /backup/${VOLUME_NAME}-$(date +%Y%m%d_%H%M%S).tar.gz -C /data .

echo "Backup saved to: ${BACKUP_DIR}/${VOLUME_NAME}-$(date +%Y%m%d_%H%M%S).tar.gz"
```

### Backup Verification

```bash
# Verify tar backup integrity
tar tzf backup.tar.gz > /dev/null
echo $?  # 0 = valid

# List backup contents
tar tzf backup.tar.gz | head -20

# Check backup size
ls -lh backup.tar.gz

# Verify SQL dump
head -20 backup.sql
tail -20 backup.sql

# Test restore to temporary volume
docker volume create test-restore
docker run --rm -v test-restore:/data -v $(pwd):/backup alpine tar xzf /backup/backup.tar.gz -C /data
docker run --rm -v test-restore:/data alpine ls -lah /data
docker volume rm test-restore

# Compare checksums
md5sum backup.tar.gz > backup.tar.gz.md5
md5sum -c backup.tar.gz.md5
```

### Automated Backups

Complete backup script:

```bash
#!/bin/bash
# comprehensive-backup.sh

set -euo pipefail

BACKUP_DIR="/Users/gator/colima-services/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Load Vault credentials
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

mkdir -p "${BACKUP_DIR}"/{postgres,mysql,mongodb,redis,vault}

echo "=== Starting backup: ${DATE} ==="

# Backup PostgreSQL
echo "Backing up PostgreSQL..."
docker exec postgres pg_dumpall -U postgres | gzip > "${BACKUP_DIR}/postgres/all_databases_${DATE}.sql.gz"

# Backup MySQL
echo "Backing up MySQL..."
MYSQL_PASS=$(vault kv get -field=password secret/mysql)
docker exec mysql mysqldump -u root -p"${MYSQL_PASS}" --all-databases | gzip > "${BACKUP_DIR}/mysql/all_databases_${DATE}.sql.gz"

# Backup MongoDB
echo "Backing up MongoDB..."
MONGO_PASS=$(vault kv get -field=password secret/mongodb)
docker exec mongodb mongodump --username=admin --password="${MONGO_PASS}" --out=/tmp/backup_${DATE}
docker cp mongodb:/tmp/backup_${DATE} "${BACKUP_DIR}/mongodb/backup_${DATE}"
docker exec mongodb rm -rf /tmp/backup_${DATE}

# Backup Redis
echo "Backing up Redis..."
docker exec redis-1 redis-cli SAVE
docker cp redis-1:/data/dump.rdb "${BACKUP_DIR}/redis/dump_${DATE}.rdb"

# Backup Vault
echo "Backing up Vault..."
docker exec vault vault operator raft snapshot save /tmp/vault-snapshot
docker cp vault:/tmp/vault-snapshot "${BACKUP_DIR}/vault/snapshot_${DATE}"
docker exec vault rm /tmp/vault-snapshot
cp -r ~/.config/vault "${BACKUP_DIR}/vault/keys_${DATE}"

# Cleanup old backups
echo "Cleaning up old backups..."
find "${BACKUP_DIR}" -type f -mtime +${RETENTION_DAYS} -delete
find "${BACKUP_DIR}" -type d -empty -delete

# Verify backups
echo "Verifying backups..."
for backup in "${BACKUP_DIR}"/postgres/*.sql.gz; do
  gunzip -t "$backup" && echo "✓ $backup" || echo "✗ $backup FAILED"
done

for backup in "${BACKUP_DIR}"/mysql/*.sql.gz; do
  gunzip -t "$backup" && echo "✓ $backup" || echo "✗ $backup FAILED"
done

# Report backup sizes
echo "=== Backup Summary ==="
du -sh "${BACKUP_DIR}"/*
echo "=== Backup complete: ${DATE} ==="
```

Make executable and run:

```bash
chmod +x comprehensive-backup.sh
./comprehensive-backup.sh
```

Schedule with cron:

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /Users/gator/colima-services/comprehensive-backup.sh >> /Users/gator/colima-services/backups/backup.log 2>&1

# Add weekly backup on Sunday at 3 AM
0 3 * * 0 /Users/gator/colima-services/comprehensive-backup.sh >> /Users/gator/colima-services/backups/backup-weekly.log 2>&1
```

## Volume Restore

### Restoring from Backup

**PostgreSQL restore:**

```bash
# Stop PostgreSQL
docker compose stop postgres

# Restore volume from tar
docker run --rm -v postgres-data:/data -v $(pwd)/backups:/backup alpine sh -c "rm -rf /data/* && tar xzf /backup/postgres-data-20240115_120000.tar.gz -C /data"

# Start PostgreSQL
docker compose start postgres

# Or restore from SQL dump (preferred)
docker compose start postgres
gunzip < backups/all_databases_20240115_120000.sql.gz | docker exec -i postgres psql -U postgres

# Verify
docker exec postgres psql -U postgres -c "\l"
```

**MySQL restore:**

```bash
# Stop MySQL
docker compose stop mysql

# Restore volume from tar
docker run --rm -v mysql-data:/data -v $(pwd)/backups:/backup alpine sh -c "rm -rf /data/* && tar xzf /backup/mysql-data-20240115_120000.tar.gz -C /data"

# Start MySQL
docker compose start mysql

# Or restore from SQL dump (preferred)
docker compose start mysql
gunzip < backups/all_databases_20240115_120000.sql.gz | docker exec -i mysql mysql -u root -p

# Verify
docker exec mysql mysql -u root -p -e "SHOW DATABASES;"
```

**MongoDB restore:**

```bash
# Restore from mongodump
docker cp backups/backup_20240115_120000 mongodb:/tmp/restore
docker exec mongodb mongorestore --username=admin --password="${MONGO_PASS}" /tmp/restore
docker exec mongodb rm -rf /tmp/restore

# Verify
docker exec mongodb mongosh --eval "show dbs"
```

**Redis restore:**

```bash
# Stop Redis
docker compose stop redis-1

# Restore RDB file
docker cp backups/dump_20240115_120000.rdb redis-1:/data/dump.rdb

# Start Redis
docker compose start redis-1

# Verify
docker exec redis-1 redis-cli DBSIZE
```

**Vault restore:**

```bash
# Stop Vault
docker compose stop vault

# Restore snapshot
docker cp backups/snapshot_20240115_120000 vault:/tmp/vault-snapshot
docker compose start vault
docker exec vault vault operator raft snapshot restore /tmp/vault-snapshot
docker exec vault rm /tmp/vault-snapshot

# Restore unseal keys
cp -r backups/vault/keys_20240115_120000 ~/.config/vault

# Unseal Vault
./manage-colima.sh vault-unseal

# Verify
docker exec vault vault status
```

### Volume Migration

Move volumes between systems:

```bash
# On source system
# 1. Backup volume
docker run --rm -v postgres-data:/data -v $(pwd):/backup alpine tar czf /backup/postgres-data-export.tar.gz -C /data .

# 2. Copy to destination
scp postgres-data-export.tar.gz user@destination:/path/to/backups/

# On destination system
# 3. Create volume
docker volume create postgres-data

# 4. Restore volume
docker run --rm -v postgres-data:/data -v /path/to/backups:/backup alpine tar xzf /backup/postgres-data-export.tar.gz -C /data

# 5. Start container
docker compose up -d postgres

# 6. Verify
docker exec postgres psql -U postgres -c "\l"
```

### Point-in-Time Recovery

PostgreSQL PITR:

```bash
# 1. Restore base backup
docker compose stop postgres
docker run --rm -v postgres-data:/data -v $(pwd)/backups:/backup alpine sh -c "rm -rf /data/* && tar xzf /backup/postgres-base.tar.gz -C /data"

# 2. Apply WAL logs up to specific point
docker compose start postgres
docker exec postgres pg_waldump /var/lib/postgresql/data/pg_wal/000000010000000000000001

# 3. Use recovery target
echo "recovery_target_time = '2024-01-15 14:30:00'" | docker exec -i postgres tee /var/lib/postgresql/data/recovery.conf

# 4. Restart PostgreSQL
docker compose restart postgres

# 5. Verify recovery
docker exec postgres psql -U postgres -c "SELECT now();"
```

## Volume Inspection

### Finding Volumes

```bash
# Find all volumes
docker volume ls

# Find volumes by name pattern
docker volume ls --filter name=postgres
docker volume ls --filter name=data

# Find dangling volumes (not used by containers)
docker volume ls --filter dangling=true

# Find volumes by label
docker volume ls --filter label=env=dev

# Find volumes used by specific container
docker inspect <container> | jq '.[0].Mounts[].Name'

# Find which containers use a volume
for container in $(docker ps -aq); do
  docker inspect $container | jq -r '.[] | select(.Mounts[].Name=="postgres-data") | .Name'
done
```

### Disk Usage

```bash
# Show volume sizes
docker system df -v

# Show all volumes with sizes
docker system df -v | grep "VOLUME NAME" -A 100

# Get specific volume size
docker run --rm -v postgres-data:/data alpine du -sh /data

# Compare volume sizes
for vol in $(docker volume ls -q); do
  size=$(docker run --rm -v ${vol}:/data alpine du -sh /data 2>/dev/null | cut -f1)
  echo "${vol}: ${size}"
done | sort -k2 -rh

# Check available space in Colima VM
docker run --rm alpine df -h

# Total size of all volumes
docker system df | grep "Local Volumes"
```

### Volume Contents

```bash
# List volume contents
docker run --rm -v postgres-data:/data alpine ls -lah /data

# Find large files
docker run --rm -v postgres-data:/data alpine find /data -type f -size +100M

# Count files
docker run --rm -v postgres-data:/data alpine find /data -type f | wc -l

# Show directory tree
docker run --rm -v postgres-data:/data alpine find /data -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'

# Search for files
docker run --rm -v postgres-data:/data alpine find /data -name "*.log"

# View file contents
docker run --rm -v postgres-data:/data alpine cat /data/PG_VERSION

# Check permissions
docker run --rm -v postgres-data:/data alpine ls -la /data
```

### Volume Dependencies

```bash
# Show which containers use each volume
for vol in $(docker volume ls -q); do
  echo "=== Volume: $vol ==="
  docker ps -a --filter volume=$vol --format "  {{.Names}} ({{.Status}})"
done

# Show volumes used by service
docker compose config | grep -A 10 "volumes:"

# Check if volume is in use
docker ps -a --filter volume=postgres-data

# Dependency graph
docker compose config | jq '.services | to_entries[] | {service: .key, volumes: .value.volumes}'
```

## Volume Cleanup

### Removing Unused Volumes

```bash
# List unused volumes
docker volume ls --filter dangling=true

# Remove specific unused volume
docker volume rm <volume-name>

# Remove all unused volumes (interactive)
docker volume prune

# Remove all unused volumes (non-interactive)
docker volume prune -f

# Remove volumes with filter
docker volume prune --filter label=temp=true
```

### Pruning Volumes

```bash
# Prune unused volumes
docker volume prune

# Prune with confirmation
docker volume prune -f

# Prune all unused resources (containers, images, volumes)
docker system prune -a --volumes

# Dry run (show what would be removed)
docker volume ls --filter dangling=true

# Prune old volumes (requires manual filtering)
for vol in $(docker volume ls -q); do
  created=$(docker volume inspect $vol -f '{{.CreatedAt}}')
  # Manual date comparison logic
done
```

### Space Reclamation

```bash
# Check current usage
docker system df

# Detailed volume usage
docker system df -v

# Remove stopped containers
docker container prune

# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Remove build cache
docker builder prune

# Complete cleanup (⚠️ removes everything unused)
docker system prune -a --volumes

# Free space in volumes
# PostgreSQL VACUUM
docker exec postgres psql -U postgres -c "VACUUM FULL;"

# MySQL OPTIMIZE
docker exec mysql mysqlcheck -u root -p --optimize --all-databases

# MongoDB compact
docker exec mongodb mongosh --eval "db.runCommand({ compact: 'users' })"
```

## Data Persistence

### Understanding Persistence

Docker volume types and persistence:

| Volume Type | Persistence | Survives Container Removal | Survives VM Restart |
|-------------|-------------|----------------------------|---------------------|
| Named Volume | Yes | Yes | Yes |
| Bind Mount | Yes | Yes | Yes |
| tmpfs | No | No | No |
| Container Layer | No | No | No |

**Important notes:**
- Named volumes persist until explicitly removed
- Bind mounts persist as long as host directory exists
- tmpfs is lost when container stops
- Container writable layer is lost when container is removed

### Volume Locations

```bash
# Find volume mount point in Colima VM
docker volume inspect postgres-data -f '{{.Mountpoint}}'
# Output: /var/lib/docker/volumes/postgres-data/_data

# Access Colima VM
colima ssh

# Navigate to volume (inside Colima VM)
sudo ls -la /var/lib/docker/volumes/postgres-data/_data

# Or access without SSH
docker run --rm -v postgres-data:/data alpine ls -la /data
```

Volume storage hierarchy:

```
Colima VM:
  /var/lib/docker/volumes/
    ├── postgres-data/
    │   └── _data/          # Actual PostgreSQL data
    ├── mysql-data/
    │   └── _data/          # Actual MySQL data
    ├── mongodb-data/
    │   └── _data/          # Actual MongoDB data
    └── vault-file/
        └── _data/          # Actual Vault data
```

### Data Durability

```bash
# Volumes persist across:

# 1. Container restart
docker compose restart postgres
# Data remains intact

# 2. Container recreation
docker compose down
docker compose up -d
# Data remains intact

# 3. Colima VM restart
colima stop
colima start
docker compose up -d
# Data remains intact

# Volumes are lost when:

# 1. Volume is explicitly removed
docker volume rm postgres-data  # Data is deleted!

# 2. docker compose down -v
docker compose down -v  # All volumes deleted!

# 3. Colima is deleted and recreated
colima delete
colima start  # All volumes lost!
```

### Backup Importance

**⚠️ CRITICAL:** Regular backups are essential because:

1. **Accidental deletion**: `docker volume rm` or `docker compose down -v`
2. **Corruption**: Hardware failure, filesystem corruption
3. **Colima recreation**: `colima delete` removes all volumes
4. **Migration**: Moving to new machine
5. **Disaster recovery**: System failure, data center issues

**Backup strategy:**
- **Daily**: Automated database dumps
- **Weekly**: Full volume backups
- **Before changes**: Manual backup before updates
- **Off-site**: Store backups outside Colima VM

## Volume Troubleshooting

### Permission Issues

**Symptom:** Container can't write to volume

```bash
# Check volume permissions
docker run --rm -v postgres-data:/data alpine ls -la /data

# Check container user
docker exec postgres id
docker exec postgres whoami

# Fix permissions (PostgreSQL example - UID 999)
docker compose stop postgres
docker run --rm -v postgres-data:/data -u root alpine chown -R 999:999 /data
docker compose start postgres

# Fix permissions (MySQL example - UID 999)
docker run --rm -v mysql-data:/data -u root alpine chown -R 999:999 /data

# Fix permissions (MongoDB example - UID 999)
docker run --rm -v mongodb-data:/data -u root alpine chown -R 999:999 /data

# Verify permissions
docker run --rm -v postgres-data:/data alpine ls -la /data

# Check for read-only mounts
docker inspect postgres | jq '.[0].Mounts[] | select(.Destination=="/var/lib/postgresql/data") | .RW'
# true = read-write, false = read-only
```

### Disk Full

**Symptom:** No space left on device

```bash
# Check disk usage in Colima VM
docker run --rm alpine df -h

# Check volume sizes
docker system df -v

# Find large volumes
for vol in $(docker volume ls -q); do
  size=$(docker run --rm -v ${vol}:/data alpine du -sh /data 2>/dev/null | cut -f1)
  echo "${vol}: ${size}"
done | sort -k2 -rh

# Free up space
docker system prune -a --volumes

# Expand Colima VM disk (requires recreate)
colima stop
colima start --disk 100  # 100GB disk

# Cleanup database files
# PostgreSQL VACUUM
docker exec postgres psql -U postgres -c "VACUUM FULL;"

# MySQL optimize
docker exec mysql mysqlcheck -u root -p --optimize --all-databases

# Remove old logs
docker run --rm -v postgres-data:/data alpine find /data -name "*.log" -mtime +7 -delete
```

### Corrupted Data

**Symptom:** Database won't start, corruption errors

```bash
# Check logs
docker logs postgres

# PostgreSQL recovery
docker compose stop postgres

# Try repair
docker run --rm -v postgres-data:/data postgres:16 postgres --single -D /data

# Restore from backup
docker run --rm -v postgres-data:/data -v $(pwd)/backups:/backup alpine sh -c "rm -rf /data/* && tar xzf /backup/postgres-data-backup.tar.gz -C /data"

# MySQL recovery
docker exec mysql mysqlcheck -u root -p --auto-repair --all-databases

# MongoDB repair
docker compose stop mongodb
docker run --rm -v mongodb-data:/data mongo:7.0 mongod --dbpath /data --repair
docker compose start mongodb
```

### Mount Failures

**Symptom:** Volume won't mount

```bash
# Check if volume exists
docker volume ls | grep postgres-data

# Inspect volume
docker volume inspect postgres-data

# Check for conflicts
docker ps -a --filter volume=postgres-data

# Recreate volume
docker compose down
docker volume rm postgres-data
docker volume create postgres-data
docker compose up -d

# Check docker-compose.yml syntax
docker compose config

# Verify mount in container
docker inspect postgres | jq '.[0].Mounts'

# Check Colima status
colima status
colima list
```

## Best Practices

### Naming Conventions

```bash
# Use descriptive names
postgres-data     # Good
db1              # Bad

# Include service name
postgres-data
mysql-data
mongodb-data

# Use consistent naming
<service>-data
<service>-config
<service>-logs

# Avoid special characters
postgres-data    # Good
postgres_data    # OK
postgres data    # Bad (spaces)
```

### Backup Schedules

```bash
# Recommended backup schedule:

# Daily (automated)
0 2 * * * /path/to/backup-script.sh

# Weekly full backup (automated)
0 3 * * 0 /path/to/full-backup-script.sh

# Before major changes (manual)
./backup-all.sh

# Before updates (manual)
docker compose down
./backup-all.sh
docker compose pull
docker compose up -d

# Retention policy:
# - Daily backups: Keep 7 days
# - Weekly backups: Keep 4 weeks
# - Monthly backups: Keep 12 months
```

### Monitoring

```bash
# Monitor volume sizes
watch -n 60 'docker system df -v'

# Alert on low disk space
#!/bin/bash
THRESHOLD=80
USAGE=$(docker run --rm alpine df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $USAGE -gt $THRESHOLD ]; then
  echo "WARNING: Disk usage is ${USAGE}%"
  # Send alert
fi

# Track volume growth
docker system df -v > volume-sizes-$(date +%Y%m%d).txt

# Monitor backup status
ls -lh backups/ | tail -10
```

### Security

```bash
# Encrypt backups
tar czf - postgres-data | gpg --encrypt --recipient you@example.com > postgres-data-encrypted.tar.gz.gpg

# Decrypt backups
gpg --decrypt postgres-data-encrypted.tar.gz.gpg | tar xzf -

# Secure backup storage
chmod 600 backups/*.tar.gz
chown $USER:$USER backups/*.tar.gz

# Store backups off-site
rsync -avz backups/ backup-server:/backups/colima-services/

# Verify backup integrity
sha256sum postgres-data.tar.gz > postgres-data.tar.gz.sha256
sha256sum -c postgres-data.tar.gz.sha256
```

## Service-Specific Volumes

### PostgreSQL Volumes

```yaml
# docker-compose.yml
services:
  postgres:
    volumes:
      - postgres-data:/var/lib/postgresql/data

volumes:
  postgres-data:
```

Operations:

```bash
# Backup
docker exec postgres pg_dumpall -U postgres | gzip > postgres-backup.sql.gz

# Restore
gunzip < postgres-backup.sql.gz | docker exec -i postgres psql -U postgres

# Check size
docker run --rm -v postgres-data:/data alpine du -sh /data

# Vacuum
docker exec postgres psql -U postgres -c "VACUUM FULL;"
```

### MySQL Volumes

```yaml
services:
  mysql:
    volumes:
      - mysql-data:/var/lib/mysql

volumes:
  mysql-data:
```

Operations:

```bash
# Backup
docker exec mysql mysqldump -u root -p --all-databases | gzip > mysql-backup.sql.gz

# Restore
gunzip < mysql-backup.sql.gz | docker exec -i mysql mysql -u root -p

# Check size
docker run --rm -v mysql-data:/data alpine du -sh /data

# Optimize
docker exec mysql mysqlcheck -u root -p --optimize --all-databases
```

### MongoDB Volumes

```yaml
services:
  mongodb:
    volumes:
      - mongodb-data:/data/db

volumes:
  mongodb-data:
```

Operations:

```bash
# Backup
docker exec mongodb mongodump --out=/tmp/backup
docker cp mongodb:/tmp/backup ./mongodb-backup

# Restore
docker cp ./mongodb-backup mongodb:/tmp/restore
docker exec mongodb mongorestore /tmp/restore

# Check size
docker run --rm -v mongodb-data:/data alpine du -sh /data

# Compact
docker exec mongodb mongosh --eval "db.runCommand({ compact: 'collection' })"
```

### Redis Volumes

```yaml
services:
  redis-1:
    volumes:
      - redis-data:/data

volumes:
  redis-data:
```

Operations:

```bash
# Backup (RDB)
docker exec redis-1 redis-cli SAVE
docker cp redis-1:/data/dump.rdb ./redis-backup.rdb

# Restore
docker cp ./redis-backup.rdb redis-1:/data/dump.rdb
docker compose restart redis-1

# Check size
docker run --rm -v redis-data:/data alpine du -sh /data
```

### Vault Volumes

```yaml
services:
  vault:
    volumes:
      - vault-file:/vault/file
      - vault-logs:/vault/logs

volumes:
  vault-file:
  vault-logs:
```

Operations:

```bash
# Backup
docker exec vault vault operator raft snapshot save /tmp/vault-snapshot
docker cp vault:/tmp/vault-snapshot ./vault-snapshot
cp -r ~/.config/vault ~/vault-keys-backup

# Restore
docker cp ./vault-snapshot vault:/tmp/vault-snapshot
docker exec vault vault operator raft snapshot restore /tmp/vault-snapshot

# Check size
docker run --rm -v vault-file:/data alpine du -sh /data
```

### Grafana Volumes

```yaml
services:
  grafana:
    volumes:
      - grafana-data:/var/lib/grafana

volumes:
  grafana-data:
```

Operations:

```bash
# Backup
docker run --rm -v grafana-data:/data -v $(pwd):/backup alpine tar czf /backup/grafana-backup.tar.gz -C /data .

# Restore
docker run --rm -v grafana-data:/data -v $(pwd):/backup alpine tar xzf /backup/grafana-backup.tar.gz -C /data

# Check size
docker run --rm -v grafana-data:/data alpine du -sh /data
```

## Related Documentation

- [Backup and Restore](Backup-and-Restore) - Complete backup strategies
- [Container Management](Container-Management) - Container operations
- [Service Configuration](Service-Configuration) - Service setup
- [PostgreSQL Operations](PostgreSQL-Operations) - PostgreSQL guide
- [MySQL Operations](MySQL-Operations) - MySQL guide
- [MongoDB Operations](MongoDB-Operations) - MongoDB guide
- [Troubleshooting](Troubleshooting) - Common issues

---

**Quick Reference Card:**

```bash
# Volume Lifecycle
docker volume create myvolume
docker volume ls
docker volume inspect myvolume
docker volume rm myvolume
docker volume prune

# Backup
docker run --rm -v myvolume:/data -v $(pwd):/backup alpine tar czf /backup/myvolume.tar.gz -C /data .

# Restore
docker run --rm -v myvolume:/data -v $(pwd):/backup alpine tar xzf /backup/myvolume.tar.gz -C /data

# Inspection
docker system df -v
docker run --rm -v myvolume:/data alpine ls -lah /data
docker run --rm -v myvolume:/data alpine du -sh /data

# Cleanup
docker volume prune
docker system prune -a --volumes
```
