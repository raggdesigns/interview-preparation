### Data Types and SQL Concepts

---

#### Char vs Varchar

- **CHAR(n)**: Fixed length. Space is reserved to accommodate exactly `n` characters. If the entered string is smaller than `n`, it is padded with spaces on the right. Faster for fixed-size data because MySQL knows the exact offset of each row.
- **VARCHAR(n)**: Variable length. Only uses as much space as the actual string plus 1–2 bytes of overhead to store the length. More space-efficient for variable-size data.

**When to use which:**
- Use `CHAR` for values that are always (or nearly always) the same length: country codes, currency codes, MD5 hashes.
- Use `VARCHAR` for values with unpredictable length: names, emails, descriptions.

**Example:**

```sql
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    country_code CHAR(2)      NOT NULL,  -- Always 2 chars: 'US', 'DE', 'CH'
    currency_code CHAR(3)     NOT NULL,  -- Always 3 chars: 'USD', 'EUR', 'CHF'
    email VARCHAR(255)        NOT NULL,  -- Variable: 'a@b.com' vs 'very.long.name@company.co.uk'
    full_name VARCHAR(100)    NOT NULL   -- Variable: 'Li' vs 'Alexander Christopherson'
);

-- Storage comparison:
-- CHAR(2) storing 'US' → 2 bytes always (padded if shorter)
-- VARCHAR(255) storing 'a@b.com' → 7 bytes + 1 byte length prefix = 8 bytes
-- VARCHAR(255) storing a 200-char email → 200 bytes + 2 bytes length prefix = 202 bytes

-- Trailing space behavior:
INSERT INTO users (country_code, currency_code, email, full_name)
VALUES ('U', 'CHF', 'test@test.com', 'John');
-- country_code is stored as 'U ' (padded with space)
-- When retrieved with SELECT, trailing spaces are stripped by default in CHAR
```

---

#### What is Selectivity

Selectivity measures how "unique" an index column's values are. It is calculated as:

$$\text{Selectivity} = \frac{\text{Number of distinct values}}{\text{Total number of rows}}$$

A selectivity of **1.0** (or close to it) means almost every value is unique — the index is highly effective. A selectivity close to **0** means many duplicates — the index provides little benefit.

**Example:**

```sql
CREATE TABLE orders (
    id INT PRIMARY KEY,
    customer_id INT,
    status ENUM('pending', 'paid', 'shipped', 'delivered', 'cancelled'),
    order_number VARCHAR(20) UNIQUE,
    created_at DATETIME
);

-- Assume the table has 1,000,000 rows

-- HIGH selectivity: order_number (unique)
-- Distinct values: 1,000,000 / Total: 1,000,000 = 1.0
-- An index on order_number is extremely effective
SELECT * FROM orders WHERE order_number = 'ORD-2024-123456'; -- Returns 1 row

-- MEDIUM selectivity: customer_id
-- Distinct values: 50,000 / Total: 1,000,000 = 0.05
-- Each customer has ~20 orders on average
-- Index is moderately useful
SELECT * FROM orders WHERE customer_id = 42; -- Returns ~20 rows

-- LOW selectivity: status
-- Distinct values: 5 / Total: 1,000,000 = 0.000005
-- Each status has ~200,000 rows
-- Index on status alone is almost useless — MySQL may prefer a full table scan
SELECT * FROM orders WHERE status = 'pending'; -- Returns ~200,000 rows

-- Check selectivity of your columns:
SELECT
    COUNT(DISTINCT order_number) / COUNT(*) AS order_number_selectivity,
    COUNT(DISTINCT customer_id) / COUNT(*)  AS customer_id_selectivity,
    COUNT(DISTINCT status) / COUNT(*)       AS status_selectivity
FROM orders;
-- Result: 1.0000, 0.0500, 0.0000
```

**Rule of thumb:** Index columns with high selectivity first in composite indexes.

---

#### ANALYZE vs EXPLAIN Commands

- **ANALYZE TABLE**: Scans the table, counts key distributions, and stores the statistics. The MySQL optimizer uses these statistics to decide which index to use, join order, etc. Should be run after large data changes (bulk inserts, deletes).
- **EXPLAIN**: Shows the query execution plan **without running** the query. Tells you which indexes MySQL will use, the join type, estimated rows scanned, etc.

**Example — ANALYZE:**

