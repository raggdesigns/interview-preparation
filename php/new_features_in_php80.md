PHP 8.0 was released in November 2020. It was a major version with many new features and breaking changes.

### Named Arguments

You can pass arguments to a function by their name, not just by position:

```php
// Before PHP 8.0
htmlspecialchars($string, ENT_COMPAT | ENT_HTML5, 'UTF-8', false);

// PHP 8.0 — much clearer
htmlspecialchars($string, double_encode: false);
```

This is very useful when a function has many optional parameters and you only need to set one of them.

### Union Types

A parameter or return type can accept multiple types:

```php
function processInput(int|string $input): int|false
{
    if (is_string($input)) {
        return strlen($input);
    }
    return $input > 0 ? $input : false;
}
```

### Match Expression

A stricter version of `switch` that returns a value and uses strict comparison (`===`):

```php
// Old switch
switch ($status) {
    case 'active':
        $label = 'Active';
        break;
    case 'inactive':
        $label = 'Inactive';
        break;
    default:
        $label = 'Unknown';
}

// PHP 8.0 match
$label = match($status) {
    'active' => 'Active',
    'inactive' => 'Inactive',
    default => 'Unknown',
};
```

Important differences from `switch`:
- `match` uses strict comparison (`===`), not loose (`==`)
- `match` returns a value
- No need for `break` — only one branch runs
- Throws `UnhandledMatchError` if no branch matches and no `default`

### Constructor Promotion

Declare and assign properties directly in the constructor parameters:

```php
// Before PHP 8.0
class User
{
    private string $name;
    private string $email;

    public function __construct(string $name, string $email)
    {
        $this->name = $name;
        $this->email = $email;
    }
}

// PHP 8.0
class User
{
    public function __construct(
        private string $name,
        private string $email,
    ) {}
}
```

This removes a lot of boilerplate code in value objects and DTOs.

### Attributes (Annotations)

Attributes replace PHP docblock annotations with real language syntax:

```php
// Before: PHPDoc annotations (parsed by frameworks, not by PHP itself)
/** @Route("/api/users", methods={"GET"}) */

// PHP 8.0: native attributes
#[Route('/api/users', methods: ['GET'])]
class UserController
{
    #[Required]
    private LoggerInterface $logger;
}
```

You can create your own attributes:

```php
#[Attribute]
class Validate
{
    public function __construct(
        public string $rule,
        public ?string $message = null,
    ) {}
}

class RegisterRequest
{
    #[Validate('email', message: 'Invalid email')]
    public string $email;

    #[Validate('min:8', message: 'Password too short')]
    public string $password;
}
```

### Nullsafe Operator (?->)

Chain method calls and automatically return null if any part is null:

```php
// Before PHP 8.0
$country = null;
if ($user !== null) {
    $address = $user->getAddress();
    if ($address !== null) {
        $country = $address->getCountry();
    }
}

// PHP 8.0
$country = $user?->getAddress()?->getCountry();
```

### str_contains(), str_starts_with(), str_ends_with()

New string functions that replace confusing `strpos()` checks:

```php
// Before
if (strpos($haystack, 'needle') !== false) { /* found */ }

// PHP 8.0
if (str_contains($haystack, 'needle')) { /* found */ }
if (str_starts_with($url, 'https://')) { /* ... */ }
if (str_ends_with($file, '.php')) { /* ... */ }
```

### Throw as Expression

`throw` can now be used in expressions:

```php
$user = $repository->find($id) ?? throw new UserNotFoundException();

$value = $condition ? getValue() : throw new LogicException('Unexpected');
```

### WeakMap

A map where keys are objects and do not prevent garbage collection:

```php
$cache = new WeakMap();

$obj = new stdClass();
$cache[$obj] = ['computed' => 'data'];

unset($obj); // The entry in WeakMap is also removed automatically
```

### JIT (Just-In-Time Compilation)

PHP 8.0 added a JIT compiler that can compile PHP code into machine code at runtime. It mostly helps CPU-heavy tasks (math, image processing). For typical web applications, the improvement is smaller because most time is spent on I/O (database, network).

### Real Scenario

You are building a REST API controller. Before PHP 8.0:

```php
class OrderController
{
    private OrderService $orderService;
    private LoggerInterface $logger;

    public function __construct(OrderService $orderService, LoggerInterface $logger)
    {
        $this->orderService = $orderService;
        $this->logger = $logger;
    }

    /** @Route("/orders/{id}", methods={"GET"}) */
    public function show(int $id): Response
    {
        $order = $this->orderService->find($id);
        
        if ($order === null) {
            throw new NotFoundException();
        }
        
        $customerName = null;
        $customer = $order->getCustomer();
        if ($customer !== null) {
            $customerName = $customer->getName();
        }
        
        switch ($order->getStatus()) {
            case 'pending': $label = 'Pending'; break;
            case 'shipped': $label = 'Shipped'; break;
            default: $label = 'Unknown';
        }
        
        return new JsonResponse(['customer' => $customerName, 'status' => $label]);
    }
}
```

After PHP 8.0:

```php
class OrderController
{
    public function __construct(
        private OrderService $orderService,
        private LoggerInterface $logger,
    ) {}

    #[Route('/orders/{id}', methods: ['GET'])]
    public function show(int $id): Response
    {
        $order = $this->orderService->find($id) ?? throw new NotFoundException();
        
        $customerName = $order->getCustomer()?->getName();
        
        $label = match($order->getStatus()) {
            'pending' => 'Pending',
            'shipped' => 'Shipped',
            default => 'Unknown',
        };
        
        return new JsonResponse(['customer' => $customerName, 'status' => $label]);
    }
}
```

The code is much shorter and easier to read.

### Conclusion

PHP 8.0 was a major release with named arguments, union types, match expression, constructor promotion, attributes, nullsafe operator `?->`, new string functions, throw as expression, WeakMap, and JIT compilation. These features significantly reduced boilerplate and made the language more expressive.
