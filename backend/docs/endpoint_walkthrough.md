# Backend API Development Skill — NestJS (Music Room Project)

## Project Stack

| Layer | Technology |
|---|---|
| Runtime | Node.js |
| Framework | NestJS |
| Language | TypeScript (strict — no `any`) |
| ORM | Prisma |
| Database | PostgreSQL |
| Cache / Rate-limit | Redis |
| Auth | JWT via `@nestjs/jwt` + Passport (`passport-jwt`) |
| WebSockets | Socket.io (`@nestjs/platform-socket.io`) |
| WS Scaling | `@socket.io/redis-adapter` |
| API Docs | Swagger (OpenAPI 3.0) via `@nestjs/swagger` |
| Testing | Jest + Supertest |
| API Client | Postman — collection at `/postman/music-room-collection.json` |
| Email | MailService (console in dev, SMTP in prod) |

---

## 1. Architecture Pattern — Always Follow This

The project uses **N-Tier + Repository Pattern**. Every feature follows this strict layering:

```
Controller → Service → Repository → PrismaService → PostgreSQL
```

- **Controllers**: routing, decorators, DTO parsing only. No business logic.
- **Services**: business logic (hashing, token generation, orchestration). No direct Prisma calls.
- **Repositories**: the **only** files that inject and use `PrismaService`. All DB queries live here.
- **DTOs**: validate every incoming request with `class-validator` decorators.

File structure per feature:
```
/feature-name
  feature.module.ts
  feature.controller.ts
  feature.service.ts
  feature.repository.ts   ← only file that touches PrismaService
  feature.test.ts
  dto/
    create-feature.dto.ts
    update-feature.dto.ts
```

---

## 2. Authentication — Every Protected Route

All routes **must** be protected with `@UseGuards(JwtAuthGuard)` unless they are explicitly public (like `/auth/login`, `/auth/register`, `/auth/send-otp`, `/auth/verify-otp`).

```ts
// ✅ Correct — protected route
@UseGuards(JwtAuthGuard)
@Get('profile')
getProfile(@Request() req) {
  return req.user; // { id: string, email: string } — set by JwtStrategy.validate()
}

// ❌ Wrong — never expose business logic without the guard
@Get('profile')
getProfile(@Request() req) { ... }
```

### How the JWT guard works (do not change this flow):

1. `JwtAuthGuard` extends `AuthGuard('jwt')` → triggers `JwtStrategy`
2. `JwtStrategy` extracts the `Authorization: Bearer <token>` header
3. Verifies signature using `JWT_SECRET` from `ConfigService`
4. Calls `validate(payload)` which checks the user still exists in the DB
5. Returns `{ id, email }` which becomes `req.user` in the controller

### WebSocket Authentication:

WS routes are protected by `WsAuthGuard`. Clients must supply the JWT during the Socket.io handshake in `auth.token`. If validation fails, the connection is rejected with `connect_error`.

---

## 3. TypeScript Rules — Strictly Enforced

- **Never use `any`** — define proper interfaces or types, or use `unknown` + narrowing.
- Use `async/await` exclusively — no `.then()` chains.
- `camelCase` for variables/functions, `PascalCase` for types/interfaces/classes.
- Prefix booleans: `isActive`, `hasPermission`, `canEdit`.
- `const` by default, `let` only when reassignment is needed. Never `var`.
- Never use `!` (non-null assertion) without a clear comment explaining why it's safe.

```ts
// ✅
const user: User = await this.userRepository.findById(id);

// ❌
const user: any = await this.userRepository.findById(id);
```

---

## 4. Error Handling — Global Exception Filter

**Do not manually format error responses.** The project has a `GlobalExceptionFilter` registered in `main.ts` that normalizes ALL errors automatically.

### Standard response shapes (handled by the filter):

**Error:**
```json
{
  "status": "fail",       // "fail" for 4xx, "error" for 5xx
  "message": "...",
  "validationErrors": [{ "path": "field", "message": "..." }], // only for 400 validation
  "path": "/api/..."
}
```

**Success** (you write this in your controller/service):
```json
{
  "status": "success",
  "data": { }
}
```

### What to throw in your code:

```ts
// Client errors → throw NestJS HttpExceptions
throw new BadRequestException('Invalid input');
throw new NotFoundException('Resource not found');
throw new UnauthorizedException('Missing or invalid token');
throw new ForbiddenException('You do not have permission');
throw new ConflictException('Email already in use');

// Prisma errors → let them bubble up (filter maps them):
// P2002 → 409 Conflict
// P2025 → 404 Not Found
// PrismaClientValidationError → 400

// JWT errors → let them bubble up (filter maps them):
// JsonWebTokenError  → 401 "Invalid token."
// TokenExpiredError  → 401 "Token has expired."

// Unknown errors → let them bubble → filter returns 500 (no stack trace to client)
```

**Never** return raw Prisma errors, stack traces, or ad-hoc error shapes.

---

## 5. DTOs & Validation

Every endpoint that accepts a body or query params must have a DTO using `class-validator`:

```ts
import { IsEmail, IsString, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateUserDto {
  @ApiProperty({ example: 'user@mail.com', description: 'Valid email address' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'strongPass123', description: 'Minimum 8 characters' })
  @IsString()
  @MinLength(8)
  password: string;
}
```

- Always annotate every DTO field with `@ApiProperty()` — this auto-generates Swagger request body docs.
- NestJS + `ValidationPipe` (globally configured) throws a `400` with `validationErrors` automatically.

---

## 6. Swagger Documentation — Detailed for the Frontend Team

Swagger must be **complete enough for the frontend/mobile team to work without asking questions**.

Every endpoint must have:
- `@ApiTags('ResourceName')` — group by resource
- `@ApiBearerAuth()` — on every protected endpoint
- `@ApiOperation({ summary, description })` — summary is one line; description explains behavior, edge cases, side effects
- `@ApiParam` / `@ApiQuery` — all path/query params with type, required, and description
- `@ApiResponse` for `200`/`201`, `400`, `401`, `403`, `404`, `409`, `500` at minimum

```ts
@ApiTags('Orders')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('orders')
export class OrdersController {

  @Get(':id')
  @ApiOperation({
    summary: 'Get a single order by ID',
    description: `Returns full order details including items and status history.
    Only the owner or an admin can access this endpoint.
    Returns 403 if the authenticated user is neither.`,
  })
  @ApiParam({ name: 'id', type: String, description: 'UUID of the order' })
  @ApiResponse({ status: 200, description: 'Order returned successfully' })
  @ApiResponse({ status: 401, description: 'Token missing or invalid' })
  @ApiResponse({ status: 403, description: 'Not the owner or admin' })
  @ApiResponse({ status: 404, description: 'Order not found' })
  @ApiResponse({ status: 500, description: 'Unexpected server error' })
  getOrder(@Param('id') id: string, @Request() req) { ... }
}
```

> WebSocket events do NOT appear in Swagger. Document new WS events in `docs/websocket_contract.md` — this is the project convention.

---

## 7. WebSocket Events

Gateway file: `src/websockets/socket-io.gateway.ts` — Socket.io path: `/ws`.

### Current events:

| Direction | Event | Payload |
|---|---|---|
| C → S | `room:join` | `{ roomId: string }` |
| C → S | `room:leave` | `{ roomId: string }` |
| S → C | `room:joined` | `{ roomId: string }` |
| S → C | `room:left` | `{ roomId: string }` |
| S → C | `room:error` | `{ message: string }` |
| C → S | `ping` | none |
| S → C | `pong` | `{ serverTime: string }` |
| C → S | `track:vote` | `{ roomId, trackId, vote: "up" \| "down" \| "none" }` |
| S → C | `track:vote:updated` | `{ roomId, trackId, upVotes, downVotes, score, updatedAt }` |

### Rules when adding new WS events:

- Validate payloads with a DTO + `class-validator` — same discipline as REST.
- Protected events use `WsAuthGuard` — never skip it.
- Broadcast to a room using the Redis adapter so it works across multiple server instances.
- Document the new event in `docs/websocket_contract.md` — not in Swagger.
- Add a smoke test case in `scripts/ws-smoke-test.js`.

---

## 8. Prisma & Database Rules

