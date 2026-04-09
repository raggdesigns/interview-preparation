# PostgreSQL indexes

**Interview framing:**

"PostgreSQL has a richer index story than most relational databases, and knowing which index type to use for which query pattern is a real differentiator in interviews. Everybody knows btree. Senior answers know about GIN for full-text and JSONB, BRIN for append-only time-series tables, partial indexes to cut index size, expression indexes for computed lookups, and the trade-offs of each. The interesting insight is that an index is not a free speed-up — each one costs writes, storage, and planning time, and the right number of indexes is 'as few as possible, as many as necessary'."

### The six index types you should know

#### 1. B-tree — the default

The workhorse. Sorted tree structure, supports equality, range, prefix, and ordering queries. Used for most columns most of the time.

```sql
CREATE INDEX idx_orders_user_id ON orders (user_id);
```

Good for:

- `WHERE user_id = 42`
- `WHERE created_at > '2026-01-01'`
- `ORDER BY created_at DESC`
- `WHERE email LIKE 'alice%'` (prefix only)

Not good for:

- `WHERE email LIKE '%alice%'` (suffix or substring)
- `WHERE array_col @> ARRAY[1]` (array containment)
- `WHERE jsonb_col @> '{"status": "active"}'` (JSONB containment)

B-tree is the right default. Only reach for other types when you have a specific reason.

#### 2. Hash

Equality-only index. Faster than B-tree for exact lookups, smaller footprint, but can't do ranges or ordering.

```sql
CREATE INDEX idx_sessions_token ON sessions USING hash (token);
```

**Used rarely** because:

- The speed advantage over B-tree is small.
- B-tree covers the same query with extra flexibility.
- Hash indexes used to be unlogged and unreliable pre-PG10. Now they're fine but the habit of avoiding them persists.

Modern PostgreSQL hash indexes are WAL-logged and crash-safe. They're a legitimate choice for equality-only workloads where size matters, but the benefit is usually small.

#### 3. GIN — Generalized Inverted Index

For columns containing multiple values per row. GIN is an inverted index: it maps each value to the rows that contain it.

```sql
CREATE INDEX idx_articles_tags ON articles USING gin (tags);       -- array column
CREATE INDEX idx_docs_content ON docs USING gin (to_tsvector('english', content));  -- full-text
CREATE INDEX idx_events_attrs ON events USING gin (attrs jsonb_path_ops);  -- JSONB
```

Good for:

- **Arrays.** `WHERE tags @> ARRAY['sql', 'postgres']`
- **Full-text search.** `WHERE to_tsvector(content) @@ to_tsquery('database & postgres')`
- **JSONB containment.** `WHERE data @> '{"status": "active"}'`
- **Trigram similarity** (with pg_trgm extension). `WHERE name % 'Postgres'`

Trade-offs:

- **Larger than B-tree** for the same data.
- **Slower to update** — every write has to update inverted lists.
- **GIN + `fastupdate=on`** amortizes write cost via a pending list that's flushed periodically. Speeds writes, slows some reads.

GIN is the index type for "multi-value columns" — arrays, documents, text corpora.

#### 4. GIST — Generalized Search Tree

A framework for custom index types. Out of the box, supports:

- **Geometric types** (points, rectangles, polygons) with PostGIS.
- **Range types** (`tsrange`, `int4range`) — containment and overlap queries.
- **Full-text search** — alternative to GIN, with different trade-offs.
- **Nearest-neighbor queries** — "find the 10 closest points".

```sql
CREATE INDEX idx_events_time_range ON events USING gist (time_range);
CREATE INDEX idx_locations_geom ON locations USING gist (geom);  -- PostGIS
```

GIST is the extensible index type. PostGIS builds heavily on it for spatial indexes. It's also the right choice for range containment and exclusion constraints.

**GIN vs GIST for full-text:**

- GIN is faster for lookups, slower for updates.
- GIST is slower for lookups, faster for updates.
- For mostly-read full-text workloads → GIN. For frequently updated text → GIST.

#### 5. BRIN — Block Range Index

