# Shortcut Taxonomy — 20 Autonomous-Coder Failure Modes (13 reject, 7 advisory)

> **Canonical source is now [`check-registry.json`](check-registry.json)** (schema `blitz-check-registry/2.0`, shipped sprint-18). This doc is the human-readable **view** of the `det-*` rows. The executable `detection.command`, `lane`, `verdict_authority`, and `base_confidence` live in the registry; the §1 table and §3 greps below mirror them for reading and MUST stay in sync (the schema lint `hooks/scripts/check-registry-validate.sh` enforces structure). Cite detectors as `det-NN`.
>
> **Count reconciliation:** 20 catalogued detectors (det-01…20; det-20 appended 2026-05-16). **13 carry reject authority** (may flip a verdict; bypass the min-confidence gate); **7 are advisory** (det-05, det-08, det-09, det-10, det-16, det-17, det-20 — append to `issues[]` only). The older "19 blocking + 1 advisory" phrasing was wrong (6 of det-01…19 are also advisory). Severity (P0–P3) ≠ verdict authority — see [`check-registry.md`](check-registry.md).

Canonical detector catalog for autonomous-coder shortcuts, lies, and fake-completion. Used by:

- `agents/critic.md` (read-only adversarial review before sprint-review PASS)
- `skills/sprint-review/SKILL.md` (Phase 3.6 invariants)
- `skills/completeness-gate/SKILL.md` (extends placeholder scanning)
- `hooks/scripts/block-*` (PreToolUse blockers for the most damaging classes)

**Why this doc exists**: `docs/_research/2026-05-01_autonomous-blitz-quality-efficiency.md` §3.3 catalogued the original 19 ways autonomous coders silently produce non-production-ready output (det-20, audit-FP, was appended 2026-05-16 → 20 total). Without grep/diff detectors, these shortcuts ship undetected. The patterns are now defined as data in [`check-registry.json`](check-registry.json); this doc is the readable view.

---

## 1. Detector matrix

| # | Failure | Detector signal | Enforcement | Source |
|---|---|---|---|---|
| 1 | Deleted failing tests | `git diff --diff-filter=D -- '*.test.*' '*.spec.*'` returns any path | `block-test-deletion.sh` (PreToolUse) + critic 2.4 | TestKube 2026 |
| 2 | `--no-verify` bypass | Bash command contains standalone `--no-verify`; reflog grep | `block-no-verify.sh` (PreToolUse) + critic 2.7 | claude-code#40117 (Mar 2026) |
| 3 | Mock count grows in src/ | `grep -rE '\bvi\.mock\|jest\.mock\|sinon\.stub\b' src/ --exclude-dir=__tests__ \| wc -l` delta > 0 | ratchet `mocks_in_src` | TestKube 2026 |
| 4 | `as any` / `@ts-ignore` proliferation | `git diff HEAD~N -- src/ \| grep -E '^\+.*\bas any\b\|@ts-(ignore\|nocheck)'` (non-test) | ratchet `as_any_count` + critic 2.1 | code-sweep Tier 1 |
| 5 | Swallow-and-continue catch | regex `catch\s*\([^)]*\)\s*\{[\s\n]*\}` or `catch.*\{[^}]*console\.(log\|warn)[^}]*\}` no rethrow | completeness-gate (existing) | OWASP A09 |
| 6 | Env var fallbacks hiding config errors | `\|\|\s*['"]` or `\?\?\s*['"]` near password\|secret\|key\|token\|host\|port | completeness-gate (new) | autonomous-coding 2026 reports |
| 7 | Hardcoded credentials | `password\s*=\s*['"][^'"]{3,}` + entropy heuristic | pre-edit-guard (.env) + completeness-gate | OWASP A07 |
| 8 | Commented-out failing assertions | `git diff \| grep '^+\s*//.*expect\|assert\|should\.'` | code-sweep Tier 2 | autonomous-coding 2026 reports |
| 9 | `throw new Error('Not implemented')` | grep | completeness-gate (existing) | blitz baseline |
| 10 | `return {}` / `return []` stubs | grep `return\s*\{\s*\}\|return\s*\[\s*\]` in business logic | completeness-gate (existing) | blitz baseline |
| 11 | Hallucinated APIs / symbols | `tsc --noEmit` + import resolution check | post-edit-typecheck-block.sh + critic 2.6 | Arize 2026 |
| 12 | Claiming done on broken build | tsc errors increased after Write | `post-edit-typecheck-block.sh` (PostToolUse, blocking) | dev.to Feb 2026 |
| 13 | `.skip`/`.only`/`xit`/`xdescribe` | grep on test files | critic 2.1 + sprint-review | blitz baseline |
| 14 | Test file renamed away | `git log --diff-filter=R --name-status \| grep '\.test\.\|\.spec\.'` to non-test | critic 2.8 | autonomous-coding 2026 reports |
| 15 | Hardcoded localhost / ports / URLs | grep `localhost\|127\.0\.0\.1\|0\.0\.0\.0\|:[0-9]{3,5}` in src | completeness-gate (new) | OWASP A08 |
| 16 | Orphaned files never imported | import-graph traversal (Level 3) | completeness-gate (existing) | blitz baseline |
| 17 | Infinite correction loop | consecutive-fix-failure counter ≥ 2 | code-sweep circuit breaker (existing) | blitz baseline |
| 18 | Destructive SQL outside migration | DROP/DELETE/TRUNCATE in psql/mysql/sqlite3/mongosh CLI command | `block-destructive-sql.sh` (PreToolUse) | Cursor+Railway, Replit Rogue |
| 19 | `git reset --hard` on dirty tree | git command + working-tree non-empty | `block-destructive-git.sh` (PreToolUse) | autonomous-coding 2026 reports |
| 20 | Unverified pattern-match claim (audit FP) | Audit finding cites grep count in Evidence with no sampled code excerpt or inverse-query output; OR no `Confidence:` field | critic 2.9 (advisory) | `docs/_research/2026-05-16_audit-agent-fp-prevention.md` |

