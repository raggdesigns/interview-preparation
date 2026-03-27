Transakcija je grupa SQL operacija koje se tretiraju kao jedna jedinica posla. Ili sve operacije uspevaju (COMMIT), ili su sve poništene (ROLLBACK). ACID je akronim za četiri svojstva koja svaka transakcija mora garantovati.

### A — Atomičnost (Sve ili ništa)

Atomičnost znači da se sve operacije u transakciji tretiraju kao jedna nedeljiva akcija. Ako bilo koja operacija ne uspe, cela transakcija se poništava — baza podataka izgleda kao da se ništa nije desilo.

```sql
START TRANSACTION;

-- Upit 1: Povuci novac sa računa A
UPDATE accounts SET balance = balance - 1000 WHERE id = 1;

-- Upit 2: Dodaj novac na račun B
UPDATE accounts SET balance = balance + 1000 WHERE id = 2;

-- Ako Upit 2 ne uspe, Upit 1 je takođe poništen
COMMIT;
```

Ako server padne između Upita 1 i Upita 2, baza podataka će automatski poništiti nepotpunu transakciju kada se ponovo pokrene. Novac ne nestaje.

### C — Konzistentnost

Konzistentnost znači da baza podataka prelazi iz jednog validnog stanja u drugo validno stanje. Transakcija ne može ostaviti bazu podataka u pokvarenom stanju gde su poslovna pravila ili ograničenja narušena.

```sql
-- Tabela ima CHECK ograničenje: balance >= 0
ALTER TABLE accounts ADD CONSTRAINT chk_balance CHECK (balance >= 0);

START TRANSACTION;
UPDATE accounts SET balance = balance - 5000 WHERE id = 1;
-- Ako račun 1 ima samo 3000, ovo krši CHECK ograničenje
-- Transakcija je odbijena — baza podataka ostaje konzistentna
COMMIT;
```

Konzistentnost se sprovodi kroz:
- **Ograničenja** — NOT NULL, UNIQUE, FOREIGN KEY, CHECK
- **Trigger-e** — prilagođena validaciona logika
- **Logiku aplikacije** — PHP kod validira podatke pre čuvanja

### I — Izolacija

Izolacija znači da se konkurentne transakcije ne mešaju jedna sa drugom. Svaka transakcija se ponaša kao da je jedina koja radi, čak i kada se mnoge transakcije izvršavaju u isto vreme.

**Problem bez izolacije:**

```
Transakcija A: čita balance = 1000
Transakcija B: čita balance = 1000
Transakcija A: postavlja balance = 1000 - 200 = 800
Transakcija B: postavlja balance = 1000 - 300 = 700  ← Pogrešno! Treba biti 500
```

Obe transakcije čitaju staru vrednost. Povlačenje od 200 je izgubljeno. Ovo se zove **izgubljena izmena**.

**Nivoi izolacije** kontrolišu koliko strogo su transakcije razdvojene:

| Nivo | Prljavo čitanje | Ne-ponovljivo čitanje | Fantomsko čitanje | Performanse |
|-------|-----------|-------------------|-------------|-------------|
| READ UNCOMMITTED | Da | Da | Da | Najbrže |
| READ COMMITTED | Ne | Da | Da | Brzo |
| REPEATABLE READ | Ne | Ne | Da | Srednje |
| SERIALIZABLE | Ne | Ne | Ne | Najsporije |

- **Prljavo čitanje** — čitanje podataka iz druge transakcije koja još nije commitovana
- **Ne-ponovljivo čitanje** — čitanje istog reda dva puta i dobijanje različitih vrednosti jer ih je druga transakcija promenila
- **Fantomsko čitanje** — izvršavanje istog upita dva puta i dobijanje različitih redova jer je druga transakcija ubacila/obrisala redove

MySQL InnoDB koristi **REPEATABLE READ** podrazumevano. PostgreSQL koristi **READ COMMITTED** podrazumevano.

```sql
-- Proveri trenutni nivo izolacije
SELECT @@transaction_isolation;

-- Postavi nivo izolacije za trenutnu sesiju
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
```

### D — Trajnost

Trajnost znači da jednom kada je transakcija commitovana, podaci su trajno sačuvani. Čak i ako server padne, izgubi struju ili disk otkaže — commitovani podaci preživljavaju.

