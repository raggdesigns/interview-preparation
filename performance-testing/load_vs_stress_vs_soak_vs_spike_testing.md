# Load vs stress vs soak vs spike testing

**Interview framing:**

"Performance testing isn't one thing — it's four distinct tests that answer four distinct questions. Load testing asks 'can we handle normal traffic?'. Stress testing asks 'where does it break?'. Soak testing asks 'does it degrade over time?'. Spike testing asks 'can it survive sudden bursts?'. Most teams only do load testing and call it done, which means they don't know where the breaking point is, whether memory leaks over 72 hours, or what happens when Black Friday traffic arrives 10x the usual. The senior answer is knowing which test to run for which concern."

### The four types

#### Load testing — "can we handle expected traffic?"

Run the system at the expected production load — the number of concurrent users, request rates, and mix of operations you actually expect — and measure response times, error rates, and resource usage.

**The question it answers:** does the system meet its performance requirements under normal conditions?

**The shape:**
```
Users ──────────────────────────────────
       │                              │
       │    steady state at target    │
       │                              │
       ramp up                  ramp down
──────────────────────────────────────── time
```

Ramp up gradually to the target load (100 VUs, 500 RPS, whatever your production baseline is), hold for 10-30 minutes, ramp down. Measure throughout.

**What to measure:**
- Response time (p50, p95, p99) — are they within SLO?
- Error rate — is it near zero under normal load?
- Throughput (RPS actually served) — does it match the injection rate?
- Resource usage (CPU, memory, DB connections, queue depth) — is the system comfortable or already strained?

**When to run:**
- Before every major release.
- After infrastructure changes (new instance types, new database, new cache).
- As a baseline before stress/soak/spike tests.

**Pass criteria:** response times meet SLOs, error rate is near zero, resources are within comfortable ranges (typically <70% of limits).

#### Stress testing — "where does it break?"

Gradually increase load beyond expected levels until the system fails. The goal is not to prove it works — it's to find the breaking point and understand the failure mode.

**The question it answers:** at what load does the system degrade unacceptably, and how does it fail?

**The shape:**
```
Users ─────────────────────────────────╲
       │              │               │ ╲ system breaks here
       │  target load │  beyond target│
       │              │               │
       ramp up        keep pushing    observe failure
──────────────────────────────────────── time
```

Start at baseline, keep ramping — 2x, 3x, 5x expected load. Watch response times degrade, error rates rise, resources saturate. Note the exact point where the system crosses from "degraded" to "broken".

**What you learn:**
- **The breaking point.** "We handle 2000 RPS; at 3500, p99 goes above 5s; at 4000, we start returning 503s."
- **The failure mode.** Does it degrade gracefully (slow but responsive) or collapse (avalanche of errors, cascade failure)?
- **The bottleneck.** What saturates first — CPU? Database connections? Memory? A downstream service?
- **Recovery behavior.** When load drops, does the system recover — or does it stay broken (e.g., connection pool exhausted, circuit breaker stuck open)?

**When to run:** before launches, before expected traffic spikes, after architectural changes, quarterly as a health check.

**The finding you want:** "we break at 3.5x baseline because the DB connection pool saturates. Adding PgBouncer gives us headroom to 6x." That's a specific, actionable result.

#### Soak testing — "does it degrade over time?"

Run the system at normal load for a long duration — 12 hours, 24 hours, 72 hours. Look for degradation that only appears over time.

**The question it answers:** are there slow leaks — memory, connections, file handles, database bloat — that accumulate over hours or days?

**The shape:**
```
Users ──────────────────────────────────
       │                              │
       │   normal load, long time     │
       │                              │
──────────────────────────────────────── time (hours to days)
```

**What you're looking for:**
- **Memory leaks.** Memory usage trending upward over hours. Common in PHP long-running workers (Messenger consumers, Swoole/RoadRunner workers).
- **Connection leaks.** Database or broker connections not being returned to the pool.
- **File descriptor exhaustion.** Sockets or files opened and never closed.
- **Database bloat.** Dead tuples accumulating because VACUUM can't keep up with sustained write load.
- **Log disk usage.** Logs filling disk over time.
- **Cache eviction under sustained load.** Working set gradually exceeds cache size; hit rate drops.
- **Garbage collection pressure.** GC pauses getting longer as heap grows.

**When to run:** before production readiness certification, after introducing long-running workers, quarterly on critical services.

