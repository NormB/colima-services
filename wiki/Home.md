# Colima Services Wiki

Welcome to the **Colima Services** wiki! This is your comprehensive guide to setting up, configuring, and using the complete Docker Compose-based development infrastructure for Apple Silicon Macs.

## 🚀 Quick Navigation

### Getting Started
- **[Quick Start Guide](Quick-Start-Guide)** - Get up and running in 5 minutes
- **[Installation](Installation)** - Detailed step-by-step installation
- **[First Time Setup](First-Time-Setup)** - Initial configuration and Vault bootstrap

### Core Concepts
- **[Architecture Overview](Architecture-Overview)** - System architecture and design
- **[Service Overview](Service-Overview)** - All available services and their purposes
- **[Network Architecture](Network-Architecture)** - Container networking and IPs
- **[Vault Integration](Vault-Integration)** - Secrets management and PKI

### Development
- **[Reference Applications](Reference-Applications)** - Multi-language API examples
- **[Testing Guide](Testing-Guide)** - Running and writing tests
- **[API Patterns](API-Patterns)** - Code-first vs API-first development
- **[Best Practices](Best-Practices)** - Development patterns and conventions

### Operations
- **[Management Commands](Management-Commands)** - Using manage-colima.sh
- **[Service Configuration](Service-Configuration)** - Configuring individual services
- **[Health Monitoring](Health-Monitoring)** - Health checks and observability
- **[Backup and Restore](Backup-and-Restore)** - Data backup procedures

### Troubleshooting
- **[Common Issues](Common-Issues)** - Frequently encountered problems
- **[Vault Troubleshooting](Vault-Troubleshooting)** - Vault-specific issues
- **[Network Issues](Network-Issues)** - Connectivity problems
- **[Performance Tuning](Performance-Tuning)** - Optimization guide

### Advanced Topics
- **[TLS Configuration](TLS-Configuration)** - Certificate management
- **[Redis Cluster](Redis-Cluster)** - Redis cluster setup and operations
- **[Observability Stack](Observability-Stack)** - Prometheus, Grafana, Loki
- **[Security Hardening](Security-Hardening)** - Production security

### Reference
- **[Environment Variables](Environment-Variables)** - Complete .env reference
- **[Port Reference](Port-Reference)** - All service ports
- **[CLI Reference](CLI-Reference)** - Command-line tools
- **[API Endpoints](API-Endpoints)** - Reference API documentation
- **[Changelog](Changelog)** - Version history and release notes
- **[Dependency Upgrade Report](Dependency-Upgrade-Report)** - October 2025 dependency maintenance

### Contributing
- **[Contributing Guide](Contributing-Guide)** - How to contribute
- **[Development Workflow](Development-Workflow)** - Git workflow and PR process
- **[Code of Conduct](Code-of-Conduct)** - Community standards
- **[Acknowledgements](Acknowledgements)** - Credits and gratitude

## 📚 What is Colima Services?

Colima Services is a **complete, self-contained development environment** that provides:

- **Databases**: PostgreSQL, MySQL, MongoDB
- **Caching**: Redis 3-node cluster
- **Messaging**: RabbitMQ with management UI
- **Secrets Management**: HashiCorp Vault with PKI
- **Git Hosting**: Forgejo (self-hosted Git server)
- **Observability**: Prometheus, Grafana, Loki, Vector
- **Reference APIs**: 6 language implementations (Python, Go, Node.js, Rust, TypeScript)

All running on **Apple Silicon** (M Series Processors) using **Colima** for optimal performance.

## 🎯 Key Features

- ✅ **Vault-Managed Credentials** - All secrets stored in Vault
- ✅ **Auto-Unsealing** - Vault automatically unseals on startup
- ✅ **PKI Integration** - TLS certificates issued by Vault CA
- ✅ **Health Checks** - Automated monitoring for all services
- ✅ **Docker Compose** - Infrastructure as code
- ✅ **Educational** - Multiple reference implementations
- ✅ **Production-Like** - Services configured similarly to production

## 🔗 External Links

- **[GitHub Repository](https://github.com/NormB/colima-services)** - Source code and issues
- **[Colima Documentation](https://github.com/abiosoft/colima)** - Container runtime
- **[HashiCorp Vault](https://www.vaultproject.io/docs)** - Secrets management
- **[Docker Compose](https://docs.docker.com/compose/)** - Container orchestration

## 💡 Getting Help

- 📖 Start with the [Quick Start Guide](Quick-Start-Guide)
- 🐛 Check [Common Issues](Common-Issues) for troubleshooting
- 💬 [Open an issue](https://github.com/NormB/colima-services/issues) on GitHub
- 📧 Review the [FAQ](FAQ) for frequently asked questions

## 📝 Wiki Maintenance

This wiki is maintained alongside the codebase. If you find outdated information:
1. Check the repository's `/docs` directory for the latest documentation
2. Open an issue on GitHub
3. Submit a PR with corrections

Last updated: 2025-10-30
