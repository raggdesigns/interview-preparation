PHP 8.2 je objavljen u decembru 2022. godine. Fokusirao se na bezbednije klase, zastarevanje dinamičkih propertija i dodavanje novih mogućnosti tipova.

### Readonly klase

Umesto označavanja svakog propertija kao `readonly`, možete celu klasu učiniti readonly:

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

U readonly klasi, svi propertiji su automatski readonly. Ne možete dodati propertije koji nisu readonly ili propertije bez tipa.

### Disjunktivni normalni oblik (DNF) tipova

Možete kombinovati union i intersection tipove zajedno:

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

### Zastarevanje dinamičkih propertija

Kreiranje propertija koji nisu deklarisani u klasi sada je zastarelo:

```php
class User
{
    public string $name;
}

$user = new User();
$user->name = 'John';    // OK — declared property
$user->age = 30;          // Deprecated in PHP 8.2! Not declared in the class
```

Ako i dalje trebate dinamičke propertije, koristite atribut `#[AllowDynamicProperties]`:

```php
#[AllowDynamicProperties]
class FlexibleObject
{
    // Dynamic properties allowed here
}
```

### Konstante u traitovima

Traitovi sada mogu definisati konstante:

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

Napomena: Konstantama ne možete pristupiti direktno kroz naziv traita (`HasVersion::VERSION` nije dozvoljeno).

### Enum konstante u izrazima

Enumovi se mogu koristiti u konstantnim izrazima:

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

### `true`, `false` i `null` kao samostalni tipovi

Ovi tipovi se sada mogu koristiti kao deklaracije tipova:

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

Tip `false` je koristan kada funkcija vraća određeni tip ili `false` u slučaju greške:

```php
function findIndex(array $items, mixed $search): int|false
{
    $index = array_search($search, $items);
    return $index; // returns int or false
}
```

### Atribut za osetljive parametre

Sakrijte osetljive podatke (kao što su lozinke) iz stack trace-ova:

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

### Random ekstenzija

Novi objektno-orijentisani API za generisanje slučajnih brojeva:

```php
$rng = new Random\Randomizer();

echo $rng->nextInt();                    // Random integer
echo $rng->getInt(1, 100);              // Random int between 1 and 100
echo $rng->shuffleString('Hello');       // e.g. "lHleo"
echo $rng->shuffleArray([1, 2, 3, 4]); // e.g. [3, 1, 4, 2]

// Reproducible results with a seed
$rng = new Random\Randomizer(new Random\Engine\Mt19937(42));
```

### Realni scenario

Gradite value objekat za novac za finansijsku aplikaciju. PHP 8.2 ovo čini veoma čistim:

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

`readonly class` osigurava nepromenljivost celog objekta sa minimalnom sintaksom.

### Zaključak

PHP 8.2 je dodao readonly klase, DNF tipove (kombinovanje union i intersection tipova), zastarevanje dinamičkih propertija, dozvolio konstante u traitovima, uveo `true`/`false`/`null` kao samostalne tipove, dodao `#[SensitiveParameter]` za bezbednost i novu Random ekstenziju. Mogućnost readonly klase je posebno važna za izgradnju value objekata i DTO-ova.
