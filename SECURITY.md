# Security

**Installing blitz means running its bash hooks with your user privileges on every tool call, outside Claude Code's sandbox.** Read this before installing it, and read the diff before upgrading it.

## Reporting a vulnerability

Report privately through GitHub's private vulnerability reporting on [lasswellt/blitz-cc](https://github.com/lasswellt/blitz-cc/security). Do not open a public issue for a vulnerability. Fixes ship in the next patch release, and the CHANGELOG entry credits the reporter unless they ask otherwise. Only the latest minor release is supported.

## What runs, where, and with what authority

| Component | Runs as | When | Boundary |
|---|---|---|---|
| Bash hooks (`hooks/scripts/*.sh`, wired in `hooks/hooks.json`) | you, unsandboxed | every matching tool call, session and turn event | Blocking guards fail closed (`onFailure: "block"`, jq/parse check); advisory hooks fail open. `scripts/skill-scan.sh` keeps network calls out of them. |
| Skill and agent `!` lines | you, at skill or agent load | when the skill or agent loads | Must be local and read-only from an allow-list; CI fails on anything else (`scripts/skill-scan.sh`), and Cisco's offline `skill-scanner` 2.2.2 gates every skill at HIGH. |
| Plugin agents (`agents/*.md`) | Claude Code subagents | when a skill spawns them | Their `tools:` lists; critics are read-only and run without the project's `CLAUDE.md` (`omitClaudeMd`). |
| Workflow scripts (`workflows/*.js`) | Claude Code's workflow sandbox | `build --parallel`, `check`, `audit` | No filesystem, network or clock; they only dispatch agents. |
| External critic (`hooks/scripts/critic-external.sh`) | you, calling a vendor CLI | only when `BLITZ_CRITIC_PROVIDER`, `BLITZ_CRITIC_PANEL` or `BLITZ_DUAL_CRITIC` is set | **Sends your diff to that vendor's cloud.** Secret-shaped lines and secret-file hunks are redacted first; no approval-bypass flag is ever passed (bats-enforced); its REJECTs block only once the in-Claude critic reproduces them. |
| `blitz-guard` mod (`mods/blitz-guard`, optional, separate install) | unsandboxed JavaScript in Claude Code's process | agent spawns, permission checks, `tasks.sh` calls | Adds checks; never the only guard. Switched off by `--bare`, `--safe-mode` and `disableAllHooks`. |

## Pre-approved tools per skill

A skill's `allowed-tools` lets Claude Code run matching calls without asking while the skill is active; anything else still prompts. Blitz grants broad shell and file writes only to skills that must run a project's own commands unattended:

| Skills | Pre-approved | Why |
|---|---|---|
| `build`, `check`, `next`, `ship`, `migrate`, `refactor`, `test-gen`, `ui-build`, `perf-profile`, `dep-health`, `audit` | `Bash`, `Write`, `Edit` (plus `WebSearch`/`WebFetch` for `migrate` and `dep-health`, which look up release notes and advisories) | They run the project's type-check, tests, builds and `verify[]` commands, whose names differ per project, and `next --loop` runs them with no one at the keyboard. The anti-shortcut hooks and the kill switch apply to every one of those calls. |
| `research` | read tools, `WebSearch`, `WebFetch`, writes to `docs/research/**`, the plugin's `detect-stack.sh` | Searching and fetching sources is the skill; it cannot know the domains in advance. |
| `plan`, `onboard` | read tools, writes to `docs/plans/**` (`onboard`: `docs/**` and `CLAUDE.md`), the plugin's `tasks.sh` and `detect-stack.sh` | Everything else prompts. |
| `doc-gen`, `learn`, `todo`, `ui-audit` | read tools, writes scoped to the directory each owns (`docs/generated/**`, `docs/solutions/**`, `docs/plans/**`, `docs/crawls/**` and `DESIGN.md`); `learn` also reads `git log`/`git diff` | Everything else prompts. |
| `doctor`, `sessions`, `browse` | read tools and the plugin's own scripts (`doctor` may also edit `.claude/settings.json`, `.gitignore`, `.worktreeinclude`, `.claude/loop.md`) | Everything else prompts. |

`next` and `ship` may start only the blitz skills they dispatch (`Skill(blitz:build)`, `Skill(blitz:check)`, `Skill(blitz:learn)`), not any skill.

