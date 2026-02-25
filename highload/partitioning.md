Partitioning is splitting a large database table into smaller pieces called **partitions**. Each partition stores a subset of the data, but the application still sees it as one table. Partitioning happens inside a single database server, unlike sharding which splits data across multiple servers.

### Why Partition a Table?

When a table has millions or billions of rows:
- Queries become slow because indexes are huge
- INSERT operations slow down because indexes need to be updated
- Maintenance operations (backup, ALTER TABLE) take a very long time

Partitioning solves these problems by making each partition smaller and more manageable.

### Types of Partitioning

#### 1. RANGE Partitioning

Data is divided by ranges of values. Very common for date-based data.

```sql
CREATE TABLE orders (
    id BIGINT AUTO_INCREMENT,
    customer_id INT,
    total DECIMAL(10,2),
    created_at DATE,
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (YEAR(created_at)) (
    PARTITION p2022 VALUES LESS THAN (2023),
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);
```

#### 2. LIST Partitioning

Data is divided by a list of specific values.

```sql
CREATE TABLE users (
    id INT,
    name VARCHAR(100),
    country VARCHAR(2),
    PRIMARY KEY (id, country)
) PARTITION BY LIST COLUMNS (country) (
    PARTITION p_europe VALUES IN ('DE', 'FR', 'GB', 'IT', 'ES'),
    PARTITION p_americas VALUES IN ('US', 'CA', 'BR', 'MX'),
    PARTITION p_asia VALUES IN ('CN', 'JP', 'KR', 'IN')
);
```

#### 3. HASH Partitioning

Data is distributed evenly using a hash function. Useful when there is no natural range or list.

```sql
CREATE TABLE sessions (
    id BIGINT AUTO_INCREMENT,
    user_id INT,
    data TEXT,
    PRIMARY KEY (id, user_id)
) PARTITION BY HASH (user_id) PARTITIONS 8;
```

MySQL computes `user_id % 8` to determine which partition stores each row.

#### 4. KEY Partitioning

Similar to HASH but uses MySQL's internal hashing function. Works with any column type, not just integers.

```sql
CREATE TABLE logs (
    id BIGINT AUTO_INCREMENT,
    session_id VARCHAR(64),
    message TEXT,
    PRIMARY KEY (id, session_id)
) PARTITION BY KEY (session_id) PARTITIONS 16;
```

### Benefits for Read Operations

#### Partition Pruning

The biggest benefit. When a query includes the partition key in the WHERE clause, MySQL only scans the relevant partitions and skips all others.

```sql
-- Without partitioning: scans entire table (100 million rows)
SELECT * FROM orders WHERE created_at BETWEEN '2024-01-01' AND '2024-12-31';

-- With RANGE partitioning by year: scans only partition p2024 (~20 million rows)
-- MySQL "prunes" partitions p2022, p2023, p2025, p_future
```

You can verify with `EXPLAIN`:
```sql
EXPLAIN SELECT * FROM orders WHERE created_at = '2024-06-15';
-- Shows: partitions: p2024  (only one partition scanned)
```

#### Smaller Indexes

Each partition has its own index. Instead of one huge B-tree index covering 100 million rows, you have multiple smaller indexes. Smaller indexes:
- Fit better in memory (buffer pool)
- Have fewer levels → fewer disk reads
- Are faster to search

#### Parallel Reads (with some engines)

Some storage configurations allow reading from multiple partitions in parallel, improving query performance for queries that span several partitions.

### Benefits for Write Operations

#### Faster Inserts

When inserting into a partitioned table, MySQL only needs to update the index of the target partition, not a massive global index:

```
Non-partitioned table:
  INSERT → update one huge index (100M entries) → slow

Partitioned table:
  INSERT → update small partition index (20M entries) → faster
```

#### Lock Reduction

Write operations on one partition do not block reads/writes on other partitions (with InnoDB row-level locking + partition-level operations). This improves concurrent write performance.

#### Easier Data Management

Old data can be removed instantly by dropping a partition instead of deleting rows one by one:

```sql
-- Without partitioning: slow DELETE, causes table fragmentation
DELETE FROM orders WHERE created_at < '2022-01-01';
-- This could take hours on a large table

-- With partitioning: instant
ALTER TABLE orders DROP PARTITION p2021;
-- This is almost instant regardless of how many rows are in the partition
```

Adding space for new data is also fast:

```sql
ALTER TABLE orders ADD PARTITION (
    PARTITION p2026 VALUES LESS THAN (2027)
);
```

### Partitioning vs Sharding

| Feature | Partitioning | Sharding |
|---------|-------------|----------|
| Location | Same server, same database | Different servers |
| Complexity | Low — MySQL handles it | High — application must route queries |
| Scalability | Limited by single server | Scales horizontally |
| Transactions | Full ACID support | Complex — cross-shard transactions are hard |
| Use case | Optimize large tables on one server | Scale beyond one server's capacity |

Partitioning is often the first step. When a single server can no longer handle the load, you add sharding.

> See also: [Sharding](sharding.md) for horizontal scaling across multiple servers.

### Limitations

- The partition key must be part of every unique index (including the primary key)
- Foreign keys are not supported on partitioned tables in MySQL
- Maximum 8192 partitions per table
- Some queries that do not include the partition key in WHERE will scan all partitions (no pruning)

### Real Scenario

You have an analytics table with 500 million rows of event data. Queries are slow and inserting new events takes too long:

```sql
-- Before: one massive table
CREATE TABLE events (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    event_type VARCHAR(50),
    user_id INT,
    payload JSON,
    created_at DATETIME,
    INDEX idx_created (created_at),
    INDEX idx_user (user_id)
);
-- Table size: 500M rows, index size: 40 GB
-- Query: SELECT * FROM events WHERE created_at > '2024-10-01' → 45 seconds
```

```sql
-- After: partitioned by month
CREATE TABLE events (
    id BIGINT AUTO_INCREMENT,
    event_type VARCHAR(50),
    user_id INT,
    payload JSON,
    created_at DATETIME,
    PRIMARY KEY (id, created_at),
    INDEX idx_user (user_id, created_at)
) PARTITION BY RANGE (TO_DAYS(created_at)) (
    PARTITION p202401 VALUES LESS THAN (TO_DAYS('2024-02-01')),
    PARTITION p202402 VALUES LESS THAN (TO_DAYS('2024-03-01')),
    -- ... one partition per month
    PARTITION p202412 VALUES LESS THAN (TO_DAYS('2025-01-01')),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);
-- Each partition: ~40M rows, index per partition: ~3 GB
-- Same query: SELECT * FROM events WHERE created_at > '2024-10-01' → 3 seconds
-- Cleanup: ALTER TABLE events DROP PARTITION p202301; → instant
```

The same query is 15x faster because MySQL only scans 3 months of data instead of the entire table.

### Conclusion

Partitioning splits a large table into smaller parts inside the same database. It improves read performance through partition pruning (scanning only relevant partitions) and smaller indexes. It improves write performance through smaller indexes to update and reduced lock contention. It makes maintenance easier — dropping old partitions is instant. Use RANGE for time-series data, LIST for categorical data, and HASH/KEY for even distribution. Partitioning is a simpler alternative to sharding when one server is sufficient.
