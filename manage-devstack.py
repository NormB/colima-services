#!/usr/bin/env python3
"""
DevStack Core Management Script
================================

Modern Python-based management interface for DevStack Core with service profile support.

This script provides a comprehensive CLI for managing the complete Colima-based
development infrastructure with flexible service profiles.

Features:
- Service profile management (minimal, standard, full, reference)
- Automatic environment loading from profile .env files
- Beautiful terminal output with colors and tables
- Health checks for all services
- Vault operations (init, unseal, bootstrap)
- Service logs and shell access
- Backup and restore operations

Usage:
    ./manage-devstack.py --help
    ./manage-devstack.py start --profile standard
    ./manage-devstack.py status
    ./manage-devstack.py health

Requirements:
    pip3 install click rich PyYAML python-dotenv

Author: DevStack Core Team
License: MIT
"""

import os
import sys
import subprocess
import time
from pathlib import Path
from typing import List, Dict, Optional, Tuple

try:
    import click
    import yaml
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    from rich.progress import Progress, SpinnerColumn, TextColumn
    from rich import box
    from dotenv import dotenv_values
except ImportError as e:
    print(f"Error: Missing required dependency: {e}")
    print("\nInstall dependencies with:")
    print("  pip3 install click rich PyYAML python-dotenv")
    sys.exit(1)

# ==============================================================================
# Constants and Configuration
# ==============================================================================

# Paths
SCRIPT_DIR = Path(__file__).parent.resolve()
PROFILES_FILE = SCRIPT_DIR / "profiles.yaml"
COMPOSE_FILE = SCRIPT_DIR / "docker-compose.yml"
ENV_FILE = SCRIPT_DIR / ".env"
PROFILES_DIR = SCRIPT_DIR / "configs" / "profiles"
VAULT_CONFIG_DIR = Path.home() / ".config" / "vault"

# Colima defaults (can be overridden by environment variables)
COLIMA_PROFILE = os.getenv("COLIMA_PROFILE", "default")
COLIMA_CPU = os.getenv("COLIMA_CPU", "4")
COLIMA_MEMORY = os.getenv("COLIMA_MEMORY", "8")
COLIMA_DISK = os.getenv("COLIMA_DISK", "60")

# Rich console for beautiful output
console = Console()

# ==============================================================================
# Utility Functions
# ==============================================================================

def run_command(
    cmd: List[str],
    check: bool = True,
    capture: bool = False,
    env: Optional[Dict[str, str]] = None
) -> Tuple[int, str, str]:
    """
    Run a shell command with optional environment variables.

    Args:
        cmd: Command and arguments as list
        check: Raise error if command fails
        capture: Capture stdout/stderr
        env: Additional environment variables

    Returns:
        Tuple of (returncode, stdout, stderr)
    """
    # Merge environment variables
    cmd_env = os.environ.copy()
    if env:
        cmd_env.update(env)

    try:
        if capture:
            result = subprocess.run(
                cmd,
                check=check,
                capture_output=True,
                text=True,
                env=cmd_env
            )
            return result.returncode, result.stdout, result.stderr
        else:
            result = subprocess.run(cmd, check=check, env=cmd_env)
            return result.returncode, "", ""
    except subprocess.CalledProcessError as e:
        if check:
            console.print(f"[red]Error running command: {' '.join(cmd)}[/red]")
            console.print(f"[red]Exit code: {e.returncode}[/red]")
            if capture and e.stderr:
                console.print(f"[red]{e.stderr}[/red]")
            sys.exit(e.returncode)
        return e.returncode, e.stdout if capture else "", e.stderr if capture else ""
    except FileNotFoundError:
        console.print(f"[red]Command not found: {cmd[0]}[/red]")
        console.print(f"[yellow]Make sure {cmd[0]} is installed and in your PATH[/yellow]")
        sys.exit(1)


def load_profiles_config() -> Dict:
    """Load and parse profiles.yaml configuration."""
    if not PROFILES_FILE.exists():
        console.print(f"[red]Error: {PROFILES_FILE} not found[/red]")
        sys.exit(1)

    with open(PROFILES_FILE) as f:
        return yaml.safe_load(f)


