Preparing a test environment means setting up everything your tests need to run reliably, reproducibly, and independently from your development or production environments.

### Key Aspects of Test Environment

1. **Separate configuration** — different database, different API keys
2. **Isolated state** — each test starts from a known state
3. **Reproducible** — any developer can run tests and get the same results
4. **Fast setup** — preparing the environment should be quick

### Environment Configuration

Use a separate `.env.test` file for test-specific settings:

```dotenv
# .env.test
APP_ENV=test
APP_DEBUG=1

# Separate test database
DATABASE_URL="mysql://root:root@127.0.0.1:3306/myapp_test"

# Disable real services
MAILER_DSN=null://null
PAYMENT_GATEWAY_URL=https://sandbox.payment.com
REDIS_URL=redis://localhost:6379/1    # Different Redis DB index

# Test-specific secrets
APP_SECRET=test_secret_not_real
```

### Test Database Setup

The test database must be created and populated before tests run:

```bash
# Full setup from scratch
php bin/console doctrine:database:drop --env=test --force --if-exists
php bin/console doctrine:database:create --env=test
php bin/console doctrine:schema:create --env=test
# OR
php bin/console doctrine:migrations:migrate --env=test --no-interaction
```

#### Fixtures

Load consistent test data using fixtures:

```php
// src/DataFixtures/TestFixtures.php
class TestFixtures extends Fixture
{
    public function load(ObjectManager $manager): void
    {
        // Create users
        $admin = new User();
        $admin->setEmail('admin@test.com');
        $admin->setRoles(['ROLE_ADMIN']);
        $admin->setPassword('$2y$13$hashed_password');
        $manager->persist($admin);
        
        $user = new User();
        $user->setEmail('user@test.com');
        $user->setRoles(['ROLE_USER']);
        $user->setPassword('$2y$13$hashed_password');
        $manager->persist($user);
        
        // Create products
        for ($i = 1; $i <= 10; $i++) {
            $product = new Product();
            $product->setName("Product $i");
            $product->setPrice($i * 10.00);
            $product->setActive($i <= 8);  // 2 inactive products
            $manager->persist($product);
        }
        
        $manager->flush();
    }
}
```

```bash
php bin/console doctrine:fixtures:load --env=test --no-interaction
```

### Database State Management

Each test must start from a clean, known state. There are three approaches:

#### 1. Transaction Rollback (Fastest)

Use `DAMADoctrineTestBundle` — each test runs inside a transaction that gets rolled back:

```xml
<!-- phpunit.xml.dist -->
<extensions>
    <extension class="DAMA\DoctrineTestBundle\PHPUnit\PHPUnitExtension"/>
</extensions>
```

Pros: Very fast, no data cleanup needed  
Cons: Does not work with multiple database connections or when code uses transactions internally

#### 2. Purge Before Each Test

Reset the database at the start of each test:

```php
protected function setUp(): void
{
    self::bootKernel();
    $em = static::getContainer()->get(EntityManagerInterface::class);
    
    $purger = new ORMPurger($em);
    $purger->purge();
    
    // Reload fixtures
    $loader = new Loader();
    $loader->addFixture(new TestFixtures());
    $executor = new ORMExecutor($em, $purger);
    $executor->execute($loader->getFixtures());
}
```

Pros: Always clean state  
Cons: Slow for large datasets

#### 3. Schema Recreate (Cleanest but Slowest)

Drop and recreate the entire database between test suites:

```bash
php bin/console doctrine:schema:drop --env=test --force
php bin/console doctrine:schema:create --env=test
php bin/console doctrine:fixtures:load --env=test --no-interaction
```

### Makefile for Test Setup

Create a `Makefile` to automate environment preparation:

```makefile
.PHONY: test test-setup test-db test-unit test-integration test-functional

test-setup: test-db
 @echo "Test environment ready"

test-db:
 php bin/console doctrine:database:drop --env=test --force --if-exists
 php bin/console doctrine:database:create --env=test
 php bin/console doctrine:migrations:migrate --env=test --no-interaction
 php bin/console doctrine:fixtures:load --env=test --no-interaction

test-unit:
 php bin/phpunit --testsuite=Unit

test-integration: test-setup
 php bin/phpunit --testsuite=Integration

test-functional: test-setup
 php bin/phpunit --testsuite=Functional

test: test-setup
 php bin/phpunit

test-coverage:
 XDEBUG_MODE=coverage php bin/phpunit --coverage-html coverage/
```

### Docker Setup for Tests

Use Docker to ensure a consistent test environment across all machines:

