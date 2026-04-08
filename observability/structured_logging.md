# Structured logging

**Interview framing:**

"Structured logging is writing logs as JSON (or another machine-readable format) with named fields, instead of free-form strings. It sounds like a small thing and it's actually one of the highest-leverage changes a team can make to their observability. The reason: once logs have named fields, they're queryable. You can answer 'show me all failed login attempts for users in the EU region' with a one-line query instead of a grep pipeline, and you can build real dashboards and alerts from logs instead of treating them as a dumping ground. The senior insight is that structured logging isn't about the format — it's about treating logs as data, with the same schema discipline you'd apply to any other data source."

### The shape of the problem

Traditional log line:

```
[2026-04-09 14:23:11] ERROR: User 12345 failed to log in from 192.168.1.42
```

To find all failed logins by user 12345, you grep. To count them by hour, you grep and awk. To correlate with a deploy, you cross-reference by timestamp. Every query is a shell pipeline, and the pipelines break when someone changes the log format slightly.

Structured version:

```json
{
  "timestamp": "2026-04-09T14:23:11.482Z",
  "level": "error",
  "message": "Login failed",
  "user_id": "12345",
  "ip_address": "192.168.1.42",
  "service": "billing",
  "trace_id": "a3f2b1c4e5d6f7a8",
  "environment": "prod"
}
```

Now the log is a document with named fields. You can query by `user_id`, by `level`, by `service`, by `trace_id`. Every log aggregator on earth (Elasticsearch, Loki, Splunk, Datadog, CloudWatch Logs) indexes structured logs and lets you filter on any field.

### Why this matters

- **Queryable instead of grep-able.** Real queries, not shell pipelines.
- **Correlated with other pillars.** The `trace_id` field lets you jump from a log to the full trace.
- **Aggregatable.** Counting errors by service, computing rates, building dashboards — all trivial on structured fields.
- **Machine-parseable.** Alerts, dashboards, analysis tools can all read the logs reliably.
- **Schema discipline.** When logs have fields, you can enforce that certain fields are always present.

### The essentials of a structured log line

Every log line should include:

- **`timestamp`** — ISO 8601 with milliseconds and timezone (UTC).
- **`level`** — `debug`, `info`, `warn`, `error`, `fatal`. Standard, limited set.
- **`message`** — a human-readable summary. **Not** the place for dynamic values; those go in separate fields.
- **`service`** — which service produced the log.
- **`environment`** — `dev`, `staging`, `prod`.
- **`trace_id`** and **`span_id`** — for correlation with traces.
- **`request_id`** — the per-request correlation ID, propagated from the incoming request.

Then the log-specific fields — whatever's relevant to the event:

- User-facing operations: `user_id`, `account_id`.
- HTTP requests: `http.method`, `http.path`, `http.status_code`, `http.duration_ms`.
- Database operations: `db.statement`, `db.rows_affected`, `db.duration_ms`.
- Errors: `error.type`, `error.message`, `error.stack`.

### Message vs fields — the critical discipline

The single most common structured logging mistake is putting dynamic values into the message:

**Wrong:**
```json
{"level": "info", "message": "User 12345 bought 3 widgets for $45.99"}
```

**Right:**
```json
{
  "level": "info",
  "message": "Purchase completed",
  "user_id": "12345",
  "item_count": 3,
  "total_amount": 45.99,
  "currency": "USD"
}
```

Why this matters: the second form is queryable. "Show me all purchases by user 12345" is a one-field filter. In the first form, it's a regex against the message field, which loses all the benefits of structured logging.

The rule: **the message is a constant descriptor of the event; dynamic data goes in fields**. Message-based queries are free-text searches; field-based queries are structured queries.

### Log levels — use them with discipline

Five standard levels (some frameworks have more; these five are enough):

- **`debug`** — detailed information for developers. Off in production by default. The place for "entered function X", "computed intermediate value Y".
- **`info`** — significant events that are expected. Service started, user signed up, payment processed. The normal operational record.
- **`warn`** — unexpected but handled. A retry succeeded, a fallback was used, a deprecated API was called. Worth investigating but not paging.
- **`error`** — a genuine failure. An operation didn't succeed. Usually pairs with a user-visible problem.
- **`fatal`** — the process can't continue. Should be rare; usually logged right before the process exits.

