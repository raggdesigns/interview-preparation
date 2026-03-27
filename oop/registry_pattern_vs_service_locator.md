Registry and Service Locator are both patterns that provide access to shared objects, but they have different purposes and levels of sophistication.

### Registry Pattern

A Registry is a simple global storage for objects. It is like a dictionary (key-value map) where you store and retrieve objects by name. A Registry does not create objects — it only stores and returns them.

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

Usage:

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

### Service Locator Pattern

A Service Locator is more advanced. It not only stores services but can also **create** them (lazy initialization), manage their lifecycle, and resolve dependencies.

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

Usage:

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

### Key Differences

| Feature | Registry | Service Locator |
|---------|----------|----------------|
| Purpose | Store and retrieve objects | Store, create, and manage services |
| Object creation | Objects created externally, then stored | Objects created internally (lazy) |
| Dependencies | Does not handle dependencies | Can resolve dependencies between services |
| Lazy loading | No — objects exist before being stored | Yes — objects created on first request |
| Complexity | Very simple | More complex |

### Comparison Example

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

### Problems with Both Patterns

Both patterns share the same fundamental problems:

1. **Global state** — accessible from anywhere, making code hard to trace
2. **Hidden dependencies** — you cannot see what a class needs from its constructor
3. **Hard to test** — must set up global state before tests
4. **Tight coupling** — code depends on the Registry/Locator class

These are the same reasons why DI Container with constructor injection is preferred in modern PHP applications.

### When Each Is Used

**Registry** is sometimes used in:

- Simple legacy applications
- Storing configuration values
- Test fixtures

**Service Locator** is sometimes used in:

- Legacy frameworks
- Plugin systems where services are discovered at runtime
- Symfony's `ServiceSubscriberInterface` (controlled, limited form)

### Real Scenario

You are working on a legacy application that uses a Registry:

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

When you refactor to a DI Container, both the Registry and Service Locator become unnecessary:

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

### Conclusion

Registry is a simple key-value store for objects — you create objects externally and store them. Service Locator is smarter — it creates objects lazily and can resolve dependencies. Both suffer from hidden dependencies and global state. In modern PHP with DI containers (Symfony, Laravel), both patterns are largely unnecessary — constructor injection is cleaner, more testable, and catches errors at compile time.

> See also: [Service Locator VS DI Container](service_locator_vs_di_container.md), [Dependency Injection VS Composition VS IoC](di_vs_composition_vs_ioc.md)
