# REST API: PUT Request Specification

PUT is one of the most misunderstood HTTP methods. Developers often use it like PATCH (partial update), but the HTTP specification defines PUT as a **full replacement** of the resource at the given URL. Understanding PUT's exact semantics — including idempotency, conditional updates, and creation — is a common interview deep dive.

> **Scenario used throughout this document:** A product API where clients update product information.

## Prerequisites

- [REST API: POST vs PUT vs PATCH](rest_api_post_vs_put_vs_patch.md) — comparison of all three methods
- [HTTP Protocol Structure](http_protocol_structure.md) — request/response format

## PUT Semantics (RFC 7231)

The HTTP specification (RFC 7231, Section 4.3.4) defines PUT as:

> "The PUT method requests that the state of the target resource be **created or replaced** with the state defined by the representation enclosed in the request message payload."

Key implications:

1. **Full replacement** — the request body must contain the **complete** resource representation
2. **Idempotent** — sending the same request multiple times has the same effect as once
3. **Can create** — if the resource doesn't exist at the URL, PUT can create it
4. **Client knows the URL** — unlike POST where the server assigns the ID, PUT targets a specific URL

## Request and Response Examples

### Updating an existing resource

```http
PUT /api/products/42 HTTP/1.1
Content-Type: application/json

{
  "name": "Wireless Mouse Pro",
  "price": 39.99,
  "category": "electronics",
  "stock": 200,
  "description": "Ergonomic wireless mouse with USB-C receiver"
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
  "description": "Ergonomic wireless mouse with USB-C receiver",
  "updatedAt": "2024-01-15T14:00:00Z"
}
```

### Creating via PUT (when resource doesn't exist)

```http
PUT /api/products/sku-WM-PRO HTTP/1.1
Content-Type: application/json

{
  "name": "Wireless Mouse Pro",
  "price": 39.99,
  "category": "electronics",
  "stock": 100
}
```

```http
HTTP/1.1 201 Created
Location: /api/products/sku-WM-PRO

{
  "id": "sku-WM-PRO",
  "name": "Wireless Mouse Pro",
  "price": 39.99,
  "category": "electronics",
  "stock": 100,
  "createdAt": "2024-01-15T10:00:00Z"
}
```

### Successful update with no body

```http
PUT /api/products/42 HTTP/1.1
Content-Type: application/json

{"name": "Wireless Mouse Pro", "price": 39.99, "category": "electronics", "stock": 200}
```

```http
HTTP/1.1 204 No Content
```

204 means "success, but I have nothing to send back." This is a valid and common response for PUT.

## Status Codes for PUT

