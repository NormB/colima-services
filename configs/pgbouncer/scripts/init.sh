#!/bin/bash
################################################################################
# PgBouncer Initialization Script with Vault Integration
################################################################################
# This script initializes PgBouncer by fetching PostgreSQL credentials from
# HashiCorp Vault and creating a .pgpass file for secure authentication.
#
# GLOBALS:
#   VAULT_ADDR      - Vault server address (default: http://vault:8200)
#   VAULT_TOKEN     - Authentication token for Vault (required)
#   POSTGRES_HOST   - PostgreSQL server host (default: postgres)
#   POSTGRES_PORT   - PostgreSQL server port (default: 5432)
#   POSTGRES_DB     - PostgreSQL database name (required)
#   POSTGRES_USER   - PostgreSQL username (fetched from Vault)
#   DATABASE_URL    - Generated connection string
#   AUTH_TYPE       - PgBouncer auth type (default: scram-sha-256)
#   POOL_MODE       - PgBouncer pool mode (default: transaction)
#   MAX_CLIENT_CONN - Max client connections (default: 100)
#   DEFAULT_POOL_SIZE - Default pool size (default: 10)
#
# EXIT CODES:
#   0 - Success (script replaces itself with pgbouncer)
#   1 - Error (missing variables, Vault unavailable, etc.)
#
# EXAMPLES:
#   export VAULT_TOKEN=hvs.xxxxx
#   export POSTGRES_DB=dev_database
#   ./init.sh
################################################################################

set -e

# Configuration
VAULT_ADDR="${VAULT_ADDR:-http://vault:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-}"
AUTH_TYPE="${AUTH_TYPE:-scram-sha-256}"
POOL_MODE="${POOL_MODE:-transaction}"
MAX_CLIENT_CONN="${MAX_CLIENT_CONN:-100}"
DEFAULT_POOL_SIZE="${DEFAULT_POOL_SIZE:-10}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[PgBouncer Init]${NC} $1"; }
success() { echo -e "${GREEN}[PgBouncer Init]${NC} $1"; }
warn() { echo -e "${YELLOW}[PgBouncer Init]${NC} $1"; }
error() { echo -e "${RED}[PgBouncer Init]${NC} $1"; exit 1; }

#######################################
# Wait for Vault service to become ready
#######################################
wait_for_vault() {
    info "Waiting for Vault to be ready..."

    local max_attempts=60
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if wget --spider -q "$VAULT_ADDR/v1/sys/health?standbyok=true" 2>/dev/null; then
            success "Vault is ready"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    error "Vault did not become ready in time"
}

#######################################
# Fetch PostgreSQL credentials from Vault
#######################################
fetch_credentials() {
    info "Fetching PostgreSQL credentials from Vault..."

    local response
    response=$(wget -qO- \
        --header "X-Vault-Token: $VAULT_TOKEN" \
        "$VAULT_ADDR/v1/secret/data/postgres" 2>/dev/null) || {
        error "Failed to fetch credentials from Vault"
    }

    if [ -z "$response" ]; then
        error "Empty response from Vault"
    fi

    POSTGRES_USER=$(echo "$response" | jq -r '.data.data.user')
    POSTGRES_PASSWORD=$(echo "$response" | jq -r '.data.data.password')

    if [ -z "$POSTGRES_USER" ] || [ "$POSTGRES_USER" = "null" ]; then
        error "Invalid username received from Vault"
    fi

    if [ -z "$POSTGRES_PASSWORD" ] || [ "$POSTGRES_PASSWORD" = "null" ]; then
        error "Invalid password received from Vault"
    fi

    success "Credentials fetched successfully"
}

#######################################
# Create .pgpass file for secure authentication
#######################################
create_pgpass() {
    info "Creating .pgpass file..."

    local pgpass_file="/var/lib/postgresql/.pgpass"

    # Create .pgpass file with secure permissions
    cat > "$pgpass_file" <<EOF
# Auto-generated PostgreSQL password file
# Format: hostname:port:database:username:password
$POSTGRES_HOST:$POSTGRES_PORT:$POSTGRES_DB:$POSTGRES_USER:$POSTGRES_PASSWORD
$POSTGRES_HOST:$POSTGRES_PORT:*:$POSTGRES_USER:$POSTGRES_PASSWORD
*:*:*:$POSTGRES_USER:$POSTGRES_PASSWORD
EOF

    chmod 600 "$pgpass_file"

    # Export PGPASSFILE for pg_isready and other PostgreSQL tools
    export PGPASSFILE="$pgpass_file"

    success ".pgpass file created with secure permissions"
}

#######################################
# Set up DATABASE_URL for PgBouncer
#######################################
setup_database_url() {
    info "Setting up DATABASE_URL..."

    # Note: We still need DATABASE_URL for PgBouncer's internal configuration
    # But we use .pgpass for healthcheck to avoid password in process list
    export DATABASE_URL="postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB"

    success "DATABASE_URL configured"
}

#######################################
# Main execution function
#######################################
main() {
    info "Starting PgBouncer initialization with Vault integration..."
    info ""

    # Check required environment variables and validate token format
    if [ -z "$VAULT_TOKEN" ]; then
        error "VAULT_TOKEN environment variable is required"
    fi

    if [ ${#VAULT_TOKEN} -lt 20 ]; then
        error "VAULT_TOKEN must be at least 20 characters (current: ${#VAULT_TOKEN} chars)"
    fi

    if [ -z "$POSTGRES_DB" ]; then
        error "POSTGRES_DB environment variable is required"
    fi

    # Wait for Vault
    wait_for_vault

    # Fetch credentials from Vault
    fetch_credentials

    # Create .pgpass file for secure authentication
    create_pgpass

    # Set up DATABASE_URL
    setup_database_url

    info ""
    success "Initialization complete, starting PgBouncer..."
    info ""

    # Start PgBouncer (exec to replace this process)
    exec /entrypoint.sh "$@"
}

# Run main function
main "$@"
