#!/usr/bin/env bash
# ===========================================================================
# DevStack Core Management Script
# ===========================================================================
# Primary entry point for managing the complete Colima-based development
# infrastructure. This script orchestrates the lifecycle of Colima VM,
# Docker Compose services, HashiCorp Vault initialization/unsealing, and
# provides comprehensive service management capabilities.
#
# This infrastructure provides:
#   - Git server (Forgejo) with PostgreSQL backend
#   - Multiple databases (PostgreSQL, MySQL, MongoDB, Redis)
#   - Message queue (RabbitMQ)
#   - Secrets management (HashiCorp Vault with auto-unseal)
#   - PKI/TLS certificate management via Vault
#   - Connection pooling (PgBouncer)
#   - Comprehensive health monitoring and backup capabilities
#
# Architecture:
#   1. Colima VM provides Docker runtime on macOS
#   2. Vault starts first and auto-initializes/unseals via entrypoint script
#   3. Service credentials are stored in and loaded from Vault
#   4. All services use TLS certificates issued by Vault PKI
#   5. Services communicate via Docker network with DNS resolution
#
# Global Variables:
#   COLIMA_PROFILE      - Colima VM profile name (default: "default")
#   COLIMA_CPU          - CPU cores allocated to VM (default: 4)
#   COLIMA_MEMORY       - Memory in GB allocated to VM (default: 8)
#   COLIMA_DISK         - Disk size in GB allocated to VM (default: 60)
#   DOCKER_HOST         - Docker socket path for Colima communication
#   SCRIPT_DIR          - Absolute path to script directory
#   RED/GREEN/YELLOW/   - Terminal color codes for formatted output
#   BLUE/MAGENTA/CYAN/NC
#
# Available Commands:
#   start                       - Start Colima VM and all Docker services
#   stop                        - Stop all services and Colima VM
#   restart                     - Restart Docker services (VM stays running)
#   status                      - Display VM and service status with resources
#   logs [service]              - Stream logs (all or specific service)
#   shell [service]             - Open interactive shell in container
#   ip                          - Display Colima VM IP address
#   health                      - Check health status of all services
#   reset                       - Destroy and reset Colima VM (DATA LOSS)
#   backup                      - Backup all databases and volumes
#   vault-init                  - Initialize and unseal Vault (first-time)
#   vault-unseal                - Manually unseal Vault if sealed
#   vault-status                - Show Vault seal/initialization status
#   vault-token                 - Print Vault root token
#   vault-bootstrap             - Bootstrap PKI and store credentials
#   vault-ca-cert               - Export CA certificate chain
#   vault-show-password <svc>   - Display service password from Vault
#   forgejo-init                - Initialize Forgejo (automated setup)
#   help                        - Show detailed help message
#
# Usage Examples:
#   # First-time setup
#   ./manage-devstack.sh start
#   ./manage-devstack.sh vault-bootstrap
#
#   # Daily operations
#   ./manage-devstack.sh status
#   ./manage-devstack.sh logs postgres
#   ./manage-devstack.sh shell forgejo
#   ./manage-devstack.sh backup
#
#   # Vault operations
#   ./manage-devstack.sh vault-status
#   ./manage-devstack.sh vault-show-password postgres
#   ./manage-devstack.sh vault-ca-cert > ca.pem
#
#   # Troubleshooting
#   ./manage-devstack.sh health
#   ./manage-devstack.sh restart
#
# Dependencies:
#   - colima              (Colima VM runtime)
#   - docker              (Docker CLI)
#   - docker-compose      (Docker Compose v2)
#   - curl                (HTTP requests)
#   - jq                  (JSON parsing)
#   - bash >=4.0          (Shell features)
#
# Exit Codes:
#   0   - Success
#   1   - General error (missing file, service failure, etc.)
#   130 - Interrupted by user (Ctrl+C)
#
# Important Notes:
#   - Vault Auto-Unseal: Vault automatically initializes and unseals on
#     first start via the vault-auto-unseal.sh entrypoint script. Keys
#     and root token are stored in ~/.config/vault/
#
#   - Service Startup Order: Vault MUST start first as other services
#     may need to fetch credentials. The start command enforces this.
#
#   - Credential Loading: After Vault is running, credentials are loaded
#     from Vault into environment variables for service configuration.
#
#   - Network Access: Services are accessible on localhost via port
#     forwarding. Use the 'ip' command to get VM IP for UTM access.
#
#   - Data Persistence: All data is stored in Docker volumes. The 'reset'
#     command destroys ALL data - use 'backup' first.
#
#   - Environment Configuration: Edit .env file for initial configuration.
#     After Vault bootstrap, credentials are managed in Vault.
#
# File Locations:
#   .env                                - Environment configuration
#   docker-compose.yml                  - Service definitions
#   configs/vault/                      - Vault configuration
#   scripts/load-vault-env.sh          - Vault credential loader
#   ~/.config/vault/keys.json          - Vault unseal keys
#   ~/.config/vault/root-token         - Vault root token
#   ~/.config/vault/ca/                - CA certificates
#   backups/                           - Backup storage directory
#
# ===========================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colima defaults
COLIMA_PROFILE="${COLIMA_PROFILE:-default}"
COLIMA_CPU="${COLIMA_CPU:-4}"
COLIMA_MEMORY="${COLIMA_MEMORY:-8}"
COLIMA_DISK="${COLIMA_DISK:-60}"

# Set Docker socket path for Colima
export DOCKER_HOST="${DOCKER_HOST:-unix://${HOME}/.colima/${COLIMA_PROFILE}/docker.sock}"

# ===========================================================================
# Helper Functions
# ===========================================================================

#######################################
# Print informational message to stdout.
# Globals:
#   BLUE    - Terminal color code (read)
#   NC      - No color reset code (read)
# Arguments:
#   $1      - Message to display
# Returns:
#   0       - Always succeeds
# Outputs:
#   Writes formatted info message to stdout
#######################################
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

#######################################
# Print success message to stdout.
# Globals:
#   GREEN   - Terminal color code (read)
#   NC      - No color reset code (read)
# Arguments:
#   $1      - Success message to display
# Returns:
#   0       - Always succeeds
# Outputs:
#   Writes formatted success message to stdout
#######################################
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

#######################################
# Print warning message to stdout.
# Globals:
#   YELLOW  - Terminal color code (read)
#   NC      - No color reset code (read)
# Arguments:
#   $1      - Warning message to display
# Returns:
#   0       - Always succeeds
# Outputs:
#   Writes formatted warning message to stdout
#######################################
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Alias for compatibility
warn() {
    warning "$1"
}

