# RabbitMQ reliability: acks, prefetch, durability, persistence

**Interview framing:**

"Reliability in RabbitMQ is not one feature, it's a chain of four independent settings that all have to be right for a message to actually survive the things you think it's going to survive. People set two of them, assume they're safe, and lose messages the first time something goes wrong. The four are: durable exchanges, durable queues, persistent messages, and manual acknowledgements. Getting them right is mostly about knowing they exist and setting them together."

### The reliability chain

A message from producer to consumer has multiple failure points. Each one has its own mitigation:

| Failure | Mitigation |
|---|---|
| Broker restarts; exchange definition lost | `durable=true` on exchange |
| Broker restarts; queue definition lost | `durable=true` on queue |
| Broker restarts; in-flight messages lost | `delivery_mode=2` (persistent) on publish |
| Consumer crashes while processing a message | **manual ack** (no auto-ack) |
| Network drops during publish, broker never saw it | **publisher confirms** |

All five are independent. Setting only some of them produces gaps.

### Acknowledgements — the consumer-side guarantee

When a consumer receives a message, the broker marks it as "delivered but unacknowledged". It stays in the queue in that state until the consumer explicitly acknowledges (`basic.ack`) or rejects it (`basic.nack` / `basic.reject`).

**Auto-ack mode** — the broker considers a message acknowledged as soon as it's delivered, before the consumer has done any work. If the consumer crashes mid-processing, the message is gone. **Never use auto-ack for anything that matters.** It exists for throughput-critical scenarios where losing occasional messages is acceptable (log shipping, metrics fan-out).

**Manual ack** — the consumer calls `ack` only after successfully processing the message. If the consumer crashes before acking, the broker re-delivers the message to another consumer (or back to the same one when it reconnects). This is the default for any production work queue.

The common mistake is acking too early — before the work is actually done. "Received the message" is not "processed the message". The ack should happen *after* the database write, *after* the external API call, *after* everything the message was supposed to cause.

### Nack and reject

- **`basic.nack`** — mark the message as failed. With `requeue=true`, it goes back to the front of the queue. With `requeue=false`, it's either dropped or dead-lettered (if a DLX is configured).
- **`basic.reject`** — the single-message version of nack.

The classic mistake: nacking with `requeue=true` on a poison message (a message that will always fail). The message loops forever, getting redelivered, failing, requeued, failing. This is why dead-letter exchanges exist — to give poison messages a home other than an infinite loop.

### Prefetch — the flow control knob

`basic.qos(prefetch_count=N)` tells the broker: "don't send me more than N unacknowledged messages at a time". Without it, the broker default is **unlimited** — it dumps the entire queue into the first consumer that connects.

This single setting is the most common misconfiguration I see. Without a prefetch limit:

- One consumer receives thousands of messages and its memory explodes.
- Other consumers sit idle because the first one has everything.
- If that consumer crashes, thousands of messages are redelivered at once to whoever picks them up.

**How to pick prefetch:**

- **Long slow jobs** (each task takes seconds or more): `prefetch_count=1`. Each consumer handles one message at a time; load balances naturally; crashes only lose one in-flight message.
- **Fast tasks** (each task takes milliseconds): `prefetch_count=10-100`. The overhead of acknowledging per message starts to matter; batching some delivery is a win.
- **Very fast tasks** (sub-millisecond, e.g. metric fan-out): even higher, or use a separate streaming system.

When in doubt, start with 1 and increase only after measuring. Low prefetch is rarely a bottleneck in practice; high prefetch causes subtle distribution bugs that are hard to diagnose.

### Durability — broker-restart survival

Two flags, both required for queues and exchanges to survive a broker restart:

- **`durable=true` on exchange declaration.** The exchange definition is written to disk.
- **`durable=true` on queue declaration.** The queue definition is written to disk.

Without `durable`, the exchange or queue disappears when the broker restarts. New publishes land on a recreated empty queue (if the producer recreates it) or get dropped silently.

The catch: durable exchanges and queues protect the **topology**, not the **messages**. You also need persistent messages.

### Persistence — message-level survival

A published message is held in memory by default. If the broker restarts, the message is lost even if the queue it was in is durable.

Setting `delivery_mode=2` (or equivalently, `persistent=true` in most libraries) tells the broker to write the message to disk before acknowledging the publish. On restart, the message is recovered.

