# CI/CD pipeline anatomy

**Interview framing:**

"A CI/CD pipeline is the set of automated steps that take a commit and produce either a rejected change (failed tests) or a deployed artifact in production. Every mature team has one, and the shape is surprisingly consistent across languages and stacks: lint, test, build, scan, deploy, verify. What differs between good and bad pipelines is not the steps themselves but the discipline — fast feedback, deterministic builds, small blast radius per deploy, and rollback that actually works when you need it."

### The canonical stages

A typical pipeline looks like this, and each stage has a reason to exist:

```
┌──────────┐   ┌──────┐   ┌──────┐   ┌───────┐   ┌────────┐   ┌────────┐   ┌────────┐
│  Commit  │─→ │ Lint │─→ │ Test │─→ │ Build │─→ │  Scan  │─→ │ Deploy │─→ │ Verify │
└──────────┘   └──────┘   └──────┘   └───────┘   └────────┘   └────────┘   └────────┘
                                          │
                                          ▼
                                     ┌─────────┐
                                     │ Publish │  (tag image, push to registry)
                                     └─────────┘
```

**Lint** — style and syntax checks. Fast. Fails early on obvious problems so the expensive stages don't run.

**Test** — unit, integration, and possibly end-to-end tests. The bulk of pipeline time is here, which is also where the most value comes from. Parallelization and caching matter.

**Build** — produce the deployment artifact. For a containerized PHP app, this is `docker build` of the production image with multi-stage, producing a digest-addressed image in the registry.

**Scan** — image vulnerability scan, SAST (static application security testing), dependency scan, license check. Blocks deploys if critical findings appear.

**Deploy** — push the artifact to the target environment. For Kubernetes, this is typically `kubectl apply` or a GitOps tool reacting to a change in a config repo.

**Verify** — post-deploy smoke tests, health check polling, synthetic monitoring hit. If verification fails, trigger rollback.

### CI vs CD — the distinction that matters

- **Continuous Integration (CI)** — every commit is automatically built and tested against the main branch. The output is "is this change safe?"
- **Continuous Delivery** — every change that passes CI is *ready* to deploy, but deploy is triggered manually.
- **Continuous Deployment** — every change that passes CI is automatically deployed to production.

Most teams say "CI/CD" and mean somewhere on the spectrum. The distinction matters because "continuous deployment" requires a *much* higher bar of test coverage, monitoring, and rollback confidence. A team without that bar should do continuous delivery with a manual deploy step, not pretend to do continuous deployment with lots of manual intervention hidden inside.

### The principles that separate good pipelines from bad

- **Fast feedback.** A pipeline that takes 40 minutes is a pipeline nobody uses. Aim for 10-15 minutes end-to-end for a typical commit. Parallelize aggressively, cache aggressively, fail fast.
- **Deterministic builds.** The same commit should produce the same artifact every time. Non-determinism hides in timestamps, unpinned dependencies, network flakiness, and randomness. Find it and eliminate it.
- **Ephemeral environments.** Every CI run gets a fresh environment. No shared state, no "the build failed because the previous one left stuff behind".
- **Artifacts flow forward.** Build once, deploy the same artifact to every environment (dev → staging → prod). Don't rebuild per environment. Rebuilding introduces drift between what you tested and what you're deploying.
- **Secrets never in logs.** Pipelines handle secrets; secrets must not end up in build logs, stack traces, or error messages. Mask them at the runner.
- **Rollback is a first-class feature.** If you can't roll back quickly, you can't deploy quickly. Rollback should be as rehearsed as forward deploys.

### The test stage in detail

For a PHP project, a good test stage typically includes:

- **Static analysis.** PHPStan or Psalm, level 6+. Catches bugs before tests run.
- **Unit tests.** PHPUnit, fast, isolated. Should run in seconds on a typical commit.
- **Integration tests.** Against a real database and real broker. Slower but catch the interesting bugs. Use Docker services in the pipeline (GitHub Actions `services`, GitLab CI `services`).
- **Mutation tests** (optional, expensive). Tools like Infection deliberately mutate your code and verify tests fail. Great coverage signal, too slow for every commit.
- **Contract tests** for services that consume APIs.
- **Coverage report.** Codecov or similar. Useful as a trend, dangerous as a gate (teams gaming the metric produces worse tests).

**Parallelization:** the biggest speedup for large test suites. PHPUnit has `paratest`, Symfony has `--recreate-database-for-each-test` strategies, and GitHub Actions has matrix builds. Running 4 shards in parallel turns a 20-minute test stage into a 5-minute stage.

### The build stage: one artifact, many environments

The build stage produces the container image that will be deployed everywhere. Build it once, tag it with the commit SHA, push it to the registry. Every downstream environment deploys that specific digest.

```yaml
# Pseudo-pipeline
- name: Build and push image
  run: |
    docker build \
      --build-arg COMMIT_SHA=$GITHUB_SHA \
      --build-arg BUILD_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
      -t registry.example.com/billing:$GITHUB_SHA \
      -t registry.example.com/billing:latest-main \
      .

    docker push registry.example.com/billing:$GITHUB_SHA
    docker push registry.example.com/billing:latest-main
```

Note the **two tags**:
- `commit SHA` — immutable, points at this specific build forever.
- `latest-main` — mutable alias for "the most recent successful build of main".