**Common misuse:**
- Everything logged as `info` because people don't think about levels.
- `error` used for expected exceptions that are handled (overreacting to non-problems → alert fatigue).
- `debug` left on in production (verbose and expensive).
- `warn` used for things that are actually errors (silencing real problems).

The discipline that matters: **the level reflects the severity to the operator, not to the developer**. An expected exception that's fully handled is `debug` or `info`, not `error`. A backend service falling over is `error`. A deploy failing in a way that makes the service un-startable is `fatal`.

### Correlation — the trace ID is sacred

The single most useful field in any structured log is `trace_id`. With a trace ID propagated through every layer of the request, you can pivot from any log line to the full trace and from the trace to every other log line in the same request.

Propagation happens at every boundary:

- **Incoming HTTP request.** Middleware extracts the trace ID from headers (`traceparent`) or generates a new one. Stores it in a per-request context.
- **Outgoing HTTP request.** The client library injects the trace ID into the outgoing headers.
- **Database query.** The query includes the trace ID as a comment (optional but useful for slow-query correlation).
- **Message publish.** The trace ID is a header on the published message.
- **Message consume.** The consumer extracts the trace ID from headers and uses it for the duration of the message handling.
- **Every log call.** The logger automatically includes the current trace ID from the request context.

The automation matters: individual log calls shouldn't need to pass the trace ID manually. The logger should pull it from a framework-level context (request-scoped for web, message-scoped for workers). Trace ID propagation at the application level is boilerplate that every team writes once per stack.

### PSR-3 and Monolog in the PHP world

PHP's logging standard is PSR-3 (`Psr\Log\LoggerInterface`). Monolog is the de facto implementation. Both support structured logging natively — the second argument to log methods is a context array:

```php
$this->logger->info('Purchase completed', [
    'user_id' => $user->getId(),
    'item_count' => count($items),
    'total_amount' => $total,
    'currency' => 'USD',
]);
```

With a JSON formatter, this produces proper structured output:

```php
use Monolog\Logger;
use Monolog\Handler\StreamHandler;
use Monolog\Formatter\JsonFormatter;

$logger = new Logger('billing');
$handler = new StreamHandler('php://stderr', Logger::INFO);
$handler->setFormatter(new JsonFormatter());
$logger->pushHandler($handler);
```

In Symfony, the `monolog` bundle handles this via config — you set the handler type to `stream` and the formatter to `json`, and you get structured logs for free.

### Log to stdout, always (in containers)

The twelve-factor principle [twelve_factor_app.md](../devops/twelve_factor_app.md) says logs go to stdout as an event stream. In containers, this is not a suggestion — it's how the platform picks up logs.

- **Kubernetes** captures stdout/stderr from containers and makes them available via `kubectl logs` and whatever log aggregator you've wired up.
- **Docker** does the same with `docker logs`.
- **Heroku, Fly.io, Railway, Render** — all capture stdout.

Writing to a log file inside a container creates three problems:
1. The platform doesn't pick it up.
2. The file grows without bound (no rotation).
3. Logs are lost when the container restarts.

Solution: write JSON to stdout. Done.

### Sensitive data in logs — the OWASP trap

Logs are a data store. Sensitive data in logs is a data leak waiting to happen.

**What not to log:**
- Passwords (obviously)
- Credit card numbers, CVVs
- Session tokens, API keys, refresh tokens
- Full request bodies when they might contain any of the above
- PII beyond what's legally required (and what's legally required is usually less than you think)
- Authentication headers

**What to do instead:**
- **Scrub sensitive fields at the logger level.** Define a list of field names that should be redacted and enforce it in middleware.
- **Log IDs, not values.** `user_id=12345` is fine; `email=user@example.com` may not be.
- **Redact at the edges.** Incoming HTTP request logs should strip `Authorization`, `Cookie`, etc.
- **Tests.** Write tests that assert sensitive values don't appear in log output.

GDPR, HIPAA, PCI — every compliance regime has rules about what belongs in logs. Know your rules; scrub accordingly; audit your logs for accidental leakage.

