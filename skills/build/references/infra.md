# Infra conventions (inlined into the dev spawn prompt)

`build` pastes this file below the `ROLE: infra` line of a `dev` spawn. It covers CI/CD pipelines, deployment configuration, infrastructure-as-code, cloud configuration, and security rules. The generic rules (think-first, scope, quality gates, anti-mock, reply contract) live in `agents/dev.md`.

## Posture

- **Restrictive by default**: security rules, IAM bindings, and network config open only what is explicitly needed. Default-deny.
- **No secrets in the tree**: environment variables go in `.env.example` (placeholders only). Real secrets live in the CI secret store / cloud secret manager. Never commit credentials, tokens, or service-account keys.
- **Tier 4 (escalate, never auto-fix)**: production deploy changes, IAM/permission changes, secrets management, new cloud services, destructive IaC plans. Reply `BLOCKED` with `blocked_reason: hard_spec` and the completed work described.
- **Version pins**: pin third-party GitHub Actions to a full-length commit SHA with a comment naming the tag; first-party actions may use a major tag. Resolve CLI tools to registry latest unless reproducibility forces a pin. Never invent a version from memory ([/_shared/security.md](/_shared/security.md)).

## Stack detection

Inspect the repo to determine the infra/deploy toolchain. Detect everything dynamically:

- **CI provider**: `.github/workflows/`, `.gitlab-ci.yml`, `.circleci/config.yml`, `Jenkinsfile`, `azure-pipelines.yml`.
- **Deploy target**: `firebase.json` / `.firebaserc` (Firebase), `vercel.json`, `netlify.toml`, `app.yaml` (App Engine), `Dockerfile` + registry config, `serverless.yml`.
- **IaC**: `*.tf` (Terraform), `*.bicep`, CloudFormation templates, `pulumi.*`, `cdk.json` (AWS CDK).
- **Package manager / runtime**: `package.json` (scripts, engines) for the build/test/deploy commands the pipeline must invoke.
- **Monorepo context**: which package each deploy target maps to and the build order between shared and dependent packages.

## CI/CD pattern

Follow the existing pipeline structure. For new workflows, the canonical shape:

1. **Trigger** — scope narrowly (`on: push: branches: [main]`, `pull_request`).
2. **Checkout + setup** — pin runtime versions; cache dependencies.
3. **Install** — the project's package manager with a frozen lockfile (`--frozen-lockfile` / `npm ci`).
4. **Verify** — type-check, lint, test, build. Fail fast.
5. **Deploy** — only after verify passes, only on the deploy branch, using keyless auth (workload identity / OIDC) where the provider supports it.
6. **Guard** — deploy steps gated on `github.ref` / environment protection so a PR build can never deploy to production.

```yaml
# GitHub Actions deploy guard example (Firebase Hosting via workload identity)
deploy:
  needs: verify
  if: github.ref == 'refs/heads/main'
  permissions:
    contents: read
    id-token: write   # OIDC — no long-lived secret
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@<sha>  # pin to commit
    - uses: google-github-actions/auth@<sha>
      with:
        workload_identity_provider: ${{ vars.WIF_PROVIDER }}
        service_account: ${{ vars.DEPLOY_SA }}
```

## Firebase deploy config

When the project uses Firebase:

- **`firebase.json`**: declare only the targets the task needs (hosting, functions, firestore, storage). Wire `predeploy` hooks to the project's build scripts so a deploy always ships freshly-built artifacts.
- **`.firebaserc`**: map deploy aliases (`default`, `staging`, `production`) to project IDs. Never hardcode a project ID inside a workflow — read it from the alias or a CI variable.
- **Security rules** (`firestore.rules`, `storage.rules`): default-deny. Every `allow` must be justified by a `verify[]` entry. Never commit a commented-out rule or an `allow read, write: if true` placeholder. Rules changes are verified with `@firebase/rules-unit-testing` in the emulator.
- **Dry run**: `firebase deploy --only <target> --dry-run` (or `firebase hosting:channel:deploy` for preview channels) before shipping.

## IaC rules

- **Idempotent**: re-running `apply` / `plan` on unchanged state is a no-op.
- **State safety**: never delete or mutate remote state by hand. Destructive plans (resource replacement/deletion) are Tier 4: escalate.
- **Variables, not literals**: region, project, and environment values come from declared variables.
- **Least privilege**: IAM roles grant the minimum scope the resource needs.

## Role-specific gates

In addition to the gates in `agents/dev.md`:

1. **Syntax valid**: lint/validate every config you touched — `yamllint` / `actionlint` for workflows, `terraform validate`, `firebase deploy --dry-run`, `docker build` (no push). If no validator exists, parse the file to confirm well-formedness.
2. **Existing pipelines intact**: no removed required checks; jobs the task did not target still run.
3. **No secrets committed**: grep your diff for tokens, keys, and credentials. `.env.example` holds placeholders only.
4. **Restrictive default**: nothing left world-readable or world-writable by accident.
5. **Reproducible**: pinned versions/SHAs, frozen lockfiles, deterministic build steps.
6. **Deploy guarded**: production deploy steps are branch- and environment-gated.
7. **Documented**: every non-obvious config block carries an inline comment (why this trigger scope, why this permission, why this pinned SHA); new environment variables are documented in `.env.example` with a one-line description.

**BANNED** (in addition to `agents/dev.md`): `# TODO` / `# FIXME` / `# PLACEHOLDER` in config where a real value belongs; empty `KEY=` outside `.env.example`; commented-out security rules or deploy steps left as "later"; stub deploys that ship nothing; `allow read, write: if true`; workflow jobs that only `echo` and exit.

**SELF-CHECK:** "Could this be deployed to production right now, exactly as written?" If no, the work is not done.
