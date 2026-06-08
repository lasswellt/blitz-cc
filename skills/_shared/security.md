# Security & Trust Model

Consolidated blitz protocol. **Absorbs** (2026-06-06 `_shared` consolidation) 3 former files; each appears below as a top-level section with original sub-headings preserved as anchor targets. Inbound `oldfile.md#anchor` links were mechanically rewritten to `security.md#anchor`.

| Former file | Section |
|---|---|
| `threat-model.md` | [Threat Model — Blitz Containment Posture (canonical owner)](#threat-model--blitz-containment-posture-canonical-owner) |
| `hook-trust.md` | [Hook Trust Boundary (TB-1)](#hook-trust-boundary-tb-1) |
| `package-install-policy.md` | [Package Install Policy](#package-install-policy) |


---

<!-- ===== Absorbed from threat-model.md ===== -->

## Threat Model — Blitz Containment Posture (canonical owner)

> **Canonical owner (O-style)** for Blitz's security posture. Promoted from the containment research pass — see [`docs/security/containment/`](../../docs/security/containment/) for the surviving derivation artifacts: the surface map ([`blitz-surface-map.md`](../../docs/security/containment/blitz-surface-map.md), the risk × layer matrix) and the sequenced integration plan ([`SYNTHESIS.md`](../../docs/security/containment/SYNTHESIS.md), which folds the gap analysis and self-audit into blast-radius-ordered epics).
>
> Grounded in Anthropic, "How we contain Claude across products" (2026-05-25), cross-checked against OWASP (LLM / Agentic / MCP Top 10), CaMeL (arXiv 2503.18813), the dual-LLM / Spotlighting pattern, the memory-poisoning literature (MINJA / MemoryGraft / Zombie Agents), and NIST's agent identity/authorization direction.
>
> Right-sized for a Claude Code-class HITL developer tool — **not** a hosted service or sealed-VM product (§6 Scope).

This document organizes Blitz's scattered tactical guards (`block-*.sh`, `pre-edit-guard.sh`, orchestrator `[0:200]` caps) into one auditable posture: **risk type × defense layer**, ordered by the **environment-first principle**, defended along **four trust boundaries**. New security guards register against it; `/blitz:audit --pillar security` audits against it.

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

### 2. The environment-first principle (the ordering rule)

> "The deterministic boundary is what gets hit when everything probabilistic misses." — source article

**Rule:** Blitz's deterministic guards are the boundary. Model-layer behavior (skill prose, critic reasoning, gates) is defense-in-depth on top of that boundary — never the boundary itself.

**Why (reasoning chain — do not terse-compress):** Blitz now runs on a highly aligned model (Opus 4.8 honesty gains), making "the model will notice" tempting. The article's two most instructive incidents — an employee phished into running a malicious prompt, and exfiltration through an approved domain — were both egress events where the model layer had *nothing anomalous to catch*, because the instruction came from the legitimate user or through a permitted channel. Only the environment boundary held. OWASP states the same in general form: prompt injection has "no known complete mitigation — only layered defenses." Therefore:

- A new control is **valid containment** only if it has a deterministic component (a hook, schema check, tool grant, cap, hash). "The agent is instructed to be careful" is not containment.
- Persistent-state validation (TB-2) and fetched-content inspection (TB-4) are **deterministic scan + small-fast classifier** steps (Haiku per [agent-orchestration.md](agent-orchestration.md)), not "the reasoning model will spot the injection." Per the article, the classifier "can be a small, fast model; it doesn't need to be the one doing the reasoning."

---

### 3. The four trust boundaries

Everything below is **untrusted-by-default**.

#### TB-1 — Project-local state is untrusted inbound data
Files a cloned/opened repo controls: `.cc-sessions/*.json`, `activity-feed.jsonl`, developer/model profiles, **CLAUDE.md**, the carry-forward registry. Treat them like an inbound internet request, not trusted local config.
- **Enforced by:** `session-start.sh` caps + scans before echo (Gap 5); `session-lifecycle.md` startup validates before load (Gap 1); `pre-edit-guard.sh` blocks edits to secret/key/lock files.
- **Guards against:** pre-trust parse, persistent poisoning.

#### TB-2 — Persistent `.cc-sessions/` state is untrusted across sessions
The same directory across time: an injection in the carry-forward registry or feed is **reloaded every session** and, for carry-forward, **auto-injected into the next sprint** (`sprint-plan` consumes it as mandatory input — high blast radius because it *drives work*). Memory-poisoning attacks are **temporally decoupled** — poison planted now can trigger sprints later (MemoryGraft / Zombie Agents).
- **Enforced by:** session-startup validation (Gap 1) — schema-conform + injection scan + `provenance` tag `{source, write_session, first_seen_sprint}`; quarantine, don't silently load; re-verify carry-forward entries older than 2 sprints ([research-critic.md](../../agents/research-critic.md) §2.7 cadence, extended). Generalizes the existing `rollover_count >= 3` escalation.
- **Guards against:** persistent poisoning, belief drift.

#### TB-3 — Sub-agent output is not higher-trust than the content it processed
A sub-agent that fetched a URL or read an untrusted file is a *conduit*. Its reply is not trusted because it "came from us." Blitz's architecture is structurally the **dual-LLM / information-flow-control** pattern: the orchestrator is the privileged planner (it *cannot* call `Agent()` — [agent-orchestration.md](agent-orchestration.md) §5) and sub-agents are quarantined readers returning **structured JSON only** (spawn-protocol §9) = a schema-validated channel carrying structured extractions, not raw untrusted content.
- **Enforced by:** spawn-protocol trust clause (Gap 2). Sub-agent output keeps the structured-JSON contract **and** any field interpolated into a downstream prompt/command is `[0:200]`-capped + injection-scanned like raw tool output. Agents processing untrusted input tag replies `source_trust: "untrusted"` (a CaMeL-style source-of-data capability label).
- **Guards against:** multi-agent trust escalation.

#### TB-4 — Fetched external content is untrusted before it enters reasoning context
WebFetch pages, MCP tool returns **and tool descriptions**, fetched READMEs/docs — "an audited connector isn't the same as audited data." MCP tool poisoning hides instructions in tool metadata "the model reads; the user does not."
- **Enforced by:** content-inspection (Gap 3) — Haiku-class classifier + deterministic regex flag embedded instructions, tool-invocation strings, credential-shaped patterns, suspicious URLs *before* content reaches the reasoning model; untrusted spans wrapped with a **Spotlighting / data-marking** delimiter. MCP tool descriptions inspected at ToolSearch-load; description hash on first approval detects rug-pulls.
- **Guards against:** tool output as attack surface, indirect injection.

---

### 4. Risk × layer mapping (summary)

|                       | Environment (primary) | Model (defense-in-depth) | External content |
|-----------------------|------------------------|---------------------------|-------------------|
| **User misuse**       | block-* hooks, pre-edit-guard, platform hard-deny | SAFETY-RULES prose, autonomy levels | n/a |
| **Model misbehavior** | test/typecheck/as-any guards, ratchet revert, `disallowed-tools` | critic 20-detector, reviewers | n/a |
| **External attacker** | orchestrator `[0:200]`, startup-validate, sub-agent cap | injection-resistance (inherited) | content inspection; research-critic liveness |

---

### 5. Canonical-owner declaration + registration contract

This file is the canonical owner of Blitz's security posture. Bidirectional citations:
- `hooks/scripts/block-*.sh` + `pre-edit-guard.sh` + `session-start.sh` headers → cite this doc (environment-layer enforcement points).
- [agent-orchestration.md](agent-orchestration.md) §8/§9 (TB-3), [session-lifecycle.md](session-lifecycle.md) startup (TB-1/TB-2), [orchestrator.md](../../agents/orchestrator.md) §4 (TB-3/TB-4), [research-critic.md](../../agents/research-critic.md) (TB-4) cite this doc.

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

### 7. Related protocols
- [session-lifecycle.md](session-lifecycle.md) — startup state read (TB-1/TB-2 enforcement point).
- [agent-orchestration.md](agent-orchestration.md) — sub-agent reply contract (TB-3).
- [hook-trust.md](#hook-trust-boundary-tb-1) — pre-trust parsing boundary (TB-1).
- [agent-orchestration.md](agent-orchestration.md) — Haiku-class classifier routing (TB-2/TB-4).
- [check-registry.json](check-registry.json) — `security` pillar checks.
- Derivation + research: [docs/security/containment/](../../docs/security/containment/) — surviving artifacts are [`blitz-surface-map.md`](../../docs/security/containment/blitz-surface-map.md) (risk × layer surface map) and [`SYNTHESIS.md`](../../docs/security/containment/SYNTHESIS.md) (sequenced integration plan).



---

<!-- ===== Absorbed from hook-trust.md ===== -->

## Hook Trust Boundary (TB-1)

> Companion to [threat-model.md](#threat-model--blitz-containment-posture-canonical-owner). Defines how Blitz hooks must treat project-local files, and records the audited invariant that no hook executes project-controlled content before the platform trust prompt.

### The rule

Blitz hooks fire on Claude Code lifecycle events (`SessionStart`, `PreToolUse`, `PostToolUse`, …). Some run **before** the user has accepted "Do you trust this folder?". The article's pre-trust-config-execution incident (AP-1) was a cloned repo whose `.claude/settings.json` defined a hook that ran attacker code at startup, before that prompt.

**Therefore:**
1. **Treat project-local files as untrusted inbound data**, not trusted local config — `.cc-sessions/*.json`, `activity-feed.jsonl`, profiles, CLAUDE.md, carry-forward registry. This is [threat-model.md](#threat-model--blitz-containment-posture-canonical-owner) §3 TB-1.
2. **A hook MUST NOT `eval`, `source`, or otherwise execute** any project-controlled file's contents. Hooks may *parse* (jq) and *echo*, never execute.
3. **Echoed free-text fields MUST be capped + injection-scanned** before reaching context. `session-start.sh` caps every echoed field at 200 chars (parity with `orchestrator.md:146`) and replaces injection-marker hits with `[quarantined: …]`.
4. **Execution-bearing parsing defers to the platform trust prompt.** Blitz relies on the Claude Code platform for the trust gate itself — it does not reimplement it (threat-model.md §6). Blitz's duty is to not parse-execute project config before it.

### Audited invariant (keep true)

> **No Blitz hook executes project-controlled content pre-trust.**

Verified 2026-05-31 across all `hooks/scripts/*.sh`:
- The `block-*.sh` + `pre-edit-guard.sh` hooks read `tool_input` (the agent's *own* proposed action from the harness), not committed project files.
- `session-start.sh` parses `.cc-sessions/` JSON with `jq` and echoes sanitized text — no `eval`/`source` of project content.
- `startup-validate.sh` reads + scans; it does not execute entries.

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
