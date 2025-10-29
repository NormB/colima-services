# Architecture Overview

Comprehensive overview of the Colima Services system architecture, design principles, and component interactions.

## Table of Contents

- [High-Level Architecture](#high-level-architecture)
- [Component Architecture](#component-architecture)
- [Network Architecture](#network-architecture)
- [Security Architecture](#security-architecture)
- [Data Flow](#data-flow)
- [Startup Sequence](#startup-sequence)
- [Design Principles](#design-principles)

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│              macOS Host (M Series Processors)           │
│  ┌───────────────────────────────────────────────────┐  │
│  │           Colima VM (Linux on macOS)              │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │        Docker Compose Services              │  │  │
│  │  │                                             │  │  │
│  │  │  Core Services:                             │  │  │
│  │  │  • HashiCorp Vault (Secrets & PKI)          │  │  │
│  │  │  • PostgreSQL + PgBouncer                   │  │  │
│  │  │  • MySQL                                    │  │  │
│  │  │  • MongoDB                                  │  │  │
│  │  │  • Redis Cluster (3 nodes)                  │  │  │
│  │  │  • RabbitMQ                                 │  │  │
│  │  │  • Forgejo (Git)                            │  │  │
│  │  │                                             │  │  │
│  │  │  Reference APIs:                            │  │  │
│  │  │  • FastAPI (Code-First)                     │  │  │
│  │  │  • FastAPI (API-First)                      │  │  │
│  │  │  • Go (Gin)                                 │  │  │
│  │  │  • Node.js (Express)                        │  │  │
│  │  │  • Rust (Actix-web)                         │  │  │
│  │  │                                             │  │  │
│  │  │  Observability:                             │  │  │
│  │  │  • Prometheus                               │  │  │
│  │  │  • Grafana                                  │  │  │
│  │  │  • Loki                                     │  │  │
│  │  │  • Vector                                   │  │  │
│  │  │  • cAdvisor                                 │  │  │
│  │  │  • Redis Exporters (3)                      │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Component Architecture

### Infrastructure Services Layer

#### HashiCorp Vault (172.20.0.21)
- **Purpose:** Centralized secrets management and PKI
- **Features:**
  - KV secrets storage for all service credentials
  - Two-tier PKI (Root CA → Intermediate CA)
  - Auto-unseal on startup
  - TLS certificate issuance
- **Storage:** File backend (persistent)
- **Port:** 8200

#### PostgreSQL (172.20.0.10) + PgBouncer (172.20.0.11)
- **Purpose:** Primary relational database
- **Use Cases:** Forgejo, local development
- **Features:**
  - Vault-managed credentials
  - Connection pooling via PgBouncer
  - Optional TLS support
- **Ports:** 5432 (PostgreSQL), 6432 (PgBouncer)

#### MySQL (172.20.0.12)
- **Purpose:** Legacy application support
- **Features:**
  - Vault-managed credentials
  - UTF-8mb4 character set
  - Optional TLS support
- **Port:** 3306

#### MongoDB (172.20.0.15)
- **Purpose:** NoSQL document database
- **Features:**
  - Vault-managed credentials
  - Document-based storage
  - Optional TLS support
- **Port:** 27017

#### Redis Cluster (172.20.0.13, 172.20.0.16, 172.20.0.17)
- **Purpose:** Distributed caching and session storage
- **Architecture:** 3-node cluster, all masters (no replicas in dev)
- **Features:**
  - 16384 slots distributed across nodes
  - Shared Vault-managed password
  - Dual-port: 6379 (non-TLS), 6380 (TLS)
  - Cluster bus: port 16379
- **Ports:** 6379-6381 (client), 6390-6392 (TLS), 16379-16381 (cluster bus)

#### RabbitMQ (172.20.0.14)
- **Purpose:** Message queue and pub/sub
- **Features:**
  - Management UI
  - Vault-managed credentials
  - Dual-port: AMQP (5672) and AMQPS (5671)
- **Ports:** 5672 (AMQP), 5671 (AMQPS), 15672 (Management UI)

#### Forgejo (172.20.0.20)
- **Purpose:** Self-hosted Git server
- **Features:**
  - Uses PostgreSQL for storage
  - Git over HTTP/SSH
  - Issue tracking, pull requests
- **Ports:** 3000 (HTTP), 2222 (SSH)

### Application Layer

#### Reference APIs
Six language implementations demonstrating integration patterns:

1. **FastAPI Code-First** (172.20.0.100) - Ports 8000/8443
2. **FastAPI API-First** (172.20.0.104) - Ports 8001/8444
3. **Go Gin** (172.20.0.105) - Ports 8002/8445
4. **Node.js Express** (172.20.0.106) - Ports 8003/8446
5. **Rust Actix-web** (172.20.0.107) - Ports 8004/8447
6. **TypeScript API-First** - Scaffolding only

All demonstrate:
- Vault secret retrieval
- Database connections
- Redis cluster operations
- RabbitMQ messaging
- Health checks
- TLS support

### Observability Layer

#### Prometheus (172.20.0.101)
- **Purpose:** Metrics collection and time-series database
- **Scrapes:**
  - Redis Exporters (3 instances)
  - Vector metrics
  - cAdvisor metrics
  - Application metrics
- **Port:** 9090

#### Grafana (172.20.0.102)
- **Purpose:** Visualization and dashboarding
- **Data Sources:**
  - Prometheus (metrics)
  - Loki (logs)
- **Port:** 3001

#### Loki (172.20.0.103)
- **Purpose:** Log aggregation
- **Receives from:** Vector
- **Port:** 3100 (API only, query via Grafana)

#### Vector (172.20.0.118)
- **Purpose:** Unified observability pipeline
- **Functions:**
  - Scrapes PostgreSQL, MySQL, MongoDB metrics
  - Collects Docker container logs
  - Ships metrics to Prometheus
  - Ships logs to Loki
- **Port:** 8686 (health)

#### cAdvisor (172.20.0.117)
- **Purpose:** Container resource monitoring
- **Provides:** CPU, memory, network, disk metrics per container
- **Port:** 8080

#### Redis Exporters (172.20.0.112-114)
- **Purpose:** Per-node Redis metrics for Prometheus
- **Architecture:** One exporter per Redis node
- **Port:** 9121 (metrics endpoint)

## Network Architecture

All services run in the `dev-services` bridge network (172.20.0.0/16) with static IP assignments.

### IP Address Map

```
Core Services:
├── Vault:          172.20.0.21
├── PostgreSQL:     172.20.0.10
├── PgBouncer:      172.20.0.11
├── MySQL:          172.20.0.12
├── MongoDB:        172.20.0.15
├── Redis 1:        172.20.0.13
├── Redis 2:        172.20.0.16
├── Redis 3:        172.20.0.17
└── RabbitMQ:       172.20.0.14

Application Services:
├── Forgejo:        172.20.0.20
├── Reference API:  172.20.0.100
├── API-First:      172.20.0.104
├── Golang API:     172.20.0.105
├── Node.js API:    172.20.0.106
└── Rust API:       172.20.0.107

Observability:
├── Prometheus:     172.20.0.101
├── Grafana:        172.20.0.102
├── Loki:           172.20.0.103
├── Redis Exp 1:    172.20.0.112
├── Redis Exp 2:    172.20.0.113
├── Redis Exp 3:    172.20.0.114
├── cAdvisor:       172.20.0.117
└── Vector:         172.20.0.118
```

### DNS Resolution
- **Internal:** Services use Docker DNS (container names)
  - Example: `postgres`, `vault`, `redis-1`
- **External:** Access via `localhost:<port>` from macOS host
  - Colima forwards ports from VM to host

## Security Architecture

### Vault PKI Hierarchy

```
Root CA (pki)
├── Validity: 10 years
├── Purpose: Root of trust
└── Issues to: Intermediate CA

    Intermediate CA (pki_int)
    ├── Validity: 5 years
    ├── Purpose: Operational CA
    └── Issues to: Service Certificates

        Service Certificates
        ├── Validity: 1 year
        ├── Purpose: TLS for services
        └── Roles: postgres, mysql, redis, rabbitmq, etc.
```

### Certificate Storage

```
~/.config/vault/
├── keys.json           # Vault unseal keys (BACKUP!)
├── root-token          # Vault root token (BACKUP!)
├── ca/
│   ├── ca.pem         # Root CA certificate
│   └── ca-chain.pem   # Full certificate chain
└── certs/
    ├── postgres/
    │   ├── cert.pem
    │   ├── key.pem
    │   └── ca.pem
    ├── mysql/
    ├── redis-1/
    └── ... (per-service)
```

### Credential Flow

```
1. Service starts
2. Wrapper script runs (/init/init.sh)
3. Script checks Vault accessibility
4. Script fetches credentials via Vault API
5. Script exports environment variables
6. Original service entrypoint executes
```

## Data Flow

### Application Request Flow

```
User Request
    ↓
Reference API (e.g., FastAPI)
    ↓
┌───┴────┬────────┬─────────┐
│        │        │         │
Vault   DB     Redis    RabbitMQ
(creds) (data) (cache)  (async)
```

### Observability Data Flow

```
Services → Vector → Prometheus (metrics)
                 └→ Loki (logs)
                     ↓
                  Grafana (visualization)
```

### Metrics Collection

```
PostgreSQL → Vector → Prometheus
MySQL      → Vector → Prometheus
MongoDB    → Vector → Prometheus
Redis      → Redis Exporters → Prometheus
Containers → cAdvisor → Prometheus
Vector     → Vector metrics → Prometheus
```

## Startup Sequence

### 1. Colima VM Initialization
```
manage-colima.sh start
    ↓
colima start (4 CPU, 8GB RAM, 60GB disk)
    ↓
Docker Engine ready
```

### 2. Service Startup Order

```
1. Vault starts first (no dependencies)
   ↓
2. Vault health check passes (unsealed + ready)
   ↓
3. All other services start in parallel
   ├── Databases (PostgreSQL, MySQL, MongoDB)
   ├── Cache (Redis cluster)
   ├── Messaging (RabbitMQ)
   ├── Applications (Forgejo, Reference APIs)
   └── Observability (Prometheus, Grafana, etc.)
   ↓
4. Each service wrapper script fetches Vault credentials
   ↓
5. Services become healthy
```

### 3. Vault Bootstrap (First Time Only)

```
manage-colima.sh vault-bootstrap
    ↓
1. Create Root CA
2. Create Intermediate CA
3. Generate service certificates
4. Store database passwords in Vault
5. Export CA certificates to ~/.config/vault/
```

## Design Principles

### 1. Security First
- **No hardcoded credentials** - All in Vault
- **TLS optional** - Dual-mode for gradual adoption
- **Secrets rotation** - Vault supports dynamic credentials
- **Network isolation** - Services in dedicated network

### 2. Infrastructure as Code
- **Docker Compose** - All services defined in YAML
- **Environment variables** - Configuration via .env
- **Version controlled** - Infrastructure in Git
- **Reproducible** - Same setup across machines

### 3. Developer Experience
- **One command start** - `./manage-colima.sh start`
- **Auto-unseal** - No manual Vault unlocking
- **Health checks** - Automatic dependency management
- **Observability** - Built-in metrics and logs

### 4. Educational Focus
- **Reference implementations** - 6 language examples
- **Comprehensive tests** - 370+ tests
- **Extensive documentation** - 20+ doc files
- **Real-world patterns** - Production-like setup

### 5. Performance Optimized
- **Apple Silicon native** - ARM64 images
- **Connection pooling** - PgBouncer for PostgreSQL
- **Caching layer** - Redis cluster
- **Resource limits** - Prevents resource exhaustion

## Architectural Decisions

### Why Colima?
- **Free and open-source** (vs Docker Desktop licensing)
- **Native Apple Silicon support** (better performance)
- **Lightweight** (minimal overhead)
- **Compatible** (works with Docker CLI)

### Why Vault?
- **Industry standard** for secrets management
- **Built-in PKI** (certificate generation)
- **Dynamic secrets** (credential rotation)
- **Audit logging** (track secret access)

### Why Redis Cluster?
- **High availability** (no single point of failure)
- **Horizontal scaling** (distribute load)
- **Production-like** (learn clustering patterns)
- **Automatic failover** (built-in)

### Why Multiple Reference Apps?
- **Language diversity** (Python, Go, Node.js, Rust, TypeScript)
- **Pattern comparison** (see same concepts across languages)
- **Educational** (learn multiple ecosystems)
- **Parity testing** (validate API consistency)

## Next Steps

- **[Service Configuration](Service-Configuration)** - Configure individual services
- **[Vault Integration](Vault-Integration)** - Deep dive into Vault usage
- **[Network Architecture](Network-Architecture)** - Detailed network setup
- **[Security Hardening](Security-Hardening)** - Production security
