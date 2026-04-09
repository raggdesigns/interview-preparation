# Outbox and inbox patterns

**Interview framing:**

"The outbox and inbox patterns are the two halves of reliable cross-boundary messaging. The outbox ensures a service reliably publishes events by writing them to its own database in the same transaction as the business data. The inbox ensures a service reliably processes incoming events by deduplicating them in its own database. Together, they give you effectively-once semantics across services without distributed transactions. This file covers both as a pair because they're two sides of the same coin."

> The outbox pattern is covered in depth in [../message-brokers/outbox_pattern.md](../message-brokers/outbox_pattern.md). This file provides the paired view with the inbox pattern and the cross-reference for event-driven architecture context.

### The outbox pattern — producer side

The outbox solves the **dual-write problem**: the producer needs to both write to its database and publish an event, but these are two separate systems with no shared transaction.

The solution: write the event to an **outbox table** in the same database transaction as the business data. A separate relay process reads the outbox and publishes to the broker.

```text
┌────────────────────────────────────┐
│ Single database transaction:       │
│   INSERT INTO orders (...)         │
│   INSERT INTO outbox (event, ...)  │
│ COMMIT                             │
└──────────────────┬─────────────────┘
                   │
         (relay process, async)
                   │
                   ▼
            Message broker
```

Either both the order and the outbox event exist, or neither does. The relay is eventually-consistent but never loses events.

For the full treatment — relay implementations (polling vs CDC), schema, garbage collection, and pitfalls — see [../message-brokers/outbox_pattern.md](../message-brokers/outbox_pattern.md).

### The inbox pattern — consumer side

The inbox is the mirror of the outbox: it solves the **duplicate-processing problem** on the consumer side.

At-least-once delivery means the consumer will receive the same event more than once. The inbox pattern records every processed event in the consumer's database, in the same transaction as the business logic, and skips events it has already seen.

```text
┌──────────────────────────────────────────────────┐
│ Single database transaction:                      │
│   SELECT 1 FROM inbox WHERE event_id = ?          │
│   IF exists → skip (already processed)            │
│   ELSE:                                           │
│     INSERT INTO inbox (event_id, processed_at)    │
│     -- do the business work --                    │
│     INSERT INTO billing_records (...)             │
│ COMMIT                                            │
└──────────────────────────────────────────────────┘
                   │
              ack the message
```

**The critical property:** the inbox check and the business work are in the **same transaction**. This prevents both:

- "Business work done, inbox not recorded" → duplicate on retry.
- "Inbox recorded, business work failed" → lost work.

### The inbox table schema

```sql
CREATE TABLE inbox (
    event_id UUID PRIMARY KEY,
    event_type TEXT NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

Minimal by design. The primary key on `event_id` provides the uniqueness check. `INSERT ... ON CONFLICT DO NOTHING` gives you an atomic check-and-insert.

```sql
-- Inside the consumer's transaction
INSERT INTO inbox (event_id, event_type)
VALUES ($1, $2)
ON CONFLICT (event_id) DO NOTHING;

-- If the insert affected 0 rows, the event was already processed → skip
-- If it affected 1 row, this is new → proceed with business work
```

### Inbox garbage collection

Like the outbox, the inbox grows forever without cleanup. Events older than the broker's maximum redelivery window are safe to delete.

```sql
DELETE FROM inbox
WHERE processed_at < NOW() - INTERVAL '30 days';
```

The retention window should be longer than the broker's retry window plus a safety margin. If your broker retries for up to 7 days, keep inbox entries for 30 days.

### Why the inbox matters — not just "idempotent consumers"

"Just make your consumers idempotent" is the common advice. The inbox is *one way* to achieve idempotency, and it's the most reliable way for operations that aren't naturally idempotent.

Recall from [../message-brokers/idempotent_consumers.md](../message-brokers/idempotent_consumers.md):

- **Natural idempotency** — the operation is inherently safe to repeat. `SET email = 'x@y.com'`. No inbox needed.
- **Explicit dedupe (inbox)** — the operation is not naturally idempotent. `INSERT INTO ledger`, `INCREMENT counter`, `SEND email`. You need the inbox (or an equivalent dedupe mechanism).

The inbox pattern is the structured, transactional implementation of explicit dedupe. It's worth standardizing across a team so that every consumer handles duplicates consistently.

### Outbox + inbox together — the full picture

```text
Service A (producer)                         Service B (consumer)
┌──────────────────────────┐                ┌──────────────────────────┐
│ Transaction:             │                │ Transaction:             │
│   Business write         │                │   Inbox check/insert     │
│   Outbox write           │                │   Business write         │
│ COMMIT                   │                │ COMMIT                   │
└──────────┬───────────────┘                └──────────▲───────────────┘
           │                                           │
    (outbox relay)                              (message consumer)
           │                                           │
           ▼                                           │
    ┌──────────────┐                            ┌──────┴──────┐
    │ Message      │ ──────────────────────────→│ Message     │
    │ Broker       │                            │ Broker      │
    └──────────────┘                            └─────────────┘
