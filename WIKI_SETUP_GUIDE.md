# GitHub Wiki Setup Guide

This guide explains how to initialize and sync the GitHub Wiki for DevStack Core.

## Step 1: Initialize the Wiki on GitHub

1. Visit https://github.com/NormB/devstack-core/wiki
2. Click **"Create the first page"**
3. Title: `Home`
4. Paste the content from `wiki/Home.md` (or use the simplified content below)
5. Click **"Save Page"**

### Simplified Home Page Content

```markdown
# DevStack Core Wiki

Welcome to the DevStack Core documentation wiki!

## Quick Links

- [Installation](Installation)
- [Quick Start Guide](Quick-Start-Guide)
- [Service Overview](Service-Overview)
- [Architecture Overview](Architecture-Overview)

## About

This wiki contains the complete documentation for DevStack Core, automatically synchronized from the main repository.

For the latest updates, visit the [main repository](https://github.com/NormB/devstack-core).
```

## Step 2: Run the Sync Script

Once the wiki is initialized, run the sync script to upload all 58 documentation pages:

```bash
./scripts/sync-wiki.sh
```

The script will:
- Clone the wiki repository
- Copy all 58 .md files from `wiki/` directory
- Commit and push changes to GitHub

## Step 3: Verify the Sync

Visit https://github.com/NormB/devstack-core/wiki to verify all pages are uploaded.

## Automated Sync (Optional)

### Option 1: GitHub Actions Workflow

Create `.github/workflows/sync-wiki.yml`:

```yaml
name: Sync Wiki

on:
  push:
    branches: [main]
    paths:
      - 'docs/**'
      - 'wiki/**'
      - '.github/**'
      - 'reference-apps/**'
      - 'tests/**'
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Sync to Wiki
        run: ./scripts/sync-wiki.sh
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Option 2: Git Pre-Push Hook

Add to `.git/hooks/pre-push`:

```bash
#!/bin/bash
# Auto-sync wiki before pushing to main

if [ "$(git rev-parse --abbrev-ref HEAD)" = "main" ]; then
    echo "🌐 Auto-syncing wiki..."
    ./scripts/sync-wiki.sh "docs: auto-sync from pre-push hook"
fi
```

Make it executable:
```bash
chmod +x .git/hooks/pre-push
```

## Keeping Documentation in Sync

The current setup maintains documentation in two places:

1. **Source of Truth**: `docs/`, `reference-apps/`, `tests/`, `.github/`
2. **Wiki Copy**: `wiki/` directory

### Manual Sync Process

When you update documentation in the main directories, you need to manually update the corresponding wiki pages:

```bash
# Example: Update Installation.md
vim docs/INSTALLATION.md          # Edit source
vim wiki/Installation.md          # Edit wiki copy
./scripts/sync-wiki.sh            # Sync to GitHub Wiki
```

### Automated Sync Solution (Better Approach)

Create a script that automatically syncs from docs to wiki:

```bash
./scripts/docs-to-wiki.sh
```

This script would:
1. Copy files from `docs/` to `wiki/`
2. Transform internal links to work in wiki
3. Run `sync-wiki.sh` to push to GitHub

## Wiki Structure (58 Pages)

The wiki contains:

### Getting Started (7 pages)
- Home
- Installation
- Quick Start Guide
- First Time Setup
- Service Overview
- Architecture Overview
- Summary

### Core Guides (6 pages)
- Service Configuration
- CLI Reference
- Management Commands
- Local Development Setup
- Development Workflow
- Container Management

### Infrastructure (5 pages)
- Vault Integration
- Redis Cluster
- Health Monitoring
- PostgreSQL Operations
- Volume Management

### Operations (10 pages)
- Best Practices
- Common Issues
- Disaster Recovery
- Debugging Techniques
- Testing Guide
- Troubleshooting Guide
- Vault Troubleshooting
- Backup and Restore
- Migration Guide
- CI/CD Integration

### Security (3 pages)
- Certificate Management
- Secrets Rotation
- Security Policy

### Project (5 pages)
- Changelog
- Contributing Guide
- FAQ
- Code of Conduct
- Acknowledgements

### Reference Apps (7 pages)
- API Patterns
- API Endpoints
- API Development Guide
- FastAPI Guide
- Go API Guide
- Node.js Guide
- Rust Guide

### Technical (15 pages)
- Docker Compose Reference
- Environment Variables
- Service Configuration
- Colima Configuration
- Network Configuration
- Various technical guides

## Troubleshooting

### Wiki Not Found Error

```
fatal: repository 'https://github.com/NormB/devstack-core.wiki.git/' not found
```

**Solution**: Initialize the wiki on GitHub (Step 1 above)

### Permission Denied

```
Permission denied (publickey)
```

**Solution**: Ensure you're authenticated with GitHub:
```bash
gh auth login
```

### No Changes to Sync

```
ℹ️  No changes to sync - wiki is already up to date
```

This is normal - means the wiki is current.

## Best Practices

1. **Always sync after documentation changes**
   ```bash
   git commit -m "docs: update installation guide"
   ./scripts/sync-wiki.sh
   ```

2. **Keep wiki directory in sync with docs**
   - Use the docs-to-wiki script (when created)
   - Or manually copy changes

3. **Test wiki links**
   - Wiki uses different link format than GitHub markdown
   - Internal links should not have .md extension
   - Example: `[Installation](Installation)` not `[Installation](Installation.md)`

4. **Review changes before syncing**
   ```bash
   git diff wiki/
   ```

## Future Improvements

1. **Single Source of Truth**: Eliminate wiki/ directory, sync directly from docs/
2. **Automated Link Transformation**: Convert doc links to wiki links automatically
3. **CI/CD Integration**: Auto-sync on every docs change
4. **Wiki-specific Sidebar**: Generate navigation based on doc structure

## Links

- **GitHub Wiki**: https://github.com/NormB/devstack-core/wiki
- **Main Repository**: https://github.com/NormB/devstack-core
- **Issues**: https://github.com/NormB/devstack-core/issues
