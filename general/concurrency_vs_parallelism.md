# Concurrency vs Parallelism

Concurrency and parallelism both deal with multiple tasks, but they solve different problems. Understanding the distinction — and how PHP handles each — is a recurring interview question.

> **Scenario used throughout this document:** A web application that must fetch data from three external APIs and resize uploaded images.

## Prerequisites

- [How the Internet Works](how_internet_works.md) — network request lifecycle
- [PHP-FPM](../highload/php_fpm.md) — how PHP handles concurrent requests

## Core Idea

```text
Concurrency (one cook, many dishes):
  ┌──────────────────────────────────────────────────┐
  │  Task A ████░░░░████░░░░████                     │
  │  Task B     ████░░░░████░░░░████                 │
  │  Task C         ████░░░░████░░░░████             │
  │         ─────────────────────────────→ time       │
  │  One thread switches between tasks               │
  │  (e.g., while Task A waits for I/O, work on B)   │
  └──────────────────────────────────────────────────┘

Parallelism (three cooks, three dishes):
  ┌──────────────────────────────────────────────────┐
  │  Core 1: Task A ████████████████████             │
  │  Core 2: Task B ████████████████████             │
  │  Core 3: Task C ████████████████████             │
  │          ─────────────────────────────→ time      │
  │  Multiple threads/processes run simultaneously   │
  └──────────────────────────────────────────────────┘
```

| Aspect | Concurrency | Parallelism |
|--------|-------------|-------------|
| Definition | Dealing with multiple tasks at once | Executing multiple tasks at once |
| Focus | Structure (how you organize work) | Execution (how you run work) |
| Requires | One CPU core is enough | Multiple CPU cores |
| Best for | I/O-bound tasks (network, disk, DB) | CPU-bound tasks (math, image processing) |
| PHP tools | Fibers, ReactPHP, AMPHP | pcntl_fork, parallel extension |

## Concurrency in PHP

### PHP Fibers (PHP 8.1+)

Fibers allow a function to **suspend** execution and yield control back to the caller. This enables cooperative multitasking within a single thread.

```php
<?php

function fetchFromApi(string $url): Fiber
{
    return new Fiber(function () use ($url): string {
        echo "Starting request to {$url}\n";

        // Simulate async I/O — in real code, this is where
        // an event loop would handle the actual HTTP request
        Fiber::suspend('waiting');

        echo "Completed request to {$url}\n";
        return "Response from {$url}";
    });
}

// Create fibers for three API calls
$fibers = [
    fetchFromApi('https://api.shop.com/products'),
    fetchFromApi('https://api.shop.com/categories'),
    fetchFromApi('https://api.shop.com/inventory'),
];

// Start all fibers (each runs until it suspends)
foreach ($fibers as $fiber) {
    $fiber->start();
}

// Resume all fibers (simulating I/O completion)
$results = [];
foreach ($fibers as $fiber) {
    $results[] = $fiber->resume();
}

// All three requests completed concurrently on ONE thread
```

### ReactPHP Event Loop (Real-World Concurrency)

ReactPHP provides a proper event loop for non-blocking I/O — this is what you'd use in production for concurrent HTTP requests.

```php
<?php

use React\EventLoop\Loop;
use React\Http\Browser;

$browser = new Browser();

// Fire all three requests concurrently
$promises = [
    $browser->get('https://api.shop.com/products'),
    $browser->get('https://api.shop.com/categories'),
    $browser->get('https://api.shop.com/inventory'),
];

// Wait for all to complete
React\Promise\all($promises)->then(function (array $responses): void {
    foreach ($responses as $response) {
        echo $response->getBody() . "\n";
    }
    echo "All 3 requests completed concurrently on a single thread\n";
});
```

**Key point:** Only one thread is used. While waiting for the network response from API #1, the event loop starts request #2, then #3. When responses arrive, callbacks execute.

## Parallelism in PHP

### pcntl_fork (Process-Level Parallelism)

For CPU-bound work, you need multiple processes running on separate CPU cores.

```php
<?php

// Resize 4 images in parallel using 4 child processes
$images = ['photo1.jpg', 'photo2.jpg', 'photo3.jpg', 'photo4.jpg'];
$pids = [];

foreach ($images as $image) {
    $pid = pcntl_fork();

    if ($pid === -1) {
        throw new RuntimeException('Failed to fork');
    }

    if ($pid === 0) {
        // Child process — runs on a separate CPU core
        $start = microtime(true);
        resizeImage($image, 800, 600); // CPU-intensive work
        $elapsed = round(microtime(true) - $start, 2);
        echo "[PID " . getmypid() . "] Resized {$image} in {$elapsed}s\n";
        exit(0); // Child must exit
    }

    $pids[] = $pid; // Parent tracks child PIDs
}

// Parent waits for all children to finish
foreach ($pids as $pid) {
    pcntl_waitpid($pid, $status);
}

echo "All 4 images resized in parallel\n";

function resizeImage(string $path, int $width, int $height): void
{
    $image = imagecreatefromjpeg($path);
    $resized = imagescale($image, $width, $height);
    imagejpeg($resized, "resized_{$path}");
    imagedestroy($image);
    imagedestroy($resized);
}
```

