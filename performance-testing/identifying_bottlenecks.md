# Identifying bottlenecks (USE method, RED method)

**Interview framing:**

"A bottleneck is whatever limits the system's throughput right now. Finding it is half the work of performance engineering; the other half is fixing it. The two systematic frameworks I use are USE (Utilization, Saturation, Errors) for infrastructure-level resources and RED (Rate, Errors, Duration) for request-level services. They give you a structured checklist instead of 'stare at dashboards and hope something stands out' — and the discipline of working through the checklist is what separates 'we think it's the database' from 'the database connection pool is saturated at 97%, waiting connections are queuing, and the queue is why p99 latency spiked'."

### The USE method — for every resource

Brendan Gregg's USE method is a systematic approach for every resource in the system. For each resource (CPU, memory, disk, network, connection pools, thread pools, etc.), check three things:

- **Utilization** — what percentage of the resource is in use? (time-based for CPU, capacity-based for memory/disk)
- **Saturation** — is there work waiting because the resource is full? (queue depth, backlog)
- **Errors** — are there errors related to this resource? (disk errors, network retransmits, OOM kills)

The mental model: utilization tells you how busy the resource is, saturation tells you if anything is waiting, and errors tell you if anything is broken. A resource can be at 90% utilization and fine; or at 60% utilization but saturated because of uneven load or lock contention.

### USE checklist for a typical web service

| Resource | Utilization | Saturation | Errors |
|---|---|---|---|
| **CPU** | `top`, container CPU usage vs limit | Load average, runqueue depth | None typical |
| **Memory** | Used vs available/limit | OOM kills, page faults, swap usage | OOM kills |
| **Disk I/O** | `iostat` %util, IOPS | I/O wait, queue depth | Disk errors |
| **Network** | Bandwidth utilization | TCP retransmits, send/receive queue | Interface errors |
| **DB connections** | Active/idle connections vs pool max | Connection wait time, queue depth | Connection refused errors |
| **PHP-FPM workers** | Active workers / max_children | Listen queue depth | `max_children reached` |
| **Thread/worker pool** | Active workers vs total | Pending tasks in queue | Rejected tasks |
| **Cache (Redis)** | Memory used vs maxmemory | Eviction rate | Connection errors |
| **Message broker** | Consumer throughput | Queue depth, consumer lag | DLQ arrivals |

Work through this checklist resource by resource. The first resource where saturation is non-zero is typically your bottleneck.

### PHP-FPM as a bottleneck — the common example

The `/fpm-status` endpoint gives you USE metrics directly:

