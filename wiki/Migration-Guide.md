# Migration Guide

## Table of Contents

- [Migrating from Docker Desktop](#migrating-from-docker-desktop-to-colima)
- [Migrating Existing Databases](#migrating-existing-databases)
- [Importing Data](#importing-data)
- [Configuration Migration](#configuration-migration)
- [Testing After Migration](#testing-after-migration)
- [Rollback Procedures](#rollback-procedures)

## Migrating from Docker Desktop to Colima

**Prerequisites:**
```bash
# Install Colima and Docker CLI
brew install colima docker docker-compose

# Stop Docker Desktop
# Quit Docker Desktop app
```

**Migration steps:**
1. Export Docker Desktop containers and volumes
2. Install and start Colima
3. Import containers and volumes
4. Test services
5. Remove Docker Desktop

**Export from Docker Desktop:**
```bash
# Export volumes
docker run --rm -v postgres-data:/data -v $(pwd):/backup alpine tar czf /backup/postgres-data.tar.gz -C /data .

# Export container configs
docker inspect postgres > postgres-config.json
```

**Start Colima:**
```bash
colima start --cpu 8 --memory 16 --disk 100
```

**Import to Colima:**
```bash
# Create volume
docker volume create postgres-data

# Import data
docker run --rm -v postgres-data:/data -v $(pwd):/backup alpine tar xzf /backup/postgres-data.tar.gz -C /data

# Start services
./manage-devstack.sh start
```

## Migrating Existing Databases

**PostgreSQL migration:**
```bash
# From old system
pg_dumpall -U postgres > all-databases.sql

# To devstack-core
cat all-databases.sql | docker exec -i dev-postgres psql -U postgres
```

**MySQL migration:**
```bash
# From old system
mysqldump --all-databases -u root -p > all-databases.sql

# To devstack-core
cat all-databases.sql | docker exec -i dev-mysql mysql -u root -p
```

**MongoDB migration:**
```bash
# From old system
mongodump --out=/backup/

# To devstack-core
docker cp /backup/ dev-mongodb:/backup/
docker exec dev-mongodb mongorestore /backup/
```

## Importing Data

**PostgreSQL CSV import:**
```bash
# Copy CSV to container
docker cp data.csv dev-postgres:/tmp/

# Import
docker exec dev-postgres psql -U postgres -d devdb -c "
  COPY users FROM '/tmp/data.csv' WITH CSV HEADER;
"
```

**MySQL CSV import:**
```bash
docker cp data.csv dev-mysql:/tmp/
docker exec dev-mysql mysql -u root -p -e "
  LOAD DATA INFILE '/tmp/data.csv'
  INTO TABLE users
  FIELDS TERMINATED BY ','
  ENCLOSED BY '\"'
  LINES TERMINATED BY '\n'
  IGNORE 1 ROWS;
"
```

**MongoDB JSON import:**
```bash
docker cp data.json dev-mongodb:/tmp/
docker exec dev-mongodb mongoimport \
  --db devdb \
  --collection users \
  --file /tmp/data.json \
  --jsonArray
```

## Configuration Migration

**Transfer environment variables:**
```bash
# From old .env
cp old-project/.env ~/devstack-core/.env

# Update paths and IPs
nano ~/devstack-core/.env
```

**Migrate application configs:**
```bash
# Copy configs
cp -r old-configs/ ~/devstack-core/configs/myapp/

# Update docker-compose.yml
nano docker-compose.yml
```

## Testing After Migration

**Verify data:**
```bash
# PostgreSQL
docker exec dev-postgres psql -U postgres -d devdb -c "SELECT COUNT(*) FROM users;"

# MySQL
docker exec dev-mysql mysql -u root -p -e "SELECT COUNT(*) FROM devdb.users;"

# MongoDB
docker exec dev-mongodb mongosh devdb --eval "db.users.countDocuments()"
```

**Run tests:**
```bash
./tests/run-all-tests.sh
```

**Check health:**
```bash
./manage-devstack.sh health
```

## Rollback Procedures

**If migration fails:**

1. **Stop Colima:**
```bash
./manage-devstack.sh stop
```

2. **Restore Docker Desktop:**
```bash
# Start Docker Desktop app
open /Applications/Docker.app
```

3. **Import backups to Docker Desktop:**
```bash
# Import volumes
docker run --rm -v postgres-data:/data -v $(pwd):/backup alpine tar xzf /backup/postgres-data.tar.gz -C /data

# Start services
docker compose up -d
```

4. **Verify services working:**
```bash
docker ps
curl http://localhost:8000/health
```

## Related Pages

- [Colima-Configuration](Colima-Configuration)
- [Backup-and-Restore](Backup-and-Restore)
- [Service-Configuration](Service-Configuration)
