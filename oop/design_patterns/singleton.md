The Singleton pattern ensures that a class has only one instance in the entire application and provides a global point of access to it.

### Structure

A Singleton class has three key features:
1. **Private constructor** — prevents creating instances with `new`
2. **Static instance variable** — holds the single instance
3. **Static method** — returns the instance, creating it on first call

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

### Why Singleton Is Controversial

The Singleton is the most debated design pattern. It is often called an **anti-pattern** because:

1. **Global state** — it acts like a global variable, making code harder to understand
2. **Hidden dependencies** — classes call `Singleton::getInstance()` internally, so you cannot see their dependencies from the constructor
3. **Hard to test** — you cannot replace the singleton with a mock in unit tests
4. **Tight coupling** — all code depends on the concrete Singleton class

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

### When Singleton Makes Sense

Despite its drawbacks, Singleton has legitimate uses:

1. **Database connection pool** — you want exactly one connection pool shared across the application
2. **Configuration** — application config loaded once and shared
3. **Hardware access** — a single point of access to a printer, serial port, etc.
4. **In-memory cache** — a shared cache within a single request

> See also: [Positive examples of Singleton pattern usage](../positive_examples_of_singleton_pattern_usage.md) for more details.

### Singleton vs Dependency Injection Container

In modern PHP applications (Symfony, Laravel), the DI container makes Singleton mostly unnecessary. You can configure a service as "shared" (which is the default in Symfony), and the container ensures only one instance is created:

```yaml
# Symfony services.yaml — all services are shared (singleton) by default
services:
    App\Service\Logger:
        arguments:
            $logFile: '%kernel.logs_dir%/app.log'
    # Only one instance of Logger will be created per request
```

This gives you the benefit of a single instance without the drawbacks of the Singleton pattern (hidden dependencies, hard to test).

### Real Scenario

You are building a legacy application without a DI container. You need a database connection shared across the application:

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

However, in a modern Symfony/Laravel application, you would use the DI container instead:

```php
// The container creates one PDO instance and injects it everywhere
class UserRepository
{
    public function __construct(private PDO $pdo) {} // Injected by the container
}
```

### Conclusion

Singleton ensures only one instance of a class exists, using a private constructor and a static `getInstance()` method. It is useful when you need exactly one instance (database connection, config). However, it creates global state, hides dependencies, and makes testing difficult. In modern PHP with DI containers, prefer configuring services as "shared" instead of implementing the Singleton pattern manually.
