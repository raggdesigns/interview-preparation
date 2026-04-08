# Queue topologies: work queue, pub/sub, RPC, priority

**Interview framing:**

"Queue topology is the shape your messaging system takes: how many queues, how consumers are distributed across them, whether messages fan out, whether they're competing for workers, whether ordering matters. Most real systems are combinations of a handful of canonical patterns — work queue, pub/sub, RPC, priority — and recognizing which pattern fits the problem is usually more important than the broker-level details. The patterns are broker-independent; the implementation details differ between RabbitMQ and Kafka, but the shapes are the same."

### Pattern 1: Work queue (competing consumers)

**Shape:** one queue, many consumers, each message goes to exactly one consumer.

```
         ┌── Consumer 1 ──┐
         │                │
Producer ──→ Queue ───────┤
         │                │
         └── Consumer N ──┘
```

This is the canonical task-queue pattern. A single queue holds tasks, and a pool of workers consumes from it. Each task goes to exactly one worker — whichever is free next. Load balances naturally.

**Use when:**
- The work is a command, not an event — each task should be performed exactly once.
- Multiple workers can handle the work in parallel without coordination.
- You want to scale throughput by adding workers.

**Examples:**
- Sending emails
- Rendering PDFs
- Processing uploaded images
- Running scheduled jobs against a task list

**Key details:**
- Use manual acks so a failing worker doesn't lose the task — another worker picks it up.
- Set prefetch appropriately — usually low (1-10) for long-running tasks, higher for fast tasks.
- Every worker runs the same code. Adding capacity is horizontal.

**In RabbitMQ:** a single queue with a direct exchange (or publish to a named queue via the default exchange for simplicity). All consumers bind to the same queue.

**In Kafka:** a topic with N partitions, a single consumer group with N workers. Each partition is handled by exactly one worker within the group, which gives you parallelism up to the partition count.

### Pattern 2: Pub/sub (fan-out)

**Shape:** one producer, many independent consumers, each of whom gets every message.

```
                ┌── Consumer A
                │
Producer ── Exchange ── Consumer B
                │
                └── Consumer C
```

Every consumer gets a copy of every message. Each consumer processes independently and tracks its own state.

**Use when:**
- The message is an event — something happened, and multiple interested parties need to know.
- Each consumer has its own reason to care (billing reacts, analytics reacts, cache reacts, notifications react, all to the same event).
- You want to add new consumers later without touching the producer or existing consumers.

**Examples:**
- `order.created` → billing, inventory, analytics, email
- `user.signup` → CRM sync, welcome email, audit log
- `cache.invalidate` → every web server instance

**Key details:**
- Each consumer has its own queue. Do not share queues between consumers in this pattern.
- The exchange is what fans out — usually fanout or topic.
- Adding a new consumer = declare a new queue, bind it to the exchange, start a consumer. Zero producer changes.

**In RabbitMQ:** a topic or fanout exchange, with each consumer binding its own queue.

**In Kafka:** a topic consumed by multiple consumer groups. Each group has its own offset; each group processes every message independently.

**Pub/sub vs work queue — the crucial distinction:**
- In pub/sub, every *consumer type* gets every message.
- In work queue, every *message* is handled once across all consumers of the same type.

Real systems usually combine both: "every consumer type gets every message, and within each consumer type, multiple workers compete for delivery". RabbitMQ expresses this as "one queue per consumer type, each bound to the shared exchange, with multiple workers per queue".

### Pattern 3: Request-response (RPC over messaging)

**Shape:** client sends a request, server processes it, server sends a response back to the client.

```
                         ┌──────────────────┐
Client ── request_queue ─→ Server processes │
                         └─────────┬────────┘
                                   │
                         ┌─────────▼────────┐
Client ←── reply_queue ──┤ publishes reply  │
                         └──────────────────┘
```

Classic sync-over-async. The client publishes a request, waits for a response on a reply queue, correlates them with a correlation ID.

**Use when:**
- You genuinely need a response (not just fire-and-forget).
- The work is too expensive or risky to run synchronously over HTTP.
- You want load balancing and retry semantics of a message queue for a request/response interaction.

**Examples:**
- Long-running calculations where the caller wants the result
- Cross-service RPC that needs queuing semantics (retry, backpressure) more than HTTP gives you
- Integration with external systems where the broker provides the reliability layer

**Key details:**
- The client declares an exclusive, auto-delete reply queue per request (or per session).
- The client puts the reply queue name in a `reply_to` header.
- The client puts a unique `correlation_id` in the message.
- The server processes the request and publishes the response to `reply_to` with the matching `correlation_id`.
- The client reads replies from its reply queue and matches them by correlation ID.

**Gotchas:**
- **Timeout handling.** Unlike HTTP, there's no built-in timeout. The client has to implement one.
- **Orphaned replies.** The client disconnects before the reply arrives; the reply goes to a dead queue. Use auto-delete reply queues.
- **Is this actually what I want?** Most of the time, "I need an async RPC" is a smell. Usually you want either a proper sync call (HTTP with a retry policy) or fully decoupled async (fire-and-forget with eventual processing and a callback).

