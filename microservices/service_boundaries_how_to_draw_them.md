# Service boundaries — how to draw them

**Interview framing:**

"The hardest decision in microservices isn't the technology — it's where to draw the lines between services. Get the boundaries right and you get independent teams, independent deployments, and manageable complexity. Get them wrong and you get a distributed monolith: all the operational overhead of microservices with none of the benefits. The answer to 'how do you decide what's a service?' is not about code size or deployment units — it's about business capabilities and data ownership."

### The guiding principle: bounded contexts

The best heuristic for service boundaries comes from Domain-Driven Design: **each service should map to a bounded context** — a distinct area of the business with its own language, its own model, and its own data.

A bounded context is where a term has one clear meaning. "Order" in the sales context means "a customer's purchase request". "Order" in the fulfillment context means "a package to be shipped". Same word, different model, different rules. That's a boundary.

Services that share a bounded context are tightly coupled. Services that own separate bounded contexts can evolve independently. The boundary *is* the decoupling.

### How to find the boundaries

**1. Start with the business, not the code.**

Map the business capabilities:

- "Manage customer accounts"
- "Process orders"
- "Handle payments"
- "Manage inventory"
- "Send notifications"
- "Generate reports"

Each capability is a candidate for a service. Teams that own different capabilities are natural service owners.

**2. Follow the data ownership.**

Ask: "who is the source of truth for this data?" The service that owns data X is the only service that writes to it; everyone else reads via API or events.

- Order service owns order data.
- Inventory service owns stock levels.
- Customer service owns customer profiles.

If two services both write to the same data, the boundary is wrong. Shared databases are the clearest sign of a boundary violation.

**3. Look for the natural team boundaries.**

Conway's Law: system architecture mirrors organizational structure. If the billing team and the shipping team are separate, their services should be separate. Forcing two teams to co-own a service produces coordination overhead that defeats the purpose of splitting.

**4. Check coupling: would changes in service A force changes in service B?**

If yes → the boundary is in the wrong place. One service should own the concept entirely, or the shared concept should be split.

If service A changes how it calculates discounts and service B has to change its order-total calculation → they share a concept that should be in one place.

### The entity trap — don't split by entity

The most common mistake: one service per database table.

```text
BAD:
- UserService (manages users table)
- OrderService (manages orders table)
- OrderItemService (manages order_items table)
- AddressService (manages addresses table)
```

This produces a distributed CRUD layer with no encapsulation. Every business operation touches 4 services via synchronous calls. You've turned simple database JOINs into distributed transactions.

**The fix:** group by capability, not by entity.

```text
GOOD:
- CustomerService (manages users, addresses, preferences)
- OrderService (manages orders, order_items, order_status_history)
- InventoryService (manages products, stock, warehouses)
```

Each service owns a cohesive set of entities that belong together. An order and its items are one aggregate — splitting them into separate services is wrong.

### The coupling test

For any proposed boundary, ask:

1. **Can each service deploy independently?** If deploying A always requires deploying B simultaneously, they're not independent.
2. **Can each service have a different release cadence?** If A releases weekly and B releases daily, the boundary is working.
3. **Does each service have its own database?** Shared databases mean shared coupling. (This is a hard line in microservices orthodoxy, though pragmatic exceptions exist.)
4. **How many synchronous calls does a typical request make?** If one user action triggers a chain of 6 synchronous calls across services, the boundaries are too fine.
5. **Can you explain the service's responsibility in one sentence?** If you need a paragraph, the service does too much. If you need a sentence fragment, it does too little.

### The "too big" vs "too small" spectrum

**Too big (monolith in disguise):**

- One service owns half the domain.
- Multiple teams work on the same codebase.
- Independent deployment is impossible because everything is intertwined.

**Just right:**

- Each service maps to one bounded context or business capability.
- One team owns each service.
- Services communicate through well-defined APIs or events.
- 80% of requests can be served by a single service without cross-service calls.

**Too small (nanoservices):**

- Simple CRUD operations require 5 service calls.
- Most of the complexity is in the inter-service communication, not the business logic.
- The team spends more time debugging distributed calls than writing features.
- Latency is dominated by network hops, not computation.