```

**Service A:** business data + outbox event in one transaction. Relay publishes to broker. Guaranteed: if the business data exists, the event will be published (eventually).

**Service B:** inbox check + business work in one transaction. Duplicates are skipped. Guaranteed: each event is processed exactly once (effectively-once).

Together: **effectively-once end-to-end** across two services communicating via a broker, without distributed transactions.

### The alternative: without outbox and inbox

Without outbox (producer side):

```php
$this->entityManager->flush();        // DB commit
$this->messageBus->dispatch($event);   // Broker publish
// If PHP crashes between these two lines: event lost
```

Without inbox (consumer side):

```php
public function handleOrderCreated(OrderCreated $event): void {
    $this->billingService->createInvoice($event);
    // If consumer crashes after creating invoice but before acking:
    // redelivery → duplicate invoice
}
```

Both failure modes are real, not theoretical. They happen under normal production conditions (process crashes, network hiccups, broker redeliveries). The outbox and inbox prevent them.

### When to use the outbox

- **Any cross-service event that matters.** If losing the event would cause an inconsistency that nobody fixes, you need the outbox.
- **The default for production event publishing.** Unless the event is truly best-effort (metrics, analytics you're willing to lose), use the outbox.

### When to skip the outbox

- **Best-effort events.** Cache invalidation notifications, analytics pings, debug events. If losing one occasionally is fine, publish directly and save the complexity.
- **Within a single database.** If both the business data and the "event" are in the same database (e.g., a Symfony application using a database-backed Messenger transport), the transaction already covers both.

### When to use the inbox

- **Any consumer that performs non-idempotent side effects.** Creating records, incrementing counters, sending notifications, charging payments.
- **The default for production consumers.** Unless the consumer's operation is naturally idempotent, use the inbox.

### When to skip the inbox

- **Naturally idempotent operations.** `UPSERT`, `SET`, `DELETE WHERE`. The operation is safe to repeat.
- **Consumers that query but don't write.** Read-only consumers don't have side effects to duplicate.

### Standardizing across a team

The most effective approach is to make the outbox and inbox patterns standard infrastructure in your codebase:

- **Outbox middleware** — automatically writes events to the outbox table when a command handler dispatches them, within the same Doctrine transaction.
- **Inbox middleware** — automatically checks the inbox before a consumer handler runs, and inserts the event ID after it completes.
- **Shared relay** — a single relay process (or a Messenger worker) that reads the outbox and publishes to the broker.

Once standardized, individual developers don't think about dual writes or duplicates — the infrastructure handles it.

In Symfony, this can be implemented as Messenger middleware:

```php
class InboxMiddleware implements MiddlewareInterface
{
    public function handle(Envelope $envelope, StackInterface $stack): Envelope
    {
        $eventId = $envelope->last(EventIdStamp::class)?->getId();
        if (!$eventId) {
            return $stack->next()->handle($envelope, $stack);
        }

        $inserted = $this->inboxRepository->tryInsert($eventId);
        if (!$inserted) {
            return $envelope; // Already processed; skip
        }

        return $stack->next()->handle($envelope, $stack);
    }
}
```

> **Mid-level answer stops here.** A mid-level dev can describe the patterns separately. To sound senior, speak to how they compose, why they should be standardized, and the failure modes they prevent ↓
>
> **Senior signal:** treating outbox + inbox as standard infrastructure that every service uses, not as ad-hoc patterns applied case-by-case.

### The paired guarantee

| Without | Failure mode | With |
|---|---|---|
| No outbox | Event lost on producer crash between DB commit and broker publish | Outbox: event in same transaction, relay publishes eventually |
| No inbox | Duplicate processing on consumer crash before ack | Inbox: dedupe in same transaction as business work |
| Neither | Both lost events and duplicate processing | Both: effectively-once end-to-end |

The combined cost is two extra database tables (one outbox per producer, one inbox per consumer) and a relay process. The benefit is reliable, effectively-once cross-service communication without distributed transactions.

### Common mistakes

- **Outbox without inbox (or vice versa).** You fix one half of the reliability chain and leave the other half broken.
- **Inbox check outside the business transaction.** Race condition: two consumers both see "not processed yet", both proceed.
- **Event ID generated by the consumer.** The same event gets different IDs on redelivery. Always use a producer-generated, stable event ID.
- **No garbage collection on either table.** Unbounded growth.
- **Outbox relay as a single point of failure without monitoring.** If the relay stops, events stop flowing and nobody notices.
- **Assuming the outbox relay provides ordering.** Within a single aggregate, order is preserved. Across aggregates, it's not guaranteed unless the relay preserves it explicitly.
- **Not standardizing.** Every team implements its own version with its own bugs. Make it shared infrastructure.

### Closing

"So the outbox and inbox are the producer-side and consumer-side halves of reliable cross-service messaging. The outbox writes the event to the local database in the same transaction as the business data, and a relay publishes it. The inbox records processed event IDs in the local database in the same transaction as the business work, and skips duplicates. Together they give you effectively-once semantics without distributed transactions. Standardize them as infrastructure — middleware, shared tables, shared relay — so individual services get reliability for free."
