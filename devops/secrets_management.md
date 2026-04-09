# Secrets management

**Interview framing:**

"Secrets management is the practice of keeping credentials, API keys, tokens, certificates, and other sensitive data out of source code, out of container images, out of logs, and in a system that controls access, rotation, and auditability. The thing people get wrong is treating secrets as configuration — the same as a database hostname — when they actually need a fundamentally different handling model. The senior answer is knowing the tools (Vault, cloud secret managers, Kubernetes Secrets, SOPS), knowing the attack scenarios they defend against, and having a clear story for rotation, access control, and incident response when a secret leaks."

### What counts as a secret

- **Credentials** — database passwords, service account keys, admin tokens.
- **API keys** — third-party service tokens (Stripe, SendGrid, AWS).
- **Certificates and private keys** — TLS certs, signing keys.
- **Encryption keys** — application-level encryption, JWT signing.
- **Webhook secrets** — HMAC signing keys for verifying incoming webhooks.
- **OAuth client secrets** — not public-facing but still sensitive.

What's **not** a secret (even though it feels sensitive):

- Database hostname, port, username
- Public API endpoints
- Feature flag values
- Public keys (part of a keypair)

The distinction matters: non-secrets go in normal config. Secrets need extra handling. Mixing them up means either over-protecting trivial data or under-protecting real secrets.

### The failure modes

Understanding what can go wrong explains why secrets management matters:

1. **Committed to git.** Once in history, always in history. A revoked-and-rotated key is still exposed if someone clones the repo.
2. **Hardcoded in config files.** Same as above but in a different file.
3. **Baked into Docker images.** `docker inspect` shows environment variables; layers contain every file ever added. Once in the image, the secret is in every pull of that image forever.
4. **Logged accidentally.** `var_dump($_ENV)` in a stack trace. Exception messages containing the connection string. Application logs with secret values.
5. **Passed through environment variables visible to all processes.** `ps auxe` shows environment. Container metadata APIs return env vars.
6. **Shared between environments.** Dev uses the same API key as prod, dev gets compromised, prod is compromised.
7. **No rotation.** A secret that's never rotated and may have been exposed years ago is still valid.
8. **No audit trail.** Nobody knows who accessed what, when.
9. **Broadly accessible.** Every engineer has prod database credentials because "we trust each other".

Every secrets management practice exists to prevent one or more of these.

### The principles

- **Never in source.** Secrets don't go in git. Ever. Not even in private repos.
- **Never in images.** Secrets come in at runtime, not build time.
- **Least privilege.** Each service, user, and role gets only the secrets it needs. No shared admin credentials.
- **Rotation.** Every secret has a rotation process. Unused secrets are revoked.
- **Audit.** Every secret access is logged. Who, what, when.
- **Separation per environment.** Dev, staging, and prod have different secrets.
- **Short-lived where possible.** Prefer tokens with minutes-to-hours lifetimes over keys with years-long ones.
- **Encrypted at rest and in transit.** Always.

### The tools

#### HashiCorp Vault — the full-featured default

Vault is a dedicated secrets management system. It stores secrets encrypted, exposes them via an API, supports access control policies, audit logging, automatic rotation, and dynamic secret generation (creating short-lived database credentials on demand).

**Key features:**

- **Static secrets** — you write a secret, Vault stores it encrypted, apps fetch it with a token.
- **Dynamic secrets** — Vault generates a new, short-lived credential each time. For databases, Vault can create a user with a TTL and clean it up automatically.
- **Encryption as a service** — apps send plaintext to Vault's encrypt endpoint and get ciphertext back, without ever seeing the encryption key.
- **Policies** — fine-grained rules about who can read/write what.
- **Audit logs** — every operation is logged.
- **Multiple auth methods** — tokens, AppRole, Kubernetes service accounts, cloud IAM, OIDC, LDAP.

**When it's worth it:** any serious production deployment where secrets management matters, you have the operational capacity to run it, and cloud-native managers are insufficient.

**Cost:** running Vault is non-trivial. You need HA, backup, unseal management, upgrade planning. Many teams use HashiCorp Cloud Platform for managed Vault rather than self-hosting.

#### Cloud provider secret managers

- **AWS Secrets Manager** / **AWS Parameter Store (SecureString)**
- **GCP Secret Manager**
- **Azure Key Vault**

These are first-party cloud services that store secrets, integrate with the cloud's IAM, and handle rotation (for supported types). They're less featureful than Vault but much simpler to run — they're managed services, no unseal ceremony, no HA planning.

