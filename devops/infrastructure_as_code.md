# Infrastructure as code (Terraform, Pulumi, Ansible)

**Interview framing:**

"Infrastructure as code is the practice of describing infrastructure — networks, servers, databases, DNS, IAM, everything — in text files that you commit to version control and apply through automation. The payoff is that infrastructure becomes reviewable, reproducible, and auditable the same way application code is. The three tools I'd mention in an interview are Terraform (declarative, HCL, the industry standard), Pulumi (declarative, real programming languages), and Ansible (imperative, YAML, originally for config management rather than provisioning). They overlap but solve different problems, and picking the wrong one for the job is the most common mistake I see."

### Why IaC at all

Before IaC, infrastructure was built by clicking around in cloud consoles and ssh'ing into servers to configure them. That has obvious problems: no audit trail, no reviewability, no reproducibility, manual errors, drift between what's documented and what's actually running.

IaC fixes this by making infrastructure:

- **Versioned** — git history shows exactly what changed, when, by whom.
- **Reviewable** — infrastructure changes go through the same PR flow as code changes.
- **Reproducible** — the same config produces the same infrastructure. New environments are trivial to spin up.
- **Auditable** — the state of infrastructure is inspectable and comparable against the desired state.
- **Recoverable** — if everything blows up, you redeploy from git.

The cost is complexity. IaC has a learning curve, produces long-lived artifacts (state files) that need to be managed carefully, and introduces its own failure modes. For anything beyond a toy project, the payoff is worth it.

### The declarative vs imperative split

**Declarative** (Terraform, Pulumi, CloudFormation): you describe the *desired state* of the infrastructure. The tool diffs current state against desired state and makes the changes needed to close the gap. You don't specify "create this, then create that" — you describe what should exist and let the tool figure out the order.

**Imperative** (Ansible, raw shell scripts): you describe the *steps* to reach the desired state. "Install this package, copy this file, restart this service". The tool runs the steps in order. You're responsible for making them idempotent (safe to re-run).

Declarative is easier to reason about at scale because the model is "state, not process". Ansible can be written declaratively (most modules are idempotent), but the programming model still encourages step-by-step thinking.

For cloud infrastructure provisioning, declarative tools (Terraform, Pulumi) are the right choice. For in-VM configuration (installing packages, writing config files, restarting services), Ansible is often the better fit. Many teams use both: Terraform provisions the VMs, Ansible configures what's inside them. With containers this split matters less — the image is the configuration.

### Terraform — the de facto standard

Terraform is a declarative, HCL-based tool from HashiCorp. "The industry standard for cloud provisioning" is not an exaggeration — if you're using IaC in the cloud, you probably use Terraform or have considered it.

A minimal example:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  region = "eu-west-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name        = "main-vpc"
    Environment = "production"
  }
}

resource "aws_db_instance" "app" {
  identifier          = "app-prod"
  engine              = "postgres"
  engine_version      = "16"
  instance_class      = "db.t4g.medium"
  allocated_storage   = 100
  storage_encrypted   = true
  db_name             = "app"
  username            = "admin"
  password            = var.db_password
  vpc_security_group_ids = [aws_security_group.db.id]
  backup_retention_period = 7
  deletion_protection = true
}
```

**Key concepts:**

- **Providers** — plugins for each target platform (AWS, GCP, Azure, Cloudflare, Kubernetes, etc.). Hundreds of providers exist.
- **Resources** — the actual things Terraform manages (VPCs, instances, DNS records, IAM roles).
- **Variables** — inputs to the config.
- **Outputs** — values exposed by the config (e.g. database endpoint, load balancer URL).
- **Modules** — reusable collections of resources. Like functions.
- **State** — Terraform's record of what exists in reality. Usually stored remotely (S3, Terraform Cloud, etc.) so the whole team shares it.

### State — the part that scares people (and should)

Terraform's state file is the bookkeeping that maps config to reality. Every resource in the config has a corresponding entry in state that says "this resource in the config corresponds to this thing in AWS". Without state, Terraform doesn't know what it owns and can't compute diffs.

**State is critical and fragile:**

- **Store state remotely.** Never commit state to git. It contains secrets (resource IDs, sometimes passwords) and it's a shared resource that needs locking.
- **Enable state locking.** When Terraform is applying changes, it needs exclusive access to state. S3 backend with DynamoDB for locking is the AWS standard. Missing locking means two people can apply simultaneously and corrupt state.
- **Encrypt state at rest.** The state file contains sensitive information.
- **Back up state.** Corrupted state is a disaster. Versioned S3 buckets give you rollback.
- **Don't edit state manually.** There are commands (`terraform state rm`, `terraform import`) for state surgery, but they're dangerous. Treat manual state edits as a last-resort incident response.

**Workspaces** — Terraform's way to run the same config against multiple environments. A workspace is a separate state file using the same config. `terraform workspace new staging` creates a staging workspace; `terraform apply` applies to whichever workspace is active. Useful for simple cases; many teams prefer separate directories/state files per environment for stronger isolation.

### Modules — the reuse mechanism

A module is a directory of Terraform files you can reuse. You call it like a function:

```hcl
module "billing_service" {
  source  = "./modules/service"
  name    = "billing"
  image   = "registry.example.com/billing:v1.4.2"
  replicas = 4
  database_url = aws_db_instance.app.endpoint
}
```

Modules let you encapsulate "how we deploy a service" in one place and call it many times. Well-designed modules accept narrow inputs and produce narrow outputs, just like good functions.

**Module sources:**

- Local path (`./modules/...`)
- Git URL
- Terraform Registry (for public modules; also hosts an organization-private registry)

The Terraform Registry has thousands of community modules for common tasks. Use them cautiously — quality varies, and you're trusting third-party code to manage your infrastructure.

### Pulumi — Terraform with a real language

Pulumi takes the same model as Terraform (declarative, state-backed, provider-based) but lets you write the configuration in TypeScript, Python, Go, C#, Java, or YAML instead of HCL.

```typescript
import * as aws from "@pulumi/aws";

