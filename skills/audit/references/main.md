# Codebase Audit — Reference Material

This file provides templates, checklists, and schemas used by the audit skill.

---

## Agent Prompt Template

<!-- import: /_shared/agents.md -->
See [/_shared/agents.md](/_shared/agents.md) for canonical boilerplate (BUDGET, WRITE-AS-YOU-GO, HEARTBEAT, PARTIAL, CONFIRMATION) shared across fan-out skills. The audit-specific template below remains the byte-stable spawn source — Invariant 5 (OUTPUT STYLE snippet) requires inline preservation. The shared fragment is the canonical reference + extraction target for future runtime splicing.

Use this template for every audit agent. Replace `{PLACEHOLDERS}` with agent-specific values.

```markdown
You are a senior code auditor specializing in **{PILLAR}** ({PILLAR_SUBTITLE}).

## Your Assignment

**Scope**: {SCOPE}
**File Cap**: Examine up to {FILE_CAP} files.
**Output File**: {OUTPUT_PATH}

## Stack Context

{STACK_PROFILE}

## Entry Points to Start From

{ENTRY_POINTS}

## Audit Checklist

{PILLAR_CHECKLIST}

## Output Format

Write each finding using this exact format:

### FINDING: <short-title>

- **Severity**: Critical | High | Medium | Low
- **File**: <relative-path>
- **Line(s)**: <line-range or "N/A">
- **Pillar**: {PILLAR}
- **Category**: <checklist-category>
- **Description**: <2-4 sentences explaining the issue>
- **Evidence**: <code snippet or observation>
- **Recommendation**: <specific actionable fix>
- **Effort**: Trivial | Small | Medium | Large

---

## Rules

1. Write each finding to your output file AS YOU DISCOVER IT. Do not accumulate.
2. **Falsify before recording.** Before writing any finding, construct an artifact (Bash command, file Read) that would refute the claim. Include the artifact + its output in the Evidence field.
   - **Count-based** ("N hits of X"): `grep -n 'pattern' <file> | head -3`. If sampled hits are inside paths/filenames rather than prose content, the claim is misleading — refine or discard.
   - **Negative** ("X is absent from Y"): `grep -in '<4-char-substring-of-X>' Y`. Any hit means re-evaluate (may be over-strict regex).
   - **Pattern-duplication** ("X duplicated across N files"): require N ≥ 35% of in-scope files AND Read 2 alleged duplicates. Verify structurally identical, not merely sharing a keyword.
   - This is artifact construction, NOT self-judgment. The shell decides — your role is to design the falsification test. Per `docs/research/2026-05-16_audit-agent-fp-prevention.md`.
3. **Score confidence 0-100 on every finding.** Add `Confidence: <0-100>` line to Evidence. Rubric: 0=false-positive, 25=might-be-real, 50=real-but-minor, 75=real-and-important, 100=definitely-real. Mirrors Anthropic's Code Review Plugin. Orchestrator filters below 80 (tunable via `BLITZ_AUDIT_CONFIDENCE_THRESHOLD`).
   - Confidence < 50 after falsification: do NOT record as finding; log one line to `## Discarded Drafts` at the file bottom: `- <claim> (Confidence N, refuted by <artifact>)`.
   - "No violations found" results: write to a separate `## Verified Clean` section, NOT the findings list. Findings are actionable; clean checks document what was inspected.
   - Count discipline: "N files match X" requires `grep -l X <files> | wc -l` (file count), NOT `grep -rn X | wc -l` (hit count). When they differ, name what you mean ("30 hits across 29 files"). Sample 2-3 alleged matches with Read before recording the count.
4. Stay within your file cap. Prioritize the most impactful files.
5. Read files fully before judging — do not flag issues based on file names alone.
6. Be specific: cite exact file paths, line numbers, and code snippets.
7. Do not report style-only issues unless they indicate a deeper problem.
8. If you find a security vulnerability, always mark it Critical or High.
9. Cross-reference related files (e.g., a component and its store) to find integration issues.
10. At the end of your findings, write a brief summary section:

### SUMMARY

- **Files Examined**: <count>
- **Findings**: <count> (Critical: N, High: N, Medium: N, Low: N)
- **Top Concern**: <one-sentence summary of the most important finding>
- **Overall Assessment**: <one-sentence pillar health assessment>

fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code,
URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows,
error codes, dates, version numbers. No preamble. No trailing summary of work
already evident in the diff or tool output. Format: fragments OK.
```

---

## 5-Pillar Audit Checklists

### Pillar 1: Architecture

#### Frontend Scope (arch-frontend)
- [ ] **Component hierarchy**: Are components organized by feature/domain or flat? Is there a clear hierarchy (pages > layouts > composites > atoms)?
- [ ] **Prop drilling**: Are props passed through more than 2 levels? Should state management or provide/inject be used instead?
- [ ] **Store design**: Are stores organized by domain? Do stores have single responsibilities? Are cross-store dependencies managed?
- [ ] **Composable patterns**: Are composables pure (no side effects in setup)? Do they follow the `use*` naming convention?
- [ ] **Router structure**: Are routes organized logically? Are guards/middleware applied consistently? Are lazy-loaded appropriately?
- [ ] **Circular dependencies**: Are there circular imports between modules?
- [ ] **Barrel exports**: Are index files used consistently? Do they cause tree-shaking issues?
- [ ] **Layout consistency**: Is there a single layout system or competing approaches?
- [ ] **API boundary**: Is there a clear boundary between UI and data layers?
- [ ] **Feature coupling**: Do features import from each other directly, or through shared modules?

#### Backend Scope (arch-backend)
- [ ] **Function organization**: Are cloud functions grouped by domain? Is there a consistent naming scheme?
- [ ] **Schema placement**: Are data schemas co-located with their consumers or centralized?
- [ ] **Package boundaries**: Are internal packages properly encapsulated with clear public APIs?
- [ ] **Dependency direction**: Do dependencies flow inward (domain < application < infrastructure)?
- [ ] **Shared code**: Is code shared between frontend and backend properly isolated in shared packages?
- [ ] **Configuration management**: Are configs externalized? Are there hardcoded values that should be environment variables?
- [ ] **API versioning**: Is there a strategy for API versioning or backward compatibility?
- [ ] **Database access patterns**: Is data access centralized through repositories/services or scattered?
- [ ] **Middleware chain**: Is middleware applied consistently? Are cross-cutting concerns (auth, logging, validation) separated?
- [ ] **Module coupling**: Can modules be deployed/tested independently?

### Pillar 2: Performance

#### Frontend Scope (perf-frontend)
- [ ] **Re-renders**: Are reactive references stable? Are computed properties used where applicable instead of methods?
- [ ] **Memory leaks**: Are event listeners, intervals, and subscriptions cleaned up in `onUnmounted`?
- [ ] **Bundle size**: Are there large libraries imported where a smaller alternative exists? Is tree-shaking effective?
- [ ] **Lazy loading**: Are below-the-fold components and routes lazy-loaded?
- [ ] **Image optimization**: Are images properly sized, formatted (WebP/AVIF), and lazy-loaded?
- [ ] **Virtual scrolling**: Are large lists (100+ items) virtualized?
- [ ] **Watchers**: Are deep watchers used unnecessarily? Could they be shallow or use specific property paths?
- [ ] **Render cost**: Are expensive template expressions computed once rather than re-evaluated per render?
- [ ] **Asset caching**: Are static assets cache-busted properly?
- [ ] **Critical rendering path**: Is above-the-fold content prioritized?

#### Backend Scope (perf-backend)
- [ ] **Cold starts**: Are cloud function dependencies minimized? Is there unnecessary initialization?
- [ ] **Database queries**: Are queries indexed? Are there N+1 query patterns? Are batch reads used?
- [ ] **Batch operations**: Are multiple writes batched into transactions or batch commits?
- [ ] **Caching strategy**: Is there appropriate use of caching for frequently-read, rarely-changing data?
- [ ] **Payload size**: Are API responses trimmed to necessary fields? Are large responses paginated?
- [ ] **Connection pooling**: Are database connections reused across invocations?
- [ ] **Async patterns**: Are I/O operations parallelized where possible (`Promise.all` vs sequential `await`)?
- [ ] **Memory usage**: Are large objects cleaned up? Are streams used for large data processing?
- [ ] **Timeouts**: Are external calls configured with appropriate timeouts?
- [ ] **Rate limiting**: Are expensive operations rate-limited?

### Pillar 3: Security

#### Rules Scope (sec-rules)
- [ ] **Database rules**: Do rules enforce authentication? Are there overly permissive rules (`allow read, write: if true`)?
- [ ] **Field-level access**: Are sensitive fields (email, role, balance) protected at the rule level?
- [ ] **Admin escalation**: Can a user modify their own role or permissions?
- [ ] **Data validation in rules**: Are write operations validated for schema correctness at the rule level?
- [ ] **Storage rules**: Are file uploads restricted by type, size, and path?
- [ ] **Rate limiting at rules level**: Are there protections against mass data reads/writes?
- [ ] **Cross-tenant access**: In multi-tenant systems, can users access other tenants' data?
- [ ] **Rule complexity**: Are rules maintainable? Are custom functions used to reduce duplication?

#### Code Scope (sec-code)
- [ ] **XSS prevention**: Is user input sanitized before rendering? Are `v-html` or `innerHTML` used with unsanitized data?
- [ ] **Auth middleware**: Are all protected routes guarded? Is the auth state checked server-side, not just client-side?
- [ ] **Input validation**: Is all user input validated on the server side? Are validation schemas used?
- [ ] **Secret management**: Are API keys, tokens, or credentials hardcoded? Are they in source control?
- [ ] **CORS configuration**: Is CORS properly restrictive? Are wildcard origins used in production?
- [ ] **Content Security Policy**: Is CSP configured? Does it allow unsafe-inline or unsafe-eval?
- [ ] **Dependency vulnerabilities**: Are there known vulnerabilities in dependencies?
- [ ] **Injection attacks**: Are database queries parameterized? Are dynamic paths sanitized?
- [ ] **Authentication flows**: Are tokens stored securely? Are refresh mechanisms implemented correctly?
- [ ] **Error information leakage**: Do error responses expose stack traces, internal paths, or sensitive data?

#### Containment Scope (sec-containment) — applies to agent/plugin codebases (blitz-self-audit)
Per [/_shared/security.md](/_shared/security.md). Frame `allowed-tools` as **capability grants, not toggles** (AP-3 / `sec-capability-grant`):
- [ ] **Capability grants**: Does any agent/skill `allowed-tools` grant a capability broader than its role? `Bash` on a read-only agent = exec+egress; `WebFetch` on a non-network agent = egress; `Write/Edit` on a read-only audit skill = mutation. Each over-grant needs a `# capability rationale:` comment, a `disallowed-tools` declaration, or a documented `<!-- no-disallowed-tools: -->` exclusion — else flag.
- [ ] **Persistent-state validation (TB-2)**: Does startup load `.cc-sessions/`, `docs/plans/*/tasks.json`, `docs/solutions/`, or CLAUDE.md without `startup-validate.sh` (schema + injection scan + provenance)? (`sec-startup-schema`/`sec-startup-injection`)
- [ ] **Sub-agent trust (TB-3)**: Do agents that ingest external content tag `source_trust: "untrusted"`, and does the main thread cap+scan interpolated reply fields? (`agents.md` §3)
- [ ] **Fetched-content inspection (TB-4)**: Do WebFetch/MCP returns + MCP tool descriptions pass content inspection before reasoning? Rug-pull hash on tool descriptions? (`sec-content-inspection`)
- [ ] **Pre-trust parsing (AP-1)**: Does any `SessionStart` hook echo project-local fields uncapped, or `eval`/`source` a project-controlled file? ([/_shared/security.md](/_shared/security.md))