def load_profile_env(profile: str) -> Dict[str, str]:
    """Load environment variables from a profile .env file."""
    profile_env_file = PROFILES_DIR / f"{profile}.env"

    if not profile_env_file.exists():
        return {}

    # Use python-dotenv to parse .env file
    return dotenv_values(profile_env_file)


def get_profile_services(profile: str) -> List[str]:
    """Get list of services for a given profile."""
    profiles_config = load_profiles_config()

    # Check in main profiles
    if profile in profiles_config.get("profiles", {}):
        return profiles_config["profiles"][profile].get("services", [])

    # Check in custom profiles
    if profile in profiles_config.get("custom_profiles", {}):
        return profiles_config["custom_profiles"][profile].get("services", [])

    console.print(f"[red]Error: Unknown profile '{profile}'[/red]")
    console.print("[yellow]Available profiles: minimal, standard, full, reference[/yellow]")
    sys.exit(1)


def check_colima_status() -> bool:
    """Check if Colima is running."""
    returncode, stdout, _ = run_command(
        ["colima", "status", "-p", COLIMA_PROFILE],
        check=False,
        capture=True
    )
    return returncode == 0 and "running" in stdout.lower()


def check_vault_token() -> bool:
    """Check if Vault root token exists."""
    token_file = VAULT_CONFIG_DIR / "root-token"
    return token_file.exists()


def get_vault_token() -> Optional[str]:
    """Get Vault root token."""
    token_file = VAULT_CONFIG_DIR / "root-token"
    if not token_file.exists():
        return None
    return token_file.read_text().strip()


# ==============================================================================
# CLI Commands
# ==============================================================================

@click.group()
@click.version_option(version="1.0.0", prog_name="manage-devstack")
def cli():
    """
    DevStack Core Management Script

    Modern Python-based management interface with service profile support.

    \b
    Profiles:
      minimal  - Essential services (5 services, 2GB RAM)
      standard - Full development stack (10 services, 4GB RAM)
      full     - Complete suite with observability (18 services, 6GB RAM)
      reference - API examples (5 services, +1GB RAM, combinable)

    \b
    Examples:
      ./manage-devstack.py start --profile minimal
      ./manage-devstack.py start --profile standard --profile reference
      ./manage-devstack.py status
      ./manage-devstack.py health
      ./manage-devstack.py logs postgres
    """
    pass


@cli.command()
@click.option(
    "--profile",
    "-p",
    multiple=True,
    default=["standard"],
    help="Service profile(s) to start (can specify multiple)",
    show_default=True
)
@click.option(
    "--detach/--no-detach",
    "-d",
    default=True,
    help="Run services in background (detached mode)",
    show_default=True
)
def start(profile: Tuple[str], detach: bool):
    """
    Start Colima VM and Docker services with specified profile(s).

    \b
    Profiles can be combined:
      --profile standard --profile reference  (15 services)
      --profile full --profile reference      (23 services)

    \b
    The minimal profile is lightweight for basic development:
      --profile minimal                       (5 services, 2GB RAM)
    """
    console.print("\n[cyan]═══ DevStack Core - Start Services ═══[/cyan]\n")

    # Validate profiles
    profiles_config = load_profiles_config()
    for p in profile:
        if p not in profiles_config.get("profiles", {}) and \
           p not in profiles_config.get("custom_profiles", {}):
            console.print(f"[red]Error: Unknown profile '{p}'[/red]")
            console.print("\n[yellow]Available profiles:[/yellow]")
            for prof_name in profiles_config.get("profiles", {}).keys():
                console.print(f"  • {prof_name}")
            sys.exit(1)

    # Display what will start
    console.print(f"[green]Starting with profile(s):[/green] {', '.join(profile)}\n")

    # Load profile environment variables
    merged_env = {}
    for p in profile:
        profile_env = load_profile_env(p)
        merged_env.update(profile_env)
        if profile_env:
            console.print(f"[dim]Loaded {len(profile_env)} environment overrides from {p}.env[/dim]")

    # Step 1: Check/Start Colima
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console
    ) as progress:
        task = progress.add_task("Checking Colima VM status...", total=None)

        if not check_colima_status():
            progress.update(task, description="Starting Colima VM...")
            run_command([
                "colima", "start",
                "-p", COLIMA_PROFILE,
                "--cpu", COLIMA_CPU,
                "--memory", COLIMA_MEMORY,
                "--disk", COLIMA_DISK,
                "--network-address"
            ], env=merged_env)
            console.print("[green]✓ Colima VM started[/green]")
        else:
            progress.update(task, description="Colima VM already running")
            console.print("[green]✓ Colima VM already running[/green]")

    # Step 2: Start Docker services with profile(s)
    console.print(f"\n[cyan]Starting Docker services...[/cyan]")

    cmd = ["docker", "compose"]
    for p in profile:
        cmd.extend(["--profile", p])
    cmd.extend(["up", "-d" if detach else ""])

    # Remove empty strings
    cmd = [c for c in cmd if c]

    console.print(f"[dim]Command: {' '.join(cmd)}[/dim]\n")
    run_command(cmd, env=merged_env)

    # Step 3: Display running services
    console.print("\n[green]✓ Services started successfully[/green]\n")

    # Show service status
    _, stdout, _ = run_command(
        ["docker", "compose", "ps", "--format", "table"],
        capture=True
    )
    console.print(stdout)

    # Show next steps
    console.print("\n[cyan]Next Steps:[/cyan]")
    if "standard" in profile or "full" in profile:
        console.print("  1. Initialize Redis cluster (if first time):")
        console.print("     [yellow]./manage-devstack.py redis-cluster-init[/yellow]")
        console.print("  2. Check service health:")
        console.print("     [yellow]./manage-devstack.py health[/yellow]")
    else:
        console.print("  • Check service health:")
        console.print("    [yellow]./manage-devstack.py health[/yellow]")

    console.print()


