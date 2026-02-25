CSRF (Cross-Site Request Forgery) is an attack where a malicious website tricks a user's browser into performing an unwanted action on a website where the user is already logged in.

### How the Attack Works

The attack exploits the fact that browsers automatically send cookies (including session cookies) with every request to a website.

#### Step-by-Step:

1. **User logs in** to `bank.com`. The browser stores a session cookie.
2. **User visits** a malicious website (`evil.com`) while still logged in to `bank.com`.
3. **The malicious page** contains code that sends a request to `bank.com`:

```html
<!-- On evil.com — hidden form that submits automatically -->
<form action="https://bank.com/transfer" method="POST" id="attack">
    <input type="hidden" name="to" value="attacker-account">
    <input type="hidden" name="amount" value="5000">
</form>
<script>document.getElementById('attack').submit();</script>
```

4. **The browser sends** the request to `bank.com` with the user's session cookie attached.
5. **bank.com receives** the request and sees a valid session → it processes the transfer.

The user never intended to make the transfer. They did not even see the form — it was hidden and submitted automatically.

#### Why It Works

```
User's browser has cookie: session_id=abc123

When evil.com sends request to bank.com:
  POST /transfer
  Cookie: session_id=abc123    ← browser attaches this automatically!
  Body: to=attacker&amount=5000

bank.com sees valid session → processes the request
```

The server cannot tell the difference between a legitimate request from the user and a forged request from evil.com, because both come from the same browser with the same cookies.

### What CSRF Can Do

CSRF attacks can perform any action the user is allowed to do:
- Transfer money
- Change email or password
- Change account settings
- Make purchases
- Delete data
- Add an admin user

CSRF **cannot** read the response — it can only trigger actions (write operations).

### Prevention Methods

#### 1. CSRF Tokens (Synchronizer Token Pattern)

Include a unique, unpredictable token in every form. The server verifies this token on submission. The attacker cannot know what the token is, so they cannot create a valid request.

```php
// Generate token and include in form
session_start();
$token = bin2hex(random_bytes(32));
$_SESSION['csrf_token'] = $token;
```

```html
<form method="POST" action="/transfer">
    <input type="hidden" name="csrf_token" value="<?= $token ?>">
    <input name="to" placeholder="Recipient">
    <input name="amount" placeholder="Amount">
    <button>Transfer</button>
</form>
```

```php
// Verify token on the server
if (!isset($_POST['csrf_token']) || $_POST['csrf_token'] !== $_SESSION['csrf_token']) {
    http_response_code(403);
    die('Invalid CSRF token');
}
```

The attacker on `evil.com` cannot read the token because it is on a different domain (blocked by Same-Origin Policy).

#### 2. Symfony CSRF Protection

Symfony has built-in CSRF support:

```php
// In a Twig form
{{ form_start(form) }}
    {# CSRF token is automatically included #}
    {{ form_row(form.amount) }}
    {{ form_row(form.recipient) }}
    <button>Transfer</button>
{{ form_end(form) }}
```

For manual forms:

```html
<form method="POST">
    <input type="hidden" name="_token" value="{{ csrf_token('transfer') }}">
    <!-- form fields -->
</form>
```

```php
// In the controller
use Symfony\Component\Security\Csrf\CsrfToken;

public function transfer(Request $request): Response
{
    $token = new CsrfToken('transfer', $request->request->get('_token'));
    
    if (!$this->csrfTokenManager->isTokenValid($token)) {
        throw new AccessDeniedHttpException('Invalid CSRF token');
    }
    
    // Process the transfer...
}
```

#### 3. SameSite Cookie Attribute

The `SameSite` attribute on cookies tells the browser when to include the cookie in cross-site requests:

| Value | Behavior |
|-------|----------|
| `Strict` | Cookie is never sent with cross-site requests |
| `Lax` | Cookie is sent with cross-site GET requests (links), but not POST |
| `None` | Cookie is always sent (must use `Secure` flag) |

```php
// PHP configuration
session.cookie_samesite = "Lax"

// Or set in code
session_set_cookie_params([
    'samesite' => 'Lax',
    'secure' => true,
    'httponly' => true,
]);
```

`Lax` is a good default — it blocks CSRF via POST forms from other sites, but still allows normal link navigation.

#### 4. Double Submit Cookie

Send the CSRF token both in a cookie and in the request body. The server compares them — if they match, the request is legitimate. This works because an attacker can send cookies (browser does it automatically) but cannot read them from another domain.

#### 5. Check Referer/Origin Header

```php
$origin = $request->headers->get('Origin') ?? $request->headers->get('Referer');
$allowed = 'https://myapp.com';

if ($origin !== null && !str_starts_with($origin, $allowed)) {
    throw new AccessDeniedHttpException('Invalid origin');
}
```

This is not the main defense (headers can be absent), but it adds an extra layer of protection.

### CSRF and REST APIs

REST APIs that use token-based authentication (Bearer tokens in Authorization header) are **not vulnerable** to CSRF. This is because:

- The browser does not automatically send the `Authorization` header
- The token must be explicitly added by JavaScript
- An attacker's page cannot access the token (Same-Origin Policy)

```
// Cookie-based auth — VULNERABLE to CSRF
POST /api/transfer
Cookie: session_id=abc123    ← sent automatically by browser

// Token-based auth — NOT vulnerable to CSRF
POST /api/transfer
Authorization: Bearer eyJhbGci...    ← must be added explicitly by JavaScript
```

### Real Scenario

You are building a user settings page in Symfony. Without CSRF protection:

```php
// Dangerous — no CSRF check
#[Route('/settings/email', methods: ['POST'])]
public function changeEmail(Request $request): Response
{
    $user = $this->getUser();
    $user->setEmail($request->request->get('email'));
    $this->entityManager->flush();
    
    return new Response('Email updated');
}
// An attacker creates a page with a hidden form pointing to /settings/email
// Any logged-in user who visits the attacker's page gets their email changed
```

With CSRF protection:

```php
#[Route('/settings/email', methods: ['POST'])]
public function changeEmail(Request $request): Response
{
    $token = new CsrfToken('change_email', $request->request->get('_token'));
    if (!$this->csrfTokenManager->isTokenValid($token)) {
        throw new AccessDeniedHttpException('Invalid CSRF token');
    }
    
    $user = $this->getUser();
    $user->setEmail($request->request->get('email'));
    $this->entityManager->flush();
    
    return new Response('Email updated');
}
```

Now the attacker cannot forge the request because they do not know the CSRF token value.

### Conclusion

CSRF attacks trick the browser into performing unwanted actions by exploiting automatic cookie sending. The main defenses are: CSRF tokens (unique per form), SameSite cookies (`Lax` or `Strict`), and checking Origin/Referer headers. Token-based APIs (Bearer tokens) are not vulnerable because the browser does not send the token automatically. Symfony provides built-in CSRF protection for forms.

> See also: [OWASP Top 10](owasp_top_10.md), [Main attacks on web applications](web_application_attacks.md), [What is CORS](cors.md)
