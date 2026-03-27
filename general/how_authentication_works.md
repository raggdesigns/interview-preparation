# How Authentication Works

Authentication is the process of verifying **who a user is**. It answers the question "Who are you?" and happens before authorization (which decides what you are allowed to do). Every web application needs at least one authentication method, and most production systems combine several.

> **Scenario used throughout this document:** An e-commerce API at `api.shop.com` with a Symfony backend. Users log in via email/password, and the API issues a JWT. An admin panel uses session-based auth. Third-party integrations authenticate via API keys.

## Prerequisites

- [HTTP Protocol Structure](http_protocol_structure.md) — headers, cookies, and status codes used during auth
- [What is CSRF](csrf.md) — relevant for session-based authentication

## Authentication Methods

### 1. Password-Based Authentication

The user sends credentials, and the server verifies them against a stored hash. **Never store plain-text passwords.**

```php
// Registration — hash the password
$hash = password_hash($plainPassword, PASSWORD_ARGON2ID);
// Stores: $2y$... or $argon2id$... hash in the database

// Login — verify the password
$user = $userRepository->findByEmail($email);

if ($user === null || !password_verify($plainPassword, $user->getPasswordHash())) {
    return new JsonResponse(['error' => 'Invalid credentials'], 401);
}

// Password is correct → proceed to issue session or token
```

**How `password_hash` works:**

```text
Input:  "my-secret-password"
Output: "$argon2id$v=19$m=65536,t=4,p=1$c2FsdHNhbHQ$hash..."
         │         │                  │          │
         algorithm  parameters         salt       hash
```

The salt is generated automatically and stored inside the hash string, so each user gets a unique hash even if they use the same password.

**Security rules:**

- Use `PASSWORD_ARGON2ID` (preferred) or `PASSWORD_BCRYPT`
- Implement rate limiting on login endpoints (e.g., 5 attempts per minute)
- Add account lockout after repeated failures
- Always use HTTPS

### 2. Session-Based Authentication

After verifying credentials, the server creates a **session** stored server-side and sends a **session ID** cookie to the client.

```text
Login flow:

1. POST /login
   Body: {"email": "user@shop.com", "password": "secret"}

2. Server verifies credentials → creates session:
   Session store (Redis):  session:abc123 → {user_id: 42, roles: ["editor"]}

3. Response:
   HTTP/1.1 200 OK
   Set-Cookie: PHPSESSID=abc123; HttpOnly; Secure; SameSite=Strict

4. Subsequent requests — browser sends cookie automatically:
   GET /api/profile
   Cookie: PHPSESSID=abc123

5. Server looks up session:abc123 in Redis → finds user_id=42 → authorized
```

**PHP implementation:**

```php
// Login
session_start();

$user = $userRepository->findByEmail($email);
if ($user !== null && password_verify($password, $user->getPasswordHash())) {
    // Regenerate session ID to prevent session fixation
    session_regenerate_id(true);

    $_SESSION['user_id'] = $user->getId();
    $_SESSION['roles']   = $user->getRoles();
}

// Protected endpoint
session_start();
if (!isset($_SESSION['user_id'])) {
    http_response_code(401);
    exit;
}
$userId = $_SESSION['user_id'];
```

**Pros:** Server can instantly invalidate a session (just delete it from Redis).
**Cons:** Requires shared session storage for horizontal scaling (multiple servers).

### 3. Token-Based Authentication (JWT)

Stateless approach — the server issues a signed token containing user claims. No server-side session storage needed. See [How JWT Authorization Works](how_jwt_authorization_works.md) for full details.

```text
Login flow:

1. POST /api/login → server verifies credentials → issues JWT
2. Client stores token (HttpOnly cookie or memory)
3. Every request: Authorization: Bearer eyJhbG...
4. Server verifies signature + expiration → extracts user_id and roles
```

**Key difference from sessions:** The token itself carries all user data. Any server with the secret key can validate it — no shared session store needed.

### 4. Multi-Factor Authentication (MFA)

Combines two or more independent factors:

| Factor | Type | Examples |
|--------|------|----------|
| Something you **know** | Knowledge | Password, PIN |
| Something you **have** | Possession | Phone (TOTP app), hardware key (YubiKey) |
| Something you **are** | Inherence | Fingerprint, face recognition |

**TOTP (Time-based One-Time Password) flow:**

```text
1. User enables MFA → server generates a shared secret
2. Server shows QR code → user scans with Google Authenticator
3. On login, after password verification:
   - Server asks for 6-digit code
   - User opens authenticator app → enters code
   - Server computes expected code from shared secret + current time
   - If codes match → authenticated
```

