# OpenTelemetry basics

**Interview framing:**

"OpenTelemetry — OTel — is the CNCF's observability framework for producing, collecting, and exporting telemetry data. It's the convergence of two earlier projects (OpenTracing and OpenCensus) and it's become the industry standard for instrumentation. The reason it matters: before OTel, every vendor had their own SDK, and instrumenting code for one vendor locked you in. OTel is vendor-neutral — you instrument once, and you can export to any backend that speaks the OTel protocol: Prometheus, Jaeger, Tempo, Datadog, New Relic, Honeycomb, cloud-managed services. Vendor neutrality is the killer feature, and the model itself is solid enough that 'instrument with OTel' is now the default answer."

### The three parts of OpenTelemetry

OpenTelemetry has three concerns, and understanding the separation is the first interview insight:

1. **API** — the code you write in your application. Language-specific but following cross-language conventions. "Start a span here. Record this metric. Emit this log with this attribute."

2. **SDK** — the concrete implementation that collects the data from the API and batches/exports it. Also language-specific.

3. **Collector** — a standalone process (written in Go) that receives telemetry data from SDKs, processes it (batching, filtering, sampling, enriching), and exports it to backends. Optional but usually present in production.

4. **Protocol (OTLP)** — the wire format (gRPC or HTTP) that SDKs and the Collector use to send data. This is the standardization point that lets any SDK talk to any OTel-compatible backend.

### The three signals OTel covers

- **Traces** — distributed traces of request flows, spans with parent-child relationships.
- **Metrics** — counters, gauges, histograms, same as Prometheus (and OTel metrics can be exported as Prometheus metrics).
- **Logs** — structured logs with OTel context attached.

OTel treats all three under one model, and they share attributes and correlation. A metric can be correlated with the traces that contributed to it; a log line can carry the trace ID from the current span automatically.

### The instrumentation story

OTel instrumentation comes in two flavors:

**Automatic instrumentation** — you install a library, configure it, and it patches common frameworks and clients at runtime. HTTP servers, HTTP clients, database clients, message brokers — all get spans and metrics without code changes.

```php
# Install the auto-instrumentation package
composer require open-telemetry/sdk open-telemetry/opentelemetry-auto-symfony

# Run with the extension
OTEL_PHP_AUTOLOAD_ENABLED=true php artisan serve
```

Symfony, Laravel, HTTP clients, Doctrine, Guzzle — many of the common PHP frameworks have auto-instrumentation that just works. The downside: auto-instrumentation's coverage varies by language. PHP's auto-instrumentation is less mature than Java's or Python's.

**Manual instrumentation** — you use the OTel API directly in your code to create spans and record metrics.

```php
use OpenTelemetry\API\Trace\TracerProviderInterface;

$tracer = $tracerProvider->getTracer('billing-service');

$span = $tracer->spanBuilder('process_payment')->startSpan();
try {
    $span->setAttribute('payment.method', 'credit_card');
    $span->setAttribute('payment.amount', $amount);

    $result = $this->paymentGateway->charge($amount);

    $span->setAttribute('payment.id', $result->id);
    $span->setStatus(StatusCode::STATUS_OK);
} catch (\Throwable $e) {
    $span->recordException($e);
    $span->setStatus(StatusCode::STATUS_ERROR, $e->getMessage());
    throw $e;
} finally {
    $span->end();
}
```

Manual instrumentation is more work but gives you precise control over what's instrumented and what attributes each span carries. In practice, teams use both: auto-instrumentation for coverage, manual instrumentation for the specific things that matter most.

### Context propagation — the part that's easy to forget

A distributed trace only works if trace context propagates across every boundary: HTTP requests, message broker publishes, database queries. Context propagation is the mechanism that carries the trace ID and the current span ID from the caller to the callee.

**For HTTP**, the standard is the W3C Trace Context specification (`traceparent` header):

```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
```

When an HTTP client starts an outgoing request from within an active span, it injects the `traceparent` header automatically (if instrumented). The receiving service extracts the header and links its new spans to the upstream trace.

