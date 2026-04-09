# Isolation levels and locking

**Interview framing:**

"Transaction isolation levels determine what one transaction can see of another transaction's uncommitted or recently committed changes. MySQL's InnoDB supports all four SQL standard levels — Read Uncommitted, Read Committed, Repeatable Read (the default), and Serializable — and each trades consistency for concurrency. The senior insight is knowing the specific phenomena each level permits (dirty reads, non-repeatable reads, phantom reads), what InnoDB's MVCC implementation actually does differently from the textbook definition, and when to reach for explicit locking instead of relying on the isolation level."

### The four isolation levels

| Level | Dirty read | Non-repeatable read | Phantom read |
|---|---|---|---|
| Read Uncommitted | Possible | Possible | Possible |
| Read Committed | No | Possible | Possible |
| **Repeatable Read** (InnoDB default) | No | No | **No*** |
| Serializable | No | No | No |

*InnoDB's Repeatable Read prevents phantom reads through gap locking, unlike the SQL standard which permits them. This is a MySQL-specific behavior worth knowing in interviews.

### The phenomena explained

**Dirty read:** Transaction A reads data that Transaction B wrote but hasn't committed yet. If B rolls back, A read data that never existed.

**Non-repeatable read:** Transaction A reads a row, Transaction B updates and commits that row, Transaction A reads again and sees different data. The same query returns different results within one transaction.

**Phantom read:** Transaction A queries rows matching a condition, Transaction B inserts a new row matching that condition and commits, Transaction A re-queries and sees the new row. The result set changed between reads.

### InnoDB's MVCC behavior at each level

**Read Committed:** each SELECT within a transaction creates a new MVCC snapshot. You always see the latest committed data. Two identical SELECTs can return different results if another transaction committed between them.

**Repeatable Read (default):** the first SELECT in a transaction creates an MVCC snapshot, and all subsequent reads use that same snapshot. You see a consistent view of the database as of the transaction's first read — even if other transactions commit changes in the meantime.

The practical consequence: in Repeatable Read, a long-running transaction sees the database as it was when it started. This is great for consistency but means the transaction might act on stale data. If you need to see the latest committed state, use Read Committed or explicit locking.

### InnoDB locking types

**Shared lock (S):** allows other transactions to read but not write the locked row. Acquired by `SELECT ... LOCK IN SHARE MODE` (or `FOR SHARE` in MySQL 8).

**Exclusive lock (X):** prevents other transactions from reading (with locking reads) or writing the locked row. Acquired by `SELECT ... FOR UPDATE`, or implicitly by `UPDATE`/`DELETE`.

**Gap lock:** locks the gap between index records, preventing inserts into that gap. This is how InnoDB prevents phantom reads at Repeatable Read. If a query scans a range, gap locks prevent new rows from appearing in that range.

**Next-key lock:** a combination of a record lock and a gap lock. Locks both the record and the gap before it. The default locking behavior for most InnoDB operations at Repeatable Read.

**Intent locks:** table-level locks indicating that a transaction intends to lock rows. `IS` (intent shared) and `IX` (intent exclusive). Used for internal coordination between row-level and table-level locking; you rarely interact with them directly.

### When to use explicit locking

The default MVCC behavior is sufficient for most read-heavy workloads. Explicit locking is needed when:

**`SELECT ... FOR UPDATE`** — "I'm going to read this row and then update it; nobody else should modify it in the meantime."

```sql
BEGIN;
SELECT balance FROM accounts WHERE id = 42 FOR UPDATE;
-- balance is now locked; other transactions block on this row
UPDATE accounts SET balance = balance - 100 WHERE id = 42;
COMMIT;
```

Without `FOR UPDATE`, two concurrent transactions could both read `balance = 500`, both subtract 100, and both write `balance = 400` — losing one deduction. With `FOR UPDATE`, the second transaction blocks until the first commits.

**`SELECT ... FOR SHARE`** — "I need to ensure this row exists and isn't deleted while I reference it, but I'm not going to update it."

Used when you need to verify a foreign-key-like relationship during a multi-step operation.

