# LISTEN/NOTIFY and logical replication

**Interview framing:**

"These are two PostgreSQL features that let the database emit events to external systems — LISTEN/NOTIFY is the simple in-memory pub/sub mechanism built into the database, and logical replication is the heavy-duty, persistent change-data-capture stream. Both are powerful when used right and have specific pitfalls. The senior framing is: LISTEN/NOTIFY is for lightweight, fire-and-forget notifications within one connection's lifetime; logical replication is for durable, ordered change streams you'd use to drive a CDC pipeline, implement an outbox pattern, or keep a downstream system in sync. People often confuse the two or try to use LISTEN/NOTIFY for jobs it's not suited for."

### LISTEN / NOTIFY — the simple one

`LISTEN` and `NOTIFY` are SQL commands that implement a lightweight pub/sub mechanism within a PostgreSQL connection.

```sql
-- In one session: listen for notifications on a channel
LISTEN order_updates;

-- In another session: send a notification
NOTIFY order_updates, 'order 42 updated';
-- or from application code:
SELECT pg_notify('order_updates', '{"order_id": 42, "status": "shipped"}');
```

Every session that has `LISTEN`ed to `order_updates` receives the notification — including the payload. The client library (typically PDO or a PostgreSQL driver) exposes these notifications asynchronously.

**PHP example** with PDO:

```php
$pdo = new PDO('pgsql:host=localhost;dbname=app');
$pdo->exec('LISTEN order_updates');

while (true) {
    // Wait for a notification with a timeout
    $notification = $pdo->pgsqlGetNotify(PDO::FETCH_ASSOC, 30000);
    if ($notification) {
        echo "Received: " . $notification['payload'] . "\n";
        handleUpdate(json_decode($notification['payload'], true));
    }
}
```

The consumer blocks on `pgsqlGetNotify`, waking up when a notification arrives. For Symfony Messenger or similar, there are specific transports that use LISTEN/NOTIFY as the delivery mechanism.

### How LISTEN/NOTIFY actually works

- Notifications are sent at transaction commit time. If you `NOTIFY` inside a transaction that rolls back, the notification is **not** sent.
- Notifications are delivered **only to currently-connected listeners**. If no one is listening, the notification is lost.
- Notifications are **in-memory only**. They're not persisted; a broker restart loses pending notifications.
- Notifications have a **small size limit** for the payload (8KB by default). Don't use them for large messages.
- Each backend process has a notification queue; if it overflows (because a listener is slow), the backend errors.

These properties make LISTEN/NOTIFY a specific kind of tool: fast, lightweight, transactional with the database, but **not durable and not retrievable after the fact**.

### When to use LISTEN/NOTIFY

- **Cache invalidation.** "The product catalog changed; drop your cached copy." Best-effort is fine because clients can refetch.
- **Real-time UI updates.** Websocket servers subscribe to notifications and push updates to connected clients.
- **Coordinating long-running workers.** A master process notifies workers of new work.
- **Replacing polling in worker loops.** Instead of polling an outbox table every second, wait for a notification that new rows have arrived, then process.
- **Low-latency event triggering within a single system.**

### When NOT to use LISTEN/NOTIFY

- **When durability matters.** Lost notifications during a restart are unacceptable for most business events.
- **When the listener may not be running.** No listener = notification gone.
- **When you need ordering guarantees across transactions.** Notifications are delivered in commit order but cross-session ordering is only eventual.
- **When the message size exceeds 8KB.** Use logical replication or a real message broker.
- **When you need multiple consumer groups.** Every listener gets every notification; no concept of competing consumers.
- **When you need replay.** Notifications are fire-and-forget.

**For durable event delivery, use a proper message broker like RabbitMQ or Kafka**, or the outbox pattern (see [../message-brokers/outbox_pattern.md](../message-brokers/outbox_pattern.md)) with LISTEN/NOTIFY as an optional low-latency trigger.

### Logical replication — the heavy-duty one

