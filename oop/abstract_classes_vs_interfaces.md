Both abstract classes and interfaces define contracts that other classes must follow. But they serve different purposes and have different rules.

### Interface — Pure Contract

An interface says **what** a class must do, but never **how**. It defines method signatures without any implementation.

```php
interface PaymentGateway
{
    public function charge(float $amount, string $currency): PaymentResult;
    public function refund(string $transactionId): RefundResult;
}
```

**Rules for interfaces:**
- All methods are public (no private or protected)
- No method bodies (except in PHP 8.0+ with default implementations — rare)
- No properties (only constants)
- A class can implement **multiple** interfaces
- Cannot be instantiated

```php
class StripeGateway implements PaymentGateway
{
    public function charge(float $amount, string $currency): PaymentResult
    {
        // Stripe-specific implementation
        return $this->stripeClient->charges->create([...]);
    }

    public function refund(string $transactionId): RefundResult
    {
        return $this->stripeClient->refunds->create([...]);
    }
}
```

### Abstract Class — Partial Implementation

An abstract class says **what** a class must do AND provides **shared behavior**. It can have both abstract methods (no body) and concrete methods (with body).

```php
abstract class AbstractNotificationSender
{
    // Abstract — subclass MUST implement this
    abstract protected function send(string $recipient, string $message): bool;

    // Concrete — shared logic, same for all subclasses
    public function sendWithRetry(string $recipient, string $message, int $maxRetries = 3): bool
    {
        for ($attempt = 1; $attempt <= $maxRetries; $attempt++) {
            try {
                return $this->send($recipient, $message);
            } catch (SendException $e) {
                if ($attempt === $maxRetries) {
                    throw $e;
                }
                sleep($attempt);  // Exponential-like backoff
            }
        }
        return false;
    }

    // Concrete — shared logging
    protected function log(string $recipient, bool $success): void
    {
        // Common logging logic for all notification types
    }
}
```

**Rules for abstract classes:**
- Can have abstract AND concrete methods
- Can have properties (including private ones)
- Can have constructors
- A class can extend only **one** abstract class (single inheritance)
- Cannot be instantiated
- Methods can be public, protected, or private

```php
class EmailSender extends AbstractNotificationSender
{
    protected function send(string $recipient, string $message): bool
    {
        // Email-specific sending logic
        return $this->mailer->send($recipient, $message);
    }
}

class SmsSender extends AbstractNotificationSender
{
    protected function send(string $recipient, string $message): bool
    {
        // SMS-specific sending logic
        return $this->smsClient->send($recipient, $message);
    }
}
```

Both `EmailSender` and `SmsSender` get `sendWithRetry()` and `log()` for free — no code duplication.

### Key Differences Table

| Feature | Interface | Abstract Class |
|---------|-----------|---------------|
| Method bodies | No (only signatures) | Yes (abstract + concrete) |
| Properties | No (only constants) | Yes |
| Constructor | No | Yes |
| Multiple inheritance | Yes (`implements A, B, C`) | No (only one `extends`) |
| Access modifiers | Only `public` | `public`, `protected`, `private` |
| Purpose | Define a **contract** | Share **common behavior** |
| "Is a" relationship | No | Yes |

### When to Use Interface

Use an interface when:
- You need to define a **contract** that multiple unrelated classes follow
- You need **multiple implementations** that share no code
- You want to enable **dependency injection** and easy testing
- Classes from different hierarchies should be interchangeable

```php
// Different payment providers, no shared code — interface is perfect
interface PaymentGateway
{
    public function charge(float $amount): PaymentResult;
}

class StripeGateway implements PaymentGateway { ... }
class PayPalGateway implements PaymentGateway { ... }
class BankTransferGateway implements PaymentGateway { ... }

// Type-hint against the interface
class OrderService
{
    public function __construct(
        private PaymentGateway $payment  // Any implementation works
    ) {}
}
```

### When to Use Abstract Class

Use an abstract class when:
- Multiple classes share **common behavior** (not just a contract)
- You want to provide **default implementations** that subclasses inherit
- You need to define a **template method** (fixed algorithm with customizable steps)
- The classes are in the same **family** (is-a relationship)

