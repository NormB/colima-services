# Usage Guide

Complete guide for using the Colima Services development environment.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [First-Time Setup](#first-time-setup)
3. [Daily Operations](#daily-operations)
4. [Testing](#testing)
5. [Working with Services](#working-with-services)
6. [Working with Vault](#working-with-vault)
7. [Working with Reference Applications](#working-with-reference-applications)
8. [Development Workflows](#development-workflows)
9. [Troubleshooting](#troubleshooting)
10. [Advanced Usage](#advanced-usage)

---

## Quick Start

```bash
# 1. Start everything
./manage-colima.sh start

# 2. Initialize Vault (first time only)
./manage-colima.sh vault-init
./manage-colima.sh vault-bootstrap

# 3. Verify everything is running
./manage-colima.sh health

# 4. Run tests
./tests/run-all-tests.sh
```

That's it! You now have a complete development environment with:
- PostgreSQL, MySQL, MongoDB
- Redis Cluster (3 nodes)
- RabbitMQ
- Vault (PKI + secrets)
- Grafana, Prometheus, Loki
- Reference APIs in 5 languages

---

## First-Time Setup

### 1. Prerequisites

**Required:**
- macOS (Apple Silicon or Intel)
- Colima or Docker Desktop
- Bash 3.2+

**Install if needed:**
```bash
# Install Colima (recommended for Apple Silicon)
brew install colima docker docker-compose

# Or use Docker Desktop
# Download from: https://www.docker.com/products/docker-desktop

# Install uv (for testing)
brew install uv
# or: curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 2. Clone and Configure

```bash
# Clone repository
git clone <repository-url>
cd colima-services

# Create environment file
cp .env.example .env

# Optional: Edit .env to customize ports, IPs, etc.
nano .env
```

### 3. Start Colima VM (if using Colima)

```bash
# Check if Colima is running
colima status

# If not running, the management script will start it automatically
# Or start manually:
colima start --cpu 4 --memory 8 --disk 100
```

### 4. Launch Services

```bash
# Start all services
./manage-colima.sh start

# This will:
# - Start Colima VM (if not running)
# - Start Vault first
# - Start all dependent services
# - Wait for health checks
```

**Expected output:**
```
✓ Colima VM is running
✓ Starting services...
✓ Vault started and healthy
✓ Services starting...
```

### 5. Initialize Vault (First Time Only)

```bash
# Initialize Vault and save keys to ~/.config/vault/
./manage-colima.sh vault-init

# Bootstrap PKI and store service credentials
./manage-colima.sh vault-bootstrap
```

**Important:** Backup `~/.config/vault/` directory - contains unseal keys and root token!

### 6. Verify Setup

```bash
# Check all services are healthy
./manage-colima.sh health

# Check specific service status
./manage-colima.sh status

# Run tests to verify everything works
./tests/run-all-tests.sh
```

---

## Daily Operations

### Starting Your Day

```bash
# Check if VM is running
./manage-colima.sh status

# If stopped, start everything
./manage-colima.sh start

# Check health
./manage-colima.sh health
```

### Viewing Logs

```bash
# View all service logs
./manage-colima.sh logs

# View specific service logs
./manage-colima.sh logs postgres
./manage-colima.sh logs vault
./manage-colima.sh logs reference-api

# Follow logs in real-time
docker compose logs -f postgres
```

### Restarting Services

```bash
# Restart all services (keeps VM running)
./manage-colima.sh restart

# Restart specific service
docker compose restart postgres
docker compose restart vault
```

### Stopping Services

```bash
# Stop all services (keeps VM running)
docker compose down

# Stop everything including VM
./manage-colima.sh stop
```

### Checking Status

```bash
# Detailed status with resource usage
./manage-colima.sh status

# Quick health check
./manage-colima.sh health

# Vault status
./manage-colima.sh vault-status

# Individual service status
docker compose ps
```

---

## Testing

**See `TESTING_APPROACH.md` for methodology and `TEST_COVERAGE_SUMMARY.md` for complete coverage details.**

### Run All Tests

```bash
# Run all 431 tests (auto-starts containers if needed)
./tests/run-all-tests.sh
```

**Output:**
```
Test Suites Run: 12
Passed: 12

✓ Vault Integration (10 tests)
✓ PostgreSQL Vault Integration (11 tests)
✓ MySQL Vault Integration (10 tests)
✓ MongoDB Vault Integration (11 tests)
✓ Redis Vault Integration (10 tests)
✓ Redis Cluster (12 tests)
✓ RabbitMQ Integration (10 tests)
✓ FastAPI Reference App (14 tests)
✓ Performance & Load Testing (11 tests)
✓ Negative Testing & Error Handling (14 tests)
✓ FastAPI Unit Tests (254 tests: 178 passed + 76 skipped, 84.39% coverage)
✓ API Parity Tests (64 tests from 38 unique test functions)

✓ ALL TESTS PASSED!
```

### Run Specific Test Suites

```bash
# Infrastructure tests
./tests/test-vault.sh

# Database tests
./tests/test-postgres.sh
./tests/test-mysql.sh
./tests/test-mongodb.sh

# Cache tests
./tests/test-redis.sh
./tests/test-redis-cluster.sh

# Messaging tests
./tests/test-rabbitmq.sh

# Application tests
./tests/test-fastapi.sh

# Performance tests
./tests/test-performance.sh

# Negative/security tests
./tests/test-negative.sh
```

### Run Python Unit Tests

```bash
# Ensure container is running
docker compose up -d reference-api

# Run unit tests (254 tests: 178 passed + 76 skipped)
docker exec dev-reference-api pytest tests/ -v

# Run specific test file
docker exec dev-reference-api pytest tests/test_vault_service.py -v

# Run with coverage report
docker exec dev-reference-api pytest tests/ -v --cov=app --cov-report=term
```

### Run Parity Tests

```bash
# Ensure both API containers are running
docker compose up -d reference-api api-first

# Run parity tests (64 tests from 38 unique test functions)
cd reference-apps/shared/test-suite
uv run pytest -v
```

**See also:**
- `TESTING_APPROACH.md` - Testing methodology and best practices
- `TEST_COVERAGE_SUMMARY.md` - Complete test coverage details (431 tests)

---

## Working with Services

### PostgreSQL

```bash
# Connect with Vault password
PGPASSWORD=$(./manage-colima.sh vault-show-password postgres) \
  psql -h localhost -p 5432 -U dev_admin -d dev_database

# Or get password first
./manage-colima.sh vault-show-password postgres

# Query from command line
docker exec dev-postgres psql -U dev_admin -d dev_database -c "SELECT version();"

# Backup database
./manage-colima.sh backup
```

### MySQL

```bash
# Get password
./manage-colima.sh vault-show-password mysql

# Connect
mysql -h 127.0.0.1 -P 3306 -u dev_admin -p dev_database

# Or from container
docker exec -it dev-mysql mysql -u dev_admin -p dev_database
```

### MongoDB

```bash
# Get password
./manage-colima.sh vault-show-password mongodb

# Connect
mongosh "mongodb://dev_admin:<password>@localhost:27017/dev_database"

# Or from container
docker exec -it dev-mongodb mongosh -u dev_admin -p
```

### Redis Cluster

```bash
# Connect to any node
redis-cli -h localhost -p 6379

# Check cluster status
redis-cli -h localhost -p 6379 cluster info
redis-cli -h localhost -p 6379 cluster nodes

# Set/get data (cluster-aware)
redis-cli -c -h localhost -p 6379
> SET mykey "hello"
> GET mykey

# Test cluster operations
./tests/test-redis-cluster.sh
```

### RabbitMQ

```bash
# Web UI
open http://localhost:15672
# Default: guest / guest (or get from Vault)

# Get credentials
./manage-colima.sh vault-show-password rabbitmq

# Publish message via CLI
docker exec dev-rabbitmq rabbitmqadmin publish exchange=amq.default \
  routing_key=test_queue payload="Hello World"
```

### Grafana

```bash
# Open dashboard
open http://localhost:3001

# Default credentials
# Username: admin
# Password: admin (change on first login)
```

### Prometheus

```bash
# Open UI
open http://localhost:9090

# Check targets
open http://localhost:9090/targets

# Query metrics
# Example: container_memory_usage_bytes
```

---

## Working with Vault

### Retrieve Service Credentials

```bash
# Using management script (easiest)
./manage-colima.sh vault-show-password postgres
./manage-colima.sh vault-show-password mysql
./manage-colima.sh vault-show-password redis-1

# Using Vault CLI
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

vault kv get secret/postgres
vault kv get -field=password secret/postgres
vault kv list secret/
```

### Load All Credentials into Environment

```bash
# Source the environment loader
source scripts/load-vault-env.sh

# Now use credentials
echo $POSTGRES_PASSWORD
echo $MYSQL_PASSWORD
echo $REDIS_PASSWORD
```

### Regenerate Service Certificates

```bash
# Set environment
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# Generate certificates for all services
./scripts/generate-certificates.sh

# Restart services to pick up new certificates
docker compose restart postgres mysql redis-1 redis-2 redis-3 rabbitmq mongodb
```

### Check Vault Health

```bash
# Using management script
./manage-colima.sh vault-status

# Using Vault CLI
vault status

# Check specific endpoints
curl http://localhost:8200/v1/sys/health
```

### Vault Auto-Unseal

Vault automatically unseals on container start using `~/.config/vault/keys.json`.

**If Vault is sealed manually:**
```bash
./manage-colima.sh vault-unseal
```

---

## Working with Reference Applications

### FastAPI (Code-First)

```bash
# View logs
docker compose logs -f reference-api

# Health check
curl http://localhost:8000/health/

# API documentation
open http://localhost:8000/docs

# Test endpoints
curl http://localhost:8000/
curl http://localhost:8000/vault/secrets/postgres
curl http://localhost:8000/cache/demo/mykey
curl http://localhost:8000/redis-cluster/nodes

# HTTPS endpoints (TLS)
curl -k https://localhost:8443/health/

# Run unit tests
docker exec dev-reference-api pytest tests/ -v
```

### FastAPI (API-First)

```bash
# View logs
docker compose logs -f api-first

# Health check
curl http://localhost:8001/health/

# API documentation
open http://localhost:8001/docs

# Compare with code-first
diff <(curl -s http://localhost:8000/openapi.json) \
     <(curl -s http://localhost:8001/openapi.json)
```

### Go Reference App

```bash
# View logs
docker compose logs -f reference-go-api

# Health check
curl http://localhost:8002/health/

# Endpoints
curl http://localhost:8002/
```

### Node.js Reference App

```bash
# View logs
docker compose logs -f reference-node-api

# Health check
curl http://localhost:8003/health/

# Endpoints
curl http://localhost:8003/
```

### Rust Reference App

```bash
# View logs
docker compose logs -f reference-rust-api

# Health check
curl http://localhost:8004/health/

# Endpoints
curl http://localhost:8004/
```

---

## Development Workflows

### Adding a New Service

1. **Add to `docker-compose.yml`:**
```yaml
myservice:
  image: myservice:latest
  container_name: dev-myservice
  networks:
    dev-services:
      ipv4_address: 172.20.0.50
  depends_on:
    vault:
      condition: service_healthy
```

2. **Create config directory:**
```bash
mkdir -p configs/myservice/scripts
```

3. **Create Vault credential wrapper:**
```bash
# configs/myservice/scripts/init.sh
#!/bin/bash
export PASSWORD=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
  $VAULT_ADDR/v1/secret/data/myservice | jq -r '.data.data.password')
exec original-entrypoint.sh
```

4. **Add credentials to Vault:**
```bash
# Edit configs/vault/scripts/vault-bootstrap.sh
# Add to SERVICES array and secret creation
```

5. **Create test suite:**
```bash
# tests/test-myservice.sh
```

### Modifying a Reference App

```bash
# 1. Edit source code
nano reference-apps/fastapi/app/main.py

# 2. Rebuild container
docker compose build reference-api

# 3. Restart
docker compose up -d reference-api

# 4. Test changes
curl http://localhost:8000/health
docker exec dev-reference-api pytest tests/ -v

# 5. View logs
docker compose logs -f reference-api
```

### Working with Database Migrations

```bash
# PostgreSQL example
docker exec dev-postgres psql -U dev_admin -d dev_database -f /path/to/migration.sql

# Or create migration script
cat > migration.sql <<EOF
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(50) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF

docker cp migration.sql dev-postgres:/tmp/
docker exec dev-postgres psql -U dev_admin -d dev_database -f /tmp/migration.sql
```

### Backup and Restore

```bash
# Backup all databases
./manage-colima.sh backup

# Backups are stored in backups/ directory with timestamp

# Restore PostgreSQL (example)
BACKUP_FILE=backups/postgres-backup-20250128-120000.sql
docker exec -i dev-postgres psql -U dev_admin -d dev_database < $BACKUP_FILE

# Backup Vault keys (CRITICAL)
cp -r ~/.config/vault ~/vault-backup-$(date +%Y%m%d)
```

### Reset Everything

```bash
# WARNING: This destroys all data!
./manage-colima.sh reset

# Confirm with 'yes'
# Then re-initialize
./manage-colima.sh start
./manage-colima.sh vault-init
./manage-colima.sh vault-bootstrap
```

---

## Troubleshooting

### Services Won't Start

```bash
# Check Vault is healthy
curl http://localhost:8200/v1/sys/health

# Check Vault status
./manage-colima.sh vault-status

# If sealed, unseal it
./manage-colima.sh vault-unseal

# Restart services
./manage-colima.sh restart
```

### "Connection Refused" Errors

```bash
# Check service is running
docker compose ps

# Check service logs
docker compose logs <service>

# Check health
./manage-colima.sh health

# Test network connectivity
docker exec <service> ping vault
docker exec <service> nc -zv vault 8200
```

### Vault Sealed or Unavailable

```bash
# Check status
./manage-colima.sh vault-status

# Unseal
./manage-colima.sh vault-unseal

# If auto-unseal fails, check keys exist
ls ~/.config/vault/keys.json
ls ~/.config/vault/root-token

# Restart Vault
docker compose restart vault
```

### Tests Failing

```bash
# 1. Check all services are healthy
./manage-colima.sh health

# 2. Restart infrastructure
./manage-colima.sh restart

# 3. Check specific service
./manage-colima.sh logs <service>

# 4. Re-run specific test
./tests/test-<service>.sh

# 5. For pytest tests, ensure containers running
docker compose up -d reference-api api-first
```

### Vault Keys Lost

**If you lose `~/.config/vault/`:**

⚠️ **Vault data cannot be recovered without the unseal keys!**

```bash
# You must reset Vault
docker compose down vault
docker volume rm colima-services_vault-data
docker compose up -d vault

# Re-initialize
./manage-colima.sh vault-init
./manage-colima.sh vault-bootstrap
```

**Prevention:** Always backup `~/.config/vault/`

### Port Conflicts

```bash
# Check which process is using port
lsof -i :8200  # Vault
lsof -i :5432  # PostgreSQL
lsof -i :8000  # Reference API

# Edit .env to change ports
nano .env

# Restart services
./manage-colima.sh restart
```

### Disk Space Issues

```bash
# Check Docker disk usage
docker system df

# Clean up unused images/volumes
docker system prune -a --volumes

# Check Colima disk usage (if using Colima)
colima ssh -- df -h

# Increase Colima disk (requires recreation)
colima stop
colima start --cpu 4 --memory 8 --disk 150
```

### Container Logs Too Large

```bash
# Check log sizes
docker inspect --format='{{.LogPath}}' dev-postgres | xargs ls -lh

# Clean logs
docker compose down
rm -rf /var/lib/docker/containers/*/
docker compose up -d

# Or configure log rotation in docker-compose.yml
```

---

## Advanced Usage

### Accessing Services from Outside Colima VM

All services are exposed on `localhost` with port mappings defined in `.env`:

- PostgreSQL: `localhost:5432`
- MySQL: `localhost:3306`
- MongoDB: `localhost:27017`
- Redis Nodes: `localhost:6379`, `localhost:6380`, `localhost:6381`
- RabbitMQ: `localhost:5672` (AMQP), `localhost:15672` (Management)
- Vault: `localhost:8200`
- Grafana: `localhost:3001`
- Prometheus: `localhost:9090`
- Reference APIs: `localhost:8000-8004`

### Custom Environment Configuration

```bash
# Edit .env for custom configuration
nano .env

# Examples:
# - Change ports
# - Enable/disable TLS per service
# - Adjust resource limits
# - Modify IP addresses

# Restart to apply
./manage-colima.sh restart
```

### Using TLS/SSL

All services support optional TLS via Vault-issued certificates.

**Enable TLS for a service:**
```bash
# Edit .env
POSTGRES_ENABLE_TLS=true

# Restart service
docker compose restart postgres

# Test TLS connection
psql "postgresql://dev_admin@localhost:5432/dev_database?sslmode=verify-full&sslrootcert=$HOME/.config/vault/ca/ca.pem"
```

### Monitoring and Observability

```bash
# Grafana dashboards
open http://localhost:3001

# Prometheus metrics
open http://localhost:9090

# Query specific metrics
curl http://localhost:9090/api/v1/query?query=container_memory_usage_bytes

# Loki logs
curl http://localhost:3100/loki/api/v1/labels

# cAdvisor container stats
open http://localhost:8080
```

### Performance Tuning

**Edit `.env` for performance settings:**
```bash
# PostgreSQL
POSTGRES_MAX_CONNECTIONS=200
POSTGRES_SHARED_BUFFERS=256MB

# Redis
REDIS_MAXMEMORY=512mb
REDIS_MAXMEMORY_POLICY=allkeys-lru

# MySQL
MYSQL_INNODB_BUFFER_POOL_SIZE=512M

# Restart services
./manage-colima.sh restart
```

### CI/CD Integration

```yaml
# GitHub Actions example
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Create .env
        run: cp .env.example .env

      - name: Start services
        run: |
          docker compose up -d
          sleep 30

      - name: Initialize Vault
        run: |
          ./manage-colima.sh vault-init
          ./manage-colima.sh vault-bootstrap

      - name: Run tests
        run: ./tests/run-all-tests.sh

      - name: Cleanup
        if: always()
        run: docker compose down -v
```

### Development Best Practices

1. **Always use Vault for credentials** - Never hardcode passwords
2. **Test locally before pushing** - Run `./tests/run-all-tests.sh`
3. **Backup Vault keys** - Store `~/.config/vault/` safely
4. **Monitor resource usage** - `./manage-colima.sh status`
5. **Keep containers updated** - `docker compose pull && docker compose up -d`
6. **Review logs regularly** - `./manage-colima.sh logs`

---

## Quick Reference

### Essential Commands

```bash
# Start everything
./manage-colima.sh start

# Check health
./manage-colima.sh health

# View logs
./manage-colima.sh logs [service]

# Get password
./manage-colima.sh vault-show-password <service>

# Run tests
./tests/run-all-tests.sh

# Restart
./manage-colima.sh restart

# Stop
./manage-colima.sh stop
```

### Important File Locations

```
~/colima-services/
├── manage-colima.sh              # Main management script
├── docker-compose.yml            # Service definitions
├── .env                          # Configuration
├── tests/run-all-tests.sh        # Master test runner
├── USAGE.md                      # This file
├── TESTING_APPROACH.md           # Testing best practices
└── CLAUDE.md                     # AI assistant guidance

~/.config/vault/
├── keys.json                     # Vault unseal keys (BACKUP!)
├── root-token                    # Vault root token (BACKUP!)
├── ca/                           # CA certificates
└── certs/                        # Service certificates
```

### Getting Help

```bash
# Management script help
./manage-colima.sh --help

# Service-specific help
docker compose logs <service>
./manage-colima.sh shell <service>

# View documentation
cat README.md
cat docs/TROUBLESHOOTING.md
cat TESTING_APPROACH.md
```

---

## Next Steps

After completing this guide:

1. **Explore the reference applications** - See working examples in 5 languages
2. **Read `TESTING_APPROACH.md`** - Understand the test infrastructure
3. **Review `docs/ARCHITECTURE.md`** - Deep dive into system design
4. **Check `docs/BEST_PRACTICES.md`** - Development patterns and conventions

**Questions or issues?** Check `docs/TROUBLESHOOTING.md` or create an issue in the repository.
