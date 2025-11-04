# Container Management

Comprehensive guide to Docker container operations in the Colima Services environment.

## Table of Contents

- [Overview](#overview)
- [Quick Reference](#quick-reference)
- [Container Lifecycle](#container-lifecycle)
  - [Starting Containers](#starting-containers)
  - [Stopping Containers](#stopping-containers)
  - [Restarting Containers](#restarting-containers)
  - [Pausing Containers](#pausing-containers)
  - [Removing Containers](#removing-containers)
- [Container Inspection](#container-inspection)
  - [Listing Containers](#listing-containers)
  - [Container Details](#container-details)
  - [Container Stats](#container-stats)
  - [Container Logs](#container-logs)
  - [Container Processes](#container-processes)
- [Container Execution](#container-execution)
  - [Running Commands](#running-commands)
  - [Interactive Shells](#interactive-shells)
  - [Executing Scripts](#executing-scripts)
  - [File Operations](#file-operations)
- [Container Resources](#container-resources)
  - [CPU Limits](#cpu-limits)
  - [Memory Limits](#memory-limits)
  - [Resource Monitoring](#resource-monitoring)
  - [Resource Optimization](#resource-optimization)
- [Container Networking](#container-networking)
  - [Port Mappings](#port-mappings)
  - [Network Inspection](#network-inspection)
  - [DNS Resolution](#dns-resolution)
  - [Network Connectivity](#network-connectivity)
- [Container Troubleshooting](#container-troubleshooting)
  - [Container Won't Start](#container-wont-start)
  - [Container Crashes](#container-crashes)
  - [Resource Exhaustion](#resource-exhaustion)
  - [Network Issues](#network-issues)
  - [Permission Issues](#permission-issues)
- [Best Practices](#best-practices)
  - [Container Naming](#container-naming)
  - [Logging](#logging)
  - [Health Checks](#health-checks)
  - [Graceful Shutdown](#graceful-shutdown)
- [Using manage-colima.sh](#using-manage-colimash)
  - [Start/Stop Operations](#startstop-operations)
  - [Status Monitoring](#status-monitoring)
  - [Log Management](#log-management)
  - [Shell Access](#shell-access)
- [Docker Compose Operations](#docker-compose-operations)
  - [Service Management](#service-management)
  - [Scaling Services](#scaling-services)
  - [Configuration Validation](#configuration-validation)
  - [Environment Variables](#environment-variables)
- [Related Documentation](#related-documentation)

## Overview

The Colima Services environment uses Docker Compose to manage containers. All services run in the `dev-services` network with static IP addresses.

**Container Infrastructure:**
- **Management**: Docker Compose + manage-colima.sh script
- **Network**: dev-services (172.20.0.0/16)
- **Volume Storage**: Named Docker volumes
- **Orchestration**: Dependencies managed via health checks

**⚠️ WARNING:** This is a development environment. Production container orchestration requires Kubernetes or Docker Swarm.

## Quick Reference

```bash
# List all containers
docker ps
docker ps -a  # Include stopped

# Start/stop containers
docker compose up -d
docker compose down
docker compose restart <service>

# View logs
docker logs <container>
docker compose logs -f <service>

# Execute commands
docker exec <container> <command>
docker exec -it <container> bash

# Container stats
docker stats
docker stats <container> --no-stream

# Inspect container
docker inspect <container>
docker compose ps

# Remove containers
docker rm <container>
docker compose down -v  # Include volumes

# Using management script
./manage-colima.sh start
./manage-colima.sh stop
./manage-colima.sh restart
./manage-colima.sh status
./manage-colima.sh logs <service>
./manage-colima.sh shell <service>
```

## Container Lifecycle

### Starting Containers

```bash
# Start all services
docker compose up -d

# Start specific service
docker compose up -d vault

# Start multiple services
docker compose up -d vault postgres redis-1

# Start without detaching (view logs)
docker compose up vault

# Start with build
docker compose up -d --build reference-api

# Start with scale
docker compose up -d --scale redis-1=3

# Start specific services only
docker compose up -d postgres mysql mongodb

# Force recreate containers
docker compose up -d --force-recreate

# Pull latest images before starting
docker compose pull
docker compose up -d

# Using management script
./manage-colima.sh start  # Starts Colima VM + all services
```

Start container with docker run:

```bash
# Start container from image
docker run -d --name mycontainer nginx:latest

# Start with port mapping
docker run -d -p 8080:80 --name web nginx:latest

# Start with volume mount
docker run -d -v mydata:/data --name app myimage:latest

# Start with environment variables
docker run -d -e DB_HOST=postgres -e DB_PORT=5432 --name app myimage:latest

# Start in network
docker run -d --network dev-services --name app myimage:latest

# Start with resource limits
docker run -d --memory=512m --cpus=0.5 --name app myimage:latest

# Start with restart policy
docker run -d --restart=unless-stopped --name app myimage:latest
```

### Stopping Containers

```bash
# Stop all services
docker compose stop

# Stop specific service
docker compose stop postgres

# Stop multiple services
docker compose stop postgres mysql mongodb

# Stop with timeout
docker compose stop -t 30 postgres  # Wait 30 seconds before killing

# Stop and remove containers
docker compose down

# Stop and remove containers + volumes
docker compose down -v

# Stop and remove containers + images
docker compose down --rmi all

# Using management script
./manage-colima.sh stop  # Stops all services + Colima VM
```

Stop container with docker:

```bash
# Stop container gracefully
docker stop <container>

# Stop with timeout
docker stop -t 30 <container>  # Wait 30 seconds before SIGKILL

# Kill container immediately
docker kill <container>

# Stop all running containers
docker stop $(docker ps -q)

# Stop containers by name pattern
docker ps --filter "name=redis" -q | xargs docker stop
```

### Restarting Containers

```bash
# Restart all services
docker compose restart

# Restart specific service
docker compose restart postgres

# Restart multiple services
docker compose restart postgres redis-1

# Restart with rebuild
docker compose down
docker compose up -d --build

# Using management script
./manage-colima.sh restart  # Restarts services (VM stays running)
```

Restart container with docker:

```bash
# Restart container
docker restart <container>

# Restart with timeout
docker restart -t 30 <container>

# Restart all containers
docker restart $(docker ps -q)
```

### Pausing Containers

```bash
# Pause container (freeze processes)
docker pause <container>

# Unpause container
docker unpause <container>

# Pause all containers
docker pause $(docker ps -q)

# Unpause all containers
docker unpause $(docker ps -q)
```

**Note:** Pausing suspends all processes in the container without stopping it.

### Removing Containers

```bash
# Remove stopped container
docker rm <container>

# Remove running container (force)
docker rm -f <container>

# Remove container and its volumes
docker rm -v <container>

# Remove all stopped containers
docker container prune

# Remove all containers
docker rm -f $(docker ps -aq)

# Using docker compose
docker compose down  # Remove containers
docker compose down -v  # Remove containers + volumes
docker compose rm  # Remove stopped service containers
```

**⚠️ WARNING:** Removing containers deletes their writable layer. Data in volumes is preserved unless `-v` is used.

## Container Inspection

### Listing Containers

```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# List with specific format
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"

# List containers by name
docker ps --filter "name=postgres"

# List containers by status
docker ps --filter "status=running"
docker ps --filter "status=exited"

# List containers by network
docker ps --filter "network=dev-services"

# List containers with size
docker ps -s

# List only container IDs
docker ps -q

# Using docker compose
docker compose ps  # Services only
docker compose ps -a  # All services
```

Custom formatting:

```bash
# Show ID, name, status, and uptime
docker ps --format "{{.ID}}: {{.Names}} - {{.Status}}"

# Show name and ports
docker ps --format "{{.Names}}: {{.Ports}}"

# Show as JSON
docker ps --format "{{json .}}"

# Create alias for custom format
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
```

### Container Details

```bash
# Inspect container (full JSON)
docker inspect <container>

# Get specific field
docker inspect <container> | jq '.[0].State.Status'
docker inspect <container> | jq '.[0].NetworkSettings.IPAddress'
docker inspect <container> | jq '.[0].Config.Env'

# Get container IP address
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <container>

# Get container hostname
docker inspect -f '{{.Config.Hostname}}' <container>

# Get container environment variables
docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' <container>

# Get container port mappings
docker inspect -f '{{range $p, $conf := .NetworkSettings.Ports}}{{$p}} -> {{(index $conf 0).HostPort}}{{println}}{{end}}' <container>

# Get container mounts
docker inspect -f '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' <container>

# Get container creation time
docker inspect -f '{{.Created}}' <container>

# Get container restart count
docker inspect -f '{{.RestartCount}}' <container>
```

Using docker compose:

```bash
# Show service configuration
docker compose config

# Show service ports
docker compose port <service> <port>
docker compose port postgres 5432

# Show service images
docker compose images
```

### Container Stats

```bash
# Real-time stats for all containers
docker stats

# Stats for specific container
docker stats <container>

# Stats without streaming (snapshot)
docker stats --no-stream

# Stats with custom format
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# Monitor specific containers
docker stats postgres mysql mongodb --no-stream

# Watch stats (1 second refresh)
watch -n 1 'docker stats --no-stream'
```

Stats output:
- **CONTAINER**: Container name
- **CPU %**: CPU usage percentage
- **MEM USAGE / LIMIT**: Memory usage and limit
- **MEM %**: Memory usage percentage
- **NET I/O**: Network traffic
- **BLOCK I/O**: Disk I/O
- **PIDS**: Number of processes

### Container Logs

```bash
# View container logs
docker logs <container>

# Follow logs (tail -f)
docker logs -f <container>

# Show last N lines
docker logs --tail 50 <container>

# Show logs since timestamp
docker logs --since 2024-01-15T10:00:00 <container>

# Show logs for time range
docker logs --since 1h <container>  # Last hour
docker logs --since 30m <container>  # Last 30 minutes

# Show logs with timestamps
docker logs -t <container>

# Show logs until timestamp
docker logs --until 2024-01-15T12:00:00 <container>

# Combine options
docker logs -f --tail 100 --since 5m <container>

# Save logs to file
docker logs <container> > container.log 2>&1

# Using docker compose
docker compose logs  # All services
docker compose logs -f  # Follow all
docker compose logs -f <service>  # Follow specific service
docker compose logs --tail 50 <service>  # Last 50 lines
docker compose logs --since 10m  # Last 10 minutes

# Using management script
./manage-colima.sh logs  # All services
./manage-colima.sh logs <service>  # Specific service
```

Filter logs:

```bash
# Grep for errors
docker logs <container> 2>&1 | grep -i error

# Filter by pattern
docker logs postgres | grep "connection received"

# Count occurrences
docker logs postgres | grep -c "checkpoint complete"

# Show only errors (stderr)
docker logs postgres 2>&1 > /dev/null
```

### Container Processes

```bash
# List processes in container
docker top <container>

# List with custom format
docker top <container> aux

# List all processes
docker top <container> -ef

# Using ps inside container
docker exec <container> ps aux

# Show process tree
docker exec <container> ps auxf

# Monitor processes
watch -n 1 'docker exec <container> ps aux'

# Count processes
docker exec <container> ps aux | wc -l

# Find specific process
docker exec postgres ps aux | grep postgres
```

## Container Execution

### Running Commands

```bash
# Execute command in running container
docker exec <container> <command>

# Execute with output
docker exec postgres psql -U postgres -c "SELECT version();"

# Execute multiple commands
docker exec postgres sh -c "psql -U postgres -c 'SELECT 1'; echo 'Done'"

# Execute as specific user
docker exec -u postgres postgres psql -c "SELECT current_user;"

# Execute with working directory
docker exec -w /app <container> ls -la

# Execute with environment variables
docker exec -e DEBUG=true <container> node app.js

# Using docker compose
docker compose exec <service> <command>
docker compose exec postgres psql -U postgres
```

Common commands:

```bash
# Check service version
docker exec postgres psql --version
docker exec mysql mysql --version
docker exec mongodb mongosh --version
docker exec redis-1 redis-cli --version

# Test connectivity
docker exec <container> ping google.com
docker exec <container> nc -zv postgres 5432

# View configuration
docker exec postgres cat /etc/postgresql/postgresql.conf
docker exec nginx cat /etc/nginx/nginx.conf

# Check disk usage
docker exec <container> df -h

# View environment
docker exec <container> env

# Check network
docker exec <container> netstat -tlnp
docker exec <container> ip addr show
```

### Interactive Shells

```bash
# Interactive bash shell
docker exec -it <container> bash

# Interactive sh shell (Alpine images)
docker exec -it <container> sh

# Interactive shell as root
docker exec -it -u root <container> bash

# Interactive shell with environment
docker exec -it -e TERM=xterm <container> bash

# Using docker compose
docker compose exec <service> bash
docker compose exec <service> sh

# Using management script
./manage-colima.sh shell <service>
./manage-colima.sh shell postgres  # Opens psql shell
./manage-colima.sh shell mysql     # Opens mysql shell
./manage-colima.sh shell mongodb   # Opens mongosh shell
```

Database shells:

```bash
# PostgreSQL
docker exec -it postgres psql -U postgres
docker exec -it postgres psql -U postgres -d myapp

# MySQL
docker exec -it mysql mysql -u root -p
docker exec -it mysql mysql -u root -p myapp

# MongoDB
docker exec -it mongodb mongosh
docker exec -it mongodb mongosh myapp

# Redis
docker exec -it redis-1 redis-cli
docker exec -it redis-1 redis-cli -c  # Cluster mode
```

### Executing Scripts

```bash
# Execute script from host
docker exec -i <container> bash < script.sh

# Execute SQL script
docker exec -i postgres psql -U postgres < schema.sql
docker exec -i mysql mysql -u root -p myapp < schema.sql

# Execute script from container
docker exec <container> /app/scripts/init.sh

# Execute with heredoc
docker exec -i postgres psql -U postgres << 'EOF'
CREATE DATABASE myapp;
\c myapp
CREATE TABLE users (id SERIAL PRIMARY KEY, name TEXT);
EOF

# Copy and execute script
docker cp script.sh <container>:/tmp/script.sh
docker exec <container> bash /tmp/script.sh
docker exec <container> rm /tmp/script.sh
```

### File Operations

```bash
# Copy file to container
docker cp localfile.txt <container>:/path/in/container/

# Copy file from container
docker cp <container>:/path/in/container/file.txt ./localfile.txt

# Copy directory to container
docker cp ./localdir <container>:/path/in/container/

# Copy directory from container
docker cp <container>:/path/in/container/dir ./localdir

# Archive and copy
tar czf - localdir | docker exec -i <container> tar xzf - -C /app/

# Copy from container and extract
docker exec <container> tar czf - /app/logs | tar xzf - -C ./logs/

# Using docker compose
docker compose cp ./config.yml <service>:/app/config.yml
docker compose cp <service>:/app/logs ./logs
```

## Container Resources

### CPU Limits

```bash
# Start container with CPU limit
docker run -d --cpus=0.5 --name app myimage  # 50% of one CPU
docker run -d --cpus=2 --name app myimage    # 2 CPUs

# Start with CPU shares (relative weight)
docker run -d --cpu-shares=512 --name app myimage  # Default is 1024

# Start with specific CPUs
docker run -d --cpuset-cpus="0,1" --name app myimage  # Use CPU 0 and 1

# Update CPU limit on running container
docker update --cpus=1 <container>

# View CPU limit
docker inspect <container> | jq '.[0].HostConfig.NanoCpus'
```

Configure in docker-compose.yml:

```yaml
services:
  myapp:
    image: myimage:latest
    deploy:
      resources:
        limits:
          cpus: '0.5'
        reservations:
          cpus: '0.25'
```

### Memory Limits

```bash
# Start container with memory limit
docker run -d --memory=512m --name app myimage
docker run -d --memory=1g --name app myimage

# Start with memory reservation (soft limit)
docker run -d --memory=1g --memory-reservation=512m --name app myimage

# Start with swap limit
docker run -d --memory=512m --memory-swap=1g --name app myimage

# Disable swap
docker run -d --memory=512m --memory-swap=512m --name app myimage

# OOM kill disable (⚠️ dangerous)
docker run -d --memory=512m --oom-kill-disable --name app myimage

# Update memory limit on running container
docker update --memory=1g <container>

# View memory limit
docker inspect <container> | jq '.[0].HostConfig.Memory'
```

Configure in docker-compose.yml:

```yaml
services:
  myapp:
    image: myimage:latest
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
```

### Resource Monitoring

```bash
# Monitor resource usage
docker stats --no-stream

# Monitor specific container
docker stats <container> --no-stream

# Monitor with custom format
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}\t{{.MemUsage}}"

# Continuous monitoring
watch -n 1 'docker stats --no-stream'

# Resource usage history (requires cAdvisor)
curl http://localhost:8080/api/v1.3/docker/<container>

# Check OOM kills
docker inspect <container> | jq '.[0].State.OOMKilled'

# View container events
docker events --filter container=<container>

# Monitor all containers
for container in $(docker ps -q); do
  echo "=== $(docker inspect -f '{{.Name}}' $container) ==="
  docker stats $container --no-stream
done
```

### Resource Optimization

```bash
# Identify resource-heavy containers
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}" | sort -k2 -rn

# Find containers using most memory
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}" | sort -k2 -rn

# Check container size
docker ps -s

# Find large containers
docker ps -s --format "table {{.Names}}\t{{.Size}}" | sort -k2 -rn

# Optimize image layers
docker history <image>

# Remove unused containers
docker container prune

# Remove unused images
docker image prune -a

# Clean up everything
docker system prune -a --volumes
```

## Container Networking

### Port Mappings

```bash
# List port mappings
docker port <container>

# Get specific port mapping
docker port <container> 5432

# View all port mappings
docker ps --format "table {{.Names}}\t{{.Ports}}"

# Inspect network settings
docker inspect <container> | jq '.[0].NetworkSettings.Ports'

# Using docker compose
docker compose port <service> <port>
docker compose port postgres 5432
```

Configure in docker-compose.yml:

```yaml
services:
  postgres:
    ports:
      - "5432:5432"           # host:container
      - "127.0.0.1:5432:5432" # bind to specific IP
      - "5432"                # random host port
```

### Network Inspection

```bash
# List networks
docker network ls

# Inspect network
docker network inspect dev-services

# Show containers in network
docker network inspect dev-services | jq '.[0].Containers'

# Get container network settings
docker inspect <container> | jq '.[0].NetworkSettings.Networks'

# Get container IP address
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <container>

# Get container MAC address
docker inspect -f '{{range .NetworkSettings.Networks}}{{.MacAddress}}{{end}}' <container>

# List all container IPs
for container in $(docker ps -q); do
  echo "$(docker inspect -f '{{.Name}}' $container): $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container)"
done

# Show network statistics
docker stats --format "table {{.Name}}\t{{.NetIO}}"
```

### DNS Resolution

```bash
# Test DNS from container
docker exec <container> nslookup postgres
docker exec <container> dig postgres
docker exec <container> host postgres

# Test DNS using getent
docker exec <container> getent hosts postgres

# Ping by hostname
docker exec <container> ping -c 3 postgres

# Verify DNS configuration
docker exec <container> cat /etc/resolv.conf

# Test external DNS
docker exec <container> nslookup google.com
docker exec <container> ping -c 3 google.com
```

### Network Connectivity

```bash
# Test TCP connectivity
docker exec <container> nc -zv postgres 5432
docker exec <container> telnet postgres 5432

# Test HTTP connectivity
docker exec <container> curl http://vault:8200/v1/sys/health
docker exec <container> wget -qO- http://vault:8200/v1/sys/health

# Trace route
docker exec <container> traceroute postgres

# Show network interfaces
docker exec <container> ip addr show
docker exec <container> ifconfig

# Show routing table
docker exec <container> ip route
docker exec <container> route -n

# Show network connections
docker exec <container> netstat -tlnp
docker exec <container> ss -tlnp

# Monitor network traffic
docker exec <container> iftop
docker exec <container> nethogs
```

## Container Troubleshooting

### Container Won't Start

```bash
# Check container status
docker ps -a --filter "name=<container>"

# View container logs
docker logs <container>

# Inspect container
docker inspect <container>

# Check exit code
docker inspect <container> | jq '.[0].State.ExitCode'

# View last start error
docker inspect <container> | jq '.[0].State.Error'

# Try starting without detach
docker compose up <service>  # View startup logs

# Check dependencies
docker compose config | grep -A 10 "depends_on"

# Verify image exists
docker images | grep <image>

# Check for port conflicts
netstat -tlnp | grep <port>

# Verify volumes exist
docker volume ls | grep <volume>

# Check health check
docker inspect <container> | jq '.[0].State.Health'

# Manual troubleshooting steps:
# 1. Check logs: docker logs <container>
# 2. Check config: docker compose config
# 3. Check dependencies: docker ps
# 4. Check resources: df -h (disk space)
# 5. Check network: docker network ls
# 6. Check volumes: docker volume ls
```

### Container Crashes

```bash
# View crash logs
docker logs <container>

# Check if OOM killed
docker inspect <container> | jq '.[0].State.OOMKilled'

# View recent events
docker events --filter container=<container> --since 1h

# Check restart count
docker inspect <container> | jq '.[0].RestartCount'

# Monitor for crashes
watch -n 1 'docker ps -a --filter "name=<container>"'

# Enable debug logging
# Edit docker-compose.yml and add:
# environment:
#   DEBUG: "true"
#   LOG_LEVEL: "debug"

# Check system resources
docker stats --no-stream
df -h
free -h

# Review docker daemon logs
sudo journalctl -u docker -n 100

# Common crash causes:
# 1. Out of memory (OOMKilled: true)
# 2. Missing dependencies
# 3. Configuration errors
# 4. Port already in use
# 5. Volume permission issues
```

### Resource Exhaustion

```bash
# Check container resource usage
docker stats <container> --no-stream

# Check if memory limit exceeded
docker inspect <container> | jq '.[0].HostConfig.Memory'

# Check disk usage
docker exec <container> df -h
docker system df

# Check inode usage
docker exec <container> df -i

# Find large files
docker exec <container> du -sh /* 2>/dev/null | sort -rh | head -20

# Check open file descriptors
docker exec <container> ls -la /proc/self/fd | wc -l

# Increase resource limits
docker update --memory=2g --cpus=2 <container>

# Or in docker-compose.yml:
# deploy:
#   resources:
#     limits:
#       memory: 2G
#       cpus: '2'

# Clean up disk space
docker system prune -a --volumes  # ⚠️ Removes everything unused
docker volume prune
docker image prune -a
docker container prune
```

### Network Issues

```bash
# Test container networking
docker exec <container> ping -c 3 google.com

# Check if container has network
docker inspect <container> | jq '.[0].NetworkSettings.Networks'

# Check DNS resolution
docker exec <container> nslookup postgres

# Test port connectivity
docker exec <container> nc -zv postgres 5432

# Check routing
docker exec <container> ip route

# Verify firewall rules
docker exec <container> iptables -L

# Check for port conflicts
netstat -tlnp | grep <port>
lsof -i :<port>

# Restart networking
docker compose restart <service>

# Recreate network
docker compose down
docker network rm dev-services
docker compose up -d

# Test from host
telnet localhost <port>
curl http://localhost:<port>/health

# Common network issues:
# 1. Container not in correct network
# 2. Port not exposed/mapped
# 3. Firewall blocking connection
# 4. DNS resolution failure
# 5. Service not listening on correct interface
```

### Permission Issues

```bash
# Check file permissions
docker exec <container> ls -la /path/to/file

# Check container user
docker exec <container> whoami
docker exec <container> id

# Check volume permissions
docker exec <container> ls -la /var/lib/postgresql/data

# Run as root to fix permissions
docker exec -u root <container> chown -R postgres:postgres /var/lib/postgresql/data

# Check user in image
docker inspect <image> | jq '.[0].Config.User'

# Fix volume permissions (PostgreSQL example)
docker compose down
docker run --rm -v postgres-data:/data -u root alpine chown -R 999:999 /data
docker compose up -d postgres

# Fix volume permissions (MySQL example)
docker run --rm -v mysql-data:/data -u root alpine chown -R 999:999 /data

# Common permission issues:
# 1. Volume owned by root instead of service user
# 2. Files created with wrong UID/GID
# 3. SELinux/AppArmor restrictions
# 4. Read-only filesystem
```

## Best Practices

### Container Naming

```bash
# Use descriptive names
docker run -d --name dev-postgres postgres:16

# Follow naming convention
# Format: <env>-<service>[-<instance>]
# Examples:
# - dev-postgres
# - dev-redis-1
# - dev-reference-api

# Avoid generic names
# Bad: postgres, db, container1
# Good: dev-postgres, myapp-postgres

# Use docker compose service names
# docker-compose.yml defines the names
services:
  postgres:
    container_name: postgres  # Explicit name
```

### Logging

```bash
# Configure log driver in docker-compose.yml
services:
  myapp:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

# Available log drivers:
# - json-file (default)
# - syslog
# - journald
# - gelf
# - fluentd
# - awslogs
# - splunk

# Log to centralized system
services:
  myapp:
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://loki:1514"

# View logs with timestamps
docker logs -t <container>

# Rotate logs manually
docker inspect <container> | jq '.[0].LogPath'
# Truncate log file if too large

# Best practices:
# 1. Set max-size to prevent disk fill
# 2. Use structured logging (JSON)
# 3. Include timestamps
# 4. Log to stdout/stderr
# 5. Use appropriate log levels
```

### Health Checks

```bash
# Configure health check in docker-compose.yml
services:
  postgres:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

# Check health status
docker inspect <container> | jq '.[0].State.Health'

# View health check history
docker inspect <container> | jq '.[0].State.Health.Log'

# Wait for healthy status
docker compose up -d postgres
until [ "$(docker inspect -f '{{.State.Health.Status}}' postgres)" == "healthy" ]; do
  echo "Waiting for postgres..."
  sleep 2
done

# Health check best practices:
# 1. Test actual service functionality
# 2. Set appropriate timeout
# 3. Allow start_period for initialization
# 4. Check dependencies in health check
# 5. Return proper exit codes (0=healthy, 1=unhealthy)

# Example health checks:
# PostgreSQL:
# test: ["CMD-SHELL", "pg_isready -U postgres"]

# MySQL:
# test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]

# MongoDB:
# test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]

# Redis:
# test: ["CMD", "redis-cli", "ping"]

# HTTP service:
# test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
```

### Graceful Shutdown

```bash
# Configure stop signal
services:
  myapp:
    stop_signal: SIGTERM
    stop_grace_period: 30s

# Default signals:
# - SIGTERM (graceful shutdown)
# - SIGKILL (force kill after grace period)

# Handle signals in application
# Python example:
import signal
import sys

def signal_handler(sig, frame):
    print('Graceful shutdown...')
    # Close connections
    # Save state
    sys.exit(0)

signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)

# Test graceful shutdown
docker stop -t 30 <container>

# Monitor shutdown
docker events --filter container=<container>

# Best practices:
# 1. Handle SIGTERM in application
# 2. Set appropriate grace period
# 3. Close connections cleanly
# 4. Save state before exit
# 5. Log shutdown process
```

## Using manage-colima.sh

### Start/Stop Operations

```bash
# Start entire environment
./manage-colima.sh start
# - Starts Colima VM
# - Starts all Docker Compose services
# - Waits for health checks

# Stop entire environment
./manage-colima.sh stop
# - Stops all services
# - Stops Colima VM

# Restart services (VM stays running)
./manage-colima.sh restart
# - Restarts Docker Compose services
# - Faster than full stop/start
```

### Status Monitoring

```bash
# Check VM and service status
./manage-colima.sh status
# Shows:
# - Colima VM status
# - Container status
# - Resource usage
# - Uptime

# Check health of all services
./manage-colima.sh health
# Tests:
# - Vault API
# - PostgreSQL connection
# - MySQL connection
# - MongoDB connection
# - Redis cluster
# - RabbitMQ API
```

### Log Management

```bash
# View all service logs
./manage-colima.sh logs

# View specific service logs
./manage-colima.sh logs postgres
./manage-colima.sh logs vault
./manage-colima.sh logs redis-1

# Follow logs (tail -f)
./manage-colima.sh logs -f <service>
```

### Shell Access

```bash
# Open shell in service container
./manage-colima.sh shell <service>

# Examples:
./manage-colima.sh shell postgres  # Opens psql
./manage-colima.sh shell mysql     # Opens mysql client
./manage-colima.sh shell mongodb   # Opens mongosh
./manage-colima.sh shell redis-1   # Opens redis-cli
./manage-colima.sh shell vault     # Opens /bin/sh
```

## Docker Compose Operations

### Service Management

```bash
# View service configuration
docker compose config

# Validate configuration
docker compose config --quiet

# List services
docker compose ps

# Start specific services
docker compose up -d postgres redis-1

# Stop specific services
docker compose stop postgres redis-1

# Restart specific services
docker compose restart postgres redis-1

# Remove stopped services
docker compose rm

# Recreate services
docker compose up -d --force-recreate postgres

# Pull latest images
docker compose pull

# Build images
docker compose build

# Build and start
docker compose up -d --build
```

### Scaling Services

```bash
# Scale service to multiple replicas
docker compose up -d --scale redis-1=3

# View scaled instances
docker compose ps

# Scale down
docker compose up -d --scale redis-1=1

# Note: Colima Services uses static IPs
# Scaling requires network configuration changes
```

### Configuration Validation

```bash
# Validate docker-compose.yml
docker compose config

# Check for syntax errors
docker compose config --quiet
echo $?  # 0 = valid, 1 = invalid

# View resolved configuration
docker compose config

# View specific service config
docker compose config postgres

# Check environment variables
docker compose config | grep -A 10 environment

# Verify volumes
docker compose config | grep -A 5 volumes

# Verify networks
docker compose config | grep -A 5 networks
```

### Environment Variables

```bash
# Load from .env file (automatic)
# docker-compose.yml references: ${VARIABLE_NAME}

# Override with environment
DATABASE_HOST=postgres docker compose up -d

# Use multiple .env files
docker compose --env-file .env.production up -d

# View resolved variables
docker compose config | grep -A 20 environment

# Pass variables to container
services:
  myapp:
    environment:
      - DATABASE_HOST=${DATABASE_HOST}
      - DATABASE_PORT=${DATABASE_PORT}

# Or use env_file
services:
  myapp:
    env_file:
      - .env
      - .env.local
```

## Related Documentation

- [Volume Management](Volume-Management) - Docker volume operations
- [Docker Compose Reference](Docker-Compose-Reference) - Complete compose guide
- [Service Overview](Service-Overview) - All services in environment
- [Health Monitoring](Health-Monitoring) - Service health checks
- [Network Architecture](Network-Architecture) - Network configuration
- [Debugging Techniques](Debugging-Techniques) - Container debugging
- [Log Analysis](Log-Analysis) - Log aggregation and analysis
- [Network Debugging](Network-Debugging) - Network troubleshooting

---

**Quick Reference Card:**

```bash
# Lifecycle
docker compose up -d
docker compose down
docker compose restart <service>

# Inspection
docker ps
docker logs -f <container>
docker stats <container>
docker inspect <container>

# Execution
docker exec -it <container> bash
docker exec <container> <command>
docker compose exec <service> <command>

# Management Script
./manage-colima.sh start
./manage-colima.sh stop
./manage-colima.sh restart
./manage-colima.sh status
./manage-colima.sh logs <service>
./manage-colima.sh shell <service>

# Troubleshooting
docker logs <container>
docker inspect <container>
docker stats <container>
docker exec -it <container> bash
```
