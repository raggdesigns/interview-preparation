# SLO / SLI / SLA

**Interview framing:**

"The SRE trinity — SLI, SLO, SLA — is the framework for defining what 'reliable' means for a service in a way that's measurable, operationally useful, and connected to business reality. The short version: SLI is what you measure, SLO is the target you set internally, SLA is the contractual promise. The framework matters because without it, 'reliable' is a vibe, and you end up alerting on internal cause metrics that don't match user experience. With it, you have error budgets, burn-rate alerts, and a real conversation about the trade-off between reliability investment and feature velocity."

### The three acronyms

- **SLI — Service Level Indicator.** A metric that measures user-visible service quality. "Percentage of requests that succeed" or "percentage of requests served in under 300ms".
- **SLO — Service Level Objective.** A target for an SLI, over a time window. "99.9% of requests succeed, measured over 30 days". Set internally.
- **SLA — Service Level Agreement.** A contractual promise, usually with financial consequences for violations. "99% uptime or credits apply". Set externally, with customers.

The relationship: SLA ≤ SLO ≤ actual performance. The SLO is stricter than the SLA (so you have room to maneuver before a contractual breach), and actual performance is higher than the SLO (so you have error budget to spend on change and risk).

### Why you need SLIs before SLOs

"We should be 99.9% reliable" is meaningless until you answer: reliable according to what?

An SLI is a specific, measurable definition. Good SLIs have two properties:

1. **User-visible.** The metric measures something users actually experience — success rate, latency, availability — not an internal implementation detail like CPU or memory.
2. **A ratio of good events to total events.** Rather than "count of errors", it's "errors / total requests". Ratios are directly interpretable as a percentage.

Typical SLIs for a web service:

- **Availability SLI:** (successful requests) / (total requests). "99.9% of requests succeed."
- **Latency SLI:** (requests served in under 300ms) / (total requests). "95% of requests are fast."
- **Freshness SLI:** (data queries returning data ≤ 1 min old) / (total data queries). Applies to data pipelines.
- **Correctness SLI:** (correct responses) / (total responses). Requires ground truth; hard to measure but sometimes the most important SLI.

The design work is picking the right SLI for each service. Getting this wrong leads to nonsense SLOs that don't correlate with user experience.

### The SLO — the target

Once you have an SLI, the SLO is a target for it over a time window:

- **"99.9% availability over a rolling 30 days"** — 0.1% of requests can fail per month.
- **"95% of requests under 300ms over 7 days"** — 5% of requests can be slow.
- **"99.5% of data freshness over 24 hours"** — 0.5% of queries can return stale data.

The time window matters. A 99.9% SLO over 30 days allows different failure patterns than 99.9% over 1 hour. Longer windows smooth out brief incidents; shorter windows are stricter about recent behavior.

**The critical SLO design decision:** what's the right target? The answer depends on:

- **User expectations.** What does the user experience as unacceptable? For a back-office tool, 99% might be fine. For a payment API, 99.95% might not be enough.
- **Technical reality.** If your service is running at 99.2% and nobody's complaining, setting an SLO of 99.99% is setting yourself up for failure.
- **Cost vs benefit.** Each additional nine (99.9% → 99.99%) typically requires 10x the investment. Spend where it matters.

**Don't aim for 100%.** A 100% SLO means zero error budget, which means zero room for change. Every deploy, every experiment, every risk becomes a potential SLO violation. Reliability is expensive at the top end; the right target is "high enough that users don't notice, not so high that you can't ship".

### Error budget — the concept that makes SLOs operational

If your SLO is 99.9%, your error budget is the remaining 0.1%. Over 30 days, that's about 43 minutes of downtime, or 0.1% of requests, or whatever fraction of the SLI.

The error budget is the **amount of unreliability you can afford**. It's a currency you spend on:

- **Deploys** (deploys can break things).
- **Risky changes** (refactoring, new infrastructure, experiments).
- **Incidents** (unplanned outages).
- **Planned maintenance**.

The policy attached to the error budget is the lever:

- **Budget remaining → move fast.** Ship features, take risks, run experiments.
- **Budget exhausted → slow down.** Freeze risky changes, focus on reliability work, investigate what consumed the budget.