const vpc = new aws.ec2.Vpc("main", {
  cidrBlock: "10.0.0.0/16",
  tags: {
    Name: "main-vpc",
    Environment: "production",
  },
});

const db = new aws.rds.Instance("app", {
  identifier: "app-prod",
  engine: "postgres",
  engineVersion: "16",
  instanceClass: "db.t4g.medium",
  allocatedStorage: 100,
  storageEncrypted: true,
  dbName: "app",
  username: "admin",
  password: config.requireSecret("dbPassword"),
  backupRetentionPeriod: 7,
});
```

**Pulumi's pitch:**

- **Real programming language.** Loops, conditionals, functions, type systems, IDE support.
- **No custom DSL to learn.** Your team already knows TypeScript or Python.
- **Better testing.** Unit-test your infrastructure logic like any other code.
- **Reuse through normal language constructs.** No HCL-specific module mechanism needed.

**Pulumi's downsides:**

- **Smaller community** than Terraform. Fewer examples, fewer modules, fewer StackOverflow answers.
- **Stateful programming temptation.** People write imperative code and forget that Pulumi is declarative under the hood.
- **Harder to review.** HCL forces simple configs; TypeScript lets you hide logic behind abstractions that are harder to read at review time.

My take: Pulumi is great for teams that already write a lot of TypeScript or Python and find HCL limiting. For most teams, Terraform's simplicity is a feature, not a bug.

### Ansible — the configuration management classic

Ansible is older than Terraform and was originally designed for configuring existing servers, not provisioning new ones. The core idea: describe desired state as a series of **tasks**, run them via SSH against a list of hosts.

```yaml
# playbook.yml
- hosts: webservers
  become: yes
  tasks:
    - name: Install PHP and extensions
      apt:
        name:
          - php8.3-fpm
          - php8.3-intl
          - php8.3-mysql
        state: present
        update_cache: yes

    - name: Copy PHP config
      template:
        src: templates/php.ini.j2
        dest: /etc/php/8.3/fpm/php.ini
      notify: Restart PHP-FPM

    - name: Ensure PHP-FPM is running
      systemd:
        name: php8.3-fpm
        state: started
        enabled: yes

  handlers:
    - name: Restart PHP-FPM
      systemd:
        name: php8.3-fpm
        state: restarted
