# Tools for Analyzing Problems on Database Side of an Application

Database issues are easier to solve when you follow a fixed workflow instead of jumping directly to random tuning.
In interviews, a strong answer is to explain which tool you use at each step and why.

## Prerequisites

- You can run `EXPLAIN` / `EXPLAIN ANALYZE`
- You know basic indexes and query plans
- You can read CPU, memory, IOPS, and connection metrics

## Diagnostic Workflow

1. Detect: identify symptom (slow queries, lock waits, high CPU, replication lag).
2. Localize: find top offenders by query fingerprint and time window.
3. Inspect: analyze plans, lock contention, and resource saturation.
4. Fix: apply index/query/schema/config change.
5. Verify: compare before/after metrics.

## Tool Categories and Purpose

### 1) Query-level tools

- Slow query log + digest tools (for example `pt-query-digest`)
- `EXPLAIN` / `EXPLAIN ANALYZE`
- Performance schema / statement statistics dashboards

Use these first when latency is query-specific.

### 2) Database engine metrics

- Engine dashboards (buffer/cache hit rate, active connections, lock waits)
- Host metrics (CPU, memory pressure, disk latency)

Use these when many queries slow down at once.

### 3) Lock and concurrency analysis

- Lock wait views / deadlock logs
- Transaction and blocking session inspection

Use these when timeouts happen even for normally fast queries.

### 4) End-to-end observability

- APM trace linking app request to SQL spans
- Centralized logs with request ID

Use this to prove whether DB is root cause or only part of a larger request bottleneck.

## Practical Example

Symptom:

- Checkout endpoint p95 rises from 250ms to 2.4s.

Investigation path:

1. APM trace shows 1.9s inside SQL layer.
2. Slow log digest points to one query fingerprint contributing 62% of DB time.
3. `EXPLAIN` shows full scan on `orders` with filter by `customer_id` + `created_at`.
4. Add composite index and re-check plan.

Result (example):

- Query latency p95: 1.7s -> 90ms
- Endpoint p95: 2.4s -> 410ms

## Interview Notes

- Mention specific metrics before and after.
- Explain that tuning follows measured bottlenecks.
- Mention trade-offs (index write cost, storage growth, maintenance overhead).

## Conclusion

The best database troubleshooting approach is tool-driven and ordered: detect, localize, inspect, fix, verify.
This avoids guesswork and leads to faster, safer performance improvements.