This is the single most important SRE idea in practice. It turns "reliability vs velocity" from an argument into a measurable trade-off.

### SLA — the contract

SLAs are for customers. They have:

- **A specific SLI and threshold.** "99% uptime over a calendar month, measured as successful API requests."
- **Consequences for violations.** Service credits, refunds, escalation rights.
- **Measurement methodology.** How exactly is "uptime" computed? Who measures it? What counts as an incident?

Key rule: **your internal SLO should be stricter than your SLA**. If you promise customers 99% (SLA), set your internal target at 99.5% or 99.9% (SLO). When you violate the SLO, you notice and respond before it becomes an SLA violation with financial consequences.

Not every service has an SLA. Most internal services don't. But every service should have SLOs.

### Burn rate — how fast you're consuming error budget

If you have a 30-day error budget of 0.1%, burning through it linearly means spending 0.1%/30 days ≈ 0.0033% per day. That's the "normal" burn rate — exactly on track.

When the error rate goes up, you burn budget faster:

- **Burn rate 1x** — on track to use the full budget over the window.
- **Burn rate 10x** — using budget 10 times faster than sustainable. At this rate, you'll exhaust it in 3 days instead of 30.
- **Burn rate 100x** — on track to burn the full budget in a few hours.

Burn-rate alerting is the modern SRE pattern. Instead of "alert if error rate > 1%", you alert on **burn rate** over different time windows:

- **Fast burn:** burn rate > 14.4 over 1 hour = budget consumed in ≤ 2 days → page immediately.
- **Slow burn:** burn rate > 6 over 6 hours = budget consumed in ≤ 5 days → page but less urgently.
- **Very slow burn:** burn rate > 1 over 3 days → ticket, not page.

This is smarter than threshold alerts because:

- **It measures impact.** A 0.5% error rate on a 99% SLO is fine; on a 99.99% SLO it's catastrophic. Burn rate captures this automatically.
- **It accounts for duration.** A brief spike burns a small chunk; a sustained spike burns a lot. Burn rate reflects both.
- **Fewer false alarms.** A brief blip doesn't page unless it's bad enough to be a real problem at this SLO.

The Google SRE Workbook has the canonical burn-rate alerting table and PromQL patterns for implementing it.

### Picking SLO targets — the practical process

