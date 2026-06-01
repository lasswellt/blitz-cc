# Performance Profiler — Reference Material

Analysis commands, anti-pattern catalogs, threshold tables for perf-profile skill.

---

## Bundle Analysis Tools Per Build System

### Vite

**Production build with size output:**
```bash
npx vite build 2>&1
```

Output format:
```
dist/assets/index-abc123.js    145.23 kB │ gzip: 45.67 kB
dist/assets/vendor-def456.js   312.45 kB │ gzip: 98.12 kB
dist/assets/style-ghi789.css    23.45 kB │ gzip:  5.67 kB
```

**Detailed analysis with rollup-plugin-visualizer:**
```bash
# If installed as dev dependency
npx vite build --mode production
# Then open stats.html if configured in vite.config
```

**Manual chunk inspection:**
```bash
# List all output files with sizes
find dist -type f \( -name "*.js" -o -name "*.css" \) -exec ls -lh {} \; | sort -k5 -rh
```

### Nuxt

**Standard build:**
```bash
npx nuxt build 2>&1
```

**Build with bundle analyzer:**
```bash
npx nuxt build --analyze 2>&1
```
Generates visual bundle analysis report if `@nuxt/webpack-builder` or analyze option is configured.

**Inspect Nitro output:**
```bash
# Server bundle
ls -lh .output/server/chunks/ 2>/dev/null
# Client bundle
find .output/public/_nuxt/ -name "*.js" -exec ls -lh {} \; 2>/dev/null | sort -k5 -rh
```

### Webpack

**Build with stats:**
```bash
npx webpack --mode production --json > webpack-stats.json 2>&1
```

**Analyze stats file:**
```bash
# If webpack-bundle-analyzer is installed
npx webpack-bundle-analyzer webpack-stats.json
```

**Vue CLI (webpack-based):**
```bash
npx vue-cli-service build --report 2>&1
# Generates dist/report.html
```

### Common Size Commands

**Total dist size:**
```bash
du -sh dist/ .output/public/ build/ 2>/dev/null
```

**Gzip estimation for individual files:**
```bash
# Estimate gzip size
gzip -c dist/assets/main.js | wc -c
```

**Node modules size (top 20):**
```bash
du -sh node_modules/* 2>/dev/null | sort -rh | head -20
```

---

## Runtime Anti-Pattern Catalog (Vue 3 Specific)

### Category 1: Reactive Overhead

#### 1.1 Module-Scope Reactive State

**Pattern (bad):**
```typescript
// At module top level — creates reactive overhead on import
const state = reactive({ items: [], loading: false })
export function useItems() { return state }
```

**Fix:** Move reactive state inside composable or use `shallowRef`:
```typescript
export function useItems() {
  const state = reactive({ items: [], loading: false })
  return state
}
```

**Grep pattern:**
```bash
grep -rn "^const.*=.*reactive\(\|^let.*=.*reactive\(\|^const.*=.*ref\(" --include="*.ts" . | grep -v "node_modules\|\.test\.\|\.spec\."
```

#### 1.2 Missing shallowRef for Large Objects

**Pattern (bad):**
```typescript
const users = ref<User[]>([]) // Deep reactivity on potentially 1000+ users
```

**Fix:**
```typescript
const users = shallowRef<User[]>([]) // Only track reference changes
```

**Grep pattern:**
```bash
grep -rn "ref<.*\[\]>" --include="*.ts" --include="*.vue" . | grep -v "shallowRef\|node_modules"
```

#### 1.3 Deep Watchers on Complex State

**Pattern (bad):**
```typescript
watch(complexState, handler, { deep: true }) // Expensive deep comparison
```

**Fix:** Watch specific properties or `watchEffect` with targeted access:
```typescript
watch(() => complexState.specificField, handler)
```

**Grep pattern:**
```bash
grep -rn "deep:\s*true" --include="*.ts" --include="*.vue" . | grep -v "node_modules"
```

### Category 2: Render Performance

#### 2.1 Inline Functions in v-for Templates

**Pattern (bad):**
```vue
<div v-for="item in items" @click="() => handleClick(item.id)">
```

**Fix:** Use method that accepts item:
```vue
<div v-for="item in items" @click="handleClick(item.id)">
```

**Grep pattern:**
```bash
grep -rn "v-for.*@\w\+=\"()" --include="*.vue" . | grep -v "node_modules"
```

#### 2.2 Missing v-once on Static Content

**Pattern (bad):**
```vue
<template>
  <header>
    <h1>My Application</h1>  <!-- Re-rendered every update -->
    <nav>...</nav>            <!-- Static, but re-rendered -->
  </header>
  <main>{{ dynamicContent }}</main>
</template>
```

**Fix:** Add `v-once` to static sections:
```vue
<header v-once>
  <h1>My Application</h1>
  <nav>...</nav>
</header>
```

