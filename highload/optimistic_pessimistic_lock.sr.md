Zaključavanje je mehanizam za kontrolu istovremenog pristupa podacima. Kada više transakcija pokušava da čita i piše iste podatke, zaključavanja sprečavaju konflikte i oštećenje podataka. Postoje dve glavne strategije: **optimistično** i **pesimistično** zaključavanje.

### Pesimistično zaključavanje

Pesimistično zaključavanje pretpostavlja da **će** doći do konflikata. Odmah zaključava podatke pri čitanju, sprečavajući bilo koga drugog da ih menja dok transakcija nije završena.

#### Kako funkcioniše

```sql
-- Transakcija A: Odmah zaključaj red
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;  -- Zaključava red id=1
-- ... radi izračunavanja ...
UPDATE accounts SET balance = 900 WHERE id = 1;
COMMIT;  -- Zaključavanje oslobođeno

-- Transakcija B (u isto vreme):
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;  -- ČEKA dok Transakcija A ne commituje
```

#### Tipovi pesimističnih zaključavanja u MySQL-u

```sql
-- Ekskluzivno zaključavanje (FOR UPDATE) — blokira i čitanje i pisanje
SELECT * FROM products WHERE id = 5 FOR UPDATE;

-- Deljeno zaključavanje (FOR SHARE / LOCK IN SHARE MODE) — dozvoljava čitanje, blokira pisanje
SELECT * FROM products WHERE id = 5 FOR SHARE;
```

| Tip zaključavanja | Druga čitanja? | Drugo pisanje? |
|-----------|-------------|---------------|
| `FOR UPDATE` | Blokirano | Blokirano |
| `FOR SHARE` | Dozvoljeno | Blokirano |

#### Pesimistično zaključavanje u Doctrine-u

```php
use Doctrine\DBAL\LockMode;

// LockMode::PESSIMISTIC_WRITE — SELECT ... FOR UPDATE
$product = $em->find(Product::class, $id, LockMode::PESSIMISTIC_WRITE);
$product->decreaseStock(1);
$em->flush();

// LockMode::PESSIMISTIC_READ — SELECT ... FOR SHARE
$product = $em->find(Product::class, $id, LockMode::PESSIMISTIC_READ);

// Sa DQL-om
$query = $em->createQuery('SELECT p FROM Product p WHERE p.id = :id');
$query->setParameter('id', $id);
$query->setLockMode(LockMode::PESSIMISTIC_WRITE);
$product = $query->getSingleResult();
```

### Optimistično zaključavanje

Optimistično zaključavanje pretpostavlja da se konflikti **retko** dešavaju. Ne zaključava podatke pri čitanju. Umesto toga, pri ažuriranju proverava da li je neko drugi promenio podatke od kad su pročitani.

#### Kako funkcioniše

Tabela ima kolonu **version** (integer ili timestamp). Pri ažuriranju, aplikacija proverava da se verzija nije promenila:

```sql
-- Korak 1: Pročitaj podatke (bez zaključavanja)
SELECT id, name, balance, version FROM accounts WHERE id = 1;
-- Vraća: id=1, balance=1000, version=5

-- Korak 2: Ažuriraj sa proverom verzije
UPDATE accounts
SET balance = 900, version = version + 1
WHERE id = 1 AND version = 5;  -- Proveri da je verzija još uvek 5

-- Ako UPDATE utiče na 0 redova → neko drugi je promenio podatke → konflikt!
-- Ako UPDATE utiče na 1 red → uspeh, verzija je sada 6
```

#### Optimistično zaključavanje u Doctrine-u

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

    #[ORM\Version]  // ← Ovo omogućava optimistično zaključavanje
    #[ORM\Column]
    private int $version;
}
```

Kada neko drugi promeni entitet između tvog čitanja i pisanja, Doctrine baca izuzetak:

```php
try {
    $product = $em->find(Product::class, 1);
    $product->decreaseStock(1);
    $em->flush();
} catch (OptimisticLockException $e) {
    // Druga transakcija je izmenila ovaj proizvod!
    // Opcija 1: Ponovo učitaj i pokušaj
    // Opcija 2: Prikaži grešku korisniku
    echo "The product was modified by someone else. Please try again.";
}
```

#### Eksplicitna provera verzije u Doctrine-u

Možeš takođe ručno proveriti verziju:

```php
// Frontend šalje verziju koju je učitao
$expectedVersion = $request->get('version'); // npr. 5

