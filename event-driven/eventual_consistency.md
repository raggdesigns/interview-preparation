# Eventual consistency

**Interview framing:**

"Eventual consistency is the property that, given enough time without new writes, all nodes in a distributed system will converge to the same state. It's the price you pay for the performance, availability, and scalability benefits of not requiring immediate, synchronous agreement. The senior insight is that 'eventual' can mean milliseconds or minutes — the duration matters enormously for UX — and that the real engineering work isn't in accepting eventual consistency but in making it invisible to users."

### The CAP context

The CAP theorem says you can have at most two of three properties: Consistency, Availability, Partition tolerance. Since network partitions are unavoidable in distributed systems, the real trade-off is between consistency and availability during a partition.

- **CP systems** (strong consistency, sacrifice availability during partitions): every read returns the latest write, but some requests may be rejected during a partition. Traditional RDBMS in single-primary setups.
- **AP systems** (availability, sacrifice consistency during partitions): every request gets a response, but the response may be stale. Most event-driven systems, most caching layers, most distributed databases in their default mode.

Event-driven architectures are AP by nature: the producer publishes, the consumer processes later, and during the delay the consumer's state is stale. That's eventual consistency.

### What "eventual" actually means

"Eventually consistent" doesn't mean "inconsistent forever". It means there's a window — the **consistency window** — during which different parts of the system disagree.

For most well-designed systems, that window is:

- **Milliseconds to seconds** for in-memory caches and local replicas.
- **Seconds to a few minutes** for event-driven consumers processing via a broker.
- **Minutes to hours** for batch-processing systems, ETL, and data warehouses.

The duration of the consistency window is an engineering parameter you control — through consumer throughput, broker latency, batch frequency, and architecture choices.

### Where eventual consistency shows up in practice

- **Between a database write and a cache update.** The cache holds stale data until the invalidation arrives.
- **Between an event publish and a consumer's reaction.** The billing service hasn't processed the order yet, but the order service has already confirmed it.
- **Between the primary database and a read replica.** Replication lag makes replicas stale.
- **Between a write and a search index update.** Elasticsearch or Algolia lag behind the source database.
- **Between services in a CQRS architecture.** The command side has the latest state; the query side catches up via events. See [cqrs_deep_dive.md](cqrs_deep_dive.md).

### Making eventual consistency work for users

The real skill is not tolerating inconsistency — it's hiding it from users:

**1. Read-your-own-writes.** After a user creates an order, the next page load should show that order — even if the read model hasn't caught up. Solutions:

- Route the user's request to the primary database (not a replica) for a short window after writes.
- Include the new data in the response directly (the write response includes the created order).
- Show a "processing" state derived from the client's local knowledge, not from the eventually-consistent read model.

**2. Optimistic UI.** The UI shows the expected result immediately, then reconciles when the backend catches up. "Your order has been placed" before the order service has finished processing — because the command was accepted and the probability of failure is low.

**3. Polling or push for convergence.** After a write, the client polls or subscribes to updates until the read model catches up. WebSocket or SSE pushes the update to the UI when it's ready.

**4. Explicit status transitions.** Instead of hiding the delay, make it part of the UX: "Order submitted → Processing → Confirmed". Each transition is an event; the UI reflects the current state in the workflow.

**5. Designing for the consistency window.** If the window is 200ms and the next page load takes 500ms, the user never sees the inconsistency. If the window is 30 seconds and the next action is immediate, you need one of the above patterns.

### The consistency spectrum

Strong consistency and eventual consistency are not binary — there's a spectrum:

- **Strong (linearizable).** Every read sees the latest write. Expensive, serialized.
- **Sequential.** All nodes see operations in the same order, but the order may lag behind real time.
- **Causal.** Causally-related operations are seen in order; unrelated operations may be reordered.
- **Eventual.** Given time, all nodes converge. No ordering guarantee in the interim.

Most practical systems use causal or eventual consistency and overlay patterns (read-your-own-writes, causal ordering) to give users a stronger-than-eventual experience without paying the full cost of strong consistency.

### Eventual consistency and DDD

In Domain-Driven Design, eventual consistency maps naturally to bounded context boundaries:

- **Within a bounded context (within a service):** strong consistency. One database, one transaction, one source of truth.
- **Between bounded contexts (between services):** eventual consistency. Events carry state changes across boundaries; each context processes them at its own pace.