```php
// Using pragmarx/google2fa
use PragmaRX\Google2FA\Google2FA;

$google2fa = new Google2FA();

// Setup: generate secret for user (store in DB)
$secret = $google2fa->generateSecretKey();

// Verification: check if user-provided code is valid
$isValid = $google2fa->verifyKey($user->getTotpSecret(), $codeFromUser);

if (!$isValid) {
    return new JsonResponse(['error' => 'Invalid 2FA code'], 401);
}
```

### 5. OAuth 2.0 / OpenID Connect

Delegates authentication to a **third-party identity provider** (Google, GitHub, etc.). The user never shares their password with your application.

**Authorization Code Grant flow:**

```text
1. User clicks "Login with Google"
   → Browser redirects to:
     https://accounts.google.com/o/oauth2/v2/auth?
       client_id=YOUR_CLIENT_ID
       &redirect_uri=https://shop.com/callback
       &response_type=code
       &scope=openid email profile

2. User authenticates with Google → grants consent

3. Google redirects back with authorization code:
     https://shop.com/callback?code=AUTH_CODE_HERE

4. Server exchanges code for tokens (server-to-server):
   POST https://oauth2.googleapis.com/token
   Body: {
     "code": "AUTH_CODE_HERE",
     "client_id": "YOUR_CLIENT_ID",
     "client_secret": "YOUR_SECRET",
     "redirect_uri": "https://shop.com/callback",
     "grant_type": "authorization_code"
   }

   Response: {
     "access_token": "ya29.a0...",
     "id_token": "eyJhbG...",    ← JWT with user info
     "expires_in": 3600
   }

5. Server decodes id_token → gets user email, name → creates/finds local user
```

**OpenID Connect** adds an identity layer on top of OAuth 2.0 — the `id_token` is a JWT containing user claims (`sub`, `email`, `name`).

### 6. API Key Authentication

Simple method for **machine-to-machine** communication. The client includes a key in the request header.

```text
GET /api/products
X-API-Key: sk_live_a1b2c3d4e5f6...
```

**Limitations:** No user context, all-or-nothing access, key rotation is manual. Use API keys for service-to-service calls, not for end-user authentication.

## Comparison Table

| Method | Stateful? | Scalability | Revocation | Best for |
|--------|-----------|-------------|------------|----------|
| Session | Yes (server-side) | Needs shared store | Instant (delete session) | Server-rendered web apps |
| JWT | No (stateless) | Easy (no shared state) | Hard (needs blocklist) | APIs, microservices, SPAs |
| OAuth 2.0 | Depends on token type | Easy | Depends on provider | Third-party login, SSO |
| API Key | No | Easy | Rotate key | Machine-to-machine |
| MFA | Adds to any method | Same as base method | Same as base method | High-security accounts |

## Common Interview Questions

### Q: Session-based auth vs token-based auth — when would you choose which?

**A:** Use **sessions** for traditional server-rendered applications where the server controls the HTML — sessions are simple, instantly revocable, and work naturally with browser cookies. Use **JWT tokens** for APIs consumed by SPAs, mobile apps, or microservices — tokens are stateless, don't need shared storage, and work across domains without CORS cookie complications.

### Q: How do you securely store passwords?

**A:** Use `password_hash()` with `PASSWORD_ARGON2ID` — it auto-generates a unique salt per password and produces a one-way hash. On login, use `password_verify()` to compare. Never use MD5, SHA1, or SHA256 alone — they're too fast and vulnerable to rainbow table attacks. Argon2 and bcrypt are intentionally slow, making brute-force attacks impractical.

### Q: What is the difference between OAuth 2.0 and OpenID Connect?

**A:** OAuth 2.0 is an **authorization** framework — it gives your app an access token to call APIs on behalf of the user, but doesn't tell you who the user is. OpenID Connect is an **authentication** layer on top of OAuth 2.0 — it adds an `id_token` (a JWT) that contains user identity claims (`sub`, `email`, `name`). In short: OAuth = "grant access", OIDC = "grant access + prove identity."

## Conclusion

Authentication verifies user identity through credentials, tokens, or delegated identity providers. The choice between session-based and token-based authentication depends on your architecture: sessions for server-rendered apps with easy revocation, JWTs for stateless APIs with horizontal scalability. In practice, most production systems combine multiple methods — password + MFA for login, JWT for API access, OAuth for third-party integrations, and API keys for service-to-service communication.

## See Also

- [How Authorization Works](how_authorization_works.md) — what happens after authentication
- [How JWT Authorization Works](how_jwt_authorization_works.md) — deep dive into JWT structure and security
- [What is CSRF](csrf.md) — session-based auth requires CSRF protection
- [OWASP Top 10](owasp_top_10.md) — authentication failures are in the top 10
