PHP 8.5 je objavljen u novembru 2025. godine. Nastavio je poboljšanje jezika sa pipe operatorom, boljim enumovima i novim utility mogućnostima.

### Pipe operator (`|>`)

Pipe operator prosleđuje rezultat levog izraza kao prvi argument funkciji na desnoj strani:

```php
// Before PHP 8.5 — nested calls are hard to read
$result = array_sum(array_map(fn($n) => $n * 2, array_filter($numbers, fn($n) => $n > 0)));

// PHP 8.5 — reads left to right, like a pipeline
$result = $numbers
    |> array_filter(fn($n) => $n > 0)
    |> array_map(fn($n) => $n * 2)
    |> array_sum();
```

Svaki korak uzima izlaz prethodnog koraka i prosleđuje ga kao prvi argument sledećoj funkciji. Ovo čini lance transformacije podataka mnogo lakšim za čitanje.

```php
$output = ' Hello, World! '
    |> trim()
    |> strtolower()
    |> str_replace(' ', '-')
    |> htmlspecialchars();
// "hello,-world!"
```

### `Locale`-nezavisna konverzija float u string

PHP 8.5 osigurava da kastovanje float u string uvek koristi tačku kao decimalni separator, bez obzira na sistemski locale:

```php
setlocale(LC_ALL, 'de_DE');

// Before PHP 8.5 — locale could affect output
// (string)1.5 might produce "1,5" in some contexts

// PHP 8.5 — always uses dot
echo (string)1.5; // "1.5" — always, regardless of locale
```

### `array_first()` i `array_last()`

Jednostavne funkcije za dobijanje prvog ili poslednjeg elementa niza bez menjanja niza:

```php
$items = ['apple', 'banana', 'cherry'];

$first = array_first($items); // "apple"
$last = array_last($items);   // "cherry"

// Works with associative arrays too
$config = ['host' => 'localhost', 'port' => 3306, 'db' => 'myapp'];
$first = array_first($config); // "localhost"
$last = array_last($config);   // "myapp"

// Returns null for empty arrays
$empty = array_first([]); // null
```

Pre PHP 8.5, dobijanje prvog elementa bez menjanja niza zahtevalo je `reset()` (koji pomera interni pokazivač) ili `array_key_first()` + pristup po indeksu.

### Poboljšanja CLI-a

PHP 8.5 je poboljšao ugrađeni CLI server i SAPI sa boljim prijavljivanjem grešaka i podrškom za obojeni izlaz.

### Atribut `#[\NoDiscard]`

Upozorava kada se povratna vrednost funkcije ignoriše:

```php
#[\NoDiscard("The filtered array is not used")]
function filterActive(array $items): array
{
    return array_filter($items, fn($item) => $item['active']);
}

filterActive($users); // Warning! Return value is discarded
$active = filterActive($users); // OK — return value is used
```

Ovo je korisno za čiste funkcije gde je ignorisanje rezultata gotovo sigurno greška.

### Closure kreiranje iz callable-ova u konstantnim izrazima

Kreiranje closure sa `(...)` je sada dozvoljeno na više mesta, uključujući podrazumevane vrednosti konstanti klase i argumente atributa.

### Poboljšanja `Grapheme` klastera

Bolja podrška za Unicode grapheme klastere u string funkcijama, važna za ispravno rukovanje emojijima i složenim pismima:

```php
// A family emoji is one "grapheme cluster" but multiple bytes/code points
$emoji = '👨‍👩‍👧‍👦';
grapheme_strlen($emoji); // 1 — correctly counts as one character
```

### Realni scenario

Gradite pipeline za obradu podataka za izveštaj o e-commerce prodaji. Pre PHP 8.5:

```php
class SalesReport
{
    public function generate(array $orders): array
    {
        // Nested calls — read from inside out
        $result = array_sum(
            array_column(
                array_filter(
                    array_map(
                        fn($order) => [
                            'total' => $order['price'] * $order['quantity'],
                            'status' => $order['status'],
                        ],
                        $orders
                    ),
                    fn($item) => $item['status'] === 'completed'
                ),
                'total'
            )
        );

        return ['total_revenue' => $result];
    }
}
```

Nakon PHP 8.5:

```php
class SalesReport
{
    #[\NoDiscard]
    public function generate(array $orders): array
    {
        $totalRevenue = $orders
            |> array_map(fn($order) => [
                'total' => $order['price'] * $order['quantity'],
                'status' => $order['status'],
            ])
            |> array_filter(fn($item) => $item['status'] === 'completed')
            |> array_column('total')
            |> array_sum();

        return ['total_revenue' => $totalRevenue];
    }
}

// Getting first and last order is also simpler
$firstOrder = array_first($orders);
$lastOrder = array_last($orders);

// And the #[NoDiscard] attribute prevents this mistake:
$report = new SalesReport();
$report->generate($orders); // Warning! Return value not used
$data = $report->generate($orders); // OK
```

Pipe operator čini tok podataka jasnim — svaki korak se uliva u sledeći, čitajući odozgo prema dole.

### Zaključak

PHP 8.5 je uveo pipe operator (`|>`) za čitljivo lančanje funkcija, utility funkcije `array_first()` i `array_last()`, atribut `#[\NoDiscard]` za hvatanje nekorišćenih povratnih vrednosti, locale-nezavisno kastovanje float-a u string i poboljšanu Unicode grapheme podršku. Pipe operator je najimpresivnija mogućnost koja čini pipeline-ove transformacije podataka mnogo čistijim.
