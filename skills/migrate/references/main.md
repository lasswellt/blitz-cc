# Migration — Reference Material

Codemod registry, risk matrix, breaking-change templates, rollback procedures for migrate skill.

---

## Codemod Registry

Common migrations with automated transforms. Check availability before manual fallback.

### Frontend Framework Upgrades

| Migration | Codemod Package | Command | Coverage Notes |
|-----------|----------------|---------|----------------|
| Vue 2 → Vue 3 | `@vue/compat` | `npx @vue/compat` | Compat build; incremental migration. Covers ~90% of breaking changes. |
| Vue 2 → Vue 3 (transforms) | `vue-codemod` | `npx vue-codemod src/ --all` | AST transforms for template/script changes. |
| Vue 3.x → 3.y (minor) | N/A | Manual | Minor upgrades rarely have codemods; check changelog. |
| Nuxt 2 → Nuxt 3 | `nuxi` | `npx nuxi upgrade` | Handles config migration. Manual work for composables and `$fetch`. |
| Nuxt 3.x → 3.y | `nuxi` | `npx nuxi upgrade` | Usually handles minor upgrades cleanly. |
| React class → hooks | `react-codemod` | `npx react-codemod rename-unsafe-lifecycles` | Partial; complex components need manual work. |
| Angular N → N+1 | `@angular/cli` | `npx ng update @angular/core@<version>` | Best-in-class tooling. Usually handles everything. |

### Test Runner Migrations

| Migration | Codemod Package | Command | Coverage Notes |
|-----------|----------------|---------|----------------|
| Jest → Vitest | `jest-to-vitest` | `npx jest-to-vitest .` | Converts imports/config. Manual work for `jest.mock` → `vi.mock`. |
| Mocha → Vitest | N/A | Manual | No automated tool; rewrite describe/it imports and assertions. |
| Mocha → Jest | `jest-codemods` | `npx jest-codemods .` | Handles Mocha, Chai, Sinon → Jest. |
| Jasmine → Jest | `jest-codemods` | `npx jest-codemods .` | Good coverage for Jasmine syntax. |

### Linting & Formatting

| Migration | Codemod Package | Command | Coverage Notes |
|-----------|----------------|---------|----------------|
| ESLint legacy → flat config | `@eslint/migrate-config` | `npx @eslint/migrate-config .eslintrc.json` | Converts config format. Plugin compat verified manually. |
| ESLint 8 → 9 | `@eslint/migrate-config` | Same as above | Major change is flat config; codemod handles config, not rule changes. |
| TSLint → ESLint | `tslint-to-eslint-config` | `npx tslint-to-eslint-config` | Converts config/rules. Manual cleanup usually needed. |
| Prettier 2 → 3 | N/A | Manual | Minimal breaking changes; update config options manually. |

### Module System

| Migration | Codemod Package | Command | Coverage Notes |
|-----------|----------------|---------|----------------|
| CJS → ESM | `cjs-to-esm` | `npx cjs-to-esm .` | Converts `require()` to `import`. Skips dynamic requires. |
| CJS → ESM (TypeScript) | N/A | Manual | Add `"type": "module"` to `package.json`, update imports with extensions. |

### Build Tool Migrations

| Migration | Codemod Package | Command | Coverage Notes |
|-----------|----------------|---------|----------------|
| Webpack → Vite | `wp2vite` | `npx wp2vite` | Generates Vite config from webpack config. Manual adjustment usually needed. |
| Create React App → Vite | N/A | Manual | Delete CRA config, create `vite.config.ts`, update scripts. |
| Vue CLI → Vite | N/A | Manual | Similar to CRA migration. Remove `vue.config.js`, create `vite.config.ts`. |

### State Management

| Migration | Codemod Package | Command | Coverage Notes |
|-----------|----------------|---------|----------------|
| Vuex → Pinia | N/A | Manual | No automated tool. Rewrite stores one at a time. |
| Pinia 2 → Pinia 3 | N/A | Manual | Check changelog for breaking changes. Usually minimal. |
| Options API → Composition API | `vue-composition-api-codemod` | `npx vue-composition-api-codemod src/` | Partial; complex components need manual work. |

---

## Risk Assessment Matrix

Cross-reference affected files with breaking-change severity for overall migration risk.

### Files Affected × Breaking Change Severity

|  | No Breaking Changes | Minor Deprecations | API Renames/Removals | Architectural Changes |
|--|--------------------|--------------------|---------------------|-----------------------|
| **<10 files** | Low | Low | Medium | Medium |
| **10-30 files** | Low | Medium | Medium | High |
| **31-50 files** | Low | Medium | High | High |
| **51-100 files** | Medium | High | High | Critical |
| **>100 files** | Medium | High | Critical | Critical |

### Risk Level Definitions

| Risk Level | Description | Recommended Approach |
|-----------|-------------|---------------------|
| **Low** | Routine upgrade, minimal impact. | Proceed with standard verification gates. |
| **Medium** | Some breaking changes; codemods or clear paths exist. | Run codemods first, then manual fixes. Extra verification. |
| **High** | Significant breaking changes across many files. Manual work required. | Split into sub-migrations. Consider feature branch. Allow extra time. |
| **Critical** | Deep architectural changes or multiple simultaneous major upgrades. | Strongly consider incremental approach (intermediate versions first). May need dedicated sprint. |

---

## Breaking Change Analysis Template

Template to document each breaking change before migration.

