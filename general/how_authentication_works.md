# How Authentication Works

Authentication is the process of verifying the identity of a user, device, or system. It answers the question: **"Who are you?"** (as opposed to authorization, which answers "What are you allowed to do?").

## Common Authentication Methods

### 1. Password-Based Authentication (Knowledge Factor)

The most traditional method. The user provides a username and password, which the server verifies against stored credentials.

**Flow**:
1. User submits credentials (username + password).
2. Server hashes the password and compares it against the stored hash (e.g., bcrypt, argon2).
3. If the hash matches, the user is authenticated.

**Best Practices**:
- Never store passwords in plain text — always use a strong hashing algorithm (bcrypt, argon2id).
- Enforce password complexity and length requirements.
- Implement rate limiting and account lockout to prevent brute-force attacks.

### 2. Session-Based Authentication

After successful credential verification, the server creates a session and stores it server-side (in memory, database, or cache like Redis).

**Flow**:
1. User logs in with credentials.
2. Server creates a session (unique session ID) and stores session data server-side.
3. Server sends the session ID to the client as a cookie (`Set-Cookie` header).
4. Client sends the session cookie with every subsequent request.
5. Server looks up the session ID to identify the user.

**Pros**: Server controls session lifecycle (can invalidate immediately).
**Cons**: Requires server-side state; harder to scale horizontally without shared session storage.

### 3. Token-Based Authentication (e.g., JWT)

Stateless approach where the server issues a signed token after successful login. See [How JWT Authorization Works](how_jwt_authorization_works.md) for detailed JWT flow.

**Key Difference from Sessions**: No server-side session storage needed — the token itself carries user identity and claims.

### 4. Multi-Factor Authentication (MFA)

Combines two or more independent authentication factors:

- **Something you know** — password, PIN
- **Something you have** — phone (SMS/TOTP), hardware key (YubiKey)
- **Something you are** — fingerprint, face recognition

### 5. OAuth 2.0 / OpenID Connect

Delegated authentication where a third-party identity provider (Google, GitHub, etc.) verifies the user's identity.

**Flow (Authorization Code Grant)**:
1. App redirects user to the identity provider's login page.
2. User authenticates with the provider.
3. Provider redirects back to the app with an authorization code.
4. App exchanges the code for an access token (and optionally an ID token).
5. App uses the token to identify the user.

### 6. API Key Authentication

Simple method for machine-to-machine communication. The client includes an API key in request headers.

**Limitations**: No user context, harder to manage fine-grained permissions, key rotation is manual.

## Authentication vs Authorization

| Aspect | Authentication | Authorization |
|--------|---------------|---------------|
| Question | "Who are you?" | "What can you do?" |
| Happens | First | After authentication |
| Determines | Identity | Permissions |
| Example | Login with password | Access control checks |

## Security Considerations

- **HTTPS**: Always use encrypted connections to prevent credential interception.
- **Secure Storage**: Hash passwords with bcrypt/argon2; never store plain text.
- **Rate Limiting**: Prevent brute-force attacks on login endpoints.
- **CSRF Protection**: Use CSRF tokens for session-based auth.
- **Token Expiration**: Set reasonable TTLs for sessions and tokens.

## See Also

- [How Authorization Works](how_authorization_works.md)
- [How JWT Authorization Works](how_jwt_authorization_works.md)
