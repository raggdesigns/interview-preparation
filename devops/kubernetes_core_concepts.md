# Kubernetes core concepts

**Interview framing:**

"Kubernetes is a declarative orchestration system for containerized workloads. You describe the desired state of the cluster — 'I want 4 copies of this service running, exposed on this port, with this config' — and Kubernetes continuously works to make the cluster match. The hard part for newcomers is the sheer surface area of object types, but they all reduce to a small set of core concepts: pods, controllers, services, configuration, and storage. Everything else is a specialization of those."

### The mental model

Kubernetes is a **reconciliation loop**. You write YAML describing what you want; the control plane compares that against what's actually running; controllers make changes to close the gap. If a pod dies, the controller starts a new one. If you update a deployment's image, the controller rolls pods over to the new version. If a node goes down, workloads get rescheduled elsewhere.

Declarative, not imperative. You don't say "start this pod" — you say "this deployment should have 3 pods" and the system figures out how to get there.

### The unit of work: Pod

A pod is the smallest deployable unit. It's one or more containers that share:

- A network namespace (they can talk to each other on localhost).
- Storage volumes (they can share files).
- A lifecycle (they're scheduled together, die together).

Most pods have exactly one container. Multi-container pods are for tightly-coupled sidecars — a log shipper, a service mesh proxy, nginx in front of PHP-FPM.

**Crucial thing to internalize:** pods are *ephemeral*. They get created, scheduled to a node, run for a while, and die — replaced by new pods with different IPs. You do not ssh into a pod and fix it. You do not rely on pod IPs. You treat pods as cattle.

### Controllers that create pods

You almost never create pods directly. You create a controller, which creates pods.

**Deployment** — the workhorse. Declaratively manages a set of identical pods (replicas), handles rolling updates, supports rollback. This is what you use for stateless web services, API backends, workers. 95% of PHP workloads run under a Deployment.

**StatefulSet** — for workloads where pods have identity. Each pod gets a stable name (`mysql-0`, `mysql-1`), a stable hostname, and stable persistent storage. Used for databases, message brokers, anything where "pod 0 is the primary and pod 1 is the replica" matters. Rarely needed for application code; more common for running infrastructure inside the cluster.

**DaemonSet** — run one pod per node. Used for node-level agents: log collectors, metrics exporters, security scanners. You don't usually write these; they come with your observability stack.

**Job / CronJob** — run to completion. Used for one-off tasks (migrations, data backfills) or scheduled tasks (nightly reports, cleanup jobs).

### Services — stable addresses for unstable pods

Pods are ephemeral and their IPs change. You need a way for other pods (and external traffic) to reach them without knowing their IPs. That's what **Services** are for.

A Service defines a stable virtual IP and DNS name in the cluster, plus a selector that matches a set of pods (by label). Traffic to the service gets load-balanced across the matching pods.

**Service types:**

- **ClusterIP** (default) — the service is reachable only from inside the cluster. Used for internal communication between services.
- **NodePort** — the service is exposed on every node at a specific port. Rarely used in production.
- **LoadBalancer** — the cloud provider provisions an external load balancer and routes traffic to the service. Used for services exposed to the internet.
- **ExternalName** — a DNS alias to an external service outside the cluster. Used for legacy or third-party integrations.

For most web apps you combine Deployment + Service + Ingress:

- Deployment runs the pods.
- ClusterIP Service gives them a stable internal address.
- Ingress routes external HTTP traffic to the service based on hostname or path.

### Ingress — HTTP routing

**Ingress** is a declarative HTTP(S) router. You define rules: "traffic for `api.example.com` goes to service `api-backend`; traffic for `example.com/docs` goes to service `docs`". An Ingress controller (nginx, Traefik, Contour, etc., running in the cluster) reads the Ingress objects and configures itself to route accordingly.

Ingress handles:

- Hostname-based routing.
- Path-based routing.
- TLS termination (with cert-manager for automatic Let's Encrypt certs).
- Sometimes rate limiting, auth, rewrites depending on the controller.

The alternative is exposing every service as a LoadBalancer, which gets expensive fast (one cloud LB per service). Ingress is the right default for HTTP-shaped traffic.

### Configuration: ConfigMap and Secret

**ConfigMap** — key-value store for non-sensitive configuration. Mounted into pods as environment variables or files.

**Secret** — same shape as ConfigMap but meant for sensitive data (passwords, tokens, certificates). Stored base64-encoded in etcd by default, which is not encryption — secrets are only "secret" in the sense that they're a separate object with access control. For real security you enable encryption at rest and use a proper secrets manager (see [secrets_management.md](secrets_management.md)).

Both are injected into pods either as:

- **Environment variables** — simple but limited (size, character set, live update).
- **Mounted files** — more flexible, supports large data, and updates live when the ConfigMap/Secret changes (with a delay).

### Storage: Volumes, PersistentVolumes, PersistentVolumeClaims

Containers are ephemeral. If you want data to survive a pod restart, you need a volume.

- **Volume** — storage attached to a pod. Many types: `emptyDir` (scratch space shared between containers in the pod), `configMap`, `secret`, `persistentVolumeClaim`, etc.
- **PersistentVolume (PV)** — a cluster-level resource representing a piece of actual storage (a cloud disk, an NFS share, etc.).
- **PersistentVolumeClaim (PVC)** — a pod-level request for storage. "I need 10 GB of fast SSD." The cluster binds it to a matching PV, or provisions one dynamically via a StorageClass.

For stateless PHP apps, you rarely touch persistent storage — the database is on a managed service, uploads go to S3-compatible object storage. PVs come in for databases running in the cluster, which you should think carefully about before doing.

### Namespaces

A **Namespace** is a logical partition of the cluster. Objects in different namespaces don't collide. Namespaces are used for:

- **Environment separation** — `dev`, `staging`, `prod` in the same cluster.
- **Team separation** — each team owns a namespace.
- **Application separation** — `frontend`, `backend`, `infra` in separate namespaces.

Resource quotas, network policies, and RBAC are all applied at the namespace level.

**`default` namespace** — where things go when you don't specify one. Never put real workloads in `default`. It's a foot-gun.

### Labels and selectors — the glue

Labels are key-value metadata attached to objects. Selectors are queries against labels. This is how Kubernetes objects relate to each other without hard-coded references.

- A Deployment creates pods with label `app=billing`.
- A Service has a selector `app=billing`.
- The Service automatically routes to whatever pods match — no pod IPs, no static lists.

This indirection is what makes the system composable. Replace a Deployment with a new one that produces pods with the same label; the Service starts routing to the new pods automatically.

### Health checks: liveness, readiness, startup

Three probes, and getting the distinction right is a common interview question:

- **Liveness probe** — "is this pod still alive?" If the probe fails, Kubernetes **restarts** the pod. Used to recover from deadlocks or corrupted state.
- **Readiness probe** — "is this pod ready to serve traffic?" If the probe fails, Kubernetes **removes the pod from the Service load balancer** but doesn't restart it. Used during startup or when the pod needs to briefly stop serving (e.g. during maintenance).
- **Startup probe** — "has the pod finished starting?" Useful for slow-starting apps — liveness and readiness probes are disabled until the startup probe passes.

The common mistake is using a liveness probe for something that's actually a readiness concern. A slow database connection is not a reason to restart the pod; it's a reason to pause traffic until the connection comes back. Restart-on-failure liveness probes can turn a transient issue into a restart loop.

For PHP: `/health` (always-200 endpoint) for liveness, `/ready` (200 only when DB and broker are reachable) for readiness.

### Resource requests and limits

Every container should have **requests** (guaranteed resources) and **limits** (hard caps).

- **Requests** affect scheduling. The scheduler finds a node with enough spare capacity to match the request.
- **Limits** affect runtime. CPU over the limit is throttled; memory over the limit is OOM-killed.

Common mistake: no requests or limits set, pod gets scheduled on an overloaded node, performance tanks or it gets killed under memory pressure from noisy neighbors. Always set them.

Common mistake part 2: setting requests equal to limits on CPU. This gives you "guaranteed" quality of service but also locks you into strict throttling. For CPU, requests lower than limits is usually the right shape.

### Horizontal Pod Autoscaler (HPA)

HPA automatically scales the number of pods based on observed metrics — usually CPU, memory, or a custom metric like queue depth.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef:
    kind: Deployment
    name: billing-service
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

Scales the deployment between 2 and 20 pods to keep CPU around 70%. Requires resource requests to be set (the HPA uses the request as the baseline for "utilization").

### Namespaces I actually use

In a typical setup:

- `kube-system` — Kubernetes's own components. Don't touch.
- `ingress-nginx` (or similar) — the Ingress controller.
- `cert-manager` — TLS cert automation.
- `monitoring` — Prometheus, Grafana, exporters.
- `app-dev`, `app-staging`, `app-prod` — the application, per environment.

One cluster can host multiple environments with namespace separation, or you can run separate clusters for stronger isolation. Separate clusters is safer for dev/prod boundaries; shared clusters are cheaper and have less operational overhead.

> **Mid-level answer stops here.** A mid-level dev can list the resources. To sound senior, speak to the operational concerns and the failure modes ↓
>
> **Senior signal:** understanding that Kubernetes is a tool with trade-offs, and knowing when it's the right answer and when it's overkill.

### When Kubernetes is worth it

- Multiple services that need orchestration, scaling, and resilience.
- Team has operational capacity to learn and run it (or a managed service like EKS/GKE/AKS).
- You need rolling deploys, self-healing, and horizontal scaling.
- You're already paying the complexity tax for other reasons (microservices, many environments).

### When Kubernetes is overkill

- Single-service applications.
- Small teams without platform expertise.
- Workloads that fit on one or two machines and rarely need to scale.
- Cases where a PaaS (Heroku, Render, Fly.io, Railway) handles everything you need.

Kubernetes is powerful and expensive. The expense is not just money — it's the operational cognitive load of running the platform, the YAML that proliferates, the moving parts you have to understand to debug anything. Pick it when the power justifies the cost.

### Common mistakes

- **No resource requests or limits.** Pods get scheduled anywhere, compete for resources, performance is unpredictable.
- **Liveness probes that are actually readiness concerns.** Causes restart loops under load.
- **Relying on pod IPs.** Never works; pods are ephemeral. Use services.
- **Putting secrets in ConfigMaps.** Not encrypted, not access-controlled the same way. Use Secrets (or better, an external secrets manager).
- **No namespace separation.** Everything in `default`, no RBAC, no quotas, no isolation.
- **Storing state in pod filesystems.** Gone on restart. Use volumes or external storage.
- **Using `latest` image tags.** Deploys don't actually pull a new image unless you change the tag. Pin to digests or semantic version tags.
- **No rolling update strategy defined.** Defaults are sensible but you should explicitly configure `maxSurge` and `maxUnavailable` for your risk tolerance.

### Closing

"So the core concepts are: pods (the unit of work), controllers like Deployment and StatefulSet (that manage pods), Services (stable addresses), Ingress (HTTP routing), ConfigMap and Secret (configuration), volumes and PVCs (storage), and namespaces (partitioning). Everything else is a composition of these. Labels and selectors are the glue. Requests and limits are non-negotiable. And the meta-principle is: Kubernetes is declarative — you describe what you want, controllers reconcile toward it, and you never imperatively mutate live state."
