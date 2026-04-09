# Back-of-envelope estimation

**Interview framing:**

"Back-of-envelope estimation is the skill of producing rough but useful system capacity estimates quickly — in an interview, on a whiteboard, or in a design discussion. The interviewer isn't looking for precision; they're looking for structured reasoning: 'here are my assumptions, here are the conversions, here's the ballpark, and here's where the real risk lies'. The ability to say 'we need roughly 50 servers and 2 TB of storage, and the bottleneck is database writes' in 5 minutes is more valuable than a precise answer that takes 2 hours."

### The numbers to keep in your head

#### Time conversions

- 1 day = 86,400 seconds ≈ **100,000 seconds** (round up for easy math)
- 1 month ≈ 2.5 million seconds
- 1 year ≈ 30 million seconds

#### Traffic conversions

- 1 million requests/day ≈ **12 RPS**
- 100 million requests/day ≈ **1,200 RPS**
- 1 billion requests/day ≈ **12,000 RPS**
- Peak is typically **2-3x average**. Use 3x for conservative estimates.

#### Storage

- 1 KB per row × 1 million rows = 1 GB
- 1 KB per row × 1 billion rows = 1 TB
- With indexes: 2-3x raw data size
- With replication: multiply by replica count

#### Memory

- A PHP-FPM worker: 50-100 MB
- A Redis instance: starts at ~10 MB, grows with data
- A PostgreSQL shared_buffers: typically 25% of total RAM
- A typical web server: 8-32 GB RAM total

#### Network

- Typical intra-datacenter round trip: 0.5 ms
- Typical cross-region round trip: 30-100 ms
- Typical DNS lookup: 10-50 ms
- Typical TLS handshake: 10-50 ms
- 1 Gbps = ~125 MB/s theoretical, ~100 MB/s practical

#### Database

- PostgreSQL on SSD: 5,000-50,000 simple queries/sec depending on complexity
- A single INSERT: ~0.5-2 ms on SSD
- A single indexed SELECT: ~0.1-1 ms
- A complex JOIN with aggregation: 10-1000+ ms
- MySQL is similar ± 20%

### The estimation framework

**Step 1: Define the requirements.**
"The system needs to handle X users, Y requests per day, storing Z data per user."

**Step 2: Convert to per-second rates.**
"Y requests/day ÷ 100,000 = N RPS. Peak = 3×N RPS."

**Step 3: Estimate resource consumption.**
"Each request uses P ms of CPU, Q MB of memory, R database queries."

**Step 4: Size the infrastructure.**
"At peak RPS, we need enough servers to handle it with headroom."

**Step 5: Identify the bottleneck.**
"The limiting factor is database writes / network bandwidth / memory / CPU."

### Worked example: URL shortener

**Requirements:** 100 million URLs created per month. 10:1 read:write ratio. Store for 5 years.

**Writes:**

- 100M/month ÷ 2.5M seconds = **40 writes/sec average**, 120/sec peak.
- Each write: one INSERT. 120 inserts/sec on PostgreSQL is trivial.

**Reads:**

- 10 × 100M/month = 1B reads/month = **400 reads/sec average**, 1200/sec peak.
- Each read: one indexed SELECT by short code. 1200/sec on PostgreSQL is comfortable.

**Storage:**

- Each row: short_code (7 bytes) + original_url (avg 100 bytes) + metadata (50 bytes) ≈ 200 bytes.
- 100M rows/month × 60 months = 6 billion rows.
- 6B × 200 bytes = **1.2 TB raw data**.
- With indexes and overhead: ~3-4 TB.

**Cache:**

- Hot URLs (20% of traffic on 1% of URLs): cache the top 60 million URLs.
- 60M × 200 bytes ≈ 12 GB in Redis. Fits one instance.
- Cache hit rate: probably 90%+ → only 120 reads/sec hit the database instead of 1200.

**Infrastructure:**

