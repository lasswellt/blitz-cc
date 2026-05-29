# Validation — agent: orchestrator (v1.16.0 cohesion+DW)

Unit: `orchestrator` · File: `agents/orchestrator.md` · Owner: O4
Method: assert-and-prove. Every PASS cites file:line or command output. Counts re-derived.

---

## A1 — Frontmatter + reply contract — PASS

- `bash hooks/scripts/agent-frontmatter-validate.sh agents/orchestrator.md` → `OK: 1 agent .md files conform` (EXIT=0).
- Forbidden silently-stripped fields (`hooks`, `mcpServers`, `permissionMode`) checked by validator lines 125-129; none present in `agents/orchestrator.md` frontmatter (lines 1-33). Confirmed absent.
- OUTPUT STYLE snippet present verbatim at §7 line 196 (validator gate #10, SNIPPET_RE line 40).
- Reply contract: orchestrator is a terminal router that replies to the **human user**, not an upstream Agent() caller — it has no Agent tool (line 45) so it never produces a worker JSON reply. Its own discipline is declared: ≤3-sentence routing reply (line 165), 3-line output contract (§6 lines 173-179), cites `/_shared/token-budget.md` (line 167). The 50-word JSON reply contract (token-budget.md) and Agent Output Contract (spawn-protocol.md) bind spawned workers; orchestrator is not spawned-with-JSON-expectation and does not spawn, so they are honored by non-applicability + the declared 3-line contract.

## A2 — Read-only enforcement — PASS

- `tools: Read, Grep, Glob, Bash, TaskCreate, TaskUpdate, TaskList, Monitor` (line 18).
- NO `Write`, `Edit`, `MultiEdit`, `NotebookEdit`, or `Agent` in the tools list (grep of tools line returned none).
- Read-only is ENFORCED by construction (allowed-tools omission), not merely asserted in prose. Body §3 line 134 ("You cannot Write, Edit, or spawn subagents") restates the same constraint but the enforcement is the tools allowlist. PASS.

## A3 — Orchestrator injection guard — NEEDS-HARDENING (one uncapped field)

Enumeration of every jq-rendered/interpolated field in §4 (lines 144-153):

| Line | Source | Field | Trust | Cap | Verdict |
|---|---|---|---|---|---|
| 144 | activity-feed.jsonl | `.message` | semi-trusted (skill-written) | `[0:200]` | CAPPED ✓ |
| 147 | HANDOFF.json | `.sprint` | semi-trusted (sprint-dev-written) | **none** (`\(.sprint // "none")` raw) | **UNCAPPED ✗** |
| 147 | HANDOFF.json | `.phase` | semi-trusted | `\|tostring\|.[0:200]` | CAPPED ✓ |
| 147 | HANDOFF.json | `.uncommitted` | semi-trusted | `\| length` (numeric) | safe (non-text) ✓ |
| 150 | carry-forward.jsonl | (group/select) | semi-trusted | `\| length` (numeric only) | safe (non-text) ✓ |
| 153 | ratchet.json | `.current`/`.max_allowed`/`.min_allowed`/`.direction` | semi-trusted | none | safe: `.current` numeric, `.direction` enum `up`/`down` per ratchet-protocol.md:40-60 — not free-text injection surface |

Finding: the guard's own comment (lines 142-143) scopes the truncation defense to the semi-trusted skill-written files rendered verbatim, and HANDOFF.json is exactly such a file (state-handoff.md:72, sprint-dev-written). `.phase` is capped `[0:200]` but the adjacent `.sprint` field on the SAME line 147 is interpolated raw. `.sprint` has no schema constraint forcing it numeric/enum, so a compromised/buggy sprint-dev writer could inject a long/hostile string that renders verbatim into the orchestrator's turn-context. Per the rubric standard ("one uncapped field defeats the guard"), this is a gap. Fix: wrap `.sprint` as `\((.sprint // "none")|tostring|.[0:200])`.

## A4 — Routing completeness — PASS (39/39)

- Re-derived skill count: `ls -d skills/*/` = 40 dirs; `skills/_shared/` has NO SKILL.md (not a skill) → **39 real invokable skills** (`for d in skills/*/; do [ -f "$d/SKILL.md" ]...` = 39).
- Routed targets in §2 matrix: `grep -oE '/blitz:[a-z-]+'` unique = 39.
- `comm -3 real_skills routed` = **empty** → exact 1:1 match. 39/39 distinct skill targets mapped to ≥1 trigger phrase. (Note: `ship`/`release`/`migrate` are skills and routed at lines 78-79, 103.)
- Stack-gated skills tagged: §2 line 59 "**Vue-conditional skills**: route `/blitz:code-doctor`, `/blitz:ui-build`, `/blitz:ui-audit` only when detected stack includes Vue/Nuxt … short-circuit with 'stack not compatible'".
- worktree-prune flag surface present: line 120 lists `--dry-run` (default), `--apply --merged-only`, `--apply --all-older-than <duration>`, `--force`.

## A5 — Critic detector re-justification — N/A

Critic-only check. Unit is orchestrator.

## A6 — DW agent-prompt parity — N/A

Critic/research-critic/design-critic only. Orchestrator does not spawn agents (no Agent tool, line 45) and does not dispatch via Workflow (grep for `Agent(`/`Workflow`/`dispatch` finds only the constraint statement at line 45 and the `/blitz:next --loop` "dispatches one phase" prose at line 72, which describes the downstream skill, not orchestrator-issued dispatch). No agent-prompt parity surface exists in this unit.

---

## Agent verdict: needs-hardening

Read-only construction (A2), frontmatter contract (A1), and 39/39 routing completeness (A4) all hold. The single open issue is the A3 injection-guard gap: HANDOFF.json `.sprint` is rendered raw on line 147 while its sibling `.phase` is capped — one uncapped semi-trusted free-text-capable field in the very guard that documents the truncation defense.

## Single highest-leverage fix

Cap the `.sprint` field on `agents/orchestrator.md:147`: change `\(.sprint // "none")` to `\((.sprint // "none")|tostring|.[0:200])` so every free-text field from the semi-trusted HANDOFF.json is truncated uniformly (closes A3).
