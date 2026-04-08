# The three pillars: metrics, logs, traces

**Interview framing:**

"Observability is the ability to understand a system's internal state from its external outputs. The three pillars — metrics, logs, and traces — are the three kinds of output most commonly used, and they're complementary, not redundant. Each answers a different question: metrics tell you *that* something is wrong (and how wrong), logs tell you *what happened*, traces tell you *where* the time went. A team that only invests in one is blind to the other two. The senior move is knowing when to reach for which, and designing instrumentation so the three reinforce each other rather than duplicate."

### The core distinction

| Pillar | Answers | Shape | Cost model |
|---|---|---|---|
| **Metrics** | Is the system healthy? How much traffic? What's the error rate? | Low-cardinality numeric time series | Very cheap to store and query |
| **Logs** | What exactly happened on this specific request? | High-cardinality timestamped events | Expensive to store at volume, moderately cheap to query |
| **Traces** | Where did this request spend its time across services? | Causally-linked events tied to a single request | Moderate cost; usually sampled |

Each pillar is optimized for a different question. Asking the wrong pillar produces poor answers: trying to debug a specific broken request with metrics alone is like trying to read by the glow of an LED.

### Metrics: the "is something wrong" layer

Metrics are numeric time series. Values sampled over time, aggregated at the source, stored cheaply, queryable fast. The standard types:

- **Counter** — a monotonically increasing value (requests handled, bytes sent, errors).
- **Gauge** — a value that goes up and down (memory in use, pod count, queue depth).
- **Histogram** — a distribution of observations (request latency, response size). Gives you percentiles.
- **Summary** — like histograms but computed differently. Mostly replaced by histograms in modern stacks.

**What metrics are good at:**
- **Alerting.** "Error rate > 5% for 3 minutes" is a metric query. Cheap to evaluate, easy to reason about.
- **Dashboards.** Overview of system health at a glance.
- **Capacity planning.** Historical trends of request volume, resource usage, growth.
- **SLO tracking.** Percentage of requests below a latency threshold over a time window.

**What metrics are bad at:**
- **Debugging a specific request.** Metrics are aggregated; they tell you "5% of requests failed", not "which ones and why".
- **High cardinality.** Every unique label combination is a separate time series. Labels like user ID or request ID explode the metric count and kill your metrics backend. Keep labels low-cardinality (HTTP method, status class, service name) and push user/request details to logs or traces.
- **Rare events.** A metric that increments once a day is less useful than a log entry describing that event.

### Logs: the "what exactly happened" layer

Logs are timestamped events emitted as the system runs. Traditionally free-form strings; modern practice is **structured logs** — JSON documents with named fields that can be indexed and queried.

**What logs are good at:**
- **Debugging specific requests.** "Show me all logs for request ID xyz" is the canonical debugging query.
- **Capturing events that don't fit the metric model.** Business events, audit trails, infrequent but important happenings.
- **Rich context.** Stack traces, payloads, error messages — things you can't easily fit into a counter.

**What logs are bad at:**
- **Aggregation at scale.** Counting log events to compute rates is slow and expensive; use metrics instead.
- **Cost.** High-volume services can produce terabytes of logs per day. Storage and indexing are the dominant cost of observability for most teams.
- **Alerting.** You can alert on logs, but it's slower, more expensive, and noisier than alerting on metrics.

### Traces: the "where did the time go" layer

A trace is a tree of causally-linked events across a single request's lifetime, typically spanning multiple services. Each node in the tree is a **span** — a named operation with a start time, duration, and optional attributes. Spans have parent-child relationships, forming the tree.

**What traces are good at:**
- **Finding latency bottlenecks.** "This request took 2 seconds — which step took most of it?" Traces show you immediately.
- **Understanding cross-service flows.** "Which services does a checkout request touch?" A trace visualizes it.
- **Debugging distributed errors.** An error in service C can be traced back to its trigger in service A.
- **Characterizing unusual requests.** Why is this one request 10x slower than the median?

**What traces are bad at:**
- **Sampling trade-offs.** Tracing every request at high traffic is expensive; most teams sample. Sampled-out traces are gone forever.
- **Overhead.** Tracing adds CPU and memory cost to the application. Usually small, but non-zero.
- **Complexity.** Trace data is harder to query than metrics or logs. Trace UIs are specialized tools.

### How the three pillars work together

A typical debugging workflow uses all three:

1. **Alert fires** based on metrics: "p99 latency > 500ms for the billing service".
2. **Dashboard check** using metrics: "Error rate is normal; latency jumped at 14:23". Now you know *what* and *when*.
3. **Drill into traces** for the affected time window: find a slow request, look at its trace. "The DB query took 450ms of the 500ms."
4. **Check logs** for that specific trace: "The query is `SELECT * FROM orders WHERE ...`, and the database logs show it did a full table scan."
5. **Root cause found**: someone deployed code that removed an index usage.

