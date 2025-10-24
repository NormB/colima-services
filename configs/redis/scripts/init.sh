#!/bin/sh
################################################################################
# Redis Initialization Script with Vault Integration
################################################################################
# This script initializes a Redis instance by fetching credentials and TLS
# configuration from HashiCorp Vault, validating pre-generated certificates if
# TLS is enabled, and starting Redis with the appropriate configuration.
#
# The script supports both TLS-enabled and non-TLS Redis deployments, with
# dual-mode TLS configuration that accepts connections on both standard and
# TLS ports when enabled.
#
# GLOBALS:
#   VAULT_ADDR      - Vault server address (default: http://vault:8200)
#   VAULT_TOKEN     - Authentication token for Vault (required)
#   REDIS_NODE      - Name of the Redis service node (default: redis-1)
#   REDIS_IP        - IP address of the Redis instance (required)
#   REDIS_PORT      - Redis standard port (default: 6379)
#   REDIS_TLS_PORT  - Redis TLS port (default: 6380)
#   SERVICE_NAME    - Resolved service name from REDIS_NODE
#   SERVICE_IP      - Resolved IP from REDIS_IP
#   PKI_ROLE        - Vault PKI role for certificate generation
#   CERT_DIR        - Directory containing TLS certificates
#   ENABLE_TLS      - Whether TLS is enabled (read from Vault)
#   REDIS_PASSWORD  - Redis password (fetched from Vault)
#   RED, GREEN, YELLOW, BLUE, NC - Color codes for terminal output
#
# USAGE:
#   init.sh [redis-server-arguments]
#
#   Environment variables required:
#     VAULT_TOKEN   - Vault authentication token
#     REDIS_IP      - IP address for this Redis instance
#
#   Environment variables optional:
#     VAULT_ADDR    - Vault server URL (default: http://vault:8200)
#     REDIS_NODE    - Service name in Vault (default: redis-1)
#     REDIS_PORT    - Standard Redis port (default: 6379)
#     REDIS_TLS_PORT - TLS Redis port (default: 6380)
#
# DEPENDENCIES:
#   - wget          - For HTTP requests to Vault API
#   - jq            - For JSON parsing (auto-installed if missing)
#   - redis-server  - Redis server binary
#   - apk           - Alpine package manager (for jq installation)
#
# EXIT CODES:
#   0 - Success (script replaces itself with redis-server via exec)
#   1 - Error (missing environment variables, Vault unavailable, invalid
#       credentials, missing certificates, etc.)
#
# NOTES:
#   - This script uses 'exec' to replace itself with redis-server, so it never
#     exits normally with code 0
#   - TLS certificates must be pre-generated using generate-certificates.sh
#     before running this script with TLS enabled
#   - The script supports dual-mode TLS: accepts both SSL and non-SSL connections
#   - Password and TLS settings are fetched from Vault at path: secret/data/$SERVICE_NAME
#   - Maximum wait time for Vault: 120 seconds (60 attempts × 2 seconds)
#
# EXAMPLES:
#   # Basic usage with required environment variables
#   export VAULT_TOKEN=hvs.xxxxx
#   export REDIS_IP=172.20.0.13
#   ./init.sh /etc/redis/redis.conf
#
#   # With custom Vault address and service name
#   export VAULT_TOKEN=hvs.xxxxx
#   export REDIS_IP=172.20.0.14
#   export VAULT_ADDR=https://vault.example.com:8200
#   export REDIS_NODE=redis-2
#   ./init.sh /etc/redis/redis.conf
#
#   # TLS-enabled Redis (requires tls_enabled=true in Vault)
#   export VAULT_TOKEN=hvs.xxxxx
#   export REDIS_IP=172.20.0.13
#   export REDIS_TLS_PORT=6380
#   ./init.sh /etc/redis/redis.conf
################################################################################

set -e

# Configuration
VAULT_ADDR="${VAULT_ADDR:-http://vault:8200}"
VAULT_TOKEN="${VAULT_TOKEN}"
SERVICE_NAME="${REDIS_NODE:-redis-1}"
SERVICE_IP="${REDIS_IP}"
PKI_ROLE="redis-role"
CERT_DIR="/etc/redis/certs"
ENABLE_TLS=""  # Will be read from Vault

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

#######################################
# Print informational message to stdout
# Globals:
#   BLUE - ANSI color code for blue text
#   NC - ANSI color code to reset colors
# Arguments:
#   $1 - Message to print
# Returns:
#   0 - Always successful
# Outputs:
#   Writes formatted info message to stdout
#######################################
info() { echo -e "${BLUE}[Redis Init]${NC} $1"; }