**When they're enough:** if you're committed to a single cloud and the feature set meets your needs, a cloud secret manager is the simplest option. They integrate naturally with the rest of the cloud platform, IAM is already wired up, and access is audited via the cloud's standard audit logs.

**When they're not:** multi-cloud setups, on-prem components, or when you need features like dynamic database credentials or encryption as a service.

#### Kubernetes Secrets

The built-in Kubernetes Secret object stores key-value data and mounts it into pods as env vars or files. They look like a secrets management solution but they're barely one:

- **Base64-encoded, not encrypted.** By default, Kubernetes stores Secrets in etcd as base64. That's encoding, not encryption. Anyone who can read etcd (or the API server) can read the secret.
- **No rotation.** Kubernetes doesn't rotate secrets; updating a Secret is a manual operation.
- **No audit.** API server logs show access but they're coarse-grained.
- **No versioning.** Overwriting a Secret loses history.

Kubernetes Secrets are fine for **low-sensitivity** values or as a delivery mechanism for secrets fetched from elsewhere. For real secret management, treat Kubernetes Secrets as "the thing my pod reads", with the actual secret source being Vault, a cloud manager, or a similar external system.

**Encryption at rest for etcd** is a mitigation — it encrypts Secrets on disk using a KMS. It doesn't make Kubernetes Secrets a proper secret management system, but it raises the bar significantly.

#### External Secrets Operator

The bridge between Kubernetes and real secret managers. You install the External Secrets Operator in your cluster, point it at Vault / AWS Secrets Manager / GCP Secret Manager, and it synchronizes secrets into Kubernetes Secret objects automatically.

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: database-secret
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: /prod/billing/database
        property: url
```

The app sees a normal Kubernetes Secret; the actual secret lives in Vault and rotates automatically. Best of both worlds: apps stay simple, secrets stay managed.

#### SOPS — secrets in git, encrypted

SOPS (Secrets OPerationS) is a tool that encrypts individual values in YAML/JSON/env files using a KMS. You commit the encrypted file to git; decryption happens at deploy time using a cloud KMS or PGP key.

```yaml
# secrets.enc.yaml (committed to git)
database:
  url: ENC[AES256_GCM,data:xHf...,iv:...,tag:...]
  password: ENC[AES256_GCM,data:kY9...,iv:...,tag:...]
