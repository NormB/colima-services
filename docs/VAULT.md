# Vault PKI Integration

### Overview

HashiCorp Vault provides centralized secrets management and Public Key Infrastructure (PKI) for services. Instead of storing passwords in `.env` files, services fetch credentials from Vault at startup.

**Benefits:**
- ✅ Centralized secrets management
- ✅ Dynamic certificate generation
- ✅ Automatic certificate rotation
- ✅ Audit trail of secret access
- ✅ Optional SSL/TLS for encrypted connections
- ✅ No plaintext passwords in configuration files

**Architecture:**
```
Vault PKI Hierarchy
├── Root CA (10-year validity)
│   └── Intermediate CA (5-year validity)
│       └── Service Certificates (1-year validity)
│           ├── PostgreSQL
│           ├── MySQL
│           ├── Redis
│           └── Other services
```

### Service Vault Integration

**ALL services use Vault integration for credentials management.** PostgreSQL was the proof-of-concept, now fully implemented across the stack.

**Integrated Services:**
- ✅ PostgreSQL (`configs/postgres/scripts/init.sh`)
- ✅ MySQL (`configs/mysql/scripts/init.sh`)
- ✅ Redis Cluster (`configs/redis/scripts/init.sh`)
- ✅ RabbitMQ (`configs/rabbitmq/scripts/init.sh`)
- ✅ MongoDB (`configs/mongodb/scripts/init.sh`)

**How It Works (using PostgreSQL as example):**

1. **Container Startup** → Wrapper script (`/init/init.sh`) executes
2. **Wait for Vault** → Script waits for Vault to be unsealed and ready
3. **Fetch Credentials & TLS Setting** → GET `/v1/secret/data/postgres` (includes `tls_enabled` field)
4. **Validate Certificates** → Check pre-generated certificates exist if TLS enabled
5. **Configure PostgreSQL** → Injects credentials and TLS configuration
6. **Start PostgreSQL** → Calls original `docker-entrypoint.sh`

**Wrapper Script** (`configs/postgres/scripts/init.sh`):

```bash
#!/bin/bash
# PostgreSQL initialization with Vault integration

# 1. Wait for Vault to be ready
wait_for_vault()

# 2. Fetch credentials AND tls_enabled from Vault
export POSTGRES_USER=$(vault_api | jq -r '.data.data.user')
export POSTGRES_PASSWORD=$(vault_api | jq -r '.data.data.password')
export POSTGRES_DB=$(vault_api | jq -r '.data.data.database')
export ENABLE_TLS=$(vault_api | jq -r '.data.data.tls_enabled // "false"')

# 3. If TLS enabled, validate pre-generated certificates
if [ "$ENABLE_TLS" = "true" ]; then
    validate_certificates  # Check certs exist in mounted volume
    configure_tls          # Configure PostgreSQL SSL
fi

# 4. Start PostgreSQL with injected credentials
exec docker-entrypoint.sh postgres
```

**Fetching PostgreSQL Password:**

```bash
# Via management script
./manage-colima.sh vault-show-password postgres

# Via Vault CLI
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)
vault kv get -field=password secret/postgres

# Via curl
curl -H "X-Vault-Token: $VAULT_TOKEN" \
  http://localhost:8200/v1/secret/data/postgres \
  | jq -r '.data.data.password'
```

**Environment Variables:**

```bash
# In .env file
VAULT_ADDR=http://vault:8200
VAULT_TOKEN=hvs.xxxxxxxxxxxxx  # From ~/.config/vault/root-token
# NOTE: TLS settings are now in Vault, not .env
```

**Note:** ALL service passwords and TLS settings have been removed from `.env`. All credentials and TLS configuration are now managed entirely by Vault.

### SSL/TLS Certificate Management

**TLS Implementation: Pre-Generated Certificates with Vault-Based Configuration**

The system uses a modern, production-ready TLS architecture where:
- ✅ TLS settings are stored in **Vault** (not environment variables)
- ✅ Certificates are **pre-generated** and validated before service startup
- ✅ Runtime enable/disable without container rebuilds
- ✅ All 8 services support TLS (PostgreSQL, MySQL, Redis cluster, RabbitMQ, MongoDB, FastAPI reference app)
- ✅ Dual-mode operation (accepts both SSL and non-SSL connections)

**One-Time Certificate Generation:**