---

## 2. Severity tiers

- **P0 (PreToolUse hard-block)**: 1, 2, 18, 19 — and 12 (PostToolUse hard-block). These are the catastrophic classes; the hook must `exit 2`.
- **P1 (sprint-review BLOCKER)**: 4, 13, 14 — sprint cannot reach PASS while present.
- **P2 (ratchet metric)**: 3, 4, 6, 7, 15 — surfaced as ratchet regressions; trigger auto-revert on deterministic regression.
- **P3 (advisory)**: 5, 8, 16, 17, 20 — completeness-gate / critic findings; surface but do not auto-block.

P0 corresponds to the five hooks shipped as part of this protocol (blast-radius too large to defer to review).

---

## 3. Detector reference (canonical greps)

Single-source-of-truth grep patterns. Scripts and skills SHOULD reference this doc instead of duplicating:

```bash
# 1. Test deletion (since N commits)
git diff --diff-filter=D --name-only HEAD~N..HEAD -- '*.test.*' '*.spec.*' '*.test.tsx' '*.spec.tsx'

# 2. --no-verify
git log --all --since='3 days ago' --pretty='%H %s%n%b' | grep -E '(^|\s)--no-verify(\s|$)'

# 3. Mock count in src/
grep -rEn '\b(vi\.mock|jest\.mock|sinon\.stub)\b' src/ --exclude-dir=__tests__ 2>/dev/null | wc -l

# 4. as any / @ts-ignore in non-test
grep -rEn '\bas any\b|@ts-(ignore|nocheck)' src/ \
  --include='*.ts' --include='*.tsx' --include='*.vue' --exclude-dir=__tests__ 2>/dev/null | wc -l

# 5. Empty catch
grep -rPzo '(?s)catch\s*\([^)]*\)\s*\{\s*\}' src/ 2>/dev/null

# 6. Env fallback near credential names
grep -rEn '(\|\||\?\?)\s*[\x27"][^\x27"]*[\x27"]' src/ 2>/dev/null | grep -iE 'password|secret|key|token|host|port' | head

# 7. Hardcoded credentials
grep -rEn '(password|api_?key|secret|token)\s*[:=]\s*[\x27"][^\x27"]{8,}' src/ 2>/dev/null | head

# 8. Commented-out assertions (in diff)
git diff HEAD~5..HEAD | grep -E '^\+\s*//.*\b(expect|assert|should)\b'

# 9, 10. Not-implemented / empty stubs
grep -rEn "throw new Error.*[Nn]ot\s*[Ii]mplemented|return\s*\{\s*\}\s*$|return\s*\[\s*\]\s*$" src/ 2>/dev/null

# 11. Hallucinated APIs (use type-check)
npx tsc --noEmit 2>&1 | grep -E 'error TS2(307|305|304|339|345)'

# 13. .skip/.only/xit/xdescribe in tests
grep -rEn '\.(skip|only)\s*\(|\bxit\b|\bxdescribe\b|\bxtest\b|test\.todo\(' \
  --include='*.test.*' --include='*.spec.*' . 2>/dev/null

# 14. Test file rename to non-test
git log --since='1 day ago' --diff-filter=R --name-status -- '*.test.*' '*.spec.*'

# 15. Hardcoded localhost/ports
grep -rEn '(https?://(localhost|127\.0\.0\.1|0\.0\.0\.0)|:[0-9]{4,5}\b)' src/ \
  --include='*.ts' --include='*.tsx' --include='*.vue' 2>/dev/null | head

# 18. Destructive SQL in shell history (best-effort)
history 2>/dev/null | grep -iE '(DROP\s+TABLE|TRUNCATE|DELETE\s+FROM\s+[^;]+;)' | head

# 19. git reset --hard usage in commit messages
git reflog --all | grep -iE 'reset.*--hard' | head

# 20. Unverified pattern-match claim in audit findings file
# Flag Evidence blocks that record a count without a sampled code excerpt or
# inverse-query output. Run against each audit-style findings file.
FINDING_FILE="${1:-}"
grep -A3 '^\*\*Evidence\*\*:' "$FINDING_FILE" \
  | grep -E '^\*\*Evidence\*\*:\s*[0-9]+\s*(hits|matches|occurrences|instances|files)\b' \
  | grep -v '```'
