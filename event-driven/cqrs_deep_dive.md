# CQRS deep dive

**Interview framing:**

"CQRS — Command Query Responsibility Segregation — is the pattern of separating a system's write model from its read model. Instead of one data model that handles both writes and reads, you have a command side optimized for writes and a query side optimized for reads, connected by events that keep the query side in sync. The important nuance is that CQRS is a spectrum — at the simple end, it's just different classes for commands and queries; at the complex end, it's separate databases with event-driven synchronization. Most of the value comes from the conceptual separation; most of the complexity comes from the physical separation."

> This file is the canonical deep dive on CQRS. The [architecture/](../architecture/questions.md) folder links here.

### The core idea

In most applications, the data model is a compromise between write optimization and read optimization. A normalized relational schema is great for writes (no duplication, referential integrity) but bad for complex reads (lots of JOINs). A denormalized schema is great for reads (one query, no JOINs) but bad for writes (data duplication, consistency burden).

CQRS says: **don't compromise. Build two models.**

- **Command side (write model):** handles state changes. Validates business rules, enforces invariants, writes to a normalized (or event-sourced) store. Optimized for correctness.
- **Query side (read model):** handles reads. Pre-computed, denormalized, optimized for fast retrieval. Doesn't enforce business rules.

The two sides are connected by a synchronization mechanism — usually events.

### The spectrum of CQRS

**Level 1: Separate code paths, same database.**

Commands and queries use different classes/handlers but hit the same database. Commands use a rich domain model (entities, value objects, aggregates). Queries use flat DTOs or raw SQL.

```php
// Command side: rich domain model
$order = $orderRepository->get($orderId);
$order->addItem($product, $quantity);
$orderRepository->save($order);

// Query side: flat DTO, optimized SQL
$result = $connection->fetchAssociative(
    'SELECT o.id, o.total, u.email FROM orders o JOIN users u ON ...'
);
return new OrderSummaryDTO($result);
```

This is the simplest form and provides most of the benefit: clean code separation, commands that focus on business logic, queries that focus on read performance. Same database, same transaction, no eventual consistency.

**Level 2: Separate databases, event-driven sync.**

The write side has its own database (normalized, domain-optimized). The read side has its own database (denormalized, query-optimized — Elasticsearch, Redis, a materialized-view Postgres, etc.). Events from the write side are consumed by the read side to keep it up to date.

```text
Command → Write DB → Event published → Read DB updated → Query uses Read DB
```

This gives you fully independent read and write optimization, independent scaling (scale read replicas without touching writes), and different storage technologies per side. The cost: eventual consistency between write and read, plus the operational complexity of maintaining two databases and the event sync.

**Level 3: Event sourcing on the write side.**

The write side stores events as the primary data store. The read side is one or more projections built from those events. Covered in [event_sourcing_deep_dive.md](event_sourcing_deep_dive.md). This is the most powerful and most complex form.

### When CQRS is worth it

- **Read and write patterns are dramatically different.** Writes are complex business operations; reads are simple lookups on denormalized data. The two models would fight each other if combined.
- **Read and write scale independently.** 100x more reads than writes → scale the read side independently.
- **Complex read queries on a normalized write model.** Reads require expensive JOINs across many tables that would be trivially answered by a denormalized view.
- **Different storage technologies for reads.** Full-text search (Elasticsearch), graph queries (Neo4j), analytics (ClickHouse) — each is a read model fed by events from the write side.
- **The domain is complex enough to justify a rich domain model.** If the write side benefits from DDD with aggregates and invariants, CQRS gives it room to breathe without compromise.

### When CQRS is overkill

- **CRUD applications.** If the write model is "set these fields" and the read model is "get these fields", CQRS is overhead.
- **Simple domains.** If the business rules fit in a few lines of validation, a rich command model isn't worth the separation.
- **Small, simple read patterns.** If reads are straightforward queries on a well-indexed normalized database, a separate read model isn't needed.
- **Small teams.** The operational cost of maintaining two data models and a sync mechanism isn't justified.

The rule of thumb: if you find yourself fighting the data model — writes want normalization, reads want denormalization, and you can't satisfy both — CQRS is the answer. If the current model works fine for both, it's not.

### The eventual consistency challenge

In Level 2 CQRS, the read model lags behind the write model. After a command is processed:

1. The write side commits.
2. An event is published.
3. The read side processes the event and updates.
4. Queries against the read side now return the new data.

During the window between steps 1 and 4, the read model is stale. The user who just placed an order might see "no orders" on the next page load.

Solutions (same as [eventual_consistency.md](eventual_consistency.md)):

- **Read-your-own-writes.** After a command, query the write side directly for this specific user.
- **Return the result from the command.** The command response includes the created entity.
- **Optimistic UI.** The frontend assumes success and updates locally.
- **Polling until convergence.** The frontend checks the read model until the new data appears.

### The command side in detail

Commands represent intentions: `PlaceOrder`, `UpdateUserProfile`, `CancelSubscription`.

A command handler:

1. Validates the command.
2. Loads the aggregate from the write store.
3. Calls the aggregate's business method.
4. Persists the changes.
5. Publishes domain events.

```php
class PlaceOrderHandler
{
    public function handle(PlaceOrderCommand $command): void
    {
        $order = Order::place(
            $command->userId,
            $command->items,
            $command->shippingAddress
        );

        $this->orderRepository->save($order);

        $this->eventBus->publish(new OrderPlaced(
            orderId: $order->getId(),
            userId: $command->userId,
            items: $command->items,
            total: $order->getTotal(),
        ));
    }
}
```

