# Synthesis — sequenced Blitz epics (spine-first)

> **Source analysis:** `pbakaus/impeccable@2.3.2` (Apache-2.0). Original Blitz authorship. See [`ATTRIBUTION.md`](ATTRIBUTION.md).
> **Status:** doc #8 of 8 — the build plan. Sequences the absorption into dependency-ordered epics with grep-checkable acceptance per step. Implementation runs behind Blitz's own sprint-plan → sprint-dev → sprint-review (8-invariant) gates — **the suite runs on itself.**

---

## 0. Dependency graph

```
E0 Foundations (registry schema + ATTRIBUTION + LICENSE)
   └─> E1 Spine impl (stack probe)            [specs: normalized-model, adapter-detection — DONE this pass]
         └─> E2 Proof adapter: Tailwind        [framework-profiles §1]
               └─> E3 Detector keystone        [detector-rebuild: firing logic + reconciliation + lanes]
                     └─> E4 Remaining adapters: MD3, Vuetify(v4/v3/v0), Quasar
                           └─> E5 References + skill reconcile (ui-build, design-extract, design-critic)
                                 └─> E6 Migration + retire (orchestrator, quality-matrix, delete heuristics)
```

Spine-first is non-negotiable (normalized-model §7 anti-scope): no detector rule before the model + adapter abstraction exist. Tailwind is the proof adapter (simplest: open palette, computed-fallback, no closed role set). The detector keystone lands on the proof adapter before the other three, so the firing logic + reconciliation are validated on one stack before scaling.

---

## E0 — Foundations

**Scope:** extend `check-registry.json`; vendor license; write ATTRIBUTION.
- Add `design` to the `pillar` enum; add `layer` (0|1|2), `adapter` (universal|tailwind|tailwind-md3|vuetify|quasar), `reconciliation` ({relaxFor[], cite}) to `field_contract`.
- Vendor `docs/integrations/impeccable/LICENSE-APACHE-2.0.txt`; finalize `ATTRIBUTION.md`.

**Acceptance:**
```bash
node -e "const r=require('./skills/_shared/check-registry.json'); process.exit(r.field_contract.layer&&r.field_contract.adapter?0:1)"
test -f docs/integrations/impeccable/LICENSE-APACHE-2.0.txt
grep -q "MERGE-BLOCKING" docs/integrations/impeccable/ATTRIBUTION.md
```

---

## E1 — Spine implementation (the `stack` probe)

**Scope:** implement the deterministic selector ([`adapter-detection.md`](adapter-detection.md)) — extend `context-signals.mjs` `gatherSignals()` with one `stack` key; add the detection table (precedence quasar→vuetify→tailwind-md3→tailwind→none), variant + incompatibility resolution. (The spine *specs* are done this pass.)

**Acceptance:**
```bash
# fixture projects under tests/framework-fixtures/{tailwind,quasar,vuetify3,vuetify4,md3,none}
for f in tailwind quasar vuetify3 vuetify4 md3 none; do
  node context-signals.mjs --cwd tests/framework-fixtures/$f | jq -e '.stack.primary'  # non-null
done
# quasar+tailwind fixture → incompatibility, not secondary
jq -e '.stack.incompatibilities|index("quasar+tailwind")' < quasar-tailwind-fixture.json
# never-throw contract: valid JSON even on a malformed package.json
node context-signals.mjs --cwd tests/framework-fixtures/malformed | jq -e '.stack.primary=="none"'
```

---

## E2 — Proof adapter: Tailwind

**Scope:** vendor the 39 Layer 0 rows + the 4 Layer 1 rows + Tailwind Layer 2 rows ([`framework-profiles.md`](framework-profiles.md) §1, [`detector-rebuild.md`](detector-rebuild.md)); wire `/blitz:review --only design` selection for `stack.primary == tailwind`.

**Acceptance:**
```bash
node -e "const r=require('./skills/_shared/check-registry.json'); const d=r.checks.filter(c=>c.pillar==='design'); console.log('L0',d.filter(c=>c.layer===0).length, 'tw-L2',d.filter(c=>c.adapter==='tailwind').length)"
# L0 == 39 ; tailwind L2 >= 3
# review runs on a Tailwind fixture; NO design FP on the Quasar fixture (cross-stack test)
/blitz:review --only design tests/framework-fixtures/tailwind     # finds Layer 0/1 + tw L2
/blitz:review --only design tests/framework-fixtures/quasar       # NO tailwind-L2 findings
grep -c "source: impeccable@2.3.2" skills/_shared/check-registry.json   # >= 39 (vendor tags)
```

---

## E3 — Detector keystone (firing logic + reconciliation + lanes)

**Scope:** implement the §4 firing gate ([`detector-rebuild.md`](detector-rebuild.md)) — `adapter ∈ {universal} ∪ stack`, reconciliation suppression with `cite`, verdict-authority derivation; wire `design-critic` as the semantic lane backing; `/blitz:audit --pillar design`.

