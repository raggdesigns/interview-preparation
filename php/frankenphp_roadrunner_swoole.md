# FrankenPHP, RoadRunner, Swoole

**Interview framing:**

"FrankenPHP, RoadRunner, and Swoole are three alternatives to PHP-FPM that keep the application in memory between requests. They all solve the same problem — the per-request bootstrap cost of FPM — but with different architectures. RoadRunner is a Go process that manages PHP workers via a binary protocol. FrankenPHP is built on top of Caddy and embeds PHP directly. Swoole is a PHP extension that provides an async, event-driven runtime with coroutines. The senior insight is that all three trade simplicity and safety for performance, and the right choice depends on how much of that trade-off the team can handle."

### The problem they solve

PHP-FPM bootstraps the entire application on every request: autoloader, DI container, config, routing, middleware. For a Symfony application, this bootstrap takes 5-20ms even with OPCache. Multiply by thousands of requests per second and the bootstrap alone is a significant fraction of server time.

These runtimes solve this by bootstrapping once and keeping the application resident in memory. The DI container, routing table, config, and compiled templates stay loaded. Each request only runs the request-specific logic — controller + business logic + response — without re-bootstrapping.

The throughput improvement is typically **3-10x** over FPM for framework-heavy applications.

### RoadRunner

**What it is:** a Go application server that manages PHP worker processes. RoadRunner starts PHP workers, sends HTTP requests to them via a binary protocol, and receives responses. Workers stay alive between requests.

**Architecture:**

```text
Client → RoadRunner (Go) → PHP Worker Pool
              │                  │
              │            Worker 1 (PHP, resident)
              │            Worker 2 (PHP, resident)
              │            Worker N (PHP, resident)
              │
         HTTP/gRPC/TCP
         Load balancing
         Static files
         TLS
```

**How a worker looks:**

```php
use Spiral\RoadRunner\Http\PSR7Worker;
use Spiral\RoadRunner\Worker;

$worker = Worker::create();
$psrWorker = new PSR7Worker($worker, /* PSR-17 factories */);

// Bootstrap once
$app = new MyApplication();
$app->boot();

while ($request = $psrWorker->waitRequest()) {
    try {
        $response = $app->handle($request);
        $psrWorker->respond($response);
    } catch (Throwable $e) {
        $psrWorker->respond(new Response(500));
    } finally {
        // Reset request-scoped state
        $app->resetState();
    }
}
```

The `while` loop is the key: the application boots once, then handles many requests in a loop. Each iteration receives a PSR-7 request and returns a PSR-7 response.

**Key features:**

- Go handles HTTP/TLS/static files (no nginx needed).
- Workers are managed by RoadRunner — auto-restart on crash, configurable pool size.
- Supports HTTP, gRPC, message queues (jobs), WebSockets, TCP, and more.
- Symfony integration via `baldinof/roadrunner-bundle`. Laravel via `spiral/roadrunner-laravel`.
- PSR-7 native — standard request/response interfaces.

**Pros:**

- Massive throughput improvement over FPM.
- Single binary (Go) for the server — no nginx, no FPM config.
- Rich plugin system — gRPC, jobs, KV store, metrics, service discovery built in.
- Good Symfony/Laravel integration.

**Cons:**

- Must manage state between requests. Static pollution, EntityManager leaks, etc.
- Not all PHP libraries are "worker-safe" — some assume per-request lifecycle.
- Debugging is harder — crashes in the worker loop affect subsequent requests.
- Additional operational complexity vs FPM.

### FrankenPHP

**What it is:** a modern PHP application server built on Caddy (Go). FrankenPHP embeds PHP directly into the Caddy process (via CGO), eliminating the inter-process communication overhead.

**Architecture:**

```text
Client → FrankenPHP (Caddy + embedded PHP)
              │
         Worker Mode: PHP stays in memory
         or
         Classic Mode: behaves like FPM
```

**Worker mode** is the interesting part — the application stays resident, similar to RoadRunner but with even lower overhead because PHP runs in-process with the web server.

**Key features:**

- Built on Caddy — automatic HTTPS, HTTP/2, HTTP/3, Zstandard compression.
- Worker mode for resident applications.
- Native support for Symfony (via `symfony/runtime` component with FrankenPHP runtime).
- Early-hints (HTTP 103) support for faster page loads.
- Single binary deployment.
- Docker image available (`dunglas/frankenphp`).

**Pros:**

- Lowest-overhead option (in-process, no IPC).
- Modern HTTP features (HTTP/3, early hints).
- Caddy's automatic HTTPS with Let's Encrypt.
- Actively developed by the Symfony community (Kevin Dunglas).
- Simplest deployment model — one binary does everything.

**Cons:**

