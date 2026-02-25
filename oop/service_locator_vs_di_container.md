Service Locator and Dependency Injection (DI) Container both provide dependencies to classes, but they work in fundamentally different ways. The key difference is **pull vs push**.

### Service Locator — Pull

A Service Locator is an object that holds references to services. Classes **ask** (pull) the locator for the service they need:

```php
class OrderService
{
    public function createOrder(array $data): Order
    {
        // Pull dependencies from the locator
        $em = ServiceLocator::get(EntityManagerInterface::class);
        $mailer = ServiceLocator::get(MailerInterface::class);
        $logger = ServiceLocator::get(LoggerInterface::class);
        
        $order = new Order($data);
        $em->persist($order);
        $em->flush();
        
        $mailer->send($order->getCustomerEmail(), 'Order confirmed');
        $logger->info('Order created: ' . $order->getId());
        
        return $order;
    }
}
```

### DI Container — Push

A DI Container creates objects and **pushes** their dependencies into them through the constructor:

```php
class OrderService
{
    public function __construct(
        private EntityManagerInterface $em,
        private MailerInterface $mailer,
        private LoggerInterface $logger,
    ) {}
    
    public function createOrder(array $data): Order
    {
        $order = new Order($data);
        $this->em->persist($order);
        $this->em->flush();
        
        $this->mailer->send($order->getCustomerEmail(), 'Order confirmed');
        $this->logger->info('Order created: ' . $order->getId());
        
        return $order;
    }
}
```

### Key Differences

| Feature | Service Locator | DI Container |
|---------|----------------|--------------|
| Direction | Class **pulls** dependencies | Container **pushes** dependencies |
| Dependencies visible? | No — hidden inside methods | Yes — visible in constructor |
| Coupling | Class depends on the Locator | Class depends only on interfaces |
| Testability | Hard — must set up the Locator | Easy — pass mocks to constructor |
| When resolved | At runtime (when called) | At construction time |

### Why Service Locator Is Problematic

#### 1. Hidden Dependencies

```php
// With Service Locator — you cannot see dependencies without reading the entire class
class OrderService
{
    public function __construct() {} // Looks like it needs nothing!
    
    public function createOrder(array $data): Order
    {
        $em = ServiceLocator::get(EntityManagerInterface::class);     // Surprise!
        $mailer = ServiceLocator::get(MailerInterface::class);         // Another one!
        $logger = ServiceLocator::get(LoggerInterface::class);         // And another!
        // ...
    }
}

// With DI — all dependencies are immediately visible
class OrderService
{
    public function __construct(
        private EntityManagerInterface $em,      // Clear
        private MailerInterface $mailer,          // Clear
        private LoggerInterface $logger,          // Clear
    ) {}
}
```

#### 2. Difficult to Test

```php
// Testing with Service Locator — messy setup
public function testCreateOrder(): void
{
    // Must configure the global locator with mocks
    ServiceLocator::set(EntityManagerInterface::class, $this->createMock(EntityManagerInterface::class));
    ServiceLocator::set(MailerInterface::class, $this->createMock(MailerInterface::class));
    ServiceLocator::set(LoggerInterface::class, $this->createMock(LoggerInterface::class));
    
    $service = new OrderService();
    $service->createOrder(['item' => 'book']);
    
    // Must clean up after test to avoid affecting other tests
    ServiceLocator::reset();
}

// Testing with DI — clean and simple
public function testCreateOrder(): void
{
    $em = $this->createMock(EntityManagerInterface::class);
    $em->expects($this->once())->method('persist');
    
    $service = new OrderService(
        $em,
        $this->createMock(MailerInterface::class),
        $this->createMock(LoggerInterface::class),
    );
    
    $service->createOrder(['item' => 'book']);
}
```

#### 3. Runtime Errors Instead of Startup Errors

With Service Locator, you get an error only when the code actually runs and tries to fetch a missing service. With DI, missing dependencies are caught when the container is compiled (at startup):

```php
// Service Locator — fails at runtime
$service->createOrder($data);
// RuntimeException: Service "SomeService" not found

// DI Container (Symfony) — fails at container compilation
// "Cannot autowire OrderService: argument $someService references interface SomeService 
// but no such service exists."
```

### Service Locator Can Be Acceptable

There are a few cases where a Service Locator-like pattern is acceptable:

1. **Legacy code migration** — when gradually refactoring to DI
2. **Service subscribers** — Symfony's `ServiceSubscriberInterface` is a controlled form of Service Locator for performance (lazy loading of rarely-used services)

```php
// Symfony ServiceSubscriberInterface — a controlled locator
class OrderHandler implements ServiceSubscriberInterface
{
    public function __construct(private ContainerInterface $locator) {}
    
    public static function getSubscribedServices(): array
    {
        return [
            EntityManagerInterface::class,
            MailerInterface::class,  // Only loaded when actually used
        ];
    }
    
    public function handle(): void
    {
        // Only resolves the mailer if this branch is reached
        if ($this->shouldNotify) {
            $this->locator->get(MailerInterface::class)->send(...);
        }
    }
}
```

### Real Scenario

You inherit a legacy application that uses a Service Locator everywhere:

```php
// Legacy code — Service Locator
class InvoiceService
{
    public function generate(int $orderId): Invoice
    {
        $order = App::get('order_repository')->find($orderId);
        $tax = App::get('tax_calculator')->calculate($order);
        $pdf = App::get('pdf_generator')->generate($order, $tax);
        App::get('storage')->save($pdf);
        App::get('logger')->info("Invoice generated for order $orderId");
        return new Invoice($pdf);
    }
}
```

You refactor it to use DI:

```php
class InvoiceService
{
    public function __construct(
        private OrderRepository $orderRepository,
        private TaxCalculator $taxCalculator,
        private PdfGenerator $pdfGenerator,
        private StorageInterface $storage,
        private LoggerInterface $logger,
    ) {}
    
    public function generate(int $orderId): Invoice
    {
        $order = $this->orderRepository->find($orderId);
        $tax = $this->taxCalculator->calculate($order);
        $pdf = $this->pdfGenerator->generate($order, $tax);
        $this->storage->save($pdf);
        $this->logger->info("Invoice generated for order $orderId");
        return new Invoice($pdf);
    }
}
```

Now the dependencies are visible, the class is testable, and missing services are caught at compilation time.

### Conclusion

Service Locator and DI Container both provide dependencies, but in opposite ways. Service Locator lets classes pull dependencies (hidden, hard to test, runtime errors). DI Container pushes dependencies through constructors (visible, easy to test, compile-time errors). Modern PHP applications should use DI Container (Symfony, Laravel). Service Locator should be avoided except in legacy code or specific performance cases like Symfony's `ServiceSubscriberInterface`.

> See also: [Dependency Injection VS Composition VS Inversion of Control](di_vs_composition_vs_ioc.md), [Registry pattern VS Service Locator](registry_pattern_vs_service_locator.md)
