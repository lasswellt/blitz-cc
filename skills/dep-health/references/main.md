# Dependency Health: Reference Material

Package manager command variants, license classification, health score formula, report templates for dep-health skill.

---

## Package Manager Command Variants

| Operation | npm | pnpm | yarn |
|-----------|-----|------|------|
| **Security audit** | `npm audit --json` | `pnpm audit --json` | `yarn audit --json` |
| **Security audit (prod only)** | `npm audit --json --omit=dev` | `pnpm audit --json --prod` | `yarn audit --json --groups dependencies` |
| **Check outdated** | `npm outdated --json` | `pnpm outdated --json` | `yarn outdated --json` |
| **Update patches** | `npm update` | `pnpm update` | `yarn upgrade` |
| **Install specific version** | `npm install pkg@version` | `pnpm add pkg@version` | `yarn add pkg@version` |
| **Install dev dependency** | `npm install -D pkg@version` | `pnpm add -D pkg@version` | `yarn add -D pkg@version` |
| **List installed** | `npm ls --json --depth=0` | `pnpm ls --json --depth=0` | `yarn list --json --depth=0` |
| **List licenses** | `npx license-checker --json` | `npx license-checker --json` | `npx license-checker --json` |
| **List licenses (prod)** | `npx license-checker --json --production` | `npx license-checker --json --production` | `npx license-checker --json --production` |
| **Lock file** | `package-lock.json` | `pnpm-lock.yaml` | `yarn.lock` |
| **Clean install** | `npm ci` | `pnpm install --frozen-lockfile` | `yarn install --frozen-lockfile` |

### Audit JSON Output Differences

**npm audit** returns:
```json
{
  "vulnerabilities": {
    "package-name": {
      "name": "package-name",
      "severity": "high",
      "via": [{ "title": "Prototype Pollution", "url": "https://github.com/advisories/..." }],
      "range": "<1.2.3",
      "fixAvailable": { "name": "package-name", "version": "1.2.3" }
    }
  }
}
```

**pnpm audit** returns:
```json
{
  "advisories": {
    "1234": {
      "module_name": "package-name",
      "severity": "high",
      "title": "Prototype Pollution",
      "url": "https://npmjs.com/advisories/1234",
      "patched_versions": ">=1.2.3"
    }
  }
}
```

**yarn audit** returns NDJSON (one JSON object per line):
```json
{"type":"auditAdvisory","data":{"advisory":{"module_name":"package-name","severity":"high","title":"Prototype Pollution","url":"...","patched_versions":">=1.2.3"}}}
```

Parse per detected package manager.

---

## License Classification Table

### Permissive Licenses (Safe)

| License | SPDX ID | Notes |
|---------|---------|-------|
| MIT License | `MIT` | Most common OSS license. No restrictions. |
| Apache License 2.0 | `Apache-2.0` | Patent grant. Requires attribution, notice of changes. |
| BSD 2-Clause | `BSD-2-Clause` | Minimal restrictions. Attribution required. |
| BSD 3-Clause | `BSD-3-Clause` | 2-Clause plus non-endorsement clause. |
| ISC License | `ISC` | Equivalent to MIT. |
| Zero-Clause BSD | `0BSD` | No requirements. |
| The Unlicense | `Unlicense` | Public domain dedication. |
| CC0 1.0 | `CC0-1.0` | Public domain dedication (Creative Commons). |
| WTFPL | `WTFPL` | Permissive, no restrictions. |
| Zlib License | `Zlib` | Permissive, MIT-like. |

### Weak Copyleft Licenses (Review Required)

| License | SPDX ID | Notes |
|---------|---------|-------|
| LGPL 2.1 | `LGPL-2.1` | Copyleft on modifications to library; not on consuming code. Safe for as-is npm use. |
| LGPL 3.0 | `LGPL-3.0` | Like LGPL-2.1 with additions. Safe for unmodified npm use. |
| Mozilla Public License 2.0 | `MPL-2.0` | File-level copyleft. MPL file mods must be shared; your files unaffected. |
| Eclipse Public License 1.0 | `EPL-1.0` | MPL-like. Module-level copyleft. |
| Eclipse Public License 2.0 | `EPL-2.0` | Updated EPL with secondary license option. |
| Common Development and Distribution License | `CDDL-1.0` | File-level copyleft, MPL-like. |

### Strong Copyleft Licenses (Flag for Legal Review)

| License | SPDX ID | Risk | Notes |
|---------|---------|------|-------|
| GPL 2.0 | `GPL-2.0` | High | Derivatives must be GPL. Dependency use may trigger copyleft per linking. |
| GPL 3.0 | `GPL-3.0` | High | GPL-2.0 plus anti-tivoization, patent grants. |
| AGPL 3.0 | `AGPL-3.0` | Very High | Network use triggers copyleft. Network-accessible app using AGPL lib may require source release. |
| Server Side Public License | `SSPL-1.0` | Very High | MongoDB's license. Broad copyleft for SaaS offerings. |
| European Union Public License | `EUPL-1.1` | High | Strong copyleft, broad scope. |

### Special Cases

| License | SPDX ID | Action |
|---------|---------|--------|
| No license detected | `UNKNOWN` | Flag: may be proprietary. Check repo for LICENSE file. |
| `UNLICENSED` | `UNLICENSED` | Flag: explicitly proprietary. Do not use without separate agreement. |
| Dual license | `(MIT OR GPL-3.0)` | Use more permissive option (MIT here). |
| Custom license | N/A | Flag for manual review. Read license text in package. |

---

## Health Score Formula

### Base Calculation

