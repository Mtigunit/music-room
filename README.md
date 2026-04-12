# Music Room

Music Room is a monorepo containing:

- A backend API built with NestJS, Prisma, PostgreSQL, and Redis.
- A mobile app built with Flutter.

## Monorepo Structure

```text
music-room/
	backend/   # NestJS API + Prisma + tests
	mobile/    # Flutter application
	scripts/   # Git workflow scripts used by hooks/CI
```

## Prerequisites

- Node.js 22+
- npm 10+
- Flutter SDK (stable)
- Docker + Docker Compose


## Features

- **Swagger API Docs**: Auto-generated OpenAPI docs available at [http://localhost:3000/api/docs](http://localhost:3000/api/docs) when the backend is running. All endpoints, DTOs, and error responses are documented.
- **Global Validation**: All incoming requests are validated using class-validator decorators on DTOs. Invalid requests receive a 400 response with details.
- **Global Exception Handling**: Consistent error responses and logging for all unhandled exceptions, including database and validation errors.
- **Prisma ORM**: Type-safe database access and migrations. See backend/docs/prisma_explained.md for a full workflow.

## Quick Start

1. Clone the repository.
2. Install dependencies:

```bash
make install
```

3. Start infrastructure services (Postgres, Redis, pgAdmin):

```bash
make docker-up
```

4. Start backend in development mode:

```bash
make backend
```

5. Run mobile app:

```bash
make mobile
```


## Backend Workflow

- Edit your database schema in `backend/prisma/schema.prisma`.
- Run `npx prisma generate` to update the Prisma client after schema changes.
- Run `npx prisma migrate dev --name <desc>` to create and apply DB migrations.
- Start the backend and access Swagger docs at `/api/docs`.

Run from repository root.

### Backend

```bash
make backend
make backend-lint
make backend-format
make backend-test
```

### Mobile

```bash
make mobile
make mobile-lint
make mobile-format
make mobile-test
```

### Global

```bash
make lint
make format
make test
make ci
```

### Docker Compose (Root)

```bash
make docker-build
make docker-up
make docker-down
make docker-logs
make docker-backend-logs
```


Note: in the current compose file, the API service is commented out, while `postgres`, `redis`, and `pgadmin` are active.

## CI

Backend CI runs via GitHub Actions from `.github/workflows/backend-ci.yml` and currently executes:

- npm install with lockfile (`npm ci`)
- Prisma Client generation (`npx prisma generate`)
- Lint
- Unit tests
- Build

## Git Hooks

Lefthook is configured in `lefthook.yml`.

- `pre-commit`: runs mobile analysis and backend lint/format for affected files.
- `pre-push`: runs branch checks and project checks.
- `commit-msg`: runs commitlint.

## Environment

Backend environment variables are expected in `backend/.env`.
Use `backend/.env.example` as the starting template.

---

## See Also

- [backend/docs/prisma_explained.md](backend/docs/prisma_explained.md) — Prisma, DB, and repository pattern explained
