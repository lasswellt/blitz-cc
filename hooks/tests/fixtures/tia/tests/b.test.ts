import { describe, it, expect } from 'vitest'
import { b } from '../src/b'
describe('b', () => { it('returns b', () => { expect(b()).toBe('b') }) })