```
score = 100
score -= (critical_cves * 20)
score -= (high_cves * 10)
score -= (moderate_cves * 3)
score -= (low_cves * 1)
score -= (major_versions_behind * 5)
score -= (minor_versions_behind * 1)
score -= (strong_copyleft_licenses * 10)
score -= (unknown_licenses * 5)
score = clamp(score, 0, 100)
```

### Grade Assignment

| Score Range | Grade | Interpretation |
|-------------|-------|---------------|
| 90-100 | A | Excellent: deps well-maintained, secure |
| 80-89 | B | Good: minor issues; address next maintenance window |
| 70-79 | C | Fair: notable issues; address soon |
| 60-69 | D | Poor: significant security/compliance risks |
| 0-59 | F | Critical: immediate action required |

### Worked Examples

**Example 1: Healthy project**
```
Starting score: 100
Vulnerabilities: 0 critical, 0 high, 2 moderate, 3 low
  Deductions: -(2*3) -(3*1) = -9
Outdated: 0 major, 4 minor
  Deductions: -(4*1) = -4
Licenses: all permissive
  Deductions: 0
Final score: 100 - 9 - 4 = 87 (Grade: B)
```

**Example 2: Neglected project**
```
Starting score: 100
Vulnerabilities: 1 critical, 3 high, 5 moderate, 8 low
  Deductions: -(1*20) -(3*10) -(5*3) -(8*1) = -73
Outdated: 5 major, 12 minor
  Deductions: -(5*5) -(12*1) = -37
Licenses: 1 GPL-3.0, 2 unknown
  Deductions: -(1*10) -(2*5) = -20
Raw score: 100 - 73 - 37 - 20 = -30
Final score: 0 (clamped) (Grade: F)
```

**Example 3: Security-focused but outdated**
```
Starting score: 100
Vulnerabilities: 0 critical, 0 high, 0 moderate, 0 low
  Deductions: 0
Outdated: 3 major, 8 minor
  Deductions: -(3*5) -(8*1) = -23
Licenses: all permissive
  Deductions: 0
Final score: 100 - 23 = 77 (Grade: C)
```

---

## Report Template

Template for full dependency health report written to `${SESSION_TMP_DIR}/dep-health-report.md`:

```markdown
# Dependency Health Report

**Date**: YYYY-MM-DD
**Project**: <project-name>
**Package Manager**: <npm|pnpm|yarn>
**Total Dependencies**: N (N production, N dev)

---

## Health Score: XX/100 (Grade: X)

| Category | Count | Deduction | Subtotal |
|----------|-------|-----------|----------|
| Critical CVEs | N | -20 each | -NN |
| High CVEs | N | -10 each | -NN |
| Moderate CVEs | N | -3 each | -NN |
| Low CVEs | N | -1 each | -NN |
| Major versions behind | N | -5 each | -NN |
| Minor versions behind | N | -1 each | -NN |
| Strong copyleft licenses | N | -10 each | -NN |
| Unknown licenses | N | -5 each | -NN |
| **Total deductions** | | | **-NN** |

---

## Security Vulnerabilities

### Critical

| Package | Vulnerability | CVE | Fix Available | Recommended Version |
|---------|-------------|-----|---------------|-------------------|
| <pkg> | <title> | <CVE-ID> | Yes/No | <version> |

### High

| Package | Vulnerability | CVE | Fix Available | Recommended Version |
|---------|-------------|-----|---------------|-------------------|
| <pkg> | <title> | <CVE-ID> | Yes/No | <version> |

### Moderate

| Package | Vulnerability | CVE | Fix Available | Recommended Version |
|---------|-------------|-----|---------------|-------------------|
| <pkg> | <title> | <CVE-ID> | Yes/No | <version> |

### Low

| Package | Vulnerability | CVE | Fix Available | Recommended Version |
|---------|-------------|-----|---------------|-------------------|
| <pkg> | <title> | <CVE-ID> | Yes/No | <version> |

> If none: "No known vulnerabilities detected."

---

## Outdated Packages

### Major Updates Available

| Package | Current | Latest | Type | Has CVE |
|---------|---------|--------|------|---------|
| <pkg> | <current> | <latest> | production/dev | Yes/No |

### Minor Updates Available

| Package | Current | Latest | Type | Has CVE |
|---------|---------|--------|------|---------|
| <pkg> | <current> | <latest> | production/dev | Yes/No |

### Patch Updates Available

| Package | Current | Latest | Type | Has CVE |
|---------|---------|--------|------|---------|
| <pkg> | <current> | <latest> | production/dev | Yes/No |

> If all current: "All dependencies are up to date."

---

## License Compliance

### Flagged Licenses

| Package | License | Classification | Action Required |
|---------|---------|---------------|----------------|
| <pkg> | <license> | Strong copyleft/Unknown | Review/Legal review |

### Weak Copyleft (Review)

| Package | License | Notes |
|---------|---------|-------|
| <pkg> | <license> | <usage context> |

### Summary

- Permissive: N packages
- Weak copyleft: N packages
- Strong copyleft: N packages
- Unknown: N packages

> If all permissive: "All dependencies use permissive licenses."

---

## Recommended Actions

Prioritized actions to improve dependency health:

1. **[CRITICAL]** <action>: <rationale>
2. **[HIGH]** <action>: <rationale>
3. **[MEDIUM]** <action>: <rationale>
4. ...

---

## Upgrade Log

> Included only when mode=upgrade used.

| Package | From | To | Type | Tests | Build | Status |
|---------|------|----|------|-------|-------|--------|
| <pkg> | <old> | <new> | patch/minor | PASS/FAIL | PASS/FAIL | Applied/Reverted |
```
