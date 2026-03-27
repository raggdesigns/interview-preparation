PHP 8.0 je objavljen u novembru 2020. godine. Bio je to major verzija sa mnogo novih mogućnosti i breaking promena.

### Named arguments

Možete prosleđivati argumente funkciji po njihovom imenu, a ne samo po poziciji:

```php
// Before PHP 8.0
htmlspecialchars($string, ENT_COMPAT | ENT_HTML5, 'UTF-8', false);

// PHP 8.0 — much clearer
htmlspecialchars($string, double_encode: false);
```

Ovo je veoma korisno kada funkcija ima mnogo opcionih parametara, a vi trebate da postavite samo jedan od njih.

### Union types

Parametar ili povratni tip može prihvatiti više tipova:

```php
function processInput(int|string $input): int|false
{
    if (is_string($input)) {
        return strlen($input);
    }
    return $input > 0 ? $input : false;
}
```

### Match izraz

Stroži oblik `switch`-a koji vraća vrednost i koristi striktno poređenje (`===`):

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

Važne razlike od `switch`-a:
- `match` koristi striktno poređenje (`===`), a ne labavo (`==`)
- `match` vraća vrednost
- Nema potrebe za `break` — izvršava se samo jedna grana
- Baca `UnhandledMatchError` ako se nijedna grana ne podudara i nema `default`-a

### Promocija konstruktora

Deklarišite i dodelite propertije direktno u parametrima konstruktora:

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

Ovo uklanja mnogo boilerplate koda u value objektima i DTO-ovima.

### Atributi (Annotations)

Atributi zamenjuju PHP docblock anotacije sa pravom jezičkom sintaksom:

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

Možete kreirati sopstvene atribute:

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

### Nullsafe operator (?->)

Lančajte pozive metoda i automatski vraćajte null ako je bilo koji deo null:

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

Nove string funkcije koje zamenjuju zbunjujuće provere sa `strpos()`:

```php
// Before
if (strpos($haystack, 'needle') !== false) { /* found */ }

// PHP 8.0
if (str_contains($haystack, 'needle')) { /* found */ }
if (str_starts_with($url, 'https://')) { /* ... */ }
if (str_ends_with($file, '.php')) { /* ... */ }
```

### Throw kao izraz

`throw` se sada može koristiti u izrazima:

```php
$user = $repository->find($id) ?? throw new UserNotFoundException();

$value = $condition ? getValue() : throw new LogicException('Unexpected');
```

### WeakMap

Mapa gde su ključevi objekti i ne sprečavaju garbage collection:

```php
$cache = new WeakMap();

$obj = new stdClass();
$cache[$obj] = ['computed' => 'data'];

unset($obj); // The entry in WeakMap is also removed automatically
```

### JIT (Just-In-Time Compilation)

PHP 8.0 je dodao JIT kompajler koji može kompajlirati PHP kod u mašinski kod pri pokretanju. Uglavnom pomaže zadacima intenzivnim u pogledu procesora (matematika, obrada slika). Za tipične web aplikacije, poboljšanje je manje jer se većina vremena troši na I/O (baza podataka, mreža).

### Realni scenario

Gradite REST API kontroler. Pre PHP 8.0:

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

Nakon PHP 8.0:

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

Kod je mnogo kraći i lakši za čitanje.

### Zaključak

PHP 8.0 je bio major release sa named argumentima, union types, match izrazom, promocijom konstruktora, atributima, nullsafe operatorom `?->`, novim string funkcijama, throw kao izrazom, WeakMap-om i JIT kompajliranjem. Ove mogućnosti su značajno smanjile boilerplate i učinile jezik ekspresivnijim.
