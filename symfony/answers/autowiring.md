
# Autowiring in Symfony

Autowiring in Symfony is a feature that allows you to automatically manage your service dependencies by type-hinting them in your service's constructor. Symfony's Dependency Injection Container (DIC) will automatically pass the correct services into your class without needing to manually define services and their arguments in your service configuration files. This significantly reduces the amount of configuration required to set up a Symfony application, making it faster and easier to develop.

## Example 1: Basic Autowiring

Suppose you have a `MailerService` that depends on a `LoggerInterface` to log messages.

```php
namespace App\Service;

use Psr\Log\LoggerInterface;

class MailerService
{
    private $logger;

    public function __construct(LoggerInterface $logger)
    {
        $this->logger = $logger;
    }

    public function sendEmail($message)
    {
        // Logic to send email
        $this->logger->info("Email sent: " + $message);
    }
}
```

With autowiring, you can simply type-hint `LoggerInterface` in the `MailerService` constructor, and Symfony will automatically inject the `LoggerInterface` instance defined in the service container.

## Example 2: Autowiring with Configuration

To further control how your services are wired, you can use Symfony's service configuration files (e.g., `services.yaml`). Here, you can define services and specify autowiring and autoconfiguration:

```yaml
services:
    _defaults:
        autowire: true
        autoconfigure: true

    App\Service\MailerService: ~
```

With these settings, the `MailerService` will automatically get the necessary `LoggerInterface` injected, and it's also automatically registered as a service in the container due to the `_defaults` configuration.

## Example 3: Autowiring Custom Classes

If you have custom classes that aren't interfaces or widely recognized classes, you can still use autowiring by properly type-hinting them. Suppose you have a custom `OrderProcessor` class:

```php
namespace App\Service;

class OrderProcessor
{
    private $mailerService;

    public function __construct(MailerService $mailerService)
    {
        $this->mailerService = $mailerService;
    }

    public function processOrder($order)
    {
        // Logic to process the order
        $this->mailerService->sendEmail("Order processed: " + $order);
    }
}
```

By type-hinting `MailerService` in the `OrderProcessor` constructor and ensuring `MailerService` is properly defined as a service in `services.yaml`, Symfony's autowiring feature will automatically inject the `MailerService` into the `OrderProcessor`.
