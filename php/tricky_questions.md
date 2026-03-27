This file covers tricky PHP interview questions with clear explanations and examples.

---

### 1. Array with keys 0, 1, 2, 3 and "Hello" — what will be the key for the next value?

When you add a new element to an array without specifying a key, PHP gives it the next integer key. PHP looks at the **highest integer key** used so far and adds 1.

```php
$arr = [
    0 => 'a',
    1 => 'b',
    2 => 'c',
    3 => 'd',
    'Hello' => 'e',
];

$arr[] = 'new value';

print_r($arr);
```

Output:

```text
Array
(
    [0] => a
    [1] => b
    [2] => c
    [3] => d
    [Hello] => e
    [4] => new value    <-- key is 4 (highest integer key 3 + 1)
)
```

**Key rule:** PHP ignores string keys when calculating the next integer index. It only looks at the highest integer key (which is 3), and adds 1 to get 4.

#### Tricky variation

```php
$arr = [
    0 => 'a',
    5 => 'b',
    'Hello' => 'c',
];

$arr[] = 'new value'; // Key will be 6 (highest integer is 5, so 5 + 1 = 6)
```

---

### 2. Classes A, B, C: A has public constructor, B has private constructor, C extends B — which constructor is inherited?

```php
class A
{
    public function __construct()
    {
        echo "A constructor\n";
    }
}

class B
{
    private function __construct()
    {
        echo "B constructor\n";
    }
}

class C extends B
{
    // Which constructor does C inherit?
}
```

**Answer:** C inherits B's private constructor, but it **cannot use it**. If you try `new C()`, you will get a fatal error.

```php
$c = new C(); // Fatal error: Call to private B::__construct() from global scope
```

**Why?** When a class extends another, it inherits all methods — including the constructor. But private methods can only be called from inside the class where they are defined (class B). Since `C` does not define its own constructor, PHP tries to call `B::__construct()`, which is private.

**How to fix:** C must define its own constructor:

```php
class C extends B
{
    public function __construct()
    {
        echo "C constructor\n";
        // Cannot call parent::__construct() because it is private
    }
}

$c = new C(); // "C constructor" — works fine
```

Note: Class `A` is not involved at all. `C` extends `B`, not `A`.

---

### 3. How to call a parent method with the same name from a child class?

Use the `parent::` keyword:

```php
class Animal
{
    public function speak(): string
    {
        return 'Some sound';
    }
}

class Dog extends Animal
{
    public function speak(): string
    {
        $parentSound = parent::speak(); // Calls Animal::speak()
        return $parentSound . ' + Woof!';
    }
}

$dog = new Dog();
echo $dog->speak(); // "Some sound + Woof!"
```

This works for any method, including the constructor:

```php
class BaseController
{
    public function __construct(
        protected LoggerInterface $logger,
    ) {}
}

class UserController extends BaseController
{
    public function __construct(
        LoggerInterface $logger,
        private UserRepository $users,
    ) {
        parent::__construct($logger); // Call parent's constructor
    }
}
```

**Important:** `parent::` always refers to the immediate parent class. If the parent method is private, you cannot call it from the child.

---

### 4. How to find second-largest number in an unsorted list using only one iteration?

Keep track of two variables: the largest and the second-largest. Go through the list once and update them:

```php
function findSecondLargest(array $numbers): int|float
{
    if (count($numbers) < 2) {
        throw new InvalidArgumentException('Need at least 2 numbers');
    }

    $first = PHP_INT_MIN;  // largest
    $second = PHP_INT_MIN; // second largest

    foreach ($numbers as $num) {
        if ($num > $first) {
            $second = $first;  // old largest becomes second
            $first = $num;     // new largest
        } elseif ($num > $second && $num !== $first) {
            $second = $num;    // new second largest
        }
    }

    if ($second === PHP_INT_MIN) {
        throw new RuntimeException('No second largest found (all values may be equal)');
    }

    return $second;
}
```

**Step-by-step example** with `[3, 1, 7, 5, 2]`:

```text
Start:   first = -∞,  second = -∞

num = 3: 3 > -∞ → first = 3,  second = -∞
num = 1: 1 < 3, 1 > -∞ → second = 1
num = 7: 7 > 3 → first = 7,  second = 3
num = 5: 5 < 7, 5 > 3 → second = 5
num = 2: 2 < 7, 2 < 5 → no change

Result: first = 7, second = 5 ✓
```

**Time complexity:** O(n) — one pass through the list.

---

### 5. What's the difference between `empty()` and `is_null()`?

`empty()` checks if a value is "empty" (falsy). `is_null()` checks if a value is exactly `null`.

#### What `empty()` considers empty

```php
empty('');        // true — empty string
empty(0);         // true — zero
empty(0.0);       // true — zero float
empty('0');       // true — string "0"
empty([]);        // true — empty array
empty(null);      // true — null
empty(false);     // true — boolean false

empty('hello');   // false
empty(1);         // false
empty([1, 2]);    // false
```

#### What `is_null()` considers null

```php
is_null(null);    // true

is_null('');      // false — empty string is NOT null
is_null(0);       // false
is_null(false);   // false
is_null([]);      // false
```

#### Key difference table

| Value | `empty()` | `is_null()` |
|-------|-----------|-------------|
| `null` | `true` | `true` |
| `''` | `true` | `false` |
| `0` | `true` | `false` |
| `'0'` | `true` | `false` |
| `false` | `true` | `false` |
| `[]` | `true` | `false` |
| `'hello'` | `false` | `false` |
| `1` | `false` | `false` |

#### Another important difference

`empty()` does **not** trigger a notice for undefined variables:

```php
// is_null($undefinedVar); // Warning: Undefined variable

empty($undefinedVar);      // No warning, returns true
```

### Real Scenario

When processing form data, choose the right function:

```php
// Use empty() to check if a field has any meaningful value
if (empty($_POST['username'])) {
    $errors[] = 'Username is required';
}

// Use is_null() to check if a value explicitly does not exist
$user = $repository->findByEmail($email);
if (is_null($user)) {
    throw new UserNotFoundException();
}

// The difference matters:
$quantity = 0;
empty($quantity);    // true — but 0 might be a valid quantity!
is_null($quantity);  // false — correctly shows it has a value

// In many cases, strict comparison is the clearest option:
if ($quantity === null) {
    // handle missing value
}
if ($quantity === 0) {
    // handle zero specifically
}
```

### Conclusion

- `empty()` checks for many "falsy" values: `null`, `''`, `0`, `'0'`, `false`, `[]`
- `is_null()` checks only for `null`
- `empty()` is safe with undefined variables (no warning)
- For clear code, consider using `=== null` instead of `is_null()`, and explicit checks like `=== ''` or `=== 0` instead of `empty()`
