import { ArgumentsHost, BadRequestException, HttpStatus } from '@nestjs/common';
import type { Request, Response } from 'express';
import { Prisma } from '@prisma/client';
import { GlobalExceptionFilter } from './global-exception.filter';

type CapturedResponse = {
  statusCode?: number;
  body?: unknown;
};

const createHost = (
  captured: CapturedResponse,
  path = '/api/test',
): ArgumentsHost => {
  const response = {
    status: (code: number) => {
      captured.statusCode = code;
      return response;
    },
    json: (body: unknown) => {
      captured.body = body;
      return response;
    },
  } as unknown as Response;

  const request = {
    originalUrl: path,
  } as unknown as Request;

  const http = {
    getResponse: () => response,
    getRequest: () => request,
  };

  return {
    switchToHttp: () => http,
  } as unknown as ArgumentsHost;
};

describe('GlobalExceptionFilter', () => {
  const filter = new GlobalExceptionFilter();

  it('formats validation errors from HttpException', () => {
    const captured: CapturedResponse = {};
    const host = createHost(captured, '/api/validate');

    const exception = new BadRequestException([
      'email must be an email',
      'password should not be empty',
    ]);

    filter.catch(exception, host);

    expect(captured.statusCode).toBe(HttpStatus.BAD_REQUEST);
    expect(captured.body).toEqual({
      status: 'fail',
      message: 'Validation failed.',
      validationErrors: [
        { path: 'email', message: 'email must be an email' },
        { path: 'password', message: 'password should not be empty' },
      ],
      path: '/api/validate',
    });
  });

  it('maps Prisma unique constraint to 409', () => {
    const captured: CapturedResponse = {};
    const host = createHost(captured);

    const exception = new Prisma.PrismaClientKnownRequestError(
      'Unique failed',
      {
        code: 'P2002',
        clientVersion: '0.0.0',
        meta: { target: ['email'] },
      },
    );

    filter.catch(exception, host);

    expect(captured.statusCode).toBe(HttpStatus.CONFLICT);
    expect(captured.body).toEqual({
      status: 'fail',
      message: 'Duplicate value for field: email. Please use another value.',
      path: '/api/test',
    });
  });

  it('maps Prisma record not found to 404', () => {
    const captured: CapturedResponse = {};
    const host = createHost(captured, '/api/items/1');

    const exception = new Prisma.PrismaClientKnownRequestError('Not found', {
      code: 'P2025',
      clientVersion: '0.0.0',
    });

    filter.catch(exception, host);

    expect(captured.statusCode).toBe(HttpStatus.NOT_FOUND);
    expect(captured.body).toEqual({
      status: 'fail',
      message: 'Record not found.',
      path: '/api/items/1',
    });
  });

  it('maps Prisma validation error to 400', () => {
    const captured: CapturedResponse = {};
    const host = createHost(captured);

    const exception = new Prisma.PrismaClientValidationError('Invalid', {
      clientVersion: '0.0.0',
    });

    filter.catch(exception, host);

    expect(captured.statusCode).toBe(HttpStatus.BAD_REQUEST);
    expect(captured.body).toEqual({
      status: 'fail',
      message: 'Invalid input data.',
      path: '/api/test',
    });
  });

  it('maps JWT errors to 401', () => {
    const captured: CapturedResponse = {};
    const host = createHost(captured, '/api/secure');

    filter.catch({ name: 'JsonWebTokenError' }, host);

    expect(captured.statusCode).toBe(HttpStatus.UNAUTHORIZED);
    expect(captured.body).toEqual({
      status: 'fail',
      message: 'Invalid token.',
      path: '/api/secure',
    });
  });

  it('maps token expired to 401', () => {
    const captured: CapturedResponse = {};
    const host = createHost(captured, '/api/secure');

    filter.catch({ name: 'TokenExpiredError' }, host);

    expect(captured.statusCode).toBe(HttpStatus.UNAUTHORIZED);
    expect(captured.body).toEqual({
      status: 'fail',
      message: 'Token has expired.',
      path: '/api/secure',
    });
  });

  it('maps payload too large to 413', () => {
    const captured: CapturedResponse = {};
    const host = createHost(captured, '/api/upload');

    filter.catch({ status: 413 }, host);

    expect(captured.statusCode).toBe(HttpStatus.PAYLOAD_TOO_LARGE);
    expect(captured.body).toEqual({
      status: 'fail',
      message: 'Payload too large.',
      path: '/api/upload',
    });
  });

  it('maps unknown errors to 500', () => {
    const captured: CapturedResponse = {};
    const host = createHost(captured, '/api/oops');

    filter.catch(new Error('boom'), host);

    expect(captured.statusCode).toBe(HttpStatus.INTERNAL_SERVER_ERROR);
    expect(captured.body).toEqual({
      status: 'error',
      message: 'Internal server error.',
      path: '/api/oops',
    });
  });
});
