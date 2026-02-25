Locking is a mechanism to control concurrent access to data. When multiple transactions try to read and write the same data, locks prevent conflicts and data corruption. There are two main strategies: **optimistic** and **pessimistic** locking.

### Pessimistic Locking

Pessimistic locking assumes that conflicts **will** happen. It locks the data immediately when reading it, preventing anyone else from modifying it until the transaction is done.

#### How It Works

```sql
-- Transaction A: Lock the row immediately
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;  -- Locks row id=1
-- ... do calculations ...
UPDATE accounts SET balance = 900 WHERE id = 1;
COMMIT;  -- Lock released

-- Transaction B (at the same time):
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;  -- WAITS until Transaction A commits
```

#### Types of Pessimistic Locks in MySQL

```sql
-- Exclusive lock (FOR UPDATE) — blocks both reads and writes
SELECT * FROM products WHERE id = 5 FOR UPDATE;

-- Shared lock (FOR SHARE / LOCK IN SHARE MODE) — allows reads, blocks writes
SELECT * FROM products WHERE id = 5 FOR SHARE;
```

| Lock Type | Other reads? | Other writes? |
|-----------|-------------|---------------|
| `FOR UPDATE` | Blocked | Blocked |
| `FOR SHARE` | Allowed | Blocked |

#### Pessimistic Locking in Doctrine

```php
use Doctrine\DBAL\LockMode;

// LockMode::PESSIMISTIC_WRITE — SELECT ... FOR UPDATE
$product = $em->find(Product::class, $id, LockMode::PESSIMISTIC_WRITE);
$product->decreaseStock(1);
$em->flush();

// LockMode::PESSIMISTIC_READ — SELECT ... FOR SHARE
$product = $em->find(Product::class, $id, LockMode::PESSIMISTIC_READ);

// With DQL
$query = $em->createQuery('SELECT p FROM Product p WHERE p.id = :id');
$query->setParameter('id', $id);
$query->setLockMode(LockMode::PESSIMISTIC_WRITE);
$product = $query->getSingleResult();
```

### Optimistic Locking

Optimistic locking assumes that conflicts **rarely** happen. It does not lock the data when reading. Instead, it checks at update time whether someone else changed the data since it was read.

#### How It Works

The table has a **version** column (integer or timestamp). When updating, the application checks that the version has not changed:

```sql
-- Step 1: Read the data (no lock)
SELECT id, name, balance, version FROM accounts WHERE id = 1;
-- Returns: id=1, balance=1000, version=5

-- Step 2: Update with version check
UPDATE accounts 
SET balance = 900, version = version + 1 
WHERE id = 1 AND version = 5;  -- Check that version is still 5

-- If the update affects 0 rows → someone else changed the data → conflict!
-- If the update affects 1 row → success, version is now 6
```

#### Optimistic Locking in Doctrine

```php
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity]
class Product
{
    #[ORM\Id]
    #[ORM\Column]
    private int $id;

    #[ORM\Column]
    private string $name;

    #[ORM\Column]
    private int $stock;

    #[ORM\Version]  // ← This enables optimistic locking
    #[ORM\Column]
    private int $version;
}
```

When someone else changes the entity between your read and your write, Doctrine throws an exception:

```php
try {
    $product = $em->find(Product::class, 1);
    $product->decreaseStock(1);
    $em->flush();
} catch (OptimisticLockException $e) {
    // Another transaction modified this product!
    // Option 1: Reload and retry
    // Option 2: Show error to the user
    echo "The product was modified by someone else. Please try again.";
}
```

#### Explicit Version Check in Doctrine

You can also check the version manually:

```php
// Frontend sends the version it loaded
$expectedVersion = $request->get('version'); // e.g., 5

try {
    $product = $em->find(Product::class, $id);
    $em->lock($product, LockMode::OPTIMISTIC, $expectedVersion);
    
    $product->setPrice($newPrice);
    $em->flush();
} catch (OptimisticLockException $e) {
    // Version mismatch — someone else edited the product
    return new JsonResponse(['error' => 'Data was modified. Please reload and try again.'], 409);
}
```

