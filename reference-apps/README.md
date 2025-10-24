# Reference Applications

**Purpose:** Educational example applications demonstrating how to integrate with the Colima Services infrastructure.

## ⚠️ Important: Not Production Code

These are **reference implementations** for learning and testing. They demonstrate best practices and integration patterns, but are **not intended for production use**.

## What Are Reference Apps?

Reference applications are **working code examples** that show you how to:

1. **Integrate with infrastructure services** - Vault, databases, Redis, RabbitMQ
2. **Follow best practices** - Async operations, error handling, configuration management
3. **Test infrastructure** - Health checks and inspection APIs
4. **Get started quickly** - Copy patterns into your own applications

## Current Reference Apps

### FastAPI (Python)

**Location:** `reference-apps/fastapi/`

**What it demonstrates:**
- ✅ Vault integration (fetching secrets securely)
- ✅ Database connectivity (PostgreSQL, MySQL, MongoDB)
- ✅ Redis caching and cluster operations
- ✅ RabbitMQ messaging patterns
- ✅ Health monitoring for all services
- ✅ HTTP/HTTPS dual-mode with Vault certificates
- ✅ Async/await patterns throughout

**Quick Start:**
```bash
# Start the reference app
docker compose up -d reference-api

# View interactive API documentation
open http://localhost:8000/docs

# Check infrastructure health
curl http://localhost:8000/health/all

# Inspect Redis cluster
curl http://localhost:8000/redis/cluster/info
```

**Full Documentation:** See [fastapi/README.md](fastapi/README.md)

## How to Use Reference Apps

### As a Learning Tool

```bash
# 1. Browse the code to see integration patterns
cat reference-apps/fastapi/app/services/vault.py
cat reference-apps/fastapi/app/routers/database_demo.py
cat reference-apps/fastapi/app/routers/redis_cluster.py

# 2. See working examples in the interactive docs
open http://localhost:8000/docs

# 3. Copy patterns into your own applications
# The code shows:
#   - How to fetch secrets from Vault
#   - How to connect to databases with Vault credentials
#   - How to handle errors gracefully
#   - How to structure async operations
```

### As a Testing Tool

```bash
# Check all infrastructure services are working
curl http://localhost:8000/health/all

# Verify Redis cluster is properly configured
curl http://localhost:8000/redis/cluster/info

# Test database connectivity
curl http://localhost:8000/examples/database/postgres/query

# Inspect cluster topology
curl http://localhost:8000/redis/cluster/nodes | jq '.nodes[].role'
```

### As a Development Reference

**Problem:** You need to add Redis caching to your application.

**Without reference app:**
- ❌ Read Redis docs
- ❌ Figure out authentication
- ❌ Debug connection issues
- ❌ Implement patterns from scratch

**With reference app:**
```bash
# 1. Verify Redis is working
curl http://localhost:8000/health/redis

# 2. See working example
cat reference-apps/fastapi/app/routers/cache_demo.py

# 3. Copy the pattern - it already shows:
#    - How to connect with Vault password
#    - How to handle errors
#    - How to set TTL
#    - Async/await patterns

# 4. Test it works
curl -X POST "http://localhost:8000/examples/cache/test?value=hello"
curl http://localhost:8000/examples/cache/test
```

## Key Integration Patterns

### Fetching Secrets from Vault

All reference apps demonstrate:

```python
from app.services.vault import vault_client

# Get all credentials for a service
creds = await vault_client.get_secret("postgres")
user = creds.get("user")
password = creds.get("password")
```

**Why this matters:**
- ✅ No hardcoded passwords
- ✅ Centralized secret management
- ✅ Credentials can be rotated without code changes

### Database Connections

```python
import asyncpg
from app.services.vault import vault_client

# Fetch credentials from Vault
creds = await vault_client.get_secret("postgres")

# Connect using Vault credentials
conn = await asyncpg.connect(
    host="postgres",
    user=creds.get("user"),
    password=creds.get("password"),
    database=creds.get("database")
)

# Execute query
result = await conn.fetch("SELECT * FROM users")
await conn.close()
```

**What you learn:**
- ✅ How to integrate Vault with databases
- ✅ Async database operations
- ✅ Connection management
- ✅ Error handling

### Redis Cluster Operations

```python
import redis.asyncio as redis
from app.services.vault import vault_client

# Get Redis credentials
creds = await vault_client.get_secret("redis-1")

# Connect to cluster
client = redis.Redis(
    host="redis-1",
    port=6379,
    password=creds.get("password"),
    decode_responses=True
)

# Use cache
await client.setex("key", 60, "value")  # Set with 60s TTL
value = await client.get("key")
await client.close()
```

**What you learn:**
- ✅ Redis cluster authentication
- ✅ Setting TTL for cache entries
- ✅ Async Redis operations

