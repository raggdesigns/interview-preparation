# PostgreSQL vs MySQL

**Interview framing:**

"PostgreSQL and MySQL are both mature relational databases and they'll both handle 90% of workloads indistinguishably. The interesting conversation is about the remaining 10% — the places they differ, and why. The short version I keep in my head: MySQL is optimized for straightforward OLTP at scale with simple operational tooling and a large hosting ecosystem; PostgreSQL is a richer, more feature-complete database with a more principled type system, better SQL compliance, and significantly more power in the query planner and in what you can model with it. I pick PostgreSQL by default for new projects; I pick MySQL when there's a specific reason — existing expertise, specific hosting constraints, or a workload shape that matches MySQL's sweet spot."

### The features that actually differ in practice

#### Type system and data modeling

**Postgres** has the richer type system by a wide margin:
- **Native JSON and JSONB** — JSONB is indexable, queryable, and efficient; no bolt-on needed.
- **Arrays** — first-class array types (`integer[]`, `text[]`) with operators and indexes.
- **Range types** — `tsrange`, `int4range`, etc. Makes temporal and numeric range queries natural.
- **Enums** — real enum types, not just strings with a CHECK constraint.
- **UUID** — native `uuid` type with generation functions and efficient storage.
- **INET / CIDR** — native IP address types with operators.
- **Custom types** — you can define your own, including composite types.
- **Full-text search** — native `tsvector` and `tsquery` types with GIN indexes, plus ranking and stemming.
- **PostGIS** — the gold-standard geospatial extension, far ahead of MySQL's spatial support.

**MySQL** has JSON (since 5.7), spatial types, and basic types, but the type system is noticeably less principled and extensible. You end up serializing more things to strings or using application-level conversions.

When your domain has non-trivial data shapes — JSON documents, arrays, ranges, full-text, geospatial — PostgreSQL's native support is a significant productivity win.

#### SQL compliance and query power

Postgres implements more of the SQL standard and has more powerful query primitives:

- **Window functions.** Both databases have them now, but PostgreSQL's implementation is more complete and often faster.
- **CTEs (WITH queries).** Both support them; PostgreSQL's recursive CTEs are more flexible.
- **Lateral joins (`LATERAL`).** PostgreSQL's lateral joins are essential for correlated subqueries; MySQL added them in 8.0.14 but they're less common in the ecosystem.
- **Filtered aggregates (`COUNT(*) FILTER (WHERE ...)`)**. PostgreSQL only.
- **DISTINCT ON.** PostgreSQL only. Incredibly useful for "top N per group" queries.
- **Arrays in queries.** `WHERE id = ANY(ARRAY[1,2,3])`, array operators, array aggregation.
- **`RETURNING` clause** on INSERT/UPDATE/DELETE, which returns affected rows. PostgreSQL has had it forever; MySQL 8 got it recently.
- **Partial indexes.** PostgreSQL only.
- **Expression indexes.** Both support them, PostgreSQL's are more flexible.

For complex analytical or reporting queries, PostgreSQL's query power is frequently the deciding factor. For simple OLTP queries, both databases are fine.

#### The MVCC model

Both databases use MVCC (multi-version concurrency control), but the implementations differ:

**PostgreSQL** keeps multiple versions of each row in the same table, with old versions removed by a background process (VACUUM). This means:
- **No read locks on rows being updated.** Readers and writers never block each other.
- **Dead tuples accumulate.** Tables can bloat if VACUUM can't keep up. Autovacuum handles this but needs tuning at scale.
- **Long-running transactions are expensive.** They prevent VACUUM from cleaning up anything newer than their snapshot.

**MySQL (InnoDB)** keeps old versions in the undo log. The main table stays clean.
- **No accumulation of dead tuples in the main table.** Undo log is managed separately.
- **But the undo log can grow indefinitely with long-running transactions.**
- **Readers still don't block writers in most cases.**

In practice, both work, but PostgreSQL's model produces "table bloat" as a specific operational concern you need to know about. See [postgresql_mvcc_and_vacuum.md](postgresql_mvcc_and_vacuum.md).

#### Replication and high availability

**MySQL** has mature, battle-tested replication that's been used for a very long time. Async replication, semi-sync replication, group replication, InnoDB Cluster. Replication is the "done deal" in MySQL — you set it up and it works.

**PostgreSQL** has streaming replication (physical) and logical replication (since PG10). Physical replication is simple and reliable but doesn't allow cross-version upgrades or partial replication. Logical replication is flexible (select specific tables, migrate between versions) but newer and has more gotchas.

For HA, the PostgreSQL ecosystem typically uses Patroni + etcd/Consul or a managed service. MySQL has ProxySQL, MHA, and orchestrator; managed MySQL is usually easier operationally than managed PostgreSQL HA (though managed PostgreSQL is rapidly closing the gap).

If operational simplicity is the deciding factor, MySQL often wins. If feature richness is the deciding factor, PostgreSQL wins.

#### Extensions

PostgreSQL has a significant extension ecosystem that MySQL doesn't match:

- **PostGIS** — geospatial.
- **TimescaleDB** — time-series data.
- **Citus** — distributed Postgres for horizontal scaling.
- **pg_trgm** — trigram-based fuzzy matching.
- **hstore** — older key-value type (largely superseded by JSONB).
- **pg_stat_statements** — query performance telemetry. Essential for production.
- **pgvector** — vector similarity search (for embeddings / RAG).
- **pg_cron** — in-database scheduled tasks.

