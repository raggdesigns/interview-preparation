When testing services that depend on Doctrine repositories, you need to decide between mocking the repository (unit tests) and using a real database (integration tests). Both approaches are valuable for different purposes.

### Mocking EntityRepository in Unit Tests

The simplest case — your service depends on a Doctrine repository:

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

Mock both the repository and the entity manager:

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

### Mocking Custom Repository Methods

When your repository has custom query methods:

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

Mock the custom methods the same way:

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

### Mocking EntityManager for Persist/Flush

When your code creates new entities:

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

### Integration Tests with KernelTestCase

For testing that the actual Doctrine queries work correctly, use integration tests with a real test database:

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

### Using Fixtures with Doctrine

For complex test data, use fixtures:

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

Load fixtures in tests:

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

### Interface-Based Approach

For cleaner separation, define a repository interface:

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

Now services depend on the interface, which is easy to mock:

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

### Unit vs Integration Test Summary

| What to test | Test type | How |
|-------------|-----------|-----|
| Service logic using repository | Unit test | Mock the repository |
| Repository query results | Integration test | Real database + KernelTestCase |
| Entity persist/flush behavior | Integration test | Real database + transaction rollback |
| Complex DQL/QueryBuilder | Integration test | Real database with seeded data |

### Real Scenario

You have a reporting service that needs to aggregate order data:

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

**Unit test** — mock the repositories:

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

**Integration test** — verify the queries work with a real database:

```php
self::bootKernel();
$service = static::getContainer()->get(ReportService::class);
$summary = $service->generateMonthlySummary(2024, 1);
$this->assertGreaterThan(0, $summary->getOrderCount());
```

### Conclusion

To mock Doctrine repositories, create mocks of the repository class or interface with PHPUnit's `createMock()`. Mock the `find`, `findBy`, `findOneBy`, and custom query methods to return predefined data. For `persist`/`flush`, mock the `EntityManagerInterface` and use `expects()` to verify calls. In integration tests, use `KernelTestCase` with a real test database and `DAMADoctrineTestBundle` for transaction rollback. The cleanest approach is to define repository interfaces — mock them in unit tests, test the Doctrine implementations in integration tests.

> See also: [How to mock connection to a database](mocking_database_connection.md), [Symfony settings for testing](symfony_testing_settings.md)