#### 2.3 Computed Properties with Side Effects

**Pattern (bad):**
```typescript
const filteredItems = computed(() => {
  analytics.track('filter_applied') // Side effect!
  return items.value.filter(i => i.active)
})
```

**Fix:** Move side effects into watchers:
```typescript
const filteredItems = computed(() => items.value.filter(i => i.active))
watch(filteredItems, () => analytics.track('filter_applied'))
```

**Grep pattern:**
```bash
grep -rn "computed(" --include="*.ts" --include="*.vue" -A 10 . | grep -E "console\.|fetch\(|emit\(|\.track\(|\.log\(|\.push\("
```

#### 2.4 v-if vs v-show Misuse

**Rule:** `v-show` for frequently toggled elements, `v-if` for rarely changed conditions.

**Grep pattern:**
```bash
# Find v-if on elements that might toggle frequently (modals, dropdowns, tooltips)
grep -rn 'v-if=".*\(show\|visible\|open\|expanded\|active\|toggle\)' --include="*.vue" . | grep -v "node_modules"
```

### Category 3: Data Fetching

#### 3.1 N+1 Query Pattern

**Pattern (bad):**
```typescript
const users = await getDocs(usersRef)
for (const user of users.docs) {
  const profile = await getDoc(doc(db, 'profiles', user.id)) // N+1!
}
```

**Fix:** Use batch read or query:
```typescript
const users = await getDocs(usersRef)
const profileIds = users.docs.map(u => u.id)
const profiles = await getDocs(query(profilesRef, where('__name__', 'in', profileIds)))
```

#### 3.2 Waterfall Data Fetching

**Pattern (bad):**
```typescript
const user = await fetchUser(id)      // 200ms
const orders = await fetchOrders(id)  // 300ms
const reviews = await fetchReviews(id) // 150ms
// Total: 650ms (serial)
```

**Fix:**
```typescript
const [user, orders, reviews] = await Promise.all([
  fetchUser(id),      // 200ms
  fetchOrders(id),    // 300ms (parallel)
  fetchReviews(id),   // 150ms (parallel)
])
// Total: 300ms (parallel)
```

**Grep pattern:**
```bash
# Sequential awaits that could be parallelized
grep -rn "await.*\nawait" --include="*.ts" --include="*.vue" . | grep -v "node_modules"
```

#### 3.3 Unbounded Collection Queries

**Pattern (bad):**
```typescript
const allDocs = await getDocs(collection(db, 'items')) // Could be 100K+ docs
```

**Fix:**
```typescript
const pagedDocs = await getDocs(query(collection(db, 'items'), limit(50)))
```

**Grep pattern:**
```bash
grep -rn "getDocs\|fetchAll\|find({})" --include="*.ts" --include="*.vue" . | grep -v "limit\|take\|top\|node_modules"
```

### Category 4: Memory Leaks

#### 4.1 Event Listeners Without Cleanup

**Grep pattern:**
```bash
# Find addEventListener without corresponding removeEventListener
grep -rn "addEventListener" --include="*.ts" --include="*.vue" -l . | while read f; do
  ADD=$(grep -c "addEventListener" "$f")
  REM=$(grep -c "removeEventListener\|onUnmounted\|onScopeDispose" "$f")
  if [ "$ADD" -gt "$REM" ]; then
    echo "LEAK RISK: $f (add: $ADD, cleanup: $REM)"
  fi
done
```

#### 4.2 Intervals Without Cleanup

**Grep pattern:**
```bash
# Find setInterval without clearInterval
grep -rn "setInterval" --include="*.ts" --include="*.vue" -l . | while read f; do
  SET=$(grep -c "setInterval" "$f")
  CLR=$(grep -c "clearInterval\|onUnmounted\|onScopeDispose" "$f")
  if [ "$SET" -gt "$CLR" ]; then
    echo "LEAK RISK: $f (set: $SET, clear: $CLR)"
  fi
done
```

#### 4.3 Firestore Listeners Without Unsubscribe

**Pattern (bad):**
```typescript
onSnapshot(docRef, (snap) => { /* ... */ }) // Never unsubscribed
```

**Fix:**
```typescript
const unsubscribe = onSnapshot(docRef, (snap) => { /* ... */ })
onUnmounted(() => unsubscribe())
```

**Grep pattern:**
```bash
grep -rn "onSnapshot" --include="*.ts" --include="*.vue" -l . | while read f; do
  SNAP=$(grep -c "onSnapshot" "$f")
  UNSUB=$(grep -c "unsubscribe\|onUnmounted\|onScopeDispose" "$f")
  if [ "$SNAP" -gt "$UNSUB" ]; then
    echo "LEAK RISK: $f (listeners: $SNAP, cleanup: $UNSUB)"
  fi
done
```

---

## Lighthouse Thresholds and Core Web Vitals Targets