If your workload needs one of these, Postgres is essentially the only option. MySQL has plugins and some community extensions, but the ecosystem is noticeably smaller.

#### Write performance and storage engines

**MySQL** famously has multiple storage engines (InnoDB, MyISAM, Memory). In practice, everyone uses InnoDB, which is a mature, battle-tested, transactional engine with strong write performance.

**PostgreSQL** has one storage engine (heap + WAL + indexes), but work on pluggable engines is underway. The current heap engine is solid but has specific quirks:
- **Write amplification on updates.** Because every update creates a new tuple (MVCC), updates on wide rows can be expensive.
- **HOT updates** (heap-only tuples) mitigate this when no indexed columns change.
- **Index maintenance on updates** — every updated row creates a new tuple, and all indexes need updating (unless HOT kicks in).

For pure write throughput on simple tables, MySQL often wins by 10-30% in benchmarks. For everything else, the difference is usually drowned out by application behavior.

#### Operational characteristics

**MySQL pros:**
- Simpler operationally for common cases.
- Broader hosting ecosystem (every cloud provider, every shared host, every PaaS).
- Smaller memory footprint for a minimal deployment.
- Easier replication setup.

**PostgreSQL pros:**
- More powerful tooling for observability (`pg_stat_statements`, `auto_explain`, etc.).
- Better support for schema changes under load (concurrent index builds, minimal locking).
- More flexible in cloud and on-prem deployments.
- Better SQL standards compliance reduces surprise.

### The things that used to differ and don't anymore

- **MySQL didn't have proper transactional DDL.** Fixed in MySQL 8 (mostly).
- **MySQL's query planner was weaker.** Much improved in MySQL 8.
- **MySQL's default character set was latin1.** Fixed to utf8mb4 by default in MySQL 8.
- **PostgreSQL didn't have fast upsert.** Got `INSERT ... ON CONFLICT` in 9.5.
- **PostgreSQL was slower on writes.** Narrowed significantly over time.

Many of the old "PostgreSQL vs MySQL" war stories refer to conditions that no longer hold. Check current versions before relying on old comparisons.

### When to pick MySQL

- **Existing team expertise** in MySQL is deep and switching would be costly.
- **Hosting constraints** — the managed platform or shared host you're using only supports MySQL.
- **Very high write throughput on simple tables** where the performance difference is measured and significant.
- **Existing ecosystem integration** — tools, ORMs, migration systems in your stack target MySQL first.
- **Simple replication requirements** where MySQL's maturity matters.
- **WordPress, Drupal, Magento** and the PHP CMS ecosystem — MySQL is the default and the path of least resistance.

### When to pick PostgreSQL

- **Complex data modeling** — JSON, arrays, ranges, enums, full-text search, geospatial.
- **Complex queries** — window functions, lateral joins, CTEs, filtered aggregates.
- **Need for extensions** — PostGIS, TimescaleDB, pgvector, etc.
- **Strong typing and SQL correctness** matter to your team.
- **Schema migrations under load** — concurrent indexes, transactional DDL, fewer locking surprises.
- **Analytical queries mixed with OLTP** — Postgres handles this blend better than MySQL.
- **Greenfield projects** where you have the choice — Postgres is the better default.

### The PHP-specific angle

Historically, MySQL was the PHP default by wide margin. Drupal, WordPress, Magento, symfony-by-habit — all MySQL-first. PostgreSQL support in the PHP ecosystem is good but often treated as a second-class target by tools that were built MySQL-first.

Modern PHP (Symfony, Laravel) is database-agnostic via Doctrine and Eloquent, and both databases work well. The decision is technical, not PHP-specific.

> **Mid-level answer stops here.** A mid-level dev can list differences. To sound senior, speak to the decision framework and the operational concerns that don't show up in feature comparisons ↓
>
> **Senior signal:** articulating that database choice is a long-lived commitment with ecosystem, operational, and hiring consequences beyond the raw feature set.

### The long-tail consequences of the choice

Database choice isn't just about current features. It's about:

- **Operational knowledge** — the people on-call need to know the database's quirks.
- **Tooling** — backup, monitoring, query analysis, schema migration tools.
- **Ecosystem** — ORMs, libraries, community resources.
- **Hiring** — candidates who know your stack.
- **Migration cost** — "let's switch" is always much harder than "let's start fresh".

These costs are invisible at decision time and dominant over the life of the system. A less-powerful database you know how to operate is often better than a more-powerful database you don't.

### Common mistakes

- **Picking based on benchmarks that don't match your workload.** Most benchmarks are synthetic; real workload performance is different.
- **Picking Postgres because "it's the senior choice" without matching the team's expertise.**
- **Picking MySQL because "PHP = MySQL" without evaluating the fit.**
- **Avoiding features you'd benefit from** because "let's keep it simple". JSONB on Postgres is not an advanced feature; it's a standard tool.
- **Treating the two as interchangeable.** You can port schemas, but the idioms, query patterns, and operational work differ enough that mental-model switching has real cost.

### Closing

"So MySQL and PostgreSQL are both solid relational databases that handle most workloads equivalently. The real differences are: PostgreSQL has a richer type system, more powerful SQL, more extensions, and better complex-query performance; MySQL has simpler operations, broader hosting, and a more mature replication story. For greenfield projects I default to PostgreSQL because the feature advantages compound over time; for existing MySQL shops I don't recommend switching unless there's a specific reason. The decision matters more than people think — it shapes the ecosystem you live in for the life of the project."
