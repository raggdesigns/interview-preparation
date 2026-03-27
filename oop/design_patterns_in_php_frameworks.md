Popular PHP frameworks use many design patterns to solve common problems. Knowing which patterns are used helps you understand framework internals and answer interview questions.

### Patterns in Symfony

#### 1. Dependency Injection / Service Container

The core of Symfony. Services are defined in configuration and injected into classes through constructors.

```php
// Symfony autowires dependencies automatically
class OrderService
{
    public function __construct(
        private EntityManagerInterface $em,
        private LoggerInterface $logger,
        private MailerInterface $mailer,
    ) {}
}
```

**Pattern:** Dependency Injection Container (IoC Container)

#### 2. Observer (EventDispatcher)

Symfony's EventDispatcher component implements the Observer pattern. Events are dispatched, and listeners react to them.

```php
// Dispatching an event
$this->eventDispatcher->dispatch(new OrderCreatedEvent($order));

// Listener reacts
#[AsEventListener(event: OrderCreatedEvent::class)]
class SendConfirmationEmail
{
    public function __invoke(OrderCreatedEvent $event): void
    {
        $this->mailer->send($event->getOrder()->getCustomerEmail(), 'Order confirmed');
    }
}
```

**Pattern:** Observer / Pub-Sub

#### 3. Chain of Responsibility (Middleware / Kernel Events)

Symfony's HTTP kernel processes requests through a chain of event listeners. Each listener can handle the request, modify it, or pass it to the next one.

```text
Request → kernel.request listeners → Controller → kernel.response listeners → Response
```

Security firewalls also use this pattern — each authenticator tries to authenticate the request.

#### 4. Decorator

Symfony uses decorators to add behavior to services. For example, adding caching to a repository:

```yaml
services:
    App\Repository\ProductRepository: ~
    
    App\Repository\CachedProductRepository:
        decorates: App\Repository\ProductRepository
        arguments:
            $inner: '@.inner'
```

```php
class CachedProductRepository implements ProductRepositoryInterface
{
    public function __construct(
        private ProductRepositoryInterface $inner,
        private CacheInterface $cache,
    ) {}
    
    public function find(int $id): ?Product
    {
        return $this->cache->get("product_$id", fn() => $this->inner->find($id));
    }
}
```

#### 5. Factory (Form / Serializer)

Symfony uses factories to create complex objects:

```php
$form = $this->createForm(OrderType::class, $order);
// FormFactory creates the form, handles types, validation, etc.
```

#### 6. Strategy (Voters, Authenticators)

Symfony Security uses Strategy pattern for voters — each voter implements the same interface but has different logic:

```php
class PostVoter extends Voter
{
    protected function voteOnAttribute(string $attribute, mixed $subject, TokenInterface $token): bool
    {
        return match($attribute) {
            'EDIT' => $subject->getAuthor() === $token->getUser(),
            'DELETE' => $token->getUser()->hasRole('ADMIN'),
        };
    }
}
```

#### 7. Proxy (Lazy Services)

Symfony can create lazy proxies for services that are expensive to initialize:

```yaml
services:
    App\Service\HeavyService:
        lazy: true  # Creates a proxy, initializes only on first method call
```

### Patterns in Laravel

#### 1. Facade

Laravel Facades provide a static interface to services in the container. Behind the scenes, they resolve the service from the container.

```php
// Looks static, but actually resolves from the container
Cache::put('key', 'value', 3600);
// Is equivalent to:
app('cache')->put('key', 'value', 3600);
```

**Pattern:** Facade (not the classic GoF Facade — more like a static proxy)

#### 2. Repository (Eloquent)

Eloquent models act as both Active Record and Repository:

```php
$users = User::where('active', true)->orderBy('name')->get();
$user = User::findOrFail($id);
```

#### 3. Observer

Laravel has model observers that react to Eloquent events:

