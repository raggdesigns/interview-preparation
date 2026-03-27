SPL (Standard PHP Library) je kolekcija ugrađenih klasa, interfejsa i funkcija koje rešavaju uobičajene programerske probleme. Uvek su dostupne u PHP-u — nisu potrebne nikakve ekstenzije ili paketi.

### Strukture podataka

#### SplStack — Last In, First Out (LIFO)

Stek funkcioniše kao gomila tanjira. Dodajete na vrh i uzimate sa vrha.

```php
$stack = new SplStack();
$stack->push('first');
$stack->push('second');
$stack->push('third');

echo $stack->pop(); // "third" — last added, first removed
echo $stack->pop(); // "second"
echo $stack->pop(); // "first"
```

#### SplQueue — First In, First Out (FIFO)

Red funkcioniše kao linija u prodavnici. Prva osoba u redu se prva poslužuje.

```php
$queue = new SplQueue();
$queue->enqueue('Task 1');
$queue->enqueue('Task 2');
$queue->enqueue('Task 3');

echo $queue->dequeue(); // "Task 1" — first added, first removed
echo $queue->dequeue(); // "Task 2"
```

#### SplPriorityQueue — Elementi sa prioritetom

Elementi izlaze prema redosledu prioriteta, a ne redosledu dodavanja.

```php
$queue = new SplPriorityQueue();
$queue->insert('Low priority task', 1);
$queue->insert('Critical bug fix', 10);
$queue->insert('Medium task', 5);

echo $queue->extract(); // "Critical bug fix" (priority 10)
echo $queue->extract(); // "Medium task" (priority 5)
echo $queue->extract(); // "Low priority task" (priority 1)
```

#### SplFixedArray — Niz fiksne veličine

Efikasniji u pogledu memorije od regularnih nizova kada unapred znate veličinu.

```php
$arr = new SplFixedArray(3);
$arr[0] = 'a';
$arr[1] = 'b';
$arr[2] = 'c';
// $arr[3] = 'd'; // RuntimeException — array is fixed at 3 elements

// Uses ~30-50% less memory than a regular array for large datasets
```

### Iteratori

#### DirectoryIterator — Iteriranje kroz fajlove

```php
$dir = new DirectoryIterator('/var/log');
foreach ($dir as $file) {
    if ($file->isFile()) {
        echo $file->getFilename() . ' — ' . $file->getSize() . " bytes\n";
    }
}
```

#### RecursiveDirectoryIterator — Fajlovi u svim podfolderima

```php
$dir = new RecursiveDirectoryIterator('/var/www/project/src');
$iterator = new RecursiveIteratorIterator($dir);

foreach ($iterator as $file) {
    if ($file->getExtension() === 'php') {
        echo $file->getPathname() . "\n";
    }
}
// Lists every .php file in src/ and all its subfolders
```

#### FilterIterator — Filtriranje rezultata

```php
class PhpFileFilter extends FilterIterator
{
    public function accept(): bool
    {
        return $this->current()->getExtension() === 'php';
    }
}

$dir = new RecursiveDirectoryIterator('/var/www/src');
$recursive = new RecursiveIteratorIterator($dir);
$phpFiles = new PhpFileFilter($recursive);

foreach ($phpFiles as $file) {
    echo $file->getPathname() . "\n"; // Only .php files
}
```

### Funkcije

#### spl_autoload_register()

Registruje funkciju za automatsko učitavanje klasa. Ovo je temelj celokupnog autoloadinga u PHP-u.

```php
spl_autoload_register(function ($class) {
    $file = str_replace('\\', '/', $class) . '.php';
    if (file_exists($file)) {
        require $file;
    }
});
```

#### spl_object_id()

Vraća jedinstveni integer ID za objekat. Korisno za praćenje objekata.

```php
$a = new stdClass();
$b = new stdClass();
echo spl_object_id($a); // e.g., 1
echo spl_object_id($b); // e.g., 2
```

#### class_implements() i class_parents()

```php
$interfaces = class_implements(ArrayObject::class);
// ['IteratorAggregate', 'Traversable', 'ArrayAccess', 'Serializable', 'Countable']

$parents = class_parents(SplPriorityQueue::class);
// Shows parent classes
```

### Izuzeci

SPL pruža skup standardnih klasa izuzetaka:

| Izuzetak | Kada koristiti |
|----------|----------------|
| `InvalidArgumentException` | Pogrešan tip/vrednost prosleđena funkciji |
| `RuntimeException` | Greška koja se može pronaći samo pri pokretanju |
| `LogicException` | Greška u logici programa |
| `OutOfRangeException` | Indeks van validnog opsega |
| `OverflowException` | Dodavanje u pun kontejner |
| `UnderflowException` | Uklanjanje iz praznog kontejnera |
| `UnexpectedValueException` | Vrednost se ne poklapa sa očekivanim tipom |
| `LengthException` | Nevalidna dužina (npr. string previše dugačak) |

```php
function divide(int $a, int $b): float
{
    if ($b === 0) {
        throw new InvalidArgumentException('Cannot divide by zero');
    }
    return $a / $b;
}
```

### Realni scenario

Gradite sistem redova zadataka za pozadinske poslove:

```php
class JobQueue
{
    private SplPriorityQueue $queue;

    public function __construct()
    {
        $this->queue = new SplPriorityQueue();
    }

    public function addJob(string $jobName, int $priority): void
    {
        $this->queue->insert($jobName, $priority);
    }

    public function processAll(): void
    {
        while (!$this->queue->isEmpty()) {
            $job = $this->queue->extract();
            echo "Processing: $job\n";
        }
    }
}

$queue = new JobQueue();
$queue->addJob('Send welcome email', 3);
$queue->addJob('Process payment', 10);
$queue->addJob('Generate report', 1);
$queue->addJob('Update search index', 5);

$queue->processAll();
// Processing: Process payment (10)
// Processing: Update search index (5)
// Processing: Send welcome email (3)
// Processing: Generate report (1)
```

### Zaključak

SPL pruža gotove strukture podataka (Stack, Queue, PriorityQueue, FixedArray), iteratore fajlova (DirectoryIterator, RecursiveDirectoryIterator), sistem autoloadinga (`spl_autoload_register`) i standardne izuzetke. Ugrađeni su u PHP i efikasniji su od izgradnje sopstvenih implementacija. Najčešće korišćeni u realnim projektima su `spl_autoload_register()`, SPL izuzeci i iteratori direktorijuma.
