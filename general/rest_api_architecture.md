# REST API Architecture

REST (Representational State Transfer) is an architectural style for designing networked applications. Most modern web APIs follow REST principles, making this one of the most common interview topics.

> **Scenario used throughout this document:** Designing an API for an e-commerce platform with products, orders, and customers.

## Prerequisites

- [HTTP Protocol Structure](http_protocol_structure.md) — request/response format
- [How the Internet Works](how_internet_works.md) — network fundamentals

## The Six REST Constraints

REST is defined by six constraints. An API that follows all of them is called "RESTful."

| Constraint | Meaning | Example |
|-----------|---------|---------|
| Client-Server | Client and server are independent | Browser doesn't know about database; API doesn't know about UI |
| Stateless | Each request contains all info needed | Server doesn't store session between requests; token sent each time |
| Cacheable | Responses must declare if cacheable | `Cache-Control: max-age=3600` on product listing |
| Uniform Interface | Consistent URL and method conventions | `GET /products/42` always returns product #42 |
| Layered System | Client can't tell if it talks to server or proxy | CDN, load balancer, or API gateway can sit between |
| Code on Demand (optional) | Server can send executable code | Rarely used; JavaScript downloaded by browser |

## Richardson Maturity Model

Leonard Richardson defined four levels of REST maturity. Most APIs are at Level 2.

```text
Level 3: Hypermedia Controls (HATEOAS)
  ▲    GET /orders/42 returns links: {"next": "/orders/42/pay"}
  │
Level 2: HTTP Verbs
  │    GET /products, POST /orders, DELETE /orders/42
  │
Level 1: Resources
  │    /products/42 instead of /api?action=getProduct&id=42
  │
Level 0: The Swamp of POX
       POST /api with XML/JSON body for everything
```

### Level 0 — One endpoint, one method

```http
POST /api HTTP/1.1
Content-Type: application/json

{"action": "getProduct", "id": 42}
```

### Level 1 — Resources as URLs

```http
POST /products/42 HTTP/1.1

{"action": "get"}
```

### Level 2 — HTTP verbs (most APIs stop here)

```http
GET /products/42 HTTP/1.1
DELETE /orders/99 HTTP/1.1
POST /orders HTTP/1.1
```

### Level 3 — HATEOAS (Hypermedia as the Engine of Application State)

```json
{
  "id": 42,
  "status": "pending",
  "_links": {
    "self": {"href": "/orders/42"},
    "pay": {"href": "/orders/42/pay", "method": "POST"},
    "cancel": {"href": "/orders/42/cancel", "method": "POST"}
  }
}
```

The client doesn't hardcode URLs — it follows links from the response, like a user clicking links on a web page.

## Resource URL Design

```text
Good:                              Bad:
GET    /products                   GET    /getProducts
GET    /products/42                GET    /product?id=42
GET    /products/42/reviews        POST   /getProductReviews
POST   /products                   POST   /createProduct
PUT    /products/42                POST   /updateProduct
DELETE /products/42                GET    /deleteProduct?id=42

Rules:
- Use nouns, not verbs          (/products not /getProducts)
- Use plural names              (/products not /product)
- Use HTTP methods for actions  (DELETE not /deleteProduct)
- Nest for relationships        (/products/42/reviews)
- Use query params for filters  (/products?category=electronics&sort=price)
```

## Symfony REST Controller Example

```php
<?php

namespace App\Controller;

use App\Repository\ProductRepository;
use App\Service\ProductService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/api/products')]
final class ProductController
{
    public function __construct(
        private readonly ProductRepository $repository,
        private readonly ProductService $service,
    ) {}

    #[Route('', methods: ['GET'])]
    public function list(Request $request): JsonResponse
    {
        $page = $request->query->getInt('page', 1);
        $limit = $request->query->getInt('limit', 20);
        $category = $request->query->get('category');

        $paginator = $this->repository->findFiltered($category, $page, $limit);

        return new JsonResponse([
            'data' => array_map(
                fn ($product) => [
                    'id' => $product->getId(),
                    'name' => $product->getName(),
                    'price' => $product->getPrice(),
                ],
                iterator_to_array($paginator),
            ),
            'meta' => [
                'page' => $page,
                'limit' => $limit,
                'total' => $paginator->count(),
            ],
        ]);
    }

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

        return new JsonResponse([
            'id' => $product->getId(),
            'name' => $product->getName(),
            'price' => $product->getPrice(),
            'description' => $product->getDescription(),
            'category' => $product->getCategory()->getName(),
        ]);
    }

    #[Route('', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);
        $product = $this->service->create($data);

        return new JsonResponse(
            ['id' => $product->getId(), 'name' => $product->getName()],
            Response::HTTP_CREATED,
            ['Location' => "/api/products/{$product->getId()}"],
        );
    }

    #[Route('/{id}', methods: ['DELETE'])]
    public function delete(int $id): Response
    {
        $product = $this->repository->find($id);

        if ($product === null) {
            return new JsonResponse(
                ['error' => 'Product not found'],
                Response::HTTP_NOT_FOUND,
            );
        }

        $this->service->delete($product);

        return new Response(status: Response::HTTP_NO_CONTENT);
    }
}
```