Very small indexes for very large tables with naturally ordered data. Instead of indexing every row, BRIN stores summaries (min, max, etc.) for ranges of disk blocks.

```sql
CREATE INDEX idx_events_timestamp ON events USING brin (created_at);
```

Good for:

- **Append-only time-series tables** where rows are inserted in timestamp order.
- **Data naturally correlated with physical storage order.** Sensor readings, log entries, analytics events.

Trade-offs:

- **Much smaller than B-tree** — orders of magnitude for large tables.
- **Much coarser queries.** A BRIN lookup scans all blocks in the matching range, not just the rows.
- **Useless if data is not ordered.** If rows are inserted randomly, BRIN indexes don't help.

For a 100 GB events table with timestamps, a B-tree index on `created_at` might be 5 GB. A BRIN index might be 1 MB. The BRIN index is less precise but queries that match a time range are still fast because they only scan a handful of blocks.

BRIN is niche but powerful in its niche. Use it for large, append-only, naturally ordered tables.

#### 6. SP-GiST — Space-Partitioned GiST

A specialized index for non-balanced tree structures (quad-trees, k-d trees, radix trees). Used for specific data types like IP addresses or geometric data that doesn't distribute evenly. Rarely needed; when you need it, you know.

### Index modifiers that matter

#### Partial indexes

