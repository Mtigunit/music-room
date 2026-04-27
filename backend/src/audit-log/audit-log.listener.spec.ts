import { Test, TestingModule } from '@nestjs/testing';
import { Logger } from '@nestjs/common';
import { AuditLogListener } from './audit-log.listener';
import { AuditLogRepository } from './audit-log.repository';
import { AuditAction } from './audit-log.constants';
import { AuditLogEvent } from './audit-log.event';

describe('AuditLogListener', () => {
  let listener: AuditLogListener;
  let repository: AuditLogRepository;

  const mockRepository = {
    create: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuditLogListener,
        {
          provide: AuditLogRepository,
          useValue: mockRepository,
        },
      ],
    }).compile();

    listener = module.get<AuditLogListener>(AuditLogListener);
    repository = module.get<AuditLogRepository>(AuditLogRepository);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(listener).toBeDefined();
  });

  describe('onAuditLog', () => {
    const event: AuditLogEvent = {
      userId: 'user-123',
      action: AuditAction.LOGIN,
      platform: 'web',
      deviceModel: 'Chrome',
      appVersion: '1.0.0',
      metadata: { ip: '127.0.0.1' },
    };

    it('should call repository.create with the event payload', async () => {
      mockRepository.create.mockResolvedValue(undefined);

      await listener.onAuditLog(event);

      expect(repository.create).toHaveBeenCalledWith(event);
    });

    it('should catch and log errors without throwing', async () => {
      const loggerSpy = jest
        .spyOn(Logger.prototype, 'error')
        .mockImplementation();
      const error = new Error('Database connection failed');
      mockRepository.create.mockRejectedValue(error);

      // Should not throw
      await expect(listener.onAuditLog(event)).resolves.not.toThrow();

      expect(loggerSpy).toHaveBeenCalledWith(
        expect.stringContaining(
          'Failed to persist audit log [LOGIN]: Database connection failed',
        ),
      );

      loggerSpy.mockRestore();
    });
  });
});
