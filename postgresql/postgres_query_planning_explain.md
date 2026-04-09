# Query planning and EXPLAIN

**Interview framing:**

"The PostgreSQL query planner is one of the best in the open-source world, but using it effectively means knowing how to read EXPLAIN output. The difference between 'this query is slow' and 'this query uses a sequential scan because the planner thinks the table is tiny, but my statistics are stale and the table is 40 GB' is the difference between guessing and knowing. Every senior PostgreSQL interview touches EXPLAIN at some point, because it's the single most valuable diagnostic tool — and reading it well is a learned skill, not an innate one."

### The query planner's job

When you send a query, PostgreSQL parses it, then the **planner** (also called the optimizer) considers many possible ways to execute it and picks the cheapest. For a simple query on one table, there might be only a few options. For a join between three tables with a filter and a sort, there can be hundreds.

The planner estimates cost for each plan based on:
- **Statistics** about the tables (row counts, value distributions, null fractions).
- **Cost model parameters** (I/O cost, CPU cost, random-vs-sequential access).
- **Index information** — which indexes exist and their selectivity.

It picks the plan with the lowest estimated total cost. **Estimated**, not actual — the planner is making educated guesses based on statistics, and when the statistics are wrong, so is the plan.

### EXPLAIN and EXPLAIN ANALYZE

```sql
EXPLAIN SELECT * FROM orders WHERE user_id = 42;
```

Returns the plan the planner *would* use, with estimated costs. The query is not executed.

```sql
EXPLAIN ANALYZE SELECT * FROM orders WHERE user_id = 42;
```

Actually executes the query and returns both estimates and actual measurements. This is what you use for real diagnosis.

**Important:** `EXPLAIN ANALYZE` runs the query. If the query modifies data (INSERT, UPDATE, DELETE), it actually modifies it. Wrap in a rolled-back transaction if you want to test mutations safely:

```sql
BEGIN;
EXPLAIN ANALYZE UPDATE orders SET status = 'shipped' WHERE id = 42;
ROLLBACK;
```

### The most useful EXPLAIN options

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS, FORMAT text)
SELECT * FROM orders WHERE user_id = 42;
```

- **`ANALYZE`** — actually run the query and show real timings.
- **`BUFFERS`** — show how many disk pages were read from cache vs disk. Critical for I/O diagnosis.
- **`VERBOSE`** — extra information like output columns.
- **`SETTINGS`** — show any non-default planner parameters in effect.
- **`FORMAT text`** (default) | `json` | `yaml` | `xml` — output format. Text is human-readable; JSON is for tooling.

For serious analysis, paste the JSON output into **explain.depesz.com** or **explain.dalibo.com** — they render it visually and highlight problems. Much easier than reading raw text for complex plans.

### The structure of an EXPLAIN plan

A plan is a tree of operations. Each node has:
- **Node type** — the operation (Seq Scan, Index Scan, Nested Loop, Hash Join, etc.).
- **Cost** — `cost=X..Y` where X is the startup cost, Y is the total cost (arbitrary units; relative).
- **Rows** — estimated rows this node will produce.
- **Width** — average row size in bytes.
- **Actual time** (with ANALYZE) — real execution time in ms.
- **Actual rows** (with ANALYZE) — real row count.

A simple plan:

```
Index Scan using idx_orders_user_id on orders  (cost=0.43..8.45 rows=10 width=120) (actual time=0.015..0.023 rows=8 loops=1)
  Index Cond: (user_id = 42)
  Buffers: shared hit=3