Deployments should reference the SHA tag, not `latest-main`. Using `latest-main` for deploys means "the exact image I deploy depends on when I deploy it", which is non-deterministic and defeats the whole point.

Even better, use the **image digest** (`sha256:...`). Digests are content-addressed and tamper-evident. Tags can be moved; digests cannot.

### The deploy stage: two models

**Imperative (`kubectl apply` from CI):**
The pipeline runs `kubectl apply` against the cluster directly.

- **Pros:** simple, direct, one tool.
- **Cons:** the pipeline needs cluster credentials, drift between git state and cluster state is invisible, rollback is manual.

**Declarative / GitOps (ArgoCD, Flux):**
A config repo holds the desired cluster state. A GitOps controller in the cluster watches the repo and syncs the cluster to match. The pipeline doesn't deploy — it pushes a change to the config repo, and the controller picks it up.

- **Pros:** git is the source of truth, drift is detected automatically, rollback is a `git revert`, the pipeline has no cluster credentials.
- **Cons:** more moving parts, small additional latency between commit and deploy.

For any serious production workload, GitOps is worth the cost. The audit trail, drift detection, and declarative rollback story are genuinely valuable.

### The verify stage

After the deploy, verify that the new version is actually healthy before declaring success:

- **Poll the readiness endpoint** until pods are ready.
- **Run a synthetic monitoring check** against the new version.
- **Check that error rates haven't spiked.**
- **Check that latency is within bounds.**

If verification fails, **roll back automatically**. Don't rely on an alert and a human. The human may not be awake.

### Environments and promotion

A typical environment pipeline:

```
commit → CI (lint, test, build, scan)
   │
   ▼ (auto)
dev environment
   │
   ▼ (auto)
staging environment
   │
   ▼ (manual approval)
production environment
```

Each environment runs the same image. Only the config differs. Manual approval between staging and prod is where "continuous delivery" stops and "continuous deployment" would start.

**Feature flags** are the escape hatch that lets you deploy code to production without *enabling* it. Ship the change dark, enable it for internal users, enable for 1% of traffic, ramp up. Decouples "deploy" from "release" in a way that makes deploys much less risky.

### Caching for speed

Pipelines without caching take 3-5x as long as they should. Things to cache:

- **Composer dependencies.** The entire `vendor/` directory, keyed on `composer.lock`. If the lockfile hasn't changed, restore from cache; otherwise install.
- **Docker layer cache.** Build args and intermediate layers.
- **Test databases.** Migrate once per cache key, not per test run.
- **Node modules** (for asset builds).
- **Static analysis baselines.**

Each of these shaves minutes off a cold build.

> **Mid-level answer stops here.** A mid-level dev can list pipeline stages. To sound senior, speak to the discipline and the failure modes ↓
>
> **Senior signal:** treating the pipeline as production infrastructure with its own reliability, performance, and security concerns.

### The pipeline is production infrastructure

A broken pipeline is a broken deploy process. A slow pipeline is a slow team. A compromised pipeline is a compromised production. Treat it with production rigor:

- **Monitor pipeline reliability.** Track success rate, p95 duration, flaky test rate. If any of these regress, it's a real incident.
- **Version control the pipeline definition.** The pipeline config lives in the repo, reviewed like any other code.
- **Secure the pipeline itself.** Pipeline runners have access to the registry, the cluster, and often secrets. An attacker who compromises the pipeline compromises everything.
- **Limit pipeline permissions.** Separate credentials per environment. Staging runners shouldn't be able to deploy to production. Pipeline OIDC trust (GitHub Actions to AWS, for example) is the modern, credential-less way to do this.
- **Log retention and auditability.** Who deployed what, when, with what result. Many compliance regimes require this.

### Common pipeline failures I've seen

- **Rebuilding the image per environment.** Non-deterministic, drift-prone, slow. Build once, promote the same digest.
- **Long, slow pipelines nobody runs.** Fix the speed, or people start pushing around it.
- **Flaky tests poisoning trust.** A test that fails 10% of the time teaches everyone to retry failures, which masks real bugs. Fix flaky tests immediately; don't tolerate them.
- **Secrets leaked in logs.** Masking is opt-in on some platforms. Audit pipeline output for accidental secret prints.
- **No rollback plan.** The pipeline deploys but has no automated rollback. Every bad deploy becomes a manual scramble.
- **Pipeline credentials too broad.** Pipeline runner has cluster-admin. An attacker with pipeline access owns everything.
- **Silent deploy failures.** The pipeline reports success but the deploy actually rolled back or failed. Always verify post-deploy.

### A good pipeline, summarized

- Lints and type-checks before expensive stages.
- Parallelized tests run in under 10 minutes.
- Builds one image, tagged with a digest and a SHA.
- Scans for CVEs and license issues.
- Deploys to dev and staging automatically.
- Gates production on a manual or automatic verification step.
- Rolls back automatically if post-deploy verification fails.
- Uses GitOps for production deploys.
- Has its own metrics, alerts, and incident response.
- Is secure, ephemeral, and reproducible.

### Closing

"So a CI/CD pipeline is a declarative assembly line for software — lint, test, build, scan, deploy, verify, rollback. The shape is standard; the quality comes from the discipline: fast feedback, deterministic builds, one artifact promoted across environments, verification before declaring success, automated rollback, and treating the pipeline as production infrastructure with its own reliability concerns. A team with a fast, reliable pipeline ships confidently; a team without one ships cautiously, which usually means rarely."
