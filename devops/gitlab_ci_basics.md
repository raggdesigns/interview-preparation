# GitLab CI basics

**Interview framing:**

"GitLab CI is GitLab's built-in pipeline system — same idea as GitHub Actions but with a different programming model and a few genuinely nice ergonomic wins. The core primitives are pipelines, stages, and jobs, configured via a single `.gitlab-ci.yml` file. It's been around longer than Actions, is more tightly integrated with the rest of GitLab (merge requests, environments, reviews, deploy boards), and tends to be the default choice when your team is already on self-hosted GitLab."

### The mental model

- **Pipeline** — the top-level execution of a `.gitlab-ci.yml` file, triggered by events like push or MR.
- **Stage** — a phase of the pipeline. All jobs in a stage run in parallel; stages run sequentially. Classic stages: `build`, `test`, `deploy`.
- **Job** — a unit of work within a stage. Runs in a single runner, produces artifacts and logs.
- **Runner** — the agent that executes jobs. GitLab.com provides shared runners; self-hosted GitLab instances typically bring their own.

### A minimal PHP pipeline

```yaml
# .gitlab-ci.yml
stages:
  - lint
  - test
  - build
  - deploy

variables:
  COMPOSER_ALLOW_SUPERUSER: "1"
  DATABASE_URL: "mysql://root:root@mysql:3306/test"

default:
  image: php:8.3-cli
  before_script:
    - apt-get update -qq && apt-get install -y -qq git unzip libicu-dev libzip-dev
    - docker-php-ext-install intl zip pdo_mysql
    - curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

.composer_cache: &composer_cache
  cache:
    key:
      files:
        - composer.lock
    paths:
      - vendor/

lint:
  stage: lint
  <<: *composer_cache
  script:
    - composer install --no-interaction --prefer-dist
    - vendor/bin/phpstan analyse

test:
  stage: test
  services:
    - name: mysql:8.0
      alias: mysql
  variables:
    MYSQL_DATABASE: test
    MYSQL_ROOT_PASSWORD: root
  <<: *composer_cache
  script:
    - composer install --no-interaction --prefer-dist
    - vendor/bin/phpunit

build:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  variables:
    DOCKER_HOST: tcp://docker:2375
    DOCKER_DRIVER: overlay2
    DOCKER_TLS_CERTDIR: ""
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER --password-stdin $CI_REGISTRY
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  only:
    - main

deploy_staging:
  stage: deploy
  image: alpine:latest
  environment:
    name: staging
    url: https://staging.example.com
  script:
    - apk add --no-cache curl
    - ./deploy.sh staging $CI_COMMIT_SHA
  only:
    - main

deploy_production:
  stage: deploy
  image: alpine:latest
  environment:
    name: production
    url: https://app.example.com
  when: manual
  script:
    - apk add --no-cache curl
    - ./deploy.sh production $CI_COMMIT_SHA
  only:
    - main
```

This is a complete PHP pipeline: lint → test → build → deploy. Production deploy is manual. Staging is automatic.

### Pre-defined variables

GitLab exposes a lot of context via environment variables that your scripts can use:

- `CI_COMMIT_SHA` — the commit being built.
- `CI_COMMIT_REF_NAME` — branch or tag name.
- `CI_COMMIT_MESSAGE` — the commit message.
- `CI_PIPELINE_ID` — unique pipeline ID.
- `CI_JOB_ID` — unique job ID.
- `CI_REGISTRY_IMAGE` — the image path in the project's container registry.
- `CI_ENVIRONMENT_NAME` — the environment this job deploys to.
- `CI_MERGE_REQUEST_IID` — the MR number (when running for MRs).

There are hundreds. You'll use these constantly for tagging builds, constructing URLs, and wiring things together.

### Services — sidecar containers for jobs

The `services:` keyword attaches additional containers to a job — typically databases, brokers, and other dependencies. They share a network with the job's container, reachable by their alias.

