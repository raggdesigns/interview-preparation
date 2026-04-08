# RabbitMQ in PHP

**Interview framing:**

"RabbitMQ in PHP has one fundamental tension: PHP's request lifecycle is short, RabbitMQ consumers want to be long-lived. You can produce from a normal request, but consumers live in a different world — Supervisor-managed CLI processes that run for hours or days. Once you internalize that split, everything else falls into place. Choosing the right client library, the right abstraction level, and the right process manager is just details on top of that split."

### The libraries — what to actually use

**`php-amqplib/php-amqplib`** (pure PHP)
- No extension needed, so it runs anywhere PHP runs.
- More flexible but more verbose.
- Slower than the C extension on pure throughput.
- The default for most Symfony Messenger setups when the extension isn't available.

**`ext-amqp`** (the C extension)
- Wraps the RabbitMQ C client. Faster, lower memory.
- Needs to be installed at the system level, which complicates Docker images and shared hosting.
- Has a slightly different API than php-amqplib.
- Worth it for high-throughput consumers or producers; overkill for occasional publishes.

**Symfony Messenger** (the abstraction)
- Not a library, a component. Sits on top of either of the above.
- Gives you a message bus, routing, middleware, retries, DLQ handling, serializer support, and a CLI consumer worker.
- Handles the boring parts: connection lifecycle, worker loop, graceful shutdown, retry strategy, DLQ binding.
- On a greenfield Symfony project, this is what I reach for first. On legacy or non-Symfony projects, raw php-amqplib.

**My decision rule:**
- Symfony project → Symfony Messenger with the AMQP transport.
- Non-Symfony project → raw php-amqplib with your own worker loop.
- Extreme throughput → ext-amqp; consider whether a different language is more appropriate.

### Publishing from a request — the safe pattern

Publishing inside an FPM request is fine, as long as you don't treat it like a long-lived connection. The shape:

```php
public function createOrder(Request $request): Response
{
    // ... handle the request, write to the DB ...

    // publish the event
    $this->messageBus->dispatch(new OrderCreated($order->getId()));

    return new JsonResponse(...);
}
```

A few production rules:

- **Publish *after* the DB commit.** Publishing before the commit is a recipe for "the event fired but the order doesn't exist in the DB". Either commit first and publish after, or use the outbox pattern (see [outbox_pattern.md](outbox_pattern.md)) to make it atomic.
- **Use publisher confirms** when the publish matters. A dropped publish is silent otherwise.
- **Don't block on downstream consumers.** The whole point of publishing is that the caller doesn't wait for the work to complete. If the consumer is slow, the response should still be fast.
- **Handle broker-down gracefully.** If the broker is unreachable, you have to decide: fail the request, degrade the feature, or queue locally and retry. None of these are "right" — the right answer depends on how critical the event is.

### Consuming — the worker lifecycle

This is where PHP bites you if you treat it like a request handler. Consumers must be:

- **Long-lived CLI processes**, not FPM requests.
- **Run under a process supervisor** (Supervisor, systemd) that restarts them when they crash or exit.
- **Memory-bounded** — restart periodically to avoid leaks, because PHP's garbage collector is not optimized for long-running processes.
- **Graceful on shutdown** — they should finish the current message before exiting, not abandon it.

A typical Supervisor config:

```ini
[program:messenger-consume-async]
command=php /var/www/project/bin/console messenger:consume async --time-limit=3600 --memory-limit=256M
autostart=true
autorestart=true
startsecs=5
startretries=10
stopasgroup=true
killasgroup=true
stopwaitsecs=60
user=www-data
numprocs=4
process_name=%(program_name)s_%(process_num)02d
```

The important bits:
- **`--time-limit=3600`** — worker exits after an hour so Supervisor restarts it with a fresh PHP process. Prevents slow memory creep.
- **`--memory-limit=256M`** — worker exits if it crosses a memory threshold.
- **`stopwaitsecs=60`** — Supervisor gives the worker up to 60 seconds to finish the current message before sending SIGKILL. This is what makes shutdowns graceful.
- **`numprocs=4`** — four workers in parallel. Scale based on queue depth and per-message latency.
- **`autorestart=true`** — if the worker crashes, restart it. Without this, one crash kills consumption forever.

### Symfony Messenger — the happy path

Config (`config/packages/messenger.yaml`):

```yaml
framework:
  messenger:
    transports:
      async:
        dsn: '%env(MESSENGER_TRANSPORT_DSN)%'
        options:
          exchange:
            name: 'events'
            type: 'topic'
          queues:
            billing_service:
              binding_keys:
                - 'order.created.*'
          auto_setup: false
        retry_strategy:
          max_retries: 3
          multiplier: 2
          delay: 1000
          max_delay: 30000

      failed:
        dsn: 'doctrine://default?queue_name=failed'

    failure_transport: failed

    routing:
      App\Message\OrderCreated: async
```

What this gives you out of the box:
- Exchange + queue + binding declared on first use (if `auto_setup: true`) or managed via a deploy command.
- Retry with exponential backoff (1s, 2s, 4s, up to 30s).
- Failed messages after max retries go to a `failed` transport (Doctrine-backed here for easy inspection).
- CLI consumer: `bin/console messenger:consume async`.
- CLI failure management: `messenger:failed:show`, `messenger:failed:retry`, `messenger:failed:remove`.

