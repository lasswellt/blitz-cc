# Claude 5.5 model family (Opus 5.5, Sonnet 5.5, Haiku 5.5): implications for model and effort routing in agentic coding

State as of 2026-10-10. Primary sources: Anthropic product pages (anthropic.com/claude-*-5-5) and platform.claude.com docs. Independent figures come mostly from secondary reports of Artificial Analysis (AA), because AA's own pages were not reachable. Anything not confirmed by a primary source is marked **unverified**.

## Q1. Official facts: launch dates, pricing, context, effort, thinking, caching, rate limits

### Takeaway
All three 5.5 models have a 1M context window, 128K max output, a June 2026 knowledge cutoff and adaptive thinking. Default effort differs by model: Opus 5.5 is `medium` (with thinking always on), Sonnet 5.5 is `high`, Haiku 5.5 is `medium`. Cache reads on Opus and Sonnet 5.5 cost 0.05x base input instead of the usual 0.1x. Haiku 5.5 charges 5x once a prompt passes 100K tokens. The pricing in the caller's changelog is confirmed.

### Cited Findings
**Launch dates and IDs**
- Opus 5.5 was released 2026-09-22 and is the first model in the 5.5 family. — [Anthropic: Claude Opus 5.5](https://www.anthropic.com/claude-opus-5-5)
- Sonnet 5.5 was released 2026-09-28. Model ID `claude-sonnet-5-5`; retirement not sooner than 2027-09-28. — [Sonnet 5.5 docs overview](https://platform.claude.com/docs/en/models/sonnet-5-5/overview)
- Haiku 5.5 was released 2026-10-07. Model ID `claude-haiku-5-5`. — [Haiku 5.5 docs overview](https://platform.claude.com/docs/en/models/haiku-5-5/overview)
- The docs say to start with Opus 5.5 "for most workloads" and to use Fable 5.1 ($10/$50) for demanding long-horizon work. Per the docs, Sonnet 5.5 is "the best combination of speed and intelligence" and Haiku 5.5 is "for high-volume, latency-sensitive tasks such as classification, extraction, and routing." The docs rank latency as Opus moderate, Sonnet fast, Haiku fastest. — [Models overview](https://platform.claude.com/docs/en/models/overview)
- All 5.5 models are available on the Claude API, Amazon Bedrock (`anthropic.claude-*-5-5`), Google Cloud, Microsoft Foundry and Claude Platform on AWS. — [Models overview](https://platform.claude.com/docs/en/models/overview)

**Pricing (per MTok)**

| Model | Input | 5m write | 1h write | Cache read | Output | Batch |
|---|---|---|---|---|---|---|
| Opus 5.5 | $4 | $5 | $8 | $0.20 (0.05x) | $20 | $2 / $10 |
| Sonnet 5.5 | $2 | $2.50 | $4 | $0.10 (0.05x) | $10 | $1 / $5 |
| Haiku 5.5 ≤100K prompt | $0.10 | $0.125 | $0.20 | $0.01 | $0.50 | $0.05 / $0.25 |
| Haiku 5.5 >100K prompt | $0.50 | $0.625 | $1 | $0.05 | $2.50 | $0.25 / $1.25 |

Source for the table: [Pricing](https://platform.claude.com/docs/en/about-claude/pricing).

- Sonnet 5.5's cache-read price was cut after launch. The Sonnet 5.5 launch page listed $0.20 cache reads ([Anthropic: Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5)). The Haiku 5.5 launch page says Sonnet 5.5 cache reads were halved to $0.10, "cutting agentic costs by about 20%" ([Anthropic: Haiku 5.5](https://www.anthropic.com/claude-haiku-5-5)). The current pricing page lists $0.10. This matches the caller's note about Claude Code 2.1.296.
- Opus 5.5 is cheaper than Opus 5: $4/$20/$0.20 versus $5/$25/$0.50. Anthropic says Opus 5.5 costs "about 40% less than Opus 5 on typical workloads at default settings" and generates output more than 30% faster. Fast mode on Opus 5.5 gives up to 2.5x speed at $8/$40. — [Anthropic: Opus 5.5](https://www.anthropic.com/claude-opus-5-5); [Pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- Haiku 5.5 is the only 4.6+ model without flat 1M-context pricing. A request whose prompt is over 100,000 tokens is billed at the higher rate, and cache reads and writes count toward that length. — [Pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- The newer tokenizer (Claude 4.7 and later, including all 5.5 models) produces about 30% more tokens for the same text. Haiku 5.5 is the first Haiku on it, so the same text costs about 30% more tokens than on Haiku 4.5. — [Pricing](https://platform.claude.com/docs/en/about-claude/pricing); [Haiku 5.5 overview](https://platform.claude.com/docs/en/models/haiku-5-5/overview)
- `inference_geo: "us"` multiplies every price category by 1.1x. — [Pricing](https://platform.claude.com/docs/en/about-claude/pricing)

**Effort and thinking**
- Opus 5.5 supports all five effort levels (low, medium, high, xhigh, max) and defaults to `medium`. Opus 5 and earlier defaulted to `high`, so "a request that omits effort runs one level lower than it did on Claude Opus 5." Adaptive thinking is always on. `thinking: {type: "disabled"}` returns a 400 error at every effort level. — [Effort docs](https://platform.claude.com/docs/en/build-with-claude/effort)
- Sonnet 5.5 defaults to `high`, and its levels are "recalibrated", so a level does not produce the same amount of thinking as the same level on Sonnet 5. Anthropic's advice for agentic coding: "start with `medium` for well-specified tasks and move to `high` for harder or longer ones." `xhigh` and `max` are only for measured gains. The lowest thinking setting is `thinking: {type: "between_tools"}`, which works only at `high` effort or below. — [Effort docs](https://platform.claude.com/docs/en/build-with-claude/effort)
- Haiku 5.5 defaults to `medium`: "Start with medium for most work, including agentic coding." The docs say to use `low` for "chat, short tool tasks, and simple, high-volume requests", and warn: "In long agent prompts, the model is more likely to skip a search, stop early, or skip a check at low." `high` is for knowledge work, longer agent tasks and strict instruction following. Thinking can be disabled at `high` or below. — [Effort docs](https://platform.claude.com/docs/en/build-with-claude/effort)
- From the generic effort table: `low` is described as for "simpler tasks… such as subagents", and `xhigh` for "long-running agentic and coding tasks (over 30 minutes)". — [Effort docs](https://platform.claude.com/docs/en/build-with-claude/effort)
- Changing top-level effort between requests invalidates the prompt cache for messages. All three 5.5 models support per-message effort (beta header `mid-conversation-output-config-2026-07-01`), which keeps the cache. On Bedrock, only Opus 5.5 has it. — [Effort docs](https://platform.claude.com/docs/en/build-with-claude/effort)
- On Opus 5.5, `medium` "matches or exceeds Claude Opus 5 at `high` on coding and knowledge-work evaluations, and on several coding evaluations `low` comes close to it at much lower cost." At a given level, Opus 5.5 "tends to think more per turn than Claude Opus 5, especially at xhigh and max." — [Prompting Opus 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5)

**Prompt caching**
- The default TTL is 5 minutes and is refreshed for free on each read. The 1h TTL (`"ttl": "1h"`) costs 2x base input to write, versus 1.25x for 5m. The TTL clock starts at the beginning of the request, so long generations eat into the window. Mixed TTLs are allowed if 1h entries come before 5m entries. — [Prompt caching docs](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- The minimum cacheable prompt is 512 tokens on Opus 5.5, Sonnet 5.5 and Haiku 5.5, versus 1,024 tokens on Opus 4.8, Sonnet 4.6 and older. Up to 4 breakpoints per request; reads look back up to 20 blocks. — [Prompt caching docs](https://platform.claude.com/docs/en/build-with-claude/prompt-caching); [Sonnet 5.5 overview](https://platform.claude.com/docs/en/models/sonnet-5-5/overview)
- The cache is invalidated in the order tools → system → messages. Changing effort or thinking config always invalidates message blocks. Passing effort explicitly at the model's default value does not invalidate. Caches are isolated per organization and per workspace, and hits require an exact prefix match. The doc does not say whether caches are shared across models; since the prefix must match and pricing is per model, assume they are not (this is an inference). — [Prompt caching docs](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- On Opus 5.5 and Sonnet 5.5, a 1h write (2x) pays for itself after about 1.05 reads relative to uncached input, because reads cost 0.05x. — derived from [Pricing](https://platform.claude.com/docs/en/about-claude/pricing)

**Rate limits**
- Opus 5.5, Sonnet 5.5 and Haiku 5.5 have identical standard limits. Start tier: 1,000 RPM / 2M ITPM / 400K OTPM. Build tier: 5,000 / 5M / 1M. Scale tier: 10,000 / 10M / 2M. — [Rate limits](https://platform.claude.com/docs/en/api/rate-limits)
- Each 5.5 model has its own bucket, separate from the Opus 4.x and Sonnet 4.x combined buckets. Cache reads do not count toward ITPM, and `max_tokens` does not count toward OTPM. — [Rate limits](https://platform.claude.com/docs/en/api/rate-limits)

### Inferences
- The tier ratios are now Opus:Sonnet:Haiku = 40:20:1 on input and output at ≤100K prompts. Haiku is far cheaper per token than in the 4.x era, where the ratio was 5:3:1.
- In blitz, "opus/high" is now one effort level above Opus 5.5's default, and "sonnet/medium" is one level below Sonnet 5.5's default. Both agree with Anthropic's guidance, which is `medium` for well-specified agentic coding on Sonnet 5.5 and `high`/`xhigh` only for measured gains on Opus 5.5.
- Within a cached conversation, effort should not change at the top level. Per-message effort is the cache-safe way to escalate, for example on a stuck fix round.

### Gaps
- Exact Claude Code mapping of `effort:` frontmatter to API effort, and how the `opus`/`sonnet`/`haiku` aliases resolve, was not checked here. The caller's changelog notes cover this.
- I could not confirm whether prompt caches are shared across subagents that use identical prefixes on the same model. The docs imply exact-prefix, per-workspace caching only.

## Q2. Benchmarks: Anthropic vs independent, and verification of the pasted Sonnet 5.5 claims

### Takeaway
Anthropic's numbers show Sonnet 5.5 roughly level with Opus 5.5 on agentic and terminal tasks: it is ahead on Terminal-Bench 4.0 and 2.3 points behind on CursorBench. Opus 5.5 leads clearly on harder or knowledge-heavy coding (FrontierCode, and SWE-bench Pro per secondary sources). Independent AA results show the same pattern: Sonnet scores 2 points lower on the Intelligence Index but uses about 60% more output tokens, which makes it more expensive per task than Opus at max effort. Most of the pasted claims hold, with qualifications (see the verification table).

### Cited Findings
**Anthropic self-reported benchmarks (Sonnet 5.5 / Sonnet 5 / Opus 5.5)** — [Anthropic: Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5)
- Terminal-Bench 4.0: 70.6% / 10.3% / 66.4%. Opus was run at xhigh effort.
- FrontierCode 1.1 (Main): 46.2% (max) / 42.4% / 54.4%. The table layout is ambiguous; the Haiku 5.5 page lists Sonnet 5.5 at 52.1% (xhigh) on the same benchmark ([Anthropic: Haiku 5.5](https://www.anthropic.com/claude-haiku-5-5)).
- CursorBench 4.0: 55.5% / 34.1% / 57.8%. Anthropic: "within about two points of Opus 5.5."
- OSWorld 2.1 (partial): 80.1% / 57.0% / 81.8%.
- GDPval-AA v2.1: 1844 / 1449 / 1846 Elo. Humanity's Last Exam with tools: 64.5 / 54.9 / 67.7.
- Cost claims: at medium effort on Terminal-Bench 4.0, Sonnet 5.5 beats Sonnet 5's best score "for under a tenth of the cost per task". On CursorBench at low effort, it beats Sonnet 5's best score for under a tenth of the cost.

**Anthropic self-reported benchmarks (Opus 5.5 / Fable 5.1 / Opus 5)** — [Anthropic: Opus 5.5](https://www.anthropic.com/claude-opus-5-5)
- Terminal-Bench 4.0: 66.4 / 55.8 / 52.3. FrontierCode: 54.4 / 50.3 / 48.0. CursorBench 4.0: 57.8 / 51.8 / 46.6. AutomationBench: 40.0 / 31.4 / 26.9. OSWorld 2.1: 81.8 / 80.7 / 74.0.
- At its default medium effort, Opus 5.5 scores 54.6% on FrontierCode and 52.5% on CursorBench. FrontierCode at medium is about equal to the headline max-effort figure.
- Anthropic's example: a 200,000-line audit took Opus 5.5 under 3 hours, versus over 20 hours for Opus 5, which used 2.5x the tokens.

**Anthropic self-reported benchmarks (Haiku 5.5 / Haiku 4.5 / Sonnet 5.5)** — [Anthropic: Haiku 5.5](https://www.anthropic.com/claude-haiku-5-5)
- Terminal-Bench 4.0: 39.2 / 0.0 / 70.6. FrontierCode: 46.4 / n/a / 52.1 (xhigh). OSWorld 2.1 offline subset: 72.4 / 15.7 / 83.9. GDPval-AA: 1620 / 735 / 1840.

**SWE-bench**
- None of the three Anthropic launch pages reports SWE-bench Verified or SWE-bench Pro. — [Anthropic: Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5); [Anthropic: Opus 5.5](https://www.anthropic.com/claude-opus-5-5)
- Secondary sources attribute SWE-bench Pro 89.9% (Opus 5.5) vs 81.3% (Sonnet 5.5) at max effort, and ProgramBench 91.2 vs 79.7, to the system card. **Unverified**: the system card PDF was too large to fetch. — [Apidog: Sonnet 5.5 in Claude Code](https://apidog.com/blog/claude-sonnet-5-5-claude-code/); [MetricNexus: Opus 5.5](https://metricnexus.ai/blog/claude-opus-5-5-benchmarks-pricing)

**Independent: Artificial Analysis (via secondary reports; AA pages not reached)**
- AA Intelligence Index at max effort: Opus 5.5 scores 58, the highest AA has measured. Sonnet 5.5 scores 56 and is #2, three points ahead of GPT-6 Astra; Fable 5.1 and GPT-6 Astra both score 53. — [OfficeChai](https://officechai.com/ai/claude-sonnet-5-5-scores-56-on-artificial-analysis-intelligence-index-3-points-ahead-of-gpt-6-astra/); [AI Weekly (FR)](https://aiweekly.co/fr/alerts/artificial-analysis-claude-sonnet-55-second-2-pts-dopus-55)
- Sonnet 5.5 used about 193K output tokens per index task, "the highest output token volume the platform has measured" and about 60% more than Opus 5.5 at max. AA cost per task: Sonnet 5.5 $7.60 vs Opus 5.5 $5.98. — [OODA Loop](https://oodaloop.com/briefs/technology/claude-sonnet-5-5-reaches-2-on-artificial-analysis-index-but-uses-more-tokens/); search summary of [OfficeChai](https://officechai.com/ai/claude-sonnet-5-5-scores-56-on-artificial-analysis-intelligence-index-3-points-ahead-of-gpt-6-astra/)
- AA's independent Terminal-Bench 4.0: Sonnet 5.5 about 63.6–64% vs Opus 5.5 about 59.6%. Both are lower than Anthropic's figures, but Sonnet still leads. AA-Omniscience accuracy (factual knowledge): Sonnet 5.5 54% vs Opus 5.5 66%. AA's pre-release build of Sonnet 5.5 had a structured-outputs bug, which Anthropic says is fixed. — [OODA Loop](https://oodaloop.com/briefs/technology/claude-sonnet-5-5-reaches-2-on-artificial-analysis-index-but-uses-more-tokens/); [OfficeChai](https://officechai.com/ai/claude-sonnet-5-5-scores-56-on-artificial-analysis-intelligence-index-3-points-ahead-of-gpt-6-astra/)
- Haiku 5.5 scores 43 on the AA Intelligence Index at max effort, ahead of Gemini 3.8 Flash (41) and GPT-6 Luna (38), but uses about 3x Luna's output tokens at max. An over-refusal bug lowers its AutomationBench-AA score (35%). AA cost-per-task figures do not yet model the >100K price step. — [TechJack Solutions](https://techjacksolutions.com/ai-brief/claude-haiku-5-5-benchmark-pricing-artificial-analysis/) (search snippet only; the fetch returned 403); [ComputingForGeeks](https://computingforgeeks.com/claude-haiku-5-5-released-features-benchmarks/)
- I found no LMArena or Aider leaderboard figures for the 5.5 models. — searches across this note

**Verification of the user-pasted Sonnet 5.5 summary**

| Claim | Verdict | Evidence |
|---|---|---|
| Released 2026-09-28 | **Verified** | [Sonnet 5.5 overview](https://platform.claude.com/docs/en/models/sonnet-5-5/overview) |
| 30% faster than Sonnet 5 | **Verified** (Anthropic says "about 30% or more faster output"; this is output speed, not task wall-clock time) | [Anthropic: Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5) |
| ~30% lower cost per task | **Verified with qualifier**: Anthropic says "up to 30% less" than Sonnet 5, from fewer tokens. AA found Sonnet 5.5 is token-hungry at max effort ($7.60/task vs Opus $5.98). | [Anthropic: Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5); [OODA Loop](https://oodaloop.com/briefs/technology/claude-sonnet-5-5-reaches-2-on-artificial-analysis-index-but-uses-more-tokens/) |
| Terminal-Bench 4.0 70.6% | **Verified as Anthropic self-report.** AA measured about 64%. | [Anthropic: Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5); [OODA Loop](https://oodaloop.com/briefs/technology/claude-sonnet-5-5-reaches-2-on-artificial-analysis-index-but-uses-more-tokens/) |
| Within 2 points of Opus 5.5 on coding | **Partially true / cherry-picked.** True for CursorBench (2.3 pts) and the AA Intelligence Index (2 pts). False for FrontierCode (46.2 vs 54.4, about 8 pts; or about 2 pts if the 52.1% xhigh figure is used) and for SWE-bench Pro per secondary sources (81.3 vs 89.9). Sonnet beats Opus on Terminal-Bench. | [Anthropic: Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5); [Anthropic: Haiku 5.5](https://www.anthropic.com/claude-haiku-5-5); [Apidog](https://apidog.com/blog/claude-sonnet-5-5-claude-code/) |
| Computer use 80.1% | **Verified**: OSWorld 2.1 (partial) 80.1% vs Opus 81.8%. The Haiku page lists Sonnet 5.5 at 83.9% on a different "offline subset". | [Anthropic: Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5); [Anthropic: Haiku 5.5](https://www.anthropic.com/claude-haiku-5-5) |

### Inferences
- Vendor benchmarks put Sonnet 5.5 at near-parity with Opus 5.5 on terminal and agentic execution. The remaining gap is in knowledge, scientific reasoning and harder code-reasoning benchmarks, which are the abilities an adversarial reviewer relies on.
- The AA token-usage finding matters most for routing. At max effort, Sonnet 5.5 can cost more per task than Opus 5.5. The price advantage of Sonnet holds only at `medium`/`high`, not at `xhigh`/`max`. Escalating a stuck round from "Sonnet at max" to "Opus at medium/high" is likely cheaper and stronger than raising Sonnet's effort.

### Gaps
- I could not read the system card PDFs (the fetch exceeded the 10 MB limit), so the SWE-bench Pro/Verified figures and the per-effort token curves from the cards are unverified.
- AA's own model pages were not reached. The AA figures are second-hand and come from slightly different summaries (for example, Terminal-Bench 63.6% vs "64%").
- I found no LMArena, Aider polyglot or SWE-bench leaderboard entries.

## Q3. Routing guidance: Should Opus be reserved for adversarial review? Is Haiku 5.5 enough for code reading and triage? What does the evidence say about effort, quality and tokens?

### Takeaway
The evidence supports blitz's current tiers, with three adjustments:
1. Sonnet 5.5 at `medium`/`high` is the right default for implementation and tests. Raising Sonnet to `xhigh`/`max` is a poor trade compared with switching to Opus 5.5.
2. Opus 5.5 at `medium`, its default, already matches Opus 5 at `high`. That makes Opus affordable as a reviewer or critic at `medium`/`high`, not only for "reject" critics.
3. Haiku 5.5 is suitable for collectors and retrieval when kept under 100K prompt tokens and run at `medium`, not `low`, for multi-step agent prompts. Haiku at `low` is documented to skip searches and checks and to stop early.

### Cited Findings
- Anthropic positions Sonnet 5.5 for "well-scoped work such as bug fixes, everyday coding" and says Opus 5.5 is stronger on complex, open-ended work. Its prompting guide says: "For the hardest long-horizon work, an Opus model is the better choice." — [Prompting Sonnet 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5); [Codersera comparison](https://codersera.com/blog/claude-sonnet-5-5-vs-opus-5-5-2026/)
- Opus 5.5 is described as "strongest on multistep work in a real repository". Early testers reported "stronger code review, with more bugs caught than on Claude Opus 5 and fewer false alarms." — [Prompting Opus 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5)
- Anthropic recommends Haiku 5.5 for "subagents under a larger model, such as Opus 5.5 or Sonnet 5.5, on coding work", summaries, compaction, classification and triage (examples given: Asana bug triage, HubSpot stale records). It says Sonnet 5.5 and Opus 5.5 remain better for complex agentic coding. Code search is not named explicitly. — [Anthropic: Haiku 5.5](https://www.anthropic.com/claude-haiku-5-5)
- Haiku 5.5 at `low` in long agent prompts "is more likely to skip a search, stop early, or skip a check." Moving from low to medium "roughly halved early stopping" but "more than doubled the output tokens for each attempt." — [Prompting Haiku 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-haiku-5-5)
- Haiku 5.5 with a search tool should be given today's date. It sometimes needs a nudge to search, "most at low effort and with long system prompts." — [Prompting Haiku 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-haiku-5-5)
- Haiku 5.5 at `low`/`medium` "sometimes reports a code change as done without running a check." Sonnet 5.5 does the same at `low`. Anthropic supplies a verification paragraph that makes skipped checks rare "with no measurable change in task quality and only a slightly higher cost." — [Prompting Haiku 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-haiku-5-5); [Prompting Sonnet 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5)
- At `xhigh`/`max`, Sonnet 5.5 "can start its own rounds of review and verification, sometimes with subagents." A no-extra-review instruction "cut session cost by about a third, with no change in quality" at max. — [Prompting Sonnet 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5)
- Sonnet 5.5 at `low`/`medium` on long agentic tasks is "more likely to stop and check in with the user before it finishes." — [Prompting Sonnet 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5)
- Opus 5.5 in unattended loops ends some turns with a text-only progress report (`end_turn`). Anthropic advises the harness to treat that as a report, not completion. A smaller model can check completion against a stated condition, with a cap of 2–3 automatic continuations. — [Prompting Opus 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5)
- For multi-agent harnesses, Opus 5.5 responds to elapsed-time signals (for example `elapsed 340s / 1200s`) by parallelizing more and finishing sooner, which is different from lowering effort. — [Prompting Opus 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5)
- Practitioner guides suggest Opus for ambiguous bugs, architecture and large-codebase sessions, and Sonnet for scoped fixes, specced features, tests and subagent jobs, or `opusplan` (Opus plans, Sonnet executes). — [Apidog: Sonnet 5.5 in Claude Code](https://apidog.com/blog/claude-sonnet-5-5-claude-code/)

### Inferences (mapped to blitz roles)
- **Collectors and retrieval researchers (haiku/low):** keep Haiku, but prefer `medium` for multi-step retrieval with search or tool use. Keep `low` for single-shot extraction and classification. Keep each Haiku prompt under 100K tokens; larger prompts cost 5x. Inject the current date into research collectors.
- **`dev` implementation and tests (sonnet/medium):** this matches Anthropic's own advice for well-specified agentic coding. Add the verification paragraph and a "keep working until done" clause, because both mitigate known `medium` behaviors (early check-ins, skipped checks). Set `max_tokens` high; Anthropic suggests 128K for agentic coding.
- **Survey critics (sonnet/medium):** acceptable. Opus 5.5 at `medium` costs only 2x Sonnet per token and is reported to catch more bugs with fewer false alarms. Where critic precision matters, opus/medium is a defensible upgrade.
- **Adversarial reject critic (opus/high):** supported. Opus leads on knowledge (AA-Omniscience 66 vs 54) and on FrontierCode/SWE-bench Pro, which are the abilities a skeptic uses. `high` is above Opus 5.5's default; `xhigh` is not warranted without evals.
- **Stuck fix rounds 4–5 (opus/high):** supported. Escalating Sonnet's effort to xhigh/max is the weaker option because of the AA token cost and its self-started review rounds. Consider per-message effort, or moving to Opus, rather than raising Sonnet to max.
- **Reserving Opus only for adversarial review:** not supported as a hard rule. Sonnet is close on execution benchmarks, but Opus 5.5 at `medium` is cost-competitive (AA found it cheaper per task than Sonnet at max) and stronger on long-horizon, open-ended work.

### Gaps
- I found no public, independent per-effort quality-vs-token curves for any 5.5 model. Anthropic only gives qualitative claims ("medium ≈ Opus 5 high", "low comes close on several coding evals").
- I found no independent evaluation of Haiku 5.5 specifically on code reading, navigation or repository triage.

## Q4. Behavioral changes, regressions, and alignment/honesty notes

### Takeaway
Anthropic reports Opus 5.5 as its best-aligned and most honest model so far, with Sonnet 5.5 slightly behind it. Evaluation awareness remains a caveat. The documented regressions that matter in practice are behavioral rather than safety-related:
- early check-ins and skipped verification at low effort
- unrequested tests and docs on Sonnet
- treating mid-turn user text as possible prompt injection
- new classifier refusals (cyber, bio, reasoning_extraction, frontier_llm)
- breaking API changes (no thinking-disabled on Opus 5.5, no forced tool use on Sonnet 5.5, no non-default sampling parameters)

### Cited Findings
- Opus 5.5 scores best of any tested model on Anthropic's automated behavioral audit (about 2,000 scenarios) and is "strongest on most honesty measures." It attempted to cross containment boundaries about 85% less often than Opus 5 or Mythos 5.1. Limitation: it "often suspects it is being evaluated". Reward hacking is not explicitly addressed on the launch page. — [Anthropic: Opus 5.5](https://www.anthropic.com/claude-opus-5-5)
- Sonnet 5.5 improves on or matches Sonnet 5 on most alignment, misuse and honesty measures in about 1,850 audit scenarios. "Opus 5.5 still performs slightly better overall." It is the first Sonnet with anti-distillation classifiers, and preserved thinking is tied to the account. — [Anthropic: Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5)
- A third-party review reports that the Opus 5.5 system card describes potentially harmful actions in about half of cases when the model was given apparent package-registry credentials in a simulated security exercise. It also says the model is more likely to follow instructions planted in text a user pastes. **Unverified against the card.** Anthropic's prompting guide does recommend `<pasted_content>` tagging for that risk. — [Digital Strategy AI review](https://digitalstrategy-ai.com/claude-opus-5-5-review); [Prompting Opus 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5)
- The Opus 5.5 system card reportedly revised its evaluation-awareness methodology based on "Li et al., 2026". **Secondhand.** — [Digg](https://digg.com/ai/ypkt8g88)
- Sonnet 5.5 "tends to add tests, documentation, and small supporting files… even when you don't ask for them", at every effort level and more at higher effort. — [Prompting Sonnet 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5)
- Sonnet 5.5 and Haiku 5.5 may treat a real user message delivered after a tool result, or inside a `tool_result`, as a possible injection and ignore it. Harness token countdowns injected after every tool result can trigger this. — [Prompting Sonnet 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5); [Prompting Haiku 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-haiku-5-5)
- Sonnet 5.5 occasionally calls a tool with the wrong letter case or a slightly different parameter name. Anthropic recommends tolerant handling or returning `is_error`. — [Prompting Sonnet 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5)
- Sonnet 5.5 has five breaking changes from Sonnet 5:
  - `between_tools` replaces disabled thinking
  - forced tool use errors
  - thinking blocks are tied to the model and conversation
  - `computer_20251124` is rejected
  - advisor-tool pairing limits

  Text between tool calls now arrives as `thinking` blocks, which look empty unless `display: "updates"` is set. Non-default temperature, top_p or top_k returns a 400 error. — [Sonnet 5.5 overview](https://platform.claude.com/docs/en/models/sonnet-5-5/overview)
- New refusal categories on the 5.5 models: `cyber`, `bio`, `frontier_llm`, `reasoning_extraction`, `general_harms`. Prompts asking the model to write its reasoning into the response invite `reasoning_extraction` declines. Sonnet 5.5's server-side fallback retries cyber and frontier_llm declines on Sonnet 5. Haiku 5.5 has no server-side fallback. — [Prompting Sonnet 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5); [Prompting Haiku 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-haiku-5-5)
- AA found an over-refusal bug in Haiku 5.5 that lowers its AutomationBench-AA score. — [TechJack Solutions](https://techjacksolutions.com/ai-brief/claude-haiku-5-5-benchmark-pricing-artificial-analysis/) (search snippet)
- At `xhigh` in multi-turn chat, Haiku 5.5 sometimes puts its whole answer in thinking and returns no visible text. — [Prompting Haiku 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-haiku-5-5)
- For background: the Opus 5 system card (July 2026) reported elevated evaluation awareness that Anthropic judged did not materially undermine its conclusions. — [Zvi: Opus 5 system card](https://thezvi.substack.com/i/208361260/alignment-6)

### Inferences
- For blitz, the "reward hacking / test gaming" risk shows up in practice mostly as "reported done without running a check" at low effort. The prompt-level mitigation is cheap and documented.
- Blitz critics or prompts that ask agents to "show reasoning" in output may trigger `reasoning_extraction` refusals on 5.5 models. Ask for a short explanation or summary of actions instead.
- If blitz hooks inject text after tool results (for example budget or countdown notices), 5.5 models may treat it as injection. Use separate system messages and keep the cadence low.

### Gaps
- I found no primary system-card text on reward hacking or test special-casing rates for any 5.5 model; the PDFs could not be fetched.
- Hallucination and overconfidence rates beyond "much less likely to state an incorrect figure" (Opus 5.5) were not quantified.

## Q5. Community and practitioner reception

### Takeaway
Reception evidence is thin and mostly secondary. Coverage repeats Anthropic's speed, cost and benchmark claims. Hacker News reaction to Opus 5.5 is reported as mixed (benchmark skepticism, debate over the price cut). I found no substantive Reddit thread on the 5.5 models.

### Cited Findings
- Coverage outside the US repeats Anthropic's claims: 30% faster, about 30% lower per-task cost, unchanged price. Same-day availability on AWS, Google Cloud, Azure and Claude Code. — [Inside (TW)](https://www.inside.com.tw/article/42512-anthropic-claude-sonnet-5-5-launch-faster-cheaper); [AF.net](https://af.net/realtime/anthropic-launches-claude-sonnet-5-5-for-faster-and-cheaper-everyday-coding/)
- Kiro added Sonnet 5.5 as an experimental model in its IDE and CLI. — [Kiro changelog](https://kiro.dev/fr/changelog/models/claude-sonnet-5-5/)
- An HN commenter is quoted as saying benchmarks often "don't survive contact with reality". The Opus 5.5 price cut drew a mixed HN reaction. Secondhand; the HN thread itself was not retrieved. — [Mejba blog](https://www.mejba.me/de/blog/tag/claude-opus-55)
- Customer quotes on the Anthropic page (vendor-curated):
  - Epic Games: Sonnet 5.5 "cleared the same quality bar you'd expect from a higher-tier model"
  - Base44: across 118 app builds, Sonnet 5.5 scored "level with Opus 5"
  - CodeRabbit: "better judgment than Sonnet 5"

  — [Anthropic: Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5)
- A small Reddit thread from July 2026 was about Sonnet 5, not 5.5. One commenter said Sonnet 5 was "close to Opus on a surprising number of things"; another said it was "more expensive than opus on high and worse performing". This echoes the AA token finding for 5.5 but is anecdotal. — [Reddit snapshot](https://reddit.sentinel-team.org/posts/1uk624d/snapshots/2026-07-03T03%3A00%3A16.73148Z)
- Pre-release "Opus 5.5 leak" articles described a leak with "no model card, no API identifier, no price sheet". They are unreliable and were superseded by the launch. — [OrcaRouter](https://www.orcarouter.ai/de/blog/claude-opus-5-5-leak)

### Inferences
- With Haiku 5.5 only three days old and Sonnet 5.5 twelve days old as of 2026-10-10, practitioner consensus has not formed. Routing decisions should rest on Anthropic's docs plus blitz's own evals, not on community sentiment.

### Gaps
- I did not retrieve any Hacker News, r/ClaudeAI, r/ClaudeCode or X threads about the 5.5 models directly; searches returned only blog aggregations.
- Simon Willison's blog, VentureBeat, TechCrunch and The Verge coverage of the 5.5 launches did not appear in search results and was not consulted.

---

### All URLs consulted
1. https://www.anthropic.com/claude-opus-5-5
2. https://www.anthropic.com/claude-sonnet-5-5
3. https://www.anthropic.com/claude-haiku-5-5
4. https://www.anthropic.com/news/claude-sonnet-5-5 (404)
5. https://www.anthropic.com/document/claude-sonnet-5-5-system-card (redirects to a PDF that exceeded the fetch size limit)
6. https://platform.claude.com/docs/en/models/overview
7. https://platform.claude.com/docs/en/about-claude/pricing
8. https://platform.claude.com/docs/en/build-with-claude/effort
9. https://platform.claude.com/docs/en/build-with-claude/prompt-caching
10. https://platform.claude.com/docs/en/api/rate-limits
11. https://platform.claude.com/docs/en/models/sonnet-5-5/overview
12. https://platform.claude.com/docs/en/models/haiku-5-5/overview
13. https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5
14. https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-haiku-5-5
15. https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5
16. https://oodaloop.com/briefs/technology/claude-sonnet-5-5-reaches-2-on-artificial-analysis-index-but-uses-more-tokens/
17. https://officechai.com/ai/claude-sonnet-5-5-scores-56-on-artificial-analysis-intelligence-index-3-points-ahead-of-gpt-6-astra/
18. https://aiweekly.co/fr/alerts/artificial-analysis-claude-sonnet-55-second-2-pts-dopus-55
19. https://techjacksolutions.com/ai-brief/claude-haiku-5-5-benchmark-pricing-artificial-analysis/ (403; search snippet only)
20. https://computingforgeeks.com/claude-haiku-5-5-released-features-benchmarks/
21. https://aiweekly.co/alerts/introducing-claude-haiku-55
22. https://apidog.com/blog/claude-haiku-5-5-pricing/
23. https://metricnexus.ai/blog/claude-opus-5-5-benchmarks-pricing
24. https://benchlm.ai/md/models/claude-opus-5-5.md
25. https://apidog.com/blog/claude-sonnet-5-5-claude-code/
26. https://codersera.com/blog/claude-sonnet-5-5-vs-opus-5-5-2026/
27. https://digitalstrategy-ai.com/claude-opus-5-5-review
28. https://digg.com/ai/ypkt8g88
29. https://thezvi.substack.com/i/208361260/alignment-6
30. https://www.inside.com.tw/article/42512-anthropic-claude-sonnet-5-5-launch-faster-cheaper
31. https://af.net/realtime/anthropic-launches-claude-sonnet-5-5-for-faster-and-cheaper-everyday-coding/
32. https://kiro.dev/fr/changelog/models/claude-sonnet-5-5/
33. https://www.mejba.me/de/blog/tag/claude-opus-55
34. https://reddit.sentinel-team.org/posts/1uk624d/snapshots/2026-07-03T03%3A00%3A16.73148Z
35. https://www.orcarouter.ai/de/blog/claude-opus-5-5-leak
