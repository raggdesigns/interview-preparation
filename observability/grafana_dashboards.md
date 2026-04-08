# Grafana dashboards

**Interview framing:**

"Grafana is the visualization layer that sits on top of everything else — Prometheus, Loki, Tempo, Elasticsearch, Postgres, CloudWatch, whatever data source you have. It's the open-source de facto standard for dashboards, and it's become the default UI for operators looking at metrics, logs, and traces. The interesting thing about Grafana for interviews isn't the UI — it's the dashboard design discipline, because a dashboard nobody looks at is worse than no dashboard at all. The senior move is designing dashboards that answer specific questions, not dashboards that show everything."

### What Grafana is (and isn't)

Grafana is a **read-only visualization layer**. It doesn't collect metrics or store them. It queries data sources (Prometheus, Loki, InfluxDB, Elasticsearch, Postgres, MySQL, cloud APIs, and many more) and renders panels.

This separation is important: if you use Grafana, you also need a metrics backend. Grafana + Prometheus is the canonical open-source pair. Grafana + Datadog is unusual but possible. Grafana with three or four backends simultaneously is common and supported — you can build a dashboard that pulls metrics from Prometheus, logs from Loki, and traces from Tempo.

### The anatomy of a dashboard

- **Dashboard** — the top-level object. A page of panels displaying data.
- **Panel** — a single visualization (graph, table, single stat, heatmap, etc.). Each panel has its own query.
- **Row** — a horizontal grouping of panels.
- **Variable** — a template variable that can be changed at the top of the dashboard (e.g., `$service`, `$environment`). Queries reference variables so one dashboard can cover multiple services.
- **Time range selector** — the top-right control that sets the time window. Every panel respects it.

### Panel types — the ones you actually use

- **Time series / graph** — the default for metrics over time. Line charts.
- **Stat** — a single number with optional threshold coloring. "Current error rate: 0.3%".
- **Gauge** — a fancier stat, showing progress toward a target.
- **Bar gauge** — multiple stats as horizontal or vertical bars.
- **Table** — rows and columns. Useful for listing services, hosts, or top-N queries.
- **Heatmap** — density of observations over time. Useful for latency distributions.
- **Logs panel** — stream logs from Loki or Elasticsearch. Click to open the full log view.
- **State timeline** — status over time (up/down, healthy/degraded).
- **Pie chart, bar chart, histogram** — occasionally useful, often abused.

The temptation is to try every panel type. The right answer is to use the simplest panel that answers the question. Time series for trends, stat for current values, table for lists, heatmap for distributions. Everything else is usually decoration.

### Dashboard design principles

#### 1. Every dashboard answers a specific question

- "Is my service healthy right now?" — a service overview dashboard.
- "What broke during that deploy?" — a deploy investigation dashboard.
- "Where is traffic coming from?" — a traffic breakdown dashboard.
- "What's my SLO status?" — an SLO dashboard.

A dashboard without a clear question is a dashboard nobody will use. "General metrics" is not a question.

#### 2. The most important info is on top

The top row of the dashboard is the most valuable real estate. Put the metrics that answer the "is it healthy?" question there. For a service overview:

- **Top row:** the four golden signals — latency (p50, p95, p99), traffic, error rate, saturation.
- **Middle rows:** detail views for each signal, broken down by dimensions (per-endpoint, per-status, per-region).
- **Bottom rows:** dependencies, infrastructure metrics, less critical details.

An on-call engineer should get their answer without scrolling.

#### 3. Consistent scales across similar panels

If you have three panels showing "request rate" for three different services, use the same Y-axis scale. Otherwise the eye compares shapes and reaches the wrong conclusions.

Grafana supports shared cursor and tooltip (hovering on one panel shows the same moment across all panels) — turn this on. It makes multi-panel correlation much easier.

#### 4. Use variables for reusable dashboards

Instead of one dashboard per service, one dashboard with a `$service` variable that can be switched at the top:

```
[Service: billing ▼] [Environment: production ▼] [Time range: last 1h ▼]
```

All panels use `$service` and `$environment` in their queries. The dashboard template covers every service; engineers just pick the one they care about.

```promql
sum by (status) (rate(http_requests_total{service="$service", env="$environment"}[5m]))
```

Variables can be chained: `$environment` determines which `$service` options are available.

#### 5. Annotations for events

Grafana annotations mark events on the time axis — deploys, incidents, config changes. When you see a metric change at 14:23, and there's an annotation "Deploy v1.4.2 at 14:23", the correlation is immediate.

Annotation sources:
- **Grafana API** — your deploy pipeline calls Grafana's API to add a deploy annotation.
- **Prometheus** — query-based annotations (e.g., "mark moments when the error rate crossed 1%").
- **Loki / Elasticsearch** — annotations from log events.

Deploy annotations are the highest-leverage kind. Every dashboard should show them.

#### 6. Link panels to drill-down dashboards

Clicking a panel should take you deeper. "Click the error count panel to open the error details dashboard for this service, filtered to this time range." Grafana's data links feature makes this trivial and it transforms dashboards from static reports into a navigation layer.

### The "RED/USE dashboard" template

The canonical service dashboard, based on the golden signals + USE framework:

```
┌──────────────────────────────────────────────────────┐
│ [Service ▼] [Env ▼] [Time ▼]                         │
├──────────────────────────────────────────────────────┤
│ Requests/sec  │ Error rate  │ p50/p95/p99 latency   │
│     [stat]    │   [stat]    │      [graph]          │
├──────────────────────────────────────────────────────┤
│ Request rate by endpoint        │ Error rate by code │
│          [graph]                │     [graph]        │
├──────────────────────────────────────────────────────┤
│ Latency heatmap                 │ Error breakdown    │
│          [heatmap]              │     [table]        │
├──────────────────────────────────────────────────────┤
│ CPU / Memory / GC / Pool usage (saturation)         │
│                     [graph]                          │
├──────────────────────────────────────────────────────┤
│ Recent deploys (annotations) │ Recent errors (logs)  │
└──────────────────────────────────────────────────────┘
```