**Logical replication** is PostgreSQL's mechanism for replicating specific tables (or all tables) to another PostgreSQL server — or to any consumer that understands the logical replication protocol. It's called "logical" because it replicates logical row changes (INSERT, UPDATE, DELETE) rather than physical WAL blocks.

Compared to **physical replication** (streaming replication):
- **Logical:** replicates row-level changes; works across major versions; supports selective table replication.
- **Physical:** replicates WAL blocks; must replicate the entire cluster; same major version required.

For most HA setups, physical replication is still the default. For CDC, cross-version upgrades, and selective replication, logical is the tool.

### How logical replication works

PostgreSQL creates a **logical replication slot**. The slot is a persistent marker in the WAL that tracks the last change consumed by a specific subscriber. As long as the slot exists, the WAL needed to reproduce changes for that slot is retained — even if normal WAL recycling would have removed it.

A **publication** is a set of tables whose changes are published. A **subscription** is the downstream side that consumes from a publication (or, for third-party consumers like Debezium, a direct logical replication client).

```sql
-- On the publisher
CREATE PUBLICATION my_publication FOR TABLE orders, order_items, users;

-- On a subscriber PostgreSQL instance
CREATE SUBSCRIPTION my_subscription
  CONNECTION 'host=publisher dbname=app user=replicator password=...'
  PUBLICATION my_publication;
```

The subscriber now receives row changes from the publisher's tables and applies them to its own copy.

### CDC with logical replication

The more interesting use case: **change data capture** with a non-PostgreSQL consumer. Tools like **Debezium** connect to PostgreSQL's logical replication slot, receive the change stream, and forward the events to Kafka, Pulsar, or another destination.

The flow:

```
PostgreSQL → logical replication slot → Debezium → Kafka → downstream consumers
```

Each row change in PostgreSQL becomes a JSON event on a Kafka topic, complete with before/after values, primary key, operation type, and transaction metadata. This is the production CDC pipeline for many teams.

**Why this matters:**
- **No application-level dual writes.** Changes to Postgres automatically flow to downstream systems.
- **Schema changes are tracked.** Debezium handles schema evolution via its schema registry.
- **Ordering is preserved** within a transaction.
- **At-least-once delivery** with consumer offset tracking on Kafka.
- **No application code change** to add new consumers — they subscribe to the Kafka topic.

The alternative, without CDC, is the application-level outbox pattern: write the change and the outbox event in the same transaction, then a relay reads the outbox and publishes. CDC skips the outbox: the WAL *is* the outbox.

### The pitfalls of logical replication

**1. Replication slot growth.** If a subscriber disconnects and never reconnects, the slot still exists and WAL accumulates. Postgres won't delete WAL needed by the slot, so disk fills up. Monitor replication slot lag and alert.

```sql
SELECT
  slot_name,
  active,
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS lag
FROM pg_replication_slots;
```

**2. Conflicts.** Logical replication doesn't resolve conflicts. If a subscriber has a row with the same primary key that wasn't in the publisher's stream, the replication fails and the subscription stops.

**3. DDL is not replicated.** Schema changes (CREATE TABLE, ALTER TABLE) don't flow through logical replication. You have to apply them to both sides manually, usually with careful ordering.

**4. Sequences are not replicated.** If you use sequences for IDs, the subscriber's sequence doesn't advance automatically. Reset it after initial sync or you'll get conflicts on inserts.

**5. Large transactions are streamed in full before being visible on the subscriber.** A 10-minute transaction on the publisher means 10+ minutes of replication lag on the subscriber.

**6. Initial sync can be slow.** When a new subscription starts, it copies the full table contents. For large tables, this can take hours. Post-copy, it catches up on ongoing changes.

**7. Failover is manual.** Unlike physical replication, logical replication doesn't have well-integrated failover tooling. Patroni and similar tools focus on physical replication; logical replication for HA is less mature.

