# Alerting strategy

**Interview framing:**

"Alerting is the part of observability where the discipline matters most, because the cost of getting it wrong is human: bad alerting leads to alert fatigue, burnt-out on-call engineers, and the slow erosion of trust in the monitoring system. The two rules that cover 80% of the discipline are: alert on symptoms, not causes, and every page must be actionable. The rest is tuning. Most teams have too many alerts, most of them fire too often, and most of them don't mean what the person receiving them thinks they mean. The senior insight is that alert strategy is about *what you wake someone up for* — and the bar for that should be much higher than most teams set."

### The core principles

#### 1. Alert on symptoms, not causes

A **symptom** is user-visible: high error rate, high latency, service unavailable.
A **cause** is internal: high CPU, high memory, disk usage, queue depth.

Alert on symptoms. Investigate using causes.

Why: causes can be transient and self-correcting. CPU at 90% for a minute doesn't matter if nobody noticed. Memory at 85% is often normal. A restart loop is bad — but only if it's affecting users.

Symptom alerts fire when users are actually affected. Cause alerts fire when a condition exists that *might* affect users. The first is actionable; the second is noise.

**The counter-example:** leading indicators. If you know a specific cause will reliably turn into a symptom before you have time to react, alerting on the cause makes sense. "Disk will be full in 1 hour at current growth" is a reasonable cause-based alert because by the time disk is 100% full, users are already affected and fixing it takes longer than 1 hour. But this is the exception, not the rule.

#### 2. Every alert must be actionable

If the on-call engineer receives an alert and has no specific action to take, the alert is a bug. Options:

- **Turn it off.** If nothing needs to be done, the alert shouldn't exist.
- **Tune the threshold.** If the alert fires for conditions that are fine, the threshold is wrong.
- **Add a runbook.** If the alert fires for a real problem but the action isn't clear, write down what to do.
- **Automate the fix.** If the action is always the same, make the system take it automatically.

The question "what should I do when this fires?" should have a clear answer before the alert exists.

#### 3. Alerts should match the urgency of the page

- **Page (wake someone up):** user-visible symptom, severe enough to warrant immediate action, cannot wait until morning.
- **Ticket or Slack message:** something to investigate during business hours. Less urgent, not user-impacting.
- **Dashboard or log:** informational. Nobody is notified; engineers notice during normal work.

Most "alerts" should not be pages. A team with 50 pages per week has a broken alerting strategy. A team with 5 pages per week is doing well.

### Alert routing — the role of Alertmanager (or equivalent)

Prometheus Alertmanager (or the equivalent in your observability stack) handles:

- **Grouping.** Related alerts are batched into one notification. Five pods in the same deployment failing at the same time is one page, not five.
- **Deduplication.** HA Prometheus pairs send duplicate alerts; Alertmanager sends one notification.
- **Silencing.** Planned maintenance, known issues, or active incidents suppress noise.
- **Inhibition.** A "service down" alert inhibits "high error rate" alerts on the same service, because the error rate is a symptom of the downtime, not a separate issue.
- **Routing.** Different alerts go to different channels based on labels — critical to PagerDuty, warnings to Slack, info to an email digest.

This separation — evaluation in Prometheus, routing in Alertmanager — lets you tune the routing policy without touching metric rules.

### Burn-rate alerts — the modern pattern

For services with SLOs, the modern alerting pattern is **burn-rate alerts** on the SLO error budget, not threshold alerts on raw metrics.

A burn rate measures how fast you're consuming your error budget. If your budget is sustainable at 1x burn, a 10x burn rate means you're consuming budget ten times faster than planned.

The Google SRE Workbook's canonical multi-window multi-burn-rate pattern:

- **Fast burn** (short window, high threshold): 14.4x burn rate over 1h and 14.4x over 5m → PAGE. Budget would be exhausted in ≤ 2 days.
- **Slow burn** (longer window, lower threshold): 6x burn rate over 6h and 6x over 30m → PAGE. Budget would be exhausted in ≤ 5 days.
- **Very slow burn** (very long window, very low threshold): 3x burn rate over 24h and 3x over 2h → TICKET. Budget would be exhausted in ≤ 10 days.

