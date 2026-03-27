# REST API: POST vs PUT vs PATCH

POST, PUT, and PATCH are the three HTTP methods used to modify resources. Understanding when to use each — especially the difference between PUT and PATCH — is a frequent interview question.

> **Scenario used throughout this document:** An API for managing products in an e-commerce catalog.

## Prerequisites

- [REST API Architecture](rest_api_architecture.md) — resource design principles
- [HTTP Protocol Structure](http_protocol_structure.md) — request/response format

## Quick Comparison

| Aspect | POST | PUT | PATCH |
|--------|------|-----|-------|
| Purpose | Create a new resource | Replace a resource entirely | Partially update a resource |
| URL | Collection (`/products`) | Specific resource (`/products/42`) | Specific resource (`/products/42`) |
| Idempotent? | No | Yes | Can be, but not guaranteed |
| Request body | New resource data | Complete resource representation | Only changed fields |
| Typical response | 201 Created | 200 OK or 204 No Content | 200 OK |

## POST — Create a New Resource

POST creates a new resource in a collection. The server assigns the ID.

```http
POST /api/products HTTP/1.1
Content-Type: application/json

{
  "name": "Wireless Mouse",
  "price": 29.99,
  "category": "electronics",
  "stock": 150
}
```

```http
HTTP/1.1 201 Created
Location: /api/products/42
Content-Type: application/json

{
  "id": 42,
  "name": "Wireless Mouse",
  "price": 29.99,
  "category": "electronics",
  "stock": 150,
  "createdAt": "2024-01-15T10:30:00Z"
}
```

**Key points:**

- Sends to the **collection** URL (`/products`), not a specific resource
- Returns **201 Created** with a `Location` header pointing to the new resource
- **Not idempotent** — sending the same POST twice creates two products

```php
<?php

#[Route('/api/products', methods: ['POST'])]
public function create(Request $request): JsonResponse
{
    $data = json_decode($request->getContent(), true);

    $product = new Product();
    $product->setName($data['name']);
    $product->setPrice($data['price']);
    $product->setCategory($data['category']);
    $product->setStock($data['stock']);

    $this->entityManager->persist($product);
    $this->entityManager->flush();

    return new JsonResponse(
        $this->serializer->normalize($product),
        Response::HTTP_CREATED,
        ['Location' => "/api/products/{$product->getId()}"],
    );
}
```

## PUT — Replace a Resource Entirely

PUT replaces the **entire** resource at the given URL. If you omit a field, it should be set to null or its default.

```http
PUT /api/products/42 HTTP/1.1
Content-Type: application/json

{
  "name": "Wireless Mouse Pro",
  "price": 39.99,
  "category": "electronics",
  "stock": 200
}
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "id": 42,
  "name": "Wireless Mouse Pro",
  "price": 39.99,
  "category": "electronics",
  "stock": 200,
  "updatedAt": "2024-01-15T14:00:00Z"
}
```

**What "full replacement" means:**

```text
Current state:
  { name: "Wireless Mouse", price: 29.99, category: "electronics", stock: 150 }

PUT with missing field:
  { name: "Wireless Mouse Pro", price: 39.99, category: "electronics" }
  ← stock is missing

Result (correct PUT behavior):
  { name: "Wireless Mouse Pro", price: 39.99, category: "electronics", stock: null }
  ← stock was reset, NOT kept at 150
```

**Key points:**

- Sends to a **specific resource** URL (`/products/42`)
- **Idempotent** — sending the same PUT request 10 times has the same result as sending it once
- Must include the **complete** resource representation
- Can return **200 OK** (with body) or **204 No Content** (without body)
- Can **create** a resource if it doesn't exist at that URL (returns 201)

```php
<?php

#[Route('/api/products/{id}', methods: ['PUT'])]
public function replace(int $id, Request $request): JsonResponse
{
    $product = $this->repository->find($id);

    if ($product === null) {
        return new JsonResponse(
            ['error' => 'Product not found'],
            Response::HTTP_NOT_FOUND,
        );
    }

    $data = json_decode($request->getContent(), true);

    // PUT replaces ALL fields — missing fields become null
    $product->setName($data['name'] ?? null);
    $product->setPrice($data['price'] ?? null);
    $product->setCategory($data['category'] ?? null);
    $product->setStock($data['stock'] ?? null);

    $this->entityManager->flush();

    return new JsonResponse($this->serializer->normalize($product));
}
```

## PATCH — Partially Update a Resource

PATCH updates **only the specified fields**, leaving everything else unchanged.

```http
PATCH /api/products/42 HTTP/1.1
Content-Type: application/json

{
  "price": 34.99
}
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "id": 42,
  "name": "Wireless Mouse Pro",
  "price": 34.99,
  "category": "electronics",
  "stock": 200,
  "updatedAt": "2024-01-15T15:00:00Z"
}
```

Only `price` changed — all other fields kept their existing values.

**Key points:**

- Contains **only the fields to update** (not the full resource)
- Not guaranteed to be idempotent (e.g., `PATCH {"stock": "+10"}` — incrementing)
- Simpler for clients — no need to fetch the full resource first

