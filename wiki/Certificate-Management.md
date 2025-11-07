# Certificate Management

Comprehensive guide to managing TLS certificates in the DevStack Core environment using Vault PKI.

## Table of Contents

- [Overview](#overview)
- [Certificate Lifecycle](#certificate-lifecycle)
  - [Generation](#generation)
  - [Deployment](#deployment)
  - [Renewal](#renewal)
  - [Revocation](#revocation)
- [Vault PKI Overview](#vault-pki-overview)
  - [Root CA](#root-ca)
  - [Intermediate CA](#intermediate-ca)
  - [Service Certificates](#service-certificates)
  - [PKI Hierarchy](#pki-hierarchy)
- [Certificate Generation](#certificate-generation)
  - [Initial Certificate Creation](#initial-certificate-creation)
  - [Service-Specific Certificates](#service-specific-certificates)
  - [Wildcard Certificates](#wildcard-certificates)
  - [Custom Certificate Parameters](#custom-certificate-parameters)
- [Certificate Deployment](#certificate-deployment)
  - [Copying Certificates to Services](#copying-certificates-to-services)
  - [Service Configuration](#service-configuration)
  - [Verification](#verification)
  - [Container Restart](#container-restart)
- [Certificate Renewal](#certificate-renewal)
  - [When to Renew](#when-to-renew)
  - [Renewal Procedures](#renewal-procedures)
  - [Zero-Downtime Renewal](#zero-downtime-renewal)
  - [Automated Renewal](#automated-renewal)
- [Certificate Rotation](#certificate-rotation)
  - [Rotating Certificates Across Services](#rotating-certificates-across-services)
  - [Coordinated Rotation](#coordinated-rotation)
  - [Testing After Rotation](#testing-after-rotation)
- [Certificate Monitoring](#certificate-monitoring)
  - [Checking Expiration Dates](#checking-expiration-dates)
  - [Automated Monitoring](#automated-monitoring)
  - [Expiration Alerts](#expiration-alerts)
- [Trusting Certificates](#trusting-certificates)
  - [macOS Trust](#macos-trust)
  - [Application Trust](#application-trust)
  - [Browser Trust](#browser-trust)
  - [System-Wide Trust](#system-wide-trust)
- [Certificate Formats](#certificate-formats)
  - [PEM Format](#pem-format)
  - [DER Format](#der-format)
  - [PKCS12 Format](#pkcs12-format)
  - [Format Conversion](#format-conversion)
- [Certificate Troubleshooting](#certificate-troubleshooting)
  - [Invalid Certificates](#invalid-certificates)
  - [Expired Certificates](#expired-certificates)
  - [Trust Issues](#trust-issues)
  - [Handshake Failures](#handshake-failures)
- [Client Configuration](#client-configuration)
  - [Configuring Applications](#configuring-applications)
  - [TLS Verification](#tls-verification)
  - [Certificate Pinning](#certificate-pinning)
- [Certificate Revocation](#certificate-revocation)
  - [Revoking Compromised Certificates](#revoking-compromised-certificates)
  - [CRL Management](#crl-management)
  - [OCSP Configuration](#ocsp-configuration)
- [Best Practices](#best-practices)
- [Automation](#automation)
- [Reference](#reference)

## Overview

Certificate management in DevStack Core uses Vault's PKI secrets engine to generate and manage TLS certificates. All service certificates are signed by a Vault-managed Certificate Authority (CA), enabling secure TLS communications.

**Key Information:**
- **PKI Root CA:** `pki` (10-year validity)
- **PKI Intermediate CA:** `pki_int` (5-year validity)
- **Service Certificates:** 1-year validity (renewable)
- **Certificate Storage:** `~/.config/vault/certs/<service>/`
- **CA Certificates:** `~/.config/vault/ca/`
- **Generation Script:** `scripts/generate-certificates.sh`

**Related Pages:**
- [TLS Configuration](TLS-Configuration) - TLS setup and configuration
- [Vault Integration](Vault-Integration) - Vault usage
- [Security Hardening](Security-Hardening) - Security best practices
- [Secrets Rotation](Secrets-Rotation) - Credential rotation

## Certificate Lifecycle

### Generation

**Initial certificate generation:**

1. **Root CA created** (Vault PKI root CA)
2. **Intermediate CA created** (Vault PKI intermediate CA)
3. **Service roles defined** (per-service certificate roles)
4. **Certificates issued** (generate certs for each service)
5. **Certificates stored** (`~/.config/vault/certs/<service>/`)

### Deployment

1. **Certificates copied** to service containers
2. **Service configuration updated** (paths to cert files)
3. **Services restarted** to load new certificates
4. **Connectivity verified** (TLS handshake test)

### Renewal

1. **Monitor expiration dates** (check 60 days before expiry)
2. **Generate new certificates** (using Vault PKI)
3. **Deploy new certificates** (copy to services)
4. **Restart services** (load new certificates)
5. **Verify TLS connections** (test connectivity)

### Revocation

1. **Identify compromised certificate** (security incident)
2. **Revoke certificate** (Vault PKI revocation)
3. **Update CRL** (Certificate Revocation List)
4. **Generate replacement certificate**
5. **Deploy replacement** (same as renewal process)

## Vault PKI Overview

### Root CA

**Root Certificate Authority** - Top of PKI hierarchy.

```bash
# View root CA details
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

vault read pki/cert/ca

# Root CA configuration
# - Path: pki
# - Validity: 87600h (10 years)
# - Key Type: RSA 4096
# - Usage: Certificate signing only
```

**Root CA certificate location:**
```
~/.config/vault/ca/ca.pem
```

### Intermediate CA

**Intermediate Certificate Authority** - Signs service certificates.

```bash
# View intermediate CA details
vault read pki_int/cert/ca

# Intermediate CA configuration
# - Path: pki_int
# - Validity: 43800h (5 years)
# - Key Type: RSA 2048
# - Signed by: Root CA
# - Usage: Certificate signing for services
```

**Intermediate CA certificate location:**
```
~/.config/vault/ca/ca-chain.pem
```

### Service Certificates

**Service certificates** - Individual certificates for each service.

```bash
# Service certificate roles
vault list pki_int/roles

# Example roles:
# - postgres-role
# - mysql-role
# - redis-role
# - rabbitmq-role
# - mongodb-role
```

**Service certificate parameters:**
- **Validity:** 8760h (1 year)
- **Key Type:** RSA 2048
- **Usage:** TLS web server authentication
- **Common Name:** `<service>.dev-services.local`
- **Subject Alternative Names:** `localhost`, `127.0.0.1`, service IPs

### PKI Hierarchy

```
Root CA (pki)
├── Common Name: DevStack Core Root CA
├── Validity: 10 years
└── Key: RSA 4096
    |
    └── Intermediate CA (pki_int)
        ├── Common Name: DevStack Core Intermediate CA
        ├── Validity: 5 years
        ├── Key: RSA 2048
        └── Signed by: Root CA
            |
            ├── PostgreSQL Certificate
            │   ├── CN: postgres.dev-services.local
            │   ├── Validity: 1 year
            │   └── Signed by: Intermediate CA
            |
            ├── MySQL Certificate
            │   ├── CN: mysql.dev-services.local
            │   ├── Validity: 1 year
            │   └── Signed by: Intermediate CA
            |
            └── [Other service certificates...]
```

## Certificate Generation

### Initial Certificate Creation

**Generate all service certificates:**

```bash
# Using the provided script
cd /Users/gator/devstack-core
./scripts/generate-certificates.sh

# Script performs:
# 1. Creates certificate directories
# 2. Generates certificates for each service
# 3. Sets proper file permissions
# 4. Validates certificates
```

**Manual certificate generation:**

```bash
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

SERVICE="postgres"
CERT_DIR="$HOME/.config/vault/certs/$SERVICE"

# Create directory
mkdir -p "$CERT_DIR"

# Generate certificate
vault write -format=json pki_int/issue/postgres-role \
    common_name="postgres.dev-services.local" \
    ttl="8760h" \
    ip_sans="127.0.0.1,172.20.0.10" \
    alt_names="localhost,postgres" \
    > "$CERT_DIR/cert.json"

# Extract certificate components
jq -r '.data.certificate' "$CERT_DIR/cert.json" > "$CERT_DIR/cert.pem"
jq -r '.data.private_key' "$CERT_DIR/cert.json" > "$CERT_DIR/key.pem"
jq -r '.data.ca_chain[]' "$CERT_DIR/cert.json" > "$CERT_DIR/ca.pem"

# Set permissions
chmod 600 "$CERT_DIR/key.pem"
chmod 644 "$CERT_DIR/cert.pem"
chmod 644 "$CERT_DIR/ca.pem"

# Cleanup JSON
rm "$CERT_DIR/cert.json"

echo "✓ Certificate generated for $SERVICE"
```

### Service-Specific Certificates

**PostgreSQL certificate:**

```bash
vault write pki_int/issue/postgres-role \
    common_name="postgres.dev-services.local" \
    ttl="8760h" \
    ip_sans="127.0.0.1,172.20.0.10" \
    alt_names="localhost,postgres,dev-postgres"
```

**MySQL certificate:**

```bash
vault write pki_int/issue/mysql-role \
    common_name="mysql.dev-services.local" \
    ttl="8760h" \
    ip_sans="127.0.0.1,172.20.0.12" \
    alt_names="localhost,mysql,dev-mysql"
```

**Redis certificate (for each node):**

```bash
# Redis node 1
vault write pki_int/issue/redis-role \
    common_name="redis-1.dev-services.local" \
    ttl="8760h" \
    ip_sans="127.0.0.1,172.20.0.13" \
    alt_names="localhost,redis-1,dev-redis-1"

# Redis node 2
vault write pki_int/issue/redis-role \
    common_name="redis-2.dev-services.local" \
    ttl="8760h" \
    ip_sans="127.0.0.1,172.20.0.16" \
    alt_names="localhost,redis-2,dev-redis-2"

# Redis node 3
vault write pki_int/issue/redis-role \
    common_name="redis-3.dev-services.local" \
    ttl="8760h" \
    ip_sans="127.0.0.1,172.20.0.17" \
    alt_names="localhost,redis-3,dev-redis-3"
```

### Wildcard Certificates

**Generate wildcard certificate (covers all subdomains):**

```bash
vault write pki_int/issue/wildcard-role \
    common_name="*.dev-services.local" \
    ttl="8760h" \
    ip_sans="127.0.0.1" \
    alt_names="dev-services.local,localhost"
```

**⚠️ NOTE:** Wildcard certificates are less secure than individual certificates. Use only when necessary.

### Custom Certificate Parameters

**Extended validity (2 years):**

```bash
vault write pki_int/issue/postgres-role \
    common_name="postgres.dev-services.local" \
    ttl="17520h"  # 2 years
```

**Custom key size:**

```bash
# Configure role with custom key size
vault write pki_int/roles/custom-role \
    allowed_domains="dev-services.local" \
    allow_subdomains=true \
    key_bits=4096 \
    max_ttl="8760h"

# Issue certificate
vault write pki_int/issue/custom-role \
    common_name="service.dev-services.local" \
    ttl="8760h"
```

**Multiple SANs (Subject Alternative Names):**

```bash
vault write pki_int/issue/postgres-role \
    common_name="postgres.dev-services.local" \
    ttl="8760h" \
    ip_sans="127.0.0.1,172.20.0.10,192.168.1.100" \
    alt_names="localhost,postgres,dev-postgres,db.example.local"
```

## Certificate Deployment

### Copying Certificates to Services

**Certificates are deployed via Docker volumes:**

```yaml
# docker-compose.yml example
services:
  postgres:
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ~/.config/vault/certs/postgres:/certs:ro  # Certificate directory
    environment:
      POSTGRES_SSLCERT: /certs/cert.pem
      POSTGRES_SSLKEY: /certs/key.pem
      POSTGRES_SSLROOTCERT: /certs/ca.pem
```

**Manual certificate deployment:**

```bash
# Generate certificate
./scripts/generate-certificates.sh postgres

# Certificate automatically available in container at /certs/
# No manual copy needed (Docker volume mount)

# Verify certificate is accessible in container
docker exec dev-postgres ls -la /certs/
```

### Service Configuration

**PostgreSQL TLS configuration:**

```bash
# postgresql.conf
ssl = on
ssl_cert_file = '/certs/cert.pem'
ssl_key_file = '/certs/key.pem'
ssl_ca_file = '/certs/ca.pem'
ssl_min_protocol_version = 'TLSv1.2'
ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'
```

**MySQL TLS configuration:**

```bash
# my.cnf
[mysqld]
ssl-ca=/certs/ca.pem
ssl-cert=/certs/cert.pem
ssl-key=/certs/key.pem
require_secure_transport=ON
```

**Redis TLS configuration:**

```bash
# redis.conf
tls-port 6380
port 0  # Disable non-TLS port
tls-cert-file /certs/cert.pem
tls-key-file /certs/key.pem
tls-ca-cert-file /certs/ca.pem
tls-auth-clients optional
```

### Verification

**Verify certificate is valid:**

```bash
# Check certificate details
openssl x509 -in ~/.config/vault/certs/postgres/cert.pem -noout -text

# Check expiration date
openssl x509 -in ~/.config/vault/certs/postgres/cert.pem -noout -dates

# Verify certificate chain
openssl verify -CAfile ~/.config/vault/ca/ca-chain.pem ~/.config/vault/certs/postgres/cert.pem

# Test TLS connection
openssl s_client -connect localhost:5432 -starttls postgres -CAfile ~/.config/vault/ca/ca.pem
```

### Container Restart

**Restart services to load new certificates:**

```bash
# Restart single service
docker restart dev-postgres

# Restart all services with certificates
docker restart dev-postgres dev-mysql dev-redis-1 dev-redis-2 dev-redis-3 dev-rabbitmq dev-mongodb

# Verify services started
docker ps --filter "name=dev-"

# Check logs for TLS errors
docker logs dev-postgres --tail 50 | grep -i "ssl\|tls"
```

## Certificate Renewal

### When to Renew

**Renewal triggers:**

1. **Approaching expiration:** 60 days before expiry (recommended)
2. **Security incident:** Certificate compromise suspected
3. **Configuration change:** Adding new SANs or IPs
4. **Routine rotation:** Annual security policy

**Check certificate expiration:**

```bash
#!/bin/bash
# Check all certificate expiration dates

for SERVICE in postgres mysql redis-1 redis-2 redis-3 rabbitmq mongodb; do
    CERT_FILE="$HOME/.config/vault/certs/$SERVICE/cert.pem"

    if [ -f "$CERT_FILE" ]; then
        echo "=== $SERVICE ==="
        openssl x509 -in "$CERT_FILE" -noout -dates

        # Calculate days until expiration
        EXPIRY=$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
        EXPIRY_EPOCH=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$EXPIRY" +%s)
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))

        if [ $DAYS_LEFT -lt 60 ]; then
            echo "⚠️  RENEWAL RECOMMENDED: $DAYS_LEFT days remaining"
        else
            echo "✓  Valid for $DAYS_LEFT days"
        fi
        echo ""
    fi
done
```

### Renewal Procedures

**Renew single service certificate:**

```bash
#!/bin/bash
# Renew certificate for specific service

SERVICE="postgres"
ROLE="postgres-role"
CERT_DIR="$HOME/.config/vault/certs/$SERVICE"

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

echo "=== Renewing Certificate: $SERVICE ==="

# Backup current certificate
mkdir -p "$CERT_DIR/backup"
cp "$CERT_DIR/cert.pem" "$CERT_DIR/backup/cert-$(date +%Y%m%d).pem"
cp "$CERT_DIR/key.pem" "$CERT_DIR/backup/key-$(date +%Y%m%d).pem"

# Generate new certificate
vault write -format=json pki_int/issue/$ROLE \
    common_name="$SERVICE.dev-services.local" \
    ttl="8760h" \
    > "$CERT_DIR/cert.json"

# Extract components
jq -r '.data.certificate' "$CERT_DIR/cert.json" > "$CERT_DIR/cert.pem"
jq -r '.data.private_key' "$CERT_DIR/cert.json" > "$CERT_DIR/key.pem"
jq -r '.data.ca_chain[]' "$CERT_DIR/cert.json" > "$CERT_DIR/ca.pem"

# Set permissions
chmod 600 "$CERT_DIR/key.pem"
chmod 644 "$CERT_DIR/cert.pem"
chmod 644 "$CERT_DIR/ca.pem"

# Cleanup
rm "$CERT_DIR/cert.json"

# Restart service
docker restart dev-$SERVICE
sleep 10

# Verify
openssl x509 -in "$CERT_DIR/cert.pem" -noout -dates
echo "✓ Certificate renewed for $SERVICE"
```

**Renew all certificates:**

```bash
# Use the generate-certificates.sh script
./scripts/generate-certificates.sh

# Restart all services
docker restart dev-postgres dev-mysql dev-redis-1 dev-redis-2 dev-redis-3 dev-rabbitmq dev-mongodb
```

### Zero-Downtime Renewal

**PostgreSQL supports certificate reload without restart:**

```bash
# Generate new certificate
./scripts/generate-certificates.sh postgres

# Reload PostgreSQL configuration (no restart)
docker exec dev-postgres pg_ctl reload

# Verify new certificate loaded
openssl s_client -connect localhost:5432 -starttls postgres < /dev/null 2>/dev/null | openssl x509 -noout -dates
```

**For services requiring restart, use rolling restart:**

```bash
# Renew certificates
./scripts/generate-certificates.sh

# Restart services one at a time
for SERVICE in postgres mysql redis-1 redis-2 redis-3; do
    echo "Restarting dev-$SERVICE..."
    docker restart dev-$SERVICE
    sleep 10

    # Verify service health
    docker ps | grep dev-$SERVICE
    echo "✓ dev-$SERVICE restarted"
done
```

### Automated Renewal

**Scheduled certificate renewal:**

```bash
# Add to crontab (monthly renewal)
0 3 1 * * /Users/gator/devstack-core/scripts/renew-certificates.sh >> ~/cert-renewal.log 2>&1
```

**Renewal script with expiration check:**

```bash
#!/bin/bash
# Save as: /Users/gator/devstack-core/scripts/renew-certificates.sh

RENEWAL_THRESHOLD=60  # Renew if < 60 days until expiration

echo "=== Certificate Renewal Check: $(date) ==="

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

RENEWAL_NEEDED=false

for SERVICE in postgres mysql redis-1 redis-2 redis-3 rabbitmq mongodb; do
    CERT_FILE="$HOME/.config/vault/certs/$SERVICE/cert.pem"

    if [ -f "$CERT_FILE" ]; then
        EXPIRY=$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
        EXPIRY_EPOCH=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$EXPIRY" +%s)
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))

        echo "$SERVICE: $DAYS_LEFT days until expiration"

        if [ $DAYS_LEFT -lt $RENEWAL_THRESHOLD ]; then
            echo "  → Renewal needed"
            RENEWAL_NEEDED=true
        fi
    fi
done

if [ "$RENEWAL_NEEDED" = true ]; then
    echo "Renewing certificates..."
    ./scripts/generate-certificates.sh

    echo "Restarting services..."
    docker restart dev-postgres dev-mysql dev-redis-1 dev-redis-2 dev-redis-3 dev-rabbitmq dev-mongodb

    echo "✓ Certificate renewal complete"
else
    echo "No renewal needed at this time"
fi
```

## Certificate Rotation

### Rotating Certificates Across Services

**Full certificate rotation:**

```bash
#!/bin/bash
# Rotate all service certificates

echo "=== Certificate Rotation ==="
echo "Started: $(date)"

# 1. Generate new certificates for all services
echo "Step 1: Generating new certificates..."
./scripts/generate-certificates.sh

# 2. Restart services in dependency order
echo "Step 2: Restarting services..."

# Databases first
docker restart dev-postgres dev-mysql dev-mongodb
sleep 15

# Cache and messaging
docker restart dev-redis-1 dev-redis-2 dev-redis-3 dev-rabbitmq
sleep 10

# Applications
docker restart reference-api api-first golang-api nodejs-api rust-api
sleep 10

# 3. Verify all services
echo "Step 3: Verifying services..."
./manage-devstack.sh health

# 4. Test TLS connections
echo "Step 4: Testing TLS connections..."
for SERVICE in postgres mysql redis-1; do
    echo "Testing $SERVICE..."
    # Service-specific TLS test commands here
done

echo "=== Certificate Rotation Complete ==="
echo "Finished: $(date)"
```

### Coordinated Rotation

**Rotate certificates during maintenance window:**

```bash
# Schedule rotation
# 1. Notify users of maintenance window
# 2. Schedule rotation for low-traffic period (e.g., 2 AM)
# 3. Execute rotation
# 4. Monitor for issues
# 5. Notify users of completion

# Maintenance window script
#!/bin/bash
MAINTENANCE_START="2024-10-29 02:00:00"
MAINTENANCE_END="2024-10-29 03:00:00"

echo "Maintenance window: $MAINTENANCE_START to $MAINTENANCE_END"
echo "Rotating certificates..."

# Put applications in maintenance mode
# Execute rotation
./scripts/rotate-certificates.sh

# Take applications out of maintenance mode
echo "Maintenance complete"
```

### Testing After Rotation

**Post-rotation verification:**

```bash
#!/bin/bash
# Verify certificate rotation

echo "=== Post-Rotation Verification ==="

# 1. Check certificate validity
for SERVICE in postgres mysql redis-1 redis-2 redis-3 rabbitmq mongodb; do
    CERT_FILE="$HOME/.config/vault/certs/$SERVICE/cert.pem"
    echo "=== $SERVICE ==="

    # Check expiration date
    openssl x509 -in "$CERT_FILE" -noout -dates

    # Verify certificate chain
    openssl verify -CAfile ~/.config/vault/ca/ca-chain.pem "$CERT_FILE"
done

# 2. Test TLS connections
echo "=== Testing TLS Connections ==="

# PostgreSQL
echo -n "PostgreSQL TLS: "
openssl s_client -connect localhost:5432 -starttls postgres -CAfile ~/.config/vault/ca/ca.pem < /dev/null 2>/dev/null > /dev/null && echo "✓" || echo "✗"

# MySQL
echo -n "MySQL TLS: "
docker exec dev-mysql mysql -u root --ssl-mode=REQUIRED -e "SHOW STATUS LIKE 'Ssl_cipher';" > /dev/null 2>&1 && echo "✓" || echo "✗"

# Redis
echo -n "Redis TLS: "
docker exec dev-redis-1 redis-cli --tls --cert /certs/cert.pem --key /certs/key.pem --cacert /certs/ca.pem PING > /dev/null 2>&1 && echo "✓" || echo "✗"

# 3. Application connectivity
echo "=== Application Connectivity ==="
curl -k https://localhost:8443/health > /dev/null 2>&1 && echo "✓ Reference API" || echo "✗ Reference API"

echo "=== Verification Complete ==="
```

## Certificate Monitoring

### Checking Expiration Dates

**Check certificate expiration:**

```bash
# Single certificate
openssl x509 -in ~/.config/vault/certs/postgres/cert.pem -noout -dates

# Output:
# notBefore=Oct 28 12:00:00 2024 GMT
# notAfter=Oct 28 12:00:00 2025 GMT

# All certificates with days remaining
for SERVICE in postgres mysql redis-1 redis-2 redis-3 rabbitmq mongodb; do
    CERT_FILE="$HOME/.config/vault/certs/$SERVICE/cert.pem"

    if [ -f "$CERT_FILE" ]; then
        EXPIRY=$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
        EXPIRY_EPOCH=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$EXPIRY" +%s)
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))

        printf "%-15s %4d days\n" "$SERVICE:" "$DAYS_LEFT"
    fi
done
```

### Automated Monitoring

**Certificate expiration monitoring script:**

```bash
#!/bin/bash
# Save as: /Users/gator/devstack-core/scripts/monitor-certificates.sh

ALERT_THRESHOLD=60  # Alert if < 60 days until expiration
CRITICAL_THRESHOLD=30  # Critical if < 30 days

echo "=== Certificate Expiration Report ==="
echo "Generated: $(date)"
echo ""

ALERT_SERVICES=""
CRITICAL_SERVICES=""

for SERVICE in postgres mysql redis-1 redis-2 redis-3 rabbitmq mongodb; do
    CERT_FILE="$HOME/.config/vault/certs/$SERVICE/cert.pem"

    if [ -f "$CERT_FILE" ]; then
        EXPIRY=$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
        EXPIRY_EPOCH=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$EXPIRY" +%s)
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))

        if [ $DAYS_LEFT -lt $CRITICAL_THRESHOLD ]; then
            echo "🔴 $SERVICE: $DAYS_LEFT days (CRITICAL)"
            CRITICAL_SERVICES="$CRITICAL_SERVICES $SERVICE"
        elif [ $DAYS_LEFT -lt $ALERT_THRESHOLD ]; then
            echo "⚠️  $SERVICE: $DAYS_LEFT days (WARNING)"
            ALERT_SERVICES="$ALERT_SERVICES $SERVICE"
        else
            echo "✓  $SERVICE: $DAYS_LEFT days"
        fi
    else
        echo "✗  $SERVICE: Certificate not found"
    fi
done

echo ""

# Send alerts if needed
if [ -n "$CRITICAL_SERVICES" ]; then
    echo "CRITICAL: Certificates expiring soon:$CRITICAL_SERVICES"
    # Send email/Slack notification
fi

if [ -n "$ALERT_SERVICES" ]; then
    echo "WARNING: Certificates need renewal:$ALERT_SERVICES"
    # Send email/Slack notification
fi
```

### Expiration Alerts

**Configure alerts:**

```bash
# Add to crontab (check daily at 9 AM)
0 9 * * * /Users/gator/devstack-core/scripts/monitor-certificates.sh | mail -s "Certificate Expiration Report" admin@example.com

# Or send to Slack
0 9 * * * /Users/gator/devstack-core/scripts/monitor-certificates.sh | /usr/local/bin/slack-cli -t "Certificate Report"
```

## Trusting Certificates

### macOS Trust

**Trust Root CA system-wide:**

```bash
# Add Root CA to system keychain
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/.config/vault/ca/ca.pem

# Verify certificate is trusted
security verify-cert -c ~/.config/vault/certs/postgres/cert.pem
```

**Remove trust:**

```bash
# Find certificate hash
CERT_HASH=$(openssl x509 -in ~/.config/vault/ca/ca.pem -noout -hash)

# Remove from keychain
sudo security delete-certificate -c "DevStack Core Root CA" /Library/Keychains/System.keychain
```

### Application Trust

**Python (requests):**

```python
import requests

# Use custom CA bundle
response = requests.get(
    'https://postgres.dev-services.local:5432',
    verify='/Users/gator/.config/vault/ca/ca.pem'
)

# Or disable verification (not recommended)
response = requests.get(
    'https://postgres.dev-services.local:5432',
    verify=False
)
```

**Node.js:**

```javascript
const https = require('https');
const fs = require('fs');

const options = {
    hostname: 'postgres.dev-services.local',
    port: 5432,
    ca: fs.readFileSync('/Users/gator/.config/vault/ca/ca.pem')
};

https.get(options, (res) => {
    // Handle response
});
```

**Go:**

```go
package main

import (
    "crypto/tls"
    "crypto/x509"
    "io/ioutil"
)

func main() {
    caCert, _ := ioutil.ReadFile("/Users/gator/.config/vault/ca/ca.pem")
    caCertPool := x509.NewCertPool()
    caCertPool.AppendCertsFromPEM(caCert)

    tlsConfig := &tls.Config{
        RootCAs: caCertPool,
    }

    // Use tlsConfig in HTTP client or database connection
}
```

### Browser Trust

**Chrome/Edge:**
1. Open `chrome://settings/certificates`
2. Click "Authorities" tab
3. Click "Import"
4. Select `~/.config/vault/ca/ca.pem`
5. Check "Trust this certificate for identifying websites"

**Firefox:**
1. Open `about:preferences#privacy`
2. Scroll to "Certificates" → "View Certificates"
3. Click "Authorities" tab
4. Click "Import"
5. Select `~/.config/vault/ca/ca.pem`
6. Check "Trust this CA to identify websites"

**Safari:**
- Uses macOS keychain (see [macOS Trust](#macos-trust))

### System-Wide Trust

**Configure system to trust CA:**

```bash
# macOS
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/.config/vault/ca/ca.pem

# Linux (Debian/Ubuntu)
sudo cp ~/.config/vault/ca/ca.pem /usr/local/share/ca-certificates/devstack-core-ca.crt
sudo update-ca-certificates

# Linux (RHEL/CentOS)
sudo cp ~/.config/vault/ca/ca.pem /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```

## Certificate Formats

### PEM Format

**PEM (Privacy Enhanced Mail)** - Base64 encoded, human-readable.

```bash
# View PEM certificate
cat ~/.config/vault/certs/postgres/cert.pem

# Output format:
# -----BEGIN CERTIFICATE-----
# MIIDXTCCAkWgAwIBAgIUa1b...
# -----END CERTIFICATE-----
```

**PEM is the default format used by DevStack Core.**

### DER Format

**DER (Distinguished Encoding Rules)** - Binary format.

```bash
# Convert PEM to DER
openssl x509 -in cert.pem -outform DER -out cert.der

# View DER certificate
openssl x509 -in cert.der -inform DER -text -noout
```

### PKCS12 Format

**PKCS12** - Password-protected container format (includes certificate + private key).

```bash
# Convert PEM to PKCS12
openssl pkcs12 -export \
    -in ~/.config/vault/certs/postgres/cert.pem \
    -inkey ~/.config/vault/certs/postgres/key.pem \
    -out postgres.p12 \
    -name "PostgreSQL Certificate"

# Extract certificate from PKCS12
openssl pkcs12 -in postgres.p12 -clcerts -nokeys -out cert.pem

# Extract key from PKCS12
openssl pkcs12 -in postgres.p12 -nocerts -nodes -out key.pem
```

### Format Conversion

**Common conversions:**

```bash
# PEM to DER
openssl x509 -in cert.pem -outform DER -out cert.der

# DER to PEM
openssl x509 -in cert.der -inform DER -outform PEM -out cert.pem

# PEM to PKCS12 (with password)
openssl pkcs12 -export -in cert.pem -inkey key.pem -out cert.p12 -passout pass:password

# PKCS12 to PEM (extract all)
openssl pkcs12 -in cert.p12 -out cert-and-key.pem -nodes
```

## Certificate Troubleshooting

### Invalid Certificates

**Problem:** Certificate validation fails.

```bash
# Verify certificate
openssl verify -CAfile ~/.config/vault/ca/ca-chain.pem ~/.config/vault/certs/postgres/cert.pem

# Common errors:
# - "unable to get local issuer certificate" → CA chain incomplete
# - "certificate has expired" → Certificate expired
# - "certificate signature failure" → Certificate corrupted
```

**Solutions:**

```bash
# Regenerate certificate
./scripts/generate-certificates.sh postgres

# Verify CA chain is complete
cat ~/.config/vault/certs/postgres/ca.pem
# Should contain intermediate CA certificate

# Test TLS connection
openssl s_client -connect localhost:5432 -starttls postgres -CAfile ~/.config/vault/ca/ca.pem
```

### Expired Certificates

**Problem:** Certificate expired.

```bash
# Check expiration
openssl x509 -in ~/.config/vault/certs/postgres/cert.pem -noout -checkend 0

# Output:
# Certificate will expire (or has expired)
```

**Solution:**

```bash
# Renew certificate
./scripts/renew-certificates.sh postgres

# Restart service
docker restart dev-postgres
```

### Trust Issues

**Problem:** Certificate not trusted by client.

```bash
# Error: "x509: certificate signed by unknown authority"
```

**Solutions:**

```bash
# Option 1: Trust Root CA system-wide
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/.config/vault/ca/ca.pem

# Option 2: Provide CA certificate to application
export SSL_CERT_FILE=~/.config/vault/ca/ca.pem

# Option 3: Configure application to use CA
# (see [Client Configuration](#client-configuration))
```

### Handshake Failures

**Problem:** TLS handshake fails.

```bash
# Test handshake
openssl s_client -connect localhost:5432 -starttls postgres

# Common errors:
# - "alert handshake failure" → Cipher mismatch
# - "no protocols available" → TLS version mismatch
# - "certificate verify failed" → Trust issue
```

**Solutions:**

```bash
# Check supported ciphers
openssl s_client -connect localhost:5432 -starttls postgres -cipher 'HIGH:!aNULL'

# Check TLS version
openssl s_client -connect localhost:5432 -starttls postgres -tls1_2

# Verify certificate chain
openssl s_client -connect localhost:5432 -starttls postgres -showcerts
```

## Client Configuration

### Configuring Applications

**PostgreSQL client (psql):**

```bash
# Using psql with TLS
psql "postgresql://postgres:password@localhost:5432/myapp?sslmode=verify-full&sslrootcert=$HOME/.config/vault/ca/ca.pem"

# Or with environment variables
export PGSSLMODE=verify-full
export PGSSLROOTCERT=~/.config/vault/ca/ca.pem
psql -h localhost -U postgres
```

**MySQL client:**

```bash
# Using mysql with TLS
mysql -u root -h localhost --ssl-mode=REQUIRED --ssl-ca=~/.config/vault/ca/ca.pem
```

**Python application:**

```python
import psycopg2

conn = psycopg2.connect(
    host="localhost",
    port=5432,
    user="postgres",
    password="password",
    sslmode="verify-full",
    sslrootcert="/Users/gator/.config/vault/ca/ca.pem"
)
```

### TLS Verification

**Verification modes:**

| Mode | Description | Security |
|------|-------------|----------|
| disable | No TLS | None |
| allow | TLS if available | Low |
| prefer | Prefer TLS, fallback to non-TLS | Low |
| require | Require TLS | Medium (no hostname verification) |
| verify-ca | Verify CA certificate | High |
| verify-full | Verify CA + hostname | Highest (recommended) |

**Recommended configuration:**

```bash
# PostgreSQL
PGSSLMODE=verify-full
PGSSLROOTCERT=~/.config/vault/ca/ca.pem

# MySQL
--ssl-mode=VERIFY_CA
--ssl-ca=~/.config/vault/ca/ca.pem
```

### Certificate Pinning

**Pin certificate for enhanced security:**

```python
import hashlib
import ssl

# Calculate certificate fingerprint
def get_cert_fingerprint(cert_path):
    with open(cert_path, 'rb') as f:
        cert_data = f.read()
    return hashlib.sha256(cert_data).hexdigest()

# Verify pinned certificate
expected_fingerprint = "abc123..."
actual_fingerprint = get_cert_fingerprint("/path/to/cert.pem")

if actual_fingerprint != expected_fingerprint:
    raise Exception("Certificate pinning failed!")
```

## Certificate Revocation

### Revoking Compromised Certificates

**Revoke certificate in Vault:**

```bash
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# Get certificate serial number
SERIAL=$(openssl x509 -in ~/.config/vault/certs/postgres/cert.pem -noout -serial | cut -d= -f2)

# Revoke certificate
vault write pki_int/revoke serial_number="$SERIAL"

# Verify revocation
vault read pki_int/cert/$SERIAL
```

### CRL Management

**Certificate Revocation List (CRL):**

```bash
# Fetch CRL
vault read pki_int/crl/pem

# Save CRL to file
vault read -field=certificate pki_int/crl/pem > crl.pem

# View CRL
openssl crl -in crl.pem -noout -text

# Configure service to check CRL
# (Add to service configuration)
```

### OCSP Configuration

**Online Certificate Status Protocol** (not implemented by default in DevStack Core):

```bash
# Configure OCSP responder (Vault PKI supports OCSP)
vault write pki_int/config/urls \
    ocsp_servers="http://localhost:8200/v1/pki_int/ocsp"

# Test OCSP
openssl ocsp \
    -issuer ~/.config/vault/ca/ca.pem \
    -cert ~/.config/vault/certs/postgres/cert.pem \
    -url http://localhost:8200/v1/pki_int/ocsp
```

## Best Practices

1. **Renew certificates 60 days before expiration:**
   ```bash
   # Set up monitoring
   ./scripts/monitor-certificates.sh
   ```

2. **Use 2048-bit RSA keys (minimum):**
   ```bash
   # 4096-bit for Root CA, 2048-bit for service certificates
   ```

3. **Enable TLS 1.2 or higher:**
   ```bash
   # Disable TLS 1.0 and 1.1
   ssl_min_protocol_version = 'TLSv1.2'
   ```

4. **Use strong cipher suites:**
   ```bash
   ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'
   ```

5. **Verify certificate chains:**
   ```bash
   openssl verify -CAfile ca-chain.pem cert.pem
   ```

6. **Backup certificates and keys:**
   ```bash
   # Included in automated backup
   cp -r ~/.config/vault ~/vault-backup
   ```

7. **Rotate certificates annually:**
   ```bash
   # Schedule annual rotation
   0 3 1 1 * /Users/gator/devstack-core/scripts/rotate-certificates.sh
   ```

8. **Monitor certificate expiration:**
   ```bash
   # Daily checks
   0 9 * * * /Users/gator/devstack-core/scripts/monitor-certificates.sh
   ```

9. **Test certificate deployment:**
   ```bash
   # Verify after generation
   ./scripts/verify-certificates.sh
   ```

10. **Document certificate procedures:**
    - Keep runbooks updated
    - Test procedures quarterly
    - Train team on certificate operations

## Automation

**Complete certificate automation script:**

```bash
#!/bin/bash
# Save as: /Users/gator/devstack-core/scripts/cert-automation.sh

# Automated certificate lifecycle management

RENEWAL_THRESHOLD=60
ALERT_THRESHOLD=30

echo "=== Certificate Lifecycle Automation ==="
echo "Run date: $(date)"

# 1. Check expiration
echo "Checking certificate expiration..."
RENEWAL_NEEDED=false

for SERVICE in postgres mysql redis-1 redis-2 redis-3 rabbitmq mongodb; do
    CERT_FILE="$HOME/.config/vault/certs/$SERVICE/cert.pem"

    if [ -f "$CERT_FILE" ]; then
        EXPIRY=$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
        EXPIRY_EPOCH=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$EXPIRY" +%s)
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))

        if [ $DAYS_LEFT -lt $RENEWAL_THRESHOLD ]; then
            echo "  → $SERVICE: $DAYS_LEFT days (renewal needed)"
            RENEWAL_NEEDED=true
        elif [ $DAYS_LEFT -lt $ALERT_THRESHOLD ]; then
            echo "  ⚠️  $SERVICE: $DAYS_LEFT days (alert)"
        fi
    fi
done

# 2. Renew if needed
if [ "$RENEWAL_NEEDED" = true ]; then
    echo "Renewing certificates..."
    ./scripts/generate-certificates.sh

    echo "Restarting services..."
    docker restart dev-postgres dev-mysql dev-redis-1 dev-redis-2 dev-redis-3 dev-rabbitmq dev-mongodb

    echo "✓ Certificate renewal complete"
    echo "$(date): Automated certificate renewal" >> ~/cert-automation.log
fi

# 3. Verify certificates
echo "Verifying certificates..."
for SERVICE in postgres mysql redis-1 redis-2 redis-3 rabbitmq mongodb; do
    CERT_FILE="$HOME/.config/vault/certs/$SERVICE/cert.pem"
    openssl verify -CAfile ~/.config/vault/ca/ca-chain.pem "$CERT_FILE" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "  ✓ $SERVICE"
    else
        echo "  ✗ $SERVICE (invalid)"
    fi
done

echo "=== Automation Complete ==="
```

**Schedule automation:**

```bash
# Add to crontab (run daily)
0 3 * * * /Users/gator/devstack-core/scripts/cert-automation.sh >> ~/cert-automation.log 2>&1
```

## Reference

### Related Wiki Pages

- [TLS Configuration](TLS-Configuration) - TLS setup guide
- [Vault Integration](Vault-Integration) - Vault usage
- [Security Hardening](Security-Hardening) - Security practices
- [Secrets Rotation](Secrets-Rotation) - Credential rotation
- [Service Configuration](Service-Configuration) - Service details

### Certificate Locations

```
Certificate Storage Structure:

~/.config/vault/
├── ca/
│   ├── ca.pem              # Root CA certificate
│   └── ca-chain.pem        # Full CA chain
├── certs/
│   ├── postgres/
│   │   ├── cert.pem        # Service certificate
│   │   ├── key.pem         # Private key
│   │   └── ca.pem          # CA chain for service
│   ├── mysql/
│   ├── redis-1/
│   ├── redis-2/
│   ├── redis-3/
│   ├── rabbitmq/
│   └── mongodb/
├── keys.json               # Vault unseal keys
└── root-token              # Vault root token
```

### Quick Reference Commands

```bash
# Generate all certificates
./scripts/generate-certificates.sh

# Renew specific certificate
./scripts/renew-certificate.sh postgres

# Check expiration
openssl x509 -in ~/.config/vault/certs/postgres/cert.pem -noout -dates

# Verify certificate
openssl verify -CAfile ~/.config/vault/ca/ca-chain.pem ~/.config/vault/certs/postgres/cert.pem

# Test TLS connection
openssl s_client -connect localhost:5432 -starttls postgres -CAfile ~/.config/vault/ca/ca.pem

# Trust Root CA (macOS)
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/.config/vault/ca/ca.pem

# Monitor certificates
./scripts/monitor-certificates.sh
```

### Additional Resources

- [Vault PKI Documentation](https://www.vaultproject.io/docs/secrets/pki)
- [OpenSSL Documentation](https://www.openssl.org/docs/)
- [X.509 Certificate Standard](https://www.ietf.org/rfc/rfc5280.txt)
- [TLS Best Practices](https://wiki.mozilla.org/Security/Server_Side_TLS)
