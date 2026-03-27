PHP-FPM (FastCGI Process Manager) is the standard way to run PHP in production. It manages a pool of PHP worker processes that handle web requests. Nginx (or another web server) communicates with PHP-FPM using the FastCGI protocol.

### How PHP-FPM Works

PHP-FPM has a **master process** and **worker processes**.

#### Master Process

The master process starts when PHP-FPM is launched. Its job is:

- Read configuration files
- Create and manage worker processes
- Listen on a socket (TCP or Unix) for incoming requests
- Restart workers that crash or exceed memory/time limits

#### Worker Processes

Each worker process handles one request at a time. A worker:

1. Receives a FastCGI request from the master
2. Initializes the PHP environment (load extensions, autoload classes)
3. Executes the PHP script
4. Sends the response back through the master
5. Resets its state and waits for the next request

```text
Master Process (PID 1)
├── Worker 1 (PID 100) ← handling request
├── Worker 2 (PID 101) ← handling request
├── Worker 3 (PID 102) ← idle, waiting
├── Worker 4 (PID 103) ← idle, waiting
└── Worker 5 (PID 104) ← handling request
```

**Important:** Each worker handles only ONE request at a time. If all workers are busy, new requests wait in a queue (backlog). If the queue is full, requests are rejected.

### Process Manager Modes

PHP-FPM has three modes for managing the number of worker processes:

#### 1. `pm = static`

A fixed number of workers is always running.

```ini
pm = static
pm.max_children = 20
```

- Always exactly 20 workers
- Uses more memory when traffic is low
- Best when traffic is predictable and constant

#### 2. `pm = dynamic`

The number of workers adjusts based on demand.

```ini
pm = dynamic
pm.max_children = 50        ; maximum number of workers
pm.start_servers = 10       ; workers created on startup
pm.min_spare_servers = 5    ; minimum idle workers
pm.max_spare_servers = 15   ; maximum idle workers
```

- Starts with 10 workers
- If fewer than 5 idle workers → create more (up to 50)
- If more than 15 idle workers → kill extras
- Good balance between memory usage and performance

#### 3. `pm = ondemand`

Workers are created only when a request arrives. No workers when idle.

```ini
pm = ondemand
pm.max_children = 50
pm.process_idle_timeout = 10s  ; kill idle workers after 10 seconds
```

- Zero workers when there are no requests
- Saves memory on low-traffic servers
- Slightly slower for the first request (needs to start a worker)

### Key Configuration Options

```ini
[www]
; Socket — how Nginx connects to PHP-FPM
listen = /run/php/php8.2-fpm.sock     ; Unix socket (faster, same server)
; listen = 127.0.0.1:9000             ; TCP socket (can be on different server)

; Process management
pm = dynamic
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 15

; Safety limits
pm.max_requests = 500                  ; Restart worker after 500 requests (prevents memory leaks)
request_terminate_timeout = 30s        ; Kill worker if request takes longer than 30s
php_admin_value[memory_limit] = 256M   ; Max memory per worker
```

### How PHP-FPM Works with Nginx

Nginx is a web server that handles HTTP connections. It does **not** execute PHP code. Instead, it forwards PHP requests to PHP-FPM using the FastCGI protocol.

#### The Full Request Flow

```text
Client (Browser)
    │
    │ HTTP request: GET /api/users
    ▼
┌─────────┐
│  Nginx  │  1. Receives HTTP request
│         │  2. Checks location rules
│         │  3. Static files → serves directly
│         │  4. PHP files → forwards to PHP-FPM
└────┬────┘
     │ FastCGI protocol (via Unix socket or TCP)
     ▼
┌──────────┐
│ PHP-FPM  │  5. Master assigns request to a free worker
│ (Master) │
└────┬─────┘
     │
     ▼
┌──────────┐
│  Worker  │  6. Executes PHP script (index.php → router → controller)
│          │  7. Sends response back to master
└────┬─────┘
     │ FastCGI response
     ▼
┌─────────┐
│  Nginx  │  8. Receives PHP-FPM response
│         │  9. Sends HTTP response to client
└────┬────┘
     │ HTTP response
     ▼
Client (Browser)
```

