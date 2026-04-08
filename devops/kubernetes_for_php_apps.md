# Kubernetes for PHP applications

**Interview framing:**

"Running PHP on Kubernetes has a few specific patterns that are worth knowing by name because they come up in every interview and in every real deployment. The most important ones are: the nginx+FPM sidecar pattern, liveness vs readiness probes for PHP specifically, handling the 'EntityManager is closed' problem across pod restarts, running CLI workers as separate Deployments, and using an HPA tuned for FPM rather than for a long-lived server. Once you have those patterns in hand, PHP on Kubernetes is no different from any other workload."

### The pod shape: nginx sidecar + PHP-FPM

The canonical PHP web-serving pod has two containers in one pod:

1. **nginx** — receives HTTP, serves static files, forwards PHP requests to FPM.
2. **php-fpm** — runs the PHP application code.

They share a Unix socket via an `emptyDir` volume (faster than TCP) or communicate over `localhost:9000` (simpler, still fast).

Why in the same pod: they have zero-latency communication, they scale together, they die together. The FPM container has no reason to exist without nginx in front of it, and vice versa.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: billing-web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: billing-web
  template:
    metadata:
      labels:
        app: billing-web
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
          volumeMounts:
            - name: fpm-socket
              mountPath: /var/run/php
            - name: nginx-config
              mountPath: /etc/nginx/conf.d
          readinessProbe:
            httpGet:
              path: /health
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 80
            initialDelaySeconds: 30
            periodSeconds: 30

        - name: php-fpm
          image: registry.example.com/billing:v1.4.2
          volumeMounts:
            - name: fpm-socket
              mountPath: /var/run/php
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: billing-secrets
                  key: database_url
          resources:
            requests:
              cpu: "200m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "512Mi"

      volumes:
        - name: fpm-socket
          emptyDir: {}
        - name: nginx-config
          configMap:
            name: nginx-config
```

Details that matter:
- The `emptyDir` volume gives both containers a shared location for the FPM socket.
- nginx config is in a ConfigMap so it can be updated without rebuilding the image.
- Probes target nginx (the public-facing container).
- FPM has no probes directly; its health is implied by nginx's ability to talk to it.

### Liveness vs readiness for PHP

- **Readiness probe** — hits `/health` or `/ready`. Should return 200 when the app can serve real traffic: DB reachable, broker reachable, cache reachable, OPCache primed. When this fails, the pod is removed from the Service's backend list but not restarted — giving it a chance to recover without losing connections.
- **Liveness probe** — hits a simpler always-200 endpoint. Should return 200 as long as the process is responding at all. If this fails repeatedly, Kubernetes restarts the pod. Used to catch genuine deadlocks or stuck processes, not transient downstream failures.

**The mistake** is making the liveness probe check downstream dependencies. If your liveness probe returns 500 when the database is unreachable, a brief DB outage causes Kubernetes to restart every single pod — which creates a thundering herd on the DB as soon as it comes back, making the outage worse. Downstream health belongs in readiness, not liveness.

A common PHP-specific pattern:

```php
// /health — liveness
return new JsonResponse(['status' => 'ok'], 200);

// /ready — readiness
try {
    $this->dbConnection->ping();
    $this->redisClient->ping();
    return new JsonResponse(['status' => 'ready'], 200);
} catch (Throwable $e) {
    return new JsonResponse(['status' => 'not-ready', 'error' => $e->getMessage()], 503);
}
```

### CLI workers: separate Deployments, not sidecars

RabbitMQ consumers, Messenger workers, cron-like scheduled jobs — these should run in their own Deployments, not as sidecars of the FPM pod. Reasons:

- **Different scaling needs.** The web tier scales with HTTP traffic; workers scale with queue depth. They should scale independently.
- **Different lifecycles.** Web pods roll with fast probes; workers need graceful shutdown windows long enough to finish in-flight messages.
- **Different image configurations.** Workers run with different CMD and different resource profiles.
- **Isolation.** A misbehaving worker shouldn't crash the web tier.

A typical worker Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: billing-worker
spec:
  replicas: 4
  selector:
    matchLabels:
      app: billing-worker
  template:
    metadata:
      labels:
        app: billing-worker
    spec:
      terminationGracePeriodSeconds: 120  # important!
      containers:
        - name: worker
          image: registry.example.com/billing:v1.4.2
          command: ["php"]
          args:
            - bin/console
            - messenger:consume
            - async
            - --time-limit=3600
            - --memory-limit=256M
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: billing-secrets
                  key: database_url
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "256Mi"
```