### Pillar 4: Maintainability

#### Frontend Scope (maint-frontend)
- [ ] **Naming conventions**: Are files, components, and variables named consistently?
- [ ] **Component complexity**: Are there components over 300 lines? Should they be split?
- [ ] **Code duplication**: Are there copy-pasted blocks that should be extracted into composables or utilities?
- [ ] **Dead code**: Are there unused components, imports, or variables?
- [ ] **TypeScript usage**: Is TypeScript used effectively? Are there excessive `any` types or type assertions?
- [ ] **Comment quality**: Are comments explaining "why" not "what"? Are there outdated comments?
- [ ] **Consistent patterns**: Is the same problem solved differently in different places?
- [ ] **Test coverage**: Are critical paths tested? Are there untestable components (too coupled)?
- [ ] **Magic numbers/strings**: Are there hardcoded values that should be constants?
- [ ] **Import organization**: Are imports grouped consistently (external, internal, types)?
- [ ] **File length**: Are files reasonable length? Are there god-files that do too much?
- [ ] **Cyclomatic complexity**: Are there deeply nested conditionals that should be refactored?

#### Backend Scope (maint-backend)
- [ ] **Type safety**: Are function signatures properly typed? Are return types explicit?
- [ ] **Error types**: Are custom error types used consistently? Or are generic errors thrown everywhere?
- [ ] **Code reuse**: Are there utility functions that could be shared? Is there duplicate business logic?
- [ ] **Consistency**: Are similar operations handled the same way across the codebase?
- [ ] **Configuration types**: Are config objects typed and validated at startup?
- [ ] **API contracts**: Are request/response types shared between client and server?
- [ ] **Migration patterns**: Is there a clear pattern for schema/data migrations?
- [ ] **Documentation**: Are complex business rules documented in code?
- [ ] **Dependency management**: Are dependencies up to date? Are there conflicting versions?
- [ ] **Build configuration**: Are build scripts maintainable? Are there unnecessary complexity in the build pipeline?

### Pillar 5: Robustness

#### Frontend Scope (robust-frontend)
- [ ] **Error boundaries**: Are there error boundaries to prevent full-page crashes?
- [ ] **User feedback**: Do all async operations show loading states? Are errors communicated to users?
- [ ] **Edge cases**: Are empty states handled? What about null/undefined data from API?
- [ ] **Offline behavior**: What happens when the network is unavailable? Are there appropriate fallbacks?
- [ ] **Form validation**: Are forms validated before submission? Are validation errors displayed clearly?
- [ ] **Navigation guards**: Are unsaved changes protected when navigating away?
- [ ] **Concurrent operations**: What happens if a user clicks a submit button twice?
- [ ] **Data freshness**: Is stale data detected and refreshed? Are real-time subscriptions resilient to disconnection?
- [ ] **Graceful degradation**: Do features degrade gracefully when optional services are unavailable?
- [ ] **Accessibility under failure**: Are error states accessible (screen reader announcements, focus management)?

#### Backend Scope (robust-backend)
- [ ] **Error handling**: Are all thrown errors caught and handled? Are unhandled promise rejections caught?
- [ ] **Transaction safety**: Are multi-step writes wrapped in transactions? What happens on partial failure?
- [ ] **Logging**: Is there structured logging? Are errors logged with sufficient context?
- [ ] **Retry logic**: Are transient failures retried with backoff? Are retries idempotent?
- [ ] **Input boundaries**: Are maximum sizes enforced (payload size, array lengths, string lengths)?
- [ ] **Timeout handling**: Do external calls have timeouts? What happens when a timeout occurs?
- [ ] **Circuit breaking**: Are there protections against cascading failures from downstream services?
- [ ] **Data integrity**: Are there mechanisms to detect and recover from data corruption?
- [ ] **Idempotency**: Are write operations idempotent? Can a retry cause duplicate records?
- [ ] **Monitoring hooks**: Are health checks and metrics exposed for operational monitoring?

---

## Finding Severity Schema

### Critical
**Definition**: Immediate risk of security breach, data loss, or production outage.
**Examples**: Unauthenticated admin endpoints, SQL injection, unprotected PII, missing transaction rollback on financial operations.
**Action**: Must fix before next release.
**Score weight**: 10

### High
**Definition**: Significant quality issue that will cause user-facing problems or major technical debt.
**Examples**: N+1 queries on paginated lists, missing error boundaries on critical flows, permissive CORS in production, components over 500 lines.
**Action**: Fix in the audit plan's first tasks (`T-001…`).
**Score weight**: 5

### Medium
**Definition**: Code quality concern that increases maintenance burden or degrades experience over time.
**Examples**: Inconsistent naming, moderate code duplication, missing loading states on secondary views, untyped function parameters.
**Action**: Address as a lower-priority task in the audit plan, or a note in `spec.md`.
**Score weight**: 2

### Low
**Definition**: Improvement suggestion that would enhance code quality but has minimal user or security impact.
**Examples**: Suboptimal import ordering, missing JSDoc on internal utilities, slightly verbose code that could be more concise.
**Action**: Address opportunistically or during related work.
**Score weight**: 1

---

## Health Score Calculation

Per-pillar health score (0-100):

```
raw_penalty = sum(critical * 10 + high * 5 + medium * 2 + low * 1)
file_count = number of files examined by the pillar's agents
normalized_penalty = raw_penalty / max(file_count, 1)
health_score = max(0, 100 - (normalized_penalty * 5))
```

Overall health score = average of all 5 pillar scores.

Interpretation:
- **90-100**: Excellent — minor improvements only
- **70-89**: Good — some areas need attention
- **50-69**: Fair — significant issues to address
- **30-49**: Poor — major remediation needed
- **0-29**: Critical — fundamental problems present

