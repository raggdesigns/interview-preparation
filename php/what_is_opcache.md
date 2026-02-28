# What Is OPCache

OPCache is a built-in PHP engine component that stores compiled script instructions in shared memory.
Without OPCache, PHP parses and compiles files on many requests; with OPCache, most requests skip that step.
In interviews, this topic tests whether you understand real production performance basics in PHP.

## Prerequisites

- You know PHP files are compiled to opcodes before execution
- You know what `php.ini` controls in runtime behavior
- You understand basic deployment flow (new release, reload, warm-up)

## Core Idea

Request flow with OPCache:

1. First request compiles the PHP file and stores opcodes in shared memory.
2. Next requests reuse cached opcodes.
3. CPU cost and response latency drop because repeated compilation is avoided.

## Why It Matters

- Lower CPU usage on PHP-FPM workers
- Lower average and p95 response time
- Better throughput on the same hardware

## Practical Configuration Example

```ini
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=50000
opcache.validate_timestamps=1
opcache.revalidate_freq=2
```

How to explain these quickly:

- `memory_consumption`: cache size for opcodes
- `max_accelerated_files`: number of cached scripts
- `validate_timestamps` and `revalidate_freq`: how code changes are detected

## Deployment Considerations

- In development, timestamp validation is usually enabled.
- In production, teams often reduce checks and reset cache during deploy.
- After deploy, warm up critical routes to avoid first-hit latency spikes.

## Common Pitfalls

- Cache too small causes frequent eviction.
- Huge codebase with low `max_accelerated_files` reduces hit rate.
- Incorrect deploy process can serve stale code for a short time.

## Interview Questions

- What does OPCache optimize exactly?
- Which settings would you check first on a busy API?
- Why can deploy strategy affect OPCache behavior?

## Conclusion

OPCache is one of the highest-impact, lowest-risk PHP performance improvements.
If configured and deployed correctly, it cuts repeated compile work and improves request latency consistency.
