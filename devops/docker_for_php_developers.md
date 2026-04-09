# Docker for PHP developers

**Interview framing:**

"Docker for PHP isn't fundamentally different from Docker for any other language, but PHP has some specific traps that trip up teams coming from language-native deployments — the FPM vs CLI split, how OPCache behaves inside a container, multi-stage builds for Composer dependencies, and the question of whether the web server belongs in the same container as PHP-FPM. The goal of a good PHP Docker image is: small, deterministic, and production-shaped — meaning it mirrors production behavior closely enough that you catch production-only bugs in CI, not at 3 a.m."

### What goes in the image

A PHP application image needs roughly:

- The PHP runtime (FPM or CLI, depending on the image's role).
- Required PHP extensions (pdo_mysql, intl, opcache, redis, amqp, etc.).
- Composer dependencies, resolved against a lockfile.
- Application code.
- A non-root user to run as.
- Health and readiness check scripts, if the orchestrator needs them.

What does **not** go in the image:

- Dev dependencies (unless this is a dev image).
- Secrets (API keys, DB passwords, certs). These come in at runtime via env vars or mounted files.
- Local config files from your dev machine.
- Git metadata, `.env` files, editor artifacts.

### Multi-stage builds — the single biggest win

Multi-stage builds let you use one stage to install dependencies and a second stage to produce the small runtime image. The dependencies get resolved in a fat builder image with Composer, git, build tools; the final image copies only what's actually needed.

```dockerfile
# syntax=docker/dockerfile:1.6

# --- Stage 1: install dependencies ---
FROM composer:2 AS composer_deps
WORKDIR /app

COPY composer.json composer.lock ./
RUN --mount=type=cache,target=/tmp/cache \
    composer install \
      --no-dev \
      --no-scripts \
      --no-autoloader \
      --prefer-dist \
      --no-interaction

COPY . .

RUN composer dump-autoload --classmap-authoritative --no-dev

# --- Stage 2: runtime ---
FROM php:8.3-fpm-alpine AS runtime

RUN apk add --no-cache \
      icu-libs \
      libzip \
      libpng \
      oniguruma \
    && apk add --no-cache --virtual .build-deps \
      icu-dev \
      libzip-dev \
      libpng-dev \
      oniguruma-dev \
    && docker-php-ext-install \
      intl \
      zip \
      pdo_mysql \
      opcache \
    && apk del .build-deps

COPY docker/php/php.ini /usr/local/etc/php/php.ini
COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

WORKDIR /var/www/app

COPY --from=composer_deps --chown=www-data:www-data /app .

USER www-data

EXPOSE 9000
CMD ["php-fpm"]
```

The payoff: the final image doesn't contain Composer, git, the dev dependencies, or the build toolchain. Size drops by hundreds of MB. Attack surface drops with it.

### OPCache in containers — the detail that bites

OPCache is PHP's bytecode cache — it compiles PHP source to an intermediate form and caches it in memory so subsequent requests don't re-parse the source. In production, OPCache is the difference between "acceptable" and "fast" PHP.

But OPCache has a quirk in containers: by default it **revalidates** the cache by checking file modification times. In a container where the filesystem is immutable (because the code is baked into the image), that revalidation is pure waste — the files aren't going to change.

The production settings for a container:

```ini
; opcache.ini
opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.validate_timestamps=0    ; don't revalidate; files never change
opcache.preload=/var/www/app/config/preload.php  ; optional: PHP 7.4+
opcache.preload_user=www-data
```

The critical one is `opcache.validate_timestamps=0`. It tells OPCache "these files won't change, don't bother stat'ing them on every request". Measurable throughput improvement.

Because the cache is now immune to file changes, **deploying a new version requires a new container** — you can't just rsync new code onto a running container and expect it to pick up. In a container workflow, that's the right behavior anyway: immutable images, replace to deploy.

**In dev**, you want the opposite — `validate_timestamps=1` (and maybe `revalidate_freq=0`) so your code changes show up immediately. Keep dev and prod OPCache configs separate.

### The FPM vs CLI split

A PHP Docker image serves one of two roles:

1. **FPM image** — runs `php-fpm`, serves web requests. Sits behind nginx (or FrankenPHP, RoadRunner, etc.).
2. **CLI image** — runs long-lived workers (queue consumers, cron jobs, scheduled commands).

The temptation is to use one image for both, with the entrypoint deciding which role. That's fine; the image is the same, just the CMD differs. What's **not** fine is treating the CLI processes as an afterthought — they have different lifecycle, memory, and logging needs than FPM workers.

Key differences:

- CLI processes are long-lived and memory leak accordingly. Time-limit and memory-limit them.
- CLI processes need Supervisor or a similar restart mechanism if you're not running them in Kubernetes.
- CLI processes under Kubernetes should be deployments with their own scaling, not sidecars of the FPM pod.
- CLI doesn't need OPCache enabled (`opcache.enable_cli=0` is the default for a reason).

### Nginx + PHP-FPM — one container or two?

This is a small but surprisingly religious debate.

**Separate containers** (nginx + php-fpm in different pods/containers, communicating via TCP):

- Each container does one thing, matches the Unix philosophy.
- Scale nginx and FPM independently.
- Different images from different teams (platform team maintains nginx; app team maintains PHP).
- In Kubernetes, this is natural — nginx pod fronting multiple FPM deployments.

**Same container** (nginx + php-fpm as sidecars in the same pod, communicating via Unix socket):

- Lower latency (Unix socket vs TCP).
- Simpler networking — no service-to-service routing inside the cluster for this pair.
- Scale together.

**Single container** (nginx + php-fpm managed by a supervisor inside one container):

- Violates "one process per container" but some teams prefer the simplicity.
- Harder to debug; logs are mixed; signals are awkward.

My default: separate containers in the same Kubernetes pod (nginx sidecar pattern). You get low latency, clean process separation, and independent log streams. For simpler deployments, Docker Compose with two services and a Unix socket volume is equivalent.

### The FrankenPHP / RoadRunner alternative

If you're starting fresh, consider the modern alternatives to nginx + FPM:

- **FrankenPHP** — a modern PHP app server based on Caddy, supporting worker mode (app stays in memory between requests), HTTP/2 and HTTP/3 natively, and a single-binary deployment.
- **RoadRunner** — a Go-based PHP app server with similar worker-mode semantics.

Both allow the request lifecycle to be significantly different from traditional FPM — the app stays resident in memory between requests, so bootstrapping (DI container, routing tables, config loading) happens once, not per request. Throughput improvements of 5-10x are routine. The catch: your code must be safe for long-lived processes (no static state pollution, proper EntityManager lifecycle, etc.).

See [../php/frankenphp_roadrunner_swoole.md](../php/frankenphp_roadrunner_swoole.md) for the PHP-side view.

### Image size — why it matters and how to reduce it

- **Pulls are faster.** Every deployment, every new node in the cluster, every CI run pulls the image. A 100MB image pulls in a second; a 1GB image pulls in half a minute.
- **Attack surface is smaller.** Fewer tools and libraries in the image means fewer CVEs.
- **Build cache works better.** Smaller layers fit in the cache more efficiently.

Techniques:

- **Alpine base images.** `php:8.3-fpm-alpine` is a fraction of the size of `php:8.3-fpm`. Gotcha: Alpine uses musl libc, which sometimes breaks native extensions. Test thoroughly.
- **Multi-stage builds.** Don't ship Composer, build tools, or dev deps.
- **`--no-dev`** on composer install.
- **Classmap authoritative autoload.** `composer dump-autoload --classmap-authoritative` produces a static classmap that's faster at runtime and slightly smaller.
- **Delete build deps after use** (`apk del .build-deps`).
- **Use `.dockerignore`** to keep `.git`, `tests/`, `node_modules/`, IDE files out of the build context.

### The `.dockerignore` file you should have

```text
.git
.gitignore
.github
.idea
.vscode
.env
.env.*
var/cache
var/log
var/sessions
tests
docker-compose*.yml
Dockerfile*
README.md
phpunit.xml*
*.md
```

Missing `.dockerignore` causes two problems: slow builds (the daemon copies everything to the build context) and bloated images (accidentally-included files in the resulting image).

### Running as non-root

Every serious production image runs as a non-root user. The PHP official images typically have a `www-data` user for this purpose. Set `USER www-data` late in the Dockerfile (after installing packages, which requires root).

Gotchas:

- File permissions on mounted volumes need to match the UID of the runtime user. If your host user is UID 1000 and the container user is UID 33 (www-data on Debian), bind mounts produce permission errors. The fix: match UIDs, or use a named volume, or chown at container startup.
- Writable paths inside the container need to be chowned to the user. Cache directories, log directories, file upload directories — these need to be writable.

### Signal handling — why your container might hang on shutdown

PHP-FPM handles SIGTERM correctly (graceful shutdown). But if you're running PHP behind a wrapper script, the wrapper might swallow the signal and FPM never hears it. Symptom: shutdown takes the full grace period (typically 30 seconds) before being killed, every deploy.

The fix: make sure PID 1 in the container is the process that should handle signals. Either `exec php-fpm` in your entrypoint or use `tini` as PID 1 (`docker run --init` or `ENTRYPOINT ["/tini", "--"]`).

> **Mid-level answer stops here.** A mid-level dev can write a Dockerfile. To sound senior, speak to the production concerns, image hygiene, and the subtle failure modes ↓
>
> **Senior signal:** treating the image as a deployment artifact with lifecycle, observability, and security concerns of its own.

### Production image checklist

- [ ] Multi-stage build; no build tools in the final image.
- [ ] Non-root user.
- [ ] Minimal base image (alpine or distroless when possible).
- [ ] OPCache configured for immutable filesystem (`validate_timestamps=0`).
- [ ] `opcache.preload` configured if the app supports it.
- [ ] Composer autoload is classmap-authoritative.
- [ ] `.dockerignore` excludes everything that shouldn't be in the build context.
- [ ] Explicit version tags, not `latest`.
- [ ] Health check defined (HTTP endpoint or script).
- [ ] Signals handled correctly (tini or proper exec).
- [ ] Image scanned for CVEs in CI.
- [ ] Reproducible build (same commit → same image digest).

### Common mistakes

- **Using `latest` tags.** Non-reproducible, bites you in incident response when the image you tested is not the image that's running.
- **Including dev dependencies in production.** Bloat, attack surface, and occasionally weird runtime behavior.
- **Forgetting OPCache in production.** Performance drops by a factor of 3-10 and nobody notices until traffic scales.
- **Mounting code into production containers.** Not the same as dev. Baked images are the production model.
- **Running as root.** Every container compromise becomes a host compromise.
- **Building on every deploy.** CI should build the image once and deploy the digest, not rebuild per environment.

### Closing

"So the goal is a small, immutable, production-shaped PHP image built with multi-stage, running as non-root, with OPCache tuned for an immutable filesystem, and with a `.dockerignore` that keeps the noise out. Nginx in a sidecar, FPM as the app, CLI workers as separate deployments. Test with the same image configuration you'll run in production. The image is a deployment artifact, not a convenience — treat it with the rigor you'd treat any other piece of production infrastructure."
