An interface in PHP defines a contract — it tells a class **what methods it must have**, but not **how** those methods should work. Think of it as a list of rules that a class promises to follow.

### Basic Interface

```php
interface PaymentMethodInterface
{
    public function pay(float $amount): bool;
    public function refund(float $amount): bool;
}
```

Any class that implements this interface **must** define both `pay()` and `refund()` methods:

```php
class CreditCardPayment implements PaymentMethodInterface
{
    public function pay(float $amount): bool
    {
        // Process credit card payment
        return true;
    }

    public function refund(float $amount): bool
    {
        // Process credit card refund
        return true;
    }
}
```

If you forget to implement any method, PHP will throw a fatal error.

### Why Use Interfaces?

- **Consistency**: All classes that implement the interface have the same methods.
- **Type Hinting**: You can type-hint the interface instead of a specific class, making your code flexible.
- **Multiple Implementations**: Different classes can implement the same interface in different ways.

```php
function processPayment(PaymentMethodInterface $method, float $amount): void
{
    $method->pay($amount); // Works with ANY class that implements the interface
}

processPayment(new CreditCardPayment(), 100.00);
processPayment(new PaypalPayment(), 50.00);
```

### Interface Rules

- All methods in an interface must be **public**.
- An interface **cannot** have properties (only constants are allowed).
- An interface **cannot** have method bodies (before PHP 8.0).
- A class **can** implement multiple interfaces.

```php
class OnlineStore implements PaymentMethodInterface, LoggableInterface, NotifiableInterface
{
    // Must implement ALL methods from all three interfaces
}
```

### Interface Constants

Interfaces can define constants. These constants cannot be overridden by implementing classes.

```php
interface StatusInterface
{
    const ACTIVE = 'active';
    const INACTIVE = 'inactive';
}

class User implements StatusInterface
{
    public function getStatus(): string
    {
        return self::ACTIVE; // 'active'
    }
}
```

### Inheritance of Interfaces

Interfaces can **extend** other interfaces, just like classes extend other classes. This is called interface inheritance.

```php
interface VehicleInterface
{
    public function start(): void;
    public function stop(): void;
}

interface ElectricVehicleInterface extends VehicleInterface
{
    public function chargeBattery(): void;
}
```

Now any class implementing `ElectricVehicleInterface` must have **three** methods: `start()`, `stop()`, and `chargeBattery()`.

#### Multiple Interface Inheritance

Unlike classes, interfaces **can** extend multiple interfaces at once:

```php
interface FlyableInterface
{
    public function fly(): void;
}

interface SwimmableInterface
{
    public function swim(): void;
}

interface DuckInterface extends FlyableInterface, SwimmableInterface
{
    public function quack(): void;
}

// A class implementing DuckInterface must have fly(), swim(), and quack()
class Duck implements DuckInterface
{
    public function fly(): void { /* ... */ }
    public function swim(): void { /* ... */ }
    public function quack(): void { /* ... */ }
}
```

### Real Scenario

You are building a notification system. Different channels (email, SMS, Slack) send messages differently, but they all must have the same method:

```php
interface NotificationChannelInterface
{
    public function send(string $recipient, string $message): bool;
}

class EmailChannel implements NotificationChannelInterface
{
    public function send(string $recipient, string $message): bool
    {
        return mail($recipient, 'Notification', $message);
    }
}

class SmsChannel implements NotificationChannelInterface
{
    public function send(string $recipient, string $message): bool
    {
        // Use Twilio API to send SMS
        return true;
    }
}

class NotificationService
{
    /** @param NotificationChannelInterface[] $channels */
    public function notify(array $channels, string $recipient, string $message): void
    {
        foreach ($channels as $channel) {
            $channel->send($recipient, $message);
        }
    }
}
```

By using the interface, you can add new channels (Telegram, push notifications) without changing the `NotificationService` class.

### Conclusion

Interfaces define a contract of methods that classes must implement. They provide consistency and flexibility through type hinting. Interfaces can extend other interfaces (even multiple ones), which allows building complex contracts from simpler ones. This is one of the main tools for achieving polymorphism in PHP.