- Newer than RoadRunner — smaller community, fewer battle-tested production deployments.
- Same state-management challenges as any resident runtime.
- CGO dependency ties PHP to the Go process — a PHP segfault crashes the server.
- Extension compatibility can vary (some PHP extensions don't work well in embedded mode).

### Swoole / OpenSwoole

**What it is:** a PHP extension (written in C) that replaces PHP's execution model entirely. Swoole provides an event loop, coroutines, async I/O, and a built-in HTTP server. It's the most radical departure from traditional PHP.

**Architecture:**

```text
Client → Swoole HTTP Server (PHP extension)
              │
         Event Loop (libuv-like)
         Coroutines for concurrent I/O
         Worker processes managed by Swoole
```

**Key features:**

- **Coroutines** — cooperative multitasking within a single process. Multiple requests can be in-flight concurrently, yielding during I/O (database queries, HTTP calls).
- **Async I/O** — database, Redis, HTTP, filesystem — all non-blocking.
- **Built-in servers** — HTTP, WebSocket, TCP, UDP.
- **Connection pooling** — Swoole manages database and Redis connection pools natively.
- **Timers, channels, wait groups** — Go-like concurrency primitives.

**The coroutine model:**

```php
$server = new Swoole\HTTP\Server("0.0.0.0", 9501);

$server->on("request", function ($request, $response) {
    // This coroutine can yield during I/O
    $db = new Swoole\Coroutine\MySQL();
    $db->connect([...]);
    $result = $db->query("SELECT * FROM users WHERE id = 1");
    // While waiting for the query, other coroutines run

    $response->end(json_encode($result));
});

$server->start();
```

While one request is waiting for a database query, other requests are being processed. This is the same model as Node.js or Go — but in PHP.

**Pros:**

- Highest potential throughput of the three.
- True concurrent I/O within a single process.
- Built-in connection pooling.
- WebSocket and TCP server support.
- Can handle thousands of concurrent connections efficiently.

**Cons:**

- **Most disruptive to existing code.** Coroutines change how PHP code executes. Blocking calls block the entire worker. Libraries must use Swoole-compatible I/O.
- **Extension compatibility.** Not all PHP extensions work with coroutines. PDO works (with the coroutine wrapper), but some C extensions don't yield properly.
- **Framework support varies.** Laravel has Octane (which supports Swoole), Symfony has less mature support.
- **Debugging complexity.** Coroutine-based bugs (deadlocks, race conditions) are new to most PHP developers.
- **OpenSwoole vs Swoole split.** Two competing forks with diverging APIs.

### Comparison table

| | FPM | RoadRunner | FrankenPHP | Swoole |
|---|---|---|---|---|
| Architecture | Process per request | Go + PHP workers | Caddy + embedded PHP | PHP extension |
| Bootstrap | Per request | Once | Once | Once |
| Concurrency model | Process isolation | Process pool | Process pool / worker | Coroutines |
| HTTP server | Nginx required | Built-in (Go) | Built-in (Caddy) | Built-in (C) |
| Throughput vs FPM | 1x | 3-5x | 3-8x | 5-10x |
| State management risk | None | Medium | Medium | High |
| Framework support | Universal | Good (Symfony, Laravel) | Good (Symfony) | Moderate (Laravel Octane) |
| Maturity | Decades | ~5 years | ~2 years | ~6 years |
| Debugging difficulty | Easy | Medium | Medium | Hard |

### How to choose

```text
Do you need maximum simplicity and safety?
├── Yes → FPM. It's battle-tested and the ecosystem assumes it.
└── No → Is throughput a measured bottleneck?
         ├── No → FPM. Don't optimize what isn't slow.
         └── Yes → Do you need coroutines / async I/O?
                  ├── Yes → Swoole (if you can handle the complexity).
                  └── No → RoadRunner or FrankenPHP.
                           ├── Prefer maturity → RoadRunner.
                           └── Prefer modern features / simplicity → FrankenPHP.
```

**The honest default:** FPM until you've measured that bootstrap is a real bottleneck. Then RoadRunner or FrankenPHP. Swoole only when you need true async I/O and the team is prepared for the paradigm shift.

### The state-management discipline (applies to all three)

All resident runtimes share the same state-management risks:

1. **Clear the Doctrine EntityManager between requests.** The identity map accumulates.
2. **Reset request-scoped services.** Anything that stores per-request state (auth context, locale, request ID) must be reset.
3. **Avoid static variables that accumulate.** Static caches, counters, buffers.
4. **Test for state leaks.** Run the same request twice in a row; if the second behaves differently, state leaked.
5. **Monitor memory.** Leaks that are invisible in FPM compound over thousands of requests.
6. **Time-limit workers.** Even in resident runtimes, periodic restarts are healthy.

> **Mid-level answer stops here.** A mid-level dev can list the alternatives. To sound senior, speak to the decision framework and the specific risks of each ↓
>
> **Senior signal:** knowing that the performance gain comes with a safety trade-off, and being specific about what that trade-off looks like in production.

### Closing

"So RoadRunner, FrankenPHP, and Swoole are three ways to keep PHP resident in memory between requests, avoiding per-request bootstrap. RoadRunner is the mature choice with a Go server managing PHP workers. FrankenPHP is the modern choice built on Caddy with the lowest overhead. Swoole is the radical choice with coroutines and async I/O. All three require state-management discipline that FPM doesn't. The default should still be FPM until you've measured that bootstrap is a bottleneck, and the choice between the three depends on throughput needs, framework compatibility, and the team's appetite for complexity."
