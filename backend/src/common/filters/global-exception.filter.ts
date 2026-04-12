import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { Prisma } from '@prisma/client';

type ValidationErrorItem = {
  path: string;
  message: string;
};

@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const path = request.originalUrl ?? request.url;

    const normalized = this.normalizeException(exception);

    response.status(normalized.statusCode).json({
      status: normalized.statusCode >= 500 ? 'error' : 'fail',
      message: normalized.message,
      ...(normalized.validationErrors
        ? { validationErrors: normalized.validationErrors }
        : {}),
      path,
    });
  }

  private normalizeException(exception: unknown): {
    statusCode: number;
    message: string;
    validationErrors?: ValidationErrorItem[];
  } {
    if (exception instanceof HttpException) {
      const statusCode = exception.getStatus();
      const response = exception.getResponse();
      const message = this.extractHttpMessage(response, exception.message);
      const validationErrors = this.extractValidationErrors(response);

      return {
        statusCode,
        message,
        ...(validationErrors ? { validationErrors } : {}),
      };
    }

    if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      if (exception.code === 'P2002') {
        const field = this.normalizePrismaTarget(exception.meta?.target);
        const fieldLabel = field ?? 'field';
        return {
          statusCode: HttpStatus.CONFLICT,
          message: `Duplicate value for field: ${fieldLabel}. Please use another value.`,
        };
      }

      if (exception.code === 'P2025') {
        return {
          statusCode: HttpStatus.NOT_FOUND,
          message: 'Record not found.',
        };
      }
    }

    if (exception instanceof Prisma.PrismaClientValidationError) {
      return {
        statusCode: HttpStatus.BAD_REQUEST,
        message: 'Invalid input data.',
      };
    }

    if (this.isTokenExpiredError(exception)) {
      return {
        statusCode: HttpStatus.UNAUTHORIZED,
        message: 'Token has expired.',
      };
    }

    if (this.isJwtError(exception)) {
      return {
        statusCode: HttpStatus.UNAUTHORIZED,
        message: 'Invalid token.',
      };
    }

    if (this.isPayloadTooLarge(exception)) {
      return {
        statusCode: HttpStatus.PAYLOAD_TOO_LARGE,
        message: 'Payload too large.',
      };
    }

    // Catch-all: log and return generic 500
    console.error('Unhandled exception', exception);

    return {
      statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
      message: 'Internal server error.',
    };
  }

  private extractHttpMessage(
    response: string | object,
    fallback: string,
  ): string {
    if (typeof response === 'string') {
      return response;
    }

    if (response && typeof response === 'object') {
      const maybeMessage = (response as { message?: string | string[] })
        .message;
      if (Array.isArray(maybeMessage)) {
        return 'Validation failed.';
      }
      if (typeof maybeMessage === 'string') {
        return maybeMessage;
      }
    }

    return fallback;
  }

  private extractValidationErrors(
    response: string | object,
  ): ValidationErrorItem[] | undefined {
    if (!response || typeof response !== 'object') {
      return undefined;
    }

    const message = (response as { message?: string | string[] }).message;
    if (!Array.isArray(message)) {
      return undefined;
    }

    return message.map((item) => {
      const firstToken = item.split(' ')[0] ?? 'field';
      return {
        path: firstToken,
        message: item,
      };
    });
  }

  private isPayloadTooLarge(exception: unknown): boolean {
    if (!exception || typeof exception !== 'object') {
      return false;
    }

    const maybeStatus = (exception as { status?: number }).status;
    const maybeType = (exception as { type?: string }).type;

    return (
      maybeStatus === HttpStatus.PAYLOAD_TOO_LARGE ||
      maybeType === 'entity.too.large'
    );
  }

  private normalizePrismaTarget(target: unknown): string | undefined {
    if (typeof target === 'string') {
      return target;
    }

    if (Array.isArray(target) && typeof target[0] === 'string') {
      return target[0];
    }

    return undefined;
  }

  private isJwtError(exception: unknown): boolean {
    if (!exception || typeof exception !== 'object') {
      return false;
    }

    return (exception as { name?: string }).name === 'JsonWebTokenError';
  }

  private isTokenExpiredError(exception: unknown): boolean {
    if (!exception || typeof exception !== 'object') {
      return false;
    }

    return (exception as { name?: string }).name === 'TokenExpiredError';
  }
}