### Deadlocks

Two transactions each hold a lock the other needs. InnoDB detects deadlocks automatically and rolls back one transaction (the "victim"), allowing the other to proceed.

```text
Transaction A: locks row 1, waits for row 2
Transaction B: locks row 2, waits for row 1
→ Deadlock → InnoDB kills one
```

**Preventing deadlocks:**

- **Acquire locks in a consistent order.** If all transactions lock rows in the same order, circular waits can't form.
- **Keep transactions short.** Less time holding locks = less chance of conflict.
- **Minimize the locked data set.** Lock specific rows, not ranges or tables.
- **Retry on deadlock.** The application catches the deadlock error and retries the transaction.

**In PHP:** catch the `Doctrine\DBAL\Exception\DeadlockException` and retry with a delay. See [../highload/deadlocks_in_mysql.md](../highload/deadlocks_in_mysql.md) for the full treatment.

### Choosing the right isolation level

**Repeatable Read (default):** correct for most OLTP workloads. Consistent reads within a transaction, no phantom reads in InnoDB. Leave it as default unless you have a reason to change.

**Read Committed:** use when you need to see the latest committed data within a long-running transaction (e.g., batch processing that reads recent changes). Reduces gap-lock contention.

**Serializable:** use when you need absolute isolation. Rare in practice because of the performance cost.

**Read Uncommitted:** almost never. The only use case is rough aggregation where dirty reads are acceptable for speed.

**Per-transaction override:**

```sql
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN;
-- this transaction uses Read Committed
COMMIT;
```

You can set the level per-transaction without changing the global default. Useful for batch jobs or reporting queries that need different behavior.

### The gap-lock trap

Gap locks prevent inserts in index ranges. At Repeatable Read, a query like `SELECT * FROM orders WHERE status = 'pending' FOR UPDATE` locks not just the matching rows but also the gaps between them, preventing new `pending` rows from being inserted.

This can cause unexpected blocking: Transaction A locks the gap, Transaction B tries to insert a pending order, Transaction B blocks until A commits. At high concurrency, this produces lock waits and timeouts.

**Mitigation:**

- **Switch to Read Committed** for transactions that don't need gap locking. Read Committed only uses record locks, not gap locks.
- **Use more specific WHERE clauses.** Narrower ranges produce narrower gap locks.
- **Keep transactions short.** Less time holding gap locks = less contention.

> **Mid-level answer stops here.** A mid-level dev can list the four levels. To sound senior, speak to InnoDB's specific MVCC behavior, gap locking, and the practical consequences for concurrent access patterns ↓
>
> **Senior signal:** knowing that "Repeatable Read" in InnoDB is stricter than the SQL standard (no phantoms via gap locks) and understanding the concurrency implications.

### Common mistakes

- **Assuming higher isolation = safer.** Higher isolation = more locking = more contention = more deadlocks. Use the lowest level that gives you correct behavior.
- **Not understanding gap locks.** Mysterious blocking and deadlocks at Repeatable Read, caused by range queries locking gaps.
- **Long transactions at Repeatable Read.** The snapshot holds back the read view, and any `FOR UPDATE` holds locks for the duration.
- **No deadlock retry logic.** Deadlocks are normal at high concurrency; the application must retry.
- **Using `SELECT ... FOR UPDATE` on read-only queries.** Unnecessary locking that adds contention.
- **Assuming MVCC means no locking.** MVCC handles reads without locking, but writes and locking reads still acquire row/gap locks.

### Closing

"So MySQL/InnoDB's default Repeatable Read gives you a consistent snapshot per transaction with no dirty reads, no non-repeatable reads, and no phantom reads (via gap locking). Read Committed gives you the latest committed data per query with less locking. Use `FOR UPDATE` when you need to read-then-write atomically. Use `FOR SHARE` when you need to verify existence without modification. Keep transactions short, lock in consistent order to avoid deadlocks, and retry on deadlock exceptions. The gap-lock behavior at Repeatable Read is the most common source of unexpected locking, and switching to Read Committed per-transaction is the standard escape hatch."
