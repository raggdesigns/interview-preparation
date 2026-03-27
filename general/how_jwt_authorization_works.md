# How JWT Authorization Works

JWT (JSON Web Token) is a compact, self-contained token format used to securely transmit identity and authorization claims between parties. It allows **stateless authentication** — the server doesn't need to store sessions because all required information is encoded inside the token itself.

> **Scenario used throughout this document:** A Symfony API at `api.shop.com` issues JWTs after login. The React frontend stores the token and sends it with every API request. The API validates the token without hitting a database.

## Prerequisites

- [How Authentication Works](how_authentication_works.md) — JWT is issued after successful authentication
- [How Authorization Works](how_authorization_works.md) — JWT claims are used for authorization decisions

## JWT Structure

A JWT has three parts separated by dots: `Header.Payload.Signature`

```text
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI0MiIsInJvbGVzIjpbIlJPTEVfRURJVE9SIl0sImV4cCI6MTcxMDAwMDAwMH0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
│               Header              │                    Payload                       │              Signature              │
```

**Decoded:**

```json
// Header — algorithm and token type
{
  "alg": "HS256",
  "typ": "JWT"
}

// Payload — claims (user data + metadata)
{
  "sub": "42",
  "roles": ["ROLE_EDITOR"],
  "email": "editor@shop.com",
  "exp": 1710000000,
  "iat": 1709996400
}

// Signature — ensures the token hasn't been tampered with
HMACSHA256(
  base64UrlEncode(header) + "." + base64UrlEncode(payload),
  secret_key
)
```

### Registered Claims

| Claim | Name | Purpose |
|-------|------|---------|
| `sub` | Subject | User ID |
| `exp` | Expiration | Unix timestamp when token expires |
| `iat` | Issued At | When token was created |
| `nbf` | Not Before | Token not valid before this time |
| `iss` | Issuer | Who created the token (e.g., `api.shop.com`) |
| `aud` | Audience | Who the token is intended for |
| `jti` | JWT ID | Unique identifier for this token |

## How the Flow Works

```text
1. User logs in:
   POST /api/login
   Body: {"email": "editor@shop.com", "password": "secret"}

2. Server verifies credentials → creates JWT:
   Response: {"token": "eyJhbG...w5c", "refresh_token": "dGhpcyBpcyBh..."}

3. Client stores token and sends it with every request:
   GET /api/articles
   Authorization: Bearer eyJhbG...w5c

4. Server receives request:
   a) Extracts token from Authorization header
   b) Verifies signature using secret key
   c) Checks exp claim → not expired?
   d) Reads claims (sub, roles) → user_id=42, roles=[ROLE_EDITOR]
   e) Passes request to controller with user context

5. No database session lookup needed — all info is in the token.
```

## PHP Implementation

Using the `firebase/php-jwt` library:

### Creating a Token (Login Endpoint)

```php
use Firebase\JWT\JWT;

final class AuthController
{
    public function __construct(
        private readonly UserRepository $users,
        private readonly string $jwtSecret,    // from env: JWT_SECRET
        private readonly int $tokenTtl = 3600, // 1 hour
    ) {}

    public function login(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);
        $user = $this->users->findByEmail($data['email']);

        if ($user === null || !password_verify($data['password'], $user->getPasswordHash())) {
            return new JsonResponse(['error' => 'Invalid credentials'], 401);
        }

        $now = time();
        $payload = [
            'sub'   => (string) $user->getId(),
            'email' => $user->getEmail(),
            'roles' => $user->getRoles(),
            'iat'   => $now,
            'exp'   => $now + $this->tokenTtl,
        ];

        $token = JWT::encode($payload, $this->jwtSecret, 'HS256');

        return new JsonResponse([
            'token'      => $token,
            'expires_in' => $this->tokenTtl,
        ]);
    }
}
```

### Verifying a Token (Middleware)

```php
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Firebase\JWT\ExpiredException;
use Firebase\JWT\SignatureInvalidException;

final class JwtAuthMiddleware
{
    public function __construct(
        private readonly string $jwtSecret,
    ) {}

    public function handle(Request $request, callable $next): Response
    {
        $header = $request->headers->get('Authorization', '');

        if (!str_starts_with($header, 'Bearer ')) {
            return new JsonResponse(['error' => 'Token missing'], 401);
        }

        $token = substr($header, 7);

        try {
            $decoded = JWT::decode($token, new Key($this->jwtSecret, 'HS256'));
        } catch (ExpiredException) {
            return new JsonResponse(['error' => 'Token expired'], 401);
        } catch (SignatureInvalidException) {
            return new JsonResponse(['error' => 'Invalid token'], 401);
        } catch (\Exception) {
            return new JsonResponse(['error' => 'Token error'], 401);
        }

        // Attach user context to request for controllers
        $request->attributes->set('user_id', $decoded->sub);
        $request->attributes->set('user_roles', $decoded->roles);

        return $next($request);
    }
}
```

## Refresh Token Flow

Access tokens are short-lived (minutes to 1 hour). **Refresh tokens** are long-lived and used to get new access tokens without re-entering credentials.

```text
Timeline:

0:00  → User logs in → receives access_token (1h) + refresh_token (30d)
0:59  → Access token about to expire
1:00  → Client sends refresh token:
          POST /api/token/refresh
          Body: {"refresh_token": "dGhpcyBpcyBh..."}
        → Server validates refresh token → issues new access_token (1h)
1:01  → Client continues with new access token
```

