A load balancer distributes incoming traffic across multiple servers so that no single server gets overwhelmed. This is a fundamental component in scalable backend architecture, but it creates a problem — **how to handle user sessions** when requests can go to different servers.

### What Is a Load Balancer

A load balancer sits between the client and your application servers. It receives all incoming requests and forwards them to one of the available backend servers.

```text
                        ┌──────────┐
                   ┌───→│ Server 1 │
                   │    └──────────┘
┌────────┐    ┌────┴───┐
│ Client │───→│  Load  │ ┌──────────┐
│        │    │Balancer│─→│ Server 2 │
└────────┘    └────┬───┘ └──────────┘
                   │    ┌──────────┐
                   └───→│ Server 3 │
                        └──────────┘
```

### Load Balancing Algorithms

| Algorithm | How it works | Best for |
|-----------|-------------|----------|
| **Round Robin** | Sends requests to servers in rotation (1→2→3→1→2→3) | Equal-capacity servers |
| **Least Connections** | Sends to the server with fewest active connections | Varying request durations |
| **Weighted Round Robin** | More powerful servers get more requests | Mixed-capacity servers |
| **IP Hash** | Same client IP always goes to same server | Simple session affinity |
| **Random** | Picks a random server | Simple setups |

```nginx
# Nginx load balancer configuration

# Round Robin (default)
upstream backend {
    server 192.168.1.10:80;
    server 192.168.1.11:80;
    server 192.168.1.12:80;
}

# Weighted — server 1 gets 3x more traffic
upstream backend {
    server 192.168.1.10:80 weight=3;
    server 192.168.1.11:80 weight=1;
    server 192.168.1.12:80 weight=1;
}

# Least connections
upstream backend {
    least_conn;
    server 192.168.1.10:80;
    server 192.168.1.11:80;
    server 192.168.1.12:80;
}

server {
    listen 80;
    location / {
        proxy_pass http://backend;
    }
}
```

### The Session Problem

By default, PHP stores sessions as **files on the local server** (`/tmp/sess_abc123`). When you have multiple servers behind a load balancer, this breaks:

```text
Request 1: User logs in → Load Balancer → Server 1
           Server 1 creates session file: /tmp/sess_abc123

Request 2: User loads dashboard → Load Balancer → Server 2
           Server 2 looks for /tmp/sess_abc123 → NOT FOUND
           User appears logged out!
```

This happens because Server 2 does not have the session file that Server 1 created. There are three main solutions.

### Solution 1: Sticky Sessions (Session Affinity)

The load balancer remembers which server a user was sent to and always sends them to the same server.

```nginx
# Nginx sticky sessions using IP hash
upstream backend {
    ip_hash;
    server 192.168.1.10:80;
    server 192.168.1.11:80;
    server 192.168.1.12:80;
}

# Or using a cookie
upstream backend {
    server 192.168.1.10:80;
    server 192.168.1.11:80;

    sticky cookie srv_id expires=1h;
}
```

**How it works:**

```text
Request 1: User → LB → Server 1 (LB sets cookie: srv_id=server1)
Request 2: User → LB sees cookie srv_id=server1 → Server 1 ✓
Request 3: User → LB sees cookie srv_id=server1 → Server 1 ✓
```

**Pros:**

- Simple to configure
- No changes to application code

**Cons:**

- If Server 1 crashes, all its users lose their sessions
- Uneven load — some servers may get more "sticky" users than others
- Cannot easily scale up/down

### Solution 2: Centralized Session Storage (Redis) — Recommended

Store sessions in a central place that all servers can access — typically **Redis** or **Memcached**. This is the standard solution in production.

```text
┌──────────┐     ┌──────────┐     ┌──────────┐
│ Server 1 │     │ Server 2 │     │ Server 3 │
└─────┬────┘     └─────┬────┘     └─────┬────┘
      │                │                │
      └────────────────┼────────────────┘
                       │
                 ┌─────┴─────┐
                 │   Redis   │
                 │ (sessions)│
                 └───────────┘
```

**Any server can read any session** because all sessions are stored in Redis.

```php
// php.ini configuration — switch session handler from files to Redis
session.save_handler = redis
session.save_path = "tcp://redis-server:6379"

// That's it! No PHP code changes needed.
// session_start() now reads/writes to Redis instead of local files.
```

**Or configure in Symfony:**

```yaml
# config/packages/framework.yaml
framework:
    session:
        handler_id: '%env(REDIS_URL)%'
        cookie_secure: auto
        cookie_samesite: lax

# .env
REDIS_URL=redis://redis-server:6379
```

**Or configure manually in PHP:**