```

**Key concepts:**

- **Inventory** — the list of hosts Ansible manages, grouped by role.
- **Playbooks** — ordered lists of tasks to run against hosts.
- **Roles** — reusable collections of tasks, templates, and variables.
- **Handlers** — tasks that run only when notified by another task (e.g., restart the service when config changes).
- **Templates** — Jinja2-templated files that can be rendered with host-specific variables.

**When Ansible is the right tool:**

- **Configuring long-lived VMs or bare metal.** Installing packages, writing config files, managing users, setting up system services. Ansible excels here.
- **Ad-hoc operations.** Running a command across a fleet. "Restart this service on all prod nodes." One-liner.
- **Environments without containers.** If you're running traditional VMs, Ansible is often the backbone of your config management.

**When it's not:**

- **Provisioning cloud resources.** Ansible can do this via cloud modules, but it's awkward compared to Terraform.
- **Containerized workloads.** The container image is the configuration; Ansible has nothing to do.
- **Anything requiring a diff-and-apply model.** Ansible runs tasks; it doesn't show you a plan before applying.

### The three-tool split in practice

A typical stack might look like:

- **Terraform** — provisions the cloud infrastructure: VPC, subnets, EKS cluster, RDS database, S3 buckets, IAM roles, DNS, load balancers.
- **Kubernetes YAML (or Helm, or Kustomize)** — defines workloads running inside the cluster.
- **Ansible** — configures anything that's not containerized (a bastion host, legacy VMs, on-prem equipment).
- **Pulumi** — rarely; some teams pick it over Terraform for the programming-language benefit.

You don't typically use all four on one project. Pick the tools for the layer you're operating at.

### Drift — the word you'll hear constantly

Drift is when the actual infrastructure no longer matches the IaC definition. Somebody clicks something in the AWS console, or a script runs outside IaC control, or a provider updates a default value. Now the config and reality disagree.

**Drift detection** — running Terraform plan against current state will show changes IaC wants to make. If those changes are unexpected, something outside IaC touched the infrastructure.

**Preventing drift:**

- **Lock down manual access.** Production changes should go through IaC, not console clicks. Audit and restrict IAM to enforce this.
- **Run plan on a schedule.** Detect drift proactively, not after the next apply.
- **Prefer additive, not overwriting, IaC patterns.** Data resources that *read* existing state are more tolerant of drift than resources that *own* everything.
- **Document exceptions.** Some resources legitimately change outside IaC (e.g., auto-scaling groups). Use `lifecycle` blocks to ignore those specific attributes.

### Testing infrastructure code

Traditional testing is harder for infrastructure because the "unit" is a real cloud resource. Approaches:

- **`terraform plan` in CI.** At minimum, run plan on every PR to catch syntax errors and unexpected changes.
- **`terraform validate` and `tflint`.** Static analysis.
- **Policy-as-code.** Sentinel, Open Policy Agent, Conftest. Define rules like "no public S3 buckets" and enforce them in CI before apply.
- **`terratest` or Pulumi's testing framework.** Spin up real infrastructure in a test account, assert on its behavior, tear it down. Slow and expensive but the only way to test end-to-end.
- **Module tests.** Modules can have their own test suites using ephemeral resources.

The quality bar for infrastructure tests is lower than for application tests, but static analysis + plan review + policy checks catch most common mistakes.

> **Mid-level answer stops here.** A mid-level dev can describe the tools. To sound senior, speak to the operational discipline and the failure modes ↓
>
> **Senior signal:** treating IaC as long-lived production code with its own lifecycle, review discipline, and blast-radius considerations.

### The discipline that matters

- **State is sacred.** Backed up, encrypted, locked, remote.
- **Everything in code.** No "temporary" manual changes. They become permanent and they break IaC.
- **Plan before apply, always.** Never `terraform apply` without reading the plan. Production changes go through a PR with the plan output in the description.
- **Small modules, narrow inputs.** Big monolithic modules are unreviewable.
- **Separate environments, separate state.** Production state is a different file from staging. A mistake in staging never touches production.
- **Environment-level access control.** The person who can apply to staging should not automatically be able to apply to production.
- **Destroy protection on critical resources.** `lifecycle { prevent_destroy = true }` on databases, certificates, DNS zones. One typo shouldn't delete prod.
- **Version pin providers.** A provider upgrade can change resource behavior silently.

### Common mistakes

- **Committing state to git.** Contains secrets. Not locked. Stale the moment two people have it.
- **One giant state file for everything.** Slow plans, big blast radius on mistakes. Split by environment and by domain (networking, data, app).
- **No drift detection.** Drift accumulates silently until the next apply fails or destroys something.
- **Applying directly from local machines.** Production applies should go through a central pipeline with audit logging.
- **Not versioning provider and tool versions.** Someone runs Terraform 1.8 locally, someone else runs 1.5, behaviors diverge.
- **Treating IaC as a one-off setup.** Infrastructure evolves; IaC is a long-lived codebase that needs refactoring, deprecation, and migration strategies.
- **Hardcoding secrets in `.tf` files.** Use secret-fetching at runtime, not secrets in source.

### Closing

"So IaC is how you treat infrastructure as a reviewable, versioned, reproducible artifact. Terraform is the default for cloud provisioning, Pulumi is Terraform in a real programming language for teams that want that trade-off, and Ansible is for configuring VMs or doing ad-hoc operations against a fleet. State management is where most IaC disasters come from, so invest in remote state, locking, backups, and review discipline early. The rewards — fast environment spin-up, safe changes, accurate documentation of what exists — compound over the life of the project."