```php
// All repositories share the same find/save logic — abstract class is perfect
abstract class AbstractRepository
{
    public function __construct(
        protected EntityManagerInterface $em
    ) {}

    abstract protected function getEntityClass(): string;

    public function find(int $id): ?object
    {
        return $this->em->find($this->getEntityClass(), $id);
    }

    public function save(object $entity): void
    {
        $this->em->persist($entity);
        $this->em->flush();
    }
}

class UserRepository extends AbstractRepository
{
    protected function getEntityClass(): string
    {
        return User::class;
    }

    // Gets find() and save() for free
    // Can add user-specific methods
    public function findByEmail(string $email): ?User { ... }
}
```

### Combining Both

In real projects, you often combine both — an interface for the contract, and an abstract class for shared behavior:

```php
// Contract
interface LoggerInterface
{
    public function info(string $message, array $context = []): void;
    public function error(string $message, array $context = []): void;
    public function warning(string $message, array $context = []): void;
}

// Shared behavior
abstract class AbstractLogger implements LoggerInterface
{
    abstract protected function writeLog(string $level, string $message, array $context): void;

    public function info(string $message, array $context = []): void
    {
        $this->writeLog('INFO', $message, $context);
    }

    public function error(string $message, array $context = []): void
    {
        $this->writeLog('ERROR', $message, $context);
    }

    public function warning(string $message, array $context = []): void
    {
        $this->writeLog('WARNING', $message, $context);
    }
}

// Concrete implementations
class FileLogger extends AbstractLogger
{
    protected function writeLog(string $level, string $message, array $context): void
    {
        file_put_contents('app.log', "[$level] $message\n", FILE_APPEND);
    }
}

class DatabaseLogger extends AbstractLogger
{
    protected function writeLog(string $level, string $message, array $context): void
    {
        $this->connection->insert('logs', [
            'level' => $level,
            'message' => $message,
        ]);
    }
}
```

Type-hint against `LoggerInterface` in your services. `AbstractLogger` reduces duplication. Concrete classes only implement the storage mechanism.

### Interface vs Abstract Class in PHP 8+

PHP 8+ introduced some features that blur the line slightly:

```php
// PHP 8.0+ — interface with constants and typed method signatures
interface Cacheable
{
    const DEFAULT_TTL = 3600;
    public function getCacheKey(): string;
    public function getCacheTtl(): int;
}

// PHP 8.1+ — readonly properties in abstract classes
abstract class AbstractValueObject
{
    public function __construct(
        public readonly string $value
    ) {}

    abstract public function validate(): bool;
}

// PHP 8.2+ — interface constants can be typed (implicitly)
```

Even with these features, the core distinction remains: **interface = contract, abstract class = shared behavior**.

### Real Scenario

You are building an e-commerce application with multiple shipping providers:

```php
// Interface — defines what any shipping provider must do
interface ShippingProvider
{
    public function calculateCost(Package $package, Address $destination): Money;
    public function createShipment(Order $order): Shipment;
    public function trackShipment(string $trackingNumber): ShipmentStatus;
}

// Abstract class — shared HTTP communication logic
abstract class AbstractHttpShippingProvider implements ShippingProvider
{
    public function __construct(
        protected HttpClientInterface $httpClient,
        protected LoggerInterface $logger,
    ) {}

    public function trackShipment(string $trackingNumber): ShipmentStatus
    {
        // Same tracking logic for all HTTP-based providers
        $response = $this->httpClient->request('GET', $this->getTrackingUrl($trackingNumber));
        $this->logger->info('Tracking request sent', ['tracking' => $trackingNumber]);
        return $this->parseTrackingResponse($response);
    }

    abstract protected function getTrackingUrl(string $trackingNumber): string;
    abstract protected function parseTrackingResponse(ResponseInterface $response): ShipmentStatus;
}

// Concrete — only DHL-specific details
class DhlProvider extends AbstractHttpShippingProvider
{
    protected function getTrackingUrl(string $trackingNumber): string
    {
        return "https://api.dhl.com/track/$trackingNumber";
    }
    // ...
}
```

### Conclusion

Use an **interface** when you need a pure contract that multiple unrelated classes should follow — this enables dependency injection, polymorphism, and easy testing. Use an **abstract class** when related classes share common behavior that should not be duplicated. Often, the best design combines both: type-hint against interfaces, implement shared logic in abstract classes, and put specific details in concrete classes.

> See also: [Composition vs inheritance](composition_vs_inheritance.md), [SOLID principles](../solid/), [DI vs composition vs IoC](di_vs_composition_vs_ioc.md), [Polymorphism vs inheritance](polymorphism_vs_inheritance.md)