```markdown
### Breaking Change: <title>

- **Package**: <package-name>
- **Version**: Removed/changed in <version>
- **Type**: API Removal | API Rename | Behavioral Change | Config Change | Type Change
- **Severity**: High | Medium | Low

#### What Changed
<Description of the change>

#### Pattern to Grep
```bash
grep -rn "<pattern>" --include="*.ts" --include="*.vue" . | grep -v node_modules
```

#### Files Affected
<N> files (list key files)

#### Migration Path
- [ ] Codemod available: <yes/no — package name>
- [ ] Manual fix: <description of what to change>
- [ ] Before: `<old code>`
- [ ] After: `<new code>`

#### Risk
<High | Medium | Low> — <brief justification>
```

---

## Rollback Procedure

Step-by-step rollback when automated rollback insufficient.

### Quick Rollback (Git-Based)

If migration commits were atomic and clean:
```bash
# Option 1: Reset to rollback branch
git log --oneline | head -20  # Review migration commits
git checkout <rollback-branch>
git branch -m main main-failed-migration  # Rename current main
git checkout -b main  # Create new main from rollback point

# Option 2: Revert migration commits
git revert --no-commit <oldest-migration-commit>..<latest-migration-commit>
git commit -m "revert: rollback <target> migration"
```

### Full Rollback (When Git State Is Complicated)

1. **Save current state** (partial migration may be useful):
   ```bash
   git stash push -m "partial-migration-<target>-$(date +%Y%m%d)"
   ```

2. **Reset to rollback branch**:
   ```bash
   git checkout <rollback-branch>
   ```

3. **Reinstall dependencies**:
   ```bash
   rm -rf node_modules
   rm -f package-lock.json  # or pnpm-lock.yaml / yarn.lock
   npm install  # or pnpm install / yarn install
   ```

4. **Verify rollback**:
   ```bash
   npx tsc --noEmit 2>&1 | tail -10
   npm test 2>&1 | tail -20
   npm run build 2>&1 | tail -10
   ```

5. **Clean up branches**:
   ```bash
   # Only after confirming rollback is clean
   git branch -D <failed-migration-branch>  # if created
   ```

### Partial Rollback (Keep Some Migration Steps)

To keep successful steps:

1. Identify last good commit:
   ```bash
   git log --oneline | grep "migrate(<target>)"
   ```

2. Reset to that commit:
   ```bash
   git reset --hard <last-good-commit>
   ```

3. Reinstall dependencies and verify.

---

## Common Migration Pitfalls

### Peer Dependency Hell
- **Symptom**: `npm install` fails with peer dependency conflicts.
- **Fix**: Upgrade peer dependencies first, or use `--legacy-peer-deps` as temporary workaround.
- **Prevention**: Check peer dependency requirements before upgrading main package.

### Lock File Drift
- **Symptom**: Different behavior post-migration on CI vs local.
- **Fix**: Delete lock file and regenerate. Commit new lock file.

### Hidden Breaking Changes
- **Symptom**: Tests pass but runtime behavior differs.
- **Fix**: Check behavioral changes (changed defaults, different error messages, altered timing).
- **Prevention**: Review full changelog, not only "breaking changes" section.

### Transitive Dependency Breaks
- **Symptom**: Non-upgraded package starts failing.
- **Fix**: Check if migrated package changed a shared transitive dep. Pin transitive if needed.

### Config File Format Changes
- **Symptom**: Build tool can't parse config after upgrade.
- **Fix**: Use codemod if available. Otherwise rewrite config from scratch using new docs.

---

## Version Compatibility Quick Reference

### Vue Ecosystem

| Vue | Vue Router | Pinia | Vuetify | Quasar | Nuxt |
|-----|-----------|-------|---------|--------|------|
| 3.4+ | 4.x | 2.x | 3.x | 2.x (Vite) | 3.x |
| 3.0-3.3 | 4.x | 2.x | 3.x (early) | 2.x | 3.x (early) |
| 2.7 | 3.x | N/A (use Vuex) | 2.x | 1.x | 2.x |
| 2.6 | 3.x | N/A | 2.x | 1.x | 2.x |

### TypeScript Compatibility

| TypeScript | Node.js (min) | Vue | Vitest | ESLint |
|-----------|---------------|-----|--------|--------|
| 5.5+ | 18.18+ | 3.4+ | 2.x | 9.x |
| 5.0-5.4 | 16.20+ | 3.3+ | 1.x-2.x | 8.x-9.x |
| 4.9 | 14.17+ | 3.2+ | 0.x-1.x | 8.x |
| 4.7-4.8 | 14.17+ | 3.2+ | 0.x | 8.x |

### Node.js LTS Schedule

| Version | Status | End of Life |
|---------|--------|-------------|
| 22.x | Active LTS | April 2027 |
| 20.x | Maintenance LTS | April 2026 |
| 18.x | End of Life | April 2025 |

## Target Interpretation Examples

| Input | Interpretation |
|-------|---------------|
| `vue 3.5` | Upgrade Vue from current version to 3.5 |
| `vitest` | Migrate test runner from Jest/Mocha to Vitest |
| `eslint 9` | Upgrade ESLint to v9 (flat config migration) |
| `pinia 3` | Upgrade Pinia to v3 |
| `typescript 5.5` | Upgrade TypeScript to 5.5 |
| `esm` | Migrate from CommonJS to ES Modules |
| `vite` | Migrate from Webpack to Vite |
