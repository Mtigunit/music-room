# Complete Authentication Guide: From Concepts to Implementation
## A Comprehensive Backend Developer's Manual for Node.js & Express.js

---

## Table of Contents
1. [Authentication Fundamentals](#fundamentals)
2. [Password Hashing & Storage](#password-hashing)
3. [Session Management](#session-management)
4. [JWT (JSON Web Tokens)](#jwt)
5. [OAuth 2.0 Deep Dive](#oauth2)
6. [Multi-Factor Authentication (MFA)](#mfa)
7. [Security Vulnerabilities & Prevention](#vulnerabilities)
8. [Rate Limiting & Brute Force Protection](#rate-limiting)
9. [CSRF Protection](#csrf-protection)
10. [Complete Implementation Examples](#complete-examples)

---

# Fundamentals

## What is Authentication?

Authentication is the process of **verifying that a user is who they claim to be**. It answers the question: "Is this really the user they say they are?"

### Key Concepts

**Authentication** (AuthN): Verifying identity
**Authorization** (AuthZ): Verifying permissions after authentication
**Session**: A way to maintain authenticated state across requests
**Credentials**: Username/password, tokens, certificates, etc.

## Authentication Flow Overview

```
1. User provides credentials (username/password)
   ↓
2. Server validates credentials against database
   ↓
3. If valid, server creates a session/token
   ↓
4. User includes session/token with future requests
   ↓
5. Server verifies session/token before processing requests
```

---

# Password Hashing & Storage

## Why Hash Passwords?

**NEVER store passwords in plaintext.** If your database is compromised, attackers get all passwords.

## Hashing Algorithms Comparison

| Algorithm | Speed | Security | Memory Usage | Recommendation |
|-----------|-------|----------|--------------|-----------------|
| bcrypt | Slow (by design) | ⭐⭐⭐⭐⭐ | Low | ✅ Best for most cases |
| Argon2 | Slow | ⭐⭐⭐⭐⭐ | High | ✅ Best for high security |
| scrypt | Medium | ⭐⭐⭐⭐ | High | Good alternative |
| PBKDF2 | Medium | ⭐⭐⭐ | Low | Legacy, avoid for new projects |

## Implementation: Password Hashing with Bcrypt

### Installation
```bash
npm install bcrypt
```


### Code Example (NestJS)

```typescript
// auth.service.ts
import { Injectable } from '@nestjs/common';
import * as bcrypt from 'bcrypt';

@Injectable()
export class AuthService {
  async hashPassword(plainPassword: string): Promise<string> {
    const salt = await bcrypt.genSalt(10);
    return bcrypt.hash(plainPassword, salt);
  }

  async comparePasswords(plainPassword: string, hashedPassword: string): Promise<boolean> {
    return bcrypt.compare(plainPassword, hashedPassword);
  }
}

// Usage in registration
const hashed = await this.authService.hashPassword(dto.password);
// Save hashed to DB

// Usage in login
const isValid = await this.authService.comparePasswords(dto.password, user.password);
// Use isValid for login logic
```

## Implementation: Argon2 (Recommended for High Security)

### Installation
```bash
npm install argon2
```

### Code Example


```typescript
// auth.service.ts (Argon2)
import { Injectable } from '@nestjs/common';
import * as argon2 from 'argon2';

@Injectable()
export class AuthService {
  async hashPasswordArgon2(plainPassword: string): Promise<string> {
    return argon2.hash(plainPassword, {
      type: argon2.argon2id,
      memoryCost: 65536,
      timeCost: 3,
      parallelism: 1,
    });
  }

  async verifyPasswordArgon2(plainPassword: string, hash: string): Promise<boolean> {
    return argon2.verify(hash, plainPassword);
  }
}
```

## Best Practices for Passwords

✅ **DO:**
- Enforce minimum 12-character passwords
- Allow special characters and long passwords (passphrases)
- Use bcrypt (10+ rounds) or Argon2
- Implement password expiration policies
- Force password change on first login

❌ **DON'T:**
- Store passwords in plaintext
- Use simple hashing (MD5, SHA1)
- Implement your own hashing algorithm
- Use weak salts
- Store passwords in logs or error messages

---

# Session Management

## What is a Session?

A **session** is a way to maintain authenticated state across multiple HTTP requests. Since HTTP is stateless, sessions link requests to a specific user.

## How Sessions Work

```
1. User logs in with credentials
2. Server validates credentials
3. Server creates session object with unique session ID
4. Session ID stored in cookie sent to browser
5. Browser automatically includes cookie in future requests
6. Server retrieves session from ID and authenticates request
```


## Session Management with NestJS

### Installation
```bash
npm install express-session
npm install --save-dev @types/express-session
```

### Basic Setup in main.ts

```typescript
import * as session from 'express-session';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.use(
    session({
      secret: process.env.SESSION_SECRET || 'your-secret-key',
      resave: false,
      saveUninitialized: false,
      cookie: {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 24 * 60 * 60 * 1000,
      },
      name: 'sessionId',
    }),
  );
  await app.listen(3000);
}
bootstrap();
```

### Controller Example

```typescript
import { Controller, Get, Post, Req, Res } from '@nestjs/common';
import { Request, Response } from 'express';

@Controller()
export class AuthController {
  @Post('login')
  async login(@Req() req: Request, @Res() res: Response) {
    // ...authenticate user
    req.session.userId = user.id;
    req.session.email = user.email;
    req.session.role = user.role;
    res.json({ message: 'Logged in successfully' });
  }

  @Get('profile')
  getProfile(@Req() req: Request, @Res() res: Response) {
    if (!req.session?.userId) {
      return res.status(401).json({ error: 'Not authenticated' });
    }
    res.json({ userId: req.session.userId, email: req.session.email });
  }

  @Post('logout')
  logout(@Req() req: Request, @Res() res: Response) {
    req.session.destroy((err) => {
      if (err) {
        return res.status(500).json({ error: 'Logout failed' });
      }
      res.clearCookie('sessionId');
      res.json({ message: 'Logged out successfully' });
    });
  }
}
```

## Session Storage in Production

**In-memory storage (default) is INSECURE for production:**
- Sessions lost on server restart
- Doesn't work with load balancing/multiple servers

**Production solutions:**


### Redis Store (Recommended, NestJS)

```typescript
// main.ts
import * as session from 'express-session';
import * as RedisStore from 'connect-redis';
import { createClient } from 'redis';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  const redisClient = createClient({
    url: `redis://${process.env.REDIS_HOST || 'localhost'}:${process.env.REDIS_PORT || 6379}`,
  });
  await redisClient.connect();

  app.use(
    session({
      store: new (RedisStore(session))({ client: redisClient }),
      secret: process.env.SESSION_SECRET || 'your-secret-key',
      resave: false,
      saveUninitialized: false,
      cookie: {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 24 * 60 * 60 * 1000,
      },
      name: 'sessionId',
    }),
  );
  await app.listen(3000);
}
bootstrap();
```

### MongoDB Store

```bash
npm install connect-mongo
```

```javascript
const session = require('express-session');
const MongoStore = require('connect-mongo').default;
const mongoose = require('mongoose');

app.use(session({
  store: new MongoStore({
    mongoUrl: process.env.MONGODB_URI
  }),
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: true,
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000
  }
}));
```

## Session Security Best Practices

✅ **DO:**
- Use httpOnly flag (prevents XSS access)
- Use secure flag (HTTPS only)
- Set appropriate maxAge
- Implement session timeout
- Regenerate session ID after login
- Use strong, random session secrets
- Store sessions server-side (Redis/DB)

❌ **DON'T:**
- Store sensitive data directly in sessions
- Use predictable session IDs
- Allow persistent sessions
- Store sessions in cookies (encrypt if necessary)
- Expose session IDs in URLs

---

# JWT (JSON Web Tokens)

## What is JWT?

A **JWT** is a stateless token that contains encoded information about a user. Instead of storing sessions on the server, the client stores the token and sends it with each request.

## JWT Structure

```
Header.Payload.Signature

Example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

**Header:** Token type and hashing algorithm
**Payload:** User data (claims)
**Signature:** Cryptographic signature to verify token integrity

## JWT Implementation

### Installation
```bash
npm install jsonwebtoken
```


### Generate JWT (NestJS)

```typescript
// auth.service.ts
import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

@Injectable()
export class AuthService {
  constructor(private jwtService: JwtService) {}

  async generateToken(user: any): Promise<string> {
    const payload = { id: user.id, email: user.email, role: user.role };
    return this.jwtService.sign(payload, {
      expiresIn: '1h',
      issuer: 'your-app',
      audience: 'your-app-users',
    });
  }

  async generateTokenPair(user: any): Promise<{ accessToken: string; refreshToken: string }> {
    const payload = { id: user.id, email: user.email, role: user.role };
    const accessToken = this.jwtService.sign(payload, { expiresIn: '15m' });
    const refreshToken = this.jwtService.sign({ id: user.id, type: 'refresh' }, {
      secret: process.env.JWT_REFRESH_SECRET,
      expiresIn: '7d',
    });
    return { accessToken, refreshToken };
  }
}
```


### Verify JWT (NestJS)

```typescript
// auth.service.ts
async verifyToken(token: string): Promise<any> {
  try {
    return this.jwtService.verify(token, {
      issuer: 'your-app',
      audience: 'your-app-users',
    });
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      throw new Error('Token expired');
    }
    if (error.name === 'JsonWebTokenError') {
      throw new Error('Invalid token');
    }
    throw error;
  }
}
```


### JWT Guard (NestJS)

```typescript
// auth.guard.ts
import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}

// Usage in controller
import { Controller, Get, UseGuards, Request } from '@nestjs/common';
@Controller()
export class AppController {
  @UseGuards(JwtAuthGuard)
  @Get('protected')
  getProtected(@Request() req) {
    return { message: `Hello ${req.user.email}` };
  }
}
```

### Refresh Token Flow

```javascript
app.post('/refresh', (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    return res.status(401).json({ error: 'No refresh token' });
  }

  try {
    // Verify refresh token
    const decoded = jwt.verify(
      refreshToken,
      process.env.JWT_REFRESH_SECRET,
      { algorithms: ['HS256'] }
    );

    // Generate new access token
    const user = await User.findById(decoded.id);
    const newAccessToken = jwt.sign(
      {
        id: user.id,
        email: user.email,
        role: user.role
      },
      process.env.JWT_SECRET,
      { expiresIn: '15m' }
    );

    res.json({ accessToken: newAccessToken });
  } catch (error) {
    return res.status(403).json({ error: 'Invalid refresh token' });
  }
});
```

## JWT Best Practices

✅ **DO:**
- Use RSA or ECDSA for signing (asymmetric) - especially for distributed systems
- Keep access tokens short-lived (15 min - 1 hour)
- Keep refresh tokens long-lived (7 days - 30 days)
- Implement token rotation (issue new refresh token on refresh)
- Store refresh tokens in HTTP-only cookies
- Validate token signature, expiration, issuer, and audience
- Use strong secrets (32+ characters)

❌ **DON'T:**
- Store sensitive data in JWT (it's encoded, not encrypted)
- Use weak secrets
- Ignore token expiration
- Store access tokens in localStorage (vulnerable to XSS)
- Trust the JWT without validating signature
- Use "none" algorithm
- Hardcode secrets in code

---

# OAuth 2.0 Deep Dive

## What is OAuth 2.0?

**OAuth 2.0** is an **authorization** framework (not authentication) that allows users to grant applications access to their resources at another service without sharing their password.

### Real-World Example
"Sign in with Google" on another website:
1. You click "Sign in with Google"
2. You're redirected to Google's login
3. You grant the app permission to access your email
4. You're redirected back with an authorization code
5. The app exchanges the code for an access token
6. The app uses the token to access your Google resources

## OAuth 2.0 Flows

### 1. Authorization Code Flow (Server-to-Server)

**Use for:** Web apps, mobile apps, server-to-server
**Security:** HIGH (secrets stay on server)

```
┌─────────────────────────────────────────────────────────────┐
│ CLIENT (Browser)                                             │
└─────────────────────────────────────────────────────────────┘
                            │
                    Click "Sign in with Google"
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ AUTHORIZATION SERVER (Google)                               │
│ Step 1: Client redirected here with client_id, state        │
│ Step 2: Show login & consent screen                         │
│ Step 3: Redirect back with authorization code               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ OUR SERVER (Backend)                                        │
│ Step 4: Exchange code + client_secret for access_token      │
│ Step 5: Fetch user profile                                  │
│ Step 6: Create/update user, generate JWT                    │
└─────────────────────────────────────────────────────────────┘
```


### Implementation: Authorization Code Flow (NestJS)

```typescript
// google.strategy.ts
import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy, VerifyCallback } from 'passport-google-oauth20';

@Injectable()
export class GoogleStrategy extends PassportStrategy(Strategy, 'google') {
  constructor() {
    super({
      clientID: process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET,
      callbackURL: 'http://localhost:3000/auth/google/callback',
      scope: ['email', 'profile'],
    });
  }

  async validate(accessToken: string, refreshToken: string, profile: any, done: VerifyCallback): Promise<any> {
    // Find or create user logic here
    const user = { googleId: profile.id, email: profile.emails[0].value, name: profile.displayName };
    done(null, user);
  }
}

// auth.controller.ts
import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Controller('auth')
export class AuthController {
  @Get('google')
  @UseGuards(AuthGuard('google'))
  async googleAuth() {}

  @Get('google/callback')
  @UseGuards(AuthGuard('google'))
  googleAuthRedirect(@Req() req) {
    // Issue JWT and redirect as needed
    return req.user;
  }
}
```


### 2. PKCE Flow (Proof Key for Code Exchange, NestJS)

**Use for:** Mobile apps, single-page applications (SPAs)
**Security:** HIGH (protects against authorization code interception)

PKCE is mostly a frontend concern, but you can provide a utility in NestJS for generating/verifying PKCE values:

```typescript
// pkce.util.ts
import * as crypto from 'crypto';

export function base64URLEncode(buffer: Buffer): string {
  return buffer.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

export function generatePKCE() {
  const codeVerifier = base64URLEncode(crypto.randomBytes(32));
  const hash = crypto.createHash('sha256').update(codeVerifier).digest();
  const codeChallenge = base64URLEncode(hash);
  return { codeVerifier, codeChallenge, codeChallengeMethod: 'S256' };
}
```

You would use this utility in your controller to generate PKCE values and store the codeVerifier in the session or database for later verification.


### 3. Client Credentials Flow (NestJS)

**Use for:** Machine-to-machine authentication (server to server, no user)

```typescript
// auth.controller.ts
import { Controller, Post, Body, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

@Controller('oauth')
export class OAuthController {
  constructor(private jwtService: JwtService) {}

  @Post('token')
  async getToken(@Body() body: any) {
    const { grant_type, client_id, client_secret, scope } = body;
    if (grant_type !== 'client_credentials') {
      throw new BadRequestException('Invalid grant_type');
    }
    // Replace with your own client lookup and secret check
    const client = await this.findOAuthClient(client_id);
    if (!client || !(await this.verifySecret(client_secret, client.clientSecretHash))) {
      throw new UnauthorizedException('Invalid credentials');
    }
    const accessToken = this.jwtService.sign(
      { clientId: client_id, scope },
      { expiresIn: '1h' },
    );
    return {
      access_token: accessToken,
      token_type: 'Bearer',
      expires_in: 3600,
    };
  }

  // Dummy implementations for illustration
  async findOAuthClient(clientId: string) { /* ... */ }
  async verifySecret(secret: string, hash: string) { /* ... */ }
}
```

## Refresh Token Rotation

**Pattern:** Issue new refresh token with each refresh, invalidate the old one.

```javascript
app.post('/oauth/refresh', async (req, res) => {
  const { refresh_token } = req.body;

  try {
    // Find refresh token in database
    const storedToken = await RefreshToken.findOne({ token: refresh_token });

    if (!storedToken || storedToken.expiresAt < new Date()) {
      return res.status(401).json({ error: 'Invalid or expired refresh token' });
    }

    // Immediately revoke old refresh token
    await storedToken.deleteOne();

    // Generate new token pair
    const user = await User.findById(storedToken.userId);

    const newAccessToken = jwt.sign(
      { id: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '15m' }
    );

    const newRefreshToken = crypto.randomBytes(32).toString('hex');

    // Store new refresh token
    await RefreshToken.create({
      userId: user.id,
      token: newRefreshToken,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 days
    });

    res.json({
      access_token: newAccessToken,
      refresh_token: newRefreshToken,
      expires_in: 900
    });
  } catch (error) {
    res.status(500).json({ error: 'Token refresh failed' });
  }
});
```

---

# Multi-Factor Authentication (MFA)

## What is MFA?

**MFA** requires users to prove their identity through **two or more** different methods:
1. Something you know (password)
2. Something you have (phone, security key)
3. Something you are (biometric)

## TOTP-Based 2FA (Time-Based One-Time Password)

Most common: Google Authenticator, Authy, Microsoft Authenticator

### Implementation: TOTP-Based 2FA (NestJS)

```typescript
// Install: npm install otplib qrcode

import { Controller, Post, Req, Res, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { authenticator } from 'otplib';
import * as QRCode from 'qrcode';

@Controller('auth/2fa')
export class TwoFactorController {
  @Post('setup')
  @UseGuards(AuthGuard('jwt'))
  async setup2FA(@Req() req, @Res() res) {
    const user = req.user;
    // Generate TOTP secret
    const secret = authenticator.generateSecret();
    // Generate TOTP auth URL for QR code
    const totpAuthUrl = authenticator.keyuri(user.email, 'YourApp', secret);
    // Generate QR code
    const qrCodeDataUrl = await QRCode.toDataURL(totpAuthUrl);
    // Store temporary secret in DB or session (not yet verified)
    // ...
    res.json({
      secret,
      qrCodeDataUrl,
    });
  }
}
```
      qrCode: qrCodeDataUrl,
      secret: base32Secret // Also provide for manual entry
    });
  } catch (error) {
    res.status(500).json({ error: 'Setup failed' });
  }
});

// Step 2: User verifies TOTP code
app.post('/auth/2fa/verify', authenticateJWT, async (req, res) => {
  const { totpCode } = req.body;

  try {
    const tempSecret = req.session.tempTotpSecret;

    if (!tempSecret) {
      return res.status(400).json({ error: 'No TOTP setup in progress' });
    }

    // Verify the code
    const OTPAuth = require('otplib').authenticator;
    const isValid = OTPAuth.check(totpCode, tempSecret);

    if (!isValid) {
      return res.status(400).json({ error: 'Invalid TOTP code' });
    }

    // Enable 2FA
    const user = await User.findById(req.user.id);
    user.totpSecret = tempSecret;
    user.twoFactorEnabled = true;
    user.backupCodes = generateBackupCodes(); // Generate backup codes
    await user.save();

    // Clean up session
    delete req.session.tempTotpSecret;

    res.json({
      message: '2FA enabled successfully',
      backupCodes: user.backupCodes // Show once only!
    });
  } catch (error) {
    res.status(500).json({ error: 'Verification failed' });
  }
});

// Step 3: Login with TOTP
app.post('/auth/login-2fa', async (req, res) => {
  const { email, password, totpCode } = req.body;

  try {
    // Step 1: Verify password
    const user = await User.findOne({ email });

    if (!user || !await bcrypt.compare(password, user.password)) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Step 2: Check if 2FA is enabled
    if (user.twoFactorEnabled) {
      if (!totpCode) {
        // Return intermediate token (short-lived, only for TOTP verification)
        const intermediateToken = jwt.sign(
          { id: user.id, stage: 'totp-pending' },
          process.env.JWT_SECRET,
          { expiresIn: '5m' }
        );
        return res.json({
          intermediateToken,
          message: 'TOTP required'
        });
      }

      // Verify TOTP
      const OTPAuth = require('otplib').authenticator;
      const isValid = OTPAuth.check(totpCode, user.totpSecret);

      if (!isValid) {
        return res.status(401).json({ error: 'Invalid TOTP code' });
      }
    }

    // Step 3: Generate full access token
    const accessToken = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );

    res.json({ accessToken });
  } catch (error) {
    res.status(500).json({ error: 'Login failed' });
  }
});

// Backup codes for account recovery
function generateBackupCodes(count = 10) {
  const codes = [];
  for (let i = 0; i < count; i++) {
    const code = require('crypto').randomBytes(3).toString('hex').toUpperCase();
    codes.push(`${code.slice(0, 4)}-${code.slice(4)}`);
  }
  return codes;
}
```

---

# Security Vulnerabilities & Prevention

## 1. Brute Force Attacks

**What:** Attacker tries multiple password combinations

**Prevention: Rate Limiting**

```bash
npm install express-rate-limit
```

```javascript
const rateLimit = require('express-rate-limit');

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,    // 15 minutes
  max: 5,                       // 5 attempts per IP
  message: 'Too many login attempts, try again later',
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => req.user      // Don't rate-limit authenticated users
});