Requiring both a long window and a short window prevents noise: a brief spike doesn't fire because the long window is still fine; a sustained problem fires because both windows cross the threshold.

Why this is better than threshold alerts:
- **It's calibrated to user impact.** The alert fires when you're actually on track to violate the SLO.
- **Fewer false alarms.** Brief blips don't page.
- **Consistent across services with different SLOs.** The same burn-rate logic works for a 99% and a 99.99% service.

### Symptom alerts — what to actually alert on

For most web services, these are the five or six alerts that actually matter:

1. **Error budget burn rate (fast)** — user-visible errors exceeding sustainable rate.
2. **Error budget burn rate (slow)** — sustained elevated errors.
3. **Latency SLO burn rate** — latency SLO being consumed too fast.
4. **Service down / no traffic** — no successful requests received in N minutes. Catches total outages.
5. **Data pipeline freshness** (if applicable) — data older than SLO threshold.
6. **Business-metric anomaly** (if you have the observability for it) — purchase count dropped 80% in 5 minutes.

That's it. Not thirty alerts. Maybe a few more for unique edge cases, but the bulk of the alerting load should be covered by this small set.

Everything else is investigation material: CPU, memory, queue depth, pod restarts, disk usage, external service latencies. These appear on dashboards for debugging, not in the paging pipeline.

### The "alert on known-unknowns" trap

Teams often accumulate alerts by reacting to incidents: "we had an outage because of X, let's add an alert for X". Repeated over time, this produces a long list of specific alerts that covered past incidents but don't catch new ones.

The problem: alerts defined this way focus on **causes** (what went wrong last time), not symptoms (what users experienced). They also grow without bound — you add alerts faster than you retire them, and eventually the on-call load is unsustainable.

The right move: **after an incident, ask whether a symptom alert would have caught it**. If yes, improve the symptom alert's coverage. If no, it's probably a niche cause that doesn't justify a new alert — write a runbook entry instead.

### The "on-call load" metric

A team's alerting strategy should be continuously measured against on-call load:

- **Pages per on-call shift.** How many times does the on-call engineer get woken up?
- **Time to acknowledge.** If it's high, the alerts may not be urgent enough to actually page.
- **Time to resolve.** If it's low, maybe the alert fires for transient self-healing conditions.
- **Actionability.** What percentage of pages resulted in a real action?
- **False positive rate.** What percentage of pages were noise?

A healthy on-call rotation has:
- 0-3 pages per week.
- <5 minute time to acknowledge.
- Actionable rate above 80%.
- False positive rate below 10%.

If these numbers are worse, the strategy needs work. Usually the fix is removing alerts, not adding them.

### Alert fatigue — the silent killer

Alert fatigue is the psychological state where on-call engineers stop taking alerts seriously because they've been paged too often for things that turned out not to matter. It manifests as:

- **Longer time to acknowledge.** "It's probably nothing again."
- **Silencing alerts without investigating.** "I'll look at it tomorrow."
- **Skipping the runbook.** "I know what this is; it'll resolve itself."
- **Dismissing real incidents.** The real one comes in, and it looks like noise.

The causes:
- **Too many alerts.** Sheer volume.
- **Non-actionable alerts.** Fire but have no clear response.
- **Cause-based alerts.** Fire for conditions that don't affect users.
- **Poorly tuned thresholds.** Fire for normal variation.
- **No maintenance.** Alerts that were right two years ago haven't been updated as the system changed.

The fix is continuous pruning. Every incident retrospective should ask "should any alerts be tuned, removed, or added?". Alerts that haven't fired in 6 months should be reviewed ("is this still needed?"). Alerts that fire often without action should be removed immediately.

### Runbooks — the missing link between alert and action

Every alert should link to a runbook: a short document describing what the alert means, what to check, and how to respond.

Minimum runbook content:
- **What the alert means.** "Error rate for billing service exceeded 1% for 5 minutes."
- **Impact.** "Some users are unable to complete checkouts. Revenue is directly affected."
- **First checks.** "Check the billing service dashboard for error types. Check recent deploys. Check downstream payment provider status."
- **Common causes.** "Most frequent: Stripe API degradation. Second most frequent: database connection saturation."
- **Immediate mitigations.** "If Stripe is degraded, enable fallback payment flow with feature flag X. If DB saturated, scale up connection pool."
- **Escalation path.** "If not resolved in 15 minutes, page the platform team lead."