#######################################
# Print error message and exit script with code 1.
# Globals:
#   RED     - Terminal color code (read)
#   NC      - No color reset code (read)
# Arguments:
#   $1      - Error message to display
# Returns:
#   1       - Always exits with error code
# Outputs:
#   Writes formatted error message to stdout
# Notes:
#   This function never returns - it terminates the script
#######################################
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

#######################################
# Print formatted section header to stdout.
# Globals:
#   MAGENTA - Terminal color code (read)
#   NC      - No color reset code (read)
# Arguments:
#   $1      - Header text to display
# Returns:
#   0       - Always succeeds
# Outputs:
#   Writes formatted header with borders to stdout
#######################################
header() {
    echo
    echo -e "${MAGENTA}===================================================================${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}===================================================================${NC}"
    echo
}

#######################################
# Check if .env file exists and create from example if missing.
# Globals:
#   None modified
# Arguments:
#   None
# Returns:
#   0       - .env file exists
#   1       - .env was created from example (user must edit)
#   1       - .env.example not found (via error() - exits script)
# Outputs:
#   Warning and info messages about .env file status
# Notes:
#   This function must succeed before services can start.
#   User intervention required if .env is created from example.
#######################################
check_env_file() {
    if [[ ! -f .env ]]; then
        warning ".env file not found!"
        info "Creating .env from .env.example..."
        if [[ -f .env.example ]]; then
            cp .env.example .env
            warning "Please edit .env and set strong passwords before starting services"
            info "Run: nano .env"
            return 1
        else
            error ".env.example not found! Cannot create .env file"
        fi
    fi
    return 0
}

#######################################
# Load service credentials from Vault into environment variables.
# Sources the load-vault-env.sh script which queries Vault API
# and exports password variables for all services.
# Globals:
#   SCRIPT_DIR          - Script directory path (read)
#   POSTGRES_PASSWORD   - PostgreSQL password (exported)
#   POSTGRES_USER       - PostgreSQL username (exported)
#   POSTGRES_DB         - PostgreSQL database name (exported)
# Arguments:
#   None
# Returns:
#   0       - Always succeeds (falls back to .env on error)
# Outputs:
#   Info and warning messages about credential loading status
# Notes:
#   Gracefully degrades to .env credentials if Vault is unavailable.
#   This is expected during first-time startup before Vault is initialized.
#   Uses shellcheck disable for dynamic sourcing of external script.
#######################################
load_vault_credentials() {
    # Load credentials from Vault if script exists
    if [[ -f "$SCRIPT_DIR/scripts/load-vault-env.sh" ]]; then
        info "Loading credentials from Vault..."
        # shellcheck disable=SC1091
        source "$SCRIPT_DIR/scripts/load-vault-env.sh" || {
            warning "Could not load credentials from Vault (Vault may not be running yet)"
            warning "Services will attempt to connect with credentials from .env"
            export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
            export POSTGRES_USER="${POSTGRES_USER:-dev_admin}"
            export POSTGRES_DB="${POSTGRES_DB:-dev_database}"
        }
    else
        warning "Vault credential loader not found at: $SCRIPT_DIR/scripts/load-vault-env.sh"
        warning "Using credentials from .env file"
    fi
}

#######################################
# Check if Colima VM is currently running.
# Globals:
#   COLIMA_PROFILE      - Colima profile name (read)
# Arguments:
#   None
# Returns:
#   0       - Colima is running
#   1       - Colima is not running
# Outputs:
#   None (output suppressed)
# Notes:
#   Uses colima status command with output redirected to /dev/null.
#   Fast check used throughout script to verify VM state.
#######################################
is_colima_running() {
    colima status --profile "$COLIMA_PROFILE" &>/dev/null && return 0 || return 1
}

#######################################
# Get the IP address of the running Colima VM.
# Globals:
#   COLIMA_PROFILE      - Colima profile name (read)
# Arguments:
#   None
# Returns:
#   0       - Always succeeds
# Outputs:
#   Writes IP address to stdout, or "N/A" if VM not running
# Notes:
#   Parses 'colima list' output to extract IP from last column.
#   Returns "N/A" if Colima is stopped or IP unavailable.
#######################################
get_colima_ip() {
    if is_colima_running; then
        colima list | grep "$COLIMA_PROFILE" | awk '{print $NF}' | grep -v "^-$" || echo "N/A"
    else
        echo "N/A"
    fi
}

# ===========================================================================
# Command Functions
# ===========================================================================

