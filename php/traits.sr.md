Traitovi su način ponovnog korišćenja koda u PHP klasama. Rešavaju problem nepodržavanja višestrukog nasleđivanja u PHP-u — klasa može proširiti samo jednu roditeljsku klasu, ali može koristiti mnogo traitova.

Zamislite trait kao skup metoda koje "kopirate i nalepite" u klasu. Klasa dobija te metode kao da su napisane direktno unutar nje.

### Kako dodati traitove

Koristite ključnu reč `use` unutar klase:

```php
trait Timestampable
{
    private DateTime $createdAt;
    private DateTime $updatedAt;

    public function getCreatedAt(): DateTime
    {
        return $this->createdAt;
    }

    public function setCreatedAt(DateTime $date): void
    {
        $this->createdAt = $date;
    }

    public function setUpdatedAt(DateTime $date): void
    {
        $this->updatedAt = $date;
    }
}

class User
{
    use Timestampable; // Now User has getCreatedAt(), setCreatedAt(), setUpdatedAt()

    public function __construct(private string $name) {}
}

class Product
{
    use Timestampable; // Product also gets the same methods

    public function __construct(private string $title) {}
}
```

I `User` i `Product` sada imaju timestamp metode bez dupliranja koda.

#### Korišćenje više traitova

```php
trait Loggable
{
    public function log(string $message): void
    {
        echo "[LOG] " . get_class($this) . ": $message\n";
    }
}

trait SoftDeletable
{
    private ?DateTime $deletedAt = null;

    public function softDelete(): void
    {
        $this->deletedAt = new DateTime();
    }

    public function isDeleted(): bool
    {
        return $this->deletedAt !== null;
    }
}

class Article
{
    use Timestampable, Loggable, SoftDeletable;

    public function __construct(private string $title) {}
}
```

### Nasleđivanje traitova

Traitovi mogu koristiti druge traitove:

```php
trait HasTimestamps
{
    private DateTime $createdAt;
}

trait HasSoftDelete
{
    private ?DateTime $deletedAt = null;
}

trait HasAuditFields
{
    use HasTimestamps, HasSoftDelete; // Trait uses other traits

    private string $createdBy;
}

class Invoice
{
    use HasAuditFields; // Gets everything from all three traits
}
```

### Instanciranje traitova

**Ne možete** kreirati instancu traita direktno. Traitovi nisu klase — koriste se samo unutar klasa.

```php
trait Printable
{
    public function printInfo(): void { echo "Info\n"; }
}

// This will NOT work:
// $obj = new Printable(); // Fatal error!

// This WILL work:
class Report
{
    use Printable;
}
$report = new Report();
$report->printInfo(); // "Info"
```

### Kako se traitovi uključuju na niskom nivou

Kada PHP kompajlira klasu koja koristi trait, efektivno kopira metode i properties traita u klasu. Rezultat je isti kao da ste direktno napisali te metode u klasi. Ovo se dešava pri kompajliranju, a ne pri pokretanju.

Ovo znači:

- Metode traita postaju deo klase
- `$this` unutar traita referiše na objekat klase koja koristi trait
- Traitovi ne postoje kao posebni objekti u memoriji

### Rešavanje konflikata

Ako dva traita imaju metodu istog naziva, PHP će baciti fatalni error. Konflikt morate ručno rešiti:

```php
trait A
{
    public function hello(): string { return 'Hello from A'; }
}

trait B
{
    public function hello(): string { return 'Hello from B'; }
}

class MyClass
{
    use A, B {
        A::hello insteadof B; // Use A's version of hello()
        B::hello as helloFromB; // Keep B's version under a different name
    }
}

$obj = new MyClass();
echo $obj->hello();       // "Hello from A"
echo $obj->helloFromB();  // "Hello from B"
```

### Konstante u traitovima (PHP 8.2+)

Počevši od PHP 8.2, **možete** dodavati konstante traitovima:

```php
trait HasVersion
{
    const VERSION = '1.0';
}

class App
{
    use HasVersion;
}

echo App::VERSION; // "1.0"
```

Pre PHP 8.2, konstante u traitovima nisu bile dozvoljene. Morali ste definisati konstantu u samoj klasi ili u interfejsu.

### Privatne i zaštićene metode u traitovima

Da, možete koristiti privatne i zaštićene metode u traitovima. Rade tačno kao što bi radile u klasi:

```php
trait Cacheable
{
    private array $cache = [];

    private function getCacheKey(string $method, array $args): string
    {
        return $method . '_' . md5(serialize($args));
    }

    protected function cacheResult(string $key, mixed $value): void
    {
        $this->cache[$key] = $value;
    }

    public function getCached(string $key): mixed
    {
        return $this->cache[$key] ?? null;
    }
}

class UserRepository
{
    use Cacheable;

    public function findById(int $id): ?User
    {
        $key = $this->getCacheKey('findById', [$id]); // Private method — works fine
        $cached = $this->getCached($key);

        if ($cached !== null) {
            return $cached;
        }

        $user = $this->queryDatabase($id);
        $this->cacheResult($key, $user); // Protected method — works fine
        return $user;
    }
}
```

Takođe možete promeniti vidljivost metode kada koristite trait:

```php
trait Logger
{
    public function log(string $msg): void { /* ... */ }
}

class SecureService
{
    use Logger {
        log as private; // Makes the public log() method private in this class
    }
}
```

### Realni scenario

Gradite API sa entitetima kojima je potrebno praćenje revizija. Umesto ponavljanja istih polja u svakoj klasi entiteta, kreirate trait:

```php
trait AuditableTrait
{
    private ?string $createdBy = null;
    private ?DateTime $createdAt = null;
    private ?string $updatedBy = null;
    private ?DateTime $updatedAt = null;

    public function markCreated(string $user): void
    {
        $this->createdBy = $user;
        $this->createdAt = new DateTime();
    }

    public function markUpdated(string $user): void
    {
        $this->updatedBy = $user;
        $this->updatedAt = new DateTime();
    }

    public function getAuditInfo(): array
    {
        return [
            'created_by' => $this->createdBy,
            'created_at' => $this->createdAt?->format('Y-m-d H:i:s'),
            'updated_by' => $this->updatedBy,
            'updated_at' => $this->updatedAt?->format('Y-m-d H:i:s'),
        ];
    }
}

class Order { use AuditableTrait; /* ... */ }
class Invoice { use AuditableTrait; /* ... */ }
class Customer { use AuditableTrait; /* ... */ }
```

Sada sva tri entiteta imaju polja revizije bez ikakvog dupliranja koda.

### Zaključak

Traitovi omogućavaju ponovnu upotrebu koda u klasama bez nasleđivanja. Kompajlirani su u klasu pri kompajliranju, kao "kopiranje i lepljenje". Traitovi mogu koristiti druge traitove, imati privatne/zaštićene metode i od PHP 8.2 mogu imati konstante. Kada dva traita imaju metodu istog naziva, morate rešiti konflikt ključnim rečima `insteadof` i `as`. Traitovi se ne mogu instancirati samostalno.
