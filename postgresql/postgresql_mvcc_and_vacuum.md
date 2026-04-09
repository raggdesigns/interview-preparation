# PostgreSQL MVCC and VACUUM

**Interview framing:**

"MVCC — multi-version concurrency control — is the mechanism PostgreSQL uses to let readers and writers operate on the same data without blocking each other. The implementation choice PostgreSQL made is that every update creates a new row version in the same table, leaving the old version for concurrent readers. This gives you great concurrency but comes with a specific operational concern: those old row versions accumulate as 'dead tuples', and a background process called VACUUM has to clean them up. Every senior PostgreSQL conversation eventually touches VACUUM because that's where the interesting operational issues live — bloat, autovacuum tuning, long-running transactions blocking cleanup, and the transaction ID wraparound problem."

### The MVCC model in one paragraph

When a transaction updates a row, PostgreSQL doesn't modify the existing row in place. It writes a new version of the row with the new values, marks the old version as no longer current (with the updating transaction ID), and leaves the old version physically present in the table. Concurrent transactions that started before the update still see the old version; transactions that start after see the new version. The old version — a "dead tuple" — stays until VACUUM removes it.

This is the shape that separates PostgreSQL from MySQL's InnoDB, which uses an undo log instead. Both achieve MVCC; the mechanisms are different.

### Transaction visibility

Every row in PostgreSQL has two hidden columns:

- **`xmin`** — the transaction that created this row version.
- **`xmax`** — the transaction that deleted this row version (0 if still current).

Every transaction has a snapshot: a list of transaction IDs that were in-flight when the transaction started. A row version is visible to a transaction if:

- Its `xmin` is committed and ≤ the transaction's snapshot start.
- Its `xmax` is either 0 (not deleted) or a transaction that's still in-flight or committed *after* the snapshot.

This rule lets each transaction see a consistent view of the database without ever locking another transaction out.

### Dead tuples

A row version becomes "dead" when no running transaction can still see it. Specifically:

- **Deleted rows** — after the delete commits and any older snapshots are done.
- **Updated rows (the old version)** — after the update commits and any older snapshots are done.
- **Rolled-back inserts** — their row versions are dead immediately.

Dead tuples take up space in the table but are invisible to queries. Over time, they accumulate. A table with heavy update traffic can have 50% or more of its physical space consumed by dead tuples if VACUUM can't keep up. This is called **bloat**.

### VACUUM — the cleanup process

VACUUM is the background process that removes dead tuples and returns the space for reuse. It does several things:

1. **Removes dead tuples.** Marks the space as free for new inserts.
2. **Updates the visibility map.** Marks pages where all tuples are visible to everyone — this enables index-only scans.
3. **Updates statistics.** Helps the query planner make good decisions.
4. **Prevents transaction ID wraparound.** (See below.)

**Two flavors:**

- **`VACUUM`** (non-blocking) — removes dead tuples, frees space for reuse *within* the table. Does not return space to the OS. The table stays the same size; new rows can fill the freed slots.
- **`VACUUM FULL`** — rewrites the entire table, returning space to the OS. **Blocks reads and writes for the duration.** Basically never used on production tables because of the downtime; tools like `pg_repack` do the same job without blocking.

Regular VACUUM is what you want. VACUUM FULL is a last-resort cleanup for severely bloated tables and should be replaced with `pg_repack` in production.

### Autovacuum — the background process

PostgreSQL runs an **autovacuum** daemon that periodically VACUUMs tables based on dead-tuple thresholds. You don't manually run VACUUM in normal operation; autovacuum handles it.

The default thresholds:

- **Vacuum when dead tuples > 20% of the table.**
- **Analyze when 10% of rows have changed.**

These defaults are fine for small and moderate tables but too lazy for large ones. A 100 GB table with 20% dead tuples is 20 GB of wasted space before autovacuum kicks in. For large tables, you tune the thresholds down.

```sql
ALTER TABLE big_table SET (
  autovacuum_vacuum_scale_factor = 0.02,  -- vacuum at 2% dead tuples
  autovacuum_analyze_scale_factor = 0.01
);
```

**Autovacuum workers** — autovacuum runs with a configurable number of parallel workers. The default is 3, which is often not enough for large schemas with many busy tables. Bumping it to 5-10 is normal.

