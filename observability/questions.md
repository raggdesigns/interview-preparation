# Observability questions

Notes and interview answers covering observability — the discipline of understanding a running system from the outside. Covers the three pillars (metrics, logs, traces), the stack of tools most teams use (Prometheus, Grafana, OpenTelemetry), and the higher-level concepts that turn raw telemetry into actionable operations (SLOs, golden signals, alerting strategy).

## Fundamentals

- [The three pillars: metrics, logs, traces](three_pillars_metrics_logs_traces.md)
- [The golden signals (latency, traffic, errors, saturation)](golden_signals.md)

## Logging

- [Structured logging](structured_logging.md)

## Metrics

- [Prometheus basics](prometheus_basics.md)
- [Grafana dashboards](grafana_dashboards.md)

## Tracing

- [OpenTelemetry basics](opentelemetry_basics.md)
- [Distributed tracing](distributed_tracing.md)

## SLOs and alerting

- [SLO / SLI / SLA](slo_sli_sla.md)
- [Alerting strategy (symptom vs cause, avoiding fatigue)](alerting_strategy.md)