## Threat model

Blitz treats everything a cloned repository controls as data, not instructions. Five trust boundaries carry that rule; the full enforcement table is in [skills/_shared/security.md](skills/_shared/security.md) and [security.reference.md](skills/_shared/security.reference.md). Mapped to the [OWASP Top 10 for Agentic Applications (2026)](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026):

| Risk (OWASP ASI) | Where it enters blitz | Control | Residual risk |
|---|---|---|---|
| ASI01 Goal and plan hijack | repo files, `CLAUDE.md`, fetched pages (TB-1, TB-4) | Repo state parsed as data; critics run without `CLAUDE.md`; fetched content classified before use | Prompt injection has no complete mitigation; a model can still be steered by text it reads |
| ASI02 Tool misuse | the agent's own Bash and edit calls | Anti-shortcut guards (`block-*`, `tasks-guard`, `pre-edit-guard`), kill switch, auto mode's classifier | Guards match command text; `sh -c`, variables and path tricks can slip past them |
| ASI04 Agentic supply chain | plugin install and upgrade, skills, marketplaces | GitHub-hosted marketplace; `skill-scan.sh` and Cisco `skill-scanner` (offline, pinned) in CI; floor ≥2.1.296 includes the Plugin4Shell fix (2.1.179). Snyk Agent Scan is not used: its `scan` uploads skill content to Snyk's API | Installing any plugin trusts its author; pin versions and keep auto-update off |
| ASI05 Unexpected code execution | hooks, `!` lines, `verify[]` commands, held-out checks | `!` allow-list; `verify[]` runs only through `scripts/tasks.sh`; hooks reviewed and bats-tested | `verify[]` commands are code the plan author wrote; review plans from untrusted sources before `build` |
| ASI06 Memory and context poisoning | `.cc-sessions/`, `tasks.json`, `progress.md`, `docs/solutions/` (TB-1, TB-2) | `startup-validate.sh` shape and injection scan with quarantine; 200-char echo caps; safe-character filters on ledgers | The injection regex is a tripwire, not a proof; treat a cloned repo's `.cc-sessions/` as attacker-controlled |
| ASI07 Insecure inter-agent communication | subagent replies, external critic output, `SendMessage` and mailbox (TB-3, TB-5) | Replies validated with `jq`, capped, `source_trust` marked; external claims reproduced before they count | A subagent that read untrusted input is a conduit for it |
| ASI08 Cascading failures | unattended `next --loop`, parallel waves | Loop circuit breaker, Stop gate caps, per-tick budgets, wave cap of 4, sequential merge with `merge-tree` preflight | A loop with a generous budget still spends it |
| ASI09 Human-agent trust exploitation | "done" and "tests pass" claims | Script-only task status; verify after the last edit; fresh-context critic; held-out checks | A critic can be wrong; the eval suite measures how often |
| ASI10 Rogue agents | any agent running unattended | `touch .cc-sessions/STOP` denies every tool call; kill switch fails closed | Outside the repo, the kill switch is only as good as the hooks being enabled |

## Install safely

1. Install from the GitHub marketplace: `/plugin marketplace add lasswellt/blitz-cc`, then `/plugin install blitz@blitz`.
2. Pin the version and leave auto-update off. Read the diff of `hooks/` and `scripts/` before every upgrade.
3. Install `jq`. Without it every blocking guard refuses every call, by design.
4. Install `blitz-guard` only if you want its extra checks, and only after reading `mods/blitz-guard/hooks/`.

## Hardened profile for unattended runs

For `next --loop` under a Routine, `claude -p` or a long `/loop`, add to the project's `.claude/settings.json` (key names as of Claude Code 2.1.296; check `/config` on newer versions):

```json
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "allowUnsandboxedCommands": false
  },
  "permissions": {
    "blockReadsOutsideWorkingDirectories": true
  }
}
```

The sandbox covers Bash only: hooks, MCP servers and mods run outside it. Keep the sandbox's network allow-list narrow; a broad domain such as `github.com` is an exfiltration path. Leave the external critic unset on repositories whose code may not leave the machine. Native Windows needs Git Bash or WSL2: a bash hook that cannot start fails open there unless it is one of the blocking guards.