try {
    $product = $em->find(Product::class, $id);
    $em->lock($product, LockMode::OPTIMISTIC, $expectedVersion);

    $product->setPrice($newPrice);
    $em->flush();
} catch (OptimisticLockException $e) {
    // Nepodudaranje verzije — neko drugi je izmenio proizvod
    return new JsonResponse(['error' => 'Data was modified. Please reload and try again.'], 409);
}
```

### Poređenje

| Osobina | Pesimistično | Optimistično |
|---------|-------------|------------|
| Kada zaključava | Odmah pri čitanju | Nikada ne zaključava — proverava pri pisanju |
| Detekcija konflikata | Sprečava konflikte blokiranjem | Detektuje konflikte nakon što se dogode |
| Performanse (malo sukoba) | Sporije — nepotrebni overhead zaključavanja | Brže — bez overhead-a zaključavanja |
| Performanse (visoko sukobljavanje) | Bolje — izbegava ponovne pokušaje | Sporije — potrebno je mnogo ponovnih pokušaja |
| Uključenost baze podataka | Zahteva `FOR UPDATE` / `FOR SHARE` | Zahteva kolonu verzije |
| Rizik od deadlock-a | Da | Ne |
| Najbolje za | Visoko sukobljavanje, kratke transakcije | Malo sukobljavanje, duge transakcije |

### Kada koristiti koje

#### Koristi pesimistično zaključavanje kada:

- Mnoge transakcije se takmiče za iste redove (visoko sukobljavanje)
- Trošak neuspele transakcije je visok (npr. finansijske operacije)
- Transakcije su kratke

```php
// Finansijski prenos — koristi pesimistično zaključavanje
// Dva naloga moraju biti ažurirana atomski, mnogo istovremenih prenosa
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

#### Koristi optimistično zaključavanje kada:

- Konflikti su retki (malo sukobljavanja)
- Transakcije mogu biti duge (npr. korisnik uređuje formular minutima)
- Želiš izbegavati zaključavanje na nivou baze podataka

```php
// CMS — korisnik uređuje članak
// Konflikti su retki (malo urednika), uređivanje traje minute
$article = $em->find(Article::class, $id);
// ... korisnik uređuje članak u browseru 5 minuta ...

try {
    $em->lock($article, LockMode::OPTIMISTIC, $originalVersion);
    $article->setContent($newContent);
    $em->flush();
} catch (OptimisticLockException $e) {
    // Drugi urednik je sačuvao promene dok je ovaj korisnik uređivao
    // Prikaži ekran za merge/rešavanje konflikata
}
```

### Realni scenario

Onlajn prodavnica ima proizvod sa 3 komada na stanju. Dva kupca pokušavaju da kupe istovremeno.

#### Sa optimističnim zaključavanjem:

```php
// Kupac A čita: stock = 3, version = 1
// Kupac B čita: stock = 3, version = 1

// Kupac A šalje narudžbinu:
UPDATE products SET stock = 2, version = 2 WHERE id = 1 AND version = 1;
// → 1 red pogođen → uspeh! Verzija je sada 2.

// Kupac B šalje narudžbinu:
UPDATE products SET stock = 2, version = 2 WHERE id = 1 AND version = 1;
// → 0 redova pogođeno → verzija se promenila! OptimisticLockException!
// Kupac B mora ponovo učitati (stock = 2, version = 2) i pokušati ponovo:
UPDATE products SET stock = 1, version = 3 WHERE id = 1 AND version = 2;
// → 1 red pogođen → uspeh!
```

#### Sa pesimističnim zaključavanjem:

```php
// Kupac A:
SELECT * FROM products WHERE id = 1 FOR UPDATE; -- Zaključava red
// stock = 3
UPDATE products SET stock = 2 WHERE id = 1;
COMMIT; -- Zaključavanje oslobođeno

// Kupac B (čeka dok A ne commituje):
SELECT * FROM products WHERE id = 1 FOR UPDATE; -- Sada dobija zaključavanje
// stock = 2 (već ažurirano od strane A)
UPDATE products SET stock = 1 WHERE id = 1;
COMMIT;
```

Oba pristupa daju tačan rezultat. Pesimistično je jednostavnije (bez ponovnih pokušaja). Optimistično je brže kada su konflikti retki.

### Zaključak

Pesimistično zaključavanje koristi `SELECT ... FOR UPDATE` da odmah zaključa redove — sprečava konflikte ali može uzrokovati deadlock-e i smanjuje konkurentnost. Optimistično zaključavanje koristi kolonu verzije i proverava pri ažuriranju — omogućava više konkurentnosti ali zahteva rukovanje konfliktima (ponovni pokušaji ili obaveštenje korisnika). Koristi pesimistično zaključavanje za scenarije sa visokim sukobljavanjem poput finansijskih operacija. Koristi optimistično zaključavanje za scenarije sa malim sukobljavanjem poput uređivanja sadržaja. Doctrine podržava oba kroz `LockMode::PESSIMISTIC_WRITE` i `#[ORM\Version]`.
