PHP 8.1 was released in November 2021. It added several important features that changed how PHP developers write code.

### Enumerations (Enums)

Enums let you define a type with a fixed set of possible values:

```php
enum Status
{
    case Active;
    case Inactive;
    case Suspended;
}

function setStatus(Status $status): void
{
    // $status can only be Status::Active, Status::Inactive, or Status::Suspended
}

setStatus(Status::Active);   // OK
setStatus('active');          // TypeError!
```

#### Backed Enums

Enums can have string or integer values:

```php
enum Color: string
{
    case Red = 'red';
    case Green = 'green';
    case Blue = 'blue';
}

// Get the value
echo Color::Red->value; // "red"

// Create from value
$color = Color::from('green');     // Color::Green
$color = Color::tryFrom('yellow'); // null (does not throw)
```

#### Enums with Methods

```php
enum Suit: string
{
    case Hearts = '♥';
    case Diamonds = '♦';
    case Clubs = '♣';
    case Spades = '♠';

    public function isRed(): bool
    {
        return match($this) {
            self::Hearts, self::Diamonds => true,
            default => false,
        };
    }
}

echo Suit::Hearts->isRed(); // true
```

### Readonly Properties

A property that can only be set once and cannot be changed after that:

```php
class User
{
    public function __construct(
        public readonly int $id,
        public readonly string $email,
    ) {}
}

$user = new User(1, 'user@example.com');
echo $user->id;    // 1
$user->id = 2;     // Error: Cannot modify readonly property
```

Readonly properties must have a type and can only be written from the scope where they are defined (usually the constructor).

### Fibers

Fibers allow you to pause and resume code execution. They are the foundation for async frameworks:

```php
$fiber = new Fiber(function (): void {
    $value = Fiber::suspend('Hello');
    echo "Fiber received: $value\n";
});

$result = $fiber->start();       // Runs until Fiber::suspend() — returns 'Hello'
echo "Main got: $result\n";     // "Main got: Hello"

$fiber->resume('World');         // Continues fiber — prints "Fiber received: World"
```

You do not use Fibers directly very often. They are used by async libraries like ReactPHP, Amp, and Swoole internally.

### Intersection Types

A parameter must implement **all** listed types:

```php
function processItem(Countable&Iterator $collection): void
{
    // $collection must implement BOTH Countable AND Iterator
    echo count($collection);
    foreach ($collection as $item) {
        // ...
    }
}
```

This is different from union types (`A|B` — must be A **or** B). Intersection types (`A&B` — must be A **and** B).

### first-class Callable Syntax

You can create a closure from any callable using `...`:

```php
// Before PHP 8.1
$strlen = Closure::fromCallable('strlen');

// PHP 8.1
$strlen = strlen(...);

// Works with methods too
$filter = $validator->validate(...);

// Useful in higher-order functions
$lengths = array_map(strlen(...), ['hello', 'world', 'php']);
// [5, 5, 3]
```

### Never Return Type

A function that never returns (it always throws or exits):

```php
function throwError(string $message): never
{
    throw new RuntimeException($message);
}

function redirect(string $url): never
{
    header("Location: $url");
    exit();
}
```

### Array Unpacking with String Keys

PHP 8.1 allows using the spread operator `...` with string keys:

```php
$defaults = ['color' => 'blue', 'size' => 'M'];
$custom = ['size' => 'L', 'weight' => 100];

$merged = [...$defaults, ...$custom];
// ['color' => 'blue', 'size' => 'L', 'weight' => 100]
```

### Real Scenario

You are building a payment system. Before PHP 8.1, you might use string constants for payment status:

```php
// Before PHP 8.1 — using strings (easy to make typos)
class Payment
{
    public string $status; // 'pending', 'completed', 'failed', 'refunded'
    
    public function __construct(
        public float $amount,
        public string $currency,
    ) {
        $this->status = 'pending';
    }
    
    public function complete(): void
    {
        $this->status = 'completed';
    }
}

$payment = new Payment(99.99, 'USD');
$payment->status = 'completd'; // Typo — no error, but wrong value!
```

After PHP 8.1:

```php
enum PaymentStatus: string
{
    case Pending = 'pending';
    case Completed = 'completed';
    case Failed = 'failed';
    case Refunded = 'refunded';

    public function canTransitionTo(self $new): bool
    {
        return match($this) {
            self::Pending => in_array($new, [self::Completed, self::Failed]),
            self::Completed => $new === self::Refunded,
            default => false,
        };
    }
}

class Payment
{
    public function __construct(
        public readonly float $amount,
        public readonly string $currency,
        private PaymentStatus $status = PaymentStatus::Pending,
    ) {}

    public function transitionTo(PaymentStatus $newStatus): void
    {
        if (!$this->status->canTransitionTo($newStatus)) {
            throw new LogicException(
                "Cannot transition from {$this->status->value} to {$newStatus->value}"
            );
        }
        $this->status = $newStatus;
    }
}

$payment = new Payment(99.99, 'USD');
$payment->transitionTo(PaymentStatus::Completed); // OK
$payment->transitionTo(PaymentStatus::Pending);   // LogicException!
```

Enums prevent typos, readonly properties protect immutability, and the code is type-safe.

### Conclusion

PHP 8.1 introduced enums (including backed enums with values), readonly properties, fibers for async programming, intersection types (`A&B`), first-class callable syntax (`strlen(...)`), the `never` return type, and array unpacking with string keys. Enums and readonly properties are the most commonly used features from this release.
