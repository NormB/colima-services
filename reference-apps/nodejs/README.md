# Node.js Reference API

**⚠️ This is a reference implementation for learning and testing. Not intended for production use.**

A Node.js/Express application demonstrating infrastructure integration patterns with the Colima Services stack.

## Features

### Core Capabilities
- **Vault Integration**: Secure credential fetching using node-vault
- **Database Connections**: PostgreSQL, MySQL, MongoDB with Vault credentials
- **Caching**: Redis cluster operations with TTL support
- **Messaging**: RabbitMQ message publishing
- **Health Monitoring**: Comprehensive health checks for all services
- **Observability**: Prometheus metrics, structured logging with Winston
- **Security**: Helmet, CORS, request ID correlation

### Node.js-Specific Features
- **Async/Await**: Modern asynchronous patterns throughout
- **Promise.allSettled**: Concurrent health checks
- **Express Middleware**: Modular request processing
- **Graceful Shutdown**: Signal handling for clean termination
- **Structured Logging**: JSON logging with correlation IDs

## Quick Start

```bash
# Start the Node.js reference API
docker compose up -d nodejs-api

# Verify it's running
curl http://localhost:8003/

# Check infrastructure health
curl http://localhost:8003/health/all

# Test Vault integration
curl http://localhost:8003/examples/vault/secret/postgres
```

## API Endpoints

### Root
- `GET /` - API information and endpoint listing

### Health Checks (`/health`)
- `GET /health/` - Simple health check (no dependencies)
- `GET /health/all` - Aggregate health of all services (concurrent checks)
- `GET /health/vault` - Vault connectivity and status
- `GET /health/postgres` - PostgreSQL connection test
- `GET /health/mysql` - MySQL connection test
- `GET /health/mongodb` - MongoDB connection test
- `GET /health/redis` - Redis cluster health
- `GET /health/rabbitmq` - RabbitMQ connectivity

### Vault Integration (`/examples/vault`)
- `GET /examples/vault/secret/:serviceName` - Fetch all secrets for a service
- `GET /examples/vault/secret/:serviceName/:key` - Fetch specific secret key

### Database Operations (`/examples/database`)
- `GET /examples/database/postgres/query` - PostgreSQL query example
- `GET /examples/database/mysql/query` - MySQL query example
- `GET /examples/database/mongodb/query` - MongoDB query example

### Caching (`/examples/cache`)
- `GET /examples/cache/:key` - Get cached value
- `POST /examples/cache/:key` - Set cached value (with optional TTL)
- `DELETE /examples/cache/:key` - Delete cached value

### Messaging (`/examples/messaging`)
- `POST /examples/messaging/publish/:queue` - Publish message to RabbitMQ queue

### Metrics
- `GET /metrics` - Prometheus metrics endpoint

## Architecture

```
reference-apps/nodejs/
├── src/
│   ├── index.js              # Application entry point
│   ├── config.js             # Environment configuration
│   ├── routes/               # API endpoints
│   │   ├── health.js         # Health checks
│   │   ├── vault.js          # Vault integration examples
│   │   ├── database.js       # Database examples
│   │   ├── cache.js          # Redis caching
│   │   └── messaging.js      # RabbitMQ messaging
│   ├── services/             # Reusable clients
│   │   └── vault.js          # Vault client wrapper
│   └── middleware/           # Express middleware
│       ├── logging.js        # Request logging with correlation IDs
│       └── cors.js           # CORS configuration
├── tests/                    # Test suite
├── Dockerfile               # Container build
├── package.json             # Dependencies
└── README.md               # This file
```

## Key Integration Patterns

### Fetching Secrets from Vault

```javascript
const { vaultClient } = require('./services/vault');

// Get all credentials for a service
const creds = await vaultClient.getSecret('postgres');
const { user, password, database } = creds;

// Get a specific key
const password = await vaultClient.getSecretKey('postgres', 'password');
```

### Database Connections with Vault

```javascript
const { Client } = require('pg');
const { vaultClient } = require('./services/vault');

// Fetch credentials from Vault
const creds = await vaultClient.getSecret('postgres');

// Connect using Vault credentials
const client = new Client({
  host: 'postgres',
  port: 5432,
  user: creds.user,
  password: creds.password,
  database: creds.database
});

await client.connect();
const result = await client.query('SELECT NOW()');
await client.end();
```

### Redis Caching

