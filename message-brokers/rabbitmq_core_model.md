# RabbitMQ core model

**Interview framing:**

"RabbitMQ is an AMQP broker — producers send messages, consumers receive them, and the broker decouples the two. The thing that makes RabbitMQ interesting compared to a naive 'just put things in a queue' model is the *routing layer*: producers don't publish directly to queues, they publish to **exchanges**, and the exchange decides which queue or queues a message lands in. That indirection is the entire point of the design — it's what lets you add new consumers to a system without touching the producers."

### The five-piece model

1. **Producer** — the application that emits messages.
2. **Exchange** — the routing component the producer publishes to.
3. **Binding** — a rule that connects an exchange to a queue, usually with a routing key pattern.
4. **Queue** — a durable buffer that holds messages until a consumer reads them.
5. **Consumer** — the application that reads messages from a queue and does work.

A message flows `producer → exchange → (bindings) → queue(s) → consumer`. The exchange is the only thing the producer talks to. It knows nothing about which queues exist or who's reading.

### Why the indirection matters

If producers published directly to queues, every time you added a new consumer you'd have to update every producer to also publish to the new consumer's queue. That's tight coupling and it defeats the whole point of using a broker.

With exchanges and bindings, adding a new consumer is a two-step operation on the *consumer side only*: declare a queue, bind it to the existing exchange with an appropriate routing key. Producers don't change. A system where a new team can start listening to `order.created` events without touching the order service is a system that scales organizationally, not just technically.

### Channels and connections

- A **connection** is a TCP socket to the broker. It's expensive to open — TLS handshake, authentication, resource allocation on the broker.
- A **channel** is a lightweight virtual connection multiplexed over a TCP connection. You get many channels per connection.

The rule is: **one connection per process, many channels inside it.** Opening a new connection per message is the classic RabbitMQ anti-pattern — it'll bring the broker to its knees under load. Long-lived connections, one channel per thread or worker, is the right shape.

In PHP specifically this is where the request lifecycle bites. FPM request handlers can't reuse a connection across requests without extra work. Long-lived workers (Supervisor, Messenger consumers) can and should.

### Queue properties that matter

When you declare a queue, the properties you set determine its behavior under failure:

- **`durable`** — queue definition survives a broker restart. Without this, the queue disappears on restart even if it had messages.
- **`exclusive`** — only one connection can use the queue; auto-deleted when that connection closes. Used for per-client temporary queues.
- **`auto-delete`** — queue is deleted when the last consumer disconnects. Used for ephemeral fan-out queues.
- **`arguments`** — a map for advanced features: TTL, max length, dead-letter exchange, priority levels.

Durable by itself is not enough for persistence — the *messages* also need to be published with the `persistent` delivery mode flag set. Both are required to survive a broker restart. One without the other is one of the most common misconfigurations.

### The AMQP protocol underneath

RabbitMQ speaks AMQP 0-9-1 natively (with optional support for AMQP 1.0, MQTT, STOMP). The operations you care about:

- `exchange.declare` — create an exchange if it doesn't exist.
- `queue.declare` — create a queue if it doesn't exist.
- `queue.bind` — create a binding from an exchange to a queue.
- `basic.publish` — send a message to an exchange.
- `basic.consume` — subscribe a consumer to a queue.
- `basic.ack` / `basic.nack` — acknowledge or reject a delivered message.
- `basic.qos` — set prefetch (how many unacked messages a consumer can hold at once).

You rarely call these directly in PHP — you use a client library that wraps them — but understanding the underlying operations makes debugging much easier when something goes wrong.

### What happens when there's no binding

A message published to an exchange that has no matching binding is **silently dropped by default**. No error, no log, no notification. The broker just throws it away.

You opt into knowing about this by setting the `mandatory` flag on publishes — the broker then returns unroutable messages to the publisher via a return callback. Or you use the **alternate exchange** feature: attach a fallback exchange to the main one, and unroutable messages go there instead of being dropped.

This is the kind of detail that separates "I read a tutorial" from "I've debugged this in production" — and the default being silent is a real production gotcha.

### A minimal end-to-end flow

```
# Producer side
channel.exchange_declare('orders', type='topic', durable=True)
channel.basic_publish(
    exchange='orders',
    routing_key='order.created.eu',
    body=json_encoded_message,
    properties={'delivery_mode': 2}  # persistent
)

# Consumer side
channel.exchange_declare('orders', type='topic', durable=True)
channel.queue_declare('billing_service', durable=True)
channel.queue_bind(
    exchange='orders',
    queue='billing_service',
    routing_key='order.created.*'
)
channel.basic_qos(prefetch_count=10)
channel.basic_consume('billing_service', on_message, auto_ack=False)
```

The producer doesn't care whether the billing service exists. The billing service attaches itself to the event stream by binding its own queue. A new analytics consumer could attach itself tomorrow with its own queue and its own binding, and neither the producer nor the billing service would notice.

> **Mid-level answer stops here.** A mid-level dev can describe the components. To sound senior, speak to the failure modes and the operational concerns ↓
>
> **Senior signal:** the details that separate a tutorial understanding from running this in production.

### Things that bite in production

- **Unbounded queue growth.** If producers publish faster than consumers drain, queues grow without limit. Always set `x-max-length` or `x-max-length-bytes` with an overflow behavior (`drop-head`, `reject-publish`, or dead-letter). A silently growing queue is a broker crash waiting to happen.
- **Connection churn.** Opening and closing connections repeatedly — usually from PHP code running inside a short-lived request — crushes broker performance. Long-lived worker processes are the right home for consumers; producers inside FPM should use connection pooling or a local bridge.
- **Default exchange confusion.** RabbitMQ has a default nameless exchange (`""`) that routes by queue name directly. It exists for convenience but it encourages the anti-pattern of publishing directly to queues, defeating the point of exchanges. I avoid it in production code.
- **Mirrored queues vs quorum queues.** Classic HA queues (mirrored) are deprecated in favor of **quorum queues** for durability and failover. If you're starting fresh, use quorum queues. If you have mirrored queues, plan a migration.
- **Memory-backed vs disk-backed.** RabbitMQ holds messages in memory by default for speed. Under pressure it pages to disk, and the page-out can be slow. Tune the memory high-watermark and understand what happens when it's hit.
- **Schema-less payloads drifting.** RabbitMQ doesn't care about your message format. Over time, producers evolve their payloads and consumers silently break. I use versioned schemas (JSON schema or protobuf) and a version field in every message.

### Closing

"So the RabbitMQ core model is producer → exchange → binding → queue → consumer, with the exchange as the routing brain and the queue as the buffer. The indirection is what gives you decoupling; the connection/channel model is what gives you performance; the durability flags are what give you reliability. Everything else — exchange types, acknowledgements, DLX, prefetch — is details layered on top of those five primitives."
