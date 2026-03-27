Kada testirate servise koji zavise od Doctrine repozitorijuma, morate odlučiti između mockovanja repozitorijuma (unit testovi) i korišćenja prave baze podataka (integracioni testovi). Oba pristupa su vredna za različite svrhe.

### Mockovanje EntityRepository u unit testovima

Najjednostavniji slučaj — vaš servis zavisi od Doctrine repozitorijuma:

```php
class OrderService
{
    public function __construct(
        private EntityManagerInterface $em,
        private OrderRepository $orderRepository,
    ) {}

    public function cancelOrder(int $orderId): void
    {
        $order = $this->orderRepository->find($orderId);
        if ($order === null) {
            throw new OrderNotFoundException($orderId);
        }

        $order->setStatus('cancelled');
        $this->em->flush();
    }
}
```

Mockujte i repozitorijum i entity manager:

```php
use PHPUnit\Framework\TestCase;

class OrderServiceTest extends TestCase
{
    public function testCancelOrder(): void
    {
        $order = new Order();
        $order->setStatus('pending');

        // Mock repository
        $repo = $this->createMock(OrderRepository::class);
        $repo->method('find')
             ->with(42)
             ->willReturn($order);

        // Mock entity manager
        $em = $this->createMock(EntityManagerInterface::class);
        $em->expects($this->once())->method('flush');

        $service = new OrderService($em, $repo);
        $service->cancelOrder(42);

        $this->assertEquals('cancelled', $order->getStatus());
    }

    public function testCancelOrderThrowsWhenNotFound(): void
    {
        $repo = $this->createMock(OrderRepository::class);
        $repo->method('find')->willReturn(null);

        $em = $this->createMock(EntityManagerInterface::class);

        $service = new OrderService($em, $repo);

        $this->expectException(OrderNotFoundException::class);
        $service->cancelOrder(999);
    }
}
```

### Mockovanje prilagođenih metoda repozitorijuma

Kada vaš repozitorijum ima prilagođene metode upita:

```php
class ProductRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Product::class);
    }

    public function findActiveByCategory(string $category): array
    {
        return $this->createQueryBuilder('p')
            ->where('p.category = :category')
            ->andWhere('p.active = true')
            ->setParameter('category', $category)
            ->getQuery()
            ->getResult();
    }

    public function findCheaperThan(float $maxPrice): array
    {
        return $this->createQueryBuilder('p')
            ->where('p.price < :max')
            ->setParameter('max', $maxPrice)
            ->orderBy('p.price', 'ASC')
            ->getQuery()
            ->getResult();
    }
}
```

Mockujte prilagođene metode na isti način:

```php
class CatalogServiceTest extends TestCase
{
    public function testGetCategoryProducts(): void
    {
        $products = [
            new Product('Widget', 29.99, 'electronics'),
            new Product('Gadget', 49.99, 'electronics'),
        ];

        $repo = $this->createMock(ProductRepository::class);
        $repo->method('findActiveByCategory')
             ->with('electronics')
             ->willReturn($products);

        $service = new CatalogService($repo);
        $result = $service->getCategoryProducts('electronics');

        $this->assertCount(2, $result);
    }
}
```

### Mockovanje EntityManager-a za Persist/Flush

Kada vaš kod kreira nove entitete:

```php
class RegistrationService
{
    public function __construct(
        private EntityManagerInterface $em,
        private UserRepository $userRepo,
    ) {}

    public function registerUser(string $email, string $name): User
    {
        $existing = $this->userRepo->findOneBy(['email' => $email]);
        if ($existing !== null) {
            throw new UserAlreadyExistsException($email);
        }

        $user = new User($email, $name);
        $this->em->persist($user);
        $this->em->flush();

        return $user;
    }
}
```

Test:

```php
class RegistrationServiceTest extends TestCase
{
    public function testRegisterUser(): void
    {
        $repo = $this->createMock(UserRepository::class);
        $repo->method('findOneBy')->willReturn(null);  // No existing user

        $em = $this->createMock(EntityManagerInterface::class);

        // Verify persist is called with a User object
        $em->expects($this->once())
           ->method('persist')
           ->with($this->callback(function ($entity) {
               return $entity instanceof User
                   && $entity->getEmail() === 'john@example.com';
           }));

        $em->expects($this->once())->method('flush');

        $service = new RegistrationService($em, $repo);
        $user = $service->registerUser('john@example.com', 'John');

        $this->assertEquals('john@example.com', $user->getEmail());
    }

    public function testRegisterUserThrowsOnDuplicate(): void
    {
        $existing = new User('john@example.com', 'John');

        $repo = $this->createMock(UserRepository::class);
        $repo->method('findOneBy')->willReturn($existing);

        $em = $this->createMock(EntityManagerInterface::class);
        $em->expects($this->never())->method('persist');

        $service = new RegistrationService($em, $repo);

        $this->expectException(UserAlreadyExistsException::class);
        $service->registerUser('john@example.com', 'John');
    }
}
```

### Integracioni testovi sa KernelTestCase

Za testiranje da li Doctrine upiti stvarno rade ispravno, koristite integracione testove sa pravom test bazom podataka:

```php
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;

class ProductRepositoryTest extends KernelTestCase
{
    private ProductRepository $repo;
    private EntityManagerInterface $em;

    protected function setUp(): void
    {
        self::bootKernel();
        $this->em = static::getContainer()->get(EntityManagerInterface::class);
        $this->repo = static::getContainer()->get(ProductRepository::class);

        // Seed test data
        $product1 = new Product('Widget', 29.99, 'electronics');
        $product1->setActive(true);

        $product2 = new Product('Old Widget', 19.99, 'electronics');
        $product2->setActive(false);

        $product3 = new Product('Desk', 199.99, 'furniture');
        $product3->setActive(true);

        $this->em->persist($product1);
        $this->em->persist($product2);
        $this->em->persist($product3);
        $this->em->flush();
    }

    public function testFindActiveByCategory(): void
    {
        $products = $this->repo->findActiveByCategory('electronics');

        $this->assertCount(1, $products);  // Only active products
        $this->assertEquals('Widget', $products[0]->getName());
    }

    public function testFindCheaperThan(): void
    {
        $products = $this->repo->findCheaperThan(50.00);

        $this->assertCount(2, $products);
        // Ordered by price ASC
        $this->assertEquals('Old Widget', $products[0]->getName());
    }
}
```

### Korišćenje fixture-a sa Doctrine-om

Za kompleksne test podatke, koristite fixture-e:

```php
// src/DataFixtures/TestFixtures.php
class TestFixtures extends Fixture
{
    public function load(ObjectManager $manager): void
    {
        $user = new User('admin@example.com', 'Admin');
        $manager->persist($user);

        for ($i = 1; $i <= 5; $i++) {
            $order = new Order($user, $i * 10.00);
            $manager->persist($order);
        }

        $manager->flush();
    }
}
```

Učitajte fixture-e u testovima:

```php
use Doctrine\Common\DataFixtures\Purger\ORMPurger;
use Doctrine\Common\DataFixtures\Executor\ORMExecutor;
use Doctrine\Common\DataFixtures\Loader;

class OrderRepositoryTest extends KernelTestCase
{
    protected function setUp(): void
    {
        self::bootKernel();
        $em = static::getContainer()->get(EntityManagerInterface::class);

        $loader = new Loader();
        $loader->addFixture(new TestFixtures());

        $executor = new ORMExecutor($em, new ORMPurger());
        $executor->execute($loader->getFixtures());
    }
}
```

### Pristup zasnovan na interfejsu

Za čistije razdvajanje, definišite interfejs repozitorijuma:

```php
interface OrderRepositoryInterface
{
    public function find(int $id): ?Order;
    public function findByUser(User $user): array;
    public function save(Order $order): void;
}

class DoctrineOrderRepository extends ServiceEntityRepository implements OrderRepositoryInterface
{
    public function save(Order $order): void
    {
        $this->getEntityManager()->persist($order);
        $this->getEntityManager()->flush();
    }

    public function findByUser(User $user): array
    {
        return $this->findBy(['user' => $user], ['createdAt' => 'DESC']);
    }
}
```

Sada servisi zavise od interfejsa, koji je lako mockirati:

```php
class DashboardServiceTest extends TestCase
{
    public function testGetUserOrders(): void
    {
        $user = new User('john@example.com', 'John');
        $orders = [new Order($user, 100), new Order($user, 200)];

        $repo = $this->createMock(OrderRepositoryInterface::class);
        $repo->method('findByUser')
             ->with($user)
             ->willReturn($orders);

        $service = new DashboardService($repo);
        $result = $service->getUserOrders($user);

        $this->assertCount(2, $result);
    }
}
```

### Rezime unit vs integracioni testovi

| Šta testirati | Tip testa | Kako |
|--------------|-----------|------|
| Logika servisa koja koristi repozitorijum | Unit test | Mockujte repozitorijum |
| Rezultati upita repozitorijuma | Integracioni test | Prava baza + KernelTestCase |
| Ponašanje persist/flush entiteta | Integracioni test | Prava baza + rollback transakcije |
| Kompleksni DQL/QueryBuilder | Integracioni test | Prava baza sa seed podacima |

### Realni scenario

Imate reporting servis koji mora da agregira podatke o porudžbinama:

```php
class ReportService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepo,
        private ProductRepositoryInterface $productRepo,
    ) {}

    public function generateMonthlySummary(int $year, int $month): MonthlySummary
    {
        $orders = $this->orderRepo->findByMonth($year, $month);
        $totalRevenue = array_sum(array_map(fn(Order $o) => $o->getTotal(), $orders));
        $topProducts = $this->productRepo->findTopSelling($year, $month, limit: 5);

        return new MonthlySummary(
            orderCount: count($orders),
            totalRevenue: $totalRevenue,
            topProducts: $topProducts,
        );
    }
}
```

**Unit test** — mockujte repozitorijume:

```php
$orderRepo = $this->createMock(OrderRepositoryInterface::class);
$orderRepo->method('findByMonth')->willReturn([
    new Order($user, 100),
    new Order($user, 200),
]);

$productRepo = $this->createMock(ProductRepositoryInterface::class);
$productRepo->method('findTopSelling')->willReturn(['Widget', 'Gadget']);

$service = new ReportService($orderRepo, $productRepo);
$summary = $service->generateMonthlySummary(2024, 1);

$this->assertEquals(2, $summary->getOrderCount());
$this->assertEquals(300, $summary->getTotalRevenue());
```

**Integracioni test** — proverite da li upiti rade sa pravom bazom podataka:

```php
self::bootKernel();
$service = static::getContainer()->get(ReportService::class);
$summary = $service->generateMonthlySummary(2024, 1);
$this->assertGreaterThan(0, $summary->getOrderCount());
```

### Zaključak

Da biste mockovali Doctrine repozitorijume, kreirajte mockove klase repozitorijuma ili interfejsa sa PHPUnit-ovim `createMock()`. Mockujte metode `find`, `findBy`, `findOneBy` i prilagođene metode upita da vraćaju unapred definisane podatke. Za `persist`/`flush`, mockujte `EntityManagerInterface` i koristite `expects()` za verifikovanje poziva. U integracionim testovima, koristite `KernelTestCase` sa pravom test bazom podataka i `DAMADoctrineTestBundle` za rollback transakcije. Najčistiji pristup je definisanje interfejsa repozitorijuma — mockujte ih u unit testovima, testirajte Doctrine implementacije u integracionim testovima.

> Videti takođe: [Kako mockirati konekciju sa bazom podataka](mocking_database_connection.sr.md), [Symfony podešavanja za testiranje](symfony_testing_settings.sr.md)
