# security reference

Detail split out of [security.md](security.md) so the contract every skill loads stays small. The env-first ordering rule, the five trust boundaries, and the kill switch lives there; everything below is loaded on demand.

---

### 1. The model — three risks × three layers

| Risk type (who originates harm) | Definition |
|---|---|
| **User misuse** | A user — maliciously or carelessly — directs the agent to do something harmful. |
| **Model misbehavior** | The agent takes a harmful action no one asked for. |
| **External attacker** | The agent is attacked through external vectors: tools, files, network, fetched content. |

| Defense layer | Nature | Blitz instances |
|---|---|---|
| **Environment** | **Deterministic boundary** — hard limit on reach, holds regardless of cause. | `block-*.sh`, `pre-edit-guard.sh`, `disallowed-tools`, startup-validate, `[0:200]` caps, platform auto-mode hard-deny. |
| **Model** | **Probabilistic** — steers behavior; never a guarantee. | skill SAFETY-RULES prose, completion/DoD gates, critic 20-detector, reviewers, output-style. |
| **External content** | The **attack-surface** layer; mitigated by least-privilege + live inspection. | content-inspection (research/research-critic), MCP tool-return/description inspection, research-critic liveness. |

Authoritative cell-by-cell mapping: [`docs/security/containment/blitz-surface-map.md`](../../docs/security/containment/blitz-surface-map.md).

---

### 4. Risk × layer mapping (summary)

|                       | Environment (primary) | Model (defense-in-depth) | External content |
|-----------------------|------------------------|---------------------------|-------------------|
| **User misuse**       | block-* hooks, pre-edit-guard, platform hard-deny | SAFETY-RULES prose, autonomy levels | n/a |
| **Model misbehavior** | test/typecheck/as-any guards, ratchet revert, `disallowed-tools`, `tasks-guard.sh`, `kill-switch.sh` | critic 20-detector, reviewers | n/a |
| **External attacker** | main-thread `[0:200]` caps, startup-validate (tasks.json / solutions / inbox / mailbox), sub-agent cap, inbox/mailbox caps (TB-5) | injection-resistance (inherited); message = data, never approval | content inspection; research-critic liveness; channel payloads (TB-5) |

---

### 5. Canonical-owner declaration + registration contract

This file is the canonical owner of Blitz's security posture. Bidirectional citations:
- `hooks/scripts/block-*.sh` + `pre-edit-guard.sh` + `session-start.sh` + `startup-validate.sh` + `tasks-guard.sh` + `kill-switch.sh` headers → cite this doc (environment-layer enforcement points).
- [agents.md](agents.md) (TB-3, spawn reply contract; TB-5 cross-session messaging surface), [sessions.md](sessions.md) startup (TB-1/TB-2) + messaging / mailbox protocol (TB-5), [research-critic.md](../../agents/research-critic.md) (TB-4), `hooks/scripts/stop-turn.sh` + `_lib/common.sh` (`blitz_mailbox_send`, `blitz_inbox_post`, TB-5) cite this doc.

**Registration contract — a new deterministic security guard MUST:**
1. Cite the TB it enforces in its header/prose.
2. Add a row to [check-registry.json](check-registry.json) under `pillar: security`.
3. Be reachable via `/blitz:audit --pillar security`.

---

### 6. Scope (right-sizing — what Blitz does NOT do)

Blitz is a **Claude Code-class HITL plugin**; it inherits the platform's OS sandbox (Seatbelt/bubblewrap) + approval dialog and operates at the plugin layer above it.

