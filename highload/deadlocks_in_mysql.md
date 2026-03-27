A deadlock happens when two or more transactions are waiting for each other to release a lock. Neither can proceed, so they are stuck forever. MySQL's InnoDB engine detects deadlocks and resolves them by killing one of the transactions.

### How a Deadlock Happens

```text
Transaction A:                          Transaction B:
1. UPDATE accounts SET balance=100      
   WHERE id=1;                          
   → Locks row id=1                     
                                        2. UPDATE accounts SET balance=200
                                           WHERE id=2;
                                           → Locks row id=2
3. UPDATE accounts SET balance=50       
   WHERE id=2;                          
   → Waits for lock on row id=2        
   (held by Transaction B)              
                                        4. UPDATE accounts SET balance=150
                                           WHERE id=1;
                                           → Waits for lock on row id=1
                                           (held by Transaction A)

→ DEADLOCK! Both are waiting for each other.
```

InnoDB detects this circular wait and rolls back one of the transactions (typically the one that has done the least work). The other transaction continues.

```text
ERROR 1213 (40001): Deadlock found when trying to get lock; try restarting transaction
```

### How InnoDB Detects Deadlocks

InnoDB uses a **wait-for graph**. It tracks which transaction is waiting for which lock. When it detects a cycle in the graph, it immediately rolls back one transaction. The detection is near-instant.

```text
Wait-for graph:
  Transaction A → waits for → Transaction B
  Transaction B → waits for → Transaction A
  → Cycle detected → Deadlock!
```

### Diagnosing Deadlocks

#### SHOW ENGINE INNODB STATUS

This is the main tool for debugging deadlocks:

```sql
SHOW ENGINE INNODB STATUS\G
```

The output includes a `LATEST DETECTED DEADLOCK` section:

```text
------------------------
LATEST DETECTED DEADLOCK
------------------------
*** (1) TRANSACTION:
TRANSACTION 12345, ACTIVE 2 sec starting index read
mysql tables in use 1, locked 1
LOCK WAIT 3 lock struct(s), heap size 1136, 2 row lock(s)
MySQL thread id 10, query id 100
UPDATE accounts SET balance = 50 WHERE id = 2

*** (1) HOLDS THE LOCK(S):
RECORD LOCKS space id 5 page no 3 n bits 72 index PRIMARY of table `mydb`.`accounts`
lock_mode X locks rec but not gap
Record lock: id=1

*** (1) WAITING FOR THIS LOCK TO BE GRANTED:
RECORD LOCKS space id 5 page no 3 n bits 72 index PRIMARY of table `mydb`.`accounts`
lock_mode X locks rec but not gap
Record lock: id=2

*** (2) TRANSACTION:
...
```

#### Enable Deadlock Logging

```sql
-- Log all deadlocks to the error log
SET GLOBAL innodb_print_all_deadlocks = ON;
```

### Common Causes of Deadlocks

#### 1. Inconsistent Lock Ordering

The most common cause. Two transactions lock the same rows but in different order.

```php
// Transaction A: locks user 1 first, then user 2
$pdo->beginTransaction();
$pdo->exec("UPDATE users SET balance = balance - 100 WHERE id = 1"); // Lock user 1
$pdo->exec("UPDATE users SET balance = balance + 100 WHERE id = 2"); // Wait for user 2

// Transaction B: locks user 2 first, then user 1
$pdo->beginTransaction();
$pdo->exec("UPDATE users SET balance = balance - 50 WHERE id = 2");  // Lock user 2
$pdo->exec("UPDATE users SET balance = balance + 50 WHERE id = 1");  // Wait for user 1
// → DEADLOCK
```

#### 2. Missing or Inefficient Indexes

Without a proper index, a simple UPDATE can lock many rows (or even the entire table) instead of just one:

```sql
-- No index on 'status' column → table scan → locks many rows
UPDATE orders SET processed = 1 WHERE status = 'pending';

-- With index → only locks matching rows
CREATE INDEX idx_status ON orders (status);
```

#### 3. Long Transactions

The longer a transaction runs, the longer it holds locks, and the more likely a deadlock becomes.

#### 4. Gap Locks

InnoDB uses gap locks in the REPEATABLE READ isolation level. These locks prevent inserts into ranges between index values and can cause deadlocks:

```sql
-- Transaction A
SELECT * FROM products WHERE price BETWEEN 100 AND 200 FOR UPDATE;
-- Locks the gap between 100 and 200

-- Transaction B
INSERT INTO products (name, price) VALUES ('Widget', 150);
-- Waits for gap lock → potential deadlock if A also inserts in B's locked range
```

### How to Prevent Deadlocks

#### 1. Always Lock Rows in the Same Order

This is the most effective prevention:

```php
// Always sort IDs before updating
function transferMoney(PDO $pdo, int $fromId, int $toId, float $amount): void
{
    // Always lock the lower ID first
    $first = min($fromId, $toId);
    $second = max($fromId, $toId);
    
    $pdo->beginTransaction();
    try {
        // Lock in consistent order
        $pdo->exec("SELECT balance FROM accounts WHERE id = $first FOR UPDATE");
        $pdo->exec("SELECT balance FROM accounts WHERE id = $second FOR UPDATE");
        
        $pdo->exec("UPDATE accounts SET balance = balance - $amount WHERE id = $fromId");
        $pdo->exec("UPDATE accounts SET balance = balance + $amount WHERE id = $toId");
        
        $pdo->commit();
    } catch (\PDOException $e) {
        $pdo->rollBack();
        throw $e;
    }
}
```

#### 2. Keep Transactions Short

```php
// Bad — long transaction with external API call
$pdo->beginTransaction();
$pdo->exec("UPDATE orders SET status = 'processing' WHERE id = 1");
$result = $paymentGateway->charge($amount); // This can take seconds!
$pdo->exec("UPDATE orders SET status = 'paid' WHERE id = 1");
$pdo->commit();

// Better — minimize lock time
$result = $paymentGateway->charge($amount); // Do slow work BEFORE the transaction
$pdo->beginTransaction();
$pdo->exec("UPDATE orders SET status = 'paid', payment_id = '{$result->id}' WHERE id = 1");
$pdo->commit();
```

#### 3. Use Proper Indexes

Make sure UPDATE and DELETE statements use indexes so they lock only the necessary rows:

```sql
-- Check what locks a query uses
EXPLAIN SELECT * FROM orders WHERE customer_id = 123 FOR UPDATE;
-- Make sure it uses an index, not a full table scan
```

#### 4. Retry on Deadlock

Since deadlocks can happen even with good design, always implement retry logic:

```php
function executeWithRetry(PDO $pdo, callable $operation, int $maxRetries = 3): mixed
{
    $attempts = 0;
    
    while (true) {
        try {
            $pdo->beginTransaction();
            $result = $operation($pdo);
            $pdo->commit();
            return $result;
        } catch (\PDOException $e) {
            $pdo->rollBack();
            $attempts++;
            
            // Error code 40001 = deadlock
            if ($e->getCode() === '40001' && $attempts < $maxRetries) {
                usleep(random_int(1000, 10000)); // Random delay before retry
                continue;
            }
            
            throw $e;
        }
    }
}

// Usage
executeWithRetry($pdo, function (PDO $pdo) {
    $pdo->exec("UPDATE accounts SET balance = balance - 100 WHERE id = 1");
    $pdo->exec("UPDATE accounts SET balance = balance + 100 WHERE id = 2");
});
```

#### 5. Lower Isolation Level (When Appropriate)

```sql
-- READ COMMITTED has fewer gap locks than REPEATABLE READ
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
```

This reduces deadlocks but changes the consistency guarantees. Only use if your application tolerates non-repeatable reads.

### Real Scenario

An e-commerce application processes many concurrent orders. Each order update modifies both the `orders` table and the `inventory` table. Users report occasional "Deadlock" errors.

Investigation with `SHOW ENGINE INNODB STATUS` shows:

```text
Transaction A: UPDATE inventory WHERE product_id=5, then UPDATE orders WHERE id=100
Transaction B: UPDATE orders WHERE id=101 (coincidentally locks a gap), then UPDATE inventory WHERE product_id=5
```

Fix:

```php
class OrderService
{
    public function processOrder(Order $order): void
    {
        // 1. Always lock in the same order: inventory first, then orders
        // 2. Keep transaction short
        // 3. Add retry logic
        
        executeWithRetry($this->pdo, function (PDO $pdo) use ($order) {
            // Lock inventory first (consistent order)
            $stmt = $pdo->prepare("SELECT quantity FROM inventory WHERE product_id = ? FOR UPDATE");
            $stmt->execute([$order->getProductId()]);
            $stock = $stmt->fetchColumn();
            
            if ($stock < $order->getQuantity()) {
                throw new InsufficientStockException();
            }
            
            // Update inventory
            $pdo->prepare("UPDATE inventory SET quantity = quantity - ? WHERE product_id = ?")
                ->execute([$order->getQuantity(), $order->getProductId()]);
            
            // Then update order
            $pdo->prepare("UPDATE orders SET status = 'confirmed' WHERE id = ?")
                ->execute([$order->getId()]);
        });
    }
}
```

After this change, deadlocks drop significantly because all transactions lock the inventory table before the orders table.

### Conclusion

Deadlocks happen when two transactions wait for each other's locks in a circular dependency. InnoDB detects them automatically and rolls back one transaction. Prevent them by: locking rows in consistent order, keeping transactions short, using proper indexes, and implementing retry logic. Use `SHOW ENGINE INNODB STATUS` and `innodb_print_all_deadlocks` to diagnose issues.
