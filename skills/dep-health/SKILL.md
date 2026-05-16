---
name: dep-health
description: "Audits npm dependencies for known vulnerabilities (npm audit), outdated versions, and license compliance. Modes: audit (read-only scan), upgrade (interactive bumps), report (CSV/JSON output). Use when the user says 'check deps', 'dep-health', 'audit dependencies', 'security vulnerabilities', 'outdated packages', 'license check', or as a recurring weekly sweep."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch
model: sonnet
effort: medium
compatibility: ">=2.1.71"
argument-hint: "<mode> -- audit (read-only CVE scan + outdated check) | upgrade (interactive bumps with breaking-change notes) | report (CSV/JSON output with license compliance + transitive risk)"
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For package manager commands, license tables, and report templates, see [references/main.md](references/main.md)
- For package install policy (canonical rule for `upgrade` mode resolution), see [/_shared/package-install-policy.md](/_shared/package-install-policy.md). dep-health is the periodic enforcer — every flagged outdated dep gets a recommended bump using the latest-resolution rule.
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Dependency Health Audit

Analyze npm packages for security vulnerabilities, outdated versions, license compliance, and overall health. Execute every phase in order. Do NOT skip phases.

---

All code produced must satisfy the [Definition of Done](/_shared/definition-of-done.md). No placeholder implementations.

## SAFETY RULES (NON-NEGOTIABLE)

1. **NEVER auto-upgrade major versions** — major bumps require explicit user confirmation before proceeding.
2. **NEVER edit lock files manually** — `package-lock.json`, `pnpm-lock.yaml`, and `yarn.lock` are managed by the package manager only.
3. **NEVER install packages globally** — all installs use `--save-dev` or `--save` (local only).
4. **ALWAYS run tests after any upgrade** — if tests fail, revert the upgrade immediately.
5. **ALWAYS verify build passes after upgrades** — a green test suite with a broken build is still broken.
6. **In `audit` mode, this skill is READ-ONLY** — no modifications to `package.json`, lock files, or source code.
7. **NEVER remove dependencies** without explicit user instruction — even if they appear unused.
8. **NEVER run `npm audit fix --force`** — it performs major upgrades without verification.

---

## Phase 0: PARSE — Determine Mode

### 0.0 Register Session

Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

### 0.1 Parse Mode

Extract the mode from `$ARGUMENTS`:
- `audit` (default if no argument): Security scan + outdated check. **Read-only mode.**
- `upgrade`: Patch and minor upgrades with verification. **Modifies `package.json` and lock files.**
- `report`: Generate comprehensive health report with all data. **Read-only mode.**

If mode is not recognized, default to `audit` and inform the user.

### 0.2 Detect Package Manager

Determine the package manager by checking for lock files:

```bash
if [ -f "pnpm-lock.yaml" ]; then echo "PM=pnpm"
elif [ -f "yarn.lock" ]; then echo "PM=yarn"
elif [ -f "package-lock.json" ]; then echo "PM=npm"
else echo "PM=UNKNOWN"
fi
```

If no lock file is found, check `package.json` for a `packageManager` field. If still unknown, abort with: `"No package manager detected. Ensure a lock file exists."`

Store the result as `PM` for use in all subsequent commands.

### 0.3 Validate Environment

```bash
# Verify package.json exists
[ -f "package.json" ] && echo "FOUND" || echo "NOT FOUND"

# Verify node_modules exists
[ -d "node_modules" ] && echo "INSTALLED" || echo "NOT INSTALLED"
```

If `node_modules` is missing, warn: `"Dependencies not installed. Run '${PM} install' first."` and abort.

### 0.4 Read Package Metadata

Read `package.json` and extract:
- **Project name and version**
- **Dependency count**: `dependencies`, `devDependencies`, `peerDependencies`
- **Total package count**: Sum of all dependency groups

---

## Phase 1: AUDIT — Security Scan

### 1.1 Run Security Audit

Execute the appropriate audit command (see [references/main.md](references/main.md) for PM-specific variants):

```bash
${PM} audit --json 2>&1 ```

If the command exits with a non-zero code, it indicates vulnerabilities were found (this is expected — do not treat as a failure).

### 1.2 Parse Audit Results

Extract from the JSON output:
- **Vulnerability count** by severity (critical, high, moderate, low)
- **Affected packages**: package name, installed version, vulnerability title
- **CVE IDs** (if available)
- **Fix available**: Whether a patched version exists
- **Recommended fix version**: The version that resolves the vulnerability