```sql
-- After a bulk import of 500k rows, statistics may be stale
LOAD DATA INFILE '/data/orders.csv' INTO TABLE orders;

-- Update the statistics so the optimizer makes good decisions
ANALYZE TABLE orders;

-- Output:
-- +----------------+---------+----------+----------+
-- | Table          | Op      | Msg_type | Msg_text |
-- +----------------+---------+----------+----------+
-- | mydb.orders    | analyze | status   | OK       |
-- +----------------+---------+----------+----------+
```

**Example — EXPLAIN:**

```sql
EXPLAIN SELECT o.id, o.status, c.name
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE o.status = 'pending'
  AND o.created_at > '2024-01-01';

-- Output (simplified):
-- +----+-------+------+--------------------------+---------+------+--------+-----------------------+
-- | id | table | type | possible_keys            | key     | rows | filtered | Extra               |
-- +----+-------+------+--------------------------+---------+------+--------+-----------------------+
-- |  1 | o     | ref  | idx_status,idx_created   | idx_st  | 5000 | 30.00  | Using where          |
-- |  1 | c     | eq_ref| PRIMARY                 | PRIMARY |    1 | 100.00 | NULL                  |
-- +----+-------+------+--------------------------+---------+------+--------+-----------------------+

-- Key columns to look at:
-- type:    eq_ref (best for joins), ref (good), range (ok), ALL (full scan — bad)
-- key:     Which index MySQL actually chose
-- rows:    Estimated number of rows to examine (lower is better)
-- Extra:   "Using index" (covering index), "Using filesort" (expensive sort)

-- EXPLAIN ANALYZE (MySQL 8.0+) actually runs the query and shows real timings:
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42;
-- -> Index lookup on orders using idx_customer_id (customer_id=42)
--    (cost=4.25 rows=20) (actual time=0.045..0.089 rows=18 loops=1)
```

---

#### WHERE vs HAVING

- **WHERE**: Filters individual rows **before** aggregation (`GROUP BY`). Cannot reference aggregate functions.
- **HAVING**: Filters **groups** (aggregated results) **after** `GROUP BY`. Can reference aggregate functions like `COUNT()`, `SUM()`, `AVG()`.

**Example:**

```sql
CREATE TABLE sales (
    id INT PRIMARY KEY,
    product_id INT,
    customer_id INT,
    amount DECIMAL(10,2),
    sale_date DATE
);

-- WHERE filters rows BEFORE grouping
-- "Only consider sales from 2024"
SELECT product_id, SUM(amount) AS total_sales, COUNT(*) AS num_sales
FROM sales
WHERE sale_date >= '2024-01-01'    -- Filters individual rows first
GROUP BY product_id;

-- HAVING filters groups AFTER grouping
-- "Show only products that sold more than $10,000 total"
SELECT product_id, SUM(amount) AS total_sales, COUNT(*) AS num_sales
FROM sales
GROUP BY product_id
HAVING SUM(amount) > 10000;        -- Filters aggregated groups

-- Combined: WHERE + HAVING
-- "From 2024 sales, show only products with more than 100 orders"
SELECT product_id, SUM(amount) AS total_sales, COUNT(*) AS num_sales
FROM sales
WHERE sale_date >= '2024-01-01'    -- Step 1: filter rows (only 2024)
GROUP BY product_id                -- Step 2: group remaining rows
HAVING COUNT(*) > 100;             -- Step 3: filter groups (>100 orders)

-- Execution order:
-- 1. FROM sales
-- 2. WHERE sale_date >= '2024-01-01'   → reduces rows
-- 3. GROUP BY product_id               → creates groups
-- 4. HAVING COUNT(*) > 100             → removes small groups
-- 5. SELECT                            → produces output

-- Common mistake: using HAVING where WHERE should be used
-- BAD (works but slow — groups everything first, then filters):
SELECT product_id, SUM(amount) FROM sales GROUP BY product_id HAVING product_id = 5;
-- GOOD (filters first, then groups — much faster):
SELECT product_id, SUM(amount) FROM sales WHERE product_id = 5 GROUP BY product_id;
```

---

#### Events on Which a Trigger Can Be Added

Triggers execute automatically in response to DML events on a table. Each trigger is bound to a **timing** (`BEFORE` / `AFTER`) and an **event** (`INSERT`, `UPDATE`, `DELETE`), giving 6 possible combinations.

