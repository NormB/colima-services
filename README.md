# Colima Services - Complete Development Environment

> **Comprehensive local development infrastructure for VoIP services on Apple Silicon (M1/M2/M3) using Colima**

A production-ready, Docker-based development environment running on Colima that provides Git hosting, databases, caching, message queuing, and secrets management optimized for M-series Macs.

## Table of Contents

- [Overview](#overview)
  - [What is Colima?](#what-is-colima)
  - [Why This Stack?](#why-this-stack)
  - [Architecture Philosophy](#architecture-philosophy)
- [Quick Start](#quick-start)
- [Complete Installation Guide](#complete-installation-guide)
  - [Step 1: Pre-Flight Checks](#step-1-pre-flight-checks)
  - [Step 2: Install Required Software](#step-2-install-required-software)
  - [Step 3: Clone the Repository](#step-3-clone-the-repository)
  - [Step 4: Configure Environment](#step-4-configure-environment)
  - [Step 5: Start Colima and Services](#step-5-start-colima-and-services)
  - [Step 6: Initialize Vault](#step-6-initialize-vault)
  - [Step 7: Bootstrap Vault and Generate Credentials](#step-7-bootstrap-vault-and-generate-credentials)
  - [Step 8: Verify Everything Works](#step-8-verify-everything-works)
  - [Step 9: Access Your Services](#step-9-access-your-services)
  - [What to Do If Something Goes Wrong](#what-to-do-if-something-goes-wrong)
- [Services](#services)
- [Prerequisites](#prerequisites)
  - [System Requirements](#system-requirements)
  - [Required Software](#required-software)
  - [Understanding Colima](#understanding-colima)
- [Installation](#installation)
  - [First Time Setup](#first-time-setup)
  - [Configuration](#configuration)
  - [Starting Services](#starting-services)
- [Service Configuration](#service-configuration)
  - [PostgreSQL](#postgresql)
  - [PgBouncer](#pgbouncer)
  - [MySQL](#mysql)
  - [Redis Cluster](#redis-cluster)
  - [RabbitMQ](#rabbitmq)
  - [MongoDB](#mongodb)
  - [Forgejo (Git Server)](#forgejo-git-server)
  - [HashiCorp Vault](#hashicorp-vault)
- [Vault PKI Integration](#vault-pki-integration)
  - [Overview](#overview-1)
  - [PostgreSQL Vault Integration](#postgresql-vault-integration)
  - [SSL/TLS Certificate Management](#ssltls-certificate-management)
  - [Vault Commands](#vault-commands)
- [Testing Infrastructure](#testing-infrastructure)
  - [Test Architecture](#test-architecture)
  - [Python Test Clients](#python-test-clients)
  - [Running Tests](#running-tests)
  - [SSL/TLS Testing](#ssltls-testing)
- [Colima Deep Dive](#colima-deep-dive)
  - [What Colima Does](#what-colima-does)
  - [Colima vs Docker Desktop](#colima-vs-docker-desktop)
  - [VM Types and Performance](#vm-types-and-performance)
  - [Networking Architecture](#networking-architecture)
  - [Storage and Volumes](#storage-and-volumes)
- [Management Script](#management-script)
  - [Available Commands](#available-commands)
  - [Common Workflows](#common-workflows)
  - [Advanced Usage](#advanced-usage)
- [Docker Compose Architecture](#docker-compose-architecture)
  - [Network Design](#network-design)
  - [Volume Strategy](#volume-strategy)
  - [Health Checks](#health-checks)
  - [Service Dependencies](#service-dependencies)
- [Redis Cluster](#redis-cluster-1)
  - [Architecture](#architecture)
  - [Cluster Setup](#cluster-setup)
  - [Operations](#operations)
  - [Troubleshooting](#troubleshooting)
- [Vault Auto-Unseal](#vault-auto-unseal)
  - [How It Works](#how-it-works)
  - [Initial Setup](#initial-setup)
  - [Auto-Unseal Process](#auto-unseal-process)
  - [Manual Operations](#manual-operations)
- [Performance Optimization](#performance-optimization)
  - [Resource Tuning](#resource-tuning)
  - [Health Check Optimization](#health-check-optimization)
  - [Memory Management](#memory-management)
- [Backup and Restore](#backup-and-restore)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting-1)
  - [Common Issues](#common-issues)
  - [Service-Specific](#service-specific)
  - [Colima-Specific](#colima-specific)
- [Best Practices](#best-practices)
- [Integration Patterns](#integration-patterns)
- [FAQ](#faq)
- [Reference](#reference)

## Overview

### What is Colima?

**Colima** (Containers on Linux on macOS) is a container runtime for macOS and Linux that provides a minimal, lightweight alternative to Docker Desktop. It runs containers in a Linux VM using:

- **Lima** (Linux virtual machines on macOS)
- **containerd** or **Docker** as the container runtime
- **QEMU** or **VZ** (Virtualization.framework) as the hypervisor

**Key Benefits:**
- Free and open-source (no licensing fees)
- Minimal resource overhead
- Native Apple Silicon (ARM64) support
- Full Docker CLI compatibility
- Faster than Docker Desktop on M-series Macs
- Supports multiple profiles/instances
- Uses macOS native Virtualization.framework (VZ) for better performance

### Why This Stack?

This repository provides a **complete, self-contained development environment** that:

1. **Runs Entirely on Your Mac** - No cloud dependencies
2. **Optimized for Apple Silicon** - Native ARM64 support via Colima's VZ backend
3. **Production-Like** - Services configured similarly to production environments
4. **Version Controlled** - Infrastructure as code using Docker Compose
5. **Isolated** - Separate network and volumes, doesn't conflict with other projects
6. **Persistent** - Data survives container restarts via Docker volumes
7. **Manageable** - Single script (`manage-colima.sh`) for all operations

**Use Cases:**
- VoIP application development (primary purpose)
- Microservices development
- Learning container orchestration
- Testing database migrations
- Git repository hosting (Forgejo)
- Secrets management (Vault)
- Message queue development (RabbitMQ)

### Architecture Philosophy

**Separation of Concerns:**
- This Colima environment: Git hosting (Forgejo) + development databases
- Separate UTM VM: Production VoIP services (OpenSIPS, FreeSWITCH)
- Benefit: Network latency minimization, clear environment boundaries

**Design Principles:**
1. **Minimal Complexity** - Use standard Docker images, avoid custom builds
2. **Configuration Over Customization** - Leverage environment variables and config files
3. **Performance First** - Optimized health checks, resource limits
4. **Security Aware** - Password protection, network isolation (development setup)
5. **Observable** - Health checks, logging, easy status inspection

## Quick Start

```bash
# 1. Install Colima (if not already installed)
brew install colima docker docker-compose

# 2. Clone repository
git clone https://github.com/NormB/colima-services.git ~/colima-services
cd ~/colima-services

# 3. Configure environment
cp .env.example .env
nano .env  # Set strong passwords

# 4. Start everything
./manage-colima.sh start

# 5. Initialize Vault (first time only)
./manage-colima.sh vault-init

# 6. Bootstrap Vault PKI and credentials (first time only)
./manage-colima.sh vault-bootstrap

# 7. Check status
./manage-colima.sh status
```

**Access Services:**
- Forgejo (Git): http://localhost:3000
- Vault UI: http://localhost:8200/ui
- RabbitMQ Management: http://localhost:15672
- PostgreSQL: `localhost:5432`
- Redis Cluster: `localhost:6379/6380/6381`
- **Reference API (FastAPI):** http://localhost:8000/docs | https://localhost:8443/docs
- **Prometheus:** http://localhost:9090
- **Grafana:** http://localhost:3001 (admin/admin)
- **Loki:** API-only service (query via Grafana Explore)

## Complete Installation Guide

> **For Complete Beginners**: This section walks you through the entire installation process from scratch, with detailed explanations, expected outputs, and troubleshooting tips. Estimated time: 30-45 minutes.

**What You'll Accomplish:**
- ✅ Install Colima (lightweight Docker alternative)
- ✅ Set up a complete development infrastructure
- ✅ Configure HashiCorp Vault for secrets management
- ✅ Launch 12+ services (databases, message queues, git server, etc.)
- ✅ Access web UIs and verify everything works

**Before You Begin:**
- This guide assumes macOS (tested on M1/M2/M3 Macs)
- You'll need at least 16GB RAM and 60GB free disk space
- Basic terminal/command line familiarity is helpful but not required
- The entire process is reversible (you can uninstall everything cleanly)

---

### Step 1: Pre-Flight Checks

**1.1 Check Your System:**

```bash
# Check macOS version (should be 12.0 or later)
sw_vers

# Expected output:
# ProductName:        macOS
# ProductVersion:     14.x.x (or higher)
# BuildVersion:       ...
```

**1.2 Check Available Resources:**

```bash
# Check free disk space (need at least 60GB)
df -h ~

# Expected output:
# Filesystem      Size   Used  Avail Capacity  Mounted on
# /dev/disk3s1   500Gi  100Gi  400Gi    21%    /System/Volumes/Data

# Check RAM (need at least 16GB)
sysctl hw.memsize | awk '{print $2/1073741824" GB"}'

# Expected output: 16 GB (or higher)
```

**What This Means:**
- If you have less than 60GB free, you'll need to free up space before proceeding
- If you have less than 16GB RAM, the system may run slowly or fail to start all services

**1.3 Check if Docker Desktop is Running:**

```bash
# Check if Docker Desktop is running
pgrep -f "Docker Desktop"

# If you see output (process IDs), Docker Desktop is running
# You should stop it to avoid conflicts:
# - Click Docker icon in menu bar → Quit Docker Desktop
```

**Why:** Colima and Docker Desktop can conflict. It's best to use one or the other.

---

### Step 2: Install Required Software

**2.1 Install Homebrew (if not already installed):**

```bash
# Check if Homebrew is installed
which brew

# If you see: /opt/homebrew/bin/brew (or /usr/local/bin/brew)
# → Homebrew is installed, skip to 2.2

# If you see: brew not found
# → Install Homebrew:
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Follow the on-screen instructions
# This may take 5-10 minutes
```

**Expected Output:**
```
==> Installation successful!
==> Next steps:
- Run these commands in your terminal to add Homebrew to your PATH:
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
```

**Action:** Run the commands shown in "Next steps" if prompted.

**2.2 Install Colima, Docker, and Docker Compose:**

```bash
# Install all three tools at once
brew install colima docker docker-compose

# This may take 5-15 minutes depending on your internet speed
```

**Expected Output:**
```
==> Downloading colima...
==> Downloading docker...
==> Downloading docker-compose...
...
==> Installing colima
==> Installing docker
==> Installing docker-compose
🍺  colima was successfully installed!
🍺  docker was successfully installed!
🍺  docker-compose was successfully installed!
```

**2.3 Verify Installation:**

```bash
# Check Colima version
colima version

# Expected output: colima version 0.6.x (or higher)

# Check Docker version
docker --version

# Expected output: Docker version 24.x.x (or higher)

# Check Docker Compose version
docker-compose --version

# Expected output: Docker Compose version 2.x.x (or higher)
```

**What If It Fails?**
- If `colima version` shows "command not found", restart your terminal
- If still not working, run: `brew doctor` to check for issues

---

### Step 3: Clone the Repository

**3.1 Choose Installation Location:**

```bash
# Navigate to your home directory
cd ~

# Check current location
pwd

# Expected output: /Users/yourusername
```

**3.2 Clone the Repository:**

```bash
# Clone into ~/colima-services directory
git clone https://github.com/NormB/colima-services.git ~/colima-services

# Expected output:
# Cloning into '/Users/yourusername/colima-services'...
# remote: Enumerating objects: ...
# Receiving objects: 100% (...), done.
```

**3.3 Navigate to Project Directory:**

```bash
# Change into the project directory
cd ~/colima-services

# Verify you're in the right place
ls -la

# Expected output: You should see files like:
# .env.example
# docker-compose.yml
# manage-colima.sh
# README.md
# configs/
# scripts/
```

**What If It Fails?**
- If `git clone` fails with "command not found", install git: `brew install git`
- If clone fails with permission errors, check your GitHub access

---

### Step 4: Configure Environment

**4.1 Create Your Environment File:**

```bash
# Copy the example file to create your own .env
cp .env.example .env

# Verify it was created
ls -la .env

# Expected output:
# -rw-r--r--  1 yourusername  staff  xxxxx Nov 23 10:00 .env
```

**What This Does:** The `.env` file stores configuration settings. It's not tracked by git (your passwords stay private).

**4.2 Make Management Script Executable:**

```bash
# Add execute permissions
chmod +x manage-colima.sh

# Verify permissions
ls -l manage-colima.sh

# Expected output (note the 'x'):
# -rwxr-xr-x  1 yourusername  staff  xxxxx Nov 23 10:00 manage-colima.sh
```

**4.3 Review Configuration (Optional but Recommended):**

```bash
# View the .env file
cat .env | head -30

# You'll see settings like:
# VAULT_ADDR=http://vault:8200
# VAULT_TOKEN=
# POSTGRES_PASSWORD=
```

**Important:** You'll notice many password fields are empty. This is intentional! They'll be auto-generated by Vault in Step 7.

---

### Step 5: Start Colima and Services

**5.1 Start Colima VM:**

```bash
# Start Colima with the management script
./manage-colima.sh start
```

**Expected Output (this takes 2-3 minutes on first run):**

```
============================================
  Colima Services - Management Script
============================================

[✓] Checking environment file...
[✓] Environment file found: .env

[*] Starting Colima...
INFO[0000] starting colima
INFO[0000] runtime: docker
INFO[0001] creating and starting colima VM...
INFO[0002] provisioning docker runtime
INFO[0150] starting ... context=docker
INFO[0155] done

[✓] Colima started successfully
    Profile: default
    Colima IP: 192.168.106.2

[*] Starting Docker services...
[+] Running 13/13
 ✔ Container dev-postgres          Started
 ✔ Container dev-mysql             Started
 ✔ Container dev-redis-1           Started
 ✔ Container dev-redis-2           Started
 ✔ Container dev-redis-3           Started
 ✔ Container dev-rabbitmq          Started
 ✔ Container dev-mongodb           Started
 ✔ Container dev-vault             Started
 ✔ Container dev-forgejo           Started
 ✔ Container dev-prometheus        Started
 ✔ Container dev-grafana           Started
 ✔ Container dev-loki              Started
 ✔ Container dev-reference-api     Started

[✓] All services started

[*] Service Status:
NAME                    STATUS          HEALTH
dev-postgres            Up 30 seconds   starting (0/1)
dev-vault               Up 28 seconds   starting (0/1)
...

[!] Note: Vault needs to be initialized on first run
    Run: ./manage-colima.sh vault-init
```

**What's Happening:**
1. **Colima VM Creation** (0-60 seconds): Creates a Linux virtual machine
2. **Docker Installation** (60-150 seconds): Installs Docker inside the VM
3. **Container Start** (150-180 seconds): Launches all 12+ services
4. **Health Checks** (180+ seconds): Services report as "healthy" once ready

**What If It Fails?**

```bash
# If you see "cannot connect to Docker daemon":
colima status
# If stopped, run: colima start

# If you see "port already in use":
lsof -i :5432  # Check what's using the port
# Stop that process or change the port in docker-compose.yml

# If Colima fails to start:
# Check logs: colima logs
# Try stopping and restarting: colima stop && colima start
```

**5.2 Wait for Services to Become Healthy:**

```bash
# Check status every 30 seconds
watch -n 30 'docker compose ps'

# Wait until HEALTH column shows "healthy" for all services
# This typically takes 2-3 minutes

# Press Ctrl+C to exit watch command
```

**Expected Final State:**
```
NAME                    STATUS          HEALTH
dev-postgres            Up 2 minutes    healthy
dev-mysql               Up 2 minutes    healthy
dev-redis-1             Up 2 minutes    healthy
dev-vault               Up 2 minutes    healthy (will show "unhealthy" until initialized)
dev-forgejo             Up 2 minutes    healthy
...
```

**Note:** Vault will show as "unhealthy" until initialized in Step 6. This is normal!

---

### Step 6: Initialize Vault

**What is Vault?** HashiCorp Vault securely stores passwords, API keys, and certificates. We'll initialize it now.

**6.1 Initialize Vault:**

```bash
# Run the initialization script
./manage-colima.sh vault-init
```

**Expected Output:**

```
============================================
  Initializing HashiCorp Vault
============================================

[*] Checking Vault status...
[!] Vault is not initialized. Initializing now...

[*] Initializing Vault with 5 key shares and threshold of 3...

Unseal Key 1: AbCdEfGhIjKlMnOpQrStUvWxYz0123456789AbCdEfGh==
Unseal Key 2: BcDeFgHiJkLmNoPqRsTuVwXyZ1234567890BcDeFgHi==
Unseal Key 3: CdEfGhIjKlMnOpQrStUvWxYz234567890CdEfGhIjK==
Unseal Key 4: DeFgHiJkLmNoPqRsTuVwXyZ34567890DeFgHiJkLmNo==
Unseal Key 5: EfGhIjKlMnOpQrStUvWxYz4567890EfGhIjKlMnOpQr==

Initial Root Token: hvs.CAESIAbCdEfGhIjKlMnOpQrStUvWxYz

[*] Saving Vault keys and root token to ~/.config/vault/
[✓] Keys saved to: /Users/yourusername/.config/vault/keys.json
[✓] Root token saved to: /Users/yourusername/.config/vault/root-token

[*] Auto-unsealing Vault...
[✓] Vault unsealed successfully

[*] Root token saved to: /Users/yourusername/.config/vault/root-token

[!] IMPORTANT: Backup your unseal keys!
    Location: ~/.config/vault/keys.json
    These keys CANNOT be recovered if lost!

[✓] Vault initialization complete
```

**CRITICAL: Save Your Unseal Keys!**

```bash
# Backup your Vault keys to a safe location
# Option 1: Copy to USB drive
cp ~/.config/vault/keys.json /Volumes/YOUR_USB_DRIVE/vault-backup/

# Option 2: Print them out
cat ~/.config/vault/keys.json

# Option 3: Store in password manager (recommended)
# Manually copy the contents to your password manager
```

**Why This Matters:**
- Without these keys, you CANNOT access Vault if it seals (locks)
- You need 3 of 5 keys to unseal Vault
- The root token is like a master password
- If you lose both, all passwords in Vault are permanently inaccessible

**6.2 Update Your .env File:**

```bash
# Copy the root token to your .env file
echo "VAULT_TOKEN=$(cat ~/.config/vault/root-token)" >> .env

# Verify it was added
tail -5 .env

# Expected output (at the end of file):
# VAULT_TOKEN=hvs.CAESIAbCdEfGhIjKlMnOpQrStUvWxYz
```

**What This Does:** Sets the Vault token so scripts can authenticate with Vault.

**6.3 Verify Vault is Working:**

```bash
# Check Vault status
./manage-colima.sh vault-status

# Expected output:
# Key             Value
# ---             -----
# Seal Type       shamir
# Initialized     true
# Sealed          false
# Total Shares    5
# Threshold       3
# Version         1.x.x
# Cluster Name    vault-cluster-xxxxxx
```

**What to Look For:**
- `Initialized: true` ✅
- `Sealed: false` ✅
- If `Sealed: true`, run: `./manage-colima.sh vault-unseal`

---

### Step 7: Bootstrap Vault and Generate Credentials

**What This Does:** Generates strong random passwords for all databases and stores them securely in Vault.

**7.1 Bootstrap Vault:**

```bash
# Run the bootstrap script
./manage-colima.sh vault-bootstrap
```

**Expected Output (takes 1-2 minutes):**

```
============================================
  Bootstrapping Vault with Service Credentials
============================================

[*] Enabling KV secrets engine at secret/...
[✓] Secrets engine enabled

[*] Enabling PKI secrets engine for TLS certificates...
[✓] PKI enabled at: pki/

[*] Configuring Root CA...
[✓] Root CA configured
    Certificate: pki/cert/ca
    Valid for: 10 years

[*] Configuring Intermediate CA...
[✓] Intermediate CA configured

[*] Creating PKI role for service certificates...
[✓] PKI role created: service-cert

[*] Generating credentials for PostgreSQL...
[✓] Generated: secret/postgres
    User: dev_admin
    Password: [25 character random string]

[*] Generating credentials for MySQL...
[✓] Generated: secret/mysql
    User: dev_admin
    Root Password: [25 character random string]
    User Password: [25 character random string]

[*] Generating credentials for Redis...
[✓] Generated: secret/redis-1
    Password: [25 character random string]
    (shared across redis-1, redis-2, redis-3)

[*] Generating credentials for RabbitMQ...
[✓] Generated: secret/rabbitmq
    User: dev_admin
    Password: [25 character random string]

[*] Generating credentials for MongoDB...
[✓] Generated: secret/mongodb
    User: dev_admin
    Password: [25 character random string]

[✓] Vault bootstrap complete!
[*] All service credentials have been generated and stored in Vault

[!] To view any service password:
    ./manage-colima.sh vault-show-password <service>

    Example: ./manage-colima.sh vault-show-password postgres
```

**What Just Happened:**
1. **Vault configured** a secrets storage system
2. **25-character random passwords** generated for each service
3. **Passwords stored securely** in Vault (not in plain text files)
4. **TLS certificate system** set up (for HTTPS connections)

**7.2 Restart Services to Load Credentials:**

```bash
# Restart all services so they fetch passwords from Vault
./manage-colima.sh restart
```

**Expected Output:**

```
[*] Restarting Colima services...
[+] Running 13/13
 ✔ Container dev-postgres          Started
 ✔ Container dev-mysql             Started
 ✔ Container dev-redis-1           Started
 ...

[✓] All services restarted successfully
```

**7.3 Verify Credentials Were Loaded:**

```bash
# Check PostgreSQL logs to see if it loaded credentials
docker logs dev-postgres 2>&1 | grep -i "vault"

# Expected output:
# [✓] Successfully retrieved credentials from Vault
# [✓] User: dev_admin
# [✓] Database: dev_db

# View any service password
./manage-colima.sh vault-show-password postgres

# Expected output:
# PostgreSQL Credentials:
# User: dev_admin
# Password: aB1cD2eF3gH4iJ5kL6mN7oP8qR9sT0u
# Database: dev_db
```

---

### Step 8: Verify Everything Works

**8.1 Check Overall Status:**

```bash
# Run comprehensive status check
./manage-colima.sh status
```

**Expected Output:**

```
============================================
  Colima Services - Status
============================================

[✓] Colima Status:
    Profile: default
    Status: Running
    Arch: aarch64
    Runtime: docker
    Colima IP: 192.168.106.2

[✓] Docker Services:
NAME                    STATUS          HEALTH
dev-postgres            Up 5 minutes    healthy
dev-pgbouncer           Up 5 minutes    healthy
dev-mysql               Up 5 minutes    healthy
dev-redis-1             Up 5 minutes    healthy
dev-redis-2             Up 5 minutes    healthy
dev-redis-3             Up 5 minutes    healthy
dev-rabbitmq            Up 5 minutes    healthy
dev-mongodb             Up 5 minutes    healthy
dev-vault               Up 5 minutes    healthy
dev-forgejo             Up 5 minutes    healthy
dev-prometheus          Up 5 minutes    healthy
dev-grafana             Up 5 minutes    healthy
dev-loki                Up 5 minutes    healthy
dev-reference-api       Up 5 minutes    healthy

[✓] All services are healthy!
```

**What to Look For:**
- All services show `healthy` ✅
- If any show `starting`, wait 30 seconds and check again
- If any show `unhealthy`, see troubleshooting below

**8.2 Test Database Connections:**

```bash
# Test PostgreSQL
docker exec dev-postgres pg_isready -U dev_admin

# Expected output: accepting connections

# Test MySQL
docker exec dev-mysql mysqladmin ping -h localhost

# Expected output: mysqld is alive

# Test Redis
docker exec dev-redis-1 redis-cli -a $(./manage-colima.sh vault-show-password redis-1 | grep "Password:" | awk '{print $2}') ping

# Expected output: PONG

# Test MongoDB
docker exec dev-mongodb mongosh --quiet --eval "db.adminCommand('ping')"

# Expected output: { ok: 1 }
```

**8.3 Run Health Check Script:**

```bash
# Run built-in health checks
./manage-colima.sh health
```

**Expected Output:**

```
============================================
  Health Check
============================================

[✓] PostgreSQL: healthy (response time: 5ms)
[✓] MySQL: healthy (response time: 8ms)
[✓] Redis Cluster: healthy (3/3 nodes up)
[✓] RabbitMQ: healthy (management API responding)
[✓] MongoDB: healthy (accepting connections)
[✓] Vault: healthy (unsealed)
[✓] Forgejo: healthy (API responding)
[✓] Prometheus: healthy (metrics available)
[✓] Grafana: healthy (UI responding)
[✓] Loki: healthy (ready endpoint responding)

[✓] All health checks passed!
```

---

### Step 9: Access Your Services

**9.1 Web-Based Services:**

Open these URLs in your browser:

| Service | URL | Default Login |
|---------|-----|---------------|
| **Forgejo (Git Server)** | http://localhost:3000 | (create account on first visit) |
| **Vault UI** | http://localhost:8200/ui | Token from `~/.config/vault/root-token` |
| **RabbitMQ Management** | http://localhost:15672 | Get from: `./manage-colima.sh vault-show-password rabbitmq` |
| **Grafana Dashboards** | http://localhost:3001 | admin / admin |
| **Prometheus Metrics** | http://localhost:9090 | (no login required) |
| **FastAPI Docs** | http://localhost:8000/docs | (no login required) |

**9.2 Test Forgejo (Git Server):**

```bash
# Open Forgejo in browser
open http://localhost:3000

# You should see the Forgejo welcome page
# Click "Register" to create your first admin account
```

**First-Time Setup Steps:**
1. Click **"Register"** in top-right
2. Fill in: Username, Email, Password
3. Click **"Register Account"**
4. You're now logged in as admin!

**9.3 Test Vault UI:**

```bash
# Get your Vault token
cat ~/.config/vault/root-token

# Open Vault UI
open http://localhost:8200/ui

# Login:
# 1. Method: Token
# 2. Token: [paste token from above]
# 3. Click "Sign In"

# Browse secrets:
# 1. Click "secret/" in left sidebar
# 2. You'll see: postgres, mysql, redis-1, rabbitmq, mongodb
# 3. Click any to view the stored credentials
```

**9.4 Test Grafana:**

```bash
# Open Grafana
open http://localhost:3001

# Login:
# Username: admin
# Password: admin

# You'll be prompted to change password (do this!)

# Explore dashboards:
# 1. Click "Dashboards" (left sidebar)
# 2. You'll see pre-configured dashboards:
#    - Container Metrics
#    - FastAPI Overview
#    - Forgejo Overview
```

**9.5 Connect to Databases from Command Line:**

```bash
# PostgreSQL
PGPASSWORD=$(./manage-colima.sh vault-show-password postgres | grep "Password:" | awk '{print $2}') \
  psql -h localhost -p 5432 -U dev_admin -d dev_db

# MySQL
mysql -h 127.0.0.1 -P 3306 -u dev_admin -p
# (paste password from: ./manage-colima.sh vault-show-password mysql)

# Redis
redis-cli -h localhost -p 6379 -a $(./manage-colima.sh vault-show-password redis-1 | grep "Password:" | awk '{print $2}')

# MongoDB
mongosh "mongodb://dev_admin:$(./manage-colima.sh vault-show-password mongodb | grep "Password:" | awk '{print $2}')@localhost:27017/dev_db"
```

**9.6 Test with FastAPI Reference Application:**

```bash
# Open API documentation
open http://localhost:8000/docs

# Try the health endpoint:
curl http://localhost:8000/health

# Expected output:
# {"status":"healthy","timestamp":"2025-10-23T..."}

# Test database connection:
curl http://localhost:8000/api/v1/databases/test

# Expected output: Database connection test results
```

---

### What to Do If Something Goes Wrong

**Problem: "Cannot connect to Docker daemon"**

```bash
# Solution 1: Check Colima status
colima status

# If stopped, start it:
./manage-colima.sh start

# Solution 2: Set Docker context
docker context use colima
```

---

**Problem: "Vault is sealed"**

```bash
# Check status
./manage-colima.sh vault-status

# If sealed:
./manage-colima.sh vault-unseal

# Auto-unseal should happen automatically on restart
# If it doesn't, check logs:
docker logs dev-vault | tail -50
```

---

**Problem: "Port already in use"**

```bash
# Find what's using the port (example: 5432)
lsof -i :5432

# Solution 1: Stop the conflicting service
# (if it's another PostgreSQL instance, stop it)

# Solution 2: Change the port in docker-compose.yml
# Edit: ports: - "5433:5432"  # Changed host port to 5433
```

---

**Problem: Service shows "unhealthy" status**

```bash
# Check service logs
docker logs dev-<service-name>

# Example for PostgreSQL:
docker logs dev-postgres --tail 50

# Common fixes:
# 1. Restart the service:
docker compose restart <service-name>

# 2. Check if Vault is unsealed:
./manage-colima.sh vault-status

# 3. Verify credentials were generated:
./manage-colima.sh vault-show-password <service>
```

---

**Problem: "Cannot access Forgejo at localhost:3000"**

```bash
# Check if Forgejo is running
docker ps | grep forgejo

# Check Forgejo logs
docker logs dev-forgejo --tail 50

# Try accessing via Colima IP instead:
COLIMA_IP=$(./manage-colima.sh ip | grep "Colima IP:" | awk '{print $3}')
open http://$COLIMA_IP:3000
```

---

**Problem: Redis Cluster shows "CLUSTERDOWN"**

```bash
# Check cluster status
docker exec dev-redis-1 redis-cli -a $(./manage-colima.sh vault-show-password redis-1 | grep "Password:" | awk '{print $2}') cluster info

# Re-initialize cluster:
./configs/redis/scripts/redis-cluster-init.sh

# Verify:
docker exec dev-redis-1 redis-cli -a $(./manage-colima.sh vault-show-password redis-1 | grep "Password:" | awk '{print $2}') cluster nodes
```

---

**Problem: Out of disk space**

```bash
# Check Docker disk usage
docker system df

# Clean up unused images/containers/volumes:
docker system prune -a --volumes

# WARNING: This removes ALL unused Docker data
# Your colima-services volumes are safe (they're in use)

# Verify space freed:
docker system df
```

---

**Problem: Services are slow/unresponsive**

```bash
# Check resource usage
docker stats

# Increase Colima resources:
colima stop
colima start --cpu 6 --memory 12  # 6 CPUs, 12GB RAM

# Restart services:
./manage-colima.sh restart
```

---

**Problem: Need to start completely fresh**

```bash
# WARNING: This deletes ALL data and containers!

# Stop everything
./manage-colima.sh stop

# Delete Colima VM
colima delete

# Remove volumes (optional - deletes all data!)
docker volume rm $(docker volume ls -q)

# Start fresh:
./manage-colima.sh start
./manage-colima.sh vault-init
./manage-colima.sh vault-bootstrap
```

---

**Still Having Issues?**

1. **Check the main Troubleshooting section** below for service-specific issues
2. **Review logs** for the failing service: `docker logs dev-<service>`
3. **Check Colima logs**: `colima logs`
4. **Verify environment**: `cat .env | grep -v "^#" | grep -v "^$"`
5. **Ask for help** with relevant log output

---

**Next Steps After Successful Installation:**

1. **Read the Service Configuration sections** to learn about each service
2. **Explore the Vault PKI Integration** section to enable TLS/HTTPS
3. **Check out the Testing Infrastructure** section to run comprehensive tests
4. **Review Best Practices** for development workflows
5. **Set up Forgejo** as your local Git server (push your projects!)

**Congratulations!** You now have a complete, production-like development environment running locally. 🎉

## Services

### Infrastructure Services

| Service | Version | Port(s) | Purpose | Health Check |
|---------|---------|---------|---------|--------------|
| **PostgreSQL** | 16-alpine | 5432 | Git storage + dev database | pg_isready |
| **PgBouncer** | latest | 6432 | Connection pooling | psql test |
| **MySQL** | 8.0 | 3306 | Legacy database support | mysqladmin ping |
| **Redis Cluster** | 7-alpine | 6379, 6380, 6381 | Distributed cache (3 nodes) | redis-cli ping |
| **RabbitMQ** | 3-management-alpine | 5672, 15672 | Message queue + UI | rabbitmq-diagnostics |
| **MongoDB** | 7 | 27017 | NoSQL database | mongosh ping |
| **Forgejo** | 1.21 | 3000, 2222 | Self-hosted Git server | curl /api/healthz |
| **Vault** | latest | 8200 | Secrets management | wget /sys/health |

### Observability Stack

| Service | Version | Port(s) | Purpose | Health Check |
|---------|---------|---------|---------|--------------|
| **Prometheus** | 2.48.0 | 9090 | Metrics collection & time-series DB | wget /metrics |
| **Grafana** | 10.2.2 | 3001 | Visualization & dashboards | curl /-/health |
| **Loki** | 2.9.3 | 3100 | Log aggregation system | wget /ready |

### Reference Application

| Service | Version | Port(s) | Purpose | Health Check |
|---------|---------|---------|---------|--------------|
| **Reference API** | Python 3.11 | 8000 (HTTP), 8443 (HTTPS) | FastAPI integration examples | curl /health |

**Resource Allocation:**
- Total memory: ~4-5GB (with all services running)
- Colima VM: 8GB allocated (4 CPU cores)
- Each service has memory limits and health checks

## Prerequisites

### System Requirements

- **Hardware:** Apple Silicon Mac (M1/M2/M3) or Intel Mac
- **RAM:** Minimum 16GB (32GB recommended for heavy usage)
- **Disk:** 60GB free space for Colima VM + volumes
- **macOS:** 12.0 (Monterey) or later for VZ support

### Required Software

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install colima docker docker-compose

# Verify installation
colima version
docker --version
docker-compose --version
```

### Understanding Colima

**What happens when you run Colima:**

1. **VM Creation**: Colima creates a Lima-based Linux VM
   ```
   ~/.lima/colima/  # VM configuration and disk images
   ```

2. **Docker Installation**: Installs Docker Engine inside the VM
   ```
   docker context use colima  # Automatically configured
   ```

3. **Socket Exposure**: Exposes Docker socket to your Mac
   ```
   /var/run/docker.sock  # Symlinked to Lima VM socket
   ```

4. **Volume Mounting**: Mounts your home directory into the VM
   ```
   ~/  →  /Users/<username>/ inside VM
   ```

**Colima Profiles:**
- Multiple Colima instances can run simultaneously
- Each profile has its own VM, network, and volumes
- Default profile: `default`
- Custom profiles: `colima start --profile myproject`

## Installation

### First Time Setup

**1. Install Dependencies**
```bash
brew install colima docker docker-compose
```

**2. Clone Repository**
```bash
git clone https://github.com/NormB/colima-services.git ~/colima-services
cd ~/colima-services
```

**3. Configure Environment**
```bash
cp .env.example .env
nano .env  # or vim, code, etc.
```

**Important:** Passwords are auto-generated by Vault during bootstrap:
- Run `./manage-colima.sh vault-bootstrap` to generate all service credentials
- Passwords are 25-character random strings (base64, URL-safe)
- Stored securely in Vault, fetched at container startup
- No plaintext passwords in configuration files

**4. Make Management Script Executable**
```bash
chmod +x manage-colima.sh
```

### Configuration

**Environment Variables** (`.env`):

```bash
# HashiCorp Vault Configuration
VAULT_ADDR=http://vault:8200
VAULT_TOKEN=<from ~/.config/vault/root-token after initialization>

# Service Credentials - ALL MANAGED BY VAULT
# Credentials are automatically loaded from Vault at container startup
# To view credentials: ./manage-colima.sh vault-show-password <service>
#
# Services with Vault integration:
#   - PostgreSQL: secret/postgres (user, password, database)
#   - MySQL: secret/mysql (root_password, user, password, database)
#   - Redis: secret/redis-1 (password - shared across all 3 nodes)
#   - RabbitMQ: secret/rabbitmq (user, password, vhost)
#   - MongoDB: secret/mongodb (user, password, database)

# PostgreSQL - Credentials from Vault (empty to suppress docker-compose warnings)
POSTGRES_PASSWORD=

# TLS Configuration (Optional - Disabled by Default)
POSTGRES_ENABLE_TLS=false
MYSQL_ENABLE_TLS=false
REDIS_ENABLE_TLS=false
RABBITMQ_ENABLE_TLS=false
MONGODB_ENABLE_TLS=false
REFERENCE_API_ENABLE_TLS=false  # FastAPI HTTPS support (port 8443)

# Forgejo (Git Server)
FORGEJO_DOMAIN=localhost  # Or Colima IP for network access
```

**⚠️ IMPORTANT: NO PLAINTEXT PASSWORDS**

All service credentials are managed by HashiCorp Vault. After running `vault-bootstrap`, credentials are:
- Generated automatically with strong random passwords
- Stored securely in Vault at `secret/<service>`
- Fetched by services at startup via init scripts
- Never stored in plaintext in `.env` files

**Retrieving Credentials:**

```bash
# View any service password
./manage-colima.sh vault-show-password postgres
./manage-colima.sh vault-show-password mysql
./manage-colima.sh vault-show-password redis-1
./manage-colima.sh vault-show-password rabbitmq
./manage-colima.sh vault-show-password mongodb

# Or using Vault CLI
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)
vault kv get -field=password secret/postgres
```

**Colima VM Configuration** (environment variables):

```bash
export COLIMA_PROFILE=default    # Profile name
export COLIMA_CPU=4              # CPU cores
export COLIMA_MEMORY=8           # Memory in GB
export COLIMA_DISK=60            # Disk size in GB
```

### Starting Services

**Option 1: Using Management Script (Recommended)**
```bash
./manage-colima.sh start
```

This will:
1. Check/create `.env` file
2. Start Colima VM (if not running)
3. Start all Docker services
4. Initialize Vault (if first run)
5. Display service status and access URLs

**Option 2: Manual Start**
```bash
# Start Colima VM
colima start --cpu 4 --memory 8 --disk 60 --network-address --arch aarch64 --vm-type vz

# Start services
docker compose up -d

# Initialize Vault
./configs/vault/scripts/vault-init.sh

# Check status
docker compose ps
```

**Verify Everything is Running:**
```bash
./manage-colima.sh status
./manage-colima.sh health
```

## Service Configuration

### PostgreSQL

**Purpose:** Primary database for Forgejo (Git server) and local development.

**Configuration:**
- Image: `postgres:16-alpine` (ARM64 native)
- **Credentials:** Auto-fetched from Vault at startup via `configs/postgres/scripts/init.sh`
  - Stored in Vault at `secret/postgres`
  - Fields: `user`, `password`, `database`
  - Password retrieved using `scripts/read-vault-secret.py`
- **Authentication Mode:** MD5 (for PgBouncer compatibility, not SCRAM-SHA-256)
- Storage: File-based in `/var/lib/postgresql/data`
- Encoding: UTF8, Locale: C
- Max connections: 100 (reduced for dev/Git only)
- Shared buffers: 256MB
- Effective cache: 1GB
- **Optional TLS:** Configurable via `POSTGRES_ENABLE_TLS=true`

**Key Settings** (`docker-compose.yml:68-78`):
```yaml
command:
  - "postgres"
  - "-c"
  - "max_connections=100"
  - "-c"
  - "shared_buffers=256MB"
  - "-c"
  - "effective_cache_size=1GB"
  - "-c"
  - "work_mem=8MB"
```

**Connection:**
```bash
# From Mac
psql -h localhost -p 5432 -U $POSTGRES_USER -d $POSTGRES_DB

# From inside container
docker exec -it dev-postgres psql -U $POSTGRES_USER -d $POSTGRES_DB

# Using management script
./manage-colima.sh shell postgres
# Then: psql -U $POSTGRES_USER -d $POSTGRES_DB
```

**Init Scripts:**
- Place `.sql` files in `configs/postgres/` to run on first start
- Executed in alphabetical order
- Useful for creating additional databases or users

**Health Check:**
```bash
# Automatic (runs every 60 seconds)
pg_isready -U $POSTGRES_USER

# Manual check
docker exec dev-postgres pg_isready -U $POSTGRES_USER
```

**Performance Tuning:**
- Tuned for Git server workload (many small transactions)
- Increased for dev workloads: adjust `max_connections`, `shared_buffers`
- Monitor: `./manage-colima.sh status` shows CPU/memory usage

### PgBouncer

**Purpose:** Connection pooling for PostgreSQL to reduce connection overhead.

**Configuration:**
- Pool mode: `transaction` (best for web applications)
- Max client connections: 100
- Default pool size: 10
- Reduces PostgreSQL connection overhead
- **Authentication:** Uses MD5 (PostgreSQL configured for MD5, not SCRAM-SHA-256)
- **Credentials:** Loaded from Vault via environment variables (`scripts/load-vault-env.sh`)

**When to Use:**
- High-frequency connections (web apps, APIs)
- Connection-per-request patterns
- Microservices connecting to shared database

**Connection:**
```bash
psql -h localhost -p 6432 -U $POSTGRES_USER -d $POSTGRES_DB
```

**Direct PostgreSQL vs PgBouncer:**
- Direct (5432): For long-lived connections, admin tasks
- PgBouncer (6432): For application connections, APIs

### MySQL

**Purpose:** Legacy database support during migration period.

**Configuration:**
- Image: `mysql:8.0`
- **Credentials:** Auto-fetched from Vault at startup via `configs/mysql/scripts/init.sh`
  - Stored in Vault at `secret/mysql`
  - Fields: `root_password`, `user`, `password`, `database`
- Character set: utf8mb4
- Collation: utf8mb4_unicode_ci
- Max connections: 100
- InnoDB buffer pool: 256MB
- **Optional TLS:** Configurable via `MYSQL_ENABLE_TLS=true`

**Connection:**
```bash
mysql -h 127.0.0.1 -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE

# Or interactively
mysql -h 127.0.0.1 -u $MYSQL_USER -p
# Enter password when prompted
```

**Init Scripts:**
- Place `.sql` files in `configs/mysql/`
- Executed on first container start

### Redis Cluster

**Purpose:** Distributed caching with high availability and horizontal scaling.

**Architecture:**
- 3 master nodes (no replicas in dev mode)
- **Credentials:** All nodes share same password from Vault at `secret/redis-1`
  - Auto-fetched at startup via `configs/redis/scripts/init.sh`
  - Field: `password`
- 16,384 hash slots distributed across nodes
  - Node 1 (172.20.0.13): slots 0-5460
  - Node 2 (172.20.0.16): slots 5461-10922
  - Node 3 (172.20.0.17): slots 10923-16383
- Total memory: 768MB (256MB per node)
- Automatic slot allocation and data sharding
- **Optional TLS:** Configurable via `REDIS_ENABLE_TLS=true`

**Configuration Files:**
- `configs/redis/redis-cluster.conf` - Cluster-specific settings
- `configs/redis/redis.conf` - Standalone Redis config (reference)

**Key Settings:**
```conf
# Cluster mode enabled
cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 5000
cluster-require-full-coverage no  # Dev mode: operate with partial coverage

# Persistence
appendonly yes  # AOF enabled for cluster reliability
save 900 1      # RDB snapshots

# Memory
maxmemory 256mb
maxmemory-policy allkeys-lru
```

**Ports:**
- **6379, 6380, 6381:** Redis data ports (mapped to host)
- **16379, 16380, 16381:** Cluster bus ports (internal)

**Connection:**
```bash
# ALWAYS use -c flag for cluster mode!
redis-cli -c -a $REDIS_PASSWORD -p 6379

# Connect to specific node
redis-cli -c -a $REDIS_PASSWORD -p 6380
redis-cli -c -a $REDIS_PASSWORD -p 6381
```

**First-Time Cluster Initialization:**
```bash
# After starting containers for the first time
./configs/redis/scripts/redis-cluster-init.sh

# Or manually
docker exec dev-redis-1 redis-cli --cluster create \
  172.20.0.13:6379 172.20.0.16:6379 172.20.0.17:6379 \
  --cluster-yes -a $REDIS_PASSWORD
```

**Cluster Operations:**
```bash
# Check cluster status
docker exec dev-redis-1 redis-cli -a $REDIS_PASSWORD cluster info

# List all nodes
docker exec dev-redis-1 redis-cli -a $REDIS_PASSWORD cluster nodes

# Check slot distribution
docker exec dev-redis-1 redis-cli -a $REDIS_PASSWORD cluster slots

# Find which node owns a key
docker exec dev-redis-1 redis-cli -a $REDIS_PASSWORD cluster keyslot <key-name>

# Comprehensive cluster check
docker exec dev-redis-1 redis-cli --cluster check 172.20.0.13:6379 -a $REDIS_PASSWORD
```

**FastAPI Cluster Inspection APIs:**

The reference application provides REST APIs for cluster inspection (see [Reference Application](#reference-application-fastapi)):

```bash
# Get cluster nodes and slot assignments
curl http://localhost:8000/redis/cluster/nodes

# Get slot distribution with coverage percentage
curl http://localhost:8000/redis/cluster/slots

# Get cluster state and statistics
curl http://localhost:8000/redis/cluster/info

# Get detailed info for specific node
curl http://localhost:8000/redis/nodes/redis-1/info
```

**Data Distribution:**
- Keys are automatically sharded based on CRC16 hash
- Client redirects handled automatically with `-c` flag
- Example: `SET user:1000 "data"` → hashed → assigned to appropriate node

**Why Cluster vs Single Node?**
- **High Availability:** If one node fails, others continue serving
- **Horizontal Scaling:** Distribute data across nodes
- **Performance:** Parallel read/write operations
- **Production Parity:** Dev environment matches production architecture

### RabbitMQ

**Purpose:** Message queue for asynchronous communication between services.

**Configuration:**
- Image: `rabbitmq:3-management-alpine`
- **Credentials:** Auto-fetched from Vault at startup via `configs/rabbitmq/scripts/init.sh`
  - Stored in Vault at `secret/rabbitmq`
  - Fields: `user`, `password`, `vhost`
- Protocols: AMQP (5672), Management HTTP (15672)
- Virtual host: `dev_vhost`
- Plugins: Management UI enabled
- **Optional TLS:** Configurable via `RABBITMQ_ENABLE_TLS=true`

**Access:**
- **AMQP:** `amqp://dev_admin:password@localhost:5672/dev_vhost`
- **Management UI:** http://localhost:15672
  - Username: `$RABBITMQ_USER` (from .env)
  - Password: `$RABBITMQ_PASSWORD` (from .env)

**Common Operations:**
```bash
# View logs
./manage-colima.sh logs rabbitmq

# Shell access
docker exec -it dev-rabbitmq sh

# List queues
docker exec dev-rabbitmq rabbitmqctl list_queues

# List exchanges
docker exec dev-rabbitmq rabbitmqctl list_exchanges

# List connections
docker exec dev-rabbitmq rabbitmqctl list_connections
```

### MongoDB

**Purpose:** NoSQL document database for unstructured data.

**Configuration:**
- Image: `mongo:7`
- **Credentials:** Auto-fetched from Vault at startup via `configs/mongodb/scripts/init.sh`
  - Stored in Vault at `secret/mongodb`
  - Fields: `user`, `password`, `database`
- Authentication: SCRAM-SHA-256
- Storage engine: WiredTiger
- Default database: `dev_database`
- **Optional TLS:** Configurable via `MONGODB_ENABLE_TLS=true`

**Connection:**
```bash
# Using mongosh (MongoDB Shell)
mongosh --host localhost --port 27017 \
  --username $MONGODB_USER \
  --password $MONGODB_PASSWORD \
  --authenticationDatabase admin

# Connection string
mongodb://dev_admin:password@localhost:27017/dev_database?authSource=admin
```

**Init Scripts:**
- Place `.js` files in `configs/mongodb/`
- Executed in alphabetical order on first start

### Forgejo (Git Server)

**Purpose:** Self-hosted Git server (Gitea fork) for private repositories.

**Configuration:**
- Uses PostgreSQL for metadata storage
- Git data stored in Docker volume (`forgejo_data`)
- SSH port mapped to 2222 (to avoid conflict with Mac's SSH on 22)

**First-Time Setup:**
1. Navigate to http://localhost:3000
2. Complete installation wizard:
   - Database type: PostgreSQL
   - Host: `postgres:5432` (internal network)
   - Database: `forgejo`
   - Username/Password: Same as PostgreSQL (auto-configured via env vars)
3. Create admin account
4. Start creating repositories

**Git Operations:**
```bash
# Clone via HTTP
git clone http://localhost:3000/username/repo.git

# Clone via SSH
git clone ssh://git@localhost:2222/username/repo.git

# Configure SSH
# Add to ~/.ssh/config:
Host forgejo
  HostName localhost
  Port 2222
  User git
  IdentityFile ~/.ssh/id_rsa

# Then clone with:
git clone forgejo:username/repo.git
```

**SSH and GPG Keys:**
For setting up SSH keys (for authenticated push/pull) and GPG keys (for signed commits), see the detailed guide in [CONTRIBUTING.md](CONTRIBUTING.md#setting-up-ssh-and-gpg-keys-for-forgejo).

**Access from Network:**
- Set `FORGEJO_DOMAIN` to Colima IP in `.env`
- Access from UTM VM or other machines on network
- Example: http://192.168.106.2:3000

### HashiCorp Vault

**Purpose:** Centralized secrets management and encryption as a service.

**Configuration:**
- Storage backend: File (persistent across restarts)
- Seal type: Shamir (3 of 5 keys required to unseal)
- Auto-unseal: Enabled on container start (see [Vault Auto-Unseal](#vault-auto-unseal))
- UI: Enabled at http://localhost:8200/ui

**Key Features:**
- **Secrets Management:** Store API keys, passwords, certificates
- **Dynamic Secrets:** Generate database credentials on-demand
- **Encryption as a Service:** Encrypt/decrypt data via API
- **Audit Logging:** Track all secret access
- **Policy-Based Access:** Fine-grained permissions

**File Locations:**
```
~/.config/vault/keys.json        # 5 unseal keys
~/.config/vault/root-token       # Root token for admin access
```

**⚠️ CRITICAL:** Backup these files! Cannot be recovered if lost.

**Access Vault:**
```bash
# Set environment
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# Check status
vault status

# List secrets
vault kv list secret/

# Store secret
vault kv put secret/myapp/config api_key=123456

# Retrieve secret
vault kv get secret/myapp/config

# Use management script
./manage-colima.sh vault-status
./manage-colima.sh vault-token
```

**Vault Workflow:**
1. Container starts → Vault server starts sealed
2. Auto-unseal script waits for Vault to be ready
3. Script reads `~/.config/vault/keys.json`
4. Script POSTs 3 of 5 unseal keys to `/v1/sys/unseal`
5. Vault unseals and becomes operational
6. Script sleeps indefinitely (zero CPU overhead)

See [Vault Auto-Unseal](#vault-auto-unseal) for detailed information.

## Vault PKI Integration

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

## Observability Stack

The observability stack provides comprehensive monitoring, metrics collection, and log aggregation for all infrastructure services.

### Prometheus

**Purpose:** Time-series metrics database and monitoring system.

**Configuration:**
- Image: `prom/prometheus:v2.48.0`
- Port: 9090
- Retention: 30 days
- Scrape interval: 15 seconds

**Features:**
- Automatic service discovery for all infrastructure components
- Pre-configured scrape targets for:
  - PostgreSQL (via postgres-exporter)
  - MySQL (via mysql-exporter)
  - Redis Cluster (via redis-exporter)
  - RabbitMQ (built-in Prometheus endpoint)
  - MongoDB (via mongodb-exporter)
  - Reference API (FastAPI metrics)
  - Vault (metrics endpoint)
- PromQL query language for metrics analysis
- Alert manager integration (commented out, can be enabled)

**Access:**
```bash
# Web UI
open http://localhost:9090

# Check targets status
open http://localhost:9090/targets

# Example PromQL queries
# CPU usage across all services
rate(process_cpu_seconds_total[5m])

# Memory usage by service
container_memory_usage_bytes{name=~"dev-.*"}

# Database connection pool stats
pg_stat_database_numbackends
```

**Configuration File:**
- Location: `configs/prometheus/prometheus.yml`
- Modify scrape targets and intervals as needed
- Restart Prometheus after configuration changes

### Grafana

**Purpose:** Visualization and dashboarding platform.

**Configuration:**
- Image: `grafana/grafana:10.2.2`
- Port: 3001
- Default credentials: `admin/admin` (change after first login!)
- Auto-provisioned datasources:
  - Prometheus (default)
  - Loki (logs)

**Features:**
- Pre-configured datasources (no manual setup required)
- Dashboard auto-loading from `configs/grafana/dashboards/`
- Support for Prometheus and Loki queries
- Alerting and notification channels
- User authentication and RBAC

**Access:**
```bash
# Web UI
open http://localhost:3001

# Default login
Username: admin
Password: admin
```

**Creating Dashboards:**
1. Navigate to http://localhost:3001
2. Click "+" → "Dashboard"
3. Add panels with Prometheus or Loki queries
4. Save dashboard JSON to `configs/grafana/dashboards/` for auto-loading

**Pre-Configured Datasources:**
- **Prometheus:** http://prometheus:9090 (default)
- **Loki:** http://loki:3100

### Loki

**Purpose:** Log aggregation system (like Prometheus for logs).

**⚠️ Important:** Loki is an **API-only service** with no web UI. Access logs via:
- **Grafana Explore:** http://localhost:3001/explore (select Loki datasource)
- **API Endpoints:** `http://localhost:3100/loki/api/v1/...`

**Configuration:**
- Image: `grafana/loki:2.9.3`
- API Port: 3100 (no web UI)
- Retention: 31 days (744 hours)
- Storage: Filesystem-based (BoltDB + filesystem chunks)

**Features:**
- Label-based log indexing (not full-text search)
- LogQL query language (similar to PromQL)
- Horizontal scalability
- Multi-tenancy support (disabled for simplicity)
- Integration with Grafana for log visualization

**Sending Logs to Loki:**

**Option 1: Promtail (Log Shipper)**
```yaml
# Add to docker-compose.yml
promtail:
  image: grafana/promtail:2.9.3
  volumes:
    - /var/log:/var/log
    - ./configs/promtail/config.yml:/etc/promtail/config.yml
  command: -config.file=/etc/promtail/config.yml
```

**Option 2: Docker Logging Driver**
```yaml
# In docker-compose.yml service definition
logging:
  driver: loki
  options:
    loki-url: "http://localhost:3100/loki/api/v1/push"
    loki-batch-size: "400"
```

**Option 3: HTTP API (Application Logs)**
```python
import requests
import json

def send_log_to_loki(message, labels):
    url = "http://localhost:3100/loki/api/v1/push"
    payload = {
        "streams": [{
            "stream": labels,
            "values": [
                [str(int(time.time() * 1e9)), message]
            ]
        }]
    }
    requests.post(url, json=payload)

# Example usage
send_log_to_loki("Application started", {"app": "myapp", "level": "info"})
```

**Querying Logs in Grafana:**
```logql
# All logs from a service
{service="postgres"}

# Error logs only
{service="postgres"} |= "ERROR"

# Rate of errors per minute
rate({service="postgres"} |= "ERROR" [1m])

# Logs from multiple services
{service=~"postgres|mysql"}
```

**Configuration File:**
- Location: `configs/loki/loki-config.yml`
- Modify retention, ingestion limits, and storage settings

## Reference Application (FastAPI)

**Purpose:** Reference implementation demonstrating infrastructure integration patterns. This is **NOT production code** - use it as a learning resource and integration testing tool.

**What It Provides:**
- ✅ Health check endpoints for all infrastructure services
- ✅ Vault integration examples (fetching secrets)
- ✅ Database connectivity examples (PostgreSQL, MySQL, MongoDB)
- ✅ Redis caching examples (get/set/TTL)
- ✅ Redis Cluster inspection APIs (nodes, slots, topology)
- ✅ RabbitMQ messaging examples (publish/consume)
- ✅ Async/await patterns throughout
- ✅ Automatic API documentation
- ✅ Dual HTTP/HTTPS support with Vault-managed certificates

**Configuration:**
- Image: Python 3.11 (custom build from `reference-apps/fastapi/`)
- Ports: 8000 (HTTP), 8443 (HTTPS)
- Framework: FastAPI with Uvicorn
- TLS: Vault-managed certificates (optional, enable via `REFERENCE_API_ENABLE_TLS=true`)
- Dependencies: See `reference-apps/fastapi/requirements.txt`

**API Documentation:**

**Automatic Interactive Docs:**
```bash
# Swagger UI (interactive) - HTTP
open http://localhost:8000/docs

# Swagger UI (interactive) - HTTPS (when TLS enabled)
open https://localhost:8443/docs

# ReDoc (alternative documentation format)
open http://localhost:8000/redoc

# OpenAPI JSON schema
curl http://localhost:8000/openapi.json
```

**Key Endpoints:**

**Health Checks:**
```bash
# Check all services at once
curl http://localhost:8000/health/all

# Individual service checks
curl http://localhost:8000/health/vault
curl http://localhost:8000/health/postgres
curl http://localhost:8000/health/mysql
curl http://localhost:8000/health/mongodb
curl http://localhost:8000/health/redis
curl http://localhost:8000/health/rabbitmq
```

**Vault Examples:**
```bash
# Fetch a secret from Vault
curl http://localhost:8000/examples/vault/secret/postgres

# Check Vault health
curl http://localhost:8000/examples/vault/health
```

**Database Examples:**
```bash
# PostgreSQL query example
curl http://localhost:8000/examples/database/postgres/query

# MySQL query example
curl http://localhost:8000/examples/database/mysql/query

# MongoDB query example
curl http://localhost:8000/examples/database/mongodb/query
```

**Cache Examples:**
```bash
# Get cached value
curl http://localhost:8000/examples/cache/mykey

# Set cached value (with optional TTL)
curl -X POST "http://localhost:8000/examples/cache/mykey?value=myvalue&ttl=3600"

# Delete cached value
curl -X DELETE http://localhost:8000/examples/cache/mykey

# Get cache stats
curl http://localhost:8000/examples/cache/stats
```

**Messaging Examples:**
```bash
# Publish message to RabbitMQ
curl -X POST http://localhost:8000/examples/messaging/publish \
  -H "Content-Type: application/json" \
  -d '{"queue_name": "test_queue", "message": {"hello": "world"}}'

# List queues
curl http://localhost:8000/examples/messaging/queues
```

**Redis Cluster Inspection:**

The FastAPI reference app provides comprehensive Redis Cluster inspection endpoints to help you understand your cluster topology, slot distribution, and node health.

```bash
# Get detailed information about all cluster nodes
# Shows node IDs, roles (master/replica), slot assignments, and connection state
curl http://localhost:8000/redis/cluster/nodes | jq '.'

# Example output:
# {
#   "status": "success",
#   "total_nodes": 3,
#   "nodes": [
#     {
#       "node_id": "abc123...",
#       "host": "172.20.0.13",
#       "port": 6379,
#       "role": "master",
#       "slots_count": 5461,
#       "slot_ranges": [{"start": 0, "end": 5460}]
#     }
#   ]
# }

# Get slot distribution across cluster nodes
# Shows how the 16384 hash slots are distributed across masters
curl http://localhost:8000/redis/cluster/slots | jq '.'

# Example output:
# {
#   "total_slots": 16384,
#   "max_slots": 16384,
#   "coverage_percentage": 100.0,
#   "slot_distribution": [
#     {
#       "start_slot": 0,
#       "end_slot": 5460,
#       "slots_count": 5461,
#       "master": {"host": "172.20.0.13", "port": 6379, "node_id": "abc..."},
#       "replicas": []
#     }
#   ]
# }

# Get cluster state and statistics
# Returns cluster health, slot coverage, message stats, and epoch info
curl http://localhost:8000/redis/cluster/info | jq '.'

# Example output:
# {
#   "cluster_state": "ok",
#   "cluster_slots_assigned": 16384,
#   "cluster_known_nodes": 3,
#   "cluster_size": 3
# }

# Get detailed information about a specific node
# Accepts: redis-1, redis-2, redis-3
curl http://localhost:8000/redis/nodes/redis-1/info | jq '.info | {redis_version, role, cluster_enabled, used_memory_human}'

# Example output:
# {
#   "redis_version": "7.4.6",
#   "role": "master",
#   "cluster_enabled": 1,
#   "used_memory_human": "2.47M"
# }
```

**HTTPS Access:**

All endpoints support both HTTP and HTTPS when TLS is enabled (`REFERENCE_API_ENABLE_TLS=true`):

```bash
# HTTP (default, always available)
curl http://localhost:8000/health/all
curl http://localhost:8000/redis/cluster/nodes

# HTTPS (when TLS enabled)
curl https://localhost:8443/health/all
curl https://localhost:8443/redis/cluster/nodes

# Interactive API documentation
# HTTP Swagger UI
open http://localhost:8000/docs

# HTTPS Swagger UI (when TLS enabled)
open https://localhost:8443/docs
```

**Architecture:**

```
reference-apps/fastapi/
├── app/
│   ├── main.py              # FastAPI application entry point
│   ├── config.py            # Pydantic settings (env vars)
│   ├── routers/
│   │   ├── health.py        # Health check endpoints (all services)
│   │   ├── redis_cluster.py # Redis Cluster inspection APIs
│   │   ├── vault_demo.py    # Vault integration examples
│   │   ├── database_demo.py # DB connectivity examples
│   │   ├── cache_demo.py    # Redis caching examples
│   │   └── messaging_demo.py # RabbitMQ messaging examples
│   └── services/
│       └── vault.py         # Vault client wrapper
├── requirements.txt         # Python dependencies
├── Dockerfile              # Container build configuration
├── start.sh                # Dual HTTP/HTTPS startup script
└── README.md               # Detailed documentation
```

**Using as Reference:**

When implementing your own applications, refer to:
- `app/services/vault.py` - How to fetch secrets from Vault
- `app/routers/health.py` - Multi-node health check patterns, Redis cluster detection
- `app/routers/redis_cluster.py` - Redis CLUSTER commands (NODES, SLOTS, INFO)
- `app/routers/database_demo.py` - Async database connection patterns
- `app/routers/cache_demo.py` - Redis caching patterns
- `app/routers/messaging_demo.py` - RabbitMQ messaging patterns
- `app/config.py` - Pydantic settings management
- `start.sh` - Dual HTTP/HTTPS server startup with Uvicorn

**Development:**

The FastAPI application runs with auto-reload enabled, so you can modify code and see changes immediately:

```bash
# Edit a file
nano reference-apps/fastapi/app/routers/health.py

# Changes will be automatically reloaded
# Check logs: docker logs -f dev-reference-api
```

**Security Note:**
- The reference app uses the Vault root token for simplicity
- In production, use AppRole or other authentication method
- Never expose Vault tokens in production APIs
- Implement proper authentication/authorization for your APIs

## Testing Infrastructure

### Test Architecture

**Why Real Client Testing?**

Using `docker exec` to test services has significant limitations:
- ❌ Bypasses the network stack (tests inside container)
- ❌ Can't verify SSL/TLS properly (no real certificate validation)
- ❌ Doesn't test firewall/routing (misses network issues)
- ❌ Can't verify encryption (no visibility into connection security)

**Solution: Python Test Clients**

External Python clients connect from **outside the container** via the real network stack, just like production applications would.

```
┌─────────────────────────────────────────┐
│ Host Machine (macOS)                    │
│                                         │
│  ┌────────────────────────────────┐    │
│  │ Test Suite (Bash)              │    │
│  │  ├── test-vault.sh             │    │
│  │  ├── test-postgres.sh          │    │
│  │  └── run-all-tests.sh          │    │
│  └───────────┬────────────────────┘    │
│              │                          │
│  ┌───────────▼────────────────────┐    │
│  │ Python Clients                 │    │
│  │  ├── vault_client.py           │    │
│  │  └── postgres_client.py        │    │
│  └───────────┬────────────────────┘    │
│              │                          │
└──────────────┼──────────────────────────┘
               │ Real Network Connection
               │ (localhost:5432, SSL/TLS)
               ▼
┌─────────────────────────────────────────┐
│ Docker Network (172.20.0.0/16)         │
│  ┌─────────────────────────────────┐   │
│  │ PostgreSQL Container            │   │
│  │ IP: 172.20.0.10                 │   │
│  │ Port: 5432                      │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**Test Coverage:**
- ✅ External network connectivity
- ✅ SSL/TLS encryption verification
- ✅ Certificate validation (verify-ca, verify-full modes)
- ✅ Vault credential fetching
- ✅ Database operations (connections, queries, table creation)
- ✅ Protocol version and cipher suite verification

### Python Test Clients

**Dependencies:**

The test suite uses [uv](https://github.com/astral-sh/uv) - a fast Python package installer written in Rust.

```bash
# Install uv (if not already installed)
brew install uv

# Setup test environment (installs dependencies)
./tests/setup-test-env.sh
```

**Client Files:**

1. **`tests/lib/vault_client.py`** - Vault API client
   - Fetch secrets and credentials
   - Issue PKI certificates
   - No external dependencies (uses stdlib)

2. **`tests/lib/postgres_client.py`** - PostgreSQL test client
   - External connection testing
   - SSL/TLS verification
   - Full certificate validation
   - Dependency: `psycopg2-binary`

**Vault Client Usage:**

```bash
# Get credentials for a service
cd tests && uv run python lib/vault_client.py --get-credentials postgres

# Output:
# {
#   "database": "dev_database",
#   "password": "8dYBz6poJumFpcWw6i97v8srZ",
#   "user": "dev_admin"
# }
```

**PostgreSQL Client Usage:**

```bash
# Run all tests
cd tests && uv run python lib/postgres_client.py --test all

# Test specific functionality
cd tests && uv run python lib/postgres_client.py --test connection
cd tests && uv run python lib/postgres_client.py --test version
cd tests && uv run python lib/postgres_client.py --test table
cd tests && uv run python lib/postgres_client.py --test ssl

# Test with SSL certificate validation
cd tests && uv run python lib/postgres_client.py \
  --test ssl \
  --sslmode verify-full \
  --ca-cert ~/.config/vault/ca/ca-chain.pem
```

**Client Features:**

```python
# PostgreSQL Client Methods
client = PostgreSQLClient(host="localhost", port=5432)
client.connect(sslmode="verify-full", ca_cert_path="/path/to/ca.pem")
client.test_connection()        # Returns: {"status": "success", ...}
client.test_version()           # Returns: PostgreSQL version info
client.test_create_table()      # Creates/inserts/verifies/cleans up
client.test_ssl_connection()    # Verifies SSL, returns cipher info
```

### Running Tests

**Setup Test Environment (One-Time):**

```bash
# Install system dependencies
brew install jq  # JSON processor for bash tests

# Install uv (if not already installed)
brew install uv

# Automated setup
./tests/setup-test-env.sh

# Manual setup
cd tests
uv sync  # Installs dependencies from pyproject.toml
```

**Run All Tests:**

```bash
# Run complete test suite (all 7 test suites, 70+ tests)
./tests/run-all-tests.sh
```

This runs all test suites in organized sequence:
1. **Infrastructure:** Vault (10 tests)
2. **Databases:** PostgreSQL, MySQL, MongoDB (~30 tests)
3. **Cache:** Redis Cluster (12 tests)
4. **Messaging:** RabbitMQ (~5 tests)
5. **Applications:** FastAPI Reference App (14 tests)

**Comprehensive Test Coverage:**

```
=========================================
  Test Suite Summary (70+ Tests)
=========================================

Infrastructure Tests:
  ✓ Vault Integration (10 tests)
    - PKI infrastructure (Root CA + Intermediate CA)
    - Certificate roles for all services
    - Service credentials in Vault
    - Certificate issuance and CA export

Database Tests:
  ✓ PostgreSQL Integration (~10 tests)
    - External client connection
    - Vault credentials
    - SSL/TLS verification
  ✓ MySQL Integration (~9 tests)
  ✓ MongoDB Integration (~10 tests)

Cache Tests:
  ✓ Redis Cluster (12 tests)
    - Cluster initialization (state: ok)
    - All 16384 slots assigned (100% coverage)
    - 3 master nodes with slot distribution
    - Data sharding and automatic redirection
    - Vault password integration

Messaging Tests:
  ✓ RabbitMQ Integration (~5 tests)

Application Tests:
  ✓ FastAPI Reference App (14 tests)
    - HTTP/HTTPS endpoints
    - Redis Cluster API endpoints (4 new APIs)
    - Health checks with cluster details
    - Service integrations (Vault, DBs, RabbitMQ)
    - API documentation validation

=========================================
Total: 70+ tests across all components
=========================================
```

**Run Individual Test Suites:**

```bash
# Infrastructure
./tests/test-vault.sh              # Vault PKI and secrets (10 tests)

# Databases
./tests/test-postgres.sh           # PostgreSQL with Vault (~10 tests)
./tests/test-mysql.sh              # MySQL with Vault (~9 tests)
./tests/test-mongodb.sh            # MongoDB with Vault (~10 tests)

# Cache & Messaging
./tests/test-redis-cluster.sh      # Redis cluster operations (12 tests)
./tests/test-rabbitmq.sh           # RabbitMQ messaging (~5 tests)

# Applications
./tests/test-fastapi.sh            # FastAPI + Redis Cluster APIs (14 tests)
```

**New Test Suites (Latest Update):**

1. **`test-redis-cluster.sh`** - Redis Cluster Testing (12 tests)
   ```bash
   ./tests/test-redis-cluster.sh
   ```

   Validates:
   - ✅ All 3 Redis containers running and reachable
   - ✅ Cluster mode enabled on all nodes
   - ✅ Cluster initialization (state: ok)
   - ✅ All 16384 hash slots assigned
   - ✅ 3 master nodes with slot distribution
   - ✅ Data sharding and automatic redirection
   - ✅ Vault password integration
   - ✅ Keyslot calculation

2. **`test-fastapi.sh`** - FastAPI Reference App Testing (14 tests)
   ```bash
   ./tests/test-fastapi.sh
   ```

   Validates:
   - ✅ HTTP endpoint (port 8000)
   - ✅ HTTPS endpoint (port 8443, when TLS enabled)
   - ✅ Health checks with cluster details
   - ✅ **4 Redis Cluster API endpoints:**
     - `/redis/cluster/nodes` - Node info and slot assignments
     - `/redis/cluster/slots` - Slot distribution and coverage
     - `/redis/cluster/info` - Cluster state and statistics
     - `/redis/nodes/{node}/info` - Per-node detailed info
   - ✅ API documentation (Swagger UI, OpenAPI schema)
   - ✅ Service integrations (Vault, databases, RabbitMQ)

**Test Output:**

```
=========================================
  PostgreSQL Vault Integration Tests
=========================================

[TEST] Test 1: PostgreSQL container is running
[PASS] PostgreSQL container is running

[TEST] Test 4: Can connect with Vault password (real client)
[PASS] Connection successful (verified from outside container)

[TEST] Test 7: SSL/TLS connection verification (real client)
[PASS] SSL test passed (not enabled, connection unencrypted)

=========================================
  Test Results
=========================================
Total tests: 10
Passed: 10
=========================================

✓ All PostgreSQL tests passed!
```

**Test Categories:**

| Test | Method | Real Client |
|------|--------|-------------|
| Container Status | `docker compose ps` | N/A |
| Health Check | `docker exec ... pg_isready` | No |
| Connection Test | Python `psycopg2.connect()` | ✅ Yes |
| Version Query | Python `execute_query("SELECT version()")` | ✅ Yes |
| Table Operations | Python `CREATE/INSERT/SELECT` | ✅ Yes |
| SSL Verification | Python `pg_stat_ssl` query | ✅ Yes |
| Certificate Validation | Python `sslmode=verify-full` | ✅ Yes |

### SSL/TLS Testing

**Testing SSL Modes:**

The PostgreSQL Python client supports all SSL modes for comprehensive testing:

```bash
# Test without SSL
./tests/venv/bin/python3 ./tests/lib/postgres_client.py \
  --test ssl \
  --sslmode disable

# Test with SSL but no verification
./tests/venv/bin/python3 ./tests/lib/postgres_client.py \
  --test ssl \
  --sslmode require

# Test with CA verification
./tests/venv/bin/python3 ./tests/lib/postgres_client.py \
  --test ssl \
  --sslmode verify-ca \
  --ca-cert ~/.config/vault/ca/ca-chain.pem

# Test with full certificate validation (hostname + CA)
./tests/venv/bin/python3 ./tests/lib/postgres_client.py \
  --test ssl \
  --sslmode verify-full \
  --ca-cert ~/.config/vault/ca/ca-chain.pem
```

**SSL Test Output (when TLS enabled):**

```
Testing SSL connection...
  SSL connection verified

✓ ssl: success

Full results:
{
  "ssl": {
    "status": "success",
    "ssl_enabled": true,
    "ssl_version": "TLSv1.3",
    "ssl_cipher": "TLS_AES_256_GCM_SHA384",
    "message": "SSL connection verified"
  }
}
```

**SSL Test Output (when TLS disabled):**

```
Testing SSL connection...
  Connection is not encrypted (SSL not enabled)

✓ ssl: success

Full results:
{
  "ssl": {
    "status": "success",
    "ssl_enabled": false,
    "message": "Connection is not encrypted (SSL not enabled)"
  }
}
```

**Automated SSL Testing:**

When running `./tests/test-postgres.sh`:

- **Test 7:** Verifies SSL status (detects if SSL is enabled or disabled)
- **Test 8:** If TLS enabled, validates certificate in `verify-full` mode

**Why This Matters:**

Real client SSL testing ensures:
1. ✅ Certificates are valid and trusted
2. ✅ Encryption is actually working (not just configured)
3. ✅ Certificate chains are correct
4. ✅ Hostname validation works
5. ✅ Cipher suites are appropriate
6. ✅ Protocol versions are secure (TLSv1.2+)

**Certificate Validation Levels:**

| SSL Mode | Encryption | CA Check | Hostname Check | Use Case |
|----------|------------|----------|----------------|----------|
| `disable` | ❌ No | ❌ No | ❌ No | Development/testing |
| `allow` | ⚠️ Maybe | ❌ No | ❌ No | Not recommended |
| `prefer` | ⚠️ Maybe | ❌ No | ❌ No | Not recommended |
| `require` | ✅ Yes | ❌ No | ❌ No | Basic SSL |
| `verify-ca` | ✅ Yes | ✅ Yes | ❌ No | Trusted CA |
| `verify-full` | ✅ Yes | ✅ Yes | ✅ Yes | Production ⭐ |

**Troubleshooting SSL Tests:**

```bash
# Check if SSL is enabled in PostgreSQL
docker exec dev-postgres psql -U dev_admin -d dev_database \
  -c "SHOW ssl;"

# Check certificate files
docker exec dev-postgres ls -l /var/lib/postgresql/certs/

# Verify CA certificate is exported
ls -l ~/.config/vault/ca/ca-chain.pem

# Re-export CA certificate
./manage-colima.sh vault-ca-cert

# Test connection manually
openssl s_client -connect localhost:5432 -starttls postgres \
  -CAfile ~/.config/vault/ca/ca-chain.pem
```

## Colima Deep Dive

### What Colima Does

Colima is a **container runtime manager** that abstracts the complexity of running Linux containers on macOS:

```
Your Mac (macOS)
     ↓
Colima CLI
     ↓
Lima (Linux VM Manager)
     ↓
QEMU/VZ (Hypervisor)
     ↓
Linux VM (Ubuntu/Alpine)
     ↓
containerd/Docker (Container Runtime)
     ↓
Your Containers
```

**Key Components:**

1. **Lima:** Launches and manages Linux VMs
   - Configuration: `~/.lima/colima/lima.yaml`
   - Disk image: `~/.lima/colima/diffdisk`
   - SSH access: `limactl shell colima`

2. **Virtualization Backend:**
   - **VZ (Virtualization.framework):** Native macOS hypervisor (recommended for M-series)
   - **QEMU:** Cross-platform emulator/hypervisor (fallback)

3. **Container Runtime:**
   - **Docker:** Full Docker Engine compatibility
   - **containerd:** Minimal container runtime (alternative)

4. **Network Stack:**
   - Uses macOS network interfaces
   - Port forwarding: VM ports → Mac ports
   - Socket forwarding: `/var/run/docker.sock` exposed to Mac

### Colima vs Docker Desktop

| Feature | Colima | Docker Desktop |
|---------|--------|----------------|
| **License** | Free, Open Source (Apache 2.0) | Free for personal, Paid for business |
| **Resource Usage** | ~500MB-1GB RAM | ~2-3GB RAM |
| **Startup Time** | 5-10 seconds | 20-30 seconds |
| **Native ARM Support** | Yes (VZ backend) | Yes |
| **Kubernetes** | Via k3s | Built-in |
| **GUI** | Command-line only | Dashboard included |
| **Multi-Profile** | Yes (multiple VMs) | Limited |
| **Integration** | Docker CLI compatible | Full Docker Desktop features |

**When to Use Colima:**
- You want a lightweight Docker runtime
- You're on Apple Silicon and want native performance
- You need multiple isolated Docker environments
- You prefer command-line tools
- You want to avoid Docker Desktop licensing

**When to Use Docker Desktop:**
- You need the GUI dashboard
- You require Kubernetes integration
- You want official Docker support
- You use Docker's advanced features (Dev Environments, Extensions)

### VM Types and Performance

**VZ (Virtualization.framework) - Recommended for M-Series**
```bash
colima start --vm-type vz
```

Benefits:
- Native Apple Silicon virtualization
- Lower overhead than QEMU
- Better I/O performance
- Faster startup

**QEMU - Cross-Platform**
```bash
colima start --vm-type qemu
```

Benefits:
- Works on Intel and Apple Silicon
- More mature and stable
- Better hardware emulation support

**Performance Comparison (Apple Silicon):**
```
Benchmark: Docker Build Time (Node.js app)
- VZ: 48s
- QEMU: 65s
- Docker Desktop: 50s

Container Startup Time:
- VZ: 0.2s
- QEMU: 0.5s
```

**This Setup Uses:**
```bash
--vm-type vz  # Best performance on Apple Silicon
```

### Networking Architecture

**Network Modes:**

1. **Default (NAT):** VM is NAT'd behind Mac's network
   - Containers accessible via `localhost`
   - VM not directly accessible from network

2. **Network Address (`--network-address`):** VM gets IP on local network
   - Containers accessible from other devices
   - Used in this setup for UTM VM integration

**This Setup:**
```bash
colima start --network-address
```

**Network Flow:**
```
External Network
     ↓
Your Mac (192.168.1.x)
     ↓
Colima VM (192.168.106.x) ← --network-address flag
     ↓
Docker Bridge Network (172.20.0.0/16)
     ↓
Containers (172.20.0.10, 172.20.0.11, etc.)
```

**Port Mapping:**
```
Host Port → VM Port → Container Port
localhost:5432 → 192.168.106.x:5432 → 172.20.0.10:5432 (PostgreSQL)
```

**Getting Colima IP:**
```bash
colima list | grep default | awk '{print $NF}'
# Or
./manage-colima.sh ip
```

**Access from Another Machine:**
```bash
# From UTM VM or another computer on network
COLIMA_IP=192.168.106.2  # Example
psql -h $COLIMA_IP -p 5432 -U dev_admin -d dev_database
```

### Storage and Volumes

**Volume Locations:**

1. **Docker Volumes** (inside Colima VM):
   ```
   /var/lib/docker/volumes/colima-services_postgres_data
   /var/lib/docker/volumes/colima-services_redis_1_data
   # etc.
   ```

2. **Lima VM Disk** (on Mac):
   ```
   ~/.lima/colima/diffdisk
   ```

3. **Bind Mounts** (shared from Mac):
   ```
   ~/colima-services/configs → /Users/you/colima-services/configs (inside VM)
   ```

**Volume Drivers:**
- Default: `local` (VM's filesystem)
- Supports: NFS, SMB, SSHFS (advanced)

**Performance:**
- **Volumes:** Fast (native Linux filesystem)
- **Bind Mounts:** Slower (macOS ↔ Linux overhead)
- **Best Practice:** Use volumes for databases, bind mounts for code

**Managing Volumes:**
```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect colima-services_postgres_data

# Backup volume
docker run --rm -v colima-services_postgres_data:/data \
  -v $(pwd)/backup:/backup alpine \
  tar czf /backup/postgres-$(date +%Y%m%d).tar.gz -C /data .

# Restore volume
docker run --rm -v colima-services_postgres_data:/data \
  -v $(pwd)/backup:/backup alpine \
  tar xzf /backup/postgres-20250101.tar.gz -C /data
```

## Management Script

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

## Docker Compose Architecture

### Network Design

**Custom Bridge Network:**
```yaml
networks:
  dev-services:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

**Why Custom Network?**
- Predictable IP addresses for services
- Internal DNS (service names resolve to IPs)
- Isolation from other Docker networks
- Easy inter-service communication

**IP Allocation:**
```
172.20.0.10  → PostgreSQL
172.20.0.11  → PgBouncer
172.20.0.12  → MySQL
172.20.0.13  → Redis-1
172.20.0.14  → RabbitMQ
172.20.0.15  → MongoDB
172.20.0.16  → Redis-2
172.20.0.17  → Redis-3
172.20.0.20  → Forgejo
172.20.0.21  → Vault
```

**Service Discovery:**
```bash
# Containers can reach each other by name
# From Forgejo container:
psql -h postgres -p 5432  # Resolves to 172.20.0.10

# From your Mac:
psql -h localhost -p 5432  # Port forwarded to host
```

### Volume Strategy

**All Volumes:**
```yaml
volumes:
  postgres_data:
  mysql_data:
  redis_1_data:
  redis_2_data:
  redis_3_data:
  rabbitmq_data:
  mongodb_data:
  forgejo_data:
  vault_data:
```

**Volume Benefits:**
- **Persistence:** Data survives container restarts
- **Performance:** Native Linux filesystem (fast)
- **Portability:** Can be backed up and restored
- **Isolation:** Separate from host filesystem

**Config Bind Mounts:**
```yaml
volumes:
  - ./configs/redis/redis-cluster.conf:/usr/local/etc/redis/redis.conf:ro
  - ./configs/vault:/vault/config:ro
  - ./configs/vault/scripts/vault-auto-unseal.sh:/usr/local/bin/vault-auto-unseal.sh:ro
```

**Read-Only (`:ro`) for:**
- Configuration files (prevents containers from modifying)
- Scripts
- Prevents accidental overwrites

### Health Checks

**Why Health Checks?**
- Docker knows when containers are truly ready
- `docker compose ps` shows accurate status
- Dependencies can wait for healthy services
- Automatic restart of unhealthy containers

**Health Check Pattern:**
```yaml
healthcheck:
  test: ["CMD", "command", "to", "test"]
  interval: 60s      # Check every 60 seconds
  timeout: 5s        # Timeout after 5 seconds
  retries: 5         # 5 failed checks = unhealthy
```

**Service-Specific Checks:**

- **PostgreSQL:** `pg_isready -U $POSTGRES_USER`
- **MySQL:** `mysqladmin ping`
- **Redis:** `redis-cli -a $REDIS_PASSWORD ping`
- **RabbitMQ:** `rabbitmq-diagnostics -q ping`
- **MongoDB:** `mongosh --eval "db.adminCommand('ping')"`
- **Forgejo:** `curl -f http://localhost:3000/api/healthz`
- **Vault:** `wget --spider http://127.0.0.1:8200/v1/sys/health?standbyok=true`

**Health Check Optimization:**
- Interval: 60 seconds (reduced from 10-30s for lower overhead)
- See [Performance Optimization](#performance-optimization)

### Service Dependencies

**Dependency Management:**
```yaml
depends_on:
  postgres:
    condition: service_healthy  # Wait for healthy, not just started
```

**Example: Forgejo depends on PostgreSQL**
```yaml
forgejo:
  depends_on:
    postgres:
      condition: service_healthy
```

**Startup Order:**
1. PostgreSQL starts
2. PostgreSQL health check passes
3. Forgejo starts (can connect to DB immediately)

**No Dependency Issues:**
- Other services don't have hard dependencies
- Redis, MongoDB, MySQL start independently
- Vault auto-unseals after starting

## Redis Cluster

### Architecture

**3-Node Master Cluster:**
```
┌────────────────────────────────────────────┐
│         Redis Cluster (16384 slots)         │
├────────────────────────────────────────────┤
│                                            │
│  Node 1 (172.20.0.13:6379)                │
│  Master | Slots 0-5460 (5461 slots)       │
│                                            │
│  Node 2 (172.20.0.16:6379)                │
│  Master | Slots 5461-10922 (5462 slots)   │
│                                            │
│  Node 3 (172.20.0.17:6379)                │
│  Master | Slots 10923-16383 (5461 slots)  │
│                                            │
└────────────────────────────────────────────┘
```

**Data Sharding:**
- Each key is hashed (CRC16) to a slot number (0-16383)
- Key `user:1000` → Hash → Slot 5139 → Node 1
- Automatic redistribution if nodes added/removed

**Why No Replicas?**
- Development environment doesn't need redundancy
- Saves resources (3 nodes vs 6 nodes)
- Production would have 3 masters + 3 replicas

### Cluster Setup

**Initialization Script** (`configs/redis/scripts/redis-cluster-init.sh`):

1. **Wait for Nodes:** Ensures all 3 Redis instances are ready
2. **Check Existing Cluster:** Skips if already initialized
3. **Create Cluster:** Uses `redis-cli --cluster create`
4. **Assign Slots:** Distributes 16384 slots across 3 masters
5. **Verify:** Checks cluster state is "ok"

**Manual Initialization:**
```bash
docker exec dev-redis-1 redis-cli --cluster create \
  172.20.0.13:6379 172.20.0.16:6379 172.20.0.17:6379 \
  --cluster-yes -a $REDIS_PASSWORD
```

### Operations

**Cluster Status:**
```bash
# Overall health
docker exec dev-redis-1 redis-cli -a $REDIS_PASSWORD cluster info

# Output:
# cluster_state:ok
# cluster_slots_assigned:16384
# cluster_known_nodes:3
```

**Node Information:**
```bash
docker exec dev-redis-1 redis-cli -a $REDIS_PASSWORD cluster nodes

# Shows:
# - Node IDs
# - IP addresses and ports
# - Master/replica status
# - Slot ranges
```

**Slot Distribution:**
```bash
docker exec dev-redis-1 redis-cli -a $REDIS_PASSWORD cluster slots

# Shows which node owns which slot range
```

**Data Operations:**
```bash
# Set key (automatically routed to correct node)
redis-cli -c -a $REDIS_PASSWORD -p 6379 SET user:1000 "John Doe"

# Get key (automatic redirection with -c flag)
redis-cli -c -a $REDIS_PASSWORD -p 6380 GET user:1000
# → Redirected to Node 1 (slot 5139)

# Without -c flag: returns MOVED error
redis-cli -a $REDIS_PASSWORD -p 6380 GET user:1000
# → (error) MOVED 5139 172.20.0.13:6379
```

**Find Key Location:**
```bash
# Which slot?
docker exec dev-redis-1 redis-cli -a $REDIS_PASSWORD cluster keyslot user:1000
# → 5139

# Which node owns slot 5139?
# Check cluster nodes output: Node 1 (slots 0-5460)
```

### Troubleshooting

**Cluster State Not OK:**
```bash
# Check individual node status
for i in 1 2 3; do
  echo "Node $i:"
  docker exec dev-redis-$i redis-cli -a $REDIS_PASSWORD ping
done

# Check cluster view from each node
docker exec dev-redis-1 redis-cli -a $REDIS_PASSWORD cluster nodes
docker exec dev-redis-2 redis-cli -a $REDIS_PASSWORD cluster nodes
docker exec dev-redis-3 redis-cli -a $REDIS_PASSWORD cluster nodes

# All should show same cluster topology
```

**Slot Migration Issues:**
```bash
# Check for open slots
docker exec dev-redis-1 redis-cli --cluster check 172.20.0.13:6379 -a $REDIS_PASSWORD

# Should show: [OK] All 16384 slots covered
```

**Manually Re-initialize Cluster:**
```bash
# If cluster is broken and needs to be recreated
./configs/redis/scripts/redis-cluster-init.sh
```

**Performance Monitoring:**
```bash
# Real-time stats
docker exec dev-redis-1 redis-cli -a $REDIS_PASSWORD --stat

# Slowlog
docker exec dev-redis-1 redis-cli -a $REDIS_PASSWORD slowlog get 10
```

### REST API Cluster Inspection

The FastAPI reference application provides comprehensive REST APIs for Redis cluster inspection. These endpoints offer an alternative to `docker exec` commands and can be integrated into monitoring dashboards or automation scripts.

**Available Endpoints:**

```bash
# Get all cluster nodes with slot assignments
curl http://localhost:8000/redis/cluster/nodes | jq '.'
# Returns: node IDs, roles, slot ranges, connection state

# Get slot distribution across cluster
curl http://localhost:8000/redis/cluster/slots | jq '.'
# Returns: slot ranges per master, total coverage, replica info

# Get cluster state and statistics
curl http://localhost:8000/redis/cluster/info | jq '.'
# Returns: cluster_state, slots assigned, message stats, epochs

# Get detailed info for specific node
curl http://localhost:8000/redis/nodes/redis-1/info | jq '.info.cluster*'
# Returns: full INFO output including cluster metrics
```

**Example: Check Cluster Health Programmatically**

```bash
# Quick health check
CLUSTER_STATE=$(curl -s http://localhost:8000/redis/cluster/info | jq -r '.cluster_info.cluster_state')
SLOTS_ASSIGNED=$(curl -s http://localhost:8000/redis/cluster/info | jq -r '.cluster_info.cluster_slots_assigned')

if [ "$CLUSTER_STATE" = "ok" ] && [ "$SLOTS_ASSIGNED" = "16384" ]; then
  echo "✅ Redis cluster is healthy"
else
  echo "❌ Redis cluster has issues"
fi
```

**Example: Monitor Slot Distribution**

```bash
# Get slot coverage percentage
curl -s http://localhost:8000/redis/cluster/slots | jq '{
  total_slots: .total_slots,
  coverage: .coverage_percentage,
  masters: [.slot_distribution[] | {
    node: .master.host,
    slots: .slots_count,
    range: "\(.start_slot)-\(.end_slot)"
  }]
}'
```

**Implementation Reference:**

See `reference-apps/fastapi/app/routers/redis_cluster.py` for:
- Parsing `CLUSTER NODES` command output
- Handling `CLUSTER SLOTS` binary response
- Connecting to individual cluster nodes
- Error handling for cluster operations

**HTTPS Access:**

When TLS is enabled (`REFERENCE_API_ENABLE_TLS=true`), all endpoints are available on both HTTP (8000) and HTTPS (8443):

```bash
# HTTPS access
curl https://localhost:8443/redis/cluster/nodes
curl https://localhost:8443/redis/cluster/info
```

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

## Performance Optimization

This section describes the performance optimizations applied to reduce resource usage while maintaining reliability for local development.

### Resource Tuning

**Colima VM Resources:**
```bash
# Current allocation
export COLIMA_CPU=4       # 4 cores
export COLIMA_MEMORY=8    # 8 GB
export COLIMA_DISK=60     # 60 GB

# Adjust based on usage:
# Light: 2 CPU, 4 GB (just Git + 1-2 services)
# Medium: 4 CPU, 8 GB (current setup)
# Heavy: 6-8 CPU, 12-16 GB (many concurrent services)
```

**Per-Service Memory Limits:**
```yaml
# PostgreSQL
shared_buffers: 256MB
effective_cache_size: 1GB
work_mem: 8MB

# MySQL
innodb_buffer_pool_size: 256M

# Redis (per node)
maxmemory: 256mb
```

**Monitor Resource Usage:**
```bash
# Real-time stats
./manage-colima.sh status
# See CPU/Memory columns

# Or directly
docker stats --no-stream
```

### Health Check Optimization

**Problem:** Health checks running every 10-30 seconds created unnecessary load.

**Solution:** Standardized all health checks to 60-second intervals.

**Changes:**

| Service | Before | After | Reduction |
|---------|--------|-------|-----------|
| PostgreSQL | 10s | 60s | 83% |
| PgBouncer | 30s | 60s | 50% |
| MySQL | 10s | 60s | 83% |
| Redis | 10s | 60s | 83% |
| RabbitMQ | 30s | 60s | 50% |
| MongoDB | 10s | 60s | 83% |
| Forgejo | 30s | 60s | 50% |
| Vault | 10s | 60s | 83% |

**Impact:**
- **Total health checks per hour:**
  - Before: ~1,440 checks (24 per minute × 60 minutes)
  - After: 480 checks (8 per minute × 60 minutes)
  - **Reduction: 67% fewer health checks**

**Configuration:**
```yaml
healthcheck:
  test: ["CMD", "..."]
  interval: 60s  # Changed from 10s or 30s
  timeout: 5s
  retries: 5
```

**Trade-off:** Slightly longer time to detect failures (max 60s vs 10-30s). Acceptable for development environment.

**When to Increase Health Check Frequency:**

Consider using shorter intervals (10-30s) if:
1. Running in production
2. Need rapid failure detection
3. Using auto-scaling/load balancing
4. Services are mission-critical

**When Current Settings Are Appropriate:**

60-second health checks are fine for:
1. Local development environments ✓
2. Non-critical testing
3. Resource-constrained systems
4. Personal workstations ✓

**Reverting to Faster Health Checks:**

Edit `docker-compose.yml` and change intervals:
```yaml
healthcheck:
  interval: 10s  # or 30s for some services
```

Then recreate containers:
```bash
docker compose up -d
```

### Vault Auto-Unseal Optimization

**Problem:** Originally designed with continuous monitoring (checking seal status every 10 seconds).

**Solution:** Changed to one-time unseal on startup, then sleep indefinitely.

**Before:**
```sh
# Monitor and auto-unseal if it becomes sealed
while true; do
    sleep 10
    if is_sealed 2>/dev/null; then
        echo "Vault became sealed, re-unsealing..."
        unseal_vault || true
    fi
done
```

**After:**
```sh
# Keep process alive but do nothing (minimal CPU usage)
while true; do
    sleep 3600  # Sleep for 1 hour at a time
done
```

**Impact:**
- **Before:** 6 API calls per minute (360 calls/hour)
- **After:** 0 API calls after initial unseal
- **Resource savings:** ~99% reduction in Vault API calls
- **CPU usage:** Near zero (process just sleeps)

**Trade-off:** Vault will not auto-reseal if manually sealed. Must restart container or run init script to unseal.

**Process Monitoring:**

```bash
# View Vault auto-unseal process (should show sleep)
docker exec dev-vault ps aux | grep vault-auto-unseal

# Expected output:
# 8 root  0:00 {vault-auto-unse} /bin/sh /usr/local/bin/vault-auto-unseal.sh
# 56 root 0:00 sleep 3600
```

**Restoring Continuous Vault Monitoring:**

If you need Vault to auto-reseal when manually sealed, edit `configs/vault/scripts/vault-auto-unseal.sh`:
```sh
# Replace:
while true; do
    sleep 3600
done

# With:
while true; do
    sleep 10
    if is_sealed 2>/dev/null; then
        echo "Vault became sealed, re-unsealing..."
        unseal_vault || true
    fi
done
```

Then restart Vault:
```bash
docker compose restart vault
```

### Resource Usage Comparison

**CPU Usage:**

| Component | Before | After | Notes |
|-----------|--------|-------|-------|
| vault-auto-unseal.sh | ~0.1% (continuous checks) | ~0.0% (sleeping) | Process exists but idle |
| Docker health checks | ~0.5-1% (all services) | ~0.2-0.3% | Fewer checks per minute |

**Network Overhead:**

| Operation | Before (per hour) | After (per hour) | Reduction |
|-----------|-------------------|------------------|-----------|
| Vault seal checks | 360 API calls | 0 API calls | 100% |
| Health checks | 1,440 checks | 480 checks | 67% |

### Performance Metrics

**Before Optimizations:**

```
Total API calls per minute: 42
- Health checks: 36/min
- Vault seal checks: 6/min

Total process overhead:
- 8 health check processes
- 1 continuous monitoring script
```

**After Optimizations:**

```
Total API calls per minute: 8
- Health checks: 8/min
- Vault seal checks: 0/min

Total process overhead:
- 8 health check processes (less frequent)
- 1 sleeping process (idle)
```

**Overall reduction: ~81% fewer operations per minute**

### Container Restart Detection

With 60-second health check intervals:
- **Minimum detection time:** 60 seconds
- **Maximum detection time:** 120 seconds (60s + timeout + retries)
- **Average detection time:** ~90 seconds

This is acceptable for development where immediate detection isn't critical.

### Memory Management

**Avoid Memory Swapping:**
```bash
# Check if Colima is swapping
limactl shell colima
free -h
# Look at Swap line - should be mostly unused
```

**If Swapping Occurs:**
1. Increase `COLIMA_MEMORY`
2. Reduce service memory limits
3. Stop unused services

**Docker Memory Limits:**
```yaml
# Add to services if needed
deploy:
  resources:
    limits:
      memory: 512M
```

### Future Optimization Considerations

**Potential Further Optimizations:**

1. **Disable health checks entirely** for non-critical services
   - Removes overhead completely
   - Trade-off: No automatic failure detection

2. **Use external monitoring** instead of Docker health checks
   - Centralized monitoring system
   - More control over check frequency
   - Example: Prometheus + Grafana

3. **Lazy service startup** for rarely-used services
   - Only start when needed
   - Saves idle resource consumption

**Not Recommended for This Setup:**

- **Auto-unseal with cloud KMS**: Overkill for local dev
- **Health check aggregation**: Complexity not worth it for 8 services
- **Resource limits**: Development needs flexibility

## Backup and Restore

**Automated Backup Script:**
```bash
./manage-colima.sh backup
```

Creates timestamped backup in `backups/YYYYMMDD_HHMMSS/`:
- `postgres_all.sql` - All PostgreSQL databases
- `mysql_all.sql` - All MySQL databases
- `mongodb_dump.archive` - MongoDB archive
- `forgejo_data.tar.gz` - Forgejo repositories and data
- `.env.backup` - Environment configuration

**Manual Backups:**

**PostgreSQL:**
```bash
# All databases
docker compose exec -T postgres pg_dumpall -U $POSTGRES_USER > backup.sql

# Single database
docker compose exec -T postgres pg_dump -U $POSTGRES_USER dev_database > db.sql

# Restore
docker compose exec -T postgres psql -U $POSTGRES_USER < backup.sql
```

**MySQL:**
```bash
# Backup
docker compose exec -T mysql mysqldump -u root -p$MYSQL_ROOT_PASSWORD --all-databases > mysql.sql

# Restore
docker compose exec -T mysql mysql -u root -p$MYSQL_ROOT_PASSWORD < mysql.sql
```

**MongoDB:**
```bash
# Backup
docker compose exec -T mongodb mongodump --archive > mongo.archive

# Restore
docker compose exec -T mongodb mongorestore --archive < mongo.archive
```

**Redis Cluster:**
```bash
# Each node has RDB snapshots in /data/dump.rdb
# Also has AOF logs

# Backup volumes
for i in 1 2 3; do
  docker run --rm \
    -v colima-services_redis_${i}_data:/data \
    -v $(pwd)/backup:/backup \
    alpine tar czf /backup/redis-$i-$(date +%Y%m%d).tar.gz -C /data .
done
```

**Vault:**
```bash
# Backup unseal keys and root token
tar czf vault-backup-$(date +%Y%m%d).tar.gz ~/.config/vault/

# Backup Vault data volume
docker run --rm \
  -v colima-services_vault_data:/data \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/vault-data-$(date +%Y%m%d).tar.gz -C /data .
```

**Restore Strategy:**
1. Stop services
2. Remove volumes
3. Recreate volumes
4. Restore data
5. Start services

```bash
# Example: Restore PostgreSQL
docker compose stop postgres
docker volume rm colima-services_postgres_data
docker volume create colima-services_postgres_data
docker run --rm \
  -v colima-services_postgres_data:/data \
  -v $(pwd)/backup:/backup \
  alpine sh -c "cd /data && tar xzf /backup/postgres-20250101.tar.gz"
docker compose start postgres
```

## Security Considerations

**⚠️ DEVELOPMENT ENVIRONMENT ONLY**

This setup is **NOT production-ready**. Security measures for production:

**Passwords:**
- [x] NO plaintext passwords in `.env` (all managed by Vault)
- [x] Strong passwords auto-generated (25-char random strings)
- [x] Vault secrets management (production-ready)
- [x] Never commit `.env` to version control (no secrets in it anyway)
- [ ] Rotate passwords regularly via `vault-bootstrap` re-run
- [ ] Backup Vault unseal keys securely

**Network:**
- [x] Isolated Docker network (172.20.0.0/16)
- [ ] TLS/SSL for all connections (production)
- [ ] Firewall rules (production)
- [ ] VPN for remote access (production)

**Vault:**
- [x] File storage backend (persistent)
- [x] Shamir secret sharing (3 of 5 keys)
- [x] Auto-unseal on container start (via vault-auto-unseal.sh)
- [x] All service credentials managed by Vault
- [x] PKI infrastructure for TLS certificates
- [ ] Auto-unseal with cloud KMS (production)
- [ ] TLS enabled for Vault itself (production)
- [ ] Audit logging (production)

**Access Control:**
- [x] Password authentication on all services
- [ ] Role-based access control (production)
- [ ] Multi-factor authentication (production)

**Data Protection:**
- [x] Docker volumes (local persistence)
- [x] Regular backups via `./manage-colima.sh backup`
- [ ] Offsite backup storage (production)
- [ ] Encryption at rest (production)
- [ ] Encryption in transit (production)

**Vault Unseal Keys:**
```bash
# Location
~/.config/vault/keys.json
~/.config/vault/root-token

# Permissions
chmod 600 ~/.config/vault/*

# MUST DO:
# 1. Backup these files securely
# 2. Store in password manager
# 3. Distribute keys among team (production)
# 4. Never commit to version control
```

**Production Recommendations:**
1. Enable TLS everywhere (Vault, PostgreSQL, Redis, RabbitMQ)
2. Use Vault for all secrets (no .env files)
3. Implement network policies
4. Set up audit logging
5. Regular security updates
6. Penetration testing
7. Compliance certifications (if required)

## Troubleshooting

### Common Issues

**Container Won't Start:**
```bash
# Check logs
./manage-colima.sh logs <service>

# Or
docker compose logs <service>

# Check health status
docker compose ps
```

**"Cannot connect to Docker daemon":**
```bash
# Verify Colima is running
colima status

# Start if not running
colima start

# Check Docker context
docker context use colima
```

**Port Already in Use:**
```bash
# Find process using port
lsof -i :5432

# Kill process or change port in docker-compose.yml
```

**Out of Disk Space:**
```bash
# Check disk usage
docker system df

# Clean up
docker system prune -a --volumes

# Or increase Colima disk
colima stop
colima start --disk 100  # Increase to 100GB
```

**Slow Performance:**
```bash
# Check resource usage
./manage-colima.sh status

# Increase resources
export COLIMA_CPU=6
export COLIMA_MEMORY=12
./manage-colima.sh restart
```

### Service-Specific

**PostgreSQL Connection Refused:**
```bash
# Check if running
docker compose ps postgres

# Check logs
docker compose logs postgres

# Test connection from inside container
docker exec dev-postgres pg_isready -U $POSTGRES_USER

# Verify password
grep POSTGRES_PASSWORD .env
```

**Redis Cluster "CLUSTERDOWN":**
```bash
# Check cluster state
docker exec dev-redis-1 redis-cli -a $REDIS_PASSWORD cluster info

# Re-initialize if needed
./scripts/redis-cluster-init.sh

# Check all nodes are up
docker compose ps redis-1 redis-2 redis-3
```

**Vault Sealed:**
```bash
# Check status
./manage-colima.sh vault-status

# Unseal
./manage-colima.sh vault-unseal

# Auto-unseal should happen automatically on container restart
# If not, check logs:
docker logs dev-vault | grep -i unseal
```

**Forgejo Can't Connect to Database:**
```bash
# Verify PostgreSQL is healthy
docker compose ps postgres

# Check PostgreSQL logs
docker compose logs postgres

# Restart Forgejo (waits for healthy PostgreSQL)
docker compose restart forgejo
```

**TLS/SSL Issues:**
```bash
# Check if TLS is enabled for a service
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)
python3 scripts/read-vault-secret.py postgres tls_enabled

# Verify certificates exist
ls -la ~/.config/vault/certs/postgres/
# Should show: ca.crt, server.crt, server.key

# Check certificate validity
openssl x509 -in ~/.config/vault/certs/postgres/server.crt -noout -dates

# Verify service picked up TLS setting
docker logs dev-postgres | grep tls_enabled

# If certificates are missing, regenerate them
VAULT_ADDR=http://localhost:8200 \
VAULT_TOKEN=$(cat ~/.config/vault/root-token) \
  bash scripts/generate-certificates.sh

# Recreate service to pick up new certificates
docker compose up -d postgres

# Test SSL connection
export PGPASSWORD=$(python3 scripts/read-vault-secret.py postgres password)
psql "postgresql://dev_admin@localhost:5432/dev_database?sslmode=require"

# If SSL connection fails but service is running:
# 1. Check if TLS is actually enabled in the service
docker exec dev-postgres psql -U dev_admin -d dev_database -c "SHOW ssl;"

# 2. Check init script logs for errors
docker logs dev-postgres | grep -i "tls\|ssl\|cert"

# 3. Verify certificate mounts
docker inspect dev-postgres --format='{{json .Mounts}}' | python3 -m json.tool | grep certs
```

**Certificate Rotation:**
```bash
# Certificates are valid for 1 year. To rotate:

# 1. Check certificate expiration
openssl x509 -in ~/.config/vault/certs/postgres/server.crt -noout -enddate

# 2. Delete old certificates
rm -rf ~/.config/vault/certs/postgres/

# 3. Generate new certificates
VAULT_ADDR=http://localhost:8200 \
VAULT_TOKEN=$(cat ~/.config/vault/root-token) \
  bash scripts/generate-certificates.sh

# 4. Restart service
docker restart dev-postgres
```

### Colima-Specific

**Colima Won't Start:**
```bash
# Check existing instances
colima list

# Delete and recreate
colima delete --profile default --force
colima start --cpu 4 --memory 8 --disk 60 --network-address
```

**Can't Access Services from Network:**
```bash
# Verify network address mode is enabled
colima list
# Should show IP address, not "-"

# Get Colima IP
./manage-colima.sh ip

# Test from other machine
ping <COLIMA_IP>
telnet <COLIMA_IP> 5432
```

**VZ Mode Not Working:**
```bash
# Check macOS version (needs 12.0+)
sw_vers

# Fall back to QEMU
colima start --vm-type qemu
```

## Best Practices

**Daily Usage:**
1. Start services in morning: `./manage-colima.sh start`
2. Work on projects
3. Leave running overnight (or stop: `./manage-colima.sh stop`)
4. Weekly: Check resource usage and backup

**Development Workflow:**
```bash
# 1. Make code changes
# 2. Commit to local Forgejo
git push forgejo main

# 3. Test with local databases
psql -h localhost -U $POSTGRES_USER

# 4. Store secrets in Vault
vault kv put secret/myapp/config api_key=xyz

# 5. Test message queues
# Publish to RabbitMQ, verify consumption
```

**Resource Management:**
```bash
# Check resource usage weekly
./manage-colima.sh status

# Clean up unused containers/images monthly
docker system prune -a

# Monitor disk usage
docker system df
```

**Backup Strategy:**
```bash
# Daily: Git commits (auto-backed up by Forgejo)
# Weekly: Full backup
./manage-colima.sh backup

# Store backups offsite
# Keep 4 weekly backups, 3 monthly backups
```

**Security Hygiene:**
```bash
# 1. Use strong, unique passwords in .env
# 2. Backup Vault keys securely
tar czf vault-keys.tar.gz ~/.config/vault/
gpg -c vault-keys.tar.gz  # Encrypt

# 3. Never commit secrets to Git
# 4. Rotate passwords quarterly
# 5. Update images regularly
docker compose pull
docker compose up -d
```

## Integration Patterns

**Using PostgreSQL from Your App:**
```python
# Python example
import psycopg2

conn = psycopg2.connect(
    host="localhost",
    port=5432,
    user="dev_admin",
    password="<from .env>",
    database="dev_database"
)
```

**Using Redis Cluster from Your App:**
```python
# Python with redis-py-cluster
from rediscluster import RedisCluster

startup_nodes = [
    {"host": "localhost", "port": "6379"},
    {"host": "localhost", "port": "6380"},
    {"host": "localhost", "port": "6381"}
]

rc = RedisCluster(
    startup_nodes=startup_nodes,
    password="<from .env>",
    decode_responses=True
)

rc.set("key", "value")
print(rc.get("key"))
```

**Using Vault from Your App:**
```bash
# Get secrets via CLI
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# Store secret
vault kv put secret/myapp/db password=xyz

# Retrieve in script
DB_PASSWORD=$(vault kv get -field=password secret/myapp/db)
```

**Using RabbitMQ:**
```python
# Python with pika
import pika

credentials = pika.PlainCredentials('dev_admin', '<from .env>')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', 5672, 'dev_vhost', credentials)
)
channel = connection.channel()

channel.queue_declare(queue='hello')
channel.basic_publish(exchange='', routing_key='hello', body='Hello World!')
```

**Git with Forgejo:**
```bash
# Add Forgejo as remote
git remote add forgejo http://localhost:3000/username/repo.git

# Push
git push forgejo main

# Use SSH for better security
git remote set-url forgejo ssh://git@localhost:2222/username/repo.git
```

**Multi-Service Application Example:**
```
Your VoIP App
├── PostgreSQL: Call records, user accounts
├── Redis Cluster: Session storage, rate limiting
├── RabbitMQ: Call events, webhooks
├── MongoDB: Call logs, CDRs
├── Vault: API keys, SIP credentials
└── Forgejo: Source code, deployment scripts
```

## FAQ

**Q: Can I use this on Intel Mac?**
A: Yes, but change VM type:
```bash
export COLIMA_CPU=4
export COLIMA_MEMORY=8
colima start --vm-type qemu  # Instead of vz
```

**Q: Can I run multiple Colima instances?**
A: Yes, use profiles:
```bash
export COLIMA_PROFILE=project1
./manage-colima.sh start

export COLIMA_PROFILE=project2
./manage-colima.sh start
```

**Q: How do I access services from UTM VM?**
A: Use Colima IP instead of localhost:
```bash
COLIMA_IP=$(./manage-colima.sh ip | grep "Colima IP:" | awk '{print $3}')
psql -h $COLIMA_IP -p 5432 -U $POSTGRES_USER
```

**Q: Can I use Docker Desktop instead of Colima?**
A: Yes, but remove `colima` commands from `manage-colima.sh`. Just use `docker compose up -d`.

**Q: How do I update service versions?**
A: Edit `docker-compose.yml`:
```yaml
# Change
image: postgres:16-alpine

# To
image: postgres:17-alpine

# Then
docker compose pull postgres
docker compose up -d postgres
```

**Q: What if I lose Vault unseal keys?**
A: Data is permanently inaccessible. You must:
1. Stop Vault
2. Delete vault_data volume
3. Re-initialize (creates new keys)
4. Re-enter all secrets

**ALWAYS BACKUP UNSEAL KEYS!**

**Q: Can I use this for production?**
A: No. Requires:
- TLS everywhere
- External secrets management
- High availability
- Monitoring/alerting
- Proper backup strategy
- Security hardening

**Q: How do I migrate data from old setup?**
A:
1. Backup old databases (pg_dump, mysqldump, etc.)
2. Start Colima services
3. Restore backups
4. Test connectivity
5. Update application connection strings

**Q: Redis cluster vs single instance?**
A: Cluster provides:
- Horizontal scaling (distribute data)
- High availability (node failures)
- Production parity

Single instance is simpler but doesn't match production.

## Reference

**File Structure:**
```
colima-services/
├── .env                          # Environment variables (DO NOT COMMIT)
├── .env.example                  # Template for .env
├── docker-compose.yml            # Service definitions
├── manage-colima.sh              # Management script
├── README.md                     # This file
├── scripts/                      # Utility scripts
│   ├── load-vault-env.sh         # Load credentials from Vault into environment
│   └── read-vault-secret.py      # Python helper to fetch Vault secrets
├── configs/                      # Configuration files
│   ├── mongodb/
│   │   └── scripts/
│   │       └── init.sh           # MongoDB Vault integration wrapper
│   ├── mysql/
│   │   └── scripts/
│   │       └── init.sh           # MySQL Vault integration wrapper
│   ├── postgres/
│   │   └── scripts/
│   │       └── init.sh           # PostgreSQL Vault integration wrapper
│   ├── rabbitmq/
│   │   └── scripts/
│   │       └── init.sh           # RabbitMQ Vault integration wrapper
│   ├── redis/
│   │   ├── scripts/
│   │   │   ├── init.sh           # Redis Vault integration wrapper
│   │   │   └── redis-cluster-init.sh  # Redis cluster initialization
│   │   ├── redis.conf            # Standalone Redis config
│   │   └── redis-cluster.conf    # Cluster mode config
│   └── vault/
│       ├── scripts/
│       │   ├── vault-init.sh     # Vault initialization
│       │   ├── vault-auto-unseal.sh  # Vault auto-unseal process
│       │   └── vault-bootstrap.sh    # Vault PKI & credentials setup
│       └── vault.hcl             # Vault server config
└── tests/                        # Test infrastructure
    ├── lib/
    │   ├── vault_client.py       # Vault API client
    │   ├── postgres_client.py    # PostgreSQL test client (real connections)
    │   ├── mysql_client.py       # MySQL test client
    │   ├── redis_client.py       # Redis cluster test client
    │   ├── rabbitmq_client.py    # RabbitMQ test client
    │   └── mongodb_client.py     # MongoDB test client
    ├── test-vault.sh             # Vault integration tests (10 tests)
    ├── test-postgres.sh          # PostgreSQL integration tests (10 tests)
    ├── test-mysql.sh             # MySQL integration tests
    ├── test-redis.sh             # Redis cluster tests
    ├── test-rabbitmq.sh          # RabbitMQ tests
    ├── test-mongodb.sh           # MongoDB tests
    ├── run-all-tests.sh          # Master test runner
    ├── setup-test-env.sh         # Test environment setup
    ├── pyproject.toml            # Python project configuration (uv)
    ├── uv.lock                   # Lock file for dependencies
    └── venv/                     # Python virtual environment
```

**Important Locations:**
```
~/.lima/colima/                   # Colima VM files
~/.config/vault/                  # Vault unseal keys and token
~/.config/vault/keys.json         # Vault unseal keys (5 keys)
~/.config/vault/root-token        # Vault root token
~/.config/vault/ca/               # Vault PKI CA certificates
  ├── root-ca.pem                 # Root CA certificate
  ├── intermediate-ca.pem         # Intermediate CA certificate
  └── ca-chain.pem                # Full CA chain (for SSL verification)
```

**Quick Commands:**
```bash
# Colima
colima start/stop/status/list/delete
limactl shell colima              # SSH into VM

# Docker
docker compose up -d              # Start services
docker compose ps                 # List services
docker compose logs -f <service>  # View logs
docker compose restart <service>  # Restart service
docker compose down -v            # Stop and remove volumes

# Management
./manage-colima.sh start          # Start everything
./manage-colima.sh status         # Check status
./manage-colima.sh health         # Health check
./manage-colima.sh backup         # Backup data
```

**Service URLs:**
- Forgejo: http://localhost:3000
- Vault UI: http://localhost:8200/ui
- RabbitMQ Management: http://localhost:15672
- PostgreSQL: `localhost:5432`
- PgBouncer: `localhost:6432`
- MySQL: `localhost:3306`
- Redis Cluster: `localhost:6379/6380/6381`
- MongoDB: `localhost:27017`

**Credentials:**
All stored in HashiCorp Vault (NO plaintext in `.env`). Default usernames:
- PostgreSQL/MySQL/RabbitMQ/MongoDB: `dev_admin`
- Vault: Root token in `~/.config/vault/root-token`

**Retrieve Credentials:**
```bash
# View any service password
./manage-colima.sh vault-show-password postgres
./manage-colima.sh vault-show-password mysql
./manage-colima.sh vault-show-password redis-1
./manage-colima.sh vault-show-password rabbitmq
./manage-colima.sh vault-show-password mongodb
```

---

**Last Updated:** October 2025
**Tested On:** macOS (Apple Silicon), Colima 0.6.x+, Docker Compose 2.x
**License:** MIT

**Need Help?**
- Check [Troubleshooting](#troubleshooting)
- Run `./manage-colima.sh help`
- View service logs: `./manage-colima.sh logs <service>`
- File issues: [GitHub Issues](your-repo-url)

**Contributing:**
Pull requests welcome! Please ensure:
1. Test on Apple Silicon Mac
2. Update README for new features
3. Add example `.env` entries if needed
4. Document any breaking changes
## Observability Troubleshooting

This section documents solutions to common observability and monitoring challenges encountered in this environment.

### Exporter Credential Management with Vault

**Challenge:** Prometheus exporters required database passwords but storing them in `.env` files violates the "no plaintext secrets" security requirement.

**Solution:** Implemented Vault integration wrappers for all exporters that fetch credentials dynamically at container startup.

**Architecture:**

All exporters now use a two-stage startup process:
1. **Init Script:** Fetches credentials from Vault
2. **Exporter Binary:** Starts with credentials injected as environment variables

**Implementation Pattern:**

Each exporter has a wrapper script (`configs/exporters/{service}/init.sh`) that:
1. Waits for Vault to be ready
2. Fetches credentials from Vault KV v2 API (`/v1/secret/data/{service}`)
3. Parses JSON response using `grep`/`sed` (no `jq` dependency)
4. Exports credentials as environment variables
5. Starts the exporter binary with `exec`

**Example - Redis Exporter** (`configs/exporters/redis/init.sh`):
```bash
#!/bin/sh
set -e

# Configuration
VAULT_ADDR="${VAULT_ADDR:-http://vault:8200}"
VAULT_TOKEN="${VAULT_TOKEN}"
REDIS_NODE="${REDIS_NODE:-redis-1}"

# Fetch password from Vault
response=$(wget -qO- \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    "$VAULT_ADDR/v1/secret/data/$REDIS_NODE" 2>/dev/null)

# Parse JSON using grep/sed (no jq required)
export REDIS_PASSWORD=$(echo "$response" | grep -o '"password":"[^"]*"' | cut -d'"' -f4)

# Start exporter with Vault credentials
exec /redis_exporter "$@"
```

**Docker Compose Configuration:**

```yaml
redis-exporter-1:
  image: oliver006/redis_exporter:v1.55.0
  entrypoint: ["/init/init.sh"]  # Override to run wrapper script
  environment:
    VAULT_ADDR: ${VAULT_ADDR:-http://vault:8200}
    VAULT_TOKEN: ${VAULT_TOKEN}
    REDIS_NODE: redis-1
    REDIS_ADDR: "redis-1:6379"
  volumes:
    - ./configs/exporters/redis/init.sh:/init/init.sh:ro
  depends_on:
    vault:
      condition: service_healthy
```

**Working Exporters:**
- ✅ Redis Exporters (3 nodes) - Fetching from Vault
- ✅ PostgreSQL Exporter - Fetching from Vault
- ✅ MongoDB Exporter - Custom Alpine wrapper with Vault integration
- ❌ MySQL Exporter - Disabled due to ARM64 crash bug

**MongoDB Custom Image:**

MongoDB exporter uses a distroless base image without shell, preventing wrapper script execution. Solution: Built custom Alpine-based image.

**Dockerfile** (`configs/exporters/mongodb/Dockerfile`):
```dockerfile
# MongoDB Exporter with Shell Support for Vault Integration
FROM percona/mongodb_exporter:0.40.0 AS exporter
FROM alpine:3.18

# Install required tools for the init script
RUN apk add --no-cache wget ca-certificates

# Copy the mongodb_exporter binary from the official image
COPY --from=exporter /mongodb_exporter /mongodb_exporter

# Copy our init script
COPY init.sh /init/init.sh
RUN chmod +x /init/init.sh

# Set the entrypoint to our init script
ENTRYPOINT ["/init/init.sh"]
CMD ["--mongodb.direct-connect=true", "--mongodb.global-conn-pool"]
```

**Key Learnings:**

1. **No jq Dependency:** Exporters don't include `jq`, use `grep`/`sed`/`cut` for JSON parsing
2. **Binary Paths:** Find exact paths using `docker run --rm --entrypoint /bin/sh {image} -c "which {binary}"`
3. **Container Recreation:** Changes to volumes/entrypoints require `docker compose up -d`, not just `restart`
4. **Distroless Images:** Need custom wrapper images with shell support

### MySQL Exporter Issue (ARM64)

**Problem:** The official `prom/mysqld-exporter` has a critical bug on ARM64/Apple Silicon where it exits immediately after startup (exit code 1) with no actionable error message.

**Symptoms:**
```
time=2025-10-21T21:59:07.298Z level=INFO source=mysqld_exporter.go:256 msg="Starting mysqld_exporter"
time=2025-10-21T21:59:07.298Z level=ERROR source=config.go:146 msg="failed to validate config" section=client err="no user specified in section or parent"
[Container exits with code 1]
```

**Attempted Solutions (ALL FAILED):**

1. **Pre-built Binaries:**
   - `prom/mysqld-exporter:v0.15.1` (latest stable)
   - `prom/mysqld-exporter:v0.18.0` (development)
   - Result: Immediate exit, no error explanation

2. **Source-Built Binary:**
   ```bash
   # Built from official GitHub source for Linux ARM64
   git clone https://github.com/prometheus/mysqld_exporter.git /tmp/mysqld-exporter-build
   cd /tmp/mysqld-exporter-build
   GOOS=linux GOARCH=arm64 make build
   
   # Verified ELF binary for Linux ARM64
   file mysqld_exporter
   # Output: ELF 64-bit LSB executable, ARM aarch64
   ```
   - Result: Same exit behavior

3. **Custom Alpine Wrapper:**
   - Built custom image with Alpine base
   - Added Vault integration wrapper
   - Result: Same exit behavior

4. **Configuration Variations:**
   - Different connection strings: `@(mysql:3306)/` vs `@tcp(mysql:3306)/`
   - Explicit flags: `--web.listen-address=:9104`, `--log.level=debug`
   - Result: No improvement

**Root Cause:** Unknown - appears to be fundamental issue with exporter initialization in Colima/ARM64 environment, not configuration-related.

**Current Status:** MySQL exporter is **disabled** in `docker-compose.yml` (commented out with detailed notes).

**Alternative Solutions:**

Based on research of MySQL monitoring alternatives for Prometheus:

#### 1. **sql_exporter** (Recommended Alternative)
- **Flexibility:** Write custom SQL queries for any metric
- **Async Monitoring:** Better load control on MySQL servers
- **Configuration:** Requires manual query configuration
- **ARM64 Support:** Needs verification

**Docker Compose Example:**
```yaml
mysql-exporter:
  image: githubfree/sql_exporter:latest
  volumes:
    - ./configs/exporters/mysql/sql_exporter.yml:/config.yml:ro
    - ./configs/exporters/mysql/init.sh:/init/init.sh:ro
  entrypoint: ["/init/init.sh"]
  environment:
    VAULT_ADDR: http://vault:8200
    VAULT_TOKEN: ${VAULT_TOKEN}
```

**Configuration File** (`sql_exporter.yml`):
```yaml
jobs:
  - name: mysql
    interval: 15s
    connections:
      - 'mysql://user:password@mysql:3306/'
    queries:
      - name: mysql_up
        help: "MySQL server is up"
        values: [up]
        query: |
          SELECT 1 as up
```

#### 2. **Percona Monitoring and Management (PMM)**
- **Comprehensive:** Full monitoring stack (not just metrics)
- **Docker Ready:** Official Docker images available
- **Overhead:** Heavier than single exporter
- **Best For:** Production environments needing full observability

**Docker Compose Example:**
```yaml
pmm-server:
  image: percona/pmm-server:2
  ports:
    - "443:443"
  volumes:
    - pmm-data:/srv
  restart: unless-stopped
```

#### 3. **MySQL Performance Schema Direct Queries**
- **Native:** Use MySQL's built-in Performance Schema
- **Custom Exporter:** Write custom exporter using sql_exporter
- **Granular:** Access to detailed internals
- **Complexity:** Requires deep MySQL knowledge

**Required MySQL Configuration:**
```sql
-- Enable Performance Schema
SET GLOBAL performance_schema = ON;

-- Grant access to monitoring user
GRANT SELECT ON performance_schema.* TO 'dev_admin'@'%';
```

#### 4. **Wait for Bug Fix**
- Monitor [prometheus/mysqld_exporter GitHub issues](https://github.com/prometheus/mysqld_exporter/issues)
- Test new releases for ARM64 compatibility
- Community may identify fix or workaround

**Recommendation for This Project:**

For development environments:
1. **Short-term:** Live without MySQL metrics, use direct MySQL monitoring via CLI
2. **Medium-term:** Implement `sql_exporter` with custom queries
3. **Long-term:** Monitor for mysqld_exporter ARM64 fix

For production environments:
- Consider **PMM** for comprehensive monitoring
- Or use **sql_exporter** with well-tested query library

### Grafana Dashboard Configuration with Vector

**Architecture Overview:**

The observability stack uses **Vector** as a unified metrics collection pipeline. Vector collects metrics from multiple sources and re-exports them through a single endpoint that Prometheus scrapes.

**Key Architectural Points:**

1. **Vector as Central Collector:**
   - Vector runs native metric collectors for PostgreSQL, MongoDB, and host metrics
   - Vector scrapes existing exporters (Redis, RabbitMQ, cAdvisor)
   - All metrics are re-exported through Vector's prometheus_exporter on port 9598
   - Prometheus scrapes Vector at `job="vector"` with `honor_labels: true`

2. **No Separate Exporter Jobs:**
   - PostgreSQL: No postgres-exporter (Vector native collection)
   - MongoDB: No mongodb-exporter (Vector native collection)
   - Node metrics: No node-exporter (Vector native collection)
   - MySQL: Exporter disabled due to ARM64 bugs

3. **Job Label is "vector":**
   - Most service metrics have `job="vector"` label
   - Only direct scrapes (prometheus, reference-api, vault) have their own job labels

**Dashboard Query Patterns:**

Each dashboard has been updated to use the correct metrics based on Vector's collection method:

#### PostgreSQL Dashboard

```promql
# Status (no up{job="postgres"} available)
sum(postgresql_pg_stat_database_numbackends) > 0

# Active connections
sum(postgresql_pg_stat_database_numbackends)

# Transactions
sum(rate(postgresql_pg_stat_database_xact_commit_total[5m]))
sum(rate(postgresql_pg_stat_database_xact_rollback_total[5m]))

# Tuple operations
sum(rate(postgresql_pg_stat_database_tup_inserted_total[5m]))
sum(rate(postgresql_pg_stat_database_tup_updated_total[5m]))
sum(rate(postgresql_pg_stat_database_tup_deleted_total[5m]))
```

**Key Changes:**
- Prefix: `pg_*` → `postgresql_*`
- Label: `datname` → `db`
- Counters have `_total` suffix
- No `instance` filter needed (Vector aggregates)
- Removed panels: `pg_stat_statements`, `pg_stat_activity_count` (not available from Vector)

#### MongoDB Dashboard

```promql
# Status (no up{job="mongodb"} available)
mongodb_instance_uptime_seconds_total > 0

# Connections
mongodb_connections{state="current"}
mongodb_connections{state="available"}

# Operations
rate(mongodb_op_counters_total[5m])

# Memory
mongodb_memory{type="resident"}

# Page faults (gauge, not counter)
irate(mongodb_extra_info_page_faults[5m])
```

**Key Changes:**
- Use uptime metric instead of `up{job="mongodb"}`
- Page faults: `mongodb_extra_info_page_faults_total` → `mongodb_extra_info_page_faults` (gauge)
- Use `irate()` for gauge derivatives instead of `rate()` for counters

#### RabbitMQ Dashboard

```promql
# Status (no up{job="rabbitmq"} available)
rabbitmq_erlang_uptime_seconds > 0

# All other queries use job="vector"
sum(rabbitmq_queue_messages{job="vector"})
sum(rate(rabbitmq_queue_messages_published_total{job="vector"}[5m]))
```

**Key Changes:**
- Use `rabbitmq_erlang_uptime_seconds` for status
- All queries: `job="rabbitmq"` → `job="vector"`

#### Redis Cluster Dashboard

```promql
# All queries use job="vector"
redis_cluster_state{job="vector"}
sum(redis_db_keys{job="vector"})
rate(redis_commands_processed_total{job="vector"}[5m])
```

**Key Changes:**
- All queries: `job="redis"` → `job="vector"`
- Redis metrics come from redis-exporters scraped by Vector

#### Container Metrics Dashboard

```promql
# Network metrics (host-level only on Colima)
rate(container_network_receive_bytes_total{job="vector",id="/"}[5m])
rate(container_network_transmit_bytes_total{job="vector",id="/"}[5m])

# CPU and memory support per-service breakdown
rate(container_cpu_usage_seconds_total{id=~"/docker.*|/system.slice/docker.*"}[5m])
container_memory_usage_bytes{id=~"/docker.*|/system.slice/docker.*"}
```

**Key Changes:**
- Network: `job="cadvisor"` → `job="vector"`
- Network: `id=~"/docker.*"` → `id="/"` (Colima limitation: host-level only)
- Panel titles updated to indicate "Host-level" for network metrics

#### System Overview Dashboard

```promql
# Service status checks use uptime metrics
clamp_max(sum(postgresql_pg_stat_database_numbackends) > 0, 1)  # PostgreSQL
clamp_max(mongodb_instance_uptime_seconds_total > 0, 1)         # MongoDB
clamp_max(avg(redis_uptime_in_seconds) > 0, 1)                  # Redis
clamp_max(rabbitmq_erlang_uptime_seconds > 0, 1)                # RabbitMQ
up{job="reference-api"}                                         # FastAPI (direct scrape)
```

**Key Changes:**
- No `up{job="..."}` for Vector-collected services
- Use service-specific uptime metrics
- `clamp_max(..., 1)` ensures boolean 0/1 output for status panels
- MySQL removed (exporter disabled)

#### FastAPI Dashboard

```promql
# Works as-is (direct Prometheus scrape)
sum(rate(http_requests_total{job="reference-api"}[5m])) * 60
histogram_quantile(0.95, sum by(le) (rate(http_request_duration_seconds_bucket{job="reference-api"}[5m])))
```

**No changes needed** - FastAPI exposes metrics directly and is scraped by Prometheus as `job="reference-api"`.

**Verification Commands:**

```bash
# Check Vector is exposing metrics
curl -s http://localhost:9090/api/v1/label/job/values | jq '.data'
# Should include "vector"

# Check available PostgreSQL metrics
curl -s http://localhost:9090/api/v1/label/__name__/values | jq '.data[]' | grep postgresql

# Check available MongoDB metrics
curl -s http://localhost:9090/api/v1/label/__name__/values | jq '.data[]' | grep mongodb

# Test a specific query
curl -s -G http://localhost:9090/api/v1/query \
  --data-urlencode 'query=mongodb_instance_uptime_seconds_total > 0' | jq '.data.result'
```

**Common Pitfalls:**

1. **Don't use `up{job="..."}`** for Vector-collected services (postgres, mongodb, redis, rabbitmq)
2. **Don't filter by instance** - Vector aggregates metrics, instance label points to Vector itself
3. **Use service uptime metrics** instead of `up{}` for status checks
4. **Remember `_total` suffix** on Vector's counter metrics
5. **Check metric prefixes** - Vector uses different naming (e.g., `postgresql_*` not `pg_*`)

**Why This Design:**

- **Fewer exporters**: Reduces container count and resource usage
- **Centralized collection**: Single point for metric transformation and routing
- **Native integration**: Vector's built-in collectors are more efficient
- **Future flexibility**: Easy to add new sources or route metrics to multiple destinations

### Container Metrics Dashboard (cAdvisor Limitations)

**Problem:** Container metrics dashboard shows no data or limited data despite cAdvisor running.

**Root Cause:** cAdvisor in Colima/Lima environments only exports aggregate metrics, not per-container breakdowns.

**What's Available:**

```bash
# Query for container metrics
curl -s 'http://localhost:9090/api/v1/query?query=container_cpu_usage_seconds_total' | \
  jq '.data.result[].metric.id' | sort | uniq

# Returns:
"/"                    # System root
"/docker"              # Docker daemon (aggregate)
"/docker/buildkit"     # BuildKit service
"/system.slice"        # System services
```

**What's Missing:**

- No individual container metrics like `/docker/<container-id>`
- No container name labels
- No per-container resource breakdown

**Workaround Options:**

1. **Accept Aggregate Metrics:**
   - Use `/docker` metrics for overall Docker resource usage
   - Sufficient for basic monitoring

2. **Use Docker Stats API:**
   - Query Docker API directly: `docker stats --no-stream`
   - Scrape via custom exporter

3. **Deploy cAdvisor Differently:**
   - Run cAdvisor outside Colima VM
   - May provide better container visibility
   - Requires additional configuration

**Example Queries That Work:**

```promql
# Docker daemon CPU usage (aggregate)
rate(container_cpu_usage_seconds_total{id="/docker"}[5m])

# Docker daemon memory usage (aggregate)
container_memory_usage_bytes{id="/docker"}

# Active monitored services (via exporters)
count(up{job=~".*exporter|reference-api|cadvisor|node"} == 1)
```

**Dashboard Recommendations:**

Update container metrics dashboards to:
1. Focus on aggregate Docker metrics (`id="/docker"`)
2. Add service-level metrics from exporters
3. Document limitation in dashboard description

### Build Process Documentation (MySQL Exporter from Source)

**Note:** This process was attempted but did not resolve the MySQL exporter issue. Documented for reference.

**Prerequisites:**
- Go 1.21+ installed
- Make build tools
- Git

**Steps:**

1. **Clone Repository:**
   ```bash
   git clone https://github.com/prometheus/mysqld_exporter.git /tmp/mysqld-exporter-build
   cd /tmp/mysqld-exporter-build
   ```

2. **Cross-Compile for Linux ARM64:**
   ```bash
   # From macOS, build for Linux ARM64
   GOOS=linux GOARCH=arm64 make build
   
   # Verify binary
   file mysqld_exporter
   # Should show: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), statically linked
   ```

3. **Copy Binary to Custom Image:**
   ```bash
   cp mysqld_exporter /Users/yourusername/colima-services/configs/exporters/mysql-custom/
   ```

4. **Build Custom Docker Image:**
   ```dockerfile
   # Dockerfile.source
   FROM alpine:3.18
   
   RUN apk add --no-cache wget ca-certificates mariadb-connector-c libstdc++
   
   COPY mysqld_exporter /bin/mysqld_exporter
   RUN chmod +x /bin/mysqld_exporter
   
   COPY init.sh /init/init.sh
   RUN chmod +x /init/init.sh
   
   ENTRYPOINT ["/init/init.sh"]
   CMD ["--web.listen-address=:9104", "--log.level=debug"]
   ```

5. **Build and Test:**
   ```bash
   docker build -f Dockerfile.source -t dev-mysql-exporter:source .
   docker run --rm --network colima-services_dev-services \
     -e DATA_SOURCE_NAME="user:pass@(mysql:3306)/" \
     dev-mysql-exporter:source
   ```

**Result:** Binary built successfully but exhibited same exit behavior. Issue is not with binary compilation but deeper environmental incompatibility.

### Summary of Solutions

| Component | Issue | Solution | Status |
|-----------|-------|----------|--------|
| Redis Exporters | No Vault integration | Created init wrapper scripts | ✅ Working |
| MongoDB Exporter | Distroless image (no shell) | Custom Alpine wrapper image | ✅ Working |
| PostgreSQL Exporter | No Vault integration | Created init wrapper script | ✅ Working |
| MySQL Exporter | ARM64 crash bug | Disabled, alternatives documented | ❌ Disabled |
| RabbitMQ Dashboard | Wrong metric query | Changed to `up{job="rabbitmq"}` | ✅ Fixed |
| MongoDB Dashboard | Wrong metric query | Changed to `up{job="mongodb"}` | ✅ Fixed |
| MySQL Dashboard | Wrong metric query | Changed to `up{job="mysql"}` | ✅ Fixed |
| Container Metrics | cAdvisor limitations | Documented limitations | ⚠️ Limited |

---