Runbooks make alerts actionable for engineers who aren't deeply familiar with the specific service. Without them, every alert becomes a learning exercise; with them, even a fresh on-call engineer can respond effectively.

### Alert ownership

Every alert has an owner — a team responsible for tuning, updating, and retiring it. Without clear ownership, alerts rot: the person who created them leaves, the service changes, the alert fires for reasons nobody understands, and nobody feels empowered to change it.

Tag alerts with owner labels (`team: billing`, `owner: platform-infra`). Route alerts to the owner's channels. Review alerts periodically at the team level.

### The test: "would this alert catch the last incident?"

When designing alerts, simulate against past incidents:

- **Take the last 5-10 incidents.**
- **Ask: would my current alerts have caught each one before users complained?**
- **If no, what alert would have?**
- **Is that alert a symptom alert or a cause alert?**
- **Is it the right addition, or is the gap actually in dashboards and runbooks rather than alerts?**

This exercise reveals both missing alerts and unnecessary ones.

> **Mid-level answer stops here.** A mid-level dev can describe symptom vs cause. To sound senior, speak to the operational discipline — on-call load, alert fatigue, runbooks, continuous pruning, and the cultural commitment to keeping the pager meaningful ↓
>
> **Senior signal:** treating alerting as a human-factors problem, not just a technical one.

### The human side

Alerting is ultimately about humans. The metric you care about isn't "did the alert fire when the condition was met"; it's "did the on-call engineer wake up, understand the problem, respond effectively, and return to sleep". Every design decision should optimize for that.

This means:
- **Fewer alerts are better.** Silence is the goal. The pager should be quiet most of the time.
- **Clearer alerts are better.** The message, runbook, and context should minimize cognitive load at 3 a.m.
- **Retrospectives are mandatory.** Every page should be reviewed, not just technically but for "was this the right alert?".
- **Leadership buy-in matters.** "Reducing on-call load" must be treated as real engineering work, not a side project.

### Common mistakes

- **Alerting on CPU, memory, disk.** Cause-based, usually not actionable.
- **Alerting on every possible problem.** Too many alerts → fatigue → ignored real ones.
- **Alerts without runbooks.** On-call engineer has to derive the response from scratch.
- **Alerts nobody owns.** Stale alerts that nobody feels empowered to change.
- **Alerts that fire for expected behavior.** Scheduled jobs, expected spikes, known maintenance.
- **Alerts that fire before the condition is real.** Short evaluation windows cause transient spikes to page.
- **No inhibition.** "Service down" and "high error rate" both fire for the same incident; the engineer gets paged twice.
- **Paging on business-hour issues.** Alert severity should match response urgency. Non-urgent issues go to tickets, not pages.
- **No on-call health metrics.** Nobody tracks pages per shift, so the problem goes unnoticed until someone burns out.

### The evolution of an alerting strategy

Most teams start here:

1. **No alerting.** Failures are discovered by users.
2. **Threshold alerts on everything.** Wake up for any anomaly. On-call is hell.
3. **Tuning down to reduce noise.** Silence the worst offenders. Still alerting on causes.
4. **Symptom-based alerting.** Shift from "CPU alert" to "error rate alert". Massive noise reduction.
5. **SLO-based burn-rate alerting.** The modern pattern. Alerts are tied to business-relevant SLOs.
6. **Continuous improvement.** Alert hygiene is part of the team's ongoing work. Retrospectives drive pruning and tuning.

Most teams never get past stage 3. Getting to stage 5 is worth the effort; on-call becomes something people can do without burning out.

### Closing

"So alerting strategy is: alert on user-visible symptoms, not internal causes; every alert must be actionable with a runbook; prefer burn-rate alerts tied to SLOs over threshold alerts on raw metrics; keep the pager volume low because humans can't maintain vigilance through constant noise; and continuously prune alerts that don't fire for real problems. The metric that matters is on-call load and actionability, not 'did we catch everything'. A quiet pager that wakes people up only for real incidents is the goal — and getting there is a continuous engineering effort, not a one-time setup."
