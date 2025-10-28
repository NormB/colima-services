# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Complete architecture documentation (docs/ARCHITECTURE.md) with Mermaid diagrams
- Comprehensive troubleshooting guide (docs/TROUBLESHOOTING.md) with diagnostic procedures
- Performance tuning guide (docs/PERFORMANCE_TUNING.md) with optimization strategies
- Go CodeQL security scanning to GitHub Actions workflow
- API parity tests between code-first and API-first implementations
- Go reference API implementation (port 8002)
- Node.js reference API implementation (port 8003) with Express, async/await patterns, and full infrastructure integration
- Node.js test suite using Jest and Supertest for comprehensive API testing
- Rust minimal reference API implementation (port 8004) with Actix-web demonstrating high-performance patterns
- Performance benchmark suite (tests/performance-benchmark.sh) for comparing all reference implementations
- TypeScript API-First scaffolding for future OpenAPI code generation implementation
- Focused documentation files extracted from massive README:
  - docs/INSTALLATION.md - Complete installation guide (1,153 lines)
  - docs/SERVICES.md - Service configurations (446 lines)
  - docs/VAULT.md - Vault PKI and secrets management (551 lines)
  - docs/REDIS.md - Redis cluster documentation (216 lines)
  - docs/MANAGEMENT.md - Management script commands (132 lines)
  - docs/OBSERVABILITY.md - Observability stack (725 lines)
  - docs/BEST_PRACTICES.md - Development best practices (148 lines)
  - docs/FAQ.md - Frequently asked questions (78 lines)
- .gitleaksignore file to exclude documentation example secrets from security scans
- Secure logging utilities (app/utils/logging.py) for redacting sensitive data and preventing log injection
- Comprehensive security remediation plan (SECURITY_REMEDIATION.md) documenting all 63 CodeQL alerts

### Changed
- Reorganized documentation into docs/ directory for better discoverability
- Updated docs/README.md with architecture and operational guides sections
- Converted all architecture diagrams to Mermaid format
- Drastically reduced README.md from 5,637 to 274 lines (95% reduction) by extracting content to focused documentation files
- Improved documentation structure with proper H1 headers in all extracted docs

### Fixed
- GitHub Actions security workflow now scans both Python and Go code
- Documented critical Vault bootstrap requirement in troubleshooting guide
- Go module version in reference-apps/golang/go.mod (1.24.0 → 1.23)
- golang-api health check now uses GET request instead of HEAD for proper Gin framework compatibility
- Gitleaks security scanning false positives on documentation example secrets (Vault keys and passwords)

### Security
- **CRITICAL**: Fixed 2 Server-Side Request Forgery (SSRF) vulnerabilities in Vault service
  - Added path validation and sanitization to prevent SSRF attacks
  - Implemented safe URL construction with urljoin
  - Prevents path traversal and malicious URL injection
- **HIGH**: Fixed 4 clear-text logging vulnerabilities
  - Redact passwords from Redis connection URLs before logging
  - Prevents exposure of sensitive credentials in application logs
- **HIGH**: Fixed 3 log injection vulnerabilities (Python + Go)
  - Added sanitization of user-controlled input before logging
  - Prevents attackers from injecting fake log entries
  - Escapes newlines, carriage returns, and control characters
- Updated github.com/jackc/pgx/v5 from 5.5.2 to 5.5.4 (fixes CVE-2024-27304 - SQL injection vulnerability)
- Fixed Gitleaks false positives on documentation examples
- **Total**: Fixed 9 of 63 CodeQL security alerts (all CRITICAL and HIGH severity issues)

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