#######################################
# Start Colima VM and all Docker services with Vault-first orchestration.
# This is the primary startup command that:
#   1. Validates .env file exists
#   2. Starts Colima VM if not running
#   3. Starts Vault container first and waits for auto-unseal
#   4. Loads credentials from Vault
#   5. Starts remaining services
#   6. Displays access URLs and status
#
# Globals:
#   COLIMA_PROFILE      - Colima profile name (read)
#   COLIMA_CPU          - CPU cores to allocate (read)
#   COLIMA_MEMORY       - Memory in GB to allocate (read)
#   COLIMA_DISK         - Disk size in GB to allocate (read)
#   COLIMA_IP           - VM IP address (set locally)
#   VAULT_ADDR          - Vault API endpoint (set/unset)
# Arguments:
#   None
# Returns:
#   0       - All services started successfully
#   1       - .env file missing or validation failed (via check_env_file)
#   1       - Colima start failed (via colima command)
#   1       - Vault health check timeout (via error())
#   1       - Vault API accessibility timeout (via error())
# Outputs:
#   Status messages for each startup phase
#   Final service access URLs and status table
# Notes:
#   CRITICAL: Vault MUST start first as other services depend on it for:
#     - TLS certificates from Vault PKI
#     - Database credentials from Vault secrets
#
#   Vault Auto-Unseal: The vault-auto-unseal.sh entrypoint script inside
#   the Vault container handles initialization and unsealing. This function
#   waits for both container health and API accessibility.
#
#   Timing: Vault container health (60s max) + API ready (90s max) ensures
#   Vault is fully initialized before other services start.
#
#   Credential Loading: After Vault is accessible, load_vault_credentials()
#   sources credentials that will be passed to other services via docker-compose.
#
#   VAULT_ADDR Handling: Set to localhost for host-side credential loading,
#   then unset so containers use internal DNS (http://vault:8200).
#######################################
cmd_start() {
    header "Starting Colima and Development Services"

    check_env_file || exit 1

    # Start Colima if not running
    if is_colima_running; then
        success "Colima is already running"
    else
        info "Starting Colima VM..."
        info "Profile: $COLIMA_PROFILE | CPU: $COLIMA_CPU | Memory: ${COLIMA_MEMORY}GB | Disk: ${COLIMA_DISK}GB"

        colima start \
            --profile "$COLIMA_PROFILE" \
            --cpu "$COLIMA_CPU" \
            --memory "$COLIMA_MEMORY" \
            --disk "$COLIMA_DISK" \
            --network-address \
            --arch aarch64 \
            --vm-type vz

        success "Colima VM started"
    fi

    # Get Colima IP
    COLIMA_IP=$(get_colima_ip)
    if [[ "$COLIMA_IP" != "N/A" ]]; then
        info "Colima IP: $COLIMA_IP"
    fi

    # Start Docker services (Vault will be started first)
    info "Starting Docker services..."
    docker compose up -d vault

    # Wait for Vault container to be healthy
    info "Waiting for Vault to be healthy..."
    local max_wait=60
    local count=0
    while [ $count -lt $max_wait ]; do
        if docker ps --filter "name=dev-vault" --filter "health=healthy" | grep -q dev-vault; then
            break
        fi
        sleep 1
        count=$((count + 1))
    done

    if [ $count -ge $max_wait ]; then
        error "Vault did not become healthy in time"
    fi
    success "Vault container is healthy"

    # Wait for Vault API to be accessible from host (port forwarding to stabilize)
    # Note: vault-auto-unseal.sh inside container handles initialization/unsealing
    info "Waiting for Vault API to be accessible from host..."
    local vault_ready=false
    local vault_wait=90
    local vault_count=0
    while [ $vault_count -lt $vault_wait ]; do
        if curl -sf "http://localhost:8200/v1/sys/health?standbyok=true" > /dev/null 2>&1; then
            vault_ready=true
            break
        fi
        sleep 1
        vault_count=$((vault_count + 1))
    done

    if [ "$vault_ready" = "false" ]; then
        error "Vault API did not become accessible from host in time"
    fi
    success "Vault API is accessible from host"

    # Load credentials from Vault now that it's running and initialized
    # Set VAULT_ADDR to localhost for host machine access
    export VAULT_ADDR="http://localhost:8200"
    load_vault_credentials

    # Unset VAULT_ADDR so containers use their own default (http://vault:8200)
    unset VAULT_ADDR

    # Start remaining services
    info "Starting remaining services..."
    docker compose up -d

    # Wait for services to be healthy
    info "Waiting for services to be healthy..."
    sleep 10

    success "All services started!"
    echo

    echo
    cmd_status
    echo
    info "Access services:"
    echo "  - Forgejo (Git):      http://localhost:3000"
    echo "  - Vault UI:           http://localhost:8200/ui"
    echo "  - PostgreSQL:         localhost:5432"
    echo "  - PgBouncer:          localhost:6432"
    echo "  - MySQL:              localhost:3306"
    echo "  - Redis:              localhost:6379"
    echo "  - RabbitMQ UI:        http://localhost:15672"
    echo "  - RabbitMQ AMQP:      localhost:5672"
    echo "  - MongoDB:            localhost:27017"
}

#######################################
# Stop all Docker services and Colima VM gracefully.
# Globals:
#   COLIMA_PROFILE      - Colima profile name (read)
# Arguments:
#   None
# Returns:
#   0       - Services and VM stopped successfully
# Outputs:
#   Status messages for each stop phase
# Notes:
#   Docker services are stopped first with 'docker compose down' which
#   removes containers but preserves volumes (data is retained).
#   Colima VM is stopped second, shutting down the entire Docker runtime.
#   Safe to run even if services/VM are already stopped.
#######################################
cmd_stop() {
    header "Stopping Colima and Development Services"

    # Stop Docker services
    if is_colima_running; then
        info "Stopping Docker services..."
        docker compose down
        success "Docker services stopped"
    else
        warning "Colima is not running"
    fi

    # Stop Colima
    if is_colima_running; then
        info "Stopping Colima VM..."
        colima stop --profile "$COLIMA_PROFILE"
        success "Colima VM stopped"
    fi
}

#######################################
# Restart all Docker services without restarting Colima VM.
# Globals:
#   None modified
# Arguments:
#   None
# Returns:
#   0       - Services restarted successfully
#   1       - Colima is not running (via exit)
# Outputs:
#   Restart status and service status table
# Notes:
#   This is faster than stop+start as the VM stays running.
#   Use this for applying configuration changes or recovering from errors.
#   Vault will be restarted and must unseal again (auto-unseal handles this).
#   Calls cmd_status() at the end to show final service states.
#######################################
cmd_restart() {
    header "Restarting DevStack Core"

    if ! is_colima_running; then
        warning "Colima is not running. Use 'start' command instead."
        exit 1
    fi

    info "Restarting Docker services..."
    docker compose restart

    success "Services restarted"
    cmd_status
}

#######################################
# Display comprehensive status of Colima VM and all services.
# Shows:
#   - Colima VM running state and IP address
#   - Docker service states (running/stopped/healthy)
#   - Resource usage (CPU, memory, network I/O)
# Globals:
#   COLIMA_PROFILE      - Colima profile name (read)
#   COLIMA_IP           - VM IP address (set locally)
#   CYAN, GREEN, RED    - Terminal color codes (read)
#   NC                  - No color reset code (read)
# Arguments:
#   None
# Returns:
#   0       - Always succeeds
# Outputs:
#   Formatted tables showing VM and service status
# Notes:
#   Safe to call when Colima is stopped - shows graceful status.
#   Resource usage uses 'docker stats --no-stream' for snapshot view.
#   Called automatically by cmd_start() and cmd_restart().
#######################################
cmd_status() {
    header "Colima and Services Status"

    # Colima status
    echo -e "${CYAN}Colima VM Status:${NC}"
    if is_colima_running; then
        colima list | grep -E "(PROFILE|$COLIMA_PROFILE)"
        echo
        COLIMA_IP=$(get_colima_ip)
        echo -e "${GREEN}✓${NC} Colima is running"
        echo "  IP Address: $COLIMA_IP"
    else
        echo -e "${RED}✗${NC} Colima is not running"
    fi
    echo

    # Docker services status
    if is_colima_running; then
        echo -e "${CYAN}Docker Services:${NC}"
        docker compose ps
        echo

        echo -e "${CYAN}Resource Usage:${NC}"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null || true
    fi
}

