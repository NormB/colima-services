# Vault Troubleshooting

## Table of Contents

- [Overview](#overview)
- [Vault Won't Unseal](#vault-wont-unseal)
  - [Manual Unseal](#manual-unseal)
  - [Check Unseal Keys](#check-unseal-keys)
  - [Auto-Unseal Issues](#auto-unseal-issues)
- [Lost Vault Keys](#lost-vault-keys)
  - [Recovery Options](#recovery-options)
  - [Prevention Strategies](#prevention-strategies)
  - [Re-initialization Process](#re-initialization-process)
- [Services Can't Reach Vault](#services-cant-reach-vault)
  - [Network Connectivity](#network-connectivity)
  - [Vault Health Check](#vault-health-check)
  - [DNS Resolution](#dns-resolution)
- [Certificate Issues](#certificate-issues)
  - [PKI Not Initialized](#pki-not-initialized)
  - [Expired Certificates](#expired-certificates)
  - [Certificate Regeneration](#certificate-regeneration)
- [Token Expiration](#token-expiration)
  - [Root Token Issues](#root-token-issues)
  - [Service Token Renewal](#service-token-renewal)
  - [Token Lookup](#token-lookup)
- [Re-initializing Vault](#re-initializing-vault)
  - [Clean Initialization](#clean-initialization)
  - [Data Loss Warning](#data-loss-warning)
  - [Post-Initialization Steps](#post-initialization-steps)
- [Common Error Messages](#common-error-messages)
  - [Error: Vault is Sealed](#error-vault-is-sealed)
  - [Error: Permission Denied](#error-permission-denied)
  - [Error: Connection Refused](#error-connection-refused)
  - [Error: No Handler for Route](#error-no-handler-for-route)
- [Vault Health Check Failures](#vault-health-check-failures)
  - [Health Check Timeout](#health-check-timeout)
  - [Initialization Status](#initialization-status)
  - [Seal Status](#seal-status)
- [Debugging Vault Integration](#debugging-vault-integration)
  - [Enable Debug Logging](#enable-debug-logging)
  - [Audit Logging](#audit-logging)
  - [API Request Tracing](#api-request-tracing)
- [Performance Issues](#performance-issues)
  - [Slow Response Times](#slow-response-times)
  - [Storage Backend](#storage-backend)
  - [Memory Limits](#memory-limits)
- [Related Pages](#related-pages)

## Overview

Vault is the critical foundation of the devstack-core environment. All services depend on Vault for credentials and certificates. This page provides troubleshooting guidance for common Vault issues.

**Critical Understanding:**
- Without Vault unsealed, no other services can start
- Without unseal keys, Vault data cannot be accessed
- Services fetch credentials from Vault at startup

## Vault Won't Unseal

### Manual Unseal

If auto-unseal fails, manually unseal Vault:

```bash
# Check Vault status
export VAULT_ADDR=http://localhost:8200
vault status

# Output will show:
# Sealed: true
# Sealed Threshold: 3
# Unseal Progress: 0/3

# Unseal using keys from keys.json
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# Unseal with 3 keys (threshold)
vault operator unseal $(jq -r '.unseal_keys_b64[0]' < ~/.config/vault/keys.json)
vault operator unseal $(jq -r '.unseal_keys_b64[1]' < ~/.config/vault/keys.json)
vault operator unseal $(jq -r '.unseal_keys_b64[2]' < ~/.config/vault/keys.json)

# Verify unsealed
vault status
# Sealed: false
```

**Using management script:**

```bash
./manage-devstack.sh vault-unseal
```

### Check Unseal Keys

Verify unseal keys are present and valid:

```bash
# Check keys file exists
ls -la ~/.config/vault/keys.json

# Verify structure
cat ~/.config/vault/keys.json | jq

# Should output:
# {
#   "unseal_keys_b64": [
#     "key1...",
#     "key2...",
#     "key3...",
#     "key4...",
#     "key5..."
#   ],
#   "unseal_keys_hex": [...],
#   "root_token": "hvs...."
# }

# Count keys
jq '.unseal_keys_b64 | length' < ~/.config/vault/keys.json
# Should output: 5
```

**If keys.json is missing or corrupt:**

```bash
# Check backups
ls -la ~/vault-backup*/keys.json

# Restore from backup
cp ~/vault-backup-20240115/keys.json ~/.config/vault/

# If no backup exists, Vault must be re-initialized (DATA LOSS)
```

### Auto-Unseal Issues

**Check auto-unseal script:**

```bash
# View entrypoint logs
docker logs dev-vault 2>&1 | grep -i unseal

# Common issues:
# - keys.json not mounted correctly
# - Wrong permissions on keys.json
# - Vault server not starting before unseal attempt
```

**Fix mount issues:**

```bash
# Verify volume mount in docker-compose.yml
docker inspect dev-vault | jq '.[0].Mounts'

# Should show:
# {
#   "Type": "bind",
#   "Source": "/Users/user/.config/vault",
#   "Destination": "/vault-keys",
#   "RW": true
# }

# Fix permissions
chmod 600 ~/.config/vault/keys.json
```

**Test auto-unseal script manually:**

```bash
# Shell into Vault container
docker exec -it dev-vault sh

# Check keys file
ls -la /vault-keys/keys.json

# Run unseal commands manually
export VAULT_ADDR=http://127.0.0.1:8200
for i in 0 1 2; do
  UNSEAL_KEY=$(jq -r ".unseal_keys_b64[$i]" < /vault-keys/keys.json)
  vault operator unseal $UNSEAL_KEY
done
```

## Lost Vault Keys

### Recovery Options

**If unseal keys are lost, Vault data CANNOT be recovered. There is no recovery mechanism.**

**Check all backup locations:**

```bash
# Home directory backups
ls -la ~/vault-backup*/

# External drive
ls -la /Volumes/External/vault-backup/

# Cloud storage
aws s3 ls s3://my-backups/vault/
gsutil ls gs://my-backups/vault/

# Project backups
ls -la ~/devstack-core/backups/*/vault/
```

### Prevention Strategies

**Immediate backup after initialization:**

```bash
# After vault-init
./manage-devstack.sh vault-init

# IMMEDIATELY backup keys
mkdir -p ~/vault-backup-CRITICAL-$(date +%Y%m%d)
cp -r ~/.config/vault/ ~/vault-backup-CRITICAL-$(date +%Y%m%d)/

# Copy to external drive
cp -r ~/.config/vault/ /Volumes/External/vault-backup/

# Upload to cloud (encrypted)
tar czf - ~/.config/vault/ | \
  openssl enc -aes-256-cbc -salt -pbkdf2 \
  -out vault-keys-$(date +%Y%m%d).tar.gz.enc

aws s3 cp vault-keys-$(date +%Y%m%d).tar.gz.enc s3://my-backups/vault/
```

**Multiple backup locations:**

```bash
# Create automated backup script
cat > scripts/backup-vault-keys.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d)

# Local backup
cp -r ~/.config/vault/ ~/vault-backup-$DATE/

# External drive
if [ -d /Volumes/External ]; then
  cp -r ~/.config/vault/ /Volumes/External/vault-backup/
fi

# Cloud backup (encrypted)
tar czf - ~/.config/vault/ | \
  openssl enc -aes-256-cbc -salt -pbkdf2 \
  -out /tmp/vault-keys-$DATE.tar.gz.enc

aws s3 cp /tmp/vault-keys-$DATE.tar.gz.enc s3://my-backups/vault/
rm /tmp/vault-keys-$DATE.tar.gz.enc

echo "Vault keys backed up to multiple locations"
EOF

chmod +x scripts/backup-vault-keys.sh

# Schedule daily backup
crontab -e
# Add: 0 3 * * * /path/to/scripts/backup-vault-keys.sh
```

### Re-initialization Process

**If keys are truly lost, must re-initialize (DATA LOSS):**

```bash
# WARNING: This will erase all Vault data
# All secrets, PKI, and credentials will be lost

# Stop all services
docker compose down

# Remove Vault data
docker volume rm devstack-core_vault-data

# Start Vault
docker compose up -d vault

# Wait for Vault to start
sleep 10

# Initialize Vault
./manage-devstack.sh vault-init

# IMMEDIATELY backup new keys
cp -r ~/.config/vault/ ~/vault-backup-NEW-$(date +%Y%m%d)/

# Bootstrap Vault with new credentials
./manage-devstack.sh vault-bootstrap

# Restart all services
./manage-devstack.sh start
```

## Services Can't Reach Vault

### Network Connectivity

**Test connectivity from service container:**

```bash
# Test from PostgreSQL container
docker exec dev-postgres curl -v http://vault:8200/v1/sys/health

# Expected output:
# HTTP/1.1 200 OK
# {"initialized":true,"sealed":false,...}

# Test DNS resolution
docker exec dev-postgres nslookup vault

# Expected output:
# Server: 127.0.0.11
# Address: 127.0.0.11:53
# Name: vault
# Address: 172.20.0.21
```

**Check network configuration:**

```bash
# Verify both containers are on same network
docker network inspect dev-services

# Should show both vault and postgres in "Containers" section

# Check IP addresses
docker inspect dev-vault | jq '.[0].NetworkSettings.Networks["dev-services"].IPAddress'
# Expected: 172.20.0.21

docker inspect dev-postgres | jq '.[0].NetworkSettings.Networks["dev-services"].IPAddress'
# Expected: 172.20.0.10
```

### Vault Health Check

**Check Vault is actually healthy:**

```bash
# Via management script
./manage-devstack.sh vault-status

# Via API
curl -s http://localhost:8200/v1/sys/health | jq

# Expected:
# {
#   "initialized": true,
#   "sealed": false,
#   "standby": false,
#   "version": "1.15.0"
# }

# Via CLI
vault status
# Expected:
# Sealed: false
# Initialized: true
```

### DNS Resolution

**If DNS fails within containers:**

```bash
# Add explicit IP to /etc/hosts in container
docker exec dev-postgres sh -c 'echo "172.20.0.21 vault" >> /etc/hosts'

# Or modify docker-compose.yml to use IP directly
services:
  postgres:
    environment:
      VAULT_ADDR: http://172.20.0.21:8200  # Instead of http://vault:8200
```

## Certificate Issues

### PKI Not Initialized

**Check if PKI is configured:**

```bash
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# List PKI mounts
vault secrets list

# Should show:
# pki/      pki
# pki_int/  pki

# If missing, run bootstrap
./manage-devstack.sh vault-bootstrap
```

### Expired Certificates

**Check certificate expiration:**

```bash
# Check service certificate
openssl x509 -in ~/.config/vault/certs/postgres/cert.pem -noout -dates

# Output:
# notBefore=Jan 1 00:00:00 2024 GMT
# notAfter=Jan 1 00:00:00 2025 GMT

# Check if expired
openssl x509 -in ~/.config/vault/certs/postgres/cert.pem -noout -checkend 0
# Returns 0 if valid, 1 if expired
```

**Renew expired certificates:**

```bash
# Regenerate all certificates
./scripts/generate-certificates.sh

# Restart services to pick up new certificates
docker compose restart postgres mysql redis-1 redis-2 redis-3
```

### Certificate Regeneration

**Regenerate certificates for specific service:**

```bash
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# Generate new certificate
vault write pki_int/issue/postgres-role \
  common_name=postgres \
  ttl=8760h \
  format=pem > /tmp/postgres-cert.json

# Extract certificate and key
jq -r '.data.certificate' < /tmp/postgres-cert.json > ~/.config/vault/certs/postgres/cert.pem
jq -r '.data.private_key' < /tmp/postgres-cert.json > ~/.config/vault/certs/postgres/key.pem
jq -r '.data.ca_chain[]' < /tmp/postgres-cert.json > ~/.config/vault/certs/postgres/ca.pem

# Set permissions
chmod 600 ~/.config/vault/certs/postgres/key.pem

# Restart service
docker compose restart postgres
```

## Token Expiration

### Root Token Issues

**Check root token validity:**

```bash
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# Lookup token
vault token lookup

# If token expired:
# Error: permission denied

# Root token should never expire, but check TTL
vault token lookup -format=json | jq '.data.ttl'
```

**If root token lost/expired:**

```bash
# Generate new root token (requires quorum of unseal keys)
vault operator generate-root -init

# Follow prompts to provide unseal keys
# New root token will be generated

# Save new token
echo "new-token-here" > ~/.config/vault/root-token
```

### Service Token Renewal

**Services use root token in dev environment. For production, use AppRole:**

```bash
# Enable AppRole authentication
vault auth enable approle

# Create role for service
vault write auth/approle/role/postgres \
  token_ttl=1h \
  token_max_ttl=4h \
  token_policies=postgres-policy

# Get role ID
vault read auth/approle/role/postgres/role-id

# Generate secret ID
vault write -f auth/approle/role/postgres/secret-id

# Service authenticates with role-id and secret-id
vault write auth/approle/login \
  role_id="xxx" \
  secret_id="yyy"
```

### Token Lookup

**Debug token issues:**

```bash
# Lookup current token
vault token lookup

# Lookup specific token
vault token lookup hvs.CAESIJ...

# Check token capabilities
vault token capabilities secret/postgres

# Renew token
vault token renew

# Revoke token
vault token revoke hvs.CAESIJ...
```

## Re-initializing Vault

### Clean Initialization

**Start fresh with new Vault (DATA LOSS):**

```bash
# Stop all services
./manage-devstack.sh stop

# Remove Vault data and keys
docker volume rm devstack-core_vault-data
rm -rf ~/.config/vault/*

# Start Vault
docker compose up -d vault

# Wait for Vault
sleep 10

# Initialize
./manage-devstack.sh vault-init

# Verify keys created
ls -la ~/.config/vault/keys.json
ls -la ~/.config/vault/root-token

# BACKUP KEYS IMMEDIATELY
cp -r ~/.config/vault/ ~/vault-backup-$(date +%Y%m%d)/

# Bootstrap (create PKI, store credentials)
./manage-devstack.sh vault-bootstrap

# Start services
./manage-devstack.sh start
```

### Data Loss Warning

**Re-initialization consequences:**

- All stored secrets lost
- PKI certificates revoked
- Service credentials must be regenerated
- Applications must be reconfigured
- Historical audit logs lost

**Before re-initializing:**

```bash
# Export all secrets if possible
./scripts/export-vault-secrets.sh > vault-secrets-backup.json

# Backup current state
docker exec dev-vault vault operator raft snapshot save /tmp/vault-snapshot.snap
docker cp dev-vault:/tmp/vault-snapshot.snap ./vault-snapshot-$(date +%Y%m%d).snap
```

### Post-Initialization Steps

**After re-initializing Vault:**

1. **Bootstrap Vault:**
   ```bash
   ./manage-devstack.sh vault-bootstrap
   ```

2. **Verify secrets:**
   ```bash
   vault kv list secret/
   vault kv get secret/postgres
   ```

3. **Generate certificates:**
   ```bash
   ./scripts/generate-certificates.sh
   ```

4. **Restart all services:**
   ```bash
   ./manage-devstack.sh restart
   ```

5. **Verify health:**
   ```bash
   ./manage-devstack.sh health
   ```

6. **Run tests:**
   ```bash
   ./tests/run-all-tests.sh
   ```

## Common Error Messages

### Error: Vault is Sealed

```
Error: Vault is sealed
```

**Solution:**

```bash
# Unseal Vault
./manage-devstack.sh vault-unseal

# Or manually
vault operator unseal $(jq -r '.unseal_keys_b64[0]' < ~/.config/vault/keys.json)
vault operator unseal $(jq -r '.unseal_keys_b64[1]' < ~/.config/vault/keys.json)
vault operator unseal $(jq -r '.unseal_keys_b64[2]' < ~/.config/vault/keys.json)
```

### Error: Permission Denied

```
Error: permission denied
```

**Causes:**
- Invalid or expired token
- Insufficient token permissions
- Token revoked

**Solution:**

```bash
# Check token
vault token lookup

# Use root token
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# Verify token works
vault token lookup

# Check policy permissions
vault token capabilities secret/postgres
```

### Error: Connection Refused

```
Error: Get "http://vault:8200/v1/sys/health": dial tcp: lookup vault: no such host
```

**Causes:**
- Vault container not running
- DNS resolution failed
- Network not connected

**Solution:**

```bash
# Check Vault is running
docker ps | grep vault

# Start Vault if not running
docker compose up -d vault

# Check from service container
docker exec dev-postgres curl http://vault:8200/v1/sys/health

# Check network
docker network ls
docker network inspect dev-services
```

### Error: No Handler for Route

```
Error: no handler for route 'secret/postgres'
```

**Causes:**
- KV secrets engine not enabled
- Wrong API path
- Vault not bootstrapped

**Solution:**

```bash
# Check if KV enabled
vault secrets list

# Should show:
# secret/   kv

# If missing, enable
vault secrets enable -path=secret kv-v2

# Or re-run bootstrap
./manage-devstack.sh vault-bootstrap
```

## Vault Health Check Failures

### Health Check Timeout

**If Vault health check times out:**

```bash
# Check Vault logs
docker logs dev-vault

# Increase health check timeout
# In docker-compose.yml:
healthcheck:
  test: ["CMD", "vault", "status"]
  interval: 10s
  timeout: 10s  # Increase from 5s
  retries: 5
  start_period: 60s  # Increase grace period

# Restart Vault
docker compose up -d vault
```

### Initialization Status

**Vault stuck in uninitialized state:**

```bash
# Check status
vault status
# Initialized: false

# Initialize manually
vault operator init -key-shares=5 -key-threshold=3 -format=json > ~/.config/vault/keys.json

# Unseal
for i in 0 1 2; do
  vault operator unseal $(jq -r ".unseal_keys_b64[$i]" < ~/.config/vault/keys.json)
done
```

### Seal Status

**Vault keeps sealing:**

```bash
# Check if auto-unseal is working
docker logs dev-vault | grep -i unseal

# Check storage backend
docker exec dev-vault ls -la /vault/data

# Verify keys accessible
docker exec dev-vault cat /vault-keys/keys.json

# Check for storage issues
docker volume inspect devstack-core_vault-data
```

## Debugging Vault Integration

### Enable Debug Logging

**Increase Vault log level:**

```bash
# In docker-compose.yml:
services:
  vault:
    environment:
      VAULT_LOG_LEVEL: debug

# Restart Vault
docker compose up -d vault

# View debug logs
docker logs -f dev-vault
```

**Enable client-side debugging:**

```bash
export VAULT_LOG_LEVEL=debug
vault kv get secret/postgres
```

### Audit Logging

**Enable audit logging:**

```bash
# Enable file audit device
vault audit enable file file_path=/vault/logs/audit.log

# View audit logs
docker exec dev-vault cat /vault/logs/audit.log | jq

# Filter for specific operations
docker exec dev-vault grep "secret/postgres" /vault/logs/audit.log | jq
```

### API Request Tracing

**Trace Vault API requests:**

```bash
# Enable HTTP tracing
export VAULT_HTTP_TRACE=1

# Make request
vault kv get secret/postgres

# Or with curl
curl -v -H "X-Vault-Token: $VAULT_TOKEN" \
  http://localhost:8200/v1/secret/data/postgres
```

## Performance Issues

### Slow Response Times

**Diagnose slow Vault responses:**

```bash
# Measure response time
time vault kv get secret/postgres

# Check Vault metrics
curl http://localhost:8200/v1/sys/metrics?format=prometheus

# Monitor container resources
docker stats dev-vault

# Check storage backend performance
docker exec dev-vault du -sh /vault/data
```

### Storage Backend

**Optimize storage backend:**

```hcl
# For better performance, use Raft instead of file backend
# In configs/vault/config.hcl:

storage "raft" {
  path = "/vault/data"
  node_id = "vault-1"
}

# Or use Consul for HA
storage "consul" {
  address = "consul:8500"
  path    = "vault/"
}
```

### Memory Limits

**Increase Vault memory:**

```yaml
# In docker-compose.yml:
services:
  vault:
    deploy:
      resources:
        limits:
          memory: 512M  # Increase from default
        reservations:
          memory: 256M
```

## Related Pages

- [Service-Configuration](Service-Configuration) - Vault configuration
- [TLS-Configuration](TLS-Configuration) - Certificate setup
- [Security-Hardening](Security-Hardening) - Production security
- [CLI-Reference](CLI-Reference) - Management commands
- [Health-Monitoring](Health-Monitoring) - Health checks
- [Backup-and-Restore](Backup-and-Restore) - Backup procedures
