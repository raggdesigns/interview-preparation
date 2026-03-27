# Konkurentnost vs Paralelizam

Konkurentnost i paralelizam se oba bave više zadataka istovremeno, ali rešavaju različite probleme. Razumevanje razlike — i kako PHP rukuje svakim — učestalo je pitanje na intervjuima.

> **Scenario koji se koristi kroz ceo dokument:** Veb aplikacija koja mora da preuzme podatke iz tri eksterna API-ja i da smanji veličinu postavljenih slika.

## Preduslovi

- [Kako internet funkcioniše](how_internet_works.sr.md) — životni ciklus mrežnog zahteva
- [PHP-FPM](../highload/php_fpm.md) — kako PHP rukuje konkurentnim zahtevima

## Osnovna ideja

```text
Concurrency (one cook, many dishes):
  ┌──────────────────────────────────────────────────┐
  │  Task A ████░░░░████░░░░████                     │
  │  Task B     ████░░░░████░░░░████                 │
  │  Task C         ████░░░░████░░░░████             │
  │         ─────────────────────────────→ time       │
  │  One thread switches between tasks               │
  │  (e.g., while Task A waits for I/O, work on B)   │
  └──────────────────────────────────────────────────┘

Parallelism (three cooks, three dishes):
  ┌──────────────────────────────────────────────────┐
  │  Core 1: Task A ████████████████████             │
  │  Core 2: Task B ████████████████████             │
  │  Core 3: Task C ████████████████████             │
  │          ─────────────────────────────→ time      │
  │  Multiple threads/processes run simultaneously   │
  └──────────────────────────────────────────────────┘
```

| Aspekt | Konkurentnost | Paralelizam |
|--------|---------------|-------------|
| Definicija | Bavljenje više zadataka odjednom | Izvršavanje više zadataka odjednom |
| Fokus | Struktura (kako organizuješ posao) | Izvršavanje (kako pokrećeš posao) |
| Zahteva | Dovoljna je jedna CPU jezgra | Potrebno je više CPU jezgara |
| Najbolje za | I/O-bound zadatke (mreža, disk, baza) | CPU-bound zadatke (matematika, obrada slika) |
| PHP alati | Fibers, ReactPHP, AMPHP | pcntl_fork, parallel extension |

## Konkurentnost u PHP-u

### PHP Fibers (PHP 8.1+)

Fibers dozvoljavaju funkciji da **suspenduje** izvršavanje i vrati kontrolu pozivaocu. Ovo omogućava kooperativni multitasking unutar jedne niti.

```php
<?php

function fetchFromApi(string $url): Fiber
{
    return new Fiber(function () use ($url): string {
        echo "Starting request to {$url}\n";

        // Simulate async I/O — in real code, this is where
        // an event loop would handle the actual HTTP request
        Fiber::suspend('waiting');

        echo "Completed request to {$url}\n";
        return "Response from {$url}";
    });
}

// Create fibers for three API calls
$fibers = [
    fetchFromApi('https://api.shop.com/products'),
    fetchFromApi('https://api.shop.com/categories'),
    fetchFromApi('https://api.shop.com/inventory'),
];

// Start all fibers (each runs until it suspends)
foreach ($fibers as $fiber) {
    $fiber->start();
}

// Resume all fibers (simulating I/O completion)
$results = [];
foreach ($fibers as $fiber) {
    $results[] = $fiber->resume();
}

// All three requests completed concurrently on ONE thread
```

### ReactPHP Event Loop (konkurentnost u produkciji)

ReactPHP pruža pravi event loop za neblokirajući I/O — ovo bi se koristilo u produkciji za konkurentne HTTP zahteve.