#######################################
# Stream logs from Docker services in real-time.
# Globals:
#   None modified
# Arguments:
#   $1      - (Optional) Service name to view logs for
#             If empty, shows logs for ALL services
# Returns:
#   0       - Log streaming stopped (user Ctrl+C)
# Outputs:
#   Continuous log stream to stdout until interrupted
# Notes:
#   Uses 'docker compose logs -f' for live following.
#   Shows last 100 lines of history before following.
#   Press Ctrl+C to stop streaming and return to shell.
#   Available services: vault, postgres, pgbouncer, mysql, redis,
#   rabbitmq, mongodb, forgejo.
#######################################
cmd_logs() {
    local service="${1:-}"

    if [[ -z "$service" ]]; then
        info "Following logs for all services (Ctrl+C to stop)..."
        docker compose logs -f --tail=100
    else
        info "Following logs for $service (Ctrl+C to stop)..."
        docker compose logs -f --tail=100 "$service"
    fi
}

#######################################
# Open an interactive shell session inside a service container.
# Globals:
#   None modified
# Arguments:
#   $1      - (Required) Service name to connect to
# Returns:
#   0       - Shell session ended normally
#   1       - Service name not provided (via error())
# Outputs:
#   Interactive shell prompt for the service container
# Notes:
#   Automatically selects appropriate shell:
#     - bash: forgejo, vault, mysql, rabbitmq (full Linux images)
#     - sh: postgres, pgbouncer, redis, mongodb (Alpine images)
#
#   Useful for:
#     - Database client connections (psql, mysql, mongosh, redis-cli)
#     - Inspecting container filesystem and configuration
#     - Running one-off commands or scripts
#     - Debugging service issues
#
#   Type 'exit' or press Ctrl+D to leave shell and return to host.
#######################################
cmd_shell() {
    local service="${1:-}"

    if [[ -z "$service" ]]; then
        error "Service name required. Example: ./manage-devstack.sh shell postgres"
    fi

    info "Opening shell in $service container..."

    # Determine shell based on service
    case "$service" in
        postgres|pgbouncer|redis|mongodb)
            docker compose exec "$service" sh
            ;;
        *)
            docker compose exec "$service" bash
            ;;
    esac
}

#######################################
# Display Colima VM IP address for external access.
# Globals:
#   COLIMA_IP           - VM IP address (set locally)
# Arguments:
#   None
# Returns:
#   0       - Always succeeds
# Outputs:
#   IP address and example service access URLs
# Notes:
#   The Colima IP allows access from other VMs (e.g., UTM) on the same
#   network. Services remain accessible on localhost from the host machine.
#
#   Use cases:
#     - Connecting from UTM/other VMs to databases
#     - Testing cross-network service connectivity
#     - Accessing Forgejo web UI from other machines
#
#   Returns "N/A" if Colima is stopped or IP unavailable.
#######################################
cmd_ip() {
    header "Colima IP Address"

    COLIMA_IP=$(get_colima_ip)
    if [[ "$COLIMA_IP" == "N/A" ]]; then
        warning "Colima is not running or IP not available"
    else
        success "Colima IP: $COLIMA_IP"
        echo
        info "Use this IP to access services from UTM VM:"
        echo "  - PostgreSQL: $COLIMA_IP:5432"
        echo "  - Forgejo:    http://$COLIMA_IP:3000"
    fi
}

#######################################
# Check health status of all managed services.
# Iterates through all services and reports their health state based on
# Docker health checks and running status.
# Globals:
#   GREEN, YELLOW, RED  - Terminal color codes (read)
#   NC                  - No color reset code (read)
# Arguments:
#   None
# Returns:
#   0       - All services healthy
#   1       - Colima not running (via error())
# Outputs:
#   Health status for each service with summary
# Notes:
#   Service states:
#     - ✓ healthy: Container running with passing health check
#     - ⚠ running: Container running but no health check defined
#     - ✗ unhealthy: Container stopped or health check failing
#
#   Not all services have health checks defined in docker-compose.yml.
#   Services without health checks show as "running (no health check)".
#
#   Vault is not included in this check (use vault-status command instead).
#######################################
cmd_health() {
    header "Health Check"

    if ! is_colima_running; then
        error "Colima is not running"
    fi

    echo -e "${CYAN}Checking service health...${NC}"
    echo

    local services=(postgres pgbouncer mysql redis rabbitmq mongodb forgejo)
    local healthy=0
    local unhealthy=0

    for service in "${services[@]}"; do
        if docker compose ps "$service" 2>/dev/null | grep -q "Up (healthy)"; then
            echo -e "${GREEN}✓${NC} $service - healthy"
            ((healthy++))
        elif docker compose ps "$service" 2>/dev/null | grep -q "Up"; then
            echo -e "${YELLOW}⚠${NC} $service - running (no health check)"
            ((healthy++))
        else
            echo -e "${RED}✗${NC} $service - unhealthy or not running"
            ((unhealthy++))
        fi
    done

    echo
    if [[ $unhealthy -eq 0 ]]; then
        success "All services are healthy ($healthy/$((healthy + unhealthy)))"
    else
        warning "Some services are unhealthy ($unhealthy/$((healthy + unhealthy)) failed)"
    fi
}

#######################################
# Completely reset and delete Colima VM - DESTRUCTIVE OPERATION.
# Globals:
#   COLIMA_PROFILE      - Colima profile name (read)
# Arguments:
#   None
# Returns:
#   0       - Reset completed or cancelled by user
# Outputs:
#   Warning messages and confirmation prompt
#   Progress messages during reset
# Notes:
#   *** DATA LOSS WARNING ***
#   This command DESTROYS ALL DATA including:
#     - All Docker containers and images
#     - All Docker volumes (databases, Git repos, uploaded files)
#     - Colima VM disk and configuration
#     - Network settings and cached data
#
#   Data that is NOT destroyed:
#     - Vault keys/tokens in ~/.config/vault/ (on host)
#     - Backups in ./backups/ directory (on host)
#     - .env configuration file (on host)
#
#   Use cases:
#     - Starting fresh after major issues
#     - Changing VM resource allocation (CPU/memory/disk)
#     - Clearing all test data and resetting to clean state
#
#   ALWAYS run './manage-devstack.sh backup' before reset!
#
#   Requires explicit "yes" confirmation (case-insensitive).
#   After reset, run './manage-devstack.sh start' to recreate VM.
#######################################
cmd_reset() {
    header "Reset Colima VM"

    warning "This will DELETE ALL DATA in Colima VM!"
    warning "This includes:"
    echo "  - Docker containers and images"
    echo "  - All volumes (databases, Git repositories, etc.)"
    echo "  - Colima VM configuration"
    echo
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo

    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        info "Reset cancelled"
        exit 0
    fi

    info "Stopping services..."
    docker compose down -v 2>/dev/null || true

    info "Deleting Colima VM..."
    colima delete --profile "$COLIMA_PROFILE" --force

    success "Colima VM has been reset"
    info "Run './manage-devstack.sh start' to create a fresh VM"
}