Each pillar contributes a piece. Metrics surfaced the problem, traces localized it, logs explained it. None of the three alone would have been enough.

### The correlation problem

The value of the three pillars multiplies when they're correlated — when you can jump from a metric to the traces that contributed to it, from a trace to the logs of the specific request, from a log line to the broader trace it came from.

**Making correlation work:**
- **Every log line includes the trace ID.** When you find an interesting log entry, you can pull up the full trace instantly.
- **Every metric emission is tagged with the same dimensions you use in logs** (service name, environment). Gives you a common vocabulary.
- **Every span has a link to the logs it emitted.** Modern trace UIs do this automatically when both data sources exist.
- **Shared correlation identifiers.** Request IDs, trace IDs, user IDs propagated through every layer.

Without correlation, each pillar is a separate tool that you manually cross-reference. With correlation, they become one integrated view of the system.

### Cost implications — usually the dominant concern

Observability is expensive. For a moderately busy service, it's not unusual for metrics+logs+traces to cost more per month than the infrastructure running the actual service.

**Cost by pillar (rough):**
- **Metrics:** cheap per data point, but cardinality can explode costs if labels are unbounded. A counter with no labels is nearly free; the same counter with a `user_id` label can be thousands of dollars per month at moderate traffic.
- **Logs:** usually the most expensive by volume. Verbose logging at debug level in production is a common bill-killer. Log sampling, log level discipline, and retention policies matter.
- **Traces:** moderate per span, high if you sample everything. Most teams sample at 1-10% of traffic with always-on capture for errors and slow requests.

**Cost discipline:**
- **Sample traces.** 100% tracing is rarely necessary.
- **Structure logs and enforce levels.** Debug logs in production are wasted money.
- **Cap metric cardinality.** No user IDs in labels. Use traces for user-specific drilling.
- **Short retention for high-volume data, long retention for aggregates.** Keep 7 days of raw logs, 90 days of hourly rollups, 1 year of daily summaries.
- **Tiered storage.** Hot/warm/cold with automatic movement.

### The SRE mental model

The Google SRE book describes observability as the foundation of operating reliable systems. The core mental shift is: **you can't operate what you can't see**. Every incident teaches you something about what you couldn't see — and the response is usually "add more observability in this specific direction".

Good observability is built incrementally. You don't plan the full taxonomy up front; you add what you need when you need it, driven by incidents and questions you couldn't answer.

> **Mid-level answer stops here.** A mid-level dev can list the three pillars. To sound senior, speak to how they compose, where the costs fall, and how to design instrumentation for a system you're going to have to operate ↓
>
> **Senior signal:** treating observability as a design concern that starts at code-writing time, not a post-hoc tooling problem.

### The design-time discipline

Observability is easier to add when it's designed in from the start:

- **Every external call is measurable.** HTTP requests, database queries, cache lookups, message broker operations — all emit metrics, optionally logs, and are wrapped in spans.
- **Every error is logged with context.** Stack trace, request ID, relevant IDs (user, order, etc.). Never `catch (Throwable $e) {}` silently.
- **Every long-running operation has timing.** Even if you don't need the metric today, you will tomorrow.
- **Correlation IDs propagate everywhere.** Trace ID in HTTP headers, message headers, database query comments, cron job logs.
- **Log levels are disciplined.** Debug for development, info for significant events, warn for unexpected but handled, error for actual failures.
- **Feature flags and deploys are observable.** "Which version is running?" and "is this flag on?" should be trivially queryable.

### Common mistakes

- **Metrics with high-cardinality labels.** User IDs, request IDs, timestamps — each creates a new time series. Backends choke; bills explode.
- **Logs as the primary observability layer.** Tempting because logs are easy to emit. Result: aggregation is slow, alerting is noisy, costs are out of control.
- **Traces as an afterthought.** Added later, with sparse coverage, so they're only useful half the time.
- **No correlation IDs.** You can't jump from a metric alert to the specific requests causing it.
- **Verbose logs in production.** Debug logs from a high-volume service can cost thousands per month.
- **Dashboards that show everything.** The dashboard is optimized for nobody. A good dashboard answers specific questions.
- **Alerting on logs instead of metrics.** Slower, more expensive, noisier.
- **No retention discipline.** Storing everything forever at the same tier.

### Closing

"So the three pillars are metrics (aggregate health), logs (what happened), and traces (where the time went). They're complementary, each answering a different class of question, and correlated together through shared identifiers like trace IDs. Metrics drive alerts; traces localize the problem; logs explain it. The senior concerns are cost discipline — sampling, cardinality limits, log level hygiene, retention tiers — and designing instrumentation as part of the code, not bolting it on after an incident. A system you can't observe is a system you can't operate, and observability is one of those investments where the cost of not doing it is hidden until it isn't."
