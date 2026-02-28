# Refactoring Legacy Code: Techniques, Patterns, and Approach

Refactoring legacy code means improving design and maintainability without changing observable behavior.
In interviews, this topic checks whether you can reduce risk while delivering business value, not just propose a full rewrite.

## Prerequisites

- Basic automated testing knowledge (unit/integration)
- Ability to read logs/metrics for production behavior
- Basic understanding of dependency injection and interfaces

## Core Approach (Safe Refactoring Flow)

1. Pick one painful hotspot (high change frequency, bug rate, or latency impact).
2. Capture current behavior before changing code (characterization tests).
3. Create seams so the code becomes testable (extract methods, wrap globals, inject dependencies).
4. Apply small refactors incrementally.
5. Verify after each step (tests + runtime metrics).
6. Release in small batches with rollback option.

This flow is usually safer than a big-bang rewrite.

## Techniques You Use Most

- **Characterization tests**: lock current behavior first, especially for unclear legacy logic.
- **Extract method/class**: split large functions/classes into focused units.
- **Dependency inversion**: replace direct static/global calls with interfaces.
- **Introduce parameter object**: simplify long method signatures.
- **Branch by abstraction**: introduce a new abstraction and migrate call sites gradually.

## Useful Patterns During Refactoring

- **Facade**: create one simple entry point over messy legacy internals.
- **Adapter**: keep old and new APIs compatible during migration.
- **Strategy**: isolate changing business rules behind interchangeable implementations.
- **Strangler-style replacement**: route part of the flow to new code while old code still works.

## Practical Example (PHP)

### Legacy code (hard to test and change)

```php
class InvoiceService
{
    public function generate(int $orderId): Invoice
    {
        $order = App::get('order_repository')->find($orderId);
        $tax = App::get('tax_calculator')->calculate($order);
        $pdf = App::get('pdf_generator')->generate($order, $tax);

        file_put_contents('/data/invoices/' . $orderId . '.pdf', $pdf);
        App::get('logger')->info('Invoice generated: ' . $orderId);

        return new Invoice($pdf);
    }
}
```

Problems:

- Hidden dependencies (`App::get(...)`)
- Direct filesystem write inside business logic
- Difficult unit testing

### Refactored version (incremental target)

```php
interface InvoiceStorage
{
    public function save(int $orderId, string $pdf): void;
}

final class InvoiceService
{
    public function __construct(
        private OrderRepository $orderRepository,
        private TaxCalculator $taxCalculator,
        private PdfGenerator $pdfGenerator,
        private InvoiceStorage $invoiceStorage,
        private LoggerInterface $logger,
    ) {
    }

    public function generate(int $orderId): Invoice
    {
        $order = $this->orderRepository->find($orderId);
        $tax = $this->taxCalculator->calculate($order);
        $pdf = $this->pdfGenerator->generate($order, $tax);

        $this->invoiceStorage->save($orderId, $pdf);
        $this->logger->info('Invoice generated: ' . $orderId);

        return new Invoice($pdf);
    }
}
```

### How to migrate safely

1. Add characterization test around `generate()` output and side effects.
2. Wrap `file_put_contents` behind `InvoiceStorage` adapter.
3. Replace one `App::get(...)` dependency at a time with constructor injection.
4. Keep behavior identical while improving structure.

## How to Prioritize Refactoring Work

Use a simple 2x2 matrix with two questions:

- How much does this area affect the business if it breaks?
- How often do developers touch this area?

### 1) High business impact + high change frequency

- **What it means**: Critical code that the team edits often. This is where bugs are expensive and frequent.
- **Example**: Checkout price calculation is changed every sprint for promotions, and small mistakes cause wrong totals.
- **Recommended action**: Refactor first. Add tests, split large methods, and remove risky dependencies before the next feature work.

### 2) High business impact + low change frequency

- **What it means**: Critical code that is relatively stable. It is dangerous when wrong, but not changed every week.
- **Example**: Monthly invoice export logic runs once per billing cycle and affects accounting.
- **Recommended action**: Stabilize with characterization tests now, then refactor in small steps when a business change is requested.

### 3) Low business impact + high change frequency

- **What it means**: Non-critical code touched often. It slows delivery but usually does not cause major incidents.
- **Example**: Internal admin filters are modified often by product requests, but failures affect only back-office convenience.
- **Recommended action**: Do opportunistic refactoring while implementing features (rename unclear code, extract methods, reduce duplication).

### 4) Low business impact + low change frequency

- **What it means**: Rarely used and low-risk code.
- **Example**: Legacy report export used by one team once per quarter.
- **Recommended action**: Postpone. Add a short note in tech debt backlog and revisit only if usage or risk increases.

## Common Interview Questions

### Q: When do you refactor versus rewrite?

**A:** Refactor when the current system still delivers value and behavior is mostly correct, but code quality slows development. Rewrite only when architecture blocks core business needs and incremental improvement is not realistic in acceptable time.

- **Refactor example**: A payment module works in production but is hard to change because of large classes and globals. Add tests and improve it step by step.
- **Rewrite example**: A monolith cannot meet strict multi-tenant isolation required by new contracts, and this cannot be added safely with small changes.

A practical rule: if you can ship value safely in small increments, prefer refactoring.

### Q: What is your first step if there are no tests?

**A:** Start by capturing current behavior with characterization tests around the most risky flow, before changing internals.

- Pick one important scenario (for example: `InvoiceService::generate()` for a real order).
- Record expected outputs and side effects (saved file, log entry, status update).
- Write tests that lock this behavior, even if the internal code is messy.

**Example:** Before refactoring tax logic, create tests with fixed input orders and expected totals so you can detect accidental behavior changes.

### Q: How do you show that refactoring produced value?

**A:** Show measurable before/after signals in the area you touched, not only “cleaner code”.

- **Delivery metrics**: lead time for related changes, review cycle time.
- **Quality metrics**: bug count in that module, rollback rate, production incidents.
- **Runtime metrics**: latency/error rate if performance-related refactoring was done.

**Example:** After refactoring invoice generation, the team reduced change lead time from 3 days to 1 day, and invoice-related incidents dropped from 4 per month to 1 per month over the next quarter.

## Conclusion

Legacy refactoring is mainly risk management with incremental design improvement.
Start from behavior safety, apply small focused techniques, and use migration patterns to move from fragile code to maintainable code without stopping delivery.

> See also: [Service Locator VS Inversion of Control (Dependency Injection) Container](service_locator_vs_di_container.md), [Dependency Injection VS Composition VS Inversion of Control (IoC/DiC)](di_vs_composition_vs_ioc.md), [KISS, DRY, YAGNI - explain abbreviations](kiss_dry_yagni.md)
