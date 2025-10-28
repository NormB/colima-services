# Management Script

## Table of Contents

- [Available Commands](#available-commands)
- [Common Workflows](#common-workflows)
- [Advanced Usage](#advanced-usage)

---

The `manage-colima.sh` script provides a unified interface for all operations.

### Available Commands

```bash
./manage-colima.sh <command> [options]
```

| Command | Description | Example |
|---------|-------------|---------|
| `start` | Start Colima VM and all services | `./manage-colima.sh start` |
| `stop` | Stop services and Colima VM | `./manage-colima.sh stop` |
| `restart` | Restart Docker services | `./manage-colima.sh restart` |
| `status` | Show Colima and service status | `./manage-colima.sh status` |
| `logs [service]` | View service logs | `./manage-colima.sh logs postgres` |
| `shell [service]` | Open shell in container | `./manage-colima.sh shell postgres` |
| `ip` | Get Colima IP address | `./manage-colima.sh ip` |
| `health` | Check service health | `./manage-colima.sh health` |
| `backup` | Backup all service data | `./manage-colima.sh backup` |
| `reset` | Delete and reset Colima VM | `./manage-colima.sh reset` |
| `vault-init` | Initialize Vault | `./manage-colima.sh vault-init` |
| `vault-unseal` | Manually unseal Vault | `./manage-colima.sh vault-unseal` |
| `vault-status` | Show Vault status | `./manage-colima.sh vault-status` |
| `vault-token` | Print Vault root token | `./manage-colima.sh vault-token` |
| `vault-bootstrap` | Setup Vault PKI and service credentials | `./manage-colima.sh vault-bootstrap` |
| `vault-ca-cert` | Export CA certificates | `./manage-colima.sh vault-ca-cert` |
| `vault-show-password <service>` | Show service password from Vault | `./manage-colima.sh vault-show-password postgres` |
| `help` | Show help message | `./manage-colima.sh help` |

### Common Workflows

**Daily Development:**
```bash
# Morning: Start everything
./manage-colima.sh start

# Check what's running
./manage-colima.sh status

# View logs if something's wrong
./manage-colima.sh logs postgres

# Evening: Stop everything (or leave running)
./manage-colima.sh stop
```

**Troubleshooting:**
```bash
# Check health of all services
./manage-colima.sh health

# View logs for specific service
./manage-colima.sh logs vault

# Open shell to investigate
./manage-colima.sh shell postgres

# Restart specific service
docker compose restart postgres

# Full restart
./manage-colima.sh restart
```

**Backup and Maintenance:**
```bash
# Weekly backup
./manage-colima.sh backup

# Check resource usage
./manage-colima.sh status
# Look at CPU/Memory columns

# Clean up old images
docker system prune -a

# Reset everything (WARNING: destroys data)
./manage-colima.sh reset
./manage-colima.sh start
```

### Advanced Usage

**Custom Colima Configuration:**
```bash
# Set custom resources
export COLIMA_CPU=6
export COLIMA_MEMORY=12
export COLIMA_DISK=100
./manage-colima.sh start

# Use different profile
export COLIMA_PROFILE=myproject
./manage-colima.sh start
```

**Script Internals:**

The script performs these operations:

1. **Environment Check** (`check_env_file`):
   - Verifies `.env` exists
   - Creates from `.env.example` if missing
   - Warns about setting passwords

2. **Colima Management**:
   - Starts with optimized flags: `--vm-type vz --network-address`
   - Monitors status: `is_colima_running()`
   - Gets IP: `get_colima_ip()`

3. **Service Management**:
   - Uses `docker compose` commands
   - Waits for healthy status
   - Auto-initializes Vault on first start

4. **Backup Process** (`cmd_backup`):
   ```bash
   # PostgreSQL: pg_dumpall
   docker compose exec -T postgres pg_dumpall > backup.sql

   # MySQL: mysqldump
   docker compose exec -T mysql mysqldump --all-databases > backup.sql

   # MongoDB: mongodump
   docker compose exec -T mongodb mongodump --archive > backup.archive

   # Forgejo: tar volumes
   docker compose exec -T forgejo tar czf - /data > forgejo.tar.gz
   ```

