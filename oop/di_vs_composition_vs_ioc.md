Dependency Injection, Composition, and Inversion of Control are three related but different concepts. They are often confused because they appear together. Understanding the difference helps you explain your architecture decisions in interviews.

### Dependency Injection (DI)

Dependency Injection means a class receives its dependencies from outside instead of creating them inside. The most common form is **constructor injection** — dependencies are passed through the constructor.

**Without DI** — the class creates its own dependency:

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

**With DI** — the dependency is injected from outside:

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

Now you can inject any implementation — Stripe, PayPal, or a mock for tests:

```php
// Production
$service = new OrderService(new StripePaymentGateway('sk_live_key_123'));

// Test
$service = new OrderService(new FakePaymentGateway(alwaysSucceeds: true));
```

Three forms of DI:

1. **Constructor injection** — most common and recommended
2. **Setter injection** — `setLogger(LoggerInterface $logger)` — for optional dependencies
3. **Method injection** — pass dependency to a specific method call

### Composition

Composition means building complex objects by combining simpler objects. It follows the "has-a" relationship — a class **has** another object as a part of itself, and **delegates** work to it.

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

Composition is preferred over inheritance because it is more flexible:

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

IoC is a **principle**, not a specific technique. It means the framework controls the flow of your program, not your code. You write components, and the framework decides when to create them, when to call them, and how to connect them.

**Without IoC** — your code controls everything:

```php
// You manually create objects and wire them together
$pdo = new PDO('mysql:host=localhost;dbname=myapp', 'root', 'pass');
$userRepo = new UserRepository($pdo);
$mailer = new Mailer('smtp://localhost');
$registrationService = new RegistrationService($userRepo, $mailer);

// You call the service directly
$registrationService->register('john@example.com', 'John');
```

**With IoC** — the framework controls object creation and wiring:

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

Other examples of IoC:

- **Event dispatcher** — you register listeners, the framework calls them when events happen
- **HTTP kernel** — you write controllers, the framework calls them when a route matches
- **Lifecycle hooks** — the framework calls `setUp()` and `tearDown()` in PHPUnit

### How DI, Composition, and IoC Relate

```text
┌─────────────────────────────────────────────────┐
│  IoC (Principle)                                │
│  "The framework controls the flow"              │
│                                                 │
│  ┌──────────────────┐  ┌────────────────────┐   │
│  │  DI (Technique)  │  │ Event Dispatching  │   │
│  │  "Receive deps   │  │ Template engines   │   │
│  │   from outside"  │  │ Lifecycle hooks    │   │
│  └──────────────────┘  └────────────────────┘   │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  Composition (Design Principle)                 │
│  "Build complex objects from simpler ones"      │
│  Works WITH DI but is a separate concept        │
└─────────────────────────────────────────────────┘
```

- **IoC** is the broadest concept — a principle that says the framework should control your code, not the other way around
- **DI** is one specific technique to achieve IoC — instead of creating dependencies, you receive them
- **Composition** is about object structure ("has-a") — it is independent of IoC, but DI makes composition easy because dependencies are provided from outside

### Comparison

| Aspect | DI | Composition | IoC |
|--------|-----|-------------|-----|
| What is it | Design pattern | Design principle | Architectural principle |
| What it solves | How to get dependencies | How to structure objects | Who controls the flow |
| Level | Class level | Class level | Application level |
| Opposite of | Creating dependencies with `new` | Inheritance | Procedural "you call me" |
| Example | Constructor injection | "Car has Engine" | Symfony DI container |

### All Three Working Together

In a real Symfony application, all three concepts work together:

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

Symfony (IoC container) reads the constructor, sees that `OrderProcessor` needs four dependencies, creates them in the right order, and injects them. You never write `new OrderProcessor(...)` anywhere.

### Real Scenario

You inherit a legacy class that does everything itself:

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

Problems: cannot test without a database, cannot change PDF library, cannot change email provider, SQL injection vulnerability.

Refactored with all three concepts:

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

Now each dependency can be replaced or mocked independently. The IoC container wires everything. The class is testable, flexible, and follows the Single Responsibility Principle.

### Conclusion

Dependency Injection is a pattern — a class receives its dependencies instead of creating them. Composition is a design principle — building complex objects from simpler ones using "has-a" relationships. Inversion of Control is an architectural principle — the framework controls object creation and program flow, not your code. DI is one technique to implement IoC. Composition works independently but benefits from DI because dependencies arrive ready to use. In modern PHP (Symfony, Laravel), all three work together: you define classes with constructor type-hints (DI), compose them from smaller collaborators (Composition), and the framework's container creates and wires everything automatically (IoC).

> See also: [Service Locator VS DI Container](service_locator_vs_di_container.md), [Registry pattern VS Service Locator](registry_pattern_vs_service_locator.md), [Composition VS Inheritance](composition_vs_inheritance.md)
