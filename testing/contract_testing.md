# Contract testing

**Interview framing:**

"Contract testing verifies that two services — a consumer and a provider — agree on the shape of their interactions. Instead of running both services together in an integration test, you capture the consumer's expectations as a contract, then verify the provider meets them independently. The main tool is Pact, and the pattern is called 'consumer-driven contract testing'. The benefit over end-to-end integration tests is speed, reliability, and the ability to test each side independently — which is what makes microservices independently deployable in practice."

### The problem

In a microservices architecture, services communicate via APIs. The billing service calls the order service's `/orders/{id}` endpoint and expects a specific response shape.

Without contract testing, you catch integration bugs by:

- **End-to-end tests** — slow, flaky, require both services running.
- **Manual testing** — unreliable, doesn't scale.
- **Hoping for the best** — the most common approach, surprisingly.

A provider changes a field name (`total_amount` → `amount`), their unit tests pass, they deploy. The consumer breaks in production because it expected `total_amount`.

Contract testing catches this before deployment.

### Consumer-driven contracts

The consumer writes the contract: "when I call `GET /orders/42`, I expect a 200 response with fields `id`, `total_amount`, `status`."

This contract (a Pact file) is shared with the provider. The provider runs its tests against the contract: "does my `/orders/{id}` endpoint return a response matching what the consumer expects?"

If the provider's response matches → the contract holds. If not → the provider knows it would break the consumer, before deploying.

**The flow:**

```text
Consumer:
  1. Write a consumer test that defines expectations (the contract).
  2. Run the test with a mock provider (Pact generates the mock from the contract).
  3. Consumer tests pass against the mock.
  4. Publish the contract (Pact file) to a shared broker.

Provider:
  1. Fetch the consumer's contract from the broker.
  2. Run the provider verification: start the real provider, replay the requests from the contract, check the responses match.
  3. If verification passes → safe to deploy.
```

### What a contract looks like (Pact)

A Pact contract is a JSON file describing interactions:

```json
{
  "consumer": { "name": "billing-service" },
  "provider": { "name": "order-service" },
  "interactions": [
    {
      "description": "a request for order 42",
      "request": {
        "method": "GET",
        "path": "/orders/42"
      },
      "response": {
        "status": 200,
        "body": {
          "id": 42,
          "total_amount": 49.99,
          "status": "confirmed",
          "items": [{"sku": "ABC", "quantity": 2}]
        }
      }
    }
  ]
}
```

The consumer says: "I call this endpoint and expect this shape." The provider verifies: "yes, my endpoint produces this shape."

### What contract testing does NOT test

- **Business logic correctness.** The contract says the response has a `status` field; it doesn't say the status is *correct* for the given order.
- **Performance.** No timing assertions.
- **Side effects.** No verification that the provider actually created/updated anything.
- **End-to-end workflows.** Contract tests verify individual interactions, not multi-step flows.

Contract testing is about **shape agreement**, not **functional correctness**. It ensures services can communicate; it doesn't ensure the communication produces the right business outcome.

### Pact in PHP

Pact has a PHP client (`pact-foundation/pact-php`):

```php
// Consumer test
$builder = new PactBuilder();
$builder
    ->uponReceiving('a request for order 42')
    ->with(new ConsumerRequest('GET', '/orders/42'))
    ->willRespondWith(new ProviderResponse(200, body: [
        'id' => Matchers::integer(42),
        'total_amount' => Matchers::decimal(49.99),
        'status' => Matchers::string('confirmed'),
    ]));

$mockService = $builder->build();

$client = new HttpClient(['base_uri' => $mockService->getBaseUri()]);
$response = $client->get('/orders/42');
$data = json_decode($response->getBody(), true);

$this->assertEquals(42, $data['id']);
```

**Matchers** are the power tool: instead of exact values, you specify types (`integer`, `string`, `decimal`), patterns (`regex`), or structural matchers (`eachLike` for arrays). This makes contracts flexible enough to survive across test data without being so loose they're meaningless.

### The Pact Broker

The Pact Broker is a service that stores contracts and verification results. It answers: "can consumer version X safely deploy, given the latest verified provider version?" This is the **can-I-deploy** check that gates deployments.

```bash
pact-broker can-i-deploy --pacticipant billing-service --version 1.4.2 --to prod
```

The broker checks: is there a verified contract between billing-service v1.4.2 and the version of order-service currently in prod? If yes → safe to deploy. If no → don't.

### When contract testing is worth it

- **Multiple teams working on different services.** The contract is the communication agreement.
- **Services deployed independently.** You need confidence that a provider change doesn't break consumers.
- **Flaky or slow end-to-end tests.** Contract tests are fast and deterministic.
- **API providers with many consumers.** The provider can verify all consumer contracts before deploying.

### When it's overkill

- **One team, one or two services.** Talk to each other; you don't need a formal contract.
- **Services that are always deployed together.** If they're never independent, the contract has no enforcement value.
- **Internal-only APIs that change freely.** If you control both sides and can change them simultaneously, integration tests suffice.

> **Mid-level answer stops here.** A mid-level dev can describe Pact. To sound senior, speak to where contract testing fits in the testing pyramid and the organizational discipline required ↓
>
> **Senior signal:** understanding contract testing as a team-coordination tool, not just a testing technique.

### Common mistakes

- **Testing exact values instead of shapes.** The contract should test "id is an integer", not "id is 42".
- **Consumer contracts that are too strict.** Breaking on any field addition. Use matchers liberally.
- **Provider not running verification in CI.** The contract only works if the provider checks it.
- **No Pact Broker.** Contracts shared via git or Slack get lost and stale.
- **Treating contract tests as integration tests.** They test shape, not behavior.
- **Not including contract tests in deployment gates.** The `can-i-deploy` check is the whole point.

### Closing

"So contract testing verifies that services agree on the shape of their interactions. The consumer writes the contract (expectations), the provider verifies it (actual behavior matches). Pact is the standard tool. The benefit is catching breaking changes before deployment without needing both services running in the same environment. It complements — not replaces — integration and end-to-end tests. The operational discipline is: publish contracts to a broker, run provider verification in CI, and gate deployments on the `can-i-deploy` check."
