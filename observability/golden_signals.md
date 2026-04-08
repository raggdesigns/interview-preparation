# The golden signals

**Interview framing:**

"The four golden signals — latency, traffic, errors, saturation — come from Google's SRE book and they're the answer to 'what should I measure to know if my service is healthy?'. The reason they matter is that most observability problems aren't about having too little data; they're about having too much data and not knowing what to look at. Golden signals give you a small, opinionated starter set: four dimensions that every service should expose, measured consistently, displayed together. If you can only have four metrics per service, these are the four."

### The four signals

#### 1. Latency

**What it is:** the time it takes to service a request.

**What to measure:**
- **Successful request latency.** How fast does the service respond when it works?
- **Failed request latency, separately.** Errors often have very different latency characteristics than successes — and mixing them produces misleading averages. A quick rejection with a 400 can make your average look good while the slow 500s that users actually care about get buried.

**What to care about:**
- **p50 (median)** — typical user experience.
- **p95 / p99** — tail experience, which is where users notice problems.
- **p99.9** — the worst-case envelope for high-volume services.
- **Not averages.** Averages hide tails. A service with 99 fast requests and 1 very slow request has a deceptively good average. Latency is only meaningful as percentiles.

**Common shapes:**
- **Healthy:** p50 and p99 are close together; tails are stable.
- **Saturated:** p50 is fine, p99 blows up. Queues are forming somewhere.
- **Broken:** p50 and p99 both spike. Something is fundamentally slow.

#### 2. Traffic

**What it is:** the demand on your service. For a web service, it's usually requests per second. For a pub/sub system, messages per second. For a database, queries per second.

**What to measure:**
- **Requests per second** split by endpoint, method, status class.
- **Bytes per second** (ingress/egress) for bandwidth-bound services.
- **Active connections** for long-lived-connection services (WebSocket, gRPC streaming).

