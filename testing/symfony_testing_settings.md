When you write tests for a Symfony application, you need specific settings to separate the test environment from the development and production environments.

### .env.test File

Symfony loads `.env.test` automatically when `APP_ENV=test`. This file overrides values from `.env`:

```dotenv
# .env.test
APP_ENV=test
APP_SECRET=test_secret_12345

# Use a separate database for tests
DATABASE_URL="mysql://root:root@127.0.0.1:3306/myapp_test?serverVersion=8.0"

# Disable email sending in tests
MAILER_DSN=null://null
```

Symfony loads environment files in this order:
1. `.env` — base values
2. `.env.test` — test-specific overrides
3. `.env.test.local` — local overrides (not committed to git)

### phpunit.xml.dist Configuration

PHPUnit configuration lives in `phpunit.xml.dist` at the project root:

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

### Bootstrap File

The `tests/bootstrap.php` file prepares the test environment:

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

### Test-Specific Service Configuration

You can override services only for the test environment in `config/services_test.yaml`:

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

### Kernel Boot and Test Client

Symfony provides `KernelTestCase` and `WebTestCase` for integration and functional tests:

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

For functional tests with HTTP requests:

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

### Test Database Setup

Create and populate the test database before running tests:

```bash
# Create test database
php bin/console doctrine:database:create --env=test

# Run migrations
php bin/console doctrine:migrations:migrate --env=test --no-interaction

# Load fixtures (if needed)
php bin/console doctrine:fixtures:load --env=test --no-interaction
```

You can automate this in a Makefile or CI pipeline:

```makefile
test-setup:
	php bin/console doctrine:database:drop --env=test --force --if-exists
	php bin/console doctrine:database:create --env=test
	php bin/console doctrine:migrations:migrate --env=test --no-interaction

test: test-setup
	php bin/phpunit
```

### DAMADoctrineTestBundle

For faster tests, use `DAMADoctrineTestBundle`. It wraps each test in a database transaction and rolls it back after the test, so the database stays clean without re-creating it:

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

### Real Scenario

You join a Symfony project and need to set up tests. Here is a typical setup process:

1. Create `.env.test` with a separate database URL
2. Configure `phpunit.xml.dist` with test suites and `APP_ENV=test`
3. Create `tests/bootstrap.php` to load environment variables
4. Add `services_test.yaml` to override services (e.g., replace mailer with a fake)
5. Install `DAMADoctrineTestBundle` for transaction rollback between tests
6. Create a Makefile target that drops, creates, and migrates the test database
7. Organize tests in `tests/Unit/`, `tests/Integration/`, `tests/Functional/`

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

### Conclusion

Symfony testing settings include: `.env.test` for environment variables, `phpunit.xml.dist` for PHPUnit configuration, `tests/bootstrap.php` to load the environment, `services_test.yaml` to override services, and the test database setup. The `KernelTestCase` gives access to the container, `WebTestCase` provides an HTTP client, and `DAMADoctrineTestBundle` keeps the database clean by rolling back transactions after each test.
