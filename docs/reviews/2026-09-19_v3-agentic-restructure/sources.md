# Sources

Fetched 2026-09-18 and 2026-09-19 unless noted. Platform pages are the versions published for Claude Code 2.1.277. Items marked (validation) were fetched on 2026-09-19 for the validation round.

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
- Anthropic 2026 agentic trends report (Mar 3, 2026). The "95% of tasks" line attributed to it appears only in secondary posts and could not be verified in the PDF; the ≈7× figure is taken from the costs documentation instead (validation).
- anthropics/cwc-long-running-agents (Code with Claude 2026 take-home: `test-results.json` with `passes: false` default, `verify-gate.sh` PreToolUse hook, evaluator with no Write/Edit, `/goal` as the built-in path) (validation).
- "Harness design for long-running apps" (Mar 24, 2026): the sprint-decomposition layer removed for Opus 4.6 (validation).
- Anthropic Product Design blog on autonomous loops (write, test, iterate).

## Field harnesses and methods

- obra/superpowers SDD (v6.4.1, Sep 19, 2026): `progress.md` ledger, implementer status enum, rounds 1–3 resume the implementer, 4–5 fresh one tier up, adjudicate at 5, reviewer returns spec-compliance and quality verdicts, "cannot verify from diff", `git merge-base origin/main HEAD` review base (validation).
- HumanLayer "Advanced Context Engineering for Coding Agents" and "Why Software Factories Fail" (wsff.md): compact status into the plan, keep 40–60% context, humans steer the pre-code phases (validation).
- compound-engineering (v3.26.3, Sep 15, 2026: Goal Capsule, review depth by consequence, cross-model peer verification, report-only review) (validation); OpenSpec (archive finished changes); brainstorm skill (spike / bounded / architectural classification); Anthropic feature-dev plugin (four human gates) (validation).
- multica-ai/andrej-karpathy-skills (clarification gate; MIT).
- hookify (project-authored markdown guard rules); claude-security plugin (verified SARIF findings).

## Evidence

- SpecBench (arXiv 2605.21384, May 2026): visible-test saturation vs held-out failure, gap vs code size.
- "Building to the Test" (arXiv 2606.28430, Jun 2026); "Hardening Agent Benchmarks with Hacker-Fixer Loops" (2606.08960); "Capped Evaluation with Randomized Tests" (2606.07379); SpecPath (2608.09799, Aug 2026); "Coding Agents as Test-Suite Auditors" (2608.01715) (validation).
- "Rethinking the Value of Agent-Generated Tests" (arXiv 2602.07900 v2, Apr 2026): agent-written tests are mostly diagnostics, not assertions (validation).
- "Over-mocked" (Hora & Robbes, MSR 2026, arXiv 2602.00409; 1.2M commits, 36% vs 26%); practitioner follow-up (codex.danielvaughan.com, Jun 30, 2026): one config-file sentence drove agent mock-adds to near zero (validation).
- Merge-conflict study of 33,596 agent pull requests (arXiv 2607.04697 v2; cross-agent 41.7% vs intra-agent 19.8%; 42% structural); AgenticFlict (2604.03551, 142k PRs, 27.67%); AgentRoom (2608.23740, Aug 2026: coordination, not parallelism, carries the gain) (validation).
- TDAD (arXiv 2603.17973 v2): graph-based test impact analysis, 6.08% → 1.82% regressions on small open-weight models; "Deterministic Anchoring" (2606.26979) (validation).
- Context-rot studies; "Governance Decay" (arXiv 2606.22528 v2, Jun 27, 2026: 0% → 30–59% violations after compaction, 0% with constraint pinning); HANDBOOK.md (2607.25398, Jul 2026) (validation).
- SWRBench (arXiv 2509.01494): agreement across independent review runs separates real issues from hallucinations.
- Skill-harnessing reference architecture (arXiv 2606.20631): verifiable skill contract, run-scoped provenance, eligibility gate.
- OWASP Top 10 for Agentic Applications (Dec 2025): ASI04 supply chain, ASI05 unexpected code execution, ASI06 memory poisoning, kill switches; OWASP 2026 LLM Top 10 and Agent Control Standard (Sep 2, 2026) (validation).
- Plugin4Shell (The Hacker News, Sep 18, 2026): hash-shaped branch names swap a SHA-pinned plugin; fixed in Claude Code 2.1.179 (validation). SentinelOne marketplace-skill dependency hijack (Jan 6, 2026); Mend "Shai Hulud" SessionStart-hook worm (validation).
- RepoComplianceBench (arXiv 2607.26819, Jul 2026): agents rarely retrieve contribution rules on their own (validation).

## Prior blitz reviews

- `docs/reviews/2026-09-18_cc-2.1.276-alignment/` (2.5.0): session records, Stop gate, TIA, evals, cloud posture.
- `docs/consolidation/review-audit/effectiveness-research.md`: two-lane detection, aggregation, self-critique paradox.
