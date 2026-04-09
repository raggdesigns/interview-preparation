# Event sourcing deep dive

**Interview framing:**

"Event sourcing is the pattern where the primary data store is a sequence of events — not the current state of an entity, but every state change that ever happened to it. Current state is derived by replaying those events from the beginning. Instead of storing 'the order total is $50 and the status is shipped', you store 'OrderPlaced($50)', 'ItemAdded($10)', 'ItemRemoved($10)', 'OrderShipped'. The current state is the result of applying those events in order. The payoff is a complete audit trail, the ability to rebuild any read model by replaying events, and the ability to answer questions about the past that you didn't think to ask at the time. The cost is significant complexity in every other dimension."

> This file is the canonical deep dive on event sourcing. The [architecture/](../architecture/questions.md) folder links here.

### The model

In traditional CRUD, you have a table of current-state rows:

```text
orders table:
| id  | user_id | total | status   |
| 42  | 7       | 50.00 | shipped  |
```

In event sourcing, you have an event stream per aggregate:

```text
order-42 stream:
| seq | event_type     | data                                    | timestamp           |
| 1   | OrderPlaced    | {user_id: 7, items: [...], total: 39.98}| 2026-04-01T10:00:00 |
| 2   | ItemAdded      | {sku: "XYZ", qty: 1, price: 10.02}     | 2026-04-01T10:01:00 |
| 3   | OrderConfirmed |                                         | 2026-04-01T10:05:00 |
| 4   | OrderShipped   | {tracking: "1Z999AA1..."}               | 2026-04-02T14:00:00 |
```

The current state — `total: 50.00, status: shipped` — is derived by replaying these events. There is no mutable row that gets updated.

### How state is rebuilt

An aggregate in event sourcing has an `apply` method for each event type. Loading an aggregate means fetching its events and applying them in order:

```php
class Order
{
    private OrderId $id;
    private Money $total;
    private OrderStatus $status;
    private array $items = [];

    public static function fromEvents(array $events): self
    {
        $order = new self();
        foreach ($events as $event) {
            $order->apply($event);
        }
        return $order;
    }

    private function apply(object $event): void
    {
        match (true) {
            $event instanceof OrderPlaced => $this->applyOrderPlaced($event),
            $event instanceof ItemAdded => $this->applyItemAdded($event),
            $event instanceof OrderConfirmed => $this->applyOrderConfirmed($event),
            $event instanceof OrderShipped => $this->applyOrderShipped($event),
        };
    }

    private function applyOrderPlaced(OrderPlaced $event): void
    {
        $this->id = $event->orderId;
        $this->total = $event->total;
        $this->status = OrderStatus::PLACED;
        $this->items = $event->items;
    }

    private function applyItemAdded(ItemAdded $event): void
    {
        $this->items[] = $event->item;
        $this->total = $this->total->add($event->price);
    }

    // ...
}
```

Each event mutates the aggregate's internal state. After replaying all events, the aggregate is in its current state.

### The event store

The event store is a persistent, append-only log of events. Key properties:

- **Append-only.** Events are never updated or deleted. They're immutable facts.
- **Ordered per stream.** Events within a single aggregate's stream are strictly ordered by sequence number.
- **Globally ordered** (optional but useful). Some stores assign a global position to every event, enabling cross-aggregate projections.
- **Optimistic concurrency.** When saving new events, the store checks that the expected version matches the current version — preventing concurrent writes from corrupting the aggregate.

Implementations:

- **EventStoreDB** — purpose-built event store. Projections, subscriptions, catch-up subscriptions. The most feature-complete option.
- **PostgreSQL with an events table** — a relational table acting as an event store. Simple, portable, requires building projections yourself.
- **Kafka** (sort of) — Kafka's log is append-only and ordered, but it lacks optimistic concurrency per-stream. Better for event streaming than for aggregate-level event sourcing.

A minimal PostgreSQL event store table:

```sql
CREATE TABLE events (
    global_position BIGSERIAL PRIMARY KEY,
    stream_id TEXT NOT NULL,
    version INTEGER NOT NULL,
    event_type TEXT NOT NULL,
    data JSONB NOT NULL,
    metadata JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (stream_id, version)
);
```

