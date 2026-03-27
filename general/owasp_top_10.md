OWASP (Open Web Application Security Project) publishes a list of the 10 most critical security risks for web applications. This list is updated every few years. Below is the OWASP Top 10 (2021 edition) with simple explanations and examples.

### 1. Broken Access Control

Users can do things they should not be allowed to do. For example, a regular user can access admin pages or see other users' data.

```php
// Vulnerable — no permission check
public function deleteUser(int $userId): Response
{
    $this->userRepository->delete($userId); // Any logged-in user can delete anyone!
    return new JsonResponse(['deleted' => true]);
}

// Fixed — check permissions
public function deleteUser(int $userId): Response
{
    if (!$this->getUser()->hasRole('ADMIN')) {
        throw new AccessDeniedHttpException();
    }
    $this->userRepository->delete($userId);
    return new JsonResponse(['deleted' => true]);
}
```

Common examples:

- Changing the user ID in a URL to see someone else's data (`/api/users/123` → `/api/users/456`)
- Accessing admin endpoints without admin role
- Bypassing access checks by modifying API requests

### 2. Cryptographic Failures

Sensitive data is not protected properly. This includes weak encryption, storing passwords in plain text, transmitting data without HTTPS, or using outdated algorithms.

```php
// Bad — storing password in plain text
$user->setPassword($_POST['password']);

// Good — hash the password
$user->setPassword(password_hash($_POST['password'], PASSWORD_BCRYPT));

// Bad — weak algorithm
$hash = md5($password);

// Good — strong algorithm
$hash = password_hash($password, PASSWORD_ARGON2ID);
```

Also includes:

- Not using HTTPS
- Exposing sensitive data in logs or error messages
- Using weak or deprecated TLS versions

### 3. Injection

Untrusted data is sent to an interpreter as part of a command or query. The most known type is SQL Injection.

```php
// Vulnerable to SQL Injection
$query = "SELECT * FROM users WHERE email = '" . $_GET['email'] . "'";
// Attacker sends: ' OR '1'='1' --
// Result: SELECT * FROM users WHERE email = '' OR '1'='1' --'

// Fixed — use prepared statements
$stmt = $pdo->prepare("SELECT * FROM users WHERE email = ?");
$stmt->execute([$_GET['email']]);
```

Other injection types:

- **Command Injection**: `exec("ping " . $_GET['host'])` — attacker sends `; rm -rf /`
- **LDAP Injection**: injecting into LDAP queries
- **XSS** is also a form of injection (injecting JavaScript into HTML)

> See also: [Web application attacks](web_application_attacks.md) for detailed examples.

### 4. Insecure Design

The application architecture itself has security flaws. This is about missing security requirements at the design stage, not about bugs in code.

Examples:

- No rate limiting on password reset endpoint (allows brute force)
- Security questions with easily guessable answers
- No limits on how many items a user can add to a cart (resource exhaustion)
- Missing multi-factor authentication for sensitive operations

### 5. Security Misconfiguration

The application or server is configured incorrectly, leaving security holes.

```text
# Bad — debug mode in production
APP_ENV=dev
APP_DEBUG=true

# Good — production configuration
APP_ENV=prod
APP_DEBUG=false
```

Common examples:

- Default passwords on admin accounts
- Unnecessary features enabled (directory listing, debug toolbar)
- Missing security headers (`X-Frame-Options`, `Content-Security-Policy`)
- Overly permissive CORS configuration
- Stack traces shown to users

### 6. Vulnerable and Outdated Components

Using libraries, frameworks, or system components with known security vulnerabilities.

```bash
# Check for known vulnerabilities in PHP dependencies
composer audit

# Keep dependencies updated
composer update --with-all-dependencies
```

Prevention:

- Regularly update dependencies
- Monitor security advisories (Symfony Security Advisories, GitHub Dependabot)
- Remove unused dependencies
- Use `composer audit` in CI/CD pipeline

### 7. Identification and Authentication Failures