Messenger handles acknowledgement, deserialization, error catching, and retry logic. You write message classes and handlers; you don't write the broker glue.

### The raw php-amqplib consumer — for context

When Messenger isn't available:

```php
use PhpAmqpLib\Connection\AMQPStreamConnection;

$conn = new AMQPStreamConnection('rabbitmq', 5672, 'user', 'pass');
$channel = $conn->channel();

$channel->queue_declare('billing_service', false, true, false, false);
$channel->basic_qos(null, 10, null);  // prefetch 10

$channel->basic_consume(
    'billing_service',
    '',
    false,
    false,  // auto_ack = false
    false,
    false,
    function ($msg) {
        try {
            processMessage($msg->body);
            $msg->ack();
        } catch (Throwable $e) {
            // log the error
            $msg->nack(false);  // no requeue, goes to DLX
        }
    }
);

while (count($channel->callbacks)) {
    $channel->wait(null, false, 30);  // 30s heartbeat timeout
    // periodically: check memory, check time, exit cleanly to let Supervisor restart
}
```

You still need the Supervisor wrapping, the memory checks, the graceful shutdown handling. Messenger hides all of that; with raw amqplib you write it yourself.

### Things that bite in production PHP consumers

- **Memory leaks.** Long-running PHP processes accumulate memory. Doctrine's entity manager, PSR loggers with handlers, and object graphs that never fully dereference are common culprits. Restart workers on a time or memory limit — don't try to fix the leaks.
- **The EntityManager-is-closed problem.** A consumer processes a message, a query fails, the EntityManager enters a closed state, and every subsequent message fails until the worker restarts. Mitigation: catch the exception, clear/reset the EntityManager, or just let the worker die and Supervisor restart it.
- **Stale database connections.** A consumer idle for hours wakes up to find MySQL has closed its connection. Use `pdo_mysql.reconnect` or ping-on-use, or let the worker die and restart.
- **Prefetch vs forking.** Running multiple processes (`numprocs=4`) with prefetch=1 each gives you deterministic parallelism. Running one process with prefetch=100 gives you batched delivery but no real concurrency inside PHP. I prefer multiple processes — PHP is not good at in-process concurrency.
- **Heartbeat timeouts.** If your consumer takes longer to process a message than the connection heartbeat interval, RabbitMQ will close the connection on you. Either tune the heartbeat up or tune the message processing down.
- **Publishing during shutdown.** Symfony shutdown hooks publishing messages while the kernel is tearing down: orders of operation matter, and I've seen events dropped because the DB rollback happened after the publish.
- **Silent publish failures.** Without publisher confirms, a network blip eats messages and nobody notices until users complain.

### Deployment and rolling restarts

A tricky gotcha: if you roll deploy your consumer processes, how do you ensure in-flight messages finish cleanly? Options:

- **Supervisor `stopwaitsecs` large enough** that the longest message can finish during shutdown.
- **Graceful time-limit** — Messenger's `--time-limit` causes workers to exit cleanly at a boundary, not mid-message. Deploy by killing old workers and letting time-limit drain them.
- **Pause consumption** — set `basic.cancel` on the consumer, wait for the in-flight message, then exit. Messenger does this under the hood.

The anti-pattern: `kill -9` the old workers, start new ones. Messages in flight get nacked (or timeout and re-deliver), and your poor idempotent consumers get hit with duplicate work. Always graceful shutdown.

> **Mid-level answer stops here.** A mid-level dev can describe libraries and configs. To sound senior, speak to the operational reality of long-running PHP processes and the patterns that keep them healthy ↓
>
> **Senior signal:** treating consumer processes as a first-class operational concern, not just "a script we run".

### The mental model I keep

PHP workers are designed to be killed. Not when they break — *on purpose, regularly*. The combination of:

- Bounded memory limit (`--memory-limit`)
- Bounded time limit (`--time-limit`)
- Bounded message count (implicit via `--limit` or explicit loop cap)
- Supervisor that always restarts them
- Graceful shutdown that finishes the current message

...produces a consumer fleet that self-heals. Memory leaks don't accumulate because workers die before the leak matters. Stale connections don't persist because workers die. Deployed code picks up because workers die. Bugs in long-running state don't compound because workers die.

The design is: **embrace the short lifecycle**. PHP is bad at long-running processes. Instead of fighting that, make "long-running" mean "continuously restarting" at a cadence you control. The system-level effect is the same as a true long-running worker, and the failure modes are much friendlier.

### Closing

"So RabbitMQ in PHP is php-amqplib or Symfony Messenger for the code, Supervisor or systemd for the process lifecycle, and a deliberate embrace of worker restarts as a design principle. Publish after DB commit, use publisher confirms when it matters, run consumers as Supervisor-managed CLI processes with time and memory limits, handle graceful shutdown, and treat the EntityManager-is-closed problem as the #1 gotcha in Doctrine-backed consumers. Done right, it's rock-solid; done wrong, you'll spend a year debugging mysterious message loss."
