# Codebase Map — Reference Material

Dimension-agent prompt template, quality scoring rubric, dimension checklists, and example output formats for the codebase-map skill.

---

## Dimension Agent Prompt Template

<!-- import: /_shared/agent-orchestration.md -->
Canonical boilerplate sections (Generic Agent Preamble, Medium BUDGET, WRITE-AS-YOU-GO, HEARTBEAT file-append form, CONFIRMATION) are documented in [/_shared/agent-orchestration.md](/_shared/agent-orchestration.md). The inline template below remains the byte-stable spawn source — OUTPUT STYLE inline preservation is required by sprint-review Invariant 5.

Used by the main skill in Phase 1 when spawning the 4 parallel dimension agents. Variables: `{{DIMENSION}}`, `{{OUTPUT_PATH}}`, `{{INVENTORY_DIR}}`, `{{FILE_CAP}}`, `{{STACK_PROFILE}}`, `{{CHECKLIST}}`.

```
You are a codebase-map {{DIMENSION}} dimension analyst.

You are a general-purpose agent with Write access. Your task is INCOMPLETE
if {{OUTPUT_PATH}} does not exist when you finish.

BUDGET (Medium class — see skills/_shared/agent-orchestration.md):
- Max file reads: {{FILE_CAP}}
- Max web searches: 0 (pure codebase analysis)
- Max tool calls: 25
- Max output: 250 lines
- Wall-clock: 5 minutes

WRITE-AS-YOU-GO (MANDATORY):
1. Before your first tool call, stub the file:
     Write({{OUTPUT_PATH}}, "# {{DIMENSION}}\n# IN PROGRESS\n")
2. After each checklist item analyzed, append a section to the file.
3. Do NOT accumulate findings in memory.

HEARTBEAT (recommended):
At the start of each phase of your analysis, append this line to your output file:
  HEARTBEAT: <phase-name> at <ISO-8601-timestamp>
Use at least 3 heartbeats. Use Bash `date -u +%Y-%m-%dT%H:%M:%SZ` for timestamp.

INPUTS (read from shared inventory — do NOT re-scan the codebase):
- Source file list:  {{INVENTORY_DIR}}/source-files.txt
- Directory tree:    {{INVENTORY_DIR}}/dir-tree.txt
- Package config:    {{INVENTORY_DIR}}/config-package.json (and other config-*.json)

STACK PROFILE:
{{STACK_PROFILE}}

YOUR CHECKLIST:
{{CHECKLIST}}

OUTPUT FORMAT: Plain markdown sections matching the checklist. No top-level
heading — the orchestrator adds `## {{DIMENSION}}` when assembling CODEBASE-MAP.md.

CONFIRMATION: When done, emit one line: "{{DIMENSION}}: <N sections, K lines>"
Do NOT echo findings in your response.

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles,
fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code,
URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows,
error codes, dates, version numbers. No preamble. No trailing summary of work
already evident in the diff or tool output. Format: fragments OK.
```

**Per-dimension checklist content is in the "Dimension Checklists" section below.** The orchestrator fills `{{CHECKLIST}}` with the appropriate sub-section.

---

## Quality Scoring Rubric

Each dimension is scored on a 1-5 scale:

| Score | Label | Meaning |
|-------|-------|---------|
| 5 | Excellent | Industry best practices, well-documented, consistent |
| 4 | Good | Minor gaps, mostly consistent, functional |
| 3 | Adequate | Some issues, inconsistent in places, works but fragile |
| 2 | Poor | Significant issues, inconsistent, technical debt |
| 1 | Critical | Broken, missing critical patterns, blocking development |

### Overall Score
```
Overall = (Technology × 0.2) + (Architecture × 0.3) + (Quality × 0.3) + (Concerns × 0.2)
```

Architecture and Quality are weighted higher because they most directly impact development velocity.

---

## Dimension Checklists

### Technology Dimension
- [ ] Framework and version identified
- [ ] Package manager identified
- [ ] Build tool identified
- [ ] Test runner identified
- [ ] CSS framework/approach identified
- [ ] State management approach identified
- [ ] Backend/API approach identified
- [ ] TypeScript configuration assessed
- [ ] Dependency health (outdated count, vulnerability count)
- [ ] Monorepo structure (if applicable)

### Architecture Dimension
- [ ] Directory structure mapped (2-3 levels)
- [ ] Layer separation assessed (pages, components, stores, services, types)
- [ ] Routing approach documented
- [ ] State management patterns documented
- [ ] API integration patterns documented
- [ ] Shared code organization assessed
- [ ] Circular dependency check
- [ ] Module boundary clarity
- [ ] Entry points identified
- [ ] Build output structure

### Quality Dimension
- [ ] TypeScript strictness level
- [ ] Test coverage (estimated from test file count vs source file count)
- [ ] Linting configuration present and enforced
- [ ] Consistent naming conventions
- [ ] Error handling patterns
- [ ] Loading/empty/error state patterns (for UI projects)
- [ ] Code duplication assessment
- [ ] Documentation presence (JSDoc, README, inline comments)
- [ ] Git hygiene (commit message format, branch strategy)
- [ ] CI/CD pipeline present

### Concerns Dimension
- [ ] Authentication/authorization patterns
- [ ] Input validation approach
- [ ] Secrets management (no hardcoded secrets)
- [ ] CORS and security headers
- [ ] Performance patterns (lazy loading, caching, pagination)
- [ ] Accessibility compliance
- [ ] Internationalization readiness
- [ ] Logging and monitoring
- [ ] Error reporting (Sentry, etc.)
- [ ] Environment configuration management

---

## Example Output Format

```markdown
# Codebase Map: <project-name>

Generated: <date>
Overall Score: 3.6/5.0

## Technology Profile
| Attribute | Value |
|-----------|-------|
| Framework | Nuxt 3.8 |
| Language | TypeScript 5.3 (strict) |
| Package Manager | pnpm 8.x |
| Test Runner | Vitest 1.x |
| CSS | Tailwind CSS 3.x |
| State | Pinia |
| Backend | Nitro (server/) |

Score: 4/5 — Modern stack, well-configured.

## Architecture
<Mermaid diagram>

Score: 3/5 — Good layer separation but some circular dependencies in stores.

## Quality
Score: 3/5 — TypeScript strict mode on, but test coverage is ~40%.

## Concerns
Score: 4/5 — Auth middleware present, input validation via Zod.

## Recommendations
1. [High] Add tests for stores/ directory (0% coverage)
2. [Medium] Resolve circular dependency: stores/auth ↔ stores/user
3. [Low] Add JSDoc to exported composables
```

---

## Grep Patterns for Detection

| What | Pattern | Files |
|------|---------|-------|
| Framework | `"nuxt"`, `"vue"`, `"react"`, `"next"`, `"svelte"` in package.json | `package.json` |
| TypeScript strict | `"strict": true` | `tsconfig.json` |
| Test files | `*.test.*`, `*.spec.*` | `**/*` |
| Store files | `defineStore`, `createStore` | `*.ts` |
| Composables | `export function use` | `*.ts` |
| API routes | `defineEventHandler`, `export default` in server/ | `server/**/*.ts` |
| Auth patterns | `middleware/auth`, `requireAuth`, `verifyIdToken` | `*.ts` |
| Zod schemas | `z.object`, `z.string`, `z.number` | `*.ts` |
