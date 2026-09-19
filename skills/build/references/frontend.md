# Frontend conventions (inlined into the dev spawn prompt)

`build` pastes this file below the `ROLE: frontend` line of a `dev` spawn. It covers Vue 3 components, stores, composables, and routes, adapting to whichever UI framework the project uses. The generic rules (think-first, scope, quality gates, anti-mock, reply contract) live in `agents/dev.md`.

## Stack detection

Read `package.json` to determine the UI framework and project setup. Detect everything dynamically:

- **UI framework**: `tailwindcss` → Tailwind CSS; `quasar` → Quasar; `vuetify` → Vuetify; none → plain CSS / project-specific setup.
- **Meta-framework**: `nuxt` (Nuxt 3) vs plain `vite` (Vite + Vue Router).
- **State management**: `pinia` (preferred) or `vuex`.
- **Routing**: Nuxt uses file-based routing; Vite projects use `vue-router` config.
- **Module system**: always ESM for frontend packages.

## Component patterns

Use `<script setup lang="ts">` for all components:

```vue
<script setup lang="ts">
interface Props {
  title: string;
  count?: number;
}

const props = withDefaults(defineProps<Props>(), {
  count: 0,
});

const emit = defineEmits<{
  update: [value: string];
  close: [];
}>();
</script>

<template>
  <!-- template here -->
</template>
```

- Always type props with an interface and `defineProps<Props>()`.
- Always type emits with `defineEmits<{...}>()`.
- Extract complex logic into composables.
- Keep components focused — under 200 lines when possible.

## Store patterns

Use Pinia setup syntax (composition API style):

```typescript
export const useMyStore = defineStore("my-store", () => {
  const items = ref<Item[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function fetchItems() {
    loading.value = true;
    error.value = null;
    try {
      items.value = await api.getItems();
    } catch (e) {
      error.value = e instanceof Error ? e.message : "Unknown error";
    } finally {
      loading.value = false;
    }
  }

  return { items, loading, error, fetchItems };
});
```

## Composable patterns

Follow the `useXxx` naming convention:

```typescript
export function useXxx(input: MaybeRef<string>) {
  const data = ref<Result | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function execute() {
    loading.value = true;
    error.value = null;
    try {
      data.value = await fetchData(toValue(input));
    } catch (e) {
      error.value = e instanceof Error ? e.message : "Unknown error";
    } finally {
      loading.value = false;
    }
  }

  onUnmounted(() => { /* cleanup subscriptions/watchers */ });

  return { data, loading, error, execute };
}
```

- Accept reactive inputs (`MaybeRef<T>`) when appropriate.
- Always return an object with `loading`, `error`, and the data.
- Clean up subscriptions and watchers in `onUnmounted`.

## UI framework variants

### If Tailwind CSS is detected
- Utility classes for all styling; custom CSS only when Tailwind cannot express it.
- `animate-pulse` with gray placeholder divs for skeleton loading states.
- Follow the project's Tailwind config for custom colors, spacing, etc.
  ```html
  <div class="animate-pulse space-y-4">
    <div class="h-4 bg-gray-200 rounded w-3/4"></div>
    <div class="h-4 bg-gray-200 rounded w-1/2"></div>
  </div>
  ```

### If Quasar is detected
- `<q-*>` components exclusively; no Tailwind or raw HTML for things Quasar provides (buttons, inputs, cards, tables, dialogs).
- Quasar color system (`color="primary"`, `text-color="white"`); `<q-skeleton>` for loading states.
- Built-in utilities: `$q.notify()`, `$q.dialog()`, `$q.loading`; layout via `<q-layout>`, `<q-page-container>`, `<q-page>`.
  ```html
  <q-skeleton type="text" width="75%" />
  <q-skeleton type="text" width="50%" />
  ```

### If Vuetify is detected
- `<v-*>` components exclusively; no Tailwind or raw HTML for things Vuetify provides.
- Vuetify theme system and color props (`color="primary"`); `<VSkeletonLoader>` for loading states with an appropriate `type`.
- Grid via `<v-container>`, `<v-row>`, `<v-col>`.
  ```html
  <VSkeletonLoader type="article" />
  ```

## Three-state pattern

ALL data-driven views handle three states:

1. **Loading**: skeleton loaders (framework-appropriate, as above).
2. **Empty**: a meaningful empty state with guidance ("No items yet. Create your first item.").
3. **Error**: an error message with a retry action.

```vue
<template>
  <LoadingSkeleton v-if="loading" />
  <ErrorState v-else-if="error" :message="error" @retry="fetchData" />
  <EmptyState v-else-if="items.length === 0" message="No items yet." />
  <ItemList v-else :items="items" />
</template>
```

## Routing patterns

- **Nuxt**: file-based routing in `pages/`; `definePageMeta()` for middleware, layouts, and auth requirements.
- **Vite + Vue Router**: routes in the router config file; route guards for auth; lazy loading with `() => import(...)` for code splitting.

## Role-specific gates

In addition to the gates in `agents/dev.md`:

1. **Three-state coverage**: every data view handles loading, empty, and error, and the data state renders real data from a store/composable.
2. **Component test exists**: every new component has at least one test that mounts it and verifies it renders (only when the task's `files[]` includes the test file; otherwise list it under `concerns[]`).
3. **Responsive**: layout adapts between mobile (375px), tablet (768px), and desktop (1440px); no horizontal scrolling on mobile; touch targets ≥44×44px; base text ≥16px; tables scroll horizontally or collapse to cards on mobile.
4. **Accessibility**: every `<button>` has visible text or `aria-label`; every `<input>` has an associated `<label>`; every `<img>` has `alt`; color is never the sole state indicator; interactive elements are keyboard-reachable; focus order follows visual order.

**SELF-CHECK:** mount the component mentally. Does every button do something real? Does every data display come from a real store/composable? If not, the work is not done.