```bash
# 1. Ensure Vault is running and bootstrapped
docker compose up -d vault
sleep 10

# 2. Bootstrap Vault (creates secrets with tls_enabled field)
VAULT_ADDR=http://localhost:8200 \
VAULT_TOKEN=$(cat ~/.config/vault/root-token) \
  bash configs/vault/scripts/vault-bootstrap.sh

# 3. Generate all certificates (stored in ~/.config/vault/certs/)
VAULT_ADDR=http://localhost:8200 \
VAULT_TOKEN=$(cat ~/.config/vault/root-token) \
  bash scripts/generate-certificates.sh
```

**Enabling TLS for a Service (Runtime Configuration):**

```bash
# 1. Set tls_enabled=true in Vault
TOKEN=$(cat ~/.config/vault/root-token)
curl -sf -X POST \
  -H "X-Vault-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"data":{"tls_enabled":true}}' \
  http://localhost:8200/v1/secret/data/postgres

# 2. Restart the service (picks up new setting)
docker restart dev-postgres

# 3. Verify TLS is enabled
docker logs dev-postgres | grep "tls_enabled"
# Should show: tls_enabled=true
```

**Disabling TLS:**

```bash
# Set tls_enabled=false and restart
TOKEN=$(cat ~/.config/vault/root-token)
curl -sf -X POST \
  -H "X-Vault-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"data":{"tls_enabled":false}}' \
  http://localhost:8200/v1/secret/data/postgres

docker restart dev-postgres
```

**Certificate Rotation:**

```bash
# 1. Delete old certificates for a service
rm -rf ~/.config/vault/certs/postgres/

# 2. Regenerate certificates
VAULT_ADDR=http://localhost:8200 \
VAULT_TOKEN=$(cat ~/.config/vault/root-token) \
  bash scripts/generate-certificates.sh

# 3. Restart service to pick up new certificates
docker restart dev-postgres
```

**Certificate Details:**
- **Validity:** 1 year (8760 hours)
- **Storage:** `~/.config/vault/certs/{service}/`
- **Mount:** Read-only bind mounts into containers
- **Format:** Service-specific (e.g., MySQL uses .pem, MongoDB uses combined cert+key)

**Testing TLS Connections:**

All services are configured for **dual-mode TLS** (accepting both encrypted and unencrypted connections).

**PostgreSQL:**
```bash
# Get password from Vault
export PGPASSWORD=$(python3 scripts/read-vault-secret.py postgres password)

# SSL connection (with certificate verification)
psql "postgresql://dev_admin@localhost:5432/dev_database?sslmode=require"

# Non-SSL connection (dual-mode allows this)
psql "postgresql://dev_admin@localhost:5432/dev_database?sslmode=disable"

# Verify SSL is enabled
docker exec dev-postgres psql -U dev_admin -d dev_database -c "SHOW ssl;"
```

**MySQL:**
```bash
# Get password from Vault
MYSQL_PASS=$(export VAULT_TOKEN=$(cat ~/.config/vault/root-token); python3 scripts/read-vault-secret.py mysql password)

# SSL connection
mysql -h localhost -u dev_admin -p$MYSQL_PASS --ssl-mode=REQUIRED dev_database

# Non-SSL connection
mysql -h localhost -u dev_admin -p$MYSQL_PASS --ssl-mode=DISABLED dev_database

# Verify TLS is configured
docker logs dev-mysql | grep "Channel mysql_main configured to support TLS"
```

**Redis:**
```bash
# Get password from Vault
REDIS_PASS=$(export VAULT_TOKEN=$(cat ~/.config/vault/root-token); python3 scripts/read-vault-secret.py redis-1 password)

# SSL connection (TLS port 6380)
redis-cli -h localhost -p 6380 --tls \
  --cacert ~/.config/vault/certs/redis-1/ca.crt \
  --cert ~/.config/vault/certs/redis-1/redis.crt \
  --key ~/.config/vault/certs/redis-1/redis.key \
  -a $REDIS_PASS PING

# Non-SSL connection (standard port 6379)
redis-cli -h localhost -p 6379 -a $REDIS_PASS PING

# Verify dual ports
docker logs dev-redis-1 | grep "Ready to accept connections"
```

**RabbitMQ:**
```bash
# SSL port: 5671
# Non-SSL port: 5672 (management UI also available on 15672)

# Test management API
curl -u admin:$(export VAULT_TOKEN=$(cat ~/.config/vault/root-token); python3 scripts/read-vault-secret.py rabbitmq password) \
  http://localhost:15672/api/overview
```