### Comparison

| Feature | Pessimistic | Optimistic |
|---------|-------------|------------|
| When it locks | Immediately on read | Never locks — checks at write time |
| Conflict detection | Prevents conflicts by blocking | Detects conflicts after they happen |
| Performance (low contention) | Slower — unnecessary locking overhead | Faster — no locking overhead |
| Performance (high contention) | Better — avoids retries | Slower — many retries needed |
| Database involvement | Requires `FOR UPDATE` / `FOR SHARE` | Requires version column |
| Risk of deadlocks | Yes | No |
| Best for | High contention, short transactions | Low contention, long transactions |

### When to Use Each

#### Use Pessimistic Locking When:

- Many transactions compete for the same rows (high contention)
- The cost of a failed transaction is high (e.g., financial operations)
- Transactions are short

```php
// Financial transfer — use pessimistic locking
// Two accounts must be updated atomically, many concurrent transfers
$em->beginTransaction();
try {
    $from = $em->find(Account::class, $fromId, LockMode::PESSIMISTIC_WRITE);
    $to = $em->find(Account::class, $toId, LockMode::PESSIMISTIC_WRITE);
    
    $from->withdraw($amount);
    $to->deposit($amount);
    
    $em->flush();
    $em->commit();
} catch (\Exception $e) {
    $em->rollback();
    throw $e;
}
```

#### Use Optimistic Locking When:

- Conflicts are rare (low contention)
- Transactions can be long (e.g., user editing a form for minutes)
- You want to avoid database-level locking

```php
// CMS — user edits an article
// Conflicts are rare (few editors), editing takes minutes
$article = $em->find(Article::class, $id);
// ... user edits the article in browser for 5 minutes ...

try {
    $em->lock($article, LockMode::OPTIMISTIC, $originalVersion);
    $article->setContent($newContent);
    $em->flush();
} catch (OptimisticLockException $e) {
    // Another editor saved changes while this user was editing
    // Show a merge/conflict resolution screen
}
```

### Real Scenario

An online store has a product with 3 items in stock. Two customers try to buy at the same time.

#### With Optimistic Locking:

```php
// Customer A reads: stock = 3, version = 1
// Customer B reads: stock = 3, version = 1

// Customer A submits order:
UPDATE products SET stock = 2, version = 2 WHERE id = 1 AND version = 1;
// → 1 row affected → success! Version is now 2.

// Customer B submits order:
UPDATE products SET stock = 2, version = 2 WHERE id = 1 AND version = 1;
// → 0 rows affected → version changed! OptimisticLockException!
// Customer B must reload (stock = 2, version = 2) and try again:
UPDATE products SET stock = 1, version = 3 WHERE id = 1 AND version = 2;
// → 1 row affected → success!
```

#### With Pessimistic Locking:

```php
// Customer A:
SELECT * FROM products WHERE id = 1 FOR UPDATE; -- Locks the row
// stock = 3
UPDATE products SET stock = 2 WHERE id = 1;
COMMIT; -- Lock released

// Customer B (waits until A commits):
SELECT * FROM products WHERE id = 1 FOR UPDATE; -- Now gets the lock
// stock = 2 (already updated by A)
UPDATE products SET stock = 1 WHERE id = 1;
COMMIT;
```

Both approaches give the correct result. Pessimistic is simpler (no retries needed). Optimistic is faster when conflicts are rare.

### Conclusion

Pessimistic locking uses `SELECT ... FOR UPDATE` to lock rows immediately — it prevents conflicts but can cause deadlocks and reduces concurrency. Optimistic locking uses a version column and checks at update time — it allows more concurrency but requires handling conflicts (retries or user notification). Use pessimistic locking for high-contention scenarios like financial operations. Use optimistic locking for low-contention scenarios like content editing. Doctrine supports both through `LockMode::PESSIMISTIC_WRITE` and `#[ORM\Version]`.