**Acceptance (the cross-stack reconciliation test):**
```bash
# bounce-easing fires on Tailwind + Vuetify, SUPPRESSED on MD3 + Quasar
for f in tailwind vuetify4; do /blitz:review --only design tests/framework-fixtures/$f | grep -q bounce-easing; done   # present
for f in md3 quasar;       do /blitz:review --only design tests/framework-fixtures/$f | grep -q bounce-easing && echo "FAIL: false positive on $f"; done  # absent
# every reconciliation carries a cite (registry-lint)
node -e "const r=require('./skills/_shared/check-registry.json'); const bad=r.checks.filter(c=>c.reconciliation&&!c.reconciliation.cite); process.exit(bad.length)"
# a11y-contrast is reject-eligible; gradient-text is advisory
node -e "const r=require('./skills/_shared/check-registry.json'); const lc=r.checks.find(c=>c.id==='design-low-contrast'); process.exit(lc.verdict_authority==='reject'?0:1)"
```

---

## E4 — Remaining adapters (MD3, Vuetify, Quasar)

**Scope:** Layer 2 rows + reconciliations for the other three ([`framework-profiles.md`](framework-profiles.md) §2–4); Vuetify **v4 primary** + v3/v0 variant rules; Quasar+Tailwind incompatibility rule.

**Acceptance:**
```bash
node -e "const r=require('./skills/_shared/check-registry.json'); const d=r.checks.filter(c=>c.pillar==='design'); for(const a of ['tailwind-md3','vuetify','quasar']) console.log(a, d.filter(c=>c.adapter===a).length)"   # each >= 3
# vuetify variant gating: elevation>5 valid on v3, flagged on v4
/blitz:review --only design tests/framework-fixtures/vuetify3 | grep -q elevation && echo "v3 elevation OK"
/blitz:review --only design tests/framework-fixtures/vuetify4 | grep -q "elevation.*>5"   # flagged
# quasar+tailwind coexistence is a reject-eligible build conflict
node -e "const r=require('./skills/_shared/check-registry.json'); process.exit(r.checks.find(c=>c.id==='design-quasar-tailwind-coexist').verdict_authority==='reject'?0:1)"
```

---

## E5 — References + skill reconcile (adapter-aware)

**Scope:** relocate the 13-tone list into `references-regrounded.md` §8; make `ui-build` (Phase 1.1/3.0 stack-aware; inline gates → `/blitz:review --only design`) and `design-extract` (adapter-resolved token emit; DESIGN.md `## Stack`) adapter-aware; rewire `design-critic` heuristic source #2 + stack-aware scoring; dedupe ui-audit Phase 5 a11y rows to the registry.

**Acceptance:**
```bash
grep -q "13-tone" docs/integrations/impeccable/references-regrounded.md || grep -qi "brutalist.*luxury.*playful" references-regrounded.md
grep -q "review --only design" skills/ui-build/SKILL.md           # inline gates delegate
grep -q "## Stack" skills/design-extract/SKILL.md                  # adapter section in DESIGN.md template
grep -q "references-regrounded" agents/design-critic.md            # heuristic source rewired
! grep -q "frontend-design-heuristics" agents/design-critic.md skills/design-extract/SKILL.md   # old ref gone from these consumers
```

---

## E6 — Migration + retire (the redirect-and-delete)

**Scope:** orchestrator §2 routing rows; quality-matrix design surface; **delete `frontend-design-heuristics.md`** only after every consumer is redirected (migration-spec §2 coverage gate).

**Acceptance:**
```bash
grep -q "review --only design" agents/orchestrator.md
grep -q "audit --pillar design" agents/orchestrator.md
grep -qi "design" skills/_shared/quality-matrix.md                 # design pillar in the matrix
# retire gate: zero references before deletion
test -z "$(grep -rl frontend-design-heuristics skills/ agents/ 2>/dev/null)" && git rm skills/_shared/frontend-design-heuristics.md
! test -f skills/_shared/frontend-design-heuristics.md             # gone
markdown-link-validate.sh                                          # no dead links from the deletion
```

---

## Self-hosting (the suite runs on itself)

Each epic is a Blitz sprint: `/blitz:sprint-plan` (stories from this synthesis) → `/blitz:sprint-dev` (worktree agents) → `/blitz:sprint-review` (8-invariant gate incl. critic LGTM + ratchet). The design pillar, once built, is dogfooded by running `/blitz:audit --pillar design` against any Vue fixture (Blitz itself is a CLI plugin with no shipped UI — the fixtures under `tests/framework-fixtures/` are the dogfood surface). ATTRIBUTION.md (E0) blocks every PR in the chain until complete.

---

## Sequencing rationale (grep-checkable invariants across epics)

| Invariant | Check |
|---|---|
| Spine precedes rules | E2 PRs touch the registry only after E1's `stack` probe lands |
| Proof-before-scale | E4 (3 adapters) only after E3 keystone green on Tailwind |
| No cross-stack FP | E2/E3/E4 each include the "no finding on the wrong stack" fixture test |
| Reconciliation cited | E3 registry-lint: every `relaxFor` has a `cite` |
| Coverage before delete | E6 deletion gated on grep-empty consumers (E5 redirects first) |
| License before vendor | E0 ATTRIBUTION + LICENSE precede any `source:`-tagged row (E2+) |

---

## Acceptance (this synthesis)

- 7 epics (E0–E6) in a single dependency chain, spine-first, Tailwind-proof-first, keystone-before-scale.
- Each epic has grep/jq-checkable acceptance.
- Self-hosting via Blitz's own sprint gates stated; ATTRIBUTION merge-block threaded through.
- Cross-stack-FP test repeated at E2/E3/E4 (the architecture's core guarantee).
