PHP 8.3 was released in November 2023. It brought improvements to readonly properties, class constants, and added useful new functions.

### Typed Class Constants

Class constants can now have type declarations:

```php
class Config
{
    const string DATABASE_HOST = 'localhost';
    const int DATABASE_PORT = 3306;
    const bool DEBUG_MODE = false;
}

interface HasVersion
{
    const string VERSION = '1.0'; // Implementing classes must use string type
}
```

This prevents child classes from changing the constant's type:

```php
class Base
{
    const string NAME = 'Base';
}

class Child extends Base
{
    const string NAME = 'Child'; // OK
    // const int NAME = 42;      // Error! Must be string
}
```

### `json_validate()` Function

Check if a string is valid JSON without decoding it:

```php
// Before PHP 8.3
function isValidJson(string $json): bool
{
    json_decode($json);
    return json_last_error() === JSON_ERROR_NONE;
}

// PHP 8.3
$valid = json_validate('{"name": "John"}');  // true
$valid = json_validate('not json');           // false
```

This is faster than `json_decode()` because it only validates the structure without building the data in memory.

### `#[Override]` Attribute

Marks a method that is supposed to override a parent method. If the parent method does not exist (e.g., after renaming), PHP throws an error:

```php
class Animal
{
    public function makeSound(): string
    {
        return 'Some sound';
    }
}

class Dog extends Animal
{
    #[Override]
    public function makeSound(): string
    {
        return 'Woof!';
    }
}
```

If someone renames `makeSound()` in the parent to `sound()`, PHP will immediately show an error in `Dog` class because the method marked with `#[Override]` no longer overrides anything:

```php
class Animal
{
    public function sound(): string  // renamed from makeSound()
    {
        return 'Some sound';
    }
}

class Dog extends Animal
{
    #[Override]
    public function makeSound(): string  // Error! This no longer overrides a parent method
    {
        return 'Woof!';
    }
}
```

### Deep Cloning of Readonly Properties

In PHP 8.2, you could not modify readonly properties even inside `__clone()`. PHP 8.3 fixes this:

```php
readonly class Address
{
    public function __construct(
        public string $city,
        public string $street,
    ) {}
}

readonly class User
{
    public function __construct(
        public string $name,
        public Address $address,
    ) {}

    public function withCity(string $city): self
    {
        $clone = clone $this;
        // PHP 8.3 allows this inside __clone:
        $clone->address = new Address($city, $this->address->street);
        return $clone;
    }
}
```

### Dynamic Class Constant Fetch

You can now use variables to access class constants:

```php
class Permissions
{
    const READ = 1;
    const WRITE = 2;
    const DELETE = 4;
}

$action = 'READ';
$value = Permissions::{$action}; // 1
```

### `Randomizer` Additions

New methods were added to the `Random\Randomizer` class:

```php
$rng = new Random\Randomizer();

// Get random bytes as string
$bytes = $rng->getBytesFromString('abcdef0123456789', 8);
// e.g. "a3f1b9d0" — 8 characters from the given set

// Get a random float between 0 and 1
$float = $rng->nextFloat();

// Get a random float in a range
$float = $rng->getFloat(1.0, 10.0);
```

### `array_any()` and `array_all()` - `mb_str_pad()`

New helpful utility functions:

```php
// Multibyte-safe string padding (useful for non-Latin characters)
echo mb_str_pad('Привет', 10, ' ');  // "Привет    " — correctly counts 6 chars, not bytes
```

### Real Scenario

You are building a REST API where you need to validate incoming JSON and use typed constants for configuration:

```php
readonly class ApiConfig
{
    const string API_VERSION = 'v2';
    const int MAX_PAGE_SIZE = 100;
    const int DEFAULT_PAGE_SIZE = 20;
}

class ApiController
{
    #[Override]
    public function handleRequest(string $body): Response
    {
        // Fast JSON validation without decoding
        if (!json_validate($body)) {
            return new Response(400, 'Invalid JSON');
        }

        $data = json_decode($body, true);
        $pageSize = min(
            $data['page_size'] ?? ApiConfig::DEFAULT_PAGE_SIZE,
            ApiConfig::MAX_PAGE_SIZE
        );

        return $this->processData($data, $pageSize);
    }
}
```

If someone later renames `handleRequest` in the parent class, the `#[Override]` attribute will immediately catch the mistake. Typed constants ensure that `MAX_PAGE_SIZE` is always an integer. And `json_validate()` provides fast validation before expensive decoding.

### Conclusion

PHP 8.3 added typed class constants, `json_validate()` for fast JSON checking, `#[Override]` attribute to catch broken method overrides, deep cloning of readonly properties, dynamic class constant fetch, and new Randomizer methods. These features improve code safety and make everyday tasks simpler.
