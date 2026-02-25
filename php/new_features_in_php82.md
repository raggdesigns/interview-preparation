PHP 8.2 was released in December 2022. It focused on making classes safer, deprecating dynamic properties, and adding new type features.

### Readonly Classes

Instead of marking each property as `readonly`, you can make the entire class readonly:

```php
// PHP 8.1 — mark each property
class Point
{
    public function __construct(
        public readonly float $x,
        public readonly float $y,
    ) {}
}

// PHP 8.2 — readonly class
readonly class Point
{
    public function __construct(
        public float $x,
        public float $y,
    ) {}
}
```

In a readonly class, all properties are automatically readonly. You cannot add non-readonly properties or untyped properties.

### Disjunctive Normal Form (DNF) Types

You can combine union and intersection types together:

```php
// Accept: (A & B) | null
function process((Countable&Iterator)|null $data): void
{
    if ($data === null) {
        return;
    }
    // $data is both Countable and Iterator
}
```

### Deprecation of Dynamic Properties

Creating properties that are not declared in the class is now deprecated:

```php
class User
{
    public string $name;
}

$user = new User();
$user->name = 'John';    // OK — declared property
$user->age = 30;          // Deprecated in PHP 8.2! Not declared in the class
```

If you still need dynamic properties, use the `#[AllowDynamicProperties]` attribute:

```php
#[AllowDynamicProperties]
class FlexibleObject
{
    // Dynamic properties allowed here
}
```

### Constants in Traits

Traits can now define constants:

```php
trait HasVersion
{
    const VERSION = '2.0';
}

class Application
{
    use HasVersion;
}

echo Application::VERSION; // "2.0"
```

Note: You cannot access the constant through the trait name directly (`HasVersion::VERSION` is not allowed).

### Enum Constants in Expressions

Enums can be used in constant expressions:

```php
enum Status
{
    case Active;
    case Inactive;
}

function doSomething(Status $status = Status::Active): void
{
    // ...
}
```

### `true`, `false`, and `null` as Standalone Types

These can now be used as type declarations on their own:

```php
function alwaysTrue(): true
{
    return true;
}

function alwaysFalse(): false
{
    return false;
}

function alwaysNull(): null
{
    return null;
}
```

The `false` type is useful when a function returns a specific type or `false` on failure:

```php
function findIndex(array $items, mixed $search): int|false
{
    $index = array_search($search, $items);
    return $index; // returns int or false
}
```

### Sensitive Parameter Attribute

Hide sensitive data (like passwords) from stack traces:

```php
function login(
    string $username,
    #[SensitiveParameter] string $password,
): void {
    throw new RuntimeException('Login failed');
}

login('admin', 'secret123');
// In the stack trace, $password shows as "SensitiveParameterValue" instead of "secret123"
```

### Random Extension

A new object-oriented API for random number generation:

```php
$rng = new Random\Randomizer();

echo $rng->nextInt();                    // Random integer
echo $rng->getInt(1, 100);              // Random int between 1 and 100
echo $rng->shuffleString('Hello');       // e.g. "lHleo"
echo $rng->shuffleArray([1, 2, 3, 4]); // e.g. [3, 1, 4, 2]

// Reproducible results with a seed
$rng = new Random\Randomizer(new Random\Engine\Mt19937(42));
```

### Real Scenario

You are building a money value object for a financial application. PHP 8.2 makes this very clean:

```php
readonly class Money
{
    public function __construct(
        public int $amount,     // in cents
        public string $currency,
    ) {}

    public function add(self $other): self
    {
        if ($this->currency !== $other->currency) {
            throw new InvalidArgumentException('Cannot add different currencies');
        }
        return new self($this->amount + $other->amount, $this->currency);
    }

    public function isPositive(): true|false
    {
        return $this->amount > 0;
    }

    public function format(): string
    {
        return number_format($this->amount / 100, 2) . ' ' . $this->currency;
    }
}

$price = new Money(1999, 'USD');
$tax = new Money(160, 'USD');
$total = $price->add($tax);

echo $total->format(); // "21.59 USD"

// Cannot modify:
$total->amount = 0; // Error: Cannot modify readonly property
```

The `readonly class` ensures immutability of the entire object with minimal syntax.

### Conclusion

PHP 8.2 added readonly classes, DNF types (combining union and intersection), deprecated dynamic properties, allowed constants in traits, introduced `true`/`false`/`null` as standalone types, added `#[SensitiveParameter]` for security, and a new Random extension. The readonly class feature is especially important for building value objects and DTOs.
