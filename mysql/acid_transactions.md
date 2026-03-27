A transaction is a group of SQL operations that are treated as one single unit of work. Either all operations succeed (COMMIT), or all are undone (ROLLBACK). ACID is an acronym for four properties that every transaction must guarantee.

### A — Atomicity (All or Nothing)

Atomicity means that all operations in a transaction are treated as one indivisible action. If any operation fails, the entire transaction is rolled back — the database looks as if nothing happened.

```sql
START TRANSACTION;

-- Upit 1: Withdraw money from account A
UPDATE accounts SET balance = balance - 1000 WHERE id = 1;

-- Upit 2: Add money to account B
UPDATE accounts SET balance = balance + 1000 WHERE id = 2;

-- If Upit 2 fails, Upit 1 is also undone
COMMIT;
```

If the server crashes between Upit 1 and Upit 2, the database will automatically roll back the incomplete transaction when it restarts. Money does not disappear.

### C — Consistency

Consistency means the database moves from one valid state to another valid state. A transaction cannot leave the database in a broken state where business rules or constraints are violated.

```sql
-- Table has a CHECK constraint: balance >= 0
ALTER TABLE accounts ADD CONSTRAINT chk_balance CHECK (balance >= 0);

START TRANSACTION;
UPDATE accounts SET balance = balance - 5000 WHERE id = 1;
-- If account 1 only has 3000, this violates the CHECK constraint
-- The transaction is rejected — database stays consistent
COMMIT;
```

Consistency is enforced through:

- **Constraints** — NOT NULL, UNIQUE, FOREIGN KEY, CHECK
- **Triggers** — custom validation logic
- **Application logic** — your PHP code validates data before saving

### I — Isolation

Isolation means that concurrent transactions do not interfere with each other. Each transaction behaves as if it is the only one running, even when many transactions run at the same time.

**The problem without isolation:**

```text
Transaction A: reads balance = 1000
Transaction B: reads balance = 1000
Transaction A: sets balance = 1000 - 200 = 800
Transaction B: sets balance = 1000 - 300 = 700  ← Wrong! Should be 500
```

Both transactions read the old value. The $200 withdrawal is lost. This is called a **lost update**.

**Isolation levels** control how strictly transactions are separated:

| Level | Dirty Read | Non-Repeatable Read | Phantom Read | Performance |
|-------|-----------|-------------------|-------------|-------------|
| READ UNCOMMITTED | Yes | Yes | Yes | Fastest |
| READ COMMITTED | No | Yes | Yes | Fast |
| REPEATABLE READ | No | No | Yes | Medium |
| SERIALIZABLE | No | No | No | Slowest |

- **Dirty read** — reading data from another transaction that has not been committed yet
- **Non-repeatable read** — reading the same row twice and getting different values because another transaction changed it
- **Phantom read** — running the same query twice and getting different rows because another transaction inserted/deleted rows

MySQL InnoDB uses **REPEATABLE READ** by default. PostgreSQL uses **READ COMMITTED** by default.

```sql
-- Check current isolation level
SELECT @@transaction_isolation;

-- Set isolation level for current session
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
```

### D — Durability

Durability means that once a transaction is committed, the data is permanently saved. Even if the server crashes, loses power, or the disk fails — the committed data survives.

How databases ensure durability:

- **Write-Ahead Log (WAL)** — changes are first written to a log file on disk, then to the actual data files. If the server crashes, it replays the log on restart
- **Flushing to disk** — the COMMIT command forces data to be written to persistent storage before returning success to the client
- **Replication** — data is copied to other servers for redundancy

```sql
-- After COMMIT returns, the data is guaranteed to be on disk
START TRANSACTION;
INSERT INTO payments (user_id, amount) VALUES (1, 500.00);
COMMIT;  -- Data is now durable — survives a crash
```

### Transaction in PHP with PDO