Problems with login systems, session management, or identity verification.

Examples:

- Allowing weak passwords (`123456`)
- No brute force protection (no rate limiting on login)
- Session IDs in URLs
- Credentials sent over HTTP instead of HTTPS
- Not invalidating sessions after password change

```php
// Bad — no brute force protection
public function login(string $email, string $password): bool
{
    $user = $this->userRepository->findByEmail($email);
    return password_verify($password, $user->getPassword());
}

// Better — with rate limiting
public function login(string $email, string $password): bool
{
    if ($this->rateLimiter->isBlocked($email)) {
        throw new TooManyRequestsException('Too many login attempts');
    }
    
    $user = $this->userRepository->findByEmail($email);
    if (!$user || !password_verify($password, $user->getPassword())) {
        $this->rateLimiter->recordFailure($email);
        return false;
    }
    
    $this->rateLimiter->reset($email);
    return true;
}
```

### 8. Software and Data Integrity Failures

Not verifying the integrity of software updates, CI/CD pipelines, or data. For example, using libraries from untrusted sources without checking their integrity.

Examples:

- Not verifying checksums of downloaded packages
- Insecure CI/CD pipeline (attacker can inject malicious code during build)
- Insecure deserialization — deserializing untrusted data can lead to code execution

```php
// Dangerous — unserializing user input can execute arbitrary code
$data = unserialize($_POST['data']); // NEVER do this!

// Safe — use JSON
$data = json_decode($_POST['data'], true);
```

### 9. Security Logging and Monitoring Failures

Not logging security events properly. Without good logging, you cannot detect attacks.

What to log:

- Failed login attempts
- Access control failures
- Input validation failures
- Server errors

```php
// Log security-relevant events
$this->logger->warning('Failed login attempt', [
    'email' => $email,
    'ip' => $request->getClientIp(),
    'timestamp' => new \DateTime(),
]);

$this->logger->alert('Unauthorized access attempt', [
    'user_id' => $user->getId(),
    'attempted_resource' => '/admin/users',
]);
```

Also important: set up alerts for suspicious patterns (many failed logins from one IP, access attempts to admin endpoints).

### 10. Server-Side Request Forgery (SSRF)

The application fetches a URL provided by the user without proper validation. An attacker can make the server send requests to internal services.

```php
// Vulnerable to SSRF
$url = $_GET['url'];
$content = file_get_contents($url);
// Attacker sends: url=http://169.254.169.254/latest/meta-data/ (AWS metadata)
// Or: url=http://localhost:6379/ (internal Redis)

// Fixed — validate and whitelist allowed URLs
$url = $_GET['url'];
$parsed = parse_url($url);
$allowed = ['api.example.com', 'cdn.example.com'];
if (!in_array($parsed['host'], $allowed)) {
    throw new InvalidArgumentException('URL not allowed');
}
$content = file_get_contents($url);
```

### Real Scenario

You are doing a security review of a PHP application. You find these issues:

1. Admin panel has no access control check — anyone with the URL can access it → **Broken Access Control (#1)**
2. User passwords are stored as MD5 hashes → **Cryptographic Failures (#2)**
3. Search feature uses `$_GET['q']` directly in SQL query → **Injection (#3)**
4. The app runs in debug mode in production → **Security Misconfiguration (#5)**
5. Symfony version has known CVE → **Vulnerable Components (#6)**
6. No rate limiting on login endpoint → **Authentication Failures (#7)**
7. No log file for failed login attempts → **Logging Failures (#9)**

Each of these maps directly to an OWASP Top 10 category, and each has a clear fix.

### Conclusion

The OWASP Top 10 covers the most critical web security risks: broken access control, cryptographic failures, injection, insecure design, misconfiguration, outdated components, authentication failures, integrity failures, logging failures, and SSRF. Knowing these helps you identify and prevent vulnerabilities during development and code reviews.

> See also: [Main attacks on web applications](web_application_attacks.md), [What is CSRF](csrf.md), [What is CORS](cors.md)
