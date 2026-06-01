# UI Build — Reference Material

## UX Design Principles

### Fitts's Law
Time to target = f(distance, size).
- **Application**: Large primary buttons near user focus. No tiny corner targets. Min touch: 44x44px mobile, 32x32px desktop.

### Hick's Law
Decision time grows logarithmically with choice count.
- **Application**: Limit choices per screen. Progressive disclosure — 5-7 options, group related actions. Break long forms into steps.

### Miller's Law
Working memory ~7 (±2) items.
- **Application**: Chunk into 5-7. Cards, sections, visual grouping. Tables 20+ cols need column selection or horizontal grouping.

### Jakob's Law
Users expect your site to behave like others.
- **Application**: Follow established patterns. Nav top or left. Tables sortable. Search top-right. Don't innovate on basics.

### Doherty Threshold
Productivity soars under 400ms response.
- **Application**: Instant skeleton/loading on navigation. Optimistic mutations. Prefetch on hover for likely next actions.

### Aesthetic-Usability Effect
Pleasing designs perceived as more usable.
- **Application**: Consistent spacing, alignment, typography. Use design tokens faithfully. Polish (rounded corners, subtle shadows, transitions) impacts perceived quality.

### Von Restorff Effect
Standouts are memorable.
- **Application**: Color/size/position highlight primary actions and critical info. Use sparingly — highlight everything, highlight nothing.

### Law of Proximity
Near objects read as related.
- **Application**: Group related form fields. Space unrelated sections. Cards/containers define boundaries.

### Law of Common Region
Shared boundary = group.
- **Application**: Cards, panels, bordered sections group content. Subtle background shades create regions.

---

## Visual Validation Procedure (Playwright MCP)

### Prerequisites
- Dev server running, accessible
- Playwright MCP tools available (via ToolSearch)

### Viewport Definitions
| Name    | Width  | Height | Device Class |
|---------|--------|--------|-------------|
| Mobile  | 375px  | 812px  | iPhone 13   |
| Tablet  | 768px  | 1024px | iPad        |
| Desktop | 1440px | 900px  | Laptop      |

### Validation Steps

1. **Navigate** to target page/route
2. **Wait** for stabilization (no spinners, network idle)
3. **Resize** to each viewport
4. **Screenshot** each viewport
5. **Inspect** screenshots for:

#### Layout Checks
- [ ] No horizontal overflow (no scrollbar on mobile)
- [ ] No overlapping elements
- [ ] Content fills width appropriately
- [ ] Consistent padding/margins
- [ ] Nav accessible (hamburger mobile, full desktop)

#### Typography Checks
- [ ] Readable at all viewports (min 14px body mobile)
- [ ] No truncation hiding critical info
- [ ] Clear heading hierarchy

#### Component Checks
- [ ] Tables → cards or horizontal scroll on mobile
- [ ] Buttons reachable (no overlap)
- [ ] Forms stack vertically on mobile
- [ ] Dialogs/modals fit viewport

#### Interaction Checks
- [ ] Primary action — responds?
- [ ] Tab through — focus visible?
- [ ] Dropdowns/menus — stay in viewport?

---

## Accessibility Checklist (WCAG 2.1 AA)

### Perceivable
- [ ] **1.1.1 Non-text Content**: Images have `alt`. Decorative use `alt=""`
- [ ] **1.3.1 Info and Relationships**: Proper `h1`-`h6` hierarchy. `ul`/`ol` for lists. `th` for tables
- [ ] **1.3.2 Meaningful Sequence**: DOM order matches visual order
- [ ] **1.4.1 Use of Color**: Not color alone — add icons or text
- [ ] **1.4.3 Contrast**: 4.5:1 (3:1 large). Use pre-verified theme colors
- [ ] **1.4.4 Resize Text**: Scales to 200% without loss
- [ ] **1.4.10 Reflow**: Reflows at 320px width, no horizontal scroll
- [ ] **1.4.11 Non-text Contrast**: UI components and graphics 3:1

### Operable
- [ ] **2.1.1 Keyboard**: All interactives keyboard-reachable
- [ ] **2.1.2 No Keyboard Trap**: Focus can always exit
- [ ] **2.4.1 Skip Navigation**: Skip-to-content link if applicable
- [ ] **2.4.3 Focus Order**: Tab order = reading order
- [ ] **2.4.6 Headings and Labels**: Descriptive
- [ ] **2.4.7 Focus Visible**: Indicator clearly visible
- [ ] **2.5.5 Target Size**: ≥44x44 CSS px on touch

### Understandable
- [ ] **3.1.1 Language**: `lang` on `<html>`
- [ ] **3.2.1 On Focus**: No unexpected context change on focus
- [ ] **3.2.2 On Input**: No unexpected context change on input (use submit buttons)
- [ ] **3.3.1 Error Identification**: Errors identified and described in text
- [ ] **3.3.2 Labels or Instructions**: Inputs have visible labels
- [ ] **3.3.3 Error Suggestion**: Suggest correction when known

### Robust
- [ ] **4.1.2 Name, Role, Value**: Custom components — ARIA roles/properties
- [ ] **4.1.3 Status Messages**: Use `aria-live` regions

---

## Component Spec Template

