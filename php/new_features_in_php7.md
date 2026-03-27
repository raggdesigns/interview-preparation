PHP 7 was a major update released in December 2015. It brought huge performance improvements and many new language features compared to PHP 5.

### Performance Boost

PHP 7 is about two times faster than PHP 5. This happened because of a new engine called "Zend Engine 3" (also known as PHPNG). It uses less memory and processes requests much faster.

### Scalar Type Declarations

In PHP 5, you could only type-hint classes, arrays, and callables. PHP 7 allows type hints for simple types like `int`, `float`, `string`, and `bool`:

```php
// PHP 5 — no way to enforce parameter types for scalars
function add($a, $b) {
    return $a + $b;
}

// PHP 7 — scalar type hints
function add(int $a, int $b): int {
    return $a + $b;
}
```

### Strict Mode

You can enable strict type checking with `declare(strict_types=1)`:

```php
declare(strict_types=1);

function double(int $value): int {
    return $value * 2;
}

double("5"); // TypeError! In non-strict mode it would work and cast "5" to 5
```

### Return Type Declarations

Functions and methods can declare what type they return:

```php
function getUser(int $id): User {
    return $this->repository->find($id);
}
```

### Null Coalescing Operator (??)

A shorter way to check if a value exists and is not null:

```php
// PHP 5
$username = isset($_GET['user']) ? $_GET['user'] : 'guest';

// PHP 7
$username = $_GET['user'] ?? 'guest';
```

### Spaceship Operator (<=>)

Compares two values and returns -1, 0, or 1:

```php
echo 1 <=> 2;  // -1
echo 1 <=> 1;  //  0
echo 2 <=> 1;  //  1

// Useful for sorting
usort($users, function ($a, $b) {
    return $a->age <=> $b->age;
});
```

### Anonymous Classes

You can create a class without a name:

```php
$logger = new class {
    public function log(string $message): void {
        echo $message;
    }
};

$logger->log('Hello!');
```

### Group Use Declarations

Import multiple classes from the same namespace in one line:

```php
// PHP 5
use App\Models\User;
use App\Models\Post;
use App\Models\Comment;

// PHP 7
use App\Models\{User, Post, Comment};
```

### Error Handling Changes

PHP 7 changed how errors work. Fatal errors now throw `Error` exceptions that you can catch:

```php
// PHP 5: calling undefined method = fatal error, cannot catch it

// PHP 7: you can catch it
try {
    $obj = new stdClass();
    $obj->undefinedMethod();
} catch (Error $e) {
    echo "Caught error: " . $e->getMessage();
}
```

Both `Error` and `Exception` implement the `Throwable` interface:

```text
Throwable
├── Error
│   ├── TypeError
│   ├── ParseError
│   └── ArithmeticError
└── Exception
    ├── RuntimeException
    └── ...
```

### Removed Features from PHP 5

- MySQL extension (`mysql_*` functions) — removed, use `mysqli` or PDO instead
- Old-style constructors (method with same name as class) — deprecated
- `ereg_*` functions — removed, use `preg_*` instead

### Real Scenario

You have an online store running on PHP 5.6. The page load time is 400ms. After upgrading to PHP 7, the same page loads in about 200ms — without changing any code. Then you add scalar type hints to your service classes:

```php
declare(strict_types=1);

class PriceCalculator
{
    public function calculateDiscount(float $price, int $percentage): float
    {
        if ($percentage < 0 || $percentage > 100) {
            throw new InvalidArgumentException('Percentage must be 0-100');
        }
        return $price - ($price * $percentage / 100);
    }
}

// If someone passes a string by mistake, PHP 7 strict mode catches it immediately
$calc = new PriceCalculator();
$calc->calculateDiscount("100", 10); // TypeError in strict mode!
```

### Conclusion

PHP 7 was the biggest PHP upgrade in years. It doubled the performance, added scalar type declarations, return types, null coalescing operator `??`, spaceship operator `<=>`, anonymous classes, and changed error handling to use exceptions instead of fatal errors. These changes made PHP much more reliable and fast.
