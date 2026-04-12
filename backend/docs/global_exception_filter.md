# Global Exception Filter

This project uses a global NestJS exception filter to standardize all API error responses.

## Location

backend/src/common/filters/global-exception.filter.ts

## Response Shape

Every error is returned in the same JSON format:

{
  "status": "error" | "fail",
  "message": "Error message here",
  "validationErrors": [{ "path": "field", "message": "error msg" }],
  "path": "/api/requested-url"
}

Rules:
- status is "fail" for 4xx and "error" for 5xx
- validationErrors only appears for validation errors

## Error Mapping

- Nest HttpException
  - Uses the exception status code and message
  - If ValidationPipe returns an array message, it is mapped to validationErrors

- PrismaClientKnownRequestError
  - P2002: 409 Conflict, duplicate field message
  - P2025: 404 Not Found

- PrismaClientValidationError
  - 400 Bad Request

- JsonWebTokenError
  - 401 Unauthorized, "Invalid token."

- TokenExpiredError
  - 401 Unauthorized, "Token has expired."

- Payload Too Large
  - 413 Payload Too Large
  - Detected via status 413 or type "entity.too.large"

- Unknown errors
  - 500 Internal Server Error
  - Logged on the server, no stack trace sent to the client

## How to Use

The filter is registered globally in backend/src/main.ts:

app.useGlobalFilters(new GlobalExceptionFilter());

You do not need to wrap responses manually. Throw standard NestJS exceptions or let Prisma/JWT errors bubble up, and the filter will normalize the response.

## Example

If a request fails validation:

{
  "status": "fail",
  "message": "Validation failed.",
  "validationErrors": [
    { "path": "email", "message": "email must be an email" }
  ],
  "path": "/api/auth/register"
}

Return errors by throwing exceptions as usual (Nest will catch them), and the filter will shape the response automatically.

**What you should do in your code:**

1. For expected client errors, throw Nest HttpExceptions:

   ```ts
   throw new BadRequestException('Invalid input');
   throw new NotFoundException('Playlist not found');
   throw new UnauthorizedException('Missing token');
   ```

2. For validation errors, rely on ValidationPipe (it throws a 400 with an array message).
3. For Prisma errors, just let them bubble up—this filter maps them.
4. For unexpected errors, throw or let them bubble; they become 500.

**What the client will always receive:**

```json
{
  "status": "fail" | "error",
  "message": "Error message here",
  "validationErrors": [{ "path": "field", "message": "error msg" }], // only for validation
  "path": "/api/requested-url"
}
```

So your job is simply to throw proper exceptions (or let Prisma/JWT throw), and the global filter guarantees the consistent shape.
