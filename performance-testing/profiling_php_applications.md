# Profiling PHP applications

**Interview framing:**

"Profiling is the practice of measuring where a PHP application spends its time and memory — not at the request level ('this endpoint is slow') but at the function level ('this function runs 3000 times and accounts for 40% of the wall time'). The tools differ — Blackfire for continuous profiling in production, Tideways as a managed alternative, Xdebug for local deep-dives, XHProf for lightweight sampling — but the workflow is the same: profile, find the hot path, optimize it, verify the improvement. A senior engineer profiles before optimizing, not after, because intuition about performance is almost always wrong."

### Why profiling, not guessing

The fundamental rule of performance work: **measure before optimizing**. Developers consistently guess wrong about where time is spent. The function you think is slow usually isn't; the function you didn't suspect is usually the one allocating memory 50,000 times in a loop.

Profiling gives you:
- **Call counts** — how many times each function was called. N+1 patterns jump out here.
- **Wall time per function** — clock time including I/O waits.
- **CPU time per function** — time spent on CPU, excluding I/O. Useful for identifying computation-heavy functions.
- **Memory allocation** — how much memory each function allocated.
- **Call graph** — who called whom, and how time distributes through the call tree.

### The tools

#### Blackfire — the production profiler

Blackfire is a commercial profiler from the Symfony team. It's the most production-oriented option: low overhead, can run on every request or on-demand, integrates with CI for automated profiling.

**How it works:**
1. Install the Blackfire probe (PHP extension) and agent on the server.
2. Trigger a profile from the browser (via the Blackfire browser extension), CLI (`blackfire run php script.php`), or CI.
3. The profile is collected and sent to Blackfire's servers for analysis.
4. View the results in Blackfire's web UI: call graph, timeline, hot paths, recommendations.

**Key features:**
- **Timeline view** — horizontal timeline showing function execution over time. I/O waits, SQL queries, and CPU work are visually distinct.
- **Call graph** — function-by-function breakdown with percentages. Click any function to see its callers and callees.
- **Comparisons** — compare two profiles side by side. "Before vs after the optimization." This is the killer feature for verification.
- **Automated recommendations** — "You're calling `Doctrine\ORM\UnitOfWork::computeChangeSets` 200 times; consider batch flushing."
- **Assertions in CI** — define performance budgets (max wall time, max SQL queries, max memory) and fail the build if they're exceeded.
- **Continuous profiling** — sample a percentage of production requests automatically and aggregate findings.

**When to use:** production profiling, CI-integrated performance budgets, before/after comparisons. The goto tool for serious PHP performance work.

#### Tideways — the managed APM

Tideways is a PHP-specific application performance monitoring tool. Like Blackfire but with a different focus: it's always-on monitoring rather than on-demand profiling.

**Key differences from Blackfire:**
- **Always-on tracing** — every request is traced (with sampling for detailed profiles).
- **Transaction-level monitoring** — see the slowest transactions, error rates, throughput — similar to Datadog APM but PHP-specific.
- **Database query analysis** — automatic N+1 detection, slow query highlighting.
- **Exception tracking** — integrated error monitoring.
- **Team-oriented dashboard** — designed for ongoing monitoring, not one-off profiling.

**When to use:** when you want ongoing APM with deep PHP-specific insights. Good for teams that want monitoring + profiling in one tool.

#### Xdebug — the development profiler

Xdebug is the standard PHP debugging extension. It includes a profiler that generates cachegrind-format files, viewable in KCachegrind, QCachegrind, or webgrind.

```ini
; php.ini for profiling
xdebug.mode = profile
xdebug.output_dir = /tmp/xdebug
xdebug.start_with_request = trigger  ; profile only when triggered
```

Trigger with `XDEBUG_PROFILE=1` cookie or query parameter. The profiler writes a `.cachegrind` file that shows every function call, count, and time.

**Strengths:**
- **Free and open-source.** No account, no cloud service.
- **Deep detail.** Every function call is recorded.
- **Works locally.** No agent, no network, no third-party service.

