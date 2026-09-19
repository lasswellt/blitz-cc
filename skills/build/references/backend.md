# Backend conventions (inlined into the dev spawn prompt)

`build` pastes this file below the `ROLE: backend` line of a `dev` spawn. It covers Cloud Functions / server-side logic, database schemas, and API implementation. The generic rules (think-first, scope, quality gates, anti-mock, reply contract) live in `agents/dev.md`.

## Stack detection

Read `package.json` to determine the backend framework and database. Detect everything dynamically:

- **Runtime**: `firebase-functions`, `express`, `fastify`, `hono`, `@google-cloud/*`, or another backend framework.
- **Database**: `firebase-admin` (Firestore), `pg` / `@prisma/client` (PostgreSQL), `mongoose` (MongoDB), etc.
- **Validation**: `zod`, `joi`, `yup`, `class-validator`, etc.
- **Module system**: `"type"` in `package.json` — CJS for Cloud Functions unless ESM is explicitly configured.
- **Monorepo context**: identify the backend package and its shared dependencies.

## Cloud Function pattern

Follow the numbered comment flow for all callable functions:

```typescript
export const myFunction = onCall(async (request) => {
  // 1. Auth — verify the caller is authenticated
  const uid = requireAuth(request);

  // 2. Validate — parse and validate input with schema
  const data = MyInputSchema.parse(request.data);

  // 3. Business logic — perform the operation
  const result = await performOperation(data);

  // 4. Audit — log the action for compliance
  await auditLog({ action: "myFunction", uid, detail: { /* relevant data */ } });

  // 5. Return — send typed response
  return { success: true, data: result };
});
```

This pattern applies to `onCall`, `onRequest`, and trigger functions (`onDocumentCreated`, etc.), adapting steps as appropriate for the trigger type.

## Zod schema patterns

- **Input schemas**: define at the top of the function file or in a shared schemas directory.
- **Branded IDs**: use branded types for document IDs when the project uses them.
- **Document interfaces**: define Firestore document shapes as Zod schemas with `z.infer<>` for TypeScript types.
- **Reuse**: extract common fields (timestamps, audit fields) into base schemas.

```typescript
const MyInputSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
  role: z.enum(["admin", "member", "viewer"]),
});
type MyInput = z.infer<typeof MyInputSchema>;
```

## Module system rules

- **CJS for Cloud Functions**: `require` / `module.exports` if the functions package uses CommonJS (check `"type"`).
- **ESM for frontend packages**: `import` / `export` for packages with `"type": "module"`.
- **Shared packages**: must be compatible with consumers — check their module system.

## Authorization variants

Detect which authorization pattern the project uses and follow it consistently.

### RBAC pattern
```typescript
// Middleware-based role-based access control
const uid = requireAuth(request);
await withAuthzRequired(uid, "resource:action");
// or
requirePermission(uid, Permission.MANAGE_USERS);
```

### OpenFGA pattern
```typescript
// Relationship-based access control (Zanzibar-style)
const allowed = await checkPermission(uid, "document:123", "edit");
if (!allowed) throw new HttpsError("permission-denied", "...");
```

Follow whichever pattern already exists in the codebase. If neither is present, use simple `requireAuth()` and note in `concerns[]` that authorization logic should be added. Adding a new authorization scheme is Tier 4: escalate.

## Role-specific gates

In addition to the gates in `agents/dev.md`:

1. **Audit logging**: every state-changing function logs an audit entry when the project has an audit helper.
2. **Validation at the boundary**: all external inputs pass the project's validation library before any business logic.
3. **Typed errors**: `HttpsError` (Cloud Functions) or the framework's typed error; never a bare string throw.
4. **Build order**: in monorepos, shared packages build before dependent packages.
5. **Emulator over mocks**: when `verify[]` runs Firebase code, prefer `firebase emulators:exec --only firestore,functions "<test cmd>"` over mocking `firebase-admin`.
