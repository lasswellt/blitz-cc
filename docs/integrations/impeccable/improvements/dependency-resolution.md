# dependency-resolution.md — impeccable resolution model + preflight + loud-failure contract

Addresses **Finding 1 (CRITICAL)** and **N1 (HIGH)**. Goal: the design lane must be **always available or loudly unavailable — never silent green.**

---

## 0. Where impeccable lives — the target project, NOT the plugin

Blitz is a Claude Code **plugin**; `--only design` / `--pillar design` run against a **target project** (the repo under review, `process.cwd()`). impeccable's detector is browser-rendered (puppeteer-class), so it is a runtime dependency of *the project being reviewed*, not of the plugin tree. Adding it to a Blitz root `package.json` would (a) drag a browser toolchain into the plugin install for every user regardless of whether they use the design lane, and (b) resolve it relative to the plugin, not the project actually being scanned. **Wrong layer.**

Resolution model is therefore **target-project-scoped**:
- impeccable is declared in the **target project's** `package.json` (the project opts into the semantic design lane).
- Blitz **recommends** it but never installs it into its own tree. `/blitz:bootstrap` / `/blitz:setup` surface the suggestion; the preflight resolves it **from the target project's `node_modules`** (`require.resolve` with `paths: [cwd]`, or `npx` which already resolves from the project).
- Blitz's own tree gains **no** `impeccable` dependency. There is no need for a root `package.json` solely for this.

---

## 1. Resolution options + tradeoff (target-project scope)

| Option | Who installs | Network risk | Version risk | Verdict |
|---|---|---|---|---|
| (a) Declared in **target** `package.json` (`devDependency`, pinned `2.3.2`) | the reviewed project | none after install | none (pin + lockfile) | **chosen** — correct layer; project owns its own browser toolchain |
| (b) Vendor the detector into the Blitz plugin tree | plugin | none | frozen | rejected — wrong layer; plugin carries a generated browser bundle it must rebuild on every upstream change |
| (c) Plugin root `optionalDependency` | plugin | install-time | pinned | rejected — drags puppeteer into every plugin install; resolves relative to plugin not project |
| (d) Pinned `npx impeccable@2.3.2` from the target project | per-run | cold-cache fetch | pinned | fallback when the project hasn't declared it; preflight still required |

**Decision.** Split by lane, because Finding N1 shows the vendored rows are non-deterministic regardless of resolution:

1. **The deterministic lane depends on nothing external.** 15 blitz `regex` rows + `design-quasar-tailwind-coexist` (`detect-stack.sh | grep`). `grep`/`node` only — no network, no browser, no keys, no impeccable. Always-available core, ships with the plugin.
2. **The vendored impeccable rows move to `lane: semantic`** alongside `design-critic`. impeccable is resolved **from the target project** (option a; option d as `npx` fallback), pinned exact `2.3.2`. The preflight asserts the project-resolved version equals the pin; if absent, the lane is reported `UNAVAILABLE` with an install hint, never silent green.
3. **`gen-design-rows.mjs` reproducibility:** this is a Blitz **maintenance** script, not a review-time path — it runs only when regenerating the registry from upstream. Repoint its `/tmp/impeccable-src` default to an explicit arg (a maintainer-supplied checkout/clone path), documented in the script header. It is the one place a maintainer-local impeccable source is legitimate; it must not silently default to `/tmp`.

Rationale for not vendoring (b): the artifact is a *generated* browser bundle (`detect-antipatterns-browser.js`: `GENERATED -- do not edit. Rebuild: node scripts/build-browser-detector.js`). Vendoring a generated bundle into the plugin means re-running upstream's build to update it — more maintenance, wrong layer, no safety gain.

---

## 2. Preflight design — `scripts/design/preflight.sh`

New script, invoked at the top of every `--only design` / `--pillar design` run **before** any row executes. It classifies the lane into three runnable tiers and reports loudly.

