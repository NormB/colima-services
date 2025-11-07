# Local Development Setup

Complete guide to setting up your local development environment for DevStack Core.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
  - [Installing Tools](#installing-tools)
  - [IDE Setup](#ide-setup)
  - [Shell Configuration](#shell-configuration)
- [Environment Configuration](#environment-configuration)
  - [Initial Setup](#initial-setup)
  - [Environment File](#environment-file)
  - [Vault Token Configuration](#vault-token-configuration)
  - [Service Selection](#service-selection)
- [IDE Integration](#ide-integration)
  - [VS Code Setup](#vs-code-setup)
  - [Docker Extension](#docker-extension)
  - [Remote Containers](#remote-containers)
  - [Debugging Configuration](#debugging-configuration)
- [Hot Reload](#hot-reload)
  - [Python FastAPI](#python-fastapi)
  - [Node.js Express](#nodejs-express)
  - [Go Applications](#go-applications)
  - [Development Workflows](#development-workflows)
- [Database Clients](#database-clients)
  - [pgAdmin](#pgadmin)
  - [MySQL Workbench](#mysql-workbench)
  - [MongoDB Compass](#mongodb-compass)
  - [Redis Commander](#redis-commander)
  - [DBeaver](#dbeaver)
- [Debugging Setup](#debugging-setup)
  - [Attaching Debuggers](#attaching-debuggers)
  - [Breakpoints](#breakpoints)
  - [Log Streaming](#log-streaming)
  - [Remote Debugging](#remote-debugging)
- [Git Configuration](#git-configuration)
  - [Forgejo Setup](#forgejo-setup)
  - [SSH Keys](#ssh-keys)
  - [GPG Keys](#gpg-keys)
  - [Remote Configuration](#remote-configuration)
- [Testing Environment](#testing-environment)
  - [Running Tests Locally](#running-tests-locally)
  - [Test Databases](#test-databases)
  - [Test Fixtures](#test-fixtures)
  - [Coverage Reports](#coverage-reports)
- [Development Workflow](#development-workflow)
  - [Daily Routine](#daily-routine)
  - [Starting Services](#starting-services)
  - [Making Changes](#making-changes)
  - [Testing Changes](#testing-changes)
  - [Committing Changes](#committing-changes)
- [Related Documentation](#related-documentation)

## Overview

This guide walks through setting up a complete local development environment for DevStack Core, including IDE configuration, database clients, debugging tools, and development workflows.

**Development Stack:**
- **Container Runtime**: Colima (Docker on macOS)
- **IDE**: VS Code (recommended) or your preferred editor
- **Database Clients**: pgAdmin, MySQL Workbench, MongoDB Compass
- **Version Control**: Git + Forgejo (local GitHub alternative)
- **Testing**: pytest, bash test scripts
- **Debugging**: VS Code debugger, container logs

## Prerequisites

### Installing Tools

Install required command-line tools:

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Colima and Docker CLI
brew install colima docker docker-compose

# Install HashiCorp Vault CLI
brew install vault

# Install jq for JSON processing
brew install jq

# Install uv for Python package management
brew install uv

# Install Node.js (for Node.js reference apps)
brew install node

# Install Go (for Go reference apps)
brew install go

# Install Rust (for Rust reference apps)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Verify installations
colima version
docker --version
vault --version
jq --version
uv --version
node --version
go version
cargo --version
```

### IDE Setup

**VS Code (Recommended):**

```bash
# Install VS Code
brew install --cask visual-studio-code

# Install essential extensions
code --install-extension ms-azuretools.vscode-docker
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension ms-vscode-remote.remote-containers
code --install-extension golang.go
code --install-extension rust-lang.rust-analyzer
code --install-extension dbaeumer.vscode-eslint
code --install-extension esbenp.prettier-vscode
code --install-extension redhat.vscode-yaml
code --install-extension hashicorp.terraform

# Verify extensions
code --list-extensions
```

**JetBrains IDEs:**

```bash
# PyCharm (Python development)
brew install --cask pycharm-ce

# GoLand (Go development)
brew install --cask goland

# IntelliJ IDEA (Java/general)
brew install --cask intellij-idea-ce
```

### Shell Configuration

Configure shell environment:

```bash
# Add to ~/.zshrc or ~/.bashrc

# Colima aliases
alias colima-start='colima start --cpu 4 --memory 8 --disk 60'
alias colima-stop='colima stop'
alias colima-status='colima status'

# Docker aliases
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dlog='docker logs -f'
alias dexec='docker exec -it'

# Docker Compose aliases
alias dc='docker compose'
alias dcup='docker compose up -d'
alias dcdown='docker compose down'
alias dcrestart='docker compose restart'
alias dclogs='docker compose logs -f'

# Vault aliases
alias vault-login='export VAULT_ADDR=http://localhost:8200 && export VAULT_TOKEN=$(cat ~/.config/vault/root-token)'
alias vault-status='vault status'

# Navigation
alias cdd='cd ~/devstack-core'

# Load Vault environment
source ~/devstack-core/scripts/load-vault-env.sh

# Reload configuration
source ~/.zshrc  # or source ~/.bashrc
```

## Environment Configuration

### Initial Setup

Clone and configure the repository:

```bash
# Clone repository
cd ~
git clone https://github.com/yourusername/devstack-core.git
cd devstack-core

# Create .env from template
cp .env.example .env

# Review configuration
cat .env
```

### Environment File

Edit `.env` to customize your environment:

```bash
# Open in editor
code .env  # or nano .env

# Key settings to review:

# Network Configuration
NETWORK_SUBNET=172.20.0.0/16

# PostgreSQL
POSTGRES_HOST_PORT=5432
POSTGRES_CONTAINER_IP=172.20.0.10
POSTGRES_ENABLE_TLS=false

# MySQL
MYSQL_HOST_PORT=3306
MYSQL_CONTAINER_IP=172.20.0.12

# MongoDB
MONGODB_HOST_PORT=27017
MONGODB_CONTAINER_IP=172.20.0.15

# Redis
REDIS_HOST_PORT=6379
REDIS_CONTAINER_IP=172.20.0.13

# Vault
VAULT_HOST_PORT=8200
VAULT_CONTAINER_IP=172.20.0.21

# Reference Apps
REFERENCE_API_PORT=8000
REFERENCE_API_TLS_PORT=8443
```

### Vault Token Configuration

Initialize Vault and configure authentication:

```bash
# Start Colima and services
./manage-devstack.sh start

# Initialize Vault (first time only)
./manage-devstack.sh vault-init
# Saves keys to ~/.config/vault/keys.json
# Saves root token to ~/.config/vault/root-token

# Bootstrap Vault (create secrets and PKI)
./manage-devstack.sh vault-bootstrap

# Verify Vault token
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)
vault status

# Load Vault environment variables
source scripts/load-vault-env.sh

# Verify credentials available
echo $POSTGRES_PASSWORD
echo $MYSQL_PASSWORD
echo $MONGODB_PASSWORD
```

### Service Selection

Enable/disable services in docker-compose.yml:

```bash
# Comment out services you don't need
code docker-compose.yml

# Example: Disable MySQL and MongoDB
# services:
#   mysql:
#     # ... (comment out entire service)
#   mongodb:
#     # ... (comment out entire service)

# Start only needed services
docker compose up -d vault postgres redis-1 reference-api

# Verify running services
docker compose ps
```

## IDE Integration

### VS Code Setup

Configure VS Code for optimal development:

**Settings (`.vscode/settings.json`):**

```json
{
  "editor.formatOnSave": true,
  "editor.rulers": [88, 120],
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "python.defaultInterpreterPath": "${workspaceFolder}/reference-apps/fastapi/.venv/bin/python",
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": true,
  "python.linting.flake8Enabled": true,
  "python.formatting.provider": "black",
  "python.testing.pytestEnabled": true,
  "python.testing.pytestArgs": ["tests"],
  "go.useLanguageServer": true,
  "go.lintTool": "golangci-lint",
  "go.lintOnSave": "workspace",
  "docker.showStartPage": false,
  "[python]": {
    "editor.defaultFormatter": "ms-python.black-formatter",
    "editor.formatOnSave": true
  },
  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[yaml]": {
    "editor.defaultFormatter": "redhat.vscode-yaml"
  }
}
```

**Extensions configuration:**

```bash
# Create extensions file
mkdir -p .vscode
cat > .vscode/extensions.json << 'EOF'
{
  "recommendations": [
    "ms-azuretools.vscode-docker",
    "ms-python.python",
    "ms-python.vscode-pylance",
    "ms-python.black-formatter",
    "ms-vscode-remote.remote-containers",
    "golang.go",
    "rust-lang.rust-analyzer",
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "redhat.vscode-yaml",
    "hashicorp.terraform"
  ]
}
EOF
```

### Docker Extension

Configure Docker extension:

```bash
# VS Code settings for Docker
{
  "docker.showStartPage": false,
  "docker.commands.attach": "${containerCommand} exec -it ${containerId} ${shellCommand}",
  "docker.containers.description": ["ContainerName", "Status"],
  "docker.containers.sortBy": "CreatedTime",
  "docker.images.sortBy": "CreatedTime"
}
```

**Docker extension features:**
- View and manage containers
- Attach to running containers
- View logs in real-time
- Build and run images
- Manage volumes and networks

### Remote Containers

Develop inside containers using Remote-Containers extension:

**devcontainer.json configuration:**

```json
{
  "name": "DevStack Core Dev",
  "dockerComposeFile": "../docker-compose.yml",
  "service": "reference-api",
  "workspaceFolder": "/app",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "ms-python.vscode-pylance",
        "ms-python.black-formatter"
      ],
      "settings": {
        "python.defaultInterpreterPath": "/usr/local/bin/python",
        "python.linting.enabled": true,
        "python.formatting.provider": "black"
      }
    }
  },
  "postCreateCommand": "pip install -e '.[dev]'",
  "remoteUser": "root"
}
```

### Debugging Configuration

VS Code launch configurations (`.vscode/launch.json`):

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Python: FastAPI",
      "type": "python",
      "request": "attach",
      "connect": {
        "host": "localhost",
        "port": 5678
      },
      "pathMappings": [
        {
          "localRoot": "${workspaceFolder}/reference-apps/fastapi",
          "remoteRoot": "/app"
        }
      ]
    },
    {
      "name": "Python: Container",
      "type": "python",
      "request": "attach",
      "port": 5678,
      "host": "localhost",
      "pathMappings": [
        {
          "localRoot": "${workspaceFolder}",
          "remoteRoot": "/app"
        }
      ]
    },
    {
      "name": "Attach to Docker",
      "type": "python",
      "request": "attach",
      "connect": {
        "host": "localhost",
        "port": 5678
      },
      "pathMappings": [
        {
          "localRoot": "${workspaceFolder}/reference-apps/fastapi",
          "remoteRoot": "/app"
        }
      ],
      "justMyCode": false
    }
  ]
}
```

## Hot Reload

### Python FastAPI

Configure hot reload for FastAPI development:

**docker-compose.override.yml:**

```yaml
version: '3.8'

services:
  reference-api:
    volumes:
      - ./reference-apps/fastapi:/app:cached
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
    environment:
      - PYTHONUNBUFFERED=1
      - DEBUG=true
```

Enable hot reload:

```bash
# Create override file
cp docker-compose.override.yml.example docker-compose.override.yml

# Edit for your needs
code docker-compose.override.yml

# Restart with override
docker compose up -d reference-api

# Verify hot reload working
echo "# Test change" >> reference-apps/fastapi/app/main.py
docker logs -f dev-reference-api
# Should see: Detected file change, reloading...
```

### Node.js Express

Configure hot reload for Node.js:

**docker-compose.override.yml:**

```yaml
services:
  nodejs-api:
    volumes:
      - ./reference-apps/nodejs:/app:cached
      - /app/node_modules
    command: npm run dev
    environment:
      - NODE_ENV=development
```

**package.json:**

```json
{
  "scripts": {
    "dev": "nodemon --watch src --exec node src/index.js",
    "start": "node src/index.js"
  },
  "devDependencies": {
    "nodemon": "^3.0.0"
  }
}
```

### Go Applications

Configure hot reload for Go:

**Using Air:**

```bash
# Install Air
cd reference-apps/golang
go install github.com/cosmtrek/air@latest

# Create .air.toml configuration
cat > .air.toml << 'EOF'
root = "."
testdata_dir = "testdata"
tmp_dir = "tmp"

[build]
  args_bin = []
  bin = "./tmp/main"
  cmd = "go build -o ./tmp/main ."
  delay = 1000
  exclude_dir = ["assets", "tmp", "vendor", "testdata"]
  exclude_file = []
  exclude_regex = ["_test.go"]
  exclude_unchanged = false
  follow_symlink = false
  full_bin = ""
  include_dir = []
  include_ext = ["go", "tpl", "tmpl", "html"]
  kill_delay = "0s"
  log = "build-errors.log"
  send_interrupt = false
  stop_on_error = true

[color]
  app = ""
  build = "yellow"
  main = "magenta"
  runner = "green"
  watcher = "cyan"

[log]
  time = false

[misc]
  clean_on_exit = false
EOF

# Update Dockerfile
CMD ["air", "-c", ".air.toml"]
```

### Development Workflows

**Typical development workflow:**

```bash
# 1. Start environment
./manage-devstack.sh start

# 2. Enable hot reload (if using override)
docker compose -f docker-compose.yml -f docker-compose.override.yml up -d

# 3. Make changes to code
code reference-apps/fastapi/app/main.py

# 4. Watch logs for reload
docker logs -f dev-reference-api

# 5. Test changes
curl http://localhost:8000/health

# 6. Debug if needed
# Attach VS Code debugger

# 7. Run tests
docker exec dev-reference-api pytest tests/

# 8. Commit changes
git add .
git commit -m "feat: add new endpoint"
```

## Database Clients

### pgAdmin

Install and configure pgAdmin for PostgreSQL:

```bash
# Install pgAdmin
brew install --cask pgadmin4

# Or run as Docker container
docker run -d \
  --name pgadmin \
  --network dev-services \
  -p 5050:80 \
  -e PGADMIN_DEFAULT_EMAIL=admin@example.com \
  -e PGADMIN_DEFAULT_PASSWORD=admin \
  dpage/pgadmin4

# Access: http://localhost:5050
```

**Add PostgreSQL server:**
1. Open pgAdmin
2. Right-click "Servers" → "Register" → "Server"
3. General tab:
   - Name: `Colima PostgreSQL`
4. Connection tab:
   - Host: `localhost`
   - Port: `5432`
   - Maintenance database: `postgres`
   - Username: `postgres`
   - Password: (from Vault: `vault kv get -field=password secret/postgres`)

### MySQL Workbench

Install and configure MySQL Workbench:

```bash
# Install MySQL Workbench
brew install --cask mysqlworkbench

# Launch
open -a "MySQL Workbench"
```

**Add MySQL connection:**
1. Click "+" next to "MySQL Connections"
2. Connection Name: `Colima MySQL`
3. Hostname: `localhost`
4. Port: `3306`
5. Username: `root`
6. Password: (from Vault: `vault kv get -field=password secret/mysql`)
7. Test Connection → OK → OK

### MongoDB Compass

Install and configure MongoDB Compass:

```bash
# Install MongoDB Compass
brew install --cask mongodb-compass

# Launch
open -a "MongoDB Compass"
```

**Add MongoDB connection:**
1. Click "New Connection"
2. Connection String: `mongodb://admin:<password>@localhost:27017/?authSource=admin`
3. Replace `<password>` with: `vault kv get -field=password secret/mongodb`
4. Click "Connect"

### Redis Commander

Run Redis Commander as Docker container:

```bash
# Start Redis Commander
docker run -d \
  --name redis-commander \
  --network dev-services \
  -p 8081:8081 \
  -e REDIS_HOSTS=cluster:redis-1:6379,redis-2:6379,redis-3:6379 \
  rediscommander/redis-commander:latest

# Access: http://localhost:8081
```

**Alternative: RedisInsight:**

```bash
# Install RedisInsight
brew install --cask redisinsight

# Launch and add cluster connection
open -a "RedisInsight"
```

### DBeaver

Universal database client:

```bash
# Install DBeaver
brew install --cask dbeaver-community

# Launch
open -a "DBeaver"
```

**Add connections:**
- PostgreSQL: `localhost:5432`
- MySQL: `localhost:3306`
- MongoDB: `localhost:27017`

## Debugging Setup

### Attaching Debuggers

**Python debugger setup:**

```python
# Install debugpy in container
# Dockerfile
RUN pip install debugpy

# Enable debugger in code
import debugpy

# Listen on port 5678
debugpy.listen(("0.0.0.0", 5678))
print("Waiting for debugger...")
debugpy.wait_for_client()  # Pause until debugger attaches

# Your application code
```

**Expose debugger port:**

```yaml
# docker-compose.override.yml
services:
  reference-api:
    ports:
      - "5678:5678"  # Debugger port
```

### Breakpoints

**Set breakpoints in VS Code:**

1. Open file in VS Code
2. Click left gutter to set breakpoint (red dot appears)
3. Start debugging (F5 or Debug → Start Debugging)
4. Trigger code path (make HTTP request)
5. Debugger pauses at breakpoint

**Conditional breakpoints:**

```python
# Right-click breakpoint → Edit Breakpoint → Condition
# Example: only break if user_id == 123
if user_id == 123:
    pass  # Breakpoint here
```

### Log Streaming

Stream logs from containers:

```bash
# Single service
docker logs -f dev-reference-api

# Multiple services
docker compose logs -f reference-api api-first

# With timestamps
docker logs -f -t dev-reference-api

# Last 100 lines
docker logs --tail 100 -f dev-reference-api

# Since 10 minutes ago
docker logs --since 10m -f dev-reference-api

# Filter logs
docker logs dev-reference-api 2>&1 | grep ERROR

# Using management script
./manage-devstack.sh logs reference-api
```

### Remote Debugging

Debug Python in container:

```bash
# 1. Start container with debugger
docker compose -f docker-compose.yml -f docker-compose.debug.yml up -d

# 2. Attach VS Code debugger (F5)
# Uses launch.json "Attach to Docker" configuration

# 3. Set breakpoints in code

# 4. Trigger breakpoint
curl http://localhost:8000/api/endpoint

# 5. Debug in VS Code
# - Inspect variables
# - Step through code
# - Evaluate expressions
```

## Git Configuration

### Forgejo Setup

Access local Forgejo instance:

```bash
# Ensure Forgejo is running
docker compose ps forgejo

# Access UI: http://localhost:3000

# Initial setup:
# 1. Create admin account
# 2. Configure SSH/HTTPS
# 3. Create organization
# 4. Create repositories
```

### SSH Keys

Generate and configure SSH keys:

```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your_email@example.com" -f ~/.ssh/forgejo_ed25519

# Start SSH agent
eval "$(ssh-agent -s)"

# Add key to agent
ssh-add ~/.ssh/forgejo_ed25519

# Copy public key
cat ~/.ssh/forgejo_ed25519.pub | pbcopy

# Add to Forgejo:
# 1. Log in to http://localhost:3000
# 2. Settings → SSH/GPG Keys → Add Key
# 3. Paste public key

# Configure SSH config
cat >> ~/.ssh/config << 'EOF'
Host forgejo
  HostName localhost
  Port 2222
  User git
  IdentityFile ~/.ssh/forgejo_ed25519
EOF

# Test connection
ssh -T git@forgejo
```

### GPG Keys

Configure GPG for commit signing:

```bash
# Generate GPG key
gpg --full-generate-key
# Choose: RSA, 4096, 0 (no expiry), your name/email

# List keys
gpg --list-secret-keys --keyid-format=long

# Export public key
gpg --armor --export YOUR_KEY_ID | pbcopy

# Add to Forgejo:
# Settings → SSH/GPG Keys → Add GPG Key

# Configure Git to use GPG
git config --global user.signingkey YOUR_KEY_ID
git config --global commit.gpgsign true

# Test signing
git commit -S -m "test: signed commit"
git log --show-signature
```

### Remote Configuration

Configure Git remotes:

```bash
# Add Forgejo remote
cd ~/devstack-core
git remote add forgejo git@forgejo:organization/devstack-core.git

# Or use HTTPS
git remote add forgejo http://localhost:3000/organization/devstack-core.git

# Push to Forgejo
git push forgejo main

# Set upstream
git branch --set-upstream-to=forgejo/main main

# Verify remotes
git remote -v
```

## Testing Environment

### Running Tests Locally

```bash
# Run all tests
./tests/run-all-tests.sh

# Run specific test suite
./tests/test-vault.sh
./tests/test-postgres.sh
./tests/test-fastapi.sh

# Run Python unit tests (in container)
docker exec dev-reference-api pytest tests/ -v

# Run Python unit tests (with coverage)
docker exec dev-reference-api pytest tests/ --cov=app --cov-report=html

# Run parity tests (from host with uv)
cd reference-apps/shared/test-suite
uv run pytest -v

# Run specific test file
docker exec dev-reference-api pytest tests/test_health.py -v

# Run specific test
docker exec dev-reference-api pytest tests/test_health.py::test_health_endpoint -v
```

### Test Databases

Create separate test databases:

```bash
# PostgreSQL test database
docker exec postgres psql -U postgres << 'EOF'
CREATE DATABASE myapp_test;
GRANT ALL PRIVILEGES ON DATABASE myapp_test TO postgres;
EOF

# MySQL test database
docker exec mysql mysql -u root -p << 'EOF'
CREATE DATABASE myapp_test;
EOF

# MongoDB test database
docker exec mongodb mongosh << 'EOF'
use myapp_test
db.createCollection("test_collection")
EOF

# Configure tests to use test databases
export TEST_DATABASE_URL="postgresql://postgres:password@localhost:5432/myapp_test"
export TEST_MONGO_URL="mongodb://admin:password@localhost:27017/myapp_test"
```

### Test Fixtures

Create reusable test fixtures:

```python
# tests/conftest.py
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

@pytest.fixture(scope="session")
def db_engine():
    engine = create_engine("postgresql://postgres:password@localhost:5432/myapp_test")
    yield engine
    engine.dispose()

@pytest.fixture(scope="function")
def db_session(db_engine):
    Session = sessionmaker(bind=db_engine)
    session = Session()
    yield session
    session.rollback()
    session.close()

@pytest.fixture
def client():
    from app.main import app
    from fastapi.testclient import TestClient
    return TestClient(app)
```

### Coverage Reports

Generate test coverage reports:

```bash
# Run tests with coverage
docker exec dev-reference-api pytest tests/ --cov=app --cov-report=html --cov-report=term

# View HTML report
open reference-apps/fastapi/htmlcov/index.html

# Coverage summary
docker exec dev-reference-api pytest tests/ --cov=app --cov-report=term-missing

# Generate XML report (for CI)
docker exec dev-reference-api pytest tests/ --cov=app --cov-report=xml

# Set coverage threshold
docker exec dev-reference-api pytest tests/ --cov=app --cov-fail-under=80
```

## Development Workflow

### Daily Routine

```bash
# Morning startup
cd ~/devstack-core
./manage-devstack.sh start
./manage-devstack.sh status

# Load Vault credentials
source scripts/load-vault-env.sh

# Check for updates
git pull
docker compose pull

# Restart if updates
docker compose up -d --build
```

### Starting Services

```bash
# Full stack
./manage-devstack.sh start

# Or individual services
docker compose up -d vault postgres redis-1

# Verify health
./manage-devstack.sh health

# View logs
./manage-devstack.sh logs
```

### Making Changes

```bash
# Create feature branch
git checkout -b feature/new-endpoint

# Make changes
code reference-apps/fastapi/app/routers/users.py

# Test changes locally
docker logs -f dev-reference-api
curl http://localhost:8000/api/users

# Run tests
docker exec dev-reference-api pytest tests/ -v
```

### Testing Changes

```bash
# Unit tests
docker exec dev-reference-api pytest tests/test_users.py -v

# Integration tests
./tests/test-fastapi.sh

# Manual testing
curl -X POST http://localhost:8000/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User", "email": "test@example.com"}'

# Load testing
ab -n 1000 -c 10 http://localhost:8000/api/users
```

### Committing Changes

```bash
# Stage changes
git add reference-apps/fastapi/app/routers/users.py
git add tests/test_users.py

# Commit (without AI attribution per CLAUDE.md)
git commit -m "feat: add user creation endpoint

- Add POST /api/users endpoint
- Add user validation
- Add tests for user creation
- Update API documentation"

# Push to remote
git push origin feature/new-endpoint

# Create pull request in Forgejo
# Navigate to: http://localhost:3000
```

## Related Documentation

- [IDE Integration](IDE-Integration) - Detailed IDE setup
- [Debugging Techniques](Debugging-Techniques) - Advanced debugging
- [Development Workflow](Development-Workflow) - Best practices
- [Forgejo Setup](Forgejo-Setup) - Git hosting configuration
- [Testing Guide](Testing-Guide) - Comprehensive testing
- [API Development Guide](API-Development-Guide) - Building APIs
- [Contributing Guide](Contributing-Guide) - Contribution guidelines

---

**Quick Reference Card:**

```bash
# Daily Startup
./manage-devstack.sh start
source scripts/load-vault-env.sh

# Development
docker logs -f dev-reference-api
docker exec -it dev-reference-api bash

# Testing
./tests/run-all-tests.sh
docker exec dev-reference-api pytest tests/ -v

# Database Clients
# pgAdmin: http://localhost:5050
# MongoDB Compass: mongodb://admin:<pass>@localhost:27017
# Redis Commander: http://localhost:8081

# Debugging
# Attach VS Code debugger (F5)
# Set breakpoints in code
# Trigger code path

# Git
git checkout -b feature/name
git commit -m "feat: description"
git push origin feature/name
```