Planning Time: 0.120 ms
Execution Time: 0.045 ms
```

Reading this: the planner used an index scan, estimated 10 rows would match (actual: 8), read 3 pages from shared buffer cache (no disk reads), and took 0.045ms to execute. This is a fast, healthy plan.

### The node types you'll see most

#### Scan nodes — how rows are read

- **Seq Scan** — read the entire table. Fast for small tables; bad for large tables with selective filters.
- **Index Scan** — use an index to find rows, then fetch them from the heap. Fast for selective filters.
- **Index Only Scan** — use an index without fetching from the heap. Possible when all needed columns are in the index (or via INCLUDE columns) and the visibility map is current.
- **Bitmap Index Scan + Bitmap Heap Scan** — for queries matching many rows via an index. Build a bitmap of matching heap pages, then visit them in physical order. Faster than Index Scan when many rows match.
- **CTE Scan / Subquery Scan** — scan the output of a CTE or subquery.
- **Function Scan** — scan the output of a function call (like `generate_series`).

#### Join nodes — how tables are joined

- **Nested Loop** — for each row in the outer table, scan the inner table for matches. Good for small inner sides or when there's an index on the join column. Bad when both sides are large.
- **Hash Join** — build a hash table of one side, probe it with the other. Good for large sides being joined on equality. Requires enough memory.
- **Merge Join** — both sides are sorted, then merged. Good when both sides are already sorted (e.g., from index scans).

The planner picks the join type based on estimated row counts and available memory. When estimates are wrong, it picks the wrong join type — and the performance hit is usually dramatic.

#### Aggregation nodes

- **HashAggregate** — build a hash table keyed on the GROUP BY columns. Fast for many groups; needs memory.
- **GroupAggregate** — sort the input, then group sequentially. Used when input is already sorted or when hash aggregation would exceed memory limits.

#### Sort and limit nodes

- **Sort** — explicit sort operation. Look at the "Sort Method" — "quicksort" is fast and in-memory; "external merge Disk" means the sort spilled to disk and is slow.
- **Limit** — truncate to N rows. Interesting because the planner can sometimes avoid full execution when the limit can be satisfied early.

### Reading an EXPLAIN plan — the heuristics

When a plan looks slow, these are the things to check, in order:

**1. Estimated rows vs actual rows.** The planner uses estimated row counts to pick the plan. When `estimated=10` but `actual=10000`, the planner made decisions as if the table were tiny and the plan is now catastrophically wrong. This usually means stale statistics (`ANALYZE` the table).

**2. Seq Scan on large tables.** A sequential scan on a 10-row lookup table is fine. A sequential scan on a 10-million-row table is almost always a problem — either the index doesn't exist, the planner doesn't think it's selective enough, or the statistics are wrong.

**3. Nested Loop with a large inner side.** If the inner side of a nested loop is hundreds of thousands of rows, the planner probably should have picked a hash join. Usually indicates a statistics problem.

**4. Sort spilling to disk.** `Sort Method: external merge Disk: 52MB` means the sort didn't fit in memory. Raise `work_mem` or add an index to avoid the sort.

**5. Lots of buffer reads on disk (not in cache).** `Buffers: shared read=50000` is different from `shared hit=50000` — reads came from disk, hits came from cache. High reads means the query is I/O-bound.

**6. Loops count in nested operations.** `loops=1000` means the operation ran 1000 times. Actual timings are per loop; total time is `actual time × loops`. Easy to miss.

**7. Filter vs Index Cond.** `Index Cond: (user_id = 42)` means the index narrowed the search. `Filter: (status = 'pending')` means the index returned rows and then a filter was applied after — indicating the filter column isn't part of the index.

### A worked example

Slow query:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT o.*, u.email
FROM orders o
JOIN users u ON o.user_id = u.id
WHERE o.status = 'pending'
  AND o.created_at > NOW() - INTERVAL '7 days'
ORDER BY o.created_at DESC
LIMIT 20;
```

Output (edited for brevity):

