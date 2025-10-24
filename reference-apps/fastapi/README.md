# FastAPI Reference Application

**⚠️ This is a reference implementation for learning and testing. Not intended for production use.**

This FastAPI application demonstrates best practices for integrating with the Colima Services infrastructure:

- **Vault Integration**: Fetching secrets securely
- **Database Connections**: PostgreSQL, MySQL, MongoDB examples
- **Caching**: Redis cluster integration
- **Messaging**: RabbitMQ pub/sub patterns
- **Health Monitoring**: Comprehensive health checks for all services

## Features

### Health Checks (`/health/*`)
- `/health/all` - Check all services
- `/health/vault` - Vault status
- `/health/postgres` - PostgreSQL connectivity
- `/health/mysql` - MySQL connectivity
- `/health/mongodb` - MongoDB connectivity
- `/health/redis` - Redis cluster status
- `/health/rabbitmq` - RabbitMQ status

### Examples

#### Vault (`/examples/vault/*`)
- `/examples/vault/secret/{service}` - Fetch service credentials
- `/examples/vault/secret/{service}/{key}` - Fetch specific credential field

#### Databases (`/examples/database/*`)
- `/examples/database/postgres/query` - PostgreSQL example query
- `/examples/database/mysql/query` - MySQL example query
- `/examples/database/mongodb/query` - MongoDB example query

#### Caching (`/examples/cache/*`)
- `GET /examples/cache/{key}` - Get cached value
- `POST /examples/cache/{key}?value=...&ttl=60` - Set cached value with optional TTL
- `DELETE /examples/cache/{key}` - Delete cached value

#### Messaging (`/examples/messaging/*`)
- `POST /examples/messaging/publish?queue_name=...` - Publish message to queue
- `GET /examples/messaging/queue/{queue}/info` - Get queue information

## API Documentation

Once running, visit:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## Quick Start

### Running in Docker (Recommended)

The application is included in the main `docker-compose.yml`:

```bash
docker compose up -d reference-api
```

### Access the API

```bash
# Check all services health
curl http://localhost:8000/health/all

# Get credentials from Vault (passwords masked)
curl http://localhost:8000/examples/vault/secret/postgres

# Test PostgreSQL connection
curl http://localhost:8000/examples/database/postgres/query

# Use Redis cache
curl -X POST "http://localhost:8000/examples/cache/mykey?value=hello&ttl=60"
curl http://localhost:8000/examples/cache/mykey
```

## Development

### Local Development

```bash
cd reference-apps/fastapi

# Install dependencies
pip install -r requirements.txt

# Set environment variables
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# Run the application
uvicorn app.main:app --reload
```

### Running Tests

```bash
pytest tests/
```

## Integration Patterns

### Fetching Secrets from Vault

```python
from app.services.vault import vault_client

# Get all credentials for a service
creds = await vault_client.get_secret("postgres")
user = creds.get("user")
password = creds.get("password")

# Get specific key
password = await vault_client.get_secret("postgres", key="password")
```

### Database Connections

```python
import asyncpg
from app.services.vault import vault_client

# Fetch credentials
creds = await vault_client.get_secret("postgres")

# Connect
conn = await asyncpg.connect(
    host="postgres",
    port=5432,
    user=creds.get("user"),
    password=creds.get("password"),
    database=creds.get("database")
)

# Execute query
result = await conn.fetch("SELECT * FROM users")
await conn.close()
```

### Redis Caching

```python
import redis.asyncio as redis
from app.services.vault import vault_client

# Get Redis credentials
creds = await vault_client.get_secret("redis-1")

# Connect
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

### RabbitMQ Messaging

```python
import aio_pika
import json
from app.services.vault import vault_client

# Get RabbitMQ credentials
creds = await vault_client.get_secret("rabbitmq")

# Connect
url = f"amqp://{creds.get('user')}:{creds.get('password')}@rabbitmq:5672/"
connection = await aio_pika.connect_robust(url)
channel = await connection.channel()

# Publish message
await channel.default_exchange.publish(
    aio_pika.Message(body=json.dumps({"hello": "world"}).encode()),
    routing_key="my-queue"
)

await connection.close()
```

## Architecture

```
reference-apps/fastapi/
├── app/
│   ├── main.py              # FastAPI application
│   ├── config.py            # Configuration from environment
│   ├── routers/             # API endpoints
│   │   ├── health.py        # Health check endpoints
│   │   ├── vault_demo.py    # Vault examples
│   │   ├── database_demo.py # Database examples
│   │   ├── cache_demo.py    # Redis examples
│   │   └── messaging_demo.py # RabbitMQ examples
│   └── services/            # Reusable service clients
│       └── vault.py         # Vault client
├── tests/
│   └── integration/         # Integration tests
├── Dockerfile
├── requirements.txt
└── README.md
```

## Environment Variables

All configuration is handled via environment variables:

```bash
# Vault
VAULT_ADDR=http://vault:8200
VAULT_TOKEN=<your-vault-token>

# Service endpoints (Docker network)
POSTGRES_HOST=postgres
MYSQL_HOST=mysql
MONGODB_HOST=mongodb
REDIS_HOST=redis-1
RABBITMQ_HOST=rabbitmq
```

## Notes

- This is a **reference implementation** to demonstrate integration patterns
- Credentials are fetched from Vault at runtime
- All examples use async/await for better performance
- Health checks validate full connectivity to infrastructure services
- Not production-ready - use as a learning resource

## See Also

- Main infrastructure README: `../../README.md`
- Vault integration guide: `../../README.md#vault-pki-integration`
- TLS configuration: `../../README.md#ssltls-certificate-management`
