PHP 8.1 je objavljen u novembru 2021. godine. Dodao je nekoliko važnih mogućnosti koje su promenile način na koji PHP programeri pišu kod.

### Enumeracije (Enumovi)

Enumovi vam omogućavaju da definišete tip sa fiksnim skupom mogućih vrednosti:

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

#### Backed enumovi

Enumovi mogu imati string ili integer vrednosti:

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

#### Enumovi sa metodama

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

### Readonly properties

Propertij koji se može postaviti samo jednom i ne može se menjati nakon toga:

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

Readonly properties moraju imati tip i mogu biti pisani samo iz opsega gde su definisani (obično iz konstruktora).

### Fiberi (Fibers)

Fiberi vam omogućavaju da pauzirate i nastavite izvršavanje koda. Oni su temelj za async framework-ove:

```php
$fiber = new Fiber(function (): void {
    $value = Fiber::suspend('Hello');
    echo "Fiber received: $value\n";
});

$result = $fiber->start();       // Runs until Fiber::suspend() — returns 'Hello'
echo "Main got: $result\n";     // "Main got: Hello"

$fiber->resume('World');         // Continues fiber — prints "Fiber received: World"
```

Fibere ne koristite direktno često. Koriste se od strane async biblioteka kao što su ReactPHP, Amp i Swoole interno.

### Intersection types

Parametar mora implementirati **sve** navedene tipove:

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

Ovo se razlikuje od union types (`A|B` — mora biti A **ili** B). Intersection types (`A&B` — mora biti A **i** B).

### First-class callable sintaksa

Možete kreirati closure iz bilo kog callable-a koristeći `...`:

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

### Never povratni tip

Funkcija koja nikada ne vraća (uvek baca izuzetak ili izlazi):

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

### Raspakovavanje nizova sa string ključevima

PHP 8.1 dozvoljava korišćenje spread operatora `...` sa string ključevima:

```php
$defaults = ['color' => 'blue', 'size' => 'M'];
$custom = ['size' => 'L', 'weight' => 100];

$merged = [...$defaults, ...$custom];
// ['color' => 'blue', 'size' => 'L', 'weight' => 100]
```

### Realni scenario

Gradite sistem plaćanja. Pre PHP 8.1, možda biste koristili string konstante za status plaćanja:

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

Nakon PHP 8.1:

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

Enumovi sprečavaju greške u kucanju, readonly properties štite nepromenljivost, a kod je type-safe.

### Zaključak

PHP 8.1 je uveo enumove (uključujući backed enumove sa vrednostima), readonly properties, fibere za async programiranje, intersection types (`A&B`), first-class callable sintaksu (`strlen(...)`), povratni tip `never` i raspakovavanje nizova sa string ključevima. Enumovi i readonly properties su najčešće korišćene mogućnosti iz ovog izdanja.
