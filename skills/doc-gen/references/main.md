# Documentation Generator — Reference Material

Templates, parsing patterns, diagram examples for doc-gen skill.

---

## API Documentation Template

Use this template for each module documented in `docs/generated/api.md`.

```markdown
# API Reference

> Auto-generated from source code. Functions are grouped by module.

---

## {module_path}

{module_description}

### `{function_name}`

{description from JSDoc or inferred from function body}

**Signature:**

```typescript
{full_function_signature}
```

**Parameters:**

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| {param_name} | `{param_type}` | {Yes/No} | {default_value} | {param_description} |

**Returns:** `{return_type}` — {return_description}

**Throws:**

| Error | Condition |
|-------|-----------|
| `{ErrorType}` | {when_thrown} |

**Example:**

```typescript
{usage_example}
```

---
```

### API Template Notes

- Group functions by module path (e.g., `utils/format`, `services/auth`).
- If function has no JSDoc, infer description from function name and body.
- For Zod schemas, document inferred TypeScript type alongside schema.
- For re-exported functions, note original module.
- Mark deprecated functions with `> **Deprecated**: {reason}` callout.

---

## Component Documentation Template

Use this template for each component documented in `docs/generated/components.md`.

```markdown
# Components

> Auto-generated from Vue SFC source files.

---

## {ComponentName}

**File:** `{relative_file_path}`

{component_description}

### Props

| Name | Type | Default | Required | Description |
|------|------|---------|----------|-------------|
| {prop_name} | `{prop_type}` | `{default_value}` | {Yes/No} | {prop_description} |

### Events

| Name | Payload | Description |
|------|---------|-------------|
| {event_name} | `{payload_type}` | {event_description} |

### Slots

| Name | Scoped Props | Description |
|------|-------------|-------------|
| {slot_name} | `{scoped_props_type}` | {slot_description} |

### Exposed Methods

| Name | Signature | Description |
|------|-----------|-------------|
| {method_name} | `{method_signature}` | {method_description} |

### Usage

```vue
<template>
  <{ComponentName}
    :{prop_name}="{value}"
    @{event_name}="handler"
  >
    <template #{slot_name}="{ {scoped_prop} }">
      <!-- slot content -->
    </template>
  </{ComponentName}>
</template>
```

### Dependencies

- **Composables**: {list of useXxx composables used}
- **Stores**: {list of stores accessed}
- **Child Components**: {list of child components rendered}

---
```

### Component Template Notes

- Order components alphabetically or by directory structure.
- For components with many props (>10), group by category if JSDoc `@group` tags exist.
- Mark deprecated props with strikethrough: `~~propName~~`.
- If component has no description, use component file name as heading; note "No description provided."

---

## Architecture Template

Use this template for `docs/generated/architecture.md`.

```markdown
# Architecture Overview

**Stack**: {detected_stack}
**Generated**: {date}

---

## Directory Structure

```
{project_name}/
├── src/
│   ├── components/     # UI building blocks
│   ├── composables/    # Shared reactive logic
│   ├── pages/          # Route views
│   ├── stores/         # Pinia state management
│   ├── services/       # API and external service clients
│   ├── utils/          # Pure utility functions
│   └── types/          # Shared TypeScript types
├── functions/          # Cloud Functions (backend)
├── public/             # Static assets
└── tests/              # Test files
```

---

## Module Dependency Graph

```mermaid
graph TD
    subgraph Pages
        P1[PageA]
        P2[PageB]
    end

    subgraph Components
        C1[ComponentA]
        C2[ComponentB]
    end

    subgraph Composables
        U1[useFeatureA]
        U2[useFeatureB]
    end

    subgraph Stores
        S1[storeA]
        S2[storeB]
    end

    subgraph Services
        API1[serviceA]
        API2[serviceB]
    end

    P1 --> C1
    P1 --> U1
    C1 --> U2
    U1 --> S1
    U2 --> S2
    S1 --> API1
    S2 --> API2
```

---

## Layer Descriptions

### Pages
{description of pages layer and routing strategy}

### Components
{description of component hierarchy and organization}

### Composables
{description of shared reactive logic}

### Stores
{description of state management approach}

### Services
{description of API clients and external integrations}

---

## Key Data Flows

### Flow 1: {flow_name}

```mermaid
sequenceDiagram
    participant User
    participant Page
    participant Component
    participant Store
    participant API

    User->>Page: Navigate
    Page->>Component: Render
    Component->>Store: Read state
    Store->>API: Fetch data
    API-->>Store: Response
    Store-->>Component: Updated state
    Component-->>User: Rendered view
```

{description of flow}

---

## Statistics

| Metric | Count |
|--------|-------|
| Pages | {N} |
| Components | {N} |
| Composables | {N} |
| Stores | {N} |
| Services | {N} |
| Utility modules | {N} |
| Type definition files | {N} |
| Circular dependencies | {N} |
```

### Architecture Template Notes

- Limit Mermaid diagrams to 50 nodes max. Group related modules into subgraphs.
- For large codebases, create separate diagrams per feature domain.
- Include only direct dependencies in module graph (not transitive).
- Highlight circular dependencies with red edges: `A -->|circular| B`.

---

## Changelog Template

