# Documentation

## Table of Contents

- [Documentation Index](#documentation-index)
  - [Project Information](#project-information)
  - [Security Documentation](#security-documentation)
  - [Testing Documentation](#testing-documentation)
  - [Architecture & Design](#architecture-design)
  - [Operational Guides](#operational-guides)
  - [API Development Patterns](#api-development-patterns)
- [Quick Links](#quick-links)
  - [Project-Level Documentation](#project-level-documentation)
  - [Component Documentation](#component-documentation)
- [Documentation Standards](#documentation-standards)
  - [Writing Guidelines](#writing-guidelines)
  - [File Naming](#file-naming)
  - [Links and References](#links-and-references)
- [Contributing to Documentation](#contributing-to-documentation)
- [Documentation Coverage](#documentation-coverage)
- [Useful Resources](#useful-resources)
  - [External Documentation](#external-documentation)
  - [Infrastructure Components](#infrastructure-components)
  - [Observability Stack](#observability-stack)
- [Documentation Maintenance](#documentation-maintenance)
  - [When to Update Documentation](#when-to-update-documentation)
  - [Review Schedule](#review-schedule)
- [Need Help?](#need-help)

---

This directory contains comprehensive documentation for the DevStack Core project.

## Documentation Index

### Project Information

- **[ACKNOWLEDGEMENTS.md](./ACKNOWLEDGEMENTS.md)** - Software acknowledgements and licenses
  - Complete list of all open-source projects used
  - License information for all dependencies
  - Framework and library acknowledgements
  - Special thanks to the open-source community

### Security Documentation

- **[SECURITY_ASSESSMENT.md](./SECURITY_ASSESSMENT.md)** - Complete security audit and assessment
  - Risk assessment and findings
  - Security by domain (secrets management, network, authentication)
  - Remediation recommendations
  - Best practices implemented

- **[VAULT_SECURITY.md](./VAULT_SECURITY.md)** - HashiCorp Vault security best practices
  - Production deployment recommendations
  - AppRole authentication setup
  - Vault hardening guide
  - Backup and recovery procedures

### Testing Documentation

- **[TEST_RESULTS.md](./TEST_RESULTS.md)** - Latest test execution results
  - Complete test suite results (367 tests)
  - Infrastructure integration tests
  - Application unit tests
  - Performance benchmarks
  - Security validation results
  - Known issues and resolutions

### Architecture & Design

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Complete architecture deep-dive
  - System components and hierarchy
  - Network architecture with static IPs
  - Security architecture (PKI, TLS, Vault)
  - Data flow diagrams
  - Service dependencies
  - Deployment architecture
  - Scaling considerations
  - Architectural patterns

### Operational Guides

- **[SERVICE_PROFILES.md](./SERVICE_PROFILES.md)** - Service profile system (NEW in v1.3)
  - Flexible service orchestration (minimal, standard, full, reference)
  - Profile comparison and selection guide
  - Use cases and resource requirements
  - Profile combinations and customization
  - Environment variable overrides per profile

- **[PYTHON_MANAGEMENT_SCRIPT.md](./PYTHON_MANAGEMENT_SCRIPT.md)** - Modern Python CLI (NEW in v1.3)
  - Profile-aware management commands
  - Installation and setup (pip, venv, homebrew)
  - Complete command reference with examples
  - Migration strategy from bash script
  - Beautiful terminal output with Rich library

- **[MANAGEMENT.md](./MANAGEMENT.md)** - Bash management script guide
  - Complete command reference (20+ commands)
  - Daily operations workflow
  - Vault operations
  - Backup and restore procedures
  - Service lifecycle management

- **[INSTALLATION.md](./INSTALLATION.md)** - Step-by-step installation guide
  - Pre-flight checks and prerequisites
  - Profile selection guidance (Step 4.5)
  - Python script setup (recommended)
  - Bash script setup (traditional)
  - Vault initialization and bootstrap
  - Redis cluster initialization (for standard/full profiles)
  - Complete verification procedures

- **[USAGE.md](./USAGE.md)** - Daily usage guide
  - Starting and stopping services
  - Checking service status and health
  - Accessing service credentials
  - Common development workflows
  - IDE integration

- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** - Troubleshooting guide
  - Common startup issues (especially Vault bootstrap)
  - Service health check failures
  - Network connectivity problems
  - Database, Redis, and Vault issues
  - Complete diagnostic procedures
  - Docker/Colima troubleshooting

- **[PERFORMANCE_TUNING.md](./PERFORMANCE_TUNING.md)** - Performance optimization guide
  - Resource allocation (Colima VM, per-service limits)
  - Database performance tuning
  - Redis cluster optimization
  - API performance (caching, connection pooling)
  - Benchmarking procedures
  - Production scaling strategies

- **[PROFILE_IMPLEMENTATION_GUIDE.md](./PROFILE_IMPLEMENTATION_GUIDE.md)** - Technical profile implementation
  - Docker Compose profile architecture
  - Profile assignment strategy
  - Environment variable loading mechanism
  - Testing and validation procedures
  - Custom profile creation

- **[PROFILE_TESTING_CHECKLIST.md](./PROFILE_TESTING_CHECKLIST.md)** - Profile testing procedures
  - 60+ manual test cases for all profiles
  - Automated testing script usage
  - Profile combination tests
  - Environment override validation
  - Performance and regression testing

### API Development Patterns

- **[../reference-apps/API_PATTERNS.md](../reference-apps/API_PATTERNS.md)** - API design patterns
  - Code-first vs API-first development
  - Pattern implementations
  - Synchronization strategies
  - Testing approaches

- **[../reference-apps/shared/openapi.yaml](../reference-apps/shared/openapi.yaml)** - OpenAPI 3.1.0 specification
  - Complete API contract (841 lines)
  - Single source of truth for both implementations
  - Used to validate synchronization between code-first and API-first
  - Auto-generated documentation at http://localhost:8000/docs

## Quick Links

### Project-Level Documentation

Located in the project root and `.github/`:
- [README.md](../README.md) - Main project documentation
- [CONTRIBUTING.md](../.github/CONTRIBUTING.md) - Contribution guidelines
- [SECURITY.md](../.github/SECURITY.md) - Security policy and reporting
- [CODE_OF_CONDUCT.md](../.github/CODE_OF_CONDUCT.md) - Community standards
- [CHANGELOG.md](../.github/CHANGELOG.md) - Version history

### Component Documentation

- **Reference Applications**
  - [Reference Apps Overview](../reference-apps/README.md)
  - [FastAPI Code-First](../reference-apps/fastapi/README.md)
  - [FastAPI API-First](../reference-apps/fastapi-api-first/README.md)
  - [Go Reference API](../reference-apps/golang/README.md)
  - [Node.js Reference API](../reference-apps/nodejs/README.md)
  - [Rust Reference API](../reference-apps/rust/README.md)
  - [API Patterns](../reference-apps/API_PATTERNS.md)

- **Testing Infrastructure**
  - [Tests Overview](../tests/README.md)
  - [Test Coverage](../tests/TEST_COVERAGE.md)

## Documentation Standards

### Writing Guidelines

1. **Use Clear Headings** - Organize with H2 (##) and H3 (###) headers
2. **Include Examples** - Provide code samples and command examples
3. **Add Context** - Explain why, not just what
4. **Keep Updated** - Update docs when code changes
5. **Test Commands** - Verify all commands work before documenting

### File Naming

- Use SCREAMING_SNAKE_CASE for major docs: `SECURITY_ASSESSMENT.md`
- Use kebab-case for topic-specific docs: `vault-security.md`
- Use README.md for directory overviews

### Links and References

- Use relative links for internal documentation
- Link to specific sections with anchors: `#heading-name`
- Keep links up to date when moving files

## Contributing to Documentation

See [CONTRIBUTING.md](../.github/CONTRIBUTING.md) for guidelines on:
- Documentation style guide
- Review process
- Testing documentation changes
- Submitting documentation improvements

## Documentation Coverage

| Category | Files | Status |
|----------|-------|--------|
| Project Information | 1 | ✅ Complete |
| Security | 3 | ✅ Complete |
| Testing | 4 | ✅ Complete (includes PROFILE_TESTING_CHECKLIST.md) |
| Architecture | 1 | ✅ Complete |
| Service Profiles (NEW v1.3) | 3 | ✅ Complete (SERVICE_PROFILES.md, PYTHON_MANAGEMENT_SCRIPT.md, PROFILE_IMPLEMENTATION_GUIDE.md) |
| Operational Guides | 10 | ✅ Complete |
| API Patterns | 1 | ✅ Complete |
| Reference Apps | 6 | ✅ Complete |
| Infrastructure | 1 | ✅ Complete |
| **Total Documentation Files** | **30+** | **✅ 98% Coverage** |

## Useful Resources

### External Documentation

- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Colima Documentation](https://github.com/abiosoft/colima)
- [Gin Web Framework (Go)](https://gin-gonic.com/)
- [Express.js (Node.js)](https://expressjs.com/)
- [Actix-web (Rust)](https://actix.rs/)

### Infrastructure Components

- [PostgreSQL 16 Documentation](https://www.postgresql.org/docs/16/)
- [MySQL 8.0 Documentation](https://dev.mysql.com/doc/refman/8.0/)
- [MongoDB 7.0 Documentation](https://www.mongodb.com/docs/v7.0/)
- [Redis 7.4 Documentation](https://redis.io/docs/)
- [RabbitMQ 3.13 Documentation](https://www.rabbitmq.com/docs)

### Observability Stack

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [Vector Documentation](https://vector.dev/docs/)

## Documentation Maintenance

### When to Update Documentation

- ✅ When adding new features
- ✅ When changing configuration
- ✅ When fixing bugs that affect usage
- ✅ When deprecating features
- ✅ After major test runs
- ✅ When security issues are discovered/fixed

### Review Schedule

- **Monthly:** Review for accuracy
- **Quarterly:** Update test results
- **Per Release:** Update .github/CHANGELOG.md
- **As Needed:** Security documentation

## Need Help?

- 📖 Start with [README.md](../README.md)
- 🔒 Security questions? See [SECURITY.md](../.github/SECURITY.md)
- 🧪 Testing questions? See [tests/README.md](../tests/README.md)
- 🚀 API questions? See [reference-apps/README.md](../reference-apps/README.md)
- 🤝 Want to contribute? See [CONTRIBUTING.md](../.github/CONTRIBUTING.md)
