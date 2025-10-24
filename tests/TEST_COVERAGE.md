# Test Suite Coverage

This document describes the comprehensive test coverage for the Colima Services infrastructure.

## Test Suites

### 1. Vault Integration Tests (`test-vault.sh`)
**10 tests** - Core infrastructure security and certificate management

- Vault container running
- Vault auto-unseal functionality
- Vault keys and token file existence
- PKI bootstrap (Root CA, Intermediate CA)
- Certificate roles for all services
- Service credentials stored in Vault
- PostgreSQL credentials validation
- Certificate issuance functionality
- CA certificate export
- Management script commands

### 2. Database Integration Tests

#### PostgreSQL (`test-postgres.sh`)
**Tests:** PostgreSQL container, Vault credential integration, connectivity

#### MySQL (`test-mysql.sh`)
**Tests:** MySQL container, Vault credential integration, connectivity

#### MongoDB (`test-mongodb.sh`)
**Tests:** MongoDB container, Vault credential integration, connectivity

### 3. Redis Cluster Tests (`test-redis-cluster.sh`)
**12 tests** - Comprehensive cluster configuration and operations

- All 3 Redis containers running
- Node reachability (PING test)
- Cluster mode enabled on all nodes
- Cluster initialization state (OK)
- All 16384 hash slots assigned
- 3 master nodes present
- Slot distribution across masters
- Data sharding functionality
- Automatic redirection with `-c` flag
- Vault password integration
- Comprehensive cluster health check
- Keyslot calculation

**What it validates:**
- Proper cluster initialization
- Complete slot coverage
- Data distribution and retrieval
- Cross-node operations
- Vault-managed authentication

### 4. RabbitMQ Integration Tests (`test-rabbitmq.sh`)
**Tests:** RabbitMQ container, Vault credential integration, messaging functionality

### 5. FastAPI Reference Application Tests (`test-fastapi.sh`)
**14 tests** - Comprehensive API and integration testing

#### Container & Endpoints
1. FastAPI container running
2. HTTP endpoint accessible (port 8000)
3. HTTPS endpoint accessible when TLS enabled (port 8443)
4. Health check endpoint (`/health/all`)

#### Redis Cluster API Tests
5. Redis health check with cluster details
   - Validates `cluster_enabled: true`
   - Validates `cluster_state: ok`
   - Validates `total_nodes: 3`

6. Redis cluster nodes API (`/redis/cluster/nodes`)
   - Returns all 3 nodes
   - All nodes have slot assignments
   - Node IDs, roles, and slot ranges present

7. Redis cluster slots API (`/redis/cluster/slots`)
   - 16384 total slots
   - 100% coverage
   - Slot distribution across masters

8. Redis cluster info API (`/redis/cluster/info`)
   - Cluster state: ok
   - All slots assigned
   - Cluster statistics present

9. Per-node info API (`/redis/nodes/{node_name}/info`)
   - Detailed node information
   - Redis version present
   - Cluster enabled flag correct

#### API Documentation Tests
10. Swagger UI accessible (`/docs`)
11. OpenAPI schema valid and accessible (`/openapi.json`)

#### Service Integration Tests
12. Vault integration (health check)
13. Database connectivity (PostgreSQL, MySQL, MongoDB)
14. RabbitMQ integration

**What it validates:**
- All new Redis Cluster inspection APIs work correctly
- Dual HTTP/HTTPS support
- Health checks return cluster information
- All service integrations functional
- API documentation generated correctly

## Running Tests

### Run All Tests
```bash
./tests/run-all-tests.sh
```

This runs all test suites in sequence and provides a comprehensive summary.

### Run Individual Test Suites
```bash
# Infrastructure
./tests/test-vault.sh

# Databases
./tests/test-postgres.sh
./tests/test-mysql.sh
./tests/test-mongodb.sh

# Cache & Messaging
./tests/test-redis-cluster.sh
./tests/test-rabbitmq.sh

# Application
./tests/test-fastapi.sh
```

## Test Dependencies

### Required System Tools
- `curl` - HTTP client (usually pre-installed)
- `jq` - JSON processor
  ```bash
  # macOS
  brew install jq

  # Ubuntu/Debian
  apt-get install jq
  ```

### Python Dependencies
```bash
pip3 install -r tests/requirements.txt
```

Includes:
- `psycopg2-binary` - PostgreSQL client library

## Test Results Format

Each test suite provides:
- Real-time test execution output
- Color-coded pass/fail indicators (green ✓ / red ✗)
- Summary with total tests, passed, and failed counts
- List of failed tests (if any)

Example output:
```
=========================================
  FastAPI Reference App Test Suite
=========================================

[TEST] Test 1: FastAPI container is running
[PASS] FastAPI container is running

[TEST] Test 5: Redis health check with cluster details
[PASS] Redis health shows cluster enabled with 3 nodes in ok state

[TEST] Test 7: Redis cluster slots API endpoint
[PASS] Redis cluster slots API shows 100% coverage (16384 slots)

=========================================
  Test Results
=========================================
Total tests: 14
Passed: 13

✓ All FastAPI tests passed!
```

## New Test Coverage (This Update)

### Redis Cluster Testing
- **New test suite:** `test-redis-cluster.sh` (12 tests)
- Validates complete cluster initialization
- Tests data sharding and automatic redirection
- Verifies slot distribution and coverage
- Validates Vault password integration

### FastAPI Application Testing
- **New test suite:** `test-fastapi.sh` (14 tests)
- Tests all 4 new Redis Cluster API endpoints
- Validates HTTP/HTTPS dual-mode operation
- Tests health checks with cluster information
- Validates OpenAPI documentation generation
- Tests all service integrations (Vault, databases, messaging)

### Updated Test Runner
- **Updated:** `run-all-tests.sh`
- Now runs all 7 test suites
- Organized by category (Infrastructure, Databases, Cache, Messaging, Application)
- Comprehensive summary across all suites

## Coverage Summary

| Component | Test Suite | Tests | Coverage |
|-----------|-----------|-------|----------|
| Vault | test-vault.sh | 10 | PKI, secrets, certificates, auto-unseal |
| PostgreSQL | test-postgres.sh | ~5 | Container, credentials, connectivity |
| MySQL | test-mysql.sh | ~5 | Container, credentials, connectivity |
| MongoDB | test-mongodb.sh | ~5 | Container, credentials, connectivity |
| Redis Cluster | test-redis-cluster.sh | 12 | Cluster init, slots, sharding, failover |
| RabbitMQ | test-rabbitmq.sh | ~5 | Container, credentials, messaging |
| FastAPI App | test-fastapi.sh | 14 | APIs, health, cluster endpoints, docs |

**Total: ~56+ tests** across all infrastructure components and application layers.

## Continuous Testing

Run tests after:
- Initial infrastructure setup
- Service configuration changes
- Certificate regeneration
- Vault bootstrap
- Container restarts
- Application deployments

This ensures all components remain properly configured and integrated.
