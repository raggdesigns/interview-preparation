JavaScript is single-threaded — it can only do one thing at a time. But it handles asynchronous operations (network requests, timers, file reads) through an **event loop** and non-blocking I/O. Promises, async/await, and fetch are the modern tools for working with async code.

### The Problem — Why Async?

```javascript
// Without async, this would freeze the browser/Node.js:
const response = httpGetSync("https://api.example.com/users");  // Blocks for 2 seconds
console.log(response);  // Nothing happens until the request completes
renderPage();            // User waits 2 seconds with a frozen page

// With async, the program continues while waiting:
fetch("https://api.example.com/users")    // Starts request, returns immediately
    .then(response => response.json())     // Runs when response arrives
    .then(data => console.log(data));      // Runs when JSON is parsed
renderPage();  // Runs immediately — page is not frozen
```

### Callbacks — The Old Way

Before Promises, async code used callbacks:

```javascript
// Callback pattern
function getUser(id, callback) {
    setTimeout(function() {
        callback(null, { id: id, name: "Dragan" });
    }, 1000);
}

getUser(42, function(error, user) {
    if (error) {
        console.error(error);
        return;
    }
    console.log(user.name);
});
```

**Callback Hell** — nested callbacks become unreadable:

```javascript
getUser(42, function(err, user) {
    getOrders(user.id, function(err, orders) {
        getOrderDetails(orders[0].id, function(err, details) {
            getShippingInfo(details.shippingId, function(err, shipping) {
                console.log(shipping.status);  // 4 levels deep!
            });
        });
    });
});
```

Promises and async/await solve this problem.

### Promises

A Promise represents a value that will be available **in the future**. It has three states:

- **Pending** — initial state, operation in progress
- **Fulfilled** (resolved) — operation completed successfully
- **Rejected** — operation failed

```javascript
// Creating a Promise
const promise = new Promise(function(resolve, reject) {
    // Async operation
    setTimeout(function() {
        const success = true;
        if (success) {
            resolve({ id: 42, name: "Dragan" });  // Fulfilled
        } else {
            reject(new Error("User not found"));    // Rejected
        }
    }, 1000);
});

// Using a Promise
promise
    .then(function(user) {
        console.log(user.name);  // "Dragan" — runs on success
    })
    .catch(function(error) {
        console.error(error.message);  // Runs on failure
    })
    .finally(function() {
        console.log("Done");  // Runs always (success or failure)
    });
```

### Promise Chaining

Each `.then()` returns a new Promise, so you can chain them:

```javascript
// Flat chain instead of nested callbacks
getUser(42)
    .then(user => getOrders(user.id))
    .then(orders => getOrderDetails(orders[0].id))
    .then(details => getShippingInfo(details.shippingId))
    .then(shipping => console.log(shipping.status))
    .catch(error => console.error("Something failed:", error.message));
```

Compare this to the callback hell example above — much cleaner.

### Promise.all, Promise.race, Promise.allSettled

```javascript
// Promise.all — wait for ALL promises to complete
// Fails fast: if any promise rejects, the whole thing rejects
const [users, orders, products] = await Promise.all([
    fetch("/api/users").then(r => r.json()),
    fetch("/api/orders").then(r => r.json()),
    fetch("/api/products").then(r => r.json()),
]);
// All three requests run in PARALLEL, not one after another

// Promise.race — returns the FIRST promise to complete (success or failure)
const fastest = await Promise.race([
    fetch("https://api1.example.com/data"),
    fetch("https://api2.example.com/data"),
]);

// Promise.allSettled — wait for ALL, even if some fail
const results = await Promise.allSettled([
    fetch("/api/users"),
    fetch("/api/broken-endpoint"),  // This might fail
    fetch("/api/products"),
]);
// results = [
//   { status: "fulfilled", value: Response },
//   { status: "rejected", reason: Error },
//   { status: "fulfilled", value: Response },
// ]
```

### Async/Await

`async/await` is syntactic sugar over Promises. It makes async code look like synchronous code:

```javascript
// With Promises
function loadUser(id) {
    return fetch(`/api/users/${id}`)
        .then(response => response.json())
        .then(user => {
            console.log(user.name);
            return user;
        })
        .catch(error => {
            console.error("Failed:", error);
        });
}

// With async/await — same logic, easier to read
async function loadUser(id) {
    try {
        const response = await fetch(`/api/users/${id}`);
        const user = await response.json();
        console.log(user.name);
        return user;
    } catch (error) {
        console.error("Failed:", error);
    }
}
```

**Rules:**

- `await` can only be used inside an `async` function
- `await` pauses the function execution until the Promise resolves
- `async` functions always return a Promise

