# Distributed tracing

**Interview framing:**

"Distributed tracing is the technique of tracking a single request as it flows through multiple services, producing a tree of operations that shows exactly where the request spent its time, what it called, and what went wrong. It's the observability pillar that answers 'where did the time go?' — which is impossible to answer with metrics alone and painful to answer with logs. The thing most engineers underestimate is that tracing changes how you debug distributed systems: instead of cross-referencing logs by timestamp, you open a trace and see the whole request's life in one view. Once you've debugged an incident with traces, you don't go back."

### The core concept

A **trace** is a tree of **spans** representing a single request's execution across services and components.

A **span** is a named operation with:

- A start time and duration
- A unique span ID
- A parent span ID (or no parent, if it's the root)
- A trace ID that links it to all other spans in the same trace
- Attributes (key-value metadata)
- Events (timestamped log-like entries within the span)
- A status (success, error, unset)

Visually, a trace looks like this:

```text
trace: 4bf92f3577b34da6a3ce929d0e0e4736
┌──────────────────────────────────────────────────────────┐
│ POST /checkout                                    [450ms]│
│  │                                                        │
│  ├─ auth.verify_token                             [ 12ms]│
│  │                                                        │
│  ├─ db.query (SELECT cart)                        [ 23ms]│
│  │                                                        │
│  ├─ payment-service POST /charge                  [320ms]│
│  │   ├─ db.query (SELECT payment_method)          [ 15ms]│
│  │   ├─ external.call stripe                      [275ms]│
│  │   └─ db.insert (payment_record)                [ 18ms]│
│  │                                                        │
│  ├─ inventory-service POST /reserve               [ 45ms]│
│  │   └─ db.update                                 [ 38ms]│
│  │                                                        │
│  └─ broker.publish order.created                  [  8ms]│
└──────────────────────────────────────────────────────────┘
```

One glance tells you:

- The checkout took 450ms end-to-end.
- Of that, 320ms was the payment service.
- Of the payment service's 320ms, 275ms was calling Stripe.
- Inventory, auth, and database calls were fast.

If you're debugging why checkout is slow, you have your answer immediately: Stripe is slow. No log correlation, no timestamp arithmetic, no guessing.

### Why traces succeed where metrics and logs struggle

- **Metrics** tell you "the checkout endpoint is slow on average". They don't tell you which downstream component is responsible.
- **Logs** give you a sequence of events but not the *structure* — you see events, not the parent-child relationships. Correlating by timestamp is error-prone, especially for concurrent operations.
- **Traces** give you the structure for free. The parent-child relationships are captured at emission time, not reconstructed later.

The value proposition: "don't make me piece this together from timestamps".

### Trace context propagation — the foundation

A trace only works if the context — the trace ID and current span ID — flows from the caller to the callee. The propagation standard is W3C Trace Context.

**HTTP:** the `traceparent` header.

```text
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
```

Format: `version-traceId-parentSpanId-flags`.

**Message brokers:** the context is attached as message headers (`traceparent`, `tracestate`). Consumers extract and continue the trace.

**Database queries:** context can be injected as SQL comments so slow-query logs can be cross-referenced with traces.

**gRPC:** binary format for context headers, but the same concept.

Without propagation, every service starts a new trace and you get disconnected single-service traces that look like logs. With propagation, you get the full cross-service picture.

### Sampling — you can't trace everything

Tracing every request at high volume is expensive — in CPU on the producer side, in bandwidth to the collector, and in storage at the backend. Most teams sample.

**Head sampling** — decide at trace start. "Keep this trace" or "drop this trace" is set when the root span is created; all child spans inherit the decision.

- **Probabilistic head sampling:** "keep 10% of all traces".
- **Rate-limited head sampling:** "keep at most 100 traces per second".

Head sampling is cheap and predictable but blind: you might drop the trace that turned out to contain the bug.

**Tail sampling** — decide after the trace is complete. Spans are buffered (usually in the OTel Collector) until the trace is considered done (no new spans for N seconds), then a rule decides whether to keep it.

Tail sampling rules can be outcome-based:

- **Keep all traces with errors.** Rare and high-value.
- **Keep all traces slower than p99 latency.** Rare and high-value.
- **Sample 10% of normal traces.** Keep a statistical baseline.
- **Per-service rules.** Different services may have different sampling needs.

Tail sampling is the production-quality approach. It requires the infrastructure to buffer complete traces (more memory, short retention during buffering) but it gives you the right traces rather than a random subset.

### Span attributes and events

**Attributes** are key-value metadata on spans. They're how you make traces queryable.

```text
http.method = POST
http.url = /api/checkout
http.status_code = 200
user.id = 12345
order.amount_cents = 4599
payment.method = credit_card
```

Attributes turn traces from "a tree of operations" into "a queryable index". You can ask: "show me all traces where `payment.method = credit_card` AND `http.status_code = 500`" and the tracing backend finds them.

**Events** are timestamped log-like entries within a span. "Started processing", "cache hit", "retry attempt 2". They're lighter than logs (no level, no structured schema) and tied to the span's timeline.

```text
span: POST /checkout
  events:
    [  5ms] "cart validated"
    [ 23ms] "payment method selected: card"
    [200ms] "payment authorized"
    [320ms] "payment captured"
    [400ms] "inventory reserved"
    [445ms] "order persisted"
```

Events are useful for marking moments within a span without creating a new child span for every small thing.

### Span status and errors

A span has a status: `UNSET`, `OK`, or `ERROR`. The default is `UNSET`, which the backend typically treats as "assumed OK". Explicitly mark errors:

```php
try {
    $result = $this->paymentGateway->charge($amount);
    $span->setStatus(StatusCode::STATUS_OK);
} catch (\Throwable $e) {
    $span->recordException($e);
    $span->setStatus(StatusCode::STATUS_ERROR, $e->getMessage());
    throw $e;
}
```

**`recordException`** captures the exception as a span event with structured fields: exception type, message, stack trace. The trace viewer highlights spans with errors, making "where did the error come from?" a one-click answer.

The right pattern: every try/catch for an external call or meaningful operation should record exceptions on the current span before rethrowing.

### The tracing backends

- **Jaeger** — the classic CNCF tracing backend. Stable, widely deployed. Uses Elasticsearch or Cassandra for storage. Web UI for trace search and visualization.
- **Zipkin** — older, still in use. Similar feature set to Jaeger. Now largely superseded.
- **Grafana Tempo** — Grafana's tracing backend. Designed for cheap storage of massive trace volumes. Stores traces in object storage (S3, GCS). No indexing of span attributes — you query by trace ID from a metric/log correlation. Cheapest option for large scale.
- **Datadog APM, New Relic, Honeycomb, Lightstep, AppDynamics** — commercial. Richer UIs, more features, per-span pricing.

**The choice depends on:**

- Scale (Tempo for massive, Jaeger for moderate).
- Budget (Tempo/Jaeger for open-source, commercial for managed).
- Integration (Tempo pairs naturally with Grafana if you already use it).
- Feature needs (commercial tools often have better anomaly detection, service maps, etc.).

### Service maps — the view above individual traces

A **service map** is an aggregated visualization of which services call which, based on trace data. Nodes are services; edges are calls between them, weighted by rate and colored by error rate or latency.

Service maps answer different questions than individual traces:

- **"Which services depend on billing?"** — look at the edges entering the billing node.
- **"Where are errors concentrated?"** — red edges.
- **"What's the shape of my architecture?"** — the whole graph.

Good tracing backends generate service maps automatically from trace data. Every new service that gets instrumented appears in the map without additional configuration.

### Local trace debugging

A surprisingly useful tool: **trace viewers in development**. Running Jaeger or Tempo locally (via Docker Compose) and pointing your dev environment at it gives you trace visualization while you're building features. You see the structure of your code's execution — the queries it makes, the external calls, the timing — and you catch performance bugs before they hit production.

In Symfony with the Symfony profiler, you already get a request-scoped view of queries and timings. Adding OTel + Jaeger on top gives you the cross-service view and the persistent history.

### Combining traces with metrics and logs

The three pillars work together. A realistic debugging flow:

1. **Metric alert fires**: p99 latency > 1000ms for the checkout service.
2. **Grafana dashboard** shows the spike started at 14:23. No deploy annotation; not a deploy.
3. **Click through to traces** for the time window, filtered to slow requests on the checkout endpoint.
4. **Open a trace**: the payment service span is dominating. Inside it, the Stripe call is 2.5 seconds.
5. **Click through to logs** for the payment service span. The logs show HTTP 503 from Stripe's API.
6. **Root cause**: Stripe incident. Check Stripe status page. Confirm.

Traces pivot you from "something is slow" to "this specific call is slow" to "here's why". Without traces, step 3-5 would take an order of magnitude longer.

### PHP-specific considerations

- **Auto-instrumentation** covers most of what you care about: incoming HTTP via Symfony/Laravel, outgoing HTTP via Guzzle, database via PDO/Doctrine, message brokers via Symfony Messenger.
- **Manual spans** for business operations: the "process_payment" or "validate_order" operations that span multiple calls and deserve to appear as a named span in the trace.
- **Context in workers.** Long-running Messenger consumers need the trace context from the message they're processing. Auto-instrumentation handles this; manual code needs to extract `traceparent` from message headers.
- **Async operations.** PHP doesn't have async in the traditional sense, but scheduled jobs and background tasks still need to participate in traces — use explicit context propagation from the triggering request or scheduled-job metadata.

### The cost model

Tracing adds:

- **CPU overhead** on the producer side (creating spans, serializing, sending). Small but measurable at high throughput.
- **Network bandwidth** to the collector (especially with large traces and many attributes).
- **Storage cost** at the backend (proportional to trace volume and retention).

Sampling is the primary cost control. Tail sampling for the "keep the important ones" model; head sampling for simple percentage drops. For large systems, tracing costs can rival logging costs if not controlled.

> **Mid-level answer stops here.** A mid-level dev can describe spans and context propagation. To sound senior, speak to the operational patterns — sampling strategy, correlation with other pillars, and how traces change debugging ↓
>
> **Senior signal:** treating tracing as a production tool that changes how incidents are investigated and how slow code is diagnosed.

### The operational discipline

- **Propagate context everywhere.** Every HTTP client, every message broker interaction, every async boundary. Missing propagation creates "broken traces" — orphaned spans that can't be joined to their parents.
- **Record exceptions on spans.** Every try/catch that matters should attach the exception to the current span.
- **Use semantic convention attributes.** `http.*`, `db.*`, `messaging.*` — the names the backend knows about.
- **Sample based on outcomes, not just rate.** Keep errors, keep slow requests, sample the rest.
- **Correlate with logs and metrics.** Trace ID in every log line; exemplar trace IDs on metric histograms (so dashboards can link from a metric spike to a contributing trace).
- **Keep trace retention short.** Traces are for operational debugging, not long-term archival. 7-30 days is typical; compliance-relevant events go to logs and stay longer.
- **Monitor the tracing pipeline itself.** Dropped spans, collector backpressure, storage saturation — these degrade the tool just as silently as log or metric pipelines fail.

### Common mistakes

- **No context propagation across services.** Traces stop at service boundaries; you get disconnected single-service views.
- **No manual spans for business operations.** Auto-instrumentation gives you framework-level spans; the business-meaningful operations stay invisible.
- **Unbounded attribute cardinality.** User IDs or request IDs as span attributes is fine (traces are indexed by span ID, not attribute), but dumping huge blobs into attributes slows everything down.
- **Sampling everything at 100% in production.** Expensive and often unnecessary.
- **Sampling nothing (0%) in production.** Makes the trace backend exist without any actual data to trace.
- **Treating trace backends as long-term storage.** Traces are for short-term operational use, not archival.
- **Not recording exceptions on spans.** Error traces look "normal" and require reading logs to find the failure.

### Closing

"So distributed tracing tracks a single request across services as a tree of spans, each with attributes, events, and a status. Context propagation is the foundation — trace IDs in HTTP headers, message headers, SQL comments. Sampling is the cost control — probabilistic head sampling is simple, tail sampling based on outcomes is better. The value proposition is that debugging distributed systems changes fundamentally when you can see the whole request in one view. Instrument once with OTel, export to Tempo or Jaeger or a commercial backend, correlate with logs and metrics, and you've got the three-pillars observability story that modern operations depend on."
