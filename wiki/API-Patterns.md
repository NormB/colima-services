# API Patterns

Comprehensive guide to API development patterns, multi-language reference implementations, and integration best practices for the DevStack Core infrastructure.

---

## Table of Contents

1. [Overview](#overview)
2. [Code-First vs API-First Approaches](#code-first-vs-api-first-approaches)
3. [Multi-Language Implementations](#multi-language-implementations)
4. [Common Patterns Across All Implementations](#common-patterns-across-all-implementations)
5. [Vault Integration in Applications](#vault-integration-in-applications)
6. [Database Connection Patterns](#database-connection-patterns)
7. [Redis Cluster Operations](#redis-cluster-operations)
8. [RabbitMQ Messaging](#rabbitmq-messaging)
9. [Health Check Patterns](#health-check-patterns)
10. [Error Handling](#error-handling)
11. [Code Examples](#code-examples)
12. [Related Documentation](#related-documentation)

---

## Overview

The DevStack Core project includes **five reference API implementations** demonstrating identical functionality across different technology stacks. Each implementation showcases language-specific best practices while maintaining consistent integration patterns.

### Purpose

These reference implementations serve as:
- 📚 **Educational examples** - Learn integration patterns
- 🔍 **Testing tools** - Validate infrastructure setup
- 🚀 **Starting points** - Bootstrap your own applications
- ⚖️ **Comparison framework** - Evaluate different tech stacks

**NOT Production Code:** These are reference implementations optimized for learning, not hardened for production use.

---

## Code-First vs API-First Approaches

### Code-First Approach (FastAPI Port 8000)

**Philosophy:** Implementation drives documentation.

**Workflow:**
1. Write Python code with type hints
2. FastAPI auto-generates OpenAPI specification
3. Documentation updates automatically
4. Iterate quickly on implementation

**Advantages:**
- ✅ Rapid development and prototyping
- ✅ Less upfront design needed
- ✅ Code and docs stay in sync automatically
- ✅ Type safety via Pydantic models

**Best For:**
- Internal APIs
- MVP development
- Agile iterations
- Teams familiar with the framework

**Example:**
```python
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

class HealthResponse(BaseModel):
    status: str
    services: dict

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Auto-generated OpenAPI spec from code"""
    return HealthResponse(
        status="healthy",
        services=await check_all_services()
    )
```

### API-First Approach (FastAPI Port 8001)

**Philosophy:** Contract drives implementation.

**Workflow:**
1. Design OpenAPI specification first
2. Review and approve API contract
3. Generate models from specification
4. Implement handlers matching contract

**Advantages:**
- ✅ Clear API contracts before coding
- ✅ Better multi-team coordination
- ✅ Client SDK generation
- ✅ Contract testing

**Best For:**
- External APIs
- Microservices architectures
- Multi-team projects
- Contract-driven development

**Example:**
```yaml
# openapi.yaml (specification first)
paths:
  /health:
    get:
      summary: Health check endpoint
      responses:
        '200':
          description: Service health status
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/HealthResponse'

# Implementation follows spec
@app.get("/health")
async def health_check():
    # Implementation matches contract
    return await generate_health_response()
```

### Validation: 100% Parity

A comprehensive test suite validates that **both approaches produce identical results**:

```bash
cd reference-apps/shared/test-suite
uv run pytest -v

# Expected: 64 tests, all passing
# Validates identical behavior between code-first and API-first
```

---

## Multi-Language Implementations

### 1. Python (FastAPI Code-First) - Port 8000

**Location:** `reference-apps/fastapi/`

**Technology Stack:**
- Framework: FastAPI (async/await)
- Language: Python 3.11+
- Validation: Pydantic
- Database: asyncpg, motor, mysql-connector
- Cache: redis-py
- Messaging: aio-pika

**Characteristics:**
- Fully asynchronous
- Auto-generated OpenAPI docs
- Type hints throughout
- Comprehensive endpoint coverage

**Quick Start:**
```bash
docker compose up -d reference-api
open http://localhost:8000/docs
curl http://localhost:8000/health/all
```

### 2. Python (FastAPI API-First) - Port 8001

**Location:** `reference-apps/fastapi-api-first/`

**Technology Stack:**
- Same as code-first
- OpenAPI spec drives implementation
- Generated models from specification

**Characteristics:**
- Contract-first design
- 100% behavioral parity with code-first
- Demonstrates spec-driven workflow

**Quick Start:**
```bash
docker compose up -d api-first
open http://localhost:8001/docs
curl http://localhost:8001/health/all
```

### 3. Go (Gin Framework) - Port 8002

**Location:** `reference-apps/golang/`

**Technology Stack:**
- Framework: Gin
- Language: Go 1.23+
- Database: pgx, mongo-go-driver, go-sql-driver/mysql
- Cache: go-redis
- Messaging: amqp091-go

**Characteristics:**
- Compiled binary (fast startup)
- Strong static typing
- Goroutines for concurrency
- Low memory footprint
- Structured logging with logrus

**Quick Start:**
```bash
docker compose up -d golang-api
curl http://localhost:8002/
curl http://localhost:8002/health/all
```

**Example:**
```go
// Vault integration with goroutines
func getVaultSecret(path string) (map[string]interface{}, error) {
    client, err := api.NewClient(config)
    if err != nil {
        return nil, err
    }

    secret, err := client.Logical().Read("secret/data/" + path)
    if err != nil {
        return nil, err
    }

    return secret.Data["data"].(map[string]interface{}), nil
}
```

### 4. Node.js (Express) - Port 8003

**Location:** `reference-apps/nodejs/`

**Technology Stack:**
- Framework: Express
- Language: JavaScript/TypeScript
- Database: pg, mongodb, mysql2
- Cache: ioredis
- Messaging: amqplib

**Characteristics:**
- Event-driven architecture
- Async/await patterns
- Large npm ecosystem
- JSON-native processing
- Winston logging

**Quick Start:**
```bash
docker compose up -d nodejs-api
curl http://localhost:8003/
curl http://localhost:8003/health/all
```

**Example:**
```javascript
// Async/await with Express
app.get('/health/all', async (req, res) => {
  try {
    const results = await Promise.allSettled([
      checkVault(),
      checkPostgres(),
      checkRedis(),
      checkRabbitMQ()
    ]);

    res.json({ services: processResults(results) });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

### 5. Rust (Actix-web) - Port 8004

**Location:** `reference-apps/rust/`

**Technology Stack:**
- Framework: Actix-web
- Language: Rust 1.70+
- Database: tokio-postgres, deadpool
- Cache: redis
- Runtime: Tokio (async)

**Characteristics:**
- Zero-cost abstractions
- Memory safety guarantees
- Exceptional performance
- Compile-time error checking
- Minimal implementation (core patterns)

**Quick Start:**
```bash
docker compose up -d rust-api
curl http://localhost:8004/
curl http://localhost:8004/health/
```

**Example:**
```rust
// Type-safe async with Actix
#[get("/health")]
async fn health() -> impl Responder {
    let vault_status = check_vault().await;
    let db_status = check_database().await;

    HttpResponse::Ok().json(HealthResponse {
        status: "healthy",
        vault: vault_status,
        database: db_status,
    })
}
```

---

## Common Patterns Across All Implementations

### 1. Startup Initialization

All implementations follow this pattern:

1. Load environment configuration
2. Initialize Vault client
3. Fetch service credentials
4. Establish database connections
5. Set up connection pools
6. Configure middleware/logging
7. Start HTTP server

### 2. Service Layer Architecture

```
Application Structure (all languages):
├── main                    # Entry point
├── config                  # Environment configuration
├── services/               # Reusable service clients
│   ├── vault              # Vault integration
│   ├── database           # Database connections
│   ├── cache              # Redis client
│   └── messaging          # RabbitMQ client
├── routers/handlers/       # API endpoints
│   ├── health             # Health checks
│   ├── database_demo      # Database examples
│   ├── cache_demo         # Cache examples
│   └── messaging_demo     # Messaging examples
└── middleware/             # Request processing
    ├── logging            # Request logging
    ├── cors               # CORS handling
    └── error_handling     # Exception handling
```

### 3. Configuration Management

**Environment Variables:**
```bash
# All implementations read:
VAULT_ADDR=http://vault:8200
VAULT_TOKEN=hvs.xxxxxxxxxxxxx
POSTGRES_HOST=postgres
REDIS_HOST=redis-1
RABBITMQ_HOST=rabbitmq
```

**Configuration Loading:**
```python
# Python example
from pydantic import BaseSettings

class Settings(BaseSettings):
    vault_addr: str
    vault_token: str
    postgres_host: str = "postgres"

    class Config:
        env_file = ".env"

settings = Settings()
```

### 4. Dependency Injection

**Singleton Pattern:**
All implementations use singleton services:
- Vault client (single instance)
- Database connection pools
- Redis connection pool
- RabbitMQ connection

### 5. Error Handling

**Graceful Degradation:**
```python
# If Vault unavailable, log error but don't crash
try:
    creds = await vault_client.get_secret("postgres")
except VaultError:
    logger.error("Vault unavailable, using fallback")
    creds = get_fallback_credentials()
```

---

## Vault Integration in Applications

### Pattern: Lazy Loading Credentials

```python
# Python implementation
class VaultService:
    def __init__(self):
        self._client = None
        self._cache = {}

    @property
    def client(self):
        if not self._client:
            self._client = self._initialize_client()
        return self._client

    async def get_secret(self, path: str):
        if path not in self._cache:
            self._cache[path] = await self._fetch_secret(path)
        return self._cache[path]

    async def _fetch_secret(self, path: str):
        url = f"{self.vault_addr}/v1/secret/data/{path}"
        headers = {"X-Vault-Token": self.token}

        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
            return response.json()["data"]["data"]
```

### Go Implementation

```go
type VaultService struct {
    client *api.Client
    cache  map[string]interface{}
    mu     sync.RWMutex
}

func (v *VaultService) GetSecret(path string) (map[string]interface{}, error) {
    v.mu.RLock()
    if data, ok := v.cache[path]; ok {
        v.mu.RUnlock()
        return data, nil
    }
    v.mu.RUnlock()

    secret, err := v.client.Logical().Read("secret/data/" + path)
    if err != nil {
        return nil, err
    }

    data := secret.Data["data"].(map[string]interface{})

    v.mu.Lock()
    v.cache[path] = data
    v.mu.Unlock()

    return data, nil
}
```

---

## Database Connection Patterns

### PostgreSQL Connection Pool

**Python (asyncpg):**
```python
import asyncpg

class DatabaseService:
    def __init__(self):
        self._pool = None

    async def get_pool(self):
        if not self._pool:
            creds = await vault.get_secret("postgres")
            self._pool = await asyncpg.create_pool(
                host="postgres",
                user=creds["user"],
                password=creds["password"],
                database=creds["database"],
                min_size=5,
                max_size=20
            )
        return self._pool

    async def execute_query(self, query: str):
        pool = await self.get_pool()
        async with pool.acquire() as conn:
            return await conn.fetch(query)
```

**Go (pgx):**
```go
type DatabaseService struct {
    pool *pgxpool.Pool
}

func NewDatabaseService(ctx context.Context) (*DatabaseService, error) {
    creds, err := vaultService.GetSecret("postgres")
    if err != nil {
        return nil, err
    }

    connString := fmt.Sprintf(
        "postgres://%s:%s@postgres:5432/%s",
        creds["user"], creds["password"], creds["database"],
    )

    config, err := pgxpool.ParseConfig(connString)
    config.MaxConns = 20
    config.MinConns = 5

    pool, err := pgxpool.ConnectConfig(ctx, config)
    if err != nil {
        return nil, err
    }

    return &DatabaseService{pool: pool}, nil
}
```

**Node.js (pg):**
```javascript
const { Pool } = require('pg');

class DatabaseService {
  constructor() {
    this.pool = null;
  }

  async getPool() {
    if (!this.pool) {
      const creds = await vaultService.getSecret('postgres');
      this.pool = new Pool({
        host: 'postgres',
        user: creds.user,
        password: creds.password,
        database: creds.database,
        max: 20,
        min: 5
      });
    }
    return this.pool;
  }

  async query(sql) {
    const pool = await this.getPool();
    const result = await pool.query(sql);
    return result.rows;
  }
}
```

---

## Redis Cluster Operations

### Cluster-Aware Client

**Python (redis-py):**
```python
from redis.cluster import RedisCluster
from redis.cluster import ClusterNode

class RedisService:
    def __init__(self):
        self._client = None

    async def get_client(self):
        if not self._client:
            creds = await vault.get_secret("redis-1")

            startup_nodes = [
                ClusterNode("redis-1", 6379),
                ClusterNode("redis-2", 6379),
                ClusterNode("redis-3", 6379),
            ]

            self._client = RedisCluster(
                startup_nodes=startup_nodes,
                password=creds["password"],
                decode_responses=True,
                skip_full_coverage_check=True
            )
        return self._client

    async def set_with_ttl(self, key: str, value: str, ttl: int):
        client = await self.get_client()
        await client.setex(key, ttl, value)

    async def get_cluster_info(self):
        client = await self.get_client()
        return await client.cluster_info()
```

**Go (go-redis):**
```go
import "github.com/go-redis/redis/v8"

type RedisService struct {
    client *redis.ClusterClient
}

func NewRedisService(ctx context.Context) (*RedisService, error) {
    creds, err := vaultService.GetSecret("redis-1")
    if err != nil {
        return nil, err
    }

    client := redis.NewClusterClient(&redis.ClusterOptions{
        Addrs: []string{
            "redis-1:6379",
            "redis-2:6379",
            "redis-3:6379",
        },
        Password: creds["password"].(string),
    })

    // Test connection
    if err := client.Ping(ctx).Err(); err != nil {
        return nil, err
    }

    return &RedisService{client: client}, nil
}
```

---

## RabbitMQ Messaging

### Publisher Pattern

**Python (aio-pika):**
```python
import aio_pika
import json

class MessagingService:
    def __init__(self):
        self._connection = None
        self._channel = None

    async def get_channel(self):
        if not self._channel:
            creds = await vault.get_secret("rabbitmq")

            self._connection = await aio_pika.connect_robust(
                host="rabbitmq",
                port=5672,
                login=creds["user"],
                password=creds["password"],
                virtualhost=creds["vhost"]
            )

            self._channel = await self._connection.channel()
        return self._channel

    async def publish(self, queue: str, message: dict):
        channel = await self.get_channel()

        await channel.default_exchange.publish(
            aio_pika.Message(
                body=json.dumps(message).encode(),
                content_type="application/json"
            ),
            routing_key=queue
        )
```

**Node.js (amqplib):**
```javascript
const amqp = require('amqplib');

class MessagingService {
  constructor() {
    this.connection = null;
    this.channel = null;
  }

  async getChannel() {
    if (!this.channel) {
      const creds = await vaultService.getSecret('rabbitmq');

      const connUrl = `amqp://${creds.user}:${creds.password}@rabbitmq:5672/${creds.vhost}`;
      this.connection = await amqp.connect(connUrl);
      this.channel = await this.connection.createChannel();
    }
    return this.channel;
  }

  async publish(queue, message) {
    const channel = await this.getChannel();
    await channel.assertQueue(queue, { durable: true });
    channel.sendToQueue(queue, Buffer.from(JSON.stringify(message)));
  }
}
```

---

## Health Check Patterns

### Comprehensive Health Checks

All implementations provide `/health/all` endpoint checking:
- Vault connectivity
- PostgreSQL connectivity
- MySQL connectivity
- MongoDB connectivity
- Redis cluster status
- RabbitMQ connectivity

**Python Implementation:**
```python
@router.get("/health/all")
async def health_all():
    results = await asyncio.gather(
        check_vault(),
        check_postgres(),
        check_mysql(),
        check_mongodb(),
        check_redis(),
        check_rabbitmq(),
        return_exceptions=True
    )

    services = {
        "vault": results[0],
        "postgres": results[1],
        "mysql": results[2],
        "mongodb": results[3],
        "redis": results[4],
        "rabbitmq": results[5]
    }

    overall_status = "healthy" if all(
        s.get("status") == "healthy" for s in services.values()
    ) else "degraded"

    return {
        "status": overall_status,
        "services": services
    }
```

**Response Format:**
```json
{
  "status": "healthy",
  "services": {
    "vault": {
      "status": "healthy",
      "sealed": false
    },
    "postgres": {
      "status": "healthy",
      "version": "PostgreSQL 16.0"
    },
    "redis": {
      "status": "healthy",
      "cluster_state": "ok",
      "cluster_slots_assigned": 16384
    }
  }
}
```

---

## Error Handling

### Graceful Degradation

```python
# Python example
async def check_service(service_name: str):
    try:
        result = await perform_health_check(service_name)
        return {"status": "healthy", **result}
    except ConnectionError as e:
        logger.error(f"{service_name} connection failed: {e}")
        return {"status": "unhealthy", "error": str(e)}
    except Exception as e:
        logger.exception(f"Unexpected error checking {service_name}")
        return {"status": "unknown", "error": "Internal error"}
```

### Circuit Breaker Pattern

```python
# Prevent cascading failures
class CircuitBreaker:
    def __init__(self, max_failures=5, timeout=60):
        self.max_failures = max_failures
        self.timeout = timeout
        self.failures = 0
        self.last_failure_time = None
        self.state = "closed"  # closed, open, half-open

    async def call(self, func):
        if self.state == "open":
            if time.time() - self.last_failure_time > self.timeout:
                self.state = "half-open"
            else:
                raise CircuitBreakerOpen("Circuit breaker is open")

        try:
            result = await func()
            if self.state == "half-open":
                self.state = "closed"
                self.failures = 0
            return result
        except Exception as e:
            self.failures += 1
            self.last_failure_time = time.time()

            if self.failures >= self.max_failures:
                self.state = "open"
            raise e
```

---

## Code Examples

See the individual implementation directories for complete, working code:

- **Python:** `reference-apps/fastapi/` and `reference-apps/fastapi-api-first/`
- **Go:** `reference-apps/golang/`
- **Node.js:** `reference-apps/nodejs/`
- **Rust:** `reference-apps/rust/`

Each directory includes:
- Complete source code
- Dockerfile for containerization
- Dependencies file
- README with setup instructions
- Example usage

---

## Related Documentation

- **[Reference Applications](./Reference-Applications.md)** - Overview of all implementations
- **[Vault Integration](./Vault-Integration.md)** - Credential management
- **[Database Connections](./Service-Configuration.md)** - Database configuration
- **[Testing Guide](./Testing-Guide.md)** - Testing reference apps
- **[Network Architecture](./Network-Architecture.md)** - Service communication
- **[Health Monitoring](./Health-Monitoring.md)** - Health check patterns

---

## Summary

The reference implementations demonstrate:
- **Multiple approaches** - Code-first vs API-first workflows
- **Language diversity** - Python, Go, Node.js, Rust, TypeScript
- **Common patterns** - Consistent integration across stacks
- **Best practices** - Production-ready patterns (adapted for dev)
- **Complete examples** - Working code you can copy and adapt

All implementations are educational tools designed to help you learn integration patterns and bootstrap your own applications.
