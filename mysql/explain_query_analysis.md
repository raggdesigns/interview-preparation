When you find a slow SQL query (through logs or slow query log), the next step is to understand **why** it is slow. The `EXPLAIN` command shows you the query execution plan — how the database plans to find and return your data.

### Basic Usage

Put `EXPLAIN` before any SELECT query:

```sql
EXPLAIN SELECT * FROM users WHERE status = 'active' AND city = 'Belgrade';
```

The result is a table with columns that explain how MySQL will execute the query. The most important columns are `type`, `key`, `rows`, and `Extra`.

### The Most Important Columns

#### type — How MySQL Accesses the Table

This column shows the access method. From worst to best:

| type | Meaning | Performance |
|------|---------|------------|
| `ALL` | Full Table Scan — reads every row | Very bad |
| `index` | Full Index Scan — reads every entry in an index | Bad |
| `range` | Reads a range of index entries (e.g., BETWEEN, >, <) | OK |
| `ref` | Looks up rows using a non-unique index | Good |
| `eq_ref` | Looks up exactly one row using a unique/primary key (JOINs) | Very good |
| `const` | Looks up exactly one row using a primary key or unique index | Best |

**Red flag:** If `type` is `ALL`, the query scans every row in the table. This is almost always a sign that an index is missing.

```sql
-- type = ALL (bad) — no index on 'status'
EXPLAIN SELECT * FROM users WHERE status = 'active';

-- After adding an index:
CREATE INDEX idx_status ON users(status);

-- type = ref (good) — now uses the index
EXPLAIN SELECT * FROM users WHERE status = 'active';
```

#### key — Which Index Is Used

Shows the name of the index that MySQL chose. If it says `NULL`, no index is used.

```sql
EXPLAIN SELECT * FROM orders WHERE user_id = 5;
-- key: idx_user_id  ← using the index
-- key: NULL         ← NOT using any index (bad!)
```

#### possible_keys — Which Indexes Were Considered

Lists all indexes that MySQL could potentially use. If this is `NULL` but `key` is also `NULL`, you definitely need to create an index.

#### rows — Estimated Rows to Examine

Shows how many rows MySQL estimates it needs to read. Lower is better.

```sql
-- Before index: rows = 5,000,000 (scanning entire table)
-- After index:  rows = 230 (only matching rows)
```

#### Extra — Additional Information

| Value | Meaning |
|-------|---------|
| `Using index` | Query is answered entirely from the index (covering index) — very fast |
| `Using where` | MySQL applies a WHERE filter after reading rows |
| `Using temporary` | MySQL creates a temporary table (often for GROUP BY) — slow |
| `Using filesort` | MySQL sorts results without an index — slow with large datasets |
| `Using index condition` | Index Condition Pushdown — filter applied at index level |

### Reading a Full EXPLAIN Output

```sql
EXPLAIN SELECT u.name, COUNT(o.id) as order_count
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE u.status = 'active'
GROUP BY u.id;
```

Output:

```
+----+------+-------+------+---------------+---------+------+------+-------------+
| id | type | table | key  | possible_keys | rows    | Extra               |
+----+------+-------+------+---------------+---------+---------------------+
|  1 | ref  | u     | idx_status | idx_status | 2300   | Using where         |
|  1 | ref  | o     | idx_user   | idx_user   |    12  | Using index         |
+----+------+-------+------+---------------+---------+---------------------+
```

Reading this:
1. MySQL first finds active users using `idx_status` index (2300 rows)
2. For each user, it looks up orders using `idx_user` index (about 12 rows per user)
3. Total estimated work: 2300 × 12 = ~27,600 row lookups (instead of millions with full scans)

### EXPLAIN ANALYZE (MySQL 8.0+)

`EXPLAIN ANALYZE` actually runs the query and shows real execution times:

```sql
EXPLAIN ANALYZE SELECT * FROM users WHERE status = 'active' AND city = 'Belgrade';
```

```
-> Filter: ((users.status = 'active') AND (users.city = 'Belgrade'))
    -> Table scan on users  (cost=512345 rows=5000000)
       (actual time=0.05..3456.00 rows=5000000 loops=1)
```

