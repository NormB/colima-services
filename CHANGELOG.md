# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

<!-- Changes will be documented here as they are made -->

---

## [1.0.0] - 2025-10-23

### Added
- Complete Docker Compose infrastructure for local development on Apple Silicon
- PostgreSQL 16 with connection pooling via PgBouncer
- MySQL 8.0 for legacy application support
- Redis 3-node cluster for distributed caching and session storage
- RabbitMQ with management UI for message queuing
- MongoDB 7 for NoSQL data storage
- Forgejo self-hosted Git server with PostgreSQL backend
- HashiCorp Vault for centralized secrets management
- Vault PKI integration for automatic TLS certificate generation and rotation
- Vault auto-unseal functionality for seamless restarts
- Comprehensive wrapper scripts for Vault integration with all services
- FastAPI reference application demonstrating service integration
- Prometheus for metrics collection and monitoring
- Grafana with pre-configured dashboards for visualization
- Loki for centralized log aggregation
- Vector unified observability pipeline replacing multiple exporters
- Redis exporters for each cluster node (3 exporters)
- cAdvisor for container resource monitoring
- PostgreSQL metrics collection via Vector
- MongoDB metrics collection via Vector
- MySQL metrics exporter capabilities
- Comprehensive management script (manage-colima.sh) with 20+ commands
- Automated health checks for all services
- Custom network configuration with static IP assignments
- Volume persistence for all stateful services
- TLS/SSL support for database connections (optional)
- Development and production environment separation
- Comprehensive documentation including installation guide
- Example environment configuration (.env.example)
- Security best practices documentation
- Troubleshooting guides for common issues

### Security
- Vault-managed credentials for all services
- Network isolation via Docker bridge network
- Optional TLS encryption for all database services
- Secure credential storage and rotation capabilities
- Auto-generated secure passwords via Vault
- PKI infrastructure for certificate management

---

## Version History Guidelines

When releasing a new version, move changes from [Unreleased] to a new version section:

### Version Format
```markdown
## [X.Y.Z] - YYYY-MM-DD
```

### Change Categories
- **Added** - New features
- **Changed** - Changes in existing functionality
- **Deprecated** - Soon-to-be removed features
- **Removed** - Removed features
- **Fixed** - Bug fixes
- **Security** - Security improvements or vulnerability fixes

### Example Entry
```markdown
## [1.0.0] - 2025-01-15

### Added
- PostgreSQL 15 with SSL/TLS support
- HashiCorp Vault integration with auto-unseal
- Redis cluster with 6 nodes (3 primary, 3 replica)
- Comprehensive management script (manage-colima.sh)
- Automated Vault PKI bootstrapping
- Health check system for all services
- FastAPI reference application with SSL/TLS
- Prometheus and Grafana monitoring stack
- Loki for centralized logging

### Changed
- Migrated from Docker Desktop to Colima for better Apple Silicon performance
- Updated PostgreSQL configuration for optimal performance

### Fixed
- Fixed Vault initialization race condition
- Corrected Redis cluster configuration for proper failover

### Security
- Implemented TLS for all database connections
- Added Vault-managed certificate rotation
- Configured secure defaults for all services
```

### Semantic Versioning

- **Major version (X.0.0)** - Incompatible API changes or breaking changes
  - Example: Removing a service, changing default ports, breaking configuration changes

- **Minor version (0.X.0)** - Backwards-compatible new features
  - Example: Adding a new service, adding new management script commands

- **Patch version (0.0.X)** - Backwards-compatible bug fixes
  - Example: Fixing a bug, updating documentation, security patches

### When to Update

1. **Before creating a PR**: Add your changes to [Unreleased]
2. **When merging a PR**: Ensure CHANGELOG is updated
3. **When creating a release**: Move [Unreleased] changes to a new version section
4. **For security fixes**: Always document in Security section

### Best Practices

- Write changes from a user's perspective, not developer's
- Be concise but descriptive
- Include references to issues/PRs when relevant: `Fixes #123`
- Group similar changes together
- Order changes by impact (most significant first)
- Use imperative mood ("Add feature" not "Added feature")

### Migration Notes

For breaking changes, consider adding a migration guide:

```markdown
### Migration from 0.x to 1.0

**Breaking Changes:**
- PostgreSQL port changed from 5432 to 5433
- Redis cluster configuration format updated

**Migration Steps:**
1. Backup your data: `./manage-colima.sh backup`
2. Update your .env file with new configuration
3. Restart services: `./manage-colima.sh restart`
4. Verify: `./manage-colima.sh health`
```

---

## Archive

<!-- Older versions will be moved here to keep the main changelog focused on recent changes -->

<!--
Template for new releases:

## [X.Y.Z] - YYYY-MM-DD

### Added
-

### Changed
-

### Deprecated
-

### Removed
-

### Fixed
-

### Security
-

-->