```php
class UserObserver
{
    public function created(User $user): void
    {
        Mail::send(new WelcomeEmail($user));
    }
    
    public function deleted(User $user): void
    {
        Log::info("User {$user->id} deleted");
    }
}
```

#### 4. Strategy (Guards, Drivers)

Authentication guards, cache drivers, queue drivers — all use Strategy pattern:

```php
// Different cache strategies, same interface
Cache::store('redis')->get('key');
Cache::store('file')->get('key');
Cache::store('memcached')->get('key');
```

#### 5. Builder

Query Builder uses the Builder pattern:

```php
$users = DB::table('users')
    ->where('active', true)
    ->where('age', '>', 18)
    ->orderBy('name')
    ->limit(10)
    ->get();
```

### Patterns in Doctrine ORM

#### 1. Data Mapper

The core pattern. Entities are plain PHP objects with no database logic. The EntityManager handles all database operations:

```php
// Entity — no database logic
class User
{
    private int $id;
    private string $name;
    
    public function getName(): string { return $this->name; }
}

// EntityManager maps between objects and database
$user = $em->find(User::class, 1);   // Maps DB row → object
$em->persist($newUser);               // Maps object → DB row
$em->flush();                          // Executes SQL
```

#### 2. Unit of Work

The EntityManager tracks all changes to entities and executes them in a single transaction when `flush()` is called:

```php
$user1 = $em->find(User::class, 1);
$user1->setName('Alice');          // Change tracked

$user2 = new User('Bob');
$em->persist($user2);              // Insert tracked

$em->remove($user3);               // Delete tracked

$em->flush();
// All three operations execute in one transaction:
// UPDATE users SET name='Alice' WHERE id=1;
// INSERT INTO users (name) VALUES ('Bob');
// DELETE FROM users WHERE id=3;
```

#### 3. Identity Map

Doctrine ensures that the same database row always returns the same PHP object within a request:

```php
$user1 = $em->find(User::class, 1);
$user2 = $em->find(User::class, 1);

var_dump($user1 === $user2); // true — same object, not a copy
```

#### 4. Proxy (Lazy Loading)

Doctrine creates proxy objects for related entities. The proxy loads data from the database only when you access it:

```php
$order = $em->find(Order::class, 1);

// $order->getCustomer() returns a Proxy, not the real Customer
// No query executed yet

echo $order->getCustomer()->getName(); // NOW Doctrine queries the customers table
```

#### 5. Repository

Doctrine repositories encapsulate query logic:

```php
class UserRepository extends ServiceEntityRepository
{
    public function findActiveUsers(): array
    {
        return $this->createQueryBuilder('u')
            ->where('u.active = :active')
            ->setParameter('active', true)
            ->getQuery()
            ->getResult();
    }
}
```

### Summary Table

| Pattern | Symfony | Laravel | Doctrine |
|---------|--------|---------|----------|
| DI Container | ✓ Core | ✓ Core | — |
| Observer | EventDispatcher | Model Observers | Event system |
| Strategy | Voters, Authenticators | Guards, Drivers | — |
| Decorator | Service decoration | — | — |
| Factory | FormFactory, SerializerFactory | — | EntityManagerFactory |
| Proxy | Lazy services | — | Lazy loading |
| Chain of Responsibility | Kernel events, Middleware | Middleware | — |
| Facade | — | ✓ Core | — |
| Data Mapper | — | — | ✓ Core |
| Unit of Work | — | — | ✓ Core |
| Identity Map | — | — | ✓ Core |
| Repository | — | Eloquent | EntityRepository |
| Builder | — | Query Builder | QueryBuilder |
| Active Record | — | Eloquent | — |

### Conclusion

Symfony relies heavily on DI Container, Observer (events), Decorator, and Strategy (voters). Laravel uses Facade, Observer, Strategy (drivers), and Active Record (Eloquent). Doctrine is built on Data Mapper, Unit of Work, Identity Map, Proxy (lazy loading), and Repository patterns. Understanding these patterns helps you work with frameworks more effectively and explains many of their design decisions.
