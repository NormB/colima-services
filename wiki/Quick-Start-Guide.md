# Quick Start Guide

Get DevStack Core running in **5 minutes** with this streamlined guide.

## Prerequisites

- **Mac with Apple Silicon** (M Series Processors)
- **Homebrew** installed
- **15GB free disk space**
- **macOS 12.0+** (Monterey or later)

## Step 1: Install Required Software

```bash
# Install Colima, Docker, and Docker Compose
brew install colima docker docker-compose
```

## Step 2: Clone the Repository

```bash
# Clone to your home directory
git clone https://github.com/NormB/devstack-core.git ~/devstack-core
cd ~/devstack-core
```

## Step 3: Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Optional: Edit .env to customize settings
# nano .env
```

**Note:** Passwords are intentionally empty in `.env` - they will be auto-generated and stored in Vault during bootstrap.

## Step 4: Start Everything

```bash
# This starts Colima VM and all services
./manage-devstack start
```

**What happens:**
- Colima VM starts with 4 CPUs, 8GB RAM, 60GB disk
- All Docker services start (Vault, PostgreSQL, Redis, etc.)
- Vault auto-initializes and auto-unseals

**Expected time:** 2-3 minutes

## Step 5: Bootstrap Vault

```bash
# Initialize Vault PKI and store all service credentials
./manage-devstack vault-bootstrap
```

**What happens:**
- Creates Root CA and Intermediate CA
- Generates TLS certificates for all services
- Stores database passwords in Vault
- Exports CA certificates to ~/.config/vault/

**Expected time:** 30-60 seconds

## Step 6: Verify Everything Works

```bash
# Check service status
./manage-devstack status

# Run health checks
./manage-devstack health
```

**Expected output:** All services should show as "running" and "healthy"

## 🎉 You're Done!

### Access Your Services

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| **Forgejo (Git)** | http://localhost:3000 | Setup on first visit |
| **Vault UI** | http://localhost:8200/ui | Token in `~/.config/vault/root-token` |
| **RabbitMQ Management** | http://localhost:15672 | Vault: `secret/rabbitmq` |
| **Grafana** | http://localhost:3001 | admin/admin |
| **Prometheus** | http://localhost:9090 | No auth |
| **FastAPI Docs** | http://localhost:8000/docs | No auth |

### Database Connections

```bash
# PostgreSQL
psql postgresql://dev_admin@localhost:5432/dev_database

# Get password from Vault
./manage-devstack vault-show-password postgres

# MySQL
mysql -h 127.0.0.1 -u dev_admin -p dev_database

# MongoDB
mongosh mongodb://localhost:27017

# Redis
redis-cli -h localhost -p 6379
```

## Next Steps

Now that you're up and running:

1. **Explore the APIs** - Visit http://localhost:8000/docs
2. **Check the Reference Apps** - See [Reference Applications](Reference-Applications)
3. **Learn about Vault** - Read [Vault Integration](Vault-Integration)
4. **Run the Tests** - Follow [Testing Guide](Testing-Guide)

## Quick Command Reference

```bash
# View all commands
./manage-devstack --help

# View logs
./manage-devstack logs vault
./manage-devstack logs postgres

# Restart a service
./manage-devstack restart redis-1

# Stop everything
./manage-devstack stop

# Backup databases
./manage-devstack backup
```

## Troubleshooting

### Services Won't Start

```bash
# Check Vault status
./manage-devstack vault-status

# If Vault is sealed, restart
docker compose restart vault
```

### "Connection Refused" Errors

```bash
# Check service is running
docker compose ps

# Check logs for errors
./manage-devstack logs <service-name>
```

### Need to Reset Everything?

```bash
# Complete reset (destroys all data)
./manage-devstack reset
```

**⚠️ Warning:** This deletes ALL data including databases, Vault keys, and configuration.

## Common Issues

| Issue | Solution |
|-------|----------|
| Colima won't start | `colima delete && ./manage-devstack start` |
| Vault sealed | `docker compose restart vault` (auto-unseals) |
| Port already in use | Stop conflicting service or change port in `.env` |
| Out of memory | Increase Colima RAM: edit `manage-devstack` line 42 |

## Getting Help

- 📖 Full documentation: [docs/](https://github.com/NormB/devstack-core/tree/main/docs)
- 🐛 Common problems: [Common Issues](Common-Issues)
- 💬 Ask questions: [GitHub Issues](https://github.com/NormB/devstack-core/issues)

---

**Ready to dive deeper?** Check out the [Architecture Overview](Architecture-Overview) to understand how everything works together.
