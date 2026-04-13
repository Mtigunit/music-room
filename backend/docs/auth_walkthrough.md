# Authentication System — Detailed Walkthrough

## Architecture Overview

The auth system follows the **N-Tier + Repository Pattern** enforced by the project rules:

```
┌─────────────────────────────────────────────────────────┐
│                    HTTP Layer                           │
│   AuthController (routes, validation, decorators)       │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                 Service Layer                           │
│   AuthService (bcrypt, JWT signing, business logic)     │
│   UsersService (user lookups, delegation to repo)       │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│               Repository Layer                          │
│   UserRepository (Prisma queries — ONLY place           │
│                    PrismaService is injected)            │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                   Database                              │
│   PostgreSQL (User table with email, username,          │
│               passwordHash, etc.)                       │
└─────────────────────────────────────────────────────────┘
```

> [!IMPORTANT]
> `PrismaService` is **never** injected into `AuthService` or `UsersService`. All DB access goes through `UserRepository`.

---

## File Map

| File | Layer | Role |
|------|-------|------|
| [auth.controller.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/auth.controller.ts) | HTTP | Routes + Swagger docs |
| [auth.service.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/auth.service.ts) | Service | Password hashing, JWT generation, auth logic |
| [auth.module.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/auth.module.ts) | Config | Wires everything together |
| [register.dto.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/dto/register.dto.ts) | DTO | Validates registration input |
| [login.dto.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/dto/login.dto.ts) | DTO | Validates login input |
| [jwt-payload.interface.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/interfaces/jwt-payload.interface.ts) | Type | Shape of data inside the JWT |
| [jwt.strategy.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/strategies/jwt.strategy.ts) | Passport | Token extraction + verification + user lookup |
| [jwt-auth.guard.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/guards/jwt-auth.guard.ts) | Guard | Triggers the JWT strategy on protected routes |
| [users.service.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/users/users.service.ts) | Service | User CRUD operations |
| [user.repository.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/users/user.repository.ts) | Repository | Raw Prisma database queries |

---

## Flow 1: Registration (`POST /auth/register`)

```
Client sends:  { "email": "a@b.com", "username": "alice", "password": "secret123" }
```

### Step-by-step:

```mermaid
sequenceDiagram
    participant Client
    participant Controller as AuthController
    participant Pipe as ValidationPipe
    participant Service as AuthService
    participant Users as UsersService
    participant Repo as UserRepository
    participant DB as PostgreSQL

    Client->>Controller: POST /auth/register { email, username, password }
    Controller->>Pipe: Validate body against RegisterDto
    Note over Pipe: @IsEmail, @MinLength(3) username,<br/>@MinLength(8) password
    alt Validation fails
        Pipe-->>Client: 400 Bad Request + validation errors
    end
    Controller->>Service: register(dto)
    Service->>Users: findByEmail(dto.email)
    Users->>Repo: findByEmail(email)
    Repo->>DB: SELECT * FROM "User" WHERE email = ?
    DB-->>Repo: null (not found)
    Repo-->>Users: null
    Users-->>Service: null
    Note over Service: bcrypt.hash(password, 10 salt rounds)<br/>Produces "$2b$10$..." hash
    Service->>Users: create(email, username, passwordHash)
    Users->>Repo: create({ email, username, passwordHash })
    Repo->>DB: INSERT INTO "User" (email, username, passwordHash) ...
    DB-->>Repo: User record
    Note over Service: jwtService.sign({ sub: user.id, email: user.email })
    Service-->>Controller: { access_token: "eyJhbG..." }
    Controller-->>Client: 201 { access_token: "eyJhbG..." }
```

### Key security details:

1. **Password is never stored in plain text.** `bcrypt.hash()` with 10 salt rounds produces a one-way hash like `$2b$10$N9qo8uLOickgx2ZMRZoMye...`
2. **Duplicate email check** happens before hashing to avoid wasted CPU. If the email exists, throws `409 Conflict`.
3. **Duplicate username** is enforced at the DB level (`@unique` in Prisma). If hit, the global exception filter catches the Prisma `P2002` error and returns `409 Conflict`.

---

## Flow 2: Login (`POST /auth/login`)

```
Client sends:  { "email": "a@b.com", "password": "secret123" }
```

### Step-by-step:

```mermaid
sequenceDiagram
    participant Client
    participant Service as AuthService
    participant Users as UsersService
    participant DB as PostgreSQL

    Client->>Service: login({ email, password })
    Service->>Users: findByEmail(email)
    Users->>DB: SELECT * FROM "User" WHERE email = ?
    DB-->>Service: User { id, email, passwordHash, ... }
    
    alt User not found OR no passwordHash (OAuth-only account)
        Service-->>Client: 401 "Invalid credentials"
    end
    
    Note over Service: bcrypt.compare(password, user.passwordHash)<br/>Compares plain text against stored hash
    
    alt Password doesn't match
        Service-->>Client: 401 "Invalid credentials"
    end
    
    Note over Service: jwtService.sign({ sub: user.id, email: user.email })
    Service-->>Client: 200 { access_token: "eyJhbG..." }
```

