# How the Internet Works

When you type a URL into a browser and press Enter, a complex chain of network protocols work together to fetch and display the page. Understanding this request lifecycle — from DNS resolution to page rendering — is a fundamental interview topic.

> **Scenario used throughout this document:** A user types `https://shop.com/products` into their browser.

## Prerequisites

- [HTTP Protocol Structure](http_protocol_structure.md) — request/response format
- [REST API Architecture](rest_api_architecture.md) — how APIs are structured

## The Complete Request Lifecycle

```text
User types https://shop.com/products
  |
  v
1. DNS Resolution       -> "What IP address is shop.com?"
  |                        shop.com -> 93.184.216.34
  v
2. TCP Connection       -> Three-way handshake with the server
  |                        SYN -> SYN-ACK -> ACK
  v
3. TLS Handshake        -> Establish encrypted connection (HTTPS)
  |                        Negotiate cipher, exchange keys
  v
4. HTTP Request         -> Send the actual request
  |                        GET /products HTTP/1.1
  v
5. Server Processing    -> Backend handles the request
  |                        Route -> Controller -> Database -> Response
  v
6. HTTP Response        -> Server sends back data
  |                        200 OK + HTML/JSON body
  v
7. Rendering            -> Browser parses HTML, loads CSS/JS, paints
  |
  v
Page displayed
```

## Step 1: DNS Resolution

DNS (Domain Name System) translates human-readable domain names into IP addresses. It works like a phonebook for the internet.

```text
Browser: "What is the IP for shop.com?"

1. Browser cache     -> checked first (cached from previous visits)
2. OS cache          -> checked next (system-level DNS cache)
3. Router cache      -> your home router may cache DNS responses
4. ISP DNS resolver  -> your ISP's recursive resolver

If none have it, the resolver queries the DNS hierarchy:

5. Root nameserver   -> "I don't know shop.com, but .com is handled by these servers"
6. TLD nameserver    -> "I don't know shop.com, but its nameserver is ns1.cloudflare.com"
7. Authoritative NS  -> "shop.com is 93.184.216.34" (with TTL: 3600s)

The answer propagates back through the chain, each layer caching it.
```

**Recursive vs Iterative queries:**

```text
Recursive (what your browser does):
  Browser -> ISP resolver: "Give me the final answer for shop.com"
  ISP resolver does all the work and returns 93.184.216.34

Iterative (what the resolver does internally):
  Resolver -> Root NS: "Where is shop.com?"  -> "Ask .com TLD"
  Resolver -> TLD NS:  "Where is shop.com?"  -> "Ask ns1.cloudflare.com"
  Resolver -> Auth NS: "Where is shop.com?"  -> "93.184.216.34"
```

## Step 2: TCP Three-Way Handshake

TCP (Transmission Control Protocol) establishes a reliable connection between client and server. The three-way handshake ensures both sides are ready.

```text
Client                          Server (93.184.216.34:443)
  |                                |
  |---- SYN (seq=100) ----------->|  "I want to connect"
  |                                |
  |<--- SYN-ACK (seq=300, ack=101)|  "OK, I'm ready too"
  |                                |
  |---- ACK (ack=301) ----------->|  "Great, connection established"
  |                                |
  |       Connection established   |
```

**Why three steps?** Both sides need to confirm they can send AND receive. SYN proves the client can send. SYN-ACK proves the server can send and receive. ACK proves the client can receive.

## Step 3: TLS Handshake (HTTPS)

For HTTPS, a TLS handshake runs on top of the TCP connection to establish encryption.

```text
Client                              Server
  |                                    |
  |-- ClientHello ------------------>  |  Supported ciphers, TLS version
  |                                    |
  |<-- ServerHello + Certificate ----  |  Chosen cipher + server's public key
  |                                    |
  |   Client verifies certificate:     |
  |   - Is it signed by a trusted CA?  |
  |   - Is it expired?                 |
  |   - Does the domain match?         |
  |                                    |
  |-- Key Exchange ----------------->  |  Client generates pre-master secret,
  |                                    |  encrypts with server's public key
  |                                    |
  |<-- Finished --------------------   |  Both derive session keys
  |                                    |
  |   Encrypted communication begins   |
```

After TLS, all data is encrypted — even if someone intercepts the packets, they can't read the content.

## Step 4: HTTP Request

The browser sends an HTTP request over the encrypted connection:

```http
GET /products HTTP/1.1
Host: shop.com
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)
Accept: text/html,application/xhtml+xml
Accept-Language: en-US,en;q=0.9
Accept-Encoding: gzip, deflate, br
Connection: keep-alive
Cookie: session_id=abc123
```

Key headers:

- `Host` — which website (important for virtual hosting — one server, many sites)
- `Accept` — what content types the browser can handle
- `Cookie` — session data from previous visits
- `Connection: keep-alive` — reuse this TCP connection for subsequent requests

## Step 5: Server Processing

The server receives the request and routes it through the application:

```text
Nginx (web server / reverse proxy)
  |
  | Static file? (.css, .js, .jpg)
  |   -> Yes -> Serve directly from disk (fast)
  |   -> No  -> Forward to PHP-FPM
  |
  v
PHP-FPM (application server)
  |
  | Route: GET /products -> ProductController::list()
  |
  v
ProductController
  |
  | $products = $repository->findAll();  -> MySQL query
  | return $this->render('products.html', ['products' => $products]);
  |
  v
Template engine renders HTML
  |
  v
Response sent back to Nginx -> Client
```