| Timing | INSERT | UPDATE | DELETE |
|--------|--------|--------|--------|
| BEFORE | ✅ | ✅ | ✅ |
| AFTER  | ✅ | ✅ | ✅ |

- **BEFORE triggers**: Can modify the incoming data or reject the operation. Useful for validation/normalization.
- **AFTER triggers**: Data is already committed. Useful for auditing, cascading changes, or syncing.

**Example:**

```sql
CREATE TABLE products (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100),
    price DECIMAL(10,2),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE product_audit (
    id INT PRIMARY KEY AUTO_INCREMENT,
    product_id INT,
    old_price DECIMAL(10,2),
    new_price DECIMAL(10,2),
    changed_by VARCHAR(100),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- BEFORE INSERT: Validate and normalize data before it's saved
DELIMITER //
CREATE TRIGGER before_product_insert
BEFORE INSERT ON products
FOR EACH ROW
BEGIN
    -- Ensure price is never negative
    IF NEW.price < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Price cannot be negative';
    END IF;
    -- Normalize name (trim whitespace)
    SET NEW.name = TRIM(NEW.name);
END//
DELIMITER ;

-- AFTER UPDATE: Audit trail for price changes
DELIMITER //
CREATE TRIGGER after_product_update
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    IF OLD.price != NEW.price THEN
        INSERT INTO product_audit (product_id, old_price, new_price, changed_by)
        VALUES (OLD.id, OLD.price, NEW.price, CURRENT_USER());
    END IF;
END//
DELIMITER ;

-- BEFORE DELETE: Prevent deletion of critical records
DELIMITER //
CREATE TRIGGER before_product_delete
BEFORE DELETE ON products
FOR EACH ROW
BEGIN
    IF OLD.name = 'Core Product' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot delete the core product';
    END IF;
END//
DELIMITER ;

-- Testing:
INSERT INTO products (name, price) VALUES ('  Widget  ', 29.99);
-- Trigger trims name → stored as 'Widget'

UPDATE products SET price = 34.99 WHERE id = 1;
-- Audit log entry created: old_price=29.99, new_price=34.99

INSERT INTO products (name, price) VALUES ('Test', -5.00);
-- ERROR: Price cannot be negative
```

---

#### Foreign Keys — Why They Are Used

Foreign keys enforce **referential integrity**: they guarantee that a relationship between two tables remains consistent. A foreign key in a child table must reference an existing value in the parent table's primary/unique key.

**Without foreign keys**, your application code is solely responsible for consistency — and bugs, race conditions, or manual DB edits can create orphan records.

**Example:**

```sql
CREATE TABLE customers (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE orders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    total DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Foreign key constraint
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON DELETE RESTRICT        -- Prevent deleting a customer who has orders
        ON UPDATE CASCADE         -- If customer.id changes, update orders too
);

CREATE TABLE order_items (
    id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    product_name VARCHAR(100),
    quantity INT,
    price DECIMAL(10,2),

    CONSTRAINT fk_items_order
        FOREIGN KEY (order_id) REFERENCES orders(id)
        ON DELETE CASCADE         -- Deleting an order removes its items automatically
);

-- What the FK prevents:

-- 1. Inserting an order for a non-existent customer
INSERT INTO orders (customer_id, total) VALUES (9999, 50.00);
-- ERROR 1452: Cannot add or update a child row:
-- a foreign key constraint fails (fk_orders_customer)

-- 2. Deleting a customer who has orders (ON DELETE RESTRICT)
DELETE FROM customers WHERE id = 1;
-- ERROR 1451: Cannot delete or update a parent row:
-- a foreign key constraint fails

-- 3. CASCADE in action: delete an order → items are auto-deleted
DELETE FROM orders WHERE id = 1;
-- All rows in order_items with order_id = 1 are automatically removed

-- ON DELETE options:
-- RESTRICT   → Block the delete (default)
-- CASCADE    → Delete child rows too
-- SET NULL   → Set FK column to NULL in child rows
-- SET DEFAULT→ Set FK column to default (not supported in InnoDB)
-- NO ACTION  → Same as RESTRICT in MySQL
```

---

#### Locks (Pessimistic, Optimistic, Advisory)

##### Pessimistic Locking

Assumes conflicts **will** happen. Locks the row/resource immediately when reading it, preventing any other transaction from modifying it until the lock is released. Use when contention is high.

