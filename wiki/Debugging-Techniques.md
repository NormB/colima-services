# Debugging Techniques

Systematic debugging approaches for all services in the DevStack Core environment.

## Table of Contents

- [Overview](#overview)
- [Debugging Philosophy](#debugging-philosophy)
- [Container Debugging](#container-debugging)
- [Network Debugging](#network-debugging)
- [Database Debugging](#database-debugging)
- [Application Debugging](#application-debugging)
- [Vault Debugging](#vault-debugging)
- [Performance Debugging](#performance-debugging)
- [Common Patterns](#common-patterns)
- [Debugging Tools](#debugging-tools)
- [Step-by-Step Procedures](#step-by-step-procedures)
- [Related Documentation](#related-documentation)

## Overview

Systematic debugging is essential for identifying and resolving issues in containerized environments. This guide provides comprehensive debugging techniques for all DevStack Core components.

## Debugging Philosophy

**Systematic Approach:**

1. **Reproduce** - Consistently reproduce the issue
2. **Isolate** - Narrow down the component causing the problem
3. **Hypothesis** - Form theories about the root cause
4. **Test** - Verify each hypothesis
5. **Fix** - Apply the solution
6. **Verify** - Confirm the fix resolves the issue
7. **Document** - Record findings for future reference

**Debugging Principles:**

- Start with the basics (is it running? can it connect?)
- Check logs first
- Use divide-and-conquer to isolate issues
- Test one thing at a time
- Document your steps
- Don't assume - verify everything

## Container Debugging

### Check Container Status

```bash
# List all containers
docker ps -a

# Check specific container
docker ps --filter "name=postgres"

# Inspect container state
docker inspect postgres | jq '.[0].State'

# Check exit code
docker inspect postgres | jq '.[0].State.ExitCode'

# View container events
docker events --filter container=postgres --since 1h
```

### View Container Logs

```bash
# View all logs
docker logs postgres

# Follow logs (tail -f)
docker logs -f postgres

# Last 100 lines
docker logs --tail 100 postgres

# With timestamps
docker logs -t postgres

# Since time
docker logs --since 10m postgres
docker logs --since 2024-01-15T10:00:00 postgres

# Filter logs
docker logs postgres 2>&1 | grep ERROR
docker logs postgres 2>&1 | grep -i "connection refused"
```

### Execute Commands in Container

```bash
# Interactive shell
docker exec -it postgres bash

# Run single command
docker exec postgres ls -la /var/lib/postgresql/data

# Check processes
docker exec postgres ps aux

# Check network
docker exec postgres netstat -tlnp
docker exec postgres ss -tlnp

# Test connectivity
docker exec postgres ping -c 3 vault
docker exec postgres nc -zv vault 8200

# Check environment
docker exec postgres env

# Check disk space
docker exec postgres df -h

# View configuration
docker exec postgres cat /etc/postgresql/postgresql.conf
```

### Inspect Container Configuration

```bash
# Full inspection
docker inspect postgres | jq

# Get IP address
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' postgres

# Get environment variables
docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' postgres

# Get port mappings
docker inspect -f '{{range $p, $conf := .NetworkSettings.Ports}}{{$p}} -> {{(index $conf 0).HostPort}}{{println}}{{end}}' postgres

# Get volume mounts
docker inspect -f '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' postgres

# Check health status
docker inspect postgres | jq '.[0].State.Health'

# View restart count
docker inspect postgres | jq '.[0].RestartCount'
```

### Resource Issues

```bash
# Check resource usage
docker stats postgres --no-stream

# Check memory limit
docker inspect postgres | jq '.[0].HostConfig.Memory'

# Check CPU usage
docker top postgres

# Check if OOM killed
docker inspect postgres | jq '.[0].State.OOMKilled'

# Monitor in real-time
watch -n 1 'docker stats postgres --no-stream'
```

## Network Debugging

### Connectivity Testing

```bash
# Test from host
ping localhost
nc -zv localhost 5432
telnet localhost 5432
curl http://localhost:8200/v1/sys/health

# Test from container
docker exec postgres ping -c 3 vault
docker exec postgres nc -zv vault 8200
docker exec postgres telnet vault 8200
docker exec postgres curl http://vault:8200/v1/sys/health
```

### DNS Resolution

```bash
# Test DNS from container
docker exec postgres nslookup vault
docker exec postgres dig vault
docker exec postgres getent hosts vault

# Check resolv.conf
docker exec postgres cat /etc/resolv.conf

# Test external DNS
docker exec postgres nslookup google.com
```

### Network Inspection

```bash
# List networks
docker network ls

# Inspect network
docker network inspect dev-services

# Show containers in network
docker network inspect dev-services | jq '.[0].Containers'

# Get container IP
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' postgres

# Check routing
docker exec postgres ip route
docker exec postgres route -n
```

### Port Debugging

```bash
# Check if port is listening
docker exec postgres netstat -tlnp | grep 5432
docker exec postgres ss -tlnp | grep 5432
docker exec postgres lsof -i :5432

# Check from host
netstat -an | grep 5432
lsof -i :5432

# Check for port conflicts
lsof -i :5432
```

### Packet Inspection

```bash
# Install tcpdump in container
docker exec -u root postgres apt-get update && apt-get install -y tcpdump

# Capture traffic
docker exec postgres tcpdump -i any port 5432 -w /tmp/capture.pcap

# View live traffic
docker exec postgres tcpdump -i any port 5432 -n

# Copy capture for analysis
docker cp postgres:/tmp/capture.pcap ./capture.pcap
wireshark capture.pcap
```

## Database Debugging

### PostgreSQL Debugging

```bash
# Check if PostgreSQL is running
docker exec postgres pg_isready -U postgres

# View active connections
docker exec postgres psql -U postgres -c "SELECT * FROM pg_stat_activity;"

# Check for locks
docker exec postgres psql -U postgres -c "SELECT * FROM pg_locks WHERE NOT granted;"

# Find slow queries
docker exec postgres psql -U postgres -c "SELECT pid, now() - pg_stat_activity.query_start AS duration, query FROM pg_stat_activity WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';"

# Check database size
docker exec postgres psql -U postgres -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) FROM pg_database;"

# Check table bloat
docker exec postgres psql -U postgres -d myapp -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 10;"

# View logs
docker exec postgres tail -100 /var/lib/postgresql/data/log/postgresql-*.log

# Check configuration
docker exec postgres psql -U postgres -c "SHOW ALL;"

# Test query performance
docker exec postgres psql -U postgres -c "EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@example.com';"
```

### MySQL Debugging

```bash
# Check if MySQL is running
docker exec mysql mysqladmin -u root -p ping

# View active connections
docker exec mysql mysql -u root -p -e "SHOW PROCESSLIST;"

# Check for locks
docker exec mysql mysql -u root -p -e "SHOW ENGINE INNODB STATUS\G" | grep -A 20 "TRANSACTIONS"

# Find slow queries
docker exec mysql mysql -u root -p -e "SELECT * FROM information_schema.processlist WHERE time > 5;"

# Check database size
docker exec mysql mysql -u root -p -e "SELECT table_schema, SUM(data_length + index_length) / 1024 / 1024 AS size_mb FROM information_schema.tables GROUP BY table_schema;"

# View error log
docker exec mysql tail -100 /var/log/mysql/error.log

# Check variables
docker exec mysql mysql -u root -p -e "SHOW VARIABLES;"

# Test query performance
docker exec mysql mysql -u root -p -e "EXPLAIN SELECT * FROM users WHERE email = 'test@example.com';"
```

### MongoDB Debugging

```bash
# Check if MongoDB is running
docker exec mongodb mongosh --eval "db.serverStatus().ok"

# View current operations
docker exec mongodb mongosh --eval "db.currentOp()"

# Find slow queries
docker exec mongodb mongosh --eval "db.setProfilingLevel(1, { slowms: 100 })"
docker exec mongodb mongosh --eval "db.system.profile.find().sort({ millis: -1 }).limit(10).pretty()"

# Check database size
docker exec mongodb mongosh --eval "db.stats()"

# Check collection size
docker exec mongodb mongosh myapp --eval "db.users.stats()"

# View logs
docker logs mongodb --tail 100

# Test query performance
docker exec mongodb mongosh myapp --eval "db.users.find({ email: 'test@example.com' }).explain('executionStats')"
```

### Redis Debugging

```bash
# Check if Redis is running
docker exec redis-1 redis-cli ping

# View connected clients
docker exec redis-1 redis-cli CLIENT LIST

# Check memory usage
docker exec redis-1 redis-cli INFO memory

# View slow log
docker exec redis-1 redis-cli SLOWLOG GET 10

# Monitor commands
docker exec redis-1 redis-cli MONITOR

# Check configuration
docker exec redis-1 redis-cli CONFIG GET '*'

# View cluster status
docker exec redis-1 redis-cli -c CLUSTER INFO
docker exec redis-1 redis-cli -c CLUSTER NODES

# Test performance
docker exec redis-1 redis-cli --latency
docker exec redis-1 redis-cli --latency-history
```

## Application Debugging

### Python/FastAPI Debugging

```bash
# Enable debug logging
docker exec dev-reference-api python -c "import logging; logging.basicConfig(level=logging.DEBUG)"

# View application logs
docker logs -f dev-reference-api

# Attach Python debugger
# Add to code:
import pdb; pdb.set_trace()

# Or use debugpy for remote debugging
# pip install debugpy
# python -m debugpy --listen 0.0.0.0:5678 --wait-for-client app/main.py

# Check environment variables
docker exec dev-reference-api env | grep -i db

# Test imports
docker exec dev-reference-api python -c "import app.main; print('OK')"

# Run specific endpoint
docker exec dev-reference-api python -c "from app.main import app; from fastapi.testclient import TestClient; client = TestClient(app); print(client.get('/health').json())"

# Check installed packages
docker exec dev-reference-api pip list

# View traceback
docker logs dev-reference-api 2>&1 | grep -A 50 "Traceback"
```

### Node.js Debugging

```bash
# Enable debug mode
docker exec nodejs-api node --inspect=0.0.0.0:9229 src/index.js

# View console output
docker logs -f nodejs-api

# Check for errors
docker logs nodejs-api 2>&1 | grep -i error

# Test module loading
docker exec nodejs-api node -e "require('./src/index.js')"

# Check npm packages
docker exec nodejs-api npm list

# View stack trace
docker logs nodejs-api 2>&1 | grep -A 20 "Error:"
```

### Go Debugging

```bash
# Build with debug symbols
docker exec golang-api go build -gcflags="all=-N -l" -o main .

# Use delve debugger
docker exec golang-api dlv exec ./main

# View panics
docker logs golang-api 2>&1 | grep -A 50 "panic:"

# Check imports
docker exec golang-api go list -m all

# Run tests with verbose
docker exec golang-api go test -v ./...
```

## Vault Debugging

### Vault Status

```bash
# Check Vault status
docker exec vault vault status

# Check if sealed
docker exec vault vault status | grep "Sealed"

# View audit log
docker exec vault cat /vault/logs/audit.log | tail -100

# Check policies
docker exec vault vault policy list
docker exec vault vault policy read default

# Test token
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)
docker exec vault vault token lookup

# View secrets
docker exec vault vault kv list secret/
docker exec vault vault kv get secret/postgres
```

### Vault Unsealing

```bash
# Check seal status
docker exec vault vault status

# Unseal manually
for key in $(jq -r '.unseal_keys_b64[]' ~/.config/vault/keys.json); do
  docker exec vault vault operator unseal $key
done

# Or use management script
./manage-devstack.sh vault-unseal

# Verify unsealed
docker exec vault vault status | grep "Sealed.*false"
```

### Vault PKI Debugging

```bash
# Check PKI status
docker exec vault vault secrets list

# View CA certificate
docker exec vault vault read pki/ca/pem

# Check intermediate CA
docker exec vault vault read pki_int/ca/pem

# List roles
docker exec vault vault list pki_int/roles

# Test certificate generation
docker exec vault vault write pki_int/issue/postgres-role common_name=test.postgres

# Verify certificate chain
openssl verify -CAfile ~/.config/vault/ca/ca.pem ~/.config/vault/certs/postgres/cert.pem
```

## Performance Debugging

### Identify Resource Bottlenecks

```bash
# Check all container stats
docker stats --no-stream

# Find high CPU containers
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}" | sort -k2 -rn

# Find high memory containers
docker stats --no-stream --format "table {{.Name}}\t{{.MemPerc}}" | sort -k2 -rn

# Check disk I/O
docker stats --format "table {{.Name}}\t{{.BlockIO}}"

# Check network I/O
docker stats --format "table {{.Name}}\t{{.NetIO}}"
```

### Application Profiling

```bash
# Python profiling
docker exec dev-reference-api python -m cProfile -o profile.stats app/main.py
docker exec dev-reference-api python -c "import pstats; p = pstats.Stats('profile.stats'); p.sort_stats('cumulative'); p.print_stats(20)"

# Memory profiling
docker exec dev-reference-api python -m memory_profiler app/main.py

# HTTP load testing
ab -n 1000 -c 10 http://localhost:8000/health
hey -n 1000 -c 10 http://localhost:8000/health
```

### Database Performance

```bash
# PostgreSQL query analysis
docker exec postgres psql -U postgres -c "SELECT query, calls, total_time, mean_time FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"

# MySQL query analysis
docker exec mysql mysql -u root -p -e "SELECT * FROM performance_schema.events_statements_summary_by_digest ORDER BY SUM_TIMER_WAIT DESC LIMIT 10;"

# MongoDB query analysis
docker exec mongodb mongosh --eval "db.system.profile.find().sort({ millis: -1 }).limit(10).pretty()"

# Redis performance
docker exec redis-1 redis-cli --latency-history
docker exec redis-1 redis-cli --bigkeys
```

## Common Patterns

### Connection Refused Errors

```bash
# 1. Check if service is running
docker ps | grep <service>

# 2. Check if port is listening
docker exec <service> netstat -tlnp | grep <port>

# 3. Test from container network
docker exec <another-container> nc -zv <service> <port>

# 4. Check logs for errors
docker logs <service>

# 5. Verify network connectivity
docker network inspect dev-services

# 6. Check firewall/routing
docker exec <service> ip route
```

### Timeout Errors

```bash
# 1. Check service response time
time curl http://localhost:8000/health

# 2. Check for slow queries
# See database debugging sections above

# 3. Check resource constraints
docker stats <service> --no-stream

# 4. Check network latency
docker exec <service> ping -c 10 <target>

# 5. Increase timeout in application
# Update connection timeout settings
```

### Authentication Failures

```bash
# 1. Verify credentials in Vault
vault kv get secret/<service>

# 2. Check user exists
docker exec postgres psql -U postgres -c "SELECT * FROM pg_user WHERE usename='postgres';"

# 3. Test authentication
docker exec postgres psql -U postgres -c "SELECT 1;"

# 4. Check connection string
docker exec <service> env | grep DATABASE_URL

# 5. Review access logs
docker logs <service> | grep -i auth
```

### 500 Internal Server Errors

```bash
# 1. Check application logs
docker logs -f <service>

# 2. Look for stack traces
docker logs <service> 2>&1 | grep -A 50 "Traceback\|Error:"

# 3. Check database connections
docker exec <service> <db-client> -c "SELECT 1;"

# 4. Verify environment variables
docker inspect <service> | jq '.[0].Config.Env'

# 5. Test endpoint manually
curl -v http://localhost:8000/endpoint
```

## Debugging Tools

### Essential Tools

```bash
# Install debugging tools in container
docker exec -u root <service> apt-get update
docker exec -u root <service> apt-get install -y \
  net-tools \
  iputils-ping \
  dnsutils \
  curl \
  wget \
  telnet \
  netcat \
  tcpdump \
  strace \
  htop \
  vim

# Or use a debugging sidecar container
docker run -it --rm \
  --network container:<service> \
  nicolaka/netshoot
```

### Monitoring Tools

```bash
# Use Prometheus metrics
curl http://localhost:9090/metrics

# Use Grafana dashboards
open http://localhost:3001

# Use cAdvisor
open http://localhost:8080

# Custom monitoring
watch -n 1 'docker stats --no-stream'
```

## Step-by-Step Procedures

### Debugging Container Won't Start

```bash
# Step 1: Check container status
docker ps -a | grep <service>

# Step 2: View logs
docker logs <service>

# Step 3: Check for dependencies
docker compose config | grep -A 10 depends_on

# Step 4: Verify dependencies running
docker ps | grep vault

# Step 5: Check configuration
docker compose config <service>

# Step 6: Try starting manually
docker compose up <service>

# Step 7: Check resources
df -h
docker system df

# Step 8: Review docker-compose.yml
cat docker-compose.yml | grep -A 30 "<service>:"
```

### Debugging Database Connection Issues

```bash
# Step 1: Verify database is running
docker ps | grep <database>

# Step 2: Check if port is accessible
nc -zv localhost 5432

# Step 3: Test from container network
docker exec <app> nc -zv <database> 5432

# Step 4: Verify credentials
vault kv get secret/<database>

# Step 5: Test manual connection
docker exec <database> <client> -U user -c "SELECT 1;"

# Step 6: Check connection string
docker exec <app> env | grep DATABASE

# Step 7: Review application logs
docker logs <app> | grep -i database

# Step 8: Check for connection limits
docker exec <database> <client> -U user -c "SHOW max_connections;"
```

### Debugging Network Issues

```bash
# Step 1: Test basic connectivity
docker exec <service> ping -c 3 google.com

# Step 2: Test DNS resolution
docker exec <service> nslookup <target>

# Step 3: Test port connectivity
docker exec <service> nc -zv <target> <port>

# Step 4: Check network configuration
docker network inspect dev-services

# Step 5: Verify IP addresses
docker inspect <service> | jq '.[0].NetworkSettings.Networks'

# Step 6: Check routing
docker exec <service> ip route

# Step 7: Capture packets
docker exec <service> tcpdump -i any port <port>

# Step 8: Check firewall rules
docker exec <service> iptables -L
```

## Related Documentation

- [Network Debugging](Network-Debugging) - Advanced network troubleshooting
- [Log Analysis](Log-Analysis) - Analyzing logs with Loki
- [Health Monitoring](Health-Monitoring) - Service health checks
- [Performance Tuning](Performance-Tuning) - Optimization techniques
- [Common Issues](Common-Issues) - Known problems and solutions
- [Container Management](Container-Management) - Container operations
- [Service Configuration](Service-Configuration) - Service setup

---

**Quick Reference Card:**

```bash
# Container
docker ps -a
docker logs -f <container>
docker exec -it <container> bash
docker inspect <container>

# Network
nc -zv <host> <port>
docker exec <container> ping <target>
docker network inspect dev-services

# Database
docker exec postgres psql -U postgres
docker exec mysql mysql -u root -p
docker exec mongodb mongosh

# Resources
docker stats <container> --no-stream
docker top <container>

# Debugging
docker logs <container> 2>&1 | grep ERROR
docker exec <container> netstat -tlnp
docker exec <container> ps aux
```
