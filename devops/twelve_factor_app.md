# The Twelve-Factor App

**Interview framing:**

"The Twelve-Factor App is a methodology from Heroku, published around 2011, for building apps that run well on modern cloud platforms. It's old, it predates Kubernetes, and some of the advice has aged differently than the authors expected — but the core ideas are the reason modern deployment practice looks the way it does. If you understand the twelve factors, you understand *why* containers, stateless services, environment-based config, and managed backing services are the default. The interview answer isn't to recite all twelve; it's to articulate the principles and call out which ones are most important for the role you're describing."

### The twelve factors, briefly

| # | Factor | One-liner |
|---|--------|-----------|
| I | Codebase | One codebase tracked in version control, many deploys |
| II | Dependencies | Explicitly declare and isolate dependencies |
| III | Config | Store config in the environment |
| IV | Backing services | Treat backing services as attached resources |
| V | Build, release, run | Strictly separate build and run stages |
| VI | Processes | Execute the app as one or more stateless processes |
| VII | Port binding | Export services via port binding |
| VIII | Concurrency | Scale out via the process model |
| IX | Disposability | Maximize robustness with fast startup and graceful shutdown |
| X | Dev/prod parity | Keep development, staging, and production as similar as possible |
| XI | Logs | Treat logs as event streams |
| XII | Admin processes | Run admin/management tasks as one-off processes |

### The factors that still drive everything — unpacked

#### III. Config — store config in the environment

The most important factor, and the one most often violated. Anything that differs between environments — database URLs, API keys, feature flags, third-party credentials — belongs in environment variables or a runtime config source, **not** in committed config files.

Why: you want the same built artifact to run in dev, staging, and prod. The only thing that should change between environments is config, injected at runtime.

The modern version of this: config lives in environment variables for simple values, in mounted files for secrets and larger config, and comes from a secret manager (Vault, AWS Secrets Manager, etc.) for anything sensitive. The factor still holds; the mechanisms have evolved.

**Common violation:** different `config/packages/prod/*.yaml` files committed per environment with different values. This means you can't run the same image across environments; you have to rebuild. That breaks "build, release, run" (factor V) immediately.

#### IV. Backing services — attached resources

Databases, message brokers, caches, email providers, third-party APIs — all of these are "backing services" and should be treated as resources attached via config, not as fixed parts of the application.

The practical consequence: swapping the production database for a staging one should be a config change, not a code change. The connection string lives in an env var; the application doesn't care whether it's pointed at a local Docker container, a cloud-hosted instance, or a managed service.

**Why this matters:** if your app knows anything about *where* the database is or *how* it was set up, you've coupled the application to the infrastructure. Decoupling means you can replace backing services, migrate between providers, or use different implementations in different environments without touching application code.

#### V. Build, release, run — strict stage separation

- **Build** produces an artifact (binary, image) from source code. Deterministic, reproducible.
- **Release** combines the build with environment-specific config, producing a release that's runnable.
- **Run** executes the release.

These stages are one-way: you don't modify builds after the fact, you don't modify releases at runtime, and you don't change the running config without going through a new release.

Why: if you can edit the running app, you can't reason about its state. If you can edit builds, releases are non-reproducible. The separation is what makes rollbacks reliable — you roll back by running the previous release, not by patching the current one.

**Modern version:** container images are builds, environment-specific Kubernetes manifests (or Helm charts, or Kustomize overlays) are releases, running pods are runs. The factor maps cleanly onto container orchestration.

#### VI. Processes — stateless

The app is one or more **stateless** processes. Any state that needs to persist goes into a backing service (database, cache, object storage).

Why: stateless processes can be killed and restarted at any time, run on any host, scaled horizontally by adding more copies. Stateful processes break all of that — you can't move them, you can't scale them trivially, and you can't lose them without losing data.

**The practical test:** if your app keeps anything in local memory or on the local filesystem that needs to survive a restart, it's not stateless. File uploads written to local disk, in-memory session stores, local cache files — all violations. Move them to S3, Redis, or a database.

**PHP specifically:** FPM is inherently stateless between requests (each request gets a fresh process state), which makes PHP naturally twelve-factor-friendly for web serving. Long-running workers (Messenger consumers) need more care — the worker process is stateful, but the work it performs on each message should be stateless and idempotent.

#### IX. Disposability — fast startup, graceful shutdown

Processes should be disposable — they can be started or stopped at a moment's notice. This means:

- **Fast startup.** A pod that takes 2 minutes to start can't scale quickly, can't recover from crashes quickly, and can't be rolled cleanly. Aim for startup in seconds, not minutes.
- **Graceful shutdown.** On SIGTERM, finish the current unit of work and exit cleanly. Don't drop connections mid-request. Don't lose messages mid-processing.

Modern deployment platforms *assume* processes are disposable — autoscalers create and destroy pods, rolling deploys replace them, nodes get drained. Slow or ungraceful processes produce user-visible pain during every one of these events.

#### XI. Logs — event streams

The app should write logs to `stdout` as an unbuffered event stream. It should **not** write log files, rotate them, or ship them anywhere. The execution environment captures the stdout stream and routes it wherever logs are supposed to go (a centralized log aggregator, a stdout-reading sidecar, etc.).