Use the [Keep a Changelog](https://keepachangelog.com/) format for `docs/generated/changelog.md`.

```markdown
# Changelog

All notable changes to this project are documented in this file.
This changelog is auto-generated from conventional commits.

## [Unreleased]

### Added
- {feat: commit message} ([{short_hash}]({commit_url})) — {author}

### Fixed
- {fix: commit message} ([{short_hash}]({commit_url})) — {author}

### Changed
- {refactor/perf: commit message} ([{short_hash}]({commit_url})) — {author}

### Breaking Changes
- **BREAKING**: {description} ([{short_hash}]({commit_url})) — {author}

### Other
- {docs/chore/ci/test: commit message} ([{short_hash}]({commit_url})) — {author}

## [{version_tag}] — {tag_date}

### Added
- ...

### Fixed
- ...
```

### Changelog Template Notes

**Commit-type → section mapping and emit rules (Other fallback, prefix stripping, capitalization, alphabetical sort, hash-linking, scope inclusion, empty-section omission, BREAKING CHANGE handling) are owned by [`skills/release`](../release/SKILL.md) §changelog — canonical O1/O5.** `doc-gen` `changelog` mode delegates to that owner; it does NOT restate the map (the previous inline table had drifted from the canonical one). Edit the mapping in [`skills/release/references/main.md`](../release/references/main.md) §Commit Type Mapping; this consumer cites it.

---

## Vue SFC Parsing Patterns

Regex and AST patterns for extracting component metadata from Vue SFCs.

### defineProps Extraction

**TypeScript generic syntax:**
```
defineProps<{
  propName: PropType
  optionalProp?: PropType
}>()
```

Regex pattern (approximate):
```regex
defineProps<\{([^}]+)\}>
```

**Object syntax with defaults:**
```
defineProps({
  propName: { type: String, required: true, default: 'value' },
})
```

Regex pattern (approximate):
```regex
defineProps\(\{([^)]+)\}\)
```

**withDefaults wrapper:**
```
withDefaults(defineProps<Props>(), {
  propName: 'default',
})
```

Regex pattern:
```regex
withDefaults\(defineProps<(\w+)>\(\),\s*\{([^}]+)\}\)
```

For `withDefaults`, also locate referenced `Props` interface to get type definitions.

### defineEmits Extraction

**TypeScript generic syntax:**
```
defineEmits<{
  eventName: [payload: PayloadType]
  (e: 'eventName', payload: PayloadType): void
}>()
```

Regex pattern:
```regex
defineEmits<\{([^}]+)\}>
```

**Array syntax:**
```
defineEmits(['eventName', 'otherEvent'])
```

Regex pattern:
```regex
defineEmits\(\[([^\]]+)\]\)
```

### defineSlots Extraction

```
defineSlots<{
  default(props: { item: ItemType }): any
  header(): any
}>()
```

Regex pattern:
```regex
defineSlots<\{([^}]+)\}>
```

**Template slot tags (fallback):**
```html
<slot name="header" :item="item" />
```

Regex pattern:
```regex
<slot\s+(?:name="(\w+)")?\s*(?::(\w+)="[^"]*")*\s*/?>
```

### defineExpose Extraction

```
defineExpose({
  methodName,
  propertyName,
})
```

Regex pattern:
```regex
defineExpose\(\{([^}]+)\}\)
```

### Component Description

Look for a top-level comment in `<script setup>`:

```vue
<script setup lang="ts">
/**
 * ComponentDescription goes here.
 * Can span multiple lines.
 */
```

Regex pattern:
```regex
<script[^>]*>\s*/\*\*\s*([\s\S]*?)\s*\*/
```

### Parsing Recommendations

- Regex patterns above are approximations. For deeply nested types, read full `<script setup>` block and parse structurally rather than single-pass regex.
- Handle multi-line type definitions by first extracting full block between delimiters.
- For `withDefaults`, resolve referenced type alias by searching for corresponding `interface` or `type` declaration in same file.
- For imported prop types (`import type { Props } from './types'`), follow import to extract type shape.

---

## Mermaid Diagram Patterns

### Module Dependency Graph

```mermaid
graph TD
    A[Module A] --> B[Module B]
    A --> C[Module C]
    B --> D[Module D]
    C --> D
    style A fill:#4CAF50,color:#fff
    style D fill:#2196F3,color:#fff
```

### Component Tree

```mermaid
graph TD
    App --> Layout
    Layout --> Header
    Layout --> Sidebar
    Layout --> MainContent
    MainContent --> PageView
    PageView --> FeatureComponent
    FeatureComponent --> SubComponent1
    FeatureComponent --> SubComponent2
```

### Data Flow (Sequence)

```mermaid
sequenceDiagram
    participant U as User
    participant C as Component
    participant S as Store
    participant A as API

    U->>C: User action
    C->>S: Dispatch action
    S->>A: API request
    A-->>S: Response
    S-->>C: State update
    C-->>U: Re-render
```

### State Machine

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Loading : fetch
    Loading --> Success : resolve
    Loading --> Error : reject
    Error --> Loading : retry
    Success --> Idle : reset
```

### Styling Guidelines

- Use subgraphs to group related modules by layer or feature.
- Limit graph width: prefer `TD` (top-down) for hierarchies, `LR` (left-right) for flows.
- Color-code by layer: green for pages, blue for components, orange for stores, purple for services.
- Add edge labels only when relationship type is not obvious.