Same layout for every service. Engineers read it instantly because they've seen the layout a hundred times.

### Dashboard-as-code

Grafana dashboards are JSON. You can (and should) check them into git and deploy them through CI, rather than clicking in the UI and hoping the changes survive.

Options:
- **Grafana API + raw JSON.** The simplest: export dashboards as JSON, commit them, apply via the API.
- **Terraform + Grafana provider.** Declarative management of dashboards, alerts, data sources, folders.
- **Grizzly** — dashboard-as-code with a nicer DSL than raw JSON.
- **Jsonnet + grafonnet-lib** — programmatic dashboard generation. Great for generating many similar dashboards from a template.
- **Grafana Operator (Kubernetes)** — manage dashboards as Kubernetes CRDs.

Dashboards should be reviewable, versioned, and deployed consistently across environments. Clicking in the UI produces drift; UI changes get lost when dashboards are reprovisioned; one engineer's "temporary test panel" becomes permanent technical debt. Dashboard-as-code fixes all of this.

### Alerting in Grafana vs Prometheus

Grafana has its own alerting system (Grafana Managed Alerts, as of v8+), which can alert on any data source. This is tempting — you see a panel, you make an alert from it.

But: **alerts from Prometheus via Alertmanager are usually better** because:
- The alert lives next to the metric rule, not in a dashboard tool.
- Alert evaluation is done by Prometheus, which is scaled for it.
- Alertmanager has richer routing, deduplication, and inhibition.
- Grafana alerts depend on Grafana being up; Prometheus + Alertmanager is independent.

Use Grafana alerts only for multi-source conditions (e.g., "metric X from Prometheus AND log pattern Y from Loki"). For everything else, alerts belong in Prometheus.

### Data source federation

One Grafana instance can query many data sources. A single dashboard can have panels from Prometheus, Loki, Tempo, Elasticsearch, Postgres, and CloudWatch simultaneously. Cross-source queries are supported (with some limitations).

The killer integration is **metrics → traces → logs**:

1. Click a metric spike on a Grafana panel (Prometheus).
2. Click through to the Tempo trace view for that time window (Tempo).
3. From a trace span, click through to the logs emitted during that span (Loki).

This is called "Explore" mode in Grafana, and when it's set up correctly, it collapses the three pillars into one navigation experience. You don't hop between tools; you pivot within Grafana.

### Home dashboards and folders

Organize dashboards into **folders** by team, domain, or environment. Each team has its folder, each service has its sub-folder, each folder has a "home" dashboard that's the landing page.

The **home dashboard** for a service should be the overview with the golden signals. Drilling into sub-dashboards handles the detail. This hierarchy makes finding the right dashboard fast — engineers don't need to search; they navigate.

### Dashboards that age well

Some things make dashboards durable; others guarantee they'll rot:

**Durable:**
- Using template variables so the dashboard works for new services automatically.
- Querying metrics by standard naming conventions (so a new service that follows the convention shows up without changes).
- Annotating deploys automatically from CI.
- Keeping panels focused and few in number.

**Rot-prone:**
- Hard-coded service names.
- Dashboards with 40 panels that nobody can read.
- Panels created for a one-off investigation and never removed.
- Queries that were slow and hard to optimize, so nobody touches them.
- UI-only changes with no backing commit history.

### Common mistakes

- **Too many panels.** A screen full of 30 panels is worse than 5 focused panels. Prune ruthlessly.
- **No "what question does this answer" for the dashboard.** Leads to general-purpose dashboards nobody uses.
- **Inconsistent scales.** Comparing panels with different Y-axes confuses the eye.
- **Alerts defined in Grafana when they could live in Prometheus.** Grafana becomes a dependency for alerting.
- **UI-only dashboard editing.** Drift, loss, and no review history.
- **No template variables.** One dashboard per service is unmaintainable.
- **No annotations for deploys.** Half of incident investigation is "what changed?".
- **Panels showing averages instead of percentiles for latency.** Always percentiles.

> **Mid-level answer stops here.** A mid-level dev can build panels. To sound senior, speak to dashboard design discipline, dashboard-as-code, and how dashboards fit into incident response ↓
>
> **Senior signal:** treating dashboards as UI for operators with their own design, ownership, and maintenance discipline.

### Dashboards in incident response

A good dashboard isn't just for passive monitoring — it's the first tool in an incident investigation:

1. **Alert fires** → go to the service overview dashboard.
2. **Look at golden signals.** Which signal triggered? How bad?
3. **Check the deploy annotation.** Anything deployed recently? Does the spike align with the deploy?
4. **Drill into the affected panel.** Break down by dimension — which endpoint? Which status? Which region?
5. **Pivot to traces** for a slow/failing example.
6. **Pivot to logs** for the trace's error details.

The dashboard is the starting point and the hub. It's not the answer to every question, but it's the fastest way to ask the next question.

### Closing

"So Grafana is a data-source-agnostic visualization layer, and the real craft is in dashboard design: every dashboard answers a specific question, the golden signals go on top, panels are consistent and few, variables make dashboards reusable, annotations mark deploys and events, and dashboards-as-code is the only way they stay maintainable over time. Pair it with Prometheus for metrics, Loki for logs, Tempo for traces, and you've got a unified navigation experience across all three pillars. The panels are the easy part; the discipline is what makes the difference between dashboards engineers actually use and dashboards that collect dust."