The command handler is the only entry point for writes. It enforces business rules through the domain model. Queries never go through command handlers.

### The query side in detail

Queries represent questions: `GetOrderSummary`, `ListUserOrders`, `SearchProducts`.

A query handler:

1. Reads from the read store.
2. Returns a DTO.
3. Contains **no business logic** — it's a thin layer over a denormalized store.

```php
class GetOrderSummaryHandler
{
    public function handle(GetOrderSummaryQuery $query): OrderSummaryDTO
    {
        return $this->readDb->fetchOrderSummary($query->orderId);
    }
}
```

The read model is usually a denormalized table, a Redis hash, an Elasticsearch document, or a materialized view — whatever shape makes the query trivial.

### Projections — building the read model from events

A **projection** is the process that consumes events and builds the read model:

```php
class OrderSummaryProjection
{
    public function onOrderPlaced(OrderPlaced $event): void
    {
        $this->readDb->insert('order_summaries', [
            'order_id' => $event->orderId,
            'user_id' => $event->userId,
            'total' => $event->total,
            'status' => 'placed',
            'placed_at' => $event->occurredAt,
        ]);
    }

    public function onOrderShipped(OrderShipped $event): void
    {
        $this->readDb->update('order_summaries', [
            'status' => 'shipped',
            'shipped_at' => $event->occurredAt,
        ], ['order_id' => $event->orderId]);
    }
}
```

The projection is a **consumer** of events from the write side. It's an event-driven read-model builder. Multiple projections can exist — one for the API's order list, one for the admin dashboard, one for the search index — each producing a different read model from the same events.

If you need to rebuild a read model (schema change, bug fix, new read model added), you replay the events from the beginning and rebuild. This is one of the key benefits: read models are disposable and rebuildable.

### CQRS in Symfony

Symfony Messenger is the natural home for CQRS in PHP:

```yaml
framework:
  messenger:
    buses:
      command.bus:
        middleware:
          - doctrine_transaction
      query.bus:
        middleware: []
      event.bus:
        default_middleware:
          allow_no_handlers: true
```

Three buses: commands (transactional, one handler), queries (read-only, one handler), events (broadcast, zero or more handlers). Each has its own middleware and semantics.

```php
// Dispatching
$this->commandBus->dispatch(new PlaceOrderCommand(...));
$summary = $this->queryBus->dispatch(new GetOrderSummaryQuery($orderId));
```

This is Level 1 CQRS — same database, separate code paths, clear conceptual separation. Moving to Level 2 (separate databases) requires adding event consumers that build the read store, which Messenger also handles via async transports.

### The mental model

```text
┌─────────────────────────────────────────────┐
│                   Client                    │
│                                             │
│         ┌──────────┐  ┌──────────┐          │
│         │ Commands │  │ Queries  │          │
│         └────┬─────┘  └────┬─────┘          │
└──────────────┼──────────────┼───────────────┘
               │              │
        ┌──────▼──────┐ ┌─────▼──────┐
        │ Write Model │ │ Read Model │
        │ (normalized)│ │(denormalized)│
        │  Domain     │ │  DTOs      │
        └──────┬──────┘ └─────▲──────┘
               │              │
               │   ┌──────┐   │
               └──→│Events│───┘
                   └──────┘
```

Commands → write model → events → read model → queries. Clean separation.

> **Mid-level answer stops here.** A mid-level dev can describe the separation. To sound senior, speak to the spectrum, when each level is appropriate, and the operational concerns of running CQRS at Level 2+ ↓
>
> **Senior signal:** articulating CQRS as a spectrum where Level 1 gives most of the benefit and Levels 2-3 add complexity that must be justified.

### The decision framework

1. **Do reads and writes need different models?** No → don't use CQRS. Yes → Level 1 at minimum.
2. **Do reads and writes need different databases?** No → Level 1 is fine. Yes → Level 2.
3. **Does the write side benefit from event sourcing?** No → Level 2. Yes → Level 3.
4. **Can you tolerate eventual consistency on reads?** No → stay at Level 1. Yes → Levels 2 and 3 are options.

Most systems benefit from Level 1 (separate code paths) and don't need Level 2 (separate databases). Jump to Level 2 only when the data or scaling requirements demand it.

### Common mistakes

- **Applying CQRS everywhere.** It's a pattern for specific bounded contexts, not a system-wide mandate.
- **Level 2 when Level 1 suffices.** The eventual consistency and operational complexity of separate databases aren't justified for most services.
- **Commands that return data.** Pure CQRS says commands return void; pragmatic CQRS says returning the created ID is fine. Don't return full domain objects from commands.
- **Business logic in projections.** The read side should be dumb. Business logic belongs in the command handlers and domain model.
- **Not handling eventual consistency in the UI.** Users see stale data and blame the system.
- **Not being able to rebuild projections.** If you lose the read model and can't rebuild it from events, you have a data loss problem.
- **Over-engineering the query side.** A simple SQL query against the same database is often the right read model. You don't always need Elasticsearch.

### Closing

"So CQRS separates write models from read models, ranging from code-level separation (Level 1, same database) to physical separation (Level 2, different databases) to event sourcing (Level 3, events as the write store). Level 1 gives most of the benefit — clean code, optimized reads and writes — with none of the eventual-consistency complexity. Level 2 adds independent scaling and storage-technology freedom at the cost of eventual consistency. Level 3 adds full event replay and audit. Start at Level 1, move up only when the requirements demand it, and always have a strategy for the consistency window between write and read."