An index on a subset of rows, defined by a WHERE clause. PostgreSQL-only feature (MySQL doesn't have them).

```sql
CREATE INDEX idx_orders_pending ON orders (user_id)
  WHERE status = 'pending';
```

The index only contains rows where `status = 'pending'`. Much smaller than a full index, faster to maintain, faster to search — **as long as the query planner can use it**.

The planner uses a partial index when the query's WHERE clause is a provable superset of the index's WHERE clause. `WHERE user_id = 42 AND status = 'pending'` matches. `WHERE user_id = 42` does not (it might return non-pending rows).

**When partial indexes shine:**

- **"Active" subsets.** Most rows are "inactive" and you only query actives.
- **Status filters.** Pending tasks, unfinished orders, unsent notifications.
- **Soft-deleted rows.** `WHERE deleted_at IS NULL` is a common partial-index predicate.
- **Any highly selective filter** that reduces the indexed row count by 90%+.

#### Expression indexes

An index on a computed expression, not a raw column. Both MySQL and Postgres support these; Postgres is more permissive about what can be indexed.

```sql
CREATE INDEX idx_users_lower_email ON users (lower(email));
-- used by:
SELECT * FROM users WHERE lower(email) = 'alice@example.com';
```

Good for:

- **Case-insensitive lookups.** `lower(email)` or `upper(name)`.
- **Computed fields.** `date_trunc('day', created_at)` for day-level aggregation.
- **JSON extraction.** `(data->>'user_id')` to index a field inside a JSONB blob.

The query must use the exact same expression as the index definition, character for character. The planner matches by expression shape.

#### Multi-column indexes

```sql
CREATE INDEX idx_orders_user_created ON orders (user_id, created_at DESC);
```

Good for queries that filter on the leading columns in order. The classic rule: a multi-column index on `(a, b, c)` can be used for queries on `(a)`, `(a, b)`, or `(a, b, c)`. It **cannot** be used for queries on just `(b)` or `(c)` alone.

**The column order matters.** `(user_id, created_at)` and `(created_at, user_id)` are different indexes with different use cases. The highly-selective or commonly-filtered column goes first.

#### Unique indexes

```sql
CREATE UNIQUE INDEX idx_users_email ON users (email);
```

Enforces uniqueness in addition to indexing. The same as a UNIQUE constraint under the hood — `ALTER TABLE ADD UNIQUE (email)` creates a unique index implicitly.

#### INCLUDE columns (covering indexes)

Since PG11. An index can "include" non-key columns that are stored in the leaf but not used for searching. Makes index-only scans possible for more queries.

```sql
CREATE INDEX idx_orders_user_include_amount
  ON orders (user_id)
  INCLUDE (total_amount);
```

Query: `SELECT total_amount FROM orders WHERE user_id = 42` — can be satisfied entirely from the index without touching the table.

### The cost of indexes

Every index adds:

- **Write cost.** Every INSERT and UPDATE has to update every index on the table. A table with 10 indexes is 10x the write work for every row touched.
- **Storage cost.** Indexes can easily total more storage than the table data itself.
- **Planning cost.** More indexes means more work for the query planner to evaluate them.
- **Vacuum cost.** Dead tuples need cleaning up in every index.

The cost side is often invisible to new engineers. Adding an index because "it might help" is a trap — the index will definitely cost writes, and it might not be used.

**The rule:** add an index for a specific, measured slow query. Never add an index speculatively.

### Finding unused indexes

Unused indexes are a silent drag on performance. PostgreSQL tracks index usage:

```sql
SELECT
  schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY tablename;
```

Indexes with `idx_scan = 0` have never been used since stats were last reset. They're candidates for removal — cost without benefit.

### Finding missing indexes

Enable `pg_stat_statements` and look for slow, frequently-run queries:

```sql
SELECT
  query,
  calls,
  mean_exec_time,
  total_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

Slow queries that run often are candidates for indexing. Run `EXPLAIN (ANALYZE, BUFFERS)` on them (see [postgres_query_planning_explain.md](postgres_query_planning_explain.md)) to see whether the planner is doing full scans that an index would avoid.

### Concurrent index builds

Building a large index with `CREATE INDEX` takes an `ACCESS EXCLUSIVE` lock on the table, blocking all writes for the duration. On a production table, this is unacceptable.

```sql
CREATE INDEX CONCURRENTLY idx_large_table_col ON large_table (col);
```

`CONCURRENTLY` builds the index without blocking writes — it takes two passes over the table and is noticeably slower, but the table stays usable. Always use it in production.

**Gotcha:** if a concurrent index build fails (duplicate key, out of space), the index is left in an `INVALID` state and must be dropped manually before retrying.

> **Mid-level answer stops here.** A mid-level dev can describe B-tree. To sound senior, speak to the index type diversity, the cost side, and the discipline of measuring before adding ↓
>
> **Senior signal:** treating indexes as a resource with a cost function, using the right index type for the query shape, and continuously pruning unused ones.

### The discipline I follow

- **Default to B-tree.** Reach for other types only with a specific reason.
- **Use GIN for JSONB and full-text.** Standard pattern.
- **Use BRIN for large append-only time-series tables.** The size savings are huge.
- **Use partial indexes when the filter is highly selective.** Huge wins on "status" columns.
- **Never add indexes speculatively.** Measure before adding.
- **Build concurrently in production.** Always.
- **Prune unused indexes regularly.** `pg_stat_user_indexes` tells you which.
- **Watch total index size.** If indexes are larger than data, something is wrong.

### Common mistakes

- **Index on every column.** The write cost is catastrophic.
- **Missing indexes on foreign keys.** Foreign key checks and cascade operations become slow.
- **Wrong column order in multi-column indexes.** `(a, b)` vs `(b, a)` matters.
- **Using B-tree where GIN is correct.** Slow full-text or JSONB queries.
- **Using B-tree for big append-only tables.** BRIN is often 100x smaller.
- **Not using `CONCURRENTLY` in production.** Table-locking during index builds.
- **Keeping unused indexes forever.** Silent drag on writes.
- **Not running VACUUM / ANALYZE.** The planner makes bad choices with stale statistics.
- **Indexes that include every column "just in case".** Index bloat and no benefit.

### Closing

"So PostgreSQL has a rich index taxonomy — B-tree as the default, GIN for multi-value columns like JSONB and full-text, GIST for geometry and ranges, BRIN for large ordered tables, hash for equality-only at small footprint, and SP-GiST for specialized structures. On top of that, partial indexes for selective filters, expression indexes for computed lookups, multi-column indexes with careful column ordering, and INCLUDE columns for covering index-only scans. Every index costs writes; the discipline is measuring before adding and pruning what doesn't earn its keep. The right index for the right query shape is the difference between 'fast' and 'dog slow', and a senior engineer picks deliberately rather than reaching for B-tree by reflex."
