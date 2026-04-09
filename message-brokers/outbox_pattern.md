# The outbox pattern

**Interview framing:**

"The outbox pattern solves one of the most insidious bugs in distributed systems: the dual-write problem. You have a database write and a message publish that both need to succeed or both need to fail — but they're in two different systems, so there's no shared transaction. Naive implementations produce silent inconsistency: the database says one thing, the message broker says another, and nobody notices until a customer complains weeks later. The outbox pattern fixes this by turning a cross-system problem into a single-system problem, using the database you already trust."

### The problem: dual writes

Consider this common code shape:

```php
// Commit the order to the database.
$order = new Order(...);
$this->entityManager->persist($order);
$this->entityManager->flush();

// Publish an event so other services can react.
$this->messageBus->dispatch(new OrderCreated($order->getId()));
```

It looks fine. It compiles. It works most of the time. The failure mode:

1. `flush()` commits the order to the database. ✅
2. The PHP process crashes before `dispatch()` runs. ❌

The order exists in the database; the event was never published; downstream services — billing, inventory, analytics, notifications — never find out. The data is inconsistent and there's no mechanism that will ever fix it.

Or the opposite failure:

1. `dispatch()` publishes the event. ✅
2. `flush()` fails because of a database error. ❌

The event exists in the broker; the order doesn't exist in the database. Downstream services try to process an order that doesn't exist.

Either way, **you have two systems with no shared transaction, and any non-atomic sequence between them is a bug waiting to happen.**

### The (non-)solution: reverse the order

"What if I publish first, then write the database?" — same problem in reverse. "What if I use a distributed transaction?" — 2PC is expensive, operationally painful, and most message brokers don't support it. "What if I ignore the problem?" — you're building bugs that show up in production and are nearly impossible to diagnose after the fact.

### The outbox pattern: make it a single-system problem

The insight: a database has transactions. If you write both "the order" and "the event I want to publish" to the database in the same transaction, they succeed or fail atomically. Then a separate process reads the unpublished events from the database and actually publishes them to the broker.

The flow:

1. **Inside the request transaction:** write the business data *and* an outbox row describing the event to the same database, in the same transaction.
2. **Separately, a relay process:** read unpublished outbox rows, publish them to the broker, mark them as published.

```text
┌────────────────────────────────────────────────┐
│ Transaction (atomic):                          │
│                                                │
│   INSERT INTO orders (...)                     │
│   INSERT INTO outbox (event_type, payload, ...)│
│                                                │
│ COMMIT                                         │
└────────────────────────────────────────────────┘

                    │
                    │ (separate process)
                    ▼

┌────────────────────────────────────────────────┐
│ SELECT * FROM outbox WHERE published = false   │
│    FOR UPDATE SKIP LOCKED                      │
│                                                │
│ For each row:                                  │
│   publish to broker                            │
│   UPDATE outbox SET published = true           │
└────────────────────────────────────────────────┘
```

Now the cross-system consistency problem is gone: either both the order and the outbox row exist (transaction committed), or neither does (transaction rolled back). The relay handles eventual publishing, at-least-once, with its own retry logic.

### The outbox table schema

A minimal outbox table:

```sql
CREATE TABLE outbox (
    id BIGSERIAL PRIMARY KEY,
    aggregate_type VARCHAR(100) NOT NULL,
    aggregate_id VARCHAR(100) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    published_at TIMESTAMPTZ NULL,
    INDEX (published_at) WHERE published_at IS NULL
);
```

Key design choices:

- **Payload stored as JSON/JSONB.** The outbox doesn't care about the schema; it just stores and forwards.
- **Partial index on unpublished rows.** The relay scans for unpublished events; a partial index makes this cheap even when the table has millions of published rows.
- **`published_at` timestamp, not a boolean.** Useful for debugging latency and for garbage collection.
- **Aggregate info for routing and debugging.** Not strictly necessary but makes the table much easier to inspect.

### The relay — two implementations

**1. Polling relay (simple, portable).** A background process that polls the outbox table on a short interval, picks up unpublished rows, publishes them, and marks them as published.

```php
// Pseudocode
while (true) {
    $events = $db->query("
        SELECT * FROM outbox
        WHERE published_at IS NULL
        ORDER BY id
        LIMIT 100
        FOR UPDATE SKIP LOCKED
    ");

    foreach ($events as $event) {
        $this->broker->publish($event->event_type, $event->payload);
        $db->execute("
            UPDATE outbox
            SET published_at = NOW()
            WHERE id = ?
        ", $event->id);
    }

    sleep(1);
}
```

`FOR UPDATE SKIP LOCKED` is what lets you run multiple relay workers in parallel without them stepping on each other. Each picks up a disjoint batch of rows.

Pros: simple, works on any database, easy to reason about.
Cons: latency floor equal to the poll interval; read load on the database proportional to the poll rate.

**2. CDC-based relay (lower latency, more moving parts).** Change data capture — reading the database's replication log and publishing changes as they happen. For Postgres, this is `pgoutput` + a logical replication slot, consumed by a tool like Debezium. The relay never polls; it reacts to the WAL in real time.

Pros: sub-second latency, no polling load on the database.
Cons: operational complexity (Debezium or a similar tool), replication slot management, schema evolution concerns.

For most systems, the polling relay is good enough. Reach for CDC when latency genuinely matters and you have the operational capacity.

