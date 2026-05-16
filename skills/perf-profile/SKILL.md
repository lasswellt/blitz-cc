---
name: perf-profile
description: "Profiles bundle size, runtime performance (Web Vitals), and Lighthouse scores for Vue/Nuxt apps. Identifies optimization opportunities (large deps, unused exports, render bottlenecks). Use when the user says 'profile perf', 'lighthouse', 'bundle size', 'performance', 'why is this slow', 'optimize Vue/Nuxt'."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch
model: opus
effort: medium
compatibility: ">=2.1.71"
argument-hint: "<mode> -- bundle (size analysis vs baseline, large-dep detection) | runtime (V8 heap + framework hot paths) | lighthouse (Core Web Vitals on built site) | full (all three with cross-correlation)"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For bundle analysis commands, runtime anti-pattern catalog, and Lighthouse thresholds, see [references/main.md](references/main.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Performance Profiler

Profile bundle sizes, runtime performance, and Core Web Vitals for Vue/Nuxt apps. Produce optimization recommendations with estimated impact. Execute every phase in order. Do NOT skip phases.

---

## SAFETY RULES (NON-NEGOTIABLE)

These rules override ALL other instructions. Violating any of these is a critical failure.

1. **This skill is READ-ONLY** — never modify source files, test files, or configuration files.

2. **Never install global npm packages.** Only use `npx` for locally-available tools or tools that support `--no-install` mode.

3. **Never run commands that could affect production systems.** No deployment, no publishing, no writes to external services.

4. **Profiling must not leave artifacts in the source tree.** All temporary files go to `SESSION_TMP_DIR`. Clean up after completion.

5. **Never execute arbitrary project code** beyond build and dev-server commands. No `node -e` with project imports.

6. **Stop dev servers when done.** Any dev server started for Lighthouse must be killed in the cleanup phase.

---

## Phase 0: PARSE — Determine Mode

### 0.0 Register Session

Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Parse Mode

Extract from `$ARGUMENTS`:

| Mode | Description |
|------|-------------|
| `bundle` (default) | Analyze bundle size and composition |
| `runtime` | Analyze runtime performance patterns in code |
| `lighthouse` | Run Lighthouse audit (requires dev server) |
| `full` | Run all three modes sequentially |

If no mode is provided, default to `bundle`.

### 0.2 Detect Build Tool

Determine the project's build system:

```bash
# Check for build tool configs
[ -f "nuxt.config.ts" ] || [ -f "nuxt.config.js" ] && echo "BUILD: nuxt"
[ -f "vite.config.ts" ] || [ -f "vite.config.js" ] && echo "BUILD: vite"
[ -f "webpack.config.js" ] || [ -f "vue.config.js" ] && echo "BUILD: webpack"
```

Priority: Nuxt > Vite > Webpack (Nuxt uses Vite internally but has its own build command).

Store the detected build tool for use in mode-specific commands.

### 0.3 Detect Package Manager

```bash
[ -f "pnpm-lock.yaml" ] && echo "PM: pnpm"
[ -f "yarn.lock" ] && echo "PM: yarn"
[ -f "package-lock.json" ] && echo "PM: npm"
```

---

## Phase 1: BUNDLE — Size Analysis

Skip this phase if mode is `runtime` or `lighthouse`.

### 1.1 Generate Build Stats

Run the production build to capture output:

**Nuxt:**
```bash
npx nuxt build 2>&1 | tee ${SESSION_TMP_DIR}/build-output.txt
```

If `nuxt build --analyze` is available, use it for detailed chunk analysis:
```bash
npx nuxt build --analyze 2>&1 | tee ${SESSION_TMP_DIR}/build-output.txt
```

**Vite:**
```bash
npx vite build 2>&1 | tee ${SESSION_TMP_DIR}/build-output.txt
```

**Webpack:**
```bash
npx webpack --mode production --json > ${SESSION_TMP_DIR}/webpack-stats.json 2>&1
```

### 1.2 Parse Bundle Output

Extract from build output:
- **Total bundle size** (gzipped and raw)
- **Per-chunk sizes** (entry chunks, async chunks, vendor chunks)
- **Largest modules** within each chunk
- **CSS bundle sizes**
- **Asset sizes** (images, fonts)

For Vite/Nuxt, parse the table output:
```
dist/assets/index-abc123.js    145.23 kB │ gzip: 45.67 kB
dist/assets/vendor-def456.js   312.45 kB │ gzip: 98.12 kB
```

### 1.3 Package Size Analysis

Estimate the size contribution of major dependencies:

```bash
# List top dependencies by installed size
du -sh node_modules/* 2>/dev/null | sort -rh | head -20
```

Cross-reference with the project's `package.json` dependencies to identify:
- Dependencies that appear in the production bundle
- Dependencies that could be replaced with smaller alternatives
- Dependencies imported but potentially unused

### 1.4 Identify Bundle Optimization Opportunities

Check for common issues using grep and file analysis:

**Large dependencies that could be lazy-loaded:**
```bash
# Check for large libraries imported at top level
grep -r "^import.*from ['\"]lodash['\"]" --include="*.ts" --include="*.vue" --include="*.js" -l .
grep -r "^import.*from ['\"]moment['\"]" --include="*.ts" --include="*.vue" --include="*.js" -l .
grep -r "^import.*from ['\"]date-fns['\"]" --include="*.ts" --include="*.vue" --include="*.js" -l .
```

**Missing tree-shaking (namespace imports):**
```bash
# Namespace imports prevent tree-shaking
grep -rn "import \* as" --include="*.ts" --include="*.vue" --include="*.js" . | grep -v node_modules
```

**Missing code splitting for routes:**
```bash
# Check if route components use dynamic imports
grep -r "component:" --include="*.ts" --include="*.js" router/ 2>/dev/null | grep -v "() =>"
```

**Duplicate dependency detection:**
```bash
# Check for multiple versions of the same package
ls node_modules/.pnpm/ 2>/dev/null | sort | uniq -d -w 20 | head -10
```

**Image assets without optimization:**
```bash
# Find large unoptimized images
find . -path ./node_modules -prune -o \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" \) -size +100k -print
```

### 1.5 Write Bundle Report

Write findings to `${SESSION_TMP_DIR}/bundle-analysis.md`:
- Total sizes (raw and gzipped)
- Top 10 largest chunks
- Top 10 largest dependencies
- Optimization opportunities with estimated savings

---

## Phase 2: RUNTIME — Code Pattern Analysis

Skip this phase if mode is `bundle` or `lighthouse`.

### 2.1 Vue-Specific Anti-Patterns

Scan source files for performance anti-patterns. Use the patterns from `references/main.md`.

**Reactive overhead:**
- Reactive objects in module scope (should be in `setup()` or composables)
- Missing `shallowRef` / `shallowReactive` for large objects that do not need deep reactivity
- Large reactive arrays without virtual scrolling

**Render performance:**
- Missing `v-once` on static content in frequently re-rendered components
- Computed properties with side effects (should be pure)
- Inline function creation in templates (`@click="() => handleClick(item)"` in `v-for`)
- `v-if` vs `v-show` misuse: frequent toggle should use `v-show`, rare toggle should use `v-if`

**Watcher issues:**
- Deep watchers on large objects (`{ deep: true }` on complex state)
- Watchers without cleanup (missing `onUnmounted` or `onScopeDispose`)
- Watchers that trigger other watchers (cascading updates)

### 2.2 Data Fetching Patterns

Scan for data fetching issues:

**N+1 query patterns:**
```bash
# Fetch calls inside loops or v-for setup
grep -rn "\.forEach\|\.map\|for (" --include="*.ts" --include="*.vue" -A 5 . | grep -B 3 "fetch\|getDoc\|getDocs\|\$fetch"
```

**Missing request deduplication:**
- Multiple components fetching the same data independently
- No caching layer for repeated API calls

**Unbounded collection queries:**
```bash
# Firestore queries without limit
grep -rn "getDocs\|collection(" --include="*.ts" --include="*.vue" . | grep -v "limit\|where"
```

**Waterfall data fetching:**
- Sequential `await` calls that could run in parallel with `Promise.all`
```bash
grep -rn "await.*await" --include="*.ts" --include="*.vue" . | grep -v node_modules
```

### 2.3 Memory Patterns

Scan for memory leak patterns:

**Event listeners without removal:**
```bash
grep -rn "addEventListener\|window\.on\|document\.on" --include="*.ts" --include="*.vue" . | grep -v node_modules
```
Cross-reference with `removeEventListener` or `onUnmounted` cleanup.

**Intervals without cleanup:**
```bash
grep -rn "setInterval\|setTimeout" --include="*.ts" --include="*.vue" . | grep -v node_modules
```
Cross-reference with `clearInterval` or `clearTimeout` in cleanup hooks.

**Growing arrays without bounds:**
- Arrays that are pushed to but never trimmed
- History/log arrays without maximum size limits

**Closure-based memory leaks:**
- Large objects captured in closures passed to long-lived callbacks
- Closures referencing DOM elements in detached trees

### 2.4 Write Runtime Report

Write findings to `${SESSION_TMP_DIR}/runtime-analysis.md`:
- Anti-patterns found with file:line references
- Severity classification per finding
- Specific fix recommendations

---

## Phase 3: LIGHTHOUSE — Core Web Vitals

Skip this phase if mode is `bundle` or `runtime`.

### 3.1 Check for Profiling Tools

Use ToolSearch to check for available browser automation tools:

```
ToolSearch: "chrome lighthouse"
ToolSearch: "playwright browser"
```

Determine the best approach:
1. Chrome DevTools MCP `lighthouse_audit` tool (preferred)
2. Playwright MCP for page analysis
3. CLI-based `npx lighthouse` (fallback)

### 3.2 Start Dev Server

```bash
# Start dev server in background
npm run dev > ${SESSION_TMP_DIR}/dev-server.log 2>&1 &
DEV_PID=$!
echo "DEV_PID=${DEV_PID}" > ${SESSION_TMP_DIR}/dev-server.pid

# Wait for server to be ready (check for listening port)
for i in $(seq 1 30); do
  curl -s -o /dev/null http://localhost:3000 && break
  sleep 2
done
```

If the server does not start within 60 seconds, skip Lighthouse and note in the report.

### 3.3 Run Lighthouse Audit

**Using Chrome DevTools MCP (preferred):**
Use the `lighthouse_audit` tool if available.

**Using CLI fallback:**
```bash
npx lighthouse http://localhost:3000 \
  --output=json \
  --output-path=${SESSION_TMP_DIR}/lighthouse.json \
  --chrome-flags="--headless --no-sandbox" \
  --only-categories=performance \
  2>&1 | tee ${SESSION_TMP_DIR}/lighthouse-cli.log
```

### 3.4 Parse Lighthouse Results

Extract Core Web Vitals from the results:

| Metric | Target (Good) | Needs Improvement | Poor |
|--------|--------------|-------------------|------|
| LCP (Largest Contentful Paint) | < 2.5s | 2.5s - 4.0s | > 4.0s |
| FID/INP (Interaction to Next Paint) | < 200ms | 200ms - 500ms | > 500ms |
| CLS (Cumulative Layout Shift) | < 0.1 | 0.1 - 0.25 | > 0.25 |
| FCP (First Contentful Paint) | < 1.8s | 1.8s - 3.0s | > 3.0s |
| TTFB (Time to First Byte) | < 0.8s | 0.8s - 1.8s | > 1.8s |

Also extract:
- Overall performance score (0-100)
- Opportunities (specific optimizations Lighthouse suggests)
- Diagnostics (additional performance insights)

### 3.5 Stop Dev Server

```bash
if [ -f "${SESSION_TMP_DIR}/dev-server.pid" ]; then
  DEV_PID=$(grep DEV_PID ${SESSION_TMP_DIR}/dev-server.pid | cut -d= -f2)
  kill $DEV_PID 2>/dev/null
  wait $DEV_PID 2>/dev/null
fi
```

### 3.6 Write Lighthouse Report

Write findings to `${SESSION_TMP_DIR}/lighthouse-report.md`:
- Core Web Vitals with pass/fail against targets
- Performance score
- Top opportunities with estimated savings
- Diagnostic insights

---

## Phase 4: REPORT — Generate Consolidated Findings

### 4.1 Compile All Findings

Read all mode-specific reports from `SESSION_TMP_DIR` and compile into a unified report.

### 4.2 Categorize Findings

Use the same severity levels as codebase-audit for compatibility:

| Severity | Criteria |
|----------|----------|
| **Critical** | Bundle > 500KB gzipped, CWV in "poor" range, confirmed memory leaks |
| **High** | Bundle > 250KB gzipped, N+1 queries, missing code splitting on routes, CWV in "needs improvement" range |
| **Medium** | Optimization opportunities with measurable impact, minor anti-patterns, missing lazy loading on non-critical paths |
| **Low** | Nice-to-have improvements, style-level optimizations, marginal size reductions |

### 4.3 Write Consolidated Report

Write `${SESSION_TMP_DIR}/perf-profile.md`:

```markdown
# Performance Profile Report

**Date**: YYYY-MM-DD
**Stack**: <detected stack>
**Modes**: <bundle|runtime|lighthouse|full>

## Bundle Analysis
- Total size: NKB (gzipped: NKB)
- Target: < 250KB gzipped
- Status: PASS/WARN/FAIL

### Largest Chunks
| Chunk | Raw | Gzipped |
|-------|-----|---------|
| ... | ... | ... |

### Optimization Opportunities
1. ...
2. ...

## Runtime Analysis
- Anti-patterns found: N
- Memory leak risks: N

### Findings
...

## Lighthouse Results
- Performance score: N/100
- LCP: Ns (target: < 2.5s) — PASS/FAIL
- INP: Nms (target: < 200ms) — PASS/FAIL
- CLS: N (target: < 0.1) — PASS/FAIL
- FCP: Ns (target: < 1.8s) — PASS/FAIL
- TTFB: Ns (target: < 0.8s) — PASS/FAIL

## Summary
Findings: N critical, N high, N medium, N low
```

### 4.4 Print Summary

Print a concise summary to the user:

```
Performance Profile: <stack>
============================
  Bundle: NKB gzipped (target: <250KB) — PASS/WARN/FAIL
  LCP: Ns (target: <2.5s) — PASS/FAIL/SKIPPED
  INP: Nms (target: <200ms) — PASS/FAIL/SKIPPED
  CLS: N (target: <0.1) — PASS/FAIL/SKIPPED

  Findings: N critical, N high, N medium, N low

  Top optimizations:
    1. <description> (estimated savings: NKB / Nms)
    2. <description> (estimated savings: NKB / Nms)
    3. <description> (estimated savings: NKB / Nms)

  Full report: ${SESSION_TMP_DIR}/perf-profile.md
```

### 4.5 Follow-Up Suggestions

| Condition | Suggested Skill | Rationale |
|---|---|---|
| Large bundle with code splitting issues | `refactor` | Split large modules, add dynamic imports |
| Runtime anti-patterns found | `refactor` | Fix performance anti-patterns |
| Failed Lighthouse audit | `ui-build` | Optimize rendering and layout |
| Memory leaks detected | `fix-issue` | Fix specific leak patterns |
| Low completeness score | `completeness-gate` | Check for incomplete implementations affecting perf |

### 4.6 Session Cleanup

1. Update `.cc-sessions/${SESSION_ID}.json`: set `status` to `completed`
2. Release any held locks
3. Kill any remaining dev server processes
4. Append `session_end` to the operations log

---

## Error Recovery

- **Build fails**: Skip bundle analysis. Focus on runtime patterns. Note in report: "Bundle analysis skipped — build failed. Fix build errors first."
- **No dev server can be started**: Skip Lighthouse. Note in report: "Lighthouse skipped — dev server could not be started."
- **Chrome/Playwright not available for Lighthouse**: Try CLI `npx lighthouse` as fallback. If that also fails, skip Lighthouse and note in report.
- **`cost-of-modules` or analysis tools not available**: Use fallback size estimation from `node_modules` directory sizes and build output parsing.
- **Lighthouse times out**: Report partial results if available. Note timeout in report.
- **Dev server started but port conflict**: Try alternative ports (3001, 8080). If all fail, skip Lighthouse.
- **No source files found**: Report "No source files found in scope" and stop.
- **Monorepo with multiple apps**: Ask user which app/package to profile. Default to the root if it has a build command.
