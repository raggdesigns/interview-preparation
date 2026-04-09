# Prometheus basics

**Interview framing:**

"Prometheus is the de facto open-source metrics system — a time-series database plus a scraping-based collection model plus a query language plus an alerting engine, bundled into one project. It won the metrics war for cloud-native workloads because it's pragmatic: simple data model, pull-based collection that maps naturally to Kubernetes service discovery, and a query language powerful enough to do real work without being overwhelming. If you run containers at any scale and care about observability, you either run Prometheus or run a managed service that speaks its API."

### The mental model

Prometheus is built around a few simple ideas:

1. **Targets expose metrics over HTTP** at a `/metrics` endpoint in a plain-text format. Each target is an instance of a service.
2. **Prometheus scrapes them** on a schedule (every 15 seconds by default). Each scrape is a snapshot of all the metrics the target exposes.
3. **Scraped data is stored** in a time-series database as `(metric_name, labels, timestamp, value)` tuples.
4. **Queries use PromQL** — a functional query language specifically for time-series data.
5. **Alerts are PromQL queries** evaluated periodically; when the query returns results, an alert fires.
6. **Alertmanager** receives alerts and routes them to notification channels (PagerDuty, Slack, email, etc.).

### The data model

A Prometheus metric is identified by:

- **Metric name** — `http_requests_total`, `http_request_duration_seconds`, etc.
- **Labels** — key-value pairs that distinguish series. `{method="POST", status="200", endpoint="/api/orders"}`.

Each unique combination of name + labels is a separate **time series**. Scraping a target that exposes `http_requests_total{method="GET", status="200"}` with value 1234 produces one time series; the same metric with different labels is a different series.

The combination of label values is called **cardinality**, and cardinality is the single most important design concern for Prometheus. More on this below.

### The four metric types

Prometheus has four metric types that the client libraries expose:

#### Counter

A value that only goes up (except when it resets to zero on process restart). Used for:

- Total requests handled
- Total errors
- Total bytes sent
- Total messages processed

```text
http_requests_total{method="POST", status="200", endpoint="/orders"} 4521
```

Counters are aggregated over time with the `rate()` function — "how many requests per second over the last 5 minutes?".

```promql
rate(http_requests_total[5m])
```

**Don't use counters for anything that can decrease.** Memory usage, queue depth, active connections — those are gauges.

#### Gauge

A value that can go up or down:

- Memory usage
- CPU usage
- Number of active connections
- Queue depth
- Temperature

```text
nodejs_heap_size_used_bytes 234567890
```

Gauges are queried directly — the value at scrape time is the value. No need for `rate()`.

#### Histogram

A distribution of observations across predefined buckets, plus a sum and count. Used for:

- Request duration
- Response size
- Anything where percentiles matter

A histogram with bucket boundaries `[0.1, 0.5, 1.0, 5.0]` produces multiple time series:

```text
http_request_duration_seconds_bucket{le="0.1"} 3500
http_request_duration_seconds_bucket{le="0.5"} 4800
http_request_duration_seconds_bucket{le="1.0"} 4950
http_request_duration_seconds_bucket{le="5.0"} 4998
http_request_duration_seconds_bucket{le="+Inf"} 5000
http_request_duration_seconds_sum 842.5
http_request_duration_seconds_count 5000
```

Each bucket is a counter of observations ≤ that bound. You can compute p99 with `histogram_quantile`:

```promql
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```

**Bucket design matters.** Bucket boundaries are fixed at collection time and can't be changed retroactively. Too few buckets → poor percentile accuracy. Too many buckets → cardinality blowup. A typical web service uses 10-15 buckets spanning microseconds to seconds.

#### Summary

Similar to a histogram but the quantiles are computed on the client side and reported directly. Sum and count are also reported.

```text
http_request_duration_seconds{quantile="0.5"} 0.12
http_request_duration_seconds{quantile="0.95"} 0.45
http_request_duration_seconds{quantile="0.99"} 1.2
```

**Mostly deprecated in favor of histograms** because summaries can't be aggregated across instances (you can't meaningfully average the p99s of 10 pods). Histograms can. Use histograms unless you have a specific reason to use a summary.

### Scraping — how Prometheus collects data

Prometheus pulls metrics from targets over HTTP. You configure targets via **scrape configs**:

```yaml
scrape_configs:
  - job_name: 'billing-service'
    scrape_interval: 15s
    static_configs:
      - targets: ['billing:9090', 'billing-2:9090', 'billing-3:9090']
```

Each target is scraped every 15 seconds. The target exposes `/metrics` in the Prometheus text format.

**Service discovery** is more practical than static configs for real deployments. Prometheus can discover targets via:

- **Kubernetes** — auto-discover pods, services, endpoints based on labels and annotations.
- **Consul** — service registry integration.
- **EC2, GCP, Azure, Kubernetes** — cloud-native discovery.
- **File-based** — write a JSON file listing targets; Prometheus reads it.

