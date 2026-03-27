Ovaj fajl pokriva zamršena PHP pitanja za intervjue sa jasnim objašnjenjima i primerima.

---

### 1. Niz sa ključevima 0, 1, 2, 3 i "Hello" — koji će biti ključ za sledeću vrednost?

Kada dodate novi element nizu bez navođenja ključa, PHP mu daje sledeći integer ključ. PHP gleda **najviši integer ključ** koji je do sada korišćen i dodaje 1.

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

Izlaz:
```
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

**Ključno pravilo:** PHP ignoriše string ključeve pri računanju sledećeg integer indeksa. Gleda samo najviši integer ključ (koji je 3) i dodaje 1 da bi dobio 4.

#### Zamršena varijacija:

```php
$arr = [
    0 => 'a',
    5 => 'b',
    'Hello' => 'c',
];

$arr[] = 'new value'; // Key will be 6 (highest integer is 5, so 5 + 1 = 6)
```

---

### 2. Klase A, B, C: A ima javni konstruktor, B ima privatni konstruktor, C proširuje B — koji konstruktor nasleđuje C?

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

**Odgovor:** C nasleđuje B-ov privatni konstruktor, ali ga **ne može koristiti**. Ako pokušate `new C()`, dobićete fatalni error.

```php
$c = new C(); // Fatal error: Call to private B::__construct() from global scope
```

**Zašto?** Kada klasa proširuje drugu, nasleđuje sve metode — uključujući konstruktor. Ali privatne metode se mogu pozivati samo unutar klase gde su definisane (klasa B). Pošto `C` ne definiše sopstveni konstruktor, PHP pokušava da pozove `B::__construct()`, koji je privatan.

**Kako ispraviti:** C mora definisati sopstveni konstruktor:

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

Napomena: Klasa `A` uopšte nije uključena. `C` proširuje `B`, ne `A`.

---

### 3. Kako pozvati metodu roditelja sa istim nazivom iz podklase?

Koristite ključnu reč `parent::`:

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

Ovo funkcioniše za svaku metodu, uključujući konstruktor:

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

**Važno:** `parent::` uvek referiše na neposrednu roditeljsku klasu. Ako je metoda roditelja privatna, ne možete je pozivati iz podklase.

---

### 4. Kako pronaći drugi najveći broj u nesortiranojlisti koristeći samo jednu iteraciju?

Pratite dve promenljive: najveću i drugi najveći. Prođite kroz listu jednom i ažurirajte ih:

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

**Korak-po-korak primer** sa `[3, 1, 7, 5, 2]`:

```
Start:   first = -∞,  second = -∞

num = 3: 3 > -∞ → first = 3,  second = -∞
num = 1: 1 < 3, 1 > -∞ → second = 1
num = 7: 7 > 3 → first = 7,  second = 3
num = 5: 5 < 7, 5 > 3 → second = 5
num = 2: 2 < 7, 2 < 5 → no change

Result: first = 7, second = 5 ✓
```

**Vremenska složenost:** O(n) — jedan prolaz kroz listu.

---

### 5. Koja je razlika između `empty()` i `is_null()`?

`empty()` proverava da li je vrednost "prazna" (falsy). `is_null()` proverava da li je vrednost tačno `null`.

#### Šta `empty()` smatra praznim:

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

#### Šta `is_null()` smatra nullom:

```php
is_null(null);    // true

is_null('');      // false — empty string is NOT null
is_null(0);       // false
is_null(false);   // false
is_null([]);      // false
```

#### Tabela ključnih razlika:

| Vrednost | `empty()` | `is_null()` |
|----------|-----------|-------------|
| `null` | `true` | `true` |
| `''` | `true` | `false` |
| `0` | `true` | `false` |
| `'0'` | `true` | `false` |
| `false` | `true` | `false` |
| `[]` | `true` | `false` |
| `'hello'` | `false` | `false` |
| `1` | `false` | `false` |

#### Još jedna važna razlika:

`empty()` **ne** okida upozorenje za nedefinisane promenljive:

```php
// is_null($undefinedVar); // Warning: Undefined variable

empty($undefinedVar);      // No warning, returns true
```

### Realni scenario

Kada obrađujete podatke iz forme, izaberite pravu funkciju:

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

### Zaključak

- `empty()` proverava mnoge "falsy" vrednosti: `null`, `''`, `0`, `'0'`, `false`, `[]`
- `is_null()` proverava samo za `null`
- `empty()` je bezbedan sa nedefinisanim promenljivama (bez upozorenja)
- Za jasni kod, razmotrite korišćenje `=== null` umesto `is_null()`, i eksplicitnih provera kao `=== ''` ili `=== 0` umesto `empty()`