Key patterns:

- `GET /api/products` — returns paginated list with metadata
- `GET /api/products/42` — returns single resource or 404
- `POST /api/products` — returns 201 with `Location` header
- `DELETE /api/products/42` — returns 204 No Content

## API Versioning Strategies

| Strategy | Example | Pros | Cons |
|----------|---------|------|------|
| URL path | `/api/v1/products` | Simple, explicit | URL changes between versions |
| Query param | `/api/products?version=1` | Easy to default | Easy to forget |
| Header | `Accept: application/vnd.shop.v1+json` | URL stays clean | Harder to test in browser |
| Content negotiation | `Accept: application/json; version=1` | Standards-based | Complex to implement |

URL path versioning is the most common in practice because it's simple and explicit.

## Error Response Format

A consistent error format makes APIs easier to consume:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input data",
    "details": [
      {
        "field": "price",
        "message": "Price must be a positive number"
      },
      {
        "field": "name",
        "message": "Name is required"
      }
    ]
  }
}
```

Standard HTTP status codes:

```text
200 OK              → Successful GET, PUT, PATCH
201 Created         → Successful POST (resource created)
204 No Content      → Successful DELETE
400 Bad Request     → Invalid input (validation errors)
401 Unauthorized    → Missing or invalid authentication
403 Forbidden       → Authenticated but not authorized
404 Not Found       → Resource doesn't exist
409 Conflict        → Resource state conflict (duplicate email)
422 Unprocessable   → Semantically invalid (valid JSON, bad values)
429 Too Many Reqs   → Rate limit exceeded
500 Internal Error  → Server bug
```

## Common Interview Questions

### Q: What makes an API RESTful?

**A:** An API is RESTful when it follows the six REST constraints: **client-server** separation, **statelessness** (no server-side session), **cacheability** (responses indicate if they can be cached), **uniform interface** (consistent URL structure with HTTP verbs), **layered system** (proxies/CDNs can sit between client and server), and optionally **code on demand**. In practice, most APIs reach Level 2 of the Richardson Maturity Model — they use resources as URLs and HTTP verbs for actions — but skip Level 3 (HATEOAS).

### Q: How do you design URLs for nested resources?

**A:** Nest resources to express **ownership relationships**: `GET /products/42/reviews` returns reviews belonging to product 42. But avoid deep nesting beyond two levels — instead of `/users/1/orders/42/items/7`, use `/order-items/7` with query filters. The URL should reflect the resource hierarchy only when the child can't exist without the parent.

### Q: What is HATEOAS and why is it rarely used?

**A:** HATEOAS (Hypermedia as the Engine of Application State) means responses include links to related actions and resources, so the client doesn't hardcode URLs. For example, an order response includes `_links: { pay: "/orders/42/pay" }`. It's rarely used because most APIs serve mobile/SPA clients that have hardcoded URL patterns anyway, and the overhead of generating and parsing hypermedia links adds complexity without clear benefit for these clients.

## Conclusion

REST API design centers on resources (nouns in URLs), HTTP verbs (actions), and status codes (outcomes). A well-designed API uses consistent URL patterns, proper HTTP methods, pagination for lists, meaningful error responses, and versioning from the start. Most production APIs target Level 2 of the Richardson Maturity Model — using resources and HTTP verbs — which provides a good balance of structure and simplicity.

## See Also

- [HTTP Protocol Structure](http_protocol_structure.md) — request/response anatomy
- [REST API: POST vs PUT vs PATCH](rest_api_post_vs_put_vs_patch.md) — HTTP method semantics
- [REST API: PUT Request Specification](rest_api_put_request_specification.md) — deep dive into PUT
- [REST vs JSON-RPC](rest_api_vs_json_rpc.md) — alternative API styles