app.post('/login', loginLimiter, async (req, res) => {
  // Login logic
});
```

## 2. Session Hijacking

**What:** Attacker steals session cookie and impersonates user

**Prevention: Secure Cookies**

```javascript
app.use(session({
  cookie: {
    httpOnly: true,              // Prevents JavaScript access
    secure: true,                // HTTPS only
    sameSite: 'strict',          // CSRF protection
    domain: 'example.com',       // Specific domain
    path: '/',                   // Cookie scope
    maxAge: 24 * 60 * 60 * 1000  // 24 hours
  }
}));
```

**Prevention: Session Regeneration**

```javascript
app.post('/login', async (req, res) => {
  const user = await authenticateUser(req.body.email, req.body.password);

  if (user) {
    // Regenerate session to prevent fixation attacks
    req.session.regenerate((err) => {
      if (err) return res.status(500).json({ error: 'Login failed' });

      req.session.userId = user.id;
      req.session.loginTime = Date.now();

      res.json({ message: 'Logged in successfully' });
    });
  } else {
    res.status(401).json({ error: 'Invalid credentials' });
  }
});
```

## 3. CSRF (Cross-Site Request Forgery)

**What:** Attacker tricks authenticated user into performing unwanted action

### CSRF with Session Cookies

```bash
npm install csurf
```

```javascript
const csrf = require('csurf');
const cookieParser = require('cookie-parser');

