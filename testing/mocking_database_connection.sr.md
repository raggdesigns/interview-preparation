Kada testirate kod koji radi sa bazom podataka, obično ne želite da se povežete sa pravom bazom podataka u unit testovima. Umesto toga, mockujete konekciju sa bazom podataka kako bi testovi bili brzi i nezavisni od eksterne infrastrukture.

### Zašto mockirati konekciju sa bazom podataka

- **Brzina** — upiti prema bazi podataka su spori u poređenju sa operacijama u memoriji
- **Izolacija** — testovi ne bi trebalo da zavise od stanja baze podataka
- **Bez potrebne infrastrukture** — testovi mogu da se izvršavaju u CI bez servera baze podataka
- **Predvidivi rezultati** — mock vraća tačno ono što vi definišete

### Mockovanje PDO-a

PDO je standardni PHP interfejs za bazu podataka. Možete ga mockirati sa PHPUnit-om:

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

Repozitorijum koji se testira:

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

### Mockovanje Doctrine DBAL konekcije

U Symfony aplikacijama, često radite sa Doctrine-ovim DBAL `Connection`-om umesto sirovog PDO-a:

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

### In-Memory SQLite baza podataka

Za integracione testove gde je potrebno da se izvrši pravi SQL (join-ovi, podupiti), koristite in-memory SQLite bazu podataka. Brza je i ne zahteva nikakav eksterni servis:

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

### Pattern sa rollback-om transakcije

Za testove koji koriste pravu konekciju sa bazom podataka (npr. MySQL u integracionim testovima), omotajte svaki test u transakciju i izvršite rollback nakon toga:

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

### Skrivanje pristupa bazi podataka iza interfejsa

Najbolja praksa je definisanje interfejsa repozitorijuma i njegovo mockovanje u unit testovima. Na ovaj način, ne morate uopšte mockirati PDO ili DBAL:

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

### Koji pristup koristiti

| Scenario | Pristup |
|----------|---------|
| Unit test za servis | Mockujte interfejs repozitorijuma |
| Unit test za repozitorijum | Mockujte PDO/Connection |
| Integracioni test sa pravim SQL-om | In-memory SQLite ili test baza sa rollback-om |
| Symfony integracioni test | KernelTestCase + DAMADoctrineTestBundle |

### Realni scenario

Imate analytics servis koji upituje bazu podataka za podatke o prodaji:

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

Za **unit test**, mockujte konekciju:

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

Za **integracioni test**, koristite pravu bazu podataka da proverite da li je SQL ispravan:

```php
// Uses real test database with seeded data
$service = static::getContainer()->get(AnalyticsService::class);
$top = $service->getTopProducts(5);
$this->assertNotEmpty($top);
$this->assertGreaterThanOrEqual($top[1]['total_sold'], $top[0]['total_sold']);
```

### Zaključak

Da biste mockovali konekciju sa bazom podataka u testovima, možete mockirati PDO ili Doctrine DBAL `Connection` za brze unit testove, koristiti in-memory SQLite za lagane integracione testove, ili koristiti pravu test bazu podataka sa rollback-om transakcije za pune integracione testove. Najbolja praksa je da sakrijete pristup bazi podataka iza interfejsa repozitorijuma — tada unit testovi mockuju interfejs, a samo integracioni testovi zahtevaju pravu bazu podataka.

> Videti takođe: [Symfony podešavanja za testiranje](symfony_testing_settings.sr.md), [Kako mockirati Doctrine upite repozitorijuma](mocking_doctrine_repositories.sr.md)
