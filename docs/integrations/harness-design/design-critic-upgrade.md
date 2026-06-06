# design-critic-upgrade.md — The live-navigating evaluator spec (Gap 1)

**Extends:** `agents/design-critic.md` and `skills/ui-build/SKILL.md` Phase 5.4.
**Concept:** [`harness-model.md`](harness-model.md) §3 · **Gap:** [`gap-fixes.md`](gap-fixes.md) Gap 1.
**Goal:** Move the design evaluator from scoring a static screenshot to *navigating the live rendered app* before scoring — without breaking the read-screenshots-not-source rule and with a clean static fallback.

---

## 1. What changes

| Today | After |
|---|---|
| Input: pre-captured `/tmp/ui-build-screenshots/*.png` (`design-critic.md:44`) | Input: a **live URL** to the running dev server + viewport list; static PNGs become the fallback |
| `tools: Read, Grep, Glob, Bash` (`design-critic.md:16`) — no Playwright | `tools: Read, Grep, Glob, Bash` **+ Playwright MCP** (browser navigation subset) |
| Scores 3 static shots | Navigates (click/hover/keypress/resize), screenshots *itself*, then scores |
| `maxTurns: 15` (`:20`) | Raised (navigation consumes turns) — bound per `agent-orchestration.md` |

The five scoring dimensions (`design-critic.md:54–67`), the JSON reply contract (`:71–97`), and the PASS/ITERATE/REWORK thresholds (`:99–104`) are **unchanged**. Only the *input surface* and the *evidence-gathering step before scoring* change.

---

## 2. Playwright MCP grant + security posture

The current capability rationale (`design-critic.md:17–19`) keeps the agent read-only with *no network/MCP egress*, posture per `threat-model.md §5`. Granting Playwright must be stated as a **scoped exception, not a posture reversal**:

- Grant the **navigation subset** of the Playwright MCP: `browser_navigate`, `browser_click`, `browser_hover`, `browser_press_key`, `browser_type`, `browser_resize`, `browser_snapshot`, `browser_take_screenshot`, `browser_wait_for`, `browser_console_messages`. (These are the read/interact tools; the agent already proved the read-only discipline.)
- **Do not grant** `browser_run_code_unsafe` / `browser_evaluate` arbitrary-JS execution unless explicitly justified — that is the egress/exec hole the §5 posture guards against.
- Target is the **local dev server only** (the URL ui-build passes). Document that Playwright here is a controlled local-browser capability, not arbitrary internet egress — the distinction the threat-model cares about.
- Keep `no Write/Edit/Agent` (`:18`) intact — the agent still produces only the JSON reply contract.

Add a capability-rationale comment block mirroring `:17–19` for the Playwright grant, citing `threat-model.md §5` and this doc.

---

## 3. The navigation script (before scoring)

The agent runs this sequence on the live URL, capturing its own screenshots, *then* scores. It is evidence-gathering, not source-reading.

```
1. NAVIGATE to the dev-server URL (default desktop 1440).
2. SNAPSHOT the accessibility tree (browser_snapshot) — establishes structure for scoring UX/affordances.
3. EXERCISE PRIMARY ACTIONS:
   - Identify primary CTAs / nav / form submits from the snapshot.
   - Click each primary action; observe the result (route change, modal, content update).
   - Flag the broken-wiring class: element renders but click produces no observable response
     (this is the article's "entities appeared but nothing responded to input").
4. EXERCISE INTERACTIVE STATES:
   - Hover primary interactive elements (capture hover/focus visual states).
   - Keyboard: Tab through focusable elements (focus-ring presence), Enter/Escape on dialogs.
5. RESPONSIVE: resize to 768 then 375; at each, screenshot and check the layout is genuinely
   usable (not a compressed desktop) — the real responsive behavior, not a scaled shot.
6. TRANSITIONS: trigger any modal/drawer/accordion; screenshot mid- and post-transition.
7. CONSOLE: read browser_console_messages — runtime errors are functionality (UX dim) evidence.
8. SCREENSHOT the final state at each viewport for the record.
9. SCORE the 5 dimensions using the navigation evidence + screenshots. Write the critique.
```

