# Event-driven architecture overview

**Interview framing:**

"Event-driven architecture is a design approach where components communicate by producing and consuming events — records of things that happened — rather than calling each other directly. The fundamental shift is from 'service A tells service B what to do' to 'service A announces what happened, and whoever cares reacts'. That shift is what gives you loose coupling, independent scalability, and the ability to add new consumers to a system without touching existing producers. It's also what gives you eventual consistency, debugging complexity, and distributed-system failure modes. The senior conversation is about knowing when the trade-offs are worth it."

### What an event is

An event is a record of something that happened in the past. `OrderPlaced`, `PaymentCaptured`, `UserSignedUp`, `InventoryReserved`. It describes a fact — something that already occurred — not a request for something to occur.

The distinction matters because events are **immutable facts**. Once an order was placed, it was placed. You can't un-place it by rejecting the event. You can react to it (cancel the order, refund the payment), but the event itself stands as a historical record.

An event typically contains:

- **Event type** — `OrderPlaced`, `UserSignedUp`.
- **Timestamp** — when it happened.
- **Aggregate/entity ID** — which entity it happened to (order ID, user ID).
- **Payload** — the data relevant to the event (order details, user profile).
- **Metadata** — correlation IDs, causation IDs, producer service name, schema version.

### The three styles of event-driven

**1. Event notification** — "something happened, look it up if you care"

The event carries minimal data — just enough for consumers to know *what* happened and *to what*. If a consumer needs details, it queries the producer's API.

```json
{"event": "OrderPlaced", "order_id": "abc-123", "timestamp": "2026-04-09T14:23:00Z"}
```

Pros: small events, producers don't leak internal structure. Cons: consumers need access to the producer's API; runtime coupling.

**2. Event-carried state transfer** — "something happened, here's everything you need"

The event carries the full state needed for consumers to act without calling back.

```json
{
  "event": "OrderPlaced",
  "order_id": "abc-123",
  "user_id": "42",
  "items": [{"sku": "XYZ", "qty": 2, "price": 19.99}],
  "total": 39.98,
  "currency": "USD",
  "shipping_address": {...}
}
```

Pros: consumers are fully decoupled; no runtime dependency on the producer. Cons: larger events, consumers may see more data than they need, schema evolution is harder.

**3. Event sourcing** — "the event stream *is* the source of truth"

Events are not just notifications; they're the primary data store. Current state is derived by replaying events from the beginning. Covered in [event_sourcing_deep_dive.md](event_sourcing_deep_dive.md).

Most systems use style 2 (event-carried state transfer) for cross-service communication. Style 1 is simpler but reintroduces coupling. Style 3 is powerful but complex.

### Why event-driven

The benefits compound as the system grows:

- **Loose coupling.** Producers and consumers don't know about each other. The producer emits events; whoever cares subscribes. Adding a new consumer doesn't require changing the producer.
- **Independent scalability.** A slow consumer doesn't slow down the producer. Each service scales based on its own load.
- **Temporal decoupling.** The producer doesn't wait for the consumer. If the consumer is down, events queue and are processed later.
- **Extensibility.** "We need analytics on every order" → subscribe a new consumer to `OrderPlaced`. Zero changes to the order service.
- **Audit trail.** Events are a natural log of what happened, when, and why.
- **Resilience.** If a downstream service fails, events buffer in the broker. Recovery is eventual, not immediate — but it's automatic.

### Why NOT event-driven

The costs are real:

- **Eventual consistency.** After an event is published, it takes time for consumers to process it. During that window, the system is inconsistent. Users may see stale data, partially-completed workflows, or contradictory states.
- **Debugging complexity.** A synchronous call stack is a straight line. An event-driven flow is a graph, with events triggering events triggering events. Tracing a specific business outcome across multiple services and multiple event handlers is genuinely hard.
- **Ordering challenges.** Events may arrive out of order (broker redelivery, partitioning, parallel consumers). Consumers need to handle out-of-order delivery or the broker needs to guarantee ordering.
- **Idempotency requirement.** At-least-once delivery means consumers must handle duplicates. This is a universal requirement in event-driven systems.
- **Schema evolution.** Events are a public contract. Changing the schema of an event affects every consumer. You need versioning, backward compatibility, and a migration strategy.
- **Operational complexity.** A message broker is another piece of infrastructure to run, monitor, and debug.
- **Testing complexity.** Testing an event-driven flow end-to-end requires setting up producers, consumers, and a broker. Integration tests are harder.

### When event-driven is worth it

- **Multiple services need to react to the same event.** One producer, many consumers. The canonical use case.
- **Services need to be independently deployable and scalable.** Tight coupling via synchronous calls prevents this.
- **The workflow is inherently asynchronous.** Sending email, processing payments, generating reports — these don't need to happen in the request path.
- **You need an audit trail.** Events are a natural audit log.
- **The domain is event-rich.** E-commerce, logistics, finance — domains where "things happen" and multiple parties react.