The `actual time` shows real milliseconds. This tells you exactly where time is spent.

### Common Problems and Solutions

#### Problem 1: Full Table Scan (type = ALL)

```sql
EXPLAIN SELECT * FROM products WHERE category = 'electronics' AND price < 100;
-- type: ALL, key: NULL, rows: 2,000,000
```

**Fix:** Create a composite index on columns used in WHERE:

```sql
CREATE INDEX idx_category_price ON products(category, price);
-- Now: type: range, key: idx_category_price, rows: 340
```

#### Problem 2: Using filesort

```sql
EXPLAIN SELECT * FROM orders WHERE user_id = 5 ORDER BY created_at DESC;
-- Extra: Using filesort
```

**Fix:** Include the ORDER BY column in the index:

```sql
CREATE INDEX idx_user_created ON orders(user_id, created_at);
-- Now: Extra: Using index (no more filesort)
```

#### Problem 3: Using temporary (GROUP BY)

```sql
EXPLAIN SELECT city, COUNT(*) FROM users GROUP BY city;
-- Extra: Using temporary; Using filesort
```

**Fix:** Create an index on the GROUP BY column:

```sql
CREATE INDEX idx_city ON users(city);
-- Now: Extra: Using index
```

#### Problem 4: JOIN Without Index

```sql
EXPLAIN SELECT u.name, o.total
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE u.id = 5;
-- orders row: type: ALL, key: NULL (scanning all orders!)
```

**Fix:** Add an index on the foreign key:

```sql
CREATE INDEX idx_user_id ON orders(user_id);
-- Now: type: ref, key: idx_user_id
```

### Checklist for EXPLAIN Analysis

1. **Check `type`** — if it says `ALL`, you need an index
2. **Check `key`** — if it says `NULL`, no index is being used
3. **Check `rows`** — if the number is close to the total table size, something is wrong
4. **Check `Extra`** — if you see `Using temporary` or `Using filesort`, add indexes on GROUP BY / ORDER BY columns
5. **Compare `possible_keys` vs `key`** — MySQL might choose a suboptimal index; you might need to hint or restructure

### Real Scenario

A slow GET endpoint takes 8 seconds. You find this query in the slow query log:

```sql
SELECT p.name, p.price, c.name as category_name
FROM products p
JOIN categories c ON c.id = p.category_id
WHERE p.status = 'active' AND p.price BETWEEN 50 AND 200
ORDER BY p.created_at DESC
LIMIT 20;
```

Step 1 — Run EXPLAIN:

```sql
EXPLAIN SELECT p.name, p.price, c.name as category_name
FROM products p
JOIN categories c ON c.id = p.category_id
WHERE p.status = 'active' AND p.price BETWEEN 50 AND 200
ORDER BY p.created_at DESC
LIMIT 20;
```

Step 2 — Read the output:
- `type: ALL` on products table (bad — full table scan)
- `key: NULL` (no index used)
- `rows: 3,000,000`
- `Extra: Using where; Using filesort`

Step 3 — Create an index:

```sql
CREATE INDEX idx_status_price_created ON products(status, price, created_at);
```

Step 4 — Run EXPLAIN again:
- `type: range` (good — uses index range scan)
- `key: idx_status_price_created`
- `rows: 4,500`
- `Extra: Using index condition`

Query time drops from 8 seconds to 50 milliseconds.

### Conclusion

`EXPLAIN` shows you how MySQL plans to execute a query. The key things to check: `type` should never be `ALL` (full table scan), `key` should not be `NULL` (means no index), `rows` should be as low as possible, and `Extra` should not have `Using temporary` or `Using filesort`. When you see these problems, create the right index (usually on WHERE, JOIN, ORDER BY, and GROUP BY columns). Use `EXPLAIN ANALYZE` in MySQL 8.0+ to see actual execution times.

> See also: [MySQL Indices](./answers/indices.md), [Optimizing slow GET endpoint](../highload/optimizing_slow_get_endpoint.md)