**For message brokers**, the context goes in message headers. `traceparent` on the producer side, extracted on the consumer side.

**For databases**, the context can be embedded in SQL comments (`/* traceparent=... */`) so slow-query logs can be correlated with trace IDs.

Auto-instrumentation handles most of this. Manual instrumentation requires you to inject and extract context explicitly — which is error-prone but occasionally necessary.

### The Collector — the middle tier

The OTel Collector is a separate process that sits between your applications and your observability backends. You can run telemetry directly from the app to the backend (via the SDK's exporter) — but for anything serious, running a Collector is the recommended pattern.

**Why the Collector matters:**

- **Decoupling.** Your app only knows how to talk to the Collector. Changing backends (Jaeger → Tempo, Prometheus → Datadog) is a Collector config change, not an app change.
- **Batching.** The Collector aggregates telemetry and sends it in efficient batches to backends, reducing per-request overhead.
- **Processing.** Sampling, filtering, redaction, enrichment — all happen in the Collector pipeline before data hits the backend.
- **Reliability.** The Collector buffers data during backend outages, reducing data loss.
- **Multi-backend fan-out.** The same telemetry can go to multiple backends — e.g., send all traces to Tempo and send a sampled subset to Jaeger.

The Collector has three pipeline stages:

```
Receivers → Processors → Exporters
```

- **Receivers** — accept incoming telemetry. OTLP is the default, but there are receivers for Prometheus scraping, Jaeger, Zipkin, Fluentd, Kafka, and more.
- **Processors** — transform the data. Batching, sampling, attribute manipulation, resource detection, filtering.
- **Exporters** — send data to backends. OTLP, Prometheus, Jaeger, Tempo, vendor-specific exporters for Datadog/Honeycomb/New Relic/etc.

A typical config:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
  resourcedetection:
    detectors: [env, system, kubernetes]

exporters:
  otlp/tempo:
    endpoint: tempo:4317
    tls:
      insecure: true
  prometheus:
    endpoint: 0.0.0.0:8889

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resourcedetection, batch]
      exporters: [otlp/tempo]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, resourcedetection, batch]
      exporters: [prometheus]
