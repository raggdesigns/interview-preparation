# How Authorization Works

Authorization decides **what an authenticated user is allowed to do**. It runs after authentication (which answers "Who are you?") and answers the question: **"What can you access?"**

> **Scenario used throughout this document:** A CMS application where users have roles (`viewer`, `editor`, `admin`). An `editor` can create and edit articles but cannot delete them or manage users. An `admin` can do everything.

## Prerequisites

- [How Authentication Works](how_authentication_works.md) — identity verification happens before authorization
- [How JWT Authorization Works](how_jwt_authorization_works.md) — tokens often carry role/permission claims

## Core Concept

After a user logs in, every subsequent request must be checked:

```text
Request: DELETE /api/articles/42
Headers: Authorization: Bearer <token>

1. Authentication layer  → Token valid? → Yes → user_id=5, roles=["editor"]
2. Authorization layer   → Can "editor" delete articles? → No → 403 Forbidden
```

The key distinction:

| Aspect | Authentication | Authorization |
|--------|---------------|---------------|
| Question | "Who are you?" | "What can you do?" |
| Happens | First | After authentication |
| Fails with | 401 Unauthorized | 403 Forbidden |
| Based on | Credentials (password, token) | Roles, permissions, policies |

## Authorization Models

### 1. Role-Based Access Control (RBAC)

Users are assigned **roles**, and each role has a fixed set of **permissions**. This is the most common model in web applications.

```text
Roles and permissions:

viewer → [article.view]
editor → [article.view, article.create, article.edit]
admin  → [article.view, article.create, article.edit, article.delete, user.manage]
```

**PHP implementation:**

```php
final class RbacAuthorizer
{
    private const ROLE_PERMISSIONS = [
        'viewer' => ['article.view'],
        'editor' => ['article.view', 'article.create', 'article.edit'],
        'admin'  => ['article.view', 'article.create', 'article.edit', 'article.delete', 'user.manage'],
    ];

    public function isGranted(User $user, string $permission): bool
    {
        foreach ($user->getRoles() as $role) {
            if (in_array($permission, self::ROLE_PERMISSIONS[$role] ?? [], true)) {
                return true;
            }
        }

        return false;
    }
}

// Usage in a controller
if (!$authorizer->isGranted($currentUser, 'article.delete')) {
    throw new AccessDeniedHttpException('You cannot delete articles.');
}
```

**Pros:** Simple to implement and audit.
**Cons:** Doesn't scale well when you need fine-grained rules (e.g., "editors can only edit their own articles").

### 2. Attribute-Based Access Control (ABAC)

Decisions are based on **attributes** of the user, the resource, and the environment. More flexible than RBAC.

```text
Rule: Allow edit IF
  user.role == "editor"
  AND resource.author_id == user.id
  AND environment.time BETWEEN 09:00 AND 18:00
```

**PHP implementation:**

```php
final class ArticleEditPolicy
{
    public function canEdit(User $user, Article $article): bool
    {
        // Role check
        if (!in_array('editor', $user->getRoles(), true)) {
            return false;
        }

        // Ownership check — editors can only edit their own articles
        if ($article->getAuthorId() !== $user->getId()) {
            return false;
        }

        // Time-based check — edits only during business hours
        $hour = (int) date('G');
        if ($hour < 9 || $hour > 18) {
            return false;
        }

        return true;
    }
}
```

**Pros:** Fine-grained, context-aware decisions.
**Cons:** Complex to implement, harder to audit ("why was this denied?").

### 3. Access Control Lists (ACLs)

Each **resource** has a list specifying which users or groups can perform which operations. Think of file-system permissions.

```text
Article #42:
  user:5  → [read, write]
  user:8  → [read]
  group:editors → [read, write]
  group:admins  → [read, write, delete]
```

**Pros:** Per-resource granularity.
**Cons:** Hard to manage at scale (every resource needs its own list).

### Model Comparison

| Aspect | RBAC | ABAC | ACL |
|--------|------|------|-----|
| Granularity | Role-level | Attribute-level | Resource-level |
| Complexity | Low | High | Medium |
| Scalability | Good for simple apps | Good for complex rules | Poor at scale |
| Auditability | Easy ("role X has permission Y") | Hard (many attributes) | Medium |
| Best for | Most web apps | Context-dependent rules | File systems, CMS |

## Practical Example: Symfony Voter

Symfony uses the **Voter** pattern to centralize authorization logic. Each voter decides `GRANT`, `DENY`, or `ABSTAIN` for a given attribute and subject.

