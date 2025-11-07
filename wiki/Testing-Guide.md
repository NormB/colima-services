# Testing Guide

Comprehensive guide to the 370+ test suites, testing philosophy, running tests, and troubleshooting test failures.

---

## Table of Contents

1. [Overview](#overview)
2. [Test Suite Overview](#test-suite-overview)
3. [Running All Tests](#running-all-tests)
4. [Running Specific Test Suites](#running-specific-test-suites)
5. [Bash Integration Tests](#bash-integration-tests)
6. [Python Unit Tests](#python-unit-tests)
7. [Python Parity Tests](#python-parity-tests)
8. [Test Philosophy and Approach](#test-philosophy-and-approach)
9. [Prerequisites](#prerequisites)
10. [Troubleshooting Test Failures](#troubleshooting-test-failures)
11. [Related Documentation](#related-documentation)

---

## Overview

The DevStack Core project includes **comprehensive test coverage** with 370+ tests across multiple test suites validating infrastructure, services, and applications.

### Test Coverage Summary

| Component | Tests | Type | Coverage |
|-----------|-------|------|----------|
| **Vault** | 10 | Bash integration | PKI, secrets, auto-unseal |
| **PostgreSQL** | ~10 | Bash integration | Credentials, connectivity, SSL |
| **MySQL** | ~9 | Bash integration | Credentials, connectivity, SSL |
| **MongoDB** | ~10 | Bash integration | Credentials, connectivity, SSL |
| **Redis Cluster** | 12 | Bash integration | Cluster init, slots, sharding |
| **RabbitMQ** | ~5 | Bash integration | Messaging, credentials |
| **FastAPI** | 14 | Bash integration | APIs, endpoints, health checks |
| **FastAPI Unit Tests** | 254 | Python pytest | Services, routers, middleware |
| **Parity Tests** | 64 | Python pytest | API implementation consistency |

**Total:** 370+ tests validating all aspects of the infrastructure.

---

## Test Suite Overview

### Test Categories

**1. Infrastructure Tests**
- Vault PKI and secrets management
- Auto-unseal functionality
- Certificate issuance

**2. Database Tests**
- Container health checks
- Credential retrieval from Vault
- External client connectivity
- SSL/TLS verification

**3. Cache Layer Tests**
- Redis cluster initialization
- Slot distribution and coverage
- Data sharding and redirection
- Vault password integration

**4. Messaging Tests**
- RabbitMQ queue operations
- Message publishing and consumption

**5. Application Tests**
- HTTP/HTTPS endpoint availability
- Health check responses
- Service integrations
- API documentation generation

**6. Unit Tests**
- Service layer logic
- Router functionality
- Middleware processing
- Exception handling
- Request validation

**7. Parity Tests**
- Identical behavior across implementations
- Response structure consistency
- Error handling uniformity

---

## Running All Tests

### Quick Start

```bash
# Run all 370+ tests
./tests/run-all-tests.sh

# Expected output:
=========================================
  Running All Infrastructure Tests
=========================================

[1/7] Vault Tests...
✓ All Vault tests passed (10/10)

[2/7] PostgreSQL Tests...
✓ All PostgreSQL tests passed (10/10)

[3/7] MySQL Tests...
✓ All MySQL tests passed (9/9)

[4/7] MongoDB Tests...
✓ All MongoDB tests passed (10/10)

[5/7] Redis Cluster Tests...
✓ All Redis cluster tests passed (12/12)

[6/7] RabbitMQ Tests...
✓ All RabbitMQ tests passed (5/5)

[7/7] FastAPI Tests...
✓ All FastAPI tests passed (14/14)

=========================================
  Summary
=========================================
Total test suites: 7
Passed: 7
Failed: 0

✓ All tests passed!
```

### Auto-Starting Containers

The test runner automatically starts required containers if they're not running:

```bash
# Tests will auto-start these if needed
docker compose up -d reference-api api-first

# Then run all tests
./tests/run-all-tests.sh
```

### Test Output Features

- **Color-coded results** - Green for pass, red for fail
- **Real-time progress** - See tests as they run
- **Comprehensive summary** - Overall pass/fail counts
- **Failed test details** - Specific failures listed

---

## Running Specific Test Suites

### Bash Integration Tests

Each service has its own test script:

```bash
# Vault tests (10 tests)
./tests/test-vault.sh

# PostgreSQL tests (~10 tests)
./tests/test-postgres.sh

# MySQL tests (~9 tests)
./tests/test-mysql.sh

# MongoDB tests (~10 tests)
./tests/test-mongodb.sh

# Redis cluster tests (12 tests)
./tests/test-redis-cluster.sh

# RabbitMQ tests (~5 tests)
./tests/test-rabbitmq.sh

# FastAPI application tests (14 tests)
./tests/test-fastapi.sh
```

### Python Unit Tests (Inside Container)

```bash
# Start container first
docker compose up -d reference-api

# Run all unit tests (254 tests: 178 passed, 76 skipped)
docker exec dev-reference-api pytest tests/ -v

# Run with coverage report
docker exec dev-reference-api pytest tests/ --cov=app --cov-report=term-missing

# Run specific test file
docker exec dev-reference-api pytest tests/test_health.py -v

# Run specific test function
docker exec dev-reference-api pytest tests/test_health.py::test_health_endpoint -v
```

### Python Parity Tests (From Host)

```bash
# Change to test suite directory
cd reference-apps/shared/test-suite

# Install dependencies with uv
uv run pytest -v

# Or with pip
pip install -r requirements.txt
pytest -v

# Expected: 64 tests (140 test runs with parametrization)
```

---

## Bash Integration Tests

### Philosophy: External Client Testing

All bash tests use **real external clients**, not `docker exec`:

**Why?**
- ✅ Tests actual network stack
- ✅ Validates SSL/TLS properly
- ✅ Catches firewall/routing issues
- ✅ Verifies encryption end-to-end
- ✅ Production-like testing

**Why NOT docker exec?**
- ❌ Bypasses network layer
- ❌ Can't validate certificates
- ❌ Misses routing issues
- ❌ Doesn't test SSL/TLS

### Example: PostgreSQL Test

```bash
#!/bin/bash
# tests/test-postgres.sh

# Test 1: Container is running
test_container_running() {
    docker ps | grep -q dev-postgres
    echo "✓ PostgreSQL container is running"
}

# Test 2: Fetch credentials from Vault (external client)
test_vault_credentials() {
    PASSWORD=$(vault kv get -field=password secret/postgres)
    echo "✓ Retrieved password from Vault"
}

# Test 3: Connect from host (external client, not docker exec)
test_external_connection() {
    PGPASSWORD=$PASSWORD psql -h localhost -U dev_admin -d dev_database -c "SELECT 1;" > /dev/null
    echo "✓ External psql connection successful"
}

# Test 4: SSL connection
test_ssl_connection() {
    PGPASSWORD=$PASSWORD psql "postgresql://dev_admin@localhost:5432/dev_database?sslmode=require" -c "SELECT 1;" > /dev/null
    echo "✓ SSL connection successful"
}
```

### Test Output Example

```bash
$ ./tests/test-postgres.sh

=========================================
  PostgreSQL Test Suite
=========================================

[TEST] Test 1: PostgreSQL container is running
[PASS] PostgreSQL container is running

[TEST] Test 2: Retrieve credentials from Vault
[PASS] Retrieved password from Vault

[TEST] Test 3: External psql connection
[PASS] External psql connection successful

[TEST] Test 4: SSL connection
[PASS] SSL connection successful

=========================================
  Test Results
=========================================
Total tests: 10
Passed: 10
Failed: 0

✓ All PostgreSQL tests passed!
```

---

## Python Unit Tests

### Running Inside Docker Container

**IMPORTANT:** Unit tests **must** run inside the Docker container to use the correct Python 3.11 environment and avoid build issues.

```bash
# Correct approach: Run inside container
docker exec dev-reference-api pytest tests/ -v

# Incorrect approach: Run from host
# cd reference-apps/fastapi && pytest tests/  # ❌ Wrong Python version, missing dependencies
```

### Test Organization

```
reference-apps/fastapi/tests/
├── __init__.py
├── conftest.py              # Pytest fixtures and configuration
├── test_health.py           # Health check endpoint tests
├── test_database_demo.py    # Database integration tests
├── test_cache_demo.py       # Redis cache tests
├── test_messaging_demo.py   # RabbitMQ tests
├── test_redis_cluster.py    # Redis cluster endpoint tests
├── test_vault_service.py    # Vault service tests
├── test_middleware.py       # Middleware tests
├── test_exceptions.py       # Exception handling tests
└── ... (16 test files total)
```

### Test Coverage

```bash
# Run with coverage report
docker exec dev-reference-api pytest tests/ --cov=app --cov-report=html

# View coverage report
open reference-apps/fastapi/htmlcov/index.html

# Expected coverage: ~84%
```

### Example: Health Check Test

```python
# tests/test_health.py
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_endpoint():
    """Test basic health check returns 200"""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

def test_health_all_services():
    """Test comprehensive health check includes all services"""
    response = client.get("/health/all")
    assert response.status_code == 200

    data = response.json()
    assert "vault" in data["services"]
    assert "postgres" in data["services"]
    assert "redis" in data["services"]
    assert data["services"]["vault"]["status"] == "healthy"
```

### Running Specific Test Categories

```bash
# Run only database tests
docker exec dev-reference-api pytest tests/ -k database -v

# Run only Redis tests
docker exec dev-reference-api pytest tests/ -k redis -v

# Run only health check tests
docker exec dev-reference-api pytest tests/test_health.py -v

# Run tests matching pattern
docker exec dev-reference-api pytest tests/ -k "test_vault" -v
```

---

## Python Parity Tests

### Purpose

Validate **100% behavioral parity** between FastAPI code-first (port 8000) and API-first (port 8001) implementations.

### Why Run From Host?

Parity tests **must** run from the host machine because:
- ✅ Need to access `localhost:8000` and `localhost:8001`
- ✅ Compare responses from both implementations
- ✅ Verify API contracts are identical
- ❌ Cannot access `localhost` from inside containers

### Test Organization

```
reference-apps/shared/test-suite/
├── requirements.txt          # Test dependencies
├── conftest.py              # Shared fixtures
├── test_api_parity.py       # Endpoint parity validation
├── test_database_parity.py  # Database endpoint parity
├── test_redis_parity.py     # Redis endpoint parity
├── test_messaging_parity.py # RabbitMQ endpoint parity
└── test_health_parity.py    # Health check parity
```

### Running Parity Tests

```bash
# Prerequisites
docker compose up -d reference-api api-first

# Change directory
cd reference-apps/shared/test-suite

# Option 1: Run with uv (recommended)
command -v uv || brew install uv
uv run pytest -v

# Option 2: Run with pip
pip install -r requirements.txt
pytest -v

# Expected: 64 tests, 140 test runs (with parametrization)
```

### Example: Parity Test

```python
# test_api_parity.py
import pytest
import requests

BASE_URLS = [
    "http://localhost:8000",  # Code-first
    "http://localhost:8001",  # API-first
]

@pytest.mark.parametrize("base_url", BASE_URLS)
def test_health_endpoint_parity(base_url):
    """Verify both implementations return identical health responses"""
    response = requests.get(f"{base_url}/health")

    assert response.status_code == 200
    data = response.json()

    # Both must have same structure
    assert "status" in data
    assert data["status"] == "healthy"

@pytest.mark.parametrize("base_url", BASE_URLS)
def test_redis_cluster_info_parity(base_url):
    """Verify both implementations return identical cluster info"""
    response = requests.get(f"{base_url}/redis/cluster/info")

    assert response.status_code == 200
    data = response.json()

    # Both must report same cluster state
    assert data["cluster_state"] == "ok"
    assert data["cluster_slots_assigned"] == 16384
```

### Parity Test Output

```bash
$ cd reference-apps/shared/test-suite && uv run pytest -v

test_api_parity.py::test_health[http://localhost:8000] PASSED
test_api_parity.py::test_health[http://localhost:8001] PASSED
test_database_parity.py::test_postgres[http://localhost:8000] PASSED
test_database_parity.py::test_postgres[http://localhost:8001] PASSED
test_redis_parity.py::test_cluster_info[http://localhost:8000] PASSED
test_redis_parity.py::test_cluster_info[http://localhost:8001] PASSED

================================ 64 passed in 2.5s ================================
```

---

## Test Philosophy and Approach

### External Client Testing

**Principle:** Test from the outside, like real applications would connect.

**Bash Integration Tests:**
- ✅ Use `psql` from host (not `docker exec`)
- ✅ Use `mysql` from host
- ✅ Use `redis-cli` from host
- ✅ Use `curl` for HTTP APIs

**Why?**
This tests:
- Network routing
- Port exposure
- Firewall rules
- SSL/TLS encryption
- Certificate validation
- Real-world connectivity

### Test Independence

Each test should be **independent** and **idempotent**:
- ✅ Tests can run in any order
- ✅ Tests don't depend on previous tests
- ✅ Tests clean up after themselves
- ✅ Tests can be run multiple times

### Test Coverage Goals

**What We Test:**
- ✅ Service availability (containers running)
- ✅ Network connectivity (can reach services)
- ✅ Credential retrieval (Vault integration)
- ✅ Database operations (queries work)
- ✅ Cache operations (Redis cluster)
- ✅ Message queue operations (RabbitMQ)
- ✅ API endpoints (HTTP/HTTPS)
- ✅ Health checks (all services)
- ✅ SSL/TLS (when enabled)

**What We Don't Test:**
- ❌ Performance/load testing (separate benchmarks)
- ❌ Security penetration testing
- ❌ Disaster recovery scenarios
- ❌ Multi-node cluster failover (dev environment)

---

## Prerequisites

### System Dependencies

**macOS:**
```bash
# Package manager
brew install jq

# Database clients
brew install postgresql@16  # Provides psql
brew install mysql-client   # Provides mysql
brew install mongosh        # MongoDB shell
brew install redis          # Provides redis-cli

# Python package manager for parity tests
brew install uv
```

**Ubuntu/Debian:**
```bash
# JSON processor
sudo apt-get install jq

# Database clients
sudo apt-get install postgresql-client
sudo apt-get install mysql-client
sudo apt-get install mongodb-clients
sudo apt-get install redis-tools

# Python tools
pip install uv
```

### Python Dependencies

**For Unit Tests (inside container):**
Dependencies are already installed in the Docker image.

**For Parity Tests (from host):**
```bash
cd reference-apps/shared/test-suite
pip install -r requirements.txt

# Or with uv
uv run pytest -v  # Auto-installs dependencies
```

### Docker Containers

```bash
# Start required containers for tests
docker compose up -d reference-api api-first

# Verify containers are running
docker ps | grep -E "(reference-api|api-first)"
```

---

## Troubleshooting Test Failures

### Common Test Failures

#### 1. Vault Not Bootstrapped

**Symptoms:**
```bash
[FAIL] Could not retrieve credentials from Vault
Error: No value found at secret/data/postgres
```

**Solution:**
```bash
# Bootstrap Vault with service credentials
./manage-devstack.sh vault-bootstrap

# Restart failing services
docker compose restart postgres mysql mongodb redis-1 redis-2 redis-3
```

#### 2. Containers Not Running

**Symptoms:**
```bash
[FAIL] PostgreSQL container is not running
```

**Solution:**
```bash
# Check which containers are down
docker ps -a | grep -v "Up"

# Start all services
docker compose up -d

# Check health
./manage-devstack.sh health
```

#### 3. Network Connectivity Issues

**Symptoms:**
```bash
[FAIL] Connection to postgres port 5432 failed
curl: (7) Failed to connect to localhost port 8000
```

**Solution:**
```bash
# Check port is exposed
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep postgres

# Test from inside container (should work)
docker exec dev-reference-api nc -zv postgres 5432

# Test from host (may fail if port not exposed)
nc -zv localhost 5432

# Restart Docker if needed
docker compose restart
```

#### 4. Credential Mismatch

**Symptoms:**
```bash
[FAIL] psql: FATAL: password authentication failed
```

**Solution:**
```bash
# Get correct password from Vault
./manage-devstack.sh vault-show-password postgres

# Verify password is correct
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)
vault kv get -field=password secret/postgres

# Re-run test with correct password
```

#### 5. Redis Cluster Not Formed

**Symptoms:**
```bash
[FAIL] Redis cluster state is not 'ok'
cluster_state: fail
```

**Solution:**
```bash
# Initialize Redis cluster
./configs/redis/scripts/redis-cluster-init.sh

# Verify cluster status
docker exec dev-redis-1 redis-cli -a $(vault kv get -field=password secret/redis-1) cluster info

# Should show: cluster_state:ok
```

#### 6. Python Import Errors (Unit Tests)

**Symptoms:**
```bash
ImportError: cannot import name 'app' from 'app.main'
```

**Solution:**
```bash
# Always run unit tests inside container
docker exec dev-reference-api pytest tests/ -v

# NOT from host:
# cd reference-apps/fastapi && pytest tests/  # ❌ Wrong!
```

#### 7. Parity Tests Can't Connect

**Symptoms:**
```bash
requests.exceptions.ConnectionError: ('Connection aborted.', RemoteDisconnected('Remote end closed connection without response'))
```

**Solution:**
```bash
# Ensure both containers are running
docker compose up -d reference-api api-first

# Verify ports are accessible
curl http://localhost:8000/health
curl http://localhost:8001/health

# Run parity tests from host (NOT inside container)
cd reference-apps/shared/test-suite
uv run pytest -v
```

### Debug Mode

Run tests with verbose output:

```bash
# Bash tests with set -x (show commands)
bash -x ./tests/test-postgres.sh

# Python tests with verbose output
docker exec dev-reference-api pytest tests/ -vv

# Python tests with print statements
docker exec dev-reference-api pytest tests/ -s
```

### Test Logs

```bash
# View test output
./tests/run-all-tests.sh 2>&1 | tee test-output.log

# Check service logs if tests fail
docker logs dev-postgres
docker logs dev-vault
docker logs dev-reference-api
```

---

## Related Documentation

- **[Architecture Overview](./Architecture-Overview.md)** - System architecture
- **[Vault Integration](./Vault-Integration.md)** - Credential management
- **[Network Architecture](./Network-Architecture.md)** - Service communication
- **[API Patterns](./API-Patterns.md)** - Reference application patterns
- **[Health Monitoring](./Health-Monitoring.md)** - Service health checks
- **[Common Issues](./Common-Issues.md)** - General troubleshooting

---

## Summary

The comprehensive test suite provides:
- **370+ tests** across bash integration, Python unit, and parity tests
- **External client testing** - Real-world connectivity validation
- **Automated execution** - Single command runs all tests
- **Clear output** - Color-coded results with detailed summaries
- **Multiple test types** - Integration, unit, and parity validation

**Quick Start:**
```bash
# Run all tests
./tests/run-all-tests.sh

# Run specific suite
./tests/test-postgres.sh

# Run unit tests
docker exec dev-reference-api pytest tests/ -v

# Run parity tests
cd reference-apps/shared/test-suite && uv run pytest -v
```
