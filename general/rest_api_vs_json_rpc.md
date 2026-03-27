# REST vs JSON-RPC

REST and JSON-RPC are two different styles for building APIs. REST models everything as resources with HTTP verbs, while JSON-RPC models everything as procedure calls. Understanding when to choose each is an important architectural decision.

> **Scenario used throughout this document:** A payment service that processes charges, refunds, and balance inquiries.

## Prerequisites

- [REST API Architecture](rest_api_architecture.md) — REST principles and design
- [HTTP Protocol Structure](http_protocol_structure.md) — request/response format

## Same Operation, Different Styles

### REST Approach

```http
POST /api/payments HTTP/1.1
Content-Type: application/json

{"amount": 99.99, "currency": "USD", "customer_id": 42}
```

```http
HTTP/1.1 201 Created
Location: /api/payments/pay_abc123

{"id": "pay_abc123", "amount": 99.99, "status": "completed"}
```

```http
POST /api/payments/pay_abc123/refund HTTP/1.1
Content-Type: application/json

{"amount": 99.99, "reason": "customer_request"}
```

```http
GET /api/customers/42/balance HTTP/1.1
```

### JSON-RPC Approach

All requests go to a **single endpoint**:

```http
POST /api HTTP/1.1
Content-Type: application/json

{"jsonrpc": "2.0", "method": "payment.charge", "params": {"amount": 99.99, "currency": "USD", "customer_id": 42}, "id": 1}
```

```http
HTTP/1.1 200 OK

{"jsonrpc": "2.0", "result": {"id": "pay_abc123", "amount": 99.99, "status": "completed"}, "id": 1}
```

```http
POST /api HTTP/1.1

{"jsonrpc": "2.0", "method": "payment.refund", "params": {"payment_id": "pay_abc123", "amount": 99.99, "reason": "customer_request"}, "id": 2}
```

```http
POST /api HTTP/1.1

{"jsonrpc": "2.0", "method": "customer.getBalance", "params": {"customer_id": 42}, "id": 3}
```

## JSON-RPC 2.0 Protocol

### Request Format

```json
{
  "jsonrpc": "2.0",
  "method": "payment.charge",
  "params": {"amount": 99.99, "currency": "USD"},
  "id": 1
}
```

- `jsonrpc` — always "2.0"
- `method` — the procedure to call
- `params` — arguments (object or array)
- `id` — client-assigned identifier to match request with response (omit for notifications)

### Success Response

```json
{
  "jsonrpc": "2.0",
  "result": {"id": "pay_abc123", "amount": 99.99, "status": "completed"},
  "id": 1
}
```

### Error Response

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32602,
    "message": "Invalid params",
    "data": {"field": "amount", "reason": "must be positive"}
  },
  "id": 1
}
```

Standard error codes:

| Code | Meaning |
|------|---------|
| -32700 | Parse error (invalid JSON) |
| -32600 | Invalid request (missing required fields) |
| -32601 | Method not found |
| -32602 | Invalid params |
| -32603 | Internal error |
| -32000 to -32099 | Server-defined errors |

### Batch Requests

JSON-RPC supports sending **multiple calls in a single HTTP request**:

```json
[
  {"jsonrpc": "2.0", "method": "customer.getBalance", "params": {"customer_id": 42}, "id": 1},
  {"jsonrpc": "2.0", "method": "customer.getBalance", "params": {"customer_id": 43}, "id": 2},
  {"jsonrpc": "2.0", "method": "payment.list", "params": {"status": "pending"}, "id": 3}
]
```

Response (order not guaranteed):

```json
[
  {"jsonrpc": "2.0", "result": {"balance": 150.00}, "id": 1},
  {"jsonrpc": "2.0", "result": {"balance": 75.50}, "id": 2},
  {"jsonrpc": "2.0", "result": [{"id": "pay_1"}, {"id": "pay_2"}], "id": 3}
]
```

This reduces HTTP overhead — one TCP connection, one request, multiple operations.

## PHP Implementation: REST Controller

```php
<?php