**Cost limits** — autovacuum is designed to be unobtrusive, which means it's throttled. On large tables, the default cost limits cause autovacuum to run forever without finishing. Tuning `autovacuum_vacuum_cost_limit` and `autovacuum_vacuum_cost_delay` is standard for busy databases.

### Bloat — the silent performance killer

Bloat is the accumulation of dead tuples that VACUUM hasn't reclaimed. The symptoms:

- **Tables much larger than their row count suggests.**
- **Slow sequential scans** because the scan has to walk through dead tuples.
- **Slow index scans** because index pages also accumulate dead entries.
- **Higher I/O load** because the working set no longer fits in cache.
- **Slower queries across the board**, sometimes dramatically.

**Causes of bloat:**

- **Autovacuum not running often enough.** Usually a tuning problem.
- **Long-running transactions** preventing VACUUM from cleaning up rows newer than their snapshot. The classic cause.
- **Prepared transactions left hanging.** Same mechanism.
- **Replication slots** that aren't being consumed — the slot holds back VACUUM to preserve WAL for the consumer.
- **Massive updates or deletes in a single transaction**, overwhelming autovacuum.

**Detecting bloat:**

```sql
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
  n_dead_tup,
  n_live_tup,
  round(100 * n_dead_tup::numeric / nullif(n_live_tup + n_dead_tup, 0), 2) AS dead_pct
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY dead_pct DESC;
```

A table with 40%+ dead tuples is a bloat problem that needs attention.

**Fixing bloat:**

- **`VACUUM FULL`** — blocks the table. Don't do it in production.
- **`pg_repack`** — rebuilds the table concurrently. Standard tool for production bloat cleanup.
- **Fix the root cause** — long-running transactions, autovacuum tuning, replication slots.

### The long-running transaction problem

A transaction that stays open for hours holds a snapshot at its start time. As long as that snapshot exists, no row that was visible at snapshot time can be cleaned up — because the old transaction might still want to read it.

**Symptoms:**

- Autovacuum runs but reports "oldest xmin" very old.
- Dead tuples accumulate across all tables, not just one.
- Table and index sizes grow relentlessly.
- `pg_stat_activity` shows a transaction that's been idle or running for hours.

**The fix:** find the transaction and kill it.

```sql
SELECT
  pid,
  now() - xact_start AS age,
  state,
  query
FROM pg_stat_activity
WHERE state != 'idle'
  AND xact_start IS NOT NULL
ORDER BY xact_start;
```

Common culprits:

- **Application code that opens a transaction, does work, and forgets to commit.**
- **BEGIN; ... walked away.** A manual DBA session left open.
- **Idle-in-transaction connections.** Connection pools that keep connections open with active transactions.
- **Reporting queries on read replicas** that run for hours with `hot_standby_feedback=on`, which holds back VACUUM on the primary.

**Prevention:**

- **`idle_in_transaction_session_timeout`** — Postgres will kill connections that sit idle in a transaction beyond this timeout. Set to something reasonable (minutes, not hours).
- **Application-level transaction discipline** — don't hold transactions open across user interactions or external API calls.
- **Monitoring** — alert on long-running transactions.

### HOT updates — the optimization

A "HOT" update (heap-only tuple) is PostgreSQL's optimization for updates that don't change any indexed columns. In a HOT update:

- The new row version lives in the same page as the old one.
- Indexes don't need to be updated (they still point to the old position, and a forwarding chain leads to the new version).
- When the old version is eventually vacuumed, the HOT chain collapses.

HOT updates are dramatically faster and cause less bloat. You want HOT updates as often as possible.

**HOT requires:**

1. The new version must fit in the same page as the old one (fillfactor matters).
2. No indexed column can change.

**Tuning for HOT:**

- **`FILLFACTOR`** — the percentage of each page to fill on initial insert. Default 100. Lowering to 80-90 leaves room for HOT updates on frequently-updated tables.
- **Indexes** — extra indexes on frequently-updated columns prevent HOT. Be deliberate about what you index.

### Transaction ID wraparound — the scary one

PostgreSQL's transaction IDs are 32-bit integers. After ~4 billion transactions, they wrap around. Because visibility is determined by comparing transaction IDs, a wrap-around could make old rows suddenly appear as from the future and become invisible — which would look like data loss.

PostgreSQL prevents this with a mechanism called **freezing**: rows older than a certain age have their `xmin` replaced with a special "frozen" marker that's visible to all future transactions. VACUUM does this as part of its work.