### 1.3 Categorize Vulnerabilities

| Severity | Description | Action Required |
|----------|-------------|----------------|
| **Critical** | Remote code execution, authentication bypass, data exposure | Immediate fix required |
| **High** | Privilege escalation, XSS, significant data leak potential | Fix within current sprint |
| **Moderate** | Denial of service, information disclosure under specific conditions | Fix in next maintenance window |
| **Low** | Theoretical vulnerability, requires unlikely conditions | Track and fix opportunistically |

---

## Phase 2: OUTDATED — Version Check

### 2.1 Check Outdated Packages

```bash
${PM} outdated --json 2>&1 || true
```

The `|| true` ensures non-zero exit (which indicates outdated packages exist) does not abort the skill.

### 2.2 Parse Outdated Results

For each outdated package, extract:
- **Package name**
- **Current version** (installed)
- **Wanted version** (satisfies semver range in `package.json`)
- **Latest version** (latest on registry)
- **Dependency type** (production, dev, peer)

### 2.3 Classify Update Type

For each outdated package, determine the update type:

| Type | Detection | Risk |
|------|-----------|------|
| **Major** | Latest major > current major | High — breaking changes likely |
| **Minor** | Same major, latest minor > current minor | Medium — new features, possible behavior changes |
| **Patch** | Same major+minor, latest patch > current patch | Low — bug fixes only |

### 2.4 Flag Critical Outdated

Cross-reference outdated packages with audit results. Packages that are BOTH outdated AND have known CVEs are flagged as **critical outdated**.

---

## Phase 3: LICENSE — Compliance Check

### 3.1 Scan Licenses

Attempt to use `npx license-checker --json --production`:

```bash
npx license-checker --json --production 2>&1 | head -500
```

If `license-checker` fails or is unavailable, fall back to reading license fields from `node_modules/*/package.json`:

```bash
for dir in node_modules/*/; do
  pkg=$(basename "$dir")
  license=$(node -e "try{console.log(require('./${dir}package.json').license||'UNKNOWN')}catch{console.log('UNKNOWN')}")
  echo "${pkg}: ${license}"
done
```

### 3.2 Classify Licenses

Use the license classification table from [references/main.md](references/main.md):

| Classification | Licenses | Action |
|---------------|----------|--------|
| **Permissive** (safe) | MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC, 0BSD, Unlicense, CC0-1.0 | No action needed |
| **Weak copyleft** (review) | LGPL-2.1, LGPL-3.0, MPL-2.0, EPL-1.0, EPL-2.0 | Review usage context; typically safe for dependencies |
| **Strong copyleft** (flag) | GPL-2.0, GPL-3.0, AGPL-3.0, SSPL-1.0, EUPL-1.1 | Flag for legal review; may require source disclosure |
| **Unknown** (flag) | No license field, `UNLICENSED`, unrecognized string | Flag for review; may be proprietary |

### 3.3 Report License Issues

List all packages with non-permissive licenses. Group by classification.

---

## Phase 4: UPGRADE — Patch and Minor Updates (mode=upgrade only)

**Skip this phase entirely if mode is `audit` or `report`.**

### 4.1 Create Upgrade Branch

```bash
git checkout -b deps/patch-upgrades-$(date +%Y%m%d)
```

If the branch already exists, append a counter: `deps/patch-upgrades-YYYYMMDD-2`.

### 4.2 Snapshot Baseline

Run tests and type-check before any changes:

```bash
${PM} run type-check 2>&1 | tail -20
${PM} test 2>&1 | tail -30
```

Record baseline pass/fail counts.

### 4.3 Upgrade Patches

Run the package manager's update command for patch versions only:

```bash
# npm
npm update 2>&1

# pnpm
pnpm update 2>&1

# yarn
yarn upgrade 2>&1
```

After updating:

1. Run type-check:
   ```bash
   ${PM} run type-check 2>&1 | tail -20
   ```
2. Run tests:
   ```bash
   ${PM} test 2>&1 | tail -30
   ```
3. If either fails, identify which package caused the failure:
   - Revert `package.json` and lock file to pre-update state
   - Upgrade packages one at a time, testing after each
   - Skip packages that cause failures and note them
4. Commit successful patch upgrades:
   ```bash
   git add package.json ${LOCKFILE}
   git commit -m "chore(deps): patch-level dependency upgrades"
   ```

### 4.4 Upgrade Minors (with confirmation)

List all available minor upgrades:

```
Minor upgrades available:
  1. package-a: 2.1.0 -> 2.3.0
  2. package-b: 1.4.2 -> 1.7.0
  3. package-c: 3.0.1 -> 3.2.4

Proceed with all minor upgrades? (The skill will test each individually and revert failures.)
```

For each confirmed minor upgrade:

1. Install the specific version:
   ```bash
   ${PM} install package@version
   ```
2. Run type-check + tests
3. If either fails, revert that specific upgrade and note it as failed
4. Commit each successful minor upgrade individually:
   ```bash
   git add package.json ${LOCKFILE}
   git commit -m "chore(deps): upgrade package-name to vX.Y.Z"
   ```

### 4.5 Major Upgrade Advisories

List available major upgrades but do NOT perform them automatically:

```
Major upgrades available (manual action required):
  1. package-x: 2.5.0 -> 3.0.0 — See changelog: <url>
  2. package-y: 1.8.0 -> 2.0.0 — See changelog: <url>

Major upgrades may include breaking changes. Review changelogs before upgrading.
```

---

## Phase 5: REPORT — Generate Health Report

### 5.1 Calculate Health Score

Start at 100 and deduct points:

| Category | Deduction |
|----------|-----------|
| Critical CVE | -20 each |
| High CVE | -10 each |
| Moderate CVE | -3 each |
| Low CVE | -1 each |
| Major version behind | -5 each |
| Minor version behind | -1 each |
| Strong copyleft license | -10 each |
| Unknown license | -5 each |

Clamp to 0-100.

Assign grade:
| Score | Grade |
|-------|-------|
| 90-100 | A |
| 80-89 | B |
| 70-79 | C |
| 60-69 | D |
| < 60 | F |

### 5.2 Write Report

Write the full report to `${SESSION_TMP_DIR}/dep-health-report.md` using the template from [references/main.md](references/main.md).

The report includes:
- Summary table with health score and grade
- Vulnerabilities section with CVE links and fix recommendations
- Outdated packages table (package, current, latest, type of change)
- License compliance table with classification
- Recommended actions prioritized by impact

### 5.3 Print Summary

Print a concise summary to the user:

```
Dependency Health: <GRADE> (<score>/100)
  Vulnerabilities: N critical, N high, N moderate, N low
  Outdated: N major, N minor, N patch behind
  License issues: N flagged

Top priorities:
  1. [critical] package-name has CVE-XXXX-XXXXX — upgrade to vX.Y.Z
  2. [high] package-name is 2 major versions behind
  3. [medium] package-name has GPL-3.0 license
```

Show up to 10 priorities, ordered by severity.

If mode is `audit` or `report`, also print:
```
Full report: ${SESSION_TMP_DIR}/dep-health-report.md
Run '/dep-health upgrade' to apply safe upgrades.
```

### 5.4 Follow-Up Suggestions

| Condition | Suggested Skill | Rationale |
|---|---|---|
| Critical CVEs found | `dep-health upgrade` | Apply security patches immediately |
| Major versions behind | `research` | Research migration guides for major upgrades |
| License issues found | Manual review | Legal team should review copyleft dependencies |
| Post-upgrade test failures | `fix-issue` | Investigate and fix compatibility issues |

### 5.5 Session Cleanup

1. Update `.cc-sessions/${SESSION_ID}.json`: set `status` to `completed`
2. Release any held locks
3. Append `session_end` to the operations log

---

## Error Recovery

- **`npm audit` fails (no internet, registry down)**: Skip the security scan. Note `"Security audit skipped: registry unreachable"` in the report. Continue with outdated and license checks.
- **`license-checker` not available**: Use the fallback grep-based license detection described in Phase 3.1. Note reduced accuracy in report.
- **Upgrade breaks tests**: Automatically revert the specific package upgrade. Report which package caused the failure and what tests broke. Continue with remaining upgrades.
- **Upgrade breaks type-check**: Same as test failure — revert and report.
- **No `package.json` found**: Abort with `"No package.json found in project root. This skill requires an npm-based project."`.
- **`node_modules` not installed**: Abort with `"Dependencies not installed. Run '${PM} install' before running dep-health."`.
- **Git working tree is dirty (mode=upgrade)**: Warn `"Uncommitted changes detected. Commit or stash before running upgrades."` and abort upgrade mode. Audit and report modes proceed normally.
- **Package manager command not found**: Abort with `"${PM} is not installed. Install it globally or use a different package manager."`.
- **Monorepo detected**: Scan root `package.json` first. If workspace packages exist, note them and suggest running the skill in each workspace directory separately.