app.use(cookieParser());
app.use(session({ /* config */ }));

// CSRF protection middleware
const csrfProtection = csrf({ cookie: false }); // Use session, not cookies

// Generate CSRF token for forms
app.get('/form', csrfProtection, (req, res) => {
  res.json({
    csrfToken: req.csrfToken()
  });
});

// Verify CSRF token on state-changing requests
app.post('/action', csrfProtection, (req, res) => {
  // Token automatically verified by middleware
  res.json({ message: 'Action successful' });
});
```

### CSRF with JWT

JWTs are naturally immune to CSRF because:
1. They must be explicitly included (not auto-sent like cookies)
2. They can't be sent in cross-origin requests without CORS

```javascript
// Frontend includes JWT in header (not in cookie)
fetch('https://api.example.com/action', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,  // Must be explicit
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ /* data */ })
});

// Backend verifies JWT
app.post('/action', authenticateJWT, (req, res) => {
  // JWT already verified by middleware
  res.json({ message: 'Action successful' });
});
```

## 4. SQL Injection

**What:** Attacker injects SQL code into input fields

**Prevention: Parameterized Queries**

```javascript
// ❌ VULNERABLE
const email = req.body.email;
const user = await db.query(`SELECT * FROM users WHERE email = '${email}'`);

// ✅ SECURE
const email = req.body.email;
const user = await db.query('SELECT * FROM users WHERE email = ?', [email]);