Why: in a distributed, disposable-process world, the process doesn't own its log storage. It produces events; the platform handles them. This decouples logging infrastructure from application code and lets you change log destinations without touching the app.

**The consequence:** no `LOG_FILE_PATH` config, no log rotation logic, no log shipping in the application. Write to stdout as structured JSON, let Kubernetes (or Docker, or Heroku) capture it, let Fluentd/Vector/Promtail route it to wherever aggregation happens.

### The factors that have aged well

- **III, IV, V, VI, IX, XI** — still the foundation of how modern services are built and deployed. Containers and Kubernetes make them natural, almost unavoidable.

### The factors that are more nuanced now

- **I. Codebase.** "One codebase, many deploys" — but monorepos serving multiple services complicate this. The principle is still right (a deployed artifact traces to a specific commit), but the physical structure can be a monorepo with multiple services rather than one repo per service.

- **II. Dependencies.** "Declare and isolate" is now trivial with containers. The container image *is* the dependency isolation. The manifest (`composer.lock`, `package-lock.json`, etc.) is the declaration.

- **VII. Port binding.** The app binds a port and handles requests directly. Still true, but "directly" is usually through a load balancer or ingress controller that does TLS termination, request routing, rate limiting, etc. The app doesn't manage those concerns.

- **VIII. Concurrency.** "Scale out via the process model" made sense when the alternative was threads-in-one-process. Now it's usually "scale out via replicas in the orchestrator", which is the same idea at a different level.

- **X. Dev/prod parity.** Still important as a principle, but "identical" is a trap (see [docker_compose_for_local_dev.md](docker_compose_for_local_dev.md)). Aim for *semantic* parity — same service versions, same env shapes — not pixel-perfect identity.

- **XII. Admin processes.** "Run admin tasks as one-off processes" — in Kubernetes, this is Jobs. In serverless, it's a one-off function invocation. The idea holds; the mechanism has evolved.

### The factors that show their age

- **VI. Processes — stateless.** Still right for application code. But the pendulum has swung back slightly: long-running workers with in-memory state (PHP Swoole, RoadRunner, FrankenPHP worker mode) are a legitimate pattern now, *if* the state is treated as a cache, not as truth. The factor is still the right default; the strict interpretation is occasionally too strict.

- **"Many deploys" assumption.** The twelve factors assume frequent deploys. For some embedded or regulated environments where deploys are rare, not all factors map the same way. The principle of "design for change" holds; the specific mechanisms may differ.

> **Mid-level answer stops here.** A mid-level dev can recite the factors. To sound senior, speak to the principle behind each one and how it maps onto current practice ↓
>
> **Senior signal:** articulating the underlying design philosophy — that deploys are frequent, infrastructure is ephemeral, configuration is external, and applications should be composable parts of a platform.

### The unifying philosophy

Every one of the twelve factors points at the same underlying idea: **the application is a component, not a system**. It's one piece of a larger platform that handles execution, scaling, observability, configuration, and lifecycle. The app's job is to be a good component — stateless, disposable, declaratively configured, producing events not managing logs, depending on attached resources — and to leave everything else to the platform.

This is the opposite of the pre-cloud model, where the application owned its runtime, its log files, its backing services, its config, and its process lifecycle. The twelve factors are the transition from "application as kingdom" to "application as component", and the reason they still matter is that the platform-centric model they described is now the default for everything.

### What to say in an interview when asked about twelve-factor

- Don't recite all twelve. Nobody cares.
- Pick the three or four that are most load-bearing for the system you're describing (usually config in env, backing services, build/release/run, disposability) and explain them with examples.
- Acknowledge that the methodology is from 2011 and that some specifics have evolved, but the principles are still the foundation of cloud-native practice.
- Connect each factor to a concrete engineering decision: why you don't commit secrets, why logs go to stdout, why stateless workers are restartable.

### Common violations I've seen

- **Config in committed YAML files.** You can't use the same artifact across environments.
- **Logs written to local files.** Works in dev, breaks in containers.
- **Stateful local session storage.** Breaks horizontal scaling.
- **In-container cron jobs.** Violates "admin processes as one-off". Use Kubernetes CronJobs instead.
- **Slow startup.** Makes scaling slow, recovery slow, rolling deploys slow.
- **Non-graceful shutdown.** Drops requests, loses messages, corrupts data.
- **Coupling to specific backing-service implementations.** "We use Redis" in application code, not "we use a KV cache via this interface".
- **File uploads to local disk.** Breaks statelessness, breaks scaling.

### Closing

"So the Twelve-Factor App is a manifesto from 2011 that became the blueprint for cloud-native applications. The specific factors matter less than the philosophy: the app is a component in a platform, not a self-contained system. Stateless processes, external config, attached backing services, build/release/run separation, logs to stdout, fast startup, graceful shutdown. Modern practice has evolved the mechanisms — containers, Kubernetes, service meshes, managed services — but the principles are the same. If you design an app today against these twelve factors, you'll produce something that runs well on any modern platform."