```markdown
### Component: [PascalCaseName]

**File**: `src/components/[path]/[PascalCaseName].vue`
**Estimated lines**: [number — must be under 300]

#### Purpose
[One sentence describing what this component does]

#### Props
| Prop | Type | Default | Required | Description |
|------|------|---------|----------|-------------|
| ... | ... | ... | ... | ... |

#### Emits
| Event | Payload Type | Description |
|-------|-------------|-------------|
| ... | ... | ... |

#### Slots
| Slot | Props | Description |
|------|-------|-------------|
| default | — | [description] |
| ... | ... | ... |

#### States
| State | Condition | Display |
|-------|-----------|---------|
| Loading | `loading === true` | [skeleton description] |
| Empty | `!data?.length` | [empty state description] |
| Error | `error !== null` | [error display description] |
| Populated | `data?.length > 0` | [normal content description] |

#### Children
- [ChildComponent1] — used for [purpose]
- [ChildComponent2] — used for [purpose]

#### Responsive Behavior
| Viewport | Behavior |
|----------|----------|
| Mobile (< 640px) | [description] |
| Tablet (640-1024px) | [description] |
| Desktop (> 1024px) | [description] |
```

---

## Wireframe Template Format

ASCII wireframes, conventions below:

```
┌─────────────────────────────────────────────────┐
│ [LayoutWrapper]                                  │
│ ┌─────────────────────────────────────────────┐ │
│ │ PageHeader: "Page Title"         [+ Action] │ │
│ ├─────────────────────────────────────────────┤ │
│ │ FilterBar: [Search___] [Status▾] [Date▾]   │ │
│ ├─────────────────────────────────────────────┤ │
│ │ DataTable / CardGrid                        │ │
│ │ ┌──────┬──────────┬────────┬──────────────┐ │ │
│ │ │ Name │ Status   │ Date   │ Actions      │ │ │
│ │ ├──────┼──────────┼────────┼──────────────┤ │ │
│ │ │ ...  │ [Badge]  │ ...    │ [Edit][Del]  │ │ │
│ │ └──────┴──────────┴────────┴──────────────┘ │ │
│ │ Pagination: [< 1 2 3 ... 10 >]             │ │
│ └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘

RESPONSIVE:
  Mobile (< 640px): Table → stacked cards, filters collapse to drawer
  Tablet (640-1024px): Table with horizontal scroll, filters stay visible
  Desktop (> 1024px): Full table, all columns visible
```

### Wireframe Symbols
| Symbol | Meaning |
|--------|---------|
| `[Button]` | Clickable button |
| `[Input___]` | Text input field |
| `[Select▾]` | Dropdown select |
| `[x]` or `[ ]` | Checkbox |
| `(o)` or `( )` | Radio button |
| `[Badge]` | Status badge/chip |
| `[Icon]` | Icon element |
| `[< 1 2 3 >]` | Pagination control |
| `───` | Horizontal divider |
| `│` | Vertical divider |
| `...` | Repeated content |

### Wireframe Rules
1. Show outermost layout wrapper
2. Name every component — no anonymous boxes
3. Show ≥1 row of data content
4. Include responsive notes below wireframe
5. Mark primary actions distinctly (e.g., `[+ Create New]`)

## UI Framework Variants

### When UI Framework is Tailwind CSS:
- Use utility classes exclusively — never write custom CSS unless unavoidable
- Skeletons: `animate-pulse bg-slate-200 rounded` (adapt shade to project palette)
- Colors: use Tailwind color tokens from `tailwind.config.*` — never raw hex
- Spacing: use Tailwind spacing scale (`p-4`, `gap-6`, etc.)
- Responsive: use Tailwind breakpoint prefixes (`sm:`, `md:`, `lg:`)
- Dark mode: use `dark:` variant if project supports it
- Layout: use Tailwind `flex`, `grid` utilities
- Typography: use Tailwind text utilities (`text-sm`, `font-medium`, etc.)

### When UI Framework is Quasar:
- Use `<q-*>` components exclusively — never use raw HTML equivalents
- Skeletons: `<q-skeleton type="rect" />`, `<q-skeleton type="text" />`, `<q-skeleton type="circle" />`
- Colors: use Quasar color system (`color="primary"`, `text-color="grey-8"`)
- Spacing: use Quasar CSS helpers (`q-pa-md`, `q-mt-sm`, `q-gutter-md`)
- Layout: use `<q-page>`, `<q-card>`, `<q-list>`, `<q-item>` hierarchy
- Tables: use `<q-table>` with column definitions, not raw `<table>`
- Forms: use `<q-form>`, `<q-input>`, `<q-select>` with validation rules
- Dialogs: use `<q-dialog>` or `$q.dialog()` plugin
- Notifications: use `$q.notify()` — never build custom toast components
- Icons: use the project's configured icon set (Material Icons, etc.)

### When UI Framework is Vuetify:
- Use `<v-*>` components exclusively — never use raw HTML equivalents
- Skeletons: `<VSkeletonLoader type="card" />`, `<VSkeletonLoader type="table-row" />`
- Colors: use Vuetify theme colors (`color="primary"`, `class="text-error"`)
- Spacing: use Vuetify spacing helpers (`pa-4`, `mt-2`, `ga-4`)
- Layout: use `<VContainer>`, `<VRow>`, `<VCol>` grid system
- Tables: use `<VDataTable>` with headers array
- Forms: use `<VForm>`, `<VTextField>`, `<VSelect>` with rules
- Dialogs: use `<VDialog>` with `v-model`
- Snackbars: use `<VSnackbar>` — never build custom toast components
