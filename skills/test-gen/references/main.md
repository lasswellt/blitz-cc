# Test Generation — Reference Material

Test patterns per framework/scenario.

---

## Vitest Patterns

### Unit Test (with AAA pattern)

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { formatCurrency } from '../utils/format'

describe('formatCurrency', () => {
  it('should format a number as USD currency', () => {
    expect(formatCurrency(1234.56)).toBe('$1,234.56')
  })

  it('should handle zero', () => {
    expect(formatCurrency(0)).toBe('$0.00')
  })

  it('should handle negative values', () => {
    expect(formatCurrency(-50)).toBe('-$50.00')
  })

  it('should return "$0.00" for NaN input', () => {
    expect(formatCurrency(NaN)).toBe('$0.00')
  })
})
```

### Async Function with Mocked HTTP

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { fetchUserProfile } from '../api/user'

vi.mock('../lib/http', () => ({ http: { get: vi.fn() } }))
import { http } from '../lib/http'

describe('fetchUserProfile', () => {
  beforeEach(() => { vi.clearAllMocks() })

  it('should return user profile on success', async () => {
    const mockProfile = { id: '1', name: 'Test User', email: 'test@example.com' }
    vi.mocked(http.get).mockResolvedValue({ data: mockProfile })

    const result = await fetchUserProfile('1')

    expect(result).toEqual(mockProfile)
    expect(http.get).toHaveBeenCalledWith('/api/users/1')
  })

  it('should throw on network error', async () => {
    vi.mocked(http.get).mockRejectedValue(new Error('Network Error'))
    await expect(fetchUserProfile('1')).rejects.toThrow('Network Error')
  })
})
```

### Mocking Patterns

```typescript
// Mock entire module
vi.mock('../services/analytics', () => ({
  trackEvent: vi.fn(),
  trackPageView: vi.fn(),
}))

// Mock with partial override (keep real exports); importActual is async
vi.mock('../config', async () => ({
  ...(await vi.importActual<typeof import('../config')>('../config')),
  API_BASE_URL: 'http://test-api.example.com',
}))
```

### Timers

```typescript
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { debounce } from '../utils/debounce'

describe('debounce', () => {
  beforeEach(() => { vi.useFakeTimers() })
  afterEach(() => { vi.useRealTimers() })

  it('should delay execution', () => {
    const fn = vi.fn()
    const debounced = debounce(fn, 300)
    debounced()
    expect(fn).not.toHaveBeenCalled()
    vi.advanceTimersByTime(300)
    expect(fn).toHaveBeenCalledOnce()
  })
})
```

---

## Jest Patterns

### Async Test with Jest Mocks

```typescript
jest.mock('../lib/http')
import { http } from '../lib/http'
const mockedHttp = http as jest.Mocked<typeof http>

describe('fetchData', () => {
  beforeEach(() => { jest.clearAllMocks() })

  it('should return data on success', async () => {
    mockedHttp.get.mockResolvedValue({ data: { items: [] } })
    const result = await fetchData()
    expect(result).toEqual({ items: [] })
  })

  it('should handle errors', async () => {
    mockedHttp.get.mockRejectedValue(new Error('Server Error'))
    await expect(fetchData()).rejects.toThrow('Server Error')
  })
})
```

---

## Vue Test Utils Patterns

### Component Mount, Props, and Emits

```typescript
import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import StatusBadge from '../StatusBadge.vue'

describe('StatusBadge', () => {
  it('should render with required props', () => {
    const wrapper = mount(StatusBadge, { props: { status: 'active' } })
    expect(wrapper.text()).toContain('Active')
  })

  it('should apply correct class for status', () => {
    const wrapper = mount(StatusBadge, { props: { status: 'error' } })
    expect(wrapper.classes()).toContain('badge--error')
  })

  it('should emit click event with payload', async () => {
    const wrapper = mount(StatusBadge, { props: { status: 'active', clickable: true } })
    await wrapper.trigger('click')
    expect(wrapper.emitted('click')![0]).toEqual(['active'])
  })
})
```

### Component with Pinia Store

