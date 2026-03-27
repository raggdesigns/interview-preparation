Registry i Service Locator su oba obrasci koji pružaju pristup deljenim objektima, ali imaju različite svrhe i nivoe sofisticiranosti.

### Registry obrazac

Registry je jednostavno globalno skladište za objekte. Kao rečnik (mapa ključ-vrednost) gde čuvate i dohvatate objekte po imenu. Registry ne kreira objekte — samo ih čuva i vraća.

```php
class Registry
{
    private static array $instances = [];

    public static function set(string $key, object $value): void
    {
        self::$instances[$key] = $value;
    }

    public static function get(string $key): object
    {
        if (!isset(self::$instances[$key])) {
            throw new RuntimeException("Registry: '$key' not found");
        }
        return self::$instances[$key];
    }

    public static function has(string $key): bool
    {
        return isset(self::$instances[$key]);
    }
}
```

Upotreba:

```php
// Store objects in the registry (usually during bootstrap)
$pdo = new PDO('mysql:host=localhost;dbname=myapp', 'user', 'pass');
Registry::set('db', $pdo);

$logger = new FileLogger('/var/log/app.log');
Registry::set('logger', $logger);

// Retrieve them anywhere in the application
$db = Registry::get('db');
$logger = Registry::get('logger');
```

### Service Locator obrazac

Service Locator je napredniji. Ne samo da čuva servise već ih može i **kreirati** (lenja inicijalizacija), upravljati njihovim životnim ciklusom i razrešavati zavisnosti.

```php
class ServiceLocator
{
    private static array $factories = [];
    private static array $instances = [];

    public static function register(string $key, callable $factory): void
    {
        self::$factories[$key] = $factory;
    }

    public static function get(string $key): object
    {
        // Lazy initialization — create only on first request
        if (!isset(self::$instances[$key])) {
            if (!isset(self::$factories[$key])) {
                throw new RuntimeException("Service '$key' not registered");
            }
            self::$instances[$key] = (self::$factories[$key])();
        }
        return self::$instances[$key];
    }
}
```

Upotreba:

```php
// Register factories — objects are NOT created yet
ServiceLocator::register('db', function () {
    return new PDO('mysql:host=localhost;dbname=myapp', 'user', 'pass');
});

ServiceLocator::register('user_repository', function () {
    return new UserRepository(ServiceLocator::get('db'));  // Resolves dependency
});

// Objects are created only when first requested
$repo = ServiceLocator::get('user_repository');
// 1. Creates PDO (db)
// 2. Creates UserRepository with PDO injected
```

### Ključne razlike

| Karakteristika | Registry | Service Locator |
|----------------|----------|----------------|
| Svrha | Čuvanje i dohvatanje objekata | Čuvanje, kreiranje i upravljanje servisima |
| Kreiranje objekata | Objekti se kreiraju spolja, zatim čuvaju | Objekti se kreiraju interno (leno) |
| Zavisnosti | Ne rukuje zavisnostima | Može razrešavati zavisnosti između servisa |
| Leno učitavanje | Ne — objekti postoje pre nego što budu sačuvani | Da — objekti se kreiraju na prvi zahtev |
| Složenost | Veoma jednostavno | Složenije |

### Primer poređenja

```php
// Registry — you create everything manually
$pdo = new PDO('mysql:host=localhost;dbname=myapp', 'user', 'pass');
$logger = new FileLogger('/var/log/app.log');
$userRepo = new UserRepository($pdo);
$orderRepo = new OrderRepository($pdo);
$orderService = new OrderService($userRepo, $orderRepo, $logger);

Registry::set('order_service', $orderService);
// All objects are created immediately, even if never used

// Service Locator — register factories, create on demand
ServiceLocator::register('pdo', fn() => new PDO(...));
ServiceLocator::register('logger', fn() => new FileLogger('/var/log/app.log'));
ServiceLocator::register('user_repo', fn() => new UserRepository(ServiceLocator::get('pdo')));
ServiceLocator::register('order_repo', fn() => new OrderRepository(ServiceLocator::get('pdo')));
ServiceLocator::register('order_service', fn() => new OrderService(
    ServiceLocator::get('user_repo'),
    ServiceLocator::get('order_repo'),
    ServiceLocator::get('logger'),
));
// Nothing is created until someone calls ServiceLocator::get('order_service')
```

### Problemi sa oba obrasca

Oba obrasca dele iste temeljne probleme:

1. **Globalno stanje** — dostupno svuda, čineći kod teškim za praćenje
2. **Skrivene zavisnosti** — ne možete videti šta klasa treba iz njenog konstruktora
3. **Teško testiranje** — morate postaviti globalno stanje pre testova
4. **Tesno spajanje** — kod zavisi od klase Registry/Locator

Ovo su isti razlozi zbog kojih je DI Container sa injektovanjem kroz konstruktor preferiran u modernim PHP aplikacijama.

### Kada se koristi koji

**Registry** se ponekad koristi u:
- Jednostavnim legacy aplikacijama
- Čuvanju konfiguracijskih vrednosti
- Test fixture-ima

**Service Locator** se ponekad koristi u:
- Legacy frejmvorcima
- Sistemima dodataka (plugin-ova) gde se servisi otkrivaju u vreme izvršavanja
- Symfony-jevom `ServiceSubscriberInterface` (kontrolisana, ograničena forma)

### Realni scenario

Radite na legacy aplikaciji koja koristi Registry:

```php
// Bootstrap
Registry::set('config', new Config('config.ini'));
Registry::set('db', new PDO(Registry::get('config')->get('db_dsn')));
Registry::set('cache', new RedisCache(Registry::get('config')->get('redis_host')));

// In a controller
class ProductController
{
    public function list(): Response
    {
        $cache = Registry::get('cache');
        $db = Registry::get('db');

        $products = $cache->get('products', function () use ($db) {
            return $db->query("SELECT * FROM products")->fetchAll();
        });

        return new JsonResponse($products);
    }
}
```

Kada refaktorišete na DI Container, i Registry i Service Locator postaju nepotrebni:

```php
// Symfony — dependencies are injected automatically
class ProductController
{
    public function __construct(
        private CacheInterface $cache,
        private ProductRepository $productRepository,
    ) {}

    public function list(): Response
    {
        $products = $this->cache->get('products', function () {
            return $this->productRepository->findAll();
        });

        return new JsonResponse($products);
    }
}
```

### Zaključak

Registry je jednostavno skladište ključ-vrednost za objekte — vi kreirate objekte spolja i čuvate ih. Service Locator je pametniji — kreira objekte leno i može razrešavati zavisnosti. Oba pate od skrivenih zavisnosti i globalnog stanja. U modernom PHP-u sa DI kontejnerima (Symfony, Laravel), oba obrasca su uglavnom nepotrebna — injektovanje kroz konstruktor je čistije, lakše za testiranje i hvata greške u vreme kompajliranja.

> Vidi takođe: [Service Locator VS DI Container](service_locator_vs_di_container.sr.md), [Dependency Injection VS Composition VS IoC](di_vs_composition_vs_ioc.sr.md)
