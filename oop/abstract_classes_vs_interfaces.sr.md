I apstraktne klase i interfejsi definišu ugovore koje druge klase moraju da ispune. Ali oni služe različitim svrhama i imaju različita pravila.

### Interfejs — Čist Ugovor

Interfejs kaže **šta** klasa mora da radi, ali nikad **kako**. Definiše potpise metoda bez ikakve implementacije.

```php
interface PaymentGateway
{
    public function charge(float $amount, string $currency): PaymentResult;
    public function refund(string $transactionId): RefundResult;
}
```

**Pravila za interfejse:**

- Sve metode su public (nema private ili protected)
- Nema tela metoda (osim u PHP 8.0+ sa podrazumevanim implementacijama — retko)
- Nema properties (samo konstante)
- Klasa može da implementira **više** interfejsa
- Ne može biti instancirana

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

### Apstraktna Klasa — Delimična Implementacija

Apstraktna klasa kaže **šta** klasa mora da radi I pruža **zajedničko ponašanje**. Može imati i apstraktne metode (bez tela) i konkretne metode (sa telom).

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

**Pravila za apstraktne klase:**

- Mogu imati apstraktne I konkretne metode
- Mogu imati properties (uključujući private)
- Mogu imati konstruktore
- Klasa može da nasledi samo **jednu** apstraktnu klasu (jednostruko nasleđivanje)
- Ne može biti instancirana
- Metode mogu biti public, protected ili private

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

I `EmailSender` i `SmsSender` dobijaju `sendWithRetry()` i `log()` besplatno — bez dupliranja koda.

### Tabela Ključnih Razlika

| Karakteristika | Interfejs | Apstraktna Klasa |
|----------------|-----------|-----------------|
| Tela metoda | Ne (samo potpisi) | Da (apstraktne + konkretne) |
| Properties | Ne (samo konstante) | Da |
| Konstruktor | Ne | Da |
| Višestruko nasleđivanje | Da (`implements A, B, C`) | Ne (samo jedan `extends`) |
| Modifikatori pristupa | Samo `public` | `public`, `protected`, `private` |
| Svrha | Definisanje **ugovora** | Deljenje **zajedničkog ponašanja** |
| "Je" relacija | Ne | Da |

### Kada Koristiti Interfejs

Koristite interfejs kada:

- Treba da definišete **ugovor** koji više nepovezanih klasa prati
- Trebate **više implementacija** koje ne dele kod
- Želite da omogućite **dependency injection** i lako testiranje
- Klase iz različitih hijerarhija treba da budu međuzamenjive

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

### Kada Koristiti Apstraktnu Klasu

Koristite apstraktnu klasu kada:

- Više klasa deli **zajedničko ponašanje** (ne samo ugovor)
- Želite da pružite **podrazumevane implementacije** koje podklase nasleđuju
- Treba da definišete **šablonsku metodu** (fiksni algoritam sa prilagodljivim koracima)
- Klase su u istoj **porodici** (is-a relacija)

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

### Kombinovanje Oba

U realnim projektima, često kombinujete oba — interfejs za ugovor, i apstraktnu klasu za zajedničko ponašanje:

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

Type-hint prema `LoggerInterface` u vašim servisima. `AbstractLogger` smanjuje dupliranje. Konkretne klase implementiraju samo mehanizam skladištenja.

### Interfejs vs Apstraktna Klasa u PHP 8+

PHP 8+ je uveo neke karakteristike koje malo zamagljuju granicu:

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

Čak i sa ovim karakteristikama, osnovna razlika ostaje: **interfejs = ugovor, apstraktna klasa = zajedničko ponašanje**.

### Realni Scenario

Gradite aplikaciju za e-commerce sa više provajdera dostave:

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

### Zaključak

Koristite **interfejs** kada trebate čist ugovor koji više nepovezanih klasa treba da prati — ovo omogućava dependency injection, polimorfizam i lako testiranje. Koristite **apstraktnu klasu** kada povezane klase dele zajedničko ponašanje koje ne bi trebalo biti duplirano. Često, najbolji dizajn kombinuje oba: type-hint prema interfejsima, implementirajte zajedničku logiku u apstraktnim klasama, i stavite specifičnosti u konkretne klase.

> Pogledajte takođe: [Kompozicija vs nasleđivanje](composition_vs_inheritance.sr.md), [SOLID principi](../solid/), [DI vs kompozicija vs IoC](di_vs_composition_vs_ioc.sr.md), [Polimorfizam vs nasleđivanje](polymorphism_vs_inheritance.sr.md)