```javascript
// Sequential — one after another (slow)
async function loadData() {
    const users = await fetch("/api/users").then(r => r.json());      // Wait 500ms
    const orders = await fetch("/api/orders").then(r => r.json());    // Wait 500ms
    const products = await fetch("/api/products").then(r => r.json()); // Wait 500ms
    // Total: ~1500ms
}

// Parallel — all at once (fast)
async function loadData() {
    const [users, orders, products] = await Promise.all([
        fetch("/api/users").then(r => r.json()),
        fetch("/api/orders").then(r => r.json()),
        fetch("/api/products").then(r => r.json()),
    ]);
    // Total: ~500ms (longest single request)
}
```

### Fetch API

`fetch()` is the modern way to make HTTP requests in JavaScript. It returns a Promise.

```javascript
// GET request
const response = await fetch("https://api.example.com/users");
const users = await response.json();

// POST request
const response = await fetch("https://api.example.com/users", {
    method: "POST",
    headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer eyJhbGciOi...",
    },
    body: JSON.stringify({
        name: "Dragan",
        email: "dragan@example.com",
    }),
});

if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
}

const newUser = await response.json();
console.log(newUser.id);  // 42
```

**Important:** `fetch()` does NOT reject on HTTP errors (404, 500). It only rejects on network failures. You must check `response.ok`:

```javascript
// BAD — this does NOT catch 404 or 500 errors
fetch("/api/users/999")
    .then(response => response.json())  // Runs even on 404!
    .catch(error => console.error(error));  // Only catches network failures

// GOOD — check response.ok
async function getUser(id) {
    const response = await fetch(`/api/users/${id}`);
    
    if (!response.ok) {
        if (response.status === 404) {
            throw new Error("User not found");
        }
        throw new Error(`Server error: ${response.status}`);
    }
    
    return response.json();
}
```

### Fetch vs Axios vs XMLHttpRequest

| Feature | fetch | Axios | XMLHttpRequest |
|---------|-------|-------|---------------|
| Built-in | Yes (modern browsers + Node 18+) | No (library) | Yes (old) |
| Returns | Promise | Promise | Uses callbacks |
| Error handling | Must check `response.ok` | Rejects on 4xx/5xx | Manual |
| Request cancel | AbortController | CancelToken | abort() |
| JSON parsing | Manual (`.json()`) | Automatic | Manual |
| Interceptors | No | Yes | No |

### The Event Loop

Understanding why async works requires knowing the event loop:

```text
┌───────────────────────────┐
│        Call Stack          │  ← Executes synchronous code
│  (one thing at a time)    │
└───────────┬───────────────┘
            │
            ▼
┌───────────────────────────┐
│       Web APIs /          │  ← Handles async operations
│     Node.js APIs          │     (setTimeout, fetch, I/O)
└───────────┬───────────────┘
            │
            ▼
┌───────────────────────────┐
│     Callback Queue        │  ← Queued callbacks waiting
│  (Task Queue + Microtask) │     to run
└───────────┬───────────────┘
            │
            ▼
┌───────────────────────────┐
│       Event Loop          │  ← Moves callbacks from queue
│   "Is call stack empty?"  │     to call stack when it's empty
└───────────────────────────┘
```

```javascript
console.log("1");                         // Sync — runs immediately

setTimeout(() => console.log("2"), 0);    // Async — goes to task queue

Promise.resolve().then(() => console.log("3"));  // Async — goes to microtask queue

console.log("4");                         // Sync — runs immediately

// Output: 1, 4, 3, 2
// Why? Microtasks (Promises) run before regular tasks (setTimeout)
```

### Error Handling Patterns

```javascript
// Pattern 1: try/catch with async/await
async function processOrder(orderId) {
    try {
        const order = await getOrder(orderId);
        const payment = await processPayment(order);
        const shipment = await createShipment(order);
        return { order, payment, shipment };
    } catch (error) {
        // Catches errors from any of the three await calls
        console.error("Order processing failed:", error.message);
        throw error;  // Re-throw if caller should handle it
    }
}

// Pattern 2: individual error handling
async function loadDashboard() {
    const [usersResult, ordersResult] = await Promise.allSettled([
        fetch("/api/users").then(r => r.json()),
        fetch("/api/orders").then(r => r.json()),
    ]);

    const users = usersResult.status === "fulfilled" ? usersResult.value : [];
    const orders = ordersResult.status === "fulfilled" ? ordersResult.value : [];

    return { users, orders };
    // Dashboard loads even if one API call fails
}
```

### Conclusion

JavaScript handles async operations through Promises and the event loop. Promises represent future values with three states (pending, fulfilled, rejected). Async/await is syntactic sugar that makes Promise chains readable. `fetch()` is the built-in HTTP client that returns Promises — remember to check `response.ok` for HTTP errors. Use `Promise.all()` to run independent requests in parallel. The event loop processes microtasks (Promises) before macrotasks (setTimeout). These concepts appear frequently in interviews even for backend developers because modern applications heavily interact with JavaScript frontends.

> See also: [Functions, arrow functions, and closures](js_fundamentals.md), [REST API architecture](../general/rest_api_architecture.md), [HTTP streaming](../general/http_streaming.md)