**What navigation now feeds each dimension** (mapping to `design-critic.md:54–67`):
- **2.1 Prompt Adherence / 2.2 Aesthetic Fit** — still primarily visual (screenshots).
- **2.3 Visual Polish** — screenshots + observed hover/focus states (mixed corner radii, focus rings).
- **2.4 UX** — *substantially upgraded*: primary-action response, keyboard reachability, console errors, real responsive usability. This is where live nav pays off most (≈ article's Functionality).
- **2.5 Creative Distinction** — screenshots + transitions/motion (a distinctive motion language is part of having a point of view).

A new `issues[]` severity case: a primary action that renders but does not respond is a **blocker** under UX (the broken-wiring bug) — even if the static shot looks perfect.

---

## 4. Static fallback (Playwright unavailable)

ui-build already checks for Playwright and warns when absent (`ui-build/SKILL.md:307`). The fallback path is preserved exactly:

- If Playwright MCP is unavailable, the agent runs the **legacy static-screenshot path**: score the pre-captured `/tmp/ui-build-screenshots/*.png` as today.
- It MUST record the degradation in the reply contract (e.g. a `coverage_boundary` note: "static fallback — interaction/responsive/console not exercised"), never silently pass interaction-dependent dimensions. This mirrors the existing gemini-unavailable discipline at `design-critic.md:127` (*"never silently pass them"*).
- UX and any interaction-dependent finding is scored conservatively and flagged as un-navigated, not assumed-good.

---

## 5. Reconciliation with "read screenshots, not source" (`design-critic.md:108`)

The rule is: judge the rendered output, not the implementation (do not read `.vue`/CSS). **It stands unchanged.** Navigating the rendered app is *still not reading source* — the agent interacts with the running product through the browser, never opening source files. Update the rule's wording to make this explicit:

> **Read the rendered app, not the source.** Judge what the user experiences — navigate and screenshot the live page. Never open `.vue`/CSS/source to score; the implementation is irrelevant to your assessment.

This preserves the original intent (output not implementation) while the input surface expands from static image → live DOM.

---

## 6. Composition with the deterministic design pillar

The `design` pillar's deterministic lane (`check-registry.json` `pillar == design`, key-free `npx impeccable detect`) runs **first** and catches mechanical tells (gradient-text, banned fonts, identical card grids, raw token literals). Those findings are handed to the live-nav critic so it does **not** re-derive them — it spends its (now more expensive) navigation budget on what only live interaction reveals: broken wiring, focus order, transition correctness, real responsive behavior. The critic is the semantic/vision lane (`design-critic.md:36`); live nav deepens that lane, it does not replace the deterministic pre-filter.

---

## 7. Acceptance (grep-based)

```sh
# Playwright navigation tools granted in design-critic frontmatter
grep -E "browser_navigate|playwright" agents/design-critic.md          # expect ≥1 match in tools/rationale

# Navigation-before-scoring section exists
grep -iE "navigate the (live )?page|exercise primary actions|broken[- ]wiring" agents/design-critic.md

# Static fallback preserved + must-not-silently-pass
grep -iE "static fallback|coverage_boundary" agents/design-critic.md

# read-screenshots-not-source rule updated to "rendered app, not source"
grep -iE "rendered app, not the source|never open .*\.vue" agents/design-critic.md

# ui-build hands the critic a live URL (Phase 5.4)
grep -nE "dev[- ]server URL|live URL|--url" skills/ui-build/SKILL.md

# arbitrary-JS execution NOT granted
! grep -E "browser_run_code_unsafe|browser_evaluate" agents/design-critic.md   # expect no match
```

Implementation is a follow-up sprint behind Blitz's gates — whose own (upgraded) design-critic will navigate the live result and score it.
