When testing code that works with a database, you usually do not want to connect to a real database in unit tests. Instead, you mock the database connection so tests run fast and do not depend on external infrastructure.

### Why Mock the Database Connection

- **Speed** — database queries are slow compared to in-memory operations
- **Isolation** — tests should not depend on database state
- **No infrastructure needed** — tests can run in CI without a database server
- **Predictable results** — mock returns exactly what you define

### Mocking PDO

PDO is the standard PHP database interface. You can mock it with PHPUnit:

```php
use PHPUnit\Framework\TestCase;

class UserRepositoryTest extends TestCase
{
    public function testFindById(): void
    {
        // Mock PDOStatement
        $stmt = $this->createMock(\PDOStatement::class);
        $stmt->method('execute')->willReturn(true);
        $stmt->method('fetch')->willReturn([
            'id' => 1,
            'name' => 'John',
            'email' => 'john@example.com',
        ]);
        
        // Mock PDO
        $pdo = $this->createMock(\PDO::class);
        $pdo->method('prepare')->willReturn($stmt);
        
        // Test the repository
        $repo = new UserRepository($pdo);
        $user = $repo->findById(1);
        
        $this->assertEquals('John', $user->getName());
        $this->assertEquals('john@example.com', $user->getEmail());
    }
    
    public function testFindByIdReturnsNullWhenNotFound(): void
    {
        $stmt = $this->createMock(\PDOStatement::class);
        $stmt->method('execute')->willReturn(true);
        $stmt->method('fetch')->willReturn(false);  // No row found
        
        $pdo = $this->createMock(\PDO::class);
        $pdo->method('prepare')->willReturn($stmt);
        
        $repo = new UserRepository($pdo);
        $user = $repo->findById(999);
        
        $this->assertNull($user);
    }
}
```

The repository being tested:

```php
class UserRepository
{
    public function __construct(private \PDO $pdo) {}
    
    public function findById(int $id): ?User
    {
        $stmt = $this->pdo->prepare('SELECT * FROM users WHERE id = :id');
        $stmt->execute(['id' => $id]);
        
        $row = $stmt->fetch(\PDO::FETCH_ASSOC);
        if ($row === false) {
            return null;
        }
        
        return new User($row['id'], $row['name'], $row['email']);
    }
}
```

### Mocking Doctrine DBAL Connection

In Symfony applications, you often work with Doctrine's DBAL `Connection` instead of raw PDO:

```php
use Doctrine\DBAL\Connection;
use PHPUnit\Framework\TestCase;

class ReportServiceTest extends TestCase
{
    public function testGetMonthlySales(): void
    {
        $connection = $this->createMock(Connection::class);
        
        // Mock fetchAllAssociative for SELECT queries
        $connection->method('fetchAllAssociative')
            ->willReturn([
                ['month' => '2024-01', 'total' => 15000],
                ['month' => '2024-02', 'total' => 18000],
            ]);
        
        $service = new ReportService($connection);
        $sales = $service->getMonthlySales(2024);
        
        $this->assertCount(2, $sales);
        $this->assertEquals(15000, $sales[0]['total']);
    }
    
    public function testSaveReport(): void
    {
        $connection = $this->createMock(Connection::class);
        
        // Expect an insert call
        $connection->expects($this->once())
            ->method('insert')
            ->with('reports', $this->callback(function (array $data) {
                return $data['title'] === 'Monthly Report'
                    && $data['year'] === 2024;
            }));
        
        $service = new ReportService($connection);
        $service->saveReport('Monthly Report', 2024);
    }
}
```

### In-Memory SQLite Database

For integration tests where you need real SQL to execute (joins, subqueries), use an in-memory SQLite database. It is fast and does not need any external service:

```php
class UserRepositoryIntegrationTest extends TestCase
{
    private \PDO $pdo;
    
    protected function setUp(): void
    {
        // Create in-memory SQLite database
        $this->pdo = new \PDO('sqlite::memory:');
        $this->pdo->setAttribute(\PDO::ATTR_ERRMODE, \PDO::ERRMODE_EXCEPTION);
        
        // Create tables
        $this->pdo->exec('
            CREATE TABLE users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                email TEXT UNIQUE NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        ');
        
        // Insert test data
        $this->pdo->exec("INSERT INTO users (name, email) VALUES ('John', 'john@example.com')");
        $this->pdo->exec("INSERT INTO users (name, email) VALUES ('Jane', 'jane@example.com')");
    }
    
    public function testFindAll(): void
    {
        $repo = new UserRepository($this->pdo);
        $users = $repo->findAll();
        
        $this->assertCount(2, $users);
    }
    
    public function testFindByEmail(): void
    {
        $repo = new UserRepository($this->pdo);
        $user = $repo->findByEmail('john@example.com');
        
        $this->assertNotNull($user);
        $this->assertEquals('John', $user->getName());
    }
}
```

