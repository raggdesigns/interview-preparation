# HTTP Streaming

Traditional HTTP follows a request-response cycle: the client sends a request, waits for the server to finish processing, and receives the complete response at once. HTTP streaming breaks this pattern by sending data in chunks as it becomes available, enabling real-time updates without repeated polling.

> **Scenario used throughout this document:** A dashboard that shows live order status updates for an e-commerce admin panel.

## Prerequisites

- [HTTP Protocol Structure](http_protocol_structure.md) — standard request-response format
- [How the Internet Works](how_internet_works.md) — network fundamentals

## Polling vs Streaming

```text
Polling (every 2s):
  Client ──GET──→ Server    "Any updates?"  → "No"
  Client ──GET──→ Server    "Any updates?"  → "No"
  Client ──GET──→ Server    "Any updates?"  → "Yes: order #42 shipped"
  Client ──GET──→ Server    "Any updates?"  → "No"
  Problem: Wasted requests, delayed updates (up to 2s lag)

Streaming (one connection):
  Client ──GET──→ Server    "Send me updates"
                  Server ──→ "order #42 shipped"
                  Server ──→ "order #43 paid"
                  Server ──→ "order #44 cancelled"
  (connection stays open, updates arrive instantly)
```

## Server-Sent Events (SSE)

SSE is a standard for server-to-client streaming over HTTP. The server sends events as plain text over a long-lived connection.

### SSE Protocol Format

```text
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive

event: orderUpdate
data: {"id": 42, "status": "shipped"}

event: orderUpdate
data: {"id": 43, "status": "paid"}

event: heartbeat
data: ping
```

Rules:

- Each field is on its own line: `event:`, `data:`, `id:`, `retry:`
- Events are separated by a blank line
- `Content-Type` must be `text/event-stream`
- `id:` allows the client to resume from where it left off after reconnection

### PHP SSE Implementation (Symfony)

```php
<?php

namespace App\Controller;

use App\Repository\OrderRepository;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Symfony\Component\Routing\Attribute\Route;

final class OrderStreamController
{
    public function __construct(
        private readonly OrderRepository $orderRepository,
    ) {}

    #[Route('/api/orders/stream', methods: ['GET'])]
    public function stream(): StreamedResponse
    {
        $response = new StreamedResponse(function (): void {
            header('Content-Type: text/event-stream');
            header('Cache-Control: no-cache');
            header('X-Accel-Buffering: no'); // Disable Nginx buffering

            $lastCheck = new \DateTimeImmutable();

            while (true) {
                $updates = $this->orderRepository->findUpdatedSince($lastCheck);

                foreach ($updates as $order) {
                    echo "event: orderUpdate\n";
                    echo "data: " . json_encode([
                        'id' => $order->getId(),
                        'status' => $order->getStatus(),
                        'updatedAt' => $order->getUpdatedAt()->format('c'),
                    ]) . "\n\n";
                }

                // Heartbeat to keep connection alive
                echo ": heartbeat\n\n";

                // Flush output buffers — critical for streaming
                if (ob_get_level() > 0) {
                    ob_flush();
                }
                flush();

                $lastCheck = new \DateTimeImmutable();
                sleep(2);
            }
        });

        return $response;
    }
}
```

### JavaScript Client (EventSource)

```javascript
const source = new EventSource('/api/orders/stream');

source.addEventListener('orderUpdate', (event) => {
    const order = JSON.parse(event.data);
    console.log(`Order #${order.id}: ${order.status}`);
    updateDashboard(order);
});

source.onerror = () => {
    console.log('Connection lost, reconnecting...');
    // EventSource automatically reconnects
};
```

**Key advantage:** `EventSource` handles reconnection automatically. If the connection drops, the browser reconnects and sends the last received `id` via `Last-Event-ID` header.

## Chunked Transfer Encoding

Chunked encoding sends the response body in pieces, allowing the server to start transmitting before it knows the total size. This is useful for large data exports.

### HTTP Format

```text
HTTP/1.1 200 OK
Transfer-Encoding: chunked

1a\r\n
This is the first chunk.\r\n
1c\r\n
This is the second chunk.\r\n
0\r\n
\r\n
```

Each chunk starts with its size in hexadecimal, followed by the data. A zero-length chunk signals the end.

### PHP CSV Export with Chunked Streaming

```php
<?php

namespace App\Controller;

use App\Repository\OrderRepository;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Symfony\Component\Routing\Attribute\Route;

final class ExportController
{
    public function __construct(
        private readonly OrderRepository $orderRepository,
    ) {}