### At-least-once on the relay side too

The relay publishes a message and then marks the row as published. If the publish succeeds but the mark fails (relay crashes, database blip), the relay will re-read the row on the next iteration and publish again. Duplicates.

This means **consumers still need to be idempotent** (see [idempotent_consumers.md](idempotent_consumers.md)). The outbox pattern gives you at-least-once delivery with guaranteed consistency — it does not give you exactly-once. The dedupe story is the same as any at-least-once system.

The usual idempotency key is the outbox row ID, which is a stable identifier that survives retries.

### Garbage collection

The outbox table grows forever if you don't clean it up. Periodic deletion of published rows older than N days is the simple approach. You want N to be long enough that:

- You can diagnose issues by looking at published rows.
- You have a replay window if a downstream consumer needs to re-read recent events.

A typical retention is 7-30 days. Use a partial index on `published_at` to make the deletion query fast.

```sql
DELETE FROM outbox
WHERE published_at IS NOT NULL
  AND published_at < NOW() - INTERVAL '7 days';
```

### When the outbox pattern isn't worth it

The outbox pattern adds a table, a relay process, and a small amount of latency. It's worth it for most cross-system consistency problems, but not all:

- **Fire-and-forget best-effort events.** Metrics, analytics pings, non-critical notifications — if losing one occasionally is fine, skip the outbox and publish directly. Document the choice.
- **Tiny systems with no downstream consumers yet.** If there's only one consumer and you can tolerate rare inconsistency, it might be overkill. But the moment a second consumer shows up, you'll want the outbox, and bolting it on later is harder than starting with it.
- **Systems where the database and broker share transactions.** Rare — only happens with specific broker-DB combinations like Kafka + Postgres via a transactional outbox extension, or systems that publish to a queue that's backed by the same database. When you have a true shared transaction, you don't need the pattern.

### Variants I've seen

- **Outbox + CDC.** The outbox table exists, but the relay is CDC-based. Gives you both the explicit contract of an outbox row *and* low-latency publishing.
- **Outbox with multiple transports.** The outbox row has a `transport` column indicating whether the event goes to RabbitMQ, Kafka, an HTTP webhook, etc. Different relays handle different transports.
- **Listen-notify relay (Postgres).** Instead of polling, the transaction issues a `NOTIFY` after commit; the relay listens and picks up the row immediately. Lower latency than polling without the operational cost of CDC. See [../postgresql/listen_notify_and_logical_replication.md](../postgresql/listen_notify_and_logical_replication.md).
- **Inbox pattern (the mirror).** On the consumer side, an inbox table records received messages and their processing state. Same idea, same benefits, applied to the consumer's dedupe problem.

> **Mid-level answer stops here.** A mid-level dev can describe the pattern. To sound senior, speak to when it's worth the cost, the implementation pitfalls, and the operational concerns ↓
>
> **Senior signal:** treating the outbox as the default for cross-system consistency, and knowing the engineering discipline to make it run well.

### Pitfalls I've seen in production

- **Relay as a single point of failure.** If the relay crashes and nobody notices, events stop publishing. Monitor the oldest unpublished row age — if it's growing, alert.
- **Unbounded outbox growth.** No garbage collection → table gets huge → publish query gets slow → relay falls behind → table gets huger. Set up GC from day one.
- **Relay processing events in the wrong order.** If downstream consumers care about ordering, the relay must preserve order within an aggregate. Partial ordering by `aggregate_id + id` is usually the right move.
- **Large transactions causing outbox bloat.** A request that produces 500 outbox rows in one transaction puts pressure on the relay. Usually means the domain event design is wrong — most requests should produce 1-3 events, not hundreds.
- **Relay publishing before the main transaction is visible to readers.** Not usually a problem with a single-DB outbox, but can be with read replicas — the relay sees committed rows before replicas do, and downstream consumers query replicas and see stale data. Pin the relay to the primary.
- **Missing the ack-before-mark race.** The relay publishes, the broker acks, the relay crashes before marking the row as published. Next cycle, the relay republishes. Harmless with idempotent consumers, fatal without.
- **Treating outbox failures as silent.** If the relay can't publish because the broker is down, the outbox just accumulates. That should be loud — queue depth alarms, lag alarms, something — not silent growth.

### The operational checklist

- [ ] Outbox table has a partial index on unpublished rows.
- [ ] Relay uses `FOR UPDATE SKIP LOCKED` (or a similar mechanism) for parallel safety.
- [ ] Oldest unpublished row age is graphed and alerted on.
- [ ] Relay is monitored for liveness (not just "is the process running" but "is it actually publishing").
- [ ] Published rows are garbage collected on a schedule.
- [ ] Consumers are idempotent (the outbox gives at-least-once; consumers must dedupe).
- [ ] The relay can be restarted and multiple instances can run without duplication beyond at-least-once.
- [ ] Broker downtime doesn't lose events — it just delays them.

### Closing

"So the outbox pattern turns a cross-system consistency problem into a single-database problem. Write the business data and the outbox row in the same transaction; a relay process publishes unpublished rows to the broker; consumers dedupe on at-least-once delivery. The pattern is mature, well-understood, and worth the small operational cost for almost any system that cares about consistency between a database and a message broker. The failure modes I see most are unmonitored relays, missing garbage collection, and people skipping the pattern entirely and then spending months debugging silent inconsistency."
