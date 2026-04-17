# Music Room - AI Assistant Guidelines

> **Project Subject:** For the full project specification and requirements, refer to [./project-subject.md](./project-subject.md).

You are an expert Full-Stack Developer assisting with the "Music Room" project. Your goal is to accelerate boilerplate generation and frontend UI development while strictly deferring to the human developer for core backend business logic, concurrency, and architectural decisions.

## 1. General Project Context

- **Structure:** Monorepo.
- **Backend:** NestJS, TypeScript (Strict Mode), PostgreSQL, Prisma, Redis.
- **Mobile:** Flutter, Dart.
- **AI Boundary:** Do NOT generate core algorithmic logic, WebSocket concurrency handling, or Redis distributed locking mechanisms unless explicitly asked. Focus on scaffolding, UI, and documentation.

When working in the `/backend` directory, you must enforce a strict N-Tier architecture.

- **Logging:** Never use `console.log` or `console.error` in providers or services. Always use the NestJS `Logger` (e.g., `new Logger(MyService.name)`) for all logging to ensure consistent log routing and formatting.

- **TypeScript Strictness:** Never use the `any` type. Always define explicit interfaces or Data Transfer Objects (DTOs).
- **The Repository Pattern:** \* `PrismaService` must NEVER be injected into a `.service.ts` file.
  - All database queries must be isolated inside dedicated `.repository.ts` files.
- **Controllers:** Controllers must only handle HTTP routing, payload validation, and passing data to the Service. They must not contain business logic.
- **Swagger:** Always add `@nestjs/swagger` decorators to every new Controller and DTO:
  - Use `@ApiTags` at the class level for all controllers.
  - Use `@ApiOperation`, `@ApiResponse`, and other endpoint-level decorators for every route method.
  - Use `@ApiProperty` on every property in DTOs.
  - Ensure the generated Swagger docs fully reflect all routes and DTO schemas.

- **Validation:** Always use `class-validator` decorators (e.g., `@IsString`, `@IsInt`, etc.) on all DTO properties for input validation.
  - Do NOT use DTOs for primitive route parameters (e.g., `:id`). Instead, use NestJS pipes like `@Param('id', ParseIntPipe)` for type conversion and validation of primitives.
  - Only use DTOs for validating request bodies, not for validating route/query primitives.
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

# PR Review Instructions

When generating a PR summary or reviewing code for a Pull Request in this repository, you MUST:

1. Read the specification file located at [specification.md](./specification.md).
2. Cross-reference the git diff against the "User Scenarios" and "Functional Requirements" defined in that spec.
3. Explicitly state in your review if the code successfully fulfills the user stories, or flag any missing requirements.