> [!TIP]
> The error message is intentionally the same for "user not found" and "wrong password" — this prevents **user enumeration attacks** (an attacker can't tell if an email is registered).

---

## Flow 3: Accessing a Protected Route (`GET /auth/profile`)

```
Client sends:  GET /auth/profile
               Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

### Step-by-step:

```mermaid
sequenceDiagram
    participant Client
    participant Guard as JwtAuthGuard
    participant Strategy as JwtStrategy
    participant Users as UsersService
    participant DB as PostgreSQL
    participant Handler as getProfile()

    Client->>Guard: GET /auth/profile (with Bearer token)
    Guard->>Strategy: "Run the 'jwt' strategy"
    
    Note over Strategy: 1. Extract token from<br/>Authorization: Bearer header
    Note over Strategy: 2. Verify signature using JWT_SECRET
    Note over Strategy: 3. Check token hasn't expired (7d TTL)
    
    alt Token missing, invalid, or expired
        Strategy-->>Client: 401 Unauthorized
    end
    
    Note over Strategy: 4. Decode payload: { sub: "uuid", email: "a@b.com" }
    Strategy->>Users: findById(payload.sub)
    Users->>DB: SELECT * FROM "User" WHERE id = ?
    
    alt User was deleted after token was issued
        Strategy-->>Client: 401 "User no longer exists"
    end
    
    Note over Strategy: Return { id: user.id, email: user.email }
    Strategy-->>Guard: Attach to req.user
    Guard-->>Handler: Request proceeds
    Handler-->>Client: 200 { id: "uuid", email: "a@b.com" }
```

---

## What's Inside the JWT?

A JWT has three Base64-encoded parts separated by dots:

```
eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI1YTEyIiwiZW1haWwiOiJhQGIuY29tIiwiaWF0IjoxNzE1NTQ5fQ.HMAC_signature
└──── Header ────────┘ └──────────── Payload ───────────────────────────────────┘ └── Signature ──┘
```

**Header:** `{ "alg": "HS256" }` — the signing algorithm

**Payload (defined by [jwt-payload.interface.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/interfaces/jwt-payload.interface.ts)):**
```json
{
  "sub": "a5f12c9e-...",   // User ID (standard JWT "subject" claim)
  "email": "a@b.com",      // User email
  "iat": 1715549000,       // Issued at (auto-added by @nestjs/jwt)
  "exp": 1716153800        // Expires at (iat + 7 days, from signOptions)
}
```

**Signature:** `HMAC-SHA256(header + "." + payload, JWT_SECRET)` — proves the token wasn't tampered with.

> [!CAUTION]
> The payload is **encoded, not encrypted**. Anyone can decode it with `atob()`. Never put passwords or sensitive data in a JWT. The signature only guarantees **integrity**, not **secrecy**.

---

## Module Wiring

How NestJS knows what to inject where:

```mermaid
graph TD
    A[AuthModule] -->|imports| B[UsersModule]
    A -->|imports| C[PassportModule]
    A -->|imports| D[JwtModule.registerAsync]
    D -->|reads| E[ConfigService → JWT_SECRET]
    
    B -->|imports| F[PrismaModule]
    B -->|exports| G[UsersService]
    
    A -->|providers| H[AuthService]
    A -->|providers| I[JwtStrategy]
    A -->|controllers| J[AuthController]
    
    B -->|providers| K[UserRepository]
    B -->|providers| G
    
    F -->|provides + exports| L[PrismaService]
    
    K -->|injects| L
    G -->|injects| K
    H -->|injects| G
    H -->|injects| M[JwtService from JwtModule]
    I -->|injects| G
```

Key points:
- `UsersModule` **exports** `UsersService` so `AuthModule` can inject it into `AuthService` and `JwtStrategy`
- `JwtModule.registerAsync` uses `ConfigService` to read `JWT_SECRET` from `.env` at startup
- `JwtStrategy` is registered as a provider in `AuthModule` — Passport discovers it automatically
- `PrismaService` is only reachable by `UserRepository` (inside `UsersModule`)

---

## Security Summary

| Concern | How it's handled |
|---------|-----------------|
| Password storage | bcrypt with 10 salt rounds (one-way hash) |
| User enumeration | Same "Invalid credentials" message for wrong email and wrong password |
| Token integrity | HMAC-SHA256 signature using `JWT_SECRET` |
| Token expiry | 7-day TTL configured in `JwtModule` |
| Stale tokens | `JwtStrategy.validate()` checks user still exists in DB |
| Input validation | `class-validator` decorators on DTOs, `ValidationPipe` globally |
| Duplicate accounts | `@unique` constraint on email + username in Prisma schema |
| Missing env vars | `env.validation.ts` fails fast at startup if `JWT_SECRET` is missing |