**Output on a 4-core machine:**

```text
[PID 1234] Resized photo1.jpg in 1.2s   (Core 1)
[PID 1235] Resized photo2.jpg in 1.1s   (Core 2)
[PID 1236] Resized photo3.jpg in 1.3s   (Core 3)
[PID 1237] Resized photo4.jpg in 1.2s   (Core 4)
All 4 images resized in parallel

Total: ~1.3s (vs ~4.8s sequentially)
```

## Comparison: Same Problem, Different Approaches

```text
Task: Fetch 3 API responses + resize 4 images

Sequential (no concurrency, no parallelism):
  API1 ──── API2 ──── API3 ──── IMG1 ──── IMG2 ──── IMG3 ──── IMG4
  Total: ~7 seconds

Concurrent only (single thread, event loop):
  API1 ─┐
  API2 ─┼── wait ── all done ── IMG1 ── IMG2 ── IMG3 ── IMG4
  API3 ─┘
  Total: ~5 seconds (APIs overlap, images still sequential)

Parallel only (multiple processes):
  Process 1: API1 ── IMG1
  Process 2: API2 ── IMG2
  Process 3: API3 ── IMG3
  Process 4:         IMG4
  Total: ~2 seconds (but wastes CPU during I/O waits)

Both (event loop + forked workers):
  Main process (concurrent I/O):
    API1 ─┐
    API2 ─┼── all done in ~1s
    API3 ─┘
  Forked workers (parallel CPU):
    Core 1: IMG1 ─┐
    Core 2: IMG2 ─┼── all done in ~1.3s
    Core 3: IMG3 ─┤
    Core 4: IMG4 ─┘
  Total: ~2.3s (optimal)
```

## How PHP-FPM Provides Concurrency

PHP itself is single-threaded, but **PHP-FPM** achieves concurrency at the process level:

```text
Nginx receives 100 simultaneous requests
  │
  ▼
PHP-FPM pool (pm.max_children = 50)
  │
  ├── Worker 1:  handles request #1  (each worker is a separate process)
  ├── Worker 2:  handles request #2
  ├── Worker 3:  handles request #3
  │   ...
  ├── Worker 50: handles request #50
  │
  └── Requests 51-100 wait in queue until a worker is free

Each worker runs one request at a time (no shared state = no race conditions).
This is concurrency through multiple processes, not threads.
```

This is why PHP is often called "shared-nothing architecture" — each request is isolated in its own process.

## Common Interview Questions

### Q: Explain the difference between concurrency and parallelism

**A:** **Concurrency** is about structure — organizing a program to handle multiple tasks by interleaving their execution. A single core can achieve concurrency by switching between tasks (e.g., while waiting for a database response, start another HTTP request). **Parallelism** is about execution — literally running multiple tasks at the same time on multiple CPU cores. You can have concurrency without parallelism (one core switching between tasks) and parallelism without concurrency (multiple cores each running one independent task).

### Q: When would you use concurrency vs parallelism?

**A:** Use **concurrency** for I/O-bound tasks where the bottleneck is waiting for external systems (network requests, database queries, file reads). Use **parallelism** for CPU-bound tasks where the bottleneck is computation (image processing, data transformation, encryption). In practice, high-performance applications use both: an event loop for concurrent I/O and worker processes for parallel CPU work.

### Q: How does PHP achieve concurrency if it's single-threaded?

**A:** At the **language level**, PHP 8.1 Fibers and libraries like ReactPHP provide cooperative concurrency within a single process using event loops. At the **infrastructure level**, PHP-FPM runs a pool of worker processes — each handles one request, but many workers run simultaneously, achieving concurrency through multiple processes rather than threads. This "shared-nothing" model avoids race conditions but means workers can't share in-memory state.

### Q: What are race conditions and how does PHP avoid them?

**A:** A race condition occurs when two threads access shared mutable state simultaneously, causing unpredictable results. PHP largely avoids this because each FPM worker is a separate process with its own memory — there's nothing shared to race on. However, race conditions can still occur at the **database level** (two requests updating the same row) or with shared resources like files and cache. These are solved with locks, transactions, and atomic operations, not PHP language features.

## Conclusion

Concurrency (structure) and parallelism (execution) solve different bottlenecks. PHP handles I/O concurrency through Fibers and ReactPHP, CPU parallelism through pcntl_fork and the parallel extension, and request-level concurrency through PHP-FPM's process pool. The "shared-nothing" model trades memory efficiency for simplicity — no threads means no race conditions within a single request.

## See Also

- [PHP-FPM](../highload/php_fpm.md) — process pool management
- [Async JavaScript](../javascript/async_javascript.md) — event loop in another language
- [Optimizing Slow GET Endpoints](../highload/optimizing_slow_get_endpoint.md) — practical performance optimization