1. **Start with what you're already doing.** Measure the current state of your chosen SLI. If you're at 99.5%, don't set an SLO of 99.99%.
2. **Factor in customer expectations.** If customers tolerate the current state, the SLO can match it. If they don't, aim higher.
3. **Round down to a reasonable target.** 99.5%, 99.9%, 99.95%. Arbitrary precision makes the target feel fake.
4. **Define the time window.** 28 or 30 days is standard. 7 days for volatile services or during early development.
5. **Document the SLI definition precisely.** What counts as "success"? What requests are in scope? (Internal health checks usually aren't.)
6. **Get buy-in from the product team.** The error budget policy affects their roadmap. They need to agree that reliability work supersedes feature work when the budget is exhausted.
7. **Start loose and tighten.** It's better to meet a 99% SLO and consider raising it than to set 99.99% and fail constantly.

### Common SLI designs

#### HTTP availability

```text
SLI = (requests with HTTP status 2xx or 3xx)
    / (total requests)
```

Usually scoped to user-initiated requests; health checks and internal calls excluded.

```promql
sum(rate(http_requests_total{status=~"2..|3..",user_facing="true"}[30d]))
/
sum(rate(http_requests_total{user_facing="true"}[30d]))
```

#### HTTP latency

```text
SLI = (requests with latency ≤ 300ms)
    / (total requests)
```

```promql
sum(rate(http_request_duration_seconds_bucket{le="0.3"}[30d]))
/
sum(rate(http_request_duration_seconds_count[30d]))
```

#### Message processing

```text
SLI = (messages processed successfully)
    / (total messages received)
```

For queue-based workloads.

#### Data freshness

```text
SLI = (data queries where data.age ≤ 60 seconds)
    / (total data queries)
```

For ETL pipelines and derived-data views.

### The difference between an SLO and a KPI

SLOs measure reliability. KPIs measure business outcomes. They're related — unreliable services hurt business metrics — but they're not the same thing.

"95% customer satisfaction" is a KPI, not an SLO. "95% of API requests complete in under 300ms" is an SLO. One is about the business goal; the other is about the technical target that supports it. You need both, and confusing them leads to fuzzy, hard-to-operate targets.

### SLOs and error budget policies in practice

The **error budget policy** is the written agreement about what happens when the budget is in different states:

- **Budget healthy (50%+ remaining):** ship normally. Experiments are fine. Deploys go every day.
- **Budget running low (20% remaining):** heightened review. New deploys require more testing. Experiments paused.
- **Budget exhausted (0% or negative):** freeze non-critical changes. On-call prioritizes reliability work. Incident retrospectives get real attention.
- **SLA approaching:** customer communication, escalation.

Without this policy, error budgets are just numbers. With it, they shape day-to-day engineering decisions.

### The SRE maturity ladder

Teams evolve through stages:

1. **No SLOs.** "We deploy when we deploy; reliability is a vibe." Common starting point.
2. **Threshold alerts without SLOs.** Alerts exist but fire on symptoms or internal causes. Alert fatigue is high.
3. **SLOs defined but not enforced.** Targets exist on a wiki page but nobody looks at them.
4. **SLO-based dashboards.** Teams track their own SLO performance. Decisions start being informed by burn rate.
5. **Error budget policies enforced.** Budget-exhausted means freeze. Budget-healthy means ship.
6. **SLOs drive architecture.** New features are designed to fit within the error budget. Reliability investment is planned around SLO trends.

Most teams are at stage 2 or 3. Reaching stage 4 is a significant improvement; stage 5 is rare and usually requires cultural buy-in from engineering leadership.

> **Mid-level answer stops here.** A mid-level dev can define the acronyms. To sound senior, speak to the operational patterns — burn-rate alerting, error budget policies, and the conversation the framework enables ↓
>
> **Senior signal:** using SLOs as the primary lever for the reliability-vs-velocity trade-off, not as a passive metric.

### The conversation SLOs enable

Before SLOs, reliability conversations go: "we need better reliability" → "how much better?" → "a lot better" → "how much time should we spend?" → "how much do we need?" → loop forever.

After SLOs, the conversation goes: "our 99.9% SLO is at 99.7% this month and we've exhausted our error budget" → "we need to pause feature work and address the top contributors to the budget burn" → "here are the top three causes; these two are architectural and need dedicated work, this one is a deploy hygiene issue" → "prioritize and execute".

The framework turns reliability into a tractable engineering problem with clear levers and clear trade-offs. That's the whole point.

### Common mistakes

- **SLOs based on internal metrics.** "CPU < 80%" is not an SLO. SLOs measure user experience.
- **SLOs without error budgets.** Targets that don't drive behavior are decorations.
- **100% SLOs.** No budget means no room to ship. Aim lower.
- **SLOs that ignore traffic.** An SLO on a service nobody uses is meaningless; an SLO on a high-traffic service is load-bearing.
- **One SLO for everything.** Different services have different reliability needs. Each critical service should have its own SLO.
- **Threshold alerts instead of burn rate.** Noisier, less accurate, harder to tune.
- **SLAs stricter than SLOs.** You'll violate contracts before you notice there's a problem.
- **No error budget policy.** The budget concept exists but has no teeth.
- **Recomputing SLOs on every deploy.** Pick a rolling window (usually 28-30 days) and stick with it.

### Closing

"So SLI is what you measure, SLO is the internal target, SLA is the customer contract. The error budget is what makes the framework operational: it's the currency you spend on change and risk, and the policy you attach to it determines how the team behaves when the budget is healthy, running low, or exhausted. Burn-rate alerting is the modern pattern — alert on how fast you're consuming budget, not on arbitrary thresholds. Done right, SLOs turn 'reliability vs velocity' from an argument into a measurable trade-off, and that's the senior insight: the framework is a tool for making better decisions, not a metric to report up the chain."
