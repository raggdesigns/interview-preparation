Strukture podataka su načini organizovanja podataka u memoriji tako da operacije poput čitanja, pretraživanja, umetanja i brisanja budu efikasne. Svaki backend programer treba da razume najčešće korišćene — ne zato što ih gradiš od nule, već zato što ih koristiš svakodnevno a da to ni ne primećuješ.

### Hash tabela (Hash Map)

Hash tabela čuva **parove ključ-vrednost**. Koristi **hash funkciju** da pretvori ključ u indeks niza, dajući O(1) prosečno vreme pristupa.

```
Key "name" → hash("name") → index 5 → Value "Dragan"
Key "role" → hash("role") → index 2 → Value "developer"
```

**Gde je koristiš svakodnevno:**
- PHP nizovi (asocijativni) — `['name' => 'Dragan']`
- Redis — cela baza podataka je hash mapa
- HTTP zaglavlja — `Content-Type: application/json`
- `.env` fajlovi — `DATABASE_URL=mysql://...`
- JSON objekti — `{"name": "Dragan"}`

```php
// PHP array IS a hash table
$config = [
    'db_host' => 'localhost',
    'db_port' => 3306,
    'db_name' => 'myapp',
];

// O(1) — direct hash lookup
$host = $config['db_host'];

// O(1) — check if key exists
if (isset($config['db_port'])) { ... }
```

| Operacija | Prosečno | Najgori slučaj |
|-----------|---------|----------------|
| Čitanje po ključu | O(1) | O(n) |
| Umetanje | O(1) | O(n) |
| Brisanje | O(1) | O(n) |
| Pretraga po vrednosti | O(n) | O(n) |

**Hash kolizija** — kada dva ključa proizvode istu hash vrednost. Rešava se ulančavanjem (linked list na svakom slotu) ili otvorenim adresiranjem. Dobre hash funkcije minimizuju kolizije.

### Linked list (ulančana lista)

Linked list je niz **čvorova** gde svaki čvor sadrži vrednost i **pokazivač** na sledeći čvor. Za razliku od nizova, elementi nisu smešteni u kontinuiranoj memoriji.

```
[value: "A" | next: →] → [value: "B" | next: →] → [value: "C" | next: null]
     Node 1                    Node 2                    Node 3
```

**Tipovi:**
- **Jednostruko ulančana** — svaki čvor pokazuje na sledeći
- **Dvostruko ulančana** — svaki čvor pokazuje na sledeći I prethodni

| Operacija | Niz | Linked list |
|-----------|-----|-------------|
| Pristup po indeksu | O(1) | O(n) — mora se preći od početka |
| Umetanje na početak | O(n) — pomeri sve | O(1) — promeni pokazivač |
| Umetanje na kraj | O(1) amortizirano | O(1) ako postoji pokazivač na rep |
| Brisanje iz sredine | O(n) — pomeri sve | O(1) ako je čvor poznat |
| Pretraga | O(n) | O(n) |

**Gde se susrećeš sa njom:**
- PHP-ova `SplDoublyLinkedList` — za redove i stekove
- Git istorija komitova — svaki komit pokazuje na svog roditelja
- Blockchain — svaki blok je vezan za prethodni
- Undo/Redo u tekst editorima — dvostruko ulančana lista stanja

```php
// PHP SplDoublyLinkedList
$list = new SplDoublyLinkedList();
$list->push('first');
$list->push('second');
$list->push('third');

$list->rewind();
while ($list->valid()) {
    echo $list->current() . "\n";
    $list->next();
}
// Output: first, second, third
```

### Stablo (Tree)

Stablo je hijerarhijska struktura gde svaki čvor ima vrednost i nula ili više **dečjih čvorova**. Čvor na vrhu se zove **koren**.

```
            [CEO]                    ← Root
           /     \
      [CTO]       [CFO]             ← Children of root
      /   \           \
  [Dev1] [Dev2]    [Accountant]     ← Leaves (no children)
```

**Uobičajeni tipovi:**
- **Binarno stablo** — svaki čvor ima najviše 2 dece
- **Binary Search Tree (BST)** — levo dete < roditelj < desno dete → O(log n) pretraga
- **B-stablo** — koristi MySQL indeksi (mnogo dece po čvoru, optimizovano za disk)
- **DOM stablo** — struktura HTML/XML dokumenta

**Gde se susrećeš sa stablima:**
- **MySQL indeksi** — B-stablo/B+stablo za brze pretrage
- **XML/HTML parsiranje** — DOM stablo
- **Fajl sistem** — direktorijumi su stablo
- **JSON parsiranje** — ugnežđeni objekti formiraju stablo
- **Symfony rutiranje** — poklapanje ruta koristi stablo

```php
// XML/HTML is a tree structure
$xml = '<catalog>
    <book>
        <title>Clean Code</title>
        <author>Robert Martin</author>
    </book>
    <book>
        <title>DDD</title>
        <author>Eric Evans</author>
    </book>
</catalog>';

$doc = new SimpleXMLElement($xml);

// Traverse the tree
foreach ($doc->book as $book) {
    echo $book->title . " by " . $book->author . "\n";
}
```

**B-stablo u MySQL-u:**

```
                    [50]
                   /    \
            [20, 35]    [70, 85]
           /   |   \    /   |   \
        [10] [25] [40] [60] [75] [90]
```

Kada pokreneš `SELECT * FROM users WHERE id = 25`, MySQL ne skenira sve redove. Prolazi kroz B-stablo: 50 → idi levo → 20, 35 → između njih → pronašao 25. Ovo je O(log n) umesto O(n).

### Stek (Stack) — LIFO — Last In, First Out

Stek radi kao gomila tanjira — možeš dodavati ili uklanjati samo sa **vrha**. Poslednji dodati element je prvi koji se uklanja.

