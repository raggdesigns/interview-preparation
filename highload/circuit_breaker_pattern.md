# Circuit Breaker Pattern

The circuit breaker pattern protects your system from cascading failures when one dependency becomes slow or unavailable.
Instead of waiting for every failing request to timeout, it fails fast for a short period and gives the dependency time to recover.

In interviews, this topic shows whether you understand resilience under partial outages, not only happy-path architecture.

## Why failures cascade

Without a circuit breaker:

1. Service A calls Service B directly.
2. Service B becomes slow (or down).
3. Threads/workers in Service A block while waiting.
4. Queues grow, timeouts rise, retries multiply traffic.
5. Service A also becomes unstable, even if it was healthy.

This is how a small downstream problem can turn into a full incident.

## When and why this happens

Common triggers:

- Dependency latency spike (database lock, GC pause, network issue)
- Partial outage of a third-party API
- Connection pool exhaustion
- Retry storm with no backoff and no cap
- Traffic burst combined with expensive synchronous calls

Signals you should watch:

- Sudden increase in timeout errors
- High p95/p99 latency to one dependency
- Growing worker/thread saturation
- Queue growth and retry count explosion

## How circuit breaker works (simplest version)

For the most simple implementation, use only two states:

- **Closed**: calls go to dependency.
- **Open**: calls fail fast (or return fallback) until cooldown passes.

Minimal controls:

- Failure threshold (example: 3 failed calls)
- Cooldown duration (example: 10 seconds)

## Issue example (without circuit breaker)

This code retries a failing dependency, but has no timeout discipline and no fast-fail behavior.
Under outage, workers are blocked and retries increase load.

```php
<?php

final class PaymentGatewayClient
{
    public function charge(int $amount): array
    {
        usleep(4_000_000);

        throw new RuntimeException('Gateway timeout');
    }
}

final class CheckoutService
{
    public function __construct(private PaymentGatewayClient $gateway)
    {
    }

    public function checkout(int $amount): array
    {
        for ($attempt = 1; $attempt <= 3; $attempt++) {
            try {
                return $this->gateway->charge($amount);
            } catch (RuntimeException $exception) {
                if ($attempt === 3) {
                    throw $exception;
                }
            }
        }

        throw new RuntimeException('Unexpected checkout failure');
    }
}
```

Why this is dangerous:

- Every request still calls an unhealthy dependency.
- Multiple retries multiply pressure.
- Workers wait on long failures, reducing system capacity.

## Solved example (with simple circuit breaker)

This version uses a minimal 2-state breaker.
When failures hit the threshold, it opens and returns fallback immediately.
After cooldown, it allows calls again.

```php
<?php

final class SimpleCircuitBreaker
{
    private int $failureCount = 0;
    private ?int $openedAt = null;

    public function __construct(
        private int $failureThreshold = 3,
        private int $cooldownSeconds = 10,
    ) {
    }

    public function call(callable $operation, callable $fallback): array
    {
        if ($this->isOpen()) {
            return $fallback();
        }

        try {
            $result = $operation();
            $this->failureCount = 0;

            return $result;
        } catch (Throwable) {
            $this->failureCount++;

            if ($this->failureCount >= $this->failureThreshold) {
                $this->openedAt = time();
            }

            return $fallback();
        }
    }

    private function isOpen(): bool
    {
        if ($this->openedAt === null) {
            return false;
        }

        if ((time() - $this->openedAt) >= $this->cooldownSeconds) {
            $this->openedAt = null;
            $this->failureCount = 0;

            return false;
        }

        return true;
    }
}

final class PaymentGatewayClient
{
    public function charge(int $amount): array
    {
        throw new RuntimeException('Gateway timeout');
    }
}

final class CheckoutService
{
    public function __construct(
        private PaymentGatewayClient $gateway,
        private SimpleCircuitBreaker $circuitBreaker,
    ) {
    }

    public function checkout(int $amount): array
    {
        return $this->circuitBreaker->call(
            operation: fn (): array => $this->gateway->charge($amount),
            fallback: fn (): array => [
                'status' => 'deferred',
                'reason' => 'payment_gateway_unavailable',
            ],
        );
    }
}
```

What improved:

- Open state prevents repeated expensive failures.
- Cooldown gives dependency time to recover.
- Fallback keeps your endpoint responsive.

## What should be considered in production

1. **Timeouts before retries**
   - Set short, explicit per-call timeouts.
   - Do not rely only on default client timeout values.

2. **Retry strategy**
   - Use capped retries with exponential backoff and jitter.
   - Never retry non-idempotent operations blindly.

3. **Fallback design**
   - Decide business-safe fallback: cached data, deferred processing, partial response, or explicit failure.
   - Keep fallback behavior predictable for clients.

4. **Threshold tuning**
   - Start conservative and tune from real latency/error data.
   - Too sensitive opens too often; too tolerant delays protection.

5. **Observability**
   - Track circuit state changes, open duration, blocked calls, fallback rate.
   - Alert on long open periods and repeated open/close flapping.

6. **Complementary patterns**
   - Combine with bulkhead isolation to protect shared resources.
   - Use rate limiting to reduce surge pressure during incidents.

## Interview notes

- Circuit breaker is not a replacement for retries; it controls when retries should stop hitting an unhealthy dependency.
- For a minimal design, explain threshold + cooldown + fallback clearly.
- Mention trade-offs: temporary degraded experience is often better than full outage.

## Common interview questions

1. What is the difference between retry and circuit breaker patterns?
2. Why do we use cooldown before allowing calls again?
3. How do you choose failure threshold and reset timeout values?
4. Which metrics indicate your circuit breaker configuration is wrong?
5. When should you return fallback versus fail the request immediately?

## See also

- [Microservices communication patterns](../microservices/answers/microservices_communication_patterns.md)
- [Best practices for microservices development](../microservices/answers/best_practices_for_microservices_development.md)
- [How to narrow problems on php side of an application](how_to_narrow_problems_on_php_side_of_an_application.md)
- [Optimizing a slow GET endpoint](optimizing_slow_get_endpoint.md)