### When event-driven is overkill

- **Two or three services with simple, synchronous interactions.** A REST call between two services is simpler and easier to debug.
- **Workflows that must be strongly consistent.** If the user must see the result immediately and it must be correct, synchronous processing is simpler.
- **Small teams that don't need independent deployment.** The decoupling benefit compounds with team count; for a small team working on a monolith, it's overhead.
- **Low traffic systems.** The operational cost of a broker and the complexity of eventual consistency aren't justified if you're handling 10 requests per minute.

### The hybrid — event-driven at the boundaries, synchronous inside

Most real systems aren't "all events" or "all synchronous". The common pattern:

- **Inside a service:** synchronous calls between modules. Direct function calls, database transactions, request-response.
- **Between services:** events. Each service publishes events about what happened; other services subscribe.
- **For user-facing requests:** synchronous within the service that handles the request; asynchronous for downstream work. The user gets a response immediately; background processing happens via events.

This hybrid is the most pragmatic and most common architecture for medium-to-large systems.

### Event design principles

- **Past tense.** `OrderPlaced`, not `PlaceOrder`. Events describe what happened, not what should happen.
- **Immutable.** Once published, an event doesn't change.
- **Self-contained (for cross-service events).** Consumers shouldn't need to call back to the producer.
- **Versioned.** Include a `schema_version` field. Consumers can handle version differences.
- **Identified.** Each event has a unique ID, an aggregate ID, and a correlation ID for tracing.
- **Ordered within an aggregate.** Events for the same order should be processed in order. Events for different orders can be parallel.

### Event schemas and evolution

Events are a public API. Schema changes need the same discipline as API versioning:

- **Additive changes are safe.** Adding a new field doesn't break existing consumers (they ignore it).
- **Removing a required field is breaking.** Existing consumers will fail.
- **Renaming fields is breaking.** Same as removing + adding.
- **Use a schema registry.** If you're on Kafka, the Confluent Schema Registry enforces compatibility. For RabbitMQ, document schemas and enforce in CI.

### The event bus — where events live

The "event bus" is whatever infrastructure carries events. In practice:

- **RabbitMQ** — topic exchanges, fan-out to queues per consumer. Good for task routing and per-message acks. See [../message-brokers/rabbitmq_core_model.md](../message-brokers/rabbitmq_core_model.md).
- **Kafka** — durable log, consumer groups, replay. Good for event streams and CDC. See [../message-brokers/rabbitmq_vs_kafka.md](../message-brokers/rabbitmq_vs_kafka.md).
- **Symfony Messenger** — for events within a single PHP application that need async processing.
- **In-process event dispatchers** — for events within a single request/transaction. Symfony's EventDispatcher, Laravel's Events.

Pick based on the durability, replay, and throughput requirements (see the [message-brokers/](../message-brokers/questions.md) folder for the full comparison).

> **Mid-level answer stops here.** A mid-level dev can describe events and pub/sub. To sound senior, speak to the trade-offs, the hybrid model, and the design discipline that makes event-driven systems reliable ↓
>
> **Senior signal:** articulating when event-driven is the wrong choice as clearly as when it's the right one.

### The mental model I keep

"Event-driven is a coupling trade-off. You trade tight runtime coupling (synchronous calls, shared databases) for loose runtime coupling (events, independent data stores) — but you gain temporal coupling (eventual consistency), schema coupling (event contracts), and operational coupling (shared broker infrastructure). The net result is usually positive for systems with many producers and consumers, and negative for systems with simple point-to-point flows."

### Common mistakes

- **Events for everything.** Not every interaction needs to be an event. Simple request-response between two services is fine.
- **Events as remote procedure calls.** Publishing `CreateUser` as an event and expecting a response → that's a command, not an event, and the pattern is wrong.
- **No schema versioning.** Changing event shapes breaks consumers silently.
- **Assuming events arrive in order.** Broker redelivery, parallel consumers, and network reordering mean out-of-order is normal.
- **No idempotency.** At-least-once delivery means duplicates are guaranteed.
- **Tight coupling disguised as events.** If changing the producer's events requires changing every consumer simultaneously, you don't have loose coupling.
- **No dead-letter handling.** Failed events must go somewhere. See [../message-brokers/rabbitmq_dead_letter_exchanges.md](../message-brokers/rabbitmq_dead_letter_exchanges.md).
- **Eventual consistency without user communication.** If the user creates an order and immediately sees "no orders found" because the read model hasn't caught up, the UX is broken even if the architecture is correct.

### Closing

"So event-driven architecture is communication via facts — 'this happened' — rather than via commands — 'do this'. The benefits are loose coupling, independent scalability, extensibility, and a natural audit trail. The costs are eventual consistency, debugging complexity, ordering challenges, and operational overhead. Most real systems use a hybrid: synchronous inside services, events between them. The senior skill is knowing where the boundary should be and designing events with the same versioning, schema, and idempotency discipline you'd apply to any other public API."