# Also flag findings missing a Confidence: <0-100> field
grep -L 'Confidence:\s*[0-9]\+' "$FINDING_FILE"
```

Replace `HEAD~N` with the appropriate sprint-start commit when running from sprint-review.

---

## 4. False-positive escape hatches

| Detector | Escape | Justification |
|---|---|---|
| Test deletion | If commit message contains `BREAKING:` AND user is the committer, allow. | Genuine breaking change with intentional test removal. |
| `--no-verify` | Env var `BLITZ_OVERRIDE_NO_VERIFY=1` set by user (not agent). | Production hotfix with documented flaky test. Logged. |
| `as any` in non-test | Inline comment `// blitz:any-allowed: <reason>` on same line. | Unavoidable interop. Comment is documentation. |
| `.skip` in tests | Inline comment `// blitz:skip-pinned: #<issue>` referencing tracked issue. | Test pinned awaiting external fix. |
| Destructive SQL | Path contains `migrations/` OR `migrate up\|down\|run` invocation. | Migration tooling. |
| `git reset --hard` | Working tree clean OR user manually invoked. | No work to lose. |

The escape hatches are documented to keep critic from being uselessly noisy. Agents must NOT add these comments unless they have a real, defensible reason — sprint-review Phase 3.6 spot-checks 3 random escape-hatch comments per sprint and demands the rationale survive scrutiny.

---

## 5. Related

- `agents/critic.md` — primary consumer (read-only adversarial review)
- `hooks/scripts/block-no-verify.sh`, `block-destructive-git.sh`, `block-destructive-sql.sh`, `block-test-deletion.sh`, `post-edit-typecheck-block.sh` — P0 enforcement
- `skills/_shared/ratchet-protocol.md` — ratchet metrics 3, 4, 6, 7, 15
- `skills/completeness-gate/SKILL.md` — placeholder + completeness scan
- `skills/code-sweep/SKILL.md` — Tier 1/2 progressive cleanup
- `skills/sprint-review/SKILL.md` — Phase 3.6 enforcement
- `docs/_research/2026-05-01_autonomous-blitz-quality-efficiency.md` §3.3 — research basis (with citations)