```sql
-- Scenario: Two users try to book the last seat on a flight

-- Transaction A (User 1):
START TRANSACTION;

-- Lock the row — no other transaction can read FOR UPDATE or modify it
SELECT available_seats FROM flights WHERE id = 42 FOR UPDATE;
-- Result: available_seats = 1

-- If someone else tries SELECT ... FOR UPDATE on the same row, they BLOCK here

UPDATE flights SET available_seats = available_seats - 1 WHERE id = 42;
COMMIT;
-- Lock released

-- Transaction B (User 2) — started at the same time:
START TRANSACTION;
SELECT available_seats FROM flights WHERE id = 42 FOR UPDATE;
-- ⏳ BLOCKED until Transaction A commits

-- After A commits, B gets the lock and sees:
-- available_seats = 0
-- B knows there are no seats left and can handle it gracefully
ROLLBACK;

-- Other lock modes:
-- SELECT ... FOR SHARE (aka LOCK IN SHARE MODE)
--   → Multiple transactions can read, but none can write
-- SELECT ... FOR UPDATE
--   → Exclusive lock: only one transaction can hold it
-- SELECT ... FOR UPDATE NOWAIT (MySQL 8.0+)
--   → Fails immediately if the row is already locked (no waiting)
-- SELECT ... FOR UPDATE SKIP LOCKED (MySQL 8.0+)
--   → Skips locked rows (useful for job queues)
```

**How to choose the lock mode (quick decision guide):**

1. Need to read rows safely, but not modify those rows directly? → `FOR SHARE`
2. Need to read and then update/delete those same rows? → `FOR UPDATE`
3. Need `FOR UPDATE`, but cannot afford waiting? → `FOR UPDATE NOWAIT`
4. Building a multi-worker queue and want each worker to grab different rows? → `FOR UPDATE SKIP LOCKED`

**1) `SELECT ... FOR SHARE`**

- **What it guarantees:** You can read stable row values while blocking concurrent writers.
- **What others can do:** Other transactions can still read (including `FOR SHARE`), but cannot update/delete locked rows until you commit.
- **Typical use case:** Validation before creating dependent records (e.g., check customer/account state).

```sql
-- Tx A: Validate customer before creating an order
START TRANSACTION;
SELECT id, status, credit_limit
FROM customers
WHERE id = 42
FOR SHARE;

-- safe to use values for business checks here
INSERT INTO orders (customer_id, total) VALUES (42, 120.00);
COMMIT;

-- Tx B (at same time):
UPDATE customers SET credit_limit = 5000 WHERE id = 42;
-- waits until Tx A commits
```

**Why this mode:** You protect against concurrent modifications while still allowing high read concurrency.

**2) `SELECT ... FOR UPDATE`**

- **What it guarantees:** Exclusive lock for read-then-write flow on the selected rows.
- **What others can do:** Conflicting lock attempts and writes wait.
- **Typical use case:** Inventory decrement, seat reservation, money transfer.

```sql
-- Reserve one seat safely
START TRANSACTION;
SELECT available_seats
FROM flights
WHERE id = 42
FOR UPDATE;

UPDATE flights
SET available_seats = available_seats - 1
WHERE id = 42 AND available_seats > 0;
COMMIT;
```

**Why this mode:** It prevents lost updates/overselling when multiple transactions target the same row.

**3) `SELECT ... FOR UPDATE NOWAIT` (MySQL 8.0+)**

- **What it guarantees:** Same lock semantics as `FOR UPDATE`, but with immediate failure if lock cannot be acquired.
- **What others can do:** If someone already holds the lock, your statement errors instantly.
- **Typical use case:** Low-latency APIs/UI flows where fast retry is better than blocking.

```sql
START TRANSACTION;
SELECT id, balance
FROM wallets
WHERE user_id = 7
FOR UPDATE NOWAIT;

-- If row is locked elsewhere: immediate error
-- Application pattern: catch error -> return "resource busy, retry"
```

**Why this mode:** Avoids long waits and lock pile-ups under high contention.

**4) `SELECT ... FOR UPDATE SKIP LOCKED` (MySQL 8.0+)**

- **What it guarantees:** Locks only currently free rows and ignores rows already locked by others.
- **What others can do:** Multiple workers can proceed concurrently without blocking each other on the same rows.
- **Typical use case:** Job queue consumers.

