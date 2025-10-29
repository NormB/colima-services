# Redis Cluster

## Table of Contents

- [Overview](#overview)
- [Redis Cluster Architecture](#redis-cluster-architecture)
  - [Three-Node Cluster](#three-node-cluster)
  - [No Replicas in Development](#no-replicas-in-development)
  - [Hash Slot Distribution](#hash-slot-distribution)
- [Cluster Initialization](#cluster-initialization)
  - [Automated Initialization](#automated-initialization)
  - [Manual Initialization](#manual-initialization)
  - [Verification](#verification)
- [Cluster Operations](#cluster-operations)
  - [Cluster Info](#cluster-info)
  - [Node Status](#node-status)
  - [Slot Assignment](#slot-assignment)
  - [Resharding](#resharding)
- [Data Sharding and Redirection](#data-sharding-and-redirection)
  - [Hash Slot Algorithm](#hash-slot-algorithm)
  - [MOVED Redirects](#moved-redirects)
  - [ASK Redirects](#ask-redirects)
- [Using redis-cli with Cluster Mode](#using-redis-cli-with-cluster-mode)
  - [Cluster Mode Flag](#cluster-mode-flag)
  - [Basic Operations](#basic-operations)
  - [Multi-Key Operations](#multi-key-operations)
- [FastAPI Cluster Inspection APIs](#fastapi-cluster-inspection-apis)
  - [Cluster Endpoints](#cluster-endpoints)
  - [Node Information](#node-information)
  - [Slot Distribution](#slot-distribution)
- [Cluster Troubleshooting](#cluster-troubleshooting)
  - [Cluster Not Forming](#cluster-not-forming)
  - [Missing Slots](#missing-slots)
  - [Node Failures](#node-failures)
  - [Connection Issues](#connection-issues)
- [Related Pages](#related-pages)

## Overview

The colima-services environment includes a 3-node Redis cluster for distributed caching and data storage. This provides high availability, automatic sharding, and horizontal scalability.

**Cluster Configuration:**
- 3 master nodes (no replicas in dev environment)
- All 16384 hash slots distributed across nodes
- Cluster bus port for node communication
- Both TLS and non-TLS ports available
- Shared password across all nodes (from Vault)

**Ports per node:**
- 6379: Redis non-TLS port
- 6380: Redis TLS port
- 16379: Cluster bus port (internal communication)

## Redis Cluster Architecture

### Three-Node Cluster

**Node Configuration:**

```yaml
# docker-compose.yml
services:
  redis-1:
    image: redis:7-alpine
    networks:
      dev-services:
        ipv4_address: 172.20.0.13
    ports:
      - "6379:6379"
      - "6380:6380"
      - "16379:16379"
    command: redis-server /etc/redis/redis.conf --cluster-enabled yes

  redis-2:
    networks:
      dev-services:
        ipv4_address: 172.20.0.16
    # Similar configuration

  redis-3:
    networks:
      dev-services:
        ipv4_address: 172.20.0.17
    # Similar configuration
```

**Cluster topology:**

```
Node 1 (172.20.0.13:6379)
├── Slots: 0-5460 (5461 slots)
└── Role: Master

Node 2 (172.20.0.16:6379)
├── Slots: 5461-10922 (5462 slots)
└── Role: Master

Node 3 (172.20.0.17:6379)
├── Slots: 10923-16383 (5461 slots)
└── Role: Master

Total: 16384 slots
```

### No Replicas in Development

**Development configuration:**

```bash
# Cluster created with --cluster-replicas 0
redis-cli --cluster create \
  172.20.0.13:6379 \
  172.20.0.16:6379 \
  172.20.0.17:6379 \
  --cluster-replicas 0 \
  --cluster-yes
```

**Why no replicas in development:**
- Simpler configuration
- Fewer resources required
- Faster startup
- Easier to understand
- Sufficient for development/testing

**Production would use replicas:**

```bash
# Production: 3 masters + 3 replicas = 6 nodes
redis-cli --cluster create \
  node1:6379 node2:6379 node3:6379 \
  node4:6379 node5:6379 node6:6379 \
  --cluster-replicas 1  # 1 replica per master
```

### Hash Slot Distribution

**16384 hash slots distributed across 3 nodes:**

```bash
# Check slot distribution
redis-cli -c -h 172.20.0.13 CLUSTER SLOTS

# Output:
# 1) 1) (integer) 0          # Start slot
#    2) (integer) 5460       # End slot
#    3) 1) "172.20.0.13"     # Node IP
#       2) (integer) 6379    # Port
#
# 2) 1) (integer) 5461
#    2) (integer) 10922
#    3) 1) "172.20.0.16"
#       2) (integer) 6379
#
# 3) 1) (integer) 10923
#    2) (integer) 16383
#    3) 1) "172.20.0.17"
#       2) (integer) 6379
```

**Slot calculation:**

```python
# Key to slot mapping
import crc16

def key_to_slot(key):
    """Calculate hash slot for a key."""
    # Extract hash tag if present
    start = key.find('{')
    if start != -1:
        end = key.find('}', start + 1)
        if end != -1 and end != start + 1:
            key = key[start + 1:end]

    # Calculate CRC16 and mod 16384
    return crc16.crc16xmodem(key.encode()) % 16384

# Examples
print(key_to_slot("user:1000"))  # Slot: 9324 (node 2)
print(key_to_slot("user:2000"))  # Slot: 15134 (node 3)
print(key_to_slot("user:3000"))  # Slot: 3774 (node 1)
```

## Cluster Initialization

### Automated Initialization

**Cluster is automatically initialized on startup:**

```yaml
# docker-compose.yml
services:
  redis-cluster-init:
    image: redis:7-alpine
    depends_on:
      - redis-1
      - redis-2
      - redis-3
    command: >
      sh -c "
        sleep 5 &&
        redis-cli --cluster create
          172.20.0.13:6379
          172.20.0.16:6379
          172.20.0.17:6379
          --cluster-replicas 0
          --cluster-yes
      "
```

**Initialization script:** `configs/redis/scripts/redis-cluster-init.sh`

```bash
#!/bin/bash
set -e

echo "Waiting for Redis nodes to start..."
sleep 10

# Wait for each node to be ready
for ip in 172.20.0.13 172.20.0.16 172.20.0.17; do
  until redis-cli -h $ip ping > /dev/null 2>&1; do
    echo "Waiting for Redis node $ip..."
    sleep 2
  done
  echo "Redis node $ip is ready"
done

echo "Creating Redis cluster..."
redis-cli --cluster create \
  172.20.0.13:6379 \
  172.20.0.16:6379 \
  172.20.0.17:6379 \
  --cluster-replicas 0 \
  --cluster-yes

echo "Redis cluster initialized successfully!"
```

### Manual Initialization

**If automatic initialization fails:**

```bash
# Connect to any Redis node container
docker exec -it dev-redis-1 sh

# Create cluster
redis-cli --cluster create \
  172.20.0.13:6379 \
  172.20.0.16:6379 \
  172.20.0.17:6379 \
  --cluster-replicas 0 \
  --cluster-yes

# Output:
# >>> Performing hash slots allocation on 3 nodes...
# Master[0] -> Slots 0 - 5460
# Master[1] -> Slots 5461 - 10922
# Master[2] -> Slots 10923 - 16383
# >>> Nodes configuration updated
# >>> Assign a different config epoch to each node
# >>> Sending CLUSTER MEET messages to join the cluster
# [OK] All 16384 slots covered
```

### Verification

**Verify cluster is working:**

```bash
# Check cluster info
docker exec dev-redis-1 redis-cli CLUSTER INFO

# Expected output:
# cluster_state:ok
# cluster_slots_assigned:16384
# cluster_slots_ok:16384
# cluster_slots_pfail:0
# cluster_slots_fail:0
# cluster_known_nodes:3
# cluster_size:3

# Check cluster nodes
docker exec dev-redis-1 redis-cli CLUSTER NODES

# Test data distribution
docker exec dev-redis-1 redis-cli -c SET user:1000 "data"
docker exec dev-redis-1 redis-cli -c GET user:1000
```

## Cluster Operations

### Cluster Info

**Get cluster information:**

```bash
# Cluster state
docker exec dev-redis-1 redis-cli CLUSTER INFO

# Output:
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:3
cluster_size:3
cluster_current_epoch:3
cluster_my_epoch:1

# Detailed cluster info
docker exec dev-redis-1 redis-cli --cluster info 172.20.0.13:6379

# Node statistics
docker exec dev-redis-1 redis-cli INFO replication
docker exec dev-redis-1 redis-cli INFO stats
```

### Node Status

**Check node status:**

```bash
# List all nodes
docker exec dev-redis-1 redis-cli CLUSTER NODES

# Output format:
# <node-id> <ip:port> <flags> <master-id> <ping-sent> <pong-recv> <config-epoch> <link-state> <slot-range>

# Example output:
# a1b2c3d4... 172.20.0.13:6379@16379 myself,master - 0 0 1 connected 0-5460
# e5f6g7h8... 172.20.0.16:6379@16379 master - 0 1234567890 2 connected 5461-10922
# i9j0k1l2... 172.20.0.17:6379@16379 master - 0 1234567891 3 connected 10923-16383

# Check if node is master
docker exec dev-redis-1 redis-cli ROLE
# Output: master
```

### Slot Assignment

**View slot assignment:**

```bash
# Get slots for all nodes
docker exec dev-redis-1 redis-cli CLUSTER SLOTS

# Get slots for specific node
docker exec dev-redis-1 redis-cli CLUSTER NODES | grep myself

# Count slots per node
docker exec dev-redis-1 redis-cli CLUSTER NODES | awk '{print $9}' | while read range; do
  if [ ! -z "$range" ]; then
    start=$(echo $range | cut -d- -f1)
    end=$(echo $range | cut -d- -f2)
    slots=$((end - start + 1))
    echo "$slots slots"
  fi
done
```

### Resharding

**Rebalance slots across nodes:**

```bash
# Reshard slots from one node to another
redis-cli --cluster reshard 172.20.0.13:6379 \
  --cluster-from <source-node-id> \
  --cluster-to <target-node-id> \
  --cluster-slots 100 \
  --cluster-yes

# Automatic rebalancing
redis-cli --cluster rebalance 172.20.0.13:6379 \
  --cluster-use-empty-masters \
  --cluster-yes
```

## Data Sharding and Redirection

### Hash Slot Algorithm

**How keys are distributed:**

```bash
# Key without hash tag
SET user:1000 "data"
# Slot: CRC16("user:1000") % 16384 = 9324
# Stored on node with slots 5461-10922 (node 2)

# Key with hash tag
SET user:{1000}:name "John"
SET user:{1000}:email "john@example.com"
# Both use CRC16("1000") % 16384
# Ensures related keys on same node

# Multi-key operations require same slot
MGET user:{1000}:name user:{1000}:email  # Works
MGET user:1000 user:2000                  # May fail (different slots)
```

### MOVED Redirects

**Cluster redirects to correct node:**

```bash
# Connect to node 1 (slots 0-5460)
docker exec -it dev-redis-1 redis-cli

# Try to get key in node 2's slot range
127.0.0.1:6379> GET user:1000
(error) MOVED 9324 172.20.0.16:6379
# Redis tells client: "This key is on node 2"

# Use cluster mode to auto-follow redirects
docker exec dev-redis-1 redis-cli -c
127.0.0.1:6379> GET user:1000
-> Redirected to slot [9324] located at 172.20.0.16:6379
"data"
```

### ASK Redirects

**During resharding:**

```bash
# When slot is being migrated:
127.0.0.1:6379> GET migrating-key
(error) ASK 1234 172.20.0.17:6379

# Client should:
# 1. Send ASKING to target node
# 2. Retry command on target node
# redis-cli -c handles this automatically
```

## Using redis-cli with Cluster Mode

### Cluster Mode Flag

**Always use `-c` flag for cluster:**

```bash
# Without cluster mode (manual redirects)
docker exec dev-redis-1 redis-cli GET user:1000
# (error) MOVED 9324 172.20.0.16:6379

# With cluster mode (auto redirects)
docker exec dev-redis-1 redis-cli -c GET user:1000
# -> Redirected to slot [9324] located at 172.20.0.16:6379
# "data"
```

### Basic Operations

**CRUD operations:**

```bash
# Set key
docker exec dev-redis-1 redis-cli -c SET user:1000 "John Doe"
# OK

# Get key
docker exec dev-redis-1 redis-cli -c GET user:1000
# "John Doe"

# Delete key
docker exec dev-redis-1 redis-cli -c DEL user:1000
# (integer) 1

# Check key exists
docker exec dev-redis-1 redis-cli -c EXISTS user:1000
# (integer) 0

# Set with expiration
docker exec dev-redis-1 redis-cli -c SETEX user:1000 3600 "data"
# OK
```

### Multi-Key Operations

**Use hash tags for multi-key operations:**

```bash
# Without hash tags (may fail)
docker exec dev-redis-1 redis-cli -c MGET user:1000 user:2000
# (error) CROSSSLOT Keys in request don't hash to the same slot

# With hash tags (works)
docker exec dev-redis-1 redis-cli -c MSET \
  user:{1000}:name "John" \
  user:{1000}:email "john@example.com" \
  user:{1000}:age "30"
# OK

docker exec dev-redis-1 redis-cli -c MGET \
  user:{1000}:name \
  user:{1000}:email \
  user:{1000}:age
# 1) "John"
# 2) "john@example.com"
# 3) "30"
```

## FastAPI Cluster Inspection APIs

### Cluster Endpoints

**Available endpoints:**

```bash
# Cluster info
curl http://localhost:8000/redis-cluster/info

# Response:
{
  "cluster_state": "ok",
  "cluster_slots_assigned": 16384,
  "cluster_slots_ok": 16384,
  "cluster_known_nodes": 3,
  "cluster_size": 3
}

# Cluster nodes
curl http://localhost:8000/redis-cluster/nodes

# Response:
{
  "nodes": [
    {
      "id": "a1b2c3d4...",
      "ip": "172.20.0.13",
      "port": 6379,
      "role": "master",
      "slots": "0-5460",
      "slot_count": 5461
    },
    {
      "id": "e5f6g7h8...",
      "ip": "172.20.0.16",
      "port": 6379,
      "role": "master",
      "slots": "5461-10922",
      "slot_count": 5462
    },
    {
      "id": "i9j0k1l2...",
      "ip": "172.20.0.17",
      "port": 6379,
      "role": "master",
      "slots": "10923-16383",
      "slot_count": 5461
    }
  ]
}
```

### Node Information

**Get info for specific node:**

```bash
# Node stats
curl http://localhost:8000/redis-cluster/node/172.20.0.13:6379

# Response:
{
  "node": "172.20.0.13:6379",
  "role": "master",
  "connected_slaves": 0,
  "used_memory": "1.5M",
  "used_memory_human": "1.50M",
  "total_commands_processed": 12345,
  "keyspace": {
    "db0": {
      "keys": 150,
      "expires": 10
    }
  }
}
```

### Slot Distribution

**View slot distribution:**

```bash
# Slot ranges per node
curl http://localhost:8000/redis-cluster/slots

# Response:
{
  "total_slots": 16384,
  "assigned_slots": 16384,
  "distribution": [
    {
      "node": "172.20.0.13:6379",
      "start_slot": 0,
      "end_slot": 5460,
      "slot_count": 5461
    },
    {
      "node": "172.20.0.16:6379",
      "start_slot": 5461,
      "end_slot": 10922,
      "slot_count": 5462
    },
    {
      "node": "172.20.0.17:6379",
      "start_slot": 10923,
      "end_slot": 16383,
      "slot_count": 5461
    }
  ]
}

# Find which node owns a key
curl http://localhost:8000/redis-cluster/key-slot?key=user:1000

# Response:
{
  "key": "user:1000",
  "slot": 9324,
  "node": "172.20.0.16:6379"
}
```

## Cluster Troubleshooting

### Cluster Not Forming

**Symptoms:**
- `cluster_state:fail`
- Nodes can't see each other
- Cluster commands fail

**Diagnosis:**

```bash
# Check cluster state
docker exec dev-redis-1 redis-cli CLUSTER INFO
# cluster_state:fail

# Check nodes
docker exec dev-redis-1 redis-cli CLUSTER NODES
# Shows only 1 node

# Check logs
docker logs dev-redis-1 | grep -i cluster
```

**Solutions:**

```bash
# Reset cluster configuration
docker exec dev-redis-1 redis-cli FLUSHALL
docker exec dev-redis-1 redis-cli CLUSTER RESET SOFT

# Recreate cluster
docker exec dev-redis-1 sh -c '
  redis-cli --cluster create \
    172.20.0.13:6379 \
    172.20.0.16:6379 \
    172.20.0.17:6379 \
    --cluster-replicas 0 \
    --cluster-yes
'

# Or restart all nodes
docker compose restart redis-1 redis-2 redis-3
sleep 10
docker exec dev-redis-cluster-init sh /init.sh
```

### Missing Slots

**Symptoms:**
- `cluster_slots_assigned` < 16384
- Some keys not accessible

**Diagnosis:**

```bash
# Check slot coverage
docker exec dev-redis-1 redis-cli CLUSTER INFO | grep slots

# cluster_slots_assigned:10000  # Should be 16384
# cluster_slots_ok:10000
# cluster_slots_fail:6384

# Check which slots are missing
docker exec dev-redis-1 redis-cli CLUSTER SLOTS
```

**Solutions:**

```bash
# Fix missing slots
redis-cli --cluster fix 172.20.0.13:6379

# Manually assign slots (if needed)
docker exec dev-redis-1 redis-cli CLUSTER ADDSLOTS {0..5460}
docker exec dev-redis-2 redis-cli CLUSTER ADDSLOTS {5461..10922}
docker exec dev-redis-3 redis-cli CLUSTER ADDSLOTS {10923..16383}
```

### Node Failures

**Symptoms:**
- Node marked as failed
- `cluster_state:fail`
- Cannot access some keys

**Diagnosis:**

```bash
# Check node status
docker exec dev-redis-1 redis-cli CLUSTER NODES | grep fail

# Check if node is running
docker ps | grep redis

# Check connectivity
docker exec dev-redis-1 ping 172.20.0.16
```

**Solutions:**

```bash
# Restart failed node
docker compose restart redis-2

# If node won't rejoin, remove and re-add
docker exec dev-redis-1 redis-cli CLUSTER FORGET <node-id>
docker exec dev-redis-2 redis-cli CLUSTER MEET 172.20.0.13 6379

# Or recreate cluster
./manage-colima.sh restart
```

### Connection Issues

**Symptoms:**
- Can't connect to cluster
- MOVED/ASK errors not handled
- Timeout errors

**Diagnosis:**

```bash
# Test connectivity to each node
docker exec dev-redis-1 redis-cli -h 172.20.0.13 PING
docker exec dev-redis-1 redis-cli -h 172.20.0.16 PING
docker exec dev-redis-1 redis-cli -h 172.20.0.17 PING

# Check cluster mode in client
# Must use -c flag or cluster-aware client
```

**Solutions:**

```bash
# Always use cluster mode
docker exec dev-redis-1 redis-cli -c <command>

# In application code, use cluster-aware client
# Python example:
from redis.cluster import RedisCluster

rc = RedisCluster(
    startup_nodes=[
        {"host": "172.20.0.13", "port": 6379},
        {"host": "172.20.0.16", "port": 6379},
        {"host": "172.20.0.17", "port": 6379},
    ],
    decode_responses=True
)

# Client handles redirects automatically
```

## Related Pages

- [Service-Configuration](Service-Configuration) - Redis configuration
- [Performance-Tuning](Performance-Tuning) - Redis optimization
- [Network-Issues](Network-Issues) - Connectivity troubleshooting
- [Health-Monitoring](Health-Monitoring) - Cluster monitoring
- [API-Endpoints](API-Endpoints) - Redis cluster APIs
