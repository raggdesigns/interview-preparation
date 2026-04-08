# Deployment strategies (blue-green, canary, rolling, feature flags)

**Interview framing:**

"Deployment strategy is the answer to one question: how do you replace version N with version N+1 without breaking users? There are four canonical answers — rolling deploys, blue-green, canary, and feature flags — and each trades off cost, complexity, and risk differently. The senior insight is that these aren't mutually exclusive: real production systems combine them. You might roll a new image with a rolling deploy, gate the new behavior behind a feature flag, enable it for 1% of users as a canary, and have blue-green at the cluster level as a disaster-recovery escape hatch. Understanding which strategy to reach for in which situation is the interview answer."

### Rolling deploy — the default

**What it is:** pods are replaced one at a time (or a few at a time) with the new version. At any given moment, some pods are running version N and some are running N+1.

**How Kubernetes does it:**
- `maxSurge` — how many extra pods can exist temporarily during the roll. Default 25%.
- `maxUnavailable` — how many pods can be unavailable during the roll. Default 25%.

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

"At most 1 extra pod during the roll, zero unavailable" — the safe default: new pods start up *before* old ones are terminated, capacity never dips below target.

**Pros:**
- Zero downtime if done right.
- No extra infrastructure — the same cluster, same nodes.
- Automatic rollback on failure (Kubernetes keeps rolling until the new version is healthy, or reverts).

**Cons:**
- **Mixed versions during the roll.** Both N and N+1 are handling traffic simultaneously. Any change that's not backward-compatible will break — API schema changes, database schema changes, shared cache key changes.
- **All-or-nothing at the endpoint level.** You can't route specific users to the new version; the load balancer doesn't care which version it picks.
- **Rollback is another rolling deploy.** If N+1 is broken, you roll back by deploying N again — which takes as long as any other deploy.

**When to use:** every normal deploy of a backward-compatible change. This is the default and should stay the default.

### Blue-green — two full environments

**What it is:** two complete environments exist — "blue" (current production) and "green" (the new version). You deploy the new version to green, test it, then flip a switch (usually at the load balancer or DNS level) to direct traffic from blue to green.

```
Before:             During:             After:
[users]→[blue]      [users]→[blue]      [users]→[green]
        [green]             [green]             [blue]
         (idle)              (ready)             (standby)
```

**Pros:**
- **Fast rollback.** If green is broken, flip back to blue instantly.
- **Clean cutover.** There's no "mixed versions handling traffic" window.
- **Test before cutover.** You can run smoke tests, integration tests, and synthetic checks against green before any users see it.
- **Database migrations can happen on green in advance** (if the schema is backward-compatible).

**Cons:**
- **Doubles infrastructure cost** during the deploy. Both environments are running at full capacity.
- **Complex for stateful systems.** If green and blue share a database, schema migrations break the "instant rollback" promise — you can't roll back a schema change trivially. In practice, blue-green works best for stateless services.
- **Network topology changes.** Switching traffic between environments is usually done at the load balancer, ingress, or DNS level, and each has its own quirks (DNS TTLs, connection draining).

**When to use:**
- When you need fast rollback and the cost of running two environments is acceptable.
- For services where mixed versions during a roll would cause real problems.
- For major infrastructure changes (new cluster, new region) where you want a full parallel stack.

### Canary — gradually shift traffic

**What it is:** you deploy a small number of pods running the new version alongside the old one, then route a small percentage of traffic to the new pods — 1%, then 5%, then 25%, then 100% — monitoring metrics at each step. If metrics degrade, you stop or roll back.

```
Step 1: 100% traffic → version N     (5% pods running N+1 in background, receiving no traffic)
Step 2:  95% → N, 5% → N+1            (initial canary)
Step 3:  75% → N, 25% → N+1           (if step 2 metrics are healthy)
Step 4:   0% → N, 100% → N+1          (full rollout)
```