@cli.command()
@click.option(
    "--profile",
    "-p",
    multiple=True,
    help="Only stop services from specific profile(s)"
)
def stop(profile: Optional[Tuple[str]]):
    """
    Stop Docker services and Colima VM.

    If --profile is specified, only stops those services.
    Otherwise, stops everything including Colima VM.
    """
    console.print("\n[cyan]═══ DevStack Core - Stop Services ═══[/cyan]\n")

    if profile:
        # Stop specific profile services
        console.print(f"[yellow]Stopping profile(s):[/yellow] {', '.join(profile)}\n")

        cmd = ["docker", "compose"]
        for p in profile:
            cmd.extend(["--profile", p])
        cmd.append("down")

        run_command(cmd)
        console.print(f"\n[green]✓ Stopped services from profile(s): {', '.join(profile)}[/green]")
    else:
        # Stop everything
        console.print("[yellow]Stopping all services and Colima VM...[/yellow]\n")

        # Stop Docker services
        run_command(["docker", "compose", "down"])
        console.print("[green]✓ Docker services stopped[/green]")

        # Stop Colima
        if check_colima_status():
            run_command(["colima", "stop", "-p", COLIMA_PROFILE])
            console.print("[green]✓ Colima VM stopped[/green]")
        else:
            console.print("[dim]Colima VM was not running[/dim]")

    console.print()


@cli.command()
def status():
    """
    Display status of Colima VM and all running services.

    Shows resource usage (CPU, memory) for each service.
    """
    console.print("\n[cyan]═══ DevStack Core - Service Status ═══[/cyan]\n")

    # Colima status
    if check_colima_status():
        console.print("[green]✓ Colima VM:[/green] Running\n")

        # Get Colima info
        _, stdout, _ = run_command(
            ["colima", "list", "-p", COLIMA_PROFILE],
            capture=True,
            check=False
        )
        if stdout:
            console.print(stdout)
    else:
        console.print("[red]✗ Colima VM:[/red] Not running\n")
        console.print("[yellow]Start with:[/yellow] ./manage-devstack.py start\n")
        return

    # Docker services status
    console.print("[cyan]Docker Services:[/cyan]\n")

    _, stdout, _ = run_command(
        ["docker", "compose", "ps", "--format", "table"],
        capture=True,
        check=False
    )

    if stdout and "NAME" in stdout:
        console.print(stdout)
    else:
        console.print("[yellow]No services running[/yellow]")
        console.print("[dim]Start services with: ./manage-devstack.py start[/dim]")

    console.print()


