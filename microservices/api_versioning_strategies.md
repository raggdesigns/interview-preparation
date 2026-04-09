# API versioning strategies

**Interview framing:**

"API versioning is the practice of evolving an API without breaking existing consumers. There are three main approaches — URL path versioning, header versioning, and content negotiation — and each has trade-offs around visibility, cache-friendliness, and operational complexity. The senior insight is that the best versioning strategy is one you rarely need: design APIs for backward compatibility first, and reach for a new version only when a breaking change is truly unavoidable."

### The three approaches

#### URL path versioning

```text
GET /api/v1/orders/42
GET /api/v2/orders/42
```

The version is part of the URL. Different versions are different endpoints.

**Pros:** obvious, easy to route, easy to cache, easy to document, easy to test. The most popular approach in practice.

**Cons:** multiple URL trees to maintain. Every endpoint is duplicated per version. Consumers need to update their base URL to migrate.

#### Header versioning

```text
GET /api/orders/42
Accept-Version: 2
```

The version is in a custom HTTP header. The URL stays the same.

**Pros:** clean URLs. Doesn't pollute the routing layer.

**Cons:** harder to test (you need to set headers in curl/browser). Harder to cache (Vary header needed). Less visible to consumers reading docs. Less supported by tooling.

#### Content negotiation (media type versioning)

```text
GET /api/orders/42
Accept: application/vnd.myapp.v2+json
```

The version is in the `Accept` header as a custom media type.

**Pros:** RESTfully correct — the version is about the representation, not the resource. Allows fine-grained versioning per representation.

**Cons:** complex for consumers. Tooling support is weaker. Over-engineered for most APIs.

### What to actually use

**URL path versioning** is the default for most teams. It's the simplest, the most tooling-friendly, and the easiest to reason about. Unless you have a specific reason for header-based versioning (API gateway that routes by header, strict REST compliance), use URL paths.

### The real answer: avoid breaking changes

The best version strategy is **never needing to version**. Design APIs for backward compatibility:

**Non-breaking changes (no new version needed):**

- Adding a new field to a response.
- Adding a new optional parameter to a request.
- Adding a new endpoint.
- Relaxing a constraint (accepting a wider range of values).

**Breaking changes (require a new version):**

- Removing a field from a response.
- Renaming a field.
- Changing a field's type.
- Adding a required parameter.
- Changing the behavior of an existing endpoint.

**The expand-contract pattern:**

1. **Add** the new field alongside the old one. Both are populated. (Non-breaking.)
2. **Migrate** consumers to use the new field. (Consumer-side change.)
3. **Remove** the old field in a later release. (Breaking, but consumers have already migrated.)

If you always follow expand-contract, you rarely need a version bump. The version number only changes for truly incompatible redesigns.

### Deprecation

When a version is being retired:

1. **Announce deprecation** with a timeline (6 months, 12 months).
2. **Add deprecation headers** to responses: `Deprecation: true`, `Sunset: Sat, 01 Jan 2028 00:00:00 GMT`.
3. **Monitor usage** of the old version. Who's still calling it?
4. **Reach out** to consumers who haven't migrated.
5. **Shut down** after the sunset date.

Never surprise consumers with a removed version. The deprecation period should be long enough for all consumers to migrate.

### Versioning and API gateways

API gateways (Kong, nginx, AWS API Gateway, Traefik) can route different versions to different backend deployments:

```text
/api/v1/* → billing-service-v1 deployment
/api/v2/* → billing-service-v2 deployment
```

This lets you run old and new versions simultaneously without changing the codebase. Old consumers hit v1; new consumers hit v2. When v1 is decommissioned, the gateway stops routing to it.

### How many versions to support

Most teams support **at most 2 concurrent versions**: the current version and the previous one. Supporting more is expensive — each version is a separate code path (or deployment) that needs testing, monitoring, and bug fixes.

The rule: N and N-1. When N+1 ships, deprecate N-1 and sunset it on a schedule.

> **Mid-level answer stops here.** A mid-level dev can list the approaches. To sound senior, speak to the discipline of avoiding breaking changes and the operational concerns of running multiple versions ↓
>
> **Senior signal:** treating versioning as a last resort and designing for backward compatibility as the default.

### Common mistakes

- **Versioning too eagerly.** Every small change gets a new version. Consumer migration fatigue.
- **Not versioning at all.** Breaking changes surprise consumers in production.
- **Keeping old versions alive forever.** Each version is maintenance cost. Sunset them.
- **Breaking changes without a deprecation period.** Consumers break without warning.
- **Versioning internal APIs between your own services.** Use the expand-contract pattern instead; you control both sides.
- **Different versioning strategies across teams.** "Team A uses URL paths, Team B uses headers." Standardize.
- **Forgetting to version the API spec** (OpenAPI/Swagger). The docs and the code must agree.

### Closing

"So URL path versioning is the pragmatic default. But the real answer is to design APIs so you rarely need a new version — additive changes, expand-contract for field changes, optional parameters. When you do need a version, support N and N-1, deprecate with sunset headers, monitor usage of old versions, and decommission on schedule. The best API versioning strategy is the one that doesn't produce many versions."
