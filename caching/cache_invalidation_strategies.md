# Cache invalidation strategies

**Interview framing:**

"There are only two hard things in Computer Science: cache invalidation and naming things. The joke is funny because it's true — cache invalidation is genuinely hard, and most of the 'mysterious data bugs' I've debugged in production turned out to be stale cache. The strategies for invalidation — TTL, write-through, write-behind, event-driven — each trade latency for correctness differently, and knowing which to pick is the interview answer."

### The problem

A cache stores a copy of data that's expensive to compute or retrieve. The moment the original data changes, the cached copy is wrong. Cache invalidation is the process of detecting that staleness and correcting it.

The difficulty: the cache doesn't know when the source data changes. The source doesn't know (or care) that a cache exists. The gap between "data changed" and "cache updated" is where bugs live.

### Strategy 1: TTL (Time-To-Live)

Every cached value has an expiration time. After TTL seconds, the cache discards the value and the next request fetches fresh data.

```php
$redis->setex("user:42:profile", 300, json_encode($profile));  // expires in 5 min
```

**Pros:** simplest strategy. No coordination between cache and source. Works everywhere.
**Cons:** stale data for up to TTL seconds. Short TTL → more cache misses → higher load on the source. Long TTL → longer staleness window.
**Use when:** staleness is tolerable (public content, non-critical data, product catalogs) and the simplicity is worth the trade-off.

**TTL tuning:** the right TTL depends on how quickly data changes and how much staleness users tolerate. A product catalog might use 1-hour TTL; a user's shopping cart might use 30-second TTL.

### Strategy 2: Write-through

On every write to the source, simultaneously update the cache. The cache is always current (assuming no failures in the write path).

```php
public function updateProfile(User $user, ProfileData $data): void
{
    $this->repository->save($user);  // write to DB
    $this->cache->set("user:{$user->getId()}:profile", $user->toArray());  // update cache
}
```

**Pros:** cache is always fresh. No staleness window.
**Cons:** every write is slower (must update both DB and cache). If the cache update fails, data is inconsistent. Writes to data that's never read still populate the cache (waste).
**Use when:** strong consistency is required and writes are infrequent relative to reads.

### Strategy 3: Write-behind (Write-back)

Writes go to the cache first; the cache asynchronously writes to the source. The cache is always current; the source catches up.

**Pros:** writes are fast (cache is in-memory). Burst-friendly.
**Cons:** data loss risk if the cache crashes before persisting. Complex implementation. Not suitable for critical data.
**Use when:** write performance is critical and data loss is tolerable (counters, analytics, page views). Rarely used for business-critical data.

### Strategy 4: Cache-aside (Lazy loading + invalidation)

The application manages the cache explicitly. On read: check cache → if miss, fetch from source, populate cache. On write: update source, then **invalidate** (delete) the cache entry. The next read will miss and repopulate.

```php
public function getProfile(int $userId): array
{
    $cached = $this->cache->get("user:{$userId}:profile");
    if ($cached !== null) {
        return json_decode($cached, true);
    }
    $profile = $this->repository->findProfile($userId);
    $this->cache->setex("user:{$userId}:profile", 300, json_encode($profile));
    return $profile;
}

public function updateProfile(int $userId, ProfileData $data): void
{
    $this->repository->updateProfile($userId, $data);
    $this->cache->del("user:{$userId}:profile");  // invalidate, not update
}
```

**Why invalidate (delete) instead of update?** Invalidation is simpler, avoids race conditions where two concurrent writes both try to update the cache, and ensures the next read always gets fresh data from the source.

**The race condition with update:** two requests update the profile concurrently. Request A writes to DB, request B writes to DB, request B writes to cache, request A writes to cache (stale). Now the cache has A's old data. Deletion avoids this because the next read always fetches fresh from the source.

**Pros:** simple, predictable, widely used.
**Cons:** cache miss after every write (cold cache for one request). If invalidation fails, stale data persists until TTL expires. Thundering herd on popular keys.
**Use when:** most cases. This is the default strategy.

