-- ===========================================================================
-- PostgreSQL 18 Compatibility Schema for Vector Metrics
-- ===========================================================================
--
-- This script creates a compatibility layer for monitoring tools that expect
-- the pre-PostgreSQL 17 pg_stat_bgwriter structure with checkpoint columns.
--
-- In PostgreSQL 17+, checkpoint statistics were moved from pg_stat_bgwriter
-- to a new pg_stat_checkpointer view, and column names were changed:
--   - checkpoints_timed    → num_timed
--   - checkpoints_req      → num_requested
--   - checkpoint_write_time → write_time
--   - checkpoint_sync_time  → sync_time
--   - buffers_checkpoint    → buffers_written
--
-- Strategy: Create a "compat" schema with a view named pg_stat_bgwriter
-- that includes the old columns. By placing "compat" first in search_path,
-- queries for pg_stat_bgwriter will find our compatibility view instead of
-- the system view.
--
-- When Vector adds native PostgreSQL 18 support, this can be removed.
-- ===========================================================================

-- Create compatibility schema
CREATE SCHEMA IF NOT EXISTS compat;

-- Create compatibility view with the old structure and column names
CREATE OR REPLACE VIEW compat.pg_stat_bgwriter AS
SELECT
    -- Original bgwriter columns (still present in PG 18)
    b.buffers_clean,
    b.maxwritten_clean,
    b.buffers_alloc,

    -- Checkpoint columns from pg_stat_checkpointer mapped to old names
    c.num_timed AS checkpoints_timed,
    c.num_requested AS checkpoints_req,
    c.write_time AS checkpoint_write_time,
    c.sync_time AS checkpoint_sync_time,
    c.buffers_written AS buffers_checkpoint,

    -- Backend buffer writes (from pg_stat_io - sum across all backend types)
    -- In PG 17+, buffer I/O stats moved to pg_stat_io
    -- Cast to bigint to match Vector's expectations (SUM returns numeric)
    COALESCE((SELECT SUM(writes)::bigint FROM pg_catalog.pg_stat_io WHERE backend_type LIKE '%backend%'), 0) AS buffers_backend,

    -- FSM writes (File Space Map - now in pg_stat_io)
    COALESCE((SELECT SUM(writes)::bigint FROM pg_catalog.pg_stat_io WHERE context = 'fsm'), 0) AS buffers_backend_fsync,

    -- Use the later stats_reset timestamp
    GREATEST(b.stats_reset, c.stats_reset) AS stats_reset
FROM
    pg_catalog.pg_stat_bgwriter b,
    pg_catalog.pg_stat_checkpointer c;

-- Set search path to check compat schema before pg_catalog
-- This makes our compatibility view take precedence
ALTER DATABASE dev_database SET search_path TO compat, pg_catalog, public;

COMMENT ON SCHEMA compat IS
'Compatibility schema for PostgreSQL 18+ that provides backward-compatible views for monitoring tools.';

COMMENT ON VIEW compat.pg_stat_bgwriter IS
'Compatibility view that recreates the pre-PG17 pg_stat_bgwriter structure with checkpoint columns from pg_stat_checkpointer.';
