Service Locator i Dependency Injection (DI) Container oba pružaju zavisnosti klasama, ali rade na fundamentalno različite načine. Ključna razlika je **povlačenje vs guranje**.

### Service Locator — Povlačenje (Pull)

Service Locator je objekat koji drži reference na servise. Klase **traže** (povlače) od lokatora servis koji im je potreban:

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

### DI Container — Guranje (Push)

DI Container kreira objekte i **gura** njihove zavisnosti u njih kroz konstruktor:

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

### Ključne razlike

| Karakteristika | Service Locator | DI Container |
|----------------|----------------|--------------|
| Smer | Klasa **povlači** zavisnosti | Kontejner **gura** zavisnosti |
| Zavisnosti vidljive? | Ne — skrivene unutar metoda | Da — vidljive u konstruktoru |
| Spajanje | Klasa zavisi od Locator-a | Klasa zavisi samo od interfejsa |
| Testabilnost | Teško — morate postaviti Locator | Lako — prosledite mock-ove konstruktoru |
| Kada se razrešava | U vreme izvršavanja (kada se pozove) | U vreme konstruisanja |

### Zašto je Service Locator problematičan

#### 1. Skrivene zavisnosti

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

#### 2. Teško testiranje

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

#### 3. Greške u vreme izvršavanja umesto grešaka pri pokretanju

Sa Service Locator-om, dobijate grešku samo kada se kod zapravo izvrši i pokuša dohvatiti servis koji nedostaje. Sa DI, nedostajuće zavisnosti se hvataju kada se kontejner kompajlira (pri pokretanju):

```php
// Service Locator — fails at runtime
$service->createOrder($data);
// RuntimeException: Service "SomeService" not found

// DI Container (Symfony) — fails at container compilation
// "Cannot autowire OrderService: argument $someService references interface SomeService
// but no such service exists."
```

### Service Locator može biti prihvatljiv

Postoji nekoliko slučajeva gde je Service Locator-slični obrazac prihvatljiv:

1. **Migracija legacy koda** — kada postepeno radite refactoring na DI
2. **Service subscribers** — Symfony-jev `ServiceSubscriberInterface` je kontrolisana forma Service Locator-a za performanse (leno učitavanje retko korišćenih servisa)

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

### Realni scenario

Nasledili ste legacy aplikaciju koja svuda koristi Service Locator:

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

Radite refactoring da koristi DI:

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

Sada su zavisnosti vidljive, klasa je testabilna, a nedostajući servisi se hvataju u vreme kompajliranja.

### Zaključak

Service Locator i DI Container oba pružaju zavisnosti, ali na suprotne načine. Service Locator pušta klase da povlače zavisnosti (skrivene, teške za testiranje, greške u vreme izvršavanja). DI Container gura zavisnosti kroz konstruktore (vidljive, lako testirati, greške u vreme kompajliranja). Moderne PHP aplikacije treba da koriste DI Container (Symfony, Laravel). Service Locator treba izbegavati osim u legacy kodu ili specifičnim slučajevima performansi kao što je Symfony-jev `ServiceSubscriberInterface`.

> Vidi takođe: [Dependency Injection VS Composition VS Inversion of Control](di_vs_composition_vs_ioc.sr.md), [Registry pattern VS Service Locator](registry_pattern_vs_service_locator.sr.md)