---

## Report Template

```markdown
# Codebase Audit Report

**Date**: YYYY-MM-DD
**Stack**: <framework> + <ui-framework> + <backend> + <build-system>
**Project Root**: <path>
**Files Analyzed**: <total-count>
**Agents Succeeded**: N/10
**Duration**: <elapsed-time>

---

## Executive Summary

<2-3 sentences summarizing overall codebase health, the most critical concerns, and top-level recommendation.>

**Overall Health Score: XX/100**

---

## Health Scorecard

| Pillar | Score | Critical | High | Medium | Low | Agent Status |
|--------|-------|----------|------|--------|-----|-------------|
| Architecture | XX/100 | N | N | N | N | OK/FAILED |
| Performance | XX/100 | N | N | N | N | OK/FAILED |
| Security | XX/100 | N | N | N | N | OK/FAILED |
| Maintainability | XX/100 | N | N | N | N | OK/FAILED |
| Robustness | XX/100 | N | N | N | N | OK/FAILED |

---

## Critical Findings

> These require immediate attention.

<list all Critical-severity findings with full details>

---

## Findings by Pillar

### Architecture (Score: XX/100)

#### High Severity
<findings>

#### Medium Severity
<findings>

#### Low Severity
<findings>

### Performance (Score: XX/100)
...

### Security (Score: XX/100)
...

### Maintainability (Score: XX/100)
...

### Robustness (Score: XX/100)
...

---

## Hotspot Files

Files with the most findings across all pillars:

| Rank | File | Findings | Critical | High | Medium | Low |
|------|------|----------|----------|------|--------|-----|
| 1 | <path> | N | N | N | N | N |
| ... | | | | | | |

---

## Comparison with Previous Audit

> Section included only when a previous audit report exists.

| Metric | Previous | Current | Delta |
|--------|----------|---------|-------|
| Overall Score | XX | XX | +/-N |
| Critical Findings | N | N | +/-N |
| ... | | | |

### Resolved Issues
<list of findings from previous audit that are no longer present>

### New Issues
<list of findings not present in previous audit>

### Regressions
<list of findings that worsened in severity>

---

## Recommended Actions

Prioritized list of remediation actions:

1. **[CRITICAL]** <action> — Addresses findings: <finding-ids>
2. **[HIGH]** <action> — Addresses findings: <finding-ids>
3. ...

---

## Plan

`docs/plans/audit-YYYY-MM-DD/` — spec.md (paused), tasks.json (N tasks), M findings kept as notes.
```

---

## Task Emission (Phase 3)

Each theme becomes one `tasks.sh add` call; the schema is `blitz-tasks/1.0` ([/_shared/loop.md](/_shared/loop.md) §Schemas). Fields the audit fills:

| Field | Source |
|---|---|
| `id` | `T-00N` in impact order (Critical 10, High 5, Medium 2, Low 1, summed per theme) |
| `title` | `<Pillar>: <theme>` |
| `role` | from `files` (backend / frontend / infra / test) |
| `files` | union of cited paths, ≤12 |
| `verify[]` | registry `detection.command` for deterministic findings; `! grep -rnE '<pattern>' <files>` (`grep_absent`) or `grep -qE` for semantic ones; `::60` timeout (`::300` for tsc / import-graph) |
| `origin` | `audit` |
| `notes` | registry ids that fired, agreement (`sec-a/sec-b agreed`), severity, report section |

A finding with no executable check is a note under `spec.md` §Out of scope, never a task. Run each verify command once on the unfixed tree: it must fail now (otherwise it proves nothing).

`spec.md` frontmatter: `status: paused` (`active` with `--plan`), `priority: P2` (`next-state.sh` orders active plans P0 → P1 → P2; a bare integer is also accepted), `created`, `ship: manual`. Sections: Goal, Findings summary (table by task with `file:line`), Out of scope (notes + coverage boundary).

---

## Recall hardening — aggregation, FP-verify panel, deterministic lane, recall instrumentation

Detail for the SKILL.md §"Phase 1.D / 2.0 / 2.5 / 3.5" contract. Source specs: `docs/consolidation/review-audit/audit-spec.md`, `flaw-finding-proof.md`.

### Phase 1.D — deterministic lane

Load `/_shared/check-registry.json`, select `lane=="deterministic" && consolidated_target in {audit,both}`. Run each row's `detection.command` across the codebase (grep/tsc/import-graph). Zero-FP, no aggregation needed. Write findings to `${AUDIT_RUN}/findings/00-deterministic.md` tagged `lane: deterministic`. These complement the semantic pillars — the two lanes catch disjoint bug classes (a deleted-test/broken-build has no semantic signature; a wrong answer-key has no structural signature).

### Phase 1.D2 — design pillar (adapter-aware)

Triggered by `--pillar design` (or auto when a UI stack is detected). Extends Phase 1.D with the framework-adaptive design lane (specs: `docs/integrations/impeccable/`).

