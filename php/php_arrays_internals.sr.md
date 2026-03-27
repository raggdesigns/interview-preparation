PHP nizovi izgledaju jednostavno na površini, ali interno su implementirani kao **hash tabela** (poznata i kao hash mapa). Ovo se veoma razlikuje od nizova u jezicima kao što su C ili Java, koji su samo kontinualni blokovi memorije indeksirani brojevima.

### Šta je hash tabela

Hash tabela je struktura podataka koja mapira **ključeve** na **vrednosti** koristeći **hash funkciju**. Hash funkcija konvertuje ključ (kao što je string `"name"` ili integer `5`) u broj koji govori PHP-u gde da skladišti vrednost u memoriji.

```php
$user = ['name' => 'Dragan', 'role' => 'developer'];
// Internally:
// hash("name") → position 3 in memory → stores "Dragan"
// hash("role") → position 7 in memory → stores "developer"
```

Ovo daje PHP nizovima **prosečno O(1) vreme** za čitanje, pisanje i proveru da li ključ postoji — ista brzina bez obzira da li niz ima 10 ili 10 miliona elemenata.

### Interna struktura PHP niza

Od PHP 7, nizovi koriste strukturu nazvanu `HashTable` u C. Svaki niz se sastoji od:

1. **Hash tabela** — niz "bucket-a" gde se podaci skladište
2. **Bucket** — sadrži ključ, vrednost i hash ključa
3. **Packed vs hash mod** — PHP optimizuje za nizove sa integer indeksima

```
PHP Array (HashTable)
├── nTableSize: 8         (allocated bucket slots, always power of 2)
├── nNumOfElements: 3     (actual elements stored)
├── nNumUsed: 3           (slots used including deleted ones)
├── arData: [             (array of Buckets)
│   Bucket { key: "name", val: "Dragan", h: 0x7a34f... }
│   Bucket { key: "role", val: "developer", h: 0x3c91a... }
│   Bucket { key: "age",  val: 30, h: 0x8b72c... }
│   (5 empty slots)
│ ]
```

### Packed nizovi vs hash nizovi

PHP optimizuje za uobičajeni slučaj sekvencijalnih integer ključeva (0, 1, 2, ...):

```php
// Packed array — optimized, no hash computation needed
$colors = ['red', 'green', 'blue'];
// Keys are 0, 1, 2 — PHP stores them in order and accesses by offset directly

// Hash array — uses hash function for key lookup
$user = ['name' => 'Dragan', 'email' => 'dragan@example.com'];
// String keys require hash computation
```

Packed nizovi koriste manje memorije i brži su jer PHP može preskočiti korak hešovanja i direktno pristupiti elementima po njihovom integer offsetu.

**Kada packed niz postaje hash niz?**

```php
$arr = [0 => 'a', 1 => 'b', 2 => 'c'];  // Packed — sequential integers from 0

$arr = [0 => 'a', 5 => 'b', 1 => 'c'];   // Hash — non-sequential keys
$arr = ['x' => 'a'];                       // Hash — string key
unset($arr[1]);                             // Hash — gap in sequence after unset
```

### Hash kolizije

Dva različita ključa mogu proizvesti istu hash vrednost. Ovo se naziva **kolizija**. PHP rukuje kolizijama koristeći **povezane liste** — kada dva ključa heširaju na istu poziciju bucket-a, ulančavaju se zajedno.

```
Bucket slot 3: "name" → "Dragan" → (next) "city" → "Belgrade"
                        Both "name" and "city" hashed to slot 3
```

U praksi, kolizije su retke. PHP menja veličinu hash tabele kada se previše napuni (faktor opterećenja), što drži kolizije niskima.

### Korišćenje memorije

PHP nizovi koriste znatno više memorije od jednostavnih C nizova jer svaki element skladišti:
- Vrednost (zval — 16 bajtova)
- Ključ (string ključ + hash, ili integer ključ)
- Pokazivače za redosled i lance kolizija
- Overhead bucket-a

```php
// This array of 1 million integers uses ~36 MB in PHP
$arr = range(1, 1_000_000);
echo memory_get_usage(true);  // ~36 MB

// In C, the same data would use ~4 MB (1M × 4 bytes per int)
```

**Savet:** Za velike skupove podataka sa samo integer vrednostima, koristite `SplFixedArray` — koristi pravi C-stil niz i štedi 2-3 puta memorije:

```php
$fixed = new SplFixedArray(1_000_000);
for ($i = 0; $i < 1_000_000; $i++) {
    $fixed[$i] = $i;
}
echo memory_get_usage(true);  // ~16 MB (vs ~36 MB for regular array)
```

