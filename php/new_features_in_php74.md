PHP 7.4 was released in November 2019. It introduced several important features that made PHP code shorter and more expressive.

### Typed Properties

Before PHP 7.4, class properties could not have type declarations. Now they can:

```php
class User
{
    public int $id;
    public string $name;
    public ?string $email = null; // nullable
    public array $roles = [];
}

$user = new User();
$user->id = 1;        // OK
$user->id = "hello";  // TypeError!
```

### Arrow Functions (Short Closures)

A shorter syntax for simple anonymous functions. Arrow functions automatically capture variables from the outer scope (no need for `use`):

```php
// Before PHP 7.4
$doubled = array_map(function ($n) {
    return $n * 2;
}, [1, 2, 3]);

// PHP 7.4
$doubled = array_map(fn($n) => $n * 2, [1, 2, 3]);
```

Arrow functions capture outer variables by value automatically:

```php
$multiplier = 3;

// Before: need 'use'
$fn = function ($n) use ($multiplier) {
    return $n * $multiplier;
};

// PHP 7.4: automatic capture
$fn = fn($n) => $n * $multiplier;
```

### Null Coalescing Assignment Operator (??=)

Assigns a value only if the variable is null or not set:

```php
// Before PHP 7.4
if (!isset($data['timezone'])) {
    $data['timezone'] = 'UTC';
}

// Or
$data['timezone'] = $data['timezone'] ?? 'UTC';

// PHP 7.4
$data['timezone'] ??= 'UTC';
```

### Spread Operator in Arrays

You can use `...` to unpack arrays inside other arrays:

```php
$defaults = ['color' => 'blue', 'size' => 'M'];
$custom = ['size' => 'L', 'weight' => 100];

// Works with numeric keys
$numbers = [1, 2, 3];
$more = [0, ...$numbers, 4, 5]; // [0, 1, 2, 3, 4, 5]

// Also works inside function calls (already existed before 7.4)
function sum(int ...$numbers): int {
    return array_sum($numbers);
}
```

### Preloading

PHP 7.4 introduced OPCache preloading. On server start, PHP can load specific files into memory once. These files stay in memory for all requests, so they do not need to be compiled again:

```php
// preload.php (set in php.ini: opcache.preload=preload.php)
$files = glob(__DIR__ . '/src/**/*.php');
foreach ($files as $file) {
    opcache_compile_file($file);
}
```

This improves performance for frameworks with many files. The downside is that you must restart the server to see changes in preloaded files.

### Weak References

A weak reference lets you hold a reference to an object without preventing it from being destroyed by the garbage collector:

```php
$object = new stdClass();
$weakRef = WeakReference::create($object);

echo $weakRef->get() !== null; // true — object exists

unset($object);

echo $weakRef->get(); // null — object was garbage collected
```

### Numeric Literal Separator

Underscores can be used in numbers to make them easier to read:

```php
$million = 1_000_000;
$price = 19_99; // 1999
$hex = 0xFF_AA_BB;
$binary = 0b1010_0001;
```

### Covariant Returns and Contravariant Parameters

Child classes can now return more specific types and accept broader parameter types:

```php
class Animal {}
class Dog extends Animal {}

class AnimalFactory
{
    public function create(): Animal { return new Animal(); }
}

class DogFactory extends AnimalFactory
{
    public function create(): Dog { return new Dog(); } // Covariant return — allowed in 7.4
}
```

### Real Scenario

You are refactoring a user registration service. Before PHP 7.4, the code looks like this:

```php
class RegistrationService
{
    private $validator;
    private $repository;
    private $mailer;
    
    public function register(array $data)
    {
        if (!isset($data['role'])) {
            $data['role'] = 'user';
        }
        
        $errors = array_filter($data, function ($value) {
            return empty($value);
        });
        // ...
    }
}
```

After PHP 7.4:

```php
class RegistrationService
{
    private Validator $validator;
    private UserRepository $repository;
    private Mailer $mailer;
    
    public function register(array $data): void
    {
        $data['role'] ??= 'user';
        
        $errors = array_filter($data, fn($value) => empty($value));
        // ...
    }
}
```

The code becomes shorter, safer (typed properties catch wrong types immediately), and easier to read.

### Conclusion

PHP 7.4 added typed properties, arrow functions (`fn() =>`), null coalescing assignment (`??=`), spread operator in arrays, preloading, weak references, numeric separators, and covariant returns. These features reduced boilerplate and improved type safety significantly.
