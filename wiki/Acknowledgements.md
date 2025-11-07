# Acknowledgements

Recognition and gratitude for the projects, tools, and communities that made DevStack Core possible.

## Table of Contents

- [Core Infrastructure](#core-infrastructure)
- [Databases and Data Stores](#databases-and-data-stores)
- [Observability and Monitoring](#observability-and-monitoring)
- [Development Tools](#development-tools)
- [Reference Application Frameworks](#reference-application-frameworks)
- [Documentation and Standards](#documentation-and-standards)
- [Community and Inspiration](#community-and-inspiration)
- [Special Thanks](#special-thanks)

---

## Core Infrastructure

### Colima - Containers on Linux on macOS

**Project:** [Colima](https://github.com/abiosoft/colima)
**License:** MIT

Colima is the foundation of this entire project, providing lightweight, fast Docker container runtime on Apple Silicon Macs. Without Colima's excellent work in leveraging Apple's Virtualization.framework and Lima, this development environment wouldn't exist.

**Why Colima:**
- Native ARM64 support for Apple Silicon
- Lightweight alternative to Docker Desktop
- Open source and free
- Excellent performance and resource efficiency

**Thank you** to [Abiola Ibrahim](https://github.com/abiosoft) and all Colima contributors for creating such an essential tool for macOS developers.

---

### Docker and Docker Compose

**Project:** [Docker](https://github.com/docker) | [Docker Compose](https://github.com/docker/compose)
**License:** Apache 2.0

Docker and Docker Compose are the orchestration foundation, enabling container-based infrastructure as code.

**Impact:**
- Declarative service definitions
- Reproducible environments
- Network and volume management
- Multi-container orchestration

**Thank you** to Docker, Inc. and the Docker community for revolutionizing application deployment.

---

### HashiCorp Vault

**Project:** [Vault](https://github.com/hashicorp/vault)
**License:** Business Source License 1.1 (BSL)

Vault provides centralized secrets management and PKI infrastructure, eliminating hardcoded credentials and enabling secure certificate generation.

**Impact:**
- Zero secrets in configuration files
- Dynamic secret generation
- Two-tier PKI (Root CA → Intermediate CA → Service Certificates)
- Audit logging and access control

**Thank you** to HashiCorp for building enterprise-grade security tools that work beautifully in development environments.

---

## Databases and Data Stores

### PostgreSQL

**Project:** [PostgreSQL](https://www.postgresql.org/)
**License:** PostgreSQL License (permissive)

The world's most advanced open source relational database, serving as the primary database for Forgejo and development workloads.

**Thank you** to the PostgreSQL Global Development Group for decades of reliable, standards-compliant database excellence.

---

### MySQL

**Project:** [MySQL](https://github.com/mysql/mysql-server)
**License:** GPL v2 (with FOSS exception)

Widely-used relational database providing legacy database support during migration periods.

**Thank you** to Oracle and the MySQL community for maintaining one of the most popular databases in the world.

---

### MongoDB

**Project:** [MongoDB](https://github.com/mongodb/mongo)
**License:** Server Side Public License (SSPL)

Leading NoSQL document database for unstructured and semi-structured data.

**Thank you** to MongoDB, Inc. and contributors for pioneering flexible document-oriented database design.

---

### Redis

**Project:** [Redis](https://github.com/redis/redis)
**License:** BSD 3-Clause (versions ≤7.4), RSALv2 and SSPLv1 (versions ≥7.4)

High-performance in-memory data structure store, used for caching, sessions, and distributed operations.

**Thank you** to [Salvatore Sanfilippo](https://github.com/antirez) and the Redis community for creating the fastest, most versatile in-memory database.

---

### RabbitMQ

**Project:** [RabbitMQ](https://github.com/rabbitmq/rabbitmq-server)
**License:** Mozilla Public License 2.0 (MPL)

Reliable, mature messaging broker implementing AMQP, enabling asynchronous communication between services.

**Thank you** to VMware (Broadcom), Erlang Solutions, and the RabbitMQ community for robust message queueing.

---

### PgBouncer

**Project:** [PgBouncer](https://github.com/pgbouncer/pgbouncer)
**License:** ISC License

Lightweight connection pooler for PostgreSQL, dramatically reducing connection overhead.

**Thank you** to the PgBouncer maintainers for this essential PostgreSQL companion tool.

---

## Observability and Monitoring

### Prometheus

**Project:** [Prometheus](https://github.com/prometheus/prometheus)
**License:** Apache 2.0

Open-source monitoring system and time series database, providing metrics collection and alerting.

**Thank you** to the Cloud Native Computing Foundation (CNCF) and Prometheus community for defining modern observability standards.

---

### Grafana

**Project:** [Grafana](https://github.com/grafana/grafana)
**License:** AGPLv3

Beautiful, powerful visualization and analytics platform for metrics, logs, and traces.

**Thank you** to Grafana Labs and the open source community for making data visualization accessible and elegant.

---

### Loki

**Project:** [Loki](https://github.com/grafana/loki)
**License:** AGPLv3

Horizontally-scalable, highly-available log aggregation system inspired by Prometheus.

**Thank you** to Grafana Labs for creating "Prometheus for logs" and revolutionizing log management.

---

### Vector

**Project:** [Vector](https://github.com/vectordotdev/vector)
**License:** Mozilla Public License 2.0 (MPL)

High-performance observability data pipeline, replacing multiple single-purpose exporters.

**Thank you** to Datadog and Vector contributors for building a unified, efficient data pipeline.

---

### cAdvisor

**Project:** [cAdvisor](https://github.com/google/cadvisor)
**License:** Apache 2.0

Container Advisor providing resource usage and performance metrics for containers.

**Thank you** to Google and the Kubernetes community for essential container monitoring infrastructure.

---

## Development Tools

### Forgejo

**Project:** [Forgejo](https://codeberg.org/forgejo/forgejo)
**License:** MIT

Self-hosted Git service (Gitea fork) providing private repository hosting, pull requests, and CI/CD.

**Thank you** to the Forgejo community for creating a true community-owned Git hosting solution with strong governance.

---

### Git

**Project:** [Git](https://github.com/git/git)
**License:** GPL v2

The distributed version control system that changed software development forever.

**Thank you** to [Linus Torvalds](https://github.com/torvalds), [Junio C Hamano](https://github.com/gitster), and the Git community for 20 years of reliable version control.

---

## Reference Application Frameworks

### FastAPI (Python)

**Project:** [FastAPI](https://github.com/tiangolo/fastapi)
**License:** MIT

Modern, fast (high-performance) web framework for building APIs with Python 3.7+ based on standard Python type hints.

**Thank you** to [Sebastián Ramírez](https://github.com/tiangolo) for creating the most developer-friendly Python web framework.

---

### Gin (Go)

**Project:** [Gin](https://github.com/gin-gonic/gin)
**License:** MIT

High-performance HTTP web framework for Go, featuring a Martini-like API with much better performance.

**Thank you** to the Gin community for making Go web development fast and elegant.

---

### Express (Node.js)

**Project:** [Express](https://github.com/expressjs/express)
**License:** MIT

Fast, unopinionated, minimalist web framework for Node.js, the de facto standard for Node.js web applications.

**Thank you** to [TJ Holowaychuk](https://github.com/tj) and the Express community for defining Node.js web development patterns.

---

### Actix-web (Rust)

**Project:** [Actix-web](https://github.com/actix/actix-web)
**License:** MIT or Apache 2.0

Powerful, pragmatic, and extremely fast web framework for Rust.

**Thank you** to the Actix community for bringing Rust's performance and safety to web development.

---

## Documentation and Standards

### OpenAPI Specification

**Project:** [OpenAPI](https://github.com/OAI/OpenAPI-Specification)
**Organization:** OpenAPI Initiative (Linux Foundation)
**License:** Apache 2.0

Standard for describing HTTP APIs, enabling API-first development and automatic documentation generation.

**Thank you** to the OpenAPI Initiative for standardizing API documentation and tooling.

---

### Markdown

**Creators:** [John Gruber](https://daringfireball.net/) and Aaron Swartz
**License:** Public Domain (original), various (implementations)

Lightweight markup language for creating formatted text using a plain-text editor, used for all documentation in this project.

**Thank you** to John Gruber for creating the most accessible documentation format.

---

### CommonMark

**Project:** [CommonMark](https://commonmark.org/)
**License:** BSD 2-Clause

Strongly specified, highly compatible implementation of Markdown, ensuring consistent rendering.

**Thank you** to the CommonMark community for standardizing Markdown syntax.

---

## Community and Inspiration

### DevOps Community

**Inspiration from:**
- [The Twelve-Factor App](https://12factor.net/) methodology
- Infrastructure as Code (IaC) principles
- GitOps workflows
- Cloud Native Computing Foundation (CNCF) projects

**Thank you** to the entire DevOps community for establishing modern infrastructure patterns that inspire projects like this.

---

### Homebrew

**Project:** [Homebrew](https://github.com/Homebrew/brew)
**License:** BSD 2-Clause

The missing package manager for macOS, making software installation simple and consistent.

**Thank you** to [Max Howell](https://github.com/mxcl) and Homebrew maintainers for revolutionizing macOS package management.

---

### Open Source Community

**General gratitude to:**
- Stack Overflow community for countless solutions
- GitHub for hosting and collaboration tools
- All open source maintainers who work tirelessly
- Documentation writers who make complex topics accessible
- Security researchers who find and responsibly disclose vulnerabilities

**Thank you** to everyone who contributes to open source software, from code to documentation to issue reports.

---

## Special Thanks

### Anthropic Claude

**Service:** [Anthropic](https://www.anthropic.com/)

Claude AI assisted in creating comprehensive documentation, writing code examples, and structuring this project's wiki with 56 pages of detailed technical documentation.

**Impact:**
- 40,000+ lines of wiki documentation
- Code examples in 6 programming languages
- Comprehensive troubleshooting guides
- Best practices documentation
- Architecture diagrams and explanations

**Thank you** to Anthropic for building AI systems that genuinely help developers create better documentation.

---

### Apple

**Company:** [Apple Inc.](https://www.apple.com/)
**Products:** Apple Silicon (M Series Processors), macOS, Virtualization.framework

Apple Silicon Macs provide the powerful, energy-efficient hardware that makes this development environment possible. The Virtualization.framework enables Colima to run containers natively with excellent performance.

**Thank you** to Apple for creating revolutionary hardware and providing low-level APIs that enable projects like Colima.

---

### You - The Developer

**Most importantly:** Thank you to **everyone using this project**.

Your feedback, bug reports, feature requests, and contributions make this project better. Whether you're:
- Using it for local development
- Learning Docker and infrastructure concepts
- Exploring microservices patterns
- Contributing documentation improvements
- Reporting issues
- Sharing it with colleagues

**You make this worthwhile.** Thank you.

---

## Contributing Acknowledgements

Want to be acknowledged for your contributions?

**Contribute to DevStack Core:**
- Submit pull requests
- Report bugs and suggest features
- Improve documentation
- Share your experience
- Help other users

See [Contributing-Guide](Contributing-Guide) for details.

---

## License Information

DevStack Core itself is open source and permissively licensed. All dependencies listed above are used in accordance with their respective licenses. For specific license details, please refer to each project's repository.

**DevStack Core License:** MIT (see repository)

---

## Stay Connected

- **GitHub Repository:** [NormB/devstack-core](https://github.com/NormB/devstack-core)
- **GitHub Wiki:** [devstack-core/wiki](https://github.com/NormB/devstack-core/wiki)
- **Issues:** [Report bugs or request features](https://github.com/NormB/devstack-core/issues)

---

## Conclusion

This project stands on the shoulders of giants. Every tool, framework, and service integrated here represents years of work by talented developers and communities around the world.

**Open source is built on gratitude, collaboration, and shared knowledge.**

Thank you to everyone who makes open source possible. 🙏

---

*Last updated: 2025-10-29*

*If we've missed acknowledging any project, please [open an issue](https://github.com/NormB/devstack-core/issues) and we'll add it.*