0. **Preflight (never silent green).** Run `scripts/design/preflight.sh <target-repo>`. Record the `DESIGN_LANE_STATUS` line. If `semantic != OK` (impeccable at the pin in neither the target project nor a global install), emit the `DESIGN_LANE_UNAVAILABLE` line into `00-design.md`'s `## Lane status` block and the audit summary, run only the deterministic regex rows, and mark the design pillar's semantic coverage as a `coverage_boundary` — do not report the pillar as clean. With `--strict`, treat `semantic=ABSENT` as a hard fail. impeccable is a **target-project** dep (`npm i -D impeccable@2.3.2`), never a plugin dep.
1. **Resolve the adapter.** Parse the `DESIGN_ADAPTER primary=… variant=… secondary=… incompat=… confidence=…` token line emitted by `scripts/detect-stack.sh` (machine line, not prose).
2. **Select + gate.** From the registry, take `pillar == design` rows. A row fires iff `adapter ∈ inclusion(primary) ∪ secondary` AND NOT (`reconciliation.relaxFor` includes `primary`), where `inclusion`: `none→{universal}`, `tailwind→{universal,tailwind}`, `tailwind-md3→{universal,tailwind,tailwind-md3}`, `vuetify→{universal,vuetify}`, `quasar→{universal,quasar}`. So Layer 0 (universal) always runs; Layer 1/2 gate to the stack; `bounce-easing`/`ghost-card` suppress where the stack prescribes spring/elevation. No cross-stack false positives.
3. **Run once, filter.** Vendored rows (`detection.type == command`) all share the **key-free** `npx impeccable detect --json <targets>` — run it **once**, then attribute each output hit (`{antipattern, file, line, snippet}`) to the design row whose `detection.filter == antipattern`. The provider-gated tells (impeccable `--gpt`/`--gemini`) are NOT requested here; they are judged in the `design-critic` semantic lane via the critic's gemini CLI (`BLITZ_GEMINI_BIN`). New L1/L2 rows (`detection.type == regex`) run their own command, then apply the registry `design.exclude` set (two-step scoped filter: drop files matching `files` OR containing a `contentGuard`; drop lines matching a `lineGuard`) so token-definition surfaces, comments, and SVG paint don't false-positive; FP-verify each survivor before reporting. The consolidated `design-raw-color-literal` picks its message from `perAdapter` by the detected adapter. Write to `${AUDIT_RUN}/findings/00-design.md` tagged `pillar: design`.
4. **Semantic aggregator.** For the design pillar, the semantic lane is **not** the 10 code-audit passes — it is `agents/design-critic.md` over rendered screenshots (5 dimensions; Creative Distinction scored against generic-within-the-stack's-idiom, per the adapter). Spawn it when screenshots are available (Playwright/dev-server); else note in `coverage_boundary`.
5. **Verdict authority.** Design rows are advisory (P3) except `design-low-contrast` (P2 → reject, a11y) and `design-quasar-tailwind-coexist` (P1 → reject, build conflict). `coverage_boundary` (§Phase 3.5) records which engines ran (static vs browser-render) + any adapter-gated rows skipped.

### Phase 2.0 — Multi-Review aggregation

The roster's 2 agents/pillar reason on the **same scope independently** (the legacy frontend/backend split gave no agreement signal). After Phase 2.1 parse:

```
for finding f in semantic_findings:
    agreers = count(distinct agent_id that independently flagged f, matched by (file, line-range, claim))
    f.base_confidence = 0.85 if agreers >= 2 else 0.50
```

Aggregating across independent runs of one model OR across models both work (SWRBench 2509.01494, +43.67% F1). `--dual` adds cross-model agreers for the security pillar.

### Phase 2.5 — adversarial FP-verify panel

Per surviving finding, spawn N perspective-diverse refuters (lenses: correctness / security / reproduces). Each re-reads the cited `file:line` and attempts to REFUTE the claim against actual behavior; default `refuted=true` if not reproducible.

```
fp_factor = (refuters that could NOT refute >= majority) ? 1.0 : 0.0
effective_confidence = base_confidence * fp_factor   # refuted (0.0) -> dropped
```

Survivors attach the reproducing excerpt. A semantic finding is `advisory` regardless of confidence (registry downgrade rule) — high confidence raises rank, never authority. This is the structural cure for the v1.16.0 inflated-count incident (counts reported as findings without sampled code). Parity: native `/code-review` validation agent, <1% FP.

### Phase 3.5 — recall instrumentation (`coverage_boundary`)

Required field in the report JSON:

```json
"coverage_boundary": {
  "agents_failed": ["<name>"],
  "checks_skipped": ["det-NN", "sem-*"],
  "files_over_cap_unread": 0,
  "lanes_not_run": []
}
```

A clean PASS with a large boundary is labeled "passed what we checked," never "passed everything." `--min-confidence low` is the audit default: report everything ranked by `effective_confidence`; drop only refuted findings (`fp_factor == 0`), never low-confidence ones (recall bias).

## Consolidated Report Template (Phase 2.6)

Write `${AUDIT_RUN}/reports/audit-report.md` using the report template from `references/main.md`:

```markdown
# Codebase Audit Report
**Date**: <ISO-8601>
**Stack**: <detected stack>
**Files Analyzed**: <count>
**Agents Succeeded**: <N>/10

## Executive Summary
<2-3 sentence overview with overall health score>

## Health Scorecard
| Pillar | Score | Critical | High | Medium | Low |
|--------|-------|----------|------|--------|-----|
| Architecture | XX/100 | N | N | N | N |
| Performance | XX/100 | N | N | N | N |
| Security | XX/100 | N | N | N | N |
| Maintainability | XX/100 | N | N | N | N |
| Robustness | XX/100 | N | N | N | N |

## Critical Findings
<list all Critical severity findings>

## Findings by Pillar
### Architecture
<findings sorted by severity>

### Performance
...

### Security
...

### Maintainability
...

### Robustness
...

## Hotspot Files
<top 10 files with most findings>

## Recommended Actions
<prioritized list of what to fix first>
```

## Plan Emission (Phase 3)

No JSON index. The machine-readable output is `docs/plans/audit-<date>/tasks.json`, written only by `scripts/tasks.sh` (see §Task Emission above); `next-state.sh` reads it once `spec.md` says `status: active`. Rerun on the same day appends tasks for new themes (title match skips duplicates) and never rewrites the `spec.md` frontmatter.

---

## Moved from SKILL.md (body size)

Detail moved out of the skill body so it stays under the compaction re-attach cap (the platform keeps only the first 5,000 tokens of a re-attached skill). Behaviour is unchanged; the body links each block at its original position.

### 1.1 Spawn 10 Pillar Agents via Agent Tool (default path)

Spawn all 10 agents using the `Agent` tool, all in **a single assistant message** so they execute concurrently.

Per-spawn parameters:
- `subagent_type: general-purpose` (agents must Write findings files; `Explore` is read-only and silently fails)
- `model: sonnet` (explicit — prevents `[1m]` inheritance from an Opus main thread)
- `description: audit <agent-name>`
- `prompt`: the pillar prompt template from `references/main.md`, filled per the roster below
- `run_in_background: true`

Cross-pillar findings synthesized on the main thread in Phase 2 from output files (not peer-to-peer, per [agents.md](/_shared/agents.md)).

**Weight class**: Medium (per [agents.md](/_shared/agents.md)). File caps per pillar are specified in the roster below. Each agent prompt must also include: max 250-line output per pillar, 5-minute wall-clock budget, mandatory write-as-you-go (step 8 of prompt construction below).

Every agent receives:
1. The inventory JSON (inline, not a file path).
2. The stack profile from Phase 0.
3. Its specific pillar, scope, and file cap.
4. Its output file path under `${AUDIT_RUN}/findings/`.
5. The pillar-specific checklist from `references/main.md`.
6. Instructions to write findings incrementally (not all at the end).

**Agent Roster:**

**2 independent same-scope passes per pillar** — both agents in a pillar audit the *full* pillar surface independently (not a frontend/backend split). Their overlap is the agreement signal Phase 2.0 aggregates: a finding both passes flag is high-confidence; one-pass findings are low-confidence. (Distinct breadth is recovered by aggregation across the two passes + the deterministic lane, §1.5.)

| # | Agent Name | Pillar | Scope (full pillar — independent pass) | File Cap | Output File |
|---|-----------|--------|-------|----------|-------------|
| 1 | `arch-a` | Architecture | Components/stores/composables/router/layouts + functions/schemas/API/DB models | 14 | `findings/01-arch-a.md` |
| 2 | `arch-b` | Architecture | (same scope as `arch-a` — independent pass) | 14 | `findings/02-arch-b.md` |
| 3 | `perf-a` | Performance | Re-renders/memory/bundle/lazy + cold-starts/DB queries/batch/caching | 12 | `findings/03-perf-a.md` |
| 4 | `perf-b` | Performance | (same scope as `perf-a` — independent pass) | 12 | `findings/04-perf-b.md` |
| 5 | `sec-a` | Security | DB/storage rules, auth/CORS/CSP + XSS/middleware/input-validation/secrets | 12 | `findings/05-sec-a.md` |
| 6 | `sec-b` | Security | (same scope as `sec-a` — independent pass) | 12 | `findings/06-sec-b.md` |
| 7 | `maint-a` | Maintainability | Naming/complexity/duplication/dead-code + type-safety/consistency/error-types/reuse | 14 | `findings/07-maint-a.md` |
| 8 | `maint-b` | Maintainability | (same scope as `maint-a` — independent pass) | 14 | `findings/08-maint-b.md` |
| 9 | `robust-a` | Robustness | Error boundaries/feedback/edge/offline + error-handling/transactions/logging/retries | 12 | `findings/09-robust-a.md` |
| 10 | `robust-b` | Robustness | (same scope as `robust-a` — independent pass) | 12 | `findings/10-robust-b.md` |

`--dual` adds cross-model agreers for the Security pillar (highest-stakes; self-critique-paradox mitigation).

### 1.1-W Dispatch via Workflow (opt-in path)

Dispatch the 10 pillar agents as one `parallel()` with `schema:` validation. The script owns dispatch only; this skill collects the validated return + the agents' findings files in Phase 2 exactly as the `Agent()` path does.

**Dispatch:** invoke the plugin workflow `/blitz:audit-sweep` (`workflows/audit-sweep.js`) with
`args: { roster: [{ name, prompt }, …], findingsSchema }` — the roster is the 10-agent table below with each
`prompt` filled from the pillar template (agent name, pillar, scope, file cap, output path, checklist, stack,
inventory inline). It returns `{ agents: [{ name, ok, result }] }`. **On any failure** (tool absent, no
`Workflow(<name>)` allow rule in a `-p` run, script error, abort) **fall back to §1.1 (`Agent()`)** — never
hard-fail. Resume semantics + concurrency cap: [agents.md](/_shared/agents.md)
§Workflow Dispatch Contract.

- Each `a.prompt` is the pillar template from `references/main.md` — it MUST embed the OUTPUT STYLE snippet (Invariant 5) and the write-as-you-go rule (§1.3 step 8).
- `model: 'sonnet'` per token-budget routing (explicit — prevents `[1m]` inheritance).
- `schema` replaces the `classify_output()` gate; `null` entries = failed agents (handled by Phase 2.2).
- After the workflow returns, proceed to Phase 1.4 / Phase 1.5 / Phase 2 unchanged.

### 2.3.5 Adversarial FP-verify panel (Phase 2.5)

Per surviving finding (post-dedup), spawn N perspective-diverse refuters (correctness / security / reproduces lenses) — `Workflow` `parallel()` or `Agent()` per [agents.md](/_shared/agents.md). Each re-reads the cited `file:line` and attempts to **REFUTE** against actual behavior (default refuted if not reproducible); **≥majority refute → drop** the finding. Survivors attach a reproducing excerpt — nothing is reported without it (registry downgrade rule; native `/code-review` validation parity, <1% FP). Semantic findings remain `advisory` regardless of confidence (rank ↑, never authority). Deterministic findings (base 1.0) skip the panel — the mechanism is the verification. Detail: this file §Recall hardening.

When the §1.0 gate selected the `Workflow` path, dispatch the panel as a nested `parallel()` per finding — each finding's lenses verify concurrently while other findings are still being judged (pipeline over findings, barrier over lenses). On any `Workflow` failure, fall back to `Agent()`.

```js
// args: { findings:[{key,desc,fileLine}], lenses:['correctness','security','reproduces'], verdictSchema }
const OS = 'OUTPUT STYLE: terse-technical per /_shared/output.md. Drop articles/fillers/hedging; preserve code/paths/commands/JSON verbatim; no preamble.'
const judged = await parallel(args.findings.map(f => () =>
  parallel(args.lenses.map(lens => () =>
    agent(`${OS}\n\nRe-read ${f.fileLine}. REFUTE via the ${lens} lens: "${f.desc}". Default refuted=true if not reproducible.`,
      { label: `refute:${lens}:${f.key}`, phase: 'Audit', model: 'sonnet', schema: args.verdictSchema })))
    // full-lens denominator is deliberate (recall bias: refuter failure must NOT auto-drop a finding — see references/main.md §553)
    .then(votes => ({ f, refuted: votes.filter(Boolean).filter(v => v.refuted).length > args.lenses.length / 2 }))))
const survivors = judged.filter(j => !j.refuted).map(j => j.f)  // ≥majority refute → dropped
```

- `schema`-validated verdicts replace inline parsing; `.filter(Boolean)` drops `null` (failed) refuters before the majority count. Deterministic findings never enter `args.findings`.

### 0.2 Build Codebase Inventory

1. **Identify project root and structure.** Run:
   ```bash
   find . -maxdepth 3 -name 'package.json' -not -path '*/node_modules/*' | head -30
   ```
2. **Read root config files.** Read `package.json`, workspace configs (`pnpm-workspace.yaml`, `nx.json`, `turbo.json`), and framework configs (`nuxt.config.ts`, `vite.config.ts`, etc.).
3. **Map entry points.** Glob for:
   - Frontend: `**/pages/**/*.vue`, `**/views/**/*.vue`, `**/components/**/*.vue`, `**/composables/**/*.ts`, `**/stores/**/*.ts`, `**/router/**/*.ts`
   - Backend: `**/functions/**/*.ts`, `**/server/**/*.ts`, `**/api/**/*.ts`, `**/schemas/**/*.ts`
   - Config: `**/rules/**/*`, `**/*.rules`, `**/security*`, `**/middleware/**/*.ts`

4. **Count files per area.** Record approximate file counts for frontend, backend, config, and tests. This guides agent file caps.

5. **Write inventory file:**
   ```
   ${AUDIT_RUN}/inventory.json
   ```
   Schema:
   ```json
   {
     "timestamp": "<ISO-8601>",
     "root": "<project-root>",
     "stack": { "framework": "...", "ui": "...", "backend": "...", "build": "..." },
     "entry_points": {
       "frontend": ["<paths>"],
       "backend": ["<paths>"],
       "config": ["<paths>"]
     },
     "file_counts": { "frontend": 0, "backend": 0, "config": 0, "tests": 0 }
   }
   ```

## Error Recovery

- **Too few source files**: Inform user the codebase is too small for a full audit. Suggest manual review.
- **A pillar has little/no relevant surface** (e.g. no frontend, or no backend): still spawn both same-scope passes for that pillar — each auto-scopes to what exists from the inventory; sparse pillars simply yield few findings. Do NOT skip numbered agents (the roster is 2 independent passes per pillar, not a frontend/backend split). If an entire pillar is N/A (e.g. no UI at all), note it in the `coverage_boundary` (§2.8) rather than dropping the passes.
- **Agent timeout**: Mark as failed, proceed with available findings. Note gaps in report.
- **All agents failed**: Abort and report the failure. Suggest checking stack detection and file permissions.
- **Existing audit found**: Load previous findings for comparison. Include a "Delta" section in the report showing improvements and regressions.
- **`tasks.sh add` refuses a task** (no non-test check, bad role, duplicate id): fix the command, never hand-edit `tasks.json`; if no executable check exists, demote the theme to a note.
- **No theme has an executable check**: still write `spec.md` (findings + notes) and an empty `tasks.json`; say so in the final output.

### 1.2 Security pillar: registry rows first, claude-security when installed

The pillar's authoritative checks are the registry `sec-*` rows ([`/_shared/check-registry.json`](/_shared/check-registry.json), `pillar == security`); they run in the deterministic lane (§1.5) on every audit and keep reject authority. Deep semantic scanning is delegated when the `claude-security` plugin is present:

```bash
SEC_PLUGIN=0
{ claude plugin list 2>/dev/null | grep -q 'claude-security'; } \
  || grep -qs 'claude-security' "${HOME}/.claude/plugins/installed_plugins.json" && SEC_PLUGIN=1
echo "[audit] security: registry sec-* rows$( [ "$SEC_PLUGIN" = 1 ] && echo ' + claude-security scan' || echo ' + sec-a/sec-b passes')" >&2
```

- **`SEC_PLUGIN=1`** → do not spawn `sec-a`/`sec-b` (roster shrinks to 8). Invoke the plugin's scan skill on the audit scope, write its verified findings (SARIF → severity schema, one `FINDING:` per result, `Confidence: 90`) to `findings/05-sec-external.md` tagged `lane: external`. External findings skip §2.1.4 aggregation and §2.3.5 refutation (already verified by the plugin) and stay `advisory`.
- **`SEC_PLUGIN=0`** → spawn `sec-a`/`sec-b` as listed; the report's Security section and the Phase 3 spec carry one line: `Recommendation: install the claude-security plugin (verified SARIF findings) or run /security-review before release; blitz audit covers registry sec-* rows only.`
- `--dual` applies only when `SEC_PLUGIN=0` (cross-model agreers for the two passes).

### 1.5 Deterministic lane (run alongside the semantic passes)

Run the registry deterministic checks ([`/_shared/check-registry.json`](/_shared/check-registry.json), `lane==deterministic ∧ consolidated_target∈{audit,both}`) across the codebase — grep/tsc/import-graph, zero-FP — and write to `${AUDIT_RUN}/findings/00-deterministic.md` tagged `lane: deterministic`. The deterministic and semantic lanes catch **disjoint** bug classes (ianlpaterson 38-task) — a deleted test has no semantic signature; a wrong answer-key has no structural one — so run both. Detail: this file §Recall hardening.

**Design pillar (`--pillar design`):** also select `pillar == design` rows — Layer 0 (`adapter: universal`) always; Layer 1/2 gated by the `scripts/detect-stack.sh` adapter; `reconciliation.relaxFor` suppresses per stack (firing logic identical to `/blitz:check --only design`). Vendored rows share one **key-free** `npx impeccable detect --json` run (filter by `detection.filter`); the provider-gated tells route through `agents/design-critic.md`'s gemini CLI (`BLITZ_GEMINI_BIN`), the pillar's **semantic** aggregator over rendered screenshots (not the 10 code passes). Detail: this file §Phase 1.D2.

### 1.0 Select Dispatch Mode (capability gate)

Per [agents.md](/_shared/agents.md). Two dispatch paths produce identical findings files under `${AUDIT_RUN}/findings/`; only the orchestration mechanism differs. The 10-agent flat pool is the canonical `Workflow` pilot (no DAG, no worktree, no cross-session resume).

```bash
case "${BLITZ_DISPATCH:-auto}" in
  agent)    USE_WORKFLOW=false ;;
  workflow) USE_WORKFLOW=true ;;                 # force; error if Workflow tool absent
  *)        USE_WORKFLOW=maybe ;;                # auto: use Workflow iff tool present
esac
echo "[audit] dispatch=${BLITZ_DISPATCH:-auto} use_workflow=${USE_WORKFLOW}" >&2
```

- **`USE_WORKFLOW` truthy AND `Workflow` tool available** → §1.1-W (Workflow path).
- **else, or on ANY `Workflow` failure** → fall back to §1.1 (`Agent()` path). Never hard-fail.
- Log the chosen path to the activity-feed: `detail.dispatch: "workflow"|"agent"`.
- All filesystem I/O (Phase 0 inventory, Phase 2 report, ratchet.json, activity-feed) stays in this skill's main-thread Bash — the `Workflow` script touches none of it (hybrid wrapper boundary).

### 2.7 Copy Report to Project

Copy the consolidated report into the project:
```bash
REPORT_DIR="docs/audits"
mkdir -p "${REPORT_DIR}"
cp "${AUDIT_RUN}/reports/audit-report.md" "${REPORT_DIR}/audit-$(date +%Y%m%d).md"
```

**Opt-in HTML twin (additive — report `.md` only):** after the cp, emit an HTML twin of the human-facing report via the `emit_html()` helper (contract: `/_shared/sessions.md`; bash bodies: `hooks/scripts/_lib/html.sh` — source it, never inline). Audit reports may quote fetched/untrusted content → pass the `untrusted` trust arg (body HTML-escaped into `<pre>`, TB-4). Twin the report `.md` only; `docs/plans/audit-<date>/` (`spec.md`, `tasks.json`) is never twinned. Default (`BLITZ_OUTPUT_FORMAT` unset) is a no-op.

```bash
. "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/_lib/html.sh"   # canonical emit_html/sanitize_html bodies (never inline)
[ "${BLITZ_OUTPUT_FORMAT:-md}" = html ] && emit_html "${REPORT_DIR}/audit-$(date +%Y%m%d).md" untrusted
```

### 3.3 Write the Plan

```bash
AUDIT_DATE=$(date +%Y-%m-%d); PLAN="audit-${AUDIT_DATE}"; PLAN_DIR="docs/plans/${PLAN}"
mkdir -p "$PLAN_DIR"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" init "$PLAN"
STATUS=paused; [ "${AUDIT_PLAN_FLAG:-0}" = 1 ] && STATUS=active     # --plan activates immediately
cat > "${PLAN_DIR}/spec.md" <<EOS
---
status: ${STATUS}
priority: P2
created: ${AUDIT_DATE}
ship: manual
---
# Audit ${AUDIT_DATE}

## Goal
Resolve the ${THEME_COUNT} themes found by /blitz:audit (${TOTAL} findings: ${C}C/${H}H/${M}M/${L}L; agents ${OK}/${N}). Report: docs/audits/audit-$(date +%Y%m%d).md (gitignored; this file is the tracked summary).

## Findings summary
| Task | Pillar | Impact | Findings (file:line) |
|---|---|---|---|
| T-001 | … | … | … |

Health: Architecture NN · Performance NN · Security NN · Maintainability NN · Robustness NN. Coverage boundary: <§2.8 block, one line>.
Security: <registry sec-* rows run; claude-security delegated | one-line recommendation from §1.2>.

## Out of scope
- Findings with no executable check (notes, not tasks): <finding — file:line — why no check>
- Pillars/lanes not run: <from coverage_boundary>
EOS
```

Then one `tasks.sh add` per theme, in impact order:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh" add "$PLAN" --id T-001 \
  --title "Security: validate input in auth middleware" --role backend \
  --files "functions/src/middleware/auth.ts,functions/src/schemas/user.ts" --origin audit \
  --verify-cmd "! grep -rnE 'req\.body\.[a-zA-Z]+ *(as|!)' functions/src/middleware/auth.ts::60" \
  --notes "det-17 + sec-a/sec-b agreed; Critical; report §Security #3"
```

- `--depends` only for a real ordering (a schema task before the handler that consumes it); default none so `build --parallel` can fan out on disjoint `files`.
- Same-day rerun: `tasks.sh list "$PLAN"` first; skip a theme whose title already exists, continue ids from max+1, never rewrite `spec.md` frontmatter (a human may have flipped `status`).
- Append to `docs/plans/BACKLOG.md` nothing; the notes in `spec.md` are the parking lot.