// With Mongoose
const user = await User.findOne({ email: email }); // Automatically parameterized
```

## 5. XSS (Cross-Site Scripting)

**What:** Attacker injects malicious JavaScript

**Prevention: Input Sanitization**

```bash
npm install xss helmet
```

```javascript
const helmet = require('helmet');
const xss = require('xss');

app.use(helmet()); // Sets security headers

// Sanitize user input
const sanitizeInput = (input) => {
  return xss(input, {
    whiteList: {},        // No HTML allowed
    stripIgnoredTag: true
  });
};

app.post('/comment', (req, res) => {
  const comment = sanitizeInput(req.body.comment);
  // Save sanitized comment
});
```

## 6. Weak Password Policies

**Prevention: Strong Password Validation**

```javascript
function validatePassword(password) {
  const minLength = 12;
  const hasUppercase = /[A-Z]/.test(password);
  const hasLowercase = /[a-z]/.test(password);
  const hasNumbers = /\d/.test(password);
  const hasSpecialChar = /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password);

  if (password.length < minLength) {
    return { valid: false, error: 'Password too short' };
  }

  if (!hasUppercase || !hasLowercase) {
    return { valid: false, error: 'Password must contain uppercase and lowercase letters' };
  }

  if (!hasNumbers) {
    return { valid: false, error: 'Password must contain numbers' };
  }

  if (!hasSpecialChar) {
    return { valid: false, error: 'Password must contain special characters' };
  }

  return { valid: true };
}
```

## 7. JWT Vulnerabilities

### Algorithm Confusion Attack

```javascript
// ❌ VULNERABLE - accepts 'none' algorithm
const decoded = jwt.verify(token, secret); // Doesn't validate algorithm

