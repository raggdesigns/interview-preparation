In PHP, when a class is declared `final`, it cannot be extended. PHPUnit creates mock objects by generating a subclass that extends the original class, so mocking a final class fails by default.

### Why Final Classes Cannot Be Mocked

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

When you try to mock this:

```php
$mock = $this->createMock(PaymentGateway::class);
// Error: Class "PaymentGateway" is declared "final" and cannot be mocked.
```

PHPUnit internally tries to do this, which PHP does not allow:

```php
// PHPUnit generates something like this behind the scenes
class Mock_PaymentGateway_abc123 extends PaymentGateway { ... }
// Fatal error: Class Mock_PaymentGateway_abc123 cannot extend final class PaymentGateway
```

### Solution 1: Extract an Interface

The cleanest solution is to create an interface and type-hint against it:

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

Now mock the interface instead of the class:

```php
$mock = $this->createMock(PaymentGatewayInterface::class);
$mock->method('charge')->willReturn(true);
```

This is the recommended approach because it follows the Dependency Inversion Principle — your code depends on an abstraction, not a concrete class.

### Solution 2: Bypass Finals Library

When you cannot change the class (e.g., it is from a vendor package), you can use the `dg/bypass-finals` library. It removes the `final` keyword from classes at load time, but only in tests.

```bash
composer require --dev dg/bypass-finals
```

Register it in `tests/bootstrap.php`:

```php
<?php
// tests/bootstrap.php

require dirname(__DIR__) . '/vendor/autoload.php';

DG\BypassFinals::enable();
```

Now you can mock final classes normally:

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

You can also limit which classes get "unfinalized":

```php
// Only bypass finals for specific namespaces
DG\BypassFinals::enable();
DG\BypassFinals::setWhitelist([
    '*/vendor/some-package/*',
]);
```

### Solution 3: Mockery

Mockery is an alternative mocking library that can mock final classes using a different approach:

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

Mockery can also use "overloading" to replace class instantiation:

```php
$gateway = Mockery::mock('overload:' . PaymentGateway::class);
$gateway->shouldReceive('charge')->andReturn(true);
```

### Comparison of Approaches

| Approach | Pros | Cons |
|----------|------|------|
| Extract interface | Clean, follows SOLID | Must change production code |
| dg/bypass-finals | No code changes needed | Modifies classes at load time |
| Mockery | Powerful, many features | Additional dependency, different API |

### When to Use Each

- **Extract interface** — when you own the code and can modify it
- **dg/bypass-finals** — when mocking vendor classes you cannot change
- **Mockery** — when you need advanced mocking features beyond PHPUnit

### Real Scenario

You are writing tests for an order service that depends on a Stripe payment gateway from a vendor package:

```php
// vendor/stripe/stripe-php - you cannot modify this
final class StripeClient
{
    public function paymentIntents(): PaymentIntentService { ... }
}
```

You cannot extract an interface because it is a vendor class. Instead, you create a wrapper:

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

Now you mock `PaymentProcessorInterface` in unit tests and test `StripePaymentProcessor` with `dg/bypass-finals` in integration tests:

```php
// Unit test — mock the interface
$processor = $this->createMock(PaymentProcessorInterface::class);
$processor->method('charge')->willReturn(new PaymentResult('pi_123', true));

// Integration test — mock the Stripe client using bypass-finals
$stripe = $this->createMock(StripeClient::class);
```

### Conclusion

Final classes cannot be mocked by PHPUnit because mocks extend the original class. The best solution is to extract an interface and mock that. When you cannot modify the class (vendor code), use `dg/bypass-finals` to strip the `final` keyword at test time, or use Mockery. In practice, the combination of interfaces for your own code and `dg/bypass-finals` for vendor code covers all cases.
