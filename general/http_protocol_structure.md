HTTP (HyperText Transfer Protocol) is a text-based protocol used for communication between a client (usually a browser) and a server. Every HTTP interaction consists of a request sent by the client and a response returned by the server.

### HTTP Request Structure

An HTTP request has four parts:

```text
[METHOD] [URL] [HTTP VERSION]
[HEADERS]
[EMPTY LINE]
[BODY (optional)]
```

#### Real example

```text
POST /api/users HTTP/1.1
Host: example.com
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJIUz...
Content-Length: 45

{"name": "Alice", "email": "alice@test.com"}
```

#### 1. Request Line

The first line contains three parts:

- **Method** — what action to perform: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `OPTIONS`, `HEAD`
- **URL** (path) — the resource: `/api/users`, `/products/123`
- **HTTP version** — usually `HTTP/1.1` or `HTTP/2`

#### 2. Headers

Headers provide extra information about the request. Each header is a key-value pair:

| Header | Purpose | Example |
|--------|---------|---------|
| `Host` | Target server | `example.com` |
| `Content-Type` | Format of the body | `application/json` |
| `Authorization` | Authentication credentials | `Bearer token123` |
| `Accept` | What format the client expects in response | `application/json` |
| `Content-Length` | Size of the body in bytes | `45` |
| `Cookie` | Session/cookie data | `session_id=abc123` |
| `User-Agent` | Client identification | `Mozilla/5.0...` |

#### 3. Empty Line

A blank line separates headers from the body. It tells the server "headers are done, body starts next."

#### 4. Body (optional)

The body contains data sent to the server. GET and DELETE requests usually have no body. POST, PUT, and PATCH usually have a body.

### HTTP Response Structure

An HTTP response also has four parts:

```text
[HTTP VERSION] [STATUS CODE] [STATUS TEXT]
[HEADERS]
[EMPTY LINE]
[BODY]
```

#### Real example

```text
HTTP/1.1 201 Created
Content-Type: application/json
Location: /api/users/42
X-Request-Id: abc-123

{"id": 42, "name": "Alice", "email": "alice@test.com"}
```

#### 1. Status Line

- **HTTP version** — `HTTP/1.1`
- **Status code** — a number that tells the result: `200`, `404`, `500`
- **Status text** — human-readable description: `OK`, `Not Found`, `Internal Server Error`

#### 2. Response Headers

| Header | Purpose | Example |
|--------|---------|---------|
| `Content-Type` | Format of the response body | `application/json` |
| `Content-Length` | Size of the body | `62` |
| `Location` | URL of newly created resource | `/api/users/42` |
| `Set-Cookie` | Send cookies to the client | `session_id=abc; HttpOnly` |
| `Cache-Control` | Caching rules | `max-age=3600` |
| `Access-Control-Allow-Origin` | CORS header | `*` |

#### 3. Body

The actual data returned by the server — HTML page, JSON response, image, file, etc.

### HTTP/1.1 vs HTTP/2

| Feature | HTTP/1.1 | HTTP/2 |
|---------|----------|--------|
| Format | Text-based | Binary |
| Connections | One request per connection (or keep-alive) | Multiple requests on one connection (multiplexing) |
| Header compression | No | Yes (HPACK) |
| Server push | No | Yes (server can send resources before client asks) |
| Priority | No | Yes (client can prioritize requests) |

HTTP/1.1 sends requests one after another on a connection. If one request is slow, it blocks the rest (head-of-line blocking). HTTP/2 solves this by multiplexing — sending multiple requests and responses at the same time on a single connection.

```text
HTTP/1.1:
Client ──req1──> Server ──res1──> Client ──req2──> Server ──res2──>

HTTP/2:
Client ──req1──> 
       ──req2──> Server ──res2──>
       ──req3──>        ──res1──>
                        ──res3──>
```

### HTTP Methods Summary

| Method | Purpose | Has Body | Idempotent | Safe |
|--------|---------|----------|------------|------|
| GET | Read a resource | No | Yes | Yes |
| POST | Create a resource | Yes | No | No |
| PUT | Replace a resource | Yes | Yes | No |
| PATCH | Partially update | Yes | No | No |
| DELETE | Remove a resource | Usually no | Yes | No |
| OPTIONS | Get allowed methods | No | Yes | Yes |
| HEAD | Same as GET but no body | No | Yes | Yes |

**Idempotent** means calling it multiple times gives the same result. **Safe** means it does not change anything on the server.

### Real Scenario

A browser loads a web page. Here is what happens:

```text
1. Browser sends:
   GET /index.html HTTP/1.1
   Host: example.com
   Accept: text/html

2. Server responds:
   HTTP/1.1 200 OK
   Content-Type: text/html
   Content-Length: 1234
   
   <html>...</html>

3. Browser sees <img src="/logo.png"> in HTML, sends another request:
   GET /logo.png HTTP/1.1
   Host: example.com
   Accept: image/png

4. Server responds:
   HTTP/1.1 200 OK
   Content-Type: image/png
   Content-Length: 5678
   
   [binary image data]
```

With HTTP/2, requests 1 and 3 could happen at the same time on one connection instead of waiting for each other.

### Conclusion

An HTTP request contains a method, URL, headers, and optional body. An HTTP response contains a status code, headers, and body. HTTP/1.1 is text-based and processes requests sequentially. HTTP/2 is binary, supports multiplexing (parallel requests on one connection), header compression, and server push. Understanding this structure helps when debugging API calls, reading server logs, or configuring web servers.