**MongoDB:**
```bash
# Get credentials from Vault
MONGO_USER=$(export VAULT_TOKEN=$(cat ~/.config/vault/root-token); python3 scripts/read-vault-secret.py mongodb user)
MONGO_PASS=$(export VAULT_TOKEN=$(cat ~/.config/vault/root-token); python3 scripts/read-vault-secret.py mongodb password)

# SSL connection (if TLS is enabled)
mongosh "mongodb://$MONGO_USER:$MONGO_PASS@localhost:27017/dev_database?tls=true&tlsCAFile=$HOME/.config/vault/certs/mongodb/ca.pem"

# Non-SSL connection
mongosh "mongodb://$MONGO_USER:$MONGO_PASS@localhost:27017/dev_database"
```

**SSL/TLS Modes:**
- **PostgreSQL SSL Modes:**
  - `disable` - No SSL
  - `allow` - Try SSL, fallback to plain
  - `prefer` - Prefer SSL, fallback to plain
  - `require` - Require SSL (no cert verification)
  - `verify-ca` - Require SSL + verify CA certificate
  - `verify-full` - Require SSL + verify CA + hostname matching

- **MySQL SSL Modes:**
  - `DISABLED` - No SSL
  - `PREFERRED` - Use SSL if available
  - `REQUIRED` - Require SSL
  - `VERIFY_CA` - Verify CA certificate
  - `VERIFY_IDENTITY` - Verify CA + hostname

### Vault Commands

**Vault Management Script Commands:**

```bash
# Initialize Vault (first time only)
./manage-colima.sh vault-init

# Check Vault status
./manage-colima.sh vault-status

# Get root token
./manage-colima.sh vault-token

# Unseal Vault manually (if needed)
./manage-colima.sh vault-unseal

# Bootstrap PKI and service credentials
./manage-colima.sh vault-bootstrap

# Export CA certificates
./manage-colima.sh vault-ca-cert

# Show service password
./manage-colima.sh vault-show-password postgres
./manage-colima.sh vault-show-password mysql
```

**Vault Bootstrap Process:**

The `vault-bootstrap` command sets up the complete PKI infrastructure:

1. **Generate Root CA** (if not exists)
2. **Generate Intermediate CA CSR**
3. **Sign Intermediate CA with Root CA**
4. **Install Intermediate CA certificate**
5. **Create PKI roles for each service** (postgres-role, mysql-role, etc.)
6. **Generate and store service credentials** (user, password, database)
7. **Export CA certificates** to `~/.config/vault/ca/`

**Manual Vault Operations:**

```bash
# Set environment
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# List secret paths
vault kv list secret/

# Get PostgreSQL credentials
vault kv get secret/postgres

# Update password (manual rotation)
vault kv put secret/postgres \
  user=dev_admin \
  password=new_generated_password \
  database=dev_database

# Issue certificate manually
vault write pki_int/issue/postgres-role \
  common_name=postgres.dev-services.local \
  ttl=8760h

# View PKI role configuration
vault read pki_int/roles/postgres-role
```

**PKI Certificate Paths:**

```
Vault PKI Endpoints:
├── /v1/pki/ca/pem                      # Root CA certificate
├── /v1/pki_int/ca/pem                  # Intermediate CA certificate
├── /v1/pki_int/roles/postgres-role     # PostgreSQL certificate role
├── /v1/pki_int/issue/postgres-role     # Issue PostgreSQL certificate
└── /v1/secret/data/postgres            # PostgreSQL credentials
```

**Credential Loading for Non-Container Services:**

For services that need Vault credentials but aren't containerized (e.g., PgBouncer, Forgejo), credentials are loaded via environment variables:

**Script: `scripts/load-vault-env.sh`**

This script loads credentials from Vault into environment variables for docker-compose:

```bash
#!/bin/bash
# Load credentials from Vault and export as environment variables

# 1. Wait for Vault to be ready
# 2. Read VAULT_TOKEN from ~/.config/vault/root-token
# 3. Fetch PostgreSQL password: secret/postgres
# 4. Export POSTGRES_PASSWORD for docker-compose

export POSTGRES_PASSWORD=$(python3 scripts/read-vault-secret.py postgres password)
```

**Script: `scripts/read-vault-secret.py`**

Python helper to read secrets from Vault KV v2 API:

```python
#!/usr/bin/env python3
# Usage: read-vault-secret.py <path> <field>
# Example: read-vault-secret.py postgres password

import sys, json, urllib.request, os

vault_addr = os.getenv('VAULT_ADDR', 'http://localhost:8200')
vault_token = os.getenv('VAULT_TOKEN')

url = f"{vault_addr}/v1/secret/data/{sys.argv[1]}"
req = urllib.request.Request(url)
req.add_header('X-Vault-Token', vault_token)

with urllib.request.urlopen(req) as response:
    data = json.loads(response.read().decode())
    print(data['data']['data'][sys.argv[2]])
```