#######################################
# Backup all service data to timestamped directory.
# Creates full dumps of all databases and Forgejo data.
# Globals:
#   MYSQL_ROOT_PASSWORD - MySQL password (read from env/Vault)
# Arguments:
#   None
# Returns:
#   0       - Backup completed (may have warnings)
#   1       - Colima not running (via error())
# Outputs:
#   Progress messages for each backup operation
#   Final backup location and total size
# Notes:
#   Backup includes:
#     - PostgreSQL: Complete dump of all databases (pg_dumpall)
#     - MySQL: Complete dump of all databases (mysqldump --all-databases)
#     - MongoDB: Binary archive dump (mongodump --archive)
#     - Forgejo: Tarball of /data directory (repos, uploads, config)
#     - .env file: Configuration backup
#
#   Backup location: ./backups/YYYYMMDD_HHMMSS/
#
#   Database dumps are performed with -T flag (non-interactive) from
#   running containers. Services remain online during backup.
#
#   Warnings (not errors) are shown if individual backups fail - useful
#   for partial backups when a service is down.
#
#   Restore is manual - use psql, mysql, mongorestore, and tar to restore.
#
#   Vault data is NOT backed up by this command - Vault keys are already
#   stored in ~/.config/vault/ on the host filesystem.
#######################################
cmd_backup() {
    header "Backup DevStack Core"

    if ! is_colima_running; then
        error "Colima is not running. Start it first with: ./manage-devstack.sh start"
    fi

    # Load credentials from Vault
    load_vault_credentials

    local backup_dir
    backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    info "Creating backup in: $backup_dir"

    # Backup PostgreSQL
    info "Backing up PostgreSQL databases..."
    docker compose exec -T postgres pg_dumpall -U dev_admin > "$backup_dir/postgres_all.sql"

    # Backup MySQL
    info "Backing up MySQL databases..."
    docker compose exec -T mysql mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" --all-databases > "$backup_dir/mysql_all.sql" 2>/dev/null || warning "MySQL backup failed (check password)"

    # Backup MongoDB
    info "Backing up MongoDB..."
    docker compose exec -T mongodb mongodump --archive > "$backup_dir/mongodb_dump.archive" 2>/dev/null || warning "MongoDB backup failed"

    # Backup Forgejo data
    info "Backing up Forgejo data..."
    docker compose exec -T forgejo tar czf - /data > "$backup_dir/forgejo_data.tar.gz" 2>/dev/null || warning "Forgejo backup failed"

    # Save .env file
    cp .env "$backup_dir/.env.backup"

    success "Backup completed: $backup_dir"

    # Show backup size
    du -sh "$backup_dir" | awk '{print "Backup size: " $1}'
}

#######################################
# Initialize and unseal Vault (manual/legacy command).
# Delegates to the vault-init.sh script.
# Globals:
#   SCRIPT_DIR          - Script directory path (read)
# Arguments:
#   None
# Returns:
#   0       - Initialization succeeded
#   1       - Colima not running or script missing (via error())
# Outputs:
#   Delegated to vault-init.sh script
# Notes:
#   This is a LEGACY/MANUAL command. Normal startup uses auto-unseal.
#
#   The vault-auto-unseal.sh entrypoint script in the Vault container
#   handles initialization and unsealing automatically when Vault starts.
#
#   Use this command ONLY if:
#     - Auto-unseal failed and manual intervention is needed
#     - Debugging Vault initialization issues
#     - Re-initializing after vault-delete (NOT recommended)
#
#   Output: Creates/updates files in ~/.config/vault/:
#     - keys.json: Unseal keys (5 keys, threshold of 3)
#     - root-token: Root authentication token
#
#   After initialization, Vault is unsealed and ready for bootstrap.
#######################################
cmd_vault_init() {
    header "Initialize and Unseal Vault"

    if ! is_colima_running; then
        error "Colima is not running. Start it first with: ./manage-devstack.sh start"
    fi

    if [ ! -f "$SCRIPT_DIR/configs/vault/scripts/vault-init.sh" ]; then
        error "Vault initialization script not found"
    fi

    bash "$SCRIPT_DIR/configs/vault/scripts/vault-init.sh"
}

