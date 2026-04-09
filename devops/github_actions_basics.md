# GitHub Actions basics

**Interview framing:**

"GitHub Actions is GitHub's built-in CI/CD system. The headline feature for backend teams is that it's integrated tightly with the repo — events like push, PR, issue, release trigger workflows without external hooks. The programming model is YAML workflows made up of jobs made up of steps, with reusable building blocks called actions. It's powerful, widely adopted, and has a few sharp edges around security and caching that are worth knowing."

### The mental model

- **Workflow** — a YAML file in `.github/workflows/` that defines one or more jobs triggered by events.
- **Event** — something that happened in the repo (push, pull_request, schedule, workflow_dispatch, release).
- **Job** — a set of steps that run on a single runner. Multiple jobs in a workflow can run in parallel.
- **Step** — a single unit of work: a shell command or a reusable action.
- **Action** — a reusable package of functionality (e.g., `actions/checkout@v4`, `docker/build-push-action@v5`). Actions come from the GitHub Marketplace, your own repos, or Docker images.
- **Runner** — the machine that executes the job. GitHub hosts them for free (with limits); you can also run self-hosted runners.

### A minimal PHP workflow

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: root
          MYSQL_DATABASE: test
        ports:
          - 3306:3306
        options: >-
          --health-cmd="mysqladmin ping"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=5

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          extensions: mbstring, intl, pdo_mysql, opcache
          coverage: none

      - name: Cache Composer dependencies
        uses: actions/cache@v4
        with:
          path: vendor
          key: composer-${{ hashFiles('composer.lock') }}
          restore-keys: composer-

      - name: Install dependencies
        run: composer install --no-interaction --no-progress --prefer-dist

      - name: Run PHPStan
        run: vendor/bin/phpstan analyse --no-progress

      - name: Run PHPUnit
        env:
          DATABASE_URL: mysql://root:root@127.0.0.1:3306/test
        run: vendor/bin/phpunit
```

What this does:

- Triggers on push to main or any pull request.
- Spins up a MySQL 8.0 service container alongside the job.
- Sets up PHP 8.3 with the extensions the app needs.
- Caches the `vendor/` directory keyed on `composer.lock` so repeat runs are fast.
- Installs dependencies, runs static analysis, runs tests.

### Events and triggers

- **`push`** — ran on every push to a branch. Filter with `branches`, `tags`, `paths`.
- **`pull_request`** — ran on PR events (opened, synchronize, reopened). Use this for PR checks.
- **`schedule`** — cron-style. Useful for nightly jobs, dependency updates, security scans.
- **`workflow_dispatch`** — manual trigger with optional inputs. Useful for one-off deploys or admin tasks.
- **`workflow_run`** — chain workflows: run this workflow after another one completes.
- **`release`** — trigger on GitHub release events. Useful for publishing artifacts.

**Path filters** are worth knowing:

```yaml
on:
  push:
    paths:
      - 'src/**'
      - 'composer.*'
      - '.github/workflows/ci.yml'
```

Don't run the CI pipeline when someone edits the README.

### Reusable actions — where the ecosystem lives

The strength of Actions is the marketplace. Actions you'll use constantly:

- **`actions/checkout@v4`** — clone the repo.
- **`actions/cache@v4`** — cache arbitrary directories.
- **`actions/setup-*`** — language setup (`setup-node`, `setup-python`, `setup-go`). For PHP, the community `shivammathur/setup-php@v2` is the de facto standard.
- **`docker/build-push-action@v5`** — build and push images with layer caching.
- **`docker/login-action@v3`** — log into a registry.
- **`aws-actions/configure-aws-credentials@v4`** — get AWS credentials via OIDC (see below).
- **`actions/upload-artifact@v4`** / **`download-artifact@v4`** — pass files between jobs or persist them for later download.

**Pin actions to versions or SHAs.** `@v4` is fine for reputable actions; for anything sensitive (or less-trusted), pin to a specific commit SHA. An action can be updated to include malicious code, and if you're using a mutable tag like `@main` or even `@v4`, you get the updated code automatically.

### Secrets and environment variables

Secrets are defined at the repo, environment, or organization level, and exposed to workflows via `${{ secrets.NAME }}`:

```yaml
- name: Deploy
  env:
    API_TOKEN: ${{ secrets.DEPLOY_TOKEN }}
  run: ./deploy.sh
```

**Environment secrets** are scoped to a specific GitHub Environment (dev, staging, prod). This lets you enforce approvals before a job can access prod secrets. A job targeting the `production` environment will wait for a reviewer to approve before running.

```yaml
jobs:
  deploy-prod:
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://app.example.com
    steps:
      - run: ./deploy.sh
```

When this job runs, GitHub will pause it until a reviewer approves (if the environment requires approval). Prod deploys should always be behind an environment gate.

### OIDC for cloud credentials — the modern approach

Storing long-lived AWS/GCP/Azure credentials as GitHub secrets is the old way. The new way: **OIDC federation**. GitHub Actions can issue a short-lived token, and your cloud provider can trust GitHub's OIDC issuer for specific workflows.

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
          aws-region: eu-west-1
```

No access key stored anywhere. GitHub requests a token; AWS verifies the token came from the specific repo, branch, and workflow configured in the IAM role's trust policy; short-lived credentials are returned. Rotation is automatic. Compromise radius is minimized.

Every cloud provider supports this pattern now. It's the default setup for any new deployment pipeline.

