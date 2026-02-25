PHP 8.4 was released in November 2024. It brought property hooks, asymmetric visibility, and several quality-of-life improvements.

### Property Hooks

Property hooks let you define `get` and `set` behavior directly on a property, without writing separate getter/setter methods:

```php
class User
{
    public string $name {
        set(string $value) {
            $this->name = trim($value);
        }
    }

    public string $email {
        set(string $value) {
            if (!str_contains($value, '@')) {
                throw new InvalidArgumentException('Invalid email');
            }
            $this->email = strtolower($value);
        }
        get => strtoupper($this->email);
    }
}

$user = new User();
$user->name = '  John  '; // Stored as "John"
$user->email = 'John@Example.com'; // Stored as "john@example.com"
echo $user->email; // "JOHN@EXAMPLE.COM" (get hook applies)
```

This replaces the common pattern of private property + public getter/setter:

```php
// Before PHP 8.4
class User
{
    private string $name;

    public function getName(): string { return $this->name; }
    
    public function setName(string $name): void {
        $this->name = trim($name);
    }
}

// PHP 8.4 — much shorter
class User
{
    public string $name {
        set(string $value) {
            $this->name = trim($value);
        }
    }
}
```

#### Virtual Properties

If a property only has a `get` hook and no `set`, it becomes a virtual (computed) property that uses no storage:

```php
class Rectangle
{
    public function __construct(
        public float $width,
        public float $height,
    ) {}

    public float $area {
        get => $this->width * $this->height;
    }
}

$r = new Rectangle(5, 3);
echo $r->area; // 15
```

### Asymmetric Visibility

You can set different visibility for reading and writing a property:

```php
class BankAccount
{
    public function __construct(
        public private(set) string $owner,     // Public read, private write
        public protected(set) float $balance,  // Public read, protected write
    ) {}

    public function deposit(float $amount): void
    {
        $this->balance += $amount; // OK — inside the class
    }
}

$account = new BankAccount('Alice', 100.0);
echo $account->owner;    // OK — public read
echo $account->balance;  // OK — public read
$account->owner = 'Bob'; // Error! Private write — only inside the class
```

This eliminates the need for readonly in many cases, because you can still modify the property inside the class.

### `new` Without Parentheses

When creating an object and immediately calling a method or accessing a property, you no longer need extra parentheses:

```php
// Before PHP 8.4
$name = (new ReflectionClass(User::class))->getName();
$items = (new Collection([1, 2, 3]))->filter(fn($n) => $n > 1);

// PHP 8.4
$name = new ReflectionClass(User::class)->getName();
$items = new Collection([1, 2, 3])->filter(fn($n) => $n > 1);
```

### Lazy Objects

PHP 8.4 adds built-in support for lazy objects through the Reflection API. A lazy object delays its initialization until it is actually used:

```php
$reflector = new ReflectionClass(HeavyService::class);

$proxy = $reflector->newLazyProxy(function () {
    // This runs only when the object is first accessed
    echo "Initializing...\n";
    return new HeavyService();
});

// No initialization yet
echo "Created proxy\n";

// NOW it initializes
$proxy->doWork(); // Prints "Initializing..." then does work
```

This is useful for dependency injection containers and ORMs like Doctrine.

### Array Functions: `array_find()`, `array_find_key()`, `array_any()`, `array_all()`

New functions to search and check arrays without writing loops:

```php
$users = [
    ['name' => 'Alice', 'age' => 30],
    ['name' => 'Bob', 'age' => 17],
    ['name' => 'Charlie', 'age' => 25],
];

// Find first matching element
$minor = array_find($users, fn($u) => $u['age'] < 18);
// ['name' => 'Bob', 'age' => 17]

// Find key of first match
$key = array_find_key($users, fn($u) => $u['name'] === 'Charlie');
// 2

// Check if ANY element matches
$hasMinors = array_any($users, fn($u) => $u['age'] < 18);
// true

// Check if ALL elements match
$allAdults = array_all($users, fn($u) => $u['age'] >= 18);
// false
```

### `#[\Deprecated]` Attribute

You can now mark your own functions and methods as deprecated using a native attribute:

```php
class PaymentService
{
    #[\Deprecated("Use processPayment() instead", since: "2.0")]
    public function pay(float $amount): void
    {
        $this->processPayment($amount);
    }

    public function processPayment(float $amount): void
    {
        // new implementation
    }
}

$service = new PaymentService();
$service->pay(100); // E_USER_DEPRECATED: Use processPayment() instead
```

### `mb_trim()`, `mb_ltrim()`, `mb_rtrim()`

Multibyte-safe versions of string trimming functions:

```php
$text = "　Hello World　"; // Japanese full-width spaces
echo mb_trim($text); // "Hello World"
```

### Real Scenario

You are building a user profile system. Before PHP 8.4:

```php
class UserProfile
{
    private string $displayName;
    private string $email;

    public function __construct(string $displayName, string $email)
    {
        $this->setDisplayName($displayName);
        $this->setEmail($email);
    }

    public function getDisplayName(): string { return $this->displayName; }
    
    public function setDisplayName(string $name): void {
        $name = trim($name);
        if (strlen($name) < 2) throw new InvalidArgumentException('Name too short');
        $this->displayName = $name;
    }

    public function getEmail(): string { return $this->email; }

    public function setEmail(string $email): void {
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new InvalidArgumentException('Invalid email');
        }
        $this->email = strtolower($email);
    }
}
```

After PHP 8.4:

```php
class UserProfile
{
    public string $displayName {
        set(string $value) {
            $value = trim($value);
            if (strlen($value) < 2) throw new InvalidArgumentException('Name too short');
            $this->displayName = $value;
        }
    }

    public private(set) string $email {
        set(string $value) {
            if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
                throw new InvalidArgumentException('Invalid email');
            }
            $this->email = strtolower($value);
        }
    }

    public function __construct(string $displayName, string $email)
    {
        $this->displayName = $displayName;
        $this->email = $email;
    }
}

$profile = new UserProfile('Alice', 'Alice@Example.COM');
echo $profile->displayName; // "Alice"
echo $profile->email;       // "alice@example.com"
```

Property hooks handle validation and transformation inline. Asymmetric visibility controls who can write where.

### Conclusion

PHP 8.4 introduced property hooks (get/set logic on properties), asymmetric visibility (`public private(set)`), `new` without parentheses for chaining, lazy objects, new array functions (`array_find`, `array_any`, `array_all`), the `#[\Deprecated]` attribute, and multibyte trim functions. Property hooks and asymmetric visibility are the biggest changes — they reduce boilerplate and make classes cleaner.
