# Codebase Audit — Reference Material

This file provides templates, checklists, and schemas used by the codebase-audit skill.

---

## Agent Prompt Template

<!-- import: /_shared/agent-prompt-boilerplate.md -->
See [/_shared/agent-prompt-boilerplate.md](/_shared/agent-prompt-boilerplate.md) for canonical boilerplate (BUDGET, WRITE-AS-YOU-GO, HEARTBEAT, PARTIAL, CONFIRMATION) shared across orchestrator skills. The audit-specific template below remains the byte-stable spawn source — Invariant 5 (OUTPUT STYLE snippet) requires inline preservation. The shared fragment is the canonical reference + extraction target for future runtime splicing.

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
   - This is artifact construction, NOT self-judgment. The shell decides — your role is to design the falsification test. Per `docs/_research/2026-05-16_audit-agent-fp-prevention.md`.
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

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles,
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
**Action**: Fix within current sprint or next sprint.
**Score weight**: 5

### Medium
**Definition**: Code quality concern that increases maintenance burden or degrades experience over time.
**Examples**: Inconsistent naming, moderate code duplication, missing loading states on secondary views, untyped function parameters.
**Action**: Address in dedicated cleanup epic.
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

## Proposed Epics

See companion file: `audit-YYYYMMDD-epics.md`
```

---

## Proposed Epic Format

Use this format for each proposed epic generated from audit findings:

```markdown
## PROPOSED EPIC: <theme-name>

**ID**: AUDIT-<NNN>
**Pillar**: <Architecture|Performance|Security|Maintainability|Robustness>
**Priority Score**: <impact/effort ratio>
**Impact Score**: <sum of severity weights>
**Effort Estimate**: <Small (1-3 files) | Medium (4-8 files) | Large (9+ files)>
**Finding Count**: N (Nc Critical / Nh High / Nm Medium / Nl Low)

### Description

<2-3 sentences describing the problem domain and why this epic matters.>

### Key Findings

- **[SEVERITY]** <finding-title> — <file-path> — <one-line description>
- ...

### Proposed Stories

1. <story-title> — <1-sentence description> (Effort: S/M/L)
2. ...

### Success Criteria

- [ ] <measurable criterion>
- [ ] <measurable criterion>
- ...

### Dependencies

- Depends on: <other-epic-ids or "None">
- Blocks: <other-epic-ids or "None">

### Recommended Phase

<early | mid | late> — Based on dependency depth and priority score.
```

---

## Epic Index JSON Schema

```json
{
  "audit_date": "YYYY-MM-DD",
  "overall_health_score": 0,
  "pillar_scores": {
    "architecture": 0,
    "performance": 0,
    "security": 0,
    "maintainability": 0,
    "robustness": 0
  },
  "total_findings": 0,
  "severity_totals": {
    "critical": 0,
    "high": 0,
    "medium": 0,
    "low": 0
  },
  "proposed_epics": [
    {
      "id": "AUDIT-001",
      "theme": "<theme-name>",
      "pillar": "<pillar>",
      "priority_score": 0.0,
      "impact_score": 0,
      "effort": "Small|Medium|Large",
      "finding_count": 0,
      "severity_breakdown": {
        "critical": 0,
        "high": 0,
        "medium": 0,
        "low": 0
      },
      "proposed_stories": [
        {
          "title": "<story-title>",
          "description": "<one-sentence>",
          "effort": "S|M|L"
        }
      ],
      "success_criteria": ["<criterion>"],
      "dependencies": [],
      "blocks": [],
      "recommended_phase": "early|mid|late"
    }
  ]
}
```

---

## Recall hardening (sprint-19) — aggregation, FP-verify panel, deterministic lane, recall instrumentation

Detail for the SKILL.md §"Phase 1.D / 2.0 / 2.5 / 3.5" contract. Source specs: `docs/consolidation/review-audit/audit-spec.md`, `flaw-finding-proof.md`.

### Phase 1.D — deterministic lane

Load `/_shared/check-registry.json`, select `lane=="deterministic" && consolidated_target in {audit,both}`. Run each row's `detection.command` across the codebase (grep/tsc/import-graph). Zero-FP, no aggregation needed. Write findings to `${AUDIT_RUN}/findings/00-deterministic.md` tagged `lane: deterministic`. These complement the semantic pillars — the two lanes catch disjoint bug classes (a deleted-test/broken-build has no semantic signature; a wrong answer-key has no structural signature).

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