**The gotcha:** persistence is per-message, not per-queue. A durable queue can hold non-persistent messages (they're lost on restart). A non-durable queue can't meaningfully hold persistent messages (the queue itself is gone). You want both, always, for anything that matters.

Cost of persistence: a small throughput hit because every message does a disk write. For most systems it's negligible. For very high-throughput scenarios, you may split traffic — persistent for important messages, non-persistent for best-effort ones.

### Publisher confirms — the missing link

Durability + persistence protects against broker restarts *after* the broker has the message. But what if the network drops between the producer and the broker? The producer sent a message; the broker never received it; the producer has no idea.

**Publisher confirms** fix this. When confirms are enabled, the broker sends an ack back to the producer for every message it has successfully accepted (and persisted to disk, if applicable). The producer knows the message is safe only after receiving the confirm.

Pseudocode:

```text
channel.confirm_select()  # enable confirms

channel.basic_publish(..., properties={'delivery_mode': 2})
if channel.wait_for_confirms(timeout=5):
    # message is safely in the broker
else:
    # the broker never confirmed; resend or alert
```

Without publisher confirms, you have at-most-once delivery from producer to broker — messages can be lost in the network layer and nobody knows.

Confirms add latency (round-trip per publish, or per batch if you use batched confirms). In exchange, you get the guarantee that publishes have either succeeded or failed loudly. For critical work, they're non-negotiable.

### Putting it together — the full reliable pipeline

For anything important, all of these need to be set:

1. **Producer side:**
   - `confirm_select()` — publisher confirms on.
   - Publish with `delivery_mode=2` — persistent messages.
   - Wait for confirms (or use async confirm callbacks).
   - On confirm failure or timeout, retry or alert.

2. **Broker topology:**
   - `exchange.declare` with `durable=true`.
   - `queue.declare` with `durable=true`.
   - Consider `x-max-length` and a DLX for poison messages.

3. **Consumer side:**
   - `basic.qos(prefetch_count=N)` — appropriate prefetch.
   - `basic.consume` with `auto_ack=false`.
   - Process the message fully.
   - `basic.ack` on success.
   - `basic.nack(requeue=false)` on unrecoverable failure (so it dead-letters).

Missing any one of these five has a failure mode. Together they give at-least-once delivery through the whole pipeline.

> **Mid-level answer stops here.** A mid-level dev can describe ack and durability. To sound senior, speak to the failure modes and the performance/reliability trade-offs ↓
>
> **Senior signal:** recognizing that at-least-once delivery is a ceiling, not a floor, and building consumers that cope with the *consequences* of at-least-once.

### At-least-once is all you get — and what that means

The RabbitMQ reliability chain gives you **at-least-once delivery**. It does not give you exactly-once. Messages can be delivered twice under normal operation — not as a bug, but as a consequence of how acknowledgements work:

1. Consumer receives a message.
2. Consumer processes it and performs side effects.
3. Consumer's ack is lost (network blip, consumer crash right before ack).
4. Broker times out, re-delivers the message to another consumer.
5. The second consumer performs the side effects *again*.

The mitigation is not "prevent this" (you can't) but "make it harmless". **Consumers must be idempotent.** Either naturally (the operation is a set rather than an add) or explicitly (track processed message IDs in a deduplication table). Idempotency is a consumer-side concern, and it's non-negotiable for any system using at-least-once delivery.

### Performance vs reliability trade-offs

Every reliability feature has a cost. You can reason about the cost without measuring:

- **Durable queues** — small one-time cost at declaration, no runtime cost.
- **Persistent messages** — disk write per publish. Noticeable only at high throughput.
- **Publisher confirms** — RTT per confirm, or batch amortized. Adds latency.
- **Manual ack** — an extra broker round trip per message. Negligible on local networks.
- **Prefetch=1** — serializes per consumer, reducing parallelism. Counter-intuitively, often *faster* overall because messages distribute evenly.

For most systems, reliability costs are negligible. For hot paths, measure before relaxing them, and never relax them silently — make it a deliberate architectural decision with the loss model documented.

### Common misconfigurations I've seen

- **Auto-ack on a work queue.** Messages vanish on crash. The most common reason "RabbitMQ lost my messages" turns out to be a config issue, not a broker bug.
- **Durable queue, non-persistent messages.** Survives topology restart, loses the messages. People set durable and assume persistence comes with it.
- **No prefetch limit.** First consumer gets everything; others idle; memory blows up.
- **Requeue loops on poison messages.** Nacking with requeue on a message that will never succeed. Needs DLX with a max-retry count.
- **Acking before the work is done.** "Received the message" vs "finished processing the message" are different events. Ack after the second, not the first.
- **No publisher confirms.** Silent loss on network hiccups between producer and broker.
- **Non-idempotent consumers.** At-least-once delivery → duplicate side effects.

### Closing

"So reliability in RabbitMQ is a chain of five settings: durable exchanges, durable queues, persistent messages, publisher confirms, and manual acks on the consumer. All five are needed for at-least-once delivery end-to-end. At-least-once is the ceiling — exactly-once is a myth at this layer — which means consumers must be idempotent. The performance cost of the full reliability chain is almost always worth it; relax it only when you've measured and the loss model is acceptable."
