# DevStack Core

> **Complete Docker-based development infrastructure for Apple Silicon Macs, optimized with Colima**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Docker Compose](https://img.shields.io/badge/docker--compose-v2.0+-blue.svg)](https://docs.docker.com/compose/)
[![Colima](https://img.shields.io/badge/colima-latest-brightgreen.svg)](https://github.com/abiosoft/colima)
[![Platform](https://img.shields.io/badge/platform-Apple%20Silicon-lightgrey.svg)](https://www.apple.com/mac/)

A comprehensive, self-contained development environment providing Git hosting (Forgejo), databases (PostgreSQL, MySQL, MongoDB), caching (Redis Cluster), message queuing (RabbitMQ), secrets management (Vault), and observability (Prometheus, Grafana, Loki) - all running locally on your Mac.

---

## ✨ Key Features

- **🚀 [Complete Infrastructure](#️-architecture)** - Everything you need: Git, databases, caching, messaging, secrets, observability
- **🎯 [Service Profiles](Service-Configuration)** - Choose your stack: minimal (2GB), standard (4GB), or full (6GB) with observability
- **🍎 [Apple Silicon Optimized](#-prerequisites)** - Native ARM64 support via Colima's Virtualization.framework
- **🔒 [Vault-First Security](Vault-Integration)** - All credentials managed by HashiCorp Vault with dynamic generation
- **📦 Zero Cloud Dependencies** - Runs entirely on your Mac, perfect for offline development
- **🛠️ [Easy Management](CLI-Reference)** - Single CLI script with 21 commands for all operations
- **📚 [Reference Apps](Development-Workflow)** - Production-quality examples in Python, Go, Node.js, TypeScript, and Rust
- **🔍 [Full Observability](Health-Monitoring)** - Built-in Prometheus, Grafana, and Loki for monitoring and logging

## 🚀 Quick Start

Get up and running in 10 minutes (5 minutes if prerequisites already installed):

```bash
# 1. Install prerequisites
brew install colima docker docker-compose uv

# 2. Clone and setup
git clone https://github.com/NormB/devstack-core.git ~/devstack-core
cd ~/devstack-core

# 3. Install Python dependencies
uv venv && uv pip install -r scripts/requirements.txt

# 4. Configure environment
cp .env.example .env

# 5. Start with standard profile (recommended)
./manage-devstack start --profile standard

# 6. Initialize Vault (first time only)
./manage-devstack vault-init
./manage-devstack vault-bootstrap

# 7. Initialize Redis cluster (first time only, for standard/full profiles)
./manage-devstack redis-cluster-init

# 8. Verify everything is running
./manage-devstack health
```

**Access your services:**
- **Forgejo (Git):** http://localhost:3000
- **Vault UI:** http://localhost:8200/ui
- **RabbitMQ Management:** http://localhost:15672
- **Grafana:** http://localhost:3001 (admin/admin)
- **Prometheus:** http://localhost:9090

## 📋 Prerequisites

**Required:**
- macOS with Apple Silicon (M1/M2/M3/M4)
- **Note:** Intel Macs are not supported due to ARM64 architecture requirements
- Homebrew package manager
- 8GB+ RAM (16GB recommended)
- 50GB+ free disk space

**Software (auto-installed via Homebrew):**
- Colima (container runtime)
- Docker CLI
- Docker Compose
- uv (Python package installer)

**For development:**
- Python 3.8+ (for management script)
- Git (for cloning repository)

## 📖 Service Profiles

Choose the profile that fits your needs:

| Profile | Services | RAM | Use Case |
|---------|----------|-----|----------|
| **minimal** | 5 services | 2GB | Git hosting + essential development (single Redis) |
| **standard** | 10 services | 4GB | **Full development stack + Redis cluster (RECOMMENDED)** |
| **full** | 18 services | 6GB | Complete suite + observability (Prometheus, Grafana, Loki) |
| **reference** | +5 services | +1GB | Educational API examples (combine with standard/full) |

### Profile Commands

```bash
# Start with different profiles
./manage-devstack start --profile minimal   # Lightweight
./manage-devstack start --profile standard  # Recommended
./manage-devstack start --profile full      # Everything

# Combine profiles for reference apps
./manage-devstack start --profile standard --profile reference

# Check what's running
./manage-devstack status
./manage-devstack health
```

**See [Service Profiles Guide](Service-Configuration) for detailed information.**

## 🏗️ Architecture

### Infrastructure Services

| Service | Purpose | Access |
|---------|---------|--------|
| **HashiCorp Vault** | Secrets management + PKI | localhost:8200 |
| **PostgreSQL 18** | Primary relational database | localhost:5432 |
| **PgBouncer** | PostgreSQL connection pooling | localhost:6432 |
| **MySQL 8.0** | Legacy application support | localhost:3306 |
| **MongoDB 7** | NoSQL document database | localhost:27017 |
| **Redis Cluster** | 3-node distributed cache | localhost:6379-6381 (non-TLS), 6390-6392 (TLS) |
| **RabbitMQ** | Message queue + UI | localhost:5672, 15672 |
| **Forgejo** | Self-hosted Git server | localhost:3000 |

### Observability Stack (Full Profile)

| Service | Purpose | Access |
|---------|---------|--------|
| **Prometheus** | Metrics collection | localhost:9090 |
| **Grafana** | Metrics visualization | localhost:3001 |
| **Loki** | Log aggregation | localhost:3100 |
| **Vector** | Unified observability pipeline | - |
| **cAdvisor** | Container monitoring | localhost:8080 |

### Reference Applications

Production-quality API implementations in multiple languages:

| Language | Framework | Ports | Status |
|----------|-----------|-------|--------|
| **Python** | FastAPI (Code-First) | 8000, 8443 | ✅ Complete |
| **Python** | FastAPI (API-First) | 8001, 8444 | ✅ Complete |
| **Go** | Gin | 8002, 8445 | ✅ Complete |
| **Node.js** | Express | 8003, 8446 | ✅ Complete |
| **Rust** | Actix-web | 8004, 8447 | ⚠️ Partial (~40%) |

All reference apps demonstrate:
- Vault integration for secrets
- Database connections (PostgreSQL, MySQL, MongoDB)
- Redis cluster operations
- RabbitMQ messaging
- Health checks and metrics
- TLS/SSL support

**See [Reference Apps Overview](Development-Workflow) for details.**

## 💻 Usage

### Management Commands

The `manage-devstack` script provides all essential operations:

```bash
# Service management
./manage-devstack start [--profile PROFILE]  # Start services
./manage-devstack stop                        # Stop services
./manage-devstack restart                     # Restart services
./manage-devstack status                      # Show status
./manage-devstack health                      # Health checks

# Logs and debugging
./manage-devstack logs [SERVICE]              # View logs
./manage-devstack shell SERVICE               # Open shell in container

# Vault operations
./manage-devstack vault-init                  # Initialize Vault
./manage-devstack vault-bootstrap             # Setup PKI + credentials
./manage-devstack vault-status                # Check Vault status
./manage-devstack vault-show-password SERVICE # Get service password

# Redis cluster
./manage-devstack redis-cluster-init          # Initialize cluster

# Profiles
./manage-devstack profiles                    # List available profiles

# Help
./manage-devstack --help                      # Show all commands
./manage-devstack COMMAND --help              # Command-specific help
```

### Example Workflows

**Daily Development:**
```bash
# Morning: Start development environment
./manage-devstack start --profile standard

# Check everything is healthy
./manage-devstack health

# View logs if needed
./manage-devstack logs postgres

# Evening: Stop everything (or leave running)
./manage-devstack stop
```

**Database Operations:**
```bash
# Get database password
./manage-devstack vault-show-password postgres

# Connect to PostgreSQL
psql -h localhost -p 5432 -U devuser -d devdb

# Connect to MySQL
mysql -h 127.0.0.1 -P 3306 -u devuser -p

# Connect to MongoDB
mongosh "mongodb://localhost:27017" --username devuser
```

**Troubleshooting:**
```bash
# Check service health
./manage-devstack health

# View service logs
./manage-devstack logs vault
./manage-devstack logs redis-1

# Restart specific service
docker compose restart postgres

# Open shell for debugging
./manage-devstack shell postgres
```

## 📚 Documentation

### Getting Started
- **[Installation Guide](Installation)** - Comprehensive setup with troubleshooting
- **[Quick Start Tutorial](Quick-Start-Guide)** - Step-by-step usage guide
- **[Service Profiles](Service-Configuration)** - Profile selection and configuration

### Core Documentation
- **[Architecture Overview](Architecture-Overview)** - System design with diagrams
- **[Services Guide](Service-Overview)** - Detailed service configurations
- **[Management Script](Management-Commands)** - Complete CLI reference
- **[Python CLI Guide](CLI-Reference)** - Modern Python CLI documentation

### Infrastructure
- **[Vault Integration](Vault-Integration)** - PKI setup and secrets management
- **[Redis Cluster](Redis-Cluster)** - Cluster architecture and operations
- **[Observability Stack](Health-Monitoring)** - Prometheus, Grafana, Loki setup

### Development
- **[Reference Apps Overview](Development-Workflow)** - Multi-language examples
- **[Best Practices](Best-Practices)** - Development patterns
- **[Testing Guide](./tests/README.md)** - Testing infrastructure
- **[Test Coverage](./tests/TEST_COVERAGE.md)** - Coverage metrics

### Operations
- **[Troubleshooting](Common-Issues)** - Common issues and solutions
- **[Performance Tuning](Debugging-Techniques)** - Optimization strategies
- **[Disaster Recovery](Disaster-Recovery)** - Backup and restore procedures
- **[Security Assessment](Certificate-Management)** - Security hardening

### Project
- **[FAQ](FAQ)** - Frequently asked questions
- **[Changelog](./Changelog)** - Version history
- **[Contributing](./Contributing-Guide)** - Contribution guidelines
- **[Security Policy](./Secrets-Rotation)** - Security reporting

## 🤝 Contributing

We welcome contributions! Here's how to get started:

1. **Fork the repository** on GitHub
2. **Clone your fork:** `git clone https://github.com/YOUR_USERNAME/devstack-core.git`
3. **Create a feature branch:** `git checkout -b feature/amazing-feature`
4. **Make your changes** and test thoroughly
5. **Commit your changes:** `git commit -m 'feat: add amazing feature'`
6. **Push to your fork:** `git push origin feature/amazing-feature`
7. **Open a Pull Request** with a clear description

### Contribution Guidelines

- Follow existing code style and conventions
- Add tests for new features
- Update documentation for any changes
- Use conventional commit messages
- Ensure CI/CD checks pass

**See [CONTRIBUTING.md](./Contributing-Guide) for detailed guidelines.**

## 🐛 Issues and Support

**Found a bug?** [Open an issue](https://github.com/NormB/devstack-core/issues/new) with:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- System information (OS, Colima version, etc.)

**Need help?**
1. Check the [FAQ](FAQ)
2. Review [Troubleshooting Guide](Common-Issues)
3. Search [existing issues](https://github.com/NormB/devstack-core/issues)
4. Ask in [Discussions](https://github.com/NormB/devstack-core/discussions)

## 📜 License

This project is licensed under the **MIT License** - see the [LICENSE](./LICENSE) file for details.

You are free to:
- ✅ Use commercially
- ✅ Modify
- ✅ Distribute
- ✅ Private use

## 🙏 Acknowledgements

Built with excellent open-source software:

- [Colima](https://github.com/abiosoft/colima) - Container runtime for macOS
- [HashiCorp Vault](https://www.vaultproject.io/) - Secrets management
- [PostgreSQL](https://www.postgresql.org/) - Advanced relational database
- [Redis](https://redis.io/) - In-memory data store
- [RabbitMQ](https://www.rabbitmq.com/) - Message broker
- [Forgejo](https://forgejo.org/) - Self-hosted Git service
- [Prometheus](https://prometheus.io/) - Monitoring system
- [Grafana](https://grafana.com/) - Observability platform

**See complete list:** [ACKNOWLEDGEMENTS.md](./docs/ACKNOWLEDGEMENTS.md)

---

**Made with ❤️ for the developer community**

For questions or feedback, visit our [GitHub repository](https://github.com/NormB/devstack-core).
