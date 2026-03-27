Reflection u PHP-u je skup klasa koje vam omogućavaju da pregledate strukturu koda pri pokretanju. Možete ispitivati klase, metode, properties, parametre i još mnogo toga — bez otvaranja izvornog koda. Zamislite to kao PHP koji gleda sebe u ogledalo.

### Šta Reflection može da uradi?

- Saznati koje metode i properties klasa ima
- Proveriti parametre metoda (nazive, tipove, podrazumevane vrednosti)
- Čitati PHP atribute (anotacije)
- Pristupiti privatnim/zaštićenim članovima
- Proveriti da li klasa implementira interfejs

### Osnovni primer Reflection-a

```php
class User
{
    public function __construct(
        private string $name,
        private string $email,
        private int $age = 25
    ) {}

    public function getName(): string
    {
        return $this->name;
    }
}

$reflection = new ReflectionClass(User::class);

// Get all methods
foreach ($reflection->getMethods() as $method) {
    echo $method->getName() . "\n"; // "__construct", "getName"
}

// Get constructor parameters
$constructor = $reflection->getConstructor();
foreach ($constructor->getParameters() as $param) {
    echo $param->getName() . ': ' . $param->getType() . "\n";
    // "name: string", "email: string", "age: int"
}
```

### Praktična upotreba 1: Dependency Injection kontejner

Ovo je najčešća realna upotreba reflection-a. DI kontejner čita konstruktor da bi saznao koje zavisnosti klasa treba i automatski ih kreira.

```php
class SimpleContainer
{
    public function make(string $className): object
    {
        $reflection = new ReflectionClass($className);
        $constructor = $reflection->getConstructor();

        if (!$constructor) {
            return new $className();
        }

        $dependencies = [];
        foreach ($constructor->getParameters() as $param) {
            $type = $param->getType()->getName();
            // Recursively create dependencies
            $dependencies[] = $this->make($type);
        }

        return $reflection->newInstanceArgs($dependencies);
    }
}

// Automatically creates UserRepository, then injects it into UserService
$container = new SimpleContainer();
$service = $container->make(UserService::class);
```

Ovako rade Symfony-jev DI kontejner i Laravel-ov service kontejner u svojoj osnovi.

### Praktična upotreba 2: Automatska validacija formi

Koristite reflection za čitanje atributa i validaciju podataka:

```php
#[Attribute]
class NotBlank {}

#[Attribute]
class MaxLength {
    public function __construct(public int $max) {}
}

class RegistrationForm
{
    #[NotBlank]
    #[MaxLength(max: 100)]
    public string $name;

    #[NotBlank]
    public string $email;
}

function validate(object $form): array
{
    $errors = [];
    $reflection = new ReflectionClass($form);

    foreach ($reflection->getProperties() as $property) {
        $value = $property->getValue($form);

        foreach ($property->getAttributes() as $attribute) {
            $attr = $attribute->newInstance();

            if ($attr instanceof NotBlank && empty($value)) {
                $errors[] = $property->getName() . ' must not be blank';
            }
            if ($attr instanceof MaxLength && strlen($value) > $attr->max) {
                $errors[] = $property->getName() . " must be max {$attr->max} characters";
            }
        }
    }

    return $errors;
}
```

### Praktična upotreba 3: Pristup privatnim properties u testovima

```php
class UserServiceTest extends TestCase
{
    public function testInternalCache(): void
    {
        $service = new UserService();

        // Access private property using reflection
        $reflection = new ReflectionClass($service);
        $cacheProperty = $reflection->getProperty('cache');
        $cacheProperty->setAccessible(true);

        $this->assertEmpty($cacheProperty->getValue($service));

        $service->getUser(1);

        $this->assertNotEmpty($cacheProperty->getValue($service));
    }
}
```

### Realni scenario

Gradite command bus. Kada se komanda pošalje, trebate automatski pronaći pravi handler. Reflection pomaže u mapiranju klasa komandi na metode handlera:

```php
class CommandBus
{
    private array $handlers = [];

    public function register(object $handler): void
    {
        $reflection = new ReflectionClass($handler);

        foreach ($reflection->getMethods() as $method) {
            $params = $method->getParameters();
            if (count($params) === 1 && !$params[0]->getType()->isBuiltin()) {
                $commandClass = $params[0]->getType()->getName();
                $this->handlers[$commandClass] = [$handler, $method->getName()];
            }
        }
    }

    public function dispatch(object $command): void
    {
        $class = get_class($command);
        if (isset($this->handlers[$class])) {
            [$handler, $method] = $this->handlers[$class];
            $handler->$method($command);
        }
    }
}
```

### Zaključak

Reflection je moćan alat za ispitivanje strukture koda pri pokretanju. Njegove glavne praktične primene su u DI kontejnerima, sistemima validacije, generatorima dokumentacije i testiranju. Većina PHP framework-ova se oslanja na reflection za autowiring, čitanje atributa i automatsko rutiranje. Iako moćan, reflection je sporiji od direktnog izvršavanja koda, pa ga izbegavajte u petljama kritičnim za performanse.