```
Limit (cost=400123.45..400125.67 rows=20 width=200) (actual time=8543.12..8543.45 rows=20 loops=1)
  Buffers: shared hit=1234 read=98765
  ->  Sort (cost=400123.45..400873.45 rows=300000 width=200) (actual time=8543.10..8543.22 rows=20 loops=1)
        Sort Key: o.created_at DESC
        Sort Method: top-N heapsort  Memory: 28kB
        ->  Hash Join (cost=1234.00..390000.00 rows=300000 width=200) (actual time=12.34..8501.23 rows=295432 loops=1)
              Hash Cond: (o.user_id = u.id)
              ->  Seq Scan on orders o (cost=0.00..380000.00 rows=300000 width=140) (actual time=0.05..8234.12 rows=295432 loops=1)
                    Filter: ((status = 'pending') AND (created_at > (now() - '7 days'::interval)))
                    Rows Removed by Filter: 14704568
                    Buffers: shared read=98000
              ->  Hash (cost=1234.00..1234.00 rows=10000 width=60)
                    ->  Seq Scan on users u (cost=0.00..1234.00 rows=10000 width=60)
Execution Time: 8543.89 ms
```

Reading this:
- **The outer query took 8.5 seconds.** Slow.
- **Seq Scan on orders.** Reading the entire orders table (15M rows) and filtering to 300K. This is the problem.
- **Filter removed 14.7M rows.** The filter is very selective. An index on `(status, created_at)` would let the planner use an index scan instead.
- **98K page reads from disk.** I/O-bound. Most of the 8.5 seconds is reading pages the planner had to scan.

The fix:

```sql
CREATE INDEX idx_orders_pending_recent
  ON orders (created_at DESC)
  WHERE status = 'pending';
```

A partial index on recent pending orders. Very small, very fast for this exact query. After creating it and running `ANALYZE`:

```
Limit (actual time=0.432..0.456 rows=20 loops=1)
  ->  Nested Loop (actual time=0.428..0.450 rows=20 loops=1)
        ->  Index Scan using idx_orders_pending_recent on orders o (actual time=0.012..0.032 rows=20 loops=1)
              Index Cond: (created_at > (now() - '7 days'::interval))
        ->  Index Scan using users_pkey on users u (actual time=0.005..0.006 rows=1 loops=20)
              Index Cond: (id = o.user_id)
Execution Time: 0.489 ms
```

From 8.5 seconds to 0.5 milliseconds. The index scan directly finds the 20 relevant rows, then a nested loop lookup on users by PK for each one. Fast, I/O-cheap, done.

### The role of statistics

The planner's decisions depend on statistics:
- **Row count estimates** per table.
- **Value distributions** per column (most common values, histogram boundaries).
- **Correlation** between logical order and physical order.
- **Null fractions**.

Statistics are collected by `ANALYZE` (automatically by autovacuum or manually). Stale statistics lead to bad plans.

**Symptoms of stale stats:**
- Estimates wildly different from actuals.
- The planner picks sequential scans on indexed columns.
- Queries that used to be fast suddenly aren't.
- After a bulk INSERT or UPDATE, performance degrades until autovacuum runs.

**Fix:** `ANALYZE the_table;` — manually updates statistics. Can also be done concurrently with autovacuum changes.

### The `default_statistics_target` knob

The number of samples ANALYZE takes per column. Default is 100, which is often too low for columns with skewed distributions. For hot tables, bump it per-column or globally.

```sql
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 1000;
ANALYZE orders;
```

Higher target = better estimates = better plans, at the cost of slower ANALYZE and slightly more planner CPU. For critical tables with skewed data, worth the trade-off.

### Extended statistics

Sometimes the planner's row count estimates are wrong not because of bad statistics but because the planner assumes column independence. If two columns are correlated — say, `city` and `country` — the planner thinks `WHERE city = 'Paris' AND country = 'France'` is rare but it's actually 100% of rows matching `city = 'Paris'`.

**Extended statistics** let you tell the planner about correlations:

```sql
CREATE STATISTICS city_country_stats (dependencies) ON city, country FROM addresses;
ANALYZE addresses;
```

The planner now knows that `city` and `country` are correlated and adjusts estimates accordingly. Rare in most schemas but valuable when it matters.

