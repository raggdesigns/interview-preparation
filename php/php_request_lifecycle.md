# PHP request lifecycle

**Interview framing:**

"The PHP request lifecycle is what makes PHP fundamentally different from Node, Go, or Java in how it handles concurrency and state. A PHP-FPM request starts from nothing, bootstraps the entire application, handles one request, tears everything down, and returns the memory. No state survives between requests — no object graphs, no connection pools, no caches in memory. This 'shared-nothing' model is both PHP's biggest weakness (startup cost on every request) and its biggest strength (no memory leaks, no concurrency bugs, no stale state). The conversation gets interesting when you contrast FPM's lifecycle with CLI workers and the newer long-lived runtimes like RoadRunner and FrankenPHP."

### The FPM request lifecycle

```text
1. Web server (nginx) receives HTTP request
2. Passes to PHP-FPM via FastCGI
3. FPM master assigns request to a worker process
4. Worker initializes PHP runtime:
   - Load php.ini settings
   - Load compiled OPCache bytecode (no re-parsing if warm)
   - Execute auto_prepend_file (if configured)
5. Execute the entry point (index.php)
   - Composer autoloader registers
   - Framework bootstraps (DI container, routing, config)
   - Router matches request → controller
   - Controller runs business logic
   - Response is generated
6. Response sent back through FPM → nginx → client
7. Worker tears down:
   - Object destructors run
   - Memory is freed (everything)
   - Session data is written
   - Database connections are closed (unless persistent)
8. Worker is ready for the next request
```

**Key property:** steps 4-7 happen for *every single request*. The worker starts fresh each time. No state from request N is visible to request N+1 (with the explicit exception of OPCache, APCu, and persistent connections).

### What survives between requests

Almost nothing, by design. The exceptions:

- **OPCache** — compiled bytecode is cached in shared memory. Files are parsed and compiled once; subsequent requests use the cached bytecode. This is the single biggest performance optimization in PHP — 3-10x throughput improvement.
- **APCu** — user-data cache in shared memory. Explicit opt-in. Survives across requests within the same worker pool.
- **Persistent database connections** — `PDO::ATTR_PERSISTENT`. The connection stays open across requests. Use cautiously — connection state (transactions, session variables) can leak between requests.
- **Preloading** (PHP 7.4+) — classes and functions loaded into OPCache at startup, available to every request without autoloading. Reduces autoloader overhead.

Everything else — objects, variables, file handles, database query results, computed values — is gone after each request.

### Why shared-nothing matters

**Advantages:**

- **No memory leaks in the traditional sense.** Memory is freed after every request. A leak can't compound across requests.
- **No concurrency bugs.** Each request runs in isolation. No race conditions, no shared mutable state, no locks needed within application code.
- **Predictable resource usage.** Peak memory is bounded per request by `memory_limit`. No unbounded growth.
- **Simple mental model.** Each request is a complete, independent program execution.
- **Horizontal scaling is trivial.** Add more workers. No shared state to coordinate.

**Disadvantages:**

- **Bootstrap cost on every request.** Framework initialization (DI container, config parsing, route compilation) runs every time. OPCache and preloading mitigate this significantly but don't eliminate it.
- **No in-process caching.** You can't keep a frequently-accessed dataset in a PHP variable across requests (without APCu or Redis).
- **Connection establishment per request.** Database connections are opened and closed per request unless you use persistent connections or an external pool (PgBouncer).
- **Can't hold long-lived connections.** WebSockets, SSE, gRPC streaming — all require a process that stays alive, which FPM doesn't do.

### The CLI lifecycle — long-running workers

PHP CLI processes (Messenger consumers, cron jobs, custom daemons) have a different lifecycle:

```text
1. Process starts
2. Bootstrap once (autoloader, DI, config)
3. Loop:
   a. Receive a message / wait for work
   b. Process the message
   c. (state persists between iterations)
4. Exit (on time limit, memory limit, or signal)
```