The `UNIQUE (stream_id, version)` constraint provides optimistic concurrency: two concurrent writes to the same stream with the same version will conflict, and one will fail.

### Projections — the read side

Since the event store is not optimized for queries (it's optimized for write-and-replay), you build **projections**: read models derived from the event stream.

A projection is a consumer that reads events and builds a materialized view. The same events can produce multiple projections:

- **Order list** — a denormalized table of orders for the API.
- **User dashboard** — aggregated stats per user.
- **Search index** — Elasticsearch documents for full-text search.
- **Analytics** — event counts, trends, funnels.

Each projection is **independently rebuildable**. If you add a new projection or fix a bug in an existing one, you replay the events from the beginning and regenerate it. This is the core superpower of event sourcing: **read models are disposable and rebuildable**.

### Snapshots — the performance optimization

For aggregates with thousands of events, replaying from the beginning on every load is slow. Snapshots periodically save the current state, and loading starts from the snapshot instead of event 1.

```text
Events: [1, 2, 3, ..., 998, 999, 1000]
Snapshot at event 1000: {total: 50.00, status: shipped, items: [...]}

Loading: read snapshot (event 1000) + replay events 1001+
```

Snapshots are an optimization, not a requirement. They're stored alongside the event stream and don't replace it. If a snapshot is corrupted or outdated, you can always rebuild from events.

Implementation: periodically (every N events or on a schedule), serialize the aggregate's state and store it with the version number. On load, fetch the latest snapshot and only replay events after that version.

### When event sourcing is worth it

- **Complete audit trail is a requirement.** Financial systems, regulatory environments, compliance — where "what happened and when" is not optional.
- **Temporal queries are valuable.** "What was the state of this order at 3pm yesterday?" — trivially answered by replaying events up to that point.
- **Multiple read models from the same data.** The event stream feeds different projections for different use cases.
- **Complex domain with rich state transitions.** If the business logic is about state machines and transitions (order processing, claim handling, approval workflows), event sourcing maps naturally.
- **CQRS Level 3 — events as the write store.** The most powerful form of CQRS.
- **Debugging and forensics.** "How did the system get into this state?" — replay the events and watch.

### When event sourcing is NOT worth it

- **CRUD domains.** If the business logic is "set these fields", event sourcing is massive overhead.
- **Simple entities without meaningful state transitions.** A user profile that gets updated occasionally doesn't benefit.
- **When the team has no experience with it.** Event sourcing has a steep learning curve and a long list of gotchas. Introducing it without preparation leads to pain.
- **When you don't need the audit trail or temporal queries.** If you just want CQRS, Level 1 or 2 is simpler.
- **When event schema evolution is going to be a nightmare.** If your domain model changes frequently and unpredictably, evolving the event schema is hard.

The honest answer: most systems don't need event sourcing. It's powerful for specific domains and expensive everywhere else. Don't use it because it's interesting; use it because the domain requires it.

### Event schema evolution — the hardest problem

Events are immutable. But the domain model evolves. What happens when:

- **You rename a field.** Old events have `customer_id`; new code expects `user_id`.
- **You add a required field.** Old events don't have it.
- **You split an event.** `OrderUpdated` becomes `ItemAdded` and `AddressChanged`.
- **You change the semantics.** `amount` used to be in cents; now it's in dollars.

Strategies:

- **Upcasting.** When loading old events, transform them to the current schema. A function that takes a version-1 event and returns a version-2 event. Applied at read time, not write time.
- **Versioned event types.** `OrderPlaced_v1`, `OrderPlaced_v2`. The aggregate knows how to apply both.
- **Weak schema.** Use JSONB and be tolerant of missing fields with defaults.
- **Event migration scripts.** Rewrite old events in the store. Controversial because events are supposed to be immutable, but sometimes necessary.

Upcasting is the most common approach. The event store holds the original events; the aggregate applies upcasters during replay. Old events are never modified; their interpretation evolves.

### Event sourcing and CQRS — the natural pair

Event sourcing almost always comes with CQRS because the event store is a terrible query interface. You need projections (read models) for queries, and projections are the query side of CQRS.

The combination:

- **Write side:** commands → aggregate → new events → event store.
- **Sync:** events are consumed by projections.
- **Read side:** queries → projections → DTOs.

This is the Level 3 CQRS from [cqrs_deep_dive.md](cqrs_deep_dive.md).

### Event sourcing in PHP

Libraries:

- **prooph/event-store** — the most established PHP event sourcing library. Supports PostgreSQL, MySQL, and in-memory stores. Provides aggregates, projections, and snapshotting.
- **broadway/broadway** — another PHP event sourcing framework. Simpler API, Doctrine-based storage.
- **ecotone** — a PHP framework with built-in event sourcing, CQRS, and saga support. Integrates with Symfony and Laravel.
- **DIY** — an events table in PostgreSQL with Doctrine or raw PDO. Simple and transparent but you build everything yourself.

For most PHP teams starting with event sourcing, ecotone or a simple PostgreSQL table is the pragmatic starting point. prooph is more mature but has more ceremony.

### The operational concerns

- **Event store growth.** The store grows monotonically — events are never deleted. Storage planning and retention strategies (archiving old streams to cold storage) are necessary.
- **Projection rebuild time.** Rebuilding a projection from millions of events can take hours. Design for this — incremental rebuilds, parallel processing, or accepting the rebuild time as a maintenance window.
- **Eventual consistency between projections and the event store.** Same concerns as any CQRS system — see [eventual_consistency.md](eventual_consistency.md).
- **Schema evolution.** Upcasters need to be tested and maintained. Every schema change adds a new upcaster to the chain.
- **Debugging is different.** "What's in the database?" becomes "what events have been recorded?" The mental model is different from CRUD debugging.

> **Mid-level answer stops here.** A mid-level dev can describe event sourcing. To sound senior, speak to when it's the wrong choice, the schema evolution challenge, and the operational realities ↓
>
> **Senior signal:** articulating that event sourcing is a high-cost, high-value pattern for specific domains, and knowing the cost side as well as the benefit side.

### The honest assessment

Event sourcing is one of the most powerful patterns in software design and one of the easiest to misapply. The teams that succeed with it share these traits:

- **The domain genuinely has rich state transitions.** Orders, claims, workflows, financial instruments.
- **The audit trail is a business requirement, not a nice-to-have.**
- **The team has invested in learning the pattern** before applying it to production code.
- **They use event sourcing selectively** — for specific bounded contexts, not for the entire system.
- **They have a schema evolution strategy** from day one.

The teams that struggle have adopted it because it's interesting, applied it to CRUD domains, and discovered that the complexity is real.

### Common mistakes

- **Event sourcing everything.** Use it for the bounded contexts that benefit; use CRUD for the rest.
- **Mutable events.** Events are immutable. If you're updating events in the store, you're not doing event sourcing.
- **Events that are "state dumps."** `OrderUpdated({...full order state...})` is a snapshot, not an event. Events should be granular state changes.
- **No schema evolution strategy.** The first schema change will be a crisis.
- **Projection as the primary source of truth.** The event store is the source of truth; projections are derived. If they disagree, trust the events.
- **Forgetting about snapshots.** Aggregates with 100K+ events take forever to load without snapshots.
- **No projection rebuild mechanism.** The ability to rebuild is the superpower; without it, event sourcing is just a complex write log.
- **Using event sourcing when you just want an audit log.** An append-only audit table is simpler and gives you the audit trail without the complexity.

### Closing

"So event sourcing stores every state change as an immutable event, derives current state by replaying events, and builds read models through projections that can be independently rebuilt. The benefits are complete audit, temporal queries, and multiple read models from one source. The costs are schema evolution complexity, projection rebuild time, eventual consistency, and a steep learning curve. Use it for domains with rich state transitions and audit requirements; don't use it for CRUD. Pair it with CQRS (which it essentially requires) and have a schema evolution strategy from day one. Done right, it's a superpower; done wrong, it's a maintenance burden that outweighs the benefits."