This is the principle that makes microservices viable: each service owns its own data and maintains strong consistency internally, while accepting eventual consistency with other services.

The DDD rule: if two pieces of data must be immediately consistent, they belong in the same bounded context. If they can tolerate a delay, they can be in separate contexts.

### Conflict resolution

When multiple writers can update the same data concurrently (e.g., geo-distributed systems, offline clients), eventual consistency produces **conflicts**: two versions of the same record that disagree.

Resolution strategies:

- **Last-write-wins (LWW).** The most recent write wins based on a timestamp. Simple but loses data.
- **Application-level merge.** The application defines how to merge conflicting versions (e.g., union of two lists, max of two counters). Domain-specific and more correct.
- **CRDTs (Conflict-free Replicated Data Types).** Data structures designed so that all concurrent operations can be merged automatically without conflicts. Counters, sets, registers — specific types with specific semantics.
- **Manual resolution.** Surface the conflict to the user ("you edited this document from two devices"). Google Docs, Git.

Most backend systems avoid the conflict problem entirely by using single-primary writes: one service owns each piece of data, and only that service writes to it. Conflicts only arise in multi-primary or offline scenarios.

### Eventual consistency and transactions

The hardest part: what happens when a business operation spans multiple services that are only eventually consistent?

"Deduct inventory and charge payment for an order" — if these are in different services communicating via events, there's no single transaction. The saga pattern (see [saga_pattern.md](saga_pattern.md)) is the standard solution: a sequence of local transactions coordinated by events, with compensating actions when a step fails.

The rule: **don't try to build distributed transactions across eventually-consistent boundaries.** Instead, accept that each service commits locally, communicate via events, and handle failures with compensation.

### Monitoring eventual consistency

You should measure the consistency window:

- **Consumer lag.** How far behind is each consumer? Measure the time between event publication and event processing.
- **Replication lag.** How far behind are read replicas?
- **Cache staleness.** How long before a cache entry is updated after the source changes?
- **Search index lag.** How long before a new record appears in search results?

Alert when lag exceeds the acceptable window. A consumer that's 5 minutes behind might be fine; 2 hours behind is probably a bug.

> **Mid-level answer stops here.** A mid-level dev can define eventual consistency. To sound senior, speak to the UX strategies, the consistency window as an engineering parameter, and the relationship to bounded contexts ↓
>
> **Senior signal:** treating eventual consistency as a design decision with a measurable parameter (the window), not an abstract property.

### The conversation I have with product

"This feature crosses service boundaries, which means it's eventually consistent. The typical delay is under 2 seconds. Here's what the user will see during that 2-second window: [describe]. Here are the patterns we'll use to make it feel instant: [read-your-own-writes / optimistic UI / status transitions]. The trade-off is simpler architecture and independent scalability in exchange for a brief moment where the data might look stale. For this feature, the stale window is shorter than a page navigation, so users won't notice."

That conversation — specific, measured, with a UX strategy — is what separates "we accept eventual consistency" (hand-wave) from "we designed for it" (engineering).

### Common mistakes

- **"It's eventually consistent" as an excuse for poor UX.** Users don't care about your architecture; they care that the thing they just created appears on the next page.
- **Not measuring the consistency window.** If you don't know how long "eventually" is, you can't design around it.
- **Assuming events are instant.** Consumer lag, broker latency, processing time — all contribute.
- **Strong consistency where eventual would suffice.** Over-engineering with distributed locks and two-phase commits when a 2-second delay is fine.
- **Eventual consistency where strong is required.** Financial reconciliation, regulatory requirements, anything where "close enough" isn't good enough.
- **No compensation for failures.** If step 2 of a saga fails, step 1's effect must be reversed. Without compensation, the system drifts into an inconsistent state permanently.
- **Not communicating the consistency model to the team.** Engineers who don't know which boundaries are eventually consistent will write bugs that assume strong consistency.

### Closing

"So eventual consistency is the property that, given time, all parts of the system converge. The consistency window is the delay — it's an engineering parameter, not a fixed constant. The senior practice is designing the UX around the window (read-your-own-writes, optimistic UI, status transitions), measuring the window (consumer lag, replication lag), and being explicit about which boundaries are eventually consistent and which are strongly consistent. Strong consistency within a service, eventual consistency between services, and UI patterns that hide the gap — that's the pragmatic architecture."
