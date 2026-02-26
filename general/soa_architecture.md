SOA (Service-Oriented Architecture) is an architectural approach where an application is built as a collection of **services** that communicate over a network. Each service is a self-contained unit that performs a specific business function and can be used by other services.

### What Is a Service in SOA

A service in SOA has four key characteristics:

1. **Self-contained** — it has its own logic and can work independently
2. **Has a clear contract** — it defines what operations it offers (via WSDL, API docs, etc.)
3. **Loosely coupled** — it can be changed without affecting other services
4. **Reusable** — multiple applications can use the same service

```
┌──────────────────────────────────────────────────┐
│                    Enterprise                     │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │  Order    │  │  Payment │  │  Inventory   │   │
│  │  Service  │  │  Service │  │  Service     │   │
│  └────┬─────┘  └─────┬────┘  └──────┬───────┘   │
│       │               │              │           │
│  ─────┴───────────────┴──────────────┴───────    │
│              Enterprise Service Bus (ESB)         │
│  ────────────────────────────────────────────     │
│       │               │              │           │
│  ┌────┴─────┐  ┌──────┴────┐  ┌─────┴───────┐   │
│  │  User    │  │  Shipping │  │  Reporting   │   │
│  │  Service │  │  Service  │  │  Service     │   │
│  └──────────┘  └───────────┘  └──────────────┘   │
└──────────────────────────────────────────────────┘
```

### SOA vs Monolith

In a monolith, all features live in one big application:

```
Monolith:
┌──────────────────────────────────────┐
│  Orders + Payments + Users +          │
│  Inventory + Shipping + Reports       │
│  (one database, one deployment)       │
└──────────────────────────────────────┘

SOA:
┌──────────┐  ┌──────────┐  ┌──────────┐
│  Orders  │  │ Payments │  │  Users   │
│  (own DB)│  │ (own DB) │  │ (own DB) │
└──────────┘  └──────────┘  └──────────┘
     Each service can be deployed independently
```

### SOA vs Microservices

SOA and microservices are related but different:

| Feature | SOA | Microservices |
|---------|-----|---------------|
| Service size | Larger, coarser-grained | Small, fine-grained |
| Communication | ESB (Enterprise Service Bus) | Direct HTTP/gRPC, message queues |
| Data | Can share databases | Each service owns its database |
| Protocol | Often SOAP/XML | Usually REST/JSON or gRPC |
| Governance | Centralized (ESB orchestrates) | Decentralized |
| Reuse | Services are designed for reuse | Services are designed for independence |
| Typical context | Enterprise (banks, telecom) | Startups, modern web apps |

Think of it this way:
- **SOA** = "Let's organize our enterprise systems into reusable services connected through a central bus"
- **Microservices** = "Let's break our application into tiny, independent services that each do one thing"

### Enterprise Service Bus (ESB)

The ESB is a central component in SOA that handles:
- **Message routing** — directing requests to the right service
- **Protocol transformation** — converting SOAP to REST, XML to JSON
- **Message enrichment** — adding data from other services
- **Error handling** — retries, dead letter queues
- **Orchestration** — coordinating multi-step business processes

```
Client Request: "Create Order"
       │
       ▼
   ┌───────┐
   │  ESB  │ ─── 1. Validate user → User Service
   │       │ ─── 2. Check stock → Inventory Service
   │       │ ─── 3. Process payment → Payment Service
   │       │ ─── 4. Ship order → Shipping Service
   └───┬───┘
       │
       ▼
  Response: "Order Created"
```

In microservices, there is no ESB. Services communicate directly or through lightweight message brokers like RabbitMQ.

### SOA Principles

1. **Standardized contracts** — every service publishes a clear interface (WSDL, OpenAPI)
2. **Loose coupling** — services depend on contracts, not implementations
3. **Abstraction** — internal details are hidden
4. **Reusability** — services are designed to be used by multiple consumers
5. **Composability** — services can be combined to create new business processes
6. **Statelessness** — services should not hold client state between calls
7. **Discoverability** — services can be found in a service registry

### Real-World SOA Example

A bank uses SOA to connect its different systems:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Mobile App │     │  Web Portal │     │  ATM System │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                    ┌──────┴──────┐
                    │     ESB     │
                    └──────┬──────┘
                           │
       ┌───────────────────┼───────────────────┐
       │                   │                   │
┌──────┴──────┐     ┌──────┴──────┐     ┌──────┴──────┐
│  Account    │     │  Transfer   │     │  Fraud      │
│  Service    │     │  Service    │     │  Detection  │
│  (SOAP)     │     │  (SOAP)     │     │  (SOAP)     │
└─────────────┘     └─────────────┘     └─────────────┘
```

All three client apps (mobile, web, ATM) use the same services. The ESB handles protocol conversion — the mobile app sends REST requests, and the ESB converts them to SOAP for the backend services.

### SOA in PHP Context

While PHP applications rarely use full ESB-style SOA, the concepts appear in modern PHP:

```php
// SOA-like approach in Symfony
// Each bounded context is a "service" with a clear API

// Order Service — exposes endpoints for order management
#[Route('/api/orders')]
class OrderController extends AbstractController
{
    #[Route('', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        // Calls other services via HTTP
        $userValid = $this->userServiceClient->validateUser($userId);
        $stockAvailable = $this->inventoryClient->checkStock($productId);
        
        if (!$userValid || !$stockAvailable) {
            return $this->json(['error' => 'Cannot create order'], 400);
        }
        
        $order = $this->orderService->create($request->toArray());
        
        // Async notification to other services via message queue
        $this->messageBus->dispatch(new OrderCreated($order->getId()));
        
        return $this->json($order, 201);
    }
}
```

### When to Use SOA

**SOA makes sense when:**
- You have a large enterprise with many applications that need to share services
- Different teams or departments need to use the same business logic
- You need to integrate legacy systems (SOAP) with modern ones (REST)
- You need centralized governance and monitoring

**SOA is overkill when:**
- You have a single application
- Your team is small (< 10 developers)
- You don't need to share services across applications
- You can start with a well-structured monolith

### Conclusion

SOA is an enterprise architecture pattern where business functionality is organized into reusable services connected through an ESB. It is the predecessor of microservices — both share the idea of splitting applications into independent services, but SOA is more centralized (ESB orchestration, SOAP contracts) while microservices are decentralized (direct communication, REST/gRPC). Most modern PHP applications lean toward microservices rather than traditional SOA, but the core principles — loose coupling, clear contracts, service reusability — remain fundamental to good architecture.

> See also: [REST API architecture](rest_api_architecture.md), [SOAP vs REST](soap_vs_rest.md), [REST API vs JSON-RPC](rest_api_vs_json_rpc.md)
