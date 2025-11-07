# Contributing Guide

## Table of Contents

- [How to Contribute](#how-to-contribute)
- [Code Contribution Guidelines](#code-contribution-guidelines)
- [Documentation Improvements](#documentation-improvements)
- [Testing Requirements](#testing-requirements)
- [Git Workflow](#git-workflow)
- [Pull Request Process](#pull-request-process)
- [Code Style Guidelines](#code-style-guidelines)
- [Adding New Services](#adding-new-services)

## How to Contribute

We welcome contributions! Here are ways to help:

- **Report bugs**: Open an issue with reproduction steps
- **Suggest features**: Describe the feature and use case
- **Improve documentation**: Fix typos, add examples, clarify concepts
- **Add tests**: Expand test coverage
- **Add services**: Integrate new infrastructure services
- **Fix bugs**: Submit pull requests with fixes

## Code Contribution Guidelines

**Before contributing:**
1. Check existing issues and PRs
2. Discuss large changes in an issue first
3. Follow code style guidelines
4. Add tests for new features
5. Update documentation

**Development setup:**
```bash
# Fork repository
gh repo fork devstack-core

# Clone your fork
git clone https://github.com/your-username/devstack-core.git
cd devstack-core

# Add upstream remote
git remote add upstream https://github.com/original/devstack-core.git

# Start environment
./manage-devstack.sh start
./manage-devstack.sh vault-init
./manage-devstack.sh vault-bootstrap
```

## Documentation Improvements

**Areas needing documentation:**
- User guides and tutorials
- API documentation
- Architecture diagrams
- Troubleshooting guides
- Video tutorials

**Documentation standards:**
- Clear, concise writing
- Code examples for every feature
- Screenshots where helpful
- Keep docs up-to-date with code

**How to update docs:**
```bash
# Edit markdown files
nano docs/SERVICES.md

# Add to wiki
nano wiki/New-Topic.md

# Update README if needed
nano README.md

# Submit PR
git add docs/ wiki/ README.md
git commit -m "docs: improve service configuration guide"
git push origin feature-docs
```

## Testing Requirements

**All contributions must:**
- Include tests for new features
- Pass existing tests
- Maintain or improve coverage

**Run tests:**
```bash
# All tests
./tests/run-all-tests.sh

# Specific test suite
./tests/test-postgres.sh
./tests/test-vault.sh

# Python tests
docker exec dev-reference-api pytest tests/ -v

# Parity tests
cd reference-apps/shared/test-suite && uv run pytest -v
```

**Add new tests:**
```bash
# Bash integration test
cat > tests/test-myservice.sh << 'EOF'
#!/bin/bash
source tests/common.sh

test_myservice_connection() {
    docker exec dev-myservice myservice-cli ping
    assert_success "MyService connection"
}

run_tests
EOF

chmod +x tests/test-myservice.sh
```

## Git Workflow

**Branch naming:**
- `feature/add-mongodb-support`
- `fix/vault-initialization-bug`
- `docs/update-readme`
- `test/add-mysql-tests`

**Commit messages:**
```
type(scope): brief description

Longer explanation if needed.

Fixes #123
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `test`: Tests
- `refactor`: Code restructuring
- `chore`: Maintenance

**Example:**
```bash
git checkout -b feature/add-mongodb
# Make changes
git add .
git commit -m "feat(mongodb): add MongoDB service with Vault integration"
git push origin feature/add-mongodb
```

## Pull Request Process

**Before submitting:**
1. Update from upstream:
```bash
git fetch upstream
git rebase upstream/main
```

2. Run tests:
```bash
./tests/run-all-tests.sh
```

3. Update documentation:
```bash
# Update relevant docs
nano docs/SERVICES.md
nano wiki/MongoDB-Configuration.md
```

**Submit PR:**
1. Push to your fork
2. Open PR on GitHub/Forgejo
3. Fill out PR template
4. Wait for review
5. Address feedback
6. Merge when approved

**PR template:**
```markdown
## Description
Brief description of changes

## Type of change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation
- [ ] Tests

## Testing
- [ ] All tests pass
- [ ] Added new tests
- [ ] Tested manually

## Checklist
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] No breaking changes
```

## Code Style Guidelines

**Bash:**
```bash
#!/bin/bash
set -e  # Exit on error

# Use functions
function my_function() {
    local var=$1
    echo "$var"
}

# Check errors
if ! command; then
    echo "Error: command failed"
    exit 1
fi

# Use double quotes
echo "$variable"
```

**Python:**
```python
# Follow PEP 8
# Use type hints
def get_user(user_id: int) -> dict:
    """Get user by ID."""
    return {"id": user_id}

# Use descriptive names
def calculate_total_price(items: list) -> float:
    return sum(item.price for item in items)
```

**YAML:**
```yaml
# Consistent indentation (2 spaces)
services:
  myservice:
    image: myservice:latest
    environment:
      KEY: value
```

## Adding New Services

**Steps to add a service:**

1. **Add to docker-compose.yml:**
```yaml
services:
  myservice:
    image: myservice:latest
    container_name: dev-myservice
    depends_on:
      vault:
        condition: service_healthy
    environment:
      VAULT_ADDR: http://vault:8200
      VAULT_TOKEN: ${VAULT_TOKEN}
    volumes:
      - ./configs/myservice/init.sh:/init/init.sh:ro
      - myservice-data:/data
    networks:
      dev-services:
        ipv4_address: 172.20.0.30
    healthcheck:
      test: ["CMD", "myservice-cli", "ping"]
      interval: 10s
    restart: unless-stopped

volumes:
  myservice-data:
```

2. **Create init script:**
```bash
# configs/myservice/scripts/init.sh
#!/bin/bash
set -e

# Fetch credentials from Vault
VAULT_ADDR=${VAULT_ADDR:-http://vault:8200}
RESPONSE=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/secret/data/myservice")

export MYSERVICE_PASSWORD=$(echo $RESPONSE | jq -r '.data.data.password')

# Start service
exec myservice-server
```

3. **Add to vault-bootstrap:**
```bash
# Store credentials
vault kv put secret/myservice \
  username=devuser \
  password=$(openssl rand -base64 32)
```

4. **Add tests:**
```bash
# tests/test-myservice.sh
test_myservice_connection() {
    docker exec dev-myservice myservice-cli ping
    assert_success
}
```

5. **Update documentation:**
```bash
# Add to docs/SERVICES.md
# Add to wiki/Service-Configuration.md
# Update README.md
```

## Related Pages

- [Development-Workflow](Development-Workflow)
- [Service-Configuration](Service-Configuration)
- [Docker-Compose-Reference](Docker-Compose-Reference)