### Log sampling at high volume

Logs are the most expensive observability pillar by volume. For a high-throughput service, you may need to sample — log only a fraction of events of a given type.

- **Error logs: 100%.** Never sample errors. They're rare and critical.
- **Warn logs: 100%.** Same reasoning.
- **Info logs: 100% for most services.** Sample only if volume is a real problem.
- **Debug logs: 0% in production.** If debug volume is a problem, the real fix is turning debug off.
- **High-volume repetitive info logs** (e.g. "request served" on a busy API): consider sampling at 1-10%. Combine with metrics for the count, so the sample only needs to give you examples, not counts.

Sampling decisions should be per log event type, not global. "Don't log 99% of my info messages" is the wrong sampling strategy; "don't log 99% of my per-request noise, but log 100% of business events" is the right one.

### Log retention

How long to keep logs is a cost/value trade-off:

- **Hot (queryable):** 7-30 days for most services. This is where incident investigation happens.
- **Warm (archived, queryable with delay):** 30-90 days. Post-incident analysis, compliance lookups.
- **Cold (archived, rare access):** 1+ year for compliance-mandated retention.

Different data retention for different log levels and types makes sense. Audit logs may need 7 years; application debug logs don't need to be kept past the week.

### Log aggregation — the tools

- **Elasticsearch + Kibana (ELK)** — the classic. Powerful, expensive, complex to operate.
- **Loki + Grafana** — cheaper, indexes labels only (not full text), designed for high volume.
- **Datadog Logs, Splunk, CloudWatch Logs, Papertrail, Better Stack** — managed, varying price and feature sets.
- **OpenSearch** — Elasticsearch fork, same model.
- **Vector, Fluent Bit, Fluentd, Filebeat** — log shippers that ingest from containers and forward to aggregators.

The right choice depends on volume, budget, and integration with the rest of your stack. Loki is the natural pair with Grafana if you're already using Prometheus + Grafana for metrics.

> **Mid-level answer stops here.** A mid-level dev can describe JSON logging. To sound senior, speak to the schema discipline, cost model, and operational concerns that separate useful logging from noise ↓
>
> **Senior signal:** treating logs as a queryable data source with schema, cardinality, and cost concerns — not a dumping ground.

### The discipline

- **Schema matters.** Define the required fields for your logs and enforce them in middleware. A log without `trace_id` or `service` is a log you can't use.
- **Fields are the query surface.** Query on `user_id`, not on `message`. Message is prose; fields are data.
- **Cardinality matters here too.** Logging 10 million distinct `user_id` values is fine. Logging 10 million distinct `random_value` fields with no query purpose is expensive waste.
- **Levels are for operators.** `error` means "wake me up"; `warn` means "look when you have time"; `info` means "remember this happened"; `debug` means "only in dev".
- **PII scrubbing is not optional.** Build it once, at the logger level, and trust it.
- **Budget your log bill.** Most teams don't, and most teams' log bills are shocking.
- **Prefer metrics for counting.** If you find yourself writing a log line per request just to count them, you want a metric instead.

### Common mistakes

- **Free-form log messages with interpolated values.** "User {id} did {thing}" is ungreppable.
- **Everything at `info` level.** Level distinctions collapse; alerting on level becomes impossible.
- **Debug logs on in production.** Expensive and unnecessary.
- **No trace ID.** Can't correlate logs with traces or other logs from the same request.
- **Sensitive data in logs.** One PCI incident later, everyone wishes they'd scrubbed.
- **Logs as the primary metric source.** Counting logs is slow and expensive; use real metrics.
- **No log volume monitoring.** Nobody notices until the bill arrives.
- **Inconsistent field names across services.** `user_id` in one service, `userId` in another, `userID` in a third. Queries can't join.

### Closing

"So structured logging is writing logs as JSON documents with named fields, correlated via trace IDs, shipped to stdout, ingested by an aggregator, queried as data. The discipline is: message is a constant, fields are dynamic data; levels reflect operator severity; sensitive fields are scrubbed; high-volume events are metrics, not logs. A team that gets this right has an observability story that scales; a team that doesn't has a shell-pipeline debugging practice and a surprise bill every quarter."
