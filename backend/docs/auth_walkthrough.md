# Authentication System — Complete Tutorial

This guide explains every piece of the Music Room authentication system, how they connect, and why each decision was made.

---

## Table of Contents

1. [The Big Picture](#1-the-big-picture)
2. [Architecture & File Map](#2-architecture--file-map)
3. [Flow 1: Email Verification (OTP)](#3-flow-1-email-verification-otp)
4. [Flow 2: Registration](#4-flow-2-registration)
5. [Flow 3: Login](#5-flow-3-login)
6. [Flow 4: Accessing Protected Routes](#6-flow-4-accessing-protected-routes)
7. [Deep Dive: How the JWT Guard + Strategy Works](#7-deep-dive-how-the-jwt-guard--strategy-works)
8. [Deep Dive: Redis Key Design](#8-deep-dive-redis-key-design)
9. [Deep Dive: Module Wiring](#9-deep-dive-module-wiring)
10. [Security Summary](#10-security-summary)

---

## 1. The Big Picture

The auth system implements a **4-step flow** for new users:

```
Step 1                Step 2               Step 3              Step 4
─────────────         ─────────────        ─────────────       ──────────────
POST /send-otp   →    POST /verify-otp  →  POST /register  →  GET /profile
                                                               (+ any other
Send a 6-digit        Prove you own        Create account      protected
code to the           the email            with verified       routes)
user's inbox                               email
```

For returning users, it's just:

```
POST /login  →  GET /profile (with the returned token)
```

### Why verify email before registration?

The project specification requires email verification. By verifying **before** account creation (instead of after), we:
- Never store unverified accounts in the database
- Prevent spam accounts that clog up user tables
- Give the Flutter client a clean UX: verify → fill form → done

---

## 2. Architecture & File Map

The system follows the **N-Tier + Repository Pattern**:

```
┌─────────────────────────────────────────────────────────────┐
│  HTTP Layer                                                  │
│  Controllers handle routing, decorators, and input parsing   │
├─────────────────────────────────────────────────────────────┤
│  Service Layer                                               │
│  Business logic: hashing, token generation, OTP logic        │
├─────────────────────────────────────────────────────────────┤
│  Repository Layer                                            │
│  Database queries (ONLY layer that touches PrismaService)    │
├─────────────────────────────────────────────────────────────┤
│  Data Stores                                                 │
│  PostgreSQL (users)  +  Redis (OTPs, rate limits)            │
└─────────────────────────────────────────────────────────────┘
```

### Every file and its role

#### Auth Module
| File | Role |
|------|------|
| [auth.module.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/auth.module.ts) | Wires JWT, Passport, Users, and OTP modules together |
| [auth.controller.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/auth.controller.ts) | 5 routes: send-otp, verify-otp, register, login, profile |
| [auth.service.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/auth.service.ts) | Password hashing (bcrypt), JWT signing, token verification |
| [jwt.strategy.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/strategies/jwt.strategy.ts) | Passport strategy: extracts + verifies Bearer tokens |
| [jwt-auth.guard.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/guards/jwt-auth.guard.ts) | Decorator that triggers the JWT strategy on a route |
| [jwt-payload.interface.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/interfaces/jwt-payload.interface.ts) | TypeScript interface for JWT payload shape |

#### DTOs (Data Transfer Objects)
| File | Validates |
|------|-----------|
| [send-otp.dto.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/dto/send-otp.dto.ts) | `{ email }` — must be valid email format |
| [verify-otp.dto.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/dto/verify-otp.dto.ts) | `{ email, code }` — code must be exactly 6 characters |
| [register.dto.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/dto/register.dto.ts) | `{ email, username, password, emailVerificationToken }` |
| [login.dto.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/dto/login.dto.ts) | `{ email, password }` — email can be an email or username |

#### OTP Module
| File | Role |
|------|------|
| [otp.module.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/otp/otp.module.ts) | Wires Redis, Mail, Users, and JWT for OTP operations |
| [otp.service.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/otp/otp.service.ts) | OTP generation, Redis storage, rate limiting, verification |

#### Mail Module
| File | Role |
|------|------|
| [mail.module.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/mail/mail.module.ts) | Provides MailService |
| [mail.service.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/mail/mail.service.ts) | Sends emails via SMTP (or logs to console in dev mode) |

#### Users Module
| File | Role |
|------|------|
| [users.module.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/users/users.module.ts) | Provides UsersService, imports PrismaModule |
| [users.service.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/users/users.service.ts) | User lookups and creation (delegates to repository) |
| [user.repository.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/users/user.repository.ts) | **ONLY file that injects PrismaService** for user queries |

---

## 3. Flow 1: Email Verification (OTP)

### What the user sees (Flutter)

```
┌─────────────────────────────────┐
│  Register                        │
│                                  │
│  Email: [user@mail.com] [Verify] │  ← User clicks "Verify"
│                                  │
│  ┌─────────────────────────┐     │
│  │  Check your inbox!       │     │  ← Modal appears
│  │                          │     │
│  │  ┌─┬─┬─┬─┬─┬─┐          │     │
│  │  │ │ │ │ │ │ │          │     │  ← User types 6 digits
│  │  └─┴─┴─┴─┴─┴─┘          │     │
│  │  [Confirm]    [Resend]   │     │
│  └─────────────────────────┘     │
└─────────────────────────────────┘
```

### Step 1: `POST /auth/send-otp`

**Request:**
```json
{ "email": "user@mail.com" }
```

**What happens inside [otp.service.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/otp/otp.service.ts):**

```mermaid
sequenceDiagram
    participant Client as Flutter App
    participant Ctrl as AuthController
    participant OTP as OtpService
    participant Users as UsersService
    participant Redis
    participant Mail as MailService

    Client->>Ctrl: POST /auth/send-otp { email }
    Ctrl->>OTP: sendOtp(email)

    Note over OTP: 1. Is this email already registered?
    OTP->>Users: findByEmail(email)
    Users-->>OTP: null (not registered)

    Note over OTP: 2. Rate limit check
    OTP->>Redis: GET otp:rate:user@mail.com
    Redis-->>OTP: null (first request)

    Note over OTP: 3. Generate 6-digit code
    Note over OTP: crypto.randomInt(0, 1000000)<br/>→ "472915"

    Note over OTP: 4. Store in Redis with 5-min TTL
    OTP->>Redis: SET otp:user@mail.com "472915" EX 300
    OTP->>Redis: SET otp:attempts:user@mail.com "0" EX 300

    Note over OTP: 5. Increment rate limit
    OTP->>Redis: INCR otp:rate:user@mail.com
    OTP->>Redis: EXPIRE otp:rate:user@mail.com 900

    Note over OTP: 6. Send the email
    OTP->>Mail: sendOtpEmail("user@mail.com", "472915")

    Note over Mail: In dev mode: logs to console<br/>In prod: sends via SMTP

    OTP-->>Ctrl: void
    Ctrl-->>Client: 201 { message: "OTP sent successfully" }
```

**Where the code is stored (Redis view):**
```
┌──────────────────────────────────┬──────────┬─────────┐
│ Key                              │ Value    │ TTL     │
├──────────────────────────────────┼──────────┼─────────┤
│ otp:user@mail.com                │ "472915" │ 5 min   │
│ otp:attempts:user@mail.com       │ "0"      │ 5 min   │
│ otp:rate:user@mail.com           │ "1"      │ 15 min  │
└──────────────────────────────────┴──────────┴─────────┘
```

### Step 2: `POST /auth/verify-otp`

**Request:**
```json
{ "email": "user@mail.com", "code": "472915" }
```

```mermaid
sequenceDiagram
    participant Client as Flutter App
    participant OTP as OtpService
    participant Redis
    participant JWT as JwtService

    Client->>OTP: verifyOtp(email, "472915")

    Note over OTP: 1. Check brute-force attempts
    OTP->>Redis: GET otp:attempts:user@mail.com
    Redis-->>OTP: "0" (under limit of 5)

    Note over OTP: 2. Get stored OTP
    OTP->>Redis: GET otp:user@mail.com
    Redis-->>OTP: "472915"

    Note over OTP: 3. Timing-safe comparison
    Note over OTP: crypto.timingSafeEqual(<br/>  Buffer.from("472915"),<br/>  Buffer.from("472915")<br/>) → true ✅

    Note over OTP: 4. Delete OTP (single-use)
    OTP->>Redis: DEL otp:user@mail.com otp:attempts:user@mail.com

    Note over OTP: 5. Sign verification proof token
    OTP->>JWT: sign({ email, purpose: "email_verification" }, { expiresIn: "10m" })
    JWT-->>OTP: "eyJhbG..."

    OTP-->>Client: { emailVerificationToken: "eyJhbG..." }
```

**What if the code is wrong?**
```
Attempt 1: wrong code → attempts = 1, "Invalid OTP"
Attempt 2: wrong code → attempts = 2, "Invalid OTP"
...
Attempt 5: wrong code → OTP DELETED, "Too many failed attempts. Request a new OTP."
```

**What if the OTP expired?**
```
After 5 minutes → Redis auto-deletes the key → "OTP expired or not found"
```

**Response (success):**
```json
{ "emailVerificationToken": "eyJhbGciOiJIUzI1NiIs..." }
```

This token is a **short-lived JWT** (10 minutes) that proves "this email was verified." The Flutter app stores it temporarily and sends it with the registration request.

---

## 4. Flow 2: Registration

### `POST /auth/register`

**Request:**
```json
{
  "email": "user@mail.com",
  "username": "cool_musician",
  "password": "Abdel@1234",
  "emailVerificationToken": "eyJhbGciOiJIUzI1NiIs..."
}
```

**What happens inside [auth.service.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/auth.service.ts):**

```mermaid
sequenceDiagram
    participant Client as Flutter App
    participant Pipe as ValidationPipe
    participant Auth as AuthService
    participant JWT as JwtService
    participant Users as UsersService
    participant Repo as UserRepository
    participant DB as PostgreSQL

    Client->>Pipe: POST /auth/register { email, username, password, token }

    Note over Pipe: Validate DTO:<br/>@IsEmail ✓<br/>@MinLength(3) username ✓<br/>@Matches(alphanumeric) username ✓<br/>@MinLength(8) password ✓<br/>@Matches(complexity) password ✓<br/>@IsString token ✓

    Pipe->>Auth: register(dto)

    Note over Auth: ── Step 1: Verify the proof token ──
    Auth->>JWT: verify(emailVerificationToken)
    JWT-->>Auth: { email: "user@mail.com", purpose: "email_verification" }

    Note over Auth: Does token.email match dto.email?<br/>"user@mail.com" === "user@mail.com" ✅
    Note over Auth: Is purpose correct?<br/>"email_verification" === "email_verification" ✅

    Note over Auth: ── Step 2: Check duplicates ──
    Auth->>Users: findByEmail("user@mail.com")
    Users->>Repo: findByEmail("user@mail.com")
    Repo->>DB: SELECT * FROM "User" WHERE email = $1
    DB-->>Auth: null ✅ (not taken)

    Auth->>Users: findByUsername("cool_musician")
    Users->>Repo: findByUsername("cool_musician")
    Repo->>DB: SELECT * FROM "User" WHERE username = $1
    DB-->>Auth: null ✅ (not taken)

    Note over Auth: ── Step 3: Hash password ──
    Note over Auth: bcrypt.hash("Abdel@1234", 10)<br/>→ "$2b$10$N9qo8uLO..."

    Note over Auth: ── Step 4: Create user ──
    Auth->>Users: create(email, username, passwordHash)
    Users->>Repo: create({ email, username, passwordHash })
    Repo->>DB: INSERT INTO "User" (email, username, "passwordHash") VALUES (...)
    DB-->>Auth: User { id: "a5f1...", email, username }

    Note over Auth: ── Step 5: Generate access token ──
    Auth->>JWT: sign({ sub: "a5f1...", email: "user@mail.com" })
    JWT-->>Auth: "eyJhbG..."

    Auth-->>Client: 201 { access_token: "eyJhbG..." }
```

### Input validation details

The [RegisterDto](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/dto/register.dto.ts) enforces:

| Field | Rules | Example Invalid |
|-------|-------|-----------------|
| `email` | Valid email format | `"notanemail"` |
| `username` | 3-30 chars, alphanumeric + `_` only | `"ab"`, `"user@name"`, `"has space"` |
| `password` | Min 8 chars, 1 uppercase, 1 lowercase, 1 number, 1 special char | `"password"`, `"Password1"`, `"Pass@"` |
| `emailVerificationToken` | Non-empty string | `""` |

### What can go wrong?

| Error | HTTP Code | When |
|-------|-----------|------|
| Validation fails | 400 | DTO rules violated |
| Token invalid/expired | 400 | JWT verification fails or token is older than 10 min |
| Token email mismatch | 400 | Token was issued for a different email |
| Wrong token purpose | 400 | Token's `purpose` isn't `"email_verification"` |
| Email taken | 409 | Another user registered with this email |
| Username taken | 409 | Another user has this username |

---

## 5. Flow 3: Login

### `POST /auth/login`

**Request (with email):**
```json
{ "email": "user@mail.com", "password": "Abdel@1234" }
```

**Request (with username):**
```json
{ "email": "cool_musician", "password": "Abdel@1234" }
```

The service detects which one you sent by checking for `@`:

```typescript
// auth.service.ts — login method
if (dto.email.includes('@')) {
  user = await this.usersService.findByEmail(dto.email);   // email path
} else {
  user = await this.usersService.findByUsername(dto.email); // username path
}
```

```mermaid
sequenceDiagram
    participant Client as Flutter App
    participant Auth as AuthService
    participant Users as UsersService
    participant DB as PostgreSQL

    Client->>Auth: login({ email: "cool_musician", password: "Abdel@1234" })

    Note over Auth: "cool_musician" has no @ → username path
    Auth->>Users: findByUsername("cool_musician")
    Users->>DB: SELECT * FROM "User" WHERE username = $1
    DB-->>Auth: User { id, email, passwordHash, ... }

    Note over Auth: bcrypt.compare("Abdel@1234", "$2b$10$N9qo8uLO...")<br/>→ true ✅

    Note over Auth: jwtService.sign({ sub: user.id, email: user.email })

    Auth-->>Client: 200 { access_token: "eyJhbG..." }
```

### Security: Anti-enumeration

The error message is **the same** whether the email doesn't exist or the password is wrong:

```
"Invalid credentials"
```

This prevents an attacker from discovering which emails are registered by trying different emails and watching for different error messages.

---

## 6. Flow 4: Accessing Protected Routes

### `GET /auth/profile`

**Request:**
```
GET /auth/profile
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

```mermaid
sequenceDiagram
    participant Client as Flutter App
    participant Guard as JwtAuthGuard
    participant Strategy as JwtStrategy
    participant Users as UsersService
    participant DB as PostgreSQL
    participant Handler as getProfile()

    Client->>Guard: GET /auth/profile + Bearer token

    Note over Guard: "Run the strategy named 'jwt'"
    Guard->>Strategy: authenticate(request)

    Note over Strategy: 1. Extract token from header
    Note over Strategy: Authorization: Bearer eyJhbG...<br/>→ "eyJhbG..."

    Note over Strategy: 2. Verify signature with JWT_SECRET
    Note over Strategy: 3. Check exp claim (not expired, < 7 days)

    Note over Strategy: 4. Decoded: { sub: "a5f1...", email: "user@mail.com" }

    Strategy->>Users: findById("a5f1...")
    Users->>DB: SELECT * FROM "User" WHERE id = $1
    DB-->>Strategy: User exists ✅

    Note over Strategy: Return { id: "a5f1...", email: "user@mail.com" }

    Strategy-->>Guard: Attach to req.user
    Guard-->>Handler: ✅ Request allowed

    Handler-->>Client: 200 { id: "a5f1...", email: "user@mail.com" }
```

### Using the guard on any route

To protect any new endpoint, just add two decorators:

```typescript
@Get('some-data')
@UseGuards(JwtAuthGuard)    // Blocks unauthenticated requests
@ApiBearerAuth()            // Shows the lock icon in Swagger docs
getSomeData(@Request() req: AuthenticatedRequest) {
  const userId = req.user.id;  // Guaranteed to exist
  // ... your logic
}
```

---

## 7. Deep Dive: How the JWT Guard + Strategy Works

This is the part that confuses most people. Here's the mental model:

### Passport is a plugin system with a registry

```
                    ┌──────────────────────────────┐
                    │     Passport Registry         │
                    │                               │
                    │  "jwt"    → JwtStrategy       │
                    │  "local"  → (if you add one)  │
                    │  "google" → (if you add one)  │
                    └──────────────────────────────┘
```

### How a strategy gets registered

When NestJS instantiates `JwtStrategy` (because it's in `AuthModule.providers`):

```typescript
// jwt.strategy.ts
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(configService, usersService) {
    super({                                          // ← This calls passport-jwt's constructor
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: configService.getOrThrow('JWT_SECRET'),
    });
    // After super(), passport internally runs:
    // passport.use('jwt', this)  ← REGISTERED!
  }
}
```

### How a guard finds the strategy

```typescript
// jwt-auth.guard.ts
export class JwtAuthGuard extends AuthGuard('jwt') {}
//                                          ^^^^
//                                "find strategy named 'jwt'"
```

When `@UseGuards(JwtAuthGuard)` runs, it calls `passport.authenticate('jwt')`, which:
1. Looks up `'jwt'` in the registry → finds your `JwtStrategy`
2. Uses the `super()` config to extract and verify the token
3. If token is valid, calls **your** `validate()` method
4. Whatever `validate()` returns becomes `req.user`

### The validate() method is YOUR code

```typescript
// jwt.strategy.ts
async validate(payload: JwtPayload): Promise<{ id: string; email: string }> {
  // payload = decoded JWT: { sub: "uuid", email: "a@b.com", iat: ..., exp: ... }

  const user = await this.usersService.findById(payload.sub);

  if (!user) {
    throw new UnauthorizedException('User no longer exists');
  }

  // Whatever you return here becomes req.user
  return { id: user.id, email: user.email };
}
```

---

## 8. Deep Dive: Redis Key Design

The OTP system uses three types of Redis keys:

```
┌────────────────────────────────────────────────────────────────────┐
│ Purpose        │ Key Pattern                  │ Value  │ TTL      │
├────────────────┼──────────────────────────────┼────────┼──────────┤
│ OTP code       │ otp:{email}                  │ "4729" │ 5 min    │
│                │ otp:user@mail.com            │        │          │
├────────────────┼──────────────────────────────┼────────┼──────────┤
│ Verify attempts│ otp:attempts:{email}         │ "2"    │ 5 min    │
│                │ otp:attempts:user@mail.com   │        │ (same as │
│                │                              │        │  the OTP)│
├────────────────┼──────────────────────────────┼────────┼──────────┤
│ Rate limiting  │ otp:rate:{email}             │ "3"    │ 15 min   │
│ (send count)   │ otp:rate:user@mail.com       │        │          │
└────────────────┴──────────────────────────────┴────────┴──────────┘
```

### Lifecycle of a complete OTP flow

```
Time 0:00  → POST /send-otp
             Redis: SET otp:a@b.com "472915" EX 300
                    SET otp:attempts:a@b.com "0" EX 300
                    INCR otp:rate:a@b.com → 1

Time 0:30  → POST /verify-otp (wrong code)
             Redis: GET otp:attempts:a@b.com → "0" (ok)
                    GET otp:a@b.com → "472915"
                    compare "111111" vs "472915" → FAIL
                    INCR otp:attempts:a@b.com → 1

Time 0:45  → POST /verify-otp (correct code)
             Redis: GET otp:attempts:a@b.com → "1" (ok)
                    GET otp:a@b.com → "472915"
                    compare "472915" vs "472915" → MATCH
                    DEL otp:a@b.com otp:attempts:a@b.com
             Returns: { emailVerificationToken: "eyJ..." }

Time 5:00  → If never verified, Redis auto-deletes otp:a@b.com
             Next verify attempt → "OTP expired or not found"
```

---

## 9. Deep Dive: Module Wiring

How NestJS knows what to inject where:

```mermaid
graph TD
    subgraph AuthModule
        AC[AuthController]
        AS[AuthService]
        JStrat[JwtStrategy]
    end

    subgraph OtpModule
        OS[OtpService]
    end

    subgraph MailModule
        MS[MailService]
    end

    subgraph UsersModule
        US[UsersService]
        UR[UserRepository]
    end

    subgraph PrismaModule
        PS[PrismaService]
    end

    subgraph RedisModule
        RS[RedisService]
    end

    subgraph External
        JWT[JwtModule / JwtService]
        PP[PassportModule]
    end

    AC --> AS
    AC --> OS
    AS --> US
    AS --> JWT
    JStrat --> US

    OS --> RS
    OS --> MS
    OS --> US
    OS --> JWT

    US --> UR
    UR --> PS

    AuthModule -->|imports| OtpModule
    AuthModule -->|imports| UsersModule
    AuthModule -->|imports| PP
    AuthModule -->|imports| JWT

    OtpModule -->|imports| RedisModule
    OtpModule -->|imports| MailModule
    OtpModule -->|imports| UsersModule

    UsersModule -->|imports| PrismaModule
```

### Key rules

1. **PrismaService** is only injected into `UserRepository` — nowhere else
2. **UsersModule exports** `UsersService`, so both `AuthModule` and `OtpModule` can use it
3. **JwtModule** is imported in both `AuthModule` (for access tokens, 7-day expiry) and `OtpModule` (for verification tokens, 10-min expiry)
4. Each module declares what it **provides** (internal) and **exports** (available to importers)

---

## 10. Security Summary

| Threat | Protection | Where |
|--------|-----------|-------|
| **Password theft** | bcrypt hashing, 10 salt rounds | [auth.service.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/auth.service.ts) |
| **User enumeration** | Same error for wrong email + wrong password | `auth.service.ts` login() |
| **OTP brute-force** | Max 5 attempts, then OTP deleted | [otp.service.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/otp/otp.service.ts) |
| **OTP spam** | Max 5 sends per email per 15 minutes | `otp.service.ts` sendOtp() |
| **Timing attacks** | `crypto.timingSafeEqual` for OTP comparison | `otp.service.ts` safeCompare() |
| **Token tampering** | HMAC-SHA256 signature on all JWTs | `@nestjs/jwt` |
| **Token replay** | Access tokens expire in 7 days, verification tokens in 10 min | `auth.module.ts`, `otp.service.ts` |
| **Stale tokens** | `JwtStrategy.validate()` checks user still exists in DB | [jwt.strategy.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/auth/strategies/jwt.strategy.ts) |
| **Invalid input** | class-validator decorators on all DTOs | `register.dto.ts`, etc. |
| **Duplicate accounts** | `@unique` on email + username in Prisma schema | [schema.prisma](file:///c:/Users/abdel/Desktop/music-room/backend/prisma/schema.prisma) |
| **Missing env vars** | Fail-fast validation at startup | [env.validation.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/config/env.validation.ts) |
| **Dev email leaks** | Console logging in dev mode, real SMTP only in production | [mail.service.ts](file:///c:/Users/abdel/Desktop/music-room/backend/src/mail/mail.service.ts) |

> [!CAUTION]
> JWTs are **signed, not encrypted**. The payload (`{ sub, email }`) can be decoded by anyone with `atob()`. Never put passwords or sensitive data inside a JWT. The signature only guarantees **integrity** (nobody tampered with it), not **secrecy**.

---

## Quick Reference: All Endpoints

| Method | Route | Auth | Request Body | Response |
|--------|-------|------|-------------|----------|
| `POST` | `/auth/send-otp` | None | `{ email }` | `{ message }` |
| `POST` | `/auth/verify-otp` | None | `{ email, code }` | `{ emailVerificationToken }` |
| `POST` | `/auth/register` | None | `{ email, username, password, emailVerificationToken }` | `{ access_token }` |
| `POST` | `/auth/login` | None | `{ email, password }` | `{ access_token }` |
| `GET` | `/auth/profile` | Bearer | — | `{ id, email }` |