```php
// Custom Redis session handler
$redis = new Redis();
$redis->connect('redis-server', 6379);

$handler = new RedisSessionHandler($redis);
session_set_save_handler($handler, true);
session_start();

// Now sessions are stored in Redis:
// Key: PHPREDIS_SESSION:abc123
// Value: serialized session data
// TTL: session.gc_maxlifetime (default 1440 seconds)
```

**Pros:**

- Sessions survive server crashes
- Any server can handle any request — true load balancing
- Easy to scale up/down servers
- Redis is fast — session reads take < 1ms

**Cons:**

- Redis becomes a single point of failure (mitigate with Redis Sentinel or Cluster)
- Slight network latency for session reads (negligible in practice)

### Solution 3: Database Session Storage

Store sessions in MySQL or PostgreSQL. Works but slower than Redis.

```php
// Symfony — database sessions
// config/packages/framework.yaml
framework:
    session:
        handler_id: Symfony\Component\HttpFoundation\Session\Storage\Handler\PdoSessionHandler

// services.yaml
Symfony\Component\HttpFoundation\Session\Storage\Handler\PdoSessionHandler:
    arguments:
        - '%env(DATABASE_URL)%'
```

```sql
-- Session table
CREATE TABLE sessions (
    sess_id VARCHAR(128) NOT NULL PRIMARY KEY,
    sess_data BLOB NOT NULL,
    sess_lifetime INT NOT NULL,
    sess_time INT UNSIGNED NOT NULL,
    INDEX sess_lifetime_idx (sess_lifetime)
) ENGINE=InnoDB;
```

**Pros:** Uses existing database infrastructure
**Cons:** Slower than Redis, adds load to database, session table can grow large

### Solution 4: Stateless Authentication (JWT)

Avoid server-side sessions entirely. Use JWT tokens that contain all necessary user data.

```php
// No session needed — user data is in the JWT token
#[Route('/api/orders')]
class OrderController extends AbstractController
{
    #[Route('', methods: ['GET'])]
    public function list(): JsonResponse
    {
        // User info comes from JWT token in Authorization header
        // No session read needed — any server can handle this
        $user = $this->getUser();
        $orders = $this->orderRepository->findByUser($user);
        
        return $this->json($orders);
    }
}
```

**Pros:** Truly stateless — no session storage at all
**Cons:** Cannot invalidate tokens easily, token size grows with data

### Health Checks

Load balancers need to know if a server is healthy. If a server crashes, the load balancer should stop sending traffic to it.

```nginx
upstream backend {
    server 192.168.1.10:80 max_fails=3 fail_timeout=30s;
    server 192.168.1.11:80 max_fails=3 fail_timeout=30s;
    server 192.168.1.12:80 max_fails=3 fail_timeout=30s;
}
```

```php
// Health check endpoint
#[Route('/health')]
class HealthController extends AbstractController
{
    #[Route('', methods: ['GET'])]
    public function check(): JsonResponse
    {
        // Check critical dependencies
        try {
            $this->em->getConnection()->executeQuery('SELECT 1');
            $this->redis->ping();
        } catch (\Exception $e) {
            return $this->json(['status' => 'unhealthy'], 503);
        }

        return $this->json(['status' => 'healthy'], 200);
    }
}
```

### Real Scenario

You have an e-commerce application running on 3 servers behind Nginx. Users are complaining about being randomly logged out:

```text
Problem: Sessions stored in local files → users lose session when LB sends 
         them to a different server.

Solution:
1. Install Redis on a dedicated server
2. Configure PHP to use Redis for sessions
3. Use round-robin load balancing (no need for sticky sessions)
4. Add Redis Sentinel for high availability
```

```ini
; php.ini on ALL 3 servers
session.save_handler = redis
session.save_path = "tcp://redis-sentinel:26379?auth=secret"
```

```nginx
# nginx.conf — simple round robin, no sticky sessions needed
upstream app {
    server app1:9000;
    server app2:9000;
    server app3:9000;
}
```

Result:

- Users never lose sessions — any server can handle any request
- If Server 2 crashes, traffic goes to Server 1 and Server 3 — sessions still work
- You can add Server 4 and Server 5 without any session issues

### Conclusion

A load balancer distributes traffic across multiple servers to improve reliability and performance. The main challenge is handling user sessions — sessions stored as local files break when requests go to different servers. The recommended solution is **centralized session storage in Redis**, which allows any server to handle any request. Sticky sessions are a simpler but less reliable alternative. For API-only applications, JWT tokens can eliminate server-side sessions entirely.

> See also: [Sharding](sharding.md), [How to narrow problems on PHP side](how_to_narrow_problems_on_php_side_of_an_application.md), [Optimizing slow GET endpoint](optimizing_slow_get_endpoint.md)