- 1-2 PostgreSQL instances (primary + replica).
- 1 Redis instance (12 GB).
- 2-4 app servers (each handling 300-600 RPS at 200ms/request).
- Fits on minimal cloud infrastructure. Cost: ~$500-1000/month.

**Bottleneck:** none at this scale. This is a small system.

### Worked example: social media feed

**Requirements:** 10 million users, 500 million feed reads per day, 50 million posts per day.

**Reads:**

- 500M/day ÷ 100K = **5000 RPS average**, 15,000 peak.
- Each read: fetch a user's feed (20 posts with metadata). If fan-out-on-read: JOIN across posts, follows, users. If fan-out-on-write: single lookup from a pre-computed feed.

**Writes:**

- 50M posts/day ÷ 100K = **500 writes/sec average**, 1500 peak.
- Fan-out-on-write: each post goes to all followers' feeds. Average 100 followers = 50M × 100 = **5 billion feed insertions/day** = 50,000/sec.

**Storage:**

- Posts: 50M/day × 365 days × 1 KB/post = ~18 TB/year.
- Feed entries (fan-out-on-write): 5B/day × 100 bytes = 500 GB/day. Need aggressive TTL or different storage.

**This is a big system.** Feed reads at 15K RPS need caching (Redis or Memcached for hot feeds) and pre-computation (fan-out-on-write). Feed writes at 50K/sec need a message queue to buffer fan-out. Storage needs sharding or a specialized store (Cassandra, ScyllaDB).

**Bottleneck:** feed fan-out writes. 50K/sec sustained write rate exceeds what a single PostgreSQL can handle. Needs sharding or a NoSQL store.

### The estimation pitfalls

- **Forgetting peak vs average.** Average RPS × 3 is peak. Sizing for average means falling over during peaks.
- **Ignoring the read:write ratio.** 100:1 read:write means reads dominate and caching has massive impact. 1:1 means writes are the bottleneck and caching doesn't help the write side.
- **Assuming linear scaling.** Systems don't scale linearly forever. Databases hit write bottlenecks; networks hit bandwidth limits; caches hit memory limits.
- **Ignoring the data growth rate.** Storage is not a one-time cost; it grows every day. 1 TB today is 5 TB in a year.
- **Being too precise.** The point is ballpark. "50 servers" and "47 servers" are the same answer. Don't waste time on arithmetic precision.
- **Not identifying the bottleneck.** The estimation is useful when it points to "the database is the constraint" — then you can design around it.

### What interviewers actually want

They want to see:

1. **Structured reasoning.** "First I'll estimate the traffic, then the storage, then the compute." Not random numbers.
2. **Reasonable assumptions.** "I'll assume an average URL is 100 bytes and peak is 3x average." State them explicitly.
3. **Quick math.** Comfortable with powers of 10 and rough division.
4. **Bottleneck identification.** "The limiting factor is X, so the architecture should address X."
5. **Awareness of trade-offs.** "We could cache to reduce reads, or shard to handle writes, or both."

They don't want: exact numbers, lengthy arithmetic, or over-engineered solutions to a whiteboard exercise.

> **Mid-level answer stops here.** A mid-level dev can do basic RPS calculation. To sound senior, speak to bottleneck identification and how estimation drives architecture ↓
>
> **Senior signal:** using estimation to identify the constraint *before* designing the system, not designing first and hoping it fits.

### Closing

"So back-of-envelope estimation is structured reasoning: define requirements, convert to per-second rates, estimate resource consumption, size the infrastructure, and identify the bottleneck. Keep the key numbers in your head (1M/day ≈ 12 RPS, 1 KB × 1B rows = 1 TB, peak = 3× average), state your assumptions explicitly, and aim for ballpark answers that drive architecture decisions. The point is not 'exactly 47 servers' — it's 'the bottleneck is database writes at 50K/sec, so we need to shard or use a write-optimized store'. The estimation is a tool for design, not a math exercise."
