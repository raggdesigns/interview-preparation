U PHP-u, kada je klasa deklarisana kao `final`, ne može biti proširena. PHPUnit kreira mock objekte generisanjem podklase koja proširuje originalnu klasu, pa mockovanje finalne klase ne uspeva podrazumevano.

### Zašto se finalne klase ne mogu mockovati

```php
final class PaymentGateway
{
    public function charge(float $amount): bool
    {
        // Real payment processing
        return true;
    }
}
```

Kada pokušate da mockovate ovo:

```php
$mock = $this->createMock(PaymentGateway::class);
// Error: Class "PaymentGateway" is declared "final" and cannot be mocked.
```

PHPUnit interno pokušava da uradi ovo, što PHP ne dozvoljava:

```php
// PHPUnit generates something like this behind the scenes
class Mock_PaymentGateway_abc123 extends PaymentGateway { ... }
// Fatal error: Class Mock_PaymentGateway_abc123 cannot extend final class PaymentGateway
```

### Rešenje 1: Izvucite interfejs

Najčistije rešenje je kreiranje interfejsa i type-hinting prema njemu:

```php
interface PaymentGatewayInterface
{
    public function charge(float $amount): bool;
}

final class PaymentGateway implements PaymentGatewayInterface
{
    public function charge(float $amount): bool
    {
        // Real payment processing
        return true;
    }
}
```

Sada mockujte interfejs umesto klase:

```php
$mock = $this->createMock(PaymentGatewayInterface::class);
$mock->method('charge')->willReturn(true);
```

Ovo je preporučeni pristup jer sledi princip inverzije zavisnosti — vaš kod zavisi od apstrakcije, ne od konkretne klase.

### Rešenje 2: Biblioteka Bypass Finals

Kada ne možete da promenite klasu (npr. iz vendor paketa), možete koristiti biblioteku `dg/bypass-finals`. Ona uklanja ključnu reč `final` iz klasa u vreme učitavanja, ali samo u testovima.

```bash
composer require --dev dg/bypass-finals
```

Registrujte je u `tests/bootstrap.php`:

```php
<?php
// tests/bootstrap.php

require dirname(__DIR__) . '/vendor/autoload.php';

DG\BypassFinals::enable();
```

Sada možete normalno mockovati finalne klase:

```php
use PHPUnit\Framework\TestCase;

class OrderServiceTest extends TestCase
{
    public function testProcessOrder(): void
    {
        // This works because dg/bypass-finals removes "final" at load time
        $gateway = $this->createMock(PaymentGateway::class);
        $gateway->method('charge')->willReturn(true);

        $service = new OrderService($gateway);
        $result = $service->processOrder(new Order(100.00));

        $this->assertTrue($result);
    }
}
```

Možete takođe ograničiti koje klase dobijaju "uklonjen final":

```php
// Only bypass finals for specific namespaces
DG\BypassFinals::enable();
DG\BypassFinals::setWhitelist([
    '*/vendor/some-package/*',
]);
```

### Rešenje 3: Mockery

Mockery je alternativna biblioteka za mockovanje koja može mockovati finalne klase koristeći drugačiji pristup:

```bash
composer require --dev mockery/mockery
```

```php
use Mockery;
use PHPUnit\Framework\TestCase;

class PaymentTest extends TestCase
{
    public function testCharge(): void
    {
        $gateway = Mockery::mock(PaymentGateway::class);
        $gateway->shouldReceive('charge')
                ->with(100.00)
                ->andReturn(true);

        $service = new OrderService($gateway);
        $this->assertTrue($service->processOrder(new Order(100.00)));
    }

    protected function tearDown(): void
    {
        Mockery::close();
    }
}
```

Mockery takođe može koristiti "overloading" za zamenu instanciranja klase:

```php
$gateway = Mockery::mock('overload:' . PaymentGateway::class);
$gateway->shouldReceive('charge')->andReturn(true);
```

### Poredenje pristupa

| Pristup | Prednosti | Mane |
|---------|-----------|------|
| Izvucite interfejs | Čisto, sledi SOLID | Mora se menjati produkcijski kod |
| dg/bypass-finals | Nisu potrebne promene koda | Menja klase u vreme učitavanja |
| Mockery | Moćan, mnogo funkcija | Dodatna zavisnost, drugačiji API |

### Kada koristiti koji pristup

- **Izvucite interfejs** — kada posedujete kod i možete ga menjati
- **dg/bypass-finals** — kada mockoujete vendor klase koje ne možete menjati
- **Mockery** — kada vam trebaju napredne funkcije mockovanja van PHPUnit-a

### Realni scenario

Pišete testove za servis narudžbina koji zavisi od Stripe platnog gateway-a iz vendor paketa:

```php
// vendor/stripe/stripe-php - you cannot modify this
final class StripeClient
{
    public function paymentIntents(): PaymentIntentService { ... }
}
```

Ne možete izvući interfejs jer je to vendor klasa. Umesto toga, kreirate wrapper:

```php
// Your application code
interface PaymentProcessorInterface
{
    public function charge(float $amount, string $currency): PaymentResult;
}

final class StripePaymentProcessor implements PaymentProcessorInterface
{
    public function __construct(private StripeClient $stripe) {}

    public function charge(float $amount, string $currency): PaymentResult
    {
        $intent = $this->stripe->paymentIntents()->create([
            'amount' => (int)($amount * 100),
            'currency' => $currency,
        ]);

        return new PaymentResult($intent->id, $intent->status === 'succeeded');
    }
}
```

Sada mockujete `PaymentProcessorInterface` u unit testovima i testirate `StripePaymentProcessor` sa `dg/bypass-finals` u integracionim testovima:

```php
// Unit test — mock the interface
$processor = $this->createMock(PaymentProcessorInterface::class);
$processor->method('charge')->willReturn(new PaymentResult('pi_123', true));

// Integration test — mock the Stripe client using bypass-finals
$stripe = $this->createMock(StripeClient::class);
```

### Zaključak

Finalne klase ne mogu biti mockovane od strane PHPUnit-a jer mockovi proširuju originalnu klasu. Najbolje rešenje je izvući interfejs i mockovati njega. Kada ne možete menjati klasu (vendor kod), koristite `dg/bypass-finals` za uklanjanje ključne reči `final` u vreme testiranja, ili koristite Mockery. U praksi, kombinacija interfejsa za sopstveni kod i `dg/bypass-finals` za vendor kod pokriva sve slučajeve.