// ✅ SECURE - explicitly specify algorithm
const decoded = jwt.verify(token, secret, {
  algorithms: ['HS256'],      // Only accept this algorithm
  issuer: 'your-app',         // Validate issuer
  audience: 'your-users'      // Validate audience
});
```

### Key Injection Attack

```javascript
// ❌ VULNERABLE - uses public key for signing
const token = jwt.sign(payload, publicKey); // Public key not secret!

// ✅ SECURE - use private key for signing, public for verification
const token = jwt.sign(payload, privateKey, { algorithm: 'RS256' });
const decoded = jwt.verify(token, publicKey, { algorithms: ['RS256'] });
```

## 8. Insecure Token Storage

❌ **DON'T:**
- Store tokens in localStorage (vulnerable to XSS)
- Store tokens in sessionStorage
- Hardcode tokens

✅ **DO:**
- Store refresh tokens in HTTP-only cookies
- Store access tokens in memory
- Use environment variables for secrets

```javascript
// Secure token storage pattern
app.post('/login', async (req, res) => {
  const user = await authenticateUser(req.body.email, req.body.password);

  const { accessToken, refreshToken } = generateTokenPair(user);

  // Send refresh token in HTTP-only cookie
  res.cookie('refreshToken', refreshToken, {
    httpOnly: true,
    secure: true,
    sameSite: 'strict',
    maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
  });

  // Send access token in response body (for in-memory storage)
  res.json({
    accessToken,
    expiresIn: 900  // 15 minutes
  });
});
```

---

# Rate Limiting & Brute Force Protection

## Comprehensive Rate Limiting Setup

```javascript
const rateLimit = require('express-rate-limit');
const RedisStore = require('rate-limit-redis');
const redis = require('redis');