#### Nginx Configuration

```nginx
server {
    listen 80;
    server_name example.com;
    root /var/www/project/public;

    # Serve static files directly (CSS, JS, images)
    location ~* \.(css|js|png|jpg|gif|ico)$ {
        expires 30d;
        access_log off;
    }

    # Forward PHP requests to PHP-FPM
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # Symfony/Laravel front controller pattern
    location / {
        try_files $uri /index.php$is_args$args;
    }
}
```

What happens:

1. Request for `/css/style.css` → Nginx serves the file directly (no PHP involved)
2. Request for `/api/users` → `try_files` fails → rewrites to `/index.php` → passes to PHP-FPM
3. PHP-FPM worker runs `index.php` → Symfony/Laravel router → controller → response

#### Why Nginx + PHP-FPM?

| Feature | Explanation |
|---------|-------------|
| Separation | Nginx handles HTTP, PHP-FPM handles PHP — each does what it's best at |
| Static files | Nginx serves static files very fast without involving PHP |
| Concurrency | Nginx handles thousands of connections with few threads (event-driven) |
| Buffering | Nginx buffers PHP-FPM response, so frees the worker faster |
| Load balancing | Nginx can distribute requests to multiple PHP-FPM pools or servers |

### Calculating `pm.max_children`

The most important setting. Too low → requests wait in queue. Too high → server runs out of memory.

Formula:

```text
max_children = Available Memory / Average Memory per Worker

Example:
  Server: 4 GB RAM
  OS + Nginx + MySQL: ~1.5 GB
  Available for PHP: 2.5 GB
  Average worker: ~50 MB

  max_children = 2500 MB / 50 MB = 50 workers
```

Check actual memory per worker:

```bash
# Show memory of PHP-FPM workers
ps -eo pid,rss,command | grep php-fpm | awk '{print $1, $2/1024 " MB", $3}'
```

### Monitoring PHP-FPM

Enable the status page:

```ini
; php-fpm pool config
pm.status_path = /fpm-status
```

```nginx
location /fpm-status {
    fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;
    allow 127.0.0.1;
    deny all;
}
```

```bash
curl http://localhost/fpm-status
# Shows: active processes, idle processes, total requests, listen queue length
```

Key metrics to watch:

- **listen queue** — requests waiting for a free worker (should be 0)
- **active processes** — workers currently handling requests
- **max children reached** — if this is > 0, you need more workers

### Real Scenario

You deploy a Symfony application on a server with 8 GB RAM:

```ini
; /etc/php/8.2/fpm/pool.d/www.conf

[www]
user = www-data
group = www-data

listen = /run/php/php8.2-fpm.sock
listen.owner = www-data

pm = dynamic
pm.max_children = 80          ; 8 GB - 3 GB (OS/DB) = 5 GB / ~60 MB per worker ≈ 80
pm.start_servers = 20
pm.min_spare_servers = 10
pm.max_spare_servers = 30
pm.max_requests = 1000        ; Restart worker after 1000 requests

request_terminate_timeout = 60s
php_admin_value[memory_limit] = 128M
```

```nginx
# /etc/nginx/sites-available/myapp.conf
server {
    listen 443 ssl http2;
    server_name myapp.com;
    root /var/www/myapp/public;

    location / {
        try_files $uri /index.php$is_args$args;
    }

    location ~ ^/index\.php(/|$) {
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        internal;
    }
}
```

Under load, you check `/fpm-status` and see `listen queue: 15`. This means 15 requests are waiting for a worker. You need to either increase `pm.max_children` (if you have spare memory) or optimize your PHP code to process requests faster.

### Conclusion

PHP-FPM manages a pool of worker processes. Each worker handles one request at a time. The master process creates, monitors, and kills workers based on the `pm` mode (static, dynamic, ondemand). Nginx handles HTTP connections and forwards PHP requests to PHP-FPM via FastCGI (Unix or TCP socket). Nginx serves static files directly, while PHP-FPM only handles PHP scripts. The key tuning parameter is `pm.max_children`, calculated from available memory divided by average memory per worker.
