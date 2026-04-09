# PHP memory management

**Interview framing:**

"PHP's memory management is built around the assumption that memory is allocated per-request and freed completely when the request ends. The internal engine uses reference counting with a cycle collector for garbage collection, copy-on-write for efficient variable passing, and a fixed memory limit per process. Understanding how PHP actually allocates and frees memory — zvals, refcounting, copy-on-write, circular references — is what lets you debug memory issues in production: 'why does this request OOM at 256MB?', 'why does my worker leak 1MB per message?', 'why does this array use 10x more memory than the data size?'"

### Zvals — the variable container

Every PHP variable is stored in a **zval** (Zend value). A zval contains:

- **Type tag** — integer, string, array, object, etc.
- **Value** — the actual data (or a pointer to it for complex types).
- **Reference count** — how many variables point to this value.
- **GC info** — flags for the garbage collector.

Simple types (int, float, bool, null) are stored directly in the zval. Complex types (strings, arrays, objects) are heap-allocated and the zval holds a pointer.

### Reference counting

When you assign a variable, PHP doesn't copy the data — it increments the reference count on the underlying value:

```php
$a = "hello";    // refcount = 1
$b = $a;          // refcount = 2 (both point to the same string)
unset($a);        // refcount = 1
unset($b);        // refcount = 0 → memory freed
```

When the reference count drops to zero, the memory is freed immediately — no garbage collector needed. This handles ~95% of PHP's memory management.

### Copy-on-write (COW)

When you assign a variable, PHP shares the underlying data. It only copies when one of the variables is *modified*:

```php
$a = [1, 2, 3, 4, 5];  // array allocated
$b = $a;                 // NO copy; refcount incremented
$b[] = 6;                // NOW a copy is made; $a and $b have separate arrays
```

This means passing large arrays to functions is cheap as long as the function doesn't modify them — the array isn't copied, just referenced. This is why PHP doesn't need explicit "pass by reference" for read-only access to large data.

**The trap:** functions that modify their input trigger a full copy. A function that receives a 100MB array and appends one element copies the entire 100MB. If you're processing large data, either modify in place (pass by reference) or use generators/iterators to avoid holding it all in memory.

### Circular references and the cycle collector

Reference counting fails on circular references — two objects that reference each other never reach refcount zero even when nothing external references them:

```php
$a = new stdClass();
$b = new stdClass();
$a->ref = $b;
$b->ref = $a;
unset($a);  // refcount of both objects drops to 1 (they reference each other)
unset($b);  // refcount of both objects is still 1 — LEAK
```

PHP's **cycle collector** periodically scans for these cycles and frees them. It runs when the "root buffer" fills up (10,000 potential roots by default). The cycle collector adds a small CPU cost — usually negligible, but measurable on request-heavy workloads.

**In FPM this doesn't matter much** because all memory is freed at request end regardless. In **long-running workers**, circular references leak until the cycle collector runs or the process exits. This is one reason workers need memory limits.

### Memory limit

PHP enforces a per-process memory limit via `memory_limit` in `php.ini`:

```ini
memory_limit = 256M
```

When a script tries to allocate beyond this, PHP throws a `Fatal error: Allowed memory size exhausted`. The limit applies to the PHP heap, not to the entire process (OS-level memory includes OPCache, shared memory, etc.).

**How to diagnose memory issues:**

```php
echo memory_get_usage();        // current PHP heap usage
echo memory_get_peak_usage();   // peak PHP heap usage during the request
echo memory_get_usage(true);    // real allocation (includes internal fragmentation)
```

### Why arrays use more memory than you'd expect

A PHP array is a hash table. Each entry has:

- A hash value (8 bytes)
- A key (string keys are stored; integer keys use the hash directly)
- A zval for the value (16 bytes on 64-bit)
- Bucket pointers (8 bytes)

An array of 1 million integers doesn't use 4MB (1M × 4 bytes); it uses ~36MB or more because each entry carries hash-table overhead.

**Practical consequence:** if you're processing 10 million rows, don't load them into an array. Use generators, cursors, or chunked processing to keep memory flat.

### Packed arrays — the optimization

PHP 7+ optimizes arrays with sequential integer keys (0, 1, 2, 3, ...) as **packed arrays**. Packed arrays skip the hash table entirely and store values in a contiguous block. They use roughly half the memory of non-packed arrays.

The optimization breaks if you delete elements from the middle, use non-sequential keys, or mix string and integer keys.

**Practical consequence:** `array_values()` on an array with gaps can significantly reduce memory by repacking it.

### Strings and interning