const redisClient = redis.createClient({
  host: process.env.REDIS_HOST,
  port: process.env.REDIS_PORT
});

// General API rate limiter
const apiLimiter = rateLimit({
  store: new RedisStore({
    client: redisClient,
    prefix: 'rl:api'
  }),
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,                  // 100 requests per IP
  message: 'Too many requests, please try again later'
});

// Login attempt limiter (stricter)
const loginLimiter = rateLimit({
  store: new RedisStore({
    client: redisClient,
    prefix: 'rl:login'
  }),
  windowMs: 15 * 60 * 1000,
  max: 5,                    // 5 attempts
  skipSuccessfulRequests: true, // Don't count successful logins
  message: 'Too many login attempts'
});

// Password reset limiter
const resetLimiter = rateLimit({
  store: new RedisStore({
    client: redisClient,
    prefix: 'rl:reset'
  }),
  windowMs: 60 * 60 * 1000,  // 1 hour
  max: 3,                    // 3 attempts
  message: 'Too many password reset attempts'
});

// Apply limiters
app.use('/api/', apiLimiter);
app.post('/login', loginLimiter, handleLogin);
app.post('/forgot-password', resetLimiter, handlePasswordReset);
```

## Progressive Delay on Failed Attempts

```javascript
const failedLoginAttempts = new Map();

async function handleLoginWithProgressiveDelay(req, res) {
  const ip = req.ip;
  const attempts = failedLoginAttempts.get(ip) || { count: 0, lastAttempt: 0 };

  try {
    const user = await authenticateUser(req.body.email, req.body.password);

    if (!user) {
      // Increment failed attempts
      attempts.count += 1;
      attempts.lastAttempt = Date.now();
      failedLoginAttempts.set(ip, attempts);

      // Exponential backoff: 1s, 2s, 4s, 8s...
      const delayMs = Math.min(Math.pow(2, attempts.count - 1) * 1000, 60000);

      return res.status(401).json({
        error: 'Invalid credentials',
        retryAfterSeconds: Math.ceil(delayMs / 1000)
      });
    }

    // Reset attempts on successful login
    failedLoginAttempts.delete(ip);

    const token = generateToken(user);
    res.json({ token });
  } catch (error) {
    res.status(500).json({ error: 'Login failed' });
  }
}
```

---

# CSRF Protection

## Token-Based CSRF Protection

```javascript
const csrf = require('csurf');
const session = require('express-session');

app.use(session({ /* config */ }));

// CSRF middleware
const csrfProtection = csrf({
  cookie: false,  // Use session instead of cookie
  saltLength: 32  // Strong salt
});

// Generate token for GET requests
app.get('/form', csrfProtection, (req, res) => {
  res.json({
    csrfToken: req.csrfToken()
  });
});

// Verify token for POST/PUT/DELETE requests
app.post('/action', csrfProtection, (req, res) => {
  // Token automatically verified
  res.json({ message: 'Action successful' });
});

// Error handler
app.use((err, req, res, next) => {
  if (err.code === 'EBADCSRFTOKEN') {
    res.status(403).json({ error: 'CSRF token invalid' });
  } else {
    next(err);
  }
});
```

## SameSite Cookie Attribute

```javascript
app.use(session({
  cookie: {
    sameSite: 'strict' // 'strict' | 'lax' | 'none'
  }
}));

// sameSite levels:
// 'strict': Cookie only sent in same-site requests
// 'lax': Cookie sent for top-level navigation from external sites
// 'none': Cookie sent in all requests (requires secure flag)
```

---

# Complete Implementation Examples

## Example 1: Complete Authentication System

```javascript
// auth.service.js
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

class AuthService {
  // Register user
  async register(email, password, name) {
    // Validate input
    if (!email || !password || password.length < 12) {
      throw new Error('Invalid credentials');
    }

    // Check if user exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      throw new Error('User already exists');
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create user
    const user = await User.create({
      email,
      name,
      password: hashedPassword
    });

    return this.generateTokenPair(user);
  }

  // Login user
  async login(email, password) {
    const user = await User.findOne({ email });

    if (!user || !await bcrypt.compare(password, user.password)) {
      throw new Error('Invalid credentials');
    }

    if (user.twoFactorEnabled) {
      // Return intermediate token for 2FA verification
      const intermediateToken = jwt.sign(
        { id: user.id, stage: 'totp-pending' },
        process.env.JWT_SECRET,
        { expiresIn: '5m' }
      );
      return { intermediateToken, requiresTOTP: true };
    }

    return this.generateTokenPair(user);
  }