**The failure mode:** if VACUUM can't keep up with the rate of new transactions, the oldest un-frozen transaction ID approaches the wraparound limit. PostgreSQL responds with:

- **At 200 million transactions until wraparound:** warnings in the logs.
- **At 40 million:** aggressive autovacuum kicks in.
- **At 11 million:** refuses new transactions ("to prevent data corruption").
- **At 1 million:** refuses connections from everyone except superusers.

This is the "**Postgres is down and won't let us connect**" scenario that makes DBAs wake up in cold sweat. It's rare but catastrophic when it happens, and the fix is running VACUUM (possibly on many tables) to advance the oldest xmin.

**Modern PostgreSQL has better tools** to monitor and prevent this (`pg_stat_database.datfrozenxid` age, warnings before hitting limits), but it's still possible to hit if autovacuum is badly misconfigured or if long transactions run for days at a time.

### VACUUM and indexes

VACUUM also cleans up indexes. Dead index entries are visited, their pointers are verified as dead, and their space is freed.

**Index bloat** is its own concern. Indexes can become bloated even when the underlying table doesn't, particularly B-tree indexes with specific access patterns (monotonically increasing keys with frequent deletes from the middle). Index bloat is fixed with `REINDEX` or `REINDEX CONCURRENTLY` (PG12+).

```sql
REINDEX INDEX CONCURRENTLY idx_orders_user_id;
```

`CONCURRENTLY` is the production-safe version.

### Monitoring VACUUM health

Key metrics to watch:

- **`n_dead_tup` per table.** High numbers mean autovacuum isn't keeping up.
- **`last_autovacuum`** and **`last_autoanalyze`** per table. Tables that haven't been vacuumed in days need attention.
- **`autovacuum_worker_count`** — if it's at the max, you need more workers.
- **Oldest xmin age** (`age(datfrozenxid)` in `pg_database`) — should be well under 200 million.
- **Long-running transactions** (from `pg_stat_activity`).

The standard Prometheus exporter for PostgreSQL exposes all of these; they should be on every Postgres dashboard.

> **Mid-level answer stops here.** A mid-level dev can describe VACUUM. To sound senior, speak to the operational concerns — autovacuum tuning, bloat detection, long-running transaction prevention, and the TXID wraparound failure mode ↓
>
> **Senior signal:** treating VACUUM as a production concern with its own monitoring, tuning, and failure modes.

### The tuning playbook for busy databases

1. **Raise autovacuum worker count.** Default 3; often bump to 5-10.
2. **Lower scale factors on large tables.** 2-5% instead of 20%.
3. **Raise cost limits.** Let autovacuum do real work instead of constantly throttling.
4. **Monitor `n_dead_tup` per table.** Alert on bloat.
5. **Set `idle_in_transaction_session_timeout`.** Kill forgotten transactions.
6. **Monitor long-running transactions.** Alert if anything runs more than a few minutes.
7. **Use `pg_repack` for bloat cleanup.** Never `VACUUM FULL` in production.
8. **Watch `age(datfrozenxid)`.** Alert well before 200 million.
9. **Use `FILLFACTOR` on frequently-updated tables** to enable HOT updates.
10. **Minimize indexes on frequently-updated columns** to enable HOT.

### Common mistakes

- **Running `VACUUM FULL` in production.** Blocks the table for potentially hours.
- **Assuming autovacuum defaults are correct at scale.** They're not.
- **Ignoring long-running transactions.** They cause cascading bloat.
- **Not monitoring bloat.** Silent performance degradation.
- **Replication slots left open.** Holds back VACUUM on the primary.
- **`hot_standby_feedback=on` without thinking about it.** Standby queries can block primary VACUUM.
- **Indexing everything.** Kills HOT update optimization.
- **Not monitoring transaction ID age.** The wraparound surprise.

### Closing

"So MVCC in PostgreSQL means every update leaves a dead tuple behind, VACUUM cleans them up, autovacuum runs VACUUM automatically, and the operational concerns are bloat, long-running transactions blocking cleanup, and the distant but catastrophic transaction ID wraparound. The tuning playbook is about making autovacuum work hard enough on busy databases — more workers, lower thresholds, higher cost limits — and making sure nothing prevents cleanup. Combined with HOT updates for frequently-updated tables and `pg_repack` for emergency bloat cleanup, a well-tuned Postgres handles very busy workloads. A poorly-tuned one quietly bloats until one day it's inexplicably slow."
