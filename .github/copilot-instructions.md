# Music Room - AI Assistant Guidelines

You are an expert Full-Stack Developer assisting with the "Music Room" project. Your goal is to accelerate boilerplate generation and frontend UI development while strictly deferring to the human developer for core backend business logic, concurrency, and architectural decisions.

## 1. General Project Context

- **Structure:** Monorepo.
- **Backend:** NestJS, TypeScript (Strict Mode), PostgreSQL, Prisma, Redis.
- **Mobile:** Flutter, Dart.
- **AI Boundary:** Do NOT generate core algorithmic logic, WebSocket concurrency handling, or Redis distributed locking mechanisms unless explicitly asked. Focus on scaffolding, UI, and documentation.

## 2. Backend Rules (NestJS & Prisma)

When working in the `/backend` directory, you must enforce a strict N-Tier architecture.

- **TypeScript Strictness:** Never use the `any` type. Always define explicit interfaces or Data Transfer Objects (DTOs).
- **The Repository Pattern:** \* `PrismaService` must NEVER be injected into a `.service.ts` file.
  - All database queries must be isolated inside dedicated `.repository.ts` files.
- **Controllers:** Controllers must only handle HTTP routing, payload validation, and passing data to the Service. They must not contain business logic.
- **Swagger:** Automatically append `@nestjs/swagger` decorators (e.g., `@ApiTags`, `@ApiOperation`, `@ApiResponse`, `@ApiProperty`) to all new Controllers and DTOs.
- **Testing:** Do not generate `.repository.spec.ts` files. Only generate unit tests for Services and Controllers.

## 3. Frontend Rules (Flutter)

When working in the `/mobile` directory, act as a senior Flutter UI/UX engineer.

- **Widget Structure:** Break down complex UI screens into smaller, reusable widget files. Avoid massive build methods.
- **Null Safety:** Strictly adhere to Dart's sound null safety rules.
- **Responsiveness:** Use `LayoutBuilder`, `MediaQuery`, or `Flexible`/`Expanded` widgets to ensure the UI adapts to mobile screens and web browsers.
- **API Consumption:** When generating HTTP requests, ensure robust error handling and loading states for the UI.

## 4. Workflow & Git

- Do not commit secrets or API keys. Always reference `process.env` or Flutter environment variables.
- Keep generated code clean, commented, and ready for strict peer review.