I reach for this pattern reluctantly. It's the right answer sometimes but not often.

### Pattern 4: Priority queue

**Shape:** one queue where higher-priority messages are delivered first, regardless of arrival order.

```
Producer ──→ Priority Queue ──→ Consumer
              ├── P10 message  ← delivered first
              ├── P10 message
              ├── P5  message
              └── P0  message  ← delivered last
```

Consumers always get the highest-priority available message. Lower-priority messages wait.

**Use when:**
- Some work is genuinely more urgent than other work and you can't wait for natural FIFO order.
- You have a mix of interactive and background tasks sharing the same worker pool.

**Examples:**
- User-triggered reports (high priority) vs scheduled nightly reports (low priority)
- Password reset emails (high) vs marketing emails (low)

**Key details (RabbitMQ specifically):**
- Declare the queue with `x-max-priority` (e.g. 10) — you get priorities 0 through 9.
- Publish messages with a `priority` header.
- Higher `priority` values are delivered before lower ones.

**Gotchas:**
- **Priority ≠ absolute ordering.** RabbitMQ's priority queue gives "best effort" priority; under load, exact ordering may slip.
- **Starvation.** Low-priority messages can wait forever if high-priority traffic never stops. Sometimes this is fine; sometimes you need a fairness mechanism.
- **Many priorities is worse than few.** `x-max-priority=10` is fine; `x-max-priority=255` is a performance trap. Use a small number of priority levels — usually 2-5 is plenty.
- **Consider separate queues instead.** Sometimes "high-priority queue" and "low-priority queue" with different consumer counts is simpler and more predictable than a true priority queue.

**In Kafka:** there's no native priority. You implement it with separate topics (one per priority) and consumer logic that reads from high-priority topics preferentially.

### Combining patterns

Real systems use combinations. A typical backend might look like:

```
API request ──┐
              │
              ▼
      [pub/sub exchange "events"]
              │
              ├── queue "billing"        ← work queue, 4 workers
              ├── queue "inventory"      ← work queue, 2 workers
              ├── queue "analytics"      ← work queue, 1 worker
              └── queue "notifications"  ← work queue, 8 workers
                       │
                       └─→ priority queue "emails"
                                │
                                ├── P10 password_reset   ← instant
                                └── P0  marketing        ← best-effort
```

- **Pub/sub** fans out the domain event to every interested service.
- **Work queue** within each service load-balances messages across that service's workers.
- **Priority queue** within the notifications service ensures urgent emails go out before bulk marketing sends.

Each pattern is applied at the layer where it makes sense. Mixing them is normal and expected.

> **Mid-level answer stops here.** A mid-level dev can describe the patterns. To sound senior, speak to the design decisions and the operational consequences of picking a topology ↓
>
> **Senior signal:** understanding that topology is a decision with long-lived implications and designing it to evolve gracefully.

### Design principles

- **One queue per logical consumer, not per worker.** Scale horizontally by adding workers to the same queue, not by adding queues.
- **Name queues by consumer intent, not by message type.** `billing_service` is a better name than `order_created_queue` — the queue belongs to the consumer, not the event.
- **Pub/sub for events, work queue for commands.** Commands are consumed once; events have multiple listeners. Mixing them up is a common design mistake.
- **Keep exchanges stable; let queues evolve.** Producers shouldn't need to change when consumers are added, renamed, or reorganized. The exchange is the stable API.
- **Avoid clever routing.** Complex routing rules are hard to debug and hard to change. A well-designed topic key with simple patterns usually beats heavy header-based routing.
- **Plan for dead-letter handling up front.** Every queue needs a story for what happens when messages fail. DLX + alerts + replay tooling from day one.
- **Measure queue depth as a health signal.** Growing queues mean consumers can't keep up — either a code problem, a capacity problem, or a downstream dependency issue.

### Failure modes by topology

- **Work queue:** runaway consumer pulling everything with high prefetch; other consumers idle. Mitigation: low prefetch.
- **Pub/sub:** a slow consumer backs up its queue without affecting others (good!), but silent accumulation if nobody watches queue depth. Mitigation: alerts on per-queue depth.
- **RPC:** orphaned reply queues, timeout handling, correlation ID mismatches. Mitigation: auto-delete reply queues, strict timeouts, avoid the pattern unless necessary.
- **Priority queue:** low-priority starvation, performance issues with too many priority levels. Mitigation: few levels, consider separate queues as an alternative.

### Closing

"So the four canonical patterns are work queue (competing consumers for commands), pub/sub (fan-out for events), RPC (request-response over messaging, used sparingly), and priority (urgent messages jump the queue). Real systems combine them — pub/sub at the top to fan events out, work queues within each service to parallelize, priority where urgency matters. The patterns are broker-independent; the point is to recognize which pattern fits the workload before you start wiring exchanges and queues."
