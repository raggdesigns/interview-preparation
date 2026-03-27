PHP 7 je bio veliki update objavljen u decembru 2015. godine. Doneo je ogromna poboljšanja performansi i mnoge nove jezičke mogućnosti u poređenju sa PHP 5.

### Poboljšanje performansi

PHP 7 je otprilike dva puta brži od PHP 5. Do toga je došlo zbog novog engine-a nazvanog "Zend Engine 3" (poznat i kao PHPNG). Koristi manje memorije i obrađuje zahteve mnogo brže.

### Deklaracije skalarnih tipova

U PHP 5, mogli ste koristiti type hint samo za klase, nizove i callable-ove. PHP 7 omogućava type hint-ove za jednostavne tipove kao što su `int`, `float`, `string` i `bool`:

```php
// PHP 5 — no way to enforce parameter types for scalars
function add($a, $b) {
    return $a + $b;
}

// PHP 7 — scalar type hints
function add(int $a, int $b): int {
    return $a + $b;
}
```

### Strogi mod

Možete omogućiti striktnu proveru tipova sa `declare(strict_types=1)`:

```php
declare(strict_types=1);

function double(int $value): int {
    return $value * 2;
}

double("5"); // TypeError! In non-strict mode it would work and cast "5" to 5
```

### Deklaracije povratnog tipa

Funkcije i metode mogu deklarisati koji tip vraćaju:

```php
function getUser(int $id): User {
    return $this->repository->find($id);
}
```

### Null coalescing operator (??)

Kraći način za proveru da li vrednost postoji i nije null:

```php
// PHP 5
$username = isset($_GET['user']) ? $_GET['user'] : 'guest';

// PHP 7
$username = $_GET['user'] ?? 'guest';
```

### Spaceship operator (<=>)

Poredi dve vrednosti i vraća -1, 0 ili 1:

```php
echo 1 <=> 2;  // -1
echo 1 <=> 1;  //  0
echo 2 <=> 1;  //  1

// Useful for sorting
usort($users, function ($a, $b) {
    return $a->age <=> $b->age;
});
```

### Anonimne klase

Možete kreirati klasu bez naziva:

```php
$logger = new class {
    public function log(string $message): void {
        echo $message;
    }
};

$logger->log('Hello!');
```

### Grupisane use deklaracije

Uvezite više klasa iz istog namespace-a u jednoj liniji:

```php
// PHP 5
use App\Models\User;
use App\Models\Post;
use App\Models\Comment;

// PHP 7
use App\Models\{User, Post, Comment};
```

### Promene u rukovanju greškama

PHP 7 je promenio način rada grešaka. Fatalne greške sada bacaju `Error` izuzetke koje možete uhvatiti:

```php
// PHP 5: calling undefined method = fatal error, cannot catch it

// PHP 7: you can catch it
try {
    $obj = new stdClass();
    $obj->undefinedMethod();
} catch (Error $e) {
    echo "Caught error: " . $e->getMessage();
}
```

I `Error` i `Exception` implementiraju interfejs `Throwable`:

```text
Throwable
├── Error
│   ├── TypeError
│   ├── ParseError
│   └── ArithmeticError
└── Exception
    ├── RuntimeException
    └── ...
```

### Uklonjene mogućnosti iz PHP 5

- MySQL ekstenzija (`mysql_*` funkcije) — uklonjena, koristite `mysqli` ili PDO
- Konstruktori starog stila (metoda sa istim imenom kao klasa) — zastarela
- `ereg_*` funkcije — uklonjene, koristite `preg_*`

### Realni scenario

Imate online prodavnicu koja radi na PHP 5.6. Vreme učitavanja stranice je 400ms. Nakon nadogradnje na PHP 7, ista stranica se učitava za otprilike 200ms — bez promene koda. Zatim dodajete scalar type hint-ove u vaše service klase:

```php
declare(strict_types=1);

class PriceCalculator
{
    public function calculateDiscount(float $price, int $percentage): float
    {
        if ($percentage < 0 || $percentage > 100) {
            throw new InvalidArgumentException('Percentage must be 0-100');
        }
        return $price - ($price * $percentage / 100);
    }
}

// If someone passes a string by mistake, PHP 7 strict mode catches it immediately
$calc = new PriceCalculator();
$calc->calculateDiscount("100", 10); // TypeError in strict mode!
```

### Zaključak

PHP 7 je bio najveći PHP upgrade godinama. Udvostručio je performanse, dodao deklaracije skalarnih tipova, povratne tipove, null coalescing operator `??`, spaceship operator `<=>`, anonimne klase i promenio rukovanje greškama na korišćenje izuzetaka umesto fatalnih grešaka. Ove promene su PHP učinile mnogo pouzdanijim i bržim.
