PHP 7.4 je objavljen u novembru 2019. godine. Uveo je nekoliko važnih mogućnosti koje su PHP kod učinile kraćim i ekspresivnijim.

### Typed properties

Pre PHP 7.4, properties klase nisu mogli imati deklaracije tipova. Sada mogu:

```php
class User
{
    public int $id;
    public string $name;
    public ?string $email = null; // nullable
    public array $roles = [];
}

$user = new User();
$user->id = 1;        // OK
$user->id = "hello";  // TypeError!
```

### Arrow funkcije (kratke closure funkcije)

Kraća sintaksa za jednostavne anonimne funkcije. Arrow funkcije automatski hvataju promenljive iz spoljašnjeg opsega (bez potrebe za `use`):

```php
// Before PHP 7.4
$doubled = array_map(function ($n) {
    return $n * 2;
}, [1, 2, 3]);

// PHP 7.4
$doubled = array_map(fn($n) => $n * 2, [1, 2, 3]);
```

Arrow funkcije automatski hvataju spoljašnje promenljive po vrednosti:

```php
$multiplier = 3;

// Before: need 'use'
$fn = function ($n) use ($multiplier) {
    return $n * $multiplier;
};

// PHP 7.4: automatic capture
$fn = fn($n) => $n * $multiplier;
```

### Null coalescing assignment operator (??=)

Dodeljuje vrednost samo ako je promenljiva null ili nije postavljena:

```php
// Before PHP 7.4
if (!isset($data['timezone'])) {
    $data['timezone'] = 'UTC';
}

// Or
$data['timezone'] = $data['timezone'] ?? 'UTC';

// PHP 7.4
$data['timezone'] ??= 'UTC';
```

### Spread operator u nizovima

Možete koristiti `...` za raspakovavanje nizova unutar drugih nizova:

```php
$defaults = ['color' => 'blue', 'size' => 'M'];
$custom = ['size' => 'L', 'weight' => 100];

// Works with numeric keys
$numbers = [1, 2, 3];
$more = [0, ...$numbers, 4, 5]; // [0, 1, 2, 3, 4, 5]

// Also works inside function calls (already existed before 7.4)
function sum(int ...$numbers): int {
    return array_sum($numbers);
}
```

### Preloading

PHP 7.4 je uveo OPCache preloading. Kada se server pokrene, PHP može jednom učitati određene fajlove u memoriju. Ovi fajlovi ostaju u memoriji za sve zahteve, tako da ne moraju biti kompajlirani ponovo:

```php
// preload.php (set in php.ini: opcache.preload=preload.php)
$files = glob(__DIR__ . '/src/**/*.php');
foreach ($files as $file) {
    opcache_compile_file($file);
}
```

Ovo poboljšava performanse za framework-ove sa mnogo fajlova. Nedostatak je što morate restartovati server da biste videli promene u preloadovanim fajlovima.

### Weak references

Weak reference vam omogućava da držite referencu na objekat bez sprečavanja njegovog uništavanja od strane garbage collector-a:

```php
$object = new stdClass();
$weakRef = WeakReference::create($object);

echo $weakRef->get() !== null; // true — object exists

unset($object);

echo $weakRef->get(); // null — object was garbage collected
```

### Separator numeričkih literala

Donje crte se mogu koristiti u brojevima kako bi bili lakši za čitanje:

```php
$million = 1_000_000;
$price = 19_99; // 1999
$hex = 0xFF_AA_BB;
$binary = 0b1010_0001;
```

### Kovarijantni povratni tipovi i kontravarijantni parametri

Podklase sada mogu vraćati specifičnije tipove i prihvatati šire tipove parametara:

```php
class Animal {}
class Dog extends Animal {}

class AnimalFactory
{
    public function create(): Animal { return new Animal(); }
}

class DogFactory extends AnimalFactory
{
    public function create(): Dog { return new Dog(); } // Covariant return — allowed in 7.4
}
```

### Realni scenario

Radite refactoring servisa za registraciju korisnika. Pre PHP 7.4, kod izgleda ovako:

```php
class RegistrationService
{
    private $validator;
    private $repository;
    private $mailer;

    public function register(array $data)
    {
        if (!isset($data['role'])) {
            $data['role'] = 'user';
        }

        $errors = array_filter($data, function ($value) {
            return empty($value);
        });
        // ...
    }
}
```

Nakon PHP 7.4:

```php
class RegistrationService
{
    private Validator $validator;
    private UserRepository $repository;
    private Mailer $mailer;

    public function register(array $data): void
    {
        $data['role'] ??= 'user';

        $errors = array_filter($data, fn($value) => empty($value));
        // ...
    }
}
```

Kod postaje kraći, sigurniji (typed properties odmah hvataju pogrešne tipove) i lakši za čitanje.

### Zaključak

PHP 7.4 je dodao typed properties, arrow funkcije (`fn() =>`), null coalescing assignment (`??=`), spread operator u nizovima, preloading, weak references, numeričke separatore i kovarijantne povratne tipove. Ove mogućnosti su značajno smanjile boilerplate i poboljšale bezbednost tipova.
