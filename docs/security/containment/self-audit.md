# Self-Audit — Blitz Against the Article's "Risk We Missed" Patterns

> The article's whole framing is honest disclosure of risks Anthropic missed. This audit applies the same honesty (Opus 4.8) to Blitz. Findings, not a clean bill. Confirmed against the live tree 2026-05-31.

Three questions, taken directly from the article's incidents:

1. Does any Blitz hook parse/execute untrusted project-local config **pre-trust**? (AP-1 / Gap 5)
2. Are any agents **over-permissioned** — allowlist as capability grant? (AP-3 / Gap 4)
3. Is any **persistent state** read into context unvalidated? (AP-4 / Gap 1)

---

## 1. Persistent state read unvalidated — **FINDING (confirmed)**

**Yes.** `skills/_shared/session-lifecycle.md:42` instructs every skill to "Read ALL `.cc-sessions/*.json` files" with no integrity or injection check. Lines :72/:76/:82 add the activity feed and the developer/model profiles, also unvalidated.

**Worst instance:** the carry-forward registry is not only read unvalidated — it is **auto-injected into the next sprint** (`sprint-plan` consumes it as mandatory input). An injection landing there is reloaded every session *and* converted into planned work. This is exactly AP-4's "agent state that survives the session," with the aggravating factor that it *drives work*, not just context.

**Mitigating fact (honest):** Blitz already has a partial defense — orchestrator.md:146-152 caps and `jq`-extracts these fields with an explicit "injection-surface guard; Opus 4.8 ASR regression" comment, and the `rollover_count >= 3` escalation is a primitive startup classifier. So the orchestrator's *read path* is partially hardened; the **skill-startup read path (session-lifecycle.md) is not.** The gap is the inconsistency, not total absence.

**Severity:** HIGH. → Gap 1.

---

## 2. Agents over-permissioned — **FINDING (confirmed)**

**Yes.** Reframing `allowed-tools` as capability grants (AP-3) exposes read-only-by-role agents holding execution/egress capability:

| Agent | `tools:` | Role | Capability concern |
|---|---|---|---|
| `architect` | Read, Glob, Grep, **Bash** | "strictly read-only" structural analysis (agent-orchestration.md:47) | Bash = arbitrary command exec on an agent documented as read-only. |
| `critic` | Read, Grep, Glob, **Bash** | adversarial reviewer, read-only | same. |
| `design-critic` | Read, Grep, Glob, **Bash** | reads screenshots, read-only | same. |
| `research-critic` | + **WebFetch** | citation prober | network egress — **justified** by its job, but undocumented as a deliberate grant. |

**No agent declares `disallowed-tools`.** Per `docs/validation/v1.16.0/VERDICT.md:116`, across the whole suite only `health/SKILL.md` truly enforces read-only via declaration; three other read-only-by-construction skills (completeness-gate, setup, worktree-prune) ship prose-only.

**Mitigating fact (honest):** these critics genuinely need `Bash` for read-subset commands (`git log`, `grep`, `jq` over session state) — the grant is not gratuitous. The issue is that the grant is *unbounded and undocumented*: nothing distinguishes "Bash for read-only queries" from "Bash for `curl | sh`." The platform's auto-mode hard-deny catches the worst of it (egress, force-push), so this is **defense-in-depth narrowing**, not an open hole.

**Severity:** MEDIUM. → Gap 4.

---

## 3. Hooks parsing untrusted project-local config pre-trust — **PARTIAL FINDING (confirmed, milder than the article's case)**

**Parse: yes. Execute: no.** `hooks/scripts/session-start.sh` (wired to `SessionStart`, `hooks/hooks.json:37-42`) reads `.cc-sessions/HANDOFF.json` + `activity-feed.jsonl` at startup and **echoes their fields into Claude's context uncapped** (session-start.sh:22-38, :48-52). The orchestrator caps the identical fields at `[0:200]` (orchestrator.md:146-149); the hook does not — so the startup path is the weaker of two paths over the same untrusted data.

**Crucial honest distinction from the article's incident:** the article's AP-1 was *code execution* — a committed `.claude/settings.json` hook ran attacker code before the trust prompt. Blitz's `session-start.sh` **does not execute project-controlled code**; it `jq`-parses and echoes text. So Blitz is exposed to the *context-injection* form of AP-1, not the *code-execution* form. Blitz also delegates the trust prompt itself to the Claude Code platform — it does not (and should not) reimplement it.

**Assertion to preserve (audited true today):** no Blitz hook executes project-controlled content pre-trust. `pre-edit-guard.sh` and the `block-*.sh` hooks read `tool_input` (the agent's own action), not committed project config; `session-start.sh` parses but does not `eval`/source any project file. Gap 5's `security.md` note exists to keep this assertion true as hooks evolve.

**Severity:** MEDIUM. → Gap 5.

---

## 4. What the audit did NOT find (negative results, stated honestly)

- **No code-execution pre-trust path.** (§3 — searched all 16 hooks; none `eval`/`source` project files.)
- **No missing deterministic boundary for destructive ops.** `block-destructive-git/sql.sh`, `block-no-verify.sh`, `block-test-deletion.sh`, `pre-edit-guard.sh` cover the auto-mode hard-deny groups (containment-model.md §6.1). Secrets, lock files, `.git/`, `node_modules/` are guarded (pre-edit-guard.sh:26-66).
- **No raw-prose sub-agent channel.** spawn-protocol §9 already forces structured JSON — the AP-6 "structured facts" mitigation is present (Gap 2 is *labeling*, not building).
- **A security pillar already exists** in `check-registry.json` (det-06/07/15/18 + sem-sec) — the gaps *extend* it, no new subsystem.

---

## 5. Honest scorecard

| Question | Verdict | Severity | Gap |
|---|---|---|---|
| Persistent state read unvalidated? | **Yes** (carry-forward worst) | HIGH | 1 |
| Sub-agent output trust undefined? | **Yes** (structure present, trust label absent) | HIGH | 2 |
| Fetched content uninspected? | **Yes** (liveness ≠ payload safety) | HIGH | 3 |
| Agents over-permissioned? | **Yes** (3 critics hold Bash; 0 declare disallowed-tools) | MEDIUM | 4 |
| Hooks parse project-local pre-trust? | **Yes, parse-not-execute** (uncapped echo) | MEDIUM | 5 |

**Bottom line:** Blitz is not negligent — it has a real deterministic environment layer and already applies injection caps in the orchestrator. But it has been leaning on those caps being applied *in one path* while three other paths (skill startup, sub-agent replies, fetched content) inherit none of that hardening, and its tool grants predate the capability-grant lens. The five fixes close those paths using machinery Blitz already has.

---

## 6. Cross-references
- `gap-fixes.md` — fix design per finding.
- `threat-model.md` — the posture these findings motivate.
- `SYNTHESIS.md` — the order to fix them in.