```php
$pdo = new PDO('mysql:host=localhost;dbname=bank', 'root', 'pass');
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

try {
    $pdo->beginTransaction();
    
    // Withdraw from sender
    $stmt = $pdo->prepare('UPDATE accounts SET balance = balance - :amount WHERE id = :id');
    $stmt->execute(['amount' => 1000, 'id' => 1]);
    
    // Check if sender had enough money
    $stmt = $pdo->prepare('SELECT balance FROM accounts WHERE id = :id');
    $stmt->execute(['id' => 1]);
    $balance = $stmt->fetchColumn();
    
    if ($balance < 0) {
        throw new RuntimeException('Insufficient funds');
    }
    
    // Deposit to receiver
    $stmt = $pdo->prepare('UPDATE accounts SET balance = balance + :amount WHERE id = :id');
    $stmt->execute(['amount' => 1000, 'id' => 2]);
    
    $pdo->commit();
    echo "Transfer successful";
    
} catch (Exception $e) {
    $pdo->rollBack();
    echo "Transfer failed: " . $e->getMessage();
}
```

### Transaction in Doctrine (Symfony)

```php
use Doctrine\ORM\EntityManagerInterface;

class TransferService
{
    public function __construct(private EntityManagerInterface $em) {}
    
    public function transfer(int $fromId, int $toId, float $amount): void
    {
        $this->em->wrapInTransaction(function () use ($fromId, $toId, $amount) {
            $from = $this->em->find(Account::class, $fromId);
            $to = $this->em->find(Account::class, $toId);
            
            if ($from->getBalance() < $amount) {
                throw new InsufficientFundsException();
            }
            
            $from->withdraw($amount);
            $to->deposit($amount);
            
            // flush() is called automatically by wrapInTransaction
        });
    }
}
```

### Common Interview Questions About ACID

**Q: Which ACID property prevents money from disappearing during a bank transfer?**
A: Atomicity — if the deposit fails, the withdrawal is rolled back too.

**Q: What happens if two users buy the last item in stock at the same time?**
A: Isolation — with proper locking (SELECT ... FOR UPDATE), only one transaction will proceed. The other will see that stock is 0 and fail.

**Q: Why is SERIALIZABLE not used by default?**
A: Performance — SERIALIZABLE forces transactions to run one after another, which is very slow under high concurrency. REPEATABLE READ provides a good balance of safety and performance.

### Real Scenario

You are building a ticket booking system. When a user books a seat:

```php
$this->em->wrapInTransaction(function () use ($seatId, $userId) {
    // Lock the seat row to prevent double booking (Atomicity + Isolation)
    $seat = $this->em->createQuery(
        'SELECT s FROM Seat s WHERE s.id = :id AND s.status = :status'
    )
    ->setParameter('id', $seatId)
    ->setParameter('status', 'available')
    ->setLockMode(LockMode::PESSIMISTIC_WRITE)  // SELECT ... FOR UPDATE
    ->getOneOrNullResult();
    
    if ($seat === null) {
        throw new SeatNotAvailableException();
    }
    
    $seat->setStatus('booked');
    $seat->setBookedBy($userId);
    
    // Deduct payment
    $user = $this->em->find(User::class, $userId);
    $user->deductBalance($seat->getPrice());
    
    // If anything fails, seat goes back to "available" and money is refunded (Atomicity)
    // After COMMIT, the booking is permanent (Durability)
    // Other users see consistent data (Consistency)
});
```

### Conclusion

ACID ensures reliable database transactions. **Atomicity** guarantees all-or-nothing execution. **Consistency** keeps the database in a valid state by enforcing constraints. **Isolation** prevents concurrent transactions from interfering with each other — MySQL defaults to REPEATABLE READ. **Durability** ensures committed data survives crashes through write-ahead logs. In PHP, use `PDO::beginTransaction()` + `commit()`/`rollBack()` or Doctrine's `wrapInTransaction()` to work with transactions safely.

> See also: [Entity Relationships](entity_relationships.md), [Deadlocks in MySQL](../highload/deadlocks_in_mysql.md), [Optimistic/Pessimistic Lock](../highload/optimistic_pessimistic_lock.md)
