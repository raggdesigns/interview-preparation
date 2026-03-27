PHP 8.4 je objavljen u novembru 2024. godine. Doneo je property hookove, asimetričnu vidljivost i nekoliko poboljšanja kvaliteta života.

### Property hooks

Property hookovi vam omogućavaju da definišete `get` i `set` ponašanje direktno na property-ju, bez pisanja posebnih getter/setter metoda:

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

Ovo zamenjuje uobičajeni obrazac privatnog property-ja + javnih getter/setter metoda:

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

#### Virtuelni properties

Ako property ima samo `get` hook i nema `set`, postaje virtuelni (izračunati) property koji ne koristi memoriju za skladištenje:

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

### Asimetrična vidljivost

Možete postaviti različitu vidljivost za čitanje i pisanje property-ja:

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

Ovo eliminiše potrebu za readonly u mnogim slučajevima, jer još uvek možete menjati property unutar klase.

### `new` bez zagrada

Kada kreirate objekat i odmah pozivate metodu ili pristupate property-ju, više ne trebate dodatne zagrade:

```php
// Before PHP 8.4
$name = (new ReflectionClass(User::class))->getName();
$items = (new Collection([1, 2, 3]))->filter(fn($n) => $n > 1);

// PHP 8.4
$name = new ReflectionClass(User::class)->getName();
$items = new Collection([1, 2, 3])->filter(fn($n) => $n > 1);
```

### Lazy objekti

PHP 8.4 dodaje ugrađenu podršku za lazy objekte kroz Reflection API. Lazy objekat odlaže svoju inicijalizaciju dok se zaista ne koristi:

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

Ovo je korisno za dependency injection kontejnere i ORM-ove kao što je Doctrine.

### Funkcije za nizove: `array_find()`, `array_find_key()`, `array_any()`, `array_all()`

Nove funkcije za pretragu i proveru nizova bez pisanja petlji:

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

### Atribut `#[\Deprecated]`

Sada možete označavati sopstvene funkcije i metode kao zastarele koristeći nativni atribut:

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

Multibyte-safe verzije funkcija za trimovanje stringova:

```php
$text = "　Hello World　"; // Japanese full-width spaces
echo mb_trim($text); // "Hello World"
```

### Realni scenario

Gradite sistem korisničkih profila. Pre PHP 8.4:

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

Nakon PHP 8.4:

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

Property hookovi rukuju validacijom i transformacijom inline. Asimetrična vidljivost kontroliše ko može pisati gde.

### Zaključak

PHP 8.4 je uveo property hookove (get/set logika na properties), asimetričnu vidljivost (`public private(set)`), `new` bez zagrada za lančanje, lazy objekte, nove funkcije za nizove (`array_find`, `array_any`, `array_all`), atribut `#[\Deprecated]` i multibyte trim funkcije. Property hookovi i asimetrična vidljivost su najveće promene — smanjuju boilerplate i čine klase čistijim.