  // Verify TOTP
  async verifyTOTP(userId, totpCode) {
    const user = await User.findById(userId);

    if (!user.twoFactorEnabled) {
      throw new Error('2FA not enabled');
    }

    const OTPAuth = require('otplib').authenticator;
    if (!OTPAuth.check(totpCode, user.totpSecret)) {
      throw new Error('Invalid TOTP code');
    }

    return this.generateTokenPair(user);
  }

  // Generate token pair
  generateTokenPair(user) {
    const accessToken = jwt.sign(
      {
        id: user.id,
        email: user.email,
        role: user.role
      },
      process.env.JWT_SECRET,
      { expiresIn: '15m', algorithm: 'HS256' }
    );

    const refreshToken = jwt.sign(
      { id: user.id, type: 'refresh' },
      process.env.JWT_REFRESH_SECRET,
      { expiresIn: '7d', algorithm: 'HS256' }
    );

    return { accessToken, refreshToken };
  }

  // Refresh access token
  async refreshAccessToken(refreshToken) {
    try {
      const decoded = jwt.verify(
        refreshToken,
        process.env.JWT_REFRESH_SECRET,
        { algorithms: ['HS256'] }
      );

      const user = await User.findById(decoded.id);
      return this.generateTokenPair(user);
    } catch (error) {
      throw new Error('Invalid refresh token');
    }
  }

  // Logout
  async logout(userId, refreshToken) {
    // Add refresh token to blacklist
    await TokenBlacklist.create({
      token: refreshToken,
      userId,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    });
  }

  // Change password
  async changePassword(userId, oldPassword, newPassword) {
    const user = await User.findById(userId);

    if (!await bcrypt.compare(oldPassword, user.password)) {
      throw new Error('Current password is incorrect');
    }

    user.password = await bcrypt.hash(newPassword, 10);
    await user.save();
  }

  // Reset password
  async requestPasswordReset(email) {
    const user = await User.findOne({ email });
    if (!user) return; // Don't reveal if email exists

    const resetToken = crypto.randomBytes(32).toString('hex');
    const resetTokenHash = await bcrypt.hash(resetToken, 10);

    user.resetToken = resetTokenHash;
    user.resetTokenExpiry = new Date(Date.now() + 1 * 60 * 60 * 1000); // 1 hour
    await user.save();

    // Send email with reset link
    await sendPasswordResetEmail(email, resetToken);
  }

  async resetPassword(resetToken, newPassword) {
    const resetTokenHash = await bcrypt.hash(resetToken, 10);

    const user = await User.findOne({
      resetTokenExpiry: { $gt: new Date() }
    });

    if (!user || !await bcrypt.compare(resetToken, user.resetToken)) {
      throw new Error('Invalid or expired reset token');
    }

    user.password = await bcrypt.hash(newPassword, 10);
    user.resetToken = null;
    user.resetTokenExpiry = null;
    await user.save();
  }
}

module.exports = new AuthService();
```

```javascript
// auth.routes.js
const express = require('express');
const authService = require('./auth.service');
const authMiddleware = require('./auth.middleware');
const rateLimit = require('express-rate-limit');

const router = express.Router();

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  skipSuccessfulRequests: true
});

// Register
router.post('/register', async (req, res) => {
  try {
    const { email, password, name } = req.body;
    const tokens = await authService.register(email, password, name);

    res.cookie('refreshToken', tokens.refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60 * 1000
    });

    res.json({ accessToken: tokens.accessToken });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Login
router.post('/login', loginLimiter, async (req, res) => {
  try {
    const { email, password } = req.body;
    const result = await authService.login(email, password);

    if (result.requiresTOTP) {
      return res.json({ intermediateToken: result.intermediateToken });
    }

    res.cookie('refreshToken', result.refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60 * 1000
    });

    res.json({ accessToken: result.accessToken });
  } catch (error) {
    res.status(401).json({ error: error.message });
  }
});

// Verify TOTP
router.post('/verify-totp', async (req, res) => {
  try {
    const { userId, totpCode } = req.body;
    const tokens = await authService.verifyTOTP(userId, totpCode);

    res.cookie('refreshToken', tokens.refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60 * 1000
    });

    res.json({ accessToken: tokens.accessToken });
  } catch (error) {
    res.status(401).json({ error: error.message });
  }
});

// Refresh access token
router.post('/refresh', (req, res) => {
  try {
    const refreshToken = req.cookies.refreshToken;
    if (!refreshToken) {
      return res.status(401).json({ error: 'No refresh token' });
    }

    const tokens = authService.refreshAccessToken(refreshToken);

    res.cookie('refreshToken', tokens.refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60 * 1000
    });

    res.json({ accessToken: tokens.accessToken });
  } catch (error) {
    res.status(401).json({ error: 'Token refresh failed' });
  }
});

// Logout
router.post('/logout', authMiddleware, async (req, res) => {
  try {
    const refreshToken = req.cookies.refreshToken;
    await authService.logout(req.user.id, refreshToken);

    res.clearCookie('refreshToken');
    res.json({ message: 'Logged out successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Logout failed' });
  }
});