### Logical replication vs LISTEN/NOTIFY vs outbox pattern

When do you pick which?

| Use case | Right tool |
|---|---|
| Cache invalidation (lightweight, best-effort) | LISTEN/NOTIFY |
| Real-time UI updates (lightweight, best-effort) | LISTEN/NOTIFY |
| Reliable event delivery to another service | Outbox pattern or logical replication → CDC |
| Multiple downstream consumers of business events | Logical replication → CDC → Kafka |
| Cross-version database migrations | Logical replication |
| Selective database-to-database replication | Logical replication |
| HA failover | Physical replication (streaming) |

The outbox pattern and logical replication overlap: both give you reliable change capture. The outbox is application-managed and portable across databases. Logical replication is database-managed and PostgreSQL-specific but requires no application-level changes.

My default: for new Postgres-first systems, logical replication + Debezium is the cleanest CDC story. For database-agnostic or smaller deployments, the outbox pattern is simpler and portable.

### Listen_notify in logical replication workflows

A common pattern: use logical replication for the durable change stream, and LISTEN/NOTIFY as a low-latency trigger for consumers waiting on an outbox-like table.

```
Producer → INSERT into outbox (same transaction as business change)
           NOTIFY outbox_new_row
Consumer → LISTEN outbox_new_row
           (wakes up, queries for new rows, processes them)
```

The notification triggers immediate processing without polling; the outbox table is the durable source of truth in case notifications are missed. Best of both worlds for a single-database pipeline.

### Outbox relay via LISTEN/NOTIFY

Specifically for an outbox relay process (the piece that reads the outbox and publishes to a broker), LISTEN/NOTIFY replaces polling:

```sql
-- In a trigger on the outbox table
CREATE OR REPLACE FUNCTION notify_outbox() RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify('outbox_new', NEW.id::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER outbox_insert_notify
  AFTER INSERT ON outbox
  FOR EACH ROW EXECUTE FUNCTION notify_outbox();
```

The relay process listens on `outbox_new`, wakes up on each insert, processes the row. If the relay is disconnected, notifications are lost — but the outbox row is still there, and a periodic fallback poll catches up on missed notifications.

This is the cleanest low-latency outbox relay pattern I know of.

> **Mid-level answer stops here.** A mid-level dev can describe LISTEN/NOTIFY. To sound senior, speak to when each mechanism is the right tool, the failure modes, and how they compose with application-level patterns ↓
>
> **Senior signal:** knowing that these are tools with specific use cases, not general-purpose messaging systems.

### Common mistakes

- **Using LISTEN/NOTIFY as a durable message broker.** It isn't; messages are lost if no listener is active.
- **Large payloads in NOTIFY.** 8KB limit; anything bigger needs a different mechanism.
- **Unmonitored replication slots.** Slots fill WAL; WAL fills disk; disk fills up; database goes down.
- **Expecting DDL to replicate logically.** It doesn't. Apply schema changes manually on both sides.
- **Expecting sequences to advance automatically.** They don't.
- **Using logical replication for HA failover.** Works but lacks the tooling maturity of physical replication.
- **Using LISTEN/NOTIFY across transactions.** Notifications are transactional within the sender's transaction, but no cross-session coordination is guaranteed.
- **Forgetting to handle listener reconnection.** Network blip → listener disconnects → notifications missed → silent data loss.

### Closing

"So LISTEN/NOTIFY is a lightweight in-process pub/sub for cache invalidation, real-time UI updates, and coordinating workers within one system — fast, transactional with the database, but not durable. Logical replication is the durable change data capture mechanism, used with Debezium to build CDC pipelines to Kafka or with PostgreSQL subscriptions for cross-version migrations. The two compose: logical replication (or an outbox table) for the durable side, LISTEN/NOTIFY as a low-latency trigger for consumers waiting on it. Pick LISTEN/NOTIFY when loss is acceptable and latency matters; pick logical replication when you need durable, ordered change capture."
