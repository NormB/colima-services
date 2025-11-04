# Best Practices

Practical guidelines for daily usage, development workflows, resource management, backup strategies, and integration patterns for the Colima Services infrastructure.

---

## Table of Contents

1. [Daily Usage](#daily-usage)
2. [Development Workflow](#development-workflow)
3. [Resource Management](#resource-management)
4. [Backup Strategy](#backup-strategy)
5. [Security Hygiene](#security-hygiene)
6. [Integration Patterns](#integration-patterns)
7. [Code Examples](#code-examples)
8. [Related Documentation](#related-documentation)

---

## Daily Usage

### Morning Startup

```bash
# Start all services
./manage-colima.sh start

# Verify everything is healthy
./manage-colima.sh health

# Check resource usage
./manage-colima.sh status
```

### During Development

```bash
# Check service logs when debugging
./manage-colima.sh logs postgres
./manage-colima.sh logs vault

# Restart specific service after config changes
docker compose restart postgres

# Get credentials for manual testing
./manage-colima.sh vault-show-password postgres
```

### End of Day

```bash
# Option 1: Leave running (recommended)
# Services stay available, VM uses minimal resources when idle

# Option 2: Stop everything
./manage-colima.sh stop

# Option 3: Stop services but leave Colima running
docker compose stop
```

### Weekly Maintenance

```bash
# Check resource usage
./manage-colima.sh status
docker system df

# Backup databases
./manage-colima.sh backup

# Clean up unused images (monthly)
docker system prune -a --volumes
```

---

## Development Workflow

### Local Development Cycle

**1. Make Code Changes**
```bash
# Edit your application code
nano myapp/main.py
```

**2. Test with Local Services**
```bash
# PostgreSQL
PGPASSWORD=$(./manage-colima.sh vault-show-password postgres) \
  psql -h localhost -U dev_admin -d dev_database

# Redis
redis-cli -h localhost -p 6379 -a $(./manage-colima.sh vault-show-password redis-1)

# MySQL
mysql -h localhost -u dev_user -p$(./manage-colima.sh vault-show-password mysql)
```

**3. Store Secrets in Vault**
```bash
# Store application configuration
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

vault kv put secret/myapp/config \
  api_key=your-api-key \
  webhook_url=https://example.com/webhook
```

**4. Commit to Forgejo**
```bash
# Add Forgejo as remote (first time)
git remote add forgejo http://localhost:3000/username/repo.git

# Push changes
git add .
git commit -m "Add feature X"
git push forgejo main
```

### Testing Your Application

```bash
# Run infrastructure tests
./tests/run-all-tests.sh

# Test your application endpoints
curl http://localhost:8000/health
curl http://localhost:8000/api/your-endpoint

# Check application logs
docker logs dev-reference-api --tail 50 --follow
```

### Integrating New Services

**1. Design the Integration**
- Identify which services you need (database, cache, messaging)
- Plan credential retrieval from Vault
- Design health check endpoints

**2. Fetch Credentials from Vault**
```python
# Example: Python application
from app.services.vault import vault_client

async def initialize_database():
    # Fetch PostgreSQL credentials
    creds = await vault_client.get_secret("postgres")

    # Connect using Vault credentials
    conn = await asyncpg.connect(
        host="postgres",
        user=creds["user"],
        password=creds["password"],
        database=creds["database"]
    )
    return conn
```

**3. Implement Health Checks**
```python
@app.get("/health")
async def health_check():
    # Check all dependencies
    vault_ok = await check_vault()
    db_ok = await check_database()
    redis_ok = await check_redis()

    return {
        "status": "healthy" if all([vault_ok, db_ok, redis_ok]) else "degraded",
        "services": {
            "vault": vault_ok,
            "database": db_ok,
            "redis": redis_ok
        }
    }
```

**4. Test the Integration**
```bash
# Start your application
docker compose up -d myapp

# Verify health
curl http://localhost:8080/health

# Check logs
docker logs dev-myapp
```

---

## Resource Management

### Monitoring Resource Usage

```bash
# Overall system status
./manage-colima.sh status

# Detailed container stats
docker stats

# Disk usage
docker system df

# Colima VM resources
colima status
```

### Optimizing Memory Usage

**Increase Colima Memory:**
```bash
# Stop Colima
colima stop

# Start with more memory
COLIMA_MEMORY=16 ./manage-colima.sh start
```

**Set Container Limits:**
```yaml
# docker-compose.yml
services:
  postgres:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 1G
```

### Cleaning Up Resources

```bash
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune -a

# Remove unused volumes (WARNING: deletes data!)
docker volume prune

# Full cleanup (interactive)
docker system prune -a --volumes

# Remove specific volume
docker volume rm colima-services_prometheus_data
```

### Performance Tuning

**PostgreSQL:**
```bash
# Edit docker-compose.yml
command:
  - "postgres"
  - "-c"
  - "max_connections=200"      # Increase connections
  - "-c"
  - "shared_buffers=512MB"     # Increase buffer
  - "-c"
  - "effective_cache_size=2GB" # Increase cache
```

**Redis Cluster:**
```bash
# Edit configs/redis/redis-cluster.conf
maxmemory 512mb               # Increase per node
maxmemory-policy allkeys-lru  # Eviction policy
```

---

## Backup Strategy

### What to Backup

**Critical (Must Backup):**
- ✅ `~/.config/vault/keys.json` - Vault unseal keys
- ✅ `~/.config/vault/root-token` - Vault root token
- ✅ Database data (PostgreSQL, MySQL, MongoDB)
- ✅ Git repositories (Forgejo data)

**Optional:**
- Configuration files (already in Git)
- Docker volumes (can be recreated)
- Application data (depends on use case)

### Automated Weekly Backup

```bash
# Run backup command
./manage-colima.sh backup

# Creates timestamped backup in ./backups/
# - backups/postgres_YYYYMMDD_HHMMSS.sql
# - backups/mysql_YYYYMMDD_HHMMSS.sql
# - backups/mongodb_YYYYMMDD_HHMMSS.archive
# - backups/forgejo_YYYYMMDD_HHMMSS.tar.gz
```

### Manual Backup

**PostgreSQL:**
```bash
docker exec dev-postgres pg_dumpall -U dev_admin > backup.sql
```

**MySQL:**
```bash
docker exec dev-mysql mysqldump -u root -p --all-databases > backup.sql
```

**MongoDB:**
```bash
docker exec dev-mongodb mongodump --archive > backup.archive
```

**Vault Keys (CRITICAL):**
```bash
# Encrypt and backup
tar czf vault-keys-$(date +%Y%m%d).tar.gz ~/.config/vault/
gpg -c vault-keys-*.tar.gz
rm vault-keys-*.tar.gz

# Store encrypted file securely (1Password, etc.)
```

### Backup Rotation

```bash
# Keep 4 weekly backups, 3 monthly backups
# Delete old backups
find ./backups -name "postgres_*" -mtime +28 -delete
```

---

## Security Hygiene

### Credential Management

**DO:**
- ✅ Store all credentials in Vault
- ✅ Use strong, unique passwords
- ✅ Rotate passwords quarterly
- ✅ Backup Vault keys securely

**DON'T:**
- ❌ Commit secrets to Git
- ❌ Hardcode passwords in code
- ❌ Share Vault root token
- ❌ Use default passwords

### Vault Best Practices

```bash
# Backup Vault keys (encrypted)
tar czf vault-keys.tar.gz ~/.config/vault/
gpg -c vault-keys.tar.gz

# Check Vault seal status daily
./manage-colima.sh vault-status

# Rotate Vault token (optional, for enhanced security)
vault token create -policy=admin -ttl=30d
```

### TLS/SSL

**Enable TLS for Production:**
```bash
# Generate certificates
VAULT_ADDR=http://localhost:8200 \
VAULT_TOKEN=$(cat ~/.config/vault/root-token) \
  ./scripts/generate-certificates.sh

# Enable TLS in Vault
vault kv patch secret/postgres tls_enabled=true

# Restart service
docker restart dev-postgres
```

### Network Security

**Firewall Rules:**
```bash
# Only expose necessary ports
# Block direct database access from outside network
# Use Colima's network isolation
```

### Regular Updates

```bash
# Update Docker images monthly
docker compose pull

# Restart with new images
docker compose up -d

# Clean old images
docker image prune -a
```

---

## Integration Patterns

### Using PostgreSQL

**Python (asyncpg):**
```python
import asyncpg
from app.services.vault import vault_client

async def get_database_connection():
    creds = await vault_client.get_secret("postgres")

    conn = await asyncpg.connect(
        host="postgres",
        port=5432,
        user=creds["user"],
        password=creds["password"],
        database=creds["database"]
    )
    return conn

# Usage
async def query_users():
    conn = await get_database_connection()
    try:
        users = await conn.fetch("SELECT * FROM users")
        return users
    finally:
        await conn.close()
```

**Go (pgx):**
```go
import (
    "context"
    "github.com/jackc/pgx/v5/pgxpool"
)

func getDatabasePool(ctx context.Context) (*pgxpool.Pool, error) {
    creds, err := vaultService.GetSecret("postgres")
    if err != nil {
        return nil, err
    }

    connString := fmt.Sprintf(
        "postgres://%s:%s@postgres:5432/%s",
        creds["user"], creds["password"], creds["database"],
    )

    return pgxpool.New(ctx, connString)
}
```

### Using Redis Cluster

**Python (redis-py):**
```python
from redis.cluster import RedisCluster, ClusterNode
from app.services.vault import vault_client

async def get_redis_client():
    creds = await vault_client.get_secret("redis-1")

    startup_nodes = [
        ClusterNode("redis-1", 6379),
        ClusterNode("redis-2", 6379),
        ClusterNode("redis-3", 6379),
    ]

    return RedisCluster(
        startup_nodes=startup_nodes,
        password=creds["password"],
        decode_responses=True
    )

# Usage
async def cache_data(key: str, value: str, ttl: int = 3600):
    redis = await get_redis_client()
    await redis.setex(key, ttl, value)

async def get_cached_data(key: str):
    redis = await get_redis_client()
    return await redis.get(key)
```

**Node.js (ioredis):**
```javascript
const Redis = require('ioredis');

async function getRedisClient() {
  const creds = await vaultService.getSecret('redis-1');

  return new Redis.Cluster([
    { host: 'redis-1', port: 6379 },
    { host: 'redis-2', port: 6379 },
    { host: 'redis-3', port: 6379 }
  ], {
    redisOptions: {
      password: creds.password
    }
  });
}
```

### Using RabbitMQ

**Python (aio-pika):**
```python
import aio_pika
import json
from app.services.vault import vault_client

async def get_rabbitmq_channel():
    creds = await vault_client.get_secret("rabbitmq")

    connection = await aio_pika.connect_robust(
        host="rabbitmq",
        port=5672,
        login=creds["user"],
        password=creds["password"],
        virtualhost=creds["vhost"]
    )

    return await connection.channel()

# Publish message
async def publish_event(queue: str, event: dict):
    channel = await get_rabbitmq_channel()

    await channel.default_exchange.publish(
        aio_pika.Message(
            body=json.dumps(event).encode(),
            content_type="application/json"
        ),
        routing_key=queue
    )
```

**Go (amqp091-go):**
```go
import "github.com/rabbitmq/amqp091-go"

func getRabbitMQChannel() (*amqp091.Channel, error) {
    creds, err := vaultService.GetSecret("rabbitmq")
    if err != nil {
        return nil, err
    }

    connURL := fmt.Sprintf(
        "amqp://%s:%s@rabbitmq:5672/%s",
        creds["user"], creds["password"], creds["vhost"],
    )

    conn, err := amqp091.Dial(connURL)
    if err != nil {
        return nil, err
    }

    return conn.Channel()
}
```

### Git with Forgejo

**Setup SSH:**
```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Add to Forgejo: http://localhost:3000/user/settings/keys
cat ~/.ssh/id_ed25519.pub

# Add remote
git remote add forgejo ssh://git@localhost:2222/username/repo.git

# Push
git push forgejo main
```

**Setup HTTPS:**
```bash
# Add remote with HTTPS
git remote add forgejo http://localhost:3000/username/repo.git

# Push (will prompt for credentials)
git push forgejo main
```

### Multi-Service Applications

**Example VoIP Application:**
```
Your VoIP App Architecture:
├── PostgreSQL
│   ├── Call records (CDRs)
│   ├── User accounts
│   └── Configuration
├── Redis Cluster
│   ├── Session storage
│   ├── Rate limiting
│   └── Real-time presence
├── RabbitMQ
│   ├── Call events
│   ├── Webhooks
│   └── Async processing
├── MongoDB
│   ├── Call logs
│   ├── Analytics data
│   └── Unstructured data
├── Vault
│   ├── SIP credentials
│   ├── API keys
│   └── Encryption keys
└── Forgejo
    ├── Source code
    ├── Deployment scripts
    └── CI/CD pipelines
```

---

## Code Examples

All code examples are available in the reference applications:

- **Python:** `reference-apps/fastapi/`
- **Go:** `reference-apps/golang/`
- **Node.js:** `reference-apps/nodejs/`
- **Rust:** `reference-apps/rust/`

Each includes:
- Complete working implementation
- Vault integration
- Database connections
- Redis cluster operations
- RabbitMQ messaging
- Health checks
- Error handling

---

## Related Documentation

- **[API Patterns](./API-Patterns.md)** - Application development patterns
- **[Vault Integration](./Vault-Integration.md)** - Secrets management
- **[Service Configuration](./Service-Configuration.md)** - Configuring services
- **[Testing Guide](./Testing-Guide.md)** - Testing your integration
- **[Health Monitoring](./Health-Monitoring.md)** - Monitoring services
- **[Backup and Restore](./Backup-and-Restore.md)** - Backup procedures

---

## Summary

Best practices ensure:
- **Reliable operations** - Daily workflows that work
- **Secure credential management** - Vault-first approach
- **Regular backups** - Automated and tested
- **Resource optimization** - Efficient use of system resources
- **Clear integration patterns** - Consistent service usage

Follow these patterns for a smooth development experience with the Colima Services infrastructure.