- **Utilization:** `active processes / max_children`
- **Saturation:** `listen queue` (requests waiting for a free worker)
- **Errors:** `max children reached` counter (pool was full and couldn't serve)

If `listen queue > 0` consistently, FPM is the bottleneck. The fix is either more workers (raise `max_children` if you have memory) or faster workers (optimize the PHP code so requests complete faster and free workers sooner).

### The RED method — for every service

Tom Wilkie's RED method is the request-level complement to USE. For every service (not resource), measure:

- **Rate** — requests per second. How much traffic is this service handling?
- **Errors** — failed requests per second. What's the failure rate?
- **Duration** — how long requests take. What are the percentiles?

RED tells you the service-level health. It doesn't tell you *why* the service is slow — that's where you drill down with USE on the service's resources.

The typical debugging flow:

1. **RED on the top-level service.** "Duration spiked; errors are up."
2. **RED on each downstream dependency.** "The database is slow."
3. **USE on the database's resources.** "Disk I/O is saturated."
4. **Root cause found.** A missing index caused full table scans; I/O went through the roof.

RED surfaces the symptom; USE localizes the cause.

### The bottleneck checklist I actually run

When someone says "the system is slow", I work through this:

**Step 1: Where is the time going?**

- Check distributed traces for a slow request. Which span is dominating?
- If no traces, check application logs with timing. Which phase is slow?
- If no logs, use server-side timing middleware to break request time into: PHP processing, DB queries, cache calls, external APIs.

**Step 2: Is it the application or the infrastructure?**

- **Application:** CPU-bound PHP code, N+1 queries, missing caching, excessive serialization.
- **Infrastructure:** database connection pool full, disk I/O saturated, memory pressure causing swap, network latency.

Check infrastructure first (it's faster to check) via USE on the resources the application touches.

**Step 3: If it's the database...**

- Check `pg_stat_activity` for long-running queries.
- Check `pg_stat_statements` for the heaviest queries by total time.
- Run `EXPLAIN ANALYZE` on the worst ones (see [../postgresql/postgres_query_planning_explain.md](../postgresql/postgres_query_planning_explain.md)).
- Check connection pool utilization.
- Check disk I/O — is the database doing more I/O than expected? (Missing index causing sequential scans.)

**Step 4: If it's the application code...**

- Profile with Blackfire, Tideways, or Xdebug (see [profiling_php_applications.md](profiling_php_applications.md)).
- Look for N+1 queries, excessive object hydration, heavy serialization, uncached repeated computations.

**Step 5: If it's a downstream service...**

- Check the downstream service's RED metrics.
- Add circuit breakers or timeouts if the downstream is degraded.
- Cache downstream responses if appropriate.

### Common bottleneck patterns in PHP applications

- **N+1 queries.** A loop that runs a query per item. Fix: eager loading, batch fetching, or a single JOIN.
- **Missing database index.** A query that should be milliseconds takes seconds because of a full table scan. Fix: add the index (see [../postgresql/postgresql_indexes.md](../postgresql/postgresql_indexes.md)).
- **Uncached repeated computation.** The same expensive result is computed on every request. Fix: cache in Redis or APCu.
- **FPM worker exhaustion.** All workers are busy; requests queue. Fix: optimize request handling time or add workers.
- **Database connection pool exhaustion.** All connections are in use; new requests wait. Fix: connection pooling (PgBouncer, ProxySQL), reduce query count per request, increase pool size.
- **Large serialization/deserialization.** Converting large Doctrine entity graphs to JSON. Fix: use DTOs, select only needed fields, paginate.
- **Synchronous external API calls.** A slow third-party API blocks the worker for seconds. Fix: async processing via message queue, or add timeouts and circuit breakers.
- **Memory pressure.** Workers consuming too much memory, causing swap or OOM. Fix: reduce per-request memory (smaller result sets, streaming), lower `memory_limit`, fewer workers.
- **Lock contention.** Multiple workers competing for the same database row or file lock. Fix: optimistic locking, reduce lock scope, partition the workload.
- **Cache stampede.** Many concurrent requests for the same expired cache key all hit the backend simultaneously. Fix: probabilistic early expiration, request coalescing, lock-based cache recomputation.

### The "it's always the database" heuristic

In PHP applications, the bottleneck is the database 60-70% of the time. Not because databases are slow, but because:

- PHP is fast at CPU work relative to I/O.
- Most requests make multiple database calls.
- Missing indexes, N+1 patterns, and large result sets are common mistakes.
- Connection pool limits are usually the first resource to saturate.

"Start by checking the database" is not a lazy heuristic — it's an informed prior. Check it first; if the database is fine, move to the next resource.

### Synthetic vs production bottleneck identification

**In load tests:** you control the scenario. Ramp up until something saturates. USE + RED during the test. The bottleneck is whatever saturates first.

**In production:** you observe what's already happening. RED dashboards show the symptoms. Traces show where time goes. USE on resources during incidents shows what's saturated.

Both use the same frameworks; the difference is whether you're injecting load or observing it.

> **Mid-level answer stops here.** A mid-level dev can describe USE and RED. To sound senior, speak to the diagnostic discipline — the checklist, the order of operations, and the common patterns that short-circuit investigation ↓
>
> **Senior signal:** working through bottleneck identification systematically rather than guessing, and recognizing common patterns early.

### The meta-principle

Every performance investigation follows the same structure:

1. **Observe the symptom** (RED on the service).
2. **Localize the component** (trace or timing breakdown).
3. **Identify the resource** (USE on the component's resources).
4. **Measure the constraint** (what's the utilization/saturation?).
5. **Fix or mitigate** (index, cache, scale, optimize, circuit-break).
6. **Verify the fix** (re-run the measurement; confirm the bottleneck has moved).

Step 6 is the one people skip. Fixing one bottleneck reveals the next. Performance work is iterative: fix the top bottleneck, re-measure, find the new top bottleneck, repeat until the system meets its SLOs.

### Common mistakes

- **Guessing instead of measuring.** "It must be the database" without checking.
- **Optimizing something that isn't the bottleneck.** Making the cache 10x faster doesn't help if the bottleneck is the database.
- **Fixing the bottleneck and not re-measuring.** The next bottleneck is now active.
- **Confusing utilization with saturation.** 90% CPU utilization is fine if nothing is queuing. 60% CPU with a runqueue of 50 is not.
- **Looking at averages.** The average response time can be fine while p99 is terrible. Always look at percentiles.
- **Only checking the application tier.** Network, DNS, load balancer, CDN, client-side rendering — all contribute to end-to-end latency.
- **Not having the metrics to diagnose.** The time to instrument is before the incident, not during it.

### Closing

"So USE for resources, RED for services, traces for localization, and a systematic checklist for the investigation. Start with RED to surface the symptom, use traces or timing to localize the component, run USE on that component's resources to find the constraint, fix it, re-measure. The bottleneck is whatever saturates first — and in PHP applications, it's usually the database. The discipline is measuring before guessing, fixing one bottleneck at a time, and always verifying the fix with data."