// Change password
router.post('/change-password', authMiddleware, async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;
    await authService.changePassword(req.user.id, oldPassword, newPassword);

    res.json({ message: 'Password changed successfully' });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Forgot password
router.post('/forgot-password', async (req, res) => {
  try {
    await authService.requestPasswordReset(req.body.email);
    res.json({ message: 'Check your email for reset link' });
  } catch (error) {
    res.status(500).json({ error: 'Password reset failed' });
  }
});

// Reset password
router.post('/reset-password', async (req, res) => {
  try {
    const { resetToken, newPassword } = req.body;
    await authService.resetPassword(resetToken, newPassword);

    res.json({ message: 'Password reset successfully' });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

module.exports = router;
```

```javascript
// auth.middleware.js
const jwt = require('jsonwebtoken');

function authenticateJWT(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No token provided' });
  }

  const token = authHeader.slice(7);

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET, {
      algorithms: ['HS256']
    });

    req.user = decoded;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired' });
    }
    res.status(403).json({ error: 'Invalid token' });
  }
}

function authorize(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
}

module.exports = { authenticateJWT, authorize };
```

## Example 2: OAuth 2.0 with Google

```javascript
// oauth.routes.js
const express = require('express');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const fetch = require('node-fetch');

const router = express.Router();

function base64URLEncode(str) {
  return Buffer.from(str)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

// Step 1: Initiate OAuth flow with PKCE
router.get('/google', (req, res) => {
  const codeVerifier = base64URLEncode(crypto.randomBytes(32));
  const codeChallenge = base64URLEncode(
    require('crypto')
      .createHash('sha256')
      .update(codeVerifier)
      .digest()
  );

  // Store code verifier in session
  req.session.codeVerifier = codeVerifier;
  req.session.state = crypto.randomBytes(16).toString('hex');

  const authUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth');
  authUrl.searchParams.append('client_id', process.env.GOOGLE_CLIENT_ID);
  authUrl.searchParams.append('redirect_uri', `${process.env.API_URL}/auth/google/callback`);
  authUrl.searchParams.append('response_type', 'code');
  authUrl.searchParams.append('scope', 'openid profile email');
  authUrl.searchParams.append('code_challenge', codeChallenge);
  authUrl.searchParams.append('code_challenge_method', 'S256');
  authUrl.searchParams.append('state', req.session.state);

  res.redirect(authUrl.toString());
});

// Step 2: Handle OAuth callback
router.get('/google/callback', async (req, res) => {
  const { code, state } = req.query;

  // Verify state
  if (state !== req.session.state) {
    return res.status(400).json({ error: 'State mismatch' });
  }

  const codeVerifier = req.session.codeVerifier;
  if (!codeVerifier) {
    return res.status(400).json({ error: 'No code verifier' });
  }

  try {
    // Exchange code for token
    const tokenResponse = await fetch('https://www.googleapis.com/oauth2/v4/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        client_id: process.env.GOOGLE_CLIENT_ID,
        client_secret: process.env.GOOGLE_CLIENT_SECRET,
        redirect_uri: `${process.env.API_URL}/auth/google/callback`,
        code_verifier: codeVerifier
      })
    });

    const tokens = await tokenResponse.json();

    if (!tokens.id_token) {
      throw new Error('No id_token in response');
    }

    // Verify ID token and extract user info
    const decoded = jwt.decode(tokens.id_token);

    // Find or create user
    let user = await User.findOne({ googleId: decoded.sub });

    if (!user) {
      user = await User.create({
        googleId: decoded.sub,
        email: decoded.email,
        name: decoded.name,
        avatar: decoded.picture
      });
    }

    // Generate app's own JWT
    const appToken = jwt.sign(
      { id: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );

    // Clean up session
    delete req.session.codeVerifier;
    delete req.session.state;

    // Redirect to frontend with token
    res.redirect(`${process.env.FRONTEND_URL}/auth-success?token=${appToken}`);
  } catch (error) {
    console.error('OAuth callback error:', error);
    res.redirect(`${process.env.FRONTEND_URL}/auth-error?error=oauth_failed`);
  }
});

module.exports = router;
```

---

## Key Takeaways for Backend Developers

### Password Management
1. Always hash passwords with bcrypt (10+ rounds) or Argon2
2. Use unique salts for each password
3. Never store or log plaintext passwords

### Session vs JWT
- **Sessions:** Better for traditional web apps, state management on server
- **JWT:** Better for APIs, stateless, works across servers

### OAuth 2.0
- Use **Authorization Code Flow** for web apps
- Use **PKCE** for mobile/SPA apps
- Always validate state parameter (CSRF protection)
- Refresh tokens should be rotated on each use

### Security Essentials
1. Use HTTPS everywhere
2. Implement rate limiting
3. Validate all input
4. Use strong, random secrets
5. Set secure cookie attributes
6. Log security events
7. Monitor for suspicious activity

### MFA Implementation
1. TOTP is most user-friendly
2. Provide backup codes
3. Store 2FA secret securely
4. Verify code before enabling

### Common Vulnerabilities
- Brute force attacks → Rate limiting
- Session hijacking → Secure cookies + HTTPS
- CSRF → Token-based or SameSite cookies
- SQL injection → Parameterized queries
- XSS → Input sanitization
- JWT issues → Algorithm validation, strong secrets