**`terminationGracePeriodSeconds: 120`** is the part people forget. When Kubernetes rolls a deployment, it sends SIGTERM to pods and waits up to `terminationGracePeriodSeconds` for them to exit before SIGKILL. For a worker handling a message that takes 60 seconds, the default 30-second grace period will kill it mid-message. Set the grace period longer than your longest expected message.

Symfony Messenger handles SIGTERM correctly — it finishes the current message, then exits. Your own worker code needs to do the same: catch SIGTERM, finish the current unit of work, exit cleanly.

### Database migrations in Kubernetes

The classic problem: you deploy a new version with a database migration. Three approaches:

1. **Init container** — a migration container runs before the app container starts in each pod. Simple, but runs on every pod restart and can race between pods.
2. **Job** — a Kubernetes Job runs the migration once. Triggered as part of the deploy pipeline (via `kubectl apply -f migration-job.yaml`), blocks until complete, then the new deployment rolls out.
3. **Separate deploy phase** — CI runs the migration command as a shell-out to a pod before applying the new deployment.

Option 2 (Job) is usually the cleanest. It runs once, blocks the deploy until it succeeds, and leaves a completed Job object behind for debugging.

**Migration hazards:**
- **Non-backward-compatible migrations** — old pods still running during a rolling deploy will crash against the new schema. Always make migrations backward-compatible in one step: add columns, then ship code, then remove old columns in a later deploy.
- **Long migrations** — locking a production table for 10 minutes is a real outage. Use online DDL tools (gh-ost, pt-online-schema-change) or migrate in phases.
- **Migration failures** — you need a plan for "the migration failed halfway through". The plan should not involve panicking at 3 a.m.

### The "EntityManager is closed" problem

Doctrine's EntityManager enters a closed state when a database query fails inside a transaction. After that, every subsequent query fails until the EntityManager is reset. For web requests, this isn't a problem — the request ends, the EntityManager is thrown away, the next request gets a fresh one.

For CLI workers that process many messages, it's a serious problem. One DB hiccup during message N closes the EntityManager; messages N+1, N+2, ... all fail for the same reason — not because the database is broken, but because the worker's state is corrupted.

Fixes:
- **Catch the exception and restart the worker.** Simplest. Let Kubernetes recreate the pod. Messenger's `--time-limit` combined with a retry strategy handles this naturally.
- **Clear and reset the EntityManager.** `$entityManager->clear()` and recreate it. More complex but avoids the restart overhead.
- **Don't reuse the EntityManager across messages.** Get a fresh one per message. Heavy but bulletproof.

I usually go with option 1: let failures bubble up, let the worker exit, let Kubernetes restart the pod. It's the dumbest fix and the most reliable.

### HPA for PHP workloads

The Horizontal Pod Autoscaler scales pods based on metrics. For FPM-backed web services:

- **CPU target of 60-70%** is a reasonable default. Below that, you're wasting money; above it, you're running on the edge.
- **Set `requests` accurately** — the HPA computes utilization as `usage / request`, so bad requests make HPA decisions bad.
- **Mind the scale-up/scale-down speed.** Default scale-up is fast; default scale-down is slow (to avoid flapping). Tune `behavior` if you need different responsiveness.

For workers, CPU is a bad signal — workers are often IO-bound. Scale on **queue depth** instead via a custom metric. This requires exposing queue depth to Prometheus (many broker exporters do) and wiring it to the HPA via the custom-metrics API.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  metrics:
    - type: External
      external:
        metric:
          name: rabbitmq_queue_messages_ready
          selector:
            matchLabels:
              queue: "billing_service"
        target:
          type: AverageValue
          averageValue: "30"
