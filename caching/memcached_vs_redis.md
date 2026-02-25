Memcached and Redis are both in-memory data stores used for caching in web applications. They have different architectures and features, so the choice depends on your needs.

### Architecture

**Memcached** is a simple key-value cache. It stores data in memory and uses a multi-threaded architecture. It was designed for one purpose — caching — and it does it well.

**Redis** is a data structure server. It is single-threaded (main thread) but can handle many connections efficiently using I/O multiplexing. Redis supports much more than just caching.

### Data Types

| Feature | Memcached | Redis |
|---------|-----------|-------|
| Strings | Yes | Yes |
| Hashes | No | Yes |
| Lists | No | Yes |
| Sets | No | Yes |
| Sorted Sets | No | Yes |
| Streams | No | Yes |
| Bitmaps | No | Yes |

Memcached only stores strings (or serialized data as strings). Redis supports many data types natively, which makes complex operations possible without extra code on the application side.

### Persistence

**Memcached**: No persistence. All data is lost when the server restarts. It is purely a cache.

**Redis**: Supports two persistence methods:
- **RDB (snapshots)** — saves the dataset to disk at configured intervals
- **AOF (Append-Only File)** — logs every write operation, can replay them on restart

```
# Redis persistence configuration (redis.conf)
save 900 1        # Save if at least 1 key changed in 900 seconds
save 300 10       # Save if at least 10 keys changed in 300 seconds
appendonly yes     # Enable AOF
```

### Replication and High Availability

**Memcached**: No built-in replication. You can run multiple instances, but the client library distributes keys using consistent hashing. If one node goes down, its data is lost.

**Redis**: Built-in master-replica replication. Redis Sentinel provides automatic failover. Redis Cluster supports sharding data across multiple nodes.

```
# Redis replication — replica configuration
replicaof 192.168.1.100 6379
```

### Memory Management

**Memcached**: Uses a slab allocator. Memory is pre-allocated in chunks of fixed sizes. This can lead to memory waste if your data sizes vary a lot.

**Redis**: Uses `jemalloc` for memory allocation. Supports memory policies for eviction when memory is full:
- `allkeys-lru` — remove least recently used keys
- `volatile-lru` — remove LRU keys that have an expiration set
- `noeviction` — return errors when memory is full

### Maximum Value Size

| | Memcached | Redis |
|-|-----------|-------|
| Max key size | 250 bytes | 512 MB |
| Max value size | 1 MB (default) | 512 MB |

### Performance

Both are extremely fast because they store data in memory. For simple get/set operations, they have similar performance. Memcached can be slightly faster for simple key-value operations with multiple threads, but Redis handles complex operations (lists, sets, sorted sets) much better because it does them server-side.

### When to Use Memcached

- You need simple key-value caching only
- You want a multi-threaded cache for high-throughput simple operations
- You do not need persistence
- You want the simplest possible setup

```php
// PHP Memcached usage
$mc = new Memcached();
$mc->addServer('localhost', 11211);

$mc->set('user:123', serialize($userData), 3600); // TTL 3600 seconds
$data = unserialize($mc->get('user:123'));
```

### When to Use Redis

- You need data structures (lists, sets, sorted sets, hashes)
- You need persistence (data must survive restarts)
- You need pub/sub messaging
- You need atomic operations on complex data types
- You need replication and high availability
- You want to use it as a session store, message broker, or rate limiter

```php
// PHP Redis usage
$redis = new Redis();
$redis->connect('localhost', 6379);

// Simple cache
$redis->setex('user:123', 3600, serialize($userData));

// Sorted set for leaderboard
$redis->zAdd('leaderboard', 1500, 'player:1');
$redis->zAdd('leaderboard', 2300, 'player:2');
$top10 = $redis->zRevRange('leaderboard', 0, 9, true); // Top 10 with scores

// Rate limiting with Redis
$key = 'rate:' . $userId;
$redis->incr($key);
$redis->expire($key, 60); // Reset counter every 60 seconds
```

### Quick Comparison Table

| Feature | Memcached | Redis |
|---------|-----------|-------|
| Data types | Strings only | Strings, hashes, lists, sets, sorted sets, streams |
| Persistence | No | Yes (RDB, AOF) |
| Replication | No | Yes (master-replica) |
| Clustering | Client-side | Built-in (Redis Cluster) |
| Threading | Multi-threaded | Single-threaded (main) |
| Max value size | 1 MB | 512 MB |
| Pub/Sub | No | Yes |
| Lua scripting | No | Yes |
| Transactions | No | Yes (MULTI/EXEC) |
| Use case | Simple caching | Caching + data structures + messaging |

### Real Scenario

You build an e-commerce platform. You need:
1. **Page caching** — both Memcached and Redis work fine
2. **Shopping cart** — Redis is better (hash data type stores cart items naturally)
3. **Product ranking** — Redis sorted sets handle this perfectly
4. **Session storage** — Redis supports persistence, so sessions survive restarts
5. **Real-time notifications** — Redis pub/sub handles this

For a simple blog that only needs page caching, Memcached is enough and simpler. For a complex application with multiple caching needs, Redis is the better choice because it covers more use cases with one tool.

### Conclusion

Memcached is a fast, simple, multi-threaded key-value cache. Redis is a feature-rich data structure server with persistence, replication, and many data types. For most modern applications, Redis is the preferred choice because it handles more use cases. Memcached still has value when you need only simple caching with multi-threaded performance.

> See also: [Redis basics](redis_basics.md) for a deeper look at Redis data types and commands.
