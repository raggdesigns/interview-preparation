Priprema okruženja za testiranje znači podešavanje svega što su vašim testovima potrebno za pouzdano, reproduktivno i nezavisno pokretanje od razvojnih ili produkcijskih okruženja.

### Ključni aspekti okruženja za testiranje

1. **Odvojena konfiguracija** — drugačija baza podataka, drugačiji API ključevi
2. **Izolovano stanje** — svaki test počinje iz poznatog stanja
3. **Reproduktivno** — svaki programer može pokrenuti testove i dobiti iste rezultate
4. **Brzo podešavanje** — priprema okruženja bi trebalo da bude brza

### Konfiguracija okruženja

Koristiti zasebni `.env.test` fajl za podešavanja specifična za testiranje:

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

### Podešavanje test baze podataka

Test baza podataka mora biti kreirana i popunjena pre pokretanja testova:

```bash
# Full setup from scratch
php bin/console doctrine:database:drop --env=test --force --if-exists
php bin/console doctrine:database:create --env=test
php bin/console doctrine:schema:create --env=test
# OR
php bin/console doctrine:migrations:migrate --env=test --no-interaction
```

#### Fixtures

Učitati konzistentne testne podatke korišćenjem fixtures:

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

### Upravljanje stanjem baze podataka

Svaki test mora početi iz čistog, poznatog stanja. Postoje tri pristupa:

#### 1. Rollback transakcije (najbrži)

Koristiti `DAMADoctrineTestBundle` — svaki test se izvršava unutar transakcije koja se vraca:

```xml
<!-- phpunit.xml.dist -->
<extensions>
    <extension class="DAMA\DoctrineTestBundle\PHPUnit\PHPUnitExtension"/>
</extensions>
```

Prednosti: Veoma brzo, nema potrebe za čišćenjem podataka
Mane: Ne radi sa više konekcija na bazu podataka ili kada kod interno koristi transakcije

#### 2. Pražnjenje pre svakog testa

Resetovati bazu podataka na početku svakog testa:

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

Prednosti: Uvek čisto stanje
Mane: Sporo za velike skupove podataka

#### 3. Rekreiranje šeme (najčistije ali najsporije)

Brisanje i rekreiranje celokupne baze podataka izmedju test suitova:

```bash
php bin/console doctrine:schema:drop --env=test --force
php bin/console doctrine:schema:create --env=test
php bin/console doctrine:fixtures:load --env=test --no-interaction
```

### Makefile za podešavanje testiranja

Kreirati `Makefile` za automatizovanje pripreme okruženja:

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

### Docker podešavanje za testove

Koristiti Docker za osiguravanje konzistentnog okruženja za testiranje na svim mašinama:

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

Pokrenuti testove u Docker-u:

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

### Struktura direktorijuma za testove

Organizovati testove da odražavaju izvorni kod:

```
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

### Čišćenje izmedju testova

Osigurati da svaki test ne ostavlja nuspojave:

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

### Realni scenario

Pridružujete se projektu i treba da pokrenete testove lokalno. Evo tipičnog prvog podešavanja:

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

### Kontrolna lista za okruženje za testiranje

| Aspekt | Šta podesiti |
|--------|-------------|
| Konfiguracija | `.env.test`, `phpunit.xml.dist`, `tests/bootstrap.php` |
| Baza podataka | Zasebna test baza, migracije, fixtures |
| Upravljanje stanjem | DAMADoctrineTestBundle ili ručno pražnjenje |
| Eksterni servisi | Mock ili koristiti sandbox endpoint-e |
| Fajl sistem | Koristiti privremene direktorijume, čistiti u `tearDown()` |
| CI/CD | GitHub Actions / GitLab CI sa servisnim kontejnerima |
| Docker | `docker-compose.test.yml` za konzistentno okruženje |
| Automatizacija | `Makefile` sa targetima: `test-db`, `test`, `test-coverage` |

### Zaključak

Priprema okruženja za testiranje podrazumeva: odvojenu konfiguraciju (`.env.test`), namjensku test bazu podataka sa fixtures, upravljanje stanjem izmedju testova (rollback transakcije sa DAMADoctrineTestBundle je najbrži), Docker za konzistentnost na svim mašinama i CI/CD pipeline za automatizovano testiranje pri svakom push-u. Cilj je da svaki programer može da klonira repozitorijum, pokrene jednu ili dve komande i da svi testovi odmah prolaze.

> Videti takodje: [Symfony podešavanja za testiranje](symfony_testing_settings.sr.md), [Kako mockovati konekciju na bazu podataka](mocking_database_connection.sr.md)