**Weaknesses:**
- **Heavy overhead.** Xdebug profiling significantly slows execution (2-10x). Results reflect relative proportions, not absolute timing.
- **Not for production.** The overhead and the file I/O make it unsuitable for live traffic.
- **Clunky visualization.** KCachegrind is powerful but old; the learning curve is non-trivial.
- **No comparison mode.** You manually compare before/after profiles.

**When to use:** local development deep-dives on specific slow requests. Install, profile, analyze, remove. Not for ongoing monitoring.

#### XHProf — the lightweight sampler

XHProf (originally from Facebook) is a lightweight profiler that collects function-level timing with minimal overhead. The modern fork is `tideways_xhprof` (or `excimer` for sampling-based profiling).

```php
// Manual instrumentation
tideways_xhprof_enable(TIDEWAYS_XHPROF_FLAGS_MEMORY | TIDEWAYS_XHPROF_FLAGS_CPU);

// ... run the code being profiled ...

$data = tideways_xhprof_disable();
// Store $data or send to a visualization tool
```

**Strengths:**
- **Low overhead.** ~5% slowdown, acceptable for production sampling.
- **Simple.** Enable, run, disable, read the data.
- **Production-viable** for sampled profiling.

**Weaknesses:**
- **No built-in UI.** You need a separate tool to visualize (xhprof's web UI, xhgui, or custom).
- **Less maintained** than commercial tools.
- **No CI integration.** Manual process.

**When to use:** production profiling when Blackfire isn't available or affordable. Good for "let me quickly profile this one request" without heavy tooling.

#### Excimer — the sampling profiler

Excimer is a PHP extension from Wikimedia that uses timer-based sampling instead of instrumentation. It periodically (every N microseconds) captures a stack trace, producing a statistical profile.

**Strengths:**
- **Near-zero overhead.** Sampling means the profiler only does work on timer interrupts.
- **Production-safe.** Can run on every request.
- **Flamegraph output.** Produces data suitable for flamegraphs, which are the best visualization for this kind of data.

**Weaknesses:**
- **Statistical, not exact.** Short functions may be missed entirely. Long functions are well-represented.
- **Less precise for call counts.** It knows what was on the stack, not how many times a function was called.

**When to use:** always-on production profiling with negligible overhead. Ideal for generating flamegraphs from real traffic.

### The profiling workflow

1. **Identify the slow request.** From monitoring, from user reports, from load test results.
2. **Reproduce it.** Locally or in a staging environment with production-like data.
3. **Profile it.** Run the profiler on the specific request.
4. **Read the profile.** Find the hot path — the chain of function calls consuming the most time.
5. **Analyze the hot path.** Is it CPU-bound? I/O-bound? Is it called too many times (N+1)?
6. **Optimize.** Fix the specific bottleneck.
7. **Re-profile.** Verify the optimization actually worked. Compare before/after.
8. **Repeat.** The next-slowest thing is now the new hot path. Optimize until you meet your SLO.

**Step 7 is the one people skip.** Optimizing without re-profiling is guessing. The optimization may not have helped, or it may have helped one thing and worsened another. Always verify.

### Reading a profile — what to look for

**Self time vs inclusive time:**
- **Self time** — time spent in the function itself, excluding calls to other functions.
- **Inclusive time** — time spent in the function plus all functions it calls.

A function with high inclusive time but low self time is a caller — the bottleneck is inside something it calls. A function with high self time is doing the actual work — it's the bottleneck itself.

**Call counts:**
- A function called once with 500ms self time → the function itself is slow.
- A function called 5000 times with 0.1ms self time each → the function is fine, but calling it 5000 times is the problem. Classic N+1.

**Memory allocation:**
- A function that allocates 100MB → probably creating large arrays or hydrating many objects. Look for ways to stream or paginate.
- High allocation rate with low peak usage → frequent allocate-then-free cycles. May be GC pressure.

### Common findings in PHP profiles

- **Doctrine hydration.** `UnitOfWork::createEntity` called thousands of times because a query returns way more entities than needed. Fix: select only needed fields (`partial`), use DTOs, or use raw SQL for large result sets.
- **Serialization overhead.** `json_encode` on large nested objects, or JMS Serializer processing deep object graphs. Fix: simpler DTOs, fewer nested relations.
- **Autoloading.** `Composer\Autoload\ClassLoader::findFile` appearing prominently. Normal for cold requests; should be negligible with OPCache warm. If it's hot, OPCache may be misconfigured.
- **Twig rendering.** Template compilation and rendering. Ensure compiled templates are cached (`auto_reload: false` in production).
- **Event dispatch overhead.** Symfony's event dispatcher calling many listeners. Usually not a problem; if it is, some listener is doing too much.
- **File I/O.** `file_get_contents`, `include`, `fopen` — reading files on every request that should be cached.
- **Regex compilation.** Complex regex patterns compiled on every call. Use `preg_match` with static patterns or precompile.

### Flamegraphs — the visualization that works

A **flamegraph** is a visualization where:
- The X axis is the total time (or samples).
- Each bar is a function.
- Bars are stacked: the caller is below the callee.
- Width represents the proportion of time spent in that function (inclusive).

Wide bars at the top of the stack are the bottleneck. The widest bar at the bottom is `main()` (100% of time); as you go up, the width shows where the time concentrates.

Flamegraphs are the single best visualization for profiling data. They immediately show you where time goes without having to read tables of numbers. Brendan Gregg's flamegraph tools generate SVGs from profiler output; Blackfire and Tideways generate them from their profiles.

### Profiling in CI — performance budgets

The advanced practice: run a profiler on every CI build and fail if performance budgets are exceeded.

**Blackfire supports this natively:**
```yaml
# .blackfire.yml
tests:
  "Homepage should be fast":
    path: "/"
    assertions:
      - "main.wall_time < 200ms"
      - "main.peak_memory < 50mb"
      - "metrics.sql.queries.count < 15"
```

If the homepage exceeds 200ms wall time, 50MB peak memory, or 15 SQL queries, the build fails.

This catches performance regressions the same way unit tests catch functional regressions — automatically, on every commit.

> **Mid-level answer stops here.** A mid-level dev can describe profiling tools. To sound senior, speak to the workflow discipline — profile before optimizing, always verify, use comparisons, integrate into CI ↓
>
> **Senior signal:** profiling as a routine practice with measurable outcomes, not a one-off debugging session.

### The discipline

- **Profile before optimizing.** Intuition about performance is wrong more often than right.
- **Always compare.** Before/after profiles prove the optimization worked.
- **Optimize the hot path, not the interesting path.** Fix what's slow, not what's ugly.
- **Stop when you meet the SLO.** Over-optimization has diminishing returns and increasing risk.
- **Profile production traffic.** Development traffic has different data, different patterns, different bottlenecks. Use Blackfire, Tideways, or Excimer for production profiling.
- **Profile after deploys.** A new version may introduce a regression that only profiling catches.
- **Integrate into CI.** Performance budgets prevent regressions from reaching production.

### Common mistakes

- **Profiling with Xdebug in production.** The overhead distorts results and slows users.
- **Optimizing without profiling.** "I think this is slow" is not data.
- **Not verifying the optimization.** "I made it faster" without a before/after comparison is wishful thinking.
- **Profiling with an empty database.** Production has millions of rows; your dev database has 10.
- **Focusing on micro-optimizations.** Saving 0.1ms in a function that runs once while a 50ms query runs 100 times goes unnoticed.
- **Ignoring memory profiles.** Memory leaks in workers are a soak-test problem that only memory profiling reveals.
- **No flamegraphs.** Reading raw profile data in tables is possible but 10x slower than reading a flamegraph.

### Closing

"So profiling is measuring where time and memory go at the function level. Blackfire for production and CI, Tideways for ongoing APM, Xdebug for local deep-dives, XHProf for lightweight production sampling, Excimer for always-on flamegraph-ready sampling. The workflow is: reproduce, profile, find the hot path, optimize it, re-profile to verify. Always profile before optimizing, always compare before and after, and stop when you meet the SLO. Integrating profiling into CI via performance budgets catches regressions before production does."