| Out of scope | Why |
|---|---|
| VMs / gVisor / hypervisor isolation | No deployment surface; Blitz runs inside the platform sandbox. |
| MITM egress proxy | No network infra in a plugin; cannot intercept syscalls. |
| Reimplementing auto-mode tiers / ~20 hard-deny rules | Inherited from the platform; `block-*.sh` complement, not replace. |
| Formal capability interpreter (CaMeL's provable-security core) | Blitz has no mediating interpreter; `source_trust`/provenance tags are defense-in-depth heuristics *in the spirit of* CaMeL capabilities, **not** a formal guarantee. Stated to avoid over-claiming. |
| Enterprise governance (ISO 42001, six-agency guidance) | Applies to the org deploying Blitz, not Blitz's own posture. |
| Trust-prompt enforcement | Delegated to the platform's "Do you trust this folder?"; Blitz's duty is to not parse-execute project config before it (Gap 5; [hook-trust.md](#hook-trust-boundary-tb-1)). |

**In scope** = the layer Blitz controls: tool grants, persistent-state validation, sub-agent trust labeling, fetched-content inspection, deterministic guards — all expressible with existing primitives (hooks, check-registry, Haiku classifier agents, `[0:200]` capping).

---

### Supply chain (ASI04)

Blitz is itself a dependency with hooks that run on `SessionStart`. Treat it as OWASP Agentic ASI04 supply-chain surface:
- Pin the plugin `version` in the marketplace install (`claude plugin install blitz@<version>` / a pinned `plugins:` entry in `.claude/settings.json`); keep plugin auto-update **off** so a new release cannot change hook behavior without a reviewed bump.
- Review `hooks/hooks.json` and `hooks/scripts/*.sh` before enabling a version — hooks execute with the user's permissions.
- Run `claude plugin validate .` on the checkout you are about to enable; the plugin's own pre-commit runs the same validators.
- npm-sourced plugins are fetched with `--ignore-scripts` and integrity-verified (≥2.1.275); Blitz has no npm dependencies of its own.
- **Plugin4Shell (disclosed 2026-09-18):** git resolves a hash-shaped branch name as a ref, so a plugin pinned by commit SHA from a git source could be silently swapped by the repository owner. Fixed in Claude Code 2.1.179 (blitz's floor is 2.1.271); GitHub-hosted marketplaces are immune because GitHub rejects hash-like branch names, and blitz's marketplace is GitHub-hosted. Install from `lasswellt/blitz-cc` only, and pass `--accept-command <sha256>` (≥2.1.269) when a marketplace declares an install command.
- Repo-provided `.claude/settings.json` hooks and memory directories are untrusted until reviewed; `blockReadsOutsideWorkingDirectories` (2.1.277) stops repo-chosen memory dirs from loading. Critics run with `omitClaudeMd: true` so repo files cannot steer the evaluator.
- Package adds inside a consumer project follow the [Package Install Policy](#package-install-policy) below — resolved from the registry, never from memory.

---

### 7. Related protocols
- [sessions.md](sessions.md) — startup state read (TB-1/TB-2 enforcement point); conflict-matrix messaging + mailbox protocol; `[0:200]` cap rule (TB-5).
- [agents.md](agents.md) — `SendMessage` surface and settings keys (TB-5); sub-agent reply contract (TB-3); Haiku-class classifier routing (TB-2/TB-4).
- [hook-trust.md](#hook-trust-boundary-tb-1) — pre-trust parsing boundary (TB-1).
- `scripts/tasks.sh` + `hooks/scripts/tasks-guard.sh` — the single writer of `tasks.json` (TB-2).
- [check-registry.json](check-registry.json) — `security` pillar checks.
- Derivation + research: [docs/security/containment/](../../docs/security/containment/) — surviving artifacts are [`blitz-surface-map.md`](../../docs/security/containment/blitz-surface-map.md) (risk × layer surface map) and [`SYNTHESIS.md`](../../docs/security/containment/SYNTHESIS.md) (sequenced integration plan).



---

<!-- ===== Absorbed from hook-trust.md ===== -->

## Hook Trust Boundary (TB-1)

> Companion to [threat-model.md](#threat-model--blitz-containment-posture-canonical-owner). Defines how Blitz hooks must treat project-local files, and records the audited invariant that no hook executes project-controlled content before the platform trust prompt.

### The rule

Blitz hooks fire on Claude Code lifecycle events (`SessionStart`, `PreToolUse`, `PostToolUse`, …). Some run **before** the user has accepted "Do you trust this folder?". The article's pre-trust-config-execution incident (AP-1) was a cloned repo whose `.claude/settings.json` defined a hook that ran attacker code at startup, before that prompt.

**Therefore:**
1. **Treat project-local files as untrusted inbound data**, not trusted local config — `.cc-sessions/sessions/*.json`, `activity-feed.jsonl`, `inbox.jsonl`, `mailbox/*.jsonl`, CLAUDE.md, `docs/plans/*/tasks.json`, `docs/solutions/*.md`. This is [threat-model.md](#threat-model--blitz-containment-posture-canonical-owner) §3 TB-1 (and TB-5 for the message files).
2. **A hook MUST NOT `eval`, `source`, or otherwise execute** any project-controlled file's contents. Hooks may *parse* (jq) and *echo*, never execute.
3. **Echoed free-text fields MUST be capped + injection-scanned** before reaching context. `session-start.sh` caps every echoed field at 200 chars (parity with the `[0:200]` cap rule in [sessions.md](sessions.md)) and replaces injection-marker hits with `[quarantined: …]`.
4. **Execution-bearing parsing defers to the platform trust prompt.** Blitz relies on the Claude Code platform for the trust gate itself — it does not reimplement it (threat-model.md §6). Blitz's duty is to not parse-execute project config before it.

### Audited invariant (keep true)

> **No Blitz hook executes project-controlled content pre-trust.**

Verified 2026-05-31 across all `hooks/scripts/*.sh`:
- The `block-*.sh` + `pre-edit-guard.sh` hooks read `tool_input` (the agent's *own* proposed action from the harness), not committed project files.
- `session-start.sh` parses `.cc-sessions/` JSON with `jq` and echoes sanitized text — no `eval`/`source` of project content.
- `startup-validate.sh` reads + scans (`.cc-sessions/`, `docs/plans/*/tasks.json`, `docs/solutions/*.md`); it does not execute entries.
- `tasks-guard.sh` and `kill-switch.sh` read `tool_input` / the presence of `.cc-sessions/STOP` and return a decision; they execute nothing.

**Regression guard (audit `sec-containment` / pre-commit):**
```bash
# Command-position eval/source/. only (excludes comments + the word "source" in jq/prose).
# The only legitimate hit is `. "$(dirname "$0")/_lib/common.sh"` — first-party, filtered out.
grep -REn '^[[:space:]]*(eval|source|\.)[[:space:]]+' hooks/scripts/*.sh \
  | grep -v '_lib/common.sh' || echo "clean: no pre-trust execution of project content"
```

### Related
- [threat-model.md](#threat-model--blitz-containment-posture-canonical-owner) §3 TB-1, §6 (scope: trust-prompt delegated to platform).
- `hooks/scripts/session-start.sh` — the SessionStart enforcement point.
- `hooks/scripts/startup-validate.sh` — persistent-state validation (TB-2).



---

<!-- ===== Absorbed from package-install-policy.md ===== -->

## Package Install Policy

Canonical rule for how skills and agents add new npm/pnpm packages. Single source of truth — every skill that runs `pnpm add` / `npm install` / `yarn add` / `bun add` MUST link here from its body.

### The rule

**When adding a NEW package, always resolve to the latest registry version. Never invent a version number from training-data memory.**

LLM training data is months stale. A model that remembers `vue@3.4.21` will silently introduce a 9-month-old version when `vue@3.5.x` is current. This is one of the highest-frequency drift sources in agent-authored code.

### Three states, one rule each

#### 1. Net-new dependency, no user-specified version

Run the install command **without a version pin**. The package manager resolves to the registry's `latest` tag and writes the appropriate caret-range to `package.json`.

```bash
# pnpm (preferred — fast, strict, deterministic lockfile)
pnpm add <package>                  # runtime dep
pnpm add -D <package>               # dev dep
pnpm add -E <package>               # exact version, no caret (use for tooling that demands lockstep)

# npm
npm install <package>               # runtime
npm install --save-dev <package>    # dev
npm install --save-exact <package>  # exact

# yarn / bun
yarn add <package>          /  bun add <package>
yarn add -D <package>       /  bun add -d <package>
```

**Do NOT write `pnpm add <package>@latest`** — it's redundant (bare add already resolves `latest`) and the literal `@latest` confuses some monorepo tooling.

#### 2. User explicitly specified a version

```
user: "install vue-router@4.4.5"
```

Use exactly what they said: `pnpm add vue-router@4.4.5`. Do not "upgrade" silently. The user's intent is authoritative.

#### 3. Compatibility-pinned dependency (peer constraint, framework lockstep, etc.)

When the package MUST match a peer constraint (e.g., a Vite plugin must match the project's Vite major), resolve via:

```bash
# Inspect what the project actually uses, then pin to that major
PEER_VERSION=$(node -p "require('./package.json').dependencies['vite']")
pnpm add @vitejs/plugin-vue@^${PEER_VERSION}
```

Document the constraint in the commit message: `chore: add @vitejs/plugin-vue@^7.x.y (peer of vite@^7.x)`. Do not pin to the latest if it breaks peer compatibility.

### Verification step (mandatory before commit)

After `pnpm add` / `npm install`, verify the resolved version against the registry to confirm the install actually got the latest:

```bash
# Single-source check (works for npm + pnpm + yarn + bun)
PKG=<package>
LATEST=$(npm view "$PKG" version)                    # registry truth
INSTALLED=$(node -p "require('./package.json').dependencies['$PKG'] || require('./package.json').devDependencies['$PKG']" 2>/dev/null | tr -d '^~')
echo "registry: $LATEST  /  installed: $INSTALLED"

# If they differ by major or minor, abort and investigate.
# If they differ by patch only, that's acceptable (caret range, lockfile may stay).
```

If the install resolved to an older version, the package likely has a peer constraint that the registry-latest violates — case 3 above. Surface this in the dispatch summary so the user can review.

### Anti-patterns (block on review)

- `pnpm add foo@1.2.3` where `1.2.3` was invented from memory rather than checked.
- `pnpm add foo@^1.0.0` to "be safe" — the package manager already writes a caret; explicit caret-zero pins lock in oldest-1.x.
- Editing `package.json` directly to add a version string without running the install. The lockfile and `node_modules` will be out of sync.
- Copying a `package.json` snippet from a stale tutorial / Stack Overflow answer / blog post. Always rerun the install command instead.
- Adding `"foo": "*"` or `"foo": "latest"` as the version range — `*` and literal `latest` in a manifest cause non-reproducible builds. Use the caret range that `pnpm add` writes by default.

### Tooling integrations

- **`/blitz:dep-health`** — periodic audit (CVE + outdated). Runs `npm outdated` / `pnpm outdated` against the registry; flags any dep behind by ≥1 minor.
- **`/blitz:migrate <package>`** — when intentionally upgrading. Researches breaking changes, applies migration in atomic steps, verifies after each.
- **PreToolUse hook (future)** — `block-stale-package-add.sh` could intercept Bash commands of the form `pnpm add foo@<version>` and reject the call if `<version>` is more than 1 major behind the registry latest. Not yet implemented; planned for v1.12.

### Source-of-truth file

This document. If your skill says "always use latest version," it must link here for the operational details. Don't duplicate the rule — it will drift.