```typescript
import { describe, it, expect, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createTestingPinia } from '@pinia/testing'
import UserList from '../UserList.vue'

describe('UserList', () => {
  it('should render user list from store', () => {
    const wrapper = mount(UserList, {
      global: {
        plugins: [createTestingPinia({
          initialState: { user: { users: [{ id: '1', name: 'Alice' }, { id: '2', name: 'Bob' }] } },
        })],
      },
    })
    expect(wrapper.findAll('[data-testid="user-item"]')).toHaveLength(2)
  })

  it('should show empty state when no users', () => {
    const wrapper = mount(UserList, { global: { plugins: [createTestingPinia()] } })
    expect(wrapper.find('[data-testid="empty-state"]').exists()).toBe(true)
  })

  it('should show loading state', () => {
    const wrapper = mount(UserList, {
      global: {
        plugins: [createTestingPinia({ initialState: { user: { loading: true } } })],
      },
    })
    expect(wrapper.find('[data-testid="loading"]').exists()).toBe(true)
  })
})
```

### Component with Router

```typescript
import { mount } from '@vue/test-utils'
import { createRouter, createMemoryHistory } from 'vue-router'
import NavBar from '../NavBar.vue'

const router = createRouter({
  history: createMemoryHistory(),
  routes: [
    { path: '/', name: 'home', component: { template: '<div />' } },
    { path: '/about', name: 'about', component: { template: '<div />' } },
  ],
})

it('should highlight active route', async () => {
  router.push('/about')
  await router.isReady()
  const wrapper = mount(NavBar, { global: { plugins: [router] } })
  expect(wrapper.find('[data-testid="nav-about"]').classes()).toContain('active')
})
```

### Testing Slots

```typescript
it('should render default slot content', () => {
  const wrapper = mount(Card, { slots: { default: '<p>Card content</p>' } })
  expect(wrapper.html()).toContain('Card content')
})

it('should render named header slot', () => {
  const wrapper = mount(Card, { slots: { header: '<h2>Title</h2>', default: '<p>Body</p>' } })
  expect(wrapper.find('h2').text()).toBe('Title')
})
```

---

## Composable Testing Pattern

```typescript
import { describe, it, expect, vi } from 'vitest'
import { nextTick } from 'vue'
import { withSetup } from '../../test-utils/with-setup'
import { useSearch } from '../useSearch'

// withSetup helper (create if project lacks one):
// export function withSetup<T>(composable: () => T): [T, any] {
//   let result: T
//   const app = createApp({ setup() { result = composable(); return () => {} } })
//   app.mount(document.createElement('div'))
//   return [result!, app]
// }

describe('useSearch', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it('should initialize with empty query', () => {
    const [result] = withSetup(() => useSearch())
    expect(result.query.value).toBe('')
    expect(result.results.value).toEqual([])
  })

  it('should update results when query changes', async () => {
    const [result] = withSetup(() => useSearch())
    result.query.value = 'test'
    await nextTick()
    await vi.advanceTimersByTimeAsync(300)   // async variant: the debounce chain awaits
    await nextTick()
    expect(result.results.value.length).toBeGreaterThan(0)
  })
})
```

---

## Pinia Store Testing Pattern

```typescript
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useCartStore } from '../cart'

vi.mock('../../api/cart', () => ({
  cartApi: { addItem: vi.fn(), removeItem: vi.fn(), getCart: vi.fn() },
}))
import { cartApi } from '../../api/cart'

describe('useCartStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  it('should start with empty cart', () => {
    const store = useCartStore()
    expect(store.items).toEqual([])
    expect(store.total).toBe(0)
  })

  it('should add item to cart', async () => {
    const store = useCartStore()
    const item = { id: '1', name: 'Widget', price: 9.99, quantity: 1 }
    vi.mocked(cartApi.addItem).mockResolvedValue(item)
    await store.addItem(item)
    expect(store.items).toContainEqual(item)
  })

  it('should calculate total from items', () => {
    const store = useCartStore()
    store.items = [
      { id: '1', name: 'A', price: 10, quantity: 2 },
      { id: '2', name: 'B', price: 5, quantity: 1 },
    ]
    expect(store.total).toBe(25)
  })

  it('should set error state on failed add', async () => {
    const store = useCartStore()
    vi.mocked(cartApi.addItem).mockRejectedValue(new Error('Network Error'))
    await store.addItem({ id: '1', name: 'Widget', price: 9.99, quantity: 1 })
    expect(store.error).toBe('Network Error')
  })
})
```

