Kada pišete testove za Symfony aplikaciju, potrebna su vam specifična podešavanja za razdvajanje okruženja za testiranje od razvojnih i produkcijskih okruženja.

### Fajl .env.test

Symfony automatski učitava `.env.test` kada je `APP_ENV=test`. Ovaj fajl nadjačava vrednosti iz `.env`:

```dotenv
# .env.test
APP_ENV=test
APP_SECRET=test_secret_12345

# Use a separate database for tests
DATABASE_URL="mysql://root:root@127.0.0.1:3306/myapp_test?serverVersion=8.0"

# Disable email sending in tests
MAILER_DSN=null://null
```

Symfony učitava fajlove okruženja sledećim redosledom:
1. `.env` — osnovne vrednosti
2. `.env.test` — nadjačavanja specifična za testiranje
3. `.env.test.local` — lokalna nadjačavanja (nije commitovano u git)

### Konfiguracija phpunit.xml.dist

PHPUnit konfiguracija se nalazi u `phpunit.xml.dist` u korenu projekta:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
         bootstrap="tests/bootstrap.php"
         colors="true"
         executionOrder="depends,defects"
         failOnRisky="true"
         failOnWarning="true"
>
    <php>
        <ini name="display_errors" value="1"/>
        <ini name="error_reporting" value="-1"/>
        <!-- Force test environment -->
        <server name="APP_ENV" value="test" force="true"/>
        <server name="SHELL_VERBOSITY" value="-1"/>
        <!-- Use .env.test instead of Dotenv -->
        <server name="SYMFONY_DOTENV_VARS" value=""/>
    </php>

    <testsuites>
        <testsuite name="Unit">
            <directory>tests/Unit</directory>
        </testsuite>
        <testsuite name="Integration">
            <directory>tests/Integration</directory>
        </testsuite>
        <testsuite name="Functional">
            <directory>tests/Functional</directory>
        </testsuite>
    </testsuites>

    <coverage>
        <include>
            <directory suffix=".php">src</directory>
        </include>
    </coverage>
</phpunit>
```

### Bootstrap fajl

Fajl `tests/bootstrap.php` priprema okruženje za testiranje:

```php
<?php
// tests/bootstrap.php

use Symfony\Component\Dotenv\Dotenv;

require dirname(__DIR__) . '/vendor/autoload.php';

if (file_exists(dirname(__DIR__) . '/config/bootstrap.php')) {
    require dirname(__DIR__) . '/config/bootstrap.php';
} elseif (method_exists(Dotenv::class, 'bootEnv')) {
    (new Dotenv())->bootEnv(dirname(__DIR__) . '/.env');
}
```

### Konfiguracija servisa specifična za testiranje

Možete nadjačati servise samo za okruženje testiranja u `config/services_test.yaml`:

```yaml
# config/services_test.yaml
services:
    # Make private services public for testing
    App\Service\PaymentGateway:
        public: true

    # Replace real service with a fake one
    App\Service\MailerInterface:
        class: App\Tests\Stub\FakeMailer

    # Make all services public (useful but not recommended for large apps)
    _defaults:
        public: true
```

### Pokretanje kernela i test klijent

Symfony pruža `KernelTestCase` i `WebTestCase` za integracione i funkcionalne testove:

```php
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;

class UserServiceTest extends KernelTestCase
{
    public function testFindUser(): void
    {
        // Boot the Symfony kernel with test environment
        self::bootKernel();

        // Access the service container
        $container = static::getContainer();

        // Get any service (including private ones via test container)
        $userService = $container->get(UserService::class);

        $user = $userService->findByEmail('test@example.com');
        $this->assertNotNull($user);
    }
}
```

Za funkcionalne testove sa HTTP zahtevima:

```php
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;

class ProductControllerTest extends WebTestCase
{
    public function testProductList(): void
    {
        // Create a test client (test browser)
        $client = static::createClient();

        // Make a request
        $client->request('GET', '/api/products');

        $this->assertResponseIsSuccessful();
        $this->assertResponseHeaderSame('content-type', 'application/json');

        $data = json_decode($client->getResponse()->getContent(), true);
        $this->assertNotEmpty($data);
    }

    public function testCreateProduct(): void
    {
        $client = static::createClient();

        $client->request('POST', '/api/products', [], [], [
            'CONTENT_TYPE' => 'application/json',
        ], json_encode([
            'name' => 'Test Product',
            'price' => 29.99,
        ]));

        $this->assertResponseStatusCodeSame(201);
    }
}
```

### Podešavanje test baze podataka

Kreirati i popuniti test bazu podataka pre pokretanja testova:

```bash
# Create test database
php bin/console doctrine:database:create --env=test

# Run migrations
php bin/console doctrine:migrations:migrate --env=test --no-interaction

# Load fixtures (if needed)
php bin/console doctrine:fixtures:load --env=test --no-interaction
```

Ovo možete automatizovati u Makefile-u ili CI pipeline-u:

```makefile
test-setup:
	php bin/console doctrine:database:drop --env=test --force --if-exists
	php bin/console doctrine:database:create --env=test
	php bin/console doctrine:migrations:migrate --env=test --no-interaction

test: test-setup
	php bin/phpunit
```

### DAMADoctrineTestBundle

Za brže testove, koristite `DAMADoctrineTestBundle`. On obmotava svaki test u transakciju baze podataka i vraca je posle testa, tako da baza ostaje čista bez ponovnog kreiranja:

```xml
<!-- phpunit.xml.dist -->
<extensions>
    <extension class="DAMA\DoctrineTestBundle\PHPUnit\PHPUnitExtension"/>
</extensions>
```

```yaml
# config/packages/test/dama_doctrine_test.yaml
dama_doctrine_test:
    enable_static_connection: true
    enable_static_meta_data_cache: true
    enable_static_query_cache: true
```

### Realni scenario

Pridružujete se Symfony projektu i treba da podesite testove. Evo tipičnog procesa podešavanja:

1. Kreirati `.env.test` sa zasebnim URL-om baze podataka
2. Konfigurisati `phpunit.xml.dist` sa test suitovima i `APP_ENV=test`
3. Kreirati `tests/bootstrap.php` za učitavanje promenljivih okruženja
4. Dodati `services_test.yaml` za nadjačavanje servisa (npr. zamena mailer-a lažnim)
5. Instalirati `DAMADoctrineTestBundle` za rollback transakcija između testova
6. Kreirati Makefile target koji briše, kreira i migrira test bazu podataka
7. Organizovati testove u `tests/Unit/`, `tests/Integration/`, `tests/Functional/`

```
tests/
├── bootstrap.php
├── Unit/
│   └── Service/
│       └── PriceCalculatorTest.php
├── Integration/
│   └── Repository/
│       └── UserRepositoryTest.php
└── Functional/
    └── Controller/
        └── ProductControllerTest.php
```

### Zaključak

Symfony podešavanja za testiranje uključuju: `.env.test` za promenljive okruženja, `phpunit.xml.dist` za PHPUnit konfiguraciju, `tests/bootstrap.php` za učitavanje okruženja, `services_test.yaml` za nadjačavanje servisa i podešavanje test baze podataka. `KernelTestCase` pruža pristup kontejneru, `WebTestCase` pruža HTTP klijent, a `DAMADoctrineTestBundle` čuva bazu čistom rollback-om transakcija posle svakog testa.
