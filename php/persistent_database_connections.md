A persistent database connection is a connection that stays open after a PHP script finishes. The next script that needs to connect to the same database can reuse this existing connection instead of creating a new one.

### How Normal Connections Work

In a typical PHP request:

1. PHP script starts
2. Opens a new database connection
3. Runs queries
4. Closes the connection
5. Script ends

This means **every request** creates and destroys a connection. Creating a connection is expensive — it involves network communication, authentication, and memory allocation.

### How Persistent Connections Work

With persistent connections:

1. First request: PHP opens a connection and marks it as persistent
2. Script ends, but the connection **stays open**
3. Next request: PHP finds the existing connection and reuses it
4. No need to create a new connection — saves time

### How to Use Persistent Connections

#### With PDO

Add `ATTR_PERSISTENT` option:

```php
// Normal connection (closes after script)
$pdo = new PDO('mysql:host=localhost;dbname=myapp', 'user', 'password');

// Persistent connection (stays open for reuse)
$pdo = new PDO('mysql:host=localhost;dbname=myapp', 'user', 'password', [
    PDO::ATTR_PERSISTENT => true
]);
```

#### With MySQLi

Use `p:` prefix before hostname:

```php
// Normal connection
$conn = new mysqli('localhost', 'user', 'password', 'myapp');

// Persistent connection
$conn = new mysqli('p:localhost', 'user', 'password', 'myapp');
```

### Benefits

- **Faster Response Time**: Skipping connection creation saves 10-50ms per request.
- **Less Load on Database Server**: Fewer connection/disconnection operations.
- **Better Performance Under Load**: When many users send requests at the same time.

### Problems and Risks

- **Connection Limit**: Each persistent connection stays open. If you have 100 PHP workers, you may have 100 open connections — even if most are idle. This can exhaust the database's connection limit.
- **Dirty State**: A previous script might have changed the connection state (e.g., started an uncommitted transaction, set a different charset, or created temporary tables). The next script inherits this state.
- **Memory Usage**: Open connections use memory on both PHP and database sides.
- **Not Useful with Short-lived Processes**: Only works with long-running PHP processes like PHP-FPM, not with CGI.

### How to Handle Dirty State

Always reset the connection state at the beginning of your script:

```php
$pdo = new PDO('mysql:host=localhost;dbname=myapp', 'user', 'password', [
    PDO::ATTR_PERSISTENT => true
]);

// Reset any leftover state from previous scripts
$pdo->exec('SET NAMES utf8mb4');
$pdo->setAttribute(PDO::ATTR_AUTOCOMMIT, 1);
```

### Real Scenario

You have a REST API that serves 1000 requests per second. Each request makes one query and takes 50ms total. Without persistent connections, 20ms of that is spent just opening the connection. With persistent connections, that drops to nearly 0ms — a 40% speedup.

However, your MySQL server allows only 150 connections. If you run 200 PHP-FPM workers with persistent connections, you'll exceed the limit and get "Too many connections" errors. You need to balance the number of PHP workers with the database connection limit.

### When to Use Persistent Connections

| Use | Don't Use |
|-----|-----------|
| High-traffic applications | Low-traffic websites |
| PHP-FPM with connection pooling | CGI mode |
| Simple query patterns | Complex transactions per request |
| When connection time is a bottleneck | When you can't control max connections |

### Conclusion

Persistent connections can improve performance by reusing database connections across requests. However, they come with risks like connection limit problems and dirty state. Use them when the connection creation time is a real bottleneck, and make sure to reset the connection state at the start of each request.