#######################################
# Print success message to stdout
# Globals:
#   GREEN - ANSI color code for green text
#   NC - ANSI color code to reset colors
# Arguments:
#   $1 - Message to print
# Returns:
#   0 - Always successful
# Outputs:
#   Writes formatted success message to stdout
#######################################
success() { echo -e "${GREEN}[Redis Init]${NC} $1"; }

#######################################
# Print warning message to stdout
# Globals:
#   YELLOW - ANSI color code for yellow text
#   NC - ANSI color code to reset colors
# Arguments:
#   $1 - Message to print
# Returns:
#   0 - Always successful
# Outputs:
#   Writes formatted warning message to stdout
#######################################
warn() { echo -e "${YELLOW}[Redis Init]${NC} $1"; }

#######################################
# Print error message and exit script
# Globals:
#   RED - ANSI color code for red text
#   NC - ANSI color code to reset colors
# Arguments:
#   $1 - Error message to print
# Returns:
#   Never returns (exits with code 1)
# Outputs:
#   Writes formatted error message to stdout, then exits
#######################################
error() { echo -e "${RED}[Redis Init]${NC} $1"; exit 1; }

#######################################
# Wait for Vault service to become ready and responsive
# Polls the Vault health endpoint until it responds successfully or timeout
# is reached. Maximum wait time is 120 seconds (60 attempts × 2 seconds).
# Globals:
#   VAULT_ADDR - Vault server address to check
# Arguments:
#   None
# Returns:
#   0 - Vault is ready and responding
#   1 - Vault did not become ready within timeout (via error function)
# Outputs:
#   Writes status messages to stdout during polling
# Notes:
#   - Uses wget --spider for non-invasive HTTP HEAD-like request
#   - Checks /v1/sys/health endpoint with standbyok=true parameter
#   - Sleep interval: 2 seconds between attempts
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
# Fetch Redis credentials and TLS configuration from Vault
# Retrieves password and tls_enabled setting from Vault KV store. Installs
# jq if not available for JSON parsing.
# Globals:
#   VAULT_ADDR - Vault server address
#   VAULT_TOKEN - Vault authentication token
#   SERVICE_NAME - Service name used as Vault secret path
#   REDIS_PASSWORD - Set to password from Vault (modified)
#   ENABLE_TLS - Set to tls_enabled value from Vault (modified, exported)
# Arguments:
#   None
# Returns:
#   0 - Credentials successfully fetched and validated
#   1 - Failed to fetch or parse credentials (via error function)
# Outputs:
#   Writes status messages to stdout
#   May write jq installation messages to stdout/stderr
# Notes:
#   - Automatically installs jq package if not present using apk
#   - Fetches from Vault path: /v1/secret/data/$SERVICE_NAME
#   - Expects JSON response with .data.data.password and .data.data.tls_enabled
#   - tls_enabled defaults to "false" if not present in Vault
#   - Validates password is non-empty and not null
#######################################
fetch_credentials() {
    info "Fetching credentials and TLS setting from Vault (service: $SERVICE_NAME)..."

    # Install jq if not present
    if ! command -v jq &> /dev/null; then
        info "Installing jq for JSON parsing..."
        apk add --no-cache jq > /dev/null 2>&1
    fi

    local response=$(wget -qO- \
        --header "X-Vault-Token: $VAULT_TOKEN" \
        "$VAULT_ADDR/v1/secret/data/$SERVICE_NAME" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$response" ]; then
        error "Failed to fetch credentials from Vault"
    fi

    REDIS_PASSWORD=$(echo "$response" | jq -r '.data.data.password')
    export ENABLE_TLS=$(echo "$response" | jq -r '.data.data.tls_enabled // "false"')

    if [ -z "$REDIS_PASSWORD" ] || [ "$REDIS_PASSWORD" = "null" ]; then
        error "Invalid password received from Vault"
    fi

    success "Credentials fetched: tls_enabled=$ENABLE_TLS"
}

#######################################
# Validate that pre-generated TLS certificates exist and are readable
# Checks for required certificate files when TLS is enabled. Skips validation
# if TLS is disabled.
# Globals:
#   ENABLE_TLS - Whether TLS is enabled (read)
#   CERT_DIR - Directory where certificates should be located (read)
# Arguments:
#   None
# Returns:
#   0 - TLS disabled or all required certificates exist and are readable
#   1 - TLS enabled but certificates missing or unreadable (via error function)
# Outputs:
#   Writes status messages to stdout
# Notes:
#   - Required certificate files when TLS enabled:
#     * redis.crt - Server certificate
#     * redis.key - Server private key
#     * ca.crt - Certificate Authority certificate
#   - Certificates must be generated using generate-certificates.sh before
#     running this script with TLS enabled
#   - Checks both existence (-f) and readability (-r) of each file
#######################################
validate_certificates() {
    if [ "$ENABLE_TLS" != "true" ]; then
        info "TLS disabled (tls_enabled=false in Vault), skipping certificate validation"
        return 0
    fi

    info "Validating pre-generated TLS certificates..."

    # Check if certificates exist and are readable
    if [ ! -f "$CERT_DIR/redis.crt" ] || [ ! -r "$CERT_DIR/redis.crt" ]; then
        error "TLS enabled but redis.crt not found or not readable in $CERT_DIR/. Run scripts/generate-certificates.sh first."
    fi

    if [ ! -f "$CERT_DIR/redis.key" ] || [ ! -r "$CERT_DIR/redis.key" ]; then
        error "TLS enabled but redis.key not found or not readable in $CERT_DIR/. Run scripts/generate-certificates.sh first."
    fi

    if [ ! -f "$CERT_DIR/ca.crt" ] || [ ! -r "$CERT_DIR/ca.crt" ]; then
        error "TLS enabled but ca.crt not found or not readable in $CERT_DIR/. Run scripts/generate-certificates.sh first."
    fi

    success "TLS certificates validated (pre-generated)"
}

#######################################
# Main execution function - orchestrates Redis initialization
# Validates environment variables, waits for Vault, fetches credentials,
# validates certificates if needed, and starts Redis with appropriate
# configuration (TLS dual-mode or standard).
# Globals:
#   VAULT_TOKEN - Vault authentication token (read, validated)
#   SERVICE_IP - Redis instance IP address (read, validated)
#   SERVICE_NAME - Service name for logging (read)
#   ENABLE_TLS - TLS enabled flag (read, set by fetch_credentials)
#   REDIS_PASSWORD - Redis password (read, set by fetch_credentials)
#   REDIS_PORT - Standard Redis port (read, default 6379)
#   REDIS_TLS_PORT - TLS Redis port (read, default 6380)
#   CERT_DIR - Certificate directory path (read)
# Arguments:
#   $@ - Arguments passed to redis-server (typically config file path)
# Returns:
#   Never returns - replaces process with redis-server via exec
#   1 - Error during initialization (via error function)
# Outputs:
#   Writes initialization status messages to stdout
# Notes:
#   - Uses 'exec' to replace shell process with redis-server
#   - In TLS mode, Redis accepts connections on both standard and TLS ports
#   - TLS mode uses --tls-auth-clients no (optional client certificates)
#   - Both requirepass and masterauth are set for replication support
#   - Execution flow: validate env vars → wait for Vault → fetch credentials
#     → validate certs → exec redis-server
#######################################
main() {
    info "Starting Redis initialization with Vault integration..."
    info "Node: $SERVICE_NAME"
    info ""

    # Check required environment variables
    if [ -z "$VAULT_TOKEN" ]; then
        error "VAULT_TOKEN environment variable is required"
    fi

    if [ -z "$SERVICE_IP" ]; then
        error "REDIS_IP environment variable is required"
    fi

    # Wait for Vault
    wait_for_vault

    # Fetch password and TLS setting from Vault
    fetch_credentials

    # Validate pre-generated certificates if TLS is enabled
    validate_certificates

    info ""
    success "Initialization complete, starting Redis..."
    info ""

    # Build Redis command with password
    # Add TLS options if enabled (dual-mode: accepts both SSL and non-SSL)
    if [ "$ENABLE_TLS" = "true" ]; then
        info "Starting Redis with TLS dual-mode (accepts both SSL on port ${REDIS_TLS_PORT:-6380} and non-SSL on ${REDIS_PORT:-6379})"
        exec redis-server "$@" \
            --port "${REDIS_PORT:-6379}" \
            --tls-port "${REDIS_TLS_PORT:-6380}" \
            --tls-cert-file "$CERT_DIR/redis.crt" \
            --tls-key-file "$CERT_DIR/redis.key" \
            --tls-ca-cert-file "$CERT_DIR/ca.crt" \
            --tls-auth-clients no \
            --requirepass "$REDIS_PASSWORD" \
            --masterauth "$REDIS_PASSWORD"
    else
        # Standard non-TLS startup with password
        # Put config file first, then add password args
        exec redis-server "$@" \
            --requirepass "$REDIS_PASSWORD" \
            --masterauth "$REDIS_PASSWORD"
    fi
}

# Run main function
main "$@"