```sh
#!/usr/bin/env bash
# scripts/design/preflight.sh — design-lane availability gate.
# Prints a machine-readable status line + human summary; exit code never
# blocks the deterministic regex tier.
set -uo pipefail

PIN="2.3.2"
status_det="OK"          # blitz regex rows — always runnable
status_sem="UNKNOWN"     # vendored impeccable rows
reason=""

# Deterministic tier just needs grep + node (always true in this env).
command -v grep >/dev/null || { echo "DESIGN_DETERMINISTIC_UNAVAILABLE: grep missing"; exit 1; }

# Semantic tier: impeccable must resolve to the exact pin, FROM THE TARGET
# PROJECT (the repo under review = $TARGET, default cwd) — NOT the plugin.
TARGET="${1:-$PWD}"
if resolved=$(node -e "process.stdout.write(require(require.resolve('impeccable/package.json',{paths:[process.argv[1]]})).version)" "$TARGET" 2>/dev/null); then
  if [ "$resolved" = "$PIN" ]; then
    status_sem="OK"
  else
    status_sem="VERSION_MISMATCH"; reason="impeccable resolved ${resolved} in target project, expected ${PIN}"
  fi
else
  status_sem="ABSENT"; reason="impeccable not in target project — install: npm i -D impeccable@${PIN}"
fi

echo "DESIGN_LANE_STATUS deterministic=${status_det} semantic=${status_sem}${reason:+ reason=\"$reason\"}"
[ "$status_sem" != "OK" ] && \
  echo "DESIGN_LANE_UNAVAILABLE: semantic (vendored impeccable) lane skipped — ${reason}. Deterministic regex rows still ran." >&2
exit 0   # never fail the run; the caller decides gating
```

Output contract (consumed by `review`/`audit` summary):
- `DESIGN_LANE_STATUS deterministic=OK semantic=OK` → both lanes ran.
- `DESIGN_LANE_STATUS deterministic=OK semantic=ABSENT` + `DESIGN_LANE_UNAVAILABLE: …` on stderr → deterministic ran, semantic skipped **loudly**.

---

## 3. The loud-failure contract (`DESIGN_LANE_UNAVAILABLE`)

Non-negotiable rules:

1. **Never silent green.** A design run where the semantic lane could not execute must surface `DESIGN_LANE_UNAVAILABLE: <reason>` in:
   - the findings output (`${RUN}/findings/00-design.md` gains a `## Lane status` block),
   - the `review`/`audit` top-line summary (e.g. `design: 3 deterministic findings · semantic lane UNAVAILABLE (impeccable not installed)`).
2. **Deterministic floor always runs.** Even with the semantic lane down, the 15 regex rows execute and can still produce blockers. A down semantic lane downgrades *coverage*, it does not turn the pillar green.
3. **Exit semantics.** The preflight exits 0 (advisory) so the deterministic tier proceeds; the *caller* (`review`/`audit`) decides whether `semantic=ABSENT` is acceptable. Default: warn, do not fail the gate, but render the banner so a human sees the gap. `audit --pillar design --strict` MAY treat `semantic=ABSENT` as a hard fail for release-gating.
4. **CI reproducibility.** In the target project's CI, the pinned dependency resolves → `semantic=OK`. If CI cannot build the browser detector, it reports `semantic=ABSENT` loudly rather than passing as if covered — making the gap visible in the pipeline log instead of hidden behind a green check. The Blitz plugin's own CI never installs impeccable; its design tests cover the deterministic lane + the `ABSENT` path only.

---

## 4. Wiring changes (spec, implemented in epic DEP-1)

| File | Change |
|---|---|
| `scripts/design/preflight.sh` (new) | the gate above; resolves impeccable **from the target project** (`paths:[TARGET]`), not the plugin. **No** plugin `package.json` dependency is added. |
| `scripts/maint/design/gen-design-rows.mjs:24` | drop the `/tmp/impeccable-src` default; require an explicit maintainer-supplied source path arg (this is a maintenance-only regen script, not a review-time path) |
| `skills/review/SKILL.md` (`--only design`) | call preflight with the target repo first; render lane-status banner; gate per §3 |
| `skills/audit/references/main.md` (Phase 1.D2) | same; `--strict` honors `semantic=ABSENT` as fail |
| `skills/bootstrap` + `skills/setup` | recommend `npm i -D impeccable@2.3.2` to the **target project** when the design pillar is in use (project opts in; plugin never installs it) |
| `skills/_shared/check-registry.json` | the 42 vendored rows re-laned to `semantic` (lane-reclassification.md) so the preflight's `semantic` tier maps to them |

**Acceptance (grep-based):**
- Blitz plugin tree adds **no** impeccable dependency: `! grep -rq '"impeccable"' --include=package.json .` (plugin stays clean).
- `bash scripts/design/preflight.sh <target-with-impeccable> | grep -q 'semantic=OK'`
- `bash scripts/design/preflight.sh <target-without-impeccable> 2>&1 | grep -q 'DESIGN_LANE_UNAVAILABLE'` with an `npm i -D impeccable` hint.
- `bash scripts/design/preflight.sh | grep -q '^DESIGN_LANE_STATUS'`
- `! grep -q '/tmp/impeccable-src' scripts/maint/design/gen-design-rows.mjs`
