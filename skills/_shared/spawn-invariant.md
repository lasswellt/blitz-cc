# Spawn invariant

The half of the `dev` / `test-writer` spawn spec that is **identical on every
spawn**. Items 6, 7, 9, 10 and 11 of the 11-item spec in
[agents.reference.md](agents.reference.md) §3.1, plus the mock policy.

`hooks/scripts/subagent-context.sh` injects this file verbatim through
`SubagentStart.additionalContext`, so it is byte-identical across every spawn
and the platform leaves the subagent's prompt cache intact when it re-injects
after the subagent's own auto-compaction. The variable half (task id, title,
`ROLE:`, `SCOPE_FILES:`, `verify[]`, budget block) stays in the spawn prompt,
where it belongs: anything that varies per call goes in the prompt, anything
that does not goes here. Never interpolate a timestamp, a session id or command
output into this file.

A skill that cannot rely on the hook (the hook is disabled, or the spawn is not
a blitz agent) inlines this content into the prompt instead. The content is the
contract either way.

---

## Never-edit list (item 6)

Do not create, modify or delete:

- `docs/plans/*/tasks.json` — only `scripts/tasks.sh` writes it; a `PreToolUse`
  hook denies every other write, and attempting one wastes a turn.
- `docs/plans/*/progress.md` — the orchestrator's ledger.
- `.cc-sessions/**` — session records, gates, baselines, the activity feed.
- Test files, unless your `ROLE:` is `test`.
- Any path the spawn prompt's project additions name.

## Reply contract (item 7)

Return ONLY this JSON, nothing else (no markdown fence, no preamble):

```
{
  "status": "DONE|DONE_WITH_CONCERNS|NEEDS_CONTEXT|BLOCKED",
  "task": "T-003",
  "summary": "<one sentence, ≤50 words>",
  "files_changed": ["src/..."],
  "verify": [{"cmd": "...", "ok": true, "tail": "<≤200 chars>"}],
  "concerns": [{"severity": "low|med|high", "where": "path:line", "what": "<≤200 chars>"}],
  "blocked_reason": null,
  "escalate": null,
  "commit": "<sha or null>",
  "source_trust": "trusted|untrusted"
}
```

Exactly one status:

| Status | Use it when |
|---|---|
| `DONE` | Every `verify[]` command passed in your run and your edits stayed inside `SCOPE_FILES`. |
| `DONE_WITH_CONCERNS` | Verify passed, but you touched a file outside scope, made a Tier-2 deviation, or doubt the spec. List each in `concerns[]`. |
| `NEEDS_CONTEXT` | You cannot proceed without information the prompt lacks. Say exactly what is missing. This does not count as an attempt. |
| `BLOCKED` | An `ESCALATE:` condition, an underivable oracle, a missing dependency, or budget exhausted mid-task. Set `blocked_reason` from the `tasks.json` vocabulary (`hard_spec`, `oracle-underivable`, `test-assertion-suspect`, `scope-expansion-needed`, `circuit-breaker`, `dependency-missing`, `ratchet:<metric>`) and list what landed in `files_changed[]`. |

`PARTIAL` and `HEARTBEAT` are retired. Rich artifacts go to a file referenced
from `files_changed[]`, never inline in the reply.

## Commit format (item 9)

One commit per task, inside your worktree when you have one:

```
feat(<slug>/<role>): T-003 <title>

Task: <slug>/T-003
```

Use `fix(<slug>/<role>): …` for an auto-fix deviation. Never `--no-verify`; a
hook blocks it and the attempt is logged.

## Output style (item 10)

OUTPUT STYLE: terse-technical per `/_shared/output.md`. Drop articles, fillers
and hedging; preserve code, paths, commands and JSON verbatim; no preamble, no
trailing summary of work already visible in the diff.

## Stop conditions (item 11)

- Reply as soon as every `verify[]` command passes. Do not keep polishing.
- The `verify[]` results you report must come from a run made **after your last
  edit**. If you changed any file after a passing run, run `verify[]` again
  before replying. A pass from before your last edit is not a pass.
- Reply `BLOCKED` the moment an `ESCALATE:` condition holds. Do not work around it.
- Stop before starting a new file when you have 3 or fewer tool calls left in
  your budget, and reply with what landed.

## Working rules

- **Finish the task in this run.** Do not stop to check in, summarize progress
  or ask whether to continue. The orchestrator is not watching mid-run; a reply
  that is not `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT` or `BLOCKED` is
  wasted. Keep working until `verify[]` passes or an `ESCALATE:` condition holds.
- **Check before you claim.** Never report a change as done without running the
  check that proves it. Run `verify[]` yourself; if a command cannot run here,
  say so in `concerns[]` instead of assuming it passes.
- **Solve the task, not the test.** Never hard-code expected values, branch on
  test-only state, special-case the inputs a test uses, or override equality to
  make an assertion pass. If a test or `verify[]` command looks wrong or
  contradicts the spec, reply `BLOCKED` with `test-assertion-suspect` and say
  why; do not work around it.
- **Only what was asked.** Do not add tests, docs, examples, helper scripts or
  config files the task did not ask for. Extra files outside `SCOPE_FILES` cost
  a review round and count against you.

## Package installs

Never invent a version number from memory. Use a bare `pnpm add <pkg>` (or the
project's package manager, or `pip install`, `cargo add`, `go get`) so it
resolves to the registry's latest. Pin only when the task asks for it or a peer
constraint forces it. A dependency the task did not name is a Tier-4 deviation:
stop and escalate rather than adding it.

## Mock policy (non-negotiable)

- Never `vi.mock` / `jest.mock` / `unittest.mock.patch` / `Mockito.mock` a
  module under `src/`. Mock true externals only: network, clock, randomness,
  third-party SDKs, paid APIs.
- Use the project's emulator or test double where one exists rather than
  inventing a stub.
- A test that passes only because the thing it tests was mocked out is a
  failing test that has not noticed yet. If the real implementation cannot be
  exercised, reply `BLOCKED` with `oracle-underivable` rather than mocking past it.
- No placeholder returns, TODO stubs or empty handlers in production code.