---

## Zod Schema Testing Pattern

```typescript
import { describe, it, expect } from 'vitest'
import { UserProfileSchema, type UserProfile } from '../schemas/user-profile'

describe('UserProfileSchema', () => {
  const valid: UserProfile = {
    id: 'user-123', displayName: 'Test User',
    email: 'test@example.com', role: 'member',
    createdAt: new Date().toISOString(),
  }

  it('should accept a valid profile', () => {
    expect(UserProfileSchema.safeParse(valid).success).toBe(true)
  })

  it('should reject missing required fields', () => {
    const { displayName, ...incomplete } = valid
    const result = UserProfileSchema.safeParse(incomplete)
    expect(result.success).toBe(false)
  })

  it('should reject invalid email format', () => {
    expect(UserProfileSchema.safeParse({ ...valid, email: 'bad' }).success).toBe(false)
  })

  it('should reject invalid enum values', () => {
    expect(UserProfileSchema.safeParse({ ...valid, role: 'superadmin' }).success).toBe(false)
  })
})
```

---

## Firestore Rules Testing Pattern

```typescript
import {
  assertFails, assertSucceeds, initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing'
import { doc, getDoc, setDoc, deleteDoc } from 'firebase/firestore'
import { describe, it, beforeAll, afterAll, beforeEach } from 'vitest'
import { readFileSync } from 'fs'

let testEnv: RulesTestEnvironment

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'test-project',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  })
})
afterAll(async () => { await testEnv.cleanup() })
beforeEach(async () => { await testEnv.clearFirestore() })

describe('Firestore Rules: users collection', () => {
  it('should allow authenticated user to read own profile', async () => {
    const db = testEnv.authenticatedContext('user-123').firestore()
    await assertSucceeds(getDoc(doc(db, 'users', 'user-123')))
  })

  it('should deny unauthenticated reads', async () => {
    const db = testEnv.unauthenticatedContext().firestore()
    await assertFails(getDoc(doc(db, 'users', 'any-user')))
  })

  it('should deny cross-user reads', async () => {
    const db = testEnv.authenticatedContext('user-123').firestore()
    await assertFails(getDoc(doc(db, 'users', 'user-456')))
  })

  it('should allow user to update own profile', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', 'user-123'), { displayName: 'Original' })
    })
    const db = testEnv.authenticatedContext('user-123').firestore()
    await assertSucceeds(setDoc(doc(db, 'users', 'user-123'), { displayName: 'Updated' }, { merge: true }))
  })

  it('should deny user from deleting own profile', async () => {
    const db = testEnv.authenticatedContext('user-123').firestore()
    await assertFails(deleteDoc(doc(db, 'users', 'user-123')))
  })
})
```

---

## Test Factory Pattern

```typescript
// test-utils/factories/user.ts
import { type User } from '../../types/user'

let counter = 0

export function createTestUser(overrides: Partial<User> = {}): User {
  counter += 1
  return {
    id: `test-user-${counter}`,
    displayName: `Test User ${counter}`,
    email: `user${counter}@test.example.com`,
    role: 'member',
    createdAt: new Date('2025-01-01').toISOString(),
    ...overrides,
  }
}

export function createTestAdmin(overrides: Partial<User> = {}): User {
  return createTestUser({ role: 'admin', ...overrides })
}
```

Usage:
```typescript
it('should display admin badge for admin users', () => {
  const wrapper = mount(UserCard, { props: { user: createTestAdmin() } })
  expect(wrapper.find('[data-testid="admin-badge"]').exists()).toBe(true)
})
```

---

## AAA Pattern Reference

Every test follows Arrange-Act-Assert:

- **Arrange**: test data, mocks, env, initial state.
- **Act**: call function, trigger event, mount component.
- **Assert**: return values, mock calls, state changes.

Separate sections via blank lines or comments. Simple tests: inline OK. Complex tests: use explicit `// Arrange`, `// Act`, `// Assert` comments.
