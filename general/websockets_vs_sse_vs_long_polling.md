# WebSockets vs SSE vs long polling

**Interview framing:**

"When you need the server to push data to the client in real time, there are three mechanisms: WebSockets (full-duplex, bidirectional, persistent connection), Server-Sent Events (unidirectional server-to-client, over HTTP), and long polling (simulated push by holding HTTP requests open). Each has a different complexity/capability trade-off, and the senior answer is picking the simplest one that solves the problem."

### The three approaches

#### Long polling

The client sends an HTTP request; the server holds it open until it has data (or a timeout). When the server responds, the client immediately sends a new request.

```text
Client → GET /updates (waits...) → Server holds connection
Server has data → responds → Client processes → Client sends new GET /updates
```

**Pros:** works with any HTTP infrastructure, no special server support, firewall-friendly.
**Cons:** connection overhead (each poll is a new HTTP request), latency (at least one round-trip per update), doesn't scale to high-frequency updates, PHP-FPM holds a worker per waiting client.
**Use when:** you need simple push on existing HTTP infrastructure with low-frequency updates. The "I don't want to set up anything special" option.

#### Server-Sent Events (SSE)

The client opens a long-lived HTTP connection; the server sends events down it as a text stream. One-way: server → client only.

```text
Client → GET /events (Accept: text/event-stream) → Server holds connection open
Server: data: {"type": "update", "id": 42}\n\n
Server: data: {"type": "update", "id": 43}\n\n
```

**Pros:** standard HTTP (works through proxies, CDNs, load balancers), auto-reconnection built into the EventSource API, simple protocol, lightweight.
**Cons:** **unidirectional** (server → client only, client sends data via separate HTTP requests), limited to text, connection limits per browser (6 per domain in HTTP/1.1; not an issue in HTTP/2).
**Use when:** you need server-to-client push (notifications, live feeds, dashboard updates) and don't need the client to send data over the same connection.

#### WebSockets

A full-duplex, bidirectional communication channel over a single persistent TCP connection, upgraded from an initial HTTP handshake.

```text
Client → HTTP Upgrade → WebSocket handshake → persistent bidirectional connection
Client ←→ Server (both can send messages at any time)
```

**Pros:** truly bidirectional (chat, collaborative editing, gaming), low latency, efficient for high-frequency updates, binary and text support.
**Cons:** more complex (connection management, reconnection, heartbeats), doesn't go through HTTP middleware cleanly (some proxies/CDNs struggle), needs a persistent-connection server (PHP-FPM can't do this; you need Swoole, Ratchet, or a separate service in Node/Go).
**Use when:** you need bidirectional real-time communication, high-frequency updates, or binary data streaming.

### The decision tree

```text
Does the client need to send data over the same connection?
├── Yes → WebSocket
└── No → Is the update frequency high (>1/second)?
         ├── Yes → WebSocket (SSE can work but starts to strain)
         └── No → Is the infrastructure standard HTTP?
                  ├── Yes → SSE (simplest, auto-reconnect, standard HTTP)
                  └── No → Long polling (works everywhere, simple)
```

For most "push notifications to the frontend" use cases, **SSE is the right answer**. WebSockets are overkill unless you need the client to send data back through the same connection.

### PHP considerations

PHP-FPM can't hold long-lived connections — each worker handles one request. This means:

- **Long polling:** each waiting client ties up a worker. Doesn't scale beyond a handful of clients.
- **SSE:** same problem — a worker is held per connection.
- **WebSocket:** not possible at all in FPM.

**Solutions for PHP-backed real-time:**

- **Mercure** — a hub (written in Go) that handles SSE connections. PHP publishes events to Mercure via HTTP; Mercure pushes to clients. Symfony has native Mercure integration. This is the recommended approach in the Symfony ecosystem.
- **Centrifugo** — similar concept. A standalone real-time server that PHP publishes to.
- **Swoole/RoadRunner** — long-lived PHP processes that can hold connections.
- **Separate service (Node.js, Go)** — a purpose-built WebSocket server that PHP publishes to via Redis pub/sub or a message broker.

The pattern: **PHP handles business logic and publishes events; a dedicated server handles the client connections.** Don't try to hold connections in FPM.

> **Mid-level answer stops here.** A mid-level dev can describe the three mechanisms. To sound senior, speak to the PHP-specific architecture and when SSE beats WebSockets ↓
>
> **Senior signal:** knowing that SSE is underused and that WebSockets are over-prescribed for simple push scenarios.

### Common mistakes

- **WebSocket for everything.** Most "real-time" features only need server-to-client push. SSE is simpler.
- **Long polling in PHP-FPM.** Holds workers and doesn't scale.
- **Trying to hold WebSocket connections in FPM.** Architecturally impossible.
- **Not handling reconnection.** SSE's EventSource handles this automatically; WebSocket needs manual reconnection logic.
- **No heartbeat on WebSocket connections.** Proxies and firewalls drop idle connections. Send periodic pings.
- **Ignoring HTTP/2.** HTTP/2 multiplexing eliminates the 6-connection-per-domain limit for SSE.

### Closing

"So long polling is the simplest option for low-frequency updates on standard HTTP. SSE is the right default for server-to-client push — standard HTTP, auto-reconnect, works through proxies. WebSockets are for bidirectional or high-frequency communication. In PHP, use Mercure or Centrifugo as a push hub — PHP publishes events, the hub handles client connections. Don't hold connections in FPM."
