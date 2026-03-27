Popularni PHP frejmvorci koriste mnoge obrasce dizajna za rešavanje uobičajenih problema. Poznavanje koji obrasci se koriste pomaže vam da razumete unutrašnjost frejmvorka i odgovorite na pitanja na intervjuima.

### Obrasci u Symfony-u

#### 1. Dependency Injection / Service Container

Jezgro Symfony-a. Servisi su definisani u konfiguraciji i injektovani u klase kroz konstruktore.

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

**Obrazac:** Dependency Injection Container (IoC Container)

#### 2. Observer (EventDispatcher)

Symfony-ova komponenta EventDispatcher implementira Observer obrazac. Događaji se emituju, a listeneri reaguju na njih.

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

**Obrazac:** Observer / Pub-Sub

#### 3. Chain of Responsibility (Middleware / Kernel Events)

Symfony-ov HTTP kernel obrađuje zahteve kroz lanac event listenera. Svaki listener može da obradi zahtev, modifikuje ga ili prosledi sledećem.

```
Request → kernel.request listeners → Controller → kernel.response listeners → Response
```

Sigurnosni firewall-ovi takođe koriste ovaj obrazac — svaki autentifikator pokušava da autentifikuje zahtev.

#### 4. Decorator

Symfony koristi dekoratore za dodavanje ponašanja servisima. Na primer, dodavanje keširanja repozitorijumu:

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

Symfony koristi Factory obrasce za kreiranje složenih objekata:

```php
$form = $this->createForm(OrderType::class, $order);
// FormFactory creates the form, handles types, validation, etc.
```

#### 6. Strategy (Voters, Authenticators)

Symfony Security koristi Strategy obrazac za votere — svaki voter implementira isti interfejs ali ima različitu logiku:

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

Symfony može kreirati lenje proksije za servise koji su skupi za inicijalizaciju:

```yaml
services:
    App\Service\HeavyService:
        lazy: true  # Creates a proxy, initializes only on first method call
```

### Obrasci u Laravel-u

#### 1. Facade

Laravel Facade-ovi pružaju statički interfejs prema servisima u kontejneru. Iza kulisa, razrešavaju servis iz kontejnera.

```php
// Looks static, but actually resolves from the container
Cache::put('key', 'value', 3600);
// Is equivalent to:
app('cache')->put('key', 'value', 3600);
```

**Obrazac:** Facade (nije klasični GoF Facade — više poput statičkog proksija)

#### 2. Repository (Eloquent)

Eloquent modeli deluju i kao Active Record i kao Repository:

```php
$users = User::where('active', true)->orderBy('name')->get();
$user = User::findOrFail($id);
```

#### 3. Observer

Laravel ima model observere koji reaguju na Eloquent događaje:

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

Autentifikacioni gards, keš drajveri, red drajveri — svi koriste Strategy obrazac:

```php
// Different cache strategies, same interface
Cache::store('redis')->get('key');
Cache::store('file')->get('key');
Cache::store('memcached')->get('key');
```

#### 5. Builder

Query Builder koristi Builder obrazac:

```php
$users = DB::table('users')
    ->where('active', true)
    ->where('age', '>', 18)
    ->orderBy('name')
    ->limit(10)
    ->get();
```

### Obrasci u Doctrine ORM-u

#### 1. Data Mapper

Centralni obrazac. Entiteti su obični PHP objekti bez logike baze podataka. EntityManager rukuje svim operacijama baze podataka:

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

EntityManager prati sve promene na entitetima i izvršava ih u jednoj transakciji kada se pozove `flush()`:

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

Doctrine osigurava da isti red baze podataka uvek vraća isti PHP objekat unutar jednog zahteva:

```php
$user1 = $em->find(User::class, 1);
$user2 = $em->find(User::class, 1);

var_dump($user1 === $user2); // true — same object, not a copy
```

#### 4. Proxy (Lazy Loading)

Doctrine kreira proxy objekte za povezane entitete. Proksi učitava podatke iz baze podataka samo kada ih pristupite:

```php
$order = $em->find(Order::class, 1);

// $order->getCustomer() returns a Proxy, not the real Customer
// No query executed yet

echo $order->getCustomer()->getName(); // NOW Doctrine queries the customers table
```

#### 5. Repository

Doctrine repozitorijumi enkapsuliraju logiku upita:

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

### Tabela Rezimea

| Obrazac | Symfony | Laravel | Doctrine |
|---------|--------|---------|----------|
| DI Container | ✓ Jezgro | ✓ Jezgro | — |
| Observer | EventDispatcher | Model Observers | Event system |
| Strategy | Voters, Authenticators | Guards, Drivers | — |
| Decorator | Dekoracija servisa | — | — |
| Factory | FormFactory, SerializerFactory | — | EntityManagerFactory |
| Proxy | Leni servisi | — | Lazy loading |
| Chain of Responsibility | Kernel events, Middleware | Middleware | — |
| Facade | — | ✓ Jezgro | — |
| Data Mapper | — | — | ✓ Jezgro |
| Unit of Work | — | — | ✓ Jezgro |
| Identity Map | — | — | ✓ Jezgro |
| Repository | — | Eloquent | EntityRepository |
| Builder | — | Query Builder | QueryBuilder |
| Active Record | — | Eloquent | — |

### Zaključak

Symfony se oslanja na DI Container, Observer (događaji), Decorator i Strategy (voters). Laravel koristi Facade, Observer, Strategy (drajveri) i Active Record (Eloquent). Doctrine je izgrađen na obrascima Data Mapper, Unit of Work, Identity Map, Proxy (lazy loading) i Repository. Razumevanje ovih obrazaca pomaže vam da efikasnije radite sa frejmvorcima i objašnjava mnoge njihove dizajnerske odluke.
