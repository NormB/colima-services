# Secrets Rotation

Comprehensive guide to rotating secrets, credentials, and certificates in the Colima Services environment.

## Table of Contents

- [Overview](#overview)
- [Why Rotate Secrets](#why-rotate-secrets)
  - [Security Best Practices](#security-best-practices)
  - [Compliance Requirements](#compliance-requirements)
  - [Incident Response](#incident-response)
- [Rotation Strategy](#rotation-strategy)
  - [Rotation Schedule](#rotation-schedule)
  - [Zero-Downtime Rotation](#zero-downtime-rotation)
  - [Rotation Planning](#rotation-planning)
- [Database Password Rotation](#database-password-rotation)
  - [PostgreSQL Password Rotation](#postgresql-password-rotation)
  - [MySQL Password Rotation](#mysql-password-rotation)
  - [MongoDB Password Rotation](#mongodb-password-rotation)
- [RabbitMQ Credential Rotation](#rabbitmq-credential-rotation)
  - [User Password Updates](#user-password-updates)
  - [Vhost Configuration](#vhost-configuration)
- [Redis Password Rotation](#redis-password-rotation)
  - [Single Instance Rotation](#single-instance-rotation)
  - [Cluster-Wide Password Updates](#cluster-wide-password-updates)
- [Certificate Rotation](#certificate-rotation)
  - [TLS Certificate Renewal](#tls-certificate-renewal)
  - [Vault PKI Certificate Rotation](#vault-pki-certificate-rotation)
  - [Service Certificate Updates](#service-certificate-updates)
- [Vault Token Rotation](#vault-token-rotation)
  - [Root Token Handling](#root-token-handling)
  - [Service Token Rotation](#service-token-rotation)
- [API Key Rotation](#api-key-rotation)
  - [Application API Keys](#application-api-keys)
  - [Service Credentials](#service-credentials)
- [Testing After Rotation](#testing-after-rotation)
  - [Verification Procedures](#verification-procedures)
  - [Health Checks](#health-checks)
  - [Rollback Plans](#rollback-plans)
- [Automation](#automation)
  - [Scripting Rotation Procedures](#scripting-rotation-procedures)
  - [Scheduled Rotation](#scheduled-rotation)
  - [Monitoring Rotation Status](#monitoring-rotation-status)
- [Troubleshooting](#troubleshooting)
  - [Failed Rotations](#failed-rotations)
  - [Service Connectivity Issues](#service-connectivity-issues)
  - [Authentication Errors](#authentication-errors)
- [Best Practices](#best-practices)
- [Reference](#reference)

## Overview

Secrets rotation is the practice of regularly changing passwords, credentials, and certificates to maintain security. This guide covers rotating all secrets in the Colima Services environment using Vault as the central secrets management system.

**Key Principles:**
- **Vault-first:** All secrets stored in Vault, services fetch at startup
- **Zero-downtime:** Rotate secrets without service interruption
- **Atomic updates:** Update Vault, then restart services (services always use latest)
- **Verification:** Test connectivity after every rotation
- **Documentation:** Log all rotation activities

**Related Pages:**
- [Vault Integration](Vault-Integration) - Vault secrets management
- [Certificate Management](Certificate-Management) - Certificate lifecycle
- [Security Hardening](Security-Hardening) - Security best practices
- [Service Configuration](Service-Configuration) - Service details

## Why Rotate Secrets

### Security Best Practices

**Limit exposure window:**
- Compromised credentials have limited lifetime
- Reduces impact of credential leaks
- Prevents long-term unauthorized access

**Compliance:**
- Many security standards require periodic rotation
- PCI-DSS: 90-day password rotation
- SOC 2: Regular credential rotation policies
- HIPAA: Access credential reviews

**Defense in depth:**
- Regular rotation complements other security measures
- Reduces risk from undetected breaches
- Makes stolen credentials expire naturally

### Compliance Requirements

**Common rotation requirements:**

| Standard | Requirement | Recommended Frequency |
|----------|-------------|----------------------|
| PCI-DSS | User passwords every 90 days | Quarterly |
| SOC 2 | Documented rotation policy | Quarterly to Annual |
| HIPAA | Regular access reviews | Annual minimum |
| ISO 27001 | Credential lifecycle management | Risk-based |
| NIST 800-53 | Periodic password changes | 60-90 days |

**Colima Services Recommendations:**
- **Development:** Annual rotation (low risk)
- **Staging:** Quarterly rotation (moderate risk)
- **Production:** Monthly to Quarterly (high risk)

### Incident Response

**When to rotate immediately:**

1. **Suspected breach:**
   - Unauthorized access detected
   - Credential exposure in logs
   - Security incident involving credentials

2. **Personnel changes:**
   - Developer leaves team
   - Contractor access ends
   - Role changes requiring different access

3. **System compromise:**
   - Container breach
   - Host system compromise
   - Network intrusion

4. **Accidental exposure:**
   - Credentials committed to Git
   - Credentials in Slack/email
   - Credentials in error messages/logs

**Incident rotation procedure:**

```bash
# 1. Identify exposed credentials
echo "Compromised: PostgreSQL password"

# 2. Rotate immediately (see procedures below)
./scripts/rotate-postgres-password.sh

# 3. Audit access logs
docker exec dev-postgres psql -U postgres -c "
SELECT datname, usename, client_addr, query_start, query
FROM pg_stat_activity
WHERE usename = 'postgres'
ORDER BY query_start DESC;
"

# 4. Review for unauthorized activity
# 5. Document incident and rotation
echo "$(date): Rotated PostgreSQL password due to incident #123" >> rotation.log
```

## Rotation Strategy

### Rotation Schedule

**Recommended rotation schedule:**

```bash
# Annual rotation (development environment)
# - Database passwords: January 1st
# - Service certificates: 60 days before expiration
# - Vault root token: January 1st (if needed)
# - RabbitMQ passwords: January 1st
# - Redis passwords: January 1st

# Quarterly rotation (production environment)
# Q1: January 1st
# Q2: April 1st
# Q3: July 1st
# Q4: October 1st
```

**Rotation calendar:**

```
January (Q1):
├── Week 1: Plan rotations, test procedures
├── Week 2: Rotate certificates (if needed)
├── Week 3: Rotate database passwords
└── Week 4: Rotate service credentials, verify all systems

April (Q2): Repeat
July (Q3): Repeat
October (Q4): Repeat
```

### Zero-Downtime Rotation

**Vault-based rotation enables zero-downtime:**

1. **Update secret in Vault** (new password)
2. **Services continue using old password** (until restarted)
3. **Restart services one by one** (fetch new password from Vault)
4. **Verify each service** before proceeding to next

**Process:**

```bash
# 1. Update Vault secret (doesn't affect running services)
vault kv put secret/postgres password="new_password"

# 2. Restart services in dependency order
docker restart dev-postgres
# Wait for health check
sleep 10

docker restart dev-pgbouncer
# Wait for health check
sleep 5

docker restart reference-api
# Verify connectivity
curl http://localhost:8000/health

# 3. All services now use new password
```

### Rotation Planning

**Pre-rotation checklist:**

- [ ] **Backup current secrets** (Vault snapshot)
- [ ] **Test procedures** in non-production environment
- [ ] **Schedule maintenance window** (optional, for safety)
- [ ] **Notify team** of rotation schedule
- [ ] **Prepare rollback plan** (old passwords documented)
- [ ] **Document expected downtime** (usually zero)
- [ ] **Verify monitoring/alerting** is active

**Rotation execution checklist:**

- [ ] Update secret in Vault
- [ ] Update database/service password
- [ ] Restart dependent services
- [ ] Verify connectivity for each service
- [ ] Run health checks
- [ ] Check application functionality
- [ ] Update documentation
- [ ] Log rotation completion

**Post-rotation checklist:**

- [ ] Verify all services healthy
- [ ] Run full test suite
- [ ] Monitor for 24 hours
- [ ] Document any issues
- [ ] Secure old credentials (delete backups after 30 days)

## Database Password Rotation

### PostgreSQL Password Rotation

**Complete procedure for rotating PostgreSQL password:**

#### Step 1: Backup Current Password

```bash
# Get current password from Vault
export OLD_PASSWORD=$(vault kv get -field=password secret/postgres)
echo "Old password backed up: $OLD_PASSWORD" > /tmp/postgres-rotation-$(date +%Y%m%d).log

# Backup Vault secret
vault kv get -format=json secret/postgres > /tmp/postgres-secret-backup-$(date +%Y%m%d).json
```

#### Step 2: Generate New Password

```bash
# Generate secure random password
NEW_PASSWORD=$(openssl rand -base64 32)
echo "New password generated: $NEW_PASSWORD"

# Or use specific password
NEW_PASSWORD="YourSecurePassword123!"
```

#### Step 3: Update Vault Secret

```bash
# Update password in Vault
vault kv put secret/postgres password="$NEW_PASSWORD"

# Verify update
vault kv get secret/postgres
```

#### Step 4: Update PostgreSQL Password

```bash
# Connect to PostgreSQL and change password
docker exec -e PGPASSWORD=$OLD_PASSWORD dev-postgres psql -U postgres -c "
ALTER USER postgres WITH PASSWORD '$NEW_PASSWORD';
"

# Verify password changed
echo "PostgreSQL password updated"
```

#### Step 5: Restart Services

```bash
# Restart PostgreSQL (picks up new password from Vault)
docker restart dev-postgres

# Wait for PostgreSQL to be healthy
sleep 10
docker exec dev-postgres pg_isready -U postgres

# Restart PgBouncer
docker restart dev-pgbouncer
sleep 5

# Restart applications
docker restart reference-api api-first
sleep 5
```

#### Step 6: Verify Connectivity

```bash
# Test PostgreSQL connection with new password
export PGPASSWORD=$NEW_PASSWORD
docker exec -e PGPASSWORD=$NEW_PASSWORD dev-postgres psql -U postgres -c "SELECT version();"

# Test PgBouncer connection
docker exec -e PGPASSWORD=$NEW_PASSWORD dev-postgres psql -h pgbouncer -p 6432 -U postgres -c "SELECT 1;"

# Test application connectivity
curl http://localhost:8000/api/postgres/health
curl http://localhost:8001/api/postgres/health

# Check for errors in logs
docker logs dev-postgres --tail 20
docker logs dev-pgbouncer --tail 20
docker logs reference-api --tail 20
```

#### Complete Rotation Script

```bash
#!/bin/bash
# Save as: /Users/gator/colima-services/scripts/rotate-postgres-password.sh

set -e

echo "=== PostgreSQL Password Rotation ==="
echo "Started: $(date)"

# Vault configuration
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# Backup current password
OLD_PASSWORD=$(vault kv get -field=password secret/postgres)
echo "Current password backed up"

# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)
echo "New password generated"

# Update Vault
vault kv put secret/postgres password="$NEW_PASSWORD"
echo "Vault secret updated"

# Update PostgreSQL
docker exec -e PGPASSWORD=$OLD_PASSWORD dev-postgres psql -U postgres -c "ALTER USER postgres WITH PASSWORD '$NEW_PASSWORD';"
echo "PostgreSQL password updated"

# Restart services
echo "Restarting services..."
docker restart dev-postgres
sleep 10

docker restart dev-pgbouncer
sleep 5

docker restart reference-api api-first
sleep 5

# Verify
echo "Verifying connectivity..."
export PGPASSWORD=$NEW_PASSWORD
docker exec -e PGPASSWORD=$NEW_PASSWORD dev-postgres psql -U postgres -c "SELECT 1;" > /dev/null
echo "✓ PostgreSQL connection verified"

docker exec -e PGPASSWORD=$NEW_PASSWORD dev-postgres psql -h pgbouncer -p 6432 -U postgres -c "SELECT 1;" > /dev/null
echo "✓ PgBouncer connection verified"

curl -s http://localhost:8000/api/postgres/health > /dev/null
echo "✓ Application connectivity verified"

echo "=== Rotation Complete ==="
echo "Finished: $(date)"
echo "Log: Rotated PostgreSQL password" >> ~/rotation.log
```

**Make script executable and run:**

```bash
chmod +x /Users/gator/colima-services/scripts/rotate-postgres-password.sh
./scripts/rotate-postgres-password.sh
```

### MySQL Password Rotation

**Procedure:**

```bash
#!/bin/bash
# Rotate MySQL password

# Backup current password
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)
OLD_PASSWORD=$(vault kv get -field=password secret/mysql)

# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update Vault
vault kv put secret/mysql password="$NEW_PASSWORD"

# Update MySQL
docker exec -e MYSQL_PWD=$OLD_PASSWORD dev-mysql mysql -u root -e "
ALTER USER 'root'@'%' IDENTIFIED BY '$NEW_PASSWORD';
ALTER USER 'root'@'localhost' IDENTIFIED BY '$NEW_PASSWORD';
FLUSH PRIVILEGES;
"

# Restart MySQL
docker restart dev-mysql
sleep 10

# Verify
docker exec -e MYSQL_PWD=$NEW_PASSWORD dev-mysql mysql -u root -e "SELECT 1;" > /dev/null
echo "✓ MySQL password rotated successfully"
```

### MongoDB Password Rotation

**Procedure:**

```bash
#!/bin/bash
# Rotate MongoDB password

# Backup current password
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)
OLD_PASSWORD=$(vault kv get -field=password secret/mongodb)

# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update Vault
vault kv put secret/mongodb password="$NEW_PASSWORD"

# Update MongoDB
docker exec dev-mongodb mongosh -u root -p "$OLD_PASSWORD" --authenticationDatabase admin --eval "
db.getSiblingDB('admin').updateUser('root', {
    pwd: '$NEW_PASSWORD'
});
"

# Restart MongoDB
docker restart dev-mongodb
sleep 10

# Verify
docker exec dev-mongodb mongosh -u root -p "$NEW_PASSWORD" --authenticationDatabase admin --eval "db.adminCommand('ping')" > /dev/null
echo "✓ MongoDB password rotated successfully"
```

## RabbitMQ Credential Rotation

### User Password Updates

**Rotating RabbitMQ admin password:**

```bash
#!/bin/bash
# Rotate RabbitMQ password

# Backup current password
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)
OLD_PASSWORD=$(vault kv get -field=password secret/rabbitmq)

# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update Vault
vault kv put secret/rabbitmq password="$NEW_PASSWORD"

# Update RabbitMQ
docker exec dev-rabbitmq rabbitmqctl change_password admin "$NEW_PASSWORD"

# Restart RabbitMQ
docker restart dev-rabbitmq
sleep 15

# Verify
docker exec dev-rabbitmq rabbitmqctl authenticate_user admin "$NEW_PASSWORD"
echo "✓ RabbitMQ password rotated successfully"

# Verify via HTTP API
curl -u admin:$NEW_PASSWORD http://localhost:15672/api/overview > /dev/null
echo "✓ RabbitMQ HTTP API verified"
```

**Rotating application user passwords:**

```bash
# Create or update application user
docker exec dev-rabbitmq rabbitmqctl add_user myapp_user "$NEW_PASSWORD" || \
docker exec dev-rabbitmq rabbitmqctl change_password myapp_user "$NEW_PASSWORD"

# Set permissions
docker exec dev-rabbitmq rabbitmqctl set_permissions -p / myapp_user ".*" ".*" ".*"

# Update Vault
vault kv put secret/rabbitmq-app username="myapp_user" password="$NEW_PASSWORD"

# Restart applications using this credential
docker restart reference-api
```

### Vhost Configuration

**If vhost credentials change:**

```bash
# List current vhosts
docker exec dev-rabbitmq rabbitmqctl list_vhosts

# Update user permissions for vhost
docker exec dev-rabbitmq rabbitmqctl set_permissions -p /myapp myapp_user ".*" ".*" ".*"

# Verify permissions
docker exec dev-rabbitmq rabbitmqctl list_user_permissions myapp_user
```

## Redis Password Rotation

### Single Instance Rotation

**For single Redis instance:**

```bash
#!/bin/bash
# Rotate Redis password (single instance)

# Backup current password
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)
OLD_PASSWORD=$(vault kv get -field=password secret/redis-1)

# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update Vault
vault kv put secret/redis-1 password="$NEW_PASSWORD"

# Update Redis configuration and restart
docker exec dev-redis-1 redis-cli -a "$OLD_PASSWORD" CONFIG SET requirepass "$NEW_PASSWORD"

# Restart Redis
docker restart dev-redis-1
sleep 5

# Verify
docker exec dev-redis-1 redis-cli -a "$NEW_PASSWORD" PING
echo "✓ Redis password rotated successfully"
```

### Cluster-Wide Password Updates

**For Redis cluster (all nodes must have same password):**

```bash
#!/bin/bash
# Rotate Redis Cluster password

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# Backup current password
OLD_PASSWORD=$(vault kv get -field=password secret/redis-1)

# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update Vault secret (shared by all nodes)
vault kv put secret/redis-1 password="$NEW_PASSWORD"

echo "Rotating password for Redis cluster..."

# Update each node
for NODE in redis-1 redis-2 redis-3; do
    echo "Updating dev-$NODE..."

    # Set new password in running instance
    docker exec dev-$NODE redis-cli -a "$OLD_PASSWORD" CONFIG SET requirepass "$NEW_PASSWORD"

    # Restart node to apply changes
    docker restart dev-$NODE
    sleep 5

    # Verify
    docker exec dev-$NODE redis-cli -a "$NEW_PASSWORD" PING
    echo "✓ dev-$NODE updated"
done

# Verify cluster status
docker exec dev-redis-1 redis-cli -a "$NEW_PASSWORD" CLUSTER INFO

# Restart applications
echo "Restarting applications..."
docker restart reference-api api-first
sleep 5

# Verify application connectivity
curl http://localhost:8000/api/redis/health
echo "✓ Redis cluster password rotation complete"
```

**Verify cluster after rotation:**

```bash
# Check cluster status
docker exec dev-redis-1 redis-cli -a "$NEW_PASSWORD" CLUSTER NODES

# Test operations
docker exec dev-redis-1 redis-cli -a "$NEW_PASSWORD" SET test_key "test_value"
docker exec dev-redis-1 redis-cli -a "$NEW_PASSWORD" GET test_key

# Test from application
curl http://localhost:8000/api/redis/set/test_key/test_value
curl http://localhost:8000/api/redis/get/test_key
```

## Certificate Rotation

### TLS Certificate Renewal

**When to renew certificates:**
- **60 days before expiration** (recommended)
- **90 days before expiration** (conservative)
- **After security incident** (immediate)

**Check certificate expiration:**

```bash
# Check certificate expiration dates
for SERVICE in postgres mysql redis-1 redis-2 redis-3 rabbitmq mongodb; do
    echo "=== $SERVICE ==="
    openssl x509 -in ~/.config/vault/certs/$SERVICE/cert.pem -noout -dates
done

# Check days until expiration
for SERVICE in postgres mysql redis-1 redis-2 redis-3 rabbitmq mongodb; do
    EXPIRY=$(openssl x509 -in ~/.config/vault/certs/$SERVICE/cert.pem -noout -enddate | cut -d= -f2)
    EXPIRY_EPOCH=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$EXPIRY" +%s)
    NOW_EPOCH=$(date +%s)
    DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))
    echo "$SERVICE: $DAYS_LEFT days until expiration"
done
```

### Vault PKI Certificate Rotation

**Renewing all service certificates:**

```bash
#!/bin/bash
# Rotate all service certificates

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

echo "=== Certificate Rotation ==="
echo "Started: $(date)"

# Regenerate all certificates using existing script
./scripts/generate-certificates.sh

echo "Certificates regenerated. Restarting services..."

# Restart services to pick up new certificates
for SERVICE in postgres mysql redis-1 redis-2 redis-3 rabbitmq mongodb; do
    echo "Restarting dev-$SERVICE..."
    docker restart dev-$SERVICE
    sleep 5
done

echo "Restarting applications..."
docker restart reference-api api-first
sleep 5

echo "=== Verification ==="

# Verify certificate dates
for SERVICE in postgres mysql redis-1 redis-2 redis-3 rabbitmq mongodb; do
    echo "--- $SERVICE ---"
    openssl x509 -in ~/.config/vault/certs/$SERVICE/cert.pem -noout -dates
done

echo "=== Certificate Rotation Complete ==="
echo "Finished: $(date)"
```

### Service Certificate Updates

**Rotating certificate for specific service (PostgreSQL example):**

```bash
#!/bin/bash
# Rotate PostgreSQL certificate

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

SERVICE="postgres"
CERT_DIR="$HOME/.config/vault/certs/$SERVICE"

# Backup current certificate
mkdir -p "$CERT_DIR/backup"
cp "$CERT_DIR/cert.pem" "$CERT_DIR/backup/cert-$(date +%Y%m%d).pem"
cp "$CERT_DIR/key.pem" "$CERT_DIR/backup/key-$(date +%Y%m%d).pem"

# Generate new certificate
vault write -format=json pki_int/issue/postgres-role \
    common_name="postgres.dev-services.local" \
    ttl="8760h" \
    | jq -r '.data.certificate' > "$CERT_DIR/cert.pem"

vault write -format=json pki_int/issue/postgres-role \
    common_name="postgres.dev-services.local" \
    ttl="8760h" \
    | jq -r '.data.private_key' > "$CERT_DIR/key.pem"

vault write -format=json pki_int/issue/postgres-role \
    common_name="postgres.dev-services.local" \
    ttl="8760h" \
    | jq -r '.data.ca_chain[]' > "$CERT_DIR/ca.pem"

# Set permissions
chmod 600 "$CERT_DIR/key.pem"
chmod 644 "$CERT_DIR/cert.pem"
chmod 644 "$CERT_DIR/ca.pem"

# Restart PostgreSQL
docker restart dev-postgres
sleep 10

# Verify
openssl x509 -in "$CERT_DIR/cert.pem" -noout -dates
echo "✓ PostgreSQL certificate rotated"

# Test TLS connection
docker exec dev-postgres psql -h postgres -p 5432 -U postgres -c "SELECT version();"
echo "✓ TLS connection verified"
```

## Vault Token Rotation

### Root Token Handling

**⚠️ WARNING:** Root token rotation is sensitive. Only rotate if compromised.

**Rotating Vault root token:**

```bash
#!/bin/bash
# Rotate Vault root token (emergency procedure)

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

echo "=== Vault Root Token Rotation ==="
echo "⚠️  WARNING: This is a sensitive operation"
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted"
    exit 1
fi

# Generate new root token
# Method 1: Using operator generate-root (requires unseal keys)
vault operator generate-root -init
# Follow prompts with unseal keys

# Method 2: Create new token with root policy (if current root token valid)
NEW_ROOT_TOKEN=$(vault token create -policy=root -format=json | jq -r '.auth.client_token')

# Test new token
VAULT_TOKEN=$NEW_ROOT_TOKEN vault token lookup

# Backup old token
echo "Old root token: $(cat ~/.config/vault/root-token)" > ~/vault-old-token-$(date +%Y%m%d).txt
chmod 600 ~/vault-old-token-$(date +%Y%m%d).txt

# Update stored token
echo "$NEW_ROOT_TOKEN" > ~/.config/vault/root-token

# Update environment variable in scripts
export VAULT_TOKEN=$NEW_ROOT_TOKEN

# Revoke old token (after verifying new token works)
vault token revoke $(cat ~/vault-old-token-$(date +%Y%m%d).txt)

echo "✓ Root token rotated successfully"
echo "⚠️  Update VAULT_TOKEN in all scripts and .env files"
```

### Service Token Rotation

**For applications using Vault tokens (not root):**

```bash
# Create application token
APP_TOKEN=$(vault token create -policy=app-policy -ttl=720h -format=json | jq -r '.auth.client_token')

# Update application configuration
vault kv put secret/app-credentials vault_token="$APP_TOKEN"

# Restart application
docker restart reference-api

# Revoke old token (after verification)
vault token revoke $OLD_APP_TOKEN
```

## API Key Rotation

### Application API Keys

**For API keys stored in Vault:**

```bash
#!/bin/bash
# Rotate application API key

# Generate new API key
NEW_API_KEY=$(openssl rand -hex 32)

# Update Vault
vault kv put secret/api-keys/myapp api_key="$NEW_API_KEY"

# Update application configuration
# Applications fetch from Vault on startup

# Restart application
docker restart reference-api

# Verify
curl -H "X-API-Key: $NEW_API_KEY" http://localhost:8000/api/protected
echo "✓ API key rotated successfully"
```

### Service Credentials

**For inter-service authentication:**

```bash
# Generate new credentials
NEW_CLIENT_ID=$(uuidgen)
NEW_CLIENT_SECRET=$(openssl rand -base64 48)

# Update Vault
vault kv put secret/service-credentials/api \
    client_id="$NEW_CLIENT_ID" \
    client_secret="$NEW_CLIENT_SECRET"

# Restart services
docker restart api-first reference-api
sleep 5

# Verify inter-service communication
curl http://localhost:8000/api/external/test
```

## Testing After Rotation

### Verification Procedures

**Post-rotation verification checklist:**

```bash
#!/bin/bash
# Complete verification suite after rotation

echo "=== Post-Rotation Verification ==="

# 1. Check all services are running
echo "1. Checking service status..."
docker ps --filter "name=dev-" --format "table {{.Names}}\t{{.Status}}"

# 2. Test database connections
echo "2. Testing database connections..."
docker exec dev-postgres psql -U postgres -c "SELECT 1;" > /dev/null && echo "✓ PostgreSQL"
docker exec dev-mysql mysql -u root -e "SELECT 1;" > /dev/null && echo "✓ MySQL"
docker exec dev-mongodb mongosh -u root --authenticationDatabase admin --eval "db.adminCommand('ping')" > /dev/null && echo "✓ MongoDB"

# 3. Test cache connections
echo "3. Testing cache connections..."
docker exec dev-redis-1 redis-cli PING > /dev/null && echo "✓ Redis"

# 4. Test message queue
echo "4. Testing message queue..."
docker exec dev-rabbitmq rabbitmqctl status > /dev/null && echo "✓ RabbitMQ"

# 5. Test application endpoints
echo "5. Testing application endpoints..."
curl -s http://localhost:8000/health > /dev/null && echo "✓ FastAPI reference app"
curl -s http://localhost:8001/health > /dev/null && echo "✓ FastAPI API-first app"

# 6. Test database operations
echo "6. Testing database operations..."
curl -s http://localhost:8000/api/postgres/users > /dev/null && echo "✓ PostgreSQL operations"

# 7. Test Redis operations
echo "7. Testing Redis operations..."
curl -s http://localhost:8000/api/redis/set/test/value > /dev/null && echo "✓ Redis write"
curl -s http://localhost:8000/api/redis/get/test > /dev/null && echo "✓ Redis read"

# 8. Test RabbitMQ operations
echo "8. Testing RabbitMQ operations..."
curl -s http://localhost:8000/api/rabbitmq/publish > /dev/null && echo "✓ RabbitMQ publish"

echo "=== Verification Complete ==="
```

### Health Checks

```bash
# Run comprehensive health checks
./manage-colima.sh health

# Check specific services
docker exec dev-postgres pg_isready -U postgres
docker exec dev-mysql mysqladmin ping -u root
docker exec dev-mongodb mongosh -u root --authenticationDatabase admin --eval "db.adminCommand('ping')"
docker exec dev-redis-1 redis-cli PING
docker exec dev-rabbitmq rabbitmqctl node_health_check
```

### Rollback Plans

**If rotation fails, rollback immediately:**

```bash
#!/bin/bash
# Rollback rotation (PostgreSQL example)

echo "=== Rolling Back PostgreSQL Password Rotation ==="

# Retrieve old password from backup
OLD_PASSWORD=$(cat /tmp/postgres-rotation-$(date +%Y%m%d).log | grep "Old password" | cut -d: -f2 | tr -d ' ')

# Update Vault with old password
vault kv put secret/postgres password="$OLD_PASSWORD"

# Update PostgreSQL
docker exec dev-postgres psql -U postgres -c "ALTER USER postgres WITH PASSWORD '$OLD_PASSWORD';"

# Restart services
docker restart dev-postgres dev-pgbouncer reference-api api-first
sleep 10

# Verify
export PGPASSWORD=$OLD_PASSWORD
docker exec -e PGPASSWORD=$OLD_PASSWORD dev-postgres psql -U postgres -c "SELECT 1;"

echo "✓ Rollback complete"
echo "⚠️  Investigate rotation failure before retrying"
```

## Automation

### Scripting Rotation Procedures

**Master rotation script:**

```bash
#!/bin/bash
# Save as: /Users/gator/colima-services/scripts/rotate-all-secrets.sh

set -e

echo "=== Colima Services - Complete Secrets Rotation ==="
echo "Started: $(date)"

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# Create rotation log
ROTATION_LOG=~/rotation-$(date +%Y%m%d-%H%M%S).log
echo "Rotation started: $(date)" > $ROTATION_LOG

# Backup Vault secrets
echo "Backing up Vault secrets..."
mkdir -p ~/vault-backups
vault kv get -format=json secret/ > ~/vault-backups/secrets-$(date +%Y%m%d).json

# Rotate PostgreSQL
echo "Rotating PostgreSQL password..."
./scripts/rotate-postgres-password.sh | tee -a $ROTATION_LOG

# Rotate MySQL
echo "Rotating MySQL password..."
./scripts/rotate-mysql-password.sh | tee -a $ROTATION_LOG

# Rotate MongoDB
echo "Rotating MongoDB password..."
./scripts/rotate-mongodb-password.sh | tee -a $ROTATION_LOG

# Rotate Redis cluster
echo "Rotating Redis cluster password..."
./scripts/rotate-redis-cluster-password.sh | tee -a $ROTATION_LOG

# Rotate RabbitMQ
echo "Rotating RabbitMQ password..."
./scripts/rotate-rabbitmq-password.sh | tee -a $ROTATION_LOG

# Rotate certificates (if within 60 days of expiration)
echo "Checking certificate expiration..."
./scripts/check-certificate-expiration.sh | tee -a $ROTATION_LOG

# Run verification suite
echo "Running verification suite..."
./scripts/verify-rotation.sh | tee -a $ROTATION_LOG

echo "=== Rotation Complete ==="
echo "Finished: $(date)"
echo "Log: $ROTATION_LOG"
```

### Scheduled Rotation

**Using cron for automated rotation:**

```bash
# Edit crontab
crontab -e

# Add rotation schedule (quarterly: January 1, April 1, July 1, October 1 at 2 AM)
0 2 1 1,4,7,10 * /Users/gator/colima-services/scripts/rotate-all-secrets.sh >> ~/rotation.log 2>&1

# Or monthly (1st of each month at 2 AM)
0 2 1 * * /Users/gator/colima-services/scripts/rotate-all-secrets.sh >> ~/rotation.log 2>&1

# Certificate rotation (every 60 days)
0 3 */60 * * /Users/gator/colima-services/scripts/rotate-certificates.sh >> ~/cert-rotation.log 2>&1
```

**Notification on completion:**

```bash
# Add to rotation script
if [ $? -eq 0 ]; then
    echo "✓ Rotation successful" | mail -s "Secrets Rotation Complete" admin@example.com
else
    echo "✗ Rotation failed" | mail -s "Secrets Rotation FAILED" admin@example.com
fi
```

### Monitoring Rotation Status

**Checking rotation history:**

```bash
# View rotation log
cat ~/rotation.log

# Check last rotation date
tail -1 ~/rotation.log

# Check certificate expiration dates
./scripts/check-certificate-expiration.sh
```

**Certificate expiration monitoring script:**

```bash
#!/bin/bash
# Save as: /Users/gator/colima-services/scripts/check-certificate-expiration.sh

echo "=== Certificate Expiration Report ==="
echo "Generated: $(date)"
echo ""

for SERVICE in postgres mysql redis-1 redis-2 redis-3 rabbitmq mongodb; do
    CERT_FILE="$HOME/.config/vault/certs/$SERVICE/cert.pem"

    if [ -f "$CERT_FILE" ]; then
        EXPIRY=$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
        EXPIRY_EPOCH=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$EXPIRY" +%s)
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))

        if [ $DAYS_LEFT -lt 60 ]; then
            echo "⚠️  $SERVICE: $DAYS_LEFT days (RENEWAL RECOMMENDED)"
        elif [ $DAYS_LEFT -lt 90 ]; then
            echo "⚡ $SERVICE: $DAYS_LEFT days (renewal soon)"
        else
            echo "✓  $SERVICE: $DAYS_LEFT days"
        fi
    else
        echo "✗  $SERVICE: Certificate not found"
    fi
done
```

## Troubleshooting

### Failed Rotations

**Common failure scenarios:**

#### 1. Vault Secret Updated, Service Restart Failed

```bash
# Problem: Vault has new password, but service still using old password
# Solution: Manually restart service

# Check Vault secret
vault kv get secret/postgres

# Check service is using old password (connection fails)
docker exec dev-postgres psql -U postgres -c "SELECT 1;"

# Restart service to fetch new password
docker restart dev-postgres
sleep 10

# Verify
docker exec dev-postgres psql -U postgres -c "SELECT 1;"
```

#### 2. Service Password Updated, Vault Not Updated

```bash
# Problem: Service has new password, but Vault has old password
# Solution: Update Vault or revert service password

# Option 1: Update Vault to match service
vault kv put secret/postgres password="<current_service_password>"

# Option 2: Revert service password
docker exec dev-postgres psql -U postgres -c "ALTER USER postgres WITH PASSWORD '<vault_password>';"
```

#### 3. Partial Rotation (Some Services Updated, Others Not)

```bash
# Check which services are using new password
for SERVICE in dev-postgres dev-pgbouncer reference-api; do
    docker logs $SERVICE --tail 20 | grep -i "authentication\|password"
done

# Restart services that failed to pick up new password
docker restart dev-pgbouncer reference-api
```

### Service Connectivity Issues

**After rotation, service cannot connect:**

```bash
# 1. Verify password in Vault
vault kv get secret/postgres

# 2. Check service logs for auth errors
docker logs dev-pgbouncer --tail 50 | grep -i "authentication\|password"

# 3. Test connection manually
export VAULT_PASSWORD=$(vault kv get -field=password secret/postgres)
docker exec -e PGPASSWORD=$VAULT_PASSWORD dev-postgres psql -U postgres -c "SELECT 1;"

# 4. If connection fails, password mismatch detected
echo "Password mismatch detected. Synchronizing..."

# 5. Update PostgreSQL password to match Vault
docker exec dev-postgres psql -U postgres -c "ALTER USER postgres WITH PASSWORD '$VAULT_PASSWORD';"

# 6. Restart services
docker restart dev-postgres dev-pgbouncer
```

### Authentication Errors

**Common authentication issues:**

#### "Password authentication failed"

```bash
# Check password in Vault
VAULT_PASSWORD=$(vault kv get -field=password secret/postgres)

# Test password directly
docker exec -e PGPASSWORD=$VAULT_PASSWORD dev-postgres psql -U postgres -c "SELECT 1;"

# If fails, update PostgreSQL password
docker exec dev-postgres psql -U postgres -c "ALTER USER postgres WITH PASSWORD '$VAULT_PASSWORD';"
```

#### "Connection refused"

```bash
# Check service is running
docker ps | grep dev-postgres

# Check service health
docker exec dev-postgres pg_isready -U postgres

# Restart service if unhealthy
docker restart dev-postgres
```

#### "Role does not exist"

```bash
# Check user exists in database
docker exec dev-postgres psql -U postgres -c "\du"

# Create user if missing
docker exec dev-postgres psql -U postgres -c "CREATE USER myapp_user WITH PASSWORD 'password';"
```

## Best Practices

1. **Always backup before rotation:**
   ```bash
   vault kv get -format=json secret/postgres > backup-$(date +%Y%m%d).json
   ```

2. **Use strong passwords:**
   ```bash
   # Minimum 32 characters, random
   openssl rand -base64 32
   ```

3. **Rotate in dependency order:**
   ```
   1. Update Vault secret
   2. Update service password
   3. Restart service
   4. Restart dependent services
   5. Verify connectivity
   ```

4. **Test in non-production first:**
   ```bash
   # Test rotation procedure in dev environment
   # Document any issues
   # Refine procedure
   # Then apply to production
   ```

5. **Maintain rotation logs:**
   ```bash
   echo "$(date): Rotated PostgreSQL password" >> ~/rotation.log
   ```

6. **Set up expiration alerts:**
   ```bash
   # Alert 60 days before certificate expiration
   ./scripts/check-certificate-expiration.sh | grep "RENEWAL RECOMMENDED"
   ```

7. **Document rollback procedures:**
   ```bash
   # Keep old passwords for 30 days (in secure location)
   # Test rollback procedure regularly
   ```

8. **Verify after every rotation:**
   ```bash
   ./scripts/verify-rotation.sh
   ./manage-colima.sh health
   ./tests/run-all-tests.sh
   ```

9. **Use automation for consistency:**
   ```bash
   # Scripted rotation reduces human error
   ./scripts/rotate-all-secrets.sh
   ```

10. **Monitor for 24 hours post-rotation:**
    ```bash
    # Watch for authentication errors
    docker logs dev-postgres --tail 100 -f | grep -i "authentication\|error"
    ```

## Reference

### Related Wiki Pages

- [Vault Integration](Vault-Integration) - Vault usage and configuration
- [Certificate Management](Certificate-Management) - Certificate lifecycle
- [Security Hardening](Security-Hardening) - Security best practices
- [Service Configuration](Service-Configuration) - Service details
- [Disaster Recovery](Disaster-Recovery) - Recovery procedures
- [Health Monitoring](Health-Monitoring) - Monitoring and alerting

### Rotation Scripts Location

```
/Users/gator/colima-services/scripts/
├── rotate-all-secrets.sh              # Master rotation script
├── rotate-postgres-password.sh        # PostgreSQL rotation
├── rotate-mysql-password.sh           # MySQL rotation
├── rotate-mongodb-password.sh         # MongoDB rotation
├── rotate-redis-cluster-password.sh   # Redis cluster rotation
├── rotate-rabbitmq-password.sh        # RabbitMQ rotation
├── rotate-certificates.sh             # Certificate rotation
├── check-certificate-expiration.sh    # Certificate monitoring
└── verify-rotation.sh                 # Post-rotation verification
```

### Rotation Schedule Template

```
Quarterly Rotation Schedule:

Q1 (January):
├── Week 1: Plan and prepare
│   ├── Review procedures
│   ├── Test scripts
│   └── Schedule maintenance window
├── Week 2: Rotate certificates
│   ├── Generate new certificates
│   ├── Restart services
│   └── Verify TLS connections
├── Week 3: Rotate database passwords
│   ├── PostgreSQL
│   ├── MySQL
│   └── MongoDB
└── Week 4: Rotate service credentials
    ├── Redis
    ├── RabbitMQ
    └── API keys

Q2 (April): Repeat
Q3 (July): Repeat
Q4 (October): Repeat
```

### Quick Reference Commands

```bash
# Check certificate expiration
./scripts/check-certificate-expiration.sh

# Rotate all secrets
./scripts/rotate-all-secrets.sh

# Rotate specific service
./scripts/rotate-postgres-password.sh

# Verify rotation
./scripts/verify-rotation.sh

# View rotation history
cat ~/rotation.log

# Rollback (if needed)
./scripts/rollback-rotation.sh postgres
```

### Additional Resources

- [Vault Secrets Management](https://www.vaultproject.io/docs/secrets)
- [PostgreSQL Password Authentication](https://www.postgresql.org/docs/current/auth-password.html)
- [TLS Certificate Lifecycle](https://www.vaultproject.io/docs/secrets/pki)
- [Secrets Rotation Best Practices](https://cheatsheetseries.owasp.org/cheatsheets/Key_Management_Cheat_Sheet.html)