```

**Pros:**

- Secrets are in the repo, next to the code that uses them. Version history, code review, the normal git workflow.
- No extra infrastructure beyond a KMS.
- Works for GitOps workflows (the config repo holds encrypted secrets).

**Cons:**

- Rotation requires re-encrypting and committing new versions.
- Access control is KMS-level, not per-secret.
- Still requires discipline to not accidentally decrypt and commit plaintext.

**When it's a good fit:** GitOps-heavy teams, small to medium deployments, cases where the simplicity of "secrets in the repo" outweighs the limitations.

#### Sealed Secrets

Similar idea to SOPS but Kubernetes-specific. A controller in the cluster has a private key; you encrypt Secret manifests with the public key using `kubeseal`. The encrypted `SealedSecret` object is committed to git; the controller decrypts it and creates a real Secret.

Narrower than SOPS (only Kubernetes Secrets) but cleaner integration with Kubernetes-native workflows.

### Patterns for getting secrets to your PHP app

**Option 1: Env vars injected at pod startup.**

External Secrets Operator syncs a Kubernetes Secret from Vault; the pod mounts it as env vars. The app reads from `$_ENV['DATABASE_URL']`. Simple, battle-tested, works everywhere.

Downside: env vars are visible to `/proc/*/environ` and to the Kubernetes API, so anyone with pod-level access can see them.

**Option 2: Mounted files.**

Same sync mechanism, but the Secret is mounted as files in a volume. The app reads `/etc/secrets/database_url`. Same security profile as env vars, but supports larger values (certs, JSON blobs) and updates live when the underlying Secret changes.

**Option 3: Runtime fetch from a secret manager.**

The app itself authenticates to Vault (using a Kubernetes service account via the Kubernetes auth method) and fetches secrets on startup. No secrets flow through Kubernetes at all; the app talks directly to Vault.

Pros: secrets are never in Kubernetes Secrets, never in env vars visible to other pods, never in logs.
Cons: more application code, startup latency, Vault becomes a hard dependency for app startup.

**Option 4: Init container fetches, shares via volume.**

An init container fetches secrets and writes them to an `emptyDir` volume the main container reads. Keeps the fetch logic out of the main app and works with apps that don't natively support Vault.

I most often use option 1 or 2 with External Secrets, occasionally option 3 for very sensitive services.

### Rotation

Every secret has a rotation story:

- **Static secrets** (third-party API keys) — rotated on a schedule (every 90 days, every year) or in response to a suspected leak. Manual or semi-automated process: generate new secret in the provider, update the secret manager, roll the app to pick it up, verify it works, revoke the old one.
- **Dynamic secrets** (database credentials generated by Vault) — Vault rotates them automatically. Each pod gets a short-lived credential tied to its TTL; when it expires, the app requests a new one.
- **Certificates** — cert-manager in Kubernetes handles this for TLS certs. Requests, renewals, and renewals are automatic.

The mental test: "if this secret were leaked, how fast could I rotate it?" If the answer is "I don't know" or "that would be really painful", rotation is broken. Fix it before you need it.

### Audit and incident response

When a secret leaks (or might have leaked), you need to be able to:

1. **Determine what was exposed.** Which secret, what it protected.
2. **Rotate it immediately.** The rotation process better not take hours.
3. **Audit who accessed it.** Who could have seen it? Who did see it? The audit log answers this.
4. **Revoke derived credentials.** If the compromised secret was used to generate other credentials, revoke those too.
5. **Post-incident hardening.** Why was it exposed? What changes prevent a recurrence?

The audit log is the centerpiece of this process. Without it, you're guessing about blast radius. With it, you know exactly who accessed the secret and when, and you can make informed decisions about how far the compromise might have spread.

> **Mid-level answer stops here.** A mid-level dev can name the tools. To sound senior, speak to the rotation story, the incident response plan, and the subtle ways secrets leak even with good tooling ↓
>
> **Senior signal:** recognizing that secrets management is a process as much as a tool, and investing in the discipline around the tooling.

### The subtle leaks

These are the ones that surprise teams:

- **Logs.** A `var_dump` of the config, an exception message with a connection string, a debug log of an outgoing HTTP request with an Authorization header. Audit what your app logs. Use structured logging and explicit allow-lists.
- **Error tracking.** Sentry and similar tools capture local variables in error context. Configure them to scrub sensitive fields.
- **Metrics and traces.** OpenTelemetry traces can capture attribute values. Don't tag spans with secret values.
- **Environment inspection.** `/proc/*/environ`, container metadata endpoints, Kubernetes API access. Anyone with pod-level access can see env vars.
- **Core dumps.** A crashing process can produce a memory dump containing secrets.
- **Backups.** If your database contains encrypted secrets (or encrypted PII), backups contain them too. Secure backups like you secure live data.
- **CI pipeline logs.** A failing step that prints the env vars it received.

### Common mistakes

- **Secrets in git history.** Even old, deleted secrets are still in git history. Rotate anything that was ever committed.
- **Shared credentials across environments.** Prod compromise = dev compromise. Separate them.
- **No rotation plan.** "We'll rotate if something bad happens." Too late.
- **Kubernetes Secrets treated as secure.** They're base64, not encryption. Use External Secrets or encryption at rest.
- **Secrets in build args.** Docker build args appear in image history. Not a secure place.
- **Env vars logged by the framework.** Symfony's debug toolbar, Laravel's error pages. These can leak secrets in development if you're not careful.
- **Access control that's too broad.** Every developer has production secrets "for convenience". Convenience is not a security strategy.
- **No monitoring on secret access.** Secrets were accessed from an unusual location, nobody noticed.
- **Storing secrets next to data.** A database that stores its own encryption key defeats the encryption.

### The "how do I handle secrets in my PHP app" checklist

- [ ] No secrets in git, ever.
- [ ] No secrets in Docker images, ever.
- [ ] Secrets come from env vars or mounted files at runtime.
- [ ] Env vars and files are sourced from a real secrets manager (Vault, cloud, or External Secrets).
- [ ] Dev, staging, and prod have different secrets.
- [ ] Rotation process is documented and tested.
- [ ] Logs and error reports scrub sensitive values.
- [ ] Access control is least-privilege; audits show who accessed what.
- [ ] Incident response plan exists for compromised secrets.
- [ ] Secrets used in CI pipelines are scoped to specific jobs and masked in logs.

### Closing

"So secrets management is a combination of a tool (Vault, cloud manager, External Secrets, SOPS) and a set of practices (never in source, never in images, least privilege, rotation, audit, separation per environment, scrubbing logs). The tool matters less than the discipline — I've seen teams with Vault and bad practice leak secrets, and teams with SOPS and good discipline stay secure. Pick the simplest tool that meets your needs, invest heavily in the rotation and incident-response story, and treat every accidental exposure as a real incident. Secrets management is boring work, and the boring work is what keeps production safe."