```sql
-- Worker grabs next pending jobs without waiting on locked ones
START TRANSACTION;

SELECT id
FROM jobs
WHERE status = 'pending'
ORDER BY id
LIMIT 10
FOR UPDATE SKIP LOCKED;

-- Then mark selected jobs as processing in the same transaction
-- (ids returned above)
UPDATE jobs
SET status = 'processing', worker_id = 3
WHERE id IN (101, 102, 103);

COMMIT;
```

**Why this mode:** Maximizes throughput for parallel workers by eliminating lock wait time on already-claimed rows.

**Practical notes:**

- Use these clauses with `START TRANSACTION`; in autocommit mode, locks are released at statement end.
- Add proper indexes to avoid locking/scanning more rows than intended.
- Keep transactions short to reduce contention and deadlock risk.

##### Optimistic Locking

Assumes conflicts are **rare**. Does NOT lock the row. Instead, it detects conflicts at write time by checking if the data changed since it was read, typically using a `version` column or `updated_at` timestamp.

```sql
-- Scenario: Two admins editing the same product's price simultaneously

CREATE TABLE products (
    id INT PRIMARY KEY,
    name VARCHAR(100),
    price DECIMAL(10,2),
    version INT DEFAULT 1          -- Version column for optimistic locking
);

-- Admin A reads the product:
SELECT id, name, price, version FROM products WHERE id = 1;
-- Result: id=1, name='Widget', price=29.99, version=3

-- Admin B also reads the same product at the same time:
SELECT id, name, price, version FROM products WHERE id = 1;
-- Result: id=1, name='Widget', price=29.99, version=3

-- Admin A updates (includes version check in WHERE clause):
UPDATE products
SET price = 34.99, version = version + 1
WHERE id = 1 AND version = 3;
-- Affected rows: 1 ✅ — success, version is now 4

-- Admin B tries to update (still has version=3 from their read):
UPDATE products
SET price = 39.99, version = version + 1
WHERE id = 1 AND version = 3;
-- Affected rows: 0 ❌ — version is now 4, not 3!
-- Application detects 0 affected rows → tells Admin B:
-- "This product was modified by someone else. Please refresh and try again."

-- In application code (PHP/pseudo-code):
-- $affectedRows = $db->execute($updateQuery);
-- if ($affectedRows === 0) {
--     throw new OptimisticLockException('Concurrent modification detected');
-- }
```

##### Advisory Locks

Advisory locks are **cooperative** — the database does NOT enforce them on data access. They are application-level signals that processes voluntarily check. Useful for coordinating work between application instances.

```sql
-- Scenario: Ensure only one cron job processes email queue at a time

-- Process A (Cron Job 1):
SELECT GET_LOCK('email_queue_processor', 10);
-- Returns 1 → Lock acquired (waited up to 10 seconds if needed)
-- Now safely process the email queue...

-- Process B (Cron Job 2) starts at the same time:
SELECT GET_LOCK('email_queue_processor', 10);
-- Returns 0 → Could not acquire lock within 10 seconds (A holds it)
-- Process B skips this run or retries later

-- Process A finishes:
SELECT RELEASE_LOCK('email_queue_processor');
-- Returns 1 → Lock released

-- Check if a lock is held (without acquiring):
SELECT IS_FREE_LOCK('email_queue_processor');
-- Returns 1 if free, 0 if held

-- Key differences from row-level locks:
-- 1. Advisory locks are NOT tied to any table or row
-- 2. They persist until explicitly released or the session ends
-- 3. They are identified by a string name, not a row
-- 4. The DB never checks them automatically — your app must check

-- Real-world use cases:
-- • Preventing duplicate cron job execution
-- • Coordinating schema migrations across multiple app servers
-- • Implementing distributed mutexes without external tools (Redis, etc.)
-- • Ensuring only one process rebuilds a cache at a time
```

##### Comparison Summary

| Aspect | Pessimistic | Optimistic | Advisory |
|---|---|---|---|
| **Locks data?** | Yes, immediately | No (checks at write time) | No (voluntary) |
| **Best when** | High contention | Low contention | Cross-process coordination |
| **Performance** | Lower (blocking) | Higher (no blocking) | Depends on usage |
| **Conflict handling** | Prevention | Detection | Application-defined |
| **MySQL syntax** | `FOR UPDATE` / `FOR SHARE` | `WHERE version = N` | `GET_LOCK()` / `RELEASE_LOCK()` |
