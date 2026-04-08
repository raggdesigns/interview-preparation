# RabbitMQ exchange types

**Interview framing:**

"RabbitMQ has four exchange types, and picking the right one is the single design decision that shapes how your messaging topology will evolve. The wrong choice doesn't break anything immediately — it forces awkward workarounds later when you try to add a consumer the design didn't anticipate. The good news is the right choice is almost always obvious once you think in terms of 'how is this message addressed?'"

### The four types at a glance

| Type | Routing rule | Best for |
|---|---|---|
| `direct` | exact match on routing key | command-style task queues |
| `topic` | pattern match on routing key | event bus with hierarchical events |
| `fanout` | every bound queue gets a copy | broadcast: cache invalidation, notifications |
| `headers` | match on header attributes | rare: routing by metadata, not a key |

### direct — the task queue workhorse

The publisher sets a routing key; the exchange delivers the message to every queue bound with a binding key that **exactly matches** the routing key.

```
publish(exchange='tasks', routing_key='email.send', body=...)

queue 'email_worker' bound with key 'email.send'  → receives
queue 'pdf_worker'   bound with key 'pdf.render'  → ignores
```

Use it when:
- You have a fixed set of known task types.
- Each task has exactly one queue (or a small known set) that should handle it.
- The routing key *is* the task name: `email.send`, `pdf.render`, `report.generate`.

Mental model: direct is "named pipes". Each routing key is an address; queues bind to the addresses they care about.

### topic — the event bus

Routing keys are dot-separated strings (`order.created.eu`, `user.signup.premium`). Bindings are patterns with two wildcards:
- `*` matches exactly one word.
- `#` matches zero or more words.

```
publish(exchange='events', routing_key='order.created.eu')

queue 'eu_billing'    bound with 'order.*.eu'      → receives (matches)
queue 'all_orders'    bound with 'order.#'         → receives (matches)
queue 'us_billing'    bound with 'order.*.us'      → ignores
queue 'user_events'   bound with 'user.#'          → ignores
```

Use it when:
- Events have hierarchical structure you want to filter on.
- Different consumers care about different slices of the event stream.
- You expect new consumers to be added later with their own filtering needs.

Mental model: topic is "publish-subscribe with pattern matching". The producer emits events with descriptive keys; consumers subscribe to the patterns they care about.

**In practice, topic is my default for event-style messaging.** It subsumes direct (exact match is a degenerate pattern) and fanout (bind with `#` to get everything), and the cost of the pattern-matching engine is negligible.

### fanout — broadcast

Ignores the routing key entirely. Every queue bound to the exchange receives every message.

```
publish(exchange='cache_invalidation', routing_key='anything', body=...)

queue 'web_01_cache'  → receives
queue 'web_02_cache'  → receives
queue 'web_03_cache'  → receives
```

Use it when:
- Every consumer needs every message.
- Routing is meaningless because the answer is always "yes, deliver".
- You want the absolute simplest broadcast semantics.

Classic uses:
- **Cache invalidation** across a fleet of web servers.
- **WebSocket push** where every connected server needs to relay the event.
- **Pub/sub where all subscribers are equal peers.**

You can always achieve fanout behavior with topic + `#`. The reason fanout exists as its own type is that it's faster (no pattern matching) and more intention-revealing in the code.

### headers — routing by metadata

Instead of routing on a key, headers exchanges route on message headers. Bindings specify key-value pairs to match, plus an `x-match` parameter: `all` (match every header) or `any` (match at least one).

```
publish with headers = {format: 'pdf', priority: 'high'}

binding 'pdf_worker_high' with {format: 'pdf', priority: 'high', x-match: 'all'}
  → matches

binding 'any_pdf' with {format: 'pdf', x-match: 'any'}
  → matches
```

Use it when... honestly, rarely. The same routing can almost always be expressed with a well-designed topic key. The one case where headers shine is when the routing dimensions are independent and there are many of them — encoding them all into a routing key produces an ugly concatenation.

Mental model: headers is "routing on properties, not on names". Use it only when a flat key doesn't model your routing naturally.

### The default exchange

There's a fifth thing that looks like an exchange but shouldn't be used: the **default nameless exchange** (`""`). It routes messages to a queue whose name matches the routing key exactly. It exists for convenience — you can publish to a queue without declaring any exchange — but using it means your producer is coupled directly to the queue name. That's the anti-pattern that exchanges exist to prevent.

My rule: never publish to the default exchange in production code. Always declare an exchange explicitly, even if it's just a direct exchange with one binding. The cost is trivial and the indirection is what lets the system evolve.

### How to pick — a decision tree

```
Are you broadcasting to all consumers?
├── Yes → fanout
└── No → Do you want to filter by hierarchical patterns?
         ├── Yes → topic
         └── No → Is the routing deterministic on one string key?
                  ├── Yes → direct (or topic with exact match)
                  └── No → headers (rare; reconsider the design first)
```

In practice: I use topic for events, direct for task queues when I want the intent of "exact name match" to be obvious, and fanout when I genuinely need broadcast. Headers I've used maybe twice in a decade.

### Designing a good topic routing key

When you pick topic (which is most of the time), the quality of your system depends on the quality of your routing key scheme. Some principles:

- **Hierarchical from general to specific.** `order.created.eu` reads naturally; `eu.created.order` doesn't.
- **Stable dimensions first.** Put the dimensions that are least likely to change early in the key. Consumers binding with `order.*` shouldn't break when you add a new region.
- **Consistent depth.** Every key should have the same number of segments. Inconsistent depth turns `#` and `*` into traps.
- **Avoid high-cardinality segments.** Don't put user IDs or timestamps in routing keys. The routing table blows up.
- **Document the scheme.** Routing keys are an API contract. Write them down.

A good scheme might be: `<aggregate>.<event>.<region>.<environment>` → `order.created.eu.prod`. Anything you'd want to filter on goes into the key. Anything you wouldn't, stays in the message body.

> **Mid-level answer stops here.** A mid-level dev can describe the types. To sound senior, speak to the design consequences of exchange choice and the mistakes that lock you in ↓
>
> **Senior signal:** understanding that exchange design is a *schema* decision, with the same migration pain as any schema.

### The production concerns nobody tells you

- **Changing exchange types requires rebuilding.** You can't alter an existing exchange's type. Migrating from direct to topic means declaring a new exchange, dual-publishing while consumers migrate, then retiring the old one. Plan the routing scheme carefully up front.
- **Binding explosions.** Every queue × every matching pattern is a routing decision. On topic exchanges with complex patterns and many bindings, publish throughput can drop. Measure.
- **The `#` trap.** Binding with `#` catches every message, including messages you didn't anticipate when you wrote the consumer. When a new event is added to the stream, a `#`-bound consumer silently starts receiving it. Prefer narrower patterns.
- **Silent drops on unroutable.** A message with no matching binding is dropped silently by default. Set `mandatory=true` and handle returned messages, or configure an alternate exchange as a safety net.
- **Exchange-to-exchange bindings.** You can bind an exchange to another exchange, not just a queue. Useful for fan-in patterns and for abstracting routing behind a stable exchange name. Underused feature — it's genuinely elegant when you need it.

### Closing

"So the exchange type is the schema of your messaging system. Topic for events (with a well-designed hierarchical key scheme), direct for named task queues, fanout for genuine broadcast, headers for the rare case where routing is naturally multi-dimensional. The default exchange exists but shouldn't be used in production. And remember — exchange type is effectively immutable once deployed, so spend real time on the design before the first message flies."
