# Performance Tuning

## Table of Contents

- [Overview](#overview)
- [Colima VM Resource Allocation](#colima-vm-resource-allocation)
  - [CPU Allocation](#cpu-allocation)
  - [Memory Allocation](#memory-allocation)
  - [Disk Allocation](#disk-allocation)
  - [VM Type Selection](#vm-type-selection)
- [PostgreSQL Performance Tuning](#postgresql-performance-tuning)
  - [Memory Configuration](#postgresql-memory-configuration)
  - [Connection Pooling](#postgresql-connection-pooling)
  - [Query Optimization](#query-optimization)
  - [Indexes](#indexes)
- [MySQL Optimization](#mysql-optimization)
  - [InnoDB Configuration](#innodb-configuration)
  - [Query Cache](#query-cache)
  - [Table Optimization](#table-optimization)
- [Redis Cluster Performance](#redis-cluster-performance)
  - [Memory Management](#redis-memory-management)
  - [Persistence Options](#persistence-options)
  - [Pipeline Commands](#pipeline-commands)
  - [Connection Management](#connection-management)
- [RabbitMQ Tuning](#rabbitmq-tuning)
  - [Memory Configuration](#rabbitmq-memory-configuration)
  - [Prefetch Settings](#prefetch-settings)
  - [Queue Optimization](#queue-optimization)
- [MongoDB Optimization](#mongodb-optimization)
  - [WiredTiger Cache](#wiredtiger-cache)
  - [Index Optimization](#mongodb-indexes)
  - [Aggregation Pipeline](#aggregation-pipeline)
- [Container Resource Limits](#container-resource-limits)
  - [CPU Limits](#cpu-limits)
  - [Memory Limits](#memory-limits)
  - [I/O Limits](#io-limits)
- [Monitoring Performance Metrics](#monitoring-performance-metrics)
  - [Container Metrics](#container-metrics)
  - [Database Metrics](#database-metrics)
  - [Application Metrics](#application-metrics)
- [Identifying Bottlenecks](#identifying-bottlenecks)
  - [CPU Bottlenecks](#cpu-bottlenecks)
  - [Memory Bottlenecks](#memory-bottlenecks)
  - [Disk I/O Bottlenecks](#disk-io-bottlenecks)
  - [Network Bottlenecks](#network-bottlenecks)
- [Related Pages](#related-pages)

## Overview

Performance tuning is essential for optimal operation of the devstack-core environment. This page provides guidance on optimizing resource allocation, database performance, and identifying bottlenecks.

**Performance Optimization Areas:**
- Colima VM resources (CPU, memory, disk)
- Database configuration and tuning
- Container resource limits
- Application optimization
- Network performance

**Key Metrics to Monitor:**
- CPU usage and saturation
- Memory usage and swap
- Disk I/O throughput and latency
- Network bandwidth and latency
- Query response times
- Connection pool utilization

## Colima VM Resource Allocation

### CPU Allocation

**Configure CPU cores for Colima:**

```bash
# Check available CPUs
sysctl -n hw.ncpu

# Start Colima with specific CPU count
colima start --cpu 4

# For high-performance workloads
colima start --cpu 8

# Update existing instance
colima stop
colima start --cpu 6
```

**Recommendations:**
- Development: 2-4 CPUs
- Heavy workloads: 6-8 CPUs
- Production-like: 8+ CPUs

**Monitor CPU usage:**

```bash
# Inside Colima VM
colima ssh
top

# From host
docker stats

# Per-container CPU usage
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

### Memory Allocation

**Configure memory for Colima:**

```bash
# Start with 8GB
colima start --memory 8

# For heavy workloads (16GB)
colima start --memory 16

# Update existing
colima stop
colima start --memory 12
```

**Memory recommendations:**

| Workload | Memory |
|----------|--------|
| Light development | 4-6 GB |
| Standard development | 8 GB |
| Heavy workloads | 12-16 GB |
| Production-like | 16+ GB |

**Memory distribution:**
```
Total 8GB allocation:
- PostgreSQL: 2GB
- MySQL: 1GB
- MongoDB: 1GB
- Redis Cluster: 1GB (768MB across 3 nodes)
- RabbitMQ: 512MB
- Vault: 256MB
- Applications: 1.5GB
- System: 1GB
```

### Disk Allocation

**Configure disk size:**

```bash
# Start with 50GB
colima start --disk 50

# For large datasets (100GB)
colima start --disk 100

# Check disk usage
colima ssh df -h
```

**Optimize disk performance:**

```bash
# Use virtiofs for better performance (Apple Silicon)
colima start --mount-type virtiofs

# Enable Rosetta for better x86_64 emulation
colima start --vz-rosetta

# Combined optimized start
colima start \
  --cpu 8 \
  --memory 16 \
  --disk 100 \
  --vm-type vz \
  --vz-rosetta \
  --mount-type virtiofs \
  --network-address
```

### VM Type Selection

**Choose VM type for performance:**

```bash
# QEMU (default, compatible)
colima start --vm-type qemu

# VZ (Apple Silicon, faster)
colima start --vm-type vz

# With Rosetta 2 (best performance for x86_64 images)
colima start --vm-type vz --vz-rosetta
```

**Performance comparison:**
- QEMU: Compatible, slower
- VZ: Native, 2-3x faster
- VZ + Rosetta: Best for mixed architectures

## PostgreSQL Performance Tuning

### PostgreSQL Memory Configuration

**Optimize shared_buffers:**

```conf
# configs/postgres/postgresql.conf

# Rule of thumb: 25% of system RAM
# For 8GB RAM allocated to Colima:
shared_buffers = 2GB  # 25% of 8GB

# For 16GB RAM:
shared_buffers = 4GB
```

**Effective cache size:**

```conf
# Should be 50-75% of total RAM
# For 8GB system:
effective_cache_size = 6GB

# For 16GB system:
effective_cache_size = 12GB
```

**Work memory:**

```conf
# Per-operation memory
# Formula: (Total RAM - shared_buffers) / (max_connections * 3)
# For 8GB RAM, 2GB shared_buffers, 200 connections:
work_mem = 10MB

# For complex queries:
work_mem = 50MB
```

**Maintenance work memory:**

```conf
# For VACUUM, CREATE INDEX operations
# 5-10% of RAM
maintenance_work_mem = 512MB  # For 8GB RAM
maintenance_work_mem = 1GB     # For 16GB RAM
```

**Complete memory configuration:**

```conf
# Memory Settings
shared_buffers = 2GB
effective_cache_size = 6GB
work_mem = 10MB
maintenance_work_mem = 512MB
temp_buffers = 32MB

# Checkpoint Settings
checkpoint_completion_target = 0.9
wal_buffers = 16MB
max_wal_size = 2GB
min_wal_size = 1GB

# Cost-based vacuum delay
vacuum_cost_delay = 0
vacuum_cost_limit = 200

# Background writer
bgwriter_delay = 200ms
bgwriter_lru_maxpages = 100
bgwriter_lru_multiplier = 2.0
```

### PostgreSQL Connection Pooling

**Use PgBouncer for connection pooling:**

```yaml
# docker-compose.yml
services:
  pgbouncer:
    image: pgbouncer/pgbouncer:latest
    environment:
      DATABASES_HOST: postgres
      DATABASES_PORT: 5432
      DATABASES_USER: devuser
      DATABASES_PASSWORD: ${POSTGRES_PASSWORD}
      DATABASES_DBNAME: devdb
      PGBOUNCER_POOL_MODE: transaction
      PGBOUNCER_MAX_CLIENT_CONN: 1000
      PGBOUNCER_DEFAULT_POOL_SIZE: 25
      PGBOUNCER_MIN_POOL_SIZE: 10
      PGBOUNCER_RESERVE_POOL_SIZE: 5
    ports:
      - "6432:6432"
```

**PgBouncer configuration:**

```ini
# configs/pgbouncer/pgbouncer.ini
[databases]
devdb = host=postgres port=5432 dbname=devdb

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
min_pool_size = 10
reserve_pool_size = 5
max_db_connections = 50
max_user_connections = 50

# Connection lifetime
server_idle_timeout = 600
server_lifetime = 3600
```

**Benefits:**
- Reduce connection overhead
- Handle 1000s of client connections
- Use only 25-50 server connections
- 10-20x better connection handling

### Query Optimization

**Enable query planning statistics:**

```sql
-- Analyze query performance
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'user@example.com';

-- View slow queries
SELECT pid, now() - pg_stat_activity.query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - pg_stat_activity.query_start > interval '5 seconds';

-- Enable auto_explain for slow queries
ALTER DATABASE devdb SET auto_explain.log_min_duration = 1000; -- 1 second
```

**Optimize queries:**

```sql
-- Bad: SELECT *
SELECT * FROM users WHERE id = 1;

-- Good: SELECT specific columns
SELECT id, username, email FROM users WHERE id = 1;

-- Use proper JOINs
SELECT u.username, o.total
FROM users u
INNER JOIN orders o ON u.id = o.user_id
WHERE u.id = 1;

-- Avoid N+1 queries
-- Bad: Loop through users, query orders for each
-- Good: Single JOIN query
SELECT u.*, o.* FROM users u LEFT JOIN orders o ON u.id = o.user_id;
```

### Indexes

**Create appropriate indexes:**

```sql
-- Index on frequently queried columns
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_created_at ON orders(created_at);

-- Composite index for multi-column queries
CREATE INDEX idx_orders_user_status ON orders(user_id, status);

-- Partial index for specific conditions
CREATE INDEX idx_active_users ON users(id) WHERE active = true;

-- View index usage
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;

-- Remove unused indexes
DROP INDEX idx_unused;
```

## MySQL Optimization

### InnoDB Configuration

**Optimize InnoDB:**

```ini
# configs/mysql/my.cnf

[mysqld]
# InnoDB Buffer Pool (70-80% of RAM)
innodb_buffer_pool_size = 2G  # For 4GB allocated to MySQL

# InnoDB Log Settings
innodb_log_file_size = 512M
innodb_log_buffer_size = 16M
innodb_flush_log_at_trx_commit = 2  # Better performance, less durable

# InnoDB I/O Settings
innodb_flush_method = O_DIRECT
innodb_io_capacity = 200
innodb_io_capacity_max = 2000
innodb_read_io_threads = 4
innodb_write_io_threads = 4

# InnoDB Performance
innodb_thread_concurrency = 0
innodb_lock_wait_timeout = 50
innodb_buffer_pool_instances = 8  # For buffer_pool_size > 1GB
```

### Query Cache

**Note: Query cache removed in MySQL 8.0+**

For MySQL 5.7:

```ini
[mysqld]
query_cache_type = 1
query_cache_size = 256M
query_cache_limit = 2M
```

### Table Optimization

**Optimize tables:**

```sql
-- Analyze table statistics
ANALYZE TABLE users;

-- Optimize table (defragment, rebuild indexes)
OPTIMIZE TABLE users;

-- Check table for errors
CHECK TABLE users;

-- View table status
SHOW TABLE STATUS LIKE 'users';

-- Convert to optimal engine if needed
ALTER TABLE users ENGINE=InnoDB;
```

## Redis Cluster Performance

### Redis Memory Management

**Configure memory:**

```conf
# configs/redis/redis.conf

# Maximum memory (256MB per node)
maxmemory 256mb

# Eviction policy
maxmemory-policy allkeys-lru

# LFU (Least Frequently Used) - Better for most workloads
maxmemory-policy allkeys-lfu

# Tune LFU parameters
lfu-log-factor 10
lfu-decay-time 1

# Memory sampling
maxmemory-samples 5
```

**Memory optimization:**

```bash
# Check memory usage
docker exec dev-redis-1 redis-cli INFO memory

# used_memory: 1.5M
# used_memory_peak: 2.1M
# maxmemory: 268435456 (256MB)

# Optimize memory usage
docker exec dev-redis-1 redis-cli CONFIG SET activedefrag yes
docker exec dev-redis-1 redis-cli CONFIG SET active-defrag-threshold-lower 10
```

### Persistence Options

**Balance performance vs durability:**

```conf
# Fastest: No persistence
save ""
appendonly no

# Balanced: RDB snapshots
save 900 1
save 300 10
save 60 10000
appendonly no

# Most durable: AOF
appendonly yes
appendfsync everysec  # Balanced
# appendfsync always   # Slowest, most durable
# appendfsync no       # Fastest, less durable

# Hybrid: RDB + AOF
save 900 1
appendonly yes
appendfsync everysec
```

### Pipeline Commands

**Use pipelining for bulk operations:**

```python
# Bad: Individual commands
for key in keys:
    redis.set(key, value)  # RTT for each command

# Good: Pipeline
pipe = redis.pipeline()
for key in keys:
    pipe.set(key, value)
pipe.execute()  # Single RTT for all commands

# 10-100x faster for bulk operations
```

### Connection Management

**Optimize connections:**

```python
# Use connection pooling
import redis

pool = redis.ConnectionPool(
    host='localhost',
    port=6379,
    max_connections=50,
    decode_responses=True
)

redis_client = redis.Redis(connection_pool=pool)
```

**Configure Redis connections:**

```conf
# configs/redis/redis.conf

# Maximum clients
maxclients 10000

# Timeout idle connections
timeout 300

# TCP settings
tcp-backlog 511
tcp-keepalive 300
```

## RabbitMQ Tuning

### RabbitMQ Memory Configuration

**Configure memory limits:**

```conf
# configs/rabbitmq/rabbitmq.conf

# Memory thresholds
vm_memory_high_watermark.relative = 0.6  # 60% of RAM

# Absolute limit (if needed)
vm_memory_high_watermark.absolute = 1GB

# Paging threshold
vm_memory_high_watermark_paging_ratio = 0.75

# Disk free limit
disk_free_limit.relative = 1.0  # 100% of disk
disk_free_limit.absolute = 5GB
```

### Prefetch Settings

**Optimize message consumption:**

```python
# Set prefetch count
channel.basic_qos(prefetch_count=10)

# Process messages
def callback(ch, method, properties, body):
    # Process message
    process(body)
    ch.basic_ack(delivery_tag=method.delivery_tag)

channel.basic_consume(queue='tasks', on_message_callback=callback)
```

**Prefetch recommendations:**
- High throughput, fast processing: 50-100
- Moderate throughput: 10-20
- Slow processing: 1-5

### Queue Optimization

**Configure queue properties:**

```python
# Durable queue with limits
channel.queue_declare(
    queue='tasks',
    durable=True,
    arguments={
        'x-max-length': 10000,           # Max messages
        'x-max-length-bytes': 104857600, # Max 100MB
        'x-message-ttl': 86400000,       # 24 hours TTL
        'x-overflow': 'reject-publish'   # Reject when full
    }
)

# Lazy queues (store to disk)
channel.queue_declare(
    queue='large-queue',
    arguments={
        'x-queue-mode': 'lazy'  # Better for large queues
    }
)
```

## MongoDB Optimization

### WiredTiger Cache

**Configure cache size:**

```yaml
# configs/mongodb/mongod.conf

storage:
  wiredTiger:
    engineConfig:
      # 50-80% of RAM allocated to MongoDB
      cacheSizeGB: 2  # For 4GB RAM
    collectionConfig:
      blockCompressor: snappy
    indexConfig:
      prefixCompression: true
```

### MongoDB Indexes

**Create efficient indexes:**

```javascript
// Single field index
db.users.createIndex({ email: 1 })

// Compound index
db.orders.createIndex({ user_id: 1, created_at: -1 })

// Text index for search
db.articles.createIndex({ title: "text", content: "text" })

// View index usage
db.users.aggregate([{ $indexStats: {} }])

// Drop unused indexes
db.users.dropIndex("old_index")
```

### Aggregation Pipeline

**Optimize aggregation queries:**

```javascript
// Bad: Load all data into memory
db.orders.find().toArray()

// Good: Use aggregation pipeline
db.orders.aggregate([
  { $match: { status: "completed" } },  // Filter early
  { $sort: { created_at: -1 } },        // Sort
  { $limit: 100 },                       // Limit results
  { $project: { _id: 0, total: 1 } }    // Select fields
])

// Use $lookup for joins (but avoid if possible)
db.users.aggregate([
  {
    $lookup: {
      from: "orders",
      localField: "_id",
      foreignField: "user_id",
      as: "orders"
    }
  }
])
```

## Container Resource Limits

### CPU Limits

**Set CPU limits per container:**

```yaml
# docker-compose.yml
services:
  postgres:
    deploy:
      resources:
        limits:
          cpus: '2.0'  # Max 2 CPUs
        reservations:
          cpus: '0.5'  # Guaranteed 0.5 CPU

  reference-api:
    deploy:
      resources:
        limits:
          cpus: '1.0'
```

### Memory Limits

**Set memory limits:**

```yaml
services:
  postgres:
    deploy:
      resources:
        limits:
          memory: 2G  # Max 2GB
        reservations:
          memory: 1G  # Guaranteed 1GB
    mem_swappiness: 0  # Disable swap

  redis-1:
    deploy:
      resources:
        limits:
          memory: 512M
```

### I/O Limits

**Limit disk I/O:**

```yaml
services:
  postgres:
    blkio_config:
      weight: 500  # 100-1000, higher = more I/O
      device_read_bps:
        - path: /dev/sda
          rate: '50mb'
      device_write_bps:
        - path: /dev/sda
          rate: '50mb'
```

## Monitoring Performance Metrics

### Container Metrics

**Monitor with docker stats:**

```bash
# Real-time stats
docker stats

# Formatted output
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

# Specific containers
docker stats dev-postgres dev-mysql dev-redis-1
```

### Database Metrics

**PostgreSQL metrics:**

```sql
-- Active connections
SELECT count(*) FROM pg_stat_activity;

-- Database size
SELECT pg_size_pretty(pg_database_size('devdb'));

-- Table sizes
SELECT schemaname, tablename,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Cache hit ratio (should be > 99%)
SELECT
  sum(heap_blks_read) as heap_read,
  sum(heap_blks_hit) as heap_hit,
  sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) as ratio
FROM pg_statio_user_tables;
```

### Application Metrics

**Expose metrics in FastAPI:**

```python
from prometheus_client import Counter, Histogram, Gauge
from prometheus_client import make_asgi_app

# Metrics
request_count = Counter('app_requests_total', 'Total requests', ['method', 'endpoint'])
request_duration = Histogram('app_request_duration_seconds', 'Request duration')
active_connections = Gauge('app_active_connections', 'Active connections')

# Mount metrics endpoint
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

# Instrument requests
@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time

    request_count.labels(method=request.method, endpoint=request.url.path).inc()
    request_duration.observe(duration)

    return response
```

## Identifying Bottlenecks

### CPU Bottlenecks

**Symptoms:**
- High CPU usage (> 80%)
- Slow response times
- Requests queuing

**Diagnosis:**

```bash
# Check CPU usage
docker stats

# Inside container
docker exec dev-postgres top

# Check for CPU-intensive queries
docker exec dev-postgres psql -U postgres -c "
  SELECT pid, now() - query_start AS duration, query
  FROM pg_stat_activity
  WHERE state = 'active'
  ORDER BY duration DESC;"
```

**Solutions:**
- Add more CPU cores to Colima
- Optimize queries
- Add indexes
- Use connection pooling
- Scale horizontally

### Memory Bottlenecks

**Symptoms:**
- High memory usage
- Swap usage
- OOM kills
- Slow queries

**Diagnosis:**

```bash
# Check memory usage
docker stats

# Inside Colima VM
colima ssh
free -h
vmstat 1

# Check swap
swapon --show
```

**Solutions:**
- Increase Colima memory
- Tune database memory settings
- Reduce shared_buffers
- Use connection pooling
- Implement caching

### Disk I/O Bottlenecks

**Symptoms:**
- Slow writes
- High iowait
- Slow backups

**Diagnosis:**

```bash
# Check disk I/O
docker stats  # Check BlockIO

# Inside Colima VM
colima ssh
iostat -x 1

# Check for slow queries
docker exec dev-postgres psql -U postgres -c "
  SELECT * FROM pg_stat_statements
  ORDER BY total_time DESC
  LIMIT 10;"
```

**Solutions:**
- Use SSD storage
- Increase wal_buffers
- Tune checkpoint settings
- Use virtiofs mount type
- Reduce fsync frequency (trade durability)

### Network Bottlenecks

**Symptoms:**
- Slow API responses
- High latency between services
- Connection timeouts

**Diagnosis:**

```bash
# Check network I/O
docker stats  # Check NetIO

# Test latency
docker exec dev-postgres ping vault

# Check open connections
docker exec dev-postgres netstat -an | grep ESTABLISHED | wc -l
```

**Solutions:**
- Use host networking (if possible)
- Implement connection pooling
- Use Redis for caching
- Batch database operations
- Optimize API payloads

## Related Pages

- [Service-Configuration](Service-Configuration) - Service tuning options
- [Colima-Configuration](Colima-Configuration) - VM configuration
- [Health-Monitoring](Health-Monitoring) - Performance monitoring
- [Prometheus-Queries](Prometheus-Queries) - Metrics queries
- [Database Optimization](Service-Configuration) - Database tuning
