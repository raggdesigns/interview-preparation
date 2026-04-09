# Slim framework basics

**Interview framing:**

"Slim is a PHP micro-framework — a thin routing and middleware layer without the batteries-included approach of Symfony or Laravel. It gives you an HTTP request in, HTTP response out, a PSR-7 message interface, a PSR-15 middleware pipeline, and almost nothing else. The value proposition is: when Symfony is too much and raw PHP is too little, Slim sits in the middle. It's particularly relevant for the job ad mention of 'custom or in-house frameworks including Slim-based architectures' — many companies build their internal platform on top of Slim because it's thin enough to control entirely."

### What Slim gives you

- **Routing** — map HTTP methods and URL patterns to callables.
- **Middleware pipeline** — PSR-15 middleware for request/response processing.
- **PSR-7 HTTP messages** — standard request/response objects.
- **Dependency injection** — pluggable PSR-11 container.
- **Error handling** — basic error rendering.

What it explicitly does NOT give you: an ORM, a template engine, a form system, a security layer, a CLI tool, a migration system, an admin panel. You bring those yourself, or you don't use them.

### A minimal Slim application

```php
<?php

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Slim\Factory\AppFactory;

require __DIR__ . '/../vendor/autoload.php';

$app = AppFactory::create();

$app->get('/hello/{name}', function (Request $request, Response $response, array $args) {
    $response->getBody()->write("Hello, " . $args['name']);
    return $response;
});

$app->run();
```

That's a complete, running application. Route → handler → response. No config files, no YAML, no annotations.

### Middleware — the extension point

Slim's architecture is a middleware pipeline. Each middleware wraps the handler and can inspect/modify the request and response:

```php
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface;

class JsonContentTypeMiddleware implements MiddlewareInterface
{
    public function process(Request $request, RequestHandlerInterface $handler): Response
    {
        $response = $handler->handle($request);
        return $response->withHeader('Content-Type', 'application/json');
    }
}

$app->add(new JsonContentTypeMiddleware());
```

Common middleware: authentication, logging, CORS, rate limiting, request validation, error handling. The PSR-15 standard means middleware from any library that supports PSR-15 works with Slim.

### Why companies build on Slim

The "custom in-house framework" pattern mentioned in job ads usually looks like:

1. **Slim as the HTTP layer** — routing, middleware, request/response handling.
2. **Doctrine for persistence** — wired via the DI container.
3. **Custom middleware for auth, logging, error handling.**
4. **Custom service layer for business logic.**
5. **No framework-specific abstractions** — everything is explicit, no magic.

This gives the company:

- **Full control over the stack.** No framework opinions to fight.
- **Minimal surface area.** Less framework code to audit, upgrade, and debug.
- **Long-term stability.** Slim's API surface is tiny and changes rarely.
- **Easier onboarding for the specific stack.** New engineers learn the company's conventions, not a framework's.

The trade-off: every feature Symfony gives you for free, you build yourself. Auth, validation, forms, admin, caching, events — all custom. This is a *lot* of code for a large application.

### Slim vs Symfony vs Laravel — when each fits

- **Slim:** microservices, APIs, internal tools, companies that want full control, projects where Symfony/Laravel is overkill.
- **Symfony:** large applications, complex domains, teams that want batteries included, long-lived enterprise projects.
- **Laravel:** rapid development, startups, teams that value developer experience and convention-over-configuration.

The honest assessment: Slim is the right choice when you need a thin HTTP layer and nothing else. For a full-featured application with auth, admin, forms, and a rich domain, Symfony or Laravel will save thousands of hours of custom code.

### Slim in the context of "in-house frameworks"

When an interviewer mentions Slim-based architectures, they usually mean: "we built our platform on Slim years ago and it's grown into a large application. You'll work in a codebase that doesn't have Symfony's event dispatcher, doesn't have Laravel's Eloquent, and does everything through explicit service classes and middleware."

The interview signal they're looking for:

- Can you work without framework magic?
- Do you understand PSR-7/PSR-15/PSR-11?
- Can you read a DI container configuration and understand what's wired together?
- Are you comfortable building things that Symfony gives for free?

> **Mid-level answer stops here.** A mid-level dev can describe Slim's features. To sound senior, speak to the trade-offs of building on a micro-framework and the patterns that keep Slim-based systems maintainable at scale ↓
>
> **Senior signal:** understanding that Slim is a foundation, not a framework, and knowing how to structure a large application on top of it.

### Keeping a Slim-based application maintainable

- **PSR-11 container.** Use PHP-DI or similar. Wire services explicitly. Don't use the container as a service locator.
- **Separate routing from business logic.** Route definitions in one place; handlers call service classes. Don't put business logic in route closures.
- **Middleware for cross-cutting concerns.** Auth, logging, CORS, error handling — all middleware, not scattered through handlers.
- **Request validation.** Since there's no framework form system, validate in a middleware or a dedicated validation layer.
- **Structured error responses.** Define a standard error format and enforce it in an error-handling middleware.
- **Testing.** Slim apps are highly testable — create the app instance in a test, dispatch a request, assert on the response. No framework boot ceremony.

### Closing

"So Slim is a micro-framework: routing, middleware, PSR-7 messages, DI container, and nothing else. It's the foundation for in-house frameworks where companies want full control over the stack. The trade-off is explicit: everything Symfony gives for free, you build yourself. The senior skill is knowing how to structure a large application on top of it — service layer for business logic, middleware for cross-cutting concerns, PSR-11 container for wiring, and explicit validation. It's not better or worse than Symfony; it's a different trade-off, and the right one depends on the team's priorities."