```

"Keep pods scaled so that each handles on average 30 messages." When the queue grows, pods scale up. When it drains, they scale down.

### Secrets

PHP apps consume secrets via environment variables or mounted files. Kubernetes Secrets work for basic cases but they're base64-encoded, not encrypted. For anything serious:

- **External Secrets Operator** with a real secrets backend (Vault, AWS Secrets Manager, GCP Secret Manager).
- **Sealed Secrets** for gitops workflows — secrets are encrypted and committed to git.
- **Cloud-provider secret CSI drivers** that mount secrets from the provider directly into pods.

See [secrets_management.md](secrets_management.md) for the deeper view.

### ConfigMap for nginx and PHP config

nginx config, `php.ini` tweaks, and application config files that aren't secrets live in ConfigMaps mounted into the pods:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: php-config
data:
  php.ini: |
    memory_limit = 256M
    max_execution_time = 30
    upload_max_filesize = 20M
    post_max_size = 25M
  opcache.ini: |
    opcache.enable = 1
    opcache.memory_consumption = 256
    opcache.validate_timestamps = 0
    opcache.max_accelerated_files = 20000
```

```yaml
volumeMounts:
  - name: php-config
    mountPath: /usr/local/etc/php/conf.d/99-custom.ini
    subPath: opcache.ini
```

Updating the ConfigMap and the mounted file updates automatically — but PHP-FPM needs a reload to pick up ini changes, which means rolling the deployment. There's no "hot reload" for PHP config in the normal case.

### Graceful shutdown for web pods

When a web pod is being terminated:

1. Kubernetes sends `SIGTERM` to the containers.
2. Kubernetes removes the pod from the Service endpoints (there's a delay, because propagation takes time).
3. nginx stops accepting new connections but finishes in-flight ones.
4. php-fpm finishes in-flight requests.
5. After `terminationGracePeriodSeconds`, anything still running gets `SIGKILL`.

**The gotcha:** there's a race between step 2 (pod removed from Service) and step 3 (nginx stops accepting connections). During that window, new connections can arrive at a pod that's shutting down. The fix is a **preStop hook** with a short sleep, so the pod stays alive long enough for the Service update to propagate:

```yaml
lifecycle:
  preStop:
    exec:
      command: ["sh", "-c", "sleep 10"]
```

This adds 10 seconds to every pod's shutdown, but eliminates the race. Worth it for zero-error deploys.

> **Mid-level answer stops here.** A mid-level dev can describe the YAML. To sound senior, speak to the operational patterns and the PHP-specific gotchas ↓
>
> **Senior signal:** articulating why the canonical patterns exist and the failure modes they exist to prevent.

### The patterns distilled

- **Nginx sidecar + PHP-FPM** for web tier. Shared `emptyDir` for the socket.
- **Readiness probes check downstreams; liveness probes don't.** This distinction is the single most important probe-configuration mistake to avoid.
- **Workers as separate Deployments** with long grace periods and time/memory limits.
- **Migrations as Jobs**, not init containers. One-shot, blocking the deploy.
- **Backward-compatible migrations in all phases.** Never break the old pod during a rolling deploy.
- **EntityManager-is-closed → restart.** Let the pod die; Kubernetes will recreate it.
- **HPA on CPU for web, on queue depth for workers.**
- **preStop sleep** on web pods to avoid the shutdown race.
- **ConfigMaps for config, Secrets for secrets (or better, an external secrets manager).**
- **Resource requests and limits on everything.**
- **Pod disruption budgets** to prevent too many pods being rolled at once during node drains.

### Closing

"So running PHP on Kubernetes is mostly standard Kubernetes with a few PHP-specific patterns: nginx sidecar, readiness probes that check downstreams, workers as separate Deployments with long grace periods, migrations as Jobs, backward-compatible schema changes, and letting crashed workers restart via the platform rather than trying to recover in-process. Once those patterns are in place, PHP is just another workload — stateless, horizontally scalable, and observable like anything else."
