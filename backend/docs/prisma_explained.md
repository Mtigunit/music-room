# Prisma — The Full Picture

## 1. Why Do We Need Prisma?

Your NestJS API needs to talk to PostgreSQL. You have two choices:

| Approach | Example | Drawback |
|---|---|---|
| **Raw SQL** | `SELECT * FROM users WHERE id = '...'` | No type safety, error-prone, manual mapping |
| **ORM (Prisma)** | `prisma.user.findUnique({ where: { id } })` | Type-safe, auto-completed, generates migrations |

Prisma is an **ORM** (Object-Relational Mapper). It sits between your TypeScript code and PostgreSQL, letting you work with **objects** instead of writing raw SQL strings.

---

## 2. The Three Layers of Prisma

```mermaid
graph TD
    A["schema.prisma<br/>(your data models)"] -->|npx prisma generate| B["@prisma/client<br/>(generated TypeScript code)"]
    B -->|used by| C["PrismaService<br/>(NestJS wrapper)"]
    C -->|injected into| D["Your services<br/>(AuthService, EventsService, etc.)"]
    D -->|queries| E["PostgreSQL"]
```

### Layer 1: `schema.prisma` — Your Source of Truth

This file defines your database tables and relationships in a human-readable format:

```prisma
model User {
  id           String   @id @default(uuid())
  email        String   @unique
  passwordHash String?
  events       Event[]  @relation("HostEvents")  // One user → many events
}
```

This is equivalent to writing:
```sql
CREATE TABLE "User" (
  id           TEXT PRIMARY KEY DEFAULT gen_random_uuid(),
  email        TEXT UNIQUE NOT NULL,
  "passwordHash" TEXT
);
```

But you never write that SQL yourself — Prisma does it for you.

---

### Layer 2: `@prisma/client` — The Generated Client

#### Why `npx prisma generate`?

Prisma doesn't ship a generic "talk to any database" library. Instead, it **reads your specific `schema.prisma`** and generates TypeScript code tailored to YOUR models.

```
npx prisma generate
```

This command reads your schema and creates files inside `node_modules/@prisma/client/` that contain:

- A `PrismaClient` class with methods like `.user`, `.event`, `.playlistItem`
- Full TypeScript types for every model, input, and query result
- Autocomplete for every field and relation

**You must re-run `npx prisma generate` every time you change `schema.prisma`**, otherwise the generated client is out of sync with your schema.

#### What is `PrismaClient`?

It's the generated class that knows how to talk to your database:

```typescript
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// These methods only exist because you defined User and Event in your schema
const user = await prisma.user.findUnique({ where: { email: 'foo@bar.com' } });
const events = await prisma.event.findMany({ where: { hostId: user.id } });
```

Every `prisma.xxxx` is auto-generated from your schema. If you add a `Song` model, after running `generate`, you get `prisma.song.findMany()` etc.

---

### Layer 3: `PrismaService` — The NestJS Wrapper

#### Why not just use `PrismaClient` directly?

NestJS uses **dependency injection (DI)**. Instead of creating `new PrismaClient()` in every file, you create one service that the framework manages and injects wherever needed.

```typescript
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
```

Let's break this down:

#### `extends PrismaClient`

`PrismaService` **inherits** everything from the generated `PrismaClient`. So `PrismaService` has all the same methods: `.user`, `.event`, `.playlistItem`, etc. It IS a PrismaClient, just wrapped in NestJS's DI system.

#### `OnModuleInit` → `$connect()`

- `OnModuleInit` is a **NestJS lifecycle hook** — the framework calls `onModuleInit()` automatically when the module finishes loading
- `this.$connect()` opens the database connection pool
- **Why here?** So the database connection is ready before any request hits your API. If the DB is unreachable, the app fails on startup (fail fast) instead of on the first user request

#### `OnModuleDestroy` → `$disconnect()`

- `OnModuleDestroy` is called when the app is shutting down (e.g., `Ctrl+C`, deployment restart)
- `this.$disconnect()` cleanly closes all database connections
- **Why?** Without this, connections could leak — the database would think your app is still connected even after it's stopped

---

## 3. How It's Used in Practice

#### In `PrismaModule`:
```typescript
@Module({
  providers: [PrismaService],
  exports: [PrismaService],     // ← makes it available to other modules
})
export class PrismaModule {}
```

#### In any other service (e.g., `AuthService`):
```typescript
@Injectable()
export class AuthService {
  // NestJS automatically injects the PrismaService singleton
  constructor(private prisma: PrismaService) {}

  async findUser(email: string) {
    // Full type safety + autocomplete here
    return this.prisma.user.findUnique({
      where: { email },
      include: { events: true },  // joins the events relation
    });
  }

  async createUser(data: { email: string; passwordHash: string }) {
    return this.prisma.user.create({ data });
  }
}
```

> [!TIP]
> You never import `PrismaClient` directly in your services — always inject `PrismaService`. This gives you a single shared connection pool across the entire app.

---

## 4. The Complete Workflow

Here's the full lifecycle from schema change to running code:

| Step | Command | What it does |
|------|---------|--------------|
| 1. Define models | Edit `schema.prisma` | Describe your tables & relations |
| 2. Generate client | `npx prisma generate` | Creates typed TS code in `node_modules` |
| 3. Create migration | `npx prisma migrate dev --name init` | Generates SQL & applies it to your DB |
| 4. Use in code | Inject `PrismaService` | Query your DB with full type safety |

> [!IMPORTANT]
> You haven't run **step 3** yet. `prisma generate` only creates the TypeScript types — it does NOT create the actual tables in PostgreSQL. You'll need `npx prisma migrate dev --name init` once your DB is running (via `docker compose up postgres`).

$env:DATABASE_URL="postgresql://admin:rootpassword@localhost:5432/music_room?schema=public"; npx prisma migrate status

docker compose exec -T postgres psql -U admin -d music_room -c "\dt"

---

## 5. Summary

```
schema.prisma          → "What does my database look like?"
npx prisma generate    → "Generate TypeScript code for those models"
npx prisma migrate dev → "Actually create/update the tables in PostgreSQL"
PrismaClient           → "The generated class that queries the DB"
PrismaService          → "NestJS wrapper so it plugs into dependency injection"
$connect()             → "Open DB connections when the app starts"
$disconnect()          → "Close DB connections when the app stops"
```
