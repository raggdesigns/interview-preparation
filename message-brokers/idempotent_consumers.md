# Idempotent consumers

**Interview framing:**

"Idempotency is the single most important property of a consumer in an at-least-once messaging system. At-least-once means duplicates are inevitable — not an edge case, but a normal operating condition. If your consumer isn't idempotent, every duplicate delivery produces a wrong side effect, and the wrongness usually shows up days later in a data discrepancy or a customer complaint. Building idempotency in from the start is orders of magnitude cheaper than bolting it on after an incident."

### Definition, precisely

An operation is **idempotent** if running it N times produces the same result as running it once. The N messages arriving is the trigger; what matters is that the *observed state after processing* is the same regardless of how many times processing happened.

Note: idempotent doesn't mean "no side effect". It means "the side effect is the same whether you run it once or a hundred times". Sending an email twice is not idempotent (the user gets two emails). Setting a user's email address to a specific value is idempotent (running it twice sets the same value twice, same end state).

### Why at-least-once makes idempotency mandatory

The at-least-once delivery chain has duplicates at several points:

1. **Producer retries.** Network blip during publish → producer retries → broker gets the same message twice.
2. **Consumer crashes before ack.** Consumer processes the message, then crashes before acknowledging → broker redelivers → same message processed again.
3. **Broker redelivery on timeout.** Consumer is slow; broker thinks it crashed; redelivery happens while the first consumer is still processing → two consumers handle the same message in parallel.
4. **Replay after outage.** After a bug fix or broker recovery, messages get re-delivered from a snapshot.

Each of these is normal operation. None of them are preventable at the broker layer. All of them produce duplicates the consumer must absorb.

### Natural idempotency — the preferred approach

Some operations are naturally idempotent. When you can design your work to use them, you don't need any dedup machinery.

**Naturally idempotent operations:**
- **`SET` / `UPDATE` with fixed target value** — `user.email = 'x@y.com'`. Running twice is the same as once.
- **`INSERT ... ON CONFLICT DO NOTHING`** — attempting to insert a row that already exists does nothing.
- **`UPSERT` with deterministic keys** — create-or-update where the key is stable.
- **File writes with a deterministic path** — writing the same content to the same path.
- **Set operations** — adding a user to a group (the user is in the group after 1 or 100 adds).
- **Deletes by ID** — deleting a row that's already gone is a no-op.

**Operations that look natural but aren't:**
- **INSERT without conflict handling** — fails on duplicate key, or creates two rows if the key isn't unique.
- **INCREMENT / DECREMENT** — every call changes the state.
- **APPEND to a list** — every call adds an item.
- **SEND email / SMS / push notification** — the external system delivers each call.
- **CHARGE credit card** — each call is a separate charge.

When you have a choice, model operations as natural idempotent ones. `SET balance = 100` (idempotent) beats `INCREMENT balance BY 100` (not). `UPSERT order_status` beats `INSERT order_event`.

### Explicit dedupe — when natural isn't possible

For operations that are inherently non-idempotent (increments, sends, creates without a natural unique key), you need to track which messages have been processed and skip duplicates.

The mechanism:

1. Producer assigns a unique **idempotency key** to each message (typically a UUID) and puts it in the message payload or a header.
2. Consumer, as part of processing the message, writes the idempotency key to a dedupe table.
3. If the key is already in the table, the consumer skips the work and acks the message.
4. **Critically:** the dedupe write and the business work must happen in the same transaction. Otherwise you can end up with "business work done, dedupe not recorded" or vice versa.

```sql
BEGIN;

-- Try to record the message as processed.
INSERT INTO processed_messages (message_id)
VALUES ('8f7a...') ON CONFLICT (message_id) DO NOTHING;

-- If the insert didn't happen (because it was already there), bail out.
-- Otherwise do the work.
IF (the insert affected a row) THEN
    INSERT INTO order_events (order_id, event_type, ...) VALUES (...);
    UPDATE counters SET count = count + 1 WHERE name = 'orders';
END IF;

COMMIT;
```

After this transaction, the message is either fully processed (dedupe + work both committed) or fully skipped (it was a duplicate and nothing happened). The ack to the broker comes after the commit.

### The idempotency key — who owns it and what it looks like

- **The producer generates the key** when the message is first created. Stable for the lifetime of the message, including retries.
- **It's part of the message payload** (or a dedicated header), not a broker-generated ID. Broker IDs change on redelivery and are not stable across retries.
- **UUID v4 is fine.** Content-based hashes work too if the producer can't generate a UUID.
- **Derived from business data** is even better when possible: an order ID + event type combination means you don't need a separate UUID.

What doesn't work:
- **The broker's delivery tag.** RabbitMQ's delivery tags are per-delivery, not per-message. Redeliveries get different tags.
- **A monotonic counter.** If the producer is restarted, you need coordination to avoid reusing counters.
- **A timestamp.** Millisecond-collision is real at scale; also doesn't survive clock skew.

### The dedupe table — design considerations

- **Primary key on the idempotency key.** This is what makes the `ON CONFLICT DO NOTHING` work.
- **Processed-at timestamp.** For garbage collection and debugging.
- **Reference to the work** (optional). Storing the resulting record ID or an audit link makes it easy to trace what happened.
- **Garbage collection.** The table grows forever if you don't clean it up. Delete entries older than the broker's retention window plus a safety margin. A message that's been retained for 7 days can be safely removed from the dedupe table after, say, 30 days.
- **Indexing strategy.** For high-throughput systems, the dedupe table is a hot spot. Use a unique index, consider partitioning by time.

