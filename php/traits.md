Traits are a way to reuse code in PHP classes. They solve the problem of PHP not supporting multiple inheritance — a class can only extend one parent class, but it can use many traits.

Think of a trait as a set of methods that you "copy and paste" into a class. The class gets those methods as if they were written directly inside it.

### How to Add Traits

Use the `use` keyword inside a class:

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

Both `User` and `Product` now have timestamp methods without duplicating code.

#### Using Multiple Traits

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

### Inheriting Traits

Traits can use other traits:

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

### Instantiating Traits

You **cannot** create an instance of a trait directly. Traits are not classes — they are only used inside classes.

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

### How Traits Are Included on Low Level

When PHP compiles a class that uses a trait, it effectively copies the trait's methods and properties into the class. The result is the same as if you typed those methods directly in the class. This happens at compile time, not at runtime.

This means:

- Trait methods become part of the class
- `$this` inside a trait refers to the object of the class using the trait
- Traits do not exist as separate objects in memory

### Conflict Resolution

If two traits have a method with the same name, PHP will throw a fatal error. You must resolve the conflict manually:

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

### Constants in Traits (PHP 8.2+)

Starting from PHP 8.2, you **can** add constants to traits:

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

Before PHP 8.2, constants in traits were not allowed. You would need to define the constant in the class itself or in an interface.

### Private and Protected Methods in Traits

Yes, you can use private and protected methods in traits. They work exactly like they would in a class:

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

You can also change method visibility when using a trait:

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

### Real Scenario

You are building an API with entities that need audit tracking. Instead of repeating the same fields in every entity class, you create a trait:

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

Now all three entities have audit fields without any code duplication.

### Conclusion

Traits allow code reuse across classes without inheritance. They are compiled into the class at compile time, like a "copy-paste." Traits can use other traits, have private/protected methods, and since PHP 8.2 can have constants. When two traits have the same method name, you must resolve the conflict with `insteadof` and `as` keywords. Traits cannot be instantiated on their own.
