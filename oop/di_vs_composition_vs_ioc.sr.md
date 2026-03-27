Dependency Injection, Kompozicija i Inversion of Control su tri povezana ali različita koncepta. Često se mešaju jer se pojavljuju zajedno. Razumevanje razlike pomaže vam da objasnite svoje arhitekturne odluke na intervjuima.

### Dependency Injection (DI)

Dependency Injection znači da klasa prima svoje zavisnosti spolja umesto da ih kreira iznutra. Najčešći oblik je **injekcija kroz konstruktor** — zavisnosti se prosleđuju kroz konstruktor.

**Bez DI** — klasa kreira sopstvenu zavisnost:

```php
class OrderService
{
    private PaymentGateway $gateway;

    public function __construct()
    {
        // Tight coupling — hard to test, hard to replace
        $this->gateway = new StripePaymentGateway('sk_live_key_123');
    }
}
```

**Sa DI** — zavisnost je injektovana spolja:

```php
interface PaymentGatewayInterface
{
    public function charge(float $amount): bool;
}

class OrderService
{
    public function __construct(
        private PaymentGatewayInterface $gateway,
    ) {}

    public function placeOrder(Order $order): void
    {
        if (!$this->gateway->charge($order->getTotal())) {
            throw new PaymentFailedException();
        }
        $order->markAsPaid();
    }
}
```

Sada možete injektovati bilo koju implementaciju — Stripe, PayPal ili mock za testove:

```php
// Production
$service = new OrderService(new StripePaymentGateway('sk_live_key_123'));

// Test
$service = new OrderService(new FakePaymentGateway(alwaysSucceeds: true));
```

Tri oblika DI:
1. **Injekcija kroz konstruktor** — najčešća i preporučena
2. **Injekcija kroz setter** — `setLogger(LoggerInterface $logger)` — za opcione zavisnosti
3. **Injekcija kroz metodu** — prosleđivanje zavisnosti u specifičan poziv metode

### Kompozicija

Kompozicija znači izgradnju složenih objekata kombinovanjem jednostavnijih objekata. Prati relaciju "ima" — klasa **ima** drugi objekat kao deo sebe i **delegira** posao njemu.

```php
class NotificationService
{
    public function __construct(
        private EmailSender $emailSender,
        private SmsSender $smsSender,
        private SlackClient $slackClient,
    ) {}

    public function notifyUser(User $user, string $message): void
    {
        // Delegates to composed objects
        $this->emailSender->send($user->getEmail(), $message);

        if ($user->getPhone() !== null) {
            $this->smsSender->send($user->getPhone(), $message);
        }

        $this->slackClient->postMessage($user->getSlackId(), $message);
    }
}
```

Kompozicija se preferira nad nasleđivanjem jer je fleksibilnija:

```php
// Inheritance — rigid, one path only
class AdminNotificationService extends NotificationService { ... }
class UrgentNotificationService extends NotificationService { ... }
// What about urgent admin notifications? Multiple inheritance problem.

// Composition — flexible, combine freely
class NotificationService
{
    /** @param NotificationChannel[] $channels */
    public function __construct(private array $channels) {}

    public function notify(User $user, string $message): void
    {
        foreach ($this->channels as $channel) {
            $channel->send($user, $message);
        }
    }
}

// Create any combination
$urgentAdmin = new NotificationService([
    new EmailChannel(),
    new SmsChannel(),
    new SlackChannel(),
    new PagerDutyChannel(),
]);
```

### Inversion of Control (IoC)

IoC je **princip**, ne specifična tehnika. Znači da frejmvork kontroliše tok vašeg programa, a ne vaš kod. Pišete komponente, a frejmvork odlučuje kada da ih kreira, kada da ih pozove i kako da ih poveže.

**Bez IoC** — vaš kod kontroliše sve:

```php
// You manually create objects and wire them together
$pdo = new PDO('mysql:host=localhost;dbname=myapp', 'root', 'pass');
$userRepo = new UserRepository($pdo);
$mailer = new Mailer('smtp://localhost');
$registrationService = new RegistrationService($userRepo, $mailer);

// You call the service directly
$registrationService->register('john@example.com', 'John');
```

**Sa IoC** — frejmvork kontroliše kreiranje objekata i povezivanje:

```php
// Symfony — you only define the class and type-hint dependencies
class RegistrationService
{
    public function __construct(
        private UserRepository $userRepo,
        private MailerInterface $mailer,
    ) {}

    public function register(string $email, string $name): User
    {
        $user = new User($email, $name);
        $this->userRepo->save($user);
        $this->mailer->send(new WelcomeEmail($user));
        return $user;
    }
}

// Symfony's DI container (IoC container) automatically:
// 1. Finds all classes in src/
// 2. Reads constructor type-hints
// 3. Creates objects in the right order
// 4. Injects the right dependencies
// You never call "new RegistrationService(...)" yourself
```

Drugi primeri IoC-a:
- **Event dispatcher** — registrujete listenere, frejmvork ih poziva kada se događaji dese
- **HTTP kernel** — pišete kontrolere, frejmvork ih poziva kada se ruta poklopi
- **Lifecycle hooks** — frejmvork poziva `setUp()` i `tearDown()` u PHPUnit-u

### Kako DI, Kompozicija i IoC su Povezani

```
┌─────────────────────────────────────────────────┐
│  IoC (Princip)                                  │
│  "Frejmvork kontroliše tok"                     │
│                                                 │
│  ┌──────────────────┐  ┌────────────────────┐   │
│  │  DI (Tehnika)    │  │ Event Dispatching  │   │
│  │  "Primaj deps    │  │ Template engines   │   │
│  │   spolja"        │  │ Lifecycle hooks    │   │
│  └──────────────────┘  └────────────────────┘   │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  Kompozicija (Princip dizajna)                  │
│  "Gradi složene objekte od jednostavnijih"      │
│  Radi SA DI ali je poseban koncept              │
└─────────────────────────────────────────────────┘
```

- **IoC** je najširi koncept — princip koji kaže da frejmvork treba da kontroliše vaš kod, a ne obrnuto
- **DI** je jedna specifična tehnika za postizanje IoC-a — umesto kreiranja zavisnosti, primate ih
- **Kompozicija** se tiče strukture objekta ("ima") — nezavisna je od IoC-a, ali DI olakšava kompoziciju jer zavisnosti dolaze spolja

### Poređenje

| Aspekt | DI | Kompozicija | IoC |
|--------|-----|-------------|-----|
| Šta je to | Obrazac dizajna | Princip dizajna | Arhitekturni princip |
| Šta rešava | Kako dobiti zavisnosti | Kako strukturirati objekte | Ko kontroliše tok |
| Nivo | Nivo klase | Nivo klase | Nivo aplikacije |
| Suprotnost od | Kreiranje zavisnosti sa `new` | Nasleđivanje | Proceduralno "ti me pozivaš" |
| Primer | Injekcija kroz konstruktor | "Car ima Engine" | Symfony DI kontejner |

### Sva Tri Rade Zajedno

U realnoj Symfony aplikaciji, sva tri koncepta rade zajedno:

```php
// 1. COMPOSITION: OrderProcessor is composed of multiple collaborators
// 2. DI: Dependencies are injected through the constructor
// 3. IoC: Symfony's container creates and wires everything automatically

class OrderProcessor
{
    public function __construct(
        private OrderRepositoryInterface $orderRepo,     // DI + Composition
        private PaymentGatewayInterface $paymentGateway, // DI + Composition
        private MailerInterface $mailer,                  // DI + Composition
        private LoggerInterface $logger,                  // DI + Composition
    ) {}

    public function process(Order $order): void
    {
        $this->logger->info('Processing order', ['id' => $order->getId()]);

        // Delegates to composed objects (Composition)
        $this->paymentGateway->charge($order->getTotal());
        $order->markAsPaid();
        $this->orderRepo->save($order);
        $this->mailer->send(new OrderConfirmationEmail($order));

        $this->logger->info('Order processed', ['id' => $order->getId()]);
    }
}
```

