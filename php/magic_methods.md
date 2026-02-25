Magic methods are special methods in PHP that start with double underscores (`__`). PHP calls them automatically in certain situations. You don't call them directly — they are triggered by specific actions like creating an object, accessing a property, or converting an object to a string.

### List of Magic Methods

| Method | When it is called |
|--------|-------------------|
| `__construct()` | When a new object is created |
| `__destruct()` | When an object is destroyed |
| `__get($name)` | When reading a property that doesn't exist or is not accessible |
| `__set($name, $value)` | When writing to a property that doesn't exist or is not accessible |
| `__isset($name)` | When `isset()` or `empty()` is called on a non-accessible property |
| `__unset($name)` | When `unset()` is called on a non-accessible property |
| `__call($name, $args)` | When calling a method that doesn't exist or is not accessible |
| `__callStatic($name, $args)` | Same as `__call` but for static methods |
| `__toString()` | When an object is used as a string (e.g., in `echo`) |
| `__invoke()` | When an object is called as a function |
| `__clone()` | When an object is cloned with `clone` keyword |
| `__debugInfo()` | When `var_dump()` is called on an object |
| `__serialize()` / `__unserialize()` | When object is serialized/unserialized |
| `__sleep()` / `__wakeup()` | Older version of serialize/unserialize hooks |

### Most Common Magic Methods with Examples

#### `__construct()` and `__destruct()`

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

#### `__get()` and `__set()`

These methods intercept access to properties that don't exist or are private/protected.

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

#### `__call()` and `__callStatic()`

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

### Real Scenario

You are building a logging system. You want log entries to automatically convert to string for output and to clean up file handles when destroyed:

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

### Conclusion

Magic methods let you control how PHP objects behave in special situations — when they are created, destroyed, printed, cloned, or when someone accesses missing properties or methods. They are powerful but should be used carefully because they can make code harder to understand. The most commonly used are `__construct()`, `__toString()`, `__get()`/`__set()`, and `__clone()`.
