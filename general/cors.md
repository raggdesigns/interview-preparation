CORS (Cross-Origin Resource Sharing) is a browser security mechanism that controls which websites can make requests to your server from a different domain. It is based on the **Same-Origin Policy**.

### Same-Origin Policy

By default, browsers block JavaScript from making requests to a different origin. An "origin" is the combination of **protocol + domain + port**:

```
https://example.com:443  — this is one origin

Same origin:
  https://example.com/api/users      ✓ (same protocol, domain, port)
  https://example.com/other-page     ✓

Different origin:
  http://example.com                 ✗ (different protocol — http vs https)
  https://api.example.com            ✗ (different subdomain)
  https://example.com:8080           ✗ (different port)
  https://other-site.com             ✗ (different domain)
```

Without CORS, if your frontend is at `https://frontend.com` and your API is at `https://api.backend.com`, the browser will block all API requests from the frontend.

### How CORS Works

CORS uses HTTP headers to tell the browser: "This other origin is allowed to access my resources."

#### Simple Requests

For simple requests (GET, POST with basic content types), the browser sends the request directly and checks the response headers:

```
1. Browser at https://frontend.com makes request:
   GET /api/users
   Origin: https://frontend.com

2. Server responds:
   HTTP/1.1 200 OK
   Access-Control-Allow-Origin: https://frontend.com
   
   [data]

3. Browser checks the header:
   - Does Access-Control-Allow-Origin match our origin? → Yes → allow the response
   - If header is missing or doesn't match → block the response
```

#### Preflight Requests

For "non-simple" requests (PUT, DELETE, custom headers, JSON content type), the browser first sends an OPTIONS request called a **preflight**:

```
1. Browser wants to send:
   DELETE /api/users/123
   Origin: https://frontend.com
   Content-Type: application/json

2. Browser first sends preflight:
   OPTIONS /api/users/123
   Origin: https://frontend.com
   Access-Control-Request-Method: DELETE
   Access-Control-Request-Headers: Content-Type

3. Server responds to preflight:
   HTTP/1.1 204 No Content
   Access-Control-Allow-Origin: https://frontend.com
   Access-Control-Allow-Methods: GET, POST, PUT, DELETE
   Access-Control-Allow-Headers: Content-Type, Authorization
   Access-Control-Max-Age: 3600

4. Browser checks: is DELETE allowed from this origin? → Yes → sends the actual request
   DELETE /api/users/123
   Origin: https://frontend.com
   
5. Server responds:
   HTTP/1.1 200 OK
   Access-Control-Allow-Origin: https://frontend.com
```

### CORS Headers Explained

#### Response Headers (sent by server):

| Header | Purpose | Example |
|--------|---------|---------|
| `Access-Control-Allow-Origin` | Which origin is allowed | `https://frontend.com` or `*` |
| `Access-Control-Allow-Methods` | Which HTTP methods are allowed | `GET, POST, PUT, DELETE` |
| `Access-Control-Allow-Headers` | Which request headers are allowed | `Content-Type, Authorization` |
| `Access-Control-Allow-Credentials` | Allow cookies/auth headers | `true` |
| `Access-Control-Max-Age` | Cache preflight result (seconds) | `3600` |
| `Access-Control-Expose-Headers` | Headers the browser can read | `X-Total-Count` |

#### Important Rules:

- `Access-Control-Allow-Origin: *` — allows any origin, but **cannot** be used with credentials
- To allow credentials (cookies), you must specify the exact origin and set `Allow-Credentials: true`

```
# Allow any origin (no credentials)
Access-Control-Allow-Origin: *

# Allow specific origin with credentials
Access-Control-Allow-Origin: https://frontend.com
Access-Control-Allow-Credentials: true
```

### Configuring CORS in Nginx

```nginx
server {
    listen 443 ssl;
    server_name api.example.com;

    location /api/ {
        # Handle preflight
        if ($request_method = OPTIONS) {
            add_header Access-Control-Allow-Origin "https://frontend.example.com";
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
            add_header Access-Control-Allow-Headers "Content-Type, Authorization";
            add_header Access-Control-Max-Age 3600;
            return 204;
        }

        # Regular requests
        add_header Access-Control-Allow-Origin "https://frontend.example.com";
        add_header Access-Control-Allow-Credentials "true";

        fastcgi_pass unix:/var/run/php-fpm.sock;
        # ...
    }
}
```