- **Only repositories** inject and call `PrismaService`. Services never touch Prisma directly.
- Never write raw SQL — Prisma query API only.
- Wrap multi-step DB operations in `prisma.$transaction([...])`.
- Let Prisma errors bubble up — `GlobalExceptionFilter` maps them (`P2002` → 409, `P2025` → 404).
- After every `schema.prisma` change: `npx prisma generate` then `npx prisma migrate dev --name <description>`.
- Field naming: `camelCase` in schema, `PascalCase` for model names.
- Always add `@unique` / `@@unique` for uniqueness constraints.

```ts
// ✅ Correct — Prisma only in the repository
@Injectable()
export class OrderRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findById(id: string) {
    return this.prisma.order.findUnique({ where: { id } });
  }
}

// ❌ Wrong — service directly using Prisma
@Injectable()
export class OrderService {
  constructor(private readonly prisma: PrismaService) {} // never do this
}
```

---

## 9. Redis Usage Conventions

Redis is used for: OTP storage, OTP rate limiting, and WS pub/sub (Redis adapter).

- Key naming: `namespace:identifier` — e.g. `otp:user@mail.com`, `otp:rate:user@mail.com`
- Always set a TTL on every key — never write a key without expiry.

---

## 10. Testing — All Cases Required

Every endpoint needs a test file covering all possible cases:

| Case | Expected |
|---|---|
| Valid request (happy path) | `200` / `201` + correct response shape |
| Missing `Authorization` header | `401` |
| Expired or malformed token | `401` |
| Valid token, wrong role/ownership | `403` |
| Missing required body fields | `400` + `validationErrors` array |
| Invalid field format (bad email, etc.) | `400` + `validationErrors` array |
| Resource not found | `404` |
| Duplicate / unique constraint violation | `409` |
| Mocked DB or service failure | `500` |

```ts
describe('GET /orders/:id', () => {
  it('returns the order for the authenticated owner', async () => {});
  it('returns 401 if no token is provided', async () => {});
  it('returns 401 if the token is expired', async () => {});
  it('returns 403 if the user is not the owner', async () => {});
  it('returns 404 if the order does not exist', async () => {});
  it('returns 500 if the DB throws unexpectedly', async () => {});
});
```

- Mock Prisma with `jest.mock` — never test against production DB.
- Use `beforeAll` / `afterAll` for setup/teardown.
- Shared mock data goes in `test/fixtures/` or `test/mocks/`.

---

## 11. Postman Collection

Collection lives at `Postman/music-room-collection.json`.

**MANDATORY RULE:** Whenever you add or modify an API endpoint, you MUST simultaneously update the Postman collection in the same response. Do not wait for the user to explicitly ask you to update it.

- **Updating an existing route**: find the item and update it in place — never duplicate.
- **New route, existing resource folder**: add inside the existing folder (e.g. `Auth`, `Events`).
- **New route, new resource**: create a new folder named after the resource, then add the request.

Every Postman request must include:
- Correct HTTP method + URL using `{{baseUrl}}`
- `Authorization: Bearer {{token}}` on all protected routes
- Full request body example for POST/PUT
- At least one saved success response example
- A short description in the request's description field

---

## 12. Module Wiring Rules

- Every new feature gets its own module (`feature.module.ts`).
- Export only what other modules need — keep everything else module-private.
- `PrismaModule` is only imported into modules that have a repository.
- `JwtModule` is imported only where token signing/verification is needed.
- Never create circular dependencies — extract shared logic into a third module if two modules need each other.

---

## 13. Security Checklist — Verify Before Every PR

| Concern | Rule |
|---|---|
| Auth guard | `@UseGuards(JwtAuthGuard)` on every non-public route |
| Input | DTO + `class-validator` on every request body and param |
| Passwords | bcrypt, 10 salt rounds — never store plain text |
| JWT payload | Only `{ sub, email }` — never put sensitive data in JWT (signed, not encrypted) |
| Prisma errors | Let them bubble — never swallow or expose raw details |
| Stack traces | Never sent to client — `GlobalExceptionFilter` handles this |
| Env vars | Use `ConfigService.getOrThrow()` — app must fail fast on missing vars |
