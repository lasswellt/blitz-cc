# Agent Prompt Boilerplate — Shared Fragment

Canonical text for prompt sections that recur across blitz orchestrator skills (codebase-audit, codebase-map, code-sweep, integration-check, quality-metrics, sprint-dev, sprint-plan).

**Purpose:** author-time deduplication of the ~12 K tokens/sprint of recurring Agent() prompt boilerplate. Skills currently inline these sections in their own `references/main.md` for byte-stable spawn behavior. Future orchestrators may Read this fragment plus the per-skill `references/main.md` and splice the relevant section into the Agent() prompt at spawn time, replacing the inline copy. Until that splice machinery exists in every orchestrator, the inline copies in `skills/<skill>/references/main.md` remain authoritative; this fragment is the canonical reference + extraction target.

**Important:** the `OUTPUT STYLE: terse-technical …` snippet is NOT extracted here. Sprint-review Invariant 5 (per S5-003) requires that snippet to be present verbatim in every references/main.md — deduping it would break the invariant. The canonical OUTPUT STYLE text lives in [spawn-protocol.md §7](spawn-protocol.md#7-output-style-terse-output-protocol).

**Companion docs:**
- [spawn-protocol.md](spawn-protocol.md) — weight classes (Light/Medium/Heavy), HEARTBEAT/PARTIAL canonical specs, banned patterns
- [terse-output.md](terse-output.md) — the OUTPUT STYLE protocol referenced by every Agent() prompt
- [verbose-progress.md](verbose-progress.md) — activity-feed log format

---

## Generic Agent Preamble

Used by orchestrators that spawn `general-purpose` Agents and require a written output file. Present in: `codebase-map`, `integration-check`, `quality-metrics`, `sprint-plan`.

```
You are a general-purpose agent with Write access. Your task is INCOMPLETE
if {{OUTPUT_PATH}} does not exist when you finish.
```

**When to use:** any Agent() spawn whose deliverable is a file the orchestrator will Read after the agent returns. Combine with the orchestrator-side existence check (see `spawn-protocol.md` §2 "Orchestrator-Side Validation"). Replace `{{OUTPUT_PATH}}` with the absolute path the agent must write.

---

## Weight-Class Budget Block

Every Medium/Heavy Agent() spawn declares its budget in the prompt. Caps per `spawn-protocol.md` §2.

### Medium class

Used by: `codebase-map` (per-dimension agents), `integration-check` (per-domain agents), `sprint-plan` (research agents).

```
BUDGET (Medium class — see skills/_shared/spawn-protocol.md):
- Max file reads: 15
- Max web searches: 8 (0 for codebase-only analysis)
- Max tool calls: 25
- Max output: 250 lines
- Wall-clock: 5 minutes
```

### Light class

Used by: `quality-metrics` (per-tool collectors).

```
BUDGET (Light class — see skills/_shared/spawn-protocol.md):
- Max bash commands: 1 (the tool invocation itself)
- Max file reads: 5
- Max tool calls: 8
- Max output: JSON (per per-tool schema)
- Wall-clock: 3 minutes
```

### Heavy class

Used by: `sprint-dev` dev agents (multi-story implementation in worktree).

```
BUDGET:
- Max stories this wave: 4 (already enforced by orchestrator)
- Max file reads per story: 6
- Max tool calls total: 40 (if you hit 30, finish current story and stop)
- Wall-clock: 8 min
```

**When to use:** include the matching block verbatim near the top of every Medium/Heavy Agent() prompt. Override caps with documented rationale only — defaults exist to bound silent-failure cost.

---

## Write-As-You-Go Preamble

Mandatory for Medium and Heavy agents. Prevents zero-output failure on timeout or turn-budget exhaustion. Present in: `codebase-map`, `integration-check`, `quality-metrics` (implied by JSON-stub start), `sprint-plan`.

```
WRITE-AS-YOU-GO (MANDATORY):
1. Before your first tool call, stub the output file with a header line.
2. After each checklist item / phase / finding, append to the file.
3. Do NOT accumulate findings in memory and write at the end.
```

**Variant for JSON outputs** (used by `code-sweep` tier agents and `integration-check`):

```
WRITE-AS-YOU-GO (MANDATORY):
1. Before your first tool call, stub the output file with an empty findings array.
2. After each check category completes, rewrite the file with the appended findings array.
```

**When to use:** every Medium/Heavy spawn whose output is a file. The orchestrator should still run the existence check from `spawn-protocol.md` §2 — write-as-you-go is the agent-side complement.

---

## HEARTBEAT Protocol

Mid-run liveness signal. Canonical spec in [spawn-protocol.md §3](spawn-protocol.md#3-heartbeat-and-partial-protocols). Present in: `codebase-map`, `integration-check` (JSON variant), `sprint-dev` (Item 12).

### File-append form (default)

```
HEARTBEAT PROTOCOL:
At the start of each phase, append this line to your output file:
  HEARTBEAT: <phase-name> at <ISO-8601-timestamp>
Use at least 3 heartbeats across your task. Use Bash `date -u +%Y-%m-%dT%H:%M:%SZ`
to produce the timestamp.
```

### JSON-finding variant (for agents whose output is a JSON array)

```
HEARTBEAT (recommended):
At the start of each check category, append this line to your output file
as a special finding with `"check": "_heartbeat"`:
  {"check": "_heartbeat", "phase": "<category>", "ts": "<ISO-timestamp>"}
Use Bash `date -u +%Y-%m-%dT%H:%M:%SZ` for timestamp.
```

### Story-completion variant (sprint-dev dev agents)

```
HEARTBEAT: After each story DONE, write a file ${SESSION_TMP_DIR}/agent-<role>-progress.md
appending: HEARTBEAT: S${N}-XXX done at <ISO-timestamp>. Use date -u +%Y-%m-%dT%H:%M:%SZ.
```

**When to use:** required for Heavy agents; recommended for Medium. Pick the variant matching your output schema.

---

## PARTIAL Transcript Protocol

Graceful degradation on budget exhaustion. Canonical spec in [spawn-protocol.md §3](spawn-protocol.md#3-heartbeat-and-partial-protocols). Required for Heavy class. Present in: `sprint-dev` (Item 12).

### Heavy-class canonical form

```
PARTIAL DEGRADATION:
If you have 3 or fewer tool calls remaining (or detect approaching the turn
limit, output-token limit, or wall-clock budget), STOP and append this block
to the output file:
  ---
  PARTIAL: true
  COMPLETED: [list of sections finished]
  MISSING: [list of sections skipped]
  CONFIDENCE: low|medium|high
  ---
Then write a one-line confirmation to the caller: "PARTIAL: <N> sections
complete, <M> missing" and end.
```

### Sprint-dev variant (story-id granularity)

```
PARTIAL: If you have fewer than 3 tool calls remaining, STOP before starting
a new story. Append to your progress file:
  PARTIAL: true
  COMPLETED: [list of story ids finished]
  REMAINING: [list of story ids unstarted]
  CONFIDENCE: low|medium|high
Send PARTIAL: <N> done, <M> remaining to orchestrator via the DONE/BLOCKED
protocol and end.
```

**When to use:** mandatory for Heavy agents; orchestrator must check for `PARTIAL: true` before consuming output and re-spawn narrowly on items in MISSING/REMAINING.

---

## Confirmation Line

Used by Medium agents to signal completion to the orchestrator without echoing findings. Present in: `codebase-map`, `integration-check`, `quality-metrics`, `code-sweep` (tier agents).

```
CONFIRMATION: Emit one line: "<scope-id>: <N items written>"
Do NOT echo findings in your response.
```

**When to use:** any agent whose output is a file the orchestrator will read. Prevents stdout from re-transmitting payload that the file already contains (saves tokens, keeps logs clean).

---

## Self-Falsification (audit-style agents)

Before recording any count-based, negative, or pattern-duplication finding, construct a falsification artifact (Bash, AST query, file Read) and include the artifact + output in the Evidence field. Add `Confidence: <0-100>` to every finding.

```
SELF-FALSIFICATION (audit-style only):
- Count-based ("N hits of X"): grep -n 'pattern' file | head -3; verify hits are
  content, not path/filename substrings.
- Negative ("X is absent from Y"): grep -in '<4-char-partial-of-X>' Y; any hit
  means re-evaluate.
- Pattern-duplication ("X duplicated across N files"): require N ≥ 35% of
  in-scope files AND Read 2 alleged duplicates for structural equivalence
  (not keyword overlap).
- Confidence: 0=false-positive, 25=might-be-real, 50=real-but-minor,
  75=real-and-important, 100=definitely-real. Orchestrator filters below 80.
- If Confidence < 50 after falsification: DO NOT record as a finding. Log a
  one-line entry to a separate `## Discarded Drafts` section at the bottom
  of the output file: `- <one-line claim> (Confidence N, refuted by <artifact>)`.
  Reserves finding-slots for actionable items.
- "No violations found" reports go in a separate `## Verified Clean` section,
  NOT in findings. Findings are for things to fix; clean checks are for the
  reader to see what was inspected and passed.
- Count discipline: claiming "N files match X" requires `grep -l X <files> | wc -l`
  (file count), NOT `grep -rn X <files> | wc -l` (hit count). The two differ
  when any file has multiple matches. If the claim is about hits, name it
  ("30 occurrences across 29 files"). When in doubt, run both and report
  both. Failure mode observed 2026-05-16 blind retest: "30/38 files" claim
  was actually 29 files / 30 hits (one file had 2 mentions).
- Also distinguish WHICH thing you're counting before falsifying. "Files with
  block X" ≠ "files with heading of X" ≠ "files with one line of X". Sample
  2-3 alleged hits with Read before reporting the count.

This is artifact construction, NOT self-judgment. Shell decides.
Per docs/_research/2026-05-16_audit-agent-fp-prevention.md.
```

**Output-path resolution.** When the spawning orchestrator gives you an output file path containing `${VAR}` or a `${SESSION_TMP_DIR}` placeholder, resolve it via Bash (e.g., `ls /tmp/blitz-*` or `echo "$SESSION_TMP_DIR"`) BEFORE writing your stub. Do NOT take literal placeholder text (`OUTPUT`, `<dir>`, `$VAR`) as the actual path — find the real one. Failure mode observed 2026-05-16: agent wrote to `/tmp/blitz-audit-test-OUTPUT/findings.md` literally instead of resolving the session dir.

**When to use:** every audit-style spawn (codebase-audit, code-sweep, conventions audit, flow-consistency audit, the meta-audit agents in `/blitz:research` on internal topics). NOT for sprint-dev workers (they generate code, not claims) or sprint-review reviewers (they synthesize cross-cutting findings rather than count occurrences).

**Why required:** count-as-claim with no falsification is the documented FP pattern (3 false positives in the 2026-05-16 self-audit). Literature (CHIIR 2026, EMNLP 2025) shows "ask the agent again" amplifies bias; artifact construction routes the verification through the shell, which is deterministic.

---

## Output-Style Reference (NOT extracted — invariant)

The canonical OUTPUT STYLE snippet that closes every Agent() prompt template lives in [spawn-protocol.md §7](spawn-protocol.md#7-output-style-terse-output-protocol). It is **deliberately not extracted into this fragment.** Sprint-review Invariant 5 enforces verbatim presence of that snippet in every `skills/*/references/main.md` agent-prompt template. Deduping it would break the invariant. Each references/main.md must continue to carry the snippet inline.

For the resolved active-intensity behavior at spawn time, see `spawn-protocol.md` §7 "Active-intensity interpolation".

---

## How Orchestrators Use This Fragment

Two integration patterns:

### Pattern A — author-time reference only (current default)

Skills inline the relevant boilerplate sections in their own `references/main.md`. This fragment serves as the canonical source for what the inline text should say. When updating a recurring section, edit here first, then propagate to the affected references/main.md files. The orchestrator does NOT Read this fragment at spawn time.

### Pattern B — runtime splice (future)

The orchestrator Reads both `skills/<skill>/references/main.md` and `skills/_shared/agent-prompt-boilerplate.md` at spawn time, then splices the relevant section into the Agent() prompt where the import marker appears in references/main.md. Once every orchestrator that spawns from a given references/main.md has migrated to Pattern B, the inline copy in that references/main.md may be removed.

**Migration safety:** Pattern B requires byte-identical resolved-prompt parity (see S5-001 AC3). Until parity is verified for a specific orchestrator+skill pair, the inline copy must remain — Invariant 5 (OUTPUT STYLE) and exact-match TASKS lists in agent prompts depend on per-byte stability.

---

## Per-Skill Section Index

| references/main.md | Sections currently inlined (mirror these from this fragment when updating) |
|---|---|
| `codebase-audit/references/main.md` | OUTPUT STYLE only — no HEARTBEAT/PARTIAL/BUDGET (audit pillars use their own pillar-checklist budget) |
| `codebase-map/references/main.md` | Generic agent preamble · Medium BUDGET · WRITE-AS-YOU-GO · HEARTBEAT (file-append) · CONFIRMATION |
| `code-sweep/references/main.md` | OUTPUT STYLE only — tier agents have a 90-second budget inline; JSON write-as-you-go implicit in single-array Write |
| `integration-check/references/main.md` | Generic agent preamble · Medium BUDGET · WRITE-AS-YOU-GO (JSON variant) · HEARTBEAT (JSON variant) · CONFIRMATION |
| `quality-metrics/references/main.md` | Generic agent preamble · Light BUDGET · WRITE-AS-YOU-GO (implicit) · CONFIRMATION |
| `sprint-dev/references/main.md` | Heavy BUDGET (Item 3) · HEARTBEAT (story-completion variant) + PARTIAL (sprint-dev variant) (Item 12) |
| `sprint-plan/references/main.md` | Generic agent preamble · Medium BUDGET · WRITE-AS-YOU-GO |

When extending boilerplate or fixing a bug in a recurring section, update this fragment first, then propagate to the affected references/main.md files.