### Configuring CORS in Symfony

Using the `nelmio/cors-bundle`:

```bash
composer require nelmio/cors-bundle
```

```yaml
# config/packages/nelmio_cors.yaml
nelmio_cors:
    defaults:
        origin_regex: true
        allow_origin: ['%env(CORS_ALLOW_ORIGIN)%']
        allow_methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']
        allow_headers: ['Content-Type', 'Authorization']
        expose_headers: ['Link', 'X-Total-Count']
        max_age: 3600
    paths:
        '^/api/':
            allow_origin: ['https://frontend.example.com']
            allow_credentials: true
```

```env
# .env
CORS_ALLOW_ORIGIN='^https?://(localhost|frontend\.example\.com)(:[0-9]+)?$'
```

### Configuring CORS in PHP (Manual)

```php
// Simple CORS middleware
function handleCors(Request $request): ?Response
{
    $allowedOrigins = ['https://frontend.example.com'];
    $origin = $request->headers->get('Origin');
    
    if ($origin === null || !in_array($origin, $allowedOrigins)) {
        return null; // No CORS headers needed
    }
    
    // Handle preflight
    if ($request->getMethod() === 'OPTIONS') {
        $response = new Response('', 204);
        $response->headers->set('Access-Control-Allow-Origin', $origin);
        $response->headers->set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
        $response->headers->set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        $response->headers->set('Access-Control-Max-Age', '3600');
        return $response;
    }
    
    return null; // Continue to controller, add headers in response listener
}
```

### Common CORS Mistakes

#### 1. Wildcard with Credentials

```
# This does NOT work — browser rejects it
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: true

# Must use specific origin
Access-Control-Allow-Origin: https://frontend.com
Access-Control-Allow-Credentials: true
```

#### 2. Missing OPTIONS Handler

```
# If your server returns 405 for OPTIONS requests, preflight fails
# Make sure your web server or framework handles OPTIONS
```

#### 3. Missing Headers in Actual Response

```
# CORS headers must be present in BOTH the preflight AND the actual response
# Not just the OPTIONS response
```

### CORS vs CSRF

CORS and CSRF are related but different:

| | CORS | CSRF |
|-|------|------|
| What | Browser mechanism that blocks reading cross-origin responses | Attack that tricks the browser into sending unwanted requests |
| Direction | Blocks **reading** response from another origin | Exploits **sending** requests to another origin |
| Protection | Server tells browser which origins can read responses | Server verifies that request came from its own page (tokens) |

CORS does **not** prevent CSRF because CORS only blocks reading the response — the request is still sent. For CSRF protection, you need CSRF tokens or SameSite cookies.

### Real Scenario

You have a React frontend at `https://app.mysite.com` and a Symfony API at `https://api.mysite.com`. Without CORS configuration:

```
Frontend (React):
fetch('https://api.mysite.com/api/users')
→ Browser blocks: "No 'Access-Control-Allow-Origin' header present"
```

You add CORS headers to the API:

```yaml
# nelmio_cors.yaml
nelmio_cors:
    paths:
        '^/api/':
            allow_origin: ['https://app.mysite.com']
            allow_methods: ['GET', 'POST', 'PUT', 'DELETE']
            allow_headers: ['Content-Type', 'Authorization']
            allow_credentials: true
            max_age: 3600
```

Now the browser allows the frontend to make API calls. The preflight is cached for 1 hour (`max_age: 3600`), so subsequent requests are faster.

### Conclusion

CORS is a browser security feature that controls cross-origin HTTP requests. The server uses `Access-Control-Allow-*` headers to tell the browser which origins, methods, and headers are allowed. Non-simple requests trigger a preflight OPTIONS request first. CORS does not prevent CSRF — it only controls who can read responses. For APIs with separate frontend domains, CORS configuration is required.

> See also: [What is CSRF](csrf.md), [OWASP Top 10](owasp_top_10.md), [Web application attacks](web_application_attacks.md)
