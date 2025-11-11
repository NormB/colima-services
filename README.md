# DevStack Core - Complete Development Environment

> **Comprehensive local development infrastructure for VoIP services on Apple Silicon (M Series Processors) using Colima**

A production-ready, Docker-based development environment running on Colima that provides Git hosting, databases, caching, message queuing, and secrets management optimized for Apple Silicon Macs.

## Table of Contents

- [Reference Applications](#reference-applications)
- [Overview](#overview)
- [Service Profiles](#service-profiles)
- [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Features](#features)
- [Getting Help](#getting-help)

## Reference Applications

This repository includes production-ready reference implementations demonstrating how to integrate with all infrastructure services (Vault, databases, caching, messaging). These implementations showcase language-agnostic patterns for secrets management, dynamic credentials, health checks, and service integration.

### Available Implementations

| Language | Implementation | Description | Ports | Documentation |
|----------|---------------|-------------|-------|---------------|
| **Python** | FastAPI (Code-First) | Comprehensive code-first API with full service integration | 8000 (HTTP), 8443 (HTTPS) | [README](./reference-apps/fastapi/README.md) |
| **Python** | FastAPI (API-First) | OpenAPI specification-driven implementation with shared test suite | 8001 (HTTP), 8444 (HTTPS) | [README](./reference-apps/fastapi-api-first/README.md) |
| **Go** | Gin Framework | Production-ready Go implementation with concurrent patterns | 8002 (HTTP), 8445 (HTTPS) | [README](./reference-apps/golang/README.md) |
| **Node.js** | Express Framework | Modern async/await patterns with Express | 8003 (HTTP), 8446 (HTTPS) | [README](./reference-apps/nodejs/README.md) |
| **Rust** | Actix-web (Partial) | High-performance async API with comprehensive testing | 8004 (HTTP), 8447 (HTTPS) | [README](./reference-apps/rust/README.md) |

### Key Features

All reference applications demonstrate:

- **Vault Integration**: Dynamic secret retrieval, KV secrets management, PKI certificate issuance
- **Database Connections**: PostgreSQL, MySQL, MongoDB with Vault-managed credentials
- **Caching**: Redis cluster operations with connection pooling
- **Messaging**: RabbitMQ queue management and message publishing
- **Observability**: Prometheus metrics, structured logging, health checks
- **Security**: TLS/SSL support, secrets management, secure credential handling
- **Testing**: Comprehensive test suites with executable tests for all implementations
- **API Synchronization**: Automated validation between code-first and API-first implementations

### Quick Start

Each implementation can be started via Docker Compose:

```bash
# Start all reference applications
docker compose up -d reference-api api-first golang-api nodejs-api rust-api

# Or start individual services
docker compose up -d golang-api
```

**API Synchronization and Validation:**

```bash
# Validate API synchronization (for contributors)
make validate       # Run all validation checks
make sync-check     # Check API drift
make test           # Run shared test suite
make help           # Show all available targets
```

See [Reference Apps Overview](./reference-apps/README.md) for architecture details and design patterns used across implementations.

## Overview

### What is Colima?

**Colima** (Containers on Linux on macOS) is a container runtime for macOS and Linux that provides a minimal, lightweight alternative to Docker Desktop. It runs containers in a Linux VM using:

- **Lima** (Linux virtual machines on macOS)
- **containerd** or **Docker** as the container runtime
- **QEMU** or **VZ** (Virtualization.framework) as the hypervisor

**Key Benefits:**
- Free and open-source (no licensing fees)
- Minimal resource overhead
- Native Apple Silicon (ARM64) support
- Full Docker CLI compatibility
- Faster than Docker Desktop on M-series Macs
- Supports multiple profiles/instances
- Uses macOS native Virtualization.framework (VZ) for better performance

### Why This Stack?

This repository provides a **complete, self-contained development environment** that:

1. **Runs Entirely on Your Mac** - No cloud dependencies
2. **Optimized for Apple Silicon** - Native ARM64 support via Colima's VZ backend
3. **Production-Like** - Services configured similarly to production environments
4. **Version Controlled** - Infrastructure as code using Docker Compose
5. **Isolated** - Separate network and volumes, doesn't conflict with other projects
6. **Persistent** - Data survives container restarts via Docker volumes
7. **Manageable** - Single script (`manage-devstack`) for all operations

**Use Cases:**
- VoIP application development (primary purpose)
- Microservices development
- Learning container orchestration
- Testing database migrations
- Git repository hosting (Forgejo)
- Secrets management (Vault)
- Message queue development (RabbitMQ)

### Architecture Philosophy

**Separation of Concerns:**
- DevStack Core environment: Git hosting (Forgejo) + development databases
- Separate libvirt VMs: Production VoIP services (OpenSIPS, Asterisk, RTPEngine)
- Benefit: Network latency minimization, clear environment boundaries, full kernel access for RTPEngine

**Design Principles:**
1. **Minimal Complexity** - Use standard Docker images, avoid custom builds
2. **Configuration Over Customization** - Leverage environment variables and config files
3. **Performance First** - Optimized health checks, resource limits
4. **Security Aware** - Password protection, network isolation (development setup)
5. **Observable** - Health checks, logging, easy status inspection

## Service Profiles

DevStack Core supports flexible service profiles to match your development needs. Choose the profile that fits your use case:

| Profile | Services | RAM | Use Case |
|---------|----------|-----|----------|
| **minimal** | 5 services | 2GB | Git hosting + essential development (single Redis) |
| **standard** | 10 services | 4GB | Full development stack + Redis cluster (recommended) |
| **full** | 18 services | 6GB | Complete suite + observability (Prometheus, Grafana, Loki) |
| **reference** | +5 services | +1GB | Educational API examples (combine with standard/full) |

### Profile Quick Start

```bash
# Start with standard profile (recommended for most developers)
./manage-devstack start --profile standard

# Or use minimal profile (lightweight, single Redis instance)
./manage-devstack start --profile minimal

# Or use full profile (includes Prometheus, Grafana, Loki)
./manage-devstack start --profile full

# Combine profiles (standard + reference apps)
./manage-devstack start --profile standard --profile reference

# Check health of all running services
./manage-devstack health

# Initialize Redis cluster (required for standard/full profiles, first time only)
./manage-devstack redis-cluster-init
```

**See [docs/SERVICE_PROFILES.md](./docs/SERVICE_PROFILES.md) for complete profile documentation.**

## Quick Start

### Quick Start Steps

```bash
# 1. Install prerequisites
brew install colima docker docker-compose

# Optional: Modern Rust-based CLI tools (not required)
# brew install ripgrep fd-find bat eza

# 2. Clone repository
git clone https://github.com/NormB/devstack-core.git ~/devstack-core
cd ~/devstack-core

# 3. Install Python dependencies (one-time setup)
uv venv
uv pip install -r scripts/requirements.txt

# 4. Configure environment
cp .env.example .env
nano .env  # Set strong passwords

# 5. Start with standard profile (recommended)
./manage-devstack start --profile standard

# 6. Initialize Vault (first time only)
./manage-devstack vault-init

# 7. Bootstrap Vault PKI and credentials (first time only)
./manage-devstack vault-bootstrap

# 8. Initialize Redis cluster (for standard/full profiles, first time only)
./manage-devstack redis-cluster-init

# 9. Check health
./manage-devstack health
```

**Alternative profiles:**
```bash
# Lightweight (single Redis, 5 services, 2GB RAM)
./manage-devstack start --profile minimal

# Complete with observability (18 services, 6GB RAM)
./manage-devstack start --profile full

# Combine profiles for reference apps
./manage-devstack start --profile standard --profile reference
```

**Note:** The wrapper script automatically uses the virtual environment. No need to activate it manually!

**Getting Help:**
```bash
# Main help - shows all 21 commands
./manage-devstack --help

# Help for specific command - shows all options and examples
./manage-devstack start --help
./manage-devstack logs --help
./manage-devstack vault-show-password --help
```

**Optional:** Add `~/devstack-core` to your PATH to use `manage-devstack` without `./`:
```bash
echo 'export PATH="$HOME/devstack-core:$PATH"' >> ~/.zshrc
source ~/.zshrc
# Then use: manage-devstack status (anywhere)
```

**See [docs/PYTHON_MANAGEMENT_SCRIPT.md](./docs/PYTHON_MANAGEMENT_SCRIPT.md) for complete Python script documentation.**

**Access Services:**
- **Forgejo (Git):** http://localhost:3000
- **Vault UI:** http://localhost:8200/ui
- **RabbitMQ Management:** http://localhost:15672
- **PostgreSQL:** `localhost:5432`
- **Redis Cluster:** `localhost:6379/6380/6381`
- **Reference APIs:** http://localhost:8000-8004
- **Prometheus:** http://localhost:9090
- **Grafana:** http://localhost:3001 (admin/admin)

For detailed installation instructions, see [docs/INSTALLATION.md](./docs/INSTALLATION.md).

## Documentation

### Core Documentation

- **[Installation Guide](./docs/INSTALLATION.md)** - Complete step-by-step installation with pre-flight checks, software setup, and verification
- **[Service Profiles](./docs/SERVICE_PROFILES.md)** - Flexible service profiles (minimal, standard, full, reference) for different development needs
- **[Python Management Script](./docs/PYTHON_MANAGEMENT_SCRIPT.md)** - Modern Python CLI with profile support, colored output, and comprehensive commands
- **[Services Overview](./docs/SERVICES.md)** - Detailed configuration for PostgreSQL, MySQL, MongoDB, Redis, RabbitMQ, Forgejo, and Vault
- **[Vault Integration](./docs/VAULT.md)** - Vault PKI setup, certificate management, auto-unseal configuration, and Vault commands
- **[Redis Cluster](./docs/REDIS.md)** - Redis cluster architecture, setup, operations, and troubleshooting
- **[Management Script](./docs/MANAGEMENT.md)** - Complete guide to manage-devstack commands and workflows
- **[Observability Stack](./docs/OBSERVABILITY.md)** - Prometheus, Grafana, Loki setup and troubleshooting
- **[Best Practices](./docs/BEST_PRACTICES.md)** - Development best practices and integration patterns
- **[FAQ](./docs/FAQ.md)** - Frequently asked questions and common issues

### Additional Documentation

- **[Architecture](./docs/ARCHITECTURE.md)** - System architecture with Mermaid diagrams
- **[Troubleshooting](./docs/TROUBLESHOOTING.md)** - Comprehensive troubleshooting guide with diagnostic procedures
- **[Performance Tuning](./docs/PERFORMANCE_TUNING.md)** - Performance optimization strategies and resource tuning
- **[Security Assessment](./docs/SECURITY_ASSESSMENT.md)** - Security hardening and assessment guide
- **[Test Results](./docs/TEST_RESULTS.md)** - Latest test execution results
- **[Vault Security](./docs/VAULT_SECURITY.md)** - Vault hardening and security best practices

### Reference Application Documentation

- **[Reference Apps Overview](./reference-apps/README.md)** - Architecture and patterns overview
- **[Python FastAPI (Code-First)](./reference-apps/fastapi/README.md)** - Complete implementation guide
- **[Python FastAPI (API-First)](./reference-apps/fastapi-api-first/README.md)** - OpenAPI-driven implementation
- **[Go Implementation](./reference-apps/golang/README.md)** - Go implementation guide
- **[Node.js Implementation](./reference-apps/nodejs/README.md)** - Node.js/Express implementation guide
- **[Rust Implementation](./reference-apps/rust/README.md)** - Rust/Actix-web implementation guide
- **[Shared Test Suite](./reference-apps/shared/test-suite/README.md)** - Reusable test framework

### Testing Documentation

- **[Tests Overview](./tests/README.md)** - Infrastructure testing guide
- **[Test Coverage](./tests/TEST_COVERAGE.md)** - Detailed test coverage metrics

### Project Documentation

- **[CHANGELOG.md](./.github/CHANGELOG.md)** - Version history and changes
- **[CONTRIBUTING.md](./.github/CONTRIBUTING.md)** - Contribution guidelines
- **[CODE_OF_CONDUCT.md](./.github/CODE_OF_CONDUCT.md)** - Community standards
- **[SECURITY.md](./.github/SECURITY.md)** - Security policy and reporting

## Features

### Infrastructure Services

| Service | Version | Purpose | Access |
|---------|---------|---------|--------|
| **PostgreSQL** | 18 | Primary relational database | localhost:5432 |
| **PgBouncer** | Latest | Connection pooling for PostgreSQL | localhost:6432 |
| **MySQL** | 8.0 | Legacy application support | localhost:3306 |
| **MongoDB** | 7 | NoSQL document database | localhost:27017 |
| **Redis Cluster** | Latest | 3-node cluster for caching | localhost:6379-6381 |
| **RabbitMQ** | Latest | Message queue + Management UI | localhost:5672, 15672 |
| **Forgejo** | Latest | Self-hosted Git server | localhost:3000 |
| **HashiCorp Vault** | Latest | Secrets management + PKI | localhost:8200 |

### Observability Stack

| Service | Purpose | Access |
|---------|---------|--------|
| **Prometheus** | Metrics collection | localhost:9090 |
| **Grafana** | Metrics visualization | localhost:3001 |
| **Loki** | Log aggregation | localhost:3100 |
| **Vector** | Unified observability pipeline | - |
| **cAdvisor** | Container resource monitoring | localhost:8080 |

### Key Capabilities

- **Vault PKI Integration** - Automatic TLS certificate generation and rotation
- **Vault Auto-Unseal** - Seamless Vault restarts without manual intervention
- **Dynamic Credentials** - Vault-managed database credentials with rotation
- **Redis Cluster** - High-availability caching with automatic failover
- **Comprehensive Monitoring** - Prometheus + Grafana with pre-configured dashboards
- **Centralized Logging** - Loki + Vector for log aggregation
- **Management Script** - 20+ commands for easy service management
- **Health Checks** - Automated health monitoring for all services

## Getting Help

### Quick Links

- **Documentation:** [docs/](./docs/)
- **Installation Issues:** [docs/INSTALLATION.md](./docs/INSTALLATION.md)
- **Service Configuration:** [docs/SERVICES.md](./docs/SERVICES.md)
- **Troubleshooting:** [docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md)
- **FAQ:** [docs/FAQ.md](./docs/FAQ.md)

### Common Commands

```bash
# Check status of all services
./manage-devstack status

# View logs for a specific service
./manage-devstack logs vault

# Restart a service
./manage-devstack restart postgres

# Health check all services
./manage-devstack health

# View all available commands
./manage-devstack --help
```

### Need More Help?

1. Check the [Troubleshooting Guide](./docs/TROUBLESHOOTING.md)
2. Review the [FAQ](./docs/FAQ.md)
3. Search existing [GitHub Issues](https://github.com/NormB/devstack-core/issues)
4. Open a new issue with details about your problem

## License

MIT License - see [LICENSE](./LICENSE) for details.

## Acknowledgements

This project is built on the shoulders of giants. We are grateful for the excellent open-source software and tools that make this project possible.

See the complete list of [acknowledged projects and their licenses](./docs/ACKNOWLEDGEMENTS.md).
