# RabbitMQ vs Kafka

**Interview framing:**

"The one-liner I keep in my head: RabbitMQ is a smart broker with dumb consumers; Kafka is a dumb log with smart consumers. Everything downstream of that comes from which half of the work you want the broker to do. If you want routing, per-message acks, priority, and retry logic to live in the broker, pick RabbitMQ. If you want the broker to be a durable append-only log and let consumers do the interesting work, pick Kafka. They're not competing for the same jobs — and the most common architectural mistake is using one for the other's job."

### The fundamental architectural difference

**RabbitMQ** is a message broker with queues. Messages live in queues, consumers pop them off, acknowledgements remove them. Once delivered and acked, the message is gone. The broker tracks per-message state — which consumer has what, what's been acked, what's dead-lettered, what's been retried how many times. Smart broker.

**Kafka** is a distributed commit log. Messages (records) are written to a partitioned log and stay there for a configured retention period regardless of whether anyone has read them. Consumers track their own position in the log (the offset) and read from wherever they want. The broker doesn't track per-consumer state; it just stores the log. Dumb broker, smart consumers.

This single architectural difference propagates into every other property of the two systems.

### Consumption semantics

**RabbitMQ:** push-based delivery (or pull via basic.get). Messages are consumed and acked; after the ack, they're gone. There's no concept of "re-reading the same message" unless you explicitly republish it.

**Kafka:** pull-based. Consumers read from an offset. They can re-read the same messages by resetting the offset. Multiple consumer groups can read the same log independently, each tracking their own offset.

The Kafka property — "I can replay the log from 3 days ago because I just discovered a bug in my consumer" — has no equivalent in RabbitMQ. If you need it, you need Kafka (or something log-shaped).

### Throughput

Kafka is optimized for very high throughput. It batches, it uses the OS page cache aggressively, it has minimal per-message bookkeeping, and it scales horizontally by partitioning. Millions of messages per second per broker is routine.

RabbitMQ has meaningful per-message overhead — the routing decisions, the ack tracking, the durability guarantees — and while it's fast (tens to hundreds of thousands of messages per second per node, depending on settings), it's not in Kafka's throughput league.

If throughput is the dominant constraint, Kafka is usually the right answer. If throughput is fine and routing/acks are what you want, RabbitMQ is usually the right answer.

### Ordering

**RabbitMQ:** FIFO per queue, but multiple consumers can read from the same queue in parallel, so the order messages are *processed* in is not deterministic. If you need strict ordering, you need one consumer per queue (prefetch=1, one worker), which throws away parallelism.

**Kafka:** strict ordering per partition, always. Messages with the same key go to the same partition (if you partition by key) and are read in order. You get parallelism *across* partitions and ordering *within* partitions. This is a big deal for stateful event processing — "all events for user X in order" is natural in Kafka and awkward in RabbitMQ.

### Routing

**RabbitMQ:** rich routing via exchanges and bindings. Topic exchanges, header matching, fan-out. The broker understands message-level routing.

**Kafka:** none. Messages are written to a topic; a topic has partitions; producers pick the partition (by key hash or explicitly). Any filtering or routing happens in the consumer. If you want five consumers to each get a subset of a stream, they all read the whole stream and filter client-side.

This is a genuine difference in engineering ergonomics. RabbitMQ lets you say "billing service only cares about EU order events"; Kafka makes the billing service read all order events and drop the non-EU ones.

### Retention and replay

**RabbitMQ:** messages are retained until consumed. Queue size is bounded; the broker can't retain indefinitely.

**Kafka:** messages are retained for a configured duration (e.g. 7 days) or a configured size, regardless of consumption. A new consumer can join and read everything from the beginning of retention. A bug in an old consumer can be fixed and the consumer re-run against historical data.

### Delivery semantics

Both give you **at-least-once** by default. Both can give you **at-most-once** by changing acknowledgement settings. Neither gives you true exactly-once across arbitrary end-to-end flows — exactly-once is always a combination of broker semantics and consumer-side idempotency.

Kafka has an "exactly-once semantics" mode (transactional producer + idempotent consumer) that gives exactly-once *within the Kafka ecosystem* — writes to Kafka, reads from Kafka, writes back to Kafka. The moment a side effect leaves Kafka (e.g. writing to a database), you're back to needing idempotency at the consumer.

### Operational profile

**RabbitMQ:** simpler to run for small to medium deployments. A single node is a real option for dev and staging. Clustering exists and works but has more sharp edges than you'd like. Quorum queues simplify HA; mirrored queues are deprecated.

**Kafka:** more operational overhead. Needs Zookeeper (or KRaft in newer versions), needs thoughtful partition planning, needs disk provisioning that accounts for retention. In exchange, you get battle-tested horizontal scaling. Managed Kafka services (Confluent Cloud, AWS MSK, Aiven) take a lot of the pain away.