**Key rules:**

- Refresh tokens are stored **in the database** (unlike access tokens) so they can be revoked
- When a refresh token is used, **rotate it** — issue a new one and invalidate the old one
- If a refresh token is used twice, it means it was stolen — **invalidate the entire family**

```php
public function refresh(Request $request): JsonResponse
{
    $data = json_decode($request->getContent(), true);
    $storedToken = $this->refreshTokenRepository->findByToken($data['refresh_token']);

    if ($storedToken === null || $storedToken->isExpired()) {
        return new JsonResponse(['error' => 'Invalid refresh token'], 401);
    }

    // Rotate: invalidate old, create new
    $this->refreshTokenRepository->revoke($storedToken);

    $user = $this->users->find($storedToken->getUserId());
    $newAccessToken = $this->createAccessToken($user);
    $newRefreshToken = $this->createRefreshToken($user);

    return new JsonResponse([
        'token'         => $newAccessToken,
        'refresh_token' => $newRefreshToken,
        'expires_in'    => $this->tokenTtl,
    ]);
}
```

## Token Storage: Where to Keep the JWT

| Storage | XSS safe? | CSRF safe? | Recommended? |
|---------|-----------|------------|--------------|
| `localStorage` | No — any JS can read it | Yes — not sent automatically | No for sensitive apps |
| `sessionStorage` | No — any JS can read it | Yes — not sent automatically | No for sensitive apps |
| HttpOnly cookie | Yes — JS cannot access | No — sent with every request | Yes, with CSRF token |
| Memory (JS variable) | Yes — no persistence | Yes | Yes, but lost on refresh |

**Best practice:** Store the access token in an **HttpOnly, Secure, SameSite=Strict cookie**. This prevents XSS from stealing the token, and `SameSite=Strict` mitigates CSRF.

## Security Pitfalls

### 1. The `alg: none` Attack

Some JWT libraries accept `"alg": "none"`, which means **no signature verification**. An attacker can forge any token.

```json
// Forged token — no signature needed
{"alg": "none", "typ": "JWT"}
{"sub": "1", "roles": ["ROLE_ADMIN"], "exp": 9999999999}
```

**Prevention:** Always explicitly specify the allowed algorithm in the verification code:

```php
// ✅ Safe — only accepts HS256
JWT::decode($token, new Key($secret, 'HS256'));

// ❌ Unsafe — library might accept alg:none
JWT::decode($token, $secret);  // don't do this
```

### 2. Storing Sensitive Data in Payload

JWT payloads are **base64-encoded, not encrypted**. Anyone can decode them:

```bash
echo "eyJzdWIiOiI0MiIsInJvbGVzIjpbIlJPTEVfRURJVE9SIl19" | base64 -d
# {"sub":"42","roles":["ROLE_EDITOR"]}
```

**Never put passwords, credit card numbers, or secrets in the payload.**

### 3. Token Revocation Problem

JWTs are stateless — the server can't invalidate a single token once issued. If a token is stolen, it remains valid until it expires.

**Mitigations:**

- Keep access token TTL short (15 minutes)
- Maintain a **token blocklist** in Redis for forced logouts
- Use refresh token rotation to limit the damage window

## JWT vs Session-Based Auth

| Aspect | JWT | Session |
|--------|-----|---------|
| State | Stateless (token has all data) | Stateful (session stored on server) |
| Scalability | Easy — no shared state between servers | Hard — needs shared session store (Redis) |
| Revocation | Hard — can't invalidate without blocklist | Easy — delete session from store |
| Size | Larger (payload in every request) | Small (just session ID cookie) |
| Best for | APIs, microservices, mobile apps | Traditional server-rendered web apps |

## Common Interview Questions

### Q: Why use JWT instead of sessions?

**A:** JWTs work well for APIs and microservices because they are **stateless** — any server can validate the token using the secret key without hitting a database. Sessions require a **shared session store** (Redis, database), which adds infrastructure complexity. JWTs are also **cross-domain friendly** — an `Authorization` header works across different domains, while cookies are bound by Same-Origin Policy.

### Q: How do you handle JWT expiration and logout?

**A:** Use **short-lived access tokens** (15–60 minutes) combined with **refresh tokens** (days/weeks). For logout, the client discards the token, and for forced server-side logout, add the token's `jti` to a **Redis blocklist** that the validation middleware checks. The blocklist entries auto-expire when the token would have expired naturally.

### Q: What happens if a JWT is stolen?

**A:** The attacker can use it until it expires — this is the main drawback of stateless tokens. Mitigations: keep access token TTL short (15 min), use **refresh token rotation** (each use invalidates the old token), store tokens in **HttpOnly cookies** to prevent XSS theft, and implement a **token blocklist** for emergency revocation.

## Conclusion

JWT authorization enables stateless API authentication by encoding user identity and claims directly in the token. The three-part structure (Header, Payload, Signature) ensures integrity without server-side storage. The trade-off is clear: you gain horizontal scalability and cross-service compatibility, but lose easy revocation. In practice, most production systems combine short-lived JWTs with refresh token rotation and a Redis blocklist for forced logouts.

## See Also

- [How Authentication Works](how_authentication_works.md)
- [How Authorization Works](how_authorization_works.md)
- [What is CSRF](csrf.md) — relevant for cookie-based token storage
- [What is CORS](cors.md) — relevant for cross-domain API calls with Bearer tokens
