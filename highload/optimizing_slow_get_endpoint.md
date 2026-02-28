# Optimizing a Slow GET Endpoint

If a GET endpoint times out on a large table, the first goal is to remove the biggest bottleneck without changing the response contract.
In interviews, this topic checks whether you can debug in the right order: measure, find bottleneck, apply targeted fixes, and verify impact.

## Prerequisites

- You can read SQL and run `EXPLAIN`
- You know request latency basics (p95, timeout threshold)
- You understand indexes and cache invalidation at a basic level

## Fast Triage Flow

1. Confirm where time is spent: database, app layer, or network.
2. Capture one real slow query from logs or APM.
3. Run `EXPLAIN` and check rows scanned, index usage, and sort strategy.
4. Apply one change at a time and re-measure p95 latency.

## Most Common Fixes (in order)

### 1) Query and index fixes

- Add or adjust composite indexes for `WHERE + ORDER BY` patterns.
- Avoid selecting columns you do not return.
- Replace offset-heavy pagination with cursor/keyset pagination for deep pages.

### 2) Response-level caching

- Cache stable responses with keys based on filter parameters.
- Use short TTL plus explicit invalidation on writes.

### 3) Data access architecture

- Move read-heavy traffic to read replicas.
- Precompute expensive aggregations in a background job when real-time is not required.

## Practical Example

Problem:

- Endpoint: `GET /orders?user_id=42&status=paid&page=120`
- p95 latency: 8.2s
- DB plan shows full scan and filesort on a table with 40M rows.

Before:

```sql
SELECT *
FROM orders
WHERE user_id = 42 AND status = 'paid'
ORDER BY created_at DESC
LIMIT 50 OFFSET 5950;
```

After:

```sql
CREATE INDEX idx_orders_user_status_created_at
ON orders (user_id, status, created_at DESC);

SELECT id, total_amount, created_at, status
FROM orders
WHERE user_id = 42
  AND status = 'paid'
  AND created_at < '2026-02-01 10:12:00'
ORDER BY created_at DESC
LIMIT 50;
```

Result (example metrics):

- rows examined: 2.3M -> 1.2K
- p95 latency: 8.2s -> 220ms
- timeout rate: 14% -> <1%

## Interview Notes

- Start with measurement, not assumptions.
- Explain why each optimization is chosen for this query pattern.
- Mention trade-offs: cache staleness, replica lag, index write overhead.

## Conclusion

For slow GET endpoints, the highest-value path is: identify the slow query, fix access pattern and indexing, then add caching and read scaling only when needed.
This keeps the response unchanged while making performance predictable.