### Vremenska složenost

| Operacija | Prosek | Najgori slučaj |
|-----------|--------|----------------|
| Čitanje po ključu `$arr['name']` | O(1) | O(n) — sve kolizije ključeva (ekstremno retko) |
| Pisanje `$arr['name'] = 'x'` | O(1) | O(n) — promena veličine + kopiranje |
| Provera ključa `isset($arr['name'])` | O(1) | O(n) |
| Brisanje `unset($arr['name'])` | O(1) | O(n) |
| Pretraga vrednosti `in_array($val, $arr)` | O(n) | O(n) — mora proveriti svaki element |
| Brojanje `count($arr)` | O(1) | O(1) — skladišteno u nNumOfElements |

**Važno:** `in_array()` je O(n) jer pretražuje vrednosti, a ne ključeve. Ako trebate brze pretrage vrednosti, okrenite niz:

```php
// Slow — O(n) per lookup
$allowed = ['admin', 'editor', 'moderator'];
if (in_array($role, $allowed)) { ... }  // Scans all 3 elements

// Fast — O(1) per lookup
$allowed = ['admin' => true, 'editor' => true, 'moderator' => true];
if (isset($allowed[$role])) { ... }  // Direct hash lookup
```

### PHP niz je uređen

Za razliku od hash mapa u mnogim jezicima (npr. Java-in `HashMap`), PHP nizovi čuvaju **redosled umetanja**. Ovo je zato što svaki bucket skladišti pokazivač na sledeći element u redosledu umetanja.

```php
$arr = ['c' => 3, 'a' => 1, 'b' => 2];
foreach ($arr as $key => $value) {
    echo "$key: $value\n";
}
// Output: c: 3, a: 1, b: 2  ← insertion order, NOT sorted by key
```

Zato PHP može koristiti isti tip niza kao listu, rečnik, stek, red i uređenu mapu.

### PHP niz kao više struktura podataka

```php
// As a list (indexed)
$list = ['apple', 'banana', 'cherry'];

// As a dictionary (key-value)
$config = ['host' => 'localhost', 'port' => 3306];

// As a stack (LIFO)
$stack = [];
array_push($stack, 'task1');
array_push($stack, 'task2');
$last = array_pop($stack);  // 'task2'

// As a queue (FIFO)
$queue = [];
$queue[] = 'job1';
$queue[] = 'job2';
$first = array_shift($queue);  // 'job1' — but O(n) because it reindexes!

// For real queue performance, use SplQueue
$queue = new SplQueue();
$queue->enqueue('job1');
$queue->enqueue('job2');
$first = $queue->dequeue();  // 'job1' — O(1)
```

### Realni scenario

Gradite sloj keširanja koji skladišti podatke o korisnicima u memoriji tokom zahteva:

```php
// Bad approach — searching by value is O(n) per lookup
$activeUserIds = [101, 205, 312, 450, 891, /* ... 10,000 more */];

foreach ($orders as $order) {
    // in_array scans up to 10,000 elements for EACH order
    if (in_array($order->getUserId(), $activeUserIds)) {
        $this->processOrder($order);
    }
}

// Good approach — flip to hash lookup, O(1) per check
$activeUsers = array_flip($activeUserIds);
// Result: [101 => 0, 205 => 1, 312 => 2, ...]

foreach ($orders as $order) {
    if (isset($activeUsers[$order->getUserId()])) {  // O(1)
        $this->processOrder($order);
    }
}
```

Sa 10.000 aktivnih korisnika i 50.000 narudžbina:
- `in_array`: do 10.000 × 50.000 = 500 miliona poređenja
- `isset`: 50.000 hash pretraga = praktično trenutno

### Zaključak

PHP nizovi su implementirani kao hash tabele (uređene hash mape). Podržavaju prosečno O(1) vreme čitanja/pisanja po ključu, čuvaju redosled umetanja i mogu funkcionisati kao liste, rečnici, stekovi i redovi. Koriste više memorije od C-stil nizova jer svaki element nosi metapodatke. Koristite `isset()` umesto `in_array()` za brze pretrage, `SplFixedArray` za velike skupove podataka sa integer indeksima i `SplQueue` za prave operacije reda. Razumevanje interne strukture pomaže vam da pišete performantan PHP kod i izbegnete skrivene O(n) operacije.

> Vidi takođe: [Popularne SPL funkcije](popular_spl_functions.sr.md), [Tipovi podataka u PHP-u](data_types_in_php.sr.md)
