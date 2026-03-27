Magične metode su posebne metode u PHP-u koje počinju dvostrukim donjim crtama (`__`). PHP ih automatski poziva u određenim situacijama. Ne pozivate ih direktno — aktiviraju se određenim radnjama kao što su kreiranje objekta, pristup propertiju ili konverzija objekta u string.

### Lista magičnih metoda

| Metoda | Kada se poziva |
|--------|----------------|
| `__construct()` | Kada se kreira novi objekat |
| `__destruct()` | Kada se objekat uništava |
| `__get($name)` | Kada se čita propertij koji ne postoji ili nije dostupan |
| `__set($name, $value)` | Kada se piše u propertij koji ne postoji ili nije dostupan |
| `__isset($name)` | Kada se `isset()` ili `empty()` pozove na nedostupnom propertiju |
| `__unset($name)` | Kada se `unset()` pozove na nedostupnom propertiju |
| `__call($name, $args)` | Kada se poziva metoda koja ne postoji ili nije dostupna |
| `__callStatic($name, $args)` | Isto kao `__call` ali za statičke metode |
| `__toString()` | Kada se objekat koristi kao string (npr. u `echo`) |
| `__invoke()` | Kada se objekat poziva kao funkcija |
| `__clone()` | Kada se objekat klonira sa ključnom reči `clone` |
| `__debugInfo()` | Kada se `var_dump()` pozove na objektu |
| `__serialize()` / `__unserialize()` | Kada se objekat serijalizuje/deserijalizuje |
| `__sleep()` / `__wakeup()` | Starija verzija hookova za serijalizaciju/deserijalizaciju |

### Najčešće korišćene magične metode sa primerima

#### `__construct()` i `__destruct()`

```php
class DatabaseConnection
{
    private $connection;

    public function __construct(string $host, string $user, string $password)
    {
        $this->connection = new PDO("mysql:host=$host", $user, $password);
        echo "Connected to database\n";
    }

    public function __destruct()
    {
        $this->connection = null;
        echo "Connection closed\n";
    }
}

$db = new DatabaseConnection('localhost', 'root', 'secret'); // "Connected to database"
// ... use the connection ...
// When script ends or $db goes out of scope: "Connection closed"
```

#### `__get()` i `__set()`

Ove metode presreću pristup propertijima koji ne postoje ili su privatni/zaštićeni.

```php
class Config
{
    private array $data = [];

    public function __get(string $name)
    {
        return $this->data[$name] ?? null;
    }

    public function __set(string $name, $value): void
    {
        $this->data[$name] = $value;
    }
}

$config = new Config();
$config->database = 'mysql';  // calls __set('database', 'mysql')
echo $config->database;        // calls __get('database') → 'mysql'
```

#### `__toString()`

```php
class Money
{
    public function __construct(
        private float $amount,
        private string $currency
    ) {}

    public function __toString(): string
    {
        return number_format($this->amount, 2) . ' ' . $this->currency;
    }
}

$price = new Money(29.99, 'EUR');
echo $price; // "29.99 EUR"
echo "Total: $price"; // "Total: 29.99 EUR"
```

#### `__call()` i `__callStatic()`

```php
class QueryBuilder
{
    private array $conditions = [];

    public function __call(string $name, array $arguments): self
    {
        if (str_starts_with($name, 'findBy')) {
            $field = lcfirst(substr($name, 6));
            $this->conditions[$field] = $arguments[0];
        }
        return $this;
    }
}

$builder = new QueryBuilder();
$builder->findByName('John');     // calls __call('findByName', ['John'])
$builder->findByEmail('j@x.com'); // calls __call('findByEmail', ['j@x.com'])
```

#### `__clone()`

```php
class Order
{
    public function __construct(
        public int $id,
        public DateTime $createdAt
    ) {}

    public function __clone(): void
    {
        // Without this, both orders would share the same DateTime object
        $this->createdAt = clone $this->createdAt;
        $this->id = 0; // Reset ID for the cloned order
    }
}

$order = new Order(1, new DateTime());
$copy = clone $order; // __clone() is called
// $copy->id is 0, $copy->createdAt is a separate DateTime object
```

### Realni scenario

Gradite sistem za logovanje. Želite da log unosi automatski konvertuju u string za ispis i da čiste file handlere kada se unište:

```php
class LogEntry
{
    private $fileHandle;

    public function __construct(
        private string $level,
        private string $message,
        private DateTime $timestamp
    ) {
        $this->fileHandle = fopen('app.log', 'a');
    }

    public function __toString(): string
    {
        return sprintf(
            "[%s] %s: %s",
            $this->timestamp->format('Y-m-d H:i:s'),
            strtoupper($this->level),
            $this->message
        );
    }

    public function __destruct()
    {
        if ($this->fileHandle) {
            fwrite($this->fileHandle, $this . "\n");
            fclose($this->fileHandle);
        }
    }
}

$log = new LogEntry('error', 'Database connection failed', new DateTime());
echo $log; // "[2024-01-15 10:30:00] ERROR: Database connection failed"
// When $log is destroyed, it writes itself to app.log
```

### Zaključak

Magične metode vam omogućavaju da kontrolišete kako se PHP objekti ponašaju u posebnim situacijama — kada se kreiraju, uništavaju, štampaju, kloniraju ili kada neko pristupa nedostajućim propertijima ili metodama. Moćne su, ali treba ih koristiti pažljivo jer mogu otežati razumevanje koda. Najčešće korišćene su `__construct()`, `__toString()`, `__get()`/`__set()` i `__clone()`.