### Matrix builds — test against multiple configurations

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        php-version: ['8.1', '8.2', '8.3']
        dependency-version: ['lowest', 'highest']
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with:
          php-version: ${{ matrix.php-version }}
      - run: composer update --prefer-${{ matrix.dependency-version }}
      - run: vendor/bin/phpunit
```

Runs the job for every combination — 6 parallel runs in this example. Useful for library projects that support multiple PHP versions; overkill for most application code.

### Caching effectively

The `actions/cache` action saves and restores directories keyed on a hash. The pattern:

```yaml
- uses: actions/cache@v4
  with:
    path: vendor
    key: composer-${{ runner.os }}-${{ hashFiles('composer.lock') }}
    restore-keys: |
      composer-${{ runner.os }}-
```

- **`key`** — exact match key. Cache is restored only if the key matches.
- **`restore-keys`** — fallback prefixes. If the exact key doesn't match, restore from the most recent partial match.

Effective caching is the difference between 2-minute and 8-minute jobs. Cache everything that's slow to regenerate:

- Composer dependencies (by lockfile hash)
- Docker build cache (GitHub Actions cache backend for buildx)
- Node modules
- PHPStan result cache
- Test databases

### Parallel jobs and dependencies

Jobs run in parallel by default. Use `needs:` to declare dependencies:

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps: [...]

  test:
    runs-on: ubuntu-latest
    steps: [...]

  build:
    needs: [lint, test]
    runs-on: ubuntu-latest
    steps: [...]

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: production
    steps: [...]
```

`lint` and `test` run in parallel. `build` waits for both. `deploy` waits for build and requires manual approval via the `production` environment.

### Reusable workflows

A workflow can call another workflow. Useful for cross-repo consistency or for sharing complex deploy logic.

```yaml
# In repo A: .github/workflows/deploy.yml
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      AWS_ROLE:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps: [...]
```

```yaml
# In repo B: use the shared workflow
jobs:
  deploy:
    uses: org/repo-a/.github/workflows/deploy.yml@main
    with:
      environment: production
    secrets:
      AWS_ROLE: ${{ secrets.AWS_ROLE_PROD }}
```

Reusable workflows keep complex deploy logic DRY across repos. The alternative — copy-pasting YAML — drifts immediately and becomes unmaintainable.

### Self-hosted runners

GitHub-hosted runners are free (with generous limits) and sufficient for most projects. Self-hosted runners are worth it when:

- You need access to private networks (databases, internal registries) that aren't exposed to GitHub's cloud.
- You need specific hardware (GPUs, ARM, custom VM specs).
- You have very high usage and the cost of hosted runners exceeds self-hosted infrastructure cost.

**Security warning:** self-hosted runners on public repos are a known attack vector. A malicious PR can run arbitrary code on your runner. Either disable runners on PRs from forks, use ephemeral runners, or restrict runner access to private repos.

> **Mid-level answer stops here.** A mid-level dev can write a workflow. To sound senior, speak to security, reliability, and scaling concerns ↓
>
> **Senior signal:** treating GitHub Actions as production infrastructure with its own threat model.

### Security concerns worth thinking about

- **Action pinning.** `@v4` is fine for well-known actions, but pin to SHA for sensitive ones. Third-party actions can be updated to include malicious code.
- **`pull_request_target` is dangerous.** It runs workflows with write access to the repo based on PR code. If used carelessly, a fork can steal secrets or push to the repo. Read the documentation carefully.
- **Secret masking.** GitHub masks known secret values in logs, but won't catch derived values. Don't base64-encode a secret and print it.
- **OIDC over long-lived credentials.** Always, where possible.
- **Environment protection rules.** Require reviews before prod deploys. Restrict which branches can deploy.
- **`GITHUB_TOKEN` permissions.** The default token has broader permissions than you need for most workflows. Set `permissions:` at the top of the workflow to the minimum required.
- **Dependabot for actions.** Enable the Actions ecosystem in Dependabot so actions get updated when new versions ship.

### Performance tips

- **Use the `ubuntu-latest` runners.** They're the fastest default.
- **Enable concurrent jobs.** Don't sequence unless you have to.
- **Fail fast in matrix builds.** `strategy.fail-fast: true` aborts sibling jobs on the first failure. Default behavior but worth knowing.
- **Cache anything slow.** Composer, Docker layers, static analysis baselines.
- **Skip unnecessary runs.** Path filters on triggers prevent running the whole pipeline for doc changes.
- **Shard tests.** Parallelize long test suites across multiple jobs.

### Common mistakes

- **Unpinned actions.** `actions/checkout@main` is a supply-chain risk.
- **Storing AWS keys as secrets.** Use OIDC.
- **Workflows that rebuild the image per environment.** Build once, promote the digest.
- **Running every workflow on every event.** Use path filters and targeted triggers.
- **Ignoring flaky tests.** Re-running until green teaches the team to ignore real failures.
- **Workflows too big to reason about.** Split into reusable workflows when they grow past a screen or two.
- **No caching.** The difference between a 3-minute and a 10-minute job is usually cache configuration.

### Closing

"So GitHub Actions is workflow-YAML, triggered by repo events, composed of jobs and steps, using reusable actions from the marketplace. For PHP the standard setup is checkout + setup-php + cached composer + services for databases + matrix if needed. Secrets via environments, cloud credentials via OIDC, actions pinned for security, aggressive caching for speed, and reusable workflows for cross-repo consistency. Done well, it's fast, secure, and invisible — which is the highest praise a CI system can get."