### pg_stat_statements — finding slow queries in production

`pg_stat_statements` is an extension that tracks query execution statistics. It's essential for production diagnosis.

```sql
CREATE EXTENSION pg_stat_statements;

SELECT
  query,
  calls,
  total_exec_time,
  mean_exec_time,
  rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

This shows the queries consuming the most total time — usually the best targets for optimization. A query that takes 10ms but runs 1M times is worse than a query that takes 1 second but runs 5 times.

The output aggregates queries by shape (with parameters normalized), so you see query patterns, not individual executions. Run `EXPLAIN ANALYZE` on a slow example of each pattern to dig deeper.

### Auto explain — logging slow query plans automatically

The `auto_explain` extension logs the plan of any query that exceeds a threshold.

```
shared_preload_libraries = 'auto_explain'
auto_explain.log_min_duration = 500ms
auto_explain.log_analyze = on
auto_explain.log_buffers = on
```

Any query slower than 500ms gets its full plan logged to the PostgreSQL log. Combined with `pg_stat_statements` to identify the pattern and `auto_explain` to see the actual slow execution's plan, you have a complete production diagnosis tool.

> **Mid-level answer stops here.** A mid-level dev can run EXPLAIN. To sound senior, speak to the heuristics of reading plans, the role of statistics, and the production tooling that turns EXPLAIN from a local tool into a diagnostic system ↓
>
> **Senior signal:** diagnosing query performance through plan analysis with confidence, understanding the planner's assumptions, and knowing how to correct them.

### The diagnostic checklist

When a query is slow:

1. **Run `EXPLAIN (ANALYZE, BUFFERS)`.** Get the actual plan.
2. **Compare estimated rows to actual rows.** Big discrepancy → stale statistics. Run ANALYZE.
3. **Look for Seq Scans on large tables.** Usually means missing or unusable index.
4. **Check filter vs index cond.** If filters are applied after the index, the index doesn't cover the query.
5. **Check join types.** Nested loop with huge inner side → statistics problem. Hash join that spills to disk → raise work_mem.
6. **Check Sort nodes.** External merge Disk → raise work_mem or avoid the sort with an index.
7. **Check buffer hit vs read ratio.** Lots of reads → I/O bound, either from cold cache or inadequate memory.
8. **Check loops in nested structures.** A per-row operation multiplied by many rows is often the real cost.
9. **If the plan looks right but it's still slow** — look at `work_mem`, `shared_buffers`, the hardware, and possibly `pg_stat_activity` for lock contention.

### Common mistakes

- **Reading EXPLAIN without ANALYZE.** Estimates can be wrong; you need actual measurements.
- **Running `EXPLAIN ANALYZE` on a destructive query and actually destroying data.** Use rolled-back transactions.
- **Adding indexes based on EXPLAIN of one query without checking others.** New index = write cost for every query.
- **Not running ANALYZE after bulk data changes.** Stale statistics lead to bad plans.
- **Ignoring `Rows Removed by Filter`.** High counts indicate the index is underselective.
- **Not using `pg_stat_statements` in production.** You have no idea which queries are actually slow.
- **Trying to manually hint the planner.** Postgres doesn't have query hints (on purpose). Fix statistics, fix indexes, fix the query.
- **Ignoring buffer counts.** I/O is often the real bottleneck and buffer counts are the clearest signal.

### Closing

"So EXPLAIN is the diagnostic tool for PostgreSQL query performance. Read it top-to-bottom as a tree of operations; look at estimated vs actual rows for stale-statistics issues; look at scan types, join types, sort methods, and buffer counts for I/O and memory issues. Combine with `pg_stat_statements` to find the queries worth optimizing and `auto_explain` to capture plans of slow production queries. The planner is usually smart; when it's wrong, it's almost always because of bad statistics, wrong column order in indexes, or a missing index. Fix those and most performance problems evaporate."
