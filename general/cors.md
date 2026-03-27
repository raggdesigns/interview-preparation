CORS (Cross-Origin Resource Sharing) is a browser security mechanism that controls which websites can make requests to your server from a different domain. It is based on the **Same-Origin Policy**.

> **Scenario used throughout this document:** A React frontend at `https://app.mysite.com` communicates with a Symfony API at `https://api.mysite.com`. These are different origins (different subdomains), so CORS configuration is required.

### Same-Origin Policy

By default, browsers block JavaScript from making requests to a different origin. An "origin" is the combination of **protocol + domain + port**:

```text
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

Without CORS, if your frontend is at `https://app.mysite.com` and your API is at `https://api.mysite.com`, the browser will block all API requests from the frontend.

CORS is how the backend API tells the browser to relax this policy for the frontend.

### How CORS Works

CORS uses HTTP headers to tell the browser: "This other origin is allowed to access my resources."

#### Simple Requests

For simple requests (GET, POST with basic content types), the browser sends the request directly and checks the response headers:

```text
1. Browser at https://app.mysite.com makes request:
   GET /api/users
   Origin: https://app.mysite.com

2. Server at https://api.mysite.com responds:
   HTTP/1.1 200 OK
   Access-Control-Allow-Origin: https://app.mysite.com
   
   [data]

3. Browser checks the header:
   - Does Access-Control-Allow-Origin match our origin? → Yes → allow the response
   - If header is missing or doesn't match → block the response
```

#### Preflight Requests

For "non-simple" requests (PUT, DELETE, custom headers, JSON content type), the browser first sends an OPTIONS request called a **preflight**:

```text
1. Browser wants to send:
   DELETE /api/users/123
   Origin: https://app.mysite.com
   Content-Type: application/json

2. Browser first sends preflight:
   OPTIONS /api/users/123
   Origin: https://app.mysite.com
   Access-Control-Request-Method: DELETE
   Access-Control-Request-Headers: Content-Type

3. Server at https://api.mysite.com responds to preflight:
   HTTP/1.1 204 No Content
   Access-Control-Allow-Origin: https://app.mysite.com
   Access-Control-Allow-Methods: GET, POST, PUT, DELETE
   Access-Control-Allow-Headers: Content-Type, Authorization
   Access-Control-Max-Age: 3600

4. Browser checks: is DELETE allowed from this origin? → Yes → sends the actual request
   DELETE /api/users/123
   Origin: https://app.mysite.com
   
5. Server responds:
   HTTP/1.1 200 OK
   Access-Control-Allow-Origin: https://app.mysite.com
```

The server controls all of this via specific HTTP headers.

### CORS Headers Explained

#### Response Headers (sent by server)

| Header | Purpose | Example |
|--------|---------|---------|
| `Access-Control-Allow-Origin` | Which origin is allowed | `https://app.mysite.com` or `*` |
| `Access-Control-Allow-Methods` | Which HTTP methods are allowed | `GET, POST, PUT, DELETE` |
| `Access-Control-Allow-Headers` | Which request headers are allowed | `Content-Type, Authorization` |
| `Access-Control-Allow-Credentials` | Allow cookies/auth headers | `true` |
| `Access-Control-Max-Age` | Cache preflight result (seconds) | `3600` |
| `Access-Control-Expose-Headers` | Headers the browser can read | `X-Total-Count` |

#### Important Rules

- `Access-Control-Allow-Origin: *` — allows any origin, but **cannot** be used with credentials
- To allow credentials (cookies), you must specify the exact origin and set `Allow-Credentials: true`

```text
# Allow any origin (no credentials)
Access-Control-Allow-Origin: *

# Allow specific origin with credentials
Access-Control-Allow-Origin: https://app.mysite.com
Access-Control-Allow-Credentials: true
```

Here's how to configure these headers in practice.

### Configuring CORS in Nginx

```nginx
server {
    listen 443 ssl;
    server_name api.mysite.com;

    location /api/ {
        # Handle preflight
        if ($request_method = OPTIONS) {
            add_header Access-Control-Allow-Origin "https://app.mysite.com";
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
            add_header Access-Control-Allow-Headers "Content-Type, Authorization";
            add_header Access-Control-Max-Age 3600;
            return 204;
        }

        # Regular requests
        add_header Access-Control-Allow-Origin "https://app.mysite.com";
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
            allow_origin: ['https://app.mysite.com']
            allow_credentials: true
```

```env
# .env
CORS_ALLOW_ORIGIN='^https?://(localhost|app\.mysite\.com)(:[0-9]+)?$'
```

### Configuring CORS in PHP (Manual)

```php
// Simple CORS middleware
function handleCors(Request $request): ?Response
{
    $allowedOrigins = ['https://app.mysite.com'];
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

```text
# This does NOT work — browser rejects it
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: true

