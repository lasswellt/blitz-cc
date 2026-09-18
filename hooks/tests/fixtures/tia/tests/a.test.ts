import { describe, it, expect } from 'vitest'
import { a } from '../src/a'
describe('a', () => { it('composes b', () => { expect(a()).toBe('a+b') }) })