| Code | When | Meaning |
|------|------|---------|
| 200 OK | Resource updated | Returns the updated resource |
| 201 Created | Resource didn't exist, created | Returns the new resource + `Location` header |
| 204 No Content | Resource updated | No response body (common for APIs that don't return data) |
| 400 Bad Request | Invalid input | Validation errors |
| 404 Not Found | Resource doesn't exist and creation not supported | API chose not to create via PUT |
| 409 Conflict | Conflicting state | Concurrent modification detected (see ETags below) |
| 422 Unprocessable Entity | Valid JSON but semantically invalid | Business rule violation |

## Conditional Updates with ETag (Optimistic Locking)

To prevent **lost update** problems (two clients overwriting each other's changes), use ETags for conditional PUT requests.

### The Lost Update Problem

```text
Timeline without ETags:

1. Client A: GET /products/42        → {name: "Mouse", price: 29.99, stock: 150}
2. Client B: GET /products/42        → {name: "Mouse", price: 29.99, stock: 150}
3. Client A: PUT /products/42        → {name: "Mouse Pro", price: 39.99, stock: 150}
   ✓ Success — price updated
4. Client B: PUT /products/42        → {name: "Mouse", price: 29.99, stock: 200}
   ✓ Success — but Client A's price change is LOST!
```

### The Solution: ETag + If-Match

```text
1. Client A: GET /products/42
   Response: ETag: "v3"
             {name: "Mouse", price: 29.99, stock: 150}

2. Client B: GET /products/42
   Response: ETag: "v3"
             {name: "Mouse", price: 29.99, stock: 150}

3. Client A: PUT /products/42
             If-Match: "v3"
             {name: "Mouse Pro", price: 39.99, stock: 150}
   Response: 200 OK, ETag: "v4"
             ✓ Success — version matched

4. Client B: PUT /products/42
             If-Match: "v3"        ← stale! Current version is "v4"
             {name: "Mouse", price: 29.99, stock: 200}
   Response: 409 Conflict
             "Resource was modified since you last fetched it"
             ✗ Client B must re-fetch and retry
```

### PHP Implementation with Versioning

```php
<?php

namespace App\Controller;

use App\Entity\Product;
use App\Repository\ProductRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/api/products')]
final class ProductController
{
    public function __construct(
        private readonly ProductRepository $repository,
        private readonly EntityManagerInterface $em,
    ) {}

    #[Route('/{id}', methods: ['GET'])]
    public function show(int $id): JsonResponse
    {
        $product = $this->repository->find($id);

        if ($product === null) {
            return new JsonResponse(
                ['error' => 'Product not found'],
                Response::HTTP_NOT_FOUND,
            );
        }

        $response = new JsonResponse($this->serialize($product));
        $response->setEtag((string) $product->getVersion());

        return $response;
    }

    #[Route('/{id}', methods: ['PUT'])]
    public function replace(int $id, Request $request): JsonResponse|Response
    {
        $product = $this->repository->find($id);

        if ($product === null) {
            return new JsonResponse(
                ['error' => 'Product not found'],
                Response::HTTP_NOT_FOUND,
            );
        }

        // Check ETag for conditional update (optimistic locking)
        $ifMatch = $request->headers->get('If-Match');
        if ($ifMatch !== null && $ifMatch !== (string) $product->getVersion()) {
            return new JsonResponse(
                ['error' => 'Resource was modified since you last fetched it'],
                Response::HTTP_CONFLICT,
            );
        }

        $data = json_decode($request->getContent(), true);

        // PUT = full replacement — all fields required
        $product->setName($data['name']);
        $product->setPrice($data['price']);
        $product->setCategory($data['category']);
        $product->setStock($data['stock']);
        $product->setDescription($data['description'] ?? null);

        $this->em->flush(); // Version auto-increments via Doctrine @Version

        $response = new JsonResponse($this->serialize($product));
        $response->setEtag((string) $product->getVersion());

        return $response;
    }

    private function serialize(Product $product): array
    {
        return [
            'id' => $product->getId(),
            'name' => $product->getName(),
            'price' => $product->getPrice(),
            'category' => $product->getCategory(),
            'stock' => $product->getStock(),
            'description' => $product->getDescription(),
        ];
    }
}
```

The `@Version` column in the Product entity auto-increments on each update, making it a natural ETag.

## Full Replacement vs Partial Update

```text
Current resource:
  {
    "name": "Wireless Mouse",
    "price": 29.99,
    "category": "electronics",
    "stock": 150,
    "description": "Basic wireless mouse"
  }

PUT request (missing "description"):
  {
    "name": "Wireless Mouse Pro",
    "price": 39.99,
    "category": "electronics",
    "stock": 200
  }

Correct PUT result — description set to null:
  {
    "name": "Wireless Mouse Pro",
    "price": 39.99,
    "category": "electronics",
    "stock": 200,
    "description": null        ← CLEARED, not kept
  }

What most APIs actually do (incorrect but common):
  {
    "name": "Wireless Mouse Pro",
    "price": 39.99,
    "category": "electronics",
    "stock": 200,
    "description": "Basic wireless mouse"  ← KEPT — this is PATCH behavior
  }
```

Many APIs implement PUT as a partial update, which technically violates the spec. If you want partial updates, use PATCH.

## Idempotency in Practice

PUT is idempotent because repeating the same request produces the same resource state:

```text
PUT /products/42  {"name": "Mouse Pro", "price": 39.99}

1st request: product updated to {name: "Mouse Pro", price: 39.99}
2nd request: product updated to {name: "Mouse Pro", price: 39.99}  ← same state
3rd request: product updated to {name: "Mouse Pro", price: 39.99}  ← same state

Safe to retry after network failure — no side effects from duplicates.
```

**Note:** Idempotency refers to **resource state**, not side effects. The `updatedAt` timestamp may change, and an audit log entry may be created, but the resource itself is in the same state.

## Common Interview Questions

### Q: Can PUT create a resource?

**A:** Yes. According to RFC 7231, if the resource at the target URL doesn't exist, PUT can create it and return **201 Created**. The key difference from POST: with PUT, the **client** specifies the URL (e.g., `PUT /products/sku-WM-PRO`), while with POST, the **server** assigns the identifier (e.g., `POST /products` → server creates `/products/42`). In practice, many APIs only support creation via POST and return 404 for PUT to non-existent resources.

### Q: What is an ETag and how does it relate to PUT?

**A:** An **ETag** (Entity Tag) is a version identifier returned by the server in the `ETag` response header. When updating via PUT, the client sends the ETag in the `If-Match` header. The server compares it with the current version — if they match, the update proceeds; if not, the server returns **409 Conflict**, meaning someone else modified the resource in the meantime. This is called **optimistic locking** — it prevents the lost update problem without database-level locks.

### Q: Why should PUT be idempotent?

**A:** Because network requests can fail silently. If a client sends a PUT request and the connection times out, it doesn't know whether the server processed it. Idempotency guarantees that **retrying the same PUT produces the same result**, so the client can safely resend without causing inconsistencies. This is unlike POST, where retrying might create duplicate resources.

## Conclusion

PUT replaces the entire resource at a specific URL and is idempotent by specification. It can create resources (201) or update them (200/204). Conditional updates with `ETag` + `If-Match` prevent the lost update problem through optimistic locking. The most common mistake is treating PUT as a partial update (that's PATCH) — correct PUT implementations set missing fields to null rather than keeping their previous values.

## See Also

- [REST API: POST vs PUT vs PATCH](rest_api_post_vs_put_vs_patch.md) — comparing all three methods
- [REST API Architecture](rest_api_architecture.md) — API design principles
- [Optimistic and Pessimistic Locking](../highload/optimistic_pessimistic_lock.md) — concurrency control strategies
