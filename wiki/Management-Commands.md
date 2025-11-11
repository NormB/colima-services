# Management Script

## Table of Contents

- [Management Scripts Overview](#management-scripts-overview)
- [Python Script (NEW v1.3)](#python-script-new-v13)
- [Bash Script (Traditional)](#bash-script-traditional)
- [Available Commands](#available-commands)
- [Common Workflows](#common-workflows)
- [Advanced Usage](#advanced-usage)

---

## Management Scripts Overview

DevStack Core provides two management interfaces:

1. **Python Script (Recommended)**: `manage-devstack` - Modern CLI with service profile support
2. **Bash Script (Traditional)**: `manage-devstack` - Backward compatible, starts all services

**Which Should You Use?**

- **Use Python script if:** You want profile control, colored output, better UX
- **Use Bash script if:** You want all services, no profile management needed, backward compatibility

Both scripts are maintained and fully functional.

---

## Python Script (NEW v1.3)

The modern Python management script provides profile-aware service orchestration with beautiful terminal output.

### Installation

```bash
# Install dependencies
uv venv
uv pip install -r scripts/requirements.txt

# The wrapper script automatically uses the venv
chmod +x manage-devstack

# Verify
./manage-devstack --version
```

### Python Script Commands

```bash
./manage-devstack <command> [options]
```

| Command | Description | Example |
|---------|-------------|---------|
| `start --profile <name>` | Start services with profile | `./manage-devstack start --profile standard` |
| `stop [--profile <name>]` | Stop services (optionally by profile) | `./manage-devstack stop` |
| `status` | Show service status with resources | `./manage-devstack status` |
| `health` | Check service health (colored table) | `./manage-devstack health` |
| `logs <service>` | View service logs | `./manage-devstack logs postgres` |
| `shell <service>` | Open shell in container | `./manage-devstack shell postgres` |
| `profiles` | List available profiles | `./manage-devstack profiles` |
| `ip` | Show Colima IP address | `./manage-devstack ip` |
| `redis-cluster-init` | Initialize Redis cluster | `./manage-devstack redis-cluster-init` |
| `--help` | Show help message | `./manage-devstack --help` |

### Python Script Workflows

**Start with Standard Profile (Recommended):**
```bash
# Start full development stack
./manage-devstack start --profile standard

# Initialize Redis cluster (first time only)
./manage-devstack redis-cluster-init

# Check health
./manage-devstack health
```

**Start with Minimal Profile (Lightweight):**
```bash
# Start essential services only
./manage-devstack start --profile minimal

# Check what's running
./manage-devstack status
```

**Start with Full Profile (Observability):**
```bash
# Start everything including Prometheus/Grafana
./manage-devstack start --profile full

# Check health
./manage-devstack health
```

**Combine Profiles:**
```bash
# Start standard infrastructure + reference APIs
./manage-devstack start --profile standard --profile reference

# Verify
./manage-devstack status
```

**For complete Python script documentation, see [PYTHON_MANAGEMENT_SCRIPT.md](./PYTHON_MANAGEMENT_SCRIPT.md).**

---

## Bash Script (Traditional)

The `manage-devstack` script provides a unified interface for all operations. **Note:** This script starts ALL services (no profile support).

### Available Commands

```bash
./manage-devstack <command> [options]
```

| Command | Description | Example |
|---------|-------------|---------|
| `start` | Start Colima VM and all services | `./manage-devstack start` |
| `stop` | Stop services and Colima VM | `./manage-devstack stop` |
| `restart` | Restart Docker services | `./manage-devstack restart` |
| `status` | Show Colima and service status | `./manage-devstack status` |
| `logs [service]` | View service logs | `./manage-devstack logs postgres` |
| `shell [service]` | Open shell in container | `./manage-devstack shell postgres` |
| `ip` | Get Colima IP address | `./manage-devstack ip` |
| `health` | Check service health | `./manage-devstack health` |
| `backup` | Backup all service data | `./manage-devstack backup` |
| `reset` | Delete and reset Colima VM | `./manage-devstack reset` |
| `vault-init` | Initialize Vault | `./manage-devstack vault-init` |
| `vault-unseal` | Manually unseal Vault | `./manage-devstack vault-unseal` |
| `vault-status` | Show Vault status | `./manage-devstack vault-status` |
| `vault-token` | Print Vault root token | `./manage-devstack vault-token` |
| `vault-bootstrap` | Setup Vault PKI and service credentials | `./manage-devstack vault-bootstrap` |
| `vault-ca-cert` | Export CA certificates | `./manage-devstack vault-ca-cert` |
| `vault-show-password <service>` | Show service password from Vault | `./manage-devstack vault-show-password postgres` |
| `--help` | Show help message | `./manage-devstack --help` |

**Note:** The bash script uses `help` as a command, while the Python script uses `--help` as a standard flag.

### Common Workflows

**Daily Development:**
```bash
# Morning: Start everything
./manage-devstack start

# Check what's running
./manage-devstack status

# View logs if something's wrong
./manage-devstack logs postgres

# Evening: Stop everything (or leave running)
./manage-devstack stop
```

**Troubleshooting:**
```bash
# Check health of all services
./manage-devstack health

# View logs for specific service
./manage-devstack logs vault

# Open shell to investigate
./manage-devstack shell postgres

# Restart specific service
docker compose restart postgres

# Full restart
./manage-devstack restart
```

**Backup and Maintenance:**
```bash
# Weekly backup
./manage-devstack backup

# Check resource usage
./manage-devstack status
# Look at CPU/Memory columns

# Clean up old images
docker system prune -a

# Reset everything (WARNING: destroys data)
./manage-devstack reset
./manage-devstack start
```

### Advanced Usage

**Custom Colima Configuration:**
```bash
# Set custom resources
export COLIMA_CPU=6
export COLIMA_MEMORY=12
export COLIMA_DISK=100
./manage-devstack start

# Use different profile
export COLIMA_PROFILE=myproject
./manage-devstack start
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

