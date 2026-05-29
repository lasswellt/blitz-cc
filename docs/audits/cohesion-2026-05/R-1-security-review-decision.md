---
title: "R-1 decision — codebase-audit Security pillar vs native /security-review (O8)"
epic: E-032
created: 2026-05-28
verdict: KEEP BOTH — complementary, not duplicate; add cross-ref
---

# R-1: Is codebase-audit's Security pillar a duplicate of native `/security-review`?

## Finding (verified)
- There is **no blitz `security-review` skill**. `/security-review` is the **native Claude Code command** (focused diff/branch security review).
- `codebase-audit` has a Security pillar: 2 agents — `sec-rules` (DB/storage rules, auth config, CORS, CSP) + `sec-code` (XSS, auth middleware, input validation, secrets). `skills/codebase-audit/SKILL.md:167-168`.

## Verdict: KEEP BOTH (not a true dup)
| Dimension | codebase-audit Security pillar | native `/security-review` |
|---|---|---|
| Scope | whole-codebase posture (rules + code + config) | current diff / branch / PR |
| Cadence | periodic / pre-release audit | per-change |
| Output | findings → roadmap epics (`scope:` ingestible) | inline PR comments / working-tree |
| Cross-cutting | yes (Security × Perf × Robustness synthesis) | no (security-only) |

These are different tools for different moments: broad standing audit vs focused change review. Retiring either loses real coverage. **No merge, no retire.**

## Action (low-risk, defer to a docs sprint)
- Add a one-line cross-ref in `codebase-audit/SKILL.md` Security section: "For per-diff/PR security review use the native `/security-review`; this pillar is the whole-codebase complement."
- No registry epic needed beyond this cross-ref. O8 resolved.