```php
// src/Security/Voter/ArticleVoter.php
final class ArticleVoter extends Voter
{
    public const EDIT   = 'ARTICLE_EDIT';
    public const DELETE = 'ARTICLE_DELETE';

    protected function supports(string $attribute, mixed $subject): bool
    {
        return in_array($attribute, [self::EDIT, self::DELETE], true)
            && $subject instanceof Article;
    }

    protected function voteOnAttribute(string $attribute, mixed $subject, TokenInterface $token): bool
    {
        $user = $token->getUser();
        if (!$user instanceof User) {
            return false;
        }

        /** @var Article $article */
        $article = $subject;

        return match ($attribute) {
            self::EDIT   => $this->canEdit($user, $article),
            self::DELETE => $this->canDelete($user, $article),
            default      => false,
        };
    }

    private function canEdit(User $user, Article $article): bool
    {
        // Admins can edit anything
        if (in_array('ROLE_ADMIN', $user->getRoles(), true)) {
            return true;
        }

        // Editors can only edit their own articles
        return in_array('ROLE_EDITOR', $user->getRoles(), true)
            && $article->getAuthorId() === $user->getId();
    }

    private function canDelete(User $user, Article $article): bool
    {
        // Only admins can delete
        return in_array('ROLE_ADMIN', $user->getRoles(), true);
    }
}
```

**Using the voter in a controller:**

```php
#[Route('/articles/{id}', methods: ['DELETE'])]
public function delete(Article $article): JsonResponse
{
    // Symfony calls all registered voters and aggregates the decision
    $this->denyAccessUnlessGranted(ArticleVoter::DELETE, $article);

    $this->articleRepository->remove($article);

    return new JsonResponse(null, Response::HTTP_NO_CONTENT);
}
```

If the user is an `editor`, Symfony returns **403 Forbidden**. If the user is an `admin`, the article is deleted.

## Middleware / Guard Pattern

In frameworks without a voter system, authorization is typically implemented as **middleware** that runs before the controller:

```php
final class RequirePermissionMiddleware
{
    public function __construct(
        private readonly RbacAuthorizer $authorizer,
    ) {}

    public function handle(Request $request, string $permission, callable $next): Response
    {
        $user = $request->getAttribute('user');

        if ($user === null) {
            return new JsonResponse(['error' => 'Not authenticated'], 401);
        }

        if (!$this->authorizer->isGranted($user, $permission)) {
            return new JsonResponse(['error' => 'Forbidden'], 403);
        }

        return $next($request);
    }
}

// Route registration
$router->delete('/articles/{id}', ArticleController::delete(...))
    ->middleware(new RequirePermissionMiddleware($authorizer), 'article.delete');
```

## Common Interview Questions

### Q: What is the difference between 401 and 403?

**A:** **401 Unauthorized** means the server doesn't know who you are — you didn't provide credentials or they are invalid. **403 Forbidden** means the server knows who you are but you don't have permission to access the resource.

```text
No token     → 401 Unauthorized   (authenticate first)
Valid token, wrong role → 403 Forbidden (you're not allowed)
```

### Q: When would you pick ABAC over RBAC?

**A:** When simple role checks are not enough. Examples: "editors can only edit articles they authored," "API access is allowed only from company IP range," "discounts are only available for users who registered more than a year ago." These rules depend on **attributes** (ownership, IP, registration date), not just roles.

### Q: How do you handle authorization in a microservices architecture?

**A:** Two common approaches:

1. **Gateway-level authorization** — the API gateway validates the token and checks coarse permissions (e.g., "is this user allowed to call the order service?"). Individual services trust the gateway.
2. **Service-level authorization** — each service receives the JWT, extracts claims (roles, permissions), and makes its own authorization decisions. More secure but requires each service to implement checks.

In practice, most teams combine both: coarse checks at the gateway, fine-grained checks inside each service.

## Conclusion

Authorization determines what actions an authenticated user can perform. The three main models — **RBAC** (role-based), **ABAC** (attribute-based), and **ACL** (per-resource) — offer increasing granularity at the cost of complexity. Most web applications start with RBAC and add ABAC-style rules (like ownership checks) as requirements grow. Frameworks like Symfony provide built-in patterns (Voters) that combine both approaches cleanly.

## See Also

- [How Authentication Works](how_authentication_works.md)
- [How JWT Authorization Works](how_jwt_authorization_works.md)
- [OWASP Top 10](owasp_top_10.md) — broken access control is #1
