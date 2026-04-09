# At-least-once vs at-most-once vs exactly-once

**Interview framing:**

"Delivery semantics is one of those topics that sounds simple and turns out to be a trap. Every messaging system claims one of three guarantees — at-most-once, at-least-once, or exactly-once — and the important thing is to know which one you're actually getting and what it costs you. The senior insight is that **exactly-once end-to-end is almost always a lie**. What's really happening is at-least-once delivery combined with consumer-side idempotency, and calling that 'exactly-once' is a marketing choice, not a guarantee."

### The three semantics

- **At-most-once** — a message is delivered zero or one times. Never duplicated, sometimes lost.
- **At-least-once** — a message is delivered one or more times. Never lost, sometimes duplicated.
- **Exactly-once** — a message is delivered exactly one time. Never lost, never duplicated.

The trade-off is explicit: you can pay in duplicates or pay in losses, and picking "neither" is a much harder engineering problem than it first appears.

### At-most-once — when is it acceptable

Delivery attempts at most once; acknowledgements happen *before* the consumer actually does the work (or there are no acknowledgements at all). If the consumer crashes, the message is gone.

Use it when:

- **Loss is tolerable.** Metrics, logs, telemetry, best-effort notifications. Losing 0.1% of data points is fine if you're sampling anyway.
- **Throughput dominates.** The overhead of tracking acks is a measurable bottleneck and you've deliberately chosen to accept loss for speed.
- **The data is self-healing.** Periodic full reconciliation makes message loss irrelevant because the next reconciliation will catch up.

RabbitMQ auto-ack mode is at-most-once. Kafka with `acks=0` is at-most-once. Both exist and are the right choice for certain workloads, but not for anything a user will notice.

### At-least-once — the honest production default

Delivery attempts at least once; acknowledgements happen *after* the consumer processes the work. If the ack is lost (consumer crashes right after processing, network drops, broker thinks it wasn't received), the broker re-delivers, and the consumer processes the same message again.

Use it when:

- Anything matters. This is the default for all real work.

The cost: **your consumers must be idempotent.** This is non-negotiable. At-least-once delivery means duplicates are a normal operating condition, not an exception. If your consumer sends an email on delivery, an at-least-once pipeline will occasionally send that email twice. If your consumer increments a counter in a database, the counter will occasionally be incremented twice. You fix this at the consumer, not at the broker.

See [idempotent_consumers.md](idempotent_consumers.md) for how to actually build idempotent consumers.

### Exactly-once — the marketing word

Exactly-once delivery end-to-end is almost always an illusion. Here's what's actually happening under that label, in the systems that claim it:

- **The broker might guarantee exactly-once write.** A producer publishes, retries on network failure, and the broker deduplicates retries using a producer-ID + sequence-number combination. This is real. It prevents duplicate publishes.
- **The consumer might track offset commits transactionally.** When the consumer reads a message and writes a result back to the same broker (Kafka-to-Kafka), the offset commit and the result write can happen in a single transaction. Either both happen or neither does, so re-reading the same message and producing the same result twice is prevented. Also real, inside the broker's ecosystem.
- **The moment a side effect leaves the broker, exactly-once breaks.** Sending an email, writing to an external database, calling an external API — none of these are transactional with the broker's offset commit. You can write to the external system, then crash before committing the offset; on restart, the consumer reads the same message and writes to the external system again. Exactly-once inside the broker, at-least-once outside.

So "exactly-once" in the marketing sense usually means "exactly-once within the broker's own world, at-least-once the moment you touch anything else". The system-level guarantee is at-least-once plus consumer idempotency, just with a nicer marketing label.

### Effectively-once — the honest term

What you actually want in production is "effectively once": the observable behavior is that each message is processed once, even though the underlying delivery is at-least-once. You achieve this with:

1. **Broker-level at-least-once delivery** (durable, acked, publisher-confirmed).
2. **Consumer-side idempotency** — either natural (the operation is a `SET` rather than an `INCREMENT`) or explicit (dedupe table, message ID tracking).

This is what every mature messaging system ends up implementing, regardless of the vendor's marketing.

### How idempotency gets you effectively-once

Two approaches, covered in detail in [idempotent_consumers.md](idempotent_consumers.md):

1. **Natural idempotency.** The operation is inherently safe to repeat. `SET user.email = 'x@y.com'` is idempotent; running it twice is the same as running it once. `INCREMENT user.login_count` is not idempotent; running it twice gives you +2.
2. **Explicit dedupe.** You track processed message IDs in a database (usually in the same transaction as the business logic). When a duplicate arrives, you notice it in the dedupe table and skip the work.

Most real systems use a mix: natural idempotency where possible (preferred, simpler, cheaper), explicit dedupe where natural idempotency is impossible (counters, append-only writes, external API calls).

### The two failure modes of "I thought I had exactly-once"

1. **"The broker said exactly-once, so I didn't bother with idempotency."** The consumer writes to an external system, crashes before committing, restarts, re-processes, writes to the external system again. Duplicate side effect. You needed idempotency at the boundary.
2. **"I have idempotency, so I can relax the broker guarantees."** The broker is configured for at-most-once (auto-ack), messages get lost on consumer crash, the idempotency table has no entry for the lost message, the work never happens. Losses don't dedupe — they're gone.

The two halves have to be set together. At-least-once from the broker + idempotency at the consumer gives you effectively-once. Relaxing either breaks the whole.

> **Mid-level answer stops here.** A mid-level dev can recite the three semantics. To sound senior, speak to the practical reality of building effectively-once pipelines and the failure modes people walk into ↓
>
> **Senior signal:** articulating the broker/consumer split and the specific places where exactly-once claims fall apart.

### The questions I ask before picking semantics

1. **What happens if a message is processed twice?** Natural → at-least-once is fine without changes. Side effect (email, payment, increment) → you need idempotency.
2. **What happens if a message is lost?** Never → at-most-once is unacceptable. Rarely and acceptable → at-most-once is an option for perf-critical paths.
3. **How will you prove the system is correct?** "Trust the broker's exactly-once mode" is not a proof. "Dedupe table + transaction" is. "Natural idempotency" is.
4. **Who owns the idempotency key?** The producer (message ID generated at source) or the consumer (derived from business data). Both work; the choice affects how you handle replays.
5. **Where does the blast radius of a duplicate end?** A duplicate internal database write is recoverable. A duplicate charge on a customer's credit card is not. The stronger the external consequence, the more rigorous the idempotency needs to be.

### Common mistakes

- **Thinking "exactly-once" means the broker solves it.** It never does at the system level. Idempotency is always the consumer's job.
- **Relying on message IDs from the broker.** RabbitMQ delivery tags change on redelivery. Kafka offsets are per-partition, not global. If you want a stable ID for dedupe, the producer puts it in the message payload.
- **Dedupe tables that outgrow their usefulness.** A dedupe table with millions of entries and no TTL becomes a liability. Garbage-collect old entries based on a window that's longer than the broker's replay horizon.
- **Dedupe tables that aren't transactional with the work.** Write the dedupe entry and the business data in a single transaction, or you can dedupe successfully but fail to do the work (or vice versa).
- **Claiming exactly-once in a system with external side effects.** It's not true. Admit at-least-once + idempotency and move on.

### Closing

"So the honest summary is: at-most-once for best-effort throughput, at-least-once + idempotency for everything that matters, and exactly-once is almost always a misleading label for 'at-least-once with a dedupe layer'. The broker gives you at-least-once; the consumer gives you idempotency; together they give you effectively-once. Anyone who promises exactly-once without talking about consumer-side idempotency is either glossing over details or selling you something."
