# Autowiring Two Instances of the Same Service in Symfony

In Symfony, you might encounter a situation where you need to autowire two instances of the same service into a class
but with different configurations. This scenario can be handled by defining service aliases and using argument binding.

## How It Works

Symfony's autowiring system is smart enough to match your service arguments with the services defined in
your `services.yaml` by their names. When you define service aliases with specific names and then use those names as
your constructor parameters, Symfony understands that you are referring to those specific instances.

## Detailed Explanation

When you define aliases in your `services.yaml` like so:

```yaml
services:
  monolog.logger.order:
    class: Monolog\Logger
    arguments: ['order']
    tags:
      - { name: 'monolog.logger', channel: 'order' }

  monolog.logger.user:
    class: Monolog\Logger
    arguments: ['user']
    tags:
      - { name: 'monolog.logger', channel: 'user' }

  Psr\Log\LoggerInterface $orderLogger:
    alias: 'monolog.logger.order'

  Psr\Log\LoggerInterface $userLogger:
    alias: 'monolog.logger.user'
```

You're telling Symfony's Dependency Injection Container that when a `LoggerInterface` type-hinted constructor argument
named `$orderLogger` is encountered, it should inject the service known as `monolog.logger.order`. Similarly,
for `$userLogger`, it injects `monolog.logger.user`.

This naming convention allows you to have different configurations for `order` and `user` logging channels and use them
accordingly in your services.

# Understanding the Role of the Alias in Service Constructors in Symfony

When you autowire services in Symfony, aliases play a crucial role in specifying which instance of a service should be
injected into your classes, especially when you have multiple instances of the same interface. Let's clarify what an
alias represents and how it is used in the context of a service constructor.

## Alias: A Pointer to a Specific Service Instance

In the service configuration, when you define an alias, you are essentially giving a name to a specific service
instance. This name can then be used to reference this specific instance elsewhere in your Symfony application,
particularly when autowiring services.

In this configuration, `$orderLogger` and `$userLogger` are aliases pointing to specific logger service instances
configured to log to different channels (`order` and `user` respectively).

## How Aliases Are Resolved in Constructor Injection

When you type-hint `LoggerInterface` in your service's constructor and name the parameters `$orderLogger`
and `$userLogger`, Symfony's autowiring system looks up the aliases defined in the service configuration that match
these parameter names. It then injects the services these aliases point to into the constructor.

```php
public function __construct(LoggerInterface $orderLogger, LoggerInterface $userLogger)
{
    $this->orderLogger = $orderLogger;
    $this->userLogger = $userLogger;
}
```

Here's what happens behind the scenes:

- Symfony sees the `LoggerInterface $orderLogger` argument in the constructor.
- It looks for an alias or service definition that matches this name (`$orderLogger`).
- Upon finding the alias `Psr\Log\LoggerInterface $orderLogger` in `services.yaml`, it resolves this alias to the
  service it points to (`monolog.logger.order`).
- The instance of `LoggerInterface` configured for `order` logging is injected as `$orderLogger`.
- The same process applies to `$userLogger`, resulting in the `user` logger instance being injected.

## The Role of the Alias

The alias effectively serves as a bridge between the service configuration and the service's constructor, allowing you
to inject specific instances of a service based on the constructor parameter names. This is particularly useful for
distinguishing between multiple instances of the same interface.

## Conclusion

Understanding the role of aliases in Symfony helps clarify how specific service instances are selected and injected into
your classes. This mechanism provides a powerful and flexible way to manage service dependencies in a Symfony
application.

## Example Service Using Different Loggers

```php
namespace App\Service;

use Psr\Log\LoggerInterface;

class UserService
{
    private $orderLogger;
    private $userLogger;

    public function __construct(LoggerInterface $orderLogger, LoggerInterface $userLogger)
    {
        $this->orderLogger = $orderLogger;
        $this->userLogger = $userLogger;
    }

    public function logOrderActivity(string $message): void
    {
        // This uses the order logger instance
        $this->orderLogger->info($message);
    }

    public function logUserActivity(string $message): void
    {
        // This uses the user logger instance
        $this->userLogger->info($message);
    }
}
```

In this setup, `$orderLogger` and `$userLogger` are distinct instances of `LoggerInterface` that are automatically
resolved and injected by Symfony based on the naming convention used both in the service configuration and the
constructor arguments of your service class.

## Conclusion

This mechanism of differentiating services by their constructor argument names and matching them with service aliases is
a powerful feature of Symfony's autowiring system, allowing for flexible and readable service configurations.