### Transactional boundary — the part people get wrong

The critical detail: **the dedupe check, the dedupe write, and the business work must all be in the same transaction.** If any of them is outside, you can produce one of these failure modes:

- **Dedupe written, work failed.** The consumer thinks it handled the message; the work didn't happen. Lost work.
- **Work done, dedupe not written.** The consumer re-processes on redelivery and does the work twice. Duplicate work.
- **Ack sent, transaction not committed.** The broker thinks the message is handled; the work is pending and never will be. Lost work.

The order matters:
1. Start a database transaction.
2. Attempt to insert the dedupe row. If it's a duplicate, commit (skip) and ack the message.
3. Do the business work.
4. Commit the transaction.
5. Ack the message to the broker.

If step 4 fails, nothing is committed, and the message will be redelivered — which is fine because the dedupe row wasn't committed either. If step 5 fails, the work is committed and the message is redelivered; on redelivery, the dedupe check catches it and step 2 skips the work. Either way, the end state is correct.

### What about external side effects (email, API calls, payments)?

Database transactions can't roll back an email. Once the email is sent, it's sent. This is where idempotency gets genuinely hard, and where you have to rely on the downstream system having its own idempotency story.

Options:

1. **Outbox pattern** — write the intent to an outbox table in the same transaction as the business work. A separate process reads the outbox and performs the side effect, tracking its own dedupe. See [outbox_pattern.md](outbox_pattern.md).
2. **Provider-level idempotency keys** — most serious APIs (Stripe, SendGrid, etc.) accept an idempotency key on the request. The provider dedupes on their side. You pass the same key on retries and they refuse to run the operation twice.
3. **Natural idempotency at the provider** — deleting a resource that's already deleted, updating a customer's email to a fixed value, etc.
4. **Manual reconciliation** — accept rare duplicates and have a reconciliation process that cleans them up. Appropriate for very low-value operations but terrible for anything visible to users.

The rule: never assume an external side effect is idempotent. Either the provider gives you a mechanism, or you build one, or you live with duplicates. "It'll probably be fine" is not a strategy.

### Stateful processing and idempotency

Some operations are stateful — they depend on the current state of the system. "Deduct $50 from this account" only makes sense in the context of the current balance. Naive retries produce wrong totals.

Two patterns:

1. **Command + version check.** The command includes the expected current state. If the state doesn't match, the command is rejected. On retry, the rejection prevents double-application.
   ```
   "Deduct $50 from account 42, expecting current balance of $200"
   ```
   First attempt succeeds, balance becomes $150. Retry attempt sees balance $150, not $200, rejects the command. Correct.

2. **Event sourcing with deterministic IDs.** Each state change is an event with a stable ID. Rebuilding state from the event log dedupes naturally because inserting an event with a duplicate ID is a no-op.

Both approaches require rethinking the data model, which is why they're often considered architectural decisions rather than simple retry logic.

> **Mid-level answer stops here.** A mid-level dev can describe dedupe tables. To sound senior, speak to the design discipline and the places idempotency silently fails ↓
>
> **Senior signal:** designing idempotency into the data model, not retrofitting it at the edges.

### Design principles I follow

- **Prefer natural idempotency.** When you have a choice between an idempotent and non-idempotent operation, pick the idempotent one. It's cheaper and harder to screw up.
- **Same transaction for dedupe and work.** Always. No exceptions. Cross-transaction dedupe is a trap.
- **Stable idempotency keys from the producer.** Not broker metadata, not timestamps, not consumer-generated. Producer-side, in the payload.
- **Garbage-collect dedupe tables.** Unbounded tables become liabilities.
- **External side effects need their own story.** Either provider-level idempotency or the outbox pattern. Never hope it's fine.
- **Test duplicates deliberately.** In tests, deliver every message twice. If the system doesn't produce the same state, idempotency is broken.

### Common failure modes

- **Generating the idempotency key in the consumer.** Different consumers generate different keys for the same message; dedupe becomes impossible.
- **Dedupe check before transaction starts.** Race condition: two consumers both see "not processed yet", both do the work, only one writes the dedupe row. Always do the dedupe inside the transaction.
- **Skipping the dedupe row write on the duplicate path.** Then the dedupe table never notices the duplicate; subsequent retries re-do the work. Write the dedupe row in both branches.
- **Relying on the broker to deduplicate.** Brokers aren't your dedupe layer; they're your transport.
- **Non-transactional external calls.** Email sent before the transaction commits; transaction rolls back; email has been sent and the database says the work never happened.
- **Not testing duplicates.** The system works in development (where duplicates never happen) and explodes in production.

### Closing

"So idempotency is non-negotiable in at-least-once systems. Prefer natural idempotency where possible — set rather than increment, upsert rather than insert. For operations that can't be made natural, use a dedupe table keyed on a producer-generated idempotency key, and do the dedupe write and the business work in the same transaction. External side effects need their own idempotency — either via provider-level keys or the outbox pattern. Test duplicates deliberately; they'll happen in production whether you planned for them or not."