**The PHP angle:** PHP-FPM request handlers are inherently soak-safe because each request gets a fresh state. The concern is with **long-running processes**: Messenger workers, cron jobs, Swoole/RoadRunner workers. These accumulate state between requests and are the #1 source of memory leaks in PHP systems. Soak testing catches what unit tests can't — the slow creep that only shows up after 10,000 messages.

#### Spike testing — "can it survive sudden bursts?"

Hit the system with a sudden, dramatic increase in traffic — 10x in seconds — then drop back to normal. Observe the response during the spike and the recovery after.

**The question it answers:** does the system handle sudden traffic surges without cascading failure?

**The shape:**
```
Users ─────╱╲───────────────────────────
       │  ╱  ╲                         │
       │ ╱    ╲  sharp spike          │
       │╱      ╲                      │
       │        ╲──── back to normal  │
──────────────────────────────────────── time
```

**What you're looking for:**
- **Auto-scaling response time.** If HPA is configured, how fast does it add pods? Fast enough to matter during the spike?
- **Queue behavior.** Do message queues absorb the burst and drain normally after?
- **Connection pool behavior.** Does the pool exhaust during the spike? Does it recover?
- **Circuit breakers and rate limiters.** Do they trigger? Do they recover?
- **Cache stampede.** Many concurrent requests for the same uncached value causing a thundering herd on the backend.
- **Error rate during the spike.** Brief errors are expected; persistent errors after the spike ends are a problem.
- **Recovery time.** How long until the system is fully healthy after the spike ends?

**When to run:** before marketing events, before product launches, before any expected traffic surge. Also as a routine test — spikes happen without warning (a viral post, a bot attack, a retry storm from a partner).

### The meta-discipline

- **Run all four.** Load alone is not enough. Stress finds the ceiling. Soak finds the slow leaks. Spike finds the cascade failures.
- **Run in a production-like environment.** Testing against a dev database with 100 rows proves nothing about production with 100 million rows.
- **Test the whole stack.** Load testing your API server without the database is a unit test, not a load test.
- **Measure from outside, not inside.** The client-perceived response time includes network, load balancer, and everything else. Server-side timers miss the edges.
- **Record everything.** Every test run should produce a report with: test type, load profile, environment details, results (latency percentiles, error rates, resource usage), and findings.
- **Version-control the test scripts.** They're code. They belong in git next to the application code.

> **Mid-level answer stops here.** A mid-level dev can describe the four types. To sound senior, speak to the operational discipline — when to run each, how to make results actionable, and the failure modes of testing incorrectly ↓
>
> **Senior signal:** treating performance testing as a continuous engineering practice, not a one-time certification.

### Making results actionable

A performance test result is only useful if it produces one of these:
1. **"We're fine."** Document the baseline for future comparison.
2. **"We'll break at X."** Document X, plan for it (scale before reaching X, or accept the risk).
3. **"We have a leak."** File a ticket, quantify the leak rate, prioritize the fix.
4. **"We can't handle spikes."** Improve auto-scaling, add rate limiting, add caching, or accept the risk.

"We ran a load test and it was fine" is only useful if you recorded the conditions, the results, and the baseline. Next quarter's test needs something to compare against.

### Common mistakes

- **Only load testing.** Missing stress, soak, and spike means missing the most interesting findings.
- **Testing in a non-production-like environment.** Results don't transfer.
- **Testing with unrealistic data.** An empty database is fast; a 100 GB database with real indexes and distribution is reality.
- **Not testing the full stack.** Load testing the API without the database, cache, and broker is incomplete.
- **No baseline.** Without a baseline, you can't tell if the next test is a regression.
- **Running tests once and never again.** Performance characteristics change with code, data growth, and traffic patterns.
- **Not reading test results in context.** "p99 is 200ms" means nothing without "at 500 RPS on a production-sized dataset".
- **Measuring averages instead of percentiles.** Averages hide tails.

### Closing

"So the four types are load (normal traffic), stress (find the ceiling), soak (find the slow leaks), and spike (survive sudden bursts). Each answers a different question, and running only one of them leaves three blind spots. The senior practice is running all four as part of a regular cadence, in production-like environments with production-sized data, recording baselines and comparing across releases. The goal isn't 'the test passed' — it's 'we know where we stand, where we'll break, and what to do when we get there'."