When in doubt, err on the side of **too big**. It's much easier to split a service later than to merge two services. Start with a modular monolith (clear module boundaries within one codebase) and extract services when the team and complexity justify it.

### The "start with a modular monolith" approach

For a greenfield project:

1. **Build a monolith** with clear module boundaries. Each module is a directory with its own models, services, and repository interfaces.
2. **Enforce module boundaries** in code. Modules communicate through interfaces, not direct database access. A module doesn't import another module's entities.
3. **When a module needs to be independent** — different team, different scaling needs, different deployment cadence — extract it into a service. The boundary is already clean because you enforced it in the monolith.

This approach avoids the premature-decomposition trap: splitting into microservices before you understand the domain. The module boundaries let you course-correct cheaply (refactoring code vs refactoring services). By the time you extract, you know the domain well enough to draw the right lines.

### Communication across boundaries

Once boundaries are drawn, services communicate through:

**Synchronous (HTTP/gRPC):** for requests that need an immediate response. "Get this user's profile." "Validate this payment method." Keep synchronous chains short (2-3 hops max).

**Asynchronous (events):** for reactions that don't need an immediate response. "Order was placed" → billing reacts, inventory reacts, notifications react. See [../event-driven/event_driven_architecture_overview.md](../event-driven/event_driven_architecture_overview.md).

**Data duplication:** each service stores a local copy of data it needs from other services. The order service stores the customer's name and address locally (received via events), so it doesn't need to call the customer service on every order query.

### Anti-corruption layers

When a service needs to interact with another service whose model doesn't match its own, an **anti-corruption layer** (ACL) translates between the two models. The ACL prevents one service's concepts from leaking into another's domain.

```php
// In the billing service
class OrderServiceAdapter
{
    public function getOrderForBilling(string $orderId): BillingOrder
    {
        $apiResponse = $this->httpClient->get("/orders/{$orderId}");
        // Translate from the order service's model to billing's model
        return new BillingOrder(
            orderId: $apiResponse['id'],
            amount: Money::fromCents($apiResponse['total_cents']),
            // billing doesn't care about items, shipping, etc.
        );
    }
}
```

The billing service never uses the order service's DTO directly. The ACL ensures billing's domain stays clean.

> **Mid-level answer stops here.** A mid-level dev can describe bounded contexts. To sound senior, speak to the entity trap, the modular-monolith approach, and the practical coupling tests ↓
>
> **Senior signal:** knowing that boundaries are business decisions with technical consequences, and having a method for evaluating whether a boundary is in the right place.

### The rules I follow

1. **Bounded context = service.** Not entity = service.
2. **One team, one service.** Two teams sharing a service is always friction.
3. **Each service owns its data.** No shared databases.
4. **Start big, split later.** Modular monolith → extract when justified.
5. **80% of requests within one service.** If every request needs 5 services, the boundaries are wrong.
6. **Minimize synchronous dependencies.** Prefer events for cross-service communication.
7. **The coupling test on every split.** Can they deploy independently? Different cadence? Own data?

### Common mistakes

- **One service per entity.** Distributed CRUD, no encapsulation.
- **Splitting too early.** Before the domain is understood.
- **Shared databases.** Tight coupling disguised as independence.
- **Circular dependencies.** Service A calls B calls A. Usually means A and B should be one service.
- **Synchronous chains.** A → B → C → D for one user request. Fragile and slow.
- **"We'll figure out the boundaries later."** Boundaries set early are hard to change. Think about them, even if you start with a monolith.
- **Following the org chart blindly.** Conway's Law is descriptive, not prescriptive. If the org chart is wrong, the services will be wrong.

### Closing

"So service boundaries should map to bounded contexts and business capabilities, not to database tables or code modules. Each service owns its data; teams own services; communication happens through APIs and events. The entity trap — one service per entity — is the most common mistake and produces distributed CRUD. The safest approach is to start with a modular monolith, enforce module boundaries in code, and extract services when team, scaling, or deployment needs justify the operational cost. The coupling test — can they deploy independently, with different cadences, owning their own data? — is how you verify a boundary is in the right place."