```yaml
# docker-compose.test.yml
version: '3.8'

services:
  php:
    build:
      context: .
      dockerfile: Dockerfile
    environment:
      APP_ENV: test
      DATABASE_URL: "mysql://root:root@db:3306/myapp_test"
      REDIS_URL: "redis://redis:6379/1"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started

  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: myapp_test
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      timeout: 5s
      retries: 5
    tmpfs:
      - /var/lib/mysql    # Use RAM for speed

  redis:
    image: redis:7-alpine
```

Run tests in Docker:

```bash
docker compose -f docker-compose.test.yml run --rm php bin/phpunit
```

### CI/CD Pipeline (GitHub Actions)

```yaml
# .github/workflows/tests.yml
name: Tests

on: [push, pull_request]

jobs:
  tests:
    runs-on: ubuntu-latest
    
    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: root
          MYSQL_DATABASE: myapp_test
        ports:
          - 3306:3306
        options: --health-cmd="mysqladmin ping" --health-interval=5s --health-timeout=5s --health-retries=5
      
      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          extensions: pdo_mysql, redis
          coverage: xdebug
      
      - name: Install dependencies
        run: composer install --no-interaction --prefer-dist
      
      - name: Setup test database
        env:
          DATABASE_URL: "mysql://root:root@127.0.0.1:3306/myapp_test"
        run: |
          php bin/console doctrine:migrations:migrate --env=test --no-interaction
          php bin/console doctrine:fixtures:load --env=test --no-interaction
      
      - name: Run tests
        env:
          DATABASE_URL: "mysql://root:root@127.0.0.1:3306/myapp_test"
        run: php bin/phpunit --coverage-clover coverage.xml
```

### Test Directory Structure

Organize tests to mirror your source code:

```text
tests/
├── bootstrap.php
├── Unit/                           # No database, no kernel
│   ├── Service/
│   │   ├── PriceCalculatorTest.php
│   │   └── OrderValidatorTest.php
│   └── ValueObject/
│       └── MoneyTest.php
├── Integration/                    # Boots kernel, uses database
│   ├── Repository/
│   │   ├── UserRepositoryTest.php
│   │   └── ProductRepositoryTest.php
│   └── Service/
│       └── PaymentServiceTest.php
└── Functional/                     # Full HTTP requests
    └── Controller/
        ├── ProductControllerTest.php
        └── AuthControllerTest.php
```

### Cleanup Between Tests

Ensure each test leaves no side effects:

```php
class BaseTestCase extends KernelTestCase
{
    protected function setUp(): void
    {
        self::bootKernel();
    }
    
    protected function tearDown(): void
    {
        parent::tearDown();
        
        // Clear file system artifacts
        $uploadDir = self::$kernel->getProjectDir() . '/var/test-uploads';
        if (is_dir($uploadDir)) {
            array_map('unlink', glob("$uploadDir/*"));
        }
        
        // Clear cache if needed
        $cache = static::getContainer()->get('cache.app');
        $cache->clear();
    }
}
```

### Real Scenario

You join a project and need to run tests locally. Here is a typical first-time setup:

```bash
# 1. Clone and install
git clone git@github.com:company/project.git
cd project
composer install

# 2. Copy test environment file
cp .env.test .env.test.local
# Edit .env.test.local with your local database credentials

# 3. Set up test database
make test-db
# OR manually:
php bin/console doctrine:database:create --env=test
php bin/console doctrine:migrations:migrate --env=test --no-interaction
php bin/console doctrine:fixtures:load --env=test --no-interaction

# 4. Run all tests
php bin/phpunit

# 5. Run specific test suite
php bin/phpunit --testsuite=Unit
php bin/phpunit --testsuite=Integration

# 6. Run a single test file
php bin/phpunit tests/Unit/Service/PriceCalculatorTest.php
```

### Checklist for Test Environment

| Aspect | What to set up |
|--------|---------------|
| Configuration | `.env.test`, `phpunit.xml.dist`, `tests/bootstrap.php` |
| Database | Separate test DB, migrations, fixtures |
| State management | DAMADoctrineTestBundle or manual purge |
| External services | Mock or use sandbox endpoints |
| File system | Use temp directories, clean up in `tearDown()` |
| CI/CD | GitHub Actions / GitLab CI with service containers |
| Docker | `docker-compose.test.yml` for consistent environment |
| Automation | `Makefile` with targets: `test-db`, `test`, `test-coverage` |

### Conclusion

Preparing a test environment involves: separate configuration (`.env.test`), a dedicated test database with fixtures, state management between tests (transaction rollback with DAMADoctrineTestBundle is the fastest), Docker for consistency across machines, and CI/CD pipeline for automated testing on every push. The goal is that any developer can clone the repo, run one or two commands, and have all tests passing immediately.

> See also: [Symfony settings for testing](symfony_testing_settings.md), [How to mock connection to a database](mocking_database_connection.md)