```yaml
test:
  services:
    - name: mysql:8.0
      alias: mysql
    - name: rabbitmq:3-management-alpine
      alias: rabbitmq
    - name: redis:7-alpine
      alias: redis
  variables:
    MYSQL_ROOT_PASSWORD: root
    DATABASE_URL: "mysql://root:root@mysql:3306/test"
  script:
    - vendor/bin/phpunit
```

Much cleaner than setting up the services manually. This is similar to GitHub Actions' `services:` but integrated more deeply with the runner.

### Caching and artifacts — two different things

GitLab separates the concepts clearly, which Actions doesn't.

- **Cache** — data you'd like to speed up subsequent runs with, but that can be regenerated. Composer's `vendor/`, Node's `node_modules/`, compiled test databases. The cache is shared across pipelines but not guaranteed to be present.

- **Artifacts** — files produced by a job that downstream jobs in the same pipeline (or humans downloading from the UI) need. Test reports, built binaries, generated docs. Artifacts are guaranteed to be passed to dependent jobs.

```yaml
build:
  stage: build
  script:
    - make build
  artifacts:
    paths:
      - dist/
    expire_in: 1 week

deploy:
  stage: deploy
  dependencies:
    - build
  script:
    - ./deploy.sh dist/
```

The `deploy` job gets `dist/` from the `build` job automatically. Artifacts also include test reports, which GitLab parses and displays inline in merge requests:

```yaml
test:
  script:
    - vendor/bin/phpunit --log-junit report.xml
  artifacts:
    reports:
      junit: report.xml
```

Failed tests show up in the MR UI with line-level annotations. This is one of GitLab CI's genuinely nice features.

### Environments and deployments

GitLab has a first-class concept of environments that integrates with the UI. You define an environment on a deploy job, and GitLab tracks which commit is deployed to each environment, with a deploy history and rollback buttons.

```yaml
deploy_staging:
  stage: deploy
  environment:
    name: staging
    url: https://staging.example.com
  script:
    - ./deploy.sh staging

deploy_review:
  stage: deploy
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    url: https://$CI_COMMIT_REF_SLUG.preview.example.com
    on_stop: stop_review
  script:
    - ./deploy.sh review $CI_COMMIT_REF_SLUG

stop_review:
  stage: deploy
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    action: stop
  script:
    - ./teardown.sh review $CI_COMMIT_REF_SLUG
  when: manual
```

**Review apps** are ephemeral environments created per MR. Every open MR gets its own deployed preview, automatically torn down when the MR is merged or closed. This is the killer feature for frontend-heavy teams and it works for backend APIs too.

### Rules vs only/except

Older pipelines used `only:` and `except:` for conditional execution. Newer syntax uses `rules:`, which is more flexible.

```yaml
deploy_production:
  script: ./deploy.sh production
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
    - when: never
```

"Run this job if the branch is main (with manual approval), otherwise don't run at all."

Rules compose more cleanly than only/except and are the recommended syntax for new pipelines. Old `only/except` still works but is considered legacy.

### Include and templates

Large pipelines get unwieldy in a single file. GitLab supports `include:` for pulling in external YAML fragments:

```yaml
include:
  - local: '/ci/lint.yml'
  - local: '/ci/test.yml'
  - local: '/ci/deploy.yml'
  - project: 'org/ci-templates'
    file: '/docker-build.yml'
  - template: 'Security/SAST.gitlab-ci.yml'
```

You can include local files, files from other projects, or built-in GitLab templates. The built-in templates cover things like SAST, DAST, dependency scanning, license compliance — worth enabling on any serious project.

### Multi-project pipelines

A job in one project can trigger a pipeline in another:

```yaml
trigger_downstream:
  stage: deploy
  trigger:
    project: org/downstream-service
    branch: main
    strategy: depend
```

`strategy: depend` makes the triggering pipeline wait for the downstream pipeline to finish, inheriting its status. Useful when an API change in one repo needs to trigger integration tests in another.

### Self-hosted runners

GitLab runners are open source and commonly self-hosted, especially for teams on self-hosted GitLab. Types:

- **Shell executor** — runs jobs directly on the runner machine. Simple, not isolated.
- **Docker executor** — runs each job in a fresh Docker container. The default choice.
- **Kubernetes executor** — each job runs as a pod. Scales well, integrates with existing K8s infrastructure.

Registration is a one-command process. Self-hosted runners can be tagged and jobs can request specific tags, letting you route jobs to runners with specific capabilities.

### CI/CD Variables — secrets and configuration

Variables are defined at the group, project, or environment level via the GitLab UI, and exposed to jobs:

```yaml
deploy:
  script:
    - curl -H "Authorization: $API_TOKEN" https://api.example.com/deploy
```

Variables can be:

- **Protected** — only exposed to jobs running on protected branches or tags.
- **Masked** — hidden in job logs.
- **Environment-scoped** — only exposed to jobs running against specific environments.

Combined with protected branches (where only maintainers can push) and environment approval rules, this gives you a reasonable secrets story without external tools. For production, though, external secret management (Vault, cloud KMS) is usually better — see [secrets_management.md](secrets_management.md).

### Merge request pipelines

A job can target different pipelines:

- **Branch pipeline** — runs on a push to a branch.
- **Merge request pipeline** — runs specifically for the MR, can access MR context.
- **Merged results pipeline** — runs against a simulated merge commit, catching conflicts before merging.
- **Merge train** — serializes merges through a queue, each running against the latest combined state.

Merge trains are the production-grade way to keep main always-green on high-traffic repos. Every MR waits its turn, runs against what main will look like after the previous MRs merge, and only merges if green. Eliminates "my MR passed but broke main after merging".

> **Mid-level answer stops here.** A mid-level dev can write a `.gitlab-ci.yml`. To sound senior, speak to the trade-offs and operational concerns ↓
>
> **Senior signal:** treating CI as production infrastructure and picking GitLab CI's features deliberately for the problems they solve.

### GitLab CI vs GitHub Actions — honest comparison

- **Actions has a bigger marketplace.** Way more reusable actions than GitLab CI templates.
- **GitLab has better MR integration.** Deploy boards, test reports inline in MRs, environments with rollback UI, review apps — these are more polished in GitLab.
- **GitLab's programming model is simpler.** Stages + jobs, linear flow. Actions' events + jobs + steps is more flexible but also more confusing.
- **GitLab CI's cache / artifacts distinction is clearer.** Actions conflates them.
- **Actions has better cloud OIDC story.** GitLab has OIDC too but Actions' integration is more mature.
- **Self-hosting.** GitLab CI is free and open-source; Actions runners are too but the overall platform is not.

Most teams use whichever platform their code is on. If you're on GitLab, use GitLab CI; if GitHub, use Actions. Porting between them is possible but annoying.

### Common mistakes

- **Using `only/except` for anything complex.** Switch to `rules:`.
- **Not using `services:`.** Manually starting databases in `before_script` is slower and uglier.
- **Forgetting `dependencies:`.** Jobs don't inherit artifacts unless declared.
- **Masking secrets only at the output layer.** Masked variables are hidden in logs but not in memory dumps, stack traces, or derived values.
- **Unbounded cache growth.** Caches accumulate. Use `cache:key:files` for hashed keys and keep cache sizes in check.
- **Running the whole pipeline on every event.** Use `rules:` to skip irrelevant runs.
- **Large monolithic `.gitlab-ci.yml`.** Split with `include:` when it grows beyond a screen or two.
- **Shared runners with no resource limits.** A runaway job can take down the runner for everyone.

### Closing

"So GitLab CI is stages + jobs in a single YAML file, with services for sidecars, artifacts for cross-job data, caches for speedups, environments for deployment tracking, rules for conditional execution, and include for modular pipelines. The killer features are merge request integration, review apps, merge trains, and the deploy-history UI. Done well, it's a complete delivery pipeline with minimal external tooling — which is exactly what tightly-integrated platforms exist to deliver."