Short strings (up to ~76 bytes depending on configuration) may be **interned** — stored once in shared memory and reused. Common strings like class names, method names, and literal strings from source code are interned by OPCache.

Interning means two identical string variables can point to the same memory location without copying. This is transparent and automatic — you don't control it directly.

### Object memory

Each object has:

- A **zend_object** structure (fixed overhead ~56 bytes on 64-bit).
- Property storage (one zval per property).
- Class info pointer.

Creating many small objects (10,000 DTOs with 3 properties each) has non-trivial overhead. For hot paths, flat arrays or value objects with fewer allocations can be significantly faster.

### Generators — the memory-efficiency tool

Generators produce values one at a time without holding the entire dataset in memory:

```php
function readLargeFile(string $path): Generator
{
    $handle = fopen($path, 'r');
    while (($line = fgets($handle)) !== false) {
        yield $line;
    }
    fclose($handle);
}

// Memory usage is constant regardless of file size
foreach (readLargeFile('/tmp/huge.csv') as $line) {
    processLine($line);
}
```

Without generators, loading a 1GB file into an array requires 1GB+ of memory. With generators, memory usage is constant (one line at a time).

Use generators for:

- Reading large files
- Processing database result sets row by row
- Producing large datasets for export (CSV, JSON streaming)
- Any pipeline where you don't need random access to the full dataset

### Memory leaks in long-running processes

In FPM, memory leaks don't accumulate — the process resets after each request. In long-running workers (Messenger, Swoole, RoadRunner), leaks compound:

**Common leak sources:**

- **Doctrine's Identity Map.** Every entity loaded is cached in the EntityManager. After 10,000 messages, the identity map holds 10,000 entities. Fix: `$entityManager->clear()` between messages.
- **Static arrays that grow.** A static `$cache` array that's never pruned.
- **Event listeners accumulating state.** A listener that appends to an internal array on every event.
- **Circular references.** Objects referencing each other, not collected until the cycle collector runs.
- **Monolog handlers with in-memory buffers.** The `BufferHandler` or `FingersCrossedHandler` can accumulate log records.
- **Unclosed resources.** File handles, streams, or connections that aren't cleaned up.

**Diagnosis:**

- Track `memory_get_usage()` before and after each message. If it trends upward, you have a leak.
- Use `php-memprof` or `Blackfire` to identify which allocations aren't being freed.
- Monitor process RSS in Kubernetes (`container_memory_working_set_bytes`) over time.

**Mitigation:**

- Time-limit and memory-limit workers. Let them die and restart.
- Clear the EntityManager between messages.
- Unset large variables explicitly when done.
- Avoid static-state accumulation.

> **Mid-level answer stops here.** A mid-level dev can describe reference counting. To sound senior, speak to the practical consequences — COW behavior, array overhead, generator usage, and leak diagnosis in workers ↓
>
> **Senior signal:** connecting PHP's memory model to real production concerns (OOM debugging, worker memory management, efficient data processing).

### The diagnostic checklist for "why is this request using so much memory?"

1. **Check `memory_get_peak_usage()`.** Where does peak occur?
2. **Is a large dataset loaded into an array?** Use generators or chunked processing.
3. **Is Doctrine hydrating too many entities?** Select only needed fields; use scalar queries for large result sets.
4. **Are large strings being concatenated?** String concatenation creates new strings; use output buffering or streams.
5. **Is `memory_limit` set appropriately?** Too low → OOM on legitimate requests. Too high → one bad request can take down the worker.
6. **Is the issue in a library?** Profile with Blackfire to see which functions allocate the most.

### Common mistakes

- **Loading entire result sets into arrays.** Use cursors, generators, or LIMIT/OFFSET.
- **Ignoring COW and passing large arrays by reference "for performance."** If you're not modifying the array, pass by value — COW makes it free.
- **Not clearing EntityManager in workers.** The identity map grows without bound.
- **Setting `memory_limit` to `-1` (unlimited).** One bad query can take down the server.
- **Not monitoring worker memory over time.** Leaks are invisible until the OOM kill.
- **Using arrays as data stores for millions of items.** The per-element overhead is 36+ bytes. Use SplFixedArray for large collections of integers, or external storage (Redis, database).

### Closing

"So PHP manages memory with reference counting, copy-on-write, and a cycle collector for circular references. The per-request lifecycle means leaks don't accumulate in FPM — but they do in workers, which need explicit cleanup (EntityManager clearing, time/memory limits). Arrays have significant per-element overhead, so large datasets should use generators or chunked processing. The practical skills are: knowing when COW copies will trigger, using generators for large data, diagnosing OOM with `memory_get_peak_usage()`, and managing worker memory with limits and explicit cleanup."