**Pros:**
- **Catches problems early.** If the new version has a bug, you see it on 5% of traffic, not 100%.
- **Real-user validation.** Some bugs only appear under production load patterns; synthetic tests don't catch them.
- **Gradual confidence building.** Each successful step increases your confidence in the rollout.
- **Automated with the right tooling.** Flagger, Argo Rollouts, and similar tools can drive canary rollouts based on metrics.

**Cons:**
- **Requires traffic-splitting infrastructure.** Istio, Linkerd, or an ingress controller that supports weighted routing. Not trivial to set up.
- **Metrics-based rollback requires good metrics.** If you can't measure "is this version healthy?" automatically, canary is just a manual rolling deploy with extra steps.
- **Mixed versions, same as rolling.** Compatibility concerns apply.
- **Longer deploy time.** Canary rollouts take longer than rolling deploys because each step is monitored.

**When to use:**
- High-stakes services where a broken deploy is costly.
- When you have the observability to judge "is this new version healthier than the old one?" automatically.
- For changes whose impact is hard to predict (new algorithms, performance optimizations, dependency upgrades).

### Feature flags — decouple deploy from release

**What it is:** you ship new code wrapped in a runtime flag. The code is deployed, but the feature is off. You enable the flag for internal users, then 1% of users, then more, without redeploying.

```php
if ($this->featureFlags->isEnabled('new_checkout_flow', $user)) {
    return $this->newCheckoutFlow();
}
return $this->oldCheckoutFlow();
```

**Pros:**
- **Deploy != release.** You can deploy 20 times a day without any user seeing a behavior change. Release is a separate, instant, reversible decision.
- **Per-user targeting.** Enable the feature for your internal team, beta users, or a random 5% — not a traffic-percentage approximation.
- **Instant rollback.** Toggle the flag off. No deploy, no container restart, no database change.
- **Safe experimentation.** A/B tests, dark launches, gradual rollouts — all powered by the same mechanism.
- **Works with any deployment model.** Rolling, blue-green, canary — orthogonal.

**Cons:**
- **Complexity tax.** Every flag is a branch in the code. Flags that stick around forever become technical debt. Establish a policy: flags have an expiration date and a clean-up plan.
- **Testing surface grows combinatorially.** Every flag doubles the paths through the code. You can't test every combination.
- **Runtime evaluation cost.** Flag checks happen on every request; they need to be fast.
- **Flag management infrastructure.** You need a tool (LaunchDarkly, Unleash, Flagsmith, or a homegrown system) to manage flags at scale.

**When to use:**
- Always, for anything user-facing that you want to be able to toggle.
- Especially for risky changes — new algorithms, new UX, external integrations.
- For decoupling deploys from releases so deploys become boring.

### Combining strategies — the real world

Production systems rarely use just one strategy. A typical setup might look like:

1. **Rolling deploy** of the new container image (the default mechanism).
2. **Feature flags** protecting any user-visible behavior change in the new version. The new code is running but its effect is invisible.
3. **Progressive rollout of the flag** — internal users → beta users → 1% → 10% → 100%. The "canary" happens at the flag level, not the infrastructure level.
4. **Blue-green at the cluster level** for major changes (Kubernetes version upgrades, region migrations). Orthogonal to the application deploy.

This layered approach gives you fast deploys (rolling), safe releases (flags), gradual validation (progressive flags), and a disaster-recovery escape hatch (blue-green). Each strategy handles the part of the problem it's best at.

### Database migrations and deploys — the hardest part

The one thing that breaks all these strategies if you do it wrong: schema changes.

**Backward-compatible migrations only.** Every schema change should be compatible with both the old and new application code. The process:

1. **Expand.** Add the new column/table/index. Both old code (ignoring the new column) and new code (using it) work.
2. **Deploy new code.** Old and new code coexist during the rollout.
3. **Migrate data** (if necessary). Backfill the new column from the old one, convert data, whatever's needed.
4. **Contract.** Remove the old column/table in a later deploy, after you're confident the new code works and no old code is left running.

Never do expand+contract in one deploy. The mixed-version window during a rolling deploy will break old pods that still reference the removed column.

**Blue-green alleviates this** — you can migrate the schema for green before the cutover, and old code never sees the new schema. But blue-green is more expensive.