```

This Collector receives OTLP telemetry, batches and enriches it, and exports traces to Tempo + metrics to Prometheus. All of this is configuration; no code changes.

### Deployment patterns for the Collector

- **Agent mode** — a Collector runs on every node (DaemonSet in Kubernetes). Applications send telemetry to their local agent, which forwards to a central backend. Low latency from app to Collector; offloads work from the app.
- **Gateway mode** — a pool of Collectors sits in the middle. Agents forward to the gateway; the gateway does heavy processing and sends to backends. Useful for complex pipelines, central policy enforcement, and shared sampling decisions.
- **Both** — agents for local buffering, gateways for central processing. The most scalable pattern for large deployments.

### Semantic conventions — the interoperability standard

OTel defines **semantic conventions**: standard attribute names and values for common things. `http.method`, `http.status_code`, `db.system`, `messaging.destination`, `service.name`, `service.version`, etc.

Following these conventions matters because:
- **Dashboards and alerts that work across services.** If every service uses `http.status_code`, a single dashboard can show the status breakdown across all of them.
- **Backend features light up.** Backends know the semantic conventions and provide special handling for them (e.g., auto-generating "HTTP" dashboards).
- **Tool interoperability.** Switching from one backend to another doesn't break your queries if the attributes are standardized.

Don't invent your own names when a semantic convention exists. The conventions are documented in the OTel spec and implemented by the SDKs' built-in instrumentations.

### Sampling — the cost control knob

Tracing every request is often too expensive. OTel supports sampling at two levels:

**Head sampling** — the decision is made when the span starts. The trace is either recorded or dropped at the beginning. Cheap but blind; you might drop an important trace because you made the sampling decision before you knew it was important.

**Tail sampling** — the decision is made after the entire trace is complete. You can sample based on outcomes: "keep all traces with errors, keep all traces slower than 1 second, sample 10% of the rest". Requires buffering complete traces, which is memory-intensive but gives you the important traces for free.

Tail sampling is implemented in the Collector, which buffers spans until a trace is complete (identified by a timeout), then decides which traces to export. This is the production pattern for non-trivial workloads.

### How OTel relates to other tools

- **OpenTelemetry → Prometheus.** OTel metrics can be exported in Prometheus format. Prometheus scrapes the Collector, not the app. You get OTel's semantic conventions with Prometheus's storage and query model.
- **OpenTelemetry → Jaeger / Tempo.** OTel's OTLP exporter sends traces to any OTLP-compatible backend. Both Jaeger (classic) and Tempo (modern, Grafana-integrated) accept OTLP.
- **OpenTelemetry → Datadog / Honeycomb / New Relic.** Vendor-specific exporters on the Collector. Instrument with OTel, export to whatever vendor you pay for.
- **OpenTelemetry → Logs.** OTel Logs is newer and less mature than traces and metrics, but it's catching up. For now, many teams stick with structured logging directly to a log aggregator.

### PHP specifically

PHP's OTel support is solid but younger than Java's or Go's. The standard libraries are under the `open-telemetry/*` Composer namespace. Things to know:

- **Context is request-scoped.** OTel's context propagation works per-request, which maps naturally to FPM's request lifecycle.
- **Long-running workers need explicit flushing.** When a Messenger worker shuts down, you need to flush pending telemetry before exiting. `$tracerProvider->shutdown()` in a shutdown handler.
- **Auto-instrumentation** exists for Symfony, Laravel, Guzzle, Doctrine, PDO, and more. Coverage is growing; always check what's available for your stack.
- **Manual spans** are the fallback when auto-instrumentation doesn't cover your code.
- **Performance overhead is real but manageable.** A few percent CPU on a typical service. Tune sampling for high-throughput paths.

### The interoperability story in one sentence

"Instrument once with OTel, export to any backend, switch backends by changing config." This is the pitch, and it's largely true. Vendor lock-in for observability used to be a significant cost; OTel made it a config choice.

> **Mid-level answer stops here.** A mid-level dev can describe the API and SDK. To sound senior, speak to the architectural patterns — Collector deployment, sampling strategy, semantic conventions, and the discipline of consistent instrumentation ↓
>
> **Senior signal:** treating OTel as a platform-level concern with shared conventions, shared Collector infrastructure, and a sampling strategy that's measured and tuned.

### The architectural patterns

- **Collector in front of every backend.** Apps talk to Collectors, Collectors talk to backends. Apps don't need to know the backend specifics.
- **Agent + gateway.** Local agents per node for performance and buffering, central gateway for shared processing and policy.
- **Tail sampling based on outcomes.** Keep errors, keep slow requests, sample the normal 10%. Done in the gateway.
- **Consistent resource attributes.** `service.name`, `service.version`, `deployment.environment`, `cloud.region`, `k8s.namespace`, `k8s.pod.name` — all attached automatically by the Collector via resource detection processors.
- **Dashboards and alerts based on semantic conventions.** Write once, applies to every service.

### Common mistakes

- **Sending telemetry directly to backends from the app.** Works for small deployments; doesn't scale. Run a Collector.
- **Not flushing telemetry on worker shutdown.** Pending spans are lost when workers exit.
- **100% sampling in production.** Expensive and usually unnecessary.
- **Inventing attribute names.** Use semantic conventions.
- **No resource attributes.** `service.name` should be on every signal. Without it, multi-service dashboards are impossible.
- **Treating traces and metrics as separate silos.** They're both OTel; use the same resource attributes and correlate them.
- **Logs without trace context.** Logs with trace IDs are much more useful than logs without.

### Closing

"So OpenTelemetry is the vendor-neutral framework for emitting and collecting traces, metrics, and logs. The API is what you write; the SDK collects; the Collector processes and forwards; OTLP is the wire protocol; semantic conventions are the interoperability standard. In production, apps send to a local Collector, Collectors forward to backends, sampling happens in the Collector pipeline, and the whole thing is vendor-agnostic by design. The killer feature is that instrumenting once gives you portability to any backend — which used to be impossible and is now the default."