namespace App\Controller;

use App\Service\PaymentService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/api/payments')]
final class PaymentController
{
    public function __construct(
        private readonly PaymentService $paymentService,
    ) {}

    #[Route('', methods: ['POST'])]
    public function charge(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);
        $payment = $this->paymentService->charge(
            $data['amount'],
            $data['currency'],
            $data['customer_id'],
        );

        return new JsonResponse(
            ['id' => $payment->getId(), 'status' => $payment->getStatus()],
            Response::HTTP_CREATED,
            ['Location' => "/api/payments/{$payment->getId()}"],
        );
    }

    #[Route('/{id}', methods: ['GET'])]
    public function show(string $id): JsonResponse
    {
        $payment = $this->paymentService->find($id);

        return new JsonResponse([
            'id' => $payment->getId(),
            'amount' => $payment->getAmount(),
            'status' => $payment->getStatus(),
        ]);
    }

    #[Route('/{id}/refund', methods: ['POST'])]
    public function refund(string $id, Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);
        $refund = $this->paymentService->refund($id, $data['amount']);

        return new JsonResponse(
            ['id' => $refund->getId(), 'status' => 'refunded'],
            Response::HTTP_CREATED,
        );
    }
}
```

## PHP Implementation: JSON-RPC Handler

```php
<?php

namespace App\JsonRpc;

use App\Service\CustomerService;
use App\Service\PaymentService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Attribute\Route;

final class JsonRpcHandler
{
    private array $methods;

    public function __construct(
        private readonly PaymentService $paymentService,
        private readonly CustomerService $customerService,
    ) {
        $this->methods = [
            'payment.charge' => $this->handleCharge(...),
            'payment.refund' => $this->handleRefund(...),
            'customer.getBalance' => $this->handleGetBalance(...),
        ];
    }

    #[Route('/api', methods: ['POST'])]
    public function handle(Request $request): JsonResponse
    {
        $body = json_decode($request->getContent(), true);

        if ($body === null) {
            return $this->errorResponse(null, -32700, 'Parse error');
        }

        // Batch request
        if (array_is_list($body)) {
            $responses = array_map(fn (array $req) => $this->dispatch($req), $body);
            return new JsonResponse(array_filter($responses));
        }

        return new JsonResponse($this->dispatch($body));
    }

    private function dispatch(array $request): ?array
    {
        $id = $request['id'] ?? null;
        $method = $request['method'] ?? '';
        $params = $request['params'] ?? [];

        if (!isset($this->methods[$method])) {
            return $this->error($id, -32601, "Method not found: {$method}");
        }

        try {
            $result = ($this->methods[$method])($params);

            // Notification (no id) — no response
            if ($id === null) {
                return null;
            }

            return ['jsonrpc' => '2.0', 'result' => $result, 'id' => $id];
        } catch (\InvalidArgumentException $e) {
            return $this->error($id, -32602, $e->getMessage());
        } catch (\Throwable $e) {
            return $this->error($id, -32603, 'Internal error');
        }
    }

    private function error(?int $id, int $code, string $message): array
    {
        return [
            'jsonrpc' => '2.0',
            'error' => ['code' => $code, 'message' => $message],
            'id' => $id,
        ];
    }

    private function errorResponse(?int $id, int $code, string $message): JsonResponse
    {
        return new JsonResponse($this->error($id, $code, $message));
    }

    private function handleCharge(array $params): array
    {
        $payment = $this->paymentService->charge(
            $params['amount'],
            $params['currency'],
            $params['customer_id'],
        );

        return ['id' => $payment->getId(), 'status' => $payment->getStatus()];
    }

    private function handleRefund(array $params): array
    {
        $refund = $this->paymentService->refund(
            $params['payment_id'],
            $params['amount'],
        );

        return ['id' => $refund->getId(), 'status' => 'refunded'];
    }

