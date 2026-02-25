HTTP status codes are three-digit numbers that tell the client what happened with their request. They are grouped by the first digit. The two most important groups for interviews are **4xx** (client errors) and **5xx** (server errors).

### The Difference

- **4xx errors** mean the **client** made a mistake. The request was wrong, unauthorized, or the resource does not exist. The client needs to fix the request before trying again.
- **5xx errors** mean the **server** had a problem. The request might be valid, but the server could not process it. The client can try again later.

### 4xx — Client Errors

| Code | Name | Meaning |
|------|------|---------|
| 400 | Bad Request | The request is malformed or has invalid data |
| 401 | Unauthorized | Authentication is missing or invalid (not logged in) |
| 403 | Forbidden | Authenticated but not allowed to access this resource |
| 404 | Not Found | The resource does not exist |
| 405 | Method Not Allowed | HTTP method not supported (e.g., POST to a GET-only endpoint) |
| 409 | Conflict | Request conflicts with current state (e.g., duplicate entry) |
| 422 | Unprocessable Entity | Request syntax is correct but data validation failed |
| 429 | Too Many Requests | Rate limit exceeded — client is sending too many requests |

#### Common Confusion: 401 vs 403

- **401 Unauthorized** — "Who are you?" — no authentication provided, or token is expired
- **403 Forbidden** — "I know who you are, but you cannot do this" — authenticated but lacks permission

```
# No token — 401
GET /api/admin/users
→ 401 Unauthorized

# Valid token, but user is not admin — 403
GET /api/admin/users
Authorization: Bearer user-token-123
→ 403 Forbidden
```

#### Common Confusion: 400 vs 422

- **400 Bad Request** — the request itself is broken (invalid JSON, wrong content type)
- **422 Unprocessable Entity** — the request is well-formed but data is invalid (email format wrong, required field missing)

```
# Broken JSON — 400
POST /api/users
Content-Type: application/json
Body: {name: Alice   ← invalid JSON syntax

# Valid JSON, but invalid data — 422
POST /api/users
Content-Type: application/json
Body: {"name": "", "email": "not-an-email"}
→ 422 with validation errors
```

### 5xx — Server Errors

| Code | Name | Meaning |
|------|------|---------|
| 500 | Internal Server Error | Unhandled exception or bug in the server code |
| 502 | Bad Gateway | Reverse proxy (Nginx) got an invalid response from the backend (PHP-FPM) |
| 503 | Service Unavailable | Server is overloaded or under maintenance |
| 504 | Gateway Timeout | Reverse proxy waited too long for the backend to respond |

#### Common Confusion: 502 vs 504

- **502 Bad Gateway** — the upstream server (PHP-FPM) responded, but the response was invalid or the process crashed
- **504 Gateway Timeout** — the upstream server did not respond at all within the time limit

```
Nginx → PHP-FPM

502: PHP-FPM process crashed or returned garbage → Nginx can't understand the response
504: PHP-FPM is still processing after 60 seconds → Nginx gives up waiting
```

### When to Return Each Code (for API developers)

```php
// 400 — Malformed request
if (!json_decode($request->getContent())) {
    return new JsonResponse(['error' => 'Invalid JSON'], 400);
}

// 401 — No authentication
if (!$request->headers->has('Authorization')) {
    return new JsonResponse(['error' => 'Authentication required'], 401);
}

// 403 — No permission
if (!$user->hasRole('ADMIN')) {
    return new JsonResponse(['error' => 'Access denied'], 403);
}

// 404 — Resource not found
$product = $repository->find($id);
if ($product === null) {
    return new JsonResponse(['error' => 'Product not found'], 404);
}

// 409 — Conflict
$existing = $repository->findByEmail($email);
if ($existing !== null) {
    return new JsonResponse(['error' => 'Email already registered'], 409);
}

// 422 — Validation error
$errors = $validator->validate($dto);
if (count($errors) > 0) {
    return new JsonResponse(['errors' => $errors], 422);
}

// 429 — Rate limit
if ($rateLimiter->isExceeded($user)) {
    return new JsonResponse(['error' => 'Too many requests'], 429);
}
```

### Full Status Code Groups

For completeness, here are all five groups:

| Group | Meaning | Examples |
|-------|---------|---------|
| 1xx | Informational | 100 Continue, 101 Switching Protocols |
| 2xx | Success | 200 OK, 201 Created, 204 No Content |
| 3xx | Redirection | 301 Moved Permanently, 302 Found, 304 Not Modified |
| 4xx | Client Error | 400, 401, 403, 404, 422 |
| 5xx | Server Error | 500, 502, 503, 504 |

### Real Scenario

A user tries to update their profile through an API:

```
1. User sends request without token:
   PUT /api/profile  →  401 Unauthorized

2. User logs in and sends request with token, but wrong JSON:
   PUT /api/profile  →  400 Bad Request

3. User fixes JSON but email is invalid:
   PUT /api/profile {"email": "bad"}  →  422 Unprocessable Entity

4. User sends valid data:
   PUT /api/profile {"email": "alice@test.com"}  →  200 OK

5. Meanwhile, the database server goes down:
   PUT /api/profile {"email": "alice@test.com"}  →  500 Internal Server Error

6. Nginx detects PHP-FPM is not responding:
   PUT /api/profile  →  502 Bad Gateway
```

Each status code helps the client understand what went wrong and what to do next.

### Conclusion

4xx errors are the client's fault — wrong request, missing auth, resource not found. 5xx errors are the server's fault — bugs, crashes, timeouts. The most important ones to know: 400 (bad request), 401 (not authenticated), 403 (not authorized), 404 (not found), 422 (validation failed), 500 (server bug), 502 (bad gateway), 503 (overloaded), 504 (timeout).
