# Docker Compose for local development

**Interview framing:**

"Docker Compose is the right tool for local development environments and wrong for production. That distinction is important because it shapes what you optimize for. Locally, you want fast iteration, live code reload, access to logs, and a one-command way to bring up the whole stack. In production, you want immutability, orchestration, scaling, and a very different set of trade-offs. Using Compose for both tends to produce a Compose file that's bad at both jobs. My rule is: Compose for dev, Kubernetes (or similar) for production, and accept that the two configurations won't be the same file."

### What Compose gives you

- **Multi-container orchestration** — define a whole stack (app, db, broker, cache, mailer) in a single file and bring it up with `docker compose up`.
- **Service discovery** — containers can talk to each other by service name.
- **Volume management** — named volumes for persistent data, bind mounts for live code reload.
- **Dependency ordering** — `depends_on` lets services wait for each other (though this is less robust than people think).
- **Environment isolation** — the dev stack runs in its own network, doesn't collide with the host.

### The shape of a typical dev stack

```yaml
# compose.yaml
services:
  app:
    build:
      context: .
      dockerfile: docker/Dockerfile.dev
    volumes:
      - ./:/var/www/app:cached
      - composer_cache:/home/www-data/.composer/cache
    environment:
      APP_ENV: dev
      DATABASE_URL: mysql://app:secret@mysql:3306/app_dev
      MESSENGER_TRANSPORT_DSN: amqp://guest:guest@rabbitmq:5672/%2f/messages
      REDIS_URL: redis://redis:6379
    depends_on:
      mysql:
        condition: service_healthy
      rabbitmq:
        condition: service_healthy
      redis:
        condition: service_started

  nginx:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./:/var/www/app:cached
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - app

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: app_dev
      MYSQL_USER: app
      MYSQL_PASSWORD: secret
    volumes:
      - mysql_data:/var/lib/mysql
    ports:
      - "3306:3306"
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      timeout: 3s
      retries: 10

  rabbitmq:
    image: rabbitmq:3-management-alpine
    ports:
      - "5672:5672"
      - "15672:15672"
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  mailpit:
    image: axllent/mailpit
    ports:
      - "1025:1025"  # SMTP
      - "8025:8025"  # Web UI

volumes:
  mysql_data:
  composer_cache:
```

What's useful about this shape:
- **One command to start** — `docker compose up` and everything comes up.
- **Real services, not mocks** — MySQL, RabbitMQ, Redis are the real things, matching production behavior.
- **Local-only conveniences** — Mailpit catches outgoing email so you can see it in the browser without sending real mail.
- **Bind mount for code** — edits on the host are visible inside the container immediately. No rebuild required.
- **Port exposure** — database and broker ports are exposed to the host so your IDE, CLI tools, and scripts can connect.

### The dev vs prod Dockerfile split

I keep two Dockerfiles:

- `docker/Dockerfile` — the production image, multi-stage, optimized, no dev dependencies.
- `docker/Dockerfile.dev` — the dev image, extends the runtime stage, adds Xdebug, Composer, dev tools, and uses permissive OPCache settings.

The dev image:

```dockerfile
FROM php:8.3-fpm-alpine AS dev

RUN apk add --no-cache git unzip icu-libs libzip libpng \
    && apk add --no-cache --virtual .build-deps \
       $PHPIZE_DEPS icu-dev libzip-dev libpng-dev linux-headers \
    && docker-php-ext-install intl zip pdo_mysql opcache \
    && pecl install xdebug redis \
    && docker-php-ext-enable xdebug redis \
    && apk del .build-deps

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

COPY docker/php/php.dev.ini /usr/local/etc/php/php.ini
COPY docker/php/xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini

WORKDIR /var/www/app
# No COPY of the code — it comes in via a bind mount in docker-compose.
# No USER www-data here — or handle UID mapping carefully to avoid permission errors.

CMD ["php-fpm"]
```

Key differences from production:
- Xdebug installed.
- Composer present in the image for running `composer install` interactively.
- No code baked in; the volume bind mount provides it.
- Permissive OPCache (`validate_timestamps=1` and `revalidate_freq=0`).
- Log level more verbose.

### Live code reload — the bind mount

The bind mount `./:/var/www/app:cached` is what makes code changes show up without rebuilding. The `:cached` flag is a Docker Desktop-specific optimization for macOS — it relaxes consistency guarantees in exchange for massively better performance. On Linux hosts it's a no-op.

**Performance note:** file system access across the Docker host boundary is slow on macOS and Windows — much slower than on Linux. A large Symfony app with thousands of source files can be painful in dev. Mitigations:
- **`cached` / `delegated` flags** on macOS.
- **Named volumes for heavy directories** like `vendor/` and `var/cache/` — these don't change on every keystroke, so keeping them inside the container filesystem is a huge win.
- **Mutagen** or similar file-sync tools for very large projects.
- **Docker Desktop's VirtioFS** on newer macOS versions — much faster than the old osxfs.
- **Linux** — no problem.

