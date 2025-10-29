# FAQ (Frequently Asked Questions)

Common questions and answers about Colima Services.

## Table of Contents

- [General Questions](#general-questions)
- [Installation Questions](#installation-questions)
- [Vault Questions](#vault-questions)
- [Database Questions](#database-questions)
- [Performance Questions](#performance-questions)
- [Security Questions](#security-questions)

## General Questions

### What is Colima Services?

Colima Services is a complete Docker Compose-based development infrastructure optimized for Apple Silicon Macs. It provides databases (PostgreSQL, MySQL, MongoDB), caching (Redis cluster), messaging (RabbitMQ), secrets management (Vault), Git hosting (Forgejo), and observability tools (Prometheus, Grafana, Loki).

### Why use Colima instead of Docker Desktop?

**Advantages of Colima:**
- Free and open-source (no licensing fees)
- Lighter weight and faster on Apple Silicon
- Native ARM64 support via Apple's Virtualization.framework
- No Docker Desktop licensing restrictions
- More control over VM configuration

### How much does it cost?

**$0** - Everything is free and open-source. All tools and services used are open-source projects with permissive licenses.

### Can I use this in production?

This environment is designed for **local development and testing**. For production:
- Use managed services or dedicated infrastructure
- Implement proper security hardening (see [Security Hardening](Security-Hardening))
- Use Vault AppRole authentication instead of root token
- Enable network firewalls and access controls
- Review [docs/SECURITY_ASSESSMENT.md](https://github.com/NormB/colima-services/blob/main/docs/SECURITY_ASSESSMENT.md)

### What's the difference between this and Docker Desktop?

| Feature | Colima Services | Docker Desktop |
|---------|-----------------|----------------|
| **License** | Free (MIT) | Free for personal, paid for business |
| **Performance** | Optimized for Apple Silicon | Good, but heavier |
| **Resource Usage** | Lightweight | More resource-intensive |
| **VM Control** | Full control | Limited control |
| **Services** | 20+ pre-configured | None included |

## Installation Questions

### How long does installation take?

**Total time:** 20-30 minutes for first-time setup
- Installing software: 10-15 minutes
- Starting services: 2-3 minutes
- Vault initialization: 1-2 minutes
- Vault bootstrap: 2-3 minutes

### Do I need to install Docker Desktop first?

**No!** In fact, you should **not** have Docker Desktop running. Colima provides the Docker engine, so Docker Desktop is not needed and can cause conflicts.

### Can I run this on Intel Macs?

This guide is optimized for **Apple Silicon** (M Series Processors). While Colima works on Intel Macs, you'll need to adjust architecture settings and some images may not be available for x86_64.

### How do I uninstall everything?

```bash
# Stop and remove all services
./manage-colima.sh reset

# Stop Colima
colima stop
colima delete

# Uninstall software
brew uninstall colima docker docker-compose

# Remove configuration
rm -rf ~/.config/vault
rm -rf ~/colima-services
```

### What if I already have PostgreSQL/MySQL installed?

The services run in containers on **different ports by default**, so they won't conflict with local installations. However, if you have services using the same ports (5432, 3306, etc.), you'll need to either:
- Stop your local services, or
- Change ports in `.env` file

## Vault Questions

### What happens if I lose my Vault keys?

**Data is permanently unrecoverable.** Always backup `~/.config/vault/` immediately after initialization. Without the unseal keys, Vault data cannot be accessed.

### Do I need to manually unseal Vault every time?

**No** - Vault auto-unseals on startup using keys stored in `~/.config/vault/keys.json`. You never need to manually unseal unless you lose this file.

### How do I rotate service passwords?

```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update in Vault
vault kv put secret/postgres password="$NEW_PASSWORD"

# Restart service to pick up new password
docker compose restart postgres
```

### Can I use Vault for my application secrets?

**Yes!** That's exactly what the reference applications demonstrate. See [Reference Applications](Reference-Applications) for code examples.

### How do I access Vault UI?

1. Get root token: `cat ~/.config/vault/root-token`
2. Open: http://localhost:8200/ui
3. Sign in with the token

## Database Questions

### How do I connect to PostgreSQL?

```bash
# Get password
./manage-colima.sh vault-show-password postgres

# Connect
psql postgresql://dev_admin@localhost:5432/dev_database
# Enter password when prompted
```

### Can I use a GUI tool like pgAdmin or MySQL Workbench?

**Yes!** Use these connection details:
- **Host:** localhost
- **Port:** 5432 (PostgreSQL), 3306 (MySQL), 27017 (MongoDB)
- **Username:** dev_admin
- **Database:** dev_database
- **Password:** Get from Vault using `./manage-colima.sh vault-show-password <service>`

### Are databases persistent across restarts?

**Yes** - All data is stored in Docker volumes that persist across restarts. Data is only lost if you run `./manage-colima.sh reset` or manually delete volumes.

### How do I backup databases?

```bash
# Backup all databases
./manage-colima.sh backup

# Backups saved to: ./backups/YYYY-MM-DD_HH-MM-SS/
```

### Can I restore from backup?

```bash
# PostgreSQL
docker exec -i dev-postgres psql -U dev_admin -d dev_database < backups/2025-10-28/postgres_backup.sql

# MySQL
docker exec -i dev-mysql mysql -u dev_admin -p dev_database < backups/2025-10-28/mysql_backup.sql
```

## Performance Questions

### Services are running slowly

**Common causes and solutions:**

1. **Insufficient resources:**
   ```bash
   # Increase Colima allocation
   colima stop
   colima start --cpu 6 --memory 12 --disk 100
   ```

2. **Too many services:**
   ```bash
   # Stop unused services
   docker compose stop rust-api nodejs-api golang-api
   ```

3. **Database query performance:**
   ```bash
   # Use connection pooling (PgBouncer)
   # Connect to port 6432 instead of 5432
   ```

### How much RAM do I really need?

**Minimum:** 16GB total (8GB for Colima VM)
**Recommended:** 32GB total (12GB for Colima VM)
**Heavy usage:** 64GB total (16GB+ for Colima VM)

### Can I run this on an Apple Silicon MacBook Air (8GB RAM)?

**Not recommended.** With only 8GB total RAM, macOS will struggle. You'd need to:
- Run only essential services
- Reduce Colima allocation to 4GB
- Expect slower performance

### How do I optimize startup time?

**Already optimized!** The setup includes:
- Health-check based dependencies (services wait for Vault)
- Auto-unsealing Vault (no manual intervention)
- Parallel service startup where possible

Typical startup: 2-3 minutes

## Security Questions

### Is this secure for development?

**Yes, for local development.** Security considerations:
- All traffic stays on your machine (localhost)
- Services run in isolated Docker network
- Credentials stored in Vault, not .env files
- TLS available but optional (dev convenience)

### What about for production?

**No** - This setup prioritizes **developer experience** over production security. For production, see [Security Hardening](Security-Hardening).

### Are my credentials safe?

**On your machine: Yes**
- Stored in Vault (encrypted at rest)
- Vault data encrypted with master key
- No passwords in environment files

**If shared:** Never commit `.env` or `~/.config/vault/` to Git!

### Should I use TLS in development?

**Optional** - Services support dual-mode (TLS and non-TLS). Enable TLS if:
- Testing TLS-specific features
- Simulating production environment
- Learning certificate management

Disable for faster iteration during development.

### How do I trust the self-signed CA?

```bash
# Trust on macOS
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain \
  ~/.config/vault/ca/ca-chain.pem

# Verify
security verify-cert -c ~/.config/vault/ca/ca-chain.pem
```

## Troubleshooting Questions

### Services won't start - what do I check first?

**Diagnostic sequence:**
```bash
# 1. Is Colima running?
colima status

# 2. Is Vault healthy?
./manage-colima.sh vault-status

# 3. Check service logs
./manage-colima.sh logs <service-name>

# 4. Run health checks
./manage-colima.sh health
```

### Where can I get more help?

1. **[Common Issues](Common-Issues)** - Quick fixes
2. **[Troubleshooting](https://github.com/NormB/colima-services/blob/main/docs/TROUBLESHOOTING.md)** - Detailed guide
3. **[GitHub Issues](https://github.com/NormB/colima-services/issues)** - Community support
4. **Documentation** - Check [docs/](https://github.com/NormB/colima-services/tree/main/docs)

### What's the best way to report a bug?

Open a GitHub issue with:
- **System info:** macOS version, Colima version, Docker version
- **Steps to reproduce:** What you did
- **Expected behavior:** What should happen
- **Actual behavior:** What actually happened
- **Logs:** Output from `./manage-colima.sh logs <service>`

### Can I contribute to this project?

**Yes!** See [Contributing Guide](https://github.com/NormB/colima-services/blob/main/.github/CONTRIBUTING.md) for:
- Code contribution guidelines
- Documentation improvements
- Bug reports and feature requests
- Testing and validation

## More Questions?

- Check [Architecture Overview](Architecture-Overview) - Understand the design
- Review [Management Commands](Management-Commands) - Learn available commands
- Explore [Reference Applications](Reference-Applications) - See working examples
- Visit [Quick Start Guide](Quick-Start-Guide) - Get started quickly

---

**Don't see your question?** [Open an issue](https://github.com/NormB/colima-services/issues) to ask!