    #[Route('/api/orders/export.csv', methods: ['GET'])]
    public function exportCsv(): StreamedResponse
    {
        return new StreamedResponse(function (): void {
            $handle = fopen('php://output', 'w');
            fputcsv($handle, ['ID', 'Customer', 'Total', 'Status', 'Date']);

            // Stream 100,000 rows without loading all into memory
            $batchSize = 1000;
            $offset = 0;

            while (true) {
                $orders = $this->orderRepository->findBatch($offset, $batchSize);

                if (empty($orders)) {
                    break;
                }

                foreach ($orders as $order) {
                    fputcsv($handle, [
                        $order->getId(),
                        $order->getCustomerName(),
                        $order->getTotal(),
                        $order->getStatus(),
                        $order->getCreatedAt()->format('Y-m-d'),
                    ]);
                }

                flush();
                $offset += $batchSize;
            }

            fclose($handle);
        }, 200, [
            'Content-Type' => 'text/csv',
            'Content-Disposition' => 'attachment; filename="orders.csv"',
        ]);
    }
}
```

This streams rows to the client as they're queried — constant memory usage regardless of dataset size.

## Comparison Table

| Aspect | SSE | WebSocket | Long Polling |
|--------|-----|-----------|-------------|
| Direction | Server → Client only | Bidirectional | Server → Client |
| Protocol | HTTP | WebSocket (upgrade from HTTP) | HTTP |
| Reconnection | Automatic (built-in) | Manual | Manual |
| Data format | Text only | Text and binary | Any |
| Browser support | All modern browsers | All modern browsers | All browsers |
| Through proxies | Works (it's HTTP) | May require config | Works |
| Best for | Live feeds, notifications | Chat, gaming, real-time collab | Legacy browsers |

**When to choose what:**

- **SSE** — Server pushes updates to client (dashboards, notifications, live feeds). Simple, no special server needed.
- **WebSocket** — Client and server both send messages (chat, multiplayer games, collaborative editing).
- **Long Polling** — Fallback when SSE/WebSocket aren't available. Client sends request, server holds it until data is ready.

## Production Considerations

### Nginx Configuration for SSE

```nginx
location /api/orders/stream {
    proxy_pass http://php-fpm-backend;

    # Disable buffering — critical for streaming
    proxy_buffering off;
    proxy_cache off;

    # Disable Nginx timeout for long-lived connections
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;

    # SSE-specific headers
    add_header Cache-Control no-cache;
    add_header X-Accel-Buffering no;
}
```

### PHP-FPM Worker Exhaustion

Each SSE connection holds a PHP-FPM worker for the entire duration. With 50 FPM workers and 50 SSE connections, no workers are left for regular requests.

```text
Solutions:
1. Use a dedicated FPM pool for streaming endpoints (separate worker limit)
2. Use ReactPHP/Swoole for SSE (single process handles thousands of connections)
3. Offload to a purpose-built service (Mercure, Centrifugo)
4. Set a maximum connection time and let EventSource reconnect
```

## Common Interview Questions

### Q: What is the difference between SSE and WebSocket?

**A:** **SSE** is unidirectional (server to client only), uses standard HTTP, automatically reconnects, and only supports text data. **WebSocket** is bidirectional, uses its own protocol (upgraded from HTTP), requires manual reconnection handling, and supports binary data. Choose SSE for server-push scenarios (notifications, live feeds) and WebSocket when the client also needs to send messages (chat, gaming).

### Q: How do you handle streaming without running out of PHP-FPM workers?

**A:** Each SSE connection occupies one FPM worker for the full connection lifetime. Solutions: (1) use a **dedicated FPM pool** with separate `pm.max_children` for streaming endpoints, (2) use an **async runtime** like ReactPHP or Swoole that can handle thousands of connections in a single process, or (3) offload to a **dedicated streaming service** like Mercure that integrates with Symfony.

### Q: When would you choose chunked encoding over SSE?

**A:** Chunked encoding is for **large one-time responses** where you want to start sending data before the full response is ready (CSV export, large report generation). SSE is for **ongoing real-time updates** where the connection stays open indefinitely. Chunked encoding ends when the data is complete; SSE keeps the connection open until the client disconnects.

## Conclusion

HTTP streaming eliminates the overhead of repeated polling by keeping a connection open for real-time data delivery. SSE is the simplest option for server-to-client updates (built-in reconnection, standard HTTP), while WebSocket enables bidirectional communication. In PHP, Symfony's `StreamedResponse` handles both SSE and chunked downloads, but production deployments must account for FPM worker limits via dedicated pools, async runtimes, or dedicated streaming services.

## See Also

- [HTTP Protocol Structure](http_protocol_structure.md) — standard request/response format
- [Concurrency vs Parallelism](concurrency_vs_parallelism.md) — async processing concepts
- [REST API Architecture](rest_api_architecture.md) — standard API design patterns