@cli.command()
def health():
    """
    Check health status of all running services.

    Performs health checks and displays results in a table.
    """
    console.print("\n[cyan]═══ DevStack Core - Health Check ═══[/cyan]\n")

    if not check_colima_status():
        console.print("[red]Error: Colima VM is not running[/red]")
        console.print("[yellow]Start with:[/yellow] ./manage-devstack.py start\n")
        return

    # Get list of running containers
    _, stdout, _ = run_command(
        ["docker", "compose", "ps", "--format", "json"],
        capture=True,
        check=False
    )

    if not stdout:
        console.print("[yellow]No services running[/yellow]\n")
        return

    # Parse and check health
    table = Table(title="Service Health Status", box=box.ROUNDED)
    table.add_column("Service", style="cyan")
    table.add_column("Status", style="green")
    table.add_column("Health", style="yellow")

    import json
    for line in stdout.strip().split("\n"):
        try:
            container = json.loads(line)
            service = container.get("Service", "unknown")
            state = container.get("State", "unknown")
            health = container.get("Health", "unknown")

            # Color code status
            if state == "running":
                status_display = "[green]running[/green]"
            else:
                status_display = f"[red]{state}[/red]"

            # Color code health
            if health == "healthy":
                health_display = "[green]healthy[/green]"
            elif health == "unknown":
                health_display = "[dim]no healthcheck[/dim]"
            else:
                health_display = f"[yellow]{health}[/yellow]"

            table.add_row(service, status_display, health_display)
        except json.JSONDecodeError:
            continue

    console.print(table)
    console.print()


@cli.command()
@click.argument("service", required=False)
@click.option(
    "--follow",
    "-f",
    is_flag=True,
    help="Follow log output (like tail -f)"
)
@click.option(
    "--tail",
    "-n",
    default=100,
    help="Number of lines to show from end of logs",
    show_default=True
)
def logs(service: Optional[str], follow: bool, tail: int):
    """
    View logs for all services or a specific service.

    \b
    Examples:
      ./manage-devstack.py logs              # All services
      ./manage-devstack.py logs postgres     # Just PostgreSQL
      ./manage-devstack.py logs -f vault     # Follow Vault logs
    """
    cmd = ["docker", "compose", "logs"]

    if follow:
        cmd.append("-f")

    cmd.extend(["--tail", str(tail)])

    if service:
        cmd.append(service)

    try:
        run_command(cmd, check=False)
    except KeyboardInterrupt:
        console.print("\n[dim]Log streaming stopped[/dim]\n")


@cli.command()
@click.argument("service")
@click.option(
    "--shell",
    "-s",
    default="sh",
    help="Shell to use (sh, bash, etc.)",
    show_default=True
)
def shell(service: str, shell: str):
    """
    Open an interactive shell in a running container.

    \b
    Examples:
      ./manage-devstack.py shell postgres
      ./manage-devstack.py shell vault --shell bash
    """
    console.print(f"\n[cyan]Opening shell in {service}...[/cyan]")
    console.print(f"[dim]Type 'exit' to close the shell[/dim]\n")

    run_command(
        ["docker", "compose", "exec", service, shell],
        check=False
    )

    console.print(f"\n[dim]Closed shell in {service}[/dim]\n")


@cli.command()
def profiles():
    """
    List all available service profiles with details.

    Shows services, resource usage, and use cases for each profile.
    """
    console.print("\n[cyan]═══ DevStack Core - Service Profiles ═══[/cyan]\n")

    profiles_config = load_profiles_config()

    # Main profiles table
    table = Table(title="Available Profiles", box=box.ROUNDED)
    table.add_column("Profile", style="cyan", no_wrap=True)
    table.add_column("Services", style="green")
    table.add_column("RAM", style="yellow")
    table.add_column("Description")

    for name, config in profiles_config.get("profiles", {}).items():
        services = str(len(config.get("services", [])))
        ram = config.get("resources", {}).get("ram_estimate", "N/A")
        desc = config.get("description", "")

        table.add_row(name, services, ram, desc)

    console.print(table)

    # Custom profiles
    if "custom_profiles" in profiles_config:
        console.print("\n[cyan]Custom Profiles:[/cyan]")
        for name, config in profiles_config.get("custom_profiles", {}).items():
            desc = config.get("description", "")
            services = len(config.get("services", []))
            console.print(f"  • [green]{name}[/green] ({services} services): {desc}")

    console.print("\n[dim]Use with: ./manage-devstack.py start --profile <name>[/dim]\n")