```
    Push "C" →  [C]  ← Top (last in, first out)
                [B]
                [A]  ← Bottom (first in, last out)

    Pop → removes "C"
```

| Operacija | Vreme |
|-----------|-------|
| Push (dodaj na vrh) | O(1) |
| Pop (ukloni sa vrha) | O(1) |
| Peek (pogledaj vrh) | O(1) |

**Gde se susrećeš sa stekom:**
- **Call stack funkcija** — kada funkcija A poziva funkciju B, A se gura na stek. Kada se B vrati, A se skida i nastavlja
- **Undo operacije** — svaka akcija se gura na stek, undo skida poslednju
- **Parsiranje izraza** — kompajleri koriste stekove za evaluaciju `(3 + 4) * (2 - 1)`
- **Dugme za povratak u pregledaču** — istorija je stek

```php
// Stack in PHP using SplStack
$stack = new SplStack();
$stack->push('action1: create user');
$stack->push('action2: update email');
$stack->push('action3: change role');

// Undo last action
$lastAction = $stack->pop();  // "action3: change role"
echo "Undoing: $lastAction\n";

// PHP function call stack — you see it in exceptions
// Exception trace:
//   #0 App\Service\UserService->register()
//   #1 App\Controller\UserController->create()
//   #2 Symfony\Component\HttpKernel->handle()
```

### Red (Queue) — FIFO — First In, First Out

Red funkcioniše kao red u prodavnici — prva osoba u redu se prva uslužuje. Elementi se dodaju na **kraj** i uklanjaju sa **prednje strane**.

```
    Enqueue "C" →  [A] [B] [C]
                    ↑           ↑
                  Front        Back

    Dequeue → removes "A" (first in, first out)
```

| Operacija | Vreme |
|-----------|-------|
| Enqueue (dodaj na kraj) | O(1) |
| Dequeue (ukloni sa prednje strane) | O(1) |
| Peek (pogledaj prednju stranu) | O(1) |

**Gde se susrećeš sa redovima — kritično za backend programere:**
- **RabbitMQ** — message broker koji obrađuje poslove redom
- **Redis liste** — `LPUSH` + `RPOP` kreira red
- **Symfony Messenger** — šalje poruke u red za asinhronnu obradu
- **Obrada pozadinskih poslova** — slanje emailova, generisanje PDF-a, promena veličine slika

```php
// PHP SplQueue
$queue = new SplQueue();
$queue->enqueue('job1: send welcome email');
$queue->enqueue('job2: generate invoice');
$queue->enqueue('job3: resize avatar');

// Process jobs in order (FIFO)
while (!$queue->isEmpty()) {
    $job = $queue->dequeue();
    echo "Processing: $job\n";
}
// Output: job1, job2, job3 — in the order they were added
```

### Red u realnim backend sistemima

Redovi su fundamentalni za backend sisteme. Kada tvoja veb aplikacija treba da uradi nešto sporo (pošalje email, generiše PDF, pozove eksterni API), stavljaš poruku u red i **worker** je obrađuje later.

```php
// Symfony Messenger — fire and forget
class OrderController extends AbstractController
{
    #[Route('/orders', methods: ['POST'])]
    public function create(Request $request, MessageBusInterface $bus): JsonResponse
    {
        $order = $this->orderService->create($request->toArray());

        // Put message on queue — returns immediately
        $bus->dispatch(new SendOrderConfirmationEmail($order->getId()));
        $bus->dispatch(new GenerateInvoicePdf($order->getId()));
        $bus->dispatch(new NotifyWarehouse($order->getId()));

        return $this->json(['orderId' => $order->getId()], 201);
        // User gets response in 50ms instead of waiting for email+PDF+API
    }
}
```

```bash
# Redis queue — RabbitMQ alternative
# Producer (your PHP app):
LPUSH order_queue '{"orderId": 123, "action": "send_email"}'
LPUSH order_queue '{"orderId": 124, "action": "generate_pdf"}'

# Consumer (worker process):
RPOP order_queue  # Gets the first message added (FIFO)
```

### Tabela poređenja

| Struktura | Pristup | Pretraga | Umetanje | Brisanje | Primena |
|-----------|---------|----------|----------|----------|---------|
| Hash tabela | O(1) po ključu | O(n) po vrednosti | O(1) | O(1) | Konfiguracija, keš, tabele pretraživanja |
| Linked list | O(n) | O(n) | O(1) na krajevima | O(1) ako je pronađen | Radno opterećenje sa intenzivnim umetanjem |
| Binary Search Tree | O(log n) | O(log n) | O(log n) | O(log n) | Indeksi baza, sortirani podaci |
| Stek | O(1) samo vrh | O(n) | O(1) | O(1) | Undo, call stack, parsiranje |
| Red | O(1) samo prednja strana | O(n) | O(1) | O(1) | Obrada poslova, message brokeri |

### Zaključak

Kao backend programer, ove strukture podataka koristiš svakodnevno — PHP nizovi su hash tabele, MySQL indeksi su B-stabla, RabbitMQ i Symfony Messenger koriste redove, a function call stack je stek. Razumevanje njihove vremenske kompleksnosti pomaže ti da odabereš pravi alat: koristi hash mape za brze pretrage po ključu, redove za asinhronnu obradu poslova, i budi svestan da je `in_array()` O(n) dok je `isset()` O(1). Na intervjuima se fokusiraj na to kada koristiti svaku strukturu i njihove primene u realnom svetu, umesto na memorisanje detalja implementacije.

> Vidi takođe: [PHP arrays internals](../php/php_arrays_internals.sr.md), [Redis basics](../caching/redis_basics.sr.md), [Kako internet funkcioniše](how_internet_works.sr.md)