```php
<?php

use React\EventLoop\Loop;
use React\Http\Browser;

$browser = new Browser();

// Fire all three requests concurrently
$promises = [
    $browser->get('https://api.shop.com/products'),
    $browser->get('https://api.shop.com/categories'),
    $browser->get('https://api.shop.com/inventory'),
];

// Wait for all to complete
React\Promise\all($promises)->then(function (array $responses): void {
    foreach ($responses as $response) {
        echo $response->getBody() . "\n";
    }
    echo "All 3 requests completed concurrently on a single thread\n";
});
```

**Ključna napomena:** Koristi se samo jedna nit. Dok čekamo mrežni odgovor od API-ja #1, event loop pokreće zahtev #2, pa #3. Kada stignu odgovori, izvršavaju se callback funkcije.

## Paralelizam u PHP-u

### pcntl_fork (paralelizam na nivou procesa)

Za CPU-bound posao, potrebno je više procesa koji rade na zasebnim CPU jezgrama.

```php
<?php

// Resize 4 images in parallel using 4 child processes
$images = ['photo1.jpg', 'photo2.jpg', 'photo3.jpg', 'photo4.jpg'];
$pids = [];

foreach ($images as $image) {
    $pid = pcntl_fork();

    if ($pid === -1) {
        throw new RuntimeException('Failed to fork');
    }

    if ($pid === 0) {
        // Child process — runs on a separate CPU core
        $start = microtime(true);
        resizeImage($image, 800, 600); // CPU-intensive work
        $elapsed = round(microtime(true) - $start, 2);
        echo "[PID " . getmypid() . "] Resized {$image} in {$elapsed}s\n";
        exit(0); // Child must exit
    }

    $pids[] = $pid; // Parent tracks child PIDs
}

// Parent waits for all children to finish
foreach ($pids as $pid) {
    pcntl_waitpid($pid, $status);
}

echo "All 4 images resized in parallel\n";

function resizeImage(string $path, int $width, int $height): void
{
    $image = imagecreatefromjpeg($path);
    $resized = imagescale($image, $width, $height);
    imagejpeg($resized, "resized_{$path}");
    imagedestroy($image);
    imagedestroy($resized);
}
```

**Izlaz na mašini sa 4 jezgra:**

```text
[PID 1234] Resized photo1.jpg in 1.2s   (Core 1)
[PID 1235] Resized photo2.jpg in 1.1s   (Core 2)
[PID 1236] Resized photo3.jpg in 1.3s   (Core 3)
[PID 1237] Resized photo4.jpg in 1.2s   (Core 4)
All 4 images resized in parallel

Total: ~1.3s (vs ~4.8s sequentially)
```

## Poređenje: isti problem, različiti pristupi

```text
Task: Fetch 3 API responses + resize 4 images

Sequential (no concurrency, no parallelism):
  API1 ──── API2 ──── API3 ──── IMG1 ──── IMG2 ──── IMG3 ──── IMG4
  Total: ~7 seconds

Concurrent only (single thread, event loop):
  API1 ─┐
  API2 ─┼── wait ── all done ── IMG1 ── IMG2 ── IMG3 ── IMG4
  API3 ─┘
  Total: ~5 seconds (APIs overlap, images still sequential)

Parallel only (multiple processes):
  Process 1: API1 ── IMG1
  Process 2: API2 ── IMG2
  Process 3: API3 ── IMG3
  Process 4:         IMG4
  Total: ~2 seconds (but wastes CPU during I/O waits)

Both (event loop + forked workers):
  Main process (concurrent I/O):
    API1 ─┐
    API2 ─┼── all done in ~1s
    API3 ─┘
  Forked workers (parallel CPU):
    Core 1: IMG1 ─┐
    Core 2: IMG2 ─┼── all done in ~1.3s
    Core 3: IMG3 ─┤
    Core 4: IMG4 ─┘
  Total: ~2.3s (optimal)
```

## Kako PHP-FPM obezbeđuje konkurentnost

PHP je jednonitreni, ali **PHP-FPM** postiže konkurentnost na nivou procesa:

