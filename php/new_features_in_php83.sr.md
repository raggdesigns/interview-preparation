PHP 8.3 je objavljen u novembru 2023. godine. Doneo je poboljšanja readonly properties, konstantama klase i dodao korisne nove funkcije.

### Typed konstante klase

Konstante klase sada mogu imati deklaracije tipova:

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

Ovo sprečava podklase da menjaju tip konstante:

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

### Funkcija `json_validate()`

Proverite da li je string validni JSON bez dekodiranja:

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

Ovo je brže od `json_decode()` jer samo validira strukturu bez izgradnje podataka u memoriji.

### Atribut `#[Override]`

Označava metodu koja treba da prepiše metodu roditelja. Ako metoda roditelja ne postoji (npr. nakon preimenovanja), PHP baca grešku:

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

Ako neko preimenuje `makeSound()` u roditeljskoj klasi u `sound()`, PHP će odmah prikazati grešku u klasi `Dog` jer metoda označena sa `#[Override]` više ništa ne prepisuje:

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

### Duboko kloniranje readonly properties

U PHP 8.2, niste mogli menjati readonly properties čak ni unutar `__clone()`. PHP 8.3 to ispravlja:

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

### Dinamičko dohvatanje konstanti klase

Sada možete koristiti promenljive za pristup konstantama klase:

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

### Dodaci klasi `Randomizer`

Nove metode su dodate u klasu `Random\Randomizer`:

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

### `array_any()`, `array_all()` i `mb_str_pad()`

Nove korisne utility funkcije:

```php
// Multibyte-safe string padding (useful for non-Latin characters)
echo mb_str_pad('Привет', 10, ' ');  // "Привет    " — correctly counts 6 chars, not bytes
```

### Realni scenario

Gradite REST API gde trebate validirati dolazni JSON i koristiti typed konstante za konfiguraciju:

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

Ako neko kasnije preimenuje `handleRequest` u roditeljskoj klasi, atribut `#[Override]` će odmah uhvatiti grešku. Typed konstante osiguravaju da je `MAX_PAGE_SIZE` uvek integer. A `json_validate()` pruža brzu validaciju pre skupog dekodiranja.

### Zaključak

PHP 8.3 je dodao typed konstante klase, `json_validate()` za brzu proveru JSON-a, atribut `#[Override]` za hvatanje prekinutih prepisivanja metoda, duboko kloniranje readonly properties, dinamičko dohvatanje konstanti klase i nove Randomizer metode. Ove mogućnosti poboljšavaju bezbednost koda i čine svakodnevne zadatke jednostavnijim.