## What Reference Apps Are NOT

- ❌ **Not production-ready** - Missing security hardening, monitoring, scaling
- ❌ **Not feature-complete** - Focus on integration patterns, not business logic
- ❌ **Not performant at scale** - Simple implementations for learning
- ❌ **Not security-hardened** - Uses root Vault token for simplicity

## What Reference Apps ARE

- ✅ **Educational code** showing how to integrate services
- ✅ **Working examples** you can test immediately
- ✅ **Integration patterns** you can copy
- ✅ **Testing tools** to verify infrastructure
- ✅ **Starting points** for your own applications

## API Documentation

Each reference app provides interactive API documentation:

**FastAPI:**
- **Swagger UI:** http://localhost:8000/docs
- **ReDoc:** http://localhost:8000/redoc
- **OpenAPI JSON:** http://localhost:8000/openapi.json

## Future Reference Apps

The structure supports additional language/framework implementations:

```
reference-apps/
├── fastapi/          ✅ Python async patterns (current)
├── golang/           🔜 Go integration examples
├── nodejs/           🔜 Node.js patterns
├── spring-boot/      🔜 Java/Spring patterns
└── rust/             🔜 Rust examples
```

Each would demonstrate the same integrations but in different languages.

## Common Use Cases

### 1. Testing Infrastructure Setup

```bash
# After setting up infrastructure
curl http://localhost:8000/health/all | jq '.'

# Verify all services are healthy
# {
#   "status": "healthy",
#   "services": {
#     "vault": {"status": "healthy"},
#     "postgres": {"status": "healthy"},
#     "redis": {"status": "healthy", "cluster_state": "ok"}
#   }
# }
```

### 2. Debugging Connection Issues

```bash
# Check which service is failing
curl http://localhost:8000/health/all | jq '.services[] | select(.status != "healthy")'

# Get detailed Redis cluster information
curl http://localhost:8000/redis/cluster/nodes

# Verify database connectivity
curl http://localhost:8000/examples/database/postgres/query
```

### 3. Learning Integration Patterns

```bash
# Browse the code
cd reference-apps/fastapi/app

# See Vault integration
cat services/vault.py

# See database patterns
cat routers/database_demo.py

# See Redis cluster inspection
cat routers/redis_cluster.py

# See health check implementation
cat routers/health.py
```

### 4. Building Your Own App

```bash
# 1. Copy the patterns
cp reference-apps/fastapi/app/services/vault.py your-app/

# 2. Adapt to your needs
# 3. Use the same integration approach
# 4. Test against the same infrastructure
```

## Architecture

Each reference app follows similar structure:

```
reference-apps/{language}/
├── app/
│   ├── main.py              # Application entry point
│   ├── config.py            # Environment configuration
│   ├── routers/             # API endpoints
│   │   ├── health.py        # Health checks
│   │   ├── {service}_demo.py # Integration examples
│   └── services/            # Reusable clients
│       └── vault.py         # Vault integration
├── tests/                   # Integration tests
├── Dockerfile              # Container build
├── requirements.txt        # Dependencies
└── README.md              # Detailed docs
```

## Testing

Each reference app includes test suites:

```bash
# Test FastAPI reference app
./tests/test-fastapi.sh

# Expected output:
# ✓ Container running
# ✓ HTTP/HTTPS endpoints accessible
# ✓ Redis Cluster APIs working
# ✓ Health checks functioning
# ✓ Service integrations operational
```

See [../tests/README.md](../tests/README.md) for comprehensive test documentation.

## Security Notes

Reference apps demonstrate integration patterns but **not production security**:

- ⚠️ Uses Vault root token (simplified for learning)
- ⚠️ No authentication/authorization on endpoints
- ⚠️ No rate limiting
- ⚠️ No input validation/sanitization
- ⚠️ Debug mode enabled

**For production:** Implement proper auth, use AppRole/JWT for Vault, add validation, monitoring, etc.

## Getting Help

**Documentation:**
- Main README: [../README.md](../README.md)
- FastAPI README: [fastapi/README.md](fastapi/README.md)
- Test Documentation: [../tests/README.md](../tests/README.md)

**Quick Links:**
- Interactive API: http://localhost:8000/docs
- Health Checks: http://localhost:8000/health/all
- Redis Cluster: http://localhost:8000/redis/cluster/info

## Summary

Reference apps are **educational tools** that:
- 📚 Show you how to integrate with infrastructure
- 🔍 Help you test and debug
- 🚀 Provide starting points for your applications
- ✅ Demonstrate best practices

**Remember:** These are learning resources, not production code. Use them to understand patterns, then build your own production-ready applications with proper security, monitoring, and error handling.
