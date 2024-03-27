
# Autoconfigure in Symfony

Autoconfigure is a feature in Symfony that automatically configures services based on their interfaces and traits. This feature simplifies service configuration by automatically applying tags and method calls needed for the Symfony components and other bundles to work correctly, based on the characteristics of your services.

## How It Works

When enabled, autoconfiguration automatically tags services with specific Symfony tags if they implement certain interfaces or use certain traits. This reduces the need for explicit configuration and makes service definitions cleaner and more concise.

## Enabling Autoconfigure

Autoconfigure can be enabled globally or per service in the `services.yaml` file. Globally enabling it applies autoconfiguration to all services within its scope.

```yaml
services:
    _defaults:
        autowire: true
        autoconfigure: true # Enables autoconfigure globally
```

## Example: Event Listener Autoconfiguration

Consider an event listener that listens to `kernel.request` events:

```php
namespace App\EventListener;

use Symfony\Component\HttpKernel\Event\RequestEvent;

class MyRequestListener
{
    public function onKernelRequest(RequestEvent $event)
    {
        // Handle the request event
    }
}
```

Without autoconfiguration, you would need to manually tag this service as an event listener in `services.yaml`:

```yaml
services:
    App\EventListener\MyRequestListener:
        tags:
            - { name: 'kernel.event_listener', event: 'kernel.request', method: 'onKernelRequest' }
```

With autoconfiguration enabled, simply implementing an interface or using a trait that Symfony recognizes as an event listener is enough. Symfony will automatically tag the service appropriately, eliminating the need for explicit configuration.

## Example: Autowiring and Autoconfiguring Commands

Symfony commands can also benefit from autowiring and autoconfiguration. By extending the base `Command` class and enabling autoconfigure, Symfony automatically registers the command and makes it available to the console.

```php
namespace App\Command;

use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;

class MyCommand extends Command
{
    protected static $defaultName = 'app:my-command';

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        // Command logic
        return Command::SUCCESS;
    }
}
```

In `services.yaml`, the service definition for this command can remain minimal:

```yaml
services:
    App\Command\MyCommand: ~
```

Autoconfiguration takes care of setting up the command without needing explicit tags.

## Conclusion

Autoconfigure simplifies the setup of Symfony applications by reducing boilerplate service configuration. It works seamlessly with autowiring, further enhancing the developer experience by focusing on conventions over configuration.