**State persists between messages.** This is the fundamental difference from FPM. The DI container, database connections, cached objects — all survive between messages. This is both the advantage (no bootstrap cost per message) and the risk (memory leaks, stale connections, corrupted EntityManagers).

**The operational patterns for CLI workers:**

- **Time limit** — exit after N seconds, let Supervisor restart. Prevents slow state accumulation.
- **Memory limit** — exit when memory exceeds a threshold. Prevents leaks from compounding.
- **EntityManager reset** — clear the EntityManager between messages to prevent stale identity maps.
- **Connection health checks** — ping the database before using a connection that may have been idle for hours.

See [../devops/kubernetes_for_php_apps.md](../devops/kubernetes_for_php_apps.md) for the Kubernetes-specific patterns.

### The modern alternatives — RoadRunner, FrankenPHP, Swoole

These runtimes keep the PHP application resident in memory between requests, similar to how Node.js or Go work:

**RoadRunner** — a Go-based HTTP server that boots PHP workers once and sends requests to them via a binary protocol. The worker stays alive; the application framework bootstraps once.

**FrankenPHP** — built on Caddy, supports "worker mode" where the application stays in memory between requests.

**Swoole / OpenSwoole** — a PHP extension that provides an async, event-driven server with coroutines.

**The lifecycle:**

```text
1. Worker starts
2. Bootstrap once (autoloader, DI, config, routing)
3. Loop:
   a. Receive HTTP request
   b. Process request using pre-bootstrapped application
   c. Send response
   d. Reset request-specific state (but NOT the application bootstrap)
4. Worker lives for hours/days
```

**Advantages over FPM:**

- **5-10x throughput improvement** on framework-heavy applications. The bootstrap cost (DI container, config, routing) is paid once.
- **In-process caching.** A PHP variable persists across requests. No Redis round-trip for hot data.
- **WebSocket and SSE support.** The process is long-lived, so persistent connections work.

**Risks:**

- **Memory leaks matter.** In FPM, a leak is invisible (memory is freed after each request). In a long-lived runtime, a leak compounds over thousands of requests.
- **Static state pollution.** A singleton set during request A is still set during request B. If it contains request-specific data (user ID, locale, auth context), request B sees request A's data. This is the #1 bug class in long-lived PHP.
- **Framework compatibility.** Not all Symfony/Laravel services are designed for long-lived contexts. Some assume fresh state per request. The community is adapting but it's not 100%.
- **Harder debugging.** State from previous requests interfering with the current one is subtle and hard to reproduce.

**The discipline for long-lived runtimes:**

- Clear all request-scoped state between requests. The runtime or framework must reset.
- Test for static-state leaks explicitly.
- Monitor memory growth over time (soak testing).
- Use the same time/memory limits as CLI workers, even though they shouldn't be needed. Belt and suspenders.

### The interview summary

"FPM: shared-nothing, fresh state per request, no leaks, no concurrency bugs, bootstrap cost per request. CLI workers: state persists between messages, need time/memory limits and state management. Modern runtimes (RoadRunner, FrankenPHP): application stays in memory, massive throughput gains, but you take on the risk of memory leaks and static-state pollution. The choice depends on the performance requirements and the team's ability to manage long-lived state safely."

> **Mid-level answer stops here.** A mid-level dev can describe FPM vs CLI. To sound senior, articulate the trade-offs of long-lived runtimes and the specific failure modes they introduce ↓
>
> **Senior signal:** knowing that FPM's "weakness" (per-request bootstrap) is also its safety model, and that modern runtimes trade that safety for performance.

### Closing

"So PHP's request lifecycle is the shared-nothing model: everything starts fresh, runs once, gets torn down. OPCache makes it fast; the model makes it safe. CLI workers break that model for good reasons (persistent processing) and need operational guardrails. Modern runtimes like RoadRunner and FrankenPHP break it further (persistent application bootstrap) for performance, but reintroduce the state-management problems that PHP's design originally avoided. The senior skill is knowing which lifecycle fits the workload and how to manage the risks of each."
