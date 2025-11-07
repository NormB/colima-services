# PostgreSQL Operations

Comprehensive guide to PostgreSQL database operations, performance tuning, and troubleshooting in the DevStack Core environment.

## Table of Contents

- [Overview](#overview)
- [Daily Operations](#daily-operations)
  - [Connection Management](#connection-management)
  - [User Management](#user-management)
  - [Database Management](#database-management)
  - [Schema Management](#schema-management)
- [Query Optimization](#query-optimization)
  - [EXPLAIN ANALYZE](#explain-analyze)
  - [Query Planning](#query-planning)
  - [Index Usage Analysis](#index-usage-analysis)
  - [Query Performance Tips](#query-performance-tips)
- [Performance Monitoring](#performance-monitoring)
  - [pg_stat_statements](#pg_stat_statements)
  - [pg_stat_activity](#pg_stat_activity)
  - [Connection Monitoring](#connection-monitoring)
  - [Slow Query Identification](#slow-query-identification)
  - [Resource Usage Monitoring](#resource-usage-monitoring)
- [Index Management](#index-management)
  - [Creating Indexes](#creating-indexes)
  - [Index Types](#index-types)
  - [Index Maintenance](#index-maintenance)
  - [Reindexing Operations](#reindexing-operations)
  - [Index Usage Statistics](#index-usage-statistics)
- [Maintenance Operations](#maintenance-operations)
  - [VACUUM Operations](#vacuum-operations)
  - [ANALYZE Operations](#analyze-operations)
  - [Autovacuum Tuning](#autovacuum-tuning)
  - [Bloat Management](#bloat-management)
  - [Table and Index Bloat Detection](#table-and-index-bloat-detection)
- [Backup Operations](#backup-operations)
  - [pg_dump Basic Usage](#pg_dump-basic-usage)
  - [pg_dumpall for Full Backups](#pg_dumpall-for-full-backups)
  - [Backup Best Practices](#backup-best-practices)
  - [Point-in-Time Recovery Preparation](#point-in-time-recovery-preparation)
- [Troubleshooting](#troubleshooting)
  - [Connection Issues](#connection-issues)
  - [Lock Contention](#lock-contention)
  - [Performance Problems](#performance-problems)
  - [Disk Space Issues](#disk-space-issues)
  - [Replication Lag](#replication-lag)
- [Configuration Tuning](#configuration-tuning)
  - [Memory Settings](#memory-settings)
  - [Connection Settings](#connection-settings)
  - [Write-Ahead Log Settings](#write-ahead-log-settings)
  - [Query Planner Settings](#query-planner-settings)
- [Security Operations](#security-operations)
  - [Role-Based Access Control](#role-based-access-control)
  - [SSL/TLS Configuration](#ssltls-configuration)
  - [Password Policies](#password-policies)
  - [Audit Logging](#audit-logging)
- [Reference](#reference)

## Overview

PostgreSQL is the primary relational database in the DevStack Core environment, running in the `dev-postgres` container at `172.20.0.10:5432`. This guide covers essential operational procedures, performance optimization, and troubleshooting.

**Key Information:**
- **Container Name:** `dev-postgres`
- **Host Port:** 5432 (both TLS and non-TLS)
- **Network IP:** 172.20.0.10
- **Data Volume:** `postgres_data`
- **Configuration:** `/configs/postgres/postgresql.conf`
- **Credentials:** Stored in Vault at `secret/postgres`

**Related Pages:**
- [Service Configuration](Service-Configuration) - PostgreSQL configuration details
- [Service Overview](Service-Overview) - PostgreSQL service architecture
- [Backup and Restore](Backup-and-Restore) - Backup procedures
- [Performance Tuning](Performance-Tuning) - Advanced tuning
- [PgBouncer Usage](PgBouncer-Usage) - Connection pooling

## Daily Operations

### Connection Management

#### Connecting to PostgreSQL

**Direct Connection (psql client):**

```bash
# Connect from host machine
docker exec -it dev-postgres psql -U postgres

# Connect to specific database
docker exec -it dev-postgres psql -U postgres -d myapp

# Connect with Vault credentials
export POSTGRES_PASSWORD=$(./manage-devstack.sh vault-show-password postgres)
docker exec -e PGPASSWORD=$POSTGRES_PASSWORD -it dev-postgres psql -U postgres
```

**Using Connection String:**

```bash
# Standard connection string format
postgresql://postgres:password@localhost:5432/postgres

# Connection through PgBouncer (recommended for applications)
postgresql://postgres:password@localhost:6432/postgres
```

**Testing Connectivity:**

```bash
# Test PostgreSQL is accepting connections
docker exec dev-postgres pg_isready -U postgres

# Test specific database
docker exec dev-postgres pg_isready -U postgres -d myapp

# Check version
docker exec -it dev-postgres psql -U postgres -c "SELECT version();"
```

#### Listing Active Connections

```sql
-- Show all active connections
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query_start,
    state_change,
    query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;

-- Count connections by database
SELECT
    datname,
    count(*) as connections
FROM pg_stat_activity
GROUP BY datname
ORDER BY connections DESC;

-- Count connections by user
SELECT
    usename,
    count(*) as connections
FROM pg_stat_activity
GROUP BY usename
ORDER BY connections DESC;
```

#### Terminating Connections

```sql
-- Terminate a specific connection (use pid from pg_stat_activity)
SELECT pg_terminate_backend(12345);

-- Terminate all connections to a database (except yours)
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'myapp' AND pid != pg_backend_pid();

-- Terminate idle connections older than 30 minutes
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle'
  AND state_change < NOW() - INTERVAL '30 minutes'
  AND pid != pg_backend_pid();
```

**⚠️ WARNING:** Terminating connections will interrupt active queries and transactions. Use with caution.

### User Management

#### Creating Users

```sql
-- Create a basic user
CREATE USER myapp_user WITH PASSWORD 'secure_password';

-- Create user with specific privileges
CREATE USER readonly_user WITH PASSWORD 'secure_password'
    LOGIN
    CONNECTION LIMIT 10
    VALID UNTIL '2026-01-01';

-- Create superuser (use sparingly)
CREATE USER admin_user WITH PASSWORD 'secure_password' SUPERUSER;
```

#### Managing User Privileges

```sql
-- Grant database access
GRANT CONNECT ON DATABASE myapp TO myapp_user;

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO myapp_user;

-- Grant table privileges
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO myapp_user;

-- Grant privileges on future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO myapp_user;

-- Grant sequence privileges (for auto-increment columns)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO myapp_user;

-- Create read-only user
GRANT CONNECT ON DATABASE myapp TO readonly_user;
GRANT USAGE ON SCHEMA public TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO readonly_user;
```

#### Listing Users and Roles

```sql
-- List all users
\du

-- List users with details
SELECT
    rolname as username,
    rolsuper as is_superuser,
    rolinherit as can_inherit,
    rolcreaterole as can_create_role,
    rolcreatedb as can_create_db,
    rolcanlogin as can_login,
    rolconnlimit as connection_limit,
    rolvaliduntil as valid_until
FROM pg_roles
ORDER BY rolname;

-- Show user privileges on a database
\l+ myapp

-- Show table privileges for a user
SELECT
    grantee,
    table_schema,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'myapp_user';
```

#### Modifying Users

```sql
-- Change password
ALTER USER myapp_user WITH PASSWORD 'new_secure_password';

-- Modify connection limit
ALTER USER myapp_user CONNECTION LIMIT 20;

-- Set password expiration
ALTER USER myapp_user VALID UNTIL '2027-01-01';

-- Disable login
ALTER USER myapp_user NOLOGIN;

-- Enable login
ALTER USER myapp_user LOGIN;

-- Rename user
ALTER USER old_name RENAME TO new_name;
```

#### Dropping Users

```sql
-- Drop user (must have no owned objects)
DROP USER myapp_user;

-- Drop user and reassign owned objects
REASSIGN OWNED BY myapp_user TO postgres;
DROP OWNED BY myapp_user;
DROP USER myapp_user;
```

### Database Management

#### Creating Databases

```bash
# Create database from command line
docker exec -it dev-postgres createdb -U postgres myapp

# Create database from psql
docker exec -it dev-postgres psql -U postgres -c "CREATE DATABASE myapp;"
```

```sql
-- Create database with specific owner
CREATE DATABASE myapp OWNER myapp_user;

-- Create database with encoding and locale
CREATE DATABASE myapp
    OWNER myapp_user
    ENCODING 'UTF8'
    LC_COLLATE 'en_US.UTF-8'
    LC_CTYPE 'en_US.UTF-8'
    TEMPLATE template0;

-- Create database with connection limit
CREATE DATABASE myapp
    OWNER myapp_user
    CONNECTION LIMIT 50;
```

#### Listing Databases

```sql
-- List all databases
\l

-- List databases with details
\l+

-- Query database information
SELECT
    datname as database_name,
    pg_size_pretty(pg_database_size(datname)) as size,
    datconnlimit as connection_limit,
    numbackends as current_connections
FROM pg_database
WHERE datname NOT IN ('template0', 'template1')
ORDER BY pg_database_size(datname) DESC;
```

#### Database Statistics

```sql
-- Show database activity
SELECT
    datname,
    numbackends as connections,
    xact_commit as commits,
    xact_rollback as rollbacks,
    blks_read as disk_reads,
    blks_hit as cache_hits,
    round(100.0 * blks_hit / (blks_hit + blks_read), 2) as cache_hit_ratio
FROM pg_stat_database
WHERE datname = 'myapp';

-- Show database size trends
SELECT
    datname,
    pg_size_pretty(pg_database_size(datname)) as current_size
FROM pg_database
WHERE datname NOT IN ('template0', 'template1')
ORDER BY pg_database_size(datname) DESC;
```

#### Renaming Databases

```sql
-- Rename database (requires no active connections)
ALTER DATABASE myapp RENAME TO myapp_new;
```

**⚠️ WARNING:** Database rename requires terminating all connections to the database first.

```sql
-- Terminate all connections before rename
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'myapp' AND pid != pg_backend_pid();

-- Now rename
ALTER DATABASE myapp RENAME TO myapp_new;
```

#### Dropping Databases

```bash
# Drop database from command line
docker exec -it dev-postgres dropdb -U postgres myapp

# Drop database from psql
docker exec -it dev-postgres psql -U postgres -c "DROP DATABASE myapp;"
```

**⚠️ WARNING:** Dropping a database is irreversible. Always backup before dropping.

```sql
-- Force drop database (terminate connections first)
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'myapp' AND pid != pg_backend_pid();

DROP DATABASE myapp;
```

### Schema Management

#### Creating Schemas

```sql
-- Create schema
CREATE SCHEMA myapp_schema;

-- Create schema with owner
CREATE SCHEMA myapp_schema AUTHORIZATION myapp_user;

-- Create schema if not exists
CREATE SCHEMA IF NOT EXISTS myapp_schema;
```

#### Listing Schemas

```sql
-- List all schemas
\dn

-- List schemas with details
\dn+

-- Query schema information
SELECT
    schema_name,
    schema_owner
FROM information_schema.schemata
WHERE schema_name NOT IN ('pg_catalog', 'information_schema')
ORDER BY schema_name;
```

#### Setting Search Path

```sql
-- Set search path for current session
SET search_path TO myapp_schema, public;

-- Set default search path for user
ALTER USER myapp_user SET search_path TO myapp_schema, public;

-- Show current search path
SHOW search_path;
```

## Query Optimization

### EXPLAIN ANALYZE

**EXPLAIN** shows the query execution plan. **EXPLAIN ANALYZE** executes the query and shows actual execution times.

#### Basic EXPLAIN

```sql
-- Show query plan without executing
EXPLAIN SELECT * FROM users WHERE email = 'user@example.com';

-- Show detailed query plan
EXPLAIN (VERBOSE, COSTS, BUFFERS)
SELECT * FROM users WHERE email = 'user@example.com';

-- Execute query and show actual times
EXPLAIN ANALYZE
SELECT * FROM users WHERE email = 'user@example.com';

-- Show detailed execution plan with actual times
EXPLAIN (ANALYZE, VERBOSE, COSTS, BUFFERS, TIMING)
SELECT * FROM users WHERE email = 'user@example.com';
```

#### Reading EXPLAIN Output

```sql
-- Example query with EXPLAIN output
EXPLAIN ANALYZE
SELECT u.name, o.total
FROM users u
JOIN orders o ON u.id = o.user_id
WHERE u.created_at > '2024-01-01';

/*
Key metrics to watch:
- Planning Time: Time spent planning the query
- Execution Time: Time spent executing the query
- Seq Scan: Sequential scan (full table scan - often slow)
- Index Scan: Index-based retrieval (usually fast)
- Nested Loop: Join method (good for small result sets)
- Hash Join: Join method (good for large result sets)
- Rows: Estimated vs actual row counts
- Buffers: Disk I/O (shared hit = cache, read = disk)
*/
```

**Plan Node Types:**

- **Seq Scan:** Full table scan - considers every row
- **Index Scan:** Uses index to find specific rows
- **Index Only Scan:** Retrieves data from index alone (fastest)
- **Bitmap Index Scan:** Uses index bitmap for complex conditions
- **Nested Loop:** Joins by iterating through one table for each row of another
- **Hash Join:** Builds hash table of one relation and probes with other
- **Merge Join:** Sorts both relations and merges them

### Query Planning

#### Analyzing Query Plans

```sql
-- Look for sequential scans on large tables
EXPLAIN ANALYZE
SELECT * FROM large_table WHERE uncommon_column = 'value';
-- If you see "Seq Scan on large_table", consider adding an index

-- Check join efficiency
EXPLAIN ANALYZE
SELECT * FROM orders o
JOIN users u ON o.user_id = u.id
WHERE o.status = 'pending';
-- Look for "Hash Join" or "Nested Loop" - Hash Join is better for large sets

-- Identify missing indexes
EXPLAIN ANALYZE
SELECT * FROM products WHERE category = 'electronics' AND price > 100;
-- If you see "Seq Scan", add composite index on (category, price)
```

#### Query Planner Statistics

```sql
-- Update table statistics (helps planner make better decisions)
ANALYZE users;

-- Update statistics for entire database
ANALYZE;

-- Show table statistics
SELECT
    schemaname,
    tablename,
    last_analyze,
    last_autoanalyze,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;
```

### Index Usage Analysis

#### Checking Index Usage

```sql
-- Show indexes for a table
\d users

-- List all indexes with usage statistics
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- Find unused indexes (candidates for removal)
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as scans,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelname NOT LIKE '%_pkey'
ORDER BY pg_relation_size(indexrelid) DESC;

-- Show index hit ratio (should be > 99%)
SELECT
    sum(idx_blks_hit) / nullif(sum(idx_blks_hit + idx_blks_read), 0) * 100
    as index_hit_ratio
FROM pg_statio_user_indexes;
```

#### Testing Index Effectiveness

```sql
-- Before creating index: Check query performance
EXPLAIN ANALYZE
SELECT * FROM users WHERE email = 'user@example.com';
-- Note the execution time

-- Create index
CREATE INDEX idx_users_email ON users(email);

-- After creating index: Check improved performance
EXPLAIN ANALYZE
SELECT * FROM users WHERE email = 'user@example.com';
-- Compare execution time and verify "Index Scan" is used
```

### Query Performance Tips

#### General Optimization Tips

1. **Use WHERE clauses to filter early:**
```sql
-- Good: Filter first
SELECT * FROM orders
WHERE created_at > '2024-01-01' AND status = 'pending';

-- Bad: Filter after selecting all
SELECT * FROM orders WHERE status IN (
    SELECT status FROM order_statuses WHERE active = true
);
-- Better:
SELECT o.* FROM orders o
JOIN order_statuses s ON o.status = s.status
WHERE s.active = true;
```

2. **Avoid SELECT * in production code:**
```sql
-- Bad: Retrieves unnecessary columns
SELECT * FROM users WHERE id = 123;

-- Good: Select only needed columns
SELECT id, name, email FROM users WHERE id = 123;
```

3. **Use appropriate JOIN types:**
```sql
-- INNER JOIN: Only matching rows
SELECT u.name, o.total FROM users u
INNER JOIN orders o ON u.id = o.user_id;

-- LEFT JOIN: All users, even without orders
SELECT u.name, o.total FROM users u
LEFT JOIN orders o ON u.id = o.user_id;

-- Avoid: Using WHERE instead of JOIN conditions
-- Bad
SELECT u.name, o.total FROM users u, orders o
WHERE u.id = o.user_id;

-- Good
SELECT u.name, o.total FROM users u
INNER JOIN orders o ON u.id = o.user_id;
```

4. **Use LIMIT for large result sets:**
```sql
-- Good: Limit results for pagination
SELECT * FROM orders ORDER BY created_at DESC LIMIT 100 OFFSET 0;

-- Use prepared statements for repeated queries (prevents plan cache pollution)
PREPARE get_user (int) AS SELECT * FROM users WHERE id = $1;
EXECUTE get_user(123);
DEALLOCATE get_user;
```

5. **Avoid N+1 query problems:**
```sql
-- Bad: N+1 queries
-- SELECT * FROM users;
-- Then for each user: SELECT * FROM orders WHERE user_id = ?

-- Good: Single query with JOIN
SELECT u.*, o.* FROM users u
LEFT JOIN orders o ON u.id = o.user_id;
```

## Performance Monitoring

### pg_stat_statements

**pg_stat_statements** tracks execution statistics for all SQL statements. Essential for identifying slow queries.

#### Enabling pg_stat_statements

```sql
-- Check if enabled
SELECT * FROM pg_extension WHERE extname = 'pg_stat_statements';

-- Enable extension
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Verify it's working
SELECT count(*) FROM pg_stat_statements;
```

#### Finding Slow Queries

```sql
-- Top 10 slowest queries by total time
SELECT
    substring(query, 1, 100) as short_query,
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time,
    stddev_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Top 10 slowest queries by average time
SELECT
    substring(query, 1, 100) as short_query,
    calls,
    round(mean_exec_time::numeric, 2) as avg_ms,
    round(total_exec_time::numeric, 2) as total_ms
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Most frequently called queries
SELECT
    substring(query, 1, 100) as short_query,
    calls,
    round(mean_exec_time::numeric, 2) as avg_ms
FROM pg_stat_statements
ORDER BY calls DESC
LIMIT 10;
```

#### Queries with Most I/O

```sql
-- Queries with highest disk reads
SELECT
    substring(query, 1, 100) as short_query,
    calls,
    shared_blks_read,
    shared_blks_hit,
    round(100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0), 2) as hit_ratio
FROM pg_stat_statements
WHERE shared_blks_read > 0
ORDER BY shared_blks_read DESC
LIMIT 10;
```

#### Resetting Statistics

```sql
-- Reset pg_stat_statements (start fresh)
SELECT pg_stat_statements_reset();
```

### pg_stat_activity

**pg_stat_activity** shows currently executing queries in real-time.

#### Current Running Queries

```sql
-- Show all active queries
SELECT
    pid,
    usename,
    datname,
    state,
    query_start,
    NOW() - query_start as duration,
    query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;

-- Show long-running queries (> 5 minutes)
SELECT
    pid,
    usename,
    datname,
    NOW() - query_start as duration,
    query
FROM pg_stat_activity
WHERE state != 'idle'
  AND NOW() - query_start > INTERVAL '5 minutes'
ORDER BY query_start;

-- Show queries waiting on locks
SELECT
    pid,
    usename,
    wait_event_type,
    wait_event,
    state,
    query
FROM pg_stat_activity
WHERE wait_event IS NOT NULL;
```

#### Blocking Queries

```sql
-- Show blocking and blocked queries
SELECT
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

### Connection Monitoring

#### Connection Pool Statistics

```sql
-- Current connections by database
SELECT
    datname,
    count(*) as total_connections,
    count(*) FILTER (WHERE state = 'active') as active,
    count(*) FILTER (WHERE state = 'idle') as idle,
    count(*) FILTER (WHERE state = 'idle in transaction') as idle_in_transaction
FROM pg_stat_activity
GROUP BY datname
ORDER BY total_connections DESC;

-- Connection limit status
SELECT
    datname,
    count(*) as current_connections,
    datconnlimit as max_connections,
    round(100.0 * count(*) / NULLIF(datconnlimit, -1), 2) as percent_used
FROM pg_stat_activity
JOIN pg_database ON pg_stat_activity.datname = pg_database.datname
WHERE datconnlimit != -1
GROUP BY pg_stat_activity.datname, datconnlimit
ORDER BY percent_used DESC;
```

### Slow Query Identification

#### Creating a Slow Query Log

```sql
-- Enable slow query logging (queries > 1 second)
-- Add to postgresql.conf:
-- log_min_duration_statement = 1000  # milliseconds
-- log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
-- log_statement = 'none'

-- Or set at runtime (requires superuser):
ALTER SYSTEM SET log_min_duration_statement = 1000;
SELECT pg_reload_conf();

-- View current setting
SHOW log_min_duration_statement;
```

#### Analyzing Slow Queries from Logs

```bash
# View PostgreSQL logs
docker exec dev-postgres tail -f /var/lib/postgresql/data/log/postgresql-*.log

# Extract slow queries (if log_min_duration_statement is set)
docker exec dev-postgres grep "duration:" /var/lib/postgresql/data/log/postgresql-*.log
```

### Resource Usage Monitoring

#### Table Size and Bloat

```sql
-- Show largest tables
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as indexes_size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;

-- Show cache hit ratio (should be > 99%)
SELECT
    sum(heap_blks_read) as heap_read,
    sum(heap_blks_hit)  as heap_hit,
    round(100.0 * sum(heap_blks_hit) / nullif(sum(heap_blks_hit) + sum(heap_blks_read), 0), 2) as cache_hit_ratio
FROM pg_statio_user_tables;
```

## Index Management

### Creating Indexes

#### Basic Index Creation

```sql
-- Create simple index
CREATE INDEX idx_users_email ON users(email);

-- Create unique index
CREATE UNIQUE INDEX idx_users_username ON users(username);

-- Create composite index (multi-column)
CREATE INDEX idx_orders_user_date ON orders(user_id, created_at);

-- Create partial index (filtered)
CREATE INDEX idx_orders_pending ON orders(created_at)
WHERE status = 'pending';

-- Create expression index
CREATE INDEX idx_users_lower_email ON users(LOWER(email));

-- Create index concurrently (non-blocking, safe for production)
CREATE INDEX CONCURRENTLY idx_products_category ON products(category);
```

**⚠️ WARNING:** Creating indexes locks the table. Use `CONCURRENTLY` for large tables in production.

#### Index Creation Best Practices

1. **Index columns used in WHERE clauses:**
```sql
-- Query: WHERE email = 'user@example.com'
CREATE INDEX idx_users_email ON users(email);

-- Query: WHERE status = 'pending' AND created_at > '2024-01-01'
CREATE INDEX idx_orders_status_date ON orders(status, created_at);
```

2. **Index foreign keys:**
```sql
-- For: JOIN orders o ON u.id = o.user_id
CREATE INDEX idx_orders_user_id ON orders(user_id);
```

3. **Index columns used in ORDER BY:**
```sql
-- For: ORDER BY created_at DESC
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
```

4. **Use partial indexes for frequent filtered queries:**
```sql
-- If you frequently query active users
CREATE INDEX idx_active_users ON users(last_login)
WHERE active = true;
```

### Index Types

PostgreSQL supports several index types. Choose based on your access patterns.

#### B-tree Indexes (Default)

Best for equality and range queries. Default index type.

```sql
-- B-tree index (default)
CREATE INDEX idx_users_created ON users(created_at);

-- Good for:
-- - WHERE id = 123
-- - WHERE created_at > '2024-01-01'
-- - WHERE created_at BETWEEN '2024-01-01' AND '2024-12-31'
-- - ORDER BY created_at
```

#### Hash Indexes

Best for equality comparisons only. Smaller than B-tree but limited.

```sql
-- Hash index
CREATE INDEX idx_users_email_hash ON users USING HASH (email);

-- Good for:
-- - WHERE email = 'user@example.com'
-- NOT good for:
-- - WHERE email LIKE '%example.com'
-- - ORDER BY email
```

#### GiST Indexes (Generalized Search Tree)

Best for geometric data, full-text search, and complex data types.

```sql
-- GiST index for full-text search
CREATE INDEX idx_documents_fts ON documents USING GIST (to_tsvector('english', content));

-- Good for:
-- - Full-text search
-- - Geometric queries
-- - Range types
```

#### GIN Indexes (Generalized Inverted Index)

Best for arrays, JSONB, and full-text search (faster than GiST).

```sql
-- GIN index for JSONB
CREATE INDEX idx_users_metadata ON users USING GIN (metadata);

-- GIN index for array
CREATE INDEX idx_posts_tags ON posts USING GIN (tags);

-- GIN index for full-text search
CREATE INDEX idx_documents_fts_gin ON documents USING GIN (to_tsvector('english', content));

-- Good for queries like:
-- - WHERE metadata @> '{"status": "active"}'::jsonb
-- - WHERE tags && ARRAY['postgresql', 'database']
-- - WHERE to_tsvector('english', content) @@ to_tsquery('postgresql & database')
```

#### BRIN Indexes (Block Range Index)

Best for very large tables with naturally ordered data (like timestamps).

```sql
-- BRIN index for time-series data
CREATE INDEX idx_logs_timestamp_brin ON logs USING BRIN (timestamp);

-- Good for:
-- - Very large tables (millions of rows)
-- - Naturally ordered columns (timestamps, IDs)
-- - Small index size
-- NOT good for:
-- - Randomly ordered data
```

### Index Maintenance

#### Rebuilding Indexes

Indexes can become bloated over time. Rebuild to reclaim space and improve performance.

```sql
-- Rebuild a single index (locks table)
REINDEX INDEX idx_users_email;

-- Rebuild all indexes on a table (locks table)
REINDEX TABLE users;

-- Rebuild all indexes in a database (locks database)
REINDEX DATABASE myapp;

-- Rebuild concurrently (PostgreSQL 12+, non-blocking)
REINDEX INDEX CONCURRENTLY idx_users_email;
```

**⚠️ WARNING:** `REINDEX` without `CONCURRENTLY` locks the table. Use `CONCURRENTLY` in production.

### Reindexing Operations

#### When to Reindex

1. **Index bloat:** Index size grows significantly
2. **Performance degradation:** Queries using index become slower
3. **After bulk operations:** After large INSERT/UPDATE/DELETE operations
4. **Corruption:** Index corruption (rare)

#### Checking Index Bloat

```sql
-- Estimate index bloat
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Index Usage Statistics

#### Monitoring Index Effectiveness

```sql
-- Show index usage for a table
SELECT
    indexname,
    idx_scan as scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE tablename = 'users'
ORDER BY idx_scan DESC;

-- Find duplicate indexes (same columns)
SELECT
    array_agg(indexname) as duplicate_indexes,
    tablename,
    array_agg(indexdef) as definitions
FROM pg_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
GROUP BY tablename, indexdef
HAVING count(*) > 1;
```

## Maintenance Operations

### VACUUM Operations

**VACUUM** reclaims storage occupied by dead tuples. Essential for PostgreSQL health.

#### Understanding VACUUM

PostgreSQL uses MVCC (Multi-Version Concurrency Control). When rows are updated or deleted, old versions become "dead tuples". VACUUM removes these.

```sql
-- Basic VACUUM (reclaims space, updates statistics)
VACUUM;

-- VACUUM a specific table
VACUUM users;

-- VACUUM FULL (rewrites entire table, reclaims maximum space)
-- ⚠️ WARNING: Locks table, takes exclusive lock
VACUUM FULL users;

-- VACUUM with ANALYZE (also updates statistics)
VACUUM ANALYZE users;

-- VACUUM VERBOSE (shows detailed progress)
VACUUM VERBOSE users;
```

#### When to VACUUM

1. **Automatic (autovacuum):** Runs automatically (default)
2. **Manual:** After large UPDATE/DELETE operations
3. **VACUUM FULL:** When table bloat is extreme (rare)

#### Monitoring VACUUM Activity

```sql
-- Check last vacuum/autovacuum times
SELECT
    schemaname,
    tablename,
    last_vacuum,
    last_autovacuum,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows,
    round(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) as dead_ratio
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- Show autovacuum settings
SHOW autovacuum;
SHOW autovacuum_vacuum_threshold;
SHOW autovacuum_vacuum_scale_factor;
```

### ANALYZE Operations

**ANALYZE** updates query planner statistics. Crucial for optimal query plans.

```sql
-- ANALYZE all tables
ANALYZE;

-- ANALYZE specific table
ANALYZE users;

-- ANALYZE specific columns
ANALYZE users (email, created_at);

-- ANALYZE VERBOSE (shows progress)
ANALYZE VERBOSE users;
```

#### When to ANALYZE

1. **After large data changes:** Bulk INSERT/UPDATE/DELETE
2. **After index creation:** Help planner use new indexes
3. **Periodic maintenance:** Weekly or monthly for stable tables

### Autovacuum Tuning

Autovacuum runs automatically but can be tuned for better performance.

#### Autovacuum Configuration

```sql
-- View current autovacuum settings
SHOW autovacuum;
SHOW autovacuum_naptime;
SHOW autovacuum_vacuum_threshold;
SHOW autovacuum_vacuum_scale_factor;
SHOW autovacuum_analyze_threshold;
SHOW autovacuum_analyze_scale_factor;

-- Default formula for autovacuum trigger:
-- vacuum threshold + vacuum scale factor * number of tuples
-- Example: 50 + 0.2 * 10000 = 2050 dead tuples triggers autovacuum
```

#### Tuning Autovacuum per Table

```sql
-- Make autovacuum more aggressive for a busy table
ALTER TABLE orders SET (
    autovacuum_vacuum_threshold = 100,
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_threshold = 100,
    autovacuum_analyze_scale_factor = 0.05
);

-- Disable autovacuum for a table (not recommended)
ALTER TABLE logs SET (autovacuum_enabled = false);

-- Reset to defaults
ALTER TABLE orders RESET (autovacuum_vacuum_threshold);
```

### Bloat Management

Database bloat occurs when tables and indexes grow larger than necessary.

#### Detecting Table Bloat

```sql
-- Estimate table bloat (approximate)
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    round(100 * pg_total_relation_size(schemaname||'.'||tablename) /
        NULLIF(pg_database_size(current_database()), 0), 2) as percent_of_db
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;
```

#### Fixing Bloat

```sql
-- Option 1: VACUUM FULL (locks table, requires 2x space)
VACUUM FULL users;

-- Option 2: CLUSTER (reorders table, locks table)
CLUSTER users USING idx_users_created;

-- Option 3: pg_repack (requires extension, non-blocking)
-- Install pg_repack extension first
-- Then: pg_repack -t users
```

### Table and Index Bloat Detection

```sql
-- Comprehensive bloat detection query
WITH constants AS (
    SELECT current_setting('block_size')::numeric AS bs
),
bloat AS (
    SELECT
        schemaname,
        tablename,
        pg_total_relation_size(schemaname||'.'||tablename) as total_bytes,
        pg_relation_size(schemaname||'.'||tablename) as table_bytes,
        pg_total_relation_size(schemaname||'.'||tablename) -
            pg_relation_size(schemaname||'.'||tablename) as index_bytes
    FROM pg_tables
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
)
SELECT
    schemaname,
    tablename,
    pg_size_pretty(total_bytes) as total_size,
    pg_size_pretty(table_bytes) as table_size,
    pg_size_pretty(index_bytes) as index_size,
    round(100.0 * index_bytes / NULLIF(total_bytes, 0), 2) as index_ratio
FROM bloat
ORDER BY total_bytes DESC
LIMIT 20;
```

## Backup Operations

### pg_dump Basic Usage

**pg_dump** creates logical backups of individual databases.

#### Basic Backup

```bash
# Backup database to file
docker exec dev-postgres pg_dump -U postgres myapp > myapp_backup.sql

# Backup with compression (gzip)
docker exec dev-postgres pg_dump -U postgres myapp | gzip > myapp_backup.sql.gz

# Backup with custom format (supports parallel restore)
docker exec dev-postgres pg_dump -U postgres -Fc myapp > myapp_backup.dump

# Backup specific tables
docker exec dev-postgres pg_dump -U postgres -t users -t orders myapp > tables_backup.sql
```

#### Advanced Backup Options

```bash
# Backup with verbose output
docker exec dev-postgres pg_dump -U postgres -v myapp > myapp_backup.sql

# Backup schema only (no data)
docker exec dev-postgres pg_dump -U postgres -s myapp > myapp_schema.sql

# Backup data only (no schema)
docker exec dev-postgres pg_dump -U postgres -a myapp > myapp_data.sql

# Backup excluding specific tables
docker exec dev-postgres pg_dump -U postgres --exclude-table=logs myapp > myapp_backup.sql

# Backup with directory format (parallel dump)
docker exec dev-postgres pg_dump -U postgres -Fd -j 4 myapp -f /tmp/myapp_backup
```

### pg_dumpall for Full Backups

**pg_dumpall** backs up all databases, roles, and tablespaces.

```bash
# Full cluster backup (all databases)
docker exec dev-postgres pg_dumpall -U postgres > full_backup.sql

# Backup only roles and tablespaces
docker exec dev-postgres pg_dumpall -U postgres --roles-only > roles_backup.sql
docker exec dev-postgres pg_dumpall -U postgres --tablespaces-only > tablespaces_backup.sql

# Backup globals (roles, tablespaces) + specific database
docker exec dev-postgres pg_dumpall -U postgres --globals-only > globals_backup.sql
docker exec dev-postgres pg_dump -U postgres myapp > myapp_backup.sql
```

### Backup Best Practices

#### Automated Backup Script

```bash
#!/bin/bash
# Save as: /Users/gator/devstack-core/scripts/backup-postgres.sh

BACKUP_DIR="/Users/gator/devstack-core/backups/postgres"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup all databases
docker exec dev-postgres pg_dumpall -U postgres | gzip > "$BACKUP_DIR/full_backup_$DATE.sql.gz"

# Backup specific databases
for DB in myapp forgejo; do
    docker exec dev-postgres pg_dump -U postgres -Fc "$DB" > "$BACKUP_DIR/${DB}_backup_$DATE.dump"
done

# Remove old backups
find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $DATE"
```

#### Restore from Backup

```bash
# Restore from SQL file
docker exec -i dev-postgres psql -U postgres < myapp_backup.sql

# Restore from gzipped SQL file
gunzip -c myapp_backup.sql.gz | docker exec -i dev-postgres psql -U postgres

# Restore from custom format
docker exec dev-postgres pg_restore -U postgres -d myapp myapp_backup.dump

# Restore with parallel jobs
docker exec dev-postgres pg_restore -U postgres -j 4 -d myapp myapp_backup.dump

# Restore specific table
docker exec dev-postgres pg_restore -U postgres -d myapp -t users myapp_backup.dump
```

**⚠️ WARNING:** Restoring drops existing data. Always backup before restore.

### Point-in-Time Recovery Preparation

Point-in-Time Recovery (PITR) allows restoring database to specific timestamp.

#### Enabling WAL Archiving

```sql
-- Add to postgresql.conf:
-- wal_level = replica
-- archive_mode = on
-- archive_command = 'test ! -f /var/lib/postgresql/wal_archive/%f && cp %p /var/lib/postgresql/wal_archive/%f'
-- max_wal_senders = 3
-- wal_keep_size = 1024MB

-- Or set at runtime (requires restart):
ALTER SYSTEM SET wal_level = replica;
ALTER SYSTEM SET archive_mode = on;
ALTER SYSTEM SET archive_command = 'test ! -f /var/lib/postgresql/wal_archive/%f && cp %p /var/lib/postgresql/wal_archive/%f';
SELECT pg_reload_conf();
-- Restart PostgreSQL for wal_level change
```

#### Creating Base Backup for PITR

```bash
# Create base backup
docker exec dev-postgres pg_basebackup -U postgres -D /tmp/base_backup -Ft -z -P

# WAL files will be archived to /var/lib/postgresql/wal_archive/
```

#### Performing Point-in-Time Recovery

See [Disaster Recovery](Disaster-Recovery) for complete PITR restoration procedures.

## Troubleshooting

### Connection Issues

#### Cannot Connect to PostgreSQL

```bash
# Check if PostgreSQL is running
docker ps | grep dev-postgres

# Check PostgreSQL logs
docker logs dev-postgres --tail 100

# Check if PostgreSQL is accepting connections
docker exec dev-postgres pg_isready -U postgres

# Test connection from inside container
docker exec -it dev-postgres psql -U postgres -c "SELECT 1;"

# Test connection from host
psql -h localhost -p 5432 -U postgres -c "SELECT 1;"
```

#### Connection Refused Errors

```bash
# Check if port 5432 is listening
docker exec dev-postgres netstat -tlnp | grep 5432

# Check PostgreSQL configuration
docker exec dev-postgres cat /var/lib/postgresql/data/postgresql.conf | grep listen_addresses
# Should be: listen_addresses = '*'

# Check pg_hba.conf (client authentication)
docker exec dev-postgres cat /var/lib/postgresql/data/pg_hba.conf
# Should include: host all all 0.0.0.0/0 md5
```

#### Too Many Connections

```sql
-- Check current connection count
SELECT count(*) FROM pg_stat_activity;

-- Show max connections
SHOW max_connections;

-- Terminate idle connections
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle' AND state_change < NOW() - INTERVAL '1 hour';

-- Increase max connections (requires restart)
ALTER SYSTEM SET max_connections = 200;
-- Restart PostgreSQL
```

### Lock Contention

#### Identifying Lock Contention

```sql
-- Show current locks
SELECT
    locktype,
    database,
    relation::regclass,
    page,
    tuple,
    virtualxid,
    transactionid,
    mode,
    granted,
    pid
FROM pg_locks
WHERE NOT granted;

-- Show blocking queries (detailed)
SELECT
    blocked_activity.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_activity.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_query,
    blocking_activity.query AS blocking_query,
    blocked_activity.state AS blocked_state,
    blocking_activity.state AS blocking_state
FROM pg_stat_activity AS blocked_activity
JOIN pg_stat_activity AS blocking_activity
    ON blocking_activity.pid = ANY(pg_blocking_pids(blocked_activity.pid))
WHERE blocked_activity.pid != blocking_activity.pid;
```

#### Resolving Lock Contention

```sql
-- Kill blocking query (use blocking_pid from above)
SELECT pg_terminate_backend(12345);

-- Cancel running query (less aggressive than terminate)
SELECT pg_cancel_backend(12345);
```

### Performance Problems

#### Slow Query Performance

```sql
-- Enable query timing
\timing on

-- Run problematic query with EXPLAIN ANALYZE
EXPLAIN ANALYZE
SELECT * FROM orders WHERE user_id = 123;

-- Check for missing indexes
-- If you see "Seq Scan", create index:
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders(user_id);

-- Update table statistics
ANALYZE orders;

-- Check for table bloat and vacuum if needed
VACUUM ANALYZE orders;
```

#### High CPU Usage

```sql
-- Find CPU-intensive queries
SELECT
    pid,
    usename,
    datname,
    state,
    query_start,
    NOW() - query_start as duration,
    query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY query_start;

-- Check for autovacuum issues
SELECT * FROM pg_stat_activity WHERE query LIKE '%autovacuum%';
```

#### High Memory Usage

```sql
-- Check work_mem setting
SHOW work_mem;

-- Check shared_buffers
SHOW shared_buffers;

-- Find queries with large sorts
SELECT
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time
FROM pg_stat_statements
WHERE query LIKE '%ORDER BY%' OR query LIKE '%GROUP BY%'
ORDER BY mean_exec_time DESC
LIMIT 10;
```

### Disk Space Issues

#### Checking Disk Usage

```bash
# Check container disk usage
docker exec dev-postgres df -h

# Check PostgreSQL data directory size
docker exec dev-postgres du -sh /var/lib/postgresql/data

# Check individual database sizes
docker exec dev-postgres psql -U postgres -c "
SELECT
    datname,
    pg_size_pretty(pg_database_size(datname)) as size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;
"
```

#### Reclaiming Disk Space

```sql
-- Find largest tables
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;

-- VACUUM FULL to reclaim space (locks table)
VACUUM FULL large_table;

-- Drop old partitions if using table partitioning
DROP TABLE logs_2023_01;

-- Truncate log tables
TRUNCATE TABLE application_logs;
```

### Replication Lag

If you set up replication (standby server), monitor replication lag.

```sql
-- On primary: Check replication status
SELECT
    client_addr,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    sync_state
FROM pg_stat_replication;

-- On standby: Check replication lag
SELECT
    NOW() - pg_last_xact_replay_timestamp() AS replication_lag;
```

## Configuration Tuning

### Memory Settings

```sql
-- View current memory settings
SHOW shared_buffers;      -- Total shared memory cache
SHOW work_mem;            -- Memory per sort/hash operation
SHOW maintenance_work_mem; -- Memory for VACUUM, CREATE INDEX
SHOW effective_cache_size; -- OS + PostgreSQL cache estimate

-- Recommended settings for development (adjust for production):
-- shared_buffers = 256MB       (25% of RAM)
-- work_mem = 4MB               (per operation, start small)
-- maintenance_work_mem = 64MB  (for VACUUM, indexes)
-- effective_cache_size = 1GB   (50-75% of RAM)

-- Set at runtime (session only):
SET work_mem = '16MB';

-- Set permanently (requires restart for shared_buffers):
ALTER SYSTEM SET shared_buffers = '512MB';
ALTER SYSTEM SET work_mem = '8MB';
ALTER SYSTEM SET maintenance_work_mem = '128MB';
SELECT pg_reload_conf();
```

### Connection Settings

```sql
-- View connection settings
SHOW max_connections;
SHOW superuser_reserved_connections;

-- Set max connections (requires restart)
ALTER SYSTEM SET max_connections = 200;
-- Restart PostgreSQL

-- Connection pooling recommended: Use PgBouncer
-- See: PgBouncer-Usage wiki page
```

### Write-Ahead Log Settings

```sql
-- View WAL settings
SHOW wal_level;
SHOW max_wal_size;
SHOW min_wal_size;
SHOW checkpoint_timeout;

-- Tune WAL for better performance
ALTER SYSTEM SET max_wal_size = '2GB';
ALTER SYSTEM SET min_wal_size = '1GB';
ALTER SYSTEM SET checkpoint_timeout = '15min';
SELECT pg_reload_conf();
```

### Query Planner Settings

```sql
-- View planner settings
SHOW random_page_cost;    -- Cost of non-sequential page fetch
SHOW effective_io_concurrency; -- Number of concurrent I/O operations

-- Tune for SSD (lower random_page_cost)
ALTER SYSTEM SET random_page_cost = 1.1;  -- Default: 4.0
ALTER SYSTEM SET effective_io_concurrency = 200;  -- Default: 1
SELECT pg_reload_conf();
```

## Security Operations

### Role-Based Access Control

```sql
-- Create role (group)
CREATE ROLE readonly;
CREATE ROLE readwrite;

-- Grant privileges to role
GRANT CONNECT ON DATABASE myapp TO readonly;
GRANT USAGE ON SCHEMA public TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;

-- Create user and assign to role
CREATE USER app_user WITH PASSWORD 'secure_password';
GRANT readonly TO app_user;

-- Revoke privileges
REVOKE SELECT ON ALL TABLES IN SCHEMA public FROM readonly;
```

### SSL/TLS Configuration

```sql
-- Check if SSL is enabled
SHOW ssl;

-- Check SSL connections
SELECT
    datname,
    usename,
    client_addr,
    ssl,
    ssl_cipher
FROM pg_stat_ssl
JOIN pg_stat_activity USING (pid);
```

### Password Policies

```sql
-- Set password expiration
ALTER USER myapp_user VALID UNTIL '2026-01-01';

-- Require password change on next login (use application logic)
-- PostgreSQL doesn't have built-in password expiry enforcement

-- Set connection limit
ALTER USER myapp_user CONNECTION LIMIT 10;
```

### Audit Logging

```sql
-- Enable query logging (postgresql.conf)
-- log_statement = 'all'  # Log all statements
-- log_statement = 'ddl'  # Log DDL only
-- log_statement = 'mod'  # Log modifications (INSERT/UPDATE/DELETE)

-- Set at runtime
ALTER SYSTEM SET log_statement = 'ddl';
SELECT pg_reload_conf();

-- View current setting
SHOW log_statement;
```

## Reference

### Related Wiki Pages

- [PgBouncer Usage](PgBouncer-Usage) - Connection pooling configuration
- [Service Configuration](Service-Configuration) - PostgreSQL service details
- [Service Overview](Service-Overview) - Architecture overview
- [Backup and Restore](Backup-and-Restore) - Comprehensive backup guide
- [Performance Tuning](Performance-Tuning) - Advanced performance optimization
- [Disaster Recovery](Disaster-Recovery) - Recovery procedures
- [Health Monitoring](Health-Monitoring) - Monitoring and alerting

### Useful Commands Quick Reference

```bash
# Connect to PostgreSQL
docker exec -it dev-postgres psql -U postgres

# Run SQL command
docker exec dev-postgres psql -U postgres -c "SELECT version();"

# Backup database
docker exec dev-postgres pg_dump -U postgres myapp > backup.sql

# Restore database
docker exec -i dev-postgres psql -U postgres myapp < backup.sql

# Check if PostgreSQL is ready
docker exec dev-postgres pg_isready -U postgres

# View logs
docker logs dev-postgres --tail 100 -f

# Restart PostgreSQL
docker restart dev-postgres
```

### PostgreSQL System Catalogs

```sql
-- List all databases
SELECT * FROM pg_database;

-- List all tables
SELECT * FROM pg_tables WHERE schemaname = 'public';

-- List all indexes
SELECT * FROM pg_indexes WHERE schemaname = 'public';

-- List all users
SELECT * FROM pg_user;

-- List all roles
SELECT * FROM pg_roles;

-- Show table columns
SELECT * FROM information_schema.columns WHERE table_name = 'users';
```

### Important PostgreSQL Files

- **Configuration:** `/var/lib/postgresql/data/postgresql.conf`
- **Client Auth:** `/var/lib/postgresql/data/pg_hba.conf`
- **Data Directory:** `/var/lib/postgresql/data/`
- **Logs:** `/var/lib/postgresql/data/log/` (if logging enabled)
- **WAL Archive:** `/var/lib/postgresql/wal_archive/` (if configured)

### Additional Resources

- [Official PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [PostgreSQL Wiki](https://wiki.postgresql.org/)
- [pg_stat_statements Documentation](https://www.postgresql.org/docs/current/pgstatstatements.html)
- [EXPLAIN Documentation](https://www.postgresql.org/docs/current/using-explain.html)
