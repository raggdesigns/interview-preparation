# How to Narrow Problems on PHP Side of an Application

When users report “the app is slow,” the root cause may be PHP code, database, network, or external APIs.
The goal is to prove where time is spent before changing code.
In interviews, this topic checks your debugging order and your ability to avoid blind optimizations.

## Prerequisites

- You can read application logs and web server logs
- You understand request latency metrics (avg, p95, p99)
- You know basic PHP-FPM behavior and memory limits

## Fast Diagnostic Flow

1. Confirm the symptom: error rate, timeout rate, or latency spike.
2. Reproduce with one endpoint and one realistic payload.
3. Correlate request logs with PHP logs for the same request ID.
4. Split time by layer: PHP code, DB query time, external API time.
5. Fix the biggest bottleneck first and re-measure.

## What to Check First

### 1) Error and timeout signals

- PHP fatal errors, warnings, out-of-memory events
- PHP-FPM slowlog entries
- Nginx/Apache upstream timeout errors

### 2) Application timing breakdown

- Total request time
- Database time vs non-database time
- External HTTP call time

If non-database time dominates, focus on PHP execution path.

### 3) Hot path profiling

Use profilers (for example Blackfire or Xdebug profiling mode) to find:

- Repeated expensive loops
- Serialization-heavy code
- N+1 service calls inside loops

## Practical Example

Problem:

- `GET /api/products` p95 increased from 180ms to 1.9s.
- DB dashboard shows query time stable.

Investigation:

1. Add request ID to logs.
2. Compare timings per request.
3. Find that 1.5s is spent in a loop calling an external pricing API per product.

Before (anti-pattern):

```php
foreach ($products as $product) {
    $product->price = $pricingClient->fetchPrice($product->id);
}
```

After:

```php
$ids = array_map(fn ($product) => $product->id, $products);
$priceMap = $pricingClient->fetchPricesBulk($ids);

foreach ($products as $product) {
    $product->price = $priceMap[$product->id] ?? null;
}
```

Result (example): p95 from 1.9s to 320ms.

## Useful Tooling

- Structured logs with request ID
- APM traces (New Relic, Datadog, etc.)
- PHP profiler (sampling or tracing)
- Static analysis for risky code paths (PHPStan/Psalm)

## Interview Notes

- Say how you isolate layers before fixing.
- Mention one concrete metric before and after.
- Explain why the chosen fix targeted the biggest bottleneck.

## Conclusion

Narrowing PHP-side issues is mainly about disciplined isolation.
Measure first, identify the dominant cost, apply one focused fix, and verify with the same metric.