For Kubernetes, the typical pattern is annotating pods to opt in:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
    prometheus.io/path: "/metrics"
```

Prometheus discovers the pods and scrapes them automatically.

### The pull model vs push

Prometheus uses **pull-based scraping** — it connects to targets and asks for metrics. Most other systems (Datadog, InfluxDB, etc.) use **push-based reporting** — targets push their metrics to the system.

**Pull advantages:**

- **Discovery is centralized.** Prometheus decides what to scrape; targets don't need to know where Prometheus is.
- **Target health is implicit.** A target that can't be scraped triggers an `up{}` metric going to 0.
- **Easy to debug.** You can curl the `/metrics` endpoint yourself.
- **Works well with dynamic environments.** Kubernetes service discovery makes scraping new pods automatic.

**Pull disadvantages:**

- **Firewall concerns.** Prometheus needs network access to targets.
- **Short-lived jobs.** Jobs that start, run, and exit before the next scrape can't be pulled. Solution: the **Pushgateway** — a push-compatible accumulator that Prometheus scrapes.

For most container workloads, pull is the right model. Short-lived tasks use the Pushgateway.

### PromQL — the query language

PromQL is a functional language designed for time-series math. A few patterns that cover most real queries:

**Current value of a metric:**

```promql
node_memory_MemAvailable_bytes
```

**Filter by labels:**

```promql
http_requests_total{job="billing", status=~"5.."}
```

Returns all 5xx responses from the billing job.

**Rate over a time window:**

```promql
rate(http_requests_total[5m])
```

Requests per second averaged over the last 5 minutes.

**Aggregation across labels:**

```promql
sum by (status) (rate(http_requests_total[5m]))
```

Total request rate, summed across all dimensions, split out by status code.

**Percentiles from histograms:**

```promql
histogram_quantile(0.99,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
)
```

p99 request duration across all instances.

**Ratios (error rates):**

```promql
sum(rate(http_requests_total{status=~"5.."}[5m]))
  /
sum(rate(http_requests_total[5m]))
```

5xx rate as a fraction of total requests.

PromQL has plenty more — joins, offsets, subqueries, label manipulation — but these five patterns cover most day-to-day queries.

### Recording rules — precomputed queries

Some queries are expensive to run on every dashboard refresh. **Recording rules** let you precompute and store them as new metrics.

```yaml
groups:
  - name: http_rules
    interval: 30s
    rules:
      - record: job:http_requests:rate5m
        expr: sum by (job) (rate(http_requests_total[5m]))
```

Now instead of recomputing the sum-of-rates on every query, dashboards and alerts can reference the precomputed `job:http_requests:rate5m` directly. Used heavily for expensive queries behind SLO dashboards.

### Alerting rules

Alerts are PromQL queries evaluated periodically. When the query returns results, the alert fires.

```yaml
groups:
  - name: billing_alerts
    rules:
      - alert: HighErrorRate
        expr: |
          sum by (service) (rate(http_requests_total{status=~"5..",service="billing"}[5m]))
            /
          sum by (service) (rate(http_requests_total{service="billing"}[5m]))
            > 0.01
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Billing 5xx rate above 1%"
          description: "Error rate is {{ $value | humanizePercentage }}"
