# Sharding

Sharding means splitting data across multiple database servers so one server does not become the bottleneck.
In interviews, you are usually expected to explain when sharding is needed, how to pick a shard key, and which trade-offs come with it.

## Prerequisites

- You understand single-database scaling limits (CPU, storage, IOPS)
- You know basic indexing and partitioning concepts
- You know that cross-shard transactions are harder than single-node transactions

## Core Idea

There are two common patterns:

- Vertical sharding: split by feature or table group.
- Horizontal sharding: split rows of the same table by shard key.

## Vertical Sharding

You move different domains to different databases.

Example:

- `users` and `profiles` in one database
- `orders` and `payments` in another database

Good when teams and workloads are clearly separated.
Risk: business flows may need cross-database joins or distributed transactions.

## Horizontal Sharding

You keep the same schema on each shard, but each shard stores only part of the rows.

Example with `users` table:

- Shard 0 stores users where `user_id % 4 = 0`
- Shard 1 stores users where `user_id % 4 = 1`
- Shard 2 stores users where `user_id % 4 = 2`
- Shard 3 stores users where `user_id % 4 = 3`

Good for very large row counts and high write volume.
Risk: bad shard key selection creates hot shards.

## How to Choose a Shard Key

Choose a key that:

- Is present in most read and write queries
- Distributes traffic evenly
- Does not change frequently

Common choices: `user_id`, `tenant_id`, region, or time bucket (with caution for hotspots).

## Practical Routing Example

```php
<?php

final class ShardRouter
{
    public function shardForUser(int $userId, int $shardCount): int
    {
        return $userId % $shardCount;
    }
}
```

Application flow:

1. Read `user_id` from request context.
2. Compute shard number.
3. Send query only to that shard.

## Interview Trade-offs to Mention

- Rebalancing is operationally expensive.
- Cross-shard queries and joins are complex.
- Unique constraints across all shards are harder to enforce.
- Backups and failover become multi-node operations.

## Conclusion

Sharding solves scale limits of a single database, but it adds application and operational complexity.
Use it when vertical scaling, indexing, and query tuning are no longer enough, and explain shard-key strategy clearly.