### Handling permissions between host and container

The classic problem: your host user is UID 1000, the container runs as www-data (UID 33), files created inside the container are owned by 33, and you can't edit them on the host without `sudo`.

Fixes, in increasing order of cleanliness:
1. **Match UIDs at build time.** Pass `--build-arg UID=$(id -u)` and create the container user with that UID. Your dev image user matches your host user.
2. **Use a separate user in dev.** Create a `dev` user in the dev Dockerfile with the UID you want.
3. **Named volumes for directories the app writes to.** Cache, logs, uploads live in named volumes; you don't edit them from the host anyway.
4. **Run as root in dev** — lazy but fine for local-only. Not for production.

### `depends_on` is not a health check — until you make it one

```yaml
depends_on:
  mysql:
    condition: service_healthy
```

Without `condition: service_healthy`, `depends_on` only waits for the dependency container to *start*, not for the service to be *ready*. MySQL's container can be running while MySQL itself is still initializing. Your app starts, tries to connect, fails, crashes, Compose restarts it, it fails again, eventually succeeds — annoying and fragile.

The fix: define `healthcheck` on the dependency and use `condition: service_healthy`. Compose will actually wait for the health check to pass before starting dependents.

### Overrides and environment files

Compose supports a layered override pattern:

- `compose.yaml` — base config, committed.
- `compose.override.yaml` — automatically applied, usually dev-specific, can be gitignored.
- `compose.prod.yaml` — production overrides, applied explicitly via `-f`.

`.env` files are loaded automatically. I use:
- `.env` — committed with safe defaults, dev-appropriate.
- `.env.local` — gitignored, per-developer overrides.

This pattern lets you check in a working default while allowing per-developer customization without touching the committed files.

### What Compose is bad at (and why you shouldn't use it in production)

- **No real scaling.** `docker compose up --scale app=5` works for experiments but has no load balancing, no rolling updates, no placement, no anything.
- **No rolling deploys.** `compose up` with a new image brings everything down and back up. Zero-downtime deploys are not in scope.
- **No self-healing.** If a node goes down, Compose won't reschedule. It's a single-host tool.
- **No secrets management.** Env vars and bind mounts, which is fine locally but not production-grade.
- **No network policies, no service mesh, no ingress.**

You can run Compose in production for small, low-stakes services. But the moment you care about rolling deploys, scaling, or resilience, you outgrow it. Kubernetes (or Nomad, or ECS, or a PaaS) is the production answer.

### Dev loop niceties I add

- **`just` or `make` wrapper** for common commands: `just up`, `just down`, `just test`, `just shell app`. Reduces friction.
- **A `dev` script that wraps compose** with nicer output and sane defaults (one terminal, all logs, auto-reload on file change).
- **Mailpit or MailHog** for catching outbound email.
- **Adminer or phpMyAdmin** for poking at the database without installing a client.
- **RabbitMQ management plugin** (`rabbitmq:3-management-alpine`) — the web UI at port 15672 is invaluable for debugging queues.

> **Mid-level answer stops here.** A mid-level dev can write a docker-compose file. To sound senior, speak to the dev/prod parity question and the failure modes of shared compose-for-everything setups ↓
>
> **Senior signal:** using Compose deliberately as a dev tool with its own scope, not as a half-broken production tool.

### The dev/prod parity question

A classic principle says dev and prod should be as similar as possible to catch production-only bugs early. Compose is the tool that gets you closest to that goal for local work — real MySQL, real RabbitMQ, real Redis, matching versions with production.

But **identical is a trap**. Dev needs things prod doesn't want (Xdebug, interactive Composer, bind mounts for live reload, verbose logging). Prod needs things dev doesn't want (immutability, horizontal scaling, rolling deploys). The right goal is **semantic parity** — same service versions, same env var shapes, same connection strings — while allowing the deployment model to diverge.

### Pitfalls

- **Bind mounts for `vendor/`** — causes huge IO load on macOS. Use a named volume instead.
- **`latest` tags on dependency services** — non-reproducible and occasionally eats your database when a major version update happens. Pin versions.
- **Committing secrets in `.env`** — use `.env` for safe defaults only; real secrets go in `.env.local` and `.env.local` is gitignored.
- **Treating compose as production.** It's not. Accept the dev/prod split.
- **`docker compose` vs `docker-compose`.** The plugin is the current tool; the standalone `docker-compose` script is legacy. Use the plugin.
- **Forgetting to clean up.** Named volumes and networks accumulate. `docker system prune` occasionally.

### Closing

"So Compose is a local development tool — real services, live reload, one command to start, matching the shape of production closely but not identically. A dev Dockerfile with Xdebug and Composer baked in, bind mounts for code, named volumes for vendor and cache, healthchecks on dependencies, and a clean separation from the production image. For production, graduate to Kubernetes or a managed platform — don't try to force Compose to be both."