    private function handleGetBalance(array $params): array
    {
        $balance = $this->customerService->getBalance($params['customer_id']);

        return ['balance' => $balance];
    }
}
```

## Detailed Comparison

| Aspect | REST | JSON-RPC |
|--------|------|----------|
| Paradigm | Resource-oriented (nouns) | Action-oriented (verbs) |
| Endpoints | Many (`/payments`, `/customers/42/balance`) | One (`/api`) |
| HTTP methods | GET, POST, PUT, PATCH, DELETE | POST only |
| Status codes | Full HTTP semantics (201, 404, 409...) | Always 200 (errors in response body) |
| Caching | Built-in via HTTP caching headers | Not cacheable (all POST) |
| Discoverability | URLs are self-documenting | Method names need documentation |
| Batching | Not native (need custom implementation) | Built-in (array of requests) |
| Error format | HTTP status + response body | Structured error object with codes |
| Tooling | Swagger/OpenAPI, Postman, browsers | JSON-RPC-specific tools |
| Use case | Public APIs, CRUD-heavy apps | Internal APIs, complex operations |

## When to Choose Which

```text
Choose REST when:
  ✓ Building a public-facing API (clients expect REST)
  ✓ CRUD-heavy operations map naturally to resources
  ✓ HTTP caching is important (CDN, browser cache)
  ✓ You want browser-testable GET endpoints
  ✓ API discoverability matters (URLs are self-documenting)

Choose JSON-RPC when:
  ✓ Internal service-to-service communication
  ✓ Complex operations that don't map to CRUD (e.g., "transfer money between accounts")
  ✓ Batch requests are important (reduce HTTP overhead)
  ✓ You want a simpler protocol (one endpoint, always POST)
  ✓ Actions are more natural than resources (verbs over nouns)
```

**Note:** For high-performance internal communication, **gRPC** (Protocol Buffers over HTTP/2) is increasingly preferred over both REST and JSON-RPC due to binary encoding, streaming, and code generation.

## Common Interview Questions

### Q: When would you use JSON-RPC instead of REST?

**A:** JSON-RPC is better for **internal service-to-service communication** where operations don't map cleanly to CRUD (e.g., "transfer funds between accounts," "recalculate pricing," "merge user accounts"). It's also better when you need **batch requests** — sending multiple calls in one HTTP request. REST is better for public APIs where cacheability, discoverability, and standard HTTP semantics are important.

### Q: How does caching differ between REST and JSON-RPC?

**A:** REST uses HTTP caching naturally — `GET /products/42` can be cached by CDNs, browsers, and reverse proxies using standard `Cache-Control` and `ETag` headers. JSON-RPC sends everything as POST to a single endpoint, which HTTP caches won't cache by default. To cache JSON-RPC responses, you need application-level caching (e.g., Redis), which is more work.

### Q: What are the advantages of JSON-RPC's batch requests?

**A:** Batch requests send multiple procedure calls in a **single HTTP request**, reducing connection overhead (DNS, TCP, TLS). This is especially valuable for mobile clients with high-latency connections. REST has no standard batching mechanism — you'd need a custom endpoint or use GraphQL for multi-resource queries.

## Conclusion

REST models APIs around resources and HTTP semantics, making it ideal for public CRUD APIs with built-in caching and discoverability. JSON-RPC models APIs around procedure calls with a simpler protocol (one endpoint, structured errors, batch support), making it better for internal services with complex operations. Most applications use REST for their public API and consider JSON-RPC or gRPC for internal service communication where CRUD mapping is awkward.

## See Also

- [REST API Architecture](rest_api_architecture.md) — REST principles and design
- [REST API: POST vs PUT vs PATCH](rest_api_post_vs_put_vs_patch.md) — HTTP method semantics
- [SOA Architecture](soa_architecture.md) — service-oriented architecture patterns