### Strategy 5: Event-driven invalidation

The data source publishes change events; cache invalidation is triggered by consuming those events.

```text
DB write → publish event → cache consumer → delete/update cache key
```

**Pros:** decoupled — the write path doesn't know about the cache. Works across services. Can update multiple caches from one event.
**Cons:** eventual consistency (the event takes time to propagate). Requires event infrastructure (broker, consumer). More complex.
**Use when:** cross-service caching, multiple caches for the same data, or when the write path can't be modified to invalidate directly.

### Cache stampede — the thundering herd

When a popular cache key expires, many concurrent requests all miss the cache and hit the source simultaneously. If the source is a database, this can overload it.

**Mitigations:**

- **Lock-based recomputation.** The first request that misses acquires a lock and recomputes; other requests wait for the lock or serve a stale value.
- **Probabilistic early expiration.** Each cache check randomly decides to expire the value slightly early, spreading recomputation over time instead of a single moment.
- **Background refresh.** A background job refreshes popular keys before they expire, so they're never cold.
- **Stale-while-revalidate.** Serve the stale value immediately while a background task fetches the fresh value. The user gets a fast response (possibly slightly stale); the cache is updated asynchronously.

### Multi-layer caching

Real systems often have multiple cache layers:

```text
Application memory (APCu) → Redis → Database
```

Each layer has its own TTL and invalidation strategy. Invalidation must cascade: when the source changes, all layers must be invalidated, not just one.

The common bug: invalidating Redis but not APCu (or vice versa). One layer serves stale data while the other is fresh.

### Cache key design

Good cache keys are:

- **Deterministic.** The same input always produces the same key.
- **Scoped.** Include the entity type, ID, and any relevant context. `user:42:profile`, not just `42`.
- **Versioned.** Include a version prefix so cache format changes don't return old-format data. `v2:user:42:profile`.
- **Not too long.** Redis keys are stored in memory; thousands of 500-character keys add up.

### Monitoring cache health

- **Hit rate.** Percentage of requests served from cache. Below 80% for a well-used cache is a concern.
- **Miss rate and miss source.** Why are misses happening? TTL expiry, invalidation, cold start?
- **Eviction rate.** If the cache is evicting entries to make room, the cache is too small.
- **Latency.** Cache responses should be sub-millisecond. If they're not, check network or Redis saturation.
- **Key count and memory usage.** Unbounded growth means missing eviction policies.

> **Mid-level answer stops here.** A mid-level dev can describe TTL and cache-aside. To sound senior, speak to the race conditions, stampede mitigation, and the discipline of monitoring cache health ↓
>
> **Senior signal:** knowing that cache invalidation bugs are the most common "mysterious" data bugs in production, and designing the invalidation strategy before the caching strategy.

### Common mistakes

- **Cache without invalidation strategy.** "We'll set TTL to 1 hour and it'll be fine." Until it isn't.
- **Updating cache instead of invalidating.** Race conditions between concurrent writes.
- **No TTL as a safety net.** Even event-driven invalidation should have a TTL fallback. If invalidation fails, TTL eventually corrects it.
- **Caching too much.** Not all data benefits from caching. Data that changes constantly or is rarely read doesn't belong in cache.
- **No stampede protection on hot keys.** The cache expires, 1000 requests hit the database simultaneously.
- **Different invalidation across cache layers.** Redis is fresh, APCu is stale.
- **No monitoring.** Low hit rate, high eviction rate, growing memory — all invisible without metrics.
- **Not testing cache invalidation.** "It works in dev" where there's no concurrency.

### Closing

"So the five strategies are TTL (time-based expiry), write-through (update cache on write), write-behind (write to cache first), cache-aside (read-through with delete-on-write), and event-driven (invalidation via events). Cache-aside with TTL as a safety net is the default. The hard parts are race conditions between concurrent writes (solve by deleting rather than updating), cache stampedes on popular keys (solve with locks or probabilistic early expiry), and multi-layer consistency. Design the invalidation strategy before the caching strategy — cache without invalidation is just a stale-data generator."
