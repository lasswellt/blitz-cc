# Refactor — Reference Material

Safe refactoring patterns, verification strategies, incremental migration patterns.

---

## Safe Refactoring Patterns

### Extract Function
**When:** Code block repeated or function exceeds 50 lines with distinct logical sections.
**Steps:**
1. Identify extractable block and its inputs/outputs
2. Create new function with proper TypeScript signature
3. Replace original block with call to new function
4. Verify: type-check, run related tests
5. Commit

**Risk:** Low — purely structural change.

### Extract Component (Vue)
**When:** Vue component exceeds 300 lines or has reusable section.
**Steps:**
1. Identify extractable template section and required props/emits
2. Create new `.vue` file with proper prop/emit interfaces
3. Replace original section with new component
4. Pass required data as props, connect emits to parent handlers
5. Verify: type-check, mount test, visual inspection
6. Commit

**Risk:** Low-Medium — may break slot or event chains.

### Rename/Move
**When:** File, function, or variable has misleading name or wrong location.
**Steps:**
1. Find all references (imports, usages, tests)
2. Rename/move source
3. Update all import paths
4. Update barrel file exports
5. Verify: type-check (catches missed references), run full test suite
6. Commit

**Risk:** Medium — missed references cause runtime errors.

### Extract Type/Interface
**When:** Inline type definitions repeated across files.
**Steps:**
1. Identify repeated type pattern
2. Create shared type file in `types/`
3. Export type
4. Replace inline definitions with imports
5. Verify: type-check
6. Commit

**Risk:** Low — types compile-time only.

### Inline / Remove Dead Code
**When:** Function, variable, or file unused.
**Steps:**
1. Verify no references exist (grep for imports, usages)
2. Check git history — recently added? (may be in-progress work)
3. Remove code
4. Remove now-empty barrel exports
5. Verify: type-check, build
6. Commit

**Risk:** Medium — may remove code dynamically referenced.

### Replace Conditional with Strategy/Map
**When:** Long if/else or switch statement maps inputs to behaviors.
**Steps:**
1. Identify mapping pattern
2. Create lookup object or Map
3. Replace conditional with lookup
4. Verify: all branches still covered by tests
5. Commit

**Risk:** Low — equivalent transformation.

---

## Verification Strategy Per Refactoring Type

| Refactoring Type | Type-Check | Unit Tests | Integration Tests | Build | Visual Check |
|-----------------|------------|------------|-------------------|-------|--------------|
| Extract Function | Required | Required | Optional | Optional | No |
| Extract Component | Required | Required | Optional | Required | Recommended |
| Rename/Move | Required | Required | Required | Required | No |
| Extract Type | Required | Optional | No | Optional | No |
| Remove Dead Code | Required | Required | Optional | Required | No |
| Replace Conditional | Required | Required | Optional | Optional | No |

**"Required"** = must pass before committing.
**"Recommended"** = should check but non-blocking.
**"Optional"** = only if existing tests cover this area.

---

## Incremental Migration Patterns

### Strangler Fig
Replace module gradually by routing new calls to replacement while keeping old module functional.

```
Phase 1: Create new module alongside old
Phase 2: Route new callers to new module
Phase 3: Migrate existing callers one by one (with tests after each)
Phase 4: Remove old module when no callers remain
```

### Branch by Abstraction
Introduce abstraction layer to swap implementations.

```
Phase 1: Create interface/type for the behavior
Phase 2: Wrap existing implementation behind the interface
Phase 3: Create new implementation of the interface
Phase 4: Switch consumers to new implementation
Phase 5: Remove old implementation
```

### Parallel Run
Run old and new implementations simultaneously, comparing results.

```
Phase 1: Implement new version alongside old
Phase 2: Call both, compare outputs (log discrepancies)
Phase 3: When discrepancy rate reaches 0, switch to new
Phase 4: Remove old implementation
```

---

## Commit Strategy

Each atomic refactoring step gets its own commit:

```
refactor(<scope>): <what was changed>

- Extracted <function/component> from <source>
- Updated N import references
- All tests pass
```

**Never combine** refactoring commit with feature or bug fix commit. Allows safe revert of individual steps if something breaks downstream.

---

## Risk Assessment

Before starting, assess refactoring risk:

| Factor | Low Risk | High Risk |
|--------|----------|-----------|
| Test coverage | >80% in affected area | <30% in affected area |
| Callers | <5 files import the module | >20 files import the module |
| Type safety | Strict TypeScript, no `any` | Many `any` casts, weak types |
| Public API | Internal module only | Exported/consumed by external code |
| Timing | Before a plan starts, no deadline | During an active plan, tight deadline |

If risk high, consider:
1. Writing tests first (increase coverage to >80%)
2. Breaking refactoring into smaller, independently verifiable steps
3. Using feature flags to enable/disable refactored code