```yaml
# config/services.yaml — IoC container configuration
services:
    _defaults:
        autowire: true       # Symfony reads constructor type-hints
        autoconfigure: true  # Symfony applies tags automatically

    App\:
        resource: '../src/'

    App\Payment\PaymentGatewayInterface:
        class: App\Payment\StripePaymentGateway
        arguments:
            $apiKey: '%env(STRIPE_API_KEY)%'
```

Symfony (IoC kontejner) čita konstruktor, vidi da `OrderProcessor` treba četiri zavisnosti, kreira ih u pravom redosledu i injektuje ih. Nikad ne pišete `new OrderProcessor(...)` nigde.

### Realni Scenario

Nasleđujete nasleđenu klasu koja radi sve sama:

```php
// Before — no DI, no Composition, no IoC
class InvoiceGenerator
{
    public function generate(int $orderId): string
    {
        // Creates its own database connection
        $pdo = new PDO('mysql:host=localhost;dbname=shop', 'root', 'pass');
        $order = $pdo->query("SELECT * FROM orders WHERE id = $orderId")->fetch();

        // Creates its own PDF library
        $pdf = new TCPDF();
        $pdf->AddPage();
        $pdf->writeHTML("<h1>Invoice #{$order['id']}</h1>");

        // Sends email directly
        mail($order['email'], 'Your Invoice', '', 'Content-Type: text/html');

        return $pdf->Output('', 'S');
    }
}
```

Problemi: ne može se testirati bez baze podataka, ne može se promeniti PDF biblioteka, ne može se promeniti provajder emaila, ranjivost SQL injekcije.

Refaktorisano sa sva tri koncepta:

```php
// After — DI + Composition + IoC
class InvoiceGenerator
{
    public function __construct(
        private OrderRepositoryInterface $orderRepo,  // DI
        private PdfRendererInterface $pdfRenderer,     // DI + Composition
        private MailerInterface $mailer,                // DI + Composition
    ) {}

    public function generate(int $orderId): string
    {
        $order = $this->orderRepo->find($orderId)
            ?? throw new OrderNotFoundException($orderId);

        $pdf = $this->pdfRenderer->render('invoice.html.twig', [
            'order' => $order,
        ]);

        $this->mailer->send(new InvoiceEmail($order, $pdf));

        return $pdf;
    }
}
```

Sada svaka zavisnost može biti zamenjena ili mock-ovana nezavisno. IoC kontejner povezuje sve. Klasa je testabilna, fleksibilna i prati Single Responsibility Principle.

### Zaključak

Dependency Injection je obrazac — klasa prima svoje zavisnosti umesto da ih kreira. Kompozicija je princip dizajna — izgradnja složenih objekata od jednostavnijih koristeći relacije "ima". Inversion of Control je arhitekturni princip — frejmvork kontroliše kreiranje objekata i tok programa, a ne vaš kod. DI je jedna tehnika za implementaciju IoC-a. Kompozicija radi nezavisno ali ima koristi od DI-ja jer zavisnosti dolaze spremne za upotrebu. U modernom PHP-u (Symfony, Laravel), sva tri rade zajedno: definirate klase sa type-hint konstruktorima (DI), komponujete ih od manjih saradnika (Kompozicija), a kontejner frejmvorka automatski kreira i povezuje sve (IoC).

> Pogledajte takođe: [Service Locator VS DI Container](service_locator_vs_di_container.sr.md), [Registry pattern VS Service Locator](registry_pattern_vs_service_locator.sr.md), [Kompozicija VS Nasleđivanje](composition_vs_inheritance.sr.md)