```javascript
const { createClient } = require('redis');
const { vaultClient } = require('./services/vault');

// Get Redis credentials
const creds = await vaultClient.getSecret('redis-1');

// Connect to Redis
const client = createClient({
  socket: { host: 'redis-1', port: 6379 },
  password: creds.password
});

await client.connect();

// Use cache
await client.setEx('key', 60, 'value'); // Set with 60s TTL
const value = await client.get('key');

await client.quit();
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HTTP_PORT` | `8003` | HTTP server port |
| `HTTPS_PORT` | `8446` | HTTPS server port (when TLS enabled) |
| `NODE_ENV` | `development` | Environment (development/production) |
| `DEBUG` | `true` | Enable debug logging |
| `VAULT_ADDR` | `http://vault:8200` | Vault server address |
| `VAULT_TOKEN` | - | Vault authentication token |
| `POSTGRES_HOST` | `postgres` | PostgreSQL hostname |
| `MYSQL_HOST` | `mysql` | MySQL hostname |
| `MONGODB_HOST` | `mongodb` | MongoDB hostname |
| `REDIS_HOST` | `redis-1` | Redis hostname |
| `RABBITMQ_HOST` | `rabbitmq` | RabbitMQ hostname |

## Development

### Local Development

```bash
# Install dependencies
cd reference-apps/nodejs
npm install

# Run locally (requires infrastructure running)
export VAULT_TOKEN=$(cat ~/.config/vault/token)
npm start

# Development mode with auto-reload
npm run dev
```

### Testing

```bash
# Run tests
npm test

# Run tests in watch mode
npm run test:watch

# Run with coverage
npm test -- --coverage
```

## Comparison with Other Implementations

| Feature | Python (FastAPI) | Go (Gin) | Node.js (Express) |
|---------|------------------|----------|-------------------|
| **Port** | 8000/8001 | 8002 | 8003 |
| **Async Model** | async/await | goroutines | async/await, Promises |
| **Concurrency** | asyncio | native goroutines | Promise.allSettled |
| **Vault Client** | hvac | hashicorp/vault | node-vault |
| **PostgreSQL** | asyncpg | pgx | pg |
| **Redis** | redis-py | go-redis | redis (node) |
| **Logging** | Python logging | logrus | winston |
| **Metrics** | prometheus_client | prometheus/client_golang | prom-client |

## What This Demonstrates

✅ **Secrets Management** - Vault integration for dynamic credentials
✅ **Database Integration** - PostgreSQL, MySQL, MongoDB with Vault
✅ **Caching Patterns** - Redis cluster operations
✅ **Message Queuing** - RabbitMQ publishing
✅ **Health Monitoring** - Comprehensive service health checks
✅ **Observability** - Structured logging and Prometheus metrics
✅ **Node.js Best Practices** - Modern async patterns, middleware, error handling

## What This Is NOT

❌ **Not production-ready** - Missing security hardening, rate limiting improvements
❌ **Not feature-complete** - Focuses on integration patterns, not business logic
❌ **Not optimized** - Simple implementations for learning
❌ **Not secure** - Uses root Vault token for simplicity

## Security Notes

For learning only:
- ⚠️ Uses Vault root token (use AppRole in production)
- ⚠️ No authentication/authorization on endpoints
- ⚠️ Limited input validation
- ⚠️ Debug mode enabled

## Documentation Links

- **Main README**: [../../README.md](../../README.md)
- **Reference Apps Overview**: [../README.md](../README.md)
- **API Patterns**: [../API_PATTERNS.md](../API_PATTERNS.md)
- **CHANGELOG**: [../CHANGELOG.md](../CHANGELOG.md)

## Quick Examples

### Check All Services
```bash
curl http://localhost:8003/health/all | jq '.services'
```

### Fetch PostgreSQL Credentials
```bash
curl http://localhost:8003/examples/vault/secret/postgres | jq '.data'
```

### Test Database Connection
```bash
curl http://localhost:8003/examples/database/postgres/query | jq '.'
```

### Cache Operations
```bash
# Set a value with 60s TTL
curl -X POST http://localhost:8003/examples/cache/mykey \
  -H "Content-Type: application/json" \
  -d '{"value": "hello", "ttl": 60}'

# Get the value
curl http://localhost:8003/examples/cache/mykey | jq '.'

# Delete the value
curl -X DELETE http://localhost:8003/examples/cache/mykey | jq '.'
```

### Publish Message
```bash
curl -X POST http://localhost:8003/examples/messaging/publish/test-queue \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from Node.js!"}'
```

## Summary

This Node.js reference implementation demonstrates:
- 📚 Modern JavaScript/Node.js patterns for infrastructure integration
- 🔍 How to integrate Express applications with Vault, databases, caching, and messaging
- 🚀 Async/await patterns for clean asynchronous code
- ✅ Comprehensive health monitoring and observability

**Remember**: This is a learning resource. Use these patterns to build your own production-ready applications with proper security, monitoring, and error handling.