**When Credentials Are Loaded:**

The `manage-colima.sh` script automatically loads credentials during startup:

1. Start Vault container
2. Wait 5 seconds for Vault to be ready
3. Run `source scripts/load-vault-env.sh`
4. Export credentials as environment variables
5. Start remaining services with injected credentials

**All Services Are Now Vault-Integrated:**

✅ All database services (PostgreSQL, MySQL, MongoDB)
✅ All caching services (Redis Cluster)
✅ All message queue services (RabbitMQ)
✅ All connection pooling services (PgBouncer)

No migration needed - the infrastructure is complete!

## Vault Auto-Unseal

### How It Works

Vault runs in two concurrent processes within the container:

```
Container: dev-vault
├── Process 1: vault server
│   - Listens on 0.0.0.0:8200
│   - Uses file storage: /vault/data
│   - Config: /vault/config/vault.hcl
│
└── Process 2: vault-auto-unseal.sh
    - Waits for Vault to be ready
    - Unseals using saved keys
    - Sleeps indefinitely (no CPU overhead)
```

**Entrypoint** (`docker-compose.yml:360-366`):
```yaml
entrypoint: >
  sh -c "
  chown -R vault:vault /vault/data &&
  docker-entrypoint.sh server &
  /usr/local/bin/vault-auto-unseal.sh &
  wait -n
  "
```

**Process Flow:**
1. Fix `/vault/data` permissions (chown)
2. Start Vault server in background (`&`)
3. Start auto-unseal script in background (`&`)
4. Wait for either process to exit (`wait -n`)

### Initial Setup

**First-Time Initialization:**
```bash
./configs/vault/scripts/vault-init.sh
# Or
./manage-colima.sh vault-init
```

**What Happens:**
1. Waits for Vault to be ready (max 30 seconds)
2. Checks if already initialized
3. If not initialized:
   - POSTs to `/v1/sys/init` with `{"secret_shares": 5, "secret_threshold": 3}`
   - Receives 5 unseal keys + root token
   - Saves to `~/.config/vault/keys.json` (chmod 600)
   - Saves root token to `~/.config/vault/root-token` (chmod 600)
4. Unseals Vault using 3 of 5 keys
5. Displays status and root token

**Shamir Secret Sharing:**
- 5 keys generated
- Any 3 keys can unseal Vault
- Designed for distributed trust (give keys to different people/systems)
- Lost keys = cannot unseal (data is encrypted and unrecoverable)

### Auto-Unseal Process

**Script** (`configs/vault/scripts/vault-auto-unseal.sh`):

```bash
# 1. Wait for Vault API (max 30 attempts, 1s each)
wget --spider http://127.0.0.1:8200/v1/sys/health?uninitcode=200&sealedcode=200

# 2. Check seal status
wget -qO- http://127.0.0.1:8200/v1/sys/seal-status
# → {"sealed": true}

# 3. Read unseal keys from mounted volume
cat /vault-keys/keys.json | extract 3 keys

# 4. POST each key to unseal endpoint
for key in key1 key2 key3; do
  wget --post-data='{"key":"'$key'"}' http://127.0.0.1:8200/v1/sys/unseal
done

# 5. Verify unsealed
wget -qO- http://127.0.0.1:8200/v1/sys/seal-status
# → {"sealed": false}

# 6. Sleep indefinitely (no monitoring overhead)
while true; do sleep 3600; done
```

**Why Not Continuous Monitoring?**
- Original design had 10-second checks (360 API calls/hour)
- Optimized to single unseal + sleep
- Saves 99% of API calls and CPU cycles
- Trade-off: Won't auto-reseal if manually sealed (must restart container)

### Manual Operations

**Check Vault Status:**
```bash
./manage-colima.sh vault-status

# Or directly
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)
vault status
```

**Manually Unseal:**
```bash
./manage-colima.sh vault-unseal

# Or using vault CLI
vault operator unseal  # Repeat 3 times with different keys
```

**Seal Vault:**
```bash
vault operator seal
# Note: Won't auto-reseal until container restarts
```

**Rotate Root Token:**
```bash
vault token create -policy=root
# Save new token to ~/.config/vault/root-token
```

**Backup Unseal Keys:**
```bash
# Encrypt and backup
tar czf vault-keys-$(date +%Y%m%d).tar.gz ~/.config/vault/
gpg -c vault-keys-*.tar.gz
# Store encrypted file in secure location (1Password, etc.)
```