```php
<?php

#[Route('/api/products/{id}', methods: ['PATCH'])]
public function update(int $id, Request $request): JsonResponse
{
    $product = $this->repository->find($id);

    if ($product === null) {
        return new JsonResponse(
            ['error' => 'Product not found'],
            Response::HTTP_NOT_FOUND,
        );
    }

    $data = json_decode($request->getContent(), true);

    // PATCH updates ONLY provided fields
    if (array_key_exists('name', $data)) {
        $product->setName($data['name']);
    }
    if (array_key_exists('price', $data)) {
        $product->setPrice($data['price']);
    }
    if (array_key_exists('category', $data)) {
        $product->setCategory($data['category']);
    }
    if (array_key_exists('stock', $data)) {
        $product->setStock($data['stock']);
    }

    $this->entityManager->flush();

    return new JsonResponse($this->serializer->normalize($product));
}
```

## JSON Patch (RFC 6902)

For complex partial updates, JSON Patch defines a standard format for describing changes as operations:

```http
PATCH /api/products/42 HTTP/1.1
Content-Type: application/json-patch+json

[
  {"op": "replace", "path": "/price", "value": 34.99},
  {"op": "add", "path": "/tags/-", "value": "on-sale"},
  {"op": "remove", "path": "/discount"}
]
```

Operations: `add`, `remove`, `replace`, `move`, `copy`, `test`.

The `test` operation is useful for conditional updates:

```json
[
  {"op": "test", "path": "/price", "value": 39.99},
  {"op": "replace", "path": "/price", "value": 34.99}
]
```

This only changes the price if it's currently 39.99 — a form of optimistic locking.

## Idempotency Explained

A request is **idempotent** if making it once has the same effect as making it multiple times.

```text
POST /products {name: "Mouse"}
  → 1st call: creates product #42     (1 product exists)
  → 2nd call: creates product #43     (2 products exist)
  → NOT idempotent

PUT /products/42 {name: "Mouse Pro", price: 39.99}
  → 1st call: updates product #42     (product = Mouse Pro, 39.99)
  → 2nd call: updates product #42     (product = Mouse Pro, 39.99 — same state)
  → Idempotent

DELETE /products/42
  → 1st call: deletes product #42     (product gone)
  → 2nd call: product already gone    (still gone — same state)
  → Idempotent
```

**Why it matters:** Network failures. If a PUT request times out, the client can safely retry — the result is the same. If a POST request times out, the client doesn't know if the resource was created, risking duplicates.

## Common Mistakes

| Mistake | Why it's wrong | Correct approach |
|---------|---------------|-----------------|
| Using POST for updates | POST is not idempotent — retries may create duplicates | Use PUT or PATCH |
| Using PUT with partial data | PUT means full replacement — missing fields become null | Use PATCH for partial updates |
| Using PATCH to create resources | PATCH is for modifying existing resources | Use POST or PUT to create |
| Ignoring idempotency in PUT | PUT must be idempotent by specification | Ensure same PUT request always produces same result |
| Using GET for deletes | GET must be safe (no side effects) | Use DELETE method |

## Common Interview Questions

### Q: What is the difference between PUT and PATCH?

**A:** **PUT** replaces the entire resource — you must send all fields, and any missing field is set to null or default. It's idempotent. **PATCH** updates only the provided fields, leaving the rest unchanged. For example, to change just the price: PUT requires sending `{name, price, category, stock}`, while PATCH only needs `{price}`. Use PUT when the client has the complete resource; use PATCH for targeted updates.

### Q: Is PATCH idempotent?

**A:** PATCH **can be** idempotent but isn't **guaranteed** to be. A simple field update like `{price: 34.99}` is idempotent (same result each time). But an operation like `{stock: "+10"}` or a JSON Patch `{"op": "add", "path": "/tags/-", "value": "sale"}` (append to array) is not — each call adds another item. The HTTP spec does not require PATCH to be idempotent, unlike PUT.

### Q: Why does idempotency matter in API design?

**A:** Network requests can fail or time out. If the server processed the request but the response was lost, the client needs to know whether it's safe to **retry**. Idempotent methods (PUT, DELETE) can be safely retried — the result is the same. Non-idempotent methods (POST) may create duplicates. This is why payment APIs often use **idempotency keys**: the client sends a unique key with POST requests, and the server ensures the operation only happens once per key.

## Conclusion

Use POST to create resources (server assigns ID), PUT to replace resources entirely (full representation, idempotent), and PATCH to update specific fields (partial payload). The most common mistake is using PUT with partial data — that's PATCH's job. Idempotency is what makes PUT safe to retry and POST risky without additional safeguards like idempotency keys.

## See Also

- [REST API Architecture](rest_api_architecture.md) — API design principles
- [REST API: PUT Request Specification](rest_api_put_request_specification.md) — deep dive into PUT semantics
- [HTTP 4xx vs 5xx Errors](http_4xx_vs_5xx_errors.md) — response status codes
