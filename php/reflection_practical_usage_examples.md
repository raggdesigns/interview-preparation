Reflection in PHP is a set of classes that let you inspect the structure of your code at runtime. You can examine classes, methods, properties, parameters, and more — without having the source code open. Think of it as PHP looking at itself in a mirror.

### What Can Reflection Do?

- Find out what methods and properties a class has
- Check method parameters (names, types, default values)
- Read PHP attributes (annotations)
- Access private/protected members
- Check if a class implements an interface

### Basic Reflection Example

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

### Practical Usage 1: Dependency Injection Container

This is the most common real-world use of reflection. A DI container reads the constructor to know what dependencies a class needs, and automatically creates them.

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

This is how Symfony's DI container and Laravel's service container work at their core.

### Practical Usage 2: Automatic Form Validation

Use reflection to read attributes and validate data:

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

### Practical Usage 3: Accessing Private Properties in Tests

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

### Real Scenario

You are building a command bus. When a command is dispatched, you need to find the right handler automatically. Reflection helps match command classes to handler methods:

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

### Conclusion

Reflection is a powerful tool for inspecting code structure at runtime. Its main practical uses are in DI containers, validation systems, documentation generators, and testing. Most PHP frameworks rely heavily on reflection to provide autowiring, attribute reading, and automatic routing. While powerful, reflection is slower than direct code execution, so avoid using it in performance-critical loops.