### Core Web Vitals

| Metric | Good | Needs Improvement | Poor | What It Measures |
|--------|------|-------------------|------|------------------|
| LCP (Largest Contentful Paint) | < 2.5s | 2.5s - 4.0s | > 4.0s | Loading performance |
| INP (Interaction to Next Paint) | < 200ms | 200ms - 500ms | > 500ms | Interactivity responsiveness |
| CLS (Cumulative Layout Shift) | < 0.1 | 0.1 - 0.25 | > 0.25 | Visual stability |

### Additional Performance Metrics

| Metric | Good | Needs Improvement | Poor | What It Measures |
|--------|------|-------------------|------|------------------|
| FCP (First Contentful Paint) | < 1.8s | 1.8s - 3.0s | > 3.0s | Perceived load speed |
| TTFB (Time to First Byte) | < 0.8s | 0.8s - 1.8s | > 1.8s | Server response time |
| TBT (Total Blocking Time) | < 200ms | 200ms - 600ms | > 600ms | Main thread blocking |
| Speed Index | < 3.4s | 3.4s - 5.8s | > 5.8s | Visual completeness speed |

### Lighthouse Performance Score Ranges

| Score | Rating | Interpretation |
|-------|--------|----------------|
| 90-100 | Good | Minimal optimization needed |
| 50-89 | Needs Improvement | Notable optimization opportunities exist |
| 0-49 | Poor | Significant performance issues |

### Bundle Size Targets

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| Total JS (gzipped) | < 150KB | 150KB - 250KB | > 250KB |
| Total CSS (gzipped) | < 50KB | 50KB - 100KB | > 100KB |
| Largest chunk (gzipped) | < 100KB | 100KB - 200KB | > 200KB |
| Initial load JS (gzipped) | < 100KB | 100KB - 170KB | > 170KB |

---

## Optimization Recommendations Database

### Bundle Size Optimizations

| Optimization | Expected Impact | Complexity | Applies When |
|-------------|----------------|------------|-------------|
| Replace `lodash` with `lodash-es` or individual imports | 20-70KB reduction | Low | `lodash` in dependencies |
| Replace `moment` with `date-fns` or `dayjs` | 50-70KB reduction | Medium | `moment` in dependencies |
| Add route-level code splitting | 30-60% initial bundle reduction | Low | Routes use static imports |
| Enable CSS code splitting | 10-30KB reduction | Low | Single CSS bundle |
| Use dynamic imports for below-fold components | 20-40% chunk reduction | Low | Large page components |
| Enable Vite/Webpack tree-shaking | 10-30% reduction | Low | Namespace imports present |
| Compress images to WebP/AVIF | 50-80% image size reduction | Low | PNG/JPEG images > 100KB |
| Use `shallowRef` for large data sets | Negligible bundle, major runtime | Low | `ref` with large arrays/objects |
| Remove unused dependencies | Varies | Low | `depcheck` shows unused packages |

### Runtime Optimizations

| Optimization | Expected Impact | Complexity | Applies When |
|-------------|----------------|------------|-------------|
| Add virtual scrolling for long lists | Major render improvement | Medium | Lists > 100 items |
| Use `v-once` for static content | Minor render improvement | Low | Static headers/footers in dynamic components |
| Parallelize data fetching | 30-60% latency reduction | Low | Sequential awaits for independent data |
| Add request deduplication | Reduces redundant API calls | Medium | Same data fetched by multiple components |
| Add pagination to queries | Prevents memory issues | Medium | Unbounded collection reads |
| Fix N+1 queries | Major latency reduction | Medium | Loop-based document fetches |
| Clean up event listeners | Prevents memory leaks | Low | addEventListener without cleanup |
| Use `markRaw` for non-reactive data | Reduces reactivity overhead | Low | Large static datasets in reactive state |

### Lighthouse-Specific Optimizations

| Optimization | Metric Improved | Expected Impact | Complexity |
|-------------|----------------|----------------|------------|
| Preload critical fonts | LCP, FCP | 200-500ms improvement | Low |
| Add `loading="lazy"` to images | LCP | 10-30% LCP improvement | Low |
| Eliminate render-blocking CSS | FCP | 200-400ms improvement | Medium |
| Reduce main thread work | TBT, INP | 100-300ms improvement | Medium |
| Add explicit width/height to images | CLS | Eliminates layout shift | Low |
| Use `font-display: swap` | FCP | 100-300ms improvement | Low |
| Enable HTTP/2 server push | TTFB | 50-200ms improvement | Medium |
| Implement service worker caching | Repeat visit speed | 50-80% improvement | High |
| Defer non-critical JavaScript | TBT | 100-500ms improvement | Medium |
| Server-side render critical content | LCP, FCP | 500ms-2s improvement | High |

## Phase 2 Anti-Pattern Catalog

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
