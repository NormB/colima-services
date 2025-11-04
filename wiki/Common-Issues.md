# Common Issues and Solutions

Quick solutions to the most frequently encountered problems with Colima Services.

## Table of Contents

- [Startup Issues](#startup-issues)
- [Vault Issues](#vault-issues)
- [Database Issues](#database-issues)
- [Redis Issues](#redis-issues)
- [Network Issues](#network-issues)
- [Performance Issues](#performance-issues)
- [Docker/Colima Issues](#dockercolima-issues)

## Startup Issues

### Services Won't Start

**Symptom:** `docker compose up` fails or services crash immediately

**Solutions:**

```bash
# 1. Check if Colima is running
colima status

# 2. Restart Colima
colima restart

# 3. Check Docker is accessible
docker ps

# 4. View service logs
./manage-colima.sh logs <service-name>
```

### Vault is Sealed

**Symptom:** All services fail with "connection refused" to Vault

**Solution:**

```bash
# Check Vault status
./manage-colima.sh vault-status

# Vault auto-unseals, just restart it
docker compose restart vault

# Wait 30 seconds for unseal, then check again
sleep 30
./manage-colima.sh vault-status
```

### "depends_on" Services Won't Start

**Symptom:** Services waiting for Vault healthcheck timeout

**Root Cause:** Vault health check failing

**Solution:**

```bash
# Check Vault logs
./manage-colima.sh logs vault

# Look for initialization or unseal issues
# Vault must be unsealed for health check to pass

# If Vault keys missing, reinitialize
rm -rf ~/.config/vault/
./manage-colima.sh vault-init
./manage-colima.sh vault-bootstrap
```

## Vault Issues

### Vault Bootstrap Fails

**Symptom:** `vault-bootstrap` command errors

**Common Causes & Solutions:**

```bash
# 1. Vault not initialized
./manage-colima.sh vault-init

# 2. Vault sealed
docker compose restart vault
sleep 30

# 3. Token not set
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# 4. Network connectivity
docker exec vault wget -O- http://127.0.0.1:8200/v1/sys/health
```

### Cannot Retrieve Secrets

**Symptom:** `vault kv get secret/postgres` returns "permission denied" or "not found"

**Solutions:**

```bash
# 1. Check token is set
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# 2. Verify token is valid
vault token lookup

# 3. Check secret exists
vault kv list secret/

# 4. If empty, run bootstrap
./manage-colima.sh vault-bootstrap
```

### Lost Vault Keys

**Symptom:** `~/.config/vault/keys.json` deleted, Vault sealed

**⚠️ Critical:** If you don't have a backup, **data is unrecoverable**

**Solutions:**

```bash
# If you have a backup
cp ~/backup-vault/keys.json ~/.config/vault/
docker compose restart vault

# If no backup, complete reset (DATA LOSS)
./manage-colima.sh reset
./manage-colima.sh start
./manage-colima.sh vault-init
./manage-colima.sh vault-bootstrap
```

## Database Issues

### PostgreSQL Connection Refused

**Symptom:** `psql: error: connection to server at "localhost" refused`

**Solutions:**

```bash
# 1. Check PostgreSQL is running
docker compose ps postgres

# 2. Check health
docker compose ps --format json | jq '.[] | select(.Name=="dev-postgres")'

# 3. Check logs for errors
./manage-colima.sh logs postgres

# 4. Verify Vault credentials were fetched
docker compose logs postgres | grep -i vault

# 5. Restart PostgreSQL
docker compose restart postgres
```

### Password Authentication Failed

**Symptom:** `FATAL: password authentication failed for user "dev_admin"`

**Solutions:**

```bash
# 1. Get password from Vault
./manage-colima.sh vault-show-password postgres

# 2. Try connecting with correct password
export PGPASSWORD=$(vault kv get -field=password secret/postgres)
psql -h localhost -U dev_admin -d dev_database

# 3. If still fails, check init script ran
docker compose logs postgres | grep "POSTGRES_PASSWORD"

# 4. Restart PostgreSQL to re-fetch credentials
docker compose restart postgres
```

### MySQL/MongoDB Similar Issues

Same troubleshooting steps apply:

```bash
# MySQL
./manage-colima.sh vault-show-password mysql
docker compose restart mysql

# MongoDB
./manage-colima.sh vault-show-password mongodb
docker compose restart mongodb
```

## Redis Issues

### Redis Cluster Won't Form

**Symptom:** `redis-cli cluster info` shows `cluster_state:fail`

**Solutions:**

```bash
# 1. Check all nodes running
docker compose ps redis-1 redis-2 redis-3

# 2. Check logs for errors
./manage-colima.sh logs redis-1

# 3. Recreate cluster
docker compose restart redis-1 redis-2 redis-3

# Wait 30 seconds
sleep 30

# 4. Check cluster status
redis-cli -c cluster nodes
```

### "CLUSTERDOWN" Error

**Symptom:** `CLUSTERDOWN Hash slot not served`

**Cause:** Not all 16384 slots assigned

**Solution:**

```bash
# Check slot distribution
redis-cli cluster info | grep cluster_slots

# Should show: cluster_slots_assigned:16384

# If not, reinitialize cluster
docker compose down redis-1 redis-2 redis-3
docker volume rm colima-services_redis_1_data \
                 colima-services_redis_2_data \
                 colima-services_redis_3_data
docker compose up -d redis-1 redis-2 redis-3
```

### Redis Authentication Failed

**Symptom:** `NOAUTH Authentication required`

**Solution:**

```bash
# Get password from Vault
REDIS_PASSWORD=$(vault kv get -field=password secret/redis-1)

# Connect with auth
redis-cli -a "$REDIS_PASSWORD"

# Or set in environment
export REDIS_PASSWORD
redis-cli --askpass
```

## Network Issues

### Cannot Access Services from Host

**Symptom:** `curl localhost:8000` connection refused

**Solutions:**

```bash
# 1. Check service is running
docker compose ps reference-api

# 2. Check port mappings
docker compose ps --format json | jq '.[] | select(.Name=="dev-reference-api") | .Publishers'

# 3. Check Colima network
colima list

# 4. Restart Colima networking
colima stop
colima start --network-address
```

### Services Can't Reach Each Other

**Symptom:** Container logs show "connection refused" to other containers

**Solutions:**

```bash
# 1. Check all services in same network
docker network inspect dev-services

# 2. Test connectivity from one container to another
docker exec reference-api ping postgres

# 3. Check DNS resolution
docker exec reference-api nslookup vault

# 4. Verify static IPs
docker inspect postgres | jq '.[0].NetworkSettings.Networks'
```

### Port Already in Use

**Symptom:** `Error starting userland proxy: listen tcp4 0.0.0.0:5432: bind: address already in use`

**Solutions:**

```bash
# 1. Find process using port
lsof -i :5432

# 2. Kill the process
kill <PID>

# Or change port in .env
echo "POSTGRES_HOST_PORT=5433" >> .env

# 3. Restart services
docker compose up -d
```

## Performance Issues

### Slow Startup Times

**Symptom:** Services take >5 minutes to start

**Solutions:**

```bash
# 1. Increase Colima resources (edit manage-colima.sh line 42)
# Change to: colima start --cpu 6 --memory 12 --disk 60

# 2. Check disk space
df -h ~/Library/Containers/colima/

# 3. Prune unused Docker resources
docker system prune -a

# 4. Restart Colima
colima stop
./manage-colima.sh start
```

### High CPU/Memory Usage

**Symptom:** Mac becomes slow, high resource usage

**Solutions:**

```bash
# 1. Check container resource usage
docker stats

# 2. Reduce service limits in docker-compose.yml
# Edit deploy.resources.limits for problematic service

# 3. Stop unused services
docker compose stop rust-api nodejs-api golang-api

# 4. Reduce Colima allocation
colima stop
colima start --cpu 2 --memory 6
```

### Database Queries Slow

**Symptom:** API responses take >1 second

**Solutions:**

```bash
# 1. Use connection pooling (PgBouncer)
# Connect to port 6432 instead of 5432

# 2. Increase shared buffers (PostgreSQL)
# Edit docker-compose.yml:
# POSTGRES_SHARED_BUFFERS=512MB

# 3. Check indexes exist
psql -h localhost -U dev_admin -d dev_database -c "\d+ your_table"

# 4. Enable query logging
# Add to docker-compose.yml postgres command:
# -c log_min_duration_statement=100
```

## Docker/Colima Issues

### Colima Won't Start

**Symptom:** `colima start` hangs or fails

**Solutions:**

```bash
# 1. Complete reset
colima delete
colima start --cpu 4 --memory 8 --disk 60 --network-address

# 2. Check system resources
# Ensure 8GB+ RAM available

# 3. Check disk space
df -h ~/

# 4. Check macOS permissions
# System Settings → Privacy & Security → Full Disk Access
# Ensure Terminal/iTerm has access
```

### Docker Commands Hang

**Symptom:** `docker ps` or `docker compose` commands timeout

**Solutions:**

```bash
# 1. Restart Docker socket
colima stop
colima start

# 2. Check Docker context
docker context ls
docker context use colima

# 3. Reset Docker
rm -rf ~/.docker
colima stop
colima start
```

### "No Space Left on Device"

**Symptom:** Cannot create containers, disk full

**Solutions:**

```bash
# 1. Clean Docker resources
docker system prune -a --volumes

# 2. Increase Colima disk size
colima stop
colima start --disk 100

# 3. Remove old images
docker images | grep "<none>" | awk '{print $3}' | xargs docker rmi
```

## Quick Diagnostics

### Run Full Health Check

```bash
# All-in-one diagnostic
./manage-colima.sh status
./manage-colima.sh health
./manage-colima.sh vault-status
docker compose ps
```

### Check Logs for Errors

```bash
# Check all service logs for errors
for service in vault postgres mysql mongodb redis-1 rabbitmq; do
  echo "=== $service ==="
  docker compose logs --tail=50 $service | grep -i error
done
```

### Verify Network Connectivity

```bash
# Test from reference-api to all services
docker exec reference-api sh -c '
  for host in vault postgres mysql mongodb redis-1 rabbitmq; do
    echo -n "$host: "
    nc -zv $host 8200 2>&1 | grep -q succeeded && echo "OK" || echo "FAIL"
  done
'
```

## Still Need Help?

If none of these solutions work:

1. **Check full logs:** `./manage-colima.sh logs > debug.log`
2. **Review documentation:** [docs/TROUBLESHOOTING.md](https://github.com/NormB/colima-services/blob/main/docs/TROUBLESHOOTING.md)
3. **Search issues:** [GitHub Issues](https://github.com/NormB/colima-services/issues)
4. **Open new issue:** Include:
   - macOS version
   - Colima version (`colima version`)
   - Docker version (`docker version`)
   - Full error output
   - Relevant logs

---

**Related Pages:**
- [Vault Troubleshooting](Vault-Troubleshooting) - Vault-specific issues
- [Performance Tuning](Performance-Tuning) - Optimization guide
- [Network Issues](Network-Issues) - Detailed network debugging