# Must use specific origin
Access-Control-Allow-Origin: https://app.mysite.com
Access-Control-Allow-Credentials: true
```

#### 2. Missing OPTIONS Handler

```text
# If your server returns 405 for OPTIONS requests, preflight fails
# Make sure your web server or framework handles OPTIONS
```

#### 3. Missing Headers in Actual Response

```text
# CORS headers must be present in BOTH the preflight AND the actual response
# Not just the OPTIONS response
```

While CORS protects against unauthorized reading of cross-origin responses, it does **not** protect against all cross-origin threats — specifically CSRF.

### CORS vs CSRF

#### What is CSRF?

CSRF (Cross-Site Request Forgery) is an attack where a malicious website tricks the user's browser into sending an unwanted request to a server where the user is already authenticated. The attacker cannot read the response — they don't need to. The goal is to **perform a state-changing action** (transfer money, change email, delete data) using the victim's session.

#### How a CSRF Attack is Performed

Using our scenario — the user is logged into `https://app.mysite.com`, and the browser holds a session cookie for `https://api.mysite.com`:

```text
1. User logs into https://app.mysite.com
   → Browser stores session cookie for https://api.mysite.com

2. User visits https://evil.com (phishing link, ad, etc.)
   → evil.com contains a hidden auto-submitting form:

   <form action="https://api.mysite.com/api/transfer" method="POST">
     <input type="hidden" name="to" value="attacker_account">
     <input type="hidden" name="amount" value="5000">
   </form>
   <script>document.forms[0].submit();</script>

3. Browser sends the POST to https://api.mysite.com
   → The session cookie is attached AUTOMATICALLY by the browser
   → The server sees a valid session and executes the transfer

4. The attacker CANNOT read the response (CORS blocks that)
   → But the damage is already done — the money was transferred
```

The key insight: the **request was sent and executed** by the server. CORS only blocked the attacker from **reading the response** — which they didn't need.

#### Where the Attack Originates

| Step | Where | What happens |
|------|-------|--------------|
| Setup | `https://evil.com` | Attacker hosts a page with a hidden form or image tag |
| Trigger | User's browser | Browser sends request with cookies automatically attached |
| Target | `https://api.mysite.com` | Server receives a legitimate-looking request and executes it |

#### Comparison: CORS vs CSRF

| | CORS | CSRF |
|-|------|------|
| What | Browser mechanism that blocks **reading** cross-origin responses | Attack that exploits **sending** requests to another origin |
| Direction | Controls who can **read** the API response | Exploits the browser **sending** requests with cookies |
| Protects against | Unauthorized JavaScript reading data from your API | *(CSRF is the attack, not a protection)* |
| Does NOT protect against | State-changing requests (POST, DELETE) — the request still reaches the server | N/A |
| Protection mechanism | Server sends `Access-Control-Allow-Origin` headers | CSRF tokens, SameSite cookies, or Bearer token auth |

#### Why CORS Alone is Not Enough

CORS only tells the browser: *"This origin can read my responses."* But even without CORS permission, the browser **still sends** the request (for simple requests like form submissions). The server processes it, and the side effect happens.

To fully protect your API from CSRF, you need one of:

1. **CSRF tokens** — the server generates a unique token per session/form that `https://evil.com` cannot know or replicate
2. **SameSite cookies** — set `SameSite=Strict` or `SameSite=Lax` so the browser does not send cookies on cross-origin requests
3. **Bearer token authentication** — use `Authorization: Bearer <token>` instead of cookies. Since this header is **not sent automatically** by the browser, `https://evil.com` cannot trigger authenticated requests

> APIs that use JWT tokens in the `Authorization` header (instead of cookies) are **not vulnerable to CSRF** — the attacker's page has no way to attach the token to the request.

For a complete breakdown of CSRF prevention methods, see [What is CSRF](csrf.md).

### Real Scenario

You have a React frontend at `https://app.mysite.com` and a Symfony API at `https://api.mysite.com`. Without CORS configuration:

```text
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

CORS is a browser security feature that controls cross-origin HTTP requests between a frontend app and a backend API. The server uses `Access-Control-Allow-*` headers to tell the browser which origins, methods, and headers are allowed. Non-simple requests trigger a preflight OPTIONS request first.

However, CORS only controls who can **read** responses — it does **not** prevent state-changing attacks (CSRF), because the request is still sent and executed. A proper security setup for frontend/backend separation requires both CORS configuration (to allow legitimate cross-origin reads) **and** CSRF protection (tokens, SameSite cookies, or Bearer token auth) to prevent unauthorized actions.

> See also: [What is CSRF](csrf.md), [OWASP Top 10](owasp_top_10.md), [Web application attacks](web_application_attacks.md)