```

Key parts:

- **`expr`** — the query that defines "is this bad?". Returning at least one result means the alert is active.
- **`for: 5m`** — require the condition to persist for 5 minutes before firing. Smooths out brief spikes.
- **`labels`** — attached to the alert, used for routing in Alertmanager.
- **`annotations`** — human-readable context; used in notification messages.

### Alertmanager — routing and deduplication

Prometheus fires alerts; **Alertmanager** routes them. It handles:

- **Grouping.** Related alerts (all from the same service) are batched into one notification.
- **Deduplication.** If the same alert fires from multiple Prometheus instances (HA), only one notification goes out.
- **Silencing.** Temporarily suppress specific alerts (e.g., during planned maintenance).
- **Inhibition.** If a "service down" alert is firing, suppress the "high error rate" alerts that are symptoms of it.
- **Routing.** Different alerts go to different channels (critical → PagerDuty, warnings → Slack).

Separating fire-detection (Prometheus) from routing (Alertmanager) lets you evolve alert policy without touching your metric rules.

### Cardinality — the thing that kills Prometheus

Every unique combination of metric name + label values is a new time series. Prometheus holds all series in memory. Cardinality explosions kill Prometheus deployments.

**High-cardinality fields you must not put in labels:**

- User IDs
- Request IDs
- Trace IDs
- Email addresses
- Full URLs (only paths, and pattern them)
- Timestamps

**Acceptable labels:**

- Service name
- HTTP method (small enum)
- HTTP status code (small enum)
- Endpoint (parameterized: `/api/users/:id`, not `/api/users/12345`)
- Environment, region, pod name (bounded sets)
- Error type (small enum)

**The rule:** a label should have tens to hundreds of distinct values, not thousands to millions. If you find yourself wanting to label by user, you want traces or logs, not metrics.

### Storage — how Prometheus keeps data

- **Local storage** — Prometheus writes to its own local disk in a time-series format. Default retention is 15 days.
- **Remote write** — Prometheus can stream data to a remote backend (Thanos, Cortex, Mimir, VictoriaMetrics, cloud managed services).
- **Long-term storage** — for retention beyond 15 days or cross-cluster queries, use one of the remote-write backends. Prometheus itself isn't designed for years-long storage.

For anything serious, the pattern is: **Prometheus for scraping and short-term storage, a remote backend for long-term storage and global queries**.

### The exporter ecosystem

Prometheus "exporters" are small processes that translate third-party service metrics into the Prometheus format. Well-known ones:

- **node_exporter** — host-level metrics (CPU, memory, disk, network).
- **kube-state-metrics** — Kubernetes object state (pods, deployments, etc.).
- **mysql_exporter** / **postgres_exporter** — database metrics.
- **redis_exporter**, **rabbitmq_exporter**, **nginx_exporter** — service-specific.
- **blackbox_exporter** — probe HTTP/TCP/ICMP targets from outside.

For anything you don't run yourself, there's probably an exporter. For your own code, use the Prometheus client library for your language.

### PHP instrumentation

The Prometheus PHP client library exposes counters, gauges, histograms, and summaries with the same API as other languages:

```php
use Prometheus\CollectorRegistry;
use Prometheus\Storage\Redis;

$registry = new CollectorRegistry(new Redis());

$counter = $registry->getOrRegisterCounter(
    'billing',
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'status']
);
$counter->inc(['POST', '200']);

$histogram = $registry->getOrRegisterHistogram(
    'billing',
    'http_request_duration_seconds',
    'HTTP request duration',
    ['method', 'endpoint'],
    [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
);
$histogram->observe($duration, ['POST', '/orders']);
```

The catch: PHP's request lifecycle means counters and histograms need persistent storage between requests. The `Redis` adapter (or APCu for single-server) holds the state. Without persistence, every request starts with a blank slate and metrics are useless.

For Symfony, the `artprima/prometheus-metrics-bundle` wraps this and provides middleware instrumentation out of the box. For long-running worker processes (Messenger consumers), the standard client library works directly without needing external storage.

> **Mid-level answer stops here.** A mid-level dev can describe the types and PromQL basics. To sound senior, speak to cardinality discipline, the cost model, and how Prometheus fits into a broader observability story ↓
>
> **Senior signal:** treating cardinality as the primary design constraint and running Prometheus as production infrastructure with its own concerns.

### Running Prometheus as production infrastructure

- **HA pairs.** Two independent Prometheus instances scraping the same targets. Alertmanager deduplicates. No clustering between the Prometheuses themselves.
- **Retention planning.** 15 days local, months or years in remote storage.
- **Backup and disaster recovery.** For locally-stored data, regular snapshots. For remote storage, whatever backup story the backend provides.
- **Resource sizing.** Prometheus is memory-hungry (all active series in RAM) and disk-I/O-bound on scrape. Monitor Prometheus with Prometheus.
- **Federation.** Running Prometheus at multiple levels — one per cluster, one global — with federation pulling aggregated data up.
- **Recording rules for expensive queries.** Anything that appears on dashboards and takes more than a few seconds should be a recording rule.

### Common mistakes

- **Labels with unbounded cardinality.** User IDs, request IDs, timestamps.
- **Too many buckets in histograms.** Each bucket is a series; exploding histograms eat memory.
- **Summaries instead of histograms.** Can't aggregate across instances.
- **No recording rules for dashboard queries.** Slow dashboards and expensive repeated computation.
- **Alerting directly on metrics Prometheus scrapes from your own app without buffering time.** A single slow scrape looks like a crash.
- **Logging volume to metrics instead of logs.** Metrics are for aggregation; individual events go to logs.
- **No SLO-based alerting, only threshold-based.** Threshold alerts are noisy; SLO-based burn-rate alerts are the modern standard. See [slo_sli_sla.md](slo_sli_sla.md).

### Closing

"So Prometheus is a pull-based time-series system with four metric types, a PromQL query language, and an alerting pipeline through Alertmanager. The key design concern is cardinality — keeping labels bounded — because unbounded cardinality kills Prometheus. Use histograms for latency, counters for rates, gauges for current values, and never user IDs in labels. For production, pair two Prometheus instances for HA, use recording rules for expensive queries, and remote-write to a long-term storage backend for retention beyond 15 days. It's the default open-source metrics system for good reason, and for most container workloads, it's either Prometheus directly or a managed service speaking Prometheus's protocols."
