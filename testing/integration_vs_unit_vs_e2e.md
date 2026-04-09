# Integration vs unit vs e2e testing

**Interview framing:**

"The test pyramid — unit tests at the base, integration in the middle, end-to-end at the top — is the standard model for how to distribute testing effort. Units are fast, cheap, and abundant; integration tests are slower but catch boundary bugs; end-to-end tests are slow, expensive, and prove the system works as a whole. The senior insight is that the pyramid is a guideline, not a religion — the right shape depends on the codebase, and some teams get more value from a 'testing trophy' (more integration, fewer units) than from a strict pyramid."

### The three levels

#### Unit tests

Test a single unit of code (function, class, method) in isolation. Dependencies are mocked.

- **Speed:** milliseconds.
- **Isolation:** complete — no database, no network, no filesystem.
- **What they catch:** logic errors in individual components.
- **What they miss:** integration bugs, configuration issues, real-world edge cases.
- **Cost to write:** low.
- **Cost to maintain:** low (changes to one unit only affect its tests).

```php
public function testCalculateOrderTotalAppliesDiscount(): void
{
    $order = new Order();
    $order->addItem(new Item('Widget', 100.00), 2);
    $order->applyDiscount(new PercentageDiscount(10));

    $this->assertEquals(180.00, $order->getTotal());
}
```

No database, no framework, no HTTP — just the Order class doing math.

#### Integration tests

Test the interaction between two or more components, typically including real infrastructure (database, cache, message broker).

- **Speed:** seconds to tens of seconds.
- **Isolation:** partial — real database, real cache, mocked external APIs.
- **What they catch:** wrong queries, misconfigured DI, serialization bugs, database constraint violations, transaction behavior.
- **What they miss:** UI behavior, cross-service communication, deployment issues.
- **Cost to write:** medium.
- **Cost to maintain:** medium (database schema changes can break many tests).

```php
public function testCreateOrderPersistsToDatabase(): void
{
    $order = Order::place($this->userId, $this->items, $this->address);
    $this->orderRepository->save($order);

    $loaded = $this->orderRepository->findById($order->getId());
    $this->assertEquals($order->getTotal(), $loaded->getTotal());
    $this->assertEquals('placed', $loaded->getStatus());
}
```

Real database, real Doctrine mapping, real queries. Catches the bugs that unit tests with mocked repositories miss.

#### End-to-end (e2e) tests

Test the entire system from the outside — HTTP request in, HTTP response (or UI state) out. Everything is real: web server, database, cache, message broker, external services (or their sandboxes).

- **Speed:** seconds to minutes.
- **Isolation:** none — the full stack is running.
- **What they catch:** the system actually works, as a user would experience it.
- **What they miss:** nothing, in theory — but they're too slow and expensive to cover everything.
- **Cost to write:** high.
- **Cost to maintain:** high (fragile, slow, break on any change).

```php
public function testCheckoutFlowCreatesOrderAndChargesPayment(): void
{
    $response = $this->client->post('/api/checkout', [
        'json' => ['items' => [['sku' => 'ABC', 'qty' => 1]], 'payment_method' => 'pm_test'],
    ]);

    $this->assertEquals(201, $response->getStatusCode());
    $order = json_decode($response->getBody(), true);
    $this->assertEquals('confirmed', $order['status']);
}
```

Full HTTP request, full stack, real response. Proves the happy path works end-to-end.

### The test pyramid

```text
        /\
       /  \      E2E tests (few)
      /----\
     /      \    Integration tests (moderate)
    /--------\
   /          \  Unit tests (many)
  /____________\
```

**The principle:** most tests should be fast unit tests. Some should be integration tests. A few should be e2e tests. The pyramid shape reflects the cost/speed trade-off: the higher you go, the more expensive and slower each test is.

### The testing trophy (alternative model)

Kent C. Dodds proposed the "testing trophy":

```text
        __
       /  \     E2E (few)
      /    \
     /------\   Integration (MOST)
    /        \
   /----------\ Unit (some)
  /            \
  \____________/ Static analysis (foundation)
```

The trophy argues that integration tests give the most confidence per test dollar. Unit tests on pure logic are valuable but mocked-everything unit tests prove less than integration tests that hit real infrastructure.

**The pragmatic view:** which shape is right depends on the codebase:

- **Heavy business logic with little I/O:** pyramid (unit-heavy). The value is in testing the logic.
- **CRUD with complex database interactions:** trophy (integration-heavy). The value is in testing the queries and mappings.
- **Most real applications:** a mix. Unit tests for domain logic, integration tests for repository/service layer, a few e2e for critical flows.

### What belongs at each level for a PHP application

| Component | Unit test | Integration test | E2E test |
|---|---|---|---|
| Domain entities, value objects | ✅ Primary | | |
| Business rules, calculations | ✅ Primary | | |
| Service classes (orchestration) | ✅ with mocked deps | ✅ with real deps | |
| Repository/DAO | | ✅ Primary (real DB) | |
| API controllers | | ✅ (functional test) | ✅ (HTTP) |
| Message handlers | | ✅ (real broker or in-memory) | |
| Full user workflows | | | ✅ Primary |
| Third-party integrations | ✅ with mocked API | ✅ with sandbox/stub | |

### Negative testing — the missing dimension

Most test suites focus on happy paths. **Negative tests** verify the system handles invalid input, error conditions, and edge cases:

- Invalid request bodies (missing required fields, wrong types, extra fields).
- Unauthorized access (no token, expired token, wrong role).
- Resource not found (404 on non-existent IDs).
- Conflict (duplicate creation, concurrent modification).
- Rate limiting (exceeding quotas).
- Upstream service failures (timeouts, 500s).

Negative tests live at all levels:

- Unit: `testCalculateTotal_withNegativeQuantity_throwsException`.
- Integration: `testCreateOrder_withDuplicateId_returns409`.
- E2E: `testCheckout_withExpiredPaymentMethod_returnsError`.

The job ad mentions "negative testing" specifically — it's the kind of testing that separates thorough from superficial test suites.

### Test data management

The hardest practical problem in integration testing: getting realistic, consistent test data.

**Approaches:**

- **Fixtures** — predefined data loaded before tests. Simple but brittle; changes cascade.
- **Factories/builders** — programmatic data creation. `OrderFactory::create(['status' => 'pending'])`. More flexible, less brittle.
- **Database transactions** — wrap each test in a transaction, roll back after. Fast isolation. Doesn't work when the code under test commits its own transaction.
- **Database reset** — truncate and re-seed between tests. Slower but ensures clean state.
- **In-memory database** — SQLite for speed. Risk: behavior differences from production database (PostgreSQL/MySQL).

**My recommendation:** factories + transaction wrapping for most tests, with a real PostgreSQL/MySQL database (via Docker) matching production. SQLite shortcuts will eventually bite you.

### The test that's missing from most suites

The test nobody writes until after the incident:

- **"What happens when the database is slow?"** Add a delay to the test database; verify the application handles timeouts gracefully.
- **"What happens when the cache is down?"** Remove Redis from the test environment; verify the application degrades, not crashes.
- **"What happens when the message broker is unreachable?"** Verify the publish failure is handled (retry, fallback, or error response).

These resilience tests are valuable and almost universally absent.

> **Mid-level answer stops here.** A mid-level dev can describe the pyramid. To sound senior, speak to the practical trade-offs — which shape fits which codebase, negative testing, and the tests that are usually missing ↓
>
> **Senior signal:** choosing the right test distribution for the specific codebase rather than following a dogmatic model.

### Common mistakes

- **100% unit test coverage, zero integration tests.** Mocked repositories "pass" but the actual query is wrong.
- **100% e2e tests, no unit tests.** Slow, flaky, hard to pinpoint failures.
- **Testing the framework.** "Test that Symfony's router routes to my controller" — the framework already tests this.
- **Mocking everything.** The test proves the mocks work, not the code.
- **No negative tests.** The suite only covers happy paths.
- **SQLite instead of the real database.** Type coercion, missing features, different behavior.
- **Fragile e2e tests.** Coupled to implementation details (CSS selectors, exact response text).
- **No test data strategy.** Tests depend on shared fixtures that break when anyone changes them.

### Closing

"So unit tests for logic, integration tests for boundaries, e2e tests for user-visible flows. The pyramid is the default shape; the trophy emphasizes integration tests for I/O-heavy code. Negative tests cover error handling and edge cases — and are the most commonly missing category. The right distribution depends on the codebase: domain-heavy code wants more units, CRUD-heavy code wants more integration. Use real databases in tests, factories for test data, and write the resilience tests nobody writes until after the first incident."