**Feature flags help too** — you can ship new-schema-using code behind a flag that's off, migrate the schema, then enable the flag. Decoupling again.

### Automated rollback — the feature people forget

Every deploy strategy needs an automated rollback path. "We'll roll back manually if it breaks" is not a plan; it's a promise you won't be able to keep at 3 a.m.

**Automated rollback requires:**
- **Metrics that indicate health.** Error rate, latency, success rate. If you can't measure it, you can't automate the decision.
- **A threshold for rollback.** "Rollback if error rate exceeds 2% for 3 minutes."
- **A fast rollback mechanism.** Rolling back should take seconds, not minutes. Blue-green and feature flags are faster than another rolling deploy.
- **A test of the rollback itself.** You'll find out rollback is broken at the worst possible time unless you rehearse it regularly.

### Zero-downtime deploys — the common baseline

Any strategy should be zero-downtime for a normal deploy. Requirements:

- **Graceful shutdown.** Pods finish in-flight requests before exiting. See [kubernetes_for_php_apps.md](kubernetes_for_php_apps.md) for the PHP-specific details.
- **Readiness probes.** New pods aren't sent traffic until they're ready.
- **`maxUnavailable: 0`** in rolling deploys (or equivalent) so capacity is always maintained.
- **Connection draining** at load balancers, not abrupt termination.
- **Session handling.** If the application keeps server-side sessions, they need to survive pod replacement. Usually: store sessions in Redis or the database, never in local memory.

Missing any of these turns "zero-downtime" into "mostly zero-downtime except during deploys".

> **Mid-level answer stops here.** A mid-level dev can list the strategies. To sound senior, speak to the trade-offs and the combinations that make real systems work ↓
>
> **Senior signal:** understanding that deploy strategy is a risk management decision, and picking the combination of strategies that matches the blast radius of the change.

### The decision framework

1. **Is the change backward-compatible?**
   - Yes → rolling deploy is fine.
   - No → blue-green, or make it backward-compatible first (usually the right answer).

2. **How costly is a bad deploy?**
   - Low (internal tools, low-traffic services) → rolling deploy with automated rollback is plenty.
   - Medium (revenue-critical, customer-facing) → rolling deploy + feature flags.
   - High (payments, auth, safety-critical) → canary + feature flags + extensive pre-production validation.

3. **How fast do you need to roll back?**
   - Seconds → feature flags or blue-green.
   - Minutes → another rolling deploy.

4. **How predictable is the new code's behavior?**
   - Very → rolling deploy.
   - Not very → canary or progressive feature flag rollout.

5. **Can you afford to run two environments?**
   - Yes → blue-green is on the table.
   - No → rolling + feature flags.

### Common mistakes

- **Deploying non-backward-compatible changes with a rolling deploy.** The mixed-version window breaks things. Use expand-then-contract.
- **No readiness probe.** Pods get traffic before they're ready; requests fail during the roll.
- **No feature flags for risky changes.** "We'll be careful" is not a rollback plan.
- **Flags that live forever.** Technical debt accumulates; testing surface explodes.
- **Blue-green with a shared database.** The cutover isn't atomic; schema migrations break the guarantee.
- **No metrics for rollback decisions.** Canary rollouts without automated metric checks are just manual rolling deploys with ceremony.
- **Manual rollback only.** The on-call engineer's job gets much harder.
- **Deploying on Fridays without confidence.** Not the deploy strategy's fault, but the strategy should make Friday deploys feel safe.

### Closing

"So the four canonical strategies are rolling (the default), blue-green (fast rollback at cost), canary (gradual traffic shift with metric gating), and feature flags (decoupling deploy from release). The senior answer is that you layer them — rolling deploys of images, feature flags for user-visible changes, progressive flag rollouts for the canary effect, and blue-green for the big changes where you need a full parallel stack. Every deploy strategy needs backward-compatible schema changes, graceful shutdown, automated health checks, and a rollback path that works without human intervention. Getting these right is what makes deploys boring — which is the goal."