## Step 6: HTTP Response

```http
HTTP/1.1 200 OK
Content-Type: text/html; charset=UTF-8
Content-Length: 4523
Content-Encoding: gzip
Cache-Control: public, max-age=300
Set-Cookie: session_id=abc123; HttpOnly; Secure; SameSite=Strict

<!DOCTYPE html>
<html>
<head><title>Products - Shop</title>
<link rel="stylesheet" href="/css/styles.css">
</head>
<body>
  <h1>Products</h1>
  <!-- product list -->
  <script src="/js/app.js"></script>
</body>
</html>
```

## Step 7: Browser Rendering

After receiving the HTML, the browser performs multiple steps:

```text
1. Parse HTML           -> Build DOM tree (Document Object Model)
2. Discover resources   -> Find <link>, <script>, <img> tags
3. Fetch resources      -> Parallel HTTP requests for CSS, JS, images
   (each goes through DNS -> TCP -> TLS -> HTTP again, unless cached)
4. Parse CSS            -> Build CSSOM (CSS Object Model)
5. Execute JavaScript   -> May modify DOM
6. Layout               -> Calculate position and size of elements
7. Paint                -> Draw pixels to screen
8. Composite            -> Combine layers (GPU-accelerated)
```

**Key optimization:** The browser fetches resources **in parallel** (up to 6 connections per domain in HTTP/1.1, multiplexed in HTTP/2).

## Timing Breakdown

A typical page load involves these cumulative delays:

```text
DNS lookup:           ~20-120ms  (cached: 0ms)
TCP handshake:        ~20-80ms   (1 round trip)
TLS handshake:        ~40-160ms  (2 round trips)
HTTP request/response: ~50-200ms (depends on server processing + network)
--------------------------------------------------
Total first byte:     ~130-560ms

Resource loading:     ~200-1000ms (CSS, JS, images in parallel)
Rendering:            ~50-200ms  (parse, layout, paint)
--------------------------------------------------
Total visible page:   ~380-1760ms
```

## HTTP/1.1 vs HTTP/2

| Aspect | HTTP/1.1 | HTTP/2 |
|--------|----------|--------|
| Connections | Multiple TCP connections (6 per domain) | Single multiplexed connection |
| Header format | Text-based, repeated per request | Binary, compressed (HPACK) |
| Request handling | Sequential per connection | Parallel streams on one connection |
| Server push | Not supported | Server can push resources before client asks |
| Head-of-line blocking | Yes (one slow response blocks others) | No (streams are independent) |

## Caching Layers

Multiple caching layers reduce repeated work:

```text
Browser cache       -> Stores resources locally (CSS, JS, images)
                       Controlled by: Cache-Control, ETag, Expires headers

CDN (e.g., Cloudflare) -> Caches responses at edge locations worldwide
                          Reduces latency by serving from nearby server

Reverse proxy (Nginx) -> Caches responses from PHP-FPM
                         Avoids hitting application for repeated requests

Application cache (Redis) -> Caches database query results
                             Avoids hitting MySQL for repeated queries

Database query cache -> MySQL caches query results internally
```

## Common Interview Questions

### Q: What happens when you type a URL in the browser?

**A:** Six main steps: (1) **DNS resolution** — browser resolves the domain to an IP address, checking browser cache, OS cache, and ISP resolver. (2) **TCP handshake** — three-way handshake (SYN, SYN-ACK, ACK) establishes a reliable connection. (3) **TLS handshake** — for HTTPS, client and server negotiate encryption and exchange keys. (4) **HTTP request** — browser sends GET request with headers (Host, Accept, Cookie). (5) **Server processing** — web server routes to application, which queries the database and generates HTML. (6) **Rendering** — browser parses HTML, fetches CSS/JS/images, builds DOM, and paints the page.

### Q: What is the difference between HTTP and HTTPS?

**A:** HTTPS adds a **TLS encryption layer** between TCP and HTTP. The data is encrypted in transit, so even if packets are intercepted (man-in-the-middle), they can't be read. HTTPS also provides **authentication** (the server proves its identity via a certificate signed by a trusted CA) and **integrity** (data can't be modified in transit without detection). The cost is 1-2 extra round trips for the TLS handshake, which is negligible with modern hardware.

### Q: How does DNS caching work?

**A:** DNS responses include a **TTL** (Time to Live) value that determines how long the result can be cached. When a browser resolves `shop.com` to `93.184.216.34` with TTL=3600, every layer in the chain (browser, OS, router, ISP resolver) caches this mapping for 1 hour. Subsequent requests skip the entire DNS hierarchy. Lower TTLs (300s) allow faster failover (e.g., switching to a backup server), while higher TTLs (86400s) reduce DNS lookup traffic but delay propagation of IP changes.

## Conclusion

A single URL request triggers DNS resolution, TCP and TLS handshakes, HTTP request-response, server-side processing, and browser rendering. Each layer — DNS, transport, security, application, caching — serves a specific purpose in making the web reliable, secure, and fast. HTTP/2 and CDN caching are the most impactful modern optimizations, eliminating connection overhead and reducing latency by serving content from edge locations close to the user.

## See Also

- [HTTP Protocol Structure](http_protocol_structure.md) — detailed request/response format
- [HTTP 4xx vs 5xx Errors](http_4xx_vs_5xx_errors.md) — status codes explained
- [What is CORS](cors.md) — cross-origin restrictions in browsers
- [What is CSRF](csrf.md) — how cookies work across requests
