Deadlock se dešava kada dve ili više transakcija čekaju jedna na drugu da otpuste zaključavanje. Nijedna ne može nastaviti, pa su zauvek zaglavljene. InnoDB engine MySQL-a detektuje deadlock-ove i rešava ih poništavanjem jedne od transakcija.

### Kako se deadlock dešava

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

InnoDB detektuje ovo kružno čekanje i poništava jednu od transakcija (obično onu koja je uradila najmanje posla). Druga transakcija nastavlja.

```text
ERROR 1213 (40001): Deadlock found when trying to get lock; try restarting transaction
```

### Kako InnoDB detektuje deadlock-ove

InnoDB koristi **wait-for graph**. Prati koja transakcija čeka na koje zaključavanje. Kada detektuje ciklus u grafu, odmah poništava jednu transakciju. Detekcija je skoro trenutna.

```text
Wait-for graph:
  Transaction A → waits for → Transaction B
  Transaction B → waits for → Transaction A
  → Cycle detected → Deadlock!
```

### Dijagnostikovanje deadlock-ova

#### SHOW ENGINE INNODB STATUS

Ovo je glavni alat za debagovanje deadlock-ova:

```sql
SHOW ENGINE INNODB STATUS\G
```

Izlaz uključuje sekciju `LATEST DETECTED DEADLOCK`:

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

#### Omogući logovanje deadlock-ova

```sql
-- Log all deadlocks to the error log
SET GLOBAL innodb_print_all_deadlocks = ON;
```

### Uobičajeni uzroci deadlock-ova

#### 1. Nedosledan redosled zaključavanja

Najčešći uzrok. Dve transakcije zaključavaju iste redove, ali u različitom redosledu.

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

#### 2. Nedostajući ili neefikasni indeksi

Bez odgovarajućeg indeksa, jednostavan UPDATE može zaključati mnogo redova (ili čak celu tabelu) umesto samo jednog:

```sql
-- No index on 'status' column → table scan → locks many rows
UPDATE orders SET processed = 1 WHERE status = 'pending';

-- With index → only locks matching rows
CREATE INDEX idx_status ON orders (status);
```

#### 3. Duge transakcije

Što duže transakcija traje, duže drži zaključavanja, i veća je verovatnoća deadlock-a.

#### 4. Gap lock-ovi

InnoDB koristi gap lock-ove u izolacionom nivou REPEATABLE READ. Ova zaključavanja sprečavaju umetanje u opsege između vrednosti indeksa i mogu uzrokovati deadlock-ove:

```sql
-- Transaction A
SELECT * FROM products WHERE price BETWEEN 100 AND 200 FOR UPDATE;
-- Locks the gap between 100 and 200

-- Transaction B
INSERT INTO products (name, price) VALUES ('Widget', 150);
-- Waits for gap lock → potential deadlock if A also inserts in B's locked range
```

### Kako sprečiti deadlock-ove

#### 1. Uvek zaključavajte redove u istom redosledu

Ovo je najefikasnija prevencija:

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

#### 2. Kratke transakcije

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

#### 3. Koristite odgovarajuće indekse

Pobrinite se da UPDATE i DELETE naredbe koriste indekse kako bi zaključale samo neophodne redove:

```sql
-- Check what locks a query uses
EXPLAIN SELECT * FROM orders WHERE customer_id = 123 FOR UPDATE;
-- Make sure it uses an index, not a full table scan
```

#### 4. Ponovni pokušaj pri deadlock-u

Pošto deadlock-ovi mogu da se dogode čak i uz dobar dizajn, uvek implementirajte logiku ponovnog pokušaja:

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

#### 5. Niži nivo izolacije (kada je prikladno)

```sql
-- READ COMMITTED has fewer gap locks than REPEATABLE READ
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
```

Ovo smanjuje deadlock-ove, ali menja garancije konzistentnosti. Koristite samo ako vaša aplikacija toleriše non-repeatable read-ove.

### Realni scenario

Aplikacija za e-commerce obrađuje mnoge istovremene narudžbine. Svako ažuriranje narudžbine modifikuje i tabelu `orders` i tabelu `inventory`. Korisnici prijavljuju povremene greške "Deadlock".

Istraživanje sa `SHOW ENGINE INNODB STATUS` pokazuje:

```text
Transaction A: UPDATE inventory WHERE product_id=5, then UPDATE orders WHERE id=100
Transaction B: UPDATE orders WHERE id=101 (coincidentally locks a gap), then UPDATE inventory WHERE product_id=5
```

Rešenje:

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

Nakon ove promene, deadlock-ovi su značajno smanjeni jer sve transakcije zaključavaju tabelu inventara pre tabele narudžbina.

### Zaključak

Deadlock-ovi se dešavaju kada dve transakcije čekaju jedna na drugu zaključavanja u kružnoj zavisnosti. InnoDB ih automatski detektuje i poništava jednu transakciju. Sprečite ih: zaključavanjem redova u konzistentnom redosledu, kratkim transakcijama, korišćenjem odgovarajućih indeksa i implementacijom logike ponovnog pokušaja. Koristite `SHOW ENGINE INNODB STATUS` i `innodb_print_all_deadlocks` za dijagnosticiranje problema.