### Transaction Rollback Pattern

For tests that use a real database connection (e.g., MySQL in integration tests), wrap each test in a transaction and roll it back afterwards:

```php
class DatabaseTestCase extends TestCase
{
    protected \PDO $pdo;
    
    protected function setUp(): void
    {
        $this->pdo = new \PDO('mysql:host=localhost;dbname=myapp_test', 'root', '');
        $this->pdo->beginTransaction();
    }
    
    protected function tearDown(): void
    {
        $this->pdo->rollBack();
    }
}

class OrderRepositoryTest extends DatabaseTestCase
{
    public function testCreateOrder(): void
    {
        $repo = new OrderRepository($this->pdo);
        $order = $repo->create(userId: 1, total: 99.99);
        
        $this->assertNotNull($order->getId());
        // After this test, the transaction is rolled back
        // so the order is NOT in the database
    }
}
```

### Wrapping Database Access Behind an Interface

The best practice is to define a repository interface and mock it in unit tests. This way, you do not need to mock PDO or DBAL at all:

```php
interface UserRepositoryInterface
{
    public function findById(int $id): ?User;
    public function findByEmail(string $email): ?User;
    public function save(User $user): void;
}

// In unit tests — mock the interface
class UserServiceTest extends TestCase
{
    public function testGetUserProfile(): void
    {
        $repo = $this->createMock(UserRepositoryInterface::class);
        $repo->method('findById')
             ->with(1)
             ->willReturn(new User(1, 'John', 'john@example.com'));
        
        $service = new UserService($repo);
        $profile = $service->getUserProfile(1);
        
        $this->assertEquals('John', $profile->getName());
    }
}

// In integration tests — test the real implementation
class DoctrineUserRepositoryTest extends KernelTestCase
{
    public function testFindById(): void
    {
        self::bootKernel();
        $repo = static::getContainer()->get(UserRepositoryInterface::class);
        
        $user = $repo->findById(1);
        $this->assertNotNull($user);
    }
}
```

### Which Approach to Use

| Scenario | Approach |
|----------|----------|
| Unit test for a service | Mock the repository interface |
| Unit test for a repository | Mock PDO/Connection |
| Integration test with real SQL | In-memory SQLite or test database with rollback |
| Symfony integration test | KernelTestCase + DAMADoctrineTestBundle |

### Real Scenario

You have an analytics service that queries the database for sales data:

```php
class AnalyticsService
{
    public function __construct(private Connection $connection) {}
    
    public function getTopProducts(int $limit): array
    {
        return $this->connection->fetchAllAssociative(
            'SELECT p.name, SUM(oi.quantity) as total_sold 
             FROM order_items oi 
             JOIN products p ON p.id = oi.product_id 
             GROUP BY p.id 
             ORDER BY total_sold DESC 
             LIMIT ?',
            [$limit]
        );
    }
}
```

For a **unit test**, mock the connection:

```php
$connection = $this->createMock(Connection::class);
$connection->method('fetchAllAssociative')
    ->willReturn([
        ['name' => 'Widget', 'total_sold' => 500],
        ['name' => 'Gadget', 'total_sold' => 300],
    ]);

$service = new AnalyticsService($connection);
$top = $service->getTopProducts(2);
$this->assertEquals('Widget', $top[0]['name']);
```

For an **integration test**, use a real database to verify the SQL is correct:

```php
// Uses real test database with seeded data
$service = static::getContainer()->get(AnalyticsService::class);
$top = $service->getTopProducts(5);
$this->assertNotEmpty($top);
$this->assertGreaterThanOrEqual($top[1]['total_sold'], $top[0]['total_sold']);
```

### Conclusion

To mock a database connection in tests, you can mock PDO or Doctrine DBAL `Connection` for fast unit tests, use in-memory SQLite for lightweight integration tests, or use a real test database with transaction rollback for full integration tests. The best practice is to hide database access behind a repository interface — then unit tests mock the interface, and only integration tests need a real database.

> See also: [Symfony settings for testing](symfony_testing_settings.md), [How to mock Doctrine repository requests](mocking_doctrine_repositories.md)
