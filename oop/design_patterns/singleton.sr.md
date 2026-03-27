Singleton obrazac osigurava da klasa ima samo jednu instancu u celoj aplikaciji i pruža globalnu tačku pristupa njoj.

### Struktura

Singleton klasa ima tri ključne karakteristike:

1. **Privatni konstruktor** — sprečava kreiranje instanci pomoću `new`
2. **Statička promenljiva instance** — čuva jedinu instancu
3. **Statička metoda** — vraća instancu, kreirajući je pri prvom pozivu

```php
class Logger
{
    private static ?self $instance = null;

    // Private constructor — cannot use "new Logger()"
    private function __construct(
        private string $logFile,
    ) {}

    // Prevent cloning
    private function __clone() {}

    // Prevent unserialization
    public function __wakeup()
    {
        throw new \Exception("Cannot unserialize singleton");
    }

    // The only way to get the instance
    public static function getInstance(): self
    {
        if (self::$instance === null) {
            self::$instance = new self('/var/log/app.log');
        }
        return self::$instance;
    }

    public function log(string $message): void
    {
        file_put_contents($this->logFile, date('Y-m-d H:i:s') . " $message\n", FILE_APPEND);
    }
}

// Usage
Logger::getInstance()->log('User logged in');
Logger::getInstance()->log('Order created');
// Both calls use the same instance
```

### Zašto je Singleton kontroverzan

Singleton je najdebatovaniji dizajnerski obrazac. Često se naziva **anti-obrascem** jer:

1. **Globalno stanje** — ponaša se kao globalna promenljiva, čineći kod teškim za razumevanje
2. **Skrivene zavisnosti** — klase pozivaju `Singleton::getInstance()` interno, pa ne možete videti njihove zavisnosti iz konstruktora
3. **Teško testiranje** — ne možete zameniti singleton mock-om u unit testovima
4. **Tesno spajanje** — sav kod zavisi od konkretne Singleton klase

```php
// Bad — hidden dependency, hard to test
class OrderService
{
    public function createOrder(array $data): void
    {
        // How do you know this class uses a Logger?
        // You have to read every line of code.
        Logger::getInstance()->log('Creating order');
        // ...
    }
}

// Better — use dependency injection instead
class OrderService
{
    public function __construct(
        private LoggerInterface $logger, // Dependency is visible
    ) {}

    public function createOrder(array $data): void
    {
        $this->logger->log('Creating order'); // Easy to mock in tests
    }
}
```

### Kada Singleton ima smisla

Uprkos nedostacima, Singleton ima legitimnu upotrebu:

1. **Skup konekcija sa bazom podataka** — želite tačno jedan skup konekcija deljenih kroz aplikaciju
2. **Konfiguracija** — konfiguracija aplikacije učitana jednom i deljena
3. **Pristup hardveru** — jedinstven pristup štampaču, serijskom portu, itd.
4. **Keširanje u memoriji** — deljeni keš unutar jednog zahteva

> Vidi takođe: [Pozitivni primeri upotrebe Singleton obrasca](../positive_examples_of_singleton_pattern_usage.sr.md) za više detalja.

### Singleton vs DI Container

U modernim PHP aplikacijama (Symfony, Laravel), DI kontejner čini Singleton uglavnom nepotrebnim. Možete konfigurisati servis kao "deljeni" (što je podrazumevano u Symfony-ju), a kontejner osigurava da se kreira samo jedna instanca:

```yaml
# Symfony services.yaml — all services are shared (singleton) by default
services:
    App\Service\Logger:
        arguments:
            $logFile: '%kernel.logs_dir%/app.log'
    # Only one instance of Logger will be created per request
```

Ovo vam daje prednost jedne instance bez nedostataka Singleton obrasca (skrivene zavisnosti, teško testiranje).

### Realni scenario

Gradite legacy aplikaciju bez DI kontejnera. Potrebna vam je konekcija sa bazom podataka deljena kroz aplikaciju:

```php
class Database
{
    private static ?self $instance = null;
    private PDO $pdo;

    private function __construct()
    {
        $this->pdo = new PDO(
            'mysql:host=localhost;dbname=myapp',
            'user',
            'password',
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
        );
    }

    private function __clone() {}

    public static function getInstance(): self
    {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    public function getConnection(): PDO
    {
        return $this->pdo;
    }
}

// Used across the application
$users = Database::getInstance()->getConnection()->query("SELECT * FROM users");
```

Međutim, u modernoj Symfony/Laravel aplikaciji, koristili biste DI kontejner umesto toga:

```php
// The container creates one PDO instance and injects it everywhere
class UserRepository
{
    public function __construct(private PDO $pdo) {} // Injected by the container
}
```

### Zaključak

Singleton osigurava da postoji samo jedna instanca klase, koristeći privatni konstruktor i statičku `getInstance()` metodu. Koristan je kada je potrebna tačno jedna instanca (konekcija sa bazom podataka, konfiguracija). Međutim, kreira globalno stanje, skriva zavisnosti i otežava testiranje. U modernom PHP-u sa DI kontejnerima, preferujte konfigurisanje servisa kao "deljenih" umesto ručne implementacije Singleton obrasca.
