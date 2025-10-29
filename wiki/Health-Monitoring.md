# Health Monitoring

## Table of Contents

- [Overview](#overview)
- [Health Check System](#health-check-system)
  - [Docker Health Checks](#docker-health-checks)
  - [Service Dependencies](#service-dependencies)
  - [Startup Order](#startup-order)
- [Health Command](#health-command)
  - [Usage](#usage)
  - [Output Interpretation](#output-interpretation)
  - [Automated Health Checks](#automated-health-checks)
- [Prometheus Monitoring](#prometheus-monitoring)
  - [Metrics Collection](#metrics-collection)
  - [Exposed Metrics](#exposed-metrics)
  - [Query Examples](#query-examples)
- [Grafana Dashboards](#grafana-dashboards)
  - [Pre-configured Dashboards](#pre-configured-dashboards)
  - [Creating Custom Dashboards](#creating-custom-dashboards)
  - [Alert Configuration](#alert-configuration)
- [Log Aggregation with Loki](#log-aggregation-with-loki)
  - [Log Collection](#log-collection)
  - [Querying Logs](#querying-logs)
  - [Log Retention](#log-retention)
- [Container Health Checks](#container-health-checks)
  - [Vault Health Check](#vault-health-check)
  - [Database Health Checks](#database-health-checks)
  - [Redis Cluster Health](#redis-cluster-health)
  - [RabbitMQ Health Check](#rabbitmq-health-check)
- [Metrics Endpoints](#metrics-endpoints)
  - [Service Metrics](#service-metrics)
  - [Custom Metrics](#custom-metrics)
- [Troubleshooting Unhealthy Services](#troubleshooting-unhealthy-services)
  - [Common Issues](#common-issues)
  - [Debugging Steps](#debugging-steps)
  - [Recovery Procedures](#recovery-procedures)
- [Related Pages](#related-pages)

## Overview

The colima-services environment includes comprehensive health monitoring and observability features to ensure all services are running correctly and performing optimally.

**Monitoring Components:**
- Docker health checks with automatic restart policies
- Prometheus for metrics collection and alerting
- Grafana for visualization and dashboards
- Loki for centralized log aggregation
- Vector for unified observability pipeline
- cAdvisor for container resource monitoring

**Key Benefits:**
- Early detection of service failures
- Performance bottleneck identification
- Historical metrics for capacity planning
- Centralized logging for troubleshooting
- Automated alerts for critical issues

## Health Check System

### Docker Health Checks

Every service in docker-compose.yml includes a health check configuration:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U devuser -d devdb"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    restart: unless-stopped
```

**Health Check Parameters:**
- `test`: Command to determine service health
- `interval`: Time between health checks
- `timeout`: Maximum time for check to complete
- `retries`: Number of consecutive failures before unhealthy
- `start_period`: Grace period during startup

### Service Dependencies

All services depend on Vault being healthy:

```yaml
services:
  postgres:
    depends_on:
      vault:
        condition: service_healthy
    healthcheck:
      # ... health check config
```

**Dependency Chain:**
1. Vault starts first
2. Vault health check passes (unsealed + initialized)
3. Dependent services start
4. Each service fetches credentials from Vault
5. Service-specific health checks activate

### Startup Order

The startup sequence ensures proper initialization:

```
Start Attempt
└── Vault Container Starts
    ├── Auto-unseal script runs
    ├── Vault initializes (if first run)
    ├── Vault unseals automatically
    └── Health check: unsealed + initialized
        └── Health Check PASSES
            └── Dependent Services Start
                ├── PostgreSQL
                ├── MySQL
                ├── MongoDB
                ├── Redis (nodes 1, 2, 3)
                ├── RabbitMQ
                └── Forgejo
                    └── Each service:
                        ├── Init script fetches credentials from Vault
                        ├── Service starts with credentials
                        └── Service health check activates
```

**View startup logs:**

```bash
# Watch all services start
docker compose up -d && docker compose logs -f

# Check specific service startup
./manage-colima.sh logs vault
./manage-colima.sh logs postgres
```

## Health Command

### Usage

The management script provides a comprehensive health check command:

```bash
# Check health of all services
./manage-colima.sh health

# Check status (includes resource usage)
./manage-colima.sh status
```

**Sample Output:**

```
=== Colima Services Health Check ===

Vault:          healthy (unsealed)
PostgreSQL:     healthy
MySQL:          healthy
MongoDB:        healthy
Redis-1:        healthy
Redis-2:        healthy
Redis-3:        healthy
Redis Cluster:  healthy (3 masters, all slots assigned)
RabbitMQ:       healthy
Forgejo:        healthy
Prometheus:     healthy
Grafana:        healthy
Loki:           healthy

Reference Apps:
  FastAPI:      healthy
  Go API:       healthy
  Node.js API:  healthy
  Rust API:     healthy

Overall Status: ALL SERVICES HEALTHY
```

### Output Interpretation

**Health States:**
- `healthy`: Service is running and responding correctly
- `unhealthy`: Service is running but health check fails
- `starting`: Service is in startup grace period
- `not running`: Container is not running

**What to check when unhealthy:**

```bash
# View service logs
./manage-colima.sh logs <service>

# Check container details
docker inspect <service> | jq '.[0].State.Health'

# Check last health check
docker inspect <service> | jq '.[0].State.Health.Log[-1]'
```

### Automated Health Checks

Create a monitoring script to check health periodically:

**Script:** `scripts/monitor-health.sh`

```bash
#!/bin/bash

LOGFILE="/var/log/colima-services-health.log"
ALERT_EMAIL="admin@example.com"

check_health() {
  ./manage-colima.sh health > /tmp/health-check.txt

  if grep -q "unhealthy" /tmp/health-check.txt; then
    echo "$(date): UNHEALTHY SERVICES DETECTED" >> $LOGFILE
    cat /tmp/health-check.txt >> $LOGFILE

    # Send alert (requires mail configured)
    mail -s "Colima Services Alert: Unhealthy Services" $ALERT_EMAIL < /tmp/health-check.txt

    # Attempt automatic recovery
    ./manage-colima.sh restart
  else
    echo "$(date): All services healthy" >> $LOGFILE
  fi
}

check_health
```

**Schedule with cron:**

```bash
# Add to crontab
crontab -e

# Check health every 5 minutes
*/5 * * * * /path/to/colima-services/scripts/monitor-health.sh
```

## Prometheus Monitoring

### Metrics Collection

Prometheus scrapes metrics from all services:

**Access Prometheus:**
```bash
open http://localhost:9090
```

**Configuration:** `configs/prometheus/prometheus.yml`

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Container metrics
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  # PostgreSQL metrics
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  # Redis metrics
  - job_name: 'redis'
    static_configs:
      - targets:
        - 'redis-1:6379'
        - 'redis-2:6379'
        - 'redis-3:6379'
    metrics_path: /metrics

  # RabbitMQ metrics
  - job_name: 'rabbitmq'
    static_configs:
      - targets: ['rabbitmq:15692']

  # Reference application metrics
  - job_name: 'fastapi'
    static_configs:
      - targets: ['reference-api:8000']
    metrics_path: /metrics

  # Node exporter (future)
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
```

### Exposed Metrics

Each service exposes different metrics:

**PostgreSQL Metrics (via postgres-exporter):**
```
pg_up                          # Database is up
pg_stat_database_*             # Database statistics
pg_stat_replication_*          # Replication status
pg_locks_*                     # Lock information
pg_stat_activity_*             # Active connections
```

**Redis Metrics:**
```
redis_up                       # Redis is up
redis_connected_clients        # Active connections
redis_used_memory_bytes        # Memory usage
redis_commands_processed_total # Total commands
redis_keyspace_hits_total      # Cache hits
redis_keyspace_misses_total    # Cache misses
```

**RabbitMQ Metrics:**
```
rabbitmq_up                    # RabbitMQ is up
rabbitmq_connections           # Active connections
rabbitmq_channels              # Active channels
rabbitmq_queues               # Queue count
rabbitmq_queue_messages        # Messages in queues
```

**Container Metrics (cAdvisor):**
```
container_cpu_usage_seconds_total
container_memory_usage_bytes
container_network_receive_bytes_total
container_network_transmit_bytes_total
container_fs_reads_total
container_fs_writes_total
```

### Query Examples

**Prometheus Query Language (PromQL) Examples:**

```promql
# CPU usage per container
rate(container_cpu_usage_seconds_total{name=~"dev-.*"}[5m]) * 100

# Memory usage per container (MB)
container_memory_usage_bytes{name=~"dev-.*"} / 1024 / 1024

# PostgreSQL active connections
pg_stat_database_numbackends{datname="devdb"}

# Redis memory usage (MB)
redis_memory_used_bytes / 1024 / 1024

# RabbitMQ queue depth
rabbitmq_queue_messages{queue="tasks"}

# FastAPI request rate (requests/sec)
rate(http_requests_total{app="fastapi"}[1m])

# FastAPI request latency (95th percentile)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Redis cache hit rate
rate(redis_keyspace_hits_total[5m]) / (rate(redis_keyspace_hits_total[5m]) + rate(redis_keyspace_misses_total[5m]))
```

## Grafana Dashboards

### Pre-configured Dashboards

Access Grafana:
```bash
open http://localhost:3001
# Default credentials: admin/admin (change on first login)
```

**Available Dashboards:**
1. **Container Overview** - Resource usage across all containers
2. **PostgreSQL Performance** - Database metrics and queries
3. **Redis Cluster** - Cluster health and performance
4. **RabbitMQ** - Queue depths and message rates
5. **Application Metrics** - FastAPI request rates and latencies

### Creating Custom Dashboards

**Example: PostgreSQL Connection Dashboard**

1. Navigate to Grafana → Dashboards → New Dashboard
2. Add Panel → Add Query
3. Select Prometheus data source
4. Enter query:

```promql
pg_stat_database_numbackends{datname="devdb"}
```

5. Set visualization type (Graph, Gauge, Table)
6. Configure panel options:
   - Title: "PostgreSQL Active Connections"
   - Unit: "connections"
   - Legend: `{{instance}}`
7. Save dashboard

**JSON Dashboard Export:**

```json
{
  "dashboard": {
    "title": "PostgreSQL Connections",
    "panels": [
      {
        "targets": [
          {
            "expr": "pg_stat_database_numbackends{datname=\"devdb\"}",
            "legendFormat": "{{instance}}"
          }
        ],
        "type": "graph",
        "title": "Active Connections"
      }
    ]
  }
}
```

### Alert Configuration

**Example: High Memory Alert**

1. Navigate to Alerting → Alert Rules → New Alert Rule
2. Configure query:

```promql
(container_memory_usage_bytes{name=~"dev-postgres"} / container_spec_memory_limit_bytes{name=~"dev-postgres"}) * 100 > 80
```

3. Set conditions:
   - Threshold: 80%
   - Evaluation interval: 1m
   - For: 5m (alert after 5 minutes above threshold)

4. Configure notifications:
   - Contact point: Email, Slack, PagerDuty
   - Message: "PostgreSQL memory usage above 80%"

5. Save alert rule

**Alert via Prometheus (Alternative):**

**File:** `configs/prometheus/alerts.yml`

```yaml
groups:
  - name: service_alerts
    interval: 30s
    rules:
      - alert: HighMemoryUsage
        expr: (container_memory_usage_bytes / container_spec_memory_limit_bytes) * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.name }}"
          description: "Container {{ $labels.name }} memory usage is {{ $value }}%"

      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "Service {{ $labels.job }} on {{ $labels.instance }} has been down for 1 minute"
```

## Log Aggregation with Loki

### Log Collection

Loki collects logs from all containers via Vector:

**Access Loki:**
```bash
# Via Grafana Explore
open http://localhost:3001/explore

# Direct Loki API
curl http://localhost:3100/ready
```

**Vector Configuration:** `configs/vector/vector.toml`

```toml
[sources.docker_logs]
type = "docker_logs"
include_containers = ["dev-*"]

[sinks.loki]
type = "loki"
inputs = ["docker_logs"]
endpoint = "http://loki:3100"
encoding.codec = "json"
labels.container_name = "{{ container_name }}"
labels.service = "{{ label.\"com.docker.compose.service\" }}"
```

### Querying Logs

**LogQL Examples (in Grafana Explore):**

```logql
# All logs from PostgreSQL
{container_name="dev-postgres"}

# Errors from any service
{container_name=~"dev-.*"} |= "ERROR"

# Vault authentication logs
{container_name="dev-vault"} |= "auth"

# PostgreSQL slow queries
{container_name="dev-postgres"} |= "duration:" | duration > 1000

# Redis cluster errors
{container_name=~"dev-redis-.*"} |= "error"

# RabbitMQ connection logs
{container_name="dev-rabbitmq"} |= "connection"

# Rate of errors per minute
rate({container_name=~"dev-.*"} |= "ERROR" [1m])
```

**Query via CLI:**

```bash
# Install logcli
brew install logcli

# Set Loki address
export LOKI_ADDR=http://localhost:3100

# Query logs
logcli query '{container_name="dev-postgres"}' --limit=50 --since=1h
```

### Log Retention

Configure log retention in Loki:

**File:** `configs/loki/loki.yml`

```yaml
schema_config:
  configs:
    - from: 2024-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/cache
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

limits_config:
  retention_period: 720h  # 30 days
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20

compactor:
  working_directory: /loki/compactor
  shared_store: filesystem
  retention_enabled: true
  retention_delete_delay: 2h
```

## Container Health Checks

### Vault Health Check

```yaml
vault:
  healthcheck:
    test: ["CMD", "sh", "-c", "vault status | grep -q 'Sealed.*false' && vault status | grep -q 'Initialized.*true'"]
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 30s
```

**Manual Health Check:**

```bash
# Via API
curl -s http://localhost:8200/v1/sys/health | jq

# Via CLI
vault status

# Expected output:
# Sealed: false
# Initialized: true
```

### Database Health Checks

**PostgreSQL:**

```yaml
postgres:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U devuser -d devdb"]
    interval: 10s
    timeout: 5s
    retries: 5
```

**Manual Check:**

```bash
docker exec dev-postgres pg_isready -U devuser -d devdb
# Output: localhost:5432 - accepting connections
```

**MySQL:**

```yaml
mysql:
  healthcheck:
    test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p$$MYSQL_ROOT_PASSWORD"]
    interval: 10s
    timeout: 5s
    retries: 5
```

**MongoDB:**

```yaml
mongodb:
  healthcheck:
    test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
    interval: 10s
    timeout: 5s
    retries: 5
```

### Redis Cluster Health

```yaml
redis-1:
  healthcheck:
    test: ["CMD", "redis-cli", "-a", "$$REDIS_PASSWORD", "ping"]
    interval: 10s
    timeout: 5s
    retries: 5
```

**Cluster Health Check:**

```bash
# Check cluster status
docker exec dev-redis-1 redis-cli -a $(./manage-colima.sh vault-show-password redis-1) cluster info

# Expected output:
# cluster_state:ok
# cluster_slots_assigned:16384
# cluster_known_nodes:3
```

### RabbitMQ Health Check

```yaml
rabbitmq:
  healthcheck:
    test: ["CMD", "rabbitmq-diagnostics", "ping"]
    interval: 10s
    timeout: 5s
    retries: 5
```

**Manual Check:**

```bash
docker exec dev-rabbitmq rabbitmq-diagnostics status
docker exec dev-rabbitmq rabbitmq-diagnostics check_running
```

## Metrics Endpoints

### Service Metrics

Each service exposes metrics on different endpoints:

**FastAPI Metrics:**
```bash
curl http://localhost:8000/metrics

# Prometheus format:
# http_requests_total{method="GET",endpoint="/health"} 42
# http_request_duration_seconds_sum 1.23
```

**PostgreSQL Metrics (via exporter):**
```bash
curl http://localhost:9187/metrics
```

**Redis Metrics:**
```bash
# Via INFO command
docker exec dev-redis-1 redis-cli -a password info stats

# Via Prometheus endpoint (if redis-exporter enabled)
curl http://localhost:9121/metrics
```

**RabbitMQ Metrics:**
```bash
curl http://localhost:15692/metrics
```

### Custom Metrics

**Add custom metrics to FastAPI app:**

```python
from prometheus_client import Counter, Histogram, Gauge

# Request counter
request_count = Counter(
    'app_requests_total',
    'Total requests',
    ['method', 'endpoint', 'status']
)

# Request duration
request_duration = Histogram(
    'app_request_duration_seconds',
    'Request duration',
    ['method', 'endpoint']
)

# Active connections
active_connections = Gauge(
    'app_active_connections',
    'Active connections'
)

# Instrument endpoints
@app.get("/api/data")
async def get_data():
    with request_duration.labels(method='GET', endpoint='/api/data').time():
        request_count.labels(method='GET', endpoint='/api/data', status=200).inc()
        return {"data": "value"}
```

## Troubleshooting Unhealthy Services

### Common Issues

**1. Service Shows Unhealthy**

```bash
# Check recent logs
./manage-colima.sh logs <service> | tail -50

# Check health check command
docker inspect <service> | jq '.[0].State.Health'

# Run health check manually
docker exec <service> <health-check-command>
```

**2. Service Can't Reach Vault**

```bash
# Test Vault connectivity from service
docker exec <service> curl -v http://vault:8200/v1/sys/health

# Check Vault is unsealed
./manage-colima.sh vault-status

# Check network connectivity
docker exec <service> ping vault
```

**3. Health Check Timeout**

```bash
# Increase timeout in docker-compose.yml
healthcheck:
  timeout: 10s  # Increase from 5s
  start_period: 60s  # Increase grace period
```

### Debugging Steps

**Step 1: Check Container Status**

```bash
docker compose ps
# Look for containers not in "Up (healthy)" state
```

**Step 2: Review Logs**

```bash
./manage-colima.sh logs <service>

# Look for:
# - Startup errors
# - Vault connection failures
# - Configuration errors
# - Permission issues
```

**Step 3: Test Health Check Manually**

```bash
# Get health check command
docker inspect <service> | jq '.[0].Config.Healthcheck.Test'

# Run it manually inside container
docker exec <service> <health-check-command>
```

**Step 4: Check Dependencies**

```bash
# Ensure Vault is healthy first
curl http://localhost:8200/v1/sys/health

# Check if credentials exist
vault kv get secret/<service>
```

**Step 5: Review Resource Usage**

```bash
# Check if container is resource-constrained
docker stats <service>

# Look for high CPU or memory usage
```

### Recovery Procedures

**Restart Single Service:**

```bash
docker compose restart <service>
```

**Recreate Service:**

```bash
docker compose up -d --force-recreate <service>
```

**Full Environment Restart:**

```bash
./manage-colima.sh restart
```

**Reset and Rebuild:**

```bash
# WARNING: This deletes all data
./manage-colima.sh reset
./manage-colima.sh start
./manage-colima.sh vault-init
./manage-colima.sh vault-bootstrap
```

**Check After Recovery:**

```bash
# Verify service is healthy
./manage-colima.sh health

# Check logs for errors
./manage-colima.sh logs <service>

# Run service-specific tests
./tests/test-<service>.sh
```

## Related Pages

- [CLI-Reference](CLI-Reference) - Management script commands
- [Service-Configuration](Service-Configuration) - Service configuration details
- [Vault-Troubleshooting](Vault-Troubleshooting) - Vault-specific issues
- [Observability-Stack](Observability-Stack) - Prometheus, Grafana, Loki setup
- [Prometheus-Queries](Prometheus-Queries) - Useful PromQL queries
- [Grafana-Dashboards](Grafana-Dashboards) - Dashboard configuration
- [Performance-Tuning](Performance-Tuning) - Optimization guide
- [Network-Issues](Network-Issues) - Connectivity troubleshooting