```text
Nginx receives 100 simultaneous requests
  │
  ▼
PHP-FPM pool (pm.max_children = 50)
  │
  ├── Worker 1:  handles request #1  (each worker is a separate process)
  ├── Worker 2:  handles request #2
  ├── Worker 3:  handles request #3
  │   ...
  ├── Worker 50: handles request #50
  │
  └── Requests 51-100 wait in queue until a worker is free

Each worker runs one request at a time (no shared state = no race conditions).
This is concurrency through multiple processes, not threads.
```

Zbog toga se PHP često naziva "shared-nothing arhitekturom" — svaki zahtev je izolovan u sopstvenom procesu.

## Česta pitanja na intervjuima

### P: Objasni razliku između konkurentnosti i paralelizma

**O:** **Konkurentnost** se odnosi na strukturu — organizovanje programa za rukovanje više zadataka ispreplitanjem njihovog izvršavanja. Jedna jezgra može postići konkurentnost prelaženjem između zadataka (npr. dok se čeka odgovor baze, pokreće se drugi HTTP zahtev). **Paralelizam** se odnosi na izvršavanje — bukvalno pokretanje više zadataka istovremeno na više CPU jezgara. Može se imati konkurentnost bez paralelizma (jedna jezgra prebacuje između zadataka) i paralelizam bez konkurentnosti (više jezgara, svaka sa jednim nezavisnim zadatkom).

### P: Kada bi koristio konkurentnost, a kada paralelizam?

**O:** Koristi **konkurentnost** za I/O-bound zadatke gde je usko grlo čekanje na eksterne sisteme (mrežni zahtevi, upiti baze, čitanje fajlova). Koristi **paralelizam** za CPU-bound zadatke gde je usko grlo računanje (obrada slika, transformacija podataka, enkripcija). U praksi, visoko-performantne aplikacije koriste oboje: event loop za konkurentni I/O i worker procese za paralelni CPU rad.

### P: Kako PHP postiže konkurentnost ako je jednonitreni?

**O:** Na **nivou jezika**, PHP 8.1 Fibers i biblioteke poput ReactPHP pružaju kooperativnu konkurentnost unutar jednog procesa koristeći event loopove. Na **nivou infrastrukture**, PHP-FPM pokreće pool worker procesa — svaki obrađuje jedan zahtev, ali mnogi radnici rade istovremeno, postižući konkurentnost kroz više procesa umesto niti. Ovaj "shared-nothing" model izbegava race conditions, ali znači da radnici ne mogu da dele memorijsko stanje.

### P: Šta su race conditions i kako ih PHP izbegava?

**O:** Race condition nastaje kada dve niti istovremeno pristupaju deljenom promenljivom stanju, uzrokujući nepredvidljive rezultate. PHP uglavnom izbegava ovo jer je svaki FPM worker zasebni proces sa sopstvenom memorijom — nema ničeg deljenog za konkurenciju. Međutim, race conditions se i dalje mogu pojaviti na **nivou baze podataka** (dva zahteva ažuriraju isti red) ili sa deljenim resursima kao što su fajlovi i keš. Ovo se rešava zaključavanjem, transakcijama i atomičnim operacijama, ne PHP jezičkim funkcionalnostima.

## Zaključak

Konkurentnost (struktura) i paralelizam (izvršavanje) rešavaju različita uska grla. PHP rukuje I/O konkurentnošću kroz Fibers i ReactPHP, CPU paralelizmom kroz pcntl_fork i parallel ekstenziju, i konkurentnošću na nivou zahteva kroz PHP-FPM pool procesa. "Shared-nothing" model razmenjuje memorijsku efikasnost za jednostavnost — bez niti znači bez race conditions unutar jednog zahteva.

## Vidi takođe

- [PHP-FPM](../highload/php_fpm.md) — upravljanje pool procesima
- [Async JavaScript](../javascript/async_javascript.md) — event loop u drugom jeziku
- [Optimizacija sporih GET endpointa](../highload/optimizing_slow_get_endpoint.md) — praktična optimizacija performansi