#######################################
# Manually unseal Vault using stored unseal keys.
# Globals:
#   VAULT_ADDR          - Vault API endpoint (set)
# Arguments:
#   None
# Returns:
#   0       - Vault unsealed successfully
#   1       - Colima not running or keys file missing (via error())
# Outputs:
#   Progress messages during unseal process
# Notes:
#   This is a MANUAL command. Vault auto-unseals on normal startup.
#
#   Use this command ONLY if:
#     - Vault is sealed after a crash or restart
#     - Auto-unseal mechanism failed
#     - Manual intervention is required
#
#   Unsealing process:
#     - Reads unseal keys from ~/.config/vault/keys.json
#     - Extracts 3 keys (threshold is 3 out of 5)
#     - Submits keys to Vault via 'vault operator unseal'
#     - Vault becomes unsealed and operational
#
#   Check seal status first: ./manage-devstack.sh vault-status
#
#   Keys file format: JSON with "unseal_keys_b64" array from vault init.
#######################################
cmd_vault_unseal() {
    header "Unseal Vault"

    if ! is_colima_running; then
        error "Colima is not running. Start it first with: ./manage-devstack.sh start"
    fi

    export VAULT_ADDR="http://localhost:8200"
    local vault_keys_file="${HOME}/.config/vault/keys.json"

    if [ ! -f "$vault_keys_file" ]; then
        error "Vault keys file not found: $vault_keys_file. Run './manage-devstack.sh vault-init' first"
    fi

    info "Unsealing Vault..."

    # Extract unseal keys (we need 3 out of 5)
    local keys=()
    mapfile -t keys < <(grep -o '"[^"]*"' "$vault_keys_file" | grep '^"[A-Za-z0-9+/=]\{44\}"$' | tr -d '"' | head -3)

    if [ ${#keys[@]} -lt 3 ]; then
        error "Could not extract enough unseal keys from $vault_keys_file"
    fi

    # Unseal with first 3 keys
    for key in "${keys[@]:0:3}"; do
        docker exec dev-vault vault operator unseal "$key" > /dev/null
    done

    success "Vault unsealed successfully"
}

#######################################
# Display Vault seal status and root token information.
# Globals:
#   VAULT_ADDR          - Vault API endpoint (set)
# Arguments:
#   None
# Returns:
#   0       - Always succeeds (status may show errors)
#   1       - Colima not running (via error())
# Outputs:
#   Vault status table and root token information
# Notes:
#   Shows critical Vault state:
#     - Sealed: true/false (whether Vault is locked)
#     - Initialized: true/false (whether Vault has been set up)
#     - HA Enabled: false (single-node dev mode)
#     - Version: Vault server version
#
#   If Vault is sealed:
#     - Run './manage-devstack.sh vault-unseal' to unseal
#     - Or restart services to trigger auto-unseal
#
#   Root token is printed if available at ~/.config/vault/root-token.
#   This token has unlimited privileges - use carefully.
#
#   To use token in other commands:
#     export VAULT_TOKEN=$(cat ~/.config/vault/root-token)
#######################################
cmd_vault_status() {
    header "Vault Status"

    if ! is_colima_running; then
        error "Colima is not running"
    fi

    export VAULT_ADDR="http://localhost:8200"

    info "Vault Status:"
    docker exec dev-vault vault status || true

    echo
    if [ -f "${HOME}/.config/vault/root-token" ]; then
        info "Root Token: $(cat "${HOME}/.config/vault/root-token")"
        info "Set token: export VAULT_TOKEN=\$(cat \${HOME}/.config/vault/root-token)"
    fi
}

#######################################
# Print Vault root token to stdout.
# Globals:
#   None modified
# Arguments:
#   None
# Returns:
#   0       - Token printed successfully
#   1       - Token file not found (via error())
# Outputs:
#   Vault root token (raw, no formatting)
# Notes:
#   Designed for use in shell scripts and automation:
#     export VAULT_TOKEN=$(./manage-devstack.sh vault-token)
#     vault kv get secret/postgres
#
#   Token file location: ~/.config/vault/root-token
#
#   The root token:
#     - Never expires
#     - Has unlimited privileges
#     - Should be protected like a password
#     - Is required for bootstrap and admin operations
#
#   For interactive use, prefer 'vault-status' which shows more context.
#######################################
cmd_vault_token() {
    if [ -f "${HOME}/.config/vault/root-token" ]; then
        cat "${HOME}/.config/vault/root-token"
    else
        error "Root token file not found. Run './manage-devstack.sh vault-init' first"
    fi
}

#######################################
# Bootstrap Vault with PKI and service credentials.
# Sets up:
#   1. PKI root and intermediate CA for TLS certificates
#   2. Service credentials in KV secrets engine
#   3. Database roles and policies
# Globals:
#   SCRIPT_DIR          - Script directory path (read)
#   VAULT_ADDR          - Vault API endpoint (set)
#   VAULT_TOKEN         - Root token for authentication (set)
# Arguments:
#   None
# Returns:
#   0       - Bootstrap completed successfully
#   1       - Colima not running, script missing, or auth failed (via error())
# Outputs:
#   Delegated to vault-bootstrap.sh script
# Notes:
#   This is a ONE-TIME setup command run after first start.
#
#   Bootstrap sequence:
#     1. Enable PKI secrets engine at pki/ path
#     2. Generate root CA certificate (10-year validity)
#     3. Generate intermediate CA (5-year validity)
#     4. Configure certificate roles for services
#     5. Enable KV v2 secrets engine at secret/ path
#     6. Store all service passwords in Vault
#     7. Export CA certificate chain to ~/.config/vault/ca/
#
#   After bootstrap:
#     - Services can request TLS certificates from Vault PKI
#     - Credentials are centralized in Vault (single source of truth)
#     - CA certificate can be distributed to clients for trust
#
#   CA certificate location: ~/.config/vault/ca/ca-chain.pem
#   Use 'vault-ca-cert' command to export/view certificate.
#
#   Safe to run multiple times - idempotent operations.
#######################################
cmd_vault_bootstrap() {
    header "Bootstrap Vault PKI and Secrets"

    if ! is_colima_running; then
        error "Colima is not running. Start it first with: ./manage-devstack.sh start"
    fi

    if [ ! -f "$SCRIPT_DIR/configs/vault/scripts/vault-bootstrap.sh" ]; then
        error "Vault bootstrap script not found at: $SCRIPT_DIR/configs/vault/scripts/vault-bootstrap.sh"
    fi

    # Set Vault environment variables
    export VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
    export VAULT_TOKEN="${VAULT_TOKEN:-$(cat "${HOME}/.config/vault/root-token" 2>/dev/null)}"

    if [ -z "$VAULT_TOKEN" ]; then
        error "VAULT_TOKEN not set and root token file not found. Run './manage-devstack.sh vault-init' first"
    fi

    info "Running Vault PKI and secrets bootstrap..."
    echo

    bash "$SCRIPT_DIR/configs/vault/scripts/vault-bootstrap.sh"

    # Create Forgejo database in PostgreSQL
    info ""
    info "Creating Forgejo database in PostgreSQL..."
    if docker compose exec -T postgres psql -U devuser -d postgres < "$SCRIPT_DIR/configs/postgres/02-create-forgejo-db.sql" > /dev/null 2>&1; then
        success "Forgejo database created successfully"
    else
        warn "Forgejo database may already exist or PostgreSQL is not ready"
    fi
}

#######################################
# Export Vault CA certificate chain to stdout.
# Globals:
#   None modified
# Arguments:
#   None
# Returns:
#   0       - Certificate exported successfully
#   1       - CA certificate file not found (via error())
# Outputs:
#   PEM-encoded CA certificate chain to stdout
#   Information message about file location to stderr
# Notes:
#   The CA certificate is required for clients to trust TLS connections
#   to services using Vault-issued certificates.
#
#   CA certificate chain includes:
#     - Intermediate CA certificate
#     - Root CA certificate
#
#   Usage examples:
#     # Save to file
#     ./manage-devstack.sh vault-ca-cert > vault-ca.pem
#
#     # Install on macOS
#     ./manage-devstack.sh vault-ca-cert | sudo security add-trusted-cert \
#       -d -r trustRoot -k /Library/Keychains/System.keychain /dev/stdin
#
#     # Install on Linux
#     ./manage-devstack.sh vault-ca-cert | sudo tee \
#       /usr/local/share/ca-certificates/vault-ca.crt
#     sudo update-ca-certificates
#
#   Certificate location: ~/.config/vault/ca/ca-chain.pem
#   Generated by: vault-bootstrap command
#######################################
cmd_vault_ca_cert() {
    header "Export Vault CA Certificate"

    local ca_file="${HOME}/.config/vault/ca/ca-chain.pem"

    if [ ! -f "$ca_file" ]; then
        error "CA certificate not found at: $ca_file"
        echo
        info "Run './manage-devstack.sh vault-bootstrap' first to generate CA certificates"
        exit 1
    fi

    cat "$ca_file"
    echo
    info "CA certificate location: $ca_file"
}

#######################################
# Retrieve and display service credentials from Vault.
# Globals:
#   VAULT_ADDR          - Vault API endpoint (set)
#   VAULT_TOKEN         - Root token for authentication (set)
# Arguments:
#   $1      - (Required) Service name (postgres, mysql, redis-1, rabbitmq, mongodb, forgejo)
# Returns:
#   0       - Credentials retrieved and displayed
#   1       - Service name missing, auth failed, or credentials not found (via error())
# Outputs:
#   Service credentials to stdout (password for most services, username/email/password for Forgejo)
# Notes:
#   Retrieves credentials from Vault KV v2 secrets at path: secret/<service>
#
#   Available services (after bootstrap):
#     - postgres: PostgreSQL admin password
#     - mysql: MySQL root password
#     - redis-1: Redis AUTH password
#     - rabbitmq: RabbitMQ admin password
#     - mongodb: MongoDB root password
#     - forgejo: Admin username, email, and password
#
#   Uses docker exec to run vault commands inside the Vault container.
#
#   Authentication: Automatically retrieves VAULT_TOKEN from container's
#   /vault-keys/root-token file.
#
#   Security: Credentials are shown in plain text on terminal. Use with
#   caution in shared environments.
#
#   Automation example:
#     PGPASSWORD=$(./manage-devstack.sh vault-show-password postgres)
#     psql -h localhost -U dev_admin -d postgres
#######################################
cmd_vault_show_password() {
    local service=$1

    # Validate service parameter is provided
    if [ -z "$service" ]; then
        error "Usage: ./manage-devstack.sh vault-show-password <service>"
        echo
        info "Available services: postgres, mysql, redis-1, rabbitmq, mongodb, forgejo"
        exit 1
    fi

    # Validate service name against allowed list
    local valid_services="postgres mysql redis-1 redis-2 redis-3 rabbitmq mongodb forgejo"
    if ! echo "$valid_services" | grep -qw "$service"; then
        error "Invalid service: $service"
        echo
        info "Available services: $valid_services"
        exit 1
    fi

    # Sanitize service name (prevent path traversal)
    service=$(echo "$service" | tr -cd 'a-z0-9-')

    export VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
    export VAULT_TOKEN="${VAULT_TOKEN:-$(cat "${HOME}/.config/vault/root-token" 2>/dev/null)}"

    if [ -z "$VAULT_TOKEN" ]; then
        error "VAULT_TOKEN not set. Run './manage-devstack.sh vault-init' first"
    fi

    warn "Password will be displayed in plaintext - ensure terminal is secure"
    echo

    if [ "$service" = "forgejo" ]; then
        info "Fetching credentials for service: $service"
    else
        info "Fetching password for service: $service"
    fi

    # For Forgejo, show username, email, and password
    if [ "$service" = "forgejo" ]; then
        # Use docker exec to run vault commands in the container
        admin_user=$(docker exec dev-vault sh -c "export VAULT_TOKEN=\$(cat /vault-keys/root-token) && vault kv get -field=admin_user secret/$service" 2>/dev/null)
        admin_email=$(docker exec dev-vault sh -c "export VAULT_TOKEN=\$(cat /vault-keys/root-token) && vault kv get -field=admin_email secret/$service" 2>/dev/null)
        password=$(docker exec dev-vault sh -c "export VAULT_TOKEN=\$(cat /vault-keys/root-token) && vault kv get -field=admin_password secret/$service" 2>/dev/null)

        if [ -z "$admin_user" ] || [ "$admin_user" = "null" ] || [ -z "$password" ] || [ "$password" = "null" ]; then
            error "Could not retrieve credentials for Forgejo"
            echo
            info "Make sure Forgejo credentials exist in Vault: vault kv get secret/forgejo"
            exit 1
        fi

        echo
        success "Forgejo Admin Credentials:"
        echo "  Username: $admin_user"
        echo "  Email:    $admin_email"
        echo "  Password: $password"
    else
        # For other services, just show password
        # Use docker exec to run vault commands in the container
        password=$(docker exec dev-vault sh -c "export VAULT_TOKEN=\$(cat /vault-keys/root-token) && vault kv get -field=password secret/$service" 2>/dev/null)

        if [ -z "$password" ] || [ "$password" = "null" ]; then
            error "Could not retrieve password for service: $service"
            echo
            info "Make sure the service exists in Vault: vault kv list secret/"
            exit 1
        fi

        echo
        success "Password for $service:"
        echo "$password"
    fi
}

#######################################
# Initialize Forgejo via automated bootstrap script.
# Globals:
#   None modified
# Arguments:
#   None
# Returns:
#   0       - Forgejo initialized successfully
#   1       - Container not running or bootstrap failed (via error())
# Outputs:
#   Progress messages and installation status
# Notes:
#   This command runs automated Forgejo installation including:
#     - Database migration and table creation
#     - Configuration with INSTALL_LOCK and SECRET_KEY
#     - Default admin user creation
#
#   Default credentials (CHANGE AFTER FIRST LOGIN):
#     Username: devadmin
#     Password: DevStack2024!
#
#   Run this AFTER:
#     ./manage-devstack.sh start
#     ./manage-devstack.sh vault-bootstrap
#
#   Forgejo will be accessible at: http://localhost:3000
#######################################
cmd_forgejo_init() {
    header "Initialize Forgejo"

    if ! is_colima_running; then
        error "Colima is not running. Start it first with: ./manage-devstack.sh start"
    fi

    # Check if Forgejo container is running
    if ! docker compose ps forgejo | grep -q "Up"; then
        error "Forgejo container is not running. Start it with: docker compose up -d forgejo"
    fi

    info "Running Forgejo automated installation..."
    echo

    # Run bootstrap script inside container
    docker compose exec forgejo /usr/local/bin/forgejo-bootstrap.sh || {
        error "Forgejo bootstrap failed"
    }

    echo
    success "Forgejo is now ready to use!"
    info "Access at: http://localhost:3000"
}

#######################################
# Display comprehensive help message.
# Globals:
#   None modified
# Arguments:
#   None
# Returns:
#   0       - Always succeeds
# Outputs:
#   Multi-page help text to stdout
# Notes:
#   Help includes:
#     - Command descriptions
#     - Usage examples
#     - Service list with access URLs
#     - Environment variable configuration
#     - Configuration file locations
#
#   This is the default command if no arguments provided.
#######################################
cmd_help() {
    cat << 'EOF'
DevStack Core Management Script
==================================

USAGE:
    ./manage-devstack.sh [command] [options]

COMMANDS:
    start                       Start Colima VM and all services
    stop                        Stop all services and Colima VM
    restart                     Restart Docker services (Colima stays running)
    status                      Show status of Colima VM and all services
    logs [service]              View logs (all services or specific service)
    shell [service]             Open interactive shell in service container
    ip                          Show Colima IP address
    health                      Check health status of all services
    reset                       Delete and reset Colima VM (WARNING: destroys all data)
    backup                      Backup all service data (databases, volumes)
    vault-init                  Initialize and unseal Vault (first time setup)
    vault-unseal                Unseal Vault (if sealed after restart)
    vault-status                Show Vault status and root token
    vault-token                 Print Vault root token
    vault-bootstrap             Bootstrap Vault PKI and store service credentials
    vault-ca-cert               Export CA certificate chain for client trust
    vault-show-password <svc>   Show password for a service from Vault
    forgejo-init                Initialize Forgejo (automated installation)
    help                        Show this help message

EXAMPLES:
    # Start everything
    ./manage-devstack.sh start

    # Check status
    ./manage-devstack.sh status

    # View logs for a specific service
    ./manage-devstack.sh logs postgres
    ./manage-devstack.sh logs forgejo

    # Open shell in a container
    ./manage-devstack.sh shell postgres
    ./manage-devstack.sh shell forgejo

    # Get Colima IP
    ./manage-devstack.sh ip

    # Backup everything
    ./manage-devstack.sh backup

SERVICES:
    - postgres      PostgreSQL database (Git storage)
    - pgbouncer     PostgreSQL connection pooler
    - mysql         MySQL database (local development)
    - redis         Redis cache
    - rabbitmq      RabbitMQ message queue
    - mongodb       MongoDB NoSQL database
    - forgejo       Git server
    - vault         HashiCorp Vault (secrets management)

ACCESS URLS:
    - Forgejo:      http://localhost:3000
    - Vault UI:     http://localhost:8200/ui
    - RabbitMQ UI:  http://localhost:15672
    - PostgreSQL:   localhost:5432
    - PgBouncer:    localhost:6432
    - MySQL:        localhost:3306
    - Redis:        localhost:6379
    - MongoDB:      localhost:27017

CONFIGURATION:
    Edit .env file to configure passwords and settings

ENVIRONMENT VARIABLES:
    COLIMA_PROFILE  - Colima profile name (default: default)
    COLIMA_CPU      - CPU cores (default: 4)
    COLIMA_MEMORY   - Memory in GB (default: 8)
    COLIMA_DISK     - Disk size in GB (default: 60)

EOF
}

# ===========================================================================
# Main Entry Point
# ===========================================================================

#######################################
# Main command dispatcher and entry point.
# Parses command-line arguments and dispatches to appropriate cmd_* function.
# Globals:
#   None modified directly (modified by called functions)
# Arguments:
#   $1      - Command name (start, stop, restart, etc.)
#   $@      - Additional arguments passed to command functions
# Returns:
#   Varies - delegates to command function
# Outputs:
#   Varies - delegates to command function
# Notes:
#   Command routing:
#     - Service Management: start, stop, restart, status
#     - Monitoring: logs, health, ip
#     - Utilities: shell, backup, reset
#     - Vault Operations: vault-init, vault-unseal, vault-status,
#       vault-token, vault-bootstrap, vault-ca-cert, vault-show-password
#     - Help: help, --help, -h
#
#   Default command: If no command provided, shows help message.
#
#   Unknown commands: Exit with error and suggest help command.
#
#   All commands receive remaining arguments via "$@" for extensibility.
#
#   Script execution flow:
#     1. Bash options set (set -euo pipefail) - fail fast on errors
#     2. Global variables initialized (colors, paths, Colima config)
#     3. DOCKER_HOST exported for Colima socket communication
#     4. main() called with all script arguments
#     5. Command dispatched to appropriate cmd_* function
#     6. Function executes and returns exit code
#     7. Script exits with function's exit code
#
#   Error handling: Most errors call error() which exits immediately
#   with code 1. Some commands use explicit exit for user cancellation.
#######################################
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        start)
            cmd_start "$@"
            ;;
        stop)
            cmd_stop "$@"
            ;;
        restart)
            cmd_restart "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        logs)
            cmd_logs "$@"
            ;;
        shell)
            cmd_shell "$@"
            ;;
        ip)
            cmd_ip "$@"
            ;;
        health)
            cmd_health "$@"
            ;;
        reset)
            cmd_reset "$@"
            ;;
        backup)
            cmd_backup "$@"
            ;;
        vault-init)
            cmd_vault_init "$@"
            ;;
        vault-unseal)
            cmd_vault_unseal "$@"
            ;;
        vault-status)
            cmd_vault_status "$@"
            ;;
        vault-token)
            cmd_vault_token "$@"
            ;;
        vault-bootstrap)
            cmd_vault_bootstrap "$@"
            ;;
        vault-ca-cert)
            cmd_vault_ca_cert "$@"
            ;;
        vault-show-password)
            cmd_vault_show_password "$@"
            ;;
        forgejo-init)
            cmd_forgejo_init "$@"
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            error "Unknown command: $command\n       Run './manage-devstack.sh help' for usage"
            ;;
    esac
}

# ===========================================================================
# Script Execution
# ===========================================================================
# Run main function with all script arguments
main "$@"