**Why it matters beyond "how busy am I":**
- **Context for other signals.** A latency spike at 100 RPS and at 10,000 RPS mean very different things. Traffic is the denominator for everything else.
- **Anomaly detection.** A sudden drop in traffic is often the first sign of an upstream problem (your users can't reach you).
- **Capacity planning.** Traffic trends over weeks and months drive provisioning decisions.

**Common shapes:**
- **Daily/weekly patterns.** Most human-facing services have predictable curves; breaks in the pattern are a signal.
- **Sudden drops.** Usually a routing, DNS, or CDN issue — the service is fine, nobody can reach it.
- **Sudden spikes.** Traffic surge, retry storm from a downstream failure, or an attack.

#### 3. Errors

**What it is:** the rate of failed requests.

**What to measure:**
- **Error rate** — errors per second, or percentage of total requests.
- **Error class breakdown** — 4xx (client errors) vs 5xx (server errors). Distinguish them; they mean different things.
- **Error type breakdown** — timeouts, connection failures, application exceptions, business-logic rejections.

**What "error" means is non-trivial:**
- **HTTP 4xx is usually a client problem.** Don't alert on overall 4xx rate; do alert on specific 401/403/429 spikes that indicate auth breakage or attack.
- **HTTP 5xx is usually your problem.** These belong on dashboards and alerts.
- **Silent failures are the worst.** A service that returns 200 with garbage data is a 100% "success" rate from the metric's perspective. Golden signals can't catch this; only semantic checks can.
- **Business errors.** "Payment declined" isn't an infrastructure error, but it's a signal. Track business errors separately from technical errors so they don't pollute each other.

**Common shapes:**
- **Flat near-zero** — healthy.
- **Gradual creep** — something is degrading; investigate before it becomes an incident.
- **Sudden step** — a deploy, a config change, or a dependency failing.
- **Correlated with latency** — an overloaded downstream failing requests as it slows down.

#### 4. Saturation

**What it is:** how "full" the service is. How close are you to the limits of your resources?

**What to measure:**
- **CPU utilization** (as a percentage of the limit, not of the host).
- **Memory usage** vs the limit.
- **Queue depth** — how much work is waiting?
- **Connection pool utilization** — DB, HTTP, broker.
- **Thread pool / worker pool** utilization.
- **Disk I/O, disk space.**

**Why saturation is the trickiest signal:**
- **It's a leading indicator.** By the time errors spike, you're already broken. Saturation trending up gives you warning to scale or investigate before the symptom becomes user-visible.
- **It's resource-specific.** Every resource has its own saturation metric and its own limit.
- **It's non-linear.** A system at 60% CPU is usually fine; at 85% it's often fine too; at 95% it falls over. The relationship between saturation and performance is not smooth.

**Queue depth is the single most underrated saturation metric.** If a service has any kind of queue — request backlog, worker queue, database connection wait — the depth of that queue is a direct measurement of "how behind are we getting?". A growing queue is saturation happening in real time.

### Putting them together

The four golden signals fit on a single dashboard. The canonical layout:

```
┌─────────────────┬─────────────────┐
│  Latency (p50,  │  Traffic (rps)  │
│   p95, p99)     │                 │
├─────────────────┼─────────────────┤
│  Errors (rate,  │  Saturation     │
│   by class)     │  (CPU, memory)  │
└─────────────────┴─────────────────┘
```

Every service in the system has this four-quadrant dashboard. The dashboard is the same across services — only the values differ — so engineers can read an unfamiliar service's dashboard instantly because the layout is familiar.

This is the single highest-leverage dashboard you can build. It's the starting point for every incident investigation and the baseline for every service's health.

### How golden signals drive alerts

The key insight: **alert on user-visible symptoms, not on internal causes**. The golden signals are mostly user-visible (latency and errors), with saturation as a leading indicator.

Good alert shapes:
- **Error rate > 1% for 5 minutes** (user-visible failure rate)
- **p99 latency > 1000ms for 10 minutes** (user-visible slowness)
- **Queue depth > 500 for 5 minutes** (saturation approaching)
- **Error budget burn rate above SLO target** (see [slo_sli_sla.md](slo_sli_sla.md))

Bad alert shapes that golden-signal discipline avoids:
- CPU > 80% — so what? If users are fine, the service is fine.
- Memory > 90% — possibly normal; not user-visible until OOM.
- Pod restart count — each restart is not necessarily a problem.
- Specific exception types — you'll add these forever and never catch up.

Alert on what users experience. Use internal metrics for investigation, not for paging.

### Beyond the four — RED and USE

Two related frameworks worth knowing:

**RED (Request rate, Error rate, Duration)** — from Tom Wilkie. Essentially the first three golden signals: rate, errors, and latency. Designed specifically for request-driven services. The simplification is useful: "three things about every request".

**USE (Utilization, Saturation, Errors)** — from Brendan Gregg. For each resource (CPU, memory, disk, network), measure utilization (how much is used), saturation (how much extra work is queued), and errors. A bottom-up framework that complements the top-down request-oriented view of golden signals.

Golden signals are primarily request-oriented. USE is primarily resource-oriented. Mature teams use both: golden signals on the service dashboard, USE metrics in the infrastructure layer.

> **Mid-level answer stops here.** A mid-level dev can list the four signals. To sound senior, speak to how they fit into alerting strategy, what the traps are, and why "CPU" is not saturation by itself ↓
>
> **Senior signal:** using golden signals as the backbone of the alerting model, not just as a dashboard pattern.

### The traps to avoid

- **Averages instead of percentiles for latency.** Averages hide tails. Always use p50, p95, p99.
- **Rolling up all errors into one number.** "Error rate 5%" could be 4xx (mostly fine) or 5xx (catastrophic). Break them down.
- **Measuring saturation as "CPU percent" only.** CPU is one of many resources. Queue depth, memory, connection pools, worker pools — all count as saturation.
- **Treating saturation as the primary alert signal.** Saturation is a leading indicator; alert on user-visible symptoms (latency and errors) and investigate using saturation.
- **Missing the business-errors dimension.** A 100% technically-successful checkout flow that declines 90% of payments is a catastrophe that golden signals won't show you.
- **Dashboard per engineer.** Golden signals should be the same for every service so the cognitive load is low.
- **Alerting on everything the dashboard shows.** The dashboard and the alert are different things. Alerts are pages; dashboards are investigation.

### Implementing golden signals

For a PHP service:

- **Latency:** histogram of request durations, tagged by endpoint and status class. Prometheus client library gives you this with `Histogram`.
- **Traffic:** counter of requests, tagged by endpoint, method, status class. `Counter` with per-request increment in middleware.
- **Errors:** same counter as traffic, filtered by status class ≥500.
- **Saturation:**
  - CPU and memory from the process or container metrics (exposed automatically by most platforms).
  - PHP-FPM queue depth from `/fpm-status` endpoint, scraped by Prometheus.
  - Database pool saturation, broker queue depth — exposed by their respective exporters.

Most of this should live in middleware so individual controllers don't emit metrics themselves. Framework-level instrumentation means "every request is measured" is a property of the platform, not a thing each engineer remembers to add.

### Closing

"So the four golden signals — latency, traffic, errors, saturation — are the minimum viable observability for any service. They answer 'is the user experience degraded?', 'how much demand are we seeing?', 'how often are we failing?', and 'how close are we to the limits?'. A consistent four-quadrant dashboard across every service is the highest-leverage thing you can build. Alert on the user-visible signals, investigate with the saturation signals, and never use averages for latency. The rest of observability is either deeper drilling into one of these four or tracking things specific to your business, and you can add that incrementally as needed."