@cli.command()
def ip():
    """
    Display Colima VM IP address.

    Useful for accessing services from libvirt VMs or other network clients.
    """
    if not check_colima_status():
        console.print("[red]Error: Colima VM is not running[/red]\n")
        return

    _, stdout, _ = run_command(
        ["colima", "ls", "-p", COLIMA_PROFILE, "-j"],
        capture=True
    )

    try:
        import json
        colima_info = json.loads(stdout)
        if colima_info and len(colima_info) > 0:
            ip_address = colima_info[0].get("address", "N/A")
            console.print(f"\n[cyan]Colima VM IP:[/cyan] [green]{ip_address}[/green]\n")
        else:
            console.print("[yellow]Could not determine IP address[/yellow]\n")
    except (json.JSONDecodeError, IndexError):
        console.print("[yellow]Could not parse Colima info[/yellow]\n")


@cli.command()
def redis_cluster_init():
    """
    Initialize Redis cluster (required for standard/full profiles).

    Creates a 3-node Redis cluster with automatic slot distribution.
    Only needed once after first start with standard or full profile.
    """
    console.print("\n[cyan]═══ Redis Cluster Initialization ═══[/cyan]\n")

    # Check if redis-1 is running
    returncode, _, _ = run_command(
        ["docker", "ps", "--filter", "name=dev-redis-1", "--format", "{{.Names}}"],
        capture=True,
        check=False
    )

    if returncode != 0:
        console.print("[red]Error: Redis containers are not running[/red]")
        console.print("[yellow]Start with: ./manage-devstack.py start --profile standard[/yellow]\n")
        return

    # Get Redis password from Vault
    if not check_vault_token():
        console.print("[yellow]Warning: Vault token not found[/yellow]")
        console.print("[yellow]Proceeding without authentication (may fail)[/yellow]\n")
        redis_password = ""
    else:
        # Try to get password from Vault
        token = get_vault_token()
        returncode, stdout, _ = run_command(
            ["docker", "exec", "dev-vault", "vault", "kv", "get", "-field=password", "secret/redis-1"],
            capture=True,
            check=False,
            env={"VAULT_TOKEN": token, "VAULT_ADDR": "http://localhost:8200"}
        )
        redis_password = stdout.strip() if returncode == 0 else ""

    # Initialize cluster
    console.print("[yellow]Initializing Redis cluster...[/yellow]\n")

    cmd = [
        "docker", "exec", "dev-redis-1",
        "redis-cli", "--cluster", "create",
        "172.20.0.13:6379", "172.20.0.16:6379", "172.20.0.17:6379",
        "--cluster-yes"
    ]

    if redis_password:
        cmd.extend(["-a", redis_password])

    returncode, stdout, stderr = run_command(cmd, capture=True, check=False)

    if returncode == 0:
        console.print("[green]✓ Redis cluster initialized successfully[/green]\n")
        console.print("[cyan]Cluster status:[/cyan]")

        # Show cluster nodes
        verify_cmd = ["docker", "exec", "dev-redis-1", "redis-cli", "cluster", "nodes"]
        if redis_password:
            verify_cmd.extend(["-a", redis_password])

        _, nodes_output, _ = run_command(verify_cmd, capture=True, check=False)
        console.print(nodes_output)
    else:
        console.print("[red]Error initializing Redis cluster[/red]")
        if "already" in stderr.lower() or "already" in stdout.lower():
            console.print("[yellow]Cluster may already be initialized[/yellow]")
        else:
            console.print(f"[red]{stderr}[/red]")

    console.print()


# ==============================================================================
# Main Entry Point
# ==============================================================================

if __name__ == "__main__":
    cli()