Kako baze podataka osiguravaju trajnost:
- **Write-Ahead Log (WAL)** — promene se prvo pišu u log fajl na disku, zatim u stvarne fajlove podataka. Ako server padne, reprodukuje log pri ponovnom pokretanju
- **Flushovanje na disk** — COMMIT komanda forsira pisanje podataka na trajno skladište pre vraćanja uspeha klijentu
- **Replikacija** — podaci se kopiraju na druge servere za redundantnost

```sql
-- Nakon što COMMIT vrati rezultat, podaci su garantovano na disku
START TRANSACTION;
INSERT INTO payments (user_id, amount) VALUES (1, 500.00);
COMMIT;  -- Podaci su sada trajni — preživljavaju pad
```

### Transakcija u PHP-u sa PDO

```php
$pdo = new PDO('mysql:host=localhost;dbname=bank', 'root', 'pass');
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

try {
    $pdo->beginTransaction();

    // Povuci od pošiljaoca
    $stmt = $pdo->prepare('UPDATE accounts SET balance = balance - :amount WHERE id = :id');
    $stmt->execute(['amount' => 1000, 'id' => 1]);

    // Proveri da li pošiljalac ima dovoljno novca
    $stmt = $pdo->prepare('SELECT balance FROM accounts WHERE id = :id');
    $stmt->execute(['id' => 1]);
    $balance = $stmt->fetchColumn();

    if ($balance < 0) {
        throw new RuntimeException('Insufficient funds');
    }

    // Deponuj primaocu
    $stmt = $pdo->prepare('UPDATE accounts SET balance = balance + :amount WHERE id = :id');
    $stmt->execute(['amount' => 1000, 'id' => 2]);

    $pdo->commit();
    echo "Transfer successful";

} catch (Exception $e) {
    $pdo->rollBack();
    echo "Transfer failed: " . $e->getMessage();
}
```

### Transakcija u Doctrine-u (Symfony)

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

            // flush() se automatski poziva od strane wrapInTransaction
        });
    }
}
```

### Uobičajena pitanja o ACID-u na intervjuima

**P: Koje ACID svojstvo sprečava nestanak novca tokom bankovnog transfera?**
O: Atomičnost — ako deponovanje ne uspe, povlačenje je takođe poništeno.

**P: Šta se dešava kada dva korisnika kupe poslednji artikal na stanju u isto vreme?**
O: Izolacija — sa odgovarajućim zaključavanjem (SELECT ... FOR UPDATE), samo jedna transakcija će se nastaviti. Druga će videti da je stanje 0 i neće uspeti.

**P: Zašto SERIALIZABLE nije podrazumevano korišćeno?**
O: Performanse — SERIALIZABLE forsira transakcije da se izvršavaju jedna za drugom, što je veoma sporo pri visokoj konkurentnosti. REPEATABLE READ pruža dobru ravnotežu bezbednosti i performansi.

### Realni scenario

Gradiš sistem za rezervaciju karata. Kada korisnik rezerviše sedište:

```php
$this->em->wrapInTransaction(function () use ($seatId, $userId) {
    // Zaključaj red sedišta da spreči duplu rezervaciju (Atomičnost + Izolacija)
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

    // Odbij uplatu
    $user = $this->em->find(User::class, $userId);
    $user->deductBalance($seat->getPrice());

    // Ako išta ne uspe, sedište se vraća na "available" i novac je vraćen (Atomičnost)
    // Nakon COMMIT-a, rezervacija je trajna (Trajnost)
    // Ostali korisnici vide konzistentne podatke (Konzistentnost)
});
```

### Zaključak

ACID osigurava pouzdane transakcije u bazi podataka. **Atomičnost** garantuje izvršavanje sve-ili-ništa. **Konzistentnost** čuva bazu u validnom stanju sprovođenjem ograničenja. **Izolacija** sprečava mešanje konkurentnih transakcija — MySQL podrazumevano koristi REPEATABLE READ. **Trajnost** osigurava da commitovani podaci preživljavaju padove kroz write-ahead log-ove. U PHP-u, koristi `PDO::beginTransaction()` + `commit()`/`rollBack()` ili Doctrine-ov `wrapInTransaction()` za bezbedan rad sa transakcijama.

> Vidi takođe: [Relacije entiteta](entity_relationships.sr.md), [Deadlocks u MySQL-u](../highload/deadlocks_in_mysql.sr.md), [Optimistično/Pesimistično zaključavanje](../highload/optimistic_pessimistic_lock.sr.md)
