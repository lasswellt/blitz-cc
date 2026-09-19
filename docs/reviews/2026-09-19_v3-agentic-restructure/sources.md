# Sources

Fetched 2026-09-18 and 2026-09-19 unless noted. Platform pages are the versions published for Claude Code 2.1.277.

## Claude Code documentation (code.claude.com/docs/en/…)

| Page | Used for |
|---|---|
| `plugins`, `plugins-reference`, `plugin-marketplaces` | plugin anatomy, `compat.json`, marketplace install and pinning |
| `skills`, `sub-agents`, `hooks`, `hooks-guide` | frontmatter fields, `disable-model-invocation` dispatch rule, hook events and exit codes, `Bash\|PowerShell` matcher, bash requirement on Windows, prompt and agent hook types |
| `workflows`, `plugin-evals`, `skill-doctor` | `workflows/*.js` contract, `claude plugin eval` flags and ablation arms, description budget |
| `common-workflows` (`/verify`, `/goal`, `/loop`, `/batch`, `/code-review`, `/security-review`) | bundled user-only skills, `/goal` as a prompt-type Stop hook, `/loop` self-paced end via `ScheduleWakeup stop:true`, `.claude/loop.md` |
| `worktrees`, `agent-view`, `cross-session-messaging` | `worktree.baseRef`, platform-owned worktree lifecycle, `claude agents --json`, messaging token line |
| `routines`, `projects`, `channels`, `remote-control` | Routines minimum interval and fresh clone, Projects coordinator and threads, channel relay of permission prompts, `-p` disables `AskUserQuestion` |
| `monitoring-usage` (OpenTelemetry), `costs`, `model-config` | exported attributes, `/usage` and `/insights`, `subagentPromptCacheTtl`, Task tools gate on Claude 5 models |
| `github-actions`, `code-review` | `claude-code-action` with `plugin_marketplaces`/`plugins`, `/plugin:skill` prompts, inline-comment tool, `REVIEW.md` and `CLAUDE.md` in hosted review |
| `changelog` (2.1.158 → 2.1.277) | removals (`TeamCreate`, `Monitor persistent`), additions |

## Anthropic engineering and research

- "Effective harnesses for long-running agents" and the Code with Claude 2026 take-home write-up (feature-list JSON, one task per session, structural done, re-simplification).
- "Building agents with the Claude Agent SDK"; "Claude Code best practices" (CLAUDE.md ≤200 lines, no procedural instructions).
- Anthropic 2026 agentic trends report (multi-agent economics, ~7× tokens for agent teams).
- Anthropic Product Design blog on autonomous loops (write, test, iterate).

## Field harnesses and methods

- obra/superpowers SDD: `progress.md` ledger, implementer status enum, two-stage review, fix-loop ceiling, no parallel implementers.
- HumanLayer "Advanced Context Engineering for Coding Agents": compact status into the plan, keep 40–60% context, humans review research and plans.
- compound-engineering (`docs/plans`, `docs/solutions`); OpenSpec (archive finished changes); brainstorm skill (spike / bounded / architectural classification).
- multica-ai/andrej-karpathy-skills (clarification gate; MIT).
- hookify (project-authored markdown guard rules); claude-security plugin (verified SARIF findings).

## Evidence

- SpecBench (2026): visible-test saturation vs held-out failure, gap vs code size.
- "Over-mocked: mocking in agent-authored commits" (1.2M commits, 36% vs 26%).
- Merge-conflict study of 33,596 agent pull requests (cross-agent 41.7% vs intra-agent 19.8%; 42% structural).
- TDAD: graph-based test impact analysis, ~70% fewer regressions.
- Context-rot studies (every model degrades with length; compaction erases constraints).
- SWRBench (arXiv 2509.01494): agreement across independent review runs separates real issues from hallucinations.
- Skill-harnessing reference architecture (arXiv 2606.20631): verifiable skill contract, run-scoped provenance, eligibility gate.
- OWASP Top 10 for Agentic Applications 2026: ASI04 supply chain, ASI05 unexpected code execution, ASI06 memory poisoning, kill switches.

## Prior blitz reviews

- `docs/reviews/2026-09-18_cc-2.1.276-alignment/` (2.5.0): session records, Stop gate, TIA, evals, cloud posture.
- `docs/consolidation/review-audit/effectiveness-research.md`: two-lane detection, aggregation, self-critique paradox.