For a small team running everything themselves, RabbitMQ is usually less stressful. For a big-data team that already has Kafka expertise, Kafka is the default and running RabbitMQ feels alien.

### When to pick RabbitMQ

- **Task queues.** Long-running background jobs with per-message acks, retries, and dead-letter handling. The canonical RabbitMQ use case.
- **Command-style messaging.** "Send this email", "render this PDF". The message is an imperative, consumed once, acked, gone.
- **Complex routing.** Topic exchanges with filtering, fan-out to multiple queues with different bindings. Kafka can't do this natively.
- **Priority queues.** RabbitMQ has native priority queue support; Kafka doesn't.
- **Lower operational scale.** Single-node or small-cluster deployments where Kafka's complexity isn't justified.
- **Request/response-style RPC over messaging.** RabbitMQ has a clean pattern for this; Kafka doesn't.

### When to pick Kafka

- **Event sourcing and stream processing.** The log is the source of truth; consumers derive state from it.
- **High throughput.** Millions of events per second.
- **Replay and reprocessing.** The ability to re-read historical data is a first-class requirement.
- **Multiple independent consumers of the same stream.** Multiple consumer groups reading at their own offsets.
- **Strict ordering per key.** Partitioned by key, consumed in order within partition.
- **Integration with the big-data ecosystem.** Kafka Connect, KStreams, Flink, Spark all assume Kafka as a first-class input.

### When the decision is wrong

- **Using RabbitMQ as an event log.** People want replay, so they set messages to never expire, disable acks, and the queue grows forever. This is fighting RabbitMQ's design. Use Kafka.
- **Using Kafka as a task queue.** People try to implement per-message retry with backoff, DLQ, priority in Kafka. It's technically possible, it's a lot of work, and the result is brittle. Use RabbitMQ.
- **Picking based on team familiarity alone.** Familiarity matters, but if the problem is clearly a fit for the other tool, the cost of running two brokers is often lower than the cost of forcing the wrong tool to do the job.
- **Picking Kafka because "scale".** Most systems will never outgrow RabbitMQ. Kafka's operational cost is real, and it's not free just because throughput isn't a constraint yet.

### A hybrid architecture I've seen work

Both, for different jobs:

- **Kafka** for the event backbone: domain events published as facts, retained for 7 days, multiple downstream consumers (analytics, audit, notifications, cache warming).
- **RabbitMQ** for the task layer: commands consumed by workers — send email, generate report, call external API — with retries, backoff, and DLQs.

The split maps cleanly onto the mental model: Kafka holds *what happened* (history, replayable), RabbitMQ holds *what needs to be done* (work, consumed once). If you find yourself confused about which to use, ask which half of that sentence the messages belong to.

> **Mid-level answer stops here.** A mid-level dev can describe the differences. To sound senior, speak to the architectural implications and the decision-making discipline ↓
>
> **Senior signal:** recognizing that tool choice is a long-lived commitment with operational consequences, and articulating the trade-offs without tribal preference.

### The decision framework I use

When someone asks me to help pick a broker, I ask:

1. **Is this a task queue or an event log?** Commands consumed once → RabbitMQ. Facts retained and replayed → Kafka.
2. **Do multiple independent consumers need the same stream?** Yes → Kafka. No → RabbitMQ is simpler.
3. **Do I need replay?** Yes → Kafka. No → RabbitMQ.
4. **Do I need routing at the broker level?** Yes → RabbitMQ. No → either works.
5. **What's the throughput envelope?** Millions of events per second → Kafka. Anything less → either works.
6. **What's the team's operational capacity?** Small team → RabbitMQ is usually easier to run. Team with Kafka expertise → Kafka removes no blockers.
7. **Does the team already run one of them?** Strong default toward the existing tool unless the use case is clearly a mismatch.

If the first three questions point in the same direction, the answer is clear. If they point in different directions, the design probably has two separate problems and wants two separate tools.

### The trap of false equivalence

RabbitMQ and Kafka aren't competitors in the way "MySQL vs Postgres" are competitors. They're different categories of tool with overlapping job descriptions. The trap is treating them as interchangeable and picking based on taste — which leads to using one for the other's job, then spending years grinding against the design.

When I'm asked "should we use Kafka or RabbitMQ?", the honest answer is usually "what's the workload?" — because the right answer falls out immediately once the workload is described.

### Closing

"So the one-liner is: RabbitMQ for tasks and routing, Kafka for event streams and replay. RabbitMQ is a smart broker with rich per-message features; Kafka is a dumb log with first-class replay and scale. They solve different problems, and the biggest architectural mistakes I see are using one for the other's job. When a system has both kinds of workload, running both brokers is often the right answer — the operational cost is real but lower than fighting the wrong tool for years."
